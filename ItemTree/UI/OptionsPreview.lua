-- Settings previews (brief U2, experimental). The settings panel (UI/Options.lua) is a list of
-- the client's own rows, and a player cannot see what a setting changes without leaving the
-- panel. So while the pointer is on one of our rows, one small popup beside it shows a live
-- example of what that row changes, drawn by the same code the game draws it with, and redrawn
-- the moment the setting changes. The rows themselves are untouched: no new column, no taller
-- rows, no captions. A row with no example shows no popup at all.
--
-- How the pointer is followed. The rows are the client's own row templates on frames UI/Options.lua
-- makes for its canvas (brief E94), each initialised through its initializer the way the client's
-- list initialises a pooled row. UI/Options.lua hands each control's initializer to
-- Preview.AttachRow, which wraps the initializer's InitFrame and Resetter the way the child marker
-- in UI/Options.lua does. The first time a frame is initialised for one of our rows, OnEnter and
-- OnLeave are hooked (HasScript checked, HookScript is additive) on its label hit area and on its
-- control's frames, and nothing else on the frame is touched. The frame is remembered with the
-- initializer it was drawn for, and a hook that fires once the frame shows somebody else's row
-- (GetElementData answers another initializer) does nothing. A dropdown's menu open and close
-- come through the initializer's own OnShow and OnHide, which the client calls on exactly those
-- two events and nothing else, so the popup stays up while the player picks from the menu.
--
-- Checked against the public mirror, github.com/Gethe/wow-ui-source, branch forever:
-- Blizzard_Settings_Shared/Blizzard_SettingControls.lua (DefaultTooltipMixin sets OnEnter and
-- OnLeave once, at OnLoad, on the row's Tooltip frame and on the Checkbox, the slider's Slider and
-- the dropdown's Dropdown; SettingsDropdownControlMixin calls initializer.OnShow and OnHide on
-- menu open and close), Blizzard_SettingControls.xml (SettingsListElementTemplate's Tooltip
-- child covers the label), Blizzard_SettingsList.lua (InitFrame and Resetter are called through
-- securecallfunction with the initializer as element data) and Blizzard_Settings.lua
-- (Settings.CreateCheckbox, CreateSlider and CreateDropdown answer the initializer).
--
-- The rules, in order: the popup shows while the pointer is on the row's label or its control;
-- it goes Preview.GRACE seconds after the pointer has left both, so moving from the label to the
-- box does not blink it; it stays while the control is held down or a dropdown's menu is open;
-- and it redraws from Options.OnChanged, so flipping the box changes the example at once.
--
-- Nothing is built while the panel is closed: the popup is made on the first hover.
--
-- Where it sits (brief U2d, the owner's ruling from his screenshot): stacked directly above the
-- client's own grey tooltip for the row (SettingsTooltip, which Settings.InitTooltip fills over
-- the hovered label or control), so the client's words and our example read as one stack next
-- to the pointer. A row the client shows no tooltip for takes the popup above its control. Where
-- there is no room above, it goes below instead, never to the side. It is placed again on every
-- enter, because the client's tooltip moves with the row and the part hovered.
--
-- Brief K13: the four Keep marks rows show a row of example bag slots wearing every variant of the
-- chosen style in the chosen colours, one slot a tier, drawn by Overlay.ShowKeep itself on frames
-- of ours, since the client will not open the bags while the Settings panel is up.
--
-- Brief K14: while the Style or Colours menu is open, the Keep marks example shows the option
-- under the pointer (Preview.Peek), drawn over a copy of the settings, so nothing is written and
-- the bags do not change until an option is picked. Leaving an option, closing the menu and the
-- popup going all clear it (Preview.Unpeek). Only hooks the client offers are used, checked
-- against the forever branch: Blizzard_Settings.lua, Settings.CreateDropdownButton passes our
-- option data's onEnter to the menu ("rootDescription:CreateHighlightRadio(optionData.label,
-- isSelected, setSelected, optionData, optionData.onEnter)"), which Blizzard_Menu's
-- MenuTemplates.CreateHighlightRadio calls on enter ("if onEnter then onEnter(data); end");
-- Settings.CreateDropdownOptionInserter hands the menu to the initializer's own handler ("if
-- initializer.customOptionHandler then initializer.customOptionHandler(rootDescription); end"),
-- and Menu.lua's element descriptions offer HookOnLeave, which adds our function to the
-- option's own through hooksecurefunc, the client's own additive hook. No frame script is set
-- and no Blizzard frame is written to.
--
-- Preview.Decision, Preview.Stack, Preview.PickSample, Preview.SampleFor, Preview.TooltipModel,
-- Preview.SlotModel, Preview.RowModel, Preview.HudModel, Preview.KeepModel and Preview.HasExample
-- are pure and run under busted. Everything below the divider is guarded, so this file loads with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Preview = {}
ItemTree.UI.OptionsPreview = Preview

local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local function themeSize(key, fallback)
  local sizes = Theme and Theme.sizes
  local value = sizes and sizes[key]
  if type(value) == "number" and value > 0 then
    return value
  end
  return fallback
end

-- How long the popup waits after the pointer has left both the label and the control.
Preview.GRACE = 0.3

-- The gap between the popup and the client's tooltip (or the control) it stacks on, and the
-- padding inside it.
Preview.GAP = themeSize("ITEMTREE_SPACE_1", 4)
Preview.PAD = themeSize("ITEMTREE_PAD_TIGHT", 8)
Preview.EDGE = themeSize("ITEMTREE_BORDER_HAIRLINE", 1)

-- How bright a line the hovered row does not govern is drawn in the tooltip example.
Preview.DIM_ALPHA = 0.4

-- The popup's own surface and edge, the panel's dark surface and a hairline.
Preview.SURFACE = "ITEMTREE_COLOR_SURFACE_FRAME"
Preview.BORDER = "ITEMTREE_COLOR_BORDER_GOLD_DIM"

-- The client's own tooltip fonts, so the example is the size a tooltip is.
Preview.TITLE_FONT = "GameTooltipHeaderText"
Preview.BODY_FONT = "GameTooltipText"
Preview.NAME_FONT = "GameFontHighlight"
Preview.FONT_FALLBACKS = { "GameTooltipText", "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }
Preview.LINE_GAP = 2
Preview.LINE_H = 14
Preview.CHAR_WIDTH = 6

-- The bag slot: the design's 36px slot carrying one New badge and nothing else. The owner's
-- ruling (brief U2b): a Changed and a New badge stacked on one slot is misleading, so the
-- example is the single mark.
Preview.SLOT = themeSize("ITEMTREE_ICON_BAGSLOT", 36)
Preview.SLOT_KINDS = { "new" }
-- The drawn square inside UI-EmptySlot's 64px canvas, which has 9px of padding on each side.
Preview.SLOT_COORDS = { 9 / 64, 55 / 64, 9 / 64, 55 / 64 }

-- The tree row: the tree's own icon, row height and badge cap.
Preview.ROW_ICON = themeSize("ITEMTREE_ICON_TREE", 20)
Preview.ROW_H = themeSize("ITEMTREE_LIST_ROW_H", 22)
Preview.ROW_BADGES = 3

-- The rows with an example, by the settings key UI/Options.lua's ORDER gives them.
Preview.TOOLTIP_KEYS =
  { "tooltipEnabled", "tooltipShowBadges", "tooltipShowUses", "tooltipShowIcons", "tooltipShowHint" }
Preview.SLOT_KEYS = { "bagOverlay", "bankOverlay", "bagBadgeScale", "bagBadgeCorner" }
Preview.BADGE_KEYS = { "badgesNew", "badgesChanged" }
Preview.HUD_KEYS = { "hudEnabled", "hudShowBadges", "hudShowSummary" }
-- Brief K13: the Keep marks section's rows. Brief K16: every row UI/Options.lua declares in that
-- section takes the Keep example, its client rows (Options.ControlDefinitions) and its Custom
-- colour rows (Options.SWATCH_ROWS) alike, so a row added there later is not listed again here.
-- Brief K14: and every dropdown in it redraws the example for the option under the pointer in its
-- open menu (Style, Colours, Colour and Valuable colour).
-- Brief ST2 (QA item 307): the section is Keep and Use marks now (UI/Options.lua KEEP_SECTION).
Preview.KEEP_SECTION = "Keep and Use marks"
-- Brief ST2 (QA item 307, the owner: "Our use mark example tooltip just shows keep marks"): the
-- rows whose Keep example also draws a slot wearing the Use mark, the Use mark switch and the Mark
-- size slider that sizes it.
Preview.USE_SLOT_KEYS = { keepUseMark = true, keepMarkScale = true }

-- The stack counts two of the Keep example's slots carry, the first marked slot and the last
-- slot, so the bar's dark end and the gem and flag corners can be judged against a count.
Preview.KEEP_COUNTS = { "16", "3" }
-- The gap between two of the Keep example's slot columns, and between a slot and its caption.
Preview.KEEP_GAP = themeSize("ITEMTREE_SPACE_2", 8)
Preview.CAPTION_GAP = themeSize("ITEMTREE_SPACE_1", 4)
Preview.CAPTION_FONT = "GameFontHighlightSmall"
Preview.COUNT_FONT = "NumberFontNormal"
-- Brief PR6: the profession icon rows (registered by UI/ProfessionsStub.lua) draw the same slot
-- with the icon added, in the corner a real slot's icon would take beside the New badge.
Preview.PROFESSION_KEYS = { "professionBadge", "professionBadgeCorner" }
-- Brief ST3 (QA item 318, the owner: "No preview for changed badges"): the Show Changed badges on
-- bags row draws the same slot wearing the Changed badge, and with the switch off (or Show Changed
-- badges off, which it needs too: UI/Overlay.lua Overlay.BadgesFor) no badge at all.
Preview.CHANGED_SLOT_KEY = "bagBadgesChanged"
Preview.CHANGED_SLOT_KINDS = { "changed" }
-- The sample profession: cooking (skill line 185), the owner's own example.
Preview.PROFESSION_SAMPLE = 185

-- Which setting turns the slot's badges on, for the two rows that are that setting.
local SLOT_WHERE = { bagOverlay = true, bankOverlay = true }

local PROFESSION_ROW = {}
for _, key in ipairs(Preview.PROFESSION_KEYS) do
  PROFESSION_ROW[key] = true
end

-- Which setting turns each badge kind on in a tree row, the rule Core/ViewModel.lua applies:
-- Season of Discovery is New in purple, so it goes with New.
local ROW_BADGE_SETTING = { new = "badgesNew", sod = "badgesNew", changed = "badgesChanged" }

-- A tick box that has never been written reads as on, the way UI/Tooltip.lua reads its own.
local function settingOn(settings, key)
  local value = settings[key]
  if value == nil then
    return true
  end
  return value and true or false
end

local function copy(source)
  local out = {}
  for key, value in pairs(type(source) == "table" and source or EMPTY) do
    out[key] = value
  end
  return out
end

--- What the popup does now. overLabel and overControl say whether the pointer is on the row's
--- label and on its control (a held control and an open menu count as on it); sinceLeft is how
--- long it is since it left both, nil when it has not. Answers "show", "hold" (inside the grace)
--- or "hide". Pure: the caller passes the time, so the spec needs no clock.
function Preview.Decision(overLabel, overControl, sinceLeft, grace)
  if overLabel or overControl then
    return "show"
  end
  sinceLeft = tonumber(sinceLeft)
  if not sinceLeft then
    return "hide"
  end
  grace = tonumber(grace) or Preview.GRACE
  if sinceLeft < grace then
    return "hold"
  end
  return "hide"
end

--- Whether the popup stacks above or below the frame it is anchored to: above, unless its top
--- would run off the top of the screen and there is room below. Where neither fits, above is
--- kept and the popup's own screen clamp takes it from there. The shape of Badges.TooltipSide,
--- turned on its side: the anchor's top and bottom, the popup height and the screen height in
--- (bottom up, as the client measures), "ABOVE" or "BELOW" out. Pure.
function Preview.Stack(anchorTop, anchorBottom, height, screenHeight, gap)
  local top = tonumber(anchorTop)
  local screen = tonumber(screenHeight) or 0
  if not top or screen <= 0 then
    return "ABOVE"
  end
  local bottom = tonumber(anchorBottom) or top
  local tall = math.max(tonumber(height) or 0, 0)
  gap = math.max(tonumber(gap) or 0, 0)
  if top + gap + tall <= screen then
    return "ABOVE"
  end
  if bottom - gap - tall >= 0 then
    return "BELOW"
  end
  return "ABOVE"
end

--- Brief K16: whether key is a row of the Keep marks section, as UI/Options.lua declares it, and
--- the row's kind ("boolean", "slider", "dropdown" or "button" for a Custom colour row). Read at
--- call time, guarded: without Options loaded nothing is a Keep row. Pure over the namespace.
-- The Keep marks rows by key, { kind }, read from UI/Options.lua once on first use (its rows are
-- fixed once the file has loaded) and dropped by Preview.Reset.
local keepIndex = nil

local function buildKeepIndex()
  local index = {}
  local Options = ItemTree.Options
  if type(Options) ~= "table" then
    return index
  end
  local section = Options.KEEP_SECTION or Preview.KEEP_SECTION
  if type(Options.ControlDefinitions) == "function" then
    local ok, defs = pcall(Options.ControlDefinitions)
    for _, def in ipairs(ok and type(defs) == "table" and defs or EMPTY) do
      if def.section == section and type(def.key) == "string" then
        index[def.key] = def.kind
      end
    end
  end
  for _, spec in ipairs(type(Options.SWATCH_ROWS) == "table" and Options.SWATCH_ROWS or EMPTY) do
    if spec.section == section and type(spec.key) == "string" then
      index[spec.key] = "button"
    end
  end
  return index
end

function Preview.KeepRow(key)
  if type(key) ~= "string" then
    return false
  end
  local index = keepIndex
  if index == nil then
    index = buildKeepIndex()
    -- Kept only once UI/Options.lua is there to read.
    if type(ItemTree.Options) == "table" then
      keepIndex = index
    end
  end
  local kind = index[key]
  if kind == nil then
    return false
  end
  return true, kind
end

--- Brief K16: the Keep marks section's rows with an example, in the panel's order. Pure.
function Preview.KeepKeys()
  local out = {}
  local Options = ItemTree.Options
  if type(Options) ~= "table" or type(Options.CanvasRows) ~= "function" then
    return out
  end
  local ok, rows = pcall(Options.CanvasRows)
  for _, row in ipairs(ok and type(rows) == "table" and rows or EMPTY) do
    local key = (row.def and row.def.key) or (row.spec and row.spec.key)
    if key and Preview.KeepRow(key) then
      out[#out + 1] = key
    end
  end
  return out
end

--- Whether a settings key has an example.
function Preview.HasExample(key)
  if type(key) ~= "string" then
    return false
  end
  return Preview.RENDERERS[key] ~= nil or Preview.KeepRow(key) == true
end

local function named(data, id)
  if type(data.GetItem) ~= "function" then
    return false
  end
  local ok, item = pcall(data.GetItem, data, id)
  return ok and type(item) == "table" and type(item.n) == "string" and item.n ~= ""
end

local function hasRecipeUses(data, id)
  if type(data.GetUses) ~= "function" then
    return false
  end
  local ok, uses = pcall(data.GetUses, data, id)
  return ok and type(uses) == "table" and type(uses.r) == "table" and #uses.r > 0
end

-- Brief PV1 (owner QA 2026-10-07, the Show uses line row showed nothing for Linen Bandage): an
-- item a recipe makes that is no reagent itself, so its tooltip carries "Made by N recipes" and
-- the Keep block does not list its uses in the line's place (brief K18).
local function madeOnly(data, id)
  if type(data.GetUses) ~= "function" then
    return false
  end
  local ok, uses = pcall(data.GetUses, data, id)
  if not ok or type(uses) ~= "table" then
    return false
  end
  local made = type(uses.p) == "table" and #uses.p > 0
  local reagent = type(uses.r) == "table" and #uses.r > 0
  return made and not reagent
end

-- Whether Diff gives the item this very mark, so a harvested id the settings hide, or a New id
-- that wears the Season of Discovery mark, is not picked as the plain example.
local function wears(diff, id, kind)
  if type(diff) ~= "table" or type(diff.Badges) ~= "function" then
    return false
  end
  local ok, kinds = pcall(diff.Badges, "items", id)
  if not ok or type(kinds) ~= "table" then
    return false
  end
  for _, each in ipairs(kinds) do
    if each == kind then
      return true
    end
  end
  return false
end

--- The fixed sample items the examples are drawn for, from the shipped data alone: never a
--- question to the client. main is the lowest id Diff marks Changed that is also a reagent in a
--- recipe, so every tooltip line has something to say; failing that, the lowest plain New item;
--- failing that, the lowest Changed item. new is the lowest plain New item, for the New badge
--- row. uses (brief PV1) is the lowest Changed item a recipe makes that is no reagent itself, for
--- the Show uses line row (its "Made by N recipes" line shows; a reagent's uses are listed by the
--- Keep block instead, brief K18), else the lowest such New item. Lowest id so the pick is the
--- same on every load. Answers { main, new, uses }, any nil where the data has none. Pure: data
--- is ItemTree.Data and diff is ItemTree.Diff.
function Preview.PickSample(data, diff)
  local out = {}
  if type(data) ~= "table" or type(data.GetDiff) ~= "function" then
    return out
  end
  local ok, tables = pcall(data.GetDiff, data)
  local items = ok and type(tables) == "table" and tables.items or nil
  if type(items) ~= "table" then
    return out
  end
  -- The cheap tests first and the lowest id so far as the gate, so the thousands of changed ids
  -- in a real build cost a comparison each and the item and badge lookups run for a handful.
  local changed = type(items.changed) == "table" and items.changed or EMPTY
  local withUses
  for raw in pairs(changed) do
    local id = tonumber(raw)
    if id and (not withUses or id < withUses) and hasRecipeUses(data, id) then
      if named(data, id) and wears(diff, id, "changed") then
        withUses = id
      end
    end
  end
  local new
  for _, raw in ipairs(type(items.new) == "table" and items.new or EMPTY) do
    local id = tonumber(raw)
    if id and (not new or id < new) and named(data, id) and wears(diff, id, "new") then
      new = id
    end
  end
  local madeChanged, madeNew
  for raw in pairs(changed) do
    local id = tonumber(raw)
    if id and (not madeChanged or id < madeChanged) and madeOnly(data, id) then
      if named(data, id) and wears(diff, id, "changed") then
        madeChanged = id
      end
    end
  end
  if not madeChanged then
    for _, raw in ipairs(type(items.new) == "table" and items.new or EMPTY) do
      local id = tonumber(raw)
      if id and (not madeNew or id < madeNew) and madeOnly(data, id) then
        if named(data, id) and wears(diff, id, "new") then
          madeNew = id
        end
      end
    end
  end
  local anyChanged
  if not withUses and not new then
    for raw in pairs(changed) do
      local id = tonumber(raw)
      if id and (not anyChanged or id < anyChanged) and named(data, id) and wears(diff, id, "changed") then
        anyChanged = id
      end
    end
  end
  out.main = withUses or new or anyChanged
  out.new = new
  out.uses = madeChanged or madeNew
  return out
end

--- The sample item a row's example is drawn for: the New item for the New badge row, the made
--- item for the Show uses line row (brief PV1), the main sample for every other. Pure.
function Preview.SampleFor(key, samples)
  samples = type(samples) == "table" and samples or EMPTY
  if key == "badgesNew" then
    return samples.new or samples.main
  end
  if key == "tooltipShowUses" then
    return samples.uses or samples.main or samples.new
  end
  return samples.main or samples.new
end

-- Name and quality from ItemTree's own data: Core's Graph first, so the example says what the
-- window says, then the data row. Never the client.
local function nameAndQuality(itemId)
  local graph = ItemTree.Graph
  if type(graph) == "table" and type(graph.Node) == "function" and type(graph.Key) == "function" then
    local ok, node = pcall(graph.Node, graph.Key("item", itemId))
    if ok and type(node) == "table" and type(node.name) == "string" and node.name ~= "" then
      return node.name, tonumber(node.quality)
    end
  end
  local data = ItemTree.Data
  if type(data) == "table" and type(data.GetItem) == "function" then
    local ok, item = pcall(data.GetItem, data, itemId)
    if ok and type(item) == "table" and type(item.n) == "string" and item.n ~= "" then
      return item.n, tonumber(item.q)
    end
  end
  return tostring(itemId or ""), nil
end

local function qualityKey(quality)
  if Theme and type(Theme.QualityKey) == "function" then
    return Theme.QualityKey(quality)
  end
  return "ITEMTREE_COLOR_TEXT_BODY"
end

local function lineTexts(lines)
  local out = {}
  for _, line in ipairs(type(lines) == "table" and lines or EMPTY) do
    if type(line) == "table" and type(line.text) == "string" then
      out[line.text] = true
    end
  end
  return out
end

--- The tooltip example for one of the tooltip rows: the item's name as the tooltip's title,
--- then ItemTree's block for the item with the CURRENT settings, through Tooltip.CachedLines, so
--- it is the block the game draws. Each line says whether the row governs it: a line the block
--- would not carry, or would carry differently, with the row's setting off. The title is the
--- game's own line and is never the governed one. Answers a list of { text, colorKey, bright,
--- title }. Pure in the sense the rest of this project means it: it reads the loaded modules
--- through the namespace, guarded, and needs no client.
function Preview.TooltipModel(itemId, settings, key)
  settings = type(settings) == "table" and settings or EMPTY
  local name, quality = nameAndQuality(itemId)
  local out = { { text = name, colorKey = qualityKey(quality), bright = false, title = true } }
  local Tooltip = ItemTree.Tooltip
  if not itemId or type(Tooltip) ~= "table" or type(Tooltip.CachedLines) ~= "function" then
    return out
  end
  local ok, block = pcall(Tooltip.CachedLines, itemId, settings)
  if not ok or type(block) ~= "table" then
    return out
  end
  local without = {}
  if type(Tooltip.BuildLines) == "function" then
    local off = copy(settings)
    off[key] = false
    local built, lines = pcall(Tooltip.BuildLines, itemId, off)
    if built then
      without = lineTexts(lines)
    end
  end
  for _, line in ipairs(block) do
    if type(line) == "table" and type(line.text) == "string" then
      out[#out + 1] = { text = line.text, colorKey = line.colorKey, bright = not without[line.text] }
    end
  end
  return out
end

--- The bag slot example: the badges' size and corner from the settings, through the same
--- Overlay.BadgeSize and Overlay.Corner the bags read, and no badges at all while the row is the
--- bag or bank tick box and it is off. For a profession icon row, profession is the sample skill
--- line (nil while professionBadge is off) and professionCorner the corner the icon takes beside
--- the badges, through Overlay.ProfessionCornerFor (brief PR6). Brief ST3 (QA item 318): for the
--- Show Changed badges on bags row the slot wears the Changed badge while that setting is on (an
--- unwritten one reads as off, its default) and Show Changed badges is on, else none. Answers
--- { size, corner, kinds, profession, professionCorner }. Pure.
function Preview.SlotModel(key, settings)
  settings = type(settings) == "table" and settings or EMPTY
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  local size, corner = 9, "TOPRIGHT"
  if type(Overlay) == "table" and type(Overlay.BadgeSize) == "function" then
    size = Overlay.BadgeSize(Preview.SLOT, settings.bagBadgeScale)
  end
  if type(Overlay) == "table" and type(Overlay.Corner) == "function" then
    corner = Overlay.Corner(settings.bagBadgeCorner)
  end
  local kinds = {}
  if key == Preview.CHANGED_SLOT_KEY then
    if settings[key] == true and settingOn(settings, "badgesChanged") then
      kinds = copy(Preview.CHANGED_SLOT_KINDS)
    end
  elseif not (SLOT_WHERE[key] and not settingOn(settings, key)) then
    kinds = copy(Preview.SLOT_KINDS)
  end
  local model = { size = size, corner = corner, kinds = kinds }
  if PROFESSION_ROW[key] and settingOn(settings, "professionBadge") then
    model.profession = Preview.PROFESSION_SAMPLE
    if type(Overlay) == "table" and type(Overlay.ProfessionCornerFor) == "function" then
      model.professionCorner = Overlay.ProfessionCornerFor(settings.professionBadgeCorner, corner, #kinds)
    end
  end
  return model
end

--- The tree row example: the item's name, quality and the badges Diff gives it, less any the
--- badge settings turn off, in priority order. Answers { itemId, name, quality, kinds }. Pure.
function Preview.RowModel(itemId, settings)
  settings = type(settings) == "table" and settings or EMPTY
  local name, quality = nameAndQuality(itemId)
  local model = { itemId = itemId, name = name, quality = quality, kinds = {} }
  local Diff = ItemTree.Diff
  if not itemId or type(Diff) ~= "table" or type(Diff.Badges) ~= "function" then
    return model
  end
  local ok, kinds = pcall(Diff.Badges, "items", itemId)
  if not ok or type(kinds) ~= "table" then
    return model
  end
  local wanted = {}
  for _, kind in ipairs(kinds) do
    local setting = ROW_BADGE_SETTING[kind]
    if not setting or settingOn(settings, setting) then
      wanted[#wanted + 1] = kind
    end
  end
  local Badges = ItemTree.Badges
  if type(Badges) == "table" and type(Badges.Sort) == "function" then
    wanted = Badges.Sort(wanted, Preview.ROW_BADGES)
  end
  model.kinds = wanted
  return model
end

--- The fixed position tooltip example: UI/EditMode.lua's own model for the item with these
--- settings, so the summary line and the badges follow their two tick boxes, and whether the
--- panel is on at all, which is off unless it has been ticked, as EditMode.Enabled reads it.
--- Answers the model (nil where EditMode did not load) and the on flag. Pure.
function Preview.HudModel(itemId, settings)
  settings = type(settings) == "table" and settings or EMPTY
  local enabled = settings.hudEnabled and true or false
  local EditMode = ItemTree.UI and ItemTree.UI.EditMode
  if type(EditMode) ~= "table" or type(EditMode.Model) ~= "function" then
    return nil, enabled
  end
  local ok, model = pcall(EditMode.Model, itemId, settings)
  if not ok then
    return nil, enabled
  end
  return model, enabled
end

--- The Keep marks example for the CURRENT settings: which slots it draws, left to right, each
--- { tier, valuable, caption, count }, in the style and colours the bags would use. A bare slot
--- first ("Not marked"), then one slot a tier of the ramp, lowest first, captioned with the tier
--- and its colour word ("Tier 3, red"); the shipped style 0 ignores tiers, so it has one marked
--- slot. Then, while the value setting is on, a slot in the top tier wearing the valuable look,
--- captioned with the setting's reading. Two slots carry a stack count (Preview.KEEP_COUNTS).
--- Brief K15: the Single colour set is one tier, so it shows one "Marked" slot, under a heading
--- that names the colour ("Flag, Single colour (teal)"); its ramp is built from these settings.
--- With Keep marks off, a heading that says so and the bare slot alone. Answers
--- { on, heading, style, ramp, corner, markScale, slots }. Pure: reads UI/Overlay.lua and
--- Core/Keep.lua through the namespace, guarded.
--- Brief ST2 (QA item 307): key is the hovered row. For the Use mark and Mark size rows
--- (Preview.USE_SLOT_KEYS) a last slot wears the Use mark ({ violet = Overlay.USE_MARK },
--- captioned "Use mark"), or with the Use mark off what such an item wears instead, its Keep look
--- (brief ST3, QA item 319, the owner's ruling A: captioned "Use mark off: shows the Keep flag").
--- markScale is the Mark size setting every slot's mark is drawn at.
function Preview.KeepModel(settings, key)
  settings = type(settings) == "table" and settings or EMPTY
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  local bare = { tier = 0, valuable = false, caption = L["Not marked"] }
  local model = { on = settingOn(settings, "keepMarks"), slots = { bare } }
  model.markScale = settings.keepMarkScale
  if type(Overlay) ~= "table" or type(Overlay.StyleIndex) ~= "function" then
    model.heading = model.on and "" or L["Keep marks are off."]
    return model
  end
  model.style = Overlay.StyleIndex(settings.keepStyle)
  -- Brief K24b (E): the one ramp reader (Overlay.SettingsRamp): always the single colour now.
  model.ramp = type(Overlay.SettingsRamp) == "function" and Overlay.SettingsRamp(settings)
    or Overlay.RampName(settings.keepRamp)
  model.corner = Overlay.Corner(settings.bagBadgeCorner)
  if not model.on then
    model.heading = L["Keep marks are off."]
    return model
  end
  if type(Overlay.SyncSingle) == "function" then
    Overlay.SyncSingle(settings)
  end
  -- Brief K16: and the valuable colour the Single colour set draws the valuable slot in.
  if type(Overlay.SyncValue) == "function" then
    Overlay.SyncValue(settings)
  end
  local ramp = Overlay.Ramp(model.ramp)
  local rampWord = (Overlay.RAMP_NAMES or EMPTY)[model.ramp] or model.ramp
  local top
  if model.style == Overlay.KEEP_STYLE_SHIPPED then
    -- The shipped look is gold whatever the Colours row says, so the heading names it alone.
    model.heading = Overlay.StyleName(model.style)
    model.slots[2] = { tier = 1, valuable = false, caption = L["Marked"] }
    top = 1
  elseif model.ramp == "single" then
    local entry = ramp[1] or EMPTY
    local hue = (Overlay.HUE_NAMES or EMPTY)[entry.hue] or entry.hue or ""
    model.heading = string.format(L["%s, %s (%s)"], Overlay.StyleName(model.style), rampWord, hue)
    model.slots[2] = { tier = 1, valuable = false, caption = L["Marked"] }
    top = 1
  else
    model.heading = string.format(L["%s, %s"], Overlay.StyleName(model.style), rampWord)
    for tier, entry in ipairs(ramp) do
      local hue = (Overlay.HUE_NAMES or EMPTY)[entry.hue] or entry.hue or ""
      model.slots[#model.slots + 1] =
        { tier = tier, valuable = false, caption = string.format(L["Tier %d, %s"], tier, hue) }
    end
    top = math.max(#ramp, 1)
  end
  local Keep = ItemTree.Keep
  if type(Keep) == "table" and type(Keep.ValueThreshold) == "function" and type(Keep.ValueLabel) == "function" then
    local ok, threshold = pcall(Keep.ValueThreshold, settings)
    if ok and threshold then
      model.slots[#model.slots + 1] = {
        tier = top,
        valuable = true,
        caption = string.format(L["Worth %s or more"], Keep.ValueLabel(threshold)),
      }
    end
  end
  if Preview.USE_SLOT_KEYS[key] then
    if settingOn(settings, "keepUseMark") then
      model.slots[#model.slots + 1] = { tier = 1, valuable = false, violet = Overlay.USE_MARK, caption = L["Use mark"] }
    else
      model.slots[#model.slots + 1] = { tier = 1, valuable = false, caption = L["Use mark off: shows the Keep flag"] }
    end
  end
  if #model.slots >= 2 then
    model.slots[2].count = Preview.KEEP_COUNTS[1]
  end
  if #model.slots >= 3 then
    model.slots[#model.slots].count = Preview.KEEP_COUNTS[2]
  end
  return model
end

-- The samples, picked once on first use and dropped when what an item record answers changes.
local samples = nil

--- The samples the examples are drawn for, picked from ItemTree.Data on first use.
function Preview.Samples()
  if samples == nil then
    samples = Preview.PickSample(ItemTree.Data, ItemTree.Diff)
  end
  return samples
end

function Preview.ResetSamples()
  samples = nil
end

--- Whether key's open menu redraws the example for the option under the pointer (brief K14): any
--- dropdown of the Keep marks section (brief K16).
function Preview.Peeks(key)
  local keep, kind = Preview.KeepRow(key)
  return keep == true and kind == "dropdown"
end

--- The settings an example is drawn from while the pointer is on one option of an open menu: a
--- copy of settings with key reading value. The table passed in is never written. Pure.
function Preview.PeekSettings(settings, key, value)
  local out = copy(settings)
  if key ~= nil then
    out[key] = value
  end
  return out
end

-- The option under the pointer in an open menu, { key, value }, or nil. Never written anywhere.
local peeking = nil

--- What the example is peeking at: the key and the value, or nil.
function Preview.Peeking()
  if peeking then
    return peeking.key, peeking.value
  end
  return nil
end

local function currentSettings()
  local settings = (ItemTree.db and ItemTree.db.settings) or EMPTY
  if peeking then
    return Preview.PeekSettings(settings, peeking.key, peeking.value)
  end
  return settings
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- One client call on a widget, type checked and pcall'd. A method this widget does not carry
-- and one that raises both read as nothing.
local function call(object, name, ...)
  if type(object) ~= "table" or type(object[name]) ~= "function" then
    return nil
  end
  local ok, value = pcall(object[name], object, ...)
  if not ok then
    return nil
  end
  return value
end

local function newFrame(kind, parent)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

local function now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return 0
  end
  local ok, value = pcall(getTime)
  return (ok and tonumber(value)) or 0
end

local function colour(key)
  if not (Theme and type(Theme.ColorTable) == "function") then
    return nil
  end
  return Theme.ColorTable(key)
end

-- Hands the font string one of the client's own font objects. Nothing here can raise.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Preview.FONT_FALLBACKS) do
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

-- A font string that is never fontless: the template is asked for at creation, and one the
-- client will not take gets a font object by hand, so SetText is never the first thing to touch
-- the font. The same shape as UI/Sidebar.lua's.
local function newFontString(parent, layer, template)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, template or Preview.BODY_FONT)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local function tintText(fontString, colorKey)
  local c = colour(colorKey)
  if c then
    call(fontString, "SetTextColor", c.r, c.g, c.b, c.a or 1)
  end
end

local function textWidth(fontString, text)
  local width = tonumber(call(fontString, "GetStringWidth"))
  if width and width > 0 then
    return width
  end
  return #(text or "") * Preview.CHAR_WIDTH
end

local function textHeight(fontString)
  local height = tonumber(call(fontString, "GetStringHeight"))
  if height and height > 0 then
    return height
  end
  return Preview.LINE_H
end

-- A flat fill in one Theme colour, through the white 8x8 in UI/Assets.lua.
local function wash(parent, layer, colorKey)
  local texture = call(parent, "CreateTexture", nil, layer)
  if type(texture) ~= "table" then
    return nil
  end
  local Assets = ItemTree.Assets
  if type(Assets) == "table" and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  local c = colour(colorKey)
  if c then
    call(texture, "SetVertexColor", c.r, c.g, c.b)
    call(texture, "SetAlpha", c.a or 1)
  end
  return texture
end

--------------------------------------------------------------------------------
-- The popup: one shared frame, built on the first hover.
--------------------------------------------------------------------------------

-- The frame, false once the client has refused us one.
local popup = nil

local function buildPopup()
  local frame = newFrame("Frame", rawget(_G, "UIParent"))
  if not frame then
    return nil
  end
  call(frame, "SetFrameStrata", "TOOLTIP")
  call(frame, "SetClampedToScreen", true)
  -- Never a click: the popup sits beside the row the pointer is on.
  call(frame, "EnableMouse", false)
  frame.fill = wash(frame, "BACKGROUND", Preview.SURFACE)
  call(frame.fill, "SetAllPoints", frame)
  local edge = Preview.EDGE
  local sides = {
    { "TOPLEFT", "TOPRIGHT", "SetHeight" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
    { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
  }
  frame.edges = {}
  for index, side in ipairs(sides) do
    local line = wash(frame, "BORDER", Preview.BORDER)
    if line then
      call(line, "SetPoint", side[1], frame, side[1], 0, 0)
      call(line, "SetPoint", side[2], frame, side[2], 0, 0)
      call(line, side[3], edge)
    end
    frame.edges[index] = line
  end
  local content = newFrame("Frame", frame)
  if not content then
    call(frame, "Hide")
    return nil
  end
  call(content, "SetPoint", "TOPLEFT", frame, "TOPLEFT", Preview.PAD, -Preview.PAD)
  call(content, "EnableMouse", false)
  content.groups = {}
  frame.content = content
  call(frame, "Hide")
  return frame
end

local function popupFrame()
  if popup == nil then
    popup = buildPopup() or false
  end
  if popup == false then
    return nil
  end
  return popup
end

--- The shared popup, built on first use; nil where the client will not make one.
function Preview.Frame()
  return popupFrame()
end

-- One group of widgets on the content frame per kind of example, made once and shown alone.
local function group(content, name)
  if type(content) ~= "table" then
    return nil
  end
  content.groups = content.groups or {}
  local frame = content.groups[name]
  if not frame then
    frame = newFrame("Frame", content)
    if not frame then
      return nil
    end
    call(frame, "SetPoint", "TOPLEFT", content, "TOPLEFT", 0, 0)
    call(frame, "EnableMouse", false)
    content.groups[name] = frame
  end
  for other, each in pairs(content.groups) do
    if other ~= name then
      call(each, "Hide")
    end
  end
  call(frame, "Show")
  return frame
end

-- The tooltip rows: the title and the block, one font string a line, the governed line at full
-- colour and the rest dimmed.
local function drawTooltip(content, settings, key)
  local frame = group(content, "tooltip")
  if not frame then
    return nil
  end
  frame.lines = frame.lines or {}
  local model = Preview.TooltipModel(Preview.SampleFor(key, Preview.Samples()), settings, key)
  local width, y = 0, 0
  local drawn = 0
  for index, line in ipairs(model) do
    local fontString = frame.lines[index]
    if not fontString then
      fontString = newFontString(frame, "OVERLAY", index == 1 and Preview.TITLE_FONT or Preview.BODY_FONT)
      frame.lines[index] = fontString
    end
    if fontString then
      call(fontString, "ClearAllPoints")
      call(fontString, "SetPoint", "TOPLEFT", frame, "TOPLEFT", 0, -y)
      call(fontString, "SetJustifyH", "LEFT")
      setText(fontString, line.text)
      tintText(fontString, line.colorKey)
      call(fontString, "SetAlpha", line.bright and 1 or Preview.DIM_ALPHA)
      call(fontString, "Show")
      width = math.max(width, textWidth(fontString, line.text))
      y = y + textHeight(fontString) + Preview.LINE_GAP
      drawn = index
    end
  end
  for index = drawn + 1, #frame.lines do
    call(frame.lines[index], "Hide")
  end
  y = math.max(y - Preview.LINE_GAP, 0)
  call(frame, "SetSize", width, y)
  return width, y
end

-- The client's empty slot art on the example slot, cropped to the square it draws.
local function slotArt(slot)
  local art = call(slot, "CreateTexture", nil, "BACKGROUND")
  if type(art) ~= "table" then
    return nil
  end
  call(art, "SetAllPoints", slot)
  local Assets = ItemTree.Assets
  if type(Assets) == "table" and type(Assets.Apply) == "function" then
    local ok, took = pcall(Assets.Apply, art, "SLOT_EMPTY")
    if ok and took then
      local c = Preview.SLOT_COORDS
      call(art, "SetTexCoord", c[1], c[2], c[3], c[4])
    end
  end
  return art
end

-- The bag and bank rows: U1's slot, its badges placed through Overlay.Place, the very call a
-- real bag slot's badges go through.
local function drawSlot(content, settings, key)
  local frame = group(content, "slot")
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  local Badges = ItemTree.Badges
  if not frame or type(Overlay) ~= "table" or type(Overlay.Place) ~= "function" then
    return nil
  end
  local size = Preview.SLOT
  if not frame.slot then
    local slot = newFrame("Frame", frame)
    if not slot or type(Badges) ~= "table" or type(Badges.CreateCluster) ~= "function" then
      return nil
    end
    call(slot, "SetSize", size, size)
    call(slot, "SetPoint", "TOPLEFT", frame, "TOPLEFT", 0, 0)
    call(slot, "EnableMouse", false)
    slot.art = slotArt(slot)
    local ok, cluster =
      pcall(Badges.CreateCluster, slot, Overlay.BadgeSize(size, nil), Overlay.MAX_BADGES, "column", Overlay.GAP)
    if not ok or type(cluster) ~= "table" then
      return nil
    end
    call(cluster, "EnableMouse", false)
    slot.cluster = cluster
    frame.slot = slot
  end
  local model = Preview.SlotModel(key, settings)
  local slot = frame.slot
  call(slot.cluster, "SetKinds", model.kinds)
  Overlay.Place(slot.cluster, slot, model.size, model.corner)
  -- Brief PR6: the profession icon, through the very call a real slot's icon goes through, and
  -- hidden again for every other slot row. Brief PR20: in its small frame, and the sample slot
  -- holds one item, so no stack count lifts it at bottom right.
  if model.profession and not slot.profession and type(Overlay.MakeProfessionIcon) == "function" then
    slot.profession = Overlay.MakeProfessionIcon(slot)
  end
  if type(Overlay.ShowProfession) == "function" then
    Overlay.ShowProfession(
      slot.profession,
      model.profession,
      slot,
      model.size,
      settings.professionBadgeCorner,
      model.corner,
      #model.kinds,
      size,
      0
    )
  end
  frame.model = model
  call(frame, "SetSize", size, size)
  return size, size
end

-- The badge rows: one tree row, the item's icon, its name in its quality colour and the badge
-- cluster the tree draws.
local function drawRow(content, settings, key)
  local frame = group(content, "row")
  local Badges = ItemTree.Badges
  if not frame or type(Badges) ~= "table" or type(Badges.CreateCluster) ~= "function" then
    return nil
  end
  local gap = themeSize("ITEMTREE_SPACE_1", 4)
  if not frame.name then
    frame.icon = call(frame, "CreateTexture", nil, "ARTWORK")
    call(frame.icon, "SetSize", Preview.ROW_ICON, Preview.ROW_ICON)
    call(frame.icon, "SetPoint", "LEFT", frame, "LEFT", 0, 0)
    frame.name = newFontString(frame, "OVERLAY", Preview.NAME_FONT)
    if not frame.name then
      return nil
    end
    call(frame.name, "SetPoint", "LEFT", frame, "LEFT", Preview.ROW_ICON + gap, 0)
    local ok, cluster = pcall(Badges.CreateCluster, frame, "tree", Preview.ROW_BADGES, "row")
    if ok and type(cluster) == "table" then
      call(cluster, "EnableMouse", false)
      call(cluster, "SetPoint", "LEFT", frame.name, "RIGHT", gap, 0)
      frame.badges = cluster
    end
  end
  local model = Preview.RowModel(Preview.SampleFor(key, Preview.Samples()), settings)
  local Assets = ItemTree.Assets
  if model.itemId and type(Assets) == "table" and type(Assets.ItemIcon) == "function" then
    local ok, icon = pcall(Assets.ItemIcon, model.itemId)
    if ok and icon then
      call(frame.icon, "SetTexture", icon)
    end
  end
  setText(frame.name, model.name)
  tintText(frame.name, qualityKey(model.quality))
  local width = Preview.ROW_ICON + gap + textWidth(frame.name, model.name)
  if frame.badges then
    local kinds = call(frame.badges, "SetKinds", model.kinds) or {}
    if #kinds > 0 and type(Badges.ClusterExtent) == "function" then
      local size = themeSize("ITEMTREE_BADGE_SIZE_TREE", 16)
      local ok, extent = pcall(Badges.ClusterExtent, #kinds, size, nil, "row")
      width = width + gap + ((ok and tonumber(extent)) or #kinds * size)
    end
  end
  frame.model = model
  call(frame, "SetSize", width, Preview.ROW_H)
  return width, Preview.ROW_H
end

-- The fixed position tooltip rows: the panel as UI/EditMode.lua draws it, through its own
-- EditMode.DrawPreview, dimmed while the panel is switched off.
local function drawHud(content, settings, key)
  local frame = group(content, "hud")
  local EditMode = ItemTree.UI and ItemTree.UI.EditMode
  if not frame or type(EditMode) ~= "table" or type(EditMode.DrawPreview) ~= "function" then
    return nil
  end
  local model, enabled = Preview.HudModel(Preview.SampleFor(key, Preview.Samples()), settings)
  if not model then
    return nil
  end
  local width, height = EditMode.DrawPreview(frame, model)
  if not width then
    return nil
  end
  call(frame, "SetAlpha", enabled and 1 or Preview.DIM_ALPHA)
  frame.enabled = enabled
  return width, height
end

-- Brief K13: one column of the Keep example, made once: the slot with the client's empty slot art,
-- the item's icon and a stack count on it, ItemTree's overlay frame over it the way UI/Overlay.lua
-- puts one over a bag button (its own frame, a few levels up, the glow and the frame made by
-- Overlay.MakeGlow and MakeRing, keepSlot naming the slot), and the caption under it.
local function keepColumn(frame, index)
  frame.columns = frame.columns or {}
  local column = frame.columns[index]
  if column then
    return column
  end
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  local slot = newFrame("Frame", frame)
  if not slot or type(Overlay) ~= "table" then
    return nil
  end
  local size = Preview.SLOT
  call(slot, "SetSize", size, size)
  call(slot, "EnableMouse", false)
  slot.art = slotArt(slot)
  slot.icon = call(slot, "CreateTexture", nil, "ARTWORK")
  call(slot.icon, "SetAllPoints", slot)
  slot.count = newFontString(slot, "ARTWORK", Preview.COUNT_FONT)
  call(slot.count, "SetPoint", "BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
  call(slot.count, "SetJustifyH", "RIGHT")
  local overlay = newFrame("Frame", slot)
  if not overlay then
    return nil
  end
  call(overlay, "EnableMouse", false)
  call(overlay, "SetAllPoints", slot)
  local level = tonumber(call(slot, "GetFrameLevel"))
  if level then
    call(overlay, "SetFrameLevel", level + (tonumber(Overlay.LEVEL_OFFSET) or 5))
  end
  overlay.keepSlot = slot
  if type(Overlay.MakeGlow) == "function" then
    overlay.glow = Overlay.MakeGlow(overlay, slot)
  end
  if type(Overlay.MakeRing) == "function" then
    overlay.ring = Overlay.MakeRing(overlay, slot)
  end
  local caption = newFontString(frame, "OVERLAY", Preview.CAPTION_FONT)
  call(caption, "SetJustifyH", "CENTER")
  column = { slot = slot, overlay = overlay, caption = caption }
  frame.columns[index] = column
  return column
end

-- Stops every Keep look the example drew, so its pulses, marches and flames do not run on while
-- the popup shows another row or is hidden.
local function stopKeep()
  local frame = popup and popup.content and popup.content.groups and popup.content.groups.keep
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  if type(frame) ~= "table" or type(Overlay) ~= "table" or type(Overlay.HideKeep) ~= "function" then
    return
  end
  for _, column in ipairs(frame.columns or EMPTY) do
    pcall(Overlay.HideKeep, column.overlay)
  end
end

-- How far a Keep look reaches past the slot: the glow on every side, and above it the flame
-- with its drift. Answers the side and the top margins.
local function keepMargins()
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  local size = Preview.SLOT
  local side = 0
  if type(Overlay) == "table" and type(Overlay.GlowSize) == "function" then
    side = math.max(math.ceil(((tonumber(Overlay.GlowSize(size)) or size) - size) / 2), 0)
  end
  local top = side
  if type(Overlay) == "table" and type(Overlay.FlameGeometry) == "function" then
    local _, height, y = Overlay.FlameGeometry(size)
    local rise = themeSize("ITEMTREE_KEEP_FLAME_RISE", 4)
    top = math.max(top, (tonumber(height) or 0) + (tonumber(y) or 0) + rise)
  end
  return side, top
end

-- The Keep marks rows (brief K13): a heading naming the style and colours, then the example slots
-- of Preview.KeepModel side by side, each marked by Overlay.ShowKeep, the very call a bag slot's
-- mark goes through, so the looks, tints, pulses and flames are the bag's own. Brief ST2: key is
-- the hovered row (the Use mark and Mark size rows add the Use mark slot), and every mark is drawn
-- at the Mark size setting, as the bags draw it.
local function drawKeep(content, settings, key)
  local frame = group(content, "keep")
  local Overlay = ItemTree.UI and ItemTree.UI.Overlay
  if not frame or type(Overlay) ~= "table" or type(Overlay.ShowKeep) ~= "function" then
    return nil
  end
  local model = Preview.KeepModel(settings, key)
  if not frame.heading then
    frame.heading = newFontString(frame, "OVERLAY", Preview.NAME_FONT)
    if not frame.heading then
      return nil
    end
    call(frame.heading, "SetPoint", "TOPLEFT", frame, "TOPLEFT", 0, 0)
    call(frame.heading, "SetJustifyH", "LEFT")
  end
  setText(frame.heading, model.heading)
  local width = textWidth(frame.heading, model.heading)
  local side, top = keepMargins()
  local slotTop = textHeight(frame.heading) + Preview.LINE_GAP + top
  local size = Preview.SLOT
  local icon
  local Assets = ItemTree.Assets
  local sample = Preview.SampleFor("keepMarks", Preview.Samples())
  if sample and type(Assets) == "table" and type(Assets.ItemIcon) == "function" then
    local ok, answer = pcall(Assets.ItemIcon, sample)
    icon = ok and answer or nil
  end
  local x, captionH = 0, 0
  local drawn = 0
  for index, entry in ipairs(model.slots) do
    local column = keepColumn(frame, index)
    if not column then
      break
    end
    setText(column.caption, entry.caption)
    local columnW = math.max(size + side * 2, textWidth(column.caption, entry.caption))
    local slotX = x + math.floor((columnW - size) / 2 + 0.5)
    call(column.slot, "ClearAllPoints")
    call(column.slot, "SetPoint", "TOPLEFT", frame, "TOPLEFT", slotX, -slotTop)
    call(column.slot, "Show")
    if icon then
      call(column.slot.icon, "SetTexture", icon)
    end
    setText(column.slot.count, entry.count or "")
    call(column.caption, "ClearAllPoints")
    call(column.caption, "SetPoint", "TOP", column.slot, "BOTTOM", 0, -(side + Preview.CAPTION_GAP))
    call(column.caption, "Show")
    captionH = math.max(captionH, textHeight(column.caption))
    Overlay.ShowKeep(
      column.overlay,
      entry.tier,
      model.style,
      model.ramp,
      size,
      model.corner,
      entry.valuable,
      entry.violet,
      model.markScale
    )
    call(column.overlay, "Show")
    column.entry = entry
    x = x + columnW + Preview.KEEP_GAP
    drawn = index
  end
  for index = drawn + 1, #(frame.columns or EMPTY) do
    local column = frame.columns[index]
    pcall(Overlay.HideKeep, column.overlay)
    call(column.slot, "Hide")
    call(column.caption, "Hide")
  end
  if drawn == 0 then
    return nil
  end
  width = math.max(width, x - Preview.KEEP_GAP)
  local height = slotTop + size + side + Preview.CAPTION_GAP + captionH
  frame.model = model
  call(frame, "SetSize", width, height)
  return width, height
end

-- One renderer per settings key: the popup's content frame and the current settings in, the
-- width and height drawn out (nil where nothing could be drawn). A key with no entry has no
-- example and no popup. Adding an example is one entry here.
Preview.RENDERERS = {}
for _, key in ipairs(Preview.TOOLTIP_KEYS) do
  Preview.RENDERERS[key] = function(content, settings)
    return drawTooltip(content, settings, key)
  end
end
for _, key in ipairs(Preview.SLOT_KEYS) do
  Preview.RENDERERS[key] = function(content, settings)
    return drawSlot(content, settings, key)
  end
end
for _, key in ipairs(Preview.PROFESSION_KEYS) do
  Preview.RENDERERS[key] = function(content, settings)
    return drawSlot(content, settings, key)
  end
end
-- Brief ST3 (QA item 318): the Changed badge's slot.
Preview.RENDERERS[Preview.CHANGED_SLOT_KEY] = function(content, settings)
  return drawSlot(content, settings, Preview.CHANGED_SLOT_KEY)
end
for _, key in ipairs(Preview.BADGE_KEYS) do
  Preview.RENDERERS[key] = function(content, settings)
    return drawRow(content, settings, key)
  end
end
for _, key in ipairs(Preview.HUD_KEYS) do
  Preview.RENDERERS[key] = function(content, settings)
    return drawHud(content, settings, key)
  end
end
-- Brief K16: the Keep marks rows share one renderer, found by section (Preview.KeepRow). Brief ST2:
-- it is handed the hovered key too, which picks the Use mark slot (Preview.USE_SLOT_KEYS).
Preview.KEEP_RENDERER = function(content, settings, key)
  return drawKeep(content, settings, key)
end

local function isKeepKey(key)
  return Preview.KeepRow(key) == true
end

local function rendererFor(key)
  if type(key) ~= "string" then
    return nil
  end
  if Preview.RENDERERS[key] then
    return Preview.RENDERERS[key]
  end
  if isKeepKey(key) then
    return Preview.KEEP_RENDERER
  end
  return nil
end

--- Draws one key's example onto the popup and sizes the popup around it. Answers true and the
--- content size, or false where the key has no example or nothing could be drawn.
function Preview.Draw(key)
  local renderer = rendererFor(key)
  if not renderer then
    return false
  end
  local frame = popupFrame()
  if not frame then
    return false
  end
  if not isKeepKey(key) then
    pcall(stopKeep)
  end
  local ok, width, height = pcall(renderer, frame.content, currentSettings(), key)
  width, height = tonumber(width), tonumber(height)
  if not ok or not width or not height then
    call(frame, "Hide")
    return false
  end
  call(frame.content, "SetSize", width, height)
  call(frame, "SetSize", width + Preview.PAD * 2, height + Preview.PAD * 2)
  frame.width = width + Preview.PAD * 2
  frame.height = height + Preview.PAD * 2
  frame.drawnKey = key
  return true, width, height
end

local function screenHeight()
  local height = tonumber(call(rawget(_G, "UIParent"), "GetHeight"))
  if height and height > 0 then
    return height
  end
  local getScreenHeight = rawget(_G, "GetScreenHeight")
  if type(getScreenHeight) == "function" then
    local ok, value = pcall(getScreenHeight)
    return (ok and tonumber(value)) or 0
  end
  return 0
end

-- How far up from a tooltip's owner the row can be: the label and the tick box are the row's
-- own children, the slider and the dropdown sit one holder further down.
local OWNER_DEPTH = 4

-- The client's own tooltip, while it is showing for this row: its owner is the row or one of
-- the row's frames (DefaultTooltipMixin makes the hovered label, tick box, slider or dropdown
-- the owner). A client whose tooltip cannot name its owner is taken at its word that it is shown.
local function clientTooltip(row)
  local tooltip = rawget(_G, "SettingsTooltip")
  if type(tooltip) ~= "table" or not call(tooltip, "IsShown") then
    return nil
  end
  if type(tooltip.GetOwner) ~= "function" then
    return tooltip
  end
  local owner = call(tooltip, "GetOwner")
  for _ = 0, OWNER_DEPTH do
    if type(owner) ~= "table" then
      return nil
    end
    if owner == row then
      return tooltip
    end
    owner = call(owner, "GetParent")
  end
  return nil
end

-- Stacked on the client's tooltip for the row, or on the row's control where the client shows
-- none: above it, or below where the top of the screen is in the way.
local function anchor(frame, row)
  local target, onto = clientTooltip(row), "tooltip"
  if not target then
    target, onto = row.itemTreePreviewControl or row, "control"
  end
  local stack =
    Preview.Stack(call(target, "GetTop"), call(target, "GetBottom"), frame.height, screenHeight(), Preview.GAP)
  call(frame, "ClearAllPoints")
  if stack == "BELOW" then
    call(frame, "SetPoint", "TOPLEFT", target, "BOTTOMLEFT", 0, -Preview.GAP)
  else
    call(frame, "SetPoint", "BOTTOMLEFT", target, "TOPLEFT", 0, Preview.GAP)
  end
  frame.stack, frame.onto = stack, onto
  return stack, onto
end

-- Where the pointer is, for the row the popup is showing. label and control are the two hover
-- states; held is the control pressed down and menu is a dropdown's menu open, both of which
-- count as being on the control.
local hover = {}

-- Brief K16: the row hooks (below, with the rows), declared here for Preview.Refresh.
local armRow, queueRearm

-- Brief K15: whether the colour picker UI/Options.lua opened is still open.
local function pickerActive()
  local Options = ItemTree.Options
  if type(Options) ~= "table" or type(Options.PickerActive) ~= "function" then
    return false
  end
  local ok, active = pcall(Options.PickerActive)
  return ok and active == true
end

local function stopTicking(frame)
  if frame then
    call(frame, "SetScript", "OnUpdate", nil)
  end
end

--- Hides the popup and forgets the row.
function Preview.Hide()
  hover = {}
  peeking = nil
  local frame = popup or nil
  if frame then
    stopTicking(frame)
    pcall(stopKeep)
    call(frame, "Hide")
  end
end

--- Shows the example for key beside row. Answers whether it is on screen.
function Preview.Show(row, key)
  if not Preview.Draw(key) then
    return false
  end
  local frame = popupFrame()
  anchor(frame, row)
  call(frame, "Show")
  return true
end

--- One tick of the grace timer, at a time the caller passes (a spec has no clock). Answers the
--- decision, and hides the popup when it is "hide".
function Preview.Tick(at)
  local since
  if hover.leftAt then
    since = (tonumber(at) or now()) - hover.leftAt
  end
  -- Brief K15: the colour picker closing (Okay, Cancel or a click outside) lets the popup go.
  if hover.picker and not pickerActive() then
    hover.picker = false
    if not hover.leftAt and not (hover.label or hover.control or hover.held or hover.menu) then
      hover.leftAt = tonumber(at) or now()
      since = 0
    end
  end
  local decision =
    Preview.Decision(hover.label, hover.control or hover.held or hover.menu or hover.picker, since, Preview.GRACE)
  if decision == "hide" then
    Preview.Hide()
  end
  return decision
end

local function startTicking()
  local frame = popup or nil
  if not frame then
    return
  end
  call(frame, "SetScript", "OnUpdate", function()
    Preview.Tick(now())
  end)
end

-- After any of the five states went false: once all five are, the grace starts.
local function released(at)
  if hover.picker and not (hover.label or hover.control or hover.held or hover.menu) then
    -- Held up by the colour picker alone: ticking, so its closing is noticed.
    startTicking()
  end
  if hover.label or hover.control or hover.held or hover.menu or hover.picker then
    return "show"
  end
  hover.leftAt = tonumber(at) or now()
  startTicking()
  return Preview.Tick(hover.leftAt)
end

--- The pointer moved on or off one part of a row: part is "label", "control", "held" or
--- "menu". A row it was not showing takes the popup over. at is the time, for the specs.
--- Answers the decision.
function Preview.Hover(row, key, part, over, at)
  if not Preview.HasExample(key) then
    return "hide"
  end
  if over then
    if hover.row ~= row or hover.key ~= key then
      Preview.Hide()
      hover = { row = row, key = key }
      if not Preview.Show(row, key) then
        hover = {}
        return "hide"
      end
    end
    hover[part] = true
    hover.leftAt = nil
    stopTicking(popup or nil)
    -- The client's tooltip has just moved to whatever part the pointer is on, so the popup
    -- follows it.
    if popup then
      anchor(popup, row)
    end
    return "show"
  end
  if hover.row ~= row or hover.key ~= key then
    return "hide"
  end
  hover[part] = false
  return released(at)
end

--- A dropdown's menu opening or closing, for the row showing key.
function Preview.MenuOpen(key, open, at)
  -- A menu closing, picked from or not, takes the example back to what the setting holds.
  Preview.Unpeek(key)
  if hover.key ~= key or not hover.row then
    return nil
  end
  return Preview.Hover(hover.row, key, "menu", open and true or false, at)
end

--- Brief K15: the colour picker opening from key's row (the Custom colour row) holds the popup up
--- while the picker is open, so the example follows the colour as it moves; the picker closing
--- lets it go through the grace, as the pointer leaving would. Answers the decision, or nil where
--- the popup is not showing key.
function Preview.PickerOpen(key, open, at)
  if hover.key ~= key or not hover.row then
    return nil
  end
  if open then
    hover.picker = true
    hover.leftAt = nil
    -- Ticking, so the picker closing is noticed once the pointer has left the row.
    startTicking()
    return "show"
  end
  hover.picker = false
  return released(at)
end

--- Forgets the popup, the row and the samples, so the next hover builds afresh. For the specs,
--- which change the client under the file between tests.
function Preview.Reset()
  Preview.Hide()
  peeking = nil
  popup = nil
  samples = nil
  keepIndex = nil
end

--- What the popup is showing: the key and the row, or nil.
function Preview.Current()
  return hover.key, hover.row
end

--- Redraws the popup for what the settings hold now. Options.OnChanged calls it for every
--- change, because one setting can change another row's example (the badge size changes the
--- corner row's slot). Answers whether a popup was redrawn.
function Preview.Refresh(key)
  if key == "showHarvested" then
    Preview.ResetSamples()
  end
  -- Brief K16: the client refills a dropdown whose value changed after this returns, which drops
  -- its hooks, so they go back on next frame.
  queueRearm(key)
  local frame = popup or nil
  if not frame or not hover.key or not hover.row then
    return false
  end
  if not Preview.Draw(hover.key) then
    return false
  end
  anchor(frame, hover.row)
  return true
end

--- Brief K14: the pointer is on the option of key's open menu that would store value. Redraws the
--- example as if the setting held value, without writing it. Answers whether a popup was redrawn.
function Preview.Peek(key, value)
  if not Preview.Peeks(key) or value == nil then
    return false
  end
  if peeking and peeking.key == key and peeking.value == value then
    return false
  end
  peeking = { key = key, value = value }
  return Preview.Refresh(key)
end

--- The pointer left key's options, or its menu closed: the example goes back to what the setting
--- holds. A key not being peeked at is left alone. Answers whether a popup was redrawn.
function Preview.Unpeek(key)
  if not peeking or (key ~= nil and peeking.key ~= key) then
    return false
  end
  peeking = nil
  return Preview.Refresh(key)
end

--- The function a dropdown option's data carries as onEnter (Settings.CreateDropdownButton hands
--- it to the menu, which calls it as the pointer lands on the option), or nil for a key that
--- does not peek. value is what the option would store.
function Preview.PeekHandler(key, value)
  if not Preview.Peeks(key) or value == nil then
    return nil
  end
  return function()
    Preview.Peek(key, value)
  end
end

--- Hooks every option of key's menu so the pointer leaving it ends the peek. rootDescription is
--- what Settings.CreateDropdownOptionInserter hands the initializer's customOptionHandler; each
--- option's description offers HookOnLeave, the menu's own additive hook. Answers how many
--- options were hooked.
function Preview.HookOptionLeaves(key, rootDescription)
  if not Preview.Peeks(key) or type(rootDescription) ~= "table" then
    return 0
  end
  local enumerate = rootDescription.EnumerateElementDescriptions
  if type(enumerate) ~= "function" then
    return 0
  end
  local ok, iterator, state, first = pcall(enumerate, rootDescription)
  if not ok or type(iterator) ~= "function" then
    return 0
  end
  local function left()
    Preview.Unpeek(key)
  end
  local hooked = 0
  pcall(function()
    for _, description in iterator, state, first do
      if type(description) == "table" and type(description.HookOnLeave) == "function" then
        if pcall(description.HookOnLeave, description, left) then
          hooked = hooked + 1
        end
      end
    end
  end)
  return hooked
end

--------------------------------------------------------------------------------
-- The rows. The client's own frames, hooked and never modified.
--------------------------------------------------------------------------------

-- The key a pooled row frame is drawing for us right now, or nil when it is somebody else's
-- row: the list hands the frame its initializer as element data, and a frame now showing
-- another initializer is not ours whatever it was last time.
local function liveKey(row)
  if type(row) ~= "table" then
    return nil
  end
  local key = row.itemTreePreviewKey
  if not key then
    return nil
  end
  if type(row.GetElementData) == "function" then
    local ok, data = pcall(row.GetElementData, row)
    if ok and data ~= nil and data ~= row.itemTreePreviewInit then
      return nil
    end
  end
  return key
end

local function hookScript(frame, script, handler)
  if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if not ok or not has then
      return false
    end
  end
  return (pcall(frame.HookScript, frame, script, handler))
end

-- Brief K16: why the Colour rows showed no example. The client sets some of a row's scripts
-- again every time it fills the row, and SetScript drops every hook HookScript put on that script.
-- Settings.InitDropdown (Blizzard_Settings_Shared/Blizzard_Settings.lua, forever branch) calls
-- dropdown:SetScript("OnEnter", ...) and SetScript("OnLeave", ...) on the row's Control.Dropdown
-- each time SettingsDropdownControlMixin:InitDropdown runs: on every Init (the page's OnShow
-- refills every row, UI/Options.lua refreshRow refills the Colour row each time the colour picker
-- turns it to Custom) and on every value change (SettingsDropdownControlMixin:SetValue, a menu
-- pick or an arrow step). A part hooked once lost its hooks then and was never hooked again. The
-- label, the arrows, the slider and the buttons have their scripts set once, at OnLoad, and keep
-- their hooks. So the Dropdown is hooked again after every fill of its row (bindRow) and on the
-- next frame after its setting changes (Preview.Rearm, queued by Preview.Refresh, which runs
-- inside the setter, before the client's own value callback refills the row). Each hooking is a
-- generation: a hook from an earlier generation that survived does nothing, so the part never
-- reports twice. Nothing is read back from the client's scripts.

local LABEL_SCRIPTS = { "OnEnter", "OnLeave" }
local CONTROL_SCRIPTS = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }

-- The handler each script runs for one part: the row is looked up at the time of the event, so a
-- pooled frame handed to another row of ours follows it.
local function partHandlers(part, row, name, generation)
  local function live()
    if part.itemTreePreviewGen ~= generation then
      return nil
    end
    return liveKey(row)
  end
  return {
    OnEnter = function()
      local key = live()
      if key then
        Preview.Hover(row, key, name, true, now())
      end
    end,
    OnLeave = function()
      local key = live()
      if key then
        Preview.Hover(row, key, name, false, now())
      end
    end,
    OnMouseDown = function()
      local key = live()
      if key then
        Preview.Hover(row, key, "held", true, now())
      end
    end,
    OnMouseUp = function()
      local key = live()
      if key then
        Preview.Hover(row, key, "held", false, now())
      end
    end,
  }
end

-- Hooks one part, in a new generation.
local function armPart(part, row, name)
  local generation = (tonumber(part.itemTreePreviewGen) or 0) + 1
  part.itemTreePreviewGen = generation
  local handlers = partHandlers(part, row, name, generation)
  for _, script in ipairs(name == "control" and CONTROL_SCRIPTS or LABEL_SCRIPTS) do
    hookScript(part, script, handlers[script])
  end
end

-- The part of a row the client sets scripts on again at each fill: a dropdown row's Dropdown.
local function refilledPart(row)
  local control = type(row) == "table" and rawget(row, "Control") or nil
  local dropdown = type(control) == "table" and rawget(control, "Dropdown") or nil
  if type(dropdown) == "table" and dropdown.itemTreePreviewRow == row then
    return dropdown
  end
  return nil
end

-- Hooks one part of a row the first time.
local function hookPart(part, row, name)
  if type(part) ~= "table" or part.itemTreePreviewRow then
    return
  end
  part.itemTreePreviewRow = row
  armPart(part, row, name)
end

-- Hooks the row's refilled part again. Answers how many parts were hooked.
armRow = function(row)
  local dropdown = refilledPart(row)
  if not dropdown then
    return 0
  end
  armPart(dropdown, row, "control")
  return 1
end

-- The row frames bound to one of our rows, weakly held, for Preview.Rearm.
local boundRows = setmetatable({}, { __mode = "k" })

--- Brief K16: hooks the Dropdown of every bound row drawing key again (every bound row where key
--- is nil), after the client refilled it for a value change. Answers how many were hooked.
function Preview.Rearm(key)
  local count = 0
  for row in pairs(boundRows) do
    if key == nil or row.itemTreePreviewKey == key then
      local ok, armed = pcall(armRow, row)
      if ok then
        count = count + armed
      end
    end
  end
  return count
end

-- The keys to hook again on the next frame, however many settings change in this one.
local rearmKeys = nil

queueRearm = function(key)
  if key == nil or next(boundRows) == nil then
    return false
  end
  if rearmKeys then
    rearmKeys[key] = true
    return true
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  rearmKeys = { [key] = true }
  local ok = pcall(timer.After, 0, function()
    local keys = rearmKeys or {}
    rearmKeys = nil
    for each in pairs(keys) do
      Preview.Rearm(each)
    end
  end)
  if not ok then
    rearmKeys = nil
  end
  return ok
end

local function children(frame)
  if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then
    return {}
  end
  local found = { pcall(frame.GetChildren, frame) }
  if not table.remove(found, 1) then
    return {}
  end
  return found
end

-- Every frame of the control, two levels down: the tick box itself, the slider and its steppers
-- inside their holder, the dropdown and its arrows inside theirs.
local function hookControl(frame, row, depth)
  hookPart(frame, row, "control")
  if depth >= 2 then
    return
  end
  for _, child in ipairs(children(frame)) do
    hookControl(child, row, depth + 1)
  end
end

-- Remembers which row of ours a pooled frame is drawing and hooks it the first time; every later
-- fill hooks again whatever part the client's fill set new scripts on (brief K16).
local function bindRow(frame, initializer, key)
  if type(frame) ~= "table" then
    return false
  end
  frame.itemTreePreviewKey = key
  frame.itemTreePreviewInit = initializer
  boundRows[frame] = true
  if frame.itemTreePreviewHooked then
    -- The client's fill has just set the Dropdown's scripts again (brief K16).
    armRow(frame)
    return true
  end
  frame.itemTreePreviewHooked = true
  local label = frame.Tooltip
  hookPart(label, frame, "label")
  for _, child in ipairs(children(frame)) do
    if child ~= label then
      hookControl(child, frame, 1)
      -- The control is the last child: the client makes it in the row's OnLoad, after the
      -- template's own frames. It is where the popup stacks when the client shows no tooltip.
      frame.itemTreePreviewControl = child
    end
  end
  -- The panel closing, or the row scrolling away, takes the popup with it.
  hookScript(frame, "OnHide", function()
    if hover.row == frame then
      Preview.Hide()
    end
  end)
  return true
end

local function unbindRow(frame)
  if type(frame) ~= "table" then
    return
  end
  frame.itemTreePreviewKey = nil
  frame.itemTreePreviewInit = nil
  if hover.row == frame then
    Preview.Hide()
  end
end

--- Hooks the popup onto one settings row. initializer is what Settings.CreateCheckbox,
--- CreateSlider or CreateDropdown answered, key the setting and kind the row's kind from
--- Options.Definitions. A key with no example is left alone. The client's own InitFrame and
--- Resetter run first, exactly as before; ours follows, pcall'd. Answers whether it hooked.
function Preview.AttachRow(initializer, key, kind)
  if type(initializer) ~= "table" or not Preview.HasExample(key) then
    return false
  end
  if initializer.itemTreePreviewKey then
    return true
  end
  initializer.itemTreePreviewKey = key
  local baseInit = initializer.InitFrame
  initializer.InitFrame = function(self, frame)
    if type(baseInit) == "function" then
      baseInit(self, frame)
    end
    pcall(bindRow, frame, self, key)
  end
  local baseReset = initializer.Resetter
  initializer.Resetter = function(self, frame)
    if type(baseReset) == "function" then
      baseReset(self, frame)
    end
    pcall(unbindRow, frame)
  end
  if kind == "dropdown" and initializer.OnShow == nil and initializer.OnHide == nil then
    initializer.OnShow = function()
      Preview.MenuOpen(key, true, now())
    end
    initializer.OnHide = function()
      Preview.MenuOpen(key, false, now())
    end
  end
  -- Brief K14: the client calls the initializer's own customOptionHandler with the menu each
  -- time it builds it, after our options are in, so each option can end the peek on leave.
  if kind == "dropdown" and Preview.Peeks(key) and initializer.customOptionHandler == nil then
    initializer.customOptionHandler = function(rootDescription)
      pcall(Preview.HookOptionLeaves, key, rootDescription)
    end
  end
  return true
end

return Preview
