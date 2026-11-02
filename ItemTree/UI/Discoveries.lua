-- The Discoveries tab: what this client has watched the realm discover, and what a new data
-- build newly names, as one list newest first.
--
-- Note the two names. ItemTree.Discoveries (Core/Discoveries.lua) is the model: the merge, the
-- date bands, the search predicate and the counts, all pure. ItemTree.UI.Discoveries, this file,
-- is the pane that draws it.
--
-- Design: the left pane of docs/ideas/sealed-tab.md, built as a tab of its own. The whole
-- withheld set, the right pane of that proposal, is not built and is parked there as a possible
-- future phase.
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_CHROME_TAB_H 24 the source tab row across the top, carrying the search box at
--   ITEMTREE_CONTROL_H_MD 24, ITEMTREE_CONTROL_H_SM 20 for the column header row and the count
--   line, ITEMTREE_LIST_ROW_H 22 item rows, ITEMTREE_LIST_CATEGORY_H 24 band headers,
--   ITEMTREE_LIST_ICON 20 item icon, ITEMTREE_LIST_COL_COUNT 36 the "When" column,
--   ITEMTREE_LIST_COL_RATE 56 the least the "Source" column is drawn at, ITEMTREE_SCROLLBAR_W
--   16 for the bar.
--
-- Row one is the window's own view tab row, borrowed: four tabs, "All", "By you", "On your
-- realm" and "New data", each wearing its count, and the search box on the same row taking
-- whatever they leave. UI/Frame.lua lends the builder and the painter (Frame.BuildViewTab and
-- Frame.PaintViewTab, laid out with Frame.ViewRowFit), so this row and the window's own cannot
-- drift apart; a build whose window has neither draws plain buttons of its own instead.
--
-- Everything under row one is inset the same on the right as on the left: the column header and
-- the list panel span the whole pane rather than stopping where the search box does, so the gap
-- to the window's border is the same on both sides. The scroll bar sits inside that edge.
--
-- The columns are Item, Source, When, and then the badge column at the right hand end, which is
-- where a tree row keeps its own. A row wears the same New and Changed medallions the tree, the
-- sidebar and the search dropdown draw on that item, from the same Core/Diff.lua through
-- Core/Discoveries.lua (row.badges), drawn with UI/Badges.lua and carrying the same tooltip on
-- hover. The window's two badge toggles reach them through the options every draw reads, so
-- turning New off in the header empties the column here as well. The column is reserved whether
-- or not a row wears anything, so the words beside it never shuffle.
--
-- The tabs narrow the list to one of three things: the player obtained the item, somebody else
-- on the realm found it and this client can now name it, or a newer data build names it. The
-- Source column (brief E79) says who saw it: the character's name for the player's own record
-- ("You" for an old one), "ItemTree" for the shipped data and "Discovery Miner" for the owner's
-- miner, and the row's tooltip says which of the three things happened. The When column is when
-- ItemTree first saw the item, and one info line over the list says so. Core/Discoveries.lua
-- words all of it. The character's name is drawn on the row and its tooltip and nowhere else.
--
-- Client APIs: ScrollBox with CreateScrollBoxListLinearView plus CreateDataProvider, with a
-- plain frame pool where the client carries none of them, exactly as UI/Tree.lua and
-- UI/History.lua do. GameTooltip:SetItemByID for a hovered row, C_Timer.After to debounce the
-- search box, Assets.Apply for every texture. Every one of them is guarded, and this file loads
-- under busted with no WoW API at all.
--
-- HARD RULE, and tests/spec/ui_discoveries_spec.lua is the guard: this pane never asks the
-- client about an item. No GetItemInfo, no GetItemInfoInstant, no RequestLoadItemDataByID, not
-- while the list is built, filtered or drawn. Names come from the collector's own records and
-- the shipped data (Core/Discoveries.lua), icons from the data's own file ids. The one client
-- call about an item is GameTooltip:SetItemByID for the single row under the cursor, which is
-- what the player asked for by hovering it, and it is never made for a list.
--
-- Privacy: nothing about the character, the realm or the account is read, drawn or stored. The
-- wording says "on your realm" and never names one, and MarkSeen writes a timestamp and nothing
-- else.
--
-- Contract with UI/Frame.lua, which owns the window:
--   Frame calls Attach(region) once with the region it created and sized, then Show() whenever
--   the Discoveries tab is selected (it is handed the window's root key, which this pane has no
--   use for and ignores). Refresh() redraws, Hide() hides the pane, Init() stays a no op.
--   UnseenCount() is the number on the bubble over the tab. The pane marks itself seen when the
--   player leaves it (Hide, or the region's own OnHide, which fires on a tab switch and on the
--   window closing), never when it opens: what arrived since the previous look wears a NEW! tag
--   for the whole of this one. All idempotent, and all no ops with no client. A click on a row opens that item through
--   ItemTree.UI.Frame.Open and then ItemTree.UI.Frame.SelectTab("Tree"), both looked up lazily
--   and both guarded.
--
-- UIDiscoveries.RowHeight, UIDiscoveries.ListHeight, UIDiscoveries.Overflows,
-- UIDiscoveries.SourceColumnWidth, UIDiscoveries.BadgeOverhang, UIDiscoveries.BadgeColumnWidth,
-- UIDiscoveries.BadgeInset, UIDiscoveries.TabLabel, UIDiscoveries.TabCount,
-- UIDiscoveries.PlaceholderText, UIDiscoveries.Interpret, UIDiscoveries.WhenSamples,
-- UIDiscoveries.WhenColumnWidth and UIDiscoveries.NewTagCentre are pure and run under busted.
-- Everything below the divider touches frames and is guarded.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local UIDiscoveries = {}
ItemTree.UI.Discoveries = UIDiscoveries

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

-- Theme loads before this file, but every size is read through a fallback anyway so the module
-- still loads if it is ever asked for on its own.
local size = Theme.Size

UIDiscoveries.ROW_H = size("ITEMTREE_LIST_ROW_H", 22)
UIDiscoveries.HEADER_H = size("ITEMTREE_LIST_CATEGORY_H", 24)
UIDiscoveries.ICON_SIZE = size("ITEMTREE_LIST_ICON", 20)
UIDiscoveries.SEARCH_H = size("ITEMTREE_CONTROL_H_MD", 24)
UIDiscoveries.COLUMN_H = size("ITEMTREE_CONTROL_H_SM", 20)
UIDiscoveries.FOOTER_H = size("ITEMTREE_CONTROL_H_SM", 20)
UIDiscoveries.SEARCH_ICON = size("ITEMTREE_ICON_TOGGLE", 12)
UIDiscoveries.GUTTER = size("ITEMTREE_LIST_GUTTER", 6)
UIDiscoveries.PAD = size("ITEMTREE_SPACE_1", 4)
UIDiscoveries.EDGE_W = size("ITEMTREE_BORDER_HAIRLINE", 1)
UIDiscoveries.SCROLLBAR_W = size("ITEMTREE_SCROLLBAR_W", 16)
-- The least the When column is drawn at. The column is measured from the longest word it can
-- carry, which is "just now" (Core/History.lua's History.Ago answers that, "59m", "23h" or a
-- count of days), so the token is only the floor under that. At 36 px "just now" was cut to
-- "just n...".
UIDiscoveries.WHEN_W = size("ITEMTREE_LIST_COL_COUNT", 36)
UIDiscoveries.whenW = UIDiscoveries.WHEN_W
-- The least the Source column is drawn at. The column is sized from its own widest word
-- (Discoveries.WhoSamples) where the client will measure one, and this is the floor under that.
UIDiscoveries.HOW_W = size("ITEMTREE_LIST_COL_RATE", 56)
UIDiscoveries.howW = UIDiscoveries.HOW_W
-- The sparkly NEW! beside the name of a row the player has not seen yet. The client's own
-- NewFeatureLabelTemplate (Blizzard_SharedXML/NewFeatureLabel.xml on the mirror's `forever`
-- branch: a "NEW" label over the collections-newglow atlas, whose Fade group pulses the glow
-- while the frame is shown and stops on hide) where the client carries it, and a "NEW!" of the
-- pane's own with an alpha pulse where it does not, in the New badge's silver blue (brief E80;
-- the client's template keeps its own gold). NEW_TAG_W is what a tag that cannot be
-- measured is taken to be, and NEW_TAG_GAP the air between the name and the tag.
UIDiscoveries.NEW_TAG_TEMPLATE = "NewFeatureLabelTemplate"
UIDiscoveries.NEW_TAG_W = 30
UIDiscoveries.NEW_TAG_H = 16
UIDiscoveries.NEW_TAG_GAP = size("ITEMTREE_SPACE_1", 4)
UIDiscoveries.NEW_TAG_COLOUR = "ITEMTREE_COLOR_SEMANTIC_NEW"
-- The fallback's pulse: one leg down to NEW_PULSE_MIN and one back up, each NEW_PULSE_LEG
-- seconds, looping.
UIDiscoveries.NEW_PULSE_MIN = 0.35
UIDiscoveries.NEW_PULSE_LEG = 0.6
-- The badge column at the right hand end of a row, the same size and the same count a tree row
-- draws: at most the New and the Changed medallion, because Core/Diff.lua keeps no third mark
-- against an item. The column is always reserved, so a row with no badge leaves the Source and
-- When columns exactly where the row above them put theirs.
UIDiscoveries.BADGE_SIZE = size("ITEMTREE_BADGE_SIZE_TREE", 16)
UIDiscoveries.BADGE_MAX = 2
-- The source tabs sit on the search box's own row, so the row costs no extra height, and they
-- are drawn at the window's own tab size. The width is only what a tab starts at: the row
-- measures each one from its word, exactly as the window's view row does.
UIDiscoveries.TAB_W = size("ITEMTREE_CHROME_TAB_W", 86)
UIDiscoveries.TAB_H = size("ITEMTREE_CHROME_TAB_H", 24)
-- The air between two tabs, the air between the last tab and the search box, and the least the
-- box may be squeezed to before the tabs start giving up their padding. The first three are the
-- window's own numbers where it will state them (Frame.ViewTabMetrics); these are the fallback.
UIDiscoveries.TAB_GAP = 2
UIDiscoveries.TAB_PAD = size("ITEMTREE_SPACE_3", 12)
UIDiscoveries.TAB_PAD_MIN = size("ITEMTREE_SPACE_1", 4)
UIDiscoveries.ROW_GAP = size("ITEMTREE_SPACE_2", 8)
UIDiscoveries.SEARCH_W_MIN = 140
-- The four tick boxes at the right hand end of the tab row: the client's own check box art in a
-- square one small control high, the words beside it, the air between the two, and the air
-- between one box's words and the next box's square, a little more than the row's gap so two
-- labels do not read as one.
UIDiscoveries.TICK_SIZE = size("ITEMTREE_CONTROL_H_SM", 20)
UIDiscoveries.TICK_GAP = size("ITEMTREE_SPACE_1", 4)
UIDiscoveries.TICK_SPACING = size("ITEMTREE_SPACE_3", 12)
UIDiscoveries.EMPTY_ICON = size("ITEMTREE_ICON_HEADER", 40)
-- The corner glyph on a row's icon, and the hairline the dark disc behind it stands proud by.
-- Never more than half the icon, which is the same rule a tree row's mark is sized by, so the
-- glyph and its backing always sit inside the icon box.
UIDiscoveries.MARK_SIZE =
  math.max(1, math.min(size("ITEMTREE_ICON_BADGE", 14), math.floor(UIDiscoveries.ICON_SIZE / 2)))
UIDiscoveries.MARK_INSET = size("ITEMTREE_BORDER_HAIRLINE", 1)
-- E44: the slop around the glyph the mark's own hover target takes, the same couple of pixels a
-- tree row gives it (UI/Tree.lua Tree.MARK_HIT_SLOP).
UIDiscoveries.MARK_HIT_SLOP = 2

-- How wide the empty state's sentence wraps at. Narrow enough to read as a paragraph in the
-- middle of the pane rather than as one long line across it.
UIDiscoveries.EMPTY_TEXT_W = 320

-- How long a keystroke is held back, the same 0.15 the tree's filter box uses, so a fast typist
-- pays for one pass over the list rather than one per letter.
UIDiscoveries.SEARCH_DEBOUNCE = 0.15

-- The most rows the plain frame pool draws, on a client with no ScrollBox. That list has no
-- scrolling of its own, so a row past the list's height was never seen anyway; past this many,
-- one muted "and 812 more" line stands for the rest, and no frame is ever made per entry.
UIDiscoveries.POOL_ROWS = 60

-- The ScrollBox builds rows from a real XML template and the addon ships no XML, so the rows are
-- BackdropTemplate frames with the mouse enabled by hand, the way UI/History.lua does it.
UIDiscoveries.ROW_TEMPLATE = "BackdropTemplate"

-- A font string made with the two argument CreateFontString has no font at all, and the next
-- SetText raises inside the client ("FontString:SetText(): Font not set"). The template is asked
-- for at creation where the client takes one, and the rest are what a client that refused the
-- template is offered instead. Same list and same rule as UI/Sidebar.lua.
UIDiscoveries.FONT_TEMPLATE = "GameFontNormalSmall"
UIDiscoveries.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

UIDiscoveries.PANEL_SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
UIDiscoveries.PANEL_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"

-- The empty state's illustration: the client's own question mark, which is what the game itself
-- draws for an item whose details it cannot resolve, so it is exactly what an undiscovered item
-- looks like to a player. The fallback is the padlock the Requirements category draws, which is
-- what this pane borrowed before the art landed; it says "locked" about something that is only
-- waiting to be found, so it is the second choice and no longer the only one.
UIDiscoveries.EMPTY_ART_KEY = "ART_EMPTY_DISCOVERIES"
UIDiscoveries.EMPTY_ART_FALLBACK = "CAT_REQUIREMENT"

--- The illustration key the empty state draws: the question mark where the build carries it and
--- the padlock where it does not. Pure, and the same shape UI/Tree.lua's Tree.EmptyArt has.
function UIDiscoveries.EmptyArt()
  if Assets and type(Assets.Has) == "function" and Assets.Has(UIDiscoveries.EMPTY_ART_KEY) then
    return UIDiscoveries.EMPTY_ART_KEY
  end
  return UIDiscoveries.EMPTY_ART_FALLBACK
end

-- The model, looked up at call time: Core loads before the UI, but a spec swaps it out and a
-- half loaded addon must not break a draw.
local function model()
  local store = ItemTree.Discoveries
  return type(store) == "table" and store or nil
end

-- The window, looked up the same way and for the same reason. Nothing here is a client call: it
-- is a table read, so the pure functions above the divider may use it too. A build whose window
-- file is older than the two view tab wrappers answers a table without them, which is what the
-- fallbacks below are for.
local function frameModule()
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  return type(frame) == "table" and frame or nil
end

--- How tall a row model draws. Pure.
function UIDiscoveries.RowHeight(row)
  if type(row) == "table" and row.kind == "header" then
    return UIDiscoveries.HEADER_H
  end
  return UIDiscoveries.ROW_H
end

--- How tall the rows are together, band headers and all. Pure.
function UIDiscoveries.ListHeight(rows)
  local total = 0
  for _, row in ipairs(rows or EMPTY) do
    total = total + UIDiscoveries.RowHeight(row)
  end
  return total
end

--- Whether these rows need a scrollbar in a list this tall. A height of nothing is a list the
--- client has not laid out yet, which reads as fitting: an unwanted bar is worse than a late
--- one, and every draw asks again. Pure.
function UIDiscoveries.Overflows(rows, height)
  local available = tonumber(height) or 0
  if available <= 0 then
    return false
  end
  return UIDiscoveries.ListHeight(rows) > available
end

--- How the pool fallback draws a list: how many rows it gives a frame (never more than
--- POOL_ROWS) and how many item rows are left over for the "and n more" line, band headers not
--- counted. Pure, and reads only each row's kind, so a lazy row is never built by it.
function UIDiscoveries.PoolPlan(rows)
  local total = #(rows or EMPTY)
  local drawn = math.min(total, UIDiscoveries.POOL_ROWS)
  local more = 0
  for index = drawn + 1, total do
    local row = rows[index]
    if type(row) == "table" and row.kind ~= "header" then
      more = more + 1
    end
  end
  return drawn, more
end

--- The muted line under a pool that stopped short, or nothing where it did not. Pure.
function UIDiscoveries.MoreText(more)
  local count = tonumber(more) or 0
  if count <= 0 then
    return ""
  end
  return string.format(L["and %d more"], count)
end

--- What the search box says before anything is typed. Pure.
function UIDiscoveries.PlaceholderText()
  return L["Search discoveries"]
end

--- The corner mark a row's icon wears, as the word and the Assets key it is drawn with, or
--- nothing at all. The rule is Core's (Core/Graph.lua Graph.DiscoveryMark), so this row and the
--- tree row it opens can never disagree.
---
--- Every row in this pane is a discovery, so the only question left is whether ItemTree's own
--- data still withholds the item: a row the shipped data now names is an ordinary item and wears
--- no mark, and a row it holds only a stub for wears the chest. Answered from the shipped tables
--- and from nothing else, so a whole list of them costs no client call at all: see the hard rule
--- at the top of Core/Discoveries.lua. Pure.
function UIDiscoveries.RowMark(row)
  if type(row) ~= "table" or row.kind ~= "item" then
    return nil
  end
  local id = tonumber(row.id)
  local data = ItemTree.Data
  local graph = ItemTree.Graph
  if not id or type(data) ~= "table" or type(graph) ~= "table" or type(graph.DiscoveryMark) ~= "function" then
    return nil
  end
  local withheld = false
  if type(data.GetItem) == "function" then
    local ok, item = pcall(data.GetItem, data, id)
    withheld = ok and type(item) == "table" and item.u ~= nil
  end
  if not withheld and type(data.IsUndiscovered) == "function" then
    local ok, answer = pcall(data.IsUndiscovered, data, id)
    withheld = ok and answer == true
  end
  if not withheld then
    return nil
  end
  local ok, mark, art = pcall(graph.DiscoveryMark, { undiscovered = true, discovered = true })
  if not ok or type(mark) ~= "string" then
    return nil
  end
  return mark, art
end

--- What that mark says in words, or nothing at all for a row that wears none. Core owns the
--- wording (Core/Graph.lua Graph.DiscoveryMarkText) for the same reason it owns the rule, so the
--- four surfaces say it in the same words. Pure.
function UIDiscoveries.MarkText(row)
  local mark = UIDiscoveries.RowMark(row)
  local graph = ItemTree.Graph
  if type(mark) ~= "string" or type(graph) ~= "table" or type(graph.DiscoveryMarkText) ~= "function" then
    return nil
  end
  local ok, text = pcall(graph.DiscoveryMarkText, mark)
  if not ok or type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

--- What a click on a row asks for: "open" with the item id, or "none" for a band header and for
--- anything without an id. Pure.
function UIDiscoveries.Interpret(row)
  if type(row) ~= "table" or row.kind ~= "item" then
    return "none", nil
  end
  local id = tonumber(row.id)
  if not id then
    return "none", nil
  end
  return "open", id
end

-- The source tabs, in the order they are drawn: every row, then each of the three sources in
-- turn. "all" is the word for no filter, rather than a nil an array cannot hold.
UIDiscoveries.FILTER_ALL = "all"
UIDiscoveries.SOURCE_FILTERS = { "all", "self", "realm", "data" }

--- The source a tab narrows to, which is nothing at all for the "All" tab: the model takes nil
--- for the whole list, and this row holds "all" in its place. Pure.
function UIDiscoveries.SourceOf(filter)
  if filter == nil or filter == UIDiscoveries.FILTER_ALL then
    return nil
  end
  return filter
end

--- The words on a source tab. Core/Discoveries.lua owns them, so a tab and the Source column can
--- never disagree about what a source is called. Pure.
function UIDiscoveries.FilterLabel(source)
  local store = model()
  if not store or type(store.FilterLabel) ~= "function" then
    return ""
  end
  local ok, text = pcall(store.FilterLabel, UIDiscoveries.SourceOf(source))
  if ok and type(text) == "string" then
    return text
  end
  return ""
end

--- How many rows a tab stands for, read off a counted list. The "All" tab carries the whole
--- count; the other three carry their own source. Core/Discoveries.lua does the counting, so the
--- tabs and the line under the list cannot disagree. Pure.
function UIDiscoveries.TabCount(counts, source)
  local store = model()
  if not store or type(store.SourceCount) ~= "function" then
    return 0
  end
  local ok, count = pcall(store.SourceCount, counts, UIDiscoveries.SourceOf(source))
  if ok and tonumber(count) then
    return tonumber(count)
  end
  return 0
end

--- The whole word on a tab: the source's own words with its count in brackets, "All (4)" and
--- "By you (0)", which is exactly what the window's view tabs draw. Frame.ViewLabel words it
--- where the window is loaded, and the same format string does it where it is not. Pure.
function UIDiscoveries.TabLabel(source, count)
  local label = UIDiscoveries.FilterLabel(source)
  if label == "" then
    -- Nothing worded the source, which means there is no model to count either: a bracketed
    -- nought beside no word at all would read as a tab that has lost its label.
    return label
  end
  local frame = frameModule()
  if frame and type(frame.ViewLabel) == "function" then
    local ok, text = pcall(frame.ViewLabel, label, count)
    if ok and type(text) == "string" then
      return text
    end
  end
  local number = tonumber(count)
  if not number then
    return label
  end
  return string.format(L["%s (%d)"], label, math.floor(number))
end

--- How wide the Source column is drawn: its own widest word and the padding either side, never
--- less than the token's width. measure is handed a word and answers how wide it draws, so the
--- rule is pure and the measuring stays with the caller's font string. A measure that answers
--- nothing at all leaves the column at the token. Pure.
function UIDiscoveries.SourceColumnWidth(measure)
  local base = UIDiscoveries.HOW_W
  local store = model()
  if type(measure) ~= "function" or not store then
    return base
  end
  -- Brief E79: the column names who saw the item, so its words are Discoveries.WhoSamples ("You",
  -- "ItemTree", the miner's name and this character's name). A model without it is measured by
  -- the source labels it still has.
  local words = {}
  if type(store.WhoSamples) == "function" then
    local ok, samples = pcall(store.WhoSamples)
    if ok and type(samples) == "table" then
      words = samples
    end
  elseif type(store.SourceLabel) == "function" then
    for _, source in ipairs(store.SOURCES or EMPTY) do
      local named, label = pcall(store.SourceLabel, source)
      if named then
        words[#words + 1] = label
      end
    end
  end
  local widest = 0
  for _, label in ipairs(words) do
    if type(label) == "string" and label ~= "" then
      local ok, width = pcall(measure, label)
      width = (ok and tonumber(width)) or 0
      if width > widest then
        widest = width
      end
    end
  end
  if widest <= 0 then
    return base
  end
  return math.max(base, math.ceil(widest) + 2 * UIDiscoveries.PAD)
end

--- The words the When column can carry, longest first in spirit: whatever Core/History.lua's
--- History.Ago answers for under a minute ("just now"), for 59 minutes, 23 hours and 999 days,
--- plus the column's own heading. Asked of History rather than written here, so the column follows
--- the words if they change. Pure.
function UIDiscoveries.WhenSamples()
  local out = { L["When"] }
  local History = ItemTree.History
  if type(History) ~= "table" or type(History.Ago) ~= "function" then
    return out
  end
  for _, elapsed in ipairs({ 30, 59 * 60, 23 * 3600, 999 * 86400 }) do
    local ok, text = pcall(History.Ago, 0, elapsed)
    if ok and type(text) == "string" and text ~= "" then
      out[#out + 1] = text
    end
  end
  return out
end

--- How wide the When column is drawn: its widest word (see WhenSamples) and the padding either
--- side, never less than the token. measure is handed a word and answers how wide it draws, as
--- for SourceColumnWidth. Pure.
function UIDiscoveries.WhenColumnWidth(measure)
  local base = UIDiscoveries.WHEN_W
  if type(measure) ~= "function" then
    return base
  end
  local widest = 0
  for _, word in ipairs(UIDiscoveries.WhenSamples()) do
    local ok, width = pcall(measure, word)
    width = (ok and tonumber(width)) or 0
    if width > widest then
      widest = width
    end
  end
  if widest <= 0 then
    return base
  end
  return math.max(base, math.ceil(widest) + 2 * UIDiscoveries.PAD)
end

--- Where the NEW! tag's centre sits, in pixels right of the name's left edge: straight after the
--- name's own text, with the gap between, but never so far right that the tag runs under the
--- Source column. textW is how wide the name draws, tagW how wide the tag is, and room how much
--- the row leaves between the name's left edge and the Source column, or nil where the row has
--- not been laid out yet (then the tag simply follows the text). The name is then stopped at the
--- tag's left, so a long name is cut short rather than run under it. Pure.
function UIDiscoveries.NewTagCentre(textW, tagW, room)
  local gap = UIDiscoveries.NEW_TAG_GAP
  local tag = tonumber(tagW) or UIDiscoveries.NEW_TAG_W
  if tag <= 0 then
    tag = UIDiscoveries.NEW_TAG_W
  end
  local text = math.max(0, tonumber(textW) or 0)
  local space = tonumber(room)
  if space and space > 0 then
    text = math.min(text, math.max(0, space - tag - gap))
  end
  return math.floor(text + gap + tag / 2 + 0.5)
end

--- How far a badge's medallion stands proud of the cluster's own box on each side. UI/Badges.lua
--- draws a supplied medallion one step up the size ladder (16 as 18), because the medallion
--- carries its own ring where a composed badge draws its glyph inside one. The same answer
--- UI/Tree.lua works out for its own badge column, so the two columns are inset alike. Pure, and
--- guarded: a build whose Badges cannot be asked reads as no overhang at all.
function UIDiscoveries.BadgeOverhang(badgeSize)
  local wanted = tonumber(badgeSize) or UIDiscoveries.BADGE_SIZE
  local art = wanted
  if type(Badges) == "table" and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, wanted)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - wanted) / 2))
end

--- The room a cluster of this many badges really takes, medallion art and all. Pure. Nothing to
--- draw is no room at all, which is what a build with no Badges module asks for.
function UIDiscoveries.BadgeColumnWidth(count, badgeSize)
  count = tonumber(count) or UIDiscoveries.BADGE_MAX
  local wanted = tonumber(badgeSize) or UIDiscoveries.BADGE_SIZE
  if count <= 0 or wanted <= 0 or type(Badges) ~= "table" then
    return 0
  end
  local gap = 0
  if type(Badges.GapFor) == "function" then
    local ok, value = pcall(Badges.GapFor, wanted)
    if ok and tonumber(value) then
      gap = tonumber(value)
    end
  end
  return count * wanted + (count - 1) * gap + 2 * UIDiscoveries.BadgeOverhang(wanted)
end

--- How far in from a row's right edge the When column ends: the row's own gutter, the badge
--- column and the gutter between the two. Every row and the header over them read this, so the
--- words stay in one line down the list whether or not a row wears a badge. Pure.
function UIDiscoveries.BadgeInset()
  local column = UIDiscoveries.BadgeColumnWidth()
  if column <= 0 then
    return UIDiscoveries.GUTTER
  end
  return UIDiscoveries.GUTTER + column + UIDiscoveries.GUTTER
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

UIDiscoveries.pool = {}
UIDiscoveries.rows = EMPTY
UIDiscoveries.entries = EMPTY
UIDiscoveries.tabs = EMPTY
UIDiscoveries.filter = nil
UIDiscoveries.sourceFilter = UIDiscoveries.FILTER_ALL
UIDiscoveries.searchText = ""
UIDiscoveries.searchToken = 0

local globalFn = ItemTree.Util.GlobalFn

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes. Looked up at call time, because a spec loads this
-- file on its own and a build without the module must cost the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

local function newFrame(kind, parent)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- A frame that is only worth having with its template: the ScrollBox parts. CreateFrame raises
-- on a template the client does not carry, so nothing here is taken without a pcall and every
-- caller has a plain fallback behind it.
local function newTemplatedFrame(kind, parent, template)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent, template)
  if ok and frame then
    return frame
  end
  return nil
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves
-- the region's own colour alone. Same idiom as UI/History.lua.
local function themeColor(key)
  if not Theme or type(Theme.ColorTable) ~= "function" or key == nil then
    return nil
  end
  return Theme.ColorTable(key)
end

local function tint(texture, key, alpha)
  local colour = themeColor(key)
  if not colour or type(texture) ~= "table" or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(colour.r, colour.g, colour.b)
  if type(texture.SetAlpha) == "function" then
    texture:SetAlpha(alpha or colour.a or 1)
  end
  return true
end

local function colourText(fontString, key)
  local colour = themeColor(key)
  if type(fontString) == "table" and colour and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(colour.r, colour.g, colour.b, colour.a or 1)
  end
end

-- A flat fill in one Theme colour. Every texture goes through Assets so the path lives in one
-- table and the harness can report it.
local function wash(parent, layer, colorKey, alpha)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local texture = parent:CreateTexture(nil, layer)
  if not texture then
    return nil
  end
  if Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey, alpha)
  texture:Hide()
  return texture
end

-- The design's InsetPanel edge: four hairlines in one Theme colour, drawn by hand. Not a nine
-- slice, because the live clients' NineSliceUtil is atlas oriented and a file layout renders as
-- a dotted edge. See docs/design-deviations.md.
local function insetBorder(frame, colorKey)
  local edges = {}
  for index = 1, 4 do
    local edge = wash(frame, "BORDER", colorKey)
    if not edge then
      return nil
    end
    edge:Show()
    edges[index] = edge
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(UIDiscoveries.EDGE_W)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(UIDiscoveries.EDGE_W)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(UIDiscoveries.EDGE_W)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(UIDiscoveries.EDGE_W)
  return { top = top, bottom = bottom, left = left, right = right, edges = edges }
end

local function tintEdges(border, colorKey)
  if type(border) ~= "table" then
    return false
  end
  for _, edge in ipairs(border.edges or EMPTY) do
    tint(edge, colorKey)
  end
  return true
end

--------------------------------------------------------------------------------
-- Font safety
--------------------------------------------------------------------------------

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(UIDiscoveries.FONT_FALLBACKS) do
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

-- Whether the client says this font string has a font. One that cannot be asked reads as having
-- none, so a font object is put on it anyway: setting one twice costs nothing.
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

-- Body face, 1px shadow. SetFont answers false rather than raising where the client cannot load
-- the face, so the answer is read and a font object put back: a font string that lost its font
-- raises from inside the next SetText.
local function styleText(fontString, fontSize, colorKey, justify, wrap)
  if type(fontString) ~= "table" then
    return nil
  end
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify or "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(wrap and true or false)
  end
  if not wrap and type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  colourText(fontString, colorKey)
  return fontString
end

-- A font string that is never fontless. The client's own font object is asked for at creation,
-- through the template argument where the client takes one and by hand where it does not, so a
-- SetText is never the first thing to touch the font.
local function newFontString(parent, fontSize, colorKey, justify, wrap)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", UIDiscoveries.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return styleText(fontString, fontSize, colorKey, justify, wrap)
end

-- Every word this pane draws goes through here. The font is put back first, and the write itself
-- is pcalled, so a client that can give a font string no font at all costs the pane a blank
-- label rather than the whole draw.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- How wide a word draws in a font string that is already carrying it. A client that will not
-- measure one is estimated from the letters instead, the same six pixels a letter UI/Frame.lua
-- estimates with, so a row still lays out rather than collapsing to nothing.
local function textWidth(fontString, text)
  local width = nil
  if type(fontString) == "table" and type(fontString.GetStringWidth) == "function" then
    local ok, measured = pcall(fontString.GetStringWidth, fontString)
    if ok then
      width = tonumber(measured)
    end
  end
  return width or (#tostring(text or "") * 6 + 8)
end

-- The word's own width, measured by writing it into a font string and reading it back. The
-- caller owns the font string and writes what it wants left in it afterwards.
local function measureWith(fontString)
  return function(text)
    setText(fontString, text)
    return textWidth(fontString, text)
  end
end

--------------------------------------------------------------------------------
-- The clock, and what the window is asked to do
--------------------------------------------------------------------------------

-- The client's own time, or the standard library's under a spec, or nothing at all. Every model
-- call takes it as an argument, so this is the only place the pane reads a clock.
local function clock()
  local clientTime = globalFn("time")
  if clientTime then
    local ok, value = pcall(clientTime)
    if ok and tonumber(value) then
      return tonumber(value)
    end
  end
  local standard = rawget(_G, "os")
  if type(standard) == "table" and type(standard.time) == "function" then
    local ok, value = pcall(standard.time)
    if ok and tonumber(value) then
      return tonumber(value)
    end
  end
  return 0
end

-- The moment today began. The calendar is the client's (or the standard library's under a
-- spec); the arithmetic is the model's. nil where nothing will say what the time is, and the
-- model then bands by elapsed time instead.
local function dayStart(now)
  local parts = nil
  local dateFn = globalFn("date")
  if dateFn then
    local ok, value = pcall(dateFn, "*t", now)
    if ok and type(value) == "table" then
      parts = value
    end
  end
  if not parts then
    local standard = rawget(_G, "os")
    if type(standard) == "table" and type(standard.date) == "function" then
      local ok, value = pcall(standard.date, "*t", now)
      if ok and type(value) == "table" then
        parts = value
      end
    end
  end
  local store = model()
  if not parts or not store or type(store.DayStart) ~= "function" then
    return nil
  end
  local ok, at = pcall(store.DayStart, now, parts.hour, parts.min, parts.sec)
  if ok and tonumber(at) then
    return tonumber(at)
  end
  return nil
end

--- Opens an item in the Tree tab: the window re-roots on it and then moves off this tab, which
--- is what a click on a row asks for. Both calls are looked up lazily and guarded, so a window
--- that is still a stub costs the click and nothing else.
function UIDiscoveries.OpenItem(itemId)
  local frame = frameModule()
  local Graph = ItemTree.Graph
  if not frame or type(frame.Open) ~= "function" then
    return false
  end
  if type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
    return false
  end
  local made, key = pcall(Graph.Key, "item", itemId)
  if not made or type(key) ~= "string" then
    return false
  end
  local opened = pcall(frame.Open, key)
  if type(frame.SelectTab) == "function" then
    pcall(frame.SelectTab, "Tree")
  end
  return opened
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function tooltipFrame()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return nil
  end
  return tooltip
end

function UIDiscoveries.HideRowTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
    return true
  end
  return false
end

-- r, g, b for a Theme colour key, and white for a key this build does not carry, because a
-- tooltip line has to be some colour and the client's own default is white.
local function tooltipColor(key)
  local colour = themeColor(key)
  if not colour then
    return 1, 1, 1
  end
  return colour.r, colour.g, colour.b
end

--- The tooltip a hovered row raises: the client's own item tooltip, the chest's sentence where
--- the row wears one, and a line saying what a click does. Brief W33 dropped the source sentence
--- and the times sentence (the owner found them unnecessary); the info line over the list still
--- carries the times sentence.
---
--- Anchored to the row's right edge, which is the pane's right edge, so the tooltip sits beside
--- the window rather than over the list the player is reading.
---
--- This is the one client call this file makes about an item, and it is made for the single row
--- under the cursor. It is never made for a list: see the hard rule at the top of this file.
function UIDiscoveries.ShowRowTooltip(frame)
  local row = type(frame) == "table" and rawget(frame, "rowModel") or nil
  local itemId = type(row) == "table" and row.kind == "item" and tonumber(row.id) or nil
  local tooltip = itemId and tooltipFrame() or nil
  if not tooltip then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  local shown = false
  if type(tooltip.SetItemByID) == "function" then
    shown = pcall(tooltip.SetItemByID, tooltip, itemId) and true or false
  end
  if not shown and type(tooltip.SetHyperlink) == "function" then
    shown = pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(itemId)) and true or false
  end
  if not shown and type(tooltip.SetText) == "function" then
    tooltip:SetText(row.name or "")
    shown = true
  end
  if type(tooltip.AddLine) == "function" then
    local r, g, b = tooltipColor("ITEMTREE_COLOR_TEXT_MUTED")
    -- E44: what the chest in the corner of the icon means, on every hover, under whichever block
    -- was drawn above it, the client's own item tooltip included. This is the one place the pane
    -- writes the sentence, and ItemTree's block (UI/Tooltip.lua) never writes it at all, so it
    -- can never land twice.
    local text = UIDiscoveries.MarkText(row)
    if text then
      tooltip:AddLine(text, r, g, b)
    end
    tooltip:AddLine(L["Click to open in the Tree tab"], r, g, b)
    shown = true
  end
  if shown and type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return shown
end

--- E44: the chest's own hover, raised from the small target over the mark itself. One line, the
--- sentence, and nothing else: the player is pointing at a 14px glyph and asking what it is, not
--- at the row.
function UIDiscoveries.ShowMarkTooltip(hit)
  local frame = type(hit) == "table" and rawget(hit, "owner") or nil
  local row = type(frame) == "table" and rawget(frame, "rowModel") or nil
  local text = UIDiscoveries.MarkText(row)
  local tooltip = text and tooltipFrame() or nil
  if not tooltip or type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:SetOwner(hit, "ANCHOR_RIGHT")
  tooltip:AddLine(text, tooltipColor("ITEMTREE_COLOR_TEXT_TITLE"))
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

local function showHover(frame, shown)
  if type(frame) == "table" and frame.hoverWash then
    if shown then
      frame.hoverWash:Show()
    else
      frame.hoverWash:Hide()
    end
  end
end

local function onRowEnter(frame)
  showHover(frame, true)
  UIDiscoveries.ShowRowTooltip(frame)
end

local function onRowLeave(frame)
  showHover(frame, false)
  UIDiscoveries.HideRowTooltip()
end

-- E6: the standard modified clicks. A left click with the client's dress up or chat link
-- modifier on an item row goes to UI/ItemClick.lua first, and when the client takes it (the item
-- is on in the Dressing Room, or its link is in the chat box) the row does not open the item.
-- Every other click is exactly what it was. The row scripts OnMouseUp, which carries the button.
function UIDiscoveries.ModifiedClick(row, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local action, id = UIDiscoveries.Interpret(row)
  if action ~= "open" then
    return false
  end
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.Handle) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.Handle, id)
  return ok and handled == true
end

local function onRowClick(frame, button)
  local row = type(frame) == "table" and rawget(frame, "rowModel") or nil
  if UIDiscoveries.ModifiedClick(row, button) then
    return
  end
  UIDiscoveries.Activate(row)
end

-- The hover target over the chest. The row keeps its highlight while the pointer is on the mark,
-- because the mark is part of the row as far as the player is concerned, and the press is handed
-- to the row's own handler so the target can never eat the click the row was meant to take.
local function onMarkEnter(hit)
  showHover(rawget(hit, "owner"), true)
  UIDiscoveries.ShowMarkTooltip(hit)
end

local function onMarkLeave(hit)
  onRowLeave(rawget(hit, "owner"))
end

local function onMarkClick(hit, button)
  onRowClick(rawget(hit, "owner"), button)
end

--- One click on a row. A band header asks for nothing.
function UIDiscoveries.Activate(row)
  local action, id = UIDiscoveries.Interpret(row)
  if action == "open" then
    -- E39: one small click for the press, before the window re-roots on the item.
    playCue("click")
    UIDiscoveries.OpenItem(id)
  end
  return action, id
end

-- One row's badge cluster, the window's own (UI/Badges.lua), so a discovery wears the same New
-- and Changed medallions the tree, the sidebar and the search dropdown draw, with the same
-- tooltip on hover. Right aligned in its column, and inset by the pixel the medallion art stands
-- proud of the cluster's box so the art ends on the row's gutter rather than outside it. nil
-- where the build carries no Badges module, and the row then draws everything else as before.
local function newBadgeCluster(frame)
  if type(Badges) ~= "table" or type(Badges.CreateCluster) ~= "function" then
    return nil
  end
  local ok, cluster = pcall(Badges.CreateCluster, frame, UIDiscoveries.BADGE_SIZE, UIDiscoveries.BADGE_MAX)
  if not ok or type(cluster) ~= "table" then
    return nil
  end
  if type(cluster.SetPoint) == "function" then
    local inset = UIDiscoveries.GUTTER + UIDiscoveries.BadgeOverhang()
    pcall(cluster.SetPoint, cluster, "RIGHT", frame, "RIGHT", -inset, 0)
  end
  if type(cluster.Hide) == "function" then
    cluster:Hide()
  end
  -- E48: each mark is its own hover target, so pointing at one says what that mark means
  -- instead of raising the row's tooltip. The row keeps its wash while the pointer is on a
  -- mark, the way it does for the chest, and UI/Badges.lua hands the press back to the row.
  -- Both methods arrived with that brief, so an older Badges draws exactly what it drew.
  if type(cluster.SetHoverEnabled) == "function" then
    pcall(cluster.SetHoverEnabled, cluster, true)
  end
  if type(cluster.SetHoverHooks) == "function" then
    pcall(cluster.SetHoverHooks, cluster, function()
      showHover(frame, true)
    end, function()
      onRowLeave(frame)
    end)
  end
  return cluster
end

-- The badges one row wears, and the item they hover over. The cluster is pooled with the row, so
-- a frame drawn again for another item is told its new subject and its new marks rather than
-- being left showing the one before it. A band header wears none and hovers over nothing.
local function applyRowBadges(frame, row)
  local cluster = type(frame) == "table" and frame.badgeCluster or nil
  if type(cluster) ~= "table" then
    return false
  end
  local id = nil
  if type(row) == "table" and row.kind == "item" then
    id = tonumber(row.id)
  end
  if type(cluster.SetSubject) == "function" then
    if id then
      pcall(cluster.SetSubject, cluster, "items", id)
    else
      pcall(cluster.SetSubject, cluster, nil, nil)
    end
  end
  if type(cluster.SetKinds) ~= "function" then
    return false
  end
  local kinds = EMPTY
  if id and type(row.badges) == "table" then
    kinds = row.badges
  end
  return (pcall(cluster.SetKinds, cluster, kinds))
end

-- Builds the widgets of one row, once. The ScrollBox hands back bare frames it made itself, so
-- this has to work on a frame this file did not create.
function UIDiscoveries.DecorateRow(frame)
  if type(frame) ~= "table" or rawget(frame, "itemTreeDiscoveryRow") then
    return frame
  end
  frame.itemTreeDiscoveryRow = true
  if type(frame.SetHeight) == "function" then
    frame:SetHeight(UIDiscoveries.ROW_H)
  end
  if type(frame.EnableMouse) == "function" then
    frame:EnableMouse(true)
  end

  -- A band header is the same frame drawn differently: the sticky surface with a divider under
  -- it, which is how every other list in the addon separates its groups.
  frame.headerFill = wash(frame, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_STICKY")
  if frame.headerFill then
    frame.headerFill:SetAllPoints(frame)
  end
  frame.headerEdge = wash(frame, "BORDER", "ITEMTREE_COLOR_BORDER_DIVIDER")
  if frame.headerEdge then
    frame.headerEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.headerEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.headerEdge:SetHeight(UIDiscoveries.EDGE_W)
  end
  frame.hoverWash = wash(frame, "BORDER", "ITEMTREE_COLOR_STATE_HOVER")
  if frame.hoverWash then
    frame.hoverWash:SetAllPoints(frame)
  end

  frame.icon = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.icon then
    frame.icon:SetSize(UIDiscoveries.ICON_SIZE, UIDiscoveries.ICON_SIZE)
    frame.icon:SetPoint("LEFT", frame, "LEFT", UIDiscoveries.GUTTER, 0)
  end

  -- The corner glyph, pinned inside the bottom right of the icon by a hairline so the dark disc
  -- behind it lands exactly on the icon's corner, the way a tree row draws the same mark. Hidden
  -- on every row that does not ask for it, because the frame is pooled.
  frame.markBack = wash(frame, "ARTWORK", "ITEMTREE_BADGE_BACKING")
  frame.mark = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "OVERLAY") or nil
  if frame.mark and frame.icon then
    local inset = UIDiscoveries.MARK_INSET
    frame.mark:SetSize(UIDiscoveries.MARK_SIZE, UIDiscoveries.MARK_SIZE)
    frame.mark:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -inset, inset)
    frame.mark:Hide()
  end
  if frame.markBack then
    if frame.mark then
      frame.markBack:SetPoint("TOPLEFT", frame.mark, "TOPLEFT", -1, 1)
      frame.markBack:SetPoint("BOTTOMRIGHT", frame.mark, "BOTTOMRIGHT", 1, -1)
    end
    frame.markBack:Hide()
  end

  -- E44: the mark's own hover target, over the glyph with a couple of pixels of slop, so the
  -- player can point at the chest and be told what it means. It sits above the row, so its press
  -- is handed to the row's handler rather than swallowed. Hidden until a row wears the chest.
  frame.markHit = newFrame("Frame", frame)
  if frame.markHit and frame.mark then
    local slop = UIDiscoveries.MARK_HIT_SLOP
    frame.markHit.owner = frame
    frame.markHit:SetPoint("TOPLEFT", frame.mark, "TOPLEFT", -slop, slop)
    frame.markHit:SetPoint("BOTTOMRIGHT", frame.mark, "BOTTOMRIGHT", slop, -slop)
    if type(frame.markHit.EnableMouse) == "function" then
      frame.markHit:EnableMouse(true)
    end
    if type(frame.markHit.SetScript) == "function" then
      frame.markHit:SetScript("OnEnter", onMarkEnter)
      frame.markHit:SetScript("OnLeave", onMarkLeave)
      frame.markHit:SetScript("OnMouseUp", onMarkClick)
    end
    frame.markHit:Hide()
  else
    frame.markHit = nil
  end

  -- The badges the rest of the window draws on this item, in a column of their own at the right
  -- hand end of the row, which is where a tree row keeps them. The column is reserved whether
  -- or not this row wears one, so the words beside it never shuffle.
  frame.badgeCluster = newBadgeCluster(frame)

  -- Item, then Source, then When, then the badges: the same order the column header draws, with
  -- When against the badge column because it is the narrowest and the one the eye runs down.
  frame.when = newFontString(frame, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if frame.when then
    frame.when:SetWidth(UIDiscoveries.whenW)
    frame.when:SetPoint("RIGHT", frame, "RIGHT", -UIDiscoveries.BadgeInset(), 0)
  end

  frame.how = newFontString(frame, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if frame.how then
    frame.how:SetWidth(UIDiscoveries.howW)
    if frame.when then
      frame.how:SetPoint("RIGHT", frame.when, "LEFT", -UIDiscoveries.GUTTER, 0)
    else
      frame.how:SetPoint("RIGHT", frame, "RIGHT", -UIDiscoveries.GUTTER, 0)
    end
  end

  frame.name = newFontString(frame, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_BODY", "LEFT")

  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEnter", onRowEnter)
    frame:SetScript("OnLeave", onRowLeave)
    frame:SetScript("OnMouseUp", onRowClick)
  end
  return frame
end

-- The icon the row draws, from the shipped data and from nothing else: the client is never asked
-- what an item looks like. An id the data has no art for takes the question mark.
local function applyRowIcon(texture, row)
  if type(texture) ~= "table" then
    return false
  end
  local icon = row.icon
  if icon ~= nil and type(texture.SetTexture) == "function" and pcall(texture.SetTexture, texture, icon) then
    texture:Show()
    return true
  end
  if Assets and type(Assets.Apply) == "function" and pcall(Assets.Apply, texture, "ICON_QUESTIONMARK") then
    texture:Show()
    return true
  end
  texture:Hide()
  return false
end

-- The corner glyph on one row, or both pieces of it hidden, and with it the hover target over it
-- (E44). The frames are pooled, so a row that wears no mark has to put the last row's away.
local function applyRowMark(frame, row)
  local mark, back, hit = frame.mark, frame.markBack, frame.markHit
  if not mark then
    if hit then
      hit:Hide()
    end
    return false
  end
  local _, art = UIDiscoveries.RowMark(row)
  local drawn = false
  if art and Assets and type(Assets.Has) == "function" and Assets.Has(art) then
    drawn = select(1, pcall(Assets.Apply, mark, art)) and true or false
  end
  if drawn and frame.icon and type(frame.icon.IsShown) == "function" and not frame.icon:IsShown() then
    drawn = false
  end
  if drawn then
    if type(mark.SetVertexColor) == "function" then
      mark:SetVertexColor(1, 1, 1)
    end
    mark:Show()
    if back then
      back:Show()
    end
    if hit then
      hit:Show()
    end
    return true
  end
  mark:Hide()
  if back then
    back:Hide()
  end
  if hit then
    hit:Hide()
  end
  return false
end

-- The fallback tag's pulse: two Alpha legs, down and back up, looping, built the way
-- UI/Badges.lua builds its own. Nothing where the client has no animations, which leaves a
-- static gold tag.
local function newTagPulse(tag)
  if type(tag) ~= "table" or type(tag.CreateAnimationGroup) ~= "function" then
    return nil
  end
  local ok, group = pcall(tag.CreateAnimationGroup, tag)
  if not ok or type(group) ~= "table" or type(group.CreateAnimation) ~= "function" then
    return nil
  end
  local legs = {
    { from = 1, to = UIDiscoveries.NEW_PULSE_MIN, order = 1 },
    { from = UIDiscoveries.NEW_PULSE_MIN, to = 1, order = 2 },
  }
  for _, leg in ipairs(legs) do
    local made, anim = pcall(group.CreateAnimation, group, "Alpha")
    if not made or type(anim) ~= "table" then
      return nil
    end
    if type(anim.SetFromAlpha) == "function" then
      pcall(anim.SetFromAlpha, anim, leg.from)
      pcall(anim.SetToAlpha, anim, leg.to)
    end
    if type(anim.SetDuration) == "function" then
      pcall(anim.SetDuration, anim, UIDiscoveries.NEW_PULSE_LEG)
    end
    if type(anim.SetOrder) == "function" then
      pcall(anim.SetOrder, anim, leg.order)
    end
  end
  if type(group.SetLooping) == "function" then
    pcall(group.SetLooping, group, "REPEAT")
  end
  return group
end

-- The NEW! tag on one row, built the first time a row needs one. The client's own template
-- first; a plain frame carrying a silver blue "NEW!" and its own pulse where the template will not
-- come. A look only: the mouse is left off, so a press or a hover goes to the row under it.
local function newTag(frame)
  local tag = newTemplatedFrame("Frame", frame, UIDiscoveries.NEW_TAG_TEMPLATE)
  if tag then
    tag.kind = "template"
  else
    tag = newFrame("Frame", frame)
    if not tag then
      return nil
    end
    tag.kind = "text"
    tag.label = newFontString(tag, size("ITEMTREE_FONTSIZE_BODY_SM", 11), UIDiscoveries.NEW_TAG_COLOUR, "CENTER")
    if tag.label then
      tag.label:SetPoint("CENTER", tag, "CENTER", 0, 0)
      setText(tag.label, L["NEW!"])
    end
    tag.pulse = newTagPulse(tag)
  end
  if type(tag.EnableMouse) == "function" then
    pcall(tag.EnableMouse, tag, false)
  end
  tag:Hide()
  return tag
end

-- How wide a tag's word draws. The template states it (NewFeatureLabelMixin:GetTextWidth, the
-- label's own width); the fallback is measured; anything that will not answer is NEW_TAG_W.
local function tagWidth(tag)
  local width = nil
  if tag.kind == "template" and type(tag.GetTextWidth) == "function" then
    local ok, measured = pcall(tag.GetTextWidth, tag)
    width = ok and tonumber(measured) or nil
  elseif tag.label then
    width = textWidth(tag.label, L["NEW!"])
  end
  if not width or width <= 0 then
    return UIDiscoveries.NEW_TAG_W
  end
  return width
end

-- Puts the tag away: hidden, and the fallback's pulse stopped. The template stops its own glow in
-- its OnHide.
local function hideTag(tag)
  if type(tag) ~= "table" then
    return false
  end
  tag:Hide()
  if tag.pulse and type(tag.pulse.Stop) == "function" then
    pcall(tag.pulse.Stop, tag.pulse)
  end
  return true
end

-- How wide the name's whole text draws, not the part the column leaves showing: the unbounded
-- width where the client answers it, the plain one where it does not.
local function nameWidth(fontString, text)
  if type(fontString) == "table" and type(fontString.GetUnboundedStringWidth) == "function" then
    local ok, measured = pcall(fontString.GetUnboundedStringWidth, fontString)
    if ok and tonumber(measured) then
      return tonumber(measured)
    end
  end
  return textWidth(fontString, text)
end

-- How much room a row leaves for its name and tag: the row's width less the icon on the left and
-- the Source, When and badge columns on the right. Nil where nothing has a width yet.
local function nameRoom(frame)
  local width = nil
  if type(frame.GetWidth) == "function" then
    local ok, measured = pcall(frame.GetWidth, frame)
    width = ok and tonumber(measured) or nil
  end
  if (not width or width <= 0) and UIDiscoveries.list and type(UIDiscoveries.list.GetWidth) == "function" then
    local ok, measured = pcall(UIDiscoveries.list.GetWidth, UIDiscoveries.list)
    width = ok and tonumber(measured) or nil
  end
  if not width or width <= 0 then
    return nil
  end
  local left = UIDiscoveries.GUTTER
  if frame.icon then
    left = left + UIDiscoveries.ICON_SIZE + UIDiscoveries.GUTTER
  end
  local right = UIDiscoveries.BadgeInset() + UIDiscoveries.whenW + UIDiscoveries.GUTTER
  if frame.how then
    right = right + UIDiscoveries.howW + UIDiscoveries.GUTTER
  end
  return width - left - right
end

-- The tag on one row, shown after the name's text for a row the player has not seen and put away
-- on every other, because the frames are pooled. Answers the tag where it is showing, so the
-- caller stops the name at its left.
local function applyNewTag(frame, row)
  local tag = frame.newTag
  if not (type(row) == "table" and row.kind ~= "header" and row.isNew == true and frame.name) then
    hideTag(tag)
    return nil
  end
  if not tag then
    tag = newTag(frame)
    frame.newTag = tag
    if not tag then
      return nil
    end
  end
  local wide = tagWidth(tag)
  local centre = UIDiscoveries.NewTagCentre(nameWidth(frame.name, row.name), wide, nameRoom(frame))
  if type(tag.SetSize) == "function" and tag.kind == "text" then
    tag:SetSize(wide, UIDiscoveries.NEW_TAG_H)
  end
  tag:ClearAllPoints()
  -- The tag hangs off the name's left edge's own anchor rather than off the name, so the name can
  -- then be stopped at the tag without the two anchoring to each other.
  local left, offset = frame, UIDiscoveries.GUTTER
  if frame.icon then
    left, offset = frame.icon, UIDiscoveries.ICON_SIZE + UIDiscoveries.GUTTER
  end
  tag:SetPoint("CENTER", left, "LEFT", offset + centre, 0)
  tag.width = wide
  tag:Show()
  if tag.pulse and type(tag.pulse.Play) == "function" then
    pcall(tag.pulse.Play, tag.pulse)
  end
  return tag
end

--- Draws one row model into a row frame. Band headers and item rows share the frame, so the
--- ScrollBox needs one template and the pool needs one kind of row.
function UIDiscoveries.InitRow(frame, row)
  if type(frame) ~= "table" then
    return false
  end
  UIDiscoveries.DecorateRow(frame)
  frame.rowModel = row
  if type(row) ~= "table" then
    frame:Hide()
    return false
  end
  if type(frame.SetHeight) == "function" then
    frame:SetHeight(UIDiscoveries.RowHeight(row))
  end

  local isHeader = row.kind == "header"
  applyRowBadges(frame, row)
  if frame.headerFill then
    if isHeader then
      frame.headerFill:Show()
    else
      frame.headerFill:Hide()
    end
  end
  if frame.headerEdge then
    if isHeader then
      frame.headerEdge:Show()
    else
      frame.headerEdge:Hide()
    end
  end

  if isHeader then
    if frame.icon then
      frame.icon:Hide()
    end
    applyRowMark(frame, nil)
    applyNewTag(frame, nil)
    setText(frame.when, "")
    setText(frame.how, "")
    if frame.name then
      frame.name:ClearAllPoints()
      frame.name:SetPoint("LEFT", frame, "LEFT", UIDiscoveries.GUTTER, 0)
      frame.name:SetPoint("RIGHT", frame, "RIGHT", -UIDiscoveries.GUTTER, 0)
      setText(frame.name, row.label)
      colourText(frame.name, "ITEMTREE_COLOR_TEXT_TITLE")
    end
    onRowLeave(frame)
    frame:Show()
    return true
  end

  if frame.icon then
    applyRowIcon(frame.icon, row)
  end
  applyRowMark(frame, row)
  setText(frame.when, row.when)
  setText(frame.how, row.how)
  if frame.name then
    frame.name:ClearAllPoints()
    if frame.icon then
      frame.name:SetPoint("LEFT", frame.icon, "RIGHT", UIDiscoveries.GUTTER, 0)
    else
      frame.name:SetPoint("LEFT", frame, "LEFT", UIDiscoveries.GUTTER, 0)
    end
    local column = frame.how or frame.when
    if column then
      frame.name:SetPoint("RIGHT", column, "LEFT", -UIDiscoveries.GUTTER, 0)
    else
      frame.name:SetPoint("RIGHT", frame, "RIGHT", -UIDiscoveries.GUTTER, 0)
    end
    setText(frame.name, row.name)
    local key = Theme and type(Theme.QualityKey) == "function" and Theme.QualityKey(row.quality) or nil
    colourText(frame.name, key or "ITEMTREE_COLOR_TEXT_BODY")
    -- A row the player has not seen wears the tag after its name, and the name is then stopped
    -- at the tag's left edge rather than run under it.
    local tag = applyNewTag(frame, row)
    if tag then
      frame.name:ClearAllPoints()
      if frame.icon then
        frame.name:SetPoint("LEFT", frame.icon, "RIGHT", UIDiscoveries.GUTTER, 0)
      else
        frame.name:SetPoint("LEFT", frame, "LEFT", UIDiscoveries.GUTTER, 0)
      end
      frame.name:SetPoint("RIGHT", tag, "CENTER", -(tag.width / 2 + UIDiscoveries.NEW_TAG_GAP), 0)
    end
  elseif frame.newTag then
    hideTag(frame.newTag)
  end
  onRowLeave(frame)
  frame:Show()
  return true
end

--------------------------------------------------------------------------------
-- The list: a ScrollBox where the client carries one, a frame pool where it does not
--------------------------------------------------------------------------------

local function scrollAvailable()
  local scrollUtil = rawget(_G, "ScrollUtil")
  if not globalFn("CreateScrollBoxListLinearView") or not globalFn("CreateDataProvider") then
    return false
  end
  if type(scrollUtil) ~= "table" then
    return false
  end
  return type(scrollUtil.InitScrollBoxListWithScrollBar) == "function"
    or type(scrollUtil.InitScrollBoxList) == "function"
end

local function newLinearView()
  local create = globalFn("CreateScrollBoxListLinearView")
  if not create then
    return nil
  end
  local ok, view = pcall(create)
  if not ok or type(view) ~= "table" then
    return nil
  end
  -- Two row heights, so the extent is asked for per row where the client can; a client that only
  -- takes one extent gets the item row height and the band headers draw a little tight.
  if type(view.SetElementExtentCalculator) == "function" then
    pcall(view.SetElementExtentCalculator, view, function(_, element)
      return UIDiscoveries.RowHeight(element)
    end)
  elseif type(view.SetElementExtent) == "function" then
    pcall(view.SetElementExtent, view, UIDiscoveries.ROW_H)
  end
  if type(view.SetElementInitializer) ~= "function" then
    return nil
  end
  local initialised = pcall(view.SetElementInitializer, view, UIDiscoveries.ROW_TEMPLATE, function(frame, element)
    UIDiscoveries.InitRow(frame, element)
  end)
  if not initialised then
    return nil
  end
  return view
end

-- Lays the scroll box out inside its host, giving the width back when the bar is not drawn.
local function anchorScrollBox(withBar)
  local box, host = UIDiscoveries.scrollBox, UIDiscoveries.scrollHost
  if not (box and host and type(box.ClearAllPoints) == "function") then
    return false
  end
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  local inset = 0
  if withBar then
    inset = -UIDiscoveries.SCROLLBAR_W
  end
  box:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", inset, 0)
  return true
end

local function buildScrollBox(parent)
  if not scrollAvailable() then
    return false
  end
  local box = newTemplatedFrame("Frame", parent, "WowScrollBoxList")
  if not box then
    return false
  end
  local bar = newTemplatedFrame("EventFrame", parent, "MinimalScrollBar")
    or newTemplatedFrame("Frame", parent, "MinimalScrollBar")
  local view = newLinearView()
  local scrollUtil = rawget(_G, "ScrollUtil")
  local ok = false
  if view and bar and type(scrollUtil.InitScrollBoxListWithScrollBar) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxListWithScrollBar, box, bar, view)
  elseif view and type(scrollUtil.InitScrollBoxList) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxList, box, view)
  end
  if not ok then
    box:Hide()
    if bar then
      bar:Hide()
    end
    return false
  end

  UIDiscoveries.scrollBox, UIDiscoveries.scrollBar, UIDiscoveries.view = box, bar, view
  UIDiscoveries.scrollHost = parent
  anchorScrollBox(false)
  if bar then
    bar:SetWidth(UIDiscoveries.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    -- Hidden until the rows say otherwise, so a short list never opens beside a full height bar.
    bar:Hide()
  end
  return true
end

local function heightOf(frame)
  if type(frame) ~= "table" or type(frame.GetHeight) ~= "function" then
    return 0
  end
  local ok, height = pcall(frame.GetHeight, frame)
  return (ok and tonumber(height)) or 0
end

-- The bar is drawn only while the rows overflow the list, and the list takes the width back when
-- it goes. Returns whether the bar is up, which is also what the name column is measured with.
function UIDiscoveries.UpdateScrollBar(rows)
  local overflow = UIDiscoveries.Overflows(rows, heightOf(UIDiscoveries.list))
  local bar = UIDiscoveries.scrollBar
  if not bar then
    return overflow
  end
  if overflow then
    bar:Show()
  else
    bar:Hide()
  end
  anchorScrollBox(overflow)
  return overflow
end

-- Brief RO1 (the owner, 2026-10-20: "if you close itemtree, when you open it up again without
-- anything changing it should open to the same place"): a redraw keeps the list where it is
-- scrolled. ScrollBoxListMixin:SetDataProvider(dataProvider, retainScrollPosition) goes back to the
-- top unless the second argument is ScrollBoxConstants.RetainScrollPosition, which is true
-- (wow-ui-source branch `forever`, Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:17 and 703 to 713),
-- so a find arriving or the window coming back used to put the list at its top. The top is now
-- asked for where the rows under the player's eye change: a search, a source tab, a tick box, and
-- a fresh open of the tab (UIDiscoveries.Show).
local RETAIN_SCROLL = true

local function drawScroll(rows)
  local box = UIDiscoveries.scrollBox
  local create = globalFn("CreateDataProvider")
  if not box or type(box.SetDataProvider) ~= "function" or not create then
    return false
  end
  local ok, provider = pcall(create, rows)
  if not ok or not provider then
    return false
  end
  return (pcall(box.SetDataProvider, box, provider, RETAIN_SCROLL))
end

-- Back to the top of the list, because the rows under the player's eye have just changed.
local function scrollToTop()
  local box = UIDiscoveries.scrollBox
  if type(box) ~= "table" then
    return false
  end
  if type(box.ScrollToBegin) == "function" and pcall(box.ScrollToBegin, box) then
    return true
  end
  if type(box.SetScrollPercentage) == "function" then
    return (pcall(box.SetScrollPercentage, box, 0))
  end
  return false
end

local function poolRow(index)
  local frame = UIDiscoveries.pool[index]
  if frame then
    return frame
  end
  frame = newFrame("Button", UIDiscoveries.content)
  if not frame then
    return nil
  end
  UIDiscoveries.DecorateRow(frame)
  local above = UIDiscoveries.pool[index - 1]
  if above then
    frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
  else
    frame:SetPoint("TOPLEFT", UIDiscoveries.content, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", UIDiscoveries.content, "TOPRIGHT", 0, 0)
  end
  UIDiscoveries.pool[index] = frame
  return frame
end

-- The "and n more" line under a pool that stopped at POOL_ROWS, made the first time it is needed
-- and hung under the last row drawn.
local function drawMoreLine(more, last)
  local line = UIDiscoveries.moreLine
  local text = UIDiscoveries.MoreText(more)
  if text == "" then
    if line then
      line:Hide()
    end
    return false
  end
  if not line then
    line =
      newFontString(UIDiscoveries.content, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
    UIDiscoveries.moreLine = line
    if not line then
      return false
    end
  end
  line:ClearAllPoints()
  if last then
    line:SetPoint("TOPLEFT", last, "BOTTOMLEFT", UIDiscoveries.GUTTER, -UIDiscoveries.PAD)
  else
    line:SetPoint("TOPLEFT", UIDiscoveries.content, "TOPLEFT", UIDiscoveries.GUTTER, -UIDiscoveries.PAD)
  end
  setText(line, text)
  line:Show()
  return true
end

-- The fallback list: the first POOL_ROWS rows in frames of their own, reused draw after draw, and
-- one line counting the rest (PoolPlan). The frames are never more than POOL_ROWS whatever the
-- list holds.
local function drawPool(rows)
  if not UIDiscoveries.content then
    return false
  end
  local limit, more = UIDiscoveries.PoolPlan(rows)
  local drawn = 0
  for index = 1, limit do
    local frame = poolRow(index)
    if not frame then
      break
    end
    UIDiscoveries.InitRow(frame, rows[index])
    drawn = index
  end
  for index = drawn + 1, #UIDiscoveries.pool do
    UIDiscoveries.pool[index].rowModel = nil
    UIDiscoveries.pool[index]:Hide()
  end
  drawMoreLine(more, UIDiscoveries.pool[drawn])
  return true
end

--------------------------------------------------------------------------------
-- The search box, the pane's own: the same debounce as the tree's filter
--------------------------------------------------------------------------------

local function searchFocus(focused)
  local box = UIDiscoveries.search
  local edges = box and rawget(box, "itemTreeEdges") or nil
  if not edges then
    return false
  end
  local key = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
  if focused then
    key = "ITEMTREE_COLOR_STATE_FOCUS"
  end
  return tintEdges(edges, key)
end

-- The placeholder and the clear button both follow whether there is anything in the box.
local function updateSearchChrome(text)
  local box = UIDiscoveries.search
  if not box then
    return false
  end
  local empty = text == nil or text == ""
  local placeholder = rawget(box, "itemTreePlaceholder")
  if placeholder then
    if empty then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end
  local clear = rawget(box, "itemTreeClear")
  if clear then
    if empty then
      clear:Hide()
    else
      clear:Show()
    end
  end
  return true
end

--- The text the list is narrowed by. This is the one way in, whether the box typed it or
--- something else cleared it, so the box is written back to match rather than being left saying
--- something the rows no longer agree with. Returns the filter now in force, nil for none.
function UIDiscoveries.SetTextFilter(text)
  local filter = ""
  if type(text) == "string" then
    filter = text:match("^%s*(.-)%s*$")
  end
  if filter ~= "" then
    UIDiscoveries.filter = filter
  else
    UIDiscoveries.filter = nil
  end
  local box = UIDiscoveries.search
  if box and type(box.GetText) == "function" and type(box.SetText) == "function" then
    local ok, current = pcall(box.GetText, box)
    current = (ok and type(current) == "string") and current or ""
    if current:match("^%s*(.-)%s*$") ~= filter then
      pcall(box.SetText, box, filter)
    end
  end
  UIDiscoveries.searchText = filter
  updateSearchChrome(filter)
  if UIDiscoveries.pane then
    UIDiscoveries.Draw()
    -- Brief RO1: the draw keeps the scroll now, and a search is new rows under the eye.
    scrollToTop()
  end
  return UIDiscoveries.filter
end

--- Narrows the list to one source, or to all of them again. The one way in, so the tab that is
--- lit and the rows always agree: the draw that follows re-words and repaints the row. Anything
--- the row does not offer reads as every row, which is what a value from another build reads as.
--- Returns the filter now in force.
function UIDiscoveries.SetSourceFilter(source)
  local wanted = UIDiscoveries.FILTER_ALL
  for _, value in ipairs(UIDiscoveries.SOURCE_FILTERS) do
    if value == source then
      wanted = value
    end
  end
  UIDiscoveries.sourceFilter = wanted
  if UIDiscoveries.pane then
    UIDiscoveries.Draw()
    -- Brief RO1: as a search does, a source tab starts its rows at the top.
    scrollToTop()
  end
  return wanted
end

-- C_Timer.After holds a keystroke back so a fast typist pays for one pass over the list rather
-- than one per letter; a client with no C_Timer filters on the keystroke itself. The timer reads
-- the text that is current when it fires, so a burst ends in one filter.
local function queueFilter(text)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    local token = (UIDiscoveries.searchToken or 0) + 1
    UIDiscoveries.searchToken = token
    local ok = pcall(timer.After, UIDiscoveries.SEARCH_DEBOUNCE, function()
      if UIDiscoveries.searchToken == token then
        UIDiscoveries.SetTextFilter(UIDiscoveries.searchText or "")
      end
    end)
    if ok then
      return true
    end
  end
  UIDiscoveries.SetTextFilter(text)
  return false
end

--- A keystroke in the search box. Returns whether anything changed, which is false for a write
--- that says what the box already said: the client fires OnTextChanged for its own SetText as
--- well as for a player's typing.
function UIDiscoveries.SetSearchText(text)
  text = type(text) == "string" and text or ""
  updateSearchChrome(text)
  if text == UIDiscoveries.searchText then
    return false
  end
  UIDiscoveries.searchText = text
  queueFilter(text)
  return true
end

--- Escape, or the clear button: the box empties, the filter goes with it and the box gives the
--- keyboard back. Returns whether there was anything to clear.
function UIDiscoveries.ClearSearch()
  local cleared = (UIDiscoveries.searchText or "") ~= ""
  local box = UIDiscoveries.search
  if box and type(box.SetText) == "function" then
    pcall(box.SetText, box, "")
  end
  UIDiscoveries.searchText = ""
  updateSearchChrome("")
  UIDiscoveries.SetTextFilter("")
  if box and type(box.ClearFocus) == "function" then
    pcall(box.ClearFocus, box)
  end
  return cleared
end

-- A script on the box. HookScript is preferred so nothing already there stops working, and a
-- frame that says it does not carry the script is left alone.
local function attachScript(frame, script, handler)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if ok and has == false then
      return false
    end
  end
  if type(frame.HookScript) == "function" and pcall(frame.HookScript, frame, script, handler) then
    return true
  end
  if type(frame.SetScript) == "function" and pcall(frame.SetScript, frame, script, handler) then
    return true
  end
  return false
end

-- The little cross that empties the box, drawn only while there is something in it.
local function buildClearButton(box)
  local button = newFrame("Button", box)
  if not button then
    return nil
  end
  button:SetSize(UIDiscoveries.SEARCH_ICON, UIDiscoveries.SEARCH_ICON)
  button:SetPoint("RIGHT", box, "RIGHT", -UIDiscoveries.GUTTER, 0)
  if type(button.CreateTexture) == "function" then
    local art = button:CreateTexture(nil, "ARTWORK")
    if art then
      art:SetAllPoints(button)
      if Assets and type(Assets.Apply) == "function" then
        pcall(Assets.Apply, art, "ICON_REDX")
      end
      tint(art, "ITEMTREE_COLOR_TEXT_MUTED", 1)
      button.art = art
    end
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  if type(button.SetScript) == "function" then
    button:SetScript("OnClick", function()
      UIDiscoveries.ClearSearch()
    end)
  end
  button:Hide()
  box.itemTreeClear = button
  return button
end

--------------------------------------------------------------------------------
-- Row one: the source tabs, and the search box beside them
--------------------------------------------------------------------------------

-- The numbers the row is laid out with. The window states its own (Frame.ViewTabMetrics) so
-- this row reads as the same strip rather than as a second pane's copy of them; a build whose
-- window will not say falls back to this file's tokens.
local function tabMetrics()
  local box = {
    height = UIDiscoveries.TAB_H,
    width = UIDiscoveries.TAB_W,
    gap = UIDiscoveries.TAB_GAP,
    padding = UIDiscoveries.TAB_PAD,
    minPadding = UIDiscoveries.TAB_PAD_MIN,
  }
  local frame = frameModule()
  if not frame or type(frame.ViewTabMetrics) ~= "function" then
    return box
  end
  local ok, stated = pcall(frame.ViewTabMetrics)
  if not ok or type(stated) ~= "table" then
    return box
  end
  for key in pairs(box) do
    local value = tonumber(stated[key])
    if value and value > 0 then
      box[key] = value
    end
  end
  return box
end

-- The look of one tab where the window will not lend its painter: selected, plain, or dimmed
-- because the tab counts nothing. The same three states and the same colours the window paints,
-- and a dimmed tab keeps its border and its click.
local function paintPlainTab(button, active, empty)
  local box = tabMetrics()
  if type(button.SetHeight) == "function" then
    local height = box.height
    if not active then
      height = math.max(1, height - 2)
    end
    button:SetHeight(height)
  end
  local edge = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
  local text = "ITEMTREE_COLOR_TEXT_MUTED"
  if active then
    edge, text = "ITEMTREE_COLOR_BORDER_GOLD", "ITEMTREE_COLOR_TEXT_TITLE"
  elseif empty then
    edge, text = "ITEMTREE_COLOR_BORDER_DIVIDER", "ITEMTREE_COLOR_TEXT_DISABLED"
  end
  -- This file's own border is a table of four hairlines and the window's is a plain array of
  -- them, because the two files draw an inset edge their own way. Both are tinted, so a window
  -- that lends a builder but no painter is still painted rather than left gold and lit.
  if not tintEdges(button.itemTreeEdges, edge) then
    for _, hairline in ipairs(button.edges or EMPTY) do
      tint(hairline, edge)
    end
  end
  local fill = button.fill or button.background
  if fill then
    local surface = UIDiscoveries.PANEL_SURFACE
    if active then
      surface = "ITEMTREE_COLOR_STATE_SELECTED"
    end
    tint(fill, surface, 1)
  end
  colourText(button.label, text)
  return true
end

-- One tab where the window will not lend its builder: an inset button with a centred label,
-- which is the shape Frame.BuildViewTab makes and the shape paintPlainTab paints.
local function buildPlainTab(parent, text, onClick)
  local button = newFrame("Button", parent)
  if not button then
    return nil
  end
  button:SetSize(UIDiscoveries.TAB_W, UIDiscoveries.TAB_H)
  button.fill = wash(button, "BACKGROUND", UIDiscoveries.PANEL_SURFACE, 1)
  if button.fill then
    button.fill:SetAllPoints(button)
    button.fill:Show()
  end
  button.itemTreeEdges = insetBorder(button, UIDiscoveries.PANEL_BORDER)
  local label = newFontString(button, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  if label then
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    setText(label, text)
    label:Show()
    button.label = label
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  attachScript(button, "OnClick", onClick)
  return button
end

-- One source tab, the window's own where it lends one. The wrappers are read at build time
-- rather than held, so a window that loads after this pane is still asked.
local function buildSourceTab(parent, filter)
  -- E39: voiced on the press, the way the window's own view tabs are, and not in SetSourceFilter,
  -- which the pane also calls itself on a rebuild.
  local onClick = function()
    playCue("tab")
    UIDiscoveries.SetSourceFilter(filter)
  end
  local frame = frameModule()
  if frame and type(frame.BuildViewTab) == "function" then
    local ok, button = pcall(frame.BuildViewTab, parent, UIDiscoveries.FilterLabel(filter), onClick)
    if ok and type(button) == "table" then
      button.itemTreeLentTab = true
      return button
    end
  end
  return buildPlainTab(parent, UIDiscoveries.FilterLabel(filter), onClick)
end

local function paintSourceTab(button, active, empty)
  if type(button) ~= "table" then
    return false
  end
  if rawget(button, "itemTreeLentTab") then
    local frame = frameModule()
    if frame and type(frame.PaintViewTab) == "function" then
      local ok, painted = pcall(frame.PaintViewTab, button, active, empty)
      if ok and painted ~= false then
        return true
      end
    end
  end
  return paintPlainTab(button, active, empty)
end

-- The tabs and the search box share one band: the tabs take what their words need and the box
-- takes the rest, giving way only once it is at its own floor. Frame.ViewRowFit is the window's
-- own arithmetic and is pure, so this row gives way in the same order the view row does; where
-- the window is not loaded each tab is simply its word and its padding.
local function fitTabRow(band, words)
  local box = tabMetrics()
  local frame = frameModule()
  if band > 0 and frame and type(frame.ViewRowFit) == "function" then
    local ok, widths, padding, fits = pcall(
      frame.ViewRowFit,
      band,
      words,
      box.gap,
      box.padding,
      box.minPadding,
      UIDiscoveries.SEARCH_W_MIN,
      UIDiscoveries.ROW_GAP
    )
    if ok and type(widths) == "table" then
      return widths, tonumber(padding) or box.padding, fits ~= false
    end
  end
  local widths = {}
  for index, width in ipairs(words) do
    widths[index] = math.max(tonumber(width) or 0, 0) + 2 * box.padding
  end
  return widths, box.padding, true
end

local function widthOf(frame)
  if type(frame) ~= "table" or type(frame.GetWidth) ~= "function" then
    return 0
  end
  local ok, width = pcall(frame.GetWidth, frame)
  return (ok and tonumber(width)) or 0
end

-- The search box takes the rest of row one: its left edge clear of the tabs by the offset the
-- row worked out, its right edge the row's own. Both points are the row's rather than the last
-- tab's, because a selected tab is drawn two pixels taller than a plain one and a box hung off
-- one would hop up and down the row as the player moved between them.
--
-- The four tick boxes hold the row's right hand end (brief E73, back where E67 had two after E72
-- gave them a row of their own), so the box stops short of them by their widths, the air between
-- them and the row's gap (tickRoom).
--
-- The fit rule: the tick boxes are never squeezed. Their room comes off the row first, at the
-- width their words measure, and the tabs and the search box share what is left in the order
-- Frame.ViewRowFit writes down: the search box shrinks to its floor (SEARCH_W_MIN), then the tabs
-- lose their padding, and only then are tab words cut. The search box is never pushed below its
-- floor or off the row.
--
-- At the window's least width (840) the pane is 776 wide (the content area is inset 32 a side).
-- Measured in the client's body font (Arial Narrow 12), the four boxes are New 44, SoD 43,
-- Changed 64 and Unchanged 74, 261 with the air between them and 269 with the row's gap. That
-- leaves the tabs at full padding and the search box 171 wide with counts in the tens and
-- hundreds; with four figure counts the tabs drop to their least padding and the box gets 197. No
-- tab word is cut. A "Show" caption before the boxes would cost another 37, which would take the
-- tabs off full padding even with small counts, so there is none: each box's hover says what it
-- shows.
local function tickWidth(tick)
  if type(tick) ~= "table" then
    return 0
  end
  local width = tonumber(rawget(tick, "itemTreeWidth")) or 0
  if width <= 0 then
    return 0
  end
  return width
end

local function tickRoom()
  local room, drawn = 0, 0
  for _, class in ipairs(UIDiscoveries.FILTER_CLASSES) do
    local width = tickWidth((UIDiscoveries.filterBoxes or EMPTY)[class])
    if width > 0 then
      room = room + width
      drawn = drawn + 1
    end
  end
  if drawn == 0 then
    return 0
  end
  return room + UIDiscoveries.TICK_SPACING * (drawn - 1) + UIDiscoveries.ROW_GAP
end

local function anchorSearchBox(offset)
  local box, row = UIDiscoveries.search, UIDiscoveries.tabRow
  if not box or not row or type(box.ClearAllPoints) ~= "function" then
    return false
  end
  box:ClearAllPoints()
  box:SetPoint("LEFT", row, "LEFT", math.max(tonumber(offset) or 0, 0), 0)
  box:SetPoint("RIGHT", row, "RIGHT", -tickRoom(), 0)
  return true
end

--- Words the four tabs, measures them and lays the row out, then lights the one the list is
--- narrowed to. counts is a counted list from Core/Discoveries.lua, which is the search box's
--- view of the entries: the tabs say how much of what is being searched each source holds, the
--- same way the window's view tabs follow the tree's own state. Returns how many tabs were
--- drawn, which is none at all before the row is built.
function UIDiscoveries.UpdateTabs(counts)
  local tabs = UIDiscoveries.tabs or EMPTY
  local row = UIDiscoveries.tabRow
  if #tabs == 0 or not row then
    return 0
  end
  local words, empties = {}, {}
  for index, filter in ipairs(UIDiscoveries.SOURCE_FILTERS) do
    local count = UIDiscoveries.TabCount(counts, filter)
    local text = UIDiscoveries.TabLabel(filter, count)
    empties[index] = count <= 0
    local button = tabs[index]
    words[index] = 0
    if button and button.label then
      setText(button.label, text)
      words[index] = textWidth(button.label, text)
    end
  end
  local box = tabMetrics()
  -- The tick boxes' room comes off the band first, so the tabs and the search box share what is
  -- left and give way in their own order before anything reaches the tick boxes (tickRoom).
  local widths, padding, fits = fitTabRow(math.max(widthOf(row) - tickRoom(), 0), words)
  UIDiscoveries.tabRowFit = fits
  local used, previous = 0, nil
  for index, button in ipairs(tabs) do
    local width = math.max(widths[index] or 0, 1)
    if type(button.SetWidth) == "function" then
      button:SetWidth(width)
    end
    if type(button.ClearAllPoints) == "function" then
      button:ClearAllPoints()
      if previous then
        button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", box.gap, 0)
        used = used + box.gap
      else
        button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
      end
    end
    used = used + width
    -- A row too narrow for even the least padding shares what is left between the tabs, and the
    -- word then has to end somewhere: a label with a width of its own is cut by the client's own
    -- ellipsis rather than spilling over the tab beside it.
    if button.label and not fits and type(button.label.SetWidth) == "function" then
      pcall(button.label.SetWidth, button.label, math.max(1, (widths[index] or 0) - 2 * padding))
    end
    paintSourceTab(button, UIDiscoveries.SOURCE_FILTERS[index] == UIDiscoveries.sourceFilter, empties[index])
    if type(button.Show) == "function" then
      button:Show()
    end
    previous = button
  end
  -- Whatever the tabs left is the search box's.
  anchorSearchBox(used + UIDiscoveries.ROW_GAP)
  return #tabs
end

-- Row one itself: a band across the top of the pane, as tall as one tab, holding the four tabs
-- on the left and the search box on the right. The band spans the pane, so everything under it
-- can be hung off the pane's own two edges and the insets match all the way round.
local function buildTabRow(pane)
  local row = newFrame("Frame", pane)
  if not row then
    return nil, EMPTY
  end
  row:SetHeight(tabMetrics().height)
  row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
  row:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
  local tabs = {}
  for index, filter in ipairs(UIDiscoveries.SOURCE_FILTERS) do
    local button = buildSourceTab(row, filter)
    if button then
      tabs[index] = button
    end
  end
  return row, tabs
end

-- The design's SearchBox across the top of the pane: the glyph, the text and the cross, in an
-- inset box one control high. Drawn out of plain frames rather than the client's own
-- SearchBoxTemplate, the way UI/Chain.lua draws everything: nothing here needs a template, so
-- there is no template to fall back from and no border art hanging outside the frame.
--
-- row is the band across the top of the pane, which the box shares with the four source tabs: it
-- starts where they end and runs to the row's own right edge, so it takes whatever they leave
-- and gives way as the window narrows. The row states where the tabs ended (anchorSearchBox) on
-- every draw; until the first one the box has the whole row, exactly as it had the whole pane
-- before the tabs landed.
local function buildSearchBox(row)
  local box = newFrame("EditBox", row)
  if not box then
    return nil
  end
  box:SetHeight(UIDiscoveries.SEARCH_H)
  box:SetPoint("LEFT", row, "LEFT", 0, 0)
  box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  -- The window must not take the keyboard when it opens. Nothing here ever calls SetFocus.
  if type(box.SetAutoFocus) == "function" then
    pcall(box.SetAutoFocus, box, false)
  end
  if type(box.EnableMouse) == "function" then
    box:EnableMouse(true)
  end
  if type(box.SetMultiLine) == "function" then
    pcall(box.SetMultiLine, box, false)
  end
  if type(box.SetFont) == "function" then
    local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
    local ok, applied = pcall(box.SetFont, box, face, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "")
    if not ok or applied == false then
      fallbackFont(box)
    end
  end
  ensureFont(box)
  colourText(box, "ITEMTREE_COLOR_TEXT_BODY")

  local fill = type(box.CreateTexture) == "function" and box:CreateTexture(nil, "BACKGROUND") or nil
  if fill then
    if Assets and type(Assets.Apply) == "function" then
      pcall(Assets.Apply, fill, "FILL_WHITE8X8")
    end
    tint(fill, UIDiscoveries.PANEL_SURFACE, 1)
    fill:SetAllPoints(box)
    fill:Show()
  end
  box.itemTreeEdges = insetBorder(box, UIDiscoveries.PANEL_BORDER)

  local icon = type(box.CreateTexture) == "function" and box:CreateTexture(nil, "ARTWORK") or nil
  if icon then
    icon:SetSize(UIDiscoveries.SEARCH_ICON, UIDiscoveries.SEARCH_ICON)
    icon:SetPoint("LEFT", box, "LEFT", UIDiscoveries.GUTTER, 0)
    if Assets and type(Assets.Apply) == "function" then
      pcall(Assets.Apply, icon, "ICON_SEARCH")
    end
    tint(icon, "ITEMTREE_COLOR_TEXT_MUTED")
    icon:Show()
  end

  local inset = UIDiscoveries.GUTTER * 2 + UIDiscoveries.SEARCH_ICON
  if type(box.SetTextInsets) == "function" then
    pcall(box.SetTextInsets, box, inset, inset, 0, 0)
  end
  buildClearButton(box)

  local placeholder = newFontString(box, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_DISABLED", "LEFT")
  if placeholder then
    placeholder:SetPoint("LEFT", box, "LEFT", inset, 0)
    placeholder:SetPoint("RIGHT", box, "RIGHT", -inset, 0)
    setText(placeholder, UIDiscoveries.PlaceholderText())
    placeholder:Show()
    box.itemTreePlaceholder = placeholder
  end

  attachScript(box, "OnTextChanged", function(self)
    local text = type(self.GetText) == "function" and self:GetText() or ""
    UIDiscoveries.SetSearchText(type(text) == "string" and text or "")
  end)
  attachScript(box, "OnEscapePressed", function(self)
    UIDiscoveries.ClearSearch()
    if type(self.ClearFocus) == "function" then
      pcall(self.ClearFocus, self)
    end
  end)
  attachScript(box, "OnEnterPressed", function(self)
    if type(self.ClearFocus) == "function" then
      pcall(self.ClearFocus, self)
    end
  end)
  attachScript(box, "OnEditFocusGained", function()
    searchFocus(true)
  end)
  attachScript(box, "OnEditFocusLost", function()
    searchFocus(false)
  end)
  return box
end

-- The four tick boxes, one per kind of row (Discoveries.ChangeClass): New, Season of Discovery,
-- Changed and Unchanged. A row shows when the box for its kind is on. New and Season of
-- Discovery start on and the other two off, so the tab opens on new content. Account wide,
-- remembered by Core/Discoveries.lua (Discoveries.ShowKind).
--
-- A find the Discovery Miner makes of a Classic item has no verdict in the data yet: the item was
-- withheld when the data was built, so there was nothing to compare against Classic Era. It
-- counts as unchanged and stays hidden while that box is off, until a later data build can
-- compare it.
--
-- A plain CheckButton drawn from the client's two check box textures through Assets, the way
-- UI/Frame.lua draws its own tick boxes, with the label made under the font rules above. The
-- check mark is shown and hidden by hand, so the art does not depend on the client's template.
local function paintTick(button, checked)
  if type(button) ~= "table" then
    return false
  end
  local check = rawget(button, "check")
  if check then
    if checked then
      check:Show()
    else
      check:Hide()
    end
  end
  if type(button.SetChecked) == "function" then
    pcall(button.SetChecked, button, checked and true or false)
  end
  return true
end

-- One tick box: the words, the one line on hover, and the setting it reads and writes (isOn and
-- setOn, looked up at click time so a spec can swap the model).
local function buildTickBox(row, text, tip, isOn, setOn)
  local button = newFrame("CheckButton", row) or newFrame("Button", row)
  if not button then
    return nil
  end
  local side = UIDiscoveries.TICK_SIZE
  button:SetHeight(side)
  local square = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "ARTWORK") or nil
  if square then
    square:SetSize(side, side)
    square:SetPoint("LEFT", button, "LEFT", 0, 0)
    if not (Assets and type(Assets.Apply) == "function" and pcall(Assets.Apply, square, "CHECKBOX_UP")) then
      tint(square, UIDiscoveries.PANEL_SURFACE, 1)
    end
    square:Show()
    button.square = square
  end
  local check = type(button.CreateTexture) == "function" and button:CreateTexture(nil, "OVERLAY") or nil
  if check then
    check:SetSize(side, side)
    check:SetPoint("CENTER", square or button, "CENTER", 0, 0)
    if not (Assets and type(Assets.Apply) == "function" and pcall(Assets.Apply, check, "CHECKBOX_CHECK")) then
      tint(check, "ITEMTREE_COLOR_BORDER_GOLD", 1)
    end
    check:Hide()
    button.check = check
  end
  local label = newFontString(button, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_BODY", "LEFT")
  if label then
    label:SetPoint("LEFT", button, "LEFT", side + UIDiscoveries.TICK_GAP, 0)
    setText(label, text)
    label:Show()
    button.label = label
  end
  local width = side + UIDiscoveries.TICK_GAP + textWidth(label, text)
  button:SetWidth(width)
  button.itemTreeWidth = width
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  attachScript(button, "OnClick", function()
    local show = not isOn()
    if show then
      playCue("checkOn")
    else
      playCue("checkOff")
    end
    setOn(show)
  end)
  attachScript(button, "OnEnter", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
      return
    end
    tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if type(tooltip.AddLine) == "function" then
      tooltip:AddLine(tip)
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  attachScript(button, "OnLeave", function()
    UIDiscoveries.HideRowTooltip()
  end)
  paintTick(button, isOn())
  button:Show()
  return button
end

--------------------------------------------------------------------------------
-- The pane
--------------------------------------------------------------------------------

-- Anchors a frame under whatever the pane drew above it, or to the top of the pane itself where
-- the client would give us none of it.
--
-- Only the top edge comes from the thing above: both sides come from the pane, every time. The
-- row above may stop short of the pane's right edge, as the search box does now that the source
-- tabs share its band, and a header or a list panel hung off that edge would sit further from
-- the window's border on the right than on the left. One inset, all the way round.
local function anchorUnder(frame, pane, above, gap)
  frame:SetPoint("LEFT", pane, "LEFT", 0, 0)
  frame:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
  if above and above ~= pane then
    frame:SetPoint("TOP", above, "BOTTOM", 0, -gap)
    return true
  end
  frame:SetPoint("TOP", pane, "TOP", 0, 0)
  return false
end

-- The four boxes in the order they are drawn, left to right, with the words beside each and its
-- one line on hover. Each box names only its kind. "SoD" is short for room on the tab row, so its
-- hover says the full name first.
local function filterBoxes()
  return {
    { class = "new", label = L["New"], tip = L["Items Forever added that Classic Era did not have."] },
    { class = "sod", label = L["SoD"], tip = L["Season of Discovery. Items that came from Season of Discovery."] },
    { class = "changed", label = L["Changed"], tip = L["Items Forever has changed against Classic Era."] },
    { class = "unchanged", label = L["Unchanged"], tip = L["Items the data marks unchanged since Classic Era."] },
  }
end

-- The four boxes on the tab row, right aligned to its right hand end: Unchanged at the edge, and
-- each box before it clear of the next one's square by TICK_SPACING, so they read New, SoD,
-- Changed, Unchanged from left to right. Answers the boxes keyed by class.
local function buildFilterBoxes(row)
  local boxes = {}
  local specs = filterBoxes()
  local after = nil
  for index = #specs, 1, -1 do
    local class = specs[index].class
    local button = buildTickBox(row, specs[index].label, specs[index].tip, function()
      return UIDiscoveries.ShowKind(class)
    end, function(show)
      UIDiscoveries.SetShowKind(class, show)
    end)
    if button then
      button.itemTreeClass = class
      if after then
        button:SetPoint("RIGHT", after, "LEFT", -UIDiscoveries.TICK_SPACING, 0)
      else
        button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      end
      boxes[class] = button
      after = button
    end
  end
  return boxes
end

-- The column words over the list, so a character's name and "ItemTree" read as an answer to
-- something. Item, then Source, then When: Source says who saw the item, and it sits beside the
-- words it heads.
--
-- The Source column is sized here, from its own widest word, and every row then draws at that
-- width: the column's token is narrower than "Discovery Miner" measures, so a fixed width would
-- either cut it or crowd the When column at the smallest window.
local function buildColumns(pane, below)
  local row = newFrame("Frame", pane)
  if not row then
    return nil
  end
  row:SetHeight(UIDiscoveries.COLUMN_H)
  anchorUnder(row, pane, below, UIDiscoveries.PAD)

  -- The badge column at the right hand end has no word over it: a heading for the New and
  -- Changed medallions would say what the medallions already say. The room is left all the same,
  -- so "When" sits over the When column rather than over the badges.
  local when = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if when then
    UIDiscoveries.whenW = UIDiscoveries.WhenColumnWidth(measureWith(when))
    when:SetWidth(UIDiscoveries.whenW)
    when:SetPoint("RIGHT", row, "RIGHT", -UIDiscoveries.BadgeInset(), 0)
    setText(when, L["When"])
  end
  local how = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if how then
    UIDiscoveries.howW = UIDiscoveries.SourceColumnWidth(measureWith(how))
    how:SetWidth(UIDiscoveries.howW)
    if when then
      how:SetPoint("RIGHT", when, "LEFT", -UIDiscoveries.GUTTER, 0)
    else
      how:SetPoint("RIGHT", row, "RIGHT", -UIDiscoveries.GUTTER, 0)
    end
    setText(how, L["Source"])
  end
  local item = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if item then
    item:SetPoint("LEFT", row, "LEFT", UIDiscoveries.GUTTER, 0)
    setText(item, L["Item"])
  end
  row.item, row.when, row.how = item, when, how
  return row
end

--- Brief E79: the words on the info line over the list, from the model so the line and the row
--- tooltip's last line cannot drift apart. Pure.
function UIDiscoveries.InfoText()
  local store = model()
  if store and type(store.TIMES_NOTE) == "string" then
    return store.TIMES_NOTE
  end
  return ""
end

-- Brief E79: one muted line between the tab row and the column words, saying what the When
-- column is: the moment ItemTree first saw an item, never the realm's first find.
local function buildInfoLine(pane, below)
  local row = newFrame("Frame", pane)
  if not row then
    return nil
  end
  row:SetHeight(UIDiscoveries.COLUMN_H)
  anchorUnder(row, pane, below, UIDiscoveries.PAD)
  local text = newFontString(row, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if text then
    text:SetPoint("LEFT", row, "LEFT", UIDiscoveries.GUTTER, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -UIDiscoveries.GUTTER, 0)
    setText(text, UIDiscoveries.InfoText())
  end
  row.text = text
  return row
end

-- The muted line under the list, and the inset panel the rows sit in between the two.
local function buildFooter(pane)
  local footer = newFontString(pane, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if not footer then
    return nil
  end
  footer:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", UIDiscoveries.GUTTER, UIDiscoveries.PAD)
  footer:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -UIDiscoveries.GUTTER, UIDiscoveries.PAD)
  setText(footer, "")
  footer:Show()
  return footer
end

local function buildListPanel(pane, below)
  local panel = newFrame("Frame", pane)
  if not panel then
    return nil, nil
  end
  anchorUnder(panel, pane, below, UIDiscoveries.PAD)
  panel:SetPoint("BOTTOM", pane, "BOTTOM", 0, UIDiscoveries.FOOTER_H)
  panel.fill = wash(panel, "BACKGROUND", UIDiscoveries.PANEL_SURFACE, 1)
  if panel.fill then
    panel.fill:SetAllPoints(panel)
    panel.fill:Show()
  end
  panel.border = insetBorder(panel, UIDiscoveries.PANEL_BORDER)

  local content = newFrame("Frame", panel)
  if not content then
    return panel, panel
  end
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", UIDiscoveries.EDGE_W, -UIDiscoveries.EDGE_W)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -UIDiscoveries.EDGE_W, UIDiscoveries.EDGE_W)
  return panel, content
end

-- The empty state: an illustration, the title and the sentence under it, centred in the list and
-- wrapped, because it is prose rather than a row. It has two sets of words (paintEmpty): the
-- model's own for a tab with nothing discovered, and "No filters are on." with a "Reset to
-- default" button under it for a tab whose four boxes are all off. The button is a plain tab
-- (buildPlainTab), so it looks like the source tabs over the list.
local function buildEmpty(host)
  local store = model()
  local block = newFrame("Frame", host)
  if not block then
    return nil
  end
  block:SetPoint("CENTER", host, "CENTER", 0, 0)
  block:SetSize(1, 1)

  local art = type(block.CreateTexture) == "function" and block:CreateTexture(nil, "ARTWORK") or nil
  if art then
    art:SetSize(UIDiscoveries.EMPTY_ICON, UIDiscoveries.EMPTY_ICON)
    art:SetPoint("BOTTOM", block, "TOP", 0, UIDiscoveries.GUTTER)
    local applied = false
    if Assets and type(Assets.Apply) == "function" then
      applied = pcall(Assets.Apply, art, UIDiscoveries.EmptyArt())
    end
    if applied then
      if type(art.SetDesaturated) == "function" then
        pcall(art.SetDesaturated, art, true)
      end
      tint(art, "ITEMTREE_COLOR_TEXT_MUTED")
      art:Show()
    else
      art:Hide()
    end
    block.art = art
  end

  local title = newFontString(block, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_BODY", "CENTER")
  if title then
    title:SetPoint("TOP", block, "TOP", 0, 0)
    if store and type(store.EmptyTitle) == "function" then
      setText(title, store.EmptyTitle())
    end
  end
  local body = newFontString(block, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "CENTER", true)
  if body then
    if title then
      body:SetPoint("TOP", title, "BOTTOM", 0, -UIDiscoveries.GUTTER)
    else
      body:SetPoint("TOP", block, "TOP", 0, 0)
    end
    if type(body.SetWidth) == "function" then
      body:SetWidth(UIDiscoveries.EMPTY_TEXT_W)
    end
    if store and type(store.EmptyText) == "function" then
      setText(body, store.EmptyText())
    end
  end
  local reset = buildPlainTab(block, L["Reset to default"], function()
    playCue("tab")
    UIDiscoveries.ResetFilters()
  end)
  if reset then
    local width = textWidth(reset.label, L["Reset to default"]) + 2 * UIDiscoveries.TAB_PAD
    reset:SetWidth(math.max(width, UIDiscoveries.TAB_W))
    if body then
      reset:SetPoint("TOP", body, "BOTTOM", 0, -UIDiscoveries.GUTTER)
    else
      reset:SetPoint("TOP", block, "BOTTOM", 0, -UIDiscoveries.GUTTER)
    end
    paintPlainTab(reset, false, false)
    reset:Hide()
  end
  block.title, block.body, block.reset = title, body, reset
  block:Hide()
  return block
end

-- Words the empty block for why the list is empty: noneOn for the four boxes all off, which
-- offers the reset button, and otherwise the model's own words for nothing discovered.
local function paintEmpty(block, noneOn)
  local title, body = nil, nil
  if noneOn then
    title, body = L["No filters are on."], L["Tick one above, or go back to the default."]
  else
    local store = model()
    if store and type(store.EmptyTitle) == "function" then
      local ok, words = pcall(store.EmptyTitle)
      title = ok and words or nil
    end
    if store and type(store.EmptyText) == "function" then
      local ok, words = pcall(store.EmptyText)
      body = ok and words or nil
    end
  end
  if block.title and type(title) == "string" then
    setText(block.title, title)
  end
  if block.body and type(body) == "string" then
    setText(block.body, body)
  end
  if block.reset then
    if noneOn then
      block.reset:Show()
    else
      block.reset:Hide()
    end
  end
  return true
end

local function showEmpty(shown, noneOn)
  local block = UIDiscoveries.empty
  if not block then
    return false
  end
  if shown then
    paintEmpty(block, noneOn == true)
    block:Show()
  else
    if block.reset then
      block.reset:Hide()
    end
    block:Hide()
  end
  return true
end

-- What the window's two badge toggles are set to, in the shape Core reads them (badgesNew and
-- badgesChanged). Frame.OptionsFromSettings is asked first: it is where the default for a key
-- nobody has set lives, and it is what the tree and the search dropdown read, so the three
-- cannot disagree about what is switched on. The saved settings are the fallback for a window
-- that will not answer, and nothing at all leaves every badge drawn.
local function badgeOptions()
  local settings = nil
  if type(ItemTree.db) == "table" and type(ItemTree.db.settings) == "table" then
    settings = ItemTree.db.settings
  end
  local frame = frameModule()
  if frame and type(frame.OptionsFromSettings) == "function" then
    local ok, opts = pcall(frame.OptionsFromSettings, settings)
    if ok and type(opts) == "table" then
      return opts
    end
  end
  return settings
end

-- What every row is drawn against: the badge toggles, copied so the saved settings are never
-- written to, and the moment of the player's previous look, which is what a NEW! tag is judged
-- against (Core/Discoveries.lua's IsNew). No previous look in hand, no tags.
local function rowOptions()
  local opts = {}
  local badges = badgeOptions()
  if type(badges) == "table" then
    for key, value in pairs(badges) do
      opts[key] = value
    end
  end
  opts.sinceLast = UIDiscoveries.sinceLast
  -- Rows are built as the list shows them (Discoveries.Rows): the ScrollBox initialises only the
  -- rows on screen, so a long list costs the band pass and not a row model per entry.
  opts.lazy = true
  return opts
end

-- The memo the tick box filter keeps its answers in for the cached list, or nothing where the
-- model has none.
local function changedMemo(store)
  if type(store.ChangedMemo) ~= "function" then
    return nil
  end
  local ok, memo = pcall(store.ChangedMemo)
  if ok and type(memo) == "table" then
    return memo
  end
  return nil
end

-- A list narrowed by the four tick boxes: only the rows whose kind has its box on. Sharing the
-- model's memo, so each entry is judged once per cached list. A model with no filter, or one that
-- raises, leaves the list as it was.
local function applyKindFilter(store, list)
  if type(store.ApplyKindFilter) ~= "function" then
    return list
  end
  local ok, narrowed = pcall(store.ApplyKindFilter, list, UIDiscoveries.ShownKinds(), changedMemo(store))
  if ok and type(narrowed) == "table" then
    return narrowed
  end
  return list
end

-- How many of a list there are, and of each source. Nothing where the model will not say.
local function countsOf(store, entries)
  if type(store.Counts) ~= "function" then
    return nil
  end
  local ok, counts = pcall(store.Counts, entries)
  if ok and type(counts) == "table" then
    return counts
  end
  return nil
end

-- The rows the model says to draw, and the two counts drawn beside them.
--
-- The words narrow the list first and a source tab narrows it after, because the tabs count what
-- the search box left: a tab says how many of what is being searched came from that source, the
-- same way the window's view tabs follow the tree's own state. Answers the rows, the counts over
-- the whole list, which is what the line under it reads, the counts over the searched list after
-- the tick box filter, which is what the tabs wear, and how many rows are being shown.
local function buildRows()
  local store = model()
  if not store then
    UIDiscoveries.entries = EMPTY
    return {}, nil, nil, 0
  end
  local now = clock()
  local entries = EMPTY
  if type(store.Entries) == "function" then
    local ok, list = pcall(store.Entries)
    if ok and type(list) == "table" then
      entries = list
    end
  end
  UIDiscoveries.entries = entries
  local searched = entries
  if UIDiscoveries.filter and type(store.Filter) == "function" then
    local ok, list = pcall(store.Filter, searched, UIDiscoveries.filter)
    if ok and type(list) == "table" then
      searched = list
    end
  end
  -- The tick boxes narrow next, before the tabs are counted: the tabs count only what each would
  -- show, so "All" is the same number as the rows under it. The line under
  -- the list still counts the whole list, and so reads "n of N discovered" while rows are hidden.
  searched = applyKindFilter(store, searched)
  local shown = searched
  if UIDiscoveries.sourceFilter ~= UIDiscoveries.FILTER_ALL and type(store.FilterSource) == "function" then
    local ok, list = pcall(store.FilterSource, shown, UIDiscoveries.sourceFilter)
    if ok and type(list) == "table" then
      shown = list
    end
  end
  local rows = {}
  if type(store.Rows) == "function" then
    -- The badge toggles are read here rather than held, so a click on the window's green New
    -- button reaches the next draw and the rows lose or regain the medallion with it.
    local opts = rowOptions()
    -- Brief P2: the model's stub memo for the cached list, so a keystroke or a tick box hands
    -- the ScrollBox the same lazy rows again rather than building a table per entry.
    if type(store.StubMemo) == "function" then
      local gotMemo, memo = pcall(store.StubMemo)
      if gotMemo and type(memo) == "table" then
        opts.stubs = memo
      end
    end
    local ok, list = pcall(store.Rows, shown, now, dayStart(now), opts)
    if ok and type(list) == "table" then
      rows = list
    end
  end
  return rows, countsOf(store, entries), countsOf(store, searched), #shown
end

--- Redraws from the model. Reads the collector's store and the shipped data through
--- Core/Discoveries.lua and nothing else: no client call about an item is made here.
function UIDiscoveries.Draw()
  local pane = UIDiscoveries.pane
  if not pane then
    return false
  end
  local rows, counts, tabCounts, shown = buildRows()
  UIDiscoveries.rows = rows
  UIDiscoveries.counts, UIDiscoveries.tabCounts = counts, tabCounts
  UIDiscoveries.UpdateTabs(tabCounts)
  for class, box in pairs(UIDiscoveries.filterBoxes or EMPTY) do
    paintTick(box, UIDiscoveries.ShowKind(class))
  end

  local store = model()
  -- A model that will not count its own list still has one, so the empty state follows the
  -- entries themselves where there is no count to read.
  local total = tonumber(counts and counts.total) or #(UIDiscoveries.entries or EMPTY)
  if UIDiscoveries.footer and store and type(store.CountLine) == "function" then
    local visible = nil
    if UIDiscoveries.filter or UIDiscoveries.sourceFilter ~= UIDiscoveries.FILTER_ALL or shown ~= total then
      visible = shown
    end
    local ok, line = pcall(store.CountLine, counts, visible)
    if ok and type(line) == "string" then
      setText(UIDiscoveries.footer, line)
    end
  end
  -- With every box off the list is empty whatever was discovered, and the block says so and
  -- offers the reset; otherwise it shows only for a tab with nothing discovered at all.
  local noneOn = not UIDiscoveries.AnyFilterOn()
  showEmpty(total == 0 or noneOn, noneOn)
  -- The rows are anchored to both edges of the list, so the name column takes whatever is left
  -- between the icon and the two right hand columns and a long name is truncated rather than
  -- pushing them off the edge. The bar is the only thing that moves that edge.
  UIDiscoveries.UpdateScrollBar(rows)

  if UIDiscoveries.mode == "scroll" then
    if drawScroll(rows) then
      return true
    end
    -- A client that took the ScrollBox but will not take a data provider falls back for good,
    -- rather than leaving the list blank.
    UIDiscoveries.mode = "pool"
    UIDiscoveries.content = UIDiscoveries.list
    if UIDiscoveries.scrollBox then
      UIDiscoveries.scrollBox:Hide()
    end
    if UIDiscoveries.scrollBar then
      UIDiscoveries.scrollBar:Hide()
    end
  end
  return drawPool(rows)
end

--------------------------------------------------------------------------------
-- The window's contract
--------------------------------------------------------------------------------

--- Builds the pane inside the region the window created and sized. Idempotent, and false with
--- no client, which leaves Show and Refresh as no ops.
function UIDiscoveries.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  if UIDiscoveries.pane == region and UIDiscoveries.list then
    return true
  end
  if not globalFn("CreateFrame") then
    return false
  end
  UIDiscoveries.pane = region
  UIDiscoveries.pool = {}
  UIDiscoveries.rows, UIDiscoveries.entries = EMPTY, EMPTY
  UIDiscoveries.scrollBox, UIDiscoveries.scrollBar, UIDiscoveries.view = nil, nil, nil
  UIDiscoveries.scrollHost, UIDiscoveries.content, UIDiscoveries.list = nil, nil, nil
  UIDiscoveries.empty, UIDiscoveries.footer, UIDiscoveries.columns = nil, nil, nil
  UIDiscoveries.infoLine = nil
  UIDiscoveries.search, UIDiscoveries.mode = nil, nil
  UIDiscoveries.tabRow, UIDiscoveries.tabs = nil, EMPTY
  UIDiscoveries.filterBoxes = {}
  UIDiscoveries.moreLine = nil
  UIDiscoveries.howW = UIDiscoveries.HOW_W
  UIDiscoveries.whenW = UIDiscoveries.WHEN_W

  -- Row one first, because everything else is hung under it: the four source tabs on the left,
  -- the four tick boxes at the right hand end, and the search box taking what is between them.
  local row, tabs = buildTabRow(region)
  UIDiscoveries.tabRow, UIDiscoveries.tabs = row, tabs
  if row then
    UIDiscoveries.filterBoxes = buildFilterBoxes(row)
    UIDiscoveries.search = buildSearchBox(row)
  end
  local below = row or region
  UIDiscoveries.infoLine = buildInfoLine(region, below)
  UIDiscoveries.columns = buildColumns(region, UIDiscoveries.infoLine or below)
  UIDiscoveries.footer = buildFooter(region)
  local panel, content = buildListPanel(region, UIDiscoveries.columns or below)
  if not panel then
    UIDiscoveries.pane = nil
    return false
  end
  UIDiscoveries.listPanel, UIDiscoveries.list = panel, content
  if buildScrollBox(content) then
    UIDiscoveries.mode = "scroll"
  else
    UIDiscoveries.mode = "pool"
    UIDiscoveries.content = content
  end
  UIDiscoveries.empty = buildEmpty(content)
  -- The row is measured against the pane's own width, so it is measured again whenever that
  -- changes: the window is resizable and nothing else tells this pane that it was dragged. The
  -- tabs are children of the row rather than of the pane, so laying them out cannot change the
  -- width that asked for it. Hooked, so whatever the window already had on the region stays.
  attachScript(region, "OnSizeChanged", function()
    UIDiscoveries.UpdateTabs(UIDiscoveries.tabCounts)
  end)
  -- The window hides the region itself on a tab switch, and the client hides it with the window
  -- when that closes, and neither calls Hide below. Both fire the region's OnHide, which is where
  -- the player's look ends and what they saw is marked seen.
  attachScript(region, "OnHide", function()
    UIDiscoveries.Leave()
  end)
  -- A rebuild gets a box with nothing in it and four tabs with no words, so whatever the pane is
  -- still filtered by is written back into both rather than narrowing the rows for a reason the
  -- player cannot see.
  UIDiscoveries.SetSourceFilter(UIDiscoveries.sourceFilter)
  if UIDiscoveries.filter then
    UIDiscoveries.SetTextFilter(UIDiscoveries.filter)
  end
  return true
end

--- Shows the pane and redraws it. The window hands over its root key, which this pane has no
--- use for: the list is the same whatever the tree is rooted on.
---
--- A look begins here: the moment of the previous one is remembered as sinceLast and nothing is
--- marked seen, so everything newer wears a NEW! tag until the player leaves the tab. The window
--- calls this on every refresh while the tab is up, and only the first call of a look takes the
--- moment, so a find that lands mid look stays new rather than being folded into this one.
--- Brief RO1: a look that starts where the last one ended with the window closing (Leave) is the
--- window coming back, and the list stays where it was scrolled; any other start (the tab
--- pressed, the first look) is a fresh open of the tab and starts at the top.
function UIDiscoveries.Show()
  if not UIDiscoveries.pane then
    return false
  end
  local fresh = not UIDiscoveries.shown and UIDiscoveries.leftWithWindow ~= true
  if not UIDiscoveries.shown then
    UIDiscoveries.leftWithWindow = nil
    local store = model()
    local at = 0
    if store and type(store.SeenAt) == "function" then
      local ok, seen = pcall(store.SeenAt)
      if ok and tonumber(seen) then
        at = tonumber(seen)
      end
    end
    UIDiscoveries.sinceLast = at
  end
  UIDiscoveries.shown = true
  UIDiscoveries.pane:Show()
  UIDiscoveries.WatchMiner()
  local drawn = UIDiscoveries.Draw()
  if fresh then
    scrollToTop()
  end
  return drawn
end

--- Re-reads the model and redraws. A pane that was never attached is a no op.
function UIDiscoveries.Refresh()
  if not UIDiscoveries.pane then
    return false
  end
  return UIDiscoveries.Draw()
end

--- Hides the pane and the tooltip with it, and gives the keyboard back: a hidden edit box that
--- still holds focus swallows the player's keys everywhere else.
function UIDiscoveries.Hide()
  UIDiscoveries.Leave()
  UIDiscoveries.HideRowTooltip()
  local box = UIDiscoveries.search
  if box and type(box.ClearFocus) == "function" then
    pcall(box.ClearFocus, box)
  end
  if not UIDiscoveries.pane then
    return false
  end
  UIDiscoveries.pane:Hide()
  return true
end

--- The end of a look: what the player saw is marked seen with the current time and the tags are
--- put away with it, so the bubble on the tab counts only what arrives after this. A pane that
--- was not showing has nothing to mark, which is what keeps the window's hiding the region at
--- build time, or twice in a row, from marking anything. Answers whether a look ended here.
function UIDiscoveries.Leave()
  if not UIDiscoveries.shown then
    return false
  end
  -- Brief RO1: whether this look ends with the window going down (Escape, the X, the key) rather
  -- than the player moving to another tab, which UIDiscoveries.Show reads to keep the scroll.
  local frame = frameModule()
  local windowUp = false
  if frame and type(frame.IsShown) == "function" then
    local ok, up = pcall(frame.IsShown)
    windowUp = ok and up == true
  end
  UIDiscoveries.leftWithWindow = not windowUp
  UIDiscoveries.shown = false
  UIDiscoveries.sinceLast = nil
  UIDiscoveries.MarkSeen()
  return true
end

--- How many discoveries are newer than the last time the player left the tab, which is the number
--- on the bubble over it. Zero where there is no model, so the window simply draws no bubble.
---
--- The window asks on every refresh, so the answer is remembered against the cached list (the
--- model's CacheVersion), the seen mark and the four tick boxes, and counted again only when
--- one moves.
function UIDiscoveries.UnseenCount()
  UIDiscoveries.WatchMiner()
  local store = model()
  if not store or type(store.UnseenCount) ~= "function" or type(store.Entries) ~= "function" then
    return 0
  end
  local gotEntries, entries = pcall(store.Entries)
  if not gotEntries or type(entries) ~= "table" then
    return 0
  end
  local seenAt = 0
  if type(store.SeenAt) == "function" then
    local ok, at = pcall(store.SeenAt)
    if ok and tonumber(at) then
      seenAt = tonumber(at)
    end
  end
  -- The four boxes as one string, so the memo compares them in one go.
  local shownKinds = UIDiscoveries.ShownKinds()
  local boxes = {}
  for _, class in ipairs(UIDiscoveries.FILTER_CLASSES) do
    boxes[#boxes + 1] = shownKinds[class] and "1" or "0"
  end
  local filters = table.concat(boxes)
  local version = nil
  if type(store.CacheVersion) == "function" then
    local ok, value = pcall(store.CacheVersion)
    version = ok and tonumber(value) or nil
  end
  local all = entries
  local held = UIDiscoveries.unseenMemo
  if
    version
    and type(held) == "table"
    and held.store == store
    and held.entries == all
    and held.version == version
    and held.seenAt == seenAt
    and held.filters == filters
  then
    return held.count
  end
  -- Only what the tab would show is counted: with a tick box unticked, a find of its kind
  -- neither raises the bubble nor wears a NEW! tag.
  entries = applyKindFilter(store, entries)
  local ok, count = pcall(store.UnseenCount, entries, seenAt)
  count = ok and tonumber(count) or 0
  UIDiscoveries.unseenMemo = {
    store = store,
    entries = all,
    version = version,
    seenAt = seenAt,
    filters = filters,
    count = count,
  }
  return count
end

--- Writes down that the player has looked, which is what clears the count. Leave calls this as
--- the player leaves the tab. Returns the moment stored, or nil where there was nowhere to put it.
function UIDiscoveries.MarkSeen()
  local store = model()
  if not store or type(store.MarkSeen) ~= "function" then
    return nil
  end
  local ok, at = pcall(store.MarkSeen, clock())
  if ok and tonumber(at) then
    return tonumber(at)
  end
  return nil
end

--------------------------------------------------------------------------------
-- The Discovery Miner's finds, straight away
--
-- Where the owner's private Discovery Miner is installed its saved global DiscoveryMinerDB is
-- present, and a find it makes should reach this tab on the next draw. Nothing polls the store:
-- one number, store.counts.found, is read every MINER_EVERY seconds while the ItemTree window is
-- shown, on a C_Timer.After chain (the window's own timer of choice), and only when it moved is
-- anything rebuilt. With the Discoveries tab showing, the pane redraws and the find wears a NEW!
-- tag, because it is newer than the look began; nothing is marked seen until the player leaves.
-- On any other tab the window lays its tabs out again, which is what raises the bubble's count.
--
-- Where the global is absent (every player but the owner) nothing is scheduled, nothing is
-- hooked and nothing else is looked up, ever. Nothing here asks the client about an item, and
-- nothing is written to the miner's table.
--------------------------------------------------------------------------------

UIDiscoveries.MINER_EVERY = 2

-- Whether the window is up. Frame.IsShown through pcall; false where there is no window.
local function windowShown()
  local frame = frameModule()
  if not (frame and type(frame.IsShown) == "function") then
    return false
  end
  local ok, shown = pcall(frame.IsShown)
  return ok and shown == true
end

-- The tab labels laid out again with fresh counts. Frame.RefreshTabCounts where the window has
-- one; otherwise Frame.Refresh, the one public path that clears the window's memoised counts,
-- which also hands its panes the model again (a find is rare enough for that to be cheap).
local function relabelTabs()
  local frame = frameModule()
  if not frame then
    return false
  end
  local refresh = frame.RefreshTabCounts
  if type(refresh) ~= "function" then
    refresh = frame.Refresh
  end
  if type(refresh) ~= "function" then
    return false
  end
  return (pcall(refresh))
end

--- One look at the miner's counter. Answers whether anything was refreshed: false where the
--- miner is absent, where the count reads as nothing, and where it has not moved since the last
--- look. The first look only takes the count down, because the window drew what was there.
function UIDiscoveries.MinerTick()
  local store = model()
  if not (store and type(store.MinerStore) == "function" and type(store.MinerFound) == "function") then
    return false
  end
  local okStore, db = pcall(store.MinerStore)
  if not okStore or type(db) ~= "table" then
    return false
  end
  local okFound, found = pcall(store.MinerFound, db)
  if not okFound or type(found) ~= "number" then
    return false
  end
  local last = UIDiscoveries.minerFound
  UIDiscoveries.minerFound = found
  if last == nil or last == found then
    return false
  end
  if UIDiscoveries.shown and UIDiscoveries.pane then
    UIDiscoveries.Draw()
    return true
  end
  relabelTabs()
  return true
end

-- Brief R3: whether the Discoveries tab is switched off (settings.showDiscoveries false). Only an
-- explicit false counts, so a spec or a half loaded client with no saved settings watches as before.
local function tabOff()
  local db = ItemTree.db
  local settings = type(db) == "table" and db.settings or nil
  return type(settings) == "table" and settings.showDiscoveries == false
end

-- Which chain is the live one. UIDiscoveries.StopMiner moves it on, so a look already booked
-- with C_Timer.After finds itself stale when it fires and books nothing more.
UIDiscoveries.minerChain = 0

-- One link of the chain: look, then book the next look while the window is still up. A window
-- that went down ends the chain, and the window's OnShow starts it again. So does the tab being
-- switched off (brief R3), and only its being switched on again and shown starts it.
local function minerStep(chain)
  if chain ~= UIDiscoveries.minerChain then
    return false
  end
  if not windowShown() or tabOff() then
    UIDiscoveries.minerWatching = false
    return false
  end
  UIDiscoveries.MinerTick()
  local timer = rawget(_G, "C_Timer")
  if not (type(timer) == "table" and type(timer.After) == "function") then
    UIDiscoveries.minerWatching = false
    return false
  end
  local booked = pcall(timer.After, UIDiscoveries.MINER_EVERY, function()
    minerStep(chain)
  end)
  if not booked then
    UIDiscoveries.minerWatching = false
    return false
  end
  return true
end

-- Starts the chain where the window is up, the tab is on and it is not already running.
local function startMinerWatch()
  if UIDiscoveries.minerWatching or not windowShown() or tabOff() then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  if not (type(timer) == "table" and type(timer.After) == "function") then
    return false
  end
  UIDiscoveries.minerWatching = true
  local chain = UIDiscoveries.minerChain
  local booked = pcall(timer.After, UIDiscoveries.MINER_EVERY, function()
    minerStep(chain)
  end)
  if not booked then
    UIDiscoveries.minerWatching = false
    return false
  end
  return true
end

--- Brief R3: stops the miner's watch. A look already booked finds its chain stale and books no
--- more; nothing is unhooked, and the window's OnShow starts it again only while the tab is on.
--- Answers whether a watch was running.
function UIDiscoveries.StopMiner()
  local was = UIDiscoveries.minerWatching == true
  UIDiscoveries.minerChain = UIDiscoveries.minerChain + 1
  UIDiscoveries.minerWatching = false
  UIDiscoveries.minerFound = nil
  return was
end

-- The window's OnShow, hooked once so a window opened again restarts the chain. HookScript only,
-- after HasScript, so whatever the window already does on show still runs.
local function hookWindow()
  local frame = frameModule()
  local window = frame and frame.frame
  if type(window) ~= "table" or UIDiscoveries.minerHooked == window then
    return UIDiscoveries.minerHooked == window
  end
  if type(window.HasScript) == "function" then
    local ok, has = pcall(window.HasScript, window, "OnShow")
    if not ok or has ~= true then
      return false
    end
  end
  if type(window.HookScript) ~= "function" then
    return false
  end
  if not pcall(window.HookScript, window, "OnShow", startMinerWatch) then
    return false
  end
  UIDiscoveries.minerHooked = window
  return true
end

--- Starts watching the miner's counter where the miner is installed. Called whenever the window
--- asks this pane for its count and whenever the pane is shown, both of which happen as the
--- window comes up. Answers whether the watch is running. With no miner, only the one global is
--- read and nothing else happens.
function UIDiscoveries.WatchMiner()
  local store = model()
  if not (store and type(store.MinerStore) == "function") then
    return false
  end
  local ok, db = pcall(store.MinerStore)
  if not ok or type(db) ~= "table" then
    return false
  end
  if UIDiscoveries.minerFound == nil and type(store.MinerFound) == "function" then
    local okFound, found = pcall(store.MinerFound, db)
    if okFound and type(found) == "number" then
      UIDiscoveries.minerFound = found
    end
  end
  hookWindow()
  startMinerWatch()
  return UIDiscoveries.minerWatching == true
end

--------------------------------------------------------------------------------
-- The four tick boxes' settings
--------------------------------------------------------------------------------

-- The four kinds in the order the boxes are drawn, for a model that will not say.
UIDiscoveries.FILTER_CLASSES = { "new", "sod", "changed", "unchanged" }
local FALLBACK_SHOWN = { new = true, sod = true }

--- Whether the box for a kind of row is on, from the model's account wide setting. Where there
--- is no model, the box's default: New and Season of Discovery on, Changed and Unchanged off.
function UIDiscoveries.ShowKind(class)
  local store = model()
  if not (store and type(store.ShowKind) == "function") then
    return FALLBACK_SHOWN[class] == true
  end
  local ok, show = pcall(store.ShowKind, class)
  return ok and show == true
end

--- The set of kinds the boxes keep now, { new = true, ... }, in the shape the model filters by.
function UIDiscoveries.ShownKinds()
  local out = {}
  for _, class in ipairs(UIDiscoveries.FILTER_CLASSES) do
    if UIDiscoveries.ShowKind(class) then
      out[class] = true
    end
  end
  return out
end

--- Whether any of the four boxes is on. A model that cannot say is taken as yes, so the pane
--- never offers a reset it cannot explain.
function UIDiscoveries.AnyFilterOn()
  local store = model()
  if not (store and type(store.AnyFilterOn) == "function") then
    return true
  end
  local ok, any = pcall(store.AnyFilterOn, UIDiscoveries.ShownKinds())
  return not ok or any == true
end

-- After a box moves: repaint all four, take the list back to the top and redraw at once, then
-- have the window count its tabs again so the bubble follows.
local function filtersMoved()
  for class, box in pairs(UIDiscoveries.filterBoxes or EMPTY) do
    paintTick(box, UIDiscoveries.ShowKind(class))
  end
  if UIDiscoveries.pane then
    UIDiscoveries.Draw()
    scrollToTop()
  end
  relabelTabs()
end

--- A tick box: writes the setting down and redraws. Answers the setting now in force.
function UIDiscoveries.SetShowKind(class, show)
  local store = model()
  if store and type(store.SetShowKind) == "function" then
    pcall(store.SetShowKind, class, show and true or false)
  end
  filtersMoved()
  return UIDiscoveries.ShowKind(class)
end

--- The "Reset to default" button: the four boxes back to their defaults, and a redraw. Answers
--- the set of kinds now shown.
function UIDiscoveries.ResetFilters()
  local store = model()
  if store and type(store.ResetFilters) == "function" then
    pcall(store.ResetFilters)
  end
  filtersMoved()
  return UIDiscoveries.ShownKinds()
end

--- Brief R3: the tab was switched off. Lets go of everything the pane holds that a draw builds
--- again: the model's cached list (Core/Discoveries.lua Discoveries.Invalidate), the rows, the
--- counts, the bubble's memo and the rows the scroll box or the pooled frames still point at,
--- and stops the miner's watch. The frames themselves stay (a client frame cannot be freed) and
--- are hidden with the tab. Switching the tab on again builds the list afresh on its first draw.
--- Answers true.
function UIDiscoveries.Release()
  UIDiscoveries.StopMiner()
  UIDiscoveries.rows, UIDiscoveries.entries = EMPTY, EMPTY
  UIDiscoveries.counts, UIDiscoveries.tabCounts = nil, nil
  UIDiscoveries.unseenMemo = nil
  UIDiscoveries.sinceLast = nil
  for _, frame in ipairs(UIDiscoveries.pool or EMPTY) do
    frame.rowModel = nil
  end
  local box = UIDiscoveries.scrollBox
  local create = globalFn("CreateDataProvider")
  if box and type(box.SetDataProvider) == "function" and create then
    local ok, provider = pcall(create, {})
    if ok and provider then
      pcall(box.SetDataProvider, box, provider)
    end
  end
  local store = model()
  if store and type(store.Invalidate) == "function" then
    pcall(store.Invalidate)
  end
  return true
end

-- The window builds and attaches the pane, so there is nothing to do at load. Kept because
-- every panel carries an Init.
function UIDiscoveries.Init()
  return false
end

return UIDiscoveries
