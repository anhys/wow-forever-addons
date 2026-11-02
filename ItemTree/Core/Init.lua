-- Addon table, saved variables and build detection.
--
-- Loaded as: local ADDON_NAME, ItemTree = ...
-- The only WoW API calls in Core live here, and each is guarded so the same file loads
-- under busted and under the browser harness. Everything decision making is a pure
-- function that takes its inputs as arguments.
local ADDON_NAME, ItemTree = ...

ItemTree.name = ADDON_NAME or "ItemTree"
ItemTree.version = "v0.1.19"
if ItemTree.version:find("^@") then
  ItemTree.version = "dev"
end

-- Locales/enUS.lua loads before this file and fills ItemTree.L; the fallback answers every key
-- with itself so the file still loads on its own.
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Saved variable defaults. ItemTreeDB is account wide; ItemTreeCharDB is per character
-- and only holds window position and size (see design: remembered per character).
ItemTree.DB_DEFAULTS = {
  version = 1,
  settings = {
    tooltipEnabled = true,
    tooltipShowBadges = true,
    tooltipShowUses = true,
    -- Brief TD1 (a player's CurseForge comment, the owner's ruling of 2026-10-23): the Tooltip display
    -- section's switches for the kinds of line a glyph tells apart (UI/Tooltip.lua
    -- Tooltip.CATEGORY_KEYS): the quest lines, the profession lines and the gear lines on item
    -- tooltips, and the Keep and sell tags (the tag row as a whole, Tooltip.TAGS_KEY) in the tooltip
    -- alone. On by default; a nil reads as on there too, so no migration: a player who never had the
    -- keys gets true, and the older tooltip switches beside them keep their keys and saved values.
    tooltipShowTags = true,
    tooltipShowQuests = true,
    tooltipShowProfessions = true,
    tooltipShowGear = true,
    -- Brief BQ7 (owner QA item 19, 2026-10-10): fold the uses that are not the player's into one
    -- line on item tooltips, on by default, and the key that shows them all while held.
    tooltipHideOtherUses = true,
    tooltipUsesModifier = "ctrl",
    -- The badge medallion and the neutral mark UI/Tooltip.lua draws beside its lines. A nil
    -- reads as on there, so this default only makes the tick box's own default explicit.
    tooltipShowIcons = true,
    tooltipShowHint = true,
    badgesNew = true,
    badgesChanged = true,
    -- Brief F155 (owner QA 2026-10-14 item 155): "Hide other faction data". On by default: the
    -- other faction's trainers, vendors and quests leave item pages, their counts, the trainer and
    -- vendor searches, the Professions tab's Trainers & vendors panel and the zone maps' NPC pins
    -- (Core/Graph.lua Graph.HidesOtherFaction is the one reader of the key). Off brings them back,
    -- marked as the other side's. No migration: a player who never had the key gets true.
    hideOtherFaction = true,
    -- Brief SR1: the search box also finds quests, vendors, zones, nodes and sets. On by default
    -- (brief SR3): the kind indexes are small and built on first use. ItemTree.MigrateSearchEverythingOn
    -- turns a saved false from before the change on once.
    searchEverything = true,
    -- Brief C1: count a minor change (an item's class, subclass or stack size, nearly always a
    -- renamed category) as Changed, and list its rows. Off by default: off, an item whose only
    -- changes are minor wears no Changed mark and its minor rows are shown nowhere (Core/Diff.lua).
    includeMinorChanges = false,
    -- Brief Q2: New in Forever and New reward marks on the quest giver's panels and the quest log
    -- (UI/QuestFlags.lua). On by default, account wide.
    questBadges = true,
    -- Brief Q5: the blue wash behind a New quest's text (brief Q4), drawn only while questBadges
    -- is on as well. On by default, account wide.
    questWash = true,
    bagOverlay = true,
    bankOverlay = true,
    -- Brief U1: the New and Changed badges on bag and bank slots, both at once. The size is a
    -- multiple of the design size (18px on a 36px slot), half by default; the corner is the
    -- client's anchor point name for the slot corner they sit in. UI/Overlay.lua reads a missing
    -- or malformed value as these same defaults.
    bagBadgeScale = 0.5,
    bagBadgeCorner = "TOPRIGHT",
    -- Brief W27: the Changed badge on bag and bank slots, off by default (the owner's ask,
    -- 2026-10-01). No migration: a player who never had the key gets false. UI/Overlay.lua
    -- reads a missing value as off too. The window's own Changed badges are badgesChanged alone.
    bagBadgesChanged = false,
    -- Brief T4: the gold glow on bag items with uses still ahead of the player, and the line in
    -- their tooltip that says why (Core/Keep.lua). On by default, account wide.
    keepMarks = true,
    -- Brief ST1 (QA item 279): the Use mark, the blue play mark on bag items to use or open now
    -- (UI/Overlay.lua), drawn while Keep marks is on. On by default; no migration.
    keepUseMark = true,
    -- Brief ST2 (QA item 307, the owner's ruling A): the Mark size slider, how big the Keep and
    -- Use marks drawn in a slot's corner are (UI/Overlay.lua Overlay.MarkSide), a multiple of
    -- today's size, so 1 is what every released build draws. No migration: bagBadgeScale keeps
    -- sizing the New and Changed badges, and the Use mark only followed it in an unreleased build.
    keepMarkScale = 1,
    -- Brief K7: how a Worth keeping item looks in the bags, and the tier ramp it is coloured by
    -- (UI/Overlay.lua KEEP_LOOKS, UI/Theme.lua keepRamps). 0 is the Classic look, the gold glow
    -- and frame together; 1 to 12 are the twelve looks /itemtree demo shows. Brief K12: set by the
    -- Style and Colours rows of the Keep marks section in Settings; the demo still overrides both
    -- in memory only. Brief K17: the Flag (12) in the Single colour set ships. No migration: a
    -- player who never chose has no key saved and gets these, a player who chose keeps the choice.
    keepStyle = 12,
    keepRamp = "single",
    -- Brief K15: the Single colour set's colour (keepRamp "single"), a key into UI/Theme.lua
    -- keepColors, or "custom" for the player's own pick from the colour picker, kept in
    -- keepColorCustom (0 to 1 per channel; the default is the keep gold, #FFC23A). Brief K17:
    -- green ships.
    keepColor = "green",
    keepColorCustom = { r = 1, g = 0.761, b = 0.227 },
    -- Brief K16: the colour a valuable item wears with the Single colour set, the same palette
    -- and Custom (keepValueColorCustom, 0 to 1 per channel). Orange is the fixed legendary orange
    -- (#FF8000) the Gold, Quality and Heat sets always use. Brief K17: Yellow ships.
    keepValueColor = "yellow",
    keepValueColorCustom = { r = 1, g = 128 / 255, b = 0 },
    -- Brief K9: an item an installed auction addon (Auctionator, Auctioneer or TSM) prices at this
    -- much or more is worth keeping, with the orange border and flame. 0 turns it off.
    -- ItemTree never scans the auction house; the price is that addon's own (Core/Prices.lua).
    -- Brief K10: in copper (1000000 is 100 gold), set on Keep.VALUE_STOPS; K9's keepValueGold is
    -- turned into it once by ItemTree.MigrateKeepValue.
    keepValueCopper = 1000000,
    -- Brief K20c (design K20 section 2): "List on the auction house when it beats the vendor by",
    -- a Core/Keep.lua BAR_STOPS key; 1.5 x the vendor price ships (the owner's assumed answer to
    -- design question 4, with a 5 silver floor, a constant). "formula" reads keepSellFormula, the
    -- player's own (Core/PriceFormula.lua), stored even where it is not understood.
    keepSellBar = "1.5x",
    keepSellFormula = "",
    minimapButton = true,
    -- Brief B1: the second minimap button, which opens the Boss loot tab. Off by default.
    bossLootMinimapButton = false,
    -- The game's own interface sounds on ItemTree's own controls (UI/Sound.lua): a tick on a
    -- toggle, a page on a tab, the character sheet's open and close on the window. On by
    -- default, because the addon is meant to sound like the rest of the interface. It governs
    -- ItemTree's cues only; the Sound Effects slider and the game's mute still apply, because
    -- every cue goes out on the SFX channel.
    interfaceSounds = true,
    -- guideLines went with brief E76. ApplyDefaults only fills missing keys and never removes
    -- one, so a guideLines a player saved before stays in the table and nothing reads it.
    -- The creature's own portrait on a Classic Era source row, drawn over the kind icon once the
    -- row has settled (UI/Tree.lua). On by default, because a list of creatures reads far better
    -- with their faces on it; off is the one setting for a slow computer, and with it off no
    -- portrait is ever asked for and every row keeps the kind icon.
    creaturePortraits = true,
    -- Brief BL12: the creature's own portrait on each Boss loot boss row, through the same call
    -- and the same queue as the source rows (UI/BossLoot.lua). On by default; off makes no
    -- portrait call at all and the rows draw their names alone, as before.
    bossPortraits = true,
    -- Draw a craft and the item it makes as one row in the Used by view, which is the row a
    -- player is reading: "Boiled Clams" the spell over "Boiled Clams" the item says it twice.
    -- On by default, because most crafts are a trained spell and the spell row says nothing the
    -- item's does not; off gives the spell and the item the two rows they have always had.
    mergeCrafts = true,
    -- Brief TC1: the footer's Total counts box. On, a reagent's count in the Sources and Requires
    -- views is multiplied by how many times the craft above it has to run, all the way down the
    -- tree; off (the default) every count is for one craft, as it always was.
    totalCounts = false,
    -- Brief SH3: the share window's Credit my character box. On, the share text carries this
    -- character's name and realm so the ItemTree site can list them among the players who helped
    -- (Core/Share.lua); off (the default) the text holds no name. The window is its only home:
    -- UI/Options.lua FOOTER_ONLY keeps it off the Settings panel.
    shareCredit = false,
    -- EXPERIMENTAL (brief E25, brief E30). How a craft row in the Used by view shows what the
    -- craft is made of: "off", "all", "tooltip", "group", "strip" or "card" (Core/ViewModel.lua
    -- CRAFT_INGREDIENT_MODES). Four ways of answering one question, each still selectable on its
    -- own so the owner can compare them in game; "all" is the default and draws three of them
    -- together, the tooltip block, the group and the item column's Recipe card.
    craftIngredients = "all",
    density = "default", -- or "compact"
    showPredicted = true,
    -- Brief GS3: draw the guessed sources (Core/GuessSources.lua) in an item's Sources view, marked
    -- Guess in their own colour and below every real row. On by default; off draws the view as it
    -- was before guesses existed. UI/Options.lua draws its row beside "Show predicted data".
    showGuessSources = true,
    -- Brief D3: show the items the Discovery Miner found on the beta realm, which the data ships
    -- as ordinary items. On by default; off puts each back behind its stub (Core/Data.lua).
    showHarvested = true,
    -- Brief D5: show what Classic Era said about an item the build withholds (its name, stats,
    -- icon and sources) before the player's realm finds it, marked as Classic Era data. On by
    -- default; off shows the stub until the client can name the item (Core/Data.lua).
    showEraDetails = true,
    -- Brief U3: the item data ships in the load on demand addon ItemTree_Data, which loads the
    -- first time the window or a page needs it. On loads it at login instead (ItemTree.OnLogin),
    -- so the first open of the window has no pause. On by default (brief E89); off only when the
    -- player turned it off. ItemTree.MigrateLoadDataAtLogin turns a saved false on once.
    loadDataAtLogin = true,
    collectorEnabled = true,
    -- Read sources out of a source database the player has installed as another addon (All The
    -- Things, Questie). Nothing of theirs is shipped, copied or saved: Providers/ reads what is
    -- already loaded in memory and answers the graph with it. On by default, because an addon
    -- that is not installed costs nothing and one that is answers the question the window asks.
    useProviders = true,
    -- Brief S6: draw the Discoveries tab (UI/Frame.lua DECLARED_TAB_SETTINGS). Off by default
    -- (brief E96): on adds the tab at once, and nothing stops being recorded either way.
    -- ItemTree.MigrateDiscoveriesOptIn turns a saved true from before the change off once.
    showDiscoveries = false,
    -- Brief PR3: draw the Professions tab (UI/ProfessionsStub.lua, which loads the
    -- ItemTree_Professions folder at login while it is on). On by default since brief PT32.
    -- ItemTree.MigrateProfessionsOn turns a saved false from before the change on once.
    showProfessions = true,
    compareBuild = "baseline",
    -- The window's own scale, on top of the client's UI scale and on top of ItemTree.SCALE_BASE:
    -- 1.0 draws the window at the base, which is the size it is designed to open at.
    windowScale = 1.0,
    -- Which scale base the stored windowScale was written against. 1 is the rebased scale, and
    -- a settings table without it is from before the rebase and is migrated once on load.
    scaleBase = 1,
    -- The click that opens the tree for an item under the cursor, as a modifier and a button.
    clickOpen = "CTRL-RIGHT",
    -- Brief T7: Ctrl + right click on a creature's frame or nameplate opens its page
    -- (UI/ItemClick.lua). On by default; the hooks are taken either way and this gates the action.
    npcClick = true,
    -- The Summary HUD (UI/EditMode.lua): one small movable panel showing the item under the
    -- cursor. Off by default, because it is a new thing on the player's screen and they can
    -- turn it on to try it; the other three are what it draws once it is on. hudUnlocked is
    -- saved like the rest so the settings tick box has something to register against, but
    -- UI/EditMode.lua puts it back to false on every login: an unlocked panel that survived a
    -- reload would follow the player around with a selection box on it.
    hudEnabled = false,
    hudShowBadges = true,
    hudShowSummary = true,
    hudUnlocked = false,
  },
  -- Minimap button angle in degrees around the ring, account wide like most addons. No angle
  -- on a fresh account: UI/Minimap.lua places the button on a free arc of the ring the first
  -- time, then saves the angle it picked (brief MB1).
  minimap = {},
  -- Brief B1: the second minimap button's angle, placed beside the first the first time it is
  -- turned on (UI/Minimap.lua PlaceBoss), then wherever the player drags it.
  bossLootMinimap = {},
  -- Brief K4: the player's own Worth keeping word per item, { [itemId] = "always" | "never" },
  -- absent for auto (Core/Keep.lua Keep.Override). Item ids and two words only.
  keepOverrides = {},
  collector = {
    records = {},
    counts = {},
  },
  history = {
    recent = {},
    pinned = {},
  },
  -- Brief L1: the loot ledger (Core/Ledger.lua). Counts only, keyed by source: how many loot
  -- windows each creature, node, container and fishing spot gave and what came out, what each
  -- vendor's rows said, and what each quest offered and how often it was handed in. Numbers and
  -- ids only, bounded by the ledger's own caps, and recorded only while collectorEnabled is on.
  ledger = {
    creature = {},
    object = {},
    container = {},
    fishing = {},
    vendor = {},
    quest = {},
  },
  -- Brief R5a: the places store (Core/Places.lua), where things are as counts on a 1 percent map
  -- grid: places[kind][id][mapId] = { [cell] = count } with the day last touched as .d. Only
  -- instance entrances (kind "e") are written yet. Ids, map ids and counts only, bounded by
  -- Places.MAX_BYTES, and recorded only while collectorEnabled is on.
  places = {},
  -- When the Discoveries tab was last opened, as a timestamp, which is what the number in
  -- brackets on the tab is counted against (Core/Discoveries.lua). Account wide, because the
  -- discoveries it is counted against are: the collector's store is, and so is a data build.
  -- A number and nothing else, so no character, realm or account fact can reach saved
  -- variables through it. 0 means the tab has never been opened, which is the honest start.
  discoveriesSeen = 0,
  -- One off chat hints the addon has already given on this account. firstRun is set once the
  -- two first run lines (how to open the tree, where the commands are) have been printed, so
  -- they are printed at most once. Booleans only.
  hints = {
    firstRun = false,
  },
}

ItemTree.CHAR_DEFAULTS = {
  version = 1,
  -- The window's default rect. Width and height are Theme.sizes ITEMTREE_FRAME_DEFAULT_W and
  -- _H, kept in step by hand because Core carries no UI dependency. ui_frame_spec pins the
  -- pair together, so a change here that is not made there as well fails the suite.
  window = { width = 1000, height = 560, point = "CENTER", x = 0, y = 0 },
  -- Where the Summary HUD sits, per character like the window. Point and offsets only: the
  -- panel sizes itself to what it is drawing, so there is no width or height to remember. The
  -- default puts it under the middle of the screen, clear of the centre where the client's own
  -- error text and loot toasts appear.
  hud = { point = "CENTER", x = 0, y = -220 },
  -- Set the first time UI/Keybind.lua offers this character a default key for the binding,
  -- whether or not a key was free. It is never cleared, so the default is applied at most
  -- once and a player who unbinds the key afterwards is left alone.
  keybindDefaultTried = false,
}

-- Copies defaults into db for any key that is missing. Never removes user data.
function ItemTree.ApplyDefaults(db, defaults)
  db = db or {}
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      db[key] = ItemTree.ApplyDefaults(db[key], value)
    elseif db[key] == nil then
      db[key] = value
    end
  end
  return db
end

-- What the client handed over for a saved variable table on this load: "absent" when the
-- global was not there at all, "empty" when it was a table with nothing in it, and "loaded"
-- when it carries keys of its own. Pure.
--
-- The distinction is worth recording because the two faults it tells apart look identical from
-- the window. An addon that writes to a table the client never serialises loses everything, and
-- so does a client that writes the file at logout and then does not read it back at login. The
-- first is ours to fix; the second (WoW Forever beta 1.60.1, build 69913) is not, and no amount
-- of care on this side survives it. ItemTree.DbStatusLine reports both.
function ItemTree.SavedState(db)
  if type(db) ~= "table" then
    return "absent"
  end
  if next(db) == nil then
    return "empty"
  end
  return "loaded"
end

-- The window's scale base. UI/Frame.lua multiplies settings.windowScale by this, so a stored
-- 1.0 draws the window at 0.85 of the client's UI scale, which is the size the owner settled on.
-- Core owns the number because the migration below has to rescale against the same one.
ItemTree.SCALE_BASE = 0.85
ItemTree.SCALE_MIN = 0.5
ItemTree.SCALE_MAX = 1.5
ItemTree.SCALE_STEP = 0.05

-- A scale written against the old base of 1 as the same size against the new base: divided by
-- the base, rounded to the nearest step and held inside the slider's range. Pure.
function ItemTree.RebaseScale(scale)
  local value = (tonumber(scale) or 1.0) / ItemTree.SCALE_BASE
  local steps = math.floor(value / ItemTree.SCALE_STEP + 0.5)
  value = steps * 5 / 100
  if value < ItemTree.SCALE_MIN then
    return ItemTree.SCALE_MIN
  end
  if value > ItemTree.SCALE_MAX then
    return ItemTree.SCALE_MAX
  end
  return value
end

-- One time settings migration, run before the defaults are applied so that a settings table
-- that is already on disk can be told apart from a fresh install. A table written before the
-- scale rebase carries no scaleBase: its windowScale is rescaled once so the window opens at
-- exactly the size it opened at before, and scaleBase is stamped so this never runs twice. A
-- fresh install has no settings table at all and takes the 1.0 default, which is the new base.
-- Returns true when it migrated something. Pure: it only touches the table it is handed.
function ItemTree.MigrateSettings(settings)
  if type(settings) ~= "table" or settings.scaleBase ~= nil then
    return false
  end
  settings.windowScale = ItemTree.RebaseScale(settings.windowScale)
  settings.scaleBase = 1
  return true
end

-- One time migration (brief E89): "Load item data at login" became on by default, but
-- ApplyDefaults had already written the old default (false) into every saved settings table, so
-- the new default alone would never reach an existing install. The first load after the change
-- sets it on once and records loadDataAtLoginOn in db.migrations (made here when absent). After
-- that the saved value is the player's: a later untick stays off across logins. Run after the
-- defaults are applied. Returns true when it set the value. Pure: it only touches the table it
-- is handed.
function ItemTree.MigrateLoadDataAtLogin(db)
  if type(db) ~= "table" then
    return false
  end
  if type(db.migrations) ~= "table" then
    db.migrations = {}
  end
  if db.migrations.loadDataAtLoginOn then
    return false
  end
  if type(db.settings) ~= "table" then
    db.settings = {}
  end
  db.settings.loadDataAtLogin = true
  db.migrations.loadDataAtLoginOn = true
  return true
end

-- One time migration (brief E96): the Discoveries tab became opt in, but ApplyDefaults had
-- already written the old default (true) into every saved settings table, so the new default
-- alone would never reach an existing install. The first load after the change sets it off once
-- and records discoveriesOptIn in db.migrations (made here when absent). After that the saved
-- value is the player's: ticking it on later stays on across logins. Run after the defaults are
-- applied. Returns true when it set the value. Pure: it only touches the table it is handed.
function ItemTree.MigrateDiscoveriesOptIn(db)
  if type(db) ~= "table" then
    return false
  end
  if type(db.migrations) ~= "table" then
    db.migrations = {}
  end
  if db.migrations.discoveriesOptIn then
    return false
  end
  if type(db.settings) ~= "table" then
    db.settings = {}
  end
  db.settings.showDiscoveries = false
  db.migrations.discoveriesOptIn = true
  return true
end

-- One time migration (brief SR3): "Search everything" became on by default, but ApplyDefaults had
-- already written SR1's default (false) into the saved settings, and the settings keep no mark of
-- whether the player touched a value, so the first load after the change sets it on once and
-- records searchEverythingOn in db.migrations (made here when absent). After that the saved value
-- is the player's: an untick stays off across logins. Run after the defaults are applied. Returns
-- true when it set the value. Pure: it only touches the table it is handed.
function ItemTree.MigrateSearchEverythingOn(db)
  if type(db) ~= "table" then
    return false
  end
  if type(db.migrations) ~= "table" then
    db.migrations = {}
  end
  if db.migrations.searchEverythingOn then
    return false
  end
  if type(db.settings) ~= "table" then
    db.settings = {}
  end
  db.settings.searchEverything = true
  db.migrations.searchEverythingOn = true
  return true
end

-- One time migration (brief PT32): the Professions tab became on by default. Before it, the
-- client's settings panel wrote the old default (false) into the saved settings at every login
-- (Settings.RegisterAddOnSetting fills a nil key with the default it is handed, wow-ui-source
-- branch forever, Blizzard_Settings_Shared/Blizzard_Setting.lua:398-400), so a saved false from
-- 0.1.8 or 0.1.9 is what nearly every player has whether or not they touched it, and an absent
-- key only a table the panel never saw. Neither tells "never touched" from "turned off", so the
-- first load after the change sets it on once, as brief SR3 did, and records professionsOn in
-- db.migrations (made here when absent). After that the saved value is the player's: turning it
-- off stays off across logins. Run after the defaults are applied. Returns true when it set the
-- value. Pure: it only touches the table it is handed.
function ItemTree.MigrateProfessionsOn(db)
  if type(db) ~= "table" then
    return false
  end
  if type(db.migrations) ~= "table" then
    db.migrations = {}
  end
  if db.migrations.professionsOn then
    return false
  end
  if type(db.settings) ~= "table" then
    db.settings = {}
  end
  db.settings.showProfessions = true
  db.migrations.professionsOn = true
  return true
end

-- One time migration (brief K10): the Keep value moved from whole gold (keepValueGold, brief K9)
-- to copper (keepValueCopper), so the slider can reach silver. A saved keepValueGold becomes gold
-- times 10000 and the old key goes, which is also the mark that it has run; a fresh account has
-- no old key and takes the default. Run before the defaults are applied, so the default never
-- stands in for a choice the player made. Returns true when it migrated something. Pure: it only
-- touches the table it is handed.
function ItemTree.MigrateKeepValue(settings)
  if type(settings) ~= "table" or settings.keepValueGold == nil then
    return false
  end
  local gold = tonumber(settings.keepValueGold)
  settings.keepValueGold = nil
  if gold == nil or gold ~= gold then
    return true
  end
  if gold < 0 then
    gold = 0
  end
  settings.keepValueCopper = math.floor(gold * 10000 + 0.5)
  return true
end

-- Parses GetBuildInfo() results into a full build id like "1.15.9.69722".
function ItemTree.ParseBuild(version, build)
  if type(version) ~= "string" or not version:match("^%d+%.%d+%.%d+$") then
    return nil
  end
  build = tostring(build or ""):match("^%d+$")
  if not build then
    return nil
  end
  return version .. "." .. build
end

local function buildTuple(id)
  local out = {}
  for part in tostring(id):gmatch("%d+") do
    out[#out + 1] = tonumber(part)
  end
  return out
end

-- Compares two build ids numerically. Returns -1, 0 or 1.
function ItemTree.CompareBuilds(a, b)
  local ta, tb = buildTuple(a), buildTuple(b)
  for i = 1, math.max(#ta, #tb) do
    local x, y = ta[i] or 0, tb[i] or 0
    if x ~= y then
      return x < y and -1 or 1
    end
  end
  return 0
end

-- Picks which data build to use for the running client.
-- available: table of build id -> true. Returns chosen build, status where status is
-- "exact" (same build), "older" (nearest older data, warn), "newer" (only newer data
-- exists, warn), or nil when nothing is available.
function ItemTree.SelectDataBuild(clientBuild, available)
  local exact, olderBest, newerBest
  for build in pairs(available or {}) do
    local cmp = ItemTree.CompareBuilds(build, clientBuild)
    if cmp == 0 then
      exact = build
    elseif cmp < 0 then
      if not olderBest or ItemTree.CompareBuilds(build, olderBest) > 0 then
        olderBest = build
      end
    else
      if not newerBest or ItemTree.CompareBuilds(build, newerBest) < 0 then
        newerBest = build
      end
    end
  end
  if exact then
    return exact, "exact"
  end
  if olderBest then
    return olderBest, "older"
  end
  if newerBest then
    return newerBest, "newer"
  end
  return nil, nil
end

-- Every build the data is exact for, from a Meta table: the compiled build (Meta.build) first,
-- then each other entry of Meta.builds, the pipeline's list of builds whose game tables are the
-- same as the compiled one's. Only strings that read as a full build id are kept (validated with
-- ParseBuild), and a build listed twice is kept once. Older data has no Meta.builds, and then
-- Meta.build alone applies. Returns an array, empty when nothing is valid.
function ItemTree.ListedBuilds(meta)
  local out, seen = {}, {}
  local function add(id)
    if type(id) ~= "string" then
      return
    end
    local version, build = id:match("^(%d+%.%d+%.%d+)%.(%d+)$")
    local parsed = version and ItemTree.ParseBuild(version, build) or nil
    if parsed and not seen[parsed] then
      seen[parsed] = true
      out[#out + 1] = parsed
    end
  end
  if type(meta) ~= "table" then
    return out
  end
  add(meta.build)
  if type(meta.builds) == "table" then
    for _, id in ipairs(meta.builds) do
      add(id)
    end
  end
  return out
end

-- The name of a spell, or nil when nothing on this client names it.
--
-- Core answers from a generated SpellNames module when the pipeline ships one, and nothing
-- otherwise, so a line about a spell still says which spell it means by id. UI/ replaces
-- this with the client's GetSpellInfo and the browser harness with its own table: every
-- layer reads one resolver, so Core/Diff.lua never has to know which one is in place.
function ItemTree.SpellName(spellId)
  if type(spellId) ~= "number" then
    return nil
  end
  local data = ItemTree.Data
  local names = data and data.Get and data:Get("SpellNames") or nil
  local name = names and names[spellId] or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

-- Runtime state filled in on load.
ItemTree.state = {
  clientBuild = nil,
  dataBuild = nil,
  dataStatus = nil,
  -- Every build the data is exact for (ItemTree.ListedBuilds), the compiled build first.
  dataBuilds = nil,
  loaded = false,
  -- How the collector ended up on this load: "installed", "absent" (Core/Collector.lua never
  -- loaded) or "failed" (it loaded and would not register). Every collected source reaches the
  -- tree through that one provider, so a window with no Drops from category and a collector that
  -- is not "installed" is a load fault rather than an empty store.
  collector = "absent",
  -- The same, for the curated quest provider in Core/Quests.lua: "installed", "absent" (the
  -- file never loaded) or "failed". A quest window with no Requires category and a provider
  -- that is not "installed" is a load fault rather than an empty curated table.
  quests = "absent",
  -- What the client handed over for each saved variable table on this load, from
  -- ItemTree.SavedState: "loaded", "empty" or "absent". Filled in by OnLoaded.
  savedDb = nil,
  savedCharDb = nil,
  -- Set by ItemTree.ShowLoadHints, so the wrong client line and the first run hint are said at
  -- most once per load.
  loadHintsShown = false,
  -- Brief PF5: true once the session's first PLAYER_ENTERING_WORLD has been handled
  -- (ItemTree.OnEnteringWorld), which Core/Data.lua stamps on Data.loadTiming as world.
  enteredWorld = false,
}

-- Reads the client build when the API exists (in game or under the harness shim).
function ItemTree.DetectClientBuild()
  local getBuildInfo = rawget(_G, "GetBuildInfo")
  if type(getBuildInfo) ~= "function" then
    return nil
  end
  local version, build = getBuildInfo()
  return ItemTree.ParseBuild(version, build)
end

-- Called once saved variables are available (ADDON_LOADED in game, directly in tests).
function ItemTree.OnLoaded(db, charDb)
  -- Read before anything is defaulted into them, because once the defaults are on an empty
  -- table it is no longer possible to tell a fresh install from a load that lost everything.
  ItemTree.state.savedDb = ItemTree.SavedState(db)
  ItemTree.state.savedCharDb = ItemTree.SavedState(charDb)
  ItemTree.MigrateSettings(type(db) == "table" and db.settings or nil)
  ItemTree.MigrateKeepValue(type(db) == "table" and db.settings or nil)
  ItemTree.db = ItemTree.ApplyDefaults(db, ItemTree.DB_DEFAULTS)
  ItemTree.MigrateLoadDataAtLogin(ItemTree.db)
  ItemTree.MigrateDiscoveriesOptIn(ItemTree.db)
  ItemTree.MigrateSearchEverythingOn(ItemTree.db)
  ItemTree.MigrateProfessionsOn(ItemTree.db)
  ItemTree.charDb = ItemTree.ApplyDefaults(charDb, ItemTree.CHAR_DEFAULTS)
  ItemTree.state.clientBuild = ItemTree.DetectClientBuild()
  local meta = ItemTree.Data and ItemTree.Data.Meta
  local available = {}
  if meta and meta.build then
    available[meta.build] = true
  end
  -- Brief D4: a build whose game tables are the same as the compiled one's is exact too.
  local listed = ItemTree.ListedBuilds(meta)
  for _, id in ipairs(listed) do
    available[id] = true
  end
  ItemTree.state.dataBuilds = listed
  ItemTree.state.dataBuild, ItemTree.state.dataStatus =
    ItemTree.SelectDataBuild(ItemTree.state.clientBuild or (meta and meta.build) or "0.0.0.0", available)
  -- The data build named everywhere stays the one the data was compiled from, even when the
  -- client matched another build on the list.
  if ItemTree.state.dataStatus == "exact" and meta and meta.build then
    ItemTree.state.dataBuild = meta.build
  end
  ItemTree.state.loaded = true
  -- The collector is optional: Core still loads without it (the harness swaps it out). Whether
  -- it registered is recorded, because the collector's provider is the only path every collected
  -- source takes into the graph: with no provider the tree draws no Drops from category at all
  -- and nothing else in the window looks any different.
  ItemTree.state.collector = "absent"
  if ItemTree.Collector then
    -- Brief R15: every record still in the old shape is converted once, before the collector
    -- reads the store; a load that stopped half way converts the rest now. The answer is what
    -- /itemtree debug reports.
    local migrated, migration =
      pcall(ItemTree.Collector.Migrate, ItemTree.db.collector, { ledger = ItemTree.db.ledger })
    ItemTree.state.collectorMigration = migrated and migration or nil
    -- Brief R3: every discovery record still a table is packed once, and the store is held to
    -- its byte budget, which is the login's prune of it. The answer is what /itemtree debug
    -- reports.
    local packed, discoveries = false, nil
    if type(ItemTree.Collector.MigrateDiscoveries) == "function" then
      packed, discoveries = pcall(ItemTree.Collector.MigrateDiscoveries, ItemTree.db.collector)
    end
    ItemTree.state.discoveriesMigration = packed and discoveries or nil
    ItemTree.collector = ItemTree.Collector.New(ItemTree.db.collector, {
      build = ItemTree.state.dataBuild or ItemTree.state.clientBuild,
    })
    if packed and type(discoveries) == "table" then
      ItemTree.collector.discPruned = tonumber(discoveries.capped) or 0
    end
    ItemTree.collector:Install()
    -- Brief R1: a store that grew past its byte budget before the cap existed is brought back
    -- under it once at login; every record write after this keeps it there.
    ItemTree.collector:Prune(ItemTree.Collector.MAX_BYTES)
    ItemTree.state.collector = ItemTree.collector:Installed() and "installed" or "failed"
  end
  -- The curated quest table, on the same terms: optional, registered here, and recorded so the
  -- debug command can say whether a quest's own rows can reach the window at all. Data/curated
  -- loads after Core, so the provider is created with no source and reads ItemTree.CuratedQuests
  -- the first time it is asked something.
  ItemTree.state.quests = "absent"
  if ItemTree.Quests then
    ItemTree.quests = ItemTree.Quests.New()
    ItemTree.quests:Install()
    -- Names now, so a quest opened by its key alone titles itself rather than reading
    -- "Quest 7786": the window asks Graph.Title before anything asks the provider for an edge.
    ItemTree.quests:SetNames()
    ItemTree.state.quests = ItemTree.quests:Installed() and "installed" or "failed"
  end
  if ItemTree.callbacks then
    ItemTree.callbacks:Fire("ITEMTREE_LOADED")
  end
  return ItemTree.db, ItemTree.charDb
end

-- One line for the debug command describing the data build situation (brief W32: the item
-- tooltip no longer carries it).
function ItemTree.DataStatusLine()
  local s = ItemTree.state
  if not s.dataBuild then
    return "Data module not loaded for this build"
  end
  if s.dataStatus == "exact" then
    return nil
  end
  if s.dataStatus == "older" then
    return string.format("Data is for build %s, this client is %s", s.dataBuild, s.clientBuild or "unknown")
  end
  return string.format("Data is for newer build %s, this client is %s", s.dataBuild, s.clientBuild or "unknown")
end

-- The debug command's data build line: "Data build: <build> (<status>)", and when the data is
-- exact for more than one build, ", also exact for: <the others>" after it.
function ItemTree.DataBuildLine()
  local s = ItemTree.state
  local line = string.format("Data build: %s (%s)", tostring(s.dataBuild or "none"), tostring(s.dataStatus or "none"))
  local others = {}
  for _, id in ipairs(type(s.dataBuilds) == "table" and s.dataBuilds or {}) do
    if id ~= s.dataBuild then
      others[#others + 1] = id
    end
  end
  if s.dataBuild and type(s.dataBuilds) == "table" and #s.dataBuilds > 1 and #others > 0 then
    line = line .. ", also exact for: " .. table.concat(others, ", ")
  end
  return line
end

-- One line for the debug command saying whether collected sources can reach the window at all:
-- how the collector's provider ended up on this load, how many records the store holds and how
-- many items they are spread over. A store full of records that never registered draws exactly
-- the same empty tree an empty store does, and the window cannot tell the two apart.
--
-- UI/Slash.lua prints ItemTree.DataStatusLine beside its collector lines; this is the same shape
-- and the numbers are Collector:Counts, so nothing here reads saved variables the debug command
-- is not already reading.
function ItemTree.CollectorStatusLine()
  local collector = ItemTree.collector
  if not collector or type(collector.Counts) ~= "function" then
    return string.format("Collector: %s, no store", tostring(ItemTree.state.collector))
  end
  local ok, counts = pcall(collector.Counts, collector)
  if not ok or type(counts) ~= "table" then
    return string.format("Collector: %s, store unreadable", tostring(ItemTree.state.collector))
  end
  -- "records 3, items 1" rather than a sentence, to read the way the debug command's other
  -- count lines already do.
  return string.format(
    "Collector: %s, records %d, items %d, provider %s",
    tostring(ItemTree.state.collector),
    tonumber(counts.total) or 0,
    tonumber(counts.items) or 0,
    counts.installed and "registered" or "not registered"
  )
end

-- One line for the debug command about the saved variables themselves. Two facts, because the
-- two faults behind "nothing I change is kept" look identical from the window:
--   what the client handed over on this load, from ItemTree.SavedState, and
--   whether the tables the addon writes are the very tables the client will serialise, which
--   is rawequal against the globals named in the TOC and nothing softer.
-- "account loaded, account table live yes" is a healthy load. "account table live no" is ours:
-- something replaced the table instead of filling it. "account empty" or "account absent" with
-- a WTF file that has content in it is the client not reading the file back, which the addon
-- cannot work around, since saved variables are the only place it is allowed to write.
function ItemTree.DbStatusLine()
  local liveDb = rawequal(ItemTree.db, rawget(_G, "ItemTreeDB"))
  local liveCharDb = rawequal(ItemTree.charDb, rawget(_G, "ItemTreeCharDB"))
  return string.format(
    "Saved variables: account %s, character %s, account table live %s, character table live %s",
    tostring(ItemTree.state.savedDb or "unknown"),
    tostring(ItemTree.state.savedCharDb or "unknown"),
    liveDb and "yes" or "no",
    liveCharDb and "yes" or "no"
  )
end

-- The same line for the curated quest table: how its provider ended up on this load and how
-- much the table holds. Counts are Quests:Counts, so nothing here reads saved variables.
function ItemTree.QuestsStatusLine()
  local quests = ItemTree.quests
  if not quests or type(quests.Counts) ~= "function" then
    return string.format("Curated quests: %s, no table", tostring(ItemTree.state.quests))
  end
  local ok, counts = pcall(quests.Counts, quests)
  if not ok or type(counts) ~= "table" then
    return string.format("Curated quests: %s, table unreadable", tostring(ItemTree.state.quests))
  end
  return string.format(
    "Curated quests: %s, quests %d, requires %d, rewards %d, provider %s",
    tostring(ItemTree.state.quests),
    tonumber(counts.quests) or 0,
    tonumber(counts.requires) or 0,
    tonumber(counts.rewards) or 0,
    counts.installed and "registered" or "not registered"
  )
end

-- The client ItemTree is built for: WoW Forever, version 1.60.x (TOC interface 16001). Any
-- other client (Classic Era 1.15.x, Anniversary, retail) that is made to load the addon anyway
-- gets data that was never meant for it, and is told so once at load.
ItemTree.FOREVER_VERSION_PREFIX = "1.60."

-- Pure. Whether a GetBuildInfo version string names a client other than WoW Forever. nil, a
-- non string and an empty string answer false: a client that will not say is not warned about.
function ItemTree.ClientMismatch(version)
  if type(version) ~= "string" or version == "" then
    return false
  end
  local prefix = ItemTree.FOREVER_VERSION_PREFIX
  return version:sub(1, #prefix) ~= prefix
end

-- Pure. The wrong client chat line for a version string, or nil when there is nothing to say.
function ItemTree.ClientMismatchLine(version)
  if not ItemTree.ClientMismatch(version) then
    return nil
  end
  -- Two sentences, two keys, so neither key runs past the line length.
  return L["ItemTree is built for the WoW Forever client (1.60.x)."]
    .. " "
    .. string.format(L["You are on %s, so what ItemTree shows may be wrong here."], version)
end

-- Pure. The words for a click to open setting (settings.clickOpen, "CTRL-RIGHT" and so on, as
-- UI/Keybind.lua CLICK_OPTIONS spells them), or nil for "OFF" and anything this build does not
-- know. Written out branch by branch so every key is a literal the locale spec can find.
function ItemTree.ClickPhrase(value)
  if value == "CTRL-RIGHT" then
    return L["Ctrl and right click"]
  end
  if value == "CTRL-LEFT" then
    return L["Ctrl and left click"]
  end
  if value == "ALT-RIGHT" then
    return L["Alt and right click"]
  end
  if value == "ALT-LEFT" then
    return L["Alt and left click"]
  end
  return nil
end

-- Pure. Whether the first run hint is still owed on this account DB. A missing DB answers
-- false, because there would be nowhere to record that it was given.
function ItemTree.FirstRunHintDue(db)
  if type(db) ~= "table" then
    return false
  end
  local hints = db.hints
  if type(hints) == "table" and hints.firstRun == true then
    return false
  end
  return true
end

-- Pure. The two first run lines, worded from the click to open setting. With the click turned
-- off the first line names the key binding alone.
function ItemTree.FirstRunHintLines(clickValue)
  local phrase = ItemTree.ClickPhrase(clickValue)
  local first
  if phrase then
    first =
      string.format(L["ItemTree: %s an item to open its tree, or set a key under Key Bindings, ItemTree."], phrase)
  else
    first = L["ItemTree: set a key under Key Bindings, ItemTree, to open the tree for the item under the cursor."]
  end
  return { first, L["/itemtree help lists the commands."] }
end

-- Pure. Records on the account DB that the first run hint was given.
function ItemTree.MarkFirstRunHint(db)
  if type(db) ~= "table" then
    return
  end
  if type(db.hints) ~= "table" then
    db.hints = {}
  end
  db.hints.firstRun = true
end

-- Client side. Guarded

-- The version string GetBuildInfo answers first ("1.60.1"), or nil where there is no such API
-- or it will not answer, which is every run under busted.
function ItemTree.ClientVersion()
  local getBuildInfo = rawget(_G, "GetBuildInfo")
  if type(getBuildInfo) ~= "function" then
    return nil
  end
  local ok, version = pcall(getBuildInfo)
  if not ok or type(version) ~= "string" then
    return nil
  end
  return version
end

-- The load hints: the wrong client line first, then the first run hint, each only when owed,
-- through the client's DEFAULT_CHAT_FRAME, guarded. Runs at most once per load
-- whatever it is handed. chat and version are arguments so the spec can hand in fakes; the
-- ADDON_LOADED handler passes the client's own. The first run flag is only set once both hint
-- lines went out, so a load with no chat frame owes the hint still. Returns the lines printed.
function ItemTree.ShowLoadHints(chat, version)
  local printed = {}
  if ItemTree.state.loadHintsShown then
    return printed
  end
  ItemTree.state.loadHintsShown = true
  if type(chat) ~= "table" or type(chat.AddMessage) ~= "function" then
    return printed
  end
  local function say(line)
    local ok = pcall(chat.AddMessage, chat, line)
    if ok then
      printed[#printed + 1] = line
    end
    return ok
  end
  local mismatch = ItemTree.ClientMismatchLine(version)
  if mismatch then
    say(mismatch)
  end
  local db = ItemTree.db
  if ItemTree.FirstRunHintDue(db) then
    local settings = type(db.settings) == "table" and db.settings or {}
    local allSaid = true
    for _, line in ipairs(ItemTree.FirstRunHintLines(settings.clickOpen)) do
      if not say(line) then
        allSaid = false
      end
    end
    if allSaid then
      ItemTree.MarkFirstRunHint(db)
    end
  end
  return printed
end

-- Whether the data addon is to be loaded at login: settings.loadDataAtLogin, due only when it is
-- exactly true. The default is true (brief E89), so it is off only when the player turned it off.
-- Pure.
function ItemTree.LoadDataAtLoginDue(settings)
  return type(settings) == "table" and settings.loadDataAtLogin == true
end

-- PLAYER_LOGIN. With "Load item data at login" on (the default), ItemTree_Data is loaded now, by the one load
-- call Data:Get would make the first time it needed a module (Data:LoadOnDemand). Returns whether
-- a load was asked for.
function ItemTree.OnLogin()
  local db = ItemTree.db
  if not ItemTree.LoadDataAtLoginDue(type(db) == "table" and db.settings or nil) then
    return false
  end
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.LoadOnDemand) ~= "function" then
    return false
  end
  pcall(data.LoadOnDemand, data, "login")
  return true
end

-- Brief PF2: the first open no longer hangs. On the first PLAYER_ENTERING_WORLD of the session
-- (a login or a reload, never a zone change), behind the loading screen:
--   1. ItemTree_Data is loaded through Data:LoadOnDemand, the path the first open takes. With "Load
--      item data at login" on (the default) PLAYER_LOGIN has already done it and this is one check;
--      a failed load keeps the lazy path, which has already recorded the reason and says it once.
--      Brief PF8: once it is loaded, the loot and vendor indexes are built whole right here, still
--      behind the loading screen (Core/Data.lua Data:PreloadLoadingScreen), because a Ctrl click on
--      a creature before the slicer reached them built them in the click's frame. A reload shows
--      the loading screen too and is the same. Not with the setting off.
--   2. A tick later the window is built, hidden (UI/Frame.lua Frame.BuildAtLogin).
--   3. ItemTree.PRELOAD_DELAY seconds later the slicer starts building the modules an item page
--      needs, one per frame (Core/Data.lua Data:StartPreload). Not with the setting off: the player
--      asked for the item data to wait for the window.
-- ItemTree.state.preload holds what happened for /itemtree debug: { data = "yes" | "no" |
-- "failed <reason>", window = "yes" | "no" }.
ItemTree.PRELOAD_DELAY = 3

-- Whether this PLAYER_ENTERING_WORLD is the one to preload on: a login or a reload, and not done
-- yet this session. Pure.
function ItemTree.PreloadDue(isLogin, isReload, done)
  if done then
    return false
  end
  return isLogin == true or isReload == true
end

-- The debug line: "preload: data addon at login yes, window at login yes, slices built 24 of 24".
-- preload is ItemTree.state.preload (nil before the first PLAYER_ENTERING_WORLD), built and total
-- the slicer's counts. Pure.
function ItemTree.PreloadLine(preload, built, total)
  if type(preload) ~= "table" then
    return "preload: not run yet"
  end
  return string.format(
    "preload: data addon at login %s, window at login %s, slices built %d of %d",
    tostring(preload.data or "no"),
    tostring(preload.window or "no"),
    tonumber(built) or 0,
    tonumber(total) or 0
  )
end

-- The debug line for this session, read from the state and the slicer.
function ItemTree.PreloadStatusLine()
  local data = ItemTree.Data
  local built, total = 0, 0
  if type(data) == "table" and type(data.PreloadCounts) == "function" then
    local ok, done, size = pcall(data.PreloadCounts, data)
    if ok then
      built, total = done, size
    end
  end
  return ItemTree.PreloadLine(ItemTree.state.preload, built, total)
end

-- Step 1: answers what the state records for the data addon.
local function preloadData()
  local db = ItemTree.db
  if not ItemTree.LoadDataAtLoginDue(type(db) == "table" and db.settings or nil) then
    return "no"
  end
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.LoadOnDemand) ~= "function" then
    return "no"
  end
  local ok, loaded = pcall(data.LoadOnDemand, data, "entering world")
  if ok and loaded then
    return "yes"
  end
  local reason = data.onDemandFailed
  if reason == nil then
    reason = ok and "not loaded" or tostring(loaded)
  end
  return "failed " .. tostring(reason)
end

-- Step 1, brief PF8: the indexes the first creature page reads, built whole behind the loading
-- screen (Data:PreloadLoadingScreen). Answers how many were built, 0 where nothing could be asked.
local function preloadIndexes()
  local data = ItemTree.Data
  if type(data) ~= "table" or type(data.PreloadLoadingScreen) ~= "function" then
    return 0
  end
  local ok, ran = pcall(data.PreloadLoadingScreen, data)
  if ok and type(ran) == "number" then
    return ran
  end
  return 0
end

-- Step 2: the window, through UI/Frame.lua. Answers whether the build was asked for.
function ItemTree.PreloadWindow()
  local preload = ItemTree.state.preload
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if type(preload) ~= "table" or type(frame) ~= "table" or type(frame.BuildAtLogin) ~= "function" then
    return false
  end
  return (pcall(frame.BuildAtLogin, function(built)
    if built then
      preload.window = "yes"
    end
  end))
end

-- Step 3: the slicer, only once the data addon loaded at login. Answers whether it started.
function ItemTree.PreloadSlices()
  local preload = ItemTree.state.preload
  local data = ItemTree.Data
  if type(preload) ~= "table" or preload.data ~= "yes" then
    return false
  end
  if type(data) ~= "table" or type(data.StartPreload) ~= "function" then
    return false
  end
  local ok, started = pcall(data.StartPreload, data)
  return ok and started == true
end

-- PLAYER_ENTERING_WORLD. Answers whether this one preloaded. Brief PF5: state.enteredWorld is set
-- once this one's own load is done, so that load counts as behind the loading screen.
function ItemTree.OnEnteringWorld(isLogin, isReload)
  local state = ItemTree.state
  if not ItemTree.PreloadDue(isLogin, isReload, state.preload ~= nil) then
    state.enteredWorld = true
    return false
  end
  local preload = { data = "no", window = "no" }
  state.preload = preload
  preload.data = preloadData()
  if preload.data == "yes" then
    preloadIndexes()
  end
  state.enteredWorld = true
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    pcall(timer.After, 0, ItemTree.PreloadWindow)
    pcall(timer.After, ItemTree.PRELOAD_DELAY, ItemTree.PreloadSlices)
  end
  return true
end

-- Event wiring, only in the client.
local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local frame = createFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:SetScript("OnEvent", function(self, event, name, extra)
    if event == "PLAYER_ENTERING_WORLD" then
      -- Brief PF2: name and extra are isInitialLogin and isReloadingUi here. Once a login or a
      -- reload has preloaded, the zone changes after it have nothing to say to this frame.
      if ItemTree.OnEnteringWorld(name, extra) then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
      end
      return
    end
    if event == "PLAYER_LOGIN" then
      ItemTree.OnLogin()
      self:UnregisterEvent("PLAYER_LOGIN")
      return
    end
    if event == "ADDON_LOADED" and name == ADDON_NAME then
      -- The client puts the saved tables on these globals just before this event and reads
      -- those same globals back at logout, so the tables are taken as they are found, filled
      -- in place by OnLoaded, and put straight back. Nothing is read at file scope, where the
      -- client would replace whatever was made, and nothing is copied into a new table: what
      -- the addon writes to for the rest of the session has to be what the client serialises.
      -- The assignment back is what covers a load that handed over nothing at all, where
      -- ApplyDefaults answers with fresh tables of its own.
      local db, charDb = ItemTree.OnLoaded(rawget(_G, "ItemTreeDB"), rawget(_G, "ItemTreeCharDB"))
      _G.ItemTreeDB = db
      _G.ItemTreeCharDB = charDb
      -- The wrong client line and the first run hint, after the DB and the build and before
      -- PLAYER_LOGIN builds any UI.
      ItemTree.ShowLoadHints(rawget(_G, "DEFAULT_CHAT_FRAME"), ItemTree.ClientVersion())
      self:UnregisterEvent("ADDON_LOADED")
    end
  end)
  local libStub = rawget(_G, "LibStub")
  if libStub then
    local handler = libStub("CallbackHandler-1.0", true)
    if handler then
      ItemTree.callbacks = handler:New(ItemTree)
    end
  end
  _G.ItemTree = ItemTree
end
