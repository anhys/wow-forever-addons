-- Slash commands: /itemtree and /it.
--
--   (no argument)      open the window the way a left click on the minimap button does, and
--                      leave a window already up alone (brief SL1, the owner's item 244)
--   help               print this list
--   debug              build ids, data status, module counts and the modules built, the Boss
--                      loot model's counts, tooltip state and counters, binding state,
--                      settings, collector counts, saved variable state
--   report             the same lines plus the recent trace, in a window they can be copied from
--   trace              toggle the tooltip trace: one chat line per tooltip post call
--   show <id or name>  open the window on an item or a creature, or print the tooltip block
--   random             show a random item
--   options            open the settings panel (config and settings are the same command)
--   reset              clear the remembered window position
--   cpu [reset]        where ItemTree spends CPU time, with the client's script profiling on,
--                      in the report window; reset starts the count again
--   ledger [reset]     the loot ledger's five line summary (Core/Ledger.lua); reset asks for the
--                      confirm word, and reset confirm clears it
--   hud [on|off|unlock|lock|reset]
--                      the Summary HUD: bare toggles it, the rest are named. UI/EditMode.lua
--                      owns the state and this is only the wording around it
--   demo level|professions|spec|talent|quest|have|scenario|at|show|off ...
--                      brief BQ13: the demo state (Core/Demo.lua), what the addon thinks the
--                      character is, memory only; every tooltip says while it is on. docs/demo.md
--                      lists the commands. Shipped, since nothing it does is saved
--   demo professions <name> <rank> [<name> <rank> ...] | none | random [<name> ...] [low|mid|high] | sample | off
--                      brief PR42: pretend professions for the Professions tab, memory only; the set
--                      replaces the player's own, and crafting is off while it is on. Bare prints it.
--                      Brief PR42b: random draws two primaries (or takes the names) at random ranks
--   demo <price|money|disenchant> <money or off> | demo level <n or off>
--                      brief K24b (H): pretend Keep tag values, memory only. Brief K24d: disenchant
--                      prices every disenchant material at that much each
--
-- Slash.Default is what a right click on the minimap button and the addon compartment entry both
-- run, so the two stay in step. Slash.OpenDefault is the other half: what a left click on that
-- button and the key binding with nothing under the cursor run. Brief SL1 (the owner, 2026-10-18,
-- item 244: "make bare /it or /itemtree open the normal panel instead of settings"): the bare
-- command left Slash.Default for Slash.OpenDefault through Slash.Show, which only ever opens.
--
-- Slash.Parse, Slash.DebugLines, Slash.UsageLines and Slash.ResolveItem are pure and run
-- under busted. Registration and printing are guarded, so this file loads with no WoW API.
--
-- Taint (the owner's gamepad freeze, 2026-10-03): a slash command runs INSIDE the chat edit box's
-- send path (ChatEdit_SendText). A handler that opened a window there and gave its edit box the
-- focus made the chat edit box lose focus and hide under our taint, and the gamepad
-- FrameControlsManager then called the protected SetPreferredGamepadInteractTarget as ItemTree
-- (ADDON_ACTION_FORBIDDEN, then a frozen client). So the registered handler does nothing but book
-- Slash.Handle for the next tick (Slash.Defer, C_Timer.After(0)), by which time the chat edit box
-- has closed itself securely; no command opens, toggles or focuses anything synchronously. The
-- addon compartment entry is booked the same way. Our windows never SetFocus on open either: only
-- the player's own click on one of our frames focuses a box.
--
-- The developer only commands sit between the packager's strip markers, and the BigWigs
-- packager deletes each marked range from a released build, marker lines included. Each range
-- is a whole table entry, a whole elseif branch or a whole function, so the file still parses
-- with every range gone (tests/spec/package_spec.lua and scripts/check-package.sh check it).
local _, ItemTree = ...

local Slash = {}
ItemTree.Slash = Slash

local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

Slash.COMMAND = "/itemtree"
Slash.SHORT = "/it"

-- "show 2589 extra" -> "show", "2589 extra". An empty message gives "", "".
function Slash.Parse(msg)
  if type(msg) ~= "string" then
    return "", ""
  end
  local trimmed = msg:match("^%s*(.-)%s*$") or ""
  if trimmed == "" then
    return "", ""
  end
  local command, rest = trimmed:match("^(%S+)%s*(.-)$")
  if not command then
    return "", ""
  end
  return command:lower(), rest or ""
end

function Slash.UsageLines()
  return {
    L["ItemTree"] .. " " .. tostring(ItemTree.version or "dev"),
    Slash.COMMAND .. ": " .. L["Open the ItemTree window"],
    Slash.COMMAND .. " help: " .. L["Show this command list"],
    Slash.COMMAND .. " debug: " .. L["Show the data and collector state"],
    Slash.COMMAND .. " report: " .. L["Open a copyable diagnostic report"],
    Slash.COMMAND .. " trace: " .. L["Toggle the tooltip trace"],
    Slash.COMMAND .. " show <id or name>: " .. L["Open the tree for an item or creature"],
    Slash.COMMAND .. " random: " .. L["Show a random item"],
    Slash.COMMAND .. " options, settings: " .. L["Open the settings panel"],
    Slash.COMMAND .. " reset: " .. L["Clear the remembered window position"],
    Slash.COMMAND .. " hud <on, off, unlock, lock, reset>: " .. L["Show or move the fixed position tooltip"],
    Slash.COMMAND .. " cpu [reset]: " .. L["Show where ItemTree spends CPU time"],
    Slash.COMMAND .. " ledger [reset]: " .. L["Show the loot ledger's counts"],
    Slash.COMMAND
      .. " demo <price, money, disenchant> <money or off>, demo level <n or off>: "
      .. L["Pretend an auction price, your money, your level or a disenchant price for the Keep tags"],
    Slash.COMMAND
      .. " demo professions <name rank ..., random [names] [low, mid, high], sample, off>: "
      .. L["Pretend to have these professions instead of your own (crafting is off)"],
    Slash.COMMAND
      .. " demo <spec, talent, quest, have, scenario, at, show, off>: "
      .. L["Pretend your specs, talents, quests and bags for a test; demo off restores everything"],
  }
end

local function joinCounts(counts)
  local keys = {}
  for key in pairs(counts or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = string.format("%s %s", key, tostring(counts[key]))
  end
  return table.concat(parts, ", ")
end

-- Brief U3: one line about memory and the load on demand data addon, from facts read off the
-- client (Slash.MemoryFacts, client side below):
--   { itemTree = KB, data = KB, loaded = true, false or nil, failed = reason or nil }
-- "Memory: ItemTree 2.1 MB, ItemTree_Data 21.9 MB, data addon loaded yes". A number the client
-- would not give reads "unknown", and a failed load adds its reason. Pure.
function Slash.MemoryLine(facts)
  facts = type(facts) == "table" and facts or {}
  local function mb(kb)
    local value = tonumber(kb)
    if not value then
      return "unknown"
    end
    return string.format("%.1f MB", value / 1024)
  end
  local loaded = "unknown"
  if facts.loaded == true then
    loaded = "yes"
  elseif facts.loaded == false then
    loaded = "no"
  end
  local line = string.format(
    "Memory: ItemTree %s, ItemTree_Data %s, data addon loaded %s",
    mb(facts.itemTree),
    mb(facts.data),
    loaded
  )
  if type(facts.failed) == "string" and facts.failed ~= "" then
    line = line .. ", load failed: " .. facts.failed
  end
  return line
end

-- Brief BL4: the data modules built so far, by name, sorted: the keys of Data's own cache, so a
-- QA step such as "no EraSources built after using only the Boss loot tab" reads straight off it.
-- "Modules built: none" for an empty or missing cache. Pure.
function Slash.ModulesBuiltLine(cache)
  local names = {}
  for name in pairs(type(cache) == "table" and cache or {}) do
    names[#names + 1] = tostring(name)
  end
  table.sort(names)
  if #names == 0 then
    return "Modules built: none"
  end
  return "Modules built: " .. table.concat(names, ", ")
end

-- Brief BL4: what the Boss loot model holds, from its Counts() (Core/BossLoot.lua):
-- "Boss loot: places 38, bosses 316, decoded 10, cached 4 places (10 bosses)", with the records it
-- could not read and a refused index added where there are any. present says whether this build
-- carries the tab at all; counts is nil while the tab has not been opened this session. Pure.
function Slash.BossLootLine(present, counts)
  if not present then
    return "Boss loot: not in this build"
  end
  if type(counts) ~= "table" then
    return "Boss loot: not opened this session"
  end
  local line = string.format(
    "Boss loot: places %d, bosses %d, decoded %d, cached %d places (%d bosses)",
    tonumber(counts.places) or 0,
    tonumber(counts.bosses) or 0,
    tonumber(counts.decodes) or 0,
    tonumber(counts.cachedPlaces) or 0,
    tonumber(counts.cachedBosses) or 0
  )
  if (tonumber(counts.malformed) or 0) > 0 then
    line = line .. string.format(", unreadable records %d", tonumber(counts.malformed))
  end
  if type(counts.refused) == "string" and counts.refused ~= "" then
    line = line .. ", refused: " .. counts.refused
  end
  return line
end

-- Brief BL14: "Seen bosses: 3 of 26 new encounters", or with no total where the Boss loot index
-- has not been read this session. Pure.
function Slash.SeenBossesLine(seen, total)
  seen = math.floor(tonumber(seen) or 0)
  if type(total) == "number" then
    return string.format("Seen bosses: %d of %d new encounters", seen, math.floor(total))
  end
  return string.format("Seen bosses: %d (Boss loot index not read this session)", seen)
end

-- Brief BL14: how many boss index entries name no creature id, or nil where the index has not
-- been read this session. Never loads it.
function Slash.NewEncounterTotal()
  local hooks = ItemTree.CollectorHooks
  if type(hooks) == "table" and type(hooks.bossNames) == "table" then
    return tonumber(hooks.bossNamesTotal)
  end
  local pane = ItemTree.UI and ItemTree.UI.BossLoot
  local model = type(pane) == "table" and pane.model or nil
  local Collector = ItemTree.Collector
  if type(model) ~= "table" or type(model.Index) ~= "function" or type(Collector) ~= "table" then
    return nil
  end
  if type(Collector.SeenBossNames) ~= "function" then
    return nil
  end
  local ok, index = pcall(model.Index, model)
  if not ok or type(index) ~= "table" then
    return nil
  end
  local _, total = Collector.SeenBossNames(index)
  return total
end

-- The most priced vendor records the debug command lists one by one; the rest are counted.
Slash.VENDOR_PRICE_LINES = 20

-- Every line the debug command prints, in order. No printing, and no WoW API but the guarded
-- memory read (Slash.MemoryFacts).
function Slash.DebugLines()
  local lines = {}
  local state = ItemTree.state or {}
  lines[#lines + 1] = string.format("%s %s", L["ItemTree"], tostring(ItemTree.version or "dev"))
  lines[#lines + 1] = string.format("Client build: %s", tostring(state.clientBuild or "unknown"))
  -- Brief SV1: which secret value check is live (Core/Util.lua Util.SecretCheck).
  local util = ItemTree.Util
  if type(util) == "table" and type(util.SecretCheck) == "function" then
    lines[#lines + 1] = string.format("Secret values: %s", util.SecretCheck())
  end
  -- Brief PR42: a QA dump taken with pretend professions says so (never which ones).
  local playerSkills = ItemTree.UI and ItemTree.UI.PlayerSkills
  if type(playerSkills) == "table" and type(playerSkills.DemoOn) == "function" and playerSkills.DemoOn() then
    lines[#lines + 1] = "demo professions: on"
  end
  -- Brief BQ13: a dump taken with any demo state on says so (Core/Demo.lua), never what.
  local demoState = ItemTree.Demo
  if type(demoState) == "table" and type(demoState.On) == "function" and demoState.On() then
    lines[#lines + 1] = "demo: on"
  end
  -- Brief K24b (H): the Keep tags' pretend values, each while it is set. Brief BQ13: the commands
  -- ship now, so the lines do too.
  local keepDemo = ItemTree.Keep
  local demoWords = Slash.DemoValueWords
  if type(keepDemo) == "table" and type(keepDemo.DEMO_KINDS) == "table" and type(demoWords) == "function" then
    for _, kind in ipairs({ "price", "money", "level", "disenchant" }) do
      local value = keepDemo[keepDemo.DEMO_KINDS[kind]]
      if value ~= nil then
        lines[#lines + 1] = string.format("demo %s: %s", kind, demoWords(kind, value))
      end
    end
  end
  -- Brief D4: Core says the data build, and every other build the data is exact for.
  if type(ItemTree.DataBuildLine) == "function" then
    lines[#lines + 1] = ItemTree.DataBuildLine()
  else
    lines[#lines + 1] =
      string.format("Data build: %s (%s)", tostring(state.dataBuild or "none"), tostring(state.dataStatus or "none"))
  end
  local status = type(ItemTree.DataStatusLine) == "function" and ItemTree.DataStatusLine() or nil
  if status then
    lines[#lines + 1] = status
  end

  local data = ItemTree.Data
  if data and type(data.Stats) == "function" then
    local stats = data:Stats()
    lines[#lines + 1] = string.format("Modules: %d built of %d", stats.loaded or 0, #(stats.modules or {}))
    local counts = joinCounts(stats.counts)
    if counts ~= "" then
      lines[#lines + 1] = string.format("Data counts: %s", counts)
    end
  else
    lines[#lines + 1] = "Modules: none"
  end
  lines[#lines + 1] = Slash.ModulesBuiltLine(data and data.cache)
  -- Brief PF2: what the login preload did (the data addon, the window, the slicer's count).
  -- Core/Init.lua owns the wording; a Core without it prints one line fewer.
  if type(ItemTree.PreloadStatusLine) == "function" then
    local ok, line = pcall(ItemTree.PreloadStatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end
  -- The Boss loot model is made the first time the tab is shown, and never here.
  local bossPane = ItemTree.UI and ItemTree.UI.BossLoot
  local bossCounts = nil
  if type(bossPane) == "table" and type(bossPane.model) == "table" and type(bossPane.model.Counts) == "function" then
    local ok, counts = pcall(bossPane.model.Counts, bossPane.model)
    if ok and type(counts) == "table" then
      bossCounts = counts
    end
  end
  local bossPresent = false
  if type(bossPane) == "table" and type(bossPane.Present) == "function" then
    local ok, present = pcall(bossPane.Present)
    bossPresent = ok and present == true
  end
  lines[#lines + 1] = Slash.BossLootLine(bossPresent, bossCounts)
  -- Brief PT1 (QA item 275): which way the square beside a creature's name went on the window's
  -- page and on the Boss loot tab's card (a portrait from a display id, or the glyph, and why).
  -- UI/InfoPanel.lua owns the wording; it reads what the last draws kept and asks the client nothing.
  local info = ItemTree.UI and ItemTree.UI.InfoPanel
  if type(info) == "table" and type(info.CardPortraitLine) == "function" then
    local bossCard = type(bossPane) == "table" and type(bossPane.Loot) == "table" and bossPane.Loot.creature or nil
    local ok, line =
      pcall(info.CardPortraitLine, info.headerPortrait, type(bossCard) == "table" and bossCard.headerPortrait or nil)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = Slash.MemoryLine(Slash.MemoryFacts())
  -- Brief QN1: the shipped player module's vendor sides, counts only, where the module is built.
  local players = ItemTree.PlayerSources
  if type(players) == "table" and type(players.DebugLine) == "function" then
    local ok, line = pcall(players.DebugLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  -- Which tooltip path installed on this client, so a missing block can be traced.
  local report = "unknown"
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.InstallReport) == "function" then
    local ok, value = pcall(tooltip.InstallReport)
    if ok and value ~= nil then
      report = tostring(value)
    end
  end
  lines[#lines + 1] = string.format("Tooltip: %s", report)

  -- What the tooltip post calls actually did this session. calls at 0 means the client never
  -- invoked us at all, which is a different fault from every call bailing out.
  local stats = (tooltip and type(tooltip.stats) == "table") and tooltip.stats or {}
  lines[#lines + 1] = string.format(
    "Tooltip calls: %d, rendered: %d, last: %s %s via %s",
    tonumber(stats.calls) or 0,
    tonumber(stats.rendered) or 0,
    tostring(stats.lastItemId or "none"),
    tostring(stats.lastOutcome or "none"),
    tostring(stats.lastSource or "none")
  )
  -- Brief CS4: what the divider rule last did ("drawn", or why not), and how many calls were for
  -- another addon's scanning tooltip and so left alone.
  lines[#lines + 1] = string.format(
    "Tooltip rule: %s, scanning tooltips skipped: %d",
    tostring(stats.lastRule or "none"),
    tonumber(stats.scanning) or 0
  )
  -- Brief TT2 (QA item 251): what the last Ctrl unfold did, and how many modifier changes the
  -- client's event and the poll each saw (the poll alone means no event came, as under the search box).
  if tooltip and type(tooltip.UnfoldDebugLine) == "function" then
    local unfoldOk, unfold = pcall(tooltip.UnfoldDebugLine)
    if unfoldOk and type(unfold) == "string" then
      lines[#lines + 1] = unfold
    end
  end
  -- Brief TV2 (QA item 347): what the block's own wrapping last did, and how many lines the client
  -- wrapped differently from the measure (put back to the client's own wrap).
  if tooltip and type(tooltip.WrapDebugLine) == "function" then
    local wrapOk, wrap = pcall(tooltip.WrapDebugLine)
    if wrapOk and type(wrap) == "string" then
      lines[#lines + 1] = wrap
    end
  end

  local settings = ItemTree.db and ItemTree.db.settings or nil
  lines[#lines + 1] = string.format(
    "Settings: db %s, tooltipEnabled %s",
    ItemTree.db and "present" or "absent",
    tostring(settings and settings.tooltipEnabled)
  )

  -- The settings the window and the two ways into it depend on, so a report says why a
  -- window came up half the size it should or why a click did nothing. Settings only: no
  -- character, realm or account data is ever read here.
  lines[#lines + 1] = string.format(
    "Window scale: %s, tooltip icons: %s",
    tostring(settings and settings.windowScale),
    tostring(settings and settings.tooltipShowIcons)
  )

  local keybind = ItemTree.Keybind
  local boundKey
  if keybind and type(keybind.KeyText) == "function" then
    local ok, value = pcall(keybind.KeyText)
    if ok and type(value) == "string" and value ~= "" then
      boundKey = value
    end
  end
  lines[#lines + 1] = string.format("Keybind: %s", boundKey or "unbound")

  -- The stored value and the words the player chose it by, which are not the same thing on a
  -- locale other than English.
  local clickText
  if keybind and type(keybind.ClickText) == "function" then
    local ok, value = pcall(keybind.ClickText)
    if ok and type(value) == "string" and value ~= "" then
      clickText = value
    end
  end
  lines[#lines + 1] =
    string.format("Click to open: %s (%s)", tostring(settings and settings.clickOpen), clickText or "off")
  -- Brief LC1-full: which click to open paths installed, and the chat link under the cursor (an
  -- item id only).
  if keybind and type(keybind.DebugLine) == "function" then
    local ok, line = pcall(keybind.DebugLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end
  -- Brief LDB1: whether the broker launcher is registered with a broker display's library.
  local broker = ItemTree.UI and ItemTree.UI.DataBroker
  if type(broker) == "table" and type(broker.DebugLine) == "function" then
    local ok, line = pcall(broker.DebugLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  local collector = ItemTree.collector
  if collector and type(collector.Counts) == "function" then
    local ok, counts = pcall(collector.Counts, collector)
    if ok and type(counts) == "table" then
      local line = string.format("Collector: %d records", counts.total or 0)
      -- Brief C20: sightings refused for a source id that is not an id, and stored rows the load
      -- dropped for one, said only when there are any.
      local refused, dropped = tonumber(counts.refused) or 0, tonumber(counts.dropped) or 0
      if refused > 0 or dropped > 0 then
        line = string.format("%s (bad source ids: %d refused, %d dropped at load)", line, refused, dropped)
      end
      lines[#lines + 1] = line
      local byKind = joinCounts(counts.byKind)
      if byKind ~= "" then
        lines[#lines + 1] = string.format("Collector by kind: %s", byKind)
      end
    end
    -- Brief R1: what pruning leaves out: the record store's size against its byte budget and how
    -- many records pruning has evicted since login.
    if type(collector.StoreSize) == "function" and ItemTree.Collector then
      local sizeOk, size = pcall(collector.StoreSize, collector)
      if sizeOk and type(size) == "table" then
        lines[#lines + 1] = ItemTree.Collector.SizeLine(size)
      end
    end
    -- Brief R15: how many old shaped records this login converted to the compact shape, and the
    -- store's size either side. Nothing when none were.
    if ItemTree.Collector and type(ItemTree.Collector.MigrationLine) == "function" then
      local lineOk, line = pcall(ItemTree.Collector.MigrationLine, ItemTree.state and ItemTree.state.collectorMigration)
      if lineOk and type(line) == "string" then
        lines[#lines + 1] = line
      end
    end
    -- Brief R3: the discovery store's size against its own budget, and the login's packing of it.
    -- Sizes and counts only: never a name, and never the character field.
    if type(collector.DiscoveriesStoreSize) == "function" and ItemTree.Collector then
      local discOk, disc = pcall(collector.DiscoveriesStoreSize, collector)
      if discOk and type(disc) == "table" then
        lines[#lines + 1] = ItemTree.Collector.DiscoveriesSizeLine(disc)
      end
      local packOk, packLine =
        pcall(ItemTree.Collector.DiscoveriesMigrationLine, ItemTree.state and ItemTree.state.discoveriesMigration)
      if packOk and type(packLine) == "string" then
        lines[#lines + 1] = packLine
      end
    end
    -- Brief QF1: the quest facts store's size against its own budget, and how many quests it
    -- holds. Counts only, never a quest's facts.
    if type(collector.QuestFactsStoreSize) == "function" and ItemTree.Collector then
      local factsOk, facts = pcall(collector.QuestFactsStoreSize, collector)
      if factsOk and type(facts) == "table" then
        lines[#lines + 1] = ItemTree.Collector.QuestFactsSizeLine(facts)
      end
    end
    -- Brief DM2: the creature displays store's size against its own budget, and how many
    -- creatures it holds. Counts only, never a creature or a display id.
    if type(collector.DisplaysStoreSize) == "function" and ItemTree.Collector then
      local displaysOk, displays = pcall(collector.DisplaysStoreSize, collector)
      if displaysOk and type(displays) == "table" then
        lines[#lines + 1] = ItemTree.Collector.DisplaysSizeLine(displays)
      end
    end
    -- Brief M2: what each vendor the player opened asked, ids and amounts only, one line per
    -- priced record under a count, so a Favour price that never reached a row can be traced to
    -- the window that did or did not state it.
    if type(collector.VendorCosts) == "function" then
      local costsOk, costs = pcall(collector.VendorCosts, collector)
      if costsOk and type(costs) == "table" then
        lines[#lines + 1] = string.format(
          "Collector vendor prices: %d of %d vendor records priced",
          tonumber(costs.priced) or 0,
          tonumber(costs.vendor) or 0
        )
        local priced = type(costs.lines) == "table" and costs.lines or {}
        for index = 1, math.min(#priced, Slash.VENDOR_PRICE_LINES) do
          lines[#lines + 1] = "  " .. tostring(priced[index])
        end
        if #priced > Slash.VENDOR_PRICE_LINES then
          lines[#lines + 1] = string.format("  and %d more", #priced - Slash.VENDOR_PRICE_LINES)
        end
      end
    end
    -- Brief M3: how many vendor records carry where the player stood at the window, a count and
    -- never the coordinates.
    if type(collector.PositionCount) == "function" then
      local posOk, placed = pcall(collector.PositionCount, collector)
      if posOk and type(placed) == "number" then
        lines[#lines + 1] = string.format("Collector vendor positions: %d vendor records with a position", placed)
      end
    end
    -- Brief BL14: how many new encounters the player has seen the creature of, against how many
    -- the boss index names with no creature id. The index is never read here: the total comes from
    -- the collector hooks' lookup or a Boss loot model this session already made.
    if type(collector.SeenBossCount) == "function" then
      local seenOk, seen = pcall(collector.SeenBossCount, collector)
      if seenOk and type(seen) == "number" then
        lines[#lines + 1] = Slash.SeenBossesLine(seen, Slash.NewEncounterTotal())
      end
    end
    -- Brief M3: the shipped Merchant's Favor rows against what the player has seen: how many ship,
    -- how many the player's own visits now stand in for, and how many of those asked a different
    -- Favour amount than the curated file says (the file is what needs fixing).
    local favour = ItemTree.Sources and ItemTree.Sources.Favour or nil
    -- Brief R15: the records as readers take them (the store keeps them compact).
    local store = nil
    if type(collector.Records) == "function" then
      local recordsOk, records = pcall(collector.Records, collector)
      store = recordsOk and records or nil
    end
    if type(favour) == "table" and type(favour.Compare) == "function" and type(favour.Table) == "function" then
      local shippedOk, shipped = pcall(favour.Table)
      local compareOk, compared = pcall(favour.Compare, store)
      if shippedOk and shipped and compareOk and type(compared) == "table" then
        lines[#lines + 1] = string.format(
          "Merchant's Favor rows: %d shipped, %d seen by you, %d seen at a different price",
          tonumber(compared.offers) or 0,
          tonumber(compared.seen) or 0,
          tonumber(compared.differ) or 0
        )
      end
    end
  else
    lines[#lines + 1] = "Collector: not loaded"
  end

  -- Brief L1: the loot ledger's size, counts only.
  lines[#lines + 1] = Slash.LedgerReportLine()
  -- Brief R5a: the places store's size against its budget and the entrances in it.
  lines[#lines + 1] = Slash.PlacesReportLine()

  -- Brief V1: Forever's own vendors, out of the client's tables. The pipeline's counts
  -- (Meta.vendorCounts), then how many of those vendors the player's own visits name. Nothing is
  -- loaded for it (the report says whether the data addon is loaded), so the second line waits for
  -- a vendor row or page to have built the module. Counts only.
  local forever = ItemTree.ForeverVendors
  if type(forever) == "table" and type(forever.Counts) == "function" then
    local visited = nil
    if collector and type(collector.VisitedVendor) == "function" then
      visited = function(npcId)
        local ok, answer = pcall(collector.VisitedVendor, collector, npcId)
        return ok and answer == true
      end
    end
    local ok, counts = pcall(forever.Counts, visited)
    if ok and type(counts) == "table" then
      if counts.vendors then
        lines[#lines + 1] = string.format(
          "Forever vendors: %d vendors, %d items, %d withheld",
          counts.vendors,
          tonumber(counts.items) or 0,
          tonumber(counts.withheld) or 0
        )
      else
        lines[#lines + 1] = "Forever vendors: none in this data"
      end
      if counts.named then
        lines[#lines + 1] =
          string.format("Forever vendors named by your visits: %d of %d", counts.named, tonumber(counts.vendors) or 0)
      elseif counts.vendors then
        lines[#lines + 1] = "Forever vendors named by your visits: not counted until a vendor row is drawn"
      end
    end
  end

  -- Brief GS3: the guessed sources' reader (Core/GuessSources.lua): not read yet, read with its
  -- record count and how many it has decoded, or refused and why. The reader owns the wording,
  -- and asking it reads nothing: the module is only built when a Sources view asks for an item.
  local guessSources = ItemTree.guessSources
  if type(guessSources) == "table" and type(guessSources.StatusLine) == "function" then
    local ok, line = pcall(guessSources.StatusLine, guessSources)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  lines[#lines + 1] = string.format("Collector enabled: %s", tostring(Slash.CollectorEnabled()))

  -- The Summary HUD: what it is set to, where it is anchored and what it is showing, so a
  -- panel nobody can see is told apart from one that is off. UI/EditMode.lua owns the wording.
  local editMode = ItemTree.UI and ItemTree.UI.EditMode
  if editMode and type(editMode.StatusLine) == "function" then
    local ok, line = pcall(editMode.StatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  else
    lines[#lines + 1] = "HUD: not loaded"
  end

  -- Brief Q2: which quest panel hooks the quest marks took. Yes or no answers and a count only;
  -- UI/QuestFlags.lua owns the wording, and a build without it prints one line fewer.
  local questMarks = ItemTree.UI and ItemTree.UI.QuestFlags
  if questMarks and type(questMarks.StatusLine) == "function" then
    local ok, line = pcall(questMarks.StatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  -- Whether collected sources reach the window at all. A store full of records that never
  -- registered draws exactly the same empty tree an empty store does, and this is the line that
  -- tells the two apart; Core/Init.lua owns the wording.
  if type(ItemTree.CollectorStatusLine) == "function" then
    local ok, line = pcall(ItemTree.CollectorStatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  -- Whether the client handed the saved variables back at all, and whether the tables the addon
  -- writes are the ones the client will serialise. The Forever beta currently hands nothing back
  -- (a known client bug), so every setting and every collected record reads as lost on each
  -- login, and that looks exactly like an addon that never saved them. Core/Init.lua owns the
  -- wording; guarded like the other status lines, so a Core without it simply prints one line
  -- fewer.
  if type(ItemTree.DbStatusLine) == "function" then
    local ok, line = pcall(ItemTree.DbStatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  -- The curated quest table, which is the third way a source reaches the window and the one
  -- that is shipped: a quest with no Requires rows is either an empty table or a provider that
  -- never registered. Core/Init.lua owns the wording.
  if type(ItemTree.QuestsStatusLine) == "function" then
    local ok, line = pcall(ItemTree.QuestsStatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end

  -- One line per source database the player has installed, which is the other half of the same
  -- question: an empty Sources tab is either an empty collector or a provider that is absent,
  -- waiting on its own database, or switched off.
  lines[#lines + 1] = string.format("Providers enabled: %s", tostring(Slash.ProvidersEnabled()))
  local providers = ItemTree.Providers
  if providers and type(providers.StatusLines) == "function" then
    local ok, provided = pcall(providers.StatusLines)
    if ok and type(provided) == "table" then
      for _, line in ipairs(provided) do
        lines[#lines + 1] = line
      end
    end
  else
    lines[#lines + 1] = "Providers: not loaded"
  end

  -- Brief K9: which auction addons are installed and how many of the items asked they priced.
  -- Counts only, no item.
  local prices = ItemTree.Prices
  if type(prices) == "table" and type(prices.StatusLine) == "function" then
    local ok, line = pcall(prices.StatusLine)
    if ok and type(line) == "string" then
      lines[#lines + 1] = line
    end
  end
  -- Brief K10: the Keep value as set, in the slider's words ("Keep value: 1 silver"), so a tester
  -- can see what the rule is comparing against.
  -- Brief K16: with the Single colour set, the colour a valuable item wears beside it.
  local keep = ItemTree.Keep
  if type(keep) == "table" and type(keep.ValueStatusLine) == "function" then
    local ok, line = pcall(keep.ValueStatusLine)
    if ok and type(line) == "string" then
      local overlay = ItemTree.UI and ItemTree.UI.Overlay
      if type(overlay) == "table" and type(overlay.ValueColourName) == "function" then
        local named, colour = pcall(overlay.ValueColourName, (ItemTree.db and ItemTree.db.settings) or {})
        if named and type(colour) == "string" then
          line = line .. ", valuable colour " .. colour
        end
      end
      lines[#lines + 1] = line
    end
  end

  -- What the bag overlay is doing: counts and yes or no answers only. UI/Overlay.lua owns the
  -- wording, and a build without the pane simply prints nothing here.
  local overlay = ItemTree.UI and ItemTree.UI.Overlay
  if overlay and type(overlay.DebugLines) == "function" then
    local ok, overlayLines = pcall(overlay.DebugLines)
    if ok and type(overlayLines) == "table" then
      for _, line in ipairs(overlayLines) do
        if type(line) == "string" then
          lines[#lines + 1] = line
        end
      end
    end
  end

  -- The Item chain view's last few menu picks. A pick out of one of that pane's drop down lists can
  -- fail without raising anything the player would ever see, and the owner has reported exactly
  -- that twice with nothing to hand over but a screenshot; these lines are what to send instead.
  -- UI/Chain.lua owns the wording and keeps the trail in memory only: what was clicked, the pin
  -- or the chain that was written, how many chains came back, and any error. Nothing is saved
  -- and nothing about the character, the realm or the account is read.
  local chain = ItemTree.UI and ItemTree.UI.Chain
  if chain and type(chain.TrailLines) == "function" then
    local ok, trailLines = pcall(chain.TrailLines, chain.trail)
    if ok and type(trailLines) == "table" then
      for _, line in ipairs(trailLines) do
        if type(line) == "string" then
          lines[#lines + 1] = line
        end
      end
    end
  end

  -- Brief SC2 (QA item 262, Show craft "did nothing" at times): the last Show craft and View
  -- profession clicks, where the Professions tab is loaded (ItemTree_Professions/Core/Craft.lua
  -- Craft.DebugLines): when, the line, held, the search fill, the open call's answer and whether the
  -- window showed. Line ids and yes or no words only.
  local craft = ItemTree.ProfessionsCraft
  if type(craft) == "table" and type(craft.DebugLines) == "function" then
    local ok, craftLines = pcall(craft.DebugLines)
    if ok and type(craftLines) == "table" then
      for _, line in ipairs(craftLines) do
        if type(line) == "string" then
          lines[#lines + 1] = line
        end
      end
    end
  end

  -- Brief G1: the errors the boundary caught this session (Core/Guard.lua), the count and the last
  -- few as "where: first line of the message (xK)". Every one of them also went to the client's
  -- error handler the first time it was met; this is the copy a player pastes into a report.
  local guard = ItemTree.Guard
  if type(guard) == "table" and type(guard.DebugLines) == "function" then
    local ok, guardLines = pcall(guard.DebugLines)
    if ok and type(guardLines) == "table" then
      for _, line in ipairs(guardLines) do
        if type(line) == "string" then
          lines[#lines + 1] = line
        end
      end
    end
  end
  return lines
end

-- Whether the player wants sources read out of the addons they have installed. Reads the
-- setting only: no character, realm or account data is touched, and no addon is loaded to
-- answer it.
function Slash.ProvidersEnabled()
  local settings = ItemTree.db and ItemTree.db.settings
  if not settings then
    return true
  end
  return settings.useProviders ~= false
end

function Slash.CollectorEnabled()
  local settings = ItemTree.db and ItemTree.db.settings
  return settings ~= nil and settings.collectorEnabled and true or false
end

-- What one item id is called. Core's Graph is the one place a key becomes a name, so a typed id
-- reads the same as the window's own title: the data build's name, the live client's where the
-- realm has found an item the build withholds, and "Undiscovered mail head" for a withheld item
-- nothing has found yet. Guarded, so it answers under a Core with no Graph.
local function itemName(itemId)
  local graph = ItemTree.Graph
  if graph and type(graph.Name) == "function" then
    local ok, name = pcall(graph.Name, "item:" .. tostring(itemId))
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local data = ItemTree.Data
  local item = data and type(data.GetItem) == "function" and data:GetItem(itemId) or nil
  if item and type(item.n) == "string" and item.n ~= "" then
    return item.n
  end
  return nil
end

-- What /itemtree show names, as itemId, name, key. The order is: a numeric item id, an exact item
-- name, an exact creature name, the lowest item id whose name contains the text, and then the
-- first creature name (alphabetically) that contains it. An item answers its id, its name and its
-- item key; a creature answers nil for the id, its name and the npc key its page opens on
-- (Core/Data.lua Data:FindCreature). Nothing at all where nothing matches.
--
-- The item name search walks the data's own name index, which no withheld item is in: the build
-- states no name for one, and the addon ships none, so a withheld item is reached by its id. The
-- creature names are the shipped Classic Era table's own, so nothing is asked of the client.
--
-- Brief SM1 (QA item 338, "/itemtree show Night Watch Guard" opened nothing): where the Classic Era
-- table holds no exact name, the search box's own creature lookup (Core/Data.lua
-- Data:SearchCreatures: the Classic Era table, the Forever Creatures module and the player's own
-- records) is asked too. Its exact name stands where a Classic Era exact name would; else, where
-- the Classic Era table holds no partial name either, its first result stands as the partial one.
-- Local data only, one search for one typed command.
local function itemKey(itemId)
  local graph = ItemTree.Graph
  if graph and type(graph.Key) == "function" then
    return graph.Key("item", itemId)
  end
  return "item:" .. tostring(itemId)
end

local function findCreature(data, text)
  if not data or type(data.FindCreature) ~= "function" then
    return nil
  end
  local ok, entry, exact = pcall(data.FindCreature, data, text)
  if not ok or type(entry) ~= "table" or type(entry.key) ~= "string" then
    return nil
  end
  return entry, exact == true
end

-- Brief SM1: the search box's creature lookup, as findCreature answers: the result whose name is
-- the text (case insensitive) and true, else the first result with a page and false, else nil.
Slash.SHOW_CREATURE_LIMIT = 20

local function searchCreature(data, text)
  if not data or type(data.SearchCreatures) ~= "function" then
    return nil
  end
  local ok, found = pcall(data.SearchCreatures, data, text, Slash.SHOW_CREATURE_LIMIT)
  if not ok or type(found) ~= "table" then
    return nil
  end
  local first = nil
  for _, entry in ipairs(found) do
    if type(entry) == "table" and type(entry.key) == "string" and type(entry.name) == "string" then
      if entry.name:lower() == text then
        return entry, true
      end
      first = first or entry
    end
  end
  if first then
    return first, false
  end
  return nil
end

function Slash.ResolveItem(text)
  if type(text) ~= "string" then
    return nil
  end
  local wanted = (text:match("^%s*(.-)%s*$") or ""):lower()
  if wanted == "" then
    return nil
  end
  local id = tonumber(wanted)
  if id then
    return id, itemName(id), itemKey(id)
  end
  local data = ItemTree.Data
  if not data or type(data.Get) ~= "function" then
    return nil
  end
  -- Brief P4: the Names module answers, so a name never builds every Items table.
  local partialId, partialName
  if type(data.ResolveItemName) == "function" then
    local ok, exactId, exactName, foundId, foundName = pcall(data.ResolveItemName, data, wanted)
    if ok and exactId then
      return exactId, exactName, itemKey(exactId)
    end
    if ok then
      partialId, partialName = foundId, foundName
    end
  end
  local creature, exact = findCreature(data, wanted)
  if not exact then
    local met, metExact = searchCreature(data, wanted)
    if met and (metExact or not creature) then
      creature, exact = met, metExact
    end
  end
  if creature and exact then
    return nil, creature.name, creature.key
  end
  if partialId then
    return partialId, partialName, itemKey(partialId)
  end
  if creature then
    return nil, creature.name, creature.key
  end
  return nil
end

-- Brief P2: /itemtree cpu. The handlers worth reading (docs/ideas/cpu-performance.md, "In client
-- method"), each as its path from the ItemTree table. Each is read through its table field,
-- which is how every caller reaches it, so a reading covers every call. A handler missing on
-- this build is skipped.
Slash.CPU_HANDLERS = {
  { "Tooltip", "OnItem" },
  { "CollectorHooks", "NoteItem" },
  { "CollectorHooks", "QuestObjectiveIndex" },
  { "CollectorHooks", "OnEvent" },
  { "UI", "Overlay", "Refresh" },
  { "UI", "EditMode", "Tick" },
  { "Graph", "Children" },
  { "Data", "SearchItems" },
  { "UI", "Frame", "RunSearch" },
  { "UI", "Tree", "Draw" },
  { "UI", "Discoveries", "Draw" },
}

local function milliseconds(value)
  local number = tonumber(value)
  if not number then
    return "unknown"
  end
  return string.format("%.1f ms", number)
end

-- The copyable block /itemtree cpu shows, from a table of readings (Slash.CpuReadings, client
-- side below):
--   { total = ms or nil, handlers = { { name, ms, calls } }, tooltipCalls = n or nil }
-- One line for the addon total, one per handler read, and the tooltip rebuild count to divide
-- by. Diagnostic lines like /itemtree debug's, so not translated. Pure.
function Slash.CpuLines(readings)
  readings = type(readings) == "table" and readings or {}
  local lines = {
    string.format("%s %s CPU, since the last reset or reload", L["ItemTree"], tostring(ItemTree.version or "dev")),
    "Addon total: " .. milliseconds(readings.total),
  }
  for _, handler in ipairs(type(readings.handlers) == "table" and readings.handlers or {}) do
    if type(handler) == "table" and type(handler.name) == "string" then
      local line = handler.name .. ": " .. milliseconds(handler.ms)
      local calls = tonumber(handler.calls)
      if calls then
        line = line .. string.format(", %d calls", calls)
      end
      lines[#lines + 1] = line
    end
  end
  local rebuilds = tonumber(readings.tooltipCalls)
  lines[#lines + 1] = "Tooltip calls: " .. (rebuilds and string.format("%d", rebuilds) or "unknown")
  return lines
end

-- The one chat line /itemtree cpu prints when there is nothing to read: profiling is off (false)
-- or the client cannot say (nil). nil when profiling is on. Pure.
function Slash.CpuOffLine(profiling)
  if profiling == true then
    return nil
  end
  if profiling == false then
    return L["Profiling is off. Type /console scriptProfile 1, then /reload. It slows every addon: turn it off after."]
  end
  return L["This client cannot say whether script profiling is on."]
end

-- Brief L1: the ledger's line for /itemtree debug and report, or a line that says why there is
-- none. Core/Ledger.lua owns the wording and the counting. Pure.
function Slash.LedgerReportLine()
  local ledger = ItemTree.Ledger
  local store = ItemTree.db and ItemTree.db.ledger
  if type(ledger) ~= "table" or type(ledger.ReportLine) ~= "function" or type(store) ~= "table" then
    return "Ledger: not loaded"
  end
  local ok, line = pcall(ledger.ReportLine, store)
  if ok and type(line) == "string" then
    return line
  end
  return "Ledger: not loaded"
end

-- Brief R5a: the places store's line for /itemtree debug and report, or a line that says why
-- there is none. Core/Places.lua owns the wording and the counting. Pure.
function Slash.PlacesReportLine()
  local places = ItemTree.Places
  local store = ItemTree.db and ItemTree.db.places
  if type(places) ~= "table" or type(places.ReportLine) ~= "function" or type(store) ~= "table" then
    return "Places: not loaded"
  end
  local ok, line = pcall(places.ReportLine, store)
  if ok and type(line) == "string" then
    return line
  end
  return "Places: not loaded"
end

-- /itemtree ledger, ledger reset and ledger reset confirm, as the lines to print. Clearing
-- takes the confirm word, so a stray "ledger reset" asks rather than clears. Pure: it touches
-- only ItemTreeDB.ledger through Core/Ledger.lua.
function Slash.LedgerLines(rest)
  local ledger = ItemTree.Ledger
  local store = ItemTree.db and ItemTree.db.ledger
  if type(ledger) ~= "table" or type(ledger.SummaryLines) ~= "function" or type(store) ~= "table" then
    return { L["The loot ledger is not available"] }
  end
  local words = {}
  for word in (type(rest) == "string" and rest or ""):lower():gmatch("%S+") do
    words[#words + 1] = word
  end
  if words[1] == "reset" then
    if words[2] == ledger.CONFIRM_WORD then
      ledger.Reset(store)
      return { L["Loot ledger cleared"] }
    end
    return {
      string.format(
        L["This clears every count in the loot ledger. Type %s to do it."],
        Slash.COMMAND .. " ledger reset " .. ledger.CONFIRM_WORD
      ),
    }
  end
  local ok, lines = pcall(ledger.SummaryLines, store)
  if not ok or type(lines) ~= "table" then
    return { L["The loot ledger is not available"] }
  end
  return lines
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- Whether the client's scriptProfile CVar is on: true, false, or nil where the client cannot
-- say. C_CVar.GetCVar first, then the old global GetCVar, each under pcall.
function Slash.CpuProfiling()
  local value = nil
  local cvar = rawget(_G, "C_CVar")
  if type(cvar) == "table" and type(cvar.GetCVar) == "function" then
    local ok, answer = pcall(cvar.GetCVar, "scriptProfile")
    if ok then
      value = answer
    end
  end
  if value == nil then
    local getCVar = rawget(_G, "GetCVar")
    if type(getCVar) == "function" then
      local ok, answer = pcall(getCVar, "scriptProfile")
      if ok then
        value = answer
      end
    end
  end
  if value == nil then
    return nil
  end
  return tostring(value) == "1"
end

-- The readings Slash.CpuLines words: UpdateAddOnCPUUsage, then the addon total and each handler
-- (GetFunctionCPUUsage with subroutines), each call under pcall. Reads timings and counters only.
function Slash.CpuReadings()
  local readings = { handlers = {} }
  local update = rawget(_G, "UpdateAddOnCPUUsage")
  if type(update) == "function" then
    pcall(update)
  end
  local addonUsage = rawget(_G, "GetAddOnCPUUsage")
  if type(addonUsage) == "function" then
    local ok, ms = pcall(addonUsage, "ItemTree")
    readings.total = ok and tonumber(ms) or nil
  end
  local functionUsage = rawget(_G, "GetFunctionCPUUsage")
  for _, path in ipairs(Slash.CPU_HANDLERS) do
    local target = ItemTree
    for _, field in ipairs(path) do
      target = type(target) == "table" and rawget(target, field) or nil
    end
    if type(target) == "function" then
      local handler = { name = table.concat(path, ".") }
      if type(functionUsage) == "function" then
        local ok, ms, calls = pcall(functionUsage, target, true)
        if ok then
          handler.ms, handler.calls = tonumber(ms), tonumber(calls)
        end
      end
      readings.handlers[#readings.handlers + 1] = handler
    end
  end
  local tooltip = ItemTree.Tooltip
  local stats = type(tooltip) == "table" and tooltip.stats or nil
  readings.tooltipCalls = type(stats) == "table" and tonumber(stats.calls) or nil
  return readings
end

-- /itemtree cpu and /itemtree cpu reset. With profiling off, or a client that cannot say, one
-- chat line says how to turn it on. Otherwise the block goes to the report window, the same
-- copyable edit box /itemtree report opens, and to chat where there is no window. Answers
-- whether a reading was shown (or, for reset, whether the count was reset).
function Slash.Cpu(rest)
  local what = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
  local offLine = Slash.CpuOffLine(Slash.CpuProfiling())
  if offLine then
    Slash.Print(offLine)
    return false
  end
  if what == "reset" then
    local reset = rawget(_G, "ResetCPUUsage")
    if type(reset) == "function" and pcall(reset) then
      Slash.Print(L["ItemTree CPU usage reset"])
      return true
    end
    Slash.Print(L["This client cannot reset CPU usage"])
    return false
  end
  local lines = Slash.CpuLines(Slash.CpuReadings())
  local report = ItemTree.UI and ItemTree.UI.Report
  if report and type(report.Show) == "function" then
    local ok, shown = pcall(report.Show, table.concat(lines, "\n"))
    if ok and shown then
      return true
    end
  end
  Slash.PrintLines(lines)
  return true
end

-- The facts Slash.MemoryLine words: UpdateAddOnMemoryUsage, then GetAddOnMemoryUsage for both
-- addon folders in KB, whether the client says ItemTree_Data is loaded (C_AddOns.IsAddOnLoaded,
-- falling back to IsAddOnLoaded) and why its load failed, if it did. Every call guarded; a client
-- without one leaves that fact out.
function Slash.MemoryFacts()
  local facts = {}
  local update = rawget(_G, "UpdateAddOnMemoryUsage")
  if type(update) == "function" then
    pcall(update)
  end
  local usage = rawget(_G, "GetAddOnMemoryUsage")
  if type(usage) == "function" then
    local ok, kb = pcall(usage, "ItemTree")
    facts.itemTree = ok and tonumber(kb) or nil
    local okData, dataKb = pcall(usage, "ItemTree_Data")
    facts.data = okData and tonumber(dataKb) or nil
  end
  local data = ItemTree.Data
  if type(data) == "table" then
    if type(data.OnDemandAddonLoaded) == "function" then
      local ok, loaded = pcall(data.OnDemandAddonLoaded, data)
      if ok then
        facts.loaded = loaded
      end
    end
    facts.failed = data.onDemandFailed
  end
  return facts
end

function Slash.Print(text)
  -- Brief E2E-1 (the e2e plan's addition 7): the developer only e2e run's listener, handed each line
  -- before it is printed (Slash.listener, nil otherwise). Our own helper, never the client's print.
  local listen = Slash.listener
  if type(listen) == "function" then
    pcall(listen, text)
  end
  local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
  if chat and type(chat.AddMessage) == "function" then
    chat:AddMessage(tostring(text))
    return true
  end
  local out = rawget(_G, "print")
  if type(out) == "function" then
    out(tostring(text))
    return true
  end
  return false
end

function Slash.PrintLines(lines)
  for _, line in ipairs(lines or {}) do
    Slash.Print(line)
  end
end

-- Opens the window on the item, and only ever opens it: a typed command should never close a
-- window, so this calls Frame.Open where the key binding calls Frame.Toggle. Open returns false
-- only where there is no client to build a window on, and the tooltip block is printed to chat
-- instead so the command is still useful.
function Slash.Show(rest)
  -- Brief BQ24 (QA item 27): "/itemtree show" with nothing after it is an open with no item, the
  -- key's and the minimap button's (Frame.OpenDefault returns to the tab the window was closed on).
  -- A typed command never closes the window, so one already up stays as it is.
  if type(rest) ~= "string" or rest:match("^%s*$") then
    local window = ItemTree.UI and ItemTree.UI.Frame
    if window and type(window.IsShown) == "function" and window.IsShown() then
      return true
    end
    return Slash.OpenDefault()
  end
  local itemId, name, key = Slash.ResolveItem(rest)
  if not key then
    Slash.Print(L["No item or creature found"])
    return false
  end
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if frame and type(frame.Open) == "function" and frame.Open(key) then
    return true
  end
  -- A creature has no tooltip block to print: the window is the only place its page is drawn.
  if not itemId then
    Slash.Print(name or L["ItemTree"])
    return false
  end
  Slash.Print(string.format("%s (%d)", name or L["ItemTree"], itemId))
  local tooltip = ItemTree.Tooltip
  if tooltip and type(tooltip.BuildLines) == "function" then
    for _, line in ipairs(tooltip.BuildLines(itemId)) do
      Slash.Print(Theme.Colorise(line.colorKey, line.text))
    end
  end
  return false
end

-- Opens the report window, which is the debug lines and the recent trace in one selectable edit
-- box. UI/Report.lua is looked up at call time, the way every other module is here, and a client
-- that will not give us a window falls back to printing the same debug lines to chat.
function Slash.Report()
  local report = ItemTree.UI and ItemTree.UI.Report
  if report and type(report.Show) == "function" then
    local ok, shown = pcall(report.Show)
    if ok and shown then
      return true
    end
  end
  Slash.PrintLines(Slash.DebugLines())
  return false
end

-- Toggles the tooltip trace. In memory only: nothing is written to saved variables, and a
-- reload turns it off again.
function Slash.Trace()
  local tooltip = ItemTree.Tooltip
  if not tooltip then
    Slash.Print(L["Tooltip trace off"])
    return false
  end
  tooltip.trace = not tooltip.trace
  Slash.Print(tooltip.trace and L["Tooltip trace on"] or L["Tooltip trace off"])
  return tooltip.trace and true or false
end

-- The default action: a right click on the minimap button and the addon compartment entry both
-- land here (the bare command opens the window since brief SL1, see Slash.Handle). A client with
-- no Settings API shows a random item instead, so the button always does something.
function Slash.Default()
  local options = ItemTree.Options
  if options and type(options.Open) == "function" and options.Open() then
    return true
  end
  return Slash.ShowRandom()
end

-- Brief D2: says the data is missing. Where ItemTree_Data failed to load, Core's own once per
-- session line (Data:WarnOnDemandFailed) is all that is said, and nothing at all once it has gone
-- out, so a player clicking again is not told ten times. The terse line is for a build with no
-- failed load behind the empty answer. Answers whether a failed load was the reason.
function Slash.SayNoData()
  local data = ItemTree.Data
  local failed = type(data) == "table" and data.onDemandFailed or nil
  if failed then
    if type(data.WarnOnDemandFailed) == "function" then
      pcall(data.WarnOnDemandFailed, data)
    end
    return true
  end
  Slash.Print(L["No item data loaded"])
  return false
end

-- rng is passed through to Data:RandomItemId, so a test can pick deterministically.
function Slash.ShowRandom(rng)
  local data = ItemTree.Data
  local itemId = data and type(data.RandomItemId) == "function" and data:RandomItemId(rng) or nil
  if not itemId then
    Slash.SayNoData()
    return false
  end
  return Slash.Show(tostring(itemId))
end

-- The window asked for with nothing pointed at: the key binding pressed with no item under the
-- cursor, and a left click on the minimap button. UI/Frame.lua owns the rule (Frame.OpenDefault)
-- and this owns the one chat line, so the two ways in behave the same and say the same thing.
--
-- Opening the item this session last showed says nothing, because that is the window the player
-- left and asked for back, and neither does the press that closes that window again. A pick says
-- why, because an item nobody named has just appeared, and it only says so when the window really
-- did open on one: a line promising an item nobody can see is worse than no line at all.
--
-- rng is handed through for the specs. Answers whether the window is open afterwards.
function Slash.OpenDefault(rng)
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if not (frame and type(frame.OpenDefault) == "function") then
    return false
  end
  local ok, opened, choice = pcall(frame.OpenDefault, rng)
  if not ok then
    return false
  end
  if choice == "missing" or choice == "none" then
    -- Nothing to pick at all, which is a build whose data never loaded. With a failed load the
    -- window opened on its own empty state (brief D2) and chat hears Core's line once a session;
    -- a press that closed that window says nothing either. The window has its own words for
    -- every other miss.
    Slash.SayNoData()
    return opened and true or false
  end
  if not opened then
    return false
  end
  if choice == "new" then
    Slash.Print(L["Opening a random new item"])
  elseif choice == "random" then
    Slash.Print(L["Opening a random item"])
  end
  return true
end

function Slash.ResetWindow()
  local window = ItemTree.CHAR_DEFAULTS and ItemTree.CHAR_DEFAULTS.window
  if not (ItemTree.charDb and window) then
    return false
  end
  local current = ItemTree.charDb.window or {}
  for key, value in pairs(window) do
    current[key] = value
  end
  ItemTree.charDb.window = current
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if frame and type(frame.ApplyWindow) == "function" then
    frame.ApplyWindow()
  end
  return true
end

-- /itemtree hud and its five sub commands. The bare command toggles the panel, which is what
-- a player who typed it wants; everything else is named. UI/EditMode.lua owns every decision
-- here, so this only picks the call and says which way it went.
function Slash.Hud(rest)
  local editMode = ItemTree.UI and ItemTree.UI.EditMode
  if type(editMode) ~= "table" or type(editMode.SetEnabled) ~= "function" then
    Slash.Print(L["The fixed position tooltip is not available on this client"])
    return false
  end
  local what = (type(rest) == "string" and rest:match("^%s*(%S*)") or ""):lower()
  if what == "" then
    local on = editMode.Toggle()
    Slash.Print(on and L["Fixed position tooltip on"] or L["Fixed position tooltip off"])
    return on
  end
  if what == "on" or what == "off" then
    editMode.SetEnabled(what == "on")
    Slash.Print(what == "on" and L["Fixed position tooltip on"] or L["Fixed position tooltip off"])
    return what == "on"
  end
  if what == "unlock" or what == "lock" then
    local unlock = what == "unlock"
    editMode.SetUnlocked(unlock)
    if unlock then
      Slash.Print(L["Fixed position tooltip unlocked, drag it where you want it"])
    else
      Slash.Print(L["Fixed position tooltip locked"])
    end
    return unlock
  end
  if what == "reset" then
    if type(editMode.ResetPosition) == "function" and editMode.ResetPosition() then
      Slash.Print(L["Fixed position tooltip position reset"])
      return true
    end
    return false
  end
  Slash.PrintLines(Slash.UsageLines())
  return false
end


-- /itemtree demo professions, brief PR42. The owner cannot level every profession to test the
-- Professions tab, so this pretends the player has the ones named, at the ranks named, through the
-- seams in UI/PlayerSkills.lua (memory only, a /reload ends it). The profession names are the ones
-- the data ships (ProfessionTracks' lines and Assets' profession bar kits, each named by
-- Keep.SkillName), matched without case or spaces, by a unique start of three letters or more, or
-- by one of the short forms below.
Slash.DEMO_SHORT = { bs = "blacksmithing", lw = "leatherworking", fa = "firstaid", mine = "mining" }
Slash.DEMO_SAMPLE = "tailoring 120 cooking 40 first aid 75"
Slash.DEMO_MAX_RANK = 300

local function compact(text)
  return (tostring(text or ""):lower():gsub("[^%a]", ""))
end

-- "FirstAid" -> "First Aid": a kit name read as words. Pure.
local function kitWords(kit)
  return (tostring(kit):gsub("(%l)(%u)", "%1 %2"))
end

-- The professions the demo accepts: { { line, name } } sorted by name, from the data the addon
-- ships. Reads no client API.
function Slash.DemoChoices()
  local lines = {}
  local tracks = ItemTree.ProfessionTracks
  for line in pairs(type(tracks) == "table" and type(tracks.lines) == "table" and tracks.lines or {}) do
    if type(line) == "number" then
      lines[line] = true
    end
  end
  local assets = ItemTree.Assets
  local kits = type(assets) == "table" and type(assets.professionBarKits) == "table" and assets.professionBarKits or {}
  for line in pairs(kits) do
    if type(line) == "number" then
      lines[line] = true
    end
  end
  local keep = ItemTree.Keep
  local out = {}
  for line in pairs(lines) do
    local name = nil
    if type(keep) == "table" and type(keep.SkillName) == "function" then
      local ok, named = pcall(keep.SkillName, line)
      name = ok and type(named) == "string" and named ~= "" and named or nil
    end
    if not name and type(kits[line]) == "string" then
      name = kitWords(kits[line])
    end
    if name then
      out[#out + 1] = { line = line, name = name }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

-- The choice a typed name means, or nil: the whole name, a short form, or a unique start of three
-- letters or more, all without case or spaces. Pure.
function Slash.DemoResolve(word, choices)
  local typed = compact(word)
  if typed == "" then
    return nil
  end
  typed = Slash.DEMO_SHORT[typed] or typed
  local found = nil
  for _, choice in ipairs(type(choices) == "table" and choices or {}) do
    local name = compact(choice.name)
    if name == typed then
      return choice
    end
    if #typed >= 3 and name:sub(1, #typed) == typed then
      if found then
        found = false
      elseif found == nil then
        found = choice
      end
    end
  end
  return found or nil
end

-- Brief PR42b: the rank bands a random set draws from (none named: 1 to Slash.DEMO_MAX_RANK), and
-- the secondary skill lines (First Aid, Cooking, Fishing) a random pick leaves out unless named.
Slash.DEMO_BANDS = { low = { 1, 75 }, mid = { 76, 225 }, high = { 226, 300 } }
Slash.DEMO_BAND_WORDS = "low, mid, high"
Slash.DEMO_SECONDARY = { [129] = true, [185] = true, [356] = true }
Slash.DEMO_RANDOM_PICKS = 2

local function unknownProfession(typed, choices)
  local names = {}
  for index, known in ipairs(type(choices) == "table" and choices or {}) do
    names[index] = known.name
  end
  return {
    kind = "error",
    message = string.format(L["Unknown profession: %s. Use one of: %s"], typed, table.concat(names, ", ")),
  }
end

-- "random [<name> ...] [low|mid|high]": the named professions, or two different primaries drawn at
-- random, each with an independent whole rank drawn in the band. A name may be several words ("first
-- aid"): the longest run of words that names a profession is taken. An unknown last word is read as
-- a bad band. draw(lo, hi) answers a whole number in lo..hi (math.random, seeded by the client; this
-- never seeds it). Answers the same shapes as Slash.ParseDemoProfessions.
function Slash.ParseDemoRandom(words, choices, draw)
  draw = draw or math.random
  local band = { 1, Slash.DEMO_MAX_RANK }
  local last = #words
  if last > 0 and Slash.DEMO_BANDS[words[last]:lower()] then
    band = Slash.DEMO_BANDS[words[last]:lower()]
    last = last - 1
  end
  local picked = {}
  local index = 1
  while index <= last do
    local choice, upto, reach = nil, nil, index - 1
    -- A run never takes a word with a digit in it: random draws the ranks, so a typed one is refused.
    while reach < last and not words[reach + 1]:find("%d") do
      reach = reach + 1
    end
    for stop = reach, index, -1 do
      local typed = {}
      for at = index, stop do
        typed[#typed + 1] = words[at]
      end
      choice = Slash.DemoResolve(table.concat(typed, " "), choices)
      if choice then
        upto = stop
        break
      end
    end
    if not choice then
      if index == #words then
        return {
          kind = "error",
          message = string.format(L["Unknown band: %s. Use one of: %s"], words[index], Slash.DEMO_BAND_WORDS),
        }
      end
      return unknownProfession(words[index], choices)
    end
    picked[#picked + 1] = choice
    index = upto + 1
  end
  if #picked == 0 then
    local primaries = {}
    for _, choice in ipairs(type(choices) == "table" and choices or {}) do
      if not Slash.DEMO_SECONDARY[choice.line] then
        primaries[#primaries + 1] = choice
      end
    end
    for _ = 1, math.min(Slash.DEMO_RANDOM_PICKS, #primaries) do
      picked[#picked + 1] = table.remove(primaries, draw(1, #primaries))
    end
  end
  local entries = {}
  for _, choice in ipairs(picked) do
    entries[#entries + 1] = { line = choice.line, name = choice.name, rank = draw(band[1], band[2]) }
  end
  return { kind = "set", entries = entries }
end

-- "/itemtree demo professions ..." read: { kind = "show" }, { kind = "off" }, { kind = "set",
-- entries = { { line, name, rank } } } or { kind = "error", message }. sample is the owner's QA set
-- (Slash.DEMO_SAMPLE); random is Slash.ParseDemoRandom, with draw passed through. Ranks are whole
-- numbers from 1 to Slash.DEMO_MAX_RANK. Pure but for the random draw.
function Slash.ParseDemoProfessions(rest, choices, draw)
  local words = {}
  for word in tostring(rest or ""):gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    return { kind = "show" }
  end
  if words[1]:lower() == "random" then
    table.remove(words, 1)
    return Slash.ParseDemoRandom(words, choices, draw)
  end
  if #words == 1 and words[1]:lower() == "off" then
    return { kind = "off" }
  end
  -- Brief BQ13: none pretends the player has no profession at all (Core/Demo.lua).
  if #words == 1 and words[1]:lower() == "none" then
    return { kind = "none" }
  end
  if #words == 1 and words[1]:lower() == "sample" then
    return Slash.ParseDemoProfessions(Slash.DEMO_SAMPLE, choices)
  end
  local rankError = string.format(L["Give each profession a rank from 1 to %d"], Slash.DEMO_MAX_RANK)
  local entries, name = {}, {}
  for _, word in ipairs(words) do
    local rank = word:match("^%-?[%d%.]+$") and tonumber(word) or nil
    if rank then
      if #name == 0 or rank ~= math.floor(rank) or rank < 1 or rank > Slash.DEMO_MAX_RANK then
        return { kind = "error", message = rankError }
      end
      local typed = table.concat(name, " ")
      local choice = Slash.DemoResolve(typed, choices)
      if not choice then
        return unknownProfession(typed, choices)
      end
      entries[#entries + 1] = { line = choice.line, name = choice.name, rank = rank }
      name = {}
    else
      name[#name + 1] = word
    end
  end
  if #name > 0 then
    return { kind = "error", message = rankError }
  end
  return { kind = "set", entries = entries }
end

-- The one line a change prints: "Demo: Tailoring 120, Cooking 40, First Aid 75", or "Demo
-- professions off" for none. Pure.
function Slash.DemoProfessionsLine(entries)
  local parts = {}
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    parts[#parts + 1] = string.format("%s %d", tostring(entry.name), tonumber(entry.rank) or 0)
  end
  if #parts == 0 then
    return L["Demo professions off"]
  end
  return string.format(L["Demo: %s"], table.concat(parts, ", "))
end

-- Sets, clears or prints the pretend professions, and prints one line through the K7 demo's print
-- path (Slash.Print). Answers whether the demo is on afterwards, or nil for an error.
function Slash.DemoProfessions(rest)
  local skills = ItemTree.UI and ItemTree.UI.PlayerSkills
  if type(skills) ~= "table" or type(skills.SetDemo) ~= "function" then
    return nil
  end
  local parsed = Slash.ParseDemoProfessions(rest, Slash.DemoChoices())
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  local demo = Slash.DemoModule()
  if parsed.kind ~= "show" then
    local entries = parsed.entries
    if parsed.kind == "none" then
      entries = "none"
    elseif parsed.kind ~= "set" then
      entries = nil
    end
    -- Brief BQ13: through the demo state where it is loaded, which publishes the change.
    if demo and type(demo.SetProfessions) == "function" then
      demo.SetProfessions(entries)
    else
      skills.SetDemo(entries ~= "none" and entries or {}, entries == "none")
      if type(skills.ApplyDemo) == "function" then
        pcall(skills.ApplyDemo)
      end
    end
  end
  local entries = skills.DemoEntries()
  if skills.DemoOn() and #entries == 0 then
    Slash.Print(L["Demo: no professions"])
  else
    Slash.Print(Slash.DemoProfessionsLine(entries))
  end
  return skills.DemoOn()
end

-- Brief K24b (H): money typed the game's way, "600g", "1s60c", "1g 20s 5c", or a bare number of
-- copper, as copper; nil for anything else. Pure.
function Slash.ParseMoney(text)
  if type(text) ~= "string" then
    return nil
  end
  local plain = text:lower():gsub("%s+", "")
  if plain == "" then
    return nil
  end
  if plain:match("^%d+$") then
    return tonumber(plain)
  end
  -- Each unit by its own letter, in the order gold, silver, copper, each at most once.
  local total, seen, rest = 0, false, plain
  for _, unit in ipairs({ { "g", 10000 }, { "s", 100 }, { "c", 1 } }) do
    local amount, after = rest:match("^(%d+)" .. unit[1] .. "(.*)$")
    if amount then
      total = total + tonumber(amount) * unit[2]
      seen = true
      rest = after
    end
  end
  if not seen or rest ~= "" then
    return nil
  end
  return total
end

-- Brief K24b (H): the words for one pretend value: money for price, money and (brief K24d)
-- disenchant ("1s 60c"), the number for level, "off" while it is not set. Pure.
function Slash.DemoValueWords(kind, value)
  if value == nil then
    return "off"
  end
  local keep = ItemTree.Keep
  if kind ~= "level" and type(keep) == "table" and type(keep.MoneyWords) == "function" then
    return keep.MoneyWords(value)
  end
  return tostring(value)
end

-- Brief K24b (H): /itemtree demo price <money or off>, demo money <money or off> and demo level
-- <n or off> (brief K24d: and demo disenchant <money or off>, every disenchant material's price
-- each): session only pretend values for the Keep tags (Core/Keep.lua Keep.SetDemo), each
-- dropping the Keep cache as it changes and touching no saved data. Bare prints the value. Answers
-- the value now set, false for off, or nil for words it could not read.
function Slash.DemoKeep(kind, rest)
  local keep = ItemTree.Keep
  if type(keep) ~= "table" or type(keep.SetDemo) ~= "function" then
    return nil
  end
  local field = keep.DEMO_KINDS and keep.DEMO_KINDS[kind] or nil
  local word = type(rest) == "string" and rest:lower():match("^%s*(.-)%s*$") or ""
  if word == "" then
    Slash.Print(string.format("Demo %s: %s", kind, Slash.DemoValueWords(kind, field and keep[field] or nil)))
    return field and keep[field] or false
  end
  local value = nil
  if word ~= "off" then
    if kind == "level" then
      value = tonumber(word)
      if value and (value < 1 or value ~= math.floor(value)) then
        value = nil
      end
    else
      value = Slash.ParseMoney(word)
    end
    if value == nil then
      local what = kind == "level" and "n" or "money"
      Slash.Print(string.format(L["Usage: %s demo %s <%s or off>"], Slash.COMMAND, kind, what))
      return nil
    end
  end
  keep.SetDemo(kind, value)
  -- Brief BQ13: the public demo view follows (Core/Demo.lua).
  local demo = Slash.DemoModule()
  if demo and type(demo.Publish) == "function" then
    pcall(demo.Publish)
  end
  -- Brief BQ30: a level that turns a spec off says so (Survival below 30).
  local note = ""
  if kind == "level" then
    note = Slash.SpecNote(demo and demo.state and demo.state.specs or nil)
  end
  Slash.Print(string.format("Demo %s: %s", kind, Slash.DemoValueWords(kind, value)) .. note)
  return value or false
end

-- Brief BQ30 (owner's spot fix, QA item 91): " (Survival is off below level 30)" where a spec named
-- (keys; nil for every spec of the class) is off at the player's level as the scores read it
-- (Gear.Player: the pretend class and level while set), else "". Never raises.
function Slash.SpecNote(specs)
  local gear, demo = ItemTree.Gear, ItemTree.Demo
  if type(gear) ~= "table" or type(gear.Player) ~= "function" then
    return ""
  end
  if type(demo) ~= "table" or type(demo.SpecNote) ~= "function" then
    return ""
  end
  local okPlayer, classId, level = pcall(gear.Player)
  if not okPlayer then
    return ""
  end
  local okNote, note = pcall(demo.SpecNote, classId, specs, level)
  if okNote and type(note) == "string" and note ~= "" then
    return " (" .. note .. ")"
  end
  return ""
end

--------------------------------------------------------------------------------
-- Brief BQ13: the demo state's commands (Core/Demo.lua owns the state, the parsing and the
-- scenarios; this prints). Shipped: they change nothing saved, and every tooltip says while one is
-- on. Each answers what it set, false for off, or nil for words it could not read.
--------------------------------------------------------------------------------

function Slash.DemoModule()
  local demo = ItemTree.Demo
  if type(demo) == "table" then
    return demo
  end
  return nil
end

local function demoMissing()
  Slash.Print("The demo state is not available")
  return nil
end

-- The player's class and its specs and labels (Core/Gear.lua), for demo spec.
local function classSpecs()
  local keep, gear = ItemTree.Keep, ItemTree.Gear
  local classId = nil
  if type(keep) == "table" and type(keep.PlayerClass) == "function" then
    local ok, id = pcall(keep.PlayerClass)
    classId = ok and tonumber(id) or nil
  end
  if type(gear) ~= "table" or type(gear.SPECS) ~= "table" then
    return classId, nil, nil
  end
  local labels = type(gear.SPEC_LABELS) == "table" and gear.SPEC_LABELS[classId or -1] or nil
  return classId, gear.SPECS[classId or -1], labels
end

-- /itemtree demo spec <spec> [spec ...] | all | off: the enabled specs of the character's class.
function Slash.DemoSpec(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local _, specs, labels = classSpecs()
  local parsed = demo.ParseSpecs(rest, specs, labels)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetSpecs(nil)
  elseif parsed.kind == "set" then
    demo.SetSpecs(parsed.specs)
  end
  local now = demo.state.specs
  Slash.Print("Demo specs: " .. (now and table.concat(now, ", ") or "off (your setting)") .. Slash.SpecNote(now))
  return now or false
end

-- /itemtree demo talent carefulaim <0..5 | off>.
function Slash.DemoTalent(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseTalent(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetCarefulAim(nil)
  elseif parsed.kind == "set" then
    demo.SetCarefulAim(parsed.rank)
  end
  local rank = demo.CarefulAim()
  Slash.Print("Demo Careful Aim: " .. (rank and tostring(rank) or "off (your talents)"))
  return rank or false
end

-- Brief ST5: /itemtree demo pet <family> [item id ...] | off, a pet of that family out that eats the
-- foods named (the client cannot say what a pretend pet eats).
function Slash.DemoPet(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParsePet(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetPet(nil)
  elseif parsed.kind == "set" then
    demo.SetPet(parsed.family, parsed.eats)
  end
  local family = demo.PetFamily()
  if not family then
    Slash.Print("Demo pet: off (your own pet)")
    return false
  end
  Slash.Print(demo.ST5Lines({ pet = demo.state.pet })[1])
  return family
end

-- Brief BQ29 (QA item 86): /itemtree demo wellfed on | off | unknown | clear, the pretend Well Fed
-- buff the buff food Use rule reads (Keep.FedState).
function Slash.DemoWellFed(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseWellFed(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "set" then
    demo.SetWellFed(parsed.value)
  end
  Slash.Print("Demo well fed: " .. demo.WellFedWords(demo.WellFed()))
  return demo.WellFed() ~= nil
end

-- Brief RB1c (the owner's ruling "A" of 2026-10-17): /itemtree demo naxx on | off | clear, the pretend
-- answer to "has this character been inside Naxxramas" (Core/QuestFlags.lua GateOpen), so the gated
-- quests can be seen keeping and folding without entering the raid.
function Slash.DemoGates(rest)
  local demo = Slash.DemoModule()
  if not demo or type(demo.ParseGates) ~= "function" then
    return demoMissing()
  end
  local parsed = demo.ParseGates(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "set" then
    demo.SetGates(parsed.value)
  end
  Slash.Print("Demo naxx: " .. demo.GatesWords(demo.GatesOpen()))
  return demo.GatesOpen() ~= nil
end

-- Brief DM1 (QA item 134): /itemtree demo at <uiMap id | zone name> <x> <y> | off, where the player
-- pretends to stand for "Show nearest" and the Map tab's player marker only (Core/Demo.lua). The
-- character never moves; memory only; demo off and a /reload end it.
function Slash.DemoAt(rest)
  local demo = Slash.DemoModule()
  if not demo or type(demo.ParseAt) ~= "function" then
    return demoMissing()
  end
  local parsed = demo.ParseAt(rest, demo.ZoneMap)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetAt(nil)
  elseif parsed.kind == "set" then
    demo.SetAt(parsed.at)
  end
  Slash.Print(demo.AtWords(demo.At(), demo.MapName))
  return demo.At() ~= nil
end

-- Brief ST5: /itemtree demo bags <n,n,n,n[,reagent n or skinning n ...]> | off, the pretend equipped
-- bags, every general bag full and the reagent or profession bag empty (Jettison's loot card reads it).
function Slash.DemoBags(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseBags(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetBags(nil)
  elseif parsed.kind == "set" then
    demo.SetBags(parsed.bags)
  end
  local bags = demo.Bags()
  if not bags then
    Slash.Print("Demo bags: off (your own bags)")
    return false
  end
  Slash.Print(demo.ST5Lines({ bags = bags })[1])
  return true
end

-- Brief BG1 (QA item 83): /itemtree demo bank <n,n,...> | off, the pretend bank's bought bag slots
-- (0 for an empty one, #itemId the bag in it), for the spare bag rule's bank read.
function Slash.DemoBank(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseBank(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetBank(nil)
  elseif parsed.kind == "set" then
    demo.SetBank(parsed.bank)
  end
  local bank = demo.Bank()
  if not bank then
    Slash.Print("Demo bank: off (your bank as last seen)")
    return false
  end
  Slash.Print(demo.ST5Lines({ bank = bank })[1])
  return true
end

-- Brief ST4 (bin B): /itemtree demo health <n | off> and /itemtree demo mana <n | off>, the most
-- health and mana the consumable rules read.
function Slash.DemoPool(pool, rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParsePool(pool, rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetPool(pool, nil)
  elseif parsed.kind == "set" then
    demo.SetPool(pool, parsed.value)
  end
  local value = demo.state[pool]
  Slash.Print(string.format("Demo %s: %s", pool, value and tostring(value) or "off (your own)"))
  return value or false
end

-- Brief BQ14 follow up: /itemtree demo class <class> [spec] | off. The spec, where given, is read
-- against the pretend class's specs (Core/Gear.lua) and pretended with it.
function Slash.DemoClass(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseClass(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetClass(nil)
  elseif parsed.kind == "set" then
    local specs = nil
    if parsed.spec then
      local gear = ItemTree.Gear
      local keys = type(gear) == "table" and type(gear.SPECS) == "table" and gear.SPECS[parsed.classId] or nil
      local labels = {}
      for _, key in ipairs(keys or {}) do
        labels[key] = type(gear.SpecLabel) == "function" and gear.SpecLabel(parsed.classId, key) or key
      end
      local read = demo.ParseSpecs(parsed.spec, keys, labels)
      if read.kind ~= "set" then
        Slash.Print(read.message or "Unknown spec")
        return nil
      end
      specs = read.specs
    end
    demo.SetClass(parsed.classId, specs)
  end
  local classId = demo.ClassId()
  Slash.Print("Demo class: " .. (classId and demo.NameOf(demo.CLASSES, classId) or "off (your own)"))
  return classId or false
end

-- /itemtree demo faction <alliance | horde> | off.
function Slash.DemoFaction(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseFaction(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetFaction(nil)
  elseif parsed.kind == "set" then
    demo.SetFaction(parsed.faction)
  end
  Slash.Print("Demo faction: " .. (demo.FactionWord() or "off (your own)"))
  return demo.Faction() or false
end

-- /itemtree demo race <race> | off. Nothing ItemTree decides reads the race today; it is pretended
-- and published (ItemTreeAPI.demo.race) for the rules that will.
function Slash.DemoRace(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseRace(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetRace(nil)
  elseif parsed.kind == "set" then
    demo.SetRace(parsed.race)
  end
  local race = demo.Race()
  Slash.Print("Demo race: " .. (race and demo.NameOf(demo.RACES, race) or "off (your own)"))
  return race or false
end

-- Brief BQ14 follow up: /itemtree demo worn <slot> <item id | off> | off. While any slot is pretended
-- the pretend set is the whole worn set the gear rules compare against (Core/Gear.lua Gear.DemoWorn).
function Slash.DemoWorn(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseWorn(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "off" then
    demo.SetWorn(nil)
  elseif parsed.kind == "set" then
    demo.SetWorn(parsed.slot, parsed.itemId, parsed.link)
  end
  local worn = demo.Worn()
  if not worn then
    Slash.Print("Demo worn: off (your own gear)")
    return false
  end
  local parts = {}
  local links = type(demo.WornLinks) == "function" and demo.WornLinks() or nil
  for slot, id in pairs(worn) do
    local suffix = type(links) == "table" and links[slot] and tostring(links[slot]):match(":(%d+)$") or nil
    parts[#parts + 1] = string.format("slot %d %s", slot, demo.ItemName(id))
      .. (suffix and string.format(" (suffix %s)", suffix) or "")
  end
  table.sort(parts)
  Slash.Print("Demo worn: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing"))
  return true
end

-- /itemtree demo quest <id> log <have>/<need> | <id> done | <id> off | none | off.
function Slash.DemoQuest(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseQuest(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "show" then
    Slash.PrintLines(demo.ShowLines())
    return demo.On()
  end
  if parsed.kind == "off" then
    demo.ClearQuests()
    Slash.Print("Demo quests: off (your quest log)")
    return false
  end
  if parsed.kind == "none" then
    demo.SetQuestsNone(true)
    Slash.Print("Demo quests: none done, none abandoned")
    return true
  end
  demo.SetQuest(parsed.questId, parsed.quest)
  Slash.Print(string.format("Demo quest %s: %s", demo.QuestName(parsed.questId), demo.QuestWords(parsed.quest)))
  return parsed.quest
end

-- /itemtree demo have <itemId> <count> | <itemId> off | off.
function Slash.DemoHave(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseHave(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "show" then
    Slash.PrintLines(demo.ShowLines())
    return demo.On()
  end
  if parsed.kind == "off" then
    demo.ClearHave()
    Slash.Print("Demo have: off (your bags)")
    return false
  end
  demo.SetHave(parsed.itemId, parsed.count)
  local count = demo.Have(parsed.itemId)
  Slash.Print(string.format("Demo have %s: %s", demo.ItemName(parsed.itemId), count and tostring(count) or "off"))
  return count or false
end

-- /itemtree demo scenario [<name> ...]: bare lists them; names apply on a clean slate.
function Slash.DemoScenario(rest)
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  local parsed = demo.ParseScenario(rest)
  if parsed.kind == "error" then
    Slash.Print(parsed.message)
    return nil
  end
  if parsed.kind == "list" then
    local lines = {}
    for _, name in ipairs(demo.ScenarioNames()) do
      local scenario = demo.SCENARIOS[name]
      lines[#lines + 1] = string.format("%s (%s): %s", name, scenario.step, scenario.text)
    end
    lines[#lines + 1] = "Building blocks: level<N>, noprofessions, noquests"
    Slash.PrintLines(lines)
    return false
  end
  demo.ApplyScenario(parsed)
  Slash.PrintLines(demo.ShowLines())
  return true
end

-- /itemtree demo show.
function Slash.DemoShow()
  local demo = Slash.DemoModule()
  if not demo then
    return demoMissing()
  end
  Slash.PrintLines(demo.ShowLines())
  return demo.On()
end

-- /itemtree demo off: everything back, the developer's bag looks too where they are on.
function Slash.DemoOff()
  local demo = Slash.DemoModule()
  if demo then
    demo.Off()
  else
    local keep = ItemTree.Keep
    if type(keep) == "table" and type(keep.SetDemo) == "function" then
      for _, kind in ipairs({ "price", "money", "level", "disenchant" }) do
        keep.SetDemo(kind, nil)
      end
    end
    local skills = ItemTree.UI and ItemTree.UI.PlayerSkills
    if type(skills) == "table" and type(skills.SetDemo) == "function" then
      skills.SetDemo(nil)
      if type(skills.ApplyDemo) == "function" then
        pcall(skills.ApplyDemo)
      end
    end
  end
  local overlay = ItemTree.UI and ItemTree.UI.Overlay
  if type(overlay) == "table" and type(overlay.demo) == "table" and type(overlay.DemoCommand) == "function" then
    pcall(overlay.DemoCommand, "off")
  end
  Slash.Print("Demo: off, everything is your own character")
  return false
end

-- The demo state's own usage, printed for a word no demo command knows.
function Slash.DemoUsageLines()
  return {
    Slash.COMMAND .. " demo level <n or off>",
    Slash.COMMAND .. " demo professions <name rank ...>, none, sample, random, off",
    Slash.COMMAND .. " demo spec <spec ...>, all, off",
    Slash.COMMAND .. " demo talent carefulaim <0 to 5 or off>",
    Slash.COMMAND .. " demo health <n or off>, demo mana <n or off>",
    Slash.COMMAND .. " demo pet <family> [item id ...], off",
    Slash.COMMAND .. " demo bags <n,n,n,n[,reagent n or skinning n ...]>, off",
    Slash.COMMAND .. " demo bank <n,n,...> (bought bank bag slots, 0 empty, #itemId), off",
    Slash.COMMAND .. " demo wellfed on, off, unknown, clear",
    Slash.COMMAND .. " demo at <uiMap id or zone name> <x> <y>, off",
    Slash.COMMAND .. " demo naxx on, off, clear",
    Slash.COMMAND .. " demo class <class> [spec], off",
    Slash.COMMAND .. " demo faction <alliance or horde>, off",
    Slash.COMMAND .. " demo race <race>, off",
    Slash.COMMAND .. " demo worn <slot> <item id, id:suffix or link>, off",
    Slash.COMMAND .. " demo quest <id> log <have>/<need>, <id> done, <id> off, none, off",
    Slash.COMMAND .. " demo have <item id> <count>, <item id> off, off",
    Slash.COMMAND .. " demo scenario <name ...> (bare lists them)",
    Slash.COMMAND .. " demo show, demo off",
  }
end

-- /itemtree demo: the demo state's words here; anything else is the developer's demos (the bag
-- looks, error, share) in a development build, else the usage.
function Slash.Demo(rest)
  local word, tail = Slash.Parse(rest)
  if word == "professions" or word == "profession" then
    return Slash.DemoProfessions(tail)
  end
  -- Brief K24b (H): the Keep tags' pretend price, money and level. Brief K24d: and what every
  -- disenchant material is worth each.
  if word == "price" or word == "money" or word == "level" or word == "disenchant" then
    return Slash.DemoKeep(word, tail)
  end
  if word == "spec" or word == "specs" then
    return Slash.DemoSpec(tail)
  end
  if word == "talent" or word == "talents" then
    return Slash.DemoTalent(tail)
  end
  if word == "class" then
    return Slash.DemoClass(tail)
  end
  if word == "health" or word == "mana" then
    return Slash.DemoPool(word, tail)
  end
  if word == "pet" then
    return Slash.DemoPet(tail)
  end
  if word == "bags" then
    return Slash.DemoBags(tail)
  end
  if word == "bank" then
    return Slash.DemoBank(tail)
  end
  if word == "wellfed" then
    return Slash.DemoWellFed(tail)
  end
  if word == "at" then
    return Slash.DemoAt(tail)
  end
  if word == "naxx" or word == "naxxramas" or word == "gates" then
    return Slash.DemoGates(tail)
  end
  if word == "faction" or word == "side" then
    return Slash.DemoFaction(tail)
  end
  if word == "race" then
    return Slash.DemoRace(tail)
  end
  if word == "worn" then
    return Slash.DemoWorn(tail)
  end
  if word == "quest" or word == "quests" then
    return Slash.DemoQuest(tail)
  end
  if word == "have" then
    return Slash.DemoHave(tail)
  end
  if word == "scenario" or word == "scenarios" then
    return Slash.DemoScenario(tail)
  end
  if word == "show" then
    return Slash.DemoShow()
  end
  if word == "off" then
    return Slash.DemoOff()
  end
  if type(Slash.DemoDev) == "function" then
    return Slash.DemoDev(rest)
  end
  Slash.PrintLines(Slash.DemoUsageLines())
  return nil
end


function Slash.Handle(msg)
  local command, rest = Slash.Parse(msg)
  if command == "" then
    -- Brief SL1 (item 244): the bare command opens the window, the minimap button's left click
    -- (Slash.OpenDefault, through Slash.Show's no item open). A typed command never closes the
    -- window, so one already up stays as it is; the settings are /itemtree options or settings.
    Slash.Show("")
  elseif command == "random" then
    Slash.ShowRandom()
  elseif command == "debug" then
    Slash.PrintLines(Slash.DebugLines())
  elseif command == "report" then
    Slash.Report()
  elseif command == "trace" then
    Slash.Trace()
  elseif command == "show" then
    Slash.Show(rest)
  elseif command == "options" or command == "config" or command == "settings" then
    local options = ItemTree.Options
    if not (options and type(options.Open) == "function" and options.Open()) then
      Slash.Print(L["Settings panel is not available on this client"])
    end
  elseif command == "reset" then
    if Slash.ResetWindow() then
      Slash.Print(L["Window position reset"])
    end
  elseif command == "hud" then
    Slash.Hud(rest)
  elseif command == "cpu" then
    Slash.Cpu(rest)
  elseif command == "ledger" then
    Slash.PrintLines(Slash.LedgerLines(rest))
  elseif command == "demo" then
    Slash.Demo(rest)
  else
    Slash.PrintLines(Slash.UsageLines())
  end
end

-- Runs fn on the next tick (C_Timer.After(0)), out of whatever client path called us, or straight
-- away on a client with no C_Timer. Answers whether it was booked, which is what the specs read.
function Slash.Defer(fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    if pcall(timer.After, 0, fn) then
      return true
    end
  end
  fn()
  return false
end

-- What the registered command runs: Slash.Handle, booked for the next tick so nothing it opens or
-- focuses runs inside the chat edit box's send path (see the taint note at the top).
function Slash.Run(msg)
  return Slash.Defer(function()
    Slash.Handle(msg)
  end)
end

function Slash.Install()
  local list = rawget(_G, "SlashCmdList")
  if type(list) ~= "table" then
    return false
  end
  _G.SLASH_ITEMTREE1 = Slash.COMMAND
  _G.SLASH_ITEMTREE2 = Slash.SHORT
  list["ITEMTREE"] = function(msg)
    Slash.Run(msg)
  end
  return true
end

Slash.Install()

-- The addon compartment entry named by "## AddonCompartmentFunc" in ItemTree.toc. Clients
-- without a compartment never call it, and defining it costs nothing. It opens the settings
-- (Slash.Default) whichever mouse button chose it: the client hands over the addon's name and the
-- button (Blizzard_Minimap/Mainline/AddonCompartment.lua:99 and :103, branch forever) and neither
-- is read. Brief SL1 left it as it was when the bare command moved to the window.
function _G.ItemTree_OnAddonCompartmentClick()
  Slash.Defer(function()
    Slash.Default()
  end)
end

return Slash
