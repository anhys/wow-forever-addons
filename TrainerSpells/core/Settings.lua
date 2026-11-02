local _, TrainerSpells = ...
TrainerSpells.LANGUAGES = {{"English", "enUS"}, {"Deutsch", "deDE"}, {"Español (España)", "esES"}, {"Español (México)", "esMX"}, {"Français", "frFR"}, {"Italiano", "itIT"}, {"한국어", "koKR"}, {"Português (Brasil)", "ptBR"}, {"Русский", "ruRU"}, {"简体中文", "zhCN"}, {"繁體中文", "zhTW"}}
TrainerSpells.LanguageNames = {}
for _, info in ipairs(TrainerSpells.LANGUAGES) do
    TrainerSpells.LanguageNames[info[2]] = info[1]
end

function TrainerSpells:GetLanguage()
    local lang = type(TrainerSpells_Global) == "table" and TrainerSpells_Global.language or nil
    if lang ~= nil and self.LanguageNames[lang] ~= nil then return lang end
    if self.LanguageNames[GetLocale()] ~= nil then return GetLocale() end
    return "enUS"
end

function TrainerSpells:GetLanguageName(lang)
    lang = lang or self:GetLanguage()
    return self.LanguageNames[lang] or lang
end

function TrainerSpells:SetLanguage(lang)
    if self.LanguageNames[lang] == nil or lang == self:GetLanguage() then return end
    TrainerSpells_Global = TrainerSpells_Global or {}
    if lang == GetLocale() then
        TrainerSpells_Global.language = nil
    else
        TrainerSpells_Global.language = lang
    end

    self:RefreshLanguage()
end

TrainerSpells.LibTrans = TrainerSpells.Trans
function TrainerSpells:Trans(key, lang, ...)
    return TrainerSpells.LibTrans(self, key, lang or TrainerSpells:GetLanguage(), ...)
end

function TrainerSpells:RefreshLanguage()
    local win = self.SettingsWindow
    if win then
        local shown = win:IsShown()
        local point = {win:GetPoint(1)}
        local width, height = win:GetSize()
        win:Hide()
        self.SettingsWindow = nil
        self.SettingCheckboxes = {}
        if shown then
            self:ToggleSettings()
            local newWin = self.SettingsWindow
            if newWin and point[1] then
                newWin:ClearAllPoints()
                newWin:SetPoint(unpack(point))
                newWin:SetSize(width, height)
            end
        end
    end

    if TrainerSpells_Refresh then TrainerSpells_Refresh() end
    if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
end

function TrainerSpells:AddLanguageButton(win)
    local function LanguageMenu(_, root)
        root:CreateTitle(self:Trans("LID_LANGUAGE"))
        for _, info in ipairs(self.LANGUAGES) do
            local lang = info[2]
            root:CreateRadio(format("%s (%s)", info[1], lang), function() return self:GetLanguage() == lang end, function() self:SetLanguage(lang) end)
        end
    end

    local parent = win.titleBar or win
    local button
    if self:GetWoWBuild() == "RETAIL" and self:CheckTemplates("WowStyle1DropdownTemplate") then
        button = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        button:SetScale(0.8)
        button:SetSize(162.5, 25)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -1.25)
        button:SetSelectionText(function() return self:GetLanguageName() end)
        button:SetTooltip(function(tooltip) tooltip:SetText(self:Trans("LID_LANGUAGE")) end)
        button:SetupMenu(LanguageMenu)
    else
        button = self:CreateButton(nil, parent)
        button:SetSize(130, 20)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 7, -2)
        button.Arrow = button:CreateTexture(nil, "OVERLAY")
        button.Arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        button.Arrow:SetSize(16, 16)
        button.Arrow:SetPoint("RIGHT", button, "RIGHT", -2, 0)
        button:SetScript("OnClick", function(sel)
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(sel, LanguageMenu)
            else
                local current = 1
                for i, info in ipairs(self.LANGUAGES) do
                    if info[2] == self:GetLanguage() then current = i end
                end

                self:SetLanguage(self.LANGUAGES[current % #self.LANGUAGES + 1][2])
            end
        end)

        button:SetScript("OnEnter", function(sel)
            GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
            GameTooltip:SetText(self:Trans("LID_LANGUAGE"))
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    button:SetText(self:GetLanguageName())
    win.Language = button
end

TrainerSpells.TabSettings = {}
TrainerSpells.TabSettingKeys = {"spellbook", "class", "pet", "trainers", "weapons", "professions", "profession_skill", "profession_recipes", "profession_trainers", "compendium_class", "compendium_professions"}
TrainerSpells.SharedTabSettings = {
    TRAINERSPELLS_COMPENDIUM_CLASS = "compendium_class",
    TRAINERSPELLS_COMPENDIUM_PROFESSIONS = "compendium_professions"
}

function TrainerSpells:LoadTabSettings()
    for _, key in ipairs(self.TabSettingKeys) do
        self.TabSettings[key] = TrainerSpells_Character[key] ~= false
    end
end

TrainerSpells:LoadTabSettings()
TrainerSpells.TabSettingListeners = {}
TrainerSpells.SettingCheckboxes = {}
function TrainerSpells:OnTabSettingsChanged(listener)
    table.insert(self.TabSettingListeners, listener)
end

function TrainerSpells:ApplyTabSettings()
    if not self.SettingsReady then return end
    self:LoadTabSettings()
    for _, listener in ipairs(self.TabSettingListeners) do
        local ok, err = pcall(listener)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end

    self:RegisterCompendiumTabs()
    if self.SettingsWindow and self.SettingsWindow.UpdateDependencies then self.SettingsWindow:UpdateDependencies() end
end

TrainerSpells:RegisterSharedSettings({
    keys = {"TRAINERSPELLS_COMPENDIUM_CLASS", "TRAINERSPELLS_COMPENDIUM_PROFESSIONS"},
    getDB = function() return TrainerSpells_Character end,
    get = function(key) return TrainerSpells_Character[TrainerSpells.SharedTabSettings[key]] ~= false end,
    set = function(key, value) TrainerSpells_Character[TrainerSpells.SharedTabSettings[key]] = value end,
    onChange = function(key, value)
        local checkbox = TrainerSpells.SettingCheckboxes[TrainerSpells.SharedTabSettings[key]]
        if checkbox and checkbox.SetChecked then checkbox:SetChecked(value ~= false) end
        TrainerSpells:ApplyTabSettings()
    end
})

function TrainerSpells:IsTabEnabled(key)
    return self.TabSettings[key] ~= false
end

function TrainerSpells:FilterTabViews(views, prefix)
    local visible = {}
    for _, entry in ipairs(views) do
        if self:IsTabEnabled((prefix or "") .. (entry.view or entry.mode)) then table.insert(visible, entry) end
    end
    return visible
end

function TrainerSpells:HasSpellbookTabs()
    local _, classToken = UnitClass("player")
    return self:IsTabEnabled("class") or self:IsTabEnabled("trainers") and self.BuildClassTrainerItems ~= nil or self:IsTabEnabled("weapons") and self.BuildWeaponSkillItems ~= nil or self:IsTabEnabled("pet") and self:HasPetClassData(classToken)
end

function TrainerSpells:GetTabLayout(key)
    return TrainerSpells_Character and TrainerSpells_Character[key] == "tabs" and "tabs" or "combined"
end

function TrainerSpells:HasProfessionTabs()
    return self:IsTabEnabled("profession_skill") or self:IsTabEnabled("profession_recipes") or self:IsTabEnabled("profession_trainers")
end

function TrainerSpells:ToggleSettings()
    if not self.SettingsWindow then
        local win = self:CreateUIWindow({
            name = "TrainerSpellsSettings",
            title = format("|T%s:20:20|t TrainerSpells v%s", TrainerSpells:GetAddonIcon(), TrainerSpells:GetAddonVersion()),
            width = 520,
            height = 600
        })

        self.SettingsWindow = win
        self:AddLanguageButton(win)
        win:AddSearch()
        win:AddCategory({
            label = "LID_GENERAL",
            key = "general"
        })

        win:AddCheckbox({
            label = "LID_SHOWMINIMAPBUTTON",
            added = "2026-10-07",
            value = TrainerSpells_Character.showMinimapButton ~= false,
            func = function(value)
                TrainerSpells_Character.showMinimapButton = value
                if value then
                    self:ShowMMBtn("TrainerSpells")
                else
                    self:HideMMBtn("TrainerSpells")
                end
            end
        })

        win:AddCategory({
            label = "LID_SETTINGS_PRICES",
            key = "prices"
        })

        win:AddDropdown({
            label = "LID_SETTINGS_PRICEDISPLAY",
            added = "2026-10-07",
            value = TrainerSpells.Pricing.GetDisplayMode(),
            choices = {
                {
                    value = "both",
                    label = "LID_SETTINGS_PRICEDISPLAY_BOTH"
                },
                {
                    value = "discounted",
                    label = "LID_SETTINGS_PRICEDISPLAY_DISCOUNTED"
                },
                {
                    value = "base",
                    label = "LID_SETTINGS_PRICEDISPLAY_BASE"
                }
            },
            func = function(value)
                TrainerSpells_Character.priceDisplay = value
                if TrainerSpells_Refresh then TrainerSpells_Refresh() end
                if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
            end
        })

        for _, category in ipairs({
            {
                label = "LID_SETTINGS_SPELLBOOK",
                key = "spellbook",
                layout = "spellbookLayout",
                compendium = "compendium_class",
                compendiumLabel = "LID_SETTINGS_COMPENDIUM_CLASS",
                options = {{"class", "LID_CLASSTRAINER"}, {"pet", "LID_PETTRAINING"}, {"trainers", "LID_CLASSTRAINERS"}, {"weapons", "LID_SETTINGS_WEAPONS"}}
            },
            {
                label = "LID_PROFESSIONS",
                key = "professions",
                layout = "professionLayout",
                compendium = "compendium_professions",
                compendiumLabel = "LID_SETTINGS_COMPENDIUM_PROFESSIONS",
                options = {{"profession_skill", "LID_PROFESSION_FROMTRAINER"}, {"profession_recipes", "LID_PROFESSION_OTHERRECIPES"}, {"profession_trainers", "LID_PROFESSION_FINDTRAINER"}}
            }
        }) do
            win:AddCategory({
                label = category.label,
                key = category.key
            })

            local function AddParent(key, label)
                local checkbox = win:AddCheckbox({
                    label = label,
                    added = "2026-10-07",
                    value = TrainerSpells_Character[key] ~= false,
                    func = function(value)
                        TrainerSpells_Character[key] = value
                        for sharedKey, setting in pairs(self.SharedTabSettings) do
                            if setting == key then self:SetSharedSetting(sharedKey, value) end
                        end

                        self:ApplyTabSettings()
                    end
                })

                self.SettingCheckboxes[key] = checkbox
                return checkbox
            end

            local layout = win:AddDropdown({
                label = "LID_SETTINGS_LAYOUT",
                value = self:GetTabLayout(category.layout),
                choices = {
                    {
                        value = "combined",
                        label = "LID_SETTINGS_LAYOUT_COMBINED"
                    },
                    {
                        value = "tabs",
                        label = "LID_SETTINGS_LAYOUT_TABS"
                    }
                },
                func = function(value)
                    TrainerSpells_Character[category.layout] = value
                    self:ApplyTabSettings()
                end
            })

            win:AddDependency(layout, function() return TrainerSpells_Character[category.key] ~= false end, 0)
            local addonTab = AddParent(category.key, "LID_SETTINGS_ADDONTAB")
            local children = {}
            for _, option in ipairs(category.options) do
                local key = option[1]
                local checkbox = win:AddCheckbox({
                    label = option[2],
                    added = "2026-10-07",
                    value = TrainerSpells_Character[key] ~= false,
                    func = function(value)
                        TrainerSpells_Character[key] = value
                        self:ApplyTabSettings()
                    end
                })

                self.SettingCheckboxes[key] = checkbox
                win:AddDependency(checkbox, function() return TrainerSpells_Character[category.key] ~= false or TrainerSpells_Character[category.compendium] ~= false end)
                table.insert(children, checkbox)
            end

            local compendiumTab = AddParent(category.compendium, category.compendiumLabel)
            for _, checkbox in ipairs(children) do
                win:AddRequirement(checkbox, addonTab)
                win:AddRequirement(checkbox, compendiumTab)
            end
        end

        win:UpdateDependencies()
        win:Layout()
    end

    self.SettingsWindow:SetShown(not self.SettingsWindow:IsShown())
end

function TrainerSpells:InitializeSettings()
    self:LoadTabSettings()
    self.SettingsReady = true
    if TrainerSpells_Character.showMinimapButton == nil then TrainerSpells_Character.showMinimapButton = true end
    self:CreateMinimapButton({
        name = "TrainerSpells",
        icon = TrainerSpells:GetAddonIcon(),
        dbtab = TrainerSpells_Character,
        dbkey = "showMinimapButton",
        vTT = {{"TrainerSpells"}, {self:Trans("LID_SETTINGS_OPEN")}},
        funcL = function() self:ToggleSettings() end,
        funcR = function() self:ToggleSettings() end
    })

    self:AddSlash("ts", function() self:ToggleSettings() end)
    self:AddSlash("trainerspells", function() self:ToggleSettings() end)
    self:ApplyTabSettings()
end
