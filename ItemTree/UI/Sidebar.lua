-- Category sidebar down the left of the window.
--
-- An inset panel of rows, which is the design's Sidebar (harness/src/render-design.tsx,
-- core/InsetPanel.jsx, frame/CategoryListItem.jsx).
--
-- The first row is always All: the label, the total of every category count, and the row that
-- clears the filter. Under it one row per category from ItemTree.ViewModel vm:Categories():
-- the profession glyph or the category shape's icon, the label, up to two 12px badges and the
-- count right aligned at the row's padding. The count column is as wide as the widest count in
-- the list and no wider, and the badges sit one gutter to its left, so the marks read as part
-- of the number rather than stranded half a row away from it; every row shares the one column,
-- so the marks line up down the pane. The label is the part that gives way and truncates with
-- an ellipsis. A profession row reads the player's rank
-- as well, "Blacksmithing 265/300", which is Core's own wording through Skills.CategoryHeader.
--
-- Selecting a row filters the right pane through vm:SetFilter(categoryId) and then asks
-- ItemTree.UI.Frame to redraw: the sidebar never redraws the tree itself and never re-roots.
-- Selecting All, or the category that is already selected, clears the filter.
--
-- The pane has no search box of its own. The window's search lives in the tree pane, which is
-- the half that narrows, so Frame.SetTextFilter is wired there and not here, and the list
-- takes the height the box used to hold off the top of the pane.
--
-- Width is the window's to decide and is never written down here. The glyph is anchored to the
-- row's left edge and the count column to its right, and the label is anchored to both, so the
-- label is the part that gives way. A region the window resizes redraws through OnSizeChanged.
--
-- Anatomy (Theme.sizes):
--   ITEMTREE_LIST_CATEGORY_H 24 row height, ITEMTREE_ICON_CATEGORY 16 glyph
--   ITEMTREE_BADGE_SIZE_LIST 12 for up to two badges, ITEMTREE_LIST_COL_COUNT 36 count ceiling
--   ITEMTREE_SPACE_2 8 gutter, ITEMTREE_LIST_GUTTER 6
-- The 8px gutter is the gap the ui kit keeps between the sidebar and the tree pane, which the
-- window owns; inside the pane the list is flush, because the design's InsetPanel holds it at
-- pad 0 and the 6px gutter is the row's own.
--
-- Every font string is created from one of the client's own font objects, because the beta
-- raises "FontString:SetText(): Font not set" on a font string that was never given a font,
-- and the Theme face goes over the top only where the client will take it. UI/Badges.lua does
-- the same for the glyph in its composed badges, which is what a category row draws.
--
-- Client APIs: ScrollBox with CreateScrollBoxListLinearView plus CreateDataProvider fed from
-- vm:Categories(); Assets.ForSkill(skillId) for the profession glyph;
-- Badges.CreateCluster(parent, 12, 2) for the header badges; GameTooltip for the row tooltips.
-- A client with no ScrollBox gets a plain frame pool instead, one row frame per category,
-- which is what the harness runs on.
--
-- Contract with the window (UI/Frame.lua owns both):
--   Attach(region) once, with a child frame the window created and sized.
--   Show(vm) on every open, re-root and refresh: re-reads vm:Categories() and redraws.
--   Refresh() redraws from the last view model. Hide() hides the pane.
-- All idempotent, and all no ops with no client.
--
-- Sidebar.RowModel, Sidebar.AllRow, Sidebar.Rows, Sidebar.Interpret, Sidebar.Total,
-- Sidebar.TooltipLines, Sidebar.Overflows, Sidebar.WidestCount, Sidebar.CountWidth and
-- Sidebar.BadgeOverhang are pure and run under busted. Everything that touches a frame is
-- guarded, so this file loads with no WoW API present.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Sidebar = {}
ItemTree.UI.Sidebar = Sidebar

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local Badges = ItemTree.Badges
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

-- Theme is loaded before this file in the TOC, but a size is read through a fallback anyway so
-- the module still loads if it is ever asked for on its own.
local size = Theme.Size

Sidebar.ROW_H = size("ITEMTREE_LIST_CATEGORY_H", 24)
Sidebar.ICON_SIZE = size("ITEMTREE_ICON_CATEGORY", 16)
Sidebar.BADGE_SIZE = size("ITEMTREE_BADGE_SIZE_LIST", 12)
Sidebar.BADGE_MAX = 2
-- The ceiling the count column is measured against, never the width it is drawn at: the pane
-- narrows it to the widest count the list actually carries. An Arial Narrow digit runs a
-- little over half the font size wide, which is what a client that will not measure a string
-- gets instead of a measurement.
Sidebar.COUNT_W = size("ITEMTREE_LIST_COL_COUNT", 36)
Sidebar.COUNT_CHAR = 0.6
Sidebar.GUTTER = size("ITEMTREE_LIST_GUTTER", 6)
Sidebar.SCROLLBAR_W = size("ITEMTREE_SCROLLBAR_W", 16)
Sidebar.EDGE_W = size("ITEMTREE_BORDER_HAIRLINE", 1)

-- The ScrollBox builds its rows from a real XML template, and the addon ships no XML, so the
-- rows are BackdropTemplate frames with the mouse enabled by hand. Every client that carries
-- ScrollBox carries BackdropTemplate, and a client that refuses it falls back to the pool.
Sidebar.ROW_TEMPLATE = "BackdropTemplate"

-- The client font objects a font string is created from, in the order they are tried. The
-- template is handed to CreateFontString so the string has a font before anything can write to
-- it, and the rest are what a client that refused the template is offered instead.
Sidebar.FONT_TEMPLATE = "GameFontNormalSmall"
Sidebar.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

Sidebar.KIND_CATEGORY = "category"
Sidebar.KIND_ALL = "all"

-- The design draws the sidebar count in brackets (CategoryListItem.jsx). Punctuation, not
-- copy, so it is not a locale string.
Sidebar.COUNT_FORMAT = "(%d)"

-- What a badge on a category row means, in one line each. UI/Badges.lua owns these words now
-- (Badges.LIST_MEANING), and this table is the fallback for a client where that file did not
-- load. Keys rather than strings, so the sweep in tests/spec/locale_spec.lua lists them.
Sidebar.BADGE_MEANING = {
  new = "New in Forever",
  changed = "Changed in Forever",
  removed = "Removed in Forever",
  predicted = "Predicted data, not yet confirmed",
  unverified = "Imported baseline, unverified",
  note = "A note other players added about this item",
  verified = "Verified by the collector",
  -- Brief GS3: a category of guessed sources.
  guess = "ItemTree's best guess, not yet seen in the game.",
}

local function countText(count)
  local number = tonumber(count)
  if not number then
    return ""
  end
  return string.format(Sidebar.COUNT_FORMAT, number)
end

-- The profession glyph wins over the category's own icon key: both tables say the same thing
-- today (ViewModel.SKILL_ICONS mirrors Assets.skillGlyphs), and Assets is the UI's own, so it
-- is the one that decides what the UI draws.
local function iconKey(category)
  local skillLine = tonumber(category.skillLine)
  if skillLine and Assets and type(Assets.ForSkill) == "function" then
    return Assets.ForSkill(skillLine)
  end
  return category.icon
end

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then
      return true
    end
  end
  return false
end

-- The category's badges, most urgent first and cut to two. A server side category always
-- carries Unverified, which is the design's rule for the group header (readme, Sidebar
-- category panels). The view model is stricter, adding it only when some entry is still
-- baseline, so this widens it rather than narrowing it and a category the collector has fully
-- verified still reads as server side data.
--
-- Brief PS3: the "?" stands for "Imported baseline, unverified", so it goes only on a category
-- that holds such a row. The view model says so in category.eraRows (Core/ViewModel.lua): false
-- for a category whose rows are all plain data (the player's own, shipped player sourced rows,
-- the client's and the build's own), which wears no "?". A category it never judged keeps the
-- old rule.
local function unverifiedRows(category)
  return category.serverSide and category.eraRows ~= false
end

local function badgeList(category)
  local kinds = {}
  for _, kind in ipairs(category.badges or EMPTY) do
    kinds[#kinds + 1] = kind
  end
  if unverifiedRows(category) and not contains(kinds, "unverified") then
    kinds[#kinds + 1] = "unverified"
  end
  if Badges and type(Badges.Sort) == "function" then
    return Badges.Sort(kinds, Sidebar.BADGE_MAX)
  end
  for index = #kinds, Sidebar.BADGE_MAX + 1, -1 do
    kinds[index] = nil
  end
  return kinds
end

-- What the player's own trade skills say about a profession category: rank, maximum,
-- specialisation and the line Core writes from them, "Blacksmithing 265/300, Armorsmith".
-- Core owns every word of it, so the sidebar, the tree pane and the browser harness cannot
-- drift apart. Read lazily and through pcall: a half loaded addon draws the plain label.
local function skillHeader(category, skills)
  if type(skills) ~= "table" then
    return nil
  end
  local Skills = ItemTree.Skills
  if type(Skills) ~= "table" or type(Skills.CategoryHeader) ~= "function" then
    return nil
  end
  local ok, header = pcall(Skills.CategoryHeader, category, skills)
  if ok and type(header) == "table" then
    return header
  end
  return nil
end

-- The sum of every category count: what the All row says. Pure.
function Sidebar.Total(categories)
  local total = 0
  for _, category in ipairs(categories or EMPTY) do
    total = total + (tonumber(category.count) or 0)
  end
  return total
end

-- The row that shows everything. It is permanently the first row, it carries the total rather
-- than a count of its own, and it is the selected row while no filter is set. It has no glyph,
-- so the labels stay in one column. Pure.
function Sidebar.AllRow(categories, selectedId)
  local total = Sidebar.Total(categories)
  return {
    kind = Sidebar.KIND_ALL,
    id = nil,
    name = L["All"],
    label = L["All"],
    count = total,
    countText = countText(total),
    badges = {},
    serverSide = false,
    selected = selectedId == nil,
  }
end

-- One row of the list, from one entry of vm:Categories(). selectedId is the category the pane
-- is filtered to, or nil. opts.skills are the player's trade skills, which turn a profession
-- label into the rank line. Pure.
function Sidebar.RowModel(category, selectedId, opts)
  if type(category) ~= "table" then
    return nil
  end
  opts = opts or EMPTY
  local id = category.id ~= nil and tostring(category.id) or nil
  local name = tostring(category.label or "")
  local header = skillHeader(category, opts.skills)
  local rankLine = header and type(header.line) == "string" and header.line or nil
  return {
    kind = Sidebar.KIND_CATEGORY,
    id = id,
    name = name,
    label = rankLine or name,
    rankLine = rankLine,
    rank = header and header.rank or nil,
    max = header and header.max or nil,
    specialisation = header and header.specialisation or nil,
    count = tonumber(category.count) or 0,
    countText = countText(category.count),
    icon = iconKey(category),
    badges = badgeList(category),
    serverSide = category.serverSide and true or false,
    -- Brief PS3: false where every row is plain data, so the tooltip adds no notice of its own.
    unverified = unverifiedRows(category) and true or false,
    notice = type(category.notice) == "string" and category.notice or nil,
    selected = id ~= nil and selectedId ~= nil and id == tostring(selectedId),
  }
end

-- Every row the pane draws: the All row, then one row per category, in the view model's order.
-- The All row's count is the total of every category, because it is what selecting it goes
-- back to. A filter naming a category that has gone highlights nothing, and All is not
-- highlighted either, so the pane still says it is filtered and can always be cleared. Pure.
function Sidebar.Rows(categories, selectedId, opts)
  opts = opts or EMPTY
  local rows = { Sidebar.AllRow(categories, selectedId) }
  for _, category in ipairs(categories or EMPTY) do
    local model = Sidebar.RowModel(category, selectedId, opts)
    if model then
      rows[#rows + 1] = model
    end
  end
  return rows
end

-- The filter id a click on this row asks for, or nil to clear it. The All row clears, and so
-- does the category that is already selected. Pure.
function Sidebar.Interpret(rowModel, selectedId)
  if type(rowModel) ~= "table" or rowModel.kind == Sidebar.KIND_ALL or rowModel.id == nil then
    return nil
  end
  local id = tostring(rowModel.id)
  if selectedId ~= nil and id == tostring(selectedId) then
    return nil
  end
  return id
end

local function countLine(model)
  local count = tonumber(model.count) or 0
  if model.kind == Sidebar.KIND_ALL then
    return string.format(L["%d rows in every category"], count)
  end
  if count == 1 then
    return string.format(L["%d row in this category"], count)
  end
  return string.format(L["%d rows in this category"], count)
end

local function badgeMeaning(kind)
  if Badges and type(Badges.LIST_MEANING) == "table" then
    local shared = Badges.LIST_MEANING[kind]
    if type(shared) == "string" then
      return shared
    end
  end
  local text = Sidebar.BADGE_MEANING[kind]
  if text then
    return L[text]
  end
  if Badges and type(Badges.Label) == "function" then
    return Badges.Label(kind)
  end
  return nil
end

-- What a row's tooltip says under its name: how many rows are in it, the player's rank and
-- specialisation where the category is a profession they have, what each of its badges means,
-- and, for a server side category, where the data came from. Pure.
function Sidebar.TooltipLines(model)
  local lines = {}
  if type(model) ~= "table" then
    return lines
  end
  local count = countLine(model)
  if count then
    lines[#lines + 1] = count
  end
  if model.rankLine then
    lines[#lines + 1] = model.rankLine
  end
  for _, kind in ipairs(model.badges or EMPTY) do
    local meaning = badgeMeaning(kind)
    if meaning then
      lines[#lines + 1] = meaning
    end
  end
  if model.serverSide and (model.notice or model.unverified ~= false) then
    local ViewModel = ItemTree.ViewModel
    lines[#lines + 1] = model.notice
      or (type(ViewModel) == "table" and ViewModel.SOURCE_NOTICE)
      or L["Imported baseline, unverified"]
  end
  return lines
end

--- The longest count in these rows, as the string a row draws. "" when there is nothing to
--- draw. The All row counts too, because it is the widest of them more often than not. Pure.
function Sidebar.WidestCount(rows)
  local widest = ""
  for _, model in ipairs(rows or EMPTY) do
    local text = type(model) == "table" and model.countText or nil
    if type(text) == "string" and #text > #widest then
      widest = text
    end
  end
  return widest
end

--- The room the count column needs for that string. measured is what the client made of it in
--- pixels, or nil where it could not be asked, and the character estimate is the floor either
--- way. Never wider than the design's own count column, and never narrower than one character,
--- so an empty list still lays a row out. Pure.
function Sidebar.CountWidth(text, fontSize, measured)
  local fontHeight = tonumber(fontSize) or size("ITEMTREE_FONTSIZE_BODY_SM", 11)
  local one = math.ceil(fontHeight * Sidebar.COUNT_CHAR)
  local chars = type(text) == "string" and #text or 0
  local width = math.max(math.ceil(chars * fontHeight * Sidebar.COUNT_CHAR), tonumber(measured) or 0)
  return math.max(one, math.min(Sidebar.COUNT_W, width))
end

--- How far a badge's medallion stands proud of the cluster box on each side. UI/Badges.lua
--- draws a supplied medallion one step up the badge size ladder, because the medallion carries
--- its own ring where a composed badge draws its glyph inside one, so every gap beside a
--- cluster allows for it and a mark never crowds the number or the label next to it. Pure, and
--- guarded: a build whose Badges cannot be asked reads as no overhang at all.
function Sidebar.BadgeOverhang()
  local art = Sidebar.BADGE_SIZE
  if Badges and type(Badges.ArtSize) == "function" then
    local ok, value = pcall(Badges.ArtSize, Sidebar.BADGE_SIZE)
    if ok and tonumber(value) then
      art = tonumber(value)
    end
  end
  return math.max(0, math.ceil((art - Sidebar.BADGE_SIZE) / 2))
end

--- The gap either side of a badge cluster: the row's own gutter, plus the pixel the medallion
--- stands proud of the cluster box. Pure.
function Sidebar.BadgeGap()
  return Sidebar.GUTTER + Sidebar.BadgeOverhang()
end

-- Whether this many rows need a scrollbar in a list this tall. A height of nothing is a pane
-- the client has not laid out yet, which reads as fitting: an unwanted bar is worse than a
-- late one, and every Refresh asks again. Pure.
function Sidebar.Overflows(rowCount, height)
  local count = tonumber(rowCount) or 0
  local available = tonumber(height) or 0
  if available <= 0 then
    return false
  end
  return count * Sidebar.ROW_H > available
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

Sidebar.pool = {}

-- One interface cue, by name. UI/Sound.lua decides what a cue sounds like and whether cues are
-- on; this is the one line a call site writes, looked up at call time so a build or a spec
-- without the module costs the cue and nothing else.
local playCue = ItemTree.UI.Sound.PlayCue

local function newFrame(kind, parent)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent)
  if ok and frame then
    return frame
  end
  return nil
end

-- A frame that is only worth having with its template: the ScrollBox parts. CreateFrame raises
-- on a template the client does not carry, so nothing here is taken without a pcall.
local function newTemplatedFrame(kind, parent, template)
  local create = rawget(_G, "CreateFrame")
  if type(create) ~= "function" then
    return nil
  end
  local ok, frame = pcall(create, kind, nil, parent, template)
  if ok and frame then
    return frame
  end
  return nil
end

-- Theme.Color raises on an unknown key, so the table is read instead and a missing key leaves
-- the client's own colour alone. Same idiom as UI/Report.lua.
local function themeColor(key)
  local color = Theme and type(Theme.ColorTable) == "function" and Theme.ColorTable(key) or nil
  return color
end

local function tint(texture, key)
  local color = themeColor(key)
  if not color or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(color.r, color.g, color.b)
  if type(texture.SetAlpha) == "function" then
    texture:SetAlpha(color.a or 1)
  end
  return true
end

local function colourText(fontString, key)
  if type(fontString) ~= "table" then
    return false
  end
  local color = themeColor(key)
  if color and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
    return true
  end
  return false
end

-- A flat fill in one Theme colour. Every texture goes through Assets so the path lives in one
-- table and the harness can report it.
local function wash(parent, layer, colorKey)
  local texture = parent:CreateTexture(nil, layer)
  if Assets and type(Assets.Apply) == "function" then
    pcall(Assets.Apply, texture, "FILL_WHITE8X8")
  end
  tint(texture, colorKey)
  texture:Hide()
  return texture
end

-- The design's InsetPanel edge: four hairlines in one Theme colour, drawn by hand. Not a nine
-- slice: NineSliceUtil on the live clients is atlas oriented, and the file layout the info
-- panel hands it renders as a dotted edge rather than a line. Four fills cannot do that.
local function insetBorder(frame, colorKey)
  local edges = {}
  for index = 1, 4 do
    edges[index] = wash(frame, "BORDER", colorKey)
    edges[index]:Show()
  end
  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(Sidebar.EDGE_W)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(Sidebar.EDGE_W)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(Sidebar.EDGE_W)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(Sidebar.EDGE_W)
  return { top = top, bottom = bottom, left = left, right = right, edges = edges }
end

-- Hands the font string one of the client's own font objects. Nothing here can raise, and a
-- client carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Sidebar.FONT_FALLBACKS) do
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

-- A font string that is never fontless. The client's own font object is asked for at creation,
-- through the template argument where the client takes one and by hand where it does not, so
-- a SetText is never the first thing to touch the font.
local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, Sidebar.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- Body face, 1px shadow, one line. A font string that does not wrap and is anchored on both
-- sides is what makes the client truncate the label with an ellipsis rather than the count
-- column moving. SetFont answers false rather than raising where the client cannot load the
-- face, so the answer is read and a font object put back: a font string that lost its font
-- raises from inside the next SetText.
local function styleText(fontString, fontSize, colorKey, justify)
  if type(fontString) ~= "table" then
    return nil
  end
  local fonts = Theme and Theme.fonts
  local face
  if fonts then
    face = fonts.ITEMTREE_FONT_BODY
  end
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, fontSize, "")
    if not ok or applied == false then
      fallbackFont(fontString)
    end
  end
  ensureFont(fontString)
  local outline = Theme and Theme.text and Theme.text.ITEMTREE_TEXT_OUTLINE
  if outline and type(fontString.SetShadowOffset) == "function" then
    fontString:SetShadowOffset(outline.x, outline.y)
    if type(fontString.SetShadowColor) == "function" then
      fontString:SetShadowColor(outline.r, outline.g, outline.b, outline.a)
    end
  end
  if type(fontString.SetJustifyH) == "function" then
    fontString:SetJustifyH(justify)
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(false)
  end
  -- A category whose name has no space in it wraps anyway without this, because word wrap only
  -- governs breaks at a space: the name then runs under the count beside it. Optional on a
  -- client, so it is asked for and pcall'd, the way UI/Tree.lua does it.
  if type(fontString.SetNonSpaceWrap) == "function" then
    pcall(fontString.SetNonSpaceWrap, fontString, false)
  end
  if type(fontString.SetMaxLines) == "function" then
    pcall(fontString.SetMaxLines, fontString, 1)
  end
  colourText(fontString, colorKey)
  return fontString
end

-- Every word this pane draws goes through here. The font is put back first, and the write
-- itself is pcalled, so a client that can give a font string no font at all costs the pane a
-- blank label rather than the whole draw.
local function setText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  ensureFont(fontString)
  return (pcall(fontString.SetText, fontString, text or ""))
end

local function tooltipFrame()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return nil
  end
  return tooltip
end

-- The row's own tooltip, from the pure lines. Guarded end to end: a client with no GameTooltip
-- just shows the hover wash.
function Sidebar.ShowRowTooltip(row)
  local model = type(row) == "table" and row.rowModel or nil
  local tooltip = type(model) == "table" and tooltipFrame() or nil
  if not tooltip then
    return false
  end
  tooltip:SetOwner(row, "ANCHOR_RIGHT")
  local title = themeColor("ITEMTREE_COLOR_TEXT_TITLE")
  local name = model.name or model.label or ""
  if type(tooltip.SetText) == "function" then
    if title then
      tooltip:SetText(name, title.r, title.g, title.b)
    else
      tooltip:SetText(name)
    end
  end
  local body = themeColor("ITEMTREE_COLOR_TEXT_BODY")
  if type(tooltip.AddLine) == "function" then
    for _, line in ipairs(Sidebar.TooltipLines(model)) do
      if body then
        tooltip:AddLine(line, body.r, body.g, body.b, true)
      else
        tooltip:AddLine(line)
      end
    end
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

function Sidebar.HideRowTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
    return true
  end
  return false
end

local function onRowEnter(row)
  if row.hoverWash then
    row.hoverWash:Show()
  end
  Sidebar.ShowRowTooltip(row)
end

local function onRowLeave(row)
  if row.hoverWash then
    row.hoverWash:Hide()
  end
  Sidebar.HideRowTooltip()
end

local function onRowClick(row)
  Sidebar.Select(row and row.rowModel or nil)
end

-- E48: makes every mark in a row's cluster its own hover target, and hands it the two calls
-- that keep the row's hover wash on while the pointer is on the mark. Both methods arrived with
-- that brief, so a build whose Badges predates it draws exactly what it drew before.
local function askBadgeHover(cluster, row)
  if type(cluster) ~= "table" or type(cluster.SetHoverEnabled) ~= "function" then
    return false
  end
  pcall(cluster.SetHoverEnabled, cluster, true)
  if type(cluster.SetHoverHooks) ~= "function" then
    return true
  end
  pcall(cluster.SetHoverHooks, cluster, function()
    if row.hoverWash then
      row.hoverWash:Show()
    end
  end, function()
    onRowLeave(row)
  end)
  return true
end

-- Builds the widgets of one row, once. The ScrollBox hands back bare frames it made itself, so
-- this has to work on a frame the sidebar did not create.
function Sidebar.DecorateRow(row)
  if type(row) ~= "table" or row.itemTreeSidebarRow then
    return row
  end
  row.itemTreeSidebarRow = true
  row:SetHeight(Sidebar.ROW_H)
  if type(row.EnableMouse) == "function" then
    row:EnableMouse(true)
  end

  -- Selected is an 18 percent gold wash with a gold bar on the leading edge; hover is a
  -- 12 percent white wash. Both are flat fills, per the design's state rules.
  row.selectedWash = wash(row, "BACKGROUND", "ITEMTREE_LIST_STATE_SELECTED")
  row.selectedWash:SetAllPoints(row)
  row.hoverWash = wash(row, "BORDER", "ITEMTREE_COLOR_STATE_HOVER")
  row.hoverWash:SetAllPoints(row)
  row.selectedEdge = wash(row, "ARTWORK", "ITEMTREE_COLOR_BORDER_GOLD")
  row.selectedEdge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.selectedEdge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.selectedEdge:SetWidth(Sidebar.EDGE_W)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(Sidebar.ICON_SIZE, Sidebar.ICON_SIZE)
  row.icon:SetPoint("LEFT", row, "LEFT", Sidebar.GUTTER, 0)

  -- The count column is right aligned at the row's padding, so it is the one part of a row
  -- that does not move when the window widens the pane. Its width is the list's, not the
  -- row's: every row shares the column the widest count needs, which is what keeps the marks
  -- beside it in one line down the pane. Refresh writes that width, and this is the fallback
  -- for a row drawn before anything measured one.
  row.count = newFontString(row, "OVERLAY")
  if row.count then
    row.count:SetPoint("RIGHT", row, "RIGHT", -Sidebar.GUTTER, 0)
    row.count:SetWidth(Sidebar.countW or Sidebar.COUNT_W)
    styleText(row.count, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
  end

  if Badges and type(Badges.CreateCluster) == "function" then
    row.badges = Badges.CreateCluster(row, Sidebar.BADGE_SIZE, Sidebar.BADGE_MAX)
    local gap = Sidebar.BadgeGap()
    if row.badges and row.count then
      row.badges:SetPoint("RIGHT", row.count, "LEFT", -gap, 0)
    elseif row.badges then
      row.badges:SetPoint("RIGHT", row, "RIGHT", -gap, 0)
    end
    -- E48: each mark on a category row is its own hover target, so pointing at the "?" says
    -- what the "?" means rather than leaving the row's list tooltip up. The row keeps its wash
    -- while the pointer is on a mark, because a mark is part of the row as far as the player is
    -- concerned; the mark's own press is handed back to the row by UI/Badges.lua.
    askBadgeHover(row.badges, row)
  end

  row.label = newFontString(row, "OVERLAY")
  styleText(row.label, size("ITEMTREE_FONTSIZE_BODY_MD", 12), "ITEMTREE_COLOR_TEXT_BODY", "LEFT")

  row:SetScript("OnEnter", onRowEnter)
  row:SetScript("OnLeave", onRowLeave)
  row:SetScript("OnMouseUp", onRowClick)
  return row
end

-- Draws one row model into a row frame. Hiding the glyph leaves the label where it was, so the
-- All row's label sits in the same column as every category label.
function Sidebar.InitRow(row, model)
  if type(row) ~= "table" then
    return false
  end
  Sidebar.DecorateRow(row)
  row.rowModel = model
  if type(model) ~= "table" then
    row:Hide()
    return false
  end

  setText(row.label, model.label)
  setText(row.count, model.countText)
  if row.count and type(row.count.SetWidth) == "function" then
    row.count:SetWidth(Sidebar.countW or Sidebar.COUNT_W)
  end

  if model.icon and Assets and type(Assets.Has) == "function" and Assets.Has(model.icon) then
    pcall(Assets.Apply, row.icon, model.icon)
    row.icon:Show()
  else
    row.icon:Hide()
  end

  -- The cluster answers with the marks it actually drew, which is what the label is anchored
  -- to: a model naming a kind the cluster does not know leaves a box of no width behind.
  local badges = model.badges or EMPTY
  local drawn = badges
  if row.badges and type(row.badges.SetKinds) == "function" then
    drawn = row.badges:SetKinds(badges) or badges
  end

  -- The label is anchored on both sides, to the glyph on its left and to the badges or the
  -- count column on its right, so it takes whatever the row's own width leaves it and gives
  -- way with an ellipsis. No width is written here: a wider pane is simply a longer label.
  local anchor, gap = row.count, Sidebar.GUTTER
  if row.badges and #drawn > 0 then
    anchor, gap = row.badges, Sidebar.BadgeGap()
  end
  if row.label then
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.icon, "RIGHT", Sidebar.GUTTER, 0)
    if anchor then
      row.label:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    else
      row.label:SetPoint("RIGHT", row, "RIGHT", -Sidebar.GUTTER, 0)
    end
  end

  if model.selected then
    row.selectedWash:Show()
    row.selectedEdge:Show()
    colourText(row.label, "ITEMTREE_COLOR_TEXT_TITLE")
  else
    row.selectedWash:Hide()
    row.selectedEdge:Hide()
    colourText(row.label, "ITEMTREE_COLOR_TEXT_BODY")
  end
  onRowLeave(row)
  row:Show()
  return true
end

local function scrollAvailable()
  local scrollUtil = rawget(_G, "ScrollUtil")
  if type(rawget(_G, "CreateScrollBoxListLinearView")) ~= "function" then
    return false
  end
  if type(rawget(_G, "CreateDataProvider")) ~= "function" then
    return false
  end
  if type(scrollUtil) ~= "table" then
    return false
  end
  return type(scrollUtil.InitScrollBoxListWithScrollBar) == "function"
    or type(scrollUtil.InitScrollBoxList) == "function"
end

local function newLinearView()
  local create = rawget(_G, "CreateScrollBoxListLinearView")
  local ok, view = pcall(create)
  if not ok or type(view) ~= "table" then
    return nil
  end
  if type(view.SetElementExtent) == "function" then
    pcall(view.SetElementExtent, view, Sidebar.ROW_H)
  end
  if type(view.SetElementInitializer) ~= "function" then
    return nil
  end
  local initialised = pcall(view.SetElementInitializer, view, Sidebar.ROW_TEMPLATE, function(row, model)
    Sidebar.InitRow(row, model)
  end)
  if not initialised then
    return nil
  end
  return view
end

-- Lays the scroll box out inside its host, giving the width back when the bar is not drawn.
local function anchorScrollBox(withBar)
  local box, host = Sidebar.scrollBox, Sidebar.scrollHost
  if not (box and host and type(box.ClearAllPoints) == "function") then
    return false
  end
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", withBar and -Sidebar.SCROLLBAR_W or 0, 0)
  return true
end

local function buildScrollBox(parent)
  if not scrollAvailable() then
    return false
  end
  local box = newTemplatedFrame("Frame", parent, "WowScrollBoxList")
  if not box then
    return false
  end
  local bar = newTemplatedFrame("EventFrame", parent, "MinimalScrollBar")
    or newTemplatedFrame("Frame", parent, "MinimalScrollBar")
  local view = newLinearView()
  local scrollUtil = rawget(_G, "ScrollUtil")
  local ok = false
  if view and bar and type(scrollUtil.InitScrollBoxListWithScrollBar) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxListWithScrollBar, box, bar, view)
  elseif view and type(scrollUtil.InitScrollBoxList) == "function" then
    ok = pcall(scrollUtil.InitScrollBoxList, box, view)
  end
  if not ok then
    box:Hide()
    if bar then
      bar:Hide()
    end
    return false
  end

  Sidebar.scrollBox, Sidebar.scrollBar, Sidebar.view, Sidebar.scrollHost = box, bar, view, parent
  anchorScrollBox(false)
  if bar then
    bar:SetWidth(Sidebar.SCROLLBAR_W)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    -- Hidden until the rows say otherwise, so a short list never opens beside a full height
    -- bar. Refresh asks again on every draw.
    bar:Hide()
  end
  return true
end

-- What the client makes of a string in the row's own count face, or nil where it will not say.
-- A hidden font string measures exactly like a drawn one, and the font goes on before the text
-- every time, because the beta raises from inside SetText on a font string with no font.
local function measureText(text)
  local ruler = Sidebar.ruler
  if not ruler or type(ruler.GetStringWidth) ~= "function" then
    return nil
  end
  setText(ruler, text or "")
  local ok, width = pcall(ruler.GetStringWidth, ruler)
  if not ok or type(width) ~= "number" or width <= 0 then
    return nil
  end
  return math.ceil(width)
end

-- The count column for this draw, worked out once for the whole list so every row's badges sit
-- in one line down the pane whatever their own count reads.
local function measureCountColumn(rows)
  local widest = Sidebar.WidestCount(rows)
  Sidebar.countW = Sidebar.CountWidth(widest, size("ITEMTREE_FONTSIZE_BODY_SM", 11), measureText(widest))
  return Sidebar.countW
end

local function heightOf(frame)
  if type(frame) ~= "table" or type(frame.GetHeight) ~= "function" then
    return 0
  end
  local ok, height = pcall(frame.GetHeight, frame)
  return (ok and tonumber(height)) or 0
end

-- The bar is drawn only while the rows overflow the list, and the list takes the width back
-- when it goes. The frame pool has no bar of its own, so this is the scroll path's alone.
function Sidebar.UpdateScrollBar(rowCount)
  local bar = Sidebar.scrollBar
  if not bar then
    return false
  end
  local overflow = Sidebar.Overflows(rowCount, heightOf(Sidebar.scrollHost or Sidebar.list))
  if overflow then
    bar:Show()
  else
    bar:Hide()
  end
  anchorScrollBox(overflow)
  return overflow
end

-- Brief RO1 (the owner's QA item 280): a new data provider keeps the column where it is scrolled.
-- ScrollBoxListMixin:SetDataProvider(dataProvider, retainScrollPosition) goes back to the top of the
-- list unless the second argument is ScrollBoxConstants.RetainScrollPosition, which is true
-- (wow-ui-source branch `forever`, Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:17 and 703 to 713).
-- Every redraw came through here without it, so picking a level on a trainer's Teaches list put the
-- column back at All. The top of a fresh page and a page's remembered offset are Sidebar.Show's to set.
local RETAIN_SCROLL = true

local function drawScroll(rows)
  local box = Sidebar.scrollBox
  local create = rawget(_G, "CreateDataProvider")
  if not box or type(box.SetDataProvider) ~= "function" or type(create) ~= "function" then
    return false
  end
  local ok, provider = pcall(create, rows)
  if not ok or not provider then
    return false
  end
  return (pcall(box.SetDataProvider, box, provider, RETAIN_SCROLL))
end

local function poolRow(index)
  local row = Sidebar.pool[index]
  if row then
    return row
  end
  row = newFrame("Button", Sidebar.content)
  if not row then
    return nil
  end
  Sidebar.DecorateRow(row)
  local above = Sidebar.pool[index - 1]
  if above then
    row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
  else
    row:SetPoint("TOPLEFT", Sidebar.content, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", Sidebar.content, "TOPRIGHT", 0, 0)
  end
  Sidebar.pool[index] = row
  return row
end

local function drawPool(rows)
  if not Sidebar.content then
    return false
  end
  local drawn = 0
  for index, model in ipairs(rows) do
    local row = poolRow(index)
    if not row then
      break
    end
    Sidebar.InitRow(row, model)
    drawn = index
  end
  for index = drawn + 1, #Sidebar.pool do
    Sidebar.pool[index]:Hide()
  end
  return true
end

local function categoriesOf(vm)
  if type(vm) ~= "table" or type(vm.Categories) ~= "function" then
    return EMPTY
  end
  local ok, categories = pcall(vm.Categories, vm)
  if ok and type(categories) == "table" then
    return categories
  end
  return EMPTY
end

-- The view model owns the filter, so the highlight is read back off it through vm:Filter().
-- A view model that cannot answer leaves the sidebar's own remembered id in place, which is
-- what the click handler set.
local function filterOf(vm, remembered)
  if type(vm) == "table" and type(vm.Filter) == "function" then
    local ok, filter = pcall(vm.Filter, vm)
    if ok then
      return filter
    end
  end
  return remembered
end

-- ItemTree.UI.Frame is looked up at call time, because it loads before this file but is built
-- later, and a window that is still a stub must not break a click or a keystroke.
local function window()
  local frame = ItemTree.UI and ItemTree.UI.Frame
  return type(frame) == "table" and frame or nil
end

local function refreshWindow()
  local frame = window()
  if not frame or type(frame.Refresh) ~= "function" then
    return false
  end
  return (pcall(frame.Refresh))
end

-- The player's trade skills, from the window. Absent reads as no skills, and every profession
-- row then draws its plain label.
local function playerSkills()
  local frame = window()
  if not frame or type(frame.PlayerSkills) ~= "function" then
    return nil
  end
  local ok, skills = pcall(frame.PlayerSkills)
  if ok and type(skills) == "table" then
    return skills
  end
  return nil
end

-- A click. Sets the filter the row asks for, then hands the redraw to the window: the sidebar
-- draws no tree and does not redraw itself here, because Frame.Refresh comes back to Show.
function Sidebar.Select(rowModel)
  local vm = Sidebar.vm
  if type(vm) ~= "table" or type(vm.SetFilter) ~= "function" then
    return false
  end
  local filterId = Sidebar.Interpret(rowModel, Sidebar.selectedId)
  -- A row pick, which is what the client's own settings category list plays a small click for
  -- (Blizzard_Settings_Shared/Blizzard_CategoryList.lua:197 on the forever branch). Only the
  -- row click reaches here, so a redraw of the column says nothing.
  playCue("click")
  vm:SetFilter(filterId)
  Sidebar.selectedId = filterId
  refreshWindow()
  return true
end

-- A script on a frame the window created. HookScript is preferred so nothing the client
-- already put there stops working, and a frame that does not carry the script is left alone.
local function hookScript(frame, script, handler)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    -- Only an explicit no is taken as one: a client that answers nothing has not said the
    -- frame lacks the script, and HookScript is pcalled anyway.
    if ok and has == false then
      return false
    end
  end
  if type(frame.HookScript) == "function" and pcall(frame.HookScript, frame, script, handler) then
    return true
  end
  if type(frame.SetScript) == "function" then
    return (pcall(frame.SetScript, frame, script, handler))
  end
  return false
end

-- The window owns the pane's width and is free to change it, so a resize is a redraw: every
-- row reads its room from the region's own edges rather than from a number written here.
-- Hooked once per region, and nothing in Refresh resizes the region, so it cannot feed itself.
local function watchSize(region)
  if rawget(region, "itemTreeSidebarSized") then
    return false
  end
  local hooked = hookScript(region, "OnSizeChanged", function()
    if Sidebar.frame == region and Sidebar.vm then
      Sidebar.Refresh()
    end
  end)
  if hooked then
    region.itemTreeSidebarSized = true
  end
  return hooked
end

-- The design's InsetPanel at pad 0, filling the region: the inset fill, a 1px border, and a
-- content frame held inside the border so no row is drawn over it. The panel takes the whole
-- region, height and width, which is what the search box used to hold off the top of it.
local function buildListPanel(region)
  local panel = newFrame("Frame", region)
  if not panel then
    return nil, nil
  end
  panel:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
  panel:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
  panel:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
  panel:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
  panel.fill = wash(panel, "BACKGROUND", "ITEMTREE_COLOR_SURFACE_INSET")
  panel.fill:SetAllPoints(panel)
  panel.fill:Show()
  panel.border = insetBorder(panel, "ITEMTREE_COLOR_BORDER_GOLD_DIM")

  local content = newFrame("Frame", panel)
  if not content then
    return panel, panel
  end
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", Sidebar.EDGE_W, -Sidebar.EDGE_W)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -Sidebar.EDGE_W, Sidebar.EDGE_W)
  return panel, content
end

-- Takes the pane the window created and sized, and builds the list inside it once. Idempotent
-- for the same region; a different region rebuilds. Returns false with no client.
function Sidebar.Attach(region)
  if type(region) ~= "table" or type(rawget(_G, "CreateFrame")) ~= "function" then
    return false
  end
  if Sidebar.frame == region and Sidebar.mode then
    return true
  end
  Sidebar.frame = region
  Sidebar.pool = {}
  Sidebar.scrollBox, Sidebar.scrollBar, Sidebar.view, Sidebar.content = nil, nil, nil, nil
  Sidebar.scrollHost, Sidebar.countW = nil, nil
  Sidebar.listPanel, Sidebar.list = buildListPanel(region)
  -- A hidden font string in the row's own count face, which the column is measured with.
  Sidebar.ruler = newFontString(region, "OVERLAY")
  if Sidebar.ruler then
    styleText(Sidebar.ruler, size("ITEMTREE_FONTSIZE_BODY_SM", 11), "ITEMTREE_COLOR_TEXT_MUTED", "RIGHT")
    Sidebar.ruler:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    Sidebar.ruler:Hide()
  end
  local host = Sidebar.list or region
  if buildScrollBox(host) then
    Sidebar.mode = "scroll"
  else
    Sidebar.mode = "pool"
    Sidebar.content = host
  end
  watchSize(region)
  return true
end

-- Redraws from the last view model. Does not show the pane: Hide stays hidden until Show.
function Sidebar.Refresh()
  if not Sidebar.frame then
    return false
  end
  local vm = Sidebar.vm
  Sidebar.selectedId = filterOf(vm, Sidebar.selectedId)
  local rows = Sidebar.Rows(categoriesOf(vm), Sidebar.selectedId, { skills = playerSkills() })
  Sidebar.rows = rows
  measureCountColumn(rows)
  Sidebar.UpdateScrollBar(#rows)
  if Sidebar.mode == "scroll" then
    if drawScroll(rows) then
      return true
    end
    -- A client that took the ScrollBox but will not take a data provider falls back for good,
    -- rather than leaving the pane blank.
    Sidebar.mode = "pool"
    Sidebar.content = Sidebar.list or Sidebar.frame
    if Sidebar.scrollBox then
      Sidebar.scrollBox:Hide()
    end
    if Sidebar.scrollBar then
      Sidebar.scrollBar:Hide()
    end
  end
  return drawPool(rows)
end

-- How tall the column's own list is, and how much of it is on screen: the rows are one fixed
-- height each, so the whole of it is a multiplication. Mirrors ScrollBoxBaseMixin's derived
-- extent less its visible extent (wow-ui-source branch `forever`), which is the range a
-- percentage is a share of.
local function scrollRange()
  local total = #(Sidebar.rows or EMPTY) * Sidebar.ROW_H
  return math.max(0, total - heightOf(Sidebar.scrollHost or Sidebar.list))
end

--- Where the category column is scrolled to, in whole pixels from the top, or nil for a column
--- that does not scroll at all: the frame pool path has no offset of its own, and neither has a
--- list that fits. One number, which is all the window writes down about this pane (brief E61).
function Sidebar.ScrollOffset()
  local box = Sidebar.scrollBox
  if type(box) ~= "table" or type(box.GetDerivedScrollOffset) ~= "function" then
    return nil
  end
  local ok, value = pcall(box.GetDerivedScrollOffset, box)
  if not ok or not tonumber(value) then
    return nil
  end
  return math.max(0, math.floor(tonumber(value) + 0.5))
end

--- Puts it back, with no glide, after the rows are in the box. The share is worked out from the
--- column's own arithmetic rather than from the box's range, which is still the last page's
--- until the client lays the new list out; a column shorter than it was comes back at its end.
--- Answers whether the box took it.
function Sidebar.ScrollTo(offset)
  local box = Sidebar.scrollBox
  if type(box) ~= "table" then
    return false
  end
  local range = scrollRange()
  offset = math.max(0, math.min(range, tonumber(offset) or 0))
  if type(box.SetScrollPercentage) == "function" then
    local percent = 0
    if range > 0 then
      percent = offset / range
    end
    if pcall(box.SetScrollPercentage, box, percent, true) then
      return true
    end
  end
  if type(box.ScrollToOffset) == "function" then
    return (pcall(box.ScrollToOffset, box, offset, true))
  end
  return false
end

-- Every open, re-root and refresh. Re-reads vm:Categories() and redraws, keeping the selected
-- category highlighted while it still exists. Nothing here takes the keyboard: the pane has no
-- edit box of its own, so the window never opens with the keyboard captured.
--
-- state is the window's page notes (brief E61): nil on a plain refresh, which leaves the column
-- exactly where it is (brief RO1: a row picked is one, drawScroll keeps the box's scroll), { top =
-- true } on an arrival that starts fresh, and the remembered sidebarOffset on a return.
function Sidebar.Show(vm, state)
  if vm ~= nil then
    Sidebar.vm = vm
  end
  if not Sidebar.frame then
    return false
  end
  local drawn = Sidebar.Refresh()
  Sidebar.frame:Show()
  if type(state) == "table" then
    Sidebar.ScrollTo(state.sidebarOffset)
  end
  return drawn
end

function Sidebar.Hide()
  local frame = Sidebar.frame
  if not frame or type(frame.Hide) ~= "function" then
    return false
  end
  frame:Hide()
  return true
end

-- The window attaches the pane, so there is nothing to do at load.
function Sidebar.Init() end

return Sidebar
