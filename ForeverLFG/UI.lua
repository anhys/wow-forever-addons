-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local T = NS.Text
local events = CreateFrame("Frame")
local function Menu(_, root)
    root:CreateTitle(T("LANGUAGE_MENU"))
    local function Select(mode)
        NS.SelectLanguage(mode)
        NS.Filters.Settings().activePreset = nil
        if NS.Filters.UpdateUI then NS.Filters.UpdateUI() end
        NS.UpdateUI()
    end
    local available = NS.AvailableLanguages()
    local all = root:CreateRadio(T("ALL_LANGUAGES"), function() return NS.Mode() == "all" end, Select, "all")
    all:SetEnabled(available ~= nil)
    local default = root:CreateRadio(T("GAME_DEFAULT"), function() return NS.Mode() == "default" end, Select, "default")
    if MenuResponse then all:SetResponse(MenuResponse.Refresh); default:SetResponse(MenuResponse.Refresh) end
    root:CreateDivider()
    if available then
        for _, code in ipairs(available) do
            local label = NS.LanguageLabel(code)
            local item = root:CreateCheckbox(label == code and code or label .. " (" .. code .. ")", function(value)
                local mode = NS.Mode()
                if mode == "all" or mode == "default" then return false end
                for chosen in mode:gmatch("[^,]+") do if chosen == value then return true end end
                return false
            end, function(value)
                local selected = {}
                local mode = NS.Mode()
                if mode ~= "all" and mode ~= "default" then for chosen in mode:gmatch("[^,]+") do selected[chosen] = true end end
                selected[value] = not selected[value] or nil
                local values = {}; for chosen in pairs(selected) do values[#values+1] = chosen end
                table.sort(values); Select(table.concat(values, ","))
            end, code)
            if MenuResponse then item:SetResponse(MenuResponse.Refresh) end
        end
    else root:CreateTitle(T("LANGUAGES_FAILED")) end
end
NS.GenerateLanguageMenu = Menu
function NS.OpenLanguageMenu(owner)
    owner = owner or NS.LanguageDropdown
    if not owner or not owner.OpenMenu or InCombatLockdown() then return end
    NS.UpdateUI()
    owner:OpenMenu()
end
function NS.UpdateUI()
    if NS.LanguageDropdown then NS.LanguageDropdown.Label:SetText(NS.LanguageLabel(NS.Mode())) end
    if NS.UpdateRefreshUI then NS.UpdateRefreshUI() end
    if NS.BrowseControls and NS.Filters.UpdateUI then NS.Filters.UpdateUI() end
    if NS.Filters.RefreshRows then NS.Filters.RefreshRows() end
    if NS.UpdateActivityOptions then NS.UpdateActivityOptions() end
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "LFG_LIST_AVAILABILITY_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", NS.UpdateUI)
