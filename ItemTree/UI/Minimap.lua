-- Minimap button, plus the default action the addon compartment entry calls.
--
-- Left click opens the tree window, right click opens the settings panel (a random item when
-- the client has no Settings API), and dragging moves the button around the minimap ring.
-- The angle is remembered account wide in ItemTree.db.minimap.angle.
--
-- The left click goes through Slash.OpenDefault, which is what the key binding with nothing
-- under the cursor runs as well: the window opens on the item this session last showed, or on a
-- random New in Forever item when it has shown none yet, and a click with that window already
-- up closes it again.
--
-- Hand rolled on purpose. The project ships only LibStub and CallbackHandler-1.0, so there
-- is no LibDBIcon and no LibDataBroker here. It is one button, one drag handler and one
-- remembered number, which is less code than the library wiring would be. A broker display's own
-- copy of LibDataBroker, when one is installed, gets a launcher from UI/DataBroker.lua (brief
-- LDB1), which runs this button's two click actions (Minimap.LeftClick, Minimap.RightClick).
--
-- No art is bundled: the icon, ring and highlight are client textures referenced by path
-- through UI/Assets.lua. The addon compartment entry itself is declared in ItemTree.toc as
-- "## AddonCompartmentFunc: ItemTree_OnAddonCompartmentClick"; the global it names is
-- defined in UI/Slash.lua next to the other command entry points.
--
-- First placement (brief MB1). LibDBIcon, which most addons use, starts every button at 225
-- degrees, so a fixed default lands in the same pile as everyone else's. An account with no
-- saved angle is placed once, about two seconds after entering the world, by looking at what is
-- already on the ring and taking the middle of the widest free arc. The angle it picks is saved,
-- so the button never moves again on its own; a drag saves what the player chose, and Reset
-- position in the settings runs the placement again.
--
-- A second button (brief B1), off by default behind the bossLootMinimapButton setting, opens the
-- window on the Boss loot tab. It shares every line of the placement code: its own angle in
-- ItemTree.db.bossLootMinimap, its own drag and its own Reset position row. Its first placement
-- takes the free spot on the ring nearest the main button (Minimap.NextFreeAngle), so the two sit
-- side by side, and from then on each is dragged on its own.
--
-- Minimap.OffsetFor, Minimap.AngleFromCursor, Minimap.OccupiedAngles, Minimap.FreeAngle,
-- Minimap.NextFreeAngle, Minimap.Enabled, Minimap.NeedsPlacement, Minimap.Angle, Minimap.SetAngle
-- and their Boss twins are pure and run under busted. Everything that touches a frame is guarded,
-- so this file loads with no WoW API present.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Minimap = {}
ItemTree.UI.Minimap = Minimap

local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Button art. The map itself is measured at placement time rather than assumed: see OffsetFor.
Minimap.SIZE = 31
-- The icon is the owner's full disc, edge to edge, with nothing of its own to crop, so it sits
-- centred on the tracking border's hole rather than on the button. MiniMap-TrackingBorder is 64
-- px; at BORDER_SIZE 53 its hole is centred at 17.0, -16.5 from the button's top left, and the
-- ring is solid from 11.2 px out to 14.1 px, with a soft inner shade from about 9 px. A 22 px
-- disc at 6, -5 is centred at 17, -16 with its 11 px edge tucked under the start of the solid
-- ring, so no map shows between disc and ring and about 3 px of ring shows all round.
Minimap.ICON_SIZE = 22
Minimap.ICON_X = 6
Minimap.ICON_Y = -5
Minimap.BORDER_SIZE = 53

-- The fallback angle, used before the first placement has run and whenever the ring has no
-- room. 160 is the left of the ring, a little above the middle: 65 degrees clear of LibDBIcon's
-- 225, where addon buttons pile up. On the Forever client (wow-ui-source, forever branch,
-- Blizzard_Minimap/Mainline/Minimap.xml) the tracking, mail and crafting order buttons, the clock
-- and the compartment sit in the strip above the map rather than on the ring, the zoom buttons sit
-- at the lower right (about 310 to 320 degrees) and only show on hover, and the expansion landing
-- page button, hidden there, would sit at about 217. Nothing of the client's own is at 160.
Minimap.DEFAULT_ANGLE = 160

-- Where LibDBIcon puts a button it has no saved position for. Always counted as taken, even with
-- nothing there yet, because addons that load later will put theirs there.
Minimap.LIBDBICON_ANGLE = 225

-- The angle every account was seeded with before brief MB1. A drag saves whatever atan2 answers,
-- which is never exactly a whole number of degrees in practice, so an exact 220 with no placed
-- mark is the old seed nobody moved, and is placed once like a fresh account.
Minimap.LEGACY_SEED_ANGLE = 220

-- Brief B1: the second button's face. A client icon is square with a baked border, so it is drawn
-- a little smaller than the owner's disc, round under the client's portrait mask, on the same
-- centre as the disc (17, -16 from the button's top left).
Minimap.BOSS_ICON_SIZE = 20
Minimap.BOSS_ICON_X = 7
Minimap.BOSS_ICON_Y = -6

-- Brief B1: how far round the ring the second button sits from the main one before its first
-- placement has run, so it never appears on top of it.
Minimap.BOSS_OFFSET = 40

-- How long after entering the world the first placement waits, so other addons' buttons exist.
Minimap.PLACEMENT_DELAY = 2

-- The largest frame the ring scan counts as a button. The map, its border art and the zone text
-- strip are all far bigger than this.
Minimap.SCAN_MAX_SIZE = 60

-- Classic Era's minimap, and the fallback for a frame that will not report a size.
Minimap.DEFAULT_MAP_SIZE = 140

-- How far past the edge of the map the button centre rides, which is where the ring border art
-- sits. LibDBIcon uses about 5. This file used to place the button at a fixed radius of 80,
-- which is exactly 140 / 2 + 10, so an inset of 10 reproduces the Classic Era placement to the
-- pixel while scaling to the much larger map the Forever beta ships.
Minimap.INSET = 10

-- Which quadrants of a minimap are round, keyed by the strings GetMinimapShape reports. The
-- quadrants are numbered the way the square minimap addons publish them: 1 lower right, 2 lower
-- left, 3 upper right, 4 upper left. A round quadrant puts the button on the ellipse, a square
-- one clamps it to the edge of the box so it still rides the border art.
Minimap.SHAPES = {
  ["ROUND"] = { true, true, true, true },
  ["SQUARE"] = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

-- Lua 5.1 has math.atan2; the browser harness runs Lua 5.3, where the two argument form of
-- math.atan replaces it. This file is not loaded by the harness, but the fallback keeps it
-- portable and costs nothing.
local atan2 = math.atan2 or math.atan

local function normalise(degrees)
  local value = tonumber(degrees)
  if not value then
    return Minimap.DEFAULT_ANGLE
  end
  value = value % 360
  if value < 0 then
    value = value + 360
  end
  return value
end

-- A usable half extent for one axis. A frame that has not been laid out yet reports 0, and a
-- frame that reports nothing at all falls back to Classic Era's map.
local function halfExtent(value, inset)
  local size = tonumber(value)
  if not size or size <= 0 then
    size = Minimap.DEFAULT_MAP_SIZE
  end
  return size / 2 + inset
end

-- Offset from the minimap centre for an angle in degrees, measured anticlockwise from east.
--
-- width and height are the live size of the map, so the ring the button rides is the ring the
-- player actually sees: a 140 px map and a 280 px map both put the button on their own border.
-- shape is what GetMinimapShape reports, or nil for round. inset is how far past the edge of
-- the map the button centre sits, defaulting to Minimap.INSET.
--
-- The angle means the same thing at every size, so a saved angle survives a resize untouched.
function Minimap.OffsetFor(width, height, angleDegrees, shape, inset)
  local pad = tonumber(inset) or Minimap.INSET
  local halfWidth = halfExtent(width, pad)
  local halfHeight = halfExtent(height, pad)
  local angle = math.rad(normalise(angleDegrees))
  local dx, dy = math.cos(angle), math.sin(angle)

  local quadrant = 1
  if dx < 0 then
    quadrant = quadrant + 1
  end
  if dy > 0 then
    quadrant = quadrant + 2
  end
  local quadrants = Minimap.SHAPES[type(shape) == "string" and shape:upper() or "ROUND"] or Minimap.SHAPES.ROUND
  if quadrants[quadrant] then
    return dx * halfWidth, dy * halfHeight
  end

  -- Square corner: run the direction out to the half diagonal and clamp it to the box, which
  -- walks the button along the straight edge instead of cutting across it. Shortening the
  -- diagonal by twice the inset is LibDBIcon's trick, and stops the button drifting off the
  -- corner of a square border where the art has no ring to sit on.
  local diagonalWidth = math.sqrt(2 * halfWidth * halfWidth) - 2 * pad
  local diagonalHeight = math.sqrt(2 * halfHeight * halfHeight) - 2 * pad
  local x = math.max(-halfWidth, math.min(dx * diagonalWidth, halfWidth))
  local y = math.max(-halfHeight, math.min(dy * diagonalHeight, halfHeight))
  return x, y
end

-- Angle in degrees of the cursor around the centre. Both points must already be in the same
-- coordinate space: the client side drag handler divides the cursor position by the
-- minimap's effective scale before calling this.
function Minimap.AngleFromCursor(cursorX, cursorY, centreX, centreY)
  local dx = (tonumber(cursorX) or 0) - (tonumber(centreX) or 0)
  local dy = (tonumber(cursorY) or 0) - (tonumber(centreY) or 0)
  return normalise(math.deg(atan2(dy, dx)))
end

-- The ring as other buttons occupy it. buttons is a list of { x = , y = , width = } frame
-- centres, and centreX, centreY the minimap's centre, all in the minimap's coordinate space
-- (pass 0, 0 or nothing when the centres are already relative to it). Returns a list of
-- { angle = , halfWidth = , distance = }: the bearing in degrees anticlockwise from east (the
-- same convention OffsetFor and LibDBIcon's minimapPos use), half the angle the button covers
-- as seen from the centre, and how far out it sits. An entry with no position, or exactly on
-- the centre, is skipped.
function Minimap.OccupiedAngles(buttons, centreX, centreY)
  local occupied = {}
  if type(buttons) ~= "table" then
    return occupied
  end
  local cx, cy = tonumber(centreX) or 0, tonumber(centreY) or 0
  for _, button in ipairs(buttons) do
    local x = type(button) == "table" and tonumber(button.x) or nil
    local y = type(button) == "table" and tonumber(button.y) or nil
    if x and y then
      local dx, dy = x - cx, y - cy
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance > 0 then
        local width = tonumber(button.width)
        if not width or width <= 0 then
          width = Minimap.SIZE
        end
        occupied[#occupied + 1] = {
          angle = normalise(math.deg(atan2(dy, dx))),
          halfWidth = math.deg(atan2(width / 2, distance)),
          distance = distance,
        }
      end
    end
  end
  return occupied
end

-- The shortest way round the ring between two bearings, 0 to 180.
local function separation(a, b)
  local difference = math.abs(a - b) % 360
  if difference > 180 then
    difference = 360 - difference
  end
  return difference
end

-- True when an occupied entry is on the ring the button rides. Anything well inside the map (a
-- map pin) or well outside it (a frame in the strip above) takes no room on the ring. The outer
-- bound leaves room for a square map's corners, which sit about 1.4 times the radius out.
local function onRing(entry, radius, size)
  local distance = tonumber(entry.distance)
  if not distance then
    return true
  end
  return distance >= radius - size and distance <= radius * 1.5 + size
end

-- The centre of the widest free arc on the ring, to half a degree. occupied is what
-- OccupiedAngles answers, radius how far out the button rides, buttonSize its width. A spot is
-- free when the button fits there with about one button width of margin on each side of it.
-- LibDBIcon's default is always taken, empty or not. Answers fallback (Minimap.DEFAULT_ANGLE when
-- nil) when the ring is empty or nothing fits. Two arcs of the same width go to the one nearer
-- the fallback.
-- Which whole degrees of the ring a button fits at, as { [degree] = true or false }, plus whether
-- any degree is taken at all. nil when nothing is on the ring. Shared by FreeAngle and
-- NextFreeAngle, so both read the ring with the same margin.
local function freeDegrees(occupied, radius, buttonSize)
  local ring = tonumber(radius)
  if not ring or ring <= 0 then
    ring = Minimap.DEFAULT_MAP_SIZE / 2 + Minimap.INSET
  end
  local size = tonumber(buttonSize)
  if not size or size <= 0 then
    size = Minimap.SIZE
  end

  local taken = {}
  if type(occupied) == "table" then
    for _, entry in ipairs(occupied) do
      if type(entry) == "table" and tonumber(entry.angle) and onRing(entry, ring, size) then
        taken[#taken + 1] = { angle = normalise(entry.angle), halfWidth = tonumber(entry.halfWidth) or 0 }
      end
    end
  end
  if #taken == 0 then
    return nil
  end
  taken[#taken + 1] = {
    angle = Minimap.LIBDBICON_ANGLE,
    halfWidth = math.deg(atan2(Minimap.SIZE / 2, ring)),
  }

  -- Our own half width and the margin, as angles on this ring.
  local clearance = math.deg(atan2(size / 2, ring)) + math.deg(atan2(size, ring))
  local free = {}
  local anyTaken = false
  for degree = 0, 359 do
    local ok = true
    for _, entry in ipairs(taken) do
      if separation(degree, entry.angle) < entry.halfWidth + clearance then
        ok = false
        break
      end
    end
    free[degree] = ok
    anyTaken = anyTaken or not ok
  end
  return free, anyTaken
end

function Minimap.FreeAngle(occupied, radius, buttonSize, fallback)
  local home = normalise(fallback == nil and Minimap.DEFAULT_ANGLE or fallback)
  local free, anyTaken = freeDegrees(occupied, radius, buttonSize)
  if not free or not anyTaken then
    return home
  end

  -- Walk once round from a taken degree, so every free run is seen whole, wrap included.
  local start = 0
  while free[start] do
    start = start + 1
  end
  local best, bestLength, bestDistance
  local runStart, runLength = nil, 0
  for step = 1, 360 do
    local degree = (start + step) % 360
    if free[degree] then
      if not runStart then
        runStart, runLength = degree, 0
      end
      runLength = runLength + 1
    elseif runStart then
      local centre = (runStart + (runLength - 1) / 2) % 360
      local distance = separation(centre, home)
      if not bestLength or runLength > bestLength or (runLength == bestLength and distance < bestDistance) then
        best, bestLength, bestDistance = centre, runLength, distance
      end
      runStart = nil
    end
  end
  if not best then
    return home
  end
  return best
end

-- Brief B1: the free whole degree nearest after, on either side, for a button that should sit
-- beside the one at after. occupied, radius and buttonSize are FreeAngle's, and after's own
-- button should be in occupied, which is what keeps the answer off it. Two spots the same distance
-- away go to the anticlockwise one. With nothing free, or nothing on the ring at all, it is
-- FreeAngle's answer with after as the fallback. Pure.
function Minimap.NextFreeAngle(occupied, radius, buttonSize, after)
  local home = normalise(after)
  local free, anyTaken = freeDegrees(occupied, radius, buttonSize)
  if free and anyTaken then
    local base = math.floor(home + 0.5)
    for step = 1, 180 do
      local up = (base + step) % 360
      if free[up] then
        return up
      end
      local down = (base - step) % 360
      if free[down] then
        return down
      end
    end
  end
  return Minimap.FreeAngle(occupied, radius, buttonSize, home)
end

function Minimap.Enabled()
  local settings = ItemTree.db and ItemTree.db.settings
  local value = settings and settings.minimapButton
  if value == nil then
    value = true
  end
  return value and true or false
end

-- True when this account's button has never been placed: no saved angle, or the old seed of
-- exactly 220 with no placed mark (see LEGACY_SEED_ANGLE). False with no saved variables at all,
-- because there is nowhere to keep the answer.
function Minimap.NeedsPlacement()
  local db = ItemTree.db
  if type(db) ~= "table" then
    return false
  end
  local saved = db.minimap
  if type(saved) ~= "table" or saved.angle == nil then
    return true
  end
  return saved.angle == Minimap.LEGACY_SEED_ANGLE and not saved.placed
end

function Minimap.Angle()
  local saved = ItemTree.db and ItemTree.db.minimap
  return normalise(saved and saved.angle or Minimap.DEFAULT_ANGLE)
end

function Minimap.SetAngle(degrees)
  local angle = normalise(degrees)
  local db = ItemTree.db
  if db then
    db.minimap = db.minimap or {}
    db.minimap.angle = angle
    -- Placed on purpose, by the first placement, Reset position or a drag: never the old seed.
    db.minimap.placed = true
  end
  return angle
end

-- Brief B1: the second button's setting, off unless the player turned it on.
function Minimap.BossEnabled()
  local settings = ItemTree.db and ItemTree.db.settings
  return (settings and settings.bossLootMinimapButton == true) and true or false
end

-- True when the second button has never been placed. It has no legacy seed to allow for.
function Minimap.BossNeedsPlacement()
  local db = ItemTree.db
  if type(db) ~= "table" then
    return false
  end
  local saved = db.bossLootMinimap
  return type(saved) ~= "table" or saved.angle == nil
end

-- The second button's angle, or, before its first placement, BOSS_OFFSET clockwise of the main
-- button, so it never draws on top of it while it waits.
function Minimap.BossAngle()
  local saved = ItemTree.db and ItemTree.db.bossLootMinimap
  if type(saved) == "table" and saved.angle ~= nil then
    return normalise(saved.angle)
  end
  return normalise(Minimap.Angle() - Minimap.BOSS_OFFSET)
end

function Minimap.SetBossAngle(degrees)
  local angle = normalise(degrees)
  local db = ItemTree.db
  if db then
    db.bossLootMinimap = type(db.bossLootMinimap) == "table" and db.bossLootMinimap or {}
    db.bossLootMinimap.angle = angle
  end
  return angle
end

-- The two buttons, each a small table of what differs between them, so the client code below is
-- written once. field is where the built frame is kept on Minimap.
local MAIN = {
  field = "button",
  frameName = "ItemTreeMinimapButton",
  icon = "MINIMAP_ICON",
  scheduled = "placementScheduled",
}
local BOSS = {
  field = "bossButton",
  frameName = "ItemTreeBossLootMinimapButton",
  icon = "MINIMAP_ICON_BOSS",
  scheduled = "bossPlacementScheduled",
  boss = true,
}

local function angleOf(which)
  if which.boss then
    return Minimap.BossAngle()
  end
  return Minimap.Angle()
end

local function setAngleOf(which, degrees)
  if which.boss then
    return Minimap.SetBossAngle(degrees)
  end
  return Minimap.SetAngle(degrees)
end

local function enabledOf(which)
  if which.boss then
    return Minimap.BossEnabled()
  end
  return Minimap.Enabled()
end

local function needsPlacementOf(which)
  if which.boss then
    return Minimap.BossNeedsPlacement()
  end
  return Minimap.NeedsPlacement()
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

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

-- Brief TX6: the buttons are ours under the client's Minimap frame, so nothing builds, moves,
-- shows or hides them in combat. Each of those asks first and, in combat, books one Refresh for
-- PLAYER_REGEN_ENABLED instead (once, however many asked; the flag clears when it runs). A drag
-- in combat still saves its angle, and the button goes there when combat ends.
Minimap.afterCombatBooked = false

function Minimap.OnCombatEnd()
  if not Minimap.afterCombatBooked then
    return false
  end
  Minimap.afterCombatBooked = false
  Minimap.Refresh()
  return true
end

-- In combat: books the Refresh and answers true. Out of combat answers false and the caller goes on.
local function deferredByCombat()
  if not inCombat() then
    return false
  end
  if Minimap.afterCombatBooked then
    return true
  end
  Minimap.afterCombatBooked = true
  if not Minimap.combatFrame then
    local createFrame = rawget(_G, "CreateFrame")
    local ok, frame = false, nil
    if type(createFrame) == "function" then
      ok, frame = pcall(createFrame, "Frame")
    end
    if ok and type(frame) == "table" then
      Minimap.combatFrame = frame
      if type(frame.RegisterEvent) == "function" then
        pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
      end
      if type(frame.SetScript) == "function" then
        pcall(frame.SetScript, frame, "OnEvent", function()
          Minimap.OnCombatEnd()
        end)
      end
    end
  end
  return true
end

-- The client's Minimap frame, which the local Minimap table above deliberately shadows.
local function minimapFrame()
  local frame = rawget(_G, "Minimap")
  if frame and type(frame.GetCenter) == "function" then
    return frame
  end
  return nil
end

-- True when the frame admits to a script type. A client that has dropped one raises when it is
-- hooked, so nothing is hooked without asking first, and a frame with no HasScript at all is
-- taken at its word. Same idiom as UI/Tooltip.lua.
local hasScript = ItemTree.Util.HasScript

-- One getter off the live frame, guarded and pcall'd, returning nil for anything that is not a
-- positive number. A minimap addon can leave the frame reporting 0 before it lays it out.
local function measure(frame, method)
  if type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  if not ok then
    return nil
  end
  value = tonumber(value)
  if value and value > 0 then
    return value
  end
  return nil
end

-- The live size of the map, read fresh every time the button is placed. The Forever beta ships
-- a much larger minimap than Classic Era, and minimap addons resize it whenever they like, so
-- caching this is what put the button inside the map art in the first place.
local function mapSize(parent)
  local width = measure(parent, "GetWidth")
  local height = measure(parent, "GetHeight")
  return width or height or Minimap.DEFAULT_MAP_SIZE, height or width or Minimap.DEFAULT_MAP_SIZE
end

-- What the client says the minimap is shaped like. Square minimap addons define this global;
-- without it every client is round.
local function minimapShape()
  local getShape = rawget(_G, "GetMinimapShape")
  if type(getShape) ~= "function" then
    return "ROUND"
  end
  local ok, shape = pcall(getShape)
  if ok and type(shape) == "string" then
    return shape
  end
  return "ROUND"
end

-- Slash loads after this file, so the command table is looked up at click time.
local function slash()
  local commands = ItemTree.Slash
  if type(commands) == "table" then
    return commands
  end
  return nil
end

local function reposition(button)
  local parent = minimapFrame()
  if not parent or deferredByCombat() then
    return false
  end
  local width, height = mapSize(parent)
  local angle = angleOf(button.itemTreeWhich or MAIN)
  local x, y = Minimap.OffsetFor(width, height, angle, minimapShape(), Minimap.INSET)
  button:ClearAllPoints()
  button:SetPoint("CENTER", parent, "CENTER", x, y)
  return true
end

-- Put the button back on the ring whenever the map changes size. HookScript is the one client
-- call here that can refuse, so the frame has to admit to the script first and the hook is
-- pcall'd, the way UI/Tooltip.lua takes its hooks. The flag is set before the attempt so a
-- refusal is not retried on every refresh.
local hookedSize = false

local function hookSize(parent)
  if hookedSize or type(parent.HookScript) ~= "function" then
    return
  end
  hookedSize = true
  if not hasScript(parent, "OnSizeChanged") then
    return
  end
  pcall(parent.HookScript, parent, "OnSizeChanged", function()
    if Minimap.button then
      reposition(Minimap.button)
    end
    if Minimap.bossButton then
      reposition(Minimap.bossButton)
    end
  end)
end

local function onDragUpdate(button)
  local parent = minimapFrame()
  local getCursorPosition = rawget(_G, "GetCursorPosition")
  if not parent or type(getCursorPosition) ~= "function" then
    return
  end
  local scale = parent:GetEffectiveScale()
  if not scale or scale == 0 then
    scale = 1
  end
  local cursorX, cursorY = getCursorPosition()
  local centreX, centreY = parent:GetCenter()
  if not (cursorX and centreX) then
    return
  end
  -- GetCenter is in the minimap's own coordinate space and GetCursorPosition is in screen
  -- pixels, so the cursor is divided by the effective scale to meet it. Both are read off the
  -- live frame, so the angle is right whatever size the map is, and what is saved is only ever
  -- a plain number of degrees.
  setAngleOf(button.itemTreeWhich or MAIN, Minimap.AngleFromCursor(cursorX / scale, cursorY / scale, centreX, centreY))
  reposition(button)
end

-- The button's two click actions, public so the broker launcher (UI/DataBroker.lua, brief LDB1)
-- runs exactly these rather than a copy. Left opens the window (Slash.OpenDefault), right the
-- settings panel (Slash.Default). Each does nothing on a build whose Slash module never loaded.
function Minimap.LeftClick()
  local commands = slash()
  if commands and type(commands.OpenDefault) == "function" then
    commands.OpenDefault()
  end
end

function Minimap.RightClick()
  local commands = slash()
  if commands and type(commands.Default) == "function" then
    commands.Default()
  end
end

-- The button's hover words: the title and the two click lines, in the order shown. The broker
-- launcher shows the same three; the button adds its drag line below them. Pure.
function Minimap.TooltipLines()
  return L["ItemTree"], L["Left click: open ItemTree"], L["Right click: settings"]
end

local function onClick(_button, mouseButton)
  if mouseButton == "RightButton" then
    Minimap.RightClick()
  else
    Minimap.LeftClick()
  end
end

local function onEnter(button)
  local tooltip = rawget(_G, "GameTooltip")
  if not tooltip or type(tooltip.SetOwner) ~= "function" then
    return
  end
  local title, left, right = Minimap.TooltipLines()
  tooltip:SetOwner(button, "ANCHOR_LEFT")
  tooltip:AddLine(title)
  tooltip:AddLine(left, 1, 1, 1)
  tooltip:AddLine(right, 1, 1, 1)
  tooltip:AddLine(L["Drag: move the button"], 1, 1, 1)
  tooltip:Show()
end

-- Brief B1: the key module, looked up at click time because it loads after this file.
local function keybind()
  local module = ItemTree.Keybind
  if type(module) == "table" then
    return module
  end
  return nil
end

-- The second button: a left click is the Boss loot key's own action (Keybind.OpenBossLoot, which
-- closes the window when it is already up on that tab), a right click is the main button's.
local function onBossClick(button, mouseButton)
  if mouseButton == "RightButton" then
    return onClick(button, mouseButton)
  end
  local module = keybind()
  if module and type(module.OpenBossLoot) == "function" then
    pcall(module.OpenBossLoot)
  end
end

local function onBossEnter(button)
  local tooltip = rawget(_G, "GameTooltip")
  if not tooltip or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_LEFT")
  tooltip:AddLine(L["ItemTree"])
  tooltip:AddLine(L["Left click: open Boss loot"], 1, 1, 1)
  tooltip:AddLine(L["Right click: settings"], 1, 1, 1)
  tooltip:AddLine(L["Drag: move the button"], 1, 1, 1)
  local module = keybind()
  if module and type(module.BossLootOn) == "function" then
    local ok, on = pcall(module.BossLootOn)
    if ok and not on then
      tooltip:AddLine(L["The Boss loot tab is turned off under Settings."], 1, 0.82, 0)
    end
  end
  tooltip:Show()
end

local function onLeave()
  local tooltip = rawget(_G, "GameTooltip")
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- Every texture goes through Assets so the path lives in one table and the harness can
-- report it. A texture the client does not have simply does not draw.
-- Brief B1: lays the entry's round mask over a square client icon, where the entry names one and
-- the client can mask. A client that cannot simply draws the icon square under the ring.
local function applyMask(button, icon, key)
  local entry = Assets.Get(key)
  if type(entry.mask) ~= "string" or type(button.CreateMaskTexture) ~= "function" then
    return false
  end
  if type(icon.AddMaskTexture) ~= "function" then
    return false
  end
  local ok, mask = pcall(button.CreateMaskTexture, button)
  if not ok or type(mask) ~= "table" then
    return false
  end
  pcall(mask.SetTexture, mask, entry.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  pcall(mask.SetAllPoints, mask, icon)
  if not pcall(icon.AddMaskTexture, icon, mask) then
    return false
  end
  button.iconMask = mask
  return true
end

local function applyTextures(button, which)
  which = which or MAIN
  local icon = button:CreateTexture(nil, "ARTWORK")
  if which.boss then
    icon:SetSize(Minimap.BOSS_ICON_SIZE, Minimap.BOSS_ICON_SIZE)
    icon:SetPoint("TOPLEFT", Minimap.BOSS_ICON_X, Minimap.BOSS_ICON_Y)
  else
    icon:SetSize(Minimap.ICON_SIZE, Minimap.ICON_SIZE)
    icon:SetPoint("TOPLEFT", Minimap.ICON_X, Minimap.ICON_Y)
  end
  Assets.Apply(icon, which.icon)
  button.icon = icon
  if which.boss then
    applyMask(button, icon, which.icon)
  end

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(Minimap.BORDER_SIZE, Minimap.BORDER_SIZE)
  border:SetPoint("TOPLEFT")
  Assets.Apply(border, "MINIMAP_BORDER")
  button.border = border

  if type(button.SetHighlightTexture) == "function" then
    button:SetHighlightTexture(Assets.Get("MINIMAP_HIGHLIGHT").path)
    local highlight = type(button.GetHighlightTexture) == "function" and button:GetHighlightTexture() or nil
    if highlight then
      Assets.Apply(highlight, "MINIMAP_HIGHLIGHT")
    end
  end
end

-- The ring scan. What is on the ring right now, as frame centres in the minimap's own coordinate
-- space: every button LibDBIcon knows, and every shown Button or small Frame parented to Minimap,
-- MinimapCluster or MinimapBackdrop (the client's own buttons and other home grown ones). Our own
-- button and anything with no position yet are skipped. Every read is pcall'd.
-- Drops pcall's ok flag and hands back every return value, or nothing when the call raised.
local function pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function call(frame, method, ...)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  return pass(pcall(frame[method], frame, ...))
end

local function shown(frame)
  if type(frame.IsShown) ~= "function" then
    return true
  end
  return call(frame, "IsShown") and true or false
end

local function scanRing(parent, skip)
  local found, seen = {}, {}
  local parentScale = measure(parent, "GetEffectiveScale") or 1

  local function add(frame)
    if type(frame) ~= "table" or seen[frame] or frame == skip or frame == parent then
      return
    end
    seen[frame] = true
    if not shown(frame) then
      return
    end
    local x, y = call(frame, "GetCenter")
    x, y = tonumber(x), tonumber(y)
    if not (x and y) then
      return
    end
    -- A frame's centre is in its own scale; bring it into the minimap's.
    local ratio = (measure(frame, "GetEffectiveScale") or parentScale) / parentScale
    found[#found + 1] = { x = x * ratio, y = y * ratio, width = (measure(frame, "GetWidth") or 0) * ratio }
  end

  local libStub = rawget(_G, "LibStub")
  if type(libStub) == "table" or type(libStub) == "function" then
    local ok, lib = pcall(libStub, "LibDBIcon-1.0", true)
    if ok and type(lib) == "table" then
      local names = call(lib, "GetButtonList")
      if type(names) == "table" then
        for _, name in ipairs(names) do
          add(call(lib, "GetMinimapButton", name))
        end
      end
    end
  end

  for _, holder in ipairs({ parent, rawget(_G, "MinimapCluster"), rawget(_G, "MinimapBackdrop") }) do
    if type(holder) == "table" and type(holder.GetChildren) == "function" then
      local children = { pcall(holder.GetChildren, holder) }
      if children[1] then
        for index = 2, #children do
          local child = children[index]
          if type(child) == "table" and not seen[child] then
            local kind = call(child, "GetObjectType")
            local width = measure(child, "GetWidth") or 0
            local height = measure(child, "GetHeight") or 0
            if
              (kind == "Button" or kind == "Frame")
              and width < Minimap.SCAN_MAX_SIZE
              and height < Minimap.SCAN_MAX_SIZE
            then
              add(child)
            end
          end
        end
      end
    end
  end
  return found
end

-- The other button's spot on the ring, as an OccupiedAngles entry, so each placement keeps off the
-- other button even before the scan can see it (not built yet, or not laid out). nil while that
-- button is off.
local function otherEntry(which, radius)
  local other = which.boss and MAIN or BOSS
  if not enabledOf(other) then
    return nil
  end
  if other.boss and Minimap.BossNeedsPlacement() then
    return nil
  end
  return { angle = angleOf(other), halfWidth = math.deg(atan2(Minimap.SIZE / 2, radius)), distance = radius }
end

-- Places one button now and saves its angle: the main one on the widest free arc, the second one
-- on the free spot nearest the main one. Answers the angle, or nil with no minimap.
local function placeButton(which)
  local parent = minimapFrame()
  if not parent then
    return nil
  end
  local centreX, centreY = call(parent, "GetCenter")
  local width, height = mapSize(parent)
  local radius = (width + height) / 4 + Minimap.INSET
  local occupied = {}
  if tonumber(centreX) and tonumber(centreY) then
    occupied = Minimap.OccupiedAngles(scanRing(parent, Minimap[which.field]), centreX, centreY)
  end
  local angle
  if which.boss then
    -- The main button always counts as taken here, on or off, so turning it back on later never
    -- lands it under this one.
    occupied[#occupied + 1] =
      { angle = Minimap.Angle(), halfWidth = math.deg(atan2(Minimap.SIZE / 2, radius)), distance = radius }
    angle = Minimap.SetBossAngle(Minimap.NextFreeAngle(occupied, radius, Minimap.SIZE, Minimap.Angle()))
  else
    occupied[#occupied + 1] = otherEntry(which, radius)
    angle = Minimap.SetAngle(Minimap.FreeAngle(occupied, radius, Minimap.SIZE, Minimap.DEFAULT_ANGLE))
  end
  local button = Minimap[which.field]
  if button then
    reposition(button)
  end
  return angle
end

--- Places the button on the widest free arc of the ring now, and saves the angle. Answers the
--- angle, or nil where there is no minimap to place against.
function Minimap.Place()
  return placeButton(MAIN)
end

--- Reset position in the settings: the one deliberate way to place the button again.
function Minimap.ResetPosition()
  return Minimap.Place()
end

--- Brief B1: the second button's placement, beside the main one. Answers the angle or nil.
function Minimap.PlaceBoss()
  return placeButton(BOSS)
end

--- Brief B1: the second button's Reset position row.
function Minimap.ResetBossPosition()
  return Minimap.PlaceBoss()
end

-- Runs one button's first placement once, delay seconds from now, if it still needs it then.
-- C_Timer.After is the normal route; a frame's OnUpdate is the fallback. Once a session each.
local function schedulePlacementOf(which, delay)
  if Minimap[which.scheduled] then
    return false
  end
  local wait = tonumber(delay) or Minimap.PLACEMENT_DELAY
  local function run()
    if needsPlacementOf(which) then
      placeButton(which)
    end
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" and pcall(timer.After, wait, run) then
    Minimap[which.scheduled] = true
    return true
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, waiter = pcall(createFrame, "Frame")
  if not ok or type(waiter) ~= "table" or type(waiter.SetScript) ~= "function" then
    return false
  end
  local elapsedTotal = 0
  waiter:SetScript("OnUpdate", function(self, elapsed)
    elapsedTotal = elapsedTotal + (tonumber(elapsed) or 0)
    if elapsedTotal >= wait then
      self:SetScript("OnUpdate", nil)
      run()
    end
  end)
  Minimap[which.scheduled] = true
  return true
end

-- Runs the first placement once, delay seconds from now, if the account still needs it then.
function Minimap.SchedulePlacement(delay)
  return schedulePlacementOf(MAIN, delay)
end

-- Brief B1: the same for the second button.
function Minimap.ScheduleBossPlacement(delay)
  return schedulePlacementOf(BOSS, delay)
end

-- The first placement waits for the world, and for the button to be on: an account that has it
-- off is placed when the setting is turned on (Refresh), not before. The main button's timer is
-- taken first, so where both wait the second one is placed after it and beside it.
local function maybeSchedule()
  if Minimap.worldEntered and Minimap.Enabled() and Minimap.NeedsPlacement() then
    Minimap.SchedulePlacement(Minimap.PLACEMENT_DELAY)
  end
  if Minimap.worldEntered and Minimap.BossEnabled() and Minimap.BossNeedsPlacement() then
    Minimap.ScheduleBossPlacement(Minimap.PLACEMENT_DELAY)
  end
end

--- PLAYER_ENTERING_WORLD's share of the loader, public so a spec can drive it.
function Minimap.OnWorldEntered()
  Minimap.worldEntered = true
  maybeSchedule()
end

-- Builds one button once. Returns nil outside the client, or on a client with no Minimap frame,
-- which leaves the addon working without a button.
local function buildButton(which)
  if Minimap[which.field] then
    return Minimap[which.field]
  end
  local createFrame = rawget(_G, "CreateFrame")
  local parent = minimapFrame()
  if type(createFrame) ~= "function" or not parent or deferredByCombat() then
    return nil
  end
  -- Brief TX2: made with no parent and moved onto the minimap at once. ItemTree never makes a
  -- frame with a client frame as its parent: on Forever the gamepad SmartNavigation post hooks
  -- CreateFrame and rebuilds an open panel's navigation state as the caller for any frame whose
  -- parent chain reaches one. SetParent is not hooked.
  local button = createFrame("Button", which.frameName)
  button:SetParent(parent)
  button.itemTreeWhich = which
  button:SetSize(Minimap.SIZE, Minimap.SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetMovable(true)
  button:SetClampedToScreen(true)
  applyTextures(button, which)
  if which.boss then
    button:SetScript("OnClick", onBossClick)
    button:SetScript("OnEnter", onBossEnter)
  else
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", onEnter)
  end
  button:SetScript("OnLeave", onLeave)
  button:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self.isDragging = nil
    self:SetScript("OnUpdate", nil)
  end)
  Minimap[which.field] = button
  hookSize(parent)
  reposition(button)
  return button
end

function Minimap.Build()
  return buildButton(MAIN)
end

-- Brief B1: the second button, built the first time it is turned on and never before.
function Minimap.BuildBoss()
  return buildButton(BOSS)
end

-- The second button follows its setting: built and shown when on, hidden when off (and never
-- built at all while it has never been on).
local function refreshBoss()
  if not Minimap.BossEnabled() then
    if Minimap.bossButton then
      Minimap.bossButton:Hide()
    end
    return
  end
  local button = Minimap.bossButton or Minimap.BuildBoss()
  if button then
    reposition(button)
    button:Show()
  end
end

-- Shows or hides the buttons for the current settings and puts them back on their angles.
-- Idempotent: each button is built once, the size hook is taken once, and the position is worked
-- out again from the live map every time. Answers whether the main button is there.
function Minimap.Refresh()
  if deferredByCombat() then
    return Minimap.button ~= nil
  end
  local button = Minimap.button or Minimap.Build()
  if not button then
    return false
  end
  if Minimap.Enabled() then
    reposition(button)
    button:Show()
  else
    button:Hide()
  end
  refreshBoss()
  maybeSchedule()
  return true
end

function Minimap.Init()
  Minimap.Build()
  return Minimap.Refresh()
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  -- PLAYER_LOGIN is the normal path. PLAYER_ENTERING_WORLD stays registered because the Forever
  -- beta sizes its minimap after login, and a zone change or a minimap addon can move it again;
  -- Init is idempotent, so running it repeatedly only re-reads the map and re-applies the angle.
  local loader = createFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:RegisterEvent("PLAYER_ENTERING_WORLD")
  loader:SetScript("OnEvent", function(self, event)
    Minimap.Init()
    if event == "PLAYER_ENTERING_WORLD" then
      Minimap.OnWorldEntered()
    end
    if event == "PLAYER_LOGIN" then
      self:UnregisterEvent("PLAYER_LOGIN")
      -- Brief LDB1: the broker launcher is registered here, once, beside the button. It loads
      -- after this file, so it is looked up now; Register is guarded and only ever runs once.
      local broker = ItemTree.UI.DataBroker
      if type(broker) == "table" and type(broker.Register) == "function" then
        pcall(broker.Register)
      end
    end
  end)
end

return Minimap
