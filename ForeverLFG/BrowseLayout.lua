-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local addonName, NS = ...
local F = NS.Filters
local layout, busy, pending, failed
local saved = {}
local events = CreateFrame("Frame")

function NS.CanChangeFrame(frame)
    if not frame or InCombatLockdown() then return false end
    local ok, safe = pcall(function()
        if frame.IsForbidden and F.Plain(frame:IsForbidden()) then return false end
        if frame.IsProtected and F.Plain(frame:IsProtected()) then return false end
        return true
    end)
    return ok and safe
end

function NS.CaptureGeometry(frame, restoreShown)
    if not frame or saved[frame] then return end
    if not NS.CanChangeFrame(frame) then error("Native frame is unavailable or protected") end
    local value = {width = F.Plain(frame:GetWidth(), "number"), height = F.Plain(frame:GetHeight(), "number"), shown = frame:IsShown(), restoreShown = restoreShown, points = {}}
    for i = 1, frame:GetNumPoints() do value.points[i] = {frame:GetPoint(i)} end
    saved[frame] = value
    return value
end

local function Restore(frame, value)
    if not NS.CanChangeFrame(frame) then error("Cannot restore native frame") end
    frame:ClearAllPoints()
    frame:SetSize(value.width, value.height)
    for _, point in ipairs(value.points) do frame:SetPoint(unpack(point)) end
    if value.restoreShown then frame:SetShown(value.shown) end
end

function NS.BrowseLayoutActive() return layout and layout.active and not failed end
function NS.BrowseLayoutFailed() return failed end

local function AnchorScroll()
    if busy or not NS.BrowseLayoutActive() or InCombatLockdown() then return end
    busy = true
    local ok, err = pcall(function()
        local browse, region = layout.browse, layout.region
        if not NS.CanChangeFrame(browse.ScrollBox) then error("ScrollBox became protected") end
        local right = browse.ScrollBar and browse.ScrollBar:IsShown() and (browse.ScrollBox.ScrollBarWidth or 16) or 0
        browse.ScrollBox:ClearAllPoints()
        browse.ScrollBox:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
        browse.ScrollBox:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, 0)
    end)
    busy = false
    if not ok or failed then NS.DisableBrowseLayout(err or "scroll geometry operation blocked") end
end

function NS.DisableBrowseLayout(reason)
    local first = not failed
    failed, pending = true, true
    if first then NS.Log("Error", "Native browse extension disabled: " .. tostring(reason), true) end
    if layout and layout.panel then layout.panel:Hide() end
    if NS.ActivityLevelsHint then NS.ActivityLevelsHint:Hide() end
    if NS.ActivityLevelsCheck then NS.ActivityLevelsCheck:Hide() end
    if NS.DisableCustomRefresh then NS.DisableCustomRefresh("browse layout unavailable") end
    if not busy and not InCombatLockdown() and layout then
        busy = true
        for frame, value in pairs(saved) do pcall(Restore, frame, value) end
        layout.active, busy, pending = false, false, nil
        if F.Refresh then F.Refresh() end
    end
end

local function PositionPanels()
    if UpdateUIPanelPositions then UpdateUIPanelPositions(layout.parent) end
end

local function Apply()
    if not layout or busy then return end
    if InCombatLockdown() then pending = true; return end
    busy, pending = true, nil
    local ok, err = pcall(function()
        local b, parent = layout.browse, layout.parent
        local show = b:IsShown() and parent:IsShown() and not failed
        if not show then
            if layout.active then
                layout.active = false
                for frame, value in pairs(saved) do Restore(frame, value) end
                PositionPanels()
            end
            layout.panel:Hide()
            if NS.ActivityLevelsHint then NS.ActivityLevelsHint:Hide() end
            if NS.ActivityLevelsCheck then NS.ActivityLevelsCheck:Hide() end
            return
        end
        for frame in pairs(saved) do if not NS.CanChangeFrame(frame) then error("Native layout unavailable") end end
        local maxLeft, available = math.max(528, saved[parent].width), UIParent:GetWidth() - 80
        local right, left = 278, maxLeft
        if available < left + right then right, left = 260, math.min(maxLeft, available - 260) end
        if left < saved[parent].width then error("Screen too narrow for native browse extension") end
        layout.leftWidth, layout.panelWidth = left, right
        layout.active = true
        parent:SetWidth(layout.leftWidth + layout.panelWidth)
        if failed or math.abs(F.Plain(parent:GetWidth(), "number") - layout.leftWidth - layout.panelWidth) > 1 then
            error("Native window width was not applied")
        end
        local panel = layout.panel
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", b, "TOPLEFT", layout.leftWidth + 4, -38)
        panel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 10)
        panel:Show()
        b.CategoryDropdown:ClearAllPoints(); b.CategoryDropdown:SetPoint("LEFT", b, "TOPLEFT", 46, -54); b.CategoryDropdown:SetSize(118, 24)
        b.ActivityDropdown:ClearAllPoints(); b.ActivityDropdown:SetPoint("LEFT", b.CategoryDropdown, "RIGHT", 12, 0); b.ActivityDropdown:SetSize(layout.leftWidth - 338, 24)
        b.RefreshButton:ClearAllPoints(); b.RefreshButton:SetPoint("LEFT", b.ActivityDropdown, "RIGHT", 14, 0)
        local fallback = NS.CustomRefreshDisabled and NS.CustomRefreshDisabled()
        b.RefreshButton:SetSize(fallback and 32 or 126, fallback and 32 or 24)
        local headerBottom = NS.LayoutActivityOptions and NS.LayoutActivityOptions(layout.leftWidth) or 100
        local region = layout.region
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -headerBottom-4)
        region:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 7, 10)
        region:SetWidth(layout.leftWidth - 14)
        -- In Mainline XML the inset border and stone header follow this art,
        -- independently of BarTop. Move their shared boundary below the whole
        -- checkbox row; moving only BarTop leaves a border through its label.
        if b.BackgroundArt then
            b.BackgroundArt:ClearAllPoints()
            b.BackgroundArt:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -headerBottom)
            b.BackgroundArt:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", layout.leftWidth - 4, 3)
        end
        -- The inset already frames the results. Avoid a second line below it.
        for _, key in ipairs({"OptionsButton", "BarTop", "BarMiddle", "SendMessageButton", "GroupInviteButton"}) do if b[key] then b[key]:Hide() end end
        if b.NoResultsFound then b.NoResultsFound:ClearAllPoints(); b.NoResultsFound:SetPoint("CENTER", region, "CENTER", 0, 0) end
        if b.SearchingSpinner then b.SearchingSpinner:ClearAllPoints(); b.SearchingSpinner:SetPoint("CENTER", region, "CENTER", 0, 0) end
        PositionPanels()
        if failed then error("Native geometry operation blocked") end
    end)
    busy = false
    if not ok or failed then NS.DisableBrowseLayout(err or "geometry operation blocked"); return end
    AnchorScroll()
    if NS.LayoutSettingsPanel then NS.LayoutSettingsPanel() end
    if F.Refresh then F.Refresh() end
    if NS.UpdateActivityOptions then NS.UpdateActivityOptions() end
end

function NS.AttachBrowsePanel(panel)
    if layout then return layout end
    local b, parent = LFGBrowseFrame, LFGParentFrame
    if not b or not parent or not b.ScrollBox or not b.CategoryDropdown or not b.ActivityDropdown or not b.RefreshButton then return end
    local ok, err = pcall(function()
        for _, frame in ipairs({parent, b.ScrollBox, b.CategoryDropdown, b.ActivityDropdown, b.RefreshButton}) do NS.CaptureGeometry(frame) end
        for _, key in ipairs({"BackgroundArt", "OptionsButton", "BarTop", "BarMiddle", "SendMessageButton", "GroupInviteButton", "NoResultsFound", "SearchingSpinner"}) do
            if b[key] then NS.CaptureGeometry(b[key], key == "OptionsButton" or key == "BarTop" or key == "BarMiddle" or key == "SendMessageButton" or key == "GroupInviteButton") end
        end
    end)
    if not ok then NS.DisableBrowseLayout(err); return end
    local region = CreateFrame("Frame", nil, b)
    layout = {browse = b, parent = parent, region = region, panel = panel, leftWidth = math.max(528, parent:GetWidth()), panelWidth = 278}
    NS.BrowseListRegion = region
    -- Blizzard повторно применяет захваченные OnLoad-якоря при появлении scrollbar.
    -- Наблюдаем обе схемы после SetPoint, не заменяя factory/visibility behavior.
    hooksecurefunc(b.ScrollBox, "SetPoint", AnchorScroll)
    b:HookScript("OnShow", Apply)
    b:HookScript("OnHide", Apply)
    parent:HookScript("OnHide", Apply)
    parent:HookScript("OnShow", Apply)
    if LFGListingFrame then LFGListingFrame:HookScript("OnShow", function() if not b:IsShown() then Apply() end end) end
    if LFGWhoListFrame then LFGWhoListFrame:HookScript("OnShow", function() if not b:IsShown() then Apply() end end) end
    panel:HookScript("OnSizeChanged", function() if NS.LayoutSettingsPanel then NS.LayoutSettingsPanel() end end)
    Apply()
    if failed then return end
    return layout
end

for _, event in ipairs({"PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, owner, operation)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if owner == addonName and type(operation) == "string" then
            for _, method in ipairs({"SetPoint", "SetWidth", "SetHeight", "SetSize", "SetParent"}) do
                if operation:find(method, 1, true) then NS.DisableBrowseLayout(operation); break end
            end
        end
        return
    end
    if failed then
        if pending and not InCombatLockdown() and layout then
            busy = true; for frame, value in pairs(saved) do pcall(Restore, frame, value) end
            layout.active, busy, pending = false, false, nil
        end
    else Apply() end
end)
