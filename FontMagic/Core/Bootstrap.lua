-- Shared namespace and constants. This file must be first in FontMagic.toc.
local addonName, FM = ...

if type(FM) ~= "table" then
    error("FontMagic requires WoW's shared addon namespace", 0)
end

addonName = type(addonName) == "string" and addonName ~= "" and addonName or "FontMagic"

FM.Constants = FM.Constants or {}
FM.Paths = FM.Paths or {}
FM.Compat = FM.Compat or {}
FM.CVars = FM.CVars or {}
FM.Database = FM.Database or {}
FM.Fonts = FM.Fonts or {}
FM.CombatFont = FM.CombatFont or {}
FM.CombatTextFix = FM.CombatTextFix or {}
FM.CombatSettings = FM.CombatSettings or {}
FM.UI = FM.UI or {}
FM.Window = FM.Window or {}
FM.Minimap = FM.Minimap or {}
FM.Events = FM.Events or {}
FM.State = FM.State or {}

FM.Constants.ADDON_NAME = addonName
FM.Constants.CUSTOM_ADDON = "FontMagicCustomFonts"
FM.Constants.DEFAULT_MINIMAP_ANGLE = 225
FM.Constants.CUSTOM_FONT_COUNT = 20
FM.Constants.FALLBACK_FONT_PATH = "Fonts\\FRIZQT__.TTF"

FM.Paths.Addon = "Interface\\AddOns\\" .. addonName .. "\\"
FM.Paths.Media = FM.Paths.Addon .. "Media\\"
FM.Paths.CustomAddon = "Interface\\AddOns\\" .. FM.Constants.CUSTOM_ADDON .. "\\"
FM.Paths.Custom = FM.Paths.CustomAddon .. "Custom\\"
