-- Info column: everything ItemTree states about the root the window is on, in the design's
-- sections, with the baseline value beside anything this build moved. The root is usually an
-- item; a spell or an enchant root draws the recipe view instead, and a quest root draws the
-- quest view.
--
-- The window owns the pane. UI/Frame.lua calls InfoPanel.Attach(region) once with a child
-- frame it created and sized, then InfoPanel.Show(rootKey) on every open, and
-- InfoPanel.SetShowChanges(bool) whenever its own "Show classic diff" tick box moves. The
-- panel never re roots, never creates a ViewModel, never walks the graph past Graph.Summary
-- Graph.SpellInfo and Graph.Children, and never touches saved variables. Frame hands it the
-- node key string ("item:2835", "spell:7411", "quest:7786"); a bare item id is taken as an item
-- key as well, so either shape re roots the column.
--
-- Design reference: the info column in harness/src/render-design.tsx, drawn over the sections
-- harness/src/api.ts builds in its `info` function. The Forever and Classic tabs are gone and
-- so is the mode button that used to sit here: there is one fact list, and the window's tick
-- box decides whether a changed field reads as old to new or as this build's value alone.
--
-- Sections, in that order, each left out when the record states nothing for it:
--   header     the icon, the name in its quality colour and the badges
--   lead       the one muted sentence some items open with: that the build withholds this one,
--              that the realm has found it, or that the build newly named it ("Newly named in
--              this build", under the New medallion the header already draws for it)
--   basics     type, subtype, slot, item level, required level, binds, stack size, unique
--   Weapon     damage, speed, and damage per second worked out from the two
--   Stats      armour first, the way the game tooltip orders it and with no plus sign on it,
--              then the real amounts, asked of the client first (ItemTree.ItemStats) and taken
--              from the record's own stats field where the client cannot say. Armour follows
--              the same two sources in the same order and is never drawn twice. Only where
--              neither answers a stat are the budget shares drawn, as percentages under the
--              honest heading "Stat budget": the raw share out of 10,000 is never drawn,
--              because 5833 is not a number a player can read.
--   Effects    each fx entry as its trigger word and the spell, with the cooldown
--   Requires   the required skill and rank by name, and the classes the item allows
--   other      set name, durability, sell price
--   Changed    the changes no fact row of its own carries, only while the tick box is on
--   uses       the summary line, worded by UI/Tooltip.lua so the two never drift apart
--
-- The spell view (a recipe or an enchant root) is built from Graph.SpellInfo and reads:
--   header     "Spell: Enchant 2H Weapon - Strength (7745)" and the spell icon
--   spell      profession, required skill, what it creates or enchants, cooldown, trainer
--   Reagents   each reagent by name with its count
--   Tools      the tool categories the recipe needs
--   Taught by  the items that teach it
--   about      the client's own spell description, wrapped, so a spell says what it does
--   Changed    the recipe's change lines while the tick box is on
--
-- The quest view opens (brief Q8) on what the client and the player's own records know about the
-- quest, all of it from Core/ViewModel.lua ViewModel.Quest (InfoPanel.QuestLiveSections):
--   lead         the level, "In your log" or "Completed", and the zone
--   Given by     the NPC that gave it and where it stood ("Captain Vale | Westfall 45.2, 61.0"),
--                from the collector's record, else Classic Era's quest giver lists
--   Turned in to the NPC it was handed in to, the same way
--   Objectives   the log's lines with their progress, while it is in the log
--   Rewards      the log's rewards while it is in the log, else the shipped QuestRewards table's
-- The client is asked about that one quest when its page opens, once per session, through the
-- reader this file installs on ViewModel.questReader (InfoPanel.ReadQuest), and asked again only
-- after the quest log says that quest moved (InfoPanel.OnQuestEvent). A quest nothing knows
-- anything about reads "Nothing known about this quest yet" and the line saying how ItemTree
-- learns it, and never an item's wording.
--
-- Under that, what the quest's own edges state, from Graph.Children over its key:
--   header     "Quest: Rise, Thunderfury! (7786)" and the quest mark the tree draws
--   Requires   every item the quest needs, with the count, walking up (QUEST_REQUIRES)
--   Started by the item that starts it, walking up (QUEST_STARTED_BY)
--   Rewards    what it gives, walking down (QUEST_REWARDS), a choice of rewards marked as one
-- Each item row is its name in its own quality colour, and a section whose edges are not simply
-- mined ends in one line saying where they came from, in Core/Confidence.lua's words. The edge
-- types are read by name and never held, because the agent adding them works in parallel: a
-- build without them draws a header and a line saying nothing is known yet, never the "Not in
-- ItemTree data" notice, because the key itself names the quest.
--
-- Under that comes everything the shipped Classic Era table states about the quest
-- (Core/EraSources.lua E:QuestFacts, drawn by InfoPanel.QuestEraSections):
--   the quest's own title in full, which the header's two lines may have cut, and the side it
--   belongs to in words;
--   Requires                 what the quest asks the player to bring, with the count (qr, brief
--                            Q10), unless the curated table or the collector already states it;
--   Rewards                  the items Era says it hands over, each a link row that re roots the
--                            window on the item;
--   Drops only on this quest the items that only drop while a player is on it, each with up to
--                            three short lines naming what drops it, where, and how often
--                            ("Forest Ooze, Azshara, about 80%");
--   and the two lines every Era fact ends on: "Predicted", then "From Classic Era. WoW Forever
--   may have changed this."
-- It is all ItemTree's own data. No quest load is ever requested of the client: the owner's probe
-- had C_QuestLog.RequestLoadQuestByID answer QUEST_DATA_LOAD_RESULT false for a quest the player
-- is not on, so there is nothing to ask for beyond what the reader above reads. An item the
-- column already names is not named twice, a section stops at eight rows and says how many are
-- left, and with the window's "Show predicted data" tick box off the whole block goes, because
-- every Era fact is a prediction.
--
-- Rows are { kind = "fact" | "change" | "para", key, field, label, value, old, new, colorKey }.
-- A changed field is one row reading old to new: the old value is drawn struck through at 60
-- percent opacity and the new value in cream beside it. The frame API has no strike through,
-- so the strike is a hairline texture drawn across the old value's own string width at mid
-- height, and every part of a row is centred in its own line box so that mid height is the
-- text's and not the box's.
--
-- A label is never truncated to make room for its value. Where the label and the value do not
-- fit one line, the value drops to wrapped lines of its own under the label, still right
-- aligned, and the row grows to hold them: the owner saw "Rogue, Priest, Shaman, Mage,
-- Warlock, Druid" drawn straight over the word "Classes". InfoPanel.FactLayout is that
-- decision on its own, widths in and placement out, and InfoPanel.ChangeLayout is the same
-- decision with the struck old value added on the row's last line. A row with no label of its
-- own (the uses line, a tool name) reads across the row from the left, and a "para" row (the
-- spell description) wraps across the whole column.
--
-- The uses line is also a link: "Used in 19 recipes" walks down from the root and so leads to
-- the window's Used by direction, "Made by 1 recipe" walks up and leads to Sources, and a line
-- with nothing behind it is plain text. InfoPanel.SummaryDirection is that decision, pure.
--
-- InfoPanel.TooltipLines(itemId) is the same facts phrased as client tooltip lines, for the
-- Tree and Sidebar panes to draw when a row inside the window is hovered. It mirrors what the
-- harness returns as `tooltip`: the binding line first, then one line per fact in the client's
-- own wording, capped at 14. A fact the client writes as a pair rather than a sentence comes
-- back as { text = label, right = value } for the caller to draw as a double line.
--
-- Anatomy (Theme): ITEMTREE_PAD_FRAME 12 panel padding, ITEMTREE_SPACE_1 4 between parts,
-- ITEMTREE_ICON_HEADER 40 for the header icon, ITEMTREE_BADGE_SIZE_TOOLTIP 14 inline badges,
-- ITEMTREE_ICON_BADGE 12 for the coins inside a price, ITEMTREE_BORDER_HAIRLINE 1 for the
-- dividers and the inset edge, ITEMTREE_FONTSIZE_BODY_SM 11 for the fact
-- rows and the section headings (the design draws facts at 10px and headings at 11px; 11 is
-- the nearest token, and the smallest the theme carries) and ITEMTREE_FONTSIZE_BODY_MD 12 for
-- the item name.
--
-- The header icon is the primary item of the whole window, so it has a size token of its own:
-- the design's info column (harness/src/render-design.tsx) draws it at 48, which crowds the
-- name beside it at this column width, and 40 is the number that reads as the primary item
-- without taking the name's second line.
--
-- Its rarity frame is drawn OVER the icon and never behind it. A hairline square 1px out from
-- art with rounded corners shows as a coloured glow poking out of the corners, which is what
-- Arcane Crystal's green edge was. The client's own item button holds the answer: an IconBorder
-- region on the OVERLAY layer carrying Interface\Common\WhiteIconFrame at exactly the icon's
-- rect, tinted with the quality colour. The template itself is not used, because on both target
-- clients SetItemButtonQuality ends in IconBorder:Hide() with the colouring commented out
-- (Blizzard_ItemButton/Classic/ItemButtonTemplate.lua, the same file on the classic_era and
-- classic_beta branches of the wow-ui-source mirror), so the native route draws no rarity at
-- all on Classic. Only the art and the placement are taken. Poor and common wear no frame,
-- which is the rule the client's own commented out code kept.
--
-- The column's width is the region's own, read on every draw and again on OnSizeChanged:
-- nothing here assumes a number, because the window has moved it once already.
--
-- Money is written the way the game writes it, as the number then the coin art for each
-- denomination the price states: 12 gold, 50 silver, 23 copper, with a zero part dropped. The
-- art is Assets COIN_GOLD, COIN_SILVER and COIN_COPPER through Assets.Markup, not the client's
-- own GetCoinTextureString, which answered nothing on the beta and left the column reading
-- "3g 60s". A client with no art at all falls back to those letters, which is what the specs
-- read, and the struck baseline price keeps its coins because both sides go through one writer.
--
-- Client APIs: ITEM_QUALITY_COLORS for the name,
-- GameTooltip on the header so the root's own tooltip reads exactly as it does anywhere else,
-- and a plain ScrollFrame driven by the mouse wheel, because the column now runs the full body
-- height and states far more than fits in it. Item stats and spell text are asked of
-- UI/Client.lua, which can answer nothing until the client has loaded them, so the column asks
-- once more when the load lands and never again for that root.
--
-- InfoPanel.Sections, SpellSections, QuestSections, QuestEraSections, QuestSourceText,
-- TooltipLines, QuestTooltipLines, Content,
-- SpellContent, QuestContent, Header, SpellHeader, QuestHeader, FieldText, Money, MoneyParts,
-- CoinText, BundleText, ClassRestriction, SummaryDirection, Dps, StatNumber, StatText, IsDpsStat,
-- IsArmourStat, ClientArmour, ArmourText,
-- QualityEdge, SectionConfidence, EffectText, ChangeText, FactLayout, ChangeLayout, SentenceWidth,
-- SharePercent, ShareText, CountText, Brighten and ParagraphLines are pure and specced: they
-- decide everything the pane says with no client present. Everything from the divider down is
-- guarded, so this file loads under busted with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local InfoPanel = {}
ItemTree.UI.InfoPanel = InfoPanel

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local COLOR_TITLE = "ITEMTREE_COLOR_TEXT_TITLE"
local COLOR_BODY = "ITEMTREE_COLOR_TEXT_BODY"
local COLOR_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
local COLOR_DIVIDER = "ITEMTREE_COLOR_BORDER_DIVIDER"
local COLOR_INSET = "ITEMTREE_COLOR_SURFACE_INSET"
local COLOR_THUMB = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
-- The link gold, which is the colour the footer's own "Options" word is written in.
local COLOR_LINK = "ITEMTREE_COLOR_TEXT_TITLE"

-- The glyph a quest wears, which is the key UI/Tree.lua and UI/Chain.lua already draw a quest
-- row and a quest stage with: the column's header must read as the same thing the tree does.
local QUEST_ASSET = "QUEST_AVAILABLE"

-- Bonding ids as the client writes them: the field value in the column, the line under the
-- item name in a tooltip.
local BONDING = {
  [1] = "When picked up",
  [2] = "When equipped",
  [3] = "When used",
  [4] = "Quest item",
}

local BONDING_LINES = {
  [1] = "Binds when picked up",
  [2] = "Binds when equipped",
  [3] = "Binds when used",
  [4] = "Quest item",
}

-- inventoryType to the slot the client names. Core states the number and nothing else, and
-- the client's own INVTYPE_ globals are not readable from a pure function, so the words live
-- here, the same list harness/src/names.ts draws the design from.
local SLOT_NAMES = {
  [1] = "Head",
  [2] = "Neck",
  [3] = "Shoulder",
  [4] = "Shirt",
  [5] = "Chest",
  [6] = "Waist",
  [7] = "Legs",
  [8] = "Feet",
  [9] = "Wrist",
  [10] = "Hands",
  [11] = "Finger",
  [12] = "Trinket",
  [13] = "One-Hand",
  [14] = "Shield",
  [15] = "Ranged",
  [16] = "Back",
  [17] = "Two-Hand",
  [18] = "Bag",
  [19] = "Tabard",
  [20] = "Chest",
  [21] = "Main Hand",
  [22] = "Off Hand",
  [23] = "Held in off hand",
  [24] = "Ammo",
  [25] = "Thrown",
  [26] = "Ranged",
  [27] = "Quiver",
  [28] = "Relic",
}

-- The fields written as coins rather than as numbers.
local MONEY_FIELDS = {
  sell_price = true,
  buy_price = true,
}

-- How many fact lines a tooltip takes before it is longer than the window.
local TOOLTIP_LIMIT = 14

-- The row pool, filled on the first draw and reused from then on.
InfoPanel.rows = {}

-- Whether a changed field reads as old to new. The window owns the tick box and tells the
-- panel; this is the default it starts on and is in memory only.
InfoPanel.showChanges = true

local function size(key, fallback)
  local sizes = Theme and Theme.sizes
  local value = sizes and sizes[key]
  if type(value) ~= "number" then
    return fallback
  end
  return value
end

local function fontSize(key, fallback)
  local sizes = Theme and Theme.fontSizes
  local value = sizes and sizes[key]
  if type(value) ~= "number" then
    return fallback
  end
  return value
end

local HAIRLINE = size("ITEMTREE_BORDER_HAIRLINE", 1)
local TIGHT = size("ITEMTREE_SPACE_1", 4)
local FONT_SM = fontSize("ITEMTREE_FONTSIZE_BODY_SM", 11)
local FONT_MD = fontSize("ITEMTREE_FONTSIZE_BODY_MD", 12)
-- One coin inside a price, a shade above the text it sits in so the art reads at this size.
local COIN = size("ITEMTREE_ICON_BADGE", 12)

-- Row heights at the smaller text size: the design draws a fact row at 13px and a heading at
-- 16px, which is the font size plus its breathing room either way.
local ROW_HEIGHTS = {
  fact = FONT_SM + 3,
  change = FONT_SM + 3,
  notice = FONT_SM + 3,
  para = FONT_SM + 3,
  heading = FONT_SM + 5,
  divider = TIGHT + HAIRLINE,
  -- Brief K24b: the Keep block's tag row, the tags' own height (Core/Keep.lua TAG_SIZE, 17) and room.
  keepTags = 17 + 3,
  -- Brief K24k (owner 2026-10-07, "the top and bottom gap for the Keep tag is too big, half
  -- that"): the blank rows above and below the tag row, half a fact row.
  keepGap = math.floor((FONT_SM + 3) / 2),
}

-- The height of one line of a row of this kind. A change row that wraps and a paragraph row
-- are taller than one line, and drawRow is what works their real height out, so this stays the
-- single line answer every caller has always had.
function InfoPanel.RowHeight(kind)
  return ROW_HEIGHTS[kind] or ROW_HEIGHTS.fact
end

-- The old value is drawn at this much of full opacity, which is the design's "struck through
-- and faded": Theme carries no alpha token to name it, so it is written here once.
local OLD_ALPHA = 0.6

-- Where a label and its value go, given the room and what each of them measures. Pure, so the
-- decision is specced without a client: widths in, placement out.
--
--   label ..................... value    one line, the value right aligned against the edge
--   label                                the label keeps the first line on its own and the
--   ............. value that wrapped       value takes wrapped lines under it, still right
--   ....................... to here        aligned, and the row grows to hold them
--
-- The label is never given away to make room: "Classes" truncated to "Cla" says nothing, and
-- the room left over at this column width was nothing at all, which is how the class list came
-- to be drawn over its own label. labelWidth in the answer is the room the label may take, and
-- 0 means "as wide as the text"; valueWidth is the width the value is given so the client
-- wraps it, and 0 means the same. valueTop is how far down the value's first line starts.
function InfoPanel.FactLayout(width, labelWidth, valueWidth, gap, lineHeight)
  width = tonumber(width) or 0
  labelWidth = math.max(tonumber(labelWidth) or 0, 0)
  valueWidth = math.max(tonumber(valueWidth) or 0, 0)
  gap = tonumber(gap) or TIGHT
  lineHeight = tonumber(lineHeight) or ROW_HEIGHTS.fact

  local function oneLine(room)
    return {
      lines = 1,
      wrap = false,
      valueWrap = false,
      height = lineHeight,
      labelWidth = room,
      valueWidth = 0,
      valueLines = 1,
      valueTop = 0,
      valueHeight = lineHeight,
    }
  end

  -- A width the client will not state is no reason to wrap anything: the row reads as it
  -- always has and the client's own clipping is what remains.
  if width <= 0 then
    return oneLine(0)
  end
  if labelWidth + valueWidth + gap <= width then
    return oneLine(math.max(width - valueWidth - gap, 0))
  end

  local valueLines = math.max(1, math.ceil(valueWidth / width))
  return {
    lines = 1 + valueLines,
    wrap = true,
    valueWrap = true,
    height = lineHeight * (1 + valueLines),
    labelWidth = 0,
    valueWidth = width,
    valueLines = valueLines,
    valueTop = lineHeight,
    valueHeight = lineHeight * valueLines,
  }
end

-- Where the three parts of a change row go. The label and the new value are laid out by
-- FactLayout, so a long new value wraps under its label exactly as a plain fact's does, and
-- the struck old value takes the row's last line on its own.
--
--   label ................. old  new     one line, the old value struck through beside the new
--   label ..................... new      two lines, the struck old value right aligned under
--   ....................... old            them, which is what a narrow column forces
--
-- oldWidth in the answer is the room the struck value may take, and 0 means "as wide as the
-- text": it is capped only where the baseline value is wider than the whole column, which
-- would otherwise run it out past the column's edge and take the strike with it.
function InfoPanel.ChangeLayout(width, labelWidth, oldWidth, newWidth, gap, lineHeight)
  width = tonumber(width) or 0
  labelWidth = math.max(tonumber(labelWidth) or 0, 0)
  oldWidth = math.max(tonumber(oldWidth) or 0, 0)
  newWidth = math.max(tonumber(newWidth) or 0, 0)
  gap = tonumber(gap) or TIGHT
  lineHeight = tonumber(lineHeight) or ROW_HEIGHTS.change

  -- Nothing struck through: an ordinary fact row, and FactLayout is the whole answer.
  if oldWidth <= 0 then
    local plain = InfoPanel.FactLayout(width, labelWidth, newWidth, gap, lineHeight)
    plain.oldWidth = 0
    return plain
  end

  local needed = labelWidth + oldWidth + newWidth + gap * 2
  if width <= 0 or needed <= width then
    return {
      lines = 1,
      wrap = false,
      valueWrap = false,
      height = lineHeight,
      labelWidth = math.max(width - oldWidth - newWidth - gap * 2, 0),
      valueWidth = 0,
      valueLines = 1,
      valueTop = 0,
      valueHeight = lineHeight,
      oldWidth = 0,
    }
  end

  local top = InfoPanel.FactLayout(width, labelWidth, newWidth, gap, lineHeight)
  local cappedOld = 0
  if oldWidth > width then
    cappedOld = width
  end
  return {
    lines = top.lines + 1,
    wrap = true,
    valueWrap = top.valueWrap,
    height = top.height + lineHeight,
    labelWidth = top.labelWidth,
    valueWidth = top.valueWidth,
    valueLines = top.valueLines,
    valueTop = top.valueTop,
    valueHeight = top.valueHeight,
    oldWidth = cappedOld,
  }
end

-- A heading or a sentence row (the uses line, a notice) reads across the row as wide as its
-- words, and the scroll frame clips whatever runs past the column's edge mid letter. Where the
-- words are wider than the row they are held to it, and the client truncates them with an
-- ellipsis the way a fact label that has given its room away does. Answers the width the words
-- take, which is also the width a link's hit area may take. Pure.
function InfoPanel.SentenceWidth(textWidth, width)
  textWidth = math.max(tonumber(textWidth) or 0, 0)
  width = tonumber(width) or 0
  if width > 0 and textWidth > width then
    return width
  end
  return textWidth
end

-- A colour lifted towards white by this much of what is left of it, for a link that brightens
-- under the pointer. The Theme carries one link gold and no brighter second one, so the hover
-- colour is worked out from the token rather than written down beside it. Pure.
function InfoPanel.Brighten(r, g, b, amount)
  local lift = tonumber(amount) or 0
  if lift < 0 then
    lift = 0
  elseif lift > 1 then
    lift = 1
  end
  local function lifted(channel)
    local value = tonumber(channel) or 0
    return value + (1 - value) * lift
  end
  return lifted(r), lifted(g), lifted(b)
end

-- How many lines a wrapped paragraph takes, for a client that will not measure one. charWidth
-- is the average width of a character at the body size, which is about half its point size in
-- the design's narrow face. Never fewer than one line.
function InfoPanel.ParagraphLines(text, width, charWidth)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  width = tonumber(width) or 0
  charWidth = tonumber(charWidth) or (FONT_SM / 2)
  if width <= 0 or charWidth <= 0 then
    return 1
  end
  local perLine = math.floor(width / charWidth)
  if perLine < 1 then
    perLine = 1
  end
  return math.max(1, math.ceil(#text / perLine))
end

-- Every module below is read through a type check and a pcall: the panel draws what it can
-- rather than raising inside a redraw.
local function moduleCall(module, name, ...)
  if not module or type(module[name]) ~= "function" then
    return nil
  end
  local ok, result = pcall(module[name], ...)
  if not ok then
    return nil
  end
  return result
end

-- Brief F155 (owner QA 2026-10-14, Runecloth: "Make sure those 6 vs 10 quests and this side panel
-- is something we inspect as part of the faction toggle"): Graph.Summary for the page, its quest
-- count less the other side's quests while "Hide other faction data" is on (UI/Tooltip.lua
-- Tooltip.WithoutOtherSide and Tooltip.HiddenFaction), so "Used in 29 recipes, 6 quests" reads the
-- tooltip's 6 on an Alliance character. The quests the item only comes from stay in it (brief K24e:
-- the page words them), but for the other side's alone (brief HF2, Tooltip.OtherSideRewards), whose
-- Sources rows the setting hides too. nil where Graph or the item answers none. Brief QS2b: the quests
-- only the other side was seen taking leave the count too, whatever the setting says (Tooltip.SeenFaction).
function InfoPanel.PageSummary(itemId)
  local summary = moduleCall(ItemTree.Graph, "Summary", itemId)
  local tooltip = ItemTree.Tooltip
  if type(summary) ~= "table" or type(tooltip) ~= "table" then
    return summary
  end
  local faction = moduleCall(tooltip, "HiddenFaction")
  local seen = moduleCall(tooltip, "SeenFaction")
  if faction == nil and seen == nil then
    return summary
  end
  return moduleCall(tooltip, "WithoutOtherSide", summary, faction, seen) or summary
end

local function dataItem(itemId)
  local data = ItemTree.Data
  if not data or type(data.GetItem) ~= "function" then
    return nil
  end
  local ok, item = pcall(data.GetItem, data, itemId)
  return ok and item or nil
end

local function positive(value)
  local number = tonumber(value)
  if not number or number <= 0 then
    return nil
  end
  return number
end

-- The denominations a price is written in, largest first, with the art each one draws and the
-- letter that stands in for it where there is no art. The arithmetic is Core/Sources.lua's:
-- 125023 copper is 12 gold, 50 silver and 23 copper.
local COINS = {
  { unit = 10000, art = "COIN_GOLD", letter = "g" },
  { unit = 100, art = "COIN_SILVER", letter = "s" },
  { unit = 1, art = "COIN_COPPER", letter = "c" },
}

-- Copper split into the denominations the game draws, largest first, as
-- { { amount, art, letter } }. A denomination of nothing is left out, and a price of nothing
-- comes back as nought copper, because a price of nothing is still a price and has to read as
-- one beside a price of something. nil for anything that is not a number. Pure.
function InfoPanel.MoneyParts(copper)
  local value = tonumber(copper)
  if not value then
    return nil
  end
  value = math.floor(value)
  if value < 0 then
    value = 0
  end
  local parts, rest = {}, value
  for _, coin in ipairs(COINS) do
    local amount = math.floor(rest / coin.unit)
    rest = rest % coin.unit
    if amount > 0 then
      parts[#parts + 1] = { amount = amount, art = coin.art, letter = coin.letter }
    end
  end
  if #parts == 0 then
    local smallest = COINS[#COINS]
    parts[1] = { amount = 0, art = smallest.art, letter = smallest.letter }
  end
  return parts
end

-- Money the way the game writes it: the number, then the coin for its denomination, for each
-- denomination the price states. icon is handed an Assets key and answers the inline texture
-- escape for it, which is what keeps this pure: a spec hands it its own, and a caller with no
-- art at all hands it nothing and the letter is written instead ("1g 23s 45c").
function InfoPanel.CoinText(copper, icon)
  local parts = InfoPanel.MoneyParts(copper)
  if not parts then
    return nil
  end
  local out = {}
  for index, part in ipairs(parts) do
    local art = nil
    if type(icon) == "function" then
      local ok, markup = pcall(icon, part.art)
      if ok and type(markup) == "string" and markup ~= "" then
        art = markup
      end
    end
    out[index] = tostring(part.amount) .. (art or part.letter)
  end
  return table.concat(out, " ")
end

-- Copper in letters: "1g 23s 45c", zero parts dropped, "0c" for nothing. The fallback for a
-- client carrying none of the coin art, and what the specs read.
function InfoPanel.Money(copper)
  return InfoPanel.CoinText(copper, nil)
end

-- The inline escape for one coin, or nil where there is no art to draw. Assets is read through
-- the namespace rather than the captured local, the way UI/Tooltip.lua reads it, so a spec can
-- take the art away; Assets.Markup raises on a key the table has no row for, and a raise inside
-- a redraw would cost the whole column, so the call is pcall'd.
function InfoPanel.CoinIcon(key)
  local assets = ItemTree.Assets
  if type(key) ~= "string" or type(assets) ~= "table" or type(assets.Markup) ~= "function" then
    return nil
  end
  local ok, markup = pcall(assets.Markup, key, COIN)
  if not ok or type(markup) ~= "string" or markup == "" then
    return nil
  end
  return markup
end

-- A price as the column draws it, with the coins in it. The one money writer: this build's
-- value, the baseline's and the tooltip block's all go through here, so a price is never
-- written two ways and the struck baseline price keeps its coins.
function InfoPanel.MoneyText(copper)
  return InfoPanel.CoinText(copper, InfoPanel.CoinIcon)
end

-- Brief PS1 bundle prices (QA item 300): a buy price's money with the bundle it buys, "25c for 5",
-- in Core/Sources.lua's words (Sources.BundleCount over the item row's vs, Sources.BundlePrice), so
-- the Buy price line and the Sold by rows say it the same way. The money alone for a bundle of 1, a
-- row stating none, or a load without Sources. Pure over Sources.
function InfoPanel.BundleText(money, item)
  local sources = ItemTree.Sources
  local count = moduleCall(sources, "BundleCount", item)
  local text = count and moduleCall(sources, "BundlePrice", money, count) or nil
  if type(text) == "string" and text ~= "" then
    return text
  end
  return money
end

-- Item class and subclass names, or nil. Data is pure Lua and always loaded before the UI, but
-- it is read through a type check and a pcall like everywhere else, so a half loaded addon
-- draws a shorter fact list rather than raising mid draw.
local function classNames(classId, subclassId)
  local data = ItemTree.Data
  if classId == nil or not data or type(data.GetClassName) ~= "function" then
    return nil, nil
  end
  local ok, name, sub = pcall(data.GetClassName, data, classId, subclassId)
  if not ok then
    return nil, nil
  end
  return name, sub
end

-- An item set by name, falling back to its id so a row still says which set it means.
local function setName(setId)
  local id = tonumber(setId)
  local data = ItemTree.Data
  if not id or not data or type(data.GetSet) ~= "function" then
    return nil
  end
  local ok, set = pcall(data.GetSet, data, id)
  if ok and type(set) == "table" and type(set.n) == "string" and set.n ~= "" then
    return set.n
  end
  return tostring(id)
end

-- "Blacksmithing 10", through Graph so the wording matches the rest of the window.
local function skillLabel(skillLine, rank)
  if not skillLine then
    return nil
  end
  local label = moduleCall(ItemTree.Graph, "SkillLabel", skillLine, rank)
  if type(label) == "string" and label ~= "" then
    return label
  end
  return nil
end

-- A mask with every bit a class could sit on. Graph.ClassNames reads the bits it knows off the
-- number, so a build of Core older than Graph.ClassCount can still be asked how many classes
-- there are by asking it to name them all.
local ALL_CLASS_BITS = 0xFFFFFF

-- The classes an allowableClass mask permits, in Classic order.
local function classList(mask)
  local names = moduleCall(ItemTree.Graph, "ClassNames", mask)
  return type(names) == "table" and names or {}
end

-- How many playable classes a mask is read against. Graph owns the class list and states the
-- count, which is what Graph.Requirements tests its own class rows against, so this column
-- tests the same number and the two panes never disagree about one item.
local function classCount()
  local count = moduleCall(ItemTree.Graph, "ClassCount")
  if type(count) == "number" and count > 0 then
    return count
  end
  return #classList(ALL_CLASS_BITS)
end

-- The classes a mask actually restricts the item to, or nil where it restricts nothing. 801
-- items in the build name every playable class in their mask, Greater Mark of the Dawn (23196)
-- among them, and "Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid" is a
-- whole line that tells the reader nothing: an item every class may use has no class
-- requirement, so the Requires section says nothing about classes at all.
--
-- total is how many classes there are to allow. A total of nothing means the caller could not
-- say, and then a named class is taken at its word rather than dropped. Pure.
function InfoPanel.ClassRestriction(names, total)
  if type(names) ~= "table" or #names == 0 then
    return nil
  end
  total = tonumber(total) or 0
  if total > 0 and #names >= total then
    return nil
  end
  return names
end

-- The six resistance schools by the ITEM_MOD code a record states them under, with both keys
-- GetItemStats answers each one with. The Forever client answers a resistance under the two
-- spellings at once: Snake Eye Kaleidoscope (273088) comes back with
-- ITEM_MOD_ARCANE_RESISTANCE_SHORT 1 and RESISTANCE6_NAME 1, and the column drew it twice, as
-- "Arcane Resistance +1" and "Arcane resistance +1". ItemTree-Data's harvest reads the same
-- pair as one stat. The RESISTANCE<n>_NAME globals go by the client's school order (1 holy,
-- 2 fire, 3 nature, 4 frost, 5 shadow, 6 arcane), which is not the ITEM_MOD order.
local RESISTANCE_SCHOOLS = {
  [51] = { mod = "ITEM_MOD_FIRE_RESISTANCE_SHORT", name = "RESISTANCE2_NAME" },
  [52] = { mod = "ITEM_MOD_FROST_RESISTANCE_SHORT", name = "RESISTANCE4_NAME" },
  [53] = { mod = "ITEM_MOD_HOLY_RESISTANCE_SHORT", name = "RESISTANCE1_NAME" },
  [54] = { mod = "ITEM_MOD_SHADOW_RESISTANCE_SHORT", name = "RESISTANCE5_NAME" },
  [55] = { mod = "ITEM_MOD_NATURE_RESISTANCE_SHORT", name = "RESISTANCE3_NAME" },
  [56] = { mod = "ITEM_MOD_ARCANE_RESISTANCE_SHORT", name = "RESISTANCE6_NAME" },
}

local RESISTANCE_CODE_BY_KEY = {}
for code, school in pairs(RESISTANCE_SCHOOLS) do
  RESISTANCE_CODE_BY_KEY[school.mod] = code
  RESISTANCE_CODE_BY_KEY[school.name] = code
end

-- The ITEM_MOD code of a resistance under either of the client's keys for it, or nil for any
-- key that is not a resistance. Armour (RESISTANCE0_NAME) is not one. Pure.
function InfoPanel.ResistanceCode(key)
  return RESISTANCE_CODE_BY_KEY[key]
end

-- The client's global string key for a resistance code's word ("RESISTANCE6_NAME" for 56), or
-- nil for a code that is not a resistance. Pure.
function InfoPanel.ResistanceNameKey(code)
  local school = RESISTANCE_SCHOOLS[code]
  return school and school.name or nil
end

-- One ITEM_MOD code by name. A resistance takes the client's own word first, the global the
-- game's tooltip writes it with ("Arcane Resistance"), so the record path and the client path
-- name it the same way; everything else, and a resistance on a client with no word for it,
-- goes through Diff so a stat is written the same way everywhere.
local function statName(code)
  local nameKey = InfoPanel.ResistanceNameKey(code)
  if nameKey then
    local label = moduleCall(ItemTree.Client, "StatLabel", nameKey)
    if type(label) == "string" and label ~= "" then
      return (label:gsub("^%l", string.upper))
    end
  end
  local name = moduleCall(ItemTree.Diff, "StatName", code)
  if type(name) == "string" and name ~= "" then
    return name
  end
  return "stat " .. tostring(code)
end

-- The name of a spell, or nil. ItemTree.SpellName is the one resolver: Core answers from the
-- generated SpellNames module and the UI layer replaces it with the client's own.
local function spellName(spellId)
  local resolver = ItemTree.SpellName
  if type(resolver) ~= "function" then
    return nil
  end
  local ok, name = pcall(resolver, spellId)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- The real stat amounts for an item, from UI/Client.lua's resolver. One resolver, read the way
-- ItemTree.SpellName is: Core declares none, the UI layer installs it, and with no client at
-- all this answers nothing and the column falls back to what the build states.
local function clientStats(itemId)
  local resolver = ItemTree.ItemStats
  if type(resolver) ~= "function" or type(itemId) ~= "number" then
    return nil
  end
  local ok, stats = pcall(resolver, itemId)
  if ok and type(stats) == "table" and #stats > 0 then
    return stats
  end
  return nil
end

-- What the running client knows about an item, or nil. Only ever asked for an item the shipped
-- data cannot state: an item WoW Forever withholds becomes readable the moment somebody on the
-- realm finds it, and the client is where that shows up first.
local function clientFacts(itemId)
  local resolver = ItemTree.ItemFacts
  if type(resolver) ~= "function" or type(itemId) ~= "number" then
    return nil
  end
  local ok, facts = pcall(resolver, itemId)
  if ok and type(facts) == "table" and type(facts.name) == "string" and facts.name ~= "" then
    return facts
  end
  return nil
end

-- A withheld item's stub with what the client answered written over it, so every row below
-- reads exactly the way it does for an item the data states outright. Only the fields the
-- client actually answered are taken; the stub's own class, subclass, slot and icon stay, and
-- nothing at all comes from the baseline. The stub is never modified.
local function withClientFacts(item, facts)
  if not facts then
    return item
  end
  local out = {}
  for key, value in pairs(item) do
    out[key] = value
  end
  out.n = facts.name
  out.q = facts.quality
  out.il = out.il or facts.level
  out.rl = out.rl or facts.requiredLevel
  out.i = out.i or facts.icon
  return out
end

-- What the client says a spell does, or nil. Spell text loads on demand, so nil here is an
-- ordinary answer and the pane asks again once the client has it.
local function spellDescription(spellId)
  local resolver = ItemTree.SpellDescription
  if type(resolver) ~= "function" or type(spellId) ~= "number" then
    return nil
  end
  local ok, text = pcall(resolver, spellId)
  if ok and type(text) == "string" and text ~= "" then
    return text
  end
  return nil
end

-- An enchant node in the shape Graph.SpellInfo answers with, as far as the data allows: the
-- name, the marks and the change lines. An enchant is applied by a spell rather than being
-- one, so it has no reagents, no tools and no description of its own.
local function enchantInfo(enchantId)
  local id = tonumber(enchantId)
  local data = ItemTree.Data
  if not id or not data or type(data.GetEnchant) ~= "function" then
    return nil
  end
  local ok, enchant = pcall(data.GetEnchant, data, id)
  if not ok or type(enchant) ~= "table" then
    return nil
  end
  local key = "enchant:" .. tostring(id)
  local graph = ItemTree.Graph
  if graph and type(graph.Key) == "function" then
    local made, built = pcall(graph.Key, "enchant", id)
    if made and type(built) == "string" then
      key = built
    end
  end
  local Diff = ItemTree.Diff
  return {
    id = id,
    key = key,
    name = enchant.n,
    title = moduleCall(graph, "Title", key) or enchant.n,
    reagents = {},
    tools = {},
    taughtBy = {},
    new = moduleCall(Diff, "IsNew", "enchants", id) == true,
    changed = moduleCall(Diff, "IsChanged", "enchants", id) == true,
    changes = moduleCall(Diff, "ChangeLines", "enchants", id) or {},
  }
end

-- The effect trigger word and the duration text both come from Core/Diff.lua, which is where
-- the words and the number style live: a change row and this column must never write the same
-- cooldown two ways. Both are read through a type check, so the column still draws if Core is
-- half loaded. Diff answers nil for a duration the build does not state.
local function durationText(ms)
  local Diff = ItemTree.Diff
  if type(Diff) ~= "table" or type(Diff.DurationText) ~= "function" then
    return nil
  end
  local ok, text = pcall(Diff.DurationText, ms)
  return ok and text or nil
end

local function effectTrigger(code)
  local Diff = ItemTree.Diff
  if type(Diff) ~= "table" or type(Diff.EffectTrigger) ~= "function" then
    return nil
  end
  local ok, word = pcall(Diff.EffectTrigger, code)
  return ok and word or nil
end

local function numberText(value)
  local number = tonumber(value)
  if number and number == math.floor(number) then
    return string.format("%d", number)
  end
  return tostring(value)
end

-- A stat amount as a player reads it: a whole number stays whole, and anything else goes to one
-- decimal place. The client's own stat table answers floats, so Ruby-Adorned Blade came back
-- with a damage per second of 23.91304397583 and the column printed every digit of it. One
-- decimal is what the client's own tooltip writes, and no number in this block is worth more.
-- nil for anything that is not a number. Pure.
function InfoPanel.StatNumber(value)
  local amount = tonumber(value)
  if not amount then
    return nil
  end
  if amount == math.floor(amount) then
    return string.format("%d", amount)
  end
  return string.format("%.1f", amount)
end

-- Whether a stat key is the weapon's damage per second. It is the one entry in the client's
-- stat table that is a measurement rather than a bonus: it is worked out from the damage and
-- the speed rather than added to anything, so it wears no plus, and the Weapon section works
-- the same number out for itself from what the build states. Pure.
function InfoPanel.IsDpsStat(key)
  if type(key) ~= "string" then
    return false
  end
  return key:find("DAMAGE_PER_SECOND", 1, true) ~= nil
end

-- One stat amount as its row draws it: "+5", "-3", "23.9". key is the client's own stat key
-- where there is one, and nil where the caller has none, which is what the build's own stat
-- list hands over. nil for anything that is not a number. Pure.
function InfoPanel.StatText(key, value)
  local amount = tonumber(value)
  if not amount then
    return nil
  end
  local text = InfoPanel.StatNumber(amount)
  if InfoPanel.IsDpsStat(key) then
    return text
  end
  if amount >= 0 then
    return "+" .. text
  end
  return text
end

-- The client's own key for armour in the table GetItemStats answers with. UI/Client.lua lists
-- it first in STAT_ORDER, which is where the game's own tooltip writes it, and this is the one
-- place the column names it. Pure.
local ARMOUR_STAT_KEY = "RESISTANCE0_NAME"

function InfoPanel.IsArmourStat(key)
  return key == ARMOUR_STAT_KEY
end

-- The client's stat list with each resistance school in it once. A school the client answered
-- under both keys keeps the place of the first (UI/Client.lua ranks RESISTANCE<n>_NAME with the
-- other resistances, the ITEM_MOD spelling sorts after them), the ITEM_MOD amount where there
-- is one, as the pipeline's harvest reads it, and one label: namer(code), which is the
-- client's own word with Core/Diff.lua's as the fallback. Every other entry is handed through
-- untouched. Pure: a new list, and the entries it keeps are never written to.
function InfoPanel.ClientStatsOnce(stats, namer)
  if type(stats) ~= "table" then
    return stats
  end
  local list, merged = {}, {}
  for _, entry in ipairs(stats) do
    local code = type(entry) == "table" and InfoPanel.ResistanceCode(entry.key) or nil
    if not code then
      list[#list + 1] = entry
    else
      local row = merged[code]
      if not row then
        local label = type(namer) == "function" and namer(code) or nil
        if type(label) ~= "string" or label == "" then
          label = entry.label
        end
        row = { key = RESISTANCE_SCHOOLS[code].name, label = label, value = entry.value }
        merged[code] = row
        list[#list + 1] = row
      end
      if entry.key == RESISTANCE_SCHOOLS[code].mod and tonumber(entry.value) then
        row.value = entry.value
      end
    end
  end
  return list
end

-- The armour entry out of the client's stat list, or nil when the client answered none. The
-- client's number always wins over the record's: it is the running client's own arithmetic on
-- the item in front of it, and the record's armour is what fills the gap when the item has not
-- loaded yet or the client was never asked. Never both. Pure.
function InfoPanel.ClientArmour(stats)
  if type(stats) ~= "table" then
    return nil
  end
  for _, entry in ipairs(stats) do
    if type(entry) == "table" and InfoPanel.IsArmourStat(entry.key) and tonumber(entry.value) then
      return entry
    end
  end
  return nil
end

-- One armour value as its row draws it: "365", never "+365". Armour is a base value the item
-- has rather than a bonus it adds, which is how the game tooltip writes it ("365 Armor"), and
-- it is the one row in the stat block that wears no sign. Bonus armour, stat 50 "Extra
-- armour", is a different thing and keeps its plus. nil for an armour of nothing. Pure.
function InfoPanel.ArmourText(value)
  local amount = tonumber(value)
  if not amount or amount <= 0 then
    return nil
  end
  return InfoPanel.StatNumber(amount)
end

-- The word for the armour row: the client's own RESISTANCE0_NAME where it has one ("Armor"),
-- and ours otherwise. UI/Client.lua is the one place a client global string is read, so the
-- record path and the client path say the same word.
local function armourLabel()
  local label = moduleCall(ItemTree.Client, "StatLabel", ARMOUR_STAT_KEY)
  if type(label) == "string" and label ~= "" then
    return label
  end
  return L["Armour"]
end

-- One StatPercentEditor share as the percentage it is. The build states the share of the stat
-- budget out of 10,000, which is 5833 for a stat worth 58 percent of it: the raw number means
-- nothing to a player and reads as a stat amount, which is exactly what it is not, so the only
-- shape this column ever draws it in is a percentage. nil for a share of nothing.
function InfoPanel.SharePercent(share)
  local value = tonumber(share)
  if not value or value <= 0 then
    return nil
  end
  return string.format(L["%d%%"], math.floor(value / 100 + 0.5))
end

-- A whole list of shares as one line: "Stamina 50%, Intellect 58%". This is what a stats_pct
-- change reads as on either side, so the Changed section never prints a raw share either.
function InfoPanel.ShareText(shares)
  if type(shares) ~= "table" then
    return nil
  end
  local parts = {}
  for _, entry in ipairs(shares) do
    if type(entry) == "table" then
      local percent = InfoPanel.SharePercent(entry[2])
      if percent then
        parts[#parts + 1] = statName(entry[1]) .. " " .. percent
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- How many a recipe makes: "2", or "1 to 2" for a range. nil where it makes one, which is the
-- ordinary case and wants no number at all.
function InfoPanel.CountText(min, max)
  local low = tonumber(min) or tonumber(max)
  local high = tonumber(max) or low
  if not low or not high then
    return nil
  end
  if low == high then
    if low <= 1 then
      return nil
    end
    return numberText(low)
  end
  return string.format(L["%s to %s"], numberText(low), numberText(high))
end

-- Text for one field in the panel's own style, for this build's value and for the baseline's
-- alike, so a change never writes the same number two ways. item is the record the field
-- belongs to, because a subclass only means something under its class. nil when the build
-- states nothing, or when the value is a shape this column does not draw.
function InfoPanel.FieldText(field, value, item)
  if value == nil then
    return nil
  end
  if field == "class" then
    return (classNames(value))
  end
  if field == "subclass" then
    local _, sub = classNames(item and item.c, value)
    return sub
  end
  if field == "bonding" then
    local text = BONDING[value]
    return text and L[text] or nil
  end
  if field == "inventory_type" then
    local text = SLOT_NAMES[value]
    return text and L[text] or nil
  end
  if field == "sell_price" or field == "buy_price" then
    local copper = positive(value)
    local text = copper and InfoPanel.MoneyText(copper) or nil
    -- Brief PS1 bundle prices: the buy price is for the vendor's bundle, "25c for 5"; the sell
    -- price is for one item, as the client states it.
    if text and field == "buy_price" then
      return InfoPanel.BundleText(text, item)
    end
    return text
  end
  if field == "item_set" then
    return setName(value)
  end
  -- A mask is a number no player can read. A mask that allows every class draws no row of its
  -- own, but a mask that moved still has to read on both sides of a change, so it is written
  -- here as the classes it names, or as the words for a mask that names them all.
  if field == "allowable_class" then
    local named = classList(value)
    if #named == 0 then
      return nil
    end
    local restricted = InfoPanel.ClassRestriction(named, classCount())
    if not restricted then
      return L["Any class"]
    end
    return table.concat(restricted, ", ")
  end
  -- The one field Diff writes as raw budget shares. Written here as percentages, so a change
  -- row reads "Stamina 50% to Stamina 60%" rather than "Stamina 5000 to Stamina 6000".
  if field == "stats_pct" then
    return InfoPanel.ShareText(value)
  end
  if field == "damage" then
    if type(value) ~= "table" then
      return nil
    end
    local low, high = tonumber(value[1]), tonumber(value[2])
    if not low or not high then
      return nil
    end
    return string.format(L["%s to %s"], numberText(low), numberText(high))
  end
  if field == "delay" then
    local ms = positive(value)
    return ms and string.format("%.2f", ms / 1000) or nil
  end
  -- Armour carries no sign on either side of a change, the way the row itself carries none,
  -- and an armour of nothing answers nil so the change falls back to Core's word for it,
  -- "none": the curves saying nothing about an item is not the same as 0 armour.
  if field == "armour" then
    return InfoPanel.ArmourText(value)
  end
  if type(value) == "table" then
    return nil
  end
  return numberText(value)
end

-- Damage per second from the two damage numbers and the weapon speed in milliseconds, to one
-- decimal the way the client writes it. nil when the build states no speed to divide by.
function InfoPanel.Dps(min, max, speedMs)
  local low, high, ms = tonumber(min), tonumber(max), tonumber(speedMs)
  if not low or not high or not ms or ms <= 0 then
    return nil
  end
  return string.format("%.1f", ((low + high) / 2) / (ms / 1000))
end

-- One fx entry as the row it draws: the trigger word, then the spell and the cooldown the
-- build states for it. Returns label, value, or nil for an entry that names no spell.
function InfoPanel.EffectText(fx)
  if type(fx) ~= "table" then
    return nil
  end
  local spellId = tonumber(fx[2])
  if not spellId then
    return nil
  end
  local trigger = effectTrigger(fx[1])
  local value = spellName(spellId) or ("spell " .. tostring(spellId))
  local cooldown = durationText(fx[4])
  if cooldown then
    value = value .. ", " .. cooldown
  end
  return L[trigger or "Effect"], value
end

-- "10 to 12". The design's change language, never arrows and never diff jargon.
function InfoPanel.ChangeText(old, new)
  return string.format(L["%s to %s"], tostring(old), tostring(new))
end

-- One side of a change in the panel's own style, falling back to the text the Diff module
-- already wrote for values this column does not draw (stat tables, reagent lists).
local function changeSide(change, which, item)
  -- Core answers a list field one line per entry, and the sides of such a line are the entry
  -- itself rather than a list of them. The one entry this column writes differently from the
  -- words Diff already wrote is a stat budget share: 5000 is not a number a player can read,
  -- and the whole point of this column's share handling is that it never draws one.
  if change.field == "stats_pct" and type(change[which]) == "table" then
    local share = InfoPanel.SharePercent(change[which][2])
    if share then
      return share
    end
  end
  -- A price of nothing is still a price, and the fact row writes it as money, so a change to
  -- or from it has to read as money on both sides: "0c to 1c", never "0 to 1c". FieldText
  -- answers nothing for a price of zero, because a row stating "sells for 0c" is noise.
  if MONEY_FIELDS[change.field] then
    local copper = tonumber(change[which])
    if copper then
      return InfoPanel.MoneyText(math.max(math.floor(copper), 0))
    end
  end
  local text = InfoPanel.FieldText(change.field, change[which], item)
  if text and text ~= "" then
    return text
  end
  return change[which .. "Text"] or InfoPanel.FieldText(change.field, change[which]) or "none"
end

-- The sentence Core writes an added or removed entry with. UI/Badges.lua takes the word out of
-- it for a badge hover, so it is asked first and the column never words the same line a second
-- way; the same locale key, read the same way, is the fallback for a client where that file did
-- not load. The marker is a control character, because nothing a locale writes can contain one.
local OP_PATTERNS = {
  added = L["%s added"],
  removed = L["%s removed"],
}

local function opWord(op)
  local word = moduleCall(ItemTree.Badges, "OpWord", op)
  if type(word) == "string" and word ~= "" then
    return word
  end
  local pattern = OP_PATTERNS[op]
  if type(pattern) ~= "string" then
    return nil
  end
  local ok, filled = pcall(string.format, pattern, "\1")
  local tail = nil
  if ok and type(filled) == "string" then
    tail = filled:match("\1%s*(.-)%s*$")
  end
  if type(tail) ~= "string" or tail == "" then
    return nil
  end
  return tail
end

-- One Diff line as the change row that draws it. Core answers one line per entry for a list
-- field (stats, effects, reagents and the rest) and says which of the three things each line
-- is: an entry that moved reads old to new, one that came reads as the new value with the word
-- after it, and one that went reads as the struck old value with the word standing where a new
-- value would, so the strike is never drawn through the word itself.
--
-- index keeps the row key unique, because one field now answers many lines. side is handed
-- "old" or "new" and answers that side in the caller's own style: an item column writes a
-- price as coins, a recipe writes what Diff already worded.
local function changeRow(change, index, side)
  local op = change.op
  local old, new = nil, nil
  if op == "added" then
    new = side("new")
  elseif op == "removed" then
    old = side("old")
  else
    old, new = side("old"), side("new")
  end
  local word = opWord(op)
  if word then
    if op == "added" and new then
      new = new .. " " .. word
    elseif op == "removed" then
      new = word
    end
  end
  local text
  if old and new then
    if op == "removed" then
      text = old .. " " .. new
    else
      text = InfoPanel.ChangeText(old, new)
    end
  else
    text = old or new or ""
  end
  return {
    kind = "change",
    key = "change:" .. tostring(change.field) .. ":" .. tostring(index),
    field = change.field,
    label = change.label or change.field,
    old = old,
    new = new,
    value = text,
    colorKey = COLOR_BODY,
  }
end

-- The uses line, worded by the tooltip block so the two never drift apart.
local function usesText(summary)
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.UsesText) == "function" then
    local ok, text, colorKey = pcall(tooltip.UsesText, summary)
    if ok and type(text) == "string" then
      return text, colorKey or COLOR_BODY
    end
  end
  return L["No known uses"], COLOR_MUTED
end

-- The view key for the fourth tab, read through Core/Edges.lua where that is loaded. Its own
-- function because the decision below and the row that carries it both ask for it, and a build
-- of Core without Edges has to fall back to the same word in both places.
local function disenchantsView()
  local edges = ItemTree.Edges
  if type(edges) == "table" and type(edges.DISENCHANTS) == "string" then
    return edges.DISENCHANTS
  end
  return "disenchants"
end

-- The direction the summary line at the foot of the column leads to, or nil for a line with
-- nothing behind it. The line is the counts Graph.Summary states, worded by UI/Tooltip.lua.
--
-- Every count in it but one is an edge that walks down from the root, which is the tree the
-- window's Used by tab draws: "Used in 19 recipes" is REAGENT_FOR, "2 quests" is the quest
-- edges either side of it, and "Teaches 1 recipe" is TEACHES, which Core/Edges.lua states as a
-- down edge whatever the word sounds like. "Made by 1 recipe" is PRODUCED_BY, the one that
-- walks up, and up is what the Sources tab draws. A summary that counts nothing at all is the
-- "No known uses" line, which leads nowhere and is not a link.
--
-- A predicted disenchant result is the one exception, and it is the last thing asked. It is not
-- a use and it is not counted in the line at all, so it only ever answers for an item that
-- counts nothing whatsoever: such an item read "No known uses" with nothing
-- behind it while its rows sat on the Disenchants into tab. Since brief W32 the item page draws
-- no summary line for that case at all (InfoPanel.Sections), and the answer is kept for
-- SummaryDirection, which still says the results walk down.
--
-- The Edges values are read through the module rather than written here, so the two never
-- drift; a build of Core with no Edges falls back to the words Frame falls back to. Pure.
function InfoPanel.SummaryView(summary)
  if type(summary) ~= "table" then
    return nil
  end
  local edges = ItemTree.Edges
  local uses = (type(edges) == "table" and edges.USES) or "uses"
  local sources = (type(edges) == "table" and edges.SOURCES) or "sources"
  local function counted(value)
    local number = tonumber(value)
    return number ~= nil and number > 0
  end
  -- Brief P5b: a class spell the item is the reagent for is a row of the Uses view too.
  -- Brief RB1: the quests the item only comes from (questRewards, brief K24e) are the Sources tab's
  -- rows, so a line counting nothing but those leads there; Graph.Summary counts the predicted rewards
  -- now (Graph.PredictedRewardQuests), 245 items whose one quest is such a reward.
  local needed = (tonumber(summary.quests) or 0) - (tonumber(summary.questRewards) or 0)
  if counted(summary.usedIn) or counted(needed) or counted(summary.teaches) or counted(summary.classSpells) then
    return uses
  end
  if counted(summary.producedBy) or counted(summary.questRewards) then
    return sources
  end
  -- Nothing at all is counted, including the tool count the line words but this has never led
  -- anywhere for: a line that says one thing and leads to another is worse than a plain one.
  if summary.disenchant and not counted(summary.toolFor) then
    return disenchantsView()
  end
  -- The third view is not answered here on purpose: nothing the summary line counts is a
  -- requirement, and inventing a line to lead to Requires would be inventing a fact.
  return nil
end

-- Brief GS3: the colour the guessed sources line is written in, the guess tier's own (the owner's
-- muted rose), and kept on hover rather than turned link gold: it is a quiet line under the
-- summary, and the Sources rows it leads to wear the same colour.
InfoPanel.GUESS_COLOR = "ITEMTREE_COLOR_SEMANTIC_GUESS"

--- Brief GS3: the one line an item whose Sources view holds guessed rows carries under its summary
--- line ("2 guessed sources, see Sources"), as a section { key, rows }, or nil for none. It leads
--- to the Sources view. count is how many guessed rows that view holds once the real rows beside
--- them have shadowed what they can (Core/ViewModel.lua ViewModel.GuessCount). Pure.
function InfoPanel.GuessSection(count)
  count = tonumber(count) or 0
  if count < 1 then
    return nil
  end
  local text
  if count == 1 then
    text = L["1 guessed source, see Sources"]
  else
    text = string.format(L["%d guessed sources, see Sources"], count)
  end
  local edges = ItemTree.Edges
  local sources = (type(edges) == "table" and edges.SOURCES) or "sources"
  return {
    key = "guesses",
    rows = {
      { kind = "fact", key = "guesses", value = text, colorKey = InfoPanel.GUESS_COLOR, link = sources, quiet = true },
    },
  }
end

-- The same decision as a plain direction, for a caller that still thinks in directions (the
-- browser harness). The view is what the row carries and what InfoPanel.FollowLink takes.
function InfoPanel.SummaryDirection(summary)
  local view = InfoPanel.SummaryView(summary)
  if not view then
    return nil
  end
  local edges = ItemTree.Edges
  if type(edges) == "table" and type(edges.ViewDirection) == "function" then
    local ok, direction = pcall(edges.ViewDirection, view)
    if ok and type(direction) == "string" then
      return direction
    end
  end
  if view == "sources" then
    return "up"
  end
  return "down"
end

-- The ordered sections for one item record, as { key, title, rows }. Pure.
--
-- item is an item record or a removed item's baseline summary, summary is Graph.Summary(id)
-- (nil leaves the uses line off, which is what a removed item wants: this build has no uses
-- to count for it), changes is Diff.GetChanges("items", id) or nil, and showChanges is the
-- window's tick box. With it off, every field is this build's value and no change row is
-- drawn anywhere; with it on, a changed field reads old to new and the changes no fact row
-- carries are collected under one heading so the toggle never hides one.
--
-- extras is what only a client can answer: { stats = { { key, label, value } } } from
-- ItemTree.ItemStats. It is the first choice for the stat block, the record's own stats field
-- the second, and the budget shares the last. extras.found is Diff.FoundLine's sentence for an
-- item the Discovery Miner found on the beta realm (brief D3), drawn as one fact row.
--
-- Brief D5: extras.realm is what the realm check says about a withheld item ("Not yet found on
-- your realm", "Checking your realm", "No one on your realm has found this item yet." or "Found
-- on your realm."), drawn as one fact row, and extras.era says the record is the Classic Era row
-- Core/Data.lua serves for it, which puts one line above the facts saying so.
-- Brief K20b: the item page's "Auction" fact row's words from { copper, source }, "15g 20s
-- (Auctionator)" in coins, or nil where there is no auction price. Pure.
function InfoPanel.AuctionText(auction)
  if type(auction) ~= "table" then
    return nil
  end
  local copper = positive(auction.copper)
  if not copper then
    return nil
  end
  local text = InfoPanel.MoneyText(copper)
  if type(auction.source) == "string" and auction.source ~= "" then
    text = string.format(L["%s (%s)"], text, auction.source)
  end
  return text
end

-- Brief K20b: the auction price of one item, { copper, source }, from Core/Prices.lua
-- (Prices.Auction: the installed auction addons' own prices, cached a minute; never a client item
-- query), or nil.
function InfoPanel.AuctionPrice(itemId)
  local prices = ItemTree.Prices
  if type(prices) ~= "table" or type(prices.Auction) ~= "function" then
    return nil
  end
  local ok, copper, source = pcall(prices.Auction, itemId)
  if not ok or tonumber(copper) == nil or tonumber(copper) <= 0 then
    return nil
  end
  return { copper = tonumber(copper), source = type(source) == "string" and source or nil }
end

-- Brief K20-wire (design K20 section 3): the item page's "Disenchant" fact row's words from
-- { copper, likely }: "about 10g" in coins where a material has an auction price, else the band's
-- likely result ("75% Soul Dust"), or nil for an item that does not disenchant. Pure.
function InfoPanel.DisenchantText(disenchant)
  if type(disenchant) ~= "table" then
    return nil
  end
  local copper = positive(disenchant.copper)
  if copper then
    return string.format(L["about %s"], InfoPanel.MoneyText(copper))
  end
  if type(disenchant.likely) == "string" and disenchant.likely ~= "" then
    return disenchant.likely
  end
  return nil
end

-- Brief K20-wire: the expected disenchant value of one shipped row, { copper, likely }, from
-- Core/DisenchantValue.lua (the shipped band and the materials' auction prices, cached a minute
-- per material; never a client item query), or nil for an item that does not disenchant. A fact
-- about the item, so it is shown whatever the player's Enchanting; the tooltip's disenchant states
-- are the player's own (design question 5, assumed).
function InfoPanel.DisenchantInfo(item)
  local values = ItemTree.DisenchantValue
  if type(values) ~= "table" or type(values.ForItem) ~= "function" or type(item) ~= "table" then
    return nil
  end
  local ok, expected = pcall(values.ForItem, item)
  if not ok or type(expected) ~= "table" then
    return nil
  end
  local likely = nil
  if type(values.LikelyWords) == "function" then
    local worded, words = pcall(values.LikelyWords, expected)
    likely = worded and words or nil
  end
  return { copper = tonumber(expected.copper), likely = likely }
end

function InfoPanel.Sections(item, summary, changes, showChanges, extras)
  local sections = {}
  if type(item) ~= "table" then
    return sections
  end
  showChanges = showChanges and true or false
  changes = changes or {}

  -- Core answers one line per entry for a list field, so a field can carry several lines. A
  -- fact row draws one value and claims a field only where the field moved once and moved as a
  -- value; everything else falls through to the Changed section, which draws a line each.
  local byField, used = {}, {}
  for _, change in ipairs(changes) do
    if type(change) == "table" and change.field then
      local lines = byField[change.field]
      if not lines then
        lines = {}
        byField[change.field] = lines
      end
      lines[#lines + 1] = change
    end
  end

  local function claimable(field)
    local lines = field and byField[field] or nil
    if not lines or #lines ~= 1 then
      return nil
    end
    local change = lines[1]
    if change.op ~= nil and change.op ~= "changed" then
      return nil
    end
    return change
  end

  -- A row, or nil where the build states nothing. A field this build moved is claimed here
  -- whether or not the tick box is on, so it never reads twice once the tick box goes on.
  local function fact(key, label, value, field, oldText)
    if value == nil or value == "" then
      return nil
    end
    local row = { kind = "fact", key = key, field = field, label = label, value = value, colorKey = COLOR_BODY }
    local change = claimable(field)
    if change then
      used[field] = true
      if showChanges then
        local old = oldText or changeSide(change, "old", item)
        row.kind, row.old, row.new, row.value = "change", old, value, InfoPanel.ChangeText(old, value)
      end
    end
    return row
  end

  local function push(rows, row)
    if row then
      rows[#rows + 1] = row
    end
  end

  local function section(key, title, rows)
    if #rows > 0 then
      local entry = { key = key, title = title, rows = rows }
      sections[#sections + 1] = entry
      return entry
    end
    return nil
  end

  -- Brief DV1: an item no player can get, opened directly, says so first, in one muted line
  -- right under the header. extras.unobtainable is Data:HiddenKind's answer, 1 or 2.
  local unobtainable = InfoPanel.UnobtainableLine(type(extras) == "table" and extras.unobtainable or nil)
  if unobtainable then
    section(
      "unobtainable",
      nil,
      { { kind = "fact", key = "unobtainable", value = unobtainable, colorKey = COLOR_MUTED } }
    )
  end

  -- An item this build withholds leads with the sentence that says so, because it is why
  -- everything under it is as thin as it is: the class, the subclass, the slot and the icon are
  -- every fact the build states, and not one line here is ever taken from the baseline. A stub
  -- that carries a name got it from the running client or from the collector's own note, which
  -- means somebody on this realm has found it.
  if item.u then
    local text = L["Undiscovered in Forever. Its details appear once someone on your realm finds it."]
    if type(item.n) == "string" and item.n ~= "" then
      text = L["Discovered on your realm. Not yet in ItemTree data."]
    end
    section("undiscovered", nil, { { kind = "para", key = "undiscovered", value = text, colorKey = COLOR_MUTED } })
  end

  -- An id the baseline had an Item row for and would not name, which this build names. It wears
  -- the New medallion in the header like anything else that is new to a player of this client
  -- (Core/Diff.lua), and this is the one line that says why it is on. Its own section, and never
  -- a row under "Changed in Forever": no field moved, and it is not the tick box's to hide.
  local discovered = byField["discovered"]
  if discovered and discovered[1] then
    used["discovered"] = true
    local text = discovered[1].text
    if type(text) == "string" and text ~= "" then
      section("discovered", nil, { { kind = "para", key = "discovered", value = text, colorKey = COLOR_MUTED } })
    end
  end

  -- When the Discovery Miner first found the item on the beta realm, as one plain fact row. The
  -- sentence is Core's (Diff.FoundLine). Brief TB6: the hover tooltip no longer carries it.
  local found = type(extras) == "table" and extras.found or nil
  if type(found) == "string" and found ~= "" then
    section("found", nil, { { kind = "fact", key = "found", value = found, colorKey = COLOR_MUTED } })
  end

  -- Brief D5: whether anybody on this realm has found a withheld item, then, for one drawn from
  -- its Classic Era row, the line that says every fact below is Classic Era's.
  local realm = type(extras) == "table" and extras.realm or nil
  if type(realm) == "string" and realm ~= "" then
    section("realm", nil, { { kind = "fact", key = "realm", value = realm, colorKey = COLOR_MUTED } })
  end
  if type(extras) == "table" and extras.era then
    section("era", nil, {
      {
        kind = "para",
        key = "era",
        value = L["Classic Era details. Forever may have changed this."],
        colorKey = COLOR_MUTED,
      },
    })
  end

  local basics = {}
  push(basics, fact("type", L["Type"], InfoPanel.FieldText("class", item.c, item), "class"))
  push(basics, fact("subtype", L["Subtype"], InfoPanel.FieldText("subclass", item.sc, item), "subclass"))
  push(basics, fact("slot", L["Slot"], InfoPanel.FieldText("inventory_type", item.it, item), "inventory_type"))
  push(basics, fact("ilvl", L["Item level"], InfoPanel.FieldText("item_level", positive(item.il)), "item_level"))
  push(
    basics,
    fact("reqlevel", L["Required level"], InfoPanel.FieldText("required_level", positive(item.rl)), "required_level")
  )
  push(basics, fact("binds", L["Binds"], InfoPanel.FieldText("bonding", positive(item.b)), "bonding"))
  push(basics, fact("stack", L["Stack size"], InfoPanel.FieldText("stack_size", positive(item.st)), "stack_size"))
  push(basics, fact("unique", L["Unique"], InfoPanel.FieldText("max_count", positive(item.mc)), "max_count"))
  section("item", nil, basics)

  local weapon = {}
  local damage = type(item.dmg) == "table" and item.dmg or nil
  push(weapon, fact("damage", L["Damage"], InfoPanel.FieldText("damage", damage, item), "damage"))
  push(weapon, fact("speed", L["Speed"], InfoPanel.FieldText("delay", positive(item.dl)), "delay"))
  -- Damage per second belongs beside the damage and the speed it is worked out from, so the
  -- Weapon section is where it is drawn and the client's own damage per second stat is left out
  -- of the stat block below. Both are the same number: the owner saw it twice.
  local drewDps = false
  if damage then
    local dps = InfoPanel.Dps(damage[1], damage[2], item.dl)
    if dps then
      push(weapon, fact("dps", L["Damage per second"], dps))
      drewDps = true
    end
  end
  section("weapon", L["Weapon"], weapon)

  -- Stats, in the order of who can be trusted to state a number a player can read. The client
  -- has worked the real amount out for every item it has loaded, whatever shape the build
  -- states it in, so it is asked first. The record's own stats field is next, which is what a
  -- Classic Era layout states outright and what the pipeline may one day work out for a retail
  -- shaped one. Only where neither answers are the budget shares drawn, and then as
  -- percentages under a heading that says what they are: they are not stats.
  local realStats = nil
  if type(extras) == "table" and type(extras.stats) == "table" and #extras.stats > 0 then
    realStats = InfoPanel.ClientStatsOnce(extras.stats, statName)
  end
  local stats = type(item.stats) == "table" and #item.stats > 0 and item.stats or nil
  local shares = type(item.pct) == "table" and #item.pct > 0 and item.pct or nil

  -- Armour leads the block, which is where the game's own tooltip writes it ("365 Armor"),
  -- and it carries no plus sign because it is a base value and not a bonus. Same two sources
  -- in the same order as the stats: the client's own number where it answered one, and the
  -- record's computed armour where it did not or was never asked. Never both, and the row is
  -- in the same place either way so the block reads the same whichever answered.
  local clientArmour = InfoPanel.ClientArmour(realStats)
  local armourRow
  if clientArmour then
    local label = clientArmour.label
    if type(label) ~= "string" or label == "" then
      label = armourLabel()
    end
    armourRow = fact("armour", label, InfoPanel.ArmourText(clientArmour.value), "armour")
  else
    armourRow = fact("armour", armourLabel(), InfoPanel.ArmourText(item.arm), "armour")
  end

  local statRows = {}
  push(statRows, armourRow)
  if realStats then
    for index, entry in ipairs(realStats) do
      local key, amount, label = nil, nil, nil
      if type(entry) == "table" then
        key, amount, label = entry.key, entry.value, entry.label
      end
      -- The one stat the Weapon section already states. Left in where there is no Weapon
      -- section, because then the client is the only one that knows the number at all. Armour
      -- is already the first row above, so the client's own entry for it is passed over here.
      if not (drewDps and InfoPanel.IsDpsStat(key)) and not InfoPanel.IsArmourStat(key) then
        if type(label) ~= "string" or label == "" then
          label = statName(key)
        end
        push(statRows, fact("stat" .. index, label, InfoPanel.StatText(key, amount)))
      end
    end
    section("stats", L["Stats"], statRows)
  elseif stats then
    for index, entry in ipairs(stats) do
      push(statRows, fact("stat" .. index, statName(entry[1]), InfoPanel.StatText(nil, entry[2] or 0)))
    end
    section("stats", L["Stats"], statRows)
  else
    -- Armour with no stat list at all, which is most of the white and grey armour in the
    -- build: it still leads a Stats block of its own, because the tooltip says "40 Armor"
    -- and nothing else.
    if armourRow then
      section("stats", L["Stats"], { armourRow })
    end
    if shares then
      local shareRows = {}
      for index, entry in ipairs(shares) do
        push(shareRows, fact("share" .. index, statName(entry[1]), InfoPanel.SharePercent(entry[2])))
      end
      -- Flagged so the tooltip block leaves it out: a percentage of a stat budget is a fact
      -- about the build, not a line the client's own item tooltip would ever carry. Its own
      -- section rather than the armour one, because armour is a number and these are not.
      local budget = section("stats", L["Stat budget"], shareRows)
      if budget then
        budget.budget = true
      end
    end
  end

  local effects = {}
  if type(item.fx) == "table" then
    for index, entry in ipairs(item.fx) do
      local label, text = InfoPanel.EffectText(entry)
      if label then
        push(effects, fact("fx" .. index, label, text))
      end
    end
  end
  section("effects", L["Effects"], effects)

  local requires = {}
  local skill = skillLabel(item.sk, item.skr)
  if skill then
    -- A rank that moved is worth reading as a rank, so the baseline side is written the same
    -- way the current one is rather than as the bare number Diff carries.
    local rankChange = claimable("required_skill_rank")
    local oldSkill = rankChange and skillLabel(item.sk, rankChange.old) or nil
    push(requires, fact("skill", L["Skill"], skill, "required_skill_rank", oldSkill))
  end
  -- A mask that allows every class allows nothing in particular, so it draws no row at all.
  local classes = InfoPanel.ClassRestriction(classList(item.ac), classCount())
  if classes then
    push(requires, fact("classes", L["Classes"], table.concat(classes, ", "), "allowable_class"))
  end
  section("requires", L["Requires"], requires)

  local other = {}
  push(other, fact("set", L["Set"], InfoPanel.FieldText("item_set", item.set, item), "item_set"))
  push(other, fact("durability", L["Durability"], InfoPanel.FieldText("durability", positive(item.dur)), "durability"))
  -- Brief PS1 bundle prices: the item goes in for its vs, "25c for 5".
  push(other, fact("buy", L["Buy price"], InfoPanel.FieldText("buy_price", positive(item.bp), item), "buy_price"))
  push(other, fact("sell", L["Sell price"], InfoPanel.FieldText("sell_price", positive(item.sp)), "sell_price"))
  -- Brief K20b (design K20 section 3): beside the sell price, the auction price an installed
  -- auction addon holds, with the addon's name (extras.auction, InfoPanel.AuctionText).
  push(other, fact("auction", L["Auction"], InfoPanel.AuctionText(type(extras) == "table" and extras.auction or nil)))
  -- Brief K20-wire: beside it, what disenchanting the item is worth (extras.disenchant,
  -- InfoPanel.DisenchantText).
  local disenchantWords = InfoPanel.DisenchantText(type(extras) == "table" and extras.disenchant or nil)
  push(other, fact("disenchant", L["Disenchant"], disenchantWords))
  section("other", nil, other)

  -- Brief SET2: the set's own list names an undiscovered twin of this piece, folded into its row
  -- while Merge recipes is on (Core/Graph.lua Graph.SetTwinText). One muted line under the facts.
  local setTwin = type(extras) == "table" and extras.setTwin or nil
  if type(setTwin) == "string" and setTwin ~= "" then
    section("settwin", nil, { { kind = "fact", key = "settwin", value = setTwin, colorKey = COLOR_MUTED } })
  end

  -- Whatever moved that no fact row states: a stat list, an icon swap, a field this column
  -- does not draw. Only while the tick box is on, so off is this build and nothing else.
  if showChanges then
    local rest = {}
    for index, change in ipairs(changes) do
      if type(change) == "table" and change.field and not used[change.field] then
        rest[#rest + 1] = changeRow(change, index, function(which)
          return changeSide(change, which, item)
        end)
      end
    end
    section("changed", L["Changed in Forever"], rest)
  end

  -- The uses line, and the direction it leads to where it leads anywhere. The row carries the
  -- direction and nothing else: the pane is what draws a link in the link gold, so the same
  -- fact worded into a client tooltip stays the colour a tooltip line is.
  --
  -- An item whose only content is a predicted disenchant result has no line at all (brief W32,
  -- the owner found "Disenchants into predicted results" added little): its rows are read on the
  -- Disenchants into tab, and "No known uses" leading there would say one thing and open another.
  local view = summary ~= nil and InfoPanel.SummaryView(summary) or nil
  if summary ~= nil and view ~= disenchantsView() then
    local text, colorKey = usesText(summary)
    local row = { kind = "fact", key = "uses", value = text, colorKey = colorKey }
    row.link = view
    section("uses", nil, { row })
  end

  return sections
end

-- Badge kinds for the header, most urgent first and at most two. Badges is loaded before this
-- file, but it is read through a type check so the panel still draws without it.
local function sortBadges(kinds)
  if type(kinds) ~= "table" then
    return {}
  end
  local badges = ItemTree.Badges
  if badges and type(badges.Sort) == "function" then
    local ok, sorted = pcall(badges.Sort, kinds, 2)
    if ok and type(sorted) == "table" then
      return sorted
    end
  end
  local out = {}
  for _, kind in ipairs(kinds) do
    if type(kind) == "string" then
      out[#out + 1] = kind
    end
  end
  return out
end

-- The lowest quality that wears a coloured rarity frame. The client's own item button draws no
-- frame below uncommon: poor and common state nothing worth a colour, and a white frame over a
-- pale icon reads as a fault rather than as a fact. See SetItemButtonQuality in
-- Blizzard_ItemButton/Classic/ItemButtonTemplate.lua, which is the same file on the classic_era
-- and the classic_beta branch of the wow-ui-source mirror.
local QUALITY_EDGE_MIN = 2

-- The Theme colour key the rarity frame over the header icon is tinted with, or nil for a root
-- that wears no frame at all: no quality, a quality below uncommon, or a quality this build of
-- the Theme has no colour for (a white frame says nothing, and a guessed colour says worse than
-- nothing). A spell, an enchant and a quest root state no quality, so they come back nil and
-- keep the plain icon. Pure.
function InfoPanel.QualityEdge(quality)
  local value = tonumber(quality)
  if not value or value < QUALITY_EDGE_MIN then
    return nil
  end
  local names = Theme and Theme.QUALITY_NAMES
  if type(names) ~= "table" or names[value] == nil then
    return nil
  end
  if not Theme or type(Theme.QualityKey) ~= "function" then
    return nil
  end
  local ok, key = pcall(Theme.QualityKey, value)
  if not ok or type(key) ~= "string" then
    return nil
  end
  return key
end

-- The header line: the item name, the Theme colour key for its quality, the quality itself so
-- a client can reach for its own ITEM_QUALITY_COLORS, and the badges beside the name. item is
-- an item record or a removed item's baseline summary.
function InfoPanel.Header(item, badges)
  local name, quality
  if type(item) == "table" then
    name = type(item.n) == "string" and item.n or nil
    quality = tonumber(item.q)
    if not name and item.u then
      -- Core decides what a withheld item is called ("Undiscovered mail chest"), so the header
      -- and the tree row never disagree about it.
      local named = moduleCall(ItemTree.Graph, "UndiscoveredName", item)
      if type(named) == "string" and named ~= "" then
        name = named
      end
    end
  end
  return {
    name = name or L["Unknown item"],
    quality = quality,
    -- Theme owns the quality to colour key table. ITEM_QUALITY_COLORS wins on a client that
    -- has it (see nameColor), so this is what the specs and a bare client see.
    colorKey = Theme.QualityKey(quality),
    badges = sortBadges(badges),
  }
end

-- The header line for a spell root: "Spell: Enchant 2H Weapon - Strength (7745)" in the title
-- colour, the recipe's own icon, and the marks the diff put on it. info is Graph.SpellInfo.
function InfoPanel.SpellHeader(info)
  local kinds = {}
  local name, icon
  if type(info) == "table" then
    name = type(info.title) == "string" and info.title or info.name
    icon = info.icon
    if info.new then
      kinds[#kinds + 1] = "new"
    end
    if info.changed then
      kinds[#kinds + 1] = "changed"
    end
  end
  return {
    name = name or L["Unknown spell"],
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = sortBadges(kinds),
    icon = icon,
  }
end

-- An item's name for a list that states ids and nothing else, falling back to the honest
-- "Item 1234" rather than a bare number.
local function itemLabel(itemId)
  local id = tonumber(itemId)
  if not id then
    return nil
  end
  local item = dataItem(id)
  if type(item) == "table" and type(item.n) == "string" and item.n ~= "" then
    return item.n
  end
  local fallback = moduleCall(ItemTree.Graph, "Fallback", "item", id)
  if type(fallback) == "string" and fallback ~= "" then
    return fallback
  end
  return tostring(id)
end

-- The ordered sections for a spell root, as { key, title, rows }. Pure.
--
-- info is Graph.SpellInfo(spellId), or the same shape built for an enchant; description is
-- what the client says the spell does (ItemTree.SpellDescription), which is nil until the
-- client has loaded the text and may stay nil on a client that never will. showChanges is the
-- window's tick box, and with it on the recipe's own change lines are drawn under one heading.
function InfoPanel.SpellSections(info, description, showChanges)
  local sections = {}
  if type(info) ~= "table" then
    return sections
  end
  showChanges = showChanges and true or false

  local function push(rows, row)
    if row then
      rows[#rows + 1] = row
    end
  end

  local function fact(key, label, value)
    if value == nil or value == "" then
      return nil
    end
    return { kind = "fact", key = key, label = label, value = value, colorKey = COLOR_BODY }
  end

  local function section(key, title, rows)
    if #rows > 0 then
      sections[#sections + 1] = { key = key, title = title, rows = rows }
    end
  end

  local facts = {}
  push(facts, fact("profession", L["Profession"], info.skillName))
  -- An item combine has no profession at all: it is cast by USING an item, and that item is
  -- what the line says in its place. Several items cast 53 of the 358 combines in build
  -- 1.60.1.69913, so the line names all of them.
  if info.combine and type(info.via) == "table" and #info.via > 0 then
    local names = {}
    for index, entry in ipairs(info.via) do
      names[index] = entry.name or itemLabel(entry.itemId)
    end
    push(facts, fact("usedfrom", L["Used from"], table.concat(names, ", ")))
  end
  local rank = tonumber(info.requiredSkill)
  if rank and rank > 0 then
    push(facts, fact("rank", L["Required skill"], numberText(rank)))
  end
  if type(info.creates) == "table" then
    local made = info.creates.name or itemLabel(info.creates.itemId)
    local count = InfoPanel.CountText(info.creates.min, info.creates.max)
    if count then
      made = string.format(L["%s x%s"], made, count)
    end
    push(facts, fact("creates", L["Creates"], made))
  end
  if type(info.enchant) == "table" then
    push(facts, fact("enchant", L["Enchants"], info.enchant.name))
  end
  push(facts, fact("cooldown", L["Cooldown"], durationText(info.cooldown)))
  if info.trainerTaught == true then
    push(facts, fact("trainer", L["Learned from"], L["A trainer"]))
  end
  section("spell", nil, facts)

  local reagents = {}
  for index, reagent in ipairs(info.reagents or {}) do
    if type(reagent) == "table" then
      local name = reagent.name or itemLabel(reagent.itemId)
      push(reagents, fact("reagent" .. index, name, numberText(reagent.count or 1)))
    end
  end
  section("reagents", L["Reagents"], reagents)

  local tools = {}
  for index, tool in ipairs(info.tools or {}) do
    if type(tool) == "table" then
      local name = tool.name or (tool.itemId and itemLabel(tool.itemId)) or nil
      push(tools, fact("tool" .. index, nil, name))
    end
  end
  section("tools", L["Tools"], tools)

  local taught = {}
  for index, itemId in ipairs(info.taughtBy or {}) do
    push(taught, fact("taught" .. index, nil, itemLabel(itemId)))
  end
  section("taughtby", L["Taught by"], taught)

  -- What the spell does, in the client's own words. A client that has not loaded the text says
  -- so rather than leaving the column silent, which is what left the owner guessing.
  local about = {}
  if type(description) == "string" and description ~= "" then
    about[#about + 1] = { kind = "para", key = "description", value = description, colorKey = COLOR_BODY }
  else
    about[#about + 1] = { kind = "para", key = "description", value = L["No description"], colorKey = COLOR_MUTED }
  end
  section("about", nil, about)

  if showChanges then
    local rest = {}
    for index, change in ipairs(info.changes or {}) do
      if type(change) == "table" and change.field then
        rest[#rest + 1] = changeRow(change, index, function(which)
          return change[which .. "Text"] or "none"
        end)
      end
    end
    section("changed", L["Changed in Forever"], rest)
    if info.new and #rest == 0 then
      section("new", nil, { { kind = "fact", key = "new", value = L["New in Forever"], colorKey = COLOR_MUTED } })
    end
  end

  return sections
end

--------------------------------------------------------------------------------
-- EXPERIMENTAL (brief E25), the modes that ask for the card ("card" and "all", brief E30): the
-- Recipe card the column draws while a craft row in the tree is hovered or under the keyboard
-- cursor.
--
-- It is drawn at the very bottom of the column, under the root's own sections, so nothing above
-- it moves as the pointer travels down the tree: a card that pushed the item's own facts about
-- would be worse than no card. UI/Tree.lua hands over the craft's spell key and the ingredient
-- lists Core already worked out (row.ingredients, row.tools), so nothing here walks the graph
-- for an answer that is already in hand and no item is ever queried.
--
-- Everything in this block is reached from InfoPanel.SetRecipe and from nowhere else, so the
-- whole mode comes out again with it.
--------------------------------------------------------------------------------

--- The inline texture escape for an icon a row carries, or "" where there is none to draw. An
--- Assets key goes through Assets.Markup, which is the one place a key becomes a path; anything
--- else is a file data id out of the generated data or a texture path, which the client draws
--- from the same escape. Pure.
function InfoPanel.IconMarkup(icon, pixels)
  if icon == nil then
    return ""
  end
  local box = math.floor(tonumber(pixels) or COIN)
  if box < 1 then
    box = 1
  end
  if type(icon) == "string" and Assets and type(Assets.Has) == "function" and Assets.Has(icon) then
    local ok, markup = pcall(Assets.Markup, icon, box)
    if ok and type(markup) == "string" then
      return markup
    end
    return ""
  end
  if type(icon) ~= "string" and type(icon) ~= "number" then
    return ""
  end
  return string.format("|T%s:%d:%d|t", tostring(icon), box, box)
end

--- The Recipe card as one section, or nil where there is nothing to draw. Pure.
---
--- card is { key, ingredients, tools }: the craft's spell key and the lists the tree row
--- carries. info is Graph.SpellInfo for that spell, which is what states the craft's name, the
--- skill line it asks for, what it makes and who teaches it; a card with no info behind it still
--- draws its ingredients, because those are the answer the player was after.
---
--- Rows are the column's own { kind, key, label, value, colorKey }: the craft's name and skill
--- line lead, then one row per ingredient with its icon and count, then the tools, what it makes
--- and where it is learnt.
function InfoPanel.RecipeSections(card, info)
  if type(card) ~= "table" then
    return {}
  end
  local ingredients = type(card.ingredients) == "table" and card.ingredients or {}
  local tools = type(card.tools) == "table" and card.tools or {}
  info = type(info) == "table" and info or {}
  local rows = {}

  local name = info.name
  if type(name) == "string" and name ~= "" then
    rows[#rows + 1] = { kind = "fact", key = "craft", value = name, colorKey = COLOR_TITLE }
  end
  if type(info.skillText) == "string" and info.skillText ~= "" then
    rows[#rows + 1] = { kind = "fact", key = "craftskill", value = info.skillText, colorKey = COLOR_MUTED }
  end

  for index, part in ipairs(ingredients) do
    local label = type(part.name) == "string" and part.name or ""
    local markup = InfoPanel.IconMarkup(part.icon, FONT_SM)
    if markup ~= "" then
      label = markup .. " " .. label
    end
    local colorKey = COLOR_BODY
    if Theme and type(Theme.QualityKey) == "function" and part.quality ~= nil then
      local ok, key = pcall(Theme.QualityKey, part.quality)
      if ok and type(key) == "string" then
        colorKey = key
      end
    end
    local count = nil
    if part.quantity ~= nil then
      count = InfoPanel.CountText(part.quantity, part.quantityMax) or numberText(part.quantity)
    end
    rows[#rows + 1] = {
      kind = "fact",
      key = "reagent" .. index,
      label = label,
      labelColorKey = colorKey,
      value = count or "",
      colorKey = COLOR_MUTED,
    }
  end

  local toolNames = {}
  for _, tool in ipairs(tools) do
    if type(tool.name) == "string" and tool.name ~= "" then
      toolNames[#toolNames + 1] = tool.name
    end
  end
  if #toolNames > 0 then
    rows[#rows + 1] = {
      kind = "fact",
      key = "crafttools",
      label = L["Tools"],
      value = table.concat(toolNames, ", "),
      colorKey = COLOR_BODY,
    }
  end

  if type(info.creates) == "table" then
    local made = info.creates.name or itemLabel(info.creates.itemId)
    local count = InfoPanel.CountText(info.creates.min, info.creates.max)
    if count then
      made = string.format(L["%s x%s"], made, count)
    end
    if made then
      rows[#rows + 1] = { kind = "fact", key = "craftmakes", label = L["Creates"], value = made, colorKey = COLOR_BODY }
    end
  end

  -- Who teaches it: the recipe item where the build names one, and the trainer where it names
  -- none, which is the ordinary case and the one a player cannot work out from the row.
  local taught = {}
  for _, itemId in ipairs(type(info.taughtBy) == "table" and info.taughtBy or {}) do
    local label = itemLabel(itemId)
    if type(label) == "string" and label ~= "" then
      taught[#taught + 1] = label
    end
  end
  if #taught > 0 then
    rows[#rows + 1] = {
      kind = "fact",
      key = "craftteacher",
      label = L["Taught by"],
      value = table.concat(taught, ", "),
      colorKey = COLOR_BODY,
    }
  elseif info.skillName then
    rows[#rows + 1] =
      { kind = "fact", key = "craftteacher", label = L["Learned from"], value = L["A trainer"], colorKey = COLOR_BODY }
  end

  if #rows == 0 then
    return {}
  end
  return { { key = "recipe", title = L["Recipe"], rows = rows } }
end

-- The quest view's sections, in order: what the quest needs, what starts it, what it gives.
--
-- Each one is an edge type read by its name off whatever Core/Edges.lua carries, never by
-- holding the type table: the agent adding the quest edges works in parallel with this one, and
-- a name that matches nothing simply draws no edges and so no section, which is exactly what a
-- build without them should show.
--
-- The direction is the edge type's own, stated here so this file never has to ask for an edge
-- type that may not exist yet: QUEST_REQUIRES and QUEST_STARTED_BY walk up from the quest and
-- QUEST_REWARDS walks down (see the round D quest contract).
local QUEST_SECTIONS = {
  { key = "questrequires", title = "Requires", edge = "QUEST_REQUIRES", direction = "up", count = true },
  { key = "queststartedby", title = "Started by", edge = "QUEST_STARTED_BY", direction = "up" },
  { key = "questrewards", title = "Rewards", edge = "QUEST_REWARDS", direction = "down", choice = true },
}

-- The direction words, from Core/Edges.lua where it is loaded, so the two never drift.
local function directionWord(which)
  local edges = ItemTree.Edges
  if type(edges) == "table" then
    local word = edges.DOWN
    if which == "up" then
      word = edges.UP
    end
    if type(word) == "string" and word ~= "" then
      return word
    end
  end
  return which
end

-- The edges of one named type leaving a node, or an empty list. Graph is read through a type
-- check and pcall'd like every other module here, so a half loaded addon draws a shorter column
-- rather than raising mid draw.
local function edgesOfType(key, name, direction, opts)
  local out = {}
  local graph = ItemTree.Graph
  if type(key) ~= "string" or type(graph) ~= "table" or type(graph.Children) ~= "function" then
    return out
  end
  local ok, edges = pcall(graph.Children, key, direction, opts)
  if not ok or type(edges) ~= "table" then
    return out
  end
  for _, edge in ipairs(edges) do
    local def = type(edge) == "table" and edge.type or nil
    if type(def) == "table" and def.name == name and type(edge.target) == "string" then
      out[#out + 1] = edge
    end
  end
  return out
end

-- The confidence a whole section can claim, which is its least trusted edge: a block of facts
-- is only as good as the weakest claim in it, and saying "verified" over a list where one line
-- is an imported baseline would be the wrong way round. nil where no edge states one. Pure.
function InfoPanel.SectionConfidence(edges)
  if type(edges) ~= "table" then
    return nil
  end
  local confidence = ItemTree.Confidence
  local ranker = type(confidence) == "table" and confidence.Rank or nil
  local worst, worstRank = nil, nil
  for _, edge in ipairs(edges) do
    local tier = type(edge) == "table" and edge.confidence or nil
    if type(tier) == "string" and tier ~= "" then
      local rank = 0
      if type(ranker) == "function" then
        local ok, answer = pcall(ranker, tier)
        if ok and type(answer) == "number" then
          rank = answer
        end
      end
      if worst == nil or rank < worstRank then
        worst, worstRank = tier, rank
      end
    end
  end
  return worst
end

-- The one line a section says about where its facts came from, or nil where there is nothing
-- worth saying. A mined fact is the norm and wears no badge anywhere in the window, so it says
-- nothing here either; everything else reads in Core/Confidence.lua's own words.
local function confidenceNote(tier)
  local confidence = ItemTree.Confidence
  if type(tier) ~= "string" or type(confidence) ~= "table" then
    return nil
  end
  if type(confidence.Badge) == "function" then
    local asked, badge = pcall(confidence.Badge, tier)
    if asked and badge == nil then
      return nil
    end
  end
  if type(confidence.Label) ~= "function" then
    return nil
  end
  local ok, label = pcall(confidence.Label, tier)
  if ok and type(label) == "string" and label ~= "" then
    return label
  end
  return nil
end

-- What one edge target is called, and the Theme colour key its name is written in. An item
-- reads as its own name in its quality colour, which is how it reads in every other pane;
-- anything else takes the title Graph gives it and the body colour.
local function targetRow(target)
  local kind, id = InfoPanel.Root(target)
  if kind == "item" and type(id) == "number" then
    local record = dataItem(id)
    local quality = type(record) == "table" and tonumber(record.q) or nil
    local colorKey = COLOR_BODY
    if Theme and type(Theme.QualityKey) == "function" then
      local ok, key = pcall(Theme.QualityKey, quality)
      if ok and type(key) == "string" then
        colorKey = key
      end
    end
    return itemLabel(id), colorKey
  end
  local title = moduleCall(ItemTree.Graph, "Title", target)
  if type(title) ~= "string" or title == "" then
    title = tostring(target)
  end
  return title, COLOR_BODY
end

-- Whether one edge is a choice of rewards rather than a reward every player gets. The quest
-- edges carry it as a flag of their own; a provider that packs it into the edge's meta table is
-- read as well, because meta is the one field Core copies through untouched.
local function isChoice(edge)
  if type(edge) ~= "table" then
    return false
  end
  if edge.choice == true then
    return true
  end
  return type(edge.meta) == "table" and edge.meta.choice == true
end

-- The ordered sections for a quest root, as { key, title, rows }. Pure in the same sense
-- Sections is: Graph and Edges answer, and the client side below only draws it.
--
-- key is the quest's node key ("quest:7786") and opts is passed straight to Graph.Children, so
-- the window's own "show predicted" setting reaches the column unchanged. An item row is its
-- name in its quality colour with the count the edge states beside it, a choice of rewards is
-- marked as one, and a section whose edges are not simply mined says so in a line.
function InfoPanel.QuestSections(key, opts)
  local sections = {}
  if type(key) ~= "string" then
    return sections
  end

  -- The same note twice is noise: a quest whose every section comes out of the curated file
  -- says "Community note" once, on the first section that carries it, and a later section on a
  -- different footing still says its own piece.
  local said = {}
  for _, spec in ipairs(QUEST_SECTIONS) do
    local edges = edgesOfType(key, spec.edge, directionWord(spec.direction), opts)
    local rows, choices = {}, {}
    for index, edge in ipairs(edges) do
      local name, colorKey = targetRow(edge.target)
      local count = nil
      if spec.count then
        count = InfoPanel.CountText(edge.quantity, edge.quantityMax)
      end
      local kind, id = InfoPanel.Root(edge.target)
      local row = {
        kind = "fact",
        key = spec.key .. index,
        label = name,
        labelColorKey = colorKey,
        value = count,
        colorKey = COLOR_BODY,
        -- The item this row stands for, where it stands for one. Nothing draws it: it is what
        -- lets the Era block below say only what this row does not already say.
        itemId = kind == "item" and id or nil,
      }
      if spec.choice and isChoice(edge) then
        choices[#choices + 1] = row
      else
        rows[#rows + 1] = row
      end
    end
    -- The rewards every player gets first, then the ones they pick between, under the line that
    -- says so: a quest that gives one of each must not read as though both are guaranteed.
    if #choices > 0 then
      rows[#rows + 1] = { kind = "fact", key = spec.key .. "choice", value = L["Choose one"], colorKey = COLOR_MUTED }
      for _, row in ipairs(choices) do
        rows[#rows + 1] = row
      end
    end
    if #rows > 0 then
      local note = confidenceNote(InfoPanel.SectionConfidence(edges))
      if note and not said[note] then
        said[note] = true
        rows[#rows + 1] = { kind = "fact", key = spec.key .. "confidence", value = note, colorKey = COLOR_MUTED }
      end
      sections[#sections + 1] = { key = spec.key, title = L[spec.title], rows = rows }
    end
  end

  return sections
end

-- The section keys the Classic Era block draws under, so a spec and a caller can name one. They
-- are keys of the block's own, never the quest section keys above: what those sections say comes
-- off this client's graph, and what these say is history.
local QUEST_ERA_LEAD = "questera"
local QUEST_ERA_REWARDS = "questerarewards"
local QUEST_ERA_DROPS = "questeradrops"

-- How many item rows one Era section draws before it counts the rest out. A column this narrow is
-- not the place to list twenty: the best of them are the answer and one plain line says how many
-- are left. The line is TEXT and never a row to press, because there is nowhere for it to lead.
local QUEST_ERA_ROWS = 8

-- How many of the sources behind one quest only drop are named under it. Three is what the
-- shipped table names for an item anyway (MAX_NAMED_ROWS in the pipeline), so this is a cap on
-- the drawing and not on the data.
local QUEST_ERA_SOURCES = 3

-- What the shipped Classic Era table states about one quest, or nil. Core/EraSources.lua is read
-- through the namespace and pcall'd like every other module here, so a load without it, and a
-- build compiled with --no-era-sources, costs the column this block and nothing else.
local function eraQuestFacts(questId)
  local era = ItemTree.eraSources
  if type(questId) ~= "number" or type(era) ~= "table" or type(era.QuestFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(era.QuestFacts, era, questId)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- Whether the window is drawing predicted data at all. Every Classic Era fact is predicted, so
-- the block this pane draws from the shipped table follows the very tick box the tree's own Era
-- rows follow, and turning predictions off takes all of it away.
--
-- opts is the window's own table where the caller passed one. Otherwise UI/Frame.lua is asked,
-- because that is where the default for a setting nobody has set lives, then the saved settings,
-- and a load that answers neither leaves predictions on, which is the default.
local function showingPredicted(opts)
  if type(opts) == "table" and opts.showPredicted ~= nil then
    return opts.showPredicted ~= false
  end
  local settings = nil
  if type(ItemTree.db) == "table" and type(ItemTree.db.settings) == "table" then
    settings = ItemTree.db.settings
  end
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) == "table" and type(frame.OptionsFromSettings) == "function" then
    local ok, answer = pcall(frame.OptionsFromSettings, settings)
    if ok and type(answer) == "table" and answer.showPredicted ~= nil then
      return answer.showPredicted ~= false
    end
  end
  if type(settings) == "table" and settings.showPredicted ~= nil then
    return settings.showPredicted ~= false
  end
  return true
end

-- One phrase and the qualifier after it, joined the way Core/Sources.lua joins them everywhere
-- else ("Skum, only while on a quest"), so the comma lives in one place and a locale can move it.
local function withNote(text, note)
  local joined = moduleCall(ItemTree.Sources, "WithNote", text, note)
  if type(joined) == "string" and joined ~= "" then
    return joined
  end
  if type(text) ~= "string" or text == "" then
    return note
  end
  if type(note) ~= "string" or note == "" then
    return text
  end
  return string.format(L["%s, %s"], text, note)
end

-- The one line under a quest only drop: what the shipped table names as the source, the place it
-- was recorded in and how often it gave the item there. "Forest Ooze, Azshara, about 80%".
--
-- row is one of the normalised rows Core/EraSources.lua hands back for a quest, the same shape
-- the Sources view draws an item's own rows from. The chance is hedged the way every other
-- historical figure in the addon is (Core/Confidence.lua): it was measured in another game.
--
-- A row that reads as its own place already (a gathering node, a whole fishing zone) never says
-- the place twice, and a container row, which names nothing because the item on the other end of
-- it names itself, is drawn as that item. nil where there is nothing to say at all. Pure.
function InfoPanel.QuestSourceText(row)
  if type(row) ~= "table" then
    return nil
  end
  local text = nil
  if type(row.label) == "string" and row.label ~= "" then
    text = row.label
  elseif type(row.container) == "number" then
    text = itemLabel(row.container)
  end
  if type(row.area) == "string" and row.area ~= "" and row.area ~= text then
    text = withNote(text, row.area)
  end
  local chance = nil
  if type(row.chance) == "number" then
    local figure = moduleCall(ItemTree.Confidence, "Chance", row.chance)
    if type(figure) == "string" and figure ~= "" then
      chance = moduleCall(ItemTree.Confidence, "Approximate", figure)
    end
  end
  return withNote(text, chance)
end

-- One item row for the Era block: the item's name in its own quality colour, and the node a
-- click on it re roots the window onto.
--
-- The name goes through Graph.Name first, because that is what knows the neutral placeholder an
-- item this build withholds is called ("Undiscovered mail chest"). The shipped table names no
-- item anywhere, and an Era name must never be drawn over one of those; the honest "Item 1234"
-- is the fallback for an id nothing at all can name.
local function eraItemRow(key, itemId)
  local node = moduleCall(ItemTree.Graph, "Key", "item", itemId) or ("item:" .. tostring(itemId))
  local label, colorKey = targetRow(node)
  local named = moduleCall(ItemTree.Graph, "Name", node)
  if type(named) == "string" and named ~= "" then
    label = named
  end
  return {
    kind = "fact",
    key = key,
    label = label,
    labelColorKey = colorKey,
    colorKey = COLOR_BODY,
    itemId = itemId,
    node = node,
  }
end

-- The plain line a capped list ends on: "and 4 more", in Core/Sources.lua's own words, or nil
-- where nothing was held back or the wording is not loaded.
local function eraMoreRow(key, more)
  local text = moduleCall(ItemTree.Sources, "MoreText", more)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return { kind = "fact", key = key, value = text, colorKey = COLOR_MUTED }
end

-- Everything the shipped Classic Era table adds to a quest's column, under the sections the
-- quest's own edges already produced. A new list is answered and nothing handed in is modified.
--
-- sections is what InfoPanel.QuestSections built, facts is what Core/EraSources.lua states about
-- the quest (nil for a quest it says nothing about), and opts is the window's own: with predicted
-- data switched off nothing here is drawn at all, because every Era fact is a prediction.
--
-- Nothing is said twice: an item the column's own Rewards section already names is not named
-- again, so a curated quest keeps everything it says today and gains only the parts Era knows
-- that it does not. The block ends on the two lines every Era fact ends on: the Predicted wording
-- the rest of the addon uses, and what a prediction out of this table means.
--
-- Brief FX14 (the coordinator's follow up of 2026-10-17): the Side line reads the final lists,
-- InfoPanel.QuestListSide, never the table's own side (facts.side), which still sided the 39 quests
-- ItemTree-Data's QS4 opened to both sides (A Thief's Reward 9339 read "Side: Horde").

--- Brief FX14: the side the final lists give a quest, in words ("Alliance" or "Horde"), or nil for
--- a quest open to both sides: Core/Graph.lua Graph.QuestSide (the shipped alliance / horde lists,
--- then the predicted side), the same answer the quest's rows on an item's Sources and Used by tabs
--- give. Guarded.
function InfoPanel.QuestListSide(questId)
  if type(questId) ~= "number" then
    return nil
  end
  local side = moduleCall(ItemTree.Graph, "QuestSide", nil, "quest:" .. questId)
  local word = (side == 1 or side == 2) and InfoPanel.SIDE_WORDS[side] or nil
  if not word then
    return nil
  end
  return L[word]
end

function InfoPanel.QuestEraSections(sections, facts, opts)
  local out = {}
  for _, section in ipairs(type(sections) == "table" and sections or {}) do
    out[#out + 1] = section
  end
  if type(facts) ~= "table" or not showingPredicted(opts) then
    return out
  end

  -- The quest's own facts: its full title, which the header's two lines may have cut, and the
  -- side it belongs to. A quest open to everyone says so by saying nothing. Brief FX14: the side
  -- is the final lists' (InfoPanel.QuestListSide), whatever the table states.
  local lead = {}
  if type(facts.title) == "string" and facts.title ~= "" then
    lead[#lead + 1] = { kind = "para", key = "eratitle", value = facts.title, colorKey = COLOR_BODY }
  end
  local side = InfoPanel.QuestListSide(facts.questId)
  if side then
    lead[#lead + 1] = { kind = "fact", key = "eraside", label = L["Side"], value = side, colorKey = COLOR_BODY }
  end

  -- The rewards this column already names, so Era adds only the ones it does not. Read off the
  -- quest's own Rewards section alone: an item the quest ASKS for is a different fact from an
  -- item it hands over, and a column that dropped the second because of the first would be
  -- hiding the answer rather than repeating it.
  local rewarded = {}
  for _, section in ipairs(out) do
    if section.key == "questrewards" or section.key == "questlogrewards" or section.key == "questshippedrewards" then
      for _, row in ipairs(section.rows or {}) do
        if type(row.itemId) == "number" then
          rewarded[row.itemId] = true
        end
      end
    end
  end

  -- Brief Q10: what the quest asks the player to bring, out of qr, each item with its count. Only
  -- where the column's own Requires section is empty: the curated table and the collector state
  -- what the quest asks for on this client, and where either does, Era's list is not drawn
  -- beside it (Core/Graph.lua drops the same rows off the graph for the same reason).
  local stated = false
  for _, section in ipairs(out) do
    if section.key == "questrequires" and type(section.rows) == "table" and #section.rows > 0 then
      stated = true
    end
  end
  local requires, held = {}, 0
  if not stated then
    for _, entry in ipairs(facts.requires or {}) do
      if type(entry) == "table" and type(entry.item) == "number" then
        if #requires < QUEST_ERA_ROWS then
          local row = eraItemRow("erarequires" .. tostring(entry.item), entry.item)
          row.value = InfoPanel.CountText(entry.count)
          requires[#requires + 1] = row
        else
          held = held + 1
        end
      end
    end
  end
  if held > 0 then
    local more = eraMoreRow("erarequiresmore", held)
    if more then
      requires[#requires + 1] = more
    end
  end

  local rewards = {}
  held = 0
  for _, entry in ipairs(facts.rewards or {}) do
    if type(entry.item) == "number" and not rewarded[entry.item] then
      if #rewards < QUEST_ERA_ROWS then
        rewards[#rewards + 1] = eraItemRow("erareward" .. tostring(entry.item), entry.item)
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = eraMoreRow("erarewardmore", held)
    if more then
      rewards[#rewards + 1] = more
    end
  end

  -- The items that only drop while the player is on the quest, each with what drops it, where,
  -- and how often. The sources read as lines under the item rather than as columns beside it: a
  -- source row's three columns do not fit a column this narrow, and the words do.
  local drops, items = {}, 0
  held = 0
  for _, entry in ipairs(facts.drops or {}) do
    if type(entry.item) == "number" then
      if items < QUEST_ERA_ROWS then
        items = items + 1
        drops[#drops + 1] = eraItemRow("eradrop" .. tostring(entry.item), entry.item)
        for index, source in ipairs(entry.sources or {}) do
          local text = nil
          if index <= QUEST_ERA_SOURCES then
            text = InfoPanel.QuestSourceText(source)
          end
          if text then
            drops[#drops + 1] = {
              kind = "fact",
              key = "eradrop" .. tostring(entry.item) .. "source" .. tostring(index),
              value = text,
              colorKey = COLOR_MUTED,
            }
          end
        end
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = eraMoreRow("eradropmore", held)
    if more then
      drops[#drops + 1] = more
    end
  end

  local last = nil
  local function push(key, title, rows)
    if #rows == 0 then
      return
    end
    local section = { key = key, title = title, rows = rows }
    out[#out + 1] = section
    last = section
  end

  push(QUEST_ERA_LEAD, nil, lead)
  -- The key is written out rather than held in a local of its own: this file's main chunk is at
  -- Lua 5.1's limit of 200 locals.
  push("questerarequires", L["Requires"], requires)
  push(QUEST_ERA_REWARDS, L["Rewards"], rewards)
  push(QUEST_ERA_DROPS, L["Drops only on this quest"], drops)
  -- Brief D5: the withheld items Core/EraSources.lua left out of the two lists above, in one line.
  local locked = InfoPanel.LockedLine(facts.locked)
  if locked then
    push("questeralocked", nil, { { kind = "fact", key = "questeralocked", value = locked, colorKey = COLOR_MUTED } })
  end

  -- What every one of those lines is worth, once, at the foot of the last of them: the Predicted
  -- wording the rest of the addon uses, then what a prediction out of this table means.
  if last then
    local confidence = ItemTree.Confidence
    local note = confidenceNote(type(confidence) == "table" and confidence.PREDICTED or nil)
    if note then
      last.rows[#last.rows + 1] = { kind = "fact", key = "eraconfidence", value = note, colorKey = COLOR_MUTED }
    end
    last.rows[#last.rows + 1] = {
      kind = "para",
      key = "eraprovenance",
      value = L["From Classic Era. WoW Forever may have changed this."],
      colorKey = COLOR_MUTED,
    }
  end
  return out
end

-- Brief Q8: the section keys of what the client and the player's own records say about a quest,
-- drawn above everything the quest's edges and the shipped tables say.
local QUEST_LIVE = "questlive"
local QUEST_GIVERS = "questgivers"
local QUEST_ENDERS = "questenders"
local QUEST_OBJECTIVES = "questobjectives"
local QUEST_LOG_REWARDS = "questlogrewards"
local QUEST_SHIPPED_REWARDS = "questshippedrewards"

-- The words the state line reads, by ViewModel.QuestFacts' state. A quest that is neither in the
-- log nor done says nothing about it.
local QUEST_STATES = {
  log = "In your log",
  done = "Completed",
}

-- The state line for a quest, or nil. Pure.
function InfoPanel.QuestStateText(state)
  local word = type(state) == "string" and QUEST_STATES[state] or nil
  return word and L[word] or nil
end

-- One NPC row under "Given by" or "Turned in to": the NPC's name, a link to its page where the
-- player's record or Classic Era names a creature, and where it stands ("Westfall 45.2, 61.0").
-- npc is one of ViewModel.QuestFacts' givers or enders. nil for an NPC nothing names. Pure.
function InfoPanel.QuestNpcRow(key, npc)
  if type(npc) ~= "table" then
    return nil
  end
  local name = npc.name
  if (type(name) ~= "string" or name == "") and type(npc.key) == "string" then
    name = moduleCall(ItemTree.Graph, "Name", npc.key)
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- Brief GF5: an approximate place (a predicted giver's) says its zone alone, never coordinates.
  local x, y = npc.x, npc.y
  if npc.approx then
    x, y = nil, nil
  end
  local place = moduleCall(ItemTree.ViewModel, "QuestPlaceText", npc.zone, x, y)
  local node = type(npc.key) == "string" and npc.key or nil
  return {
    kind = "fact",
    key = key,
    label = name,
    labelColorKey = node and COLOR_LINK or COLOR_BODY,
    value = place,
    colorKey = COLOR_BODY,
    node = node,
    -- Brief TV4: the zone and the place apart, for the hover's bracketed spot (Sources.SpotText).
    -- Nothing on the page draws them.
    zone = type(npc.zone) == "string" and npc.zone ~= "" and npc.zone or nil,
    x = tonumber(x),
    y = tonumber(y),
  }
end

-- One reward row: the item's name in its own quality colour, the count beside it where the log
-- states more than one, and the item's page a click away.
local function questRewardRow(key, reward)
  local row = eraItemRow(key, reward.itemId)
  row.value = InfoPanel.CountText(reward.count, reward.count)
  return row
end

-- What the client's log and the player's own records say about one quest, as the sections the
-- column draws first. facts is ViewModel.QuestFacts' answer (nil draws nothing). Each part is left
-- out where nothing states it: a quest the player has never met reads nothing here at all.
--
--   lead          level, the state ("In your log", "Completed") and the zone
--   Given by      the NPC that gave it, from the player's record, else Classic Era's
--   Turned in to  the NPC it was handed in to, the same way
--   Objectives    the log's own lines with their progress, only while it is in the log
--   Rewards       the log's rewards while it is in the log, else Forever's own where the client's
--                 quest cache states them (brief QB2, the Classic Era ones it no longer names after
--                 them under their own line), else the shipped QuestRewards table's,
--                 each a link to the item, a choice marked as one
--
-- Brief GF5: and the predicted facts (facts.predicted, and the givers and turn ins marked predicted),
-- each part of them under the Predicted mark's words: their own lead (title, level, required level,
-- side, zone) after the one above, their givers and turn ins where nothing of ours names any, their
-- objectives as links (InfoPanel.QuestPredictedObjectives), the previous and next quests, and their
-- rewards after ours, then the currency and last the one money and XP line. eraFacts is what the
-- Classic Era table states about the quest (Core/EraSources.lua QuestFacts), whose side wins.
--
-- Classic Era parts end on the line every Era fact ends on. Pure over facts.
function InfoPanel.QuestLiveSections(facts, eraNamesRewards, eraFacts)
  local sections = {}
  if type(facts) ~= "table" then
    return sections
  end
  local function push(key, title, rows)
    if #rows > 0 then
      sections[#sections + 1] = { key = key, title = title, rows = rows }
    end
    return rows
  end
  local function eraLine(rows, key)
    rows[#rows + 1] = {
      kind = "para",
      key = key,
      value = L["From Classic Era. WoW Forever may have changed this."],
      colorKey = COLOR_MUTED,
    }
  end
  -- Brief GF5: the Predicted mark's own words (Core/Confidence.lua Label) at the foot of the rows
  -- that are predicted, the line every Classic Era block ends on too.
  local foretold = type(facts.predicted) == "table" and facts.predicted or {}

  local lead = {}
  if type(facts.level) == "number" then
    lead[#lead + 1] =
      { kind = "fact", key = "questlevel", label = L["Level"], value = tostring(facts.level), colorKey = COLOR_BODY }
  end
  local state = InfoPanel.QuestStateText(facts.state)
  if state then
    lead[#lead + 1] = { kind = "fact", key = "queststate", value = state, colorKey = COLOR_BODY }
  end
  if type(facts.zone) == "string" and facts.zone ~= "" then
    lead[#lead + 1] = { kind = "fact", key = "questzone", label = L["Zone"], value = facts.zone, colorKey = COLOR_BODY }
  end
  push(QUEST_LIVE, nil, lead)

  local predictedLead = InfoPanel.QuestPredictedLead(foretold, eraFacts)
  if #predictedLead > 0 then
    push("questpredicted", nil, predictedLead)
  end

  -- Brief NW1 (owner ruling B of 2026-10-19, QA item 283): the quest's hand kept how-to note under
  -- the Community note heading, high on the page so the header's hover (QuestTooltipLines) says it
  -- before its line cap. The predicted setting leaves it be: it is a community note.
  if type(facts.note) == "string" and facts.note ~= "" then
    push(
      "questnote",
      L["Community note"],
      { { kind = "para", key = "questnote", value = facts.note, colorKey = COLOR_BODY } }
    )
  end

  for _, side in ipairs({
    { QUEST_GIVERS, L["Given by"], facts.givers },
    { QUEST_ENDERS, L["Turned in to"], facts.enders },
  }) do
    local rows, era, predicted = {}, false, false
    for index, npc in ipairs(type(side[3]) == "table" and side[3] or {}) do
      local row = InfoPanel.QuestNpcRow(side[1] .. index, npc)
      if row then
        rows[#rows + 1] = row
        era = era or npc.era == true
        predicted = predicted or npc.predicted == true
      end
    end
    -- Brief IW1 (the owner's ruling "2B" of 2026-10-22): the items a quest hands the player are no row
    -- under the giver here any more (brief PV1 drew one): they are the Quest tab's own "Provided items"
    -- category (Core/ViewModel.lua QUEST_GROUPS), so nothing reads as a giver that is not one.
    if era then
      eraLine(rows, side[1] .. "era")
    end
    push(side[1], side[2], rows)
  end

  local objectives = {}
  for index, objective in ipairs(type(facts.objectives) == "table" and facts.objectives or {}) do
    objectives[#objectives + 1] = {
      kind = "fact",
      key = QUEST_OBJECTIVES .. index,
      value = objective.text,
      colorKey = objective.done and COLOR_MUTED or COLOR_BODY,
    }
  end
  local predictedObjectives = InfoPanel.QuestPredictedObjectives(foretold.objectives)
  for _, row in ipairs(predictedObjectives) do
    objectives[#objectives + 1] = row
  end
  push(QUEST_OBJECTIVES, L["Objectives"], objectives)

  -- Brief GF5: the quests before and after this one, the Predicted mark's words under the last.
  local chain = {}
  for _, side in ipairs({
    { "questprevious", L["Previous quest"], foretold.previous },
    { "questnext", L["Next quest"], foretold.next },
  }) do
    local rows = {}
    for index, linked in ipairs(type(side[3]) == "table" and side[3] or {}) do
      local row = InfoPanel.QuestLinkRow(side[1] .. index, type(linked) == "table" and linked.key or nil)
      if row then
        rows[#rows + 1] = row
      end
    end
    if #rows > 0 then
      chain[#chain + 1] = { side[1], side[2], rows }
    end
  end
  for _, part in ipairs(chain) do
    push(part[1], part[2], part[3])
  end

  local fixed, choices = {}, {}
  local key = facts.rewardsFrom == "log" and QUEST_LOG_REWARDS or QUEST_SHIPPED_REWARDS
  -- The shipped table's rewards are Classic Era's, which the Era block under this one already
  -- names where Core/EraSources.lua knows the quest (eraNamesRewards): said once, there.
  local rewards = facts.rewards
  if facts.rewardsFrom == "shipped" and eraNamesRewards then
    rewards = nil
  end
  -- Brief QB2: a Classic Era reward the quest no longer hands over in Forever (from "classic") is
  -- drawn after Forever's own, under a line that says so, its name muted.
  local classic = {}
  for _, reward in ipairs(type(rewards) == "table" and rewards or {}) do
    if type(reward.itemId) == "number" then
      local row = questRewardRow(key .. tostring(reward.itemId), reward)
      if reward.from == "classic" then
        row.labelColorKey = COLOR_MUTED
        classic[#classic + 1] = row
      elseif reward.choice then
        choices[#choices + 1] = row
      else
        fixed[#fixed + 1] = row
      end
    end
  end
  if #choices > 0 then
    fixed[#fixed + 1] = { kind = "fact", key = key .. "choice", value = L["Choose one"], colorKey = COLOR_MUTED }
    for _, row in ipairs(choices) do
      fixed[#fixed + 1] = row
    end
  end
  if #fixed > 0 then
    if facts.rewardsFrom == "log" then
      fixed[#fixed + 1] =
        { kind = "fact", key = key .. "from", value = L["From your quest log"], colorKey = COLOR_MUTED }
    elseif facts.rewardsFrom == "shipped" then
      eraLine(fixed, key .. "era")
    end
    -- Brief PS5: the player module's rewards are plain data, with no line of their own. Brief QB2:
    -- so are the quest cache's ("forever" and "confirmed").
  end
  if #classic > 0 then
    fixed[#fixed + 1] = {
      kind = "fact",
      key = key .. "classic",
      value = L["Classic Era rewards, changed in Forever"],
      colorKey = COLOR_MUTED,
    }
    for _, row in ipairs(classic) do
      fixed[#fixed + 1] = row
    end
  end
  -- Brief GF5: the predicted rewards after every one of ours, a choice marked as one, then the
  -- currency and last the one money and XP line, under the Predicted mark's words.
  local predictedRows = InfoPanel.QuestPredictedRewards(key, foretold)
  for _, row in ipairs(predictedRows) do
    fixed[#fixed + 1] = row
  end
  push(key, L["Rewards"], fixed)
  return sections
end

-- Brief GF5: the predicted lead, as rows: the title (where the graph names the quest by it), the
-- level, the required level, the side in the words a vendor's page uses (InfoPanel.SIDE_WORDS) unless
-- the Classic Era block draws its Side line (brief FX14: the final lists' side for eraFacts.questId), and
-- the zone. Empty for none. Pure over the shipped lists.
function InfoPanel.QuestPredictedLead(foretold, eraFacts)
  local rows = {}
  if type(foretold) ~= "table" then
    return rows
  end
  if type(foretold.title) == "string" and foretold.title ~= "" then
    rows[#rows + 1] = { kind = "para", key = "questpredictedtitle", value = foretold.title, colorKey = COLOR_BODY }
  end
  if type(foretold.level) == "number" then
    rows[#rows + 1] = {
      kind = "fact",
      key = "questpredictedlevel",
      label = L["Level"],
      value = tostring(foretold.level),
      colorKey = COLOR_BODY,
    }
  end
  if type(foretold.requiredLevel) == "number" then
    rows[#rows + 1] = {
      kind = "fact",
      key = "questpredictedrequired",
      label = L["Required level"],
      value = tostring(foretold.requiredLevel),
      colorKey = COLOR_BODY,
    }
  end
  -- Brief FX14: the Classic Era block's Side line is the final lists' now (InfoPanel.QuestListSide),
  -- so this one steps aside where that line is drawn, never for the table's own side alone.
  local eraSide = type(eraFacts) == "table" and InfoPanel.QuestListSide(eraFacts.questId) ~= nil
  local side = type(foretold.side) == "number" and InfoPanel.SIDE_WORDS[foretold.side] or nil
  if side and not eraSide then
    rows[#rows + 1] =
      { kind = "fact", key = "questpredictedside", label = L["Side"], value = L[side], colorKey = COLOR_BODY }
  end
  if type(foretold.zone) == "string" and foretold.zone ~= "" then
    rows[#rows + 1] =
      { kind = "fact", key = "questpredictedzone", label = L["Zone"], value = foretold.zone, colorKey = COLOR_BODY }
  end
  return rows
end

-- Brief GF5: one predicted objective a line each ("Kill 8 Kobold Vermin", Core/ViewModel.lua
-- ObjectiveLine), each opening the page of what it names. Empty for none. Pure over the names.
function InfoPanel.QuestPredictedObjectives(objectives)
  local rows = {}
  for index, objective in ipairs(type(objectives) == "table" and objectives or {}) do
    local text = moduleCall(ItemTree.ViewModel, "ObjectiveLine", objective)
    if type(text) == "string" and text ~= "" then
      rows[#rows + 1] = {
        kind = "fact",
        key = QUEST_OBJECTIVES .. "predicted" .. index,
        value = text,
        colorKey = COLOR_BODY,
        node = objective.key,
      }
    end
  end
  return rows
end

-- Brief GF5: a quest named by its key, a link to its page ("Rare Books", or "Quest 91777" where
-- nothing names it), or nil for a key that is not a quest's. Pure over the names.
function InfoPanel.QuestLinkRow(key, questKey)
  local Graph = ItemTree.Graph
  if type(questKey) ~= "string" or type(Graph) ~= "table" then
    return nil
  end
  local name = moduleCall(Graph, "Name", questKey)
  if type(name) ~= "string" or name == "" then
    name = moduleCall(Graph, "Title", questKey)
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local shown = moduleCall(ItemTree.ViewModel, "QuestTitleText", questKey, name)
  return {
    kind = "fact",
    key = key,
    label = type(shown) == "string" and shown ~= "" and shown or name,
    labelColorKey = COLOR_LINK,
    colorKey = COLOR_BODY,
    node = questKey,
  }
end

-- Brief GF5: a currency's name as the client spells it ("Merchant's Favor"), else the name the
-- shipped Merchant's Favor block gives the one currency it states, else nil.
function InfoPanel.CurrencyName(currencyId)
  local sources = ItemTree.Sources
  local name = moduleCall(sources, "CurrencyName", currencyId)
  if type(name) == "string" and name ~= "" then
    return name
  end
  local favour = type(sources) == "table" and sources.Favour or nil
  local shipped = moduleCall(favour, "Table")
  local currency = type(shipped) == "table" and shipped.currency or nil
  if type(currency) == "table" and currency.id == currencyId and type(currency.name) == "string" then
    return currency.name
  end
  return nil
end

-- Brief GF5: the predicted rewards' rows for the Rewards section keyed key: each item a link in its
-- quality colour, the choices after a "Choose one" line of their own, then one line per currency
-- ("5 Merchant's Favor") and last the money and XP ("4s, 880 XP"). Empty for none. Pure over the
-- names.
function InfoPanel.QuestPredictedRewards(key, foretold)
  local rows, choices = {}, {}
  if type(foretold) ~= "table" then
    return rows
  end
  for _, reward in ipairs(type(foretold.rewards) == "table" and foretold.rewards or {}) do
    if type(reward.itemId) == "number" then
      local row = questRewardRow(key .. "predicted" .. tostring(reward.itemId), reward)
      if reward.choice then
        choices[#choices + 1] = row
      else
        rows[#rows + 1] = row
      end
    end
  end
  if #choices > 0 then
    rows[#rows + 1] = { kind = "fact", key = key .. "predictedchoice", value = L["Choose one"], colorKey = COLOR_MUTED }
    for _, row in ipairs(choices) do
      rows[#rows + 1] = row
    end
  end
  local module = ItemTree.QuestsPredicted
  for index, entry in ipairs(type(foretold.currency) == "table" and foretold.currency or {}) do
    local text = moduleCall(module, "CurrencyText", entry, InfoPanel.CurrencyName)
    if type(text) == "string" and text ~= "" then
      rows[#rows + 1] = { kind = "fact", key = key .. "currency" .. index, value = text, colorKey = COLOR_BODY }
    end
  end
  local sources = ItemTree.Sources
  local moneyText = type(sources) == "table" and sources.MoneyText or nil
  local money = moduleCall(module, "MoneyXpText", foretold.money, foretold.xp, moneyText)
  if type(money) == "string" and money ~= "" then
    rows[#rows + 1] = { kind = "fact", key = key .. "money", value = money, colorKey = COLOR_BODY }
  end
  return rows
end

-- The quest's own edge sections, less every reward the column's own Rewards section above already
-- names: the log's list is the truth while it is there, and one item twice reads as two rewards. A
-- section left with nothing but its notes goes. Pure over the two lists.
local function withoutNamedRewards(edgeSections, liveSections)
  local named = {}
  for _, section in ipairs(liveSections) do
    if section.key == QUEST_LOG_REWARDS or section.key == QUEST_SHIPPED_REWARDS then
      for _, row in ipairs(section.rows) do
        if type(row.itemId) == "number" then
          named[row.itemId] = true
        end
      end
    end
  end
  if next(named) == nil then
    return edgeSections
  end
  local out = {}
  for _, section in ipairs(edgeSections) do
    if section.key ~= "questrewards" then
      out[#out + 1] = section
    else
      local rows, items = {}, 0
      for _, row in ipairs(section.rows or {}) do
        if not (type(row.itemId) == "number" and named[row.itemId]) then
          rows[#rows + 1] = row
          if type(row.itemId) == "number" then
            items = items + 1
          end
        end
      end
      if items > 0 then
        out[#out + 1] = { key = section.key, title = section.title, rows = rows }
      end
    end
  end
  return out
end

-- The header line for a quest root: "Quest: Rise, Thunderfury! (7786)" in the title colour and
-- the quest mark the tree draws a quest row with. A quest states no quality, so the header icon
-- wears no rarity frame.
--
-- Brief NW1: a quest with a hand kept how-to note (note, its text) wears the Community note mark,
-- whose hover says the note (brief E93, header.note, drawHeader).
function InfoPanel.QuestHeader(title, note)
  local name = L["Unknown quest"]
  if type(title) == "string" and title ~= "" then
    name = title
  end
  local header = {
    name = name,
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = {},
    asset = QUEST_ASSET,
  }
  if type(note) == "string" and note ~= "" then
    header.badges = { "note" }
    header.note = { note }
  end
  return header
end

--- Brief RB2 (owner QA 2026-10-17 item 194, "mark ... as possibly horde only if we're showing them to
--- the opposite faction"): the section a quest page leads with where the quest is open to both
--- sides and our own data leans to the side that is not the player's (Core/Graph.lua
--- Graph.LeanWords over ItemTree-Data RB3's lean lists): one muted line, "Possibly Horde only". nil
--- for the leaning side's player, a quest that leans nowhere or is sided outright, and a character
--- whose side is not known. Drawn whatever "Show predicted data" says: the lean is ours, not the
--- Classic Era table's. Guarded.
function InfoPanel.QuestLeanSection(questKey)
  local graph = ItemTree.Graph
  if type(questKey) ~= "string" or type(graph) ~= "table" or type(graph.PlayerSide) ~= "function" then
    return nil
  end
  local words = moduleCall(graph, "LeanWords", questKey, moduleCall(graph, "PlayerSide"))
  if type(words) ~= "string" or words == "" then
    return nil
  end
  return { key = "questlean", rows = { { kind = "fact", key = "questlean", value = words, colorKey = COLOR_MUTED } } }
end

-- Everything the pane says about one quest root: what the client and the player's records know
-- (brief Q8), what the quest's own edges state, then what the shipped Classic Era table states.
--
-- A quest is never "Not in ItemTree data": the key names it, so the column draws the header, and
-- it says nothing is known yet only where nothing of any kind is. The client is asked about this
-- one quest through ViewModel.Quest, once per session (see InfoPanel.ReadQuest for what it costs).
function InfoPanel.QuestContent(id, showChanges, opts)
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  showChanges = showChanges and true or false
  local content = { questId = id, kind = "quest", showChanges = showChanges, sections = {} }
  if type(id) ~= "number" then
    content.notice = L["Not in ItemTree data"]
    return content
  end

  local key = moduleCall(ItemTree.Graph, "Key", "quest", id) or ("quest:" .. tostring(id))
  content.found = true
  -- The sections are built before the title is asked for, because a quest has no generated
  -- module behind it: nothing knows its name until something that supplies its edges has
  -- registered one (Graph.SetName), and walking the edges is what makes that happen. Asked the
  -- other way round, the first draw of a quest reads "Quest 7786" and only a redraw names it.
  --
  -- Brief Q8: what the client knows about the quest and what the player's own records say, first.
  -- ViewModel.Quest asks the client once per quest per session (ViewModel.QuestLive), so the Quest
  -- tab and the Map tab reading the same answer cost nothing more; its title, where the client
  -- gives one, is on the graph before the header below asks for it.
  local facts = moduleCall(ItemTree.ViewModel, "Quest", id, opts)
  content.quest = facts
  local era = eraQuestFacts(id)
  local eraRewards = type(era) == "table" and type(era.rewards) == "table" and #era.rewards > 0
  local live = InfoPanel.QuestLiveSections(facts, eraRewards and showingPredicted(opts), era)
  local sections = {}
  for _, section in ipairs(live) do
    sections[#sections + 1] = section
  end
  for _, section in ipairs(withoutNamedRewards(InfoPanel.QuestSections(key, opts), live)) do
    sections[#sections + 1] = section
  end
  -- And everything the shipped table knows about the quest itself, which is the only thing that
  -- ever answered for a quest reached from a quest only drop: the pass over the table is paid
  -- here, on a quest node being opened, and never while a tree is built.
  content.sections = InfoPanel.QuestEraSections(sections, era, opts)
  -- Brief QN1: "Quest: Taming the Beast (II) (6062)" for a quest in a chain of same titled ones.
  local title = moduleCall(ItemTree.Graph, "Title", key)
  content.header = InfoPanel.QuestHeader(
    moduleCall(ItemTree.ViewModel, "QuestTitleText", key, title) or title,
    type(facts) == "table" and facts.note or nil
  )
  if #content.sections == 0 then
    -- Brief Q8: nothing at all, which is a quest the player has never met, that is not in the log
    -- and that no table states. Quest words, never an item's.
    content.empty = true
    content.sections = {
      {
        key = "quest",
        rows = {
          { kind = "fact", key = "unknown", value = L["Nothing known about this quest yet"], colorKey = COLOR_MUTED },
          {
            kind = "para",
            key = "unknownhow",
            value = L["ItemTree records who gives it and where as you play"],
            colorKey = COLOR_MUTED,
          },
        },
      },
    }
  end
  -- Brief RB2 (owner QA 2026-10-17 item 194): a quest open to both that our data leans to the other
  -- side leads with a muted "Possibly Horde only" (InfoPanel.QuestLeanSection).
  local lean = InfoPanel.QuestLeanSection(key)
  if lean then
    table.insert(content.sections, 1, lean)
  end
  return content
end

-- Brief TV4 (the owner's designs 1 and 2 of 2026-10-21, item 347, ruling C2): the quest's own
-- lines for a hover, the page header's and a quest row's in the window. The client has no tooltip
-- for a quest id, so this is the whole of it under the title, in the game tooltip's own lines, a
-- label on the left and its value on the right, a blank line between the parts:
--
--   the state       "Completed" in green, "In your log", or "Not completed" muted
--   Side, Zone      with the side's icon, then the level where the log states one
--   Community note  the quest's hand kept note (brief NW1)
--   Given by        each giver with its spot in brackets, "[24.6, 78.2]", or "[Stormwind: 42.1,
--   Turned in to    65.8]" where it stands in another zone than the quest's (Sources.SpotText)
--   Objectives      while the quest is in the log
--   Requires        "[icon] 8 x Painted Gnoll Armband (quest drop)", the drop note where the item
--                   only drops on this quest (the Classic Era table's list, which no longer draws
--                   a section of its own here)
--   Started by      the item that starts it
--   Rewards         "(Choose one)" on the right where every item is a choice, each item with its
--                   icon in its quality colour, then the currency and the money and XP line
--   Previous quest, Next quest
--
-- Ruling B2: no Predicted words and no "From Classic Era" line here (the page keeps them), and a
-- part with nothing in it is not drawn, so no heading ever stands alone. Each line is { text,
-- right, colorKey, rightColorKey } or a blank { text = " ", gap = true }. Pure over content.
InfoPanel.CARD_ICON = 14
InfoPanel.CARD_NPCS = 3
InfoPanel.CARD_ITEMS = 8
InfoPanel.CARD_OBJECTIVES = 6

-- Brief TV4: the row keys a hover leaves out: the Predicted and Classic Era words (ruling B2), the
-- log's provenance line and the title the Classic Era block repeats. Matched on the key's end.
InfoPanel.CARD_SKIP_ENDINGS = { "confidence", "era", "provenance", "from", "eratitle", "predictedtitle" }

function InfoPanel.QuestTooltipLines(content)
  local lines = {}
  if type(content) ~= "table" then
    return lines
  end
  local facts = type(content.quest) == "table" and content.quest or nil
  local function skipped(row)
    local key = type(row) == "table" and row.key or nil
    if type(key) ~= "string" then
      return false
    end
    for _, ending in ipairs(InfoPanel.CARD_SKIP_ENDINGS) do
      if key:sub(-#ending) == ending then
        return true
      end
    end
    return false
  end
  local function section(key)
    for _, entry in ipairs(content.sections or {}) do
      if entry.key == key then
        return entry
      end
    end
    return nil
  end
  local function rowsOf(key)
    local entry = section(key)
    return type(entry) == "table" and type(entry.rows) == "table" and entry.rows or {}
  end
  local function rowByKey(key, rowKey)
    for _, row in ipairs(rowsOf(key)) do
      if row.key == rowKey then
        return row
      end
    end
    return nil
  end
  local function pair(list, label, value, rightColorKey)
    if type(value) == "string" and value ~= "" then
      list[#list + 1] =
        { text = label, right = value, colorKey = COLOR_BODY, rightColorKey = rightColorKey or COLOR_MUTED }
    end
  end
  local function single(list, text, colorKey)
    if type(text) == "string" and text ~= "" then
      list[#list + 1] = { text = text, colorKey = colorKey or COLOR_BODY }
    end
  end
  local function itemLine(row, count, note)
    local record = type(row.itemId) == "number" and dataItem(row.itemId) or nil
    local icon = InfoPanel.IconMarkup(type(record) == "table" and record.i or nil, InfoPanel.CARD_ICON)
    local text = row.label or ""
    if count then
      text = string.format(L["%s x %s"], tostring(count), text)
    end
    if note then
      text = string.format(L["%s (quest drop)"], text)
    end
    if icon ~= "" then
      text = icon .. " " .. text
    end
    return { text = text, colorKey = row.labelColorKey or COLOR_BODY }
  end
  local parts = {}
  local function part(list)
    if #list > 0 then
      parts[#parts + 1] = list
    end
  end

  -- The state, and the lean (brief RB2) under it.
  local state = {}
  local stateWord = facts and facts.state or nil
  if stateWord == "done" then
    single(state, InfoPanel.QuestStateText("done"), "ITEMTREE_COLOR_QUALITY_UNCOMMON")
  elseif stateWord == "log" then
    single(state, InfoPanel.QuestStateText("log"), COLOR_BODY)
  elseif facts then
    single(state, L["Not completed"], COLOR_MUTED)
  end
  for _, row in ipairs(rowsOf("questlean")) do
    single(state, row.value, COLOR_MUTED)
  end
  part(state)

  -- Side, zone and level: the log's, else the Classic Era block's side and the predicted lead.
  local lead = {}
  local sideRow = rowByKey("questera", "eraside") or rowByKey("questpredicted", "questpredictedside")
  if sideRow and type(sideRow.value) == "string" then
    local value = sideRow.value
    for number, word in pairs(InfoPanel.SIDE_WORDS) do
      if L[word] == value and type(Assets) == "table" and type(Assets.SIDES) == "table" and Assets.SIDES[number] then
        local ok, markup = pcall(Assets.Markup, Assets.SIDES[number], InfoPanel.CARD_ICON)
        if ok and type(markup) == "string" and markup ~= "" then
          value = markup .. " " .. value
        end
      end
    end
    pair(lead, L["Side"], value)
  end
  local zoneRow = rowByKey("questlive", "questzone") or rowByKey("questpredicted", "questpredictedzone")
  local home = zoneRow and zoneRow.value or nil
  -- Brief TV4 (design 2, Riverpaw Gnoll Bounty): a quest no source gives a zone of its own reads
  -- the zone its first giver (else turn in) stands in, so the spots under it need not name it.
  if not home then
    for _, key in ipairs({ "questgivers", "questenders" }) do
      for _, row in ipairs(rowsOf(key)) do
        if not home and row.label and type(row.zone) == "string" and row.zone ~= "" then
          home = row.zone
        end
      end
    end
  end
  pair(lead, L["Zone"], home)
  local levelRow = rowByKey("questlive", "questlevel") or rowByKey("questpredicted", "questpredictedlevel")
  pair(lead, L["Level"], levelRow and levelRow.value or nil)
  local required = rowByKey("questpredicted", "questpredictedrequired")
  pair(lead, L["Required level"], required and required.value or nil)
  part(lead)

  -- The hand kept note, heading and all (brief NW1).
  local note = {}
  local noteSection = section("questnote")
  if noteSection then
    for _, row in ipairs(noteSection.rows or {}) do
      if #note == 0 then
        single(note, noteSection.title)
      end
      single(note, row.value, COLOR_MUTED)
    end
  end
  part(note)

  -- Who gives it and who takes it back, each with its spot.
  local npcs = {}
  for _, spec in ipairs({ { "questgivers", L["Given by"] }, { "questenders", L["Turned in to"] } }) do
    local drawn = 0
    for _, row in ipairs(rowsOf(spec[1])) do
      if row.label and not skipped(row) and drawn < InfoPanel.CARD_NPCS then
        if drawn == 0 then
          single(npcs, spec[2])
        end
        drawn = drawn + 1
        local spot = moduleCall(ItemTree.Sources, "SpotText", row.zone, row.x, row.y, home)
        npcs[#npcs + 1] = { text = row.label, right = spot, colorKey = COLOR_MUTED, rightColorKey = COLOR_BODY }
      end
    end
  end
  part(npcs)

  local objectives = {}
  for _, row in ipairs(rowsOf("questobjectives")) do
    if row.value and #objectives < InfoPanel.CARD_OBJECTIVES + 1 then
      if #objectives == 0 then
        single(objectives, L["Objectives"])
      end
      single(objectives, row.value, row.colorKey or COLOR_BODY)
    end
  end
  part(objectives)

  -- What it asks for: the quest's own list, else the Classic Era table's, each "N x Item", the
  -- items that only drop on this quest marked so.
  local dropsHere = {}
  for _, row in ipairs(rowsOf("questeradrops")) do
    if type(row.itemId) == "number" then
      dropsHere[row.itemId] = true
    end
  end
  local requires, items = {}, 0
  for _, key in ipairs({ "questrequires", "questerarequires" }) do
    for _, row in ipairs(rowsOf(key)) do
      if not skipped(row) then
        if row.label and items < InfoPanel.CARD_ITEMS then
          if #requires == 0 then
            single(requires, L["Requires"])
          end
          items = items + 1
          requires[#requires + 1] = itemLine(row, row.value or "1", dropsHere[row.itemId])
        elseif not row.label and row.value and #requires > 0 then
          single(requires, row.value, COLOR_MUTED)
        end
      end
    end
  end
  part(requires)

  local started = {}
  for _, row in ipairs(rowsOf("queststartedby")) do
    if row.label and not skipped(row) then
      if #started == 0 then
        single(started, L["Started by"])
      end
      started[#started + 1] = itemLine(row, nil, false)
    end
  end
  part(started)

  -- What it hands over, out of every Rewards section the page drew, each item once.
  local fixed, choices, classic, after, more = {}, {}, {}, {}, {}
  local named, classicHeading, heldItems = {}, nil, 0
  for _, key in ipairs({ "questlogrewards", "questshippedrewards", "questrewards", "questerarewards" }) do
    local mode = "fixed"
    for _, row in ipairs(rowsOf(key)) do
      local rowKey = type(row.key) == "string" and row.key or ""
      if rowKey:sub(-6) == "choice" then
        mode = "choice"
      elseif rowKey:sub(-7) == "classic" and not row.itemId then
        mode = "classic"
        classicHeading = row.value
      elseif type(row.itemId) == "number" and not skipped(row) then
        if not named[row.itemId] then
          named[row.itemId] = true
          if mode == "choice" then
            choices[#choices + 1] = row
          elseif mode == "classic" then
            classic[#classic + 1] = row
          else
            fixed[#fixed + 1] = row
          end
        end
      elseif not skipped(row) and type(row.itemId) ~= "number" then
        -- Not a Predicted or Classic Era word (ruling B2): the held back count, then the currency
        -- and the money and XP line.
        if rowKey:find("more", 1, true) then
          more[#more + 1] = row.value
        elseif row.value then
          after[#after + 1] = row.value
        end
      end
    end
  end
  local rewards = {}
  local onlyChoices = #fixed == 0 and #choices > 0
  if #fixed + #choices + #classic + #after > 0 then
    if onlyChoices then
      pair(rewards, L["Rewards"], L["(Choose one)"])
    else
      single(rewards, L["Rewards"])
    end
  end
  local drawnItems = 0
  local function addItems(list)
    for _, row in ipairs(list) do
      if drawnItems < InfoPanel.CARD_ITEMS then
        drawnItems = drawnItems + 1
        rewards[#rewards + 1] = itemLine(row, row.value, false)
      else
        heldItems = heldItems + 1
      end
    end
  end
  addItems(fixed)
  if #choices > 0 and not onlyChoices then
    single(rewards, L["(Choose one)"], COLOR_MUTED)
  end
  addItems(choices)
  if #classic > 0 then
    single(rewards, classicHeading, COLOR_MUTED)
    addItems(classic)
  end
  if heldItems > 0 then
    single(rewards, moduleCall(ItemTree.Sources, "MoreText", heldItems), COLOR_MUTED)
  end
  for _, text in ipairs(more) do
    single(rewards, text, COLOR_MUTED)
  end
  for _, text in ipairs(after) do
    single(rewards, text, COLOR_BODY)
  end
  part(rewards)

  local chain = {}
  for _, spec in ipairs({ { "questprevious", L["Previous quest"] }, { "questnext", L["Next quest"] } }) do
    local drawn = false
    for _, row in ipairs(rowsOf(spec[1])) do
      if row.label then
        if not drawn then
          single(chain, spec[2])
          drawn = true
        end
        single(chain, row.label, COLOR_MUTED)
      end
    end
  end
  part(chain)

  -- Anything else the page drew (the withheld items' line, "Nothing known about this quest yet"),
  -- as the page words it.
  local KNOWN = {
    questlean = true,
    questlive = true,
    questpredicted = true,
    questnote = true,
    questgivers = true,
    questenders = true,
    questobjectives = true,
    questrequires = true,
    questerarequires = true,
    queststartedby = true,
    questlogrewards = true,
    questshippedrewards = true,
    questrewards = true,
    questerarewards = true,
    questprevious = true,
    questnext = true,
    questera = true,
    questeradrops = true,
  }
  local rest = {}
  for _, entry in ipairs(content.sections or {}) do
    if not KNOWN[entry.key] then
      local drawn = false
      for _, row in ipairs(entry.rows or {}) do
        if not skipped(row) then
          if not drawn and entry.title then
            single(rest, entry.title)
          end
          drawn = true
          if row.label then
            pair(rest, row.label, row.value)
            if not row.value then
              single(rest, row.label, row.labelColorKey or COLOR_BODY)
            end
          else
            single(rest, row.value, row.colorKey or COLOR_MUTED)
          end
        end
      end
    end
  end
  part(rest)

  for index, list in ipairs(parts) do
    if index > 1 then
      lines[#lines + 1] = { text = " ", gap = true, colorKey = COLOR_BODY }
    end
    for _, line in ipairs(list) do
      lines[#lines + 1] = line
    end
  end
  return lines
end

--- Brief TV4: a quest row's hover in the window, the same card the quest page's header hover draws:
--- the title the page heads with ("Quest: Riverpaw Gnoll Bounty (11)", the quest id kept) and the
--- lines (InfoPanel.QuestTooltipLines). opts is the window's own, as InfoPanel.QuestContent takes
--- it. nil for a quest id that is not one. The client is asked about this one quest the way the
--- page asks (ViewModel.Quest, once per session).
function InfoPanel.QuestCard(questId, opts)
  questId = tonumber(questId)
  if not questId or questId <= 0 then
    return nil, nil
  end
  local content = InfoPanel.QuestContent(questId, false, opts)
  local header = type(content) == "table" and content.header or nil
  local title = type(header) == "table" and header.name or nil
  if type(title) ~= "string" or title == "" then
    return nil, nil
  end
  return title, InfoPanel.QuestTooltipLines(content)
end

--------------------------------------------------------------------------------
-- A creature root (brief E57)
--------------------------------------------------------------------------------

-- The section keys the creature page draws under, so a spec and a caller can name one.
local CREATURE_SECTION = "creature"
local CREATURE_ZONES = "creaturezones"

-- How many places the column lists before it counts the rest out. Six is what fits beside the
-- model without pushing the Loot tab's own answer off the bottom of a short window, and the line
-- under them says how many are left.
local CREATURE_ZONE_ROWS = 6

-- Brief Z1: the zone key one place line leads to, and the words its hover says, or nil for a place
-- with no area id. A creature's and a node's places are links to the zone's own page. Pure.
function InfoPanel.ZoneLinkOf(zone)
  local graph = ItemTree.Graph
  local areaId = type(zone) == "table" and tonumber(zone.areaId) or nil
  local name = type(zone) == "table" and zone.name or nil
  if not areaId or type(graph) ~= "table" or type(graph.Key) ~= "function" then
    return nil, nil
  end
  local hint = nil
  if type(name) == "string" and name ~= "" then
    hint = string.format(L["Click to open %s"], name)
  end
  return graph.Key("zone", areaId), hint
end

-- What the shipped Classic Era table states about the creature one node key names, or nil.
-- Core/EraSources.lua is read through the namespace and pcall'd like every other module here, so
-- a load without it, and a build compiled with --no-era-sources, costs the column this page and
-- nothing else. Nothing at all is asked of the client: the table is ours.
local function eraCreatureFacts(key)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.CreatureFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(era.CreatureFacts, era, key)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- What the shipped Classic Era table states about the vendor one npc key names, or nil.
local function eraVendorFacts(key)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.VendorFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(era.VendorFacts, era, key)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- How many quests the shipped Classic Era table says the NPC one npc key names starts and ends
-- (Core/EraSources.lua E:QuestGiverCounts, brief N3), with nothing decoded. 0, 0 for none.
local function eraQuestCounts(key)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.QuestGiverCounts) ~= "function" then
    return 0, 0
  end
  local ok, starts, ends = pcall(era.QuestGiverCounts, era, key)
  if not ok then
    return 0, 0
  end
  return tonumber(starts) or 0, tonumber(ends) or 0
end

-- Brief RB1 (owner QA 2026-10-17 item 197): how many quests one npc key starts and ends, the very
-- rows its Quests tab counts (Core/ViewModel.lua ViewModel.NpcQuestCounts: the predicted quest facts'
-- givers and turn ins too, Predicted rows included while they are shown), with the window's own
-- options where the caller hands none, so the line and the tab never disagree. The Classic Era list
-- lengths alone (eraQuestCounts) where the view model is not loaded. 0, 0 for none. A field rather
-- than a local: this file is at Lua's 200 locals.
function InfoPanel.NpcQuestCounts(key, opts)
  local vm = ItemTree.ViewModel
  if type(vm) ~= "table" or type(vm.NpcQuestCounts) ~= "function" then
    return eraQuestCounts(key)
  end
  if type(opts) ~= "table" then
    local ui = ItemTree.UI
    local frame = type(ui) == "table" and ui.Frame or nil
    local settings = type(ItemTree.db) == "table" and ItemTree.db.settings or nil
    if type(frame) == "table" and type(frame.OptionsFromSettings) == "function" then
      local ok, answer = pcall(frame.OptionsFromSettings, settings)
      opts = ok and type(answer) == "table" and answer or nil
    end
    opts = opts or { showPredicted = showingPredicted(nil) }
  end
  local ok, starts, ends = pcall(vm.NpcQuestCounts, key, opts)
  if not ok then
    return 0, 0
  end
  return tonumber(starts) or 0, tonumber(ends) or 0
end

-- What the player's own records say about one npc key (Core/Collector.lua C:NpcFacts), or nil.
local function collectedNpcFacts(key)
  local collector = ItemTree.collector
  if type(collector) ~= "table" or type(collector.NpcFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(collector.NpcFacts, collector, key)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- Brief M3: the Merchant's Favor half of Core/Sources.lua, or nil.
local function favourModule()
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) ~= "table" then
    return nil
  end
  return favour
end

-- What the curated tier ships about the Merchant's Favor vendor one npc key names, or nil.
local function favourVendorFacts(key)
  local facts = moduleCall(favourModule(), "VendorFacts", key)
  if type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- Brief V1: what the client's own vendor tables say about the vendor one npc key names
-- (Core/ForeverVendors.lua Facts), or nil.
local function clientVendorFacts(key)
  local facts = moduleCall(ItemTree.ForeverVendors, "Facts", key)
  if type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- The level band as plain numbers: "23 to 24", or the one number where the band is one level.
-- Core/Sources.lua's own LevelBand says "level 23 to 24", which is the right words on a source
-- row and says the label twice in a labelled column. Pure.
function InfoPanel.CreatureLevel(low, high)
  low, high = tonumber(low), tonumber(high)
  if not low then
    return nil
  end
  if not high or high <= low then
    return tostring(low)
  end
  return string.format(L["%d to %d"], low, high)
end

-- Brief P6b: the words the side icon beside an NPC page's name stands for, by the shipped table's
-- own side numbers (cf). 3 is both sides, which the window calls neutral. Each is the English
-- wording and its own locale key; the row's tooltip says the same words (UI/Tree.lua SIDE_WORDS).
InfoPanel.HEADER_SIDES = { [1] = "Alliance", [2] = "Horde", [3] = "Neutral (both sides)" }

-- The size of that icon, the name's own font size so it sits on the line like a letter.
InfoPanel.SIDE_ICON = (type(Theme) == "table" and Theme.fontSizes and Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD) or 13

-- A side number the header can draw (1, 2 or 3), or nil. Pure.
function InfoPanel.SideOf(faction)
  if InfoPanel.HEADER_SIDES[faction] then
    return faction
  end
  return nil
end

-- The word a header's side stands for, translated, or nil. Pure.
function InfoPanel.SideWord(side)
  local word = InfoPanel.HEADER_SIDES[side]
  return word and L[word] or nil
end

-- Brief P6b: the header's name with the side icon after it, "Gimble Thistlefuzz |A:...|a", or the
-- name alone where the header states no side or the Assets table carries no key for it. The
-- header's own name stays plain, because the hover, the breadcrumb and a search read it. Pure.
function InfoPanel.HeaderName(header)
  if type(header) ~= "table" then
    return nil
  end
  local name = header.name
  local key = type(Assets) == "table" and type(Assets.SIDES) == "table" and Assets.SIDES[header.side] or nil
  if type(name) ~= "string" or name == "" or not key then
    return name
  end
  if type(Assets.Has) == "function" and not Assets.Has(key) then
    return name
  end
  local ok, markup = pcall(Assets.Markup, key, InfoPanel.SIDE_ICON)
  if not ok or type(markup) ~= "string" then
    return name
  end
  return name .. " " .. markup
end

-- Brief P6b: "Teaches 28 recipes" or "Teaches 1 recipe", the line a trainer's facts block gains,
-- out of the length of the shipped table's tr list for it. nil for none. Pure.
function InfoPanel.TeachesLine(count)
  local n = math.floor(tonumber(count) or 0)
  if n < 1 then
    return nil
  end
  if n == 1 then
    return L["Teaches 1 recipe"]
  end
  return string.format(L["Teaches %d recipes"], n)
end

-- That line as the rows a caller appends: empty for a creature that teaches nothing, or with "Show
-- predicted data" off, because every one of those recipes is a Classic Era fact. Pure.
function InfoPanel.TeachesRows(count, opts)
  if not showingPredicted(opts) then
    return {}
  end
  local line = InfoPanel.TeachesLine(count)
  if not line then
    return {}
  end
  return { { kind = "fact", key = "npcteaches", value = line, colorKey = COLOR_BODY } }
end

-- The header for a creature root: the creature's own name, and the glyph for the kind of creature
-- it is, which is the same glyph its rows wear in the tree.
--
-- The name and nothing else. A creature node's id is one the ADDON made up out of the name's place
-- in the shipped string table, and the owner's rule is that no made up id appears anywhere a
-- player reads: not here, not in the window title, not in the breadcrumb and not in Recently
-- viewed (Core/Graph.lua Graph.Title is where the other three are answered).
function InfoPanel.CreatureHeader(facts)
  local name = L["Unknown creature"]
  if type(facts) == "table" and type(facts.name) == "string" and facts.name ~= "" then
    name = facts.name
  end
  local asset = nil
  if type(facts) == "table" then
    local key = moduleCall(ItemTree.ViewModel, "CreatureIcon", { type = facts.type, family = facts.family })
    if type(key) == "string" and key ~= "" then
      asset = key
    end
  end
  return {
    name = name,
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = {},
    asset = asset,
    -- Brief P6b: the side it serves, for the icon beside the name (InfoPanel.HeaderName).
    side = type(facts) == "table" and InfoPanel.SideOf(facts.faction) or nil,
  }
end

-- Brief E90: where a creature, a node, a fishing pool or a chest is, as one line a page's header
-- carries: "Silverpine Forest 45.2, 61.0; 44.8, 62.3 and 5 more". places is what E:Places answers
-- ({ zone, points = { { x, y }, ... }, more }), already capped at three. Each point to one decimal,
-- the way the game's own map prints it. bare leaves the zone's name off, for a line that sits
-- under the zone's own row (brief N4). nil for nothing to say. Pure.
function InfoPanel.WhereText(places, bare)
  if type(places) ~= "table" or type(places.points) ~= "table" then
    return nil
  end
  local coords = {}
  for _, point in ipairs(places.points) do
    local x = type(point) == "table" and tonumber(point.x) or nil
    local y = type(point) == "table" and tonumber(point.y) or nil
    if x and y then
      coords[#coords + 1] = string.format("%.1f, %.1f", x, y)
    end
  end
  if #coords == 0 then
    return nil
  end
  local text = table.concat(coords, "; ")
  if not bare and type(places.zone) == "string" and places.zone ~= "" then
    text = places.zone .. " " .. text
  end
  local more = math.floor(tonumber(places.more) or 0)
  if more > 0 then
    text = string.format(L["%s and %d more"], text, more)
  end
  return text
end

-- The section a page with a Map view leads with (brief E90): the "Where" line, right under the
-- header, or nil. Every pin is a Classic Era fact, so with "Show predicted data" off there is none,
-- as for the rest of the page's Classic Era facts. Pure.
function InfoPanel.WhereSection(places, opts)
  if not showingPredicted(opts) then
    return nil
  end
  local text = InfoPanel.WhereText(places)
  if not text then
    return nil
  end
  return {
    key = "where",
    rows = { { kind = "fact", key = "where", label = L["Where"], value = text, colorKey = COLOR_BODY } },
  }
end

-- Brief N4: one zone's pins out of a decoded pin list ({ area, map, x, y }, E:PinsOf's shape), in
-- the shape InfoPanel.WhereText reads: { areaId, points = { { x, y }, ... }, more }, at most three
-- points and more counting only that zone's pins the answer leaves out. nil for none there. Pure.
function InfoPanel.ZonePlaces(pins, areaId)
  if type(pins) ~= "table" or areaId == nil then
    return nil
  end
  local points, count = {}, 0
  for _, pin in ipairs(pins) do
    if type(pin) == "table" and pin.area == areaId and type(pin.x) == "number" and type(pin.y) == "number" then
      count = count + 1
      if #points < 3 then
        points[#points + 1] = { x = pin.x, y = pin.y }
      end
    end
  end
  if count == 0 then
    return nil
  end
  return { areaId = areaId, points = points, more = count - #points }
end

-- Brief N4: where the client's waypoint goes for a page with exactly one position in all: the
-- pin's zone map and its place in 0 to 1, the shape UI/Map.lua Map.SetWaypoint takes. nil for no
-- pins, several, a pin with no map, or one off the map. Pure.
function InfoPanel.WaypointOf(pins)
  if type(pins) ~= "table" or #pins ~= 1 then
    return nil
  end
  local pin = pins[1]
  if type(pin) ~= "table" or type(pin.map) ~= "number" then
    return nil
  end
  local x, y = tonumber(pin.x), tonumber(pin.y)
  if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
    return nil
  end
  return { map = pin.map, x = x / 100, y = y / 100 }
end

-- Brief UX1 (QA item 402): what a Where row's waypoint is for, the words the "Waypoint added" toast
-- says (UI/Toast.lua): the row's own (entry.waypointFor, the placed object a spot is), else the name
-- the page heads with ("Hogger", "Copper Vein"). Never the coordinates. nil for neither. Pure.
function InfoPanel.WaypointFor(entry, content)
  if type(entry) == "table" and type(entry.waypointFor) == "string" and entry.waypointFor ~= "" then
    return entry.waypointFor
  end
  local header = type(content) == "table" and content.header or nil
  local name = type(header) == "table" and header.name or nil
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Brief N4: puts the Where lines on a page under its zones rather than over everything. content is
-- a page's content, zonesKey the key of its "Known in" section, pins the key's decoded pins and
-- nameOf(areaId) the zone's name. Each zone row that carries an areaId with pins there gains a
-- Where row directly under it, the coordinates alone because the zone is named just above. Where
-- no listed zone has a pin, the zone the map opens on is named in one Where row after the zones,
-- and a page with no zones section leads with it, as InfoPanel.WhereSection's line did. A page
-- with exactly one position in all carries the waypoint on its one Where row
-- (InfoPanel.WaypointOf). A Classic Era fact, so "Show predicted data" off adds nothing. Pure.
function InfoPanel.PlaceWhere(content, zonesKey, pins, opts, nameOf)
  if type(content) ~= "table" or type(content.sections) ~= "table" then
    return content
  end
  if not showingPredicted(opts) or type(pins) ~= "table" or #pins == 0 then
    return content
  end
  local waypoint = InfoPanel.WaypointOf(pins)
  -- Brief UX1: what that waypoint is for, the page's own name, which its toast says.
  local waypointFor = waypoint and InfoPanel.WaypointFor(nil, content) or nil

  -- One Where row: coordinates only under a zone row, the zone named where it stands on its own.
  local function whereRow(places, bare)
    local text = InfoPanel.WhereText(places, bare)
    if not text then
      return nil
    end
    return {
      kind = "fact",
      key = "where" .. tostring(places.areaId or ""),
      label = L["Where"],
      value = text,
      colorKey = COLOR_BODY,
      waypoint = waypoint,
      waypointFor = waypointFor,
    }
  end

  -- The zone the pins mostly stand in, which is the zone a Map tab opens on (EraSources.ZonePins'
  -- rule: the first of them on a tie), named in its own Where row.
  local function busiestRow()
    local counts, best = {}, nil
    for _, pin in ipairs(pins) do
      local area = type(pin) == "table" and pin.area or nil
      if area ~= nil then
        counts[area] = (counts[area] or 0) + 1
        if not best or counts[area] > counts[best] then
          best = area
        end
      end
    end
    local places = InfoPanel.ZonePlaces(pins, best)
    if not places then
      return nil
    end
    if type(nameOf) == "function" then
      local ok, name = pcall(nameOf, best)
      places.zone = ok and name or nil
    end
    return whereRow(places, false)
  end

  local section = nil
  for _, candidate in ipairs(content.sections) do
    if zonesKey ~= nil and candidate.key == zonesKey then
      section = candidate
      break
    end
  end
  if not section then
    local where = busiestRow()
    if where then
      table.insert(content.sections, 1, { key = "where", rows = { where } })
    end
    return content
  end
  local rows, placed, lastZone = {}, false, 0
  for _, row in ipairs(section.rows or {}) do
    rows[#rows + 1] = row
    if row.areaId ~= nil then
      lastZone = #rows
      local places = InfoPanel.ZonePlaces(pins, row.areaId)
      local where = places and whereRow(places, true) or nil
      if where then
        rows[#rows + 1] = where
        lastZone = #rows
        placed = true
      end
    end
  end
  if not placed then
    local where = busiestRow()
    if where then
      table.insert(rows, lastZone + 1, where)
    end
  end
  section.rows = rows
  return content
end

-- Puts a page's Where lines under its zones (InfoPanel.PlaceWhere): the decoded pins the key
-- names, through the shipped table's reader and the Map tab's own cache (E:PinsOf,
-- E:ObjectPinsOf), and the zone name one area id has, through E:Places. Nothing added without a
-- reader. Guarded.
local function placeWhere(content, key, zonesKey, opts)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.PinSubject) ~= "function" then
    return content
  end
  -- Brief EK1: the reader's PinSubject, which reads a creature page key's name out of the table.
  local ok, field, nameIndex = pcall(era.PinSubject, era, key)
  -- Brief EK1 2b step 1: a Forever page (npc:<id>) that joins a Classic Era name (E:NpcNameAt) says
  -- where that name stands, as the Classic Era page of the name does: its pins are read through
  -- that page's key. A Forever page that joins no name is left as it was.
  -- A merged page (cm) is that page's own key, and PinSubject reads a positive key out of the built
  -- table alone, so it may answer nothing before the table is built. NpcNameAt builds it, so
  -- PinSubject is asked again whenever PageKey answers a key, the page's own included, and the
  -- Where line does not hang on what the page asked first.
  if ok and not field and type(era.NpcNameAt) == "function" and type(era.PageKey) == "function" then
    local joined, joinedIndex = pcall(era.NpcNameAt, era, key)
    local paged, pageKey = false, nil
    if joined and type(joinedIndex) == "number" then
      paged, pageKey = pcall(era.PageKey, era, joinedIndex)
    end
    if paged and type(pageKey) == "string" then
      key = pageKey
      ok, field, nameIndex = pcall(era.PinSubject, era, key)
    end
  end
  local reader = nil
  if ok and field == "mp" then
    reader = era.PinsOf
  elseif ok and field == "op" then
    reader = era.ObjectPinsOf
  end
  if type(reader) ~= "function" then
    return content
  end
  local fine, pins = pcall(reader, era, nameIndex)
  if not fine or type(pins) ~= "table" then
    return content
  end
  return InfoPanel.PlaceWhere(content, zonesKey, pins, opts, function(areaId)
    if type(era.Places) ~= "function" then
      return nil
    end
    local done, places = pcall(era.Places, era, key, areaId)
    return done and type(places) == "table" and places.zone or nil
  end)
end

-- The side words the title line says, by number: the same words InfoPanel.SIDE_WORDS gives a
-- vendor's Side line, for the two that are one sided.
local TITLE_SIDES = { [1] = "Alliance", [2] = "Horde" }

-- Brief T2b: the line an NPC's page leads with, under its name: the title the shipped table gives
-- it and the side where it serves only one, "<Wrought Iron Supplies>, Alliance". Either half is
-- left out where the table states none, and a side of 3 says nothing here (the page's own Side
-- line says "Alliance and Horde"). nil for nothing to say. Pure.
function InfoPanel.TitleLine(title, faction)
  local bracketed = nil
  if type(title) == "string" and title ~= "" then
    bracketed = "<" .. title .. ">"
  end
  local side = nil
  if faction == 1 or faction == 2 then
    side = L[TITLE_SIDES[faction]]
  end
  if bracketed and side then
    return bracketed .. ", " .. side
  end
  return bracketed or side
end

-- Brief T2b: that line as the section a page's sections lead with, in the muted face, or nil. A
-- Classic Era fact like the rest of the page, so "Show predicted data" off says none. Pure.
function InfoPanel.TitleSection(title, faction, opts)
  if not showingPredicted(opts) then
    return nil
  end
  local line = InfoPanel.TitleLine(title, faction)
  if not line then
    return nil
  end
  return { key = "npctitle", rows = { { kind = "fact", key = "npctitle", value = line, colorKey = COLOR_MUTED } } }
end

-- Leads a page's sections with the title line where there is one.
local function addTitle(content, facts, opts)
  if type(facts) ~= "table" then
    return content
  end
  local section = InfoPanel.TitleSection(facts.title, facts.faction, opts)
  if section then
    table.insert(content.sections, 1, section)
  end
  return content
end

-- Brief D5: "3 not yet found on your realm", for the withheld items a creature's loot or a quest's
-- items leave out while Classic Era details are off and the client cannot name them. nil for none.
-- Pure.
function InfoPanel.LockedLine(count)
  local n = tonumber(count)
  if not n or n < 1 then
    return nil
  end
  return string.format(L["%d not yet found on your realm"], math.floor(n))
end

-- Everything the column says about a creature, under the model: what kind of thing it is, what
-- level it was, whether the table calls it a boss, and the places it is known in, then the two
-- lines every Classic Era fact ends on.
--
-- With the window's "Show predicted data" tick box off the whole block goes, because every one of
-- these facts is a prediction, exactly as the quest block above it does. Pure.
function InfoPanel.CreatureSections(facts, opts)
  local sections = {}
  if type(facts) ~= "table" or not showingPredicted(opts) then
    return sections
  end
  local Sources = ItemTree.Sources
  local rows = {}

  local typeWord = type(Sources) == "table" and Sources.CREATURE_TYPES and Sources.CREATURE_TYPES[facts.type] or nil
  if typeWord then
    rows[#rows + 1] =
      { kind = "fact", key = "creaturetype", label = L["Type"], value = L[typeWord], colorKey = COLOR_BODY }
  end
  local familyWord = type(Sources) == "table" and Sources.CREATURE_FAMILIES and Sources.CREATURE_FAMILIES[facts.family]
    or nil
  if familyWord then
    rows[#rows + 1] =
      { kind = "fact", key = "creaturefamily", label = L["Family"], value = L[familyWord], colorKey = COLOR_BODY }
  end
  local level = InfoPanel.CreatureLevel(facts.low, facts.high)
  if level then
    rows[#rows + 1] = { kind = "fact", key = "creaturelevel", label = L["Level"], value = level, colorKey = COLOR_BODY }
  end
  if facts.boss then
    -- Said as the one word rather than as a labelled field: "Boss" is what the table knows and
    -- there is no scale behind it to put on the other side of a colon.
    rows[#rows + 1] = { kind = "fact", key = "creatureboss", value = L["Boss"], colorKey = COLOR_BODY }
  end

  -- The places, one per line, because a creature in four zones is four answers and not one long
  -- line. The Map tab draws the same list as a map (brief E59).
  local places, held = {}, 0
  for _, zone in ipairs(facts.zones or {}) do
    if type(zone) == "table" and type(zone.name) == "string" and zone.name ~= "" then
      if #places < CREATURE_ZONE_ROWS then
        local node, hint = InfoPanel.ZoneLinkOf(zone)
        places[#places + 1] = {
          kind = "fact",
          key = "creaturezone" .. tostring(zone.areaId or #places),
          areaId = zone.areaId,
          value = zone.name,
          colorKey = COLOR_BODY,
          node = node,
          hint = hint,
        }
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = moduleCall(ItemTree.Sources, "MoreText", held)
    if type(more) == "string" and more ~= "" then
      places[#places + 1] = { kind = "fact", key = "creaturezonemore", value = more, colorKey = COLOR_MUTED }
    end
  end

  local last = nil
  if #rows > 0 then
    last = { key = CREATURE_SECTION, rows = rows }
    sections[#sections + 1] = last
  end
  if #places > 0 then
    last = { key = CREATURE_ZONES, title = L["Known in"], rows = places }
    sections[#sections + 1] = last
  end
  -- Brief D5: the items its Loot tab leaves out, because the realm has not found them and Classic
  -- Era details are turned off. One line, and only when there are any.
  local locked = InfoPanel.LockedLine(facts.locked)
  if locked then
    last = {
      key = "creaturelocked",
      rows = { { kind = "fact", key = "creaturelocked", value = locked, colorKey = COLOR_MUTED } },
    }
    sections[#sections + 1] = last
  end
  if not last then
    return sections
  end

  -- What every one of those lines is worth, once, at the foot of the last of them: the same two
  -- lines the quest block closes on, so a player reads one sentence about this data wherever it
  -- is drawn.
  local confidence = ItemTree.Confidence
  local note = confidenceNote(type(confidence) == "table" and confidence.PREDICTED or nil)
  if note then
    last.rows[#last.rows + 1] = { kind = "fact", key = "creatureconfidence", value = note, colorKey = COLOR_MUTED }
  end
  last.rows[#last.rows + 1] = {
    kind = "para",
    key = "creatureprovenance",
    value = L["From Classic Era. WoW Forever may have changed this."],
    colorKey = COLOR_MUTED,
  }
  return sections
end

--- Brief BQ4 (QA item 25): the facts CreatureSections reads, with the instance the Boss loot index
--- files the creature under as its one place where the shipped table states none
--- (Creatures.BossZones), so a summoned boss reads "Known in Wailing Caverns" as Skum does. The
--- table's own facts are never changed: a copy carries the zones. The index is the one a boss's
--- "Boss of" line already reads (InfoPanel.BossOfFor), asked only when a page has no zones. Guarded.
function InfoPanel.FactsWithBossPlace(facts, key)
  if type(facts) ~= "table" or (type(facts.zones) == "table" and #facts.zones > 0) then
    return facts
  end
  local creatures = ItemTree.Creatures
  if type(creatures) ~= "table" or type(creatures.BossZones) ~= "function" then
    return facts
  end
  local boss = InfoPanel.BossOfFor(key, nil)
  if not boss then
    return facts
  end
  local ok, zones = pcall(creatures.BossZones, facts.zones, boss)
  if not ok or type(zones) ~= "table" or #zones == 0 then
    return facts
  end
  local copy = {}
  for field, value in pairs(facts) do
    copy[field] = value
  end
  copy.zones = zones
  return copy
end

-- Everything the pane says about one creature root, or nil for an npc key that names no creature:
-- a vendor, the world drop node, a summary row. Such a key falls through to the item column, which
-- is what it drew before this existed.
--
-- content.display is the id the one model on the page is drawn from, where the table ships one.
-- Nothing here asks the client for it: the id was checked against this build's own
-- CreatureDisplayInfo before it was shipped, and the drawing half below decides what to do with it.
function InfoPanel.CreatureContent(key, showChanges, opts)
  local facts = eraCreatureFacts(key)
  -- Brief N3: a name only vendor rows name has a kind now, for its portrait and its map, and its
  -- page is still a vendor's: InfoPanel.NpcContent draws it, with the portrait.
  if not facts or facts.role == "vendor" then
    return nil
  end
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  local content = {
    kind = "creature",
    nameIndex = facts.nameIndex,
    display = facts.display,
    creature = facts,
    showChanges = showChanges and true or false,
    found = true,
    header = InfoPanel.CreatureHeader(facts),
    sections = InfoPanel.CreatureSections(InfoPanel.FactsWithBossPlace(facts, key), opts),
  }
  -- Brief N2: a creature that also sells, or one the player looted or bought from, keeps its own
  -- header and gains the "Sells" count and where the player saw it, in a block of their own under
  -- the Classic Era facts.
  local collected = collectedNpcFacts(key)
  local trade = InfoPanel.NpcTradeRows(InfoPanel.SellsCount(key, eraVendorFacts(key), collected, opts), collected)
  -- Brief N3: and the quests it starts and ends, in the same block. Brief RB1: the tab's own rows.
  local starts, ends = InfoPanel.NpcQuestCounts(key, opts)
  for _, row in ipairs(InfoPanel.QuestGiverRows(starts, ends, opts)) do
    trade[#trade + 1] = row
  end
  -- Brief P6b: and how many recipes it teaches, which its Teaches tab lists.
  for _, row in ipairs(InfoPanel.TeachesRows(facts.teaches, opts)) do
    trade[#trade + 1] = row
  end
  if #trade > 0 then
    table.insert(content.sections, 1, { key = "npc", rows = trade })
  end
  if #content.sections == 0 then
    content.sections = {
      {
        key = CREATURE_SECTION,
        rows = {
          {
            kind = "fact",
            key = "unknown",
            value = L["Nothing known about this creature yet"],
            colorKey = COLOR_MUTED,
          },
        },
      },
    }
  end
  return addTitle(placeWhere(content, key, CREATURE_ZONES, opts), facts, opts)
end

--------------------------------------------------------------------------------
-- An NPC root: a vendor, and anything the player looted or bought from (brief N2)
--------------------------------------------------------------------------------

-- The side words a vendor's f states, by number. 3 is both sides, said in full: on a vendor's own
-- page "which side can buy here" is the question, and "both" is an answer to it. Each word is the
-- English wording and its own locale key.
InfoPanel.SIDE_WORDS = { [1] = "Alliance", [2] = "Horde", [3] = "Alliance and Horde" }

-- How many rows the page's Sells tab holds, or 0. The view model's own count where it can say, so
-- the line and the tab never disagree; otherwise the larger of the two sources' own counts, which
-- is the least the tab can hold. Pure over what it is handed.
function InfoPanel.SellsCount(key, vendor, collected, opts)
  local predicted = showingPredicted(opts)
  local edges = ItemTree.Edges
  local view = (type(edges) == "table" and edges.SELLS) or "sells"
  -- Brief CT1b (QA item 227): a page with no Sells tab (a class trainer) has no count of it to ask
  -- for, and asking counted every other tab of the page again under this line's own options.
  local views = moduleCall(ItemTree.ViewModel, "ViewsFor", key)
  local tabbed = type(views) ~= "table"
  for _, each in ipairs(type(views) == "table" and views or {}) do
    tabbed = tabbed or each == view
  end
  local counts = nil
  if tabbed then
    counts = moduleCall(ItemTree.ViewModel, "ViewCounts", key, { showPredicted = predicted })
  end
  if type(counts) == "table" and type(counts[view]) == "number" then
    return counts[view]
  end
  local shipped = (predicted and type(vendor) == "table" and tonumber(vendor.total)) or 0
  local seen = (type(collected) == "table" and tonumber(collected.sells)) or 0
  return math.max(shipped, seen)
end

-- The lines an NPC's page adds for what it sells and where the player saw it: "Sells 12" and
-- "Seen in Elwynn Forest". A creature that also sells keeps its own header and facts and gains
-- these under them. Empty where there is nothing to say. Pure.
function InfoPanel.NpcTradeRows(sells, collected)
  local rows = {}
  local count = tonumber(sells)
  if count and count > 0 then
    rows[#rows + 1] = {
      kind = "fact",
      key = "npcsells",
      label = L["Sells"],
      value = tostring(math.floor(count)),
      colorKey = COLOR_BODY,
    }
  end
  local zone = type(collected) == "table" and collected.zone or nil
  if type(zone) == "string" and zone ~= "" then
    rows[#rows + 1] = { kind = "fact", key = "npcseen", label = L["Seen in"], value = zone, colorKey = COLOR_BODY }
  end
  return rows
end

-- Brief N3: "Starts 2 quests, ends 1", "Starts 1 quest" or "Ends 3 quests", out of the two counts
-- the shipped table's quest giver lists give. nil where both are 0. Pure.
function InfoPanel.QuestGiverLine(starts, ends)
  starts = math.floor(tonumber(starts) or 0)
  ends = math.floor(tonumber(ends) or 0)
  if starts > 0 and ends > 0 then
    if starts == 1 then
      return string.format(L["Starts 1 quest, ends %d"], ends)
    end
    return string.format(L["Starts %d quests, ends %d"], starts, ends)
  end
  if starts > 0 then
    if starts == 1 then
      return L["Starts 1 quest"]
    end
    return string.format(L["Starts %d quests"], starts)
  end
  if ends > 0 then
    if ends == 1 then
      return L["Ends 1 quest"]
    end
    return string.format(L["Ends %d quests"], ends)
  end
  return nil
end

-- The one line an NPC's facts block gains for its quests (brief N3), as a list of rows so a caller
-- can append it: empty where the NPC gives none, or where "Show predicted data" is off, because
-- every one of those quests is a Classic Era fact. Pure.
function InfoPanel.QuestGiverRows(starts, ends, opts)
  if not showingPredicted(opts) then
    return {}
  end
  local line = InfoPanel.QuestGiverLine(starts, ends)
  if not line then
    return {}
  end
  return { { kind = "fact", key = "npcquests", value = line, colorKey = COLOR_BODY } }
end

-- The header for a vendor, or for an NPC only the player's own records know: its name, and the
-- vendor glyph where it sells anything. A made up id is never shown, as on a creature's page.
--
-- Brief V1: client is what the client's own vendor tables say (Core/ForeverVendors.lua Facts). Its
-- label is the name the player's visit or another local record gives it, else "Vendor (npc N)":
-- the one place a real npc id is shown, because it is the only thing the client states about it.
function InfoPanel.NpcHeader(vendor, collected, shipped, client)
  local name = nil
  if type(vendor) == "table" and type(vendor.name) == "string" and vendor.name ~= "" then
    name = vendor.name
  elseif type(collected) == "table" and type(collected.name) == "string" and collected.name ~= "" then
    name = collected.name
  elseif type(shipped) == "table" and type(shipped.name) == "string" and shipped.name ~= "" then
    -- Brief M3: a Merchant's Favor vendor the curated tier ships, before the player has met it.
    name = shipped.name
  elseif type(client) == "table" and type(client.label) == "string" and client.label ~= "" then
    name = client.label
  end
  local sells = type(vendor) == "table"
    or type(shipped) == "table"
    or type(client) == "table"
    or (type(collected) == "table" and (tonumber(collected.sells) or 0) > 0)
  return {
    name = name or L["Unknown NPC"],
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = {},
    asset = sells and "CAT_VENDOR" or nil,
    -- Brief P6b: the side the shipped table gives the vendor, for the icon beside the name.
    side = type(vendor) == "table" and InfoPanel.SideOf(vendor.faction) or nil,
  }
end

-- Brief M3: "Vendor, Alliance, Redridge Mountains", the line a shipped Merchant's Favor vendor's
-- page leads with. Either half is left out where the file states none. Pure.
function InfoPanel.VendorLine(shipped)
  if type(shipped) ~= "table" then
    return nil
  end
  local side = type(shipped.faction) == "string" and shipped.faction ~= "" and L[shipped.faction] or nil
  local zone = type(shipped.zone) == "string" and shipped.zone ~= "" and shipped.zone or nil
  if side and zone then
    return string.format(L["Vendor, %s, %s"], side, zone)
  end
  return moduleCall(ItemTree.Sources, "Note", L["Vendor"], side, zone) or L["Vendor"]
end

-- Brief M3: the rows a shipped Merchant's Favor vendor's page says about it: the vendor line, what
-- it does and where in the zone ("Supply Officer, Three Corners"), and the pages it rests on. Pure.
function InfoPanel.FavourVendorRows(shipped)
  local rows = {}
  if type(shipped) ~= "table" then
    return rows
  end
  rows[#rows + 1] = { kind = "fact", key = "npcfavour", value = InfoPanel.VendorLine(shipped), colorKey = COLOR_BODY }
  local role = type(shipped.role) == "string" and shipped.role ~= "" and shipped.role or nil
  local area = type(shipped.area) == "string" and shipped.area ~= "" and shipped.area or nil
  local place = moduleCall(ItemTree.Sources, "Note", role, area)
  if type(place) == "string" and place ~= "" then
    rows[#rows + 1] = { kind = "fact", key = "npcfavourrole", value = place, colorKey = COLOR_BODY }
  end
  local cited = moduleCall(favourModule(), "CommunityText", shipped.sources)
  if type(cited) == "string" and cited ~= "" then
    rows[#rows + 1] = { kind = "para", key = "npcfavoursource", value = cited, colorKey = COLOR_MUTED }
  end
  return rows
end

-- Brief V1: the rows a vendor the client's own tables list says about it: "Vendor, Stormwind City"
-- (or "Vendor" where no words name its area), and the tier's own words under it. Pure.
function InfoPanel.ClientVendorRows(client)
  local rows = {}
  if type(client) ~= "table" then
    return rows
  end
  local zone = type(client.zone) == "string" and client.zone ~= "" and client.zone or nil
  local line = moduleCall(ItemTree.Sources, "Note", L["Vendor"], zone) or L["Vendor"]
  rows[#rows + 1] = { kind = "fact", key = "npcclient", value = line, colorKey = COLOR_BODY }
  rows[#rows + 1] = { kind = "para", key = "npcclientsource", value = L["From client data"], colorKey = COLOR_MUTED }
  return rows
end

-- Everything the column says about a vendor, or an NPC the player looted or bought from that the
-- shipped table does not call a creature: "Vendor", the side it serves, how many things it sells,
-- where the player saw it and the places the table knows it in. The Classic Era facts go with the
-- "Show predicted data" tick box, as a creature's do; what the player saw stays. Pure.
function InfoPanel.NpcSections(vendor, collected, sells, opts, quests, shipped, client)
  local sections = {}
  local predicted = showingPredicted(opts)
  if not predicted then
    vendor = nil
  end
  local rows = {}
  local selling = type(vendor) == "table" or (type(collected) == "table" and (tonumber(collected.sells) or 0) > 0)
  if type(shipped) == "table" then
    -- Brief M3: a shipped Merchant's Favor vendor says more than "Vendor" in its first line. It is
    -- a community note rather than a prediction, so the predicted tick box leaves it be.
    for _, row in ipairs(InfoPanel.FavourVendorRows(shipped)) do
      rows[#rows + 1] = row
    end
  elseif type(client) == "table" then
    -- Brief V1: a vendor the client's own tables list. The client's statement, not a prediction,
    -- so the predicted tick box leaves it be too.
    for _, row in ipairs(InfoPanel.ClientVendorRows(client)) do
      rows[#rows + 1] = row
    end
  elseif selling then
    rows[#rows + 1] = { kind = "fact", key = "npcvendor", value = L["Vendor"], colorKey = COLOR_BODY }
  end
  -- Brief T2b: a vendor that serves one side says so in the line under its name
  -- (InfoPanel.TitleLine), so this line is left for the vendor both sides can use.
  local side = type(vendor) == "table" and vendor.faction == 3 and InfoPanel.SIDE_WORDS[3] or nil
  if side then
    rows[#rows + 1] = { kind = "fact", key = "npcside", label = L["Side"], value = L[side], colorKey = COLOR_BODY }
  end
  for _, row in ipairs(InfoPanel.NpcTradeRows(sells, collected)) do
    rows[#rows + 1] = row
  end
  -- Brief N3: quests is { starts, ends }, the two counts of the quests it gives, where known.
  if type(quests) == "table" then
    for _, row in ipairs(InfoPanel.QuestGiverRows(quests[1], quests[2], opts)) do
      rows[#rows + 1] = row
    end
  end
  if #rows > 0 then
    sections[#sections + 1] = { key = "npc", rows = rows }
  end
  if type(vendor) ~= "table" then
    return sections
  end
  local places, held = {}, 0
  for _, zone in ipairs(vendor.zones or {}) do
    if type(zone) == "table" and type(zone.name) == "string" and zone.name ~= "" then
      if #places < CREATURE_ZONE_ROWS then
        places[#places + 1] = {
          kind = "fact",
          key = "npczone" .. tostring(zone.areaId or #places),
          areaId = zone.areaId,
          value = zone.name,
          colorKey = COLOR_BODY,
        }
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = moduleCall(ItemTree.Sources, "MoreText", held)
    if type(more) == "string" and more ~= "" then
      places[#places + 1] = { kind = "fact", key = "npczonemore", value = more, colorKey = COLOR_MUTED }
    end
  end
  local last = sections[#sections]
  if #places > 0 then
    last = { key = "npczones", title = L["Known in"], rows = places }
    sections[#sections + 1] = last
  end
  -- The same closing line every Classic Era block ends on.
  if last then
    last.rows[#last.rows + 1] = {
      kind = "para",
      key = "npcprovenance",
      value = L["From Classic Era. WoW Forever may have changed this."],
      colorKey = COLOR_MUTED,
    }
  end
  return sections
end

-- Brief PS5: what the shipped player module says about an npc key (Core/PlayerSources.lua
-- NpcFacts), or nil. Loads the module, as an npc page's tabs already have.
function InfoPanel.PlayerNpcFacts(key)
  local facts = moduleCall(ItemTree.PlayerSources, "NpcFacts", key)
  if type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- Brief PS5: the line one role the player module gives an npc reads as, or nil for a word it does
-- not know. A trainer reads "Trainer: Leatherworking" where the module states what it trains. Pure.
function InfoPanel.PlayerRoleText(role, trains)
  if role == "vendor" then
    return L["Vendor"]
  elseif role == "giver" then
    return L["Quest giver"]
  elseif role == "ender" then
    return L["Quest turn-in"]
  elseif role == "stable" then
    return L["Stable master"]
  elseif role == "trainer" then
    if type(trains) == "string" and trains ~= "" then
      return string.format(L["Trainer: %s"], trains)
    end
    return L["Trainer"]
  end
  return nil
end

-- Brief PS5: an npc's role lines out of PlayerSources.NpcFacts, one fact row per role, plain data
-- with no line of its own. skipVendor leaves out "Vendor" where the page already says it. Pure.
function InfoPanel.PlayerRoleRows(facts, skipVendor)
  local rows = {}
  if type(facts) ~= "table" then
    return rows
  end
  for _, role in ipairs(type(facts.roles) == "table" and facts.roles or {}) do
    local text = InfoPanel.PlayerRoleText(role, facts.trains)
    if text and not (skipVendor and role == "vendor") then
      rows[#rows + 1] = { kind = "fact", key = "npcrole" .. role, value = text, colorKey = COLOR_BODY }
    end
  end
  return rows
end

-- Brief PS5: a page for an npc key gains its role lines from the player module, in the npc block
-- (made where the page has none, after its title line). "Vendor" is left out where a line of the
-- page already says the npc sells. The content, changed in place; nil stays nil.
function InfoPanel.WithPlayerRoles(content, key)
  if type(content) ~= "table" or type(content.sections) ~= "table" then
    return content
  end
  local facts = InfoPanel.PlayerNpcFacts(key)
  if not facts then
    return content
  end
  local selling = false
  for _, section in ipairs(content.sections) do
    for _, row in ipairs(type(section.rows) == "table" and section.rows or {}) do
      if row.key == "npcvendor" or row.key == "npcclient" or row.key == "npcfavour" then
        selling = true
      end
    end
  end
  local rows = InfoPanel.PlayerRoleRows(facts, selling)
  if #rows == 0 then
    return content
  end
  local at = 1
  while content.sections[at] and content.sections[at].key == "npctitle" do
    at = at + 1
  end
  local block = content.sections[at]
  if not (block and block.key == "npc") then
    block = { key = "npc", rows = {} }
    table.insert(content.sections, at, block)
  end
  for index, row in ipairs(rows) do
    table.insert(block.rows, index, row)
  end
  -- A page that said nothing is known now says something: its "nothing known" line goes.
  for index = #content.sections, 1, -1 do
    local section = content.sections[index]
    local list = type(section.rows) == "table" and section.rows or {}
    for row = #list, 1, -1 do
      if list[row].key == "unknown" then
        table.remove(list, row)
      end
    end
    if #list == 0 then
      table.remove(content.sections, index)
    end
  end
  return content
end

-- Everything the pane says about an npc root that is not a creature, or nil for one nobody knows:
-- a vendor out of the shipped table, or an NPC only the player's own records hold. Its portrait is
-- drawn only where the table ships a display id for the name (content.kind "creature" is what asks
-- for the model block); every other vendor's page is its header and its lines.
function InfoPanel.NpcContent(key, showChanges, opts)
  local vendor = eraVendorFacts(key)
  local collected = collectedNpcFacts(key)
  local shipped = favourVendorFacts(key)
  local client = clientVendorFacts(key)
  local starts, ends = eraQuestCounts(key)
  if not vendor and not collected and not shipped and not client and starts + ends == 0 then
    -- Brief PS5: an npc only the player module knows (no Classic Era, client or Creatures row): its
    -- page is its name and its role lines (InfoPanel.WithPlayerRoles, which the caller adds).
    local reported = InfoPanel.PlayerNpcFacts(key)
    -- Brief DM2: a Creatures row that names the creature has the page (InfoPanel.CreaturesContent);
    -- a row with display ids and no name (a creature only the players' recorded display ids know,
    -- such as Owen Thadd 211022) leaves the page to the player module's name, and the caller's
    -- InfoPanel.WithCreaturesModel draws its model from the row's display id.
    local row = InfoPanel.CreaturesRowFor(key)
    if not reported or (row and type(row.name) == "string" and row.name ~= "") then
      return nil
    end
    if showChanges == nil then
      showChanges = InfoPanel.showChanges
    end
    return {
      kind = "npc",
      creatureId = moduleCall(ItemTree.CreatureLookup, "IdOfKey", key),
      showChanges = showChanges and true or false,
      found = true,
      header = {
        name = type(reported.name) == "string" and reported.name ~= "" and reported.name or L["Unknown NPC"],
        quality = nil,
        colorKey = COLOR_TITLE,
        badges = {},
        asset = (tonumber(reported.sells) or 0) > 0 and "CAT_VENDOR" or nil,
      },
      sections = {
        {
          key = "npc",
          rows = {
            { kind = "fact", key = "unknown", value = L["Nothing known about this NPC yet"], colorKey = COLOR_MUTED },
          },
        },
      },
    }
  end
  -- Brief RB1: the quest line counts the Quests tab's own rows, the predicted givers and turn ins
  -- among them (the Classic Era lengths above only choose which page this is, as before).
  starts, ends = InfoPanel.NpcQuestCounts(key, opts)
  -- Brief P6b: a vendor that also trains says how many recipes it teaches, under its trade lines.
  local teaches = InfoPanel.TeachesRows(moduleCall(ItemTree.eraSources, "TeachCount", ItemTree.eraSources, key), opts)
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  local display = type(vendor) == "table" and tonumber(vendor.display) or nil
  local content = {
    kind = display and "creature" or "npc",
    display = display,
    -- Brief T8: a real npc id (npc:<id>) draws its model from the id where no display id is
    -- shipped (drawCreatureModel), which is what Galestrider's page needed.
    creatureId = moduleCall(ItemTree.CreatureLookup, "IdOfKey", key),
    vendor = vendor,
    collected = collected,
    showChanges = showChanges and true or false,
    found = true,
    header = InfoPanel.NpcHeader(vendor, collected, shipped, client),
    sections = InfoPanel.NpcSections(
      vendor,
      collected,
      InfoPanel.SellsCount(key, vendor, collected, opts),
      opts,
      { starts, ends },
      shipped,
      client
    ),
  }
  if #teaches > 0 then
    local first = content.sections[1]
    if not (first and first.key == "npc") then
      first = { key = "npc", rows = {} }
      table.insert(content.sections, 1, first)
    end
    for _, row in ipairs(teaches) do
      first.rows[#first.rows + 1] = row
    end
  end
  if #content.sections == 0 then
    content.sections = {
      {
        key = "npc",
        rows = {
          { kind = "fact", key = "unknown", value = L["Nothing known about this NPC yet"], colorKey = COLOR_MUTED },
        },
      },
    }
  end
  return addTitle(placeWhere(content, key, "npczones", opts), vendor, opts)
end

--------------------------------------------------------------------------------
-- A creature ItemTree's data knows nothing about (brief T8)
--------------------------------------------------------------------------------

-- The glyph for the creature type the client names ("Beast"), by the English words
-- Core/Sources.lua CREATURE_TYPES gives each type, else the unknown creature's, so the model's
-- block is held open while the model loads. Pure over the shipped words.
function InfoPanel.SightingAsset(creatureType)
  local Sources = ItemTree.Sources
  local types = type(Sources) == "table" and Sources.CREATURE_TYPES or nil
  if type(creatureType) == "string" and type(types) == "table" then
    for id, word in pairs(types) do
      if word == creatureType or L[word] == creatureType then
        local key = moduleCall(ItemTree.ViewModel, "CreatureIcon", { type = id })
        if type(key) == "string" and key ~= "" then
          return key
        end
      end
    end
  end
  return "CREATURE_UNKNOWN"
end

-- The words a classification is said in on that page, by Core/CreatureLookup.lua CLASSIFICATIONS
-- words, each written out so the locale scan finds it.
InfoPanel.RANK_WORDS = {
  ["Boss"] = L["Boss"],
  ["Rare elite"] = L["Rare elite"],
  ["Elite"] = L["Elite"],
  ["Rare"] = L["Rare"],
  ["Normal"] = L["Normal"],
}

--- Brief C5: how many rows a creature's Loot tab holds (the view model's own count, so the page
--- and the tab never disagree), Predicted rows included while they are shown, or 0.
function InfoPanel.CreatureLootCount(creatureId)
  local id = tonumber(creatureId)
  if not id or id <= 0 then
    return 0
  end
  local counts = moduleCall(ItemTree.ViewModel, "ViewCounts", "npc:" .. id, { showPredicted = showingPredicted(nil) })
  local edges = ItemTree.Edges
  local view = (type(edges) == "table" and edges.LOOT) or "loot"
  return type(counts) == "table" and tonumber(counts[view]) or 0
end

--- The page for a creature only the player's own sighting knows (Core/CreatureLookup.lua
--- ItemTreeDB.seenCreatures): its name, its id under the name, its level ("??" where the client
--- says -1), its classification, its creature type and where it was seen, and one muted line
--- saying ItemTree holds nothing else. The model is drawn from the creature id (content.creatureId).
--- nil for no sighting. Pure over the record.
function InfoPanel.SightingContent(sighting, showChanges)
  if type(sighting) ~= "table" then
    return nil
  end
  local id = tonumber(sighting.npcId)
  if not id or id <= 0 then
    return nil
  end
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  local name = type(sighting.name) == "string" and sighting.name ~= "" and sighting.name or L["Unknown creature"]
  local rows = {}
  local level = moduleCall(ItemTree.CreatureLookup, "LevelText", sighting.level)
  if type(level) == "string" then
    rows[#rows + 1] = { kind = "fact", key = "creaturelevel", label = L["Level"], value = level, colorKey = COLOR_BODY }
  end
  local rank = moduleCall(ItemTree.CreatureLookup, "ClassificationWord", sighting.classification)
  if type(rank) == "string" and InfoPanel.RANK_WORDS[rank] then
    rows[#rows + 1] = { kind = "fact", key = "creaturerank", value = InfoPanel.RANK_WORDS[rank], colorKey = COLOR_BODY }
  end
  if type(sighting.creatureType) == "string" and sighting.creatureType ~= "" then
    rows[#rows + 1] = {
      kind = "fact",
      key = "creaturetype",
      label = L["Type"],
      value = sighting.creatureType,
      colorKey = COLOR_BODY,
    }
  end
  if type(sighting.zone) == "string" and sighting.zone ~= "" then
    rows[#rows + 1] =
      { kind = "fact", key = "npcseen", label = L["Seen in"], value = sighting.zone, colorKey = COLOR_BODY }
  end
  local sections = {
    {
      key = "creatureid",
      rows = {
        { kind = "fact", key = "creatureid", value = string.format(L["ID %d"], id), colorKey = COLOR_MUTED },
      },
    },
  }
  if #rows > 0 then
    sections[#sections + 1] = { key = CREATURE_SECTION, rows = rows }
  end
  -- Brief C4 addendum: a paragraph, so the line wraps within the column instead of being cut.
  -- Brief C5: said only while the Loot tab holds no rows of any kind, Predicted ones included.
  if InfoPanel.CreatureLootCount(id) == 0 then
    sections[#sections + 1] = {
      key = "sightingnone",
      rows = {
        {
          kind = "para",
          key = "sightingnone",
          value = L["ItemTree has no data for this creature yet"],
          colorKey = COLOR_MUTED,
        },
      },
    }
  end
  return {
    kind = "creature",
    creatureId = id,
    sighting = sighting,
    showChanges = showChanges and true or false,
    found = true,
    header = {
      name = name,
      quality = nil,
      colorKey = COLOR_TITLE,
      badges = {},
      asset = InfoPanel.SightingAsset(sighting.creatureType),
    },
    sections = sections,
  }
end

--- Brief T8: the ways a creature page's model can be drawn, best first: the shipped display id
--- (SetDisplayInfo), then (brief C4) the first display id the Creatures data states for it, the
--- unit the page was opened from while it is still the target (SetUnit), and the creature id
--- (SetCreature), from the page's own npc id or the unit it was opened from. Each entry is
--- { how, value }. targetGuid is the target's GUID now, or nil. Pure.
function InfoPanel.ModelSources(content, targetGuid)
  local out = {}
  if type(content) ~= "table" then
    return out
  end
  local display = tonumber(content.display)
  if display then
    out[#out + 1] = { how = "display", value = display }
  end
  local creaturesDisplay = tonumber(content.creaturesDisplay)
  if creaturesDisplay and creaturesDisplay ~= display then
    out[#out + 1] = { how = "display", value = creaturesDisplay }
  end
  local origin = type(content.origin) == "table" and content.origin or nil
  if origin and type(origin.guid) == "string" and origin.guid ~= "" and origin.guid == targetGuid then
    out[#out + 1] = { how = "unit", value = "target" }
  end
  local creatureId = tonumber(content.creatureId) or (origin and tonumber(origin.npcId)) or nil
  if creatureId and creatureId > 0 and creatureId == math.floor(creatureId) then
    out[#out + 1] = { how = "creature", value = creatureId }
  end
  return out
end

--- Brief RB2: the real creature id a creature page stands for (its own id, else the id of the unit
--- it was opened from), or nil. Pure.
function InfoPanel.PageCreatureId(content)
  if type(content) ~= "table" then
    return nil
  end
  local origin = type(content.origin) == "table" and content.origin or nil
  local id = tonumber(content.creatureId) or (origin and tonumber(origin.npcId)) or nil
  if id and id > 0 and id == math.floor(id) then
    return id
  end
  return nil
end

--- Brief T8: the unit a page was last opened from (Core/CreatureLookup.lua Origin), put on the
--- content so the model can be drawn from it. The content, changed in place. Pure over the lookup.
function InfoPanel.WithOrigin(content, root)
  if type(content) ~= "table" then
    return content
  end
  local origin = moduleCall(ItemTree.CreatureLookup, "Origin", root)
  if type(origin) == "table" then
    content.origin = origin
  end
  return content
end

--------------------------------------------------------------------------------
-- A creature the Creatures data knows (brief C4)
--------------------------------------------------------------------------------

--- Brief C4: the page for a creature with no Classic Era page that the Creatures data knows (the
--- creatures testers have met, Core/Creatures.lua): its name, its title under it, its id, then
--- the level the player saw it at, its classification, its type and family and where the player
--- saw it, and the line saying where the facts come from. row is Creatures.Get's answer; sighting
--- the player's own record (Core/CreatureLookup.lua Sighting) or nil. The data's name, type and
--- classification come first and the sighting fills what the data does not state; the level and
--- the zone are the sighting's alone. The model is drawn from the data's first display id
--- (content.creaturesDisplay), then the creature id. nil for no row. Pure over the two records.
function InfoPanel.CreaturesContent(row, sighting, showChanges)
  if type(row) ~= "table" then
    return nil
  end
  local id = tonumber(row.id)
  if not id or id <= 0 then
    return nil
  end
  if type(sighting) ~= "table" or tonumber(sighting.npcId) ~= id then
    sighting = nil
  end
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  local seen = sighting or {}
  local Creatures = ItemTree.Creatures
  local name = row.name
  if type(name) ~= "string" or name == "" then
    name = type(seen.name) == "string" and seen.name ~= "" and seen.name or L["Unknown creature"]
  end
  local rows = {}
  local level = moduleCall(ItemTree.CreatureLookup, "LevelText", seen.level)
  if type(level) == "string" then
    rows[#rows + 1] = { kind = "fact", key = "creaturelevel", label = L["Level"], value = level, colorKey = COLOR_BODY }
  end
  local rank = moduleCall(Creatures, "ClassificationWord", row.classification)
  if type(rank) ~= "string" then
    local word = moduleCall(ItemTree.CreatureLookup, "ClassificationWord", seen.classification)
    rank = type(word) == "string" and InfoPanel.RANK_WORDS[word] or nil
  end
  if type(rank) == "string" then
    rows[#rows + 1] = { kind = "fact", key = "creaturerank", value = rank, colorKey = COLOR_BODY }
  end
  local typeWord = moduleCall(Creatures, "TypeWord", row.typeId)
  if type(typeWord) ~= "string" and type(seen.creatureType) == "string" and seen.creatureType ~= "" then
    typeWord = seen.creatureType
  end
  if type(typeWord) == "string" then
    rows[#rows + 1] =
      { kind = "fact", key = "creaturetype", label = L["Type"], value = typeWord, colorKey = COLOR_BODY }
  end
  local familyWord = moduleCall(Creatures, "FamilyWord", row.familyId)
  if type(familyWord) == "string" then
    rows[#rows + 1] =
      { kind = "fact", key = "creaturefamily", label = L["Family"], value = familyWord, colorKey = COLOR_BODY }
  end
  if type(seen.zone) == "string" and seen.zone ~= "" then
    rows[#rows + 1] = { kind = "fact", key = "npcseen", label = L["Seen in"], value = seen.zone, colorKey = COLOR_BODY }
  elseif type(row.trainsZone) == "string" and row.trainsZone ~= "" then
    -- Brief TR1: the zone a trainer stands in by name alone (an owner claim, "Riverglades"), where
    -- no map id is known: the name is shown and nothing routes to it.
    rows[#rows + 1] =
      { kind = "fact", key = "creaturezone", label = L["Zone"], value = row.trainsZone, colorKey = COLOR_BODY }
  end
  local sections = {}
  local title = InfoPanel.TitleLine(row.title)
  if title then
    sections[#sections + 1] =
      { key = "npctitle", rows = { { kind = "fact", key = "npctitle", value = title, colorKey = COLOR_MUTED } } }
  end
  sections[#sections + 1] = {
    key = "creatureid",
    rows = {
      { kind = "fact", key = "creatureid", value = string.format(L["ID %d"], id), colorKey = COLOR_MUTED },
    },
  }
  if #rows > 0 then
    sections[#sections + 1] = { key = CREATURE_SECTION, rows = rows }
  end
  sections[#sections + 1] = {
    key = "creaturesource",
    rows = { { kind = "para", key = "creaturesource", value = L["From client data"], colorKey = COLOR_MUTED } },
  }
  local asset = moduleCall(ItemTree.ViewModel, "CreatureIcon", { type = row.typeId, family = row.familyId })
  if type(asset) ~= "string" or asset == "" or not row.typeId then
    asset = InfoPanel.SightingAsset(seen.creatureType)
  end
  local displays = type(row.displays) == "table" and row.displays or {}
  return {
    kind = "creature",
    creatureId = id,
    creaturesDisplay = tonumber(displays[1]),
    creaturesRow = row,
    sighting = sighting,
    showChanges = showChanges and true or false,
    found = true,
    header = { name = name, quality = nil, colorKey = COLOR_TITLE, badges = {}, asset = asset },
    sections = sections,
  }
end

--- Brief C4: the Creatures row for the creature id a page stands for: its own npc:<id>, else the
--- unit it was opened from (content.origin). nil where neither names one the data knows. Builds
--- the Creatures module (a page is one of the needs that may).
function InfoPanel.CreaturesRowFor(root, content)
  local id = moduleCall(ItemTree.CreatureLookup, "IdOfKey", root)
  if not id and type(content) == "table" and type(content.origin) == "table" then
    id = tonumber(content.origin.npcId)
  end
  if not id then
    return nil
  end
  local row = moduleCall(ItemTree.Creatures, "Get", id)
  if type(row) ~= "table" then
    return nil
  end
  return row
end

--- Brief C4: a Classic Era creature page or an NPC page with no display id of its own takes the
--- Creatures data's first display id for its model (content.creaturesDisplay), and nothing else of
--- the data: the page is otherwise unchanged. The content, changed in place.
function InfoPanel.WithCreaturesModel(content, root)
  if type(content) ~= "table" or tonumber(content.display) then
    return content
  end
  local row = InfoPanel.CreaturesRowFor(root, content)
  local display = row and type(row.displays) == "table" and tonumber(row.displays[1]) or nil
  if display then
    content.creaturesDisplay = display
  end
  return content
end

--------------------------------------------------------------------------------
-- The creature's portrait in the header's square (brief PT1)
--------------------------------------------------------------------------------

--- A CreatureDisplayInfo id: a whole number above nought, or nil. A field, not a local: the file's
--- main chunk is at the 200 locals Lua allows. Pure.
function InfoPanel.WholeDisplay(value)
  value = tonumber(value)
  if value and value > 0 and value == math.floor(value) then
    return value
  end
  return nil
end

--- Brief PT1 (owner QA 2026-10-19, item 275: Faldrim Anvilmar's card wore the undead glyph while his
--- model drew from display 142826): the display id the square beside a creature's name is drawn
--- from, or nil, which leaves the square to the glyph of its kind. The header's own where the caller
--- states one (header.portrait: UI/BossLoot.lua's panel knows ids its model is not drawn from), else,
--- for a creature or NPC page, the id its model is drawn from: the shipped one (content.display),
--- then the Creatures data's first (content.creaturesDisplay). Pure.
function InfoPanel.HeaderPortrait(content)
  if type(content) ~= "table" then
    return nil
  end
  local header = type(content.header) == "table" and content.header or nil
  local stated = header and InfoPanel.WholeDisplay(header.portrait) or nil
  if stated then
    return stated
  end
  if content.kind ~= "creature" and content.kind ~= "npc" then
    return nil
  end
  return InfoPanel.WholeDisplay(content.display) or InfoPanel.WholeDisplay(content.creaturesDisplay)
end

--- Brief PT1: what one card's square drew, in the words of the /itemtree debug line. record is
--- what the draw kept on its surface ({ display, drawn }), nil where the surface drew no card yet.
--- Diagnostic words, like the rest of that command's lines, so not translated. Pure.
function InfoPanel.CardPortraitWords(record)
  if type(record) ~= "table" then
    return "no card drawn"
  end
  local display = InfoPanel.WholeDisplay(record.display)
  if not display then
    return "glyph (no display id)"
  end
  if record.drawn == true then
    return string.format("portrait from display %d", display)
  end
  return string.format("glyph (display %d asked, the client drew nothing)", display)
end

--- Brief PT1: the /itemtree debug line saying which way the last creature page's card and the Boss
--- loot tab's card went. Pure over the two records.
function InfoPanel.CardPortraitLine(pageRecord, bossRecord)
  return string.format(
    "Card portraits: page %s; Boss loot %s",
    InfoPanel.CardPortraitWords(pageRecord),
    InfoPanel.CardPortraitWords(bossRecord)
  )
end

--------------------------------------------------------------------------------
-- A boss's place (brief NP3)
--------------------------------------------------------------------------------

--- Brief NP3: the owner's words (2026-10-04), "we don't have a way to link creature boss pages back
--- to their dungeon zone (e.g. Witherfang) but we know where it comes from". The place the Boss loot
--- index files a creature page's creature under as a boss (Core/BossLoot.lua M:BossOfCreature,
--- through the shared model a zone page reads too), or nil. The page's own key, its real creature
--- id (its own, else the unit it was opened from) and the Classic Era name it joins all match, the
--- name by the creature id its page is keyed by (brief EK2: E:CreatureIdAt, never the name's place).
function InfoPanel.BossOfFor(root, content)
  local BossLoot = ItemTree.BossLoot
  local model = moduleCall(BossLoot, "Shared")
  if type(model) ~= "table" or type(model.BossOfCreature) ~= "function" then
    return nil
  end
  local creatureId = moduleCall(ItemTree.CreatureLookup, "IdOfKey", root)
  local origin = type(content) == "table" and type(content.origin) == "table" and content.origin or nil
  if not creatureId and origin then
    creatureId = tonumber(origin.npcId)
  end
  local era = ItemTree.eraSources
  local eraId = moduleCall(era, "CreatureIdAt", era, root)
  if type(eraId) ~= "number" then
    eraId = nil
  end
  local ok, boss = pcall(model.BossOfCreature, model, root, creatureId, eraId)
  if ok and type(boss) == "table" then
    return boss
  end
  return nil
end

--- Brief NP3: whether an instance's area has a zone page of its own (its Here and Map tabs), which
--- is what a "Boss of" line opens; one without opens the Boss loot tab at the boss instead.
function InfoPanel.ZoneHasPage(areaId)
  local graph = ItemTree.Graph
  local edges = ItemTree.Edges
  if type(areaId) ~= "number" or type(graph) ~= "table" or type(edges) ~= "table" then
    return false
  end
  local views = moduleCall(ItemTree.ViewModel, "ViewsFor", graph.Key("zone", areaId))
  return views ~= nil and views == edges.ZONE_VIEWS
end

--- Brief NP3: "Boss of Ruins of Lordaeron", the fact line a boss's page carries, a link to the
--- instance's zone page where it has one (zonePage) and to the Boss loot tab at the boss otherwise
--- ("bossentry:<entry>", UI/Frame.lua Frame.OpenSpecial). nil for no place name. Pure.
function InfoPanel.BossOfRow(boss, zonePage)
  local name = type(boss) == "table" and boss.placeName or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local node = nil
  if zonePage and type(boss.areaId) == "number" then
    node = "zone:" .. tostring(boss.areaId)
  elseif type(boss.bossId) == "number" then
    node = "bossentry:" .. tostring(boss.bossId)
  end
  return {
    kind = "fact",
    key = "creaturebossof",
    value = string.format(L["Boss of %s"], name),
    colorKey = COLOR_BODY,
    node = node,
    hint = node and string.format(L["Click to open %s"], name) or nil,
  }
end

--- Brief NP3: a creature page whose creature the Boss loot index files as a boss gains the "Boss
--- of" line in place of the plain "Boss" word and of "Seen in", in its creature block (made after
--- its title and id lines where it has none). An ordinary creature's page is left exactly as it
--- was, "Seen in" and all. The content, changed in place; nil stays nil.
function InfoPanel.WithBossOf(content, root)
  if type(content) ~= "table" or type(content.sections) ~= "table" then
    return content
  end
  local boss = InfoPanel.BossOfFor(root, content)
  if not boss then
    return content
  end
  local row = InfoPanel.BossOfRow(boss, InfoPanel.ZoneHasPage(boss.areaId))
  if not row then
    return content
  end
  content.bossOf = boss
  local home, at = nil, nil
  for index = 1, #content.sections do
    local list = type(content.sections[index].rows) == "table" and content.sections[index].rows or {}
    for position = #list, 1, -1 do
      local key = list[position].key
      if key == "creatureboss" or key == "npcseen" then
        table.remove(list, position)
        home = home or content.sections[index]
        if home == content.sections[index] then
          at = position
        end
      end
    end
  end
  for index = #content.sections, 1, -1 do
    local section = content.sections[index]
    if section ~= home and type(section.rows) == "table" and #section.rows == 0 then
      table.remove(content.sections, index)
    end
  end
  if not home then
    for _, section in ipairs(content.sections) do
      if section.key == CREATURE_SECTION then
        home = section
        at = #section.rows + 1
        break
      end
    end
  end
  if not home then
    local place = 1
    local lead = { npctitle = true, creatureid = true }
    while content.sections[place] and lead[content.sections[place].key] do
      place = place + 1
    end
    home = { key = CREATURE_SECTION, rows = {} }
    table.insert(content.sections, place, home)
    at = 1
  end
  table.insert(home.rows, math.min(at or 1, #home.rows + 1), row)
  return content
end

--------------------------------------------------------------------------------
-- A herb, a vein, a fishing pool or a chest root (brief D7)
--------------------------------------------------------------------------------

-- The section keys the object column's blocks carry.
local OBJECT_SECTION = "object"
local OBJECT_ZONES = "objectzones"

-- The glyph the header wears for each category, which is the glyph the tree's own category of that
-- kind wears (Core/ViewModel.lua GROUP_ICONS), so the page reads as the row it was opened from.
InfoPanel.OBJECT_ASSETS = {
  herb = "CAT_HERBALISM",
  vein = "CAT_MINING",
  fished = "CAT_FISHING",
  object = "CAT_CHEST",
}

-- What the thing IS, in the words a player calls it: "Herb node", "Mining node", "Fishing pool" or
-- "Chest", by the category the shipped table files it under. nil for anything else. Brief SR3: the
-- search dropdown's node rows (UI/Frame.lua Frame.SearchKindWords) say the same locale keys. Pure.
function InfoPanel.ObjectKindWord(category)
  if category == "herb" then
    return L["Herb node"]
  elseif category == "vein" then
    return L["Mining node"]
  elseif category == "fished" then
    return L["Fishing pool"]
  elseif category == "object" then
    return L["Chest"]
  end
  return nil
end

-- What the shipped Classic Era table states about the object one node key names, or nil. Read
-- through the namespace and pcall'd like the creature's, so a load without Core/EraSources.lua
-- costs the column this page and nothing else.
local function eraObjectFacts(key)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.ObjectFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(era.ObjectFacts, era, key)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- The header for an object root: the object's own name and the glyph of its kind. No portrait: an
-- object has no model the column could draw, and the name is the whole of what the table states.
-- Brief Q9b: icon is what the node yields (Core/ViewModel.lua NodeIcon: Truesilver Ore's icon on
-- Truesilver Deposit), drawn over the glyph, and asset the glyph to wear where there is none; both
-- optional, and neither is ever the note. Pure.
function InfoPanel.ObjectHeader(facts, icon, asset)
  local name = type(facts) == "table" and facts.name or nil
  -- Brief EO1: a world object that gives quests and is filed under no category (a wanted poster) is
  -- no node: its own name alone, and the quest glyph the client marks such an object with.
  local giver = type(facts) == "table"
    and facts.category == nil
    and (tonumber(facts.starts) or 0) + (tonumber(facts.ends) or 0) > 0
  if type(name) ~= "string" or name == "" then
    name = InfoPanel.ObjectKindWord(type(facts) == "table" and facts.category or nil) or ""
  elseif not giver then
    -- Brief Q9b: "Black Lotus node", the word in the name's own text and so its own colour, as
    -- the title bar and the breadcrumb read it (UI/Frame.lua).
    name = string.format(L["%s node"], name)
  end
  -- Brief QI2 (the owner's "A" of 2026-10-23): one that only takes quests back (Buzzbox 411) wears the
  -- turn in "?"; one that starts any keeps the "!", whatever it also takes back.
  local questAsset = nil
  if giver then
    questAsset = (tonumber(facts.starts) or 0) > 0 and "CAT_QUEST" or "CAT_QUEST_TURNIN"
  end
  return {
    name = name,
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = {},
    icon = icon,
    asset = questAsset or asset or (type(facts) == "table" and InfoPanel.OBJECT_ASSETS[facts.category] or nil),
  }
end

-- Everything the column says about an object: what it is ("Mining vein") and in how many zones
-- ("5 zones"), the zones one per line, then the two lines every Classic Era fact ends on. With the
-- window's "Show predicted data" tick box off the whole block goes, as a creature's does. Pure.
function InfoPanel.ObjectSections(facts, opts)
  local sections = {}
  if type(facts) ~= "table" or not showingPredicted(opts) then
    return sections
  end
  local rows = {}
  local word = InfoPanel.ObjectKindWord(facts.category)
  if word then
    rows[#rows + 1] = { kind = "fact", key = "objectkind", value = word, colorKey = COLOR_BODY }
  end
  -- Brief EO1: what a world object gives, in the words an NPC's page says it ("Starts 2 quests").
  local given = InfoPanel.QuestGiverLine(facts.starts, facts.ends)
  if given then
    rows[#rows + 1] = { kind = "fact", key = "objectquests", value = given, colorKey = COLOR_BODY }
  end
  local zones = type(facts.zones) == "table" and facts.zones or {}
  if #zones > 0 then
    local count = moduleCall(ItemTree.Sources, "ZoneCount", #zones)
    if type(count) == "string" and count ~= "" then
      rows[#rows + 1] = { kind = "fact", key = "objectzonecount", value = count, colorKey = COLOR_BODY }
    end
  elseif type(facts.inside) == "string" and facts.inside ~= "" then
    -- A node that stands only inside instances: the instance, the way its row's zone column says.
    rows[#rows + 1] = { kind = "fact", key = "objectinside", value = facts.inside, colorKey = COLOR_BODY }
  end

  local places, held = {}, 0
  for _, zone in ipairs(zones) do
    if type(zone) == "table" and type(zone.name) == "string" and zone.name ~= "" then
      if #places < CREATURE_ZONE_ROWS then
        local node, hint = InfoPanel.ZoneLinkOf(zone)
        places[#places + 1] = {
          kind = "fact",
          key = "objectzone" .. tostring(zone.areaId or #places),
          areaId = zone.areaId,
          value = zone.name,
          colorKey = COLOR_BODY,
          node = node,
          hint = hint,
        }
      else
        held = held + 1
      end
    end
  end
  if held > 0 then
    local more = moduleCall(ItemTree.Sources, "MoreText", held)
    if type(more) == "string" and more ~= "" then
      places[#places + 1] = { kind = "fact", key = "objectzonemore", value = more, colorKey = COLOR_MUTED }
    end
  end

  local last = nil
  if #rows > 0 then
    last = { key = OBJECT_SECTION, rows = rows }
    sections[#sections + 1] = last
  end
  if #places > 0 then
    last = { key = OBJECT_ZONES, title = L["Known in"], rows = places }
    sections[#sections + 1] = last
  end
  if not last then
    return sections
  end
  local confidence = ItemTree.Confidence
  local note = confidenceNote(type(confidence) == "table" and confidence.PREDICTED or nil)
  if note then
    last.rows[#last.rows + 1] = { kind = "fact", key = "objectconfidence", value = note, colorKey = COLOR_MUTED }
  end
  last.rows[#last.rows + 1] = {
    kind = "para",
    key = "objectprovenance",
    value = L["From Classic Era. WoW Forever may have changed this."],
    colorKey = COLOR_MUTED,
  }
  return sections
end

-- Brief Q9b: the icon a node page wears, (file, asset), out of Core/ViewModel.lua NodeIcon: the
-- page's own key, no owner, so the yield is the item a gathering node is keyed by or the node's
-- first "gives" edge. nil, nil with no view model loaded.
function InfoPanel.ObjectIcon(key)
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) ~= "table" or type(ViewModel.NodeIcon) ~= "function" then
    return nil, nil
  end
  local ok, file, asset = pcall(ViewModel.NodeIcon, key, nil, nil)
  if not ok then
    return nil, nil
  end
  return file, asset
end

-- Everything the pane says about one object root, or nil for an object key the shipped table files
-- under no object category (a live object the collector saw, a summary row), which falls through to
-- the item column exactly as it did before.
function InfoPanel.ObjectContent(key, showChanges, opts)
  local facts = eraObjectFacts(key)
  if not facts then
    return nil
  end
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  return placeWhere({
    kind = "object",
    nameIndex = facts.nameIndex,
    object = facts,
    showChanges = showChanges and true or false,
    found = true,
    header = InfoPanel.ObjectHeader(facts, InfoPanel.ObjectIcon(key)),
    sections = InfoPanel.ObjectSections(facts, opts),
  }, key, OBJECT_ZONES, opts)
end

--------------------------------------------------------------------------------
-- A zone root (brief Z1)
--------------------------------------------------------------------------------

local ZONE_SECTION = "zone"
local ZONE_COUNTS = "zonecounts"

-- The glyph a zone's header wears: the map for a zone, and the instance glyph for a place this
-- client has no map of. Both are UI/Assets.lua keys.
InfoPanel.ZONE_ASSETS = { zone = "CAT_ZONE", instance = "CAT_INSTANCE" }

-- What the shipped Classic Era table states about the zone one key names, or nil.
local function eraZoneFacts(key)
  local era = ItemTree.eraSources
  if type(era) ~= "table" or type(era.ZoneFacts) ~= "function" then
    return nil
  end
  local ok, facts = pcall(era.ZoneFacts, era, key)
  if not ok or type(facts) ~= "table" then
    return nil
  end
  return facts
end

-- The one word a zone is: "Zone", or "Instance" for a place this client has no map of, which is
-- how the shipped table tells an instance from a zone. Pure.
function InfoPanel.ZoneKindWord(facts)
  if type(facts) == "table" and facts.instance then
    return L["Instance"]
  end
  return L["Zone"]
end

-- The header for a zone root: the zone's own name and the glyph of its kind. No portrait: a zone
-- has no model, and the name is the whole of what the table states. Brief Z4: an instance new in
-- Forever (facts.forever, the Boss loot place's g) wears the New badge, as its place row on the
-- Boss loot tab does; brief Z5: so does an outdoor zone new in Forever (zf). Pure.
function InfoPanel.ZoneHeader(facts)
  local name = type(facts) == "table" and facts.name or nil
  if type(name) ~= "string" or name == "" then
    name = InfoPanel.ZoneKindWord(facts)
  end
  local instance = type(facts) == "table" and facts.instance
  local badges = {}
  if type(facts) == "table" and facts.forever then
    badges[1] = "new"
  end
  return {
    name = name,
    quality = nil,
    colorKey = COLOR_TITLE,
    badges = badges,
    asset = instance and InfoPanel.ZONE_ASSETS.instance or InfoPanel.ZONE_ASSETS.zone,
  }
end

-- Everything the column says about a zone: what it is ("Zone" or "Instance"), then how many rows
-- its Here tab holds of each kind ("Drops from 392"), the items it leaves out, and the two lines
-- every Classic Era fact ends on. counts is the Here tab's own per category answer
-- (Core/ViewModel.lua ViewModel.ZoneCounts), so the column and the tab never disagree. Pure.
function InfoPanel.ZoneSections(facts, counts, locked, opts)
  local sections = {}
  if type(facts) ~= "table" then
    return sections
  end
  local head = {
    key = ZONE_SECTION,
    rows = { { kind = "fact", key = "zonekind", value = InfoPanel.ZoneKindWord(facts), colorKey = COLOR_BODY } },
  }
  sections[#sections + 1] = head
  local rows = {}
  for _, entry in ipairs(type(counts) == "table" and counts or {}) do
    if type(entry) == "table" and type(entry.label) == "string" and tonumber(entry.count) then
      rows[#rows + 1] = {
        kind = "fact",
        key = "zonecount" .. tostring(entry.id or #rows),
        label = entry.label,
        value = tostring(math.floor(tonumber(entry.count))),
        colorKey = COLOR_BODY,
      }
    end
  end
  local last = head
  if #rows > 0 then
    last = { key = ZONE_COUNTS, title = L["Here"], rows = rows }
    sections[#sections + 1] = last
  end
  -- Brief Z4: an instance new in Forever holds nothing out of Classic Era, so it carries none of
  -- the Classic Era lines below. Brief Z5: nor does an outdoor zone new in Forever.
  if not showingPredicted(opts) or facts.forever then
    return sections
  end
  local lockedLine = InfoPanel.LockedLine(locked)
  if lockedLine then
    last = {
      key = "zonelocked",
      rows = { { kind = "fact", key = "zonelocked", value = lockedLine, colorKey = COLOR_MUTED } },
    }
    sections[#sections + 1] = last
  end
  local confidence = ItemTree.Confidence
  local note = confidenceNote(type(confidence) == "table" and confidence.PREDICTED or nil)
  if note then
    last.rows[#last.rows + 1] = { kind = "fact", key = "zoneconfidence", value = note, colorKey = COLOR_MUTED }
  end
  last.rows[#last.rows + 1] = {
    kind = "para",
    key = "zoneprovenance",
    value = L["From Classic Era. WoW Forever may have changed this."],
    colorKey = COLOR_MUTED,
  }
  return sections
end

-- Everything the pane says about one zone root, or nil for a zone key the shipped table names no
-- area for, which falls through to the item column as it always has.
function InfoPanel.ZoneContent(key, showChanges, opts)
  local facts = eraZoneFacts(key)
  if not facts then
    return nil
  end
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  local predicted = showingPredicted(opts)
  -- Brief Z5: facts.forever is the table's own zf answer (Core/EraSources.lua E:ZoneFacts), for
  -- Forever's instances and outdoor zones alike. Brief Z4: a table that ships no zf still asks the
  -- instance's Boss loot place (its g).
  if facts.instance and not facts.forever then
    local place = moduleCall(ItemTree.ViewModel, "InstancePlace", key)
    facts.forever = type(place) == "table" and place.new == true or nil
  end
  local counts = moduleCall(ItemTree.ViewModel, "ZoneCounts", key, { showPredicted = predicted })
  local locked = 0
  local era = ItemTree.eraSources
  if predicted and type(era) == "table" and type(era.ZoneEdges) == "function" then
    local ok, _, held = pcall(era.ZoneEdges, era, key)
    if ok then
      locked = tonumber(held) or 0
    end
  end
  return {
    kind = "zone",
    zone = facts,
    showChanges = showChanges and true or false,
    found = true,
    header = InfoPanel.ZoneHeader(facts),
    sections = InfoPanel.ZoneSections(facts, counts, locked, opts),
  }
end

-- Brief D5: the realm check's line for a withheld item's page, or nil. The check's own answer
-- first; then what the client can already name (the collector's note, from this session or an
-- earlier one); then, for a page drawn from the item's Classic Era row, the plain fact that the
-- realm has not been heard to find it. A stub page with no answer yet says nothing here, because
-- its own sentence already says the item is undiscovered. Pure: every read is a table lookup.
function InfoPanel.RealmLine(itemId, era)
  local check = ItemTree.RealmCheck
  local state = moduleCall(check, "State", itemId)
  local line = moduleCall(check, "Line", state)
  if type(line) == "string" and line ~= "" then
    return line
  end
  local data = ItemTree.Data
  if type(data) == "table" and type(data.ClientNames) == "function" then
    local ok, names = pcall(data.ClientNames, data, itemId)
    if ok and names == true then
      return L["Found on your realm."]
    end
  end
  if era then
    return L["Not yet found on your realm"]
  end
  return nil
end

-- Brief DV1: the one line an item no player can get carries on its page, from Data:HiddenKind's
-- answer: 1 a developer item, 2 one probably never released. nil for anything else.
function InfoPanel.UnobtainableLine(kind)
  if kind == 1 then
    return L["Not obtainable: developer item"]
  elseif kind == 2 then
    return L["Probably never released"]
  end
  return nil
end

-- Data:HiddenKind for one item, read guarded: 1, 2 or nil.
local function unobtainableKind(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.HiddenKind) ~= "function" then
    return nil
  end
  local ok, kind = pcall(data.HiddenKind, data, itemId)
  if ok and (kind == 1 or kind == 2) then
    return kind
  end
  return nil
end

-- Whether the build withholds this item, which is what puts the realm check on its page.
local function withheldItem(itemId)
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.IsUndiscovered) ~= "function" then
    return false
  end
  local ok, answer = pcall(data.IsUndiscovered, data, itemId)
  return ok and answer == true
end

-- Everything the pane says about one item id. Pure: the specs read it directly and the client
-- side below only draws it. showChanges defaults to the window's last word on the tick box.
-- Brief M3: what an item's column adds for Merchant's Favor. An item a shipped vendor sells for
-- Favour gets one line saying where the currency comes from, which opens the Waylaid Crate; a crate
-- gets the Supply Officers it is turned in to, each opening its page, the player's side first.
-- Empty for every other item. Pure over the curated tier and the player's side.
function InfoPanel.FavourSections(itemId)
  local sections = {}
  local favour = favourModule()
  if not favour or type(itemId) ~= "number" then
    return sections
  end
  if moduleCall(favour, "IsOffer", itemId) == true then
    local crate = moduleCall(favour, "CrateItem")
    if type(crate) == "number" and crate ~= itemId then
      sections[#sections + 1] = {
        key = "favour",
        rows = {
          {
            kind = "fact",
            key = "favourcrate",
            label = L["Merchant's Favor comes from Waylaid Crates"],
            labelColorKey = COLOR_LINK,
            colorKey = COLOR_BODY,
            node = "item:" .. crate,
          },
        },
      }
    end
  end
  if moduleCall(favour, "IsCrate", itemId) == true then
    local rows = {}
    local officers = moduleCall(favour, "CrateOfficers", moduleCall(favour, "PlayerFaction")) or {}
    for index, vendor in ipairs(officers) do
      local node = moduleCall(favour, "NodeKey", vendor)
      local name = moduleCall(favour, "DisplayName", vendor)
      if type(node) == "string" and type(name) == "string" then
        rows[#rows + 1] = {
          kind = "fact",
          key = "favourofficer" .. index,
          label = name,
          labelColorKey = COLOR_LINK,
          value = vendor.zone,
          colorKey = COLOR_BODY,
          node = node,
        }
      end
    end
    if #rows > 0 then
      sections[#sections + 1] = { key = "favourturnin", title = L["Turned in to"], rows = rows }
    end
  end
  return sections
end

-- The options the window draws its tree with, asked of UI/Frame.lua as showingPredicted does, so
-- a count made here is the very count the window's tabs were labelled from, out of the same cache.
local function windowOptions()
  local settings = nil
  if type(ItemTree.db) == "table" and type(ItemTree.db.settings) == "table" then
    settings = ItemTree.db.settings
  end
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) == "table" and type(frame.OptionsFromSettings) == "function" then
    local ok, answer = pcall(frame.OptionsFromSettings, settings)
    if ok and type(answer) == "table" then
      return answer
    end
  end
  return { showPredicted = showingPredicted(nil) }
end

--- Brief GS3: puts the guessed sources line straight under the summary line (the "uses" section),
--- or at the end where there is none, for an item whose Sources view holds a guessed row. Asks
--- Core/ViewModel.lua ViewModel.GuessCount, which answers out of the tab counts' own cache, so it
--- adds no walk to a page whose tabs are counted. Answers whether a line was added.
function InfoPanel.AddGuessSection(sections, itemId)
  if type(sections) ~= "table" or type(itemId) ~= "number" then
    return false
  end
  local graph = ItemTree.Graph
  local key = type(graph) == "table" and type(graph.Key) == "function" and graph.Key("item", itemId) or nil
  local count = key and moduleCall(ItemTree.ViewModel, "GuessCount", key, windowOptions()) or 0
  local section = InfoPanel.GuessSection(count)
  if not section then
    return false
  end
  local at = #sections + 1
  for index, held in ipairs(sections) do
    if held.key == "uses" then
      at = index + 1
    end
  end
  table.insert(sections, at, section)
  return true
end

--- Brief M14: the lines an item found in a fixed object in the world carries under its guessed
--- sources line, as a section { key, rows }, or nil for none. spots is what Core/GuessSources.lua
--- R:PlacedSpots answers ({ label, where, map, x, y }, x and y in percent). Each spot is a Where
--- line, "Stonetalon Mountains 74.4, 85.7", carrying the waypoint the Set waypoint button (and a
--- click on the coordinates) sets where the zone has a map, under the object's own line ("Contained
--- in Library Book"), which is said once for spots of the same object. Pure.
function InfoPanel.PlacedSection(spots)
  if type(spots) ~= "table" then
    return nil
  end
  local rows, lastLabel = {}, nil
  for index, spot in ipairs(spots) do
    local where = type(spot) == "table" and spot.where or nil
    if type(where) == "string" and where ~= "" then
      if type(spot.label) == "string" and spot.label ~= lastLabel then
        rows[#rows + 1] =
          { kind = "fact", key = "placed" .. index, value = spot.label, colorKey = InfoPanel.GUESS_COLOR }
        lastLabel = spot.label
      end
      rows[#rows + 1] = {
        kind = "fact",
        key = "placedwhere" .. index,
        label = L["Where"],
        value = where,
        colorKey = COLOR_BODY,
        waypoint = InfoPanel.WaypointOf({ { map = spot.map, x = spot.x, y = spot.y } }),
        -- Brief UX1: the object the spot is, which the waypoint's toast says.
        waypointFor = type(spot.objectName) == "string" and spot.objectName ~= "" and spot.objectName or nil,
        waypointClick = true,
      }
    end
  end
  if #rows == 0 then
    return nil
  end
  return { key = "placed", rows = rows }
end

--- Brief M14: puts InfoPanel.PlacedSection straight under the guessed sources line, for an item
--- whose guesses name a placed object. Asks the addon's own guess reader (Core/GuessSources.lua
--- R:PlacedSpots), one record read by binary search. Answers whether a section was added.
function InfoPanel.AddPlacedSection(sections, itemId)
  if type(sections) ~= "table" or type(itemId) ~= "number" then
    return false
  end
  local reader = ItemTree.guessSources
  if type(reader) ~= "table" or type(reader.PlacedSpots) ~= "function" then
    return false
  end
  local ok, spots = pcall(reader.PlacedSpots, reader, itemId)
  local section = ok and InfoPanel.PlacedSection(spots) or nil
  if not section then
    return false
  end
  local at = #sections + 1
  for index, held in ipairs(sections) do
    if held.key == "guesses" then
      at = index + 1
    end
  end
  table.insert(sections, at, section)
  return true
end

-- Brief K4: the one muted line an item carries while the player has overruled its Keep mark,
-- "Marked Always", "Marked Never" or (brief K5) "Marked Off", so the state reads even where the
-- switch on the caption row is out of sight. nil for auto. Pure.
function InfoPanel.KeepOverrideLine(value)
  if value == "always" then
    return L["Marked Always"]
  elseif value == "never" then
    return L["Marked Never"]
  elseif value == "off" then
    return L["Marked Off"]
  end
  return nil
end

-- The item fact sections the line goes under: the basics, weapon, stats, effects, requires and
-- other blocks, so it sits after the last of them and above the Changed block and the uses line.
local FACT_SECTIONS = { item = true, weapon = true, stats = true, effects = true, requires = true, other = true }

-- Brief K11: the glyph size on the Keep rows, the size the tooltip draws the same glyphs at.
InfoPanel.KEEP_ICON = size("ITEMTREE_BADGE_SIZE_TOOLTIP", 14)

-- Brief K11: the item's Keep verdict as the page's rows, the very lines the tooltip draws
-- (Core/Keep.lua ItemLines and VerdictLines, so the two never disagree): brief K24b, a blank row,
-- the tag row (kind "keepTags", its tints in its own art, plain its words), a blank row, then one
-- row per reason with its glyph at the left, a profession the player lacks in the muted grey with
-- its glyph at full colour. Each reason is a fact row with no label,
-- { kind = "fact", key = "keep", value, colorKey, icon }, value carrying the glyph's escape. The
-- item page draws no "ItemTree" label (brief TB7): the page is ItemTree's own.
-- Empty with Keep marks off or nothing to say. The player's level and side come from
-- UI/Tooltip.lua, the same two reads the tooltip's verdict is scored with. Brief F160 follow up: a
-- bag the character has in one of the bag slots, with no other copy carried in the bags
-- (Keep.EquippedBagAlone), reads [Keep] "Equipped bag" as the bag bar's hover does.
function InfoPanel.KeepRows(itemId)
  local rows = {}
  local db = ItemTree.db
  local settings = type(db) == "table" and type(db.settings) == "table" and db.settings or {}
  if settings.keepMarks == false or type(itemId) ~= "number" then
    return rows
  end
  local level, faction
  local tooltip = ItemTree.Tooltip
  if type(tooltip) == "table" and type(tooltip.PlayerFacts) == "function" then
    local ok, answerLevel, answerFaction = pcall(tooltip.PlayerFacts)
    if ok then
      level, faction = answerLevel, answerFaction
    end
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.ItemLines) ~= "function" then
    return rows
  end
  -- Brief F160 follow up: the equipped bag read, worn with Keep.ItemLines' wornBag where it answers.
  local worn, wornBag = nil, nil
  if type(keep.EquippedBagAlone) == "function" then
    local asked, answer = pcall(keep.EquippedBagAlone, itemId)
    if asked and answer ~= nil then
      worn, wornBag = true, answer
    end
  end
  local ok, lines = pcall(keep.ItemLines, itemId, level, faction, nil, nil, nil, worn, nil, nil, nil, nil, wornBag)
  if not ok or type(lines) ~= "table" then
    return rows
  end
  -- Brief BQ24 (QA item 23): the quest count steps aside for the quest lines naming what it
  -- counts, as on the tooltip.
  if type(tooltip) == "table" and type(tooltip.FoldQuestCountFor) == "function" then
    local folded, out = pcall(tooltip.FoldQuestCountFor, lines, itemId, level, faction)
    if folded and type(out) == "table" then
      lines = out
    end
  end
  -- Brief HF1 (QA item 181): the quest lines the tooltip's more section holds, drawn here in full as
  -- every use that is not the player's is: the quests ahead (QA item 158), another class's and, with
  -- "Hide other faction data" off, the other side's, so the block's quest lines add up to the
  -- "Used in 29 recipes, 6 quests" line above it.
  for _, name in ipairs({ "FoldAheadQuestsFor", "FoldOtherQuestsFor" }) do
    if type(tooltip) == "table" and type(tooltip[name]) == "function" then
      local folded, out = pcall(tooltip[name], lines, itemId, level, faction)
      if folded and type(out) == "table" then
        lines = out
      end
    end
  end
  for _, line in ipairs(lines) do
    if type(line) == "table" and type(line.text) == "string" then
      local value = line.text
      local markup = InfoPanel.IconMarkup(line.icon, InfoPanel.KEEP_ICON)
      if markup ~= "" then
        value = markup .. " " .. value
      end
      -- Brief K24b: the tag row is a row of its own height (InfoPanel.RowHeight("keepTags")), and
      -- the blank spacers around it are rows with no words, half a row high (brief K24k, "keepGap").
      local kind = "fact"
      if line.tags then
        kind = "keepTags"
      elseif line.spacer then
        kind = "keepGap"
        value = " "
      end
      rows[#rows + 1] = {
        kind = kind,
        key = "keep",
        value = value,
        colorKey = line.colorKey or COLOR_BODY,
        icon = line.icon,
        spacer = line.spacer or nil,
        plain = line.plain,
      }
    end
  end
  return rows
end

--- Brief K4: puts the Marked line under the item's facts where Core/Keep.lua holds an override for
--- it, at the end where the item has no facts. Brief K11: the section holds the item's Keep
--- verdict as the tooltip draws it (InfoPanel.KeepRows), and the Marked line only where there is no
--- verdict. Answers whether a line was added.
function InfoPanel.AddKeepSection(sections, itemId)
  if type(sections) ~= "table" or type(itemId) ~= "number" then
    return false
  end
  local rows = InfoPanel.KeepRows(itemId)
  -- The verdict's head already says "(marked by you)", so the Marked line stands in only where
  -- there is no verdict to read: Off, which is silence, or an item with nothing to say.
  local text = nil
  if #rows == 0 then
    text = InfoPanel.KeepOverrideLine(moduleCall(ItemTree.Keep, "Override", itemId))
  end
  if text then
    rows[#rows + 1] = { kind = "fact", key = "keep", value = text, colorKey = COLOR_MUTED }
  end
  if #rows == 0 then
    return false
  end
  local at = #sections + 1
  for index, held in ipairs(sections) do
    if FACT_SECTIONS[held.key] then
      at = index + 1
    end
  end
  table.insert(sections, at, { key = "keep", rows = rows })
  return true
end

function InfoPanel.Content(itemId, showChanges)
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  showChanges = showChanges and true or false
  local content = { itemId = itemId, showChanges = showChanges, sections = {} }

  if type(itemId) ~= "number" then
    content.notice = L["Not in ItemTree data"]
    return content
  end

  local Diff = ItemTree.Diff
  local item = dataItem(itemId)
  if item then
    -- An item this build withholds carries no name of its own, so the client is asked: a realm
    -- that has found the item is exactly what the live layer is for, and what the client
    -- answers is this client's own data rather than anything the addon shipped.
    local facts = nil
    if item.u then
      facts = clientFacts(itemId)
      item = withClientFacts(item, facts)
    end
    local era = item.era == true
    local withheld = withheldItem(itemId)
    local changes = moduleCall(Diff, "GetChanges", "items", itemId) or {}
    -- Brief F155: the other side's quests out of its count while the setting is on.
    local summary = InfoPanel.PageSummary(itemId)
    -- A Classic Era row is Classic Era's facts throughout, so the client's stat amounts are not
    -- laid over it: they would be Forever's numbers under a line saying Classic Era.
    local stats = nil
    if not era then
      stats = clientStats(itemId)
    end
    content.found = true
    content.isNew = moduleCall(Diff, "IsNew", "items", itemId) == true
    content.undiscovered = item.u ~= nil
    content.discovered = facts ~= nil
    content.era = era
    content.header = InfoPanel.Header(item, moduleCall(Diff, "Badges", "items", itemId))
    local found = moduleCall(Diff, "FoundLine", "items", itemId)
    local realm = nil
    if withheld then
      realm = InfoPanel.RealmLine(itemId, era)
    end
    content.sections = InfoPanel.Sections(item, summary, changes, showChanges, {
      stats = stats,
      found = found,
      realm = realm,
      era = era,
      unobtainable = unobtainableKind(itemId),
      setTwin = moduleCall(ItemTree.Graph, "SetTwinText", itemId),
      auction = InfoPanel.AuctionPrice(itemId),
      disenchant = InfoPanel.DisenchantInfo(item),
    })
    InfoPanel.AddKeepSection(content.sections, itemId)
    -- Brief M14: an item found in a fixed object says where it stands, only while its Sources
    -- view holds a guessed row, so the rules that hide a guess hide these lines too.
    if InfoPanel.AddGuessSection(content.sections, itemId) then
      InfoPanel.AddPlacedSection(content.sections, itemId)
    end
    for _, section in ipairs(InfoPanel.FavourSections(itemId)) do
      content.sections[#content.sections + 1] = section
    end
    -- What the pane should ask the client for again once it has loaded the item, and nothing
    -- to ask for once the client has answered. A withheld item's page makes the realm check
    -- instead (Core/RealmCheck.lua), which is the one request it ever sends: the answer names
    -- the item where the realm has found it, and the redraw it triggers reads that.
    content.wantsStats = false
    content.realmCheck = withheld
    if not withheld and stats == nil and type(item.pct) == "table" and #item.pct > 0 then
      content.wantsStats = true
    end
    return content
  end

  -- An id this build withholds that nothing in the compiled data points at, so there is not even
  -- a stub to read a class, a slot and an icon off. The column can still say the one thing that
  -- is true about it, which is worth more than "Not in ItemTree data": that line reads as an id
  -- the addon has never heard of, and this is an item the build is holding back. The title is
  -- the neutral placeholder Core words a nameless withheld item with, until the client answers
  -- with a name of its own.
  local mark = moduleCall(ItemTree.Graph, "ItemDiscoveryMark", itemId)
  if mark == "undiscovered" or mark == "discovered" then
    local facts = clientFacts(itemId)
    content.found = true
    content.undiscovered = true
    content.discovered = facts ~= nil
    content.header = {
      name = (facts and facts.name) or L["Undiscovered item"],
      quality = facts and facts.quality or nil,
      colorKey = Theme.QualityKey(facts and facts.quality or nil),
      badges = {},
    }
    local text = L["Undiscovered in Forever. Its details appear once someone on your realm finds it."]
    if facts then
      text = L["Discovered on your realm. Not yet in ItemTree data."]
    end
    content.sections = {}
    local unobtainable = InfoPanel.UnobtainableLine(unobtainableKind(itemId))
    if unobtainable then
      content.sections[1] = {
        key = "unobtainable",
        rows = { { kind = "fact", key = "unobtainable", value = unobtainable, colorKey = COLOR_MUTED } },
      }
    end
    content.sections[#content.sections + 1] = {
      key = "undiscovered",
      rows = { { kind = "para", key = "undiscovered", value = text, colorKey = COLOR_MUTED } },
    }
    local realm = InfoPanel.RealmLine(itemId, false)
    if realm then
      content.sections[#content.sections + 1] = {
        key = "realm",
        rows = { { kind = "fact", key = "realm", value = realm, colorKey = COLOR_MUTED } },
      }
    end
    -- Nothing else can be said until the client loads it, so the column makes the realm check,
    -- which is the one request, and redraws on its answer.
    content.wantsStats = false
    content.realmCheck = true
    return content
  end

  local summary = moduleCall(Diff, "RemovedSummary", "items", itemId)
  if type(summary) == "table" then
    content.found = true
    content.removed = true
    content.header = InfoPanel.Header(summary, { "removed" })
    local sections = InfoPanel.Sections(summary, nil, nil, showChanges)
    -- Everything above is the baseline's own record, so the column says in words that this is
    -- an item the build dropped rather than leaving the mark beside the name to carry it.
    sections[#sections + 1] = {
      key = "removed",
      rows = { { kind = "fact", key = "removed", value = L["Removed in Forever"], colorKey = COLOR_MUTED } },
    }
    content.sections = sections
    return content
  end

  content.notice = L["Not in ItemTree data"]
  return content
end

-- Everything the pane says about one spell or enchant root. Pure in the same sense Content is:
-- Graph and the client resolvers answer, and the client side below only draws it.
function InfoPanel.SpellContent(id, showChanges, kind)
  if showChanges == nil then
    showChanges = InfoPanel.showChanges
  end
  showChanges = showChanges and true or false
  kind = kind == "enchant" and "enchant" or "spell"
  local content = { spellId = id, kind = kind, showChanges = showChanges, sections = {} }

  local info
  if type(id) == "number" then
    if kind == "enchant" then
      info = enchantInfo(id)
    else
      info = moduleCall(ItemTree.Graph, "SpellInfo", id)
    end
  end
  if type(info) ~= "table" then
    content.notice = L["Not in ItemTree data"]
    return content
  end

  local description = nil
  if kind == "spell" then
    description = spellDescription(id)
  end
  content.found = true
  content.isNew = info.new == true
  content.description = description
  content.wantsDescription = false
  if kind == "spell" and description == nil then
    content.wantsDescription = true
  end
  content.header = InfoPanel.SpellHeader(info)
  content.sections = InfoPanel.SpellSections(info, description, showChanges)
  return content
end

-- The kind and the id behind whatever the window handed the pane: a node key string
-- ("item:2835", "spell:7411"), or a bare item id, which is what the older callers pass.
function InfoPanel.Root(root)
  if type(root) == "number" then
    return "item", root
  end
  local graph = ItemTree.Graph
  if type(root) ~= "string" or not graph or type(graph.Parse) ~= "function" then
    return nil, nil
  end
  local ok, kind, id = pcall(graph.Parse, root)
  if not ok or type(kind) ~= "string" then
    return nil, nil
  end
  return kind, id
end

-- Everything the pane says about the window's root, whichever kind of node it is. The one
-- entry point Show and Refresh both go through.
function InfoPanel.ContentForKey(root, showChanges)
  local kind, id = InfoPanel.Root(root)
  if kind == "spell" or kind == "enchant" then
    return InfoPanel.SpellContent(id, showChanges, kind)
  end
  if kind == "quest" then
    return InfoPanel.QuestContent(id, showChanges)
  end
  -- An npc node the shipped Classic Era table calls a creature (brief E57). Anything else that
  -- happens to be an npc key, a vendor or the world drop, answers nothing here and falls through
  -- to the item column, which is what it has always drawn.
  if kind == "npc" then
    -- Brief C4: either page takes its model from the Creatures data where it ships no display id.
    -- Brief PS5: each of the pages below gains the player module's role lines for the npc.
    -- Brief NP3: and a boss's page the line that names its place (InfoPanel.WithBossOf).
    local creature = InfoPanel.CreatureContent(root, showChanges)
    if creature then
      local made = InfoPanel.WithCreaturesModel(InfoPanel.WithOrigin(creature, root), root)
      return InfoPanel.WithBossOf(InfoPanel.WithPlayerRoles(made, root), root)
    end
    -- Brief N2: a vendor, or an NPC the player's own records hold.
    local npc = InfoPanel.NpcContent(root, showChanges)
    if npc then
      local made = InfoPanel.WithCreaturesModel(InfoPanel.WithOrigin(npc, root), root)
      return InfoPanel.WithBossOf(InfoPanel.WithPlayerRoles(made, root), root)
    end
    -- Brief C4: a creature the Creatures data knows, with the player's own sighting (brief T8) for
    -- the level and the zone. Then brief T8: a creature only the player's own sighting knows,
    -- opened with Ctrl + right click.
    local lookup = ItemTree.CreatureLookup
    local npcId = moduleCall(lookup, "IdOfKey", root)
    local seen = moduleCall(lookup, "Sighting", npcId)
    local known = InfoPanel.CreaturesContent(InfoPanel.CreaturesRowFor(root), seen, showChanges)
    if known then
      return InfoPanel.WithBossOf(InfoPanel.WithPlayerRoles(InfoPanel.WithOrigin(known, root), root), root)
    end
    local sighting = InfoPanel.SightingContent(seen, showChanges)
    if sighting then
      return InfoPanel.WithBossOf(InfoPanel.WithOrigin(sighting, root), root)
    end
  end
  -- Brief D7: a herb, a vein, a fishing pool or a chest the shipped table files under one of its
  -- object categories. Any other object key falls through, as it always has.
  if kind == "object" then
    local object = InfoPanel.ObjectContent(root, showChanges)
    if object then
      return object
    end
  end
  -- Brief Z1: a zone or an instance the shipped table names.
  if kind == "zone" then
    local zone = InfoPanel.ZoneContent(root, showChanges)
    if zone then
      return zone
    end
  end
  return InfoPanel.Content(kind == "item" and id or nil, showChanges)
end

-- One fact as the client would write it in a tooltip, or nil for a fact a tooltip does not
-- repeat. A pair the client draws left and right (sell price, durability, a set name) keeps
-- its label and comes back with the value in `right`; everything else is one sentence.
--
-- Brief TV4 (the owner's design 6, Thorium Shells, item 347): the numbers are pairs too, a label
-- on the left and its value on the right in the muted grey, "Max stack 500", "Damage 17 - 18",
-- "Speed 3.00", "Damage per second 5.8", "Buy price (x 100) 40s"; the level lines read "Item level
-- 57" and "Requires level 52". item is the record the row was read from.
local function tooltipLine(sectionKey, row, item)
  local value = row.value
  if not row.label then
    return { text = value, colorKey = row.colorKey or COLOR_BODY, color = row.color }
  end
  if sectionKey == "stats" then
    return { text = value .. " " .. row.label, colorKey = COLOR_BODY }
  end
  if sectionKey == "effects" then
    return { text = row.label .. ": " .. value, colorKey = COLOR_BODY }
  end
  if sectionKey == "weapon" and row.key == "damage" then
    local damage = type(item) == "table" and type(item.dmg) == "table" and item.dmg or nil
    local low, high = damage and tonumber(damage[1]) or nil, damage and tonumber(damage[2]) or nil
    if low and high then
      value = string.format(L["%s - %s"], numberText(low), numberText(high))
    end
  end
  if sectionKey == "requires" then
    if row.key == "classes" then
      return { text = string.format(L["Classes: %s"], value), colorKey = COLOR_BODY }
    end
    return { text = string.format(L["Requires %s"], value), colorKey = COLOR_BODY }
  end
  if row.key == "binds" then
    -- The binding is the line under the item name, and it is already written there.
    return nil
  end
  if row.key == "type" or row.key == "subtype" or row.key == "slot" then
    return { text = value, colorKey = COLOR_BODY }
  end
  if row.key == "ilvl" then
    return { text = string.format(L["Item level %s"], value), colorKey = COLOR_BODY }
  end
  if row.key == "stack" then
    if value == "1" then
      return nil
    end
    return { text = L["Max stack"], right = value, colorKey = COLOR_BODY, rightColorKey = COLOR_MUTED }
  end
  if row.key == "unique" then
    return { text = string.format(L["Unique (%s)"], value), colorKey = COLOR_BODY }
  end
  if row.key == "reqlevel" then
    return { text = string.format(L["Requires level %s"], value), colorKey = COLOR_BODY }
  end
  local label = row.label
  if row.key == "buy" then
    -- Brief PS1 bundle prices: the money alone on the right, how many it buys in the label.
    local count = moduleCall(ItemTree.Sources, "BundleCount", item)
    local money = type(item) == "table" and InfoPanel.FieldText("sell_price", positive(item.bp)) or nil
    if tonumber(count) and money then
      label, value = string.format(L["Buy price (x %s)"], tostring(count)), money
    end
  end
  return { text = label, right = value, colorKey = COLOR_BODY, rightColorKey = COLOR_MUTED }
end

-- The same facts as client tooltip lines, for a row hovered inside the window. Pure, and the
-- caller draws the item name itself, so this is the block under it. Array of
-- { text, colorKey, right, rightColorKey }; empty for an item ItemTree has no record of.
--
-- Brief TV4 (the owner's design 6): three parts with a blank line ({ text = " ", gap = true })
-- between them: what the item is ("Projectile" with "Bullet" on the right, its levels), its
-- numbers and prices, then its uses, the quests counted as "Quests 1" and any other use in the
-- uses line's own words. A slot that only repeats the class ("Ammo" under "Projectile") is not
-- drawn. Capped at TOOLTIP_LIMIT lines of words.
function InfoPanel.TooltipLines(itemId)
  local lines = {}
  local item = type(itemId) == "number" and dataItem(itemId) or nil
  if type(item) ~= "table" then
    return lines
  end
  local notes, identity, numbers, uses = {}, {}, {}, {}

  local bonding = BONDING_LINES[positive(item.b) or 0]
  if bonding then
    identity[#identity + 1] = { text = L[bonding], colorKey = COLOR_BODY }
  end

  -- Brief F155: the other side's quests out of its count while the setting is on.
  local summary = InfoPanel.PageSummary(itemId)
  -- The budget block is left out: a share of a stat budget is a fact about the build, and a
  -- tooltip is the client's own voice, which never says such a thing.
  for _, section in ipairs(InfoPanel.Sections(item, summary, nil, false)) do
    if section.key == "item" then
      local byKey = {}
      for _, row in ipairs(section.rows) do
        byKey[row.key] = row
      end
      local kind, sub = byKey.type and byKey.type.value, byKey.subtype and byKey.subtype.value
      if kind and sub and sub ~= kind then
        identity[#identity + 1] = { text = kind, right = sub, colorKey = COLOR_BODY, rightColorKey = COLOR_BODY }
      elseif kind or sub then
        identity[#identity + 1] = { text = kind or sub, colorKey = COLOR_BODY }
      end
      -- Brief TV4: ammo's slot says what its class already does.
      if byKey.slot and byKey.slot.value ~= sub and item.c ~= InfoPanel.PROJECTILE_CLASS then
        identity[#identity + 1] = tooltipLine(section.key, byKey.slot, item)
      end
      for _, key in ipairs({ "ilvl", "reqlevel", "unique" }) do
        if byKey[key] then
          identity[#identity + 1] = tooltipLine(section.key, byKey[key], item)
        end
      end
      if byKey.stack then
        numbers[#numbers + 1] = tooltipLine(section.key, byKey.stack, item)
      end
    elseif section.key == "uses" then
      local quests = type(summary) == "table" and tonumber(summary.quests) or 0
      if quests > 0 then
        uses[#uses + 1] =
          { text = L["Quests"], right = tostring(quests), colorKey = COLOR_BODY, rightColorKey = COLOR_MUTED }
        local others = {}
        for key, value in pairs(summary) do
          others[key] = value
        end
        -- The quests are the pair above, and what makes it is the row's own Source line.
        others.quests, others.questArt, others.questsOthers, others.producedBy = 0, nil, nil, 0
        local text, colorKey = usesText(others)
        if colorKey ~= COLOR_MUTED then
          uses[#uses + 1] = { text = text, colorKey = colorKey }
        end
      else
        for _, row in ipairs(section.rows) do
          uses[#uses + 1] = tooltipLine(section.key, row, item)
        end
      end
    elseif section.key ~= "changed" and not section.budget then
      local into = numbers
      if InfoPanel.TOOLTIP_NOTES[section.key] then
        into = notes
      end
      for _, row in ipairs(section.rows) do
        local line = tooltipLine(section.key, row, item)
        if line then
          into[#into + 1] = line
        end
      end
    end
  end

  local words = 0
  for _, part in ipairs({ notes, identity, numbers, uses }) do
    if #part > 0 and words < TOOLTIP_LIMIT then
      if #lines > 0 then
        lines[#lines + 1] = { text = " ", gap = true, colorKey = COLOR_BODY }
      end
      for _, line in ipairs(part) do
        if words >= TOOLTIP_LIMIT then
          break
        end
        words = words + 1
        lines[#lines + 1] = line
      end
    end
  end
  return lines
end

-- Brief TV4: the item class of ammunition (the client's Projectile), whose slot line goes.
InfoPanel.PROJECTILE_CLASS = 6

-- Brief TV4: the sections whose one line says what the item's state is (undiscovered, found, a
-- Classic Era row), drawn first in the hover, as on the page.
InfoPanel.TOOLTIP_NOTES =
  { unobtainable = true, undiscovered = true, discovered = true, found = true, realm = true, era = true }

--- The corner mark the column's header icon wears, as the word it is decided by, and what that
--- mark says in words. Both rules are Core's (Core/Graph.lua Graph.DiscoveryMark and
--- Graph.DiscoveryMarkText), because the tree row, the Discoveries row, the chain stage and this
--- header have to agree about what a mark means and say it in the same words. The content
--- already states the two facts the rule is decided from. Pure.
function InfoPanel.MarkWord(content)
  local word = moduleCall(ItemTree.Graph, "DiscoveryMark", content)
  if type(word) ~= "string" then
    return nil
  end
  return word
end

function InfoPanel.MarkText(content)
  local text = moduleCall(ItemTree.Graph, "DiscoveryMarkText", InfoPanel.MarkWord(content))
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

-- The column's own frame (brief E78). The owner asked for the column to stand out from the panes
-- to its right: a chunkier, bevelled gold border in the client's own art, the kind its bags and
-- dialogs wear, over a lighter and warmer fill.
--
-- The border is the client's "Dialog" nine slice layout (Blizzard_SharedXML/Mainline/
-- NineSliceLayouts.lua, the Dialog entry at line 157 on the wow-ui-source forever branch), whose
-- UI-Frame-DiamondMetal pieces this client draws from the gold Camelot sheets. It is chosen over
-- the bags' own HeldBagLayout (line 361 of the same file, named by ContainerFrameTemplate in
-- Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml line 233) because the bag's corners carry the
-- window's portrait ring and title band, which a column has no room for; the Dialog pieces are the
-- same gold family with a plain bevelled rail and a stud at each corner.
InfoPanel.FRAME_LAYOUT = "Dialog"

-- Where the rail sits in the Dialog art, in the art's own pixels at scale 1: every piece is 64 by
-- 64 (128 texels at 2x), the rail runs from 12 to 21 in from the piece's outer edge, and the
-- corner stud reaches out to about 5. Measured off the c60 sheets on 1.60.1.70009.
InfoPanel.FRAME_ART = { piece = 64, railOuter = 12, railInner = 21 }

-- The Assets keys the hand placed fallback draws, by the piece name NineSliceUtil gives each.
InfoPanel.FRAME_PIECES = {
  { name = "TopLeftCorner", key = "INFO_FRAME_CORNER_TL", point = "TOPLEFT" },
  { name = "TopRightCorner", key = "INFO_FRAME_CORNER_TR", point = "TOPRIGHT" },
  { name = "BottomLeftCorner", key = "INFO_FRAME_CORNER_BL", point = "BOTTOMLEFT" },
  { name = "BottomRightCorner", key = "INFO_FRAME_CORNER_BR", point = "BOTTOMRIGHT" },
  { name = "TopEdge", key = "INFO_FRAME_EDGE_TOP", from = "TopLeftCorner", to = "TopRightCorner", tile = "horiz" },
  {
    name = "BottomEdge",
    key = "INFO_FRAME_EDGE_BOTTOM",
    from = "BottomLeftCorner",
    to = "BottomRightCorner",
    tile = "horiz",
  },
  { name = "LeftEdge", key = "INFO_FRAME_EDGE_LEFT", from = "TopLeftCorner", to = "BottomLeftCorner", tile = "vert" },
  {
    name = "RightEdge",
    key = "INFO_FRAME_EDGE_RIGHT",
    from = "TopRightCorner",
    to = "BottomRightCorner",
    tile = "vert",
  },
}

--- The frame's geometry in the column's own pixels, from the scale the art is drawn at and how far
--- it hangs outside the column. railOuter and railInner are where the gold rail lands in from the
--- column's edge; the fill stops halfway across the rail so nothing of it shows outside; the
--- scrollbar thumb sits gap inside the rail (brief E83, 1 when not given); the content is inset by
--- pad, or further if the thumb would otherwise touch it, and on the right by textGap past the
--- thumb's inner edge, whether or not the thumb shows, so lines never reflow when it appears. Pure.
function InfoPanel.FrameGeometry(scale, outset, pad, thumbW, gap, textGap)
  scale = tonumber(scale) or 1
  if scale <= 0 then
    scale = 1
  end
  outset = math.max(0, tonumber(outset) or 0)
  pad = math.max(0, tonumber(pad) or 0)
  thumbW = math.max(0, tonumber(thumbW) or 0)
  gap = math.max(0, tonumber(gap) or 1)
  textGap = math.max(0, tonumber(textGap) or 1)
  local art = InfoPanel.FRAME_ART
  local railOuter = art.railOuter * scale - outset
  local railInner = art.railInner * scale - outset
  local thumbInset = math.max(1, railInner + gap)
  local contentInset = math.max(pad, math.ceil(thumbInset + thumbW) + 1)
  return {
    scale = scale,
    outset = outset,
    railOuter = railOuter,
    railInner = railInner,
    fillInset = math.max(0, math.floor((railOuter + railInner) / 2)),
    gap = gap,
    thumbInset = thumbInset,
    contentInset = contentInset,
    contentRight = math.max(contentInset, math.ceil(thumbInset + thumbW + textGap)),
  }
end

--- Where the thumb's right edge sits in from the column's edge once one screen pixel is known:
--- never nearer the rail than that pixel, so the thumb stays clear of the border art however
--- small the gap token is. unitsPerPixel is one screen pixel in the column's units; nil or
--- nonsense keeps the geometry's own inset. Pure.
function InfoPanel.ThumbInset(geometry, unitsPerPixel)
  local inset = tonumber(geometry and geometry.thumbInset) or 1
  local pixel = tonumber(unitsPerPixel)
  local rail = tonumber(geometry and geometry.railInner)
  if not pixel or pixel <= 0 or pixel ~= pixel or pixel == math.huge or not rail then
    return inset
  end
  return math.max(inset, rail + pixel)
end

-- The fill candidates, lightest first, and what each has to keep readable over it: the body text
-- and the "Used in N recipes" gold at 4.5:1, the muted labels and every quality coloured name at
-- 3:1. The wash is drawn over the inset surface, so the contrast is measured on the two together.
InfoPanel.FILL_BASE = COLOR_INSET
InfoPanel.FILL_CANDIDATES = {
  "ITEMTREE_COLOR_INFO_FILL_ALT",
  "ITEMTREE_COLOR_INFO_FILL",
  "ITEMTREE_COLOR_INFO_FILL_SOFT",
}
InfoPanel.FILL_CHECKS = {
  { key = COLOR_BODY, min = 4.5 },
  { key = COLOR_TITLE, min = 4.5 },
  { key = COLOR_MUTED, min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_POOR", min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_COMMON", min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_UNCOMMON", min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_RARE", min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_EPIC", min = 3 },
  { key = "ITEMTREE_COLOR_QUALITY_LEGENDARY", min = 3 },
}

--- The contrast of every checked text colour against one fill drawn over the inset surface:
--- { [textKey] = ratio }, and whether all of them clear their minimum. nil where Theme cannot say.
--- Pure.
function InfoPanel.FillContrast(fillKey)
  if not (Theme and type(Theme.ColorTable) == "function" and type(Theme.Contrast) == "function") then
    return nil
  end
  local fill, base = Theme.ColorTable(fillKey), Theme.ColorTable(InfoPanel.FILL_BASE)
  if not (fill and base) then
    return nil
  end
  local surface = Theme.Blend(fill, base)
  local ratios, passes = {}, true
  for _, check in ipairs(InfoPanel.FILL_CHECKS) do
    local text = Theme.ColorTable(check.key)
    if text then
      local ratio = Theme.Contrast(text, surface)
      ratios[check.key] = ratio
      if ratio < check.min then
        passes = false
      end
    end
  end
  return ratios, passes
end

--- The fill the column wears: the lightest candidate that keeps every checked colour readable, or
--- nil where none does (the column then keeps the plain inset surface). Pure.
function InfoPanel.ChooseFill()
  for _, key in ipairs(InfoPanel.FILL_CANDIDATES) do
    local ratios, passes = InfoPanel.FillContrast(key)
    if ratios and passes then
      return key
    end
  end
  return nil
end

--- The pixels a supplied medallion stands proud of its badge frame on each side: the art is drawn
--- a step up the size ladder (Badges.ArtSize), 16 on the header's 14 badge, so one pixel. The
--- header cluster is inset by it so the medallion is not cut at the scroll frame's top and
--- right edges (brief E82). Pure.
function InfoPanel.BadgeOverhang(badgeSize)
  local wanted = tonumber(badgeSize) or Theme.sizes.ITEMTREE_BADGE_SIZE_TOOLTIP or 14
  local art = wanted
  local Badges = ItemTree.Badges
  if type(Badges) == "table" and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, wanted)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - wanted) / 2))
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

local PAD = size("ITEMTREE_PAD_FRAME", 12)
-- The root's own art is the primary item of the window, so it has a token of its own rather
-- than borrowing a bag slot's: the owner read the old header as "too small". See the note at
-- the top for why the design's 48 is not the number.
local ICON = size("ITEMTREE_ICON_HEADER", 40)
local BADGE = size("ITEMTREE_BADGE_SIZE_TOOLTIP", 14)
-- The corner mark on the header icon, sized by the rule every other surface sizes it by: never
-- more than the badge token and never more than half the icon it sits in.
local MARK = math.max(1, math.min(size("ITEMTREE_ICON_BADGE", 14), math.floor(ICON / 2)))
-- E44: the slop around the glyph the mark's own hover target takes, the same couple of pixels a
-- tree row gives it (UI/Tree.lua Tree.MARK_HIT_SLOP).
local MARK_HIT_SLOP = 2
-- The last resort only: every draw reads the region's real width first, because the window has
-- widened this column once already and will again.
local COLUMN = size("ITEMTREE_LIST_COL_INFO", 225)

-- The template a font string is born with, and the client font objects to fall back on. A font
-- string made with the two argument CreateFontString has no font at all, and the next SetText
-- raises inside the client, so one of these is on every font string before a word is written.
InfoPanel.FONT_TEMPLATE = "GameFontNormalSmall"
InfoPanel.FONT_FALLBACKS = {
  "GameFontHighlightSmall",
  "GameFontNormalSmall",
  "GameFontHighlight",
  "GameFontNormal",
}

-- The name wraps to two lines beside the icon before it truncates, so the header block is as
-- tall as two lines of it whether or not this name needs them.
local HEADER_H = math.max(ICON, (FONT_MD + 2) * 2)
local SCROLL_STEP = ROW_HEIGHTS.fact * 3
local THUMB_W = HAIRLINE * 2
-- The column's frame, worked out once from the Theme tokens (see InfoPanel.FrameGeometry).
local FRAME = InfoPanel.FrameGeometry(
  size("ITEMTREE_INFO_FRAME_SCALE", 0.6),
  size("ITEMTREE_INFO_FRAME_OUTSET", 5),
  PAD,
  THUMB_W,
  size("ITEMTREE_INFO_SCROLL_GAP", 0.35),
  size("ITEMTREE_INFO_TEXT_TO_SCROLL", 8)
)
-- How far in the scrolling content sits from the column's top, left and bottom edges, and from
-- its right edge, which leaves the thumb its lane and the room past it (brief E83).
local INSET = FRAME.contentInset
local INSET_RIGHT = FRAME.contentRight

-- How far the link gold is lifted towards white while the pointer is on it. Enough to read as
-- a state change at the scale the owner runs the window at, and not so far the word goes pale.
local LINK_HOVER = 0.35

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes. Looked up at call time, because a spec loads this
-- file on its own and a build without the module must cost the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

-- One CreateFrame call, pcall'd, the same idiom as UI/Report.lua: a client that does not carry
-- the template still gets its frame without the art, and a client with no CreateFrame at all
-- gets nothing, which is what leaves Attach returning false under busted.
local function newFrame(kind, name, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  if template then
    local ok, frame = pcall(create, kind, name, parent, template)
    if ok and frame then
      return frame
    end
  end
  local ok, frame = pcall(create, kind, name, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- E44: puts one frame a level over another, so the pointer lands on it rather than on the frame
-- it covers. Guarded end to end: a client that will not say what level a frame is on leaves both
-- where they are, and the pane loses a hover and nothing else.
local function raiseOver(frame, other)
  if type(frame) ~= "table" or type(frame.SetFrameLevel) ~= "function" then
    return false
  end
  local level = nil
  if type(other) == "table" and type(other.GetFrameLevel) == "function" then
    local ok, value = pcall(other.GetFrameLevel, other)
    if ok then
      level = tonumber(value)
    end
  end
  if not level then
    return false
  end
  return (pcall(frame.SetFrameLevel, frame, level + 1))
end

-- Whether a script may be put on a frame. The beta and Classic Era carry different script
-- handlers on the same frame types, so HasScript is asked where the client answers it; a
-- client that will not say reads as yes, because SetScript on a handler it does not know is
-- what raises, and that is pcall'd at every call site anyway.
local function canScript(frame, script)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) ~= "function" then
    return true
  end
  local ok, has = pcall(frame.HasScript, frame, script)
  if not ok or has == nil then
    return true
  end
  return has and true or false
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves
-- the client's own colour alone. Same idiom as UI/Tooltip.lua and UI/Report.lua.
local function themeColor(key)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  if not color then
    return nil
  end
  return color.r, color.g, color.b, color.a
end

local function colourText(fontString, key)
  local r, g, b, a = themeColor(key)
  if r and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(r, g, b, a or 1)
  end
end

local function assetEntry(key)
  if not (Assets and type(Assets.Has) == "function" and Assets.Has(key)) then
    return nil
  end
  local ok, entry = pcall(Assets.Get, key)
  if ok and type(entry) == "table" then
    return entry
  end
  return nil
end

-- The art the rarity frame over the header icon is drawn with, best first, and how each one
-- sits over the icon.
--
-- The client's own item button (ItemButtonTemplate in Blizzard_ItemButton/Classic, identical on
-- the classic_era and classic_beta branches of the wow-ui-source mirror) carries an IconBorder
-- region on the OVERLAY layer holding Interface\Common\WhiteIconFrame at exactly the icon's
-- rect, and SetItemButtonQuality tints it with the quality colour. That art is ICON_FRAME_WHITE
-- and it is drawn at the icon's own rect, which is why nothing is ever drawn behind the icon: a
-- square edge 1px out from art with rounded corners is the green glow the owner saw poking out
-- of Arcane Crystal's corners.
--
-- The template itself is not used, because on both target clients SetItemButtonQuality ends in
-- button.IconBorder:Hide() with the colouring commented out: Classic never colours an item
-- button's frame, so the native route draws no rarity at all. The art is the part worth taking.
--
-- UI/Assets.lua belongs to another file this round, so a table with no ICON_FRAME_WHITE in it
-- falls back to the action button's border, which is what older client code ringed a quality
-- with: a square glow with a clear middle, blended additively, hence the blend mode. It is
-- drawn at the icon's rect like the first one rather than oversized around it, because the
-- header sits inside a scroll frame that would clip anything hanging over its top edge and
-- leave the glow lopsided. Neither key present draws no frame at all, which is the one thing
-- that is never worse than the fault it replaces.
local ICON_FRAME_ART = {
  { key = "ICON_FRAME_WHITE" },
  { key = "ACTION_BORDER", blend = "ADD" },
}

-- Puts the best rarity frame art the client's Assets table carries on a texture, and answers
-- the entry that went on it so the caller knows how to place it. nil where none of it is there.
local function applyIconFrame(texture)
  local assets = ItemTree.Assets
  if type(texture) ~= "table" or type(assets) ~= "table" or type(assets.Apply) ~= "function" then
    return nil
  end
  for _, art in ipairs(ICON_FRAME_ART) do
    local has = true
    if type(assets.Has) == "function" then
      local asked, answer = pcall(assets.Has, art.key)
      has = asked and answer == true
    end
    if has then
      local ok, applied = pcall(assets.Apply, texture, art.key)
      if ok and applied ~= false then
        return art
      end
    end
  end
  return nil
end

-- A flat fill. SetColorTexture is the modern call; a client without it paints the white 8x8.
local function fillTexture(texture, key)
  local r, g, b, a = themeColor(key)
  if not r then
    return false
  end
  if type(texture.SetColorTexture) == "function" then
    texture:SetColorTexture(r, g, b, a or 1)
    return true
  end
  local entry = assetEntry("FILL_WHITE8X8")
  if entry and type(texture.SetTexture) == "function" then
    texture:SetTexture(entry.path)
    texture:SetVertexColor(r, g, b, a or 1)
    return true
  end
  return false
end

-- The last resort edge: four hairlines in the Theme border colour, which is what the column wore
-- before brief E78 and what a client with neither NineSliceUtil nor the Dialog atlases still gets.
--
-- The design's INPUT_BORDER asset is the client's edit box strip (a left cap, a tiling middle
-- and a right cap in one file), not a nine slice: handing it to NineSliceUtil, or to
-- SetBackdrop as an edgeFile at slice 8, cuts the caps into every corner and draws the dotted
-- edge the column had in game on both Classic Era and the Forever beta.
local function applyInsetBorder(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local texture = frame:CreateTexture(nil, "BORDER")
    if not texture then
      return nil
    end
    fillTexture(texture, COLOR_DIVIDER)
    if side == "TOP" or side == "BOTTOM" then
      texture:SetHeight(HAIRLINE)
      texture:SetPoint(side .. "LEFT", frame, side .. "LEFT", 0, 0)
      texture:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", 0, 0)
    else
      texture:SetWidth(HAIRLINE)
      texture:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0)
      texture:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0)
    end
    edges[#edges + 1] = texture
  end
  frame.edges = edges
  return "hairline"
end

-- The Dialog pieces placed by hand from Assets keys, the way NineSliceUtil places them: a corner
-- at each corner at the art's own size, each edge stretched between its two corners and tiled
-- along its length. True only if all eight pieces took their art.
local function placeFramePieces(art)
  if not (Assets and type(Assets.Apply) == "function") or type(art.CreateTexture) ~= "function" then
    return false
  end
  local piece = InfoPanel.FRAME_ART.piece
  local placed = {}
  for _, spec in ipairs(InfoPanel.FRAME_PIECES) do
    local texture = art:CreateTexture(nil, "BORDER")
    local drawn = texture ~= nil and (type(Assets.Has) ~= "function" or Assets.Has(spec.key) == true)
    if drawn then
      local ok, applied = pcall(Assets.Apply, texture, spec.key)
      drawn = ok and applied ~= false
    end
    if not drawn then
      for _, done in pairs(placed) do
        done:Hide()
      end
      if texture then
        texture:Hide()
      end
      return false
    end
    if spec.point then
      texture:SetSize(piece, piece)
      texture:SetPoint(spec.point, art, spec.point, 0, 0)
    elseif spec.tile == "horiz" then
      texture:SetHeight(piece)
      texture:SetPoint("TOPLEFT", placed[spec.from], "TOPRIGHT", 0, 0)
      texture:SetPoint("BOTTOMRIGHT", placed[spec.to], "BOTTOMLEFT", 0, 0)
      if type(texture.SetHorizTile) == "function" then
        pcall(texture.SetHorizTile, texture, true)
      end
    else
      texture:SetWidth(piece)
      texture:SetPoint("TOPLEFT", placed[spec.from], "BOTTOMLEFT", 0, 0)
      texture:SetPoint("BOTTOMRIGHT", placed[spec.to], "TOPRIGHT", 0, 0)
      if type(texture.SetVertTile) == "function" then
        pcall(texture.SetVertTile, texture, true)
      end
    end
    placed[spec.name] = texture
    art[spec.name] = texture
  end
  return true
end

-- The column's bevelled gold frame (brief E78), drawn on a frame of its own so it can be scaled:
-- the Dialog art at full size is a rail 9px thick 12px in from the edge, too grand for a 180px
-- column, so the frame is drawn at ITEMTREE_INFO_FRAME_SCALE and hung ITEMTREE_INFO_FRAME_OUTSET
-- outside the column, which lands the rail a couple of pixels in from the column's edge. Offsets
-- on a scaled frame are in its own units, hence the divide.
--
-- The client's own layout by name first, the way UI/Frame.lua asks for its window border; the
-- eight Assets keys by hand where NineSliceUtil is missing or refuses; the old hairlines where
-- neither draws. Answers which one went on, and the art frame where there is one.
local function applyColumnFrame(frame)
  local art = newFrame("Frame", nil, frame)
  if art then
    if type(art.SetScale) == "function" then
      pcall(art.SetScale, art, FRAME.scale)
    end
    local offset = FRAME.outset / FRAME.scale
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    if type(art.EnableMouse) == "function" then
      pcall(art.EnableMouse, art, false)
    end
    frame.art = art
    local util = rawget(_G, "NineSliceUtil")
    if type(util) == "table" and type(util.ApplyLayoutByName) == "function" then
      local ok = pcall(util.ApplyLayoutByName, art, InfoPanel.FRAME_LAYOUT)
      if ok and art.TopLeftCorner ~= nil then
        return "nineslice", art
      end
    end
    if placeFramePieces(art) then
      return "atlas", art
    end
    art:Hide()
    frame.art = nil
  end
  return applyInsetBorder(frame), nil
end

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(InfoPanel.FONT_FALLBACKS) do
    local object = rawget(_G, name)
    if object ~= nil then
      local ok, applied = pcall(fontString.SetFontObject, fontString, object)
      if ok and applied ~= false then
        return true
      end
    end
  end
  return false
end

-- Whether the client says this font string has a font. One that cannot be asked reads as
-- having none, so a font object is put on it anyway: setting one twice costs nothing.
local function hasFont(fontString)
  if type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
    return false
  end
  local ok, face = pcall(fontString.GetFont, fontString)
  if not ok then
    return false
  end
  return face ~= nil and face ~= ""
end

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString)
end

-- A font string in the design's body face at the size the token names, with the 1px shadow
-- every font string in the window carries. The template is asked for at creation, so a SetText
-- is never the first thing to touch the font; SetFont answers false rather than raising where
-- the client cannot load the face, so the answer is read and a font object put back.
local function newFontString(parent, points, colorKey, justify, wrap)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", InfoPanel.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY or nil
  if face and type(fontString.SetFont) == "function" then
    local applied, answer = pcall(fontString.SetFont, fontString, face, points, "")
    if not applied or answer == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local shadow = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if shadow and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(shadow.x, shadow.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(shadow.r, shadow.g, shadow.b, shadow.a)
    end
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(wrap and true or false)
  end
  -- A font string created in code is centred until it is told otherwise, and this column is
  -- labels on the left against numbers on the right.
  if justify and type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify)
  end
  -- Every part of a row is given a box a line high and the text centred in it, so the middle of
  -- the box is the middle of the words. The strike through is a hairline anchored to the middle
  -- of the old value's box, and at the scale the owner runs the window at a font string left on
  -- the client's default would put that line wherever the default happened to be.
  if type(fontString.SetJustifyV) == "function" then
    fontString:SetJustifyV("MIDDLE")
  end
  colourText(fontString, colorKey)
  return fontString
end

-- A measurement the client has, or 0. Every size read is guarded the same way, so the layout
-- falls back to the design's own numbers rather than raising where a frame cannot say.
local function measure(object, getter)
  if not object or type(object[getter]) ~= "function" then
    return 0
  end
  local ok, value = pcall(object[getter], object)
  return (ok and tonumber(value)) or 0
end

-- Brief BL8: every function that draws takes the surface it draws on. The window's own column is
-- InfoPanel itself (its frame, rows, model block and scroll state live on the module, as they always
-- have), and InfoPanel.NewSurface makes another one inside any region, which is how the Boss loot
-- tab draws a creature's column beside its loot. surface is optional everywhere and means the
-- window's column when left out, so the window's own calls read exactly as they did.
local function surfaceOf(surface)
  if type(surface) == "table" then
    return surface
  end
  return InfoPanel
end

local function paneWidth(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local width = measure(frame, "GetWidth")
  if width <= 0 then
    width = measure(surface.region, "GetWidth")
  end
  if width <= 0 then
    width = COLUMN
  end
  return width - INSET - INSET_RIGHT
end

local function paneHeight(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local height = measure(frame and frame.scroll, "GetHeight")
  if height > 0 then
    return height
  end
  height = measure(frame, "GetHeight")
  if height <= 0 then
    height = measure(surface.region, "GetHeight")
  end
  if height <= 0 then
    return 0
  end
  return height - INSET * 2
end

-- The link gold, lifted towards white while the pointer is on the word. A client that will not
-- take a text colour keeps the one it has, which is still the link gold.
--
-- colorKey is the colour the words are actually written in, for the one kind of link that is not
-- gold: a row naming another node keeps the item's own quality colour, so what the pointer does
-- to it is lift THAT towards white. Left out, it is the link gold.
local function linkColour(fontString, hovered, colorKey)
  if type(fontString) ~= "table" or type(fontString.SetTextColor) ~= "function" then
    return false
  end
  local r, g, b, a = themeColor(colorKey or COLOR_LINK)
  if not r then
    return false
  end
  if hovered then
    r, g, b = InfoPanel.Brighten(r, g, b, LINK_HOVER)
  end
  fontString:SetTextColor(r, g, b, a or 1)
  return true
end

-- The pointer over a link, where the client has a cursor to change. Named cursors only: no
-- path is written here, and a client that carries neither call simply keeps its arrow.
local function linkCursor(hovered)
  local name = hovered and "SetCursor" or "ResetCursor"
  local call = rawget(_G, name)
  if type(call) ~= "function" then
    return false
  end
  if hovered then
    return (pcall(call, "INTERACT_CURSOR"))
  end
  return (pcall(call))
end

-- E6: the standard modified clicks on a row that names an item. Answers true when the client
-- took the click (the item is on in the Dressing Room, or its link is in the chat box), and the
-- link then does not re-root the window. A right click, a plain click and a row that names
-- anything but an item answer false and do what they always did.
function InfoPanel.ModifiedClick(nodeKey, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.HandleKey) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.HandleKey, nodeKey)
  return ok and handled == true
end

-- One row frame, reused from the pool. A row carries every part any kind of row needs and
-- shows only the ones that kind uses: label on the left, value on the right, the old value
-- ahead of it on a change row with the strike across it, the wrapped paragraph for a spell
-- description, and the hairline for a divider. Every part is anchored again on each draw,
-- because a change row that wraps puts the old value on a line of its own.
local function newRow(parent)
  local row = newFrame("Frame", nil, parent)
  if not row then
    return nil
  end
  row:SetHeight(InfoPanel.RowHeight("fact"))
  row:SetPoint("LEFT", parent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  row.label = newFontString(row, FONT_SM, COLOR_MUTED, "LEFT")
  row.value = newFontString(row, FONT_SM, COLOR_BODY, "RIGHT")
  row.old = newFontString(row, FONT_SM, COLOR_MUTED, "RIGHT")
  row.para = newFontString(row, FONT_SM, COLOR_BODY, "LEFT", true)
  row.line = row:CreateTexture(nil, "ARTWORK")
  row.strike = row:CreateTexture(nil, "OVERLAY")

  if row.label then
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
  end
  if row.value then
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  end
  if row.old and row.value then
    row.old:SetPoint("RIGHT", row.value, "LEFT", -TIGHT, 0)
  end
  -- Anchored on the left only: the width is set on each draw, which is what makes the client
  -- wrap it, and a region anchored on both sides would take its width from the anchors instead.
  if row.para then
    row.para:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.para:Hide()
  end
  if row.line then
    row.line:SetHeight(HAIRLINE)
    row.line:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.line:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    fillTexture(row.line, COLOR_DIVIDER)
    row.line:Hide()
  end
  -- The frame API has no strike through, so this hairline is it: drawn across the old value's
  -- own string width at mid height, in the colour the old value is written in.
  if row.strike then
    row.strike:SetHeight(HAIRLINE)
    fillTexture(row.strike, COLOR_MUTED)
    row.strike:Hide()
  end
  -- The hit area for a row that is a link. Only as wide as its own words, so the rest of the
  -- row stays dead: a summary line that reads "Used in 19 recipes" must not turn the whole
  -- width of the column into something to click.
  row.link = newFrame("Button", nil, row)
  if row.link then
    row.link:SetPoint("LEFT", row, "LEFT", 0, 0)
    if type(row.link.EnableMouse) == "function" then
      row.link:EnableMouse(true)
    end
    if canScript(row.link, "OnClick") then
      row.link:SetScript("OnClick", function(button, mouseButton)
        -- E6: a left click with the client's dress up or chat link modifier on an item link
        -- goes to UI/ItemClick.lua first, and the window stays where it is when the client takes
        -- it. See InfoPanel.ModifiedClick.
        if InfoPanel.ModifiedClick(button.node, mouseButton) then
          return
        end
        -- E39: one small click for the press. The cue is on the row rather than in FollowLink,
        -- which the harness and the window itself also call where no one has pressed anything.
        playCue("click")
        -- A row that names another node re roots the window on it; the summary line at the foot
        -- of the column leads to a view of the root it is already on.
        if button.node then
          InfoPanel.OpenNode(button.node)
          return
        end
        InfoPanel.FollowLink(button.direction)
      end)
    end
    if canScript(row.link, "OnEnter") then
      row.link:SetScript("OnEnter", function(button)
        linkColour(button.word, true, button.wordColorKey)
        linkCursor(true)
        -- Brief Z1: a link that says where it goes, a zone's name for one.
        local tooltip = rawget(_G, "GameTooltip")
        if type(button.hint) == "string" and type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
          tooltip:SetOwner(button, "ANCHOR_RIGHT")
          if type(tooltip.AddLine) == "function" then
            tooltip:AddLine(button.hint)
          end
          if type(tooltip.Show) == "function" then
            tooltip:Show()
          end
        end
      end)
    end
    if canScript(row.link, "OnLeave") then
      row.link:SetScript("OnLeave", function(button)
        linkColour(button.word, false, button.wordColorKey)
        linkCursor(false)
        local tooltip = rawget(_G, "GameTooltip")
        if type(button.hint) == "string" and type(tooltip) == "table" and type(tooltip.Hide) == "function" then
          tooltip:Hide()
        end
      end)
    end
    row.link:Hide()
  end
  return row
end

-- Every word this pane draws goes through here. The font is put back first, and the write
-- itself is pcalled, so a client that can leave a font string with no font at all costs the
-- pane a blank label rather than the whole draw.
local function setText(fontString, text, colorKey)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return
  end
  ensureFont(fontString)
  if text == nil or text == "" then
    pcall(fontString.SetText, fontString, "")
    fontString:Hide()
    return
  end
  pcall(fontString.SetText, fontString, text)
  if colorKey then
    colourText(fontString, colorKey)
  end
  fontString:Show()
end

-- Opacity on anything that carries it, for the faded old value. A client that will not take an
-- alpha simply keeps the one it has.
local function setAlpha(object, alpha)
  if type(object) ~= "table" or type(object.SetAlpha) ~= "function" then
    return false
  end
  return (pcall(object.SetAlpha, object, alpha))
end

-- The value is what the reader came for, so it keeps its width and the label takes what is
-- left: a long label truncates, a number never does.
local function setLabelWidth(row, width)
  if row.label and type(row.label.SetWidth) == "function" then
    row.label:SetWidth(math.max(tonumber(width) or 0, 0))
  end
end

-- A label sized for a fact row stays sized until it is told otherwise, and a heading or a
-- sentence reads across the whole row: width 0 is the client's own "as wide as the text".
local function freeLabel(row)
  setLabelWidth(row, 0)
end

-- Holds a heading or a sentence row to the row's width. See InfoPanel.SentenceWidth.
local function clampSentence(row, width)
  local textWidth = measure(row.label, "GetStringWidth")
  local held = InfoPanel.SentenceWidth(textWidth, width)
  if held < textWidth then
    setLabelWidth(row, held)
  end
  return held
end

-- A width on any region, with 0 meaning "as wide as the text". A font string keeps whatever it
-- was given last, so the value is handed 0 before it is measured and the real width after.
local function setRegionWidth(object, width)
  if type(object) ~= "table" or type(object.SetWidth) ~= "function" then
    return false
  end
  return (pcall(object.SetWidth, object, math.max(tonumber(width) or 0, 0)))
end

local function setRegionHeight(object, height)
  if type(object) ~= "table" or type(object.SetHeight) ~= "function" then
    return false
  end
  return (pcall(object.SetHeight, object, math.max(tonumber(height) or 0, 0)))
end

-- Whether a value takes wrapped lines of its own. Set before the text, because a font string
-- measures itself the way it was last told to wrap.
local function setWrap(object, wrap)
  if type(object) ~= "table" or type(object.SetWordWrap) ~= "function" then
    return false
  end
  return (pcall(object.SetWordWrap, object, wrap and true or false))
end

-- Hides everything a row is not using this time round, so a row that was a change row last
-- draw does not keep its faded old value, its strike, its wrapped value or its link.
local function clearRow(row)
  setText(row.label, nil)
  setText(row.value, nil)
  setText(row.old, nil)
  setText(row.para, nil)
  setAlpha(row.old, 1)
  setWrap(row.value, false)
  setRegionWidth(row.value, 0)
  setWrap(row.old, false)
  setRegionWidth(row.old, 0)
  if row.strike then
    row.strike:Hide()
  end
  if row.line then
    row.line:Hide()
  end
  if row.link then
    row.link.direction = nil
    row.link.node = nil
    row.link.hint = nil
    row.link.word = nil
    row.link.wordColorKey = nil
    row.link:Hide()
  end
  if row.waypointButton then
    row.waypointButton.at = nil
    row.waypointButton:Hide()
  end
  if row.coordsLink then
    row.coordsLink.at = nil
    row.coordsLink:Hide()
  end
end

-- The strike across the old value, at its own string width and at mid height. Anchoring the
-- hairline's right edge to the font string's right edge centres it vertically, and the old
-- value's box is a line high with its text centred in it (newFontString sets that), so the
-- centre of the box is the middle of the words at any window scale. The width is the text's
-- own, so the line never overruns it; cap is the room the old value was held to where the
-- baseline value was wider than the whole column, and the strike is held to the same.
local function drawStrike(row, cap)
  if not (row.strike and row.old) then
    return false
  end
  local textWidth = measure(row.old, "GetStringWidth")
  cap = tonumber(cap) or 0
  if cap > 0 and textWidth > cap then
    textWidth = cap
  end
  if textWidth <= 0 then
    row.strike:Hide()
    return false
  end
  row.strike:ClearAllPoints()
  row.strike:SetWidth(textWidth)
  row.strike:SetHeight(HAIRLINE)
  row.strike:SetPoint("RIGHT", row.old, "RIGHT", 0, 0)
  setAlpha(row.strike, OLD_ALPHA)
  row.strike:Show()
  return true
end

-- Where the value goes once the layout has decided, and how tall the row really is. A value
-- that wrapped is given the column's width so the client breaks it, and the client's own
-- measurement of the wrapped block wins over the estimate where it answers one: the rows under
-- it start below it either way. Returns the row's height.
local function placeValue(row, layout, line)
  local height = layout.height
  if not row.value then
    return height
  end
  local valueHeight = layout.valueHeight or line
  setWrap(row.value, layout.valueWrap and true or false)
  setRegionWidth(row.value, layout.valueWidth or 0)
  if layout.valueWrap then
    local measured = measure(row.value, "GetStringHeight")
    if measured > valueHeight then
      height = height + (measured - valueHeight)
      valueHeight = measured
    end
  end
  setRegionHeight(row.value, valueHeight)
  row.value:ClearAllPoints()
  row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(layout.valueRight or 0), -(layout.valueTop or 0))
  return height
end

-- A change row: label, the old value struck through and faded, then the new value. One line
-- where the three fit, two where they do not, and InfoPanel.ChangeLayout is the one that
-- decides which. Returns the height the row took.
local function drawChangeRow(row, entry, width)
  local line = InfoPanel.RowHeight("change")
  setText(row.label, entry.label, COLOR_MUTED)
  setText(row.old, entry.old, COLOR_MUTED)
  setText(row.value, entry.new, entry.colorKey or COLOR_BODY)
  setAlpha(row.old, OLD_ALPHA)
  freeLabel(row)

  local layout = InfoPanel.ChangeLayout(
    width,
    measure(row.label, "GetStringWidth"),
    measure(row.old, "GetStringWidth"),
    measure(row.value, "GetStringWidth"),
    TIGHT,
    line
  )
  setLabelWidth(row, layout.labelWidth)

  if row.label then
    row.label:ClearAllPoints()
    row.label:SetHeight(line)
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  end
  local height = placeValue(row, layout, line)
  row:SetHeight(height)
  if row.old then
    row.old:ClearAllPoints()
    row.old:SetHeight(line)
    setRegionWidth(row.old, layout.oldWidth or 0)
    if layout.wrap then
      -- The label and the new value keep the lines above; the struck old value drops to the
      -- row's last line, right aligned under them, and never lands on top of the label.
      row.old:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    elseif row.value then
      row.old:SetPoint("TOPRIGHT", row.value, "TOPLEFT", -TIGHT, 0)
    else
      row.old:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    end
  end
  drawStrike(row, layout.oldWidth)
  row.wrapped = layout.wrap
  return height
end

-- A wrapped paragraph across the whole column: the spell description. The client measures it
-- where it can, and where it cannot the estimate is what keeps the rows under it from
-- overlapping it.
local function drawParagraph(row, entry, width)
  local line = InfoPanel.RowHeight("para")
  freeLabel(row)
  if row.para and type(row.para.SetWidth) == "function" and width > 0 then
    row.para:SetWidth(width)
  end
  setText(row.para, entry.value, entry.colorKey or COLOR_BODY)
  local height = measure(row.para, "GetStringHeight")
  if height <= 0 then
    height = InfoPanel.ParagraphLines(entry.value, width, FONT_SM / 2) * line
  end
  height = math.max(height, line)
  row:SetHeight(height)
  if row.para then
    row.para:SetHeight(height)
  end
  return height
end

-- Brief N4: the Set waypoint button's height, the line's with a little room for the client's own
-- button art, and the padding either side of its words.
InfoPanel.WAYPOINT_H = ROW_HEIGHTS.fact + 4
InfoPanel.WAYPOINT_PAD = 16

-- Whether a Where line's waypoint can be set in this client: UI/Map.lua Map.CanWaypoint for its
-- map, the question the Map tab's pins ask (brief M7). False with no Map loaded.
function InfoPanel.CanWaypoint(at)
  if type(at) ~= "table" or type(at.map) ~= "number" then
    return false
  end
  local Map = ItemTree.UI and ItemTree.UI.Map
  if type(Map) ~= "table" or type(Map.CanWaypoint) ~= "function" then
    return false
  end
  local ok, can = pcall(Map.CanWaypoint, at.map)
  return ok and can == true
end

-- The player's press on the Set waypoint button: UI/Map.lua Map.SetWaypoint for that map and
-- place, under pcall. Answers whether the client took it. Brief UX1: label is what the waypoint is
-- for, which the "Waypoint added" toast says (nil says nothing under the title).
function InfoPanel.SetWaypoint(at, label)
  if type(at) ~= "table" then
    return false
  end
  local Map = ItemTree.UI and ItemTree.UI.Map
  if type(Map) ~= "table" or type(Map.SetWaypoint) ~= "function" then
    return false
  end
  local ok, set = pcall(Map.SetWaypoint, at.map, at.x, at.y, label)
  return ok and set == true
end

-- Brief UX1: a Where row's press (the Set waypoint button, or its coordinates): the waypoint the
-- control carries, with the words the row gave it, else the open page's name (InfoPanel.WaypointFor).
function InfoPanel.PressWaypoint(control)
  if type(control) ~= "table" then
    return false
  end
  local label = control.waypointFor
  if type(label) ~= "string" or label == "" then
    label = InfoPanel.WaypointFor(nil, InfoPanel.content)
  end
  return InfoPanel.SetWaypoint(control.at, label)
end

-- The Set waypoint button a row keeps once it has needed one: the client's own button art
-- (UIPanelButtonTemplate) on a Button of our own, in the small font, made the first time a row
-- draws a Where line that has a waypoint. Answers it and its width, sized to its words and the line.
local function waypointButton(row)
  local function sizeOf(made)
    local textWidth = 0
    if type(made.GetTextWidth) == "function" then
      local ok, value = pcall(made.GetTextWidth, made)
      textWidth = ok and tonumber(value) or 0
    end
    if textWidth <= 0 then
      textWidth = string.len(L["Set waypoint"]) * FONT_SM / 2
    end
    local width = math.ceil(textWidth + InfoPanel.WAYPOINT_PAD)
    if type(made.SetSize) == "function" then
      pcall(made.SetSize, made, width, InfoPanel.WAYPOINT_H)
    end
    return width
  end
  local button = row.waypointButton
  if button then
    return button, sizeOf(button)
  end
  button = newFrame("Button", nil, row, "UIPanelButtonTemplate")
  if not button then
    return nil
  end
  local small = rawget(_G, "GameFontNormalSmall")
  if small and type(button.SetNormalFontObject) == "function" then
    pcall(button.SetNormalFontObject, button, small)
  end
  local highlight = rawget(_G, "GameFontHighlightSmall")
  if highlight and type(button.SetHighlightFontObject) == "function" then
    pcall(button.SetHighlightFontObject, button, highlight)
  end
  if type(button.SetText) == "function" then
    pcall(button.SetText, button, L["Set waypoint"])
  end
  if canScript(button, "OnClick") then
    button:SetScript("OnClick", function(self)
      InfoPanel.PressWaypoint(self)
    end)
  end
  button:Hide()
  row.waypointButton = button
  return button, sizeOf(button)
end

-- Brief M14: the hit area over a Where line's coordinates, for a row whose line asks for it
-- (entry.waypointClick): a left click there sets the same waypoint the Set waypoint button does. A
-- Button of our own, made the first time such a row is drawn and kept with the row. A field rather
-- than a local, because this file's main chunk is at Lua 5.1's limit of 200 locals.
function InfoPanel.CoordsLink(row)
  if row.coordsLink then
    return row.coordsLink
  end
  local link = newFrame("Button", nil, row)
  if not link then
    return nil
  end
  if type(link.EnableMouse) == "function" then
    pcall(link.EnableMouse, link, true)
  end
  if canScript(link, "OnClick") then
    link:SetScript("OnClick", function(self, mouseButton)
      if mouseButton ~= nil and mouseButton ~= "LeftButton" then
        return
      end
      InfoPanel.PressWaypoint(self)
    end)
  end
  if canScript(link, "OnEnter") then
    link:SetScript("OnEnter", function(self)
      linkCursor(true)
      local tooltip = rawget(_G, "GameTooltip")
      if type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
        pcall(tooltip.SetOwner, tooltip, self, "ANCHOR_RIGHT")
        if type(tooltip.AddLine) == "function" then
          pcall(tooltip.AddLine, tooltip, L["Set waypoint"])
        end
        if type(tooltip.Show) == "function" then
          pcall(tooltip.Show, tooltip)
        end
      end
    end)
  end
  if canScript(link, "OnLeave") then
    link:SetScript("OnLeave", function()
      linkCursor(false)
      local tooltip = rawget(_G, "GameTooltip")
      if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
        pcall(tooltip.Hide, tooltip)
      end
    end)
  end
  link:Hide()
  row.coordsLink = link
  return link
end

-- Draws one entry into a pooled row and answers the height it took.
local function drawRow(row, entry, width)
  row.kind = entry.kind
  row.wrapped = false
  clearRow(row)

  if entry.kind == "divider" then
    freeLabel(row)
    if row.line then
      row.line:Show()
    end
    row:SetHeight(InfoPanel.RowHeight("divider"))
    return InfoPanel.RowHeight("divider")
  end
  if entry.kind == "para" then
    return drawParagraph(row, entry, width)
  end

  row:SetHeight(InfoPanel.RowHeight(entry.kind))
  -- A heading, a notice, and a fact with no label of its own (the uses line), are sentences
  -- rather than label and value pairs: they read across the row from the left.
  if entry.kind == "heading" then
    freeLabel(row)
    if row.label then
      row.label:ClearAllPoints()
      row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    setText(row.label, entry.label, COLOR_MUTED)
    clampSentence(row, width)
    return InfoPanel.RowHeight("heading")
  end
  if entry.kind == "notice" or not entry.label then
    freeLabel(row)
    if row.label then
      row.label:ClearAllPoints()
      row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    -- A line that leads somewhere is written in the link gold and carries a hit area only as
    -- wide as its own words; everything else reads as the muted sentence it always was.
    local colorKey = entry.colorKey or COLOR_MUTED
    -- Brief GS3: a quiet link (the guessed sources line) keeps its own colour.
    if (entry.link or entry.node) and not entry.quiet then
      colorKey = COLOR_LINK
    end
    setText(row.label, entry.value, colorKey)
    -- Brief TB1: a row's own { r, g, b } (the Keep head's, the bag flag's colour) over its key.
    local own = colorKey ~= COLOR_LINK and type(entry.color) == "table" and entry.color or nil
    if own and row.label and type(row.label.SetTextColor) == "function" and tonumber(own.r) then
      row.label:SetTextColor(own.r, own.g, own.b, 1)
    end
    local wordsWidth = clampSentence(row, width)
    if entry.link and row.link and row.label then
      row.link.direction = entry.link
      row.link.word = row.label
      row.link.wordColorKey = entry.quiet and colorKey or nil
      row.link:SetHeight(InfoPanel.RowHeight(entry.kind))
      setRegionWidth(row.link, wordsWidth)
      row.link:Show()
    elseif entry.node and row.link and row.label then
      -- Brief Z1: a place line that opens the zone's own page, in the link gold, its hover saying so.
      row.link.node = entry.node
      row.link.hint = entry.hint
      row.link.word = row.label
      row.link:SetHeight(InfoPanel.RowHeight(entry.kind))
      setRegionWidth(row.link, wordsWidth)
      row.link:Show()
    end
    return InfoPanel.RowHeight(entry.kind)
  end
  if entry.kind == "change" then
    return drawChangeRow(row, entry, width)
  end

  local line = InfoPanel.RowHeight(entry.kind)
  if row.label then
    row.label:ClearAllPoints()
    row.label:SetHeight(line)
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  end
  -- A label is muted unless the row names a colour for it: a quest's item rows read as the item
  -- names they are, in their own quality colours, with the count muted beside them.
  setText(row.label, entry.label, entry.labelColorKey or COLOR_MUTED)
  setText(row.value, entry.value, entry.colorKey or COLOR_BODY)
  -- A row that names another node leads to it. The hit area is only as wide as the name, so the
  -- rest of the row stays dead, and the name keeps the colour it was written in: an item reads as
  -- its own quality here exactly as it does everywhere else, and the pointer lifts that colour
  -- rather than turning the name into the footer's link gold.
  if entry.node and row.link and row.label then
    row.link.node = entry.node
    row.link.word = row.label
    row.link.wordColorKey = entry.labelColorKey or COLOR_MUTED
    row.link:SetHeight(line)
    setRegionWidth(row.link, measure(row.label, "GetStringWidth"))
    row.link:Show()
  end
  -- The label is never given away to make room: where the two do not fit one line the value
  -- takes wrapped lines of its own under it and the row grows, which is what keeps a long class
  -- list off the word "Classes".
  -- Brief N4: a Where line for a page with one position carries the Set waypoint button on its
  -- right, and the value sits to the button's left.
  local button, buttonWidth = nil, 0
  if InfoPanel.CanWaypoint(entry.waypoint) then
    button, buttonWidth = waypointButton(row)
    buttonWidth = button and (buttonWidth + TIGHT) or 0
  end
  local layout = InfoPanel.FactLayout(
    width - buttonWidth,
    measure(row.label, "GetStringWidth"),
    measure(row.value, "GetStringWidth"),
    TIGHT,
    line
  )
  layout.valueRight = buttonWidth
  setLabelWidth(row, layout.labelWidth)
  local height = placeValue(row, layout, line)
  if button then
    button.at = entry.waypoint
    button.waypointFor = entry.waypointFor
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    button:Show()
    height = math.max(height, InfoPanel.WAYPOINT_H)
    -- Brief M14: the coordinates themselves set it too, on a line that asks for that.
    local link = entry.waypointClick and row.value and InfoPanel.CoordsLink(row) or nil
    if link then
      link.at = entry.waypoint
      link.waypointFor = entry.waypointFor
      link:ClearAllPoints()
      link:SetPoint("TOPRIGHT", row.value, "TOPRIGHT", 0, 0)
      local wordsWidth = measure(row.value, "GetStringWidth")
      if layout.valueWidth and layout.valueWidth > 0 and wordsWidth > layout.valueWidth then
        wordsWidth = layout.valueWidth
      end
      setRegionWidth(link, wordsWidth)
      link:SetHeight(line)
      link:Show()
    end
  end
  row:SetHeight(height)
  row.wrapped = layout.valueWrap
  return height
end

local function rowAt(index, surface)
  surface = surfaceOf(surface)
  local pool = surface.rows
  local row = pool[index]
  if row then
    return row
  end
  local frame = surface.frame
  row = newRow(frame and frame.content or frame)
  if not row then
    return nil
  end
  pool[index] = row
  return row
end

-- The name colour: the client's own quality colours where it has them, the Theme keys where it
-- does not. ITEM_QUALITY_COLORS is read for the quality the header names, so the panel never
-- disagrees with the client's own tooltip.
local function nameColor(fontString, quality, colorKey)
  local colors = rawget(_G, "ITEM_QUALITY_COLORS")
  if quality and type(colors) == "table" then
    local color = colors[quality]
    if type(color) == "table" and color.r and type(fontString.SetTextColor) == "function" then
      fontString:SetTextColor(color.r, color.g, color.b, 1)
      return
    end
  end
  colourText(fontString, colorKey)
end

-- Everything the pane draws, in order: the hairline between two sections, the section heading,
-- then the section's own rows. An item this build has no record of is the one notice row.
local function drawEntries(content)
  local entries = {}
  if content.notice then
    entries[#entries + 1] = { kind = "notice", value = content.notice, colorKey = COLOR_MUTED }
    return entries
  end
  for index, section in ipairs(content.sections or {}) do
    if index > 1 then
      entries[#entries + 1] = { kind = "divider" }
    end
    if section.title then
      entries[#entries + 1] = { kind = "heading", label = section.title }
    end
    for _, row in ipairs(section.rows) do
      entries[#entries + 1] = row
    end
  end
  return entries
end

-- EXPERIMENTAL (brief E25): the Recipe card's own entries, appended under everything the root
-- said. Graph.SpellInfo names the craft, states its skill line, what it makes and who teaches
-- it; the ingredients are the ones the tree row already carried, so the column asks for nothing
-- the pane did not already have. Guarded like every other Graph call here.
local function appendRecipeEntries(entries)
  local card = InfoPanel.recipe
  if type(card) ~= "table" then
    return entries
  end
  local info = nil
  local kind, id = InfoPanel.Root(card.key)
  if kind == "spell" and type(id) == "number" then
    info = moduleCall(ItemTree.Graph, "SpellInfo", id)
  end
  for _, section in ipairs(InfoPanel.RecipeSections(card, info)) do
    if #entries > 0 then
      entries[#entries + 1] = { kind = "divider" }
    end
    if section.title then
      entries[#entries + 1] = { kind = "heading", label = section.title }
    end
    for _, row in ipairs(section.rows) do
      entries[#entries + 1] = row
    end
  end
  return entries
end

--- EXPERIMENTAL (brief E25). The craft the column draws a Recipe card for, or nil to take the
--- card away. card is { key, ingredients, tools } from the tree row under the pointer or the
--- keyboard cursor (UI/Tree.lua, which decides whether the mode in force asks for a card at
--- all). Redraws only when the craft actually changes, so travelling down a list of rows for
--- the same craft costs one draw, and answers whether it redrew.
function InfoPanel.SetRecipe(card)
  local key = nil
  if type(card) == "table" and type(card.key) == "string" then
    key = card.key
  end
  local held = InfoPanel.recipe
  local heldKey = type(held) == "table" and held.key or nil
  if heldKey == key then
    return false
  end
  if key == nil then
    InfoPanel.recipe = nil
  else
    InfoPanel.recipe = card
  end
  if not InfoPanel.frame then
    return false
  end
  return InfoPanel.Refresh()
end

local function buildPanel(region, surface)
  surface = surfaceOf(surface)
  local frame = newFrame("Frame", nil, region)
  if not frame then
    return nil
  end
  frame:SetAllPoints(region)

  -- The frame first, because where the fill stops depends on whether the gold rail drew: under
  -- the rail it stops halfway across it, so nothing of the fill shows outside; with the
  -- hairlines it runs to the column's edge as it always did.
  frame.border = applyColumnFrame(frame)
  local framed = frame.border == "nineslice" or frame.border == "atlas"
  local fillInset = framed and FRAME.fillInset or 0
  frame.framed = framed
  frame.thumbInset = framed and FRAME.thumbInset or HAIRLINE

  frame.background = frame:CreateTexture(nil, "BACKGROUND")
  if frame.background then
    frame.background:SetPoint("TOPLEFT", frame, "TOPLEFT", fillInset, -fillInset)
    frame.background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -fillInset, fillInset)
    fillTexture(frame.background, COLOR_INSET)
  end
  -- The gold wash over the inset surface that makes the column read as a lighter, warmer surface
  -- than the panes beside it, the lightest candidate that keeps every line readable
  -- (InfoPanel.ChooseFill). One sublevel over the inset fill it tints.
  frame.fillKey = InfoPanel.ChooseFill()
  if frame.fillKey then
    frame.wash = frame:CreateTexture(nil, "BACKGROUND")
    if frame.wash then
      if type(frame.wash.SetDrawLayer) == "function" then
        pcall(frame.wash.SetDrawLayer, frame.wash, "BACKGROUND", 1)
      end
      frame.wash:SetPoint("TOPLEFT", frame, "TOPLEFT", fillInset, -fillInset)
      frame.wash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -fillInset, fillInset)
      fillTexture(frame.wash, frame.fillKey)
    end
  end

  -- The column scrolls as one, the header with it, the way the design's info column does.
  local scroll = newFrame("ScrollFrame", nil, frame)
  if not scroll then
    return nil
  end
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -INSET)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET_RIGHT, INSET)
  frame.scroll = scroll

  local content = newFrame("Frame", nil, scroll)
  if not content then
    return nil
  end
  content:SetSize(paneWidth(surface), HEADER_H)
  content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  if type(scroll.SetScrollChild) == "function" then
    scroll:SetScrollChild(content)
  end
  frame.content = content

  if type(scroll.EnableMouseWheel) == "function" then
    scroll:EnableMouseWheel(true)
  end
  scroll:SetScript("OnMouseWheel", function(_, delta)
    InfoPanel.Scroll(-(tonumber(delta) or 0) * SCROLL_STEP, surface)
  end)

  -- No scrollbar art: a thin thumb down the inside edge, drawn only while there is more
  -- column than pane. Just inside the gold rail, on a frame of its own raised over the rail's, so
  -- the rail's soft inner shadow never dims it.
  local thumbHost = newFrame("Frame", nil, frame) or frame
  if thumbHost ~= frame then
    thumbHost:SetAllPoints(frame)
    raiseOver(thumbHost, frame.art)
    frame.thumbHost = thumbHost
  end
  frame.thumb = thumbHost:CreateTexture(nil, "OVERLAY")
  if frame.thumb then
    frame.thumb:SetWidth(THUMB_W)
    fillTexture(frame.thumb, COLOR_THUMB)
    frame.thumb:Hide()
  end

  frame.icon = content:CreateTexture(nil, "ARTWORK")
  if frame.icon then
    frame.icon:SetSize(ICON, ICON)
    frame.icon:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  end

  -- The rarity frame, over the icon and never behind it, in the shape the client's own item
  -- button draws: the art at the icon's own rect, tinted on each draw because the quality is
  -- the root's and not the frame's. A build whose Assets table carries neither key leaves this
  -- nil and the header simply draws the plain icon.
  frame.iconFrame = content:CreateTexture(nil, "OVERLAY")
  frame.iconFrameArt = applyIconFrame(frame.iconFrame)
  if frame.iconFrame and frame.iconFrameArt and frame.icon then
    local art = frame.iconFrameArt
    frame.iconFrame:SetAllPoints(frame.icon)
    if art.blend and type(frame.iconFrame.SetBlendMode) == "function" then
      pcall(frame.iconFrame.SetBlendMode, frame.iconFrame, art.blend)
    end
    frame.iconFrame:Hide()
  else
    frame.iconFrame = nil
  end

  -- The corner mark the tree row and the Discoveries row draw on the same item, in the same
  -- corner and on the same dark disc, so the column's header and the row the player clicked to
  -- get here read as one thing. Nothing is applied here: the mark's art is the root's own and
  -- goes on at every draw.
  frame.markBack = content:CreateTexture(nil, "ARTWORK")
  frame.mark = content:CreateTexture(nil, "OVERLAY")
  if frame.mark and frame.icon then
    frame.mark:SetSize(MARK, MARK)
    frame.mark:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -HAIRLINE, HAIRLINE)
    frame.mark:Hide()
  else
    frame.mark = nil
  end
  if frame.markBack then
    if frame.mark then
      frame.markBack:SetPoint("TOPLEFT", frame.mark, "TOPLEFT", -HAIRLINE, HAIRLINE)
      frame.markBack:SetPoint("BOTTOMRIGHT", frame.mark, "BOTTOMRIGHT", HAIRLINE, -HAIRLINE)
      fillTexture(frame.markBack, "ITEMTREE_BADGE_BACKING")
    end
    frame.markBack:Hide()
  end

  local badges = ItemTree.Badges
  if badges and type(badges.CreateCluster) == "function" then
    local ok, cluster = pcall(badges.CreateCluster, content, BADGE, 2)
    if ok and cluster then
      frame.badges = cluster
      local inset = InfoPanel.BadgeOverhang(BADGE)
      cluster:SetPoint("TOPRIGHT", content, "TOPRIGHT", -inset, -inset)
      -- E48: each mark in the header explains itself on hover, whether or not the thing on
      -- show has anything to diff. The method arrived with that brief, so a build whose Badges
      -- predates it keeps the marks it always drew.
      if type(cluster.SetHoverEnabled) == "function" then
        pcall(cluster.SetHoverEnabled, cluster, true)
      end
    end
  end

  -- The name wraps to a second line beside the icon before it truncates: "Torn Insect Wing"
  -- is two lines, not "Torn Insect...".
  frame.itemName = newFontString(content, FONT_MD, COLOR_TITLE, "LEFT", true)
  if frame.itemName then
    frame.itemName:SetPoint("TOPLEFT", content, "TOPLEFT", ICON + TIGHT, 0)
    if frame.badges then
      frame.itemName:SetPoint("TOPRIGHT", frame.badges, "TOPLEFT", -TIGHT, 0)
    else
      frame.itemName:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    end
    frame.itemName:SetHeight(HEADER_H)
    if type(frame.itemName.SetMaxLines) == "function" then
      pcall(frame.itemName.SetMaxLines, frame.itemName, 2)
    end
  end

  -- The header is the one part of the column a player expects a tooltip from, the way a row in
  -- the tree gives one, so a frame over the icon and the name catches the hover. Mouse only:
  -- the wheel is left to the scroll frame under it.
  frame.headerHit = newFrame("Frame", nil, content)
  if frame.headerHit then
    frame.headerHit:SetHeight(HEADER_H)
    frame.headerHit:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    frame.headerHit:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    if type(frame.headerHit.EnableMouse) == "function" then
      frame.headerHit:EnableMouse(true)
    end
    if canScript(frame.headerHit, "OnEnter") then
      frame.headerHit:SetScript("OnEnter", function()
        InfoPanel.ShowHeaderTooltip(surface)
      end)
    end
    if canScript(frame.headerHit, "OnLeave") then
      frame.headerHit:SetScript("OnLeave", function()
        InfoPanel.HideHeaderTooltip()
      end)
    end
    -- E6: the header takes the standard modified clicks and nothing else. See
    -- InfoPanel.HeaderClick.
    if canScript(frame.headerHit, "OnMouseUp") then
      frame.headerHit:SetScript("OnMouseUp", function(_, button)
        InfoPanel.HeaderClick(button, surface)
      end)
    end
  end

  -- E44: the mark's own hover target, over the glyph with a couple of pixels of slop, so the
  -- player can point at the chest and be told what it means. Made after the header's own hit
  -- frame and raised a level over it, because it has to be the frame the pointer lands on, and
  -- it passes its clicks straight through, so nothing underneath loses a press it would
  -- otherwise have had.
  frame.markHit = newFrame("Frame", nil, content)
  if frame.markHit and frame.mark then
    frame.markHit:SetPoint("TOPLEFT", frame.mark, "TOPLEFT", -MARK_HIT_SLOP, MARK_HIT_SLOP)
    frame.markHit:SetPoint("BOTTOMRIGHT", frame.mark, "BOTTOMRIGHT", MARK_HIT_SLOP, -MARK_HIT_SLOP)
    raiseOver(frame.markHit, frame.headerHit)
    if type(frame.markHit.EnableMouse) == "function" then
      frame.markHit:EnableMouse(true)
    end
    -- The clicks fall through to whatever is under the mark, which is the header and its
    -- modified clicks (E6). A client with no propagation call of its own leaves them where they
    -- were, and the mark then answers no click at all. Brief NC1: the call is refused in combat,
    -- and a creature's page can be the first one built in a fight, so it goes through the badges'
    -- deferral, which makes it now out of combat and once when combat ends otherwise.
    local badgesModule = ItemTree.Badges
    if type(badgesModule) == "table" and type(badgesModule.PropagateClicks) == "function" then
      pcall(badgesModule.PropagateClicks, frame.markHit)
    end
    if canScript(frame.markHit, "OnEnter") then
      frame.markHit:SetScript("OnEnter", function()
        InfoPanel.ShowMarkTooltip(surface)
      end)
    end
    if canScript(frame.markHit, "OnLeave") then
      frame.markHit:SetScript("OnLeave", function()
        InfoPanel.HideHeaderTooltip()
      end)
    end
    frame.markHit:Hide()
  else
    frame.markHit = nil
  end

  -- Rows hang under the header block, which is the only fixed part left.
  frame.rowAnchor = newFrame("Frame", nil, content)
  if frame.rowAnchor then
    frame.rowAnchor:SetHeight(HAIRLINE)
    frame.rowAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -HEADER_H - TIGHT)
    frame.rowAnchor:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -HEADER_H - TIGHT)
  end

  -- The window is what decides how wide this column is, and it has moved it once already, so
  -- the layout is redone whenever the region resizes rather than measured once at build.
  if canScript(frame, "OnSizeChanged") then
    frame:SetScript("OnSizeChanged", function()
      InfoPanel.OnSizeChanged(surface)
    end)
  end

  frame:Hide()
  return frame
end

-- Attaches the pane to the frame the window built and sized for it. Idempotent: called again
-- with the same region it does nothing, and with a different one it moves the pane rather than
-- building a second. False with no client, which is what makes every call below a no op.
function InfoPanel.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  local frame = InfoPanel.frame
  if frame then
    if InfoPanel.region ~= region then
      frame:SetParent(region)
      frame:ClearAllPoints()
      frame:SetAllPoints(region)
      InfoPanel.region = region
    end
    return true
  end
  InfoPanel.region = region
  frame = buildPanel(region, InfoPanel)
  if not frame then
    InfoPanel.region = nil
    return false
  end
  InfoPanel.frame = frame
  InfoPanel.rows = {}
  InfoPanel.offset = 0
  return true
end

-- The header icon: the item's own, the recipe's own where the data carries one, and the spell
-- mark from Assets where it does not. Textures only ever come from an Assets key or from a
-- fileDataID the generated data states; no path is ever written here.
-- The rarity frame over the header icon, tinted with the root's own quality colour. Drawn only
-- for a root that states a quality worth a frame (InfoPanel.QualityEdge decides), so a common
-- reagent, a spell, an enchant and a quest all keep the plain icon, which is what the client
-- itself draws for them.
local function drawIconFrame(header, shown, surface)
  surface = surfaceOf(surface)
  local texture = surface.frame and surface.frame.iconFrame
  if not texture then
    return false
  end
  local key = nil
  if shown and type(header) == "table" then
    key = InfoPanel.QualityEdge(header.quality)
  end
  local r, g, b = nil, nil, nil
  if key then
    r, g, b = themeColor(key)
  end
  if not r or type(texture.SetVertexColor) ~= "function" then
    texture:Hide()
    return false
  end
  texture:SetVertexColor(r, g, b)
  texture:Show()
  return true
end

-- The corner mark on the header icon, from the same rule the tree row asks (Core/Graph.lua
-- Graph.DiscoveryMark): the content already states the two facts it is decided from. Drawn only
-- while the icon itself is, because a mark with no icon under it is a glyph floating in the pad.
local function drawHeaderMark(content, iconShown, surface)
  local frame = surfaceOf(surface).frame
  local mark, back, hit = frame.mark, frame.markBack, frame.markHit
  -- E44: the hover target over the glyph follows the chest and nothing else. A question mark
  -- needs none: the column already says what it means in words, in the block under the header.
  if hit then
    if iconShown and InfoPanel.MarkText(content) then
      hit:Show()
    else
      hit:Hide()
    end
  end
  if not mark then
    return false
  end
  local art = nil
  if iconShown then
    local graph = ItemTree.Graph
    local word = InfoPanel.MarkWord(content)
    local key = nil
    if type(word) == "string" and type(graph) == "table" and type(graph.DISCOVERY_MARK_ART) == "table" then
      key = graph.DISCOVERY_MARK_ART[word]
    end
    if type(key) == "string" then
      local assets = ItemTree.Assets
      local has = type(assets) == "table" and type(assets.Has) == "function" and assets.Has(key) == true
      if has and select(1, pcall(assets.Apply, mark, key)) then
        art = key
      end
    end
  end
  if art then
    if type(mark.SetVertexColor) == "function" then
      mark:SetVertexColor(1, 1, 1)
    end
    mark:Show()
    if back then
      back:Show()
    end
    return true
  end
  mark:Hide()
  if back then
    back:Hide()
  end
  return false
end

--- Brief PT1 (owner QA 2026-10-19, item 275): the creature's own portrait in the header's square,
--- from the display id InfoPanel.HeaderPortrait answers, on our own texture (frame.icon), through the
--- client call the rows and the window's round portrait use. One call per draw of a card, like the
--- window's portrait, and no queue: the queue is for long lists of rows. What was asked and whether
--- it drew is kept on the surface (surface.headerPortrait) for the /itemtree debug line. Answers
--- whether the portrait is up; false leaves the square to the glyph below.
function InfoPanel.DrawHeaderPortrait(content, surface)
  surface = surfaceOf(surface)
  local icon = surface.frame and surface.frame.icon or nil
  local display = InfoPanel.HeaderPortrait(content)
  if type(content) ~= "table" or (content.kind ~= "creature" and content.kind ~= "npc" and not display) then
    surface.headerPortrait = nil
    return false
  end
  local drawn = false
  local call = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
  if display and type(icon) == "table" and type(call) == "function" then
    -- A glyph's tex coords and tint never carry over onto the face.
    if type(icon.SetTexCoord) == "function" then
      pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
    end
    if type(icon.SetVertexColor) == "function" then
      pcall(icon.SetVertexColor, icon, 1, 1, 1)
    end
    drawn = select(1, pcall(call, icon, display)) == true
  end
  surface.headerPortrait = { display = display, drawn = drawn }
  if drawn and type(icon.Show) == "function" then
    icon:Show()
  end
  return drawn
end

local function drawHeaderIcon(content, surface)
  local frame = surfaceOf(surface).frame
  local header = content.header
  if not frame.icon then
    return false
  end
  if not header then
    -- Brief PT1: no card, so no record of one for the debug line.
    surfaceOf(surface).headerPortrait = nil
    frame.icon:Hide()
    drawIconFrame(header, false, surface)
    return false
  end
  -- Brief PT1: a creature with a display id wears its own face; the glyph is for one with none.
  if InfoPanel.DrawHeaderPortrait(content, surface) then
    drawIconFrame(header, true, surface)
    return true
  end
  local icon
  if type(content.itemId) == "number" and Assets and type(Assets.ItemIcon) == "function" then
    local ok, found = pcall(Assets.ItemIcon, content.itemId)
    if ok then
      icon = found
    end
  elseif header.icon ~= nil then
    icon = header.icon
  end
  if icon ~= nil and type(frame.icon.SetTexture) == "function" then
    frame.icon:SetTexture(icon)
    frame.icon:Show()
    drawIconFrame(header, true, surface)
    return true
  end
  -- A root with no art of its own wears the glyph its kind wears everywhere else in the window:
  -- the quest mark for a quest, the blue flame for a spell. The header states the key, so no
  -- path is written here and a kind with no glyph draws nothing rather than a question mark.
  local key = nil
  if type(header.asset) == "string" then
    key = header.asset
  elseif type(content.spellId) == "number" then
    key = "ICON_SPELL_MARK"
  end
  if key and Assets and type(Assets.Apply) == "function" then
    local has = type(Assets.Has) ~= "function" or Assets.Has(key) == true
    if has and select(1, pcall(Assets.Apply, frame.icon, key)) then
      frame.icon:Show()
      drawIconFrame(header, true, surface)
      return true
    end
  end
  frame.icon:Hide()
  drawIconFrame(header, false, surface)
  return false
end

--------------------------------------------------------------------------------
-- The creature page's one model (brief E57)
--------------------------------------------------------------------------------

-- How tall the model block is, and the air under it before the first fact row. The column was
-- 225 wide when this was chosen, so a square of about that was the whole of what there is: any
-- taller and the type, the level and the zones are below the fold on a short window. At 180 it
-- stands a little taller than it is wide, which the model's own framing absorbs.
InfoPanel.MODEL_H = 168
InfoPanel.MODEL_GAP = TIGHT * 2

-- The camera, following Interface/AddOns/Blizzard_FrameXML/QuestNPCModelFrameMixin.lua and
-- Interface/AddOns/Blizzard_SharedXML/Mainline/ModelFrames.lua on the `forever` branch of
-- Gethe/wow-ui-source, which is the code the Forever client runs.
--
--   zoom      SetPortraitZoom. Blizzard's own quest giver frame uses 0.6, which is a head and
--             shoulders; MODELFRAME_MIN_ZOOM is 0.0 and that is the WHOLE model, which is what
--             the owner asked for ("load the model of the creature"), so a murloc and a dragon
--             are both entirely inside the box.
--   rotation  SetRotation, in radians. MODELFRAME_DEFAULT_ROTATION is 0.61, about 35 degrees off
--             front, which is the angle every model frame in the client opens at and is exactly
--             the "facing slightly off front" the brief asks for. QuestNPCModelFrameMixin uses 0
--             instead, because a quest giver is talking to you; a creature being looked at reads
--             better at the client's own default.
InfoPanel.MODEL_ZOOM = 0
InfoPanel.MODEL_ROTATION = 0.61

-- The one PlayerModel this pane ever makes, plus the texture behind it that stands in when there
-- is no model to draw. Made once, on the first creature page, and reused for every creature after
-- it: a frame per root would leak one model per creature the player looks at.
--
-- nil for a client with no PlayerModel frame type at all, which is what leaves the fallback
-- texture as the whole of the block.
local function buildModel(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  if not frame then
    return nil
  end
  if surface.modelBlock then
    return surface.modelBlock
  end
  local parent = frame.content or frame
  local block = { parent = parent }
  block.holder = newFrame("Frame", nil, parent)
  if not block.holder then
    return nil
  end
  block.holder:SetHeight(InfoPanel.MODEL_H)
  block.holder:Hide()
  -- The stand in: the kind of creature it is, as big as the block. Always made, because it is
  -- what a creature with no shipped display id, a client with no PlayerModel and a call that
  -- raised all fall back to, and an empty box is the one answer the brief refuses.
  if type(block.holder.CreateTexture) == "function" then
    local ok, texture = pcall(block.holder.CreateTexture, block.holder, nil, "ARTWORK")
    if ok and texture then
      block.glyph = texture
      local side = math.min(InfoPanel.MODEL_H, ICON * 3)
      texture:SetSize(side, side)
      texture:SetPoint("CENTER", block.holder, "CENTER", 0, 0)
      texture:Hide()
    end
  end
  -- PlayerModel is the frame type SetDisplayInfo lives on (FrameAPICharacterModelBase on the
  -- `forever` branch). A client that does not carry it leaves model nil and the glyph does the
  -- whole job.
  block.model = newFrame("PlayerModel", nil, block.holder)
  if block.model then
    block.model:SetAllPoints(block.holder)
    -- So a model never keeps rendering behind a hidden frame: the window's own OnHide clears it
    -- as well, and this is the belt to that brace.
    if type(block.model.SetKeepModelOnHide) == "function" then
      pcall(block.model.SetKeepModelOnHide, block.model, false)
    end
    block.model:Hide()
  end
  surface.modelBlock = block
  return block
end

-- Puts one display id on the model, with the camera above. Answers false for anything at all
-- going wrong, which is what sends the block to its glyph instead.
local function applyModel(block, display)
  local model = block.model
  if not model or type(model.SetDisplayInfo) ~= "function" then
    return false
  end
  if type(model.ClearModel) == "function" then
    pcall(model.ClearModel, model)
  end
  if not select(1, pcall(model.SetDisplayInfo, model, display)) then
    return false
  end
  if type(model.SetPortraitZoom) == "function" then
    pcall(model.SetPortraitZoom, model, InfoPanel.MODEL_ZOOM)
  end
  if type(model.SetRotation) == "function" then
    -- animate = false: the model is being put on screen, not turned, and the client's own default
    -- for the second argument is true, which spins it on every redraw.
    if not select(1, pcall(model.SetRotation, model, InfoPanel.MODEL_ROTATION, false)) then
      pcall(model.SetRotation, model, InfoPanel.MODEL_ROTATION)
    end
  end
  if type(model.RefreshCamera) == "function" then
    pcall(model.RefreshCamera, model)
  end
  block.display = display
  -- Brief RB2: a display drawn this way shows at once, and is what a later creature load must not
  -- take for its own (InfoPanel.ConfirmModel).
  InfoPanel.HoldModel(block, false)
  block.shownDisplay, block.shownFor = display, nil
  return true
end

-- The creature's own portrait as a flat texture, which is the middle answer: better than a stock
-- glyph and available wherever the row portraits are (brief E53 uses the same call). False where
-- the client does not carry it.
local function applyPortrait(block, display)
  local glyph = block.glyph
  local call = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
  if not glyph or type(call) ~= "function" or type(display) ~= "number" then
    return false
  end
  return (pcall(call, glyph, display))
end

--- Brief T8: the target's GUID now, or nil. One read, made when a creature page draws. A field
--- rather than a local, since the file is at the 200 local limit.
function InfoPanel.TargetGuid()
  local guid = rawget(_G, "UnitGUID")
  if type(guid) ~= "function" then
    return nil
  end
  local ok, answer = pcall(guid, "target")
  -- Brief SV1: a GUID the client keeps secret is no GUID. No new local: the file is at the limit.
  if ok and ItemTree.Util.CanRead(answer) and type(answer) == "string" then
    return answer
  end
  return nil
end

-- Brief T8: puts a model on from the unit (SetUnit) or the creature id (SetCreature), the way
-- UI/BossLoot.lua ApplyCreatureModel does (brief BL14), with the same camera. The client draws a
-- creature id out of its own creature cache, which holds every creature the player has seen; one
-- it has never seen draws nothing and raises nothing, so the glyph stays up under the model until
-- the client says a model loaded (GetModelFileID answers, now or on OnModelLoaded, which is hooked
-- on our own PlayerModel, once). False where the model cannot take the call. A field rather than
-- a local, since the file is at the 200 local limit.
function InfoPanel.ApplyLiveModel(block, how, value, asset, pageCreature)
  local model = block.model
  local call = how == "unit" and "SetUnit" or "SetCreature"
  if not model or type(model[call]) ~= "function" then
    return false
  end
  if type(model.ClearModel) == "function" then
    pcall(model.ClearModel, model)
  end
  -- Brief RB2b: a creature id draw is held and shown before it is asked for (the client loads a
  -- model only into a shown frame), and what the frame reports once cleared and shown is read
  -- then: no display there means whatever it reports after SetCreature is this load's own.
  local cleared = nil
  if how == "creature" then
    InfoPanel.HoldModel(block, true)
    model:Show()
    local shown, readable = InfoPanel.ModelDisplay(model)
    cleared = shown or (readable and 0) or nil
  end
  if not select(1, pcall(model[call], model, value)) then
    return false
  end
  if type(model.SetPortraitZoom) == "function" then
    pcall(model.SetPortraitZoom, model, InfoPanel.MODEL_ZOOM)
  end
  if type(model.SetRotation) == "function" then
    if not select(1, pcall(model.SetRotation, model, InfoPanel.MODEL_ROTATION, false)) then
      pcall(model.SetRotation, model, InfoPanel.MODEL_ROTATION)
    end
  end
  if type(model.RefreshCamera) == "function" then
    pcall(model.RefreshCamera, model)
  end
  block.creatureId = how == "creature" and value or true
  block.unit = how == "unit" and value or nil
  -- Brief RB2 (owner QA 2026-10-17 item 192): a creature id draw is held unseen until the client
  -- reports the model for THIS creature (InfoPanel.ConfirmModel); a unit draw shows at once.
  if how == "creature" then
    InfoPanel.StartModelLoad(block, value, cleared)
  else
    block.modelLoad = nil
    -- The page's own creature id (pageCreature, where the page has one), whose model a unit draw
    -- shows: a later load of that creature by id never takes its display for a stale one.
    block.unitFor = tonumber(pageCreature)
    InfoPanel.HoldModel(block, false)
  end
  model:Show()
  local glyph = block.glyph
  local function loaded()
    if type(model.GetModelFileID) ~= "function" then
      return false
    end
    local ok, fileId = pcall(model.GetModelFileID, model)
    return ok and type(fileId) == "number" and fileId > 0
  end
  if glyph then
    if how ~= "creature" and loaded() then
      glyph:Hide()
      InfoPanel.NoteUnitShown(block)
    else
      local has = type(asset) == "string" and (type(Assets.Has) ~= "function" or Assets.Has(asset) == true)
      if has and select(1, pcall(Assets.Apply, glyph, asset)) then
        glyph:Show()
      else
        glyph:Hide()
      end
      if not block.creatureHooked and type(model.HookScript) == "function" then
        local hasScript = type(model.HasScript) ~= "function"
          or select(2, pcall(model.HasScript, model, "OnModelLoaded"))
        if hasScript then
          block.creatureHooked = pcall(model.HookScript, model, "OnModelLoaded", function()
            InfoPanel.ModelLoaded(block)
          end)
        end
      end
    end
  end
  -- Brief RB2: a creature the client already has is confirmed (and shown) at once; else the retry
  -- ladder asks again (InfoPanel.ScheduleModelRetry).
  if how == "creature" and not InfoPanel.ConfirmModel(block) then
    InfoPanel.ScheduleModelRetry(block, block.modelLoad)
  end
  return true
end

-- Brief RB2 (owner QA 2026-10-17 item 192, Owen Thadd 211022: "the wrong model again on first open
-- (going to another page and back fixes it)", and on another day the Crest of Lordaeron's model
-- stood in his place). PlayerModel:SetCreature(id) for a creature the client has not cached sends a
-- query and draws nothing, or keeps drawing the model the frame drew last
-- (FrameAPICharacterModelBaseDocumentation.lua:153 SetCreature, :43 GetDisplayInfo, forever branch;
-- the Boss loot tab met the same, brief BL17). So a creature id draw keeps the kind glyph up and
-- the model unseen (alpha 0: the frame stays shown so the client goes on loading it) until the
-- client reports the model for THIS creature: GetDisplayInfo answers a display id, on
-- OnModelLoaded or a read of our own, that is not the one this block showed for something else
-- (block.shownDisplay), unless this creature is known to wear it (Core/CreatureLookup.lua
-- SeenDisplay). Then it shows, the display id is kept for the portraits (InfoPanel.KeepLiveDisplay)
-- and the window's round portrait is drawn again. While the answer is not there, SetCreature is
-- asked again on BL17's ladder (0.5, 1, 2 then 4 seconds, five tries in all), then the glyph stays.
-- A load another draw replaced does nothing.
--
-- Brief RB2b (the Fable review of the run back, finding M1): two creatures that wear one model.
-- Open a page drawn from display D, then a creature drawn by id whose own model is D too: the
-- client answers D, the block's stale one, and RB2's rule held the model for good. Now a display
-- equal to the stale one is the load's own where the frame was seen with no display during this
-- load (read once cleared and shown, before SetCreature, and at every read since: a frame that
-- went blank and then reports D was given D by our call), or where OnModelLoaded follows one of
-- our SetCreature retries (a model loaded because we asked again; the first call's event is not
-- taken, as showing the frame may reload the model it held). A frame that reports the other
-- creature's display throughout, and never fires after a retry, keeps the glyph: a wrong model is
-- never shown. The mirror (wow-ui-source, forever 1.60.1 70245) shows no Blizzard PlayerModel code
-- on OnModelLoaded (the one model loaded hook there is a ModelScene actor's,
-- Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:3448 SetOnModelLoadedCallback), so the reads
-- of GetDisplayInfo (FrameAPICharacterModelBaseDocumentation.lua:43) carry the rule and the event
-- is the second way in; where it never fires the ladder's reads still decide.

-- BL17's ladder (UI/BossLoot.lua MODEL_RETRY_DELAYS, MODEL_MAX_TRIES).
InfoPanel.MODEL_RETRY_DELAYS = { 0.5, 1, 2, 4 }
InfoPanel.MODEL_MAX_TRIES = 5
InfoPanel.modelLoads = 0

--- The wait after try number tries before the display id is read again, or nil once no try is
--- left. Pure.
function InfoPanel.ModelRetryDelay(tries)
  tries = tonumber(tries)
  if not tries or tries < 1 or tries >= InfoPanel.MODEL_MAX_TRIES + 1 then
    return nil
  end
  local delays = InfoPanel.MODEL_RETRY_DELAYS
  return delays[math.min(math.floor(tries), #delays)]
end

--- Whether display, what GetDisplayInfo answered, is the model a load asked for: a whole display id
--- above nought that is not the stale one the block showed before (load.stale), unless the
--- creature is known to wear it (load.known). Pure.
function InfoPanel.ModelConfirmed(display, load)
  if type(display) ~= "number" or display <= 0 or display ~= math.floor(display) or type(load) ~= "table" then
    return false
  end
  return display ~= load.stale or load.known == display
end

--- Brief RB2b: whether display is a creature load's own model: InfoPanel.ModelConfirmed, or a
--- whole display id above nought equal to the stale one where the frame was seen with no display
--- during the load (load.sawClear), or where it came with OnModelLoaded (viaEvent) after a
--- SetCreature retry of ours (load.tries 2 or more). Pure.
function InfoPanel.ModelAccepted(display, load, viaEvent)
  if InfoPanel.ModelConfirmed(display, load) then
    return true
  end
  if not InfoPanel.ModelConfirmed(display, {}) or type(load) ~= "table" then
    return false
  end
  return load.sawClear == true or (viaEvent == true and (tonumber(load.tries) or 0) >= 2)
end

--- Brief RB2b: the display id a model frame reports, a whole number above nought, or nil (none, 0,
--- a value the client keeps secret, no such call), and whether the frame answered readably (true
--- for a plain 0 too, false for a secret value, a raise or no such call). Guarded.
function InfoPanel.ModelDisplay(model)
  if type(model) ~= "table" or type(model.GetDisplayInfo) ~= "function" then
    return nil, false
  end
  local ok, display = pcall(model.GetDisplayInfo, model)
  -- Brief SV1: a value the client keeps secret is no display id, and no answer either.
  if not ok or not ItemTree.Util.CanRead(display) then
    return nil, false
  end
  if not InfoPanel.ModelConfirmed(display, {}) then
    return nil, true
  end
  return display, true
end

--- Shows (held false) or hides (held true) the model's drawing without hiding its frame: the
--- model's own alpha and the frame's. Guarded.
function InfoPanel.HoldModel(block, held)
  local model = type(block) == "table" and block.model or nil
  if type(model) ~= "table" then
    return false
  end
  local alpha = held and 0 or 1
  if type(model.SetModelAlpha) == "function" then
    pcall(model.SetModelAlpha, model, alpha)
  end
  if type(model.SetAlpha) == "function" then
    pcall(model.SetAlpha, model, alpha)
  end
  block.modelHeld = held and true or nil
  return true
end

--- Starts a creature id load on a block: the model held, and the load ({ token, creatureId, tries,
--- stale, known, sawClear }) kept as block.modelLoad. cleared is what the frame reported once
--- cleared and shown, before SetCreature (InfoPanel.ModelDisplay): a display id, 0 for a readable
--- answer of none (which sets sawClear), or nil where it could not be read. Answers the load. Guarded.
function InfoPanel.StartModelLoad(block, creatureId, cleared)
  InfoPanel.modelLoads = InfoPanel.modelLoads + 1
  local stale = nil
  if block.shownFor ~= creatureId then
    stale = block.shownDisplay
  end
  local load = {
    token = InfoPanel.modelLoads,
    creatureId = creatureId,
    tries = 1,
    stale = stale,
    known = moduleCall(ItemTree.CreatureLookup, "SeenDisplay", creatureId),
    sawClear = cleared == 0 or nil,
  }
  block.modelLoad = load
  InfoPanel.HoldModel(block, true)
  return load
end

--- Reads the display id for the block's current creature load and, where it is the model asked for
--- (InfoPanel.ModelAccepted; viaEvent true when OnModelLoaded asks), shows it: the model unheld, the
--- glyph down, the display kept for the portraits and the window's round portrait drawn again.
--- Answers whether the load is done. Guarded.
function InfoPanel.ConfirmModel(block, viaEvent)
  local load = type(block) == "table" and block.modelLoad or nil
  local model = type(block) == "table" and block.model or nil
  if type(load) ~= "table" or type(model) ~= "table" or block.creatureId ~= load.creatureId then
    return false
  end
  if load.done then
    return true
  end
  if type(model.GetDisplayInfo) ~= "function" then
    return false
  end
  local ok, display = pcall(model.GetDisplayInfo, model)
  -- Brief SV1: a value the client keeps secret is no display id.
  if not ok or not ItemTree.Util.CanRead(display) then
    return false
  end
  -- Brief RB2b: a frame that reports no display has let go of what it held (load.sawClear).
  if not InfoPanel.ModelConfirmed(display, {}) then
    load.sawClear = true
    return false
  end
  if not InfoPanel.ModelAccepted(display, load, viaEvent) then
    return false
  end
  load.done = true
  InfoPanel.HoldModel(block, false)
  if block.glyph and type(block.glyph.Hide) == "function" then
    block.glyph:Hide()
  end
  block.shownDisplay, block.shownFor = display, load.creatureId
  -- Brief QI1: the display id, kept for the rows' and the window's portraits.
  InfoPanel.KeepLiveDisplay(block)
  InfoPanel.RedrawPortrait(load.creatureId)
  return true
end

--- The hook on our own PlayerModel's OnModelLoaded: a creature load is confirmed (or not yet); a
--- unit draw takes its glyph down and remembers what it showed. Guarded.
function InfoPanel.ModelLoaded(block)
  if type(block) ~= "table" then
    return false
  end
  if type(block.modelLoad) == "table" then
    -- Brief RB2b: through the event, which after a retry of ours may take the stale display.
    return InfoPanel.ConfirmModel(block, true)
  end
  if block.unit and block.glyph and type(block.glyph.Hide) == "function" then
    block.glyph:Hide()
    InfoPanel.NoteUnitShown(block)
  end
  return false
end

--- A unit draw's display id, noted as what the block shows (for the page's own creature,
--- block.unitFor), so a later creature load knows it for a stale one. Answers whether one was
--- noted. Guarded.
function InfoPanel.NoteUnitShown(block)
  local model = type(block) == "table" and block.model or nil
  if not block.unit or type(model) ~= "table" or type(model.GetDisplayInfo) ~= "function" then
    return false
  end
  local ok, display = pcall(model.GetDisplayInfo, model)
  -- Brief SV1: a value the client keeps secret is no display id.
  if not ok or not ItemTree.Util.CanRead(display) or not InfoPanel.ModelConfirmed(display, {}) then
    return false
  end
  block.shownDisplay, block.shownFor = display, block.unitFor
  return true
end

--- One step of the ladder for a load: wait, read, and ask SetCreature again while the model is not
--- confirmed and a try is left; give up quietly after the last. Nothing for a load another draw
--- replaced. Answers whether a wait was booked. Guarded.
function InfoPanel.ScheduleModelRetry(block, load)
  if type(block) ~= "table" or type(load) ~= "table" or load.done then
    return false
  end
  local delay = InfoPanel.ModelRetryDelay(load.tries)
  local timer = rawget(_G, "C_Timer")
  if not delay or type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  return (
    pcall(timer.After, delay, function()
      if block.modelLoad ~= load or load.done or block.creatureId ~= load.creatureId then
        return
      end
      if InfoPanel.ConfirmModel(block) then
        return
      end
      local model = block.model
      if
        load.tries >= InfoPanel.MODEL_MAX_TRIES
        or type(model) ~= "table"
        or type(model.SetCreature) ~= "function"
        or not pcall(model.SetCreature, model, load.creatureId)
      then
        load.gaveUp = true
        return
      end
      load.tries = load.tries + 1
      if not InfoPanel.ConfirmModel(block) then
        InfoPanel.ScheduleModelRetry(block, load)
      end
    end)
  )
end

--- The window's round portrait drawn again once a creature's model is confirmed, where the window
--- is on that creature's page (UI/Frame.lua DrawCreaturePortrait, which reads the display id just
--- kept). Answers whether it was asked. Guarded.
function InfoPanel.RedrawPortrait(creatureId)
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) ~= "table" or type(frame.DrawCreaturePortrait) ~= "function" or not frame.portrait then
    return false
  end
  if type(creatureId) ~= "number" or frame.rootKey ~= "npc:" .. tostring(creatureId) then
    return false
  end
  return (pcall(frame.DrawCreaturePortrait, frame.portrait, frame.rootKey))
end

-- Brief QI1 (owner QA 2026-10-17, feedback item 182: Owen Thadd 211022 wore the generic NPC icon):
-- keeps the display id the client drew a creature page's model with (one GetDisplayInfo read on our
-- own PlayerModel, FrameAPICharacterModelBaseDocumentation.lua:43 on the forever branch; 0 until
-- the client has the creature) for the creature id the page asked for (block.creatureId, a number
-- only for a SetCreature draw), in Core/CreatureLookup.lua RememberDisplay, where the rows' and the
-- window's portraits find it (Core/ViewModel.lua SeenDisplay). The Boss loot tab keeps a boss's the
-- same way (brief BL17, UIBossLoot.RememberDisplay). Answers whether one was kept. A field rather
-- than a local, since the file is at the 200 local limit.
function InfoPanel.KeepLiveDisplay(block)
  local model = type(block) == "table" and block.model or nil
  local creatureId = type(block) == "table" and block.creatureId or nil
  if type(creatureId) ~= "number" or type(model) ~= "table" or type(model.GetDisplayInfo) ~= "function" then
    return false
  end
  local ok, display = pcall(model.GetDisplayInfo, model)
  -- Brief SV1: a value the client keeps secret is no display id.
  if not ok or not ItemTree.Util.CanRead(display) then
    return false
  end
  if moduleCall(ItemTree.CreatureLookup, "RememberDisplay", creatureId, display) ~= true then
    return false
  end
  -- Brief DM2 (owner QA 2026-10-17 item 192): and in the player's saved records, so the portrait
  -- outlasts a /reload and the owner's mine carries the display id into the Creatures data. Only
  -- this confirmed SetCreature draw writes: a unit draw (InfoPanel.NoteUnitShown) shows the unit as
  -- it looks now (a disguise, a shapeshift or a polymorph is not the creature's own model) and is
  -- read with no stale check, so it never records.
  moduleCall(ItemTree.CreatureLookup, "SaveDisplay", creatureId, display)
  return true
end

-- Takes the model down: the model cleared and both halves of the block hidden.
--
-- Called whenever the column draws anything that is not a creature, and from the window's own
-- OnHide, so no model is left rendering behind a closed window. Idempotent, and false where there
-- was never a block to clear. surface is the column to clear, the window's own when left out.
function InfoPanel.ClearModel(surface)
  -- Brief CT1b: the next refresh draws the column whole again (InfoPanel.Refresh).
  surfaceOf(surface).drawn = nil
  local block = surfaceOf(surface).modelBlock
  if type(block) ~= "table" then
    return false
  end
  block.display = nil
  block.kind = nil
  block.creatureId = nil
  block.unit = nil
  -- Brief RB2: a creature load still waiting stops (block.shownDisplay stays: it is what the
  -- client may still draw next).
  block.modelLoad = nil
  if block.model then
    if type(block.model.ClearModel) == "function" then
      pcall(block.model.ClearModel, block.model)
    end
    block.model:Hide()
  end
  if block.glyph then
    block.glyph:Hide()
  end
  if block.holder then
    block.holder:Hide()
  end
  return true
end

-- The one model on a creature page, under the header. Answers how tall the block came out, which
-- is 0 for every other kind of root.
--
-- The model is drawn whatever the "Creature portraits" setting says: that setting is about the
-- portrait on every ROW of a long list, which is a call per row and a queue behind it, and this is
-- one model on a page the player opened to look at the creature.
local function drawCreatureModel(content, surface)
  surface = surfaceOf(surface)
  -- Brief T8: an NPC page with a real npc id, or one opened from a unit, has a model to draw too.
  local wanted = type(content) == "table"
    and (content.kind == "creature" or tonumber(content.creatureId) ~= nil or type(content.origin) == "table")
  if not wanted then
    InfoPanel.ClearModel(surface)
    return 0
  end
  local block = buildModel(surface)
  if not block or not block.holder then
    return 0
  end
  block.holder:ClearAllPoints()
  local frame = surface.frame
  local parent = block.parent
  block.holder:SetPoint("LEFT", parent, "LEFT", 0, 0)
  block.holder:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  if frame and frame.rowAnchor then
    block.holder:SetPoint("TOP", frame.rowAnchor, "BOTTOM", 0, 0)
  else
    block.holder:SetPoint("TOP", parent, "TOP", 0, -HEADER_H - TIGHT)
  end
  block.holder:SetHeight(InfoPanel.MODEL_H)
  block.holder:Show()

  block.creatureId, block.unit = nil, nil
  -- Brief RB2: every draw starts with no creature load in flight and the model unheld; only a
  -- creature id draw holds it (InfoPanel.StartModelLoad).
  block.modelLoad = nil
  InfoPanel.HoldModel(block, false)
  -- Brief C4: the portrait below falls back to the Creatures data's display id too.
  local display = tonumber(content.display) or tonumber(content.creaturesDisplay)
  -- Brief T8: the shipped display id first, then the unit while it is still the target, then the
  -- creature id (InfoPanel.ModelSources), then the portrait and the glyph below.
  local glyphKey = content.header and content.header.asset or nil
  if glyphKey == nil then
    glyphKey = "CREATURE_UNKNOWN"
  end
  for _, source in ipairs(InfoPanel.ModelSources(content, InfoPanel.TargetGuid())) do
    if source.how == "display" then
      if applyModel(block, source.value) then
        if block.glyph then
          block.glyph:Hide()
        end
        block.model:Show()
        return InfoPanel.MODEL_H + InfoPanel.MODEL_GAP
      end
    elseif InfoPanel.ApplyLiveModel(block, source.how, source.value, glyphKey, InfoPanel.PageCreatureId(content)) then
      return InfoPanel.MODEL_H + InfoPanel.MODEL_GAP
    end
  end
  if block.model then
    if type(block.model.ClearModel) == "function" then
      pcall(block.model.ClearModel, block.model)
    end
    block.model:Hide()
  end
  -- No display id, no PlayerModel, or a call that raised: the creature's own portrait if the
  -- client will draw one, and the glyph for the kind of creature it is if it will not. Never an
  -- empty box.
  if block.glyph then
    local drawn = display and applyPortrait(block, display) or false
    if not drawn then
      local key = content.header and content.header.asset or nil
      local has = type(key) == "string" and (type(Assets.Has) ~= "function" or Assets.Has(key) == true)
      drawn = has and select(1, pcall(Assets.Apply, block.glyph, key)) or false
    end
    if drawn then
      block.glyph:Show()
      return InfoPanel.MODEL_H + InfoPanel.MODEL_GAP
    end
    block.glyph:Hide()
  end
  block.holder:Hide()
  return 0
end

-- Which diff table the root belongs to, so a hovered Changed badge can list the differences.
local function diffKindFor(content)
  if type(content.itemId) == "number" then
    return "items", content.itemId
  end
  if type(content.spellId) == "number" then
    if content.kind == "enchant" then
      return "enchants", content.spellId
    end
    return "recipes", content.spellId
  end
  return nil, nil
end

local function drawHeader(content, surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local header = content.header
  if frame.itemName then
    -- Brief P6b: an NPC's side icon rides after its name.
    setText(frame.itemName, header and InfoPanel.HeaderName(header) or nil)
    if header then
      nameColor(frame.itemName, header.quality, header.colorKey)
    end
  end
  drawHeaderMark(content, drawHeaderIcon(content, surface), surface)
  if frame.badges and type(frame.badges.SetKinds) == "function" then
    pcall(frame.badges.SetKinds, frame.badges, header and header.badges or {})
    -- Brief NW1: the header's own note (a quest's how-to note), which its Community note mark says
    -- when hovered; nil on every other header, so a reused cluster never keeps the last one.
    if type(frame.badges.SetNote) == "function" then
      pcall(frame.badges.SetNote, frame.badges, header and header.note or nil)
    end
    -- Round C gives badge clusters a subject, so hovering the Changed badge lists what moved.
    -- Called only where the cluster carries it: UI/Badges.lua owns whether it does.
    if type(frame.badges.SetSubject) == "function" then
      local kind, id = diffKindFor(content)
      pcall(frame.badges.SetSubject, frame.badges, kind, id)
    end
  end
end

-- modelHeight is what the creature page's model block took, and 0 for every other root: the first
-- fact row then starts under the model instead of under the header.
local function drawRows(entries, modelHeight, surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local pool = surface.rows
  local parent = frame.content or frame
  local width = paneWidth(surface)
  local block = (tonumber(modelHeight) or 0) > 0 and surface.modelBlock or nil
  local previous, height = nil, 0
  for index, entry in ipairs(entries) do
    local row = rowAt(index, surface)
    if not row then
      break
    end
    row:ClearAllPoints()
    row:SetPoint("LEFT", parent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if previous then
      row:SetPoint("TOP", previous, "BOTTOM", 0, 0)
    elseif block and block.holder then
      row:SetPoint("TOP", block.holder, "BOTTOM", 0, -InfoPanel.MODEL_GAP)
    elseif frame.rowAnchor then
      row:SetPoint("TOP", frame.rowAnchor, "BOTTOM", 0, 0)
    else
      row:SetPoint("TOP", parent, "TOP", 0, -HEADER_H)
    end
    -- The row answers its own height: a change row that wrapped and a wrapped paragraph are
    -- both taller than one line, and the row under them has to start below them.
    height = height + (tonumber(drawRow(row, entry, width)) or InfoPanel.RowHeight(entry.kind))
    row:Show()
    previous = row
  end
  for index = #entries + 1, #pool do
    pool[index]:Hide()
  end
  return HEADER_H + TIGHT + (tonumber(modelHeight) or 0) + height
end

-- One screen pixel in the column's own units, or nil where the client will not say. Shared with
-- the tooltip's divider rule since brief CS4 (Core/Util.lua Util.ScreenPixel, the same formula).
local screenPixel = ItemTree.Util.ScreenPixel

-- The thumb, and the clamp that keeps the column from scrolling past its own end. Called on
-- every redraw, because the content height is what decides both.
local function updateScroll(contentHeight, surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local pane = paneHeight(surface)
  local overflow = contentHeight - pane
  if overflow < 0 or pane <= 0 then
    overflow = 0
  end
  surface.overflow = overflow
  local offset = math.max(0, math.min(tonumber(surface.offset) or 0, overflow))
  surface.offset = offset
  if frame.scroll and type(frame.scroll.SetVerticalScroll) == "function" then
    pcall(frame.scroll.SetVerticalScroll, frame.scroll, offset)
  end
  if not frame.thumb then
    return
  end
  if overflow <= 0 then
    frame.thumb:Hide()
    return
  end
  local run = pane * (pane / contentHeight)
  local travel = (pane - run) * (offset / overflow)
  frame.thumb:ClearAllPoints()
  frame.thumb:SetHeight(math.max(run, ROW_HEIGHTS.fact))
  if frame.framed then
    frame.thumbInset = InfoPanel.ThumbInset(FRAME, screenPixel(frame))
  end
  frame.thumb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(frame.thumbInset or HAIRLINE), -INSET - travel)
  frame.thumb:Show()
end

-- Scrolls the column by pixels, clamped to what there is. False with no pane. surface is the
-- column to scroll, the window's own when left out.
function InfoPanel.Scroll(delta, surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  if not frame then
    return false
  end
  local overflow = tonumber(surface.overflow) or 0
  local offset = math.max(0, math.min((tonumber(surface.offset) or 0) + (tonumber(delta) or 0), overflow))
  if offset == surface.offset then
    return true
  end
  surface.offset = offset
  updateScroll(tonumber(surface.contentHeight) or 0, surface)
  return true
end

-- Follows the summary line at the foot of the column: the window opens the view that line
-- counted, and comes back to the Tree tab first where it was on the Chain tab, because the view
-- is what the tree draws. UI/Frame.lua is another file's, so every entry point is read through
-- a type check and pcall'd: a window that carries none of them costs the click and nothing
-- else. Takes a view key or, from the harness, a plain direction. Returns whether the window
-- was asked.
function InfoPanel.FollowLink(viewOrDirection)
  if viewOrDirection == nil then
    return false
  end
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) ~= "table" then
    return false
  end
  -- The window has three views over two directions. A window that carries SetView is told the
  -- view, which is what the row holds; one that only carries SetDirection is told the direction
  -- that view walks. Either way the argument may arrive as a view key or as a plain direction,
  -- because the harness still passes a direction.
  local edges = ItemTree.Edges
  local view, direction = nil, nil
  if type(edges) == "table" and type(edges.ViewDirection) == "function" then
    local ok, answer = pcall(edges.ViewDirection, viewOrDirection)
    if ok and type(answer) == "string" then
      view, direction = viewOrDirection, answer
    end
  end
  if not view then
    direction = viewOrDirection
    if type(edges) == "table" and type(edges.ViewOf) == "function" then
      local ok, answer = pcall(edges.ViewOf, viewOrDirection)
      if ok and type(answer) == "string" then
        view = answer
      end
    end
  end
  local setView = type(frame.SetView) == "function" and view ~= nil
  if not setView and type(frame.SetDirection) ~= "function" then
    return false
  end
  if type(frame.SelectTab) == "function" then
    local tab = nil
    if type(frame.Tab) == "function" then
      local ok, current = pcall(frame.Tab)
      if ok then
        tab = current
      end
    end
    if tab ~= "Tree" then
      pcall(frame.SelectTab, "Tree")
    end
  end
  if setView then
    return (pcall(frame.SetView, view))
  end
  return (pcall(frame.SetDirection, direction))
end

-- Re roots the one window on a node this column named: a reward, an item that only drops on a
-- quest, anything a row carries a key for. This never opens a second window, exactly as
-- UI/History.lua's own row does not.
--
-- UI/Frame.lua is another file's, so it is looked up at call time and pcall'd: a window that
-- carries no entry point costs the click and nothing else. Frame.OpenPicked is asked for first
-- for the same reason the history list asks for it, because a click in the info column is a jump
-- to a thing rather than a step through the graph, so the window lands on its Tree tab. Returns
-- whether the window was asked.
--
-- E64: restore = false, because this is a jump FORWARD. Frame.OpenPicked with nothing else to
-- say counts as a return (brief E61), since Recently viewed reaches the window through it, and
-- a link in this column is the opposite of that: the player has never asked for that page back,
-- they have just pointed at a reward and asked to see it. So it starts fresh, the way the search
-- dropdown and the dice do. Frame.Open honours the same option, so the fall back agrees.
function InfoPanel.OpenNode(key)
  if type(key) ~= "string" or key == "" then
    return false
  end
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  if type(frame) ~= "table" or type(frame.Open) ~= "function" then
    return false
  end
  local open = frame.Open
  if type(frame.OpenPicked) == "function" then
    open = frame.OpenPicked
  end
  return (pcall(open, key, { restore = false }))
end

-- Asks the client once for whatever the column wanted and could not have: the real stats for
-- an item the client has not loaded yet, and a spell's own text. One ask per id for the life
-- of the session, so the redraw the answer triggers can never ask again and loop, and the
-- redraw only happens where the window is still on the root that asked.
local function requestMissing(content)
  if type(content) ~= "table" then
    return false
  end
  local asked = InfoPanel.asked
  if type(asked) ~= "table" then
    asked = {}
    InfoPanel.asked = asked
  end
  local root = InfoPanel.root

  local function askOnce(key, request, id)
    if asked[key] or type(request) ~= "function" or type(id) ~= "number" then
      return false
    end
    asked[key] = true
    local ok, made = pcall(request, id, function()
      if InfoPanel.frame and InfoPanel.root == root then
        InfoPanel.Refresh()
      end
    end)
    return ok and made == true
  end

  local made = false
  if content.wantsStats and type(content.itemId) == "number" then
    made = askOnce("stats:" .. tostring(content.itemId), ItemTree.RequestItemData, content.itemId) or made
  end
  -- Brief D5: the one live check a withheld item's page makes. Core/RealmCheck.lua remembers every
  -- id it has asked about for the session, so this redraw, the answer's redraw and any later visit
  -- ask nothing more. The first time it moves the page on (to "Checking your realm", or straight
  -- to found where the client already holds the item) the page is drawn once more to say so.
  local check = ItemTree.RealmCheck
  if content.realmCheck and type(content.itemId) == "number" and type(check) == "table" then
    local id = content.itemId
    local before = moduleCall(check, "State", id)
    local now = moduleCall(check, "Start", id, function()
      if InfoPanel.frame and InfoPanel.root == root then
        InfoPanel.Refresh()
      end
    end)
    if before == nil and now ~= nil then
      made = true
      if InfoPanel.frame and InfoPanel.root == root then
        InfoPanel.Refresh()
      end
    end
  end
  if content.wantsDescription and type(content.spellId) == "number" then
    made = askOnce("spell:" .. tostring(content.spellId), ItemTree.RequestSpellData, content.spellId) or made
  end
  return made
end

-- The client's own tooltip for whatever the header names, which ItemTree's tooltip hook then
-- appends its block to, so the header reads exactly as a row in the tree does. SetItemByID and
-- SetSpellByID are the modern calls and the hyperlink is the older one; a client that carries
-- neither gets the panel's own name line rather than an empty frame.
local function setClientItem(tooltip, itemId)
  if type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, itemId) then
    return true
  end
  if type(tooltip.SetHyperlink) == "function" then
    return pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(itemId)) and true or false
  end
  return false
end

local function setClientSpell(tooltip, spellId)
  if type(tooltip.SetSpellByID) == "function" and pcall(tooltip.SetSpellByID, tooltip, spellId) then
    return true
  end
  if type(tooltip.SetHyperlink) == "function" then
    return pcall(tooltip.SetHyperlink, tooltip, "spell:" .. tostring(spellId)) and true or false
  end
  return false
end

-- Our own lines under a tooltip's title, in the colours the rows were written in. A line with a
-- value on the right is drawn as a double line where the client carries one and as a single
-- line where it does not. Guarded end to end: a client that will not take a line leaves the
-- header showing its title alone.
local function addOwnLines(tooltip, lines)
  if type(tooltip) ~= "table" or type(lines) ~= "table" then
    return false
  end
  local added = false
  for _, line in ipairs(lines) do
    local text = line.text
    if type(text) == "string" and text ~= "" then
      local r, g, b = themeColor(line.colorKey or COLOR_BODY)
      if not r then
        r, g, b = 1, 1, 1
      end
      -- Brief TB1: a line's own colour (the Keep head's) wins over its key.
      if type(line.color) == "table" and tonumber(line.color.r) then
        r, g, b = line.color.r, line.color.g, line.color.b
      end
      -- Brief TV4: the value on the right in a colour of its own where the line names one.
      local rr, rg, rb = r, g, b
      if line.rightColorKey then
        local cr, cg, cb = themeColor(line.rightColorKey)
        if cr then
          rr, rg, rb = cr, cg, cb
        end
      end
      if line.right ~= nil and type(tooltip.AddDoubleLine) == "function" then
        if pcall(tooltip.AddDoubleLine, tooltip, text, tostring(line.right), r, g, b, rr, rg, rb) then
          added = true
        end
      elseif type(tooltip.AddLine) == "function" then
        if line.right ~= nil then
          text = text .. " " .. tostring(line.right)
        end
        if pcall(tooltip.AddLine, tooltip, text, r, g, b, true) then
          added = true
        end
      end
    end
  end
  return added
end

--- Brief TV4: the same drawing for a caller outside this file (UI/Tree.lua's quest rows), lines as
--- InfoPanel.QuestTooltipLines answers them. Answers whether any line went on.
function InfoPanel.AddTooltipLines(tooltip, lines)
  return addOwnLines(tooltip, lines)
end

-- E6: a left click on the header of an item page, with the client's dress up or chat link
-- modifier, goes to UI/ItemClick.lua for the page's own item. Answers true when the client took
-- it. A plain click, any other button and any page that is not an item (a creature, a spell, a
-- quest) do nothing at all, which is what the header has always done with a click.
function InfoPanel.HeaderClick(button, surface)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local itemId = InfoPanel.itemId
  if surface ~= nil and surface ~= InfoPanel then
    local content = type(surface) == "table" and surface.content or nil
    itemId = type(content) == "table" and content.itemId or nil
  end
  if type(itemId) ~= "number" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.Handle) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.Handle, itemId)
  return ok and handled == true
end

-- Brief BQ28 (owner QA 2026-10-10 items 56 and 80): the header's tooltip has its corner on the
-- header icon's (UI/Compare.lua Compare.OwnIcon, the bag slot's rule), not on the column wide hit
-- frame, whose far top right corner is where the comparison manager's re-anchor put BQ25b's.
-- ANCHOR_RIGHT where Compare is not loaded. Answers whether it was owned.
function InfoPanel.OwnHeaderTooltip(tooltip, owner, frame)
  local Compare = ItemTree.Compare
  if type(Compare) == "table" and type(Compare.OwnIcon) == "function" then
    local ok, owned = pcall(Compare.OwnIcon, tooltip, owner, rawget(frame, "icon"))
    if ok and owned then
      return true
    end
  end
  return (pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT"))
end

-- The root's own tooltip, on hovering the icon and name at the top of the column. Guarded end
-- to end: a client with no GameTooltip simply shows nothing.
function InfoPanel.ShowHeaderTooltip(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local content = surface.content
  local tooltip = rawget(_G, "GameTooltip")
  if not frame or type(content) ~= "table" then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  local owner = frame.headerHit or frame
  if not InfoPanel.OwnHeaderTooltip(tooltip, owner, frame) then
    return false
  end
  -- Brief BQ25a (QA item 72): Ctrl unfolds the uses here too (UI/Tooltip.lua RedrawOnModifier).
  local tip = ItemTree.Tooltip
  if type(tip) == "table" and type(tip.RedrawOnModifier) == "function" then
    tip.RedrawOnModifier(owner, InfoPanel.ShowHeaderTooltip, surface)
  end
  local shown = false
  if type(content.itemId) == "number" then
    shown = setClientItem(tooltip, content.itemId)
  elseif type(content.spellId) == "number" and content.kind ~= "enchant" then
    shown = setClientSpell(tooltip, content.spellId)
  end
  if not shown then
    local header = content.header
    local name = type(header) == "table" and header.name or nil
    if type(name) ~= "string" or name == "" or type(tooltip.SetText) ~= "function" then
      if type(tooltip.Hide) == "function" then
        pcall(tooltip.Hide, tooltip)
      end
      return false
    end
    pcall(tooltip.SetText, tooltip, name)
    -- Brief P6b: the word the side icon beside the name stands for.
    local side = InfoPanel.SideWord(header.side)
    if side then
      addOwnLines(tooltip, { { text = side, colorKey = COLOR_BODY } })
    end
    -- Classic has no client tooltip for a quest id at all, so a quest header hover is our own
    -- lines and nothing else: what it needs, what starts it, what it gives.
    if content.kind == "quest" then
      addOwnLines(tooltip, InfoPanel.QuestTooltipLines(content))
    end
  end
  -- E44: what the chest in the corner of the header icon means, on every hover, under whichever
  -- block was drawn above it, the client's own item tooltip included. This is the one place the
  -- column writes the sentence, and ItemTree's block (UI/Tooltip.lua) never writes it at all, so
  -- it can never land twice.
  local marked = InfoPanel.MarkText(content)
  if marked then
    addOwnLines(tooltip, { { text = marked, colorKey = COLOR_MUTED } })
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  -- Brief BQ28: below the icon where the filled tooltip would run off the top of the screen.
  local Compare = ItemTree.Compare
  if type(Compare) == "table" and type(Compare.FitIcon) == "function" then
    pcall(Compare.FitIcon, tooltip)
  end
  return true
end

--- E44: the chest's own hover, raised from the small target over the mark itself. One line, the
--- sentence, and nothing else: the player is pointing at a 14px glyph and asking what it is, not
--- at the item.
function InfoPanel.ShowMarkTooltip(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  local text = InfoPanel.MarkText(surface.content)
  local tooltip = rawget(_G, "GameTooltip")
  if not frame or not text then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if not pcall(tooltip.SetOwner, tooltip, frame.markHit or frame, "ANCHOR_RIGHT") then
    return false
  end
  if not addOwnLines(tooltip, { { text = text, colorKey = COLOR_TITLE } }) then
    if type(tooltip.Hide) == "function" then
      pcall(tooltip.Hide, tooltip)
    end
    return false
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

function InfoPanel.HideHeaderTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.Hide) ~= "function" then
    return false
  end
  return (pcall(tooltip.Hide, tooltip))
end

-- A row copied without the parts that lead somewhere. A surface that is not the window's column
-- (the Boss loot tab's creature panel) has no root of its own for a summary line to open a view
-- of, and no window to re root, so its rows are words and nothing else.
local function plainEntries(entries)
  local out = {}
  for index, entry in ipairs(entries) do
    if type(entry) == "table" and (entry.link ~= nil or entry.node ~= nil) then
      local copy = {}
      for key, value in pairs(entry) do
        copy[key] = value
      end
      copy.link, copy.node = nil, nil
      out[index] = copy
    else
      out[index] = entry
    end
  end
  return out
end

--- Brief BL8: draws one content table (what InfoPanel.CreatureContent, InfoPanel.Content and the
--- rest answer) into a surface: the header, the creature's one model where the content is a
--- creature (cleared for anything else), and the rows under them, then the scroll clamp. The
--- window's column is the surface when it is left out, and InfoPanel.Refresh is that call;
--- InfoPanel.NewSurface makes another. The Recipe card and the client data requests belong to the
--- window's column alone. Answers whether it drew.
function InfoPanel.DrawContent(content, surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  if not frame then
    return false
  end
  local window = surface == InfoPanel
  if not window and type(content) ~= "table" then
    return false
  end
  surface.content = content
  surface.paneWidth = paneWidth(surface)
  if frame.content then
    frame.content:SetWidth(surface.paneWidth)
  end
  drawHeader(content, surface)
  -- E57: the creature page's one model sits between the header and the facts, and is cleared for
  -- every other kind of root, so no model is left rendering behind an item's column.
  local modelHeight = drawCreatureModel(content, surface)
  -- E25: the Recipe card goes last, under everything the root itself said, so the facts above it
  -- never move as the pointer travels down the tree.
  local entries = drawEntries(content)
  if window then
    entries = appendRecipeEntries(entries)
  else
    entries = plainEntries(entries)
  end
  local height = drawRows(entries, modelHeight, surface)
  surface.contentHeight = height
  if frame.content then
    frame.content:SetHeight(height)
  end
  updateScroll(height, surface)
  frame:Show()
  return true
end

--- Brief BL8: a column of its own inside any region, drawn by the same builders as the window's:
--- the frame and its fill, the header, the one model block, the row pool and the scroll. Answers
--- the surface, which InfoPanel.DrawContent and InfoPanel.ClearSurface take, or nil with no client.
--- Nothing is drawn and no model is made until DrawContent is handed a creature.
---
---   { region, frame, rows, modelBlock, offset, overflow, contentHeight, paneWidth, content }
function InfoPanel.NewSurface(region)
  if type(region) ~= "table" then
    return nil
  end
  local surface = { region = region, rows = {}, offset = 0 }
  local frame = buildPanel(region, surface)
  if not frame then
    return nil
  end
  surface.frame = frame
  return surface
end

--- Brief BL8: takes a surface down: its model cleared and hidden, and its frame hidden. What was
--- drawn is let go of too. Idempotent; false for no surface.
function InfoPanel.ClearSurface(surface)
  if type(surface) ~= "table" then
    return false
  end
  InfoPanel.ClearModel(surface)
  surface.content = nil
  surface.offset = 0
  local frame = surface.frame
  if frame and type(frame.Hide) == "function" then
    frame:Hide()
  end
  return true
end

--- Brief CT1b: whether two values are the same all the way down: two tables key by key, anything
--- else by ==, so a function or a frame is the same only where it is the one value. A nesting past
--- 16 deep reads as different. Pure.
function InfoPanel.SameValue(a, b, depth)
  if a == b then
    return true
  end
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  depth = (depth or 0) + 1
  if depth > 16 then
    return false
  end
  for key, value in pairs(a) do
    if not InfoPanel.SameValue(value, b[key], depth) then
      return false
    end
  end
  for key in pairs(b) do
    if a[key] == nil then
      return false
    end
  end
  return true
end

--- Brief CT1b (QA item 227): what the window's column is about to draw for an NPC's page, as the
--- record InfoPanel.Refresh compares with the last one drawn: the root, the content, the column's
--- width, the Recipe card, the player's target (the model's live source, InfoPanel.ModelSources)
--- and whether the column is up. nil for any other page, which draws every time as it always has
--- (an item's icon, for one, is the client's at draw time and in no content).
function InfoPanel.DrawnState(content)
  if type(content) ~= "table" or (content.kind ~= "creature" and content.kind ~= "npc") then
    return nil
  end
  local frame = InfoPanel.frame
  local shown = false
  if frame and type(frame.IsShown) == "function" then
    local ok, answer = pcall(frame.IsShown, frame)
    shown = ok and answer == true
  end
  return {
    root = InfoPanel.root,
    content = content,
    width = paneWidth(InfoPanel),
    recipe = InfoPanel.recipe,
    target = InfoPanel.TargetGuid(),
    shown = shown,
  }
end

-- Redraws the last root. False with no client, or before the window attached the pane.
--
-- Brief CT1b (QA item 227): every refresh of the window (a tab press, a level filter, a row opened)
-- handed the column its root again, and it was drawn whole each time, the model put on again with
-- it: 28 draws at about 7.5 ms each on the owner's PC over three trainer pages. An NPC's page that
-- would draw exactly what is up already (InfoPanel.DrawnState) is left as it is, and only the scroll
-- is put where the draw would have put it (InfoPanel.Show starts it at the top). Anything that takes
-- the model down (InfoPanel.ClearModel: the window closing, the column hidden) forgets the record.
function InfoPanel.Refresh()
  if not InfoPanel.frame then
    return false
  end
  local content = InfoPanel.ContentForKey(InfoPanel.root, InfoPanel.showChanges)
  local state = InfoPanel.DrawnState(content)
  if state and state.shown and InfoPanel.SameValue(InfoPanel.drawn, state) then
    updateScroll(tonumber(InfoPanel.contentHeight) or 0, InfoPanel)
    requestMissing(content)
    return true
  end
  InfoPanel.drawn = nil
  InfoPanel.DrawContent(content, InfoPanel)
  if state then
    state.shown = true
    InfoPanel.drawn = state
  end
  requestMissing(content)
  return true
end

-- Re roots the pane on a ViewModel node key and redraws. The window passes the key string
-- ("item:2835", "spell:7411"); a bare item id is taken as an item root, which is what the
-- older callers hand over. An unknown key draws the empty notice rather than raising, and with
-- no client this is a no op.
function InfoPanel.Show(rootKey)
  InfoPanel.root = rootKey
  InfoPanel.key = rootKey
  -- E25: a new root is a new tree, so whatever craft the pointer was over is gone with it.
  InfoPanel.recipe = nil
  local kind, id = InfoPanel.Root(rootKey)
  InfoPanel.itemId = nil
  InfoPanel.spellId = nil
  InfoPanel.questId = nil
  if kind == "item" then
    InfoPanel.itemId = id
  elseif kind == "spell" or kind == "enchant" then
    InfoPanel.spellId = id
  elseif kind == "quest" then
    InfoPanel.questId = id
  end
  InfoPanel.offset = 0
  return InfoPanel.Refresh()
end

function InfoPanel.Hide()
  -- E57: the creature page's model goes down with the column, so nothing keeps rendering behind a
  -- pane nobody can see.
  InfoPanel.ClearModel()
  local frame = InfoPanel.frame
  if not frame or type(frame.Hide) ~= "function" then
    return false
  end
  frame:Hide()
  return true
end

-- The window widened this column from 150 to 225, took it to 180 (E77) and may move it again,
-- so every draw reads the region's real width and this is what redraws when it changes. Only on
-- a real change, and never while a redraw is already running: a redraw resizes the scroll
-- child, and a client that reports that back as another size change would otherwise loop. A
-- hidden pane is left alone, because Refresh shows what it draws.
function InfoPanel.OnSizeChanged(surface)
  surface = surfaceOf(surface)
  local frame = surface.frame
  if not frame or surface.resizing then
    return false
  end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and shown == false then
      return false
    end
  end
  local width = paneWidth(surface)
  if width == surface.paneWidth then
    return false
  end
  surface.paneWidth = width
  surface.resizing = true
  local ok
  if surface == InfoPanel then
    ok = pcall(InfoPanel.Refresh)
  else
    ok = pcall(InfoPanel.DrawContent, surface.content, surface)
  end
  surface.resizing = false
  return ok
end

-- The window's "Show classic diff" tick box. On, a changed field reads old to new; off, every
-- field is this build's value and no change row is drawn. In memory only, and the window is
-- the one that remembers it. Returns the state the panel is now in.
function InfoPanel.SetShowChanges(show)
  local on = show and true or false
  if InfoPanel.showChanges ~= on then
    InfoPanel.showChanges = on
    InfoPanel.Refresh()
  end
  return on
end

--------------------------------------------------------------------------------
-- What the client knows about one quest (brief Q8)
--------------------------------------------------------------------------------

-- One function off a client table, pcall'd, answering every value, or nothing where the table or
-- the function is missing or the call raised.
local function passAll(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function apiCall(api, name, ...)
  if type(api) ~= "table" or type(api[name]) ~= "function" then
    return nil
  end
  return passAll(pcall(api[name], ...))
end

-- One global function, the same way.
local function globalCall(name, ...)
  return apiCall(_G, name, ...)
end

-- The item id a quest log link names, or nil.
local linkItemId = ItemTree.Util.ItemIdFromLink

-- A zone map's own name, out of C_Map.GetMapInfo, or nil.
local function mapInfoName(mapId)
  if type(mapId) ~= "number" or mapId <= 0 then
    return nil
  end
  local info = apiCall(rawget(_G, "C_Map"), "GetMapInfo", mapId)
  if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
    return info.name
  end
  return nil
end

-- The rewards the quest log lists for one quest, by id: GetNumQuestLogRewards(questId) and
-- GetNumQuestLogChoices(questId) count them, GetQuestLogRewardInfo(index, questId) answers the
-- fixed ones (the item id its sixth value, the count its third) and GetQuestLogItemLink(kind,
-- index, questId) names each one the info call does not. Only the quest id shape is used: the
-- Forever client is retail shaped, where the id is taken, and the id free shape reads whichever
-- quest the log has selected, which is not this one.
local function logRewards(questId)
  local out, seen = {}, {}
  for _, spec in ipairs({
    { kind = "reward", count = "GetNumQuestLogRewards", info = "GetQuestLogRewardInfo" },
    { kind = "choice", count = "GetNumQuestLogChoices" },
  }) do
    local total = math.min(tonumber((globalCall(spec.count, questId))) or 0, 10)
    for index = 1, total do
      local itemId, count = nil, nil
      if spec.info then
        local _, _, numItems, _, _, id = globalCall(spec.info, index, questId)
        itemId, count = positive(id), positive(numItems)
      end
      itemId = itemId or linkItemId(globalCall("GetQuestLogItemLink", spec.kind, index, questId))
      if itemId and not seen[itemId] then
        seen[itemId] = true
        out[#out + 1] = { itemId = itemId, count = count, choice = spec.kind == "choice" }
      end
    end
  end
  return out
end

-- The objectives C_QuestLog.GetQuestObjectives(questId) states: { text, have, need, done }.
local function logObjectives(questLog, questId)
  local out = {}
  local list = apiCall(questLog, "GetQuestObjectives", questId)
  for _, objective in ipairs(type(list) == "table" and list or {}) do
    if type(objective) == "table" then
      out[#out + 1] = {
        text = objective.text,
        have = tonumber(objective.numFulfilled),
        need = tonumber(objective.numRequired),
        done = objective.finished == true,
      }
    end
  end
  return out
end

-- The zone the client puts one quest in, and which call said so: GetQuestUiMapID(questId) first
-- (the call the Forever branch's own Mainline QuestMapFrame.lua uses), then
-- C_QuestLog.GetQuestAdditionalHighlights(questId), whose first value is a uiMap id too. nil, nil
-- where neither answers a map.
local function questMap(questLog, questId)
  local mapId = positive((globalCall("GetQuestUiMapID", questId)))
  if mapId then
    return mapId, "GetQuestUiMapID"
  end
  mapId = positive((apiCall(questLog, "GetQuestAdditionalHighlights", questId)))
  if mapId then
    return mapId, "GetQuestAdditionalHighlights"
  end
  return nil, nil
end

--- What the client says about ONE quest, for ViewModel.QuestLive to keep for the session. Every
--- call is about this quest id alone, pcall'd, and nothing is asked for any other quest:
---
---   always          C_QuestLog.IsOnQuest, C_QuestLog.IsQuestFlaggedCompleted,
---                   C_QuestLog.GetTitleForQuestID, GetQuestUiMapID (then
---                   C_QuestLog.GetQuestAdditionalHighlights where that answers no map), and
---                   C_Map.GetMapInfo once per distinct map (the quest's and the player's records')
---   in the log      C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo (the level),
---                   C_QuestLog.GetQuestObjectives, GetNumQuestLogRewards, GetNumQuestLogChoices,
---                   one GetQuestLogRewardInfo or GetQuestLogItemLink per reward, and
---                   QuestPOIGetIconInfo for the objective's mark
---
--- So a quest not in the log costs five to seven calls and one in the log about fifteen, once per
--- session, and again only after the log says that quest moved. mapIds are the maps the player's
--- own records name, so their zones are named in the same pass.
function InfoPanel.ReadQuest(questId, mapIds)
  if type(questId) ~= "number" or questId <= 0 then
    return nil
  end
  local questLog = rawget(_G, "C_QuestLog")
  local live = { mapNames = {} }
  live.onQuest = apiCall(questLog, "IsOnQuest", questId) == true
  if not live.onQuest then
    live.completed = apiCall(questLog, "IsQuestFlaggedCompleted", questId) == true
  end
  local title = apiCall(questLog, "GetTitleForQuestID", questId)
  if type(title) == "string" and title ~= "" then
    live.title = title
  end
  if live.onQuest then
    local index = apiCall(questLog, "GetLogIndexForQuestID", questId)
    local info = type(index) == "number" and apiCall(questLog, "GetInfo", index) or nil
    if type(info) == "table" then
      live.level = positive(info.level)
      if not live.title and type(info.title) == "string" and info.title ~= "" then
        live.title = info.title
      end
    end
    live.objectives = logObjectives(questLog, questId)
    live.rewards = logRewards(questId)
  end
  live.mapId, live.zoneFrom = questMap(questLog, questId)
  if live.onQuest and live.mapId then
    local _, x, y = globalCall("QuestPOIGetIconInfo", questId)
    x, y = tonumber(x), tonumber(y)
    if x and y and x > 0 and y > 0 and x <= 1 and y <= 1 then
      live.poi = { mapId = live.mapId, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
    end
  end
  local wanted = { live.mapId }
  for _, mapId in ipairs(type(mapIds) == "table" and mapIds or {}) do
    wanted[#wanted + 1] = mapId
  end
  for _, mapId in pairs(wanted) do
    if type(mapId) == "number" and live.mapNames[mapId] == nil then
      live.mapNames[mapId] = mapInfoName(mapId) or false
    end
  end
  for mapId, name in pairs(live.mapNames) do
    if name == false then
      live.mapNames[mapId] = nil
    end
  end
  live.zone = live.mapId and live.mapNames[live.mapId] or nil
  return live
end

-- Installed at load: Core asks the client through this seam and nowhere else.
do
  local viewModel = ItemTree.ViewModel
  if type(viewModel) == "table" then
    viewModel.questReader = InfoPanel.ReadQuest
  end
end

-- The quest id a quest event names: QUEST_ACCEPTED hands over the id alone on the retail shaped
-- client and the log index then the id on Classic Era, QUEST_REMOVED and QUEST_TURNED_IN the id
-- first. The last whole number wins for the first, the first for the others. Pure.
function InfoPanel.QuestEventId(event, first, second)
  local questId
  if event == "QUEST_ACCEPTED" then
    questId = tonumber(second) or tonumber(first)
  else
    questId = tonumber(first)
  end
  if not questId or questId <= 0 then
    return nil
  end
  return questId
end

-- Brief Q8: forgets what the client said about the quests a quest event moved, and redraws the
-- window where it is on one of them. QUEST_LOG_UPDATE names no quest, so it forgets every quest
-- kept while it was in the log (their progress may have moved) and nothing else; the three events
-- that name a quest forget that one. Answers whether the open quest was forgotten.
function InfoPanel.OnQuestEvent(event, ...)
  local viewModel = ItemTree.ViewModel
  if type(viewModel) ~= "table" or type(viewModel.DropQuestLive) ~= "function" then
    return false
  end
  local dropped = {}
  if event == "QUEST_LOG_UPDATE" then
    for questId, live in pairs(viewModel.questLive or {}) do
      if type(live) == "table" and live.onQuest == true then
        dropped[#dropped + 1] = questId
      end
    end
  else
    dropped[1] = InfoPanel.QuestEventId(event, ...)
  end
  local open = false
  for _, questId in ipairs(dropped) do
    pcall(viewModel.DropQuestLive, questId)
    if questId == InfoPanel.questId then
      open = true
    end
  end
  if open then
    InfoPanel.RedrawQuest()
  end
  return open
end

-- Draws the open quest again, once, a moment after the log settles: QUEST_LOG_UPDATE comes in
-- bursts, and each redraw asks the client about that one quest again.
function InfoPanel.RedrawQuest()
  if InfoPanel.questRedrawPending then
    return false
  end
  local function redraw()
    InfoPanel.questRedrawPending = false
    if not InfoPanel.questId then
      return
    end
    local ui = ItemTree.UI
    local frame = type(ui) == "table" and ui.Frame or nil
    if type(frame) == "table" and type(frame.IsShown) == "function" and frame.IsShown() then
      local vm = frame.vm
      if type(vm) == "table" and type(vm.SetOptions) == "function" then
        pcall(vm.SetOptions, vm, {})
      end
      if type(frame.Refresh) == "function" then
        pcall(frame.Refresh)
      end
    end
    pcall(InfoPanel.Refresh)
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    InfoPanel.questRedrawPending = true
    if pcall(timer.After, 0.25, redraw) then
      return true
    end
    InfoPanel.questRedrawPending = false
  end
  redraw()
  return true
end

InfoPanel.QUEST_EVENTS = { "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }

-- The event frame, made once at load where the client can make one.
do
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) == "function" then
    local ok, frame = pcall(createFrame, "Frame")
    if ok and type(frame) == "table" and type(frame.RegisterEvent) == "function" then
      for _, event in ipairs(InfoPanel.QUEST_EVENTS) do
        pcall(frame.RegisterEvent, frame, event)
      end
      if type(frame.SetScript) == "function" then
        pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
          pcall(InfoPanel.OnQuestEvent, event, ...)
        end)
      end
      InfoPanel.questEvents = frame
    end
  end
end

-- The window owns the pane's frame, so there is nothing to build at load. Every panel carries
-- an Init and UI/Frame.lua calls it.
function InfoPanel.Init() end

return InfoPanel
