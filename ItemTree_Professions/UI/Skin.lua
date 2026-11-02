-- The Professions tab's skin (brief PR13, redrawn by brief PR16): the client's own profession art
-- for the rank bar, cut to the tab's sizes, and the cards drawn from flat fills.
--
-- Brief PR16: the owner found the ProfessionsBook card art's bevel massive, the CalloutGlow round a
-- recommended card pixelated and the wrong shape, and both blurred when the canvas zoomed in (the
-- canvas zooms with SetScale, so any bitmap on it is magnified). A card is now flat colour with a
-- thin edge and a small chamfer at each corner, every piece a solid white texture tinted, so it is
-- as sharp at 200% as at 100%. The chamfer is a square turned 45 degrees (Texture:SetRotation);
-- a turned square looks the same whichever way the client turns it, and where the client has no
-- SetRotation the corners are simply square.
--
--   Skin.Info(raw)                           a GetAtlasInfo answer as { w, h, l, r, t, b, file }
--   Skin.ThreeSlices(info, cap, w, h)        three pieces, the caps kept and the middle cut 1:1
--   Skin.FlipbookFrame(info, columns, frameH, fraction)   l, r, t, b of the sheet's first frame
--   Skin.ChamferPieces(w, h, chamfer, edge)  the flat card's rects and turned squares
--   Skin.Card(frame, w, h, style)            draws that card on a frame
--   Skin.PlateLook(state, lit, enabled)      brief PR17: what a labelled plate button paints
--   Skin.PlateButton(parent, w, h)           brief PR17: the window's red plate button, with words;
--                                            brief PW1: its plate in the client's three slices
--   Skin.PaintPlate(button, state)           and its pointer states, lit and faded included
--   Skin.PlateScripts(button, setScript, extra)   its pointer handlers, chained to the caller's
--   Skin.BorderPieces(w, h, corner, inset)   brief PR19: the thin border's nine pieces, none meeting
--   Skin.Border(frame, w, h, style)          brief PR19: draws that border (and a face) from the
--                                            client's own tooltip art, tinted
--   Skin.GlowStops(colour), Skin.Glow(texture, key)   brief PR23: a soft glow fading out to the
--                                            left, a gradient on a white texture
--   Skin.NineSlices(info, corner, size, w, h), Skin.NineSlice(frame, key, w, h, style)
--                                            brief PR36: one atlas in nine pieces (the parchment)
--   Skin.CropCoords(info, crop), Skin.FaceCoords(coords, w, h, rect), Skin.ArtCard(frame, w, h,
--                                            style)  brief PR36: a chamfered card with an atlas
--                                            face (the gunmetal strip)
--
-- Brief PR19 (QA round 4): "a more polished look ... thin border textures rather than plain 1 px
-- borders". Skin.Card now draws the client's own thin tooltip border first: the eight pieces of
-- TooltipDefaultLayout (Blizzard_SharedXML/Mainline/NineSliceLayouts.lua, wow-ui-source branch
-- forever: Tooltip-NineSlice-CornerTopLeft and the rest, the Camelot spelling ending -c60 in
-- alts), 7 by 7 texel corners and 7 texel edges in UiTextureAtlasMember of 1.60.1.70009, a light
-- bevel tinted to the card's edge colour. The art is small, so it is drawn at its own size (or
-- smaller, the Recommended tag's 5 px) and only ever magnified by the canvas zoom itself. The art's
-- own rounded corner replaces the chamfer, and its nine pieces never overlap, so a card faded
-- with one SetAlpha on its frame fades evenly (the chamfer's turned squares overlapped, and their
-- corners showed through as brighter diamonds). Where any of the eight pieces is missing the
-- chamfered flat card below is drawn as before.
--
-- Coordinates are the frame's own, y running down from its top left, the way UI\Layout.lua
-- writes them. Texture coordinates are the file's, 0 to 1.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Skin = {}
ItemTree.ProfessionsSkin = Skin

local EMPTY = {}

-- The flat card's chamfer at each corner, in px, and its edge's thickness.
Skin.CHAMFER = 4
Skin.EDGE = 1
-- Brief PR19: the thin border's corner and edge size in px (the art's own 7 texels), and how far
-- in the face starts at that size: the tooltip layout's own Center sits 4 px into the 7 px corner,
-- so the bevel is the outer 3 px and the rest of each piece is clear.
Skin.BORDER = 7
Skin.BORDER_FACE = 3
-- The Assets keys of the eight pieces, by piece.
Skin.BORDER_KEYS = {
  TL = "PROFESSION_BORDER_TL",
  TR = "PROFESSION_BORDER_TR",
  BL = "PROFESSION_BORDER_BL",
  BR = "PROFESSION_BORDER_BR",
  TOP = "PROFESSION_BORDER_TOP",
  BOTTOM = "PROFESSION_BORDER_BOTTOM",
  LEFT = "PROFESSION_BORDER_LEFT",
  RIGHT = "PROFESSION_BORDER_RIGHT",
}
Skin.BORDER_ORDER = { "TL", "TR", "BL", "BR", "TOP", "BOTTOM", "LEFT", "RIGHT" }

--------------------------------------------------------------------------------
-- Pure
--------------------------------------------------------------------------------

--- A GetAtlasInfo answer as { w, h, l, r, t, b, file }, or nil where it is not a usable atlas.
--- Pure.
function Skin.Info(raw)
  if type(raw) ~= "table" then
    return nil
  end
  local w, h = tonumber(raw.width), tonumber(raw.height)
  local l, r = tonumber(raw.leftTexCoord), tonumber(raw.rightTexCoord)
  local t, b = tonumber(raw.topTexCoord), tonumber(raw.bottomTexCoord)
  local file = raw.file or raw.filename
  if not (w and h and l and r and t and b) or w <= 0 or h <= 0 or file == nil then
    return nil
  end
  return { w = w, h = h, l = l, r = r, t = t, b = b, file = file }
end

local clamp = ItemTree.Util.Clamp

--- Three pieces of one atlas for a w by h bar: the left and right caps at cap wide, the middle
--- cut one to one from the atlas where it is wide enough. The full atlas height is stretched to h.
--- Pure.
function Skin.ThreeSlices(info, cap, w, h)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if type(info) ~= "table" or w <= 0 or h <= 0 then
    return {}
  end
  local c = math.max(math.min(tonumber(cap) or 0, w / 2, info.w / 2), 0)
  local du = (info.r - info.l) / info.w
  local innerW = w - 2 * c
  local spanW = clamp(innerW, 0, info.w - 2 * c)
  return {
    { part = "LEFT", x = 0, y = 0, w = c, h = h, l = info.l, r = info.l + c * du, t = info.t, b = info.b },
    {
      part = "MIDDLE",
      x = c,
      y = 0,
      w = innerW,
      h = h,
      l = info.l + c * du,
      r = info.l + (c + spanW) * du,
      t = info.t,
      b = info.b,
    },
    { part = "RIGHT", x = w - c, y = 0, w = c, h = h, l = info.r - c * du, r = info.r, t = info.t, b = info.b },
  }
end

--- The texture coordinates of a flipbook sheet's first frame (columns across, frames frameH atlas
--- pixels high), cut to the first fraction of its width, so a bar filled to a fraction shows that
--- much of one frame rather than the whole sheet squeezed in. Pure.
function Skin.FlipbookFrame(info, columns, frameH, fraction)
  if type(info) ~= "table" then
    return nil
  end
  columns = math.max(tonumber(columns) or 1, 1)
  frameH = tonumber(frameH) or info.h
  if frameH <= 0 or frameH > info.h then
    frameH = info.h
  end
  fraction = clamp(tonumber(fraction) or 1, 0, 1)
  local frameU = (info.r - info.l) / columns
  local frameV = (info.b - info.t) * frameH / info.h
  return info.l, info.l + frameU * fraction, info.t, info.t + frameV
end

--- The flat card for a w by h frame with a chamfer at each corner and an edge thick: { chamfer,
--- face = { rects }, edges = { rects }, outer = { squares }, inner = { squares } }. The face is a
--- middle column and two side strips that leave each chamfer by chamfer corner open; a square turned
--- 45 degrees in the edge colour (outer, half diagonal chamfer) and one in the face colour on top of
--- it (inner, half diagonal chamfer less the edge's diagonal width) close each corner along the cut.
--- A square is { cx, cy, side }: its centre and its side before turning. Pure.
function Skin.ChamferPieces(w, h, chamfer, edge)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  edge = math.max(tonumber(edge) or Skin.EDGE, 0)
  local c = math.max(math.min(tonumber(chamfer) or Skin.CHAMFER, w / 2, h / 2), 0)
  local root2 = math.sqrt(2)
  -- The inner square must keep some size, or the corner shows the edge colour solid.
  if c - edge * root2 < 0.5 then
    c = 0
  end
  local out = { chamfer = c, face = {}, edges = {}, outer = {}, inner = {} }
  if w <= 0 or h <= 0 then
    return out
  end
  out.face[1] = { x = c, y = 0, w = w - 2 * c, h = h }
  if c > 0 then
    out.face[2] = { x = 0, y = c, w = c, h = h - 2 * c }
    out.face[3] = { x = w - c, y = c, w = c, h = h - 2 * c }
  end
  out.edges[1] = { x = c, y = 0, w = w - 2 * c, h = edge }
  out.edges[2] = { x = c, y = h - edge, w = w - 2 * c, h = edge }
  out.edges[3] = { x = 0, y = c, w = edge, h = h - 2 * c }
  out.edges[4] = { x = w - edge, y = c, w = edge, h = h - 2 * c }
  if c > 0 then
    local innerHalf = c - edge * root2
    for index, corner in ipairs({ { c, c }, { w - c, c }, { c, h - c }, { w - c, h - c } }) do
      out.outer[index] = { cx = corner[1], cy = corner[2], side = c * root2 }
      out.inner[index] = { cx = corner[1], cy = corner[2], side = innerHalf * root2 }
    end
  end
  return out
end

--- Brief PR19: the thin border for a w by h frame with corners corner px square (Skin.BORDER by
--- default, held to half the frame): { corner, inset, face = rect, pieces = { TL, TR, BL, BR, TOP,
--- BOTTOM, LEFT, RIGHT } }. The corners sit in the frame's corners, the edges run between them,
--- and no two pieces meet, so one frame alpha fades them all evenly. The face starts inset px in
--- (Skin.BORDER_FACE at the art's own size, scaled with a smaller corner), under the clear inner
--- part of the border. Pure.
function Skin.BorderPieces(w, h, corner, inset)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  local c = math.max(math.min(tonumber(corner) or Skin.BORDER, w / 2, h / 2), 0)
  if inset == nil then
    inset = math.floor(Skin.BORDER_FACE * c / Skin.BORDER + 0.5)
  end
  inset = math.max(math.min(tonumber(inset) or 0, w / 2, h / 2), 0)
  local out = { corner = c, inset = inset, pieces = {} }
  if w <= 0 or h <= 0 then
    return out
  end
  out.face = { x = inset, y = inset, w = w - 2 * inset, h = h - 2 * inset }
  local p = out.pieces
  p.TL = { x = 0, y = 0, w = c, h = c }
  p.TR = { x = w - c, y = 0, w = c, h = c }
  p.BL = { x = 0, y = h - c, w = c, h = c }
  p.BR = { x = w - c, y = h - c, w = c, h = c }
  p.TOP = { x = c, y = 0, w = w - 2 * c, h = c }
  p.BOTTOM = { x = c, y = h - c, w = w - 2 * c, h = c }
  p.LEFT = { x = 0, y = c, w = c, h = h - 2 * c }
  p.RIGHT = { x = w - c, y = c, w = c, h = h - 2 * c }
  return out
end

--- Brief PR17: what a labelled plate button (Skin.PlateButton) paints for a pointer state
--- ("normal", "hover", "pushed"), whether it is lit and whether it can be pressed: the state
--- Frame.PaintPlateButton draws, and whether the plate's highlight stays on at rest. A button
--- that cannot be pressed never lights or goes down (it is faded instead, and keeps its hover's
--- tooltip); a lit one glows in every state. Pure.
function Skin.PlateLook(state, lit, enabled)
  if enabled == false then
    return "normal", false
  end
  if state ~= "hover" and state ~= "pushed" then
    state = "normal"
  end
  return state, lit == true
end

--- Brief PR23: a soft glow's two ends for a horizontal gradient that fades out to the LEFT: the
--- colour at no alpha on the left, and at the colour's own alpha (1 where it has none) on the
--- right, against the line it glows from. nil without a colour. Pure.
function Skin.GlowStops(colour)
  if type(colour) ~= "table" then
    return nil
  end
  local r, g, b = tonumber(colour.r) or 1, tonumber(colour.g) or 1, tonumber(colour.b) or 1
  local a = tonumber(colour.a) or 1
  return { r = r, g = g, b = b, a = 0 }, { r = r, g = g, b = b, a = a }
end

--- Brief PR36 (owner QA of PR35, 2026-10-02): nine pieces of one atlas for a w by h frame, the
--- art's corners corner texels square drawn size px square (corner where size is not given, held
--- to half the frame), the edges and centre stretched between them: { { part, x, y, w, h, l, r, t,
--- b } } in TL, TOP, TR, LEFT, CENTRE, RIGHT, BL, BOTTOM, BR order. Empty without art or size.
--- Pure.
function Skin.NineSlices(info, corner, size, w, h)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if type(info) ~= "table" or w <= 0 or h <= 0 then
    return {}
  end
  local c = clamp(tonumber(corner) or 0, 0, math.min(info.w, info.h) / 2)
  local s = clamp(tonumber(size) or c, 0, math.min(w, h) / 2)
  local du = (info.r - info.l) / info.w
  local dv = (info.b - info.t) / info.h
  local u = { info.l, info.l + c * du, info.r - c * du, info.r }
  local v = { info.t, info.t + c * dv, info.b - c * dv, info.b }
  local xs, ws = { 0, s, w - s }, { s, w - 2 * s, s }
  local ys, hs = { 0, s, h - s }, { s, h - 2 * s, s }
  local names = { "TL", "TOP", "TR", "LEFT", "CENTRE", "RIGHT", "BL", "BOTTOM", "BR" }
  local out = {}
  for row = 1, 3 do
    for column = 1, 3 do
      out[#out + 1] = {
        part = names[(row - 1) * 3 + column],
        x = xs[column],
        y = ys[row],
        w = ws[column],
        h = hs[row],
        l = u[column],
        r = u[column + 1],
        t = v[row],
        b = v[row + 1],
      }
    end
  end
  return out
end

--- Brief PR36: an atlas's texture coordinates cut to crop, { l, r, t, b } as fractions of the
--- atlas's own rect (the gunmetal strip's dark middle without the art's rims). No crop, the whole
--- rect. Pure.
function Skin.CropCoords(info, crop)
  if type(info) ~= "table" then
    return nil
  end
  crop = type(crop) == "table" and crop or EMPTY
  local function at(fraction, from, to, default)
    return from + (to - from) * clamp(tonumber(fraction) or default, 0, 1)
  end
  return {
    l = at(crop[1], info.l, info.r, 0),
    r = at(crop[2], info.l, info.r, 1),
    t = at(crop[3], info.t, info.b, 0),
    b = at(crop[4], info.t, info.b, 1),
  }
end

--- Brief PR36: the texture coordinates for rect, a piece of a w by h card, where the coords rect is
--- stretched over the whole card: the pieces of one face share one picture with no seams. Pure.
function Skin.FaceCoords(coords, w, h, rect)
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if type(coords) ~= "table" or type(rect) ~= "table" or w <= 0 or h <= 0 then
    return nil
  end
  local du, dv = (coords.r - coords.l) / w, (coords.b - coords.t) / h
  return {
    l = coords.l + rect.x * du,
    r = coords.l + (rect.x + rect.w) * du,
    t = coords.t + rect.y * dv,
    b = coords.t + (rect.y + rect.h) * dv,
  }
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local assets = ItemTree.ProfessionsKit.Assets
local theme = ItemTree.ProfessionsKit.Theme

local function entryOf(key)
  local a = assets()
  if not (a and type(a.Has) == "function" and a.Has(key)) then
    return nil
  end
  local ok, entry = pcall(a.Get, key)
  return ok and type(entry) == "table" and entry or nil
end

--- What the client holds for an atlas name, normalised by Skin.Info, or nil.
function Skin.AtlasInfo(name)
  local api = rawget(_G, "C_Texture")
  if type(name) ~= "string" or type(api) ~= "table" or type(api.GetAtlasInfo) ~= "function" then
    return nil
  end
  local ok, raw = pcall(api.GetAtlasInfo, name)
  if not ok then
    return nil
  end
  return Skin.Info(raw)
end

--- An Assets key's atlas as the client holds it: the entry's own name, else each of its alts, the
--- first that answers. Answers the info and the name it answered for, or nil.
function Skin.Resolve(key)
  local entry = entryOf(key)
  if not entry or entry.kind ~= "atlas" then
    return nil
  end
  local info = Skin.AtlasInfo(entry.name)
  if info then
    return info, entry.name, entry
  end
  for _, alt in ipairs(entry.alts or EMPTY) do
    info = Skin.AtlasInfo(alt)
    if info then
      return info, alt, entry
    end
  end
  return nil
end

--- Whether an atlas key is there to draw: the client knows its name or one of its alts.
function Skin.Has(key)
  return Skin.Resolve(key) ~= nil
end

function Skin.Colour(key)
  local t = theme()
  if not (t and key and type(t.ColorTable) == "function") then
    return nil
  end
  local ok, colour = pcall(t.ColorTable, key)
  return ok and type(colour) == "table" and colour or nil
end

local function newTexture(parent, layer, sub)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(parent.CreateTexture, parent, nil, layer or "BACKGROUND", nil, sub)
  if ok and type(texture) == "table" then
    return texture
  end
  return nil
end

local function place(texture, frame, rect)
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", frame, "TOPLEFT", rect.x, -rect.y)
  texture:SetSize(math.max(rect.w, 0.01), math.max(rect.h, 0.01))
end

local function paintPiece(texture, file, piece)
  local ok = pcall(texture.SetTexture, texture, file)
  if not ok then
    return false
  end
  if type(texture.SetTexCoord) == "function" then
    pcall(texture.SetTexCoord, texture, piece.l, piece.r, piece.t, piece.b)
  end
  return true
end

local function vertex(texture, colour)
  if type(texture.SetVertexColor) ~= "function" then
    return
  end
  if colour then
    texture:SetVertexColor(colour.r, colour.g, colour.b, 1)
  else
    texture:SetVertexColor(1, 1, 1, 1)
  end
end

local function white(texture, colour)
  local a = assets()
  if not a or type(a.Apply) ~= "function" then
    return false
  end
  local ok, applied = pcall(a.Apply, texture, "FILL_WHITE8X8")
  if not ok or applied == false then
    return false
  end
  if colour and type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(colour.r, colour.g, colour.b, colour.a or 1)
  end
  return true
end

local function canTurn(texture)
  return type(texture) == "table" and type(texture.SetRotation) == "function"
end

-- A square turned 45 degrees about its centre.
local function placeTurned(texture, frame, square)
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", frame, "TOPLEFT", square.cx - square.side / 2, -(square.cy - square.side / 2))
  texture:SetSize(math.max(square.side, 0.01), math.max(square.side, 0.01))
  pcall(texture.SetRotation, texture, math.pi / 4)
end

--- Brief PR19: the eight border pieces as the client holds them, { [piece] = info }, or nil where
--- any one is missing (the caller then draws the flat edges it drew before). Asked of the client
--- once a session (Skin.borderArt; false once it has answered that one is missing), since every
--- card on screen draws it.
function Skin.BorderArt()
  local cached = rawget(Skin, "borderArt")
  if cached ~= nil then
    return cached or nil
  end
  local out = {}
  for _, piece in ipairs(Skin.BORDER_ORDER) do
    local info = Skin.Resolve(Skin.BORDER_KEYS[piece])
    if not info then
      Skin.borderArt = false
      return nil
    end
    out[piece] = info
  end
  Skin.borderArt = out
  return out
end

--- Hides a border Skin.Border drew.
function Skin.HideBorder(frame, store)
  local pieces = type(frame) == "table" and rawget(frame, store or "borderPieces") or nil
  if type(pieces) ~= "table" then
    return
  end
  for _, texture in pairs(pieces) do
    texture:Hide()
  end
end

--- Brief PR19: draws the client's thin border (Skin.BorderPieces) over a w by h frame, tinted
--- style.edge, and where style.fill is given a flat face inside it. The textures are made once and
--- kept on the frame under style.store .. "Border" (default "borderPieces"): the face on the
--- BACKGROUND layer at sublevel -6, the pieces at -3 (or on style.layer at 0, the rank bar's
--- frame over its fill), under anything else the frame draws. No
--- piece is given an alpha of its own. Answers whether it drew; false where the art is missing,
--- with nothing shown.
function Skin.Border(frame, w, h, style)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return false
  end
  style = type(style) == "table" and style or EMPTY
  local store = style.store and (style.store .. "Border") or "borderPieces"
  local art = Skin.BorderArt()
  if not art then
    Skin.HideBorder(frame, store)
    return false
  end
  local pieces = rawget(frame, store)
  if type(pieces) ~= "table" then
    pieces = {}
    for _, piece in ipairs(Skin.BORDER_ORDER) do
      local texture = newTexture(frame, style.layer or "BACKGROUND", style.layer and 0 or -3)
      if not texture then
        return false
      end
      pieces[piece] = texture
    end
    pieces.FACE = newTexture(frame, "BACKGROUND", -6)
    frame[store] = pieces
  end
  local shape = Skin.BorderPieces(w, h, style.corner or Skin.BORDER, style.inset)
  local edge = Skin.Colour(style.edge)
  for _, piece in ipairs(Skin.BORDER_ORDER) do
    local texture, rect = pieces[piece], shape.pieces[piece]
    if rect and rect.w > 0 and rect.h > 0 and paintPiece(texture, art[piece].file, art[piece]) then
      place(texture, frame, rect)
      vertex(texture, edge)
      texture:Show()
    else
      texture:Hide()
    end
  end
  local face = pieces.FACE
  if face then
    local fill = style.fill and Skin.Colour(style.fill) or nil
    if fill and shape.face and white(face, fill) then
      place(face, frame, shape.face)
      face:Show()
    else
      face:Hide()
    end
  end
  frame.borderShape = shape
  return true
end

--- Draws the card over a w by h frame. Brief PR19: the client's thin border and a flat face first
--- (Skin.Border); where that art is missing, the flat chamfered card (Skin.ChamferPieces), the
--- textures made once and kept on the frame under style.store (default "cardPieces"). style: {
--- fill, edge (Theme colour keys), thickness, chamfer, corner (the border's corner px), art (false
--- for the chamfer whatever the client holds) }. Every piece sits on the BACKGROUND layer below
--- sublevel 0, under anything else the frame draws. Answers whether it drew; on false the caller
--- draws its own fallback. frame.cardArt says which: "border" or "chamfer".
function Skin.Card(frame, w, h, style)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return false
  end
  style = type(style) == "table" and style or EMPTY
  local store = style.store or "cardPieces"
  if
    style.art ~= false
    and Skin.Border(frame, w, h, { fill = style.fill, edge = style.edge, corner = style.corner, store = style.store })
  then
    Skin.HideCard(frame, store)
    frame.cardArt = "border"
    return true
  end
  frame.cardArt = "chamfer"
  local pieces = rawget(frame, store)
  if type(pieces) ~= "table" then
    pieces = { face = {}, edges = {}, outer = {}, inner = {} }
    local layers = { outer = -7, face = -6, inner = -5, edges = -4 }
    local counts = { outer = 4, face = 3, inner = 4, edges = 4 }
    for group, count in pairs(counts) do
      for index = 1, count do
        local texture = newTexture(frame, "BACKGROUND", layers[group])
        if not texture then
          return false
        end
        pieces[group][index] = texture
      end
    end
    frame[store] = pieces
  end
  local chamfer = style.chamfer or Skin.CHAMFER
  if not canTurn(pieces.outer[1]) then
    chamfer = 0
  end
  local shape = Skin.ChamferPieces(w, h, chamfer, style.thickness or Skin.EDGE)
  local fill, edge = Skin.Colour(style.fill), Skin.Colour(style.edge)
  local drawn = true
  for group, colour in pairs({ face = fill, inner = fill, edges = edge, outer = edge }) do
    for index, texture in ipairs(pieces[group]) do
      local rect = shape[group][index]
      if rect and white(texture, colour) then
        if rect.side then
          placeTurned(texture, frame, rect)
        else
          place(texture, frame, rect)
        end
        texture:Show()
      else
        texture:Hide()
        if group == "face" and index == 1 then
          drawn = false
        end
      end
    end
  end
  frame.cardShape = shape
  return drawn
end

--- Hides a card Skin.Card drew.
function Skin.HideCard(frame, store)
  local pieces = rawget(frame, store or "cardPieces")
  if type(pieces) == "table" then
    for _, group in pairs(pieces) do
      for _, texture in ipairs(group) do
        texture:Hide()
      end
    end
  end
end

local function frameApi()
  local ui = ItemTree.UI
  local found = type(ui) == "table" and ui.Frame or nil
  if type(found) == "table" and type(found.NewPlateButton) == "function" then
    return found
  end
  return nil
end

--- Brief PR17: a labelled red plate button, w by h, on parent: the window's shared plate button
--- (UI/Frame.lua Frame.NewPlateButton, briefs BL31 and BL32) with no glyph, sized to the words.
--- The helper draws the plate's highlight additively and keeps a child frame (.glyphFrame) one
--- level above every plate texture, so the words go there (.labelParent) and the highlight can
--- never cover them, which is what left the old Trainers & vendors button a red smear (QA round
--- 3). Answers the button, hidden, or nil where the window has no such helper; the caller then
--- draws its own flat button.
function Skin.PlateButton(parent, w, h)
  local api = frameApi()
  if not api then
    return nil
  end
  local ok, button = pcall(api.NewPlateButton, parent, nil, nil, h)
  if not ok or type(button) ~= "table" then
    return nil
  end
  if type(button.SetSize) == "function" then
    pcall(button.SetSize, button, w or h, h)
  end
  -- Brief PW1 (QA item 238 c): the plate drawn the client's way, a left cap, a middle and a right
  -- cap (UI/Frame.lua Frame.SlicePlate), where it was one whole texture stretched to the button.
  if type(api.SlicePlate) == "function" then
    pcall(api.SlicePlate, button, h)
    -- Cut again where the button is later given another height (a caller's own layout), so the
    -- caps keep the art's shape; only when the caps' width would change.
    if type(button.HookScript) == "function" and type(api.PlateCapWidth) == "function" then
      pcall(button.HookScript, button, "OnSizeChanged", function(self, _, height)
        local art = rawget(self, "plate")
        height = tonumber(height)
        if type(art) == "table" and height and height > 0 and api.PlateCapWidth(height) ~= rawget(art, "cap") then
          pcall(api.SlicePlate, self, height)
        end
      end)
    end
  end
  button.plated = true
  button.labelParent = rawget(button, "glyphFrame") or button
  return button
end

-- The plate's highlight, whichever plate the helper drew: the client's art or its own wash.
local function plateHighlight(button)
  local art = rawget(button, "plate")
  if type(art) == "table" and type(art.highlight) == "table" then
    return art.highlight
  end
  local own = rawget(button, "highlight")
  return type(own) == "table" and own or nil
end

--- Brief PR17: paints a Skin.PlateButton in a pointer state, through Frame.PaintPlateButton, by
--- Skin.PlateLook of the button's .lit and .canPress. A lit button keeps its additive highlight
--- on, moved to the ARTWORK layer so it shows at rest (the HIGHLIGHT layer draws only under the
--- pointer); the words sit on the child frame above it. Answers the state painted, or nil.
function Skin.PaintPlate(button, state)
  if type(button) ~= "table" or not rawget(button, "plated") then
    return nil
  end
  local api = frameApi()
  local look, glow = Skin.PlateLook(state, rawget(button, "lit"), rawget(button, "canPress"))
  if api and type(api.PaintPlateButton) == "function" then
    pcall(api.PaintPlateButton, button, look)
  end
  local highlight = plateHighlight(button)
  if highlight then
    if type(highlight.SetDrawLayer) == "function" then
      pcall(highlight.SetDrawLayer, highlight, glow and "ARTWORK" or "HIGHLIGHT")
    end
    if glow then
      highlight:Show()
    end
  end
  button.look = look
  return look
end

--- Brief PR17: the pointer handlers a Skin.PlateButton paints itself from, each followed by the
--- caller's own (extra = { OnEnter, OnLeave, OnMouseDown, OnMouseUp }, any left out), so a
--- button that also pans or shows a tooltip keeps the plate's states. setScript is the caller's
--- guarded SetScript.
function Skin.PlateScripts(button, setScript, extra)
  extra = type(extra) == "table" and extra or EMPTY
  local function chain(script, state)
    setScript(button, script, function(self, ...)
      local wanted = state
      if type(state) == "function" then
        wanted = state(self)
      end
      Skin.PaintPlate(self, wanted)
      if type(extra[script]) == "function" then
        extra[script](self, ...)
      end
    end)
  end
  chain("OnEnter", "hover")
  chain("OnLeave", "normal")
  chain("OnMouseDown", "pushed")
  chain("OnMouseUp", function(self)
    -- A press let go off the button leaves it at rest.
    if type(self.IsMouseOver) == "function" then
      local ok, over = pcall(self.IsMouseOver, self)
      if ok and over == false then
        return "normal"
      end
    end
    return "hover"
  end)
  chain("OnHide", "normal")
end

--- Draws an atlas cut into three over a w by h region of frame, at x, y. Pieces kept under store.
--- Answers whether it drew.
function Skin.ThreeSlice(frame, key, x, y, w, h, store, layer, sub)
  local pieces = rawget(frame, store)
  local info, _, entry = Skin.Resolve(key)
  if not info then
    if type(pieces) == "table" then
      for _, texture in pairs(pieces) do
        texture:Hide()
      end
    end
    return false
  end
  if type(pieces) ~= "table" then
    pieces = {}
    for _, part in ipairs({ "LEFT", "MIDDLE", "RIGHT" }) do
      local texture = newTexture(frame, layer or "ARTWORK", sub)
      if not texture then
        return false
      end
      pieces[part] = texture
    end
    frame[store] = pieces
  end
  for _, piece in ipairs(Skin.ThreeSlices(info, entry.cap or 8, w, h)) do
    local texture = pieces[piece.part]
    if piece.w <= 0 or not paintPiece(texture, info.file, piece) then
      texture:Hide()
    else
      place(texture, frame, { x = x + piece.x, y = y + piece.y, w = piece.w, h = piece.h })
      vertex(texture, nil)
      texture:Show()
    end
  end
  return true
end

--- Draws a flipbook atlas's first frame into texture, cut to fraction of its width. Answers
--- whether it drew.
function Skin.Flipbook(texture, key, fraction)
  local info, _, entry = Skin.Resolve(key)
  if not info or type(texture) ~= "table" then
    return false
  end
  local book = type(entry.flipbook) == "table" and entry.flipbook or EMPTY
  local l, r, t, b = Skin.FlipbookFrame(info, book.columns, book.frameH, fraction)
  if not l or not paintPiece(texture, info.file, { l = l, r = r, t = t, b = b }) then
    return false
  end
  vertex(texture, nil)
  return true
end

-- A ColorMixin for the modern SetGradient, or nil where the client has no CreateColor.
local function colourObject(stop)
  local create = rawget(_G, "CreateColor")
  if type(create) ~= "function" then
    return nil
  end
  local ok, colour = pcall(create, stop.r, stop.g, stop.b, stop.a)
  return ok and colour or nil
end

--- Brief PR23: a solid white texture shaded as a soft glow in a Theme colour, fading out to the
--- left (Skin.GlowStops): the modern SetGradient with two colour objects first, then the classic
--- SetGradientAlpha, each under pcall. Answers "gradient", or false where neither draws (the
--- caller then hides it: a flat wash would read as a band, not a glow).
function Skin.Glow(texture, colourKey)
  if type(texture) ~= "table" or not white(texture, nil) then
    return false
  end
  local from, to = Skin.GlowStops(Skin.Colour(colourKey))
  if not from then
    return false
  end
  vertex(texture, nil)
  if type(texture.SetGradient) == "function" then
    local min, max = colourObject(from), colourObject(to)
    if min and max and pcall(texture.SetGradient, texture, "HORIZONTAL", min, max) then
      return "gradient"
    end
  end
  if type(texture.SetGradientAlpha) == "function" then
    local ok =
      pcall(texture.SetGradientAlpha, texture, "HORIZONTAL", from.r, from.g, from.b, from.a, to.r, to.g, to.b, to.a)
    if ok then
      return "gradient"
    end
  end
  return false
end

--- Brief PR36: draws an atlas in nine pieces over a w by h frame (Skin.NineSlices), the corners
--- style.size px (the entry's own slice texels where style.corner is not given), tinted style.tint
--- (a Theme colour key) where given. The textures are made once under style.store (default
--- "slicePieces") on the BACKGROUND layer at sublevel -6, under anything else the frame draws.
--- Answers whether it drew; false where the art is missing, with nothing shown.
function Skin.NineSlice(frame, key, w, h, style)
  if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then
    return false
  end
  style = type(style) == "table" and style or EMPTY
  local store = style.store or "slicePieces"
  local pieces = rawget(frame, store)
  local info, _, entry = Skin.Resolve(key)
  if not info then
    for _, texture in pairs(type(pieces) == "table" and pieces or EMPTY) do
      texture:Hide()
    end
    return false
  end
  if type(pieces) ~= "table" then
    pieces = {}
    for _, part in ipairs({ "TL", "TOP", "TR", "LEFT", "CENTRE", "RIGHT", "BL", "BOTTOM", "BR" }) do
      local texture = newTexture(frame, style.layer or "BACKGROUND", style.sub or -6)
      if not texture then
        return false
      end
      pieces[part] = texture
    end
    frame[store] = pieces
  end
  local corner = style.corner or (type(entry) == "table" and entry.slice) or 16
  local tint = style.tint and Skin.Colour(style.tint) or nil
  local drawn = false
  for _, piece in ipairs(Skin.NineSlices(info, corner, style.size, w, h)) do
    local texture = pieces[piece.part]
    if piece.w > 0 and piece.h > 0 and paintPiece(texture, info.file, piece) then
      place(texture, frame, piece)
      vertex(texture, tint)
      texture:Show()
      drawn = true
    else
      texture:Hide()
    end
  end
  return drawn
end

--- Brief PR36: Skin.Card's chamfered flat card (never the tooltip border) with its face painted in
--- an atlas: style.art (an Assets key), cut to style.crop or the entry's own crop
--- (Skin.CropCoords), stretched over the card (Skin.FaceCoords) and tinted style.tint. style also
--- takes Skin.Card's fill, edge, thickness, chamfer and store. The corners' small turned squares
--- keep the flat fill. Answers "art", "flat" (the card without its art) or false (no card; the
--- caller draws its own fallback).
function Skin.ArtCard(frame, w, h, style)
  style = type(style) == "table" and style or EMPTY
  local store = style.store or "cardPieces"
  local drawn = Skin.Card(frame, w, h, {
    fill = style.fill,
    edge = style.edge,
    thickness = style.thickness,
    chamfer = style.chamfer,
    store = store,
    art = false,
  })
  if not drawn then
    return false
  end
  local info, _, entry = Skin.Resolve(style.art)
  local pieces = rawget(frame, store)
  local shape = rawget(frame, "cardShape")
  if not (info and type(pieces) == "table" and type(shape) == "table") then
    return "flat"
  end
  local coords = Skin.CropCoords(info, style.crop or (type(entry) == "table" and entry.crop) or nil)
  local tint = style.tint and Skin.Colour(style.tint) or nil
  for index, texture in ipairs(pieces.face or EMPTY) do
    local rect = shape.face[index]
    local piece = rect and Skin.FaceCoords(coords, w, h, rect) or nil
    if piece and paintPiece(texture, info.file, piece) then
      vertex(texture, tint)
    end
  end
  return "art"
end

return Skin
