-- ForeverLFG -- Copyright (c) 2026 Forever. All rights reserved. See LICENSE.
local _, NS = ...
local F = NS.Filters
local fields = {"mode", "auto", "seek", "recruit", "levelMin", "levelMax", "classes", "style", "orderGroups", "orderPlayers", "friendsFirst"}
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do if type(v) == "boolean" then result[k] = v end end
    return result
end
function F.SavePreset(name, replace)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    local length = 0
    for _ in name:gmatch("[\1-\127\194-\244][\128-\191]*") do length = length + 1 end
    if name == "" or length > 40 or name:find("[%z\1-\31\127|]") then return false, "BROWSE_BAD_NAME" end
    local s = F.Settings()
    if s.presets[name] and not replace then return false, "BROWSE_REPLACE" end
    local count = 0; for _ in pairs(s.presets) do count = count + 1 end
    if not s.presets[name] and count >= 30 then return false, "BROWSE_PRESET_LIMIT" end
    local preset = {language = NS.Mode()}
    for _, key in ipairs(fields) do preset[key] = Copy(s[key]) end
    s.presets[name], s.activePreset = preset, name
    if F.UpdateUI then F.UpdateUI() end
    return true
end
function F.LoadPreset(name)
    local s = F.Settings()
    local preset = s.presets[name]
    if type(preset) ~= "table" then return false end
    if type(preset.language) == "string" and preset.language ~= "" then
        local _, canonical, err, key = NS.LanguageFilter(preset.language)
        if not canonical then NS.SetStatus(key, err, "validation"); return false end
    end
    for _, key in ipairs(fields) do s[key] = Copy(preset[key]) end
    F.Settings() -- Нормализация сохранённых значений до построения контролов.
    if type(preset.language) == "string" then NS.SelectLanguage(preset.language) end
    s.activePreset, F.resetCollapse = name, true
    if F.ClearLevelDraft then F.ClearLevelDraft() end
    if F.Refresh then F.Refresh() end
    return true
end
