-- The Professions tab's layout (brief PR7): where every band, node, link and the "you are here"
-- line sits on the canvas, worked out from one line's track (Core\Professions.lua Model.Track) and
-- a table of sizes. Pure: no client call anywhere in this file, so busted runs all of it.
--
--   Layout.Bands(track, sizes, opts)
--     { width, height,
--       columns = { { band, index, x, w, header = rect,
--                     nodes = { { node, x, y, w, h, route, recommended } },
--                     more = { x, y, w, h, count } or nil, hidden, others } },
--       links = { { from = nodeRect, to = nodeRect } },
--       marker = { x, y, h } or nil,
--       current = the index of the player's own band's column, or nil }
--
-- Brief PR13: a node's height can vary (opts.heightOf(item), a reagent list that wraps to a second
-- row), and the marker is no longer drawn as a line over the cards: the pane marks the current
-- band's header (column.current, column.tickX, the rank's place along that header) instead.
--
-- Bands are columns, left to right in band order. Inside a band the nodes stack downwards: the
-- route nodes first, in route order (Model.Track already puts them there), then the rest. A band
-- whose other recipes run past sizes.collapse shows the route and the first collapse others, then
-- a "Show N more" row; opts.expanded[bandIndex] shows them all. The content height is the tallest
-- column's.
--
-- The links join each band's first route node to the next band's first route node (a band with
-- no route is stepped over), so the recommended path reads as a chain, the way the Item chain tab
-- joins its stages.
--
-- The marker is the player's rank on the canvas: inside the current band it is interpolated by
-- rank from the band's left edge (at lo) to its right edge (at hi); below the first band it sits
-- on the first band's left edge, and at or past the last band's hi on the last band's right edge.
--
-- Gathering lines carry spots rather than nodes: each spot is laid out as a node { spot = spot }
-- and none is on the route, so a gathering line has no links.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Layout = {}
ItemTree.ProfessionsLayout = Layout

local EMPTY = {}

-- The defaults, in pixels, for a sizes table that leaves any of them out. UI\Pane.lua passes its
-- own, built from Theme tokens.
Layout.DEFAULTS = {
  colW = 200, -- one band's width
  gap = 44, -- between two bands: the chain tab's gap plus its arrow
  header = 40, -- the band header, label and note
  nodeH = 48, -- one node: icon and name, then the reagent row
  nodeGap = 4, -- between two nodes
  pad = 8, -- round the whole content
  moreH = 22, -- the "Show N more" row
  collapse = 6, -- how many non route nodes a band shows before it collapses the rest
}

local function size(sizes, key)
  local value = tonumber(sizes[key])
  if value == nil or value < 0 then
    return Layout.DEFAULTS[key]
  end
  return value
end

local function copyRect(rect)
  return { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
end

--- The things a band lays out, in order: a craft band's nodes, or a gather band's spots as
--- { spot = spot } nodes. Pure.
function Layout.Items(band, kind)
  if type(band) ~= "table" then
    return {}
  end
  if kind == "gather" or (type(band.spots) == "table" and #(band.nodes or EMPTY) == 0) then
    local out = {}
    for _, spot in ipairs(type(band.spots) == "table" and band.spots or EMPTY) do
      if type(spot) == "table" then
        out[#out + 1] = { spot = spot, route = false }
      end
    end
    return out
  end
  local out = {}
  for _, node in ipairs(type(band.nodes) == "table" and band.nodes or EMPTY) do
    if type(node) == "table" then
      out[#out + 1] = node
    end
  end
  return out
end

--- Which of a band's items are drawn: every route node, then the first `collapse` others, or all
--- of them when expanded. Answers the drawn list, how many others are held back, and how many
--- others there are in all. Pure.
function Layout.Visible(items, collapse, expanded)
  collapse = tonumber(collapse) or Layout.DEFAULTS.collapse
  local shown, others, hidden = {}, 0, 0
  for _, item in ipairs(type(items) == "table" and items or EMPTY) do
    -- Brief PR49b: a re-planned band's alternatives (alt) are held on screen like the route.
    if item.route == true or item.alt == true then
      shown[#shown + 1] = item
    else
      others = others + 1
      if expanded or others <= collapse then
        shown[#shown + 1] = item
      else
        hidden = hidden + 1
      end
    end
  end
  return shown, hidden, others
end

--- Brief PR49b: whether a node wears the Recommended tag and starts the arrow: its own
--- recommended where the model says (Model.Track), else whether it is on the route, as before.
--- Pure.
function Layout.Recommended(node)
  if type(node) ~= "table" then
    return false
  end
  if node.recommended ~= nil then
    return node.recommended == true
  end
  return node.route == true
end

--- The marker's x for a rank against laid out columns, or nil with no columns. Pure.
function Layout.MarkerX(columns, rank)
  if type(columns) ~= "table" or #columns == 0 then
    return nil
  end
  rank = tonumber(rank) or 0
  local first, last = columns[1], columns[#columns]
  local firstLo = tonumber(first.band and first.band.lo) or 0
  if rank <= firstLo then
    return first.x
  end
  for _, column in ipairs(columns) do
    local lo = tonumber(column.band and column.band.lo) or 0
    local hi = tonumber(column.band and column.band.hi) or lo
    if rank >= lo and rank < hi then
      local span = hi - lo
      if span <= 0 then
        return column.x
      end
      return column.x + column.w * (rank - lo) / span
    end
  end
  return last.x + last.w
end

--- The column a rank falls in: its index, or nil below the first band's lo or at or past the last
--- band's hi. Pure.
function Layout.CurrentIndex(columns, rank)
  rank = tonumber(rank)
  if type(columns) ~= "table" or rank == nil then
    return nil
  end
  for index, column in ipairs(columns) do
    local lo = tonumber(column.band and column.band.lo) or 0
    local hi = tonumber(column.band and column.band.hi) or lo
    if rank >= lo and rank < hi then
      return index
    end
  end
  return nil
end

--- The whole canvas for one line's track. sizes: colW, gap, header, nodeH, nodeGap, pad, moreH,
--- collapse (Layout.DEFAULTS fills any left out). opts: rank (for the marker; no rank, no
--- marker), expanded = { [bandIndex] = true }, heightOf(item) a node's own height (nodeH where it
--- answers nothing). Pure.
function Layout.Bands(track, sizes, opts)
  sizes = type(sizes) == "table" and sizes or EMPTY
  opts = type(opts) == "table" and opts or EMPTY
  local colW, gap = size(sizes, "colW"), size(sizes, "gap")
  local header, nodeH, nodeGap = size(sizes, "header"), size(sizes, "nodeH"), size(sizes, "nodeGap")
  local pad, moreH, collapse = size(sizes, "pad"), size(sizes, "moreH"), size(sizes, "collapse")
  local expanded = type(opts.expanded) == "table" and opts.expanded or EMPTY
  local heightOf = type(opts.heightOf) == "function" and opts.heightOf or nil
  local bands = type(track) == "table" and type(track.bands) == "table" and track.bands or EMPTY
  local kind = type(track) == "table" and track.kind or nil

  local out = { columns = {}, links = {}, width = pad * 2, height = pad * 2 }
  local x = pad
  local bottom = pad
  for index, band in ipairs(bands) do
    local column = {
      band = band,
      index = index,
      x = x,
      w = colW,
      header = { x = x, y = pad, w = colW, h = header },
      nodes = {},
    }
    local shown, hidden, others = Layout.Visible(Layout.Items(band, kind), collapse, expanded[index] == true)
    column.hidden, column.others = hidden, others
    local y = pad + header + nodeGap
    for _, node in ipairs(shown) do
      local h = heightOf and tonumber(heightOf(node)) or nil
      if h == nil or h <= 0 then
        h = nodeH
      end
      column.nodes[#column.nodes + 1] = {
        node = node,
        x = x,
        y = y,
        w = colW,
        h = h,
        route = node.route == true,
        recommended = Layout.Recommended(node),
      }
      y = y + h + nodeGap
    end
    if hidden > 0 or (expanded[index] == true and others > collapse) then
      column.more = { x = x, y = y, w = colW, h = moreH, count = hidden, expanded = hidden == 0 }
      y = y + moreH + nodeGap
    end
    column.bottom = y
    if y > bottom then
      bottom = y
    end
    out.columns[#out.columns + 1] = column
    x = x + colW + gap
  end
  if #out.columns > 0 then
    out.width = x - gap + pad
    out.height = bottom - nodeGap + pad
  end

  -- The recommended path: each band's first Recommended node to the next band that has one
  -- (brief PR49b: never a route recipe with no points in its band).
  local previous = nil
  for _, column in ipairs(out.columns) do
    local first = nil
    for _, rect in ipairs(column.nodes) do
      if rect.recommended then
        first = rect
        break
      end
    end
    if first then
      if previous then
        out.links[#out.links + 1] = { from = copyRect(previous), to = copyRect(first) }
      end
      previous = first
    end
  end

  local rank = tonumber(opts.rank)
  if rank ~= nil then
    local markerX = Layout.MarkerX(out.columns, rank)
    if markerX then
      out.marker = { x = markerX, y = pad, h = out.height - pad * 2 }
    end
    local current = Layout.CurrentIndex(out.columns, rank)
    if current then
      local column = out.columns[current]
      column.current = true
      column.tickX = markerX
      out.current = current
    end
  end
  return out
end

return Layout
