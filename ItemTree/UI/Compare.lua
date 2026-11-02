-- Brief CS1 (owner, 2026-10-06): the comparison tooltips beside an ItemTree hover sit on the LEFT
-- of the item's tooltip, where a bag hover puts them, unless they would run off the left of the
-- screen there, in which case the client's own choice stands.
--
-- Why they sat on the right: every hover in the window anchors the game tooltip ANCHOR_RIGHT of
-- the row, and the client's TooltipComparisonManager:AnchorShoppingTooltips (Blizzard_SharedXMLGame/
-- Tooltip/TooltipComparisonManager.lua, mirror branch forever at 1.60.1.70235) reads that anchor
-- type and, when the comparison fits in the space to the right, puts it there. A bag slot anchors
-- ANCHOR_NONE, so the same code falls through to "whichever side has more room", which at a bag
-- in the bottom right corner is the left. The player reads the Equipped tooltip on the left there
-- and expects it on the left here.
--
-- How: a post hook (hooksecurefunc, the client's own additive hook) on that one method. After the
-- client has placed the two shopping tooltips, and only when the game tooltip's owner is a frame
-- inside ItemTree's window, the hook measures what the client measured (the left most edge of the
-- tooltip and its anchor frame, the width of the shown comparison tooltips, in the client's own
-- coordinates) and, when the comparison fits to the left, anchors it there with exactly the points
-- the client's own "left" branch sets. When it does not fit, the client's placement is left alone,
-- which is the one edge case the owner named. A client without the manager (Classic Era's
-- GameTooltip_AnchorComparisonTooltips) gets the same hook on that global.
--
-- Brief BQ3 (owner QA item 14, 2026-10-09: the comparison still opened on the right): the client
-- anchors the comparison inside the item tooltip's own fill, before that tooltip's Show, and on a
-- hover the tooltip can have no left edge to measure yet (hidden, or not sized). Where GetLeft
-- answers nothing the client and CS1 both read an edge of 0, nothing fits left of 0, and the
-- right hand placement stood. Not yet proven in game (no probe was run), but it is the one path
-- in the code that keeps it on the right
-- (TooltipComparisonManager.lua:61 to 74, then FinalizeItemTooltip in TooltipDataRules.lua:150 to
-- 174, which runs before the post calls and the Show in TooltipDataHandler.lua:298 to 300). Two
-- answers: the edge is worked out from the owner's geometry and the anchor type where the tooltip
-- has none (Compare.TooltipLeft), and a placement left on the right is looked at once more on the
-- next frame, when the tooltip has been placed (Compare.BookRecheck). The side itself is one pure
-- answer with the screen's edges in it (Compare.Side).
--
-- Rules kept: nothing is written onto any client frame or table (bible, taint lint brief T6);
-- every client answer goes through Util.CanRead before it is compared (brief SV1); the hook body
-- runs under Core/Guard.lua's boundary, so an error leaves the client's placement and nothing else.
local _, ItemTree = ...

local Compare = {}
ItemTree.Compare = Compare

local Util = ItemTree.Util
local canRead = Util.CanRead

-- The window every hover of ours sits under. Read at call time, so this file needs nothing of
-- UI/Frame.lua at load, and the name is the fallback for a namespace with no Frame in it.
Compare.WINDOW_NAME = "ItemTreeFrame"
-- How far up the owner's parent chain to look for the window: a tree row sits a handful of frames
-- under it (row, scroll child, scroll frame, pane, region, window), the deepest panes a few more.
Compare.PARENT_DEPTH = 12

-- The method hooked on the manager, and the Classic global hooked where there is no manager.
Compare.MANAGER = "TooltipComparisonManager"
Compare.MANAGER_METHOD = "AnchorShoppingTooltips"
Compare.CLASSIC_FUNCTION = "GameTooltip_AnchorComparisonTooltips"

-- A client number read into a local and checked before any arithmetic, or nil.
local function number(value)
  if not canRead(value) then
    return nil
  end
  return tonumber(value)
end

local function call(frame, method, ...)
  if type(frame) ~= "table" or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, answer = pcall(frame[method], frame, ...)
  if not ok or not canRead(answer) then
    return nil
  end
  return answer
end

local function frameName(frame)
  local name = call(frame, "GetName")
  if type(name) == "string" then
    return name
  end
  return nil
end

local function guarded(name, fn, ...)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    Guard.Run(name, fn, ...)
    return
  end
  fn(...)
end

-- Whether owner is ItemTree's window or a frame under it. Pure over the frames it is handed.
function Compare.IsOurs(owner)
  local Frame = ItemTree.Frame
  local window = type(Frame) == "table" and rawget(Frame, "frame") or nil
  local wanted = (type(Frame) == "table" and Frame.FRAME_NAME) or Compare.WINDOW_NAME
  local frame = owner
  for _ = 1, Compare.PARENT_DEPTH do
    if type(frame) ~= "table" then
      return false
    end
    if (window ~= nil and rawequal(frame, window)) or frameName(frame) == wanted then
      return true
    end
    frame = call(frame, "GetParent")
  end
  return false
end

-- Pure: the left most edge the client measures, the smaller of the tooltip's left and its
-- anchor frame's, or whichever one is known.
function Compare.LeftEdge(tooltipLeft, anchorLeft)
  if tooltipLeft ~= nil and anchorLeft ~= nil then
    return math.min(tooltipLeft, anchorLeft)
  end
  return tooltipLeft or anchorLeft or 0
end

-- Pure: whether a comparison totalWidth wide fits to the left of leftEdge, the client's own test
-- for its "left" side. Nothing shown fits nowhere.
function Compare.FitsLeft(leftEdge, totalWidth)
  leftEdge = tonumber(leftEdge)
  totalWidth = tonumber(totalWidth)
  if leftEdge == nil or totalWidth == nil or totalWidth <= 0 then
    return false
  end
  return totalWidth < leftEdge
end

-- Brief BQ3 (owner QA item 14, 2026-10-09: "our tooltip seems to always flex right"): the side
-- the comparison goes on, as one pure answer. Left wherever the comparison fits to the left of
-- leftEdge (the bag hover's side); else right wherever it fits between rightEdge and the screen's
-- right; else whichever side has more room, which is the client's own last resort
-- (TooltipComparisonManager.lua:97 to 101, mirror branch forever at 1.60.1.70245). screenWidth nil
-- reads as no room on the right. Answers "left" or "right".
function Compare.Side(leftEdge, rightEdge, totalWidth, screenWidth)
  if Compare.FitsLeft(leftEdge, totalWidth) then
    return "left"
  end
  local left = tonumber(leftEdge) or 0
  local right = tonumber(rightEdge)
  local screen = tonumber(screenWidth)
  local rightRoom = 0
  if right and screen then
    rightRoom = screen - right
  end
  local width = tonumber(totalWidth) or 0
  if width > 0 and width < rightRoom then
    return "right"
  end
  if rightRoom < left then
    return "left"
  end
  return "right"
end

-- Brief BQ3: where the game tooltip's left edge is, from its owner, for the moment the client
-- anchors the comparison before it has placed the tooltip (GetLeft answers nothing then, and the
-- client and CS1 both read that as an edge of 0, so the comparison went right). An ANCHOR_RIGHT or
-- ANCHOR_BOTTOMRIGHT tooltip starts at its owner's right, an ANCHOR_TOPLEFT one at its owner's left,
-- and an ANCHOR_LEFT or ANCHOR_BOTTOMLEFT one ends at its owner's left, so it starts a tooltip's
-- width before that (only where the width is known). nil for any other anchor or a missing number.
-- Pure.
function Compare.TooltipLeft(anchorType, ownerLeft, ownerRight, tooltipWidth)
  ownerLeft, ownerRight, tooltipWidth = tonumber(ownerLeft), tonumber(ownerRight), tonumber(tooltipWidth)
  if anchorType == "ANCHOR_RIGHT" or anchorType == "ANCHOR_BOTTOMRIGHT" then
    return ownerRight
  end
  if anchorType == "ANCHOR_TOPLEFT" then
    return ownerLeft
  end
  if (anchorType == "ANCHOR_LEFT" or anchorType == "ANCHOR_BOTTOMLEFT") and ownerLeft and tooltipWidth then
    return ownerLeft - tooltipWidth
  end
  return nil
end

-- Brief BQ28 (owner QA 2026-10-10 items 56 and 80, M6 failed twice: "The tooltip should touch the
-- corner of the icon like in bags (top right corner is probably the correct one for us)"): every
-- tooltip the window raises over an item (the item page header, a Sources or Used by row, a search
-- dropdown row) is placed the way the client places a bag slot's
-- (ContainerFrameItemButton_CalculateItemTooltipAnchors, Blizzard_UIPanels_Game/Mainline/
-- ContainerFrame.lua:1616 to 1626, mirror branch forever at 1.60.1.70245): its BOTTOMLEFT on the
-- hovered ICON's TOPRIGHT where the icon sits in the left half of the screen, else its BOTTOMRIGHT
-- on the icon's TOPLEFT; and, where the filled tooltip would run off the top of the screen above
-- the icon, below it instead (TOPLEFT on the icon's BOTTOMRIGHT, or TOPRIGHT on its BOTTOMLEFT).
--
-- Why BQ24 and BQ25b's anchors floated (the header's over the tab bar at the column's far top
-- right): both owned the tooltip with an anchor type on a hit frame as wide as the row or the
-- column (the header's headerHit), reaching the item with an offset (SetOwner(owner, "ANCHOR_RIGHT",
-- x, y)). The comparison manager re-anchors the item tooltip by its anchor type whenever the
-- Equipped comparison does not fit beside it, with an offset of its own
-- (TooltipComparisonManager.lua:104 to 117, SetAnchorType(anchorType, slideAmount, 0)), which
-- throws ours away and puts the tooltip back on the hit frame's far TOPRIGHT corner: above the
-- header, over the tab bar, at the right of the column, the Equipped comparison beside it. A bag
-- slot survives the same call only because its owner IS the slot, so the anchor type and the
-- points agree. Our icons are textures inside a wide hit frame, so the tooltip keeps its points
-- with ANCHOR_PRESERVE, the client's own form for a tooltip placed by hand that nothing may move
-- (QuestMapFrame.lua:2219 to 2221: ClearAllPoints, SetPoint, SetOwner(self, "ANCHOR_PRESERVE")),
-- and which the comparison manager never slides (TooltipComparisonManager.lua:104). The owner
-- stays the hovered frame, so everything keyed on it (the Ctrl redraw, IsOurs, the search list's
-- own hide) is unchanged.
--
-- Pure: where a tooltip goes on an icon. The icon's edges and the screen's are in the same units
-- (the UI's); tooltipHeight is the filled tooltip's height in those units, nil before the fill
-- (above the icon then, the bag slot's way). Answers { point, relativePoint, left, below,
-- rightSide }: the tooltip's point on the icon's relativePoint, its left edge where it is known
-- before the fill (the comparison's side rule reads it, Compare.anchorHint), and which corner it
-- took. nil without the icon's edges.
function Compare.IconAnchor(iconLeft, iconRight, iconTop, iconBottom, screenWidth, screenHeight, tooltipHeight)
  iconLeft, iconRight = tonumber(iconLeft), tonumber(iconRight)
  iconTop, iconBottom = tonumber(iconTop), tonumber(iconBottom)
  if not iconLeft or not iconRight or not iconTop or not iconBottom then
    return nil
  end
  local screen = tonumber(screenWidth)
  local rightSide = screen == nil or iconRight < screen / 2
  local tall, height = tonumber(screenHeight), tonumber(tooltipHeight)
  -- Below only where it does not fit above and there is more room below than above.
  local below = false
  if tall ~= nil and height ~= nil and iconTop + height > tall and tall - iconTop < iconBottom then
    below = true
  end
  local anchor = { below = below, rightSide = rightSide }
  if rightSide then
    anchor.point = below and "TOPLEFT" or "BOTTOMLEFT"
    anchor.relativePoint = below and "BOTTOMRIGHT" or "TOPRIGHT"
    anchor.left = iconRight
  else
    anchor.point = below and "TOPRIGHT" or "BOTTOMRIGHT"
    anchor.relativePoint = below and "BOTTOMLEFT" or "TOPLEFT"
  end
  return anchor
end

-- The last placement Compare.OwnIcon made, { owner, left }: tooltipEdges reads its left for the
-- moment before the tooltip has a place of its own. Our own table, never a client frame's.
Compare.anchorHint = nil

-- The last icon a tooltip was placed on, { tooltip, owner, region, below }, for Compare.FitIcon
-- after the fill. Our own table, never a client frame's.
Compare.iconPlaced = nil

-- A screen measure (GetScreenWidth, GetScreenHeight), or nil. Guarded.
local function screenMeasure(name)
  local read = rawget(_G, name)
  if type(read) ~= "function" then
    return nil
  end
  local ok, value = pcall(read)
  if ok and canRead(value) then
    return tonumber(value)
  end
  return nil
end

-- How a region's own units stand to the UI's (its effective scale over UIParent's; a texture that
-- will not say asks its parent), 1 where either will not answer. Guarded.
local function scaleRatio(region)
  local own = number(call(region, "GetEffectiveScale"))
  if not own then
    own = number(call(call(region, "GetParent"), "GetEffectiveScale"))
  end
  local ui = number(call(rawget(_G, "UIParent"), "GetEffectiveScale"))
  if own and ui and own > 0 and ui > 0 then
    return own / ui
  end
  return 1
end

-- The anchor for a region (the icon, or the hovered frame where the icon is not drawn), its edges
-- read in the UI's units. Guarded.
local function anchorFor(region, tooltipHeight)
  local ratio = scaleRatio(region)
  local function edge(method)
    local value = number(call(region, method))
    return value and value * ratio or nil
  end
  return Compare.IconAnchor(
    edge("GetLeft"),
    edge("GetRight"),
    edge("GetTop"),
    edge("GetBottom"),
    screenMeasure("GetScreenWidth"),
    screenMeasure("GetScreenHeight"),
    tooltipHeight
  )
end

-- The icon where it is drawn and placed, else nil. Guarded.
local function drawnIcon(icon)
  if type(icon) ~= "table" or call(icon, "IsShown") ~= true then
    return nil
  end
  if number(call(icon, "GetRight")) == nil then
    return nil
  end
  return icon
end

-- Puts the tooltip's corner on the region's. Guarded.
local function placeOn(tooltip, region, anchor)
  if type(tooltip.ClearAllPoints) ~= "function" or type(tooltip.SetPoint) ~= "function" then
    return false
  end
  if not pcall(tooltip.ClearAllPoints, tooltip) then
    return false
  end
  return (pcall(tooltip.SetPoint, tooltip, anchor.point, region, anchor.relativePoint, 0, 0))
end

-- Brief BQ28: owns the game tooltip on the hovered frame and places it on the icon's corner by
-- Compare.IconAnchor (the hovered frame's own corner where the icon is not drawn). Falls back to
-- the plain ANCHOR_RIGHT owner where nothing has edges yet. Call it on every show: a pooled row's
-- icon is read afresh each time. Answers the anchor type used, or nil where the tooltip could not
-- be owned. Guarded.
function Compare.OwnIcon(tooltip, owner, icon)
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" or type(owner) ~= "table" then
    return nil
  end
  Compare.iconPlaced = nil
  local region = drawnIcon(icon) or owner
  local anchor = anchorFor(region, nil)
  if anchor and placeOn(tooltip, region, anchor) and pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_PRESERVE") then
    local left = anchor.left
    if left ~= nil then
      left = left / scaleRatio(tooltip)
    end
    Compare.anchorHint = { owner = owner, left = left }
    Compare.iconPlaced = { tooltip = tooltip, owner = owner, region = region, below = anchor.below }
    return "ANCHOR_PRESERVE"
  end
  Compare.anchorHint = nil
  if not pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_RIGHT") then
    return nil
  end
  return "ANCHOR_RIGHT"
end

-- Brief BQ28: after the fill and the Show, the tooltip's height is known: where it would run off
-- the top of the screen above the icon it goes below it (Compare.IconAnchor). Only the tooltip
-- Compare.OwnIcon last placed, while the same frame still owns it. Answers "kept", "below",
-- "above", or nil where there was nothing to fit. Guarded.
function Compare.FitIcon(tooltip)
  local placed = Compare.iconPlaced
  if type(placed) ~= "table" or not rawequal(placed.tooltip, tooltip) then
    return nil
  end
  if not rawequal(call(tooltip, "GetOwner"), placed.owner) then
    return nil
  end
  local height = number(call(tooltip, "GetHeight"))
  if not height or height <= 0 then
    return nil
  end
  local anchor = anchorFor(placed.region, height * scaleRatio(tooltip))
  if not anchor then
    return nil
  end
  if anchor.below == placed.below then
    return "kept"
  end
  if not placeOn(tooltip, placed.region, anchor) then
    return nil
  end
  placed.below = anchor.below
  return anchor.below and "below" or "above"
end

-- The frame the comparison sits beside: the anchor frame, or for an embedded tooltip its
-- grandparent, as the client reads it.
local function sideAnchorOf(anchor)
  if type(anchor) ~= "table" then
    return nil
  end
  local embedded = rawget(anchor, "IsEmbedded")
  if canRead(embedded) and embedded then
    local parent = call(anchor, "GetParent")
    local grand = call(parent, "GetParent")
    if type(grand) == "table" then
      return grand
    end
  end
  return anchor
end

-- Puts the shown comparison tooltips on the left of the game tooltip when they fit there, with
-- the points the client's own left branch sets. Answers "left" when it moved them, "kept" when the
-- client's placement stands, and nil when there was nothing to measure.
-- Brief BQ3: the tooltip's left and right edges as the client measures them, falling back to its
-- owner's geometry (Compare.TooltipLeft) where the tooltip has not been placed yet. Either nil.
local function tooltipEdges(tooltip)
  local left = number(call(tooltip, "GetLeft"))
  local right = number(call(tooltip, "GetRight"))
  if left == nil then
    local owner = call(tooltip, "GetOwner")
    local anchorType = call(tooltip, "GetAnchorType")
    local width = number(call(tooltip, "GetWidth"))
    -- Brief BQ28: a tooltip placed on an icon by Compare.OwnIcon starts where that placed it.
    local hint = Compare.anchorHint
    if type(hint) == "table" and hint.left ~= nil and rawequal(hint.owner, owner) then
      left = hint.left
    else
      left = Compare.TooltipLeft(anchorType, number(call(owner, "GetLeft")), number(call(owner, "GetRight")), width)
    end
    if left ~= nil and right == nil and width ~= nil then
      right = left + width
    end
  end
  return left, right
end

-- What the last placement did, for a /run probe while the owner QAs it: "left", "kept: <why>" or
-- nil before any. In memory only.
Compare.lastOutcome = nil

function Compare.PlaceLeft(tooltip, anchor, primary, secondary, primaryShown, secondaryShown)
  if type(tooltip) ~= "table" or type(primary) ~= "table" then
    return nil
  end
  anchor = type(anchor) == "table" and anchor or tooltip
  local sideAnchor = sideAnchorOf(anchor) or tooltip
  local tipLeft, tipRight = tooltipEdges(tooltip)
  local anchorLeft, anchorRight = nil, nil
  if not rawequal(sideAnchor, tooltip) then
    anchorLeft, anchorRight = number(call(sideAnchor, "GetLeft")), number(call(sideAnchor, "GetRight"))
  end
  local leftEdge = Compare.LeftEdge(tipLeft, anchorLeft)
  local rightEdge = tipRight
  if anchorRight ~= nil and (rightEdge == nil or anchorRight > rightEdge) then
    rightEdge = anchorRight
  end
  local totalWidth = 0
  if primaryShown then
    totalWidth = totalWidth + (number(call(primary, "GetWidth")) or 0)
  end
  if secondaryShown and type(secondary) == "table" then
    totalWidth = totalWidth + (number(call(secondary, "GetWidth")) or 0)
  end
  local screen = rawget(_G, "GetScreenWidth")
  local screenWidth = nil
  if type(screen) == "function" then
    local ok, width = pcall(screen)
    if ok and canRead(width) then
      screenWidth = tonumber(width)
    end
  end
  -- Left only where it fits there: where it fits nowhere and the left has more room, the client
  -- already chose the left and slid the tooltip to make it fit, and its placement stands.
  if
    Compare.Side(leftEdge, rightEdge, totalWidth, screenWidth) ~= "left" or not Compare.FitsLeft(leftEdge, totalWidth)
  then
    if tipLeft == nil and anchorLeft == nil then
      Compare.lastOutcome = "kept: no geometry"
    else
      Compare.lastOutcome = "kept: no room on the left"
    end
    return "kept"
  end
  if type(primary.ClearAllPoints) ~= "function" or type(primary.SetPoint) ~= "function" then
    return nil
  end
  primary:ClearAllPoints()
  primary:SetPoint("TOP", anchor, 0, 0)
  primary:SetPoint("RIGHT", sideAnchor, "LEFT")
  if secondaryShown and type(secondary) == "table" and type(secondary.SetPoint) == "function" then
    if type(secondary.ClearAllPoints) == "function" then
      secondary:ClearAllPoints()
    end
    secondary:SetPoint("TOP", anchor, 0, 0)
    secondary:SetPoint("TOPRIGHT", primary, "TOPLEFT")
  end
  Compare.lastOutcome = "left"
  return "left"
end

-- The manager's post hook: after AnchorShoppingTooltips(primaryShown, secondaryShown) on the
-- manager, whose tooltip, anchorFrame and the tooltip's shoppingTooltips pair are read, never set.
function Compare.OnManagerAnchored(manager, primaryShown, secondaryShown)
  if type(manager) ~= "table" then
    return nil
  end
  local tooltip = rawget(manager, "tooltip")
  if not canRead(tooltip) or type(tooltip) ~= "table" then
    return nil
  end
  if not Compare.IsOurs(call(tooltip, "GetOwner")) then
    return nil
  end
  local anchor = rawget(manager, "anchorFrame")
  if not canRead(anchor) then
    anchor = nil
  end
  local pair = rawget(tooltip, "shoppingTooltips")
  if not canRead(pair) or type(pair) ~= "table" then
    return nil
  end
  local primary, secondary = rawget(pair, 1), rawget(pair, 2)
  if not canRead(primary) or not canRead(secondary) then
    return nil
  end
  local placed = Compare.PlaceLeft(tooltip, anchor, primary, secondary, primaryShown and true, secondaryShown and true)
  if placed == "kept" then
    Compare.BookRecheck(tooltip, anchor, primary, secondary, primaryShown and true, secondaryShown and true)
  end
  return placed
end

-- Brief BQ3: a placement the client made before the game tooltip had a place to measure (the first
-- hover's anchoring runs inside the tooltip's own fill, before its Show) is looked at once more on
-- the next frame, when the tooltip has been placed: still ours, the comparison still shown, it goes
-- left where it fits. One booked call however many hooks asked; nothing without C_Timer.
local pending = nil

local function recheck()
  local job = pending
  pending = nil
  if type(job) ~= "table" then
    return nil
  end
  if not Compare.IsOurs(call(job.tooltip, "GetOwner")) then
    return nil
  end
  local primaryShown = job.primaryShown and call(job.primary, "IsShown") == true
  local secondaryShown = job.secondaryShown and call(job.secondary, "IsShown") == true
  if not primaryShown then
    return nil
  end
  return Compare.PlaceLeft(job.tooltip, job.anchor, job.primary, job.secondary, primaryShown, secondaryShown)
end
Compare.Recheck = recheck

function Compare.BookRecheck(tooltip, anchor, primary, secondary, primaryShown, secondaryShown)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  local booked = pending ~= nil
  pending = {
    tooltip = tooltip,
    anchor = anchor,
    primary = primary,
    secondary = secondary,
    primaryShown = primaryShown,
    secondaryShown = secondaryShown,
  }
  if booked then
    return true
  end
  local ok = pcall(timer.After, 0, function()
    guarded("Compare.Recheck", recheck)
  end)
  if not ok then
    pending = nil
  end
  return ok
end

-- The Classic global's post hook: GameTooltip_AnchorComparisonTooltips(tooltip, anchorFrame,
-- shoppingTooltip1, shoppingTooltip2, primaryItemShown, secondaryItemShown).
function Compare.OnClassicAnchored(tooltip, anchor, primary, secondary, primaryShown, secondaryShown)
  if type(tooltip) ~= "table" or not Compare.IsOurs(call(tooltip, "GetOwner")) then
    return nil
  end
  return Compare.PlaceLeft(tooltip, anchor, primary, secondary, primaryShown and true, secondaryShown and true)
end

-- Hooks whichever anchoring the client has. Idempotent; answers "manager", "classic" or nil, and
-- keeps answering what it took.
function Compare.Install()
  if Compare.installed then
    return Compare.installed
  end
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" then
    return nil
  end
  local manager = rawget(_G, Compare.MANAGER)
  if type(manager) == "table" and type(rawget(manager, Compare.MANAGER_METHOD)) == "function" then
    local ok = pcall(hook, manager, Compare.MANAGER_METHOD, function(self, primaryShown, secondaryShown)
      guarded("Compare.OnManagerAnchored", Compare.OnManagerAnchored, self, primaryShown, secondaryShown)
    end)
    if ok then
      Compare.installed = "manager"
      return Compare.installed
    end
  end
  if type(rawget(_G, Compare.CLASSIC_FUNCTION)) == "function" then
    local ok = pcall(hook, Compare.CLASSIC_FUNCTION, function(...)
      guarded("Compare.OnClassicAnchored", Compare.OnClassicAnchored, ...)
    end)
    if ok then
      Compare.installed = "classic"
      return Compare.installed
    end
  end
  return nil
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  -- The manager loads with the client's own UI, so the first try is at load; PLAYER_LOGIN and
  -- PLAYER_ENTERING_WORLD are the retries for a client whose tooltip code is not up yet.
  if not Compare.Install() then
    local loader = createFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function(self, event)
      Compare.Install()
      if Compare.installed then
        self:UnregisterAllEvents()
      elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
      end
    end)
  end
end

return Compare
