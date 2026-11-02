-- The Boss loot tab: dungeons, raids and world bosses by level, their bosses and rare elites, and
-- what each one drops, drawn over the model in Core/BossLoot.lua (ItemTree.BossLoot).
--
-- The tab is registered with the window (Frame.RegisterTab) and its setting with the panel
-- (Options.RegisterSetting) only where the data build carries the BossLoot module
-- (Data:IsOnDemand("BossLoot"), read off Meta, which costs no load), so a build without it has no
-- tab and no setting. The setting, showBossLoot, is on by default.
--
-- Layout: three columns inside the hosted region, each a panel in the window's inset style.
--   Left    the places (about 190 px): band headers "Level 1 to 10" to "Level 51 to 60", then
--           "Endgame (60+)" (level 60 places and every world boss, brief BL28), then
--           "Level unknown", in the tree's category style, and under them the place rows, the name
--           over a muted subtitle ("Dungeon, level 16 to 22", "Raid, 40 players", "World boss,
--           Azshara") with the New mark where the place is new in Forever.
--   Middle  the bosses, rare elites, rares and chests of the chosen place (about 210 px): the name
--           over the rank word and the level, the loot count on the right, New where the
--           encounter is new in Forever. Brief BL23: the count is the rows the Loot pane lists,
--           Predicted rows included, and a boss not new itself that drops an item new in
--           Forever wears a small blue diamond left of it.
--   Right   the rest. A header line (the boss name and the "Creature page" button) and under it
--           a sub region holding a hosted sub pane, Loot, with its own Attach, Show, Refresh,
--           Hide and Release. A later "Map" sub pane is to be a sibling in the same sub region,
--           switched by a small strip over it; neither is built here (UIBossLoot.SUBPANES).
--           The Loot pane draws the Classic Era banner line once, then the type groups in the
--           tree's category style with their counts, then the item rows: icon, name in quality
--           colour, the rate column and the badge cluster the tree draws. Brief BL8: once the
--           player picks a boss that has a creature page, the creature's own column (the model,
--           name, Type, Level and the Predicted line, UI/InfoPanel.lua's builders) sits at the
--           left of the Loot pane at the info column's width and the list takes the rest; the
--           empty states are the tree's own designed block, illustration and all; the item rows
--           follow the Compact rows setting at the tree's heights.
--
-- Each list is a ScrollBox where the client has one, with a variable extent per row, else a pool
-- of POOL_ROWS frames the mouse wheel pages through.
--
-- What is built when (the plan, section 2): the first show builds the index and the place list;
-- a place click reads its bosses straight off the index; a boss click decodes that one boss's
-- loot (M:Loot). Nothing here builds EraSources, its LootIndex or any Items_* module: only the
-- "Creature page" button does, by opening that page because the player asked.
--
-- Release: when the region hides (another tab, or the window closing) the model lets go of every
-- decoded row (M:Release), each list's data provider is emptied and every pooled frame's rowModel
-- is dropped. The place, the boss and the scroll offsets stay in session state (UIBossLoot.state,
-- never saved). If the heap grew by more than the model's threshold since the tab was shown, a
-- ticker runs one pcalled collectgarbage("step", 64) a tick, never in combat, and stops when a
-- step finishes a cycle or after 30 ticks. Never "collect".
--
-- HARD RULE: no item queries. Names, icons and qualities come from the model (the shipped Names
-- module and the collector's records). The one client call about an item is
-- GameTooltip:SetItemByID for the one row under the mouse.
--
-- Contract with UI/Frame.lua: Attach(region) once, Show() whenever the tab is selected (handed the
-- root key, which this pane ignores), Refresh(), Hide(). All no ops with no client.
--
-- The functions above the divider are pure and run under busted with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local UIBossLoot = {}

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local size = Theme.Size

-- The tab, the region it is drawn in, the data module it waits on and the setting that gates it.
UIBossLoot.TAB_NAME = "Boss loot"
UIBossLoot.REGION = "bossloot"
UIBossLoot.MODULE = "BossLoot"
UIBossLoot.SETTING = "showBossLoot"
UIBossLoot.TAB_ICON = "ICON_TAB_BOSSLOOT"
UIBossLoot.TAB_WORD = L["Boss loot"]

-- The window finds a hosted pane by its tab's name, so the module is filed under that name, and
-- under BossLoot for a reader.
ItemTree.UI[UIBossLoot.TAB_NAME] = UIBossLoot
ItemTree.UI.BossLoot = UIBossLoot

UIBossLoot.TAB_SPEC = {
  region = UIBossLoot.REGION,
  icon = UIBossLoot.TAB_ICON,
  setting = UIBossLoot.SETTING,
  -- A browser of its own, like Discoveries: no breadcrumb trail, no diff row, no view row.
  headerRows = { crumbs = false, diffRow = false, viewRow = false },
  -- It draws nothing about the root, so opening an item from it moves to the Tree tab.
  showsRoot = false,
  -- Brief BL8: Tree, Chain, Boss loot, Discoveries, then any developer tab.
  before = "Discoveries",
}

UIBossLoot.SETTING_ENTRY = {
  key = UIBossLoot.SETTING,
  label = L["Show the Boss loot tab"],
  section = L["Feature tabs"],
  kind = "boolean",
  default = true,
  tooltip = L["A tab of what dungeon, raid and world bosses drop, by level."],
}

-- Sizes. Theme tokens where one exists.
UIBossLoot.PLACE_W = 190
UIBossLoot.BOSS_W = 210
UIBossLoot.GAP = size("ITEMTREE_SPACE_2", 8)
UIBossLoot.PAD = size("ITEMTREE_SPACE_1", 4)
UIBossLoot.GUTTER = size("ITEMTREE_LIST_GUTTER", 6)
UIBossLoot.EDGE_W = size("ITEMTREE_BORDER_HAIRLINE", 1)
UIBossLoot.ROW_H = size("ITEMTREE_LIST_ROW_H", 22)
UIBossLoot.BAND_H = size("ITEMTREE_LIST_CATEGORY_H", 24)
-- A place or boss row is two lines: the name over its muted subtitle. No token is this tall.
UIBossLoot.TWO_LINE_H = 34
-- How far in from the row's top the name sits, and from its bottom the subtitle. Brief BL8 closed
-- the gap between the two lines by 4 pixels: this was ITEMTREE_SPACE_1 (4) and is now 6 each side,
-- the row still 34 tall.
UIBossLoot.LINE_INSET = size("ITEMTREE_SPACE_1", 4) + 2
-- The glyph at the left of a band header, the tree's category glyph size.
UIBossLoot.BAND_ICON = size("ITEMTREE_ICON_CATEGORY", 16)
-- The creature panel beside the loot (brief BL8): the info column's own width.
UIBossLoot.CREATURE_W = size("ITEMTREE_LIST_COL_INFO", 180)
UIBossLoot.ICON_SIZE = size("ITEMTREE_LIST_ICON", 20)
UIBossLoot.RATE_W = size("ITEMTREE_LIST_COL_RATE", 56)
UIBossLoot.COUNT_W = size("ITEMTREE_LIST_COL_COUNT", 36)
UIBossLoot.BADGE_SIZE = size("ITEMTREE_BADGE_SIZE_TREE", 16)
UIBossLoot.BADGE_MAX = 3
UIBossLoot.MARK_SIZE = size("ITEMTREE_BADGE_SIZE_LIST", 12)
-- Brief BL26, redrawn by brief BL29: the map button at the far right of a place row is a small
-- square (BL26's 16 px, the category glyph size) drawn as the header's dice button is: the
-- client's red panel button plate (Assets BUTTON_UP, BUTTON_DOWN, BUTTON_HIGHLIGHT, no new art)
-- with a glyph centred on it, the plate's side less MAP_ICON_BEVEL each side. Full strength at
-- rest; the plate's own highlight under the pointer. Brief BL30: the glyph is the flat eye
-- (Assets ICON_VIEW_FLAT) in the Recent button's clock style, drawn untinted; where the client
-- will not draw it, the flat "go to" arrow (MAP_ICON_FALLBACK); where neither draws, the plate
-- alone.
UIBossLoot.MAP_ICON_SIZE = size("ITEMTREE_ICON_CATEGORY", 16)
UIBossLoot.MAP_ICON_BEVEL = 3
UIBossLoot.MAP_ICON_GLYPH = math.max(1, UIBossLoot.MAP_ICON_SIZE - 2 * UIBossLoot.MAP_ICON_BEVEL)
UIBossLoot.MAP_ICON_KEY = "ICON_VIEW_FLAT"
UIBossLoot.MAP_ICON_FALLBACK = "ICON_VIEW_GO"
UIBossLoot.SCROLLBAR_W = size("ITEMTREE_SCROLLBAR_W", 16)
UIBossLoot.FONT_SM = size("ITEMTREE_FONTSIZE_BODY_SM", 11)
UIBossLoot.FONT_MD = size("ITEMTREE_FONTSIZE_BODY_MD", 12)
UIBossLoot.FONT_LG = size("ITEMTREE_FONTSIZE_TITLE_SM", 14)
UIBossLoot.HEADER_H = size("ITEMTREE_CONTROL_H_MD", 24) + 4
UIBossLoot.BANNER_H = size("ITEMTREE_LIST_ROW_H", 22)
UIBossLoot.BANNER_ICON = size("ITEMTREE_ICON_BADGE", 14)
UIBossLoot.BUTTON_W = 108
UIBossLoot.BUTTON_H = size("ITEMTREE_CONTROL_H_SM", 20) + 2
UIBossLoot.EMPTY_ART_W = 120
UIBossLoot.EMPTY_W = 300
UIBossLoot.POOL_ROWS = 40
UIBossLoot.WHEEL_ROWS = 3

UIBossLoot.ROW_TEMPLATE = "BackdropTemplate"
UIBossLoot.FONT_TEMPLATE = "GameFontNormalSmall"
UIBossLoot.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }
UIBossLoot.PANEL_SURFACE = "ITEMTREE_COLOR_SURFACE_INSET"
UIBossLoot.PANEL_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
-- The tree's category row: the sticky surface with the divider hairline, and the body word.
UIBossLoot.BAND_SURFACE = "ITEMTREE_COLOR_SURFACE_STICKY"
UIBossLoot.BAND_EDGE = "ITEMTREE_COLOR_BORDER_DIVIDER"
UIBossLoot.BAND_WORD = "ITEMTREE_COLOR_TEXT_BODY"
-- Brief BL10: the place column's level band headers alone sit on a bevelled bar: the fill, the
-- quest log title highlight's sheen added over it in the same colour, a top line and a dark bottom
-- edge for the bevel, and the words. The glyph sits on a dark keyline square so an item icon's own
-- edge never bleeds into the bar. Brief Q9b took the bar out of the bright gold into the window's
-- palette: the dark brown fill (#4A3A1E), the muted gold top line (ITEMTREE_COLOR_BORDER_GOLD_DIM,
-- #8A7139, opaque), the sheen down to 0.1, and the words in the standard title gold (#FFD100).
-- The two alphas stay the owner's knobs; ui_theme_spec holds the words at 7:1 under the sheen.
UIBossLoot.BAND_GOLD_FILL = "ITEMTREE_COLOR_BAND_FILL"
UIBossLoot.BAND_GOLD_EDGE = "ITEMTREE_COLOR_BAND_EDGE"
UIBossLoot.BAND_GOLD_WORD = "ITEMTREE_COLOR_BAND_WORD"
UIBossLoot.BAND_GOLD_LIGHT = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
UIBossLoot.BAND_GOLD_SHEEN = "BAND_SHEEN"
UIBossLoot.BAND_SHEEN_ALPHA = 0.1
UIBossLoot.BAND_LIGHT_ALPHA = 1
-- Brief BL11: the silver dragon crest straight after a rare elite's or rare's name, and the
-- silver its rank word takes at the top of the row's tooltip.
UIBossLoot.CREST_KEY = "CREST_RARE_ELITE"
UIBossLoot.CREST_GAP = 4
UIBossLoot.RARE_WORD = "ITEMTREE_COLOR_TEXT_RARE_SILVER"
UIBossLoot.CREST_RANKS = { [2] = true, [3] = true }
-- Brief BL12: the creature's portrait at the left of a boss row, square, the row's height less
-- this inset above and below, and this gap before the name.
UIBossLoot.PORTRAIT_INSET = 3
UIBossLoot.PORTRAIT_GAP = 6
-- Brief Q9b, made round by brief BL16: a rare elite's or rare's portrait is a disc, masked round
-- with the client's portrait mask (Assets PORTRAIT_MASK), on a dark disc in the badge backing,
-- framed in a bevelled silver ring. Brief BL21: the ring is ItemTree's own round portrait ring
-- (Assets PORTRAIT_RING, a bevelled band in neutral greys with a transparent middle), tinted the
-- rare silver its crest and rank word wear and drawn RING_SCALE times the portrait's side on the
-- row's overlay, above the portrait and the glyph, so its bevel reads as a frame round the disc
-- and the portrait shows through its open centre. BL16's filled Unverified medallion drew under
-- the portrait, which covered all but a sliver of it. 32 px round the 28 px disc by default and 21
-- round the 18 px disc compact, and never taller than the boss row (TWO_LINE_H, 34 at both
-- densities). Where the client will not mask, the square keeps Q9b's one pixel silver edges
-- (RING_W) just inside its edge.
UIBossLoot.RING_KEY = "PORTRAIT_RING"
UIBossLoot.RING_LAYER = "OVERLAY"
UIBossLoot.RING_SUBLEVEL = 1
UIBossLoot.MASK_KEY = "PORTRAIT_MASK"
UIBossLoot.RING_SCALE = 1.15
UIBossLoot.RING_COLOR = "ITEMTREE_COLOR_TEXT_RARE_SILVER"
UIBossLoot.DISC_COLOR = "ITEMTREE_BADGE_BACKING"
-- Brief BL23: the small blue diamond left of the count on a boss row that is not new itself but
-- drops at least one item new in WoW Forever. No art of its own: a square wash turned 45 degrees
-- (a plain square where the client cannot turn a texture), in the New badge's blue (UI/Badges.lua
-- new.tint), on a square one pixel larger each side in the badge backing, which reads as a thin
-- dark edge. Clearly smaller than the 12 px round New mark and a different shape, so it never
-- reads as "this boss is new". DIAMOND_SIZE is the side at the default row height; compact rows
-- scale it (UIBossLoot.DiamondSize).
UIBossLoot.DIAMOND_SIZE = 7
UIBossLoot.DIAMOND_EDGE = 1
UIBossLoot.DIAMOND_COLOR = "ITEMTREE_COLOR_SEMANTIC_NEW"
UIBossLoot.DIAMOND_EDGE_COLOR = "ITEMTREE_BADGE_BACKING"
UIBossLoot.DIAMOND_ROTATION = math.pi / 4
UIBossLoot.DIAMOND_LAYER = "OVERLAY"
UIBossLoot.RING_W = 1
UIBossLoot.CHEST_RANK = 4
UIBossLoot.EMPTY_ART_KEY = "ART_EMPTY_SOURCES"
UIBossLoot.EMPTY_ART_FALLBACK = "ART_EMPTY_SOURCES_ICON"
-- The selected row (brief BL8), the sidebar's selected category: the list's gold wash at its own
-- alpha, the gold bar on the leading edge, the name in the selected gold and the subtitle in a
-- darker shade of it.
UIBossLoot.SELECTED_FILL = "ITEMTREE_LIST_STATE_SELECTED"
UIBossLoot.SELECTED_EDGE = "ITEMTREE_COLOR_BORDER_GOLD"
UIBossLoot.SELECTED_NAME = "ITEMTREE_COLOR_TEXT_SELECTED"
UIBossLoot.SELECTED_SUB = "ITEMTREE_COLOR_TEXT_SELECTED_MUTED"
UIBossLoot.NAME_WORD = "ITEMTREE_COLOR_TEXT_BODY"
UIBossLoot.SUB_WORD = "ITEMTREE_COLOR_TEXT_MUTED"
-- The band header glyphs (brief BL8), band 1 to 6, then band 7 "Endgame (60+)" (brief BL28), which
-- wears band 6's Thunderfury as no fitting seventh glyph exists, then "Level unknown" (band 8):
-- UI/Assets.lua keys.
UIBossLoot.BAND_ICONS = {
  "ICON_BAND_1",
  "ICON_BAND_2",
  "ICON_BAND_3",
  "ICON_BAND_4",
  "ICON_BAND_5",
  "ICON_BAND_6",
  "ICON_BAND_6",
}
UIBossLoot.BAND_ICON_UNKNOWN = "ICON_BAND_UNKNOWN"
-- What a boss row says at its right where it has no loot count: nothing is known.
UIBossLoot.UNKNOWN_COUNT = "?"
UIBossLoot.BANNER_ART = "BADGE_INFO"

-- The GC ticker (plan section 2, "GC step").
UIBossLoot.GC_INTERVAL = 0.1
UIBossLoot.GC_MAX_TICKS = 30
UIBossLoot.GC_STEP_KB = 64

-- The right column's sub panes, by name, and the one shown. Loot is the only one today; a Map
-- pane is to be a sibling here, under a strip this file does not build yet.
UIBossLoot.SUBPANES = {}
UIBossLoot.SUBPANE_ORDER = { "Loot" }
UIBossLoot.subPane = "Loot"

-- The words the empty states and notes use, as keys, so the specs can name them.
UIBossLoot.WORLD_DROP_NOTE = "World drops are not listed per creature"
UIBossLoot.LOCKED_LINE = "%d not yet found on your realm"
UIBossLoot.ERA_DETAILS_SETTING = "Show Classic Era details for items not yet found"
UIBossLoot.PREDICTED_SETTING = "Show predicted data"

-- Session state: kept while the game runs, never saved. focus is the column the keyboard moves
-- in and cursor the item row it is on in the loot column (brief BL4).
-- creature is the boss whose creature panel the player asked for by picking it (brief BL8).
UIBossLoot.state = {
  place = nil,
  boss = nil,
  creature = nil,
  focus = "places",
  cursor = nil,
  offsets = { places = 0, bosses = 0, loot = 0 },
}

--------------------------------------------------------------------------------
-- Pure: words
--------------------------------------------------------------------------------

-- "level 16 to 22", "level 60" or nil, and the capitalised form where it starts a line.
local function levelWords(lo, hi, capital)
  lo, hi = tonumber(lo), tonumber(hi)
  if lo and hi and lo ~= hi then
    return string.format(capital and L["Level %d to %d"] or L["level %d to %d"], lo, hi)
  end
  local level = lo or hi
  if level then
    return string.format(capital and L["Level %d"] or L["level %d"], level)
  end
  return nil
end

local function join(first, second)
  if first and second then
    return string.format(L["%s, %s"], first, second)
  end
  return first or second
end

--- The muted line under a place's name: "Dungeon, level 16 to 22", "Raid, 40 players",
--- "World boss, Azshara". Pure.
function UIBossLoot.PlaceSubtitle(row)
  if type(row) ~= "table" then
    return ""
  end
  local k = tonumber(row.k)
  if k == 3 then
    local zones = nil
    for _, zone in ipairs(type(row.zones) == "table" and row.zones or EMPTY) do
      if type(zone) == "string" and zone ~= "" then
        zones = join(zones, zone)
      end
    end
    return join(L["World boss"], zones)
  end
  if k == 2 then
    local players = tonumber(row.sz)
    if players then
      return join(L["Raid"], string.format(L["%d players"], players))
    end
    return join(L["Raid"], levelWords(row.lo, row.hi))
  end
  return join(L["Dungeon"], levelWords(row.lo, row.hi))
end

-- Where a place is, "Westfall 42.5, 71.7, Eastern Kingdoms" (Core/BossLoot.lua PlaceWhere), or nil.
local function placeWhere(row)
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) ~= "table" or type(BossLoot.PlaceWhere) ~= "function" then
    return nil
  end
  return BossLoot.PlaceWhere(row)
end

--- The place row's tooltip (brief BL13b): the place's name as the title, then where it is
--- (BossLoot.PlaceWhere, "Westfall, Eastern Kingdoms"), then its kind with the level range and the
--- raid's players ("Dungeon, level 16 to 21", "Raid, level 60, 40 players", "World boss, level
--- 60"), then what the New badge means where the place is new. nil for anything but a place row.
--- Brief BL26: withMap says the row draws its map icon, whose own tooltip says where the place is,
--- so the row's leaves the location line out; a row with no icon keeps it. Pure.
---   { title, lines = { text, ... } }
function UIBossLoot.PlaceTooltip(row, withMap)
  if type(row) ~= "table" or row.kind ~= "place" then
    return nil
  end
  local lines = {}
  local where = not withMap and placeWhere(row) or nil
  if where then
    lines[#lines + 1] = where
  end
  local k = tonumber(row.k)
  local kind = L["Dungeon"]
  if k == 3 then
    kind = L["World boss"]
  elseif k == 2 then
    kind = L["Raid"]
  end
  local line = join(kind, levelWords(row.lo, row.hi))
  -- Only a raid gives its players: a dungeon's MaxPlayers is a legacy cap that reads wrong today.
  local players = k == 2 and tonumber(row.sz) or nil
  if players then
    line = join(line, string.format(L["%d players"], players))
  end
  lines[#lines + 1] = line
  if row.isNew then
    lines[#lines + 1] = L["New in Forever"]
  end
  local name = type(row.name) == "string" and row.name ~= "" and row.name or nil
  return { title = name, lines = lines }
end

--- Brief BL26: what a place row's map icon opens, or nil where the place has no map to show (and
--- the row draws no icon). facts is what the row does not carry itself, each optional:
---
---   area      the place's area id in the index (a)
---   areaName  its AreaTable name where it differs from its own (an)
---   bossKey   for a world boss, the creature page key of its first entry that has one
---
--- A world boss (k = 3) opens its boss's creature page on the Map tab (the spawn points, brief M8)
--- and answers { key, view }. Any other place opens its instance's page on the Map tab, which
--- draws the shipped mouth and portal, or the client's entrance, or the Classic Era stand in, all
--- off the entrance zone: so a place with neither a shipped point nor an entrance zone has no map.
--- It answers { area, names, view }, names being every name the instance's area can be looked up
--- by where the index gives no area (UIBossLoot.PlaceMapKey). Pure.
function UIBossLoot.PlaceMapTarget(row, facts)
  if type(row) ~= "table" or row.kind ~= "place" then
    return nil
  end
  facts = type(facts) == "table" and facts or EMPTY
  local Edges = ItemTree.Edges
  local view = type(Edges) == "table" and Edges.MAP or "map"
  if tonumber(row.k) == 3 then
    if type(facts.bossKey) == "string" and facts.bossKey ~= "" then
      return { key = facts.bossKey, view = view }
    end
    return nil
  end
  local zone = type(row.zone) == "string" and row.zone ~= ""
  if not (zone or type(row.mouth) == "table" or type(row.entrance) == "table") then
    return nil
  end
  local names = {}
  for _, name in ipairs({ row.name, facts.areaName }) do
    if type(name) == "string" and name ~= "" then
      names[#names + 1] = name
    end
  end
  local area = tonumber(facts.area)
  if area and (area <= 0 or area % 1 ~= 0) then
    area = nil
  end
  if not area and #names == 0 then
    return nil
  end
  return { area = area, names = names, view = view }
end

--- Brief BL26: the page key a map target (UIBossLoot.PlaceMapTarget) opens: its own key, else the
--- instance's zone key off its area, else off the first of its names areaIdOf (the Classic Era
--- table's name lookup, asked only on a click) knows. nil where none resolves. Pure.
function UIBossLoot.PlaceMapKey(target, areaIdOf)
  if type(target) ~= "table" then
    return nil
  end
  if type(target.key) == "string" and target.key ~= "" then
    return target.key
  end
  local area = tonumber(target.area)
  if not area and type(areaIdOf) == "function" then
    for _, name in ipairs(type(target.names) == "table" and target.names or EMPTY) do
      local found = tonumber(areaIdOf(name))
      if found and found > 0 and found % 1 == 0 then
        area = found
        break
      end
    end
  end
  if not area then
    return nil
  end
  local Graph = ItemTree.Graph
  if type(Graph) == "table" and type(Graph.Key) == "function" then
    local ok, key = pcall(Graph.Key, "zone", area)
    if ok and type(key) == "string" then
      return key
    end
  end
  return string.format("zone:%d", area)
end

--- Brief BL26: the one line the map icon's tooltip gives, where the place is (BossLoot.PlaceWhere),
--- or "Map" where nothing is known. Pure.
function UIBossLoot.PlaceMapLine(row)
  return placeWhere(row) or L["Map"]
end

--- Brief BL26: how much of a place row's right hand end the name and subtitle keep clear of: the
--- New badge's slot (always kept, as before), and the map icon's beside it where the row has one.
--- Pure.
function UIBossLoot.PlaceRightWidth(withMap)
  local width = UIBossLoot.MARK_SIZE + UIBossLoot.PAD
  if withMap then
    width = width + UIBossLoot.MAP_ICON_SIZE + UIBossLoot.PAD
  end
  return width
end

--- The muted line under a boss's name: "Rare elite, level 12 to 14", "Level 24", "Chest", or "".
--- Pure.
function UIBossLoot.BossMeta(row)
  if type(row) ~= "table" then
    return ""
  end
  local rank = type(row.rankWord) == "string" and row.rankWord or nil
  if rank then
    return join(rank, levelWords(row.lo, row.hi)) or ""
  end
  return levelWords(row.lo, row.hi, true) or ""
end

--- Whether a boss row wears the silver dragon crest (brief BL11): a rare elite (r 2) or a rare
--- (r 3). A boss is what the column is and a chest is not a creature, so neither does. Pure.
function UIBossLoot.WearsCrest(row)
  return type(row) == "table" and UIBossLoot.CREST_RANKS[tonumber(row.r) or 0] == true
end

--- The crest's side for a name drawn at this font size: the name's line height, which is the font
--- size and a pixel above and below. Pure.
function UIBossLoot.CrestSize(fontSize)
  return math.floor(tonumber(fontSize) or UIBossLoot.FONT_MD) + 2
end

--- Where the crest goes, measured from the name's left edge: straight after the words and a gap,
--- or, where the words are wider than the room the name has (room already less the crest and its
--- gap), after the room, where the client has cut the name short. room 0 or none is a row not
--- sized yet, and the words' own width stands. Pure.
function UIBossLoot.CrestOffset(textWidth, room)
  textWidth = math.max(0, tonumber(textWidth) or 0)
  room = tonumber(room) or 0
  if room > 0 and textWidth > room then
    textWidth = room
  end
  return math.floor(textWidth + 0.5) + UIBossLoot.CREST_GAP
end

--- Whether a boss row's portrait square wears the silver ring (brief Q9b): the rows that wear the
--- crest, a rare elite (r 2) or a rare (r 3). A boss and a chest wear none. Pure.
function UIBossLoot.WearsRing(row)
  return UIBossLoot.WearsCrest(row)
end

--- The silver ring's side round a portrait disc of this side (brief BL16): RING_SCALE times it,
--- to the nearest whole pixel and never smaller than the disc; 0 for no disc. Brief BL21: never
--- taller than the boss row it sits in (TWO_LINE_H), so it cannot reach the rows above and below.
--- Pure.
function UIBossLoot.RingSize(side)
  side = tonumber(side) or 0
  if side <= 0 then
    return 0
  end
  local ring = math.max(side, math.floor(side * UIBossLoot.RING_SCALE + 0.5))
  return math.max(side, math.min(ring, UIBossLoot.TWO_LINE_H))
end

--- The tooltip a boss row shows on hover (brief BL11): for a rare elite or a rare, the rank word as
--- its first line in the rare silver; nil for every other row, which shows none. Pure.
---   { title, titleKey, lines }
function UIBossLoot.RankTooltip(row)
  if not UIBossLoot.WearsCrest(row) or type(row.rankWord) ~= "string" or row.rankWord == "" then
    return nil
  end
  return { title = row.rankWord, titleKey = UIBossLoot.RARE_WORD, lines = {} }
end

--- Whether the boss rows draw portraits (brief BL12): the bossPortraits setting, on by default.
--- An explicit if, because a nil setting is the default and not the off answer. Pure over the db.
function UIBossLoot.PortraitsEnabled()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" and settings.bossPortraits == false then
    return false
  end
  return true
end

--- The portrait's side on a boss row at a density: the two line row's height less the inset above
--- and below, or the compact row height where Compact rows is on. Pure.
function UIBossLoot.PortraitSize(density)
  if density == "compact" then
    return UIBossLoot.ItemLayout("compact").height
  end
  return UIBossLoot.TWO_LINE_H - 2 * UIBossLoot.PORTRAIT_INSET
end

--- The CreatureDisplayInfo id a boss row's portrait is drawn from: the index entry's cd, a whole
--- positive number, or nil. Pure.
function UIBossLoot.PortraitOf(entry)
  local display = type(entry) == "table" and entry.cd or nil
  if type(display) ~= "number" or display <= 0 or display ~= math.floor(display) then
    return nil
  end
  return display
end

--- The glyph a boss row draws in the portrait's square until the portrait comes, or for good where
--- the entry has no cd: the creature type's glyph the creature panel wears (ViewModel.CreatureIcon
--- over ct), nil for a chest or an entry with no type. Pure.
function UIBossLoot.PortraitGlyph(entry)
  if type(entry) ~= "table" or tonumber(entry.r) == UIBossLoot.CHEST_RANK then
    return nil
  end
  local creatureType = tonumber(entry.ct)
  local ViewModel = ItemTree.ViewModel
  if not creatureType or type(ViewModel) ~= "table" or type(ViewModel.CreatureIcon) ~= "function" then
    return nil
  end
  local ok, key = pcall(ViewModel.CreatureIcon, { type = creatureType })
  if ok and type(key) == "string" and key ~= "" then
    return key
  end
  return nil
end

--- Brief C4: the ranks a Creatures row's classification stands for where an entry states none:
--- a boss (k 3), a rare elite (k 2) and a rare (k 4). Normal and elite say nothing here.
UIBossLoot.CREATURES_RANKS = { [3] = 1, [2] = 2, [4] = 3 }

--- Brief C4: an index entry with a creature id (c) but no creature type (ct), no display id (cd)
--- or no rank (r) filled from the Creatures data (Core/Creatures.lua, the creatures testers have
--- met): ct from its type, r from its classification, and creaturesDisplay, the portrait's
--- display id, from its first display id. A copy where anything was filled, the entry itself
--- otherwise. cd is never set, so the panel's model stays the model loader's. Builds the
--- Creatures module only for an entry that lacks one of the three.
function UIBossLoot.WithCreaturesRow(entry)
  if type(entry) ~= "table" or (entry.ct ~= nil and entry.cd ~= nil and entry.r ~= nil) then
    return entry
  end
  local id = type(entry.c) == "table" and tonumber(entry.c[1]) or nil
  local Creatures = ItemTree.Creatures
  if not id or type(Creatures) ~= "table" or type(Creatures.Get) ~= "function" then
    return entry
  end
  local ok, row = pcall(Creatures.Get, id)
  if not ok or type(row) ~= "table" then
    return entry
  end
  local fill = {}
  if entry.ct == nil and row.typeId then
    fill.ct = row.typeId
  end
  if entry.r == nil and UIBossLoot.CREATURES_RANKS[row.classification or -1] then
    fill.r = UIBossLoot.CREATURES_RANKS[row.classification]
  end
  local display = type(row.displays) == "table" and row.displays[1] or nil
  if entry.cd == nil and UIBossLoot.PortraitOf({ cd = display }) then
    fill.creaturesDisplay = display
  end
  if next(fill) == nil then
    return entry
  end
  local copy = {}
  for field, value in pairs(entry) do
    copy[field] = value
  end
  for field, value in pairs(fill) do
    copy[field] = value
  end
  return copy
end

--- The loot count on a boss row, "" for none. Pure.
function UIBossLoot.CountText(count)
  count = tonumber(count) or 0
  if count <= 0 then
    return ""
  end
  return tostring(math.floor(count))
end

--- What a boss row draws at its right (brief BL8): the loot count, or "?" where there is none, so
--- every row has something there. Pure.
function UIBossLoot.BossCountText(count)
  local text = UIBossLoot.CountText(count)
  if text == "" then
    return UIBossLoot.UNKNOWN_COUNT
  end
  return text
end

--- The Assets key a band header wears (brief BL8): ICON_BAND_1 to ICON_BAND_6 for the level bands,
--- ICON_BAND_6 again for band 7, "Endgame (60+)" (brief BL28), and ICON_BAND_UNKNOWN for band 8,
--- "Level unknown", or anything else. Pure.
function UIBossLoot.BandIcon(band)
  local key = UIBossLoot.BAND_ICONS[tonumber(band) or 0]
  return key or UIBossLoot.BAND_ICON_UNKNOWN
end

-- "Turn on Show predicted data in the settings to see them."
local function turnOn(settingKey)
  return string.format(L["Turn on %s in the settings to see them."], L[settingKey])
end

local function nothingKnownWords()
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) == "table" and type(BossLoot.NothingKnown) == "function" then
    return BossLoot.NothingKnown()
  end
  return L["Nothing known yet"], L["ItemTree lists what you loot here as you play"]
end

--- What the right column says in place of a list, or nil where it draws one. hasPlace is whether
--- a place is chosen; answer is the model's M:Loot for the chosen boss (nil for none).
---
---   { title, line, art, note }
---
--- The plan's table: no place chosen; nothing known about the boss (owner answer a); everything
--- locked (the D5 count and the setting's name); predicted data hidden with no verified rows (the
--- setting's name); and the world drop footnote as the note wherever w > 0. Brief BL8: an entry
--- the index knows only as w world drops (no loot records of its own, nothing the player saw) says
--- so in its own words, the boss's name and w in the line and the "as you play" line as the note,
--- and "Nothing known yet" is kept for an entry with neither. Brief BL9: the tree's empty state
--- illustration (art) is for the states where nothing is known, no place chosen and "Nothing known
--- yet" (with or without the footnote). Where sources exist but none is listed (world drops only,
--- predicted data hidden, rows locked) the state is text only (art false). Every state is laid out
--- the way the tree lays its own. Pure.
function UIBossLoot.EmptyState(answer, hasPlace)
  if type(answer) ~= "table" then
    if not hasPlace then
      return { title = L["Choose a dungeon, raid or world boss"], art = true }
    end
    local title, line = nothingKnownWords()
    return { title = title, line = line, art = true }
  end
  local worldDrops = tonumber(answer.worldDrops) or 0
  local note = nil
  if worldDrops > 0 then
    note = L[UIBossLoot.WORLD_DROP_NOTE]
  end
  local rows = type(answer.rows) == "table" and answer.rows or EMPTY
  if #rows > 0 then
    return nil
  end
  local locked = tonumber(answer.locked) or 0
  local hidden = tonumber(answer.predictedHidden) or 0
  if answer.nothingKnown and worldDrops > 0 then
    local boss = type(answer.boss) == "table" and answer.boss or EMPTY
    local name = type(boss.name) == "string" and boss.name ~= "" and boss.name or L["Unknown creature"]
    local _, asYouPlay = nothingKnownWords()
    return {
      title = L["Only world drops in Classic Era"],
      line = string.format(
        L["%s's %d items are shared with many creatures, so none is listed here"],
        name,
        math.floor(worldDrops)
      ),
      note = asYouPlay,
      art = false,
    }
  end
  if answer.nothingKnown or (locked == 0 and hidden == 0) then
    local title, line = nothingKnownWords()
    return { title = title, line = line, note = note, art = true }
  end
  if hidden > 0 then
    return {
      title = L["Predicted data is hidden"],
      line = turnOn(UIBossLoot.PREDICTED_SETTING),
      note = note,
      art = false,
    }
  end
  return {
    title = string.format(L[UIBossLoot.LOCKED_LINE], locked),
    line = turnOn(UIBossLoot.ERA_DETAILS_SETTING),
    note = note,
    art = false,
  }
end

--- The empty state as the tree's designed block takes it (UI/Tree.lua Tree.EmptyBlock): the title
--- as the heading and the line and the note, where there are, as the paragraph under it, and art
--- false for a text only state (UIBossLoot.EmptyLayout reads it; the tree ignores it). Pure.
function UIBossLoot.EmptySpec(empty)
  if type(empty) ~= "table" then
    return nil
  end
  local lines = {}
  for _, text in ipairs({ empty.line, empty.note }) do
    if type(text) == "string" and text ~= "" then
      lines[#lines + 1] = text
    end
  end
  local spec = { heading = empty.title, lines = lines }
  if empty.art == false then
    spec.art = false
  end
  return spec
end

--- The right column's list for one answer: a group header per type group, its item rows, then
--- the notes (predicted rows left out, locked rows left out, world drops not listed). Also
--- answers whether any Classic Era row is drawn, which is what the banner is for. Pure.
---
---   { kind = "group", word, count, type }
---   { kind = "item", id, item }            item is the model's row
---   { kind = "note", text }
function UIBossLoot.LootRows(answer)
  local out, anyEra = {}, false
  if type(answer) ~= "table" then
    return out, anyEra
  end
  for _, group in ipairs(type(answer.groups) == "table" and answer.groups or EMPTY) do
    out[#out + 1] = { kind = "group", word = group.word, count = group.count, type = group.type }
    for _, row in ipairs(type(group.rows) == "table" and group.rows or EMPTY) do
      out[#out + 1] = { kind = "item", id = row.id, item = row }
      -- A guessed row (brief GS5) is not Classic Era data, so it never calls for the banner, and
      -- nor is a community drop (brief DL1).
      if not row.verified and row.guess == nil and not row.community then
        anyEra = true
      end
    end
  end
  if #out > 0 then
    if (tonumber(answer.predictedHidden) or 0) > 0 then
      out[#out + 1] = { kind = "note", text = L["Predicted data is hidden"] }
    end
    if (tonumber(answer.locked) or 0) > 0 then
      out[#out + 1] = { kind = "note", text = string.format(L[UIBossLoot.LOCKED_LINE], answer.locked) }
    end
    if (tonumber(answer.worldDrops) or 0) > 0 then
      out[#out + 1] = { kind = "note", text = L[UIBossLoot.WORLD_DROP_NOTE] }
    end
  end
  return out, anyEra
end

--- The banner line over the loot, the tree's own words (Tree.EraBanner), or nil where the tree
--- cannot be asked. { text, lines }.
function UIBossLoot.EraBanner()
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  if type(Tree) ~= "table" or type(Tree.EraBanner) ~= "function" then
    return nil
  end
  local ok, banner = pcall(Tree.EraBanner, { { source = { historical = true } } })
  if ok and type(banner) == "table" and type(banner.text) == "string" then
    return banner
  end
  return nil
end

--- The marks an item row wears: the New and Changed badges the model worked out, and the
--- confidence mark (Predicted for a Classic Era row, Verified for one the collector saw). Pure.
function UIBossLoot.ItemKinds(row)
  local kinds = {}
  if type(row) ~= "table" then
    return kinds
  end
  for _, kind in ipairs(type(row.badges) == "table" and row.badges or EMPTY) do
    kinds[#kinds + 1] = kind
  end
  if type(row.confidence) == "string" then
    kinds[#kinds + 1] = row.confidence
  end
  return kinds
end

--------------------------------------------------------------------------------
-- Pure: guessed loot (brief GS5)
--------------------------------------------------------------------------------

-- The type code of the group the guessed rows sit in, after every type group of known loot.
UIBossLoot.GUESS_GROUP = "guess"

-- The rate column and the tooltip line of a guessed row: the tier's word, and the Sources view's
-- own guess lines (the strength, the why and the one line that says it is a guess).
local function guessRate(row)
  local GuessSources = ItemTree.GuessSources
  row.rate = type(GuessSources) == "table" and GuessSources.LABEL or L["Guess"]
  local Sources = ItemTree.Sources
  if type(Sources) ~= "table" or type(Sources.GuessFacts) ~= "function" then
    return
  end
  local ok, facts = pcall(Sources.GuessFacts, row)
  if not ok or type(facts) ~= "table" then
    return
  end
  local lines = {}
  for _, line in ipairs({ facts.strengthLine or false, facts.whyLine or false, facts.line or false }) do
    if line then
      lines[#lines + 1] = line
    end
  end
  if #lines > 0 then
    row.rateTip = table.concat(lines, "\n")
  end
end

--- Brief GS5: the Predicted rows of a boss entry, with the rate column and its tooltip line each
--- (guessRate). Brief Z4: the rows themselves are Core/BossLoot.lua BossLoot.GuessRows', which a
--- zone page's Here tab lists too; see there for which guesses are listed and in what order.
---
---   { id, name, quality, icon, era, type, ilvl, verified = false, seen = 0, guess, confidence,
---     basis, rate, rateTip, badges }
function UIBossLoot.GuessRows(entry, known)
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) ~= "table" or type(BossLoot.GuessRows) ~= "function" then
    return {}
  end
  local rows = BossLoot.GuessRows(entry, known)
  for _, row in ipairs(rows) do
    guessRate(row)
  end
  return rows
end

--- Brief GS5: an answer with the guessed rows after all its known loot, as one more group, the
--- Predicted group, counted on its own header. The model's answer is held in its cache, so it is
--- never changed: a new table is answered where there are guesses, and the answer itself where
--- there are none. Brief BL23: the boss row's count follows this answer (UIBossLoot.LootSummary),
--- the Predicted rows included. Pure.
function UIBossLoot.WithGuesses(answer, guessRows)
  if type(answer) ~= "table" or type(guessRows) ~= "table" or #guessRows == 0 then
    return answer
  end
  local out = {}
  for key, value in pairs(answer) do
    out[key] = value
  end
  local rows, groups = {}, {}
  for _, row in ipairs(type(answer.rows) == "table" and answer.rows or EMPTY) do
    rows[#rows + 1] = row
  end
  for _, group in ipairs(type(answer.groups) == "table" and answer.groups or EMPTY) do
    groups[#groups + 1] = group
  end
  for _, row in ipairs(guessRows) do
    rows[#rows + 1] = row
  end
  groups[#groups + 1] = { type = UIBossLoot.GUESS_GROUP, word = L["Predicted"], count = #guessRows, rows = guessRows }
  out.rows = rows
  out.groups = groups
  out.guessed = #guessRows
  out.nothingKnown = false
  return out
end

--------------------------------------------------------------------------------
-- Pure: layout
--------------------------------------------------------------------------------

--- The three column widths for a region this wide: places, bosses and the rest (never below 0).
--- Pure.
function UIBossLoot.ColumnWidths(width)
  width = math.max(tonumber(width) or 0, 0)
  local left, middle = UIBossLoot.PLACE_W, UIBossLoot.BOSS_W
  local right = math.max(0, width - left - middle - 2 * UIBossLoot.GAP)
  return left, middle, right
end

--- The row density the tree draws at (brief BL8): "compact" where the settings say so (the
--- footer's Compact rows box and the panel's Display row write it), else "default". The same read
--- as UI/Tree.lua Tree.Density. Pure over ItemTree.db.
function UIBossLoot.Density()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" and settings.density == "compact" then
    return "compact"
  end
  return "default"
end

-- An item row's height at a density: Theme.RowHeight, the tree's own rule (22, or 18 compact).
local function itemRowHeight(density)
  if Theme and type(Theme.RowHeight) == "function" then
    local ok, height = pcall(Theme.RowHeight, density)
    if ok and tonumber(height) then
      return tonumber(height)
    end
  end
  if density == "compact" then
    return size("ITEMTREE_LIST_ROW_H_COMPACT", 18)
  end
  return UIBossLoot.ROW_H
end

--- How tall one row of any column is drawn. The loot column's item rows and notes follow the
--- density the tree draws at (density, else UIBossLoot.Density()); its type group bars keep the
--- tree's category height, which the tree keeps at both densities too. Pure.
function UIBossLoot.RowExtent(row, density)
  local kind = type(row) == "table" and row.kind or nil
  if kind == "band" or kind == "group" then
    return UIBossLoot.BAND_H
  end
  if kind == "place" or kind == "boss" then
    return UIBossLoot.TWO_LINE_H
  end
  return itemRowHeight(density or UIBossLoot.Density())
end

--- An item row's parts at a density, the tree's own rule (UI/Tree.lua Tree.Layout and
--- Tree.IconSize): the row height, an icon that gives back the two pixels its edge needs on a
--- compact row, and the name in the small body size when compact. Pure.
---
---   { height, icon, font }
function UIBossLoot.ItemLayout(density)
  density = density == "compact" and "compact" or "default"
  local height = itemRowHeight(density)
  local room = height - 2 * UIBossLoot.EDGE_W
  local icon = UIBossLoot.ICON_SIZE
  if room > 0 then
    icon = math.min(icon, room)
  end
  local font = UIBossLoot.FONT_MD
  if density == "compact" then
    font = UIBossLoot.FONT_SM
  end
  return { height = height, icon = icon, font = font }
end

--- How the Loot sub pane shares its width (brief BL8): the creature panel at the info column's
--- width on the left where a boss's panel is up, a gap, and the loot list the rest; the list alone
--- otherwise. Answers the panel's width (0 for none) and the list's left edge. Pure.
function UIBossLoot.LootSplit(width, withCreature)
  width = math.max(tonumber(width) or 0, 0)
  if not withCreature then
    return 0, 0
  end
  local panel = UIBossLoot.CREATURE_W
  if width > 0 then
    panel = math.min(panel, width)
  end
  return panel, panel + UIBossLoot.GAP
end

--- Where the pool fallback's window over the rows starts, clamped. Pure.
function UIBossLoot.PoolOffset(total, offset, rows)
  total, offset, rows = tonumber(total) or 0, tonumber(offset) or 0, tonumber(rows) or 1
  local most = math.max(0, total - rows)
  return math.max(0, math.min(math.floor(offset), most))
end

--------------------------------------------------------------------------------
-- Pure: the creature panel's content (brief BL8)
--------------------------------------------------------------------------------

--- Brief BL20: a name as the naming rule compares it: lower case, trimmed, and the curly
--- apostrophes and the backtick read as a plain one, so "Mar'li" typed either way agrees.
--- nil for no name. Pure.
function UIBossLoot.FoldName(text)
  if type(text) ~= "string" then
    return nil
  end
  local folded = string.lower(text)
  folded = (folded:gsub("\226\128\152", "'"))
  folded = (folded:gsub("\226\128\153", "'"))
  folded = (folded:gsub("`", "'"))
  folded = folded:match("^%s*(.-)%s*$")
  if folded == "" then
    return nil
  end
  return folded
end

--- Brief BL20: the name a boss is shown by. entry is { name, c }: the entry's own name (the
--- client's encounter name, read off the index's strings) and its creature ids. Where the entry
--- has a creature id and that creature's name (creatureName) is known and differs from the
--- entry's (UIBossLoot.FoldName), the creature's name; else the entry's. The client's
--- DungeonEncounter list names Hall of Thanes' second boss "Infurnus", but the creature is
--- Magmatus (261316). Pure.
function UIBossLoot.DisplayName(entry, creatureName)
  if type(entry) ~= "table" then
    return nil
  end
  local name = type(entry.name) == "string" and entry.name or nil
  local id = type(entry.c) == "table" and tonumber(entry.c[1]) or nil
  local folded = UIBossLoot.FoldName(creatureName)
  if not id or not folded or folded == UIBossLoot.FoldName(name) then
    return name
  end
  return (creatureName:match("^%s*(.-)%s*$"))
end

--- Brief BL20: the creature's own name for an index entry (its b table, c the creature ids), or
--- nil: the Creatures data's name for its first creature id (Core/Creatures.lua, which builds the
--- module on this first ask), else the name on the collector's seen boss record (seen) where the
--- record's npcId is one of the entry's creatures. A later data build that ships the name on the
--- entry itself (cn, an index into the index's strings like n) would be read first.
function UIBossLoot.CreatureNameFor(entry, seen)
  local ids = type(entry) == "table" and type(entry.c) == "table" and entry.c or nil
  local id = ids and tonumber(ids[1]) or nil
  if not id then
    return nil
  end
  local Creatures = ItemTree.Creatures
  if type(Creatures) == "table" and type(Creatures.Name) == "function" then
    local ok, name = pcall(Creatures.Name, id)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  if type(seen) ~= "table" or type(seen.name) ~= "string" or seen.name == "" then
    return nil
  end
  local npcId = tonumber(seen.npcId)
  for _, creatureId in ipairs(ids) do
    if npcId and tonumber(creatureId) == npcId then
      return seen.name
    end
  end
  return nil
end

--- Brief BL23: the diamond's side at a density: DIAMOND_SIZE at the default row height, scaled
--- by the compact row height over the default one where Compact rows is on, and never under 4 px.
--- Pure.
function UIBossLoot.DiamondSize(density)
  local side = UIBossLoot.DIAMOND_SIZE
  if density == "compact" then
    local default = itemRowHeight("default")
    local compact = itemRowHeight("compact")
    if default > 0 then
      side = math.floor(side * compact / default + 0.5)
    end
  end
  return math.max(4, side)
end

--- Brief BL23: how far the diamond's centre sits left of the count's left edge: the gap, and half
--- the drawn shape's width (the diagonal where it is turned, the side where it is not) with its
--- edge. Pure.
function UIBossLoot.DiamondOffset(side, turned)
  local drawn = side + 2 * UIBossLoot.DIAMOND_EDGE
  if turned then
    drawn = drawn * math.sqrt(2)
  end
  return UIBossLoot.PAD + math.ceil(drawn / 2)
end

--- Brief BL23: whether a loot row's item is new in WoW Forever: Diff.IsNew, or a New (or Season
--- of Discovery) mark already on the row. Pure over the data.
function UIBossLoot.IsNewLoot(row)
  if type(row) ~= "table" then
    return false
  end
  local Diff = ItemTree.Diff
  local id = tonumber(row.id)
  if id and type(Diff) == "table" and type(Diff.IsNew) == "function" then
    local ok, answer = pcall(Diff.IsNew, "items", id)
    if ok and answer then
      return true
    end
  end
  for _, badge in ipairs(type(row.badges) == "table" and row.badges or EMPTY) do
    local isNew = badge == "new" or badge == "sod"
    if not isNew and type(Diff) == "table" and type(Diff.IsNewBadge) == "function" then
      local ok, answer = pcall(Diff.IsNewBadge, badge)
      isNew = ok and answer == true
    end
    if isNew then
      return true
    end
  end
  return false
end

--- Brief BL23: what a boss row draws from the answer its panel would draw (the model's rows with
--- the Predicted rows after them, lootAnswer): the count, every row the panel lists (so the
--- Predicted rows count while Show guessed sources is on and not while it is off, and collector
--- rows always count), and whether the row wears the diamond: a boss that is not new itself
--- (isNewBoss false) with at least one of those rows new in WoW Forever. A new boss never wears
--- it, since its round New mark already says new. nil count for no answer, which keeps the
--- index's own. Pure.
function UIBossLoot.LootSummary(answer, isNewBoss)
  if type(answer) ~= "table" or type(answer.rows) ~= "table" then
    return nil, false
  end
  local newLoot = false
  if not isNewBoss then
    for _, row in ipairs(answer.rows) do
      if UIBossLoot.IsNewLoot(row) then
        newLoot = true
        break
      end
    end
  end
  return #answer.rows, newLoot
end

--- Brief BL23: the line a boss row's hover carries where it wears the diamond, in the diamond's
--- blue. Pure.
function UIBossLoot.NewLootLine()
  return { text = L["Drops items new in WoW Forever"], colorKey = UIBossLoot.DIAMOND_COLOR }
end

--- Brief BL20: the muted line a boss's hover carries where it is shown by its creature's name,
--- "Encounter: Infurnus", or nil where there is no encounter name to give. Pure.
function UIBossLoot.EncounterLine(encounterName)
  if type(encounterName) ~= "string" or encounterName == "" then
    return nil
  end
  return { text = string.format(L["Encounter: %s"], encounterName), colorKey = UIBossLoot.SUB_WORD }
end

--- Brief BL20: a boss row's hover. A rare elite or a rare keeps its rank word title
--- (UIBossLoot.RankTooltip); a row shown by its creature's name (encounterName, the client's own
--- name for it) adds the muted "Encounter:" line, under the rank word or under the shown name
--- (shownName). Brief BL23: a row wearing the diamond (row.newLoot) adds "Drops items new in WoW
--- Forever" last, under the row's name where nothing else titles it. nil for a row with none of
--- these, which shows none. Pure.
---   { title, titleKey, lines }
function UIBossLoot.BossTooltip(row, shownName, encounterName)
  local rank = UIBossLoot.RankTooltip(row)
  local lines = {}
  local line = UIBossLoot.EncounterLine(encounterName)
  if line then
    lines[#lines + 1] = line
  end
  if type(row) == "table" and row.newLoot == true and not row.isNew then
    lines[#lines + 1] = UIBossLoot.NewLootLine()
  end
  if #lines == 0 then
    return rank
  end
  if rank then
    return { title = rank.title, titleKey = rank.titleKey, lines = lines }
  end
  local title = type(shownName) == "string" and shownName ~= "" and shownName or nil
  if not title and type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
    title = row.name
  end
  return { title = title, lines = lines }
end

--- Whether a boss index entry has a creature for the panel to draw (brief BL9): a display id
--- (cd), a creature type (ct) or at least one creature id (c). An entry with none of the three (a
--- Forever encounter the index knows by name alone) has no panel. Pure.
function UIBossLoot.HasCreature(entry)
  if type(entry) ~= "table" then
    return false
  end
  if tonumber(entry.cd) or tonumber(entry.ct) then
    return true
  end
  return type(entry.c) == "table" and entry.c[1] ~= nil
end

--- Brief BL14: the creature id the panel's model is drawn from with SetCreature where the entry
--- has no display id (cd): the index's first creature id (c), else the npcId of the collector's
--- seen boss record (seen, C:SeenBoss). nil where the entry has a cd, which keeps the display id
--- path first, and where neither names a creature. Pure.
function UIBossLoot.ModelCreatureId(entry, seen)
  if type(entry) ~= "table" or UIBossLoot.PortraitOf(entry) then
    return nil
  end
  local function whole(value)
    if type(value) == "number" and value > 0 and value == math.floor(value) then
      return value
    end
    return nil
  end
  local first = type(entry.c) == "table" and whole(entry.c[1]) or nil
  if first then
    return first
  end
  return type(seen) == "table" and whole(seen.npcId) or nil
end

-- The glyph a panel wears while its model is drawn from a creature id alone: the creature type's
-- glyph where the entry has one, else the unknown creature's, so the model's block is held open.
UIBossLoot.SEEN_GLYPH = "CREATURE_UNKNOWN"

--- Brief BL17: whether an entry is a boss new in WoW Forever (g = 1) with no Classic Era page (no
--- e), which is the entry the Predicted line and the Classic Era provenance line are wrong for. Pure.
function UIBossLoot.IsNewBoss(entry)
  return type(entry) == "table" and tonumber(entry.g) == 1 and entry.e == nil
end

--- Brief BL17: whether an entry has loot records of its own (l, a non empty string). The fallback
--- when the caller does not say whether the loot pane lists rows. Pure.
function UIBossLoot.HasLootRecords(entry)
  return type(entry) == "table" and type(entry.l) == "string" and entry.l ~= ""
end

-- The line a new boss's panel ends with while nothing is known of its loot (the E86 notice's
-- wording family).
UIBossLoot.NEW_BOSS_LINE = "New in WoW Forever. Its loot is not yet known."

local function newBossRow()
  return {
    kind = "para",
    key = "creaturenew",
    value = L["New in WoW Forever. Its loot is not yet known."],
    colorKey = "ITEMTREE_COLOR_TEXT_MUTED",
  }
end

-- Whether the panel says there is loot: the caller's word where it gives one, else the entry's own
-- loot records.
local function lootKnown(entry, hasLoot)
  if hasLoot ~= nil then
    return hasLoot == true
  end
  return UIBossLoot.HasLootRecords(entry)
end

--------------------------------------------------------------------------------
-- Pure: the creature model loader (brief BL17)
--------------------------------------------------------------------------------

-- PlayerModel:SetCreature(id) asks the server about a creature the client has never seen; until
-- the answer comes the frame draws nothing, and the first call can fail silently. The loader asks
-- again on a short ladder while GetDisplayInfo() still answers 0: the waits after each try, in
-- seconds, and the most tries (SetCreature calls) one load makes before it gives up quietly.
UIBossLoot.MODEL_RETRY_DELAYS = { 0.5, 1, 2, 4 }
UIBossLoot.MODEL_MAX_TRIES = 5

--- The wait after try number tries (1 for the first SetCreature) before the display id is read
--- again, or nil once there is no try left to wait on: the ladder's step, its last step repeated
--- for the fifth try, so the fifth try is read once too. Pure.
function UIBossLoot.ModelRetryDelay(tries)
  tries = tonumber(tries)
  if not tries or tries < 1 or tries > UIBossLoot.MODEL_MAX_TRIES then
    return nil
  end
  local delays = UIBossLoot.MODEL_RETRY_DELAYS
  return delays[math.min(math.floor(tries), #delays)]
end

--- What the loader does when it reads the display id after try number tries: "done" where the
--- client answered a display id, "retry" where it answered 0 and a try is left, "give up"
--- otherwise. Pure.
function UIBossLoot.ModelLoadStep(tries, display)
  if UIBossLoot.WholeDisplay(display) then
    return "done"
  end
  if (tonumber(tries) or 0) < UIBossLoot.MODEL_MAX_TRIES then
    return "retry"
  end
  return "give up"
end

--- A CreatureDisplayInfo id: a whole number above nought, or nil. Pure.
function UIBossLoot.WholeDisplay(value)
  if type(value) == "number" and value > 0 and value == math.floor(value) then
    return value
  end
  return nil
end

--- Brief BL17: the display id the loader remembered in a boss's seenBosses record (displayId),
--- for the creature it was confirmed for (displayCreatureId). Where creatureId is given it must
--- be that creature, so a data build that moves the entry to another creature draws nothing stale.
--- nil where there is none. Pure.
function UIBossLoot.RememberedDisplay(record, creatureId)
  if type(record) ~= "table" then
    return nil
  end
  local display = UIBossLoot.WholeDisplay(record.displayId)
  if not display then
    return nil
  end
  if creatureId ~= nil and record.displayCreatureId ~= creatureId then
    return nil
  end
  return display
end

--- Brief BL14: the panel for an entry the index knows by name alone (no cd, ct or c: a new Forever
--- encounter) once the player has seen its creature (seen, the collector's C:SeenBoss record).
--- Its name is the entry's, else the record's; its one fact the Level, the index's range where it
--- has one, else the level the record saw. These are what the player saw in Forever, not
--- Classic Era's, so there is no Predicted line and no provenance, and Show predicted data
--- leaves them alone. Brief BL17: a new boss (UIBossLoot.IsNewBoss) with no loot known (hasLoot,
--- else its own loot records) ends with "New in WoW Forever. Its loot is not yet known." nil where
--- there is no record, which is the panel main draws for such an entry: none. Pure.
function UIBossLoot.SeenContent(entry, name, seen, hasLoot)
  if type(entry) ~= "table" or type(seen) ~= "table" then
    return nil
  end
  if type(name) ~= "string" or name == "" then
    name = type(seen.name) == "string" and seen.name ~= "" and seen.name or L["Unknown creature"]
  end
  local rows = {}
  local lo, hi = tonumber(entry.lo), tonumber(entry.hi)
  if not lo and not hi then
    lo = tonumber(seen.level)
  end
  if lo or hi then
    local value = tostring(lo or hi)
    if lo and hi and lo ~= hi then
      value = string.format(L["%d to %d"], lo, hi)
    end
    rows[#rows + 1] = { kind = "fact", key = "creaturelevel", label = L["Level"], value = value }
  end
  if UIBossLoot.IsNewBoss(entry) and not lootKnown(entry, hasLoot) then
    rows[#rows + 1] = newBossRow()
  end
  local sections = {}
  if #rows > 0 then
    sections[1] = { key = "creature", rows = rows }
  end
  return {
    kind = "creature",
    display = nil,
    header = { name = name, colorKey = "ITEMTREE_COLOR_TEXT_TITLE", badges = {}, asset = UIBossLoot.SEEN_GLYPH },
    sections = sections,
  }
end

--- What the creature panel beside the loot draws for one boss, as UI/InfoPanel.lua's surface
--- takes it, built from the boss index alone: entry is the index's own b entry (its cd display id,
--- its ct creature type id, lo and hi) and name the entry's name. The owner's rule is that the tab
--- never builds EraSources or its loot index, so nothing here asks either: the Type word is the one
--- the creature page's Type line uses (Core/Sources.lua CREATURE_TYPES), the glyph the one its rows
--- wear (ViewModel.CreatureIcon), and the Level the entry's own band. The fixed Predicted line and
--- the provenance line close it, as they close a creature page; with Show predicted data off the
--- facts go and the name and the model stay. No cd draws no model: InfoPanel falls back to the
--- glyph. nil for no entry, and for an entry UIBossLoot.HasCreature says has no creature unless
--- the collector has seen it (seen, brief BL14: UIBossLoot.SeenContent answers for it then). It
--- asks nothing of loot, so an entry with nothing known (a new boss with no loot table) or only
--- world drops has its panel as any other does (brief BL9). Brief BL17: a boss new in WoW Forever
--- with no Classic Era page (UIBossLoot.IsNewBoss) has no Predicted line and no Classic Era line:
--- its Type and Level are Forever's own, so Show predicted data leaves them alone, and where no
--- loot is known (hasLoot, else the entry's own loot records) it ends with "New in WoW Forever.
--- Its loot is not yet known." A new boss with loot rows ends at its facts. Pure.
---
---   { kind = "creature", display, header = { name, colorKey, badges, asset }, sections }
function UIBossLoot.CreatureContent(entry, name, showPredicted, seen, hasLoot)
  if not UIBossLoot.HasCreature(entry) then
    return UIBossLoot.SeenContent(entry, name, seen, hasLoot)
  end
  local isNew = UIBossLoot.IsNewBoss(entry)
  local creatureType = tonumber(entry.ct)
  local asset = nil
  local ViewModel = ItemTree.ViewModel
  if creatureType and type(ViewModel) == "table" and type(ViewModel.CreatureIcon) == "function" then
    local ok, key = pcall(ViewModel.CreatureIcon, { type = creatureType })
    if ok and type(key) == "string" and key ~= "" then
      asset = key
    end
  end
  if type(name) ~= "string" or name == "" then
    name = L["Unknown creature"]
  end
  local rows = {}
  if showPredicted ~= false or isNew then
    local Sources = ItemTree.Sources
    local types = type(Sources) == "table" and Sources.CREATURE_TYPES or nil
    local typeWord = type(types) == "table" and creatureType and types[creatureType] or nil
    if typeWord then
      rows[#rows + 1] = { kind = "fact", key = "creaturetype", label = L["Type"], value = L[typeWord] }
    end
    -- "23 to 24", or the one number, as the creature page's Level line reads.
    local lo, hi = tonumber(entry.lo), tonumber(entry.hi)
    if lo or hi then
      local value = tostring(lo or hi)
      if lo and hi and lo ~= hi then
        value = string.format(L["%d to %d"], lo, hi)
      end
      rows[#rows + 1] = { kind = "fact", key = "creaturelevel", label = L["Level"], value = value }
    end
  end
  if isNew then
    if not lootKnown(entry, hasLoot) then
      rows[#rows + 1] = newBossRow()
    end
  elseif showPredicted ~= false then
    local Confidence = ItemTree.Confidence
    if type(Confidence) == "table" and type(Confidence.Label) == "function" then
      local ok, label = pcall(Confidence.Label, Confidence.PREDICTED or "predicted")
      if ok and type(label) == "string" and label ~= "" then
        rows[#rows + 1] =
          { kind = "fact", key = "creatureconfidence", value = label, colorKey = "ITEMTREE_COLOR_TEXT_MUTED" }
      end
    end
    rows[#rows + 1] = {
      kind = "para",
      key = "creatureprovenance",
      value = L["From Classic Era. WoW Forever may have changed this."],
      colorKey = "ITEMTREE_COLOR_TEXT_MUTED",
    }
  end
  local sections = {}
  if #rows > 0 then
    sections[1] = { key = "creature", rows = rows }
  end
  -- Brief PT1 (owner QA 2026-10-19, item 275): the square beside the name wears the face the boss's
  -- row wears (UI/InfoPanel.lua InfoPanel.HeaderPortrait): the entry's cd, else the Creatures data's
  -- first (creaturesDisplay, which never drives the model); the glyph above only where neither is.
  local portrait = UIBossLoot.PortraitOf(entry) or UIBossLoot.WholeDisplay(entry.creaturesDisplay)
  return {
    kind = "creature",
    display = tonumber(entry.cd),
    header = {
      name = name,
      colorKey = "ITEMTREE_COLOR_TEXT_TITLE",
      badges = {},
      asset = asset,
      portrait = portrait,
    },
    sections = sections,
  }
end

--------------------------------------------------------------------------------
-- Pure: clicks
--------------------------------------------------------------------------------

--- What one click asks for. column is "places", "bosses", "loot" or "creature"; row is that
--- column's row (for "creature", the creature page key or nil). Answers the action and its
--- argument:
---
---   "place", placeId      a place row
---   "boss", bossId        a boss row
---   "open", itemId        an item row (a modified click is tried through ItemClick first)
---   "creature", key       the Creature page button, where the boss has a page
---   "none"                a band header, a group header, a note, a right click, no page
---
--- Pure.
function UIBossLoot.Interpret(column, row, button)
  if button ~= nil and button ~= "LeftButton" then
    return "none"
  end
  if column == "creature" then
    if type(row) == "string" and row ~= "" then
      return "creature", row
    end
    return "none"
  end
  if type(row) ~= "table" then
    return "none"
  end
  if column == "places" then
    if row.kind == "place" and row.id then
      return "place", row.id
    end
    return "none"
  end
  if column == "bosses" then
    if row.id then
      return "boss", row.id
    end
    return "none"
  end
  if column == "loot" then
    if row.kind == "item" and tonumber(row.id) then
      return "open", tonumber(row.id)
    end
    return "none"
  end
  return "none"
end

--------------------------------------------------------------------------------
-- Pure: keys (brief BL4)
--------------------------------------------------------------------------------

-- The three columns, left to right, which is the order LEFT and RIGHT walk.
UIBossLoot.COLUMNS = { "places", "bosses", "loot" }

-- The keys the pane answers, by the client's key name, and what each is. Every other key is
-- handed straight back to the game.
UIBossLoot.KEYS = { UP = "up", DOWN = "down", LEFT = "left", RIGHT = "right", ENTER = "enter", NUMPADENTER = "enter" }

local function columnIndex(column)
  for index, name in ipairs(UIBossLoot.COLUMNS) do
    if name == column then
      return index
    end
  end
  return 1
end

--- What one key asks for in the column that has the keyboard (focus, "places" when unknown):
---
---   "move", -1 or 1     UP or DOWN: the row above or below in that column
---   "focus", column     LEFT or RIGHT: the column beside it; ENTER in the places or the bosses
---                       column steps into the next one, the way RIGHT does
---   "open"              ENTER in the loot column: open the item under the cursor
---   "none"              LEFT in the places column, RIGHT in the loot column: the pane's key, and
---                       nothing to do
---   nil                 any other key, which the pane hands back to the game
---
--- Pure.
function UIBossLoot.KeyAction(key, focus)
  local what = type(key) == "string" and UIBossLoot.KEYS[key] or nil
  if not what then
    return nil
  end
  local at = columnIndex(focus)
  if what == "up" then
    return "move", -1
  end
  if what == "down" then
    return "move", 1
  end
  if what == "enter" and UIBossLoot.COLUMNS[at] == "loot" then
    return "open"
  end
  local step = what == "left" and -1 or 1
  local column = UIBossLoot.COLUMNS[at + step]
  if column then
    return "focus", column
  end
  return "none"
end

--- The row a move lands on: from the row at index `at` (nil for none yet), `delta` rows on, past
--- any row `selectable` says no to (a band header, a group header, a note). It stops at either end
--- rather than wrapping, and answers `at` where there is nowhere to go. With no row yet, DOWN lands
--- on the first selectable row and UP on the last. nil for a list with nothing selectable. Pure.
function UIBossLoot.StepIndex(rows, at, delta, selectable)
  rows = type(rows) == "table" and rows or EMPTY
  delta = (tonumber(delta) or 0) < 0 and -1 or 1
  local ok = type(selectable) == "function" and selectable or function()
    return true
  end
  at = tonumber(at)
  local index
  if at == nil then
    index = delta > 0 and 1 or #rows
  else
    index = at + delta
  end
  while index >= 1 and index <= #rows do
    if ok(rows[index]) then
      return index
    end
    index = index + delta
  end
  if at ~= nil then
    return at
  end
  return nil
end

--- Whether a row of this column can take the keyboard's cursor. Pure.
function UIBossLoot.Selectable(column, row)
  if type(row) ~= "table" then
    return false
  end
  if column == "places" then
    return row.kind == "place" and row.id ~= nil
  end
  if column == "bosses" then
    return row.id ~= nil
  end
  return row.kind == "item" and tonumber(row.id) ~= nil
end

--------------------------------------------------------------------------------
-- Pure: the GC run
--------------------------------------------------------------------------------

--- One garbage collector run after a release: Tick is called once per GC_INTERVAL. Each tick,
--- unless inCombat() says true, makes one pcalled collect("step", stepKB); the run ends when a
--- step answers true (the cycle is done), when the call raises, or after maxTicks ticks, combat
--- ticks included. Never "collect". opts: { collect, inCombat, maxTicks, stepKB }. Pure: the
--- collector is handed in.
function UIBossLoot.NewGCRun(opts)
  opts = type(opts) == "table" and opts or EMPTY
  local run = {
    ticks = 0,
    steps = 0,
    done = false,
    maxTicks = tonumber(opts.maxTicks) or UIBossLoot.GC_MAX_TICKS,
    stepKB = tonumber(opts.stepKB) or UIBossLoot.GC_STEP_KB,
    collect = opts.collect,
    inCombat = opts.inCombat,
  }
  function run:Tick()
    if self.done then
      return false
    end
    if self.ticks >= self.maxTicks or type(self.collect) ~= "function" then
      self.done = true
      return false
    end
    self.ticks = self.ticks + 1
    local busy = false
    if type(self.inCombat) == "function" then
      local ok, answer = pcall(self.inCombat)
      busy = ok and answer == true
    end
    if not busy then
      self.steps = self.steps + 1
      local ok, finished = pcall(self.collect, "step", self.stepKB)
      if not ok or finished == true then
        self.done = true
      end
    end
    if self.ticks >= self.maxTicks then
      self.done = true
    end
    return not self.done
  end
  return run
end

--------------------------------------------------------------------------------
-- The model and the window's side
--------------------------------------------------------------------------------

--- The model instance, made on first use and kept for the session.
function UIBossLoot.Model()
  if UIBossLoot.model then
    return UIBossLoot.model
  end
  local BossLoot = ItemTree.BossLoot
  if type(BossLoot) ~= "table" or type(BossLoot.New) ~= "function" then
    return nil
  end
  UIBossLoot.model = BossLoot.New({})
  return UIBossLoot.model
end

local function frameModule()
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if type(frame) == "table" then
    return frame
  end
  return nil
end

-- Brief G1: a draw a place or boss pick starts runs under the window's boundary (Frame.Guarded),
-- which hands an error to the client's handler and puts the empty page up. With no window, a
-- straight call.
local function guarded(where, fn, ...)
  local frame = frameModule()
  if frame and type(frame.Guarded) == "function" then
    return frame.Guarded(where, fn, ...)
  end
  return fn(...)
end

--- Whether this data build carries the Boss loot index, read off Meta (no load).
function UIBossLoot.Present()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.IsOnDemand) ~= "function" then
    return false
  end
  local ok, present = pcall(data.IsOnDemand, data, UIBossLoot.MODULE)
  return ok and present == true
end

--- Registers the tab with the window and the setting with the panel, but only where the data
--- build carries the module. Both are idempotent; the setting is registered once the panel's
--- module has loaded (it loads after this file, so ADDON_LOADED asks again). Answers whether the
--- tab is registered.
function UIBossLoot.Register()
  if not UIBossLoot.Present() then
    return false
  end
  local Options = ItemTree.Options
  if type(Options) == "table" and type(Options.RegisterSetting) == "function" then
    pcall(Options.RegisterSetting, UIBossLoot.SETTING_ENTRY)
  end
  local frame = frameModule()
  if not frame or type(frame.RegisterTab) ~= "function" then
    return false
  end
  local ok, done = pcall(frame.RegisterTab, UIBossLoot.TAB_NAME, UIBossLoot.TAB_SPEC)
  return ok and done == true
end

--- Opens a page key through the window, then moves to the Tree tab, which is where it is drawn.
--- opts is handed to Frame.Open as it is (brief E97: an item carries its origin there).
function UIBossLoot.OpenKey(key, opts)
  local frame = frameModule()
  if type(key) ~= "string" or not frame or type(frame.Open) ~= "function" then
    return false
  end
  -- Brief G1: no pcall around the open. The window's own opens run under its boundary
  -- (Frame.Guarded); a pcall here would only hide a raise from the specs, which run with it off.
  if opts ~= nil then
    frame.Open(key, opts)
  else
    frame.Open(key)
  end
  local ok = true
  if type(frame.SelectTab) == "function" then
    pcall(frame.SelectTab, "Tree")
  end
  return ok
end

-- The name of the row with this id in a model list, or nil. Reads what the lists already hold.
local function nameIn(rows, id)
  for _, row in ipairs(type(rows) == "table" and rows or EMPTY) do
    if row.id == id and row.kind ~= "band" then
      return row.name
    end
  end
  return nil
end

--- Brief E97: where an item opened from the loot list came from, which the window turns into a
--- boss crumb in its breadcrumb. { kind = "boss", place, boss, placeName, bossName, offsets }, the
--- offsets read off the lists as they stand now, or nil with no place and boss chosen.
function UIBossLoot.Origin()
  local state = UIBossLoot.state
  if state.place == nil or state.boss == nil then
    return nil
  end
  if type(UIBossLoot.CaptureOffsets) == "function" then
    pcall(UIBossLoot.CaptureOffsets)
  end
  local placeName, bossName = nil, nil
  local model = UIBossLoot.Model()
  if model then
    local okPlaces, places = pcall(model.Places, model)
    placeName = okPlaces and nameIn(places, state.place) or nil
    local okBosses, bosses = pcall(model.Bosses, model, state.place)
    bossName = okBosses and nameIn(bosses, state.boss) or nil
  end
  -- Brief BL20: the crumb carries the name the tab shows the boss by.
  if type(UIBossLoot.BossNaming) == "function" then
    bossName = UIBossLoot.BossNaming(state.boss, bossName) or bossName
  end
  local offsets = state.offsets or EMPTY
  return {
    kind = "boss",
    place = state.place,
    boss = state.boss,
    placeName = placeName,
    bossName = bossName,
    offsets = { places = offsets.places or 0, bosses = offsets.bosses or 0, loot = offsets.loot or 0 },
  }
end

--- Brief E97: puts the tab back on a boss crumb's record (UIBossLoot.Origin's shape): the place,
--- the boss and its creature panel, and the three scroll offsets, which the next draw applies
--- rather than reading the lists over them. Answers whether the record was usable.
function UIBossLoot.RestoreSnapshot(record)
  if type(record) ~= "table" or record.place == nil or record.boss == nil then
    return false
  end
  local state = UIBossLoot.state
  state.place = record.place
  state.boss = record.boss
  state.creature = record.boss
  state.cursor = nil
  local offsets = type(record.offsets) == "table" and record.offsets or EMPTY
  for _, name in ipairs({ "places", "bosses", "loot" }) do
    state.offsets[name] = tonumber(offsets[name]) or 0
  end
  UIBossLoot.pendingReset = nil
  UIBossLoot.restoring = true
  return true
end

--- Opens an item's page, carrying the boss it was opened from (brief E97).
function UIBossLoot.OpenItem(itemId)
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
    return false
  end
  local ok, key = pcall(Graph.Key, "item", itemId)
  if not ok or type(key) ~= "string" then
    return false
  end
  local origin = UIBossLoot.Origin()
  if origin then
    return UIBossLoot.OpenKey(key, { origin = origin })
  end
  return UIBossLoot.OpenKey(key)
end

--- E6's modified clicks: the dress up or chat link modifier on an item goes to UI/ItemClick.lua
--- first, and when the client takes it the row does not open the item.
function UIBossLoot.ModifiedClick(itemId)
  local helper = ItemTree.ItemClick
  if type(helper) ~= "table" or type(helper.Handle) ~= "function" then
    return false
  end
  local ok, handled = pcall(helper.Handle, itemId)
  return ok and handled == true
end

-- A new place or boss starts its columns at the top. The names are also kept for the next draw,
-- which reads where the lists are scrolled to before it puts these back to the top.
local function resetOffsets(...)
  local offsets = UIBossLoot.state.offsets
  UIBossLoot.pendingReset = { ... }
  for _, name in ipairs(UIBossLoot.pendingReset) do
    offsets[name] = 0
  end
end

--- Chooses a place: its bosses are read and the first is chosen at once. Brief BL23: the draw
--- then reads each boss's loot for its count and diamond (the model holds them by place).
--- Answers the boss chosen, or nil for a place with none.
function UIBossLoot.SelectPlace(placeId)
  local state = UIBossLoot.state
  state.place = placeId
  state.boss = nil
  state.cursor = nil
  state.creature = nil
  resetOffsets("bosses", "loot")
  local model = UIBossLoot.Model()
  local bosses = model and model:Bosses(placeId) or EMPTY
  local first = bosses[1]
  state.boss = first and first.id or nil
  -- Brief BL9: the first boss, picked for the player, has its creature panel as a clicked one does.
  state.creature = state.boss
  if UIBossLoot.Draw then
    guarded("BossLoot.SelectPlace", UIBossLoot.Draw)
  end
  return state.boss
end

--- Chooses a boss: its loot is decoded (M:Loot) when the right column draws it. state.creature
--- names the boss whose creature panel is wanted, and follows state.boss (brief BL9: every chosen
--- boss has its panel, however it was chosen). _chosen (a click or the keyboard) is kept for the
--- callers and no longer changes anything.
function UIBossLoot.SelectBoss(bossId, _chosen)
  local state = UIBossLoot.state
  state.boss = bossId
  state.cursor = nil
  state.creature = bossId
  resetOffsets("loot")
  if UIBossLoot.Draw then
    guarded("BossLoot.SelectBoss", UIBossLoot.Draw)
  end
  return bossId
end

-- The chosen boss's own index entry, or nil.
local function chosenEntry(model, boss)
  local ok, index = pcall(model.Index, model)
  if not ok or type(index) ~= "table" or type(index.b) ~= "table" then
    return nil
  end
  local entry = index.b[boss]
  return type(entry) == "table" and entry or nil
end

--- Brief BL22: the page of an entry's first creature id (c[1]) where the Creatures data has a row
--- for it (Core/Creatures.lua, the creatures testers have met): npc:<id>, the key a source row and
--- Ctrl + right click open (brief C4 and T8), else nil. Builds the Creatures module.
function UIBossLoot.MetCreatureKey(entry)
  local id = type(entry) == "table" and type(entry.c) == "table" and tonumber(entry.c[1]) or nil
  local Creatures = ItemTree.Creatures
  if not id or id <= 0 or id % 1 ~= 0 or type(Creatures) ~= "table" or type(Creatures.Get) ~= "function" then
    return nil
  end
  local ok, row = pcall(Creatures.Get, id)
  if not ok or type(row) ~= "table" then
    return nil
  end
  return "npc:" .. string.format("%d", id)
end

--- The creature page key of the chosen boss, or nil: its Classic Era page where it has one, else
--- (brief BL22) the page of its creature the Creatures data knows.
function UIBossLoot.CreatureKey()
  local model = UIBossLoot.Model()
  local boss = UIBossLoot.state.boss
  if not model or not boss then
    return nil
  end
  local key = model:CreatureKey(boss)
  if key then
    return key
  end
  return UIBossLoot.MetCreatureKey(chosenEntry(model, boss))
end

--- Brief BL22: why the chosen boss has no creature page, in the player's terms. A boss with a
--- creature id nobody has met yet says so; any other says Classic Era has no record of it.
function UIBossLoot.NoPageReason()
  local model = UIBossLoot.Model()
  local boss = UIBossLoot.state.boss
  local entry = model and boss ~= nil and chosenEntry(model, boss) or nil
  if type(entry) == "table" and type(entry.c) == "table" and tonumber(entry.c[1]) then
    return L["Nobody has met this creature yet, so it has no page."]
  end
  return L["Classic Era has no record of this creature, so it has no page."]
end

--- Brief BL26: what a place row's map icon opens (UIBossLoot.PlaceMapTarget), read off the row and
--- the index: the place's area and AreaTable name, and for a world boss the creature page of its
--- first entry that has one. nil where the place has no map. Table reads only.
function UIBossLoot.PlaceMapFor(row)
  if type(row) ~= "table" or row.kind ~= "place" then
    return nil
  end
  local facts = {}
  local model = UIBossLoot.Model()
  local ok, index = false, nil
  if model and type(model.Index) == "function" then
    ok, index = pcall(model.Index, model)
  end
  local place = ok and type(index) == "table" and type(index.p) == "table" and index.p[row.id] or nil
  if type(place) == "table" then
    facts.area = place.a
    local strings = type(index.s) == "table" and index.s or EMPTY
    facts.areaName = type(place.an) == "number" and strings[place.an] or nil
    if tonumber(row.k) == 3 then
      for _, bossId in ipairs(type(place.b) == "table" and place.b or EMPTY) do
        local asked, key = pcall(model.CreatureKey, model, bossId)
        if not asked or type(key) ~= "string" then
          key = UIBossLoot.MetCreatureKey(type(index.b) == "table" and index.b[bossId] or nil)
        end
        if type(key) == "string" then
          facts.bossKey = key
          break
        end
      end
    end
  end
  return UIBossLoot.PlaceMapTarget(row, facts)
end

--- Brief BL26: a map icon clicked. Opens the target's page on its Map tab, the way the creature
--- page button opens a page (UIBossLoot.OpenKey). An instance the index gives no area is looked up
--- by name in the Classic Era table, on this click only. Answers whether a page opened.
function UIBossLoot.OpenPlaceMap(target)
  local key = UIBossLoot.PlaceMapKey(target, function(name)
    local era = ItemTree.eraSources
    if type(era) ~= "table" or type(era.AreaIdOf) ~= "function" then
      return nil
    end
    local ok, area = pcall(era.AreaIdOf, era, name)
    return ok and area or nil
  end)
  if not key then
    return false
  end
  return UIBossLoot.OpenKey(key, { view = target.view })
end

--- One click, acted on. Answers what Interpret said, or "modified" where ItemClick took it.
function UIBossLoot.Activate(column, row, button)
  local action, arg = UIBossLoot.Interpret(column, row, button)
  if action == "place" then
    UIBossLoot.SelectPlace(arg)
  elseif action == "boss" then
    UIBossLoot.SelectBoss(arg, true)
  elseif action == "open" then
    if UIBossLoot.ModifiedClick(arg) then
      return "modified", arg
    end
    UIBossLoot.OpenItem(arg)
  elseif action == "creature" then
    UIBossLoot.OpenKey(arg)
  end
  return action, arg
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

UIBossLoot.lists = {}
UIBossLoot.released = true

local globalFn = ItemTree.Util.GlobalFn
local playCue = ItemTree.UI.Sound.PlayCue

local function newFrame(kind, parent, name, template)
  local create = globalFn("CreateFrame")
  if not create then
    return nil
  end
  local ok, frame = pcall(create, kind, name, parent, template)
  if ok and frame then
    return frame
  end
  return nil
end

local function themeColor(key)
  if not Theme or type(Theme.ColorTable) ~= "function" or key == nil then
    return nil
  end
  return Theme.ColorTable(key)
end

local function applyColour(target, colour, alpha, method)
  if type(target) ~= "table" or type(colour) ~= "table" or type(target[method]) ~= "function" then
    return false
  end
  target[method](target, colour.r, colour.g, colour.b, alpha or colour.a or 1)
  return true
end

local function tint(texture, key, alpha)
  return applyColour(texture, themeColor(key), alpha, "SetVertexColor")
end

local function colourText(fontString, key)
  return applyColour(fontString, themeColor(key), nil, "SetTextColor")
end

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
  return texture
end

local function insetBorder(frame, colorKey)
  local edges = {}
  for index = 1, 4 do
    local edge = wash(frame, "BORDER", colorKey)
    if not edge then
      return nil
    end
    edges[index] = edge
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(UIBossLoot.EDGE_W)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(UIBossLoot.EDGE_W)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(UIBossLoot.EDGE_W)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(UIBossLoot.EDGE_W)
  return edges
end

local function panel(parent)
  local frame = newFrame("Frame", parent)
  if not frame then
    return nil
  end
  frame.fill = wash(frame, "BACKGROUND", UIBossLoot.PANEL_SURFACE, 1)
  if frame.fill then
    frame.fill:SetAllPoints(frame)
  end
  frame.edges = insetBorder(frame, UIBossLoot.PANEL_BORDER)
  return frame
end

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

local function widthOf(frame)
  if type(frame) ~= "table" or type(frame.GetWidth) ~= "function" then
    return 0
  end
  local ok, width = pcall(frame.GetWidth, frame)
  return (ok and tonumber(width)) or 0
end

local function setShown(frame, shown)
  if type(frame) ~= "table" then
    return
  end
  if shown and type(frame.Show) == "function" then
    frame:Show()
  elseif not shown and type(frame.Hide) == "function" then
    frame:Hide()
  end
end

--------------------------------------------------------------------------------
-- Font safety, the same shape as UI/Sidebar.lua and UI/Discoveries.lua
--------------------------------------------------------------------------------

local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(UIBossLoot.FONT_FALLBACKS) do
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

-- Body face at one size, 1px shadow. SetFont answers false rather than raising where the face
-- will not load, so the answer is read and a font object put back before any SetText.
local function styleText(fontString, fontSize, colorKey, justify)
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
    fontString:SetWordWrap(false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  colourText(fontString, colorKey)
  return fontString
end

local function newFontString(parent, fontSize, colorKey, justify)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", UIBossLoot.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return styleText(fontString, fontSize or UIBossLoot.FONT_MD, colorKey, justify)
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- A wrapping paragraph, for the empty state.
local function wrapText(fontString)
  if type(fontString) ~= "table" then
    return fontString
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(true)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 0)
  end
  return fontString
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

local function gameTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
    return tooltip
  end
  return nil
end

local function hideTooltip()
  local tooltip = gameTooltip()
  if tooltip and type(tooltip.Hide) == "function" then
    pcall(tooltip.Hide, tooltip)
  end
end

local function textTooltip(owner, title, lines, titleKey)
  local tooltip = gameTooltip()
  if not tooltip or type(tooltip.AddLine) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  local title_ = themeColor(titleKey or "ITEMTREE_COLOR_TEXT_TITLE") or { r = 1, g = 0.82, b = 0 }
  local body = themeColor("ITEMTREE_COLOR_TEXT_BODY") or { r = 1, g = 1, b = 1 }
  if title then
    tooltip:AddLine(title, title_.r, title_.g, title_.b)
  end
  -- A line is its text, or (brief BL20) { text, colorKey } for a line in a colour of its own.
  for _, line in ipairs(lines or EMPTY) do
    local text, colour = line, body
    if type(line) == "table" then
      text, colour = line.text, themeColor(line.colorKey) or body
    end
    tooltip:AddLine(text, colour.r, colour.g, colour.b, true)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

--- The one client call about an item: the hovered row's tooltip, with the Classic Era rate as a
--- line under it where the row carries one.
function UIBossLoot.ShowItemTooltip(owner, row)
  local item = type(row) == "table" and row.item or nil
  local id = item and tonumber(item.id) or nil
  local tooltip = id and gameTooltip() or nil
  if not tooltip then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT")
  local shown = type(tooltip.SetItemByID) == "function" and pcall(tooltip.SetItemByID, tooltip, id)
  if not shown then
    return false
  end
  if type(item.rateTip) == "string" and item.rateTip ~= "" and type(tooltip.AddLine) == "function" then
    local muted = themeColor("ITEMTREE_COLOR_TEXT_MUTED") or { r = 0.7, g = 0.7, b = 0.7 }
    tooltip:AddLine(item.rateTip, muted.r, muted.g, muted.b, true)
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

--------------------------------------------------------------------------------
-- Lists: a ScrollBox with a variable extent per row, or a pool the wheel pages through
--------------------------------------------------------------------------------

local function scrollAvailable()
  local scrollUtil = rawget(_G, "ScrollUtil")
  if not globalFn("CreateScrollBoxListLinearView") or not globalFn("CreateDataProvider") then
    return false
  end
  return type(scrollUtil) == "table"
    and (
      type(scrollUtil.InitScrollBoxListWithScrollBar) == "function"
      or type(scrollUtil.InitScrollBoxList) == "function"
    )
end

local function initRow(list, frame, row)
  if type(frame) ~= "table" then
    return
  end
  if not rawget(frame, "itemTreeBossLootRow") then
    frame.itemTreeBossLootRow = true
    list.spec.decorate(frame, list)
  end
  list.frames[frame] = true
  frame.rowModel = row
  if type(frame.SetHeight) == "function" then
    frame:SetHeight(UIBossLoot.RowExtent(row))
  end
  if type(row) ~= "table" then
    frame:Hide()
    return
  end
  list.spec.init(frame, row, list)
  frame:Show()
end

local function buildScrollBox(list)
  if not scrollAvailable() then
    return false
  end
  local host = list.host
  local box = newFrame("Frame", host, nil, "WowScrollBoxList")
  if not box then
    return false
  end
  local bar = newFrame("EventFrame", host, nil, "MinimalScrollBar") or newFrame("Frame", host, nil, "MinimalScrollBar")
  local okView, view = pcall(globalFn("CreateScrollBoxListLinearView"))
  if
    not okView
    or type(view) ~= "table"
    or type(view.SetElementInitializer) ~= "function"
    or type(view.SetElementExtentCalculator) ~= "function"
  then
    box:Hide()
    if bar then
      bar:Hide()
    end
    return false
  end
  pcall(view.SetElementExtentCalculator, view, function(_, element)
    return UIBossLoot.RowExtent(element)
  end)
  local initialised = pcall(view.SetElementInitializer, view, UIBossLoot.ROW_TEMPLATE, function(frame, element)
    initRow(list, frame, element)
  end)
  local scrollUtil = rawget(_G, "ScrollUtil")
  local ok = false
  if initialised and bar and type(scrollUtil.InitScrollBoxListWithScrollBar) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxListWithScrollBar, box, bar, view)
  elseif initialised and type(scrollUtil.InitScrollBoxList) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxList, box, view)
  end
  if not ok then
    box:Hide()
    if bar then
      bar:Hide()
    end
    return false
  end
  box:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -UIBossLoot.SCROLLBAR_W, 0)
  if bar then
    bar:SetWidth(UIBossLoot.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
  end
  list.box, list.bar, list.view = box, bar, view
  return true
end

local function poolRow(list, index)
  local frame = list.pool[index]
  if frame then
    return frame
  end
  frame = newFrame("Button", list.host)
  if not frame then
    return nil
  end
  local above = list.pool[index - 1]
  if above then
    frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
  else
    frame:SetPoint("TOPLEFT", list.host, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", list.host, "TOPRIGHT", 0, 0)
  end
  list.pool[index] = frame
  return frame
end

local function drawPool(list)
  local rows = list.rows
  list.offset = UIBossLoot.PoolOffset(#rows, list.offset, UIBossLoot.POOL_ROWS)
  local drawn = 0
  for index = 1, math.min(UIBossLoot.POOL_ROWS, #rows - list.offset) do
    local frame = poolRow(list, index)
    if not frame then
      break
    end
    initRow(list, frame, rows[list.offset + index])
    drawn = index
  end
  for index = drawn + 1, #list.pool do
    list.pool[index].rowModel = nil
    list.pool[index]:Hide()
  end
  return true
end

local function drawScroll(list)
  local box, create = list.box, globalFn("CreateDataProvider")
  if not box or type(box.SetDataProvider) ~= "function" or not create then
    return false
  end
  local ok, provider = pcall(create, list.rows)
  if not ok or not provider then
    return false
  end
  return (pcall(box.SetDataProvider, box, provider))
end

-- Where a list is scrolled to: a fraction for the ScrollBox, a row index for the pool.
local function listOffset(list)
  if type(list) ~= "table" then
    return 0
  end
  if list.mode == "scroll" and list.box and type(list.box.GetScrollPercentage) == "function" then
    local ok, value = pcall(list.box.GetScrollPercentage, list.box)
    return (ok and tonumber(value)) or 0
  end
  return list.offset or 0
end

local function setListOffset(list, value)
  if type(list) ~= "table" then
    return
  end
  value = tonumber(value) or 0
  if list.mode == "scroll" then
    if list.box and type(list.box.SetScrollPercentage) == "function" then
      pcall(list.box.SetScrollPercentage, list.box, value)
    end
    return
  end
  list.offset = math.floor(value)
  drawPool(list)
end

local function drawList(list, rows)
  if type(list) ~= "table" then
    return false
  end
  list.rows = type(rows) == "table" and rows or EMPTY
  if list.mode == "scroll" then
    if drawScroll(list) then
      return true
    end
    list.mode = "pool"
    setShown(list.box, false)
    setShown(list.bar, false)
  end
  return drawPool(list)
end

-- Empties a list: the data provider goes and every frame it drew lets go of its row.
local function clearList(list)
  if type(list) ~= "table" then
    return
  end
  list.rows = EMPTY
  if list.mode == "scroll" and list.box and type(list.box.SetDataProvider) == "function" then
    local create = globalFn("CreateDataProvider")
    if create then
      local ok, provider = pcall(create, {})
      if ok and provider then
        pcall(list.box.SetDataProvider, list.box, provider)
      end
    end
  end
  for frame in pairs(list.frames) do
    frame.rowModel = nil
  end
  for _, frame in ipairs(list.pool) do
    frame.rowModel = nil
    frame:Hide()
  end
end

local function newList(name, parent, spec)
  local host = newFrame("Frame", parent)
  if not host then
    return nil
  end
  host:SetPoint("TOPLEFT", parent, "TOPLEFT", UIBossLoot.EDGE_W, -UIBossLoot.EDGE_W)
  host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -UIBossLoot.EDGE_W, UIBossLoot.EDGE_W)
  if type(host.SetClipsChildren) == "function" then
    pcall(host.SetClipsChildren, host, true)
  end
  local list = {
    name = name,
    host = host,
    spec = spec,
    pool = {},
    frames = setmetatable({}, { __mode = "k" }),
    rows = EMPTY,
    offset = 0,
  }
  if buildScrollBox(list) then
    list.mode = "scroll"
  else
    list.mode = "pool"
    if type(host.EnableMouseWheel) == "function" then
      pcall(host.EnableMouseWheel, host, true)
    end
    attachScript(host, "OnMouseWheel", function(_, delta)
      local step = (tonumber(delta) or 0) > 0 and -UIBossLoot.WHEEL_ROWS or UIBossLoot.WHEEL_ROWS
      list.offset = UIBossLoot.PoolOffset(#list.rows, list.offset + step, UIBossLoot.POOL_ROWS)
      drawPool(list)
    end)
  end
  UIBossLoot.lists[name] = list
  return list
end

--------------------------------------------------------------------------------
-- Row parts shared by the three lists
--------------------------------------------------------------------------------

-- The band header parts (the tree's category row: sticky surface, divider top and bottom), the
-- hover and selection washes. Hidden until a row asks.
local function decorateBase(frame)
  if type(frame.EnableMouse) == "function" then
    frame:EnableMouse(true)
  end
  frame.bandFill = wash(frame, "BACKGROUND", UIBossLoot.BAND_SURFACE, 1)
  if frame.bandFill then
    frame.bandFill:SetAllPoints(frame)
  end
  frame.bandTop = wash(frame, "BORDER", UIBossLoot.BAND_EDGE)
  if frame.bandTop then
    frame.bandTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.bandTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.bandTop:SetHeight(UIBossLoot.EDGE_W)
  end
  frame.bandEdge = wash(frame, "BORDER", UIBossLoot.BAND_EDGE)
  if frame.bandEdge then
    frame.bandEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.bandEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.bandEdge:SetHeight(UIBossLoot.EDGE_W)
  end
  -- Brief BL8: the sidebar's selected look. The wash at the token's own alpha (it was drawn
  -- opaque, the tan fill the owner could not read the words on) and the gold bar on the leading
  -- edge; the words take the selected gold in paintSelected.
  frame.selectedFill = wash(frame, "BACKGROUND", UIBossLoot.SELECTED_FILL)
  if frame.selectedFill then
    frame.selectedFill:SetAllPoints(frame)
  end
  frame.selectedEdge = wash(frame, "ARTWORK", UIBossLoot.SELECTED_EDGE)
  if frame.selectedEdge then
    frame.selectedEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.selectedEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.selectedEdge:SetWidth(UIBossLoot.EDGE_W)
  end
  frame.hoverFill = wash(frame, "BORDER", "ITEMTREE_COLOR_STATE_HOVER")
  if frame.hoverFill then
    frame.hoverFill:SetAllPoints(frame)
  end
  -- Brief BL10: the gold bevelled bar, for the place column's band headers only (showBand's gold).
  frame.goldFill = wash(frame, "BACKGROUND", UIBossLoot.BAND_GOLD_FILL, 1)
  if frame.goldFill then
    frame.goldFill:SetAllPoints(frame)
  end
  frame.goldSheen = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "BORDER") or nil
  if frame.goldSheen then
    local applied = Assets
      and type(Assets.Apply) == "function"
      and select(2, pcall(Assets.Apply, frame.goldSheen, UIBossLoot.BAND_GOLD_SHEEN)) == true
    if applied then
      if type(frame.goldSheen.SetBlendMode) == "function" then
        pcall(frame.goldSheen.SetBlendMode, frame.goldSheen, "ADD")
      end
      tint(frame.goldSheen, UIBossLoot.BAND_GOLD_FILL, UIBossLoot.BAND_SHEEN_ALPHA)
      frame.goldSheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -UIBossLoot.EDGE_W)
      frame.goldSheen:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, UIBossLoot.EDGE_W)
    else
      frame.goldSheen:Hide()
      frame.goldSheen = nil
    end
  end
  frame.goldTop = wash(frame, "ARTWORK", UIBossLoot.BAND_GOLD_LIGHT, UIBossLoot.BAND_LIGHT_ALPHA)
  if frame.goldTop then
    frame.goldTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.goldTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.goldTop:SetHeight(UIBossLoot.EDGE_W)
  end
  frame.goldEdge = wash(frame, "ARTWORK", UIBossLoot.BAND_GOLD_EDGE)
  if frame.goldEdge then
    frame.goldEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.goldEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.goldEdge:SetHeight(UIBossLoot.EDGE_W)
  end
  -- The dark keyline square behind the glyph on the bar, a pixel proud of it on every side. The
  -- bevel's dark edge since brief Q9b, when the words went gold.
  frame.goldIconBack = wash(frame, "BORDER", UIBossLoot.BAND_GOLD_EDGE)
  local goldParts = { frame.goldFill, frame.goldSheen, frame.goldTop, frame.goldEdge, frame.goldIconBack }
  for index = 1, 5 do
    setShown(goldParts[index], false)
  end
  -- Brief BL8: the band's glyph at the left, the way a tree category row wears one.
  frame.bandIcon = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.bandIcon then
    frame.bandIcon:SetSize(UIBossLoot.BAND_ICON, UIBossLoot.BAND_ICON)
    frame.bandIcon:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    frame.bandIcon:Hide()
  end
  frame.bandLabel = newFontString(frame, UIBossLoot.FONT_MD, UIBossLoot.BAND_WORD, "LEFT")
  if frame.bandLabel then
    frame.bandLabel:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    frame.bandLabel:SetPoint("RIGHT", frame, "RIGHT", -(UIBossLoot.GUTTER + UIBossLoot.COUNT_W), 0)
  end
  frame.bandCount = newFontString(frame, UIBossLoot.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if frame.bandCount then
    frame.bandCount:SetWidth(UIBossLoot.COUNT_W)
    frame.bandCount:SetPoint("RIGHT", frame, "RIGHT", -UIBossLoot.GUTTER, 0)
  end
end

-- The band's glyph, where the row names one: an Assets key, applied, and the label moved in to
-- start past it. With no key (a type group in the loot column) the label starts at the gutter.
local function paintBandIcon(frame, iconKey)
  local icon, label = frame.bandIcon, frame.bandLabel
  local drawn = false
  if icon and iconKey and Assets and type(Assets.Apply) == "function" then
    local has = type(Assets.Has) ~= "function" or Assets.Has(iconKey) == true
    drawn = has and select(1, pcall(Assets.Apply, icon, iconKey)) == true
  end
  frame.bandIconKey = drawn and iconKey or nil
  setShown(icon, drawn)
  if label and type(label.ClearAllPoints) == "function" then
    label:ClearAllPoints()
    if drawn then
      label:SetPoint("LEFT", icon, "RIGHT", UIBossLoot.GUTTER, 0)
    else
      label:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    end
    label:SetPoint("RIGHT", frame, "RIGHT", -(UIBossLoot.GUTTER + UIBossLoot.COUNT_W), 0)
  end
end

-- The selected look (brief BL8): the wash and the gold edge, and on a two line row the name in the
-- selected gold over its subtitle in the darker gold. An item row keeps its name's quality colour,
-- so it is handed no words to colour.
local function paintSelected(frame, on, name, sub)
  on = on == true
  setShown(frame.selectedFill, on)
  setShown(frame.selectedEdge, on)
  frame.selected = on
  if name then
    colourText(name, on and UIBossLoot.SELECTED_NAME or UIBossLoot.NAME_WORD)
  end
  if sub then
    colourText(sub, on and UIBossLoot.SELECTED_SUB or UIBossLoot.SUB_WORD)
  end
end

-- A band or group header, or none. gold (brief BL10) is the place column's level band: the gold
-- bevelled bar in place of the tree's category row, the words in the dark band word. Every other
-- header (the loot column's type groups) keeps the tree's design.
local function showBand(frame, shown, label, count, iconKey, gold)
  gold = shown and gold == true
  local plain = shown and not gold
  for _, part in ipairs({ frame.bandFill, frame.bandTop, frame.bandEdge }) do
    setShown(part, plain)
  end
  local goldParts = { frame.goldFill, frame.goldSheen, frame.goldTop, frame.goldEdge }
  for index = 1, 4 do
    setShown(goldParts[index], gold)
  end
  setShown(frame.bandLabel, shown)
  setShown(frame.bandCount, shown)
  frame.bandGold = gold
  if shown then
    colourText(frame.bandLabel, gold and UIBossLoot.BAND_GOLD_WORD or UIBossLoot.BAND_WORD)
    colourText(frame.bandCount, gold and UIBossLoot.BAND_GOLD_WORD or "ITEMTREE_COLOR_TEXT_MUTED")
    paintBandIcon(frame, iconKey)
    local back = frame.goldIconBack
    if back then
      back:ClearAllPoints()
      if gold and frame.bandIconKey then
        back:SetPoint("TOPLEFT", frame.bandIcon, "TOPLEFT", -UIBossLoot.EDGE_W, UIBossLoot.EDGE_W)
        back:SetPoint("BOTTOMRIGHT", frame.bandIcon, "BOTTOMRIGHT", UIBossLoot.EDGE_W, -UIBossLoot.EDGE_W)
      end
      setShown(back, gold and frame.bandIconKey ~= nil)
    end
    setText(frame.bandLabel, label or "")
    setText(frame.bandCount, count or "")
    paintSelected(frame, false)
    setShown(frame.hoverFill, false)
  else
    frame.bandIconKey = nil
    setShown(frame.bandIcon, false)
    setShown(frame.goldIconBack, false)
  end
end

-- A cluster of badges, UI/Badges.lua's, at the right hand end of the row with hover targets.
local function newCluster(frame, badgeSize, max, anchorTo, offset)
  local Badges = ItemTree.Badges
  if type(Badges) ~= "table" or type(Badges.CreateCluster) ~= "function" then
    return nil
  end
  local ok, cluster = pcall(Badges.CreateCluster, frame, badgeSize, max)
  if not ok or type(cluster) ~= "table" then
    return nil
  end
  if type(cluster.SetPoint) == "function" then
    pcall(cluster.SetPoint, cluster, "RIGHT", anchorTo or frame, anchorTo and "LEFT" or "RIGHT", -(offset or 0), 0)
  end
  if type(cluster.SetHoverEnabled) == "function" then
    pcall(cluster.SetHoverEnabled, cluster, true)
  end
  if type(cluster.SetHoverHooks) == "function" then
    pcall(cluster.SetHoverHooks, cluster, function()
      setShown(frame.hoverFill, true)
    end, function()
      setShown(frame.hoverFill, false)
    end)
  end
  if type(cluster.Hide) == "function" then
    cluster:Hide()
  end
  return cluster
end

local function setKinds(cluster, kinds, subjectId, basis)
  if type(cluster) ~= "table" then
    return
  end
  if type(cluster.SetSubject) == "function" then
    if subjectId then
      pcall(cluster.SetSubject, cluster, "items", subjectId)
    else
      pcall(cluster.SetSubject, cluster, nil, nil)
    end
  end
  if type(cluster.SetBasis) == "function" then
    pcall(cluster.SetBasis, cluster, basis)
  end
  if type(cluster.SetKinds) == "function" then
    pcall(cluster.SetKinds, cluster, kinds or EMPTY)
  end
end

local function onEnterBase(frame)
  local row = rawget(frame, "rowModel")
  if type(row) == "table" and (row.kind == "band" or row.kind == "group" or row.kind == "note") then
    return
  end
  setShown(frame.hoverFill, true)
end

local function onLeaveBase(frame)
  setShown(frame.hoverFill, false)
  hideTooltip()
end

-- Two lines: the name over a muted subtitle, with a right hand slot of the given width. Each line
-- sits LINE_INSET in from its edge of the row (brief BL8 moved them 2 pixels closer each).
local function decorateTwoLine(frame, rightW)
  local inset = UIBossLoot.LINE_INSET
  frame.name = newFontString(frame, UIBossLoot.FONT_MD, UIBossLoot.NAME_WORD, "LEFT")
  if frame.name then
    frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", UIBossLoot.GUTTER, -inset)
    frame.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(UIBossLoot.GUTTER + rightW), -inset)
  end
  frame.sub = newFontString(frame, UIBossLoot.FONT_SM, UIBossLoot.SUB_WORD, "LEFT")
  if frame.sub then
    frame.sub:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", UIBossLoot.GUTTER, inset)
    frame.sub:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(UIBossLoot.GUTTER + rightW), inset)
  end
end

--------------------------------------------------------------------------------
-- The places column
--------------------------------------------------------------------------------

local PLACE_SPEC = {}

-- Brief BL31: the red plate button is UI/Frame.lua's (Frame.NewPlateButton), shared with the zone
-- list row's eye. Frame.lua loads before this file; the module is held at load so a stand in for
-- the window cannot hide it, and read again where it was not there yet.
local plateModule = ItemTree.UI and ItemTree.UI.Frame or nil

local function plateApi()
  for _, candidate in ipairs({ plateModule, ItemTree.UI and ItemTree.UI.Frame }) do
    if type(candidate) == "table" and type(candidate.NewPlateButton) == "function" then
      return candidate
    end
  end
  return nil
end

local function paintMapIcon(button, state)
  local api = plateApi()
  if api and type(api.PaintPlateButton) == "function" then
    pcall(api.PaintPlateButton, button, state)
  end
end

-- Brief BL26: the map button at the far right of a place row, so the rest of the row keeps its
-- click. Hovering it keeps the row's hover wash and says where the place is; a left click opens
-- the place's map (UIBossLoot.OpenPlaceMap). Brief BL29 draws it as the header's dice button:
-- the red panel plate, or the dice button's fallback (the dim accent fill in a gold edge) where
-- the client art will not draw, with the glyph centred on it (brief BL30: the flat eye, else the
-- arrow). Brief BL31: the button is Frame.NewPlateButton, which paints its own states. nil where
-- the client makes no frame.
local function newMapIcon(frame)
  local api = plateApi()
  if not api then
    return nil
  end
  local ok, button =
    pcall(api.NewPlateButton, frame, UIBossLoot.MAP_ICON_KEY, UIBossLoot.MAP_ICON_FALLBACK, UIBossLoot.MAP_ICON_SIZE)
  if not ok or type(button) ~= "table" then
    return nil
  end
  pcall(button.SetPoint, button, "RIGHT", frame, "RIGHT", -UIBossLoot.GUTTER, 0)
  attachScript(button, "OnEnter", function(self)
    paintMapIcon(self, "hover")
    setShown(frame.hoverFill, true)
    local row = rawget(frame, "rowModel")
    if type(row) == "table" and row.kind == "place" then
      textTooltip(self, UIBossLoot.PlaceMapLine(row), nil)
    end
  end)
  attachScript(button, "OnLeave", function(self)
    paintMapIcon(self, "normal")
    setShown(frame.hoverFill, false)
    hideTooltip()
  end)
  attachScript(button, "OnClick", function(_, mouseButton)
    if mouseButton ~= nil and mouseButton ~= "LeftButton" then
      return
    end
    local target = rawget(frame, "mapTarget")
    if target and UIBossLoot.OpenPlaceMap(target) then
      playCue("click")
    end
  end)
  setShown(button, false)
  return button
end

-- Brief BL26: the name and subtitle end short of the right hand slot, the New badge's alone or the
-- badge and the map icon's, anchored again only when the width changes.
local function placeTextRight(frame, withMap)
  local rightW = UIBossLoot.PlaceRightWidth(withMap)
  if rawget(frame, "textRightW") == rightW then
    return
  end
  frame.textRightW = rightW
  local inset = UIBossLoot.LINE_INSET
  local right = -(UIBossLoot.GUTTER + rightW)
  for _, pair in ipairs({ { frame.name, "TOP", -inset }, { frame.sub, "BOTTOM", inset } }) do
    local text, edge, y = pair[1], pair[2], pair[3]
    if type(text) == "table" and type(text.ClearAllPoints) == "function" then
      pcall(text.ClearAllPoints, text)
      pcall(text.SetPoint, text, edge .. "LEFT", frame, edge .. "LEFT", UIBossLoot.GUTTER, y)
      pcall(text.SetPoint, text, edge .. "RIGHT", frame, edge .. "RIGHT", right, y)
    end
  end
end

-- Brief BL26: the New badge at the far right, or just left of the map icon where the row has one.
local function placeMarkBeside(frame, withMap)
  local cluster = frame.newMark
  if type(cluster) ~= "table" or rawget(frame, "markBesideMap") == withMap then
    return
  end
  frame.markBesideMap = withMap
  if type(cluster.ClearAllPoints) ~= "function" or type(cluster.SetPoint) ~= "function" then
    return
  end
  pcall(cluster.ClearAllPoints, cluster)
  if withMap and frame.mapIcon then
    pcall(cluster.SetPoint, cluster, "RIGHT", frame.mapIcon, "LEFT", -UIBossLoot.PAD, 0)
  else
    pcall(cluster.SetPoint, cluster, "RIGHT", frame, "RIGHT", -UIBossLoot.GUTTER, 0)
  end
end

function PLACE_SPEC.decorate(frame)
  decorateBase(frame)
  decorateTwoLine(frame, UIBossLoot.PlaceRightWidth(false))
  frame.textRightW = UIBossLoot.PlaceRightWidth(false)
  frame.newMark = newCluster(frame, UIBossLoot.MARK_SIZE, 1, nil, UIBossLoot.GUTTER)
  frame.markBesideMap = false
  frame.mapIcon = newMapIcon(frame)
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEnter", function(self)
      onEnterBase(self)
      local tip = UIBossLoot.PlaceTooltip(rawget(self, "rowModel"), rawget(self, "mapTarget") ~= nil)
      if tip then
        textTooltip(self, tip.title, tip.lines)
      end
    end)
    frame:SetScript("OnLeave", onLeaveBase)
    frame:SetScript("OnMouseUp", function(self, button)
      local action = UIBossLoot.Activate("places", rawget(self, "rowModel"), button)
      if action ~= "none" then
        playCue("select")
      end
    end)
  end
end

function PLACE_SPEC.init(frame, row)
  local band = row.kind == "band"
  showBand(frame, band, row.label, nil, band and UIBossLoot.BandIcon(row.band) or nil, true)
  setShown(frame.name, not band)
  setShown(frame.sub, not band)
  local target = not band and UIBossLoot.PlaceMapFor(row) or nil
  if not frame.mapIcon then
    target = nil
  end
  frame.mapTarget = target
  setShown(frame.mapIcon, target ~= nil)
  if band then
    setKinds(frame.newMark, EMPTY)
    return
  end
  placeTextRight(frame, target ~= nil)
  placeMarkBeside(frame, target ~= nil)
  setText(frame.name, row.name)
  setText(frame.sub, UIBossLoot.PlaceSubtitle(row))
  setKinds(frame.newMark, row.isNew and { "new" } or EMPTY)
  paintSelected(frame, row.id == UIBossLoot.state.place, frame.name, frame.sub)
  setShown(frame.hoverFill, false)
end

--------------------------------------------------------------------------------
-- The bosses column
--------------------------------------------------------------------------------

local BOSS_SPEC = {}

-- Brief BL16, made a MaskTexture by brief BL24: the client's round portrait mask (Assets
-- PORTRAIT_MASK) as a MaskTexture region over the portrait's square, made once per row frame.
-- The legacy Texture:SetMask masks a texture's FILE, and a creature portrait is a render target
-- with none: the portrait drawn after it came out square with black corners, and a redraw asking
-- SetMask again rebuilt the texture from its last file, the type glyph, over the portrait. A
-- MaskTexture masks whatever the texture shows and outlives every SetTexture and portrait call,
-- which is how Blizzard masks its own creature portraits (Blizzard_EncounterJournal.xml, the
-- creature buttons' CircleMask, forever branch of Gethe/wow-ui-source). nil where the client
-- cannot make or add one, and the square keeps Q9b's silver edges.
local function newPortraitMask(frame, icon)
  if type(frame.CreateMaskTexture) ~= "function" or type(icon) ~= "table" then
    return nil
  end
  if type(icon.AddMaskTexture) ~= "function" or type(icon.RemoveMaskTexture) ~= "function" then
    return nil
  end
  if not Assets or type(Assets.Get) ~= "function" then
    return nil
  end
  local found, entry = pcall(Assets.Get, UIBossLoot.MASK_KEY)
  if not found or type(entry) ~= "table" or type(entry.path) ~= "string" then
    return nil
  end
  local ok, mask = pcall(frame.CreateMaskTexture, frame)
  if not ok or type(mask) ~= "table" or type(mask.SetTexture) ~= "function" then
    return nil
  end
  local wrap = "CLAMPTOBLACKADDITIVE"
  if not pcall(mask.SetTexture, mask, entry.path, wrap, wrap) then
    return nil
  end
  if type(mask.SetAllPoints) == "function" then
    pcall(mask.SetAllPoints, mask, icon)
  end
  return mask
end

-- Brief BL24: puts the round mask on a texture, or takes it off, under pcall. Answers whether the
-- texture is masked now.
local function setMask(texture, mask, on)
  if type(texture) ~= "table" or type(mask) ~= "table" then
    return false
  end
  if on then
    return type(texture.AddMaskTexture) == "function" and pcall(texture.AddMaskTexture, texture, mask) == true
  end
  if type(texture.RemoveMaskTexture) == "function" then
    pcall(texture.RemoveMaskTexture, texture, mask)
  end
  return false
end

-- How far a badge's medallion art reaches past its own box, so a mark placed beside the count
-- keeps clear of it (the tree's own Tree.BadgeOverhang).
local function badgeOverhang(badgeSize)
  local Badges = ItemTree.Badges
  local art = badgeSize
  if type(Badges) == "table" and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, badgeSize)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - badgeSize) / 2))
end

-- Brief BL23: one square of the diamond, a wash on the row's overlay at the given sublevel (the
-- edge under the blue), hidden until a row asks for it.
local function diamondPart(frame, colorKey, sublevel)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local texture = frame:CreateTexture(nil, UIBossLoot.DIAMOND_LAYER, nil, sublevel)
  if not texture then
    return nil
  end
  if Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey, 1)
  setShown(texture, false)
  return texture
end

-- Brief BL23: turns a square 45 degrees. false where the client has no SetRotation or refuses
-- it, and the square then stays square.
local function turnDiamond(texture)
  if type(texture) ~= "table" or type(texture.SetRotation) ~= "function" then
    return false
  end
  local ok = pcall(texture.SetRotation, texture, UIBossLoot.DIAMOND_ROTATION)
  return ok == true
end

-- Brief BL23: the diamond sized for the row density and placed left of the count, or hidden.
local function paintDiamond(frame, wears)
  local diamond, edge = frame.diamond, frame.diamondEdge
  if wears and diamond then
    local side = UIBossLoot.DiamondSize(UIBossLoot.Density())
    local offset = UIBossLoot.DiamondOffset(side, frame.diamondTurned == true)
    local anchor = frame.count or frame
    local point = frame.count and "LEFT" or "RIGHT"
    diamond:ClearAllPoints()
    diamond:SetSize(side, side)
    diamond:SetPoint("CENTER", anchor, point, -offset, 0)
    if edge then
      local outer = side + 2 * UIBossLoot.DIAMOND_EDGE
      edge:ClearAllPoints()
      edge:SetSize(outer, outer)
      edge:SetPoint("CENTER", diamond, "CENTER", 0, 0)
    end
  end
  setShown(diamond, wears)
  setShown(edge, wears and diamond ~= nil)
end

-- Brief BL8: the count, or "?", is centred on the two line row at its right edge, and takes only
-- the width of its own words, so the New mark sits just left of the digits and centred on the row
-- as well rather than hanging off the name's line at the edge.
function BOSS_SPEC.decorate(frame)
  decorateBase(frame)
  local markGap = UIBossLoot.PAD + badgeOverhang(UIBossLoot.MARK_SIZE)
  frame.markGap = markGap
  decorateTwoLine(frame, UIBossLoot.COUNT_W + UIBossLoot.MARK_SIZE + markGap)
  frame.count = newFontString(frame, UIBossLoot.FONT_SM, UIBossLoot.SUB_WORD, "RIGHT")
  if frame.count then
    frame.count:SetPoint("RIGHT", frame, "RIGHT", -UIBossLoot.GUTTER, 0)
  end
  frame.newMark = newCluster(frame, UIBossLoot.MARK_SIZE, 1, frame.count, markGap)
  frame.nameRight = UIBossLoot.COUNT_W + UIBossLoot.MARK_SIZE + markGap
  -- Brief BL23: the diamond left of the count, in the room the round New mark takes on a new
  -- boss's row (the two never show together). Made and turned once here, sized and placed in
  -- BOSS_SPEC.init.
  frame.diamondEdge = diamondPart(frame, UIBossLoot.DIAMOND_EDGE_COLOR, 0)
  frame.diamond = diamondPart(frame, UIBossLoot.DIAMOND_COLOR, 1)
  frame.diamondTurned = turnDiamond(frame.diamondEdge) and turnDiamond(frame.diamond)
  if not frame.diamondTurned then
    -- A client that turned one part and not the other draws both square.
    for _, part in ipairs({ frame.diamondEdge or false, frame.diamond or false }) do
      if part and type(part.SetRotation) == "function" then
        pcall(part.SetRotation, part, 0)
      end
    end
  end
  -- Brief BL12: the portrait's square at the left, drawn in BOSS_SPEC.init. It is the frame's
  -- icon because the tree's portrait queue (UI/Tree.lua E53) draws into frame.icon.
  frame.icon = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.icon then
    frame.icon:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    frame.icon:Hide()
  end
  -- Brief BL16, raised by brief BL21: the bevelled silver ring round the portrait's disc, centred
  -- on it and sized in paintRing, on the row's overlay above the portrait and the glyph, its open
  -- centre letting the portrait show through. The dark disc sits under the portrait (ARTWORK -1)
  -- and backs it wherever the portrait or the glyph is clear. Both are made once here and hidden
  -- until a rare's row asks for them. The disc is masked round once, for good; a disc the client
  -- will not mask is never shown. Brief BL24: both take the one MaskTexture, frame.iconMask, which
  -- the portrait keeps (see newPortraitMask), so the square's corners stay clear.
  frame.ring, frame.disc, frame.discRound, frame.iconMask = nil, nil, false, nil
  frame.masked = false
  if frame.icon then
    frame.iconMask = newPortraitMask(frame, frame.icon)
    local ring = frame:CreateTexture(nil, UIBossLoot.RING_LAYER, nil, UIBossLoot.RING_SUBLEVEL)
    if ring then
      local drawn = Assets
        and type(Assets.Apply) == "function"
        and select(2, pcall(Assets.Apply, ring, UIBossLoot.RING_KEY)) == true
      ring:Hide()
      if drawn then
        tint(ring, UIBossLoot.RING_COLOR, 1)
        ring:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        frame.ring = ring
      end
    end
    local disc = frame:CreateTexture(nil, "ARTWORK", nil, -1)
    if disc then
      if Assets and type(Assets.Apply) == "function" then
        pcall(Assets.Apply, disc, "FILL_WHITE8X8")
      end
      tint(disc, UIBossLoot.DISC_COLOR, 1)
      disc:SetAllPoints(frame.icon)
      disc:Hide()
      frame.disc = disc
      frame.discRound = setMask(disc, frame.iconMask, true)
    end
  end
  -- Brief Q9b: the square's silver edges, now only where the client will not mask the portrait
  -- round: four one pixel edges anchored to the square itself, so they follow its size in default
  -- and compact rows. On the row's own overlay, made before the crest, hidden until asked for.
  frame.ringEdges = nil
  if frame.icon then
    local edges = {}
    for index = 1, 4 do
      edges[index] = wash(frame, "OVERLAY", UIBossLoot.RING_COLOR, 1)
    end
    if edges[1] and edges[2] and edges[3] and edges[4] then
      local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
      local icon, w = frame.icon, UIBossLoot.RING_W
      top:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
      top:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
      top:SetHeight(w)
      bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
      bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
      bottom:SetHeight(w)
      left:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
      left:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
      left:SetWidth(w)
      right:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
      right:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
      right:SetWidth(w)
      frame.ringEdges = edges
    end
    for _, edge in ipairs(edges) do
      setShown(edge, false)
    end
  end
  -- Brief BL11: the silver dragon crest, placed after the name's words in BOSS_SPEC.init.
  frame.crest = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.crest then
    frame.crest:Hide()
  end
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEnter", function(self)
      onEnterBase(self)
      -- Brief BL20: the rank word and, for a boss shown by its creature's name, the encounter's.
      local tip =
        UIBossLoot.BossTooltip(rawget(self, "rowModel"), rawget(self, "shownName"), rawget(self, "encounterName"))
      if tip then
        textTooltip(self, tip.title, tip.lines, tip.titleKey)
      end
    end)
    frame:SetScript("OnLeave", onLeaveBase)
    frame:SetScript("OnMouseUp", function(self, button)
      local action = UIBossLoot.Activate("bosses", rawget(self, "rowModel"), button)
      if action ~= "none" then
        playCue("select")
      end
    end)
  end
end

-- The crest after the name (brief BL11), or none. The name gives up the crest's room at its right
-- so the crest never reaches the New mark or the count, and the crest sits after the words the
-- name actually draws.
local function paintCrest(frame, row)
  local crest, name = frame.crest, frame.name
  if not crest or not name then
    return false
  end
  local wears = UIBossLoot.WearsCrest(row)
    and Assets
    and type(Assets.Apply) == "function"
    and select(2, pcall(Assets.Apply, crest, UIBossLoot.CREST_KEY)) == true
  local inset = UIBossLoot.LINE_INSET
  local right = frame.nameRight or 0
  local side = UIBossLoot.CrestSize(frame.nameSize or UIBossLoot.FONT_MD)
  if wears then
    right = right + side + UIBossLoot.CREST_GAP
  end
  local left = UIBossLoot.GUTTER + (frame.nameLeft or 0)
  if type(name.ClearAllPoints) == "function" then
    name:ClearAllPoints()
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -inset)
    name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(UIBossLoot.GUTTER + right), -inset)
  end
  local sub = frame.sub
  if sub and type(sub.ClearAllPoints) == "function" then
    sub:ClearAllPoints()
    sub:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, inset)
    sub:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(UIBossLoot.GUTTER + (frame.nameRight or 0)), inset)
  end
  frame.crestShown = wears == true
  if not wears then
    crest:ClearAllPoints()
    crest:Hide()
    return false
  end
  local textWidth = 0
  for _, method in ipairs({ "GetUnboundedStringWidth", "GetStringWidth" }) do
    if type(name[method]) == "function" then
      local ok, width = pcall(name[method], name)
      if ok and tonumber(width) then
        textWidth = tonumber(width)
        break
      end
    end
  end
  -- The name's own width where the client has laid it out, else the row's less its insets.
  local room = widthOf(name)
  if room <= 0 then
    room = math.max(0, widthOf(frame) - UIBossLoot.GUTTER * 2 - right)
  end
  crest:SetSize(side, side)
  crest:ClearAllPoints()
  crest:SetPoint("LEFT", name, "LEFT", UIBossLoot.CrestOffset(textWidth, room), 0)
  crest:Show()
  return true
end

-- Brief BL14: the collector's seen boss record for one entry (C:SeenBoss), a table read, or nil.
local function seenBoss(bossId)
  local instance = ItemTree.collector
  if bossId == nil or type(instance) ~= "table" or type(instance.SeenBoss) ~= "function" then
    return nil
  end
  local ok, record = pcall(instance.SeenBoss, instance, bossId)
  if ok and type(record) == "table" then
    return record
  end
  return nil
end

--- Brief BL20: the name the tab shows a boss by, and the client's encounter name where the two
--- differ (else nil): UIBossLoot.DisplayName over the index entry (read off the model the tab
--- holds) and UIBossLoot.CreatureNameFor. name is the entry's name where the caller has it (a
--- list row's), else it is read off the index's strings. The shown name is nil only where
--- neither the caller nor the index names the entry.
function UIBossLoot.BossNaming(bossId, name)
  local model = UIBossLoot.Model()
  local entry = nil
  if model and bossId ~= nil then
    local ok, index = pcall(model.Index, model)
    entry = ok and type(index) == "table" and type(index.b) == "table" and index.b[bossId] or nil
    if (type(name) ~= "string" or name == "") and type(entry) == "table" and type(index.s) == "table" then
      name = index.s[entry.n]
    end
  end
  if type(entry) ~= "table" then
    return name, nil
  end
  local creatureName = UIBossLoot.CreatureNameFor(entry, seenBoss(bossId))
  local shown = UIBossLoot.DisplayName({ name = name, c = entry.c }, creatureName)
  if shown ~= nil and shown ~= name then
    return shown, name
  end
  return name, nil
end

-- Brief BL17: the collector's seenBosses table itself (C.store.seenBosses), where the loader
-- remembers the display id it confirmed, or nil.
local function seenStore()
  local instance = ItemTree.collector
  local store = type(instance) == "table" and instance.store or nil
  local seen = type(store) == "table" and store.seenBosses or nil
  if type(seen) == "table" then
    return seen
  end
  return nil
end

--- Brief BL17: remembers a display id the loader confirmed for a boss's creature in that boss's
--- seenBosses record, as displayId with the creature it is for as displayCreatureId, so the next
--- session draws the portrait at once and a later data build can ship it. A boss with no record
--- yet gets one holding those two fields alone (no npcId, so C:SeenBoss, the seen boss count and
--- the panel's seen content still see no sighting). Answers whether it was written.
function UIBossLoot.RememberDisplay(bossId, creatureId, display)
  display = UIBossLoot.WholeDisplay(display)
  if not display or type(bossId) ~= "number" or type(creatureId) ~= "number" then
    return false
  end
  local seen = seenStore()
  if not seen then
    return false
  end
  local record = seen[bossId]
  if type(record) ~= "table" then
    record = {}
    seen[bossId] = record
  end
  record.displayId = display
  record.displayCreatureId = creatureId
  return true
end

--- Brief BL17: the display id remembered for a boss whose entry has none of its own (no cd), for
--- the creature its model is drawn from (UIBossLoot.ModelCreatureId), or nil.
function UIBossLoot.RememberedDisplayFor(bossId, entry)
  local seen = bossId ~= nil and seenStore() or nil
  local record = seen and seen[bossId] or nil
  if type(record) ~= "table" then
    return nil
  end
  local creatureId = UIBossLoot.ModelCreatureId(entry, seenBoss(bossId))
  if not creatureId then
    return nil
  end
  return UIBossLoot.RememberedDisplay(record, creatureId)
end

--- Brief PT1 (owner QA 2026-10-19, item 275): the display id a boss's portrait is drawn from, on its
--- row and on the panel's card alike: the index entry's cd, else the one the loader remembered for
--- its creature (BL17), else the Creatures data's first (C4: entry.creaturesDisplay, once
--- UIBossLoot.WithCreaturesRow has filled it). nil where none is known, which leaves the glyph.
function UIBossLoot.BossDisplay(bossId, entry)
  local display = UIBossLoot.PortraitOf(entry) or UIBossLoot.RememberedDisplayFor(bossId, entry)
  if display then
    return display
  end
  return type(entry) == "table" and UIBossLoot.WholeDisplay(entry.creaturesDisplay) or nil
end

-- Brief BL12: the portrait, through the tree's own E53 queue (UI/Tree.lua): the same client call
-- (SetPortraitTextureFromCreatureDisplayID, made by Tree.PortraitTick), the same dwell, the same
-- one call a frame, the same cap and the same "stop asking for good" when the call is missing or
-- raises. A row draws its glyph at once and only offers the portrait; nothing is asked for here.
local function treePortraits()
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  if
    type(Tree) == "table"
    and type(Tree.PortraitPush) == "function"
    and type(Tree.PortraitDrop) == "function"
    and type(Tree.PortraitTick) == "function"
  then
    return Tree
  end
  return nil
end

-- Brief BL24: whether the tree's driver is really running. OnUpdate fires only on a VISIBLE frame,
-- and the tree's driver can be left shown inside the tree's hidden pane while the Boss loot tab is
-- up, with requests still in the queue: asking IsShown alone let this tab wait on a driver that
-- never ran, and no request was served again.
local function driverRuns(driver)
  if type(driver) ~= "table" then
    return false
  end
  if type(driver.IsVisible) == "function" then
    local ok, visible = pcall(driver.IsVisible, driver)
    if ok and type(visible) == "boolean" then
      return visible
    end
  end
  return type(driver.IsShown) == "function" and driver:IsShown() == true
end

-- The tab's own turn of the tree's driver, for while the tree's driver is not running (it is made
-- only when a source row first asks). It ticks the one shared queue, so the rate never doubles:
-- while the tree's driver is up this one does nothing.
local function portraitDriver(Tree)
  local driver = UIBossLoot.portraitDriver
  if not driver then
    driver = newFrame("Frame", rawget(_G, "UIParent"))
    if not driver or type(driver.SetScript) ~= "function" then
      return nil
    end
    driver:SetScript("OnUpdate", function(self, elapsed)
      if not driverRuns(Tree.portraitDriver) then
        Tree.PortraitTick(elapsed)
      end
      if #(Tree.portraits or EMPTY) == 0 then
        self:Hide()
      end
    end)
    driver:Hide()
    UIBossLoot.portraitDriver = driver
  end
  return driver
end

-- Takes a portrait off a pooled frame drawing another row, the way the tree does (tex coords
-- back, a plain texture set), and its request out of the queue. Brief BL19: a frame moving to
-- another boss is washed whether or not it holds a portrait the tree drew, so nothing of the
-- boss it drew before shows while the new one's portrait is queued.
local function portraitClear(frame, Tree, bossId)
  if Tree then
    Tree.PortraitDrop(Tree.portraits or {}, frame)
  end
  local icon = frame.icon
  local moved = rawget(frame, "portraitBoss") ~= bossId
  frame.portraitBoss = bossId
  if (moved or rawget(frame, "itemTreePortrait") ~= nil) and icon then
    frame.itemTreePortrait = nil
    if type(icon.SetTexCoord) == "function" then
      pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
    end
    if type(icon.SetTexture) == "function" then
      pcall(icon.SetTexture, icon, nil)
    end
  end
end

local function paintPortrait(frame, row)
  local icon = frame.icon
  local Tree = treePortraits()
  frame.nameLeft = 0
  if not icon then
    return false
  end
  if not UIBossLoot.PortraitsEnabled() then
    portraitClear(frame, Tree, nil)
    frame.row, frame.layout = nil, nil
    icon:Hide()
    return false
  end
  local model = UIBossLoot.Model()
  local entry = nil
  if model then
    local ok, index = pcall(model.Index, model)
    entry = ok and type(index) == "table" and type(index.b) == "table" and index.b[row.id] or nil
  end
  local side = UIBossLoot.PortraitSize(UIBossLoot.Density())
  icon:SetSize(side, side)
  frame.nameLeft = side + UIBossLoot.PORTRAIT_GAP
  -- Brief C4: the Creatures data's type for the glyph and first display id for the portrait, where
  -- the entry ships neither. Brief BL17: the display id the loader remembered where the entry ships
  -- none. Brief PT1: both through the one rule the panel's card follows (UIBossLoot.BossDisplay).
  entry = UIBossLoot.WithCreaturesRow(entry)
  local display = UIBossLoot.BossDisplay(row.id, entry)
  -- The same creature coming back round keeps its portrait and asks for nothing.
  if display and rawget(frame, "itemTreePortrait") == display then
    frame.portraitBoss = row.id
    frame.row, frame.layout = row, { kind = "row", portrait = display }
    icon:Show()
    return true
  end
  -- Brief BL19: the glyph goes on a washed square before anything is queued, and the queued
  -- request names this row, so a tick that lands after the frame moved on draws nothing (the
  -- tree's own check, UI/Tree.lua portraitLive, compares the frame's row and display to it).
  portraitClear(frame, Tree, row.id)
  frame.row, frame.layout = row, { kind = "row", portrait = display }
  local glyph = UIBossLoot.PortraitGlyph(entry)
  local drawn = glyph ~= nil and select(2, pcall(Assets.Apply, icon, glyph)) == true
  setShown(icon, drawn)
  if not display or not Tree or Tree.portraitsBroken then
    return drawn
  end
  if type(rawget(_G, "SetPortraitTextureFromCreatureDisplayID")) ~= "function" then
    Tree.portraitsBroken = true
    return drawn
  end
  -- The glyph-less square still takes the portrait: shown now, filled when its turn comes.
  icon:Show()
  Tree.portraits = Tree.portraits or {}
  Tree.PortraitPush(Tree.portraits, {
    frame = frame,
    row = row,
    display = display,
    at = Tree.portraitClock or 0,
  }, Tree.PORTRAIT_QUEUE)
  local driver = portraitDriver(Tree)
  if driver then
    driver:Show()
  end
  return true
end

-- Brief BL16: a rare's portrait made round and ringed, shown with the square (the type glyph
-- before the portrait comes and the portrait after, both drawn into the one masked texture) and
-- never on a boss, a chest or a square not drawn. The disc wants the ring art and the mask both;
-- without either the square keeps Q9b's silver edges. A pooled frame changing rank takes the
-- mask, the ring and the disc down again here. Brief BL24: the mask goes on once and stays while
-- the frame draws rares; a redraw never asks for it again.
local function paintRing(frame, row, square)
  local wears = square == true and UIBossLoot.WearsRing(row)
  local icon = frame.icon
  local round = wears and frame.ring ~= nil and frame.iconMask ~= nil
  if round and not frame.masked then
    round = setMask(icon, frame.iconMask, true)
    frame.masked = round
  elseif not round and frame.masked then
    setMask(icon, frame.iconMask, false)
    frame.masked = false
  end
  if round then
    local side = UIBossLoot.RingSize(UIBossLoot.PortraitSize(UIBossLoot.Density()))
    frame.ring:SetSize(side, side)
  end
  setShown(frame.ring, round)
  setShown(frame.disc, round and frame.discRound == true)
  local edged = wears and not round
  for _, edge in ipairs(frame.ringEdges or EMPTY) do
    setShown(edge, edged)
  end
  frame.ringShown = wears
  frame.ringRound = round == true
  return wears
end

function BOSS_SPEC.init(frame, row)
  showBand(frame, false)
  setShown(frame.name, true)
  setShown(frame.sub, true)
  -- Brief BL20: the creature's name where it differs from the client's encounter name.
  local shown, encounter = UIBossLoot.BossNaming(row.id, row.name)
  frame.shownName, frame.encounterName = shown, encounter
  setText(frame.name, shown or row.name)
  local square = paintPortrait(frame, row)
  paintRing(frame, row, square)
  paintCrest(frame, row)
  setText(frame.sub, UIBossLoot.BossMeta(row))
  setText(frame.count, UIBossLoot.BossCountText(row.count))
  setKinds(frame.newMark, row.isNew and { "new" } or EMPTY)
  paintDiamond(frame, row.newLoot == true and not row.isNew)
  paintSelected(frame, row.id == UIBossLoot.state.boss, frame.name, frame.sub)
  setShown(frame.hoverFill, false)
end

--------------------------------------------------------------------------------
-- The Loot sub pane (the right column under the boss header)
--------------------------------------------------------------------------------

local Loot = {}
UIBossLoot.Loot = Loot
UIBossLoot.SUBPANES.Loot = Loot

local LOOT_SPEC = {}

function LOOT_SPEC.decorate(frame)
  decorateBase(frame)
  frame.icon = type(frame.CreateTexture) == "function" and frame:CreateTexture(nil, "ARTWORK") or nil
  if frame.icon then
    frame.icon:SetSize(UIBossLoot.ICON_SIZE, UIBossLoot.ICON_SIZE)
    frame.icon:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
  end
  local badgeW = UIBossLoot.BADGE_MAX * (UIBossLoot.BADGE_SIZE + 3)
  frame.cluster = newCluster(frame, UIBossLoot.BADGE_SIZE, UIBossLoot.BADGE_MAX, nil, UIBossLoot.GUTTER)
  frame.rate = newFontString(frame, UIBossLoot.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  if frame.rate then
    frame.rate:SetWidth(UIBossLoot.RATE_W)
    frame.rate:SetPoint("RIGHT", frame, "RIGHT", -(UIBossLoot.GUTTER + badgeW + UIBossLoot.GUTTER), 0)
  end
  frame.name = newFontString(frame, UIBossLoot.FONT_MD, "ITEMTREE_COLOR_TEXT_BODY", "LEFT")
  frame.fontSize = UIBossLoot.FONT_MD
  if frame.name then
    if frame.icon then
      frame.name:SetPoint("LEFT", frame.icon, "RIGHT", UIBossLoot.GUTTER, 0)
    else
      frame.name:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    end
    frame.name:SetPoint("RIGHT", frame.rate or frame, frame.rate and "LEFT" or "RIGHT", -UIBossLoot.GUTTER, 0)
  end
  frame.note = newFontString(frame, UIBossLoot.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if frame.note then
    frame.note:SetPoint("LEFT", frame, "LEFT", UIBossLoot.GUTTER, 0)
    frame.note:SetPoint("RIGHT", frame, "RIGHT", -UIBossLoot.GUTTER, 0)
  end
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEnter", function(self)
      onEnterBase(self)
      local row = rawget(self, "rowModel")
      if type(row) == "table" and row.kind == "item" then
        UIBossLoot.ShowItemTooltip(self, row)
      end
    end)
    frame:SetScript("OnLeave", onLeaveBase)
    frame:SetScript("OnMouseUp", function(self, button)
      local action = UIBossLoot.Activate("loot", rawget(self, "rowModel"), button)
      if action == "open" then
        playCue("click")
      end
    end)
  end
end

local function paintIcon(texture, icon)
  if type(texture) ~= "table" then
    return
  end
  local drawn = false
  if icon ~= nil and type(texture.SetTexture) == "function" then
    drawn = pcall(texture.SetTexture, texture, icon)
  end
  if not drawn and Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "ICON_QUESTIONMARK")
  end
  texture:Show()
end

-- Brief BL8: an item row's icon and name follow the density the tree draws at, applied on every
-- draw so the footer's Compact rows box takes effect on the next redraw.
local function applyDensity(frame)
  local layout = UIBossLoot.ItemLayout(UIBossLoot.Density())
  frame.itemLayout = layout
  if frame.icon and type(frame.icon.SetSize) == "function" then
    frame.icon:SetSize(layout.icon, layout.icon)
  end
  if frame.name and frame.fontSize ~= layout.font then
    frame.fontSize = layout.font
    styleText(frame.name, layout.font, UIBossLoot.NAME_WORD, "LEFT")
  end
end

function LOOT_SPEC.init(frame, row)
  local kind = row.kind
  showBand(frame, kind == "group", row.word, kind == "group" and UIBossLoot.CountText(row.count) or nil)
  applyDensity(frame)
  local item = kind == "item" and row.item or nil
  setShown(frame.icon, item ~= nil)
  setShown(frame.name, item ~= nil)
  setShown(frame.rate, item ~= nil)
  setShown(frame.note, kind == "note")
  -- The keyboard's cursor (brief BL4), only while the loot column has the keyboard.
  local state = UIBossLoot.state
  paintSelected(frame, kind == "item" and state.focus == "loot" and row.id == state.cursor)
  setShown(frame.hoverFill, false)
  if kind == "note" then
    setText(frame.note, row.text)
  end
  if not item then
    setKinds(frame.cluster, EMPTY)
    return
  end
  paintIcon(frame.icon, item.icon)
  setText(frame.name, item.name)
  local qualityKey = nil
  if item.quality ~= nil and Theme and type(Theme.QualityKey) == "function" then
    qualityKey = Theme.QualityKey(item.quality)
  end
  -- Brief BL25: never dimmed. A Verified, Classic Era or guessed row draws its quality colour at
  -- full strength, as the creature page does; the group header, the badges and the rate carry
  -- the difference.
  colourText(frame.name, qualityKey or "ITEMTREE_COLOR_TEXT_MUTED")
  setText(frame.rate, item.rate or "")
  setKinds(frame.cluster, UIBossLoot.ItemKinds(item), item.id, item.basis)
end

local function buildBanner(region)
  local banner = newFrame("Frame", region)
  if not banner then
    return nil
  end
  banner:SetHeight(UIBossLoot.BANNER_H)
  banner:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
  banner:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
  if type(banner.EnableMouse) == "function" then
    banner:EnableMouse(true)
  end
  banner.icon = type(banner.CreateTexture) == "function" and banner:CreateTexture(nil, "ARTWORK") or nil
  if banner.icon then
    banner.icon:SetSize(UIBossLoot.BANNER_ICON, UIBossLoot.BANNER_ICON)
    banner.icon:SetPoint("LEFT", banner, "LEFT", UIBossLoot.GUTTER, 0)
    if Assets and type(Assets.Apply) == "function" then
      pcall(Assets.Apply, banner.icon, UIBossLoot.BANNER_ART)
    end
  end
  banner.text = newFontString(banner, UIBossLoot.FONT_SM, "ITEMTREE_COLOR_TEXT_MUTED", "LEFT")
  if banner.text then
    banner.text:SetPoint("LEFT", banner.icon or banner, banner.icon and "RIGHT" or "LEFT", UIBossLoot.PAD, 0)
    banner.text:SetPoint("RIGHT", banner, "RIGHT", -UIBossLoot.GUTTER, 0)
  end
  attachScript(banner, "OnEnter", function(self)
    local words = self.words
    if type(words) == "table" then
      textTooltip(self, words.text, words.lines)
    end
  end)
  attachScript(banner, "OnLeave", hideTooltip)
  banner:Hide()
  return banner
end

--------------------------------------------------------------------------------
-- The empty state, laid out as the tree lays its own (brief BL8)
--------------------------------------------------------------------------------

-- The tree's pure layout where UI/Tree.lua is loaded (Tree.EmptyBlock, Tree.EmptyArt), so the
-- illustration, the heading and the lines are the same sizes, colours and placement as the
-- sources empty state; a plain stack of the same pieces where it is not.
local function treeModule()
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  if type(Tree) == "table" and type(Tree.EmptyBlock) == "function" then
    return Tree
  end
  return nil
end

local function emptyArtKey()
  local Tree = treeModule()
  if Tree and type(Tree.EmptyArt) == "function" then
    local ok, key = pcall(Tree.EmptyArt)
    if ok and type(key) == "string" then
      return key
    end
  end
  if Assets and type(Assets.Has) == "function" then
    if Assets.Has(UIBossLoot.EMPTY_ART_KEY) then
      return UIBossLoot.EMPTY_ART_KEY
    end
    if Assets.Has(UIBossLoot.EMPTY_ART_FALLBACK) then
      return UIBossLoot.EMPTY_ART_FALLBACK
    end
  end
  return nil
end

--- A layout with the illustration taken out (brief BL9): no art box, the gap under it gone from
--- the block's height, and the words centred in the area on their own the way Tree.EmptyBlock
--- centres a block that had no room for its picture. An area with no size keeps the top it had.
--- Pure.
function UIBossLoot.TextOnlyLayout(layout, height)
  if type(layout) ~= "table" then
    return layout
  end
  local artHeight = tonumber(layout.artHeight) or 0
  local total = tonumber(layout.height)
  if total and artHeight > 0 then
    total = total - artHeight - (tonumber(layout.gap) or 0)
  end
  layout.artWidth, layout.artHeight = 0, 0
  if total then
    layout.height = math.max(0, total)
    height = tonumber(height) or 0
    if height > 0 then
      layout.top = math.max(0, math.floor((height - layout.height) / 2))
    end
  end
  return layout
end

--- Where the empty state's pieces go in an area this size: Tree.EmptyBlock's answer where the
--- tree is loaded, else the same shape from this file's own sizes. { width, gap, lineGap,
--- headingSize, lineSize, artWidth, artHeight, height (the tree's only), top }. A spec with art
--- false gets UIBossLoot.TextOnlyLayout's answer.
function UIBossLoot.EmptyLayout(width, height, spec)
  local textOnly = type(spec) == "table" and spec.art == false
  local Tree = treeModule()
  if Tree then
    local ok, layout = pcall(Tree.EmptyBlock, width, height, spec)
    if ok and type(layout) == "table" then
      if textOnly then
        return UIBossLoot.TextOnlyLayout(layout, height)
      end
      return layout
    end
  end
  local aspect = 1
  local key = emptyArtKey()
  if key and Assets and type(Assets.Aspect) == "function" then
    local ok, value = pcall(Assets.Aspect, key)
    aspect = (ok and tonumber(value)) or 1
  end
  local artWidth = UIBossLoot.EMPTY_ART_W
  if textOnly then
    artWidth = 0
  end
  return {
    width = UIBossLoot.EMPTY_W,
    gap = UIBossLoot.GAP,
    lineGap = UIBossLoot.PAD,
    headingSize = UIBossLoot.FONT_LG,
    lineSize = UIBossLoot.FONT_MD,
    artWidth = artWidth,
    artHeight = math.floor(artWidth / math.max(aspect, 0.1) + 0.5),
    top = UIBossLoot.GAP,
  }
end

-- One wrapped, centred string of the block at a face and size, the font put back where the face
-- will not load, as the tree's own wrapText does.
local function emptyText(fontString, width, text, colorKey, fontSize, face)
  if type(fontString) ~= "table" then
    return false
  end
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  colourText(fontString, colorKey)
  if type(fontString.SetWidth) == "function" then
    fontString:SetWidth(width)
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH("CENTER")
  end
  wrapText(fontString)
  setText(fontString, text)
  fontString:Show()
  return true
end

local function buildEmpty(region)
  local block = newFrame("Frame", region)
  if not block then
    return nil
  end
  if type(block.EnableMouse) == "function" then
    block:EnableMouse(false)
  end
  block.art = type(block.CreateTexture) == "function" and block:CreateTexture(nil, "ARTWORK") or nil
  block.title = newFontString(block, UIBossLoot.FONT_LG, "ITEMTREE_COLOR_TEXT_TITLE", "CENTER")
  block.line = newFontString(block, UIBossLoot.FONT_MD, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  block.note = newFontString(block, UIBossLoot.FONT_MD, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER")
  block:Hide()
  return block
end

-- Draws one empty state into the block, in the area it is anchored to: the illustration at its
-- own shape, then the heading, then the line and the note, each hung off the piece above it. A
-- text only state (brief BL9) hides the illustration and unhooks it, so the heading is the top
-- of the block and nothing is left hanging off a hidden picture.
local function drawEmpty(block, empty, width, height)
  local spec = UIBossLoot.EmptySpec(empty)
  if type(block) ~= "table" or not spec then
    return false
  end
  local layout = UIBossLoot.EmptyLayout(width, height, spec)
  local previous = nil
  local function stack(region, gap)
    region:ClearAllPoints()
    if previous then
      region:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
    else
      region:SetPoint("TOP", block, "TOP", 0, -(tonumber(layout.top) or 0))
    end
    previous = region
  end
  local art, key = block.art, emptyArtKey()
  block.artKey = nil
  if art then
    if empty.art and key and (tonumber(layout.artHeight) or 0) > 0 and pcall(Assets.Apply, art, key) then
      art:SetSize(layout.artWidth, layout.artHeight)
      stack(art, 0)
      art:Show()
      block.artKey = key
    else
      art:ClearAllPoints()
      art:Hide()
    end
  end
  local titleFace = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_TITLE
  local bodyFace = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  if block.title then
    emptyText(block.title, layout.width, spec.heading, "ITEMTREE_COLOR_TEXT_TITLE", layout.headingSize, titleFace)
    stack(block.title, layout.gap)
  end
  for index, part in ipairs({ block.line, block.note }) do
    local text = spec.lines[index]
    if text then
      emptyText(part, layout.width, text, "ITEMTREE_COLOR_TEXT_MUTED", layout.lineSize, bodyFace)
      stack(part, index == 1 and layout.gap or layout.lineGap)
    else
      setText(part, "")
      setShown(part, false)
    end
  end
  block:Show()
  return true
end

--------------------------------------------------------------------------------
-- The creature panel beside the loot (brief BL8)
--------------------------------------------------------------------------------

-- The boss's creature column, drawn by UI/InfoPanel.lua's own builders into a surface of its own
-- (InfoPanel.NewSurface) at the left of the Loot sub pane: the portrait or model, the name, Type,
-- Level and the Predicted line, exactly as a creature page draws them. It belongs to the Loot sub
-- pane, so a later Map sub pane never shows it.
--
-- When: for the chosen boss, whether the player picked it or a place click picked it for them
-- (UIBossLoot.state.creature follows state.boss, brief BL9), and in every state of the right
-- column, the empty states included. An entry with no creature page (no e, Oggleflint in Ragefire
-- Chasm) still has its panel from its index entry; only the Creature page button needs e.
-- The model (SetDisplayInfo, under pcall inside InfoPanel) is loaded then and only then, and is
-- cleared and hidden when another boss is picked, when the Loot sub pane hides and when the tab
-- hides (Release). Everything it draws comes from the boss index (UIBossLoot.CreatureContent):
-- the tab never builds EraSources or its loot index, a boss click included.

local function infoPanel()
  local info = ItemTree.UI and ItemTree.UI.InfoPanel
  if type(info) == "table" and type(info.NewSurface) == "function" and type(info.DrawContent) == "function" then
    return info
  end
  return nil
end

local function panelIcon(surface)
  return type(surface) == "table" and type(surface.frame) == "table" and surface.frame.icon or nil
end

-- Brief BL19: takes the portrait off the panel's header square the moment the selection changes,
-- the way the rows wash theirs (tex coords back, a plain texture set), so the glyph or the "?"
-- InfoPanel draws next goes on a clean square and never over the previous boss's face.
local function panelPortraitClear(surface)
  local icon = panelIcon(surface)
  if type(icon) ~= "table" then
    return false
  end
  surface.portraitBoss, surface.portraitDisplay = nil, nil
  if type(icon.SetTexCoord) == "function" then
    pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
  end
  if type(icon.SetTexture) == "function" then
    pcall(icon.SetTexture, icon, nil)
  end
  return true
end

--- Takes the creature panel down: its model cleared and hidden, the panel hidden. Idempotent.
function Loot.ClearCreature()
  local info = ItemTree.UI and ItemTree.UI.InfoPanel
  if Loot.creature and type(info) == "table" and type(info.ClearSurface) == "function" then
    pcall(info.ClearSurface, Loot.creature)
  end
  -- Brief BL19: the header's portrait goes with the boss it was for.
  panelPortraitClear(Loot.creature)
  -- Brief BL14: the creature id a model was drawn from goes with it. Brief BL17: and so does its
  -- load, so a retry in flight never draws into the next boss.
  local block = type(Loot.creature) == "table" and Loot.creature.modelBlock or nil
  if type(block) == "table" then
    block.creatureId = nil
    UIBossLoot.CancelCreatureModel(block.model)
  end
  setShown(Loot.creatureHost, false)
  local was = Loot.creatureBoss ~= nil
  Loot.creatureKey = nil
  Loot.creatureBoss = nil
  Loot.creatureShown = false
  return was
end

-- Draws the panel for the chosen boss where the player asked for it, and takes it down otherwise.
-- A redraw of the same boss (a refresh, the Compact rows box) keeps what is drawn and loads
-- nothing again. Answers whether the panel is up.
-- The boss's own index entry and name, read off the index the tab already holds.
local function bossEntry(bossId, answer)
  local model = UIBossLoot.Model()
  if not model or bossId == nil then
    return nil
  end
  local ok, index = pcall(model.Index, model)
  local entry = ok and type(index) == "table" and type(index.b) == "table" and index.b[bossId] or nil
  -- Brief C4: the Creatures data's type and rank where the entry ships none.
  entry = UIBossLoot.WithCreaturesRow(entry)
  local boss = type(answer) == "table" and answer.boss or nil
  local name = type(boss) == "table" and boss.name or nil
  -- An answer with no boss on it (or none at all) still names the panel from the index's strings.
  if (type(name) ~= "string" or name == "") and type(entry) == "table" and ok and type(index.s) == "table" then
    name = index.s[entry.n]
  end
  -- Brief BL20: the panel names the creature as the list does.
  name = UIBossLoot.BossNaming(bossId, name) or name
  return entry, name
end

-- Brief BL17: the creature model loader. A PlayerModel asked for a creature the client has never
-- seen (SetCreature) sends the server a query and keeps drawing whatever it drew last until the
-- answer comes, and the first call can fail silently: the owner saw the previous boss's model
-- under a new boss's name. The loader clears the model first (the glyph under it stays up), asks,
-- and confirms with GetDisplayInfo() (non zero once the client has the creature) straight away,
-- on OnModelLoaded (HookScript on our own PlayerModel, once per frame) and on a C_Timer.After
-- ladder (UIBossLoot.ModelRetryDelay) that asks again while the answer is 0, then gives up
-- quietly. Each call is a load of its own (a table with a token); the model's current load is
-- kept by frame, and a timer or a hook whose load is no longer current does nothing, so a load
-- superseded by another selection never draws into it.
UIBossLoot.modelLoads = setmetatable({}, { __mode = "k" })
local modelHooked = setmetatable({}, { __mode = "k" })
local loadTokens = 0

local function modelDisplay(model)
  if type(model.GetDisplayInfo) ~= "function" then
    return nil
  end
  local ok, display = pcall(model.GetDisplayInfo, model)
  return ok and UIBossLoot.WholeDisplay(display) or nil
end

local function currentLoad(load)
  return UIBossLoot.modelLoads[load.model] == load
end

-- Reads the display id for a current load, and on the first non zero answer hands it on. Answers
-- whether the load is done.
local function confirmLoad(load)
  if load.display then
    return true
  end
  if not currentLoad(load) then
    return false
  end
  local display = modelDisplay(load.model)
  if not display then
    return false
  end
  load.display = display
  if type(load.onLoaded) == "function" then
    pcall(load.onLoaded, display, load)
  end
  return true
end

local function onModelLoaded(model)
  local load = UIBossLoot.modelLoads[model]
  if load then
    confirmLoad(load)
  end
end

local function hookModel(model)
  if modelHooked[model] or type(model.HookScript) ~= "function" then
    return
  end
  if type(model.HasScript) == "function" then
    local ok, has = pcall(model.HasScript, model, "OnModelLoaded")
    if not ok or not has then
      return
    end
  end
  if pcall(model.HookScript, model, "OnModelLoaded", onModelLoaded) then
    modelHooked[model] = true
  end
end

-- One step of the ladder: wait, read, and ask again while the answer is 0 and a try is left.
local function scheduleLoad(load)
  local delay = UIBossLoot.ModelRetryDelay(load.tries)
  local timer = rawget(_G, "C_Timer")
  if not delay or type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  local ok = pcall(timer.After, delay, function()
    if load.display or not currentLoad(load) then
      return
    end
    local step = UIBossLoot.ModelLoadStep(load.tries, modelDisplay(load.model))
    if step == "done" then
      confirmLoad(load)
      return
    end
    if step ~= "retry" or not pcall(load.model.SetCreature, load.model, load.creatureId) then
      load.gaveUp = true
      return
    end
    load.tries = load.tries + 1
    if not confirmLoad(load) then
      scheduleLoad(load)
    end
  end)
  return ok
end

--- Brief BL17: loads a creature's model into one of our PlayerModel frames by creature id:
--- ClearModel, SetCreature, then the confirmation and the retry ladder above. onLoaded(display,
--- load) is called once, with the display id GetDisplayInfo() answered, and only while this load
--- is the model's current one. Answers the load ({ token, model, creatureId, tries, display,
--- gaveUp }), or nil where the model or the id will not do or SetCreature raised.
function UIBossLoot.LoadCreatureModel(model, creatureId, onLoaded)
  if type(model) ~= "table" or type(model.SetCreature) ~= "function" then
    return nil
  end
  if type(creatureId) ~= "number" or creatureId <= 0 or creatureId ~= math.floor(creatureId) then
    return nil
  end
  loadTokens = loadTokens + 1
  local load = { token = loadTokens, model = model, creatureId = creatureId, onLoaded = onLoaded, tries = 0 }
  UIBossLoot.modelLoads[model] = load
  if type(model.ClearModel) == "function" then
    pcall(model.ClearModel, model)
  end
  hookModel(model)
  if not pcall(model.SetCreature, model, creatureId) then
    UIBossLoot.modelLoads[model] = nil
    return nil
  end
  load.tries = 1
  if not confirmLoad(load) then
    scheduleLoad(load)
  end
  return load
end

--- Brief BL17: drops the model's current load, so nothing it has in flight draws. Answers whether
--- there was one.
function UIBossLoot.CancelCreatureModel(model)
  if type(model) == "table" and UIBossLoot.modelLoads[model] ~= nil then
    UIBossLoot.modelLoads[model] = nil
    return true
  end
  return false
end

--- Brief BL14: draws the panel's model from a creature id where the entry has no display id,
--- after InfoPanel has drawn the block with its glyph. Brief BL17: through the loader
--- (UIBossLoot.LoadCreatureModel), so the model is cleared first, confirmed by its display id and
--- asked for again while the client does not have the creature; the glyph stays up until the
--- load is confirmed, and onLoaded(display) follows it. Answers whether the call was made.
function UIBossLoot.ApplyCreatureModel(surface, creatureId, onLoaded)
  local block = type(surface) == "table" and surface.modelBlock or nil
  local model = type(block) == "table" and block.model or nil
  if type(model) ~= "table" or type(model.SetCreature) ~= "function" or type(creatureId) ~= "number" then
    return false
  end
  local function frameModel()
    local info = ItemTree.UI and ItemTree.UI.InfoPanel
    if type(info) ~= "table" then
      return
    end
    if info.MODEL_ZOOM and type(model.SetPortraitZoom) == "function" then
      pcall(model.SetPortraitZoom, model, info.MODEL_ZOOM)
    end
    if info.MODEL_ROTATION and type(model.SetRotation) == "function" then
      if not pcall(model.SetRotation, model, info.MODEL_ROTATION, false) then
        pcall(model.SetRotation, model, info.MODEL_ROTATION)
      end
    end
  end
  block.creatureId = creatureId
  local load = UIBossLoot.LoadCreatureModel(model, creatureId, function(display)
    if block.creatureId ~= creatureId or block.model ~= model then
      return
    end
    frameModel()
    if block.glyph and type(block.glyph.Hide) == "function" then
      block.glyph:Hide()
    end
    if type(onLoaded) == "function" then
      pcall(onLoaded, display)
    end
  end)
  if not load then
    block.creatureId = nil
    return false
  end
  frameModel()
  if type(model.Show) == "function" then
    model:Show()
  end
  return true
end

-- Brief BL17: the creature's portrait on the panel's header square (InfoPanel's surface.frame.icon,
-- our own texture), where the "?" or the type glyph stood. Brief BL19: only for the boss the panel
-- draws now. Answers whether it was drawn.
local function panelPortrait(surface, display, bossId)
  local icon = panelIcon(surface)
  local call = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
  if type(icon) ~= "table" or type(call) ~= "function" or not UIBossLoot.WholeDisplay(display) then
    return false
  end
  if bossId == nil or Loot.creatureBoss ~= bossId then
    return false
  end
  if type(icon.SetTexCoord) == "function" then
    pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
  end
  if not pcall(call, icon, display) then
    return false
  end
  surface.portraitBoss, surface.portraitDisplay = bossId, display
  -- Brief PT1: and the card's content says so, so a redraw of the same card (a resize,
  -- InfoPanel.OnSizeChanged) draws the face again rather than the glyph, and the debug line knows.
  local content = surface.content
  if type(content) == "table" and type(content.header) == "table" then
    content.header.portrait = display
  end
  surface.headerPortrait = { display = display, drawn = true }
  if type(icon.Show) == "function" then
    icon:Show()
  end
  return true
end

-- Brief BL17: redraws the boss rows showing one boss, so a display id just remembered puts its
-- portrait on the row through the tree's own queue (paintPortrait).
local function repaintBossRows(bossId)
  local list = UIBossLoot.lists.bosses
  if type(list) ~= "table" then
    return 0
  end
  local count = 0
  local function repaint(frame)
    local row = type(frame) == "table" and frame.rowModel or nil
    if type(row) == "table" and row.kind == "boss" and row.id == bossId then
      BOSS_SPEC.init(frame, row)
      count = count + 1
    end
  end
  for frame in pairs(list.frames or EMPTY) do
    repaint(frame)
  end
  for _, frame in ipairs(list.pool or EMPTY) do
    if not (list.frames and list.frames[frame]) then
      repaint(frame)
    end
  end
  return count
end

--- Brief BL17: what follows a confirmed load for the chosen boss: the display id remembered in
--- its seenBosses record, its portrait on the panel's header and on its row. Nothing where the
--- panel has moved on to another boss. Brief BL19: token is the panel draw the load was asked
--- for (Loot.creatureToken); a load from an earlier draw, even of the same boss, draws nothing.
function UIBossLoot.CreatureLoaded(bossId, creatureId, display, token)
  if Loot.creatureBoss ~= bossId then
    return false
  end
  if token ~= nil and token ~= Loot.creatureToken then
    return false
  end
  UIBossLoot.RememberDisplay(bossId, creatureId, display)
  panelPortrait(Loot.creature, display, bossId)
  repaintBossRows(bossId)
  return true
end

local function drawCreature(answer)
  local state = UIBossLoot.state
  local wanted = state.boss ~= nil and state.creature == state.boss
  local info = wanted and infoPanel() or nil
  if not info or not Loot.creatureHost then
    Loot.ClearCreature()
    return false
  end
  if Loot.creatureShown and Loot.creatureBoss == state.boss then
    return true
  end
  Loot.ClearCreature()
  local entry, name = bossEntry(state.boss, answer)
  local settings = ItemTree.db and ItemTree.db.settings
  local showPredicted = not (type(settings) == "table" and settings.showPredicted == false)
  local seen = seenBoss(state.boss)
  -- Brief GS5b: a Predicted row is a guess, so a new boss listing only guesses still says its
  -- loot is not yet known.
  local hasLoot = false
  for _, row in ipairs(type(answer) == "table" and type(answer.rows) == "table" and answer.rows or EMPTY) do
    if type(row) == "table" and row.guess == nil then
      hasLoot = true
      break
    end
  end
  local content = UIBossLoot.CreatureContent(entry, name, showPredicted, seen, hasLoot)
  if type(content) ~= "table" then
    return false
  end
  -- Brief BL14: a model drawn from a creature id alone needs its block held open, so a panel
  -- with no glyph of its own wears the unknown creature's until the model comes.
  local creatureId = UIBossLoot.ModelCreatureId(entry, seen)
  if creatureId and type(content.header) == "table" and content.header.asset == nil then
    content.header.asset = UIBossLoot.SEEN_GLYPH
  end
  -- Brief PT1 (owner QA 2026-10-19, item 275): the square beside the name wears the face the
  -- boss's row wears, by the same rule (UIBossLoot.BossDisplay), and InfoPanel draws it there in
  -- place of the glyph. Before this only a boss with no cd took a face, once its model loaded
  -- (BL17), so every boss shipping a cd (Faldrim Anvilmar's 142826) kept its type glyph.
  local portrait = UIBossLoot.BossDisplay(state.boss, entry)
  if portrait and type(content.header) == "table" then
    content.header.portrait = portrait
  end
  if not Loot.creature then
    local made, surface = pcall(info.NewSurface, Loot.creatureHost)
    Loot.creature = made and surface or nil
  end
  if not Loot.creature then
    return false
  end
  Loot.creatureHost:Show()
  local drew = pcall(info.DrawContent, content, Loot.creature)
  if not drew then
    Loot.ClearCreature()
    return false
  end
  -- The creature page key where the entry has one (nil where it has none), and the boss drawn,
  -- set before the model is asked for, so a load the client answers at once finds its boss.
  local bossId = state.boss
  Loot.creatureKey = UIBossLoot.CreatureKey()
  Loot.creatureBoss = bossId
  Loot.creatureShown = true
  Loot.creatureToken = (Loot.creatureToken or 0) + 1
  local token = Loot.creatureToken
  -- Brief BL19: the boss the square's face is for. Brief PT1: InfoPanel drew it from the header's
  -- portrait above (a display id remembered from an earlier load among them, BL17).
  local drawn = Loot.creature.headerPortrait
  if type(drawn) == "table" and drawn.drawn == true then
    Loot.creature.portraitBoss, Loot.creature.portraitDisplay = bossId, drawn.display
  end
  if creatureId then
    UIBossLoot.ApplyCreatureModel(Loot.creature, creatureId, function(display)
      UIBossLoot.CreatureLoaded(bossId, creatureId, display, token)
    end)
  end
  Loot.creatureDraws = (Loot.creatureDraws or 0) + 1
  return true
end

--------------------------------------------------------------------------------
-- The Loot sub pane's own calls
--------------------------------------------------------------------------------

--- Builds the Loot sub pane inside the sub region the right column hands it. Idempotent.
function Loot.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  if Loot.region == region and Loot.list then
    return true
  end
  Loot.region = region
  -- The creature panel's own frame, at the left. Empty and hidden until a boss is picked.
  local creatureHost = newFrame("Frame", region)
  if creatureHost then
    creatureHost:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    creatureHost:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    creatureHost:SetWidth(UIBossLoot.CREATURE_W)
    creatureHost:Hide()
  end
  Loot.creatureHost = creatureHost
  Loot.banner = buildBanner(region)
  local host = newFrame("Frame", region)
  if not host then
    return false
  end
  host:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
  Loot.host = host
  Loot.list = newList("loot", host, LOOT_SPEC)
  Loot.empty = buildEmpty(region)
  return Loot.list ~= nil
end

-- The banner, the list and the empty state take the room right of the creature panel where it is
-- up (UIBossLoot.LootSplit), and the whole width otherwise; the list starts under the banner
-- while the banner is up. Answers the area's width and height, for the empty state's layout.
local function placeLootParts(withBanner)
  local region = Loot.region
  if not region then
    return 0, 0
  end
  local width = widthOf(region)
  local _, left = UIBossLoot.LootSplit(width, Loot.creatureShown)
  local banner, host, block = Loot.banner, Loot.host, Loot.empty
  if banner and type(banner.ClearAllPoints) == "function" then
    banner:ClearAllPoints()
    banner:SetPoint("TOPLEFT", region, "TOPLEFT", left, 0)
    banner:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
  end
  if host and type(host.ClearAllPoints) == "function" then
    host:ClearAllPoints()
    local top = withBanner and -UIBossLoot.BANNER_H or 0
    host:SetPoint("TOPLEFT", region, "TOPLEFT", left, top)
    host:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
  end
  if block and type(block.ClearAllPoints) == "function" then
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", region, "TOPLEFT", left + UIBossLoot.GUTTER, 0)
    block:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -UIBossLoot.GUTTER, 0)
  end
  local height = 0
  if type(region.GetHeight) == "function" then
    local ok, value = pcall(region.GetHeight, region)
    height = (ok and tonumber(value)) or 0
  end
  return math.max(0, width - left - 2 * UIBossLoot.GUTTER), height
end

--- Draws one answer: the creature panel where the player picked the boss, then the empty state,
--- or the banner and the list.
function Loot.Show(answer, hasPlace)
  if not Loot.region then
    return false
  end
  Loot.region:Show()
  Loot.answer = answer
  drawCreature(answer)
  local empty = UIBossLoot.EmptyState(answer, hasPlace)
  local rows, anyEra = UIBossLoot.LootRows(answer)
  if empty then
    clearList(Loot.list)
    setShown(Loot.host, false)
    setShown(Loot.banner, false)
    local width, height = placeLootParts(false)
    drawEmpty(Loot.empty, empty, width, height)
    return true
  end
  setShown(Loot.empty, false)
  local words = anyEra and UIBossLoot.EraBanner() or nil
  if Loot.banner then
    Loot.banner.words = words
    if words then
      setText(Loot.banner.text, words.text)
    end
    setShown(Loot.banner, words ~= nil)
  end
  placeLootParts(words ~= nil)
  setShown(Loot.host, true)
  return drawList(Loot.list, rows)
end

function Loot.Refresh()
  return Loot.Show(Loot.answer, UIBossLoot.state.place ~= nil)
end

--- Lets go of the rows it drew: the provider is emptied, the pooled frames drop their rows, and
--- the creature panel's model is cleared and hidden.
function Loot.Release()
  Loot.answer = nil
  clearList(Loot.list)
  Loot.ClearCreature()
  if Loot.banner then
    Loot.banner.words = nil
  end
end

function Loot.Hide()
  Loot.Release()
  setShown(Loot.region, false)
  return true
end

--------------------------------------------------------------------------------
-- The right column's header: the boss name and the Creature page button
--------------------------------------------------------------------------------

local function paintCreatureButton(button, enabled)
  if type(button) ~= "table" then
    return
  end
  button.pageEnabled = enabled
  local text = enabled and "ITEMTREE_COLOR_TEXT_BODY" or "ITEMTREE_COLOR_TEXT_DISABLED"
  colourText(button.label, text)
  for _, hairline in ipairs(button.edges or EMPTY) do
    tint(hairline, enabled and UIBossLoot.PANEL_BORDER or "ITEMTREE_COLOR_BORDER_DIVIDER")
  end
end

local function buildHeader(parent)
  local header = newFrame("Frame", parent)
  if not header then
    return nil
  end
  header:SetHeight(UIBossLoot.HEADER_H)
  local button = newFrame("Button", header)
  if button then
    button:SetSize(UIBossLoot.BUTTON_W, UIBossLoot.BUTTON_H)
    button:SetPoint("RIGHT", header, "RIGHT", -UIBossLoot.GUTTER, 0)
    button.fill = wash(button, "BACKGROUND", UIBossLoot.PANEL_SURFACE, 1)
    if button.fill then
      button.fill:SetAllPoints(button)
    end
    button.edges = insetBorder(button, UIBossLoot.PANEL_BORDER)
    button.label = newFontString(button, UIBossLoot.FONT_MD, "ITEMTREE_COLOR_TEXT_BODY", "CENTER")
    if button.label then
      button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
      setText(button.label, L["Creature page"])
    end
    -- Never Disable()d: a disabled button takes no hover in the client, and the tooltip saying
    -- why there is no page is the point. The click does nothing while it is painted disabled.
    attachScript(button, "OnClick", function(self)
      if self.pageEnabled then
        playCue("click")
        UIBossLoot.Activate("creature", UIBossLoot.CreatureKey(), "LeftButton")
      end
    end)
    attachScript(button, "OnEnter", function(self)
      if not self.pageEnabled then
        textTooltip(self, L["Creature page"], { UIBossLoot.NoPageReason() })
      end
    end)
    attachScript(button, "OnLeave", hideTooltip)
    header.button = button
  end
  header.title = newFontString(header, UIBossLoot.FONT_LG, "ITEMTREE_COLOR_TEXT_TITLE", "LEFT")
  if header.title then
    header.title:SetPoint("LEFT", header, "LEFT", UIBossLoot.GUTTER, 0)
    header.title:SetPoint("RIGHT", button or header, button and "LEFT" or "RIGHT", -UIBossLoot.GUTTER, 0)
  end
  -- Brief BL20: a boss shown by its creature's name gives the client's encounter name on hover.
  -- Motion only where the client has it, so a click on the header still reaches what is under it.
  local motion = type(header.SetMouseMotionEnabled) == "function" and pcall(header.SetMouseMotionEnabled, header, true)
  if not motion and type(header.EnableMouse) == "function" then
    pcall(header.EnableMouse, header, true)
  end
  attachScript(header, "OnEnter", function(self)
    local tip = UIBossLoot.BossTooltip(nil, rawget(self, "shownName"), rawget(self, "encounterName"))
    if tip then
      textTooltip(self, tip.title, tip.lines, tip.titleKey)
    end
  end)
  attachScript(header, "OnLeave", hideTooltip)
  header.edge = wash(header, "BORDER", UIBossLoot.BAND_EDGE)
  if header.edge then
    header.edge:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    header.edge:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    header.edge:SetHeight(UIBossLoot.EDGE_W)
  end
  return header
end

local function drawHeader(answer)
  local header = UIBossLoot.header
  if not header then
    return
  end
  local boss = type(answer) == "table" and answer.boss or nil
  setShown(header, boss ~= nil)
  if not boss then
    return
  end
  -- Brief BL20: the creature's name where it differs from the client's encounter name.
  local shown, encounter = UIBossLoot.BossNaming(boss.id, boss.name)
  header.shownName, header.encounterName = shown, encounter
  setText(header.title, shown or boss.name or "")
  paintCreatureButton(header.button, UIBossLoot.CreatureKey() ~= nil)
end

--------------------------------------------------------------------------------
-- The GC ticker
--------------------------------------------------------------------------------

local function collector()
  local fn = UIBossLoot.collect or rawget(_G, "collectgarbage")
  if type(fn) == "function" then
    return fn
  end
  return nil
end

local function heapKB()
  local fn = collector()
  if not fn then
    return nil
  end
  local ok, count = pcall(fn, "count")
  return ok and tonumber(count) or nil
end

--- Stops the running GC ticker, if any.
function UIBossLoot.StopGC()
  local ticker = UIBossLoot.gcTicker
  UIBossLoot.gcTicker = nil
  if type(ticker) == "table" and type(ticker.Cancel) == "function" then
    pcall(ticker.Cancel, ticker)
  end
  local driver = UIBossLoot.gcDriver
  if driver and type(driver.SetScript) == "function" then
    pcall(driver.SetScript, driver, "OnUpdate", nil)
  end
  UIBossLoot.gcRun = nil
end

--- After a release: where the heap grew by more than the model's threshold since the mark taken
--- when the tab was shown, a run of single steps at GC_INTERVAL. Answers whether one started.
function UIBossLoot.StartGC()
  UIBossLoot.StopGC()
  local BossLoot = ItemTree.BossLoot
  local mark = UIBossLoot.mark
  UIBossLoot.mark = nil
  if type(BossLoot) ~= "table" or type(BossLoot.GCPlan) ~= "function" then
    return false
  end
  if BossLoot.GCPlan(heapKB(), mark) ~= "step" then
    return false
  end
  local run = UIBossLoot.NewGCRun({ collect = collector(), inCombat = globalFn("InCombatLockdown") })
  UIBossLoot.gcRun = run
  local function tick()
    if UIBossLoot.gcRun ~= run then
      return
    end
    if not run:Tick() then
      UIBossLoot.StopGC()
    end
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.NewTicker) == "function" then
    local ok, ticker = pcall(timer.NewTicker, UIBossLoot.GC_INTERVAL, tick, UIBossLoot.GC_MAX_TICKS)
    if ok and ticker then
      UIBossLoot.gcTicker = ticker
      return true
    end
  end
  local driver = UIBossLoot.gcDriver or newFrame("Frame")
  if not driver or type(driver.SetScript) ~= "function" then
    UIBossLoot.gcRun = nil
    return false
  end
  UIBossLoot.gcDriver = driver
  local elapsed = 0
  driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (tonumber(delta) or 0)
    if elapsed >= UIBossLoot.GC_INTERVAL then
      elapsed = 0
      tick()
    end
  end)
  return true
end

--------------------------------------------------------------------------------
-- The pane
--------------------------------------------------------------------------------

local function captureOffsets()
  local offsets = UIBossLoot.state.offsets
  local lists = UIBossLoot.lists
  if lists.places then
    offsets.places = listOffset(lists.places)
  end
  if lists.bosses then
    offsets.bosses = listOffset(lists.bosses)
  end
  if lists.loot then
    offsets.loot = listOffset(lists.loot)
  end
end

--- Brief E97: the scroll offsets as the lists stand now, read into the session state while the
--- pane is up. Answers the state's offsets table.
function UIBossLoot.CaptureOffsets()
  if UIBossLoot.pane and UIBossLoot.lists and not UIBossLoot.released then
    captureOffsets()
  end
  return UIBossLoot.state.offsets
end

local function restoreOffsets()
  local offsets = UIBossLoot.state.offsets
  local lists = UIBossLoot.lists
  setListOffset(lists.places, offsets.places)
  setListOffset(lists.bosses, offsets.bosses)
  setListOffset(lists.loot, offsets.loot)
end

local function showNotice(text, line)
  local notice = UIBossLoot.notice
  if not notice then
    return
  end
  if text then
    setText(notice.title, text)
    setText(notice.line, line or "")
    notice:Show()
  else
    notice:Hide()
  end
  for _, column in ipairs({ UIBossLoot.placePanel, UIBossLoot.bossPanel, UIBossLoot.lootPanel }) do
    setShown(column, not text)
  end
end

local function lootAnswer(model, bossId)
  if not model or not bossId then
    return nil
  end
  local ok, answer = pcall(model.Loot, model, bossId)
  if ok and type(answer) == "table" then
    -- Brief GS5: the guesses naming this boss's creature, after its known loot.
    local entry = bossEntry(bossId, answer)
    local asked, guessRows = pcall(UIBossLoot.GuessRows, entry, answer.rows)
    if asked then
      return UIBossLoot.WithGuesses(answer, guessRows)
    end
    return answer
  end
  return nil
end

-- Brief BL23: each boss row's count and diamond from the answer its panel would draw
-- (UIBossLoot.LootSummary): the model's rows, held by place in its cache, and the Predicted rows.
-- Local data only, never an item query. A boss whose answer cannot be made keeps the index's count.
local function summariseBosses(model, bosses)
  for _, row in ipairs(bosses) do
    local ok, answer = pcall(lootAnswer, model, row.id)
    local count, newLoot = UIBossLoot.LootSummary(ok and answer or nil, row.isNew == true)
    if count then
      row.count = count
    end
    row.newLoot = newLoot == true
  end
end

--- Redraws the three columns from the model and the session state. The first draw after a
--- release puts the scroll offsets back where the player left them; every other draw keeps them.
function UIBossLoot.Draw()
  if not UIBossLoot.pane then
    return false
  end
  local model = UIBossLoot.Model()
  if not model then
    showNotice(L["Boss loot data is not available."])
    return false
  end
  -- Brief E97: a boss crumb has just put its offsets in the state, and they are the ones to draw.
  if not UIBossLoot.released and not UIBossLoot.restoring then
    captureOffsets()
  end
  UIBossLoot.restoring = nil
  for _, name in ipairs(UIBossLoot.pendingReset or EMPTY) do
    UIBossLoot.state.offsets[name] = 0
  end
  UIBossLoot.pendingReset = nil
  local places, err = model:Places()
  if #places == 0 then
    showNotice(L["Boss loot data is not available."], err)
    return false
  end
  showNotice(nil)
  local state = UIBossLoot.state
  drawList(UIBossLoot.lists.places, places)
  local bosses = state.place and model:Bosses(state.place) or EMPTY
  for _, row in ipairs(bosses) do
    row.kind = "boss"
  end
  summariseBosses(model, bosses)
  drawList(UIBossLoot.lists.bosses, bosses)
  local answer = lootAnswer(model, state.boss)
  drawHeader(answer)
  local sub = UIBossLoot.SUBPANES[UIBossLoot.subPane]
  if sub and type(sub.Show) == "function" then
    sub.Show(answer, state.place ~= nil and #bosses > 0)
  end
  restoreOffsets()
  UIBossLoot.released = false
  return true
end

--------------------------------------------------------------------------------
-- The keyboard (brief BL4)
--------------------------------------------------------------------------------

-- The pane takes the keyboard while it is shown and answers five keys (UIBossLoot.KEYS), and
-- only while the pointer is over it and the player is out of combat: UP and DOWN move within the
-- column that has the keyboard, LEFT and RIGHT move between the columns, ENTER opens. Every other
-- key, and these five anywhere else, go straight back to the game (SetPropagateKeyboardInput), so
-- a player who walks with the arrow keys keeps them. Propagation is put back to true on every key
-- release, and the keyboard is let go of when combat starts, so a key held as combat starts can
-- never leave the game's keys swallowed.

local function inCombat()
  local fn = globalFn("InCombatLockdown")
  if not fn then
    return false
  end
  local ok, answer = pcall(fn)
  return ok and answer == true
end

local function mouseOver(frame)
  if type(frame) ~= "table" or type(frame.IsMouseOver) ~= "function" then
    return false
  end
  local ok, over = pcall(frame.IsMouseOver, frame)
  return ok and over == true
end

local function propagate(frame, on)
  if type(frame) == "table" and type(frame.SetPropagateKeyboardInput) == "function" then
    pcall(frame.SetPropagateKeyboardInput, frame, on)
  end
end

--- Takes the keyboard (on) or lets it go. Taking it is never done in combat, and propagation is
--- set to true first, so the pane starts out handing every key back. Answers whether it has it.
function UIBossLoot.SetKeyboard(on)
  local pane = UIBossLoot.pane
  if type(pane) ~= "table" or type(pane.EnableKeyboard) ~= "function" then
    UIBossLoot.keyboard = false
    return false
  end
  on = on == true
  if on and inCombat() then
    on = false
  end
  if on then
    propagate(pane, true)
  end
  pcall(pane.EnableKeyboard, pane, on)
  UIBossLoot.keyboard = on
  return on
end

-- The rows of a column as they are drawn, or as the model gives them where nothing is drawn.
local function columnRows(column)
  local list = UIBossLoot.lists[column]
  if type(list) == "table" and type(list.rows) == "table" and #list.rows > 0 then
    return list.rows
  end
  local model = UIBossLoot.Model()
  local state = UIBossLoot.state
  if column == "places" then
    return model and (model:Places()) or EMPTY
  end
  if column == "bosses" then
    return (model and state.place) and (model:Bosses(state.place)) or EMPTY
  end
  return (UIBossLoot.LootRows(UIBossLoot.Loot.answer))
end

-- Where a column's cursor is: the chosen place, the chosen boss, or the loot cursor's item.
local function cursorIndex(column, rows)
  local state = UIBossLoot.state
  local want = state.place
  if column == "bosses" then
    want = state.boss
  elseif column == "loot" then
    want = state.cursor
  end
  if want == nil then
    return nil
  end
  for index, row in ipairs(rows) do
    if UIBossLoot.Selectable(column, row) and row.id == want then
      return index
    end
  end
  return nil
end

local function firstSelectable(column, rows)
  return UIBossLoot.StepIndex(rows, nil, 1, function(row)
    return UIBossLoot.Selectable(column, row)
  end)
end

-- Scrolls a column so its row at index is in view: the pool's window moves by as little as it
-- must, and a ScrollBox is asked to bring the element into view where it can.
local function reveal(column, index)
  local list = UIBossLoot.lists[column]
  if type(list) ~= "table" or not index then
    return
  end
  if list.mode == "scroll" then
    local box = list.box
    if box and type(box.ScrollToElementDataIndex) == "function" then
      pcall(box.ScrollToElementDataIndex, box, index)
    end
    return
  end
  local offset = list.offset or 0
  if index <= offset then
    offset = index - 1
  elseif index > offset + UIBossLoot.POOL_ROWS then
    offset = index - UIBossLoot.POOL_ROWS
  end
  if offset ~= list.offset then
    list.offset = offset
    drawPool(list)
  end
end

-- Paints the loot cursor on the frames drawn now, without drawing the list again.
local function paintCursor()
  local list = UIBossLoot.lists.loot
  if type(list) ~= "table" then
    return
  end
  local state = UIBossLoot.state
  for frame in pairs(list.frames) do
    local row = rawget(frame, "rowModel")
    local on = type(row) == "table" and row.kind == "item" and state.focus == "loot" and row.id == state.cursor
    paintSelected(frame, on == true)
  end
end

--- One key, acted on (UIBossLoot.KeyAction's table): a move selects the place or the boss the way
--- a click does, or moves the loot cursor; a focus change puts the loot cursor on the first item
--- when the loot column takes the keyboard; ENTER on an item opens its page. Answers the action,
--- or nil for a key the pane does not answer. Works on the model alone where nothing is drawn.
function UIBossLoot.HandleKey(key)
  local state = UIBossLoot.state
  local focus = state.focus or "places"
  local action, arg = UIBossLoot.KeyAction(key, focus)
  if action == "move" then
    local rows = columnRows(focus)
    local at = cursorIndex(focus, rows)
    local index = UIBossLoot.StepIndex(rows, at, arg, function(row)
      return UIBossLoot.Selectable(focus, row)
    end)
    if index and index ~= at then
      local row = rows[index]
      if focus == "places" then
        UIBossLoot.SelectPlace(row.id)
      elseif focus == "bosses" then
        UIBossLoot.SelectBoss(row.id, true)
      else
        state.cursor = row.id
        paintCursor()
      end
      reveal(focus, index)
    end
  elseif action == "focus" then
    local rows = columnRows(arg)
    local first = firstSelectable(arg, rows)
    if first then
      state.focus = arg
      if arg == "loot" and not cursorIndex("loot", rows) then
        state.cursor = rows[first].id
        reveal("loot", first)
      end
      paintCursor()
    else
      action = "none"
    end
  elseif action == "open" then
    if state.cursor then
      UIBossLoot.OpenItem(state.cursor)
    end
  end
  return action, arg
end

local function onKeyDown(self, key)
  -- In combat nothing is changed: propagation stands at true (it is put back on every release)
  -- and a protected call is never made.
  if inCombat() then
    return
  end
  local ours = UIBossLoot.KeyAction(key, UIBossLoot.state.focus) ~= nil and mouseOver(self)
  propagate(self, not ours)
  if ours then
    UIBossLoot.HandleKey(key)
  end
end

local function onKeyUp(self)
  if not inCombat() then
    propagate(self, true)
  end
end

-- The pane's key scripts, and a small watcher that lets the keyboard go when combat starts and
-- takes it back when combat ends while the pane is up.
local function attachKeyboard(region)
  attachScript(region, "OnKeyDown", onKeyDown)
  attachScript(region, "OnKeyUp", onKeyUp)
  local watcher = UIBossLoot.combatWatcher or newFrame("Frame")
  if watcher and type(watcher.RegisterEvent) == "function" and type(watcher.SetScript) == "function" then
    pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_DISABLED")
    pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then
        UIBossLoot.SetKeyboard(false)
      elseif UIBossLoot.pane and not UIBossLoot.released then
        UIBossLoot.SetKeyboard(true)
      end
    end)
  end
  UIBossLoot.combatWatcher = watcher
end

local function layoutColumns(width)
  local left, middle = UIBossLoot.ColumnWidths(width)
  if UIBossLoot.placePanel and type(UIBossLoot.placePanel.SetWidth) == "function" then
    UIBossLoot.placePanel:SetWidth(left)
  end
  if UIBossLoot.bossPanel and type(UIBossLoot.bossPanel.SetWidth) == "function" then
    UIBossLoot.bossPanel:SetWidth(middle)
  end
end

--- Builds the pane inside the region the window made. Idempotent, and false with no client.
function UIBossLoot.Attach(region)
  if type(region) ~= "table" then
    return false
  end
  if UIBossLoot.pane == region and UIBossLoot.lists.places then
    return true
  end
  if not globalFn("CreateFrame") then
    return false
  end
  UIBossLoot.pane = region
  UIBossLoot.lists = {}

  local left, middle = UIBossLoot.ColumnWidths(widthOf(region))
  local placePanel = panel(region)
  if not placePanel then
    UIBossLoot.pane = nil
    return false
  end
  placePanel:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
  placePanel:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
  placePanel:SetWidth(left)
  UIBossLoot.placePanel = placePanel
  newList("places", placePanel, PLACE_SPEC)

  local bossPanel = panel(region)
  if bossPanel then
    bossPanel:SetPoint("TOPLEFT", placePanel, "TOPRIGHT", UIBossLoot.GAP, 0)
    bossPanel:SetPoint("BOTTOMLEFT", placePanel, "BOTTOMRIGHT", UIBossLoot.GAP, 0)
    bossPanel:SetWidth(middle)
    newList("bosses", bossPanel, BOSS_SPEC)
  end
  UIBossLoot.bossPanel = bossPanel

  -- The right column: the header line on top, then the sub region a sub pane is drawn in.
  local lootPanel = panel(region)
  if lootPanel then
    lootPanel:SetPoint("TOPLEFT", bossPanel or placePanel, "TOPRIGHT", UIBossLoot.GAP, 0)
    lootPanel:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    local header = buildHeader(lootPanel)
    if header then
      header:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", UIBossLoot.EDGE_W, -UIBossLoot.EDGE_W)
      header:SetPoint("TOPRIGHT", lootPanel, "TOPRIGHT", -UIBossLoot.EDGE_W, -UIBossLoot.EDGE_W)
      header:Hide()
    end
    UIBossLoot.header = header
    local subRegion = newFrame("Frame", lootPanel)
    if subRegion then
      subRegion:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", UIBossLoot.EDGE_W, -(UIBossLoot.EDGE_W + UIBossLoot.HEADER_H))
      subRegion:SetPoint("BOTTOMRIGHT", lootPanel, "BOTTOMRIGHT", -UIBossLoot.EDGE_W, UIBossLoot.EDGE_W)
      UIBossLoot.subRegion = subRegion
      for _, name in ipairs(UIBossLoot.SUBPANE_ORDER) do
        local sub = UIBossLoot.SUBPANES[name]
        if sub and type(sub.Attach) == "function" then
          sub.Attach(subRegion)
        end
      end
      if Loot.list then
        UIBossLoot.lists.loot = Loot.list
      end
    end
  end
  UIBossLoot.lootPanel = lootPanel

  local notice = newFrame("Frame", region)
  if notice then
    notice:SetAllPoints(region)
    notice.title = wrapText(newFontString(notice, UIBossLoot.FONT_LG, "ITEMTREE_COLOR_TEXT_TITLE", "CENTER"))
    notice.line = wrapText(newFontString(notice, UIBossLoot.FONT_MD, "ITEMTREE_COLOR_TEXT_MUTED", "CENTER"))
    if notice.title then
      notice.title:SetWidth(UIBossLoot.EMPTY_W)
      notice.title:SetPoint("BOTTOM", notice, "CENTER", 0, 0)
    end
    if notice.line then
      notice.line:SetWidth(UIBossLoot.EMPTY_W)
      notice.line:SetPoint("TOP", notice, "CENTER", 0, -UIBossLoot.GAP)
    end
    notice:Hide()
  end
  UIBossLoot.notice = notice

  attachScript(region, "OnSizeChanged", function(self)
    layoutColumns(widthOf(self))
  end)
  attachKeyboard(region)
  -- Another tab, or the window closing: the decoded rows go.
  attachScript(region, "OnHide", function()
    UIBossLoot.Release()
  end)
  return true
end

--- Lets go of everything the tab decoded and drew, keeping the session state, then starts the GC
--- ticker where the heap grew enough. Answers whether anything was released.
function UIBossLoot.Release()
  hideTooltip()
  UIBossLoot.SetKeyboard(false)
  if UIBossLoot.released then
    return false
  end
  captureOffsets()
  local model = UIBossLoot.model
  if model and type(model.Release) == "function" then
    pcall(model.Release, model)
  end
  for name, list in pairs(UIBossLoot.lists) do
    if name ~= "loot" then
      clearList(list)
    end
  end
  for _, sub in pairs(UIBossLoot.SUBPANES) do
    if type(sub.Release) == "function" then
      sub.Release()
    end
  end
  UIBossLoot.released = true
  UIBossLoot.StartGC()
  return true
end

--- Shows the pane and redraws it. The root key the window hands over is ignored.
function UIBossLoot.Show()
  if not UIBossLoot.pane then
    return false
  end
  UIBossLoot.StopGC()
  if UIBossLoot.mark == nil then
    UIBossLoot.mark = heapKB()
  end
  UIBossLoot.pane:Show()
  local drawn = UIBossLoot.Draw()
  UIBossLoot.SetKeyboard(true)
  return drawn
end

function UIBossLoot.Refresh()
  if not UIBossLoot.pane then
    return false
  end
  return UIBossLoot.Draw()
end

function UIBossLoot.Hide()
  UIBossLoot.Release()
  if not UIBossLoot.pane then
    return false
  end
  UIBossLoot.pane:Hide()
  return true
end

function UIBossLoot.Init() end

-- The tab is registered as the file loads, which is before the window is built. The settings
-- panel's module loads after this file, so the setting is registered again at ADDON_LOADED. Its
-- default is not written into the saved settings: the window reads an unset tab setting as the
-- default registered here (Frame.TabSettingOn, brief BL4), and ADDON_LOADED is before the window
-- is built.
UIBossLoot.Register()

local events = newFrame("Frame")
if events and type(events.RegisterEvent) == "function" and type(events.SetScript) == "function" then
  pcall(events.RegisterEvent, events, "ADDON_LOADED")
  pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
  events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "ItemTree" then
      return
    end
    UIBossLoot.Register()
    if event == "PLAYER_LOGIN" and type(self.UnregisterAllEvents) == "function" then
      pcall(self.UnregisterAllEvents, self)
    end
  end)
end
UIBossLoot.events = events

return UIBossLoot
