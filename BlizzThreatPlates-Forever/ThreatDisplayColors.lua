local addon = ForeverNameplates
-- Text has its own palette; changing it must not recolor health bars/borders.
local defaults = {secure={0,1,0}, warning={1,0.82,0}, lost={1,0,0}}
local function Channel(mode)
    return (mode or addon:GetThreatDisplayMode()) == "percentage" and "percentage" or "number"
end
local function Component(value, fallback)
    if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" or value ~= value then return fallback end
    return math.max(0,math.min(1,value))
end
function addon:GetThreatTextColorDefaults(kind)
    return unpack(defaults[kind] or defaults.lost)
end
function addon:GetThreatTextColor(kind, mode)
    local fallback = defaults[kind] or defaults.lost
    local settings = ForeverNameplatesDB and ForeverNameplatesDB.threatTextColors
    local palette = type(settings) == "table" and settings[Channel(mode)]
    local color = type(palette) == "table" and palette[kind]
    if type(color) ~= "table" then return unpack(fallback) end
    return Component(color[1],fallback[1]),Component(color[2],fallback[2]),Component(color[3],fallback[3])
end
function addon:SetThreatTextColor(kind, r, g, b, mode)
    if not defaults[kind] then return end
    local channel = Channel(mode)
    local fallback = defaults[kind]
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    local settings = ForeverNameplatesDB.threatTextColors
    if type(settings) ~= "table" then settings={}; ForeverNameplatesDB.threatTextColors=settings end
    if type(settings[channel]) ~= "table" then settings[channel]={} end
    settings[channel][kind] = {Component(r,fallback[1]),Component(g,fallback[2]),Component(b,fallback[3])}
    if self.RefreshThreatDifferential then self:RefreshThreatDifferential()
    elseif self.RefreshThreatPercentages then self:RefreshThreatPercentages() end
end
