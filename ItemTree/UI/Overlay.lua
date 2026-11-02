-- Badge overlays on bag and bank item buttons. Implements design component
-- badges/BagSlotOverlay.jsx, and the clickable reference in
-- design/templates/bag-interaction/BagInteraction.dc.html.
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_ICON_BAGSLOT 36 (32 and 30 variants: ITEMTREE_ICON_BAGSLOT_ALT,
--   ITEMTREE_ICON_BAGSLOT_MIN)
--   ITEMTREE_BADGE_SIZE_SLOT 18 on 36px slots, 16 at 32px, 14 at 30px, which is the design size
--   Badges anchor top right with a 1px inset and stack down the right edge with a 1px gap,
--   at most two, clear of the stack count in the bottom right corner
--
-- Two settings change that, account wide and for bags and bank alike (brief U1):
--   bagBadgeScale, default 0.5: the design size times this, to a whole pixel and never under 4,
--   so a 36px slot carries a 9px badge by default. The settings slider runs 0.2 to 1.5 (brief
--   ST1; it was 0.3 with a 5px floor). Brief ST2: it sizes the New and Changed badges (and the
--   profession icon) only; the Keep and Use marks follow keepMarkScale (Overlay.MarkSide).
--   bagBadgeCorner, default TOPRIGHT: which corner of the slot the badges sit in. The badge's
--   own corner is what is anchored to the slot's matching corner, 1px in, so a change of size
--   grows or shrinks the badge towards that corner and never moves it off it. The second badge
--   stacks away from the corner along the vertical edge: down from a top corner, up from a
--   bottom one. The design's top right placement is the default.
-- Both are read at draw time, and the settings panel's preview slot is placed through the same
-- Overlay.BadgeSize, Overlay.Anchor and Overlay.Place calls, so the two cannot drift apart.
--
-- The bag is never touched. One overlay frame is parented to each item button, the mouse is
-- off on it so every click, drag and tooltip still reaches the button underneath, and nothing
-- is written onto the button itself: the overlays are held in a weak table keyed by the
-- button, so no bag addon and no client frame is modified and a frame the client releases
-- takes its overlay with it. An overlay also hides with its button, because it is parented to
-- it, so a bag that closes needs no work here.
--
-- The overlay handles no input at all. The ItemTree key binding opens the window for the item
-- under the cursor; see UI/Keybind.lua, which resolves the item from the tooltip.
--
-- Two clients, one code path, every difference behind a small adapter:
--
--   Finding the frames. The modern container code (the Forever beta 1.60.1) draws the combined
--   view in ContainerFrameCombinedBags and keeps the separate bags in the globals
--   ContainerFrame1 to ContainerFrame13, the same names Classic Era uses. Both are read, and a
--   frame reached twice is only walked once.
--
--   Finding the buttons. The modern frames keep their buttons in an Items array, read here as
--   a plain table with only the shown ones taken; Classic Era names them ContainerFrameNItemM.
--   Whichever answers with a button is the one used, counted rather than trusted.
--
--   Taint (brief T6). Nothing here calls the client's own Lua enumerators. The modern
--   ContainerFrameUtil_EnumerateContainerFrames builds its frame list lazily, in an upvalue,
--   the first time anything asks, and EnumerateValidItems asks GetBagSize, which writes
--   frame.size when it is unset (Blizzard_UIPanels_Game Mainline/ContainerFrame.lua, branch
--   forever). Asked from here, both writes would be ItemTree's, and every later secure caller
--   (OpenBag, ContainerFrame_GenerateFrame and from there each slot's bag id) would read
--   ItemTree's taint, which is how a right click on a bag item (C_Container.UseContainerItem)
--   ends in "ItemTree has been blocked from an action only available to the Blizzard UI".
--   Only C side frame methods (IsShown, GetID, GetParent, GetName) and plain reads are used.
--
--   Finding the slot. The modern buttons carry button:GetBagID(); Classic Era's carry only
--   button:GetID() and take the bag from the frame they sit in. The bank's own slots sit in
--   BankSlotsFrame, which carries no bag id, so BANK_CONTAINER is passed in for them. The
--   bank bags are ordinary container frames and need nothing special. The Forever bank (brief
--   BG3) is BankPanel, whose pooled item buttons carry their bank tab and slot as the fields
--   bankTabID and containerSlotID; see collectBankPanel.
--
--   Reading the item. C_Container.GetContainerItemID is the modern namespace and the bare
--   GetContainerItemID is Classic Era's.
--
-- When it refreshes: BAG_UPDATE_DELAYED (never BAG_UPDATE, which fires once per bag per
-- change), BANKFRAME_OPENED, PLAYERBANKSLOTS_CHANGED and PLAYER_ENTERING_WORLD, plus the hooks
-- below, so badges appear the moment a bag opens rather than on the next event. Bursts are
-- coalesced into one pass, which starts the next frame with C_Timer.After(0) and draws its slots
-- over as many frames as the login slicer's budget per frame needs (brief PF7, "The queued bag
-- pass, in slices" below).
--
-- Opening a bag fires no event this module could listen to, so the hooks are the whole story
-- for a first draw, and they are taken on frames that are closed as well as open. What is
-- hooked, and why each one is needed (Blizzard_UIPanels_Game, branch forever):
--
--   Every container frame's own OnShow script, through HookScript. It is the one signal both
--   clients share and it does not depend on a global: the combined backpack's OnShow is a mixin
--   method (Mainline/ContainerFrame.xml, ContainerFrameCombinedBags) while a plain bag's is the
--   global ContainerFrame_OnShow (Mainline/ContainerFrame.xml, ContainerFrameTemplate).
--
--   Every container frame's own UpdateItems, which is what paints a bag on the modern code.
--   Taken per frame rather than on ContainerFrameMixin, because a mixin's functions are copied
--   onto each frame as it is created. It is reached from exactly one place,
--   ContainerFrameMixin:AddItemsForRefresh, and from inside a ContinueOnLoad callback
--   (Mainline/ContainerFrame.lua), so the first paint of a bag lands some time AFTER the frame
--   was shown, once the item data has loaded. That is why OnShow alone is not enough.
--
--   The global ContainerFrame_GenerateFrame, which is the one function that opens or rebuilds a
--   bag on both clients and is called by name, so a hook on it is reached. It covers a frame
--   this module has never seen, including one the client creates later.
--
--   The global ContainerFrame_Update, which is Classic Era's redraw. The Forever client's
--   container code carries no function of that name at all, so that hook covers nothing there.
--
--   The Forever bank panel's own GenerateItemSlotsForSelectedTab (brief BG3), taken with
--   hooksecurefunc on BankPanel, the one method every open, page, bank tab and bank type of that
--   bank goes through. See collectBankPanel; nothing hooks a script on the bank.
--
-- And a couple of settle passes a few seconds after login (Overlay.SETTLE_DELAYS), because a bag
-- that was open across a /reload is reopened by the client's own BAG_OPEN handling some time
-- after PLAYER_LOGIN and paints itself later still. Each pass is one walk over the buttons that
-- are visible at that moment and queries nothing.
--
-- Combat (brief TX6): nothing here is attached, anchored, shown or hidden on a slot while the
-- player is in combat, where a frame under a client frame cannot be moved, shown or hidden and the
-- client blames ItemTree. Each draw asks InCombatLockdown first; in combat it books one redraw of
-- its surface for PLAYER_REGEN_ENABLED (one flag per surface, cleared when it runs) and leaves
-- every frame as it is. Overlay.Attach is the one place that calls SetParent.
--
-- No saved variables and no logging: item ids only ever pass through memory.
--
-- Overlay.BadgesFor, Overlay.Scale, Overlay.Corner, Overlay.DesignSize, Overlay.BadgeSize and
-- Overlay.Anchor are pure and run under busted with no client, and so are the profession icon's
-- Overlay.ProfessionCorner, NextCorner, ProfessionCornerFor and ProfessionAnchor (brief PR6).
-- Everything below the divider is guarded, so this file loads with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Overlay = {}
ItemTree.UI.Overlay = Overlay

local Theme = ItemTree.Theme
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- At most two badges on a slot: a third would reach the stack count.
Overlay.MAX_BADGES = 2

-- 1px in from the chosen corner, and 1px between the two badges (Badges.GAP_SLOT).
Overlay.INSET = 1
Overlay.GAP = Badges.GAP_SLOT

-- The badge size setting: a multiple of the design size. Half by default, because the full
-- design size reads as too big on a 36px slot. The range is the settings slider's, and a
-- stored value outside it is held to it, so a hand edited saved file cannot draw a badge
-- bigger than the slot. MIN_BADGE is the smallest badge that still reads as a mark at all.
-- Brief ST1 (QA item 279, a player: "i think i have it on smallest setting but its still quite
-- big"): the slider's bottom went from 0.3 to 0.2 and the floor from 5 to 4 px, so on a 36px slot
-- the smallest badge is 4 px with a 5 px medallion (Badges.ArtSize), where it was 5 px with a
-- 12 px medallion.
Overlay.SCALE_DEFAULT = 0.5
Overlay.SCALE_MIN = 0.2
Overlay.SCALE_MAX = 1.5
Overlay.SCALE_STEP = 0.05
Overlay.MIN_BADGE = 4

-- The corner setting: the client's own anchor point names, so a value passes straight to
-- SetPoint. Listed in the order the settings dropdown offers them.
Overlay.CORNER_DEFAULT = "TOPRIGHT"
Overlay.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

-- Which way is in from each corner: x is +1 towards the right, y is +1 upwards, as SetPoint
-- reads its offsets. The badge stack runs the same way as y, away from the corner.
local CORNER_SIGNS = {
  TOPLEFT = { x = 1, y = -1 },
  TOPRIGHT = { x = -1, y = -1 },
  BOTTOMLEFT = { x = 1, y = 1 },
  BOTTOMRIGHT = { x = -1, y = 1 },
}

-- How far above the button the overlay sits, so the badges draw over the icon, the quality
-- border and the cooldown swipe rather than under them.
Overlay.LEVEL_OFFSET = 5

-- Seconds after Install at which a settle pass is taken. Two of them, a moment apart, because
-- the client's own first paint of a bag is not synchronous and a bag restored across a /reload
-- opens after PLAYER_LOGIN. The saved settings are in place at ADDON_LOADED, which is before
-- Install runs, so every pass here is already reading them.
Overlay.SETTLE_DELAYS = { 1, 5 }

-- The last few things this module could not do, oldest first, for the debug command. Every
-- client call below is pcall'd, so without this a hook the client refused leaves no trace at
-- all: the bag simply has no badges on it and nothing says why. Bounded, so a client that
-- refuses on every pass cannot grow it.
Overlay.MAX_PROBLEMS = 8
Overlay.problems = {}

-- How this module ended up wired into the client's bags, for the debug command. Counts and yes
-- or no answers only: no item, character or realm fact reaches it.
Overlay.hooks = {
  frames = 0,
  updateItems = 0,
  onShow = 0,
  containerUpdate = false,
  generateFrame = false,
  -- Brief BG3: the Forever bank panel's GenerateItemSlotsForSelectedTab, once hooked.
  bankPanel = false,
}

-- Slot width to badge size, largest first. The design draws 18 on the 36px slot and steps
-- down 2px for each smaller slot, so the 32px slot takes 16 and the 30px one takes 14.
local SLOT_BADGE = {
  { width = Theme.sizes.ITEMTREE_ICON_BAGSLOT, size = Theme.sizes.ITEMTREE_BADGE_SIZE_SLOT },
  { width = Theme.sizes.ITEMTREE_ICON_BAGSLOT_ALT, size = Theme.sizes.ITEMTREE_BADGE_SIZE_SLOT - 2 },
  { width = Theme.sizes.ITEMTREE_ICON_BAGSLOT_MIN, size = Theme.sizes.ITEMTREE_BADGE_SIZE_SLOT - 4 },
}

-- Which setting turns each badge kind on. A kind no setting names is always drawn.
local BADGE_SETTING = {
  new = "badgesNew",
  -- Season of Discovery is New in purple, so the New setting turns it off too.
  sod = "badgesNew",
  changed = "badgesChanged",
}

-- Which setting turns the overlay on for each place a slot can be.
local WHERE_SETTING = {
  bag = "bagOverlay",
  bank = "bankOverlay",
}

-- A setting that has never been written reads as on, the same way UI/Tooltip.lua reads one.
local function settingOn(settings, key)
  if type(settings) ~= "table" or key == nil then
    return true
  end
  local value = settings[key]
  if value == nil then
    return true
  end
  return value and true or false
end

-- Brief W27: the Changed badge on a bag or bank slot also needs this setting, off by default
-- (Core/Init.lua DB_DEFAULTS). Unlike the others, an unwritten value reads as off, its default.
-- The window's own Changed badges read badgesChanged alone and are untouched.
local BAG_CHANGED_SETTING = "bagBadgesChanged"

local function bagChangedOn(settings)
  if type(settings) ~= "table" then
    return false
  end
  return settings[BAG_CHANGED_SETTING] == true
end

-- The badge size setting as a number to multiply by. Anything that is not a positive number
-- (nil, a string, NaN, zero) is malformed and reads as the default; a number outside the
-- slider's range is held to it.
function Overlay.Scale(value)
  if type(value) ~= "number" or value ~= value or value <= 0 then
    return Overlay.SCALE_DEFAULT
  end
  if value < Overlay.SCALE_MIN then
    return Overlay.SCALE_MIN
  end
  if value > Overlay.SCALE_MAX then
    return Overlay.SCALE_MAX
  end
  return value
end

-- The corner setting as an anchor point name. Anything but one of the four reads as the
-- default top right.
function Overlay.Corner(value)
  if type(value) == "string" and CORNER_SIGNS[value] then
    return value
  end
  return Overlay.CORNER_DEFAULT
end

-- The design size for a slot of this width: 18 at 36 and above, 16 at 32, 14 at 30 and below.
-- The width is read off the button at draw time, because a bag addon and the two clients all
-- size their slots differently. A width that cannot be read at all takes the design's own slot.
function Overlay.DesignSize(slotWidth)
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    return SLOT_BADGE[1].size
  end
  for _, entry in ipairs(SLOT_BADGE) do
    if width >= entry.width then
      return entry.size
    end
  end
  return SLOT_BADGE[#SLOT_BADGE].size
end

-- The badge size to draw: the design size for the slot times the size setting, rounded to a
-- whole pixel and never under MIN_BADGE. scale is the stored setting, read through
-- Overlay.Scale, so a missing or malformed one draws at half the design size.
function Overlay.BadgeSize(slotWidth, scale)
  local size = math.floor(Overlay.DesignSize(slotWidth) * Overlay.Scale(scale) + 0.5)
  if size < Overlay.MIN_BADGE then
    return Overlay.MIN_BADGE
  end
  return size
end

-- Where one badge goes: its own corner point, the slot's matching point and the x, y offsets
-- between them. The first badge sits 1px in from the corner on both edges; the second is one
-- badge and a 1px gap further along the vertical edge, down from a top corner and up from a
-- bottom one. Because the badge's own corner is the point anchored, the first badge's offsets
-- do not depend on its size at all: a bigger or smaller badge grows or shrinks towards the
-- corner and stays on it. Returns point, relativePoint, x, y.
function Overlay.Anchor(index, size, corner)
  index = tonumber(index) or 1
  if index < 1 then
    index = 1
  end
  size = tonumber(size) or Overlay.BadgeSize(nil)
  corner = Overlay.Corner(corner)
  local signs = CORNER_SIGNS[corner]
  local along = Overlay.INSET + (index - 1) * (size + Overlay.GAP)
  return corner, corner, signs.x * Overlay.INSET, signs.y * along
end

--------------------------------------------------------------------------------
-- The profession icon (brief PR6)
--
-- Items the player's profession route still needs (the Relevant set Core/Keep.lua reads from the
-- ItemTree_Professions model, the same set that keeps them) carry that profession's icon in one
-- corner of the slot: bottom left by default (brief PR20; it was bottom right), its own setting
-- (professionBadgeCorner), sized with the badges (bagBadgeScale). It is one texture of its own on
-- the overlay frame, apart from the badge cluster, made the first time a slot needs it, sitting
-- inset inside a small frame of its own (brief PR20): a dark backing and the client's thin
-- tooltip bevel in tiny corner pieces, or flat 1px edges where that art is missing.
--
-- Where it goes (the framed box, which is the icon and its frame together):
--   * the chosen corner, unless the badges sit in that corner on this slot, in which case the next
--     corner clockwise (top left, top right, bottom right, bottom left);
--   * 1px in from the corner, as a badge is, in every corner. Only at bottom right, and only on a
--     slot that is showing a stack count (ItemButtonTemplate's Count, NumberFontNormal at 14px,
--     anchored BOTTOMRIGHT -5, 2 in Blizzard_ItemButton Mainline and Shared, branch forever), is
--     it lifted clear of the count: by the count's own height where the button carries it, else
--     COUNT_CLEAR scaled to the slot's height (brief PR20, Overlay.CountLift);
--   * and where the badge stack runs down (or up) the same side edge far enough to reach it, it
--     steps in by one badge and a gap, so it sits beside the stack rather than on it.
--
-- The icon art is the profession's category glyph in UI/Assets.lua (Assets.skillGlyphs, client
-- icon paths), a static table in the core addon: it never needs ItemTree_Data loaded.
--------------------------------------------------------------------------------

Overlay.PROFESSION_CORNER_DEFAULT = "BOTTOMLEFT"

-- How far above the slot's bottom edge the stack count's digits reach on a slot COUNT_SLOT px
-- high: the count's own 2px lift and about 12px of NumberFontNormal's 14px line that the digits
-- fill. A slot of another height scales it (Overlay.CountLift).
Overlay.COUNT_CLEAR = 14
Overlay.COUNT_SLOT = 37

-- Brief PR20: the icon's small frame. The icon sits PROFESSION_FRAME_PAD px in from the frame's
-- outer edge on every side, so the framed box is the badge size plus twice the pad. The corner
-- pieces are PROFESSION_FRAME_CORNER px square (PROFESSION_FRAME_CORNER_LARGE from a badge size of
-- PROFESSION_FRAME_LARGE_AT), small enough to stay crisp at half size badges. The tooltip bevel's
-- art is 7 texels deep with its clear inner part from texel 3 (UI/Assets.lua PROFESSION_BORDER_*),
-- so the dark backing starts that far in, scaled to the corner, and never shows past the rounded
-- corners.
Overlay.PROFESSION_FRAME_PAD = 2
Overlay.PROFESSION_FRAME_CORNER = 3
Overlay.PROFESSION_FRAME_CORNER_LARGE = 4
Overlay.PROFESSION_FRAME_LARGE_AT = 14
Overlay.PROFESSION_FRAME_ART = 7
Overlay.PROFESSION_FRAME_ART_FACE = 3
Overlay.PROFESSION_FRAME_EDGE = "ITEMTREE_COLOR_BORDER_GOLD"
Overlay.PROFESSION_FRAME_FILL = "ITEMTREE_BADGE_BACKING"
-- The eight pieces, in drawing order, and the Assets keys they are drawn from.
Overlay.PROFESSION_FRAME_ORDER = { "TL", "TR", "BL", "BR", "TOP", "BOTTOM", "LEFT", "RIGHT" }
Overlay.PROFESSION_FRAME_KEYS = {
  TL = "PROFESSION_BORDER_TL",
  TR = "PROFESSION_BORDER_TR",
  BL = "PROFESSION_BORDER_BL",
  BR = "PROFESSION_BORDER_BR",
  TOP = "PROFESSION_BORDER_TOP",
  BOTTOM = "PROFESSION_BORDER_BOTTOM",
  LEFT = "PROFESSION_BORDER_LEFT",
  RIGHT = "PROFESSION_BORDER_RIGHT",
}

-- Client icons carry a bevelled edge that reads as a smudge at badge size, so it is cropped off.
Overlay.PROFESSION_CROP = { 0.07, 0.93, 0.07, 0.93 }

-- Clockwise round the slot, from each corner to the next.
local CLOCKWISE = {
  TOPLEFT = "TOPRIGHT",
  TOPRIGHT = "BOTTOMRIGHT",
  BOTTOMRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPLEFT",
}

-- The profession icon's corner setting as an anchor point name. Anything but one of the four
-- reads as the default, bottom left. Pure.
function Overlay.ProfessionCorner(value)
  if type(value) == "string" and CORNER_SIGNS[value] then
    return value
  end
  return Overlay.PROFESSION_CORNER_DEFAULT
end

-- The next corner clockwise from this one. Pure.
function Overlay.NextCorner(corner)
  return CLOCKWISE[Overlay.ProfessionCorner(corner)]
end

-- The corner the icon takes on a slot: the chosen one, or the next clockwise where the badges
-- sit in it (badgeCount above 0 in badgeCorner). Brief PM1: lookCorner is the corner the Keep
-- look draws its own glyph in (Overlay.LookCorner: the Flag's or the Corner gem's), nil for a
-- look that sits in none; the icon steps clockwise past it as well, so the two never share a
-- corner. Pure.
function Overlay.ProfessionCornerFor(chosen, badgeCorner, badgeCount, lookCorner)
  local corner = Overlay.ProfessionCorner(chosen)
  local badges = (tonumber(badgeCount) or 0) > 0 and Overlay.Corner(badgeCorner) or nil
  local look = type(lookCorner) == "string" and CORNER_SIGNS[lookCorner] and lookCorner or nil
  for _ = 1, 4 do
    if corner ~= badges and corner ~= look then
      return corner
    end
    corner = CLOCKWISE[corner]
  end
  return corner
end

-- Brief PR20: how far a bottom right icon is lifted for the slot's stack count. shown is whether
-- the slot is showing a count at all: none, and the icon sits flush (0, no lift). Where the count's
-- own height is known (countHeight, read off the button's Count) that is the lift; else
-- COUNT_CLEAR scaled by the slot's height over COUNT_SLOT, or COUNT_CLEAR itself for an unknown
-- slot. Whole pixels. Pure.
function Overlay.CountLift(shown, slotHeight, countHeight)
  if not shown then
    return 0
  end
  local height = tonumber(countHeight)
  if height and height > 0 then
    return math.floor(height + 0.5)
  end
  local side = tonumber(slotHeight)
  if not side or side <= 0 then
    return Overlay.COUNT_CLEAR
  end
  return math.floor(Overlay.COUNT_CLEAR * side / Overlay.COUNT_SLOT + 0.5)
end

-- Brief PR20: the icon's frame for a badge size, as rectangles from the framed box's top left
-- (x right, y down): { box, pad, corner, icon = rect, face = rect, pieces = { TL, TR, BL, BR, TOP,
-- BOTTOM, LEFT, RIGHT } }. box is the framed box's side, pad how far in the icon sits, face the
-- dark backing. flat is the fallback where the bevel art is missing: four 1px edges round the box
-- and no corner pieces, the backing filling the inside of them. Pure.
function Overlay.ProfessionFrame(size, flat)
  size = tonumber(size) or Overlay.BadgeSize(nil)
  local pad = Overlay.PROFESSION_FRAME_PAD
  local box = size + 2 * pad
  local out = { box = box, pad = pad, icon = { x = pad, y = pad, w = size, h = size }, pieces = {} }
  local p = out.pieces
  if flat then
    out.corner = 0
    out.face = { x = 1, y = 1, w = box - 2, h = box - 2 }
    p.TOP = { x = 0, y = 0, w = box, h = 1 }
    p.BOTTOM = { x = 0, y = box - 1, w = box, h = 1 }
    p.LEFT = { x = 0, y = 1, w = 1, h = box - 2 }
    p.RIGHT = { x = box - 1, y = 1, w = 1, h = box - 2 }
    return out
  end
  local c = Overlay.PROFESSION_FRAME_CORNER
  if size >= Overlay.PROFESSION_FRAME_LARGE_AT then
    c = Overlay.PROFESSION_FRAME_CORNER_LARGE
  end
  out.corner = c
  local inset = math.floor(Overlay.PROFESSION_FRAME_ART_FACE * c / Overlay.PROFESSION_FRAME_ART + 0.5)
  out.face = { x = inset, y = inset, w = box - 2 * inset, h = box - 2 * inset }
  p.TL = { x = 0, y = 0, w = c, h = c }
  p.TR = { x = box - c, y = 0, w = c, h = c }
  p.BL = { x = 0, y = box - c, w = c, h = c }
  p.BR = { x = box - c, y = box - c, w = c, h = c }
  p.TOP = { x = c, y = 0, w = box - 2 * c, h = c }
  p.BOTTOM = { x = c, y = box - c, w = box - 2 * c, h = c }
  p.LEFT = { x = 0, y = c, w = c, h = box - 2 * c }
  p.RIGHT = { x = box - c, y = c, w = c, h = box - 2 * c }
  return out
end

-- Where the icon's framed box goes in the corner it takes: its own corner point, the slot's
-- matching point and the x, y offsets, as Overlay.Anchor answers for a badge. size is the framed
-- box's side. slotWidth is the slot's side (a slot is square), read for the clash with a badge
-- stack on the same side edge; badgeCorner and badgeCount are the badges this slot draws. lift is
-- Overlay.CountLift's answer for the slot, read only at bottom right (brief PR20: flush there with
-- no count). Returns point, relativePoint, x, y. Pure.
function Overlay.ProfessionAnchor(size, corner, slotWidth, badgeCorner, badgeCount, lift)
  corner = Overlay.ProfessionCorner(corner)
  size = tonumber(size) or Overlay.BadgeSize(nil)
  local signs = CORNER_SIGNS[corner]
  local across, along = Overlay.INSET, Overlay.INSET
  if corner == "BOTTOMRIGHT" then
    along = math.max(Overlay.INSET, tonumber(lift) or 0)
  end
  local count = math.min(tonumber(badgeCount) or 0, Overlay.MAX_BADGES)
  badgeCorner = Overlay.Corner(badgeCorner)
  if count > 0 and badgeCorner ~= corner and CORNER_SIGNS[badgeCorner].x == signs.x then
    local side = tonumber(slotWidth)
    if not side or side <= 0 then
      side = Theme.sizes.ITEMTREE_ICON_BAGSLOT
    end
    local stack = Overlay.INSET + count * size + (count - 1) * Overlay.GAP
    if stack + Overlay.GAP + along + size > side then
      across = across + size + Overlay.GAP
    end
  end
  return corner, corner, signs.x * across, signs.y * along
end

-- The art key for a skill line's icon, or nil for a skill line UI/Assets.lua has no glyph for.
-- Pure over the loaded Assets table.
function Overlay.ProfessionIconKey(skillLine)
  local assets = ItemTree.Assets
  local glyphs = type(assets) == "table" and assets.skillGlyphs or nil
  local id = tonumber(skillLine)
  if type(glyphs) ~= "table" or not id then
    return nil
  end
  return glyphs[id]
end

-- The skill line whose icon a slot's item wears, or nil. Every one of these must hold: the
-- professionBadge setting is on (an unwritten one reads as on), the place's own setting (bagOverlay
-- or bankOverlay) is on, the player has not set the item to Never or Off in Keep, and the item is in
-- the profession route's Relevant set. That last is Keep.ProfessionRelevant, which answers only
-- while UI/ProfessionsStub.lua Active() is true (the tab's setting on and its folder loaded) and
-- reads the model's own set, so it answers before ItemTree_Data has loaded and never asks for it.
function Overlay.ProfessionFor(itemId, settings, where)
  local id = tonumber(itemId)
  if not id or not settingOn(settings, "professionBadge") then
    return nil
  end
  if not settingOn(settings, WHERE_SETTING[where] or WHERE_SETTING.bag) then
    return nil
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.ProfessionRelevant) ~= "function" then
    return nil
  end
  if type(keep.Override) == "function" then
    local ok, word = pcall(keep.Override, id)
    if ok and (word == "never" or word == "off") then
      return nil
    end
  end
  local ok, info = pcall(keep.ProfessionRelevant, id)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local line = tonumber(info.skillLine)
  if not line or not Overlay.ProfessionIconKey(line) then
    return nil
  end
  return line
end

-- The kinds to draw on one slot: what Diff says about the item, filtered by the badge
-- settings, sorted by priority and capped at two. where is "bag" or "bank", and the overlay
-- setting for that place turns the whole slot off. A Changed badge is drawn on a slot only while
-- bagBadgesChanged is on as well as badgesChanged (brief W27). An empty slot and an item the build says
-- nothing about both come back empty, which is what hides the overlay.
function Overlay.BadgesFor(itemId, settings, where)
  if not settingOn(settings, WHERE_SETTING[where] or WHERE_SETTING.bag) then
    return {}
  end
  local id = tonumber(itemId)
  if not id then
    return {}
  end
  local Diff = ItemTree.Diff
  if not Diff or type(Diff.Badges) ~= "function" then
    return {}
  end
  local ok, kinds = pcall(Diff.Badges, "items", id)
  if not ok or type(kinds) ~= "table" then
    return {}
  end
  local wanted = {}
  for _, kind in ipairs(kinds) do
    local wantedKind = settingOn(settings, BADGE_SETTING[kind])
    if wantedKind and kind == "changed" and not bagChangedOn(settings) then
      wantedKind = false
    end
    if wantedKind then
      wanted[#wanted + 1] = kind
    end
  end
  return Badges.Sort(wanted, Overlay.MAX_BADGES)
end

-- The item id in an item hyperlink or item string, or nil. Some bag addons hold a slot's link
-- rather than its id (ArkInventory keeps the link in the slot's own record). Pure.
function Overlay.ItemIdFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

-- A number that is a real bag or slot, or nil. Pure.
local function whole(value)
  local number = tonumber(value)
  if number == nil or number ~= math.floor(number) then
    return nil
  end
  return number
end
Overlay.Whole = whole

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Records one thing the client refused, newest last, and answers false so a caller can return
-- it straight back. The list is what the debug command prints; nothing is printed from here.
local function trace(what, err)
  local problems = Overlay.problems
  problems[#problems + 1] = tostring(what) .. ": " .. tostring(err)
  while #problems > Overlay.MAX_PROBLEMS do
    table.remove(problems, 1)
  end
  return false
end

-- One client call, type checked and pcall'd. An API this client does not carry and one that
-- raises both read as nothing found. That is the whole safety story for this file: a refusal
-- costs the one button it was asked about and never the rest of the bag.
local apiCall = ItemTree.Util.ApiResult
-- Brief UI1: whether a client value may be compared (bible B10), for Overlay.Attach's strata.
local canRead = ItemTree.Util.CanRead

local function globalCall(name, ...)
  return apiCall(rawget(_G, name), ...)
end

-- One method on a frame, the same way. A method this frame does not carry reads as nothing.
local function method(object, name, ...)
  if type(object) ~= "table" then
    return nil
  end
  return apiCall(object[name], object, ...)
end

-- A numeric client global, or the Classic Era value when this client does not name it.
local function constant(name, fallback)
  return tonumber(rawget(_G, name)) or fallback
end

-- True unless the frame says it is hidden. A frame with no IsShown at all counts as shown,
-- because the only frames that reach here are ones the client handed us as open.
local function isShown(frame)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.IsShown) ~= "function" then
    return true
  end
  local ok, shown = pcall(frame.IsShown, frame)
  if not ok then
    return true
  end
  return shown and true or false
end

--------------------------------------------------------------------------------
-- Combat (brief TX6)
--------------------------------------------------------------------------------

-- True while the client is in combat lockdown. A client (or the test harness) with no
-- InCombatLockdown, or one that raises, answers not in combat.
local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- The redraws booked for the end of combat, one per surface, in the order they were booked.
Overlay.afterCombat = {}
Overlay.afterCombatOrder = {}

-- Books one redraw of a surface for PLAYER_REGEN_ENABLED. A surface already booked is not booked
-- again. Answers whether this call booked it.
local function bookAfterCombat(surface, fn)
  if Overlay.afterCombat[surface] then
    return false
  end
  Overlay.afterCombat[surface] = fn
  Overlay.afterCombatOrder[#Overlay.afterCombatOrder + 1] = surface
  if not Overlay.combatFrame then
    local create = rawget(_G, "CreateFrame")
    local ok, frame = false, nil
    if type(create) == "function" then
      ok, frame = pcall(create, "Frame")
    end
    if ok and type(frame) == "table" then
      Overlay.combatFrame = frame
      method(frame, "RegisterEvent", "PLAYER_REGEN_ENABLED")
      method(frame, "SetScript", "OnEvent", function()
        Overlay.OnCombatEnd()
      end)
    end
  end
  return true
end

-- PLAYER_REGEN_ENABLED: runs every booked redraw once, clearing each flag first. Answers how many
-- ran.
function Overlay.OnCombatEnd()
  local booked, order = Overlay.afterCombat, Overlay.afterCombatOrder
  Overlay.afterCombat, Overlay.afterCombatOrder = {}, {}
  local ran = 0
  for _, surface in ipairs(order) do
    local fn = booked[surface]
    if fn then
      ran = ran + 1
      local ok, err = pcall(fn)
      if not ok then
        trace("after combat " .. tostring(surface), err)
      end
    end
  end
  return ran
end

-- Brief BG2: the container ids the client's own Enum.BagIndex names, as { [id] = "bank" | "bag" }:
-- "bank" for every name with "bank" in it and "bag" for the rest, or nil where the client has no
-- such enum or it names no bank container at all. The Forever client (1.60.1, the camelot game type)
-- names 27 (Blizzard_APIDocumentationGenerated/BagIndexConstantsDocumentation.lua:18-51, mirror
-- 1.60.1.70245): Accountbanktab -3 and Characterbanktab -2 (the containers the bank bags sit in),
-- Keyring -1, Backpack 0, Bag_1 to Bag_4, ReagentBag 5, CharacterBankTab_1 to _9 (6 to 14, the
-- bank's tabs: Camelot/BankFrame.lua:316 GetExactBankTabSlot) and AccountBankTab_1 to _9 (15 to 23,
-- :318). That client defines no BANK_CONTAINER and no NUM_BANKBAGSLOTS (the branch names them only
-- in Vanilla/BankFrame.lua, which the camelot game type does not load), so the Classic rule below
-- read -1 (its keyring), 5 (the reagent bag) and 6 to 10 as the bank and 11 to 23 and -2, -3 as
-- bags. Read once per enum table: a plain read of the client's own table, nothing written.
local bagIndexRead, bagIndexPlaces = nil, nil

local function enumPlaces()
  local enum = rawget(_G, "Enum")
  local index = type(enum) == "table" and rawget(enum, "BagIndex") or nil
  if type(index) ~= "table" then
    return nil
  end
  if index == bagIndexRead then
    return bagIndexPlaces
  end
  local places, banks = {}, 0
  for name, id in pairs(index) do
    local number = tonumber(id)
    if type(name) == "string" and number then
      if name:lower():find("bank", 1, true) then
        places[number] = "bank"
        banks = banks + 1
      elseif places[number] == nil then
        places[number] = "bag"
      end
    end
  end
  bagIndexRead, bagIndexPlaces = index, banks > 0 and places or nil
  return bagIndexPlaces
end

-- "bank" for the bank's own container and for the bank bags, which are ordinary container
-- frames sitting past the player's own bags. Everything else is a bag. Brief BG2: where the
-- client's Enum.BagIndex names the id, its name answers (enumPlaces); an id it does not name, and
-- a client with no such enum (Classic Era), takes the Classic constants as before.
function Overlay.WhereForBag(bag)
  bag = tonumber(bag)
  if bag == nil then
    return "bag"
  end
  local places = enumPlaces()
  if places and places[bag] then
    return places[bag]
  end
  if bag == constant("BANK_CONTAINER", -1) then
    return "bank"
  end
  local bags = constant("NUM_BAG_SLOTS", 4)
  if bag > bags and bag <= bags + constant("NUM_BANKBAGSLOTS", 6) then
    return "bank"
  end
  return "bag"
end

-- The item in one slot, or nil for an empty slot. C_Container is the modern namespace and the
-- bare global is Classic Era's.
function Overlay.ItemIdAt(bag, slot)
  if bag == nil or slot == nil then
    return nil
  end
  local container = rawget(_G, "C_Container")
  if type(container) == "table" then
    local id = tonumber(apiCall(container.GetContainerItemID, bag, slot))
    if id then
      return id
    end
  end
  return tonumber(globalCall("GetContainerItemID", bag, slot))
end

-- Brief BG3: the bank tab and slot a Forever bank panel button shows, or nil, nil for any other
-- button. The panel's pooled buttons keep both as plain fields that the button's own Init sets each
-- time the pool hands it out (Blizzard_UIPanels_Game Mainline/BankFrameTemplates.lua:476-508, called
-- from :1040 as button:Init(bankType, bagID, slot)). The tab is a container id Enum.BagIndex names
-- (CharacterBankTab_1 to AccountBankTab_9, 6 to 23, brief BG2), and the client's own tooltip and
-- clicks read the slot through exactly this pair (:397 SetBagItem, :427 PickupContainerItem). Plain
-- reads of the button's table: no method of the button is called and nothing is written.
function Overlay.BankPanelSlot(button)
  if type(button) ~= "table" then
    return nil, nil
  end
  local bag, slot = whole(rawget(button, "bankTabID")), whole(rawget(button, "containerSlotID"))
  if bag == nil or slot == nil then
    return nil, nil
  end
  return bag, slot
end

-- bag, slot for one item button. bagHint is what a caller that already knows the bag passes:
-- the bank's own slots, whose parent carries no bag id, and the Classic Era buttons looked up
-- by the name of the frame they belong to. Otherwise the modern button:GetBagID() answers,
-- and failing that the frame the button sits in does. Brief BG3: a Forever bank panel button
-- answers its bank tab and slot (Overlay.BankPanelSlot) first, because its GetID is not the slot.
function Overlay.ButtonSlot(button, bagHint)
  if bagHint == nil then
    local tab, tabSlot = Overlay.BankPanelSlot(button)
    if tabSlot ~= nil then
      return tab, tabSlot
    end
  end
  local slot = tonumber(method(button, "GetID"))
  local bag = tonumber(bagHint)
  if bag == nil then
    bag = tonumber(method(button, "GetBagID"))
  end
  if bag == nil then
    bag = tonumber(method(method(button, "GetParent"), "GetID"))
  end
  return bag, slot
end

--------------------------------------------------------------------------------
-- Hooks on whatever opens or redraws a bag
--------------------------------------------------------------------------------

-- Container frames already hooked, weakly held so a frame the client releases goes with it.
local hookedFrames = setmetatable({}, { __mode = "k" })

-- What every hook here does: ask for one refresh, debounced.
local function queueRefresh()
  Overlay.Queue()
end

-- HookScript raises on a frame that has no such script, and the beta is retail shaped, so
-- HasScript is asked first and a frame that will not answer counts as not having it.
local function hasScript(frame, name)
  if type(frame) ~= "table" or type(frame.HasScript) ~= "function" then
    return false
  end
  local ok, has = pcall(frame.HasScript, frame, name)
  if not ok then
    return false
  end
  return has and true or false
end

-- Both per frame hooks, taken once per frame and only once the module is installed.
--
-- Taken whether or not the frame is showing at the time. That is the whole point: a bag that is
-- closed when this runs is exactly the one whose first open used to go unnoticed, because the
-- hooks used to be taken from inside the walk over OPEN frames, so a closed bag was returned
-- from before it was ever hooked and opening it reached nothing.
--
--   OnShow is the frame's own script, so it covers both clients and both shapes of bag: the
--   combined backpack's OnShow is a mixin method and a plain bag's is a global.
--   UpdateItems is the modern code's redraw, called from a ContinueOnLoad callback once the
--   item data has loaded, which is the moment a first draw really has something to read.
--
-- Classic Era carries no UpdateItems and is covered as well by the global hooks in Install.
local function hookFrame(frame)
  if not Overlay.installed or type(frame) ~= "table" or hookedFrames[frame] then
    return false
  end
  hookedFrames[frame] = true
  Overlay.hooks.frames = Overlay.hooks.frames + 1
  local taken = false
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) == "function" and type(frame.UpdateItems) == "function" then
    local ok, err = pcall(hook, frame, "UpdateItems", queueRefresh)
    if ok then
      Overlay.hooks.updateItems = Overlay.hooks.updateItems + 1
      taken = true
    else
      trace("UpdateItems hook", err)
    end
  end
  if hasScript(frame, "OnShow") and type(frame.HookScript) == "function" then
    local ok, err = pcall(frame.HookScript, frame, "OnShow", queueRefresh)
    if ok then
      Overlay.hooks.onShow = Overlay.hooks.onShow + 1
      taken = true
    else
      trace("OnShow hook", err)
    end
  end
  return taken
end

-- hooksecurefunc on one global, by name. A client that does not carry it is not a failure and
-- leaves no trace; a client that refuses the hook does.
local function hookGlobal(name)
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" or type(rawget(_G, name)) ~= "function" then
    return false
  end
  local ok, err = pcall(hook, name, queueRefresh)
  if not ok then
    return trace(name .. " hook", err)
  end
  return true
end

--------------------------------------------------------------------------------
-- Finding the buttons
--------------------------------------------------------------------------------

-- One container frame's item buttons, handed to add(button, bagHint). Returns how many were
-- found, which is also what decides whether the next way of finding them is tried.
--
-- The frame is hooked BEFORE the closed bag is returned from, so that a bag the player has not
-- opened yet still gets its OnShow and UpdateItems hooks and marks itself the moment it opens.
local function collectFrame(frame, add)
  hookFrame(frame)
  if not isShown(frame) then
    return 0
  end
  local bag = tonumber(method(frame, "GetID"))
  local count = 0
  local function take(button, bagHint)
    if type(button) == "table" then
      count = count + 1
      add(button, bagHint)
    end
  end
  -- The modern code's own buttons, read off the frame's Items array rather than through
  -- EnumerateValidItems, whose GetBagSize writes frame.size when it is unset and would leave
  -- that write tainted by us (brief T6). A pooled button past the bag's size is hidden, so only
  -- the shown ones are taken. Each one carries its bag, so no hint is passed.
  local items = rawget(frame, "Items")
  if type(items) == "table" then
    for _, button in ipairs(items) do
      if isShown(button) then
        take(button)
      end
    end
  end
  -- Classic Era: ContainerFrameNItemM, with the bag on the frame they belong to.
  if count == 0 then
    local name = method(frame, "GetName")
    if type(name) == "string" and name ~= "" then
      for index = 1, constant("MAX_CONTAINER_ITEMS", 36) do
        take(rawget(_G, name .. "Item" .. index), bag)
      end
    end
  end
  return count
end

-- The bank's own slots: named globals on both clients, sitting in BankSlotsFrame, which
-- carries no bag id, so BANK_CONTAINER is passed in as the bag. The bank bags are ordinary
-- container frames and are found with the bags.
local function collectBank(add)
  if not isShown(rawget(_G, "BankFrame")) then
    return 0
  end
  local bag = constant("BANK_CONTAINER", -1)
  local slotsFrame = rawget(_G, "BankSlotsFrame")
  local count = 0
  for index = 1, constant("NUM_BANKGENERIC_SLOTS", 28) do
    local button = rawget(_G, "BankFrameItem" .. index)
    if type(button) ~= "table" and type(slotsFrame) == "table" then
      button = rawget(slotsFrame, "Item" .. index)
    end
    if type(button) == "table" then
      count = count + 1
      add(button, bag, "bank")
    end
  end
  return count
end

-- Brief BG3: the Forever bank. The camelot game type loads Camelot/BankFrame.xml and the Mainline
-- bank templates (Blizzard_UIPanels_Game.toc:137-141). BankFrame holds the global BankPanel
-- (Camelot/BankFrame.xml:85-87, itemButtonTemplate CamelotBankItemButtonTemplate, :33, which inherits
-- BankItemButtonTemplate), and the panel draws its slots from a frame pool parented to itself
-- (Mainline/BankFrameTemplates.lua:683 CreateFramePool("ItemButton", self, ...)). There are no named
-- slot globals and no bag id on the panel, so collectBank above finds nothing there.
--
-- Every page, bank tab or bank type the player picks goes through the one panel method
-- GenerateItemSlotsForSelectedTab, which releases the whole pool and acquires it again (:1062-1063),
-- each button Init'd with the tab and slot it now shows and shown (:1040-1041): reached from Reset
-- (:937-944, on OnShow :688-693 and on SetBankType :845-852, which the bank's own tabs call,
-- Mainline/BankFrameTemplates.lua:52-59), from a tab picked (:806-812 to RefreshBankPanel :870-891)
-- and from a page (:624-660). A released button is hidden (:677-680, Pool_HideAndClearAnchors), so
-- only the shown ones are taken, and their tab and slot are read again when a sliced pass reaches
-- them (drawJob), so a button the pool handed another slot in between draws the slot it shows.
--
-- What is hooked: that one method, with hooksecurefunc on the panel itself, the way hookFrame takes
-- each container frame's UpdateItems. It only asks for the queued pass, which starts the next frame.
-- No script is hooked on the panel or on BankFrame, a managed UI panel (BankFrameRegistration.lua:11
-- RegisterUIPanel, and ShowUIPanel in Mainline/BankFrameTemplates.lua:120): see the panelhook shape in
-- tests/spec/taint_lint_spec.lua. The buttons are found with the panel's own GetChildren, a C side
-- frame method like IsShown and GetParent, never through the pool's Lua (the enumerator the panel
-- itself uses is one of the names the taint lint refuses).
Overlay.BANK_PANEL_HOOK = "GenerateItemSlotsForSelectedTab"

-- The panel the hook was taken on, weakly held, so a later call takes nothing twice.
local hookedPanels = setmetatable({}, { __mode = "k" })

local function hookBankPanel(panel)
  if not Overlay.installed or type(panel) ~= "table" or hookedPanels[panel] then
    return false
  end
  hookedPanels[panel] = true
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" or type(panel[Overlay.BANK_PANEL_HOOK]) ~= "function" then
    return false
  end
  local ok, err = pcall(hook, panel, Overlay.BANK_PANEL_HOOK, queueRefresh)
  if not ok then
    return trace("BankPanel hook", err)
  end
  Overlay.hooks.bankPanel = true
  return true
end

-- The Forever bank panel's shown item buttons, handed to add with no bag hint (each one carries its
-- own tab and slot, Overlay.BankPanelSlot), where "bank" and as pooled, so its overlay comes from the
-- stock made at login (brief BG3, see "The bank panel's stock"). Only while BankFrame and the panel
-- are both shown: the panel keeps its pool acquired when the bank closes (its OnHide releases
-- nothing, :695-704), so a closed bank would otherwise be walked on every bag update.
local function collectBankPanel(add)
  local panel = rawget(_G, "BankPanel")
  if type(panel) ~= "table" then
    return 0
  end
  hookBankPanel(panel)
  if not isShown(rawget(_G, "BankFrame")) then
    -- The stock is made at login (Overlay.Install); a panel the client made after that gets its
    -- stock on the first pass that sees it closed, and a stock that fell short is topped up here.
    if Overlay.stockMade == 0 then
      Overlay.FillStock()
    else
      Overlay.TopUpStock()
    end
    return 0
  end
  if not isShown(panel) or type(panel.GetChildren) ~= "function" then
    return 0
  end
  local children = { pcall(panel.GetChildren, panel) }
  if not children[1] then
    trace("BankPanel children", children[2])
    return 0
  end
  local count = 0
  for index = 2, #children do
    local button = children[index]
    if type(button) == "table" and rawget(button, "isInitialized") ~= false and isShown(button) then
      local _, slot = Overlay.BankPanelSlot(button)
      if slot ~= nil then
        count = count + 1
        add(button, nil, "bank", true)
      end
    end
  end
  return count
end

-- Every item button the client is currently showing, as { button, bag, slot, where }.
-- Deduplicated by frame and by button, because the same bag can be reached both through the
-- modern enumerator and as a named global.
function Overlay.Targets()
  local targets, seenButton, seenFrame = {}, {}, {}

  local function add(button, bagHint, whereHint, pooled)
    if type(button) ~= "table" or seenButton[button] then
      return
    end
    seenButton[button] = true
    local bag, slot = Overlay.ButtonSlot(button, bagHint)
    if slot == nil then
      return
    end
    -- Brief PF7: the hints too, so a sliced pass reads the button's slot again when it gets there.
    -- Brief BG3: pooled marks a Forever bank panel button, whose overlay comes from the stock.
    targets[#targets + 1] = {
      button = button,
      bag = bag,
      slot = slot,
      where = whereHint or Overlay.WhereForBag(bag),
      hint = bagHint,
      whereHint = whereHint,
      pooled = pooled or nil,
    }
  end

  local function visitFrame(frame)
    if type(frame) ~= "table" or seenFrame[frame] then
      return
    end
    seenFrame[frame] = true
    collectFrame(frame, add)
  end

  -- Never ContainerFrameUtil_EnumerateContainerFrames: see the taint note at the top of the file.
  visitFrame(rawget(_G, "ContainerFrameCombinedBags"))
  for index = 1, constant("NUM_CONTAINER_FRAMES", 13) do
    visitFrame(rawget(_G, "ContainerFrame" .. index))
  end
  collectBank(add)
  collectBankPanel(add)
  return targets
end

--------------------------------------------------------------------------------
-- The overlay frames
--------------------------------------------------------------------------------

-- Overlays by button, weakly held. Nothing is written onto the button, so the bag frame is
-- left exactly as the client built it, and an overlay goes as soon as its button does.
local overlays = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- The Keep mark (brief T4)
--------------------------------------------------------------------------------

-- The player's level and side, as Core/Keep.lua takes them. Two client calls about the player,
-- never about an item, read once and kept until the player levels (Overlay.OnEvent).
function Overlay.PlayerFacts()
  local held = Overlay.player
  if held then
    return held.level, held.faction
  end
  local level = tonumber(apiCall(rawget(_G, "UnitLevel"), "player"))
  local word = apiCall(rawget(_G, "UnitFactionGroup"), "player")
  -- Brief BQ14 follow up: the pretend level and side (Core/Demo.lua) while they are set; Demo.Apply
  -- drops the held facts when either moves.
  local demo = ItemTree.Demo
  if type(demo) == "table" then
    if type(demo.PlayerLevel) == "function" then
      local ok, pretend = pcall(demo.PlayerLevel, level)
      if ok then
        level = pretend
      end
    end
    if type(demo.FactionWord) == "function" then
      local ok, pretend = pcall(demo.FactionWord)
      if ok and pretend then
        word = pretend
      end
    end
  end
  local keep = ItemTree.Keep
  local faction = keep and type(keep.FactionOf) == "function" and keep.FactionOf(word) or nil
  Overlay.player = { level = level, faction = faction }
  return level, faction
end

-- Whether a slot's item wears the Keep mark. Scored from ItemTree's own tables through the
-- per item cache in Core/Keep.lua; nothing here asks the client about the item.
function Overlay.KeepFor(itemId, settings)
  if not itemId or not settingOn(settings, "keepMarks") then
    return false
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return false
  end
  local level, faction = Overlay.PlayerFacts()
  local ok, score = pcall(keep.CachedScore, itemId, level, faction)
  if not ok or score == nil then
    return false
  end
  return keep.Marked(score) and true or false
end

-- The glow's side for a slot this wide. Pure.
function Overlay.GlowSize(slotWidth)
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    width = Theme.sizes.ITEMTREE_ICON_BAGSLOT
  end
  return math.floor(width * (Theme.sizes.ITEMTREE_KEEP_GLOW_SCALE or 1.6) + 0.5)
end

-- The gold glow round a slot: the client's action button border (Assets KEEP_GLOW), added
-- rather than laid over, tinted ITEMTREE_COLOR_KEEP_GLOW at ITEMTREE_KEEP_GLOW_ALPHA. It is a
-- texture on ItemTree's own frame, in its BACKGROUND layer, so the badges (child frames) draw
-- over it; its centre is clear, so the icon and the count read through it. centreOn is the slot
-- it rings, which may be another frame than its own (Baganator's corner frame). Hidden at birth.
function Overlay.MakeGlow(frame, centreOn)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local ok, glow = pcall(frame.CreateTexture, frame, nil, "BACKGROUND")
  if not ok or type(glow) ~= "table" then
    return nil
  end
  local assets = ItemTree.Assets
  if type(assets) == "table" and type(assets.Apply) == "function" then
    pcall(assets.Apply, glow, "KEEP_GLOW")
  end
  method(glow, "SetBlendMode", "ADD")
  local color = type(Theme.ColorTable) == "function" and Theme.ColorTable("ITEMTREE_COLOR_KEEP_GLOW") or nil
  if color then
    method(glow, "SetVertexColor", color.r, color.g, color.b, Theme.sizes.ITEMTREE_KEEP_GLOW_ALPHA or 0.7)
  end
  method(glow, "ClearAllPoints")
  method(glow, "SetPoint", "CENTER", centreOn or frame, "CENTER", 0, 0)
  method(glow, "Hide")
  return glow
end

-- The frame's side for a slot this wide, ITEMTREE_KEEP_RING_SCALE times it, rounded to a whole pixel.
-- Pure.
function Overlay.RingSize(slotWidth)
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    width = Theme.sizes.ITEMTREE_ICON_BAGSLOT
  end
  return math.floor(width * (Theme.sizes.ITEMTREE_KEEP_RING_SCALE or 1.06) + 0.5)
end

-- Brief K3: the bevelled gold frame on the slot's own edge, beside the glow. ItemTree's own art
-- (Assets KEEP_RING), its gold baked in, so it is drawn untinted, centred on the slot at RingSize.
-- It is a texture on ItemTree's own frame, in its ARTWORK layer: the overlay frame sits above the
-- button, so the frame draws over the icon and the client's quality border (a kept green item
-- reads gold), over the glow in the BACKGROUND layer beneath it, and under the badges, child
-- frames of the overlay. slot is the button it frames, which may be another frame than its own
-- (Baganator's corner frame). Hidden at birth, and shown and hidden with the glow.
function Overlay.MakeRing(frame, slot)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local ok, ring = pcall(frame.CreateTexture, frame, nil, "ARTWORK")
  if not ok or type(ring) ~= "table" then
    return nil
  end
  local assets = ItemTree.Assets
  if type(assets) == "table" and type(assets.Apply) == "function" then
    pcall(assets.Apply, ring, "KEEP_RING")
  end
  method(ring, "ClearAllPoints")
  method(ring, "SetPoint", "CENTER", slot or frame, "CENTER", 0, 0)
  method(ring, "Hide")
  return ring
end

-- Brief PR6: the profession icon, one texture on ItemTree's own frame (never on the client's
-- button), in its OVERLAY layer so it draws over the Keep frame and glow. Made the first time a
-- slot needs it and hidden at birth. Brief PR20: its frame is made with it, on the same frame: the
-- dark backing (icon.backing) at OVERLAY sublevel -2 and the eight bevel pieces (icon.pieces) at
-- -1, both under the icon, all hidden at birth.
function Overlay.MakeProfessionIcon(frame)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local ok, icon = pcall(frame.CreateTexture, frame, nil, "OVERLAY")
  if not ok or type(icon) ~= "table" then
    return nil
  end
  method(icon, "Hide")
  local made, backing = pcall(frame.CreateTexture, frame, nil, "OVERLAY", nil, -2)
  if made and type(backing) == "table" then
    method(backing, "Hide")
    icon.backing = backing
  end
  icon.pieces = {}
  for _, piece in ipairs(Overlay.PROFESSION_FRAME_ORDER) do
    local took, texture = pcall(frame.CreateTexture, frame, nil, "OVERLAY", nil, -1)
    if took and type(texture) == "table" then
      method(texture, "Hide")
      icon.pieces[piece] = texture
    end
  end
  return icon
end

-- Hides the icon and its frame.
local function hideProfession(icon)
  if type(icon) ~= "table" then
    return
  end
  method(icon, "Hide")
  method(icon.backing, "Hide")
  for _, texture in pairs(type(icon.pieces) == "table" and icon.pieces or {}) do
    method(texture, "Hide")
  end
end
Overlay.HideProfession = hideProfession

-- The bevel's atlas names as the client holds them, { [piece] = name }, or false where any one is
-- missing (the frame is then drawn flat). Each key's own name first, then its alts, asked of
-- C_Texture.GetAtlasInfo once a session (Overlay.professionFrameArt).
function Overlay.ProfessionFrameArt()
  if Overlay.professionFrameArt ~= nil then
    return Overlay.professionFrameArt
  end
  local api = rawget(_G, "C_Texture")
  local assets = ItemTree.Assets
  local out = false
  if type(api) == "table" and type(api.GetAtlasInfo) == "function" and type(assets) == "table" then
    out = {}
    for _, piece in ipairs(Overlay.PROFESSION_FRAME_ORDER) do
      local key = Overlay.PROFESSION_FRAME_KEYS[piece]
      local entry = type(assets.Has) == "function" and assets.Has(key) and assets.Get(key) or nil
      local found
      if type(entry) == "table" and entry.kind == "atlas" then
        local names = { entry.name }
        for _, alt in ipairs(entry.alts or {}) do
          names[#names + 1] = alt
        end
        for _, name in ipairs(names) do
          if not found and apiCall(api.GetAtlasInfo, name) then
            found = name
          end
        end
      end
      if not found then
        out = false
        break
      end
      out[piece] = found
    end
  end
  Overlay.professionFrameArt = out
  return out
end

-- One region of the frame, placed by its rectangle from the framed box's top left, which is pad
-- px up and left of the icon's own top left.
local function placeFramePart(texture, icon, rect, pad)
  method(texture, "ClearAllPoints")
  method(texture, "SetPoint", "TOPLEFT", icon, "TOPLEFT", rect.x - pad, pad - rect.y)
  method(texture, "SetSize", math.max(rect.w, 0.01), math.max(rect.h, 0.01))
end

-- Paints one piece flat: the white fill, tinted.
local function paintFlat(texture, colour)
  local assets = ItemTree.Assets
  if type(assets) ~= "table" or type(assets.Apply) ~= "function" then
    return false
  end
  local ok, took = pcall(assets.Apply, texture, "FILL_WHITE8X8")
  if not ok or took == false then
    return false
  end
  if colour then
    method(texture, "SetVertexColor", colour.r, colour.g, colour.b, colour.a or 1)
  end
  return true
end

-- Brief PR20: draws the icon's frame round it at badge size size. The bevel where the client
-- holds every piece of its art, else flat 1px edges. Answers "bevel" or "flat" (icon.frameArt).
local function drawProfessionFrame(icon, size)
  local art = Overlay.ProfessionFrameArt()
  local shape = Overlay.ProfessionFrame(size, not art)
  local edge = type(Theme.ColorTable) == "function" and Theme.ColorTable(Overlay.PROFESSION_FRAME_EDGE) or nil
  local fill = type(Theme.ColorTable) == "function" and Theme.ColorTable(Overlay.PROFESSION_FRAME_FILL) or nil
  local backing = icon.backing
  if backing then
    if paintFlat(backing, fill) then
      placeFramePart(backing, icon, shape.face, shape.pad)
      method(backing, "Show")
    else
      method(backing, "Hide")
    end
  end
  for _, piece in ipairs(Overlay.PROFESSION_FRAME_ORDER) do
    local texture, rect = icon.pieces and icon.pieces[piece], shape.pieces[piece]
    if texture then
      local painted = false
      if rect and art then
        painted = method(texture, "SetAtlas", art[piece]) ~= false
        if painted and edge then
          method(texture, "SetVertexColor", edge.r, edge.g, edge.b, 1)
        end
      elseif rect then
        painted = paintFlat(texture, edge)
      end
      if painted then
        placeFramePart(texture, icon, rect, shape.pad)
        method(texture, "Show")
      else
        method(texture, "Hide")
      end
    end
  end
  icon.frameArt = art and "bevel" or "flat"
  icon.frameShape = shape
  return icon.frameArt
end

-- Brief PR20: Overlay.CountLift for one item button: whether it is showing a stack count, read off
-- the Count the client's item button template gives it (shown, with text), and that count's own
-- height. Read only, nothing is written onto the button. A button with no Count reads as none.
function Overlay.CountLiftFor(button, slotHeight)
  local count = type(button) == "table" and rawget(button, "Count") or nil
  if type(count) ~= "table" or not isShown(count) then
    return 0
  end
  local text = method(count, "GetText")
  if text == nil or text == "" then
    return 0
  end
  local height = tonumber(method(count, "GetStringHeight")) or tonumber(method(count, "GetHeight"))
  return Overlay.CountLift(true, slotHeight, height)
end

-- Shows a slot's profession icon for skillLine, or hides it for nil. anchor is the slot it sits
-- on (the overlay frame, or Baganator's item button), size the badge size, chosen the corner
-- setting, and badgeCorner, badgeCount the badges the slot draws, which move it on a clash (see
-- Overlay.ProfessionCornerFor and ProfessionAnchor); lift is Overlay.CountLift's answer for the
-- slot's stack count (0 or nil for none). The icon is size px and its frame's box size plus twice
-- the pad, the box placed in the corner. The bag overlay and the settings preview both come
-- through here. Brief PM1: lookCorner is the corner the slot's Keep look holds (Overlay.LookCorner),
-- which the icon steps past too; nil for none. Answers the corner it took, or nil when hidden.
function Overlay.ShowProfession(
  icon,
  skillLine,
  anchor,
  size,
  chosen,
  badgeCorner,
  badgeCount,
  slotWidth,
  lift,
  lookCorner
)
  if type(icon) ~= "table" then
    return nil
  end
  local key = skillLine and Overlay.ProfessionIconKey(skillLine) or nil
  if not key then
    hideProfession(icon)
    icon.skillLine = nil
    return nil
  end
  if icon.skillLine ~= skillLine then
    local assets = ItemTree.Assets
    local applied = false
    if type(assets) == "table" and type(assets.Apply) == "function" then
      local ok, took = pcall(assets.Apply, icon, key)
      applied = ok and took ~= false
    end
    if not applied then
      hideProfession(icon)
      icon.skillLine = nil
      return nil
    end
    local crop = Overlay.PROFESSION_CROP
    method(icon, "SetTexCoord", crop[1], crop[2], crop[3], crop[4])
    icon.skillLine = skillLine
  end
  size = tonumber(size) or Overlay.BadgeSize(nil)
  local pad = Overlay.PROFESSION_FRAME_PAD
  local box = size + 2 * pad
  local corner = Overlay.ProfessionCornerFor(chosen, badgeCorner, badgeCount, lookCorner)
  local point, relativePoint, x, y = Overlay.ProfessionAnchor(box, corner, slotWidth, badgeCorner, badgeCount, lift)
  local signs = CORNER_SIGNS[corner]
  method(icon, "SetSize", size, size)
  method(icon, "ClearAllPoints")
  method(icon, "SetPoint", point, anchor, relativePoint, x + signs.x * pad, y + signs.y * pad)
  method(icon, "Show")
  drawProfessionFrame(icon, size)
  icon.corner = corner
  return corner
end

--------------------------------------------------------------------------------
-- The Keep looks, tiers and demo (brief K7)
--
-- Twelve looks for a Worth keeping item in the bags (ten from brief K7, Dashed border and Flag from
-- brief K12), each drawn in the colour of the item's tier on one of three ramps (UI/Theme.lua
-- keepRamps). Style 0 is the Classic look, the gold glow and the bevelled frame together, which
-- ignores the tier (brief K17: the Flag in Single colour ships instead); 1 to 12 are the looks
-- /itemtree demo shows and the Keep marks section's Style row offers (UI/Options.lua). Every look
-- is textures on ItemTree's own overlay frame, made the first time a slot needs them and never on
-- the button itself.
--
-- Overlay.LookParts is the pure description of what a look draws (asset key, layer, blend, tint,
-- size and anchor, part by part), so the specs read it with no client; Overlay.ShowKeep draws it.
-- A look whose art the client will not draw (Assets.Apply false) falls back to look 1, and
-- Overlay.lookFallback remembers which asset refused, for the debug line and the demo's line.
--------------------------------------------------------------------------------

Overlay.KEEP_STYLE_SHIPPED = 0

-- Which asset each look fell back from, by style, for the debug line and the demo's line.
Overlay.lookFallback = {}

-- The twelve looks, in the order the demo and the Style row number them.
Overlay.KEEP_LOOKS = {
  { key = "glow", name = L["Glow"] },
  { key = "ring", name = L["Ring"] },
  { key = "slotglow", name = L["Slot glow"] },
  { key = "border", name = L["Thin border"] },
  { key = "inner", name = L["Inner glow"] },
  { key = "gem", name = L["Corner gem"] },
  { key = "bar", name = L["Bottom bar"] },
  { key = "ribbon", name = L["Ribbon"] },
  { key = "cosmetic", name = L["Cosmetic frame"] },
  { key = "pulse", name = L["Pulse"] },
  { key = "dash", name = L["Dashed border"] },
  { key = "flag", name = L["Flag"] },
}
Overlay.KEEP_SHIPPED_NAME = L["Glow and frame"]

-- The ramps' names, in the words the demo prints.
Overlay.RAMP_NAMES = { gold = L["Gold"], quality = L["Quality"], heat = L["Heat"], single = L["Single colour"] }
-- Brief K15: the one tier set, built from the player's keepColor (Overlay.SyncSingle).
Overlay.RAMP_SINGLE = "single"
Overlay.RAMP_DEFAULT = "gold"

-- Brief K8: each tier's colour in words (Theme.keepRamps hue), for the demo's chat line.
Overlay.HUE_NAMES = {
  gold = L["gold"],
  ["bright gold"] = L["bright gold"],
  green = L["green"],
  blue = L["blue"],
  purple = L["purple"],
  orange = L["orange"],
  red = L["red"],
  -- Brief K15: the Single colour picks (UI/Theme.lua keepColors) and the player's own colour.
  pink = L["pink"],
  teal = L["teal"],
  white = L["white"],
  silver = L["silver"],
  custom = L["custom"],
  -- Brief K17: the Yellow pick.
  yellow = L["yellow"],
}

-- Which asset key each colour word draws for the Slot glow and Thin border looks.
local SLOT_GLOW_KEYS = {
  white = "KEEP_SLOT_GLOW_WHITE",
  green = "KEEP_SLOT_GLOW_GREEN",
  blue = "KEEP_SLOT_GLOW_BLUE",
  purple = "KEEP_SLOT_GLOW_PURPLE",
  orange = "KEEP_SLOT_GLOW_ORANGE",
  artifact = "KEEP_SLOT_GLOW_ARTIFACT",
  heirloom = "KEEP_SLOT_GLOW_HEIRLOOM",
}
local BORDER_KEYS = {
  gray = "KEEP_BORDER_GRAY",
  white = "KEEP_BORDER_WHITE",
  green = "KEEP_BORDER_GREEN",
  blue = "KEEP_BORDER_BLUE",
  purple = "KEEP_BORDER_PURPLE",
  orange = "KEEP_BORDER_ORANGE",
  artifact = "KEEP_BORDER_ARTIFACT",
}

-- The corner the Corner gem sits in for each badge corner: diagonally across from the badges,
-- except that across from the top left is the stack count's corner, so the gem goes top right
-- there instead (brief K12).
local GEM_CORNER = {
  TOPLEFT = "TOPRIGHT",
  TOPRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPRIGHT",
  BOTTOMRIGHT = "TOPLEFT",
}

-- Brief K12: the Flag sits top left, or top right where the badges have the top left.
local FLAG_CORNER = {
  TOPLEFT = "TOPRIGHT",
  TOPRIGHT = "TOPLEFT",
  BOTTOMLEFT = "TOPLEFT",
  BOTTOMRIGHT = "TOPLEFT",
}

-- Brief K24b (owner ruling 2026-10-05: "We have KEEP AND VALUE but we probably need DISENCHANT",
-- "flag in violet"): the Sell (AH) corner coin, the Disenchant (Sell AH) Enchanting glyph and K21's
-- tilted coin under a Keep look are gone. The bags draw three marks, all in the player's one
-- chosen Keep look: Keep in the Keep colour, Value in the Valuable colour, and Disenchant in
-- DISENCHANT_COLOUR (Overlay.KeepStateFor). Nothing is drawn for Auction or Vendor on their own.
Overlay.DISENCHANT_COLOUR = { r = 0.64, g = 0.44, b = 0.88 }

-- The Disenchant mark's colour in TierColour's shape, the same violet as the Disenchant tag; no
-- art word, so a look that picks its art by colour word draws its white art tinted. Pure.
function Overlay.DisenchantColour()
  local violet = Overlay.DISENCHANT_COLOUR
  return { r = violet.r, g = violet.g, b = violet.b, a = 1, hue = "purple" }
end

-- Brief BQ9: the Use mark (the fifth answer of Overlay.KeepStateFor and the violet argument the
-- looks take, as a word): the play wedge in a slot's corner, in the Use blue (Theme ITEMTREE_COLOR_USE,
-- the same hue as Jettison's Use rows), whatever Keep look the player chose.
Overlay.USE_MARK = "use"

-- Brief ST1 (QA item 279): the setting that turns the Use mark off (Core/Init.lua, on by default).
Overlay.USE_MARK_SETTING = "keepUseMark"

--- Brief ST1: whether these settings draw the Use mark. A setting never written reads as on. Pure.
function Overlay.UseMarkOn(settings)
  return settingOn(settings, Overlay.USE_MARK_SETTING)
end

-- Brief ST2 (QA item 307, the owner's ruling A: "two sliders by family"): the Mark size slider
-- (keepMarkScale, Core/Init.lua) under the Keep and Use marks heading sizes the marks a look draws
-- in a slot's corner, the Keep Flag, the Corner gem and the Use mark, as a multiple of today's
-- size; Bag badge size (now Badge size) sizes the New and Changed badges alone. ST1 had the Use
-- mark follow the badges' slider while the Keep marks followed nothing. The looks that frame the
-- whole slot (the glows, rings, borders, the bar, the ribbon) keep the slot's size: a border drawn
-- smaller than its slot no longer frames it. 1 is today's size; 0.4 is ST1's smallest Use mark (5
-- px on a 36 px slot) and 1.5 its largest (18 px, half the slot), so the range keeps ST1's reach
-- with no dead end. A stored value outside the range is held to it, a malformed one reads as 1.
Overlay.MARK_SCALE_SETTING = "keepMarkScale"
Overlay.MARK_SCALE_DEFAULT = 1
Overlay.MARK_SCALE_MIN = 0.4
Overlay.MARK_SCALE_MAX = 1.5
Overlay.MARK_SCALE_STEP = 0.05

--- Brief ST2: the Mark size setting as a number to multiply by, held to the slider's range. Pure.
function Overlay.MarkScale(value)
  if type(value) ~= "number" or value ~= value or value <= 0 then
    return Overlay.MARK_SCALE_DEFAULT
  end
  if value < Overlay.MARK_SCALE_MIN then
    return Overlay.MARK_SCALE_MIN
  end
  if value > Overlay.MARK_SCALE_MAX then
    return Overlay.MARK_SCALE_MAX
  end
  return value
end

--- Brief ST2: the side of a corner mark whose share of the slot is share (the look's own scale,
--- its size today) on a slot this wide at this Mark size setting, to a whole pixel. At the default
--- it is exactly Overlay.LookSide(slotWidth, share), so nothing moves for a player who never
--- touches the slider. Never past half the slot, so the item's icon always shows (the Corner gem
--- stops there from 1.25), and never under a pixel. Pure.
function Overlay.MarkSide(slotWidth, share, scale)
  local side = Overlay.LookSide(slotWidth, (tonumber(share) or 1) * Overlay.MarkScale(scale))
  local cap = math.floor(Overlay.LookSide(slotWidth, 1) / 2)
  if side > cap then
    side = cap
  end
  if side < 1 then
    side = 1
  end
  return side
end

--- Brief ST1 (QA item 279), brief ST2: the Use mark's side on a slot this wide at this Mark size
--- setting (it followed Bag badge size under ST1). At the default it is what UI15 made it,
--- ITEMTREE_USE_MARK_SCALE of the slot (12 px on a 36 px slot, the Flag's size); 5 px at 0.4 and 18
--- px at 1.5 on a 36 px slot. Pure.
function Overlay.UseMarkSide(slotWidth, scale)
  return Overlay.MarkSide(slotWidth, Theme.sizes.ITEMTREE_USE_MARK_SCALE or (0.42 * 0.8), scale)
end

-- The Use mark's colour in TierColour's shape. Pure over UI/Theme.lua.
function Overlay.UseColour()
  local colour = Theme.ColorTable("ITEMTREE_COLOR_USE")
  return { r = colour.r, g = colour.g, b = colour.b, a = 1, hue = "blue", token = "ITEMTREE_COLOR_USE" }
end

-- A stored style as 0 to 12. Anything else is the shipped look. Pure.
function Overlay.StyleIndex(value)
  local index = tonumber(value)
  if index == nil or index ~= math.floor(index) or index < 0 or index > #Overlay.KEEP_LOOKS then
    return Overlay.KEEP_STYLE_SHIPPED
  end
  return index
end

-- A look's name in words, style 0 included. Pure.
function Overlay.StyleName(style)
  local look = Overlay.KEEP_LOOKS[Overlay.StyleIndex(style)]
  return look and look.name or Overlay.KEEP_SHIPPED_NAME
end

-- A stored ramp as one of the ramp names. Anything else is Gold. Pure.
function Overlay.RampName(value)
  local ramps = Theme.keepRamps or {}
  local name = type(value) == "string" and value:lower() or nil
  if name and name ~= "order" and type(ramps[name]) == "table" and #ramps[name] > 0 then
    return name
  end
  return Overlay.RAMP_DEFAULT
end

-- Brief K24b (E): the ONE reader of the ramp the settings choose. The Colours choice (Gold, Quality,
-- Heat, Single colour) is hidden and the look always uses the single colour, so this answers
-- RAMP_SINGLE whatever the saved keepRamp holds (a saved choice of another set is left in the
-- saved file and ignored). The bag looks, the Settings example, the debug line and the tag tints
-- (Overlay.TagColours) all read it, so they cannot disagree. The demo's own ramp is the demo's.
-- Pure.
function Overlay.SettingsRamp(_settings)
  return Overlay.RAMP_SINGLE
end

-- Brief K24b (D1): the Keep tag's and the Auction tag's tints for these settings, each { r, g, b }:
-- the Keep colour (the single colour ramp's tier, Overlay.TierColour) and the Valuable colour
-- (Overlay.ValueColour), both built from the settings first (Overlay.SyncSingle, SyncValue), so
-- the tags wear the very colours the bag looks are drawn in. nil for either that cannot be had.
function Overlay.TagColours(settings)
  settings = type(settings) == "table" and settings or {}
  Overlay.SyncSingle(settings)
  Overlay.SyncValue(settings)
  local rampName = Overlay.SettingsRamp(settings)
  local keep = Overlay.TierColour(rampName, 1)
  local value = Overlay.ValueColour(rampName)
  local keepTint = keep and { r = keep.r, g = keep.g, b = keep.b } or nil
  local valueTint = value and { r = value.r, g = value.g, b = value.b } or nil
  return keepTint, valueTint
end

-- Brief K15: the Single colour ramp the settings name, one tier (UI/Theme.lua SingleRamp). Pure.
function Overlay.SingleRamp(settings)
  settings = type(settings) == "table" and settings or {}
  return Theme.SingleRamp(settings.keepColor, settings.keepColorCustom)
end

-- Brief K15: builds Theme.keepRamps.single from the settings given, at draw time, so the Single
-- colour set always draws the colour those settings hold (the saved ones for the bags, a peek's
-- copy for the Settings example). Answers the ramp.
-- The colour the ramp was last built for, so a bag redraw that changes nothing allocates nothing.
local singleBuiltFor = nil

local function singleKey(settings)
  local key = Theme.KeepColorKey(settings.keepColor)
  if key ~= Theme.KEEP_COLOR_CUSTOM then
    return key
  end
  local colour = Theme.CustomColour(settings.keepColorCustom)
  return string.format("custom:%.4f:%.4f:%.4f", colour.r, colour.g, colour.b)
end

function Overlay.SyncSingle(settings)
  settings = type(settings) == "table" and settings or {}
  local ramps = Theme.keepRamps
  local key = singleKey(settings)
  if type(ramps) == "table" and key == singleBuiltFor and type(ramps.single) == "table" then
    return ramps.single
  end
  local ramp = Overlay.SingleRamp(settings)
  if type(ramps) == "table" then
    ramps.single = ramp
    singleBuiltFor = key
  end
  return ramp
end

-- A ramp's list of tiers. Pure.
function Overlay.Ramp(name)
  local ramps = Theme.keepRamps or {}
  return ramps[Overlay.RampName(name)] or {}
end

-- Brief K16: the player's valuable colour (UI/Theme.lua ValueColourEntry), which only the Single
-- colour set draws. Built at draw time from the settings given, as the Single colour ramp is, so
-- the bags draw the saved colour and the Settings example a peek's copy.
function Overlay.ValueColourEntry(settings)
  settings = type(settings) == "table" and settings or {}
  return Theme.ValueColourEntry(settings.keepValueColor, settings.keepValueColorCustom)
end

local valueEntry = nil
-- Brief OPT3 (F11): the colour key and custom channels the entry was last built for, so a bag pass
-- that changes nothing allocates nothing (as singleBuiltFor does for the Single colour ramp).
local valueBuiltFor, valueBuiltR, valueBuiltG, valueBuiltB = nil, nil, nil, nil

--- Builds the valuable colour from the settings given; answers the entry. The entry last built is
--- handed back while the colour key and, for the custom colour, its three channels are unchanged.
function Overlay.SyncValue(settings)
  local held = type(settings) == "table" and settings or {}
  local key = Theme.KeepColorKey(held.keepValueColor, Theme.KEEP_VALUE_COLOR_DEFAULT)
  local r, g, b
  if key == Theme.KEEP_COLOR_CUSTOM and type(held.keepValueColorCustom) == "table" then
    local custom = held.keepValueColorCustom
    r, g, b = custom.r, custom.g, custom.b
  end
  if valueEntry ~= nil and key == valueBuiltFor and r == valueBuiltR and g == valueBuiltG and b == valueBuiltB then
    return valueEntry
  end
  valueEntry = Overlay.ValueColourEntry(settings)
  valueBuiltFor, valueBuiltR, valueBuiltG, valueBuiltB = key, r, g, b
  return valueEntry
end

-- Brief K13 addendum: the colour a valuable item wears its look in, in TierColour's shape: the
-- legendary orange (ITEMTREE_COLOR_KEEP_VALUE) at full alpha, its art word orange. Brief K16: with
-- the Single colour set (rampName "single") it is the player's valuable colour instead, as last
-- built by Overlay.SyncValue. Pure apart from reading that.
function Overlay.ValueColour(rampName)
  local entry
  if rampName ~= nil and Overlay.RampName(rampName) == Overlay.RAMP_SINGLE then
    entry = valueEntry or Theme.ValueColourEntry(nil)
  else
    entry = Theme.ValueColourEntry(Theme.KEEP_VALUE_COLOR_FIXED)
  end
  local color = entry.rgb or (entry.color and Theme.ColorTable(entry.color)) or { r = 1, g = 0.5, b = 0 }
  return {
    r = color.r,
    g = color.g,
    b = color.b,
    a = tonumber(entry.alpha) or 1,
    token = entry.color,
    word = entry.word,
    hue = entry.hue,
  }
end

--- Brief K16: the valuable colour in words while the settings choose the Single colour set ("teal",
--- "custom"), or nil with Gold, Quality or Heat, whose valuable colour is the fixed orange. For
--- /itemtree debug and the demo's line. Pure.
function Overlay.ValueColourName(settings)
  settings = type(settings) == "table" and settings or {}
  if Overlay.SettingsRamp(settings) ~= Overlay.RAMP_SINGLE then
    return nil
  end
  local entry = Overlay.ValueColourEntry(settings)
  return Overlay.HUE_NAMES[entry.hue] or entry.hue
end

-- One tier of a ramp as { r, g, b, a, token, word, hue }, the tier clamped to the ramp. Pure.
function Overlay.TierColour(rampName, tier)
  local ramp = Overlay.Ramp(rampName)
  local count = #ramp
  if count == 0 then
    return nil
  end
  local index = math.floor(tonumber(tier) or 1)
  if index < 1 then
    index = 1
  elseif index > count then
    index = count
  end
  local entry = ramp[index]
  -- Brief K15: the player's own colour carries its rgb and no token.
  local color = entry.rgb or (entry.color and Theme.ColorTable(entry.color)) or { r = 1, g = 1, b = 1 }
  return {
    r = color.r,
    g = color.g,
    b = color.b,
    a = tonumber(entry.alpha) or 1,
    token = entry.color,
    word = entry.word,
    hue = entry.hue,
  }
end

-- Brief TBR2: the colour the bag flag wears for one tier of a ramp, in TierColour's shape
-- ({ r, g, b, a, token, word, hue }): the tier's colour, or Overlay.ValueColour for a valuable
-- item. nil for tier 0 (nothing drawn) or an empty ramp. The one place the colour is chosen:
-- Overlay.LookParts and Overlay.KeepStateFor both call it (brief K24b: the tooltip's tags read
-- the same Keep and Valuable colours through Overlay.TagColours). Pure apart from what
-- ValueColour reads.
function Overlay.FlagColour(rampName, tier, valuable, violet)
  tier = math.floor(tonumber(tier) or 0)
  if tier < 1 then
    return nil
  end
  local colour = Overlay.TierColour(rampName, tier)
  if not colour then
    return nil
  end
  if valuable then
    colour = Overlay.ValueColour(rampName)
  elseif violet == Overlay.USE_MARK then
    colour = Overlay.UseColour()
  elseif violet then
    -- Brief K24b: the Disenchant mark, never over a valuable or keep colour.
    colour = Overlay.DisenchantColour()
  end
  return colour
end

-- A colour as { r, g, b, a } at a share of its brightness, the alpha kept. Pure.
function Overlay.Darken(tint, factor)
  factor = tonumber(factor) or 1
  return { tint[1] * factor, tint[2] * factor, tint[3] * factor, tint[4] }
end

-- Brief K15: how far in from the slot's corner a corner part sits on a slot this wide: pixels on
-- a 36px slot (ITEMTREE_ICON_BAGSLOT) scaled with the slot to a whole pixel, or the badges' own
-- Overlay.INSET where the part names none. Pure.
function Overlay.CornerInset(slotWidth, pixels)
  pixels = tonumber(pixels)
  if pixels == nil then
    return Overlay.INSET
  end
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    width = Theme.sizes.ITEMTREE_ICON_BAGSLOT
  end
  return math.max(0, math.floor(pixels * width / Theme.sizes.ITEMTREE_ICON_BAGSLOT + 0.5))
end

-- The side of a centred part for a slot this wide at this scale, to a whole pixel. Pure.
function Overlay.LookSide(slotWidth, scale)
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    width = Theme.sizes.ITEMTREE_ICON_BAGSLOT
  end
  return math.floor(width * (tonumber(scale) or 1) + 0.5)
end

local function sizeToken(key, fallback)
  local value = Theme.sizes[key]
  if value == nil then
    return fallback
  end
  return value
end

-- The glow part every glow look shares: the action button border, added, in the tier colour.
local function glowPart(colour, pulse)
  return {
    part = "glow",
    asset = "KEEP_GLOW",
    layer = "BACKGROUND",
    blend = "ADD",
    tint = { colour.r, colour.g, colour.b, colour.a },
    scale = sizeToken("ITEMTREE_KEEP_GLOW_SCALE", 1.6),
    pulse = pulse or nil,
  }
end

-- A tint that draws a coloured client art in its own colour at the tier's alpha, or white art in
-- the tier's colour.
local function wordTint(colour)
  if colour.word == "white" then
    return { colour.r, colour.g, colour.b, colour.a }
  end
  return { 1, 1, 1, colour.a }
end

-- What one look draws for one tier, as a list of parts, each
--   { part, asset, layer, sublevel, blend, tint = { r, g, b, a } or nil, desaturate, scale,
--     anchor = "centre" | "corner" | "bottom", corner, pulse, span = "solid" | "fade",
--     gradient = { from = { r, g, b, a }, to = { r, g, b, a } }, march = seconds a cycle }
-- in draw order. style is 0 to 12, tier 1 to the ramp's length (0 draws nothing), corner the
-- badge corner setting. Brief K24b: violet (and not valuable) draws it in the Disenchant violet.
-- Brief K13 addendum: valuable draws the same look in Overlay.ValueColour,
-- the legendary orange above every ramp, in place of the tier's colour (the orange art where a
-- look picks its art by colour word); the shipped look tints its glow orange and keeps its frame.
-- Brief ST2: markSized marks a corner part the Mark size slider sizes (the Flag, the Corner gem,
-- the Use mark), its scale then being its share of the slot at the slider's default.
-- Pure.
function Overlay.LookParts(style, rampName, tier, corner, valuable, violet)
  tier = math.floor(tonumber(tier) or 0)
  if tier < 1 then
    return {}
  end
  style = Overlay.StyleIndex(style)
  local ramp = Overlay.Ramp(rampName)
  -- Brief TBR2: the colour the tooltip's Keep head wears too (Overlay.FlagColour).
  -- Brief K24b: violet draws the look in the Disenchant violet (the Disenchant mark).
  local colour = Overlay.FlagColour(rampName, tier, valuable, violet)
  if not colour then
    return {}
  end
  if tier > #ramp then
    tier = #ramp
  end
  -- Brief BQ9: the Use mark is its own glyph in every look, in the badge corner's opposite as the gem.
  if violet == Overlay.USE_MARK then
    return {
      {
        part = "usemark",
        asset = "USE_MARK",
        layer = "OVERLAY",
        tint = { colour.r, colour.g, colour.b, colour.a },
        -- Brief UI15 (QA item 211): 80% of BQ9's 0.42, the Flag's size (UI/Theme.lua).
        scale = sizeToken("ITEMTREE_USE_MARK_SCALE", 0.42 * 0.8),
        anchor = "corner",
        corner = GEM_CORNER[Overlay.Corner(corner)],
        inset = sizeToken("ITEMTREE_USE_MARK_INSET", 1),
        -- Brief ST2 (QA item 307): sized by the Mark size slider (Overlay.MarkSide), scale being
        -- its size at the slider's default. Under ST1 it followed Bag badge size.
        markSized = true,
      },
    }
  end
  local look = Overlay.KEEP_LOOKS[style]
  local key = look and look.key or "shipped"
  if key == "shipped" then
    -- Today's look, whatever the tier: the gold glow at its own alpha and the untinted frame. A
    -- valuable item's glow is orange at the same alpha (brief K16: the valuable colour, which
    -- may be the player's own colour with no token).
    local gold = valuable and colour or Theme.ColorTable("ITEMTREE_COLOR_KEEP_GLOW")
    return {
      glowPart({ r = gold.r, g = gold.g, b = gold.b, a = sizeToken("ITEMTREE_KEEP_GLOW_ALPHA", 0.7) }),
      { part = "ring", asset = "KEEP_RING", layer = "ARTWORK", scale = sizeToken("ITEMTREE_KEEP_RING_SCALE", 1.06) },
    }
  end
  if key == "glow" then
    return { glowPart(colour) }
  end
  if key == "ring" then
    -- The frame's gold is baked in, so the keep gold draws it as it is and any other colour
    -- takes the gold out first.
    local ring =
      { part = "ring", asset = "KEEP_RING", layer = "ARTWORK", scale = sizeToken("ITEMTREE_KEEP_RING_SCALE", 1.06) }
    if colour.token ~= "ITEMTREE_COLOR_KEEP_GLOW" then
      ring.desaturate = true
      ring.tint = { colour.r, colour.g, colour.b, colour.a }
    end
    return { ring }
  end
  if key == "slotglow" then
    return {
      {
        part = "slotglow",
        asset = SLOT_GLOW_KEYS[colour.word] or SLOT_GLOW_KEYS.white,
        layer = "ARTWORK",
        blend = "ADD",
        tint = SLOT_GLOW_KEYS[colour.word] and wordTint(colour) or { colour.r, colour.g, colour.b, colour.a },
        scale = sizeToken("ITEMTREE_KEEP_SLOTGLOW_SCALE", 39 / 36),
      },
    }
  end
  if key == "border" then
    return {
      {
        part = "border",
        asset = BORDER_KEYS[colour.word] or BORDER_KEYS.white,
        layer = "ARTWORK",
        tint = BORDER_KEYS[colour.word] and wordTint(colour) or { colour.r, colour.g, colour.b, colour.a },
        scale = sizeToken("ITEMTREE_KEEP_BORDER_SCALE", 1),
      },
    }
  end
  local tint = { colour.r, colour.g, colour.b, colour.a }
  if key == "inner" then
    return {
      {
        part = "inner",
        asset = "KEEP_INNER_GLOW",
        layer = "ARTWORK",
        blend = "ADD",
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_INNERGLOW_SCALE", 1),
      },
    }
  end
  if key == "gem" then
    -- Brief K12: ItemTree's own faceted gem, blended rather than added so its dark outline reads.
    return {
      {
        part = "gem",
        asset = "KEEP_GEM",
        layer = "ARTWORK",
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_GEM_SCALE", 0.4),
        anchor = "corner",
        corner = GEM_CORNER[Overlay.Corner(corner)],
        -- Brief ST2 (QA item 307): a corner mark, sized by the Mark size slider (Overlay.MarkSide).
        markSized = true,
      },
    }
  end
  if key == "dash" then
    -- Brief K12: the dashed frame on the slot's edge, its dashes marching round it, faster at
    -- the ramp's top tier.
    local seconds = sizeToken("ITEMTREE_KEEP_DASH_SECONDS", 0.6)
    if tier == #ramp and #ramp > 1 then
      seconds = sizeToken("ITEMTREE_KEEP_DASH_SECONDS_TOP", 0.3)
    end
    return {
      {
        part = "dash",
        asset = "KEEP_DASH",
        layer = "ARTWORK",
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_DASH_SCALE", 1),
        march = seconds,
      },
    }
  end
  if key == "flag" then
    -- Brief K12: the quiet look, a small flag in a top corner and nothing else. Brief K15: inset
    -- 2px from the corner on a 36px slot, so it never touches the edge.
    return {
      {
        part = "flag",
        asset = "KEEP_FLAG",
        layer = "ARTWORK",
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_FLAG_SCALE", 1 / 3),
        anchor = "corner",
        corner = FLAG_CORNER[Overlay.Corner(corner)],
        inset = sizeToken("ITEMTREE_KEEP_FLAG_INSET", 2),
        -- Brief ST2 (QA item 307): a corner mark, sized by the Mark size slider (Overlay.MarkSide).
        markSized = true,
      },
    }
  end
  if key == "bar" then
    -- Brief K8: the whole width, in the tier colour, then fading to a darker shade of it under
    -- the stack count's side, so the count stays readable on it.
    return {
      {
        part = "bar",
        asset = "FILL_WHITE8X8",
        layer = "ARTWORK",
        tint = tint,
        anchor = "bottom",
        span = "solid",
      },
      {
        part = "barfade",
        asset = "FILL_WHITE8X8",
        layer = "ARTWORK",
        anchor = "bottom",
        span = "fade",
        gradient = { from = tint, to = Overlay.Darken(tint, sizeToken("ITEMTREE_KEEP_BAR_DARKEN", 0.45)) },
      },
    }
  end
  if key == "ribbon" then
    return {
      {
        part = "ribbon",
        asset = "KEEP_RIBBON",
        layer = "ARTWORK",
        blend = "ADD",
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_RIBBON_SCALE", 44 / 36),
      },
    }
  end
  if key == "cosmetic" then
    return {
      {
        part = "cosmetic",
        asset = "KEEP_COSMETIC",
        layer = "ARTWORK",
        desaturate = true,
        tint = tint,
        scale = sizeToken("ITEMTREE_KEEP_COSMETIC_SCALE", 1),
      },
    }
  end
  -- Pulse: the glow breathing, with the client's slot flash behind it at the top tier only.
  local parts = {}
  if tier == #ramp and #ramp > 1 then
    parts[1] = {
      part = "flash",
      asset = "KEEP_FLASH",
      layer = "BACKGROUND",
      sublevel = -1,
      blend = "ADD",
      tint = tint,
      scale = sizeToken("ITEMTREE_KEEP_FLASH_SCALE", 90 / 36),
    }
  end
  parts[#parts + 1] = glowPart(colour, true)
  return parts
end

-- Brief PM1: the corner a look draws its own glyph in for one tier, the corner of its first part
-- anchored to a corner (the Flag's top corner, the Corner gem's), or nil for a look that sits in no
-- corner (the glows, frames, borders and the Ribbon are centred on the slot, the bar runs its whole
-- bottom edge) or a tier that draws nothing. The profession icon steps past it. Pure.
function Overlay.LookCorner(style, rampName, tier, corner, valuable, violet)
  for _, part in ipairs(Overlay.LookParts(style, rampName, tier, corner, valuable, violet)) do
    if part.anchor == "corner" and type(part.corner) == "string" then
      return part.corner
    end
  end
  return nil
end

-- The Bottom bar's size and place on a slot this wide: width, height and the x, y in from the
-- slot's bottom left corner, so it runs the whole bottom edge with the same inset at each end
-- (brief K8). Pure.
function Overlay.BarGeometry(slotWidth)
  local width = tonumber(slotWidth)
  if not width or width <= 0 then
    width = Theme.sizes.ITEMTREE_ICON_BAGSLOT
  end
  local unitScale = width / Theme.sizes.ITEMTREE_ICON_BAGSLOT
  local height = math.max(1, math.floor(sizeToken("ITEMTREE_KEEP_BAR_HEIGHT", 3) * unitScale + 0.5))
  local inset = math.max(1, math.floor(2 * unitScale + 0.5))
  local length = math.max(0, math.floor(width + 0.5) - 2 * inset)
  return length, height, inset, inset
end

-- The bar's two spans along a length: the solid tier colour from the left, then the fade to the
-- right edge. Answers the solid length and the fade length, which add up to the whole. Pure.
function Overlay.BarSplit(length)
  length = math.max(0, math.floor(tonumber(length) or 0))
  local solid = math.floor(length * sizeToken("ITEMTREE_KEEP_BAR_SPLIT", 2 / 3) + 0.5)
  if solid > length then
    solid = length
  end
  return solid, length - solid
end

--------------------------------------------------------------------------------
-- The valuable look (brief K9). An item an installed auction addon prices at the Keep value or
-- more wears the legendary orange treatment. Brief K13 addendum (owner: "the high value item gold
-- checker is overriding the selected style with its own style"): it wears the SELECTED Keep look,
-- drawn in the legendary orange (Overlay.LookParts with valuable, Overlay.ValueColour), and on top
-- of it two small flames on the slot's top edge, the client's legendary toast particles, each
-- drifting up a few pixels and fading on a slow loop, the second half a cycle behind the first.
-- No orange border or slot glow of its own any more, so nothing covers the look. The flames sit
-- on the top edge and reach only a little way down, so they never cover the icon's middle or the
-- stack count. A flame whose art the client will not draw is left out and the rest still draws.
--------------------------------------------------------------------------------

-- The flames a valuable item wears over its look, as parts in Overlay.LookParts's shape; each
-- also carries flame = its phase (0 or 0.5 of a cycle) and anchor "top". Pure.
function Overlay.ValueParts()
  local flameHeight = sizeToken("ITEMTREE_KEEP_FLAME_HEIGHT", 0.5)
  return {
    {
      part = "flame1",
      asset = "KEEP_VALUE_FLAME_1",
      layer = "OVERLAY",
      blend = "ADD",
      anchor = "top",
      scale = 1,
      height = flameHeight,
      flame = 0,
    },
    {
      part = "flame2",
      asset = "KEEP_VALUE_FLAME_2",
      layer = "OVERLAY",
      blend = "ADD",
      anchor = "top",
      scale = 1,
      height = flameHeight,
      flame = 0.5,
    },
  }
end

-- A flame's size and place on a slot this wide: width, height and the y offset of its bottom
-- edge from the slot's top edge (negative, so it reaches down over the icon's top). Pure.
function Overlay.FlameGeometry(slotWidth, heightShare)
  local width = Overlay.LookSide(slotWidth, 1)
  local height = math.max(1, Overlay.LookSide(slotWidth, heightShare or sizeToken("ITEMTREE_KEEP_FLAME_HEIGHT", 0.5)))
  local overlap = math.floor(height * sizeToken("ITEMTREE_KEEP_FLAME_OVERLAP", 0.35) + 0.5)
  return width, height, -overlap
end

--------------------------------------------------------------------------------
-- The demo (brief K7): /itemtree demo. Memory only, so a /reload ends it and the saved settings
-- never see it.
--------------------------------------------------------------------------------

local HASH_MOD = 2147483647

-- A number in 0 to 1 from a seed and a slot's key, the same every time for the same two. Pure.
function Overlay.DemoDraw(seed, key)
  local h = math.floor(tonumber(seed) or 1) % HASH_MOD
  local text = tostring(key)
  for index = 1, #text do
    h = (h * 31 + text:byte(index)) % HASH_MOD
  end
  h = h + 1
  for _ = 1, 3 do
    h = (h * 16807) % HASH_MOD
  end
  return h / HASH_MOD
end

-- The demo's tier for one slot: about a third of slots get none (0), the rest spread over the
-- ramp's tiers with the lower tiers commoner, weighted count, count - 1, down to 1 for the top,
-- which is the rarest. Pure, and stable for a seed.
function Overlay.DemoTier(seed, key, count)
  count = math.floor(tonumber(count) or 0)
  if count < 1 then
    return 0
  end
  local draw = Overlay.DemoDraw(seed, key)
  if draw < 1 / 3 then
    return 0
  end
  local share = (draw - 1 / 3) / (2 / 3)
  local total = count * (count + 1) / 2
  local reached = 0
  for tier = 1, count do
    reached = reached + (count + 1 - tier) / total
    if share < reached then
      return tier
    end
  end
  return count
end

-- The demo's state: nil while off, else { style = 1 to 12, ramp = name }. The seed is drawn once
-- a session and kept across an off and on, so the same slots light the same way.
Overlay.demo = nil
Overlay.demoSeed = nil
-- Brief K9: /itemtree demo value, while on the demo's top tier slots wear the valuable look too.
Overlay.demoValue = false

-- The style and ramp the bags draw with: the demo's while it is on, else the settings'. Brief
-- K15: builds the Single colour ramp from the settings first, the demo's included.
function Overlay.KeepLook(settings)
  settings = type(settings) == "table" and settings or {}
  Overlay.SyncSingle(settings)
  -- Brief K16: and the valuable colour the Single colour set draws a valuable item in.
  Overlay.SyncValue(settings)
  local demo = Overlay.demo
  if type(demo) == "table" then
    return demo.style, demo.ramp
  end
  return Overlay.StyleIndex(settings.keepStyle), Overlay.SettingsRamp(settings)
end

-- The one chat line the demo prints for its state.
function Overlay.DemoLine()
  local demo = Overlay.demo
  if type(demo) ~= "table" then
    return L["ItemTree demo: off"]
  end
  if demo.ramp == Overlay.RAMP_SINGLE then
    Overlay.SyncSingle((ItemTree.db and ItemTree.db.settings) or {})
  end
  local ramp = Overlay.Ramp(demo.ramp)
  local top = ramp[#ramp]
  local hue = top and Overlay.HUE_NAMES[top.hue]
  local line
  if hue and demo.ramp == Overlay.RAMP_SINGLE then
    -- Brief K15: one tier, so the line names the player's colour alone.
    line = string.format(
      L["ItemTree demo: style %d of %d, %s, ramp %s (%s)"],
      demo.style,
      #Overlay.KEEP_LOOKS,
      Overlay.StyleName(demo.style),
      Overlay.RAMP_NAMES[demo.ramp] or demo.ramp,
      hue
    )
  elseif hue then
    -- Brief K8: the top tier's colour, so the line reads without the tooltip.
    line = string.format(
      L["ItemTree demo: style %d of %d, %s, ramp %s (%d tiers, %s highest)"],
      demo.style,
      #Overlay.KEEP_LOOKS,
      Overlay.StyleName(demo.style),
      Overlay.RAMP_NAMES[demo.ramp] or demo.ramp,
      #ramp,
      hue
    )
  else
    line = string.format(
      L["ItemTree demo: style %d of %d, %s, ramp %s (%d tiers)"],
      demo.style,
      #Overlay.KEEP_LOOKS,
      Overlay.StyleName(demo.style),
      Overlay.RAMP_NAMES[demo.ramp] or demo.ramp,
      #ramp
    )
  end
  if Overlay.lookFallback[demo.style] then
    line = line .. " " .. L["(the client would not draw this look's art, so it shows as Glow)"]
  end
  if Overlay.demoValue then
    -- Brief K16: the Single colour set names the valuable colour too.
    local valueName = demo.ramp == Overlay.RAMP_SINGLE
      and Overlay.ValueColourName({
        keepRamp = Overlay.RAMP_SINGLE,
        keepValueColor = ((ItemTree.db and ItemTree.db.settings) or {}).keepValueColor,
        keepValueColorCustom = ((ItemTree.db and ItemTree.db.settings) or {}).keepValueColorCustom,
      })
    if valueName then
      line = line .. " " .. string.format(L["(top tier slots wear the valuable look, in %s)"], valueName)
    else
      line = line .. " " .. L["(top tier slots wear the valuable look)"]
    end
  end
  return line
end

-- Starts the demo if it is off, with the look the settings name (or look 1 for the shipped one)
-- and their ramp. seed is for the specs; the client draws one.
function Overlay.DemoStart(seed)
  if Overlay.demoSeed == nil or seed ~= nil then
    local draw = seed
    if draw == nil then
      local random = math.random
      local ok, value = pcall(random, 1, HASH_MOD - 1)
      draw = ok and value or 1
    end
    Overlay.demoSeed = draw
  end
  if type(Overlay.demo) ~= "table" then
    local settings = (ItemTree.db and ItemTree.db.settings) or {}
    local style = Overlay.StyleIndex(settings.keepStyle)
    if style == Overlay.KEEP_STYLE_SHIPPED then
      style = 1
    end
    Overlay.demo = { style = style, ramp = Overlay.SettingsRamp(settings) }
  end
  return Overlay.demo
end

-- /itemtree demo and its sub commands: style <1..12>, ramp <gold|quality|heat|single>, value, next,
-- off, and nothing for the state. Redraws the bags on every change and answers the line to print.
-- Brief K15: ramp single draws in the player's own keepColor.
function Overlay.DemoCommand(rest)
  local what, arg = "", ""
  if type(rest) == "string" then
    what, arg = rest:match("^%s*(%S*)%s*(.-)%s*$")
    what = (what or ""):lower()
  end
  if what == "" then
    return Overlay.DemoLine()
  end
  if what == "off" then
    Overlay.demo = nil
    Overlay.demoValue = false
    Overlay.Refresh()
    return Overlay.DemoLine()
  end
  if what == "style" then
    local index = tonumber(arg)
    if index == nil or index ~= math.floor(index) or index < 1 or index > #Overlay.KEEP_LOOKS then
      return L["Usage: /itemtree demo style <1 to 12>, ramp <gold, quality, heat or single>, value, next or off"]
    end
    Overlay.DemoStart().style = index
  elseif what == "value" then
    -- Brief K9: a toggle, which starts the demo where it is off.
    if type(Overlay.demo) == "table" then
      Overlay.demoValue = not Overlay.demoValue
    else
      Overlay.DemoStart()
      Overlay.demoValue = true
    end
  elseif what == "next" then
    local demo = type(Overlay.demo) == "table" and Overlay.demo or nil
    if demo then
      demo.style = demo.style % #Overlay.KEEP_LOOKS + 1
    else
      Overlay.DemoStart()
    end
  elseif what == "ramp" then
    local name = type(arg) == "string" and arg:lower() or ""
    if Overlay.RampName(name) ~= name then
      return L["Usage: /itemtree demo style <1 to 12>, ramp <gold, quality, heat or single>, value, next or off"]
    end
    Overlay.DemoStart().ramp = name
  else
    return L["Usage: /itemtree demo style <1 to 12>, ramp <gold, quality, heat or single>, value, next or off"]
  end
  Overlay.Refresh()
  return Overlay.DemoLine()
end

-- The tier a slot's item draws in on the ramp given, or 0 for none. While the demo is on it is the
-- demo's draw for the slot (key), whatever the item's uses; otherwise the Keep score's tier, and 0
-- with Keep marks off. Nothing here asks the client about the item.
--
-- Brief TBR2: and, third, the colour the flag wears (Overlay.FlagColour), nil for tier 0.
--
-- Brief K9: Overlay.KeepStateFor answers the tier and whether the slot wears the valuable look:
-- the score's valuable flag on a marked item, or, while the demo is on with its value toggle,
-- the demo's top tier slots.
--
-- Brief K12: the player's own word on an item (Keep.Override) wins over the demo too. Never and Off
-- draw nothing and Always draws the top tier, so pressing the item page's Worth keeping control
-- moves the slot at once whether or not the demo is running. The demo is memory only, so before
-- this a slot it marked kept its look until a /reload ended the demo.
-- Brief K24b: one env table for the tags and Keep.BagValuable, filled per slot, so a bag pass makes
-- none per slot.
local overlayEnv = {}

-- Brief K28: the link a slot's score is asked with for its random suffix roll: the caller's own (a
-- bag addon's record, Baganator's details.itemLink), else the live bag slot's, which Keep.SlotLink
-- asks of the client only for an item whose row may roll one. It goes to Keep.CachedScore as its
-- rollLink, whose one Keep.RollKey decides whether it names a roll (the brief K28 addendum: no
-- second and third RollKey here), and which hands it on only then, so every other item is scored
-- and priced exactly as before. nil for anything else.
local function slotLink(keep, itemId, bag, slot, link)
  if link ~= nil then
    -- A bag addon's record is asked through Util.CanRead before any compare (bible B10).
    local util = ItemTree.Util
    if type(util) == "table" and type(util.CanRead) == "function" and not util.CanRead(link) then
      return nil
    end
  elseif bag ~= nil and slot ~= nil and type(keep.SlotLink) == "function" then
    local ok, read = pcall(keep.SlotLink, itemId, bag, slot)
    link = ok and read or nil
  end
  if type(link) ~= "string" then
    return nil
  end
  return link
end

-- Brief BQ29 (QA items 79a and 87): whether a tags answer (Keep.Tags) draws [Use] or [Open] as its
-- first tag, the one the bag mark follows. Pure.
function Overlay.UseTagFirst(answer)
  local tags = type(answer) == "table" and answer.tags or nil
  local first = type(tags) == "table" and tags[1] or nil
  return first == "use" or first == "open"
end

function Overlay.KeepStateFor(itemId, settings, key, rampName, bag, slot, link)
  if not itemId then
    return 0, false
  end
  local ramp = Overlay.Ramp(rampName)
  if type(Overlay.demo) == "table" then
    local keep = ItemTree.Keep
    local word
    if type(keep) == "table" and type(keep.Override) == "function" then
      local ok, answer = pcall(keep.Override, itemId)
      word = ok and answer or nil
    end
    if word == "never" or word == "off" then
      return 0, false
    end
    local tier = Overlay.DemoTier(Overlay.demoSeed, key or itemId, #ramp)
    if word == "always" then
      tier = #ramp
    end
    local valuable = Overlay.demoValue == true and tier > 0 and tier == #ramp
    return tier, valuable, Overlay.FlagColour(rampName, tier, valuable)
  end
  if not settingOn(settings, "keepMarks") then
    return 0, false
  end
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.CachedScore) ~= "function" then
    return 0, false
  end
  local level, faction = Overlay.PlayerFacts()
  -- Brief K28: the slot's link as the rollLink, so a random suffix roll is weighed and held apart.
  local ok, score =
    pcall(keep.CachedScore, itemId, level, faction, nil, nil, nil, nil, slotLink(keep, itemId, bag, slot, link))
  if not ok or score == nil then
    return 0, false
  end
  -- Brief K24b (owner ruling 2026-10-05: "We have KEEP AND VALUE but we probably need DISENCHANT",
  -- "flag in violet"): three marks, all the player's one chosen Keep look:
  --   KEEP       the Keep colour where the Keep tag is there (the soft keep included)
  --   VALUE      the Valuable colour, with the look's valuable art and the flames, where a KNOWN
  --              price reaches "Valuable at" (Keep.BagValuable), keep or not, at the top tier, as
  --              0.1.7 drew a valuable item (valuable wins the colour over a keep)
  --   DISENCHANT the Disenchant violet where the Disenchant tag is there (Enchanting only) and
  --              neither mark above applies
  -- Nothing for Auction or Vendor on their own. The player's own Never and Off draw nothing. bag
  -- and slot name the live bag slot, whose real bound state rules a soulbound item out of the
  -- valuable look and the auction house out of the tags (Keep.BoundFor). The fifth answer is
  -- violet: true for the Disenchant mark.
  if score.override == "never" or score.override == "off" then
    return 0, false
  end
  local bound = nil
  if bag ~= nil and slot ~= nil and type(keep.BoundFor) == "function" then
    -- (an explicit if: "read and value or nil" turned a read false into nil)
    local read, value = pcall(keep.BoundFor, itemId, bag, slot)
    if read then
      bound = value
    end
  end
  overlayEnv.money = type(keep.Money) == "function" and keep.Money() or nil
  overlayEnv.bound = bound
  -- Brief BQ9: the player's buffs, so a scroll whose buff is on leaves the Use mark (Keep.DoNow).
  overlayEnv.auras = type(keep.CurrentAuras) == "function" and keep.CurrentAuras() or nil
  -- Brief K31: which copy of a profession tool is kept, so a spare copy leaves the Keep mark.
  overlayEnv.tool = nil
  if type(score.tool) == "table" and score.tool.own and type(keep.ToolFor) == "function" then
    local read, tool = pcall(keep.ToolFor, itemId, bag, slot)
    if read and type(tool) == "table" then
      overlayEnv.tool = tool
    end
  end
  local answer = nil
  if type(keep.Tags) == "function" then
    local tagged, tags = pcall(keep.Tags, score, settings, overlayEnv)
    answer = tagged and tags or nil
  end
  local hasTag = type(keep.HasTag) == "function" and keep.HasTag or function()
    return false
  end
  local keeps = hasTag(answer, "keep") or (answer == nil and score.override == "always")
  local valuable = false
  if type(keep.BagValuable) == "function" then
    local read, value = pcall(keep.BagValuable, score, settings, overlayEnv)
    valuable = read and value == true
  end
  local violet = not keeps and not valuable and hasTag(answer, "disenchant")
  -- Brief BQ9: an [Open] or [Use] item draws the Use mark alone, in the Use blue (violet "use").
  -- Brief BQ29 (QA items 79a and 87): the mark follows the tag the tooltip draws first: [Use] or
  -- [Open] is the Use look, a potion or bandage's [Use] keep (answer.useKeep) included; [Keep] (a
  -- lasting buff with its buff on, a buff food while well fed) is the Keep look.
  -- Brief ST1 (QA item 279): the Use mark can be turned off (keepUseMark). Brief ST3 (QA item 319,
  -- the owner's ruling A: "Off: these items wear the Keep mark instead"): off, every item that would
  -- wear it wears its Keep look in its place, an item only to use or open now included (under ST1
  -- such an item, kept by nothing else, wore nothing).
  if not valuable and Overlay.UseTagFirst(answer) then
    if Overlay.UseMarkOn(settings) then
      return 1, false, Overlay.UseColour(), nil, Overlay.USE_MARK
    end
    keeps, violet = true, false
  end
  local tier = 0
  if keeps then
    if type(keep.Tier) == "function" then
      local counted, value = pcall(keep.Tier, score, ramp)
      if counted and tonumber(value) then
        tier = tonumber(value)
      end
    end
    -- Brief K24b: the provisional soft keep (Keep.CouldUse) is a Keep tag the mark rule does not
    -- count, so it takes the first tier.
    if tier < 1 then
      tier = 1
    end
  end
  if valuable then
    -- Brief K9 (0.1.7): a valuable item takes the top tier.
    tier = math.max(#ramp, 1)
  elseif violet then
    tier = 1
  end
  if tier == 0 then
    return 0, false
  end
  -- Brief TBR2: the flag's colour as a third answer (Overlay.FlagColour).
  return tier, valuable, Overlay.FlagColour(rampName, tier, valuable, violet), nil, violet
end

function Overlay.KeepTierFor(itemId, settings, key, rampName)
  return (Overlay.KeepStateFor(itemId, settings, key, rampName))
end

-- Brief K8: the tier and ramp each slot button was last drawn with, so the item tooltip can say
-- what the demo marked it with. Weak keyed, by the button, like the overlays.
local slotTiers = setmetatable({}, { __mode = "k" })
local slotRamps = setmetatable({}, { __mode = "k" })

local function noteTier(button, tier, rampName)
  if button ~= nil then
    slotTiers[button] = tier
    slotRamps[button] = rampName
  end
end

-- The demo's tooltip line for a tier on a ramp: "ItemTree demo: tier 3 of 3, Heat", or nil for
-- a bare slot. Pure.
function Overlay.DemoTipText(tier, rampName)
  tier = math.floor(tonumber(tier) or 0)
  local name = Overlay.RampName(rampName)
  local count = #Overlay.Ramp(name)
  if tier < 1 or count == 0 then
    return nil
  end
  if tier > count then
    tier = count
  end
  return string.format(L["ItemTree demo: tier %d of %d, %s"], tier, count, Overlay.RAMP_NAMES[name] or name)
end

-- The demo's tooltip line for the slot button a tooltip is anchored to, or nil: the demo is off,
-- the owner is no slot the bags drew, or the demo left it bare.
function Overlay.DemoTipFor(owner)
  if type(Overlay.demo) ~= "table" or owner == nil then
    return nil
  end
  local tier = slotTiers[owner]
  if tier == nil then
    return nil
  end
  return Overlay.DemoTipText(tier, slotRamps[owner])
end

-- Every Keep part a frame has made, the glow and the frame included.
local function keepTextures(frame)
  local list = {}
  if type(frame.glow) == "table" then
    list.glow = frame.glow
  end
  if type(frame.ring) == "table" then
    list.ring = frame.ring
  end
  for part, texture in pairs(type(frame.keepParts) == "table" and frame.keepParts or {}) do
    list[part] = texture
  end
  return list
end

local function stopPulse(texture)
  if type(texture) == "table" and texture.itPulse then
    method(texture.itPulse, "Stop")
    method(texture, "SetAlpha", 1)
  end
  -- Brief K12: so does the dashed frame's march. Brief OPT6: and the slot no longer carries the
  -- dashed look, so showing its overlay again does not start it.
  if type(texture) == "table" and texture.itMarch then
    method(texture.itMarch, "Stop")
  end
  if type(texture) == "table" then
    texture.itMarchWanted = nil
  end
  -- Brief K9: a flame's loop stops with it.
  if type(texture) == "table" and texture.itFlame then
    method(texture.itFlame, "Stop")
    texture.itFlameWaiting = nil
    method(texture, "SetAlpha", 1)
  end
end

-- Hides every Keep part on a frame.
function Overlay.HideKeep(frame)
  if type(frame) ~= "table" then
    return
  end
  for _, texture in pairs(keepTextures(frame)) do
    stopPulse(texture)
    Overlay.ReleaseMarch(texture)
    method(texture, "Hide")
  end
end

-- The texture for one part, made on the frame the first time and given its art; the glow and the
-- frame are the ones MakeGlow and MakeRing made. Answers the texture and whether its art drew.
local function partTexture(frame, part)
  local texture
  if part.part == "glow" then
    texture = frame.glow
  elseif part.part == "ring" then
    texture = frame.ring
  else
    frame.keepParts = frame.keepParts or {}
    texture = frame.keepParts[part.part]
    if texture == nil and type(frame.CreateTexture) == "function" then
      local ok, made = pcall(frame.CreateTexture, frame, nil, part.layer or "ARTWORK", nil, part.sublevel or 0)
      if ok and type(made) == "table" then
        texture = made
        frame.keepParts[part.part] = made
      end
    end
  end
  if type(texture) ~= "table" then
    return nil, false
  end
  if texture.itAsset ~= part.asset then
    local assets = ItemTree.Assets
    local drew = false
    if type(assets) == "table" and type(assets.Apply) == "function" then
      local ok, answer = pcall(assets.Apply, texture, part.asset)
      drew = ok and answer == true
    end
    texture.itAsset = part.asset
    texture.itDrew = drew
  end
  return texture, texture.itDrew ~= false
end

-- The pulse on one texture: an alpha animation of ItemTree's own, bouncing from full to
-- ITEMTREE_KEEP_PULSE_LOW and back once every ITEMTREE_KEEP_PULSE_SECONDS.
local function startPulse(texture)
  local group = texture.itPulse
  if group == nil then
    group = method(texture, "CreateAnimationGroup")
    if type(group) ~= "table" then
      return false
    end
    local alpha = method(group, "CreateAnimation", "Alpha")
    if type(alpha) == "table" then
      method(alpha, "SetFromAlpha", 1)
      method(alpha, "SetToAlpha", sizeToken("ITEMTREE_KEEP_PULSE_LOW", 0.35))
      method(alpha, "SetDuration", sizeToken("ITEMTREE_KEEP_PULSE_SECONDS", 2) / 2)
      method(alpha, "SetSmoothing", "IN_OUT")
    end
    method(group, "SetLooping", "BOUNCE")
    texture.itPulse = group
  end
  if not method(group, "IsPlaying") then
    method(group, "Play")
  end
  return true
end

-- Brief K9: a flame's loop on one texture, an animation group of ItemTree's own: a drift up of
-- ITEMTREE_KEEP_FLAME_RISE pixels and a fade from full to nothing over
-- ITEMTREE_KEEP_FLAME_SECONDS, repeating. phase is the share of a cycle the loop starts behind,
-- so two flames never peak together; the late one starts on a timer of its own.
local function startFlame(texture, phase)
  local group = texture.itFlame
  local seconds = sizeToken("ITEMTREE_KEEP_FLAME_SECONDS", 2)
  if group == nil then
    group = method(texture, "CreateAnimationGroup")
    if type(group) ~= "table" then
      return false
    end
    local drift = method(group, "CreateAnimation", "Translation")
    if type(drift) == "table" then
      method(drift, "SetOffset", 0, sizeToken("ITEMTREE_KEEP_FLAME_RISE", 4))
      method(drift, "SetDuration", seconds)
      method(drift, "SetSmoothing", "OUT")
    end
    local fade = method(group, "CreateAnimation", "Alpha")
    if type(fade) == "table" then
      method(fade, "SetFromAlpha", 1)
      method(fade, "SetToAlpha", 0)
      method(fade, "SetDuration", seconds)
      method(fade, "SetSmoothing", "IN")
    end
    method(group, "SetLooping", "REPEAT")
    texture.itFlame = group
  end
  if method(group, "IsPlaying") or texture.itFlameWaiting then
    return true
  end
  local delay = (tonumber(phase) or 0) * seconds
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if delay > 0 and type(after) == "function" then
    texture.itFlameWaiting = true
    local ok = pcall(after, delay, function()
      if texture.itFlameWaiting then
        texture.itFlameWaiting = nil
        method(group, "Play")
      end
    end)
    if ok then
      return true
    end
    texture.itFlameWaiting = nil
  end
  method(group, "Play")
  return true
end

-- Brief K12: the four quarter turns of a texture, as SetTexCoord's eight numbers (upper left, lower
-- left, upper right, lower right). Each turn is a quarter turn clockwise from the one before.
Overlay.MARCH_COORDS = {
  { 0, 0, 0, 1, 1, 0, 1, 1 },
  { 0, 1, 1, 1, 0, 0, 1, 0 },
  { 1, 1, 1, 0, 0, 1, 0, 0 },
  { 1, 0, 0, 0, 1, 1, 0, 1 },
}

-- The next of the four quarter turns after this one, 1 to 4, round again after 4. Pure.
function Overlay.MarchStep(phase)
  phase = math.floor(tonumber(phase) or 0)
  return phase % #Overlay.MARCH_COORDS + 1
end

local function setMarchPhase(texture, phase)
  texture.itMarchPhase = phase
  method(texture, "SetTexCoord", unpack(Overlay.MARCH_COORDS[phase]))
end

-- Brief OPT6 (audit F15): every OnLoop step of every march since the file loaded, one addition a
-- tick, for /itemtree probe march. Read through Overlay.MarchTicks.
local marchTicks = 0

function Overlay.MarchTicks()
  return marchTicks
end

-- Brief K12: the Dashed border's march. The client cannot scroll a texture's coordinates
-- cheaply, but the art (Art/keep-dash.tga, scripts/build-art.py) holds an odd count of dash
-- periods round the frame, one more than a multiple of four, so a quarter turn of the texture
-- moves every dash a quarter of a period along the frame. An animation group of ItemTree's own
-- loops once a quarter of the cycle (a held alpha, so nothing fades), and each loop turns the
-- texture one quarter further through SetTexCoord: the dashes step round the slot like marching
-- ants, one period every `seconds`. A client whose group will not take the loop script keeps the
-- dashes still.
--
-- Brief OPT6 (audit F15): the texture remembers it wants to march (itMarchWanted, cleared by
-- stopPulse) and at what pace, so its overlay's OnShow can start it again. owner is the frame the
-- look is drawn on; one that stops its marches on hide (watchMarch) and is not visible right now
-- is left still, and its OnShow starts the march when the slot is seen.
local function startMarch(texture, seconds, owner)
  seconds = tonumber(seconds) or 0.6
  texture.itMarchWanted = true
  texture.itMarchSeconds = seconds
  local step = seconds / #Overlay.MARCH_COORDS
  local group = texture.itMarch
  if group == nil and texture.itMarchIdle ~= nil then
    -- Brief OPT8: the group this texture marched with before it was released, taken back.
    group = texture.itMarchIdle
    texture.itMarchIdle = nil
    method(group, "SetScript", "OnLoop", texture.itMarchLoop)
    texture.itMarch = group
  end
  if group == nil then
    group = method(texture, "CreateAnimationGroup")
    if type(group) ~= "table" then
      return false
    end
    local hold = method(group, "CreateAnimation", "Alpha")
    if type(hold) == "table" then
      method(hold, "SetFromAlpha", 1)
      method(hold, "SetToAlpha", 1)
    end
    texture.itMarchHold = hold
    method(group, "SetLooping", "REPEAT")
    texture.itMarchLoop = function()
      marchTicks = marchTicks + 1
      setMarchPhase(texture, Overlay.MarchStep(texture.itMarchPhase))
    end
    method(group, "SetScript", "OnLoop", texture.itMarchLoop)
    texture.itMarch = group
  end
  if texture.itMarchPhase == nil then
    setMarchPhase(texture, 1)
  end
  if texture.itMarchStep ~= step then
    texture.itMarchStep = step
    if type(texture.itMarchHold) == "table" then
      method(texture.itMarchHold, "SetDuration", step)
    end
  end
  if type(owner) == "table" and owner.itMarchWatched and method(owner, "IsVisible") == false then
    method(group, "Stop")
    return true
  end
  if not method(group, "IsPlaying") then
    method(group, "Play")
  end
  return true
end

-- Brief OPT8: a texture whose slot shows no Keep look at all is released: its march group is
-- stopped, its loop script cleared and the live reference (itMarch) dropped, so the group is no
-- longer counted, ticked or started on show. The owner's probe (2026-10-04) found the bags' pooled
-- item buttons change slots on every reopen (Blizzard_UIPanels_Game Mainline ContainerFrame.lua,
-- UpdateItemSlots releases the whole pool and acquires it again, branch forever), so a dashed item
-- lands on a button that never marched and gets a group of its own, while the button it left holds
-- a still group for nothing: "dashed 10, groups 15" after one reopen. The client cannot destroy an
-- animation group, so the released one is parked on its own texture (itMarchIdle) and taken back by
-- startMarch the next time that texture marches: one group per texture for its life, never a
-- second. A look change on a slot still marked keeps the group (Overlay.ShowKeep), so switching
-- looks back and forth makes nothing either.
function Overlay.ReleaseMarch(texture)
  if type(texture) ~= "table" or texture.itMarch == nil then
    return false
  end
  local group = texture.itMarch
  method(group, "Stop")
  method(group, "SetScript", "OnLoop", nil)
  texture.itMarch = nil
  texture.itMarchWanted = nil
  texture.itMarchIdle = group
  return true
end

-- Brief OPT6 (audit F15): a slot's overlay stops every march on it when it is hidden, itself or
-- through the bag it sits in (the client sends OnHide to a shown frame whose ancestor hides), and
-- starts again on show only the textures that still carry the dashed look and still show. Stop,
-- not Pause: the phase lives on the texture (itMarchPhase and its coordinates), so it survives.
local function marchesOnHide(frame)
  for _, texture in pairs(type(frame.keepParts) == "table" and frame.keepParts or {}) do
    if type(texture) == "table" and texture.itMarch then
      method(texture.itMarch, "Stop")
    end
  end
end

local function marchesOnShow(frame)
  for _, texture in pairs(type(frame.keepParts) == "table" and frame.keepParts or {}) do
    if type(texture) == "table" and texture.itMarchWanted and isShown(texture) then
      startMarch(texture, texture.itMarchSeconds, frame)
    end
  end
end

-- Puts the two scripts on one of OUR overlay frames, called once as it is built, before it is
-- moved under the slot. Nothing else sets OnShow or OnHide on an overlay, so there is nothing to
-- chain (and reading a handler back is a shape the taint lint refuses). Never called on a client
-- frame.
local function watchMarch(frame)
  if type(frame) ~= "table" or frame.itMarchWatched then
    return
  end
  method(frame, "SetScript", "OnHide", marchesOnHide)
  method(frame, "SetScript", "OnShow", marchesOnShow)
  frame.itMarchWatched = true
end
Overlay.WatchMarch = watchMarch

-- Brief OPT6: what /itemtree probe march reads. Every overlay ItemTree made (the bags' and
-- Baganator's corners): the textures carrying the dashed look, the march groups that exist, the
-- ones playing, and the tick count. Answers { dashed, groups, playing, ticks }.
function Overlay.MarchStats(frames)
  local stats = { dashed = 0, groups = 0, playing = 0, ticks = marchTicks }
  local seen = {}
  local function count(frame)
    if type(frame) ~= "table" or seen[frame] then
      return
    end
    seen[frame] = true
    for _, texture in pairs(type(frame.keepParts) == "table" and frame.keepParts or {}) do
      if type(texture) == "table" then
        if texture.itMarchWanted and isShown(texture) then
          stats.dashed = stats.dashed + 1
        end
        if texture.itMarch then
          stats.groups = stats.groups + 1
          if method(texture.itMarch, "IsPlaying") then
            stats.playing = stats.playing + 1
          end
        end
      end
    end
  end
  for _, frame in pairs(frames or {}) do
    count(frame)
  end
  return stats
end

-- Brief K8: a horizontal gradient on a texture, from one { r, g, b, a } to another. The modern
-- client takes two colour objects, the classic one SetGradientAlpha's eight numbers; a client
-- with neither gets a plain fill in the darker colour. Answers which way it drew.
local function applyGradient(texture, from, to)
  local createColor = rawget(_G, "CreateColor")
  if type(texture.SetGradient) == "function" and type(createColor) == "function" then
    local made, a, b = pcall(function()
      return createColor(from[1], from[2], from[3], from[4]), createColor(to[1], to[2], to[3], to[4])
    end)
    if made and a ~= nil and b ~= nil and pcall(texture.SetGradient, texture, "HORIZONTAL", a, b) then
      return "gradient"
    end
  end
  if type(texture.SetGradientAlpha) == "function" then
    local ok = pcall(
      texture.SetGradientAlpha,
      texture,
      "HORIZONTAL",
      from[1],
      from[2],
      from[3],
      from[4],
      to[1],
      to[2],
      to[3],
      to[4]
    )
    if ok then
      return "gradientalpha"
    end
  end
  method(texture, "SetVertexColor", to[1], to[2], to[3], to[4])
  return "fill"
end

-- Places, tints and shows one prepared part over the slot. Brief ST2: markScale is the Mark size
-- setting, read by a corner part it sizes (part.markSized: the Flag, the Corner gem, the Use mark).
-- Such a part is anchored by its own corner to the slot's, inset as before, so a change of size
-- grows or shrinks it towards that corner and never moves it off it.
local function drawPart(frame, texture, part, slotWidth, markScale)
  local slot = frame.keepSlot or frame
  method(texture, "SetBlendMode", part.blend or "BLEND")
  if part.desaturate or texture.itDesaturated then
    method(texture, "SetDesaturated", part.desaturate and true or false)
    texture.itDesaturated = part.desaturate and true or nil
  end
  if part.tint then
    method(texture, "SetVertexColor", part.tint[1], part.tint[2], part.tint[3], part.tint[4])
    texture.itTinted = true
  elseif texture.itTinted then
    method(texture, "SetVertexColor", 1, 1, 1, 1)
    texture.itTinted = nil
  end
  method(texture, "ClearAllPoints")
  if part.anchor == "bottom" then
    local width, height, x, y = Overlay.BarGeometry(slotWidth)
    if part.span then
      local solid, fade = Overlay.BarSplit(width)
      if part.span == "fade" then
        x, width = x + solid, fade
      else
        width = solid
      end
    end
    method(texture, "SetSize", width, height)
    method(texture, "SetPoint", "BOTTOMLEFT", slot, "BOTTOMLEFT", x, y)
  elseif part.anchor == "top" then
    -- Brief K9: a flame on the slot's top edge, reaching a little way down over the icon.
    local width, height, y = Overlay.FlameGeometry(slotWidth, part.height)
    method(texture, "SetSize", width, height)
    method(texture, "SetPoint", "BOTTOM", slot, "TOP", 0, y)
  elseif part.anchor == "corner" then
    local side
    if part.markSized then
      side = Overlay.MarkSide(slotWidth, part.scale, markScale)
    else
      side = Overlay.LookSide(slotWidth, part.scale)
    end
    local signs = CORNER_SIGNS[part.corner] or CORNER_SIGNS.BOTTOMLEFT
    local inset = Overlay.CornerInset(slotWidth, part.inset)
    method(texture, "SetSize", side, side)
    method(texture, "SetPoint", part.corner, slot, part.corner, signs.x * inset, signs.y * inset)
  else
    local side = Overlay.LookSide(slotWidth, part.scale)
    method(texture, "SetSize", side, side)
    method(texture, "SetPoint", "CENTER", slot, "CENTER", 0, 0)
  end
  if part.gradient then
    texture.itGradient = applyGradient(texture, part.gradient.from, part.gradient.to)
  end
  if part.flame then
    startFlame(texture, part.flame)
  elseif part.march then
    startMarch(texture, part.march, frame)
  elseif part.pulse then
    startPulse(texture)
  else
    stopPulse(texture)
  end
  method(texture, "Show")
end

-- Draws a slot's Keep mark in one look and tier, and hides every other part the frame has made.
-- A tier of 0 hides the lot. A look any of whose art the client will not draw is drawn as look 1
-- instead, and the refusal remembered. Brief K9: valuable adds the flames over the look
-- (Overlay.ValueParts), any one of which the client will not draw is simply left out. Brief K13
-- addendum: and draws the look itself in the legendary orange (Overlay.LookParts with valuable).
-- Brief K24b: violet draws the look in the Disenchant violet (no flames). Answers whether anything
-- shows. Brief ST2: markScale is the Mark size setting the corner marks follow (nil, the default
-- size); under ST1 this was the Bag badge size, which the Use mark alone followed.
function Overlay.ShowKeep(frame, tier, style, rampName, slotWidth, corner, valuable, violet, markScale)
  if type(frame) ~= "table" then
    return false
  end
  local parts = Overlay.LookParts(style, rampName, tier, corner, valuable, violet)
  local wanted, textures = {}, {}
  for index, part in ipairs(parts) do
    local texture, drew = partTexture(frame, part)
    if texture == nil or not drew then
      Overlay.lookFallback[Overlay.StyleIndex(style)] = part.asset
      if Overlay.StyleIndex(style) ~= 1 then
        return Overlay.ShowKeep(frame, tier, 1, rampName, slotWidth, corner, valuable, violet, markScale)
      end
      parts, textures = {}, {}
      break
    end
    textures[index] = texture
    wanted[texture] = true
  end
  if valuable and #parts > 0 then
    for _, part in ipairs(Overlay.ValueParts()) do
      local texture, drew = partTexture(frame, part)
      if texture ~= nil and drew then
        parts[#parts + 1] = part
        textures[#parts] = texture
        wanted[texture] = true
      end
    end
  end
  for _, texture in pairs(keepTextures(frame)) do
    if not wanted[texture] then
      stopPulse(texture)
      -- Brief OPT8: a slot left with no look at all (Baganator's corner on an unmarked item, a
      -- tier of 0) releases its march; a slot that only changed look keeps it.
      if #parts == 0 then
        Overlay.ReleaseMarch(texture)
      end
      method(texture, "Hide")
    end
  end
  for index, part in ipairs(parts) do
    drawPart(frame, textures[index], part, slotWidth, markScale)
  end
  return #parts > 0
end

-- Brief TX2: the frame levels of one overlay and everything on it, set outright from the level
-- the overlay takes: the cluster one above it and each badge one above the cluster, which is
-- where a frame made with its parent lands. The overlay is built with no parent and moved under
-- the button afterwards, so its children are never made against the button's level.
local function relevel(frame, level)
  method(frame, "SetFrameLevel", level)
  local cluster = frame.cluster
  if type(cluster) ~= "table" then
    return
  end
  method(cluster, "SetFrameLevel", level + 1)
  for _, badge in ipairs(type(cluster.badges) == "table" and cluster.badges or {}) do
    method(badge, "SetFrameLevel", level + 2)
  end
end

-- Brief TX2: moves a finished overlay under the client frame it marks. Everything on the overlay
-- is made before this runs and nothing is made on it after: on Forever the gamepad
-- SmartNavigation post hooks CreateFrame and, for a frame whose parent chain reaches an open
-- panel (the combined bags, the merchant), rebuilds that panel's navigation state as the caller
-- (Blizzard_GamepadSmartNavigation/SmartNavigation.lua SetupFrameHooks, UpdateParent,
-- RefreshButtonGroups, branch forever). That state tainted by ItemTree had the protected
-- SetPreferredGamepadInteractTarget refused on every soft target change. SetParent is not
-- hooked. The overlay takes the button's strata where the move did not hand it on, and sits
-- offset levels above the button. Answers true when the move took.
function Overlay.Attach(frame, button, offset)
  if type(frame) ~= "table" or type(button) ~= "table" then
    return false
  end
  -- Brief TX6: never moved in combat. The draws that reach here ask first; this is the backstop.
  if inCombat() then
    return false
  end
  if type(frame.SetParent) ~= "function" or not pcall(frame.SetParent, frame, button) then
    return false
  end
  -- Brief UI1: from 1.60.1.70425 GetFrameStrata can answer a secret (the new FrameStrata aspect,
  -- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:435-437, branch forever), and a
  -- secret raises on the compare. An unreadable strata is left alone: the overlay keeps the one
  -- SetParent handed it.
  local strata = method(button, "GetFrameStrata")
  if type(strata) == "string" and canRead(strata) and method(frame, "GetFrameStrata") ~= strata then
    method(frame, "SetFrameStrata", strata)
  end
  local level = tonumber(method(button, "GetFrameLevel"))
  if level then
    relevel(frame, level + (tonumber(offset) or Overlay.LEVEL_OFFSET))
  end
  return true
end

-- One overlay frame on a button, with its badge cluster placed in the corner the settings name.
-- Mouse off on every path the two clients offer, so every click, drag and tooltip reaches the
-- button underneath. Built whole with no parent (the cluster filled to its most badges, the Keep
-- glow and ring made), then moved under the button by Overlay.Attach; see there for why.
-- Returns nil outside the client.
--
-- Brief BG3: split in two, the build (buildOverlay) and the move under the button (attachOverlay),
-- so the Forever bank panel's overlays can be built at login and moved under a slot only when one
-- has a mark to wear (see "The bank panel's stock" below). A bag slot still does both at once.
--
-- buildOverlay: the frame, hidden, with no parent, its cluster filled and its Keep glow and ring
-- made. width is the slot's, for the first badge size (every draw sizes the badges again through
-- Overlay.Place); centreOn is the slot the glow and ring centre on, nil for the overlay itself,
-- which attachOverlay's SetAllPoints puts on its button's centre.
local function buildOverlay(settings, width, centreOn)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" then
    return nil
  end
  method(frame, "EnableMouse", false)
  method(frame, "SetMouseClickEnabled", false)
  method(frame, "SetMouseMotionEnabled", false)
  method(frame, "Hide")
  local size = Overlay.BadgeSize(width, settings.bagBadgeScale)
  local cluster = Badges.CreateCluster(frame, size, Overlay.MAX_BADGES, "column", Overlay.GAP)
  if not cluster then
    return nil
  end
  method(cluster, "EnableMouse", false)
  method(cluster, "Fill")
  frame.cluster = cluster
  frame.glow = Overlay.MakeGlow(frame, centreOn)
  frame.ring = Overlay.MakeRing(frame, centreOn)
  watchMarch(frame)
  return frame
end

-- attachOverlay: the built frame moved under the button by Overlay.Attach, laid over it, its cluster
-- placed in the corner the settings name, and kept in the overlays table. nil where the move did not
-- take.
local function attachOverlay(frame, button, settings)
  -- Brief K7: every Keep look is centred on (or placed against) the button it marks.
  frame.keepSlot = button
  if not Overlay.Attach(frame, button) then
    frame.keepSlot = nil
    return nil
  end
  method(frame, "SetAllPoints", button)
  local size = Overlay.BadgeSize(tonumber(method(button, "GetWidth")), settings.bagBadgeScale)
  Overlay.Place(frame.cluster, frame, size, settings.bagBadgeCorner)
  overlays[button] = frame
  return frame
end

local function createOverlay(button, settings)
  local frame = buildOverlay(settings, tonumber(method(button, "GetWidth")), button)
  if not frame then
    return nil
  end
  return attachOverlay(frame, button, settings)
end

--------------------------------------------------------------------------------
-- The bank panel's stock (brief BG3)
--
-- The owner's rule for the Forever bank: with the gamepad UI on, a frame made while a client panel
-- is open can leave that panel's gamepad state ItemTree's, and its close is then refused
-- (ADDON_ACTION_FORBIDDEN SetPreferredGamepadInteractTarget, briefs TX1 and TX2), so no frame is
-- made on the bank's open at all. The overlays the bank panel's pooled buttons wear are made at
-- login instead (Overlay.Install, at PLAYER_LOGIN, behind the loading screen), whole, hidden and
-- with no parent, and a bank slot takes one from the stock the first time it has a mark to wear.
-- Moving it under the slot is Overlay.Attach, the same SetParent the bag slots' overlays take.
-- Only a client whose bank is the pooled panel (Overlay.HasBankPanel) makes a stock; Classic Era
-- makes none.
--
-- The pool hands the same buttons out again on every page, tab and bank type (it makes a button
-- only when every one it holds is in use), and an overlay stays on its button for the session, so
-- one page's worth covers every button the panel can show at once: Overlay.BANK_STOCK is the camelot
-- panel's page size (Camelot/BankFrame.xml:88 maximumTotalSlotsPerPage 88; the panel's page filter
-- is Mainline/BankFrameTemplates.lua:1003-1010). Should a bank ever show more slots at once than
-- that, the slots past the stock go unmarked (Overlay.stockShort counts them) and the stock is
-- topped up by that many on the first pass after the bank closes, so the next open marks them.
--------------------------------------------------------------------------------

Overlay.BANK_STOCK = 88

-- The built overlays not yet under a slot, last made first out.
local stock = {}
-- Bank slots left unmarked for want of a stocked overlay since the last top up, each button counted
-- once however many passes find it short (shortButtons, weakly held like the overlays).
Overlay.stockShort = 0
local shortButtons = setmetatable({}, { __mode = "k" })
-- How many overlays the stock has been made with, in all, this session.
Overlay.stockMade = 0
-- How long the login fill took, in ms on the client's debugprofilestop, or nil where unmeasured.
Overlay.stockMs = nil

-- True when this client's bank is the pooled panel: the global BankPanel carrying the method every
-- page, tab and bank type is drawn by (see collectBankPanel).
function Overlay.HasBankPanel()
  local panel = rawget(_G, "BankPanel")
  return type(panel) == "table" and type(panel[Overlay.BANK_PANEL_HOOK]) == "function"
end

-- How many built overlays the stock holds.
function Overlay.StockCount()
  return #stock
end

-- Builds overlays into the stock until it holds total (Overlay.BANK_STOCK when not given). Never
-- while the bank is shown, and only on a client with the bank panel. Answers how many were made.
function Overlay.FillStock(total)
  if not Overlay.HasBankPanel() or isShown(rawget(_G, "BankFrame")) then
    return 0
  end
  total = tonumber(total) or Overlay.BANK_STOCK
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  local made = 0
  while #stock < total do
    local frame = buildOverlay(settings, nil, nil)
    if not frame then
      break
    end
    stock[#stock + 1] = frame
    made = made + 1
  end
  Overlay.stockMade = Overlay.stockMade + made
  return made
end

-- The first pass after the bank closes makes up for any slot the stock fell short on (called from
-- collectBankPanel while the bank is closed). Answers how many were made.
function Overlay.TopUpStock()
  if Overlay.stockShort <= 0 or isShown(rawget(_G, "BankFrame")) then
    return 0
  end
  local short = Overlay.stockShort
  Overlay.stockShort = 0
  shortButtons = setmetatable({}, { __mode = "k" })
  return Overlay.FillStock(#stock + short)
end

-- One stocked overlay moved under a bank panel button, or nil when the stock is empty (counted for
-- the top up) or the move did not take (the overlay goes back to the stock).
local function stockedOverlay(button, settings)
  local frame = table.remove(stock)
  if not frame then
    if not shortButtons[button] then
      shortButtons[button] = true
      Overlay.stockShort = Overlay.stockShort + 1
    end
    return nil
  end
  if not attachOverlay(frame, button, settings) then
    stock[#stock + 1] = frame
    return nil
  end
  return frame
end

-- Sizes and places one badge cluster on the frame it marks: every badge at the size given,
-- each one anchored by its own corner to anchor's matching corner through Overlay.Anchor. The
-- cluster's own column layout only knows top to bottom, so each badge is anchored here instead,
-- which is what lets the stack run up from a bottom corner. Called after SetKinds, so a badge
-- the cluster has just made is placed with the rest. The bag overlay and the settings panel's
-- preview slot both come through here, so the preview is the real placement and not a copy of
-- it. Returns true when the cluster could be placed.
function Overlay.Place(cluster, anchor, size, corner)
  if type(cluster) ~= "table" then
    return false
  end
  size = tonumber(size) or Overlay.BadgeSize(nil)
  corner = Overlay.Corner(corner)
  local badges = type(cluster.badges) == "table" and cluster.badges or {}
  if cluster.badgeSize ~= size then
    cluster.badgeSize = size
    for _, badge in ipairs(badges) do
      method(badge, "SetBadgeSize", size)
    end
  end
  local kinds = type(cluster.kinds) == "table" and cluster.kinds or {}
  if #kinds > 0 and type(Badges.ClusterExtent) == "function" then
    method(cluster, "SetSize", Badges.ClusterExtent(#kinds, size, cluster.gap or Overlay.GAP, "column"))
  end
  local point, relativePoint, x, y = Overlay.Anchor(1, size, corner)
  method(cluster, "ClearAllPoints")
  method(cluster, "SetPoint", point, anchor, relativePoint, x, y)
  for index, badge in ipairs(badges) do
    point, relativePoint, x, y = Overlay.Anchor(index, size, corner)
    method(badge, "ClearAllPoints")
    method(badge, "SetPoint", point, anchor, relativePoint, x, y)
  end
  cluster.corner = corner
  return true
end

-- Brief P2 (#3): what each overlay last drew, so a pass that finds a slot unchanged leaves it
-- alone. SetKinds clears and redraws every badge, so redrawing an unchanged slot on every loot,
-- sale and sort cost widget calls for nothing; the skip saves that CPU. The
-- memory is the item id, the badge kinds in order, the size and the corner, held on the overlay
-- frame as drawn; hiddenAs is the outcome ("off" or "hidden") an overlay was last hidden for.
-- Overlay.Forget drops both on every overlay, which a Refresh that is not a queued bag pass does
-- first, so a settings change always redraws in full.
local function sameKinds(held, kinds)
  if type(held) ~= "table" or #held ~= #kinds then
    return false
  end
  for index = 1, #kinds do
    if held[index] ~= kinds[index] then
      return false
    end
  end
  return true
end

-- Whether a remembered draw still stands for these. profession is the skill line whose icon the
-- slot wears (nil for none) and professionCorner the corner setting it was placed from (brief
-- PR6), so a slot whose item joins or leaves the route, or a corner change, redraws. lift is the
-- icon's stack count lift (brief PR20), so a stack that grows a count, or loses it, redraws. Pure,
-- for the spec.
function Overlay.SameDraw(drawn, itemId, kinds, size, corner, profession, professionCorner, lift)
  if type(drawn) ~= "table" then
    return false
  end
  return drawn.itemId == itemId
    and drawn.size == size
    and drawn.corner == corner
    and drawn.profession == profession
    and drawn.professionCorner == professionCorner
    and drawn.professionLift == lift
    and sameKinds(drawn.kinds, kinds)
end

-- Brief OPT3 (F11): the badge kinds each slot button was last worked out with, so a queued bag
-- pass over an unchanged slot reuses them rather than asking Core/Diff.lua again (three small
-- tables a slot). Each memo holds the item id, the place and what the answer is read from: the
-- settings table and Core/Data.lua by identity and Data.generation (a harvest, Era or data reset
-- bumps it). A settings change reaches the bags through a Refresh that is not a reuse pass, and
-- Forget drops every memo (forgotten), so the answer is always the one Overlay.BadgesFor would give. Weak
-- keyed by the button, like the overlays.
local badgeMemos = setmetatable({}, { __mode = "k" })
-- Bumped by Overlay.Forget, which so drops every memo without making them again.
local forgotten = 0

-- What the badge answer is read from beyond the item, the place and the settings: Core/Data.lua by
-- identity and its generation. Two values, no table.
local function badgeEpoch()
  local data = ItemTree.Data
  if type(data) ~= "table" then
    return nil, nil
  end
  return data, rawget(data, "generation")
end

-- The slot's badge kinds: the memo's while it still stands, else Overlay.BadgesFor's answer, which
-- is remembered. The list handed back is never written to (SetKinds sorts into its own copy and
-- the drawn record takes a copy).
local function slotBadges(button, itemId, settings, where)
  local data, generation = badgeEpoch()
  local memo = button ~= nil and badgeMemos[button] or nil
  if
    memo
    and memo.forgotten == forgotten
    and memo.itemId == itemId
    and memo.where == where
    and memo.settings == settings
    and memo.data == data
    and memo.generation == generation
  then
    return memo.kinds
  end
  local kinds = Overlay.BadgesFor(itemId, settings, where)
  if button ~= nil then
    if not memo then
      memo = {}
      badgeMemos[button] = memo
    end
    memo.forgotten, memo.itemId, memo.where, memo.settings = forgotten, itemId, where, settings
    memo.data, memo.generation, memo.kinds = data, generation, kinds
  end
  return kinds
end

function Overlay.Forget()
  for _, frame in pairs(overlays) do
    frame.drawn = nil
    frame.hiddenAs = nil
  end
  forgotten = forgotten + 1
end

-- Brief OPT3 (F11): the look and ramp a whole pass draws with. Overlay.Refresh works them out once
-- (Overlay.KeepLook) for the settings it hands every slot and clears them when the pass ends, so a
-- slot drawn inside the pass reads two upvalues instead of rebuilding the Single colour key and
-- the valuable colour per slot. A slot drawn outside a pass (an adapter's own hook), or with other
-- settings, asks Overlay.KeepLook itself, as before.
local passSettings, passStyle, passRamp = nil, nil, nil

local function keepLook(settings)
  if passSettings ~= nil and settings == passSettings then
    return passStyle, passRamp
  end
  return Overlay.KeepLook(settings)
end

-- A bag addon's adapter hands the item over (false for an empty slot), because its slot may be
-- another character's cached bag, which the live container would answer wrongly for. Shared by
-- every slot, so a pass makes no closure per slot.
local function slotItem(target)
  if target.itemId ~= nil then
    return target.itemId or nil
  end
  return Overlay.ItemIdAt(target.bag, target.slot)
end

-- Brief K7: the slot's key, which is what the demo draws its tier by. Only the demo reads it
-- (Overlay.KeepStateFor), so it is built only while the demo is on.
local function slotKeyOf(target)
  if type(Overlay.demo) ~= "table" then
    return nil
  end
  return tostring(target.where) .. ":" .. tostring(target.bag) .. ":" .. tostring(target.slot)
end

-- Brief K24b: the live bag and slot of a target, for the slot's real bound state, or nil, nil for a
-- bag addon's cached slot (target.itemId set: it may be another character's bag).
local function liveSlot(target)
  if target.itemId ~= nil then
    return nil, nil
  end
  return target.bag, target.slot
end

-- Brief G1: one slot's draw under Core/Guard.lua's boundary. An error leaves that slot's marks off
-- (the client's own slot is untouched) and is recorded and handed to the client's error handler,
-- once per distinct message, rather than counted as failed without a word. Answers ok and the
-- outcome, the way the pcall it replaces did. Defined before apply, which it reaches through
-- Overlay.applySlot.
local function guardedApply(where, target, settings)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    return Guard.Run(where, Overlay.applySlot, target, settings)
  end
  return true, Overlay.applySlot(target, settings)
end

-- One button. Returns "shown", "hidden" or "off". No overlay is built for a slot with nothing
-- to say, so an empty bag costs no frames at all.
local function apply(target, settings)
  local button = target.button
  local existing = overlays[button]
  local itemId
  -- Brief K7: the look, the ramp and the slot's key, which is what the demo draws its tier by.
  local style, rampName = keepLook(settings)
  local slotKey = slotKeyOf(target)
  local tier, valuable, _, violet
  -- Brief T4: the Keep mark is its own setting, so a slot whose badges are off for this place can
  -- still glow. Only when neither is wanted is the slot off. The demo marks slots either way.
  local keepWanted = settingOn(settings, "keepMarks") or type(Overlay.demo) == "table"
  if not settingOn(settings, WHERE_SETTING[target.where] or WHERE_SETTING.bag) then
    itemId = keepWanted and slotItem(target) or nil
    if keepWanted then
      local bag, slot = liveSlot(target)
      tier, valuable, _, _, violet = Overlay.KeepStateFor(itemId, settings, slotKey, rampName, bag, slot)
    else
      tier, valuable = 0, false
    end
    noteTier(button, tier, rampName)
    if tier < 1 then
      if existing and existing.hiddenAs ~= "off" then
        method(existing, "Hide")
        existing.drawn = nil
        existing.hiddenAs = "off"
      end
      return "off"
    end
  else
    itemId = slotItem(target)
    local bag, slot = liveSlot(target)
    tier, valuable, _, _, violet = Overlay.KeepStateFor(itemId, settings, slotKey, rampName, bag, slot)
    noteTier(button, tier, rampName)
  end
  local kinds = slotBadges(button, itemId, settings, target.where)
  local keep = tier > 0
  -- Brief K24b: the Disenchant mark's violet is part of what was drawn.
  -- Brief BQ9: and the Use mark (violet "use").
  local markWord = ""
  if violet == Overlay.USE_MARK then
    markWord = ":use"
  elseif violet then
    markWord = ":violet"
  end
  -- Brief ST2: and the Mark size it was drawn at, which the Flag, the Corner gem and the Use mark
  -- follow (under ST1 the Use mark alone followed Bag badge size).
  markWord = markWord .. ":" .. tostring(Overlay.MarkScale(settings[Overlay.MARK_SCALE_SETTING]))
  local keepDrawn = keep and (style .. ":" .. rampName .. ":" .. tier .. (valuable and ":value" or "") .. markWord)
    or false
  -- Brief PR6: nil whenever the place is off, so the Keep only path above never draws it.
  local profession = Overlay.ProfessionFor(itemId, settings, target.where)
  if #kinds == 0 and not keep and not profession then
    if existing and existing.hiddenAs ~= "hidden" then
      method(existing.cluster, "SetKinds", {})
      Overlay.HideKeep(existing)
      hideProfession(existing.profession)
      method(existing, "Hide")
      existing.drawn = nil
      existing.hiddenAs = "hidden"
    end
    return "hidden"
  end
  local frame = existing
  if not frame then
    -- Brief BG3: a Forever bank panel slot takes an overlay made at login, never a new one.
    if target.pooled then
      frame = stockedOverlay(button, settings)
    else
      frame = createOverlay(button, settings)
    end
  end
  if not frame then
    return "hidden"
  end
  -- Size and corner are read on every draw, the way the badge settings are, so a slot that
  -- changed width (the other client, or a bag addon) and a setting changed in the panel both
  -- land on the next refresh with no second cluster built.
  local width = tonumber(method(button, "GetWidth"))
  local size = Overlay.BadgeSize(width, settings.bagBadgeScale)
  local corner = Overlay.Corner(settings.bagBadgeCorner)
  local professionCorner = Overlay.ProfessionCorner(settings.professionBadgeCorner)
  -- Brief PR20: read only for a slot that wears the icon, and only off the slot's own count.
  local lift
  if profession then
    lift = Overlay.CountLiftFor(button, tonumber(method(button, "GetHeight")) or width)
  end
  if
    frame.hiddenAs == nil
    and Overlay.SameDraw(frame.drawn, itemId, kinds, size, corner, profession, professionCorner, lift)
    and frame.drawn.keep == keepDrawn
  then
    return "shown"
  end
  method(frame.cluster, "SetKinds", kinds)
  Overlay.Place(frame.cluster, frame, size, settings.bagBadgeCorner)
  Overlay.ShowKeep(frame, tier, style, rampName, width, corner, valuable, violet, settings[Overlay.MARK_SCALE_SETTING])
  if profession and not frame.profession then
    frame.profession = Overlay.MakeProfessionIcon(frame)
  end
  -- Brief PM1: the icon and the Keep look are two drawings on the one frame; the icon keeps out
  -- of the corner the look's glyph holds.
  local lookCorner = profession and keep and Overlay.LookCorner(style, rampName, tier, corner, valuable, violet) or nil
  Overlay.ShowProfession(
    frame.profession,
    profession,
    frame,
    size,
    professionCorner,
    corner,
    #kinds,
    width,
    lift,
    lookCorner
  )
  method(frame, "Show")
  -- A copy of the kinds, because the cluster keeps the list it was handed.
  local held = {}
  for index = 1, #kinds do
    held[index] = kinds[index]
  end
  frame.drawn = {
    itemId = itemId,
    kinds = held,
    size = size,
    corner = corner,
    keep = keepDrawn,
    profession = profession,
    professionCorner = professionCorner,
    professionLift = lift,
  }
  frame.hiddenAs = nil
  return "shown"
end

Overlay.applySlot = apply

-- The overlay frame on one button, or nil. For the specs and for a sibling that wants to know
-- whether a slot is badged; nothing here builds one.
function Overlay.FrameFor(button)
  return overlays[button]
end

--------------------------------------------------------------------------------
-- Bag addon adapters (brief T5)
--
-- A bag addon replaces the client's bag frames with its own, so the walk above finds nothing to
-- mark. Each adapter below follows one addon's own slots, from what that addon's source does
-- (docs/bag-addons.md has the survey, with the file and commit each name was read from). The
-- rules are T6's: hooksecurefunc on the addon's own redraw function or the addon's own plugin
-- API, never a replaced function and never a field written onto the addon's frames. The
-- overlay is the same one the client's bags get, parented to the slot, mouse off, held in the
-- weak overlays table keyed by the slot. Each adapter keeps the slots it has seen in a weak
-- table of its own, which is how a settings change redraws them.
--
-- Every adapter carries:
--   name, label   the key and the words the debug line uses
--   addons        the addon folder names that turn it on
--   hookName      what it follows, for the debug line
--   install()     takes its hook or registration; true when something took
--   bagOf, slotOf, itemOf, whereOf (slot)   read the slot; itemOf answers false for an empty
--                 slot and nil when it cannot say, whereOf answers "bag", "bank" or nil to skip
--
-- An adapter whose addon is not loaded is never installed, and one that fails costs itself and
-- nobody else. A player with no bag addon gets only the generic hook on SetItemButtonTexture,
-- which turns away every button that does not name its bag, so nothing changes for them.
--------------------------------------------------------------------------------

-- Whether an addon is loaded: C_AddOns on the modern clients, the bare global on older ones.
local function addonLoaded(name)
  local addons = rawget(_G, "C_AddOns")
  if type(addons) == "table" and type(addons.IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(addons.IsAddOnLoaded, name)
    if ok and loaded then
      return true
    end
  end
  local legacy = rawget(_G, "IsAddOnLoaded")
  if type(legacy) == "function" then
    local ok, loaded = pcall(legacy, name)
    if ok and loaded then
      return true
    end
  end
  return false
end
Overlay.AddonLoaded = addonLoaded

-- An Ace addon object by name, or nil. AdiBags and BetterBags are both AceAddon-3.0 addons.
local function aceAddon(name)
  local libStub = rawget(_G, "LibStub")
  if type(libStub) ~= "table" and type(libStub) ~= "function" then
    return nil
  end
  local ok, ace = pcall(libStub, "AceAddon-3.0", true)
  if not ok or type(ace) ~= "table" or type(ace.GetAddon) ~= "function" then
    return nil
  end
  local found, addon = pcall(ace.GetAddon, ace, name, true)
  if found and type(addon) == "table" then
    return addon
  end
  return nil
end

local function field(object, key)
  if type(object) ~= "table" then
    return nil
  end
  return rawget(object, key)
end

local function secureHook(target, name, handler)
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" then
    return false
  end
  if target == nil then
    if type(rawget(_G, name)) ~= "function" then
      return false
    end
    local ok, err = pcall(hook, name, handler)
    if not ok then
      return trace(name .. " hook", err)
    end
    return true
  end
  if type(target) ~= "table" or type(target[name]) ~= "function" then
    return false
  end
  local ok, err = pcall(hook, target, name, handler)
  if not ok then
    return trace(name .. " hook", err)
  end
  return true
end

-- Per adapter state: whether it is on, and the slots it has seen with what each last drew.
Overlay.adapterState = {}

local function stateOf(name)
  local state = Overlay.adapterState[name]
  if not state then
    state = { active = false, installed = false, seen = setmetatable({}, { __mode = "k" }) }
    Overlay.adapterState[name] = state
  end
  return state
end

local ADAPTER_BY_NAME = {}

-- Draws one slot an adapter has seen. Returns the outcome apply gave, or nil when the adapter
-- could not place the slot at all.
local function drawSeen(adapter, button, settings)
  local where = adapter.whereOf(button)
  if where == nil then
    return nil
  end
  local itemId = adapter.itemOf(button)
  if itemId == nil then
    return nil
  end
  local target = {
    button = button,
    bag = adapter.bagOf(button),
    slot = adapter.slotOf(button),
    where = where,
    itemId = itemId,
  }
  local ok, outcome =
    guardedApply("Overlay." .. tostring(adapter.name), target, settings or (ItemTree.db and ItemTree.db.settings) or {})
  if not ok then
    trace(adapter.name .. " draw", outcome)
    return nil
  end
  return outcome
end

-- What an adapter's hook calls for one slot the addon has just drawn.
function Overlay.SeenSlot(name, button)
  local adapter = ADAPTER_BY_NAME[name]
  if not adapter or type(button) ~= "table" then
    return nil
  end
  local state = stateOf(name)
  -- Brief TX6: in combat the slot is remembered, and drawn with the rest when combat ends.
  if inCombat() then
    state.seen[button] = state.seen[button] or "skipped"
    bookAfterCombat("adapters", function()
      Overlay.RefreshAdapters()
    end)
    return nil
  end
  local outcome = drawSeen(adapter, button)
  state.seen[button] = outcome or "skipped"
  return outcome
end

-- The generic reading of a slot: a bag the button names outright, never one taken from its
-- parent (a loot or merchant button's parent answers an id too), and a slot from GetID.
local function namedBag(button)
  if type(button.GetBag) == "function" then
    local ok, bag = pcall(button.GetBag, button)
    if ok and whole(bag) then
      return whole(bag)
    end
  end
  for _, key in ipairs({ "bagID", "bagId", "BagID", "bag" }) do
    local bag = whole(field(button, key))
    if bag then
      return bag
    end
  end
  return nil
end

local function slotByID(button)
  return whole(method(button, "GetID"))
end

-- The client's own bag and bank buttons are the client adapter's, so the generic one leaves
-- them alone. They are the ones sitting straight in a container frame or the bank's slots. Brief
-- BG3: and in the Forever bank panel, whose pooled buttons are the client adapter's now.
local CLIENT_PARENTS = { "^ContainerFrame", "^BankSlotsFrame", "^BankFrame", "^ReagentBankFrame", "^BankPanel$" }

local function clientButton(button)
  local parent = method(button, "GetParent")
  local name = method(parent, "GetName")
  if type(name) ~= "string" then
    return false
  end
  for _, pattern in ipairs(CLIENT_PARENTS) do
    if name:match(pattern) then
      return true
    end
  end
  return false
end

-- Bagnon, Bagnonium (the addon that was Combuctor) and anything else built on BagBrother. Their
-- Item:Update ends in the global SetItemButtonTexture, and each slot keeps the addon's own record
-- of what it shows in its info field, which is right for another character's cached bag too.
--
-- Brief Q9a: BagBrother's own TOC loads no code at all on 12.1.4. Bagnon's main.xml includes
-- BagBrother's core, so WildAddon's NewAddon publishes the addon object under the HOST's name:
-- the global is Bagnon (or Bagnonium), never BagBrother. Looking for BagBrother alone is why the
-- adapter never claimed a slot and the generic one badged them instead. The object is known by
-- its Item class, which every host carries.
Overlay.BAGBROTHER_GLOBALS = { "Bagnon", "Bagnonium", "Combuctor", "BagBrother" }

local function bagBrother()
  for _, name in ipairs(Overlay.BAGBROTHER_GLOBALS) do
    local addon = rawget(_G, name)
    if type(addon) == "table" then
      local ok, item = pcall(function()
        return addon.Item
      end)
      if ok and type(item) == "table" then
        return addon
      end
    end
  end
  return nil
end
Overlay.BagBrother = bagBrother

local bagBrotherAdapter = {
  name = "bagbrother",
  label = "Bagnon",
  addons = { "BagBrother", "Bagnon", "Bagnonium", "Combuctor" },
  hookName = "SetItemButtonTexture",
  textureHook = true,
  claims = function(button)
    return bagBrother() ~= nil and type(button.GetBag) == "function" and type(field(button, "info")) == "table"
  end,
  bagOf = namedBag,
  slotOf = slotByID,
  itemOf = function(button)
    local info = field(button, "info")
    if type(info) ~= "table" then
      return nil
    end
    return whole(info.itemID) or false
  end,
  whereOf = function(button)
    local addon = bagBrother()
    local classes = { guild = addon and addon.GuildItem, vault = addon and addon.VaultItem }
    if type(classes.vault) == "table" and button.OnClick ~= nil and button.OnClick == classes.vault.OnClick then
      return nil
    end
    if type(classes.guild) == "table" and button.OnClick ~= nil and button.OnClick == classes.guild.OnClick then
      return "bank"
    end
    return Overlay.WhereForBag(namedBag(button))
  end,
}

-- AdiBags: its ItemButton class keeps bag, slot and itemId on each button, and every redraw runs
-- the class prototype's Update (the bank button class inherits it).
local adiBagsAdapter = {
  name = "adibags",
  label = "AdiBags",
  addons = { "AdiBags" },
  hookName = "ItemButton prototype Update",
  install = function()
    local addon = aceAddon("AdiBags")
    if not addon or type(addon.GetClass) ~= "function" then
      return false
    end
    local ok, class = pcall(addon.GetClass, addon, "ItemButton")
    local prototype = ok and field(class, "prototype") or nil
    return secureHook(prototype, "Update", function(button)
      Overlay.SeenSlot("adibags", button)
    end)
  end,
  bagOf = function(button)
    return whole(field(button, "bag"))
  end,
  slotOf = function(button)
    return whole(field(button, "slot"))
  end,
  itemOf = function(button)
    return whole(field(button, "itemId")) or false
  end,
  whereOf = function(button)
    local bag = whole(field(button, "bag"))
    if bag == nil then
      return nil
    end
    return Overlay.WhereForBag(bag)
  end,
}

-- ArkInventory: every slot's icon is drawn by ArkInventory.Frame_Item_Update_Texture(frame), the
-- slot's place is in its ARK_Data field, and ArkInventory.Frame_Item_GetDB(frame) answers the
-- addon's record of the slot, whose h is the item's link.
local ARK_LOCATIONS = { Bag = 1, Bank = 3, Vault = 4 }

local function arkInventory()
  local addon = rawget(_G, "ArkInventory")
  return type(addon) == "table" and addon or nil
end

local function arkData(frame)
  local data = field(frame, "ARK_Data")
  return type(data) == "table" and data or nil
end

local arkInventoryAdapter = {
  name = "arkinventory",
  label = "ArkInventory",
  addons = { "ArkInventory" },
  hookName = "ArkInventory.Frame_Item_Update_Texture",
  install = function()
    return secureHook(arkInventory(), "Frame_Item_Update_Texture", function(frame)
      Overlay.SeenSlot("arkinventory", frame)
    end)
  end,
  bagOf = function(frame)
    local data = arkData(frame)
    return data and whole(data.bag_id) or nil
  end,
  slotOf = function(frame)
    local data = arkData(frame)
    return data and whole(data.slot_id) or nil
  end,
  itemOf = function(frame)
    local addon = arkInventory()
    if not addon or type(addon.Frame_Item_GetDB) ~= "function" then
      return nil
    end
    local ok, record = pcall(addon.Frame_Item_GetDB, frame)
    if not ok then
      return nil
    end
    if type(record) ~= "table" then
      return false
    end
    return Overlay.ItemIdFromLink(record.h) or false
  end,
  whereOf = function(frame)
    local data = arkData(frame)
    if not data then
      return nil
    end
    local addon = arkInventory()
    local const = addon and field(addon, "Const")
    local locations = type(const) == "table" and type(const.Location) == "table" and const.Location or ARK_LOCATIONS
    local loc = data.loc_id
    if loc == (locations.Bag or ARK_LOCATIONS.Bag) then
      return "bag"
    end
    if loc == (locations.Bank or ARK_LOCATIONS.Bank) or loc == (locations.Vault or ARK_LOCATIONS.Vault) then
      return "bank"
    end
    return nil
  end,
}

-- ElvUI: the Bags module redraws one slot at a time through B:UpdateSlot(frame, bagID, slotID),
-- where the slot is frame.Bags[bagID][slotID] and carries itemID, BagID and bagFrame. ElvUI
-- keeps its own local copy of SetItemButtonTexture, so the generic hook never sees it.
local function elvBags()
  local elv = rawget(_G, "ElvUI")
  local engine = type(elv) == "table" and elv[1] or nil
  if type(engine) ~= "table" or type(engine.GetModule) ~= "function" then
    return nil
  end
  local ok, bags = pcall(engine.GetModule, engine, "Bags", true)
  if ok and type(bags) == "table" then
    return bags
  end
  return nil
end

local elvUIAdapter = {
  name = "elvui",
  label = "ElvUI",
  addons = { "ElvUI" },
  hookName = "ElvUI Bags UpdateSlot",
  install = function()
    return secureHook(elvBags(), "UpdateSlot", function(_, frame, bagID, slotID)
      local bags = field(frame, "Bags")
      local bag = type(bags) == "table" and bags[bagID] or nil
      local slot = type(bag) == "table" and bag[slotID] or nil
      if type(slot) == "table" then
        Overlay.SeenSlot("elvui", slot)
      end
    end)
  end,
  bagOf = function(slot)
    return whole(field(slot, "BagID"))
  end,
  slotOf = slotByID,
  itemOf = function(slot)
    return whole(field(slot, "itemID")) or false
  end,
  whereOf = function(slot)
    local bagFrame = field(slot, "bagFrame")
    if type(bagFrame) == "table" and field(bagFrame, "isBank") then
      return "bank"
    end
    return Overlay.WhereForBag(whole(field(slot, "BagID")))
  end,
}

-- BetterBags: its Events module sends item/Updated (ctx, item, decoration) after every slot draw
-- and item/Clearing before a slot is emptied. The decoration is the button the player sees, and
-- item:GetItemData() answers the slot's bagid, slotid and itemInfo.itemID.
local betterBagsItems = setmetatable({}, { __mode = "k" })

local function betterBagsData(button)
  local item = betterBagsItems[button]
  if type(item) ~= "table" or type(item.GetItemData) ~= "function" then
    return nil
  end
  local ok, data = pcall(item.GetItemData, item)
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

local betterBagsAdapter = {
  name = "betterbags",
  label = "BetterBags",
  addons = { "BetterBags" },
  hookName = "BetterBags item/Updated",
  install = function()
    local addon = aceAddon("BetterBags")
    if not addon or type(addon.GetModule) ~= "function" then
      return false
    end
    local ok, events = pcall(addon.GetModule, addon, "Events", true)
    if not ok or type(events) ~= "table" or type(events.RegisterMessage) ~= "function" then
      return false
    end
    local function buttonOf(item, decoration)
      if type(decoration) == "table" then
        return decoration
      end
      return type(item) == "table" and field(item, "button") or nil
    end
    local updated = pcall(events.RegisterMessage, events, "item/Updated", function(_, item, decoration)
      local button = buttonOf(item, decoration)
      if type(button) == "table" then
        betterBagsItems[button] = item
        Overlay.SeenSlot("betterbags", button)
      end
    end)
    pcall(events.RegisterMessage, events, "item/Clearing", function(_, item, decoration)
      local button = buttonOf(item, decoration)
      local frame = type(button) == "table" and overlays[button] or nil
      if frame then
        method(frame, "Hide")
        frame.drawn = nil
        frame.hiddenAs = "hidden"
      end
    end)
    return updated
  end,
  bagOf = function(button)
    local data = betterBagsData(button)
    return data and whole(data.bagid) or nil
  end,
  slotOf = function(button)
    local data = betterBagsData(button)
    return data and whole(data.slotid) or nil
  end,
  itemOf = function(button)
    local data = betterBagsData(button)
    if not data then
      return nil
    end
    local info = data.itemInfo
    return type(info) == "table" and whole(info.itemID) or false
  end,
  whereOf = function(button)
    local data = betterBagsData(button)
    if not data then
      return nil
    end
    return Overlay.WhereForBag(whole(data.bagid))
  end,
}

-- Baganator: no hook at all. Its own plugin API, Baganator.API.RegisterCornerWidget, asks for a
-- frame per slot (onInit) and then asks that frame to draw for each item (onUpdate, which
-- answers true to show). Baganator places and shows the frame in whichever icon corner the
-- player picked in its settings, top right by default here. The frame and its badge cluster are
-- ItemTree's own.
Overlay.BAGANATOR_WIDGET = "itemtree"
local baganatorCorners = setmetatable({}, { __mode = "k" })

-- Brief OPT6: Overlay.MarchStats over every overlay ItemTree made, the bags' and Baganator's.
function Overlay.MarchReport()
  local frames = {}
  for _, frame in pairs(overlays) do
    frames[#frames + 1] = frame
  end
  for frame in pairs(baganatorCorners) do
    frames[#frames + 1] = frame
  end
  return Overlay.MarchStats(frames)
end
-- Brief TX6: corner frames built in combat, waiting to be moved under their slot, by frame.
local baganatorUnattached = setmetatable({}, { __mode = "k" })

-- What Baganator's surface books for the end of combat: every corner frame built in combat moved
-- under its slot, then Baganator asked to draw its slots again.
local function baganatorAfterCombat()
  for frame, itemButton in pairs(baganatorUnattached) do
    if Overlay.Attach(frame, itemButton, 1) then
      baganatorUnattached[frame] = nil
    end
  end
  local addon = rawget(_G, "Baganator")
  local api = type(addon) == "table" and field(addon, "API") or nil
  if type(api) == "table" and type(api.RequestItemButtonsRefresh) == "function" then
    pcall(api.RequestItemButtonsRefresh)
  end
end

function Overlay.BaganatorInit(itemButton)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  -- Brief TX2: built whole with no parent and moved under the slot last, one level above it
  -- where a frame made with its parent lands. See Overlay.Attach.
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" then
    return nil
  end
  method(frame, "EnableMouse", false)
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  local size = Overlay.BadgeSize(tonumber(method(itemButton, "GetWidth")), settings.bagBadgeScale)
  local cluster = Badges.CreateCluster(frame, size, Overlay.MAX_BADGES, "column", Overlay.GAP)
  if not cluster then
    return nil
  end
  method(cluster, "EnableMouse", false)
  method(cluster, "Fill")
  frame.cluster = cluster
  frame.slot = itemButton
  frame.keepSlot = itemButton
  -- The Keep mark rings the whole slot, so it is centred on the item button rather than on this
  -- corner frame, and shows while Baganator shows the frame.
  frame.glow = Overlay.MakeGlow(frame, itemButton)
  frame.ring = Overlay.MakeRing(frame, itemButton)
  watchMarch(frame)
  method(frame, "SetSize", size, size)
  baganatorCorners[frame] = false
  -- Brief TX6: built whole in combat, but moved under the slot only when combat ends.
  if inCombat() then
    baganatorUnattached[frame] = itemButton
    bookAfterCombat("baganator", baganatorAfterCombat)
    return frame
  end
  if not Overlay.Attach(frame, itemButton, 1) then
    baganatorCorners[frame] = nil
    return nil
  end
  return frame
end

-- true to show, false for a slot with nothing to say, nil while Baganator has no item id yet.
function Overlay.BaganatorUpdate(frame, details)
  if type(frame) ~= "table" or type(details) ~= "table" then
    return false
  end
  -- Brief TX6: in combat the corner keeps what it last answered and nothing on it is touched.
  if inCombat() then
    bookAfterCombat("baganator", baganatorAfterCombat)
    return baganatorCorners[frame] == true
  end
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  local where = "bag"
  local slotKey
  local location = details.itemLocation
  if type(location) == "table" and type(location.GetBagAndSlot) == "function" then
    local ok, bag, slot = pcall(location.GetBagAndSlot, location)
    if ok and whole(bag) then
      where = Overlay.WhereForBag(whole(bag))
      slotKey = where .. ":" .. tostring(whole(bag)) .. ":" .. tostring(whole(slot))
    end
  end
  local kinds = Overlay.BadgesFor(details.itemID, settings, where)
  local style, rampName = Overlay.KeepLook(settings)
  -- Brief K28: Baganator's own details.itemLink (docs/bag-addons.md), for a random suffix roll.
  local tier, valuable, _, _, violet =
    Overlay.KeepStateFor(details.itemID, settings, slotKey, rampName, nil, nil, details.itemLink)
  local keep = tier > 0
  local profession = Overlay.ProfessionFor(details.itemID, settings, where)
  baganatorCorners[frame] = #kinds > 0 or keep or profession ~= nil
  local slotWidth = tonumber(method(frame.slot, "GetWidth"))
  Overlay.ShowKeep(
    frame,
    tier,
    style,
    rampName,
    slotWidth,
    Overlay.CORNER_DEFAULT,
    valuable,
    violet,
    settings[Overlay.MARK_SCALE_SETTING]
  )
  local size = Overlay.BadgeSize(slotWidth, settings.bagBadgeScale)
  -- Brief PR6: the icon is placed on the item button itself, in the corner the setting names,
  -- and Baganator keeps this frame, and the badges with it, in the slot's top right.
  if profession and not frame.profession then
    frame.profession = Overlay.MakeProfessionIcon(frame)
  end
  Overlay.ShowProfession(
    frame.profession,
    profession,
    frame.slot or frame,
    size,
    settings.professionBadgeCorner,
    Overlay.CORNER_DEFAULT,
    #kinds,
    slotWidth,
    profession and Overlay.CountLiftFor(frame.slot, tonumber(method(frame.slot, "GetHeight")) or slotWidth) or 0,
    profession and keep and Overlay.LookCorner(style, rampName, tier, Overlay.CORNER_DEFAULT, valuable, violet) or nil
  )
  if #kinds == 0 and not keep and not profession then
    method(frame.cluster, "SetKinds", {})
    return false
  end
  method(frame.cluster, "SetKinds", kinds)
  Overlay.Place(frame.cluster, frame, size, Overlay.CORNER_DEFAULT)
  local width, height = size, size
  if type(Badges.ClusterExtent) == "function" then
    width, height = Badges.ClusterExtent(#kinds, size, Overlay.GAP, "column")
  end
  method(frame, "SetSize", width, height)
  return true
end

local baganatorAdapter = {
  name = "baganator",
  label = "Baganator",
  addons = { "Baganator" },
  hookName = "Baganator.API.RegisterCornerWidget",
  install = function()
    local addon = rawget(_G, "Baganator")
    local api = type(addon) == "table" and field(addon, "API") or nil
    if type(api) ~= "table" or type(api.RegisterCornerWidget) ~= "function" then
      return false
    end
    local ok, err = pcall(
      api.RegisterCornerWidget,
      "ItemTree",
      Overlay.BAGANATOR_WIDGET,
      Overlay.BaganatorUpdate,
      Overlay.BaganatorInit,
      { corner = "top_right", priority = 1 }
    )
    if not ok then
      return trace("Baganator corner widget", err)
    end
    return true
  end,
  -- Baganator draws and shows the corner itself, so a settings change only asks it to redraw.
  refresh = function()
    local addon = rawget(_G, "Baganator")
    local api = type(addon) == "table" and field(addon, "API") or nil
    if type(api) == "table" and type(api.RequestItemButtonsRefresh) == "function" then
      pcall(api.RequestItemButtonsRefresh)
    end
  end,
  count = function()
    local shown = 0
    for frame, badged in pairs(baganatorCorners) do
      if badged and isShown(frame) then
        shown = shown + 1
      end
    end
    return shown
  end,
}

-- The fallback for any other bag addon: its slots are caught as they draw through the global
-- SetItemButtonTexture, and kept only when the button names its bag outright (GetBag, or a bag,
-- bagID or BagID field) and is not one of the client's own. The item comes from an itemID or
-- itemId field where the addon keeps one, and from the live bag otherwise.
local genericAdapter = {
  name = "generic",
  label = "Other bag addons",
  hookName = "SetItemButtonTexture",
  textureHook = true,
  always = true,
  claims = function(button)
    return namedBag(button) ~= nil and slotByID(button) ~= nil and not clientButton(button)
  end,
  bagOf = namedBag,
  slotOf = slotByID,
  itemOf = function(button)
    local id = whole(field(button, "itemID")) or whole(field(button, "itemId"))
    if id then
      return id
    end
    return Overlay.ItemIdAt(namedBag(button), slotByID(button)) or false
  end,
  whereOf = function(button)
    return Overlay.WhereForBag(namedBag(button))
  end,
}

-- The client's own bags first (the walk above), then the named addons in the brief's priority,
-- and the generic fallback last so a named adapter always claims its own slots first.
Overlay.ADAPTERS = {
  { name = "client", label = "Client bags", always = true, hookName = "container frames", client = true },
  bagBrotherAdapter,
  adiBagsAdapter,
  arkInventoryAdapter,
  baganatorAdapter,
  elvUIAdapter,
  betterBagsAdapter,
  genericAdapter,
}
for _, adapter in ipairs(Overlay.ADAPTERS) do
  ADAPTER_BY_NAME[adapter.name] = adapter
end

-- Whether an adapter's addon is loaded. The client's and the generic one always are.
function Overlay.AdapterDetected(adapter)
  if type(adapter) ~= "table" then
    return false
  end
  if adapter.always then
    return true
  end
  for _, name in ipairs(adapter.addons or {}) do
    if addonLoaded(name) then
      return true
    end
  end
  return false
end

-- The one hook on the global SetItemButtonTexture, shared by every adapter that follows it: the
-- first active one that claims the button takes it. Cheap, because the client calls it for
-- every item button it draws anywhere.
local function onTexture(button)
  if type(button) ~= "table" then
    return
  end
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    if adapter.textureHook and stateOf(adapter.name).active then
      local ok, claimed = pcall(adapter.claims, button)
      if ok and claimed then
        Overlay.SeenSlot(adapter.name, button)
        return
      end
    end
  end
end

-- Takes each detected adapter's hook, once. Idempotent, and safe to call again later: an addon
-- that loaded after the first call is picked up by the next. Returns how many are active.
function Overlay.InstallAdapters()
  local active = 0
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    local state = stateOf(adapter.name)
    if not adapter.client and not state.installed and Overlay.AdapterDetected(adapter) then
      local took
      if adapter.textureHook then
        if not Overlay.textureHooked then
          Overlay.textureHooked = secureHook(nil, "SetItemButtonTexture", onTexture)
        end
        took = Overlay.textureHooked
      else
        local ok, answer = pcall(adapter.install)
        took = ok and answer == true
        if not ok then
          trace(adapter.name .. " install", answer)
        end
      end
      state.installed = took and true or false
      state.active = state.installed
    end
    if adapter.client then
      state.active = Overlay.installed == true
    end
    if state.active then
      active = active + 1
    end
  end
  return active
end

-- One slot an adapter has seen, drawn again, with its outcome kept on the adapter's seen list.
-- Shared by Overlay.RefreshAdapters and the sliced bag pass (brief PF7).
local function redrawSeen(adapter, button, settings)
  local outcome = drawSeen(adapter, button, settings)
  stateOf(adapter.name).seen[button] = outcome or "skipped"
  return outcome
end

-- Redraws every slot an adapter has seen that is still on screen, and counts the badged ones.
function Overlay.RefreshAdapters(settings)
  settings = settings or (ItemTree.db and ItemTree.db.settings) or {}
  Overlay.adapterStats = Overlay.adapterStats or {}
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    local state = stateOf(adapter.name)
    if state.active and not adapter.client then
      if type(adapter.refresh) == "function" then
        pcall(adapter.refresh)
      end
      if type(adapter.count) == "function" then
        local ok, shown = pcall(adapter.count)
        Overlay.adapterStats[adapter.name] = ok and tonumber(shown) or 0
      else
        local shown = 0
        for button in pairs(state.seen) do
          if isShown(button) then
            if redrawSeen(adapter, button, settings) == "shown" then
              shown = shown + 1
            end
          end
        end
        Overlay.adapterStats[adapter.name] = shown
      end
    end
  end
end

-- How many slots an adapter has badged as they stand now: its last pass, updated by every draw
-- its hook has taken since.
function Overlay.AdapterBadged(name)
  local adapter = ADAPTER_BY_NAME[name]
  if not adapter then
    return 0
  end
  if adapter.client then
    return tonumber(type(Overlay.stats) == "table" and Overlay.stats.shown) or 0
  end
  if type(adapter.count) == "function" then
    local ok, shown = pcall(adapter.count)
    return ok and tonumber(shown) or 0
  end
  local shown = 0
  for button, outcome in pairs(stateOf(name).seen) do
    if outcome == "shown" and isShown(button) then
      shown = shown + 1
    end
  end
  return shown
end

-- One line naming the active adapters and what each has badged. Counts only.
function Overlay.AdapterLine(onlyWithAddons)
  local parts, beyondClient = {}, false
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    local state = stateOf(adapter.name)
    if state.active then
      parts[#parts + 1] = string.format("%s %d", adapter.label, Overlay.AdapterBadged(adapter.name))
      beyondClient = beyondClient or not adapter.client
    end
  end
  if onlyWithAddons and not beyondClient then
    return nil
  end
  if #parts == 0 then
    return "Bag adapters: none active"
  end
  return "Bag adapters (slots badged): " .. table.concat(parts, ", ")
end

-- Re-evaluates every visible bag and bank button. Safe to call at any time: before Install,
-- with no client at all, and from Options.OnChanged when a setting changes. Returns how many
-- buttons were looked at, and leaves the tally in Overlay.stats.
--
-- reuse is true only for a pass a bag update takes on a client with no C_Timer (Overlay.Queue),
-- which leaves an unchanged slot as it is. Any other call (a setting changed, Install) forgets what
-- was drawn and redraws every slot. Brief PF7: this is the whole pass in one frame, for a setting
-- changed in the panel, Install and the demo; a bag update takes the sliced pass below
-- (Overlay.Queue), and a whole pass ends the one in flight, since it draws every slot itself.
function Overlay.Refresh(reuse)
  -- Brief TX6: in combat the whole pass waits for the end of combat, and redraws every slot then.
  if inCombat() then
    bookAfterCombat("bags", Overlay.Refresh)
    return 0
  end
  Overlay.pass = nil
  if reuse ~= true then
    Overlay.Forget()
  end
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  local ok, targets = pcall(Overlay.Targets)
  if not ok then
    trace("walking the bags", targets)
  end
  if not ok or type(targets) ~= "table" then
    targets = {}
  end
  local counts = { buttons = 0, shown = 0, hidden = 0, off = 0, failed = 0 }
  -- Brief OPT3 (F11): the pass's look, once (see keepLook).
  local lookOk, style, rampName = pcall(Overlay.KeepLook, settings)
  if lookOk then
    passSettings, passStyle, passRamp = settings, style, rampName
  end
  for _, target in ipairs(targets) do
    counts.buttons = counts.buttons + 1
    local applied, outcome = guardedApply("Overlay slot", target, settings)
    if applied and counts[outcome] then
      counts[outcome] = counts[outcome] + 1
    else
      counts.failed = counts.failed + 1
    end
  end
  Overlay.stats = counts
  pcall(Overlay.RefreshAdapters, settings)
  passSettings, passStyle, passRamp = nil, nil, nil
  return counts.buttons
end

--------------------------------------------------------------------------------
-- The queued bag pass, in slices (brief PF7)
--
-- The owner's hitch run on 1.60.1.70374 (2026-10-14): at a vendor the only frames of ours over
-- 33 ms were this module's bag pass, 30 to 43 ms, in the frame after the merchant opened. The
-- client opens every bag there, each bag's OnShow and UpdateItems hook asks for a pass, and the
-- one pass they shared drew every slot of every bag in one frame (offline over the shipped data,
-- 80 slots: about 44 ms with nothing warmed, 23 ms after the Keep scores were dropped).
--
-- So a bag update now takes a pass the way the login slicer builds its plan (Core/Data.lua
-- Data:PreloadSlice, briefs PF2 and PF3): every request until the pass starts is the same one
-- pass, and each frame draws slots for at most the slicer's budget (Data.PRELOAD_BUDGET_MS, 4 ms
-- on Data.SliceClock, at least one slot), the rest the next frame. The pass is the walk
-- Overlay.Refresh(true) makes: the same targets (Overlay.Targets), the same draw (apply), the same
-- order, then the slots the bag addon adapters have seen and their counts, so once it ends the
-- bags read exactly as a whole pass would leave them. Two things differ, both about when:
--   the slot the player is looking at (under the cursor, or holding the item on the cursor) is
--   drawn at the start of the next slice, the others keeping their order;
--   a slot's bag and slot are read off its button again when the slice reaches it, so a pooled
--   button the client gave another slot in between draws the slot it shows.
-- A request while a pass is drawing (another bag update, Keep.Repaint's Forget and Queue) asks for
-- one more pass after it, from the start the frame after it ends, so a slot drawn before the
-- change is drawn again and no frame takes two slices. Overlay.Refresh (a setting changed, the
-- demo, Install) is still the whole pass in one frame and ends a pass in flight. Combat stops a
-- pass where it is (brief TX6): every slot is drawn again, in slices, once combat ends.
--------------------------------------------------------------------------------

-- The pass in flight, or nil: { jobs, at, counts, shown, ticks, again }. jobs is nil until its
-- first slice, which takes the walk.
Overlay.pass = nil
-- The number of slices the last finished pass took, for the specs and the measure scripts.
Overlay.lastPassTicks = nil

-- The pass's budget per frame, in ms: the login slicer's, read when a slice starts.
local function passBudget()
  local data = ItemTree.Data
  local budget = type(data) == "table" and tonumber(data.PRELOAD_BUDGET_MS) or nil
  return budget or 4
end

-- The slicer's clock (Data.SliceClock: debugprofilestop in the client). 0 with no clock, which
-- never reaches a deadline, so the slice draws the whole pass.
local function passClock()
  local data = ItemTree.Data
  local clock = type(data) == "table" and data.SliceClock or nil
  if type(clock) == "function" then
    local ok, ms = pcall(clock)
    if ok and type(ms) == "number" then
      return ms
    end
  end
  return 0
end

-- Whether a client value may be compared (secret values, bible B10). Asked out of combat only, but
-- asked all the same.
local function readable(value)
  local util = ItemTree.Util
  if type(util) == "table" and type(util.CanRead) == "function" then
    return util.CanRead(value)
  end
  return true
end

-- The frames under the cursor as a set (GetMouseFoci, else the older GetMouseFocus), or nil.
local function underCursor()
  local foci = rawget(_G, "GetMouseFoci")
  if type(foci) == "function" then
    local ok, frames = pcall(foci)
    if ok and type(frames) == "table" then
      local set = nil
      for _, frame in ipairs(frames) do
        if type(frame) == "table" then
          set = set or {}
          set[frame] = true
        end
      end
      return set
    end
  end
  local focus = rawget(_G, "GetMouseFocus")
  if type(focus) == "function" then
    local ok, frame = pcall(focus)
    if ok and type(frame) == "table" then
      return { [frame] = true }
    end
  end
  return nil
end

-- The item id the cursor holds (an item being dragged), or nil.
local function cursorItem()
  local info = rawget(_G, "GetCursorInfo")
  if type(info) ~= "function" then
    return nil
  end
  local ok, kind, id = pcall(info)
  if not ok or not readable(kind) or kind ~= "item" or not readable(id) then
    return nil
  end
  return tonumber(id)
end

-- The item a job's slot holds as it stands: the live bag slot for the client's bags, the
-- adapter's own reading for a bag addon's slot.
local function jobItem(job)
  if job.adapter then
    local ok, id = pcall(job.adapter.itemOf, job.button)
    return ok and tonumber(id) or nil
  end
  local bag, slot = Overlay.ButtonSlot(job.button, job.hint)
  return Overlay.ItemIdAt(bag, slot)
end

-- Moves the slots the player is looking at to the front of what the pass has still to draw, the
-- rest keeping their order. Answers how many moved.
local function lookedAtFirst(pass)
  local hovered = underCursor()
  local held = cursorItem()
  if hovered == nil and held == nil then
    return 0
  end
  local jobs, picked = pass.jobs, nil
  for index = pass.at, #jobs do
    local job = jobs[index]
    if (hovered and hovered[job.button]) or (held and jobItem(job) == held) then
      picked = picked or {}
      picked[#picked + 1] = index
    end
  end
  if picked == nil or (#picked == 1 and picked[1] == pass.at) then
    return 0
  end
  local moved = {}
  for index = #picked, 1, -1 do
    table.insert(moved, 1, table.remove(jobs, picked[index]))
  end
  for offset, job in ipairs(moved) do
    table.insert(jobs, pass.at + offset - 1, job)
  end
  return #moved
end

-- The pass's walk, taken at its first slice: the client's own bag and bank slots
-- (Overlay.Targets), then every slot a bag addon's adapter has seen that is on screen, as
-- Overlay.RefreshAdapters draws them (an adapter that counts its own, Baganator, draws itself).
local function passJobs()
  local ok, targets = pcall(Overlay.Targets)
  if not ok then
    trace("walking the bags", targets)
  end
  local jobs = (ok and type(targets) == "table") and targets or {}
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    local state = stateOf(adapter.name)
    if state.active and not adapter.client and type(adapter.count) ~= "function" then
      for button in pairs(state.seen) do
        if isShown(button) then
          jobs[#jobs + 1] = { button = button, adapter = adapter }
        end
      end
    end
  end
  return jobs
end

-- One slot of the pass: a client target with its slot read again off its button, or a bag addon's
-- slot through its adapter, tallied the way Overlay.Refresh and Overlay.RefreshAdapters tally.
local function drawJob(pass, job, settings)
  if job.adapter then
    -- An adapter's own reading of its slot (whereOf, itemOf) can raise: it costs that slot only,
    -- as the pcall round Overlay.RefreshAdapters did in a whole pass.
    local ok, outcome = pcall(redrawSeen, job.adapter, job.button, settings)
    if not ok then
      trace(tostring(job.adapter.name) .. " draw", outcome)
    elseif outcome == "shown" then
      pass.shown[job.adapter.name] = (pass.shown[job.adapter.name] or 0) + 1
    end
    return
  end
  local bag, slot = Overlay.ButtonSlot(job.button, job.hint)
  if slot ~= nil then
    job.bag, job.slot = bag, slot
    job.where = job.whereHint or Overlay.WhereForBag(bag)
  end
  local counts = pass.counts
  counts.buttons = counts.buttons + 1
  local applied, outcome = guardedApply("Overlay slot", job, settings)
  if applied and counts[outcome] then
    counts[outcome] = counts[outcome] + 1
  else
    counts.failed = counts.failed + 1
  end
end

-- The end of a pass: the tally, and each adapter's count and own refresh, as
-- Overlay.RefreshAdapters leaves them.
local function finishPass(pass)
  Overlay.stats = pass.counts
  Overlay.lastPassTicks = pass.ticks
  Overlay.adapterStats = Overlay.adapterStats or {}
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    local state = stateOf(adapter.name)
    if state.active and not adapter.client then
      if type(adapter.refresh) == "function" then
        pcall(adapter.refresh)
      end
      if type(adapter.count) == "function" then
        local ok, shown = pcall(adapter.count)
        Overlay.adapterStats[adapter.name] = ok and tonumber(shown) or 0
      else
        Overlay.adapterStats[adapter.name] = pass.shown[adapter.name] or 0
      end
    end
  end
end

-- What C_Timer.After(0) calls: the next slice, through the table, so /itprobe hitch times it, and
-- under Core/Guard.lua's boundary (brief G1): a slice that raised is reported once, and its pass is
-- let go rather than left in flight, where every later request would only ask for "one more".
local function onTick()
  Overlay.pending = nil
  local Guard = ItemTree.Guard
  if type(Guard) ~= "table" or type(Guard.Run) ~= "function" then
    Overlay.PassTick()
    return
  end
  if not Guard.Run("Overlay pass", Overlay.PassTick) then
    Overlay.pass = nil
    passSettings, passStyle, passRamp = nil, nil, nil
  end
end

-- Books the next slice for the next frame, once. Answers whether one is booked.
local function bookTick()
  if Overlay.pending then
    return true
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  Overlay.pending = true
  if not pcall(timer.After, 0, onTick) then
    Overlay.pending = nil
    return false
  end
  return true
end

-- Brief TX6: a pass combat stopped is taken again from the start once combat ends, every slot
-- drawn afresh (Overlay.Forget), as the whole pass booked for then does.
local function passAfterCombat()
  Overlay.Forget()
  Overlay.Queue()
end

-- One slice of the pass in flight: slots for at most budget ms (passBudget by default), at least
-- one, the slots the player is looking at first; the next slice booked for the next frame, or the
-- pass finished. Answers how many slots it drew.
function Overlay.PassTick(budget)
  local pass = Overlay.pass
  if pass == nil then
    return 0
  end
  if inCombat() then
    Overlay.pass = nil
    bookAfterCombat("bags", passAfterCombat)
    return 0
  end
  if pass.jobs == nil then
    pass.jobs = passJobs()
    pass.counts = { buttons = 0, shown = 0, hidden = 0, off = 0, failed = 0 }
    pass.shown = {}
    pass.ticks = 0
  end
  pass.ticks = pass.ticks + 1
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  -- Brief OPT3 (F11): the slice's look, once (see keepLook).
  local lookOk, style, rampName = pcall(Overlay.KeepLook, settings)
  if lookOk then
    passSettings, passStyle, passRamp = settings, style, rampName
  end
  lookedAtFirst(pass)
  local deadline = passClock() + (tonumber(budget) or passBudget())
  local jobs, drawn = pass.jobs, 0
  while pass.at <= #jobs do
    local job = jobs[pass.at]
    pass.at = pass.at + 1
    drawJob(pass, job, settings)
    drawn = drawn + 1
    -- A whole pass taken meanwhile (Overlay.Refresh) has drawn the rest.
    if Overlay.pass ~= pass then
      break
    end
    -- Where no next frame can be booked (C_Timer refused it), the pass finishes now.
    if pass.at <= #jobs and passClock() >= deadline and bookTick() then
      break
    end
  end
  passSettings, passStyle, passRamp = nil, nil, nil
  if pass.at > #jobs and Overlay.pass == pass then
    Overlay.pass = nil
    finishPass(pass)
    if pass.again then
      Overlay.Queue()
    end
  end
  return drawn
end

-- Asks for a bag pass. Every request until the pass starts is the same pass, which starts the next
-- frame; a request while one is drawing asks for one more after it (see above). On a client with
-- no C_Timer the whole pass is drawn at once, as before. Answers whether this call asked for a new
-- pass.
function Overlay.Queue()
  local pass = Overlay.pass
  if pass then
    if pass.jobs then
      pass.again = true
    end
    return false
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    Overlay.Refresh(true)
    return true
  end
  Overlay.pass = { at = 1, again = false }
  if not bookTick() then
    Overlay.pass = nil
    Overlay.Refresh(true)
  end
  return true
end

-- Brief PF3: the bags the login slicer scores (the backpack and the four bag slots).
Overlay.WARM_BAGS = { 0, 1, 2, 3, 4 }

-- Brief PF3: the Keep score of every item in the bags, scored with exactly the call a bag slot's
-- mark makes (Overlay.KeepStateFor with the slot's bag and slot), so the first bag open after it
-- draws from Core/Keep.lua's held scores: about 14 ms over 80 slots before, 1.2 ms after (offline,
-- out-pf3/REPORT.md). The login slicer (Core/Data.lua Data.PRELOAD_BAG_WARM) calls it once, inside
-- its own coroutine, and Data.SliceCheck between two slots carries it over frames. Container slot
-- reads only, the same ones the marks make; nothing is drawn and nothing is asked of the server.
-- Answers how many slots were scored; 0 with Keep marks off, in combat or outside the client.
function Overlay.WarmScores()
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  if not settingOn(settings, "keepMarks") or type(Overlay.demo) == "table" or inCombat() then
    return 0
  end
  local container = rawget(_G, "C_Container")
  local slotsOf = type(container) == "table" and container.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots")
  if type(slotsOf) ~= "function" then
    return 0
  end
  local data = ItemTree.Data
  local check = type(data) == "table" and data.SliceCheck or nil
  local _, rampName = Overlay.KeepLook(settings)
  local scored = 0
  for _, bag in ipairs(Overlay.WARM_BAGS) do
    local ok, slots = pcall(slotsOf, bag)
    for slot = 1, (ok and tonumber(slots)) or 0 do
      local itemId = Overlay.ItemIdAt(bag, slot)
      if itemId then
        pcall(Overlay.KeepStateFor, itemId, settings, nil, rampName, bag, slot)
        scored = scored + 1
        if type(check) == "function" then
          check(1)
        end
      end
    end
  end
  return scored
end

-- The passes taken a moment after Install, so a bag the player never touches still ends up
-- marked. Two things make the first draw late on this client and neither is something the
-- module can be told about: a bag that was open across a /reload is reopened by the client's
-- own BAG_OPEN handling some time after PLAYER_LOGIN, and a bag that is open paints its items
-- from a ContinueOnLoad callback once their data has arrived. Returns how many were scheduled;
-- 0 on a client with no C_Timer, which refreshes straight away everywhere else instead.
function Overlay.Settle(delays)
  if type(delays) ~= "table" then
    delays = Overlay.SETTLE_DELAYS
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    Overlay.settled = 0
    return 0
  end
  local taken = 0
  for _, delay in ipairs(delays) do
    local ok, err = pcall(timer.After, delay, queueRefresh)
    if ok then
      taken = taken + 1
    else
      trace("settle pass", err)
    end
  end
  Overlay.settled = taken
  return taken
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- BAG_UPDATE_DELAYED is the one to listen to: BAG_UPDATE fires once per bag per change, and
-- several of them arrive for a single loot. The bank events cover a bank that opens or
-- changes while it is open, and PLAYER_ENTERING_WORLD covers a reload with the bags open.
Overlay.EVENTS = {
  "BAG_UPDATE_DELAYED",
  "BANKFRAME_OPENED",
  "PLAYERBANKSLOTS_CHANGED",
  "PLAYER_ENTERING_WORLD",
  -- Brief T4: a new level moves which uses are still ahead, so the Keep marks are scored again.
  "PLAYER_LEVEL_UP",
}

local WATCHED = {}
for _, event in ipairs(Overlay.EVENTS) do
  WATCHED[event] = true
end

-- Brief Q9a: an addon that loads after ItemTree (a load on demand Bagnon module, or a bag addon
-- a player loads by hand) is picked up the moment it loads, rather than at the next world entry.
-- Registered on its own, outside Overlay.EVENTS, and only an addon some adapter names asks for
-- anything: every other addon's load costs one table lookup.
Overlay.LATE_EVENT = "ADDON_LOADED"

-- The addon names any adapter turns on for, as a set.
local function adapterAddons()
  local set = {}
  for _, adapter in ipairs(Overlay.ADAPTERS) do
    for _, name in ipairs(adapter.addons or {}) do
      set[name] = true
    end
  end
  return set
end

-- Takes the hooks of an adapter whose addon has just loaded. True when the addon was one an
-- adapter names and the overlay is installed.
function Overlay.OnAddonLoaded(name)
  if not Overlay.installed or type(name) ~= "string" then
    return false
  end
  Overlay.adapterAddons = Overlay.adapterAddons or adapterAddons()
  if not Overlay.adapterAddons[name] then
    return false
  end
  pcall(Overlay.InstallAdapters)
  Overlay.Queue()
  return true
end

-- True when the event asked for a refresh. An event this module does not watch is ignored
-- outright, so a client that hands us BAG_UPDATE anyway still does not cost a walk.
function Overlay.OnEvent(event, ...)
  if event == Overlay.LATE_EVENT then
    return Overlay.OnAddonLoaded(...)
  end
  if not WATCHED[event] then
    return false
  end
  if event == "PLAYER_LEVEL_UP" then
    Overlay.player = nil
    local keep = ItemTree.Keep
    if type(keep) == "table" and type(keep.Reset) == "function" then
      keep.Reset()
    end
    Overlay.Forget()
  end
  -- A bag addon that loaded after login is picked up on the next world entry.
  if event == "PLAYER_ENTERING_WORLD" and Overlay.installed then
    pcall(Overlay.InstallAdapters)
  end
  Overlay.Queue()
  return true
end

-- Nothing to do on load: Install hooks the client, and the loader at the foot of the file
-- calls it at PLAYER_LOGIN.
function Overlay.Init() end

-- Hooks the client once. Idempotent; returns the event frame, or nil outside the client. Each
-- registration is taken on its own, so an engine that has dropped one of these events costs
-- us that event and not the rest.
function Overlay.Install()
  if Overlay.installed then
    return Overlay.frame
  end
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, "Frame")
  if not ok or type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return nil
  end
  local registered = 0
  for _, event in ipairs(Overlay.EVENTS) do
    if pcall(frame.RegisterEvent, frame, event) then
      registered = registered + 1
    end
  end
  if registered == 0 or type(frame.SetScript) ~= "function" then
    return nil
  end
  Overlay.lateRegistered = pcall(frame.RegisterEvent, frame, Overlay.LATE_EVENT) and true or false
  local hooked = pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
    Overlay.OnEvent(event, ...)
  end)
  if not hooked then
    return nil
  end
  Overlay.frame = frame
  Overlay.installed = true
  -- Classic Era redraws a bag through ContainerFrame_Update. The Forever client's container
  -- code names no such function, so on that client this hook covers nothing and the per frame
  -- UpdateItems hooks hookFrame takes are what cover a redraw.
  Overlay.hookedUpdate = hookGlobal("ContainerFrame_Update")
  -- Both clients open or rebuild a bag through ContainerFrame_GenerateFrame, and both call it
  -- by name, so this reaches a frame that did not exist the last time the bags were walked.
  Overlay.hookedGenerate = hookGlobal("ContainerFrame_GenerateFrame")
  Overlay.hooks.containerUpdate = Overlay.hookedUpdate
  Overlay.hooks.generateFrame = Overlay.hookedGenerate
  -- Brief BG3: the Forever bank panel's redraw, and the overlays its slots will wear, both now, at
  -- login, so the bank's first open makes no frame (see "The bank panel's stock").
  hookBankPanel(rawget(_G, "BankPanel"))
  local clock = rawget(_G, "debugprofilestop")
  local started = type(clock) == "function" and tonumber(apiCall(clock)) or nil
  if Overlay.FillStock() > 0 and started then
    local ended = tonumber(apiCall(clock))
    Overlay.stockMs = ended and (ended - started) or nil
  end
  -- Paints what is open and, just as importantly, hooks every bag frame that is not.
  pcall(Overlay.InstallAdapters)
  Overlay.Refresh()
  Overlay.Settle()
  return frame
end

--------------------------------------------------------------------------------
-- What the debug command can print
--------------------------------------------------------------------------------

-- One line saying how this module is wired into this client's bags and what the last pass saw.
-- Counts and yes or no answers only, so no item, character or realm fact can reach it. The
-- shape is ItemTree.CollectorStatusLine's, which is what UI/Slash.lua already prints.
function Overlay.StatusLine()
  local hooks = Overlay.hooks
  local stats = type(Overlay.stats) == "table" and Overlay.stats or {}
  return string.format(
    "Bag overlay: %s, frames hooked %d (redraw %d, open %d), ContainerFrame_Update %s, "
      .. "ContainerFrame_GenerateFrame %s, last pass %d button(s), %d badged, %d failed",
    Overlay.installed and "installed" or "not installed",
    tonumber(hooks.frames) or 0,
    tonumber(hooks.updateItems) or 0,
    tonumber(hooks.onShow) or 0,
    hooks.containerUpdate and "hooked" or "absent",
    hooks.generateFrame and "hooked" or "absent",
    tonumber(stats.buttons) or 0,
    tonumber(stats.shown) or 0,
    tonumber(stats.failed) or 0
  )
end

-- Brief BG3: how the Forever bank panel is wired, in counts only, or nil on a client with no such
-- panel (Classic Era). Overlays ready is the stock still to hand out; slots short is any bank slot
-- the stock ran out for since the last top up, which should read 0; and how long the login fill took.
function Overlay.BankLine()
  if not Overlay.HasBankPanel() then
    return nil
  end
  local line = string.format(
    "Bank panel: %s, overlays ready %d of %d made, slots short %d",
    Overlay.hooks.bankPanel and "hooked" or "not hooked",
    Overlay.StockCount(),
    tonumber(Overlay.stockMade) or 0,
    tonumber(Overlay.stockShort) or 0
  )
  -- The login fill's cost, so the owner can read it on his slower PC.
  if tonumber(Overlay.stockMs) then
    line = line .. string.format(", made at login in %.1f ms", Overlay.stockMs)
  end
  return line
end

-- Brief K7: the Keep look the bags draw with, whether the demo is on, and any look whose art the
-- client refused, so it drew as Glow. No item, character or realm fact reaches it.
function Overlay.KeepLookLine()
  local settings = (ItemTree.db and ItemTree.db.settings) or {}
  local style, rampName = Overlay.KeepLook(settings)
  local fell = {}
  for index = 1, #Overlay.KEEP_LOOKS do
    if Overlay.lookFallback[index] then
      fell[#fell + 1] = string.format("%d (%s)", index, tostring(Overlay.lookFallback[index]))
    end
  end
  return string.format(
    "Keep look: style %d (%s), ramp %s, demo %s%s, drawn as Glow instead: %s",
    style,
    Overlay.StyleName(style),
    rampName,
    type(Overlay.demo) == "table" and "on" or "off",
    Overlay.demoValue and " (value)" or "",
    #fell > 0 and table.concat(fell, ", ") or "none"
  )
end

-- That line, then whatever this module swallowed, indented under it. Every client call in this
-- file is pcall'd, so a hook the client refused would otherwise be invisible: the only symptom
-- is a bag with no badges on it.
function Overlay.DebugLines()
  local lines = { Overlay.StatusLine() }
  -- Brief BG3: the Forever bank panel's line, on a client that has the panel.
  local bankOk, bankLine = pcall(Overlay.BankLine)
  if bankOk and type(bankLine) == "string" then
    lines[#lines + 1] = bankLine
  end
  for _, problem in ipairs(Overlay.problems) do
    lines[#lines + 1] = "  " .. problem
  end
  -- The adapters line, once anything beyond the client's own bags is wired in (in the client
  -- that is always, because the generic hook is always taken).
  local ok, adapters = pcall(Overlay.AdapterLine, true)
  if ok and type(adapters) == "string" then
    lines[#lines + 1] = adapters
  end
  -- Brief K7: the Keep look line, once the demo is on or a look has fallen back.
  if type(Overlay.demo) == "table" or next(Overlay.lookFallback) ~= nil then
    lines[#lines + 1] = Overlay.KeepLookLine()
  end
  return lines
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local ok, loader = pcall(createFrame, "Frame")
  if ok and type(loader) == "table" then
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.SetScript, loader, "OnEvent", function(self)
      Overlay.Install()
      pcall(self.UnregisterEvent, self, "PLAYER_LOGIN")
    end)
  end
end

return Overlay
