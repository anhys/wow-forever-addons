-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local T = NS.Text

function NS.BrowseHelp(owner, title, detail)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if detail then GameTooltip:AddLine(detail, 1, 1, 1, true) end
    GameTooltip:Show()
end

function NS.CreateSettingsDropdown(name, parent, y, caption)
    -- Intrinsic dropdowns own mouse-down/global-click coordination and menu lifetime.
    local button = CreateFrame("DropdownButton", name, parent)
    button:SetHeight(24)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", caption and 78 or 8, -y)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -y)
    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAtlas("common-dropdown-textholder", true)
    button.Background:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 7)
    button.Background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -9)
    button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Label:SetPoint("LEFT", button, "LEFT", 5, -1)
    button.Label:SetPoint("RIGHT", button, "RIGHT", -23, -1)
    button.Label:SetJustifyH("LEFT"); button.Label:SetWordWrap(false)
    button.Arrow = button:CreateTexture(nil, "ARTWORK")
    button.Arrow:SetAtlas("common-dropdown-a-button", true)
    button.Arrow:SetPoint("RIGHT", button, "RIGHT", 1, -3)
    if caption then
        button.Caption = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.Caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y - 6)
        button.Caption:SetWidth(70); button.Caption:SetJustifyH("LEFT"); button.Caption:SetWordWrap(false)
        button.Caption:SetText(T(caption))
    end
    button:SetScript("OnEnter", function(self) NS.BrowseHelp(self, self.Label:GetText()) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function NS.LayoutSettingsPanel()
    local panel = NS.SettingsPanel
    if not panel or not panel.Viewport or panel.layingOut then return end
    panel.layingOut = true
    local viewport = panel.Viewport
    local height = panel.contentHeight or 1
    local overflow = height > viewport:GetHeight()
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    viewport:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", overflow and -24 or -8, 4)
    panel.Content:SetWidth(math.max(1, viewport:GetWidth()))
    panel.Content:SetHeight(math.max(1, height))
    viewport:UpdateScrollChildRect()
    viewport:SetVerticalScroll(math.min(viewport:GetVerticalScroll(), math.max(0, height - viewport:GetHeight())))
    panel.ScrollBar:SetShown(overflow)
    panel.layingOut = false
end

function NS.EnsureSettingsPanel()
    if NS.SettingsPanel then return NS.SettingsPanel end
    if InCombatLockdown() or NS.BrowseLayoutFailed() then return end
    local browse = LFGBrowseFrame
    if not browse or not LFGParentFrame or not browse.ScrollBox or not MenuUtil or not ScrollUtil or not ScrollUtil.InitScrollFrameWithScrollBar then return end
    if not LFGParentFrame.ListingTab or not LFGParentFrame.BrowsingTab or not LFGParentFrame.WhoListingTab then
        NS.DisableBrowseLayout("unsupported native navigation layout"); return
    end
    local panel = CreateFrame("Frame", "ForeverLFGSettingsPanel", browse)
    panel:Hide()
    panel:SetFrameLevel(browse:GetFrameLevel() + 2)
    panel:EnableMouse(true)
    panel.Background = panel:CreateTexture(nil, "BACKGROUND")
    panel.Background:SetAllPoints(panel); panel.Background:SetColorTexture(.025, .022, .018, .97)
    panel.Divider = panel:CreateTexture(nil, "BORDER")
    panel.Divider:SetColorTexture(.55, .39, .12, 1); panel.Divider:SetWidth(1)
    panel.Divider:SetPoint("TOPLEFT", panel, "TOPLEFT", -5, 0)
    panel.Divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -5, 0)
    local viewport = CreateFrame("ScrollFrame", "ForeverLFGSettingsScrollFrame", panel)
    panel.Viewport = viewport
    viewport:EnableMouseWheel(true)
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    viewport:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 4)
    local content = CreateFrame("Frame", nil, viewport)
    panel.Content = content
    content:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    content:SetSize(250, 1)
    viewport:SetScrollChild(content)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    panel.ScrollBar = scrollBar
    scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    ScrollUtil.InitScrollFrameWithScrollBar(viewport, scrollBar)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) scrollBar:ScrollStepInDirection(-delta) end)
    NS.SettingsPanel = panel
    if not NS.AttachBrowsePanel(panel) then NS.SettingsPanel = nil; panel:Hide(); return end
    -- Cosmetic only: keep the native side-tab frame, mask and click behavior.
    -- An unavailable/protected icon must not prevent the search panel loading.
    local tab = LFGParentFrame.BrowsingTab
    local icon = tab.Icon
    if icon and NS.CanChangeFrame(tab) and NS.CanChangeFrame(icon) then
        pcall(function()
            icon:SetTexture("Interface\\AddOns\\ForeverLFG\\Media\\SearchGlobe.tga")
            -- SetChecked reapplies this extent; leave room for the handle inside the mask.
            if tab.SetFillToInterior then tab:SetFillToInterior(true, 44) end
        end)
    end
    NS.LayoutSettingsPanel()
    return panel
end
