-- English (Australian spelling). Other locales copy this file and override keys.
-- Voice follows the design system: terse, sentence case, one line per fact, no dashes.
--
-- Grouped by the module that draws the string. Most are written as L["..."] where they are
-- used; the rest reach L through a variable, which is a tab name, a slot number, an edge
-- trigger or a settings key, so the comment over those blocks names the table that holds
-- them. tests/spec/locale_spec.lua checks both kinds, and fails both on a string with no
-- entry and on an entry nothing says any more.
local _, ItemTree = ...

local L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})
ItemTree.L = L

-- Core/Graph.lua, Core/Collector.lua and Core/ViewModel.lua: the group an edge is filed under,
-- which is also the category label in the tree and in the sidebar, and the requirement lines an
-- item's own record states.
L["Quests"] = "Quests"
L["Requirements"] = "Requirements"
L["Reagents"] = "Reagents"
L["Item set"] = "Item set"
L["Community"] = "Community"
L["Disenchants into"] = "Disenchants into"
L["Disenchanted from"] = "Disenchanted from"
L["Sold by"] = "Sold by"
L["Drops from"] = "Drops from"
L["Gathered from"] = "Gathered from"
L["Fished from"] = "Fished from"
L["Contained in"] = "Contained in"
L["Contains"] = "Contains"
L["Opens"] = "Opens"
L["Opened by"] = "Opened by"
L["Teaches"] = "Teaches"
L["Taught by"] = "Taught by"
L["Tool for"] = "Tool for"
L["Level %d"] = "Level %d"
-- Core/Quests.lua and the two provider adapters, on a quest node rather than an item: what the
-- turn in asks for, what it hands back and the item that starts it. "Requires" is the edge
-- wording further down and is shared deliberately; the other two are their own.
L["Rewards"] = "Rewards"
L["Started by"] = "Started by"

-- Core/Graph.lua: what kind of thing a node is, for a title that is not an item's own name
-- ("Spell: Old Blade (200)"), and for a node nothing on this client can name ("Creature 448").
-- Core/Sources.lua names the Quest source column with the same word.
L["Item"] = "Item"
L["Spell"] = "Spell"
L["Skill"] = "Skill"
L["Set"] = "Set"
L["Enchant"] = "Enchant"
L["Quest"] = "Quest"
L["Creature"] = "Creature"
L["Object"] = "Object"
L["Zone"] = "Zone"
L["%s: %s (%d)"] = "%s: %s (%d)"

-- Core/Edges.lua: the words for one edge, which Edges.Label answers with. A breadcrumb, a
-- chain step and a category all read them, so an edge is worded in exactly one place. The
-- groups above are the wider heading a row is filed under and are deliberately not the same
-- words: an edge is "Dropped by", the category it lands in is "Drops from". USED_BY_SPELL is
-- worded "Used by", which is also the direction tab further down, and REQUIRES_SKILL is
-- worded "Requires", which is also the info column's own requirements heading.
L["Reagent for"] = "Reagent for"
L["Produced by"] = "Produced by"
L["Creates"] = "Creates"
L["Requires tool"] = "Requires tool"
L["Enchants"] = "Enchants"
L["Prospects into"] = "Prospects into"
L["Mills into"] = "Mills into"
L["Starts quest"] = "Starts quest"
L["Quest objective"] = "Quest objective"
L["Quest reward"] = "Quest reward"
L["Provided by quest"] = "Provided by quest"
L["Dropped by"] = "Dropped by"
L["Looted from"] = "Looted from"
L["Skinned from"] = "Skinned from"
L["Profession"] = "Profession"
L["Part of set"] = "Part of set"
L["Set member"] = "Set member"
L["Reagent"] = "Reagent"
L["Trainer"] = "Trainer"

-- Core/Confidence.lua: how well known a fact is, with the build stamp a verified one carries.
-- The other tiers are the badge words further down.
L["Verified by collector"] = "Verified by collector"
L["From client data"] = "From client data"
L["%s, build %s"] = "%s, build %s"
-- A drop rate a provider states as a rounded number rather than a count of sightings, wrapped
-- so the row cannot read as though it were measured here.
L["about %s"] = "about %s"

-- Core/ViewModel.lua: the notice rows the design draws above a group, and the line a view with
-- nothing in it carries, one per tab (EMPTY_TEXT). The sources line is the heading of the
-- designed empty block UI/Tree.lua draws over that view, as one sentence (brief E1).
L["No known uses"] = "No known uses"
L["No data for this item yet."] = "No data for this item yet."
L["Nothing is required"] = "Nothing is required"
L["Drop data is from Classic Era. Forever drop rates are not yet known."] =
  "Drop data is from Classic Era. Forever drop rates are not yet known."
L["Quest data is imported baseline data. Forever turn-ins are not yet confirmed."] =
  "Quest data is imported baseline data. Forever turn-ins are not yet confirmed."
L["Predicted from item level and quality. Confirmed results replace predictions as they are seen."] =
  "Predicted from item level and quality. Confirmed results replace predictions as they are seen."

-- Core/Diff.lua: the field a change row names, through Diff.FieldLabel, and the change wording
-- itself. UI/InfoPanel.lua draws several of the same words as fact labels. "%s [%s]" puts the
-- ids on a change whose two sides would otherwise read the same.
L["Name"] = "Name"
L["Quality"] = "Quality"
L["Item level"] = "Item level"
L["Required level"] = "Required level"
L["Required skill"] = "Required skill"
L["Skill level"] = "Skill level"
L["Races"] = "Races"
L["Buy price"] = "Buy price"
L["Bonding"] = "Bonding"
L["Item class"] = "Item class"
L["Item subclass"] = "Item subclass"
L["Lock"] = "Lock"
L["Slots"] = "Slots"
L["Bag type"] = "Bag type"
L["Tool category"] = "Tool category"
L["Icon"] = "Icon"
L["Trivial low"] = "Trivial low"
L["Trivial high"] = "Trivial high"
L["Skill ups"] = "Skill ups"
L["Supercedes"] = "Supercedes"
L["Cooldown"] = "Cooldown"
L["Shared cooldown"] = "Shared cooldown"
L["Tool items"] = "Tool items"
L["Category"] = "Category"
L["Parent"] = "Parent"
L["%s to %s"] = "%s to %s"
L["%s [%s]"] = "%s [%s]"
-- The clauses Diff.EffectText hangs off an item effect, lower case because each follows the
-- effect's own sentence.
L["1 charge"] = "1 charge"
L["%d charges"] = "%d charges"
L["cooldown %s"] = "cooldown %s"
L["shared cooldown %s"] = "shared cooldown %s"
-- One entry of a list field that gained or lost a member, written per entry rather than as a
-- whole new list. Core/Diff.lua words it; UI/Badges.lua, UI/Tree.lua and UI/InfoPanel.lua draw
-- the same two wordings.
L["%s added"] = "%s added"
L["%s removed"] = "%s removed"
L["Compared with Classic Era"] = "Compared with Classic Era"
L["No comparison build loaded"] = "No comparison build loaded"

-- What sets an item effect off, from the first number of an fx entry. Diff.EffectTrigger
-- names the code and UI/InfoPanel.lua draws the word; a trigger with no name of its own
-- reads as the plain word Effect.
L["Use"] = "Use"
L["Equip"] = "Equip"
L["Chance on hit"] = "Chance on hit"
L["Soulstone"] = "Soulstone"
L["Learn"] = "Learn"
L["Effect"] = "Effect"

-- Core/Chain.lua: what a chain step says about the reagents and tools it does not draw.
-- UI/InfoPanel.lua writes a requirement line with the same wording.
-- "+" rather than "plus": it reads as the recipe's own arithmetic and leaves the control room
-- for the count at the width of one chain slot. A quest has no reagents, so its stages count
-- items instead.
L["+ 1 other reagent"] = "+ 1 other reagent"
L["+ %d other reagents"] = "+ %d other reagents"
L["+ 1 other item"] = "+ 1 other item"
L["+ %d other items"] = "+ %d other items"
L["Requires %s"] = "Requires %s"

-- Core/Sources.lua: the type column and the filter chips, from Sources.TYPES, which
-- Core/ViewModel.lua hangs on a row walking up and UI/Tree.lua draws.
L["Recipe"] = "Recipe"
L["Key"] = "Key"
L["Drop"] = "Drop"
L["Vendor"] = "Vendor"
L["Gather"] = "Gather"
L["Fished"] = "Fished"
L["Contained"] = "Contained"
-- Sources.PROVENANCE: which installed addon a source row was read out of, drawn beside the row
-- so nothing a provider says is mistaken for something ItemTree ships.
L["via All The Things"] = "via All The Things"
L["via Questie"] = "via Questie"

-- UI/Badges.lua: one word per badge (Badges.TITLE), the sentence each mark means in a list
-- tooltip (Badges.LIST_MEANING, which UI/Sidebar.lua reads), and the line that counts the
-- changes a hovered Changed badge had no room for.
L["New"] = "New"
L["Changed"] = "Changed"
L["Removed"] = "Removed"
L["Predicted"] = "Predicted"
L["Unverified"] = "Unverified"
L["Verified"] = "Verified"
L["Community note"] = "Community note"
L["New in Forever"] = "New in Forever"
L["Changed in Forever"] = "Changed in Forever"
L["Removed in Forever"] = "Removed in Forever"
L["Predicted data, not yet confirmed"] = "Predicted data, not yet confirmed"
L["Imported baseline, unverified"] = "Imported baseline, unverified"
L["Verified by the collector"] = "Verified by the collector"
L["and %d more"] = "and %d more"

-- UI/Tooltip.lua: the block under an item name in the client's own tooltip. The counted lines
-- are picked a pair at a time by Tooltip.UsesText, one wording for one and one for more. The
-- hint line names the click shortcut, the bound key, or both.
L["Not in ItemTree data"] = "Not in ItemTree data"
L["Used in %d recipe"] = "Used in %d recipe"
L["Used in %d recipes"] = "Used in %d recipes"
L["%d quest"] = "%d quest"
L["%d quests"] = "%d quests"
L["Teaches %d recipe"] = "Teaches %d recipe"
L["Teaches %d recipes"] = "Teaches %d recipes"
L["Made by %d recipe"] = "Made by %d recipe"
L["Made by %d recipes"] = "Made by %d recipes"
L["Tool for %d recipe"] = "Tool for %d recipe"
L["Tool for %d recipes"] = "Tool for %d recipes"
L["Press %s for the full tree"] = "Press %s for the full tree"
L["%s for the full tree"] = "%s for the full tree"
L["%s or %s for the full tree"] = "%s or %s for the full tree"
L["Set a key in ItemTree settings to open the full tree"] = "Set a key in ItemTree settings to open the full tree"

-- Providers/AllTheThings.lua and Providers/Questie.lua: the name of a source database the
-- player has installed, through adapter.label, which Providers/Registry.lua draws. The addon's
-- own name is not translated, so a locale leaves these alone.
L["All The Things"] = "All The Things"
L["Questie"] = "Questie"

-- UI/Options.lua: the settings panel. Options.CATEGORY_NAME, the section headers in
-- Options.SECTIONS and the label and tooltip on every entry of its ORDER table all reach L
-- through a variable. The section headers are in the design's order (ScreensOther.jsx).
L["ItemTree"] = "ItemTree"
L["Display"] = "Display"
L["Data confidence"] = "Data confidence"
L["Fixed position tooltip"] = "Fixed position tooltip"
L["Compact rows"] = "Compact rows"
L["Compare against"] = "Compare against"
L["Window scale"] = "Window scale"
L["1x fits the window to about two thirds of your screen."] = "1x fits the window to about two thirds of your screen."
L["Show New badges"] = "Show New badges"
L["Show Changed badges"] = "Show Changed badges"
L["Show predicted data"] = "Show predicted data"
L["Record what you see"] = "Record what you see"
local COLLECTOR_TOOLTIP = "Remembers what you loot, what vendors sell and what quests offer, and the bosses you "
  .. "meet. Item pages, the Boss loot tab and the Discoveries tab then show what you have "
  .. "actually seen instead of Classic Era predictions. Off keeps what is already recorded."
L[COLLECTOR_TOOLTIP] = COLLECTOR_TOOLTIP
L["Use sources from other installed addons"] = "Use sources from other installed addons"
L["Show tooltip lines"] = "Show tooltip lines"
L["Show badge lines"] = "Show badge lines"
L["Show uses line"] = "Show uses line"
L["Show ItemTree icons in tooltips"] = "Show ItemTree icons in tooltips"
L["Show the key binding hint"] = "Show the key binding hint"
L["Open with a click"] = "Open with a click"
local CLICK_OPEN_TOOLTIP = "Which click on an item opens its tree. Ctrl + left click also opens the dressing room, "
  .. "because that is the game's own dress up shortcut."
L[CLICK_OPEN_TOOLTIP] = CLICK_OPEN_TOOLTIP
L["Show minimap button"] = "Show minimap button"
-- The Fixed position tooltip section: the Summary HUD's four tick boxes, then the reset row,
-- which is not a setting and reaches L through Options.HUD_RESET_LABEL, _BUTTON and _TOOLTIP.
-- The row label is the section header's own key, "Fixed position tooltip", defined above.
L["Show the fixed position tooltip"] = "Show the fixed position tooltip"
-- The tick box tooltip, long enough to be named once and used twice.
local HUD_TOOLTIP = "Shows the item under your cursor in a tooltip that stays in one place on the screen. "
  .. "Click it to open the tree, and tick Unlock to move to drag it somewhere else."
L[HUD_TOOLTIP] = HUD_TOOLTIP
L["Show badges"] = "Show badges"
L["Show the summary line"] = "Show the summary line"
L["Unlock to move"] = "Unlock to move"
L["Drag the tooltip where you want it. It locks again when you log out."] =
  "Drag the tooltip where you want it. It locks again when you log out."
L["Reset position"] = "Reset position"
L["Puts the fixed position tooltip back where it started."] = "Puts the fixed position tooltip back where it started."

-- UI/Keybind.lua and the key binding row in UI/Options.lua, which names the two through
-- Options.KEYBIND_LABEL and Options.KEYBIND_TOOLTIP. "Tree for hovered item" is the row label,
-- kept short because the client's key binding row truncates its label column. The full
-- sentence above it is the row tooltip. The click shortcuts are Keybind.CLICK_OPTIONS, which
-- is what the Open with a click dropdown lists and what the tooltip hint line names.
L["Tree for hovered item"] = "Tree for hovered item"
L["Open the tree for the hovered item"] = "Open the tree for the hovered item"
L["ItemTree bound %s to open the tree for the hovered item"] = "ItemTree bound %s to open the tree for the hovered item"
L["Not bound"] = "Not bound"
L["This key was bound to %s"] = "This key was bound to %s"
L["Key bindings cannot be changed in combat"] = "Key bindings cannot be changed in combat"
L["Ctrl + right click"] = "Ctrl + right click"
L["Ctrl + left click"] = "Ctrl + left click"
L["Alt + right click"] = "Alt + right click"
L["Alt + left click"] = "Alt + left click"
L["Off"] = "Off"

-- UI/Minimap.lua: the button's own tooltip. The left click line has to be true whether the
-- button reopens the last item or picks one, so it names the window rather than what is in it.
L["Left click: open ItemTree"] = "Left click: open ItemTree"
L["Drag: move the button"] = "Drag: move the button"

-- UI/Slash.lua: the command list, and what a command answers with.
L["Show this command list"] = "Show this command list"
L["Show a random item"] = "Show a random item"
L["Open the settings panel"] = "Open the settings panel"
L["Show the data and collector state"] = "Show the data and collector state"
L["Open a copyable diagnostic report"] = "Open a copyable diagnostic report"
L["Toggle the tooltip trace"] = "Toggle the tooltip trace"
L["Clear the remembered window position"] = "Clear the remembered window position"
L["Tooltip trace on"] = "Tooltip trace on"
L["Tooltip trace off"] = "Tooltip trace off"
L["Window position reset"] = "Window position reset"
L["Settings panel is not available on this client"] = "Settings panel is not available on this client"
L["No item data loaded"] = "No item data loaded"
-- /itemtree hud and its five sub commands.
L["Show or move the fixed position tooltip"] = "Show or move the fixed position tooltip"
L["Fixed position tooltip on"] = "Fixed position tooltip on"
L["Fixed position tooltip off"] = "Fixed position tooltip off"
L["Fixed position tooltip unlocked, drag it where you want it"] =
  "Fixed position tooltip unlocked, drag it where you want it"
L["Fixed position tooltip locked"] = "Fixed position tooltip locked"
L["Fixed position tooltip position reset"] = "Fixed position tooltip position reset"
L["The fixed position tooltip is not available on this client"] =
  "The fixed position tooltip is not available on this client"
-- /itemtree probe, the alias for /itprobe. UI/Probe.lua owns every other word of it.
L["Ask the client about undiscovered items"] = "Ask the client about undiscovered items"
L["The item probe is not available on this client"] = "The item probe is not available on this client"

-- UI/EditMode.lua: the Summary HUD, which players know as the fixed position tooltip. The label
-- above it while it is unlocked, and what it says while it is unlocked with nothing under the
-- cursor.
L["ItemTree fixed position tooltip"] = "ItemTree fixed position tooltip"
L["Hover an item"] = "Hover an item"

-- UI/Report.lua: the /itemtree report window, which is the debug lines and the recent tooltip
-- trace in one selectable edit box so they can be pasted rather than screenshotted. Close is
-- the history modal's button as well.
L["ItemTree report"] = "ItemTree report"
L["Everything is selected: copy with Ctrl C or Cmd C"] = "Everything is selected: copy with Ctrl C or Cmd C"
L["Close"] = "Close"

-- UI/Frame.lua: the window shell. Frame.TABS names the two tabs and Frame.VIEW_TABS the three
-- views, both through L, and so do the New and Changed toggles in the caption row. The Requires
-- tab's word is the one UI/InfoPanel.lua and Core already draw, a few blocks down.
L["Tree"] = "Tree"
L["Chain"] = "Chain"
L["Sources"] = "Sources"
L["Used by"] = "Used by"
L["Show classic diff"] = "Show classic diff"
L["Options"] = "Options"
L["Not built yet"] = "Not built yet"
L["Item %d"] = "Item %d"
-- A view tab with its row count beside it, "Used by (12)".
L["%s (%d)"] = "%s (%d)"

-- UI/Sidebar.lua: the category column, which leads with an All row carrying the total.
L["All"] = "All"
L["Search uses"] = "Search uses"
L["%d rows in every category"] = "%d rows in every category"
L["%d row in this category"] = "%d row in this category"
L["%d rows in this category"] = "%d rows in this category"

-- UI/Tree.lua: the tree column, including the source columns it folds in and the mark a row
-- that stands for a recipe or an enchant carries.
L["Show %d more"] = "Show %d more"
L["Already in this path"] = "Already in this path"
L["Loading data"] = "Loading data"
L["No matches"] = "No matches"
L["Your skill: %s"] = "Your skill: %s"
L["Marked %s"] = "Marked %s"
L["Search sources"] = "Search sources"
L["Recipe (%s)"] = "Recipe (%s)"
L["Seen %d"] = "Seen %d"

-- UI/InfoPanel.lua: the item info column, which is the fact labels, the section headings and
-- the values the column writes as a phrase rather than a number.
L["Type"] = "Type"
L["Subtype"] = "Subtype"
L["Slot"] = "Slot"
L["Binds"] = "Binds"
L["Stack size"] = "Stack size"
L["Sell price"] = "Sell price"
L["Durability"] = "Durability"
L["Classes"] = "Classes"
L["Weapon"] = "Weapon"
L["Damage"] = "Damage"
L["Damage per second"] = "Damage per second"
L["Speed"] = "Speed"
L["Stats"] = "Stats"
L["Stat budget"] = "Stat budget"
L["Effects"] = "Effects"
L["Requires"] = "Requires"
L["Unique"] = "Unique"
L["Unique (%s)"] = "Unique (%s)"
L["Unknown item"] = "Unknown item"
L["Unknown spell"] = "Unknown spell"
L["Learned from"] = "Learned from"
L["A trainer"] = "A trainer"
L["Tools"] = "Tools"
L["No description"] = "No description"
L["%d%%"] = "%d%%"
L["%s x%s"] = "%s x%s"
L["Any class"] = "Any class"
-- The quest view: the header for a quest nothing names, the line under one nothing is known
-- about, and the mark on a reward the player picks between. Core/Quests.lua words the last one
-- the same way on the edge itself.
L["Unknown quest"] = "Unknown quest"
L["Nothing known about this quest yet"] = "Nothing known about this quest yet"
L["Choose one"] = "Choose one"

-- The same facts phrased as the client's own tooltip lines, for a row hovered in the window
-- (brief TV4 moved the level, stack and weapon words to its block at the end of the file).
L["Classes: %s"] = "Classes: %s"

-- UI/InfoPanel.lua bonding and slots, all reached by number. BONDING is the word in the Binds
-- row, BONDING_LINES the sentence the client writes under an item name, and SLOT_NAMES the
-- inventory type, spelled the way the client spells it.
L["When picked up"] = "When picked up"
L["When equipped"] = "When equipped"
L["When used"] = "When used"
L["Quest item"] = "Quest item"
L["Binds when picked up"] = "Binds when picked up"
L["Binds when equipped"] = "Binds when equipped"
L["Binds when used"] = "Binds when used"
L["Head"] = "Head"
L["Neck"] = "Neck"
L["Shoulder"] = "Shoulder"
L["Shirt"] = "Shirt"
L["Chest"] = "Chest"
L["Waist"] = "Waist"
L["Legs"] = "Legs"
L["Feet"] = "Feet"
L["Wrist"] = "Wrist"
L["Hands"] = "Hands"
L["Finger"] = "Finger"
L["Trinket"] = "Trinket"
L["One-Hand"] = "One-Hand"
L["Two-Hand"] = "Two-Hand"
L["Main Hand"] = "Main Hand"
L["Off Hand"] = "Off Hand"
L["Held in off hand"] = "Held in off hand"
L["Shield"] = "Shield"
L["Ranged"] = "Ranged"
L["Thrown"] = "Thrown"
L["Ammo"] = "Ammo"
L["Quiver"] = "Quiver"
L["Relic"] = "Relic"
L["Back"] = "Back"
L["Bag"] = "Bag"
L["Tabard"] = "Tabard"

-- UI/Chain.lua: the whole chain on one canvas, with the fit, pan and zoom controls, the chain
-- selector, and what a right click on a step or a co-reagent offers.
L["No chain from this item"] = "No chain from this item"
L["Nothing links this item to another one in either direction."] =
  "Nothing links this item to another one in either direction."
L["Fit"] = "Fit"
L["Fit the whole chain"] = "Fit the whole chain"
L["Zoom in"] = "Zoom in"
L["Zoom out"] = "Zoom out"
-- UI/Map.lua (brief UX2): the chain's zoom bar on the Map tab, its Reset button's hover.
L["Reset the zoom to show the whole map"] = "Reset the zoom to show the whole map"
L["1 alternative"] = "1 alternative"
L["%d alternatives"] = "%d alternatives"
L["Choose which chain to show"] = "Choose which chain to show"
L["Follow this step instead"] = "Follow this step instead"
L["Follow this reagent instead"] = "Follow this reagent instead"
L["Follow this item instead"] = "Follow this item instead"
L["Open as the new root"] = "Open as the new root"
-- UI/Discoveries.lua: a found item's row opens it on the Item tree tab, and its hover says so.
L["Click to open in the Tree tab"] = "Click to open in the Tree tab"

-- UI/History.lua: the recently viewed modal the rewind button raises over the window.
-- UI/Chain.lua marks a pinned step with the same two words.
L["Recently viewed"] = "Recently viewed"
L["Pinned"] = "Pinned"
L["Recent"] = "Recent"
L["Pin"] = "Pin"
L["Unpin"] = "Unpin"
L["Clear history"] = "Clear history"
L["Nothing viewed yet"] = "Nothing viewed yet"
L["%d pinned"] = "%d pinned"
L["%d recent"] = "%d recent"
L["%d pinned, %d recent"] = "%d pinned, %d recent"

-- UI/Probe.lua: the /itprobe diagnostic, which asks the client what it will say about an
-- undiscovered item id. "Undiscovered" is the addon's one word for an item this build lists by
-- id and withholds the details of; the design notes call the mechanic sealing. For the owner,
-- opt in, in memory only: nothing it finds is saved and nothing about the character, the realm
-- or the account is read. The table itself is not translated, because
-- its column headings are the names of the client calls it made.
L["ItemTree probe"] = "ItemTree probe"
L["ItemTree probe: a diagnostic for undiscovered items. Nothing is saved."] =
  "ItemTree probe: a diagnostic for undiscovered items. Nothing is saved."
L["probe these item ids"] = "probe these item ids"
L["probe a fixed sample of undiscovered ids, 40 by default and 200 at most"] =
  "probe a fixed sample of undiscovered ids, 40 by default and 200 at most"
L["probe a few ordinary ids, to see what a normal answer looks like"] =
  "probe a few ordinary ids, to see what a normal answer looks like"
L["stop a probe that is running"] = "stop a probe that is running"
L["Probing %d ids. /itprobe stop ends it."] = "Probing %d ids. /itprobe stop ends it."
L["A probe is already running. /itprobe stop ends it."] = "A probe is already running. /itprobe stop ends it."
L["No probe is running"] = "No probe is running"
L["Nothing to probe"] = "Nothing to probe"
L["The probe does not run in combat"] = "The probe does not run in combat"
L["This client has no timer, so the probe cannot be throttled"] =
  "This client has no timer, so the probe cannot be throttled"
L["Probe finished: %d ids"] = "Probe finished: %d ids"
L["The whole report is in ItemTree.UI.Probe.lastReport"] = "The whole report is in ItemTree.UI.Probe.lastReport"

-- Core/Graph.lua, Core/ViewModel.lua and UI/InfoPanel.lua: item combines, a create item spell
-- cast by USING an item, with no profession behind it. "Combine" leads such a row's title where
-- "Spell" leads a recipe's, "Item use" is the category both sides of one are filed under, and a
-- row the build named after the item you use is renamed after what it makes.
L["Combine"] = "Combine"
L["Item use"] = "Item use"
L["Combine: %s"] = "Combine: %s"
L["Used from"] = "Used from"
L["Used"] = "Used"
L["%s and %d more"] = "%s and %d more"

-- Core/Graph.lua: what an item WoW Forever withholds is called. The build has an Item row for
-- it and no ItemSparse row, so the name is built from the class, the subclass and the slot that
-- row states and from nothing else. The slot words are Graph's SLOT_WORDS, by inventory type.
L["Undiscovered %s"] = "Undiscovered %s"
L["Undiscovered item"] = "Undiscovered item"
L["head"] = "head"
L["neck"] = "neck"
L["shoulder"] = "shoulder"
L["shirt"] = "shirt"
L["chest"] = "chest"
L["waist"] = "waist"
L["legs"] = "legs"
L["feet"] = "feet"
L["wrist"] = "wrist"
L["hands"] = "hands"
L["ring"] = "ring"
L["trinket"] = "trinket"
L["shield"] = "shield"
L["back"] = "back"
L["tabard"] = "tabard"
L["held in off hand"] = "held in off hand"
L["relic"] = "relic"

-- UI/Tooltip.lua, UI/Tree.lua and UI/InfoPanel.lua: what the addon says about an item the build
-- withholds and about one somebody on the realm has since found. The tooltip block splits the
-- sentence over its status line and the line under it, because a status line sits beside a
-- medallion; a row tooltip and the info column have the room for the whole sentence.
L["Undiscovered in Forever"] = "Undiscovered in Forever"
L["Its details appear once someone on your realm finds it."] = "Its details appear once someone on your realm finds it."
L["Discovered on your realm"] = "Discovered on your realm"
L["Not yet in ItemTree data."] = "Not yet in ItemTree data."
L["Undiscovered in Forever. Its details appear once someone on your realm finds it."] =
  "Undiscovered in Forever. Its details appear once someone on your realm finds it."
L["Discovered on your realm. Not yet in ItemTree data."] = "Discovered on your realm. Not yet in ItemTree data."

-- Core/Diff.lua: an id the baseline had an Item row for and would not name, which this build
-- names. It was discovered, not added, so it wears no medallion and carries this line instead.
L["Discovered"] = "Discovered"
L["Newly named in this build"] = "Newly named in this build"

-- UI/Tree.lua: the search box, once the window has three views rather than two directions.
L["Search requirements"] = "Search requirements"

-- UI/Chain.lua: the two lines a stage tooltip ends on. A click opens the stage on a list view,
-- and a right click follows the chain from it without leaving the Item chain view.
L["Right click to follow the chain from here"] = "Right click to follow the chain from here"

-- Core/ViewModel.lua EMPTY_TEXT: the line the fourth tab draws when it has nothing. It covers
-- two answers at once, because the tab cannot tell them apart: a shirt or a trade good cannot
-- be disenchanted at all, and an item the bands do not cover has no result to predict.
L["Cannot be disenchanted, or the result is not known"] = "Cannot be disenchanted, or the result is not known"

-- UI/Tree.lua: the search box on the view tab row, once the window has a fourth view.
L["Search disenchant results"] = "Search disenchant results"

-- Core/Discoveries.lua and UI/Discoveries.lua: the Discoveries tab, one list of the items this
-- client has watched the realm discover and the items a new data build newly names. The five
-- band headers the list is grouped under, the plain count line under the list (the per source
-- numbers are on the tabs over it, so the line does not say them twice), the column header
-- beside Item, the search box and the empty state. The Source column and the words on the
-- source tabs are their own block at the end of this file.
L["Today"] = "Today"
L["Yesterday"] = "Yesterday"
L["Earlier this week"] = "Earlier this week"
L["Earlier"] = "Earlier"
L["In this data build"] = "In this data build"
L["%d discovered"] = "%d discovered"
L["%d of %d discovered"] = "%d of %d discovered"
L["When"] = "When"
L["Search discoveries"] = "Search discoveries"
L["Nothing discovered yet"] = "Nothing discovered yet"
L["WoW Forever keeps an item's details back until someone on your realm finds it."] =
  "WoW Forever keeps an item's details back until someone on your realm finds it."
L["When you come across one, it appears here."] = "When you come across one, it appears here."

-- UI/Frame.lua Frame.TABS: the third top tab, which opens the Discoveries pane. The word is
-- reached through the tab table, so tests/spec/locale_spec.lua lists it by hand.
L["Discoveries"] = "Discoveries"

-- Core/Discoveries.lua: the Source column, which tells three things apart. The player obtained
-- the item; the client could name an item the data withholds and the player only saw it, which
-- means somebody else on the realm found it; or a newer data build names it. The three short
-- words go in the column (brief W33 took the longer sentences out of a hovered row's tooltip),
-- and the four short words on the source tabs over the list, each of which wears its own count. All are reached
-- through tables, so tests/spec/locale_spec.lua lists them by hand.
L["Source"] = "Source"
L["Found by you"] = "Found by you"
L["On your realm"] = "On your realm"
L["New data"] = "New data"
L["All"] = "All"
L["By you"] = "By you"

-- Core/Chain.lua and UI/Chain.lua: the two signposts a chain ends and begins on. A chain stops
-- at the item that would be disenchanted rather than running on through the dust, and says so
-- with one stage the player can click; a chain rooted on a shard or a dust says the same thing
-- the other way about, because its sources are every piece of equipment in the band. The results
-- line is how many things the rule predicts the last item turns into. "Disenchanted from" is the
-- edge's own wording, stated in Core/Edges.lua and already in this file.
L["Disenchants"] = "Disenchants"
L["1 result"] = "1 result"
L["%d results"] = "%d results"

-- UI/Frame.lua: the footer's Merge recipes tick box, left of Compact rows. A recipe and the item
-- it teaches are two nodes in the graph and one thing to the player, so the window draws them as
-- one row by default and this turns that off. Its hover text is the brief F1 block at the end.
L["Merge recipes"] = "Merge recipes"

-- UI/Tree.lua: what a merged craft row says in its tooltip, where the tree drew it as two small
-- glyphs on the row's icon. "Makes 4" is the yield the corner of the icon carries as a stack
-- count, and "Taught by Recipe: Thistle Tea" is what the quiet scroll mark means: a recipe item
-- teaches this craft, rather than a trainer. "Merge recipes" is in the UI/Frame.lua block
-- above; the two files draw the one setting.
L["Makes %s"] = "Makes %s"
L["Taught by %s"] = "Taught by %s"

-- UI/InfoPanel.lua and Core/Diff.lua: armour. No build states it as a column the addon can
-- read; the pipeline works it out from the four armour curves by item level, quality, armour
-- subclass and slot (ItemTree-Data docs/armour.md), and the client's own RESISTANCE0_NAME is
-- used in its place wherever the running client has one, which on an English client reads
-- "Armor". This is the word for a client that answers nothing, and the label Core/Diff.lua
-- puts on an armour change row through Diff.FieldLabel, which is reached through a table.
L["Armour"] = "Armour"

-- UI/Options.lua: the Source databases section at the foot of the settings panel. The header
-- is Options.PROVIDER_SECTION, which is also the fifth entry in Options.SECTIONS; the five
-- plain words are Options.PROVIDER_STATES, one per state a database can be in, which
-- Options.StateText answers with. The first four are Providers/Registry.lua's own states and
-- "Turned off" is what every row reads as while the tick box above them is off. All of these
-- reach L through a table, so tests/spec/locale_spec.lua lists them by hand.
L["Source databases"] = "Source databases"
L["Not installed"] = "Not installed"
L["Installed, waiting to load"] = "Installed, waiting to load"
L["Ready"] = "Ready"
L["Stopped after an error"] = "Stopped after an error"
L["Turned off"] = "Turned off"

-- EXPERIMENTAL (brief E25): what a craft is made of, in the Used by view. One block for all
-- four ways of showing it, because they are one feature and three of them come out again once
-- the owner has picked his favourite.
--
-- "Ingredients (%d)" is the muted group row Core/ViewModel.lua adds under a craft in the group
-- mode; "%s %s" joins two words (E25's reagent line, "x2 Raw Nightfin Snapper", until brief LF1 gave
-- the tooltip block its "Ingredients:" heading and "2 x Raw Nightfin Snapper" lines, in the LF1 block
-- at the end of this file); "Tools: %s" is the one line a recipe's tools take under that block. The
-- settings row's label and its hover text reach L through UI/Options.lua ORDER and the six
-- words for the modes through CHOICE_SOURCES, so tests/spec/locale_spec.lua lists the label and
-- the hover text by hand. "Off" is already in this file, from the click to open row, and so is
-- "All", from the sidebar's own first row (brief E30 added the mode of that name).
L["Ingredients (%d)"] = "Ingredients (%d)"
L["%s %s"] = "%s %s"
L["Tools: %s"] = "Tools: %s"
L["Ingredients under Used by"] = "Ingredients under Used by"
-- Longer than a line either side of the equals, so it is named once and used twice, the way the
-- provider tooltip above is. The key is still the English sentence itself.
local INGREDIENTS_TOOLTIP = "Experimental. Four ways to see what a craft is made of without leaving the row. "
  .. "All shows the tooltip, the group and the item column together."
L[INGREDIENTS_TOOLTIP] = INGREDIENTS_TOOLTIP
L["In the tooltip"] = "In the tooltip"
L["As a group"] = "As a group"
L["As a strip"] = "As a strip"
L["In the item column"] = "In the item column"

-- Brief E28: the historical Classic Era source table (Core/EraSources.lua), drawn as history
-- and never as a fact about WoW Forever.
--
-- "World drop" names the row for an item the snapshot only knew drops out in the world, and
-- "Alliance" and "Horde" are the side a vendor or a quest belongs to; all three reach L through
-- a table in Core/EraSources.lua. "Classic Era" is the provenance Core/Sources.lua draws in the
-- same column it draws "via All The Things" in, "~%s" is how Core/Confidence.lua marks a figure
-- measured in another game and "About %s in Classic Era" is the same figure spelled out in the
-- row's tooltip. "Taken from Classic Era, not yet seen in Forever" is the Predicted badge's meaning
-- line for such a row, which reaches L through UI/Badges.lua MEANING_BY_BASIS; a predicted
-- disenchant result keeps the line it has always had. tests/spec/locale_spec.lua lists every one
-- of those by hand. The banner at the top of the Sources view and the line at the foot of a
-- row's tooltip are written where they are drawn, in UI/Tree.lua.
L["World drop"] = "World drop"
L["Alliance"] = "Alliance"
L["Horde"] = "Horde"
L["Classic Era"] = "Classic Era"
L["~%s"] = "~%s"
L["About %s in Classic Era"] = "About %s in Classic Era"
L["Taken from Classic Era, not yet seen in Forever"] = "Taken from Classic Era, not yet seen in Forever"
L["From Classic Era. WoW Forever may have changed this."] = "From Classic Era. WoW Forever may have changed this."
L["Some of these sources are from Classic Era and may have changed."] =
  "Some of these sources are from Classic Era and may have changed."
L["WoW Forever keeps loot details on the server until players find them, so nobody has real drop data yet."] =
  "WoW Forever keeps loot details on the server until players find them, so nobody has real drop data yet."
L["Rows marked Predicted come from Classic Era, and their drop chances were measured there."] =
  "Rows marked Predicted come from Classic Era, and their drop chances were measured there."
L["Use them as a guide."] = "Use them as a guide."

-- Brief E33: the dice button on the band, which opens one item this build added, picked at
-- random. The first line is the tooltip's title and the other two are the muted line under it,
-- one for a build with something to offer and one for a build with nothing new in it at all.
-- All three are written where they are drawn, in UI/Frame.lua.
L["Random new item in Forever"] = "Random new item in Forever"
L["Opens one of the items this build added."] = "Opens one of the items this build added."
L["This build has added nothing yet."] = "This build has added nothing yet."

-- Brief E36: the corner mark an item this build withholds wears once somebody on the realm has
-- found it, and the empty state a view draws for one nobody has found yet.
--
-- The first line is what the chest in the corner of the icon means, written in Core/Graph.lua
-- (Graph.DiscoveryMarkText) so the tree row, the Discoveries row, the chain stage and the info
-- column's header all say it in the same words. Brief E44: it is drawn on every hover of a
-- marked item, the client's own item tooltip included, and it is the whole of the small tooltip
-- the chest itself raises. Each of the four surfaces writes it in exactly one place and
-- ItemTree's tooltip block never writes it at all, so it can never land twice in one tooltip.
--
-- The other four are the designed empty state UI/Tree.lua draws over a view with nothing in it
-- when the root is an item nobody has found: the heading and three sentences under the dragon.
L["This item has been discovered"] = "This item has been discovered"
L["Nobody has found this item yet"] = "Nobody has found this item yet"
L["WoW Forever keeps an item's details on the server until it first drops."] =
  "WoW Forever keeps an item's details on the server until it first drops."
L["Until then ItemTree can show its type and its icon, and nothing more."] =
  "Until then ItemTree can show its type and its icon, and nothing more."
L["It will appear under Discoveries as soon as someone on your realm finds it."] =
  "It will appear under Discoveries as soon as someone on your realm finds it."

-- Brief E37: the interface sounds tick box, under Display in the settings page. The label and
-- the hover text reach L through the ORDER entry in UI/Options.lua, so tests/spec/locale_spec.lua
-- lists them by hand. UI/Sound.lua itself draws nothing and says nothing.
L["Interface sounds"] = "Interface sounds"
L["Play the game's own click and page sounds on ItemTree's buttons, tabs and tick boxes."] =
  "Play the game's own click and page sounds on ItemTree's buttons, tabs and tick boxes."

-- Brief E38: the eight kinds of source the Classic Era table gained in version 2, and the words
-- a row of one says beyond the name of the thing it points at.
--
-- The first block is the category an Era row is filed under, which reaches L through
-- Core/EraSources.lua PLACES and Core/ViewModel.lua GROUP_IDS: a boss drop, a creature drop, a
-- world drop, a vendor, a quest and a container all keep the category a player already knows
-- from their own sightings, and these six are the shapes no sighting has ever produced.
L["Skinned from"] = "Skinned from"
L["Gathered in"] = "Gathered in"
L["Mined in"] = "Mined in"
L["Fished in"] = "Fished in"
L["Found in"] = "Found in"
L["Pickpocketed from"] = "Pickpocketed from"

-- The qualifier a row ends with, and the words a summary row is named by. All of them reach L
-- through Core/Sources.lua, which is where every other piece of source wording lives: "%s, %s"
-- is how a qualifier is joined to the row's own name, "and %d more" and the four counts are what
-- a category says where the pipeline listed the best of it and counted the rest, "level %d to
-- %d" is that group's level band, and the two quest lines are a source that only gives the item
-- while the player is on a quest that asks for it. tests/spec/locale_spec.lua lists them.
L["%s, %s"] = "%s, %s"
L["and %d more"] = "and %d more"
L["%d vendors"] = "%d vendors"
L["%d creatures"] = "%d creatures"
L["%d quests"] = "%d quests"
L["%d sources"] = "%d sources"
L["level %d to %d"] = "level %d to %d"
L["only while on a quest"] = "only while on a quest"
L["only on the quest %s"] = "only on the quest %s"
L["limited stock %d"] = "limited stock %d"

-- Brief E47: opening the window with nothing pointed at. The key binding with nothing under the
-- cursor and a left click on the minimap button both open the item this session last showed,
-- in silence, because that is the window the player asked for back. They say why only when they
-- had to pick an item instead, which is the first time either is used in a session: out of the
-- dice button's New in Forever pool, or out of the whole database on a build that added nothing.
-- UI/Slash.lua Slash.OpenDefault prints them.
L["Opening a random new item"] = "Opening a random new item"
L["Opening a random item"] = "Opening a random item"

-- UI/Minimap.lua: the right click line. Brief E63 swapped the two clicks, so this one is the
-- settings panel now and the window moved to the left click line above.
L["Right click: settings"] = "Right click: settings"

-- UI/Probe.lua: the two one shot sub commands of /itprobe, added for the research round that
-- asked what the client itself will say about a quest and whether it will draw a creature
-- portrait. Only the usage lines are worded: everything those probes print is a diagnostic
-- table in plain English, the same as the item probe's report.
L["ask the client about one quest id, and print nothing long"] =
  "ask the client about one quest id, and print nothing long"
L["draw one creature portrait for a few seconds"] = "draw one creature portrait for a few seconds"
L["try one creature model for a few seconds"] = "try one creature model for a few seconds"

-- Brief E50: a Classic Era summary row is an OFFER now, not a fact about a number. The rest of
-- every list it stands for is shipped, so pressing the row draws those sources under it, and the
-- words say so. "Show %d more" is the same key the tree's own group cap row already uses, because
-- it is the same offer in the same words; "Show %s" wraps the counted wording a whole category
-- summary carries ("Show 184 vendors"). A row the table ships no list for keeps "and %d more"
-- above and does nothing at all. Both reach L through Core/Sources.lua.
L["Show %s"] = "Show %s"

-- Brief E50: what KIND of creature a source row names. The shipped table states the type and the
-- beast family as plain ids (Core/EraSources.lua KindOf) and no table anywhere names either, so
-- the words are ours: the row's icon draws the same fact and its tooltip says it in these words.
-- All of them reach L through Core/Sources.lua CREATURE_TYPES and CREATURE_FAMILIES.
--
-- The eleven types, in the source's own order. 10 is its "not specified", which is a real answer
-- about 191 of the names, worded as what it means to somebody reading the row.
L["Beast"] = "Beast"
L["Dragonkin"] = "Dragonkin"
L["Demon"] = "Demon"
L["Elemental"] = "Elemental"
L["Giant"] = "Giant"
L["Undead"] = "Undead"
L["Humanoid"] = "Humanoid"
L["Critter"] = "Critter"
L["Mechanical"] = "Mechanical"
L["Unknown creature"] = "Unknown creature"
L["Totem"] = "Totem"

-- The families under those types: the seventeen beast families this data uses, which are the
-- hunter pet families a player already knows by name, and the one demon family it carries.
L["Wolf"] = "Wolf"
L["Cat"] = "Cat"
L["Spider"] = "Spider"
L["Bear"] = "Bear"
L["Boar"] = "Boar"
L["Crocolisk"] = "Crocolisk"
L["Carrion Bird"] = "Carrion Bird"
L["Crab"] = "Crab"
L["Gorilla"] = "Gorilla"
L["Raptor"] = "Raptor"
L["Tallstrider"] = "Tallstrider"
L["Felhunter"] = "Felhunter"
L["Scorpid"] = "Scorpid"
L["Turtle"] = "Turtle"
L["Bat"] = "Bat"
L["Hyena"] = "Hyena"
L["Bird of Prey"] = "Bird of Prey"
L["Wind Serpent"] = "Wind Serpent"

-- The map probe's two usage lines (UI/Probe.lua). The probe is a diagnostic the owner types, not
-- a player feature, but its lines go through the locale like every other string.
L["draw one zone map for a few seconds, with a pin at x y in percent"] =
  "draw one zone map for a few seconds, with a pin at x y in percent"
L["ask the client what it calls one area id"] = "ask the client what it calls one area id"

-- Brief E52: what the info column says about a quest, out of ItemTree's own data. Both are
-- written where they are drawn, in UI/InfoPanel.lua.
--
-- "Side" labels the one thing the shipped Classic Era table states about who a quest is for:
-- Alliance or Horde, in the words the source rows already use, and nothing at all for a quest
-- open to everyone. "Drops only on this quest" heads the items that drop for a player who is on
-- it and for nobody else, each with the creature, the place and the chance under it. The rest of
-- that block is worded already: "Rewards", "and %d more", "%s, %s", "about %s", "Predicted" and
-- "From Classic Era. WoW Forever may have changed this."
L["Side"] = "Side"
L["Drops only on this quest"] = "Drops only on this quest"

-- E53: the creature portraits tick box under Display, whose two strings reach L through the
-- ORDER entry in UI/Options.lua the way every other settings row's words do.
L["Creature portraits"] = "Creature portraits"
L["Draws each creature's portrait on source rows. Turn it off on a slow computer and every row keeps a plain icon."] =
  "Draws each creature's portrait on source rows. Turn it off on a slow computer and every row keeps a plain icon."

-- Brief E57: a creature page. Clicking a source creature used to re root the window on an empty
-- page, so it now carries the creature's model and details on the left and two tabs of its own on
-- the right, Loot and Map, in place of the four an item has.
--
-- The two tab words are UI/Frame.lua's (Frame.VIEW_LABELS), the search box's words are
-- UI/Tree.lua's, the three category headers are the groups Core/EraSources.lua files a creature's
-- loot under (CREATURE_LOOT) and the two type column words sit beside "Drop" in Core/Sources.lua.
-- The rest is what the left column says about the creature itself (UI/InfoPanel.lua) and what the
-- map's rectangle says until brief E59 draws the real map in it.
L["Loot"] = "Loot"
L["Map"] = "Map"
L["Search loot"] = "Search loot"
L["Drops"] = "Drops"
L["Skinned"] = "Skinned"
L["Pickpocketed"] = "Pickpocketed"
L["Family"] = "Family"
L["Level"] = "Level"
L["Boss"] = "Boss"
L["%d to %d"] = "%d to %d"
L["Known in"] = "Known in"
L["Unknown creature"] = "Unknown creature"
L["Nothing known about this creature yet"] = "Nothing known about this creature yet"
L["Nothing known to come off this creature"] = "Nothing known to come off this creature"
L["No places known for this creature"] = "No places known for this creature"
L["No place is known for this creature"] = "No place is known for this creature"
L["World drops are not listed per creature"] = "World drops are not listed per creature"

-- Brief E59: the Map tab draws the zone's own art, out of the running client, with the creature's
-- shipped pins on it (UI/Map.lua). The zone's own name is the caption and is the build's own
-- string, not a key; the zone buttons above the map wear the same names. These four are the words
-- the tab adds around them.
--
-- The note under the map is the provenance line every other prediction in the addon closes on,
-- written for a position rather than for a drop, and it sits under the "Predicted" wording that
-- Core/Confidence.lua already owns. The other three are what the tab says where there is a map and
-- no pin on it, and where the creature is inside a place this client ships no map of, which is
-- every instance in this build.
L["Positions from Classic Era. WoW Forever may have changed this."] =
  "Positions from Classic Era. WoW Forever may have changed this."
L["No position is known in this zone"] = "No position is known in this zone"
L["Inside %s"] = "Inside %s"
L["There is no map of the inside of a place."] = "There is no map of the inside of a place."

-- Brief E62: the Map tab's zone strip becomes one dropdown where a creature is known in more than
-- five zones, or where the row of zone buttons will not fit the panel (UI/Map.lua). The zone names
-- themselves are the build's own strings and are not keys; these two are the words the dropdown
-- adds around them.
--
-- The first is the dropdown's own label, which is the open zone and how many pins stand in it
-- ("Elwynn Forest (6)"), so the one control says as much as the row of buttons it replaced. A
-- language that writes a count before the name, or with other brackets, changes the whole string
-- rather than having it built for it. The second is the dropdown's tooltip, written the way the
-- chain selector's own is.
L["%s (%d)"] = "%s (%d)"
L["Choose which zone to show"] = "Choose which zone to show"

-- Brief L4: the two load hints Core/Init.lua prints to chat. The first two keys make one line,
-- joined by a space, said once per load on any client whose version does not begin 1.60., with
-- %s the version GetBuildInfo gave. The rest are the first run hint, said once per account: the
-- click phrase comes from the click to open setting and fills the %s of the first hint line, and
-- the line with no %s stands in for it when the click is turned off.
L["ItemTree is built for the WoW Forever client (1.60.x)."] = "ItemTree is built for the WoW Forever client (1.60.x)."
L["You are on %s, so what ItemTree shows may be wrong here."] =
  "You are on %s, so what ItemTree shows may be wrong here."
L["ItemTree: %s an item to open its tree, or set a key under Key Bindings, ItemTree."] =
  "ItemTree: %s an item to open its tree, or set a key under Key Bindings, ItemTree."
L["ItemTree: set a key under Key Bindings, ItemTree, to open the tree for the item under the cursor."] =
  "ItemTree: set a key under Key Bindings, ItemTree, to open the tree for the item under the cursor."
L["/itemtree help lists the commands."] = "/itemtree help lists the commands."
L["Ctrl and right click"] = "Ctrl and right click"
L["Ctrl and left click"] = "Ctrl and left click"
L["Alt and right click"] = "Alt and right click"
L["Alt and left click"] = "Alt and left click"

-- Brief E1: the Sources empty state (UI/Tree.lua Tree.EmptyState) and the settings panel stop
-- promoting other addons. The first three are the heading and the two lines over an item's
-- Sources view with nothing in it. The last is the tooltip on "Use sources from other installed
-- addons" (UI/Options.lua), reached through Options.Definitions. Longer than a line either side
-- of the equals, so it is named once and used twice.
L["No data for this item yet"] = "No data for this item yet"
L["Start exploring. Maybe you'll be the one to find it!"] = "Start exploring. Maybe you'll be the one to find it!"
local PROVIDERS_TOOLTIP = "Adds the drops, vendors and quest rewards that your other installed addons know about to "
  .. "item pages. Off shows ItemTree's own data only."
L[PROVIDERS_TOOLTIP] = PROVIDERS_TOOLTIP
-- UI/Slash.lua (brief S1): /itemtree show finds a creature by name as well as an item.
L["Open the tree for an item or creature"] = "Open the tree for an item or creature"
L["No item or creature found"] = "No item or creature found"
-- UI/Frame.lua (brief S1): the search box placeholder, now that it finds creatures as well as items.
L["Search"] = "Search"

-- UI/Discoveries.lua (brief E4): the tag beside the name of a discovery the player has not seen
-- yet, where the client's own NEW label template is not there to draw it.
L["NEW!"] = "NEW!"

-- UI/Badges.lua, UI/Frame.lua and UI/Tooltip.lua (brief D2): the Season of Discovery badge, the
-- New mark in purple for a new item that came from Season of Discovery (its label, also the
-- footer legend's words) and the line its hover and the item tooltip carry.
L["Season of Discovery"] = "Season of Discovery"
L["New in Forever. This item came from Season of Discovery."] =
  "New in Forever. This item came from Season of Discovery."
-- UI/Discoveries.lua (brief E5, since E72 the Unchanged box on the tab row): the one line
-- tooltip of the box that shows the items the data marks unchanged.
L["Items the data marks unchanged since Classic Era."] = "Items the data marks unchanged since Classic Era."

-- Brief D3: the Discovery Miner's harvest. The settings row under Data confidence and its tooltip
-- (UI/Options.lua ORDER), the one line an item it found carries in the info column and the
-- tooltip block (Core/Diff.lua FoundLine), and the line under a harvest's changes in the Changed
-- badge's hover (Core/Diff.lua SourceText).
L["Show items found on the beta"] = "Show items found on the beta"
local HARVEST_TOOLTIP = "Shows names and stats for items first found on the beta realm, before your own realm "
  .. "finds them. Off hides them until it does."
L[HARVEST_TOOLTIP] = HARVEST_TOOLTIP
L["First found on the beta realm, %s"] = "First found on the beta realm, %s"
L["From the beta harvest"] = "From the beta harvest"

-- Brief E66: a discovery made on another realm the player plays on (Core/Discoveries.lua
-- SOURCE_LABELS, "other"). Shown under All, never under On your realm.
L["Other realms"] = "Other realms"
-- UI/Discoveries.lua (briefs E67, E72 and E73): the four boxes at the right hand end of the
-- Discoveries tab's tab row, one per kind of row. "New" and "Changed" are the badge words above;
-- "Unchanged" and three of the one line tooltips are here, and "SoD" with its tooltip at the end
-- of the file. Then the empty state when every box is off, and its button.
L["Unchanged"] = "Unchanged"
L["Items Forever added that Classic Era did not have."] = "Items Forever added that Classic Era did not have."
L["Items Forever has changed against Classic Era."] = "Items Forever has changed against Classic Era."
L["No filters are on."] = "No filters are on."
L["Tick one above, or go back to the default."] = "Tick one above, or go back to the default."
L["Reset to default"] = "Reset to default"

-- UI/Discoveries.lua (brief E73): the Season of Discovery box on the tab row, short for room, and
-- its one line tooltip, which says the full name first.
L["SoD"] = "SoD"
L["Season of Discovery. Items that came from Season of Discovery."] =
  "Season of Discovery. Items that came from Season of Discovery."


-- UI/Options.lua (brief U1): the bag badge size slider and corner dropdown under Bags,
-- and the four corners the dropdown offers. The preview slot row that carried its own label is
-- now the example beside the two rows (brief U2), which has no words of its own. Brief ST2: the
-- slider's words are in the ST2 block at the end of the file.
L["Bag badge corner"] = "Bag badge corner"
L["Which corner of a bag or bank slot the badge sits in. The stack count uses the bottom right."] =
  "Which corner of a bag or bank slot the badge sits in. The stack count uses the bottom right."
L["Top left"] = "Top left"
L["Top right"] = "Top right"
L["Bottom left"] = "Bottom left"
L["Bottom right"] = "Bottom right"

-- Brief D5: Classic Era details for withheld items, the setting under Data confidence, the realm
-- check a withheld item's page makes (Core/RealmCheck.lua) and the count line a creature's or a
-- quest's list gives the items it leaves out.
L["Show Classic Era details for items not yet found"] = "Show Classic Era details for items not yet found"
local ERA_DETAILS_TOOLTIP = "Shows the Classic Era name, stats and sources of items your realm has not found yet, "
  .. "marked Classic Era because Forever may have changed them. Off hides them until your "
  .. "realm finds the item."
L[ERA_DETAILS_TOOLTIP] = ERA_DETAILS_TOOLTIP
L["Classic Era details. Forever may have changed this."] = "Classic Era details. Forever may have changed this."
L["Not yet found on your realm"] = "Not yet found on your realm"
L["Checking your realm"] = "Checking your realm"
L["No one on your realm has found this item yet."] = "No one on your realm has found this item yet."
L["Found on your realm."] = "Found on your realm."
L["%d not yet found on your realm"] = "%d not yet found on your realm"

-- Brief U3: the item data ships in the load on demand addon ItemTree_Data. The setting under
-- Performance that loads it at login (on by default since brief E89), and the one chat line a failed load prints
-- (Core/Data.lua).
L["Load item data at login"] = "Load item data at login"
local LOAD_AT_LOGIN_TOOLTIP = "Loads ItemTree's item data when you log in, so the window opens without a pause. "
  .. "Off loads it the first time the window opens and saves about 20 MB until then."
L[LOAD_AT_LOGIN_TOOLTIP] = LOAD_AT_LOGIN_TOOLTIP
L["ItemTree's item data did not load. Install the ItemTree_Data folder beside ItemTree and enable it."] =
  "ItemTree's item data did not load. Install the ItemTree_Data folder beside ItemTree and enable it."

-- Brief Q2: New in Forever on quests and the New reward mark (UI/QuestFlags.lua), and the setting
-- under Display that turns both off (its row's words are at the end since brief SM1). "New in
-- Forever" itself is the tooltip's key above.
L["New reward"] = "New reward"
local QUEST_BADGES_TOOLTIP = "Marks quests Forever added, and rewards a quest did not give in Classic Era, "
  .. "when you are offered them and in the quest log."
L[QUEST_BADGES_TOOLTIP] = QUEST_BADGES_TOOLTIP

-- Brief P2: /itemtree cpu (UI/Slash.lua), which reads where ItemTree spends CPU time with the
-- client's script profiling on.
L["Show where ItemTree spends CPU time"] = "Show where ItemTree spends CPU time"
local CPU_PROFILING_OFF = "Profiling is off. Type /console scriptProfile 1, then /reload. "
  .. "It slows every addon: turn it off after."
L[CPU_PROFILING_OFF] = CPU_PROFILING_OFF
L["This client cannot say whether script profiling is on."] = "This client cannot say whether script profiling is on."
L["ItemTree CPU usage reset"] = "ItemTree CPU usage reset"
L["This client cannot reset CPU usage"] = "This client cannot reset CPU usage"

-- Brief Q5: the switch for the blue wash behind a New quest's text (UI/QuestFlags.lua), beside the
-- questBadges row above; both sit under Badges since brief S7.
L["Show the blue wash on new quests"] = "Show the blue wash on new quests"
local QUEST_WASH_TOOLTIP = "A blue wash behind the top of a new quest's text on the quest panels, so a New in "
  .. "Forever quest reads as one at a glance. Off leaves the badge alone."
L[QUEST_WASH_TOOLTIP] = QUEST_WASH_TOOLTIP
-- Brief DV1: the one line an item no player can get carries when it is opened directly
-- (UI/InfoPanel.lua InfoPanel.UnobtainableLine).
L["Not obtainable: developer item"] = "Not obtainable: developer item"
L["Probably never released"] = "Probably never released"

-- Brief S4: the title bar search box's tooltip (UI/Frame.lua buildSearch), which says how to find
-- an item by its id (Core/Data.lua Data.ParseSearch) and that creatures are found by name.
L["Search names, or c:1234 for an item id"] = "Search names, or c:1234 for an item id"
L["Creatures are found by name only."] = "Creatures are found by name only."
-- Brief C1: the includeMinorChanges row under Display (UI/Options.lua ORDER).
L["Include minor changes"] = "Include minor changes"
local INCLUDE_MINOR_TOOLTIP = "Also marks an item Changed when only its category or stack size changed. Off lists only "
  .. "changes to things like its name, stats, effects, armour, quality or binding."
L[INCLUDE_MINOR_TOOLTIP] = INCLUDE_MINOR_TOOLTIP
-- Brief E79: who saw an item in the Discoveries tab's Source column, and the one sentence on the
-- tab's info line and every row's tooltip (Core/Discoveries.lua). "ItemTree" is above.
L["You"] = "You"
L["Discovery Miner"] = "Discovery Miner"
L["Times are when ItemTree first saw an item, not when your realm first found it."] =
  "Times are when ItemTree first saw an item, not when your realm first found it."
-- Brief M2: a vendor row's price names a currency or an item it cannot name otherwise
-- (Core/Sources.lua CostText): "30 currency 3402", "3 x item 1234".
L["currency %d"] = "currency %d"
L["item %d"] = "item %d"
-- Brief D6: a Classic Era vein's node row's category (Core/EraSources.lua PLACES; a herb's is
-- "Gathered from" above), and the zone column of a node row, which says how many zones it opens
-- onto (Core/Sources.lua ZoneCount).
L["Mined from"] = "Mined from"
L["%d zones"] = "%d zones"
L["1 zone"] = "1 zone"


-- Brief MB1: the minimap button's reset row in the settings.
L["Minimap button"] = "Minimap button"
L["Moves the minimap button to a free spot on the ring."] = "Moves the minimap button to a free spot on the ring."
-- Brief N2: an NPC's own page, what it sells and where the player saw it.
L["Sells"] = "Sells"
L["Seen in"] = "Seen in"
L["Unknown NPC"] = "Unknown NPC"
L["Alliance and Horde"] = "Alliance and Horde"
L["Nothing known about this NPC yet"] = "Nothing known about this NPC yet"
L["Nothing known to be sold here"] = "Nothing known to be sold here"
-- Brief D7: what a Classic Era object's page says it is (UI/InfoPanel.lua ObjectKindWord). "Chest"
-- is already above.
L["Fishing pool"] = "Fishing pool"
-- Brief D7: a gathering node row's hover where its name opens the node's Map page (UI/Tree.lua).
L["Click to open %s"] = "Click to open %s"
-- Brief N3: an NPC's Quests tab (the two groups, and the line when it is empty) and the line its
-- page's facts block gains for the quests it starts and ends (UI/InfoPanel.lua QuestGiverLine).
L["Starts"] = "Starts"
L["Ends"] = "Ends"
L["No quests known for this NPC"] = "No quests known for this NPC"
L["Starts 1 quest"] = "Starts 1 quest"
L["Starts %d quests"] = "Starts %d quests"
L["Ends 1 quest"] = "Ends 1 quest"
L["Ends %d quests"] = "Ends %d quests"
L["Starts 1 quest, ends %d"] = "Starts 1 quest, ends %d"
L["Starts %d quests, ends %d"] = "Starts %d quests, ends %d"
-- Brief Z1: a zone's own page, its Here tab, and the pick its Map tab pins.
L["Here"] = "Here"
L["Classic Era placed nothing here"] = "Classic Era placed nothing here"
L["Click a source's name on the Here tab to pin it on this map."] =
  "Click a source's name on the Here tab to pin it on this map."
L["Click to show %s on the map"] = "Click to show %s on the map"
-- A zone page's header word for a place with no map (UI/InfoPanel.lua ZoneKindWord). A developer
-- block above defines it too, but that block is stripped from a packaged build and this is not.
L["Instance"] = "Instance"
-- Brief M3: Merchant's Favor vendors as shipped community rows (Core/Sources.lua Favour), the
-- vendor's page and pin (UI/InfoPanel.lua, UI/Map.lua) and the crate's own lines.
L["Community note: %s"] = "Community note: %s"
L["Vendor, %s, %s"] = "Vendor, %s, %s"
L["Merchant's Favor comes from Waylaid Crates"] = "Merchant's Favor comes from Waylaid Crates"
L["Turned in to"] = "Turned in to"
L["Where you stood when you opened this vendor"] = "Where you stood when you opened this vendor"
L["A position from community pages, not checked in game"] = "A position from community pages, not checked in game"
-- Brief S5: the Performance section of the settings (UI/Options.lua SECTIONS), which holds the
-- loadDataAtLogin row above.
L["Performance"] = "Performance"
-- Brief S6: the row under Window (UI/Options.lua ORDER; the section word is in the BL3 block
-- below) that shows or hides the Discoveries tab (UI/Frame.lua DECLARED_TAB_SETTINGS).
L["Show the Discoveries tab"] = "Show the Discoveries tab"

-- Brief BL2: the Boss loot model (Core/BossLoot.lua). The type group words (BossLoot.TYPE_WORDS;
-- Back, Shield, Neck, Finger, Trinket, Relic, Ranged, Recipe, Quest and Key are above already),
-- the rank words (BossLoot.RANK_WORDS; Chest is above already), the place list's band headers and
-- the empty state of an entry nobody knows the loot of.
L["Plate"] = "Plate"
L["Mail"] = "Mail"
L["Leather"] = "Leather"
L["Cloth"] = "Cloth"
L["Held in off-hand"] = "Held in off-hand"
L["One-hand weapon"] = "One-hand weapon"
L["Two-hand weapon"] = "Two-hand weapon"
L["Material"] = "Material"
L["Consumable"] = "Consumable"
L["Container"] = "Container"
L["Other"] = "Other"
L["Rare elite"] = "Rare elite"
L["Rare"] = "Rare"
L["Level %d to %d"] = "Level %d to %d"
L["Level unknown"] = "Level unknown"
L["Nothing known yet"] = "Nothing known yet"
L["ItemTree lists what you loot here as you play"] = "ItemTree lists what you loot here as you play"

-- Brief BL3: the Boss loot tab (UI/BossLoot.lua): the tab's word, its setting under Feature tabs
-- (brief E96, it was Window), the place subtitles, the empty states and notes, and the Creature
-- page button.
L["Boss loot"] = "Boss loot"
L["Feature tabs"] = "Feature tabs"
L["Show the Boss loot tab"] = "Show the Boss loot tab"
L["A tab of what dungeon, raid and world bosses drop, by level."] =
  "A tab of what dungeon, raid and world bosses drop, by level."
L["Dungeon"] = "Dungeon"
L["Raid"] = "Raid"
L["World boss"] = "World boss"
L["%d players"] = "%d players"
L["level %d"] = "level %d"
L["Choose a dungeon, raid or world boss"] = "Choose a dungeon, raid or world boss"
L["Predicted data is hidden"] = "Predicted data is hidden"
L["Turn on %s in the settings to see them."] = "Turn on %s in the settings to see them."
L["Creature page"] = "Creature page"
L["Classic Era has no record of this creature, so it has no page."] =
  "Classic Era has no record of this creature, so it has no page."
L["Boss loot data is not available."] = "Boss loot data is not available."

-- Brief BL8: the Boss loot tab's state for an entry the index knows only as world drops.
L["Only world drops in Classic Era"] = "Only world drops in Classic Era"
L["%s's %d items are shared with many creatures, so none is listed here"] =
  "%s's %d items are shared with many creatures, so none is listed here"
-- Brief V1: Forever's own vendors, out of the client's tables (Core/ForeverVendors.lua): a vendor
-- nothing has named yet, and the one row of an item whose vendor the client does not name.
L["Vendor (npc %d)"] = "Vendor (npc %d)"
L["Sold by a vendor (not yet named by the client)"] = "Sold by a vendor (not yet named by the client)"

-- Brief GS2: the guessed sources (Core/GuessSources.lua). The word the tier is called by, the
-- nodes a guess that names no source points at, and the short name of the strategy that led a
-- guess. The strategy names are the developer tab's own words (brief GU1), repeated here outside
-- its strip block because a released build draws them too.
L["Guess"] = "Guess"
L["Unknown vendor"] = "Unknown vendor"
L["Unknown container"] = "Unknown container"
L["Unknown node"] = "Unknown node"
L["Name family"] = "Name family"
L["Made by a spell"] = "Made by a spell"
L["Starts a quest"] = "Starts a quest"
L["Reputation requirement"] = "Reputation requirement"
L["PvP or holiday requirement"] = "PvP or holiday requirement"
L["Zone or instance bound"] = "Zone or instance bound"
L["Lockbox or quest item"] = "Lockbox or quest item"
L["Shared limit category"] = "Shared limit category"
L["Recipe rank"] = "Recipe rank"
L["Item set mates"] = "Item set mates"
L["Transmog set mates"] = "Transmog set mates"
L["Nearby item ids"] = "Nearby item ids"
L["Shared appearance"] = "Shared appearance"
L["Shared icon"] = "Shared icon"
L["Nearby display ids"] = "Nearby display ids"
L["Icon twin"] = "Icon twin"
L["Level and type patterns"] = "Level and type patterns"
L["New zones by level"] = "New zones by level"
L["Price signals"] = "Price signals"
L["Name words"] = "Name words"
L["Icon name words"] = "Icon name words"
L["Icon name hints"] = "Icon name hints"
L["Spells with the same icon"] = "Spells with the same icon"
L["Found at the same time"] = "Found at the same time"
L["Quest cache"] = "Quest cache"
L["Creature and object caches"] = "Creature and object caches"
L["Price lists"] = "Price lists"
L["Shown on a creature"] = "Shown on a creature"
L["Boss or achievement criteria"] = "Boss or achievement criteria"
L["Used as a currency"] = "Used as a currency"
L["Transmog siblings"] = "Transmog siblings"
L["Linked items"] = "Linked items"
L["Race requirement"] = "Race requirement"
L["PvP rank rewards"] = "PvP rank rewards"

-- Brief GS3: the guessed sources drawn in the Sources view (Core/ViewModel.lua GUESS_NOTICE,
-- Core/Sources.lua GuessFacts, UI/Badges.lua's guess kind), the info column's one line
-- (UI/InfoPanel.lua GuessSection) and the setting (UI/Options.lua). "Strong" and "Likely" are the
-- developer tab's words too, and ship here outside its strip block because a released build
-- draws them on a guessed row's tooltip.
L["Guesses from ItemTree's model. Forever items are still being discovered and sources are not known."] =
  "Guesses from ItemTree's model. Forever items are still being discovered and sources are not known."
L["A guess from ItemTree's model, not seen in the game."] = "A guess from ItemTree's model, not seen in the game."
-- What the Guess mark means (UI/Badges.lua MEANING, UI/Sidebar.lua BADGE_MEANING).
L["ItemTree's best guess, not yet seen in the game."] = "ItemTree's best guess, not yet seen in the game."
L["Strong"] = "Strong"
L["Likely"] = "Likely"
L["Guess: %s"] = "Guess: %s"
L["Why: %s"] = "Why: %s"
L["1 guessed source, see Sources"] = "1 guessed source, see Sources"
L["%d guessed sources, see Sources"] = "%d guessed sources, see Sources"
L["Show guessed sources"] = "Show guessed sources"
local GUESS_SOURCES_TOOLTIP = "Lists likely sources, marked Guess, for items with no known source. "
  .. "Off shows only known and predicted sources."
L[GUESS_SOURCES_TOOLTIP] = GUESS_SOURCES_TOOLTIP

-- Brief E87: a summary whose list is shipped but cannot be opened where it stands (the loop or
-- the depth cap stops it), so it says what it is rather than offering a list (UI/Tree.lua
-- SummaryText).
L["%d more, not listed here"] = "%d more, not listed here"
-- Brief E88: the count under the change lines in the item tooltip while the classic diff is on
-- (UI/Tooltip.lua Tooltip.ChangeLines).
L["and 1 more change"] = "and 1 more change"
L["and %d more changes"] = "and %d more changes"
-- Brief BL12: the Boss portraits row under Display (UI/Options.lua).
L["Boss portraits"] = "Boss portraits"
L["Draws each boss's portrait on the Boss loot rows. Off leaves the rows to their names."] =
  "Draws each boss's portrait on the Boss loot rows. Off leaves the rows to their names."

-- Brief Z2: a zone's page says what happens there (Core/ViewModel.lua ZONE_WORDS), its Map view's
-- item column counts each item's sources (ZONE_NOUNS, ZONE_WHOLE), and the caption under the map
-- names the pick (UI/Map.lua ZONE_CAPTION and the place counts).
L["Dropped here"] = "Dropped here"
L["Mined here"] = "Mined here"
L["Gathered here"] = "Gathered here"
L["Fished here"] = "Fished here"
L["Found here"] = "Found here"
L["Skinned here"] = "Skinned here"
L["Pickpocketed here"] = "Pickpocketed here"
L["Sold here"] = "Sold here"
L["1 creature"] = "1 creature"
L["1 node"] = "1 node"
L["%d nodes"] = "%d nodes"
L["1 pool"] = "1 pool"
L["%d pools"] = "%d pools"
L["1 object"] = "1 object"
L["%d objects"] = "%d objects"
L["1 vendor"] = "1 vendor"
L["1 quest"] = "1 quest"
L["Zone wide"] = "Zone wide"
L["%s: %s, %s"] = "%s: %s, %s"
L["1 place"] = "1 place"
L["%d places"] = "%d places"
L["%d places and %d more"] = "%d places and %d more"
L["no places known"] = "no places known"

-- Brief Q7: hovering the badge beside a quest's title says what it means, and for a Changed quest
-- how many rewards are new since Classic Era (UI/QuestFlags.lua ChangeCountText).
L["1 change since Classic Era"] = "1 change since Classic Era"
L["%d changes since Classic Era"] = "%d changes since Classic Era"
-- Brief E90: a creature's or a node's page says where, with the coordinates the game's map prints
-- ("Silverpine Forest 45.2, 61.0"), up to three per zone (brief TV4 moved the row's words to its
-- block at the end of the file).
L["Where"] = "Where"

-- Brief T2b: a source only the other side can use says so where its rate would be, and on its own
-- line in the row's tooltip (UI/Tree.lua FactionOnlyText).
-- Brief T4: Keep marks (Core/Keep.lua, UI/Overlay.lua, UI/Tooltip.lua, UI/Options.lua).
L["Keep marks"] = "Keep marks"
L["A gold glow on bag items with uses still ahead of you, and a line in their tooltip. Off draws neither."] =
  "A gold glow on bag items with uses still ahead of you, and a line in their tooltip. Off draws neither."
L["Its 1 use is below your level"] = "Its 1 use is below your level"
L["Its %d uses are below your level"] = "Its %d uses are below your level"
L["1 recipe"] = "1 recipe"
L["%d recipes"] = "%d recipes"
L["1 lock"] = "1 lock"
L["%d locks"] = "%d locks"
L["%s and %s"] = "%s and %s"
L["Alliance only"] = "Alliance only"
L["Horde only"] = "Horde only"

-- Brief P5b: class spells an item is the reagent for (Core/Graph.lua REAGENT_FOR_SPELL): the uses
-- line (UI/Tooltip.lua UsesText), the row's tooltip (UI/Tree.lua ClassSpellText) and the Keep line
-- (Core/Keep.lua TooltipText).
L["Reagent for 1 class spell"] = "Reagent for 1 class spell"
L["Reagent for %d class spells"] = "Reagent for %d class spells"
L["Reagent for the %s spell %s"] = "Reagent for the %s spell %s"
L["Reagent for the spell %s"] = "Reagent for the spell %s"
L["Used by your %s"] = "Used by your %s"
L["Used by %d of your spells"] = "Used by %d of your spells"
L["Used by %s spells"] = "Used by %s spells"
-- Brief Q8: a quest's page. The info column's lines (UI/InfoPanel.lua QuestLiveSections and
-- QUEST_STATES), the Quest tab's categories and reward types (Core/ViewModel.lua QUEST_GROUPS,
-- QUEST_CHOICE; brief QV3: a fixed reward says no word), and the Map tab's pins and lines (UI/Map.lua
-- QUEST_*).
L["Given by"] = "Given by"
-- Brief IW1 (the owner's ruling "2B" of 2026-10-22): the Quest tab's category of the items a quest hands over.
L["Provided items"] = "Provided items"
L["Objectives"] = "Objectives"
L["In your log"] = "In your log"
L["Completed"] = "Completed"
L["From your quest log"] = "From your quest log"
L["ItemTree records who gives it and where as you play"] = "ItemTree records who gives it and where as you play"
L["Choice"] = "Choice"
L["%d/%d %s"] = "%d/%d %s"
L["Where you stood when the quest was given or handed in"] = "Where you stood when the quest was given or handed in"
L["The objective's place, from your quest log"] = "The objective's place, from your quest log"
L["No places known for this quest yet"] = "No places known for this quest yet"
L["Given by: %s"] = "Given by: %s"
L["Turned in to: %s"] = "Turned in to: %s"
L["Search this quest"] = "Search this quest"

-- Brief Q9a: the Keep verdict's head, green or red with the level bracket it is for (Core/Keep.lua
-- TooltipParts and Bracket); brief K11: a line of its own, the reasons on the lines under it.
-- Brief TB6: the heads themselves and the item page's "Keep:" switch label are at the end of the file.
L["%s below your level"] = "%s below your level"

-- Brief Q9b: the category tooltip's count where a category draws more rows than it has sources
-- (UI/Tree.lua CategoryCountText, "4 sources, 32 rows", joined by "%s, %s"), a node page's title,
-- header and breadcrumb ("Black Lotus node"), a node map's zone with no pins (UI/Map.lua
-- NO_POSITIONS, and "%s (%s)" in its dropdown label) and the caption for a fish caught in open
-- water (UI/Map.lua OPEN_WATER).
L["1 source"] = "1 source"
L["1 row"] = "1 row"
L["%d rows"] = "%d rows"
L["%s node"] = "%s node"
L["%s (%s)"] = "%s (%s)"
L["no positions known"] = "no positions known"
L["Open water, anywhere in the zone"] = "Open water, anywhere in the zone"
-- Brief E93: the Community note mark's meaning everywhere it is explained (UI/Badges.lua MEANING
-- and LIST_MEANING, UI/Sidebar.lua BADGE_MEANING), and the last line of a row's own note on its
-- hover, naming the pages the note rests on (UI/Tree.lua BadgeNote).
L["A note other players added about this item"] = "A note other players added about this item"
L["From %s"] = "From %s"

-- Brief T7: Ctrl + right click on a creature (UI/ItemClick.lua): the npcClick row under Keys and clicks.
L["Ctrl + right click on NPCs opens their page"] = "Ctrl + right click on NPCs opens their page"
local NPC_CLICK_TOOLTIP = "Ctrl + right click a creature's target frame or nameplate to open its page in ItemTree. "
  .. "The creature's own menu still opens as well."
L[NPC_CLICK_TOOLTIP] = NPC_CLICK_TOOLTIP
-- Brief P6b: the side icon's word on an NPC's row and page header (UI/Tree.lua SIDE_WORDS,
-- UI/InfoPanel.lua HEADER_SIDES; "Alliance" and "Horde" are keys already), and the line a
-- trainer's page gains for its Teaches tab (UI/InfoPanel.lua TeachesLine).
L["Neutral (both sides)"] = "Neutral (both sides)"
L["Teaches 1 recipe"] = "Teaches 1 recipe"
L["Teaches %d recipes"] = "Teaches %d recipes"
-- Brief Z3: the tooltip on the eye button at the right of each item row in a zone's Map view item
-- list (UI/ZoneItems.lua EyeTip), which opens the item's page.
L["View %s"] = "View %s"
-- Brief C2: the first window tab is "Item tree" (its id stays "Tree", and "Tree" above is its word
-- on a narrow strip), and Chain is the first view tab of an item, "Item chain" ("Chain" above on a
-- narrow row). A chain stage's click hint and the two disenchant signposts no longer name a tab
-- that is gone: a stage opens its own page, and a signpost the view it stands for.
L["Item tree"] = "Item tree"
L["Item chain"] = "Item chain"
L["Click to open its page"] = "Click to open its page"
L["Disenchants into the usual dusts, essences and shards. Click to see them on the Disenchants into tab."] =
  "Disenchants into the usual dusts, essences and shards. Click to see them on the Disenchants into tab."
L["Disenchanted from the usual pieces of equipment. Click to see them on the Sources tab."] =
  "Disenchanted from the usual pieces of equipment. Click to see them on the Sources tab."
-- Brief B1: the key binding for the Boss loot tab (UI/Keybind.lua BINDING_NAME_ITEMTREE_BOSSLOOT and
-- the settings row, UI/Options.lua BOSS_KEYBIND_), the line the Boss loot tab's hover gains
-- (UI/Frame.lua Frame.TabTooltipLines), and the opt in second minimap button (UI/Minimap.lua, the
-- bossLootMinimapButton row under Minimap and its Reset position row).
L["Open Boss loot"] = "Open Boss loot"
L["Opens the window on the Boss loot tab, or closes it when it is already there."] =
  "Opens the window on the Boss loot tab, or closes it when it is already there."
L["The Boss loot tab is turned off under Settings."] = "The Boss loot tab is turned off under Settings."
L["Set a key for this tab under Settings"] = "Set a key for this tab under Settings"
L["Key: %s"] = "Key: %s"
L["Boss loot minimap button"] = "Boss loot minimap button"
L["A second minimap button that opens the Boss loot tab. Off by default."] =
  "A second minimap button that opens the Boss loot tab. Off by default."
L["Moves the Boss loot minimap button to a free spot beside the main one."] =
  "Moves the Boss loot minimap button to a free spot beside the main one."
L["Left click: open Boss loot"] = "Left click: open Boss loot"

-- Brief S7: the settings sections Integration was split into (UI/Options.lua SECTIONS), and the
-- Boss loot key row's second tooltip line, which names the section the tab's switch is in. Brief
-- ST2: Badges and Bags became New and Changed badges (the ST2 block at the end of the file). Brief
-- TD1: Tooltips became Tooltip display (the TD1 block at the end of the file).
L["Keys and clicks"] = "Keys and clicks"
L["Minimap"] = "Minimap"
L["The Boss loot tab is turned off under Feature tabs."] = "The Boss loot tab is turned off under Feature tabs."
-- Brief K1: the Keep line's refinements (Core/Keep.lua). An item sold everywhere reads one muted
-- line, recipes are named by profession and another profession's recipes read grey (brief W28:
-- the grey alone says it), and the help text (Keep.HelpText) names the two thresholds.
L["Sold by vendors everywhere"] = "Sold by vendors everywhere"
L["%d silver"] = "%d silver"
L["%d copper"] = "%d copper"
L["An item %d or more vendors sell for %s or less never glows, and its tooltip says Sold by vendors everywhere."] =
  "An item %d or more vendors sell for %s or less never glows, and its tooltip says Sold by vendors everywhere."

-- Brief T8: the page a creature ItemTree's data knows nothing about opens onto (UI/InfoPanel.lua
-- SightingContent): the id under its name, the classification words (Core/CreatureLookup.lua
-- CLASSIFICATIONS; "Rare", "Rare elite" and "Boss" are keys already) and the one muted line.
L["ID %d"] = "ID %d"
L["Elite"] = "Elite"
L["Normal"] = "Normal"
L["ItemTree has no data for this creature yet"] = "ItemTree has no data for this creature yet"
-- Brief BL17: the line under a boss new in WoW Forever with no Classic Era page while none of its
-- loot is known (UI/BossLoot.lua CreatureContent and SeenContent), in the E86 notice's wording.
L["New in WoW Forever. Its loot is not yet known."] = "New in WoW Forever. Its loot is not yet known."

-- Brief GS5: the short name of the pipeline's strategy C1 (Core/GuessSources.lua WHY_WORDS), which
-- a released build draws on a guessed row's tooltip. The developer block above defines it too, but
-- that block is stripped from a packaged build and this is not.
L["Community claim"] = "Community claim"
-- Brief L1: the loot ledger (Core/Ledger.lua): the five line summary /itemtree ledger prints, the
-- reset's confirm prompt and answer, and the command's line in the help list (UI/Slash.lua).
L["Show the loot ledger's counts"] = "Show the loot ledger's counts"
L["Loot sources counted: %d (%d creatures, %d nodes and objects, %d containers, %d fishing spots)"] =
  "Loot sources counted: %d (%d creatures, %d nodes and objects, %d containers, %d fishing spots)"
L["Loot windows counted: %d"] = "Loot windows counted: %d"
L["Different items counted: %d"] = "Different items counted: %d"
L["Vendors: %d, visited %d times"] = "Vendors: %d, visited %d times"
L["Quests: %d, handed in %d times. The ledger holds about %s KB."] =
  "Quests: %d, handed in %d times. The ledger holds about %s KB."
L["The loot ledger is not available"] = "The loot ledger is not available"
L["Loot ledger cleared"] = "Loot ledger cleared"
L["This clears every count in the loot ledger. Type %s to do it."] =
  "This clears every count in the loot ledger. Type %s to do it."
-- Brief E94: the settings page draws on its own canvas, so it carries the Defaults button the
-- client's list header would (UI/Options.lua buildHeaderStrip). The button uses the client's own
-- SETTINGS_DEFAULTS where it has one; the second key is what it says between the two clicks.
L["Defaults"] = "Defaults"
L["Click again"] = "Click again"
L["Puts every ItemTree setting on this page back to its default. Click twice to confirm."] =
  "Puts every ItemTree setting on this page back to its default. Click twice to confirm."
-- Brief K4: the Keep switch on an item page (UI/Frame.lua; its label "Keep:" and the marked tooltip
-- heads are in the brief TB6 block at the end) and the info column's line (UI/InfoPanel.lua).
L["Auto"] = "Auto"
L["Always"] = "Always"
L["Never"] = "Never"
L["Marked Always"] = "Marked Always"
L["Marked Never"] = "Marked Never"

-- Brief BL20: the muted line a boss's hover carries on the Boss loot tab where the boss is shown by
-- its creature's name and the client's encounter list names it otherwise (UI/BossLoot.lua).
L["Encounter: %s"] = "Encounter: %s"

-- Brief SET2: Merge recipes also folds a set's unnamed member into the named piece of the same
-- slot (Core/Graph.lua Graph.SetTwins). The one line the folded piece's tooltip (UI/Tooltip.lua)
-- and info column (UI/InfoPanel.lua) carry; the setting's hover text is the brief F1 block.
L["The set's own list also names an undiscovered %s item (id %d). It is probably this one."] =
  "The set's own list also names an undiscovered %s item (id %d). It is probably this one."
-- Brief BL22: the Boss loot header's Creature page hover for a boss whose creature has no row in
-- the Creatures data yet (UI/BossLoot.lua NoPageReason).
L["Nobody has met this creature yet, so it has no page."] = "Nobody has met this creature yet, so it has no page."

-- Brief K5: the Worth keeping switch's fourth segment, Off (its word is L["Off"] above), and the info
-- column's line. Brief FN2: its hover line is in the FN2 block at the end.
L["Marked Off"] = "Marked Off"
-- Brief BL23: the hover line of a Boss loot boss row wearing the small blue diamond, a boss not new
-- itself that drops an item new in WoW Forever (UI/BossLoot.lua NewLootLine).
L["Drops items new in WoW Forever"] = "Drops items new in WoW Forever"

-- Brief F1: the Merge recipes hover text, one sentence a line (UI/Options.lua
-- Options.MergeTooltipLines). The settings row joins them; the footer tick box stacks them.
L["Show a recipe and the item it makes as one row."] = "Show a recipe and the item it makes as one row."
L["Fold a set's undiscovered piece into the found piece for the same slot."] =
  "Fold a set's undiscovered piece into the found piece for the same slot."
L["Turn this off to see the spell, the item and every piece the set lists on separate rows."] =
  "Turn this off to see the spell, the item and every piece the set lists on separate rows."

-- Brief SR1: the "Search everything" setting (UI/Options.lua), and the words a search result and a
-- Recently viewed row of the other kinds of page say beside the name (UI/Frame.lua
-- Frame.SearchKindWords, Core/History.lua History.KindFacts).
L["Search everything"] = "Search everything"
L["The search box also finds quests, vendors, zones, herbs, veins, chests and item sets by name."] =
  "The search box also finds quests, vendors, zones, herbs, veins, chests and item sets by name."
L["Open their pages straight from the search. Item results still come first, then creatures."] =
  "Open their pages straight from the search. Item results still come first, then creatures."
L["%d pieces"] = "%d pieces"

-- Brief F155 (owner QA 2026-10-14 item 155): the "Hide other faction data" setting (UI/Options.lua,
-- under Display), and the one muted line a list says in place of the other side's rows it hid
-- (Core/Graph.lua Graph.HiddenText: the trainer search, UI/Frame.lua; the Professions tab's Trainers &
-- vendors panel, ItemTree_Professions/UI/Trainers.lua).
L["Hide other faction data"] = "Hide other faction data"
-- Brief SF1: and NPC pages' Quests tabs, which CH1 made it hide the other side's quests on.
local HIDE_OTHER_FACTION_TOOLTIP = "Hides the other faction's trainers, vendors and quests, because this character "
  .. "cannot use them: on item pages and their counts, on NPC pages' Quests tabs, in searches, in the "
  .. "Trainers & vendors panel and on zone maps. Drops and neutral NPCs always show. Off shows them, "
  .. "marked with their faction."
L[HIDE_OTHER_FACTION_TOOLTIP] = HIDE_OTHER_FACTION_TOOLTIP
L["1 Alliance trainer hidden"] = "1 Alliance trainer hidden"
L["%d Alliance trainers hidden"] = "%d Alliance trainers hidden"
L["1 Horde trainer hidden"] = "1 Horde trainer hidden"
L["%d Horde trainers hidden"] = "%d Horde trainers hidden"
L["1 Alliance vendor hidden"] = "1 Alliance vendor hidden"
L["%d Alliance vendors hidden"] = "%d Alliance vendors hidden"
L["1 Horde vendor hidden"] = "1 Horde vendor hidden"
L["%d Horde vendors hidden"] = "%d Horde vendors hidden"

-- Brief D2: what a failed load of ItemTree_Data says, once per session in chat and in the window's
-- empty state (Core/Data.lua Data.ON_DEMAND_HINTS and Data.OnDemandFailedMessage, UI/Frame.lua).
L["The ItemTree_Data folder is not in your AddOns folder: reinstall ItemTree, both folders ship in the one zip."] =
  "The ItemTree_Data folder is not in your AddOns folder: reinstall ItemTree, both folders ship in the one zip."
L["ItemTree Data is unticked in the AddOns list: tick it and reload."] =
  "ItemTree Data is unticked in the AddOns list: tick it and reload."
L["The game says ItemTree Data is out of date: tick Load out of date AddOns in the AddOns list."] =
  "The game says ItemTree Data is out of date: tick Load out of date AddOns in the AddOns list."
L["Type /itemtree debug for details."] = "Type /itemtree debug for details."

-- Brief D2, the owner's addition: the numbered steps the window's empty state draws for each
-- reason ItemTree_Data did not load (UI/Frame.lua Frame.DATA_MISSING_STEPS, numbered in code).
L["Press Escape and open AddOns."] = "Press Escape and open AddOns."
L["Tick ItemTree Data (and ItemTree)."] = "Tick ItemTree Data (and ItemTree)."
L["Tick Load out of date AddOns at the top."] = "Tick Load out of date AddOns at the top."
L["Type /itemtree debug and send the lines to the author."] = "Type /itemtree debug and send the lines to the author."

-- Brief D5: the data-missing empty state's headline for each reason, its new steps and its Open
-- AddOns button (UI/Frame.lua Frame.DATA_MISSING_HEADLINES and Frame.DATA_MISSING_STEPS).
L["Make sure ItemTree Data is enabled in your addon settings."] =
  "Make sure ItemTree Data is enabled in your addon settings."
L["The ItemTree_Data folder is missing."] = "The ItemTree_Data folder is missing."
L["The game marks ItemTree Data as out of date. Tick Load out of date AddOns."] =
  "The game marks ItemTree Data as out of date. Tick Load out of date AddOns."
L["ItemTree's item data did not load."] = "ItemTree's item data did not load."
L["Click Reload UI (the Okay button) and the game reloads."] = "Click Reload UI (the Okay button) and the game reloads."
L["Uninstall ItemTree, then install it again: the download holds two folders, ItemTree and ItemTree_Data."] =
  "Uninstall ItemTree, then install it again: the download holds two folders, ItemTree and ItemTree_Data."
L["Quit and restart the game."] = "Quit and restart the game."
L["Open AddOns"] = "Open AddOns"

-- Brief M7: an instance's Map tab draws the zone that holds its entrance, and a left click on a map
-- pin sets the client's waypoint there (UI/Map.lua Map.ENTRANCE*, Map.WAYPOINT_HINT).
L["Entrance"] = "Entrance"
L["%s entrance, %s"] = "%s entrance, %s"
L["Near %s"] = "Near %s"
L["The entrance as the game's own world map places it."] = "The entrance as the game's own world map places it."
L["Where the entrance is in this zone is not known yet."] = "Where the entrance is in this zone is not known yet."
L["Left click: set a waypoint"] = "Left click: set a waypoint"
-- Brief SR3: what a node's page and its search row say it is (UI/InfoPanel.lua ObjectKindWord,
-- UI/Frame.lua Frame.SearchKindWords), and the line the Search everything hover text gained now
-- the setting is on by default (UI/Options.lua).
L["Herb node"] = "Herb node"
L["Mining node"] = "Mining node"
L["On by default. Turn it off to search items and creatures only, for a shorter list."] =
  "On by default. Turn it off to search items and creatures only, for a shorter list."

-- Brief M8: the line under an instance's map where its instance portal pin is drawn, which the data
-- ships from the game's own tables (UI/Map.lua Map.PORTAL_NOTE).
L["The instance portal is placed from the game's own map data."] =
  "The instance portal is placed from the game's own map data."
-- Brief M8 owner additions: the instance portal pin beside the entrance, and a world boss's spawn
-- points (UI/Map.lua Map.ENTRANCE_PORTAL, Map.SPAWN*).
L["Instance portal"] = "Instance portal"
L["Spawn point"] = "Spawn point"
L["%s spawn point, %s"] = "%s spawn point, %s"
L["%s spawn points, %s"] = "%s spawn points, %s"
L["Where this boss spawns is not known yet."] = "Where this boss spawns is not known yet."

-- Brief N4: the button on a creature's or a node's Where line when it has one position (UI/InfoPanel.lua).
L["Set waypoint"] = "Set waypoint"

-- Brief PR3: the optional Professions tab's stub (UI/ProfessionsStub.lua): the tab word, its
-- setting under Feature tabs, the line drawn when its folder will not load, and the module folder's
-- placeholder line; and the generic line a failed optional folder prints (Core/Modules.lua).
L["Professions"] = "Professions"
L["Professions tab"] = "Professions tab"
L["Adds a Professions tab that shows your professions' levelling routes and keeps the reagents you still need."] =
  "Adds a Professions tab that shows your professions' levelling routes and keeps the reagents you still need."
L["The Professions tab needs the ItemTree_Professions folder. Install it beside ItemTree and enable it."] =
  "The Professions tab needs the ItemTree_Professions folder. Install it beside ItemTree and enable it."
L["Your profession routes will show here."] = "Your profession routes will show here."
L["The %s folder did not load. Install it beside ItemTree and enable it."] =
  "The %s folder did not load. Install it beside ItemTree and enable it."

-- Brief PR4: the Keep line for a reagent the player's profession route still needs, naming the
-- profession and the band (Core/Keep.lua Keep.ProfessionWords), and its fallback with no name.
L["%s, skill %d to %d"] = "%s, skill %d to %d"
L["Profession, skill %d to %d"] = "Profession, skill %d to %d"

-- Brief PR6: the profession icon on bag items the route still needs, its two rows in the Bags
-- section and their hover text (UI/ProfessionsStub.lua BADGE_ENTRIES).
L["Profession icon on route items"] = "Profession icon on route items"
L["Shows the profession's icon on items your profession route still needs."] =
  "Shows the profession's icon on items your profession route still needs."
L["Profession icon corner"] = "Profession icon corner"
L["Which corner of a bag or bank slot the profession icon sits in. A badge in that corner moves it to the next."] =
  "Which corner of a bag or bank slot the profession icon sits in. A badge in that corner moves it to the next."

-- Brief PR7: the Professions pane's own words (ItemTree_Professions/UI/Pane.lua and
-- UI/Layout.lua): the band label, the unchecked note, the recommended mark, the two empty states
-- and the fold back button.
L["%s %d to %d"] = "%s %d to %d"
L["Not yet checked on this client."] = "Not yet checked on this client."
L["Learn a profession to see its levelling route here."] = "Learn a profession to see its levelling route here."
L["There is no levelling route for %s yet."] = "There is no levelling route for %s yet."
L["Show fewer"] = "Show fewer"

-- Brief PR9: the route Keep line with the player's count against the route's need
-- (Core/Keep.lua Keep.ProfessionWords). Brief PR39: the count's own words are at the end of the
-- file. Brief BQ16: the "you have enough" words went, the count reads past the need too.

-- Brief PR10: the note under a Professions band whose route comes from the original game
-- (ItemTree_Professions/UI/Pane.lua Pane.WORDS.classic).
L["This route is from the original game and may not be the best path here. New recipes still show below."] =
  "This route is from the original game and may not be the best path here. New recipes still show below."

-- Brief PR13: the Professions tab's rank bar (ItemTree_Professions/UI/Bar.lua), its tier names,
-- ticks, specialisation marks and locked stretch, and the canvas's zoom reset and zone rows
-- (ItemTree_Professions/UI/Pane.lua).
L["Apprentice"] = "Apprentice"
L["Journeyman"] = "Journeyman"
L["Expert"] = "Expert"
L["Artisan"] = "Artisan"
L["%s %d/%d"] = "%s %d/%d"
L["Skill cap %d"] = "Skill cap %d"
L["Specialisation from %d"] = "Specialisation from %d"
L["Yours: %s"] = "Yours: %s"
L["A Weaponsmith later masters one of: %s"] = "A Weaponsmith later masters one of: %s"
L["Train %s to go past %d"] = "Train %s to go past %d"
L["Locked past %d"] = "Locked past %d"
L["Click to open the zone page"] = "Click to open the zone page"
L["Reset"] = "Reset"

-- Brief PR15: the Professions tab's Trainers & vendors button and panel
-- (ItemTree_Professions/UI/Trainers.lua Trainers.WORDS).
L["Trainers & vendors"] = "Trainers & vendors"
L["Train %s"] = "Train %s"
L["Trainers for %s"] = "Trainers for %s"
L["No trainer teaches %s."] = "No trainer teaches %s."
L["These trainers teach %s."] = "These trainers teach %s."
L["%s is learnt from this item."] = "%s is learnt from this item."
L["Other faction"] = "Other faction"
L["No trainer known yet"] = "No trainer known yet"
L["Recipes sold for %d to %d"] = "Recipes sold for %d to %d"
L["No recipe for these levels is sold by a vendor."] = "No recipe for these levels is sold by a vendor."
L["And %d more, on its page"] = "And %d more, on its page"
L["No vendor known yet"] = "No vendor known yet"
L["Trainer and vendor data could not be loaded."] = "Trainer and vendor data could not be loaded."
L["Loading trainers and vendors."] = "Loading trainers and vendors."
L["Who teaches the next rank, and who sells the recipes for your level."] =
  "Who teaches the next rank, and who sells the recipes for your level."
-- Brief PR15, the owner's view rule: the Professions canvas Reset button's hover (UI/Pane.lua).
L["Reset the zoom and centre on your current level"] = "Reset the zoom and centre on your current level"
-- Brief PR16: the Trainers & vendors panel's one sentence footer (UI/Trainers.lua).
L["Trainers and vendors are from the original game and may differ here."] =
  "Trainers and vendors are from the original game and may differ here."

-- Brief R3: the showDiscoveries row's tooltip (UI/Options.lua), which since brief E96 says the tab
-- is opt in, now also says what is kept while it is off and that the oldest finds go once full.
local DISCOVERIES_TAB_TOOLTIP = "Adds a Discoveries tab listing, newest first, the items you have seen your realm find "
  .. "and the items new data has named. Finds are kept either way, so those items keep their "
  .. "names in search and tooltips, and show here when you turn it on. The name of the "
  .. "character who saw each find is kept only while the tab is on. Once the list is full, "
  .. "the oldest finds are let go."
L[DISCOVERIES_TAB_TOOLTIP] = DISCOVERIES_TAB_TOOLTIP

-- Brief R4: the loot ledger's sixth summary line (Core/Ledger.lua SummaryLines).
L["Kills counted: %d. Loot windows with money: %d. Items disenchanted: %d."] =
  "Kills counted: %d. Loot windows with money: %d. Items disenchanted: %d."

-- Brief M11: a world boss's patrol path on its Map tab, and the line that says it appears at one of
-- the places shown (UI/Map.lua Map.PATROL_HEADING, ONE_OF_THESE, PATROL_WORD and PATROL_FROM).
L["%s patrol, %s"] = "%s patrol, %s"
L["%s appears at one of these places."] = "%s appears at one of these places."
L["patrol path"] = "patrol path"
L["Patrol path from %s"] = "Patrol path from %s"

-- Brief M13: a small patrol path's own pin on a world boss's Map tab, and its tooltip line
-- (UI/Map.lua Map.PATH_PIN and PATH_PIN_POINTS).
L["Patrol path"] = "Patrol path"
L["Patrol path, %d points"] = "Patrol path, %d points"

-- Brief BL28: the Boss loot tab's band header for level 60 places and every world boss
-- (Core/BossLoot.lua BandLabel, band 7).
L["Endgame (60+)"] = "Endgame (60+)"

-- Brief M14: a guessed source that is an object placed in the world, such as a library book's
-- bookshelf (Core/GuessSources.lua GuessSources.PlacedLabel).
L["Contained in %s"] = "Contained in %s"
L["Contained in an object"] = "Contained in an object"

-- Brief Z2 (2026-09-30): a zone's creature and NPC groups and what an NPC is (Core/ViewModel.lua
-- ZonePeopleGroups and NpcRole).
L["Creatures here"] = "Creatures here"
L["NPCs here"] = "NPCs here"
L["Quest giver"] = "Quest giver"
L["Quest ender"] = "Quest ender"

-- Brief W27: the Bags section's tick box for the Changed badge on bag and bank slots, off by
-- default (UI/Options.lua, UI/Overlay.lua Overlay.BadgesFor).
L["Show Changed badges on bags"] = "Show Changed badges on bags"
L["Also marks bag and bank items that changed from Classic. Off, bag slots mark only new items."] =
  "Also marks bag and bank items that changed from Classic. Off, bag slots mark only new items."
-- Brief K7: the ten Worth keeping looks, the shipped one, the two ramps not already named, and the
-- demo's lines (UI/Overlay.lua KEEP_LOOKS, RAMP_NAMES, DemoLine and DemoCommand; UI/Slash.lua
-- Slash.Demo and its usage line, developer only).
L["Glow"] = "Glow"
L["Ring"] = "Ring"
L["Slot glow"] = "Slot glow"
L["Thin border"] = "Thin border"
L["Inner glow"] = "Inner glow"
L["Corner gem"] = "Corner gem"
L["Bottom bar"] = "Bottom bar"
L["Ribbon"] = "Ribbon"
L["Cosmetic frame"] = "Cosmetic frame"
L["Pulse"] = "Pulse"
L["Glow and frame"] = "Glow and frame"
L["Gold"] = "Gold"
L["Heat"] = "Heat"
L["ItemTree demo: off"] = "ItemTree demo: off"
L["ItemTree demo: style %d of %d, %s, ramp %s (%d tiers)"] = "ItemTree demo: style %d of %d, %s, ramp %s (%d tiers)"
L["(the client would not draw this look's art, so it shows as Glow)"] =
  "(the client would not draw this look's art, so it shows as Glow)"
L["The bag overlay is not available on this client"] = "The bag overlay is not available on this client"
L["Show the Worth keeping looks on your bags"] = "Show the Worth keeping looks on your bags"
-- Brief W28: the Keep setting's help text (Keep.HelpText) says what the grey in the Keep line means.
L["Recipes for a profession you do not have read grey."] = "Recipes for a profession you do not have read grey."
-- Brief K8: the demo's tooltip line, and the top tier's colour on its chat line.
L["ItemTree demo: tier %d of %d, %s"] = "ItemTree demo: tier %d of %d, %s"
L["ItemTree demo: style %d of %d, %s, ramp %s (%d tiers, %s highest)"] =
  "ItemTree demo: style %d of %d, %s, ramp %s (%d tiers, %s highest)"
L["gold"] = "gold"
L["bright gold"] = "bright gold"
L["green"] = "green"
L["blue"] = "blue"
L["purple"] = "purple"
L["orange"] = "orange"
L["red"] = "red"
-- Brief K9: auction value in Worth keeping (UI/Options.lua the Keep value row and
-- Options.GoldLabel, UI/Overlay.lua DemoLine). Brief K11: the value line reads "1g 4s
-- (Auctionator)" through "%s (%s)" (Core/Keep.lua ValueWords).
L["%d gold"] = "%d gold"
L["(top tier slots wear the valuable look)"] = "(top tier slots wear the valuable look)"
-- Brief K10: the Keep value slider on fixed stops (UI/Options.lua), its first stop Off.
L["The first stop turns it off."] = "The first stop turns it off."
-- Brief K12: the Keep marks section in Settings (UI/Options.lua Style and Colours rows) and the two
-- new looks (UI/Overlay.lua KEEP_LOOKS), with the demo's usage line now counting twelve styles.
L["Dashed border"] = "Dashed border"
L["Flag"] = "Flag"
L["Style"] = "Style"
L["How bag and bank items worth keeping are marked."] = "How bag and bank items worth keeping are marked."
-- Brief K13: the Keep marks rows' example in Settings (UI/OptionsPreview.lua Preview.KeepModel),
-- one example slot a tier, captioned under each.
L["Not marked"] = "Not marked"
L["Marked"] = "Marked"
L["Tier %d, %s"] = "Tier %d, %s"
L["Worth %s or more"] = "Worth %s or more"
L["Keep marks are off."] = "Keep marks are off."
-- Brief K15: the Single colour set (UI/Options.lua Colours, Colour and Custom colour rows, UI/Theme.lua
-- keepColors), its colour words (UI/Overlay.lua HUE_NAMES), the example's heading and the demo's line.
L["Single colour"] = "Single colour"
L["Colour"] = "Colour"
L["Custom colour"] = "Custom colour"
L["Choose colour"] = "Choose colour"
L["Orange"] = "Orange"
L["Red"] = "Red"
L["Pink"] = "Pink"
L["Purple"] = "Purple"
L["Blue"] = "Blue"
L["Teal"] = "Teal"
L["Green"] = "Green"
L["White"] = "White"
L["Silver"] = "Silver"
L["Custom"] = "Custom"
L["pink"] = "pink"
L["teal"] = "teal"
L["white"] = "white"
L["silver"] = "silver"
L["custom"] = "custom"
L["%s, %s (%s)"] = "%s, %s (%s)"
L["ItemTree demo: style %d of %d, %s, ramp %s (%s)"] = "ItemTree demo: style %d of %d, %s, ramp %s (%s)"
L["Usage: /itemtree demo style <1 to 12>, ramp <gold, quality, heat or single>, value, next or off"] =
  "Usage: /itemtree demo style <1 to 12>, ramp <gold, quality, heat or single>, value, next or off"
L["Custom is the colour you choose with the Custom colour row."] =
  "Custom is the colour you choose with the Custom colour row."
L["The bags and the example follow it as you move it. Okay keeps it, Cancel puts back the old one."] =
  "The bags and the example follow it as you move it. Okay keeps it, Cancel puts back the old one."
-- Brief K16: the Valuable colour rows of the Keep marks section (UI/Options.lua) and the demo's line
-- naming the valuable colour (UI/Overlay.lua).
L["Valuable colour"] = "Valuable colour"
L["Custom valuable colour"] = "Custom valuable colour"
L["Opens the colour picker to choose your own colour for valuable items."] =
  "Opens the colour picker to choose your own colour for valuable items."
L["(top tier slots wear the valuable look, in %s)"] = "(top tier slots wear the valuable look, in %s)"
-- Brief K17: style 0 is named Classic now the Flag ships, and the Yellow pick of the Colour rows.
L["Classic (glow and frame)"] = "Classic (glow and frame)"
L["Yellow"] = "Yellow"
L["yellow"] = "yellow"
-- Brief NC1: the probe's Ctrl + right click trace.
L["print what each Ctrl + right click on a creature does, for 30 seconds"] =
  "print what each Ctrl + right click on a creature does, for 30 seconds"
L["Tracing Ctrl + right clicks for %d seconds. Ctrl + right click a creature."] =
  "Tracing Ctrl + right clicks for %d seconds. Ctrl + right click a creature."
-- Brief TC1: the footer's Total counts box (UI/Frame.lua), its hover and the tree row's tooltip
-- line (UI/Tree.lua Tree.TotalLabel).
L["Total counts"] = "Total counts"
L["Multiply a recipe's counts down the tree, so each row says how many you need in all."] =
  "Multiply a recipe's counts down the tree, so each row says how many you need in all."
L["12 Arcanite Bars need 12 Thorium Bar and 12 Arcane Crystal."] =
  "12 Arcanite Bars need 12 Thorium Bar and 12 Arcane Crystal."
L["Off, each count is for one craft."] = "Off, each count is for one craft."
L["%s in all: %s per craft, %s crafts"] = "%s in all: %s per craft, %s crafts"
-- Brief G1: the empty page a page draw that failed leaves in the window (UI/Frame.lua).
L["This page could not be shown"] = "This page could not be shown"
L["The details are in /itemtree debug"] = "The details are in /itemtree debug"
-- Brief PR18: the craft queue tray the Create all button opens (ItemTree_Professions/UI/Queue.lua).
L["All done"] = "All done"
L["Clear"] = "Clear"
L["Crafting %s"] = "Crafting %s"
L["Crafts each recipe in turn by itself"] = "Crafts each recipe in turn by itself"
L["Create next in the ItemTree queue"] = "Create next in the ItemTree queue"
L["Done"] = "Done"
L["Empties the queue"] = "Empties the queue"
L["Moves on to the next recipe"] = "Moves on to the next recipe"
L["Opening the profession window"] = "Opening the profession window"
L["Out of materials"] = "Out of materials"
L["Pause"] = "Pause"
L["Paused for combat"] = "Paused for combat"
L["Remove from the queue"] = "Remove from the queue"
L["Resume"] = "Resume"
L["Skip"] = "Skip"
L["Skipped"] = "Skipped"
L["Stopped after %d of %d"] = "Stopped after %d of %d"
L["Stops after the craft under way"] = "Stops after the craft under way"
L["The craft did not start"] = "The craft did not start"
L["The craft failed"] = "The craft failed"
L["The queue is empty"] = "The queue is empty"
-- Brief PR19: the trainer warning strip under the Professions tab's rank bar, and its demo.
L["Demo: %s"] = "Demo: %s"
L["Show trainers"] = "Show trainers"
L["You have hit the %s cap (%d/%d). Visit a trainer to learn %s."] =
  "You have hit the %s cap (%d/%d). Visit a trainer to learn %s."
-- Brief PR21: the bank reason (ItemTree_Professions/Core/Craft.lua Craft.WORDS),
-- the reworked craft queue tray (ItemTree_Professions/UI/Queue.lua Queue.WORDS) and the
-- RECOMMENDED tag on the cards, the block view and the queue rows (UI/Pane.lua Pane.WORDS).
L["Nothing to make for this level yet: the materials are in your bank, not your bags."] =
  "Nothing to make for this level yet: the materials are in your bank, not your bags."
L["Back to ItemTree"] = "Back to ItemTree"
L["Start craft queue"] = "Start craft queue"
L["Craft next"] = "Craft next"
L["RECOMMENDED"] = "RECOMMENDED"
L["Press Start craft queue to begin"] = "Press Start craft queue to begin"
L["Press Craft next to go on"] = "Press Craft next to go on"
-- Brief PR22: the craft queue tray switching the profession window to its line, its finished state
-- and the recipes it removes (ItemTree_Professions/UI/Queue.lua Queue.WORDS).
L["Queue finished: %d crafted."] = "Queue finished: %d crafted."
L["%s removed: it no longer gives skill."] = "%s removed: it no longer gives skill."
L["Starting %s"] = "Starting %s"
L["Nothing started. Press Craft next to try again."] = "Nothing started. Press Craft next to try again."
-- Brief PR24: the queue row's count ("x 5") (ItemTree_Professions/UI/Queue.lua Queue.WORDS).
L["x %d"] = "x %d"
-- Brief PR25: the craft queue tray's instant Pause, the button named in every press line, the
-- reagent words with the per craft count, the Requirements box and its pre-check, and a failed
-- craft's client error (ItemTree_Professions/UI/Queue.lua Queue.WORDS).
L["Interrupted. Press Resume to go on."] = "Interrupted. Press Resume to go on."
L["Paused. Press Resume to go on."] = "Paused. Press Resume to go on."
L["The craft failed: %s"] = "The craft failed: %s"
L["Press Craft next (or your key) for each recipe"] = "Press Craft next (or your key) for each recipe"
L["Stops before the next recipe. The game has no way to stop a batch part way."] =
  "Stops before the next recipe. The game has no way to stop a batch part way."
L["Paused: this one finishes, then it stops."] = "Paused: this one finishes, then it stops."
L["Paused: this batch finishes, then it stops."] = "Paused: this batch finishes, then it stops."
L["Paused after %d of %d. Press Resume to go on."] = "Paused after %d of %d. Press Resume to go on."
L["Switched to %s. Press %s to craft."] = "Switched to %s. Press %s to craft."
L["Switched profession. Press %s to craft."] = "Switched profession. Press %s to craft."
L["%d/%d (%d per craft)"] = "%d/%d (%d per craft)"
L["%s: near one"] = "%s: near one"
L["%s: not near one"] = "%s: not near one"
L["%s: in your bags"] = "%s: in your bags"
L["%s: not in your bags"] = "%s: not in your bags"
L["%s: you are there"] = "%s: you are there"
L["%s: not here"] = "%s: not here"
L["%s: needed"] = "%s: needed"
L["For %s."] = "For %s."
L["For %s and %d more."] = "For %s and %d more."
L["%s needs a %s. Stand near one, then press %s."] = "%s needs a %s. Stand near one, then press %s."
L["%s needs a %s in your bags. Get one, then press %s."] = "%s needs a %s in your bags. Get one, then press %s."
L["%s needs %s. Go there, then press %s."] = "%s needs %s. Go there, then press %s."

-- Brief PR27: Craft all queues only enough to reach the band's end (Core/Craft.lua, UI/Queue.lua).
L["This level is done."] = "This level is done."
L["Stopped: you reached %s %d, the end of this level."] = "Stopped: you reached %s %d, the end of this level."
L["Out of materials for this level: %s %d of %d."] = "Out of materials for this level: %s %d of %d."
L["Crafted %d (the most that can still give skill). Press Craft next to go on."] =
  "Crafted %d (the most that can still give skill). Press Craft next to go on."

-- The owner, 2026-10-02: Create all is now Craft all (the band button, the hover's title, the queue
-- tray's title and the tray's done line), and the hover is one paragraph saying what it does, then
-- one coloured status line (ItemTree_Professions/UI/Pane.lua Pane.WORDS, Core/Craft.lua
-- Craft.WORDS, UI/Queue.lua Queue.WORDS).
L["Craft all"] = "Craft all"
L["Craft all queue"] = "Craft all queue"
L["This level is done. Use Craft all on %d to %d."] = "This level is done. Use Craft all on %d to %d."
-- luacheck: push ignore 631
L["This will add as many items as possible into a crafting queue, up to the amount it takes to level up to the next profession band. Recommended items are prioritised."] =
  "This will add as many items as possible into a crafting queue, up to the amount it takes to level up to the next profession band. Recommended items are prioritised."
-- luacheck: pop
L["Not enough materials"] = "Not enough materials"
L["Nothing here gives skill any more"] = "Nothing here gives skill any more"
L["This level is done"] = "This level is done"
L["Not in combat"] = "Not in combat"
L["Enough to reach %d"] = "Enough to reach %d"
L["Gets you to about %d of %d"] = "Gets you to about %d of %d"

-- Brief PR29: the "Show nearest" button on a Sources view's "Sold by" header (UI/Tree.lua) and the
-- answers it gives in its tooltip and in chat (Core/Nearest.lua).
L["Show nearest"] = "Show nearest"
L["Finds the nearest vendor that sells this and sets a waypoint."] =
  "Finds the nearest vendor that sells this and sets a waypoint."
L["Straight line; flight paths and roads are not counted."] = "Straight line; flight paths and roads are not counted."
L["No position known for these vendors."] = "No position known for these vendors."
L["Your own position is not available here, for example inside a dungeon."] =
  "Your own position is not available here, for example inside a dungeon."
L["No vendor on your side has a known position."] = "No vendor on your side has a known position."
L["Nearest: %s"] = "Nearest: %s"
L["Nearest: %s (about %s yards)"] = "Nearest: %s (about %s yards)"
L["Nearest: %s (another zone)"] = "Nearest: %s (another zone)"
L["Nearest: %s (another zone, about %s yards)"] = "Nearest: %s (another zone, about %s yards)"
L["None on this continent. Nearest: %s"] = "None on this continent. Nearest: %s"
L["None on this continent. Nearest: %s (%s)"] = "None on this continent. Nearest: %s (%s)"
-- The owner, 2026-10-02: a material clicked in the Professions tab opens on its Sources view.
L["Click to see where to get it"] = "Click to see where to get it"
L["%d/%d (%d)"] = "%d/%d (%d)"
L["Click to see where to learn it"] = "Click to see where to learn it"
L["Nothing to craft: %s."] = "Nothing to craft: %s."
L["%s isn't learnt"] = "%s isn't learnt"
L["%s needs skill %d"] = "%s needs skill %d"
L["%s needs %d %s, you have %d"] = "%s needs %d %s, you have %d"
L["%s gives no skill"] = "%s gives no skill"
-- Brief PR34: "Show nearest" on a Sources view's "Trainer" header (UI/Tree.lua, Core/Nearest.lua).
L["Finds the nearest trainer who teaches this and sets a waypoint."] =
  "Finds the nearest trainer who teaches this and sets a waypoint."
L["No position known for these trainers."] = "No position known for these trainers."
L["No trainer on your side has a known position."] = "No trainer on your side has a known position."

-- Brief PR35: the craft queue tray's profession groups (ItemTree_Professions/UI/Queue.lua): the
-- switch to the next profession, a group's own Clear, the vendor shopping list, the level summary
-- and whole-queue total, and the card at a band's end.
L["Switched to %s. Press %s to go on."] = "Switched to %s. Press %s to go on."
L["Clear %s"] = "Clear %s"
L["Takes this profession off the queue. The others stay."] = "Takes this profession off the queue. The others stay."
L["Vendor shopping list"] = "Vendor shopping list"
L["Grab these to start crafting the queue."] = "Grab these to start crafting the queue."
L["For %d more %s"] = "For %d more %s"
L["Sold by vendors"] = "Sold by vendors"
L["%s %d of %d"] = "%s %d of %d"
L["%s %d to %d of %d"] = "%s %d to %d of %d"
L["+%d skill: %s %d to %d (level done)"] = "+%d skill: %s %d to %d (level done)"
L["+%d skill: %s %d to %d of %d (out of materials)"] = "+%d skill: %s %d to %d of %d (out of materials)"
L["+%d skill: %s %d to %d of %d"] = "+%d skill: %s %d to %d of %d"
L["%d crafted"] = "%d crafted"
L["+%d skill across %d professions"] = "+%d skill across %d professions"
L["You reached %s %d"] = "You reached %s %d"
L["Queue stopped so you don't waste materials"] = "Queue stopped so you don't waste materials"

-- Brief PR36 (owner QA of PR35): the craft queue's group header, "Cooking (16) - 1 to 50", the
-- shopping list's info mark, and the celebration card's View button
-- (ItemTree_Professions/UI/Queue.lua).
L["%s (%d) - %d to %d"] = "%s (%d) - %d to %d"
L["%s - %d to %d"] = "%s - %d to %d"
L["Click to see where to buy it"] = "Click to see where to buy it"
L["View %d to %d"] = "View %d to %d"
L["Opens ItemTree on this profession's next level. Nothing is queued or crafted."] =
  "Opens ItemTree on this profession's next level. Nothing is queued or crafted."

-- Brief N1: a zone Here row's tooltip line where the source it names opens its own page
-- (UI/Tree.lua Tree.SourceHint).
L["Click %s to open its page"] = "Click %s to open its page"
-- Brief PS1: player sourced rows (Core/PlayerSources.lua): the one line a row's tooltip and a
-- vendor's map say about where it comes from.
L["Reported by players"] = "Reported by players"

-- Brief PS3: the line under a vendor's map where the spot is the shipped player sourced one alone
-- (UI/Map.lua Map.VendorNoteLines).
L["Where players stood when they opened this vendor"] = "Where players stood when they opened this vendor"
-- Brief PR37: a reagent short for one craft on a card of the player's own band, its hover line
-- (ItemTree_Professions/UI/Pane.lua).
L["%d more for one craft"] = "%d more for one craft"
-- Brief PR38: the craft queue's one main button (ItemTree_Professions/UI/Queue.lua): its Switch
-- label, the hint under it and its hover, and the again line naming the button as it reads.
L["Switch to %s"] = "Switch to %s"
L["Switch profession"] = "Switch profession"
L["Next up is %s. Press Switch to %s."] = "Next up is %s. Press Switch to %s."
L["Next up is another profession. Press Switch profession."] = "Next up is another profession. Press Switch profession."
L["Opens that profession's window. Nothing is crafted on this press."] =
  "Opens that profession's window. Nothing is crafted on this press."
L["Press %s again to start"] = "Press %s again to start"

-- Brief K18: the Keep line for the recipes no profession names, their shipped name where they share
-- one, else a count (Core/Keep.lua Keep.PlainWords).
L["%s (%d recipes)"] = "%s (%d recipes)"
L["1 other recipe"] = "1 other recipe"
L["%d other recipes"] = "%d other recipes"

-- Brief PS5: the second cut of shipped player records. An NPC's role lines from the PlayerSources
-- module (UI/InfoPanel.lua InfoPanel.PlayerRoleText), and the lines under an NPC's and a quest's
-- map where the spot is the module's alone (UI/Map.lua VendorNoteLines and QuestNoteLines).
L["Trainer: %s"] = "Trainer: %s"
L["Quest turn-in"] = "Quest turn-in"
L["Stable master"] = "Stable master"
L["Where players stood when they talked to this NPC"] = "Where players stood when they talked to this NPC"
L["Where players stood when the quest was given or handed in"] =
  "Where players stood when the quest was given or handed in"
-- Brief PR39: the route Keep line's count (Core/Keep.lua Keep.ProfessionWords), the craft queue's row
-- "+" and "-" and their hovers, the Pause that stops the craft under way, and a need only the
-- profession's own window can check (ItemTree_Professions/UI/Queue.lua).
L["Level %s (%d / %d needed)"] = "Level %s (%d / %d needed)"
L["Level a profession (%d / %d needed)"] = "Level a profession (%d / %d needed)"
L["+"] = "+"
L["-"] = "-"
L["One more"] = "One more"
L["Adds one craft, up to what your materials and this level allow."] =
  "Adds one craft, up to what your materials and this level allow."
L["One fewer"] = "One fewer"
L["Takes one craft off. The X removes the row."] = "Takes one craft off. The X removes the row."
L["Stops now: the craft under way is cancelled and its materials kept."] =
  "Stops now: the craft under way is cancelled and its materials kept."
L["Your key binding still stops after the craft under way."] = "Your key binding still stops after the craft under way."
L["Paused: stopping the craft under way."] = "Paused: stopping the craft under way."
L["%s: open %s to check"] = "%s: open %s to check"
L["%s: open the profession window to check"] = "%s: open the profession window to check"
-- Brief K19: the Keep value works with no auction addon, from the item's vendor sell price. The
-- value line's words (Core/Keep.lua ValueWords) and the slider's hover text (UI/Options.lua).
L["The price is an installed auction addon's own scan (Auctionator, Auctioneer or TSM),"] =
  "The price is an installed auction addon's own scan (Auctionator, Auctioneer or TSM),"
L["or the item's vendor sell price where no addon has a price."] =
  "or the item's vendor sell price where no addon has a price."
L["ItemTree never scans the auction house."] = "ItemTree never scans the auction house."
-- Brief PR40: the craft queue's Recommended badge and its hover, and the plain progress line
-- (ItemTree_Professions/UI/Queue.lua).
L["R"] = "R"
L["Recommended: the route's pick for this band"] = "Recommended: the route's pick for this band"
L["%d of %d crafts done"] = "%d of %d crafts done"
L["%d of %d crafts done, %d recipes"] = "%d of %d crafts done, %d recipes"
-- Brief B7: the muted tooltip line on a player sourced row that took a Classic Era row's place,
-- with that row's drop rate (Core/Sources.lua EraRateLine).
L["Classic Era drop rate: %s"] = "Classic Era drop rate: %s"
-- Brief QN1: a player sourced vendor row's tooltip line where only one side's players recorded it
-- and nothing proves the side it serves (UI/Tree.lua SeenSideText).
L["Seen by Alliance players"] = "Seen by Alliance players"
L["Seen by Horde players"] = "Seen by Horde players"
-- Brief SH1: the share window and its header button (UI/Share.lua), and the counts line
-- the window states (Core/Share.lua Share.Summary).
L["The text could not be built. The details are in /itemtree debug."] =
  "The text could not be built. The details are in /itemtree debug."
L["%d drops, %d vendor prices, %d quest facts, %d creatures, %d places and %d discoveries"] =
  "%d drops, %d vendor prices, %d quest facts, %d creatures, %d places and %d discoveries"
L["%s KB of text"] = "%s KB of text"

-- Brief SH2: the share window's words, its parts row (UI/Share.lua) and the developer copy probe
-- (UI/Share.lua, UI/Slash.lua).
L["Help make ItemTree better"] = "Help make ItemTree better"
L["Part %d of %d"] = "Part %d of %d"
L["Copy this part, paste it, then press Next"] = "Copy this part, paste it, then press Next"
L["Previous"] = "Previous"
L["Next"] = "Next"
L["Fill the share box with a test text to copy"] = "Fill the share box with a test text to copy"
L["The share window is not available on this client"] = "The share window is not available on this client"
L["Copy probe: %d characters in the box"] = "Copy probe: %d characters in the box"
L["Copy probe: %d characters. Copy them, paste them in the site's box, read the last line there."] =
  "Copy probe: %d characters. Copy them, paste them in the site's box, read the last line there."

-- Brief SH3: the share window's Credit my character box (UI/Share.lua).
L["Credit my character"] = "Credit my character"
-- luacheck: push ignore 631
L["Adds this character's name and realm to the text, so it can be listed on the ItemTree site among the players who helped. Off leaves every name out."] =
  "Adds this character's name and realm to the text, so it can be listed on the ItemTree site among the players who helped. Off leaves every name out."
-- luacheck: pop
L["This character's name could not be read, so the text holds no name."] =
  "This character's name could not be read, so the text holds no name."

-- Brief SH5: the share window redesigned and its link (UI/Share.lua), the developer parts demo
-- (UI/Share.lua, UI/Slash.lua).
L["1. Open itemtree.net in your browser"] = "1. Open itemtree.net in your browser"
L["ItemTree sends nothing by itself. The text holds what you recorded and your character's name."] =
  "ItemTree sends nothing by itself. The text holds what you recorded and your character's name."
L["Credit my character on itemtree.net"] = "Credit my character on itemtree.net"
L["%d parts, newest first"] = "%d parts, newest first"
L["Show the share window's parts with a short test text"] = "Show the share window's parts with a short test text"
L["Share demo: %d parts"] = "Share demo: %d parts"
L["Share demo off"] = "Share demo off"

-- Brief SH7: the share window's words after the owner's QA (UI/Share.lua): the thanks line, step 2
-- naming the copy key, the footer.
L["Sharing what you find on your journeys helps make ItemTree's data more accurate."] =
  "Sharing what you find on your journeys helps make ItemTree's data more accurate."
L["2. Copy this text with Ctrl+C, then paste it there"] = "2. Copy this text with Ctrl+C, then paste it there"
L["2. Copy this text with Cmd+C, then paste it there"] = "2. Copy this text with Cmd+C, then paste it there"
L["Only game information is exported. No personal data is included."] =
  "Only game information is exported. No personal data is included."

-- Brief NP1 to NP3: a boss page's line naming its place (UI/InfoPanel.lua WithBossOf). (Brief TR2
-- folded the Trains tab into Teaches and dropped its two words.)
L["Boss of %s"] = "Boss of %s"
-- Brief PRX (PR44): an alternative recipe card's hover, what it would take on its own to the end of
-- its band (ItemTree_Professions/UI/Pane.lua).
L["On its own, %d crafts to reach %d:"] = "On its own, %d crafts to reach %d:"
L["%d x %s"] = "%d x %s"

-- Brief TB6 (owner 2026-10-05): the Keep verdict's heads, "Keep" instead of "Worth keeping" and
-- "No need to keep" instead of "Not worth keeping" (Core/Keep.lua), and the item page's switch
-- label (UI/Frame.lua).
L["Keep:"] = "Keep:"
L["Keep"] = "Keep"

-- Brief TBR (TB4, TB9, TB10): the Keep block's reasons for a quest item whose quests are done or
-- abandoned, a chained use through another profession's product, and a class locked consumable's
-- own use (Core/Keep.lua), with its Used by category (Core/ViewModel.lua).
L["Class use"] = "Class use"
-- Brief PR42: the developer's pretend professions, /itemtree demo professions (UI/Slash.lua), and
-- the craft queue's main button while they are on (ItemTree_Professions/UI/Queue.lua).
L["Pretend to have these professions instead of your own (crafting is off)"] =
  "Pretend to have these professions instead of your own (crafting is off)"
L["Give each profession a rank from 1 to %d"] = "Give each profession a rank from 1 to %d"
L["Unknown profession: %s. Use one of: %s"] = "Unknown profession: %s. Use one of: %s"
L["Demo professions off"] = "Demo professions off"
L["Demo"] = "Demo"
L["Pretend professions: crafting is off"] = "Pretend professions: crafting is off"
-- Brief LC0: the owner's click to open probe, /itprobe clickopen (UI/Probe.lua).
L["print what each modified click on an item does, for 120 seconds unless told otherwise"] =
  "print what each modified click on an item does, for 120 seconds unless told otherwise"
L["Tracing clicks on items for %d seconds. Try a loot slot, a roll, a chat link, a bag item."] =
  "Tracing clicks on items for %d seconds. Try a loot slot, a roll, a chat link, a bag item."
-- Brief PR48: the Mining track's smelting, a band's suggestion and a smelt card's words
-- (ItemTree_Professions/UI/Pane.lua).
L["Mine %s %d to %d, %s %d to %d"] = "Mine %s %d to %d, %s %d to %d"
L["Mine %d to %d, %s %d to %d"] = "Mine %d to %d, %s %d to %d"
L["%s x%d"] = "%s x%d"
L["%s -> %s"] = "%s -> %s"
L["Guaranteed points to %d, likely to %d"] = "Guaranteed points to %d, likely to %d"
L["Guaranteed points to %d"] = "Guaranteed points to %d"
L["Likely points to %d"] = "Likely points to %d"
-- Brief PR42b: /itemtree demo professions random [names] [low|mid|high] (UI/Slash.lua).
L["Unknown band: %s. Use one of: %s"] = "Unknown band: %s. Use one of: %s"
-- Brief TP1: the owner's trainer probe, /itprobe trainer (UI/Probe.lua).
L["print what the open trainer asks for each service, or wait 120 seconds for one"] =
  "print what the open trainer asks for each service, or wait 120 seconds for one"
L["Open a trainer window first. Waiting %d seconds for one to open."] =
  "Open a trainer window first. Waiting %d seconds for one to open."
-- Brief PF1: the owner's window open probe, /itprobe open (UI/Probe.lua).
L["time the next window open part by part, then the one after it"] =
  "time the next window open part by part, then the one after it"
L["Open probe armed: open an item now, then open another for the warm numbers."] =
  "Open probe armed: open an item now, then open another for the warm numbers."
-- Brief PR49b: the Professions cards on the re-planned routes, the band heading's hover and the
-- live re-rank on auction house prices (ItemTree_Professions/UI/Pane.lua).
L["No points here on this client"] = "No points here on this client"
L["Pattern sold by a vendor"] = "Pattern sold by a vendor"
L["Pattern from a reputation vendor"] = "Pattern from a reputation vendor"
L["Needs the %s specialisation"] = "Needs the %s specialisation"
L["Needs a specialisation"] = "Needs a specialisation"
L["Season of Discovery recipe"] = "Season of Discovery recipe"
L["needs %d %s, about %d days of cooldowns"] = "needs %d %s, about %d days of cooldowns"
L["needs %d %s, about a day of cooldowns"] = "needs %d %s, about a day of cooldowns"
-- Brief PR49c: a dropped pattern can be bought on the auction house too (ItemTree_Professions/UI/Pane.lua).
L["Pattern must be found or bought on AH"] = "Pattern must be found or bought on AH"
-- Brief G1b: a planned gathering band's item cards and its heading note (ItemTree_Professions/UI/Pane.lua).
L["Gather from %d - %d"] = "Gather from %d - %d"
L["Gather to %d"] = "Gather to %d"
L["Gather %s"] = "Gather %s"
L["%s from %d"] = "%s from %d"
L["%s still gives points to %d"] = "%s still gives points to %d"
L["%s; %s"] = "%s; %s"
L["%s. %s"] = "%s. %s"
-- Brief TB13: a chained use's Keep line, "8 x Blacksmithing via Alchemy (Sulfuric Acid)", the
-- professions' glyphs inline before their names, and the other products the pair reaches (Core/Keep.lua).
L["%d x %s via %s (%s)"] = "%d x %s via %s (%s)"
L["%s, +%d more"] = "%s, +%d more"
-- Brief PR49d: the Changed badge's and the route hovers' shorter words (ItemTree_Professions/UI/Pane.lua).
L["Goes grey at %d (Classic Era %d)"] = "Goes grey at %d (Classic Era %d)"
L["Classic guides use %s (grey here)"] = "Classic guides use %s (grey here)"
L["About %s a point at your auction prices"] = "About %s a point at your auction prices"
L["Cheapest at your auction prices: about %s a point"] = "Cheapest at your auction prices: about %s a point"
L["Reordered by your auction prices"] = "Reordered by your auction prices"
-- Brief TB14 (owner QA 2026-10-05): the Keep block's one quest line with the finished quests in
-- brackets, the class line, the chain line's short profession names (Core/Keep.lua), and a
-- gathering card at one number (ItemTree_Professions/UI/Pane.lua).
L["%d completed"] = "%d completed"
L["%d abandoned"] = "%d abandoned"
L["Class: %s"] = "Class: %s"
L["%s (%s %d)"] = "%s (%s %d)"
L["Warrior"] = "Warrior"
L["Paladin"] = "Paladin"
L["Hunter"] = "Hunter"
L["Rogue"] = "Rogue"
L["Priest"] = "Priest"
L["Shaman"] = "Shaman"
L["Mage"] = "Mage"
L["Warlock"] = "Warlock"
L["Druid"] = "Druid"
L["Alch"] = "Alch"
L["BS"] = "BS"
L["Ench"] = "Ench"
L["Eng"] = "Eng"
L["LW"] = "LW"
L["Tailor"] = "Tailor"
L["Mining"] = "Mining"
L["Herb"] = "Herb"
L["Skin"] = "Skin"
L["Cook"] = "Cook"
L["FA"] = "FA"
L["Fish"] = "Fish"
L["Gather at %d"] = "Gather at %d"
-- Brief K20 (design K20 Keep and Sell): the two prices, the Keep, Vendor and Sell (AH) verdict,
-- the Bar setting and the price formula (Core/Keep.lua, Core/PriceFormula.lua, UI/Options.lua,
-- UI/InfoPanel.lua).
L["Valuable at"] = "Valuable at"
L["Auction"] = "Auction"
L["An item a vendor or the auction house values at this much or more wears orange with a flame."] =
  "An item a vendor or the auction house values at this much or more wears orange with a flame."
L["+10 silver"] = "+10 silver"
L["+1 gold"] = "+1 gold"
L["1.25 x"] = "1.25 x"
L["1.5 x"] = "1.5 x"
L["2 x"] = "2 x"
L["3 x"] = "3 x"
L["Formula"] = "Formula"
L["List on the auction house when it beats the vendor by"] = "List on the auction house when it beats the vendor by"
L["Formula takes your own, such as max(vendor * 2, vendor + 1g)."] =
  "Formula takes your own, such as max(vendor * 2, vendor + 1g)."
-- Brief K20-facts: the expected disenchant value's words (Core/DisenchantValue.lua), "25% Large
-- Glimmering Shard" (brief K24b: "no price for Soul Dust" went with the disenchant sum lines).
L["%s%% %s"] = "%s%% %s"
-- Brief K20-wire: gear and disenchanting join the Keep verdict (Core/Keep.lua): the gear line, the
-- armour and weapon words it names, the two disenchant states and their lines.
L["Not for your class (%s)"] = "Not for your class (%s)"
L["Not for your class"] = "Not for your class"
L["cloth"] = "cloth"
L["leather"] = "leather"
L["mail"] = "mail"
L["plate"] = "plate"
L["shield"] = "shield"
L["libram"] = "libram"
L["idol"] = "idol"
L["totem"] = "totem"
L["one-hand axe"] = "one-hand axe"
L["two-hand axe"] = "two-hand axe"
L["bow"] = "bow"
L["gun"] = "gun"
L["one-hand mace"] = "one-hand mace"
L["two-hand mace"] = "two-hand mace"
L["polearm"] = "polearm"
L["one-hand sword"] = "one-hand sword"
L["two-hand sword"] = "two-hand sword"
L["staff"] = "staff"
L["fist weapon"] = "fist weapon"
L["dagger"] = "dagger"
L["thrown"] = "thrown"
L["crossbow"] = "crossbow"
L["wand"] = "wand"
L["Disenchants into %s, %s"] = "Disenchants into %s, %s"
L["Disenchants into %s"] = "Disenchants into %s"
L["Disenchant"] = "Disenchant"

-- Brief K24b: the verdict as action tags, the gear words, the settings and Formula help, the demo.
L["(No AH data)"] = "(No AH data)"
L["(marked by you)"] = "(marked by you)"
L["Useful at level %d"] = "Useful at level %d"
L["Useful from level %d to %d"] = "Useful from level %d to %d"
L["You could use this"] = "You could use this"
L["Keep when you mark it Always, your route needs it, it has uses ahead, it is an upgrade,"] =
  "Keep when you mark it Always, your route needs it, it has uses ahead, it is an upgrade,"
L["or it disenchants into something you use."] = "or it disenchants into something you use."
L["Auction when its price beats the vendor by your margin and a stack is worth it for the money you carry,"] =
  "Auction when its price beats the vendor by your margin and a stack is worth it for the money you carry,"
L["and Vendor beside it while that is close. Disenchant stands beside or for Auction when you enchant."] =
  "and Vendor beside it while that is close. Disenchant stands beside or for Auction when you enchant."
L["How much more than the vendor an auction must pay per item, after its cut."] =
  "How much more than the vendor an auction must pay per item, after its cut."
L["An item that falls short is not offered for auction; lower it to see more. Never never offers it."] =
  "An item that falls short is not offered for auction; lower it to see more. Never never offers it."
L["Classic is the gold glow and frame. The other styles take the Colour row's colour."] =
  "Classic is the gold glow and frame. The other styles take the Colour row's colour."
L["The colour of the Keep tag in tooltips and of the marks on bag items you keep."] =
  "The colour of the Keep tag in tooltips and of the marks on bag items you keep."
L["Opens the colour picker to choose your own Keep colour."] = "Opens the colour picker to choose your own Keep colour."
L["The colour of the Auction tag in tooltips and of bag items worth the Valuable at amount or more."] =
  "The colour of the Auction tag in tooltips and of bag items worth the Valuable at amount or more."
L["Formula not understood: %s at character %d, using 1.5 x vendor"] =
  "Formula not understood: %s at character %d, using 1.5 x vendor"
L["not understood"] = "not understood"
L["The auction price must reach this. Use vendor, auction, numbers, money like 1g 20s, and min() or max()."] =
  "The auction price must reach this. Use vendor, auction, numbers, money like 1g 20s, and min() or max()."
L["Your own line for Auction: the price an item must reach on the auction house, after its cut."] =
  "Your own line for Auction: the price an item must reach on the auction house, after its cut."
L["Names: vendor (its vendor price), auction (the first auction addon with a price), auctionator,"] =
  "Names: vendor (its vendor price), auction (the first auction addon with a price), auctionator,"
L["auctioneer, dbmarket and dbminbuyout (TSM), and disenchant (when you enchant)."] =
  "auctioneer, dbmarket and dbminbuyout (TSM), and disenchant (when you enchant)."
L["Money is written 1g20s5c. Use + - * / and brackets, and min(), max(), avg() and first()."] =
  "Money is written 1g20s5c. Use + - * / and brackets, and min(), max(), avg() and first()."
L["Example: max(vendor * 2, vendor + 1g) needs twice the vendor price and at least 1 gold more."] =
  "Example: max(vendor * 2, vendor + 1g) needs twice the vendor price and at least 1 gold more."
L["Example: min(dbmarket * 0.8, vendor * 3) needs 80% of TSM's market value, at most three times vendor."] =
  "Example: min(dbmarket * 0.8, vendor * 3) needs 80% of TSM's market value, at most three times vendor."
L["Usage: %s demo %s <%s or off>"] = "Usage: %s demo %s <%s or off>"
-- Brief K24d: the tags' second round (owner QA 2026-10-06).
L["Not an upgrade"] = "Not an upgrade"
L["Pretend an auction price, your money, your level or a disenchant price for the Keep tags"] =
  "Pretend an auction price, your money, your level or a disenchant price for the Keep tags"
-- Brief K24e: the tags' round 2 QA (owner 2026-10-06): the gear line's two item levels, worn first.
L["Equipped"] = "Equipped"
-- Brief K24h (tester QA 2026-10-07): grey and white gear held against what is worn, the Equip tag,
-- the armour kind words, the worn item outdone in the comparison tooltip, food for your level.
L["Upgrade for your %s at level %d (%s)"] = "Upgrade for your %s at level %d (%s)"
L["Upgrade for your %s (%s)"] = "Upgrade for your %s (%s)"
L["Upgrade (%s)"] = "Upgrade (%s)"
L["ilvl %s"] = "ilvl %s"
L["%s over %s"] = "%s over %s"
L["slot empty"] = "slot empty"
L["Lighter armour than you wear"] = "Lighter armour than you wear"
L["Equip"] = "Equip"
L["Better gear available"] = "Better gear available"
L["Food or drink for your level"] = "Food or drink for your level"
-- Brief K27 (owner 2026-10-08): a gear upgrade by stats per spec. The upgrade line with no brackets
-- (an upgrade for every spec of the class), and each spec's label (Core/Gear.lua Gear.SPEC_LABELS),
-- the spec alone and never the class (the owner's ruling: only the player's own class is shown).
-- "Elemental" is the creature type's entry above, the same word.
L["Upgrade for your %s at level %d"] = "Upgrade for your %s at level %d"
L["Upgrade for your %s"] = "Upgrade for your %s"
L["Upgrade"] = "Upgrade"
L["Arms"] = "Arms"
L["Fury"] = "Fury"
L["Protection"] = "Protection"
L["Holy"] = "Holy"
L["Retribution"] = "Retribution"
L["Beast Mastery"] = "Beast Mastery"
L["Marksmanship"] = "Marksmanship"
L["Survival"] = "Survival"
L["Assassination"] = "Assassination"
L["Combat"] = "Combat"
L["Subtlety"] = "Subtlety"
L["Discipline"] = "Discipline"
L["Shadow"] = "Shadow"
L["Enhancement"] = "Enhancement"
L["Restoration"] = "Restoration"
L["Arcane"] = "Arcane"
L["Fire"] = "Fire"
L["Frost"] = "Frost"
L["Affliction"] = "Affliction"
L["Demonology"] = "Demonology"
L["Destruction"] = "Destruction"
L["Balance"] = "Balance"
L["Feral DPS"] = "Feral DPS"
L["Feral Tank"] = "Feral Tank"
-- Brief K27: the per character spec rows in Settings (UI/Options.lua Options.SpecDefinitions). Their
-- hover is brief ST3's (the ST3 block at the end of the file).
L["Suggest gear for %s"] = "Suggest gear for %s"
-- Brief K26 (owner 2026-10-07): the Pet food tag and its reason, and a food or drink with a buff.
L["Pet food"] = "Pet food"
L["Food for your pet"] = "Food for your pet"
L["Food or drink with a buff"] = "Food or drink with a buff"
-- Brief K25: the consumable facts' kind words and reason lines (Core/Consumables.lua).
L["food"] = "food"
L["drink"] = "drink"
L["potion"] = "potion"
L["bandage"] = "bandage"
L["buff"] = "buff"
L["item"] = "item"
L["Best %s in your bags"] = "Best %s in your bags"
L["Better %s in your bags"] = "Better %s in your bags"
L["Too weak for your level"] = "Too weak for your level"
L["No use at the level cap"] = "No use at the level cap"
L["Can't use at your level"] = "Can't use at your level"
L["Needs a skill you lack"] = "Needs a skill you lack"
-- Brief SR4: the "+N more" row that ends a kind's rows in the search dropdown, one wording for one
-- and one for more (UI/Frame.lua Frame.SearchMoreText).
L["+1 more item"] = "+1 more item"
L["+%d more items"] = "+%d more items"
L["+1 more creature"] = "+1 more creature"
L["+%d more creatures"] = "+%d more creatures"
L["+1 more quest"] = "+1 more quest"
L["+%d more quests"] = "+%d more quests"
L["+1 more vendor"] = "+1 more vendor"
L["+%d more vendors"] = "+%d more vendors"
L["+1 more zone"] = "+1 more zone"
L["+%d more zones"] = "+%d more zones"
L["+1 more node"] = "+1 more node"
L["+%d more nodes"] = "+%d more nodes"
L["+1 more set"] = "+1 more set"
L["+%d more sets"] = "+%d more sets"
-- Brief PB1 addendum: the craft queue, a stop for full bags once the bags have room again.
L["Your bags have room again. Press Resume to go on."] = "Your bags have room again. Press Resume to go on."
-- Brief K30: a profession reagent kept only as many as the route still needs (Core/Keep.lua).
L["Not needed to level %s"] = "Not needed to level %s"
L["Not needed to level your professions"] = "Not needed to level your professions"
-- Brief K30 addendum: the uses line names the professions of the recipes (UI/Tooltip.lua).
L["Used in %d %s recipe"] = "Used in %d %s recipe"
L["Used in %d %s recipes"] = "Used in %d %s recipes"
L["Used in %d recipes: %s, %s"] = "Used in %d recipes: %s, %s"
-- Brief K29: the words of a food or drink kept for its kill experience while levelling.
L["More kill experience while levelling"] = "More kill experience while levelling"
-- Brief S8: the trainer search ("t:lw", "trainer:hunter"): the kinds it knows (Core/TrainerSearch.lua
-- TrainerSearch.KINDS, the classes' names already above), its rows and its hint lines, the search
-- box's hint line, and (the owner's addendum) the header row above each kind's rows in the
-- dropdown (UI/Frame.lua Frame.SEARCH_GROUP_WORDS and SEARCH_NODE_WORDS).
L["Alchemy"] = "Alchemy"
L["Blacksmithing"] = "Blacksmithing"
L["Enchanting"] = "Enchanting"
L["Engineering"] = "Engineering"
L["Herbalism"] = "Herbalism"
L["Leatherworking"] = "Leatherworking"
L["Skinning"] = "Skinning"
L["Tailoring"] = "Tailoring"
L["Cooking"] = "Cooking"
L["First Aid"] = "First Aid"
L["Fishing"] = "Fishing"
L["Riding"] = "Riding"
L["Weapon masters"] = "Weapon masters"
L["Pet trainers"] = "Pet trainers"
L["%s trainers"] = "%s trainers"
L["+1 more trainer"] = "+1 more trainer"
L["+%d more trainers"] = "+%d more trainers"
L["No %s known yet."] = "No %s known yet."
L["No trainer kind matches %s. Type t: to see them all."] = "No trainer kind matches %s. Type t: to see them all."
L["t:hunter or trainer:leatherworking for trainers"] = "t:hunter or trainer:leatherworking for trainers"
L["Items"] = "Items"
L["Creatures"] = "Creatures"
L["Vendors"] = "Vendors"
L["Zones"] = "Zones"
L["Sets"] = "Sets"
L["Nodes"] = "Nodes"
L["Herb nodes"] = "Herb nodes"
L["Mining nodes"] = "Mining nodes"
L["Fishing pools"] = "Fishing pools"
L["Chests"] = "Chests"
L["Trainers"] = "Trainers"
L["Trainers for"] = "Trainers for"
-- Brief Q1: a Classic quest tied to a game event (Core/EraSources.lua _MarkQuest, the Used by row's
-- tag). Brief BQ16: the "the rest can go" sentences (Q1, K30, INT1b) went for the need lines.
L["Event"] = "Event"
-- Brief BQ6 (the owner's QA backlog 2026-10-09 and 10-10): a relevant bandage beside a better one
-- carried, the best food that is also a kill experience food while levelling (Core/Consumables.lua
-- Words), a lure or device for one of the player's professions (Core/Keep.lua ProfessionUseWords),
-- and soulbound gear with a special effect kept until its level (Core/Keep.lua GearWords).
L["Still useful, a better bandage in your bags"] = "Still useful, a better bandage in your bags"
L["Best %s in your bags, more kill experience"] = "Best %s in your bags, more kill experience"
L["For your %s"] = "For your %s"
-- Brief ST4 (G1, the owner's ruling of 2026-10-10): a mage's plain food or drink their best known
-- conjure rank makes as well (Core/Consumables.lua Conjures).
L["You can conjure food as good"] = "You can conjure food as good"
L["You can conjure water as good"] = "You can conjure water as good"
-- Brief BQ7 (owner QA items 19 and 20, backlog JO1, 2026-10-10): the Hide irrelevant uses setting
-- and its modifier (UI/Options.lua, UI/Tooltip.lua Tooltip.FoldUses), the opened first keep and the
-- locked box words (Core/Keep.lua), and the line linking a Classic consumable and its soulbound
-- Forever copy (UI/Tooltip.lua Tooltip.CopyLine).
L["Hide irrelevant uses"] = "Hide irrelevant uses"
L["Folds the uses for professions you do not have into one line, so your own uses stand out."] =
  "Folds the uses for professions you do not have into one line, so your own uses stand out."
L["Show every use while holding"] = "Show every use while holding"
L["Hold it on a tooltip to see every use."] = "Hold it on a tooltip to see every use."
L["Ctrl"] = "Ctrl"
L["Shift"] = "Shift"
L["Alt"] = "Alt"
L["and %d other uses, hold %s"] = "and %d other uses, hold %s"
L["Locked: needs Lockpicking %d"] = "Locked: needs Lockpicking %d"
L["Locked: needs a key or a rogue"] = "Locked: needs a key or a rogue"
-- Brief BQ5: the uses line names the profession of the recipes that make an item (UI/Tooltip.lua
-- MadeByWords): "Made by Alchemy", "Made by Alchemy, Tailoring".
L["Made by %s"] = "Made by %s"
-- Brief BQ9: the "do this now" verdicts (Core/Keep.lua): the [Open] and [Use] tags' words, the
-- [Open] line from a container's contents ("Open it: Clam Meat, sometimes Small Lustrous Pearl"),
-- a buff to use now and a quest to start.
L["Open"] = "Open"
L["Open it"] = "Open it"
L["Open it: %s"] = "Open it: %s"
L["%s, sometimes %s"] = "%s, sometimes %s"
L["sometimes %s"] = "sometimes %s"
L["%s or %s"] = "%s or %s"
L["other loot"] = "other loot"
-- Brief BQ30 addendum (QA item 95): the use now words, an elixir or scroll, and a buff food.
L["Use it now to get a buff"] = "Use it now to get a buff"
L["Eat it now to get a buff"] = "Eat it now to get a buff"
L["Use it: starts a quest"] = "Use it: starts a quest"
-- Brief BQ13: the demo state (Core/Demo.lua): the tooltip's marker while any of it is on
-- (UI/Tooltip.lua Tooltip.DemoMarker), the usage line and the no profession line (UI/Slash.lua).
L["Demo state on, not your real character"] = "Demo state on, not your real character"
L["Pretend your specs, talents, quests and bags for a test; demo off restores everything"] =
  "Pretend your specs, talents, quests and bags for a test; demo off restores everything"
L["Demo: no professions"] = "Demo: no professions"
-- Brief BQ15: the "Rewards (2)" group under a quest in Used by (Core/ViewModel.lua), and the
-- Predicted mark's words on a Classic Era reward of a quest the Forever client lists (UI/Badges.lua).
L["Rewards (%d)"] = "Rewards (%d)"
L["Classic Era reward, not yet seen in Forever"] = "Classic Era reward, not yet seen in Forever"
-- Brief BQ16 (the owner's ruling of 2026-10-10, QA item 8): a quest need in the levelling line's
-- shape, "Westfall Stew (II) (9 / 8 needed)" (Core/Keep.lua Keep.NeedWords).
L["%s (%d / %d needed)"] = "%s (%d / %d needed)"
-- Brief BQ18 (the owner's rulings of 2026-10-10, QA items 11 and 12): a worn piece a carried one
-- beats (Keep.TagReasons). The working stock's own lines went with the owner's QA item 43.
L["Better gear in your bags: %s"] = "Better gear in your bags: %s"
-- Brief BQ24 (QA 2026-10-10 item 23): the quest count line's words after the quest lines that name
-- some of what it counts (UI/Tooltip.lua Tooltip.FoldQuestCount).
L["and %d other quest"] = "and %d other quest"
L["and %d other quests"] = "and %d other quests"
-- Brief BQ24 (QA item 25): the tooltip of "Show nearest" on the trainer search's divider (UI/Frame.lua
-- Frame.PaintSearchNearest).
L["Finds the nearest of these trainers and sets a waypoint."] =
  "Finds the nearest of these trainers and sets a waypoint."
-- Brief BQ24 (QA item 35): the red gem's words on the Professions tab (UI/Frame.lua
-- Frame.ProfessionsAlert) and on a profession's row in the tab (ItemTree_Professions UI/Pane.lua).
L["Some of your professions can be levelled up"] = "Some of your professions can be levelled up"
L["%s can be levelled up"] = "%s can be levelled up"
-- Brief BQ23 (the owner's QA of 2026-10-10, item 38): a camp item's keep line (Core/Keep.lua).
L["Camp item: a buff at a campfire"] = "Camp item: a buff at a campfire"
-- Brief BQ25c (the owner's QA of 2026-10-10, item 52): the bag rule's lines, like compared with like
-- (Core/Keep.lua Keep.BagFacts): a Keep's words, and a bag no better than the equipped one's, muted.
L["Your ranged weapon does not use arrows"] = "Your ranged weapon does not use arrows"
L["Your ranged weapon does not use bullets"] = "Your ranged weapon does not use bullets"
L["Fills an empty bag slot"] = "Fills an empty bag slot"
L["Bigger than your %d slot bag"] = "Bigger than your %d slot bag"
L["Smaller than your %d slot bag"] = "Smaller than your %d slot bag"
L["No bigger than your %d slot bag"] = "No bigger than your %d slot bag"
L["No quiver equipped"] = "No quiver equipped"
L["No ammo pouch equipped"] = "No ammo pouch equipped"
L["Faster quiver than yours"] = "Faster quiver than yours"
L["Faster ammo pouch than yours"] = "Faster ammo pouch than yours"
L["Slower than your quiver"] = "Slower than your quiver"
L["Slower than your ammo pouch"] = "Slower than your ammo pouch"
L["Bigger than your %d slot quiver"] = "Bigger than your %d slot quiver"
L["Bigger than your %d slot ammo pouch"] = "Bigger than your %d slot ammo pouch"
L["Smaller than your quiver"] = "Smaller than your quiver"
L["Smaller than your ammo pouch"] = "Smaller than your ammo pouch"
L["No better than your quiver"] = "No better than your quiver"
L["No better than your ammo pouch"] = "No better than your ammo pouch"
L["Soul bags are for warlocks"] = "Soul bags are for warlocks"
L["No soul bag equipped"] = "No soul bag equipped"
L["Bigger than your %d slot soul bag"] = "Bigger than your %d slot soul bag"
L["No bigger than your %d slot soul bag"] = "No bigger than your %d slot soul bag"
L["Not for your professions"] = "Not for your professions"
L["Fills your empty reagent bag slot"] = "Fills your empty reagent bag slot"
L["Bigger than your %d slot reagent bag"] = "Bigger than your %d slot reagent bag"
L["No bigger than your %d slot reagent bag"] = "No bigger than your %d slot reagent bag"
-- Brief BQ30 (the owner's spot fix of 2026-10-10, QA item 91): a spec row's muted note in Settings
-- for a spec that counts only from a level (UI/Options.lua Options.SpecLabel).
L["from level %d"] = "from level %d"
-- Brief BQ30 addendum (the owner's ruling of 2026-10-10, QA item 92): the [Equip] tag names the
-- specs it is for in short form (Core/Keep.lua Keep.TagWord, Core/Gear.lua Gear.SPEC_SHORT).
L["Equip (%s)"] = "Equip (%s)"
L["(%s)"] = "(%s)"
L["BM"] = "BM"
L["MM"] = "MM"
L["Surv"] = "Surv"
L["Prot"] = "Prot"
L["Ret"] = "Ret"
L["Assa"] = "Assa"
L["Sub"] = "Sub"
L["Disc"] = "Disc"
L["Ele"] = "Ele"
L["Enh"] = "Enh"
L["Resto"] = "Resto"
L["Affl"] = "Affl"
L["Destro"] = "Destro"
L["Bal"] = "Bal"
L["Feral"] = "Feral"

-- Brief BQ29: the Well Fed aura the buff food Use rule reads (Keep.FedState).
L["Well Fed"] = "Well Fed"

-- Brief PT32: the Professions tab setting's second hover sentence (UI/ProfessionsStub.lua).
L["On by default. Turn it off to hide the tab and stop keeping reagents for your routes."] =
  "On by default. Turn it off to hide the tab and stop keeping reagents for your routes."

-- Brief GW1 (the owner's rulings, QA items 97, 101 and 102): the gear line's reasons (Keep.GearWords)
-- and a cosmetic piece's own kind (Keep.ActionWords, Keep.SaleReasons).
L["Not for your class (%s only)"] = "Not for your class (%s only)"
L["Not for your class (off hand weapon)"] = "Not for your class (off hand weapon)"
L["Not an upgrade at level %d"] = "Not an upgrade at level %d"
L["Needs level %d"] = "Needs level %d"
L["Use it to collect the appearance"] = "Use it to collect the appearance"
L["Appearance collected"] = "Appearance collected"
L["Not for your specs"] = "Not for your specs"

-- Brief GW1b (the review of GW1): the gear line for a grey piece beyond the look ahead, and for a
-- wearable piece whose compare could not be made (Keep.GearWords).
L["Poor quality"] = "Poor quality"
L["Nothing to compare"] = "Nothing to compare"

-- Brief WL1 (QA item 108, the owner's ruling "A"): the Worthless tag's word (Keep.TagWord); its muted
-- line "No sell price" went with brief TV1 (the note on the tag row, below).
L["Worthless"] = "Worthless"

-- Brief TR1 (QA items 111, 112, 114): a trainer's Trains tab rows (Core/ViewModel.lua TrainsLabel,
-- TRAINS_RANK_NAMES) and the muted line for a trainer whose teaching nothing records (EMPTY_TEXT).
L["Master"] = "Master"
L["Teaches %s up to %s"] = "Teaches %s up to %s"
L["Trainer (what they teach is not recorded yet)"] = "Trainer (what they teach is not recorded yet)"

-- Brief TR1c (QA item 127): the muted line under a map whose pins include an owner confirmed
-- claim's approximate position (UI/Map.lua Map.APPROXIMATE).
L["Approximate position"] = "Approximate position"

-- Brief TR2 (QA item 128): a trainer's Teaches tab: a rank spell's row, its rank word then its
-- profession ("Apprentice Mining", Core/ViewModel.lua RankSpellLabel), and the line of a profession
-- whose top rank is not known (TrainsLabel).
L["%s %s"] = "%s %s"
L["Teaches %s"] = "Teaches %s"

-- Brief OL1 (QA item 132): a chest's Loot tab and an openable item's Contains tab with nothing in
-- them, which only "Show predicted data" off reaches (Core/ViewModel.lua EMPTY_TEXT).
L["Nothing known to be inside this"] = "Nothing known to be inside this"

-- Brief NR1b (QA item 134): the muted words after the "Show nearest" line where no trainer who
-- teaches the player's next rank has a known position (Core/Nearest.lua Nearest.FALLBACK_NOTE).
L["(may not teach your next rank: none who does has a known position)"] =
  "(may not teach your next rank: none who does has a known position)"

-- Brief K31 (feedback item 144): the profession tool rule (Core/Keep.lua): the best tool the player
-- carries for one of their professions ("Tool for Skinning" since brief UL1), every other copy ("Spare Skinning tool"),
-- a tool for a profession the player lacks ("Tool for Mining"), and the words where the tables do
-- not name the profession.
L["Spare %s tool"] = "Spare %s tool"
L["Tool for %s"] = "Tool for %s"
L["Profession tool"] = "Profession tool"
L["Spare profession tool"] = "Spare profession tool"
L["Tool for another profession"] = "Tool for another profession"

-- Brief BG1 (QA item 83, the owner's rulings of 2026-10-13): the spare bag rule (Core/Keep.lua): a
-- spare bag kept for the bank and alts, a bound one kept for the player's own bank, and the bank
-- read where the bank is known. QA item 153: never a quiver or ammo pouch.
L["Useful for bank and alts"] = "Useful for bank and alts"
L["Useful for your bank"] = "Useful for your bank"
L["Fills an empty bank slot"] = "Fills an empty bank slot"
L["Bigger than your bank bag"] = "Bigger than your bank bag"

-- Brief QB2: the client's quest cache. The Changed mark's words on a Classic Era reward the quest no
-- longer hands over in Forever (UI/Badges.lua), and the line a quest page's Classic Era rewards sit
-- under when Forever hands over others (UI/InfoPanel.lua).
L["Classic Era reward, no longer handed over in Forever"] = "Classic Era reward, no longer handed over in Forever"
L["Classic Era rewards, changed in Forever"] = "Classic Era rewards, changed in Forever"

-- QA item 153 (the owner, 2026-10-14): a quiver or ammo pouch upgrade the character cannot wear yet,
-- kept until its required level (Core/Keep.lua ammoUpgrade).
L["Quiver upgrade at level %d"] = "Quiver upgrade at level %d"
L["Ammo pouch upgrade at level %d"] = "Ammo pouch upgrade at level %d"
-- Brief fix156 (owner QA 2026-10-14 item 156): a class trainer's Teaches tab, in its own title
-- ("Hunter Trainer: teaches class spells, which ItemTree does not list").
L["%s: teaches class spells, which ItemTree does not list"] = "%s: teaches class spells, which ItemTree does not list"
-- QA item 158 (the owner, 2026-10-14): the muted line for the quests the player cannot take yet,
-- folded under the uses modifier on the tooltip (UI/Tooltip.lua Tooltip.FoldAheadQuests).
L["1 quest from level %d"] = "1 quest from level %d"
L["%d quests from level %d"] = "%d quests from level %d"
-- Brief F160 (owner QA 2026-10-14, item 160): a bag hovered in the bag slot it is in use in (the bag
-- bar, a bank bag slot), and a reagent bag upgrade the character cannot use yet (Core/Keep.lua
-- reagentVerdict).
L["Equipped bag"] = "Equipped bag"
L["Equipped bank bag"] = "Equipped bank bag"
L["Reagent bag upgrade at level %d"] = "Reagent bag upgrade at level %d"
-- Brief GF5: the predicted quest facts. An objective's kind in the Quest tab's type column and its
-- line on the quest page (Core/ViewModel.lua ObjectiveLine), the quests before and after it, and the
-- one money and XP line (Core/QuestsPredicted.lua MoneyXpText).
L["Kill"] = "Kill"
L["Collect"] = "Collect"
L["Kill %d %s"] = "Kill %d %s"
L["Collect %d %s"] = "Collect %d %s"
L["Use %d %s"] = "Use %d %s"
L["Use %s"] = "Use %s"
L["Previous quest"] = "Previous quest"
L["Next quest"] = "Next quest"
L["%s, %d XP"] = "%s, %d XP"
L["%d XP"] = "%d XP"
-- Brief K14 (ruling 2, owner 2026-10-14): a profession bag weighed in the normal bag slots against the
-- smallest profession bag worn there (Core/Keep.lua professionSlotsVerdict).
L["Bigger than your %d slot profession bag"] = "Bigger than your %d slot profession bag"
-- Brief BG4 (owner QA 2026-10-17, items 184 to 186): the reagent bag slot weighed by slots whatever bag
-- is in it (Core/Keep.lua slotWords), and a profession bag no better in either place
-- (professionVerdict). They replace "Your reagent bag slot holds a ...".
L["Upgrade for your reagent bag slot"] = "Upgrade for your reagent bag slot"
L["Smaller than the bag in your reagent bag slot"] = "Smaller than the bag in your reagent bag slot"
L["No bigger than the bag in your reagent bag slot"] = "No bigger than the bag in your reagent bag slot"
L["Worse than your current bags"] = "Worse than your current bags"
-- Brief BG4 follow up: a normal bag over a profession bag worn in a normal bag slot that is no smaller,
-- by the leeway (Core/Keep.lua normalVerdict).
L["Better than your %d slot profession bag"] = "Better than your %d slot profession bag"
-- Brief HF1 (owner QA 2026-10-17 item 181): the muted quest lines in the Keep block's more section for
-- the listed quests it does not count for this character (UI/Tooltip.lua Tooltip.OtherQuestLines):
-- another class's ("1 Paladin quest") and, with "Hide other faction data" off, the other side's.
L["1 %s quest"] = "1 %s quest"
L["%d %s quests"] = "%d %s quests"
L["1 quest for another class"] = "1 quest for another class"
L["%d quests for other classes"] = "%d quests for other classes"
L["1 Horde quest"] = "1 Horde quest"
L["%d Horde quests"] = "%d Horde quests"
L["1 Alliance quest"] = "1 Alliance quest"
L["%d Alliance quests"] = "%d Alliance quests"
-- Brief RB2 (owner QA 2026-10-17 item 194): the muted words the other side's player reads on the rows
-- and the page of a quest open to both that our own data leans to one side (Core/Graph.lua
-- Graph.LeanWords, ItemTree-Data RB3's lean lists).
L["Possibly Alliance only"] = "Possibly Alliance only"
L["Possibly Horde only"] = "Possibly Horde only"
-- Brief RB2 (item 205): the muted end of a trainer "Show nearest" line where a nearer trainer was
-- passed over because it does not teach the player's next rank (Core/Nearest.lua NoteNearer).
L["(%s is nearer but does not teach %s)"] = "(%s is nearer but does not teach %s)"
-- Brief RB5 (QA item 202, the owner's ruling 2 of 2026-10-14): a consumable kept far ahead for a
-- profession the player has at a lower rank, "Useful at First Aid 225" (the line unnamed: the second).
L["Useful at %s %d"] = "Useful at %s %d"
L["Useful once your skill is higher"] = "Useful once your skill is higher"
-- Brief RB1b (the owner's answer of 2026-10-17 on QA item 190, "B but make repeatable quests never
-- relevant (so always collapsed)"): the muted line the Keep block folds under the modifier for the
-- repeatable quests the item page counts and nothing keeps for (UI/Tooltip.lua OtherQuestLines).
L["1 repeatable quest"] = "1 repeatable quest"
L["%d repeatable quests"] = "%d repeatable quests"
-- Brief RB1c (the owner's ruling "A" of 2026-10-17): the folded line for the quests an instance holds
-- back where the data names no instance (UI/Tooltip.lua OtherQuestLines); a named one reads "8 Naxxramas
-- quests" through "%d %s quests". Brief LF1 (QA item 243, the owner: "This is misleading wording because
-- the quest isnt in the instance we just track the quest by if you entered the instance. So remove that
-- text"): the unnamed line says "1 quest" or "3 quests" through the keys above.
-- Brief SC1 (QA item 212, an enchanter could not click Craft all): the Craft all hover's note on the
-- recipes it leaves out for making no item, and its reasons where it cannot queue (Core/Craft.lua
-- Craft.State); and each recipe card's Show craft button, its hover and why it cannot
-- (Core/Craft.lua Craft.ShowState, UI/Pane.lua).
L["Recipes that make no item, such as enchants, are left out: use them from the profession window."] =
  "Recipes that make no item, such as enchants, are left out: use them from the profession window."
L["Nothing here makes an item to queue"] = "Nothing here makes an item to queue"
L["You have not learnt the item recipes here"] = "You have not learnt the item recipes here"
L["Show craft"] = "Show craft"
L["Opens the %s window. Find %s in its list."] = "Opens the %s window. Find %s in its list."
L["Opens the %s window."] = "Opens the %s window."
-- Brief PW1 (QA item 239 c): Show craft's hover where the click fills the window's search with the
-- recipe (Core/Craft.lua Craft.ShowState): "Opens the Leatherworking window on Embossed Leather Gloves."
L["Opens the %s window on %s."] = "Opens the %s window on %s."
L["Not with demo professions"] = "Not with demo professions"
L["You do not have %s"] = "You do not have %s"
L["You have not learnt this recipe yet"] = "You have not learnt this recipe yet"
-- Brief UI15 (QA item 209): the button on the client's profession window that opens this tab on its
-- profession (ItemTree_Professions/UI/WindowButton.lua). Item 213's hint line under the canvas went
-- with brief LF1's floating panel (its words in the LF1 block at the end of this file).
L["View in ItemTree"] = "View in ItemTree"
-- Brief TP1 (the owner's QA item 210, Tom's feedback via Chris, 2026-10-17): track another profession
-- per character on the Professions tab's list (ItemTree_Professions/UI/Track.lua): the add button and
-- its hover, the range dropdown's hover for its empty choice ("Not tracking items", the owner's
-- words), the red X's hover and a tracked row's hover. Brief LF1 reworded the dropdown's empty choice
-- and the bar's tag for a tracked profession (the LF1 block at the end of this file).
L["Track another profession"] = "Track another profession"
L["Add a profession you do not have. Pick a range under it and ItemTree keeps its items as if you had it."] =
  "Add a profession you do not have. Pick a range under it and ItemTree keeps its items as if you had it."
L["Not tracking items"] = "Not tracking items"
L["Keeps the items %s needs from %d to %d, as if you had it"] =
  "Keeps the items %s needs from %d to %d, as if you had it"
L["Stop tracking %s"] = "Stop tracking %s"
L["Tracked: you do not have %s"] = "Tracked: you do not have %s"
-- Brief CT1 (the owner, 2026-10-17, QA items 207 and 215): a class trainer's Teaches tab. A class
-- spell row's second column, "1s 80c (Rank 3)" (Core/EraSources.lua ClassSpellMeta, money first),
-- and "Learnt (Rank 3)" where the character knows it (UI/Tree.lua LearntMeta), both joined by
-- "%s (%s)" (brief LF1, QA item 241: CT1 joined them with a comma, "Rank 3, 1s 80c" and "Learnt,
-- Rank 3"); the tab's line for a class trainer whose class spells are hidden with "Show predicted
-- data" off (Core/ViewModel.lua VM:Rows).
L["Rank %d"] = "Rank %d"
L["Learnt"] = "Learnt"
L["%s: teaches class spells"] = "%s: teaches class spells"
-- And what the spell mark on such a row says when hovered (UI/Tree.lua TrainerSpellText).
L["%s spell"] = "%s spell"
L["Class spell"] = "Class spell"
-- Brief AA-RB (the owner's QA item 219, 2026-10-17: "When we know there are uses (but not for your
-- current faction) make the wording 'No known uses for [your_faction]'"): the uses line, the item
-- page's summary and Used by tab, and the Keep block under Always or Never, where every use the item
-- had was a quest of the other side (UI/Tooltip.lua Tooltip.NoUsesWords, Core/ViewModel.lua
-- ViewModel.NoUsesText, Core/Keep.lua Keep.NoUsesWords).
L["No known uses for Alliance"] = "No known uses for Alliance"
L["No known uses for Horde"] = "No known uses for Horde"
-- Brief AA-RB (QA item 216): a toy's one Keep reason (Core/Keep.lua Keep.KEEP_TOY), as Jettison locks
-- it ("Locked: toy").
L["Toy"] = "Toy"
-- Brief WS1 (the owner's ruling "A for writs" of 2026-10-17 night, QA item 226): the folded line for the
-- quests an item starts that the character holds no starter of and has not got in the log (UI/Tooltip.lua
-- OtherQuestLines, Core/QuestFlags.lua STARTER_GATE); they never keep an item until then. Brief LF1
-- (QA item 243) reworded it (the LF1 block at the end of this file).
-- Brief LF1 (the owner's QA items 240, 241 and 243, 2026-10-18, look and feel). The Professions tab
-- (ItemTree_Professions/UI/Track.lua): a tracked profession's range dropdown, its empty choice in the
-- field and the list ("Instead of a tracking option being just 'None' it should be 'No level
-- tracking'"), and the bar's tag for it, the qualifier in brackets ("[Profession] (tracking X to Y)
-- or [Profession] (not tracking)"). The canvas's floating hotkey panel (ItemTree_Professions/UI/
-- Pane.lua Pane.HINTS): each action's word under its picture (the keycap's "Shift" and the "+" are
-- the keys already above). And the tooltip's folded line for the quests started by an item the
-- character does not have (UI/Tooltip.lua OtherQuestLines), its qualifier in brackets ("1 quest
-- (started by an item you don't have)"). And a craft row's tooltip block (UI/Tree.lua
-- Tree.IngredientLines, item 246: "Ingredients should be in white and have a colon. The quantities
-- should be [N] x [incgredient]"): its heading, and a reagent's line for a stated range ("%d x %s",
-- the single count's, is the key above).
L["No level tracking"] = "No level tracking"
L["%s (tracking %d to %d)"] = "%s (tracking %d to %d)"
L["%s (not tracking)"] = "%s (not tracking)"
L["Zoom"] = "Zoom"
L["Pan"] = "Pan"
L["Scroll"] = "Scroll"
L["1 quest (started by an item you don't have)"] = "1 quest (started by an item you don't have)"
L["%d quests (started by items you don't have)"] = "%d quests (started by items you don't have)"
L["Ingredients:"] = "Ingredients:"
L["%d to %d x %s"] = "%d to %d x %s"
-- Brief SL1 (the owner's item 244, 2026-10-18): the help line for the bare /itemtree, which opens the
-- window the minimap button's left click opens (UI/Slash.lua Slash.UsageLines).
L["Open the ItemTree window"] = "Open the ItemTree window"
-- Brief TW1 (the owner's ruling "2.A", 2026-10-18): the races a racial class spell is limited to, in
-- brackets after its name on a class trainer's Teaches tab ("Starshards (Night Elf)"), where the
-- client cannot name the race itself (Core/EraSources.lua EraSources.RACES; Undead, Alliance and Horde
-- are older keys).
L["Human"] = "Human"
L["Orc"] = "Orc"
L["Dwarf"] = "Dwarf"
L["Night Elf"] = "Night Elf"
L["Tauren"] = "Tauren"
L["Gnome"] = "Gnome"
L["Troll"] = "Troll"
-- Brief TT2 (the owner's item 247, 2026-10-18): the hint on a search dropdown row's tooltip where
-- click to open is off or a left click, which a plain click on the row answers (UI/Tooltip.lua
-- Tooltip.RowHintText); the search box holds the keyboard there, so the key is not named.
L["Click for the full tree"] = "Click for the full tree"
-- Brief SC2 (the owner's items 262 and 263, 2026-10-18): the Show craft hover where the profession
-- window already shows the line (ItemTree_Professions/Core/Craft.lua Craft.ShowState), and the
-- route header's View profession button (Craft.ViewState).
L["The %s window is open. Find %s in its list."] = "The %s window is open. Find %s in its list."
L["The %s window is open."] = "The %s window is open."
L["View profession"] = "View profession"
-- Brief TW3 (the owner's ruling "A", 2026-10-18): what the spell mark on a pet trainer's row says when
-- hovered (UI/Tree.lua TrainerSpellText).
L["Pet ability"] = "Pet ability"

-- Brief RB2B (QA item 267, the owner: "peacebloom is never needed to level herbalism (you gain levels
-- from picking herbs)"): a gathering trade's grey recipe line, and a tracked range's (Core/Keep.lua
-- Keep.GatherSpareWords).
L["Below your current %s level"] = "Below your current %s level"
L["Below your current profession levels"] = "Below your current profession levels"
L["Outside your %s range (tracked)"] = "Outside your %s range (tracked)"

-- Brief SC5 (the owner's items 284 and 289, 2026-10-20): the Show craft button's words where its click
-- is a step before the one that lands on the recipe, and their hovers (ItemTree_Professions/Core/
-- Craft.lua Craft.ShowState): it opens the profession window on the line first, or readies a window
-- already up on it.
L["Find recipe"] = "Find recipe"
L["Opens the %s window first. Then Show craft finds %s."] = "Opens the %s window first. Then Show craft finds %s."
L["Readies the %s window. Then Show craft finds %s."] = "Readies the %s window. Then Show craft finds %s."
-- Brief NW1 (the owner's standing rule of 2026-10-20): the last line of a map spot's tooltip where the
-- spot rests on one report nobody has checked in game, its pin drawn dimmed (UI/Map.lua Map.SpotLines).
L["Weak indicator"] = "Weak indicator"

-- Brief ST1 (QA items 279 and 285): the key buttons' capture prompt and hover, now that both of a
-- row's two buttons listen for a key or a gamepad button (UI/Options.lua), and the Use mark's row
-- under Keep marks (UI/Options.lua, UI/Overlay.lua Overlay.UseMarkOn). Brief ST3: its hover is in the
-- ST3 block at the end of the file.
L["Press a key or button"] = "Press a key or button"
L["Click, then press a key or a gamepad button. Right click to clear it."] =
  "Click, then press a key or a gamepad button. Right click to clear it."
L["Use mark"] = "Use mark"
-- Brief CH1 (owner QA 2026-10-18 item 249, with item 270's note): the line an NPC's Quests tab draws
-- where "Hide other faction data" took every quest out (Core/ViewModel.lua VM:_NoQuestsText).
L["No known quests for Alliance"] = "No known quests for Alliance"
L["No known quests for Horde"] = "No known quests for Horde"

-- Brief TY1 (owner item 235): the thank you note under the Share link after an update (UI/Share.lua
-- UIShare.NoticeText), the whole message in one key, and the developer only help line for /itemtree
-- demo share, which shows the note beside the ping (UI/Slash.lua; was brief SH8's ping only line).
-- luacheck: push ignore 631
L["If you enjoyed ItemTree during the beta, please help make it better by sending your game data through the link above. Thank you for trying ItemTree, and for your feedback."] =
  "If you enjoyed ItemTree during the beta, please help make it better by sending your game data through the link above. Thank you for trying ItemTree, and for your feedback."
-- luacheck: pop
L["Replay the Share link's ping and its thank you note"] = "Replay the Share link's ping and its thank you note"

-- Brief PS1 bundle prices (QA item 300): a vendor's money price with the bundle it buys, "25c for 5"
-- (Core/Sources.lua Sources.BundlePrice: Sold by and Sells rows, the Buy price line).
L["%s for %d"] = "%s for %d"

-- Brief JG1 (item 302, a player's Grimoire of Torment (Rank 2) read as a sale): a warlock's demon
-- grimoire, kept until the demon is known to have learnt it (Core/Keep.lua Keep.PetBookWords,
-- Keep.PetBookLearntWords): the demons and their abilities (Keep.DEMON_BOOKS; "Felhunter" is above,
-- a creature family), the keep's reason and the learnt book's muted line.
L["Imp"] = "Imp"
L["Voidwalker"] = "Voidwalker"
L["Succubus"] = "Succubus"
L["Firebolt"] = "Firebolt"
L["Blood Pact"] = "Blood Pact"
L["Fire Shield"] = "Fire Shield"
L["Phase Shift"] = "Phase Shift"
L["Torment"] = "Torment"
L["Sacrifice"] = "Sacrifice"
L["Consume Shadows"] = "Consume Shadows"
L["Suffering"] = "Suffering"
L["Lash of Pain"] = "Lash of Pain"
L["Soothing Kiss"] = "Soothing Kiss"
L["Seduction"] = "Seduction"
L["Lesser Invisibility"] = "Lesser Invisibility"
L["Devour Magic"] = "Devour Magic"
L["Tainted Blood"] = "Tainted Blood"
L["Spell Lock"] = "Spell Lock"
L["Paranoia"] = "Paranoia"
L["Teaches your %s %s"] = "Teaches your %s %s"
L["Learnt by your %s"] = "Learnt by your %s"
-- Brief CS1 (the owner's ruling A of 2026-10-20, QA item 304): the last line of a Confirmed spot's pin
-- (UI/Map.lua Map.SpotLines), a spot a player's recorded find backs, with the creature's name, and the
-- same without one. A Reported spot's pin closes on "Reported by players", a weak one's on "Weak
-- indicator" (both above).
L["Confirmed: a player found %s here"] = "Confirmed: a player found %s here"
L["Confirmed: a player found it here"] = "Confirmed: a player found it here"

-- Brief CB1 (item 305): a book that teaches the player a spell of their own class, kept until the
-- player is known to have learnt it (Core/Keep.lua Keep.ClassBookWords: "Teaches you Arcane
-- Brilliance (Rank 1)"; a learnt one reads the muted "Learnt" above).
L["Teaches you %s"] = "Teaches you %s"
-- Brief TY2 (owner item 311): the thank you note's heading after ItemTree's mark (UI/Share.lua
-- UIShare.NoticeHeading), and the developer only test of its once only showing, /itemtree demo share
-- due and reset (UI/Share.lua UIShare.NoticeCommand): its help line (UI/Slash.lua) and its three
-- answers.
L["Thanks for your support"] = "Thanks for your support"
L["Show the thank you note as an update does, or forget that it was closed"] =
  "Show the thank you note as an update does, or forget that it was closed"
-- luacheck: push ignore 631
L["The thank you note is due, as after an update. Close it with its X or the link, then /reload and open ItemTree: it stays away."] =
  "The thank you note is due, as after an update. Close it with its X or the link, then /reload and open ItemTree: it stays away."
L["The thank you note was closed on this account, so it stays away, as after an update. /itemtree demo share reset brings it back."] =
  "The thank you note was closed on this account, so it stays away, as after an update. /itemtree demo share reset brings it back."
L["The thank you note is forgotten: not due and not closed. /itemtree demo share due shows it again."] =
  "The thank you note is forgotten: not due and not closed. /itemtree demo share due shows it again."
-- Brief FF1: the answer to /itemtree demo share due while UIShare.NOTICE_ID is nil (no note on live).
L["No thank you note is switched on in this build, so none is ever due. /itemtree demo share still shows its words."] =
  "No thank you note is switched on in this build, so none is ever due. /itemtree demo share still shows its words."
-- luacheck: pop
-- Brief ST2 (QA item 307, the owner's ruling A): the two settings headings by family (UI/Options.lua
-- BADGES_SECTION and KEEP_SECTION, drawn through L), Badge size's label and hover under the first,
-- the Mark size slider under the second, and the Use mark example's caption for a switched off
-- Use mark (UI/OptionsPreview.lua KeepModel; "Use mark" itself is above). Brief ST3: the first
-- heading and the caption are in the ST3 block below.
L["Keep and Use marks"] = "Keep and Use marks"
L["Badge size"] = "Badge size"
L["How big the New and Changed badges and the profession icon are on bag and bank slots."] =
  "How big the New and Changed badges and the profession icon are on bag and bank slots."
L["Mark size"] = "Mark size"
L["How big the Keep and Use marks in a corner of bag and bank slots are."] =
  "How big the Keep and Use marks in a corner of bag and bank slots are."
L["Styles that frame the whole slot stay the slot's size."] = "Styles that frame the whole slot stay the slot's size."
-- Brief ST3 (QA items 315 to 320, the round AH settings notes): the Forever badges heading (UI/Options.lua
-- BADGES_SECTION and UI/ProfessionsStub.lua BAG_SECTION, drawn through L; it read New and Changed
-- badges), the two place switches under its "Where" sub heading ("Where" itself is above) and their
-- hovers, the Use mark's hover and its example's caption in the owner's words (item 319, ruling A),
-- and the spec rows' hover in his words (item 320, ruling A: unticking every spec turns gear
-- suggestions off).
L["Forever badges"] = "Forever badges"
L["In your bags"] = "In your bags"
L["In your bank"] = "In your bank"
L["Shows every ItemTree badge on your bag slots: New, Changed and the profession icon."] =
  "Shows every ItemTree badge on your bag slots: New, Changed and the profession icon."
L["Shows every ItemTree badge on your bank slots: New, Changed and the profession icon."] =
  "Shows every ItemTree badge on your bank slots: New, Changed and the profession icon."
L["Off hides them all there. Keep and Use marks have their own switches."] =
  "Off hides them all there. Keep and Use marks have their own switches."
L["The blue play mark on bag items you can use or open now."] =
  "The blue play mark on bag items you can use or open now."
L["Off: these items wear the Keep mark instead."] = "Off: these items wear the Keep mark instead."
L["Use mark off: shows the Keep flag"] = "Use mark off: shows the Keep flag"
L["Tick the specs you play."] = "Tick the specs you play."
L["ItemTree suggests gear upgrades only for ticked specs."] = "ItemTree suggests gear upgrades only for ticked specs."
L["Untick them all to turn gear suggestions off."] = "Untick them all to turn gear suggestions off."
L["This character only."] = "This character only."
-- Brief KC2 (QA items 335 and 336): the key buttons' hover lines on the client's gamepad mode (UI/Options.lua
-- Options.PAD_MODE_TIP): the game's bags and windows keep their own buttons.
L["Gamepad mode: the game's bags and windows keep their own buttons,"] =
  "Gamepad mode: the game's bags and windows keep their own buttons,"
L["so a key here may not work while they are open."] = "so a key here may not work while they are open."
-- Brief RP-AI (ST3's note on QA item 320): the muted gear line of a weapon or armour piece while every
-- "Suggest gear for" box is unticked (Core/Keep.lua Keep.GearWords, score.gearOff).
L["Gear suggestions off"] = "Gear suggestions off"
-- Brief AM1 (QA item 330): the reason line of ammo the worn ranged weapon fires, kept as Jettison locks
-- it (Core/Keep.lua Keep.AmmoWords).
L["Ammo for your bow"] = "Ammo for your bow"
L["Ammo for your crossbow"] = "Ammo for your crossbow"
L["Ammo for your gun"] = "Ammo for your gun"
-- Brief SM1 (QA item 329, the owner: "change the setting name"): the questBadges row reads Show New
-- on quests and rewards, since the title's Changed badge is rare (UI/Options.lua). Rule and tooltip unchanged.
L["Show New on quests and rewards"] = "Show New on quests and rewards"
-- Brief EQ2 (QA item 342, the owner 2026-10-21: "Let's add "Any spec" to make it clear what any means"):
-- the [Equip] tag's label where every spec open to the class wants the piece, "Equip (Any spec)"
-- (Core/Keep.lua Keep.EquipSpecWords; it read "Any", the key removed from the BQ30 block above).
L["Any spec"] = "Any spec"
-- Brief TV1 (QA item 347, the tooltip audit's rulings of 2026-10-21): the three way tie's note on the
-- tag row and the Worthless tag's (Core/Keep.lua Keep.TagNote); the Hearthstone's reason (Keep.TagReasons);
-- a cosmetic collected by wearing it (Keep.ActionWords); a companion pet item (Keep.TagReasons); a recipe
-- item's state line (Keep.RecipeWords); a white piece past the look ahead (Keep.GearWords, was "Common
-- quality"); the uses fold with no line above it (UI/Tooltip.lua Tooltip.FoldUses).
L["(Not enough AH data)"] = "(Not enough AH data)"
L["(No sell price or use)"] = "(No sell price or use)"
L["Takes you back to your inn"] = "Takes you back to your inn"
L["Wear it to collect the appearance"] = "Wear it to collect the appearance"
L["Use it to learn this companion"] = "Use it to learn this companion"
L["Already known"] = "Already known"
L["Not your profession (%s)"] = "Not your profession (%s)"
L["Low quality"] = "Low quality"
L["%d uses, hold %s"] = "%d uses, hold %s"
-- Brief TV4 (QA item 347, the owner's ruling C2 and designs 1 to 6 of 2026-10-21): the inner
-- tooltips of rows in the window, in the game tooltip's label and value lines. A map spot in brackets
-- (Core/Sources.lua Sources.SpotText), a level band (Sources.LevelRange); the quest card
-- (UI/InfoPanel.lua InfoPanel.QuestTooltipLines); a source row's lines and spot tiers (UI/Tree.lua
-- Tree.SourceTipLines, Tree.KnownLocationLines, Tree.CreatureFooter); the item facts block
-- (InfoPanel.TooltipLines, design 6).
L["[%s]"] = "[%s]"
L["[%s: %s]"] = "[%s: %s]"
L["%s - %s"] = "%s - %s"
L["Not completed"] = "Not completed"
L["(Choose one)"] = "(Choose one)"
L["%s x %s"] = "%s x %s"
L["%s (quest drop)"] = "%s (quest drop)"
L["Known location"] = "Known location"
L["Known locations"] = "Known locations"
L["+%d more on map"] = "+%d more on map"
L["Confirmed"] = "Confirmed"
L["Reported"] = "Reported"
L["Price"] = "Price"
L["Drop chance"] = "Drop chance"
L["%s (Classic Era)"] = "%s (Classic Era)"
L["Classic Era drop rate"] = "Classic Era drop rate"
L["Quest only drop"] = "Quest only drop"
L["Player sightings"] = "Player sightings"
L["Click the creature name to see more info"] = "Click the creature name to see more info"
L["Item level %s"] = "Item level %s"
L["Requires level %s"] = "Requires level %s"
L["Max stack"] = "Max stack"
L["Buy price (x %s)"] = "Buy price (x %s)"
-- Brief FN2 (QA item 347 F, the owner's ruling of 2026-10-21): a [Keep] resting on a counted need reads
-- "Keep (22)", 22 the amount required, in its words (Core/Keep.lua Keep.TagWord) as on its tag row.
-- QA item 347j (his choice A): the Keep switch's hover on an item's page, a title and one line per
-- segment (UI/Frame.lua Frame.KeepSwitchTip).
L["Keep (%s)"] = "Keep (%s)"
L["Keep this item?"] = "Keep this item?"
L["Auto: ItemTree decides from what it is used for"] = "Auto: ItemTree decides from what it is used for"
L["Always: always marked Keep"] = "Always: always marked Keep"
L["Never: never kept, shows how to sell it"] = "Never: never kept, shows how to sell it"
L["Off: no Keep or sell tags on this item"] = "Off: no Keep or sell tags on this item"
-- Brief UL1 (QA items 347g to 347i, 355 and 356, the owner's design-5): the uses lines in the Keep
-- block's shape (Core/Keep.lua). A crate in the need shape with no count read ("Waylaid Supplies (20
-- needed)"), the quests finished as their own lines with the qualifier in brackets, and a recipe item's
-- state ("Learn it now", "Learn it (Requires Enchanting 290)").
L["%s (%d needed)"] = "%s (%d needed)"
L["1 quest (completed)"] = "1 quest (completed)"
L["%d quests (completed)"] = "%d quests (completed)"
L["1 quest (abandoned)"] = "1 quest (abandoned)"
L["%d quests (abandoned)"] = "%d quests (abandoned)"
L["Learn it now"] = "Learn it now"
L["Learn it (Requires %s %d)"] = "Learn it (Requires %s %d)"
-- Brief UL2 (QA item 366): an item combine that is no supply crate (a toy) reads as before UL1.
L["%s needs %d"] = "%s needs %d"
-- Brief QX1 (the owner's words of 2026-10-22, quest items you no longer need): a finished quest item's
-- reason lines under its [Vendor] or [Worthless] tag (Core/Keep.lua Keep.FinishedLines), the quest's
-- title in straight double quotes; several quests of one kind add "and N more" ("%s and %d more").
L["KEEP_QUEST_COMPLETE"] = 'Quest complete: "%s"'
L["KEEP_QUEST_ABANDONED"] = 'Quest abandoned: "%s"'
-- Brief AQF1 fix 4 (the owner's ruling "A" of 2026-10-22, QA item 380, his accepted words): a quest never
-- taken that is grey for the player, a chain end and not in the log, after the complete and abandoned lines.
L["KEEP_QUEST_BELOW_LEVEL"] = 'Quest below your level: "%s"'
-- Brief UX1 (QA item 402, the owner, 2026-10-23): the toast a waypoint ItemTree sets puts up
-- (UI/Toast.lua), its title and what the waypoint is for: a quest's NPC or objective (UI/Map.lua
-- Map.QuestPlaces) and an NPC Show nearest found (Core/Nearest.lua Nearest.WaypointFor).
L["Waypoint added"] = "Waypoint added"
L["%s, gives %s"] = "%s, gives %s"
L["%s, turn in for %s"] = "%s, turn in for %s"
L["Objective for %s"] = "Objective for %s"
L["%s, nearest trainer"] = "%s, nearest trainer"
L["%s, nearest vendor"] = "%s, nearest vendor"
-- Brief UX1 (QA item 403): the trainer button beside the dice (UI/Frame.lua), its hover title and
-- the search it runs ("Searches t:warlock").
L["Find your class trainers"] = "Find your class trainers"
L["Searches %s"] = "Searches %s"
-- Brief TD1 (a player's CurseForge comment, the owner's ruling of 2026-10-23): the Tooltip display
-- section (UI/Options.lua TOOLTIP_SECTION, it was Tooltips), a switch per kind of ItemTree tooltip
-- line (UI/Tooltip.lua Tooltip.CATEGORY_KEYS), and the hover words of every row in it.
L["Tooltip display"] = "Tooltip display"
L["Show Keep and sell tags"] = "Show Keep and sell tags"
L["Shows the [Keep], [Use], [Vendor] and [Worthless] tags and their counts."] =
  "Shows the [Keep], [Use], [Vendor] and [Worthless] tags and their counts."
L["Off leaves the lines under them, and the marks on your bag items."] =
  "Off leaves the lines under them, and the marks on your bag items."
L["Show quest lines"] = "Show quest lines"
L["Show profession lines"] = "Show profession lines"
L["Show gear lines"] = "Show gear lines"
L["Shows ItemTree's lines under an item's own tooltip lines. Off draws none of them."] =
  "Shows ItemTree's lines under an item's own tooltip lines. Off draws none of them."
L["Says if Forever added or changed the item, such as New in Forever or Changed in Forever."] =
  "Says if Forever added or changed the item, such as New in Forever or Changed in Forever."
L["Lists what the item is used for, such as Used in 6 recipes, 1 quest."] =
  "Lists what the item is used for, such as Used in 6 recipes, 1 quest."
L["Where the lines under the Keep and sell tags list the uses, they stand in for it."] =
  "Where the lines under the Keep and sell tags list the uses, they stand in for it."
L["Shows the quests that need the item, such as Riverpaw Gnoll Bounty (3 / 8 needed)."] =
  "Shows the quests that need the item, such as Riverpaw Gnoll Bounty (3 / 8 needed)."
L["And the quests you finished, such as Quest complete."] = "And the quests you finished, such as Quest complete."
L["Turn it off if another quest addon already shows them."] = "Turn it off if another quest addon already shows them."
L["The Keep and sell tags stay as they are."] = "The Keep and sell tags stay as they are."
L["Shows the recipes and professions that use the item, such as 12 x Tailoring."] =
  "Shows the recipes and professions that use the item, such as 12 x Tailoring."
L["And what your profession still needs, such as Level Cooking (12 / 40 needed)."] =
  "And what your profession still needs, such as Level Cooking (12 / 40 needed)."
L["Shows the gear lines, such as Upgrade for your Chest or Equipped."] =
  "Shows the gear lines, such as Upgrade for your Chest or Equipped."
L["Draws the quest mark, the profession icons and the Forever badges beside ItemTree's lines."] =
  "Draws the quest mark, the profession icons and the Forever badges beside ItemTree's lines."
L["The last line, which says how to open the full tree, such as Ctrl + right click for the full tree."] =
  "The last line, which says how to open the full tree, such as Ctrl + right click for the full tree."
