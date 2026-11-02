-- The standard modified clicks on ItemTree's own item rows: the dress up click tries the item on
-- in the Dressing Room and the chat link click puts its link in the chat box, exactly as a click
-- in the player's bags does. The modifiers are the client's own bindings, read through
-- IsModifiedClick("DRESSUP") and IsModifiedClick("CHATLINK"), so control and shift out of the
-- box and whatever a player has rebound them to.
--
-- The click is handed to the client's own HandleModifiedItemClick, which is the funnel every
-- item button in the game sends a modified click through. On the `forever` branch of the
-- wow-ui-source mirror it lives in Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua: the chat
-- link half calls ChatFrameUtil.InsertLink and answers true when a chat box took the link, and
-- the dress up half answers DressUpItemLocation(nil) or DressUpLink(link), which is false for an
-- item that cannot be worn (Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua). A false answer
-- leaves the row to do what it always does, so a control click on ore still opens the ore.
--
-- The link is the full hyperlink when the client already holds the item, from ONE GetItemInfo
-- call, and the bare "item:<id>" string when it does not, which the dress up half accepts. A
-- chat box is never handed a bare string, so a chat link click on an item the client has not
-- seen does nothing. Nothing here requests an item or waits for one to load.
--
-- UI/Keybind.lua hooks the same funnel for the tree's own click to open shortcut, and sees this
-- call too. The shipped setting is a right click, so a left click here never reaches it.
--
-- Callers: the item rows of UI/Tree.lua, UI/Discoveries.lua, UI/InfoPanel.lua, UI/Frame.lua (the
-- search dropdown) and UI/Chain.lua. Each one asks ItemClick.Handle first on a LEFT click and
-- runs its own action only when Handle answers false.
--
-- Brief T7: the file also owns Ctrl + right click on a creature in the world. It is further down,
-- after the item half, under "Creature clicks". Brief T8 widened it to the whole target and focus
-- frame and gave a creature nothing is known about a page of its own.
local _, ItemTree = ...

local ItemClick = {}
ItemTree.ItemClick = ItemClick

--- What a left click with these modifiers asks for: "dressup", "chatlink" or nil for a plain
--- click. Dress up wins when both are held, which the default bindings never allow. Pure.
function ItemClick.Wanted(isDressUp, isChatLink)
  if isDressUp then
    return "dressup"
  end
  if isChatLink then
    return "chatlink"
  end
  return nil
end

-- A positive whole item id, or nil.
local itemIdOf = ItemTree.Util.PositiveId

-- Brief SV1: whether a client value may be read (Core/Util.lua Util.CanRead): a mouseover
-- creature's GUID and a frame's name can be secret in combat on the Forever client.
local canRead = ItemTree.Util.CanRead

--- The link to hand the client for an item: the cached hyperlink when there is one, else the
--- bare "item:<id>" string. nil for anything that is not an item id. Pure.
function ItemClick.Link(itemId, cachedLink)
  local id = itemIdOf(itemId)
  if not id then
    return nil
  end
  if type(cachedLink) == "string" and cachedLink:find("|Hitem:", 1, true) then
    return cachedLink
  end
  return "item:" .. id
end

--- The item id in a node key ("item:2835" -> 2835), or nil for any other kind of node, so a
--- creature, quest or spell row never reaches Handle. Pure.
function ItemClick.ItemIdOfKey(key)
  if type(key) ~= "string" then
    return nil
  end
  return itemIdOf(key:match("^item:(%d+)$"))
end

--- Brief T7: whether a click on a creature's frame asks for its page. The setting must be on, the
--- button the right one, Ctrl held and neither Alt nor Shift (Shift and Ctrl with Alt are other
--- people's shortcuts), and the unit not a player. Pure.
function ItemClick.NpcClickWanted(settingOn, button, ctrl, alt, shift, isPlayer)
  if not settingOn or button ~= "RightButton" or not ctrl or alt or shift or isPlayer then
    return false
  end
  return true
end

--- Brief T8: the unit frame a press landed on, out of the frames under the cursor. frames is the
--- client's list (GetMouseFoci), innermost first; roots maps each hooked unit frame to its unit
--- token. Each frame and up to depth of its parents is read (GetParent), so a press on the target
--- frame's portrait, health bar or mana bar, which sit three and four frames below it, finds the
--- target frame. Answers the frame and its unit, or nil. Pure over what it is handed.
function ItemClick.UnitFrameOf(frames, roots, depth)
  if type(frames) ~= "table" or type(roots) ~= "table" then
    return nil
  end
  depth = tonumber(depth) or ItemClick.PARENT_DEPTH
  for _, frame in ipairs(frames) do
    local seen = {}
    for _ = 0, depth do
      if type(frame) ~= "table" or seen[frame] then
        break
      end
      seen[frame] = true
      local unit = roots[frame]
      if unit then
        return frame, unit
      end
      if type(frame.GetParent) ~= "function" then
        break
      end
      local ok, parent = pcall(frame.GetParent, frame)
      -- Brief SV1: a parent the client keeps secret (SecretAspect Hierarchy) is never a table key.
      if not ok or not canRead(parent) then
        break
      end
      frame = parent
    end
  end
  return nil
end

-- How far up the parent chain UnitFrameOf reads. The target frame's health bar is four below it
-- (TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar), so eight is room to
-- spare and still short enough that a frame whose parent is itself cannot spin.
ItemClick.PARENT_DEPTH = 8

--- Brief T7: whether every frame under the cursor is the world itself, by name, which is where a
--- nameplate and a creature's model both sit: a nameplate takes no mouse of its own, so the client
--- reports WorldFrame over one. An empty or unknown list is not the world. Pure.
function ItemClick.OverWorld(names)
  if type(names) ~= "table" or #names == 0 then
    return false
  end
  for _, name in ipairs(names) do
    if name ~= "WorldFrame" then
      return false
    end
  end
  return true
end

--- Brief NC1: whether a press landed on the world, where the frames under the cursor (frames, with
--- their names in names) are each either WorldFrame or inside one of the nameplates plates maps to
--- its unit (frame -> unit token, as UnitFrameOf reads it). Answers true and the first plate's
--- unit (nil when every frame is WorldFrame), or false when any frame is anything else, or the
--- list is unknown (nil).
---
--- An EMPTY list is the world: on 1.60.1.70205 GetMouseFoci answers {} over a creature's body and
--- over a nameplate alike, with "mouseover" set (the owner's probe, 2026-10-04). The released
--- code read {} as "not the world" (ItemClick.OverWorld), so its world path never fired on this
--- client. Pure over what it is handed.
function ItemClick.PressOnWorld(frames, names, plates)
  if type(frames) ~= "table" or type(names) ~= "table" then
    return false
  end
  if #frames == 0 then
    return true, nil
  end
  plates = type(plates) == "table" and plates or {}
  local plateUnit = nil
  for index, frame in ipairs(frames) do
    if names[index] ~= "WorldFrame" then
      local plate, unit = ItemClick.UnitFrameOf({ frame }, plates)
      if not plate then
        return false
      end
      plateUnit = plateUnit or unit
    end
  end
  return true, plateUnit
end

--- Brief NC1: the kind a unit GUID names, its first field ("Creature", "Vehicle", "Pet",
--- "Player"), or nil. The GUID itself is never kept or printed, only this word. Pure.
function ItemClick.GuidKind(guid)
  if type(guid) ~= "string" then
    return nil
  end
  return guid:match("^([^%-]+)%-")
end

--- Brief NC1: whether the press a GLOBAL_MOUSE_DOWN carries is one the creature click wants to
--- look at at all: the right button with Ctrl held. Pure.
function ItemClick.IsNpcPress(button, ctrl)
  return button == "RightButton" and ctrl and true or false
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local function modifiedClick(name)
  local ask = rawget(_G, "IsModifiedClick")
  if type(ask) ~= "function" then
    return false
  end
  local ok, held = pcall(ask, name)
  if ok and held then
    return true
  end
  return false
end

-- The hyperlink the client already holds for the item, or nil. One call, and only ever made for
-- a click the player modified, so it is never a loop and never a query in bulk.
local function linkFrom(info, itemId)
  if type(info) ~= "function" then
    return nil
  end
  local ok, _, link = pcall(info, itemId)
  if ok and type(link) == "string" and link ~= "" then
    return link
  end
  return nil
end

-- The modern C_Item.GetItemInfo first, the global as the fallback, as UI/Client.lua does. One
-- call, or two when the first answers nothing usable.
local function cachedLink(itemId)
  local cItem = rawget(_G, "C_Item")
  if type(cItem) == "table" then
    local link = linkFrom(cItem.GetItemInfo, itemId)
    if link then
      return link
    end
  end
  return linkFrom(rawget(_G, "GetItemInfo"), itemId)
end

--- Answers a left click on an item row. Returns true when the client took the click (the item is
--- on in the Dressing Room, or its link is in the chat box), and the row must then do nothing
--- else. False for a plain click, a click the client declined, and anything that raised.
function ItemClick.Handle(itemId)
  local id = itemIdOf(itemId)
  if not id then
    return false
  end
  local wanted = ItemClick.Wanted(modifiedClick("DRESSUP"), modifiedClick("CHATLINK"))
  if not wanted then
    return false
  end
  local handler = rawget(_G, "HandleModifiedItemClick")
  if type(handler) ~= "function" then
    return false
  end
  local cached = cachedLink(id)
  if wanted == "chatlink" and not cached then
    return false
  end
  local ok, handled = pcall(handler, ItemClick.Link(id, cached))
  if ok and handled then
    return true
  end
  return false
end

--- Handle for a node key, for the surfaces that hold keys rather than ids. False for any key
--- that is not an item.
function ItemClick.HandleKey(key)
  local id = ItemClick.ItemIdOfKey(key)
  if not id then
    return false
  end
  return ItemClick.Handle(id)
end

--------------------------------------------------------------------------------
-- Creature clicks (brief T7). Ctrl + right click on the target frame, the focus frame or a
-- creature's nameplate opens that creature's ItemTree page (Core/CreatureLookup.lua picks it).
--
-- The frames are the client's, so they are only ever post hooked: HookScript("OnClick") runs our
-- function after the client's own with nothing to change, and no field is written onto a frame.
-- The client's own right click menu still opens; a post hook cannot stop it. Party and raid
-- frames are left alone, since they show players.
--
-- Brief T8, the whole unit frame. On the `forever` branch of the wow-ui-source mirror
-- (Blizzard_UnitFrame/Mainline/TargetFrame.xml, which the Camelot layer does not replace) the
-- TargetFrame and FocusFrame are SecureUnitButtons, and the portrait, the health bar and the mana
-- bar are children: TargetFrameContainer.Portrait, and TargetFrameContent.TargetFrameContentMain's
-- HealthBarsContainer.HealthBar and ManaBar. The two bars inherit TextStatusBar
-- (Blizzard_TextStatusBar/TextStatusBar.xml, enableMouseMotion for their hover text), so the
-- client names the bar, not the button, as the frame under the cursor, and the owner saw the
-- button's OnClick post hook answer only a press on the name. The press is therefore read the way
-- the world's is: GLOBAL_MOUSE_DOWN, then the frames under the cursor (GetMouseFoci) and their
-- parents, and a press anywhere inside a hooked unit frame opens that frame's unit. The bars are
-- StatusBars with no OnClick of their own, so there is nothing on them to hook and nothing is
-- turned on for them: no EnableMouse, no script set. Any child that does carry an OnClick (none
-- does on this branch) is post hooked like its parent (ItemClick.UNIT_FRAME_CHILDREN), and the
-- button's own post hook stays for a client with no GetMouseFoci. A press the down path answered
-- is not answered again by the button's post hook when the button comes up.
--
-- Nameplates. NAME_PLATE_UNIT_ADDED names each nameplate the client shows, and its UnitFrame is
-- hooked once (a weak table remembers which). On the `forever` branch of the wow-ui-source mirror,
-- though, Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua calls EnableMouse(false) on that
-- frame and the engine takes the click itself, so the hook alone would never fire. The press is
-- therefore also read from GLOBAL_MOUSE_DOWN: over the world (every frame under the cursor is
-- WorldFrame, which is what a nameplate reports) with a creature under the cursor ("mouseover"),
-- Ctrl + right click opens that creature. That covers the creature's model as well as its plate.
--
-- Brief NC1 (a player's report that the click failed now and then): a nameplate the client does
-- name as a frame under the cursor (the plate's base frame carries hit test points on this branch,
-- Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua UpdateHitTestArea, and other addons parent
-- their plates to it) counts as the world too, and its own unit is opened, so "mouseover" missing
-- or naming another creature no longer loses the press. The debounce is marked only by a press
-- that opened the window. The owner's probe can trace each press.
--
-- The setting npcClick gates the action and is read at click time; the hooks are taken once at
-- login whether it is on or off, because a post hook that decides against acting costs nothing.
--------------------------------------------------------------------------------

-- A second open of the same page this soon after the first is the same press reaching two paths.
ItemClick.NPC_DEBOUNCE = 0.3

--- Whether the setting is on. A missing value is the shipped default, which is on.
function ItemClick.NpcClickOn()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" and settings.npcClick == false then
    return false
  end
  return true
end

local function held(name)
  local down = rawget(_G, name)
  if type(down) ~= "function" then
    return false
  end
  local ok, answer = pcall(down)
  return ok and answer and true or false
end

local function now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, at = pcall(getTime)
  if ok and type(at) == "number" then
    return at
  end
  return nil
end

-- Brief NC1: the trace the owner's diagnostic probe asks for ("npcclick"). While it
-- runs, every Ctrl + right press hands the probe one record of what each step decided: the frames
-- under the cursor by name, whether "mouseover" exists, the unit's GUID kind and creature id
-- (never a GUID, never a name, and no id at all for a player), combat, the debounce, the path that
-- answered and what the lookup found. Session only; nothing is stored.
ItemClick.tracer = nil
ItemClick.traceUntil = nil

--- Starts the trace for seconds, handing each record to fn. True when it started.
function ItemClick.TraceFor(seconds, fn)
  local at = now()
  if type(fn) ~= "function" or type(seconds) ~= "number" or not at then
    return false
  end
  ItemClick.tracer, ItemClick.traceUntil = fn, at + seconds
  return true
end

--- Whether the trace is running. It stops itself once its time is up.
function ItemClick.Tracing()
  if type(ItemClick.tracer) ~= "function" then
    return false
  end
  local at = now()
  if not at or not ItemClick.traceUntil or at >= ItemClick.traceUntil then
    ItemClick.tracer, ItemClick.traceUntil = nil, nil
    return false
  end
  return true
end

local function emit(trace)
  if trace and ItemClick.Tracing() then
    pcall(ItemClick.tracer, trace)
  end
end

local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return nil
  end
  local ok, locked = pcall(lockdown)
  if not ok then
    return nil
  end
  return locked and true or false
end

-- The unit's GUID kind and creature id for the trace, read once. A player's GUID gives its kind
-- and nothing else.
local function traceUnit(trace, unit)
  if not trace then
    return
  end
  trace.unit = unit
  local guidOf = rawget(_G, "UnitGUID")
  if type(guidOf) ~= "function" or type(unit) ~= "string" then
    return
  end
  local ok, guid = pcall(guidOf, unit)
  if not ok then
    return
  end
  -- Brief SV1: the probe line says "(secret)" rather than touching a GUID it may not read.
  if not canRead(guid) then
    trace.kind = "(secret)"
    return
  end
  trace.kind = ItemClick.GuidKind(guid)
  local lookup = ItemTree.CreatureLookup
  if lookup and type(lookup.CreatureIdFromGuid) == "function" then
    trace.npcId = lookup.CreatureIdFromGuid(guid)
  end
end

--- Opens the window on the creature a unit token names: the page ItemTree's data keeps for it,
--- else (brief T8) its own page built from the unit, and nothing for a player or a pet. Only ever
--- opens, never toggles. True when it opened.
---
--- Brief NC1: the debounce is marked only by a press that opened the window, so a press that
--- failed (no page, no window, an open that raised) never makes the next one look like a repeat.
--- The window opens in combat as it does out of it (brief E91: its open makes no protected call).
function ItemClick.OpenCreature(unit, trace)
  if trace then
    trace.combat = inCombat()
  end
  local lookup = ItemTree.CreatureLookup
  if not (lookup and type(lookup.ForUnit) == "function") then
    if trace then
      trace.result = "no lookup"
    end
    return false
  end
  local ok, key = pcall(lookup.ForUnit, unit)
  if trace then
    trace.key = ok and key or nil
  end
  if not ok or not key then
    if trace then
      trace.result = ok and "no page" or "lookup raised"
    end
    return false
  end
  local at = now()
  if key == ItemClick.lastNpcKey and at and ItemClick.lastNpcAt then
    local since = at - ItemClick.lastNpcAt
    if trace then
      trace.since = since
    end
    if since >= 0 and since < ItemClick.NPC_DEBOUNCE then
      if trace then
        trace.result = "debounced"
      end
      return false
    end
  end
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if not frame or type(frame.Open) ~= "function" then
    if trace then
      trace.result = "no window"
    end
    return false
  end
  local opened, answer = pcall(frame.Open, key)
  if opened and answer then
    ItemClick.lastNpcKey, ItemClick.lastNpcAt = key, at
    if trace then
      trace.result = "opened"
    end
    return true
  end
  if trace then
    trace.result = opened and "window refused" or "window raised"
  end
  return false
end

-- The unit a hooked frame shows, read at click time since a nameplate's frame is reused for other
-- units: its "unit" attribute (the secure unit button's own), else its unit field, else the token
-- it was hooked with. Reads only.
local function unitOf(frame, fallback)
  if type(frame) == "table" then
    if type(frame.GetAttribute) == "function" then
      local ok, unit = pcall(frame.GetAttribute, frame, "unit")
      if ok and type(unit) == "string" and unit ~= "" then
        return unit
      end
    end
    local ok, unit = pcall(function()
      return frame.unit
    end)
    if ok and type(unit) == "string" and unit ~= "" then
      return unit
    end
  end
  return fallback
end

-- Brief T8: the unit frame whose press the down path answered, and when. The button's own OnClick
-- post hook fires when the same press comes up, and stands down for it. A press held longer than
-- this is a new one as far as the hook can tell.
ItemClick.PRESS_WINDOW = 2

local function answeredOnDown(frame)
  local pressed = ItemClick.pressedFrame
  if pressed == nil or pressed ~= frame then
    return false
  end
  ItemClick.pressedFrame = nil
  local at, since = now(), nil
  if at and ItemClick.pressedAt then
    since = at - ItemClick.pressedAt
  end
  return since == nil or (since >= 0 and since < ItemClick.PRESS_WINDOW)
end

-- Brief NC1: when the world path opened a creature on the press, and the nameplate's own OnClick
-- post hook, which the client fires on the same press coming up (the plate's UnitFrame registers
-- RightButtonUp, Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua on the forever branch),
-- stands down for it. A target or focus frame is never a plate, so it keeps its own rule above.
local function answeredInWorld(frame)
  if ItemClick.unitRoots[frame] or (ItemClick.rootOf and ItemClick.rootOf[frame]) then
    return false
  end
  local pressedAt = ItemClick.worldPressedAt
  if pressedAt == nil then
    return false
  end
  ItemClick.worldPressedAt = nil
  local at = now()
  if not at or type(pressedAt) ~= "number" then
    return true
  end
  local since = at - pressedAt
  return since >= 0 and since < ItemClick.PRESS_WINDOW
end

--- What the post hook runs. True when the window opened.
function ItemClick.OnUnitFrameClick(frame, button, fallbackUnit)
  if not ItemClick.NpcClickOn() then
    return false
  end
  if answeredOnDown(frame) or answeredOnDown(ItemClick.rootOf and ItemClick.rootOf[frame]) then
    return false
  end
  if answeredInWorld(frame) then
    if ItemClick.Tracing() then
      emit({ path = "frame hook", result = "answered on the press" })
    end
    return false
  end
  local unit = unitOf(frame, fallbackUnit)
  local lookup = ItemTree.CreatureLookup
  local isPlayer = lookup and type(lookup.IsPlayer) == "function" and lookup.IsPlayer(unit)
  local wanted = ItemClick.NpcClickWanted(
    true,
    button,
    held("IsControlKeyDown"),
    held("IsAltKeyDown"),
    held("IsShiftKeyDown"),
    isPlayer
  )
  if not wanted then
    return false
  end
  local trace = ItemClick.Tracing() and { path = "frame hook" } or nil
  traceUnit(trace, unit)
  local answer = ItemClick.OpenCreature(unit, trace)
  emit(trace)
  return answer
end

-- The frames already hooked. Weak keys, so a frame the client lets go is not held here.
ItemClick.hookedFrames = setmetatable({}, { __mode = "k" })

-- Brief T8: the unit frames a press inside answers, frame -> unit token ("target", "focus"), and
-- each hooked child's unit frame. Our own tables keyed by the client's frames; nothing is written
-- onto a frame. Weak keys, as above.
ItemClick.unitRoots = setmetatable({}, { __mode = "k" })
ItemClick.rootOf = setmetatable({}, { __mode = "k" })

-- Brief T8: the children of a TargetFrameTemplate button, by their parentKey path on the `forever`
-- branch (Blizzard_UnitFrame/Mainline/TargetFrame.xml): the portrait's container, the health bar
-- and the mana bar. Read, never written; each is post hooked only where it has an OnClick.
ItemClick.UNIT_FRAME_CHILDREN = {
  { "TargetFrameContainer" },
  { "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar" },
  { "TargetFrameContent", "TargetFrameContentMain", "ManaBar" },
}

-- One child of a client frame by its parentKey path, a read per step, or nil.
local function childAt(frame, path)
  for _, key in ipairs(path) do
    if type(frame) ~= "table" then
      return nil
    end
    local ok, child = pcall(function()
      return frame[key]
    end)
    if not ok then
      return nil
    end
    frame = child
  end
  if type(frame) ~= "table" then
    return nil
  end
  return frame
end

--- Brief G1: runs one of our click bodies under Core/Guard.lua's boundary. An error leaves our
--- part of the click undone (the client's own click has already run, a post hook comes after it)
--- and is recorded and handed to the client's error handler, rather than swallowed by a bare
--- pcall. Answers ok and the body's answers.
function ItemClick.Guarded(where, fn, ...)
  local Guard = ItemTree.Guard
  if type(Guard) == "table" and type(Guard.Run) == "function" then
    return Guard.Run(where, fn, ...)
  end
  return true, fn(...)
end

--- Post hooks one of the client's unit frames, once. True when it is hooked, now or before.
function ItemClick.HookUnitFrame(frame, fallbackUnit)
  if type(frame) ~= "table" then
    return false
  end
  if ItemClick.hookedFrames[frame] then
    return true
  end
  if type(frame.HasScript) ~= "function" or type(frame.HookScript) ~= "function" then
    return false
  end
  local hasOk, has = pcall(frame.HasScript, frame, "OnClick")
  if not hasOk or not has then
    return false
  end
  local ok = pcall(frame.HookScript, frame, "OnClick", function(self, button)
    ItemClick.Guarded("ItemClick.OnUnitFrameClick", ItemClick.OnUnitFrameClick, self, button, fallbackUnit)
  end)
  if not ok then
    return false
  end
  ItemClick.hookedFrames[frame] = true
  return true
end

--- Brief T8: takes a client unit frame whole: the frame is remembered as the root a press inside
--- it answers (ItemClick.UnitFrameOf), its own OnClick is post hooked, and so is each child in
--- UNIT_FRAME_CHILDREN that carries an OnClick. True when the frame is remembered.
function ItemClick.HookWholeUnitFrame(frame, unit)
  if type(frame) ~= "table" or type(unit) ~= "string" then
    return false
  end
  ItemClick.unitRoots[frame] = unit
  ItemClick.HookUnitFrame(frame, unit)
  for _, path in ipairs(ItemClick.UNIT_FRAME_CHILDREN) do
    local child = childAt(frame, path)
    if child and ItemClick.HookUnitFrame(child, unit) then
      ItemClick.rootOf[child] = frame
    end
  end
  return true
end

--- A nameplate the client has just shown: hook its unit frame, once per frame.
function ItemClick.OnNamePlateAdded(unit)
  local namePlates = rawget(_G, "C_NamePlate")
  local getPlate = type(namePlates) == "table" and namePlates.GetNamePlateForUnit or nil
  if type(getPlate) ~= "function" or type(unit) ~= "string" then
    return false
  end
  local ok, plate = pcall(getPlate, unit)
  if not ok or type(plate) ~= "table" then
    return false
  end
  local readOk, unitFrame = pcall(function()
    return plate.UnitFrame
  end)
  if not readOk or type(unitFrame) ~= "table" then
    return false
  end
  return ItemClick.HookUnitFrame(unitFrame, nil)
end

-- The frames under the cursor, or nil when the client will not say.
local function focusFrames()
  local foci = rawget(_G, "GetMouseFoci")
  local frames
  if type(foci) == "function" then
    local ok, list = pcall(foci)
    if ok and type(list) == "table" then
      frames = list
    end
  end
  if not frames then
    local focus = rawget(_G, "GetMouseFocus")
    if type(focus) == "function" then
      local ok, frame = pcall(focus)
      if ok and type(frame) == "table" then
        frames = { frame }
      end
    end
  end
  return frames
end

-- The names of the frames under the cursor, or nil when the client will not say.
local function focusNames(frames)
  if not frames then
    return nil
  end
  local names = {}
  for _, frame in ipairs(frames) do
    local name = nil
    if type(frame) == "table" and type(frame.GetName) == "function" then
      local ok, named = pcall(frame.GetName, frame)
      -- Brief SV1: a frame whose name the client keeps secret (SecretAspect ObjectName) is named
      -- "(secret)", which matches no frame name a rule looks for.
      if ok and not canRead(named) then
        name = "(secret)"
      elseif ok and type(named) == "string" then
        name = named
      end
    end
    names[#names + 1] = name or ""
  end
  return names
end

--- Brief T8: a Ctrl + right press inside the target or focus frame, anywhere on it: the portrait,
--- the bars, the name. Opens that frame's unit and tells the button's post hook to stand down for
--- the same press. True when the window opened.
function ItemClick.OnUnitFramePress(button, frames, trace)
  local root, unit = ItemClick.UnitFrameOf(frames, ItemClick.unitRoots)
  if not root then
    return false
  end
  local readUnit = unitOf(root, unit)
  traceUnit(trace, readUnit)
  local lookup = ItemTree.CreatureLookup
  local isPlayer = lookup and type(lookup.IsPlayer) == "function" and lookup.IsPlayer(readUnit)
  if not ItemClick.NpcClickWanted(true, button, true, held("IsAltKeyDown"), held("IsShiftKeyDown"), isPlayer) then
    if trace then
      trace.result = isPlayer and "a player" or "other modifiers held"
    end
    return false
  end
  ItemClick.pressedFrame, ItemClick.pressedAt = root, now()
  return ItemClick.OpenCreature(readUnit, trace)
end

-- Brief NC1: the nameplates the client is showing, each plate frame and its UnitFrame mapped to
-- the unit token the plate shows, read at press time because the client reuses its plates. Reads
-- only: C_NamePlate.GetNamePlates is the client's own list of the plates on screen, a handful,
-- and asks the server nothing. nil with no client.
local function plateRoots()
  local namePlates = rawget(_G, "C_NamePlate")
  local getAll = type(namePlates) == "table" and namePlates.GetNamePlates or nil
  if type(getAll) ~= "function" then
    return nil
  end
  local ok, plates = pcall(getAll)
  if not ok or type(plates) ~= "table" then
    return nil
  end
  local roots = {}
  for _, plate in ipairs(plates) do
    if type(plate) == "table" then
      local readOk, unitFrame, token = pcall(function()
        return plate.UnitFrame, plate.namePlateUnitToken
      end)
      if readOk then
        local unit = unitOf(unitFrame, nil)
        if not unit and type(token) == "string" and token ~= "" then
          unit = token
        end
        if unit then
          roots[plate] = unit
          if type(unitFrame) == "table" then
            roots[unitFrame] = unit
          end
        end
      end
    end
  end
  return roots
end

local function unitThere(unit)
  local exists = rawget(_G, "UnitExists")
  if type(exists) ~= "function" then
    return false
  end
  local ok, there = pcall(exists, unit)
  return ok and there and true or false
end

-- The press itself, for OnWorldMouseDown. trace is the probe's record or nil.
local function worldPress(button, trace)
  if not ItemClick.NpcClickOn() then
    if trace then
      trace.path = "setting off"
    end
    return false
  end
  local frames = focusFrames()
  local names = focusNames(frames)
  if trace then
    trace.frames = names
  end
  if frames and ItemClick.UnitFrameOf(frames, ItemClick.unitRoots) then
    if trace then
      trace.path = "unit frame"
    end
    return ItemClick.OnUnitFramePress(button, frames, trace)
  end
  -- Brief NC1: a nameplate the client names as a frame under the cursor counts as the world,
  -- and its unit is the one the player pressed on, whatever "mouseover" says.
  local plates = nil
  if frames and not ItemClick.OverWorld(names) then
    plates = plateRoots()
  end
  local onWorld, plateUnit = ItemClick.PressOnWorld(frames, names, plates)
  local mouseover = unitThere("mouseover")
  if trace then
    trace.mouseover = mouseover
  end
  if not onWorld then
    if trace then
      trace.path = "over a frame"
    end
    return false
  end
  local unit = plateUnit
  if not unit and mouseover then
    unit = "mouseover"
  end
  if trace then
    trace.path = plateUnit and "nameplate" or "world"
  end
  if not unit then
    if trace then
      trace.result = "no unit under the cursor"
    end
    return false
  end
  traceUnit(trace, unit)
  local lookup = ItemTree.CreatureLookup
  local isPlayer = lookup and type(lookup.IsPlayer) == "function" and lookup.IsPlayer(unit)
  if not ItemClick.NpcClickWanted(true, button, true, held("IsAltKeyDown"), held("IsShiftKeyDown"), isPlayer) then
    if trace then
      trace.result = isPlayer and "a player" or "other modifiers held"
    end
    return false
  end
  local opened = ItemClick.OpenCreature(unit, trace)
  if opened then
    ItemClick.worldPressedAt = now() or false
  end
  return opened
end

--- A mouse press anywhere: Ctrl + right click over the world on a creature (its nameplate or its
--- model) opens its page, and (brief T8) so does one anywhere inside the target or focus frame.
--- Brief NC1: a nameplate the client reports under the cursor counts as the world, and while the
--- probe's trace runs every Ctrl + right press hands it a record.
function ItemClick.OnWorldMouseDown(button)
  if not ItemClick.IsNpcPress(button, held("IsControlKeyDown")) then
    return false
  end
  local trace = ItemClick.Tracing() and {} or nil
  local answer = worldPress(button, trace)
  emit(trace)
  return answer
end

--- Takes the hooks, once: the target and focus frames, every nameplate already shown, and the
--- event frame's nameplate and mouse events. Idempotent.
function ItemClick.InstallNpcClick()
  ItemClick.HookWholeUnitFrame(rawget(_G, "TargetFrame"), "target")
  ItemClick.HookWholeUnitFrame(rawget(_G, "FocusFrame"), "focus")
  local namePlates = rawget(_G, "C_NamePlate")
  local getAll = type(namePlates) == "table" and namePlates.GetNamePlates or nil
  if type(getAll) == "function" then
    local ok, plates = pcall(getAll)
    if ok and type(plates) == "table" then
      for _, plate in ipairs(plates) do
        local readOk, unitFrame = pcall(function()
          return plate.UnitFrame
        end)
        if readOk then
          ItemClick.HookUnitFrame(unitFrame, nil)
        end
      end
    end
  end
  local frame = ItemClick.eventFrame
  if not ItemClick.npcEventsWatched and type(frame) == "table" and type(frame.RegisterEvent) == "function" then
    pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
    pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
    ItemClick.npcEventsWatched = true
  end
  return true
end

--- What the event frame runs, named so a spec drives it with a fake frame.
function ItemClick.OnEvent(_, event, arg1)
  if event == "NAME_PLATE_UNIT_ADDED" then
    ItemClick.Guarded("ItemClick.OnNamePlateAdded", ItemClick.OnNamePlateAdded, arg1)
    return
  end
  if event == "GLOBAL_MOUSE_DOWN" then
    ItemClick.Guarded("ItemClick.OnWorldMouseDown", ItemClick.OnWorldMouseDown, arg1)
    return
  end
  if event == "PLAYER_LOGIN" then
    ItemClick.Guarded("ItemClick.InstallNpcClick", ItemClick.InstallNpcClick)
  end
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local ok, loader = pcall(createFrame, "Frame")
  if ok and type(loader) == "table" then
    ItemClick.eventFrame = loader
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.SetScript, loader, "OnEvent", ItemClick.OnEvent)
  end
end
