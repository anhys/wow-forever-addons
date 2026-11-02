-- Settings panel. Implements the Settings screen from design ui_kits/itemtree_addon/
-- ScreensOther.jsx inside the game's own options window, as a category of its own. One
-- checkbox per boolean in ItemTree.db.settings, grouped and ordered the way the design groups
-- and orders them.
--
-- The design is four panels down a sidebar: Display, Data confidence, Integration, Edit
-- Mode. A Settings category is one scrolling page, so each panel became a section header,
-- named in Options.SECTIONS and carried on every entry in ORDER. Brief S7 split the design's
-- Integration panel into Badges, Tooltips, Bags, Keys and clicks, and Minimap. Brief ST2 joined
-- Badges and Bags into New and Changed badges, beside Keep and Use marks (QA item 307). Brief ST3
-- (QA items 315 to 317) named it Forever badges, laid its switches out as kinds over places (a
-- "Where" sub heading over the bag and bank switches) and moved the portraits to Performance.
--
-- Brief E94: the category is a canvas the page draws itself, with the client's own row
-- templates on frames of ours, so it looks like the client's settings list while the game's
-- settings search never reads a row of it. See the canvas section below the divider.
--
-- The page also carries rows that are not settings: the two key binding rows, which open the
-- Keys and clicks section, the Summary HUD's reset position button, which sits under "Unlock to
-- move", a Reset position row under each minimap button, and a logo row at the top.
--
-- The list ends on a section the design has no panel for, "Source databases": the tick
-- box that turns reading them on and off, and one row per database that IS installed saying
-- what state it is in. It offers, links to and recommends nothing (brief E1). See the Source
-- databases sections, one above the divider and one below.
--
-- Options.Definitions is pure and runs under busted: it is the single ordered description
-- of every setting, and the page is generated from it. Everything else is guarded.
local _, ItemTree = ...

local Options = {}
ItemTree.Options = Options

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

Options.CATEGORY_NAME = "ItemTree"

-- The row label for the key binding control, and the full sentence behind it. The label is
-- kept short because the client's own key binding row truncates its label column at about
-- twenty five characters. It is not a setting: it writes a client key binding, not
-- ItemTree.db.settings, so it is deliberately outside Definitions and ORDER.
Options.KEYBIND_LABEL = "Tree for hovered item"
Options.KEYBIND_TOOLTIP = "Open the tree for the hovered item"

-- Brief B1: the second key binding row, under the first, for the key that opens the Boss loot tab
-- (UI/Keybind.lua Keybind.BOSS_BINDING). Unbound by default. The second tooltip line is added only
-- while the Boss loot tab is turned off, because the key opens nothing then.
Options.BOSS_KEYBIND_LABEL = "Open Boss loot"
Options.BOSS_KEYBIND_TOOLTIP = "Opens the window on the Boss loot tab, or closes it when it is already there."
-- The row sits on the settings page itself, so it names the section the tab's switch is in (brief S7).
Options.BOSS_KEYBIND_OFF = "The Boss loot tab is turned off under Feature tabs."

-- The Summary HUD's reset row, under the Fixed position tooltip tick boxes. Not a setting
-- either: it runs UI/EditMode.lua's ResetPosition, which writes the per character position back
-- to the default, so it is outside Definitions and ORDER the same way the key binding row is.
-- The row label is the section's own name: "Fixed position tooltip position" reads badly, and
-- the button beside it already says what the row does.
Options.HUD_RESET_LABEL = "Fixed position tooltip"
Options.HUD_RESET_BUTTON = "Reset position"
Options.HUD_RESET_TOOLTIP = "Puts the fixed position tooltip back where it started."

-- The window scale slider. The range is the one the window itself can take: a half size
-- window is still readable and anything over one and a half fills the screen on the owner's
-- resolution. The step is fine enough to nudge and coarse enough to land on round numbers.
--
-- Core owns the numbers, because it is Core that clamps a migrated setting to the same range
-- (ItemTree.RebaseScale) and UI/Frame.lua that clamps what the slider hands back. These are the
-- fallbacks for a load order that has not reached Core/Init.lua, the way UI/Frame.lua reads
-- them: the panel is built long after load, so in the client it is always Core's numbers.
Options.SCALE_MIN = tonumber(ItemTree.SCALE_MIN) or 0.5
Options.SCALE_MAX = tonumber(ItemTree.SCALE_MAX) or 1.5
Options.SCALE_STEP = tonumber(ItemTree.SCALE_STEP) or 0.05

-- The right hand label on the slider: 1.0 reads "1.00x". Punctuation rather than copy, so
-- the format is not a locale string.
Options.SCALE_FORMAT = "%.2fx"

-- The slider's right hand label. Pure, so the wording is specced with no client present.
function Options.ScaleLabel(value)
  return string.format(Options.SCALE_FORMAT, tonumber(value) or 1)
end

-- The bag badge size slider and corner dropdown (brief U1). UI/Overlay.lua owns the numbers,
-- because it is Overlay.Scale that holds a stored value to the same range; these fallbacks are
-- for a load order that has not reached it, the way the window scale reads Core's. Its right
-- hand label is Options.ScaleLabel, so it reads "0.50x" like the window scale does.
local OVERLAY = ItemTree.UI and ItemTree.UI.Overlay or EMPTY
Options.BADGE_SCALE_MIN = tonumber(OVERLAY.SCALE_MIN) or 0.2
Options.BADGE_SCALE_MAX = tonumber(OVERLAY.SCALE_MAX) or 1.5
Options.BADGE_SCALE_STEP = tonumber(OVERLAY.SCALE_STEP) or 0.05
-- Brief ST2 (QA item 307): the Mark size slider, the same way: Overlay.MarkScale holds a stored
-- value to the range, and it reads "1.00x" at today's size.
Options.MARK_SCALE_MIN = tonumber(OVERLAY.MARK_SCALE_MIN) or 0.4
Options.MARK_SCALE_MAX = tonumber(OVERLAY.MARK_SCALE_MAX) or 1.5
Options.MARK_SCALE_STEP = tonumber(OVERLAY.MARK_SCALE_STEP) or 0.05

-- Brief K9: the Keep value slider. Brief K10: it moves over fixed stops (Core/Keep.lua
-- Keep.VALUE_STOPS, in copper, Off first), the slider's position is the stop's index, and its
-- right hand label is Options.ValueLabel, "Off", "1 silver", "100 gold". Keep loads first in the
-- TOC; without it (a spec that loads this file alone) the stops are Off and the 100 gold default.
local VALUE_STOPS_FALLBACK = { 0, 1000000 }

local function valueStops()
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.VALUE_STOPS) == "table" and #keep.VALUE_STOPS > 0 then
    return keep.VALUE_STOPS
  end
  return VALUE_STOPS_FALLBACK
end

-- The slider's range: the first stop to the last. The last is counted when the definitions are
-- built, so the row follows Keep's table whatever loaded first.
Options.VALUE_STOP_MIN = 1
Options.VALUE_STOP_STEP = 1
function Options.ValueStopCount()
  return #valueStops()
end

-- The slider position a stored copper value reads as: the nearest stop at or below it, so an
-- old 30 gold sits on 20 gold, without the setting being rewritten. Missing reads as the default.
-- Pure.
function Options.ValueStopIndex(copper)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.ValueStopIndex) == "function" then
    return keep.ValueStopIndex(copper)
  end
  local value = tonumber(copper)
  if value == nil then
    value = VALUE_STOPS_FALLBACK[#VALUE_STOPS_FALLBACK]
  end
  local index = 1
  for i, stop in ipairs(VALUE_STOPS_FALLBACK) do
    if value >= stop then
      index = i
    end
  end
  return index
end

-- The copper a slider position stores, held inside the stops. Pure.
function Options.ValueStopCopper(index)
  local stops = valueStops()
  local i = math.floor((tonumber(index) or 1) + 0.5)
  if i < 1 then
    i = 1
  elseif i > #stops then
    i = #stops
  end
  return stops[i]
end

-- The Keep value slider's right hand label for a slider position. Pure.
function Options.ValueLabel(index)
  local copper = Options.ValueStopCopper(index)
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.ValueLabel) == "function" then
    return keep.ValueLabel(copper)
  end
  if copper <= 0 then
    return L["Off"]
  end
  return string.format(L["%d gold"], math.floor(copper / 10000))
end

-- The fifth section, which the design has no panel for: where the source databases the player
-- installs as other addons are spoken about. Named here because Options.SECTIONS and the
-- ORDER entry below both want it; everything else about the section is in its own block.
Options.PROVIDER_SECTION = "Source databases"

-- The design's Settings screen is four panels down the left: Display, Data confidence,
-- Integration, Edit Mode. The client's Settings category is one scrolling list, so each
-- panel became a section header. The design's Edit Mode panel is headed Fixed position
-- tooltip, which is what players call the Summary HUD: the Forever client ships no Edit Mode,
-- and a section named after a screen the player cannot open sends them looking.
-- Brief S7: Integration grew too large, so it is split by what each row reaches into: Badges
-- (with the quest marks, which had a Quests section of their own since brief Q5), Tooltips,
-- Bags, Keys and clicks, and Minimap. The looks come first, then the places ItemTree appears
-- in the client, then Performance and Data confidence.
-- Brief S5: Performance, which the design has no panel for, holds the settings that trade memory
-- or load time for speed.
-- Brief S6: the tab section, which the design has no panel for either, comes last: which tabs the
-- window draws, the Discoveries tab's row here and the Boss loot tab's (and a developer tab's)
-- registered by their modules. The owner named it Feature tabs (brief E96); it was Window.
Options.TABS_SECTION = "Feature tabs"
-- The section the two key binding rows open (brief S7), named because Options.Install draws them
-- as its header is passed.
Options.KEYS_SECTION = "Keys and clicks"
-- Brief K12: the Keep marks section, straight after Bags: the Keep marks switch, the value slider
-- (both moved from Bags, keys unchanged), and the Style and Colours rows that pick the look.
-- Brief ST2 (QA item 307, the owner's ruling A: "two sliders by family"): two headings, one a
-- family of marks. New and Changed badges takes in the Badges and Bags sections (the window's New
-- and Changed switches, the quest marks, the bag and bank switches, Badge size and the corner),
-- where Bags was, so the two families sit side by side; Keep marks becomes Keep and Use marks,
-- with the Keep marks and Use mark switches and the Mark size slider that sizes both marks. Keys
-- and saved values are unchanged: only the headers and Badge size's words moved.
-- Brief ST3 (QA item 316, the owner: "New and changed should be called Forever badges"): the
-- heading's words only; UI/ProfessionsStub.lua BAG_SECTION names it too.
Options.BADGES_SECTION = "Forever badges"
Options.KEEP_SECTION = "Keep and Use marks"
-- Brief TD1 (a player's CurseForge comment, the owner's ruling of 2026-10-23): Tooltips became
-- Tooltip display, a switch per kind of ItemTree tooltip line. The rows that were under Tooltips are
-- under it with their keys and saved values unchanged.
Options.TOOLTIP_SECTION = "Tooltip display"
Options.SECTIONS = {
  "Display",
  Options.TOOLTIP_SECTION,
  "Fixed position tooltip",
  Options.BADGES_SECTION,
  Options.KEEP_SECTION,
  Options.KEYS_SECTION,
  "Minimap",
  "Performance",
  "Data confidence",
  Options.PROVIDER_SECTION,
  Options.TABS_SECTION,
}

-- The order of the rows inside a section, where it is not the order the rows are listed or
-- registered in (brief E96). The tab rows follow the strip, Boss loot then Discoveries, whichever
-- module registers first; a key not listed keeps its place after the listed ones, which is where
-- a developer build's own tab row lands, last as its tab is.
Options.SECTION_KEY_ORDER = {
  [Options.TABS_SECTION] = { "showBossLoot", "showDiscoveries" },
}

-- Order and grouping follow the design's Settings screen. Keys must exist in Core/Init.lua
-- DB_DEFAULTS, and every entry names a section from Options.SECTIONS.
--
-- Two settings have no home in the design and sit under the closest section: "Record what
-- you see" is what turns predicted data into verified data, so it goes under Data
-- confidence beside the predicted marker, and "Show minimap button" is another place
-- ItemTree appears in the rest of the UI, so it has a Minimap section of its own (brief S7).
-- Dropdown rows whose options come from another module rather than from a list written out
-- here. Keyed by the name an ORDER entry gives in optionSource.
local CHOICE_SOURCES = {}

-- The "Open with a click" options: value, label, in the order UI/Keybind.lua lists them, so
-- the two can never drift over what a click means. An empty list on a build where Keybind did
-- not load, which leaves the row undrawn rather than drawn with nothing in it.
function CHOICE_SOURCES.click()
  local keybind = ItemTree.Keybind
  local source = keybind and keybind.CLICK_OPTIONS
  local out = {}
  if type(source) ~= "table" then
    return out
  end
  for _, option in ipairs(source) do
    out[#out + 1] = { value = option.value, label = L[option.label] }
  end
  return out
end

-- EXPERIMENTAL (brief E25, brief E30): the six ways the Used by view can show what a craft is
-- made of. Core owns the six values (Core/ViewModel.lua CRAFT_INGREDIENT_MODES) and this owns
-- the words for them, in the order they are offered: nothing, then everything, then the four
-- answers on their own in the order they take over the window, from the tooltip alone to the
-- info column. "All" sits second because it is the default and the one most players want; the
-- four below it are there to be compared. The whole row comes out with the feature once the
-- owner has picked one.
local CRAFT_INGREDIENT_LABELS = {
  off = "Off",
  all = "All",
  tooltip = "In the tooltip",
  group = "As a group",
  strip = "As a strip",
  card = "In the item column",
}

function CHOICE_SOURCES.craftIngredients()
  local ViewModel = ItemTree.ViewModel
  local modes = ViewModel and ViewModel.CRAFT_INGREDIENT_MODES
  local out = {}
  if type(modes) ~= "table" then
    return out
  end
  for _, mode in ipairs(modes) do
    local label = CRAFT_INGREDIENT_LABELS[mode]
    if label then
      out[#out + 1] = { value = mode, label = L[label] }
    end
  end
  return out
end

-- Brief BQ7: the keys that show every use on a tooltip while held (UI/Tooltip.lua
-- Tooltip.UsesModifier), Ctrl first since it is the default and lines up with Ctrl + right click.
function CHOICE_SOURCES.usesModifier()
  return {
    { value = "ctrl", label = L["Ctrl"] },
    { value = "shift", label = L["Shift"] },
    { value = "alt", label = L["Alt"] },
  }
end

-- Brief U1: the four corners a bag badge can sit in, in UI/Overlay.lua's own order, with the
-- words for each. The values are the client's anchor point names, which is what Overlay reads.
-- Written as L literals rather than through a table so the locale sweep finds every one.
function CHOICE_SOURCES.badgeCorner()
  return {
    { value = "TOPLEFT", label = L["Top left"] },
    { value = "TOPRIGHT", label = L["Top right"] },
    { value = "BOTTOMLEFT", label = L["Bottom left"] },
    { value = "BOTTOMRIGHT", label = L["Bottom right"] },
  }
end

-- Brief K12: the Keep marks section's Style row, the Classic look (style 0) first and then the
-- twelve looks by name, in UI/Overlay.lua's own order (KEEP_LOOKS), so the row and the demo number
-- them alike. The control holds the style as a string ("0" to "12"), the setting the number Overlay
-- reads. Without Overlay loaded (a spec that loads this file alone) the row offers style 0 only.
-- Brief K17: style 0 is named Classic, since the Flag ships now.
function CHOICE_SOURCES.keepStyle()
  local out = { { value = "0", label = L["Classic (glow and frame)"] } }
  local overlay = ItemTree.UI and ItemTree.UI.Overlay
  local looks = type(overlay) == "table" and overlay.KEEP_LOOKS or nil
  for index, look in ipairs(type(looks) == "table" and looks or {}) do
    out[#out + 1] = { value = tostring(index), label = look.name }
  end
  return out
end

-- The Style row's control value for a stored style, the shipped look for anything Overlay would
-- not draw. Pure.
function Options.KeepStyleToControl(value)
  local overlay = ItemTree.UI and ItemTree.UI.Overlay
  if type(overlay) == "table" and type(overlay.StyleIndex) == "function" then
    return tostring(overlay.StyleIndex(value))
  end
  local index = tonumber(value)
  if index == nil or index ~= math.floor(index) or index < 0 then
    return "0"
  end
  return tostring(index)
end

-- The style a Style row choice stores, as the number Overlay reads. Pure.
function Options.KeepStyleFromControl(value)
  local index = tonumber(value)
  if index == nil or index ~= math.floor(index) or index < 0 then
    return 0
  end
  return index
end

-- Brief K24b (E): the Colours row (Gold, Quality, Heat, Single colour) is gone from the page: the
-- look always uses the single colour (UI/Overlay.lua Overlay.SettingsRamp, the one reader), and a
-- saved choice of another set stays in the saved file, ignored.

-- Brief K15: the Colour row, the Single colour set's quick picks in UI/Theme.lua keepColors' order,
-- then Custom, the player's own colour from the Custom colour row's picker. L literals, as above.
function CHOICE_SOURCES.keepColor()
  return {
    { value = "yellow", label = L["Yellow"] },
    { value = "gold", label = L["Gold"] },
    { value = "orange", label = L["Orange"] },
    { value = "red", label = L["Red"] },
    { value = "pink", label = L["Pink"] },
    { value = "purple", label = L["Purple"] },
    { value = "blue", label = L["Blue"] },
    { value = "teal", label = L["Teal"] },
    { value = "green", label = L["Green"] },
    { value = "white", label = L["White"] },
    { value = "silver", label = L["Silver"] },
    { value = "custom", label = L["Custom"] },
  }
end

-- Brief K20c (design K20 section 2): the "List on the auction house when it beats the vendor by"
-- row's stops, in Core/Keep.lua BAR_STOPS' order, each value its key there. L literals, as above.
function CHOICE_SOURCES.keepSellBar()
  return {
    { value = "never", label = L["Never"] },
    { value = "10s", label = L["+10 silver"] },
    { value = "1g", label = L["+1 gold"] },
    { value = "1.25x", label = L["1.25 x"] },
    { value = "1.5x", label = L["1.5 x"] },
    { value = "2x", label = L["2 x"] },
    { value = "3x", label = L["3 x"] },
    { value = "formula", label = L["Formula"] },
  }
end

-- Brief K20c: the Bar row's hover text, a sentence a key. Brief K24b: the auction house is offered
-- as the Auction tag, and the hidden 5 silver floor is gone.
local SELL_BAR_TOOLTIP = L["How much more than the vendor an auction must pay per item, after its cut."]
  .. " "
  .. L["An item that falls short is not offered for auction; lower it to see more. Never never offers it."]
  .. " "
  .. L["Formula takes your own, such as max(vendor * 2, vendor + 1g)."]

-- The Style row's hover text, a sentence a key so each fits the line limit. Brief K24b: the looks
-- take the Colour row's colour now, the Colours row is gone.
local KEEP_STYLE_TOOLTIP = L["How bag and bank items worth keeping are marked."]
  .. " "
  .. L["Classic is the gold glow and frame. The other styles take the Colour row's colour."]
-- Brief K15: the Colour row and the Custom colour row under it. Brief K24b: the Keep tag in the
-- tooltip wears it too.
local KEEP_COLOR_TOOLTIP = L["The colour of the Keep tag in tooltips and of the marks on bag items you keep."]
  .. " "
  .. L["Custom is the colour you choose with the Custom colour row."]
local KEEP_CUSTOM_TOOLTIP = L["Opens the colour picker to choose your own Keep colour."]
  .. " "
  .. L["The bags and the example follow it as you move it. Okay keeps it, Cancel puts back the old one."]
-- Brief K16: the Valuable colour row and the Custom valuable colour row under it. Brief K24b: the
-- Auction tag in the tooltip wears it too.
local KEEP_VALUE_COLOR_TOOLTIP =
  L["The colour of the Auction tag in tooltips and of bag items worth the Valuable at amount or more."]
local KEEP_VALUE_CUSTOM_TOOLTIP = L["Opens the colour picker to choose your own colour for valuable items."]
  .. " "
  .. L["The bags and the example follow it as you move it. Okay keeps it, Cancel puts back the old one."]

-- Brief K16: the Keep marks section's two palette colours, each a Colour style dropdown (the
-- palette and Custom) with a Custom row under it whose button opens the colour picker. One helper
-- declares both rows of a pair (Options.ColourPairRows); Options.OpenColourPicker takes the
-- pair's two keys. Brief K24b: no requires any more (the single colour is always the look, and the
-- valuable colour also tints the Auction tag, so it is open with the value setting off too).
-- fallbackToken is what a custom colour reads as when it is not one.
Options.COLOUR_PAIRS = {
  {
    colorKey = "keepColor",
    customKey = "keepColorCustom",
    label = L["Colour"],
    customLabel = L["Custom colour"],
    tooltip = KEEP_COLOR_TOOLTIP,
    customTooltip = KEEP_CUSTOM_TOOLTIP,
    fallbackToken = "ITEMTREE_COLOR_KEEP_GLOW",
  },
  {
    colorKey = "keepValueColor",
    customKey = "keepValueColorCustom",
    label = L["Valuable colour"],
    customLabel = L["Custom valuable colour"],
    tooltip = KEEP_VALUE_COLOR_TOOLTIP,
    customTooltip = KEEP_VALUE_CUSTOM_TOOLTIP,
    fallbackToken = "ITEMTREE_COLOR_KEEP_VALUE",
  },
}

--- The two rows one colour pair declares: the dropdown's ORDER entry (the palette plus Custom,
--- under Keep marks and greyed out with it and with the pair's requires) and the Custom row's
--- spec for Options.SWATCH_ROWS, straight after the dropdown. Brief K17: the Custom row also
--- needs the dropdown on Custom, so it greys out as the dropdown steps off it. Pure.
function Options.ColourPairRows(pair)
  local swatchRequires = { [pair.colorKey] = "custom" }
  for key, wanted in pairs(pair.requires or {}) do
    swatchRequires[key] = wanted
  end
  local dropdown = {
    key = pair.colorKey,
    label = pair.label,
    section = Options.KEEP_SECTION,
    kind = "dropdown",
    optionSource = "keepColor",
    tooltip = pair.tooltip,
    dependsOn = { "keepMarks" },
    requires = pair.requires,
  }
  local swatch = {
    key = pair.customKey,
    after = pair.colorKey,
    section = Options.KEEP_SECTION,
    dependsOn = { "keepMarks" },
    requires = swatchRequires,
    pair = pair,
  }
  return dropdown, swatch
end

--- Brief K17: whether a change to this setting can change what a Custom row's swatch shows: its
--- own custom key, or any key the row watches for its enabling. Pure.
function Options.SwatchWatches(key)
  for _, swatch in ipairs(Options.SWATCH_ROWS or EMPTY) do
    if key == swatch.key then
      return true
    end
    for _, watched in ipairs(Options.WatchedKeys(swatch)) do
      if key == watched then
        return true
      end
    end
  end
  return false
end

--- The colour pair a colour or custom key belongs to, or nil. Pure.
function Options.ColourPair(key)
  for _, pair in ipairs(Options.COLOUR_PAIRS) do
    if pair.colorKey == key or pair.customKey == key then
      return pair
    end
  end
  return nil
end

local COLOUR_DROPDOWN, COLOUR_SWATCH = Options.ColourPairRows(Options.COLOUR_PAIRS[1])
local VALUE_COLOUR_DROPDOWN, VALUE_COLOUR_SWATCH = Options.ColourPairRows(Options.COLOUR_PAIRS[2])

-- Brief T4: the Keep marks row's hover text, held here only to keep the line under the length limit.
-- Brief K1: followed by Core/Keep.lua's own help text, which names the sold everywhere thresholds,
-- read when the definitions are built so the words live in one place. A function, which
-- Options.Definitions calls; without Keep loaded the row keeps its first sentence alone.
local KEEP_TOOLTIP_BASE =
  L["A gold glow on bag items with uses still ahead of you, and a line in their tooltip. Off draws neither."]
local function KEEP_TOOLTIP()
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.HelpText) == "function" then
    local ok, help = pcall(keep.HelpText)
    if ok and type(help) == "string" and help ~= "" then
      -- Brief K20b: the order of decision (Keep.OrderText) before the thresholds.
      local okOrder, order = false, nil
      if type(keep.OrderText) == "function" then
        okOrder, order = pcall(keep.OrderText)
      end
      if okOrder and type(order) == "string" and order ~= "" then
        return KEEP_TOOLTIP_BASE .. " " .. order .. " " .. help
      end
      return KEEP_TOOLTIP_BASE .. " " .. help
    end
  end
  return KEEP_TOOLTIP_BASE
end

-- Brief K9: the Keep value row's hover text, split so each key fits the line limit. Brief K19: the
-- price is an auction addon's scan, or the item's vendor sell price where none has one. Brief
-- K20b: the value no longer marks an item worth keeping; it is the orange, on whatever it reads.
local VALUE_TOOLTIP = L["An item a vendor or the auction house values at this much or more wears orange with a flame."]
  .. " "
  .. L["The price is an installed auction addon's own scan (Auctionator, Auctioneer or TSM),"]
  .. " "
  .. L["or the item's vendor sell price where no addon has a price."]
  .. " "
  .. L["ItemTree never scans the auction house."]
  .. " "
  .. L["The first stop turns it off."]

-- Brief F1: the Merge recipes words, one sentence a line, in the one place both surfaces read them.
-- The settings row joins them into its hover text; the window's footer tick box (UI/Frame.lua
-- Frame.MergeToggleTip) stacks them under the title, so the two can never say different things.
-- Written as L literals so the locale sweep finds each one. Pure.
function Options.MergeTooltipLines()
  return {
    L["Show a recipe and the item it makes as one row."],
    L["Fold a set's undiscovered piece into the found piece for the same slot."],
    L["Turn this off to see the spell, the item and every piece the set lists on separate rows."],
  }
end

-- Brief SR1: the Search everything hover text, sentences written as L literals so the locale
-- sweep finds each one: what the search then finds, that items still lead the list, and (brief
-- SR3) that it is on by default and what turning it off does.
local function SEARCH_EVERYTHING_TOOLTIP()
  return L["The search box also finds quests, vendors, zones, herbs, veins, chests and item sets by name."]
    .. " "
    .. L["Open their pages straight from the search. Item results still come first, then creatures."]
    .. " "
    .. L["On by default. Turn it off to search items and creatures only, for a shorter list."]
end

local function MERGE_TOOLTIP()
  return table.concat(Options.MergeTooltipLines(), " ")
end

-- An entry's hover text: a string through the locale table, or a function's answer as it stands.
local function tooltipOf(entry)
  local tooltip = entry.tooltip
  if type(tooltip) == "function" then
    local ok, text = pcall(tooltip)
    if ok and type(text) == "string" then
      return text
    end
    return nil
  end
  return tooltip and L[tooltip] or nil
end

local ORDER = {
  -- Display: the design's Tree group, then "Compare against", then how the window presents itself.
  {
    key = "density",
    label = "Compact rows",
    section = "Display",
    kind = "choice",
    choices = { "default", "compact" },
    checkedValue = "compact",
    uncheckedValue = "default",
  },
  -- The same tick box the window's footer carries beside Compact rows, so a player who found it
  -- there and a player who came looking in the settings are changing the one setting. Compact
  -- rows above it is the footer's other tick box (brief E76).
  {
    key = "mergeCrafts",
    label = "Merge recipes",
    section = "Display",
    tooltip = MERGE_TOOLTIP,
  },
  -- EXPERIMENTAL (brief E25), beside Merge recipes because it is the same question about the
  -- same row: what a craft is, and what it is made of. Four ways of answering it, so the owner
  -- can try each one in game; three of them come out again once he has chosen. All is the
  -- default and draws three of the four together (brief E30).
  {
    key = "craftIngredients",
    label = "Ingredients under Used by",
    section = "Display",
    kind = "dropdown",
    optionSource = "craftIngredients",
    tooltip = "Experimental. Four ways to see what a craft is made of without leaving the row. "
      .. "All shows the tooltip, the group and the item column together.",
  },
  -- Brief ST3 (QA item 315): Creature portraits and Boss portraits moved from here to Performance.
  -- No control, on purpose. The dropdown machinery is here and the two values are written
  -- out, but the addon ships one Diff module built against one baseline (Data/generated/Meta
  -- states baseline and build), nothing in Core reads the setting, and there is no previous
  -- build's data to compare against, so a dropdown would be a row that changes nothing. It
  -- keeps its default and its locale key until a second comparison exists.
  {
    key = "compareBuild",
    label = "Compare against",
    section = "Display",
    kind = "choice",
    choices = { "baseline", "previous" },
  },
  -- Not in the design, which has no scale control at all. It belongs under Display because
  -- it is the one setting that changes how big everything in the window is drawn.
  {
    key = "windowScale",
    label = "Window scale",
    section = "Display",
    kind = "slider",
    min = Options.SCALE_MIN,
    max = Options.SCALE_MAX,
    step = Options.SCALE_STEP,
    tooltip = "1x fits the window to about two thirds of your screen.",
  },
  -- Not in the design either, and last under Display for the same reason the scale slider is
  -- near the end: it is about how the window presents itself rather than about what it lists.
  -- The game's own click, page and open sounds on ItemTree's own controls (UI/Sound.lua). It
  -- takes effect on the click after it, with no reload.
  {
    key = "interfaceSounds",
    label = "Interface sounds",
    section = "Display",
    tooltip = "Play the game's own click and page sounds on ItemTree's buttons, tabs and tick boxes.",
  },
  -- Brief SR1: the search box also finds the other kinds of page by name (UI/Frame.lua
  -- Frame.SearchAll). Under Display because it changes what the window's own search lists. On by
  -- default since brief SR3 (Core/Init.lua MigrateSearchEverythingOn); off, the search is the
  -- items and creatures search it always was.
  {
    key = "searchEverything",
    label = "Search everything",
    section = "Display",
    tooltip = SEARCH_EVERYTHING_TOOLTIP,
  },
  -- Brief F155 (owner QA 2026-10-14 item 155, "Hide other faction data / On by default"): under
  -- Display, beside Search everything, because it changes what the window's lists and searches show.
  -- The one key Core/Graph.lua Graph.HidesOtherFaction reads. No hover example (UI/OptionsPreview.lua):
  -- what it hides is rows in the window, which the preview has none of.
  {
    key = "hideOtherFaction",
    label = "Hide other faction data",
    section = "Display",
    -- Brief SF1 (CH1's queued note, QA item 295): CH1 made it hide the other side's quests on NPC
    -- pages' Quests tabs too, so the words name them.
    tooltip = "Hides the other faction's trainers, vendors and quests, because this character "
      .. "cannot use them: on item pages and their counts, on NPC pages' Quests tabs, in searches, in the "
      .. "Trainers & vendors panel and on zone maps. Drops and neutral NPCs always show. Off shows them, "
      .. "marked with their faction.",
  },
  -- Tooltip display (brief TD1; it was Tooltips, brief S7, from Integration): the design's "Where badges
  -- appear" group starts with the item tooltips and the lines they can carry. Brief U4: the rows after
  -- the master switch only mean anything while it is on, so they sit indented under it and greyed out
  -- while it is off (dependsOn, brief U2c). Brief TD1 (a player's CurseForge comment: "Can you add a
  -- setting so ItemTree doesn't add quests to tooltips?", the owner's ruling of 2026-10-23): one switch
  -- per kind of line, every one on by default: the Keep and sell tags (the tag row as a whole, in the
  -- tooltip alone), the badge line, the uses line, then the three kinds a line's glyph tells apart
  -- wherever it is drawn (UI/Tooltip.lua Tooltip.CATEGORY_KEYS: quests, professions, gear), the fold,
  -- the icons, and the hint last, as it is the tooltip's last line. The older rows keep their keys,
  -- labels and saved values. The tag row and its counts are no kind's (the owner's ruling): only their
  -- own switch hides them. Display only: no switch here changes a Keep verdict, ItemTreeAPI's answers
  -- (Core/API.lua CHANGE_SETTINGS names none) or the item page.
  {
    key = "tooltipEnabled",
    label = "Show tooltip lines",
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Shows ItemTree's lines under an item's own tooltip lines. Off draws none of them."],
  },
  -- Brief TD1 (the owner's naming note of 2026-10-23: "Keep" is both the whole row and one of its tags,
  -- so the row is named for the whole of it): the tag row in the tooltip alone (UI/Tooltip.lua
  -- Tooltip.TAGS_KEY). Greyed while Keep marks is off, which draws no tag row anywhere.
  {
    key = "tooltipShowTags",
    label = L["Show Keep and sell tags"],
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Shows the [Keep], [Use], [Vendor] and [Worthless] tags and their counts."]
      .. " "
      .. L["Off leaves the lines under them, and the marks on your bag items."],
    dependsOn = { "tooltipEnabled" },
    requires = { keepMarks = true },
  },
  {
    key = "tooltipShowBadges",
    label = "Show badge lines",
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Says if Forever added or changed the item, such as New in Forever or Changed in Forever."],
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipShowUses",
    label = "Show uses line",
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Lists what the item is used for, such as Used in 6 recipes, 1 quest."]
      .. " "
      .. L["Where the lines under the Keep and sell tags list the uses, they stand in for it."],
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipShowQuests",
    label = L["Show quest lines"],
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Shows the quests that need the item, such as Riverpaw Gnoll Bounty (3 / 8 needed)."]
      .. " "
      .. L["And the quests you finished, such as Quest complete."]
      .. " "
      .. L["Turn it off if another quest addon already shows them."]
      .. " "
      .. L["The Keep and sell tags stay as they are."],
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipShowProfessions",
    label = L["Show profession lines"],
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Shows the recipes and professions that use the item, such as 12 x Tailoring."]
      .. " "
      .. L["And what your profession still needs, such as Level Cooking (12 / 40 needed)."]
      .. " "
      .. L["The Keep and sell tags stay as they are."],
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipShowGear",
    label = L["Show gear lines"],
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Shows the gear lines, such as Upgrade for your Chest or Equipped."]
      .. " "
      .. L["The Keep and sell tags stay as they are."],
    dependsOn = { "tooltipEnabled" },
  },
  -- Brief BQ7 (owner QA item 19, 2026-10-10): the uses for professions the player does not have, and
  -- chains through them, fold into one "and N other uses" line on item tooltips (UI/Tooltip.lua
  -- Tooltip.FoldUses). On by default. The row under it picks the key that shows them all. Brief TD1: a
  -- kind of line turned off above is never counted in the fold, nor shown while the key is held.
  {
    key = "tooltipHideOtherUses",
    label = "Hide irrelevant uses",
    section = Options.TOOLTIP_SECTION,
    tooltip = "Folds the uses for professions you do not have into one line, so your own uses stand out.",
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipUsesModifier",
    label = "Show every use while holding",
    section = Options.TOOLTIP_SECTION,
    kind = "dropdown",
    optionSource = "usesModifier",
    tooltip = "Hold it on a tooltip to see every use.",
    dependsOn = { "tooltipHideOtherUses" },
  },
  {
    key = "tooltipShowIcons",
    label = "Show ItemTree icons in tooltips",
    section = Options.TOOLTIP_SECTION,
    tooltip = L["Draws the quest mark, the profession icons and the Forever badges beside ItemTree's lines."],
    dependsOn = { "tooltipEnabled" },
  },
  {
    key = "tooltipShowHint",
    label = "Show the key binding hint",
    section = Options.TOOLTIP_SECTION,
    tooltip = L["The last line, which says how to open the full tree, such as Ctrl + right click for the full tree."],
    dependsOn = { "tooltipEnabled" },
  },
  -- Fixed position tooltip: the design's Summary element group. One movable panel, then what it
  -- draws, then the unlock that lets it be dragged. The reset button goes in after the unlock;
  -- see the Summary HUD section below the divider. The first tooltip is the description of the
  -- whole thing, what it is and how to move it, so it is long on purpose.
  {
    key = "hudEnabled",
    label = "Show the fixed position tooltip",
    section = "Fixed position tooltip",
    tooltip = "Shows the item under your cursor in a tooltip that stays in one place on the screen. "
      .. "Click it to open the tree, and tick Unlock to move to drag it somewhere else.",
  },
  -- Brief U4: what follows the first row only means anything while it is on, so it sits
  -- indented under it and greyed out while it is off. The reset row is linked the same way by
  -- linkHudReset, below the divider.
  {
    key = "hudShowBadges",
    label = "Show badges",
    section = "Fixed position tooltip",
    dependsOn = { "hudEnabled" },
  },
  {
    key = "hudShowSummary",
    label = "Show the summary line",
    section = "Fixed position tooltip",
    dependsOn = { "hudEnabled" },
  },
  {
    key = "hudUnlocked",
    label = "Unlock to move",
    section = "Fixed position tooltip",
    tooltip = "Drag the tooltip where you want it. It locks again when you log out.",
    dependsOn = { "hudEnabled" },
  },
  -- New and Changed badges (brief ST2, QA item 307; it was Badges, brief S7, and Bags): every New
  -- and Changed mark ItemTree draws, wherever it draws it. Keys, defaults and saved values are
  -- unchanged throughout. Brief ST3 (QA items 316 and 317, the owner: "Its a little bit confusing the
  -- difference between the top Show badges and bottom show bag badges"): headed Forever badges, and
  -- read as two axes. The KINDS first, each global (the window, the pages, the bags): Show New
  -- badges, Show Changed badges with its two children indented under it, and the quest marks with
  -- their wash. Then the PLACES under a small "Where" sub heading (Options.SUBHEADINGS): In your bags
  -- and In your bank, which turn every ItemTree badge in that place on or off. Then Badge size, the
  -- corner and the profession icon rows (UI/ProfessionsStub.lua) as before. A bag badge needs its kind
  -- and its place both on (UI/Overlay.lua Overlay.BadgesFor). UI/ProfessionsStub.lua BAG_ORDER keeps
  -- the same order for the client, where it registers its two rows.
  { key = "badgesNew", label = "Show New badges", section = Options.BADGES_SECTION },
  { key = "badgesChanged", label = "Show Changed badges", section = Options.BADGES_SECTION },
  -- Brief C1: whether a minor change (an item's class, subclass or stack size, nearly always a
  -- renamed category) counts as Changed and is listed, beside the badge rows it changes. No hover
  -- example: UI/OptionsPreview.lua gives this row none. Brief ST3 (QA item 317): indented under Show
  -- Changed badges but never greyed with it (indent, Options.dependencies route "indent"): it also
  -- decides the change rows the item page and the tooltip list, which do not follow the badges.
  {
    key = "includeMinorChanges",
    label = "Include minor changes",
    section = Options.BADGES_SECTION,
    tooltip = "Also marks an item Changed when only its category or stack size changed. Off lists only "
      .. "changes to things like its name, stats, effects, armour, quality or binding.",
    indent = true,
  },
  -- Brief W27: the Changed badge on bag and bank slots, off by default. The window's own Changed
  -- badges are the Show Changed badges row above and are untouched by this one. Brief ST3 (QA item
  -- 317): moved up under Show Changed badges, indented, and greyed out while Show Changed badges is
  -- off (requires) or while neither place below shows badges (dependsOn), which is when it can draw
  -- nothing. Brief ST3 (QA item 318): its example is a bag slot wearing the Changed badge.
  {
    key = "bagBadgesChanged",
    label = L["Show Changed badges on bags"],
    section = Options.BADGES_SECTION,
    tooltip = L["Also marks bag and bank items that changed from Classic. Off, bag slots mark only new items."],
    dependsOn = { "bagOverlay", "bankOverlay" },
    requires = { badgesChanged = true },
  },
  -- The quest marks (brief Q2, UI/QuestFlags.lua): what ItemTree draws on the client's quest panels
  -- and quest log. They had a Quests section of their own (brief Q5) until brief S7. No hover
  -- example (UI/OptionsPreview.lua): the quest panels are the client's, and there is nothing of ours
  -- to draw beside the row. Brief SM1 (QA item 329): it reads "Show New on quests and rewards", since
  -- the title's Changed badge is rare (it needs a New reward); the rule and the tooltip are unchanged.
  {
    key = "questBadges",
    label = "Show New on quests and rewards",
    section = Options.BADGES_SECTION,
    tooltip = "Marks quests Forever added, and rewards a quest did not give in Classic Era, "
      .. "when you are offered them and in the quest log.",
  },
  -- The blue wash behind a New quest's text (brief Q4, blue since brief Q6). It is drawn only with the marks, so it
  -- sits indented under them and greyed out while they are off (dependsOn, brief U2c). No hover
  -- example either: the preview has no quest surface to draw it on.
  {
    key = "questWash",
    label = "Show the blue wash on new quests",
    section = Options.BADGES_SECTION,
    tooltip = "A blue wash behind the top of a new quest's text on the quest panels, so a New in "
      .. "Forever quest reads as one at a glance. Off leaves the badge alone.",
    dependsOn = { "questBadges" },
  },
  -- Bags (brief S7, from Integration): the badges on bag and bank slots, their size and corner. The
  -- Keep marks rows have a section of their own since brief K12. Brief ST2: under New and Changed
  -- badges now. Brief ST3 (QA item 317): the two places under the "Where" sub heading, labelled In
  -- your bags and In your bank (they read "Show badges on bags" and "on bank"), each saying it covers
  -- every ItemTree badge in that place. Keep and Use marks do not follow them (UI/Overlay.lua apply).
  {
    key = "bagOverlay",
    label = L["In your bags"],
    section = Options.BADGES_SECTION,
    tooltip = L["Shows every ItemTree badge on your bag slots: New, Changed and the profession icon."]
      .. " "
      .. L["Off hides them all there. Keep and Use marks have their own switches."],
  },
  {
    key = "bankOverlay",
    label = L["In your bank"],
    section = Options.BADGES_SECTION,
    tooltip = L["Shows every ItemTree badge on your bank slots: New, Changed and the profession icon."]
      .. " "
      .. L["Off hides them all there. Keep and Use marks have their own switches."],
  },
  -- Brief U1: how big the bag and bank badges are and which corner of the slot they sit in,
  -- straight under the two tick boxes that turn them on. Hovering either shows the example slot
  -- beside the row (brief U2, UI/OptionsPreview.lua). Both are greyed out while neither tick box
  -- above them is on, because then there are no badges to size or place (dependsOn, brief U2c).
  -- The words are L literals so the locale sweep finds them where they are used; Definitions
  -- looks each one up again, which answers the same words.
  -- Brief ST2 (QA item 307): labelled Badge size under its family's heading, and it sizes the New
  -- and Changed badges (and the profession icon beside them) alone: the Use mark follows Mark size.
  {
    key = "bagBadgeScale",
    label = L["Badge size"],
    section = Options.BADGES_SECTION,
    kind = "slider",
    min = Options.BADGE_SCALE_MIN,
    max = Options.BADGE_SCALE_MAX,
    step = Options.BADGE_SCALE_STEP,
    tooltip = L["How big the New and Changed badges and the profession icon are on bag and bank slots."],
    dependsOn = { "bagOverlay", "bankOverlay" },
  },
  {
    key = "bagBadgeCorner",
    label = L["Bag badge corner"],
    section = Options.BADGES_SECTION,
    kind = "dropdown",
    optionSource = "badgeCorner",
    tooltip = L["Which corner of a bag or bank slot the badge sits in. The stack count uses the bottom right."],
    dependsOn = { "bagOverlay", "bankOverlay" },
  },
  -- Keep marks (brief K12, from Bags). Brief T4: the gold glow on bag items worth keeping
  -- (Core/Keep.lua). It needs no badge setting of its own, so it depends on nothing.
  {
    key = "keepMarks",
    label = L["Keep marks"],
    section = Options.KEEP_SECTION,
    tooltip = KEEP_TOOLTIP,
  },
  -- Brief ST1 (QA item 279, a player's CurseForge comment; the owner asked for this row himself):
  -- the blue play mark on bag items to use or open now (UI/Overlay.lua USE_MARK), on by default.
  -- Greyed out with Keep marks, which draws the mark at all. Brief ST3 (QA item 319, the owner's
  -- ruling A): off, every such item wears its Keep mark instead (UI/Overlay.lua KeepStateFor), and
  -- the hover says so in his words.
  {
    key = "keepUseMark",
    label = L["Use mark"],
    section = Options.KEEP_SECTION,
    tooltip = L["The blue play mark on bag items you can use or open now."]
      .. " "
      .. L["Off: these items wear the Keep mark instead."],
    dependsOn = { "keepMarks" },
  },
  -- Brief ST2 (QA item 307, the owner's ruling A: "one Mark size slider, today's size the
  -- default"): how big the Keep and Use marks in a slot's corner are (UI/Overlay.lua
  -- Overlay.MarkSide), 1.00x today's. Under the two switches it sizes, greyed out with Keep marks,
  -- which draws both. Its example is the Keep example with a Use mark slot (UI/OptionsPreview.lua).
  {
    key = "keepMarkScale",
    label = L["Mark size"],
    section = Options.KEEP_SECTION,
    kind = "slider",
    min = Options.MARK_SCALE_MIN,
    max = Options.MARK_SCALE_MAX,
    step = Options.MARK_SCALE_STEP,
    tooltip = L["How big the Keep and Use marks in a corner of bag and bank slots are."]
      .. " "
      .. L["Styles that frame the whole slot stay the slot's size."],
    dependsOn = { "keepMarks" },
  },
  -- Brief K9: the auction value an item is worth keeping at, from an installed auction addon's
  -- own scan, or (brief K19) its vendor sell price (Core/Prices.lua). Under Keep marks and greyed
  -- out with it. Brief K20a: labelled "Valuable at", the key unchanged.
  {
    key = "keepValueCopper",
    label = L["Valuable at"],
    section = Options.KEEP_SECTION,
    kind = "slider",
    min = Options.VALUE_STOP_MIN,
    max = Options.ValueStopCount,
    step = Options.VALUE_STOP_STEP,
    labelFormat = Options.ValueLabel,
    -- Brief K10: the slider holds a stop's index and the setting the stop's copper.
    toControl = Options.ValueStopIndex,
    fromControl = Options.ValueStopCopper,
    tooltip = VALUE_TOOLTIP,
    dependsOn = { "keepMarks" },
  },
  -- Brief K20c (design K20 section 2): the Bar, how far an auction price must beat the vendor
  -- price before an item reads Sell (AH). Under Formula, the formula row goes straight under it
  -- (Options.FORMULA_ROWS); it is built at login with the rest of the page.
  {
    key = "keepSellBar",
    label = L["List on the auction house when it beats the vendor by"],
    section = Options.KEEP_SECTION,
    kind = "dropdown",
    optionSource = "keepSellBar",
    tooltip = SELL_BAR_TOOLTIP,
    dependsOn = { "keepMarks" },
  },
  -- Brief K12: which look marks a worth keeping item, and the colours it is drawn in. Both redraw
  -- the bags at once through Options.OnChanged, and both are greyed out with Keep marks. The
  -- demo (/itemtree demo) still overrides both in memory while it runs.
  {
    key = "keepStyle",
    label = L["Style"],
    section = Options.KEEP_SECTION,
    kind = "dropdown",
    optionSource = "keepStyle",
    toControl = Options.KeepStyleToControl,
    fromControl = Options.KeepStyleFromControl,
    tooltip = KEEP_STYLE_TOOLTIP,
    dependsOn = { "keepMarks" },
  },
  -- Brief K15: the Single colour set's colour, greyed out unless Colours is Single colour (requires)
  -- and Keep marks is on. The Custom colour row (Options.SWATCH_ROWS) goes straight under it.
  -- Brief K16: then the valuable colour, the same pair of rows, also greyed out while the value
  -- setting is Off. Both declared by Options.ColourPairRows.
  COLOUR_DROPDOWN,
  VALUE_COLOUR_DROPDOWN,
  -- Keys and clicks (brief S7, from Integration): the two key binding rows go in first, as the
  -- section's header is passed (see Options.Install below the divider), then the clicks that do
  -- the same jobs, so every way into the window sits together.
  {
    key = "clickOpen",
    label = "Open with a click",
    section = "Keys and clicks",
    kind = "dropdown",
    optionSource = "click",
    tooltip = "Which click on an item opens its tree. Ctrl + left click also opens the dressing room, "
      .. "because that is the game's own dress up shortcut.",
  },
  -- Brief T7: the same click on a creature, beside the item click it mirrors.
  {
    key = "npcClick",
    label = "Ctrl + right click on NPCs opens their page",
    section = "Keys and clicks",
    tooltip = "Ctrl + right click a creature's target frame or nameplate to open its page in ItemTree. "
      .. "The creature's own menu still opens as well.",
  },
  -- Minimap (brief S7, from Integration): each button, with its Reset position row straight under it
  -- (see Options.Install below the divider).
  { key = "minimapButton", label = "Show minimap button", section = "Minimap" },
  -- Brief B1: the opt in second minimap button (UI/Minimap.lua), which opens the Boss loot tab.
  {
    key = "bossLootMinimapButton",
    label = "Boss loot minimap button",
    section = "Minimap",
    tooltip = "A second minimap button that opens the Boss loot tab. Off by default.",
  },
  -- Performance (brief S5): the settings that trade memory or load time for speed.
  -- Brief U3: the item data ships in the load on demand addon ItemTree_Data. No hover example
  -- (UI/OptionsPreview.lua): there is nothing on screen to show for it. Moved here from
  -- Integration with its key and label unchanged, so a saved setting carries over. On by default
  -- since brief E89, so the first open of the window has no pause.
  {
    key = "loadDataAtLogin",
    label = "Load item data at login",
    section = "Performance",
    tooltip = "Loads ItemTree's item data when you log in, so the window opens without a pause. "
      .. "Off loads it the first time the window opens and saves about 20 MB until then.",
  },
  -- E53: the creature's own portrait on a source row, drawn over the kind icon once the row has
  -- settled. The sentence under it is the one a player on an older computer needs: this is the
  -- row that turns the drawing off. Brief ST3 (QA item 315, the owner: "Creature and boss
  -- portraits should be in performance section"): moved here from Display, key and words unchanged.
  {
    key = "creaturePortraits",
    label = "Creature portraits",
    section = "Performance",
    tooltip = "Draws each creature's portrait on source rows. "
      .. "Turn it off on a slow computer and every row keeps a plain icon.",
  },
  -- Brief BL12: the same portraits on the Boss loot tab's boss rows, straight after the row
  -- above because it is the same drawing in another list. Brief ST3: moved with it.
  {
    key = "bossPortraits",
    label = "Boss portraits",
    section = "Performance",
    tooltip = "Draws each boss's portrait on the Boss loot rows. Off leaves the rows to their names.",
  },
  -- alwaysLoad3dMap (brief BL6), "always load 3D maps on view", joins this section here.
  -- Data confidence: the design's Markers group.
  { key = "showPredicted", label = "Show predicted data", section = "Data confidence" },
  -- Brief GS3: the guessed sources (Core/GuessSources.lua), a tier below the predictions and
  -- beside their row. On by default; off draws the Sources view exactly as it was before guesses
  -- existed. With "Show predicted data" off no guess is drawn either way. No hover example.
  {
    key = "showGuessSources",
    label = "Show guessed sources",
    section = "Data confidence",
    tooltip = "Lists likely sources, marked Guess, for items with no known source. Off shows only known "
      .. "and predicted sources.",
  },
  -- Brief D3: the items the Discovery Miner found on the beta realm ship as ordinary items. Off
  -- puts each one back behind its stub (Core/Data.lua HarvestMasked). It is a question about how
  -- far the data can be trusted to say what an item is, so it sits with the predicted marker.
  {
    key = "showHarvested",
    label = "Show items found on the beta",
    section = "Data confidence",
    tooltip = "Shows names and stats for items first found on the beta realm, before your own realm "
      .. "finds them. Off hides them until it does.",
  },
  -- Brief D5: what Classic Era said about an item the build withholds, shown before the player's
  -- realm finds it (Core/Data.lua EraUnlocked). Beside the harvest row, because it is the same
  -- question about how far the data can be trusted to say what an item is. UI/OptionsPreview.lua
  -- gives it no hover example.
  {
    key = "showEraDetails",
    label = "Show Classic Era details for items not yet found",
    section = "Data confidence",
    tooltip = "Shows the Classic Era name, stats and sources of items your realm has not found yet, "
      .. "marked Classic Era because Forever may have changed them. Off hides them until your "
      .. "realm finds the item.",
  },
  {
    key = "collectorEnabled",
    label = "Record what you see",
    section = "Data confidence",
    tooltip = "Remembers what you loot, what vendors sell and what quests offer, and the bosses you "
      .. "meet. Item pages, the Boss loot tab and the Discoveries tab then show what you have "
      .. "actually seen instead of Classic Era predictions. Off keeps what is already recorded.",
  },
  -- Source databases, after the Data confidence section. It used to sit under Data
  -- confidence beside the collector, which is the other answer to the same question, but the
  -- status rows it governs are a section of
  -- their own and a tick box reads oddly away from the rows it switches off. The key, the
  -- default and the behaviour are untouched: only the section it is filed under moved.
  {
    key = "useProviders",
    label = "Use sources from other installed addons",
    section = Options.PROVIDER_SECTION,
    tooltip = "Adds the drops, vendors and quest rewards that your other installed addons know about to "
      .. "item pages. Off shows ItemTree's own data only.",
  },
  -- Feature tabs (brief S6, named in E96): which tabs the window draws. The section the Boss loot
  -- tab's own setting (registered by UI/BossLoot.lua) and a developer tab's join, so
  -- the tab toggles sit together under one header (Options.GroupBySection). The
  -- Discoveries tab is opt in (brief E96): on adds it at once (UI/Frame.lua Frame.SyncTabs) and
  -- the Discovery records carry on either way.
  {
    key = "showDiscoveries",
    label = "Show the Discoveries tab",
    section = Options.TABS_SECTION,
    tooltip = "Adds a Discoveries tab listing, newest first, the items you have seen your realm find "
      .. "and the items new data has named. Finds are kept either way, so those items keep their "
      .. "names in search and tooltips, and show here when you turn it on. The name of the "
      .. "character who saw each find is kept only while the tab is on. Once the list is full, "
      .. "the oldest finds are let go.",
  },
}

local function defaults()
  return (ItemTree.DB_DEFAULTS and ItemTree.DB_DEFAULTS.settings) or {}
end

-- Settings a module brings with it, in the order they were registered, drawn after every entry
-- in ORDER. Empty in a released build: the only module that registers one is developer only and
-- the package never carries it, so this file names none of them.
Options.EXTRA = {}

--- Adds a setting a module brings with it: an ORDER shaped entry { key, label, section, kind,
--- tooltip, default, ... }, drawn after everything in ORDER under its own section. Its key need
--- not be in DB_DEFAULTS: default is what it reads as until it is set, which is how a module's
--- setting stays out of the saved variables of a build that does not carry the module. Only
--- before the panel is installed, because Install registers every setting with the client once.
--- Answers whether it was added, and true for a key already registered.
function Options.RegisterSetting(entry)
  if type(entry) ~= "table" or type(entry.key) ~= "string" or type(entry.label) ~= "string" then
    return false
  end
  for _, existing in ipairs(ORDER) do
    if existing.key == entry.key then
      return true
    end
  end
  for _, existing in ipairs(Options.EXTRA) do
    if existing.key == entry.key then
      return true
    end
  end
  if Options.category then
    return false
  end
  Options.EXTRA[#Options.EXTRA + 1] = entry
  return true
end

-- The options a dropdown row draws, either written out in the entry or fetched from the
-- module that owns them. Always a list, never nil.
local function choicesFor(entry)
  local source = entry.optionSource and CHOICE_SOURCES[entry.optionSource] or nil
  if type(source) == "function" then
    local ok, list = pcall(source)
    if ok and type(list) == "table" then
      return list
    end
    return {}
  end
  return entry.choices
end

-- The default to register when DB_DEFAULTS.settings does not carry the key. Written as an if
-- rather than with and/or, which cannot carry a false through.
local function fallbackDefault(entry, choices)
  if entry.kind == "slider" then
    return entry.min
  end
  if entry.kind == "choice" then
    return choices and choices[1] or nil
  end
  if entry.kind == "dropdown" then
    local first = choices and choices[1] or nil
    if type(first) == "table" then
      return first.value
    end
    return first
  end
  return true
end

--- Puts every row of a section together, sections in the order they first appear, and orders the
--- rows inside a section by Options.SECTION_KEY_ORDER where it names them, keeping the order
--- they came in otherwise. The panel draws a header wherever the section changes from one row to
--- the next, so a registered row (Options.EXTRA, drawn after all of ORDER) whose section was
--- already drawn used to get a second header of the same name: the Boss loot row under a second
--- Window, after a developer tab's Beta features (brief E96). Answers a new list. Pure.
function Options.GroupBySection(rows, keyOrder)
  rows = type(rows) == "table" and rows or {}
  keyOrder = type(keyOrder) == "table" and keyOrder or {}
  local sections, bySection = {}, {}
  for index, row in ipairs(rows) do
    local section = row.section
    local name = section == nil and "" or section
    if not bySection[name] then
      bySection[name] = {}
      sections[#sections + 1] = name
    end
    local list = bySection[name]
    list[#list + 1] = { row = row, index = index }
  end
  local out = {}
  for _, name in ipairs(sections) do
    local list = bySection[name]
    local rank = {}
    for position, key in ipairs(type(keyOrder[name]) == "table" and keyOrder[name] or {}) do
      rank[key] = position
    end
    table.sort(list, function(a, b)
      local ra, rb = rank[a.row.key] or math.huge, rank[b.row.key] or math.huge
      if ra ~= rb then
        return ra < rb
      end
      return a.index < b.index
    end)
    for _, item in ipairs(list) do
      out[#out + 1] = item.row
    end
  end
  return out
end

-- A slider's top end, which a row whose range follows another file's table gives as a function
-- (brief K10, the Keep value's stops).
local function maxOf(entry)
  if type(entry.max) == "function" then
    return entry.max()
  end
  return entry.max
end

-- Ordered { key, label, kind, default, tooltip, choices, checkedValue, uncheckedValue }, and
-- min, max and step on a slider. Any boolean added to DB_DEFAULTS.settings later is appended
-- automatically, so the panel never silently drops a setting.
-- Brief TC1: booleans in DB_DEFAULTS.settings that live on the window's footer alone and never
-- get a Settings panel row, which a boolean not placed in ORDER otherwise would (see the end of
-- Options.Definitions). The owner finds the panel long enough. Brief SH3: the share window's
-- Credit my character box (shareCredit) lives in that window alone, the same way.
Options.FOOTER_ONLY = { totalCounts = true, shareCredit = true }

-- Brief K27 (owner 2026-10-08): the per character spec setting, one tick box per spec of the
-- player's OWN class (Core/Gear.lua Gear.SPECS, each labelled by Gear.SpecLabel), all ticked by
-- default, straight after the Bar row in Keep marks (and its formula rows) and greyed out with Keep
-- marks. They are not in ItemTree.db.settings: each reads and writes this character's
-- ItemTreeCharDB through Core/Keep.lua (Keep.SpecEnabled, Keep.SetSpecEnabled), registered in the
-- client's proxy form. The class is read when the definitions are (the page is built at
-- PLAYER_LOGIN, Options.Install, when UnitClass answers), so no class known means no spec rows.
-- Like every row of the section they take the Keep marks example (UI/OptionsPreview.lua, brief K16).
Options.SPECS_AFTER = "keepSellBar"
Options.SPEC_KEY_PREFIX = "gearSpec_"

--- The spec key a spec row's setting key stands for ("gearSpec_holy" is "holy"), or nil. Pure.
function Options.SpecOfKey(key)
  if type(key) ~= "string" then
    return nil
  end
  local prefix = Options.SPEC_KEY_PREFIX
  if key:sub(1, #prefix) ~= prefix or #key == #prefix then
    return nil
  end
  return key:sub(#prefix + 1)
end

--- The player's class for the spec rows, through Core/Keep.lua's held read (UnitClass), or nil.
function Options.SpecClass()
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.PlayerClass) ~= "function" then
    return nil
  end
  local ok, classId = pcall(keep.PlayerClass)
  return ok and tonumber(classId) or nil
end

--- The spec rows' tooltip: what a tick does, that every box unticked turns gear suggestions off, and
--- that it is this character's alone. Brief ST3 (QA item 320, the owner's ruling A: "These suggest
--- tooltips need to be plainer and clearer"; "What if they want no spec suggested?"): his words
--- exactly, one sentence a literal so the locale sweep finds each. Unticking every spec now turns gear
--- suggestions off (Core/Keep.lua Keep.EnabledSpecs and Keep.GearFacts); it used to count as every
--- spec ticked. Pure.
function Options.SpecTooltip()
  return L["Tick the specs you play."]
    .. " "
    .. L["ItemTree suggests gear upgrades only for ticked specs."]
    .. " "
    .. L["Untick them all to turn gear suggestions off."]
    .. " "
    .. L["This character only."]
end

--- Brief BQ30: the player's level for the spec rows (Gear.Player: the pretend level while set), or
--- nil where the client will not say.
function Options.SpecLevel()
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.Player) ~= "function" then
    return nil
  end
  local ok, _, level = pcall(gear.Player)
  return ok and tonumber(level) or nil
end

--- Brief BQ30 (owner's spot fix, QA item 91): a spec row's label, "Suggest gear for Survival", and
--- for a spec closed at the player's level (Gear.SpecOpen) the muted "from level 30" after it: the
--- row stays, the spec counts only from that level. Pure over Core/Gear.lua and UI/Theme.lua.
function Options.SpecLabel(classId, spec, label, level)
  local text = string.format(L["Suggest gear for %s"], label)
  local gear = ItemTree.Gear
  if type(gear) ~= "table" or type(gear.SpecOpen) ~= "function" or gear.SpecOpen(classId, spec, level) then
    return text
  end
  local note = string.format(L["from level %d"], gear.SpecFromLevel(classId, spec))
  local theme = ItemTree.Theme
  if type(theme) == "table" and type(theme.Colorise) == "function" then
    local ok, muted = pcall(theme.Colorise, "ITEMTREE_COLOR_TEXT_MUTED", note)
    if ok then
      note = muted
    end
  end
  return text .. " " .. note
end

--- The spec rows for a class, ORDER shaped entries in the class's order: { key = "gearSpec_holy",
--- spec = "holy", label = "Suggest gear for Holy", section, default = true, tooltip,
--- dependsOn }. Empty for no class or a class with no specs; never another class's specs. Brief
--- BQ30: level, the player's (nil: not known), adds the muted "from level 30" to a closed spec's
--- label (Options.SpecLabel). Pure over Core/Gear.lua.
function Options.SpecDefinitions(classId, level)
  local out = {}
  local gear = ItemTree.Gear
  local specs = type(gear) == "table" and type(gear.SPECS) == "table" and gear.SPECS[tonumber(classId) or -1] or nil
  if type(specs) ~= "table" or type(gear.SpecLabel) ~= "function" then
    return out
  end
  for _, spec in ipairs(specs) do
    local label = gear.SpecLabel(classId, spec)
    if type(label) == "string" then
      out[#out + 1] = {
        key = Options.SPEC_KEY_PREFIX .. spec,
        spec = spec,
        label = Options.SpecLabel(classId, spec, label, level),
        section = Options.KEEP_SECTION,
        kind = "boolean",
        default = true,
        tooltip = Options.SpecTooltip(),
        dependsOn = { "keepMarks" },
      }
    end
  end
  return out
end

function Options.Definitions()
  local source = defaults()
  local out, seen = {}, {}
  local entries = {}
  -- Brief K27: the player's own class's spec rows, straight after the Bar row.
  local specRows = Options.SpecDefinitions(Options.SpecClass(), Options.SpecLevel())
  for _, entry in ipairs(ORDER) do
    entries[#entries + 1] = entry
    if entry.key == Options.SPECS_AFTER then
      for _, spec in ipairs(specRows) do
        entries[#entries + 1] = spec
      end
      specRows = EMPTY
    end
  end
  for _, spec in ipairs(specRows) do
    entries[#entries + 1] = spec
  end
  for _, entry in ipairs(Options.EXTRA) do
    entries[#entries + 1] = entry
  end
  for _, entry in ipairs(entries) do
    local choices = choicesFor(entry)
    local default = source[entry.key]
    -- A registered setting states its own default, because its key is not in DB_DEFAULTS.
    if default == nil then
      default = entry.default
    end
    if default == nil then
      default = fallbackDefault(entry, choices)
    end
    seen[entry.key] = true
    out[#out + 1] = {
      key = entry.key,
      label = L[entry.label],
      section = entry.section,
      kind = entry.kind or "boolean",
      default = default,
      tooltip = tooltipOf(entry),
      choices = choices,
      checkedValue = entry.checkedValue,
      uncheckedValue = entry.uncheckedValue,
      min = entry.min,
      max = maxOf(entry),
      step = entry.step,
      labelFormat = entry.labelFormat,
      toControl = entry.toControl,
      fromControl = entry.fromControl,
      dependsOn = entry.dependsOn,
      requires = entry.requires,
      -- Brief ST3 (QA item 317): indented under the row above without being greyed with it.
      indent = entry.indent == true or nil,
      -- Brief K27: a spec row's spec key; its value is this character's, not a db.settings key.
      spec = entry.spec,
    }
  end
  out = Options.GroupBySection(out, Options.SECTION_KEY_ORDER)
  local extras = {}
  for key, value in pairs(source) do
    if not seen[key] and type(value) == "boolean" and not Options.FOOTER_ONLY[key] then
      extras[#extras + 1] = key
    end
  end
  table.sort(extras)
  -- A boolean added to DB_DEFAULTS.settings and not yet placed in ORDER lands at the end of
  -- the last section that has a setting, rather than under no header at all.
  local lastSection = out[#out] and out[#out].section or Options.SECTIONS[1]
  for _, key in ipairs(extras) do
    out[#out + 1] = { key = key, label = L[key], section = lastSection, kind = "boolean", default = source[key] }
  end
  return out
end

-- Definitions drawn as a checkbox: every boolean, plus density, which stores a string but
-- reads as one tick box ("Compact rows").
function Options.CheckboxDefinitions()
  local out = {}
  for _, def in ipairs(Options.Definitions()) do
    if def.kind == "boolean" or def.checkedValue then
      out[#out + 1] = def
    end
  end
  return out
end

-- Definitions the panel draws any control for: the tick boxes, plus the slider and dropdown
-- rows. "Compare against" is a choice with no control of its own yet, so it is left out here
-- exactly as it is left out of the tick boxes.
function Options.ControlDefinitions()
  local out = {}
  for _, def in ipairs(Options.Definitions()) do
    if def.kind == "boolean" or def.checkedValue or def.kind == "slider" or def.kind == "dropdown" then
      out[#out + 1] = def
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- The Source databases section, the part of it that decides nothing about frames.
--
-- ItemTree ships no world sources at all, and a player who already has a source database
-- installed as another addon can have it read. This section is the tick box that turns that
-- on and off, and one row per database that is installed saying what state it is in.
--
-- Brief E1, the owner's ruling for the first release: no other addon is promoted anywhere. So
-- there is no sentence under the header, no row for a database that is not installed, and no
-- button, link or note on any row. Everything in this block is pure: the caller does the asking.
--------------------------------------------------------------------------------

-- A database's state in plain words. The first four are Providers/Registry.lua's own states.
-- "off" is not a state an adapter ever reports: it is what every row reads as while the player
-- has reading switched off, which the tick box directly above the rows is what turns back on.
Options.PROVIDER_STATES = {
  absent = "Not installed",
  waiting = "Installed, waiting to load",
  ready = "Ready",
  disabled = "Stopped after an error",
  off = "Turned off",
}

-- A row whose state is a word this file has never heard of reads as nothing installed.
Options.PROVIDER_STATE_DEFAULT = "absent"

--- One database's state in plain words, through the locale. Anything this file does not know
--- reads as not installed. Pure.
function Options.StateText(state)
  local words
  if type(state) == "string" then
    words = Options.PROVIDER_STATES[state]
  end
  if not words then
    words = Options.PROVIDER_STATES[Options.PROVIDER_STATE_DEFAULT]
  end
  return L[words]
end

--- Whether a status row is a database that is installed: any state the registry reports other
--- than "absent", and never a word this file has not heard of. Pure.
function Options.IsInstalled(state)
  if type(state) ~= "string" or state == "absent" or state == "off" then
    return false
  end
  return Options.PROVIDER_STATES[state] ~= nil
end

--- One row per source database that is installed, in the order the registry files them. A
--- database that is not installed has no row at all, so the section never names an addon the
--- player does not have.
---
--- statuses is what ItemTree.Providers.Status() answers, a list of { key, label, state, detail }
--- whose label is already through the locale; enabled is false only when the useProviders
--- setting is off, and then every row reads "Turned off". Neither is asked for here, because
--- this has to decide with no registry in front of it.
---
--- Answers a list of { key, label, state, stateText }. Pure.
function Options.ProviderRows(statuses, enabled)
  local out = {}
  for _, row in ipairs(type(statuses) == "table" and statuses or EMPTY) do
    if type(row) == "table" and type(row.key) == "string" and Options.IsInstalled(row.state) then
      local state = row.state
      -- Nothing is being read at all, whatever each adapter makes of itself, so every row says
      -- the one thing that is true of all of them.
      if enabled == false then
        state = "off"
      end
      out[#out + 1] = {
        key = row.key,
        label = row.label or row.key,
        state = state,
        stateText = Options.StateText(state),
      }
    end
  end
  return out
end

-- The status row's own pixels. The line is PROVIDER_LINE_H tall and the row is that plus the
-- air above and below it. PROVIDER_STATE_X is measured from the middle of the row, which is
-- about where the client's own controls start.
Options.PROVIDER_ROW_H = 26
Options.PROVIDER_LINE_H = 22
Options.PROVIDER_TOP = 2
Options.PROVIDER_STATE_X = -80
Options.PROVIDER_STATE_W = 130

function Options.Get(key)
  -- Brief K27: a spec row reads this character's spec setting.
  local spec = Options.SpecOfKey(key)
  if spec then
    local keep = ItemTree.Keep
    if type(keep) == "table" and type(keep.SpecEnabled) == "function" then
      return keep.SpecEnabled(spec) and true or false
    end
    return true
  end
  local settings = ItemTree.db and ItemTree.db.settings or {}
  local value = settings[key]
  if value == nil then
    value = defaults()[key]
  end
  return value
end

-- Called after any setting changes so the live surfaces pick it up.
function Options.OnChanged(key, value)
  if ItemTree.Tooltip and type(ItemTree.Tooltip.ResetRendered) == "function" then
    ItemTree.Tooltip.ResetRendered()
  end
  -- Brief FX-AG2 (FR-AG2's M2): the Item chain pane holds the chains it drew under a stamp of the
  -- settings it knows it reads (UI/Chain.lua Chain.CACHE_FACTS). Any setting changed here lets
  -- them all go before the window draws again (Frame.RefreshFromSettings below), so a setting the
  -- stamp does not name, one added later included, still draws the new chain.
  local chain = ItemTree.UI and ItemTree.UI.Chain
  if type(chain) == "table" and type(chain.DropCache) == "function" then
    pcall(chain.DropCache)
  end
  -- Turning the provider layer off or on changes what every source row answers, so what the
  -- adapters have worked out is dropped and so are the direction counts the tabs are labelled
  -- from, which Core/ViewModel.lua's Reset is the documented way to clear.
  -- Showing or hiding the harvested items changes what an item record answers, so what was built
  -- from the item tables is dropped (the name index most of all), with the Diff lookups and the
  -- direction counts beside them.
  if key == "showHarvested" then
    local data = ItemTree.Data
    if type(data) == "table" and type(data.ResetHarvest) == "function" then
      pcall(data.ResetHarvest, data)
    end
    local diff = ItemTree.Diff
    if type(diff) == "table" and type(diff.Reset) == "function" then
      pcall(diff.Reset)
    end
    local viewModel = ItemTree.ViewModel
    if viewModel and type(viewModel.Reset) == "function" then
      pcall(viewModel.Reset)
    end
  end
  -- Showing or hiding the Classic Era details changes what a withheld item's record and its
  -- sources answer, so the name index and the direction counts built while it said otherwise go.
  if key == "showEraDetails" then
    local data = ItemTree.Data
    if type(data) == "table" and type(data.ResetEra) == "function" then
      pcall(data.ResetEra, data)
    end
    local viewModel = ItemTree.ViewModel
    if viewModel and type(viewModel.Reset) == "function" then
      pcall(viewModel.Reset)
    end
  end
  -- Brief C1: counting minor changes or not moves items between the Discoveries tab's Changed and
  -- Unchanged boxes, so the cached list and its counts go. The tooltip cache, the overlay and the
  -- open window are refreshed below for every setting.
  if key == "includeMinorChanges" then
    local discoveries = ItemTree.Discoveries
    if type(discoveries) == "table" and type(discoveries.Invalidate) == "function" then
      pcall(discoveries.Invalidate)
    end
  end
  -- Brief R3: the Discoveries tab switched off lets go of the list, the rows and the miner's
  -- watch it built; switched on again, it builds them afresh on its first draw.
  if key == "showDiscoveries" and value ~= true then
    local pane = ItemTree.UI and ItemTree.UI.Discoveries
    if type(pane) == "table" and type(pane.Release) == "function" then
      pcall(pane.Release)
    else
      local discoveries = ItemTree.Discoveries
      if type(discoveries) == "table" and type(discoveries.Invalidate) == "function" then
        pcall(discoveries.Invalidate)
      end
    end
  end
  -- Turning "Load item data at login" on loads it now as well, so the setting does what it says
  -- without waiting for the next login. Off changes nothing until then: loaded data stays loaded.
  -- Brief PF5: named as the caller for Data.loadTiming.
  if key == "loadDataAtLogin" and value == true then
    local data = ItemTree.Data
    if type(data) == "table" and type(data.LoadOnDemand) == "function" then
      pcall(data.LoadOnDemand, data, nil, "setting turned on")
    end
  end
  -- Brief F155: "Hide other faction data" changes which rows every view, count and search holds and
  -- whether the other side's quests count in Keep: the held scores and counts go, and Keep repaints
  -- the bags. The open Trainers & vendors panel is drawn again.
  if key == "hideOtherFaction" then
    local keep = ItemTree.Keep
    if type(keep) == "table" and type(keep.DropScores) == "function" then
      pcall(keep.DropScores)
    end
    local api = ItemTree.API
    if type(api) == "table" and type(api.Reset) == "function" then
      pcall(api.Reset)
    end
    local viewModel = ItemTree.ViewModel
    if viewModel and type(viewModel.Reset) == "function" then
      pcall(viewModel.Reset)
    end
    if type(keep) == "table" and type(keep.Repaint) == "function" then
      pcall(keep.Repaint)
    end
    local trainers = ItemTree.ProfessionsTrainers
    if type(trainers) == "table" and trainers.open and type(trainers.Fill) == "function" then
      pcall(trainers.Fill)
    end
  end
  -- Brief GS3: the guessed rows go or come back, and with them the Sources count they were in.
  if key == "showGuessSources" then
    local viewModel = ItemTree.ViewModel
    if viewModel and type(viewModel.Reset) == "function" then
      pcall(viewModel.Reset)
    end
  end
  if key == "useProviders" then
    local providers = ItemTree.Providers
    if providers and type(providers.Reset) == "function" then
      pcall(providers.Reset)
    end
    local viewModel = ItemTree.ViewModel
    if viewModel and type(viewModel.Reset) == "function" then
      pcall(viewModel.Reset)
    end
    -- The status rows under the tick box are the one surface that can be looked at while it is
    -- being changed, so they are repainted rather than left saying what was true a moment ago.
    if type(Options.RefreshProviders) == "function" then
      pcall(Options.RefreshProviders)
    end
  end
  local overlay = ItemTree.UI and ItemTree.UI.Overlay
  if overlay and type(overlay.Refresh) == "function" then
    overlay.Refresh()
  end
  -- Brief K20c: the formula row shows under Formula only, with its note while the formula is not
  -- understood, and greys with Keep marks.
  if key == "keepSellBar" or key == "keepSellFormula" or key == "keepMarks" then
    pcall(Options.RefreshFormulaRows)
  end
  -- Brief K15: the Custom colour row's swatch shows the stored colour. Brief K16: either pair's.
  -- Brief K17: and dims with its row, so any setting a Custom row watches repaints the swatches.
  if Options.SwatchWatches(key) and type(Options.RefreshSwatches) == "function" then
    pcall(Options.RefreshSwatches)
  end
  -- Brief Q2: the quest marks redraw on the panels that are open when their setting changes,
  -- and the wash with its own switch (brief Q5).
  if key == "questBadges" or key == "questWash" then
    local quests = ItemTree.UI and ItemTree.UI.QuestFlags
    if quests and type(quests.Refresh) == "function" then
      pcall(quests.Refresh)
    end
  end
  local minimap = ItemTree.UI and ItemTree.UI.Minimap
  if minimap and type(minimap.Refresh) == "function" then
    minimap.Refresh()
  end
  -- The main window rebuilds its view model options from the settings it was given. It is a no op
  -- while the window is unbuilt, and pcall'd because a setting change must never take the panel
  -- down with it.
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if frame and type(frame.RefreshFromSettings) == "function" then
    pcall(frame.RefreshFromSettings)
  end
  -- The Summary HUD reads four settings and the window scale, so it is refreshed for any of
  -- them rather than for a named list: Refresh is idempotent and is a no op while the panel
  -- is switched off.
  local editMode = ItemTree.UI and ItemTree.UI.EditMode
  if editMode and type(editMode.Refresh) == "function" then
    pcall(editMode.Refresh)
  end
  -- Brief U2: the example beside the hovered row redraws with the live surfaces, so the popup and
  -- the game change together. The client's slider writes its setting on every step of a drag,
  -- so the example follows the slider as it moves. A no op while no popup is on screen.
  local preview = ItemTree.UI and ItemTree.UI.OptionsPreview
  if preview and type(preview.Refresh) == "function" then
    pcall(preview.Refresh, key)
  end
  if ItemTree.callbacks then
    ItemTree.callbacks:Fire("ITEMTREE_SETTING_CHANGED", key, value)
  end
end

--- Brief E2E-1 (the e2e plan's addition 4): one setting set from code the way the page sets it, its
--- two steps (the stored value, then Options.OnChanged, so every live surface and Jettison hear it as
--- a tick by hand). The page itself is read again only while it is on screen: a page that is not
--- shown reads every row again from its own OnShow (Options.RefreshCanvas), so nothing here reaches
--- into the client's settings panel. The developer only e2e run is the caller; it keeps the value
--- answered here and puts it back the same way. Answers the value stored before, and whether it set.
function Options.Set(key, value)
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) ~= "table" or type(key) ~= "string" then
    return nil, false
  end
  local before = settings[key]
  settings[key] = value
  Options.OnChanged(key, value)
  local canvas = Options.canvas
  local page = type(canvas) == "table" and canvas.frame or nil
  if type(page) == "table" and type(page.IsShown) == "function" then
    local ok, shown = pcall(page.IsShown, page)
    if ok and shown then
      pcall(Options.RefreshCanvas)
    end
  end
  return before, true
end

-- Brief U5: the child marker. A dependent row is indented by the client, and a small mark in
-- that indent says the row belongs to the tick box above it. The client puts a row's label at
-- LEFT + (indent + 37) (SettingsListElementMixin:Init, Blizzard_SettingControls.lua, forever
-- branch) and indents by 15 (indentSize, same file), so the gap runs from 37 to 52.
Options.ROW_LABEL_INSET = 37
Options.ROW_INDENT = 15
Options.CHILD_MARKER_ASSET = "OPTIONS_CHILD_MARKER"
-- Used only where UI/Theme.lua cannot be asked; the tokens are the real values.
Options.CHILD_MARKER_SIZE = 10
Options.CHILD_MARKER_GAP = 3

local function themeSize(key, fallback)
  local theme = ItemTree.Theme
  local value = theme and type(theme.sizes) == "table" and theme.sizes[key]
  if type(value) == "number" then
    return value
  end
  return fallback
end

--- The marker's side in pixels and its gap to the label, from the Theme tokens. Pure.
function Options.ChildMarkerSize()
  return themeSize("ITEMTREE_OPTIONS_CHILD_MARKER", Options.CHILD_MARKER_SIZE),
    themeSize("ITEMTREE_OPTIONS_CHILD_MARKER_GAP", Options.CHILD_MARKER_GAP)
end

--- Where the marker's left edge sits from the row's left edge, for a row indented by indent
--- pixels: just left of the label, with the gap between. nil where the indent leaves no room
--- for it (a row the client did not indent), which is what keeps it off the parent's own label
--- column. Pure.
function Options.ChildMarkerX(indent)
  indent = tonumber(indent)
  if not indent or indent <= 0 then
    return nil
  end
  local size, gap = Options.ChildMarkerSize()
  if indent < size + gap then
    return nil
  end
  return indent + Options.ROW_LABEL_INSET - gap - size
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- One interface cue, by name. UI/Sound.lua decides what a cue sounds like and whether cues are
-- on; this is the one line a call site writes, looked up at call time so a build or a spec
-- without the module costs the cue and nothing else.
--
-- Only one control on this page uses it, and it is not a setting: the page itself opening. Every
-- tick box, dropdown and slider here is the client's own control template and already plays the
-- client's own sound (SettingsCheckboxControlMixin:SetValue, Blizzard_Settings_Shared/
-- Blizzard_SettingControls.lua on the forever branch), so adding one would be a second sound on
-- one click.
local playCue = ItemTree.UI.Sound.PlayCue

local function booleanGetter(def)
  return function()
    local value = Options.Get(def.key)
    if def.checkedValue then
      return value == def.checkedValue
    end
    return value and true or false
  end
end

local function booleanSetter(def)
  return function(value)
    local settings = ItemTree.db and ItemTree.db.settings
    if not settings then
      return
    end
    if def.checkedValue then
      settings[def.key] = value and def.checkedValue or def.uncheckedValue
    else
      settings[def.key] = value and true or false
    end
    Options.OnChanged(def.key, settings[def.key])
  end
end

-- A slider stores a number and a dropdown stores a string, so those two read and write the
-- stored value straight through rather than as a tick box state.
local function valueGetter(def)
  return function()
    return Options.Get(def.key)
  end
end

local function valueSetter(def)
  return function(value)
    local settings = ItemTree.db and ItemTree.db.settings
    if not settings then
      return
    end
    settings[def.key] = value
    Options.OnChanged(def.key, value)
  end
end

-- The control kinds whose stored value is not a boolean, and the Settings.VarType name each
-- one declares.
local VALUE_TYPES = { slider = "Number", dropdown = "String" }

-- The client rejects a setting whose default does not match its declared type, so the type
-- follows the control kind. A client with no VarType table gets the native type name, which
-- is what VarType holds anyway.
local function varTypeFor(Settings, def)
  local name = VALUE_TYPES[def.kind] or "Boolean"
  local types = Settings.VarType
  if type(types) == "table" and type(types[name]) == "string" then
    return types[name]
  end
  return name:lower()
end

-- Brief K10: a slider whose control holds something other than the stored value (the Keep value's
-- stop index) reads and writes through the row's toControl and fromControl. Moving the slider
-- onto the stop the stored value already reads as writes nothing, so an old 30 gold stays 30 gold
-- until the player moves off 20 gold.
local function mappedGetter(def)
  return function()
    return def.toControl(Options.Get(def.key))
  end
end

local function mappedSetter(def)
  return function(value)
    local settings = ItemTree.db and ItemTree.db.settings
    if not settings then
      return
    end
    if def.toControl(Options.Get(def.key)) == value then
      return
    end
    local stored = def.fromControl(value)
    settings[def.key] = stored
    Options.OnChanged(def.key, stored)
  end
end

local function isMapped(def)
  return type(def.toControl) == "function" and type(def.fromControl) == "function"
end

-- Brief K27: a spec row reads and writes this character's spec setting through Core/Keep.lua.
local function specGetter(def)
  return function()
    return Options.Get(def.key)
  end
end

local function specSetter(def)
  return function(value)
    local keep = ItemTree.Keep
    if type(keep) ~= "table" or type(keep.SetSpecEnabled) ~= "function" then
      return
    end
    keep.SetSpecEnabled(def.spec, value and true or false)
    Options.OnChanged(def.key, value and true or false)
  end
end

local function accessorsFor(def)
  if def.spec then
    return specGetter(def), specSetter(def)
  end
  if isMapped(def) then
    return mappedGetter(def), mappedSetter(def)
  end
  if VALUE_TYPES[def.kind] then
    return valueGetter(def), valueSetter(def)
  end
  return booleanGetter(def), booleanSetter(def)
end

-- Registers one setting and says which of the two paths it took. The 11.x signature takes
-- the backing table, so the control writes straight into ItemTree.db.settings and tells
-- nobody, which is why Install wires a value changed callback for it. The 10.x proxy form
-- gets explicit accessors and its setter calls Options.OnChanged itself. Density always uses
-- the proxy form because it stores a string but draws as a tick box.
-- Returns the setting and true when it came through the proxy form.
local function registerSetting(Settings, category, def)
  local variable = "ITEMTREE_" .. def.key
  local settings = ItemTree.db and ItemTree.db.settings
  local varType = varTypeFor(Settings, def)
  if
    not def.checkedValue
    and not isMapped(def)
    and not def.spec
    and settings
    and type(Settings.RegisterAddOnSetting) == "function"
  then
    local ok, setting =
      pcall(Settings.RegisterAddOnSetting, category, variable, def.key, settings, varType, def.label, def.default)
    if ok and setting then
      return setting, false
    end
  end
  if type(Settings.RegisterProxySetting) == "function" then
    -- The proxy reads and writes the control state, so a setting that stores a string but
    -- draws as a tick box registers the boolean its getter will return, not the stored
    -- default. Written out rather than with and/or, which cannot carry a false through.
    local default = def.default
    if def.checkedValue then
      default = def.default == def.checkedValue
    end
    if isMapped(def) then
      default = def.toControl(def.default)
    end
    local get, set = accessorsFor(def)
    local ok, setting = pcall(Settings.RegisterProxySetting, category, variable, varType, def.label, default, get, set)
    if ok and setting then
      return setting, true
    end
  end
  return nil
end

-- Settings.CreateSliderOptions takes the range and the step and hands back an options table
-- the slider control reads. The right hand label is set through the options table's own
-- formatter, and the position it wants is named by a client mixin, so both are checked before
-- either is used: a client with the slider but not the formatter shows the bare number, which
-- is still usable.
local function sliderOptions(Settings, def)
  if type(Settings.CreateSliderOptions) ~= "function" then
    return nil
  end
  local ok, options = pcall(Settings.CreateSliderOptions, def.min, def.max, def.step)
  if not ok or type(options) ~= "table" then
    return nil
  end
  local mixin = rawget(_G, "MinimalSliderWithSteppersMixin")
  local labels = type(mixin) == "table" and mixin.Label or nil
  local right = type(labels) == "table" and labels.Right or nil
  if right ~= nil and type(options.SetLabelFormatter) == "function" then
    local format = type(def.labelFormat) == "function" and def.labelFormat or Options.ScaleLabel
    pcall(options.SetLabelFormatter, options, right, format)
  end
  return options
end

-- Brief K14: an option of a row UI/OptionsPreview.lua peeks for (the Keep marks Style and
-- Colours rows) carries onEnter in its option data, which Settings.CreateDropdownButton hands
-- the menu and the menu calls as the pointer lands on the option. It redraws the example for
-- what the option would store and writes nothing. Looked up at call time, as attachPreview is.
local function peekOnHover(data, def, value)
  local preview = ItemTree.UI and ItemTree.UI.OptionsPreview
  if type(data) ~= "table" or not (preview and type(preview.PeekHandler) == "function") then
    return
  end
  local stored = value
  if type(def.fromControl) == "function" then
    local ok, converted = pcall(def.fromControl, value)
    if ok and converted ~= nil then
      stored = converted
    end
  end
  local ok, handler = pcall(preview.PeekHandler, def.key, stored)
  if ok and type(handler) == "function" then
    data.onEnter = handler
  end
end

-- A dropdown takes a function the client calls each time it draws the row, which answers with
-- the option data the client's own text container builds. A row with no options is not drawn
-- at all, rather than drawn empty.
local function dropdownOptions(Settings, def)
  local choices = def.choices
  if type(choices) ~= "table" or #choices == 0 then
    return nil
  end
  if type(Settings.CreateControlTextContainer) ~= "function" then
    return nil
  end
  return function()
    local ok, container = pcall(Settings.CreateControlTextContainer)
    if not ok or type(container) ~= "table" or type(container.Add) ~= "function" then
      return {}
    end
    for _, choice in ipairs(choices) do
      local added, data = pcall(container.Add, container, choice.value, choice.label, choice.tooltip)
      if added then
        peekOnHover(data, def, choice.value)
      end
    end
    local dataOk, data = pcall(container.GetData, container)
    if dataOk and type(data) == "table" then
      return data
    end
    return {}
  end
end

--------------------------------------------------------------------------------
-- The canvas (brief E94).
--
-- The page used to be a vertical layout category: a list of initializers the client drew in its
-- own settings list. The game's settings search walks every vertical layout's initializers
-- (SettingsPanelMixin:FindInitializersMatchingSearchText, Blizzard_SettingsPanel.lua) and reads
-- each one's fields, so one search that passed our rows read data we wrote, and the pass carried
-- our taint into the Social rows after it: "Execution tainted by ItemTree while reading field
-- tooltipFunc" and a blocked IsUserOAuthed (owner, 2026-09-28, item 80).
--
-- So the category is a canvas layout now (Settings.RegisterCanvasLayoutCategory): the client
-- shows one frame of ours where its list would be and the search never looks inside it. The
-- frame draws every row itself, with the client's own row templates created on OUR frames, so
-- it looks like the list did:
--   the section headers are SettingsListSectionHeaderTemplate, filled by the initializer
--   CreateSettingsListSectionHeaderInitializer makes;
--   a tick box, a slider and a dropdown are SettingsCheckboxControlTemplate,
--   SettingsSliderControlTemplate and SettingsDropdownControlTemplate, filled by the initializers
--   Settings.CreateCheckboxInitializer, CreateSliderInitializer and CreateDropdownInitializer
--   make (the forms of Settings.CreateCheckbox and the rest that register nothing), over the
--   setting objects Settings.RegisterAddOnSetting or RegisterProxySetting made, as before;
--   a Reset position row is SettingButtonControlTemplate over CreateSettingsButtonInitializer;
--   the two key rows are our own row with the client's KeyBindingFrameBindingButtonTemplate as
--   the key button, driven by our own capture (the client's KeyBindingFrameBindingTemplate
--   hands its buttons to the settings list's input blocker while it listens, which is hidden
--   behind a canvas, and its listener is the game's own Key Bindings panel's);
--   the header strip is the list's own measurements: the title in GameFontHighlightHuge, a
--   Defaults button, the divider, and the rows in a scroll frame with the client's
--   MinimalScrollBar, at the list's padding and spacing.
-- Checked against github.com/Gethe/wow-ui-source, branch forever: Blizzard_Settings_Shared/
-- Blizzard_SettingControls.lua and .xml, Blizzard_Settings.lua, Blizzard_SettingsList.lua and
-- .xml, Blizzard_SettingsPanel.lua, Blizzard_SettingsLayouts.lua, Blizzard_SettingsInbound.lua,
-- Blizzard_Keybindings.lua and .xml, and Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua.
--
-- The rules the taint proof in tests/spec/ui_options_spec.lua holds this to: nothing is
-- registered into a vertical layout, no initializer is handed to the client's lists, and no
-- field is written on a frame this file did not create. The initializers above are made, never
-- registered, and each is bound to one frame of ours through that frame's GetElementData, which
-- is how the client's row code finds its initializer. None of them is linked to a parent
-- initializer: the client answers IsParentInitializerInLayout by walking the current layout's
-- initializers, which a canvas does not have, so a dependent row is indented and greyed through
-- Indent, AddModifyPredicate and AddEvaluateStateCVar instead.
--------------------------------------------------------------------------------

-- The client's templates, by the names Blizzard_SettingControls.xml, Blizzard_Keybindings.xml and
-- MinimalScrollBar.xml give them on the forever branch.
Options.TEMPLATES = {
  boolean = "SettingsCheckboxControlTemplate",
  slider = "SettingsSliderControlTemplate",
  dropdown = "SettingsDropdownControlTemplate",
  header = "SettingsListSectionHeaderTemplate",
  button = "SettingButtonControlTemplate",
  keyButton = "KeyBindingFrameBindingButtonTemplate",
  panelButton = "UIPanelButtonTemplate",
  scrollBar = "MinimalScrollBar",
}

-- The settings list's own measurements (Blizzard_SettingsList.xml and SettingsListMixin:OnLoad,
-- forever branch): a header 50 tall with the title at 7, -22 and the Defaults button 96 by 22
-- at -36, -16 from the top right; the scroll box from 15 left of the header's foot, 2 below it,
-- to 20 in from the right; inside it 10 above and below the rows, 25 on the left, and 9 between
-- rows. A row is 26 tall (the control templates' size) and a section header 45.
Options.CANVAS_HEADER_H = 50
Options.CANVAS_TITLE_FONT = "GameFontHighlightHuge"
Options.CANVAS_TITLE_X = 7
Options.CANVAS_TITLE_Y = -22
Options.CANVAS_DEFAULTS_W = 96
Options.CANVAS_DEFAULTS_H = 22
Options.CANVAS_DEFAULTS_X = -36
Options.CANVAS_DEFAULTS_Y = -16
Options.CANVAS_LIST_X = -15
Options.CANVAS_LIST_Y = -2
Options.CANVAS_LIST_RIGHT = -20
Options.CANVAS_LIST_BOTTOM = -2
Options.CANVAS_PAD = 10
Options.CANVAS_PAD_LEFT = 25
Options.CANVAS_SPACING = 9
Options.ROW_H = 26
Options.HEADER_ROW_H = 45
-- The scroll bar beside the list, as the list anchors it.
Options.SCROLLBAR_TOP = -4
Options.SCROLLBAR_BOTTOM = 7
-- The key button, where KeyBindingFrameBindingTemplate puts its first one.
Options.KEY_BUTTON_W = 160
Options.KEY_BUTTON_H = 22
Options.KEY_BUTTON_X = -80
-- A row label's font, and the smaller one the client gives a row under a parent.
Options.ROW_FONT = "GameFontNormal"
Options.CHILD_ROW_FONT = "GameFontNormalSmall"
-- The Defaults button takes a second click inside this many seconds; the first only asks.
Options.DEFAULTS_CONFIRM_SECONDS = 3

-- The Reset position rows, each under the tick box it belongs to, indented and greyed while that
-- box is off. Not settings: each runs a module's ResetPosition. The words are written as L
-- literals where the row is drawn, so the locale sweep finds them.
Options.RESET_ROWS = {
  { key = "hudReset", after = "hudUnlocked", dependsOn = { "hudEnabled" } },
  { key = "minimapReset", after = "minimapButton", dependsOn = { "minimapButton" } },
  { key = "bossLootMinimapReset", after = "bossLootMinimapButton", dependsOn = { "bossLootMinimapButton" } },
}

-- Brief ST3 (QA item 317): the small sub headings inside a section, each drawn straight before the
-- row it names (before), once: "Where" over Forever badges' two place switches, so the places read
-- apart from the kinds above them. Not settings and not the client's rows: a label of ours at the
-- row labels' inset (buildSubheading), on a row shorter than a control's. The words are L literals
-- here so the locale sweep finds them.
Options.SUBHEADINGS = {
  { key = "badgesWhere", before = "bagOverlay", label = L["Where"] },
}
Options.SUBHEADING_H = 18
Options.SUBHEADING_FONT = "GameFontHighlight"

-- Brief K15: the Custom colour row, a button that opens the client's colour picker with a swatch of
-- the colour beside it, straight under the Colour row and greyed out with it. Not a setting row of
-- the client's: the picker writes keepColorCustom and keepColor itself (Options.OpenColourPicker).
-- Brief K16: and the Custom valuable colour row under the Valuable colour row.
Options.SWATCH_ROWS = { COLOUR_SWATCH, VALUE_COLOUR_SWATCH }

-- Brief K20c: the formula row, one text box for the player's own Bar, and the muted note under it
-- that says when the formula is not understood. Straight after the Bar row and shown only while
-- it reads Formula (Options.FormulaRowsShown). Not settings of the client's: the box writes
-- keepSellFormula itself (Options.SaveFormula). Built at login with every other row (bible A2)
-- and never focused by ItemTree (bible A4): the player clicks into it.
Options.FORMULA_AFTER = "keepSellBar"
Options.FORMULA_ROWS = {
  { kind = "formula", key = "keepSellFormula" },
  -- Brief K24b (F2): the muted help line under the box, shown with it.
  { kind = "formulaHelp", key = "keepSellFormulaHelp" },
  { kind = "formulaNote", key = "keepSellFormulaNote" },
}
Options.FORMULA_BOX_WIDTH = 260
Options.FORMULA_BOX_HEIGHT = 20
Options.TEMPLATES.editBox = "InputBoxTemplate"

--- Brief K20c: whether the formula row and its note are shown for these settings (the saved ones
--- unless given): the row while the Bar reads Formula, the note while it does and the formula is
--- not understood (Core/PriceFormula.lua Check). Brief K24b (F4): an EMPTY box shows no note.
--- Answers two booleans. Pure.
function Options.FormulaRowsShown(settings)
  if type(settings) ~= "table" then
    settings = (ItemTree.db and ItemTree.db.settings) or {}
  end
  if settings.keepSellBar ~= "formula" then
    return false, false
  end
  return true, Options.FormulaNoteText(settings) ~= nil
end

--- Brief K24b (F4): the note under the formula box for these settings (the saved ones unless
--- given): nil for an empty box or a formula that is understood, else "Formula not understood:
--- <the reason> at character N, using 1.5 x vendor", the reason and position the parser returns.
--- Pure over Core/PriceFormula.lua.
function Options.FormulaNoteText(settings)
  if type(settings) ~= "table" then
    settings = (ItemTree.db and ItemTree.db.settings) or {}
  end
  local text = settings.keepSellFormula
  if type(text) ~= "string" or not text:find("%S") then
    return nil
  end
  local formula = ItemTree.PriceFormula
  if type(formula) ~= "table" or type(formula.Check) ~= "function" then
    return nil
  end
  local ok, understood, pos, words = pcall(formula.Check, settings)
  if ok and understood == true then
    return nil
  end
  if not ok then
    pos, words = 1, nil
  end
  return string.format(
    L["Formula not understood: %s at character %d, using 1.5 x vendor"],
    tostring(words or L["not understood"]),
    math.floor(tonumber(pos) or 1)
  )
end

--- Brief K24b (F1, F2, F3): the formula row's help. The grey example inside the empty box, the
--- muted line under it, and the hover's lines: the row's name, the full list of names and what
--- they read, how money is written, the operators and functions, and two worked examples. Each a
--- literal for the locale sweep. Pure.
function Options.FormulaExample()
  return "max(vendor * 2, vendor + 1g)"
end

function Options.FormulaHelpText()
  return L["The auction price must reach this. Use vendor, auction, numbers, money like 1g 20s, and min() or max()."]
end

function Options.FormulaHoverLines()
  return {
    L["Formula"],
    L["Your own line for Auction: the price an item must reach on the auction house, after its cut."],
    L["Names: vendor (its vendor price), auction (the first auction addon with a price), auctionator,"],
    L["auctioneer, dbmarket and dbminbuyout (TSM), and disenchant (when you enchant)."],
    L["Money is written 1g20s5c. Use + - * / and brackets, and min(), max(), avg() and first()."],
    L["Example: max(vendor * 2, vendor + 1g) needs twice the vendor price and at least 1 gold more."],
    L["Example: min(dbmarket * 0.8, vendor * 3) needs 80% of TSM's market value, at most three times vendor."],
  }
end

--- The page, top to bottom, as a list of rows: { kind = "logo" }, { kind = "header", section },
--- { kind = "control", def }, { kind = "keybind", which = "main" or "boss" }, { kind = "reset",
--- spec }, { kind = "swatch", spec }, brief K20c's { kind = "formula" } and { kind = "formulaNote" }
--- and { kind = "providers" }, and brief ST3's { kind = "subheading", spec }. The logo first; a
--- header wherever the section changes; the two key rows as the Keys and clicks header is passed
--- (brief S7); a sub heading straight before the row it names (never at the foot: without that row
--- it heads nothing); each reset and swatch row straight after the row it follows; the database
--- rows after the tick box that governs them. Anything a build never reached lands at the foot.
--- defs defaults to Options.ControlDefinitions(). Pure.
function Options.CanvasRows(defs)
  defs = type(defs) == "table" and defs or Options.ControlDefinitions()
  local rows = { { kind = "logo" } }
  local placed = {}
  local function add(row)
    rows[#rows + 1] = row
  end
  local function keys()
    if not placed.keys then
      placed.keys = true
      add({ kind = "keybind", which = "main" })
      add({ kind = "keybind", which = "boss" })
    end
  end
  local resetAfter, swatchAfter, subheadingBefore = {}, {}, {}
  for _, spec in ipairs(Options.RESET_ROWS) do
    resetAfter[spec.after] = spec
  end
  for _, spec in ipairs(Options.SUBHEADINGS) do
    subheadingBefore[spec.before] = spec
  end
  for _, spec in ipairs(Options.SWATCH_ROWS) do
    swatchAfter[spec.after] = spec
  end
  local current
  for _, def in ipairs(defs) do
    if def.section and def.section ~= current then
      current = def.section
      add({ kind = "header", section = def.section })
      if def.section == Options.KEYS_SECTION then
        keys()
      end
    end
    local subheading = subheadingBefore[def.key]
    if subheading and not placed[subheading.key] then
      placed[subheading.key] = true
      add({ kind = "subheading", spec = subheading })
    end
    add({ kind = "control", def = def })
    local spec = resetAfter[def.key]
    if spec and not placed[spec.key] then
      placed[spec.key] = true
      add({ kind = "reset", spec = spec })
    end
    local swatch = swatchAfter[def.key]
    if swatch and not placed[swatch.key] then
      placed[swatch.key] = true
      add({ kind = "swatch", spec = swatch })
    end
    -- Brief K20c: the formula row and its note, straight after the Bar row.
    if def.key == Options.FORMULA_AFTER and not placed.formula then
      placed.formula = true
      for _, formulaRow in ipairs(Options.FORMULA_ROWS) do
        add({ kind = formulaRow.kind, spec = formulaRow })
      end
    end
    if def.key == "useProviders" and not placed.providers then
      placed.providers = true
      add({ kind = "providers" })
    end
  end
  keys()
  for _, spec in ipairs(Options.RESET_ROWS) do
    if not placed[spec.key] then
      placed[spec.key] = true
      add({ kind = "reset", spec = spec })
    end
  end
  for _, spec in ipairs(Options.SWATCH_ROWS) do
    if not placed[spec.key] then
      placed[spec.key] = true
      add({ kind = "swatch", spec = spec })
    end
  end
  if not placed.providers then
    add({ kind = "providers" })
  end
  return rows
end

--- Where each row's top sits below the top of the list, and how tall the list is, for rows of the
--- given heights: the list's padding above, its spacing between, its padding below. Pure.
function Options.StackOffsets(heights, pad, spacing)
  pad = tonumber(pad) or Options.CANVAS_PAD
  spacing = tonumber(spacing) or Options.CANVAS_SPACING
  local offsets, y = {}, pad
  for index, height in ipairs(type(heights) == "table" and heights or EMPTY) do
    if index > 1 then
      y = y + spacing
    end
    offsets[index] = y
    y = y + (tonumber(height) or 0)
  end
  return offsets, y + pad
end

--- The value each setting on the page goes back to under Defaults, as { key, value } in page
--- order: DB_DEFAULTS.settings first, a registered row's own default otherwise. Brief K27: a spec
--- row is left out, since it is this character's and not a db.settings key; Options.ResetToDefaults
--- turns every spec back on itself. Pure.
function Options.DefaultValues(defs)
  local source = defaults()
  local out = {}
  for _, def in ipairs(type(defs) == "table" and defs or Options.ControlDefinitions()) do
    local value = not def.spec and source[def.key] or nil
    if value == nil then
      value = def.default
    end
    if value ~= nil and not def.spec then
      out[#out + 1] = { key = def.key, value = value }
    end
  end
  return out
end

--- Puts every setting on the page back to its default, telling the live surfaces about each one
--- that changed. Positions and key bindings are not settings and are left alone, as the
--- client's own Defaults leaves them. Answers the keys that changed.
function Options.ResetToDefaults()
  local settings = ItemTree.db and ItemTree.db.settings
  local changed = {}
  if type(settings) ~= "table" then
    return changed
  end
  for _, entry in ipairs(Options.DefaultValues()) do
    if settings[entry.key] ~= entry.value then
      settings[entry.key] = entry.value
      changed[#changed + 1] = entry.key
      pcall(Options.OnChanged, entry.key, entry.value)
    end
  end
  -- Brief K27: every spec of this character's class back on, its default.
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.SetSpecEnabled) == "function" then
    for _, def in ipairs(Options.SpecDefinitions(Options.SpecClass())) do
      if keep.SetSpecEnabled(def.spec, true) then
        changed[#changed + 1] = def.key
        pcall(Options.OnChanged, def.key, true)
      end
    end
  end
  if type(Options.RefreshCanvas) == "function" then
    pcall(Options.RefreshCanvas)
  end
  return changed
end

--------------------------------------------------------------------------------
-- Frames and font strings, all of them ours.
--------------------------------------------------------------------------------

Options.FONT_TEMPLATE = "GameFontNormalSmall"
Options.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Options.FONT_FALLBACKS) do
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

-- A font string that is never fontless. The client's own font object is asked for at
-- creation, through the template argument where the client takes one and by hand where it
-- does not, so a SetText is never the first thing to touch the font. A caller that wants
-- another of the client's fonts names it; a client that will not take the template still gets
-- a font string with a font on it, in whatever face Options.FONT_FALLBACKS could be had.
local function newFontString(parent, layer, template)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, template or Options.FONT_TEMPLATE)
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

-- One method call on a frame or region of ours, pcall'd, answering what it answered.
local function call(object, name, ...)
  if type(object) ~= "table" or type(object[name]) ~= "function" then
    return nil
  end
  local answer = { pcall(object[name], object, ...) }
  if not answer[1] then
    return nil
  end
  return unpack(answer, 2)
end

-- A frame of ours, made from the client's template where one is named. nil where the client
-- will not make it, which the caller answers by drawing less.
local function newFrame(kind, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent, template)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

local function showRegion(region, shown)
  if type(region) ~= "table" then
    return
  end
  if shown then
    call(region, "Show")
    return
  end
  call(region, "Hide")
end

-- The client's own settings tooltip where it has one, the game tooltip otherwise.
local function settingsTooltip()
  local tooltip = rawget(_G, "SettingsTooltip")
  if type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
    return tooltip
  end
  tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.SetOwner) == "function" then
    return tooltip
  end
  return nil
end

-- The client's row code finds its initializer through GetElementData, which the client's list
-- hands every frame it lays out. Our frames are laid out by us, so each is given its own.
local function bindInitializer(frame, initializer)
  frame.GetElementData = function()
    return initializer
  end
end

--------------------------------------------------------------------------------
-- The logo row: the artwork and the version line on a frame of ours, as tall as
-- Options.LOGO_ROW_EXTENT. The fallback, where the art will not draw, is the square mark inline
-- in the first section header's text through Assets.Markup. Robust before pretty.
--------------------------------------------------------------------------------

Options.LOGO_HEIGHT = 64
-- The row is the artwork plus the padding above and below it.
Options.LOGO_ROW_EXTENT = 84
-- Width over height, if UI/Assets.lua cannot be asked. The artwork sits on a padded canvas,
-- so drawing it square would squash it.
Options.LOGO_ASPECT = 1.412698
-- The inline mark in the fallback header, at about the height of a header line.
Options.LOGO_MARK_SIZE = 18
Options.LOGO_INDENT = 37

-- The LOGO entry's stated aspect, or the constant. Assets.Get raises on an unknown key, so
-- the key is asked for first, exactly as UI/Report.lua does it.
local function logoAspect()
  local assets = ItemTree.Assets
  if not (assets and type(assets.Has) == "function" and assets.Has("LOGO")) then
    return Options.LOGO_ASPECT
  end
  local ok, entry = pcall(assets.Get, "LOGO")
  if ok and type(entry) == "table" and type(entry.aspect) == "number" and entry.aspect > 0 then
    return entry.aspect
  end
  return Options.LOGO_ASPECT
end

-- Draws the logo and the version onto the logo row, once. Returns the texture or nil, and nil
-- is what makes the row draw nothing rather than a broken picture.
local function buildLogo(frame)
  if frame.itemTreeLogo then
    return frame.itemTreeLogo
  end
  local assets = ItemTree.Assets
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  if not (assets and type(assets.Apply) == "function" and type(assets.Has) == "function" and assets.Has("LOGO")) then
    return nil
  end
  local made, texture = pcall(frame.CreateTexture, frame, nil, "ARTWORK")
  if not made or type(texture) ~= "table" then
    return nil
  end
  local applied, drawn = pcall(assets.Apply, texture, "LOGO")
  if not applied or drawn == false then
    call(texture, "Hide")
    return nil
  end
  local height = Options.LOGO_HEIGHT
  call(texture, "SetSize", math.floor(height * logoAspect() + 0.5), height)
  call(texture, "SetPoint", "LEFT", frame, "LEFT", Options.LOGO_INDENT, 0)
  frame.itemTreeLogo = texture

  local version = newFontString(frame, "OVERLAY")
  if version then
    call(version, "SetPoint", "LEFT", texture, "RIGHT", 12, 0)
    setText(version, tostring(ItemTree.version or "dev"))
    frame.itemTreeLogoVersion = version
  end
  return texture
end

-- The square mark as inline text, for the fallback. The escape is square, so this is
-- LOGO_MARK rather than the wide logo, which would be squashed.
local function logoMarkup()
  local assets = ItemTree.Assets
  if not (assets and type(assets.Markup) == "function" and type(assets.Has) == "function") then
    return nil
  end
  if not assets.Has("LOGO_MARK") then
    return nil
  end
  local ok, markup = pcall(assets.Markup, "LOGO_MARK", Options.LOGO_MARK_SIZE)
  if ok and type(markup) == "string" and markup ~= "" then
    return markup
  end
  return nil
end

--------------------------------------------------------------------------------
-- The key rows. The client's own key binding row cannot live on a canvas (see the canvas
-- section above), so each is a row of ours: the label where the client puts a row label, and one
-- key button made from the client's KeyBindingFrameBindingButtonTemplate where the client puts
-- its first. The button captures the next key press itself: Keybind.CaptureDecision says what a
-- press means and Keybind.BindingString builds the binding string, both pure and specced.
-- Keybind.KeyText stays the single source of the display string, and Keybind.Set and
-- Keybind.Clear own the writing, so nothing here calls SetBinding itself.
--
-- Brief ST1 (QA item 285, the owner: "Mimic the standard hotkey style interface horizontal
-- stack (but keep our default current hotkey)"): each row is the game's Key Bindings row, the
-- label then two equal key buttons side by side, Key 1 where the client puts Button1 and Key 2
-- straight to its right (KeyBindingFrameBindingTemplate, Blizzard_Settings_Shared/
-- Blizzard_Keybindings.xml:64 to 81, branch forever, 1.60.1.70450). Key 1 holds today's key
-- (the default ApplyDefault offers); Key 2 reads Not bound until set, greyed at 0.8 as the
-- client's BindingButtonTemplate_SetupBindingButton draws an empty one (Blizzard_SharedXML/
-- BindingUtil.lua:224 to 230). Both listen for a key or a gamepad button, as the client's
-- KeybindListener does (OnKeyDown and OnGamePadButtonDown, Blizzard_Keybindings.lua:3 to 9):
-- a pad press only reaches a frame that has EnableGamePadButton on, so a capturing button turns
-- it on and off again with its OnGamePadButtonDown script. Both buttons are made with the row,
-- at login with the rest of the page (bible A2), never while the client's panel is open.
--------------------------------------------------------------------------------

-- The row label for the key binding control, and the full sentence behind it. The label is
-- kept short to fit the label column, which ends 85 left of the row's middle. It is not a
-- setting: it writes a client key binding, not ItemTree.db.settings, so it is deliberately
-- outside Definitions and ORDER.
local function keybindAction()
  local keybind = ItemTree.Keybind
  if keybind and type(keybind.BINDING) == "string" and keybind.BINDING ~= "" then
    return keybind.BINDING
  end
  return nil
end

-- Brief B1: the Boss loot binding's action, or nil on a build whose Keybind has none.
local function bossKeybindAction()
  local keybind = ItemTree.Keybind
  if keybind and type(keybind.BOSS_BINDING) == "string" and keybind.BOSS_BINDING ~= "" then
    return keybind.BOSS_BINDING
  end
  return nil
end

--- Brief B1: the Boss loot row's tooltip lines. The second line is there only while the Boss loot
--- tab is turned off (Keybind.BossLootOn), because the key opens nothing then.
function Options.BossKeybindLines()
  local lines = { L[Options.BOSS_KEYBIND_TOOLTIP] }
  local keybind = ItemTree.Keybind
  if keybind and type(keybind.BossLootOn) == "function" then
    local ok, on = pcall(keybind.BossLootOn)
    if ok and not on then
      lines[#lines + 1] = L[Options.BOSS_KEYBIND_OFF]
    end
  end
  return lines
end

-- What each key row says: its action, its label and the lines its tooltip carries, read at
-- hover time.
local function keyRowFor(which)
  if which == "boss" then
    return { action = bossKeybindAction(), label = L[Options.BOSS_KEYBIND_LABEL], lines = Options.BossKeybindLines }
  end
  return {
    action = keybindAction(),
    label = L[Options.KEYBIND_LABEL],
    lines = function()
      return { L[Options.KEYBIND_TOOLTIP] }
    end,
  }
end

-- Live key buttons, weakly held.
local liveButtons = setmetatable({}, { __mode = "k" })

-- Brief ST1: the two key buttons a row carries, Key 1 then Key 2.
Options.KEY_SLOTS = 2
-- The client draws an empty key button at this alpha (BindingUtil.lua:229, branch forever).
Options.KEY_UNBOUND_ALPHA = 0.8

local function boundKeyText(action, slot)
  local keybind = ItemTree.Keybind
  if keybind and type(keybind.KeyText) == "function" then
    local ok, text = pcall(keybind.KeyText, action, slot)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  return nil
end

--- Brief ST1: what a key button says and how bright it is: the bound key at full alpha, or
--- "Not bound" in the hint grey at the client's 0.8, or the capture prompt while it listens.
--- Answers text, alpha. Reads the key through Keybind.KeyText, the grey from UI/Theme.lua.
function Options.KeyButtonFace(action, slot, capturing)
  if capturing then
    return L["Press a key or button"], 1
  end
  local text = boundKeyText(action, slot)
  if text then
    return text, 1
  end
  local words = L["Not bound"]
  local theme = ItemTree.Theme
  if type(theme) == "table" and type(theme.Colorise) == "function" then
    local ok, wrapped = pcall(theme.Colorise, "ITEMTREE_COLOR_TEXT_HINT", words)
    if ok and type(wrapped) == "string" then
      words = wrapped
    end
  end
  return words, Options.KEY_UNBOUND_ALPHA
end

local function refreshButton(button)
  -- The client's key button lights up while it listens; ours does while it captures.
  if type(button.SetSelected) == "function" then
    pcall(button.SetSelected, button, button.capturing and true or false)
  end
  local text, alpha = Options.KeyButtonFace(button.itemTreeAction, button.itemTreeSlot, button.capturing)
  button:SetText(text)
  call(button, "SetAlpha", alpha)
end

-- Repaints every live key button. Keybind.Changed calls this whenever the key changes,
-- including a change made from the client's own Key Bindings panel.
function Options.RefreshKeybind()
  for button in pairs(liveButtons) do
    pcall(refreshButton, button)
  end
end

local function modifierDown(name)
  local down = rawget(_G, name)
  if type(down) ~= "function" then
    return false
  end
  local ok, held = pcall(down)
  return ok and held and true or false
end

-- The window's combat registry (UI/Frame.lua), or nil where it is not loaded.
local function windowFrame()
  local ui = ItemTree.UI
  local Frame = type(ui) == "table" and ui.Frame or nil
  if type(Frame) == "table" and type(Frame.AfterCombat) == "function" then
    return Frame
  end
  return nil
end

local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- While capturing, the key must not also run whatever it is bound to today, so the button takes
-- the keyboard with propagation off for the duration (a capture never starts in combat, where
-- SetPropagateKeyboardInput is refused, brief E91).
--
-- Brief ST1b (the JK1 agent's catch): the capture used to end by setting propagation back on,
-- inside the very key press that ended it. The flag a key handler leaves is what decides whether
-- that press goes on to the game, so the key just caught also ran its binding (the action it was
-- just bound to, or whatever it did before). Now the capture ends by turning the keyboard (and the
-- pad) off on the button and leaving propagation off, which means nothing once the button takes
-- no keys: the game's own listener never turns propagation on at all (KeybindListener:
-- SetListening and StopListening, Blizzard_Settings_Shared/Blizzard_Keybindings.lua:26 to 61;
-- off is a frame's default, Blizzard_SharedXML/UI.xsd:844), and CustomBindingButtonMixin only
-- switches its keyboard and pad input off (Blizzard_SharedXML/CustomBindingButtonMixin.lua:24 to
-- 25, 35 to 36, 167 to 168; branch forever, 1.60.1.70450). Turning the keyboard off is allowed in
-- combat (a frame of ours, not a protected one), so the old after combat reset is gone.
local function takeKeyboard(button)
  if not inCombat() then
    call(button, "SetPropagateKeyboardInput", false)
  end
  call(button, "EnableKeyboard", true)
end

-- Brief ST1: a capturing button takes gamepad presses too. EnableGamePadButton is on only while
-- it listens, the way the client's own CustomBindingButtonMixin turns it on and off
-- (Blizzard_SharedXML/CustomBindingButtonMixin.lua:112 to 125, branch forever); a client
-- without it simply never hands the button a pad press.
local function setGamePad(button, listen)
  call(button, "EnableGamePadButton", listen and true or false)
end

-- Brief ST1b: the client's frame time, or nil, to know the frame a capture began in.
local function frameTime()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, value = pcall(getTime)
  if ok and type(value) == "number" then
    return value
  end
  return nil
end

local function stopCapture(button)
  button.capturing = nil
  button.captureStarted = nil
  button:SetScript("OnKeyDown", nil)
  call(button, "SetScript", "OnGamePadButtonDown", nil)
  -- Brief ST1b: input off, propagation left off, so the press that ended the capture stays ours.
  call(button, "EnableKeyboard", false)
  setGamePad(button, false)
  refreshButton(button)
end

-- A capture still running as combat starts is ended there, before the lockdown, so the key
-- button cannot keep the game's keys through a fight. Brief ST1: also every other button's
-- capture as one starts, so only one button listens at a time, as in the client's panel.
local function stopEveryCapture(except)
  for button in pairs(liveButtons) do
    if button.capturing and button ~= except then
      pcall(stopCapture, button)
    end
  end
end

-- A key or (brief ST1) a gamepad button pressed while the button listens. The binding goes in
-- the button's own slot (button.itemTreeSlot), and Backspace or Delete clears that slot alone.
local function onInput(button, key)
  local keybind = ItemTree.Keybind
  if not keybind or type(keybind.CaptureDecision) ~= "function" then
    stopCapture(button)
    return
  end
  local ctrl, alt, shift =
    modifierDown("IsControlKeyDown"), modifierDown("IsAltKeyDown"), modifierDown("IsShiftKeyDown")
  -- Brief JK2 (QA item 308): Cmd on a Mac (META) too, read as the game's own Key Bindings panel
  -- reads it (IsMetaKeyDown, Blizzard_SharedXML/BindingUtil.lua:130, branch forever).
  local meta = modifierDown("IsMetaKeyDown")
  -- Brief KC1 (GP1's note on QA item 324): in the client's gamepad mode the pad's own Shift, Ctrl
  -- and Alt buttons too (Keybind.PadHeldModifiers), which IsShiftKeyDown and the rest never see
  -- there, so Left trigger + X binds as SHIFT-PAD3 with gamepad mode on as it does with it off.
  if type(keybind.PadHeldModifiers) == "function" then
    local ok, padDown = pcall(keybind.PadHeldModifiers)
    if ok and type(padDown) == "table" then
      ctrl = ctrl or padDown.ctrl == true
      alt = alt or padDown.alt == true
      shift = shift or padDown.shift == true
    end
  end
  local padHeld = nil
  if type(keybind.PadModifiers) == "function" then
    local ok, held = pcall(keybind.PadModifiers)
    padHeld = ok and held or nil
  end
  local what, binding = keybind.CaptureDecision(key, ctrl, alt, shift, padHeld, meta)
  if what == "ignore" then
    return
  end
  if what == "clear" then
    button.notice = nil
    if type(keybind.Clear) == "function" then
      pcall(keybind.Clear, button.itemTreeAction, button.itemTreeSlot)
    end
  elseif what == "bind" then
    button.notice = nil
    if type(keybind.Set) == "function" then
      -- The client unbinds whatever else held the key, which is what the Key Bindings panel
      -- does too, so the only thing left to do is say what was replaced.
      local ok, applied, replaced = pcall(keybind.Set, binding, button.itemTreeAction, button.itemTreeSlot)
      if ok and applied and replaced then
        button.notice = string.format(L["This key was bound to %s"], replaced)
      end
    end
  end
  stopCapture(button)
end

-- Brief ST1: a gamepad press while the button listens. On Forever an OnGamePadButtonDown script
-- answers whether the press goes on to the game's bindings: true lets it through, false keeps it
-- (Blizzard_SharedXML/Blizzard_RadialWheel.lua:547 to 561 keeps PAD2 with false;
-- Blizzard_GamepadActionBars/FlyoutRadial.lua:276 lets every press through with true; branch
-- forever, 1.60.1.70450). Every press is the player's answer to "Press a key or button", so it is
-- kept: it must never also run what the button is bound to, nor the gamepad UI's own click on
-- the focused key button, which would start the capture again.
-- Brief ST1b (as JK1 does): a press in the very frame the capture began is the gamepad cursor's
-- own click that began it, reaching the button after the click turned its pad input on; it is
-- kept and passed over, and the capture goes on waiting for the player's answer.
local function onGamePadInput(button, key)
  if button.captureStarted ~= nil and button.captureStarted == frameTime() then
    return false
  end
  onInput(button, key)
  return false
end

local function startCapture(button)
  local keybind = ItemTree.Keybind
  if keybind and type(keybind.InCombat) == "function" and keybind.InCombat() then
    button.notice = L["Key bindings cannot be changed in combat"]
    return
  end
  button.notice = nil
  stopEveryCapture(button)
  local Frame = windowFrame()
  if Frame and type(Frame.OnCombatStart) == "function" then
    Frame.OnCombatStart("Options.capture", stopEveryCapture)
  end
  button.capturing = true
  button.captureStarted = frameTime()
  takeKeyboard(button)
  button:SetScript("OnKeyDown", onInput)
  call(button, "SetScript", "OnGamePadButtonDown", onGamePadInput)
  setGamePad(button, true)
  refreshButton(button)
end

-- The row's words, first line highlighted the way the client's own row tooltips are.
local function addLines(tooltip, lines)
  for index, line in ipairs(lines) do
    if index == 1 then
      tooltip:AddLine(line)
    else
      tooltip:AddLine(line, 1, 1, 1)
    end
  end
end

local function rowLines(owner)
  local lines = type(owner.itemTreeLines) == "function" and owner.itemTreeLines() or nil
  if type(lines) ~= "table" or #lines == 0 then
    lines = { L[Options.KEYBIND_TOOLTIP] }
  end
  return lines
end

-- Brief KC1 (GP1's note on QA item 324): the key buttons' hover lines on what works in the
-- client's gamepad mode. KC2 (QA item 335, the owner's round AI: Left trigger + X did not open
-- ItemTree on a gamepad bag item; the game's bags keep their own buttons): the lines say so instead
-- of promising a pair (GM1's More menu entry came out with item 336). Jettison's key buttons keep
-- its own words, where its pair works (item 333b).
Options.PAD_MODE_TIP = {
  L["Gamepad mode: the game's bags and windows keep their own buttons,"],
  L["so a key here may not work while they are open."],
}

local function showButtonTooltip(button)
  local tooltip = settingsTooltip()
  if not tooltip then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  addLines(tooltip, rowLines(button))
  tooltip:AddLine(L["Click, then press a key or a gamepad button. Right click to clear it."], 1, 1, 1)
  for _, line in ipairs(Options.PAD_MODE_TIP) do
    tooltip:AddLine(line, 1, 1, 1)
  end
  if button.notice then
    tooltip:AddLine(button.notice, 1, 1, 1)
  end
  tooltip:Show()
end

local function hideTooltip()
  local tooltip = settingsTooltip()
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- One key button of a row, for slot 1 or (brief ST1) slot 2. Key 1 sits where the client puts
-- Button1, Key 2 straight to its right, the same size, as Button2 does.
local function buildButton(frame, slot)
  frame.itemTreeKeyButtons = frame.itemTreeKeyButtons or {}
  if frame.itemTreeKeyButtons[slot] then
    return frame.itemTreeKeyButtons[slot]
  end
  local button = newFrame("Button", frame, Options.TEMPLATES.keyButton)
    or newFrame("Button", frame, Options.TEMPLATES.panelButton)
  if not button then
    return nil
  end
  button:SetSize(Options.KEY_BUTTON_W, Options.KEY_BUTTON_H)
  local first = frame.itemTreeKeyButtons[1]
  if slot == 1 or not first then
    button:SetPoint("LEFT", frame, "CENTER", Options.KEY_BUTTON_X + (slot - 1) * Options.KEY_BUTTON_W, 0)
  else
    button:SetPoint("LEFT", first, "RIGHT", 0, 0)
  end
  button.itemTreeSlot = slot
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end
  button:SetScript("OnClick", function(self, clicked)
    if self.capturing then
      stopCapture(self)
      return
    end
    if clicked == "RightButton" then
      local keybind = ItemTree.Keybind
      if keybind and type(keybind.Clear) == "function" then
        pcall(keybind.Clear, self.itemTreeAction, self.itemTreeSlot)
      end
      refreshButton(self)
      return
    end
    startCapture(self)
  end)
  button:SetScript("OnEnter", showButtonTooltip)
  button:SetScript("OnLeave", hideTooltip)
  button:SetScript("OnHide", function(self)
    if self.capturing then
      stopCapture(self)
    end
  end)
  frame.itemTreeKeyButtons[slot] = button
  if slot == 1 then
    frame.itemTreeKeyButton = button
  end
  liveButtons[button] = true
  return button
end

-- The label's hover: the row's name and its sentence, as the client's own rows show theirs.
local function showRowTooltip(frame)
  local tooltip = settingsTooltip()
  if not tooltip then
    return
  end
  tooltip:SetOwner(frame, "ANCHOR_RIGHT")
  addLines(tooltip, rowLines(frame))
  tooltip:Show()
end

-- One key row of ours, or nil on a build whose Keybind names no such action.
local function buildKeyRow(content, which)
  local row = keyRowFor(which)
  if not row.action then
    return nil
  end
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local label = newFontString(frame, "OVERLAY", Options.ROW_FONT)
  if label then
    call(label, "SetPoint", "LEFT", frame, "LEFT", Options.ROW_LABEL_INSET, 0)
    call(label, "SetPoint", "RIGHT", frame, "CENTER", Options.KEY_BUTTON_X - 5, 0)
    call(label, "SetJustifyH", "LEFT")
    setText(label, row.label)
  end
  frame.itemTreeLabel = label
  frame.itemTreeLines = row.lines
  call(frame, "EnableMouse", true)
  call(frame, "SetScript", "OnEnter", showRowTooltip)
  call(frame, "SetScript", "OnLeave", hideTooltip)
  -- Brief ST1: Key 1 and Key 2, both made here with the row.
  local buttons = {}
  for slot = 1, Options.KEY_SLOTS do
    local button = buildButton(frame, slot)
    if button then
      button.itemTreeAction = row.action
      button.itemTreeLines = row.lines
      pcall(refreshButton, button)
      buttons[#buttons + 1] = button
    end
  end
  local button = frame.itemTreeKeyButton
  local record = { route = "canvas", label = row.label, action = row.action, button = button, buttons = buttons }
  if which == "boss" then
    Options.bossLootKeybind = record
  else
    Options.keybind = record
  end
  return { kind = "keybind", key = which, frame = frame, height = Options.ROW_H, record = record }
end

--------------------------------------------------------------------------------
-- The Reset position rows.
--------------------------------------------------------------------------------

local function hudResetClick()
  local editMode = ItemTree.UI and ItemTree.UI.EditMode
  if editMode and type(editMode.ResetPosition) == "function" then
    pcall(editMode.ResetPosition)
  end
end

local function minimapResetClick()
  local minimap = ItemTree.UI and ItemTree.UI.Minimap
  if minimap and type(minimap.ResetPosition) == "function" then
    pcall(minimap.ResetPosition)
  end
end

local function bossMinimapResetClick()
  local minimap = ItemTree.UI and ItemTree.UI.Minimap
  if minimap and type(minimap.ResetBossPosition) == "function" then
    pcall(minimap.ResetBossPosition)
  end
end

-- The words and the click for each reset row: label, button text, tooltip, click.
local function resetWords(key)
  if key == "minimapReset" then
    return L["Minimap button"],
      L["Reset position"],
      L["Moves the minimap button to a free spot on the ring."],
      minimapResetClick
  end
  if key == "bossLootMinimapReset" then
    return L["Boss loot minimap button"],
      L["Reset position"],
      L["Moves the Boss loot minimap button to a free spot beside the main one."],
      bossMinimapResetClick
  end
  return L[Options.HUD_RESET_LABEL], L[Options.HUD_RESET_BUTTON], L[Options.HUD_RESET_TOOLTIP], hudResetClick
end

--------------------------------------------------------------------------------
-- The Source databases rows: one per installed database, its name and its state in plain
-- words, and nothing to click. They are made again every time the page is shown, so a database
-- that finished loading while the page was closed reads as Ready the next time it is opened.
--------------------------------------------------------------------------------

-- The client's own font for the state beside the name: the white one it uses for a value.
Options.PROVIDER_STATE_FONT = "GameFontHighlightSmall"

-- Status rows that are on screen, weakly held.
local liveProviderRows = setmetatable({}, { __mode = "k" })

--- The rows the section draws right now. A build with no registry, or with no database
--- installed, answers an empty list, which leaves the section as the tick box alone.
function Options.ProviderStatus()
  local providers = ItemTree.Providers
  if type(providers) ~= "table" or type(providers.Status) ~= "function" then
    return {}
  end
  local ok, statuses = pcall(providers.Status)
  if not ok or type(statuses) ~= "table" then
    return {}
  end
  local enabled = true
  if type(providers.Enabled) == "function" then
    local asked, value = pcall(providers.Enabled)
    if asked then
      enabled = value ~= false
    end
  end
  return Options.ProviderRows(statuses, enabled)
end

--- The live row for one database key, or nil where the registry has nothing to say about it.
function Options.ProviderRow(key)
  for _, row in ipairs(Options.ProviderStatus()) do
    if row.key == key then
      return row
    end
  end
  return nil
end

-- Asks every adapter to look at itself again. The registry does this on its own events as
-- well; this is for the database whose own ready hook never took, so opening the page is
-- always a fresh look. It is two "is that addon there" questions and no item query at all.
local function refreshAdapters()
  local providers = ItemTree.Providers
  if type(providers) == "table" and type(providers.RefreshAll) == "function" then
    pcall(providers.RefreshAll)
  end
end

-- Draws one status row's pieces onto a row frame, once per frame. Returns the frame, or nil
-- where it would take no font string, which leaves the row blank rather than half drawn.
local function buildProviderRow(frame)
  if frame.itemTreeProviderName then
    return frame
  end
  local name = newFontString(frame, "OVERLAY")
  local state = newFontString(frame, "OVERLAY", Options.PROVIDER_STATE_FONT)
  if not name or not state then
    return nil
  end
  local line = Options.PROVIDER_TOP + Options.PROVIDER_LINE_H / 2
  call(name, "SetPoint", "LEFT", frame, "TOPLEFT", Options.LOGO_INDENT, -line)
  call(state, "SetPoint", "LEFT", frame, "TOP", Options.PROVIDER_STATE_X, -line)
  call(state, "SetWidth", Options.PROVIDER_STATE_W)
  call(state, "SetJustifyH", "LEFT")
  frame.itemTreeProviderName, frame.itemTreeProviderState = name, state
  return frame
end

-- Writes what one database says onto the frame it is drawn on. Returns the row, or nil where
-- the frame would take nothing or the database no longer reports itself installed, in which
-- case the row is left blank rather than naming an addon the player does not have.
local function paintProviderRow(frame, key)
  if not buildProviderRow(frame) then
    return nil
  end
  liveProviderRows[frame] = key
  local row = Options.ProviderRow(key)
  if not row then
    showRegion(frame.itemTreeProviderName, false)
    showRegion(frame.itemTreeProviderState, false)
    return nil
  end
  setText(frame.itemTreeProviderName, row.label)
  setText(frame.itemTreeProviderState, row.stateText)
  showRegion(frame.itemTreeProviderName, true)
  showRegion(frame.itemTreeProviderState, true)
  return row
end

--- Repaints every status row that is on screen. The rows read the databases again whenever the
--- page is shown, so this is for a change made while the player is looking at them.
function Options.RefreshProviders()
  for frame, key in pairs(liveProviderRows) do
    pcall(paintProviderRow, frame, key)
  end
end

-- The status frames, one per installed database, made as they are first needed and kept.
local providerFrames = {}

-- Paints one frame per installed database and hides the rest. Answers the frames in use.
local function syncProviderRows(content)
  refreshAdapters()
  local used = {}
  local keys = {}
  for index, row in ipairs(Options.ProviderStatus()) do
    local frame = providerFrames[index]
    if not frame then
      -- Brief TX1: made with no parent and then moved under the page. The page is built at login,
      -- so this only runs for a database that arrives later, possibly while the page is up inside
      -- the client's settings panel, and a CreateFrame whose parent sits in an open client panel
      -- runs the gamepad SmartNavigation's CreateFrame hook (UpdateParent, RefreshButtonGroups)
      -- as us. SetParent is not hooked.
      frame = newFrame("Frame", nil)
      call(frame, "SetParent", content)
      providerFrames[index] = frame
    end
    if frame and paintProviderRow(frame, row.key) then
      used[#used + 1] = frame
      keys[#keys + 1] = row.key
    end
  end
  for index = 1, #providerFrames do
    local frame = providerFrames[index]
    local inUse = false
    for _, other in ipairs(used) do
      inUse = inUse or other == frame
    end
    if not inUse then
      liveProviderRows[frame] = nil
      showRegion(frame, false)
    end
  end
  Options.providerRows = #keys > 0 and { route = "canvas", keys = keys } or nil
  return used
end

--------------------------------------------------------------------------------
-- Dependent rows and the child marker.
--------------------------------------------------------------------------------

-- Brief U2: hands one control row to UI/OptionsPreview.lua, which follows the pointer on it and
-- shows the row's example beside it. Looked up at call time, so a build without the file keeps
-- every row exactly as it was.
local function attachPreview(initializer, def)
  local preview = ItemTree.UI and ItemTree.UI.OptionsPreview
  if type(initializer) ~= "table" or not (preview and type(preview.AttachRow) == "function") then
    return false
  end
  local ok, attached = pcall(preview.AttachRow, initializer, def.key, def.kind)
  return ok and attached == true
end

-- Brief U2c: an ORDER entry may carry dependsOn, a list of tick box keys the row depends on. It
-- is enabled while ANY of them is on and greyed out, the client's own way, while all are off.
-- Brief K15: it may also carry requires, { key = value }, settings that must ALL read exactly that
-- value (the Colour row needs Colours on Single colour). Brief K16: or pass a test, where the value
-- is a function (the Valuable colour row needs the Keep value on). Pure: a row with neither is always
-- enabled. settings defaults to the saved settings, and a key never written reads as its
-- default, the way Options.Get reads it.
local function readSetting(key, settings)
  if type(settings) == "table" then
    local value = settings[key]
    if value == nil then
      value = defaults()[key]
    end
    return value
  end
  return Options.Get(key)
end

function Options.DependsMet(def, settings)
  local requires = type(def) == "table" and def.requires or nil
  if type(requires) == "table" then
    for key, wanted in pairs(requires) do
      -- Brief K16: a function is a test the setting's value must pass (the Keep value is on).
      if type(wanted) == "function" then
        if not wanted(readSetting(key, settings)) then
          return false
        end
      elseif readSetting(key, settings) ~= wanted then
        return false
      end
    end
  end
  local parents = type(def) == "table" and def.dependsOn or nil
  if type(parents) ~= "table" or #parents == 0 then
    return true
  end
  for _, key in ipairs(parents) do
    if readSetting(key, settings) then
      return true
    end
  end
  return false
end

-- The settings a dependent row is evaluated again on: its dependsOn parents, then its requires
-- keys in name order. Pure.
function Options.WatchedKeys(spec)
  local out, seen = {}, {}
  for _, key in ipairs(type(spec) == "table" and type(spec.dependsOn) == "table" and spec.dependsOn or EMPTY) do
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  local extra = {}
  for key in pairs(type(spec) == "table" and type(spec.requires) == "table" and spec.requires or EMPTY) do
    if not seen[key] then
      seen[key] = true
      extra[#extra + 1] = key
    end
  end
  table.sort(extra)
  for _, key in ipairs(extra) do
    out[#out + 1] = key
  end
  return out
end

-- Brief U5: the child marker on a dependent row. One texture per frame, made the first time the
-- row is initialised and kept; shown on init and hidden on release. It is a region of the row
-- frame, so the client's DisplayEnabled (DesaturateHierarchy) greys it with the row when the
-- master switch is off.
local function buildChildMarker(frame)
  if frame.itemTreeChildMarker then
    return frame.itemTreeChildMarker
  end
  local assets = ItemTree.Assets
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local key = Options.CHILD_MARKER_ASSET
  if not (assets and type(assets.Apply) == "function" and type(assets.Has) == "function" and assets.Has(key)) then
    return nil
  end
  local made, texture = pcall(frame.CreateTexture, frame, nil, "ARTWORK")
  if not made or type(texture) ~= "table" then
    return nil
  end
  local applied, drawn = pcall(assets.Apply, texture, key)
  if not applied or drawn == false then
    call(texture, "Hide")
    return nil
  end
  local size = Options.ChildMarkerSize()
  call(texture, "SetSize", size, size)
  local theme = ItemTree.Theme
  if theme and type(theme.Color) == "function" and type(texture.SetVertexColor) == "function" then
    local ok, r, g, b = pcall(theme.Color, "ITEMTREE_COLOR_TEXT_MUTED")
    if ok then
      pcall(texture.SetVertexColor, texture, r, g, b)
    end
  end
  frame.itemTreeChildMarker = texture
  return texture
end

-- The row's own indent as the client reads it, which is what placed its label.
local function rowIndent(frame)
  if type(frame.GetIndent) == "function" then
    local ok, indent = pcall(frame.GetIndent, frame)
    if ok and type(indent) == "number" then
      return indent
    end
  end
  return Options.ROW_INDENT
end

local function showChildMarker(frame)
  if type(frame) ~= "table" then
    return
  end
  local x = Options.ChildMarkerX(rowIndent(frame))
  local texture = x and buildChildMarker(frame) or nil
  if not texture then
    showRegion(frame.itemTreeChildMarker, false)
    return
  end
  call(texture, "ClearAllPoints")
  call(texture, "SetPoint", "LEFT", frame, "LEFT", x, 0)
  showRegion(texture, true)
end

local function hideChildMarker(frame)
  if type(frame) == "table" then
    showRegion(frame.itemTreeChildMarker, false)
  end
end

-- Wraps a dependent row's InitFrame and Resetter the way UI/OptionsPreview.lua's AttachRow does:
-- the client's own run first, and ours follows, pcall'd. Once per initializer. Records the row
-- in Options.childMarkers for the specs.
local function attachChildMarker(initializer, key)
  if type(initializer) ~= "table" then
    return false
  end
  if not initializer.itemTreeChildMarker then
    initializer.itemTreeChildMarker = true
    local baseInit = initializer.InitFrame
    initializer.InitFrame = function(self, frame)
      if type(baseInit) == "function" then
        baseInit(self, frame)
      end
      pcall(showChildMarker, frame)
    end
    local baseReset = initializer.Resetter
    initializer.Resetter = function(self, frame)
      if type(baseReset) == "function" then
        baseReset(self, frame)
      end
      pcall(hideChildMarker, frame)
    end
  end
  Options.childMarkers[key] = true
  return true
end

-- A dependent row, indented and greyed by the client's own row code: Indent puts the label 15
-- further in (SettingsListElementInitializer:GetIndent answers indentSize while data.indent is
-- set), AddModifyPredicate is what IsEnabled asks before DisplayEnabled greys the row, and
-- AddEvaluateStateCVar re-runs the row's EvaluateState whenever that setting variable's value
-- changes (it registers on any setting variable, despite its name). Every parent is watched,
-- because a canvas row has no parent initializer to be told through. Records what it did in
-- Options.dependencies for the specs. spec is a definition or a reset row: a key and dependsOn.
local function linkDependents(initializer, spec)
  local parents = spec.dependsOn
  if type(initializer) ~= "table" then
    return false
  end
  -- Brief ST3 (QA item 317): a row that reads as a child of the row above (indent) but stays
  -- enabled whatever that row says: Include minor changes under Show Changed badges, which also
  -- decides the change rows the pages list. Indented and marked as a child, with no predicate.
  if (type(parents) ~= "table" or #parents == 0) and spec.indent == true then
    local indented = false
    if type(initializer.Indent) == "function" then
      indented = pcall(initializer.Indent, initializer)
    end
    Options.dependencies[spec.key] = { route = "indent", watched = {}, indented = indented }
    if indented then
      attachChildMarker(initializer, spec.key)
    end
    return true
  end
  if type(parents) ~= "table" or #parents == 0 then
    return false
  end
  local function predicate()
    return Options.DependsMet(spec)
  end
  if type(initializer.AddModifyPredicate) ~= "function" then
    return false
  end
  if not pcall(initializer.AddModifyPredicate, initializer, predicate) then
    return false
  end
  local indented = false
  if type(initializer.Indent) == "function" then
    indented = pcall(initializer.Indent, initializer)
  end
  local watched = {}
  if type(initializer.AddEvaluateStateCVar) == "function" then
    for _, key in ipairs(Options.WatchedKeys(spec)) do
      local variable = "ITEMTREE_" .. key
      if pcall(initializer.AddEvaluateStateCVar, initializer, variable) then
        watched[#watched + 1] = variable
      end
    end
  end
  Options.dependencies[spec.key] = { route = "predicate", parent = parents[1], watched = watched, indented = indented }
  if indented then
    attachChildMarker(initializer, spec.key)
  end
  return true
end

--------------------------------------------------------------------------------
-- Rows drawn with the client's templates.
--------------------------------------------------------------------------------

-- The template an initializer names, or the fallback for its kind.
local function templateOf(initializer, fallback)
  if type(initializer) == "table" and type(initializer.GetTemplate) == "function" then
    local ok, template = pcall(initializer.GetTemplate, initializer)
    if ok and type(template) == "string" and template ~= "" then
      return template
    end
  end
  return fallback
end

-- Initialises a templated row through its initializer, the way the client's list does
-- (ScrollBoxFactoryInitializerMixin:InitFrame calls frame:Init), so the wrappers the preview and
-- the child marker put on the initializer run too. A child row takes the smaller label the client
-- gives a row under a parent. Answers whether the client's own Init ran.
local function initRow(record)
  local initializer, frame = record.initializer, record.frame
  local ok
  if type(initializer.InitFrame) == "function" then
    ok = pcall(initializer.InitFrame, initializer, frame)
  else
    ok = type(frame.Init) == "function" and pcall(frame.Init, frame, initializer)
  end
  if record.child and type(frame.Text) == "table" then
    call(frame.Text, "SetFontObject", rawget(_G, Options.CHILD_ROW_FONT) or Options.CHILD_ROW_FONT)
  end
  record.initialised = ok and true or false
  return record.initialised
end

-- The client's Release, through the initializer (ScrollBoxFactoryInitializerMixin:Resetter),
-- which drops the row's callback handles so it can be initialised again.
local function releaseRow(record)
  local initializer, frame = record.initializer, record.frame
  if type(initializer.Resetter) == "function" then
    pcall(initializer.Resetter, initializer, frame)
  elseif type(frame.Release) == "function" then
    pcall(frame.Release, frame)
  end
end

-- A frame of the given template carrying the initializer, initialised. nil where the client
-- will not make the frame.
local function templatedRow(content, initializer, template, kind, key, height, child)
  local frame = newFrame("Frame", content, template)
  if not frame then
    return nil
  end
  bindInitializer(frame, initializer)
  local record = {
    kind = kind,
    key = key,
    frame = frame,
    initializer = initializer,
    template = template,
    height = height or Options.ROW_H,
    child = child,
  }
  initRow(record)
  return record
end

-- A section header: the client's header template filled by its own initializer, or a title
-- font string of ours where the client has neither.
local function buildHeader(content, section, prefix)
  local text = L[section]
  if type(prefix) == "string" and prefix ~= "" then
    text = prefix .. " " .. text
  end
  local create = rawget(_G, "CreateSettingsListSectionHeaderInitializer")
  if type(create) == "function" then
    local ok, initializer = pcall(create, text)
    if ok and type(initializer) == "table" then
      local record = templatedRow(
        content,
        initializer,
        templateOf(initializer, Options.TEMPLATES.header),
        "header",
        section,
        Options.HEADER_ROW_H
      )
      if record then
        record.text = text
        return record
      end
    end
  end
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local title = newFontString(frame, "OVERLAY", "GameFontHighlightLarge")
  if title then
    call(title, "SetPoint", "TOPLEFT", frame, "TOPLEFT", 7, -16)
    setText(title, text)
  end
  return { kind = "header", key = section, frame = frame, height = Options.HEADER_ROW_H, text = text, route = "own" }
end

-- The initializer for one control, from the forms of the client's Create* calls that register
-- nothing. nil where the client has no such form or the row has nothing to offer.
local function controlInitializer(Settings, setting, def)
  local create, options
  if def.kind == "slider" then
    create = Settings.CreateSliderInitializer
    options = sliderOptions(Settings, def)
  elseif def.kind == "dropdown" then
    create = Settings.CreateDropdownInitializer
    options = dropdownOptions(Settings, def)
  else
    create = Settings.CreateCheckboxInitializer
  end
  if type(create) ~= "function" then
    return nil
  end
  if def.kind == "slider" or def.kind == "dropdown" then
    if not options then
      return nil
    end
  end
  local ok, initializer = pcall(create, setting, options, def.tooltip)
  if ok and type(initializer) == "table" then
    return initializer
  end
  return nil
end

local function buildControl(Settings, content, def)
  local setting = Options.settingObjects[def.key]
  if not setting then
    return nil
  end
  local initializer = controlInitializer(Settings, setting, def)
  if not initializer then
    return nil
  end
  local child = linkDependents(initializer, def) and Options.dependencies[def.key].indented or false
  -- Brief U2: the row shows an example of what it changes while the pointer is on it.
  attachPreview(initializer, def)
  local template = templateOf(initializer, Options.TEMPLATES[def.kind] or Options.TEMPLATES.boolean)
  return templatedRow(content, initializer, template, "control", def.key, Options.ROW_H, child)
end

local function buildReset(content, spec)
  local create = rawget(_G, "CreateSettingsButtonInitializer")
  if type(create) ~= "function" then
    return nil
  end
  local label, buttonText, tooltip, click = resetWords(spec.key)
  -- The fifth argument is whether the row adds search tags. The client asserts on nil, and there
  -- is no search to tag for on a canvas.
  local ok, initializer = pcall(create, label, buttonText, click, tooltip, false)
  if not ok or type(initializer) ~= "table" then
    return nil
  end
  initializer.itemTreeRow = spec.key
  local child = linkDependents(initializer, spec) and Options.dependencies[spec.key].indented or false
  local record = templatedRow(
    content,
    initializer,
    templateOf(initializer, Options.TEMPLATES.button),
    "reset",
    spec.key,
    Options.ROW_H,
    child
  )
  if record then
    Options[spec.key] = { route = "button", label = label, buttonText = buttonText, initializer = initializer }
  end
  return record
end

--------------------------------------------------------------------------------
-- The Custom colour row and the colour picker (brief K15).
--
-- Checked against github.com/Gethe/wow-ui-source, branch forever. The Settings API does offer a
-- colour swatch control (Settings.CreateColorSwatchInitializer over SettingsColorSwatchControlTemplate,
-- Blizzard_Settings_Shared/Blizzard_Settings.lua and Blizzard_SettingControls.lua), but it stores a
-- hex string and hands its own swatchFunc and cancelFunc to the picker, both only ever writing the
-- setting: the row never learns that the picker opened, so Cancel could not put back a palette
-- colour the picker replaced with "custom". So the row is the client's button row
-- (CreateSettingsButtonInitializer, as the Reset position rows are) on a frame of ours, with a
-- swatch texture of ours beside the button, and its click calls the documented
-- ColorPickerFrame:SetupColorPickerAndShow(info) (Blizzard_ColorPickerFrame/Mainline/
-- ColorPickerFrame.lua) with a plain table of our own: r, g, b, swatchFunc and cancelFunc. The
-- picker calls swatchFunc as its colour moves and on Okay, and cancelFunc on Cancel, Escape or a
-- click outside it. Nothing is written onto ColorPickerFrame, no script is set or hooked on it,
-- and it is only ever read (GetColorRGB, IsShown).
--------------------------------------------------------------------------------

-- The swatch beside the button: its side and its edge, and where it sits from the row's centre (the
-- client's button is 200 wide from 40 left of the centre, SettingsButtonControlMixin:Init).
Options.SWATCH_SIZE = 16
Options.SWATCH_EDGE = 1
Options.SWATCH_X = 168
Options.SWATCH_FILL = "FILL_WHITE8X8"
Options.SWATCH_EDGE_COLOR = "ITEMTREE_COLOR_BORDER_GOLD_DIM"
-- Brief K17: the swatch's alpha while its row is greyed out.
Options.SWATCH_DIM_ALPHA = 0.35

-- The open picker's session, { colour, custom, pair }: what the pair's colour and custom keys held
-- when it opened (keepColor and keepColorCustom, or brief K16's keepValueColor and
-- keepValueColorCustom), put back on Cancel. nil while the picker is not ours.
Options.picker = nil

local function themeOf()
  return ItemTree.Theme
end

-- A stored custom colour as a fresh { r, g, b }, the keep gold (or fallbackToken's colour, brief
-- K16) where it is not one. Pure.
function Options.CustomColour(value, fallbackToken)
  local theme = themeOf()
  if theme and type(theme.CustomColour) == "function" then
    return theme.CustomColour(value, fallbackToken)
  end
  if type(value) == "table" and tonumber(value.r) and tonumber(value.g) and tonumber(value.b) then
    return { r = tonumber(value.r), g = tonumber(value.g), b = tonumber(value.b) }
  end
  return { r = 1, g = 0.761, b = 0.227 }
end

-- The swatch rows on screen, weakly held, so a colour change repaints them.
local liveSwatches = setmetatable({}, { __mode = "k" })

-- The pair a swatch row was drawn for, the Colour pair where it names none.
local function pairOf(spec)
  local pair = type(spec) == "table" and spec.pair or nil
  return pair or Options.COLOUR_PAIRS[1]
end

local function paintSwatch(frame)
  local swatch = type(frame) == "table" and frame.itemTreeSwatch or nil
  if not swatch then
    return false
  end
  local pair = pairOf(frame.itemTreeSwatchSpec)
  local colour = Options.CustomColour(Options.Get(pair.customKey), pair.fallbackToken)
  -- Brief K17: dimmed with its row while the row is greyed out (the dropdown is not on Custom).
  local spec = frame.itemTreeSwatchSpec
  local alpha = 1
  if type(spec) == "table" and not Options.DependsMet(spec) then
    alpha = Options.SWATCH_DIM_ALPHA
  end
  call(swatch.fill, "SetVertexColor", colour.r, colour.g, colour.b, 1)
  call(swatch.fill, "SetAlpha", alpha)
  call(swatch.edge, "SetAlpha", alpha)
  return true
end

--- Repaints every Custom colour swatch on screen from its stored colour. Answers how many.
function Options.RefreshSwatches()
  local painted = 0
  for frame in pairs(liveSwatches) do
    if paintSwatch(frame) then
      painted = painted + 1
    end
  end
  return painted
end

-- One texture of ours on the row frame, drawn from the white fill. nil where the client will not.
local function swatchTexture(frame, layer)
  local assets = ItemTree.Assets
  if type(frame.CreateTexture) ~= "function" or not (assets and type(assets.Apply) == "function") then
    return nil
  end
  local made, texture = pcall(frame.CreateTexture, frame, nil, layer)
  if not made or type(texture) ~= "table" then
    return nil
  end
  local applied, drawn = pcall(assets.Apply, texture, Options.SWATCH_FILL)
  if not applied or drawn == false then
    call(texture, "Hide")
    return nil
  end
  return texture
end

local function buildSwatchTexture(frame)
  if type(frame) ~= "table" then
    return nil
  end
  if frame.itemTreeSwatch then
    return frame.itemTreeSwatch
  end
  local edge = swatchTexture(frame, "ARTWORK")
  local fill = swatchTexture(frame, "OVERLAY")
  if not edge or not fill then
    call(edge, "Hide")
    call(fill, "Hide")
    return nil
  end
  local outer = Options.SWATCH_SIZE + Options.SWATCH_EDGE * 2
  call(edge, "SetSize", outer, outer)
  call(edge, "SetPoint", "LEFT", frame, "CENTER", Options.SWATCH_X, 0)
  local theme = themeOf()
  if theme and type(theme.Color) == "function" then
    local ok, r, g, b = pcall(theme.Color, Options.SWATCH_EDGE_COLOR)
    if ok then
      call(edge, "SetVertexColor", r, g, b, 1)
    end
  end
  call(fill, "SetSize", Options.SWATCH_SIZE, Options.SWATCH_SIZE)
  call(fill, "SetPoint", "CENTER", edge, "CENTER", 0, 0)
  call(edge, "Show")
  call(fill, "Show")
  frame.itemTreeSwatch = { edge = edge, fill = fill }
  liveSwatches[frame] = true
  return frame.itemTreeSwatch
end

-- Re-reads one drawn row through its initializer, so a dropdown shows a value written here.
local function refreshRow(key)
  local record = Options.CanvasRow(key)
  if record and record.initializer then
    releaseRow(record)
    initRow(record)
  end
end

local function writableSettings()
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) == "table" then
    return settings
  end
  return nil
end

--- The colour under the picker, as the player moves it or presses Okay: stored as the pair's
--- custom key (keepColorCustom by default), and the bags, the example and the swatch redrawn at
--- once. Brief K17: the colour key is left alone, because the Custom row (and so the picker) is
--- only enabled while it already reads "custom". Answers whether it was stored.
function Options.ApplyPickedColour(r, g, b, pair)
  pair = pairOf({ pair = pair })
  local settings = writableSettings()
  if not settings then
    return false
  end
  local colour = Options.CustomColour({ r = r, g = g, b = b }, pair.fallbackToken)
  settings[pair.customKey] = colour
  Options.OnChanged(pair.customKey, colour)
  return true
end

--- Cancel, Escape or a click outside the picker: the pair's two keys go back to what they held
--- when it opened, and everything redraws. Answers whether anything was put back.
function Options.CancelPickedColour(session)
  session = session or Options.picker
  local settings = writableSettings()
  if type(session) ~= "table" or not settings then
    return false
  end
  local pair = pairOf(session)
  Options.picker = nil
  settings[pair.customKey] = Options.CustomColour(session.custom, pair.fallbackToken)
  local colourChanged = settings[pair.colorKey] ~= session.colour
  settings[pair.colorKey] = session.colour
  if colourChanged then
    Options.OnChanged(pair.colorKey, session.colour)
    pcall(refreshRow, pair.colorKey)
  end
  Options.OnChanged(pair.customKey, settings[pair.customKey])
  return true
end

local function colourPicker()
  local picker = rawget(_G, "ColorPickerFrame")
  if type(picker) == "table" and type(picker.SetupColorPickerAndShow) == "function" then
    return picker
  end
  return nil
end

--- Whether our picker session is still open: the picker is on screen and was last opened by us.
--- A session the picker has closed (Okay hides it after its last swatchFunc) is forgotten here.
function Options.PickerActive()
  if not Options.picker then
    return false
  end
  local picker = rawget(_G, "ColorPickerFrame")
  if type(picker) == "table" and call(picker, "IsShown") then
    return true
  end
  Options.picker = nil
  return false
end

--- The info table the picker is opened with: the stored colour, no opacity, and our two
--- callbacks for this session. A plain table of ours; the picker copies what it needs. Pure,
--- apart from what the callbacks do when the picker calls them.
function Options.PickerInfo(session, readColour)
  local pair = pairOf(session)
  local start = Options.CustomColour(session and session.custom, pair.fallbackToken)
  return {
    r = start.r,
    g = start.g,
    b = start.b,
    hasOpacity = false,
    swatchFunc = function()
      if Options.picker ~= session then
        return
      end
      local ok, r, g, b = pcall(readColour)
      if ok and tonumber(r) and tonumber(g) and tonumber(b) then
        Options.ApplyPickedColour(r, g, b, pair)
      end
    end,
    cancelFunc = function()
      if Options.picker ~= session then
        return
      end
      Options.CancelPickedColour(session)
    end,
  }
end

--- Opens the client's colour picker on the stored custom colour (a Custom row's click). colorKey
--- and customKey name the pair it writes (brief K16): keepColor and keepColorCustom where they are
--- left out. The Settings example is held up while the picker is open (Preview.PickerOpen).
--- Answers whether the picker opened; a client without it does nothing.
function Options.OpenColourPicker(colorKey, customKey)
  local pair = Options.ColourPair(customKey or colorKey) or Options.COLOUR_PAIRS[1]
  if (colorKey and colorKey ~= pair.colorKey) or (customKey and customKey ~= pair.customKey) then
    return false
  end
  local picker = colourPicker()
  local settings = writableSettings()
  if not picker or not settings then
    return false
  end
  local session = {
    colour = settings[pair.colorKey],
    custom = Options.CustomColour(settings[pair.customKey], pair.fallbackToken),
    pair = pair,
  }
  Options.picker = session
  local info = Options.PickerInfo(session, function()
    return picker:GetColorRGB()
  end)
  if not pcall(picker.SetupColorPickerAndShow, picker, info) then
    Options.picker = nil
    return false
  end
  local preview = ItemTree.UI and ItemTree.UI.OptionsPreview
  if preview and type(preview.PickerOpen) == "function" then
    pcall(preview.PickerOpen, pair.customKey, true)
  end
  return true
end

local function buildSwatch(content, spec)
  local create = rawget(_G, "CreateSettingsButtonInitializer")
  if type(create) ~= "function" then
    return nil
  end
  local pair = pairOf(spec)
  local label, buttonText = pair.customLabel, L["Choose colour"]
  local function swatchClick()
    pcall(Options.OpenColourPicker, pair.colorKey, pair.customKey)
  end
  -- The fifth argument is whether the row adds search tags, as on the Reset position rows.
  local ok, initializer = pcall(create, label, buttonText, swatchClick, pair.customTooltip, false)
  if not ok or type(initializer) ~= "table" then
    return nil
  end
  initializer.itemTreeRow = spec.key
  local child = linkDependents(initializer, spec) and Options.dependencies[spec.key].indented or false
  attachPreview(initializer, { key = spec.key, kind = "button" })
  local record = templatedRow(
    content,
    initializer,
    templateOf(initializer, Options.TEMPLATES.button),
    "swatch",
    spec.key,
    Options.ROW_H,
    child
  )
  if record then
    record.frame.itemTreeSwatchSpec = spec
    record.swatch = buildSwatchTexture(record.frame)
    paintSwatch(record.frame)
    -- Brief K16: one record a pair, by its custom key; swatchRow stays the Colour pair's.
    Options.swatchRows = Options.swatchRows or {}
    Options.swatchRows[spec.key] =
      { route = "button", label = label, buttonText = buttonText, initializer = initializer }
    if spec.key == Options.COLOUR_PAIRS[1].customKey then
      Options.swatchRow = Options.swatchRows[spec.key]
    end
  end
  return record
end

-- Brief K20c: writes the formula the box holds, as typed, and lets everything that reads it know.
-- The text is cut at Core/PriceFormula.lua's MAX_LENGTH. A formula that is not understood is
-- stored all the same; the note under the box says so.
function Options.SaveFormula(text)
  local settings = ItemTree.db and ItemTree.db.settings
  if type(settings) ~= "table" then
    return false
  end
  text = type(text) == "string" and text or ""
  local formula = ItemTree.PriceFormula
  local limit = type(formula) == "table" and tonumber(formula.MAX_LENGTH) or 400
  if #text > limit then
    text = text:sub(1, limit)
  end
  if settings.keepSellFormula == text then
    return true
  end
  settings.keepSellFormula = text
  Options.OnChanged("keepSellFormula", text)
  return true
end

-- Brief K20c: the formula row, a label and an edit box of our own on our own row frame. Its
-- scripts are ours on our own box: Enter and leaving the box store the text, Escape puts the
-- stored text back. SetAutoFocus false, so showing the page never focuses it.
local function buildFormulaRow(content, spec)
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local label = newFontString(frame, "OVERLAY", "GameFontNormal")
  if label then
    call(label, "SetPoint", "LEFT", frame, "LEFT", Options.ROW_LABEL_INSET + Options.ROW_INDENT, 0)
    setText(label, L["Formula"])
  end
  local box = newFrame("EditBox", frame, Options.TEMPLATES.editBox) or newFrame("EditBox", frame)
  if box then
    call(box, "SetAutoFocus", false)
    local formula = ItemTree.PriceFormula
    call(box, "SetMaxLetters", type(formula) == "table" and tonumber(formula.MAX_LENGTH) or 400)
    call(box, "SetSize", Options.FORMULA_BOX_WIDTH, Options.FORMULA_BOX_HEIGHT)
    call(box, "SetPoint", "LEFT", frame, "CENTER", -80, 0)
    call(box, "SetScript", "OnEnterPressed", function(self)
      Options.SaveFormula(call(self, "GetText"))
      call(self, "ClearFocus")
    end)
    call(box, "SetScript", "OnEscapePressed", function(self)
      call(self, "SetText", Options.Get(spec.key) or "")
      call(self, "ClearFocus")
    end)
    call(box, "SetScript", "OnEditFocusLost", function(self)
      Options.SaveFormula(call(self, "GetText"))
    end)
    call(box, "SetText", Options.Get(spec.key) or "")
    -- Brief K24b (F1): the grey example inside the empty box, gone while there is text in it. A
    -- font string of ours on our own box; the box's own text change is heard through HookScript.
    local example = newFontString(box, "ARTWORK", "GameFontDisable")
    if example then
      call(example, "SetPoint", "LEFT", box, "LEFT", 6, 0)
      setText(example, Options.FormulaExample())
      local theme = ItemTree.Theme
      if type(theme) == "table" and type(theme.ColorTable) == "function" then
        local ok, colour = pcall(theme.ColorTable, "ITEMTREE_COLOR_TEXT_MUTED")
        if ok and type(colour) == "table" then
          call(example, "SetTextColor", colour.r, colour.g, colour.b)
        end
      end
      local function showExample(self)
        local text = call(self, "GetText")
        showRegion(example, type(text) ~= "string" or text == "")
      end
      if type(box.HookScript) == "function" then
        pcall(box.HookScript, box, "OnTextChanged", showExample)
      end
      showExample(box)
    end
    box.itemTreeExample = example
  end
  -- Brief K24b (F3): the hover on the row with the full list and two worked examples.
  frame.itemTreeLines = Options.FormulaHoverLines
  call(frame, "EnableMouse", true)
  call(frame, "SetScript", "OnEnter", showRowTooltip)
  call(frame, "SetScript", "OnLeave", hideTooltip)
  return { kind = "formula", key = spec.key, frame = frame, height = Options.ROW_H, box = box, label = label }
end

-- Brief K24b (F2): the muted help line under the formula box.
local function buildFormulaHelp(content, spec)
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local help = newFontString(frame, "OVERLAY", "GameFontHighlightSmall")
  if help then
    call(help, "SetPoint", "LEFT", frame, "LEFT", Options.ROW_LABEL_INSET + Options.ROW_INDENT, 0)
    call(help, "SetPoint", "RIGHT", frame, "RIGHT", -Options.ROW_LABEL_INSET, 0)
    call(help, "SetJustifyH", "LEFT")
    setText(help, Options.FormulaHelpText())
    local theme = ItemTree.Theme
    if type(theme) == "table" and type(theme.ColorTable) == "function" then
      local ok, colour = pcall(theme.ColorTable, "ITEMTREE_COLOR_TEXT_MUTED")
      if ok and type(colour) == "table" then
        call(help, "SetTextColor", colour.r, colour.g, colour.b)
      end
    end
  end
  return { kind = "formulaHelp", key = spec.key, frame = frame, height = Options.ROW_H, help = help }
end

-- Brief K20c: the muted note under the formula row. Brief K24b (F4): "Formula not understood: <the
-- reason> at character N, using 1.5 x vendor" (Options.FormulaNoteText), set again on every refresh.
local function buildFormulaNote(content, spec)
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local note = newFontString(frame, "OVERLAY", "GameFontHighlightSmall")
  if note then
    call(note, "SetPoint", "LEFT", frame, "CENTER", -80, 0)
    setText(note, Options.FormulaNoteText() or "")
    local theme = ItemTree.Theme
    if type(theme) == "table" and type(theme.ColorTable) == "function" then
      local ok, colour = pcall(theme.ColorTable, "ITEMTREE_COLOR_TEXT_MUTED")
      if ok and type(colour) == "table" then
        call(note, "SetTextColor", colour.r, colour.g, colour.b)
      end
    end
  end
  return { kind = "formulaNote", key = spec.key, frame = frame, height = Options.ROW_H, note = note }
end

-- Brief K20c: shows the formula row and its note as the settings say (Options.FormulaRowsShown),
-- puts the stored formula in the box where the player is not typing in it, greys the box with
-- Keep marks, and lays the page out again. A page that was never built is left alone.
function Options.RefreshFormulaRows()
  local canvas = Options.canvas
  if not canvas or not canvas.rows then
    return false
  end
  local row, note = Options.FormulaRowsShown()
  for _, record in ipairs(canvas.rows) do
    if record.kind == "formula" then
      record.hidden = not row
      if record.box and not call(record.box, "HasFocus") then
        call(record.box, "SetText", Options.Get(record.key) or "")
      end
      if record.box then
        call(record.box, "SetEnabled", Options.DependsMet({ dependsOn = { "keepMarks" } }) and true or false)
      end
    elseif record.kind == "formulaHelp" then
      record.hidden = not row
    elseif record.kind == "formulaNote" then
      record.hidden = not note
      if note and record.note then
        setText(record.note, Options.FormulaNoteText() or "")
      end
    end
  end
  Options.LayoutRows()
  return true
end

-- Brief ST3 (QA item 317): a small sub heading inside a section ("Where"), at the row labels'
-- inset, sitting low on its short row so it reads with the rows under it.
local function buildSubheading(content, spec)
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local text = newFontString(frame, "OVERLAY", Options.SUBHEADING_FONT)
  if text then
    call(text, "SetPoint", "BOTTOMLEFT", frame, "BOTTOMLEFT", Options.ROW_LABEL_INSET, 0)
    call(text, "SetJustifyH", "LEFT")
    setText(text, spec.label)
  end
  return { kind = "subheading", key = spec.key, frame = frame, height = Options.SUBHEADING_H, text = text }
end

local function buildLogoRow(content)
  local frame = newFrame("Frame", content)
  if not frame then
    return nil
  end
  local builtOk, texture = pcall(buildLogo, frame)
  if not builtOk or not texture then
    showRegion(frame, false)
    return nil
  end
  Options.logo = { route = "canvas", height = Options.LOGO_HEIGHT, extent = Options.LOGO_ROW_EXTENT }
  return { kind = "logo", key = "logo", frame = frame, height = Options.LOGO_ROW_EXTENT }
end

--------------------------------------------------------------------------------
-- The page frame: the header strip, the scroll frame and its bar, then the rows.
--------------------------------------------------------------------------------

-- The client's own word for Defaults where it has one, ours otherwise.
local function defaultsText()
  local word = rawget(_G, "SETTINGS_DEFAULTS")
  if type(word) == "string" and word ~= "" then
    return word
  end
  return L["Defaults"]
end

local function now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and type(value) == "number" then
      return value
    end
  end
  local clock = rawget(_G, "time")
  if type(clock) ~= "function" then
    local osLib = rawget(_G, "os")
    clock = type(osLib) == "table" and osLib.time or nil
  end
  if type(clock) == "function" then
    local ok, value = pcall(clock)
    if ok and type(value) == "number" then
      return value
    end
  end
  return 0
end

local function disarmDefaults(button)
  button.itemTreeArmedAt = nil
  call(button, "SetText", defaultsText())
end

-- The client's Defaults asks first, in a popup of its own; ours asks by taking a second click
-- within Options.DEFAULTS_CONFIRM_SECONDS, the button saying so in between. at is the time, for
-- the specs. Answers "armed", "reset" or nil.
function Options.DefaultsClick(button, at)
  if type(button) ~= "table" then
    return nil
  end
  at = tonumber(at) or now()
  local armed = button.itemTreeArmedAt
  if armed and at - armed <= Options.DEFAULTS_CONFIRM_SECONDS then
    disarmDefaults(button)
    Options.ResetToDefaults()
    return "reset"
  end
  button.itemTreeArmedAt = at
  call(button, "SetText", L["Click again"])
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    pcall(timer.After, Options.DEFAULTS_CONFIRM_SECONDS, function()
      if button.itemTreeArmedAt == at then
        disarmDefaults(button)
      end
    end)
  end
  return "armed"
end

local function showDefaultsTooltip(button)
  local tooltip = settingsTooltip()
  if not tooltip then
    return
  end
  tooltip:SetOwner(button, "ANCHOR_RIGHT")
  tooltip:AddLine(defaultsText())
  tooltip:AddLine(L["Puts every ItemTree setting on this page back to its default. Click twice to confirm."], 1, 1, 1)
  tooltip:Show()
end

-- Brief E94: the header strip the client's list draws above its rows, drawn again on ours, since
-- a canvas takes the list's place and the list's header with it.
local function buildHeaderStrip(canvas)
  local parts = {}
  parts.title = newFontString(canvas, "ARTWORK", Options.CANVAS_TITLE_FONT)
  if parts.title then
    call(parts.title, "SetPoint", "TOPLEFT", canvas, "TOPLEFT", Options.CANVAS_TITLE_X, Options.CANVAS_TITLE_Y)
    call(parts.title, "SetJustifyH", "LEFT")
    setText(parts.title, L[Options.CATEGORY_NAME])
  end
  local assets = ItemTree.Assets
  if assets and type(assets.Has) == "function" and assets.Has("OPTIONS_DIVIDER") then
    local made, divider = pcall(canvas.CreateTexture, canvas, nil, "ARTWORK")
    if made and type(divider) == "table" then
      local applied, drawn = pcall(assets.Apply, divider, "OPTIONS_DIVIDER", true)
      if applied and drawn ~= false then
        call(divider, "SetPoint", "TOP", canvas, "TOP", 0, -Options.CANVAS_HEADER_H)
        parts.divider = divider
      else
        call(divider, "Hide")
      end
    end
  end
  local button = newFrame("Button", canvas, Options.TEMPLATES.panelButton)
  if button then
    call(button, "SetSize", Options.CANVAS_DEFAULTS_W, Options.CANVAS_DEFAULTS_H)
    call(button, "SetPoint", "TOPRIGHT", canvas, "TOPRIGHT", Options.CANVAS_DEFAULTS_X, Options.CANVAS_DEFAULTS_Y)
    call(button, "SetText", defaultsText())
    call(button, "SetScript", "OnClick", function(self)
      Options.DefaultsClick(self)
    end)
    call(button, "SetScript", "OnEnter", showDefaultsTooltip)
    call(button, "SetScript", "OnLeave", hideTooltip)
    parts.defaults = button
  end
  return parts
end

-- The scroll frame the rows sit in, where the client's list puts its scroll box, and the
-- client's MinimalScrollBar beside it, wired through ScrollUtil.InitScrollFrameWithScrollBar,
-- which sets scripts on the two frames it is handed and nothing else. The bar shows only while
-- there is something to scroll, as the list's does. Without a scroll frame the rows sit on the
-- page itself.
local function buildScroll(canvas, parts)
  local scroll = newFrame("ScrollFrame", canvas)
  if not scroll then
    return canvas
  end
  call(
    scroll,
    "SetPoint",
    "TOPLEFT",
    canvas,
    "TOPLEFT",
    Options.CANVAS_LIST_X,
    -Options.CANVAS_HEADER_H + Options.CANVAS_LIST_Y
  )
  call(scroll, "SetPoint", "BOTTOMRIGHT", canvas, "BOTTOMRIGHT", Options.CANVAS_LIST_RIGHT, Options.CANVAS_LIST_BOTTOM)
  local content = newFrame("Frame", scroll)
  if not content then
    return canvas
  end
  call(content, "SetSize", 1, 1)
  call(scroll, "SetScrollChild", content)
  call(scroll, "SetScript", "OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then
      call(content, "SetWidth", width)
    end
  end)
  parts.scroll, parts.content = scroll, content
  local bar = newFrame("EventFrame", canvas, Options.TEMPLATES.scrollBar)
  local util = rawget(_G, "ScrollUtil")
  if
    bar
    and type(util) == "table"
    and type(util.InitScrollFrameWithScrollBar) == "function"
    and pcall(util.InitScrollFrameWithScrollBar, scroll, bar)
  then
    call(bar, "SetPoint", "TOPLEFT", scroll, "TOPRIGHT", 0, Options.SCROLLBAR_TOP)
    call(bar, "SetPoint", "BOTTOMLEFT", scroll, "BOTTOMRIGHT", -1, Options.SCROLLBAR_BOTTOM)
    if type(scroll.HookScript) == "function" then
      pcall(scroll.HookScript, scroll, "OnScrollRangeChanged", function(_, _, range)
        showRegion(bar, (tonumber(range) or 0) > 0)
      end)
    end
    parts.bar = bar
  else
    -- No client bar: the wheel still scrolls the list.
    showRegion(bar, false)
    call(scroll, "EnableMouseWheel", true)
    call(scroll, "SetScript", "OnMouseWheel", function(self, delta)
      local range = tonumber(call(self, "GetVerticalScrollRange")) or 0
      local offset = (tonumber(call(self, "GetVerticalScroll")) or 0) - (tonumber(delta) or 0) * 30
      call(self, "SetVerticalScroll", math.max(0, math.min(range, offset)))
    end)
  end
  return content
end

-- Places every drawn row down the list, the database rows expanded in their place, and sizes the
-- list to hold them.
local function layoutRows()
  local canvas = Options.canvas
  if not canvas or not canvas.rows then
    return 0
  end
  local content = canvas.content or canvas.frame
  local placed = {}
  for _, record in ipairs(canvas.rows) do
    if record.kind == "providers" then
      for _, frame in ipairs(syncProviderRows(content)) do
        placed[#placed + 1] = { frame = frame, height = Options.PROVIDER_ROW_H }
      end
    elseif record.frame and record.hidden then
      -- Brief K20c: a row the settings hide (the formula row away from Formula) takes no space.
      showRegion(record.frame, false)
    elseif record.frame then
      placed[#placed + 1] = record
    end
  end
  local heights = {}
  for index, item in ipairs(placed) do
    heights[index] = item.height
  end
  local offsets, total = Options.StackOffsets(heights)
  for index, item in ipairs(placed) do
    local frame = item.frame
    call(frame, "ClearAllPoints")
    call(frame, "SetPoint", "TOPLEFT", content, "TOPLEFT", Options.CANVAS_PAD_LEFT, -offsets[index])
    call(frame, "SetPoint", "TOPRIGHT", content, "TOPRIGHT", 0, -offsets[index])
    call(frame, "SetHeight", item.height)
    showRegion(frame, true)
  end
  if content ~= canvas.frame then
    call(content, "SetHeight", total)
  end
  canvas.placed = #placed
  return total
end

-- Brief K20c: the layout, for Options.RefreshFormulaRows above it in the file.
Options.LayoutRows = layoutRows

--- Draws every row onto the page, once; answers the rows drawn. Brief TX1: called from
--- Options.Install at login, while the page is hidden and has no parent, never from the page's
--- OnShow. With the gamepad UI on, the client's SmartNavigation post hooks CreateFrame and, for a
--- frame whose parent sits inside an open panel, rebuilds that panel's navigation state from the
--- caller's code (Blizzard_GamepadSmartNavigation/SmartNavigation.lua SetupFrameHooks, branch
--- forever). Building the rows inside the open settings panel left that state tainted by ItemTree,
--- and the panel's close then had the protected SetPreferredGamepadInteractTarget refused.
function Options.BuildCanvas()
  local canvas = Options.canvas
  if not canvas then
    return nil
  end
  if canvas.rows then
    return canvas.rows
  end
  local Settings = canvas.settingsApi or rawget(_G, "Settings") or EMPTY
  local content = canvas.content or canvas.frame
  local rows = {}
  canvas.rows = rows
  Options.sections = {}
  local headerPrefix
  for _, row in ipairs(Options.CanvasRows()) do
    local record
    if row.kind == "logo" then
      record = buildLogoRow(content)
      if not record then
        headerPrefix = logoMarkup()
      end
    elseif row.kind == "header" then
      record = buildHeader(content, row.section, headerPrefix)
      if record then
        Options.sections[#Options.sections + 1] = row.section
        if headerPrefix then
          Options.logo = { route = "header" }
          headerPrefix = nil
        end
      end
    elseif row.kind == "control" then
      record = buildControl(Settings, content, row.def)
    elseif row.kind == "keybind" then
      record = buildKeyRow(content, row.which)
    elseif row.kind == "reset" then
      record = buildReset(content, row.spec)
    elseif row.kind == "swatch" then
      record = buildSwatch(content, row.spec)
    elseif row.kind == "formula" then
      record = buildFormulaRow(content, row.spec)
    elseif row.kind == "formulaHelp" then
      record = buildFormulaHelp(content, row.spec)
    elseif row.kind == "formulaNote" then
      record = buildFormulaNote(content, row.spec)
    elseif row.kind == "subheading" then
      record = buildSubheading(content, row.spec)
    elseif row.kind == "providers" then
      record = { kind = "providers", key = "providers" }
    end
    if record then
      rows[#rows + 1] = record
    end
  end
  -- Brief K20c: the formula rows start shown or hidden as the settings say.
  Options.RefreshFormulaRows()
  return rows
end

--- The drawn row for a setting key, a reset row's key, a section name, "main" or "boss" for the
--- key rows, or "logo". nil before the page is built.
function Options.CanvasRow(key)
  local canvas = Options.canvas
  for _, record in ipairs(canvas and canvas.rows or EMPTY) do
    if record.key == key then
      return record
    end
  end
  return nil
end

--- Reads every row again, the way the client's list does each time it shows a category: the
--- client's rows are released and initialised afresh, so a setting changed anywhere else (the
--- window's footer, a slash command) is what the page shows; the key buttons, the database rows
--- and the layout follow. A page that was never built is left alone.
function Options.RefreshCanvas()
  local canvas = Options.canvas
  if not canvas then
    return false
  end
  -- Brief TX1: never built here. This runs from the page's OnShow, inside the client's open
  -- settings panel; Options.Install builds the rows at login.
  if not canvas.rows then
    return false
  end
  for _, record in ipairs(canvas.rows) do
    if record.initializer then
      releaseRow(record)
      initRow(record)
    end
  end
  Options.RefreshKeybind()
  pcall(Options.RefreshSwatches)
  -- Brief K20c: the formula rows as the settings say, then the layout.
  if not pcall(Options.RefreshFormulaRows) then
    layoutRows()
  end
  return true
end

--------------------------------------------------------------------------------
-- The category.
--------------------------------------------------------------------------------

-- Registers every setting on the page with the client, as before: the client's Defaults for all
-- settings, Settings.GetValue and the value changed callbacks all go through these.
local function registerAll(Settings, category)
  Options.settingObjects = {}
  for _, def in ipairs(Options.ControlDefinitions()) do
    local setting, viaProxy = registerSetting(Settings, category, def)
    if setting then
      Options.settingObjects[def.key] = setting
      -- A setting registered with the backing table writes the value and says nothing, so the
      -- live surfaces would not catch up until a reload. The proxy setter already calls
      -- OnChanged, so it is left alone rather than firing twice.
      if not viaProxy and type(Settings.SetOnValueChangedCallback) == "function" then
        pcall(Settings.SetOnValueChangedCallback, "ITEMTREE_" .. def.key, function(_, _setting, value)
          Options.OnChanged(def.key, value)
        end)
      end
    end
  end
end

-- The page frame, parented by the client when it shows the category. Its OnShow reads every row
-- again, which is our script on our frame; it defines none of OnCommit, OnDefault or OnRefresh,
-- the fields the client's panel reads off a canvas.
local function buildPage()
  local frame = newFrame("Frame", nil)
  if not frame then
    return nil
  end
  call(frame, "Hide")
  local parts = buildHeaderStrip(frame)
  parts.frame = frame
  buildScroll(frame, parts)
  call(frame, "SetScript", "OnShow", function()
    Options.RefreshCanvas()
  end)
  return parts
end

-- Builds the category. Idempotent; returns the category or nil outside the client.
function Options.Install()
  if Options.category then
    return Options.category
  end
  local Settings = rawget(_G, "Settings")
  if type(Settings) ~= "table" then
    return nil
  end
  -- Brief E94: a canvas or nothing. A client without the canvas call gets no settings page (and
  -- /itemtree config says so), never the vertical list the game's settings search taints through.
  if type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
    return nil
  end
  if not (ItemTree.db and ItemTree.db.settings) then
    return nil
  end
  Options.keybind = nil
  Options.bossLootKeybind = nil
  Options.logo = nil
  Options.hudReset = nil
  Options.minimapReset = nil
  Options.bossLootMinimapReset = nil
  Options.providerRows = nil
  Options.swatchRows = nil
  Options.dependencies = {}
  Options.childMarkers = {}
  Options.sections = {}
  Options.canvas = nil
  -- Rows of a page built before belong to that page, not this one.
  providerFrames = {}
  local parts = buildPage()
  if not parts then
    return nil
  end
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, parts.frame, L[Options.CATEGORY_NAME])
  if not ok or not category then
    return nil
  end
  parts.settingsApi = Settings
  Options.canvas = parts
  registerAll(Settings, category)
  -- Brief TX1: every row is made now, while the page is hidden and outside the settings panel,
  -- so no frame of ours is ever created with a parent inside the open panel. See BuildCanvas.
  Options.BuildCanvas()
  if type(Settings.RegisterAddOnCategory) == "function" then
    pcall(Settings.RegisterAddOnCategory, category)
  end
  Options.category = category
  if type(category.GetID) == "function" then
    Options.categoryId = category:GetID()
  else
    Options.categoryId = category.ID or category
  end
  return category
end

function Options.Open()
  local Settings = rawget(_G, "Settings")
  if not Settings or type(Settings.OpenToCategory) ~= "function" then
    return false
  end
  -- Brief E91: the client refuses to show the settings panel in combat (ShowUIPanel returns
  -- early and says an action was blocked), so the request waits for combat to end. It is taken,
  -- so the caller does not fall back to something else, and silent until the panel really opens.
  local Frame = windowFrame()
  if Frame and inCombat() then
    Frame.AfterCombat(Options.Open, "Options.Open")
    return true
  end
  if not Options.category then
    Options.Install()
  end
  local id = Options.categoryId or Options.category
  if not id then
    return false
  end
  Settings.OpenToCategory(id)
  -- The settings page is a window opening, so it gets the same cue the main window does. Here
  -- rather than in UI/Frame.lua's footer button, because the minimap button and /itemtree
  -- options both reach the page through UI/Slash.lua, which calls this directly.
  playCue("open")
  return true
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local loader = createFrame("Frame")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function(self)
    Options.Install()
    self:UnregisterEvent("PLAYER_LOGIN")
  end)
end

return Options
