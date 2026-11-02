-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local events = CreateFrame("Frame")
local native, button, installed, failed, restorePending
local T = NS.Text
function NS.CustomRefreshDisabled() return failed == true end
local function Tooltip()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT"); GameTooltip:SetText(T("BROWSE_REFRESH"))
    GameTooltip:AddLine(NS.LanguageLabel(NS.Mode()), 1, .82, 0, true)
    local enabled, key, remaining = NS.SearchButtonState()
    if not enabled then GameTooltip:AddLine(remaining and T(key, remaining) or T(key), 1, 1, 1, true)
    elseif NS.statusKind == "error" then GameTooltip:AddLine(T("BROWSE_SEARCH_FAILED"), 1, .4, .3, true)
    elseif NS.SearchSelectionIsCurrent() then GameTooltip:AddLine(T("BROWSE_REFRESH_HINT"), 1, 1, 1, true)
    elseif NS.statusKey == "NATIVE_COMPLETE" or NS.statusKey == "LANGUAGE_UNCONFIRMED" then GameTooltip:AddLine(T("BROWSE_NATIVE_REFRESH"), 1, .82, 0, true)
    else GameTooltip:AddLine(T("BROWSE_REFRESH_DIRTY"), 1, .82, 0, true) end
    GameTooltip:Show()
end
local function Restore()
    if InCombatLockdown() then restorePending = true; return end
    restorePending = nil
    if button then button:Hide() end
    if installed and native then
        local ok, err = pcall(function() native:SetSize(32, 32); native:Show() end)
        if not ok then NS.Log("Error", "Could not restore game refresh: " .. tostring(err), true); return end
    end
    installed = nil
end
function NS.DisableCustomRefresh(reason)
    if failed then return end
    failed = true
    if button then button:SetEnabled(false) end
    NS.Log("Error", "Custom refresh disabled; game refresh retained: " .. tostring(reason), true)
    Restore()
end
function NS.UpdateRefreshUI()
    if not installed or failed or not button then return end
    if native:IsShown() then NS.DisableCustomRefresh("game button was shown again"); return end
    local enabled = NS.SearchButtonState()
    button:SetEnabled(enabled)
    local pending = NS.IsPending()
    local dirty = not pending and not NS.SearchSelectionIsCurrent()
    button:SetText(T(pending and "SEARCHING" or "BROWSE_REFRESH"))
    button:GetFontString():SetTextColor(1, dirty and .82 or 1, dirty and .1 or 1)
    button.Icon:SetVertexColor(1, dirty and .82 or 1, dirty and .1 or 1)
    button.Icon:SetAlpha(pending and .4 or 1)
    button.Dirty:SetShown(dirty and enabled)
    if button:IsMouseOver() then Tooltip() end
end
local function Install()
    if installed or failed or InCombatLockdown() then return end
    if NS.BrowseLayoutFailed() then return end
    local browse = LFGBrowseFrame
    if not browse or not browse.RefreshButton or not NS.SettingsPanel then return end
    native = browse.RefreshButton
    local ok, safe = pcall(function()
        if not NS.CanChangeFrame(native) then return false end
        return native:IsShown()
    end)
    if not ok or not safe then NS.DisableCustomRefresh("button unavailable or protected"); return end
    button = CreateFrame("Button", "ForeverLFGRefreshButton", browse, "UIPanelButtonTemplate")
    button:SetAllPoints(native); button:SetFrameLevel(native:GetFrameLevel() + 1)
    button:SetText(T("BROWSE_REFRESH"))
    local label = button:GetFontString()
    label:ClearAllPoints(); label:SetPoint("LEFT", button, "LEFT", 27, 0); label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.Icon = button:CreateTexture(nil, "ARTWORK", nil, 5)
    button.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton"); button.Icon:SetSize(16, 16); button.Icon:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.Dirty = button:CreateTexture(nil, "OVERLAY")
    button.Dirty:SetAllPoints(button); button.Dirty:SetColorTexture(1, .75, .05, .12)
    button:RegisterForClicks("LeftButtonUp"); button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", Tooltip); button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        if failed then return end
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        NS.Request(nil, nil, false, "refresh-button")
        NS.UpdateRefreshUI()
    end)
    local elapsed = 0
    button:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta; if elapsed < .25 then return end
        elapsed = 0; NS.UpdateRefreshUI()
    end)
    button:Hide(); installed = true
    local hidden, err = pcall(native.Hide, native)
    if not hidden or native:IsShown() then NS.DisableCustomRefresh(err or "Hide did not hide game button"); return end
    NS.Log("UI", "Native browse extended; manual refresh uses selected languages; automatic searches unchanged")
    button:Show(); NS.UpdateRefreshUI()
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function() if restorePending then Restore() end; Install(); NS.UpdateRefreshUI() end)
