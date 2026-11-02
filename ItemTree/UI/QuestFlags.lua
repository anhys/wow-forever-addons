-- New in Forever and New reward marks on the client's quest panels and quest log (brief Q2,
-- docs/ideas/quest-new-changed.md). Core/QuestFlags.lua answers; this file reads the quest the
-- client is showing and draws the marks.
--
-- What is drawn, and where:
--
--   The title. The New badge (UI/Badges.lua, the medallion items wear), alone, at the right end
--   of the title's text column, centred on the title's first line, on the offer
--   (QuestFrameDetailPanel), the progress panel (QuestFrameProgressPanel), the turn in panel
--   (QuestFrameRewardPanel), the world map's detail pane (QuestMapFrame.DetailsFrame) and the
--   quest log popup (QuestLogPopupDetailFrame). A quest with a New reward wears the Changed badge
--   there as well, right of the New one. No words: the owner ruled on 2026-09-26 that the badge
--   says it (brief Q4).
--
--   The wash. Behind a New quest's text on the offer, the turn in panel, the popup and the map's
--   detail pane (not the progress panel, which has no description), a blue wash (the New badge's
--   silver blue) over the top of the text column that fades out quickly and smoothly towards a
--   parchment yellow (WashBands).
--   It is its own frame one level under the frame that holds the title and description font
--   strings, so the parchment (the panel's Bg, two levels further down) stays under it and the
--   text stays over it.
--
--   The reward buttons, in the offer, the turn in panel, the popup and the map's reward block. A
--   reward that is itself New in Forever wears the New badge in the icon's top right corner, the
--   corner the bag badges use. A reward the quest did not give in Classic Era wears the Changed
--   medallion there, with the words "New reward" at the button's bottom right, inside the button:
--   the client centres the item's name in the space right of the icon, so a one line name leaves
--   that strip clear, nothing outside the button is covered, and no other reward moves.
--
--   The quest log rows on the world map (QuestScrollFrame.titleFramePool). The New badge alone, at
--   the row's right end: left of the "(Elite)" tag when the row carries one, else left of the
--   storyline icon or the quest type icon when the row shows one, else left of the tracking tick
--   box (the row's Checkbox, QuestLogTitleTemplate in Mainline QuestMapFrame.xml), never over any
--   of them, so it stays clear of the Camelot level prefix at the start of the title.
--
--   The hover (brief Q7). The title's two badges are the one thing here that takes the mouse:
--   motion only, clicks passed through to whatever is under them (the title is plain text on
--   every surface, so nothing there wants the click). Hovering one shows GameTooltip anchored to
--   it with what the badge means as its one line, in the badge's colour, and for Changed, where
--   the rewards were read, a muted second line counting the changes since Classic Era. Leaving
--   hides it. The reward marks, the row badges and the wash stay mouse off: an item's own tooltip
--   already says what a reward is.
--
-- The hooks, checked against github.com/Gethe/wow-ui-source branch forever,
-- Interface/AddOns/Blizzard_UIPanels_Game (Mainline QuestInfo.lua and .xml, QuestFrame.lua and
-- .xml, QuestMapFrame.lua, and Camelot QuestMapFrameOverrides.lua):
--
--   hooksecurefunc("QuestInfo_Display"). The offer, turn in, popup and map detail panes all call it
--   by name (the panels' OnShow handlers are bound by reference in XML, so a hook on those globals
--   would never run, but they call QuestInfo_Display by name). The template argument says which
--   surface it is: QUEST_TEMPLATE_DETAIL the offer, QUEST_TEMPLATE_REWARD the turn in,
--   QUEST_TEMPLATE_LOG the popup, QUEST_TEMPLATE_MAP_DETAILS the map's title and
--   QUEST_TEMPLATE_MAP_REWARDS the map's rewards. The quest is the one QuestInfo itself reads:
--   C_QuestLog.GetSelectedQuest() when QuestInfoFrame.questLog is set, GetQuestID() otherwise.
--   The rewards are QuestInfoFrame.rewardsFrame.RewardButtons (QuestInfoRewardsFrame, or
--   MapQuestInfoRewardsFrame on the map), each button carrying .type ("reward" or "choice"),
--   .objectType ("item" or "currency") and the index it was filled from as its ID.
--
--   QuestFrameProgressPanel:HookScript("OnShow"), after HasScript. The progress panel sets
--   QuestProgressTitleText itself and never calls QuestInfo_Display.
--
--   hooksecurefunc("QuestLogQuests_Update"), which releases and rebuilds every row, then a walk of
--   the pool's ACTIVE buttons only. That walk is over frames the client already drew; each row's
--   quest id is its button.questID, and the verdict is a table lookup. No item or quest call is
--   made per row, which is also why a row wears New and never Changed: Changed needs the rewards.
--
-- The live reward ids: GetQuestItemInfo(type, index) on the quest giver's panels and
-- GetQuestLogRewardInfo(index) or GetQuestLogChoiceInfo(index) in the log, the item id their sixth
-- value, with GetQuestItemLink and GetQuestLogItemLink as the fallback. One call per reward button
-- of the one quest on screen, the same calls the client makes to fill the button. The progress
-- panel draws no rewards and so never wears Changed.
--
-- Every frame here is ItemTree's own: parented to the client's frame, mouse off (bar the title
-- badges' hover, which is scripted on those badges alone), anchored and nothing else. No client
-- frame is moved, resized or written to. Frames sit in weak tables keyed by the client's frame.
-- Combat (brief TX6). Nothing here is created, attached, anchored, shown or hidden while the
-- player is in combat: a frame under a client panel cannot be moved, shown or hidden then, and a
-- call such as SetPropagateMouseClicks on the title badge is refused outright, with the client
-- blaming ItemTree (ADDON_ACTION_BLOCKED, the owner running and opening a quest in combat,
-- 2026-10-04). Every draw asks InCombatLockdown first; in combat it books one redraw of its
-- surface for PLAYER_REGEN_ENABLED (one flag per surface, cleared when it runs) and leaves the
-- frames alone. The hooks never draw inside the client's own show chain either: each one only
-- books the draw for the next tick (QuestUI.Defer, C_Timer.After(0)), so nothing of ours is made
-- or attached while the client is still inside its ShowUIPanel. attach is the one place that
-- calls SetParent.
--
-- The setting "Show New on quests and rewards" (questBadges, on by default) hides every mark.
-- "Show the blue wash on new quests" (questWash, on by default, brief Q5) hides the wash alone and
-- leaves the badges; the wash needs both on. No saved variables and no logging.
--
-- Everything above the client side divider is pure and runs under busted with no client.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local QuestUI = {}
ItemTree.UI.QuestFlags = QuestUI

local Theme = ItemTree.Theme
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- The surfaces, by the QuestInfo template global that draws each. MAP_REWARDS draws no title:
-- its rewards decide the map title's Changed badge.
QuestUI.TEMPLATES = {
  QUEST_TEMPLATE_DETAIL = "offer",
  QUEST_TEMPLATE_REWARD = "turnin",
  QUEST_TEMPLATE_LOG = "popup",
  QUEST_TEMPLATE_MAP_DETAILS = "map",
  QUEST_TEMPLATE_MAP_REWARDS = "mapRewards",
}

-- Which title surfaces draw their rewards in the same QuestInfo_Display call.
QuestUI.REWARDS_WITH_TITLE = { offer = true, turnin = true, popup = true }

-- The badge sizes (Theme tokens through Badges.SizeFor): the title's beside title text, the row's
-- and the reward button's at the list size.
QuestUI.TITLE_BADGE = "tooltip"
QuestUI.ROW_BADGE = "list"
QuestUI.REWARD_BADGE = "list"

-- Pixels between the parts of a tag, and between a mark and the thing it sits against.
QuestUI.GAP = 3
QuestUI.INSET = 1
QuestUI.ROW_INSET = 4

-- Above the client's frame, so a mark draws over the icon and its border.
QuestUI.LEVEL_OFFSET = 5

-- A client that reports more rewards than this is answering nonsense; a Classic quest gives at
-- most four fixed and six choices.
QuestUI.MAX_REWARDS = 16

-- A setting never written reads as on.
function QuestUI.Enabled(settings)
  if type(settings) ~= "table" or settings.questBadges == nil then
    return true
  end
  return settings.questBadges and true or false
end

-- Brief Q5: the wash has its own switch, and is drawn only while the marks are on as well. A
-- wash setting never written reads as on, the same as the marks.
function QuestUI.WashEnabled(settings)
  if not QuestUI.Enabled(settings) then
    return false
  end
  if type(settings) ~= "table" or settings.questWash == nil then
    return true
  end
  return settings.questWash and true or false
end

-- The surface one QuestInfo_Display call draws, from its template and the template globals the
-- client names (name -> the table). nil for a template this file does not mark.
function QuestUI.SurfaceFor(template, globals)
  if type(template) ~= "table" or type(globals) ~= "table" then
    return nil
  end
  for name, surface in pairs(QuestUI.TEMPLATES) do
    if globals[name] == template then
      return surface
    end
  end
  return nil
end

-- The badge kinds a quest's title wears, New first.
function QuestUI.TitleKinds(isNew, isChanged)
  local kinds = {}
  if isNew then
    kinds[#kinds + 1] = "new"
  end
  if isChanged then
    kinds[#kinds + 1] = "changed"
  end
  return kinds
end

-- A reward verdict (Core/QuestFlags.lua) as the badge kind to draw and the words under it.
function QuestUI.RewardMark(verdict)
  if verdict == "new_item" then
    return "new", nil
  end
  if verdict == "new_reward" then
    return "changed", L["New reward"]
  end
  return nil, nil
end

-- How far down from the title's top a tag of this height sits so it is centred on the first line.
function QuestUI.TagOffsetY(lineHeight, tagHeight)
  lineHeight = tonumber(lineHeight) or 0
  tagHeight = tonumber(tagHeight) or 0
  if lineHeight <= tagHeight then
    return 0
  end
  return -math.floor((lineHeight - tagHeight) / 2 + 0.5)
end

-- The title's text column on each surface, from the forever branch: how far its right end sits in
-- from the right edge of the frame the title is in, and how far down that frame the title starts.
-- The offer's, turn in's and progress panel's scroll children are 300 wide (QuestDetail,
-- QuestReward and QuestProgressScrollChildFrame, Mainline QuestFrame.xml); the popup's
-- ScrollFrame.ScrollChild and the map's DetailsFrame.ScrollFrame.Contents are 298 (QuestMapFrame.xml).
-- The title sits at 10, -10 and 275 wide on the offer, 10, -10 and 285 on the turn in panel,
-- 5, -5 and 285 in the popup, 5, -10 and 289 on the map (the QUEST_TEMPLATE_* elements and
-- contentWidth in Mainline QuestInfo.lua), and 10, -10 and 285 on the progress panel
-- (QuestProgressTitleText). The measured numbers win when the client answers (TagPlacement).
QuestUI.TITLE_COLUMN = {
  offer = { right = 15, top = 10 },
  turnin = { right = 5, top = 10 },
  progress = { right = 5, top = 10 },
  popup = { right = 8, top = 5 },
  map = { right = 4, top = 10 },
}

-- Where a title tag goes: the x and y of its TOPRIGHT against the TOPRIGHT of the title's parent,
-- so its right edge is the right end of the title's text column and the badges centre on the
-- title's first line. measured holds what the client says: parentWidth, and the title's x and y
-- offsets in its parent (its TOPLEFT point) and its width. Anything missing, or a column that
-- would end past the parent's edge, falls back to TITLE_COLUMN. The map narrows its title to clear
-- its path buttons (QuestInfo_AdjustTitleWidth), which the measured width follows.
function QuestUI.TagPlacement(surface, measured, lineHeight, tagHeight)
  local column = QuestUI.TITLE_COLUMN[surface] or { right = QuestUI.ROW_INSET, top = 0 }
  local right, top = column.right, column.top
  if type(measured) == "table" then
    local parentWidth = tonumber(measured.parentWidth)
    local x, y, width = tonumber(measured.x), tonumber(measured.y), tonumber(measured.width)
    if parentWidth and x and width and parentWidth > 0 and width > 0 then
      local gap = parentWidth - (x + width)
      if gap >= 0 then
        right = gap
      end
    end
    if y and y <= 0 then
      top = -y
    end
  end
  return -right, -top + QuestUI.TagOffsetY(lineHeight, tagHeight)
end

-- The surfaces that wear the wash: the ones that draw a description under the title.
QuestUI.WASH_SURFACES = { offer = true, turnin = true, popup = true, map = true }

-- The wash's textures sit on the BACKGROUND layer at its top sublevel, in a frame one level under
-- the frame that holds the text.
QuestUI.WASH_LAYER = "BACKGROUND"
QuestUI.WASH_SUBLEVEL = 7

local function washColour(key, alpha, fallback)
  local colour = Theme and Theme.colors and Theme.colors[key] or fallback
  return { r = colour.r, g = colour.g, b = colour.b, a = alpha }
end

-- The wash, top to bottom: two stacked vertical fades, a short strong band and then a long tail,
-- which is what makes the fade quick but smooth. Each band's top and bottom colour and alpha; the
-- tail turns from the New badge's silver blue to a parchment yellow as it fades to nothing, so it
-- lands on the paper (brief Q6).
function QuestUI.WashBands()
  local blue = { r = 0.47, g = 0.72, b = 0.96 }
  local parchment = { r = 0.80, g = 0.70, b = 0.35 }
  return {
    {
      height = 36,
      top = washColour("ITEMTREE_COLOR_QUEST_WASH", 0.40, blue),
      bottom = washColour("ITEMTREE_COLOR_QUEST_WASH", 0.14, blue),
    },
    {
      height = 130,
      top = washColour("ITEMTREE_COLOR_QUEST_WASH", 0.14, blue),
      bottom = washColour("ITEMTREE_COLOR_QUEST_WASH_PARCHMENT", 0, parchment),
    },
  }
end

-- The wash's whole height, the bands stacked.
function QuestUI.WashHeight(bands)
  local total = 0
  for _, band in ipairs(bands or QuestUI.WashBands()) do
    total = total + (tonumber(band.height) or 0)
  end
  return total
end

-- Where a row's badge goes: left of the leftmost thing the client shows at the row's right end.
-- Right to left the client lays out the tracking tick box (Checkbox), the quest type icon
-- (TagTexture), the storyline icon (StorylineTexture) and the tag text, so the badge goes left of
-- the tag text when the row shows one; else left of the storyline icon; else left of the quest
-- type icon; else left of the tick box; else at the row's right inset. (QuestLogTitleTemplate in
-- Mainline QuestMapFrame.xml and QuestLogQuests_AddQuestButton in QuestMapFrame.lua, forever.)
-- Returns point, relativeTo key ("TagText", "StorylineTexture", "TagTexture", "Checkbox" or
-- "button"), relativePoint, x.
function QuestUI.RowAnchor(tagShown, tickShown, typeIconShown, storylineShown)
  if tagShown then
    return "RIGHT", "TagText", "LEFT", -QuestUI.GAP
  end
  if storylineShown then
    return "RIGHT", "StorylineTexture", "LEFT", -QuestUI.GAP
  end
  if typeIconShown then
    return "RIGHT", "TagTexture", "LEFT", -QuestUI.GAP
  end
  if tickShown then
    return "RIGHT", "Checkbox", "LEFT", -QuestUI.GAP
  end
  return "RIGHT", "button", "RIGHT", -QuestUI.ROW_INSET
end

-- The hover on a title badge (brief Q7): what the badge means, in the badge's colour, and for a
-- Changed quest whose rewards were read, a muted line counting the changes since Classic Era.
-- New and Changed name themselves with their heading ("New in Forever", "Changed in Forever");
-- Season of Discovery's heading alone says too little, so it takes its meaning line
-- (Badges.Meaning). Each line is { text, colorKey }; an empty list for a kind with no words.
QuestUI.HOVER_FROM_MEANING = { sod = true }
QuestUI.HOVER_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
QuestUI.HOVER_FALLBACK_COLOUR = "ITEMTREE_COLOR_TEXT_TITLE"

-- The count line: "1 change since Classic Era", "3 changes since Classic Era". nil for none.
function QuestUI.ChangeCountText(count)
  count = tonumber(count)
  if not count or count < 1 then
    return nil
  end
  count = math.floor(count)
  if count == 1 then
    return L["1 change since Classic Era"]
  end
  return string.format(L["%d changes since Classic Era"], count)
end

function QuestUI.MarkTooltipLines(kind, changeCount)
  if type(Badges) ~= "table" or type(kind) ~= "string" then
    return {}
  end
  local text
  if QuestUI.HOVER_FROM_MEANING[kind] then
    text = type(Badges.Meaning) == "function" and Badges.Meaning(kind) or nil
  elseif type(Badges.Title) == "function" then
    text = Badges.Title(kind)
  end
  if type(text) ~= "string" or text == "" then
    return {}
  end
  local meta = type(Badges.META) == "table" and Badges.META[kind] or nil
  local colorKey = type(meta) == "table" and (meta.tint or meta.ring) or nil
  local lines = { { text = text, colorKey = colorKey or QuestUI.HOVER_FALLBACK_COLOUR } }
  if kind == "changed" then
    local count = QuestUI.ChangeCountText(changeCount)
    if count then
      lines[2] = { text = count, colorKey = QuestUI.HOVER_MUTED }
    end
  end
  return lines
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The last few things the client refused, for a debug line. Bounded.
QuestUI.MAX_PROBLEMS = 8
QuestUI.problems = {}
QuestUI.hooks = { display = false, progress = false, log = false }

local function trace(what, err)
  local problems = QuestUI.problems
  problems[#problems + 1] = tostring(what) .. ": " .. tostring(err)
  while #problems > QuestUI.MAX_PROBLEMS do
    table.remove(problems, 1)
  end
  return false
end

local function apiCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if ok then
    return a, b, c, d, e, f
  end
  return nil
end

local function globalCall(name, ...)
  return apiCall(rawget(_G, name), ...)
end

local function method(object, name, ...)
  if type(object) ~= "table" then
    return nil
  end
  return apiCall(object[name], object, ...)
end

local function isShown(frame)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.IsShown) ~= "function" then
    return true
  end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and shown and true or false
end

local function hasScript(frame, name)
  if type(frame) ~= "table" or type(frame.HasScript) ~= "function" then
    return false
  end
  local ok, has = pcall(frame.HasScript, frame, name)
  return ok and has and true or false
end

local function settings()
  return (ItemTree.db and ItemTree.db.settings) or {}
end

local function flags()
  local core = ItemTree.QuestFlags
  if type(core) == "table" then
    return core
  end
  return nil
end

--------------------------------------------------------------------------------
-- Combat and the next tick (brief TX6)
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
QuestUI.afterCombat = {}
QuestUI.afterCombatOrder = {}

-- Books one redraw of a surface for PLAYER_REGEN_ENABLED. A surface already booked is not booked
-- again. Answers whether this call booked it.
local function bookAfterCombat(surface, fn)
  if QuestUI.afterCombat[surface] then
    return false
  end
  QuestUI.afterCombat[surface] = fn
  QuestUI.afterCombatOrder[#QuestUI.afterCombatOrder + 1] = surface
  if not QuestUI.combatFrame then
    local create = rawget(_G, "CreateFrame")
    local ok, frame = false, nil
    if type(create) == "function" then
      ok, frame = pcall(create, "Frame")
    end
    if ok and type(frame) == "table" then
      QuestUI.combatFrame = frame
      method(frame, "RegisterEvent", "PLAYER_REGEN_ENABLED")
      method(frame, "SetScript", "OnEvent", function()
        QuestUI.OnCombatEnd()
      end)
    end
  end
  return true
end

-- PLAYER_REGEN_ENABLED: runs every booked redraw once, clearing each flag first. Answers how many
-- ran.
function QuestUI.OnCombatEnd()
  local booked, order = QuestUI.afterCombat, QuestUI.afterCombatOrder
  QuestUI.afterCombat, QuestUI.afterCombatOrder = {}, {}
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

-- The draws the hooks booked for the next tick, by key. A key booked again before its tick runs
-- keeps the one timer and draws the latest call.
QuestUI.nextTick = {}

-- Runs fn on the next tick (C_Timer.After(0)), out of the client's show chain, or straight away on
-- a client with no C_Timer, the shape of Slash.Defer. Answers whether it was booked.
function QuestUI.Defer(key, fn)
  if type(fn) ~= "function" then
    return false
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) == "function" then
    local waiting = QuestUI.nextTick[key] ~= nil
    QuestUI.nextTick[key] = fn
    if waiting then
      return true
    end
    local ok = pcall(after, 0, function()
      local run = QuestUI.nextTick[key]
      QuestUI.nextTick[key] = nil
      if run then
        local drawn, err = pcall(run)
        if not drawn then
          trace(tostring(key), err)
        end
      end
    end)
    if ok then
      return true
    end
    QuestUI.nextTick[key] = nil
  end
  local drawn, err = pcall(fn)
  if not drawn then
    trace(tostring(key), err)
  end
  return false
end

local itemIdFromLink = ItemTree.Util.ItemIdFromLink
-- Brief UI1: whether a client value may be compared (bible B10), for attach's strata.
local canRead = ItemTree.Util.CanRead

--------------------------------------------------------------------------------
-- Fonts. A font string made without a template has no font, and SetText then raises inside the
-- client; SetFont answers false rather than raising when the face will not load. So a font string
-- is made from a client template, given the Theme face only when SetFont says yes, and given a
-- client font object otherwise, before any text reaches it. The shape of UI/Sidebar.lua's.
--------------------------------------------------------------------------------

QuestUI.FONT_TEMPLATE = "GameFontNormalSmall"
QuestUI.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(QuestUI.FONT_FALLBACKS) do
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
  return ok and face ~= nil and face ~= ""
end

local function ensureFont(fontString)
  if hasFont(fontString) then
    return true
  end
  return fallbackFont(fontString)
end

local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, QuestUI.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- The Theme body face at a Theme size, the 1px shadow, one line, in a Theme colour.
local function styleText(fontString, sizeKey, colorKey, justify)
  if type(fontString) ~= "table" then
    return nil
  end
  local face = Theme and Theme.fonts and Theme.fonts.ITEMTREE_FONT_BODY
  local size = Theme and Theme.sizes and Theme.sizes[sizeKey]
  if face and size and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, size, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline then
    method(fontString, "SetShadowOffset", outline.x, outline.y)
    method(fontString, "SetShadowColor", outline.r, outline.g, outline.b, outline.a)
  end
  method(fontString, "SetJustifyH", justify or "LEFT")
  method(fontString, "SetWordWrap", false)
  local colour = Theme and Theme.colors and Theme.colors[colorKey]
  if colour then
    method(fontString, "SetTextColor", colour.r, colour.g, colour.b, colour.a or 1)
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

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

-- Brief TX2: every frame here is made with NO parent, built whole (its badges included), and only
-- then moved under the client frame it marks by attach. On Forever the gamepad SmartNavigation
-- post hooks CreateFrame and, for a frame whose parent chain reaches an open panel (the quest
-- log, the quest giver's window), rebuilds that panel's navigation state as the caller
-- (Blizzard_GamepadSmartNavigation/SmartNavigation.lua SetupFrameHooks, branch forever), which
-- leaves it tainted by ItemTree. SetParent is not hooked.
local function newFrame()
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
  return frame
end

-- Moves a finished frame under the client frame it marks: the parent's strata where the move did
-- not hand it on, LEVEL_OFFSET levels above the parent, and each badge frame on it one level
-- above that, where a badge made with its parent lands. Answers true when the move took.
local function attach(frame, parent, ...)
  if type(frame) ~= "table" or type(parent) ~= "table" or type(frame.SetParent) ~= "function" then
    return false
  end
  -- Brief TX6: never moved in combat. The draws that reach here ask first; this is the backstop.
  if inCombat() then
    return false
  end
  if not pcall(frame.SetParent, frame, parent) then
    return false
  end
  -- Brief UI1: from 1.60.1.70425 GetFrameStrata can answer a secret (the new FrameStrata aspect,
  -- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:435-437, branch forever), and a
  -- secret raises on the compare. An unreadable strata is left alone: the frame keeps the one
  -- SetParent handed it.
  local strata = method(parent, "GetFrameStrata")
  if type(strata) == "string" and canRead(strata) and method(frame, "GetFrameStrata") ~= strata then
    method(frame, "SetFrameStrata", strata)
  end
  local level = tonumber(method(parent, "GetFrameLevel"))
  if level then
    method(frame, "SetFrameLevel", level + QuestUI.LEVEL_OFFSET)
    for index = 1, select("#", ...) do
      local child = select(index, ...)
      if type(child) == "table" then
        method(child, "SetFrameLevel", level + QuestUI.LEVEL_OFFSET + 1)
      end
    end
  end
  return true
end

local function newBadge(parent, context)
  if type(Badges) ~= "table" or type(Badges.Create) ~= "function" then
    return nil
  end
  local ok, badge = pcall(Badges.Create, parent, Badges.SizeFor(context))
  if not ok or type(badge) ~= "table" then
    return nil
  end
  method(badge, "EnableMouse", false)
  return badge
end

--------------------------------------------------------------------------------
-- The title badges' hover (brief Q7). Only ever on ItemTree's own badge frames: no script is set
-- on, and nothing is written to, any client frame.
--------------------------------------------------------------------------------

local function tooltip()
  local frame = rawget(_G, "GameTooltip")
  if type(frame) == "table" then
    return frame
  end
  return nil
end

local function themeColour(key)
  local colour = Theme and Theme.colors and Theme.colors[key]
  if type(colour) == "table" then
    return colour
  end
  return nil
end

-- Shows GameTooltip for one title badge. Answers whether it drew.
function QuestUI.ShowMarkTooltip(badge)
  local tip = tooltip()
  if type(badge) ~= "table" or not tip then
    return false
  end
  local lines = QuestUI.MarkTooltipLines(badge.kind, badge.changeCount)
  if #lines == 0 then
    return false
  end
  method(tip, "SetOwner", badge, "ANCHOR_RIGHT")
  for index, line in ipairs(lines) do
    local colour = themeColour(line.colorKey) or {}
    if index == 1 then
      method(tip, "SetText", line.text, colour.r, colour.g, colour.b)
    else
      method(tip, "AddLine", line.text, colour.r, colour.g, colour.b, true)
    end
  end
  method(tip, "Show")
  return true
end

-- Hides GameTooltip if one of our badges holds it. A client without IsOwned hides it outright,
-- which is what leaving the badge means anyway.
function QuestUI.HideMarkTooltip(badge)
  local tip = tooltip()
  if not tip then
    return false
  end
  if type(tip.IsOwned) == "function" then
    local ok, owned = pcall(tip.IsOwned, tip, badge)
    if ok and not owned then
      return false
    end
  end
  method(tip, "Hide")
  return true
end

-- Motion only, clicks passed through, and the two scripts, on our own badge. Once per badge.
local function makeHoverable(badge)
  if type(badge) ~= "table" or badge.questHover or inCombat() then
    return false
  end
  badge.questHover = true
  method(badge, "EnableMouse", true)
  method(badge, "SetMouseMotionEnabled", true)
  method(badge, "SetMouseClickEnabled", false)
  -- Brief NC1: refused in combat, so through the badges' deferral (now, or once combat ends).
  if type(Badges) == "table" and type(Badges.PropagateClicks) == "function" then
    pcall(Badges.PropagateClicks, badge)
  end
  method(badge, "SetScript", "OnEnter", function(self)
    local ok, err = pcall(QuestUI.ShowMarkTooltip, self)
    if not ok then
      trace("mark hover", err)
    end
  end)
  method(badge, "SetScript", "OnLeave", function(self)
    pcall(QuestUI.HideMarkTooltip, self)
  end)
  return true
end

local function badgeSize(context)
  if type(Badges) == "table" and type(Badges.SizeFor) == "function" then
    return tonumber(Badges.SizeFor(context)) or 14
  end
  return 14
end

-- One title tag per surface, keyed by surface name. Its parent is the frame the title sits in at
-- draw time (the surface's scroll child), so the tag scrolls and clips with the title, hides with
-- its panel, and is anchored to that frame's right edge rather than to the end of the title text.
QuestUI.tags = {}

local function tagFor(surface, parent)
  local tag = QuestUI.tags[surface]
  if tag and tag.parent ~= parent then
    if not attach(tag, parent, tag.newBadge, tag.changedBadge) then
      return nil
    end
    tag.parent = parent
  end
  if tag then
    return tag
  end
  if type(parent) ~= "table" then
    return nil
  end
  tag = newFrame()
  if not tag then
    return nil
  end
  tag.newBadge = newBadge(tag, QuestUI.TITLE_BADGE)
  tag.changedBadge = newBadge(tag, QuestUI.TITLE_BADGE)
  makeHoverable(tag.newBadge)
  makeHoverable(tag.changedBadge)
  if not attach(tag, parent, tag.newBadge, tag.changedBadge) then
    return nil
  end
  tag.parent = parent
  QuestUI.tags[surface] = tag
  return tag
end

local function hideTag(surface)
  local tag = QuestUI.tags[surface]
  if tag then
    if tag.newBadge then
      QuestUI.HideMarkTooltip(tag.newBadge)
    end
    if tag.changedBadge then
      QuestUI.HideMarkTooltip(tag.changedBadge)
    end
    method(tag, "Hide")
  end
end

-- What the client says about where the title sits in its parent, for TagPlacement.
local function measureTitle(header, parent)
  local measured = {
    parentWidth = tonumber(method(parent, "GetWidth")),
    width = tonumber(method(header, "GetWidth")),
  }
  local point, relativeTo, relativePoint, x, y = method(header, "GetPoint", 1)
  if point == "TOPLEFT" and relativePoint == "TOPLEFT" and (relativeTo == parent or relativeTo == nil) then
    measured.x, measured.y = tonumber(x), tonumber(y)
  end
  return measured
end

-- Lays out one tag for a title font string: [New badge][Changed badge], its right edge at the
-- right end of the title's text column. changeCount, where the rewards were read, is how many
-- rewards are new since Classic Era, for the Changed badge's hover. Returns true when something is
-- shown.
local function drawTag(surface, header, isNew, isChanged, changeCount)
  if type(header) ~= "table" then
    hideTag(surface)
    return false
  end
  local kinds = QuestUI.TitleKinds(isNew, isChanged)
  if #kinds == 0 then
    hideTag(surface)
    return false
  end
  local parent = method(header, "GetParent") or header
  local tag = tagFor(surface, parent)
  if not tag then
    return false
  end
  local size = badgeSize(QuestUI.TITLE_BADGE)
  local gap = QuestUI.GAP
  -- Left to right: the New badge, the Changed badge.
  local parts = {}
  if isNew and tag.newBadge then
    method(tag.newBadge, "SetKind", "new")
    parts[#parts + 1] = tag.newBadge
  elseif tag.newBadge then
    method(tag.newBadge, "SetKind", nil)
  end
  if tag.changedBadge then
    tag.changedBadge.changeCount = isChanged and tonumber(changeCount) or nil
  end
  if isChanged and tag.changedBadge then
    method(tag.changedBadge, "SetKind", "changed")
    parts[#parts + 1] = tag.changedBadge
  elseif tag.changedBadge then
    method(tag.changedBadge, "SetKind", nil)
  end
  local x = 0
  for index, part in ipairs(parts) do
    method(part, "ClearAllPoints")
    method(part, "SetPoint", "LEFT", tag, "LEFT", x, 0)
    x = x + size + (index < #parts and gap or 0)
  end
  method(tag, "SetSize", math.max(x, 1), size)
  method(tag, "ClearAllPoints")
  local _, fontHeight = method(header, "GetFont")
  local offsetX, offsetY = QuestUI.TagPlacement(surface, measureTitle(header, parent), tonumber(fontHeight), size)
  method(tag, "SetPoint", "TOPRIGHT", parent, "TOPRIGHT", offsetX, offsetY)
  method(tag, "Show")
  return true
end

--------------------------------------------------------------------------------
-- The wash
--------------------------------------------------------------------------------

-- One wash per surface, keyed by surface name, parented to the frame the title sits in.
QuestUI.washes = {}

local function colourObject(colour)
  local create = rawget(_G, "CreateColor")
  if type(create) ~= "function" then
    return nil
  end
  local ok, object = pcall(create, colour.r, colour.g, colour.b, colour.a)
  if ok and object ~= nil then
    return object
  end
  return nil
end

-- A vertical fade on a white texture, bottom colour to top colour: the modern SetGradient with two
-- ColorMixin colours first, then the old SetGradientAlpha, each under pcall. Answers which took,
-- "modern" or "alpha", or false.
function QuestUI.PaintGradient(texture, bottom, top)
  if type(texture) ~= "table" or type(bottom) ~= "table" or type(top) ~= "table" then
    return false
  end
  if type(texture.SetGradient) == "function" then
    local low, high = colourObject(bottom), colourObject(top)
    if low and high and pcall(texture.SetGradient, texture, "VERTICAL", low, high) then
      return "modern"
    end
  end
  if type(texture.SetGradientAlpha) == "function" then
    local ok = pcall(
      texture.SetGradientAlpha,
      texture,
      "VERTICAL",
      bottom.r,
      bottom.g,
      bottom.b,
      bottom.a,
      top.r,
      top.g,
      top.b,
      top.a
    )
    if ok then
      return "alpha"
    end
  end
  return false
end

local function newWashTexture(frame)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(frame.CreateTexture, frame, nil, QuestUI.WASH_LAYER, nil, QuestUI.WASH_SUBLEVEL)
  if not ok or type(texture) ~= "table" then
    return nil
  end
  local Assets = ItemTree.Assets
  if type(Assets) == "table" and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  return texture
end

-- Full width across the top of the text column, one frame level under the frame that holds the
-- text, so it draws over the parchment and under the words. Set again at every draw, since the
-- client may have raised the panel since.
local function placeWash(wash, parent, height)
  local level = tonumber(method(parent, "GetFrameLevel"))
  if level then
    method(wash, "SetFrameLevel", math.max(level - 1, 0))
  end
  method(wash, "ClearAllPoints")
  method(wash, "SetPoint", "TOPLEFT", parent, "TOPLEFT", 0, 0)
  method(wash, "SetPoint", "TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  method(wash, "SetHeight", height)
end

local function washFor(surface, parent)
  local wash = QuestUI.washes[surface]
  if wash then
    if wash.parent ~= parent then
      if not attach(wash, parent) then
        return nil
      end
      wash.parent = parent
    end
    return wash
  end
  if type(parent) ~= "table" then
    return nil
  end
  wash = newFrame()
  if not wash then
    return nil
  end
  wash.bands = {}
  local above
  for _, band in ipairs(QuestUI.WashBands()) do
    local texture = newWashTexture(wash)
    if texture then
      if above then
        method(texture, "SetPoint", "TOPLEFT", above, "BOTTOMLEFT", 0, 0)
        method(texture, "SetPoint", "TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
      else
        method(texture, "SetPoint", "TOPLEFT", wash, "TOPLEFT", 0, 0)
        method(texture, "SetPoint", "TOPRIGHT", wash, "TOPRIGHT", 0, 0)
      end
      method(texture, "SetHeight", band.height)
      texture.gradientRoute = QuestUI.PaintGradient(texture, band.bottom, band.top)
      wash.bands[#wash.bands + 1] = texture
      above = texture
    end
  end
  if not attach(wash, parent) then
    return nil
  end
  wash.parent = parent
  QuestUI.washes[surface] = wash
  return wash
end

-- Hides the surface's wash. It is hidden whatever the settings say, so turning either switch off
-- takes the wash down on the next Refresh.
local function hideWash(surface)
  local wash = QuestUI.washes[surface]
  if wash then
    method(wash, "Hide")
  end
end

-- Shows the surface's wash behind a New quest's text, and hides it for anything else, or while the
-- wash switch or the marks are off (QuestUI.WashEnabled). The badge is drawn apart from this.
local function drawWash(surface, parent, questIsNew)
  if
    not questIsNew
    or not QuestUI.WASH_SURFACES[surface]
    or type(parent) ~= "table"
    or not QuestUI.WashEnabled(settings())
  then
    hideWash(surface)
    return false
  end
  local wash = washFor(surface, parent)
  if not wash then
    return false
  end
  placeWash(wash, parent, QuestUI.WashHeight())
  method(wash, "Show")
  return true
end

-- One overlay per reward button, keyed weakly by the button.
local rewardOverlays = setmetatable({}, { __mode = "k" })

local function rewardOverlay(button)
  local overlay = rewardOverlays[button]
  if overlay then
    return overlay
  end
  if type(button) ~= "table" then
    return nil
  end
  overlay = newFrame()
  if not overlay then
    return nil
  end
  method(overlay, "SetAllPoints", button)
  overlay.badge = newBadge(overlay, QuestUI.REWARD_BADGE)
  local icon = type(button.Icon) == "table" and button.Icon or button
  if overlay.badge then
    method(overlay.badge, "SetPoint", "TOPRIGHT", icon, "TOPRIGHT", -QuestUI.INSET, -QuestUI.INSET)
  end
  overlay.words = styleText(
    newFontString(overlay, "OVERLAY"),
    "ITEMTREE_FONTSIZE_BODY_SM",
    "ITEMTREE_COLOR_SEMANTIC_CHANGED",
    "RIGHT"
  )
  if overlay.words then
    method(overlay.words, "SetPoint", "BOTTOMRIGHT", button, "BOTTOMRIGHT", -QuestUI.ROW_INSET, QuestUI.INSET + 1)
  end
  if not attach(overlay, button, overlay.badge) then
    return nil
  end
  rewardOverlays[button] = overlay
  return overlay
end

local function clearReward(button)
  local overlay = rewardOverlays[button]
  if overlay then
    method(overlay.badge, "SetKind", nil)
    method(overlay, "Hide")
  end
end

-- The item id behind one reward button, read the way the client filled it. nil for a currency, a
-- hidden button, or a client that will not say.
function QuestUI.ButtonItemId(button, questLog)
  if type(button) ~= "table" or not isShown(button) then
    return nil
  end
  if button.objectType ~= nil and button.objectType ~= "item" then
    return nil
  end
  local kind = button.type
  if kind ~= "reward" and kind ~= "choice" then
    return nil
  end
  local index = tonumber(method(button, "GetID"))
  if not index or index <= 0 then
    return nil
  end
  local itemId
  if questLog then
    local info = kind == "choice" and "GetQuestLogChoiceInfo" or "GetQuestLogRewardInfo"
    itemId = select(6, globalCall(info, index))
    if not tonumber(itemId) then
      itemId = itemIdFromLink(globalCall("GetQuestLogItemLink", kind, index))
    end
  else
    itemId = select(6, globalCall("GetQuestItemInfo", kind, index))
    if not tonumber(itemId) then
      itemId = itemIdFromLink(globalCall("GetQuestItemLink", kind, index))
    end
  end
  return tonumber(itemId)
end

-- The buttons a rewards frame holds, in order. Only the client's own array: nothing is created.
local function rewardButtons(rewardsFrame)
  local buttons = type(rewardsFrame) == "table" and rawget(rewardsFrame, "RewardButtons") or nil
  if type(buttons) ~= "table" then
    return {}
  end
  local out = {}
  for index, button in ipairs(buttons) do
    if index > QuestUI.MAX_REWARDS then
      break
    end
    out[#out + 1] = button
  end
  return out
end

-- Marks every reward button of one rewards frame and answers whether any is a New reward, and how
-- many are. Reads one item id per shown item button, for the one quest on screen.
function QuestUI.MarkRewards(rewardsFrame, questId, questLog)
  local buttons = rewardButtons(rewardsFrame)
  local core = flags()
  if not core or not QuestUI.Enabled(settings()) then
    for _, button in ipairs(buttons) do
      clearReward(button)
    end
    return false, 0
  end
  local ids, fixed, choices = {}, {}, {}
  for _, button in ipairs(buttons) do
    local itemId = QuestUI.ButtonItemId(button, questLog)
    ids[button] = itemId
    if itemId then
      local list = button.type == "choice" and choices or fixed
      list[#list + 1] = itemId
    end
  end
  local ok, verdicts = pcall(core.RewardVerdicts, questId, fixed, choices)
  if not ok or type(verdicts) ~= "table" then
    verdicts = {}
  end
  local changed, count = false, 0
  for _, button in ipairs(buttons) do
    local itemId = ids[button]
    local kind, words = QuestUI.RewardMark(itemId and verdicts[itemId] or nil)
    if kind then
      local overlay = rewardOverlay(button)
      if overlay then
        method(overlay.badge, "SetKind", kind)
        if overlay.words then
          setText(overlay.words, words or "")
          if words then
            method(overlay.words, "Show")
          else
            method(overlay.words, "Hide")
          end
        end
        method(overlay, "Show")
      end
      if kind == "changed" then
        changed = true
        count = count + 1
      end
    else
      clearReward(button)
    end
  end
  return changed, count
end

--------------------------------------------------------------------------------
-- The surfaces
--------------------------------------------------------------------------------

-- The QuestInfo template globals this client names, read at call time.
local function templateGlobals()
  local globals = {}
  for name in pairs(QuestUI.TEMPLATES) do
    globals[name] = rawget(_G, name)
  end
  return globals
end

-- The quest QuestInfo is showing, the way QuestInfo reads it.
local function questInfoQuestId()
  local frame = rawget(_G, "QuestInfoFrame")
  local questLog = type(frame) == "table" and frame.questLog and true or false
  if questLog then
    local questLogApi = rawget(_G, "C_QuestLog")
    local selected = type(questLogApi) == "table" and apiCall(questLogApi.GetSelectedQuest) or nil
    return tonumber(selected), true
  end
  return tonumber(globalCall("GetQuestID")), false
end

local function isNew(questId)
  local core = flags()
  if not core or type(core.IsNew) ~= "function" then
    return false
  end
  local ok, answer = pcall(core.IsNew, questId)
  return ok and answer == true
end

-- What the map's title last learned from the map's rewards, so the order of the two calls does not
-- matter.
QuestUI.mapChanged = {}
QuestUI.mapChangeCount = {}

-- What each surface was last drawn from (the quest, whether it is the log's, the rewards frame and
-- the frame the surface lives in), so the setting can redraw what is on screen without asking
-- QuestInfoFrame, whose fields only describe the last call.
QuestUI.last = {}

local function titleHeader()
  return rawget(_G, "QuestInfoTitleHeader")
end

-- Redraws one surface from what the client last drew it with, while its frame is still shown;
-- what a surface books for the end of combat.
local function redrawSurface(surface)
  if surface == "progress" then
    if isShown(rawget(_G, "QuestFrameProgressPanel")) then
      return QuestUI.OnProgressShow()
    end
    hideTag("progress")
    return false
  end
  if surface == "log" then
    return QuestUI.OnLogUpdate()
  end
  local context = QuestUI.last[surface]
  if type(context) == "table" and isShown(context.parentFrame) then
    return QuestUI.DrawDisplay(context)
  end
  hideTag(surface)
  hideWash(surface)
  return false
end

-- In combat: books the surface's redraw for PLAYER_REGEN_ENABLED and answers true, touching no
-- frame. Out of combat answers false and the caller draws.
local function deferredByCombat(surface)
  if not inCombat() then
    return false
  end
  bookAfterCombat(surface, function()
    redrawSurface(surface)
  end)
  return true
end

-- Draws one surface from a context QuestUI.DisplayContext built. Returns true when the surface is one of ours.
function QuestUI.Draw(context)
  if type(context) ~= "table" then
    return false
  end
  local surface, questId = context.surface, context.questId
  if deferredByCombat(surface) then
    return true
  end
  local enabled = QuestUI.Enabled(settings())
  if surface == "mapRewards" then
    local changed, count = QuestUI.MarkRewards(context.rewardsFrame, questId, context.questLog)
    if questId then
      QuestUI.mapChanged = { [questId] = changed }
      QuestUI.mapChangeCount = { [questId] = count }
    end
    -- The map's title was drawn first on this client; give it the Changed badge now it is known.
    local map = QuestUI.last.map
    local header = titleHeader()
    if
      enabled
      and type(map) == "table"
      and map.questId == questId
      and isShown(map.parentFrame)
      and method(header, "GetParent") == map.parentFrame
    then
      drawTag("map", header, isNew(questId), changed, count)
    end
    return true
  end
  local changed, count = false, nil
  if QuestUI.REWARDS_WITH_TITLE[surface] then
    changed, count = QuestUI.MarkRewards(context.rewardsFrame, questId, context.questLog)
  elseif surface == "map" then
    changed = questId ~= nil and QuestUI.mapChanged[questId] == true
    count = questId ~= nil and QuestUI.mapChangeCount[questId] or nil
  end
  if not enabled or not questId then
    hideTag(surface)
    hideWash(surface)
    return true
  end
  local header = titleHeader()
  local questIsNew = isNew(questId)
  drawTag(surface, header, questIsNew, changed, count)
  drawWash(surface, method(header, "GetParent") or context.parentFrame, questIsNew)
  return true
end

-- What one QuestInfo_Display call shows, read at the call: the quest, whether it is the log's, the
-- rewards frame and the frame the surface lives in. Reads only, so the hook takes it inside the
-- client's call and draws from it a tick later. nil for a template that is not one of ours.
function QuestUI.DisplayContext(template, parentFrame)
  local surface = QuestUI.SurfaceFor(template, templateGlobals())
  if not surface then
    return nil
  end
  local questId, questLog = questInfoQuestId()
  local info = rawget(_G, "QuestInfoFrame")
  return {
    surface = surface,
    questId = questId,
    questLog = questLog,
    rewardsFrame = type(info) == "table" and info.rewardsFrame or nil,
    parentFrame = parentFrame,
  }
end

-- Draws what DisplayContext read. In combat the surface's redraw is booked instead.
function QuestUI.DrawDisplay(context)
  if type(context) ~= "table" or not context.surface then
    return false
  end
  local surface = context.surface
  QuestUI.last[surface] = context
  if deferredByCombat(surface) then
    return true
  end
  -- QuestInfoTitleHeader moves between the panels that share it, so any other surface's tag that
  -- was anchored to it goes before this surface's is drawn.
  if surface ~= "mapRewards" then
    for name in pairs(QuestUI.tags) do
      if name ~= surface and name ~= "progress" then
        hideTag(name)
      end
    end
  end
  return QuestUI.Draw(context)
end

-- The progress panel, which draws its own title and no rewards.
function QuestUI.OnProgressShow()
  if deferredByCombat("progress") then
    return false
  end
  local questId = tonumber(globalCall("GetQuestID"))
  if not QuestUI.Enabled(settings()) or not questId then
    hideTag("progress")
    return false
  end
  return drawTag("progress", rawget(_G, "QuestProgressTitleText"), isNew(questId), false)
end

-- Row badges, keyed weakly by the pooled row button.
local rowBadges = setmetatable({}, { __mode = "k" })

local function rowBadge(button)
  local badge = rowBadges[button]
  if badge then
    return badge
  end
  if type(button) ~= "table" then
    return nil
  end
  local holder = newFrame()
  if not holder then
    return nil
  end
  method(holder, "SetSize", badgeSize(QuestUI.ROW_BADGE), badgeSize(QuestUI.ROW_BADGE))
  holder.badge = newBadge(holder, QuestUI.ROW_BADGE)
  if holder.badge then
    method(holder.badge, "SetPoint", "CENTER", holder, "CENTER", 0, 0)
  end
  if not attach(holder, button, holder.badge) then
    return nil
  end
  rowBadges[button] = holder
  return holder
end

local function tagTextShown(button)
  local tagText = type(button) == "table" and button.TagText or nil
  if type(tagText) ~= "table" or not isShown(tagText) then
    return false
  end
  local text = method(tagText, "GetText")
  return type(text) == "string" and text ~= ""
end

-- One of the row's own regions by its key (Checkbox, TagTexture or StorylineTexture), or nil when
-- it is missing or hidden.
local function shownRegion(button, key)
  local region = rawget(button, key)
  if type(region) ~= "table" or not isShown(region) then
    return nil
  end
  return region
end

-- The row's tracking tick box (QuestLogTitleTemplate's Checkbox), or nil when it is missing or hidden.
local function tickBox(button)
  return shownRegion(button, "Checkbox")
end

-- One row: the New badge or nothing. button.questID is what the client set on the row; the
-- verdict is a table lookup.
function QuestUI.MarkRow(button, enabled)
  if type(button) ~= "table" then
    return false
  end
  local questId = tonumber(rawget(button, "questID"))
  if not enabled or not questId or not isNew(questId) then
    local holder = rowBadges[button]
    if holder then
      method(holder, "Hide")
    end
    return false
  end
  local holder = rowBadge(button)
  if not holder then
    return false
  end
  local tick = tickBox(button)
  local typeIcon, storyline = shownRegion(button, "TagTexture"), shownRegion(button, "StorylineTexture")
  local point, relativeKey, relativePoint, x =
    QuestUI.RowAnchor(tagTextShown(button), tick ~= nil, typeIcon ~= nil, storyline ~= nil)
  local relativeTo = button
  if relativeKey == "TagText" then
    relativeTo = button.TagText
  elseif relativeKey == "StorylineTexture" then
    relativeTo = storyline
  elseif relativeKey == "TagTexture" then
    relativeTo = typeIcon
  elseif relativeKey == "Checkbox" then
    relativeTo = tick
  end
  method(holder, "ClearAllPoints")
  method(holder, "SetPoint", point, relativeTo, relativePoint, x, 0)
  method(holder.badge, "SetKind", "new")
  method(holder, "Show")
  return true
end

-- A broken iterator must not spin: no quest log holds anywhere near this many rows.
local MAX_ROWS = 200

-- After every QuestLogQuests_Update: the pool's active rows, and only those.
function QuestUI.OnLogUpdate()
  if deferredByCombat("log") then
    return 0
  end
  local scroll = rawget(_G, "QuestScrollFrame")
  local pool = type(scroll) == "table" and scroll.titleFramePool or nil
  if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then
    return 0
  end
  local enabled = QuestUI.Enabled(settings())
  local ok, iterator, state, control = pcall(pool.EnumerateActive, pool)
  if not ok or type(iterator) ~= "function" then
    return 0
  end
  local marked = 0
  for _ = 1, MAX_ROWS do
    local stepped, button = pcall(iterator, state, control)
    if not stepped or button == nil then
      break
    end
    control = button
    if QuestUI.MarkRow(button, enabled) then
      marked = marked + 1
    end
  end
  return marked
end

-- Redraws what is on screen, after the setting changes. Each surface is redrawn from the arguments
-- the client last drew it with, and only while its frame is shown.
function QuestUI.Refresh()
  if inCombat() then
    bookAfterCombat("refresh", QuestUI.Refresh)
    return false
  end
  -- The map's title before its rewards, the order the client draws them in.
  for _, surface in ipairs({ "offer", "turnin", "popup", "map", "mapRewards" }) do
    local context = QuestUI.last[surface]
    if type(context) == "table" and isShown(context.parentFrame) then
      pcall(QuestUI.Draw, context)
    else
      hideTag(surface)
      hideWash(surface)
    end
  end
  if isShown(rawget(_G, "QuestFrameProgressPanel")) then
    pcall(QuestUI.OnProgressShow)
  else
    hideTag("progress")
  end
  pcall(QuestUI.OnLogUpdate)
  return true
end

--------------------------------------------------------------------------------
-- Install
--------------------------------------------------------------------------------

local function hookGlobal(name, handler)
  local hook = rawget(_G, "hooksecurefunc")
  if type(hook) ~= "function" or type(rawget(_G, name)) ~= "function" then
    return false
  end
  local ok, err = pcall(hook, name, handler)
  if not ok then
    return trace(name .. " hook", err)
  end
  return true
end

-- Takes whichever hook is still missing. Idempotent: each is taken once.
function QuestUI.Install()
  local hooks = QuestUI.hooks
  if not hooks.display then
    -- Brief TX6: read inside the client's call, drawn a tick later, out of its show chain.
    hooks.display = hookGlobal("QuestInfo_Display", function(template, parentFrame)
      local ok, context = pcall(QuestUI.DisplayContext, template, parentFrame)
      if not ok then
        trace("QuestInfo_Display", context)
      elseif context then
        QuestUI.Defer(context.surface, function()
          QuestUI.DrawDisplay(context)
        end)
      end
    end)
  end
  if not hooks.log then
    hooks.log = hookGlobal("QuestLogQuests_Update", function()
      QuestUI.Defer("log", QuestUI.OnLogUpdate)
    end)
  end
  if not hooks.progress then
    local panel = rawget(_G, "QuestFrameProgressPanel")
    if hasScript(panel, "OnShow") and type(panel.HookScript) == "function" then
      -- Brief TX6: the hook stays, the draw moves out of ShowUIPanel to the next tick.
      local ok, err = pcall(panel.HookScript, panel, "OnShow", function()
        QuestUI.Defer("progress", QuestUI.OnProgressShow)
      end)
      if ok then
        hooks.progress = true
      else
        trace("progress panel hook", err)
      end
    end
  end
  QuestUI.installed = hooks.display or hooks.log or hooks.progress
  return QuestUI.installed
end

-- One line for a debug listing. Yes or no answers only.
function QuestUI.StatusLine()
  local hooks = QuestUI.hooks
  local function word(on)
    return on and "hooked" or "absent"
  end
  return string.format(
    "Quest marks: QuestInfo_Display %s, progress panel %s, QuestLogQuests_Update %s, %d problem(s)",
    word(hooks.display),
    word(hooks.progress),
    word(hooks.log),
    #QuestUI.problems
  )
end

-- At PLAYER_LOGIN, and again when another Blizzard addon loads while a hook is still missing.
local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local ok, loader = pcall(createFrame, "Frame")
  if ok and type(loader) == "table" then
    pcall(loader.RegisterEvent, loader, "PLAYER_LOGIN")
    pcall(loader.RegisterEvent, loader, "ADDON_LOADED")
    pcall(loader.SetScript, loader, "OnEvent", function(self, event)
      if event == "ADDON_LOADED" and not QuestUI.loggedIn then
        return
      end
      QuestUI.loggedIn = true
      QuestUI.Install()
      local hooks = QuestUI.hooks
      if hooks.display and hooks.log and hooks.progress then
        pcall(self.UnregisterEvent, self, "ADDON_LOADED")
        pcall(self.UnregisterEvent, self, "PLAYER_LOGIN")
      end
    end)
  end
end

return QuestUI
