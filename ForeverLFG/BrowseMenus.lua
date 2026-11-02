-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local F, P, T = NS.Filters, NS.Filters.Plain, NS.Text
local events = CreateFrame("Frame")
local installed, preferenceWarning, controlsInstalled, InstallActivityControls, decorationWarning
local decorated = setmetatable({}, {__mode = "k"})
local cvar = "disableSuggestedLevelActivityFilter"
local function MenuInitializer(callback)
    return function(button,...)
        local ok,width,height=pcall(callback,button,...)
        if ok then return width,height end
        -- All activity rows share this optional decoration; report only once per
        -- session, including regenerated menus, to preserve useful search events.
        if not decorationWarning then
            decorationWarning=true
            NS.Log("Error", "Activity menu decoration unavailable: "..tostring(width), true)
        end
        -- Keep the native element when this optional decoration cannot be applied.
    end
end
function F.RecommendedLevels(activityID)
    local ok, text = pcall(function()
        local info = P(C_LFGList.GetActivityInfoTable(activityID))
        if not info then return "" end
        local low, high = P(info.minLevelSuggestion), P(info.maxLevelSuggestion)
        low = type(low) == "number" and low > 0 and low or nil
        high = type(high) == "number" and high > 0 and high or nil
        if low and high then return low == high and tostring(low) or low .. " - " .. high end
        if low then return ">= " .. low end
        if high then return "<= " .. high end
        return ""
    end)
    return ok and text or ""
end
local function Modify(owner, root)
    if not NS.BrowseLayoutActive() or not LFGBrowseFrame or owner ~= LFGBrowseFrame.ActivityDropdown then return end
    if type(root.EnumerateElementDescriptions) ~= "function" or not MenuUtil.CreateTitle then return end
    local ok, err = pcall(function()
        root:SetScrollMode(math.max(180, math.min(400, UIParent:GetHeight() - 120)))
        local category = P(LFGBrowseFrame.CategoryDropdown:GetValue(), "number")
        local activities = P(LFGUtil_GetFilteredActivities(category), "table")
        local eligible, groups = {}, {}
        for _, id in ipairs(activities) do
            eligible[id] = true
            local info = P(C_LFGList.GetActivityInfoTable(id))
            if info and info.groupFinderActivityGroupID then groups[P(info.groupFinderActivityGroupID)] = true end
        end
        local function Visit(description)
            for _, child in description:EnumerateElementDescriptions() do
                local id = child:GetData()
                if type(id) == "number" and eligible[id] and not groups[id] and not decorated[child] then
                    decorated[child] = true
                    child:AddInitializer(MenuInitializer(function(button)
                        local range = F.RecommendedLevels(id)
                        local nameWidth = button.fontString and button.fontString:GetStringWidth() or 140
                        if range == "" then return math.max(245, nameWidth + 78), math.max(20, button:GetHeight()) end
                        -- Menu compositor forbids CreateFontString. Attach a fresh
                        -- pooled region on every initialization; the menu releases it.
                        local label = button:AttachFontString()
                        label:Hide(); label:SetFontObject("GameFontDisableSmall")
                        label:SetHeight(20); label:SetJustifyH("RIGHT"); label:SetWordWrap(false)
                        label:ClearAllPoints(); label:SetPoint("RIGHT", button, "RIGHT", -18, 0)
                        label:SetText(range)
                        local width, height = math.max(245, nameWidth + label:GetStringWidth() + 78), math.max(20, button:GetHeight())
                        label:Show()
                        return width, height
                    end))
                end
                Visit(child)
            end
            return true
        end
        -- Один и тот же готовый description может прийти при немедленной регистрации.
        if decorated[root] then return end
        decorated[root] = true
        Visit(root)
        if #activities == 0 then return end
        local header = MenuUtil.CreateTitle(T("BROWSE_RECOMMENDED"))
        header:SetSelectionIgnored()
        header:AddInitializer(MenuInitializer(function(button)
            button.fontString:ClearAllPoints(); button.fontString:SetPoint("RIGHT", button, "RIGHT", -18, 0)
            button.fontString:SetJustifyH("RIGHT")
            return 245, 20
        end))
        root:Insert(header, 1)
    end)
    if not ok then NS.Log("Error", "Activity menu extension unavailable: " .. tostring(err), true) end
end
local function HiddenCategories()
    if GetCVarBool(cvar) or P(LFGBrowseFrame.CategoryDropdown:GetValue(), "number") ~= 0 then return false end
    -- После сброса категории игра может ещё показывать прежнюю выдачу.
    if F.counts and F.counts.source > 0 then return false end
    local total = P(LFGBrowseFrame.totalResults)
    if type(total) == "number" and total > 0 then return false end
    for _, category in ipairs(P(C_LFGList.GetAvailableCategories(), "table")) do
        category = P(category, "number")
        local available = P(C_LFGList.GetAvailableActivities(category), "table")
        if #available > 0 and #P(LFGUtil_GetFilteredActivities(category), "table") == 0 then return true end
    end
    return false
end
function NS.UpdateActivityOptions()
    if not controlsInstalled then InstallActivityControls() end
    local check = NS.ActivityLevelsCheck
    local hint = NS.ActivityLevelsHint
    if not check or not hint then return end
    local active = NS.BrowseLayoutActive()
    local ok, checked = pcall(function() return P(GetCVarBool(cvar), "boolean") end)
    check:SetChecked(ok and checked == true)
    check:SetEnabled(active and not InCombatLockdown() and ok)
    check:SetShown(active)
    local show = false
    if active and not InCombatLockdown() and not NS.IsPending() and not LFGBrowseFrame.searching then
        local ok, hidden = pcall(HiddenCategories)
        show = ok and hidden == true
    end
    hint:SetWidth(math.max(120, NS.BrowseListRegion:GetWidth() - 24))
    hint:SetShown(show)
end
local function Install()
    if installed or InCombatLockdown() or not Menu or type(Menu.ModifyMenu) ~= "function" then return end
    if not LFGBrowseFrame or not LFGBrowseFrame.ActivityDropdown then return end
    Menu.ModifyMenu("MENU_LFG_BROWSE_ACTIVITY", Modify)
    installed = true
end
InstallActivityControls = function()
    local b = LFGBrowseFrame
    if controlsInstalled or InCombatLockdown() or not b or not NS.BrowseLayoutActive() or not NS.BrowseListRegion then return end
    local check = CreateFrame("CheckButton", "ForeverLFGAllActivityLevels", b, "UICheckButtonTemplate")
    check:SetSize(22, 22); check:Hide()
    check:SetPoint("TOPLEFT", b.CategoryDropdown, "BOTTOMLEFT", -3, -6)
    check.Text:SetText(T("BROWSE_ALL_LEVELS")); check.Text:SetFontObject("GameFontHighlightSmall")
    check.Text:ClearAllPoints(); check.Text:SetPoint("TOPLEFT", check, "TOPRIGHT", 2, -4)
    check.Text:SetJustifyH("LEFT"); check.Text:SetWordWrap(true)
    check:SetMotionScriptsWhileDisabled(true)
    check:SetScript("OnClick", function(self)
        if not NS.BrowseLayoutActive() or InCombatLockdown() then NS.UpdateActivityOptions(); return end
        local checked = self:GetChecked() == true
        local ok, err = pcall(function()
            SetCVar(cvar, checked)
            if P(GetCVarBool(cvar), "boolean") ~= checked then error("activity-level preference was not applied") end
        end)
        if not ok then NS.Log("Error", "Activity-level preference could not be changed: " .. tostring(err), true) end
        NS.UpdateActivityOptions()
    end)
    check:SetScript("OnEnter", function(self)
        -- This row is close to the screen top. Place the help below it instead
        -- of growing upward across the selectors and window title.
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints(); GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        GameTooltip:SetText(T("BROWSE_ALL_LEVELS"))
        GameTooltip:AddLine(T("BROWSE_ALL_LEVELS_HINT"), 1, 1, 1, true)
        if InCombatLockdown() then GameTooltip:AddLine(T("BROWSE_ACTION_COMBAT"), 1, .6, .4, true) end
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    NS.ActivityLevelsCheck = check
    local hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- Ниже штатного сообщения, не поверх заголовков разделов или ошибки поиска.
    hint:SetPoint("CENTER", NS.BrowseListRegion, "CENTER", 0, -70)
    hint:SetWordWrap(true); hint:SetJustifyH("CENTER"); hint:SetHeight(54)
    hint:SetText(T("BROWSE_LEVELS_HIDDEN_HINT")); hint:Hide()
    NS.ActivityLevelsHint = hint
    if type(b.ActivityFiltersChanged) == "function" then hooksecurefunc(b, "ActivityFiltersChanged", NS.UpdateActivityOptions) end
    controlsInstalled = true
end
function NS.LayoutActivityOptions(leftWidth)
    InstallActivityControls()
    local check = NS.ActivityLevelsCheck
    if not check then return 100 end
    local text = check.Text
    -- Reserve wrapping space only when the label needs it. A full-column
    -- FontString width would also make the blank row toggle the shared CVar.
    text:SetWidth(math.min(math.max(120, leftWidth - 80), math.ceil(text:GetUnboundedStringWidth())))
    local rowHeight = math.max(22, text:GetStringHeight() + 8)
    -- Кликабельны галочка и видимая подпись, без пустого места справа.
    check:SetHitRectInsets(0, -text:GetWidth()-2, 0, -(rowHeight-22))
    return 72 + rowHeight + 6
end
local function InitialPreference()
    if InCombatLockdown() or not NS.SettingsPanel or NS.BrowseLayoutFailed() or not SetCVar or not GetCVarBool then return end
    local settings = NS.Database().settings
    if settings.activityLevelsPolicy == 2 then return end
    -- 0.7.0-0.7.3 enabled all levels automatically. Restore native recommendations
    -- once for both new installs and upgrades; later explicit choices remain native.
    local ok,applied = pcall(function()
        if GetCVarBool(cvar) then SetCVar(cvar,false) end
        return not GetCVarBool(cvar)
    end)
    if ok and applied then
        settings.activityLevelsPolicy=2
        settings.activityLevelsInitialized=nil
    elseif not preferenceWarning then
        preferenceWarning=true
        NS.Log("Error", "Recommended activity levels could not be restored; will retry out of combat", true)
    end
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "CVAR_UPDATE", "LFG_LIST_AVAILABILITY_UPDATE", "PLAYER_LEVEL_UP"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function() Install(); InstallActivityControls(); InitialPreference(); NS.UpdateActivityOptions() end)
F.InitializeActivityLevels = InitialPreference
