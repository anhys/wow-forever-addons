-- Brief OPT4: the Professions tab's small client helpers, the one copy of what UI/Queue.lua,
-- UI/Pane.lua, UI/Trainers.lua, UI/Bar.lua and UI/Skin.lua each carried. Every helper here was byte
-- for byte (or in meaning) the same in each file that now takes it; the comment over each names
-- them. A copy that differed in any way stayed in its own file:
--
--   newFrame      stays in every file, so tests/spec/taint_lint_spec.lua still sees each file's
--                 own CreateFrame wrapper and checks the parents handed to it there.
--   setScript     each names its own file in the Guard's place ("Professions.Queue." and so on).
--   applyAsset    UI/Bar.lua's asks Assets.Has without first checking the key, and its wash
--   and wash      draws through that applyAsset, so both stay there.
--   edges         UI/Pane.lua's lays no points and takes no colour key.
--   the font kit  each file's falls back through its own FONT_FALLBACKS.
--
-- Loaded before UI/Queue.lua, the first file that takes from it (ItemTree_Professions.toc). Every
-- helper reads ItemTree's modules when it is called, never as this file loads, so a spec's fake
-- Theme or Assets is what answers.
local _, ItemTree = ...
-- ItemTree_Professions is an addon of its own: its files belong in ItemTree's namespace.
if type(ItemTree) ~= "table" or type(ItemTree.Modules) ~= "table" then
  ItemTree = rawget(_G, "ItemTree") or ItemTree
end

local Kit = {}
ItemTree.ProfessionsKit = Kit

local EMPTY = {}

-- Theme's size table, or an empty one where Theme is not loaded. UI/Bar.lua, UI/Pane.lua,
-- UI/Queue.lua and UI/Trainers.lua, each as it loads.
function Kit.ThemeSizes()
  local theme = ItemTree.Theme
  return type(theme) == "table" and type(theme.sizes) == "table" and theme.sizes or EMPTY
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

-- ItemTree's modules, each nil where it is not a table. Theme: UI/Pane.lua, UI/Queue.lua,
-- UI/Skin.lua, UI/Trainers.lua. Assets: those four and UI/Bar.lua. Skin: UI/Bar.lua, UI/Pane.lua,
-- UI/Queue.lua, UI/Trainers.lua. Pane: UI/Queue.lua, UI/Trainers.lua.
local function theme()
  local found = ItemTree.Theme
  return type(found) == "table" and found or nil
end
Kit.Theme = theme

local function assets()
  local found = ItemTree.Assets
  return type(found) == "table" and found or nil
end
Kit.Assets = assets

function Kit.Skin()
  local found = ItemTree.ProfessionsSkin
  return type(found) == "table" and found or nil
end

function Kit.Pane()
  local professions = ItemTree.Professions
  local found = type(professions) == "table" and professions.pane or nil
  return type(found) == "table" and found or nil
end

-- Theme's colour table for a key, or nil. UI/Bar.lua, UI/Pane.lua, UI/Queue.lua, UI/Trainers.lua.
local function colourOf(key)
  local t = theme()
  if not (t and key and type(t.ColorTable) == "function") then
    return nil
  end
  local ok, colour = pcall(t.ColorTable, key)
  return ok and type(colour) == "table" and colour or nil
end
Kit.ColourOf = colourOf

-- Brief PM1 (brief G1 reaching the Professions code): every script body set through a file's
-- setScript runs under ItemTree.Guard.Run, the boundary main's panes use, so a fault in one is
-- handed to the client's error handler once and the rest of the tab keeps working. Only
-- ItemTree's own handlers on ItemTree's own frames are wrapped. UI/Bar.lua, UI/Pane.lua,
-- UI/Queue.lua and UI/Trainers.lua.
function Kit.GuardScript(where, handler)
  if type(handler) ~= "function" then
    return handler
  end
  return function(...)
    local Guard = ItemTree.Guard
    if type(Guard) == "table" and type(Guard.Run) == "function" then
      Guard.Run(where, handler, ...)
      return
    end
    return handler(...)
  end
end

-- Shows or hides a frame or region. UI/Pane.lua, UI/Queue.lua and UI/Trainers.lua.
function Kit.SetShown(object, shown)
  if type(object) ~= "table" then
    return false
  end
  local method = shown and object.Show or object.Hide
  if type(method) ~= "function" then
    return false
  end
  return (pcall(method, object))
end

-- A texture tinted to a Theme colour key. UI/Bar.lua, UI/Pane.lua, UI/Queue.lua, UI/Trainers.lua.
local function tint(texture, key)
  local colour = colourOf(key)
  if not colour or type(texture) ~= "table" or type(texture.SetVertexColor) ~= "function" then
    return false
  end
  texture:SetVertexColor(colour.r, colour.g, colour.b, colour.a or 1)
  return true
end
Kit.Tint = tint

-- A FontString's colour from a Theme colour key, alpha 1. UI/Pane.lua, UI/Queue.lua and
-- UI/Trainers.lua.
local function textColour(fontString, key)
  local colour = colourOf(key)
  if not colour or type(fontString) ~= "table" or type(fontString.SetTextColor) ~= "function" then
    return false
  end
  fontString:SetTextColor(colour.r, colour.g, colour.b, 1)
  return true
end
Kit.TextColour = textColour

-- An Assets key put on a texture. UI/Pane.lua, UI/Queue.lua and UI/Trainers.lua.
local function applyAsset(texture, key)
  local a = assets()
  if not (a and texture and key and type(a.Has) == "function" and a.Has(key)) then
    return false
  end
  local ok, applied = pcall(a.Apply, texture, key)
  return ok and applied ~= false
end
Kit.ApplyAsset = applyAsset

-- A texture on a frame of ours, or nil. UI/Bar.lua, UI/Pane.lua, UI/Queue.lua, UI/Trainers.lua.
local function newTexture(parent, layer, sub)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end
  local ok, texture = pcall(parent.CreateTexture, parent, nil, layer, nil, sub)
  if ok and type(texture) == "table" then
    return texture
  end
  return nil
end
Kit.NewTexture = newTexture

-- A flat white texture tinted to a Theme colour key. UI/Pane.lua, UI/Queue.lua, UI/Trainers.lua.
local function wash(parent, layer, colourKey, sub)
  local texture = newTexture(parent, layer, sub)
  if not texture then
    return nil
  end
  applyAsset(texture, "FILL_WHITE8X8")
  tint(texture, colourKey)
  return texture
end
Kit.Wash = wash

-- Four hairline edges, the flat fallback where the card will not draw. UI/Queue.lua and
-- UI/Trainers.lua.
function Kit.Edges(frame, colourKey)
  local out = {}
  for index = 1, 4 do
    out[index] = wash(frame, "BORDER", colourKey)
    if not out[index] then
      return nil
    end
  end
  local top, bottom, left, right = out[1], out[2], out[3], out[4]
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(1)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(1)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(1)
  return out
end

-- A FontString's drawn width when above 0, or nil. UI/Pane.lua and UI/Trainers.lua.
function Kit.StringWidth(fontString)
  if type(fontString) ~= "table" or type(fontString.GetStringWidth) ~= "function" then
    return nil
  end
  local ok, width = pcall(fontString.GetStringWidth, fontString)
  width = ok and tonumber(width) or nil
  if width and width > 0 then
    return width
  end
  return nil
end

-- Hides the client's GameTooltip. UI/Bar.lua, UI/Pane.lua, UI/Queue.lua and UI/Trainers.lua.
function Kit.HideTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    pcall(tooltip.Hide, tooltip)
  end
end

return Kit
