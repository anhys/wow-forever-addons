-- Key binding: open the tree for the item under the cursor, or (brief T7) the creature whose
-- tooltip is showing when no item is, or (brief QK1) the quest the player is reading in one of the
-- client's quest panes when neither is. See Keybind.ShownQuests.
--
-- A modifier click was the first idea, but a modifier click cannot cancel the client's own
-- bag pickup, so the addon takes a key binding instead. The key acts on whatever the cursor
-- is over: the item the game tooltip is showing, or the one in an open item link tooltip.
--
-- Bindings.xml at the addon root declares the binding and calls the global
-- ItemTree_OpenHovered defined at the foot of this file. The client discovers Bindings.xml
-- from the addon folder on its own, so it is deliberately not listed in ItemTree.toc, and it
-- names no default key: a default attribute there is applied before anything can be checked
-- and would stomp a binding the player already uses. Keybind.ApplyDefault offers a default
-- at login instead, once per character and only for a key that runs nothing at all.
--
-- Keybind.Set, Keybind.Clear and Keybind.ApplyDefault are the only things here that write a
-- binding, and each one saves the binding set afterwards. The settings panel control in
-- UI/Options.lua goes through them rather than calling SetBinding itself.
--
-- The Key Bindings panel reads these globals for its labels, all set below:
--   BINDING_HEADER_ITEMTREE          the section heading
--   BINDING_NAME_ITEMTREE_OPEN       the row label
--   BINDING_NAME_ITEMTREE_BOSSLOOT   the second row (brief B1)
--
-- Brief B1: a second binding, ITEMTREE_BOSSLOOT, opens the window straight on the Boss loot tab
-- (Keybind.OpenBossLoot). It is never bound by default: ApplyDefault offers a key to the first
-- binding only. Keybind.KeyText, Keybind.Set and Keybind.Clear take the binding action as an
-- optional argument, which is the first binding when it is left out.
--
-- Brief ST1 (QA item 285): each action holds two keys, the way the game's Key Bindings panel
-- shows them (Key 1 and Key 2), so a player can set a keyboard key and a gamepad button side by
-- side. KeyText, Set and Clear take the slot (1 or 2) after the action; Set keeps the other
-- slot's key and the order the client lists them in, as the panel's own listener does
-- (KeybindListener:RebindKeysInOrder, Blizzard_Settings_Shared/Blizzard_Keybindings.lua:176,
-- branch forever, 1.60.1.70450). Keybind.SlotKeys says which keys end up bound, pure.
--
-- The file also owns click to open: a modified mouse click on an item, which is the shortcut
-- most players find first. It listens for the press itself through GLOBAL_MOUSE_DOWN, so it
-- works wherever the key works, and keeps a hook on the client's own modified click funnel as
-- the fallback. Brief LC1-full adds a hook on SetItemRef for chat links and a hover memory for
-- the chat link under the cursor. See Keybind.InstallClickOpen.
--
-- Keybind.ItemIdFromTooltips, Keybind.ClickDecision, Keybind.ClickLabel,
-- Keybind.ShouldSkipFocus and Keybind.IsRepeatClick are pure and take their inputs as
-- arguments, so specs pass stubs. Everything below the divider is guarded, so this file loads
-- with no WoW API.
local _, ItemTree = ...

local Keybind = {}

-- Brief SV1: whether a client value may be read (Core/Util.lua Util.CanRead). The hovered unit's
-- name and a frame's name, parent and protected flag can each be secret on the Forever client.
local canRead = ItemTree.Util.CanRead
-- A positive whole id, or nil (Core/Util.lua Util.PositiveId).
local positiveId = ItemTree.Util.PositiveId
ItemTree.Keybind = Keybind

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- The binding action name. Bindings.xml and the BINDING_NAME_ global both spell it out.
Keybind.BINDING = "ITEMTREE_OPEN"

-- Brief B1: the binding that opens the Boss loot tab. Unbound by default, set under Settings.
Keybind.BOSS_BINDING = "ITEMTREE_BOSSLOOT"

-- The binding action a caller named, or the first binding. Only the two ItemTree actions are
-- taken, so a stray argument can never write somebody else's binding. Pure.
function Keybind.Action(action)
  if action == Keybind.BOSS_BINDING then
    return Keybind.BOSS_BINDING
  end
  return Keybind.BINDING
end

-- The keys ItemTree will take as a default, in order of preference. Nothing is bound from
-- Bindings.xml, because a default attribute there would stomp a key the player already uses.
-- ApplyDefault walks this list at login instead and only takes a key that runs nothing.
Keybind.DEFAULT_KEYS = { "ALT-I", "SHIFT-I", "ALT-T", "SHIFT-T" }

-- Keys that are only a modifier. Holding Shift is not a binding, so a capture waits for the
-- real key rather than treating the modifier itself as one.
local MODIFIER_KEYS = {
  LSHIFT = true,
  RSHIFT = true,
  SHIFT = true,
  LCTRL = true,
  RCTRL = true,
  CTRL = true,
  LALT = true,
  RALT = true,
  ALT = true,
  LMETA = true,
  RMETA = true,
  META = true,
  UNKNOWN = true,
}

-- Builds the binding string the client uses, for example "ALT-CTRL-SHIFT-I". Returns nil for no
-- key at all and for a key that is only a modifier, so a capture can simply keep waiting. Pure.
-- Brief JK2 (QA item 308, the owner: "I can't seem to set CMD hotkey anymore"): every modifier the
-- game's own Key Bindings panel takes, META (Cmd on a Mac) too, named and ordered as the panel
-- builds its chord: ALT, CTRL, SHIFT, META, then the key (CreateKeyChordStringUsingMetaKeyState,
-- Blizzard_SharedXML/BindingUtil.lua:116 to 140, the order its KeyComparator sorts by at :5 to 19
-- and :94 to 102; the panel's listener calls it at Blizzard_Settings_Shared/Blizzard_Keybindings.lua
-- :108; branch forever, 1.60.1.70450). meta is the fifth argument so every older caller still reads
-- the same.
function Keybind.BindingString(key, ctrl, alt, shift, meta)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  key = key:upper()
  if MODIFIER_KEYS[key] then
    return nil
  end
  local prefix = ""
  if alt then
    prefix = prefix .. "ALT-"
  end
  if ctrl then
    prefix = prefix .. "CTRL-"
  end
  if shift then
    prefix = prefix .. "SHIFT-"
  end
  if meta then
    prefix = prefix .. "META-"
  end
  return prefix .. key
end

-- What a captured key press means, as one of four words:
--   "ignore"  nothing or a bare modifier, keep capturing
--   "cancel"  unmodified Escape, leave the binding as it was
--   "clear"   unmodified Backspace or Delete, unbind
--   "bind"    plus the binding string to set
-- Modified Escape, Backspace and Delete are ordinary keys and bind, which is what the Key
-- Bindings panel does too. Pure, so the capture rules are specced with no client present.
-- Brief ST1: a gamepad button arrives here too, by its key name ("PAD1", "PADDUP"). padHeld is
-- an optional set of the button names the player's gamepad uses as Shift, Ctrl or Alt
-- (Keybind.PadModifiers): pressing one alone is a modifier, so the capture keeps waiting for
-- the button it modifies.
-- Brief JK2: meta (Cmd on a Mac) is a modifier like the other three (Keybind.BindingString).
function Keybind.CaptureDecision(key, ctrl, alt, shift, padHeld, meta)
  local binding = Keybind.BindingString(key, ctrl, alt, shift, meta)
  if not binding then
    return "ignore"
  end
  if type(padHeld) == "table" and padHeld[key:upper()] then
    return "ignore"
  end
  if not (ctrl or alt or shift or meta) then
    local bare = key:upper()
    if bare == "ESCAPE" then
      return "cancel"
    end
    if bare == "BACKSPACE" or bare == "DELETE" then
      return "clear"
    end
  end
  return "bind", binding
end

-- Brief ST1: the two key slots an action shows, Key 1 and Key 2. Anything but 2 is the first.
-- Pure.
function Keybind.Slot(slot)
  if slot == 2 then
    return 2
  end
  return 1
end

-- Brief ST1: the keys an action holds after newKey goes into one slot, in the order they are
-- bound. key1 and key2 are what GetBindingKey answers today. The slot's old key goes; the other
-- slot keeps its key unless it is the new key itself. The client lists an action's keys in the
-- order they were bound, so a Key 2 set while Key 1 is empty becomes Key 1, as it does in the
-- game's own Key Bindings panel. Pure.
function Keybind.SlotKeys(key1, key2, slot, newKey)
  local keys = { key1, key2 }
  if type(newKey) ~= "string" or newKey == "" then
    newKey = nil
  end
  keys[Keybind.Slot(slot)] = newKey
  local out, seen = {}, {}
  for index = 1, 2 do
    local key = keys[index]
    if type(key) == "string" and key ~= "" and not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  return out
end

-- Picks the default key. candidates is an ordered list, isBound() says whether the player
-- already has a key on the binding, and isFree(key) says whether the key runs nothing at
-- all. Returns the first free candidate, or nil when the binding is already bound or every
-- candidate is taken. Pure: ApplyDefault supplies the two client backed predicates.
function Keybind.ChooseDefault(candidates, isBound, isFree)
  if type(isBound) == "function" and isBound() then
    return nil
  end
  if type(isFree) ~= "function" then
    return nil
  end
  for _, key in ipairs(candidates or {}) do
    if isFree(key) then
      return key
    end
  end
  return nil
end

-- Click to open. The key binding acts on the item under the cursor, which the owner found
-- hard to discover, so a modified mouse click is the default way in and the key stays as
-- well. A stored value is the modifier and the button spelled the way a client binding string
-- is, so it reads on its own in the report, and "OFF" turns the shortcut off.
Keybind.CLICK_OFF = "OFF"

-- Ordered for the settings dropdown. Ctrl and left click is the game's own dress up shortcut,
-- which is why it is offered but is not the default: taking it opens the dressing room beside
-- the tree. The labels are English here and the row draws L of them.
Keybind.CLICK_OPTIONS = {
  { value = "CTRL-RIGHT", label = "Ctrl + right click" },
  { value = "CTRL-LEFT", label = "Ctrl + left click" },
  { value = "ALT-RIGHT", label = "Alt + right click" },
  { value = "ALT-LEFT", label = "Alt + left click" },
  { value = Keybind.CLICK_OFF, label = "Off" },
}

-- The button name the client reports for each half of an option.
local CLICK_BUTTONS = { LEFT = "LeftButton", RIGHT = "RightButton" }

-- The readable words for a stored value, or nil for "off" and for anything this build does
-- not know. Pure.
function Keybind.ClickLabel(value)
  for _, option in ipairs(Keybind.CLICK_OPTIONS) do
    if option.value == value then
      if option.value == Keybind.CLICK_OFF then
        return nil
      end
      return option.label
    end
  end
  return nil
end

-- Whether a modified click is the one the player asked for.
--   setting  a value from CLICK_OPTIONS; "OFF", nil and anything unknown never match
--   button   what the client says was clicked, "LeftButton" or "RightButton", nil when it
--            will not say, which is never a match: a client that cannot name the button must
--            not have a Ctrl and left click dress up counted as a Ctrl and right click
--   ctrl, alt, shift  the modifier state at the click
-- The modifier state has to match exactly. Shift is the client's own chat link modifier and
-- Ctrl with Alt is nobody's shortcut, so only the one named modifier may be held. Pure.
function Keybind.ClickDecision(setting, button, ctrl, alt, shift)
  if type(setting) ~= "string" then
    return false
  end
  local wantModifier, wantButton = setting:match("^(%u+)%-(%u+)$")
  if not wantModifier or CLICK_BUTTONS[wantButton] ~= button then
    return false
  end
  if shift then
    return false
  end
  local ctrlDown = ctrl and true or false
  local altDown = alt and true or false
  if wantModifier == "CTRL" then
    return ctrlDown and not altDown
  end
  if wantModifier == "ALT" then
    return altDown and not ctrlDown
  end
  return false
end

-- How long a second open of the same item is treated as the same click, in seconds. The two
-- click paths can both fire for one press: the mouse event on the way down and the client's
-- own modified click funnel on the way up. Opening is idempotent, so this is belt and braces.
Keybind.CLICK_DEBOUNCE = 0.3

-- Frames a click must never open the tree over. Each rule is a Lua pattern matched against
-- the name of the frame under the cursor and against every name in its parent chain, so an
-- unnamed row inside a named window is caught by the window.
--
-- We cannot cancel the click itself, only decide whether to answer it, so the rules are about
-- what the click already does underneath. A rule marked modifiedOpens holds only for a press
-- with no modifier: its frame does something of its own on a plain click and nothing but the
-- modified click funnel on a modified one. The mouse path only ever answers a modified press
-- (ClickDecision wants Ctrl or Alt), so such a rule is the guard that says why it may.
--   ItemTree   our own window. Its rows raise real item tooltips and re-root the tree on a
--              click of their own, so a second opener fighting them is pure surprise.
--   LootFrame  the loot window (brief LC1-full). Read on 1.60.1.70205 (wow-ui-source forever,
--              e3ecc27): the window is LootFrame (Blizzard_UIPanels_Game/Mainline/LootFrame.xml
--              line 116) and its rows are unnamed. Each row's Item button registers BOTH buttons
--              (LootFrame.xml line 9, registerForClicks="LeftButtonUp, RightButtonUp"), and its
--              OnClick hands every IsModifiedClick() press to HandleModifiedItemClick and loots
--              only an unmodified one (Mainline/LootFrame.lua lines 67 to 88). So a Ctrl + right
--              click there never loots: the mouse path opens on it, and so does the funnel.
--   LootButton the older Classic loot slots, LootButton1 to LootButton4 under the same window,
--              whose LootButton_OnClick has the same IsModifiedClick split. Not on the beta's
--              Mainline files; kept for the older shape, same guard.
--   Loot       any other frame with Loot in its name: another addon's loot window, whose click we
--              have not read, and the beta's WorldLootObjectList, whose rows send every press to
--              a widget (Blizzard_WorldLootObjectList.lua line 52, OnMouseDown) whose handler is
--              not in the mirror. Always skipped, except the names listed against it: the two
--              loot slot rules above, which carry their own guard, and the roll windows below.
--   action     a right click on an action button casts the thing on it. Action buttons are
--              protected as well, which is the rule below, but a name costs nothing to read.
-- The need and greed roll windows are excepted from the Loot rule (brief LC1): their item icon
-- does nothing on a right click. On 70205 the roll frame is GroupLootFrame1 to 4 inside
-- GroupLootContainer (Mainline/GroupLootFrame.xml lines 632 to 644, GamepadGroupLootRollFrame at
-- line 599 in gamepad mode), and its IconFrame (line 319) registers no clicks, so its OnClick
-- (lines 365 to 367, HandleModifiedItemClick) answers the left button only.
local LOOT_SLOT_NAMES = { "^LootFrame", "^LootButton%d" }
local ROLL_WINDOW_NAMES = { "^GroupLootFrame%d", "^GroupLootContainer", "^GamepadGroupLootRollFrame" }
local LOOT_EXCEPTIONS = {}
for _, list in ipairs({ LOOT_SLOT_NAMES, ROLL_WINDOW_NAMES }) do
  for _, pattern in ipairs(list) do
    LOOT_EXCEPTIONS[#LOOT_EXCEPTIONS + 1] = pattern
  end
end

local FOCUS_SKIP_RULES = {
  { pattern = "^ItemTree", reason = "itemtree" },
  { pattern = LOOT_SLOT_NAMES[1], reason = "loot", modifiedOpens = true },
  { pattern = LOOT_SLOT_NAMES[2], reason = "loot", modifiedOpens = true },
  { pattern = "Loot", reason = "loot", except = LOOT_EXCEPTIONS },
  { pattern = "ActionButton", reason = "action" },
  { pattern = "ActionBar", reason = "action" },
  { pattern = "^MultiBar", reason = "action" },
  { pattern = "^StanceButton", reason = "action" },
  { pattern = "^PossessButton", reason = "action" },
}

-- Whether a rule's own exception list takes this name out of it.
local function excepted(rule, name)
  for _, pattern in ipairs(rule.except or {}) do
    if name:find(pattern) then
      return true
    end
  end
  return false
end

-- Whether a click over this frame must be left alone, plus the word for why. The argument is
-- a plain description of what is under the cursor, which is all the rule needs:
--   name      the frame's own name, or nil for an unnamed frame
--   parents   the names above it, and the names of any other frames under the cursor
--   protected true when the client says the frame is protected, which every action bar
--             button and every secure template is
-- modified is true when the press holds Ctrl, Alt or Shift: a rule marked modifiedOpens (the
-- loot slots) is then lifted, because the frame's own click does nothing but the funnel. Left
-- out, it counts as a plain press, the safe way round.
-- Nothing known means nothing to skip: a client that will not say what is under the cursor
-- still opens the tree, because the click's own effect is the client's either way. Pure.
function Keybind.ShouldSkipFocus(focus, modified)
  if type(focus) ~= "table" then
    return false
  end
  if focus.protected then
    return true, "protected"
  end
  local names = {}
  if type(focus.name) == "string" then
    names[#names + 1] = focus.name
  end
  if type(focus.parents) == "table" then
    for _, name in ipairs(focus.parents) do
      if type(name) == "string" then
        names[#names + 1] = name
      end
    end
  end
  for _, rule in ipairs(FOCUS_SKIP_RULES) do
    if not (rule.modifiedOpens and modified) then
      for _, name in ipairs(names) do
        if name:find(rule.pattern) and not excepted(rule, name) then
          return true, rule.reason
        end
      end
    end
  end
  return false
end

-- Whether this open repeats the one just made, so the second path to fire for a single press
-- does nothing. Only the same item counts: clicking one item and then another is two opens
-- however fast the player is. A clock that has gone backwards, which is what a reload looks
-- like, is treated as a fresh click rather than as a repeat. Pure: the caller supplies the
-- clock, so a spec drives it. Pure.
function Keybind.IsRepeatClick(itemId, now, lastItemId, lastAt)
  if itemId == nil or lastItemId == nil or itemId ~= lastItemId then
    return false
  end
  local at, previous = tonumber(now), tonumber(lastAt)
  if not at or not previous then
    return false
  end
  local since = at - previous
  if since < 0 then
    return false
  end
  return since < Keybind.CLICK_DEBOUNCE
end

-- A frame with no IsShown counts as shown, so a spec stub needs only GetItem.
local function isShown(frame)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.IsShown) ~= "function" then
    return true
  end
  local ok, visible = pcall(frame.IsShown, frame)
  return ok and visible and true or false
end

-- GetItem returns name, link. Both the call and the parse are guarded: a frame that is not
-- really a tooltip, or a link that is not an item, simply yields nothing.
local function itemIdFrom(frame)
  if not isShown(frame) or type(frame.GetItem) ~= "function" then
    return nil
  end
  local ok, _, link = pcall(frame.GetItem, frame)
  if not ok or not link then
    return nil
  end
  local tooltip = ItemTree.Tooltip
  if not tooltip or type(tooltip.ItemIdFromLink) ~= "function" then
    return nil
  end
  return tooltip.ItemIdFromLink(link)
end

-- The item id under the cursor, in this order: the game tooltip; then (brief LC1-full)
-- hoveredLinkId, the item of the chat link the cursor rests on, which shows no tooltip of its
-- own; then an open item link tooltip, which is what a linked item clicked in chat leaves on
-- screen. The hovered link comes before the item link tooltip because that window can stay up
-- from an earlier click while the cursor is on another link: the thing under the cursor wins.
function Keybind.ItemIdFromTooltips(gameTooltip, itemRefTooltip, hoveredLinkId)
  local id = itemIdFrom(gameTooltip)
  if id then
    return id
  end
  if type(hoveredLinkId) == "number" then
    return hoveredLinkId
  end
  return itemIdFrom(itemRefTooltip)
end

-- Brief LC1-full: the item id in a chat hyperlink, or nil for any other kind of link. The chat
-- frame hands its hyperlink scripts and SetItemRef the link's payload, "item:<id>:...", and a
-- full "|Hitem:...|h[...]|h" hyperlink is taken too. Keystone, quest, achievement, player and
-- every other kind are left alone: only the item kind counts, however the payload reads after
-- it. The id itself is read by Tooltip.ItemIdFromLink, the one link reader. Pure.
function Keybind.LinkItemId(link)
  -- Brief SV1: a chat line's payload can be secret (SecretInChatMessagingLockdown), and so its link.
  if not canRead(link) or type(link) ~= "string" then
    return nil
  end
  if not (link:find("^item:") or link:find("|Hitem:")) then
    return nil
  end
  local tooltip = ItemTree.Tooltip
  if not tooltip or type(tooltip.ItemIdFromLink) ~= "function" then
    return nil
  end
  local ok, id = pcall(tooltip.ItemIdFromLink, link)
  if ok and type(id) == "number" then
    return id
  end
  return nil
end

-- Brief LC1-full: the /itemtree debug line that says which click to open paths installed:
--   click open: mouse <on|off>, funnel <on|off>, links <on|off>, hover link <id|none>
-- mouse is the GLOBAL_MOUSE_DOWN path, funnel the HandleModifiedItemClick hook, links the
-- SetItemRef hook, and hover link the item of the chat link under the cursor right now (an item
-- id, never a link or a name). state holds the four facts. Pure.
function Keybind.ClickOpenLine(state)
  state = type(state) == "table" and state or {}
  local function onOff(value)
    if value then
      return "on"
    end
    return "off"
  end
  local hover = type(state.hoverLink) == "number" and tostring(state.hoverLink) or "none"
  return string.format(
    "click open: mouse %s, funnel %s, links %s, hover link %s",
    onOff(state.mouse),
    onOff(state.funnel),
    onOff(state.links),
    hover
  )
end

-- Brief QK1 (the owner's QA item 387 and his ruling 387b, 2026-10-23): the quest the key opens when
-- no item and no creature is under the cursor. shown lists the client's quest panes that are up,
-- each { surface = its name, questId = the quest it shows, hovered = true when the cursor is over
-- it }, in Keybind.ShownQuests' order. The pane under the cursor wins, else the first pane with a
-- quest. A pane whose quest is not a positive whole number (GetQuestID answers 0 on the giver's
-- greeting list) is passed over. Answers the quest id and the pane's name, or nil. Pure.
function Keybind.PickShownQuest(shown)
  if type(shown) ~= "table" then
    return nil
  end
  local firstId, firstSurface = nil, nil
  for _, pane in ipairs(shown) do
    local id = type(pane) == "table" and positiveId(pane.questId) or nil
    if id then
      if pane.hovered == true then
        return id, pane.surface
      end
      if firstId == nil then
        firstId, firstSurface = id, pane.surface
      end
    end
  end
  return firstId, firstSurface
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The bound key as the Key Bindings panel shows it, for example "Shift-T". Returns nil when
-- the binding is unbound or the client is not present. Never errors: the tooltip hint calls
-- this inside a pcall and takes a display string or nil. action is Keybind.Action's. Brief ST1:
-- slot 2 reads the action's second key; no slot (every caller but the settings rows) the first.
function Keybind.KeyText(action, slot)
  local getBindingKey = rawget(_G, "GetBindingKey")
  if type(getBindingKey) ~= "function" then
    return nil
  end
  local ok, first, second = pcall(getBindingKey, Keybind.Action(action))
  local key = first
  if Keybind.Slot(slot) == 2 then
    key = second
  end
  if not ok or type(key) ~= "string" or key == "" then
    return nil
  end
  local getBindingText = rawget(_G, "GetBindingText")
  if type(getBindingText) == "function" then
    -- One argument only. A second argument is a key prefix on some clients and an
    -- "abbreviate" flag on others, and the abbreviated form reads "s-m-O" where the full
    -- one reads "Shift-Cmd-O". The bare call gives the full text on both target clients.
    local textOk, text = pcall(getBindingText, key)
    if textOk and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return key
end

-- True while the player is in combat, when the client can say. Binding changes are refused
-- then, because SetBinding is protected.
function Keybind.InCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return ok and locked and true or false
end

-- The action a key currently runs, or nil when nothing holds it. GetBindingAction covers
-- Blizzard defaults, other addons and macro bindings alike, so a key that reports an action
-- is never taken silently.
function Keybind.ActionFor(key)
  local getBindingAction = rawget(_G, "GetBindingAction")
  if type(getBindingAction) ~= "function" or type(key) ~= "string" or key == "" then
    return nil
  end
  local ok, action = pcall(getBindingAction, key)
  if not ok or type(action) ~= "string" or action == "" then
    return nil
  end
  return action
end

-- The readable name of a binding action, for the line that says what a new key replaced.
-- A binding action name is not player data, so it is safe to show and to log.
function Keybind.ActionName(action)
  if type(action) ~= "string" or action == "" then
    return nil
  end
  local getBindingName = rawget(_G, "GetBindingName")
  if type(getBindingName) == "function" then
    local ok, name = pcall(getBindingName, action)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local label = rawget(_G, "BINDING_NAME_" .. action)
  if type(label) == "string" and label ~= "" then
    return label
  end
  return action
end

-- Writes the current binding set to disk, the way the Key Bindings panel does.
local function saveBindings()
  local save = rawget(_G, "SaveBindings")
  local current = rawget(_G, "GetCurrentBindingSet")
  if type(save) ~= "function" or type(current) ~= "function" then
    return false
  end
  local ok, set = pcall(current)
  if not ok or set == nil then
    return false
  end
  return pcall(save, set) and true or false
end

-- Tells the surfaces that show the key that it has changed: the tooltip hint line is
-- rebuilt on the next hover and the settings control refreshes its own text.
function Keybind.Changed()
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.ResetRendered) == "function" then
    pcall(tooltip.ResetRendered)
  end
  local options = ItemTree.Options
  if options and type(options.RefreshKeybind) == "function" then
    pcall(options.RefreshKeybind)
  end
end

-- Drops every key on the binding. Returns true when something was removed.
local function dropKeys(setBinding, action)
  local getBindingKey = rawget(_G, "GetBindingKey")
  if type(getBindingKey) ~= "function" then
    return false
  end
  local ok, first, second = pcall(getBindingKey, action)
  if not ok then
    return false
  end
  local removed = false
  for _, key in ipairs({ first or false, second or false }) do
    if type(key) == "string" and key ~= "" then
      local dropOk, dropped = pcall(setBinding, key, nil)
      if dropOk and dropped ~= false then
        removed = true
      end
    end
  end
  return removed
end

-- Brief ST1: an action's two keys as GetBindingKey answers them, or nil, nil.
local function boundKeys(action)
  local getBindingKey = rawget(_G, "GetBindingKey")
  if type(getBindingKey) ~= "function" then
    return nil, nil
  end
  local ok, first, second = pcall(getBindingKey, action)
  if not ok then
    return nil, nil
  end
  return first, second
end

-- Unbinds the binding entirely and saves. Returns true when a key was removed. action is
-- Keybind.Action's. Brief ST1: with a slot (1 or 2) only that slot's key goes, which is what a
-- right click on one of the game's Key Bindings buttons does (Blizzard_Keybindings.lua:434 to
-- 437, branch forever); the other key stays bound.
function Keybind.Clear(action, slot)
  local setBinding = rawget(_G, "SetBinding")
  if type(setBinding) ~= "function" or Keybind.InCombat() then
    return false
  end
  action = Keybind.Action(action)
  if slot == nil then
    if not dropKeys(setBinding, action) then
      return false
    end
  else
    local first, second = boundKeys(action)
    local key = first
    if Keybind.Slot(slot) == 2 then
      key = second
    end
    if type(key) ~= "string" or key == "" then
      return false
    end
    local ok, dropped = pcall(setBinding, key, nil)
    if not ok or dropped == false then
      return false
    end
  end
  saveBindings()
  Keybind.Changed()
  return true
end

-- Binds one key, taking it off whatever else held it, which is what the Key Bindings panel
-- does with a conflict. Returns true plus the readable name of the action it replaced, or
-- false when the client refuses, the player is in combat or there is no client at all. action is
-- Keybind.Action's: the Boss loot row passes Keybind.BOSS_BINDING.
-- Brief ST1: slot (1 or 2, the first when left out) is the one the key goes in; the other slot's
-- key stays. Both keys are unbound and bound again in order (Keybind.SlotKeys), as the panel's
-- own listener does, so the client lists them in the slots the player sees. Where the client
-- refuses the new key, the keys the action held are put back.
function Keybind.Set(binding, action, slot)
  if type(binding) ~= "string" or binding == "" or Keybind.InCombat() then
    return false
  end
  local setBinding = rawget(_G, "SetBinding")
  if type(setBinding) ~= "function" then
    return false
  end
  action = Keybind.Action(action)
  local replaced = Keybind.ActionFor(binding)
  if replaced == action then
    replaced = nil
  end
  local first, second = boundKeys(action)
  dropKeys(setBinding, action)
  local refused = false
  for _, key in ipairs(Keybind.SlotKeys(first, second, slot, binding)) do
    local ok, applied = pcall(setBinding, key, action)
    if key == binding and (not ok or applied == false) then
      refused = true
    end
  end
  if refused then
    -- The order is the old one again: drop what went on and bind the old keys back.
    dropKeys(setBinding, action)
    for _, key in ipairs({ first or false, second or false }) do
      if type(key) == "string" and key ~= "" then
        pcall(setBinding, key, action)
      end
    end
    return false
  end
  saveBindings()
  Keybind.Changed()
  return true, replaced and Keybind.ActionName(replaced) or nil
end

-- Brief ST1: the gamepad buttons the player's pad uses as Shift, Ctrl and Alt, as a set of key
-- names for Keybind.CaptureDecision, read from the client's GamePadEmulateShift, Ctrl and Alt
-- settings. A client without them, or one that answers "NONE", gives an empty set.
Keybind.PAD_MODIFIER_CVARS = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }

function Keybind.PadModifiers()
  local held = {}
  local cvars = rawget(_G, "C_CVar")
  local getCVar = type(cvars) == "table" and cvars.GetCVar or rawget(_G, "GetCVar")
  if type(getCVar) ~= "function" then
    return held
  end
  for _, name in ipairs(Keybind.PAD_MODIFIER_CVARS) do
    local ok, value = pcall(getCVar, name)
    if ok and type(value) == "string" and value ~= "" and value:upper() ~= "NONE" then
      held[value:upper()] = true
    end
  end
  return held
end

-- Brief KC1: whether the client's interface is in gamepad mode, the yellow arrow cursor. The
-- client's own test (InputUtil.IsGamepadUIEnabled, Blizzard_SharedXML/Mainline/InputUtil.lua:11
-- to 13) is C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
-- (the enum, Blizzard_APIDocumentationGenerated/InputConstantsDocumentation.lua:20 to 28; branch
-- forever, 1.60.1.70245), asked here of the API itself, as Jettison's Window.GamepadUI does.
-- False where the client cannot say.
function Keybind.GamepadUI()
  local style = rawget(_G, "C_InputInterfaceStyle")
  local enum = rawget(_G, "Enum")
  local get = type(style) == "table" and rawget(style, "GetCurrentStyle") or nil
  if type(get) ~= "function" or type(enum) ~= "table" then
    return false
  end
  local typesOk, types = pcall(function()
    return enum.InputDeviceInterfaceType
  end)
  if not typesOk or type(types) ~= "table" or types.Gamepad == nil then
    return false
  end
  local ok, current = pcall(get)
  return ok and canRead(current) and current == types.Gamepad
end

-- Brief KC1 (GP1's note on the owner's QA item 324, "with it on I can only do bare buttons in the
-- keybind area"): why a pair like Left trigger + X was taken as a bare X in the client's gamepad
-- mode. A pad button the player's gamepad settings make Shift, Ctrl or Alt (GamePadEmulateShift,
-- Ctrl and Alt) never reaches IsShiftKeyDown and the rest there: the triggers are the gamepad
-- interface's own action bar modifiers, bindings of its own (GAMEPADLEFTMOD and GAMEPADRIGHTMOD,
-- Blizzard_Gamepad/Bindings.xml:14 to 19, in the binding context the interface switches on as it
-- starts, Blizzard_Gamepad/Core.lua:44 to 53 and 69 to 71), which it reads with IsKeyDown on the
-- bound key (GamepadMode.IsBindingDown and IsLeftModifierDown, Blizzard_Gamepad/Utility/Bindings/
-- HoldBindings.lua:252 to 270; branch forever, 1.60.1.70245); and a probe on 1.60.1.70170 read
-- Shift as up with the emulated Shift trigger held (GP1's citation). So the capture, which read
-- only the four modifier readers, saw the bare button.
-- In the gamepad interface the same buttons are read the interface's way, IsKeyDown on each, and
-- count as the modifier they stand for, so Left trigger + X binds as SHIFT-PAD3 in both modes,
-- as Jettison's GP1 reads them (its Window.PadHeldModifiers). Read only; out of the gamepad
-- interface the client's own emulation answers, as before.
Keybind.PAD_HELD_CVARS = {
  shift = "GamePadEmulateShift",
  ctrl = "GamePadEmulateCtrl",
  alt = "GamePadEmulateAlt",
}

-- Brief KC1: the modifiers the pad holds now in the gamepad interface ({ shift = true, ... }),
-- empty outside it or where the client cannot say.
function Keybind.PadHeldModifiers()
  local held = {}
  if not Keybind.GamepadUI() then
    return held
  end
  local isDown = rawget(_G, "IsKeyDown")
  local cvars = rawget(_G, "C_CVar")
  local getCVar = type(cvars) == "table" and cvars.GetCVar or rawget(_G, "GetCVar")
  if type(isDown) ~= "function" or type(getCVar) ~= "function" then
    return held
  end
  for name, cvar in pairs(Keybind.PAD_HELD_CVARS) do
    local ok, button = pcall(getCVar, cvar)
    if ok and canRead(button) and type(button) == "string" and button ~= "" and button:upper() ~= "NONE" then
      local read, down = pcall(isDown, button:upper())
      if read and canRead(down) and down then
        held[name] = true
      end
    end
  end
  return held
end

-- Applies a default key once per character, and only when every condition holds: the saved
-- variables are up, the player is out of combat, the binding is still unbound, and this
-- character has not been offered a default before. A candidate is only taken when
-- GetBindingAction reports no action for it, which covers Blizzard defaults, other addons
-- and macro bindings alike, so a key already in use is never stomped.
--
-- The per character flag is set whether or not a key was free, so this runs at most once:
-- a player who unbinds the key afterwards is not handed it back at the next login.
-- Returns the key applied, or nil.
function Keybind.ApplyDefault()
  local charDb = ItemTree.charDb
  if type(charDb) ~= "table" or charDb.keybindDefaultTried then
    return nil
  end
  if Keybind.InCombat() then
    -- Brief E91: SetBinding is protected, so a login or reload in combat offers the default once
    -- combat ends, through the window's queue, rather than waiting for the next loading screen.
    local ui = ItemTree.UI
    local Frame = type(ui) == "table" and ui.Frame or nil
    if type(Frame) == "table" and type(Frame.AfterCombat) == "function" then
      Frame.AfterCombat(Keybind.ApplyDefault, "Keybind.ApplyDefault")
    end
    return nil
  end
  local getBindingKey = rawget(_G, "GetBindingKey")
  local getBindingAction = rawget(_G, "GetBindingAction")
  local setBinding = rawget(_G, "SetBinding")
  if type(getBindingKey) ~= "function" or type(getBindingAction) ~= "function" then
    return nil
  end
  if type(setBinding) ~= "function" then
    return nil
  end
  local function isBound()
    local ok, key = pcall(getBindingKey, Keybind.BINDING)
    return ok and type(key) == "string" and key ~= ""
  end
  local function isFree(key)
    return Keybind.ActionFor(key) == nil
  end
  local chosen = Keybind.ChooseDefault(Keybind.DEFAULT_KEYS, isBound, isFree)
  charDb.keybindDefaultTried = true
  if not chosen then
    return nil
  end
  local ok, applied = pcall(setBinding, chosen, Keybind.BINDING)
  if not ok or applied == false then
    return nil
  end
  saveBindings()
  Keybind.Changed()
  -- One chat line, so a binding that appeared by itself is never a mystery.
  local slash = ItemTree.Slash
  if slash and type(slash.Print) == "function" then
    local shown = Keybind.KeyText() or chosen
    pcall(slash.Print, string.format(L["ItemTree bound %s to open the tree for the hovered item"], shown))
  end
  return chosen
end

-- The client wrapper: the two real tooltip frames, or nothing outside the client, and (brief
-- LC1-full) the chat link under the cursor as the last resort.
function Keybind.HoveredItemId()
  local hovered = Keybind.HoveredLinkId and Keybind.HoveredLinkId() or nil
  return Keybind.ItemIdFromTooltips(rawget(_G, "GameTooltip"), rawget(_G, "ItemRefTooltip"), hovered)
end

-- Brief T7: the unit the game tooltip is showing, or nil. GetUnit answers the name and the unit
-- token; a tooltip that shows a unit it cannot give a token for falls back to "mouseover", which
-- is the unit a world tooltip is about. An item wins where both are shown: OpenHovered asks this
-- only when no item is under the cursor.
function Keybind.HoveredUnit()
  local tooltip = rawget(_G, "GameTooltip")
  if not isShown(tooltip) or type(tooltip.GetUnit) ~= "function" then
    return nil
  end
  local ok, name, unit = pcall(tooltip.GetUnit, tooltip)
  -- Brief SV1: a unit the tooltip keeps secret is no unit this shortcut can open.
  if not ok or not canRead(name) or not canRead(unit) then
    return nil
  end
  if type(unit) == "string" and unit ~= "" then
    return unit
  end
  if type(name) == "string" and name ~= "" then
    return "mouseover"
  end
  return nil
end

-- Brief QK1 (the owner's QA item 387, "Ctrl + right click anywhere inside a quest", and his ruling
-- 387b of 2026-10-23: the open key now, the click only after a taint check): the quest the player
-- is reading. The client's quest panes, read in this order, which is the order a tie goes when the
-- cursor is over none of them. Checked against the UI source mirror's forever branch at 172a387
-- (1.60.1.70450), where the Forever client (game type camelot, family mainline) loads the Mainline
-- quest files (Blizzard_UIPanels_Game.toc:88, :91, :100, :175, :176):
--
--   giver  QuestFrame (Mainline QuestFrame.xml:42), the quest giver's window, on its offer, progress
--          or turn in panel (QuestFrameDetailPanel :196, QuestFrameProgressPanel :94,
--          QuestFrameRewardPanel :71), never on its greeting list (:231). Its quest is GetQuestID(),
--          the call QuestInfo makes for a pane that is not the log's (QuestInfo.lua:124 to :130,
--          :608). First, because the client takes the popup down whenever one of these panels comes
--          up (QuestFrame.lua:43, :62, :67, :71).
--   popup  QuestLogPopupDetailFrame (Mainline QuestMapFrame.xml:311), the quest log's details
--          window. ShowQuest keeps the quest on the frame and makes it the log's selection
--          (QuestMapFrame.lua:2613, :2614); OnHide clears it (:2538 to :2541).
--   map    QuestMapFrame.DetailsFrame (QuestMapFrame.xml:661, named at QuestMapFrame.lua:466), the
--          details pane beside the world map, the one in the owner's screenshot.
--          QuestMapFrame_ShowQuestDetails keeps the quest on the pane and makes it the selection
--          (QuestMapFrame.lua:1046 to :1048); QuestMapFrame_CloseQuestDetails hides the pane and
--          clears it (:1114, :1115), and the quest log's own OnHide closes it (:630 to :634).
--
-- A log pane's quest is the frame's own questID first and C_QuestLog.GetSelectedQuest()
-- (QuestLogDocumentation.lua:611, the call QuestInfo makes for the log's panes) only where the frame
-- holds none: the selection is one value both log panes set, so with the popup opened over the map
-- pane it names the popup's quest, while each frame's field names the quest that frame is drawing.
--
-- Up is IsVisible, false once the frame or anything above it is hidden (the pane sits under the
-- world map, Blizzard_WorldMap.lua:1391); under the cursor is IsMouseOver. Those two questions,
-- two field reads and the two C calls are all this asks of the client: nothing is written onto,
-- hooked on or parented to a client frame, no client Lua helper is called, and nothing moves focus.
-- Gamepad mode shows the same frames (WorldMapMixin:OnOpenQuestDetails, Blizzard_WorldMap.lua:546;
-- QuestFrame_SetupGamepad, QuestFrame.lua:763; QuestLogPopupDetailMixin:SetupGamepad,
-- QuestMapFrame.lua:2550): the mirror has no gamepad quest window of its own.

-- One field of a client frame, read under pcall, or nil.
local function fieldOf(frame, key)
  if type(frame) ~= "table" then
    return nil
  end
  local ok, value = pcall(function()
    return frame[key]
  end)
  if not ok then
    return nil
  end
  return value
end

-- A yes or no question to a client frame (IsVisible, IsMouseOver). A frame that cannot answer, or
-- whose answer the client keeps secret (brief SV1), answers no: a pane is never guessed to be up.
local function frameSays(frame, method)
  local ask = fieldOf(frame, method)
  if type(ask) ~= "function" then
    return false
  end
  local ok, answer = pcall(ask, frame)
  if not ok or not canRead(answer) then
    return false
  end
  return answer and true or false
end

-- A quest id the client handed back, when it may be read and is a positive whole number.
local function readableQuestId(value)
  if not canRead(value) then
    return nil
  end
  return positiveId(value)
end

-- The quest log's selection, or nil.
local function selectedQuest()
  local questLog = rawget(_G, "C_QuestLog")
  local get = type(questLog) == "table" and questLog.GetSelectedQuest or nil
  if type(get) ~= "function" then
    return nil
  end
  local ok, id = pcall(get)
  if not ok then
    return nil
  end
  return readableQuestId(id)
end

-- A log pane's quest: the frame's own questID, else the log's selection.
local function logPaneQuest(frame)
  return readableQuestId(fieldOf(frame, "questID")) or selectedQuest()
end

-- The quest giver's quest, or nil.
local function giverQuest()
  local get = rawget(_G, "GetQuestID")
  if type(get) ~= "function" then
    return nil
  end
  local ok, id = pcall(get)
  if not ok then
    return nil
  end
  return readableQuestId(id)
end

-- The giver's panels that show one quest, by their global names (Mainline QuestFrame.xml).
Keybind.GIVER_QUEST_PANELS = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }

local function giverPanelUp()
  for _, name in ipairs(Keybind.GIVER_QUEST_PANELS) do
    if frameSays(rawget(_G, name), "IsVisible") then
      return true
    end
  end
  return false
end

--- The client's quest panes that are up right now, in tie order, each { surface, questId, hovered }
--- for Keybind.PickShownQuest. An empty list when none is, or outside the client.
function Keybind.ShownQuests()
  local shown = {}
  local function add(surface, frame, questId)
    shown[#shown + 1] = { surface = surface, questId = questId, hovered = frameSays(frame, "IsMouseOver") }
  end
  local giver = rawget(_G, "QuestFrame")
  if frameSays(giver, "IsVisible") and giverPanelUp() then
    add("giver", giver, giverQuest())
  end
  local popup = rawget(_G, "QuestLogPopupDetailFrame")
  if frameSays(popup, "IsVisible") then
    add("popup", popup, logPaneQuest(popup))
  end
  local details = fieldOf(rawget(_G, "QuestMapFrame"), "DetailsFrame")
  if frameSays(details, "IsVisible") then
    add("map", details, logPaneQuest(details))
  end
  return shown
end

--- The quest the player is reading, and its pane's name, or nil when no quest pane is up.
function Keybind.ShownQuestId()
  local ok, shown = pcall(Keybind.ShownQuests)
  if not ok then
    return nil
  end
  return Keybind.PickShownQuest(shown)
end

--- The node key of a quest's page, built the way the quest rows build theirs (Graph.Key), with a
--- dead twin folded into its live quest here (Graph.FoldTwinKey, brief RB3) rather than only in
--- Frame.Open, so the toggle compares the key the window is really rooted on and a second press
--- closes it. The plain "quest:<id>" string is the fallback where Core/Graph.lua is not loaded.
function Keybind.QuestKey(questId)
  local key = "quest:" .. tostring(questId)
  local graph = ItemTree.Graph
  if type(graph) ~= "table" then
    return key
  end
  if type(graph.Key) == "function" then
    local ok, built = pcall(graph.Key, "quest", questId)
    if ok and type(built) == "string" then
      key = built
    end
  end
  if type(graph.FoldTwinKey) == "function" then
    local ok, folded = pcall(graph.FoldTwinKey, key)
    if ok and type(folded) == "string" then
      key = folded
    end
  end
  return key
end

-- The node key for an item, built the way Slash.Show builds it, with the plain string as the
-- fallback for a build where Core/Graph.lua is not loaded.
function Keybind.NodeKey(itemId)
  local key = "item:" .. tostring(itemId)
  local graph = ItemTree.Graph
  if graph and type(graph.Key) == "function" then
    local ok, built = pcall(graph.Key, "item", itemId)
    if ok and type(built) == "string" then
      key = built
    end
  end
  return key
end

-- Opens the window on an item, and only ever opens it: this is what a click and the random
-- item both take, where the key press toggles. False means there was no window to open, or
-- the call raised.
function Keybind.OpenItem(itemId)
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if not frame or type(frame.Open) ~= "function" then
    return false
  end
  local ok, opened = pcall(frame.Open, Keybind.NodeKey(itemId))
  if not ok then
    return false
  end
  return opened and true or false
end

-- Nothing under the cursor. A dead key press teaches a player nothing, so the window opens on
-- the item this session last showed, on the newest Recently viewed page when it has shown none yet
-- (brief RO1), and on a random New in Forever item when that list is empty too. UI/Frame.lua owns
-- that rule (Frame.OpenDefault) and UI/Slash.lua owns the one chat line
-- (Slash.OpenDefault), so a left click on the minimap button does exactly the same thing.
--
-- False means no window is open afterwards: the press closed the one it was already showing,
-- there was nothing to pick, or there is no client to build a window on.
function Keybind.OpenDefault()
  local slash = ItemTree.Slash
  if not (slash and type(slash.OpenDefault) == "function") then
    return false
  end
  local ok, opened = pcall(slash.OpenDefault)
  if not ok then
    return false
  end
  return opened and true or false
end

-- What the binding runs. With nothing under the cursor it opens the window on this session's
-- last item, or picks one, see OpenDefault. Otherwise it hands the node key to the window
-- through Frame.Toggle, so the key is a toggle: pressing it on a window already rooted on this
-- item closes it, and pressing it on another item re roots. Frame.Open is the fallback for a
-- window with no Toggle. False means the window is not open: it just closed, there was no client
-- to build one on, or the call raised.
--
-- Brief QK1: what is under the cursor comes first, an item and then a creature. With neither, a
-- quest pane that is up (Keybind.ShownQuests) opens that quest's page, through the same toggle, and
-- only with no quest pane up does the press fall to OpenDefault. It runs inside the key press as the
-- item open always has: Frame.Toggle shows ItemTree's own window and makes no protected call, and
-- the window never takes the keyboard focus on open.
function Keybind.OpenHovered()
  local itemId = Keybind.HoveredItemId()
  local key
  if itemId then
    key = Keybind.NodeKey(itemId)
  else
    -- Brief T7: no item, but the tooltip shows a creature. Its page opens the way an item's does;
    -- a creature nothing is known about opens a page of its own (brief T8), and a player is
    -- nothing hovered.
    local unit = Keybind.HoveredUnit()
    local lookup = ItemTree.CreatureLookup
    if unit and lookup and type(lookup.ForUnit) == "function" then
      local ok, found = pcall(lookup.ForUnit, unit)
      if ok and found then
        key = found
      end
    end
    -- Brief QK1: no item and no creature, but a quest pane is up: the quest the player is reading.
    if not key then
      local questId = Keybind.ShownQuestId()
      if questId then
        key = Keybind.QuestKey(questId)
      end
    end
    if not key then
      return Keybind.OpenDefault()
    end
  end
  local frame = ItemTree.UI and ItemTree.UI.Frame
  local show = frame and (type(frame.Toggle) == "function" and frame.Toggle or frame.Open)
  if type(show) == "function" then
    local ok, opened = pcall(show, key)
    if ok then
      return opened and true or false
    end
  end
  return false
end

-- Brief B1: the Boss loot tab's module and the window, or nil for either where the build has none.
local function bossLootModules()
  local ui = ItemTree.UI
  if type(ui) ~= "table" then
    return nil, nil
  end
  local pane = type(ui.BossLoot) == "table" and ui.BossLoot or nil
  local frame = type(ui.Frame) == "table" and ui.Frame or nil
  return pane, frame
end

-- The Boss loot tab's name on the strip, which is the id Frame.SelectTab takes.
function Keybind.BossLootTab()
  local pane = bossLootModules()
  if pane and type(pane.TAB_NAME) == "string" and pane.TAB_NAME ~= "" then
    return pane.TAB_NAME
  end
  return "Boss loot"
end

-- Whether the Boss loot tab is there to open: its module is in this build and has its data, and
-- the tab's own setting (showBossLoot) is on, read the way the window reads it
-- (Frame.TabSettingOn), so an unset value takes the tab's registered default. False means the key
-- and the second minimap button open nothing.
function Keybind.BossLootOn()
  local pane, frame = bossLootModules()
  if not pane then
    return false
  end
  if type(pane.Present) == "function" then
    local ok, present = pcall(pane.Present)
    if not ok or not present then
      return false
    end
  end
  local settings = ItemTree.db and ItemTree.db.settings
  if frame and type(frame.TabSettingOn) == "function" then
    local ok, on = pcall(frame.TabSettingOn, Keybind.BossLootTab(), settings)
    return ok and on == true
  end
  local key = type(pane.SETTING) == "string" and pane.SETTING or "showBossLoot"
  return not (type(settings) == "table" and settings[key] == false)
end

-- What the Boss loot key and the second minimap button run. With the window up on the Boss loot
-- tab it closes the window; with the window up on another tab it moves to Boss loot; with the
-- window closed it opens it on the page it last showed (or the key's usual first pick, see
-- Frame.OpenDefault, because the window cannot open on no page at all) and then moves to Boss
-- loot. The tab turned off, or not in this build, opens nothing. Answers whether the window is
-- open on the tab afterwards.
function Keybind.OpenBossLoot()
  if not Keybind.BossLootOn() then
    return false
  end
  local _, frame = bossLootModules()
  if not frame or type(frame.SelectTab) ~= "function" then
    return false
  end
  local tab = Keybind.BossLootTab()
  local shownOk, shown = pcall(function()
    return type(frame.IsShown) == "function" and frame.IsShown()
  end)
  shown = shownOk and shown and true or false
  if shown and type(frame.Tab) == "function" then
    local ok, current = pcall(frame.Tab)
    if ok and current == tab then
      if type(frame.Hide) == "function" then
        pcall(frame.Hide)
      end
      return false
    end
  end
  if not shown then
    local key = frame.rootKey or frame.lastRootKey or frame.pendingKey
    local ok, opened
    if key and type(frame.Open) == "function" then
      -- Brief RO1: the Item tree tab under it comes back as it was closed, a creature's tab and all.
      ok, opened = pcall(frame.Open, key, { restore = true, reopen = true })
    elseif type(frame.OpenDefault) == "function" then
      ok, opened = pcall(frame.OpenDefault)
    end
    if not ok or not opened then
      return false
    end
  end
  local ok, now = pcall(frame.SelectTab, tab)
  return ok and now == tab
end

--------------------------------------------------------------------------------
-- Click to open. Two paths, because one was not enough.
--
-- The event path is the main one: GLOBAL_MOUSE_DOWN carries the button name and fires for
-- every press anywhere, so the shortcut reaches every surface the key binding reaches. The
-- item is resolved exactly the way the key resolves it, from the tooltip on screen, so a
-- profession reagent, a loot row, a quest reward, a character sheet slot, an auction row and
-- another addon's frame all work as long as they show an item tooltip. The event exists on
-- both target clients: Blizzard_APIDocumentationGenerated/SystemDocumentation.lua names
-- GlobalMouseDown with a cstring "button" payload on the classic_era and classic_beta
-- branches alike, and the client's own SharedUIPanelTemplates listens for its GLOBAL_MOUSE_UP
-- twin. Nothing hovered means nothing happens: opening the window with nothing pointed at
-- belongs to the key and the minimap button, not to a click on the world.
--
-- The funnel hook is the fallback: hooksecurefunc on HandleModifiedItemClick, for a client
-- that has never heard of the event, and for a chat hyperlink clicked with no tooltip on
-- screen. hooksecurefunc runs our function after the client's own with the same arguments and
-- gives it no way to change what the client does, so nothing here can taint a protected
-- action. A container item button registers LeftButtonUp and RightButtonUp and its OnClick
-- sends any modified click to OnModifiedClick, which calls HandleModifiedItemClick with the
-- item link: Classic Era Blizzard_UIPanels_Game/Classic/ContainerFrame_Shared.lua, and the
-- beta's Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua. Bank slots, merchant rows,
-- buyback rows and chat links reach the same funnel on both.
--
-- Both paths can answer one press, the event on the way down and the funnel on the way up, so
-- both go through OpenClicked, which drops a second open of the same item inside
-- CLICK_DEBOUNCE seconds. Opening is idempotent anyway: OpenItem calls Frame.Open, never
-- Frame.Toggle, so the worst a double would do is re-root the window on the item it is
-- already showing.
--
-- We cannot cancel the click's own action, only decline to answer it, which is what
-- ShouldSkipFocus is for: loot rows loot, action buttons cast, and our own rows re-root
-- themselves. The tree window is an ordinary frame, so opening it inside combat lockdown is
-- allowed, and every call is pcall'd so a click can never raise inside the client's handler.
--
-- Per surface, for the default Ctrl + right click and the hotkey (brief LC1-full, read on
-- 1.60.1.70205, wow-ui-source forever e3ecc27; the clickopen probe says what the client does):
--   loot slot      mouse path (the loot rule is lifted for a modified press) and the funnel (the
--                  row's Item button takes the right button, LootFrame.xml line 9, and sends a
--                  modified press to HandleModifiedItemClick, LootFrame.lua line 68): one open,
--                  never a loot. Hotkey: GameTooltip.
--   roll window    mouse path only: the IconFrame takes the left button alone
--                  (GroupLootFrame.xml line 319). Hotkey: GameTooltip (SetLootRollItem).
--   chat link      mouse path from the hover memory, the SetItemRef hook from the click, and the
--                  funnel when the client names the button there: one open. Hotkey: the hover
--                  memory (ahead of an item link tooltip left open), or ItemRefTooltip once the
--                  link was left clicked open and the cursor is off the link.
--   trade, yours   mouse path and the funnel (TradeFrame.xml lines 140 to 155, both buttons).
--   trade, theirs  mouse path only (TradeFrame.xml lines 95 to 101, no RegisterForClicks).
--                  Hotkey on both: GameTooltip (SetTradePlayerItem, SetTradeTargetItem).
--
-- One gap is the client's own: a modified click on a lootable item with a button other than
-- the left one is treated as a plain click when the player's AUTOLOOTTOGGLE modifier is held,
-- so Alt and right click on a full lockbox does nothing when Alt is their auto loot modifier.
--------------------------------------------------------------------------------

-- The stored click option, falling back to the shipped default so saved variables written
-- before the setting existed still open on the default click.
function Keybind.ClickSetting()
  local settings = ItemTree.db and ItemTree.db.settings
  local value = settings and settings.clickOpen
  if type(value) ~= "string" or value == "" then
    local defaults = ItemTree.DB_DEFAULTS and ItemTree.DB_DEFAULTS.settings
    value = defaults and defaults.clickOpen
  end
  if type(value) ~= "string" or value == "" then
    return Keybind.CLICK_OFF
  end
  return value
end

-- The readable shortcut, for the tooltip hint line and the settings panel, or nil when click
-- to open is off. Never errors: the hint calls this inside a pcall and takes a string or nil.
function Keybind.ClickText()
  local label = Keybind.ClickLabel(Keybind.ClickSetting())
  if not label then
    return nil
  end
  return L[label]
end

-- The mouse button the client says was clicked, or nil when it will not say. Only ever called
-- from inside a click handler, which is where GetMouseButtonClicked has an answer.
local function mouseButtonClicked()
  local clicked = rawget(_G, "GetMouseButtonClicked")
  if type(clicked) ~= "function" then
    return nil
  end
  local ok, button = pcall(clicked)
  if not ok or type(button) ~= "string" or button == "" then
    return nil
  end
  return button
end

local function modifierHeld(name)
  local down = rawget(_G, name)
  if type(down) ~= "function" then
    return false
  end
  local ok, held = pcall(down)
  return ok and held and true or false
end

-- The clock the two click paths debounce against, in seconds with fractions, or nil where
-- there is no client. GetTime is the client's own frame clock, which is what every Blizzard
-- panel times a double click with. A spec replaces this whole function.
function Keybind.Now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, now = pcall(getTime)
  if not ok or type(now) ~= "number" then
    return nil
  end
  return now
end

-- Brief LC0: the trace the owner's probe asks for ("/itprobe clickopen"). While it runs, both
-- click paths hand the probe one small record per modified press: the button, the modifiers,
-- ClickDecision's answer, the focus names the skip rule read, the skip verdict, the item id
-- (never a link, never a name) and what OpenClicked did. Nothing about what a click does
-- changes: the record is filled beside the real decision and the answers are the same. Not
-- armed, the cost is one nil check per press. Session only; nothing is stored.
Keybind.tracer = nil
Keybind.traceUntil = nil

--- Starts the trace for seconds, handing each record to fn. True when it started.
function Keybind.TraceFor(seconds, fn)
  local at = Keybind.Now()
  if type(fn) ~= "function" or type(seconds) ~= "number" or not at then
    return false
  end
  Keybind.tracer, Keybind.traceUntil = fn, at + seconds
  return true
end

--- Whether the trace is running. It stops itself once its time is up.
function Keybind.Tracing()
  if type(Keybind.tracer) ~= "function" then
    return false
  end
  local at = Keybind.Now()
  if not at or not Keybind.traceUntil or at >= Keybind.traceUntil then
    Keybind.tracer, Keybind.traceUntil = nil, nil
    return false
  end
  return true
end

-- A fresh record when the trace is armed, else nil. The nil check comes first, so a session
-- with no probe running pays nothing more.
local function newTrace(path)
  if Keybind.tracer == nil or not Keybind.Tracing() then
    return nil
  end
  return { path = path }
end

local function emitTrace(trace)
  if trace and type(Keybind.tracer) == "function" then
    pcall(Keybind.tracer, trace)
  end
end

-- What both click paths open with. A second open of the same item inside CLICK_DEBOUNCE
-- seconds is dropped, so a press that reaches both paths opens once. With no clock to read
-- nothing is dropped, which is the safe way round: opening is idempotent. The optional trace
-- (brief LC0) is told whether the open ran or the debounce dropped it, and nothing else.
function Keybind.OpenClicked(itemId, trace)
  if itemId == nil then
    if trace then
      trace.result = "no item"
    end
    return false
  end
  local now = Keybind.Now()
  if Keybind.IsRepeatClick(itemId, now, Keybind.lastClickItem, Keybind.lastClickAt) then
    if trace then
      trace.result = "debounced"
      trace.since = now - Keybind.lastClickAt
    end
    return false
  end
  Keybind.lastClickItem = itemId
  Keybind.lastClickAt = now
  local opened = Keybind.OpenItem(itemId)
  if trace then
    trace.result = opened and "opened" or "open refused"
  end
  return opened
end

-- The frames under the cursor, innermost first, or nil when the client will not say.
-- GetMouseFoci is the modern shape and answers a table of regions on both target clients
-- (Blizzard_APIDocumentationGenerated/InputDocumentation.lua on classic_era and
-- classic_beta); GetMouseFocus is the older single frame shape, kept as the fallback.
local function mouseFocusFrames()
  local foci = rawget(_G, "GetMouseFoci")
  if type(foci) == "function" then
    local ok, frames = pcall(foci)
    if ok and type(frames) == "table" and frames[1] ~= nil then
      return frames
    end
  end
  local focus = rawget(_G, "GetMouseFocus")
  if type(focus) == "function" then
    local ok, frame = pcall(focus)
    if ok and type(frame) == "table" then
      return { frame }
    end
  end
  return nil
end

-- Brief SV1: what a frame name the client keeps secret reads as.
Keybind.SECRET_NAME = "(secret)"

local function frameName(frame)
  if type(frame) ~= "table" or type(frame.GetName) ~= "function" then
    return nil
  end
  local ok, name = pcall(frame.GetName, frame)
  if not ok then
    return nil
  end
  -- Brief SV1: a name the client keeps secret (SecretAspect ObjectName) reads as "(secret)",
  -- which no skip rule matches and the clickopen probe prints as it is.
  if not canRead(name) then
    return Keybind.SECRET_NAME
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

-- How far up a parent chain to read. Deep enough for a row inside a scroll box inside a pane
-- inside a window, short enough that a frame whose parent is itself cannot spin.
local FOCUS_PARENT_DEPTH = 8

local function addParentNames(frame, names, seen)
  for _ = 1, FOCUS_PARENT_DEPTH do
    if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then
      return
    end
    local ok, parent = pcall(frame.GetParent, frame)
    -- Brief SV1: a parent the client keeps secret (SecretAspect Hierarchy) ends the walk.
    if not ok or not canRead(parent) or type(parent) ~= "table" or seen[parent] then
      return
    end
    seen[parent] = true
    local name = frameName(parent)
    if name then
      names[#names + 1] = name
    end
    frame = parent
  end
end

-- The two frames that sit under every click in the game. Both are protected, so their flag
-- says nothing about what the player is pointing at and reading it would turn the shortcut
-- off everywhere. Their names are still read, they are simply never the protected answer.
local FOCUS_ROOTS = { WorldFrame = true, UIParent = true }

-- A plain description of what is under the cursor, for ShouldSkipFocus: the name of the first
-- frame the client names, every other name around it and above it, and whether any of them,
-- the two roots aside, is protected. The protected flag is taken from the whole stack rather
-- than from one entry because the client does not promise an order for GetMouseFoci, and an
-- action bar button must be skipped wherever in the list it turns up. Returns nil when the
-- client will not say what is under the cursor.
function Keybind.FocusDescription()
  local frames = mouseFocusFrames()
  if not frames then
    return nil
  end
  local description = { parents = {}, protected = false }
  local seen = {}
  for index, frame in ipairs(frames) do
    if type(frame) == "table" and not seen[frame] then
      seen[frame] = true
      local name = frameName(frame)
      if index == 1 then
        description.name = name
      elseif name then
        description.parents[#description.parents + 1] = name
      end
      if not FOCUS_ROOTS[name or ""] and type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        -- Brief SV1: a flag the client keeps secret (SecretAspect ObjectSecurity) says nothing.
        if ok and canRead(protected) and protected then
          description.protected = true
        end
      end
      addParentNames(frame, description.parents, seen)
    end
  end
  return description
end

-- What a mouse press runs. The button comes from the event, the modifiers from the client,
-- and the item from whatever tooltip is on screen, which is exactly how the key binding finds
-- it, so every surface that shows an item tooltip is covered. Nothing hovered means nothing
-- happens: opening with nothing pointed at belongs to the key alone. Returns true only when the
-- window opened, which is what the spec asserts; the client ignores the answer.
-- Brief LC0: fills a mouse path record with what the skip rule and the key read, beside the real
-- decision rather than inside it, so a press the shortcut ignores still says what was under the
-- cursor. Only ever called while the probe's trace is armed.
local function traceMouse(trace, button, setting, ctrl, alt, shift)
  trace.button, trace.ctrl, trace.alt, trace.shift = button, ctrl, alt, shift
  trace.decision = Keybind.ClickDecision(setting, button, ctrl, alt, shift)
  local ok, focus = pcall(Keybind.FocusDescription)
  trace.focus = ok and focus or nil
  local skipOk, skip, reason = pcall(Keybind.ShouldSkipFocus, trace.focus, ctrl or alt or shift)
  if skipOk then
    trace.skip, trace.reason = skip and true or false, reason
  end
  local itemOk, itemId = pcall(Keybind.HoveredItemId)
  trace.itemId = itemOk and itemId or nil
end

function Keybind.OnGlobalMouseDown(button)
  -- This runs for every press anywhere in the game, so the cheapest test comes first and a
  -- player who has turned the shortcut off pays a string compare.
  local trace = newTrace("mouse")
  local setting = Keybind.ClickSetting()
  if setting == Keybind.CLICK_OFF and not trace then
    return false
  end
  local ctrl, alt, shift =
    modifierHeld("IsControlKeyDown"), modifierHeld("IsAltKeyDown"), modifierHeld("IsShiftKeyDown")
  -- The probe traces modified presses only: every plain press in the game would drown the lines.
  if trace and not (ctrl or alt or shift) then
    trace = nil
  end
  if trace then
    traceMouse(trace, button, setting, ctrl, alt, shift)
  end
  if setting == Keybind.CLICK_OFF or not Keybind.ClickDecision(setting, button, ctrl, alt, shift) then
    if trace then
      trace.result = "not this click"
      emitTrace(trace)
    end
    return false
  end
  -- Brief LC1-full: the press is modified (ClickDecision wants Ctrl or Alt), which is what lifts
  -- the loot slot rule: the loot row's own click never loots a modified press.
  local skipOk, skip = pcall(function()
    return Keybind.ShouldSkipFocus(Keybind.FocusDescription(), ctrl or alt or shift)
  end)
  if not skipOk or skip then
    if trace then
      trace.result = skipOk and "skipped" or "focus raised"
      emitTrace(trace)
    end
    return false
  end
  local itemId = Keybind.HoveredItemId()
  if not itemId then
    if trace then
      trace.result = "no item"
      emitTrace(trace)
    end
    return false
  end
  local opened = Keybind.OpenClicked(itemId, trace)
  emitTrace(trace)
  return opened
end

-- What the hook runs. Reads the link the client was given, checks the click against the
-- setting and opens the tree. Returns true only when the window opened, which is what the
-- spec asserts; the client itself ignores the answer.
--
-- Brief LC0: while the probe's trace is armed, every call (every modified click that reaches
-- the funnel) hands it one record: the button and modifiers read now, the decision, the item id
-- parsed from the link (the link itself never leaves here) and what OpenClicked did.
function Keybind.OnModifiedItemClick(link)
  local trace = newTrace("funnel")
  local ctrl, alt, shift =
    modifierHeld("IsControlKeyDown"), modifierHeld("IsAltKeyDown"), modifierHeld("IsShiftKeyDown")
  local button = mouseButtonClicked()
  local tooltip = ItemTree.Tooltip
  local decision = Keybind.ClickDecision(Keybind.ClickSetting(), button, ctrl, alt, shift)
  if trace then
    trace.button, trace.ctrl, trace.alt, trace.shift, trace.decision = button, ctrl, alt, shift, decision
    if tooltip and type(tooltip.ItemIdFromLink) == "function" then
      local idOk, id = pcall(tooltip.ItemIdFromLink, link)
      trace.itemId = idOk and id or nil
    end
  end
  if not decision then
    if trace then
      trace.result = "not this click"
      emitTrace(trace)
    end
    return false
  end
  if not tooltip or type(tooltip.ItemIdFromLink) ~= "function" then
    if trace then
      trace.result = "no reader"
      emitTrace(trace)
    end
    return false
  end
  local ok, itemId = pcall(tooltip.ItemIdFromLink, link)
  if not ok or not itemId then
    if trace then
      trace.result = "not an item"
      emitTrace(trace)
    end
    return false
  end
  local opened = Keybind.OpenClicked(itemId, trace)
  emitTrace(trace)
  return opened
end

--------------------------------------------------------------------------------
-- Brief LC1-full: chat links, directly.
--
-- A chat frame hands a click on any hyperlink to SetItemRef (ChatFrameMixin:OnHyperlinkClick,
-- Blizzard_ChatFrameBase/Shared/ChatFrame.lua lines 19 to 25, on 1.60.1.70205, wow-ui-source
-- forever e3ecc27), with the button that was pressed. SetItemRef (Blizzard_UIPanels_Game/
-- Mainline/ItemRef.lua lines 6 to 27) offers the link to LinkUtil.ProcessLink first, whose item
-- handler only takes a Shift + left click into a chat box (Shared/ItemRefHandlersShared.lua lines
-- 154 to 163), and then sends any IsModifiedClick() press to HandleModifiedItemClick. So the
-- funnel hook already sees a Ctrl + right click on a chat item link, but not the button: inside a
-- hyperlink click GetMouseButtonClicked has no button of its own to report (VERIFY with the
-- clickopen probe). A post hook on SetItemRef reads the button the chat frame passed and decides
-- on it, whatever the client's own SetItemRef did. Both hooks can answer one click; OpenClicked's
-- debounce makes that one open.
--
-- The hotkey over a hovered, unclicked link: a chat link shows no tooltip until it is clicked,
-- so neither tooltip holds its item. The chat frame template declares OnHyperlinkEnter and
-- OnHyperlinkLeave (Blizzard_ChatFrameBase/Mainline/ChatFrame.xml lines 17 and 18; the mixin's
-- handlers, ChatFrame.lua lines 27 to 33, only fire EventRegistry events). A HookScript on each
-- chat frame remembers the hovered item id HERE, in Keybind, never on the frame, and forgets it
-- on leave. HookScript chains after the frame's own handler and cannot replace it. Nothing is
-- shown on hover: a hover tooltip is another addon's job.
--------------------------------------------------------------------------------

-- The chat link under the cursor: its item id, and the chat frame it is in, so a memory whose
-- frame has gone or no longer has the cursor is dropped rather than answered.
Keybind.hoverLinkItem = nil
Keybind.hoverLinkFrame = nil

-- The chat frames already hooked, weak so a frame the client throws away is not held.
local hookedChatFrames = setmetatable({}, { __mode = "k" })

--- What the OnHyperlinkEnter hook runs: remembers the link's item id, or forgets any memory for
--- a link that is not an item.
function Keybind.OnLinkEnter(frame, link)
  local id = Keybind.LinkItemId(link)
  if id then
    Keybind.hoverLinkItem, Keybind.hoverLinkFrame = id, frame
  else
    Keybind.hoverLinkItem, Keybind.hoverLinkFrame = nil, nil
  end
end

--- What the OnHyperlinkLeave hook runs: forgets the memory, unless it belongs to another frame.
function Keybind.OnLinkLeave(frame)
  if Keybind.hoverLinkFrame == nil or Keybind.hoverLinkFrame == frame then
    Keybind.hoverLinkItem, Keybind.hoverLinkFrame = nil, nil
  end
end

--- The item id of the chat link under the cursor, or nil. A memory whose frame is hidden, or
--- says the cursor is no longer over it, is dropped: a leave the client never sent cannot leave
--- the hotkey stuck on an old link.
function Keybind.HoveredLinkId()
  local id, frame = Keybind.hoverLinkItem, Keybind.hoverLinkFrame
  if type(id) ~= "number" then
    return nil
  end
  if frame ~= nil then
    local gone = not isShown(frame)
    if not gone and type(frame.IsMouseOver) == "function" then
      local ok, over = pcall(frame.IsMouseOver, frame)
      gone = ok and over == false
    end
    if gone then
      Keybind.hoverLinkItem, Keybind.hoverLinkFrame = nil, nil
      return nil
    end
  end
  return id
end

--- What the SetItemRef post hook runs. link is the hyperlink's payload and button the one the
--- chat frame passed. Opens the tree for an item link clicked the way the setting asks, through
--- OpenClicked and its debounce. Returns true only when the window opened. While the clickopen
--- probe runs it hands the probe a funnel record marked via = "link".
function Keybind.OnSetItemRef(link, _, button)
  local trace = newTrace("funnel")
  local ctrl, alt, shift =
    modifierHeld("IsControlKeyDown"), modifierHeld("IsAltKeyDown"), modifierHeld("IsShiftKeyDown")
  local decision = Keybind.ClickDecision(Keybind.ClickSetting(), button, ctrl, alt, shift)
  local itemId = Keybind.LinkItemId(link)
  if trace then
    trace.via = "link"
    trace.button, trace.ctrl, trace.alt, trace.shift, trace.decision = button, ctrl, alt, shift, decision
    trace.itemId = itemId
  end
  if not decision then
    if trace then
      trace.result = "not this click"
      emitTrace(trace)
    end
    return false
  end
  if not itemId then
    if trace then
      trace.result = "not an item"
      emitTrace(trace)
    end
    return false
  end
  local opened = Keybind.OpenClicked(itemId, trace)
  emitTrace(trace)
  return opened
end

-- Hooks SetItemRef, once per session.
local function hookItemRef()
  if Keybind.linkHooked then
    return true
  end
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" or type(rawget(_G, "SetItemRef")) ~= "function" then
    return false
  end
  local ok = pcall(hook, "SetItemRef", function(link, text, button)
    pcall(Keybind.OnSetItemRef, link, text, button)
  end)
  if not ok then
    return false
  end
  Keybind.linkHooked = true
  return true
end

-- The chat frames to hook: ChatFrame1 to ChatFrame<NUM_CHAT_WINDOWS>, and every name in the
-- client's CHAT_FRAMES list, which also holds the temporary whisper windows made later
-- (Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua lines 66, 93 and 445, on 70205).
local function chatFrameList()
  local list, seen = {}, {}
  local function add(frame)
    if type(frame) == "table" and not seen[frame] then
      seen[frame] = true
      list[#list + 1] = frame
    end
  end
  local count = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
  for index = 1, count do
    add(rawget(_G, "ChatFrame" .. index))
  end
  local names = rawget(_G, "CHAT_FRAMES")
  if type(names) == "table" then
    for _, name in pairs(names) do
      if type(name) == "string" then
        add(rawget(_G, name))
      end
    end
  end
  return list
end

-- HookScript on one chat frame's two hyperlink scripts, once per frame. A frame that does not
-- have both scripts (HasScript), or has no HookScript, is left alone.
local function hookChatFrame(frame)
  if hookedChatFrames[frame] then
    return true
  end
  if type(frame.HasScript) ~= "function" or type(frame.HookScript) ~= "function" then
    return false
  end
  local enterOk, hasEnter = pcall(frame.HasScript, frame, "OnHyperlinkEnter")
  local leaveOk, hasLeave = pcall(frame.HasScript, frame, "OnHyperlinkLeave")
  if not (enterOk and hasEnter and leaveOk and hasLeave) then
    return false
  end
  local ok = pcall(frame.HookScript, frame, "OnHyperlinkEnter", function(self, link)
    pcall(Keybind.OnLinkEnter, self, link)
  end)
  if not ok then
    return false
  end
  pcall(frame.HookScript, frame, "OnHyperlinkLeave", function(self)
    pcall(Keybind.OnLinkLeave, self)
  end)
  hookedChatFrames[frame] = true
  return true
end

--- Hooks every chat frame there is now. Answers how many chat frames carry the hover hooks.
function Keybind.HookChatFrames()
  local count = 0
  for _, frame in ipairs(chatFrameList()) do
    if hookChatFrame(frame) then
      count = count + 1
    end
  end
  Keybind.chatFramesHooked = count
  return count
end

-- Hooks the chat frames, and FCF_OpenTemporaryWindow so a whisper window made later is hooked
-- as it opens. Once per session; answers whether any chat frame carries the hooks.
local function hookChatLinks()
  if not Keybind.chatWindowHooked then
    local hook = rawget(_G, "hooksecurefunc")
    if type(hook) == "function" and type(rawget(_G, "FCF_OpenTemporaryWindow")) == "function" then
      local ok = pcall(hook, "FCF_OpenTemporaryWindow", function()
        pcall(Keybind.HookChatFrames)
      end)
      Keybind.chatWindowHooked = ok and true or nil
    end
  end
  return Keybind.HookChatFrames() > 0
end

--- The /itemtree debug line for click to open (brief LC1-full), read from what installed.
function Keybind.DebugLine()
  return Keybind.ClickOpenLine({
    mouse = Keybind.mouseWatched,
    funnel = Keybind.clickHooked,
    links = Keybind.linkHooked,
    hoverLink = Keybind.HoveredLinkId(),
  })
end

-- Listens for the press itself, once per session. The event frame is the one made at the foot
-- of this file, and a spec puts its own table there. A client that has never heard of the
-- event refuses to register it, which leaves the funnel hook as the only path.
local function watchMouse()
  if Keybind.mouseWatched then
    return true
  end
  local frame = Keybind.eventFrame
  if type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return false
  end
  -- An unknown event raises on one client and answers false on another, so both are refusals.
  local ok, registered = pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
  if not ok or registered == false then
    return false
  end
  Keybind.mouseWatched = true
  return true
end

-- Hooks the funnel, once per session.
local function hookItemClick()
  if Keybind.clickHooked then
    return true
  end
  local hook = rawget(_G, "hooksecurefunc")
  local handler = rawget(_G, "HandleModifiedItemClick")
  if type(hook) ~= "function" or type(handler) ~= "function" then
    return false
  end
  local ok = pcall(hook, "HandleModifiedItemClick", function(link)
    pcall(Keybind.OnModifiedItemClick, link)
  end)
  if not ok then
    return false
  end
  Keybind.clickHooked = true
  return true
end

-- Puts both paths in place, and is idempotent: each half remembers itself, so a second call
-- after a later login event costs nothing. The setting is read at click time rather than here,
-- so changing it in the settings panel takes effect on the next click with no reinstalling,
-- and turning it off leaves both paths in place deciding against opening anything. Returns
-- true when at least one path is in place.
function Keybind.InstallClickOpen()
  local watching = watchMouse()
  local hooked = hookItemClick()
  -- Brief LC1-full: chat links directly, and the hotkey over a hovered link.
  local linked = hookItemRef()
  local hovering = hookChatLinks()
  return watching or hooked or linked or hovering
end

-- Labels for the Key Bindings panel. The client looks up BINDING_HEADER_<header> and
-- BINDING_NAME_<name> for the header and the row that Bindings.xml declares.
-- The row label is kept short: the Key Bindings panel and the settings panel both truncate
-- this column at about twenty five characters, and "Open the tree for the hovered item" was
-- cut to "Open the tree for the hove...". The full sentence is the row tooltip instead.
_G.BINDING_HEADER_ITEMTREE = L["ItemTree"]
_G.BINDING_NAME_ITEMTREE_OPEN = L["Tree for hovered item"]
_G.BINDING_NAME_ITEMTREE_BOSSLOOT = L["Open Boss loot"]

-- Bindings.xml can only call a global, so this is the entry point it names.
function _G.ItemTree_OpenHovered()
  return Keybind.OpenHovered()
end

-- Brief B1: the second binding's entry point.
function _G.ItemTree_OpenBossLoot()
  return Keybind.OpenBossLoot()
end

-- What the event frame runs, named so a spec can drive the whole dispatch with a fake frame.
-- The signature is the one SetScript hands an OnEvent script: the frame, the event name, then
-- the event's own arguments, which for GLOBAL_MOUSE_DOWN is the button name.
function Keybind.OnEvent(frame, event, arg1)
  if event == "GLOBAL_MOUSE_DOWN" then
    pcall(Keybind.OnGlobalMouseDown, arg1)
    return
  end
  if event == "UPDATE_BINDINGS" then
    Keybind.Changed()
    return
  end
  -- Click to open is installed from here rather than at file scope: the client defines
  -- HandleModifiedItemClick in Blizzard_ItemButton, which is loaded by the time the player
  -- logs in but not necessarily by the time this file runs. InstallClickOpen is idempotent.
  pcall(Keybind.InstallClickOpen)
  local charDb = ItemTree.charDb
  if not charDb then
    return
  end
  pcall(Keybind.ApplyDefault)
  if charDb.keybindDefaultTried and type(frame) == "table" and type(frame.UnregisterEvent) == "function" then
    pcall(frame.UnregisterEvent, frame, "PLAYER_LOGIN")
    pcall(frame.UnregisterEvent, frame, "PLAYER_ENTERING_WORLD")
  end
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  -- PLAYER_LOGIN is the normal path: Core/Init.lua fills ItemTree.charDb from ADDON_LOADED,
  -- which always fires first, so the per character flag is there to read. PLAYER_ENTERING_WORLD
  -- is the retry for a client where it somehow is not, and ApplyDefault is idempotent, so a
  -- second call after the flag is set does nothing.
  --
  -- UPDATE_BINDINGS stays registered for the life of the session: it is what the client fires
  -- when any binding changes, wherever the change came from, so the tooltip hint and the
  -- settings control follow a key set in the Key Bindings panel just as well as one set here.
  --
  -- The same frame carries GLOBAL_MOUSE_DOWN, registered by InstallClickOpen at login rather
  -- than here, so a client that has never heard of the event simply refuses it there.
  local ok, loader = pcall(createFrame, "Frame")
  if ok and type(loader) == "table" then
    Keybind.eventFrame = loader
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.RegisterEvent, loader, "PLAYER_ENTERING_WORLD")
    pcall(loader.RegisterEvent, loader, "UPDATE_BINDINGS")
    pcall(loader.SetScript, loader, "OnEvent", Keybind.OnEvent)
  end
end

return Keybind
