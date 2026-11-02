-- The Summary HUD, ItemTree's single Edit Mode element.
--
-- One small movable panel, a single row about ITEMTREE_CHROME_TITLEBAR_H tall: the item icon,
-- the quality coloured item name, the same summary line the item tooltip draws, and the badge
-- cluster. It follows the item under the cursor, keeps showing the last one for EditMode.HOLD
-- seconds after the pointer leaves, fades over the last EditMode.FADE of that and then goes.
-- A left click opens that item in the main window.
--
-- Design components: chrome/SummaryHud.jsx and the Edit Mode screen in
-- ui_kits/itemtree_addon/ScreensOther.jsx.
--
-- Anatomy (Theme.sizes), see EditMode.Anatomy:
--   ITEMTREE_ICON_TREE 20 item icon, ITEMTREE_BADGE_SIZE_TREE 16 badges
--   ITEMTREE_PAD_TIGHT 8 padding, ITEMTREE_SPACE_2 8 gap between the parts
--   ITEMTREE_CHROME_TITLEBAR_H 28 height for the single row
--   ITEMTREE_EDITMODE_SELECTION is the selection outline colour
--
-- Why this is not a real Edit Mode system. EditModeManagerFrame walks its registered systems
-- with secureexecuterange (Blizzard_EditMode/Shared/EditModeManager.lua on the classic_era
-- branch of the wow-ui-source mirror), a system is keyed by an Enum.EditModeSystem value an
-- addon cannot add to, and the layout is written through protected account settings. An addon
-- frame in that list taints the lot, and the Forever beta ships no Blizzard_EditMode at all.
-- So this is a plain movable frame, locked by default, with an Unlock tick box in settings and
-- /itemtree hud unlock. Where the client does have Edit Mode, the manager's OnShow and OnHide
-- are hooked (HasScript checked, pcall'd) so the panel unlocks while the player is in Edit
-- Mode and locks again when they leave: it behaves like an element without registering one.
--
-- Nothing here is protected, so the panel is free to appear and move in combat.
--
-- While the setting is off no frame is built, nothing is hooked and no OnUpdate runs: the
-- whole file costs one table.
--
-- EditMode.Anatomy, LayoutWidth, ScaleFor, HoldDecision, Position and Model are pure and run
-- under busted. Everything below the divider is guarded, so this file loads with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local EditMode = {}
ItemTree.UI.EditMode = EditMode

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

-- How long the last item stays on screen after the pointer leaves it, and how much of that
-- tail is spent fading out. The design does not say, so this is the brief's fallback: hold
-- three seconds, and spend the last half second fading rather than blinking out.
EditMode.HOLD = 3.0
EditMode.FADE = 0.5

-- How often the cursor is asked what it is over. Ten times a second is well under the rate the
-- client rebuilds a tooltip that is already on screen, and is the only recurring cost the panel
-- has while it is switched on.
EditMode.POLL = 0.1

-- Badges shown at once, the same cap the tooltip block uses.
EditMode.MAX_BADGES = 3

-- The panel never draws narrower than this, so an unlocked empty panel is still something the
-- player can grab.
EditMode.MIN_WIDTH = 140

-- Rough width of one character, for a client that will not measure a font string. Only ever a
-- fallback: the panel is a little wide or a little narrow, never absent.
EditMode.CHAR_WIDTH = 6

EditMode.FRAME_NAME = "ItemTreeSummaryHud"
EditMode.STRATA = "MEDIUM"

-- The words on the label above the panel while it is unlocked (players know the panel as the
-- fixed position tooltip), and what the panel says while it is unlocked with nothing under the
-- cursor.
EditMode.LABEL = "ItemTree fixed position tooltip"

EditMode.FONT_TEMPLATE = "GameFontNormalSmall"
EditMode.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

local function themeSize(key, fallback)
  local sizes = Theme and Theme.sizes
  local value = sizes and sizes[key]
  if type(value) == "number" and value > 0 then
    return value
  end
  return fallback
end

-- The panel's measurements, read off Theme with the design's numbers as the fallback for a
-- build where UI/Theme.lua did not load. Pure.
function EditMode.Anatomy()
  return {
    height = themeSize("ITEMTREE_CHROME_TITLEBAR_H", 28),
    icon = themeSize("ITEMTREE_ICON_TREE", 20),
    badge = themeSize("ITEMTREE_BADGE_SIZE_TREE", 16),
    pad = themeSize("ITEMTREE_PAD_TIGHT", 8),
    gap = themeSize("ITEMTREE_SPACE_2", 8),
    edge = themeSize("ITEMTREE_BORDER_HAIRLINE", 1),
    handle = 7,
  }
end

-- How wide the whole panel is for the parts it is drawing: padding, the icon, then the name,
-- the summary line and the badge cluster, each preceded by a gap and each left out when it is
-- not drawn (width 0). Never narrower than EditMode.MIN_WIDTH. Pure.
function EditMode.LayoutWidth(nameWidth, lineWidth, badgeWidth)
  local box = EditMode.Anatomy()
  local width = box.pad + box.icon
  for _, part in ipairs({ nameWidth, lineWidth, badgeWidth }) do
    local value = tonumber(part) or 0
    if value > 0 then
      width = width + box.gap + value
    end
  end
  width = width + box.pad
  if width < EditMode.MIN_WIDTH then
    return EditMode.MIN_WIDTH
  end
  return width
end

-- The scale the panel is drawn at: the window scale setting, held inside the range the window
-- takes, on top of ItemTree.SCALE_BASE. There is deliberately no screen normalising here. The
-- window fits itself to the monitor because it is a document; a HUD element is furniture, and
-- growing it on a bigger screen is not what the player who placed it asked for. Pure.
function EditMode.ScaleFor(setting)
  local value = tonumber(setting)
  if not value then
    value = 1.0
  end
  local low = tonumber(ItemTree.SCALE_MIN) or 0.5
  local high = tonumber(ItemTree.SCALE_MAX) or 1.5
  if value < low then
    value = low
  elseif value > high then
    value = high
  end
  return value * (tonumber(ItemTree.SCALE_BASE) or 0.85)
end

-- What the panel does this tick. hovering says whether an item is under the cursor right now,
-- elapsed is how long it is since one was (nil when nothing has been), hold is how long the
-- last item stays and fade how much of the tail is spent fading. Returns the state, one of
-- "show", "hold" or "hide", and the alpha to draw at. Pure.
function EditMode.HoldDecision(hovering, elapsed, hold, fade)
  if hovering then
    return "show", 1
  end
  elapsed = tonumber(elapsed)
  if not elapsed then
    return "hide", 0
  end
  hold = tonumber(hold) or EditMode.HOLD
  fade = tonumber(fade) or EditMode.FADE
  if fade < 0 then
    fade = 0
  end
  if fade > hold then
    fade = hold
  end
  if elapsed >= hold then
    return "hide", 0
  end
  local remaining = hold - elapsed
  if fade > 0 and remaining < fade then
    return "hold", remaining / fade
  end
  return "hold", 1
end

-- Where the panel sits. saved is ItemTree.charDb.hud, defaults ItemTree.CHAR_DEFAULTS.hud,
-- width and height the panel's own size, screenW and screenH what the client reports (leave
-- them out to skip the clamp) and scale what the panel is drawn at, because a scaled frame
-- measures itself in its own units. The anchor point is remembered too, so the offsets are
-- clamped to the screen extent less the panel's own size whichever corner it hangs from.
-- Returns { point, x, y }. Pure.
function EditMode.Position(saved, defaults, width, height, screenW, screenH, scale)
  saved = type(saved) == "table" and saved or EMPTY
  defaults = type(defaults) == "table" and defaults or EMPTY
  local point = type(saved.point) == "string" and saved.point or defaults.point
  if type(point) ~= "string" then
    point = "CENTER"
  end
  local x = tonumber(saved.x) or tonumber(defaults.x) or 0
  local y = tonumber(saved.y) or tonumber(defaults.y) or 0
  width = tonumber(width) or 0
  height = tonumber(height) or 0
  screenW, screenH = tonumber(screenW), tonumber(screenH)
  scale = tonumber(scale)
  if not scale or scale <= 0 then
    scale = 1
  end
  if screenW and screenW > 0 then
    local limit = math.max(0, screenW / scale - width)
    x = math.max(-limit, math.min(x, limit))
  end
  if screenH and screenH > 0 then
    local limit = math.max(0, screenH / scale - height)
    y = math.max(-limit, math.min(y, limit))
  end
  return { point = point, x = x, y = y }
end

local function settings()
  return (ItemTree.db and ItemTree.db.settings) or EMPTY
end

-- A tick box that defaults to on: nil reads as on, the way UI/Tooltip.lua reads its own.
local function settingOn(source, key)
  local value = source[key]
  if value == nil then
    return true
  end
  return value and true or false
end

-- The panel is a new thing on the player's screen, so it starts off and nil reads as off.
function EditMode.Enabled()
  return settings().hudEnabled and true or false
end

function EditMode.ShowBadges()
  return settingOn(settings(), "hudShowBadges")
end

function EditMode.ShowSummary()
  return settingOn(settings(), "hudShowSummary")
end

-- Whether the panel can be dragged. The stored tick box is one way in; the client's own Edit
-- Mode being open is the other, and it is not saved anywhere.
function EditMode.Unlocked()
  if EditMode.editModeOpen then
    return true
  end
  return settings().hudUnlocked and true or false
end

-- The item's icon, through UI/Assets.lua, which answers from the shipped data first and the
-- client's own lookup after. nil where neither could say.
local function itemIcon(itemId)
  if not (Assets and type(Assets.ItemIcon) == "function") then
    return nil
  end
  local ok, icon = pcall(Assets.ItemIcon, itemId)
  if ok and icon then
    return icon
  end
  return nil
end

-- Name and quality. Core's Graph first, so the panel says the same thing the window does: the
-- data build's name, the live client's where the realm has found an item the build withholds,
-- and "Undiscovered mail head" for a withheld item nothing has found yet. Then ItemTree's own
-- data for a build with no Graph, then the client's GetItemInfo for an item this build ships no
-- row for, and finally the id on its own rather than an empty panel.
local function nameAndQualityFrom(getItemInfo, itemId)
  if type(getItemInfo) ~= "function" then
    return nil, nil
  end
  local ok, name, _, quality = pcall(getItemInfo, itemId)
  if ok and type(name) == "string" and name ~= "" then
    return name, tonumber(quality)
  end
  return nil, nil
end

-- The modern C_Item.GetItemInfo first, the global as the fallback, as UI/Client.lua does. One
-- call, or two when the first answers nothing usable.
local function clientNameAndQuality(itemId)
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" then
    local name, quality = nameAndQualityFrom(itemApi.GetItemInfo, itemId)
    if name then
      return name, quality
    end
  end
  return nameAndQualityFrom(rawget(_G, "GetItemInfo"), itemId)
end

-- Whether the item rows are loaded (brief U3: they ship in the load on demand ItemTree_Data).
local function itemRowsLoaded()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.OnDemandLoaded) ~= "function" then
    return true
  end
  local ok, loaded = pcall(data.OnDemandLoaded, data)
  return not ok or loaded ~= false
end

local function itemNameAndQuality(itemId)
  -- Brief U3: while the item rows are not loaded the client names the item first, since the
  -- panel shows the item under the cursor, which the client has; the chain below would load the
  -- data addon to say the same name. An item the client cannot name falls through to it.
  if not itemRowsLoaded() then
    local name, quality = clientNameAndQuality(itemId)
    if name then
      return name, quality
    end
  end
  local graph = ItemTree.Graph
  if graph and type(graph.Node) == "function" and type(graph.Key) == "function" then
    local ok, node = pcall(graph.Node, graph.Key("item", itemId))
    if ok and type(node) == "table" and type(node.name) == "string" and node.name ~= "" then
      return node.name, tonumber(node.quality)
    end
  end
  local data = ItemTree.Data
  if data and type(data.GetItem) == "function" then
    local ok, item = pcall(data.GetItem, data, itemId)
    if ok and type(item) == "table" and type(item.n) == "string" and item.n ~= "" then
      return item.n, tonumber(item.q)
    end
  end
  local name, quality = clientNameAndQuality(itemId)
  if name then
    return name, quality
  end
  return tostring(itemId), nil
end

-- The badge kinds for an item, in the tooltip's own priority order and capped the same way.
-- Both modules are read through the namespace and guarded, so a build missing either draws no
-- badges rather than failing.
local function badgeKinds(itemId)
  local tooltip = ItemTree.Tooltip
  if not (tooltip and type(tooltip.BadgeKinds) == "function") then
    return {}
  end
  local ok, kinds = pcall(tooltip.BadgeKinds, itemId)
  if not ok or type(kinds) ~= "table" then
    return {}
  end
  local badges = ItemTree.Badges
  if badges and type(badges.Sort) == "function" then
    local sorted, result = pcall(badges.Sort, kinds, EditMode.MAX_BADGES)
    if sorted and type(result) == "table" then
      return result
    end
  end
  return kinds
end

-- The summary line, which is the same words and the same colour the item tooltip's uses line
-- carries: Core/Graph.lua counts them and UI/Tooltip.lua words them. Nothing is copied here,
-- both are called through the namespace and guarded.
local function summaryLine(itemId)
  local tooltip = ItemTree.Tooltip
  if not (tooltip and type(tooltip.UsesText) == "function") then
    return nil, nil
  end
  local summary
  local graph = ItemTree.Graph
  if graph and type(graph.Summary) == "function" then
    local ok, result = pcall(graph.Summary, itemId)
    if ok then
      summary = result
    end
  end
  -- Brief F155: the other side's quests out of the count while "Hide other faction data" is on, the
  -- number the tooltip and the item page say (UI/Tooltip.lua Tooltip.WithoutOtherSide). Brief QS2b:
  -- and the quests only the other side was seen taking, whatever the setting says.
  if
    type(summary) == "table"
    and type(tooltip.HiddenFaction) == "function"
    and type(tooltip.WithoutOtherSide) == "function"
  then
    local okSide, faction = pcall(tooltip.HiddenFaction)
    local seen = nil
    if type(tooltip.SeenFaction) == "function" then
      local okSeen, answer = pcall(tooltip.SeenFaction)
      seen = okSeen and answer or nil
    end
    faction = okSide and faction or nil
    if faction or seen then
      local okCount, counted = pcall(tooltip.WithoutOtherSide, summary, faction, seen)
      if okCount and type(counted) == "table" then
        summary = counted
      end
    end
  end
  local ok, text, colorKey = pcall(tooltip.UsesText, summary)
  if not ok or type(text) ~= "string" then
    return nil, nil
  end
  return text, colorKey
end

-- Everything the panel draws for one item: { itemId, icon, name, quality, badges, line,
-- lineColorKey }. badges is empty and line is nil where the settings say not to draw them, so
-- the draw never has to ask a second time. nil for anything that is not an item id. Pure in
-- the sense the rest of this project means it: it reads the loaded modules through the
-- namespace, guarded, and needs no client.
function EditMode.Model(itemId, source)
  itemId = tonumber(itemId)
  if not itemId then
    return nil
  end
  source = type(source) == "table" and source or settings()
  local name, quality = itemNameAndQuality(itemId)
  local model = {
    itemId = itemId,
    icon = itemIcon(itemId),
    name = name,
    quality = quality,
    badges = {},
  }
  if settingOn(source, "hudShowBadges") then
    model.badges = badgeKinds(itemId)
  end
  if settingOn(source, "hudShowSummary") then
    model.line, model.lineColorKey = summaryLine(itemId)
  end
  return model
end

-- One line for /itemtree debug: what the panel is set to, where it is anchored and which item
-- it is showing. Settings and an item id only; no character, realm or account data.
function EditMode.StatusLine()
  local saved = (ItemTree.charDb and type(ItemTree.charDb.hud) == "table") and ItemTree.charDb.hud or EMPTY
  return string.format(
    "HUD: %s, badges %s, summary %s, %s, point %s %s %s, item %s",
    EditMode.Enabled() and "on" or "off",
    EditMode.ShowBadges() and "on" or "off",
    EditMode.ShowSummary() and "on" or "off",
    EditMode.Unlocked() and "unlocked" or "locked",
    tostring(saved.point or "none"),
    tostring(saved.x or 0),
    tostring(saved.y or 0),
    tostring(EditMode.itemId or "none")
  )
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

local function themeColor(key)
  if not (Theme and type(Theme.ColorTable) == "function") then
    return nil
  end
  return Theme.ColorTable(key)
end

local function tint(texture, key, alpha)
  local color = themeColor(key)
  if not color or type(texture) ~= "table" or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(color.r, color.g, color.b)
  if type(texture.SetAlpha) == "function" then
    texture:SetAlpha(alpha or color.a or 1)
  end
  return true
end

local function colourText(fontString, key)
  local color = themeColor(key)
  if not color or type(fontString) ~= "table" or type(fontString.SetTextColor) ~= "function" then
    return false
  end
  fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
  return true
end

-- The client's own quality colours where it has them, the design tokens where it does not,
-- exactly as UI/Frame.lua picks a title colour.
local function qualityRGB(quality)
  local colors = rawget(_G, "ITEM_QUALITY_COLORS")
  local entry = type(colors) == "table" and quality and colors[quality] or nil
  if type(entry) == "table" and tonumber(entry.r) then
    return entry.r, entry.g, entry.b
  end
  local key = "ITEMTREE_COLOR_QUALITY_COMMON"
  if Theme and type(Theme.QualityKey) == "function" then
    key = Theme.QualityKey(quality)
  end
  local color = themeColor(key)
  if not color then
    return nil
  end
  return color.r, color.g, color.b
end

-- A flat fill in one Theme colour. Every texture goes through Assets, so the path lives in one
-- table and the harness can report it.
local function wash(parent, layer, colorKey)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(parent.CreateTexture, parent, nil, layer)
  if not ok or type(texture) ~= "table" then
    return nil
  end
  if Assets and type(Assets.Apply) == "function" and type(Assets.Has) == "function" and Assets.Has("FILL_WHITE8X8") then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey)
  return texture
end

local function newFrame(kind, name, parent)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, name, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(EditMode.FONT_FALLBACKS) do
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

-- A font string that is never fontless: the template is asked for at creation, and a client
-- that will not take one gets a font object by hand, so a SetText is never the first thing to
-- touch the font.
local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, EditMode.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- Body face at one of the Theme sizes, a 1px shadow and one line. SetFont answers false rather
-- than raising where the face cannot be loaded, so the answer is read and a font object put
-- back: a font string that lost its font raises from inside the next SetText.
local function styleText(fontString, sizeKey, colorKey)
  if type(fontString) ~= "table" then
    return nil
  end
  local fonts = Theme and Theme.fonts
  local face = fonts and fonts.ITEMTREE_FONT_BODY
  local fontSize = (Theme and Theme.fontSizes and Theme.fontSizes[sizeKey]) or 12
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    pcall(fontString.SetShadowOffset, fontString, outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      pcall(fontString.SetShadowColor, fontString, outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  colourText(fontString, colorKey)
  return fontString
end

-- Every word this panel draws goes through here. The font is put back first and the write
-- itself is pcall'd, so a client that can give a font string no font at all costs the panel a
-- blank label rather than the whole draw.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- What the client says a font string is, or an estimate from the character count for one that
-- will not measure itself. Nothing is drawn off screen either way: the panel is a little wide
-- or a little narrow, never missing.
local function textWidth(fontString, text)
  if type(text) ~= "string" or text == "" then
    return 0
  end
  if type(fontString) == "table" and type(fontString.GetStringWidth) == "function" then
    local ok, width = pcall(fontString.GetStringWidth, fontString)
    width = ok and tonumber(width) or nil
    if width and width > 0 then
      return width
    end
  end
  return #text * EditMode.CHAR_WIDTH
end

local function showRegion(region, shown)
  if type(region) ~= "table" then
    return false
  end
  if shown then
    if type(region.Show) == "function" then
      return (pcall(region.Show, region))
    end
    return false
  end
  if type(region.Hide) == "function" then
    return (pcall(region.Hide, region))
  end
  return false
end

local function screenSize()
  local width = rawget(_G, "GetScreenWidth")
  local height = rawget(_G, "GetScreenHeight")
  local w = type(width) == "function" and tonumber(width()) or nil
  local h = type(height) == "function" and tonumber(height()) or nil
  return w, h
end

local function now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return 0
  end
  local ok, value = pcall(getTime)
  return (ok and tonumber(value)) or 0
end

local round = ItemTree.Util.Round

-- The item under the cursor, through the resolver the key binding and the click already share.
-- UI/Keybind.lua hangs off ItemTree.Keybind; ItemTree.UI.Keybind is checked as well so a move
-- of that table does not take the panel with it.
function EditMode.HoveredItemId()
  local keybind = ItemTree.Keybind or (ItemTree.UI and ItemTree.UI.Keybind)
  if not (type(keybind) == "table" and type(keybind.HoveredItemId) == "function") then
    return nil
  end
  local ok, itemId = pcall(keybind.HoveredItemId)
  if not ok then
    return nil
  end
  return tonumber(itemId)
end

-- Opens whatever the panel is showing, in the main window. Keybind.OpenItem builds the node key
-- and calls Frame.Open, so the click lands exactly where the bound key would.
function EditMode.OpenCurrent()
  local itemId = tonumber(EditMode.itemId)
  if not itemId then
    return false
  end
  local keybind = ItemTree.Keybind or (ItemTree.UI and ItemTree.UI.Keybind)
  if type(keybind) == "table" and type(keybind.OpenItem) == "function" then
    local ok, opened = pcall(keybind.OpenItem, itemId)
    if ok and opened then
      return true
    end
  end
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if not (frame and type(frame.Open) == "function") then
    return false
  end
  local ok, opened = pcall(frame.Open, "item:" .. tostring(itemId))
  return (ok and opened) and true or false
end

-- The selection outline the design draws in Edit Mode: a hairline all round in the selection
-- colour, with a small square at each corner, plus the label above the panel. Four fills rather
-- than a nine slice, the way UI/Sidebar.lua draws its inset edge.
local function buildOutline(frame)
  local box = EditMode.Anatomy()
  local key = "ITEMTREE_EDITMODE_SELECTION"
  local edges = {}
  for index = 1, 4 do
    edges[index] = wash(frame, "OVERLAY", key)
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  if top then
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(box.edge)
  end
  if bottom then
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(box.edge)
  end
  if left then
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(box.edge)
  end
  if right then
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(box.edge)
  end
  local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
  local handles = {}
  for index, corner in ipairs(corners) do
    local handle = wash(frame, "OVERLAY", key)
    if handle then
      handle:SetSize(box.handle, box.handle)
      handle:SetPoint("CENTER", frame, corner, 0, 0)
    end
    handles[index] = handle
  end
  -- The design puts the label inline with the row. It goes above the panel here instead, so
  -- turning the unlock on never changes how wide the panel is or where its parts sit.
  local label = newFontString(frame, "OVERLAY")
  if label then
    styleText(label, "ITEMTREE_FONTSIZE_BODY_SM", key)
    label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    setText(label, L[EditMode.LABEL])
  end
  return { edges = edges, handles = handles, label = label }
end

-- The panel's own parts on a frame: the item icon, the name, the summary line and the badge
-- cluster, laid out left to right exactly as the design draws them. Shared by the panel itself and
-- by EditMode.DrawPreview, so the settings panel's example is this code and not a copy of it.
local function buildParts(frame)
  local box = EditMode.Anatomy()
  local ok, icon = pcall(frame.CreateTexture, frame, nil, "ARTWORK")
  if ok and type(icon) == "table" then
    icon:SetSize(box.icon, box.icon)
    icon:SetPoint("LEFT", frame, "LEFT", box.pad, 0)
    frame.icon = icon
  end

  frame.nameText = newFontString(frame, "OVERLAY")
  if frame.nameText then
    styleText(frame.nameText, "ITEMTREE_FONTSIZE_BODY_MD", "ITEMTREE_COLOR_TEXT_BODY")
    if frame.icon then
      frame.nameText:SetPoint("LEFT", frame.icon, "RIGHT", box.gap, 0)
    else
      frame.nameText:SetPoint("LEFT", frame, "LEFT", box.pad, 0)
    end
  end

  frame.lineText = newFontString(frame, "OVERLAY")
  if frame.lineText then
    styleText(frame.lineText, "ITEMTREE_FONTSIZE_BODY_SM", "ITEMTREE_COLOR_TEXT_MUTED")
    if frame.nameText then
      frame.lineText:SetPoint("LEFT", frame.nameText, "RIGHT", box.gap, 0)
    end
  end

  local badges = ItemTree.Badges
  if badges and type(badges.CreateCluster) == "function" then
    local made, cluster = pcall(badges.CreateCluster, frame, "tree", EditMode.MAX_BADGES, "row")
    if made and type(cluster) == "table" then
      frame.badges = cluster
      if frame.lineText then
        cluster:SetPoint("LEFT", frame.lineText, "RIGHT", box.gap, 0)
      end
      showRegion(cluster, false)
    end
  end
end

-- Builds the panel once. Returns nil outside the client, which is what leaves every other
-- entry point answering false rather than raising.
function EditMode.Build()
  if EditMode.frame then
    return EditMode.frame
  end
  local box = EditMode.Anatomy()
  local parent = rawget(_G, "UIParent")
  local frame = newFrame("Frame", EditMode.FRAME_NAME, parent)
  if not frame then
    return nil
  end
  EditMode.frame = frame
  frame:Hide()
  frame:SetSize(EditMode.MIN_WIDTH, box.height)
  if type(frame.SetFrameStrata) == "function" then
    pcall(frame.SetFrameStrata, frame, EditMode.STRATA)
  end
  if type(frame.SetMovable) == "function" then
    pcall(frame.SetMovable, frame, true)
  end
  if type(frame.SetClampedToScreen) == "function" then
    pcall(frame.SetClampedToScreen, frame, true)
  end
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end

  frame.background = wash(frame, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_TOOLTIP")
  if frame.background then
    frame.background:SetAllPoints(frame)
    showRegion(frame.background, false)
  end
  frame.outline = buildOutline(frame)

  buildParts(frame)

  if type(frame.RegisterForDrag) == "function" then
    pcall(frame.RegisterForDrag, frame, "LeftButton")
  end
  frame:SetScript("OnDragStart", function(self)
    if not EditMode.Unlocked() or type(self.StartMoving) ~= "function" then
      return
    end
    pcall(self.StartMoving, self)
    self.moving = true
  end)
  frame:SetScript("OnDragStop", function(self)
    if not self.moving then
      return
    end
    self.moving = nil
    if type(self.StopMovingOrSizing) == "function" then
      pcall(self.StopMovingOrSizing, self)
    end
    EditMode.SavePosition()
  end)
  frame:SetScript("OnMouseUp", function(_self, button)
    if EditMode.Unlocked() or button ~= "LeftButton" then
      return
    end
    EditMode.OpenCurrent()
  end)
  return frame
end

-- Brief OPT3: the last state ApplyState put on the panel, so a tick that would apply the very
-- same thing (the same item still hovered at full alpha, or nothing hovered for a while) leaves
-- the panel as it is instead of showing, hiding and fading every part again ten times a second.
-- It holds the frame, the decision, the unlock, the item and the three flags the parts are shown
-- by, and the answer ApplyState gave. Anything else that draws on or changes the panel (Draw,
-- ApplyUnlocked, Refresh, Teardown) forgets it, so the next tick applies in full.
local applied = { frame = nil }

local function forgetApplied()
  applied.frame = nil
end

-- Exposed for the spec, and for any caller that has touched the panel's parts itself.
EditMode.ForgetApplied = forgetApplied

-- Shows or hides the parts that need an item behind them, and takes the mouse away with them:
-- a panel with nothing to say must not eat a click meant for the world behind it. An unlocked
-- panel keeps the mouse either way, because that is what a drag is taken with.
local function showContent(frame, shown)
  showRegion(frame.icon, shown)
  showRegion(frame.nameText, shown)
  showRegion(frame.lineText, shown and frame.lineTextShown)
  showRegion(frame.badges, shown and frame.badgesShown)
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, (shown or EditMode.Unlocked()) and true or false)
  end
end

-- Draws one model onto a frame carrying the parts buildParts made, and sizes the row around it.
-- A nil model leaves the frame empty at its minimum width, which is what an unlocked panel with
-- nothing hovered shows.
local function drawParts(frame, model)
  local box = EditMode.Anatomy()
  local nameWidth, lineWidth, badgeWidth = 0, 0, 0
  frame.emptyDrawn = type(model) ~= "table"
  if type(model) == "table" then
    if frame.icon then
      local icon = model.icon
      if icon then
        pcall(frame.icon.SetTexture, frame.icon, icon)
      end
    end
    if frame.nameText then
      setText(frame.nameText, model.name)
      local r, g, b = qualityRGB(model.quality)
      if r and type(frame.nameText.SetTextColor) == "function" then
        pcall(frame.nameText.SetTextColor, frame.nameText, r, g, b)
      end
      nameWidth = textWidth(frame.nameText, model.name)
    end
    if frame.lineText then
      local text = model.line
      frame.lineTextShown = type(text) == "string" and text ~= ""
      setText(frame.lineText, text or "")
      colourText(frame.lineText, model.lineColorKey or "ITEMTREE_COLOR_TEXT_MUTED")
      if frame.lineTextShown then
        lineWidth = textWidth(frame.lineText, text)
      end
    end
    -- The item is the cluster's subject, set before the kinds so a mark made there inherits it:
    -- that is what lets a hovered Changed badge list the changes, the way the info panel header
    -- and the tree rows do. Without it the hover had the heading and nothing under it.
    if frame.badges and type(frame.badges.SetSubject) == "function" then
      pcall(frame.badges.SetSubject, frame.badges, "items", model.itemId)
    end
    if frame.badges and type(frame.badges.SetKinds) == "function" then
      local ok, kinds = pcall(frame.badges.SetKinds, frame.badges, model.badges or {})
      local count = (ok and type(kinds) == "table") and #kinds or 0
      frame.badgesShown = count > 0
      if count > 0 then
        local badges = ItemTree.Badges
        if badges and type(badges.ClusterExtent) == "function" then
          local sized, width = pcall(badges.ClusterExtent, count, box.badge, nil, "row")
          badgeWidth = (sized and tonumber(width)) or count * box.badge
        else
          badgeWidth = count * box.badge
        end
      end
    end
  else
    frame.lineTextShown, frame.badgesShown = false, false
    if frame.nameText then
      setText(frame.nameText, L["Hover an item"])
      colourText(frame.nameText, "ITEMTREE_COLOR_TEXT_MUTED")
    end
    if frame.badges and type(frame.badges.SetSubject) == "function" then
      pcall(frame.badges.SetSubject, frame.badges, nil, nil)
    end
    if frame.badges and type(frame.badges.SetKinds) == "function" then
      pcall(frame.badges.SetKinds, frame.badges, {})
    end
  end
  -- The cluster hangs off whichever part is actually drawn before it, so turning the summary
  -- line off closes the gap it left rather than pushing the badges past the panel's edge.
  if frame.badges and type(frame.badges.SetPoint) == "function" then
    local anchor = frame.lineTextShown and frame.lineText or frame.nameText
    if anchor then
      if type(frame.badges.ClearAllPoints) == "function" then
        pcall(frame.badges.ClearAllPoints, frame.badges)
      end
      pcall(frame.badges.SetPoint, frame.badges, "LEFT", anchor, "RIGHT", box.gap, 0)
    end
  end
  frame.contentWidth = EditMode.LayoutWidth(nameWidth, lineWidth, badgeWidth)
  frame:SetSize(frame.contentWidth, box.height)
  return true
end

-- Draws one model onto the panel. False where there is no panel.
function EditMode.Draw(model)
  local frame = EditMode.frame
  if not frame then
    return false
  end
  forgetApplied()
  return drawParts(frame, model)
end

-- Brief U2: the settings panel's example of the fixed position tooltip. Builds the panel's parts
-- on a frame the caller owns (once), draws the model onto it with the panel's own code and shows
-- the parts the model has, with the mouse off. None of the panel's own state is touched: no
-- position, no scale, no drag, no outline, no hold timer. Answers the width and height drawn, or
-- nil where the frame will take no parts.
function EditMode.DrawPreview(frame, model)
  if type(frame) ~= "table" or type(frame.SetSize) ~= "function" then
    return nil
  end
  if not frame.hudParts then
    local ok = pcall(buildParts, frame)
    if not ok then
      return nil
    end
    frame.hudParts = true
  end
  local ok = pcall(drawParts, frame, model)
  if not ok then
    return nil
  end
  showRegion(frame.icon, true)
  showRegion(frame.nameText, true)
  showRegion(frame.lineText, frame.lineTextShown and true or false)
  showRegion(frame.badges, frame.badgesShown and true or false)
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end
  return frame.contentWidth, EditMode.Anatomy().height
end

-- Puts the scale on the panel. Returns the scale, or nil where there is no panel.
function EditMode.ApplyScale()
  local frame = EditMode.frame
  if not (frame and type(frame.SetScale) == "function") then
    return nil
  end
  local scale = EditMode.ScaleFor(settings().windowScale)
  if not pcall(frame.SetScale, frame, scale) then
    return nil
  end
  EditMode.scale = scale
  return scale
end

-- Puts the panel where this character left it, clamped to the screen.
function EditMode.ApplyPosition()
  local frame = EditMode.frame
  if not frame then
    return false
  end
  -- Never while the player has hold of it: re-anchoring a frame the client is moving would
  -- drop it out from under the cursor.
  if frame.moving then
    return false
  end
  local box = EditMode.Anatomy()
  local width = tonumber(frame.contentWidth) or EditMode.MIN_WIDTH
  local screenW, screenH = screenSize()
  local at = EditMode.Position(
    ItemTree.charDb and ItemTree.charDb.hud,
    ItemTree.CHAR_DEFAULTS and ItemTree.CHAR_DEFAULTS.hud,
    width,
    box.height,
    screenW,
    screenH,
    tonumber(EditMode.scale) or EditMode.ScaleFor(settings().windowScale)
  )
  if type(frame.ClearAllPoints) == "function" then
    pcall(frame.ClearAllPoints, frame)
  end
  frame:SetPoint(at.point, rawget(_G, "UIParent"), at.point, at.x, at.y)
  EditMode.at = at
  return true
end

-- Remembers where the player dragged it. Only point, x and y are written: the keys
-- CHAR_DEFAULTS.hud declares, and nothing else ever reaches saved variables from here.
function EditMode.SavePosition()
  local frame, charDb = EditMode.frame, ItemTree.charDb
  if not (frame and type(charDb) == "table" and type(frame.GetPoint) == "function") then
    return false
  end
  local hud = type(charDb.hud) == "table" and charDb.hud or {}
  charDb.hud = hud
  local ok, point, _, _, x, y = pcall(frame.GetPoint, frame)
  if not ok or type(point) ~= "string" then
    return false
  end
  hud.point = point
  hud.x = round(x) or hud.x
  hud.y = round(y) or hud.y
  return true
end

-- Puts the panel back where it started. This is what /itemtree hud reset and the settings
-- button both call.
function EditMode.ResetPosition()
  local defaults = ItemTree.CHAR_DEFAULTS and ItemTree.CHAR_DEFAULTS.hud
  local charDb = ItemTree.charDb
  if not (type(charDb) == "table" and type(defaults) == "table") then
    return false
  end
  local hud = type(charDb.hud) == "table" and charDb.hud or {}
  for key, value in pairs(defaults) do
    hud[key] = value
  end
  charDb.hud = hud
  EditMode.ApplyPosition()
  return true
end

-- The selection outline, the label and the drag background follow the unlock, and nothing
-- else does.
function EditMode.ApplyUnlocked()
  local frame = EditMode.frame
  if not frame then
    return false
  end
  forgetApplied()
  local unlocked = EditMode.Unlocked()
  showRegion(frame.background, unlocked)
  local outline = frame.outline
  if type(outline) == "table" then
    for _, edge in ipairs(outline.edges or {}) do
      showRegion(edge, unlocked)
    end
    for _, handle in ipairs(outline.handles or {}) do
      showRegion(handle, unlocked)
    end
    showRegion(outline.label, unlocked)
  end
  return unlocked
end

-- Applies one tick's decision: what is shown, and at what alpha. An unlocked panel is always
-- on screen, with or without an item, so there is something to take hold of.
function EditMode.ApplyState(state, alpha)
  local frame = EditMode.frame
  if not frame then
    return false
  end
  local unlocked = EditMode.Unlocked()
  if
    applied.frame == frame
    and applied.state == state
    and applied.alpha == alpha
    and applied.unlocked == unlocked
    and applied.itemId == EditMode.itemId
    and applied.emptyDrawn == frame.emptyDrawn
    and applied.lineTextShown == frame.lineTextShown
    and applied.badgesShown == frame.badgesShown
  then
    EditMode.applySkipped = (EditMode.applySkipped or 0) + 1
    return applied.answer
  end
  local answer = EditMode.ApplyStateNow(frame, state, alpha, unlocked)
  applied.frame, applied.state, applied.alpha, applied.unlocked = frame, state, alpha, unlocked
  applied.itemId = EditMode.itemId
  applied.emptyDrawn, applied.lineTextShown = frame.emptyDrawn, frame.lineTextShown
  applied.badgesShown, applied.answer = frame.badgesShown, answer
  return answer
end

-- The work ApplyState does when the state is new: what it always did on every tick.
function EditMode.ApplyStateNow(frame, state, alpha, unlocked)
  if state == "hide" then
    EditMode.itemId = nil
    showContent(frame, false)
    if unlocked then
      -- Only once: the empty panel is redrawn when it becomes empty, not ten times a second
      -- for as long as the player leaves it unlocked.
      if not frame.emptyDrawn then
        EditMode.Draw(nil)
      end
      showRegion(frame.nameText, true)
      if type(frame.SetAlpha) == "function" then
        pcall(frame.SetAlpha, frame, 1)
      end
      return true
    end
    if type(frame.SetAlpha) == "function" then
      pcall(frame.SetAlpha, frame, 1)
    end
    return false
  end
  showContent(frame, true)
  if type(frame.SetAlpha) == "function" then
    pcall(frame.SetAlpha, frame, tonumber(alpha) or 1)
  end
  return true
end

-- One poll. Reads what is under the cursor, redraws when it changed, and applies the hold
-- timer's answer. Takes the time so a spec can drive it without a clock.
function EditMode.Tick(at)
  at = tonumber(at) or now()
  local hovered = EditMode.HoveredItemId()
  if hovered then
    EditMode.lastSeen = at
    if hovered ~= EditMode.itemId then
      EditMode.itemId = hovered
      EditMode.Draw(EditMode.Model(hovered))
      EditMode.ApplyPosition()
    end
  end
  local elapsed
  if EditMode.lastSeen then
    elapsed = at - EditMode.lastSeen
  end
  local state, alpha = EditMode.HoldDecision(hovered ~= nil, elapsed, EditMode.HOLD, EditMode.FADE)
  EditMode.ApplyState(state, alpha)
  return state, alpha
end

local function onUpdate(frame, elapsed)
  frame.sincePoll = (frame.sincePoll or 0) + (tonumber(elapsed) or 0)
  if frame.sincePoll < EditMode.POLL then
    return
  end
  frame.sincePoll = 0
  EditMode.Tick(now())
end

-- Takes the panel off the screen and stops it costing anything: no OnUpdate, no state.
function EditMode.Teardown()
  EditMode.itemId, EditMode.lastSeen = nil, nil
  forgetApplied()
  local frame = EditMode.frame
  if not frame then
    return false
  end
  frame:SetScript("OnUpdate", nil)
  frame.sincePoll = nil
  pcall(frame.Hide, frame)
  return true
end

-- Builds, shows, scales and positions the panel for whatever the settings now say, or takes it
-- away when they say it is off. Idempotent, and the one thing every other entry point calls.
function EditMode.Refresh()
  if not EditMode.Enabled() then
    EditMode.Teardown()
    return false
  end
  local frame = EditMode.Build()
  if not frame then
    return false
  end
  forgetApplied()
  EditMode.ApplyScale()
  EditMode.ApplyUnlocked()
  local held = EditMode.itemId
  EditMode.Draw(held and EditMode.Model(held) or nil)
  EditMode.ApplyPosition()
  pcall(frame.Show, frame)
  frame.sincePoll = 0
  frame:SetScript("OnUpdate", onUpdate)
  EditMode.Tick(now())
  return true
end

-- The contract UI/Slash.lua and the settings panel use.

function EditMode.SetEnabled(enabled)
  local value = enabled and true or false
  local source = ItemTree.db and ItemTree.db.settings
  if source then
    source.hudEnabled = value
  end
  local options = ItemTree.Options
  if options and type(options.OnChanged) == "function" then
    pcall(options.OnChanged, "hudEnabled", value)
  else
    EditMode.Refresh()
  end
  return value
end

function EditMode.Toggle()
  return EditMode.SetEnabled(not EditMode.Enabled())
end

function EditMode.SetUnlocked(unlocked)
  local value = unlocked and true or false
  local source = ItemTree.db and ItemTree.db.settings
  if source then
    source.hudUnlocked = value
  end
  local options = ItemTree.Options
  if options and type(options.OnChanged) == "function" then
    pcall(options.OnChanged, "hudUnlocked", value)
  else
    EditMode.Refresh()
  end
  return value
end

-- The client's own Edit Mode opening and closing. While it is open the panel is unlocked
-- whatever the tick box says, and closing it puts the tick box's answer back.
function EditMode.SetEditModeOpen(open)
  EditMode.editModeOpen = open and true or false
  EditMode.Refresh()
  return EditMode.editModeOpen
end

-- True when the frame admits to a script type. A client that has dropped one raises when it is
-- hooked, so nothing is hooked without asking first, and a frame with no HasScript at all is
-- taken at its word. Same idiom as UI/Minimap.lua.
local hasScript = ItemTree.Util.HasScript

-- Hooks the client's Edit Mode, where there is one. Classic Era ships Blizzard_EditMode and the
-- Forever beta does not, so the whole thing is rawget guarded and taken once.
function EditMode.HookEditManager()
  if EditMode.hooked then
    return false
  end
  local manager = rawget(_G, "EditModeManagerFrame")
  if type(manager) ~= "table" or type(manager.HookScript) ~= "function" then
    return false
  end
  EditMode.hooked = true
  local taken = false
  if hasScript(manager, "OnShow") then
    taken = pcall(manager.HookScript, manager, "OnShow", function()
      EditMode.SetEditModeOpen(true)
    end) or taken
  end
  if hasScript(manager, "OnHide") then
    taken = pcall(manager.HookScript, manager, "OnHide", function()
      EditMode.SetEditModeOpen(false)
    end) or taken
  end
  return taken
end

-- A lock is never remembered: an unlocked panel that survived a reload would follow the player
-- around with a blue box on it and nothing to say why. The tick box is put back to locked here,
-- before the settings panel is ever built, so it draws unticked.
function EditMode.Init()
  local source = ItemTree.db and ItemTree.db.settings
  if source then
    source.hudUnlocked = false
  end
  EditMode.editModeOpen = false
  EditMode.HookEditManager()
  return EditMode.Refresh()
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local loader = createFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function(self)
    EditMode.Init()
    self:UnregisterEvent("PLAYER_LOGIN")
  end)
end

return EditMode
