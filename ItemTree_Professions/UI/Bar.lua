-- The Professions tab's rank bar (brief PR13): a strip across the top of the canvas, fixed while
-- the canvas pans and zooms, in the style of the client's own profession bar. It runs the whole
-- skill axis, 1 to 300:
--
--   filled   1 to the player's rank, in the profession's own fill art (flat colour where the
--            client will not draw it);
--   empty    the rank to the current cap (the max the player has trained to);
--   locked   the cap to 300, greyed, with a padlock: the tiers not yet trained.
--
-- On it: a tick at each tier's cap (Apprentice 75, Journeyman 150, Expert 225, Artisan 300) with
-- its name on hover, and a mark where a specialisation opens up, naming the choices on hover and
-- lit where the player holds one. Over it, one bordered tag at the player's rank says "Cooking
-- 16/75", with the specialisation; the bar carries no words of its own (brief PR16: one readout).
--
-- Brief PR16: the bar is the canvas's own axis. The pane hands Draw an axis, rank to x along the
-- strip, that is the canvas's columns at the pan and zoom in force (Layout.MarkerX), so the bar
-- pans and zooms with the bands under it, its rank is where the "you are here" line runs down the
-- canvas, and the tag sits at the top of that line with a short stem down through the bar.
--
-- The specialisation ranks (Bar.SPECIALISATIONS) are the Classic Era quest data's own skill
-- requirement for the quests that teach each one (quest_template RequiredSkillValue in the
-- classic-db cache the pipeline reads): Armorsmith and Weaponsmith 200 (quests 5283, 5284, 5301,
-- 5302), Dragonscale, Elemental and Tribal Leatherworking 225 (5141 to 5148), Gnomish and Goblin
-- Engineering 200 (3639, 3641, 3643). The weapon masteries (Hammersmith, Axesmith, Swordsmith) are
-- taught by no quest in that data and their rank is not held anywhere we read, so they carry no
-- mark of their own: the Weaponsmith mark names them on hover instead.
--
-- Everything above the "Client side" divider is pure and runs under busted with no WoW API.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Bar = {}
ItemTree.ProfessionsBar = Bar

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local EMPTY = {}

local themeSizes = ItemTree.ProfessionsKit.ThemeSizes

local SIZES = themeSizes()

Bar.FLOOR = 1
Bar.CAP = 300
Bar.HEIGHT = SIZES.ITEMTREE_PROFESSION_BAR_H or 18
Bar.TOP_H = SIZES.ITEMTREE_PROFESSION_TOP_H or 56
Bar.TAG_H = 20
-- Brief PR25: the strip has no frame now, only its dark fill (the pane draws it); the tag and the
-- bar stand 7 px in from its top and bottom in the 56 px strip (PR23's rail had 10).
Bar.TAG_Y = 7
Bar.BAR_Y = 31
Bar.INSET = 3
Bar.TICK_W = 1
Bar.HIT_W = 10
Bar.SPEC_W = 3
Bar.SPEC_OVER = 3
Bar.LOCK = 12
Bar.PAD = SIZES.ITEMTREE_SPACE_2 or 8
Bar.FONT = 11
Bar.CHAR_W = 6.2
Bar.HERE_W = SIZES.ITEMTREE_PROFESSION_HERE_W or 2
-- Brief PR23: the stem's glow to its left, as the canvas line's. Brief PR24: 60% of PR23's 32, and
-- none at HERE_GLOW_MIN_RANK or below (UI\Pane.lua's rule).
Bar.HERE_GLOW_W = SIZES.ITEMTREE_PROFESSION_HERE_GLOW_W or 19
Bar.HERE_GLOW_MIN_RANK = 5

-- The tiers, each named at the rank it caps.
Bar.TIERS = {
  { rank = 75, name = L["Apprentice"] },
  { rank = 150, name = L["Journeyman"] },
  { rank = 225, name = L["Expert"] },
  { rank = 300, name = L["Artisan"] },
}

-- Where each specialisation opens up, by skill line, the choices as spell ids of
-- Core/Skills.lua's SPECIALISATIONS (the names come from there). See the header for the source.
Bar.SPECIALISATIONS = {
  [164] = { { rank = 200, choices = { 9788, 9787 }, masteries = { 17040, 17041, 17039 } } },
  [165] = { { rank = 225, choices = { 10656, 10658, 10660 } } },
  [202] = { { rank = 200, choices = { 20219, 20222 } } },
}

Bar.WORDS = {
  rank = L["%s %d/%d"],
  withSpec = L["%s, %s"],
  cap = L["Skill cap %d"],
  specFrom = L["Specialisation from %d"],
  yours = L["Yours: %s"],
  masteries = L["A Weaponsmith later masters one of: %s"],
  locked = L["Train %s to go past %d"],
  lockedTop = L["Locked past %d"],
}

-- Theme keys.
Bar.EMPTY_COLOUR = "ITEMTREE_COLOR_PROFESSION_BAR_EMPTY"
Bar.LOCKED_COLOUR = "ITEMTREE_COLOR_PROFESSION_BAR_LOCKED"
-- Brief PR17: the padlock's pale gold, the cards' own.
Bar.LOCK_TINT = "ITEMTREE_COLOR_PROFESSION_LOCK_ICON"
Bar.TICK_COLOUR = "ITEMTREE_COLOR_PROFESSION_BAR_TICK"
Bar.SPEC_COLOUR = "ITEMTREE_COLOR_PROFESSION_BAR_SPEC"
Bar.SPEC_KNOWN_COLOUR = "ITEMTREE_COLOR_PROFESSION_BAR_SPEC_KNOWN"
Bar.TAG_FILL = "ITEMTREE_COLOR_PROFESSION_TAG_FILL"
Bar.HERE_COLOUR = "ITEMTREE_COLOR_PROFESSION_HERE"
-- Brief PR23: the stem is the canvas line's top, so it wears the same white core and left glow.
Bar.HERE_CORE = "ITEMTREE_COLOR_PROFESSION_HERE_CORE"
Bar.HERE_GLOW = "ITEMTREE_COLOR_PROFESSION_HERE_GLOW"
Bar.TAG_WORD = "ITEMTREE_COLOR_BAND_WORD"
Bar.BAR_WORD = "ITEMTREE_COLOR_TEXT_BODY"
Bar.EDGE_COLOUR = "ITEMTREE_COLOR_BORDER_GOLD_DIM"

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

local clamp = ItemTree.Util.Clamp

--- How far along the 1 to cap axis a rank sits, 0 to 1. Pure.
function Bar.Fraction(value, cap)
  cap = tonumber(cap) or Bar.CAP
  local span = cap - Bar.FLOOR
  if span <= 0 then
    return 0
  end
  return clamp(((tonumber(value) or 0) - Bar.FLOOR) / span, 0, 1)
end

--- A rank's x along a bar width wide. Pure.
function Bar.X(value, width, cap)
  return Bar.Fraction(value, cap) * (tonumber(width) or 0)
end

--- The bar's three stretches for a rank and a cap: filled 1 to rank, empty rank to max, locked
--- max to 300. locked is nil once the player has trained all the way. Pure.
function Bar.Segments(rank, max, cap)
  cap = tonumber(cap) or Bar.CAP
  rank = clamp(tonumber(rank) or 0, 0, cap)
  max = tonumber(max) or cap
  max = clamp(max, rank, cap)
  local out = {
    filled = { from = Bar.FLOOR, to = math.max(rank, Bar.FLOOR) },
    empty = { from = math.max(rank, Bar.FLOOR), to = math.max(max, Bar.FLOOR) },
  }
  if max < cap then
    out.locked = { from = max, to = cap }
  end
  return out
end

--- The tier ticks along a bar width wide: { rank, name, x }. axis(rank), where given, places
--- them instead of the straight 1 to cap scale. Pure.
function Bar.TierMarks(width, cap, axis)
  local out = {}
  for _, tier in ipairs(Bar.TIERS) do
    local x = type(axis) == "function" and axis(tier.rank) or Bar.X(tier.rank, width, cap)
    out[#out + 1] = { rank = tier.rank, name = tier.name, x = x }
  end
  return out
end

local function specName(spellId, specs)
  for _, entry in ipairs(specs or EMPTY) do
    if entry.id == spellId then
      return entry.name
    end
  end
  return nil
end

--- The specialisation marks for a line along a bar width wide: { rank, x, choices = { names },
--- masteries = { names }, known = the choice the player holds or nil }. specs is Core/Skills.lua's
--- SPECIALISATIONS table, known the names the player holds (Frame.PlayerSkills specialisations).
--- Pure.
function Bar.SpecMarks(line, known, width, specs, cap, axis)
  local held = {}
  for _, name in ipairs(type(known) == "table" and known or EMPTY) do
    held[name] = true
  end
  local lineSpecs = type(specs) == "table" and specs[tonumber(line)] or nil
  local out = {}
  for _, mark in ipairs(Bar.SPECIALISATIONS[tonumber(line)] or EMPTY) do
    local x = type(axis) == "function" and axis(mark.rank) or Bar.X(mark.rank, width, cap)
    local entry = { rank = mark.rank, x = x, choices = {}, masteries = {} }
    for _, id in ipairs(mark.choices) do
      local name = specName(id, lineSpecs)
      if name then
        entry.choices[#entry.choices + 1] = name
        if held[name] then
          entry.known = name
        end
      end
    end
    for _, id in ipairs(mark.masteries or EMPTY) do
      local name = specName(id, lineSpecs)
      if name then
        entry.masteries[#entry.masteries + 1] = name
        if held[name] then
          entry.mastery = name
        end
      end
    end
    out[#out + 1] = entry
  end
  return out
end

--- "Cooking 16/75", the client's own shape. Pure.
function Bar.RankText(name, rank, max)
  return string.format(Bar.WORDS.rank, tostring(name or ""), tonumber(rank) or 0, tonumber(max) or Bar.CAP)
end

--- The tag's words: the rank text, and the specialisation the player holds where there is one.
--- Pure.
function Bar.TagText(name, rank, max, spec)
  local text = Bar.RankText(name, rank, max)
  if type(spec) == "string" and spec ~= "" then
    return string.format(Bar.WORDS.withSpec, text, spec)
  end
  return text
end

--- The tier the next training opens, for a cap below 300: the first tier past max. Pure.
function Bar.NextTier(max)
  max = tonumber(max) or 0
  for _, tier in ipairs(Bar.TIERS) do
    if tier.rank > max then
      return tier
    end
  end
  return nil
end

--- The locked stretch's hover line. Pure.
function Bar.LockedText(max)
  local tier = Bar.NextTier(max)
  if tier then
    return string.format(Bar.WORDS.locked, tier.name, tonumber(max) or 0)
  end
  return string.format(Bar.WORDS.lockedTop, tonumber(max) or 0)
end

--- A rough width for a line of text at the bar's font size, where the client will not measure.
--- Pure.
function Bar.TextWidth(text)
  return math.floor(#tostring(text or "") * Bar.CHAR_W + 0.5)
end

--- The straight axis: a rank's x along a bar width wide, inside its inset. Pure.
function Bar.LinearAxis(width, cap)
  local inner = (tonumber(width) or 0) - Bar.INSET * 2
  return function(value)
    return Bar.INSET + Bar.X(value, inner, cap)
  end
end

--- The span the bar covers along the strip for an axis: from 1's x to the cap's, held inside
--- 0 to width (brief PR23: inside inset to width less inset, the strip's frame rail, where one is
--- given). nil where none of it shows. Pure.
function Bar.Span(axis, width, cap, inset)
  width = tonumber(width) or 0
  inset = math.max(tonumber(inset) or 0, 0)
  local from = tonumber(axis(Bar.FLOOR)) or 0
  local to = tonumber(axis(tonumber(cap) or Bar.CAP)) or 0
  local left, right = math.max(from - Bar.INSET, inset), math.min(to + Bar.INSET, width - inset)
  if right - left < Bar.INSET * 2 + 1 then
    return nil
  end
  return left, right
end

--- Where the tag sits: centred on the rank's x, kept inside 0 to width minus reserve (the zoom
--- controls' room at the right). Brief PR23: and no nearer the left edge than inset (the strip's
--- frame rail), where one is given. Pure.
function Bar.TagX(anchorX, tagW, width, reserve, inset)
  anchorX, tagW = tonumber(anchorX) or 0, tonumber(tagW) or 0
  local left = math.max(tonumber(inset) or 0, 0)
  local right = (tonumber(width) or 0) - (tonumber(reserve) or 0) - tagW
  local x = anchorX - tagW / 2
  if x > right then
    x = right
  end
  if x < left then
    x = left
  end
  return x
end

--- Brief PR23: the stem's glow rect, HERE_GLOW_W to the left of the stem and as tall, nothing to
--- its right; nil without a stem, and (brief PR24) nil at rank HERE_GLOW_MIN_RANK or below (an
--- unknown rank keeps it). Pure.
function Bar.StemGlow(stem, height, rank)
  if type(stem) ~= "table" then
    return nil
  end
  rank = tonumber(rank)
  if rank ~= nil and rank <= Bar.HERE_GLOW_MIN_RANK then
    return nil
  end
  local x, y = tonumber(stem.x) or 0, tonumber(stem.y) or 0
  return { x = x - Bar.HERE_GLOW_W, y = y, w = Bar.HERE_GLOW_W, h = math.max((tonumber(height) or 0) - y, 0) }
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local skin = ItemTree.ProfessionsKit.Skin
local assets = ItemTree.ProfessionsKit.Assets
local colourOf = ItemTree.ProfessionsKit.ColourOf

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

-- Brief PM1 (brief G1 reaching the Professions code): every script body set through setScript
-- runs under ItemTree.Guard.Run, the boundary main's panes use, so a fault in one is handed to the
-- client's error handler once and the rest of the tab keeps working. Only ItemTree's own handlers
-- on ItemTree's own frames are wrapped. raw sets the handler as it is: the hardware event craft
-- path (the Craft all button's click, the queue's press and pause) stays exactly as proven in game.
local guardScript = ItemTree.ProfessionsKit.GuardScript

local function setScript(frame, script, handler, raw)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if not (ok and has) then
      return false
    end
  end
  if not raw then
    handler = guardScript("Professions.Bar." .. tostring(script), handler)
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

local function applyAsset(texture, key)
  local a = assets()
  if not (a and texture and type(a.Has) == "function" and a.Has(key)) then
    return false
  end
  local ok, applied = pcall(a.Apply, texture, key)
  return ok and applied ~= false
end

local tint = ItemTree.ProfessionsKit.Tint
local newTexture = ItemTree.ProfessionsKit.NewTexture

local function wash(parent, layer, key, sub)
  local texture = newTexture(parent, layer, sub)
  if texture then
    applyAsset(texture, "FILL_WHITE8X8")
    tint(texture, key)
  end
  return texture
end

local FONT_FALLBACKS = { "GameFontHighlightSmall", "GameFontNormalSmall", "GameFontNormal" }

local function ensureFont(fontString)
  if type(fontString.GetFont) == "function" then
    local ok, face = pcall(fontString.GetFont, fontString)
    if ok and face ~= nil and face ~= "" then
      return true
    end
  end
  if type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(FONT_FALLBACKS) do
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

local function newText(parent, colourKey, justify, template)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY", template or "GameFontHighlightSmall")
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, "OVERLAY")
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  local theme = ItemTree.Theme
  local face = type(theme) == "table" and theme.fonts and theme.fonts.ITEMTREE_FONT_BODY
  if face and type(fontString.SetFont) == "function" then
    local set, applied = pcall(fontString.SetFont, fontString, face, Bar.FONT, "OUTLINE")
    if not set or applied == false then
      ensureFont(fontString)
    end
  end
  ensureFont(fontString)
  if type(fontString.SetJustifyH) == "function" then
    pcall(fontString.SetJustifyH, fontString, justify or "CENTER")
  end
  if type(fontString.SetWordWrap) == "function" then
    pcall(fontString.SetWordWrap, fontString, false)
  end
  local colour = colourOf(colourKey)
  if colour and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(colour.r, colour.g, colour.b, 1)
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

local function measure(fontString, text)
  if type(fontString) == "table" and type(fontString.GetStringWidth) == "function" then
    local ok, width = pcall(fontString.GetStringWidth, fontString)
    width = ok and tonumber(width) or nil
    if width and width > 0 then
      return width
    end
  end
  return Bar.TextWidth(text)
end

local function at(object, parent, x, y, w, h)
  object:ClearAllPoints()
  object:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  object:SetSize(math.max(w, 0.01), math.max(h, 0.01))
end

local hideTooltip = ItemTree.ProfessionsKit.HideTooltip

--- A small tooltip: a title and plain lines. Answers whether it drew.
function Bar.ShowTooltip(owner, title, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_BOTTOM")
  if type(tooltip.SetText) == "function" then
    pcall(tooltip.SetText, tooltip, title or "")
  elseif type(tooltip.AddLine) == "function" then
    pcall(tooltip.AddLine, tooltip, title or "")
  end
  for _, line in ipairs(lines or EMPTY) do
    if type(tooltip.AddLine) == "function" then
      pcall(tooltip.AddLine, tooltip, line, 1, 1, 1, true)
    end
  end
  if type(tooltip.Show) == "function" then
    pcall(tooltip.Show, tooltip)
  end
  return true
end

local function hitFrame(parent)
  local hit = newFrame("Frame", parent)
  if not hit then
    return nil
  end
  if type(hit.EnableMouse) == "function" then
    pcall(hit.EnableMouse, hit, true)
  end
  setScript(hit, "OnEnter", function(self)
    local tip = rawget(self, "tip")
    if tip then
      Bar.ShowTooltip(self, tip.title, tip.lines)
    end
  end)
  setScript(hit, "OnLeave", hideTooltip)
  return hit
end

--- Builds the strip on parent, once. Answers the strip frame, or nil.
function Bar.Build(parent)
  local strip = newFrame("Frame", parent)
  if not strip then
    return nil
  end
  strip:SetHeight(Bar.TOP_H)
  -- The bar itself, a frame of its own so its pieces sit on its own coordinates.
  local bar = newFrame("Frame", strip)
  strip.bar = bar
  if bar then
    bar.bgFlat = wash(bar, "BACKGROUND", Bar.EMPTY_COLOUR)
    bar.fill = newTexture(bar, "ARTWORK", 1)
    bar.locked = wash(bar, "ARTWORK", Bar.LOCKED_COLOUR, 2)
    bar.lock = newTexture(bar, "OVERLAY", 2)
    bar.edges = {}
    for index = 1, 4 do
      bar.edges[index] = wash(bar, "OVERLAY", Bar.EDGE_COLOUR, 1)
    end
    bar.text = newText(bar, Bar.BAR_WORD, "CENTER", "GameFontHighlightSmall")
    bar.ticks, bar.tickHits, bar.specs, bar.specHits = {}, {}, {}, {}
    bar.lockHit = hitFrame(bar)
  end
  -- The tag over the bar, at the player's rank, and its stem down through the bar to the canvas.
  local tag = newFrame("Frame", strip)
  strip.tag = tag
  if tag then
    tag.fill = wash(tag, "BACKGROUND", Bar.TAG_FILL)
    if tag.fill then
      tag.fill:SetAllPoints(tag)
    end
    tag.left = newTexture(tag, "BORDER")
    tag.middle = newTexture(tag, "BORDER")
    tag.right = newTexture(tag, "BORDER")
    tag.text = newText(tag, Bar.TAG_WORD, "CENTER", "GameFontNormalSmall")
  end
  local stemFrame = newFrame("Frame", strip)
  if stemFrame then
    if type(stemFrame.SetAllPoints) == "function" then
      stemFrame:SetAllPoints(strip)
    end
    if bar and type(stemFrame.SetFrameLevel) == "function" and type(bar.GetFrameLevel) == "function" then
      local ok, level = pcall(bar.GetFrameLevel, bar)
      if ok and tonumber(level) then
        pcall(stemFrame.SetFrameLevel, stemFrame, tonumber(level) + 2)
      end
    end
    strip.stem = wash(stemFrame, "OVERLAY", Bar.HERE_CORE, 5)
    -- Brief PR23: the canvas line's pale blue glow on the stem's left, fading out to the left.
    local glow = newTexture(stemFrame, "OVERLAY", 4)
    local s = skin()
    if glow and not (s and type(s.Glow) == "function" and s.Glow(glow, Bar.HERE_GLOW)) then
      glow:Hide()
      glow = nil
    end
    strip.stemGlow = glow
  end
  return strip
end

local function drawEdges(bar, w, h)
  local list = bar.edges
  if type(list) ~= "table" or #list < 4 then
    return
  end
  at(list[1], bar, 0, 0, w, 1)
  at(list[2], bar, 0, h - 1, w, 1)
  at(list[3], bar, 0, 0, 1, h)
  at(list[4], bar, w - 1, 0, 1, h)
  for _, edge in ipairs(list) do
    edge:Show()
  end
end

local function hideEdges(bar)
  for _, edge in ipairs(bar.edges or EMPTY) do
    edge:Hide()
  end
end

local function drawTag(strip, text, anchorX, width, reserve, inset)
  local tag = strip.tag
  if not tag then
    return
  end
  setText(tag.text, text)
  local tagW = math.floor(measure(tag.text, text) + 16 + 0.5)
  strip.tagW = tagW
  local x = Bar.TagX(anchorX, tagW, width, reserve, inset)
  strip.tagX = x
  at(tag, strip, x, Bar.TAG_Y, tagW, Bar.TAG_H)
  if tag.text then
    tag.text:ClearAllPoints()
    tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
  end
  -- The bevelled border the window's title row buttons wear (Assets INPUT_BORDER, three slices).
  local capW = 8
  local drawn = applyAsset(tag.left, "INPUT_BORDER_LEFT")
    and applyAsset(tag.middle, "INPUT_BORDER_MIDDLE")
    and applyAsset(tag.right, "INPUT_BORDER_RIGHT")
  for _, piece in ipairs({ tag.left, tag.middle, tag.right }) do
    if piece then
      if drawn then
        tint(piece, "ITEMTREE_COLOR_PROFESSION_CARD_GOLD")
        piece:Show()
      else
        piece:Hide()
      end
    end
  end
  if drawn then
    at(tag.left, tag, 0, 0, capW, Bar.TAG_H)
    at(tag.middle, tag, capW, 0, math.max(tagW - capW * 2, 1), Bar.TAG_H)
    at(tag.right, tag, tagW - capW, 0, capW, Bar.TAG_H)
  end
  tag:Show()
end

local function pooled(list, index, build)
  local object = list[index]
  if not object then
    object = build()
    list[index] = object
  end
  return object
end

local function hideFrom(list, from)
  for index = from, #list do
    if list[index] then
      list[index]:Hide()
    end
  end
end

--- Draws the strip for one line. args: { line, name, rank, max, known = { names }, width,
--- reserve (px kept clear at the right for the zoom controls), axis (rank to x along the strip,
--- the canvas's; the straight 1 to 300 scale where it is left out) }. Answers the drawn state for
--- the specs: { segments, fill = "art" or "flat", rankX, tagX, tagW, stem, ticks, specs, span }.
function Bar.Draw(strip, args)
  if type(strip) ~= "table" or type(args) ~= "table" then
    return nil
  end
  local width = math.max(tonumber(args.width) or 0, 1)
  local rank, max = tonumber(args.rank) or 0, tonumber(args.max) or Bar.CAP
  local axis = type(args.axis) == "function" and args.axis or Bar.LinearAxis(width)
  local s = skin()
  local bar = strip.bar
  local state = { segments = Bar.Segments(rank, max) }
  strip:SetWidth(width)
  local skills = ItemTree.Skills
  local specs = Bar.SpecMarks(
    args.line,
    args.known,
    width - Bar.INSET * 2,
    type(skills) == "table" and skills.SPECIALISATIONS or nil,
    nil,
    axis
  )
  local held = nil
  for _, mark in ipairs(specs) do
    held = mark.mastery or mark.known or held
  end
  state.specs = specs
  state.rankX = axis(math.max(rank, Bar.FLOOR))
  local inset = math.max(tonumber(args.inset) or 0, 0)
  local left, right = Bar.Span(axis, width, nil, inset)
  state.span = left and { left = left, right = right } or nil
  if bar and not left then
    bar:Hide()
  elseif bar then
    local h = Bar.HEIGHT
    local barW = right - left
    at(bar, strip, left, Bar.BAR_Y, barW, h)
    local innerH = h - Bar.INSET * 2
    -- A rank's x inside the bar, held to its inside.
    local function x(value)
      return clamp(axis(value) - left, Bar.INSET, barW - Bar.INSET)
    end
    local function inside(value)
      local px = axis(value) - left
      return px >= Bar.INSET and px <= barW - Bar.INSET
    end
    -- The background: the client's bar background cut in three, else the flat empty colour.
    local bgArt = s and s.ThreeSlice(bar, "PROFESSION_BAR_BG", 0, 0, barW, h, "bgPieces", "BACKGROUND", 1)
    if bar.bgFlat then
      at(bar.bgFlat, bar, 0, 0, barW, h)
      if bgArt then
        bar.bgFlat:Hide()
      else
        bar.bgFlat:Show()
      end
    end
    -- The filled stretch.
    local fillFrom, fillTo = x(state.segments.filled.from), x(state.segments.filled.to)
    local fillW = fillTo - fillFrom
    if rank < Bar.FLOOR then
      fillW = 0
    end
    if bar.fill then
      if fillW >= 1 then
        at(bar.fill, bar, fillFrom, Bar.INSET, fillW, innerH)
        local a = assets()
        local key = a and type(a.ForProfessionBar) == "function" and a.ForProfessionBar(args.line) or nil
        local drawn = key and s and s.Flipbook(bar.fill, key, fillW / math.max(barW - Bar.INSET * 2, 1))
        if drawn then
          state.fill = "art"
        else
          applyAsset(bar.fill, "FILL_WHITE8X8")
          local kit = a and a.professionBarKits and a.professionBarKits[tonumber(args.line)]
          local token = "ITEMTREE_COLOR_PROFESSION_BAR_" .. (kit and kit:upper() or "DEFAULT")
          if not tint(bar.fill, token) then
            tint(bar.fill, "ITEMTREE_COLOR_PROFESSION_BAR_DEFAULT")
          end
          state.fill = "flat"
        end
        bar.fill:Show()
      else
        bar.fill:Hide()
      end
    end
    -- The locked stretch past the cap, greyed, with the padlock in its middle.
    local locked = state.segments.locked
    local lockedLeft = locked and x(locked.from) or nil
    local lockedW = locked and (x(locked.to) - lockedLeft) or 0
    if locked and bar.locked and lockedW >= 1 then
      at(bar.locked, bar, lockedLeft, Bar.INSET, lockedW, innerH)
      bar.locked:Show()
      if bar.lock then
        if lockedW >= Bar.LOCK + 4 and applyAsset(bar.lock, "PROFESSION_LOCK") then
          at(bar.lock, bar, lockedLeft + (lockedW - Bar.LOCK) / 2, (h - Bar.LOCK) / 2, Bar.LOCK, Bar.LOCK)
          -- Brief PR17: the padlock lifted to a pale gold at full strength, so it stands out.
          if type(bar.lock.SetDesaturated) == "function" then
            pcall(bar.lock.SetDesaturated, bar.lock, true)
          end
          tint(bar.lock, Bar.LOCK_TINT)
          if type(bar.lock.SetAlpha) == "function" then
            pcall(bar.lock.SetAlpha, bar.lock, 1)
          end
          bar.lock:Show()
        else
          bar.lock:Hide()
        end
      end
      if bar.lockHit then
        at(bar.lockHit, bar, lockedLeft, 0, lockedW, h)
        bar.lockHit.tip = { title = Bar.LockedText(max), lines = {} }
        bar.lockHit:Show()
      end
      state.locked = { x = lockedLeft, w = lockedW }
    else
      if bar.locked then
        bar.locked:Hide()
      end
      if bar.lock then
        bar.lock:Hide()
      end
      if bar.lockHit then
        bar.lockHit:Hide()
      end
    end
    -- The frame over it all: the client's bar frame cut in three; brief PR19: else the tab's thin
    -- border (UI\Skin.lua Skin.Border, no face); else a hairline.
    local frameArt = s and s.ThreeSlice(bar, "PROFESSION_BAR_FRAME", 0, 0, barW, h, "framePieces", "OVERLAY", 0)
    local border = false
    if not frameArt and s and type(s.Border) == "function" then
      border = s.Border(bar, barW, h, { edge = Bar.EDGE_COLOUR, store = "bar", layer = "OVERLAY" })
    elseif s and type(s.HideBorder) == "function" then
      s.HideBorder(bar, "barBorder")
    end
    state.frame = frameArt and "art" or (border and "border" or "flat")
    if frameArt or border then
      hideEdges(bar)
    else
      drawEdges(bar, barW, h)
    end
    -- The tier ticks, each with a hover, where they fall on the bar.
    state.ticks = Bar.TierMarks(barW, nil, function(value)
      return axis(value) - left
    end)
    for index, mark in ipairs(state.ticks) do
      local tick = pooled(bar.ticks, index, function()
        return wash(bar, "OVERLAY", Bar.TICK_COLOUR, 3)
      end)
      local shown = mark.rank < Bar.CAP and inside(mark.rank)
      if tick then
        if shown then
          at(tick, bar, math.min(mark.x, barW - Bar.INSET - Bar.TICK_W), Bar.INSET, Bar.TICK_W, innerH)
          tick:Show()
        else
          tick:Hide()
        end
      end
      local hit = pooled(bar.tickHits, index, function()
        return hitFrame(bar)
      end)
      if hit then
        if inside(mark.rank) then
          at(hit, bar, math.min(mark.x - Bar.HIT_W / 2, barW - Bar.HIT_W), 0, Bar.HIT_W, h)
          hit.tip = { title = mark.name, lines = { string.format(Bar.WORDS.cap, mark.rank) } }
          hit:Show()
        else
          hit:Hide()
        end
      end
    end
    -- The specialisation marks: a gold notch standing proud of the bar, lit where it is held.
    for index, mark in ipairs(specs) do
      local notch = pooled(bar.specs, index, function()
        return wash(bar, "OVERLAY", Bar.SPEC_COLOUR, 4)
      end)
      local px = mark.x - left - Bar.SPEC_W / 2
      local shown = inside(mark.rank)
      if notch then
        if shown then
          at(notch, bar, px, -Bar.SPEC_OVER, Bar.SPEC_W, h + Bar.SPEC_OVER * 2)
          tint(notch, mark.known and Bar.SPEC_KNOWN_COLOUR or Bar.SPEC_COLOUR)
          notch:Show()
        else
          notch:Hide()
        end
      end
      local hit = pooled(bar.specHits, index, function()
        return hitFrame(bar)
      end)
      if hit then
        if shown then
          at(hit, bar, px - Bar.HIT_W / 2, -Bar.SPEC_OVER, Bar.HIT_W, h + Bar.SPEC_OVER * 2)
          local lines = { table.concat(mark.choices, ", ") }
          if #mark.masteries > 0 then
            lines[#lines + 1] = string.format(Bar.WORDS.masteries, table.concat(mark.masteries, ", "))
          end
          local yours = mark.mastery or mark.known
          if yours then
            lines[#lines + 1] = string.format(Bar.WORDS.yours, yours)
          end
          hit.tip = { title = string.format(Bar.WORDS.specFrom, mark.rank), lines = lines }
          hit:Show()
        else
          hit:Hide()
        end
      end
    end
    hideFrom(bar.specs, #specs + 1)
    hideFrom(bar.specHits, #specs + 1)
    -- Brief PR16: one readout, the tag; the bar's own centred words are gone.
    if bar.text then
      setText(bar.text, "")
      bar.text:Hide()
    end
    bar:Show()
  end
  -- Brief TP1: a caller's own words for the tag (a tracked profession's, UI\Track.lua Track.Tag).
  local tagText = type(args.tag) == "string" and args.tag ~= "" and args.tag or Bar.TagText(args.name, rank, max, held)
  drawTag(strip, tagText, state.rankX, width, args.reserve, inset)
  state.tagX, state.tagW = strip.tagX, strip.tagW
  -- The stem: from the tag's foot down through the bar to the canvas, where the tag stands over
  -- the rank (not pushed aside by the strip's edge or the controls) and the rank is on screen.
  local stem = strip.stem
  local overRank = state.tagX ~= nil
    and state.rankX >= state.tagX
    and state.rankX <= state.tagX + (state.tagW or 0)
    and state.rankX >= inset
    and state.rankX <= width - inset
  state.stem = overRank and { x = state.rankX - Bar.HERE_W / 2, y = Bar.TAG_Y + Bar.TAG_H } or nil
  if stem then
    if state.stem then
      at(stem, strip, state.stem.x, state.stem.y, Bar.HERE_W, Bar.TOP_H - state.stem.y)
      stem:Show()
    else
      stem:Hide()
    end
  end
  state.stemGlow = Bar.StemGlow(state.stem, Bar.TOP_H, rank)
  local glow = strip.stemGlow
  if glow then
    local rect = state.stemGlow
    if rect then
      at(glow, strip, rect.x, rect.y, rect.w, rect.h)
      glow:Show()
    else
      glow:Hide()
    end
  end
  strip:Show()
  return state
end

return Bar
