-- Confidence badges. Implements design components badges/Badge.jsx and badges/BadgeCluster.jsx.
--
-- Six kinds (New, Changed, Predicted, Community note, Unverified, Guess) draw the supplied medallion
-- art from Art/, which already carries its own ring and backing, so nothing is composed under
-- them. Removed reuses the Changed medallion desaturated under a red slash. Season of Discovery
-- draws its own medallion, the New one in the epic purple (Assets BADGE_ART_SOD), because it is
-- New with one more fact on it: the item came from Season of Discovery. Verified is composed
-- on the shared backing: a near black disc at 85 percent with a 1px ring in the semantic colour,
-- both drawn through the client's round portrait mask so no square corner shows (brief BG2),
-- then a tick in uncommon green at 0.7 scale. Where a client refuses the addon art (see
-- Art/README.md) every full medallion falls back to that same composed form using a client
-- texture, an atlas or a glyph, so the set is never blank: Unverified falls back to the bold "?"
-- in body cream it drew before the owner's medallion replaced it.
--
-- ItemTree's own art is trusted: it ships in the addon folder, so a client that will not draw
-- it says so, and the composed form is kept for the cases it does say so in. SetTexture
-- answering false or raising is one. A client texture reading back as nothing at all is the
-- other. Nothing else is: reading a medallion back and insisting on the file that was asked
-- for cost the window its medallions for a whole round, because the live clients answer
-- GetTexture with a file data id of their own, a differently cased or forward slashed path, a
-- path with the extension on it, or nothing at all until the file has streamed in, and every
-- one of those read as a failure. Any non nil read back is art. The texture is still emptied
-- before anything goes on it, so a pooled texture cannot show art left over from the last draw.
-- The cost of trusting our own art is that a build shipped without the Art folder draws blank
-- medallions rather than composed ones: that is a packaging fault, not a client difference, and
-- the .pkgmeta and Art/README.md are where it belongs.
--
-- A medallion is drawn one step up the badge size ladder from the frame it sits in (12 becomes
-- 14, 16 becomes 18), because it carries its own ring where the composed form draws a client
-- glyph at 0.7 inside one, so at the same pixel size the mark inside the medallion reads
-- smaller. The frame keeps its own Theme token, so no row and no cluster moves.
--
-- A badge shows its own tooltip on hover: what the mark means, and, for Changed on a subject a
-- caller named with :SetSubject(diffKind, id), one line per change out of Core/Diff. A badge
-- takes no mouse at all until it has a subject, so the bag overlay's badges stay as inert as
-- the button they sit over.
--
-- That tooltip is ItemTree's own frame rather than GameTooltip, because GameTooltip can neither
-- strike text through nor take our opacity, and a change wants both: the old value struck
-- through in the same grey the "Compared with Classic Era" line is drawn in, then the word
-- between the two sides, then the new value in body cream. One shared frame, at tooltip strata,
-- clamped to the screen, anchored off the badge's right edge and flipped to its left where the
-- right would take it off screen. A client that will not give us a frame at all falls back to
-- GameTooltip with the same lines written as one string each.
--
-- The composed form is the only badge that draws text, and its glyph is created from one of
-- the client's own font objects and given its font before a single character is written to it:
-- the beta raises "FontString:SetText(): Font not set" otherwise, from inside the C call, so
-- the whole list draw goes with it. Verified composes whenever the tick atlas is missing, and
-- Unverified composes wherever its medallion will not draw, which is the path a server side
-- category row took on the client that raised.
--
-- Everything above the frame side divider runs under busted and the browser harness with no
-- client at all; the one thing there that is not pure is Badges.LinesFor, which reads
-- ItemTree.Diff through the namespace, guarded. Frame creation is guarded too, so this file
-- loads with no WoW API present.
local _, ItemTree = ...

local Badges = {}
ItemTree.Badges = Badges

local Theme = ItemTree.Theme
local Assets = ItemTree.Assets
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Most urgent mark first, so it always wins the first slot in a cluster.
-- Season of Discovery sits beside New: Core/Diff.lua answers one or the other for an item, never
-- both, so the two never compete for a slot.
-- Brief GS3: a guess sits straight after Predicted, the tier it is drawn below.
Badges.PRIORITY = { "removed", "changed", "new", "sod", "note", "predicted", "guess", "unverified", "verified" }

local RANK = {}
for index, kind in ipairs(Badges.PRIORITY) do
  RANK[kind] = index
end

-- art: supplied medallion, drawn whole. fallbackArt: client texture used when the medallion
-- is missing, drawn on the composed backing. ring and tint are Theme colour keys. artTint names
-- an Assets vertex colour the medallion is drawn in, after desaturate has taken its own colour
-- off, which is how a medallion is recoloured without new art (Community note). artGradient names two Assets
-- colours, { top, bottom }, the medallion is shaded in from top to bottom instead.
Badges.META = {
  -- Brief A1: the New medallion is the owner's infinity mark, already in Forever's blue, so it
  -- is drawn as it is, with no desaturate and no vertex colour: greyed and tinted it came out far
  -- darker than the art. The fallback star and its ring still wear Assets BADGE_NEW_TINT, the
  -- silver blue, through ring, tint and their own Assets entries. Brief E82: it no longer pulses
  -- (the owner: it added nothing), so no badge animates.
  new = {
    label = L["New"],
    art = "BADGE_ART_NEW",
    full = true,
    fallbackArt = "BADGE_NEW",
    ring = "ITEMTREE_COLOR_SEMANTIC_NEW",
    tint = "ITEMTREE_COLOR_SEMANTIC_NEW",
  },
  -- New, for an item that came from Season of Discovery (Core/Diff.lua Diff.IsSod): the New
  -- medallion in the epic purple (Assets BADGE_ART_SOD, its own file, drawn as it is), at the
  -- same size. The owner ruled that this badge must not glow. It used to be the New medallion
  -- desaturated under a purple vertex colour, which multiplies the grey and came out darker
  -- than the tooltip's purple text. Where
  -- the medallion will not draw, the New star in that purple (Assets BADGE_SOD) on the composed
  -- backing with an epic ring.
  sod = {
    label = L["Season of Discovery"],
    art = "BADGE_ART_SOD",
    full = true,
    fallbackArt = "BADGE_SOD",
    ring = "ITEMTREE_COLOR_QUALITY_EPIC",
  },
  changed = {
    label = L["Changed"],
    art = "BADGE_ART_CHANGED",
    full = true,
    fallbackArt = "BADGE_CHANGED",
    ring = "ITEMTREE_COLOR_SEMANTIC_CHANGED",
    tint = "ITEMTREE_COLOR_SEMANTIC_CHANGED",
  },
  removed = {
    label = L["Removed"],
    art = "BADGE_ART_CHANGED",
    full = true,
    fallbackArt = "BADGE_CHANGED",
    ring = "ITEMTREE_COLOR_SEMANTIC_REMOVED",
    tint = "ITEMTREE_COLOR_SEMANTIC_REMOVED",
    desaturate = true,
    slash = true,
    slashArt = "FILL_WHITE8X8",
    slashColor = "ITEMTREE_COLOR_SEMANTIC_REMOVED",
  },
  -- Brief E80: the blue "i" greyed and drawn in a light silver (Assets BADGE_NOTE_TINT), so it
  -- no longer sits beside the new blue New, and stays lighter than the Unverified grey.
  note = {
    label = L["Community note"],
    art = "BADGE_ART_NOTE",
    full = true,
    desaturate = true,
    artTint = "BADGE_NOTE_TINT",
    fallbackArt = "BADGE_INFO",
    ring = "ITEMTREE_COLOR_SEMANTIC_NOTE",
    tint = "ITEMTREE_COLOR_SEMANTIC_NOTE",
  },
  -- Brief E80: the crystal ball shaded teal at the top to green at the bottom. The art is
  -- already teal, so it is not greyed first: the gradient only pushes each half its own way.
  predicted = {
    label = L["Predicted"],
    art = "BADGE_ART_PREDICTED",
    full = true,
    artGradient = { top = "BADGE_PREDICTED_TOP", bottom = "BADGE_PREDICTED_BOTTOM" },
    fallbackArt = "BADGE_PREDICTED",
    ring = "ITEMTREE_COLOR_SEMANTIC_PREDICTED",
    tint = "ITEMTREE_COLOR_SEMANTIC_PREDICTED",
  },
  -- Unverified draws the owner's question mark medallion, the fifth file in the family, and
  -- keeps the backing and the glyph it used to compose: those are now the fallback a client that
  -- will not draw the file gets, exactly as the other medallions fall back to a client texture.
  unverified = {
    label = L["Unverified"],
    art = "BADGE_ART_UNVERIFIED",
    full = true,
    backing = "BADGE_RING",
    glyph = "?",
    ring = "ITEMTREE_COLOR_SEMANTIC_UNVERIFIED",
    tint = "ITEMTREE_COLOR_TEXT_BODY",
    scale = 0.72,
  },
  verified = {
    label = L["Verified"],
    backing = "BADGE_RING",
    atlas = "ICON_CHECK",
    ring = "ITEMTREE_COLOR_QUALITY_UNCOMMON",
    tint = "ITEMTREE_COLOR_QUALITY_UNCOMMON",
    scale = 0.7,
  },
  -- Brief GS3: a source ItemTree's model guessed (Core/GuessSources.lua). Brief A3: it draws the
  -- owner's three dice in a ring in the guess rose (Assets BADGE_ART_GUESS), a full medallion
  -- like the rest of the family, drawn as it is. Where that will not draw it falls back to the
  -- composed form GS3 drew: the shared backing, its ring in the guess colour and a smaller ring
  -- of the same art inside it (Assets BADGE_GUESS, tinted Assets.BADGE_GUESS_TINT). Never the
  -- question mark, which is the undiscovered corner mark.
  guess = {
    label = L["Guess"],
    art = "BADGE_ART_GUESS",
    full = true,
    backing = "BADGE_RING",
    fallbackArt = "BADGE_GUESS",
    ring = "ITEMTREE_COLOR_SEMANTIC_GUESS",
    tint = "ITEMTREE_COLOR_SEMANTIC_GUESS",
    scale = 0.6,
  },
}

-- The near black disc every composed badge sits on.
Badges.BACKING_COLOR = "ITEMTREE_BADGE_BACKING"
Badges.BACKING_ART = "BADGE_RING"
-- Brief BG2: the round mask the composed backing and ring are drawn through, the client's own
-- portrait alpha mask (Assets PORTRAIT_MASK, the one the Boss loot tab masks its rare portraits
-- with). BADGE_RING's file is square, and the near black backing tinted onto it drew as a black
-- square with a thin grey edge behind the Verified tick; through the mask it is a round disc
-- inside the ring, the silhouette of the medallions beside it. A mask, never drawn itself.
Badges.MASK_KEY = "PORTRAIT_MASK"

-- The heading a hovered badge shows, one per kind. The first three are the owner's wording for
-- the beta, the same words UI/Tooltip.lua puts on an item's own tooltip, so a mark reads the
-- same wherever it is drawn.
Badges.TITLE = {
  new = L["New in Forever"],
  sod = L["Season of Discovery"],
  changed = L["Changed in Forever"],
  removed = L["Removed in Forever"],
  predicted = L["Predicted"],
  note = L["Community note"],
  unverified = L["Unverified"],
  verified = L["Verified"],
  guess = L["Guess"],
}

-- The line under the heading: what the mark means, in the wording the sidebar tooltips and the
-- Diff caption already use. Every kind carries one, because E48 made every mark its own hover
-- target and a mark that answers a hover with its own name alone has not explained itself:
-- Community note used to stop at its heading, and now says where the note came from. A note mark
-- on a row that carries its own note says that note instead (brief E93, Badges.TooltipLines).
Badges.MEANING = {
  new = L["Compared with Classic Era"],
  sod = L["New in Forever. This item came from Season of Discovery."],
  changed = L["Compared with Classic Era"],
  removed = L["Compared with Classic Era"],
  note = L["A note other players added about this item"],
  predicted = L["Predicted data, not yet confirmed"],
  unverified = L["Imported baseline, unverified"],
  verified = L["Verified by the collector"],
  guess = L["ItemTree's best guess, not yet seen in the game."],
}

-- The meaning line for a mark whose fact is not the kind the line above describes, by the basis
-- the fact carries (Core/Confidence.lua BASIS_*).
--
-- Every predicted fact the addon shipped until now came out of the disenchant bands, so one
-- line covered them all. The shipped Classic Era source table is a prediction of a different
-- kind: it is not worked out from item level and quality, it is what another game used to do.
-- A basis with nothing here, and a mark carrying no basis at all, keeps the line above, so a
-- predicted disenchant row says exactly what it has always said.
Badges.MEANING_BY_BASIS = {
  predicted = {
    era = L["Taken from Classic Era, not yet seen in Forever"],
    -- Brief BQ15 (QA 2026-10-10 item 2): a reward of a quest the Forever client lists. The quest is
    -- real; the client's tables carry no rewards, so the reward is Classic Era's until a turn in
    -- records it (UI/Tree.lua BadgeBasis).
    erareward = L["Classic Era reward, not yet seen in Forever"],
  },
  -- Brief QB2: a Classic Era reward the quest no longer hands over in Forever, by the client's quest
  -- cache (UI/Tree.lua BadgeBasis).
  changed = {
    rewardchanged = L["Classic Era reward, no longer handed over in Forever"],
  },
}

-- The heading a hovered mark draws. A kind the TITLE table has no row for falls back to its own
-- label, so a kind added to META without a heading still names itself rather than answering a
-- hover with nothing at all. nil only for something that is not a badge kind.
function Badges.Title(kind)
  local title = Badges.TITLE[kind]
  if type(title) == "string" and title ~= "" then
    return title
  end
  return Badges.Label(kind)
end

-- What a mark means, for a mark standing on a fact with a basis. The one place that choice is
-- made, so the hovered badge, the list tooltip and the harness all read the same words.
function Badges.Meaning(kind, basis)
  local byBasis = type(basis) == "string" and Badges.MEANING_BY_BASIS[kind] or nil
  local meaning = byBasis and byBasis[basis] or nil
  if meaning then
    return meaning
  end
  return Badges.MEANING[kind]
end

-- The same facts as one line each, for a list tooltip that names every mark on a row rather
-- than hovering one (UI/Sidebar.lua). There is no heading to hang a meaning under there, so a
-- diff mark takes its heading, which says which mark it is, and a confidence mark the sentence
-- that explains it. This is the one place those words live; the sidebar keeps a copy only as a
-- fallback for a client where this file did not load.
Badges.LIST_MEANING = {
  new = Badges.TITLE.new,
  changed = Badges.TITLE.changed,
  removed = Badges.TITLE.removed,
  note = Badges.MEANING.note,
  predicted = Badges.MEANING.predicted,
  unverified = Badges.MEANING.unverified,
  verified = Badges.MEANING.verified,
  guess = Badges.MEANING.guess,
}

-- Tooltip colours. Removed is the one heading that is not title gold, the same way
-- UI/Tooltip.lua colours its status line, because Removed shares the Changed medallion.
local COLOR_TITLE = "ITEMTREE_COLOR_TEXT_TITLE"
local COLOR_MUTED = "ITEMTREE_COLOR_TEXT_MUTED"
local COLOR_BODY = "ITEMTREE_COLOR_TEXT_BODY"
local TITLE_COLOR = { removed = "ITEMTREE_COLOR_SEMANTIC_REMOVED" }

-- A change reads as the old value struck through, the word between the two sides, and the new
-- value in body cream. The old value, the label ahead of it and that word are all the one grey,
-- the same the line that says what the mark means has always been drawn in: it was the disabled
-- grey until this round, and the owner could not read it at tooltip size.
local COLOR_OLD = COLOR_MUTED
local COLOR_NEW = COLOR_BODY

-- How many changes a hovered Changed badge lists before it counts the rest.
Badges.MAX_CHANGE_LINES = 12

-- The Diff kinds a subject can be named with, and the node kinds that map onto them, so a
-- caller holding a view model node can hand over node.kind and be understood.
Badges.DIFF_KINDS = { "items", "recipes", "enchants", "skills" }

local DIFF_KIND = { item = "items", spell = "recipes", enchant = "enchants", skill = "skills" }
for _, kind in ipairs(Badges.DIFF_KINDS) do
  DIFF_KIND[kind] = kind
end

-- The Diff kind for "items", or for a node kind like "item". nil for anything else.
function Badges.DiffKind(kind)
  if type(kind) ~= "string" then
    return nil
  end
  return DIFF_KIND[kind]
end

-- Badge sizes by context, from Theme.sizes.
local SIZE_KEYS = {
  list = "ITEMTREE_BADGE_SIZE_LIST",
  tooltip = "ITEMTREE_BADGE_SIZE_TOOLTIP",
  tree = "ITEMTREE_BADGE_SIZE_TREE",
  slot = "ITEMTREE_BADGE_SIZE_SLOT",
}

Badges.CONTEXTS = { "list", "tooltip", "tree", "slot" }

-- The badge sizes the Theme names, smallest first: the ladder a medallion steps up, and the
-- ladder's own step for a size past the top of it.
local SIZE_LADDER = {}
for _, context in ipairs(Badges.CONTEXTS) do
  local size = Theme.sizes[SIZE_KEYS[context]]
  if size then
    SIZE_LADDER[#SIZE_LADDER + 1] = size
  end
end
table.sort(SIZE_LADDER)
Badges.SIZE_LADDER = SIZE_LADDER
Badges.SIZE_STEP = 2

-- 3px between badges everywhere except bag slots, which stack at 1px down the right edge.
Badges.GAP_DEFAULT = 3
Badges.GAP_SLOT = 1

-- The client font objects a glyph is created from, in the order they are tried. The template
-- goes to CreateFontString so the glyph has a font the moment it exists, and the rest are what
-- a client that would not take the template is offered instead.
Badges.FONT_TEMPLATE = "GameFontNormalSmall"
Badges.FONT_FALLBACKS = { "GameFontNormalSmall", "GameFontNormal", "GameFontHighlightSmall" }

function Badges.IsKind(kind)
  return Badges.META[kind] ~= nil
end

function Badges.Label(kind)
  local meta = Badges.META[kind]
  return meta and meta.label or nil
end

function Badges.Rank(kind)
  return RANK[kind] or (#Badges.PRIORITY + 1)
end

-- Sorted by priority, de-duplicated, truncated to max (default 3). Unknown kinds are dropped.
function Badges.Sort(kinds, max)
  local out = {}
  if type(kinds) ~= "table" then
    return out
  end
  local seen = {}
  for _, kind in ipairs(kinds) do
    if Badges.META[kind] and not seen[kind] then
      seen[kind] = true
      out[#out + 1] = kind
    end
  end
  table.sort(out, function(a, b)
    return RANK[a] < RANK[b]
  end)
  if max and max >= 0 and #out > max then
    for index = #out, max + 1, -1 do
      out[index] = nil
    end
  end
  return out
end

-- Pixel size for a context: list 12, tooltip 14, tree 16, slot 18. A number passes through.
function Badges.SizeFor(context)
  if type(context) == "number" then
    return context
  end
  local key = SIZE_KEYS[context or "list"] or SIZE_KEYS.list
  return Theme.sizes[key]
end

-- The pixel size a supplied medallion is drawn at inside a badge this size: one step up the
-- badge size ladder, 12 to 14 and 16 to 18. The medallion carries its own ring, where the
-- composed badge draws a client glyph at 0.7 inside one, so the same pixel size leaves the
-- medallion's mark reading smaller. The badge frame itself stays on its own token.
--
-- Brief ST1 (QA item 279): a badge smaller than the ladder's first rung (the bag badges, sized by
-- the Bag badge size slider) used to step up to that rung, so every bag medallion drew 12 px
-- whatever the slider said below 0.65 ("i think i have it on smallest setting but its still quite
-- big"). Below the first rung the medallion is a third bigger than its badge, which is the 12 px
-- the default 9 px bag badge has always drawn, never past the first rung and always at least a
-- pixel bigger than the badge: 4 px draws 5, 5 draws 7, 9 draws 12, 10 and 11 draw 12.
Badges.SMALL_ART_RATIO = 4 / 3

function Badges.ArtSize(size)
  local pixels = tonumber(size) or Badges.SizeFor("list")
  local floor = SIZE_LADDER[1]
  if floor and pixels < floor then
    local art = math.floor(pixels * Badges.SMALL_ART_RATIO + 0.5)
    return math.max(pixels + 1, math.min(art, floor))
  end
  for _, step in ipairs(SIZE_LADDER) do
    if step > pixels then
      return step
    end
  end
  return pixels + Badges.SIZE_STEP
end

-- The air a medallion is allowed above and below the text it sits beside, so a badge in a row
-- never stands taller than the row's own words.
Badges.TEXT_HEADROOM = 4

-- The badge size to draw beside text this tall: the largest on the ladder whose medallion,
-- which is drawn a step up that ladder, still fits inside the text height plus that air. The
-- footer legend and the sidebar ask for this rather than naming a size, so a medallion drawn
-- whole and a composed one both sit on the text's centre line at the same height.
function Badges.SizeForText(textHeight)
  local height = tonumber(textHeight)
  local smallest = SIZE_LADDER[1] or Badges.SizeFor("list")
  if not height or height <= 0 then
    return smallest
  end
  local room = height + Badges.TEXT_HEADROOM
  local best = nil
  for _, step in ipairs(SIZE_LADDER) do
    if Badges.ArtSize(step) <= room then
      best = step
    end
  end
  return best or smallest
end

-- Whether art that ships with ItemTree is what a key names. Our own files sit in the addon
-- folder, the client opens them the way it opens any file it is handed, and there is no second
-- opinion to be had about them: nothing is read back off a texture they went on. Assets is a
-- pure table, so this needs no client.
function Badges.IsOwnArt(key)
  if type(Assets) ~= "table" or type(Assets.Has) ~= "function" or not Assets.Has(key) then
    return false
  end
  local ok, entry = pcall(Assets.Get, key)
  if not ok or type(entry) ~= "table" then
    return false
  end
  return entry.kind == "addon"
end

-- Whether what a texture reads back counts as art that landed. The clients answer GetTexture
-- with whatever they stored, and what that is differs by client and by file: the path in either
-- case and with either slash, the path with the extension on it, or a file data id of the
-- client's own. None of those can be checked against the file that was asked for without
-- rejecting art that really is there, so any non nil answer is art. Nothing at all, and the
-- false a client answers where it is explicit about it, are the only failures.
function Badges.TextureLoaded(readBack)
  if readBack == nil or readBack == false then
    return false
  end
  if readBack == "" then
    return false
  end
  return true
end

-- Gap for a context or an explicit pixel size. Bag slot badges sit 1px apart.
function Badges.GapFor(context)
  if context == "slot" then
    return Badges.GAP_SLOT
  end
  if type(context) == "number" and context >= Theme.sizes.ITEMTREE_BADGE_SIZE_SLOT then
    return Badges.GAP_SLOT
  end
  return Badges.GAP_DEFAULT
end

-- Cluster box for count badges of this size. direction is "row" or "column".
function Badges.ClusterExtent(count, size, gap, direction)
  count = count or 0
  size = size or Badges.SizeFor("list")
  gap = gap or Badges.GAP_DEFAULT
  if count <= 0 then
    return 0, 0
  end
  local run = count * size + (count - 1) * gap
  if direction == "column" then
    return size, run
  end
  return run, size
end

-- Every Assets key this module can draw, sorted. The harness missing-asset report and the
-- specs use it to prove Badges never names an asset that Assets does not carry.
function Badges.AssetKeys()
  local seen = { [Badges.BACKING_ART] = true, [Badges.MASK_KEY] = true }
  for _, meta in pairs(Badges.META) do
    for _, field in ipairs({ "art", "fallbackArt", "backing", "atlas", "slashArt" }) do
      if meta[field] then
        seen[meta[field]] = true
      end
    end
  end
  local keys = {}
  for key in pairs(seen) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- Every Theme colour key this module can use, sorted.
function Badges.ColorKeys()
  local seen = { [Badges.BACKING_COLOR] = true }
  for _, meta in pairs(Badges.META) do
    for _, field in ipairs({ "ring", "tint", "slashColor" }) do
      if meta[field] then
        seen[meta[field]] = true
      end
    end
  end
  local keys = {}
  for key in pairs(seen) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- A colour escape around text, or the plain text where Theme cannot colour it. Theme.Hex
-- raises on a key it has no row for, and nothing that draws a tooltip may raise.
local function colourise(colorKey, text)
  if type(Theme) ~= "table" or type(Theme.Colorise) ~= "function" then
    return text
  end
  local ok, coloured = pcall(Theme.Colorise, colorKey, text)
  if ok and type(coloured) == "string" then
    return coloured
  end
  return text
end

-- The sentence an added or removed entry is written as. Core splits a list field into one line
-- per entry and says which of the three each one is; the word at the end of these is what a
-- tooltip row puts after the value, so the value can be struck through without the word being
-- struck with it.
Badges.OP_TEXT = {
  added = L["%s added"],
  removed = L["%s removed"],
}

-- The markers a format string is filled with to find the words it puts around its values. Two
-- control characters, because nothing a locale writes can contain them.
local MARK_ONE, MARK_TWO = "\1", "\2"

local function trim(text)
  if type(text) ~= "string" then
    return nil
  end
  local trimmed = text:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end
  return trimmed
end

-- The word between the two sides of a change, taken out of the one sentence the whole addon
-- writes a change with, so a locale that translates "%s to %s" translates this too and no
-- second key has to carry a bare preposition. A locale that reorders the two sides has nothing
-- between them to find, and the English word stands in.
function Badges.ChangeJoiner()
  local ok, filled = pcall(string.format, L["%s to %s"], MARK_ONE, MARK_TWO)
  if ok then
    local between = trim(type(filled) == "string" and filled:match(MARK_ONE .. "(.-)" .. MARK_TWO) or nil)
    if between then
      return between
    end
  end
  return "to"
end

-- The word an added or removed entry ends with, out of the same sentence, for the same reason.
-- nil for a change that is neither.
function Badges.OpWord(op)
  local pattern = Badges.OP_TEXT[op]
  if type(pattern) ~= "string" then
    return nil
  end
  local ok, filled = pcall(string.format, pattern, MARK_ONE)
  if not ok or type(filled) ~= "string" then
    return nil
  end
  return trim(filled:match(MARK_ONE .. "(.*)$"))
end

-- Which of the three things a change line says. Core hangs an `op` of "added", "removed" or
-- "changed" on a line it split out of a list field, with the side that does not exist left nil.
-- A line from before that carries no op at all, so the sides it does carry answer for it: one
-- side alone is an entry that came or went, and two is a value that moved.
function Badges.ChangeOp(change)
  if type(change) ~= "table" then
    return nil
  end
  local op = change.op
  if op == "added" or op == "removed" or op == "changed" then
    return op
  end
  local hasOld = type(change.oldText) == "string" and change.oldText ~= ""
  local hasNew = type(change.newText) == "string" and change.newText ~= ""
  if hasOld and not hasNew then
    return "removed"
  end
  if hasNew and not hasOld then
    return "added"
  end
  return "changed"
end

-- One change out of Diff.ChangeLines as the pieces a tooltip row draws, left to right. A piece
-- is { text, colorKey, strike }: strike is the old value, which the frame draws a hairline
-- across at the string's own width, because the frame API has no strike through (the same
-- idiom UI/InfoPanel.lua draws its change rows with). Returns the pieces and the op they were
-- built for. nil for anything that is not a change, or a change with nothing to say.
function Badges.ChangeParts(change)
  if type(change) ~= "table" then
    return nil
  end
  local op = Badges.ChangeOp(change)
  local label = change.label or change.field
  if type(label) ~= "string" or label == "" then
    -- A value that moved always reads as something changing, even where nothing named the
    -- field; an entry that came or went says so in its own words and needs no such stand in.
    label = nil
    if op == "changed" then
      label = Badges.Label("changed") or "Changed"
    end
  end
  local old, new = nil, nil
  if op ~= "added" and type(change.oldText) == "string" and change.oldText ~= "" then
    old = change.oldText
  end
  if op ~= "removed" and type(change.newText) == "string" and change.newText ~= "" then
    new = change.newText
  end

  local parts = {}
  if label then
    parts[#parts + 1] = { text = label, colorKey = COLOR_MUTED }
  end
  if old then
    parts[#parts + 1] = { text = old, colorKey = COLOR_OLD, strike = true }
  end
  if old and new then
    parts[#parts + 1] = { text = Badges.ChangeJoiner(), colorKey = COLOR_MUTED }
  end
  if new then
    parts[#parts + 1] = { text = new, colorKey = COLOR_NEW }
  end
  local word = Badges.OpWord(op)
  if word and (old or new) then
    parts[#parts + 1] = { text = word, colorKey = COLOR_MUTED }
  end
  if #parts == 0 then
    return nil
  end
  return parts, op
end

-- The pieces as one string: what a client tooltip is handed where this file could not make a
-- frame of its own, and what a spec, the harness and anything reading a row as words takes.
local function joinParts(parts, coloured)
  local words = {}
  for _, part in ipairs(parts) do
    if coloured then
      words[#words + 1] = colourise(part.colorKey, part.text)
    else
      words[#words + 1] = part.text
    end
  end
  return table.concat(words, " ")
end

-- One change as a tooltip line. Returns the text the client draws, escapes and all, the same
-- words with nothing in them, and the pieces the frame draws. nil for anything that is not a
-- change.
function Badges.ChangeLine(change)
  local parts, op = Badges.ChangeParts(change)
  if not parts then
    return nil
  end
  return joinParts(parts, true), joinParts(parts, false), parts, op
end

-- One line of a tooltip that is a single run of words: the heading, what the mark means, and
-- the line that counts the changes there was no room for. It carries the same parts list a
-- change line does, holding the one piece, so the frame draws every line the same way, and that
-- piece wraps where a change line's pieces flow.
local function plainLine(text, colorKey, title)
  local part = { text = text, colorKey = colorKey, wrap = true }
  return { text = text, label = text, colorKey = colorKey, title = title, parts = { part } }
end

-- The whole tooltip for a badge, as lines: the heading, what the mark means, and, for Changed,
-- one line per change. changes is what Diff.ChangeLines answered for the badge's subject and is
-- ignored for every other kind. Each line is { text, label, colorKey, parts }: text is what a
-- client tooltip is handed, escapes and all, label the same words with no markup, which is what
-- a spec, the harness and anything reading the block as words takes, and parts the pieces our
-- own frame draws. The heading also carries title = true. max caps the change lines, default
-- Badges.MAX_CHANGE_LINES, and the rest are counted.
--
-- basis is what the fact under the mark is based on, where the mark stands on a fact that has
-- one (Core/Confidence.lua BASIS_*): it only ever changes the meaning line, and a caller with
-- none in hand gets the line the badge has always carried.
--
-- note is the row's own note, for a Community note mark on a row that carries one (brief E93,
-- UI/Tree.lua BadgeNote): a list of strings, the note's sentence where the data has one and the
-- line naming its pages last. Those lines stand in place of the generic meaning, and a note mark
-- handed none, or any other kind, keeps the meaning.
function Badges.TooltipLines(kind, changes, max, basis, note)
  local lines = {}
  local title = Badges.Title(kind)
  if title == nil then
    return lines
  end
  lines[#lines + 1] = plainLine(title, TITLE_COLOR[kind] or COLOR_TITLE, true)
  local own = kind == "note" and Badges.NoteLines(note) or nil
  if own then
    for _, text in ipairs(own) do
      lines[#lines + 1] = plainLine(text, COLOR_MUTED)
    end
  else
    local meaning = Badges.Meaning(kind, basis)
    if meaning then
      lines[#lines + 1] = plainLine(meaning, COLOR_MUTED)
    end
  end
  if kind ~= "changed" or type(changes) ~= "table" then
    return lines
  end
  local built = {}
  for _, change in ipairs(changes) do
    local text, label, parts, op = Badges.ChangeLine(change)
    if text then
      built[#built + 1] = { text = text, label = label, colorKey = COLOR_BODY, parts = parts, op = op }
    end
  end
  local cap = tonumber(max) or Badges.MAX_CHANGE_LINES
  if cap < 0 then
    cap = 0
  end
  for index = 1, math.min(#built, cap) do
    lines[#lines + 1] = built[index]
  end
  local rest = #built - cap
  if rest > 0 then
    lines[#lines + 1] = plainLine(string.format(L["and %d more"], rest), COLOR_MUTED)
  end
  -- Where the changes came from, said once under them, for a change the Discovery Miner's harvest
  -- produced rather than two builds (brief D3). Core owns the words for each source tag.
  local source = nil
  for _, change in ipairs(changes) do
    if type(change) == "table" and type(change.source) == "string" then
      source = change.source
      break
    end
  end
  local Diff = ItemTree.Diff
  if source and type(Diff) == "table" and type(Diff.SourceText) == "function" then
    local ok, text = pcall(Diff.SourceText, source)
    if ok and type(text) == "string" and text ~= "" then
      lines[#lines + 1] = plainLine(text, COLOR_MUTED)
    end
  end
  return lines
end

-- The lines of a row's own note that are words, in order, or nil where there are none, so a
-- note mark handed an empty list or a list of blanks still says what it means. Pure.
function Badges.NoteLines(note)
  if type(note) ~= "table" then
    return nil
  end
  local out = {}
  for _, text in ipairs(note) do
    if type(text) == "string" and text ~= "" then
      out[#out + 1] = text
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Whether a mark of this kind has words to answer a hover with: a heading, and a line under it
-- saying what the mark means. E48 makes every mark its own hover target wherever it is drawn,
-- and a target that shows nothing is worse than none at all, because it takes the row's own
-- tooltip away and puts nothing in its place. A kind that cannot explain itself is therefore
-- never given the mouse, and the spec holds every kind in META to this. Pure.
function Badges.Explains(kind)
  return #Badges.TooltipLines(kind) >= 2
end

-- Where a row's pieces go inside a tooltip this wide. They are placed left to right, and a
-- piece that will not fit the line it is on starts the next one, so a long change wraps inside
-- the tooltip rather than widening it. A piece wider than the whole row takes as many lines as
-- it needs on its own. Pure: the measured widths in, one { line, x, width, lines } per piece
-- out, with the line count and the width the widest line actually used. gap is the space
-- between two pieces sharing a line.
function Badges.FlowRow(widths, width, gap)
  gap = math.max(tonumber(gap) or 0, 0)
  width = math.max(tonumber(width) or 0, 0)
  local places, line, cursor, used = {}, 1, 0, 0
  for index, raw in ipairs(widths or {}) do
    local piece = math.max(tonumber(raw) or 0, 0)
    local x = cursor
    if x > 0 then
      x = x + gap
    end
    if width > 0 and x > 0 and x + piece > width then
      line, x = line + 1, 0
    end
    local spans = 1
    if width > 0 and piece > width then
      spans = math.ceil(piece / width)
      piece = width
    end
    places[index] = { line = line, x = x, width = piece, lines = spans }
    if x + piece > used then
      used = x + piece
    end
    if spans > 1 then
      -- A piece that filled the row leaves nothing beside it, so the next one starts a line.
      line, cursor = line + spans - 1, width
    else
      cursor = x + piece
    end
  end
  return places, line, used
end

-- Which side of the badge the tooltip sits on: its right, the way GameTooltip's ANCHOR_RIGHT
-- does, unless the tooltip would run off the right of the screen and there is room on the left.
-- Where neither side fits, the right is kept and the frame's own clamp takes it from there.
-- Pure: the badge's edges, the tooltip width and the screen width in, "RIGHT" or "LEFT" out.
function Badges.TooltipSide(badgeLeft, badgeRight, width, screenWidth, gap)
  local left = tonumber(badgeLeft) or 0
  local right = tonumber(badgeRight) or 0
  local wide = math.max(tonumber(width) or 0, 0)
  local screen = tonumber(screenWidth) or 0
  gap = math.max(tonumber(gap) or 0, 0)
  if screen <= 0 then
    return "RIGHT"
  end
  if right + gap + wide <= screen then
    return "RIGHT"
  end
  if left - gap - wide >= 0 then
    return "LEFT"
  end
  return "RIGHT"
end

-- The lines for a badge of this kind sitting on this subject. ItemTree.Diff is read here rather
-- than captured at load, so this file still loads on its own under busted and a spec can put a
-- different module under it; a Diff that is absent or raises costs the change lines and nothing
-- else. No client API, so this is as testable as the rest of the file above the divider.
function Badges.LinesFor(kind, diffKind, id, basis, note)
  local changes = nil
  local subject, subjectId = Badges.DiffKind(diffKind), tonumber(id)
  if kind == "changed" and subject and subjectId then
    local Diff = ItemTree.Diff
    if type(Diff) == "table" and type(Diff.ChangeLines) == "function" then
      local ok, answered = pcall(Diff.ChangeLines, subject, subjectId)
      if ok and type(answered) == "table" then
        changes = answered
      end
    end
  end
  return Badges.TooltipLines(kind, changes, nil, basis, note)
end

--------------------------------------------------------------------------------
-- Frame side. Everything below needs the client (or the harness shim).
--------------------------------------------------------------------------------

-- One CreateFrame call, pcall'd, the same idiom as UI/InfoPanel.lua: a client that does not
-- carry the template still gets its frame without the art, and a client with no CreateFrame at
-- all gets nothing, which is what leaves Badges.Create answering nil under busted.
local function createFrame(kind, name, parent, template)
  local fn = rawget(_G, "CreateFrame")
  if type(fn) ~= "function" then
    return nil
  end
  if template then
    local ok, frame = pcall(fn, kind, name, parent, template)
    if ok and type(frame) == "table" then
      return frame
    end
  end
  local ok, frame = pcall(fn, kind, name, parent)
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- One client call on a widget, type checked and pcall'd, the way UI/Overlay.lua does it. A
-- method this widget does not carry and one that raises both read as nothing.
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

-- Brief TX6: true while the client is in combat lockdown. A client (or the test harness) with no
-- InCombatLockdown, or one that raises, answers not in combat.
local function inCombat()
  local lockdown = rawget(_G, "InCombatLockdown")
  if type(lockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(lockdown)
  return (ok and locked) and true or false
end

-- Brief TX6: SetPropagateMouseClicks is refused in combat, whatever frame it is called on, and the
-- client blames ItemTree (the owner saw it on a quest's title badge, 2026-10-04). A badge given
-- hover in combat waits here, weakly held, and is handed the call once on PLAYER_REGEN_ENABLED.
local propagatePending = setmetatable({}, { __mode = "k" })
Badges.afterCombatBooked = false

-- PLAYER_REGEN_ENABLED: every waiting frame takes the call it missed, once, and the booking
-- clears. A frame booked with a still wanted check takes it only where the check still answers
-- true (a hover badge only while its hover is on). Answers how many took it.
function Badges.OnCombatEnd()
  Badges.afterCombatBooked = false
  local done = 0
  for frame, wanted in pairs(propagatePending) do
    propagatePending[frame] = nil
    local still = wanted == true
    if type(wanted) == "function" then
      local ok, answer = pcall(wanted, frame)
      still = ok and answer and true or false
    end
    if still then
      call(frame, "SetPropagateMouseClicks", true)
      done = done + 1
    end
  end
  return done
end

--- Clicks on one of OUR frames pass to the frame under it: SetPropagateMouseClicks(true) now out
--- of combat, and once on PLAYER_REGEN_ENABLED in combat, where the client refuses it on any frame
--- (the API documentation marks it protected with restrictions; brief NC1 saw it blocked from the
--- info panel's Keep mark, 2026-10-04). stillWanted, when given, is asked at the end of combat
--- and the call is skipped where it answers false. The end of combat is booked once, however
--- many frames wait for it. True when the call was made now, false when it waits.
function Badges.PropagateClicks(frame, stillWanted)
  if type(frame) ~= "table" then
    return false
  end
  if not inCombat() then
    call(frame, "SetPropagateMouseClicks", true)
    return true
  end
  propagatePending[frame] = type(stillWanted) == "function" and stillWanted or true
  Badges.afterCombatBooked = true
  return false
end

--- The end of combat watcher: one unparented frame of our own, made when this file loads (never
--- lazily in combat, which the gamepad UI punishes), watching PLAYER_REGEN_ENABLED for the calls
--- PropagateClicks booked. Once; a later call answers the frame already made. nil with no client.
function Badges.InstallCombatFrame()
  if Badges.combatFrame then
    return Badges.combatFrame
  end
  local made = createFrame("Frame")
  if not made then
    return nil
  end
  Badges.combatFrame = made
  call(made, "RegisterEvent", "PLAYER_REGEN_ENABLED")
  call(made, "SetScript", "OnEvent", function()
    Badges.OnCombatEnd()
  end)
  return made
end

Badges.InstallCombatFrame()

-- A hover badge takes its waiting call only while its hover is still on.
local function hoverStillOn(frame)
  return frame.hoverEnabled and true or false
end

-- Art left on a texture from the last draw would answer for art that never loaded, so the
-- texture is emptied before anything is put on it. The tex coords go back with it: a rect
-- narrowed for one asset must not crop the next.
local function clearTexture(texture)
  call(texture, "SetTexture", nil)
  call(texture, "SetTexCoord", 0, 1, 0, 1)
end

-- Applies an asset and reports whether the art landed, which is what decides between the
-- medallion and the composed form.
--
-- The only failures counted are the ones a client is explicit about: SetTexture or SetAtlas
-- answering false, Assets.Apply raising, and a client texture reading back as nothing at all.
-- ItemTree's own art is never read back, because the live clients answer GetTexture for it with
-- a file data id of their own, a path in another case or with another slash, a path with the
-- extension on it, or nothing at all until the file has streamed in, and a read back that
-- insisted on the file asked for took the medallions off the window for a round. An atlas is
-- read back by name, which is the one accessor whose answer means what it says, and a client
-- carrying neither accessor is left with the answer the setter gave.
local function applyArt(texture, key)
  if type(texture) ~= "table" or not Assets.Has(key) then
    return false
  end
  local entry = Assets.Get(key)
  clearTexture(texture)
  local ok, applied = pcall(Assets.Apply, texture, key)
  if not ok or applied == false then
    return false
  end
  if entry.kind == "atlas" then
    if type(texture.GetAtlas) ~= "function" then
      return true
    end
    local atlas = call(texture, "GetAtlas")
    return type(atlas) == "string" and atlas ~= ""
  end
  if Badges.IsOwnArt(key) or type(texture.GetTexture) ~= "function" then
    return true
  end
  return Badges.TextureLoaded(call(texture, "GetTexture"))
end

local function tint(texture, colorKey, alpha)
  local color = Theme.colors[colorKey]
  if not color then
    return
  end
  texture:SetVertexColor(color.r, color.g, color.b)
  texture:SetAlpha(alpha or color.a or 1)
end

-- Hands the glyph one of the client's own font objects. Nothing here can raise, and a client
-- carrying none of them answers false, which is as far as this file can go.
local function fallbackFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
    return false
  end
  for _, name in ipairs(Badges.FONT_FALLBACKS) do
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
-- through the template argument where the client takes one and by hand where it does not.
local function newFontString(parent, layer)
  if type(parent) ~= "table" or type(parent.CreateFontString) ~= "function" then
    return nil
  end
  local ok, fontString = pcall(parent.CreateFontString, parent, nil, layer, Badges.FONT_TEMPLATE)
  if not ok or type(fontString) ~= "table" then
    ok, fontString = pcall(parent.CreateFontString, parent, nil, layer)
  end
  if not ok or type(fontString) ~= "table" then
    return nil
  end
  ensureFont(fontString)
  return fontString
end

-- The Theme face at the size asked for, over the font the string was created with. SetFont
-- answers false rather than raising where the client cannot load the face, so the answer is
-- read and a font object put back: no font string here may ever end up with no font at all.
local function setFace(fontString, size)
  if type(fontString) ~= "table" then
    return false
  end
  local fonts = Theme and Theme.fonts
  local face
  if fonts then
    face = fonts.ITEMTREE_FONT_BODY
  end
  if face and type(fontString.SetFont) == "function" then
    local ok, applied = pcall(fontString.SetFont, fontString, face, size, "")
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
  return true
end

-- The font goes on before the text, always. This is the call the beta raised from: SetText on
-- a font string that had never been given a font, run by the ScrollBox inside its element
-- initialiser, where the error crosses a C boundary and takes the whole draw with it.
local function setGlyph(frame, text, size)
  local fontString = frame.glyph
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  setFace(fontString, size)
  return (pcall(fontString.SetText, fontString, text or ""))
end

-- A ColorMixin colour for SetGradient, or nil where the client has no CreateColor.
local function colourObject(colour)
  local create = rawget(_G, "CreateColor")
  if type(create) ~= "function" then
    return nil
  end
  local ok, object = pcall(create, colour.r, colour.g, colour.b, colour.a or 1)
  if ok and object ~= nil then
    return object
  end
  return nil
end

-- A vertical shade on a texture, bottom colour to top colour, the shape UI/QuestFlags.lua
-- PaintGradient has: the modern SetGradient with two ColorMixin colours, then the old
-- SetGradientAlpha, each under pcall, then a flat SetVertexColor in the top colour where
-- neither takes. Answers which took: "modern", "alpha", "flat" or false.
function Badges.PaintGradient(texture, bottom, top)
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
      bottom.a or 1,
      top.r,
      top.g,
      top.b,
      top.a or 1
    )
    if ok then
      return "alpha"
    end
  end
  if type(texture.SetVertexColor) == "function" and pcall(texture.SetVertexColor, texture, top.r, top.g, top.b) then
    return "flat"
  end
  return false
end

local WHITE = { r = 1, g = 1, b = 1, a = 1 }

-- Brief BG2: the round mask (Badges.MASK_KEY) as a MaskTexture over the badge's own box, made
-- once per badge and put on the backing and the ring, so the composed form is a dark disc in a
-- round ring at every size. A MaskTexture masks whatever its textures show and outlives every
-- SetTexture, so a pooled badge redrawn as another kind keeps it. Each step is type checked and
-- pcall'd: a client that cannot make, load or add a mask keeps the square backing it drew
-- before, and the badge reads roundBacking false. Answers the mask, or nil.
local function newRoundMask(frame, textures)
  if type(frame) ~= "table" or type(frame.CreateMaskTexture) ~= "function" then
    return nil
  end
  if not Assets or type(Assets.Has) ~= "function" or not Assets.Has(Badges.MASK_KEY) then
    return nil
  end
  local found, entry = pcall(Assets.Get, Badges.MASK_KEY)
  if not found or type(entry) ~= "table" or type(entry.path) ~= "string" then
    return nil
  end
  local ok, mask = pcall(frame.CreateMaskTexture, frame)
  if not ok or type(mask) ~= "table" or type(mask.SetTexture) ~= "function" then
    return nil
  end
  local wrap = "CLAMPTOBLACKADDITIVE"
  local loaded, answer = pcall(mask.SetTexture, mask, entry.path, wrap, wrap)
  if not loaded or answer == false then
    return nil
  end
  if type(mask.SetAllPoints) == "function" then
    pcall(mask.SetAllPoints, mask, frame)
  end
  local added = 0
  for _, texture in ipairs(textures) do
    if type(texture) == "table" and type(texture.AddMaskTexture) == "function" then
      if pcall(texture.AddMaskTexture, texture, mask) then
        added = added + 1
      end
    end
  end
  if added == 0 then
    return nil
  end
  return mask
end

local function clearBadge(frame)
  frame.backing:Hide()
  frame.ring:Hide()
  frame.art:Hide()
  frame.slash:Hide()
  if frame.glyph then
    frame.glyph:Hide()
  end
  if frame.art.SetDesaturated then
    frame.art:SetDesaturated(false)
  end
  -- A gradient left by Predicted is painted back to white by the same route that drew it, and
  -- the vertex colour below then covers whatever a route could not undo. SetGradient and
  -- SetVertexColor both write the four corner colours, so either one alone clears the other.
  if frame.art.gradientRoute then
    if frame.art.gradientRoute ~= "flat" then
      Badges.PaintGradient(frame.art, WHITE, WHITE)
    end
    frame.art.gradientRoute = nil
  end
  frame.art:SetVertexColor(1, 1, 1, 1)
  frame.art:SetAlpha(1)
  frame:SetAlpha(1)
end

local function showComposed(frame, meta, size)
  frame.backing:Show()
  applyArt(frame.backing, meta.backing or Badges.BACKING_ART)
  tint(frame.backing, Badges.BACKING_COLOR)
  frame.ring:Show()
  applyArt(frame.ring, meta.backing or Badges.BACKING_ART)
  tint(frame.ring, meta.ring, 1)
  local inner = math.floor(size * (meta.scale or 0.7) + 0.5)
  local points = math.max(6, inner)
  if meta.glyph then
    if setGlyph(frame, meta.glyph, points) then
      local color = Theme.colors[meta.tint]
      if color and type(frame.glyph.SetTextColor) == "function" then
        frame.glyph:SetTextColor(color.r, color.g, color.b, color.a)
      end
      frame.glyph:Show()
    end
  elseif meta.atlas then
    frame.art:SetSize(inner, inner)
    if applyArt(frame.art, meta.atlas) then
      tint(frame.art, meta.tint, 1)
      frame.art:Show()
    elseif setGlyph(frame, meta.glyph or "+", points) then
      frame.glyph:Show()
    end
  elseif meta.fallbackArt then
    frame.art:SetSize(inner, inner)
    if applyArt(frame.art, meta.fallbackArt) then
      tint(frame.art, meta.tint, 1)
      frame.art:Show()
    end
  end
end

--------------------------------------------------------------------------------
-- The hover tooltip
--------------------------------------------------------------------------------

-- How wide a tooltip is allowed to grow before a row wraps inside it. The design has no token
-- for it: it is what two stat changes side by side measure at the body size, and past it a
-- change list starts reading as a wall rather than a list.
Badges.TOOLTIP_MAX_WIDTH = 320

-- The owner asked for a background a little more solid than the Theme's tooltip surface, which
-- is 0.90. Theme carries no token between that and the opaque one, so the number lives here.
Badges.TOOLTIP_ALPHA = 0.95

local TOOLTIP_PAD = Theme.sizes.ITEMTREE_PAD_TIGHT or 8
local TOOLTIP_GAP = Theme.sizes.ITEMTREE_SPACE_1 or 4
local TOOLTIP_OFFSET = Theme.sizes.ITEMTREE_SPACE_1 or 4
local HAIRLINE = Theme.sizes.ITEMTREE_BORDER_HAIRLINE or 1
local FONT_TITLE = Theme.fontSizes.ITEMTREE_FONTSIZE_TITLE_SM or 14
local FONT_BODY = Theme.fontSizes.ITEMTREE_FONTSIZE_BODY_SM or 11

local function lineHeight(points)
  local factor = (Theme.lineHeights and Theme.lineHeights.ITEMTREE_LINEHEIGHT_ROW) or 1.15
  return math.floor(points * factor + 0.5)
end

local LINE_TITLE = lineHeight(FONT_TITLE)
local LINE_BODY = lineHeight(FONT_BODY)

local function themeColor(colorKey)
  local colors = type(Theme) == "table" and Theme.colors or nil
  if not colors then
    return nil
  end
  return colors[colorKey]
end

-- A measurement the client has, or 0, the way UI/InfoPanel.lua reads one: the layout falls back
-- to its own numbers rather than raising where a widget will not say.
local function measure(object, getter)
  if type(object) ~= "table" or type(object[getter]) ~= "function" then
    return 0
  end
  local ok, value = pcall(object[getter], object)
  return (ok and tonumber(value)) or 0
end

local function assetPath(key)
  if type(Assets) ~= "table" or type(Assets.Has) ~= "function" or not Assets.Has(key) then
    return nil
  end
  local ok, entry = pcall(Assets.Get, key)
  if not ok or type(entry) ~= "table" then
    return nil
  end
  return entry.path
end

-- A flat fill in a Theme colour. SetColorTexture is the modern call; a client without it paints
-- the white 8x8 through Assets, so no path is named here either.
local function fillTexture(texture, colorKey, alpha)
  local colour = themeColor(colorKey)
  if type(texture) ~= "table" or not colour then
    return false
  end
  local a = alpha or colour.a or 1
  if type(texture.SetColorTexture) == "function" then
    return (pcall(texture.SetColorTexture, texture, colour.r, colour.g, colour.b, a))
  end
  if not applyArt(texture, "FILL_WHITE8X8") then
    return false
  end
  call(texture, "SetVertexColor", colour.r, colour.g, colour.b, a)
  return true
end

-- The client's own tooltip border and background, at the opacity the owner asked for. A client
-- with no BackdropTemplate still gets a readable panel: a flat fill in the Theme's tooltip
-- surface, with no border on it.
local function applyTooltipBackdrop(frame)
  local surface = themeColor("ITEMTREE_COLOR_SURFACE_TOOLTIP")
  local r, g, b = 0, 0, 0
  if surface then
    r, g, b = surface.r, surface.g, surface.b
  end
  if type(frame.SetBackdrop) == "function" then
    local ok = pcall(frame.SetBackdrop, frame, {
      bgFile = assetPath("TOOLTIP_BACKGROUND"),
      edgeFile = assetPath("TOOLTIP_BORDER"),
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    if ok then
      call(frame, "SetBackdropColor", r, g, b, Badges.TOOLTIP_ALPHA)
      return "backdrop"
    end
  end
  local fill = call(frame, "CreateTexture", nil, "BACKGROUND")
  if type(fill) ~= "table" then
    return nil
  end
  fillTexture(fill, "ITEMTREE_COLOR_SURFACE_TOOLTIP", Badges.TOOLTIP_ALPHA)
  call(fill, "SetAllPoints", frame)
  frame.fill = fill
  return "fill"
end

-- The one shared tooltip frame. false once a client has refused us one, so the refusal is not
-- paid for on every hover.
local shared = nil

local function buildTooltip()
  local frame = createFrame("Frame", nil, rawget(_G, "UIParent"), "BackdropTemplate")
  if not frame then
    return nil
  end
  frame.rows = {}
  call(frame, "SetFrameStrata", "TOOLTIP")
  call(frame, "SetClampedToScreen", true)
  -- The tooltip never takes the mouse: it sits beside the badge the pointer is still on.
  call(frame, "EnableMouse", false)
  call(frame, "SetSize", Badges.TOOLTIP_MAX_WIDTH, LINE_BODY)
  frame.panel = applyTooltipBackdrop(frame)
  call(frame, "Hide")
  return frame
end

local function tooltipFrame()
  if shared == nil then
    shared = buildTooltip() or false
  end
  if shared == false then
    return nil
  end
  return shared
end

-- The shared frame, for a caller that wants to look at it (the specs do). nil where the client
-- would not give us one.
function Badges.TooltipFrame()
  return tooltipFrame()
end

-- One row of the tooltip: the font strings its pieces are written into and the hairline that
-- strikes the old value through. Rows and pieces are pooled, so a long change list hovered once
-- costs its font strings once.
local function tooltipRow(frame, index)
  local row = frame.rows[index]
  if not row then
    row = { parts = {} }
    frame.rows[index] = row
  end
  return row
end

local function rowPart(frame, row, index)
  local part = row.parts[index]
  if not part then
    part = newFontString(frame, "OVERLAY")
    if part then
      call(part, "SetJustifyH", "LEFT")
      row.parts[index] = part
    end
  end
  return part
end

-- One hairline per line the struck value takes: a value long enough to wrap is struck through
-- on every line of itself, not just the first.
local function rowStrike(frame, row, index)
  row.strikes = row.strikes or {}
  local strike = row.strikes[index]
  if strike == nil then
    strike = call(frame, "CreateTexture", nil, "OVERLAY")
    if type(strike) ~= "table" then
      strike = false
    else
      call(strike, "SetHeight", HAIRLINE)
    end
    row.strikes[index] = strike
  end
  if strike == false then
    return nil
  end
  return strike
end

-- Every word this tooltip draws goes through here: the font goes on before the text, always,
-- and the write is pcall'd, so a client that can leave a font string with no font at all costs
-- the hover a blank piece rather than the whole draw.
local function writePart(fontString, text, colorKey, points)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end
  setFace(fontString, points)
  if not (pcall(fontString.SetText, fontString, text or "")) then
    return false
  end
  local colour = themeColor(colorKey)
  if colour then
    call(fontString, "SetTextColor", colour.r, colour.g, colour.b, colour.a or 1)
  end
  return true
end

local EMPTY_ROW = {}

local function hideParts(row, from)
  for index = from, #row.parts do
    call(row.parts[index], "Hide")
  end
end

local function hideStrikes(row, from)
  for index = from, #(row.strikes or EMPTY_ROW) do
    if type(row.strikes[index]) == "table" then
      call(row.strikes[index], "Hide")
    end
  end
end

-- Draws the lines into the frame and answers the size it needs. Two passes over each row: every
-- piece is written and measured first, because what the client makes of a string is the only
-- honest width, and then Badges.FlowRow places them. A piece that wrapped is given the row's
-- width and word wrap, and the client is asked how tall it came out.
local function drawTooltip(frame, lines)
  local content = Badges.TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2
  local top, used = 0, 0
  for index, line in ipairs(lines) do
    local row = tooltipRow(frame, index)
    local points = line.title and FONT_TITLE or FONT_BODY
    local height = line.title and LINE_TITLE or LINE_BODY
    local parts = line.parts or { { text = line.text, colorKey = line.colorKey, wrap = true } }
    local widths, strings = {}, {}
    for pieceIndex, piece in ipairs(parts) do
      local fontString = rowPart(frame, row, pieceIndex)
      strings[pieceIndex] = fontString
      widths[pieceIndex] = 0
      if fontString and writePart(fontString, piece.text, piece.colorKey, points) then
        call(fontString, "SetWordWrap", piece.wrap and true or false)
        call(fontString, "SetWidth", 0)
        widths[pieceIndex] = measure(fontString, "GetStringWidth")
      end
    end

    local places, count = Badges.FlowRow(widths, content, TOOLTIP_GAP)
    local bottom, struck = count * height, 0
    for pieceIndex, piece in ipairs(parts) do
      local fontString, place = strings[pieceIndex], places[pieceIndex]
      if fontString and place then
        local offset = (place.line - 1) * height
        local tall = height
        if place.lines > 1 then
          call(fontString, "SetWordWrap", true)
          call(fontString, "SetWidth", place.width)
          tall = math.max(measure(fontString, "GetStringHeight"), place.lines * height)
        end
        call(fontString, "ClearAllPoints")
        call(fontString, "SetPoint", "TOPLEFT", frame, "TOPLEFT", TOOLTIP_PAD + place.x, -(TOOLTIP_PAD + top + offset))
        call(fontString, "Show")
        if offset + tall > bottom then
          bottom = offset + tall
        end
        if place.x + place.width > used then
          used = place.x + place.width
        end
        -- The frame API has no strike through, so these hairlines are it: the old value's own
        -- string width, at mid height, in the colour the old value is written in. The same
        -- idiom UI/InfoPanel.lua draws its change rows with, one line of it at a time.
        if piece.strike and widths[pieceIndex] > 0 then
          for lineIndex = 1, place.lines do
            local strike = rowStrike(frame, row, struck + 1)
            if not strike then
              break
            end
            call(strike, "ClearAllPoints")
            call(strike, "SetWidth", math.min(widths[pieceIndex] - (lineIndex - 1) * place.width, place.width))
            call(strike, "SetHeight", HAIRLINE)
            fillTexture(strike, piece.colorKey)
            if place.lines == 1 then
              -- Anchoring the hairline's left edge to the string's left edge centres it
              -- vertically, which is where a strike through belongs.
              call(strike, "SetPoint", "LEFT", fontString, "LEFT", 0, 0)
            else
              local middle = math.floor(height / 2) + (lineIndex - 1) * height
              call(strike, "SetPoint", "TOPLEFT", fontString, "TOPLEFT", 0, -middle)
            end
            call(strike, "Show")
            struck = struck + 1
          end
        end
      end
    end
    hideStrikes(row, struck + 1)
    hideParts(row, #parts + 1)
    top = top + bottom
  end
  for index = #lines + 1, #frame.rows do
    hideParts(frame.rows[index], 1)
    hideStrikes(frame.rows[index], 1)
  end
  local width = math.min(Badges.TOOLTIP_MAX_WIDTH, used + TOOLTIP_PAD * 2)
  local height = top + TOOLTIP_PAD * 2
  call(frame, "SetSize", width, height)
  return width, height
end

-- Off the badge's right edge, the way GameTooltip's ANCHOR_RIGHT sits, flipped to its left
-- where the right would take it off the screen. GetLeft and GetRight are in the badge's own
-- scale and the screen width in UIParent's, which is close enough to choose a side; the frame's
-- clamp is what makes the last few pixels right.
local function anchorTooltip(frame, badge, width)
  local screen = measure(rawget(_G, "UIParent"), "GetWidth")
  if screen <= 0 then
    local getScreenWidth = rawget(_G, "GetScreenWidth")
    if type(getScreenWidth) == "function" then
      local ok, value = pcall(getScreenWidth)
      screen = (ok and tonumber(value)) or 0
    end
  end
  local side = Badges.TooltipSide(measure(badge, "GetLeft"), measure(badge, "GetRight"), width, screen, TOOLTIP_OFFSET)
  call(frame, "ClearAllPoints")
  if side == "LEFT" then
    call(frame, "SetPoint", "TOPRIGHT", badge, "TOPLEFT", -TOOLTIP_OFFSET, 0)
  else
    call(frame, "SetPoint", "TOPLEFT", badge, "TOPRIGHT", TOOLTIP_OFFSET, 0)
  end
  return side
end

-- The client's own tooltip, for a client that would not give us a frame: the same lines, each
-- written as one string, with no strike through and no opacity of ours.
local function showGameTooltip(badge, lines)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return false
  end
  call(tooltip, "SetOwner", badge, "ANCHOR_RIGHT")
  local head = lines[1]
  local title = themeColor(head.colorKey)
  if title then
    call(tooltip, "SetText", head.text, title.r, title.g, title.b)
  else
    call(tooltip, "SetText", head.text)
  end
  for index = 2, #lines do
    local line = lines[index]
    local colour = themeColor(line.colorKey)
    if colour then
      call(tooltip, "AddLine", line.text, colour.r, colour.g, colour.b, true)
    else
      call(tooltip, "AddLine", line.text)
    end
  end
  call(tooltip, "Show")
  return true
end

-- The badge's own tooltip: what the mark means, and what changed where the badge has a subject.
-- Guarded end to end, so a client that can draw neither simply shows nothing. Returns whether a
-- tooltip was drawn.
function Badges.ShowTooltip(badge)
  if type(badge) ~= "table" then
    return false
  end
  local lines = Badges.LinesFor(badge.kind, badge.diffKind, badge.subjectId, badge.basis, badge.note)
  if #lines == 0 then
    return false
  end
  local frame = tooltipFrame()
  if not frame then
    return showGameTooltip(badge, lines)
  end
  local width = drawTooltip(frame, lines)
  anchorTooltip(frame, badge, width)
  call(frame, "Show")
  frame.owner = badge
  return true
end

function Badges.HideTooltip()
  local hidden = false
  if type(shared) == "table" then
    call(shared, "Hide")
    shared.owner = nil
    hidden = true
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    call(tooltip, "Hide")
    hidden = true
  end
  return hidden
end

-- Drops the shared frame, so a spec (or a client that has just been handed a UI) builds a new
-- one rather than keeping one made against the last CreateFrame.
function Badges.ResetTooltip()
  shared = nil
end

-- A click that lands on a badge belongs to whatever the badge sits on. The modern clients can
-- leave motion on and turn clicks off, which sends the click straight through; Classic Era
-- cannot, so the click is handed to the first parent that has a handler for it.
local MAX_PARENTS = 6
local CLICK_SCRIPTS = { "OnMouseUp", "OnClick" }

-- The first two answers of one method call, or nil where the frame has no such method or it raised.
local function call2(object, name)
  if type(object) ~= "table" or type(object[name]) ~= "function" then
    return nil
  end
  local ok, first, second = pcall(object[name], object)
  if not ok then
    return nil
  end
  return first, second
end

-- Brief T6: a click is never handed to a frame the client may run protected code from. Calling
-- such a frame's OnClick from here runs the client's handler in ItemTree's execution, and on a
-- bag slot that handler ends in C_Container.UseContainerItem, which the client then blocks with
-- "ItemTree has been blocked from an action only available to the Blizzard UI". So the walk stops
-- at the first frame that is protected or forbidden, or that is a container item slot (it answers
-- a bag from GetBagID or GetSlotAndBagID, the modern client's ContainerFrameItemButtonMixin). The Forever
-- client never reaches this at all, because its badges pass clicks straight through.
function Badges.RefusesForwardedClick(node)
  if type(node) ~= "table" then
    return true
  end
  if call(node, "IsForbidden") or call(node, "IsProtected") then
    return true
  end
  if tonumber(call(node, "GetBagID")) ~= nil then
    return true
  end
  local _, bag = call2(node, "GetSlotAndBagID")
  return tonumber(bag) ~= nil
end

local function forwardClick(frame, button)
  local node = call(frame, "GetParent")
  for _ = 1, MAX_PARENTS do
    if type(node) ~= "table" or Badges.RefusesForwardedClick(node) then
      return false
    end
    for _, script in ipairs(CLICK_SCRIPTS) do
      local handler = call(node, "GetScript", script)
      if type(handler) == "function" then
        pcall(handler, node, button)
        return true
      end
    end
    node = call(node, "GetParent")
  end
  return false
end

-- Our own frame, so SetScript is the right call, but a frame type that has no such script is
-- asked first: HasScript answers for that, and SetScript is pcall'd either way.
local function setScript(frame, script, handler)
  if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
    return false
  end
  if type(frame.HasScript) == "function" then
    local ok, has = pcall(frame.HasScript, frame, script)
    if ok and has == false then
      return false
    end
  end
  return (pcall(frame.SetScript, frame, script, handler))
end

-- What a surface wants to happen besides the tooltip while the pointer is on one of its marks.
-- A row that paints its own hover state loses it the moment a child frame takes the mouse, so
-- the sidebar and the Discoveries pane hand the mark the two calls that put the row's wash back
-- and take it away again. Nothing here may raise on a hover, so both are pcall'd.
local function hoverHook(frame, name)
  local hook = rawget(frame, name)
  if type(hook) == "function" then
    pcall(hook, frame)
  end
end

-- A badge takes no mouse until hover is turned on, which giving it a subject does and asking for
-- it outright does too: the bag overlay and the Edit mode preview draw badges over a button
-- whose clicks and tooltip have to reach the client untouched, so hover stays opt in. Motion
-- without clicks where the client can separate the two, which the Forever client can
-- (SetMouseClickEnabled and SetPropagateMouseClicks are both in the generated API
-- documentation on Gethe/wow-ui-source, branch `forever`); a client that cannot is left taking
-- the click and handing it to the row through forwardClick.
local function enableHover(frame, on)
  if frame.hoverEnabled == on then
    return on
  end
  frame.hoverEnabled = on
  call(frame, "EnableMouse", on)
  call(frame, "SetMouseMotionEnabled", on)
  call(frame, "SetMouseClickEnabled", false)
  Badges.PropagateClicks(frame, hoverStillOn)
  if not on or frame.hoverScripted then
    return on
  end
  frame.hoverScripted = true
  setScript(frame, "OnEnter", function(self)
    hoverHook(self, "hoverEnter")
    Badges.ShowTooltip(self)
  end)
  setScript(frame, "OnLeave", function(self)
    Badges.HideTooltip()
    hoverHook(self, "hoverLeave")
  end)
  setScript(frame, "OnMouseUp", function(self, button)
    forwardClick(self, button)
  end)
  return on
end

-- E48: whether this badge should be taking the mouse right now. Two reasons are kept apart,
-- because clearing a subject used to switch hover off on a badge whose surface had asked for it
-- outright: a source row, a category header and the footer legend have nothing to diff, so they
-- were the marks that never explained themselves. A kind with no words to say is never given the
-- mouse either, so a hover target can never show an empty tooltip.
local function refreshHover(frame)
  local wanted = frame.hoverAsked == true or frame.hoverBySubject == true
  if wanted and Badges.IsKind(frame.kind) and not Badges.Explains(frame.kind) then
    wanted = false
  end
  if not wanted and frame.hoverEnabled == nil then
    -- Never turned on, so there is nothing to turn off. A badge nobody asked about is left
    -- exactly as it was born, which is what keeps the bag overlay's marks from ever being
    -- handed a mouse call at all.
    return false
  end
  return enableHover(frame, wanted)
end

-- One badge. :SetKind(kind) swaps the art; :SetKind(nil) hides it.
function Badges.Create(parent, size)
  size = Badges.SizeFor(size or "tree")
  local frame = createFrame("Frame", nil, parent)
  if not frame then
    return nil
  end
  frame:SetSize(size, size)
  frame.badgeSize = size

  frame.backing = frame:CreateTexture(nil, "BACKGROUND")
  frame.backing:SetAllPoints(frame)
  frame.ring = frame:CreateTexture(nil, "BORDER")
  frame.ring:SetAllPoints(frame)
  frame.backingMask = newRoundMask(frame, { frame.backing, frame.ring })
  frame.roundBacking = frame.backingMask ~= nil
  frame.art = frame:CreateTexture(nil, "ARTWORK")
  frame.art:SetPoint("CENTER")
  frame.art:SetSize(size, size)
  frame.slash = frame:CreateTexture(nil, "OVERLAY")
  frame.slash:SetPoint("CENTER")
  frame.glyph = newFontString(frame, "OVERLAY")
  if frame.glyph then
    frame.glyph:SetPoint("CENTER", 0, 0)
  end
  clearBadge(frame)
  frame:Hide()

  function frame:SetKind(kind)
    self.kind = kind
    self.artSize = nil
    local meta = Badges.META[kind]
    clearBadge(self)
    -- A pooled badge redrawn as another kind asks again whether that kind has words for a hover,
    -- so a mark can never be left with the mouse and nothing to say.
    refreshHover(self)
    if not meta then
      self:Hide()
      return false
    end
    local drawn = false
    if meta.full and meta.art then
      -- The medallion carries its own ring, so it is drawn a step up the size ladder while the
      -- frame under it keeps its token: nothing in a row or a cluster moves.
      local artSize = Badges.ArtSize(self.badgeSize)
      self.art:SetSize(artSize, artSize)
      drawn = applyArt(self.art, meta.art)
      if drawn then
        self.artSize = artSize
        self.art:Show()
        if meta.desaturate and self.art.SetDesaturated then
          self.art:SetDesaturated(true)
        end
        -- A medallion drawn in a vertex colour, its own colour taken off above (Community
        -- note), or shaded top to bottom (Predicted). clearBadge undoes both on the next draw.
        local colour = meta.artTint and Assets.Tint(meta.artTint) or nil
        if colour then
          call(self.art, "SetVertexColor", colour.r, colour.g, colour.b)
        end
        local shade = meta.artGradient
        local top = shade and Assets.Tint(shade.top) or nil
        local bottom = shade and Assets.Tint(shade.bottom) or nil
        if top and bottom then
          self.art.gradientRoute = Badges.PaintGradient(self.art, bottom, top) or nil
        end
      end
    end
    if not drawn then
      -- Composed form: shared backing plus a client texture, glyph or atlas.
      showComposed(self, meta, self.badgeSize)
    end
    if meta.slash then
      -- The slash crosses whatever was drawn, which is the medallion where it landed.
      local across = self.badgeSize
      if drawn then
        across = Badges.ArtSize(self.badgeSize)
      end
      local thickness = math.max(1, math.floor(self.badgeSize / 12 + 0.5))
      self.slash:SetSize(math.max(1, across - 4), thickness)
      applyArt(self.slash, meta.slashArt or "FILL_WHITE8X8")
      tint(self.slash, meta.slashColor or "ITEMTREE_COLOR_SEMANTIC_REMOVED", 1)
      -- WoW rotates anticlockwise in radians, so pi/4 matches the design's rotate(-45deg).
      if self.slash.SetRotation then
        self.slash:SetRotation(math.pi / 4)
      end
      self.slash:Show()
    end
    self:Show()
    return true
  end

  function frame:GetKind()
    return self.kind
  end

  -- The Diff subject behind this badge, so a hovered Changed mark can say what changed.
  -- diffKind is one of Badges.DIFF_KINDS ("items", "recipes", "enchants", "skills") or a node
  -- kind that maps onto one ("item", "spell", "enchant", "skill"); nil clears the subject.
  -- Naming a subject is also what gives a badge the mouse, and clearing one no longer takes the
  -- mouse back off a badge whose surface asked for hover in its own right.
  function frame:SetSubject(diffKind, id)
    local subject, subjectId = Badges.DiffKind(diffKind), tonumber(id)
    if subject == nil or subjectId == nil then
      self.diffKind, self.subjectId = nil, nil
      self.hoverBySubject = false
      refreshHover(self)
      return false
    end
    self.diffKind, self.subjectId = subject, subjectId
    self.hoverBySubject = true
    refreshHover(self)
    return true
  end

  function frame:GetSubject()
    return self.diffKind, self.subjectId
  end

  -- What the fact under this mark is based on, which picks the meaning line its tooltip draws
  -- (Core/Confidence.lua BASIS_*). Set on every draw, so a pooled badge reused for another row
  -- never keeps the last row's wording; nil is the line the badge has always carried.
  function frame:SetBasis(basis)
    self.basis = type(basis) == "string" and basis or nil
    return self.basis
  end

  function frame:GetBasis()
    return self.basis
  end

  -- The row's own note, which a Community note mark says in place of its generic meaning (brief
  -- E93): a list of strings, or nil. Set on every draw the way the basis is, so a pooled badge
  -- never keeps the last row's note.
  function frame:SetNote(note)
    self.note = Badges.NoteLines(note)
    return self.note
  end

  function frame:GetNote()
    return self.note
  end

  -- Hover on its own, for a badge that stands for a kind rather than a subject: the footer
  -- legend, a source row, a category header and every other surface where the mark explains
  -- itself and there is nothing to diff. Kept apart from the subject, so the two cannot cancel
  -- each other out.
  function frame:SetHoverEnabled(on)
    self.hoverAsked = on == true
    return refreshHover(self)
  end

  function frame:IsHoverEnabled()
    return self.hoverEnabled == true
  end

  -- What else a hover on this mark does, for a surface that paints the row's hover state itself
  -- and would otherwise see it go out the moment the pointer crossed onto the mark. Either may
  -- be nil. The badge is the one argument, and its OnEnter runs the enter hook before the
  -- tooltip while its OnLeave runs the leave hook after it, so the row's state is in place
  -- before the words are and goes last on the way out.
  function frame:SetHoverHooks(onEnter, onLeave)
    self.hoverEnter = type(onEnter) == "function" and onEnter or nil
    self.hoverLeave = type(onLeave) == "function" and onLeave or nil
    return self.hoverEnter ~= nil or self.hoverLeave ~= nil
  end

  function frame:SetBadgeSize(newSize)
    newSize = Badges.SizeFor(newSize)
    self.badgeSize = newSize
    self:SetSize(newSize, newSize)
    if self.kind then
      self:SetKind(self.kind)
    end
  end

  return frame
end

-- One badge more on a cluster, at the given place in its stack, carrying everything the cluster
-- hands on (subject, basis, note, hover and its hooks). Answers the badge, or nil where the
-- client would not make one.
local function addBadge(cluster, index)
  local badge = Badges.Create(cluster, cluster.badgeSize)
  if not badge then
    return nil
  end
  if index == 1 then
    badge:SetPoint(
      cluster.direction == "column" and "TOP" or "LEFT",
      cluster,
      cluster.direction == "column" and "TOP" or "LEFT",
      0,
      0
    )
  elseif cluster.direction == "column" then
    badge:SetPoint("TOP", cluster.badges[index - 1], "BOTTOM", 0, -cluster.gap)
  else
    badge:SetPoint("LEFT", cluster.badges[index - 1], "RIGHT", cluster.gap, 0)
  end
  -- Only a cluster that has a subject hands one on: a badge nobody named a subject for is never
  -- asked for the mouse at all, which is what the bag overlay draws.
  if cluster.diffKind and type(badge.SetSubject) == "function" then
    badge:SetSubject(cluster.diffKind, cluster.subjectId)
  end
  if type(badge.SetBasis) == "function" then
    badge:SetBasis(cluster.basis)
  end
  if type(badge.SetNote) == "function" then
    badge:SetNote(cluster.note)
  end
  -- E48: hover and the hooks that go with it are inherited the way the subject is, so a mark
  -- drawn for the first time on the fourth row of a list is as much a hover target as the one on
  -- the first row.
  if cluster.hoverAsked and type(badge.SetHoverEnabled) == "function" then
    badge:SetHoverEnabled(true)
  end
  if (cluster.hoverEnter or cluster.hoverLeave) and type(badge.SetHoverHooks) == "function" then
    badge:SetHoverHooks(cluster.hoverEnter, cluster.hoverLeave)
  end
  cluster.badges[index] = badge
  return badge
end

-- Ordered badge group. :SetKinds(kinds) sorts by priority, keeps max, hides the rest.
function Badges.CreateCluster(parent, size, max, direction, gap)
  size = Badges.SizeFor(size or "tree")
  max = max or 3
  direction = direction == "column" and "column" or "row"
  gap = gap or Badges.GapFor(size)
  local frame = createFrame("Frame", nil, parent)
  if not frame then
    return nil
  end
  frame.badges = {}
  frame.badgeSize = size
  frame.max = max
  frame.direction = direction
  frame.gap = gap
  frame:SetSize(Badges.ClusterExtent(max, size, gap, direction))

  function frame:SetKinds(kinds)
    local sorted = Badges.Sort(kinds, self.max)
    for index, kind in ipairs(sorted) do
      local badge = self.badges[index] or addBadge(self, index)
      if not badge then
        break
      end
      badge:SetKind(kind)
    end
    for index = #sorted + 1, #self.badges do
      self.badges[index]:SetKind(nil)
    end
    self.kinds = sorted
    local width, height = Badges.ClusterExtent(#sorted, self.badgeSize, self.gap, self.direction)
    if #sorted == 0 then
      self:Hide()
    else
      self:SetSize(width, height)
      self:Show()
    end
    return sorted
  end

  function frame:GetKinds()
    return self.kinds or {}
  end

  -- Brief TX2: makes every badge the cluster can ever show now, hidden, so a later SetKinds never
  -- creates a frame. A cluster that will be moved under a client frame (the bag and merchant
  -- overlay) is filled while it still has no client parent: on Forever the gamepad
  -- SmartNavigation post hooks CreateFrame and, for a frame whose parent chain reaches an open
  -- panel, rebuilds that panel's navigation state as the caller, which leaves it tainted.
  -- Answers how many badges the cluster holds.
  function frame:Fill()
    for index = #self.badges + 1, self.max do
      if not addBadge(self, index) then
        break
      end
    end
    return #self.badges
  end

  -- The subject every badge in this cluster sits on, for the hover tooltip. Same arguments as
  -- the single badge's, and badges made later in SetKinds inherit it.
  function frame:SetSubject(diffKind, id)
    local subject, subjectId = Badges.DiffKind(diffKind), tonumber(id)
    if subject == nil or subjectId == nil then
      subject, subjectId = nil, nil
    end
    self.diffKind, self.subjectId = subject, subjectId
    for _, badge in ipairs(self.badges) do
      if type(badge.SetSubject) == "function" then
        badge:SetSubject(subject, subjectId)
      end
    end
    return subject ~= nil
  end

  function frame:GetSubject()
    return self.diffKind, self.subjectId
  end

  -- The basis every badge in this cluster stands on, for the hover tooltip's meaning line.
  -- Badges made later in SetKinds inherit it, the way the subject is inherited.
  function frame:SetBasis(basis)
    self.basis = type(basis) == "string" and basis or nil
    for _, badge in ipairs(self.badges) do
      if type(badge.SetBasis) == "function" then
        badge:SetBasis(self.basis)
      end
    end
    return self.basis
  end

  function frame:GetBasis()
    return self.basis
  end

  -- The row's own note every badge in this cluster carries, for a Community note mark's hover
  -- (brief E93). Badges made later in SetKinds inherit it, the way the basis is inherited.
  function frame:SetNote(note)
    self.note = Badges.NoteLines(note)
    for _, badge in ipairs(self.badges) do
      if type(badge.SetNote) == "function" then
        badge:SetNote(self.note)
      end
    end
    return self.note
  end

  function frame:GetNote()
    return self.note
  end

  -- E48: every mark in this cluster is its own hover target, whether or not there is anything to
  -- diff under it. One call per surface at the time the cluster is built, and badges made later
  -- in SetKinds inherit it, the way the subject and the basis are inherited. A cluster nobody
  -- asks stays as inert as it has always been, which is what the bag overlay and the Edit mode
  -- preview draw.
  function frame:SetHoverEnabled(on)
    self.hoverAsked = on == true
    for _, badge in ipairs(self.badges) do
      if type(badge.SetHoverEnabled) == "function" then
        badge:SetHoverEnabled(self.hoverAsked)
      end
    end
    return self.hoverAsked
  end

  function frame:IsHoverEnabled()
    return self.hoverAsked == true
  end

  -- What else a hover on any mark in this cluster does, for a surface that paints the row's own
  -- hover state. Inherited by badges made later, like everything else here.
  function frame:SetHoverHooks(onEnter, onLeave)
    self.hoverEnter = type(onEnter) == "function" and onEnter or nil
    self.hoverLeave = type(onLeave) == "function" and onLeave or nil
    for _, badge in ipairs(self.badges) do
      if type(badge.SetHoverHooks) == "function" then
        badge:SetHoverHooks(self.hoverEnter, self.hoverLeave)
      end
    end
    return self.hoverEnter ~= nil or self.hoverLeave ~= nil
  end

  frame:SetKinds({})
  return frame
end

return Badges
