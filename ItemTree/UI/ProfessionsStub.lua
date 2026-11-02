-- The Professions tab's stub in the core addon (brief PR3).
--
-- The tab itself, its model and its data live in the load on demand folder ItemTree_Professions.
-- This file is all the core carries for it:
--   * the setting, showProfessions, on by default (brief PT32), under Feature tabs (Options.RegisterSetting,
--     at file load and again at ADDON_LOADED, the way UI/BossLoot.lua registers its own);
--   * the tab, "Professions", registered with the window before it is built (Frame.RegisterTab),
--     hidden while the setting is off and shown live by Frame.SyncTabs when it is turned on;
--   * a pane object the window hosts, which forwards Attach, Show, Refresh and Hide to the loaded
--     module's pane, loading the folder on the first Show and drawing one plain line in the
--     region when the folder cannot be loaded;
--   * the loads themselves: at PLAYER_LOGIN when the setting is on, and at once when the player
--     turns it on (the ITEMTREE_SETTING_CHANGED callback UI/Options.lua fires after every
--     setting change). Turning it off hides the tab; the module stays loaded until /reload.
--
-- A player who turns the setting off pays nothing: no folder loaded, no module code, and no
-- client event registered once PLAYER_LOGIN has been seen.
--
-- ProfessionsStub.Active() is true only while the setting is on AND the module is loaded. Later
-- briefs (the Keep rule, the bag icon) ask it, never the module's presence alone.
--
-- The functions above the divider are pure and run under busted with no WoW API.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Theme = ItemTree.Theme
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local ProfessionsStub = {}

ProfessionsStub.FOLDER = "ItemTree_Professions"
ProfessionsStub.TAB_NAME = "Professions"
ProfessionsStub.REGION = "professions"
ProfessionsStub.SETTING = "showProfessions"
-- No tab glyph of its own yet: the blacksmithing hammer the tree's category rows already draw.
ProfessionsStub.TAB_ICON = "CAT_BLACKSMITHING"
ProfessionsStub.TAB_WORD = L["Professions"]

-- The words the stub and the module folder draw. The folder's own placeholder line is kept here
-- because tests/spec/locale_spec.lua reads only Core, UI and Providers for locale literals, and the
-- folder's UI/Pane.lua reads it from this table.
ProfessionsStub.WORDS = {
  failed = L["The Professions tab needs the ItemTree_Professions folder. Install it beside ItemTree and enable it."],
  placeholder = L["Your profession routes will show here."],
}

-- The window finds a hosted pane by its tab's name, so the stub is filed under that name, and
-- under ProfessionsStub for a reader.
ItemTree.UI[ProfessionsStub.TAB_NAME] = ProfessionsStub
ItemTree.UI.ProfessionsStub = ProfessionsStub

ProfessionsStub.TAB_SPEC = {
  region = ProfessionsStub.REGION,
  icon = ProfessionsStub.TAB_ICON,
  setting = ProfessionsStub.SETTING,
  -- A browser of its own, like Boss loot: no breadcrumb trail, no diff row, no view row.
  headerRows = { crumbs = false, diffRow = false, viewRow = false },
  -- It draws nothing about the root, so opening an item from it moves to the Tree tab.
  showsRoot = false,
  -- Tree, Chain, Boss loot, Professions, Discoveries.
  before = "Discoveries",
}

-- The setting's hover text: what the player gets, in plain words.
-- Brief PT32: the second sentence says it is on by default and what turning it off does.
local SETTING_WHAT =
  L["Adds a Professions tab that shows your professions' levelling routes and keeps the reagents you still need."]
local SETTING_DEFAULT = L["On by default. Turn it off to hide the tab and stop keeping reagents for your routes."]
ProfessionsStub.SETTING_TOOLTIP = SETTING_WHAT .. " " .. SETTING_DEFAULT

ProfessionsStub.SETTING_ENTRY = {
  key = ProfessionsStub.SETTING,
  label = L["Professions tab"],
  section = L["Feature tabs"],
  kind = "boolean",
  -- Brief PT32: on by default, the same as DB_DEFAULTS.settings.showProfessions in Core/Init.lua.
  default = true,
  tooltip = ProfessionsStub.SETTING_TOOLTIP,
}

-- Brief PR6: the profession icon on bag items the route still needs (UI/Overlay.lua), two rows
-- in the Bags section straight after the badge size and corner. They are greyed out while the
-- tab's setting is off (dependsOn, UI/Options.lua Options.DependsMet), because the icon only ever
-- shows with the tab on. The size is the badges' own (bagBadgeScale). Registered here, in the
-- core, so they exist before the panel is built whether or not the folder ever loads.
ProfessionsStub.BADGE_SETTING = "professionBadge"
ProfessionsStub.BADGE_CORNER_SETTING = "professionBadgeCorner"
-- Brief ST2 (QA item 307): the Bags section joined Badges as New and Changed badges
-- (UI/Options.lua Options.BADGES_SECTION); the two rows stay after the bag rows, sized with them.
-- Brief ST3 (QA item 316): the heading reads Forever badges now.
ProfessionsStub.BAG_SECTION = "Forever badges"

-- The two rows' hover text: what the player gets, in plain words.
ProfessionsStub.BADGE_TOOLTIP = L["Shows the profession's icon on items your profession route still needs."]
ProfessionsStub.BADGE_CORNER_TOOLTIP =
  L["Which corner of a bag or bank slot the profession icon sits in. A badge in that corner moves it to the next."]

ProfessionsStub.BADGE_ENTRIES = {
  {
    key = ProfessionsStub.BADGE_SETTING,
    label = L["Profession icon on route items"],
    section = ProfessionsStub.BAG_SECTION,
    kind = "boolean",
    default = true,
    tooltip = ProfessionsStub.BADGE_TOOLTIP,
    dependsOn = { ProfessionsStub.SETTING },
  },
  {
    key = ProfessionsStub.BADGE_CORNER_SETTING,
    label = L["Profession icon corner"],
    section = ProfessionsStub.BAG_SECTION,
    kind = "dropdown",
    optionSource = "badgeCorner",
    -- Brief PR20: bottom left, clear of the stack count (UI/Overlay.lua PROFESSION_CORNER_DEFAULT).
    default = "BOTTOMLEFT",
    tooltip = ProfessionsStub.BADGE_CORNER_TOOLTIP,
    dependsOn = { ProfessionsStub.SETTING },
  },
}

-- Where the two rows sit inside Bags: after the badge rows (W27's Changed row included) and before
-- the Keep marks row, which keeps its place after the listed keys (UI/Options.lua
-- Options.GroupBySection). Only written where the panel has no order of its own for the section.
-- Brief ST2: the section opens on the window's badge and quest rows now, so they are listed first.
-- Brief ST3 (QA item 317): the kinds, then the places, UI/Options.lua's own order: Show Changed
-- badges on bags moved up under Show Changed badges.
ProfessionsStub.BAG_ORDER = {
  "badgesNew",
  "badgesChanged",
  "includeMinorChanges",
  "bagBadgesChanged",
  "questBadges",
  "questWash",
  "bagOverlay",
  "bankOverlay",
  "bagBadgeScale",
  "bagBadgeCorner",
  ProfessionsStub.BADGE_SETTING,
  ProfessionsStub.BADGE_CORNER_SETTING,
}

-- Text inset inside the region.
ProfessionsStub.PAD = (Theme and Theme.sizes and Theme.sizes.ITEMTREE_SPACE_2) or 8
ProfessionsStub.FONT_SIZE = (Theme and Theme.sizes and Theme.sizes.ITEMTREE_FONTSIZE_BODY_MD) or 12
ProfessionsStub.FONT_TEMPLATE = "GameFontNormalSmall"
ProfessionsStub.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }
ProfessionsStub.TEXT_COLOUR = "ITEMTREE_COLOR_TEXT_MUTED"

--- Whether the setting is on in these saved settings, with the default applied to a key that is
--- not there (brief PT32: on, Core/Init.lua DB_DEFAULTS, else this file's entry). Only a boolean
--- true reads as on once a value is saved. Pure.
function ProfessionsStub.SettingOn(settings)
  local value = nil
  if type(settings) == "table" then
    value = settings[ProfessionsStub.SETTING]
  end
  if value == nil then
    local defaults = ItemTree.DB_DEFAULTS and ItemTree.DB_DEFAULTS.settings
    if type(defaults) == "table" then
      value = defaults[ProfessionsStub.SETTING]
    end
  end
  if value == nil then
    value = ProfessionsStub.SETTING_ENTRY.default
  end
  return value == true
end

local function currentSettings()
  local db = ItemTree.db
  return type(db) == "table" and db.settings or nil
end

local function modules()
  local found = ItemTree.Modules
  if type(found) == "table" then
    return found
  end
  return nil
end

--- Whether the module folder has loaded and announced itself.
function ProfessionsStub.Loaded()
  local found = modules()
  if not found or type(found.Loaded) ~= "function" then
    return false
  end
  return found.Loaded(ProfessionsStub.FOLDER) == true
end

--- True only while the setting is on and the module is loaded. What the Keep rule and the bag
--- icon ask (later briefs).
function ProfessionsStub.Active()
  return ProfessionsStub.SettingOn(currentSettings()) and ProfessionsStub.Loaded()
end

--- Loads the module folder (once per session, through Core/Modules.lua). Answers whether it is
--- loaded.
function ProfessionsStub.Load()
  local found = modules()
  if not found or type(found.Load) ~= "function" then
    return false
  end
  local ok, loaded = pcall(found.Load, ProfessionsStub.FOLDER)
  return ok and loaded == true
end

--- The table the module announced, or nil.
function ProfessionsStub.Module()
  local found = modules()
  if not found or type(found.Get) ~= "function" then
    return nil
  end
  local api = found.Get(ProfessionsStub.FOLDER)
  if type(api) == "table" then
    return api
  end
  return nil
end

--- The loaded module's pane, or nil.
function ProfessionsStub.ModulePane()
  local api = ProfessionsStub.Module()
  local pane = api and api.pane
  if type(pane) == "table" and type(pane.Show) == "function" then
    return pane
  end
  return nil
end

--- What a changed setting does here: turning showProfessions on loads the folder now, without a
--- reload. Anything else, off included, changes nothing. Answers whether a load was asked for.
function ProfessionsStub.OnSettingChanged(key, value)
  if key ~= ProfessionsStub.SETTING or value ~= true then
    return false
  end
  ProfessionsStub.Load()
  return true
end

--- The login check: loads the folder when the setting is on, so later briefs have the data before
--- the window opens. Answers whether a load was asked for.
function ProfessionsStub.OnLogin()
  if not ProfessionsStub.SettingOn(currentSettings()) then
    return false
  end
  ProfessionsStub.Load()
  return true
end

--- Brief PR18: the "Create next in the ItemTree queue" key (Bindings.xml ITEMTREE_CRAFTNEXT runs
--- ItemTree_CraftQueueNext). Does nothing unless the Professions tab is on and its folder loaded;
--- then one press of the craft queue (ItemTree_Professions/UI/Queue.lua Queue.Binding), inside the
--- key press. Answers whether the queue was pressed.
function ProfessionsStub.CraftNext()
  if not ProfessionsStub.Active() then
    return false
  end
  local api = ProfessionsStub.Module()
  local queue = api and api.queue
  if type(queue) ~= "table" or type(queue.Binding) ~= "function" then
    return false
  end
  return (pcall(queue.Binding))
end

local function frameModule()
  local frame = ItemTree.UI and ItemTree.UI.Frame
  if type(frame) == "table" then
    return frame
  end
  return nil
end

--- Registers the setting with the panel and the tab with the window. Both are idempotent; the
--- setting is registered once the panel's module has loaded (it loads after this file, so
--- ADDON_LOADED asks again), and the folder's failure line with the loader. Answers whether the
--- tab is registered.
function ProfessionsStub.Register()
  local found = modules()
  if found and type(found.Describe) == "function" then
    pcall(found.Describe, ProfessionsStub.FOLDER, ProfessionsStub.WORDS.failed)
  end
  local Options = ItemTree.Options
  if type(Options) == "table" and type(Options.RegisterSetting) == "function" then
    pcall(Options.RegisterSetting, ProfessionsStub.SETTING_ENTRY)
    for _, entry in ipairs(ProfessionsStub.BADGE_ENTRIES) do
      pcall(Options.RegisterSetting, entry)
    end
    local order = Options.SECTION_KEY_ORDER
    if type(order) == "table" and order[ProfessionsStub.BAG_SECTION] == nil then
      order[ProfessionsStub.BAG_SECTION] = ProfessionsStub.BAG_ORDER
    end
  end
  local frame = frameModule()
  if not frame or type(frame.RegisterTab) ~= "function" then
    return false
  end
  local ok, done = pcall(frame.RegisterTab, ProfessionsStub.TAB_NAME, ProfessionsStub.TAB_SPEC)
  return ok and done == true
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local function newFrame(kind)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- Font safety, the same shape as UI/Sidebar.lua and UI/BossLoot.lua: a FontString with no font
-- raises "Font not set" on SetText, and SetFont answers false rather than raising when the face
-- will not load, so the answer is read and a client font object put on before any SetText.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(ProfessionsStub.FONT_FALLBACKS) do
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

local function styleText(fontString)
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, ProfessionsStub.FONT_SIZE, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local colour = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(ProfessionsStub.TEXT_COLOUR)
  if type(colour) == "table" and type(fontString.SetTextColor) == "function" then
    pcall(fontString.SetTextColor, fontString, colour.r, colour.g, colour.b, colour.a or 1)
  end
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, "LEFT")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, true)
  end
  return fontString
end

local function newFontString(parent)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", ProfessionsStub.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  styleText(fontString)
  local pad = ProfessionsStub.PAD
  if type(fontString.SetPoint) == "function" then
    pcall(fontString.SetPoint, fontString, "TOPLEFT", parent, "TOPLEFT", pad, -pad)
    pcall(fontString.SetPoint, fontString, "TOPRIGHT", parent, "TOPRIGHT", -pad, -pad)
  end
  return fontString
end

local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local function setShown(object, shown)
  if type(object) ~= "table" then
    return false
  end
  local method = shown and object.Show or object.Hide
  if type(method) ~= "function" then
    return false
  end
  return (pcall(method, object))
end

--- Draws one plain line of text at the top of a region, font safe, and shows it. Hand back the
--- FontString a previous call answered to reuse it. Answers the FontString, or nil where nothing
--- could be drawn. The module folder's placeholder pane draws through this too.
function ProfessionsStub.DrawMessage(region, text, fontString)
  if type(fontString) ~= "table" then
    fontString = newFontString(region)
  end
  if not fontString then
    return nil
  end
  if not setText(fontString, text) then
    return fontString
  end
  setShown(fontString, true)
  return fontString
end

--- Hides a line DrawMessage drew. Safe on nil.
function ProfessionsStub.HideMessage(fontString)
  return setShown(fontString, false)
end

-- The pane contract with UI/Frame.lua: Attach(region) once, Show() whenever the tab is selected
-- (handed the root key, passed through), Refresh(), Hide(). Each forwards to the module's pane
-- once the folder has loaded.

function ProfessionsStub.Attach(region)
  ProfessionsStub.region = region
  return true
end

-- Brief PM1 (brief G1 reaching the Professions code): the module's pane runs under the window's
-- boundary (Frame.Guarded, the way UI/BossLoot.lua's draws do) rather than in a pcall that would
-- hide its fault: a draw that raises leaves the empty page, hands the error to the client's
-- handler once, and keeps the window usable. Inside a draw the window started (Frame.SelectTab,
-- itself guarded) the call runs straight. Where there is no window module, a pcall as before.
local function forward(method, ...)
  local pane = ProfessionsStub.ModulePane()
  if not pane or type(pane[method]) ~= "function" then
    return false, false
  end
  local frame = frameModule()
  if frame and type(frame.Guarded) == "function" then
    local answer = frame.Guarded("Professions." .. method, pane[method], ...)
    return true, answer ~= false
  end
  local ok, answer = pcall(pane[method], ...)
  return true, ok and answer ~= false
end

--- Shows the tab: loads the folder on the first call, then hands the module's pane the region
--- (once) and shows it. Where the folder cannot be loaded, the plain failure line is drawn in the
--- region instead. Answers whether the module's pane drew.
function ProfessionsStub.Show(rootKey)
  local pane = ProfessionsStub.ModulePane()
  if not pane then
    ProfessionsStub.Load()
    pane = ProfessionsStub.ModulePane()
  end
  if not pane then
    ProfessionsStub.message =
      ProfessionsStub.DrawMessage(ProfessionsStub.region, ProfessionsStub.WORDS.failed, ProfessionsStub.message)
    return false
  end
  ProfessionsStub.HideMessage(ProfessionsStub.message)
  if not ProfessionsStub.paneAttached and type(pane.Attach) == "function" then
    -- Flagged before the call, so a pane that raises is not attached again on every show.
    ProfessionsStub.paneAttached = true
    pcall(pane.Attach, ProfessionsStub.region)
  end
  local _, drawn = forward("Show", rootKey)
  return drawn
end

function ProfessionsStub.Refresh()
  local _, drawn = forward("Refresh")
  return drawn
end

function ProfessionsStub.Hide()
  ProfessionsStub.HideMessage(ProfessionsStub.message)
  local _, done = forward("Hide")
  return done
end

function ProfessionsStub.Init() end

-- The tab is registered as the file loads, which is before the window is built. The settings
-- panel's module loads after this file, so the setting is registered again at ADDON_LOADED. The
-- default (off) is not written into the saved settings: the window reads an unset tab setting as
-- the default registered here (Frame.TabSettingOn).
ProfessionsStub.Register()

-- Turning the setting on loads the folder at once. UI/Options.lua fires ITEMTREE_SETTING_CHANGED
-- through ItemTree's CallbackHandler after every setting change (Options.OnChanged); this is an
-- addon callback, not a client event. The handler is (event, key, value).
if type(ItemTree.RegisterCallback) == "function" then
  pcall(ItemTree.RegisterCallback, ProfessionsStub, "ITEMTREE_SETTING_CHANGED", function(_, key, value)
    ProfessionsStub.OnSettingChanged(key, value)
  end)
end

local events = newFrame("Frame")
if events and type(events.RegisterEvent) == "function" and type(events.SetScript) == "function" then
  pcall(events.RegisterEvent, events, "ADDON_LOADED")
  pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
  events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "ItemTree" then
      return
    end
    ProfessionsStub.Register()
    if event == "PLAYER_LOGIN" then
      ProfessionsStub.OnLogin()
      if type(self.UnregisterAllEvents) == "function" then
        pcall(self.UnregisterAllEvents, self)
      end
    end
  end)
end
ProfessionsStub.events = events

-- Brief PR18: the key binding's entry point and its row label in the Key Bindings panel, under
-- ItemTree's own heading (Bindings.xml). Here in the core, not in the load on demand folder, so the
-- label reads right before that folder loads.
function _G.ItemTree_CraftQueueNext()
  ProfessionsStub.CraftNext()
end
_G.BINDING_NAME_ITEMTREE_CRAFTNEXT = L["Create next in the ItemTree queue"]

return ProfessionsStub
