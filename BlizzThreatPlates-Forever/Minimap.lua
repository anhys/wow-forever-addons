local addonName = ...
local addon = ForeverNameplates

local button = CreateFrame("Button", "ForeverNameplatesMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")

local icon = button:CreateTexture(nil, "BACKGROUND")
-- Keep the artwork at the original minimap icon size inside Blizzard's rim.
icon:SetTexture("Interface\\AddOns\\" .. (addonName or "BlizzThreatPlates-Forever") .. "\\media\\ThreatSignalMinimap.tga")
icon:SetTexCoord(0.11, 0.87, 0.12, 0.88)
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

-- Keep the button centered on a ring just OUTSIDE the minimap edge.
-- The old fixed radius of 80 placed it partly inside larger/scaled minimaps.
local BUTTON_HALF = 10
local EDGE_GAP = -2

local function GetRingRadius()
    -- Minimap width/height themselves are safe here; this runs on our UI button,
    -- not while scanning nameplate frames.
    local w = Minimap:GetWidth() or 140
    local h = Minimap:GetHeight() or 140
    return (math.max(w, h) * 0.5) + BUTTON_HALF + EDGE_GAP
end

local function SetPosition(angle)
    local rad = math.rad(angle or 225)
    local radius = GetRingRadius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * radius,
        math.sin(rad) * radius)
end

local function MouseAngle()
    local mx, my = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    mx, my = mx / scale, my / scale
    local cx, cy = Minimap:GetCenter()
    return math.deg(math.atan2(my - cy, mx - cx))
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local angle = MouseAngle()
        ForeverNameplatesDB.minimap.angle = angle
        SetPosition(angle)
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function()
    addon:ToggleOptions()
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BlizzThreatPlates-Forever")
    GameTooltip:AddLine("Click: Threat color settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("UI_SCALE_CHANGED")
init:RegisterEvent("DISPLAY_SIZE_CHANGED")
init:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ForeverNameplatesDB = ForeverNameplatesDB or {}
        ForeverNameplatesDB.minimap = ForeverNameplatesDB.minimap or {angle=225}
    end
    local angle = ForeverNameplatesDB and ForeverNameplatesDB.minimap
        and ForeverNameplatesDB.minimap.angle or 225
    SetPosition(angle)
    if addon:GetMinimapVisible() then button:Show() else button:Hide() end
end)
