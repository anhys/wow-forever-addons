-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local F, T = NS.Filters, NS.Text
local events = CreateFrame("Frame")
local panel, ui, updating, levelError, timeoutSpinnerHidden
local roleKeys = {TANK = "ROLE_TANK", HEALER = "ROLE_HEALER", DAMAGER = "ROLE_DAMAGE"}
local modeKeys = {seek = "FILTER_SEEK", recruit = "FILTER_RECRUIT", off = "FILTER_OFF"}
local orderKeys = {native = "BROWSE_NATIVE", name = "BROWSE_NAME", size = "BROWSE_SIZE", level = "BROWSE_LEVEL_ORDER"}
local function Place(frame, y, height)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 0, -y)
    frame:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", 0, -y)
    if height then frame:SetHeight(height) end
end
local function DropdownPlace(button, y)
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 78, -y)
    button:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", -8, -y)
    button.Caption:ClearAllPoints(); button.Caption:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 0, -y-6)
end
local function Label(font)
    local text = panel.Content:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    text:SetJustifyH("LEFT"); text:SetWordWrap(true)
    return text
end
local function Button(name, text, callback)
    local button = CreateFrame("Button", name, panel.Content, "UIPanelButtonTemplate")
    button:SetText(T(text)); button:SetHeight(26); button:SetScript("OnClick", callback)
    return button
end
local function Check(name, text, callback)
    local button = CreateFrame("CheckButton", name, panel.Content, "UICheckButtonTemplate")
    button:SetSize(22, 22); button.Text:SetText(T(text)); button.Text:SetFontObject("GameFontHighlightSmall")
    button.Text:ClearAllPoints(); button.Text:SetPoint("LEFT", button, "RIGHT", 2, 0)
    button:SetScript("OnClick", callback)
    return button
end
local function CheckPlace(button, y)
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", -3, -y)
    button.Text:SetWidth(math.max(40, panel.Content:GetWidth() - 24)); button.Text:SetJustifyH("LEFT"); button.Text:SetWordWrap(true)
end
local function Rule(y)
    local texture = panel.Content:CreateTexture(nil, "BORDER")
    texture:SetColorTexture(.45, .32, .10, 1); texture:SetHeight(1)
    return texture
end
local function RulePlace(texture, y)
    texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 0, -y)
    texture:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", 0, -y)
end

function F.StyleName(value)
    if type(value) == "number" and value >= 1 and value <= 4 then
        return _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. value] or T("BROWSE_STYLE_" .. value)
    end
    return T("BROWSE_STYLE_0")
end
local function Styles(_, root)
    root:CreateRadio(T("BROWSE_ANY_STYLE"), function() return F.Settings().style == nil end, function() F.Settings().style = nil; F.Changed() end)
    local values = Enum and Enum.LFGEntryGeneralPlaystyle
    if not values then return end
    for _, key in ipairs({"Learning", "FunRelaxed", "FunSerious", "Expert"}) do
        local value = values[key]
        if type(value) == "number" then
            root:CreateRadio(F.StyleName(value), function(v) return F.Settings().style == v end,
                function(v) F.Settings().style = v; F.Changed() end, value)
        end
    end
end
local function Classes(_, root)
    root:SetScrollMode(320)
    for _, class in ipairs(F.ClassList()) do
        local item = root:CreateCheckbox(class.name, function(token) local c = F.Settings().classes; return c == nil or c[token] == true end, function(token)
            local s = F.Settings()
            if not s.classes then s.classes = {}; for _, entry in ipairs(F.ClassList()) do s.classes[entry.token] = true end end
            s.classes[token] = not s.classes[token] or nil
            local all = true
            for _, entry in ipairs(F.ClassList()) do if not s.classes[entry.token] then all = false; break end end
            if all then s.classes = nil end
            F.Changed()
        end, class.token)
        item:AddInitializer(function(button)
            local check = button:AttachTexture()
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Up"); check:SetDrawLayer("BACKGROUND")
            check:SetSize(24, 24); check:SetPoint("LEFT", button, "LEFT", -2, 0)
            local icon = button:AttachTexture()
            icon:SetAtlas("groupfinder-icon-class-" .. string.lower(class.token)); icon:SetSize(20, 20)
            icon:SetPoint("LEFT", button, "LEFT", 26, 0)
            local text = button.fontString
            text:ClearAllPoints(); text:SetPoint("LEFT", button, "LEFT", 52, 0)
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class.token]
            text:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            return math.max(210, text:GetStringWidth() + 64), 26
        end)
        if MenuResponse then item:SetResponse(MenuResponse.Refresh) end
    end
    root:CreateDivider()
    local all = root:CreateButton(T("BROWSE_SELECT_ALL"), function() F.Settings().classes = nil; F.Changed() end)
    local clear = root:CreateButton(T("BROWSE_CLEAR"), function() F.Settings().classes = {}; F.Changed() end)
    if MenuResponse then all:SetResponse(MenuResponse.Refresh); clear:SetResponse(MenuResponse.Refresh) end
end
local function Orders(_, root)
    for _, kind in ipairs({"groups", "players"}) do
        root:CreateTitle(T(kind == "groups" and "BROWSE_GROUPS" or "BROWSE_PLAYERS"))
        local field = kind == "groups" and "orderGroups" or "orderPlayers"
        for _, value in ipairs({"native", kind == "groups" and "size" or "level", "name"}) do
            root:CreateRadio(T(orderKeys[value]), function(v) return F.Settings()[field] == v end, function(v) F.Settings()[field] = v; F.Changed() end, value)
        end
    end
end
local function Presets(_, root)
    root:SetScrollMode(330)
    local names = {}
    for name, preset in pairs(F.Settings().presets) do if type(name) == "string" and type(preset) == "table" then names[#names+1] = name end end
    table.sort(names)
    if #names == 0 then root:CreateTitle(T("BROWSE_CUSTOM")) end
    for _, name in ipairs(names) do root:CreateRadio(name, function(v) return F.Settings().activePreset == v end, F.LoadPreset, name) end
end

function F.OpenPresetDialog()
    if InCombatLockdown() then return end
    local dialog = NS.PresetDialog
    if not dialog then
        dialog = CreateFrame("Frame", "ForeverLFGPresetDialog", UIParent, "BackdropTemplate")
        NS.PresetDialog = dialog
        dialog:SetSize(330, 185); dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG"); dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", dialog, "TOP", 0, -14); title:SetText(T("BROWSE_PRESET_NAME"))
        dialog.Input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        dialog.Input:SetAutoFocus(false); dialog.Input:SetMaxLetters(40); dialog.Input:SetSize(288, 24)
        dialog.Input:SetPoint("TOP", dialog, "TOP", 0, -45)
        dialog.Message = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dialog.Message:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -79)
        dialog.Message:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -18, -79); dialog.Message:SetHeight(53); dialog.Message:SetWordWrap(true)
        local function Save()
            local name = dialog.Input:GetText():match("^%s*(.-)%s*$")
            local ok, key = F.SavePreset(name, dialog.confirm == name)
            if ok then dialog:Hide(); return end
            dialog.confirm = key == "BROWSE_REPLACE" and name or nil
            dialog.Message:SetText(T(key == "BROWSE_REPLACE" and "BROWSE_REPLACE_HINT" or key))
        end
        dialog.Save = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        dialog.Save:SetSize(135, 26); dialog.Save:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 15)
        dialog.Save:SetText(T("BROWSE_SAVE_OK")); dialog.Save:SetScript("OnClick", Save)
        dialog.Cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        dialog.Cancel:SetSize(135, 26); dialog.Cancel:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 15)
        dialog.Cancel:SetText(T("BROWSE_CANCEL")); dialog.Cancel:SetScript("OnClick", function() dialog:Hide() end)
        dialog.Input:SetScript("OnTextChanged", function() dialog.confirm = nil; dialog.Message:SetText("") end)
        dialog.Input:SetScript("OnEnterPressed", Save)
        dialog.Input:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog:HookScript("OnHide", function() dialog.Input:ClearFocus() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1] = "ForeverLFGPresetDialog" end
    end
    dialog.confirm = nil; dialog.Input:SetText(F.Settings().activePreset or "")
    dialog.Message:SetText(""); dialog:Show(); dialog.Input:SetFocus()
end

local function ApplyLevels()
    if updating or not ui or not ui.ready then return end
    levelError = not F.SetLevels(ui.Low:GetText(), ui.High:GetText())
    F.UpdateUI()
end
local function LevelHelp(owner)
    local key = owner == ui.Low and "BROWSE_LEVEL_MIN" or owner == ui.High and "BROWSE_LEVEL_MAX" or "BROWSE_LEVEL"
    NS.BrowseHelp(owner, T(key), T("BROWSE_LEVEL_HELP"))
    if levelError then GameTooltip:AddLine(T("BROWSE_LEVEL_ERROR"), 1, .3, .3, true); GameTooltip:Show() end
end
local function SetEdit(edit, value)
    if not levelError and not edit:HasFocus() and edit:GetText() ~= tostring(value or "") then edit:SetText(value and tostring(value) or "") end
end
local function SeekRoleHint(roles)
    local only, count = "ANY", 0
    for _, role in ipairs(F.roles) do
        if roles[role] == true then only, count = role, count + 1 end
    end
    return T("BROWSE_SEEK_" .. (count > 1 and "MULTIPLE" or only))
end
function F.ClearLevelDraft()
    levelError = nil
    if ui and ui.ready then updating = true; ui.Low:ClearFocus(); ui.High:ClearFocus(); updating = false end
end

function F.UpdateUI()
    if not panel or not ui or not ui.ready or updating then return end
    updating = true
    local s = F.Settings()
    local c = F.context
    if not c then
        local ok, value = pcall(F.Context)
        c = ok and value or {roles = {}, reason = "FILTER_DATA_UNAVAILABLE", bypass = true}
    end
    local recruit, enabled = s.mode == "recruit", not InCombatLockdown()
    ui.LevelHelp:SetShown(recruit)
    ui.Mode.Label:SetText(T(modeKeys[s.mode])); ui.Mode:SetEnabled(enabled)
    ui.Languages.Label:SetText(NS.LanguageLabel(NS.Mode()))
    ui.Languages:SetEnabled(enabled and not (NS.CustomRefreshDisabled and NS.CustomRefreshDisabled()))
    ui.Style.Label:SetText((s.mode == "off" or s.style == nil) and T("BROWSE_ANY_STYLE") or F.StyleName(s.style))
    ui.Style:SetEnabled(enabled and s.mode ~= "off" and Enum and Enum.LFGEntryGeneralPlaystyle ~= nil)
    local y = 90
    for _, object in ipairs({ui.FilterTitle, ui.Immediate, ui.Auto, ui.RosterCount, ui.Hint, ui.RoleBar, ui.RoleHint, ui.LevelLabel, ui.Low, ui.High, ui.Dash, ui.Classes, ui.Classes.Caption, ui.Reset, ui.LevelError, ui.FilterRule}) do object:SetShown(s.mode ~= "off") end
    if s.mode ~= "off" then
        RulePlace(ui.FilterRule, y-7); Place(ui.FilterTitle, y, 16)
        ui.FilterTitle:SetText(T(recruit and "BROWSE_PLAYER_FILTERS" or "BROWSE_GROUP_FILTERS")); y = y + 19
        ui.Immediate:ClearAllPoints(); ui.Immediate:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", 0, -y+17)
        ui.Immediate:SetText(T((not enabled or c.bypass or c.reason == "FILTER_COMBAT") and "BROWSE_PAUSED" or "BROWSE_IMMEDIATE"))
        ui.Immediate:SetShown(recruit)
        ui.Auto:SetShown(recruit); ui.Auto:SetChecked(s.auto); ui.Auto:SetEnabled(enabled)
        ui.RosterCount:SetShown(recruit and s.auto and c.roster ~= nil)
        if recruit then
            CheckPlace(ui.Auto, y)
            ui.Auto.Text:SetWidth(math.max(40, panel.Content:GetWidth()-58))
            ui.RosterCount:ClearAllPoints(); ui.RosterCount:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", -3, -y-5)
            ui.RosterCount:SetText(c.roster and tostring(c.roster.size).."/5" or "")
            y = y + 21
        end
        local hint = T(recruit and "FILTER_NEED" or "BROWSE_SEEK_ROLE")
        if not enabled then hint = T("FILTER_COMBAT")
        elseif c.bypass or c.reason == "FILTER_COMBAT" then hint = T(c.reason or "FILTER_DATA_UNAVAILABLE")
        elseif recruit and s.auto then
            local missing = {}
            if c.roster and not c.bypass then
                for _, role in ipairs(F.roles) do if c.roster.missing[role] > 0 then missing[#missing+1] = T(roleKeys[role]) .. " " .. c.roster.missing[role] end end
                hint = c.full and T("FILTER_FULL") or T("BROWSE_MISSING", table.concat(missing, ", "))
            else hint = T(c.reason or "BROWSE_AUTO_PAUSED") end
        end
        Place(ui.Hint, y, 0); ui.Hint:SetText(hint)
        local hintHeight = math.max(recruit and 24 or 18, ui.Hint:GetStringHeight())
        ui.Hint:SetHeight(hintHeight); y = y + hintHeight + 3
        Place(ui.RoleBar, y, 58); y = y + 62
        ui.RoleHint:SetShown(recruit or (enabled and not c.bypass and c.reason ~= "FILTER_COMBAT"))
        if ui.RoleHint:IsShown() then
            Place(ui.RoleHint, y, 0)
            ui.RoleHint:SetText(recruit and T(s.auto and "BROWSE_ROLE_MANUAL" or "BROWSE_OR_ROLES") or SeekRoleHint(s.seek))
            local roleHintHeight = math.max(12, ui.RoleHint:GetStringHeight())
            ui.RoleHint:SetHeight(roleHintHeight); y = y + roleHintHeight + 3
        end
        local roles = recruit and c.roles or s.seek
        local any = true
        for _, role in ipairs(F.roles) do if roles and roles[role] then any = false end end
        for _, role in ipairs({"ANY", "TANK", "HEALER", "DAMAGER"}) do
            local button = ui.Roles[role]
            local selected = role == "ANY" and any or role ~= "ANY" and roles and roles[role] == true
            if (c.bypass or c.full) and s.auto and recruit then selected = false end
            button:SetFilterState(selected, enabled)
        end
        local cellWidth = panel.Content:GetWidth()/4
        for i,role in ipairs({"ANY", "TANK", "HEALER", "DAMAGER"}) do
            local button=ui.Roles[role]
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", ui.RoleBar, "TOPLEFT", (i-.5)*cellWidth-21, 0)
            button.Label:SetWidth(cellWidth - 2)
        end
        for _, object in ipairs({ui.LevelLabel, ui.Low, ui.High, ui.Dash, ui.Classes, ui.Classes.Caption}) do object:SetShown(recruit) end
        if recruit then
            local editWidth = math.min(59, math.max(44, (panel.Content:GetWidth() - 112) / 2))
            ui.Low:SetWidth(editWidth); ui.High:SetWidth(editWidth)
            ui.LevelLabel:ClearAllPoints(); ui.LevelLabel:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 0, -y-5)
            ui.LevelHelp:ClearAllPoints(); ui.LevelHelp:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", -3, -y)
            ui.Low:ClearAllPoints(); ui.Low:SetPoint("TOPLEFT", panel.Content, "TOPLEFT", 86, -y)
            ui.High:ClearAllPoints(); ui.High:SetPoint("TOPRIGHT", panel.Content, "TOPRIGHT", -8, -y)
            ui.Dash:ClearAllPoints(); ui.Dash:SetPoint("CENTER", ui.Low, "RIGHT", (panel.Content:GetWidth() - 94 - 2*editWidth)/2, 0)
            SetEdit(ui.Low, s.levelMin); SetEdit(ui.High, s.levelMax)
            ui.Low:SetEnabled(enabled); ui.High:SetEnabled(enabled)
            ui.Low:SetTextColor(1, levelError and .25 or 1, levelError and .25 or 1)
            ui.High:SetTextColor(1, levelError and .25 or 1, levelError and .25 or 1)
            y = y + 27
            ui.LevelError:SetShown(levelError == true)
            if levelError then Place(ui.LevelError, y, 42); y = y + 46 end
            DropdownPlace(ui.Classes, y); y = y + 29
            local names, classes = {}, F.ClassList()
            for _, class in ipairs(classes) do if not s.classes or s.classes[class.token] then names[#names+1] = class.name end end
            local summary = #names == #classes and T("BROWSE_ALL_CLASSES") or (#names == 1 and names[1] or T("BROWSE_CLASS_COUNT", #names))
            ui.Classes.Label:SetText(summary); ui.Classes:SetEnabled(enabled)
            ui.Classes.detail = #names > 0 and table.concat(names, ", ") or T("BROWSE_EMPTY_CLASSES")
        else ui.LevelError:Hide() end
        Place(ui.Reset, y, 24); ui.Reset:SetEnabled(enabled and (F.HasConditions() or levelError)); y = y + 31
    end
    RulePlace(ui.ViewRule, y); y = y + 8
    Place(ui.ViewTitle, y, 16); y = y + 20
    DropdownPlace(ui.Order, y); y = y + 28
    ui.Order.Label:SetText(T(orderKeys[recruit and s.orderPlayers or s.orderGroups])); ui.Order:SetEnabled(enabled)
    CheckPlace(ui.Friends, y); ui.Friends:SetChecked(s.friendsFirst == true); ui.Friends:SetEnabled(enabled); y = y + 25
    RulePlace(ui.PresetRule, y); y = y + 8
    DropdownPlace(ui.Preset, y); ui.Preset.Label:SetText(s.activePreset or T("BROWSE_CUSTOM")); ui.Preset:SetEnabled(enabled); y = y + 29
    Place(ui.Save, y, 24); ui.Save:SetEnabled(enabled and not (recruit and levelError)); y = y + 28
    panel.contentHeight = y
    local previousWidth = panel.Content:GetWidth()
    NS.LayoutSettingsPanel()
    if ui.Empty then
        local timeout = NS.BrowseLayoutActive() and NS.SearchTimedOut()
        local spinner = LFGBrowseFrame.SearchingSpinner
        -- Только отображение тайм-аута: флаги/контроллер Blizzard не сбрасываем.
        if timeout and NS.CanChangeFrame(spinner) and spinner:IsShown() then
            spinner:Hide(); timeoutSpinnerHidden = true
        elseif not timeout and timeoutSpinnerHidden and NS.CanChangeFrame(spinner) then
            timeoutSpinnerHidden = nil
            spinner:SetShown(LFGBrowseFrame.searching)
        end
        local reason = timeout and "BROWSE_SEARCH_FAILED" or F.EmptyReason()
        ui.Empty:SetShown(NS.BrowseLayoutActive() and reason ~= nil and (timeout or (not LFGBrowseFrame.searching and not LFGBrowseFrame.searchFailed)))
        ui.Empty:SetText(T(reason or "BROWSE_EMPTY"))
    end
    updating = false
    if previousWidth ~= panel.Content:GetWidth() then F.UpdateUI() end
end

local function Build()
    if panel or InCombatLockdown() then return end
    panel = NS.EnsureSettingsPanel()
    if not panel then return end
    ui = {Roles = {}}
    NS.BrowseControls = ui
    ui.Mode = NS.CreateSettingsDropdown("ForeverLFGFilterMode", panel.Content, 0, "BROWSE_MODE")
    ui.Mode:SetupMenu(function(_, root)
        for _, mode in ipairs({"seek", "recruit", "off"}) do root:CreateRadio(T(modeKeys[mode]), function(v) return F.Settings().mode == v end, F.SelectMode, mode) end
    end)
    ui.Languages = NS.CreateSettingsDropdown("ForeverLFGLanguageDropdown", panel.Content, 29, "BROWSE_LANGUAGES")
    NS.LanguageDropdown = ui.Languages
    ui.Languages:SetupMenu(function(owner,root)
        if NS.GenerateLanguageMenu then NS.GenerateLanguageMenu(owner,root) end
    end)
    ui.Languages:RegisterCallback("OnMenuOpen", function() NS.Log("Action", "Language menu opened") end, events)
    ui.Languages:SetScript("OnEnter", function(self)
        NS.BrowseHelp(self, NS.LanguageLabel(NS.Mode()), NS.CustomRefreshDisabled() and T("BROWSE_NATIVE_REFRESH") or nil)
    end)
    ui.Style = NS.CreateSettingsDropdown("ForeverLFGStyleDropdown", panel.Content, 58, "BROWSE_STYLE")
    ui.Style:SetupMenu(Styles)
    ui.FilterRule, ui.ViewRule, ui.PresetRule = Rule(), Rule(), Rule()
    ui.FilterTitle, ui.Hint = Label(), Label("GameFontDisableSmall")
    ui.Immediate, ui.RosterCount, ui.RoleHint = Label("GameFontDisableSmall"), Label("GameFontDisableSmall"), Label("GameFontDisableSmall")
    ui.Auto = Check("ForeverLFGFilterAuto", "BROWSE_AUTO_PARTY", function(self)
        local s, c = F.Settings(), F.context or F.Context()
        s.auto = self:GetChecked() == true
        if not s.auto then s.recruit = {}; for _, role in ipairs(F.roles) do s.recruit[role] = c.roles and c.roles[role] == true or false end end
        F.Changed()
    end)
    ui.RoleBar = CreateFrame("Frame", nil, panel.Content)
    for i, role in ipairs({"ANY", "TANK", "HEALER", "DAMAGER"}) do
        local button = NS.CreateFilterRoleButton("ForeverLFGFilter" .. role, ui.RoleBar, role, T(role == "ANY" and "BROWSE_ANY" or roleKeys[role]))
        ui.Roles[role] = button
        button:SetScript("OnClick", function()
            if role == "ANY" then local s = F.Settings(); if s.mode == "recruit" then s.auto, s.recruit = false, {} else s.seek = {} end; F.Changed()
            else F.SelectRole(role) end
        end)
        button:HookScript("OnEnter", function(self)
            local key = F.Settings().mode == "seek" and ("BROWSE_SEEK_HELP_" .. role) or "BROWSE_OR_ROLES"
            NS.BrowseHelp(self, button.Label:GetText(), T(key))
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    ui.LevelLabel, ui.Dash, ui.LevelError = Label(), Label(), Label("GameFontRedSmall")
    ui.LevelLabel:SetText(T("BROWSE_LEVEL")); ui.Dash:SetText("-"); ui.LevelError:SetText(T("BROWSE_LEVEL_ERROR"))
    -- FontString has no mouse scripts; the small hit area covers only the label.
    ui.LevelHelp = CreateFrame("Frame", nil, panel.Content)
    ui.LevelHelp:SetSize(82, 24); ui.LevelHelp:EnableMouse(true); ui.LevelHelp:Hide()
    ui.LevelHelp:SetScript("OnEnter", LevelHelp)
    ui.LevelHelp:SetScript("OnLeave", function() GameTooltip:Hide() end)
    for _, key in ipairs({"Low", "High"}) do
        local edit = CreateFrame("EditBox", nil, panel.Content, "InputBoxTemplate")
        ui[key] = edit; edit:SetSize(59, 24); edit:SetAutoFocus(false); edit:SetMaxLetters(4); edit:SetNumeric(true)
        edit:SetScript("OnEnter", LevelHelp)
        edit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        edit:SetScript("OnEnterPressed", function(self) ApplyLevels(); self:ClearFocus() end)
        edit:SetScript("OnEditFocusLost", ApplyLevels)
        edit:SetScript("OnEscapePressed", function(self) updating = true; self:SetText(""); self:ClearFocus(); updating = false; levelError = nil; F.UpdateUI() end)
        edit:SetScript("OnTabPressed", function(self)
            if InCombatLockdown() or F.Settings().mode ~= "recruit" then return end
            local target = self == ui.Low and ui.High or ui.Low
            self:ClearFocus(); target:SetFocus(); target:HighlightText()
        end)
    end
    ui.Classes = NS.CreateSettingsDropdown("ForeverLFGClassDropdown", panel.Content, 0, "BROWSE_CLASSES")
    ui.Classes:SetupMenu(Classes)
    ui.Classes:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPRIGHT", ui.Classes, "BOTTOMRIGHT", 0, -2))
    ui.Classes:SetScript("OnEnter", function(self) NS.BrowseHelp(self, self.Label:GetText(), self.detail) end)
    ui.Reset = Button("ForeverLFGResetFilters", "BROWSE_RESET", function()
        updating = true; ui.Low:ClearFocus(); ui.High:ClearFocus(); updating = false
        levelError = nil; F.Reset()
    end)
    ui.ViewTitle = Label(); ui.ViewTitle:SetText(T("BROWSE_VIEW"))
    ui.Order = NS.CreateSettingsDropdown("ForeverLFGOrderDropdown", panel.Content, 0, "BROWSE_ORDER")
    ui.Order:SetupMenu(Orders)
    ui.Friends = Check("ForeverLFGFriendsFirst", "BROWSE_FRIENDS", function(self) F.Settings().friendsFirst = self:GetChecked() == true; F.Changed() end)
    ui.Preset = NS.CreateSettingsDropdown("ForeverLFGPresetDropdown", panel.Content, 0, "BROWSE_PRESET")
    ui.Preset:SetupMenu(Presets)
    ui.Save = Button("ForeverLFGSavePreset", "BROWSE_SAVE", F.OpenPresetDialog)
    ui.Save:SetMotionScriptsWhileDisabled(true)
    ui.Save:SetScript("OnEnter", function(self) if levelError then NS.BrowseHelp(self, T("BROWSE_LEVEL"), T("BROWSE_LEVEL_ERROR")) end end)
    ui.Save:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.Empty = LFGBrowseFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ui.Empty:SetPoint("CENTER", NS.BrowseListRegion, "CENTER", 0, 0); ui.Empty:SetWidth(290); ui.Empty:SetWordWrap(true)
    NS.FilterEmptyText = ui.Empty
    ui.ready = true
    if F.InitializeActivityLevels then F.InitializeActivityLevels() end
    F.UpdateUI()
end
local function Install()
    local ok, err = pcall(Build)
    if not ok then
        NS.DisableBrowseLayout("Filter controls initialization failed: " .. tostring(err))
    end
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function() Install(); F.UpdateUI() end)
