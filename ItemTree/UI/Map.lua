-- The Map tab of a creature page: the zone's own art out of the running client, with the
-- creature's shipped map pins on it (brief E59). Since brief D7 the same tab on the page of a herb,
-- a vein, a fishing pool or a chest, with that object's pins (Map.ObjectSubject). Since brief Z1 the
-- same tab on a ZONE's own page, with the pins of the one source the player picked on its Here tab
-- (Map.ZoneSubject), and the zone named over a creature's or a node's map opens that zone's page.
--
-- UI/Tree.lua owns the tab and the rectangle it is drawn in, and exposes one seam,
-- Tree.MapPainter(region, nameIndex, zones). This file is the painter that replaces the default,
-- and Tree.MapCleaner beside it is how the pane takes down what the painter left. Nothing else
-- in the pane, in the window or in Core knows this file exists.
--
-- Everything above the divider is pure and runs under busted with no WoW API:
--   Map.Grid(layer)                 one art layer as a tile grid, or nil
--   Map.TileIndex(grid, row, col)   which texture of the layer's list belongs at a cell
--   Map.Fit(grid, w, h)             how big that layer is drawn inside a box, at its own shape
--   Map.TileRects(grid, fit)        every tile's rect and crop inside the drawn map
--   Map.OverlayRects(info, grid, fit) one explored overlay's tiles as rects (brief MX1)
--   Map.ExploredRects(list, grid, fit) every overlay's tiles, mouseover highlights left out
--   Map.OverlayFromData(row)        one shipped MapOverlays row in the client's own shape
--   Map.PinOffset(x, y, w, h)       where one percentage pair sits inside the drawn map
--   Map.PinSize(width)              how big a pin is drawn on a map that wide
--   Map.Merge(zones, pins)          the zone list the tab draws, and which one opens first
--   Map.TextWidth(text, size)       roughly how wide a label is where nothing can measure one
--   Map.ButtonWidth(textWidth)      how wide one zone button is for a label that wide
--   Map.ZoneControl(widths, room)   "none", "buttons" or "menu": what the zone strip is
--   Map.ZoneText(zone)              the words one zone wears in the strip
--   Map.ZoneLabel(zone)             "Elwynn Forest (6)", what the dropdown reads
--   Map.MenuEntries(list, selected) the rows the dropdown's list draws
--   Map.MenuWidth(widths, ...)      how wide that list is
--   Map.MaxOffset(count, rows)      how far a list of that many can be scrolled
--   Map.MenuStart(current, ...)     where the list starts so the open zone is on screen
--   Map.PinText(pin)                "26.3, 93.1"
--   Map.CaptionLines(zone)          the words over the map
--   Map.NoteLines()                 the two words under it, the Predicted wording and its line
--   Map.ZoneNoteLines(facts)        a zone's own lines under it: none for a zone new in Forever
--   Map.TextLines(list, cap)        what the tab says when there is no art to draw
--   Map.TipLines(name, zone, pin)   the three lines a hovered pin puts in the tooltip
--   Map.ZonePlace(facts, pick, pins) the one place a zone's own Map tab draws (brief Z1)
--   Map.ZoneLinkText(name)           "Click to open Feralas", the hover on a zone name that is a link
--   Map.ZonePinLines(source, pin, low, high) what a pin of a zone's item pick says (brief Z2)
--   Map.ZoneItemCaption(entry, places, more) "Truesilver Ore: Truesilver Deposit, 6 places"
--   Map.ZoneItemPlace(facts, entry, decoded) the place a zone's item pick draws, its pins capped
--   Map.PlacedPin(source)            the one spot a placed object source stands at (brief M15)
--   Map.QuestPlaces(facts)           a quest's recorded giver, turn in and objective as places (brief Q8)
--   Map.QuestNoteLines(facts)        whose positions those pins are
--   Map.QuestEmptyLines()            what a quest's map says with nothing to place
--   Map.PositionPercent(position)    a client position (0 to 1) as percentages (brief M7)
--   Map.MatchEntrance(list, names)   the client's entrance of one instance, by name
--   Map.EntrancePlaces(entrance, at) the entrance zone's map and its one Entrance pin
--   Map.WaypointAt(uiMapId, pin)     the point a left click on a pin sets the waypoint at
--   Map.WaypointFor(pin, creature)   what that waypoint is for, the words its toast says (brief UX1)
--   Map.PathThickness(width)         how thick a patrol path is drawn on a map that wide (brief M11)
--   Map.PathSegments(points, w, h)   the line pieces one patrol path is drawn with
--   Map.PathExtent(points)           the box one patrol path covers, in map percent (brief M13)
--   Map.IsSmallPath(extent)          whether that box is small enough to need a pin to be found
--   Map.PathPins(paths, pins, name, zone) the "Patrol path" pins a place's small paths get
--   Map.WorldBossNotes(boss, places) the lines under a world boss's map, "one of these" where it is
--   Map.PlayerSize(width)            how big the player's arrow is on a map that wide (brief MP1)
--   Map.PlayerDotSize(width)         how big the dot is that stands in for it with no facing
--   Map.PlayerSpot(x, y)             the client's place for the player (0 to 1), or nil off the map
--   Map.RectSpot(rect, x, y)         a place on a child map as a place on its parent
--   Map.PlayerFace(facing)           the arrow turned to the facing, or the unturned dot
--   Map.PlayerOffset(x, y, w, h)     where the marker's centre sits inside the drawn map
--   Map.ZoomCeiling(scale)           the highest zoom a map drawn at that scale takes (brief UX2)
--   Map.ClampZoom(zoom, ceiling)     a zoom held between 1x and that ceiling
--   Map.IsDrag(dx, dy)               whether a press that moved that far is a drag rather than a click
--   Map.InView(x, y, zoom, ...)      whether a pin is inside the visible part of a zoomed map
--   Map.ZoomKey(root, zone)          what one zoom belongs to: the page and the zone it draws
--
-- The tile arithmetic is Blizzard's own, read off MapCanvasDetailLayerMixin:RefreshDetailTiles in
-- Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvasDetailLayer.lua on the `forever` branch of
-- the Gethe/wow-ui-source mirror: the grid is math.ceil(layerWidth / tileWidth) by
-- math.ceil(layerHeight / tileHeight) and the texture list is read across the top row first,
-- textureIndex = (tileRow - 1) * numDetailTilesCols + tileCol. Blizzard's tiles are all one size
-- and the last column and row hang over the layer, which its canvas clips; this file crops those
-- two edges with SetTexCoord instead, which lands on exactly the same rectangle and needs no
-- clipping frame. The box is scaled by the smaller of the two ratios, which is what
-- MapCanvasScrollControllerMixin:CreateZoomLevels does with baseScale in the same add-on. Every
-- call is declared in Blizzard_APIDocumentationGenerated/MapDocumentation.lua on the same branch
-- (C_Map.GetMapArtLayers returns UiMapLayerInfo: layerWidth, layerHeight, tileWidth, tileHeight;
-- C_Map.GetMapArtLayerTextures returns a list of file ids), and this file still looks each one up
-- at run time rather than trusting the documentation.
--
-- NOT YET PROVEN: whether the Forever beta really hands the art back. So the whole of it degrades.
-- A C_Map call this client does not carry, a call that raises, a layer that cannot be laid out and
-- an empty tile list all do the same thing: the tab falls back to Tree.DrawMapZones with the pins
-- written out as plain text ("Elwynn Forest 26.3, 93.1"), and nothing asks the client again for
-- the rest of the session.
--
-- Nothing here queries an item or stores anything. The player's own position is read only while
-- a map is on screen, to draw where they stand on it (brief MP1), and is never kept or printed.
-- The pins are the shipped Classic Era table's own (Core/EraSources.lua E:PinsOf), decoded only
-- because the player opened this tab. Since brief M3 a vendor's page adds one pin of its own: the
-- place the curated tier ships for a Merchant's Favor vendor, or where the player stood when they
-- last opened its window, which the collector recorded then (Map.VendorPositions). Since brief Q8
-- a quest's page has the tab too: where the player stood when the quest was given and handed in,
-- and the client's objective mark while it is in the log (Map.QuestSubject, Map.DrawQuest).
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Map = {}
ItemTree.UI.Map = Map

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}
local SIZES = Theme.sizes
local FONTS = Theme.fontSizes

--------------------------------------------------------------------------------
-- What it is made of
--------------------------------------------------------------------------------

--- The pin. One key, one texture, and UI/Assets.lua owns the path.
Map.PIN_KEY = "MAP_PIN"

--- The plain block a client that will not draw the pin file gets instead: the New colour as it
--- is, every channel, so the block wears the badge's silver blue (brief E80). Pure.
Map.PIN_FALLBACK_COLOUR = "ITEMTREE_COLOR_SEMANTIC_NEW"

function Map.PinFallbackColour()
  local colour = Theme.ColorTable(Map.PIN_FALLBACK_COLOUR)
  if type(colour) ~= "table" then
    return 1, 1, 1, 1
  end
  return colour.r, colour.g, colour.b, 1
end

--- How big a pin is drawn. The pipeline reduces a creature's spawns to at most six points on a
--- grid of FIVE percent of the zone's map, so two pins on one map are at least a twentieth of its
--- width apart: 25 pixels on a 500 pixel map. A 14 pixel pin therefore leaves eleven pixels of air
--- between two neighbours and six of them in one corner still read as six. The size follows the
--- map rather than being fixed, so a window dragged small keeps the same picture, and it is
--- clamped at both ends because a pin below ten pixels is a smudge and one above eighteen covers
--- the ground it is pointing at.
Map.PIN_BASIS = 500
Map.PIN_AT_BASIS = 14
Map.PIN_MIN = 10
Map.PIN_MAX = 18

--- At most six pins per creature per zone reach the table, so the pool never needs a seventh.
Map.PIN_CAP = 6

--- A classic zone is twelve tiles (a 1002 by 668 layer in 256 pixel tiles is four columns by
--- three rows). The cap is there so a layer this addon has never seen cannot ask for hundreds of
--- textures; a grid past it is drawn as far as the cap and no further.
Map.TILE_CAP = 48

--- How many zones' art descriptions are kept. A player walks between the zones of one creature,
--- so a handful covers the need and the answers are two small tables each.
Map.ART_CACHE = 8

--- The air around the block, and the zone buttons above the map.
Map.PAD = SIZES.ITEMTREE_SPACE_3
Map.GAP = SIZES.ITEMTREE_SPACE_2
Map.LINE_GAP = SIZES.ITEMTREE_SPACE_1
Map.BUTTON_H = SIZES.ITEMTREE_CONTROL_H_SM
Map.BUTTON_GAP = SIZES.ITEMTREE_SPACE_1
Map.BUTTON_PAD = SIZES.ITEMTREE_SPACE_2
Map.BUTTON_CHAR = 0.6
Map.FONT_SM = FONTS.ITEMTREE_FONTSIZE_BODY_SM

--- How many zones still read as a row of buttons (brief E62). The owner's ruling, on the shipped
--- pins: of 2,596 creature names 2,253 are in one zone, 311 in two, 23 in three, 5 in four, 1 in
--- five, and three are in more (Cow in seven, Deer and Rabbit in thirteen). So the row is what
--- every creature but a handful draws, and past five the strip becomes ONE dropdown rather than
--- three rows of buttons stacked over the map.
Map.ZONE_MAX = 5

--- The dropdown's list. Ten rows at once and the wheel through the rest, which is the cap and the
--- wheel UI/Chain.lua's own lists use, so a player who has used one list has used them all. A
--- deeper list would hang past the bottom of a short window, where every row past the edge is one
--- nothing can click.
Map.MENU_ROW_H = SIZES.ITEMTREE_LIST_ROW_H
Map.MENU_MAX_ROWS = 10
Map.MENU_MIN_W = 150
Map.MENU_MAX_W = 260
Map.MENU_SCROLLER_W = 4
--- The chevron on the dropdown and the tick beside the zone that is open.
Map.MENU_ACTION = SIZES.ITEMTREE_ICON_CATEGORY
--- The room a pin count takes on the right of a row.
Map.MENU_RIGHT_W = 34
Map.CHEVRON_KEY = "ICON_CHEVRON_COLLAPSE"
Map.TICK_KEY = "ICON_CHECK"

--- The list sits strictly above the catcher: the catcher is a screen wide mouse trap and a press
--- that lands on it closes the list, which is exactly the press that was meant for a row. Both
--- names and the step of 500 are UI/Chain.lua's, which read them off the client's own menus
--- (Blizzard_Menu/Menu.lua, MenuManagerMixin:OpenMenu, on the `forever` branch).
Map.CATCHER_STRATA = "FULLSCREEN"
Map.MENU_STRATA = "FULLSCREEN_DIALOG"
Map.MENU_LEVEL_STEP = 500

--- What a rectangle is taken to be where the client will not measure it. The same shape the map
--- probe draws in, so a spec and a client that answers nothing both get a layout rather than a
--- divide by zero.
Map.BOX_W = 500
Map.BOX_H = 333

--- How many lines of places and pins the text fallback lists before it counts the rest out.
Map.TEXT_CAP = 12

--- The wordings. Each is the English and its own locale key.
Map.NOTE = "Positions from Classic Era. WoW Forever may have changed this."
Map.NO_POSITION = "No position is known in this zone"
Map.INSIDE = "Inside %s"
Map.NO_INSIDE_MAP = "There is no map of the inside of a place."
-- Brief M7: an instance's own page draws the zone that holds its entrance, with one Entrance pin,
-- in place of the words above. The header names both: "Wailing Caverns entrance, The Barrens".
Map.ENTRANCE = "Entrance"
Map.ENTRANCE_HEADING = "%s entrance, %s"
Map.ENTRANCE_NEAR = "Near %s"
Map.ENTRANCE_CLIENT = "The entrance as the game's own world map places it."
Map.ENTRANCE_UNKNOWN = "Where the entrance is in this zone is not known yet."
-- Brief M8: the line under the map wherever the instance portal pin is drawn, which the data ships
-- from the game's own tables. A shipped mouth is hand kept, so it gets no line of its own.
Map.PORTAL_NOTE = "The instance portal is placed from the game's own map data."
-- Brief M8 (owner addition, 2026-09-30): the data may ship both the outdoor mouth and the instance
-- portal; the mouth is the Entrance pin and the portal wears a portal icon under this label.
Map.ENTRANCE_PORTAL = "Instance portal"
Map.PORTAL_KEY = "MAP_PIN_PORTAL"
-- Brief M8 (owner addition, 2026-09-30): a world boss's own Map tab labels its Classic Era pins as
-- spawn points and heads the map "Azuregos spawn point, Azshara", or says it has none.
Map.SPAWN = "Spawn point"
Map.SPAWN_HEADING = "%s spawn point, %s"
Map.SPAWNS_HEADING = "%s spawn points, %s"
Map.SPAWN_UNKNOWN = "Where this boss spawns is not known yet."
-- Brief M11: a zone a world boss only walks through, with no spawn point in it, is headed with its
-- patrol; a boss whose places are shared, or which stands at one of several spots, says so under
-- the map. A zone with a path and no pin says "patrol path" where another says it has no position.
Map.PATROL_HEADING = "%s patrol, %s"
Map.ONE_OF_THESE = "%s appears at one of these places."
Map.PATROL_WORD = "patrol path"
Map.PATROL_FROM = "Patrol path from %s"
-- Brief M7, 2026-09-30: the inside map is a second entry in the zone strip beside the entrance,
-- held back until the dungeon map work (branch feature/dungeon-map) has a map to draw there. It
-- turns this on; until then the strip is never drawn for an instance.
Map.SHOW_INSIDE_MAPS = false
-- Brief M7: the line a pin's tooltip closes on where a left click sets the client's waypoint there.
Map.WAYPOINT_HINT = "Left click: set a waypoint"
-- Brief Z1: what a zone's own map says while no source is picked, and the line a zone name that
-- opens the zone's page says on hover.
Map.ZONE_HINT = "Click a source's name on the Here tab to pin it on this map."
Map.ZONE_LINK = "Click to open %s"
-- Brief Z2: the caption under a zone's map naming the item picked in its item column, and the
-- words it counts the places in.
Map.ZONE_CAPTION = "%s: %s, %s"
Map.ZONE_CAPTION_BARE = "%s: %s"
Map.ONE_PLACE = "1 place"
Map.PLACES = "%d places"
Map.PLACES_MORE = "%d places and %d more"
Map.NO_PLACES = "no places known"
-- Brief Q9b: what a zone of a node's Map view says in place of a pin count of 0, and the caption
-- under a zone's map for a fish caught in open water (a whole fishing zone, which names no pool).
Map.NO_POSITIONS = "no positions known"
-- Brief TR1c: the muted line under a map whose pins include a claim's approximate position.
Map.APPROXIMATE = "Approximate position"
-- Brief NW1 (owner ruling B of 2026-10-19, QA item 283): a creature found at one of several hand kept
-- spots (Core/Creatures.lua SpotPositions: the Night Watch Guard has nine in Duskwood) draws every
-- spot, past the six pins a Classic Era name ships per zone. The most one zone of such a map draws.
Map.SPOT_CAP = 16
-- The owner's standing rule of 2026-10-20: a spot one unverified report alone names (Core/Creatures.lua,
-- the data's sw) is a weak indicator, its pin drawn at this alpha with the tooltip line "Weak indicator".
Map.WEAK_ALPHA = 0.45
-- Brief CS1 (the owner's ruling A of 2026-10-20, QA item 304): a Confirmed spot, one a player's
-- recorded find backs (Core/Creatures.lua, the data's sc, or the player's own record), is drawn at full
-- brightness and marked on the pin itself.
-- Brief CS2 (QA item 309, the owner: "I don't like the gold ring at all ... an additional green border
-- around the shape of the pin (few pixels green border?)"): the mark is a green outline that follows the
-- pin's own diamond, in place of CS1's gold ring. The plain white fill tinted the Verified badge's green
-- (UI/Badges.lua verified: ITEMTREE_COLOR_QUALITY_UNCOMMON), a square turned a quarter of a right angle
-- into a diamond (SetRotation, as the instance marker's pointer, brief M10), centred on the pin under
-- its art and Map.OutlineRect wider than the pin's own diamond, so only a band a few pixels wide shows
-- round the pin's dark edge. Its width follows the pin's size, which follows the map, so the band reads
-- alike at every map size. No new texture file.
Map.OUTLINE_KEY = "FILL_WHITE8X8"
Map.OUTLINE_COLOUR = "ITEMTREE_COLOR_QUALITY_UNCOMMON"
Map.OUTLINE_LAYER = "BORDER"
-- The pin art's own diamond, corner to corner, against the pin's side: MAP_PIN's 30 by 30 crop of
-- Interface\Waypoint\WaypoinMapPinUI (fileDataID 3500068) is opaque from its 5th to its 26th pixel
-- both ways, 22 of 30, centred in the crop (read off the file in the public wow-ui-textures mirror).
Map.PIN_DIAMOND = 22 / 30
-- The band: OUTLINE_SHARE of the pin's side in whole pixels, never under OUTLINE_MIN (2 pixels on the
-- smallest pin and the 14 pixel one a 500 pixel map draws, 3 on the largest).
Map.OUTLINE_SHARE = 0.15
Map.OUTLINE_MIN = 2
-- Brief MP1 of 2026-10-20 (QA item 321, the owner: "Confirmed pins should appear above unconfirmed (if
-- they are all confirmed then it doesnt matter)"): where pins overlap, the surer spot draws on top. Each
-- pin is put this many levels over the canvas it stands on (a new child frame starts one over its
-- parent): a weak spot lowest, every other pin next, a Confirmed spot over both, its green outline with
-- it (a texture on the same frame). All stay under the player's marker (Map.PLAYER_LEVEL_STEP). Frame
-- level is how the client's own world map orders its pins (MapCanvasPinMixin:ApplyFrameLevel calls
-- SetFrameLevel, Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua:565-567, wow-ui-source forever
-- 1.60.1.70245).
Map.PIN_LEVEL_WEAK = 1
Map.PIN_LEVEL = 2
Map.PIN_LEVEL_CONFIRMED = 3
Map.OPEN_WATER = "Open water, anywhere in the zone"

--- Brief Z2: the most pins a zone's item pick draws. The table ships at most six per source per
--- zone, so a single node never meets it; an item off many creatures can, and the caption counts
--- out the rest.
Map.ZONE_PIN_CAP = 80

--- Brief M11: a patrol path is a chain of thin lines between its points, in the pin's own colour
--- at reduced alpha, under the pins, with a small dot at its first point. The thickness follows the
--- map the way a pin's size does, clamped at both ends. The data ships at most 32 points a path; the
--- caps only keep a path this addon has never seen from asking for hundreds of pieces.
Map.PATH_COLOUR = Map.PIN_FALLBACK_COLOUR
Map.PATH_ALPHA = 0.9
Map.PATH_AT_BASIS = 2
Map.PATH_MIN = 2
Map.PATH_MAX = 3
Map.PATH_DOT = 3
Map.PATH_POINT_CAP = 32
Map.PATH_CAP = 4
Map.PATH_FILL_KEY = "FILL_WHITE8X8"

--- Brief M13: a path whose box is under this many percent of the map on BOTH axes is a fleck at
--- map scale (Maws' swim in the Bay of Storms), so it gets a plain pin at the box's centre, labelled
--- and hovered with its point count, unless a pin already stands inside the box.
Map.SMALL_PATH_PERCENT = 6
Map.PATH_PIN = "Patrol path"
Map.PATH_PIN_POINTS = "Patrol path, %d points"

--- Brief MP1: the player's own place on the map, the way the client's world map shows it: its
--- player arrow (UI/Assets.lua MAP_PLAYER_ARROW) turned to the player's facing, or its unit dot
--- (MAP_PLAYER_DOT, tinted gold) where the client gives no facing. Drawn over the pins, takes no
--- mouse and raises no tooltip.
Map.PLAYER_ARROW_KEY = "MAP_PLAYER_ARROW"
Map.PLAYER_DOT_KEY = "MAP_PLAYER_DOT"
Map.PLAYER_DOT_COLOUR = "ITEMTREE_COLOR_TEXT_TITLE"
--- The world map's own sizes, read on the `forever` branch of the Gethe/wow-ui-source mirror: the
--- player pin is 27 (GroupMembersDataProviderMixin:GetUnitPinSizesTable,
--- Blizzard_SharedMapDataProviders/GroupMembersDataProvider.lua) on a canvas 697 wide (the
--- minimised world map is 702 wide, WorldMapMixin:SetupMinimizeMaximizeButton in
--- Blizzard_WorldMap/Blizzard_WorldMap.lua, and its canvas is inset 2 on the left and 3 on the
--- right). So the arrow is the same share of our map's width, which is 19 pixels on a 500 pixel
--- map, clamped at both ends like a pin.
Map.PLAYER_WORLD_SIZE = 27
Map.PLAYER_WORLD_CANVAS = 697
Map.PLAYER_MIN = 12
Map.PLAYER_MAX = 32
--- The dot against the arrow's size, and never under PLAYER_DOT_MIN pixels.
Map.PLAYER_DOT_SHARE = 0.6
Map.PLAYER_DOT_MIN = 8
--- How often the place is read while a map is on screen, in seconds: ten times a second.
Map.PLAYER_TICK = 0.1
--- How far over the canvas the marker's layer sits: a pin is one level over the canvas, so this
--- keeps the marker above every pin.
Map.PLAYER_LEVEL_STEP = 10
--- How many parents up the client's map tree the shown map may be from the player's own map.
Map.PLAYER_PARENT_STEPS = 6

--- Brief UX2 (QA item 404, the owner: "Zoom + pan feature on map (right now the only way to scale up is
--- to scale up window)"): the wheel over the map zooms about the pointer, a drag pans, and the chain
--- tab's own zoom bar (UI/Chain.lua Chain.ZoomBar: Reset, + and - with the readout, as the Professions
--- tab lays them out) sits in the map's top right corner. 1x is the map fitted to the panel, as it was
--- drawn before; the ceiling is ZOOM_MAX, and lower where a bigger zoom would draw one pixel of the
--- art across more than ZOOM_TEXEL of ours (a blur, not detail). One step is the chain tab's.
Map.ZOOM_STEP = 1.25
Map.ZOOM_MAX = 4
Map.ZOOM_TEXEL = 2
--- How far, in the window's own units, a press must travel before it is a drag: a press on a pin that
--- moves less is still a click and sets its waypoint; one that moves further pans and never does.
Map.DRAG_THRESHOLD = 4
--- The Reset button's width, the Professions tab's own (Pane.RESET_W).
Map.ZOOM_RESET_W = 44

--- Colours, all Theme tokens.
Map.COLOR_TITLE = "ITEMTREE_COLOR_TEXT_TITLE"
Map.COLOR_BODY = "ITEMTREE_COLOR_TEXT_BODY"
Map.COLOR_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
Map.COLOR_BUTTON = "ITEMTREE_COLOR_BUTTON_FACE"
Map.COLOR_BUTTON_HOVER = "ITEMTREE_COLOR_BUTTON_FACE_HOVER"
Map.COLOR_BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
Map.COLOR_BORDER_ON = "ITEMTREE_COLOR_BORDER_GOLD"
Map.COLOR_MENU = "ITEMTREE_COLOR_SURFACE_STICKY"
Map.COLOR_HOVER = "ITEMTREE_COLOR_STATE_HOVER"
Map.COLOR_TRACK = "ITEMTREE_COLOR_BORDER_DIVIDER"

--------------------------------------------------------------------------------
-- Pure. The arithmetic of laying a zone's art out in a box and putting pins on it
--------------------------------------------------------------------------------

--- The tile grid of one art layer, computed the way Blizzard's own detail layer computes it: the
--- ceiling of the layer size over the tile size in each direction. nil where the client described
--- a layer that cannot be laid out, which is a fact worth falling back on rather than guessing
--- past.
function Map.Grid(layer)
  local row = type(layer) == "table" and layer or EMPTY
  local width = tonumber(row.layerWidth) or 0
  local height = tonumber(row.layerHeight) or 0
  local tileWidth = tonumber(row.tileWidth) or 0
  local tileHeight = tonumber(row.tileHeight) or 0
  if width <= 0 or height <= 0 or tileWidth <= 0 or tileHeight <= 0 then
    return nil
  end
  return {
    width = width,
    height = height,
    tileWidth = tileWidth,
    tileHeight = tileHeight,
    cols = math.ceil(width / tileWidth),
    rows = math.ceil(height / tileHeight),
  }
end

--- Which texture of the layer's list belongs at a row and column. Blizzard's own order, from the
--- same function: textureIndex = (tileRow - 1) * numDetailTilesCols + tileCol, so the list is read
--- across the top row first. Getting this backwards is how a map comes out transposed.
function Map.TileIndex(grid, row, col)
  local cols = type(grid) == "table" and tonumber(grid.cols) or nil
  if not cols or cols < 1 then
    return nil
  end
  local wantedRow, wantedCol = tonumber(row), tonumber(col)
  if not wantedRow or not wantedCol or wantedRow < 1 or wantedCol < 1 or wantedCol > cols then
    return nil
  end
  return (wantedRow - 1) * cols + wantedCol
end

--- How big the layer is drawn inside a box: the smaller of the two ratios, so the art keeps its
--- own shape and nothing is stretched. A classic zone is three to two, so a box wider than that
--- leaves air down each side and the map is centred in it.
function Map.Fit(grid, boxWidth, boxHeight)
  if type(grid) ~= "table" then
    return nil
  end
  local width = tonumber(grid.width) or 0
  local height = tonumber(grid.height) or 0
  local box = tonumber(boxWidth) or 0
  local tall = tonumber(boxHeight) or 0
  if width <= 0 or height <= 0 or box <= 0 or tall <= 0 then
    return nil
  end
  local scale = math.min(box / width, tall / height)
  return { scale = scale, width = width * scale, height = height * scale }
end

--- Every tile of the grid as a rect inside the drawn map, in the order the textures are read.
---
---   index          the texture of the layer's list this tile draws
---   x, y           the tile's top left, in pixels from the map's own top left, y DOWNWARDS
---   width, height  how big it is drawn
---   left, right, top, bottom   the crop, which is the whole file but on the last column and the
---                              last row, where Blizzard's own tiles hang over the layer and its
---                              canvas clips them
---
--- An empty list where the grid or the fit is not something this can lay out, so a caller draws
--- nothing rather than half a map.
function Map.TileRects(grid, fit)
  if type(grid) ~= "table" or type(fit) ~= "table" then
    return EMPTY
  end
  local scale = tonumber(fit.scale) or 0
  if scale <= 0 then
    return EMPTY
  end
  local out = {}
  for row = 1, grid.rows do
    local top = (row - 1) * grid.tileHeight
    local high = math.min(grid.tileHeight, grid.height - top)
    for col = 1, grid.cols do
      local left = (col - 1) * grid.tileWidth
      local wide = math.min(grid.tileWidth, grid.width - left)
      local index = Map.TileIndex(grid, row, col)
      if index and index <= Map.TILE_CAP and wide > 0 and high > 0 then
        out[#out + 1] = {
          index = index,
          x = left * scale,
          y = top * scale,
          width = wide * scale,
          height = high * scale,
          left = 0,
          right = wide / grid.tileWidth,
          top = 0,
          bottom = high / grid.tileHeight,
        }
      end
    end
  end
  return out
end

--- Brief MX1 (2026-10-02): the explored areas the client's own map draws over the base art. The
--- arithmetic is Blizzard's, read off MapExplorationPinMixin:RefreshOverlays in
--- Interface/AddOns/Blizzard_SharedMapDataProviders/MapExplorationDataProvider.lua on the `forever`
--- branch of the Gethe/wow-ui-source mirror. Each overlay is a textureWidth by textureHeight
--- picture at offsetX, offsetY in the layer's own pixels, cut into tiles the size of the LAYER's
--- tiles: math.ceil(textureWidth / tileWidth) across by math.ceil(textureHeight / tileHeight) down,
--- its file ids read across the top row first. Every tile is a whole tile but the last column and
--- row, which are textureWidth % tileWidth (a whole tile where that is 0) and are cropped out of a
--- file the next power of two up from 16, which is what SetTexCoord(0, pixel / file) does there.
---
--- The overlay list is an input in one shape, whatever it came from (Map.Overlays):
---   { textureWidth, textureHeight, offsetX, offsetY, fileDataIDs, cols?, isShownByMouseOver?,
---     isDrawOnTopLayer? }
--- cols, where given, is how many ids one row of the list holds; otherwise the tile count across.

--- The most overlay tiles one map draws. A busy classic zone is a few dozen; the cap only keeps a
--- map this addon has never seen from asking for hundreds of textures.
Map.EXPLORED_TILE_CAP = 400

--- The smallest power of two, from 16 up, that holds size pixels: the file a last tile is cut from.
function Map.TileFileSize(size)
  local pixels = tonumber(size) or 0
  local file = 16
  while file < pixels do
    file = file * 2
  end
  return file
end

--- One overlay's tiles as rects inside the drawn map, the same shape Map.TileRects answers plus
--- fileId (the texture) and onTop (Blizzard's isDrawOnTopLayer). An empty list for an entry that
--- is only shown while the mouse is over it (isShownByMouseOver: a highlight, not an explored
--- area), and for anything that cannot be laid out. Pure.
function Map.OverlayRects(info, grid, fit)
  if type(info) ~= "table" or type(grid) ~= "table" or type(fit) ~= "table" then
    return EMPTY
  end
  if info.isShownByMouseOver then
    return EMPTY
  end
  local scale = tonumber(fit.scale) or 0
  local tileW = tonumber(grid.tileWidth) or 0
  local tileH = tonumber(grid.tileHeight) or 0
  local width = tonumber(info.textureWidth) or 0
  local height = tonumber(info.textureHeight) or 0
  local ids = info.fileDataIDs
  if scale <= 0 or tileW <= 0 or tileH <= 0 or width <= 0 or height <= 0 or type(ids) ~= "table" then
    return EMPTY
  end
  local offsetX = tonumber(info.offsetX) or 0
  local offsetY = tonumber(info.offsetY) or 0
  local wide = math.ceil(width / tileW)
  local tall = math.ceil(height / tileH)
  local stride = tonumber(info.cols)
  if not stride or stride < 1 then
    stride = wide
  end
  local onTop = info.isDrawOnTopLayer and true or false
  local out = {}
  for row = 1, tall do
    local pixelH, fileH = tileH, tileH
    if row == tall then
      pixelH = height % tileH
      if pixelH == 0 then
        pixelH = tileH
      end
      fileH = Map.TileFileSize(pixelH)
    end
    for col = 1, wide do
      local pixelW, fileW = tileW, tileW
      if col == wide then
        pixelW = width % tileW
        if pixelW == 0 then
          pixelW = tileW
        end
        fileW = Map.TileFileSize(pixelW)
      end
      local fileId = col <= stride and ids[(row - 1) * stride + col] or nil
      if fileId ~= nil then
        out[#out + 1] = {
          fileId = fileId,
          onTop = onTop,
          x = (offsetX + tileW * (col - 1)) * scale,
          y = (offsetY + tileH * (row - 1)) * scale,
          width = pixelW * scale,
          height = pixelH * scale,
          left = 0,
          right = pixelW / fileW,
          top = 0,
          bottom = pixelH / fileH,
        }
      end
    end
  end
  return out
end

--- Every overlay of a map, in list order, capped at Map.EXPLORED_TILE_CAP tiles. Pure.
function Map.ExploredRects(list, grid, fit)
  if type(list) ~= "table" then
    return EMPTY
  end
  local out = {}
  for _, info in ipairs(list) do
    for _, rect in ipairs(Map.OverlayRects(info, grid, fit)) do
      if #out >= Map.EXPLORED_TILE_CAP then
        return out
      end
      out[#out + 1] = rect
    end
  end
  return out
end

--- One row of the shipped MapOverlays module ({ w, h, x, y, t = { ids }, c = cols }) in the shape
--- the client's own GetExploredMapTextures answers, so both sources go through the same maths.
--- nil for a row that is not one. Pure.
function Map.OverlayFromData(row)
  if type(row) ~= "table" or type(row.t) ~= "table" then
    return nil
  end
  local width, height = tonumber(row.w), tonumber(row.h)
  if not width or not height then
    return nil
  end
  return {
    textureWidth = width,
    textureHeight = height,
    offsetX = tonumber(row.x) or 0,
    offsetY = tonumber(row.y) or 0,
    fileDataIDs = row.t,
    cols = tonumber(row.c),
  }
end

--- Where a pin sits inside the drawn map, as an offset from its TOP LEFT. The map's x runs west to
--- east and its y runs north to south, which is the way a database site quotes a pin and the way
--- the client's own map positions run, so x is a straight fraction of the width and y is a
--- straight fraction of the height DOWNWARDS, which is a negative offset in this API.
function Map.PinOffset(xPercent, yPercent, width, height)
  local x = (tonumber(xPercent) or 0) / 100 * (tonumber(width) or 0)
  local y = (tonumber(yPercent) or 0) / 100 * (tonumber(height) or 0)
  return x, -y
end

--- How big a pin is on a map this wide, clamped at both ends. See Map.PIN_BASIS above.
function Map.PinSize(width)
  local drawn = (tonumber(width) or 0) / Map.PIN_BASIS * Map.PIN_AT_BASIS
  if drawn < Map.PIN_MIN then
    return Map.PIN_MIN
  end
  if drawn > Map.PIN_MAX then
    return Map.PIN_MAX
  end
  return drawn
end

--- Brief M11: how thick a patrol path's line is on a map this wide, clamped at both ends.
function Map.PathThickness(width)
  local drawn = (tonumber(width) or 0) / Map.PIN_BASIS * Map.PATH_AT_BASIS
  if drawn < Map.PATH_MIN then
    return Map.PATH_MIN
  end
  if drawn > Map.PATH_MAX then
    return Map.PATH_MAX
  end
  return drawn
end

--- Brief M11: THE LINE PIECES ONE PATROL PATH IS DRAWN WITH on a map drawn width by height, one
--- per pair of consecutive points in walking order, capped at Map.PATH_POINT_CAP points. Each is
--- in the drawn map's own offsets from its TOP LEFT, x to the right and y UP (so a point below the
--- top is negative, as Map.PinOffset answers), with the piece's centre, length and angle, which is
--- what a texture turned about its centre needs, and both ends, which is what a line object needs:
---
---   { x1, y1, x2, y2, cx, cy, length, angle }
---
--- angle is in radians, counter clockwise from pointing right, the way the client turns a texture.
--- Two points on the same spot make no piece. Pure.
function Map.PathSegments(points, width, height)
  local out = {}
  local list = type(points) == "table" and points or EMPTY
  local last = math.min(#list, Map.PATH_POINT_CAP)
  local previous = nil
  for index = 1, last do
    local point = list[index]
    local x = type(point) == "table" and tonumber(point.x) or nil
    local y = type(point) == "table" and tonumber(point.y) or nil
    if x and y then
      local ox, oy = Map.PinOffset(x, y, width, height)
      if previous then
        local dx, dy = ox - previous[1], oy - previous[2]
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0 then
          out[#out + 1] = {
            x1 = previous[1],
            y1 = previous[2],
            x2 = ox,
            y2 = oy,
            cx = (previous[1] + ox) / 2,
            cy = (previous[2] + oy) / 2,
            length = length,
            angle = math.atan2(dy, dx),
          }
        end
      end
      previous = { ox, oy }
    end
  end
  return out
end

--- Brief M13: THE BOX ONE PATROL PATH COVERS, in the map's own percent, over the same points
--- Map.PathSegments draws (a point that is not one is passed over, capped at Map.PATH_POINT_CAP):
---
---   { left, right, top, bottom, width, height, x, y, count }
---
--- x and y are the box's centre and count is how many points it was taken over. nil where the path
--- has no point at all. Pure.
function Map.PathExtent(points)
  local list = type(points) == "table" and points or EMPTY
  local last = math.min(#list, Map.PATH_POINT_CAP)
  local left, right, top, bottom, count = nil, nil, nil, nil, 0
  for index = 1, last do
    local point = list[index]
    local x = type(point) == "table" and tonumber(point.x) or nil
    local y = type(point) == "table" and tonumber(point.y) or nil
    if x and y then
      count = count + 1
      left = left and math.min(left, x) or x
      right = right and math.max(right, x) or x
      top = top and math.min(top, y) or y
      bottom = bottom and math.max(bottom, y) or y
    end
  end
  if count == 0 then
    return nil
  end
  return {
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    width = right - left,
    height = bottom - top,
    x = (left + right) / 2,
    y = (top + bottom) / 2,
    count = count,
  }
end

--- Brief M13: whether a path's box (Map.PathExtent's answer) is under Map.SMALL_PATH_PERCENT on both
--- axes, which is a path the line alone leaves hard to find. Pure.
function Map.IsSmallPath(extent)
  if type(extent) ~= "table" or type(extent.width) ~= "number" or type(extent.height) ~= "number" then
    return false
  end
  return extent.width < Map.SMALL_PATH_PERCENT and extent.height < Map.SMALL_PATH_PERCENT
end

--- Brief M13: THE PINS A PLACE'S SMALL PATHS GET, one plain pin (never the icon marker) at the
--- centre of each small path's box, named "Patrol path" and hovered with the boss's name, the zone
--- and "Patrol path, 14 points". A path with a pin already inside its box (a spawn pin, or the pin
--- of a path before it) gets none, and a larger path gets none: its line is enough. Pure.
---
---   paths  the place's paths, { { points }, ... }
---   pins   the pins the place already draws, { { x, y }, ... }
function Map.PathPins(paths, pins, name, zoneName)
  local out = {}
  local standing = {}
  for _, pin in ipairs(type(pins) == "table" and pins or EMPTY) do
    if type(pin) == "table" and tonumber(pin.x) and tonumber(pin.y) then
      standing[#standing + 1] = { x = tonumber(pin.x), y = tonumber(pin.y) }
    end
  end
  for _, path in ipairs(type(paths) == "table" and paths or EMPTY) do
    local extent = Map.PathExtent(type(path) == "table" and path.points or nil)
    if Map.IsSmallPath(extent) then
      local inside = false
      for _, pin in ipairs(standing) do
        if pin.x >= extent.left and pin.x <= extent.right and pin.y >= extent.top and pin.y <= extent.bottom then
          inside = true
        end
      end
      if not inside then
        local pin = { x = extent.x, y = extent.y, name = L[Map.PATH_PIN], lines = {} }
        for _, text in ipairs({
          type(name) == "string" and name or "",
          type(zoneName) == "string" and zoneName or "",
          string.format(L[Map.PATH_PIN_POINTS], extent.count),
        }) do
          if text ~= "" then
            pin.lines[#pin.lines + 1] = text
          end
        end
        out[#out + 1] = pin
        standing[#standing + 1] = pin
      end
    end
  end
  return out
end

--- Brief M10: a pin that wears an icon (the instance portal, Map.PORTAL_KEY) is drawn as a MARKER:
--- the icon in a square with a one pixel border in the pin's own colour (the silver blue of the
--- plain pin, Map.PIN_FALLBACK_COLOUR), and a small pointer centred on the bottom border pointing
--- down. The TIP of the pointer is the position; the square stands above it, so the icon never
--- covers the ground it names. The pointer is a square of the plain white fill turned a quarter of
--- a right angle into a diamond, centred on the bottom border and drawn under the icon, so the icon
--- hides its top half and its bottom half is the notch. Plain pins are unchanged.
Map.MARKER_BORDER = 1
Map.MARKER_COLOUR = Map.PIN_FALLBACK_COLOUR
Map.MARKER_FILL_KEY = "FILL_WHITE8X8"
--- The pointer's height against the square's side, and never under MARKER_POINTER_MIN pixels,
--- below which a notch reads as a speck on the border.
Map.MARKER_POINTER = 0.3
Map.MARKER_POINTER_MIN = 3

--- The marker's geometry for an icon drawn size pixels square. Pure.
---
---   side     the square, border included (the icon is side - 2 * MARKER_BORDER inside it)
---   pointer  how far the tip hangs under the square's bottom edge
---   width, height   the frame, which is the hit area: the square and the pointer together
---   point    the frame's point that goes on the position: BOTTOM, which is the tip
---   diamond  the pointer's own square, before it is turned, and where its centre sits above the
---            tip (on the bottom border, so exactly half of it hangs below the square)
function Map.MarkerRect(size)
  local icon = tonumber(size) or 0
  if icon < 0 then
    icon = 0
  end
  local side = icon + 2 * Map.MARKER_BORDER
  local pointer = math.floor(side * Map.MARKER_POINTER + 0.5)
  if pointer < Map.MARKER_POINTER_MIN then
    pointer = Map.MARKER_POINTER_MIN
  end
  return {
    icon = icon,
    side = side,
    pointer = pointer,
    width = side,
    height = side + pointer,
    point = "BOTTOM",
    diamond = pointer * math.sqrt(2),
    diamondY = pointer,
  }
end

--- Where the marker's parts land relative to the position it stands for, x to the right and y UP,
--- in pixels: the tip, and the square's four edges. What the spec reads to say the tip is on the
--- point and the square is above it. Pure.
function Map.MarkerExtent(rect)
  if type(rect) ~= "table" then
    return nil
  end
  local half = rect.side / 2
  return {
    tipX = 0,
    tipY = 0,
    left = -half,
    right = half,
    bottom = rect.pointer,
    top = rect.pointer + rect.side,
  }
end

--- Brief CS2 (QA item 309): the green outline's geometry for a Confirmed pin drawn size pixels square.
--- Pure.
---
---   width   the band, in whole pixels, between the pin's own diamond and the outline's edge
---   pin     how far the pin's own diamond reaches from its centre to a corner (half of size times
---           Map.PIN_DIAMOND)
---   side    the square SetRotation turns into the outline's diamond, centred on the pin: the pin's
---           own diamond's square (its corner to corner over the square root of two) with the band on
---           both sides, so every edge of the outline stands width pixels off the pin's edge
---   reach   how far the outline's corners reach from the pin's centre (pin plus width times the
---           square root of two)
function Map.OutlineRect(size)
  local side = tonumber(size) or 0
  if side < 0 then
    side = 0
  end
  local width = math.floor(side * Map.OUTLINE_SHARE + 0.5)
  if width < Map.OUTLINE_MIN then
    width = Map.OUTLINE_MIN
  end
  local diamond = side * Map.PIN_DIAMOND
  local square = diamond / math.sqrt(2) + 2 * width
  return {
    width = width,
    pin = diamond / 2,
    side = square,
    reach = square / math.sqrt(2),
  }
end

--- Brief UX2: THE HIGHEST ZOOM a map drawn at this fit scale (Map.Fit's scale: drawn pixels per pixel of
--- the art) may take: Map.ZOOM_MAX, or less where more would draw one pixel of the art across more than
--- Map.ZOOM_TEXEL drawn ones, and never under 1 (the map fitted to the panel). Pure.
function Map.ZoomCeiling(scale)
  scale = tonumber(scale) or 0
  if scale <= 0 then
    return 1
  end
  return math.max(1, math.min(Map.ZOOM_MAX, Map.ZOOM_TEXEL / scale))
end

--- Brief UX2: a zoom held between 1 and the ceiling, and exactly 1 where a step back down lands a
--- rounding error away from it (1.25 times 0.8 is not quite 1 in floating point). Pure.
function Map.ClampZoom(zoom, ceiling)
  zoom = tonumber(zoom) or 1
  ceiling = math.max(1, tonumber(ceiling) or 1)
  if zoom > ceiling then
    zoom = ceiling
  end
  if zoom < 1 + 1e-6 then
    return 1
  end
  return zoom
end

--- Brief UX2: whether a press that has moved dx, dy (the window's units) is a drag. Pure.
function Map.IsDrag(dx, dy)
  dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
  return dx * dx + dy * dy >= Map.DRAG_THRESHOLD * Map.DRAG_THRESHOLD
end

--- Brief UX2: whether a pin at x, y (Map.PinOffset's answer on the map drawn at 1x: x to the right, y
--- UP, so a pin below the top is negative) is inside a viewport width by height at this zoom and pan
--- (the zoomed map's top left, in the viewport's own units with y DOWN, Chain.ClampPan's shape). A pin
--- outside is hidden, so nothing off the visible map can be hovered or clicked. Pure.
function Map.InView(x, y, zoom, panX, panY, width, height)
  zoom = tonumber(zoom) or 1
  local across = (tonumber(panX) or 0) + (tonumber(x) or 0) * zoom
  local down = (tonumber(panY) or 0) - (tonumber(y) or 0) * zoom
  local slack = 1e-6
  return across >= -slack
    and across <= (tonumber(width) or 0) + slack
    and down >= -slack
    and down <= (tonumber(height) or 0) + slack
end

--- Brief UX2: what one zoom belongs to: the page the map is on and the zone it draws. The zoom is kept
--- while the key is (the tab left and come back to, the window resized) and goes back to 1x as soon as
--- the map drawn is another one. Pure.
function Map.ZoomKey(root, zone)
  local entry = type(zone) == "table" and zone or EMPTY
  return string.format("%s|%s|%s", tostring(root or ""), tostring(entry.areaId), tostring(entry.map))
end

--- Brief MP1 of 2026-10-20 (CS2's note): how far the plain pin's tip stands over its frame's bottom
--- edge, for a pin drawn size pixels square. The art's diamond is centred in its crop (Map.PIN_DIAMOND),
--- so its bottom corner, the tip a player reads as the spot, is (1 - PIN_DIAMOND) / 2 of the side up:
--- about 2 pixels on the 14 pixel pin. drawPins lowers the frame by this much, so the tip is on the
--- position at every pin size. Pure.
function Map.PinTipLift(size)
  local side = tonumber(size) or 0
  if side < 0 then
    side = 0
  end
  return side * (1 - Map.PIN_DIAMOND) / 2
end

--- Brief M12: how many rows a line wraps to inside width at one font size, by the same estimate
--- Map.TextWidth makes. What the client measures wins where it will answer (layOut asks it); this
--- is the answer where it will not, and it is what every spec measures against. Pure.
function Map.TextRows(text, width, fontSize)
  local wide = tonumber(width) or 0
  local need = Map.TextWidth(text, fontSize)
  if wide <= 0 or need <= wide then
    return 1
  end
  return math.ceil(need / wide)
end

--- Brief M12: how tall a block of lines comes to inside width, one line under the next with
--- Map.LINE_GAP between them, as layOut lays them out. 0 for no lines. Pure.
function Map.LinesHeight(lines, width, fontSize)
  local size = tonumber(fontSize) or Map.FONT_SM
  local tall, count = 0, 0
  for _, line in ipairs(type(lines) == "table" and lines or EMPTY) do
    if type(line) == "table" then
      count = count + 1
      tall = tall + Map.TextRows(line.text, width, size) * size
    end
  end
  if count == 0 then
    return 0
  end
  return tall + (count - 1) * Map.LINE_GAP
end

--- Brief M12: THE MAP BLOCK laid out down a pane height pixels tall, under a strip top pixels tall:
--- the caption lines, the map, and the note lines under it, with the map scaled to whatever room
--- the words leave (keeping its shape), so the block never reaches past the pane's bottom edge at
--- any size the window can take. captionsH and notesH are the two blocks' own heights (measured by
--- the client, or Map.LinesHeight). Every offset is DOWN from the pane's top. Pure.
---
---   fit        Map.Fit's answer for the room, or nil where the art cannot be laid out
---   captionTop where the caption block starts
---   canvasTop  where the map starts
---   notesTop   where the note block starts
---   bottom     where the whole block ends, which is never past height - Map.PAD while the pane
---              has room for the words at all
function Map.BlockLayout(grid, width, height, top, captionsH, notesH)
  top = tonumber(top) or 0
  captionsH = tonumber(captionsH) or 0
  notesH = tonumber(notesH) or 0
  local captionTop = top + Map.PAD
  local captionBlock = captionsH > 0 and captionsH + Map.LINE_GAP or 0
  local notesBlock = notesH > 0 and notesH + Map.LINE_GAP or 0
  local canvasTop = captionTop + captionBlock + Map.GAP
  local room = math.max(1, (tonumber(height) or 0) - Map.PAD - notesBlock - Map.GAP - canvasTop)
  local fit = Map.Fit(grid, width, room)
  if not fit then
    return nil
  end
  local notesTop = canvasTop + fit.height + Map.GAP
  return {
    fit = fit,
    captionTop = captionTop,
    canvasTop = canvasTop,
    notesTop = notesTop,
    bottom = notesTop + notesH,
  }
end

--- The zone list the tab draws, out of the two things the addon knows about one creature: the
--- places the shipped rows state (which is what the seam hands over) and the areas its pins stand
--- in, which are not the same list. A creature's loot rows name the one place the source database
--- filed them under; its pins can stand in a dozen. Rabbit is known in Dun Morogh and has pins in
--- thirteen zones.
---
--- Each entry is { areaId, name, map, pins }: name from the seam where the seam knew it, map the
--- zone map id off the first pin that carries one, and pins the pipeline's own order inside that
--- area, fullest cell first, never sorted here.
---
--- The order is the data's own: the seam's places first, in its order, then any area only the pins
--- name, in theirs. Answers the list and the index of the zone that opens first, which is the one
--- with the most pins, ties going to whichever comes first in that order. nil where there is
--- nothing at all to show.
---
--- Brief M11: paths (EraSources.PathsOf's answer) put each path on its own area's zone, after the
--- pins, as { points } in entry.paths, so a zone a boss only walks through is in the list too. A pin
--- that is a hand kept spot keeps its kept mark.
function Map.Merge(zones, pins, paths)
  local list, byArea = {}, {}
  local function slot(areaId)
    local held = byArea[areaId]
    if held then
      return held
    end
    held = { areaId = areaId, pins = {} }
    byArea[areaId] = held
    list[#list + 1] = held
    return held
  end
  for _, zone in ipairs(type(zones) == "table" and zones or EMPTY) do
    local areaId = type(zone) == "table" and tonumber(zone.areaId) or nil
    if areaId then
      local entry = slot(areaId)
      if type(zone.name) == "string" and zone.name ~= "" then
        entry.name = zone.name
      end
    end
  end
  for _, pin in ipairs(type(pins) == "table" and pins or EMPTY) do
    local areaId = type(pin) == "table" and tonumber(pin.area) or nil
    local x = type(pin) == "table" and tonumber(pin.x) or nil
    local y = type(pin) == "table" and tonumber(pin.y) or nil
    if areaId and x and y then
      local entry = slot(areaId)
      if entry.map == nil and tonumber(pin.map) then
        entry.map = tonumber(pin.map)
      end
      if #entry.pins < Map.PIN_CAP then
        entry.pins[#entry.pins + 1] = { x = x, y = y, kept = pin.kept == true or nil }
      end
    end
  end
  for _, path in ipairs(type(paths) == "table" and paths or EMPTY) do
    local areaId = type(path) == "table" and tonumber(path.area) or nil
    local points = type(path) == "table" and path.points or nil
    if areaId and type(points) == "table" and #points >= 2 then
      local entry = slot(areaId)
      if entry.map == nil and tonumber(path.map) then
        entry.map = tonumber(path.map)
      end
      entry.paths = entry.paths or {}
      if #entry.paths < Map.PATH_CAP then
        entry.paths[#entry.paths + 1] = { points = points }
      end
    end
  end
  local selected = nil
  for index, entry in ipairs(list) do
    if not selected or #entry.pins > #list[selected].pins then
      selected = index
    end
  end
  return list, selected
end

--- Brief Q9b: a node's zone list with every zone that has a pin ahead of every zone that has none,
--- each half in the order it had, and the index of the zone that opened first carried across. A
--- node's own row lists zones its pins never stand in, and those read "no positions known" at the
--- foot of the list rather than among the zones a player can look at. Pure; list is reordered in
--- place and returned.
function Map.PinnedFirst(list, selected)
  if type(list) ~= "table" then
    return list, selected
  end
  local open = list[selected]
  local pinned, bare = {}, {}
  for _, zone in ipairs(list) do
    if #(type(zone) == "table" and zone.pins or EMPTY) > 0 then
      pinned[#pinned + 1] = zone
    else
      bare[#bare + 1] = zone
    end
  end
  for index = 1, #pinned do
    list[index] = pinned[index]
  end
  for index = 1, #bare do
    list[#pinned + index] = bare[index]
  end
  for index, zone in ipairs(list) do
    if zone == open then
      return list, index
    end
  end
  return list, selected
end

--------------------------------------------------------------------------------
-- Pure. The zone strip: a row of buttons, or one dropdown (brief E62)
--------------------------------------------------------------------------------

--- Roughly how wide a label is at one font size, in pixels.
---
--- Nothing outside the client can measure a font, so this is the body face's average advance
--- times the number of characters, the same estimate UI/Chain.lua keeps for the same reason: the
--- client's own ruler is asked first, this is the answer where there is none, and it is the
--- answer every spec measures against.
function Map.TextWidth(text, fontSize)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  fontSize = tonumber(fontSize) or Map.FONT_SM
  return math.ceil(#text * fontSize * Map.BUTTON_CHAR)
end

--- How wide one zone button is for a label that wide: the words, padding either side, and never
--- under two button heights, so a one word zone is a button rather than a stub.
function Map.ButtonWidth(textWidth)
  local wide = (tonumber(textWidth) or 0) + 2 * Map.BUTTON_PAD
  local least = Map.BUTTON_H * 2
  if wide < least then
    return least
  end
  return wide
end

--- The words one zone wears in the strip: the build's own name for it, and the bare area id where
--- the table has no name for it, which is what the buttons drew before the dropdown existed.
function Map.ZoneText(zone)
  if type(zone) ~= "table" then
    return ""
  end
  -- Brief M8: a place headed with more than its zone ("Azuregos spawn points, Azshara") wears
  -- just the zone in the strip.
  if type(zone.stripName) == "string" and zone.stripName ~= "" then
    return zone.stripName
  end
  if type(zone.name) == "string" and zone.name ~= "" then
    return zone.name
  end
  return tostring(zone.areaId or "")
end

--- WHICH CONTROL THE ZONE STRIP IS, out of the zone names' MEASURED widths (in the strip's own
--- order) and the width the panel has for them: "none", "buttons" or "menu".
---
--- Two rules, and either one is enough to make it a dropdown:
---   * more than Map.ZONE_MAX zones, which is the owner's ruling (see the constant), because
---     thirteen buttons is three rows of them stacked over the map;
---   * a row that will not fit the panel's width at the window's current size and scale, because
---     five short zone names fit a wide window and three long ones do not fit a narrow one.
---
--- The width boundary is inclusive: a row that comes to EXACTLY the room it is given still draws
--- as buttons, and one pixel more is a dropdown. Fewer than two zones is no control at all, since
--- a button that is the only button says nothing.
---
--- Pure, and measured rather than guessed: the caller hands over the client's own measurement of
--- each name where the client will answer, and Map.TextWidth's estimate where it will not.
function Map.ZoneControl(widths, available)
  local list = type(widths) == "table" and widths or EMPTY
  local count = #list
  if count < 2 then
    return "none"
  end
  if count > Map.ZONE_MAX then
    return "menu"
  end
  local room = tonumber(available) or 0
  local total = 0
  for index = 1, count do
    if index > 1 then
      total = total + Map.BUTTON_GAP
    end
    total = total + Map.ButtonWidth(list[index])
  end
  if room > 0 and total > room then
    return "menu"
  end
  return "buttons"
end

--- What the dropdown itself reads: the zone that is open and how many pins stand in it, so the
--- strip says as much as the row of buttons it replaced.
function Map.ZoneLabel(zone)
  if type(zone) ~= "table" then
    return ""
  end
  local pins = #(zone.pins or EMPTY)
  if pins == 0 then
    -- Brief Q9b: words, never a bare 0.
    return string.format(L["%s (%s)"], Map.ZoneText(zone), Map.EmptyWord(zone))
  end
  return string.format(L["%s (%d)"], Map.ZoneText(zone), pins)
end

--- What a zone with no pin says in place of a count: "patrol path" where a path is drawn in it
--- (brief M11), "no positions known" otherwise. Pure.
function Map.EmptyWord(zone)
  if type(zone) == "table" and type(zone.paths) == "table" and #zone.paths > 0 then
    return L[Map.PATROL_WORD]
  end
  return L[Map.NO_POSITIONS]
end

--- The first point of a zone's first path, or nil. Pure.
local function pathStart(zone)
  local paths = type(zone) == "table" and zone.paths or nil
  local first = type(paths) == "table" and paths[1] or nil
  local points = type(first) == "table" and first.points or nil
  return type(points) == "table" and points[1] or nil
end

--- The rows the dropdown's list draws: every zone the tab has, in the DATA'S OWN order (which is
--- the order the buttons drew in and the order Map.Merge states), each with its name, its pin
--- count and whether it is the one open. Never sorted here: a list that reshuffled itself when it
--- was reopened would move the row under the player's hand.
function Map.MenuEntries(list, selected)
  local out = {}
  for index, zone in ipairs(type(list) == "table" and list or EMPTY) do
    local pins = #(zone.pins or EMPTY)
    out[index] = {
      areaId = zone.areaId,
      text = Map.ZoneText(zone),
      -- Brief Q9b: a zone with no pin says so in words, which are wider than the count column, so
      -- the row is marked and its name gives them the room (Map.MenuWidths, applyMenuRow).
      right = pins == 0 and Map.EmptyWord(zone) or tostring(pins),
      wide = pins == 0 or nil,
      current = index == selected,
    }
  end
  return out
end

--- Brief Q9b: the widths Map.MenuWidth sizes the list by, with each row whose right hand words are
--- wider than the count column (a zone with "no positions known") widened by the difference, so
--- the name and the words both fit where the list's ceiling allows. measure(text) is the client's
--- ruler where there is one; Map.TextWidth's estimate otherwise. Pure.
function Map.MenuWidths(widths, entries, measure)
  local out = {}
  for index, width in ipairs(type(widths) == "table" and widths or EMPTY) do
    local at = tonumber(width) or 0
    local entry = type(entries) == "table" and entries[index] or nil
    if type(entry) == "table" and entry.wide and type(entry.right) == "string" then
      local right = type(measure) == "function" and tonumber(measure(entry.right)) or nil
      right = right or Map.TextWidth(entry.right, Map.FONT_SM)
      if right > Map.MENU_RIGHT_W then
        at = at + (right - Map.MENU_RIGHT_W) + Map.BUTTON_PAD
      end
    end
    out[index] = at
  end
  return out
end

--- How wide the list is: its longest name, the pin count on the right and the tick beside it,
--- held between the dropdown's own width and a ceiling so thirteen zone names cannot draw a list
--- wider than the map under it.
function Map.MenuWidth(widths, least, most)
  least = tonumber(least) or Map.MENU_MIN_W
  most = tonumber(most) or Map.MENU_MAX_W
  if most < least then
    most = least
  end
  local widest = 0
  for _, width in ipairs(type(widths) == "table" and widths or EMPTY) do
    local at = tonumber(width) or 0
    if at > widest then
      widest = at
    end
  end
  local wanted = math.ceil(widest) + Map.MENU_RIGHT_W + Map.MENU_ACTION + Map.BUTTON_PAD * 3
  if wanted < least then
    return least
  end
  if wanted > most then
    return most
  end
  return wanted
end

--- The most rows a list of this many can start at and still fill itself. Same arithmetic as
--- UI/Chain.lua's own lists, because it is the same wheel.
function Map.MaxOffset(count, rows)
  count = tonumber(count) or 0
  rows = tonumber(rows) or Map.MENU_MAX_ROWS
  if rows < 1 then
    rows = 1
  end
  local most = count - rows
  if most < 0 then
    return 0
  end
  return most
end

--- Where the list starts so the zone that is open is on screen when the list is opened again.
--- Thirteen zones is ten rows and three below the fold, and a player who picked the last of them
--- would otherwise reopen the list on rows they have already read.
function Map.MenuStart(current, count, rows)
  rows = tonumber(rows) or Map.MENU_MAX_ROWS
  if rows < 1 then
    rows = 1
  end
  current = tonumber(current) or 0
  if current <= rows then
    return 0
  end
  local most = Map.MaxOffset(count, rows)
  local start = current - rows
  if start > most then
    return most
  end
  return start
end

--- The alpha a pin is drawn at: Map.WEAK_ALPHA for a weak spot (the owner's standing rule of
--- 2026-10-20), full for every other pin. Pure.
function Map.PinAlpha(pin)
  if type(pin) == "table" and pin.weak then
    return Map.WEAK_ALPHA
  end
  return 1
end

--- Brief MP1 of 2026-10-20 (QA item 321): how many levels over the canvas a pin is drawn, so the surer
--- spot is on top where pins overlap: Map.PIN_LEVEL_CONFIRMED for a Confirmed spot, Map.PIN_LEVEL_WEAK
--- for a weak one, Map.PIN_LEVEL for every other pin. Pure.
function Map.PinLevel(pin)
  if type(pin) ~= "table" then
    return Map.PIN_LEVEL
  end
  if pin.confirmed == true then
    return Map.PIN_LEVEL_CONFIRMED
  end
  if pin.weak then
    return Map.PIN_LEVEL_WEAK
  end
  return Map.PIN_LEVEL
end

--- One pin as a player reads it, which is the pair every database site quotes.
function Map.PinText(pin)
  if type(pin) ~= "table" then
    return ""
  end
  return string.format("%.1f, %.1f", tonumber(pin.x) or 0, tonumber(pin.y) or 0)
end

--- The words over the map: the zone's own name, and under it the one line a zone that has a map
--- and no pin for this creature needs, because an empty map with no caption reads as a bug.
function Map.CaptionLines(zone)
  local out = {}
  if type(zone) ~= "table" then
    return out
  end
  if type(zone.name) == "string" and zone.name ~= "" then
    out[#out + 1] = { text = zone.name, heading = true }
  end
  -- Brief Z1: a zone's own map names the source it is pinning under the zone, and says how to pick
  -- one while none is picked, which is the one case where an empty map is not "no position".
  if type(zone.subtitle) == "string" and zone.subtitle ~= "" then
    out[#out + 1] = { text = zone.subtitle }
  end
  if zone.map and #(zone.pins or EMPTY) == 0 and not pathStart(zone) then
    if type(zone.hint) == "string" and zone.hint ~= "" then
      out[#out + 1] = { text = zone.hint, muted = true }
    else
      out[#out + 1] = { text = L[Map.NO_POSITION], muted = true }
    end
  end
  return out
end

--- The Predicted wording the rest of the addon closes a Classic Era block with, read through
--- Core/Confidence.lua so the word itself is written down in one place.
function Map.PredictedWord()
  local confidence = ItemTree.Confidence
  if type(confidence) == "table" and type(confidence.Label) == "function" then
    local ok, label = pcall(confidence.Label, confidence.PREDICTED)
    if ok and type(label) == "string" and label ~= "" then
      return label
    end
  end
  return L["Predicted"]
end

--- The two lines under the map: the same pair every other prediction in the addon closes on, with
--- the provenance line written for a position rather than for a drop.
function Map.NoteLines()
  return {
    { text = Map.PredictedWord(), muted = true },
    { text = L[Map.NOTE], muted = true },
  }
end

--- Brief Z5: the lines under a zone's own map. A zone new in Forever (facts.forever, the table's
--- zf) holds nothing out of Classic Era, so it says nothing there; every other zone closes on the
--- Predicted pair (Map.NoteLines). Pure.
function Map.ZoneNoteLines(facts)
  if type(facts) == "table" and facts.forever then
    return {}
  end
  return Map.NoteLines()
end

--- The block a zone this client has no map for draws instead of art: which place the creature is
--- inside, and why there is nothing to look at. Every instance in this build is one of these,
--- because the client ships no dungeon map at all.
function Map.InsideLines(zone)
  local name = type(zone) == "table" and zone.name or nil
  if type(name) ~= "string" or name == "" then
    return EMPTY
  end
  return {
    { text = string.format(L[Map.INSIDE], name), heading = true },
    { text = L[Map.NO_INSIDE_MAP], muted = true },
  }
end

--- What the tab says when there is no art to draw at all: the places, with each pin written out
--- under its own zone's name, in the shape Tree.DrawMapZones lays out. A zone with no pin keeps
--- its bare name, which is exactly what the tab drew before this file existed.
---
--- cap is how many lines of places and pins are listed before the rest are counted out, in the
--- same words every other capped list in the addon uses.
function Map.TextLines(list, cap)
  local Tree = ItemTree.UI and ItemTree.UI.Tree
  local places = type(list) == "table" and list or EMPTY
  if #places == 0 then
    if type(Tree) == "table" and type(Tree.MapLines) == "function" then
      return Tree.MapLines(EMPTY, Map.TEXT_CAP)
    end
    return EMPTY
  end
  cap = math.max(1, math.floor(tonumber(cap) or Map.TEXT_CAP))
  local heading = (type(Tree) == "table" and Tree.MAP_HEADING) or "Known in"
  local out = { { text = L[heading], heading = true } }
  local held = 0
  local function push(text)
    if #out - 1 < cap then
      out[#out + 1] = { text = text }
    else
      held = held + 1
    end
  end
  for _, zone in ipairs(places) do
    local name = type(zone.name) == "string" and zone.name ~= "" and zone.name or nil
    local pins = zone.pins or EMPTY
    if #pins == 0 then
      if name then
        push(name)
      end
      -- Brief M11: a zone the creature only walks through says where its patrol starts.
      local start = pathStart(zone)
      if start then
        push(string.format(L[Map.PATROL_FROM], Map.PinText(start)))
      end
    else
      for _, pin in ipairs(pins) do
        -- Both halves are data, so there is nothing here to translate: the zone is the build's
        -- own name for it and the pair is two numbers.
        push(name and (name .. " " .. Map.PinText(pin)) or Map.PinText(pin))
      end
    end
  end
  if held > 0 then
    local more = nil
    local Sources = ItemTree.Sources
    if type(Sources) == "table" and type(Sources.MoreText) == "function" then
      local ok, text = pcall(Sources.MoreText, held)
      if ok and type(text) == "string" and text ~= "" then
        more = text
      end
    end
    out[#out + 1] = { text = more or (tostring(held) .. " more"), muted = true }
  end
  return out
end

--- The three lines a hovered pin puts in the tooltip: what it is, where it is, and the pair. Any
--- of them that is not known is left out rather than drawn empty.
function Map.TipLines(name, zone, pin)
  local out = {}
  if type(name) == "string" and name ~= "" then
    out[#out + 1] = name
  end
  if type(zone) == "string" and zone ~= "" then
    out[#out + 1] = zone
  end
  local text = Map.PinText(pin)
  if text ~= "" then
    out[#out + 1] = text
  end
  return out
end

--- What a place with no art draws instead: its name, then each pin written out after the name of
--- the creature it belongs to, or the one line a place with no pin needs, capped the way
--- Map.TextLines is. zone is one entry of the list Map.DrawPlaces is handed. Pure.
function Map.PlaceLines(zone, cap)
  local out = {}
  if type(zone) ~= "table" then
    return out
  end
  cap = math.max(1, math.floor(tonumber(cap) or Map.TEXT_CAP))
  if type(zone.name) == "string" and zone.name ~= "" then
    out[#out + 1] = { text = zone.name, heading = true }
  end
  local pins = type(zone.pins) == "table" and zone.pins or EMPTY
  local start = pathStart(zone)
  if #pins == 0 then
    if start then
      out[#out + 1] = { text = string.format(L[Map.PATROL_FROM], Map.PinText(start)) }
    elseif type(zone.hint) == "string" and zone.hint ~= "" then
      out[#out + 1] = { text = zone.hint, muted = true }
    else
      out[#out + 1] = { text = L[Map.NO_POSITION], muted = true }
    end
    return out
  end
  for index, pin in ipairs(pins) do
    if index > cap then
      break
    end
    local name = type(pin.name) == "string" and pin.name ~= "" and pin.name or nil
    -- Both halves are data, as in Map.TextLines: a name and two numbers.
    out[#out + 1] = { text = name and (name .. " " .. Map.PinText(pin)) or Map.PinText(pin) }
  end
  return out
end

--- THE ONE PLACE A ZONE'S OWN MAP DRAWS (brief Z1), in the shape Map.DrawPlaces takes: the zone,
--- its map (nil for an instance, which draws the block E60 made for one), and the picked source's
--- pins that stand in THIS zone and no other, each named for the source, capped the way a
--- creature's are. With nothing picked it has no pins and carries the line that says how to pick
--- one; with a pick it carries the source's name under the zone's. Pure.
---
---   facts  { areaId, name, map } out of Core/EraSources.lua E:ZoneFacts
---   pick   { nameIndex, kind, name } or nil (Core/ViewModel.lua ViewModel.ZonePick)
---   pins   the picked name's decoded pins, every area of them, or nil
function Map.ZonePlace(facts, pick, pins)
  if type(facts) ~= "table" or type(facts.areaId) ~= "number" then
    return nil
  end
  local place = { areaId = facts.areaId, name = facts.name, map = tonumber(facts.map), pins = {} }
  local name = type(pick) == "table" and type(pick.name) == "string" and pick.name ~= "" and pick.name or nil
  if not name then
    place.hint = L[Map.ZONE_HINT]
    return place
  end
  place.subtitle = name
  for _, pin in ipairs(type(pins) == "table" and pins or EMPTY) do
    if type(pin) == "table" and tonumber(pin.area) == facts.areaId and tonumber(pin.x) and tonumber(pin.y) then
      if #place.pins < Map.PIN_CAP then
        place.pins[#place.pins + 1] = { x = tonumber(pin.x), y = tonumber(pin.y), name = name }
      end
    end
  end
  return place
end

--- The line a zone name that is a link says on hover: "Click to open Feralas". nil for no name.
--- Pure.
function Map.ZoneLinkText(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return string.format(L[Map.ZONE_LINK], name)
end

--- Brief Z2: the lines a hovered pin of a zone's item pick puts in the tooltip: the source's own
--- name (the creature, the node or the vendor), the rate its Here row states, the level range the
--- table states for a creature, the pair, and the Predicted word, because every one of these
--- positions is Classic Era's. Anything not known is left out. Pure.
function Map.ZonePinLines(source, pin, low, high)
  local out = {}
  source = type(source) == "table" and source or EMPTY
  if type(source.name) == "string" and source.name ~= "" then
    out[#out + 1] = source.name
  end
  if type(source.rate) == "string" and source.rate ~= "" then
    out[#out + 1] = source.rate
  end
  low, high = tonumber(low), tonumber(high)
  if low and low > 0 then
    if high and high > low then
      out[#out + 1] = string.format(L["Level %d to %d"], low, high)
    else
      out[#out + 1] = string.format(L["Level %d"], low)
    end
  end
  local text = Map.PinText(pin)
  if text ~= "" then
    out[#out + 1] = text
  end
  out[#out + 1] = Map.PredictedWord()
  return out
end

--- Brief Z2: the line under a zone's map saying what is pinned: the item, then its one source by
--- name or its sources counted ("10 creatures"), then how many places, with the ones the cap held
--- back counted out. An item whose only source names nothing (a whole fishing zone) says so and
--- counts no places. Pure.
---
---   entry   an item row of Core/ViewModel.lua ViewModel.ZoneItemsOf
---   places  how many pins the pick has in this zone, before the cap
---   more    how many of those the cap held back
function Map.ZoneItemCaption(entry, places, more)
  if type(entry) ~= "table" then
    return nil
  end
  local name = tostring(entry.name or "")
  local count = tonumber(entry.count) or 0
  local what = entry.countText
  if count == 1 then
    local only = type(entry.sources) == "table" and entry.sources[1] or nil
    if type(only) == "table" and type(only.name) == "string" and only.name ~= "" then
      what = only.name
    end
  end
  what = tostring(what or "")
  if count < 1 then
    -- Brief Q9b: a fish from a whole fishing zone is caught in open water, and says so.
    if entry.group == "fishedin" then
      what = L[Map.OPEN_WATER]
    end
    return string.format(L[Map.ZONE_CAPTION_BARE], name, what)
  end
  places = math.max(0, math.floor(tonumber(places) or 0))
  more = math.max(0, math.floor(tonumber(more) or 0))
  -- Brief Z2 (2026-09-30): a creature's or an NPC's own row is its one source, so the caption names
  -- it once: "Harvest Watcher: 14 places".
  local person = entry.person == true
  local counted
  if places == 0 then
    counted = L[Map.NO_PLACES]
  elseif more > 0 then
    counted = string.format(L[Map.PLACES_MORE], places - more, more)
  elseif places == 1 then
    counted = L[Map.ONE_PLACE]
  else
    counted = string.format(L[Map.PLACES], places)
  end
  if person then
    return string.format(L[Map.ZONE_CAPTION_BARE], name, counted)
  end
  return string.format(L[Map.ZONE_CAPTION], name, what, counted)
end

--- Brief M15: the one pin a placed object source of a zone's item row stands at ({ area, x, y }, x
--- and y in percent, Core/ViewModel.lua ViewModel.AddPlacedZoneItems), or nil for any other source.
--- Pure.
function Map.PlacedPin(source)
  if type(source) ~= "table" or source.placed ~= true then
    return nil
  end
  local area, x, y = tonumber(source.area), tonumber(source.x), tonumber(source.y)
  if not area or not x or not y then
    return nil
  end
  return { area = area, x = x, y = y }
end

--- Brief Z2: THE PLACE A ZONE'S ITEM PICK DRAWS, in the shape Map.DrawPlaces takes: the zone, its
--- map, and every pin of every source of the picked item that stands in this zone, each with its own
--- tooltip lines, capped at Map.ZONE_PIN_CAP in the sources' own order, and the caption naming the
--- pick. Pure.
---
---   facts    { areaId, name, map } out of Core/EraSources.lua E:ZoneFacts
---   entry    the picked item row (Core/ViewModel.lua ViewModel.ZoneItemsOf)
---   decoded  one { pins, low, high } per entry.sources, by the same index: the source's decoded
---            pins (every area of them) and the level range the table states for a creature
function Map.ZoneItemPlace(facts, entry, decoded)
  if type(facts) ~= "table" or type(facts.areaId) ~= "number" or type(entry) ~= "table" then
    return nil
  end
  local place = { areaId = facts.areaId, name = facts.name, map = tonumber(facts.map), pins = {} }
  local places, cap = 0, Map.ZONE_PIN_CAP
  decoded = type(decoded) == "table" and decoded or EMPTY
  for index, source in ipairs(type(entry.sources) == "table" and entry.sources or EMPTY) do
    local held = type(decoded[index]) == "table" and decoded[index] or EMPTY
    for _, pin in ipairs(type(held.pins) == "table" and held.pins or EMPTY) do
      local x, y = type(pin) == "table" and tonumber(pin.x) or nil, type(pin) == "table" and tonumber(pin.y) or nil
      if x and y and tonumber(pin.area) == facts.areaId then
        places = places + 1
        if #place.pins < cap then
          local at = { x = x, y = y, name = source.name }
          at.lines = Map.ZonePinLines(source, at, held.low, held.high)
          -- Brief M15: a placed object's pin names the item it holds under the object.
          if source.placed == true and type(entry.name) == "string" and entry.name ~= "" then
            table.insert(at.lines, 2, entry.name)
          end
          place.pins[#place.pins + 1] = at
        end
      end
    end
  end
  place.places = places
  place.more = places - #place.pins
  place.subtitle = Map.ZoneItemCaption(entry, places, place.more)
  return place
end

--------------------------------------------------------------------------------
-- Pure. A vendor's own pin (brief M3)
--------------------------------------------------------------------------------

--- A vendor's place put into the zone list the tab draws: where the curated tier ships one, or
--- where the player stood when they opened its window (Core/Sources.lua Favour.Positions).
---
--- positions is { { map, x, y, zone, name, seen } }, x and y in percent. A pin joins the zone
--- already drawn on that map (a name's Classic Era pins, brief N3), in front of them, else the
--- vendor's map is added as a zone of its own. Answers the list and the index of the zone the
--- vendor's own pin is in, which is the one that opens first. Pure: only the list handed in, or a
--- new one, is changed.
--
-- Brief NW1: a hand kept spot (pos.spot) is kept past Map.PIN_CAP, up to Map.SPOT_CAP on its map, and
-- its pin says the creature is at one of these places (Map.SpotLines) when hovered.
function Map.WithVendorPins(list, positions)
  list = type(list) == "table" and list or {}
  local selected = nil
  local spotted = {}
  for _, pos in ipairs(type(positions) == "table" and positions or EMPTY) do
    local x = type(pos) == "table" and tonumber(pos.x) or nil
    local y = type(pos) == "table" and tonumber(pos.y) or nil
    if x and y and type(pos.map) == "number" then
      local at = nil
      for index, zone in ipairs(list) do
        if zone.map == pos.map then
          at = index
          break
        end
      end
      if not at then
        list[#list + 1] = { areaId = -pos.map, name = pos.zone, map = pos.map, pins = {} }
        at = #list
      end
      local entry = list[at]
      entry.pins = entry.pins or {}
      if (entry.name == nil or entry.name == "") and type(pos.zone) == "string" then
        entry.name = pos.zone
      end
      local pin = { x = x, y = y, name = pos.name }
      if pos.spot then
        pin.spot = true
        pin.weak = pos.weak == true or nil
        pin.confirmed = pos.confirmed == true or nil
        pin.lines = Map.SpotLines(pos.name, entry.name, pin)
        spotted[at] = true
      end
      table.insert(entry.pins, 1, pin)
      if #entry.pins > (spotted[at] and Map.SPOT_CAP or Map.PIN_CAP) then
        table.remove(entry.pins)
      end
      selected = selected or at
    end
  end
  return list, selected
end

--- The lines under a vendor's map: whose position it is. The player's own reads as that; a
--- shipped one says it is a community note nobody has checked in game. withEra adds the Classic
--- Era line where the list also holds a name's Era pins. Pure.
---
--- Brief V1: a pin out of the client's own vendor tables (client true) says so, the tier's own
--- words, and stands beside the player's own pin rather than being replaced by it. The community
--- lines are said only where a pin is the curated tier's.
---
--- Brief PS3: one line says whose spot it is. The player's own record alone, or the player's own
--- beside the shipped player sourced spot, reads "Where you stood when you opened this vendor"; the
--- shipped spot alone reads "Where players stood when they opened this vendor". The row's tooltip
--- already says "Reported by players", so the map no longer says it again.
---
--- Brief PS5: a shipped spot of an npc that sells nothing (a quest giver, a trainer, a stable
--- master: its pins carry talked) reads "Where players stood when they talked to this NPC".
--
-- Brief NW1: where a pin is a hand kept spot of a creature found at one of several places, the map
-- says the words a world boss's map does ("Night Watch Guard appears at one of these places.") and
-- nothing else (the owner, 2026-10-20: "none of the text below the top line is necessary").
function Map.VendorNoteLines(positions, withEra)
  local seen, client, community, players, talked, approx = false, false, false, false, false, false
  local spotName = nil
  for _, pos in ipairs(type(positions) == "table" and positions or EMPTY) do
    if type(pos) == "table" and pos.spot and spotName == nil and type(pos.name) == "string" and pos.name ~= "" then
      spotName = pos.name
    end
    if type(pos) == "table" then
      if pos.seen then
        seen = true
      elseif pos.client then
        client = true
      elseif pos.approx then
        approx = true
      elseif pos.players then
        players = true
        talked = talked or pos.talked == true
      else
        community = true
      end
    end
  end
  local out = {}
  if client then
    out[#out + 1] = { text = L["From client data"], muted = true }
  end
  if seen then
    out[#out + 1] = { text = L["Where you stood when you opened this vendor"], muted = true }
  elseif players and talked then
    out[#out + 1] = { text = L["Where players stood when they talked to this NPC"], muted = true }
  elseif players then
    out[#out + 1] = { text = L["Where players stood when they opened this vendor"], muted = true }
  end
  -- Brief TR1c: a claim's approximate pin says so in one muted line, and on its own is no
  -- community note (no site, no badge: brief R14's approximate cells carry only their flag).
  if approx then
    out[#out + 1] = { text = L[Map.APPROXIMATE], muted = true }
  end
  if not seen and (community or not (client or players or approx)) then
    out[#out + 1] = { text = L["Community note"], muted = true }
    out[#out + 1] = { text = L["A position from community pages, not checked in game"], muted = true }
  end
  if withEra then
    out[#out + 1] = { text = L[Map.NOTE], muted = true }
  end
  if spotName then
    return { { text = string.format(L[Map.ONE_OF_THESE], spotName) } }
  end
  return out
end

--- Brief NW1: the lines a hand kept spot's pin says when hovered: that the creature appears at one
--- of these places (the words under a world boss's map, Map.ONE_OF_THESE), then the zone and the
--- pair, as every pin does. A spot with no name says the zone and the pair alone. Pure.
---
--- The owner's standing rule of 2026-10-20: a weak spot's pin (pin.weak, one unverified report) closes
--- on "Weak indicator".
---
--- Brief CS1 (the owner's ruling A of 2026-10-20): every spot's pin closes on its tier. A Confirmed one
--- (pin.confirmed, a player's recorded find backs it) on "Confirmed: a player found <name> here", a
--- weak one on "Weak indicator", and every other (two or more reports, no record) on "Reported by
--- players".
function Map.SpotLines(name, zone, pin)
  local lines = Map.TipLines(nil, zone, pin)
  local named = type(name) == "string" and name ~= ""
  if named then
    table.insert(lines, 1, string.format(L[Map.ONE_OF_THESE], name))
  end
  if type(pin) ~= "table" then
    return lines
  end
  if pin.confirmed and named then
    lines[#lines + 1] = string.format(L["Confirmed: a player found %s here"], name)
  elseif pin.confirmed then
    lines[#lines + 1] = L["Confirmed: a player found it here"]
  elseif pin.weak then
    lines[#lines + 1] = L["Weak indicator"]
  else
    lines[#lines + 1] = L["Reported by players"]
  end
  return lines
end

--------------------------------------------------------------------------------
-- Pure. A quest's own map (brief Q8)
--------------------------------------------------------------------------------

--- The words a quest's Map tab uses: the pin words, the lines under the map, and what the tab says
--- where nothing places the quest at all.
Map.QUEST_GIVER = "Given by: %s"
Map.QUEST_ENDER = "Turned in to: %s"
Map.QUEST_OBJECTIVE = "Quest objective"
Map.QUEST_STOOD = "Where you stood when the quest was given or handed in"
Map.QUEST_POI = "The objective's place, from your quest log"
Map.QUEST_NONE = "No places known for this quest yet"
Map.QUEST_HOW = "ItemTree records who gives it and where as you play"

--- Every place a quest's Map tab pins, as the list Map.DrawPlaces draws: the recorded giver's and
--- turn in's positions (where the player stood when each window opened) and the client's objective
--- mark while the quest is in the log. facts is Core/ViewModel.lua ViewModel.Quest's answer. One
--- entry per map, in the order giver, turn in, objective, each { areaId = -map, name, map, pins },
--- each pin { x, y, name, lines }. An empty list where nothing has a place. Pure.
---
--- Brief UX1: questName, where handed, is the quest's name for its pins' waypoint words where
--- facts carries no title.
---
--- Brief NW1: spotsOf(key), where handed, answers the hand kept spot pins of a giver's or a turn
--- in's npc key (Map.SpotPins): every spot of a creature found at one of several places is pinned,
--- once per creature, after the places above, past Map.PIN_CAP up to Map.SPOT_CAP, each pin
--- { x, y, name = the creature, spot = true, lines = Map.SpotLines }.
function Map.QuestPlaces(facts, spotsOf, questName)
  local list, byMap = {}, {}
  if type(facts) ~= "table" then
    return list
  end
  -- Brief UX1: what each pin's waypoint is for, "Marshal Dughan, turn in for Wanted: Hogger", where
  -- the quest's title is known (Map.WaypointFor reads it): the client's or the players' (facts.title),
  -- else questName, the quest's own name in our data (Map.QuestName).
  local quest = type(facts.title) == "string" and facts.title ~= "" and facts.title or nil
  if not quest and type(questName) == "string" and questName ~= "" then
    quest = questName
  end
  local function waypointWords(side, name)
    if not quest then
      return nil
    end
    if side == "poi" then
      return string.format(L["Objective for %s"], quest)
    end
    if type(name) ~= "string" or name == "" then
      return nil
    end
    if side == "giver" then
      return string.format(L["%s, gives %s"], name, quest)
    end
    return string.format(L["%s, turn in for %s"], name, quest)
  end
  local function place(mapId, zone, x, y, title, spot, weak, confirmed, waypointFor)
    x, y = tonumber(x), tonumber(y)
    if type(mapId) ~= "number" or not x or not y then
      return
    end
    local entry = byMap[mapId]
    if not entry then
      entry = { areaId = -mapId, map = mapId, pins = {} }
      byMap[mapId] = entry
      list[#list + 1] = entry
    end
    if (entry.name == nil or entry.name == "") and type(zone) == "string" and zone ~= "" then
      entry.name = zone
    end
    local pin = { x = x, y = y, name = title, spot = spot, weak = weak, confirmed = confirmed }
    pin.lines = Map.TipLines(title, entry.name, pin)
    pin.waypointFor = waypointFor
    if #entry.pins < (spot and Map.SPOT_CAP or Map.PIN_CAP) then
      entry.pins[#entry.pins + 1] = pin
    end
  end
  local sides = {
    { facts.givers, Map.QUEST_GIVER, L["Given by"], "giver" },
    { facts.enders, Map.QUEST_ENDER, L["Turned in to"], "ender" },
  }
  for _, side in ipairs(sides) do
    for _, npc in ipairs(type(side[1]) == "table" and side[1] or EMPTY) do
      if type(npc) == "table" then
        local title = side[3]
        if type(npc.name) == "string" and npc.name ~= "" then
          title = string.format(L[side[2]], npc.name)
        end
        place(npc.mapId, npc.zone, npc.x, npc.y, title, nil, nil, nil, waypointWords(side[4], npc.name))
      end
    end
  end
  local poi = type(facts.poi) == "table" and facts.poi or nil
  if poi then
    place(poi.mapId, poi.zone or facts.zone, poi.x, poi.y, L[Map.QUEST_OBJECTIVE], nil, nil, nil, waypointWords("poi"))
  end
  if type(spotsOf) == "function" then
    local done = {}
    for _, side in ipairs(sides) do
      for _, npc in ipairs(type(side[1]) == "table" and side[1] or EMPTY) do
        local key = type(npc) == "table" and npc.key or nil
        if type(key) == "string" and not done[key] then
          done[key] = true
          local ok, spots = pcall(spotsOf, key)
          for _, spot in ipairs(ok and type(spots) == "table" and spots or EMPTY) do
            if type(spot) == "table" then
              place(
                spot.map,
                spot.zone,
                spot.x,
                spot.y,
                spot.name or npc.name,
                true,
                spot.weak == true or nil,
                spot.confirmed == true or nil,
                waypointWords(side[4], spot.name or npc.name)
              )
            end
          end
        end
      end
    end
  end
  for _, entry in ipairs(list) do
    if (entry.name == nil or entry.name == "") and entry.map == facts.mapId then
      entry.name = facts.zone
    end
    -- A pin's second line is the zone, which the first pin of a map may have named before it.
    for _, pin in ipairs(entry.pins) do
      if pin.spot then
        pin.lines = Map.SpotLines(pin.name, entry.name, pin)
      else
        pin.lines = Map.TipLines(pin.name, entry.name, pin)
      end
    end
  end
  return list
end

--- The lines under a quest's map: whose positions the pins are. Pure.
---
--- Brief NW1: places is Map.QuestPlaces' answer, where handed: where a hand kept spot is among its
--- pins the map says "<creature> appears at one of these places." and nothing else (the owner,
--- 2026-10-20: "none of the text below the top line is necessary").
function Map.QuestNoteLines(facts, places)
  local out = {}
  if type(facts) ~= "table" then
    return out
  end
  local stood, players, approx = false, false, false
  for _, list in ipairs({ facts.givers, facts.enders }) do
    for _, npc in ipairs(type(list) == "table" and list or EMPTY) do
      if type(npc) == "table" and type(npc.mapId) == "number" and tonumber(npc.x) and tonumber(npc.y) then
        -- Brief GF5: a predicted giver's approximate pin says so, as a trainer's does.
        if npc.approx == true then
          approx = true
        elseif npc.players == true then
          players = true
        else
          stood = true
        end
      end
    end
  end
  if stood then
    out[#out + 1] = { text = L[Map.QUEST_STOOD], muted = true }
  elseif players then
    -- Brief PS5: a giver or turn in the shipped player module places, where none of the player's
    -- own records does.
    out[#out + 1] = { text = L["Where players stood when the quest was given or handed in"], muted = true }
  end
  if approx then
    out[#out + 1] = { text = L[Map.APPROXIMATE], muted = true }
  end
  if type(facts.poi) == "table" then
    out[#out + 1] = { text = L[Map.QUEST_POI], muted = true }
  end
  local spotName = nil
  for _, place in ipairs(type(places) == "table" and places or EMPTY) do
    for _, pin in ipairs(type(place) == "table" and type(place.pins) == "table" and place.pins or EMPTY) do
      if spotName == nil and type(pin) == "table" and pin.spot and type(pin.name) == "string" and pin.name ~= "" then
        spotName = pin.name
      end
    end
  end
  if spotName then
    return { { text = string.format(L[Map.ONE_OF_THESE], spotName) } }
  end
  return out
end

--- What a quest's Map tab says where nothing places the quest: the quest's own words. Pure.
function Map.QuestEmptyLines()
  return {
    { text = L[Map.QUEST_NONE], heading = true },
    { text = L[Map.QUEST_HOW], muted = true },
  }
end

--------------------------------------------------------------------------------
-- Pure. An instance's entrance and a pin's waypoint (brief M7)
--------------------------------------------------------------------------------

local function foldName(text)
  if type(text) ~= "string" then
    return nil
  end
  local folded = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if folded == "" then
    return nil
  end
  return folded
end

--- One position as a pair of percentages, out of whatever the client hands back for one: a
--- Vector2DMixin (GetXY), or a plain { x, y }, each in 0 to 1. nil where it is neither, or off the
--- map.
function Map.PositionPercent(position)
  if type(position) ~= "table" then
    return nil
  end
  local x, y = nil, nil
  if type(position.GetXY) == "function" then
    local ok, px, py = pcall(position.GetXY, position)
    if ok then
      x, y = tonumber(px), tonumber(py)
    end
  end
  if x == nil or y == nil then
    x, y = tonumber(position.x), tonumber(position.y)
  end
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return { x = x * 100, y = y * 100 }
end

--- The one entrance of the client's list (C_EncounterJournal.GetDungeonEntrancesForMap, a list of
--- DungeonEntranceMapInfo: name, position and more) whose name is one of the instance's names,
--- as { x, y } in percent, or nil. A zone with three entrances (The Barrens) is matched by name and
--- never by being the only one. Pure.
function Map.MatchEntrance(list, names)
  if type(list) ~= "table" or type(names) ~= "table" then
    return nil
  end
  local wanted = {}
  for _, name in ipairs(names) do
    local folded = foldName(name)
    if folded then
      wanted[folded] = true
    end
  end
  for _, info in ipairs(list) do
    local folded = type(info) == "table" and foldName(info.name) or nil
    if folded and wanted[folded] then
      local at = Map.PositionPercent(info.position)
      if at then
        return at
      end
    end
  end
  return nil
end

--- THE PLACES AN INSTANCE'S OWN MAP DRAWS, in the shape Map.DrawPlaces takes, and the lines under
--- the map: the entrance zone's map headed "Wailing Caverns entrance, The Barrens", with one
--- Entrance pin where the client names the entrance (client, { x, y } in percent), or failing that
--- where the data ships the outdoor mouth from the game's own tables (entrance.shipped.mouth, brief
--- M8). The instance portal the data ships on the same map (entrance.shipped.portal) is a second
--- pin beside it, labelled "Instance portal" and wearing the portal icon. With neither the client's
--- entrance nor either shipped point, the pin stands where Classic Era places one of the instance's
--- own creatures in that zone (entrance.near), or there is no pin and the line that says the
--- entrance's place is not known. With Map.SHOW_INSIDE_MAPS on,
--- the instance itself follows as a second place, which the zone strip then offers. Pure.
---
---   entrance  Core/ViewModel.lua ViewModel.InstanceEntrance's answer
---   client    the client's own entrance position, or nil
function Map.EntrancePlaces(entrance, client)
  if type(entrance) ~= "table" or type(entrance.map) ~= "number" then
    return nil
  end
  local instance = type(entrance.instance) == "string" and entrance.instance or ""
  local zoneName = type(entrance.zoneName) == "string" and entrance.zoneName or ""
  local place = {
    areaId = tonumber(entrance.zoneArea) or -entrance.map,
    name = string.format(L[Map.ENTRANCE_HEADING], instance, zoneName),
    map = entrance.map,
    pins = {},
  }
  local notes = EMPTY
  local near = type(entrance.near) == "table" and entrance.near[1] or nil
  local shipped = type(entrance.shipped) == "table" and entrance.shipped or EMPTY
  local function placed(at)
    return type(at) == "table" and tonumber(at.x) ~= nil and tonumber(at.y) ~= nil
  end
  local function factPin(at, label)
    local pin = { x = tonumber(at.x), y = tonumber(at.y), name = L[label] }
    pin.lines = { L[label], instance }
    if zoneName ~= "" then
      pin.lines[#pin.lines + 1] = zoneName
    end
    pin.lines[#pin.lines + 1] = Map.PinText(pin)
    return pin
  end
  local fromClient = placed(client)
  local mouth = fromClient and client or (placed(shipped.mouth) and shipped.mouth or nil)
  local portal = placed(shipped.portal) and shipped.portal or nil
  if mouth or portal then
    notes = {}
    if mouth then
      place.pins[#place.pins + 1] = factPin(mouth, Map.ENTRANCE)
    end
    if portal then
      local pin = factPin(portal, Map.ENTRANCE_PORTAL)
      pin.icon = Map.PORTAL_KEY
      place.pins[#place.pins + 1] = pin
    end
    if fromClient then
      notes[#notes + 1] = { text = L[Map.ENTRANCE_CLIENT], muted = true }
    end
    if portal then
      notes[#notes + 1] = { text = L[Map.PORTAL_NOTE], muted = true }
    end
  elseif type(near) == "table" and tonumber(near.x) and tonumber(near.y) then
    local pin = { x = tonumber(near.x), y = tonumber(near.y), name = L[Map.ENTRANCE] }
    pin.lines = { L[Map.ENTRANCE], instance }
    if type(near.name) == "string" and near.name ~= "" then
      pin.lines[#pin.lines + 1] = string.format(L[Map.ENTRANCE_NEAR], near.name)
    end
    pin.lines[#pin.lines + 1] = Map.PinText(pin)
    pin.lines[#pin.lines + 1] = Map.PredictedWord()
    place.pins[1] = pin
    notes = Map.NoteLines()
  else
    place.hint = L[Map.ENTRANCE_UNKNOWN]
  end
  local places = { place }
  if Map.SHOW_INSIDE_MAPS then
    places[2] = { areaId = tonumber(entrance.areaId), name = instance, pins = {} }
  end
  return places, notes
end

--- Brief M8 (owner addition): THE PLACES A WORLD BOSS'S OWN MAP DRAWS, in the shape Map.DrawPlaces
--- takes, and which one opens: each zone Classic Era places the boss in (list, Map.Zones' answer:
--- { areaId, name, map, pins }) headed "Azuregos spawn point, Azshara" (or "spawn points" for
--- several), each pin labelled "Spawn point" with the boss's name in its tooltip, the fullest zone
--- opening. Where Classic Era places the boss nowhere on a map, the first of the boss's own zones
--- (boss.maps, { areaId, name, map }) that has a map, with no pin and the line that says where it
--- spawns is not known. nil where there is neither, and the creature's map is drawn as before.
--- Pure.
---
--- Brief M11: a zone the boss walks a patrol path in (zone.paths, out of Map.Merge) is a place too,
--- with its paths, headed "Maws patrol, Azshara" where it has no spawn point and with the spawn
--- heading where it has both. Brief M13: a small path's own pins (Map.PathPins) go in place.pathPins,
--- which the draw puts on after the spawn pins.
---
---   boss  Core/ViewModel.lua ViewModel.WorldBoss's answer: { name, zones, maps, shared }
function Map.WorldBossPlaces(boss, list)
  if type(boss) ~= "table" then
    return nil
  end
  local name = type(boss.name) == "string" and boss.name or ""
  local places, best, most = {}, 1, 0
  for _, zone in ipairs(type(list) == "table" and list or EMPTY) do
    local pins = type(zone) == "table" and type(zone.pins) == "table" and zone.pins or EMPTY
    local paths = type(zone) == "table" and type(zone.paths) == "table" and zone.paths or EMPTY
    if (#pins > 0 or #paths > 0) and type(zone.map) == "number" then
      local zoneName = Map.ZoneText(zone)
      local heading = Map.PATROL_HEADING
      if #pins == 1 then
        heading = Map.SPAWN_HEADING
      elseif #pins > 1 then
        heading = Map.SPAWNS_HEADING
      end
      local place = {
        areaId = zone.areaId,
        map = zone.map,
        name = string.format(L[heading], name, zoneName),
        stripName = zoneName,
        pins = {},
      }
      if #paths > 0 then
        place.paths = paths
      end
      for index, pin in ipairs(pins) do
        local copy = { x = pin.x, y = pin.y, name = L[Map.SPAWN], kept = pin.kept }
        copy.lines = { L[Map.SPAWN] }
        for _, text in ipairs({ name, zoneName, Map.PinText(copy) }) do
          if text ~= "" then
            copy.lines[#copy.lines + 1] = text
          end
        end
        place.pins[index] = copy
      end
      -- Brief M13: a small path is a fleck at map scale, so it gets a pin of its own, held apart
      -- from the spawn pins so the heading, the strip's count and the words stay the spawn points'.
      if #paths > 0 then
        local pathPins = Map.PathPins(paths, place.pins, name, zoneName)
        if #pathPins > 0 then
          place.pathPins = pathPins
        end
      end
      places[#places + 1] = place
      if #pins > most then
        best, most = #places, #pins
      end
    end
  end
  if #places > 0 then
    -- The fullest zone first, so it is the one Map.DrawPlaces opens on.
    if best ~= 1 then
      table.insert(places, 1, table.remove(places, best))
    end
    return places
  end
  for _, zone in ipairs(type(boss.maps) == "table" and boss.maps or EMPTY) do
    if type(zone) == "table" and type(zone.map) == "number" then
      local zoneName = type(zone.name) == "string" and zone.name or ""
      return {
        {
          areaId = tonumber(zone.areaId) or -zone.map,
          map = zone.map,
          name = string.format(L[Map.SPAWN_HEADING], name, zoneName),
          stripName = zoneName,
          pins = {},
          hint = L[Map.SPAWN_UNKNOWN],
        },
      }
    end
  end
  return nil
end

--- Brief M11: the lines under a world boss's map. Where its place is shared (boss.shared, the Boss
--- loot index's po) or any pin of its places is a hand kept spot (kept), the plain line that it
--- appears at one of these places leads; the Predicted wording and its line follow as on every
--- map. Nothing here says where a place came from. Pure.
function Map.WorldBossNotes(boss, places)
  local notes = Map.NoteLines()
  if type(boss) ~= "table" then
    return notes
  end
  local oneOf = boss.shared == true
  for _, place in ipairs(type(places) == "table" and places or EMPTY) do
    for _, pin in ipairs(type(place) == "table" and type(place.pins) == "table" and place.pins or EMPTY) do
      if type(pin) == "table" and pin.kept == true then
        oneOf = true
      end
    end
  end
  local name = type(boss.name) == "string" and boss.name or ""
  if not oneOf or name == "" then
    return notes
  end
  table.insert(notes, 1, { text = string.format(L[Map.ONE_OF_THESE], name) })
  return notes
end

--- The point the client's waypoint call takes for one pin of a zone map: the map id and the pin's
--- place in 0 to 1. nil for no map or a pin off the map. Pure.
function Map.WaypointAt(uiMapId, pin)
  if type(uiMapId) ~= "number" or type(pin) ~= "table" then
    return nil
  end
  local x, y = tonumber(pin.x), tonumber(pin.y)
  if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
    return nil
  end
  return { map = uiMapId, x = x / 100, y = y / 100 }
end

-- Brief UX1: the pin names that say what kind of place a pin is and not whose, which the toast
-- follows with the name they belong to.
local KIND_PINS = { Map.SPAWN, Map.ENTRANCE, Map.ENTRANCE_PORTAL, Map.PATH_PIN }

--- Brief UX1 (QA item 402): what a waypoint set on one pin is for, the words the "Waypoint added"
--- toast says under its title (UI/Toast.lua): the pin's own words where it carries them
--- (pin.waypointFor, a quest's NPCs, Map.QuestPlaces), else its name, else the creature the map is
--- for ("Hogger", "Copper Vein"). A pin named for its kind of place (a spawn point, an entrance, an
--- instance portal, a patrol path) adds the first of its hover lines that names whose it is:
--- "Spawn point, Azuregos", "Entrance, The Deadmines". Never the coordinates. nil for nothing to
--- say. Pure.
function Map.WaypointFor(pin, creature)
  pin = type(pin) == "table" and pin or EMPTY
  if type(pin.waypointFor) == "string" and pin.waypointFor ~= "" then
    return pin.waypointFor
  end
  local name = type(pin.name) == "string" and pin.name ~= "" and pin.name or nil
  if not name and type(creature) == "string" and creature ~= "" then
    name = creature
  end
  if not name then
    return nil
  end
  local kind = false
  for _, key in ipairs(KIND_PINS) do
    if name == L[key] then
      kind = true
    end
  end
  if not kind then
    return name
  end
  local coords = Map.PinText(pin)
  for _, line in ipairs(type(pin.lines) == "table" and pin.lines or EMPTY) do
    if type(line) == "string" and line ~= "" and line ~= name and line ~= coords then
      return name .. ", " .. line
    end
  end
  return name
end

--------------------------------------------------------------------------------
-- Pure. Where the player is (brief MP1)
--------------------------------------------------------------------------------

--- How big the player's arrow is drawn on a map this wide: the world map's own share of its
--- canvas (Map.PLAYER_WORLD_SIZE over Map.PLAYER_WORLD_CANVAS), rounded, clamped at both ends.
function Map.PlayerSize(width)
  local drawn = math.floor((tonumber(width) or 0) * Map.PLAYER_WORLD_SIZE / Map.PLAYER_WORLD_CANVAS + 0.5)
  if drawn < Map.PLAYER_MIN then
    return Map.PLAYER_MIN
  end
  if drawn > Map.PLAYER_MAX then
    return Map.PLAYER_MAX
  end
  return drawn
end

--- How big the dot is drawn where there is no facing: a share of the arrow, never a speck.
function Map.PlayerDotSize(width)
  local drawn = math.floor(Map.PlayerSize(width) * Map.PLAYER_DOT_SHARE + 0.5)
  if drawn < Map.PLAYER_DOT_MIN then
    return Map.PLAYER_DOT_MIN
  end
  return drawn
end

--- The player's place on a map out of the two numbers the client answers (0 to 1, x west to east
--- and y north to south), or nil: no answer, an answer that is not two numbers, a place off this
--- map, or (0, 0), which is what the client answers where it cannot place the player at all
--- (Core/Nearest.lua reads it the same way).
function Map.PlayerSpot(x, y)
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then
    return nil
  end
  if x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then
    return nil
  end
  return x, y
end

--- A place on a child map as a place on its parent, through the child's rectangle on the parent
--- (C_Map.GetMapRectOnMap's minX, maxX, minY, maxY, each 0 to 1 of the parent), or nil where the
--- rectangle is not one or the place falls off the parent.
function Map.RectSpot(rect, x, y)
  if type(rect) ~= "table" or type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  local minX, maxX, minY, maxY = rect.minX, rect.maxX, rect.minY, rect.maxY
  if type(minX) ~= "number" or type(maxX) ~= "number" or type(minY) ~= "number" or type(maxY) ~= "number" then
    return nil
  end
  if maxX <= minX or maxY <= minY then
    return nil
  end
  return Map.PlayerSpot(minX + x * (maxX - minX), minY + y * (maxY - minY))
end

--- What the marker wears for one facing (GetPlayerFacing: radians, 0 is north, turning
--- anticlockwise, which is the way SetRotation turns a texture): the arrow turned by it, or the
--- unturned dot where there is no facing to show.
function Map.PlayerFace(facing)
  if type(facing) == "number" and facing == facing and facing ~= math.huge and facing ~= -math.huge then
    return Map.PLAYER_ARROW_KEY, facing
  end
  return Map.PLAYER_DOT_KEY, 0
end

--- Where the marker's centre sits inside the drawn map, as an offset from its TOP LEFT, for a
--- place in 0 to 1: x to the right and y downwards, which is a negative offset in this API.
function Map.PlayerOffset(x, y, width, height)
  return x * (tonumber(width) or 0), -(y * (tonumber(height) or 0))
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

--- Whether the art has been given up on for this session. Set by the first C_Map call that is
--- missing, raises, describes a layer that cannot be laid out or hands back no tiles, and never
--- cleared: an unproven client is asked once and then left alone. Map.artReason says which.
Map.artBlocked = false
Map.artReason = nil

local globalFn = ItemTree.Util.GlobalFn

-- Brief E91: the list's keyboard, which is combat safe. SetPropagateKeyboardInput is refused in
-- combat lockdown on the Forever client, so the list never decides propagation then: it takes the
-- keyboard only out of combat, with propagation on, lets it go on PLAYER_REGEN_DISABLED (before
-- the lockdown, through UI/Frame.lua's Frame.OnCombatStart) and takes it back as combat ends. In
-- combat Escape therefore reaches the client's CloseSpecialWindows and closes the window.
local function inCombat()
  local lockdown = globalFn("InCombatLockdown")
  if not lockdown then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

local function menuPropagate(menu, on)
  if inCombat() or type(menu) ~= "table" or type(menu.SetPropagateKeyboardInput) ~= "function" then
    return false
  end
  return (pcall(menu.SetPropagateKeyboardInput, menu, on))
end

local function menuKeyboard(menu, on)
  if type(menu) == "table" and type(menu.EnableKeyboard) == "function" then
    pcall(menu.EnableKeyboard, menu, on)
  end
end

-- Takes the keyboard for a list going up, out of combat only. Answers whether it holds it.
local function takeMenuKeyboard(menu)
  if inCombat() then
    menuKeyboard(menu, false)
    return false
  end
  menuPropagate(menu, true)
  menuKeyboard(menu, true)
  return true
end

-- One interface cue, by name. UI/Sound.lua owns which sound a cue is and whether cues are on at
-- all; this is the one line a call site writes, and it is looked up at call time so a spec that
-- loads this file on its own costs the cue and nothing else. Same shape as UI/Chain.lua.
local playCue = ItemTree.UI.Sound.PlayCue

-- True when the frame admits to a script type. A client that has dropped one raises when it is
-- given a handler, so nothing is set without asking first, and a frame with no HasScript at all
-- is taken at its word.
local function hasScript(frame, script)
  if type(frame) ~= "table" or type(frame.HasScript) ~= "function" then
    return type(frame) == "table"
  end
  local ok, has = pcall(frame.HasScript, frame, script)
  if ok and has then
    return true
  end
  return false
end

local function setScript(frame, script, handler)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" or not hasScript(frame, script) then
    return false
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

-- Which presses a button answers, in the modern shape first and the classic one after, each
-- pcall'd, the way every other two signature call in this addon is tried. Answers the shape that
-- took, or nil where the client would take neither, so a spec can read what was asked for.
local function registerClicks(frame, modern, classic)
  if type(frame) ~= "table" or type(frame.RegisterForClicks) ~= "function" then
    return nil
  end
  if pcall(frame.RegisterForClicks, frame, unpack(modern)) then
    return modern
  end
  if classic and pcall(frame.RegisterForClicks, frame, unpack(classic)) then
    return classic
  end
  return nil
end

local function setStrata(frame, strata)
  if type(frame) ~= "table" or type(frame.SetFrameStrata) ~= "function" then
    return false
  end
  return (pcall(frame.SetFrameStrata, frame, strata))
end

-- A number the client answers with, or nil.
local function number(frame, method)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  if not ok then
    return nil
  end
  return tonumber(value)
end

local function treeModule()
  local ui = ItemTree.UI
  local tree = type(ui) == "table" and ui.Tree or nil
  return type(tree) == "table" and tree or nil
end

local function eraModule()
  local era = ItemTree.eraSources
  return type(era) == "table" and era or nil
end

--- One C_Map call. Answers false where the client does not carry it and where it raised, which
--- are the two things that give the art up for the session.
local function mapCall(name, ...)
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" then
    return false, nil
  end
  local fn = api[name]
  if type(fn) ~= "function" then
    return false, nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    return false, nil
  end
  return true, value
end

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

local function tint(region, key, alpha)
  local colour = key and Theme.ColorTable(key) or nil
  if not colour or type(region) ~= "table" or type(region.SetVertexColor) ~= "function" then
    return false
  end
  region:SetVertexColor(colour.r, colour.g, colour.b)
  if type(region.SetAlpha) == "function" then
    region:SetAlpha(alpha or colour.a or 1)
  end
  return true
end

local function textColor(fontString, key)
  local colour = key and Theme.ColorTable(key) or nil
  if not colour or type(fontString) ~= "table" or type(fontString.SetTextColor) ~= "function" then
    return false
  end
  fontString:SetTextColor(colour.r, colour.g, colour.b, colour.a or 1)
  return true
end

--- Font safety, the same shape UI/Sidebar.lua and UI/Tree.lua use: a FontString made with the two
--- argument CreateFontString has no font, SetFont ANSWERS false rather than raising when the face
--- is missing, and the next SetText raises "Font not set" inside the client. So the template is
--- asked for first, the answer of every SetFont is read, and a client font object is put back
--- whenever the string has none.
Map.FONT_TEMPLATE = "GameFontNormalSmall"
Map.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontNormal" }

local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Map.FONT_FALLBACKS) do
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

local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, Map.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

local function setFont(fontString, size, face)
  if type(fontString) ~= "table" then
    return false
  end
  if type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face or Theme.fonts.ITEMTREE_FONT_BODY, size, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  if type(fontString.SetShadowOffset) == "function" then
    local outline = Theme.text.ITEMTREE_TEXT_OUTLINE
    pcall(fontString.SetShadowOffset, fontString, outline.x, outline.y)
    pcall(fontString.SetShadowColor, fontString, outline.r, outline.g, outline.b, outline.a)
  end
  return true
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

--- One line of the block, wrapped inside the width it is given and centred, exactly as the pane's
--- own empty state writes its lines.
local function writeLine(fontString, width, line, size)
  if type(fontString) ~= "table" or type(line) ~= "table" then
    return false
  end
  local colour = Map.COLOR_BODY
  local face = nil
  if line.heading then
    colour, face = Map.COLOR_TITLE, Theme.fonts.ITEMTREE_FONT_TITLE
  elseif line.muted then
    colour = Map.COLOR_MUTED
  end
  setFont(fontString, size, face)
  textColor(fontString, colour)
  if type(fontString.SetWidth) == "function" then
    fontString:SetWidth(width)
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH("CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, true)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 0)
  end
  setText(fontString, line.text)
  if type(fontString.Show) == "function" then
    fontString:Show()
  end
  return true
end

--------------------------------------------------------------------------------
-- Brief M12: the map follows the window's size
--
-- WHY IT OVERFLOWED: the map was laid out once, when the tab was drawn, from the pane's height at
-- that moment: the canvas was given a fixed size and the note lines a fixed offset from the pane's
-- top. Nothing drew it again when the window was dragged shorter (the window's own OnSizeChanged
-- hook refits the title band and nothing else), so the pane shrank under a map of the old size,
-- and the map and its notes hung out past the window's bottom edge. The lists on every other tab
-- are anchored to their pane and scroll, which is why only this tab showed it. No scroll frame and
-- no search list row count is involved: the Map pane has neither.
--
-- The fix is the root one: the pane is watched for a change of size and the tab is drawn again with
-- exactly what it was last handed, so the map is fitted to the pane as it is now.
--------------------------------------------------------------------------------

--- Draws the tab again with exactly what it was last handed, in the pane's size as it is now.
function Map.Redraw()
  local last = Map.last
  if type(last) ~= "table" or last.region == nil then
    return false
  end
  if last.places then
    local ok, drawn = pcall(Map.DrawPlaces, last.region, last.places, last.notes)
    return ok and drawn ~= false
  end
  local ok, drawn = pcall(Map.Draw, last.region, last.nameIndex, last.zones)
  return ok and drawn ~= false
end

--- The pane's OnSizeChanged: draws the tab again when the pane the map is up in has changed size,
--- and does nothing for a pane the map is not showing in (Map.Clear lets go of it) or a size it
--- was already drawn at.
function Map.Resized(region)
  if region == nil or Map.live ~= region then
    return false
  end
  local width, height = Map.Box(region)
  local drawn = Map.drawnSize
  if type(drawn) == "table" and drawn.width == width and drawn.height == height then
    return false
  end
  return Map.Redraw()
end

local function onRegionSized(region)
  Map.Resized(region)
end

--- Listens for the pane's change of size, once per pane. The pane is this addon's own frame (the
--- window's map region, UI/Frame.lua), and the listener is hooked rather than set, so a handler the
--- window puts there still runs. A frame that will not take a hook is left alone: the map then keeps
--- the size it was drawn at, as it always did.
local function watchSize(region)
  Map.watched = Map.watched or setmetatable({}, { __mode = "k" })
  if Map.watched[region] then
    return true
  end
  if not hasScript(region, "OnSizeChanged") or type(region.HookScript) ~= "function" then
    return false
  end
  local hooked = pcall(region.HookScript, region, "OnSizeChanged", onRegionSized)
  Map.watched[region] = hooked or nil
  return hooked
end

--------------------------------------------------------------------------------
-- The frames, built once and reused
--------------------------------------------------------------------------------

--- Everything the painter draws hangs off one record, held against the region it was built in: the
--- window rebuilding its regions hands over a different frame and this builds again rather than
--- drawing into something that is no longer on screen.
---
---   viewport  the map's window in the region, the size the layout fitted the art to (brief UX2)
---   canvas    the map itself, inside the viewport: the drawn art at the zoom in force, moved to pan
---   tiles     the art, one texture per tile of the layer's grid
---   explored  the explored areas over the art, one texture per overlay tile (brief MX1)
---   pins      one small frame per pin, each with its own texture, hovering for its tooltip
---   lines     the pieces of the patrol paths drawn on the map, and dots their first points (M11)
---   buttons   the zone buttons above the map, one per zone, where they fit on one row
---   dropdown  the one control that replaces them where they do not (brief E62)
---   menu      the dropdown's list, its rows and the screen wide catcher under it
---   ruler     a hidden font string, asked how wide a zone name is before the strip is decided
---   above     the caption lines over the map
---   below     the Predicted wording and the provenance line under it
---   centre    the block a zone with no map draws instead of art
---   zoomBar   the chain tab's zoom bar over the map's top right corner, made the first time a map
---             can zoom (brief UX2)
---
--- Brief UX2: the viewport's handlers, a pin's press and the drag's end, defined with the zoom further
--- down.
local onViewportMouseDown, onViewportMouseUp, onViewportWheel, onPinMouseDown, stopDrag

local function onViewportHide()
  stopDrag()
end

local function build(region)
  if Map.parts and Map.parts.region == region then
    return Map.parts
  end
  if type(region) ~= "table" then
    return nil
  end
  -- The window handed over a different frame, so everything the last one holds is taken down
  -- before it is let go of: an open list hanging off a region nothing draws in any more would
  -- otherwise be left on the screen with nothing able to close it.
  if Map.parts then
    Map.Clear()
  end
  -- A region drawn into before keeps its frames: the creature page's map and a guessed place's
  -- map (Map.DrawPlaces) take turns, and a frame once made can never be freed.
  local held = Map.partsByRegion and Map.partsByRegion[region]
  if held then
    Map.parts = held
    return held
  end
  -- Brief UX2: the map's own window onto the canvas. The canvas is its child, sized to the map at the
  -- zoom in force and moved under it to pan, and the viewport clips it while zoomed in, so a zoomed
  -- map never spills over the words and the strip round it. At 1x the two are one rectangle and
  -- nothing is clipped, so a pin on the map's very edge still stands over it as it always did.
  local viewport = newFrame("Frame", region)
  if not viewport then
    return nil
  end
  local canvas = newFrame("Frame", viewport)
  if not canvas then
    return nil
  end
  local parts = {
    region = region,
    viewport = viewport,
    canvas = canvas,
    tiles = {},
    explored = {},
    pins = {},
    lines = {},
    dots = {},
    buttons = {},
    menuRows = {},
    above = {},
    below = {},
    centre = {},
    zoomables = {},
  }
  if type(viewport.SetPoint) == "function" then
    viewport:SetPoint("CENTER", region, "CENTER", 0, 0)
  end
  if type(canvas.SetPoint) == "function" then
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
  end
  -- A client that will not clip keeps the map at 1x: a zoomed canvas it cannot clip would be drawn
  -- over the whole pane.
  parts.clips = type(viewport.SetClipsChildren) == "function" and pcall(viewport.SetClipsChildren, viewport, false)
    or false
  -- The press, the release and the wheel start out off: they are turned on where the map can zoom
  -- (applyView), so a map that cannot lets every press through exactly as it did before.
  if type(viewport.EnableMouse) == "function" then
    pcall(viewport.EnableMouse, viewport, false)
  end
  if type(viewport.EnableMouseWheel) == "function" then
    pcall(viewport.EnableMouseWheel, viewport, false)
  end
  setScript(viewport, "OnMouseDown", onViewportMouseDown)
  setScript(viewport, "OnMouseUp", onViewportMouseUp)
  setScript(viewport, "OnMouseWheel", onViewportWheel)
  setScript(viewport, "OnHide", onViewportHide)
  canvas:Hide()
  viewport:Hide()
  -- The tape measure: one hidden font string at the size the strip draws, asked how wide a zone
  -- name is before the row of buttons is sized or given up on. UI/Chain.lua carries the same one.
  parts.ruler = newFontString(region, "OVERLAY")
  if parts.ruler then
    setFont(parts.ruler, Map.FONT_SM)
    if type(parts.ruler.Hide) == "function" then
      parts.ruler:Hide()
    end
  end
  Map.parts = parts
  Map.partsByRegion = Map.partsByRegion or setmetatable({}, { __mode = "k" })
  Map.partsByRegion[region] = parts
  watchSize(region)
  return parts
end

local function pooled(pool, make)
  return function(index)
    local held = pool[index]
    if held then
      return held
    end
    held = make(index)
    if held then
      pool[index] = held
    end
    return held
  end
end

local function hideFrom(pool, first)
  for index = first, #pool do
    local held = pool[index]
    if type(held) == "table" and type(held.Hide) == "function" then
      held:Hide()
    end
  end
end

--- The tooltip a hovered pin raises, in its own words: the creature, the place, and the pair.
local function showPinTooltip(frame)
  local tooltip = rawget(_G, "GameTooltip")
  local lines = rawget(frame, "itemTreeLines")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  if type(lines) ~= "table" or #lines == 0 or type(tooltip.AddLine) ~= "function" then
    return false
  end
  -- Brief UX2: a map being dragged raises no pin's tooltip as the pins slide under the pointer.
  if type(Map.drag) == "table" and Map.drag.moved then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  local colour = Theme.ColorTable(Map.COLOR_MUTED)
  for index, text in ipairs(lines) do
    if index == 1 then
      tooltip:AddLine(text)
    else
      tooltip:AddLine(text, colour and colour.r, colour and colour.g, colour and colour.b)
    end
  end
  -- Brief M7: a pin a left click sets the client's waypoint at says so, last.
  if type(rawget(frame, "itemTreeWaypoint")) == "table" then
    tooltip:AddLine(L[Map.WAYPOINT_HINT], colour and colour.r, colour and colour.g, colour and colour.b)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

--- Brief M8: puts the face one pin wears on it, the standard pin or another Assets key (the
--- instance portal's icon), falling back to the standard pin where the client will not draw the
--- other. Answers the key it wears.
local function pinFace(frame, key)
  local art = rawget(frame, "itemTreeArt")
  key = key or Map.PIN_KEY
  if type(art) ~= "table" or rawget(frame, "itemTreeFace") == key then
    return key
  end
  local applied, drew = pcall(Assets.Apply, art, key)
  if not (applied and drew) and key ~= Map.PIN_KEY then
    key = Map.PIN_KEY
    pcall(Assets.Apply, art, key)
  end
  frame.itemTreeFace = key
  return key
end

local function hidePinTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
  return true
end

--- Brief M7: a left press released on a pin that carries a waypoint sets the client's waypoint
--- there. Any other button does what it did before, which is nothing. Brief UX2: a press that
--- travelled Map.DRAG_THRESHOLD or more before the release panned the map, and sets nothing.
local function onPinMouseUp(frame, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  if stopDrag() then
    return false
  end
  local at = rawget(frame, "itemTreeWaypoint")
  if type(at) ~= "table" then
    return false
  end
  -- Brief UX1: and the toast says what the pin is for.
  return Map.SetWaypoint(at.map, at.x, at.y, rawget(frame, "itemTreeWaypointFor"))
end

--- Brief M7: whether a pin takes a click, which is only while it carries a waypoint; otherwise a
--- press passes through it, as it always did.
local function pinClicks(frame, on)
  if type(frame.SetMouseClickEnabled) == "function" then
    pcall(frame.SetMouseClickEnabled, frame, on and true or false)
  end
end

--- Brief M10: one piece of the marker, a texture of the plain white fill in the pin's colour. A
--- client that will not draw the fill file gets the colour as a flat block, which is the same thing.
local function markerPiece(frame, layer, subLevel)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(frame.CreateTexture, frame, nil, layer, nil, subLevel)
  if not ok or type(texture) ~= "table" then
    return nil
  end
  local applied, drew = pcall(Assets.Apply, texture, Map.MARKER_FILL_KEY)
  if applied and drew then
    tint(texture, Map.MARKER_COLOUR, 1)
  elseif type(texture.SetColorTexture) == "function" then
    pcall(texture.SetColorTexture, texture, Map.PinFallbackColour())
  end
  return texture
end

--- Brief M10: the marker's border and pointer, made the first time the pin wears an icon and kept
--- on the pin for every draw after. Four one pixel edges over the icon, and the pointer: the fill
--- turned into a diamond (SetRotation) under the icon, so the icon hides its top half and the bottom
--- half is the notch. Where the client will not turn a texture the pointer is a short stem instead,
--- which still points at the spot.
local function ensureMarker(frame)
  local held = rawget(frame, "itemTreeMarker")
  if held then
    return held
  end
  local marker = { edges = {} }
  for index = 1, 4 do
    marker.edges[index] = markerPiece(frame, "OVERLAY", 1)
  end
  marker.pointer = markerPiece(frame, "ARTWORK", 0)
  marker.shape = "stem"
  local pointer = marker.pointer
  if pointer and type(pointer.SetRotation) == "function" then
    if pcall(pointer.SetRotation, pointer, math.pi / 4) then
      marker.shape = "diamond"
    end
  end
  frame.itemTreeMarker = marker
  return marker
end

local function showRegion(region, on)
  if type(region) ~= "table" then
    return
  end
  if on and type(region.Show) == "function" then
    region:Show()
  elseif not on and type(region.Hide) == "function" then
    region:Hide()
  end
end

--- Brief M10: lays one pin out as a marker (on) or as the plain pin (off), at size pixels for the
--- icon. The frame is the whole marker, so the hover and the click take the square and the pointer
--- alike, and its BOTTOM (the pointer's tip) is what drawPins puts on the position.
local function applyMarker(frame, size, on)
  local art = rawget(frame, "itemTreeArt")
  local marker = on and ensureMarker(frame) or rawget(frame, "itemTreeMarker")
  if not on then
    if type(frame.SetSize) == "function" then
      frame:SetSize(size, size)
    end
    if type(art) == "table" and type(art.ClearAllPoints) == "function" then
      art:ClearAllPoints()
      art:SetAllPoints(frame)
    end
    if marker then
      for _, edge in ipairs(marker.edges) do
        showRegion(edge, false)
      end
      showRegion(marker.pointer, false)
    end
    return nil
  end
  local rect = Map.MarkerRect(size)
  local border = Map.MARKER_BORDER
  if type(frame.SetSize) == "function" then
    frame:SetSize(rect.width, rect.height)
  end
  if type(art) == "table" and type(art.ClearAllPoints) == "function" then
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", border, -border)
    if type(art.SetSize) == "function" then
      art:SetSize(rect.icon, rect.icon)
    end
  end
  -- Top, bottom, left, right: each a hairline along one side of the square at the frame's top.
  local edges = marker.edges
  local spots = {
    { "TOPLEFT", 0, 0, rect.side, border },
    { "TOPLEFT", 0, -(rect.side - border), rect.side, border },
    { "TOPLEFT", 0, 0, border, rect.side },
    { "TOPLEFT", rect.side - border, 0, border, rect.side },
  }
  for index, spot in ipairs(spots) do
    local edge = edges[index]
    if edge then
      edge:ClearAllPoints()
      edge:SetPoint(spot[1], frame, spot[1], spot[2], spot[3])
      if type(edge.SetSize) == "function" then
        edge:SetSize(spot[4], spot[5])
      end
      showRegion(edge, true)
    end
  end
  local pointer = marker.pointer
  if pointer then
    pointer:ClearAllPoints()
    if marker.shape == "diamond" then
      -- Centred on the bottom border, so exactly half of it hangs under the square and its lowest
      -- corner is the frame's bottom edge: the position.
      pointer:SetPoint("CENTER", frame, "BOTTOM", 0, rect.diamondY)
      if type(pointer.SetSize) == "function" then
        pointer:SetSize(rect.diamond, rect.diamond)
      end
    else
      pointer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
      if type(pointer.SetSize) == "function" then
        pointer:SetSize(2 * border + 1, rect.pointer)
      end
    end
    showRegion(pointer, true)
  end
  return rect
end

--- Brief CS2 (QA item 309, in place of CS1's gold ring): the green outline a Confirmed spot's pin
--- wears, the plain white fill (Map.OUTLINE_KEY) tinted Map.OUTLINE_COLOUR and turned into a diamond,
--- Map.OutlineRect(size).side square before the turn, centred on the pin under its art, so a band a few
--- pixels wide shows round the pin's own shape. Made on our own pin frame the first time one is
--- Confirmed and kept for every draw after; shown on a Confirmed pin and hidden on every other, so a
--- pooled frame reused for a plain pin loses it. A client that will not draw the fill file gets the
--- green as a flat colour, which is the same thing. Where the client will not turn a texture there is
--- no outline (an unturned square is not the pin's shape): the tooltip still says the tier. Answers
--- whether the outline shows.
local function pinOutline(frame, on, size)
  local outline = rawget(frame, "itemTreeOutline")
  if not on then
    showRegion(outline, false)
    return false
  end
  if outline == nil then
    outline = false
    if type(frame.CreateTexture) == "function" then
      local ok, texture = pcall(frame.CreateTexture, frame, nil, Map.OUTLINE_LAYER)
      if ok and type(texture) == "table" then
        local applied, drew = pcall(Assets.Apply, texture, Map.OUTLINE_KEY)
        if applied and drew then
          tint(texture, Map.OUTLINE_COLOUR, 1)
        elseif type(texture.SetColorTexture) == "function" then
          local colour = Theme.ColorTable(Map.OUTLINE_COLOUR)
          if type(colour) == "table" then
            pcall(texture.SetColorTexture, texture, colour.r, colour.g, colour.b, 1)
          end
        end
        if type(texture.SetRotation) == "function" and pcall(texture.SetRotation, texture, math.pi / 4) then
          outline = texture
        else
          showRegion(texture, false)
        end
      end
    end
    frame.itemTreeOutline = outline
  end
  if not outline then
    return false
  end
  local side = Map.OutlineRect(size).side
  outline:ClearAllPoints()
  outline:SetPoint("CENTER", frame, "CENTER", 0, 0)
  if type(outline.SetSize) == "function" then
    outline:SetSize(side, side)
  end
  showRegion(outline, true)
  return true
end

--- One pin: a frame so it can be hovered, with the pin texture on it. It takes MOTION, and a click
--- only where a left click sets a waypoint (brief M7, drawPins turns that on per pin), so on a
--- client that cannot set one pressing the map does exactly what it did before, which is nothing.
local function newPin(parts)
  local frame = newFrame("Frame", parts.canvas)
  if not frame then
    return nil
  end
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, true)
  end
  if type(frame.SetMouseClickEnabled) == "function" then
    pcall(frame.SetMouseClickEnabled, frame, false)
  end
  if type(frame.SetMouseMotionEnabled) == "function" then
    pcall(frame.SetMouseMotionEnabled, frame, true)
  end
  if type(frame.CreateTexture) == "function" then
    local ok, texture = pcall(frame.CreateTexture, frame, nil, "OVERLAY")
    if ok and type(texture) == "table" then
      local applied, drew = pcall(Assets.Apply, texture, Map.PIN_KEY)
      frame.itemTreeFace = Map.PIN_KEY
      if not (applied and drew) and type(texture.SetColorTexture) == "function" then
        -- A client that will not draw the pin file keeps a plain block, so a pin is still a pin.
        pcall(texture.SetColorTexture, texture, Map.PinFallbackColour())
      end
      if type(texture.SetAllPoints) == "function" then
        texture:SetAllPoints(frame)
      end
      frame.itemTreeArt = texture
    end
  end
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnEnter", showPinTooltip)
    frame:SetScript("OnLeave", hidePinTooltip)
  end
  -- Brief UX2: a pin that takes the click takes the press with it, so a drag that starts on it
  -- pans the map as one that starts beside it does (a pin that takes no click lets the press through
  -- to the viewport under it).
  setScript(frame, "OnMouseDown", onPinMouseDown)
  setScript(frame, "OnMouseUp", onPinMouseUp)
  frame:Hide()
  return frame
end

--------------------------------------------------------------------------------
-- Brief UX2: zoom and pan
--
-- The map is drawn at 1x exactly as before, into the canvas at the size the layout fitted it to, and
-- every piece that zooms is written down as it is placed (parts.zoomables, at its 1x place). A zoom
-- lays those same pieces out again at the zoom times their 1x place and size, the canvas grown to
-- match, without making, texturing, levelling or tinting anything: the tiles, the explored areas,
-- the patrol paths and the pins' positions. A pin keeps its 1x size, a path its thickness and a dot
-- its size, because they mark places on the map rather than being part of its art. A pan only moves
-- the canvas under the viewport, and hides the pins it moves out of view so none can be hovered or
-- clicked off the visible map. Nothing runs while the map is left alone: the one OnUpdate is the
-- drag's, set on the press and cleared on the release.
--
-- The controls and the arithmetic are the chain tab's, the way the Professions tab reuses them
-- (UI/Chain.lua Chain.ZoomBar with its ControlButton, and Chain.ZoomAbout, Chain.ClampPan,
-- Chain.ViewportPoint and Chain.ZoomText), the pan held as it holds it: the zoomed map's top left in
-- the viewport's own units, y running down, never past an edge. UI/Chain.lua loads after this file,
-- so it is looked up when a map is drawn; without it (a spec that loads this file alone), or on a
-- client that will not clip, the map stays at 1x and never takes the wheel or a press.
--
-- Taint: every frame here is our own (the viewport, the canvas, the zoom bar on the pane UI/Frame.lua
-- hands over). Nothing touches WorldMapFrame, the client's map canvas or its mixins, and nothing is
-- hooked.
--------------------------------------------------------------------------------

local function chainApi()
  local ui = ItemTree.UI
  local chain = type(ui) == "table" and ui.Chain or nil
  if type(chain) ~= "table" then
    return nil
  end
  for _, name in ipairs({ "ZoomAbout", "ClampPan", "ViewportPoint", "ZoomText" }) do
    if type(chain[name]) ~= "function" then
      return nil
    end
  end
  return chain
end

-- The view of the map drawn now, where it can zoom at all.
local function zoomView()
  local parts = Map.parts
  local view = type(parts) == "table" and parts.view or nil
  if type(view) ~= "table" or not view.zoomable then
    return nil, nil
  end
  return view, parts
end

--- Lays every piece the draw wrote down out again at the zoom in force, with the canvas, and moves
--- the player's marker onto the map at that size. Answers how many pieces it moved.
local function relayout(parts)
  local view, canvas = parts.view, parts.canvas
  local zoom = view.zoom
  if type(canvas.SetSize) == "function" then
    canvas:SetSize(view.width * zoom, view.height * zoom)
  end
  local moved = 0
  for _, entry in ipairs(parts.zoomables) do
    local piece, kind = entry.region, entry.kind
    piece:ClearAllPoints()
    if kind == "line" then
      pcall(piece.SetStartPoint, piece, "TOPLEFT", canvas, entry.x1 * zoom, entry.y1 * zoom)
      pcall(piece.SetEndPoint, piece, "TOPLEFT", canvas, entry.x2 * zoom, entry.y2 * zoom)
    elseif kind == "rect" then
      piece:SetPoint("TOPLEFT", canvas, "TOPLEFT", entry.x * zoom, -entry.y * zoom)
      if type(piece.SetSize) == "function" then
        piece:SetSize(entry.width * zoom, entry.height * zoom)
      end
    elseif kind == "turned" then
      piece:SetPoint("CENTER", canvas, "TOPLEFT", entry.x * zoom, entry.y * zoom)
      if type(piece.SetSize) == "function" then
        piece:SetSize(entry.length * zoom, entry.thickness)
      end
    elseif kind == "pin" then
      piece:SetPoint("BOTTOM", canvas, "TOPLEFT", entry.x * zoom, entry.y * zoom - entry.lift)
    else
      piece:SetPoint("CENTER", canvas, "TOPLEFT", entry.x * zoom, entry.y * zoom)
    end
    moved = moved + 1
  end
  -- Brief MP1's marker reads its place against the map's drawn size; its own size stays the 1x one.
  local player = parts.player
  if type(player) == "table" and player.map ~= nil then
    player.width, player.height = view.width * zoom, view.height * zoom
    player.x, player.y = nil, nil
    Map.PlayerTick()
  end
  return moved
end

--- Puts the canvas under the viewport at the pan in force and hides every pin the pan leaves off the
--- visible map (showing again any it brings back). Answers how many pins are in view.
local function moveCanvas(parts)
  local view, canvas = parts.view, parts.canvas
  canvas:ClearAllPoints()
  canvas:SetPoint("TOPLEFT", parts.viewport, "TOPLEFT", view.panX, -view.panY)
  local inside = 0
  for _, entry in ipairs(parts.zoomables) do
    if entry.kind == "pin" then
      local seen = Map.InView(entry.x, entry.y, view.zoom, view.panX, view.panY, view.width, view.height)
      if seen ~= entry.inside then
        entry.inside = seen
        showRegion(entry.region, seen)
      end
      if seen then
        inside = inside + 1
      end
    end
  end
  return inside
end

--- The clip, which is on only while zoomed in, and the readout.
local function showZoom(parts)
  local view = parts.view
  if parts.clips then
    pcall(parts.viewport.SetClipsChildren, parts.viewport, view.zoom > 1)
  end
  local chain, controls = chainApi(), parts.zoomBar
  if chain and type(controls) == "table" and controls.label then
    setText(controls.label, chain.ZoomText(view.zoom))
  end
end

--- Brief UX2: zooms the map by a factor about a point in the viewport (pointerX, pointerY in its own
--- units from its top left, y down: the pointer for the wheel, the middle for the buttons), held
--- between 1x and the map's ceiling, the point under the pointer kept under it. Answers the zoom now
--- in force, or nil where the map drawn cannot zoom.
function Map.ZoomBy(factor, pointerX, pointerY)
  local view, parts = zoomView()
  local chain = chainApi()
  if not view or not chain then
    return nil
  end
  local zoom = view.zoom
  local newZoom = Map.ClampZoom(zoom * (tonumber(factor) or 1), view.ceiling)
  if newZoom == zoom then
    return zoom
  end
  pointerX = math.max(0, math.min(view.width, tonumber(pointerX) or view.width / 2))
  pointerY = math.max(0, math.min(view.height, tonumber(pointerY) or view.height / 2))
  local panX = chain.ZoomAbout(zoom, newZoom, pointerX, view.panX)
  local panY = chain.ZoomAbout(zoom, newZoom, pointerY, view.panY)
  view.zoom = newZoom
  view.panX, view.panY = chain.ClampPan(panX, panY, view.width, view.height, view.width, view.height, newZoom)
  relayout(parts)
  moveCanvas(parts)
  showZoom(parts)
  return newZoom
end

--- Brief UX2: moves the zoomed map to a pan (Chain.ClampPan's shape), held so no edge of the map ever
--- comes inside the viewport. Answers the pan in force, or nil where the map cannot zoom.
function Map.SetPan(panX, panY)
  local view, parts = zoomView()
  local chain = chainApi()
  if not view or not chain then
    return nil
  end
  view.panX, view.panY = chain.ClampPan(
    tonumber(panX) or 0,
    tonumber(panY) or 0,
    view.width,
    view.height,
    view.width,
    view.height,
    view.zoom
  )
  moveCanvas(parts)
  return view.panX, view.panY
end

--- Brief UX2: back to 1x, the whole map fitted to the panel. The zoom bar's Reset.
function Map.ResetZoom()
  local view, parts = zoomView()
  if not view then
    return false
  end
  view.zoom, view.panX, view.panY = 1, 0, 0
  relayout(parts)
  moveCanvas(parts)
  showZoom(parts)
  return true
end

-- The cursor in the window's own units (GetCursorPosition answers in screen pixels, which the
-- viewport's effective scale turns back), or nil where the client will not say.
local function cursorPoint(parts)
  local get = globalFn("GetCursorPosition")
  if not get then
    return nil
  end
  local ok, x, y = pcall(get)
  x, y = ok and tonumber(x) or nil, ok and tonumber(y) or nil
  if not (x and y) then
    return nil
  end
  local scale = number(parts.viewport, "GetEffectiveScale") or 1
  if scale <= 0 then
    scale = 1
  end
  return x / scale, y / scale
end

-- How far the pointer is inside the viewport from its top left, y down (Chain.ViewportPoint), or nil,
-- which leaves Map.ZoomBy the middle.
local function pointerOffsets(parts)
  local chain = chainApi()
  local get = globalFn("GetCursorPosition")
  if not chain or not get then
    return nil
  end
  local ok, x, y = pcall(get)
  if not ok then
    return nil
  end
  local viewport = parts.viewport
  local scale = number(viewport, "GetEffectiveScale") or 1
  return chain.ViewportPoint(x, y, number(viewport, "GetLeft"), number(viewport, "GetTop"), scale)
end

-- A pin's tooltip, put away as the map starts to move under it.
local function dropPinTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.GetOwner) ~= "function" then
    return false
  end
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if ok and type(owner) == "table" and rawget(owner, "itemTreeLines") ~= nil then
    return hidePinTooltip()
  end
  return false
end

-- The drag, each frame from the press to the release: nothing until the pointer has travelled
-- Map.DRAG_THRESHOLD, then the map follows it. A release the client never delivered (the button let
-- go off the window) ends it where the client says the button is up.
local function onDragUpdate()
  local drag, parts = Map.drag, Map.parts
  if type(drag) ~= "table" or type(parts) ~= "table" then
    return stopDrag()
  end
  local held = globalFn("IsMouseButtonDown")
  if held then
    local ok, down = pcall(held, "LeftButton")
    if ok and down == false then
      return stopDrag()
    end
  end
  local x, y = cursorPoint(parts)
  if not x or (x == drag.lastX and y == drag.lastY) then
    return false
  end
  drag.lastX, drag.lastY = x, y
  local dx, dy = x - drag.x, y - drag.y
  if not drag.moved then
    if not Map.IsDrag(dx, dy) then
      return false
    end
    drag.moved = true
    dropPinTooltip()
  end
  -- Screen y runs up and the pan runs down, so the vertical delta is taken the other way.
  Map.SetPan(drag.panX + dx, drag.panY - dy)
  return true
end

--- A left press on the map or on a pin that takes clicks: the start of what may become a drag. Only
--- on a map that can zoom; at 1x it still decides whether the release on a pin is a click.
local function startDrag()
  local view, parts = zoomView()
  if not view then
    return false
  end
  local x, y = cursorPoint(parts)
  if not x then
    return false
  end
  Map.drag = { x = x, y = y, lastX = x, lastY = y, panX = view.panX, panY = view.panY, moved = false }
  Map.dragDriver = parts.viewport
  setScript(parts.viewport, "OnUpdate", onDragUpdate)
  return true
end

--- Ends the drag, if there is one. Answers whether the press travelled far enough to be a drag
--- (counting the last stretch the frame did not get to see), which is what tells a pin's release
--- whether it was a click.
stopDrag = function()
  local drag, driver = Map.drag, Map.dragDriver
  Map.drag, Map.dragDriver = nil, nil
  if driver ~= nil then
    setScript(driver, "OnUpdate", nil)
  end
  if type(drag) ~= "table" then
    return false
  end
  if not drag.moved and type(Map.parts) == "table" then
    local x, y = cursorPoint(Map.parts)
    if x and Map.IsDrag(x - drag.x, y - drag.y) then
      drag.moved = true
    end
  end
  return drag.moved == true
end

onViewportMouseDown = function(_, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  return startDrag()
end

onViewportMouseUp = function(_, button)
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  stopDrag()
  return true
end

onPinMouseDown = onViewportMouseDown

onViewportWheel = function(_, delta)
  delta = tonumber(delta) or 0
  local view, parts = zoomView()
  if delta == 0 or not view then
    return false
  end
  local factor = delta > 0 and Map.ZOOM_STEP or (1 / Map.ZOOM_STEP)
  local pointerX, pointerY = pointerOffsets(parts)
  return Map.ZoomBy(factor, pointerX, pointerY) ~= nil
end

--- The chain tab's zoom bar (Chain.ZoomBar), Reset, + and - with the readout as the Professions tab
--- lays them out, made once per set of parts on the pane, over the map's top right corner.
local function ensureZoomBar(parts, chain)
  if parts.zoomBar ~= nil then
    return parts.zoomBar or nil
  end
  parts.zoomBar = false
  if type(chain.ZoomBar) ~= "function" then
    return nil
  end
  local bar = newFrame("Frame", parts.region)
  if not bar then
    return nil
  end
  local tall = tonumber(chain.CONTROL_H) or Map.BUTTON_H
  if type(bar.SetHeight) == "function" then
    bar:SetHeight(tall)
  end
  -- Over the pins and the player's marker, so nothing the map draws can cover a control; levelled
  -- before its buttons are made on it, the way the chain tab raises its own bar.
  local level = number(parts.canvas, "GetFrameLevel")
  if level and type(bar.SetFrameLevel) == "function" then
    pcall(bar.SetFrameLevel, bar, level + Map.PLAYER_LEVEL_STEP + 1)
  end
  local ok, controls = pcall(chain.ZoomBar, bar, {
    {
      key = "reset",
      text = L["Reset"],
      width = Map.ZOOM_RESET_W,
      hint = L["Reset the zoom to show the whole map"],
      onClick = function()
        Map.ResetZoom()
      end,
    },
    {
      key = "plus",
      text = "+",
      width = tall,
      hint = L["Zoom in"],
      onClick = function()
        Map.ZoomBy(Map.ZOOM_STEP)
      end,
    },
    {
      key = "minus",
      text = "-",
      width = tall,
      hint = L["Zoom out"],
      onClick = function()
        Map.ZoomBy(1 / Map.ZOOM_STEP)
      end,
    },
  })
  bar:Hide()
  if not ok or type(controls) ~= "table" then
    return nil
  end
  controls.height = tall
  parts.zoomBar = controls
  return controls
end

-- The bar in the viewport's top right corner where the map can zoom and the corner has room for it.
local function placeZoomBar(parts, on)
  local controls = parts.zoomBar
  if type(controls) ~= "table" then
    return false
  end
  local bar, view = controls.bar, parts.view
  local wide = (tonumber(controls.width) or 0) + 2 * Map.GAP
  local tall = (tonumber(controls.height) or Map.BUTTON_H) + 2 * Map.GAP
  if not on or type(view) ~= "table" or view.width < wide or view.height < tall then
    bar:Hide()
    return false
  end
  bar:ClearAllPoints()
  bar:SetPoint("TOPRIGHT", parts.viewport, "TOPRIGHT", -Map.GAP, -Map.GAP)
  local level = number(parts.canvas, "GetFrameLevel")
  if level and type(bar.SetFrameLevel) == "function" then
    pcall(bar.SetFrameLevel, bar, level + Map.PLAYER_LEVEL_STEP + 1)
  end
  bar:Show()
  return true
end

-- The viewport takes the press and the wheel exactly while the map can zoom.
local function viewportMouse(viewport, on)
  if type(viewport.EnableMouse) == "function" then
    pcall(viewport.EnableMouse, viewport, on)
  end
  if type(viewport.EnableMouseWheel) == "function" then
    pcall(viewport.EnableMouseWheel, viewport, on)
  end
end

--- Brief UX2: the view a map just drawn at 1x is shown in. The same page and zone as the view before it
--- keeps that zoom and pan (the pan scaled to the map's new size, so a resized window shows the same
--- part of the map), and anything else starts at 1x. Then the pieces are laid out at that zoom, the
--- canvas moved to that pan, and the controls put up. Answers the view.
local function applyView(parts, fit, zone)
  local chain = chainApi()
  local ceiling = (chain and parts.clips) and Map.ZoomCeiling(fit.scale) or 1
  local Tree = treeModule()
  local key = Map.ZoomKey(Tree and Tree.mapRoot or nil, zone)
  local view = { key = key, zoom = 1, panX = 0, panY = 0, width = fit.width, height = fit.height, ceiling = ceiling }
  view.zoomable = ceiling > 1
  local held = Map.view
  if type(held) == "table" and held.key == key and (held.width or 0) > 0 and (held.height or 0) > 0 then
    view.zoom = held.zoom
    view.panX = held.panX * fit.width / held.width
    view.panY = held.panY * fit.height / held.height
  end
  local zoom = Map.ClampZoom(view.zoom, ceiling)
  if chain and zoom > 1 then
    if zoom ~= view.zoom then
      view.panX = chain.ZoomAbout(view.zoom, zoom, fit.width / 2, view.panX)
      view.panY = chain.ZoomAbout(view.zoom, zoom, fit.height / 2, view.panY)
    end
    view.zoom = zoom
    view.panX, view.panY = chain.ClampPan(view.panX, view.panY, fit.width, fit.height, fit.width, fit.height, zoom)
  else
    view.zoom, view.panX, view.panY = 1, 0, 0
  end
  parts.view, Map.view = view, view
  viewportMouse(parts.viewport, view.zoomable)
  if view.zoom ~= 1 then
    relayout(parts)
  end
  moveCanvas(parts)
  if chain and view.zoomable then
    ensureZoomBar(parts, chain)
  end
  placeZoomBar(parts, view.zoomable)
  showZoom(parts)
  return view
end

-- The viewport, the canvas and the zoom bar together: up with a map, down with it.
local function showArt(parts, on)
  if not on then
    stopDrag()
  end
  showRegion(parts.viewport, on)
  showRegion(parts.canvas, on)
  if not on and type(parts.zoomBar) == "table" then
    showRegion(parts.zoomBar.bar, false)
  end
end

--- The face and the four hairline edges every control in the strip wears, drawn by hand rather
--- than borrowed from a client template, because the strip has to read as the same kind of
--- control as the view tabs above it whatever the client carries. Kept on the frame as
--- itemTreeFill and itemTreeEdges, which is what the draw re-tints.
local function plate(button, faceKey)
  if type(button.CreateTexture) ~= "function" then
    return false
  end
  local ok, fill = pcall(button.CreateTexture, button, nil, "BACKGROUND")
  if ok and type(fill) == "table" then
    Assets.Apply(fill, "FILL_WHITE8X8")
    tint(fill, faceKey or Map.COLOR_BUTTON, 1)
    if type(fill.SetAllPoints) == "function" then
      fill:SetAllPoints(button)
    end
    button.itemTreeFill = fill
  end
  local edges = {}
  for _, name in ipairs({ "top", "bottom", "left", "right" }) do
    local okEdge, line = pcall(button.CreateTexture, button, nil, "BORDER")
    if okEdge and type(line) == "table" then
      Assets.Apply(line, "FILL_WHITE8X8")
      tint(line, Map.COLOR_BORDER, 1)
      edges[name] = line
      edges[#edges + 1] = line
    end
  end
  local hairline = SIZES.ITEMTREE_BORDER_HAIRLINE
  if edges.top then
    edges.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    edges.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    edges.top:SetHeight(hairline)
  end
  if edges.bottom then
    edges.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    edges.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    edges.bottom:SetHeight(hairline)
  end
  if edges.left then
    edges.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    edges.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    edges.left:SetWidth(hairline)
  end
  if edges.right then
    edges.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    edges.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    edges.right:SetWidth(hairline)
  end
  button.itemTreeEdges = edges
  return true
end

--- One zone button, one of the row of them a creature known in two to five zones draws.
local function newZoneButton(parts, index)
  local button = newFrame("Button", parts.region)
  if not button then
    return nil
  end
  plate(button)
  button.itemTreeLabel = newFontString(button, "OVERLAY")
  if button.itemTreeLabel and type(button.itemTreeLabel.SetPoint) == "function" then
    button.itemTreeLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
  if type(button.RegisterForClicks) == "function" then
    pcall(button.RegisterForClicks, button, "LeftButtonUp")
  end
  if type(button.SetScript) == "function" then
    button:SetScript("OnEnter", function(self)
      if not rawget(self, "itemTreeOn") then
        tint(rawget(self, "itemTreeFill"), Map.COLOR_BUTTON_HOVER, 1)
      end
    end)
    button:SetScript("OnLeave", function(self)
      if not rawget(self, "itemTreeOn") then
        tint(rawget(self, "itemTreeFill"), Map.COLOR_BUTTON, 1)
      end
    end)
    button:SetScript("OnClick", function(self)
      Map.Select(rawget(self, "itemTreeArea"))
    end)
  end
  button.itemTreeIndex = index
  button:Hide()
  return button
end

--------------------------------------------------------------------------------
-- The zone dropdown and its list (brief E62)
--------------------------------------------------------------------------------
-- A creature in more than five zones, or in zones whose buttons will not fit the panel on one
-- row, gets ONE control in the buttons' own place: the zone that is open with its pin count, and
-- a list of every zone behind it.
--
-- NEVER UIDropDownMenu. It is global, shared with the client's own menus and taints easily. The
-- list here is this file's own frames, built the way UI/Chain.lua builds the chain selector's,
-- which is where every hard lesson about a list of our own is already written down:
--
--   * A ROW PICKS ON THE PRESS, NOT ON THE RELEASE (brief E29 found this the hard way). Every
--     closer fires on the way DOWN, and a Button hidden between the press and the release never
--     delivers OnClick at all, so a row that waited for LeftButtonUp raced every closer for its
--     own click and lost silently. The client settles it the same way: Blizzard_Menu/Menu.lua on
--     the `forever` branch gives every menu element an OnMouseDown and no OnClick, and
--     MenuManagerMixin:HandleGlobalMouseEvent closes on GLOBAL_MOUSE_DOWN only after asking
--     ContainsCursor.
--   * So the closers ask first. Map.MenuHasCursor is that question, and it answers for the
--     dropdown as well as for the list: a press on the control the list belongs to is the player
--     folding it away, which the control itself answers on the release, not a dismissal.
--   * The list is raised over everything on every open, because the window it lives in sets its
--     own strata, and every row is levelled against the list AFTER the list has been raised.
--   * Escape closes the list and nothing else: every other key is handed straight back to the
--     client, so typing is never swallowed. Up, Down and Enter are deliberately not taken: the
--     chain selector does not take them either, and a list that ate the movement keys to offer
--     them would be a far worse bargain than one wheel notch.
--
-- Ten rows at once and the wheel through the rest (Map.MENU_MAX_ROWS). Thirteen zones, which is
-- the deepest the shipped data goes, is therefore ten rows and one notch of the wheel for the
-- other three, with a thin scroller down the edge saying so. Two columns were the alternative and
-- were not taken: the zones are in the data's own order, and a reader who has to go back up to
-- the top of a second column to keep reading that order has lost the thread of it.

-- The screen wide mouse trap under the list, for a client that will not tell us about a press
-- itself. Hidden with the list, and with the map, so it can never be left swallowing clicks.
local function hideCatcher()
  local parts = Map.parts
  local catcher = type(parts) == "table" and parts.catcher or nil
  if type(catcher) == "table" and type(catcher.Hide) == "function" then
    catcher:Hide()
  end
  return true
end

--- Whether the pointer is over the open list, one of its rows, or the dropdown the list belongs
--- to. The client's own menus ask exactly this before closing on a global mouse down
--- (MenuManagerMixin:ContainsCursor, Blizzard_Menu/Menu.lua on the `forever` branch): a press
--- inside a menu is the player picking a row, never the player dismissing it. The dropdown is in
--- the question because a press on it is the player folding the list away, and the control
--- answers that itself on the release; a closer that took it first would close the list and let
--- the release open it straight back up.
---
--- A client that will not say where the pointer is answers false, which leaves the closers doing
--- what they always did.
function Map.MenuHasCursor()
  local parts = Map.parts
  local menu = type(parts) == "table" and parts.menu or nil
  if not (menu and rawget(menu, "shownMenu")) then
    return false
  end
  local frames = { menu, parts.dropdown }
  for _, row in ipairs(parts.menuRows or EMPTY) do
    frames[#frames + 1] = row
  end
  for _, frame in ipairs(frames) do
    if type(frame) == "table" and type(frame.IsShown) == "function" and type(frame.IsMouseOver) == "function" then
      local asked, shown = pcall(frame.IsShown, frame)
      if asked and shown then
        local answered, over = pcall(frame.IsMouseOver, frame)
        if answered and over then
          return true
        end
      end
    end
  end
  return false
end

--- Hides the list, if one is open.
---
--- voiced is the player putting the list away themselves, which is a second press on the
--- dropdown, Escape, or a press that lands anywhere outside it: that plays menuClose, and only
--- where a list was really open, so a close that closes nothing is silent. Every other close
--- stays silent on purpose, the way UI/Chain.lua's does: a close that follows a pick has already
--- been voiced by the pick, and a close a redraw or a hidden window brought about is not
--- something the player did at all.
function Map.CloseMenu(voiced)
  local parts = Map.parts
  if type(parts) ~= "table" then
    return false
  end
  local menu = parts.menu
  local wasOpen = (menu and rawget(menu, "shownMenu")) and true or false
  if type(menu) == "table" then
    menu.shownMenu = false
    if type(menu.Hide) == "function" then
      menu:Hide()
    end
  end
  -- The rows are hidden in their own right rather than left to the list they hang off: a pooled
  -- row still carries the zone the last list put on it, so a row that is only hidden because its
  -- parent is comes back the moment anything shows that parent.
  hideFrom(parts.menuRows or EMPTY, 1)
  hideCatcher()
  Map.menuEntries, Map.menuOffset = nil, 0
  if wasOpen and voiced == true then
    playCue("menuClose")
  end
  return true
end

--- The level the list has to clear to be clickable: the catcher's, the dropdown it drops out of
--- and the panel they both sit in, whichever is highest, plus the step the client's own menus
--- take (Blizzard_Menu/Menu.lua, MenuManagerMixin:OpenMenu).
function Map.MenuLevel(...)
  local level = 0
  for index = 1, select("#", ...) do
    local at = number(select(index, ...), "GetFrameLevel")
    if at and at > level then
      level = at
    end
  end
  return level + Map.MENU_LEVEL_STEP
end

-- The list over everything, on every open rather than once when it was built: the window this
-- panel lives in states its own strata, and anything that restates the panel's would otherwise
-- carry the list down with it.
local function raiseMenu(parts)
  setStrata(parts.catcher, Map.CATCHER_STRATA)
  setStrata(parts.menu, Map.MENU_STRATA)
  local menu = parts.menu
  if type(menu) == "table" and type(menu.SetFrameLevel) == "function" then
    pcall(menu.SetFrameLevel, menu, Map.MenuLevel(parts.catcher, parts.dropdown, parts.region))
  end
  return true
end

-- Every row is levelled again on every fill, against the level the list is at by then. A new
-- frame takes its parent's level plus one and never moves again, so a pooled row would otherwise
-- keep the level the list happened to be at when it was first built while the list climbs out
-- from under it, and a row below the list is a row the LIST answers for.
local function levelRow(row, level)
  if not level or type(row.SetFrameLevel) ~= "function" then
    return false
  end
  return (pcall(row.SetFrameLevel, row, level + 1))
end

-- What a row does when it is pressed: remember the zone and draw the tab again. The list is shut
-- first, so nothing redraws underneath an open menu, and the pick itself is what is voiced.
local function onRowClick(row, button)
  -- Every other button is one "AnyDown" brought with it. The middle button and the thumb buttons
  -- were never meant to pick a zone. A client that will not name the button is taken as a left
  -- click, which is what it always was.
  if button ~= nil and button ~= "LeftButton" then
    return false
  end
  local areaId = rawget(row, "itemTreeArea")
  playCue("click")
  Map.CloseMenu()
  if type(areaId) ~= "number" then
    return false
  end
  return Map.Select(areaId)
end

--- One row of the list: the zone's name, its pin count on the right, and a tick on the one that
--- is open.
local function newMenuRow(parts, index)
  local menu = parts.menu
  if type(menu) ~= "table" then
    return nil
  end
  local row = newFrame("Button", menu)
  if not row then
    return nil
  end
  if type(row.SetHeight) == "function" then
    row:SetHeight(Map.MENU_ROW_H)
  end
  -- Said out loud rather than left to the frame kind's default: a row the client does not take
  -- the mouse on hands the press straight through to the catcher underneath, which closes the
  -- list and changes nothing.
  if type(row.EnableMouse) == "function" then
    pcall(row.EnableMouse, row, true)
  end
  if type(row.CreateTexture) == "function" then
    local ok, hover = pcall(row.CreateTexture, row, nil, "HIGHLIGHT")
    if ok and type(hover) == "table" then
      Assets.Apply(hover, "FILL_WHITE8X8")
      tint(hover, Map.COLOR_HOVER, nil)
      if type(hover.SetAllPoints) == "function" then
        hover:SetAllPoints(row)
      end
      row.itemTreeHover = hover
    end
    local marked, tick = pcall(row.CreateTexture, row, nil, "OVERLAY")
    if marked and type(tick) == "table" then
      local drew = pcall(Assets.Apply, tick, Map.TICK_KEY)
      if drew and type(tick.SetSize) == "function" then
        tick:SetSize(Map.MENU_ACTION, Map.MENU_ACTION)
        tick:SetPoint("RIGHT", row, "RIGHT", -Map.BUTTON_PAD, 0)
        tint(tick, Map.COLOR_TITLE, 1)
        row.itemTreeTick = tick
      end
      if type(tick.Hide) == "function" then
        tick:Hide()
      end
    end
  end
  row.itemTreeLabel = newFontString(row, "OVERLAY")
  if row.itemTreeLabel then
    setFont(row.itemTreeLabel, Map.FONT_SM)
    row.itemTreeLabel:SetPoint("LEFT", row, "LEFT", Map.BUTTON_PAD, 0)
    row.itemTreeLabel:SetPoint("RIGHT", row, "RIGHT", -(Map.BUTTON_PAD * 2 + Map.MENU_RIGHT_W), 0)
    if type(row.itemTreeLabel.SetJustifyH) == "function" then
      row.itemTreeLabel:SetJustifyH("LEFT")
    end
    if type(row.itemTreeLabel.SetWordWrap) == "function" then
      pcall(row.itemTreeLabel.SetWordWrap, row.itemTreeLabel, false)
    end
  end
  row.itemTreeRight = newFontString(row, "OVERLAY")
  if row.itemTreeRight then
    setFont(row.itemTreeRight, Map.FONT_SM)
    row.itemTreeRight:SetPoint("RIGHT", row, "RIGHT", -(Map.BUTTON_PAD * 2 + Map.MENU_ACTION), 0)
    if type(row.itemTreeRight.SetJustifyH) == "function" then
      row.itemTreeRight:SetJustifyH("RIGHT")
    end
  end
  -- THE PICK IS TAKEN ON THE PRESS. See the block at the top of this section: brief E29.
  row.itemTreeClicks = registerClicks(row, { "AnyDown" }, { "LeftButtonDown" })
  setScript(row, "OnClick", onRowClick)
  row.itemTreeIndex = index
  row:Hide()
  return row
end

-- One row filled in for one zone.
local function applyMenuRow(row, entry)
  row.itemTreeArea = tonumber(entry.areaId)
  if row.itemTreeLabel then
    textColor(row.itemTreeLabel, entry.current and Map.COLOR_TITLE or Map.COLOR_BODY)
    setText(row.itemTreeLabel, entry.text)
    row.itemTreeLabel:Show()
  end
  if row.itemTreeRight then
    textColor(row.itemTreeRight, Map.COLOR_MUTED)
    setText(row.itemTreeRight, entry.right)
    row.itemTreeRight:Show()
  end
  -- Brief Q9b: the name ends where the right hand words begin on a row whose words are wider than
  -- the count column, and at the column otherwise. A pooled row is set back every time.
  if row.itemTreeLabel and type(row.itemTreeLabel.SetPoint) == "function" then
    if entry.wide and row.itemTreeRight then
      row.itemTreeLabel:SetPoint("RIGHT", row.itemTreeRight, "LEFT", -Map.BUTTON_PAD, 0)
    else
      row.itemTreeLabel:SetPoint("RIGHT", row, "RIGHT", -(Map.BUTTON_PAD * 2 + Map.MENU_RIGHT_W), 0)
    end
  end
  if row.itemTreeTick then
    if entry.current then
      row.itemTreeTick:Show()
    else
      row.itemTreeTick:Hide()
    end
  end
  return row
end

--- The list itself. Its own frame, its own strata, and it takes the mouse so a press that lands
--- between two rows stops there rather than falling through to the catcher and closing the list
--- from under the player.
local function newMenu(parts)
  local menu = newFrame("Frame", parts.region)
  if not menu then
    return nil
  end
  plate(menu, Map.COLOR_MENU)
  setStrata(menu, Map.MENU_STRATA)
  if type(menu.EnableMouse) == "function" then
    pcall(menu.EnableMouse, menu, true)
  end
  if type(menu.EnableMouseWheel) == "function" then
    pcall(menu.EnableMouseWheel, menu, true)
  end
  -- A list opened low on the screen is dragged back onto it rather than drawn off the edge,
  -- where every row past the edge is one nothing can click.
  if type(menu.SetClampedToScreen) == "function" then
    pcall(menu.SetClampedToScreen, menu, true)
  end
  setScript(menu, "OnMouseWheel", function(_, delta)
    Map.ScrollMenu(delta)
  end)
  -- The scroll indicator: a track down the right hand edge with a thumb on it, drawn only where
  -- there is something to scroll, so ten zones or fewer read as a plain list.
  if type(menu.CreateTexture) == "function" then
    local edge = SIZES.ITEMTREE_BORDER_HAIRLINE
    local ok, track = pcall(menu.CreateTexture, menu, nil, "ARTWORK")
    if ok and type(track) == "table" then
      Assets.Apply(track, "FILL_WHITE8X8")
      tint(track, Map.COLOR_TRACK, 1)
      track:SetWidth(Map.MENU_SCROLLER_W)
      track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -edge, -edge)
      track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -edge, edge)
      track:Hide()
      menu.itemTreeTrack = track
    end
    local made, thumb = pcall(menu.CreateTexture, menu, nil, "OVERLAY")
    if made and type(thumb) == "table" then
      Assets.Apply(thumb, "FILL_WHITE8X8")
      tint(thumb, Map.COLOR_BORDER_ON, 1)
      thumb:SetWidth(Map.MENU_SCROLLER_W)
      thumb:Hide()
      menu.itemTreeThumb = thumb
    end
  end
  -- Escape closes the list and nothing else. Every other key is handed straight back, so an open
  -- list never swallows a keystroke and never closes the window with it.
  -- Brief E91: never decided in combat, see takeMenuKeyboard.
  takeMenuKeyboard(menu)
  setScript(menu, "OnKeyDown", function(self, key)
    local propagate = key ~= "ESCAPE"
    menuPropagate(self, propagate)
    if not propagate then
      Map.CloseMenu(true)
    end
  end)
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  if type(Frame) == "table" and type(Frame.OnCombatStart) == "function" then
    Frame.OnCombatStart(menu, function()
      menuPropagate(menu, true)
      menuKeyboard(menu, false)
    end, function()
      takeMenuKeyboard(menu)
    end)
  end
  -- Whatever hid the list, including the panel it hangs off being hidden with the window, it is
  -- no longer open and the catcher under it goes with it.
  setScript(menu, "OnHide", function(self)
    self.shownMenu = false
    hideCatcher()
  end)
  menu:Hide()
  return menu
end

-- The click catcher, on UIParent where the client has one so a press anywhere on the screen
-- closes the list, and on the panel otherwise, which is as far as this file can see.
local function newCatcher(parts)
  local host = rawget(_G, "UIParent")
  if type(host) ~= "table" then
    host = parts.region
  end
  local catcher = newFrame("Frame", host)
  if not catcher then
    return nil
  end
  if type(catcher.SetAllPoints) == "function" then
    catcher:SetAllPoints(host)
  end
  if type(catcher.EnableMouse) == "function" then
    pcall(catcher.EnableMouse, catcher, true)
  end
  setStrata(catcher, Map.CATCHER_STRATA)
  -- Never the press that belongs to a row or to the dropdown itself: the catcher is a screen wide
  -- trap and the rows answer the press themselves, so a catcher that closed on any press at all
  -- could take the pick off the row it was meant for.
  setScript(catcher, "OnMouseDown", function()
    if Map.MenuHasCursor() then
      return false
    end
    return Map.CloseMenu(true)
  end)
  catcher:Hide()
  return catcher
end

-- The one line a hovered control puts in the tooltip.
local function showHint(frame, text)
  local tooltip = rawget(_G, "GameTooltip")
  if type(text) ~= "string" or text == "" then
    return false
  end
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" or type(tooltip.AddLine) ~= "function" then
    return false
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  tooltip:AddLine(text)
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

--- The dropdown: the zone that is open, its pin count, and the chevron the chain selector wears.
local function newDropdown(parts)
  local button = newFrame("Button", parts.region)
  if not button then
    return nil
  end
  plate(button)
  if type(button.CreateTexture) == "function" then
    local ok, chevron = pcall(button.CreateTexture, button, nil, "OVERLAY")
    if ok and type(chevron) == "table" then
      local drew = pcall(Assets.Apply, chevron, Map.CHEVRON_KEY)
      if drew and type(chevron.SetSize) == "function" then
        chevron:SetSize(Map.MENU_ACTION, Map.MENU_ACTION)
        chevron:SetPoint("RIGHT", button, "RIGHT", -Map.BUTTON_PAD, 0)
        tint(chevron, Map.COLOR_BODY, 1)
        button.itemTreeChevron = chevron
      elseif type(chevron.Hide) == "function" then
        chevron:Hide()
      end
    end
  end
  button.itemTreeLabel = newFontString(button, "OVERLAY")
  if button.itemTreeLabel then
    setFont(button.itemTreeLabel, Map.FONT_SM)
    button.itemTreeLabel:SetPoint("LEFT", button, "LEFT", Map.BUTTON_PAD, 0)
    button.itemTreeLabel:SetPoint("RIGHT", button, "RIGHT", -(Map.BUTTON_PAD * 2 + Map.MENU_ACTION), 0)
    if type(button.itemTreeLabel.SetJustifyH) == "function" then
      button.itemTreeLabel:SetJustifyH("LEFT")
    end
    if type(button.itemTreeLabel.SetWordWrap) == "function" then
      pcall(button.itemTreeLabel.SetWordWrap, button.itemTreeLabel, false)
    end
  end
  -- The dropdown answers the RELEASE, the way the chain selector does, and the closers leave a
  -- press that lands on it alone (Map.MenuHasCursor), so a second press really does fold the list
  -- away instead of closing and reopening it.
  button.itemTreeClicks = registerClicks(button, { "LeftButtonUp" }, { "AnyUp" })
  setScript(button, "OnClick", function()
    Map.ToggleMenu()
  end)
  setScript(button, "OnEnter", function(self)
    tint(rawget(self, "itemTreeFill"), Map.COLOR_BUTTON_HOVER, 1)
    showHint(self, L["Choose which zone to show"])
  end)
  setScript(button, "OnLeave", function(self)
    tint(rawget(self, "itemTreeFill"), Map.COLOR_BUTTON, 1)
    hidePinTooltip()
  end)
  button:Hide()
  return button
end

-- The dropdown, its list and the catcher, made on the first draw that needs them and reused for
-- every creature after. A creature in one zone, and every creature whose buttons fit, costs none
-- of them.
local function ensureMenu(parts)
  if not parts.dropdown then
    parts.dropdown = newDropdown(parts)
  end
  if not parts.menu and parts.dropdown then
    parts.menu = newMenu(parts)
    parts.catcher = newCatcher(parts)
  end
  if parts.dropdown and parts.menu then
    return parts.dropdown
  end
  return nil
end

--- Whether the pointer's press reached us as an event rather than through the catcher. Set once
--- per session by the first list that opens on a client that answers GLOBAL_MOUSE_DOWN.
Map.globalMouse = false

--- Closes an open list when a press lands outside it, which is what the client tells us directly.
--- The same rule as the catcher, asked the same way round, so nothing of ours is ever over a row.
function Map.OnGlobalMouseDown(button)
  if button ~= nil and button ~= "LeftButton" and button ~= "RightButton" then
    return false
  end
  local parts = Map.parts
  local menu = type(parts) == "table" and parts.menu or nil
  if not (menu and rawget(menu, "shownMenu")) then
    return false
  end
  if Map.MenuHasCursor() then
    return false
  end
  return Map.CloseMenu(true)
end

-- Listens for the press itself, once per session. A client that has never heard of the event
-- refuses to register it, which leaves the catcher as the only way to close a list.
local function watchGlobalMouse()
  if Map.globalMouse then
    return true
  end
  local watcher = Map.watcher
  if not watcher then
    watcher = newFrame("Frame", nil)
    if not watcher then
      return false
    end
    Map.watcher = watcher
    setScript(watcher, "OnEvent", function(_, event, button)
      if event == "GLOBAL_MOUSE_DOWN" then
        Map.OnGlobalMouseDown(button)
      end
    end)
  end
  if type(watcher.RegisterEvent) ~= "function" then
    return false
  end
  -- An unknown event raises on one client and answers false on another, so both are refusals.
  local ok, registered = pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
  if not ok or registered == false then
    return false
  end
  Map.globalMouse = true
  return true
end

local function showCatcher(parts)
  -- Nothing of ours goes over the rows on a client that will tell us about the press itself.
  if Map.globalMouse then
    return false
  end
  local catcher = parts.catcher
  if type(catcher) ~= "table" or type(catcher.Show) ~= "function" then
    return false
  end
  catcher:Show()
  return true
end

-- The thumb on the scroll track: how far through a long list the player is.
local function applyScroller(parts, count, offset)
  local menu = parts.menu
  local track = type(menu) == "table" and rawget(menu, "itemTreeTrack") or nil
  local thumb = type(menu) == "table" and rawget(menu, "itemTreeThumb") or nil
  if not (track and thumb) then
    return false
  end
  local rows = Map.MENU_MAX_ROWS
  if count <= rows then
    track:Hide()
    thumb:Hide()
    return false
  end
  local height = rows * Map.MENU_ROW_H
  local run = math.max(math.floor(height * rows / count + 0.5), Map.MENU_ROW_H)
  local most = Map.MaxOffset(count, rows)
  local travel = height - run
  local at = most > 0 and (offset / most) or 0
  thumb:ClearAllPoints()
  thumb:SetHeight(run)
  thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -math.floor(travel * at + 0.5))
  thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -math.floor(travel * at + 0.5))
  track:Show()
  thumb:Show()
  return true
end

-- Draws the window of rows the offset names. The pool is only ever MENU_MAX_ROWS deep, so
-- thirteen zones cost the same ten frames as three do.
local function fillMenu(parts, entries, offset)
  local menu = parts.menu
  local count = #entries
  local rows = math.min(count, Map.MENU_MAX_ROWS)
  local hairline = SIZES.ITEMTREE_BORDER_HAIRLINE
  local scroller = count > rows and Map.MENU_SCROLLER_W or 0
  local get = pooled(parts.menuRows, function(index)
    return newMenuRow(parts, index)
  end)
  -- Read once, after the list has been raised for this open: every row is put above it.
  local level = number(menu, "GetFrameLevel")
  local shown = 0
  for index = 1, rows do
    local row = get(index)
    if row then
      shown = index
      levelRow(row, level)
      applyMenuRow(row, entries[offset + index])
      row:ClearAllPoints()
      local top = hairline + (index - 1) * Map.MENU_ROW_H
      row:SetPoint("TOPLEFT", menu, "TOPLEFT", hairline, -top)
      row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -(hairline + scroller), -top)
      row:Show()
    end
  end
  hideFrom(parts.menuRows, shown + 1)
  applyScroller(parts, count, offset)
  return shown
end

--- Scrolls an open list by whole rows. delta is the wheel's own sign: up is towards the start.
function Map.ScrollMenu(delta)
  local parts = Map.parts
  local entries = Map.menuEntries
  local menu = type(parts) == "table" and parts.menu or nil
  if not (entries and menu and rawget(menu, "shownMenu")) then
    return false
  end
  local most = Map.MaxOffset(#entries, Map.MENU_MAX_ROWS)
  if most == 0 then
    return false
  end
  local offset = (Map.menuOffset or 0) - (tonumber(delta) or 0)
  if offset < 0 then
    offset = 0
  elseif offset > most then
    offset = most
  end
  if offset == Map.menuOffset then
    return false
  end
  Map.menuOffset = offset
  fillMenu(parts, entries, offset)
  return true
end

--- Opens the list under the dropdown. Everything in it comes from the strip the last draw stated,
--- so the list can never offer a zone the tab is not holding.
function Map.OpenMenu()
  local parts, strip = Map.parts, Map.strip
  if type(parts) ~= "table" or type(strip) ~= "table" then
    return false
  end
  local dropdown = ensureMenu(parts)
  local menu = parts.menu
  if not (dropdown and menu) then
    return false
  end
  local entries = Map.MenuEntries(strip.list, strip.selected)
  if #entries == 0 then
    return false
  end
  local function measure(text)
    if parts.ruler and setText(parts.ruler, text) then
      local measured = number(parts.ruler, "GetStringWidth")
      if measured and measured > 0 then
        return measured
      end
    end
    return nil
  end
  local widths = Map.MenuWidths(strip.widths, entries, measure)
  local width = Map.MenuWidth(widths, strip.width, math.min(Map.MENU_MAX_W, strip.available))
  local offset = Map.MenuStart(strip.selected, #entries, Map.MENU_MAX_ROWS)
  Map.menuEntries, Map.menuOffset = entries, offset
  -- Raised before it is filled, never after: the rows are levelled against the list, so the list
  -- has to be at the level it is going to be at before the first row is put above it.
  watchGlobalMouse()
  raiseMenu(parts)
  local shown = fillMenu(parts, entries, offset)
  if shown == 0 then
    return Map.CloseMenu()
  end
  menu:SetSize(width, shown * Map.MENU_ROW_H + SIZES.ITEMTREE_BORDER_HAIRLINE * 2)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -Map.LINE_GAP)
  showCatcher(parts)
  menu.shownMenu = true
  menu:Show()
  takeMenuKeyboard(menu)
  playCue("menuOpen")
  return true
end

--- What the dropdown does when it is pressed: opens its list, or folds an open one away.
function Map.ToggleMenu()
  local parts = Map.parts
  local menu = type(parts) == "table" and parts.menu or nil
  if menu and rawget(menu, "shownMenu") then
    return Map.CloseMenu(true)
  end
  return Map.OpenMenu()
end

--------------------------------------------------------------------------------
-- Reading the client's art, once per zone map
--------------------------------------------------------------------------------

--- What this client says one zone map is made of: the first art layer as a grid, and the file ids
--- of its tiles. nil and a reason where there is nothing to lay out, and every reason gives the
--- art up for the session, because a client that answers any of them has not been shown to answer
--- the others either.
function Map.ReadArt(uiMapId)
  if type(uiMapId) ~= "number" then
    return nil, "map"
  end
  local ok, layers = mapCall("GetMapArtLayers", uiMapId)
  if not ok then
    return nil, "call"
  end
  local grid = Map.Grid(type(layers) == "table" and layers[1] or nil)
  if not grid then
    return nil, "layer"
  end
  local okTextures, textures = mapCall("GetMapArtLayerTextures", uiMapId, 1)
  if not okTextures then
    return nil, "call"
  end
  if type(textures) ~= "table" or #textures == 0 then
    return nil, "tiles"
  end
  return { grid = grid, textures = textures }
end

--- The same answer, remembered, so walking between two zones of one creature asks the client once
--- each. The cache is a handful of small tables and is dropped whole when it is full.
function Map.Art(uiMapId)
  if Map.artBlocked then
    return nil, Map.artReason or "blocked"
  end
  local cache = Map.artCache
  if type(cache) ~= "table" then
    cache = { order = {} }
    Map.artCache = cache
  end
  local held = cache[uiMapId]
  if held then
    return held
  end
  local record, reason = Map.ReadArt(uiMapId)
  if not record then
    Map.artBlocked = true
    Map.artReason = reason
    return nil, reason
  end
  if #cache.order >= Map.ART_CACHE then
    Map.artCache = { order = {} }
    cache = Map.artCache
  end
  cache[uiMapId] = record
  cache.order[#cache.order + 1] = uiMapId
  return record
end

--------------------------------------------------------------------------------
-- Brief MX1: the explored areas over the art, once per zone map
--------------------------------------------------------------------------------

--- The shipped full set of one map's overlays (the MapOverlays module, built from the build's
--- WorldMapOverlay tables), so every zone is drawn fully revealed. nil where the module or the
--- map is not there.
function Map.DataOverlays(uiMapId)
  local Data = ItemTree.Data
  if type(Data) ~= "table" or type(Data.Get) ~= "function" then
    return nil
  end
  local ok, module = pcall(Data.Get, Data, "MapOverlays")
  local rows = ok and type(module) == "table" and module[uiMapId] or nil
  if type(rows) ~= "table" or #rows == 0 then
    return nil
  end
  local out = {}
  for _, row in ipairs(rows) do
    out[#out + 1] = Map.OverlayFromData(row)
  end
  return out
end

--- The player's own explored areas, out of C_MapExplorationInfo.GetExploredMapTextures (declared
--- in Blizzard_APIDocumentationGenerated, read the way MapExplorationPinMixin reads it). nil where
--- the client does not carry it, raised or answered nothing.
function Map.ClientOverlays(uiMapId)
  local api = rawget(_G, "C_MapExplorationInfo")
  local fn = type(api) == "table" and api.GetExploredMapTextures or nil
  if type(fn) ~= "function" then
    return nil
  end
  local ok, list = pcall(fn, uiMapId)
  if not ok or type(list) ~= "table" then
    return nil
  end
  return list
end

--- What is drawn over one map's art: the shipped full set where it ships, else the player's own
--- explored areas, else nothing (EMPTY). Remembered per map for the session; the client's answer
--- is dropped on MAP_EXPLORATION_UPDATED (Map.OnExplorationUpdated). Answers the list and its
--- source, "data", "client" or "none".
function Map.Overlays(uiMapId)
  if type(uiMapId) ~= "number" then
    return EMPTY, "none"
  end
  local cache = Map.overlayCache
  if type(cache) ~= "table" then
    cache = {}
    Map.overlayCache = cache
  end
  local held = cache[uiMapId]
  if held then
    return held.list, held.source
  end
  local list, source = Map.DataOverlays(uiMapId), "data"
  if not list then
    list, source = Map.ClientOverlays(uiMapId), "client"
  end
  if not list then
    list, source = EMPTY, "none"
  end
  cache[uiMapId] = { list = list, source = source }
  return list, source
end

--- MAP_EXPLORATION_UPDATED: the player found somewhere, so every remembered answer is dropped and
--- a map on screen is drawn again with the new area in it.
function Map.OnExplorationUpdated()
  Map.overlayCache = nil
  if Map.live ~= nil then
    return Map.Redraw()
  end
  return false
end

--- Listens for the client's exploration event, once per session, on our own frame.
local function watchExploration()
  if Map.explorationWatched then
    return true
  end
  local watcher = Map.explorationWatcher
  if not watcher then
    watcher = newFrame("Frame", nil)
    if not watcher then
      return false
    end
    Map.explorationWatcher = watcher
    setScript(watcher, "OnEvent", function(_, event)
      if event == "MAP_EXPLORATION_UPDATED" then
        Map.OnExplorationUpdated()
      end
    end)
  end
  if type(watcher.RegisterEvent) ~= "function" then
    return false
  end
  local ok, registered = pcall(watcher.RegisterEvent, watcher, "MAP_EXPLORATION_UPDATED")
  if not ok or registered == false then
    return false
  end
  Map.explorationWatched = true
  return true
end

--------------------------------------------------------------------------------
-- What the addon knows about one creature's places
--------------------------------------------------------------------------------

--- The build's own name for one area, through the shipped table's public namer. The zone list the
--- seam hands over only names the places the creature's ROWS state, so a zone that only its pins
--- stand in has to be named from here.
function Map.ZoneName(areaId)
  local era = eraModule()
  local Graph = ItemTree.Graph
  if not era or type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
    return nil
  end
  if type(era.NameFor) ~= "function" or type(areaId) ~= "number" then
    return nil
  end
  local ok, key = pcall(Graph.Key, "zone", areaId)
  if not ok or type(key) ~= "string" then
    return nil
  end
  local named, name = pcall(era.NameFor, era, key)
  if named and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- Every zone one creature's Map tab can draw, and which of them opens first. The pins are decoded
--- here and nowhere else, which is what keeps era.pinDecodes at zero for a tree build: nothing on
--- the way to a drawn tree calls this. kind "object" reads a herb's, a vein's, a fishing pool's or
--- a chest's pins instead (brief D7, E:ObjectPinsOf); anything else is a creature's.
function Map.Zones(nameIndex, zones, kind)
  local era = eraModule()
  local pins = EMPTY
  local reader = (kind == "object") and "ObjectPinsOf" or "PinsOf"
  if era and type(era[reader]) == "function" and type(nameIndex) == "number" then
    local ok, decoded = pcall(era[reader], era, nameIndex)
    if ok and type(decoded) == "table" then
      pins = decoded
    end
  end
  -- Brief M11: a creature's patrol paths, out of pt. An object walks nowhere.
  local paths = EMPTY
  if kind ~= "object" and era and type(era.PathsOf) == "function" and type(nameIndex) == "number" then
    local ok, decoded = pcall(era.PathsOf, era, nameIndex)
    if ok and type(decoded) == "table" then
      paths = decoded
    end
  end
  local list, selected = Map.Merge(zones, pins, paths)
  if kind == "object" then
    list, selected = Map.PinnedFirst(list, selected)
  end
  for _, zone in ipairs(list) do
    if zone.map == nil and era and type(era.MapOf) == "function" then
      local ok, uiMapId = pcall(era.MapOf, era, zone.areaId)
      if ok and type(uiMapId) == "number" then
        zone.map = uiMapId
      end
    end
    if zone.name == nil then
      zone.name = Map.ZoneName(zone.areaId)
    end
  end
  return list, selected
end

--- The creature's own name, for the pin tooltip. The shipped table's namer again, through the node
--- key the page is rooted on: the creature's page (brief EK1, keyed by its creature id, E:PageKey).
--- kind "object" names the node, the pool or the chest instead (brief D7), through its own page key
--- (brief EK1 2c, keyed by its gameobject id, E:ObjectKey).
function Map.CreatureName(nameIndex, kind)
  local era = eraModule()
  local Graph = ItemTree.Graph
  if not era or type(era.NameFor) ~= "function" or type(nameIndex) ~= "number" then
    return nil
  end
  if type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
    return nil
  end
  local ok, key = false, nil
  if kind == "object" then
    -- Brief EK1 2c: the object's page, keyed by its gameobject id.
    if type(era.ObjectKey) == "function" then
      ok, key = pcall(era.ObjectKey, era, nameIndex)
    end
  elseif type(era.PageKey) == "function" then
    ok, key = pcall(era.PageKey, era, nameIndex)
  end
  if not ok or type(key) ~= "string" then
    -- Brief EK1: a creature or an object the table states no id for has no page key, and is named
    -- by its name all the same.
    if type(era.NameAt) == "function" then
      local named, name = pcall(era.NameAt, era, nameIndex)
      if named and type(name) == "string" and name ~= "" then
        return name
      end
    end
    return nil
  end
  local named, name = pcall(era.NameFor, era, key)
  if named and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- Brief M3: the pins of the vendor the pane's map is rooted on, where the curated tier ships its
--- place or the player's records hold where they stood at its window, or nil. Read off
--- Tree.mapRoot the way Map.ObjectSubject is; guarded, so no pane, no table and no vendor all
--- answer nil. Nothing is asked of the client.
---
--- Brief V1: a vendor the client's own tables place (Core/ForeverVendors.lua Positions) adds its
--- client pin first, and the player's own pin (or the curated one) stands beside it.
function Map.VendorPositions()
  local Tree = treeModule()
  local root = Tree and Tree.mapRoot or nil
  if type(root) ~= "string" or root:sub(1, 4) ~= "npc:" then
    return nil
  end
  local out = {}
  local forever = ItemTree.ForeverVendors
  if type(forever) == "table" and type(forever.Facts) == "function" and type(forever.Positions) == "function" then
    local ok, facts = pcall(forever.Facts, root)
    if ok and type(facts) == "table" then
      local placed, pins = pcall(forever.Positions, facts)
      for _, pin in ipairs(placed and type(pins) == "table" and pins or EMPTY) do
        out[#out + 1] = pin
      end
    end
  end
  local sources = ItemTree.Sources
  local favour = type(sources) == "table" and sources.Favour or nil
  if type(favour) == "table" and type(favour.Positions) == "function" then
    local shipped = nil
    if type(favour.VendorFacts) == "function" then
      local ok, facts = pcall(favour.VendorFacts, root)
      shipped = ok and type(facts) == "table" and facts or nil
    end
    local collected = nil
    local instance = ItemTree.collector
    if type(instance) == "table" and type(instance.NpcFacts) == "function" then
      local ok, facts = pcall(instance.NpcFacts, instance, root)
      collected = ok and type(facts) == "table" and facts or nil
    end
    local ok, positions = pcall(favour.Positions, shipped, collected)
    for _, pin in ipairs(ok and type(positions) == "table" and positions or EMPTY) do
      out[#out + 1] = pin
    end
  end
  -- Brief PS1: where players stood at this vendor's window, shipped as map cells
  -- (Core/PlayerSources.lua NpcFacts), one pin at each cell's centre.
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.NpcFacts) == "function" then
    local ok, facts = pcall(players.NpcFacts, root)
    for _, pin in
      ipairs(ok and type(facts) == "table" and type(facts.positions) == "table" and facts.positions or EMPTY)
    do
      out[#out + 1] = pin
    end
  end
  -- Brief TR1c: an owner confirmed claim's approximate positions (Core/Creatures.lua
  -- ClaimPositions), shipped only where our own records place the creature nowhere.
  for _, pin in ipairs(Map.ClaimPins(root)) do
    out[#out + 1] = pin
  end
  -- Brief NW1: a creature found at one of several hand kept spots (Core/Creatures.lua
  -- SpotPositions), every spot, shipped whether or not our own records place it too.
  for _, pin in ipairs(Map.SpotPins(root)) do
    out[#out + 1] = pin
  end
  if #out == 0 then
    return nil
  end
  return out
end

--- Brief TR1c: the approximate claim pins of an npc key ("npc:<creature id>"), each
--- { map, x, y, zone, name, approx = true }, or an empty list. Guarded: no Creatures module, no row
--- and a made up key all answer an empty list. Asks nothing of the client but a map's name.
---
--- Brief GF5: and a predicted giver's or turn in's approximate pins (Core/QuestsPredicted.lua
--- NpcPins, shipped only where no record of ours places the creature), for its Forever page or its
--- Classic Era one, the same way.
function Map.ClaimPins(root)
  local players = ItemTree.PlayerSources
  local zoneOf = type(players) == "table" and players.MapName or nil
  local out = EMPTY
  local Creatures = ItemTree.Creatures
  local id = type(root) == "string" and tonumber(root:match("^npc:(%d+)$")) or nil
  if id and type(Creatures) == "table" and type(Creatures.ClaimPositions) == "function" then
    local ok, pins = pcall(Creatures.ClaimPositions, id, zoneOf)
    out = ok and type(pins) == "table" and pins or EMPTY
  end
  local predicted = ItemTree.QuestsPredicted
  if type(root) == "string" and type(predicted) == "table" and type(predicted.NpcPins) == "function" then
    local ok, pins = pcall(predicted.NpcPins, root, zoneOf)
    if ok and type(pins) == "table" and #pins > 0 then
      local joined = {}
      for _, pin in ipairs(out) do
        joined[#joined + 1] = pin
      end
      for _, pin in ipairs(pins) do
        joined[#joined + 1] = pin
      end
      out = joined
    end
  end
  return out
end

--- Brief NW1: the hand kept spot pins of an npc key ("npc:<creature id>"), each { map, x, y, zone,
--- name, spot = true } (Core/Creatures.lua SpotPositions), or an empty list. Guarded: no Creatures
--- module, no row and a made up key all answer an empty list. Asks nothing of the client but a map's
--- name.
---
--- Brief CS1: a spot near the player's own record of the creature (Core/Collector.lua C:NpcPlaces: a
--- quest it gave or took back, its vendor window) draws Confirmed on their own client, before any
--- compile ships it. No collector, or one that raises, and the spots are as shipped.
function Map.SpotPins(root)
  local Creatures = ItemTree.Creatures
  local id = type(root) == "string" and tonumber(root:match("^npc:(%d+)$")) or nil
  if not id or type(Creatures) ~= "table" or type(Creatures.SpotPositions) ~= "function" then
    return EMPTY
  end
  local players = ItemTree.PlayerSources
  local zoneOf = type(players) == "table" and players.MapName or nil
  local own = nil
  local instance = ItemTree.collector
  if type(instance) == "table" and type(instance.NpcPlaces) == "function" then
    local found, places = pcall(instance.NpcPlaces, instance, id)
    own = found and type(places) == "table" and places or nil
  end
  local ok, pins = pcall(Creatures.SpotPositions, id, zoneOf, own)
  return ok and type(pins) == "table" and pins or EMPTY
end

--- The OBJECT the pane's map is rooted on, where it is one (brief D7): its name index, the zones its
--- own row lists, and "object". nil for every other root, a creature's included, which keeps the
--- name index and the places the seam handed over.
---
--- The seam hands over a creature's name index and nothing for any other root (Tree.MapFacts asks
--- E:CreatureFacts), so the object is read off the root the pane says it is drawing, Tree.mapRoot,
--- which Tree.ShowMap sets before it calls the painter. Guarded: no pane, no table and no object
--- all answer nil.
function Map.ObjectSubject()
  local Tree = treeModule()
  local era = eraModule()
  local root = Tree and Tree.mapRoot or nil
  if type(root) ~= "string" or not era or type(era.ObjectFacts) ~= "function" then
    return nil
  end
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Kind) ~= "function" then
    return nil
  end
  local okKind, kind = pcall(Graph.Kind, root)
  if not okKind or kind ~= "object" then
    return nil
  end
  local ok, facts = pcall(era.ObjectFacts, era, root)
  if not ok or type(facts) ~= "table" or type(facts.nameIndex) ~= "number" then
    return nil
  end
  local zones = {}
  for _, zone in ipairs(facts.zones or EMPTY) do
    if type(zone) == "table" and type(zone.areaId) == "number" then
      zones[#zones + 1] = { areaId = zone.areaId, name = zone.name }
    end
  end
  return facts.nameIndex, zones, "object"
end

--- The ZONE the pane's map is rooted on, where it is one (brief Z1): its facts out of the shipped
--- table ({ areaId, name, map }) and the source the player picked on its Here tab, or nil for every
--- other root. Read off Tree.mapRoot the way Map.ObjectSubject is, and guarded the same way.
function Map.ZoneSubject()
  local Tree = treeModule()
  local era = eraModule()
  local root = Tree and Tree.mapRoot or nil
  if type(root) ~= "string" or not era or type(era.ZoneFacts) ~= "function" then
    return nil
  end
  local Graph = ItemTree.Graph
  if type(Graph) ~= "table" or type(Graph.Kind) ~= "function" then
    return nil
  end
  local okKind, kind = pcall(Graph.Kind, root)
  if not okKind or kind ~= "zone" then
    return nil
  end
  local ok, facts = pcall(era.ZoneFacts, era, root)
  if not ok or type(facts) ~= "table" or type(facts.areaId) ~= "number" then
    return nil
  end
  local pick = nil
  local ViewModel = ItemTree.ViewModel
  if type(ViewModel) == "table" and type(ViewModel.ZonePick) == "function" then
    local picked, held = pcall(ViewModel.ZonePick, root)
    if picked and type(held) == "table" then
      pick = held
    end
  end
  -- Brief Z2: the item picked in the Map view's item column, where the column has built its list.
  -- Read without building anything (ViewModel.HeldZoneItem).
  local item = nil
  if type(ViewModel) == "table" and type(ViewModel.HeldZoneItem) == "function" then
    local picked, held = pcall(ViewModel.HeldZoneItem, root)
    if picked and type(held) == "table" then
      item = held
    end
  end
  return facts, pick, item
end

--- Opens one zone's own page (brief Z1): the window re-roots on the zone and lands on its Tree tab.
--- Both calls are UI/Frame.lua's, looked up at call time and pcall'd, so a window that is not
--- there costs the click and nothing else.
function Map.OpenZone(areaId)
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  local Graph = ItemTree.Graph
  if type(areaId) ~= "number" or type(frame) ~= "table" or type(frame.Open) ~= "function" then
    return false
  end
  if type(Graph) ~= "table" or type(Graph.Key) ~= "function" then
    return false
  end
  playCue("click")
  local opened = pcall(frame.Open, Graph.Key("zone", areaId))
  if type(frame.SelectTab) == "function" then
    pcall(frame.SelectTab, "Tree")
  end
  return opened
end

--------------------------------------------------------------------------------
-- The client's waypoint and its entrance list (brief M7)
--------------------------------------------------------------------------------

-- Both calls are checked against the `forever` branch of the Gethe/wow-ui-source mirror:
-- Blizzard_APIDocumentationGenerated/MapDocumentation.lua declares C_Map.SetUserWaypoint(point) ->
-- wasSet and C_Map.CanSetUserWaypointOnMap(uiMapID) -> canSet, and
-- Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua asks the second before the
-- first, with the point made by UiMapPoint.CreateFromCoordinates (Blizzard_ObjectAPI/Mainline/
-- UiMapPoint.lua, a plain table maker). EncounterJournalDocumentation.lua on the same branch
-- declares C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID) -> a list of
-- DungeonEntranceMapInfo (name, position as a Vector2DMixin, and more), which the world map's
-- DungeonEntranceDataProvider.lua draws its entrance pins from. Every one is looked up at call
-- time and pcall'd, and only ever asked because the player opened this tab or clicked a pin.

--- Whether a left click on a pin of this zone map can set the client's waypoint: the client
--- carries C_Map.SetUserWaypoint, and C_Map.CanSetUserWaypointOnMap, where it carries it, says yes.
function Map.CanWaypoint(uiMapId)
  local api = rawget(_G, "C_Map")
  if type(uiMapId) ~= "number" or type(api) ~= "table" or type(api.SetUserWaypoint) ~= "function" then
    return false
  end
  if type(api.CanSetUserWaypointOnMap) == "function" then
    local ok, can = pcall(api.CanSetUserWaypointOnMap, uiMapId)
    return ok and can == true
  end
  return true
end

--- The point C_Map.SetUserWaypoint takes, made the way the client's own map makes it.
local function waypointPoint(uiMapId, x, y)
  local maker = rawget(_G, "UiMapPoint")
  if type(maker) == "table" and type(maker.CreateFromCoordinates) == "function" then
    local ok, point = pcall(maker.CreateFromCoordinates, uiMapId, x, y)
    if ok and type(point) == "table" then
      return point
    end
  end
  local position = nil
  local vector = globalFn("CreateVector2D")
  if vector then
    local ok, made = pcall(vector, x, y)
    if ok and type(made) == "table" then
      position = made
    end
  end
  return { uiMapID = uiMapId, position = position or { x = x, y = y } }
end

--- Sets the client's user waypoint at one place of a zone map, x and y in 0 to 1: the player's own
--- click on one of our pins, and nothing else ever calls it. Answers whether the client took it.
---
--- Brief UX1 (QA item 402): once the client has taken it, the "Waypoint added" toast (UI/Toast.lua)
--- says what it is for, label ("Hogger", "Marshal Dughan, turn in for Wanted: Hogger"), or nothing
--- under its title where no label is handed. Every waypoint ItemTree sets comes through here, so
--- every one gets its toast; a refused one gets none.
function Map.SetWaypoint(uiMapId, x, y, label)
  if not Map.CanWaypoint(uiMapId) or type(x) ~= "number" or type(y) ~= "number" then
    return false
  end
  local api = rawget(_G, "C_Map")
  local ok, set = pcall(api.SetUserWaypoint, waypointPoint(uiMapId, x, y))
  if not ok or set == false then
    return false
  end
  -- The on-screen arrow points at it straight away (C_SuperTrack.SetSuperTrackedUserWaypoint,
  -- declared in SuperTrackManagerDocumentation.lua on the same branch), where the client carries it.
  local track = rawget(_G, "C_SuperTrack")
  if type(track) == "table" and type(track.SetSuperTrackedUserWaypoint) == "function" then
    pcall(track.SetSuperTrackedUserWaypoint, true)
  end
  playCue("click")
  Map.WaypointToast(label)
  return true
end

--- Brief UX1: the "Waypoint added" toast for a waypoint the client took, through UI/Toast.lua,
--- looked up at call time and pcall'd, so a build or a spec without it costs the toast and nothing
--- else. Answers whether a toast went up.
function Map.WaypointToast(label)
  local ui = ItemTree.UI
  local toast = type(ui) == "table" and ui.Toast or nil
  if type(toast) ~= "table" or type(toast.ShowWaypoint) ~= "function" then
    return false
  end
  local ok, shown = pcall(toast.ShowWaypoint, type(label) == "string" and label or nil)
  return ok and shown == true
end

--- Brief M8: the client's own name for one zone map (C_Map.GetMapInfo(uiMapID).name), or nil where
--- the client carries no such call, raises or names nothing.
function Map.MapName(uiMapId)
  local api = rawget(_G, "C_Map")
  if type(uiMapId) ~= "number" or type(api) ~= "table" or type(api.GetMapInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(api.GetMapInfo, uiMapId)
  if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
    return info.name
  end
  return nil
end

--- Where the client's own world map puts one instance's entrance on a zone map, in percent, or nil
--- where the client carries no such list, raises, or names no entrance of that name there.
function Map.ClientEntrance(uiMapId, names)
  local journal = rawget(_G, "C_EncounterJournal")
  if type(uiMapId) ~= "number" or type(journal) ~= "table" then
    return nil
  end
  if type(journal.GetDungeonEntrancesForMap) ~= "function" then
    return nil
  end
  local ok, list = pcall(journal.GetDungeonEntrancesForMap, uiMapId)
  if not ok then
    return nil
  end
  return Map.MatchEntrance(list, names)
end

--- Brief M8 (owner addition): the world boss one creature name is, where the Boss loot index lists
--- it under a world boss place: Core/ViewModel.lua ViewModel.WorldBoss's answer, or nil.
function Map.WorldBossSubject(nameIndex)
  local ViewModel = ItemTree.ViewModel
  if type(nameIndex) ~= "number" or type(ViewModel) ~= "table" or type(ViewModel.WorldBoss) ~= "function" then
    return nil
  end
  local ok, boss = pcall(ViewModel.WorldBoss, nameIndex)
  if ok and type(boss) == "table" then
    return boss
  end
  return nil
end

--- The INSTANCE the pane's map is rooted on, where it is one whose entrance zone is known: Core/
--- ViewModel.lua ViewModel.InstanceEntrance's answer, or nil for every other root. Read off
--- Tree.mapRoot the way Map.ZoneSubject is.
function Map.EntranceSubject()
  local Tree = treeModule()
  local root = Tree and Tree.mapRoot or nil
  local ViewModel = ItemTree.ViewModel
  if type(root) ~= "string" or type(ViewModel) ~= "table" or type(ViewModel.InstanceEntrance) ~= "function" then
    return nil
  end
  local ok, entrance = pcall(ViewModel.InstanceEntrance, root)
  if ok and type(entrance) == "table" then
    return entrance
  end
  return nil
end

--------------------------------------------------------------------------------
-- Brief MP1: where the player is
--
-- The marker is the world map's own player arrow on a layer of its own over the canvas: a frame
-- the size of the drawn map, a few levels over it so the arrow is drawn over every pin, which takes
-- no mouse at all (a press and a hover go straight through to the pins and the map under it), with
-- one texture on it: the arrow, or the dot where the client gives no facing.
--
-- Where: C_Map.GetBestMapForUnit("player") names the player's own map. Where that is the map on
-- screen, C_Map.GetPlayerMapPosition(<that map>, "player") is the place. Where the map on screen is
-- a parent of it (the zone over a cave's own map, a continent over a zone), the place on the
-- player's own map is carried up through the client's own translation: the child's rectangle on
-- the parent (C_Map.GetMapRectOnMap), decided once per map the player stands on, else the world
-- position the client puts that place at (C_Map.GetWorldPosFromMapPos) asked where it lies on the
-- map on screen (C_Map.GetMapPosFromWorldPos). Anywhere else (another zone, an instance, a place
-- the client will not give) there is no marker. Every call is declared in
-- Blizzard_APIDocumentationGenerated/MapDocumentation.lua, GetPlayerFacing in
-- PlayerScriptDocumentation.lua, on the `forever` branch of the Gethe/wow-ui-source mirror, and each
-- is looked up at call time.
--
-- When: a ticker (C_Timer.NewTicker every Map.PLAYER_TICK) runs while the layer is on screen and
-- not a moment longer. The layer's own OnHide stops it (the window going, the tab changing, a pane
-- hiding) and Map.Clear and Map.ClearArt stop it too; its OnShow starts it again over a map still
-- drawn. A tick makes no table and no frame: it reuses the one texture and the numbers on the
-- layer's record, and touches the texture only where something changed. Nothing is stored and
-- nothing is printed: the place is read, drawn and let go.
--------------------------------------------------------------------------------

--- C_Map where this client carries the two calls the marker cannot do without, else nil.
local function playerApi()
  local api = rawget(_G, "C_Map")
  if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function" then
    return nil
  end
  if type(api.GetPlayerMapPosition) ~= "function" then
    return nil
  end
  return api
end

--- Whether ItemTree may read a value the client handed over (Core/Util.lua Util.CanRead, brief
--- SV1, bible B10). A value it may not read is no place at all, and is never compared.
local function readable(value)
  local util = ItemTree.Util
  local check = type(util) == "table" and util.CanRead or nil
  if type(check) ~= "function" then
    return true
  end
  return check(value) and true or false
end

--- x and y out of what the client answers for a place: a Vector2DMixin (GetXY, else its x and y),
--- or on an older shape the two numbers themselves.
local function positionXY(first, second)
  if type(first) == "table" then
    if type(first.GetXY) == "function" then
      local ok, x, y = pcall(first.GetXY, first)
      if ok then
        return x, y
      end
    end
    return first.x, first.y
  end
  return first, second
end

--- The player's place on one map, 0 to 1, and the client's own answer for it (which the world
--- route hands back to the client), or nil.
local function askPlace(api, uiMapId)
  local ok, first, second = pcall(api.GetPlayerMapPosition, uiMapId, "player")
  if not ok then
    return nil
  end
  local x, y = positionXY(first, second)
  if not readable(x) or not readable(y) then
    return nil
  end
  x, y = Map.PlayerSpot(x, y)
  if not x then
    return nil
  end
  return x, y, first
end

--- How a place on the player's own map reaches the map on screen, where that is a parent of it:
--- the child's rectangle on the parent, "world" for the world position route, or false where the
--- map on screen is not a parent of the player's map or the client offers neither route. Asked
--- once per map the player stands on while one map is on screen (the layer keeps the answer).
local function parentRoute(api, own, shown)
  if type(api.GetMapInfo) ~= "function" then
    return false
  end
  local at, found = own, false
  for _ = 1, Map.PLAYER_PARENT_STEPS do
    local ok, info = pcall(api.GetMapInfo, at)
    local parent = ok and type(info) == "table" and info.parentMapID or nil
    if type(parent) ~= "number" or parent == 0 or parent == at then
      break
    end
    if parent == shown then
      found = true
      break
    end
    at = parent
  end
  if not found then
    return false
  end
  if type(api.GetMapRectOnMap) == "function" then
    local ok, minX, maxX, minY, maxY = pcall(api.GetMapRectOnMap, own, shown)
    if ok then
      local rect = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
      if Map.RectSpot(rect, 0.5, 0.5) then
        return rect
      end
    end
  end
  if type(api.GetWorldPosFromMapPos) == "function" and type(api.GetMapPosFromWorldPos) == "function" then
    return "world"
  end
  return false
end

-- Brief DM1 (QA item 134): the pretend position (`/itemtree demo at`, Core/Demo.lua Demo.At) as
-- { map, x, y } (x and y 0 to 100), or nil while the character's own stands.
local function demoAt()
  local demo = ItemTree.Demo
  if type(demo) ~= "table" or type(demo.At) ~= "function" then
    return nil
  end
  local ok, at = pcall(demo.At)
  if ok and type(at) == "table" and type(at.map) == "number" and tonumber(at.x) and tonumber(at.y) then
    return at
  end
  return nil
end

-- The pretend place as the client's own answer would be, for the world route: one vector per
-- pretend position, made once and kept (a tick makes no table), through the client's constructor.
local demoVector = { at = nil, vector = nil }

local function demoAnswer(at)
  if demoVector.at == at then
    return demoVector.vector
  end
  local vector = nil
  local make = globalFn("CreateVector2D")
  if make then
    local ok, made = pcall(make, at.x / 100, at.y / 100)
    vector = ok and type(made) == "table" and made or nil
  end
  demoVector.at, demoVector.vector = at, vector
  return vector
end

--- Where the player is on the map the layer shows, 0 to 1, or nil. Brief DM1: the pretend position
--- while it is set (the marker stands there; the character never moves).
local function playerSpot(player)
  local api = playerApi()
  if not api then
    return nil
  end
  local at = demoAt()
  local own
  if at then
    own = at.map
  else
    local okMap, best = pcall(api.GetBestMapForUnit, "player")
    if not okMap or type(best) ~= "number" or not readable(best) then
      return nil
    end
    own = best
  end
  local shown = player.map
  if own == shown then
    if at then
      return Map.PlayerSpot(at.x / 100, at.y / 100)
    end
    local x, y = askPlace(api, shown)
    return x, y
  end
  local route = player.via[own]
  if route == nil then
    route = parentRoute(api, own, shown)
    player.via[own] = route
  end
  if not route then
    return nil
  end
  local x, y, answer
  if at then
    x, y = Map.PlayerSpot(at.x / 100, at.y / 100)
    answer = x and demoAnswer(at) or nil
  else
    x, y, answer = askPlace(api, own)
  end
  if not x then
    return nil
  end
  if route ~= "world" then
    return Map.RectSpot(route, x, y)
  end
  -- The world route hands the client's own answer back to it, so this side makes no vector.
  if type(answer) ~= "table" then
    return nil
  end
  local okWorld, continent, world = pcall(api.GetWorldPosFromMapPos, own, answer)
  if not okWorld or continent == nil or world == nil then
    return nil
  end
  local okOn, onMap, position = pcall(api.GetMapPosFromWorldPos, continent, world, shown)
  if not okOn or onMap ~= shown then
    return nil
  end
  local px, py = positionXY(position)
  if not readable(px) or not readable(py) then
    return nil
  end
  return Map.PlayerSpot(px, py)
end

--- The way the player faces, in radians, or nil where the client does not say.
local function playerFacing()
  local fn = globalFn("GetPlayerFacing")
  if not fn then
    return nil
  end
  local ok, facing = pcall(fn)
  if not ok or not readable(facing) then
    return nil
  end
  return facing
end

--- Puts one face on the marker's texture at its size: the arrow as the client draws it, the dot
--- in the gold the client's own titles wear. A layer whose client will not draw the arrow, or will
--- not turn a texture, wears the dot from then on, and one that will draw neither a flat block of
--- the gold, so the place is still marked. Answers the face it put on.
local function wearFace(player, key)
  local texture = player.arrow
  if key == Map.PLAYER_ARROW_KEY and player.noArrow then
    key = Map.PLAYER_DOT_KEY
  end
  local applied, drew = pcall(Assets.Apply, texture, key, false)
  if not (applied and drew) and key == Map.PLAYER_ARROW_KEY then
    player.noArrow = true
    key = Map.PLAYER_DOT_KEY
    applied, drew = pcall(Assets.Apply, texture, key, false)
  end
  local size = key == Map.PLAYER_ARROW_KEY and player.size or player.dotSize
  if type(texture.SetSize) == "function" then
    texture:SetSize(size, size)
  end
  if key == Map.PLAYER_ARROW_KEY then
    if type(texture.SetVertexColor) == "function" then
      pcall(texture.SetVertexColor, texture, 1, 1, 1)
    end
    if type(texture.SetAlpha) == "function" then
      pcall(texture.SetAlpha, texture, 1)
    end
  elseif applied and drew then
    tint(texture, Map.PLAYER_DOT_COLOUR, 1)
  elseif type(texture.SetColorTexture) == "function" then
    local colour = Theme.ColorTable(Map.PLAYER_DOT_COLOUR)
    if colour then
      pcall(texture.SetColorTexture, texture, colour.r, colour.g, colour.b, 1)
    end
  end
  player.face, player.turned = key, nil
  return key
end

--- Turns the texture, only where the turn has changed. Answers false where the client would not.
local function turnFace(player, rotation)
  if player.turned == rotation then
    return true
  end
  local texture = player.arrow
  if type(texture.SetRotation) ~= "function" or not pcall(texture.SetRotation, texture, rotation) then
    return false
  end
  player.turned = rotation
  return true
end

--- One tick's work: reads the place and the facing, and moves, turns, shows or hides the one
--- texture. Answers whether the marker is up.
local function placePlayer(player)
  local texture = player.arrow
  local x, y = playerSpot(player)
  if not x then
    if player.up ~= false then
      texture:Hide()
      player.up = false
    end
    return false
  end
  local key, rotation = Map.PlayerFace(playerFacing())
  if key == Map.PLAYER_ARROW_KEY and player.noArrow then
    key = Map.PLAYER_DOT_KEY
  end
  if player.face ~= key then
    key = wearFace(player, key)
  end
  if key ~= Map.PLAYER_ARROW_KEY then
    rotation = 0
  end
  if not turnFace(player, rotation) and key == Map.PLAYER_ARROW_KEY then
    -- An arrow that cannot be turned points the wrong way, so it is the dot instead.
    player.noArrow = true
    wearFace(player, Map.PLAYER_DOT_KEY)
    turnFace(player, 0)
  end
  if player.x ~= x or player.y ~= y then
    local offsetX, offsetY = Map.PlayerOffset(x, y, player.width, player.height)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", player.holder, "TOPLEFT", offsetX, offsetY)
    player.x, player.y = x, y
  end
  if player.up ~= true then
    texture:Show()
    player.up = true
  end
  return true
end

--- Stops the ticker, or the frame driver a client without C_Timer runs instead. Answers whether
--- either was running.
function Map.StopPlayer()
  local ticker, driver = Map.playerTicker, Map.playerDriver
  Map.playerTicker, Map.playerDriver = nil, nil
  if type(ticker) == "table" and type(ticker.Cancel) == "function" then
    pcall(ticker.Cancel, ticker)
  end
  if driver ~= nil then
    setScript(driver, "OnUpdate", nil)
  end
  return ticker ~= nil or driver ~= nil
end

--- The layer's record on the parts the map is drawing now, where it has a map to mark.
local function livePlayer()
  local parts = Map.parts
  local player = type(parts) == "table" and parts.player or nil
  if type(player) ~= "table" or player.map == nil then
    return nil
  end
  return player
end

--- One tick. Where no marked map is on screen it does nothing at all and stops the ticker; a place
--- the client will not let this side read is no marker for the tick, never an error per tick.
function Map.PlayerTick()
  local player = livePlayer()
  if not player then
    Map.StopPlayer()
    return false
  end
  local holder = player.holder
  if type(holder.IsVisible) == "function" then
    local ok, visible = pcall(holder.IsVisible, holder)
    if ok and visible == false then
      Map.StopPlayer()
      return false
    end
  end
  local ok, up = pcall(placePlayer, player)
  if ok then
    return up
  end
  if type(player.arrow.Hide) == "function" then
    player.arrow:Hide()
  end
  player.up = false
  return false
end

local function tickPlayer()
  return Map.PlayerTick()
end

--- The driver on a client without C_Timer: the layer's own OnUpdate, which the client only runs
--- while the layer is on screen, throttled to the ticker's rate.
local function onPlayerUpdate(_, elapsed)
  local player = livePlayer()
  if not player then
    Map.StopPlayer()
    return
  end
  player.elapsed = (player.elapsed or 0) + (tonumber(elapsed) or 0)
  if player.elapsed >= Map.PLAYER_TICK then
    player.elapsed = 0
    Map.PlayerTick()
  end
end

--- Starts the ticker for a marked map, once: a second start while one runs is nothing.
local function startPlayer(player)
  if Map.playerTicker ~= nil or Map.playerDriver ~= nil then
    return true
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.NewTicker) == "function" then
    local ok, ticker = pcall(timer.NewTicker, Map.PLAYER_TICK, tickPlayer)
    if ok and ticker then
      Map.playerTicker = ticker
      return true
    end
  end
  player.elapsed = 0
  if setScript(player.holder, "OnUpdate", onPlayerUpdate) then
    Map.playerDriver = player.holder
    return true
  end
  return false
end

--- The layer's OnShow and OnHide: the ticker runs exactly while the layer of the map being drawn
--- is on screen. A layer of another pane coming and going leaves it alone.
local function onLayerShow(self)
  local player = livePlayer()
  if player and player.holder == self then
    startPlayer(player)
  end
end

local function onLayerHide(self)
  local parts = Map.parts
  local player = type(parts) == "table" and parts.player or nil
  if type(player) ~= "table" or player.holder == self then
    Map.StopPlayer()
  end
end

--- The layer and its one texture, made the first time a map is drawn on these parts and kept.
local function ensurePlayer(parts)
  if parts.player ~= nil then
    return parts.player or nil
  end
  local holder = newFrame("Frame", parts.canvas)
  local texture = nil
  if holder and type(holder.CreateTexture) == "function" then
    local ok, made = pcall(holder.CreateTexture, holder, nil, "OVERLAY", nil, 7)
    if ok and type(made) == "table" then
      texture = made
    end
  end
  if not texture then
    parts.player = false
    if holder and type(holder.Hide) == "function" then
      holder:Hide()
    end
    return nil
  end
  if type(holder.SetAllPoints) == "function" then
    holder:SetAllPoints(parts.canvas)
  end
  -- No mouse at all: the layer covers the whole map, and a press or a hover reaches the pins and
  -- the map under it exactly as it did before there was a marker.
  if type(holder.EnableMouse) == "function" then
    pcall(holder.EnableMouse, holder, false)
  end
  if type(holder.SetMouseClickEnabled) == "function" then
    pcall(holder.SetMouseClickEnabled, holder, false)
  end
  if type(holder.SetMouseMotionEnabled) == "function" then
    pcall(holder.SetMouseMotionEnabled, holder, false)
  end
  setScript(holder, "OnShow", onLayerShow)
  setScript(holder, "OnHide", onLayerHide)
  texture:Hide()
  parts.player = { holder = holder, arrow = texture, via = {} }
  return parts.player
end

--- Takes the marker down and stops the ticker. The layer is kept for the next map.
local function hidePlayer(parts)
  Map.StopPlayer()
  local player = type(parts) == "table" and parts.player or nil
  if type(player) ~= "table" then
    return false
  end
  player.map, player.up = nil, false
  if type(player.arrow.Hide) == "function" then
    player.arrow:Hide()
  end
  if type(player.holder.Hide) == "function" then
    player.holder:Hide()
  end
  return true
end

--- Puts the marker's layer over a drawn map of uiMapId at the fit's size, places the marker at
--- once and starts the ticker; takes it down where this client cannot place the player at all.
--- Answers whether the layer is up.
local function drawPlayer(parts, uiMapId, fit)
  if type(uiMapId) ~= "number" or type(fit) ~= "table" or not playerApi() then
    hidePlayer(parts)
    return false
  end
  local player = ensurePlayer(parts)
  if not player then
    return false
  end
  if player.map ~= uiMapId then
    player.via = {}
  end
  player.map = uiMapId
  player.width, player.height = fit.width, fit.height
  player.size, player.dotSize = Map.PlayerSize(fit.width), Map.PlayerDotSize(fit.width)
  player.face, player.turned, player.x, player.y = nil, nil, nil, nil
  local holder = player.holder
  local level = number(parts.canvas, "GetFrameLevel")
  if level and type(holder.SetFrameLevel) == "function" then
    pcall(holder.SetFrameLevel, holder, level + Map.PLAYER_LEVEL_STEP)
  end
  holder:Show()
  startPlayer(player)
  Map.PlayerTick()
  return true
end

--------------------------------------------------------------------------------
-- The painter
--------------------------------------------------------------------------------

--- The zone name over a creature's or a node's map, as a link to the zone's own page (brief Z1): an
--- invisible button laid over the caption's first line, the zone's name, which is already written
--- in the gold every link in the window wears. Made once per set of parts; hidden wherever the map
--- draws no zone name, and on a zone's own page, which is where the link would lead.
local function captionLink(parts)
  if parts.captionLink ~= nil then
    return parts.captionLink or nil
  end
  local button = newFrame("Button", parts.region)
  if not button then
    parts.captionLink = false
    return nil
  end
  registerClicks(button, { "LeftButtonUp" })
  setScript(button, "OnClick", function(self, mouseButton)
    if mouseButton ~= nil and mouseButton ~= "LeftButton" then
      return
    end
    Map.OpenZone(rawget(self, "itemTreeArea"))
  end)
  setScript(button, "OnEnter", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    local text = Map.ZoneLinkText(rawget(self, "itemTreeName"))
    if not text or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
      return
    end
    tooltip:SetOwner(self, "ANCHOR_RIGHT")
    if type(tooltip.AddLine) == "function" then
      tooltip:AddLine(text)
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  setScript(button, "OnLeave", hidePinTooltip)
  if type(button.Hide) == "function" then
    button:Hide()
  end
  parts.captionLink = button
  return button
end

--- Lays the caption link over the zone name the caption drew, or puts it away where there is none.
local function placeCaptionLink(parts, zone)
  local button = captionLink(parts)
  if not button then
    return false
  end
  local heading = parts.above and parts.above[1] or nil
  local name = type(zone) == "table" and zone.name or nil
  if
    type(heading) ~= "table"
    or not (type(heading.IsShown) ~= "function" or heading:IsShown())
    or type(zone.areaId) ~= "number"
    or type(name) ~= "string"
    or name == ""
  then
    button:Hide()
    return false
  end
  button.itemTreeArea = zone.areaId
  button.itemTreeName = name
  local wide = number(heading, "GetStringWidth")
  if not wide or wide <= 0 then
    wide = Map.TextWidth(name, Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD)
  end
  button:ClearAllPoints()
  button:SetPoint("TOP", heading, "TOP", 0, 0)
  if type(button.SetSize) == "function" then
    button:SetSize(wide, Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD + Map.LINE_GAP)
  end
  button:Show()
  return true
end

local function hideCaptionLink(parts)
  local button = type(parts) == "table" and parts.captionLink or nil
  if type(button) == "table" and type(button.Hide) == "function" then
    button:Hide()
  end
end

--- How big the rectangle really is. A client that will not measure it gets the probe's own shape,
--- so there is always a layout rather than a divide by zero.
function Map.Box(region)
  local width, height = 0, 0
  if type(region) == "table" then
    if type(region.GetWidth) == "function" then
      local ok, value = pcall(region.GetWidth, region)
      if ok then
        width = tonumber(value) or 0
      end
    end
    if type(region.GetHeight) == "function" then
      local ok, value = pcall(region.GetHeight, region)
      if ok then
        height = tonumber(value) or 0
      end
    end
  end
  if width <= 0 then
    width = Map.BOX_W
  end
  if height <= 0 then
    height = Map.BOX_H
  end
  return width, height
end

--- How tall one written line is: the client's own measure where it answers (a line that wrapped is
--- two or more rows tall), else Map.TextRows' estimate. Brief M12: the block under the map was
--- counted at one row a line, so a wrapped note line ran past the reserved room.
local function lineHeight(fontString, line, width, size)
  local measured = number(fontString, "GetStringHeight")
  if measured and measured > 0 then
    return measured
  end
  return Map.TextRows(type(line) == "table" and line.text or nil, width, size) * size
end

--- Lays a block of lines out from one anchor downwards, and answers how tall it came to.
local function layOut(pool, lines, width, anchor, point, offsetY)
  local size = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_MD
  local previous, drawn, tall = nil, 0, 0
  for index, line in ipairs(lines) do
    local fontString = pool.get(index)
    if fontString and writeLine(fontString, width, line, size) then
      drawn = drawn + 1
      fontString:ClearAllPoints()
      if previous then
        fontString:SetPoint("TOP", previous, "BOTTOM", 0, -Map.LINE_GAP)
        tall = tall + Map.LINE_GAP + lineHeight(fontString, line, width, size)
      else
        fontString:SetPoint(point, anchor, point, 0, offsetY)
        tall = lineHeight(fontString, line, width, size)
      end
      previous = fontString
    end
  end
  hideFrom(pool.list, drawn + 1)
  if drawn == 0 then
    return 0
  end
  return tall
end

--- Hides every tile, pin, button and the zone dropdown with its list, and the canvas with them.
--- Called before the tab draws words instead of art, and by Tree.ClearMap when the tab, the root
--- or the window goes, so leaving the tab, switching creature and hiding the window all leave
--- nothing behind.
function Map.Clear()
  Map.live, Map.drawnSize = nil, nil
  local parts = Map.parts
  -- Brief MP1: the player's marker goes and its ticker stops, whatever else was drawn.
  hidePlayer(parts)
  if type(parts) ~= "table" then
    return false
  end
  -- Brief UX2: the viewport and the zoom bar with it, and a drag in hand ends.
  showArt(parts, false)
  -- Silently: a list that goes because the window went is not something the player did.
  Map.CloseMenu()
  if type(parts.dropdown) == "table" and type(parts.dropdown.Hide) == "function" then
    parts.dropdown:Hide()
  end
  hideFrom(parts.tiles, 1)
  hideFrom(parts.explored or EMPTY, 1)
  hideFrom(parts.pins, 1)
  hideFrom(parts.lines or EMPTY, 1)
  hideFrom(parts.dots or EMPTY, 1)
  hideFrom(parts.buttons, 1)
  hideFrom(parts.above, 1)
  hideFrom(parts.below, 1)
  hideFrom(parts.centre, 1)
  hideCaptionLink(parts)
  return true
end

-- Puts the zone dropdown away without touching anything else.
local function hideDropdown(parts)
  if type(parts.dropdown) == "table" and type(parts.dropdown.Hide) == "function" then
    parts.dropdown:Hide()
  end
  return true
end

-- Every zone name's width, measured by the client where it will answer and estimated where it
-- will not, which is what the decision between a row and a dropdown is made on.
local function zoneWidths(parts, list)
  local ruler = parts.ruler
  local widths = {}
  for index, zone in ipairs(list) do
    local text = Map.ZoneText(zone)
    local measured = nil
    if ruler and setText(ruler, text) then
      measured = number(ruler, "GetStringWidth")
      if measured and measured <= 0 then
        measured = nil
      end
    end
    widths[index] = measured or Map.TextWidth(text, Map.FONT_SM)
  end
  return widths
end

--- Draws the row of zone buttons across the top of the rectangle, and answers how much room it
--- took. It is only reached where they fit on one row, but it still wraps: a client that cannot
--- build the dropdown keeps every zone on a button rather than losing the ones past the edge.
local function drawZoneButtons(parts, list, selected, widths, width)
  local get = pooled(parts.buttons, function(index)
    return newZoneButton(parts, index)
  end)
  local x, y, drawn = 0, 0, 0
  for index, zone in ipairs(list) do
    local button = get(index)
    if button then
      local text = Map.ZoneText(zone)
      local wide = Map.ButtonWidth(widths[index])
      if x > 0 and x + wide > width then
        x, y = 0, y + Map.BUTTON_H + Map.BUTTON_GAP
      end
      button.itemTreeArea = zone.areaId
      button.itemTreeOn = index == selected
      if type(button.SetSize) == "function" then
        button:SetSize(wide, Map.BUTTON_H)
      end
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", parts.region, "TOPLEFT", Map.PAD + x, -(Map.PAD + y))
      local label = rawget(button, "itemTreeLabel")
      if label then
        setFont(label, Map.FONT_SM)
        textColor(label, button.itemTreeOn and Map.COLOR_TITLE or Map.COLOR_BODY)
        setText(label, text)
        label:Show()
      end
      tint(rawget(button, "itemTreeFill"), Map.COLOR_BUTTON, 1)
      for _, edge in ipairs(rawget(button, "itemTreeEdges") or EMPTY) do
        tint(edge, button.itemTreeOn and Map.COLOR_BORDER_ON or Map.COLOR_BORDER, 1)
      end
      button:Show()
      drawn = drawn + 1
      x = x + wide + Map.BUTTON_GAP
    end
  end
  hideFrom(parts.buttons, drawn + 1)
  return y + Map.BUTTON_H + Map.GAP
end

--- Draws the one dropdown that stands in for the row, and answers how much room it took.
local function drawDropdown(parts, list, selected, widths, width)
  local dropdown = ensureMenu(parts)
  if not dropdown then
    -- A client that will not build the control keeps the buttons, wrapped onto as many rows as
    -- they take: every zone is still one press away, which is the whole point of the strip.
    Map.strip.control = "buttons"
    return drawZoneButtons(parts, list, selected, widths, width)
  end
  hideFrom(parts.buttons, 1)
  local label = Map.ZoneLabel(list[selected])
  local measured = nil
  if parts.ruler and setText(parts.ruler, label) then
    measured = number(parts.ruler, "GetStringWidth")
    if measured and measured <= 0 then
      measured = nil
    end
  end
  local wide = Map.ButtonWidth((measured or Map.TextWidth(label, Map.FONT_SM)) + Map.MENU_ACTION)
  if wide > width then
    wide = width
  end
  if type(dropdown.SetSize) == "function" then
    dropdown:SetSize(wide, Map.BUTTON_H)
  end
  dropdown:ClearAllPoints()
  dropdown:SetPoint("TOPLEFT", parts.region, "TOPLEFT", Map.PAD, -Map.PAD)
  local text = rawget(dropdown, "itemTreeLabel")
  if text then
    setFont(text, Map.FONT_SM)
    textColor(text, Map.COLOR_TITLE)
    setText(text, label)
    text:Show()
  end
  tint(rawget(dropdown, "itemTreeFill"), Map.COLOR_BUTTON, 1)
  for _, edge in ipairs(rawget(dropdown, "itemTreeEdges") or EMPTY) do
    tint(edge, Map.COLOR_BORDER_ON, 1)
  end
  dropdown:Show()
  -- What an open list draws from, so the list can never offer a zone the tab is not holding.
  Map.strip.width = wide
  return Map.BUTTON_H + Map.GAP
end

--- The zone strip: a row of buttons for two to five zones that fit, one dropdown otherwise, and
--- nothing at all for a creature known in one place. Answers how much room it took.
local function drawZoneStrip(parts, list, selected, width)
  local widths = zoneWidths(parts, list)
  local control = Map.ZoneControl(widths, width)
  Map.strip = { list = list, selected = selected, widths = widths, available = width, control = control }
  if control == "none" then
    hideFrom(parts.buttons, 1)
    hideDropdown(parts)
    Map.CloseMenu()
    return 0
  end
  if control == "menu" then
    return drawDropdown(parts, list, selected, widths, width)
  end
  hideDropdown(parts)
  Map.CloseMenu()
  return drawZoneButtons(parts, list, selected, widths, width)
end

-- Brief UX2: one piece of art the draw just placed at its 1x rect, written down for the zoom.
local function zoomRect(parts, texture, rect)
  local list = parts.zoomables
  list[#list + 1] =
    { kind = "rect", region = texture, x = rect.x, y = rect.y, width = rect.width, height = rect.height }
end

--- Puts the art in the canvas: one texture per tile, reused across creatures and across zones, and
--- everything the last draw used and this one does not is hidden rather than left behind.
local function drawTiles(parts, art, fit)
  local get = pooled(parts.tiles, function()
    if type(parts.canvas.CreateTexture) ~= "function" then
      return nil
    end
    local ok, texture = pcall(parts.canvas.CreateTexture, parts.canvas, nil, "ARTWORK")
    if ok and type(texture) == "table" then
      return texture
    end
    return nil
  end)
  local drawn = 0
  for _, rect in ipairs(Map.TileRects(art.grid, fit)) do
    local tile = get(rect.index)
    if tile then
      tile:ClearAllPoints()
      tile:SetPoint("TOPLEFT", parts.canvas, "TOPLEFT", rect.x, -rect.y)
      if type(tile.SetSize) == "function" then
        tile:SetSize(rect.width, rect.height)
      end
      if type(tile.SetTexture) == "function" then
        pcall(tile.SetTexture, tile, art.textures[rect.index])
      end
      if type(tile.SetTexCoord) == "function" then
        pcall(tile.SetTexCoord, tile, rect.left, rect.right, rect.top, rect.bottom)
      end
      tile:Show()
      zoomRect(parts, tile, rect)
      if rect.index > drawn then
        drawn = rect.index
      end
    end
  end
  hideFrom(parts.tiles, drawn + 1)
  return drawn
end

--- Brief MX1: the explored areas over the art, one texture per overlay tile out of their own pool,
--- one sublevel over the base tiles (two for Blizzard's draw on top entries) and under the paths
--- and the pins. Nothing to draw, or no answer at all, leaves the art exactly as it was.
local function drawExplored(parts, art, fit, uiMapId)
  parts.explored = parts.explored or {}
  watchExploration()
  local list = Map.Overlays(uiMapId)
  local get = pooled(parts.explored, function()
    if type(parts.canvas.CreateTexture) ~= "function" then
      return nil
    end
    local ok, texture = pcall(parts.canvas.CreateTexture, parts.canvas, nil, "ARTWORK", nil, 1)
    if ok and type(texture) == "table" then
      return texture
    end
    return nil
  end)
  local drawn = 0
  for _, rect in ipairs(Map.ExploredRects(list, art.grid, fit)) do
    local tile = get(drawn + 1)
    if not tile then
      break
    end
    drawn = drawn + 1
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", parts.canvas, "TOPLEFT", rect.x, -rect.y)
    if type(tile.SetSize) == "function" then
      tile:SetSize(rect.width, rect.height)
    end
    if type(tile.SetDrawLayer) == "function" then
      pcall(tile.SetDrawLayer, tile, "ARTWORK", rect.onTop and 2 or 1)
    end
    if type(tile.SetTexture) == "function" then
      pcall(tile.SetTexture, tile, rect.fileId)
    end
    if type(tile.SetTexCoord) == "function" then
      pcall(tile.SetTexCoord, tile, rect.left, rect.right, rect.top, rect.bottom)
    end
    tile:Show()
    zoomRect(parts, tile, rect)
  end
  hideFrom(parts.explored, drawn + 1)
  return drawn
end

--- Brief M11: one piece of the canvas a path is drawn with, in the path's colour at its alpha: the
--- plain white fill tinted, or the colour as a flat block where the client will not draw the file.
local function pathPaint(region)
  local applied, drew = pcall(Assets.Apply, region, Map.PATH_FILL_KEY)
  if applied and drew then
    tint(region, Map.PATH_COLOUR, Map.PATH_ALPHA)
  elseif type(region.SetColorTexture) == "function" then
    local r, g, b = Map.PinFallbackColour()
    pcall(region.SetColorTexture, region, r, g, b, Map.PATH_ALPHA)
  end
  return region
end

--- Brief M11: one piece of a path. The client's own line object where the canvas makes one (it
--- joins two points at any angle); otherwise a texture turned about its centre, and where the
--- client will not turn a texture, nothing, and the path is drawn as a dot at each point instead.
--- Both are ours, made on our own canvas, in the layer over the art and under the pins (a pin is a
--- child frame of the canvas, so it is always drawn over the canvas's own textures).
local function newSegment(parts)
  local canvas = parts.canvas
  if type(canvas.CreateLine) == "function" then
    local ok, line = pcall(canvas.CreateLine, canvas, nil, "OVERLAY")
    if ok and type(line) == "table" and type(line.SetStartPoint) == "function" then
      line.itemTreeShape = "line"
      return pathPaint(line)
    end
  end
  if type(canvas.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(canvas.CreateTexture, canvas, nil, "OVERLAY")
  if not ok or type(texture) ~= "table" then
    return nil
  end
  if type(texture.SetRotation) ~= "function" or not pcall(texture.SetRotation, texture, 0) then
    if type(texture.Hide) == "function" then
      texture:Hide()
    end
    parts.noSegments = true
    return nil
  end
  texture.itemTreeShape = "texture"
  return pathPaint(texture)
end

local function newDot(parts)
  local canvas = parts.canvas
  if type(canvas.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(canvas.CreateTexture, canvas, nil, "OVERLAY")
  if not ok or type(texture) ~= "table" then
    return nil
  end
  return pathPaint(texture)
end

--- Lays one piece of a path out between its two ends.
local function placeSegment(segment, piece, canvas, thickness)
  segment:ClearAllPoints()
  if rawget(segment, "itemTreeShape") == "line" then
    pcall(segment.SetStartPoint, segment, "TOPLEFT", canvas, piece.x1, piece.y1)
    pcall(segment.SetEndPoint, segment, "TOPLEFT", canvas, piece.x2, piece.y2)
    if type(segment.SetThickness) == "function" then
      pcall(segment.SetThickness, segment, thickness)
    end
  else
    segment:SetPoint("CENTER", canvas, "TOPLEFT", piece.cx, piece.cy)
    if type(segment.SetSize) == "function" then
      segment:SetSize(piece.length, thickness)
    end
    pcall(segment.SetRotation, segment, piece.angle)
  end
  segment:Show()
end

--- Brief M11: puts the zone's patrol paths on the drawn map, each a chain of pieces between its
--- points and a small dot at its first point, out of two pools that grow only to what the fullest
--- zone drawn so far needs. Everything this draw does not use is hidden. Answers how many pieces
--- it drew.
local function drawPaths(parts, zone, fit)
  parts.lines = parts.lines or {}
  parts.dots = parts.dots or {}
  local getLine = pooled(parts.lines, function()
    if parts.noSegments then
      return nil
    end
    return newSegment(parts)
  end)
  local getDot = pooled(parts.dots, function()
    return newDot(parts)
  end)
  local thickness = Map.PathThickness(fit.width)
  local dotSize = thickness * Map.PATH_DOT
  local lines, dots = 0, 0
  -- Brief UX2: every piece and dot written down at its 1x place for the zoom; a line keeps its
  -- thickness and a dot its size at every zoom.
  local zoomables = parts.zoomables
  local function dot(x, y)
    local frame = getDot(dots + 1)
    if frame then
      dots = dots + 1
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", parts.canvas, "TOPLEFT", x, y)
      if type(frame.SetSize) == "function" then
        frame:SetSize(dotSize, dotSize)
      end
      frame:Show()
      zoomables[#zoomables + 1] = { kind = "dot", region = frame, x = x, y = y }
    end
  end
  for _, path in ipairs(type(zone.paths) == "table" and zone.paths or EMPTY) do
    local pieces = Map.PathSegments(path.points, fit.width, fit.height)
    local drawn = 0
    for _, piece in ipairs(pieces) do
      local segment = getLine(lines + 1)
      if segment then
        lines = lines + 1
        drawn = drawn + 1
        placeSegment(segment, piece, parts.canvas, thickness)
        if rawget(segment, "itemTreeShape") == "line" then
          zoomables[#zoomables + 1] =
            { kind = "line", region = segment, x1 = piece.x1, y1 = piece.y1, x2 = piece.x2, y2 = piece.y2 }
        else
          zoomables[#zoomables + 1] = {
            kind = "turned",
            region = segment,
            x = piece.cx,
            y = piece.cy,
            length = piece.length,
            thickness = thickness,
          }
        end
      end
    end
    if pieces[1] then
      dot(pieces[1].x1, pieces[1].y1)
      -- A client that drew no piece still shows where the path runs: a dot at every point.
      if drawn == 0 then
        for _, piece in ipairs(pieces) do
          dot(piece.x2, piece.y2)
        end
      end
    end
  end
  hideFrom(parts.lines, lines + 1)
  hideFrom(parts.dots, dots + 1)
  return lines
end

--- Brief MP1 of 2026-10-20 (QA item 321): puts one pin Map.PinLevel(pin) levels over the canvas's
--- level (base), on every draw, so a pooled frame reused for another tier moves too. Our own frame,
--- pcall'd like the player's marker: a client that will not set it keeps the order it had. Answers
--- whether it took.
local function levelPin(frame, base, pin)
  if not base or type(frame.SetFrameLevel) ~= "function" then
    return false
  end
  return (pcall(frame.SetFrameLevel, frame, base + Map.PinLevel(pin)))
end

--- Puts the pins on the drawn map. One frame per pin out of a pool that never grows past what one
--- zone needs, because the table ships at most six per creature per zone.
local function drawPins(parts, zone, fit, creature)
  local get = pooled(parts.pins, function()
    return newPin(parts)
  end)
  local size = Map.PinSize(fit.width)
  local base = number(parts.canvas, "GetFrameLevel")
  local drawn = 0
  -- Brief M13: a world boss's small paths add their pins after the place's own.
  local all = zone.pins or EMPTY
  if type(zone.pathPins) == "table" and #zone.pathPins > 0 then
    all = {}
    for _, pin in ipairs(zone.pins or EMPTY) do
      all[#all + 1] = pin
    end
    for _, pin in ipairs(zone.pathPins) do
      all[#all + 1] = pin
    end
  end
  local waypoints = #all > 0 and Map.CanWaypoint(zone.map)
  for index, pin in ipairs(all) do
    local frame = get(index)
    if frame then
      local x, y = Map.PinOffset(pin.x, pin.y, fit.width, fit.height)
      frame:ClearAllPoints()
      -- The art is a marker whose point is at the bottom, which is where the position is. Brief
      -- M10: a pin that wears an icon (the instance portal) is a bordered square standing on a
      -- pointer, and the pointer's tip, the frame's bottom, is on the position too. Brief MP1 of
      -- 2026-10-20 (CS2's note): the plain pin's tip, its diamond's bottom corner, stands
      -- Map.PinTipLift(size) over its frame's bottom, so that frame goes that much lower.
      local face = pinFace(frame, pin.icon)
      local lift = face == Map.PIN_KEY and Map.PinTipLift(size) or 0
      frame:SetPoint("BOTTOM", parts.canvas, "TOPLEFT", x, y - lift)
      -- Brief UX2: its 1x place for the zoom, which moves it and never resizes it.
      local zoomables = parts.zoomables
      zoomables[#zoomables + 1] = { kind = "pin", region = frame, x = x, y = y, lift = lift, inside = true }
      applyMarker(frame, size, face ~= Map.PIN_KEY)
      -- Brief MP1 of 2026-10-20 (QA item 321): a Confirmed spot over every other pin, a weak one under.
      levelPin(frame, base, pin)
      -- The owner's standing rule of 2026-10-20: a weak spot (one unverified report) is drawn dimmed;
      -- every other pin, and a pooled frame reused for one, at full alpha.
      if type(frame.SetAlpha) == "function" then
        frame:SetAlpha(Map.PinAlpha(pin))
      end
      -- Brief CS2 (QA item 309): a Confirmed spot (a player's recorded find) wears the green outline
      -- round the pin's own diamond; no other pin does, nor a pin wearing an icon (another shape).
      pinOutline(frame, type(pin) == "table" and pin.confirmed == true and face == Map.PIN_KEY, size)
      -- Brief Z2: a zone's item pick hands each pin its own lines (Map.ZonePinLines).
      frame.itemTreeLines = type(pin.lines) == "table" and pin.lines
        or Map.TipLines(pin.name or creature, zone.name, pin)
      -- Brief M7: where the client can set a waypoint on this map, a left click sets it here.
      local at = waypoints and Map.WaypointAt(zone.map, pin) or nil
      frame.itemTreeWaypoint = at
      -- Brief UX1: what the pin is for, which the waypoint's toast says.
      frame.itemTreeWaypointFor = at and Map.WaypointFor(pin, creature) or nil
      pinClicks(frame, at ~= nil)
      frame:Show()
      drawn = drawn + 1
    end
  end
  hideFrom(parts.pins, drawn + 1)
  return drawn
end

--- Brief M12: the caption lines, the map and the note lines, laid out down the pane by
--- Map.BlockLayout so the map takes only the room the words leave. Both blocks of words are written
--- first so the client can say how tall they came to (a line that wrapped is taller), and the notes
--- are then put under the map. Answers the layout, or nil where the art cannot be laid out.
local function drawBlock(parts, art, captions, notes, above, below, width, height, top, uiMapId)
  local region = parts.region
  local inner = math.max(1, width - 2 * Map.PAD)
  local captionsH = layOut(above, captions, inner, region, "TOP", -(top + Map.PAD))
  local notesH = layOut(below, notes, inner, region, "TOP", -(top + Map.PAD))
  local block = Map.BlockLayout(art.grid, inner, height, top, captionsH, notesH)
  if not block then
    return nil
  end
  local fit = block.fit
  -- Brief UX2: the viewport takes the place the canvas had, and the canvas is drawn in it at 1x;
  -- applyView zooms it once the pins are on (Map.Draw, Map.DrawPlaces).
  local viewport = parts.viewport
  if type(viewport.SetSize) == "function" then
    viewport:SetSize(fit.width, fit.height)
  end
  viewport:ClearAllPoints()
  viewport:SetPoint("TOP", region, "TOP", 0, -block.canvasTop)
  if type(parts.canvas.SetSize) == "function" then
    parts.canvas:SetSize(fit.width, fit.height)
  end
  parts.canvas:ClearAllPoints()
  parts.canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
  showArt(parts, true)
  parts.zoomables = {}
  drawTiles(parts, art, fit)
  drawExplored(parts, art, fit, uiMapId)
  -- Brief MP1: the player's own place, where they are on this map, over everything else.
  drawPlayer(parts, uiMapId, fit)
  layOut(below, notes, inner, region, "TOP", -block.notesTop)
  Map.block = { width = width, height = height, layout = block }
  return block
end

--- The tab with no art in it: the places and the pins as plain words, laid out by the pane's own
--- default painter so the block reads exactly as it read before this file existed.
function Map.Fallback(region, nameIndex, zones, list, kind)
  Map.Clear()
  local Tree = treeModule()
  if not Tree or type(Tree.DrawMapZones) ~= "function" then
    return false
  end
  if list == nil then
    list = Map.Zones(nameIndex, zones, kind)
  end
  local lines = nil
  if type(list) == "table" and #list > 0 then
    lines = Map.TextLines(list, Map.TEXT_CAP)
  end
  return Tree.DrawMapZones(region, nameIndex, zones, lines) ~= false
end

--- Brief Q8: the QUEST the pane's map is rooted on, where it is one: everything known about it
--- (Core/ViewModel.lua ViewModel.Quest, whose client answer is already kept for the session, so
--- the Map tab asks the client nothing the Quest tab did not), or nil for every other root.
function Map.QuestSubject()
  local Tree = treeModule()
  local root = Tree and Tree.mapRoot or nil
  if type(root) ~= "string" or root:sub(1, 6) ~= "quest:" then
    return nil
  end
  local questId = tonumber(root:sub(7))
  local viewModel = ItemTree.ViewModel
  if not questId or type(viewModel) ~= "table" or type(viewModel.Quest) ~= "function" then
    return nil
  end
  local opts = nil
  local ui = ItemTree.UI
  local frame = type(ui) == "table" and ui.Frame or nil
  local vm = type(frame) == "table" and frame.vm or nil
  if type(vm) == "table" and type(vm.opts) == "table" then
    opts = vm.opts
  end
  local ok, facts = pcall(viewModel.Quest, questId, opts)
  if ok and type(facts) == "table" then
    return facts
  end
  return nil
end

--- Brief UX1: the name of the quest the pane's map is rooted on, in our own data (Core/Graph.lua
--- Graph.Name), for the waypoint words of its pins, or nil for any other root or no name. Guarded.
function Map.QuestName()
  local Tree = treeModule()
  local root = Tree and Tree.mapRoot or nil
  local graph = ItemTree.Graph
  if type(root) ~= "string" or root:sub(1, 6) ~= "quest:" or type(graph) ~= "table" then
    return nil
  end
  if type(graph.Name) ~= "function" then
    return nil
  end
  local ok, name = pcall(graph.Name, root)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

--- A QUEST's own Map tab (brief Q8): the recorded giver's and turn in's positions and the
--- client's objective mark, drawn by Map.DrawPlaces so the art, the zone strip and the fallback
--- to words are exactly a place's. With nothing placed, the quest's own words and no map.
function Map.DrawQuest(region, facts)
  -- Brief NW1: and every hand kept spot of a giver or a turn in found at one of several places.
  -- Brief UX1: the quest's own name for its pins' waypoint words.
  local places = Map.QuestPlaces(facts, Map.SpotPins, Map.QuestName())
  if #places > 0 and Map.DrawPlaces(region, places, Map.QuestNoteLines(facts, places)) then
    return true
  end
  Map.Clear()
  local Tree = treeModule()
  if not Tree or type(Tree.DrawMapZones) ~= "function" then
    return false
  end
  local lines = Map.QuestEmptyLines()
  if #places > 0 then
    lines = Map.TextLines(places, Map.TEXT_CAP)
  end
  return Tree.DrawMapZones(region, nil, EMPTY, lines) ~= false
end

--- THE PAINTER. Handed the rectangle, the creature's place in the shipped string table and the
--- places its rows state, it draws the selected zone's art with the creature's pins on it.
---
--- Never raises: every client call inside it is guarded, and anything it cannot do ends in the
--- words the tab drew before there was a map.
function Map.Draw(region, nameIndex, zones)
  -- Brief Q8: a quest's own page draws where its NPCs stood and its objective, and nothing else.
  local quest = Map.QuestSubject()
  if quest then
    return Map.DrawQuest(region, quest)
  end
  -- Brief Z1: a zone's own page draws the zone and the picked source's pins, and nothing else.
  local zoneFacts, pick, item = Map.ZoneSubject()
  if zoneFacts then
    return Map.DrawZone(region, zoneFacts, pick, item)
  end
  Map.last = { region = region, nameIndex = nameIndex, zones = zones }
  -- Brief D7: a herb, a vein, a fishing pool or a chest root draws its own pins on exactly the same
  -- art, strip and fallbacks. Everything below reads the three it answers.
  local kind = nil
  local objectIndex, objectZones, objectKind = Map.ObjectSubject()
  if objectIndex then
    nameIndex, zones, kind = objectIndex, objectZones, objectKind
  end
  local list, best = Map.Zones(nameIndex, zones, kind)
  -- Brief M8 (owner addition): a world boss's own page labels its pins as spawn points.
  Map.worldBoss = nil
  if kind == nil then
    local boss = Map.WorldBossSubject(nameIndex)
    local places = boss and Map.WorldBossPlaces(boss, list) or nil
    if places then
      Map.worldBoss = { name = boss.name, places = #places, pins = #places[1].pins }
      local Tree = treeModule()
      if Tree and type(Tree.MapPanel) == "function" then
        pcall(Tree.MapPanel, region)
      end
      local parts = build(region)
      if parts then
        hideCaptionLink(parts)
      end
      return Map.DrawPlaces(region, places, Map.WorldBossNotes(boss, places))
    end
  end
  -- Brief M3: a vendor's own pin, where the curated tier or the player's visit places it, with the
  -- name's Classic Era pins where it has them, and the lines under the map saying whose it is.
  local vendorNotes = nil
  if kind == nil then
    local positions = Map.VendorPositions()
    if positions then
      local withEra = #list > 0
      local own
      list, own = Map.WithVendorPins(list, positions)
      best = own or best
      vendorNotes = Map.VendorNoteLines(positions, withEra)
    end
  end
  -- A creature the table states no place for keeps brief E57's own wording, which is what the
  -- default painter draws for an empty zone list.
  if #list == 0 then
    return Map.Fallback(region, nameIndex, zones, list, kind)
  end
  if Map.artBlocked then
    return Map.Fallback(region, nameIndex, zones, list, kind)
  end
  -- Which zone is open is the player's and sticks while they are on this creature; a different
  -- creature opens on its own fullest zone rather than on whatever the last one was showing.
  local selected = best or 1
  local held = Map.selected
  if type(held) == "table" and held.name == nameIndex and held.kind == kind then
    for index, zone in ipairs(list) do
      if zone.areaId == held.areaId then
        selected = index
      end
    end
  end
  Map.selected = { name = nameIndex, kind = kind, areaId = list[selected].areaId }

  -- The pane's own inset panel first, so the art is drawn inside the same bordered rectangle the
  -- words are and not in a hole in the window.
  local Tree = treeModule()
  if Tree and type(Tree.MapPanel) == "function" then
    pcall(Tree.MapPanel, region)
  end
  local parts = build(region)
  if not parts then
    return Map.Fallback(region, nameIndex, zones, list, kind)
  end
  hideCaptionLink(parts)
  local zone = list[selected]
  local width, height = Map.Box(region)
  -- Brief M12: the pane this is drawn in, and at what size, so a change of size draws it again.
  Map.live, Map.drawnSize = region, { width = width, height = height }
  local inner = math.max(1, width - 2 * Map.PAD)
  local top = drawZoneStrip(parts, list, selected, inner)

  local above =
    { get = pooled(parts.above, function()
      return newFontString(region, "OVERLAY")
    end), list = parts.above }
  local below =
    { get = pooled(parts.below, function()
      return newFontString(region, "OVERLAY")
    end), list = parts.below }
  local centre = {
    get = pooled(parts.centre, function()
      return newFontString(region, "OVERLAY")
    end),
    list = parts.centre,
  }

  -- A place this client has no map of, which is every instance in this build. No art, no pins,
  -- and a block in the middle saying where the creature is and why there is nothing to look at.
  if not zone.map then
    Map.ClearArt()
    hideFrom(parts.above, 1)
    hideFrom(parts.below, 1)
    layOut(centre, Map.InsideLines(zone), inner, region, "TOP", -(top + math.max(0, (height - top) / 3)))
    return true
  end
  hideFrom(parts.centre, 1)

  local art, reason = Map.Art(zone.map)
  if not art then
    Map.artReason = reason
    return Map.Fallback(region, nameIndex, zones, list, kind)
  end

  local notes = vendorNotes or Map.NoteLines()
  local block = drawBlock(parts, art, Map.CaptionLines(zone), notes, above, below, width, height, top, zone.map)
  if not block then
    return Map.Fallback(region, nameIndex, zones, list, kind)
  end
  drawPaths(parts, zone, block.fit)
  drawPins(parts, zone, block.fit, Map.CreatureName(nameIndex, kind))
  -- Brief UX2: the zoom and pan this page's map is held at, or 1x.
  applyView(parts, block.fit, zone)
  -- Brief Z1: the zone's name over the map opens the zone's own page.
  placeCaptionLink(parts, zone)
  return true
end

--- A ZONE's own Map tab (brief Z1): the zone's art with the pins of the one source the player picked
--- on its Here tab, or no pins and the line that says how to pick one. An instance, which this
--- client has no map of, says so the way a creature inside one does (brief E60). Drawn by
--- Map.DrawPlaces, so the art, the fallback to words and the notes are exactly a place's.
---
--- The pins are decoded here and only here, for the one name picked: a zone of a thousand sources
--- decodes one pin string.
---
--- Brief Z2: item is the row picked in the Map view's item column, and where there is one it is
--- what the map pins: every source of that item here, one pin string decoded per named source (the
--- reader keeps the last four, E:_CachedPins), with each pin's own tooltip lines and the caption
--- naming the pick. Without one the map is brief Z1's, one source picked on the Here tab.
function Map.DrawZone(region, facts, pick, item)
  -- Brief M7: an instance's own page draws the zone that holds its entrance, where that is known.
  if type(facts) == "table" and facts.map == nil then
    local entrance = Map.EntranceSubject()
    if entrance then
      return Map.DrawEntrance(region, entrance)
    end
  end
  local era = eraModule()
  if type(item) == "table" then
    return Map.DrawZoneItem(region, facts, item, era)
  end
  local pins = nil
  if era and type(pick) == "table" and type(pick.nameIndex) == "number" then
    local reader = pick.kind == "object" and "ObjectPinsOf" or "PinsOf"
    if type(era[reader]) == "function" then
      local ok, decoded = pcall(era[reader], era, pick.nameIndex)
      if ok and type(decoded) == "table" then
        pins = decoded
      end
    end
  end
  local place = Map.ZonePlace(facts, pick, pins)
  if not place then
    return false
  end
  local Tree = treeModule()
  if Tree and type(Tree.MapPanel) == "function" then
    pcall(Tree.MapPanel, region)
  end
  local parts = build(region)
  if parts then
    hideCaptionLink(parts)
  end
  return Map.DrawPlaces(region, { place }, Map.ZoneNoteLines(facts))
end

--- Brief M7: an instance's own Map tab: the entrance zone's art with the one Entrance pin, where
--- the client's own entrance list names it or Classic Era places one of the instance's creatures
--- in that zone, drawn by Map.DrawPlaces so the art, the words and the fallback are a place's.
function Map.DrawEntrance(region, entrance)
  -- Brief M8: the map drawn may be the shipped pin's rather than the entrance zone's, and then the
  -- header names it by the client's own name for that map, else the entrance zone's.
  if type(entrance.zoneName) ~= "string" then
    entrance.zoneName = Map.MapName(entrance.map) or entrance.zoneHint
  end
  local client = Map.ClientEntrance(entrance.map, entrance.names)
  local places, notes = Map.EntrancePlaces(entrance, client)
  if not places then
    return false
  end
  Map.entrance = {
    map = entrance.map,
    client = client ~= nil,
    shipped = client == nil and type(entrance.shipped) == "table",
    pins = #places[1].pins,
    places = #places,
  }
  local Tree = treeModule()
  if Tree and type(Tree.MapPanel) == "function" then
    pcall(Tree.MapPanel, region)
  end
  local parts = build(region)
  if parts then
    hideCaptionLink(parts)
  end
  return Map.DrawPlaces(region, places, notes)
end

--- Brief Z2: a zone's map with the pins of every source of one item row. Each named source's pins
--- are decoded (creature pins out of mp for a drop, a skin, a pocket or a vendor; object pins out of
--- op for a node, a pool or a chest) and a creature's level range read (E:KindOf, a lookup), and
--- Map.ZoneItemPlace lays them out. Nothing else is asked of anything.
function Map.DrawZoneItem(region, facts, item, era)
  local decoded = {}
  for index, source in ipairs(type(item.sources) == "table" and item.sources or EMPTY) do
    local held = { pins = EMPTY }
    -- Brief M15: a placed object guess carries its one spot, and nothing is decoded for it.
    local spot = Map.PlacedPin(source)
    if spot then
      held.pins = { spot }
    elseif era and type(source.nameIndex) == "number" then
      local reader = source.kind == "object" and "ObjectPinsOf" or "PinsOf"
      if type(era[reader]) == "function" then
        local ok, pins = pcall(era[reader], era, source.nameIndex)
        if ok and type(pins) == "table" then
          held.pins = pins
        end
      end
      if source.kind == "npc" and type(era.KindOf) == "function" then
        local ok, kind, _, low, high = pcall(era.KindOf, era, source.nameIndex)
        if ok and kind ~= nil then
          held.low, held.high = low, high
        end
      end
    end
    decoded[index] = held
  end
  local place = Map.ZoneItemPlace(facts, item, decoded)
  if not place then
    return false
  end
  Map.zoneItem = { key = item.key, places = place.places, drawn = #place.pins, sources = #decoded }
  local Tree = treeModule()
  if Tree and type(Tree.MapPanel) == "function" then
    pcall(Tree.MapPanel, region)
  end
  local parts = build(region)
  if parts then
    hideCaptionLink(parts)
  end
  return Map.DrawPlaces(region, { place }, Map.ZoneNoteLines(facts))
end

--- A PLACE rather than a creature: the developer only tab of likely sources hands over the places it
--- guessed, and this draws them with the same strip, art, pins and fallbacks as a creature's map.
---
---   places  { { areaId, name, map, pins = { { x, y, name } } }, ... } in the caller's order,
---           which is the order the strip draws; the first opens first. map is the zone map id
---           or nil, and a place with none draws the block an instance draws (brief E60). Each
---           pin carries the name its tooltip leads with.
---   notes   the lines under the map, the caller's own words ({ text, muted }).
---
--- Never raises, and answers false only where there is nothing to draw or no frame to draw in.
function Map.DrawPlaces(region, places, notes)
  local list = type(places) == "table" and places or EMPTY
  Map.last = { region = region, places = list, notes = notes }
  if #list == 0 then
    return false
  end
  local selected = 1
  local held = Map.selected
  if type(held) == "table" and held.places == list then
    for index, zone in ipairs(list) do
      if zone.areaId == held.areaId then
        selected = index
      end
    end
  end
  Map.selected = { places = list, areaId = list[selected].areaId }
  local parts = build(region)
  if not parts then
    return false
  end
  local zone = list[selected]
  local width, height = Map.Box(region)
  Map.live, Map.drawnSize = region, { width = width, height = height }
  local inner = math.max(1, width - 2 * Map.PAD)
  local top = drawZoneStrip(parts, list, selected, inner)
  local function lines(pool)
    return {
      get = pooled(pool, function()
        return newFontString(region, "OVERLAY")
      end),
      list = pool,
    }
  end
  local above, below, centre = lines(parts.above), lines(parts.below), lines(parts.centre)
  local function words(block)
    Map.ClearArt()
    hideFrom(parts.above, 1)
    hideFrom(parts.below, 1)
    layOut(centre, block, inner, region, "TOP", -(top + Map.PAD))
    return true
  end
  if not zone.map then
    Map.ClearArt()
    hideFrom(parts.above, 1)
    hideFrom(parts.below, 1)
    layOut(centre, Map.InsideLines(zone), inner, region, "TOP", -(top + math.max(0, (height - top) / 3)))
    return true
  end
  if Map.artBlocked then
    return words(Map.PlaceLines(zone, Map.TEXT_CAP))
  end
  local art, reason = Map.Art(zone.map)
  if not art then
    Map.artReason = reason
    return words(Map.PlaceLines(zone, Map.TEXT_CAP))
  end
  hideFrom(parts.centre, 1)
  notes = type(notes) == "table" and notes or EMPTY
  local block = drawBlock(parts, art, Map.CaptionLines(zone), notes, above, below, width, height, top, zone.map)
  if not block then
    return words(Map.PlaceLines(zone, Map.TEXT_CAP))
  end
  drawPaths(parts, zone, block.fit)
  drawPins(parts, zone, block.fit, nil)
  -- Brief UX2: the zoom and pan this page's map is held at, or 1x.
  applyView(parts, block.fit, zone)
  return true
end

--- Hides the art and its pins without touching the words around them.
function Map.ClearArt()
  local parts = Map.parts
  hidePlayer(parts)
  if type(parts) ~= "table" then
    return false
  end
  -- Brief UX2: the viewport and the zoom bar with it, and a drag in hand ends.
  showArt(parts, false)
  hideFrom(parts.tiles, 1)
  hideFrom(parts.explored or EMPTY, 1)
  hideFrom(parts.pins, 1)
  hideFrom(parts.lines or EMPTY, 1)
  hideFrom(parts.dots or EMPTY, 1)
  return true
end

-- Brief G1: the redraw a zone pick starts runs under the window's boundary (Frame.GuardedRun),
-- which hands an error to the client's handler and puts the empty page up, rather than a bare
-- pcall that swallowed it. Answers whether it drew without raising. With no window (a spec that
-- loads this file alone), a straight call.
local function guardedRun(where, fn, ...)
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if type(frame) == "table" and type(frame.GuardedRun) == "function" then
    return frame.GuardedRun(where, fn, ...)
  end
  return true, fn(...)
end

--- What a zone button and a row of the zone list both do: remember the zone and draw the tab
--- again, with exactly the arguments the pane handed over last time. Nothing else in the window
--- has to be told.
function Map.Select(areaId)
  local last = Map.last
  if type(areaId) ~= "number" or type(last) ~= "table" then
    return false
  end
  if last.places then
    Map.selected = { places = last.places, areaId = areaId }
    return (guardedRun("Map.Select", Map.DrawPlaces, last.region, last.places, last.notes))
  end
  -- The subject is worked out again by Map.Draw, so an object root keeps its own kind here too.
  local objectIndex, _, kind = Map.ObjectSubject()
  Map.selected = { name = objectIndex or last.nameIndex, kind = kind, areaId = areaId }
  return (guardedRun("Map.Select", Map.Draw, last.region, last.nameIndex, last.zones))
end

--- Brief TA1 (the developer only tooltip audit): a drawn pin's own hover, made reachable the way
--- UI/Tree.lua's Tree.ShowRowTooltip is, on the index'th pin on show (the first by default) of the
--- map last drawn. Answers whether a tooltip went up.
function Map.ShowPinTooltip(index)
  local parts = Map.parts
  local pins = type(parts) == "table" and parts.pins or nil
  local wanted, seen = tonumber(index) or 1, 0
  for _, frame in ipairs(type(pins) == "table" and pins or EMPTY) do
    local ok, shown = false, false
    if type(frame) == "table" and type(frame.IsShown) == "function" then
      ok, shown = pcall(frame.IsShown, frame)
    end
    if ok and shown == true then
      seen = seen + 1
      if seen == wanted then
        return showPinTooltip(frame) == true
      end
    end
  end
  return false
end

--- Puts this file behind the pane's seam. Called at load; a build without UI/Tree.lua, and a spec
--- that loads this file on its own, cost nothing.
function Map.Install()
  local Tree = treeModule()
  if not Tree then
    return false
  end
  Tree.MapPainter = Map.Draw
  Tree.MapCleaner = Map.Clear
  return true
end

Map.Install()

return Map
