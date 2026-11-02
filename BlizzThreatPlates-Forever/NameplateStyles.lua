local addon = ForeverNameplates
local activeStyle
local ATD_DEFAULTS = {size = 4, name = 11, percent = 11, value = 12}
local JUNDIES_DEFAULTS = {size = 2, name = 12, percent = 12, value = 12}

function addon:GetATDStyleDefaults()
    if self:IsJundiesStyle() then return JUNDIES_DEFAULTS.size,JUNDIES_DEFAULTS.name,JUNDIES_DEFAULTS.percent,JUNDIES_DEFAULTS.value end
    return ATD_DEFAULTS.size, ATD_DEFAULTS.name, ATD_DEFAULTS.percent, ATD_DEFAULTS.value
end

function addon:GetNameplateStyles()
    local result = {}
    local labels = {
        Classic = "UNIT_NAMEPLATES_STYLE_CLASSIC", Modern = "UNIT_NAMEPLATES_STYLE_MODERN",
        Thin = "UNIT_NAMEPLATES_STYLE_THIN", Block = "UNIT_NAMEPLATES_STYLE_BLOCK",
        HealthFocus = "UNIT_NAMEPLATES_STYLE_HEALTH_FOCUS", CastFocus = "UNIT_NAMEPLATES_STYLE_CAST_FOCUS",
        Legacy = "UNIT_NAMEPLATES_STYLE_LEGACY", Default = "UNIT_NAMEPLATES_STYLE_DEFAULT",
    }
    -- Read client enum IDs and localized labels, never assume menu order is ID order.
    for key, global in pairs(labels) do
        local id = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle[key]
        local label = _G[global]
        if id ~= nil and label and (key == "Modern" or key == "Thin"
            or key == "Block" or key == "CastFocus" or id == self:GetNameplateStyle()) then
            if key == "Modern" then label = "Blizzard Large"
            elseif key == "Thin" then label = "Blizzard Default" end
            result[#result + 1] = {id = id, key = key, name = label}
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    result[#result + 1] = {id = "ATD", key = "ATD", name = "ATD Inspired"}
    result[#result + 1] = {id = "JUNDIES", key = "JUNDIES", name = "Jundies Inspired"}
    if self.GetDevNameplateStyles then
        for _,style in ipairs(self:GetDevNameplateStyles()) do result[#result+1]=style end
    end
    return result
end

function addon:IsATDStyle()
    if self:GetCompatibilityMode() then return false end
    local appearance = ForeverNameplatesDB and ForeverNameplatesDB.appearance
    return appearance and (appearance.customStyle == "ATD" or appearance.customStyle == "JUNDIES") or false
end
function addon:IsJundiesStyle()
    return not self:GetCompatibilityMode() and ForeverNameplatesDB and ForeverNameplatesDB.appearance
        and ForeverNameplatesDB.appearance.customStyle=="JUNDIES" or false
end

local function SelectedStyle()
    return addon:IsATDStyle() and addon:GetNameplateStyleFamily() or addon:GetNameplateStyle()
end

function addon:GetNameplateStyle()
    return tonumber(GetCVar("nameplateStyle")) or 0
end

function addon:GetNameplateStyleFamily()
    if self:IsATDStyle() then
        return (self.GetSelectedDevNameplateStyleId and self:GetSelectedDevNameplateStyleId())
            or (self:IsJundiesStyle() and "JUNDIES" or "ATD")
    end
    local styles = Enum.NamePlateStyle
    local id = self:GetNameplateStyle()
    if id == styles.Block then return styles.Modern end
    if id == styles.CastFocus then return styles.Thin end
    return id
end

function addon:GetCastbarThick()
    local styles = Enum.NamePlateStyle
    local id = self:GetNameplateStyle()
    return id == styles.Block or id == styles.CastFocus
end

function addon:GetNameplateHealthInfoFlags(applied)
    if self:IsATDStyle() then
        local defaults = self.defaults.atdHealthText
        local saved = ForeverNameplatesDB and ForeverNameplatesDB.atdHealthText or {}
        if self.IsJundiesStyle and self:IsJundiesStyle() then
            defaults={percentEnabled=true,valueEnabled=true}
            saved=ForeverNameplatesDB and ForeverNameplatesDB.jundiesHealthText or {}
        end
        local percent, value = saved.percentEnabled, saved.valueEnabled
        if percent == nil then percent = defaults.percentEnabled end
        if value == nil then value = defaults.valueEnabled end
        return percent == true, value == true
    end
    local flags = Enum and Enum.NamePlateInfoDisplay or {}
    local function Enabled(index)
        return self:IsNameplateBitfieldEnabled("nameplateInfoDisplay", index, applied)
    end
    return Enabled(flags.CurrentHealthPercent or 1), Enabled(flags.CurrentHealthValue or 2)
end

function addon:SetNameplateHealthInfoEnabled(kind, enabled)
    if kind ~= "percent" and kind ~= "value" then return end
    enabled = enabled and true or false
    if self:IsATDStyle() then
        ForeverNameplatesDB = ForeverNameplatesDB or {}
        local key=self.IsJundiesStyle and self:IsJundiesStyle() and "jundiesHealthText" or "atdHealthText"
        ForeverNameplatesDB[key] = ForeverNameplatesDB[key] or {}
        ForeverNameplatesDB[key][kind.."Enabled"] = enabled
        if self.RefreshATDStyle then self:RefreshATDStyle() end
    else
        local flags = Enum and Enum.NamePlateInfoDisplay or {}
        local index = kind == "percent" and (flags.CurrentHealthPercent or 1) or (flags.CurrentHealthValue or 2)
        self:SetNameplateBitfieldIndex("nameplateInfoDisplay", index, enabled)
    end
    if self.RefreshStyleOptions then self:RefreshStyleOptions() end
end

local function SaveProfile(id)
    local db = ForeverNameplatesDB
    if not db or id == nil or addon:GetCompatibilityMode() then return end
    db.appearance.styleProfiles = db.appearance.styleProfiles or {}
    db.appearance.styleProfiles[id] = {
        size = addon:GetNameplateSize(), name = addon:GetMobNameFontSize(),
        percent = addon:GetHealthPercentFontSize(), value = addon:GetHealthValueFontSize(),
        infoDisplay = addon:GetNameplateBitfieldMask("nameplateInfoDisplay"),
    }
end

function addon:CaptureCompatibilityStyle()
    local db = ForeverNameplatesDB
    if not db or not db.appearance then return end
    local selected = SelectedStyle()
    SaveProfile(selected)
    db.compatibilityStyle = {selected=selected,native=self:GetNameplateStyle(),size=self:GetNameplateSize(),
        custom=db.appearance.customStyle,draft=db.appearance.devStyleDraft,
        infoDisplay=self:GetNameplateBitfieldMask("nameplateInfoDisplay")}
end

function addon:RestoreCompatibilityStyle()
    local db = ForeverNameplatesDB
    local saved = db and db.compatibilityStyle
    if not saved or not db.appearance then return end
    db.appearance.customStyle,db.appearance.devStyleDraft = saved.custom,saved.draft
    db.appearance.style,db.appearance.size = saved.selected,saved.size
    activeStyle = saved.selected
    -- Restore the saved selection before repainting any live feature. Another
    -- addon may have changed these CVars while it owned the nameplates.
    self:SetNameplateCVar("nameplateStyle",saved.native)
    self:SetNameplateCVar("nameplateSize",saved.size)
    self:SetNameplateBitfieldMask("nameplateInfoDisplay",saved.infoDisplay)
    db.compatibilityStyle = nil
end

function addon:InitializeNameplateStyles()
    if self:GetCompatibilityMode() then
        local saved = ForeverNameplatesDB.compatibilityStyle
        activeStyle = saved and saved.selected or ForeverNameplatesDB.appearance.style
        return
    end
    -- A custom skin uses a real native style underneath; never write its string
    -- ID to Blizzard's numeric CVar. Respect an external native-style change.
    if self:IsATDStyle() and self:GetNameplateStyle() ~= Enum.NamePlateStyle.Modern then
        ForeverNameplatesDB.appearance.customStyle = nil
    end
    activeStyle = SelectedStyle()
    ForeverNameplatesDB.appearance.style = activeStyle
    -- Adopt Blizzard's current selection without writing nameplateStyle.
    -- Large/Modern keeps the BTP label; other native styles stay selected.
end

local function StyleChanged()
    if not ForeverNameplatesDB or not ForeverNameplatesDB.appearance then return end
    if addon:GetCompatibilityMode() then return end
    if addon:IsATDStyle() and addon:GetNameplateStyle() ~= Enum.NamePlateStyle.Modern then
        if addon.RestoreATDStyle then addon:RestoreATDStyle() end
        ForeverNameplatesDB.appearance.customStyle = nil
    end
    local id = SelectedStyle()
    if id ~= activeStyle then
        SaveProfile(activeStyle)
        local profiles = ForeverNameplatesDB.appearance.styleProfiles or {}
        local profile = profiles[id]
        if addon:IsATDStyle() and not profile then
            profile = id=="JUNDIES" and JUNDIES_DEFAULTS or ATD_DEFAULTS
        end
        activeStyle = id
        ForeverNameplatesDB.appearance.style = id
        -- First visit inherits the current settings; subsequent visits restore
        -- that style's own adjustments. No speculative font-size presets.
        if profile then
            addon:SetNameplateSize(profile.size)
            addon:SetMobNameFontSize(profile.name)
            addon:SetHealthPercentFontSize(profile.percent)
            addon:SetHealthValueFontSize(profile.value)
        end
    end
    if addon.ApplyNameplateDimensions then addon:ApplyNameplateDimensions() end
    if addon.ApplyNativeTextSizes then addon:ApplyNativeTextSizes() end
    if addon.RefreshNativeCCFallbacks then addon:RefreshNativeCCFallbacks() end
    if addon.RefreshStyleOptions then addon:RefreshStyleOptions() end
end

function addon:SetNameplateStyle(id)
    if InCombatLockdown() then
        print("BlizzThreatPlates: change nameplate style after combat.")
        return
    end
    for _, style in ipairs(self:GetNameplateStyles()) do
        if style.id == id then
            if addon.RestoreATDStyle then addon:RestoreATDStyle() end
            local custom = id == "ATD" or id=="JUNDIES" or style.key == "DevDraft"
            ForeverNameplatesDB.appearance.customStyle = id=="JUNDIES" and "JUNDIES" or custom and "ATD" or nil
            ForeverNameplatesDB.appearance.devStyleDraft = style.key == "DevDraft" and id or nil
            SetCVar("nameplateStyle", custom and Enum.NamePlateStyle.Modern or id)
            StyleChanged()
            if addon.RefreshATDStyle then addon:RefreshATDStyle() end
            return
        end
    end
end

function addon:SetCastbarThick(thick)
    if InCombatLockdown() then
        print("BlizzThreatPlates: change castbar style after combat.")
        return
    end
    local styles = Enum.NamePlateStyle
    local family = self:GetNameplateStyleFamily()
    local id
    if family == styles.Modern then id = thick and styles.Block or styles.Modern
    elseif family == styles.Thin then id = thick and styles.CastFocus or styles.Thin end
    if id == nil or id == self:GetNameplateStyle() then return end
    -- Castbar thickness should not change the user's health/name text sizes.
    SaveProfile(id)
    self:SetNameplateStyle(id)
end

local events = CreateFrame("Frame")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, cvar)
    if event == "PLAYER_LOGOUT" then SaveProfile(activeStyle)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if addon.RefreshStyleOptions then addon:RefreshStyleOptions() end
    elseif cvar == "nameplateStyle" or cvar == "NAMEPLATESTYLE" then
        C_Timer.After(0, StyleChanged)
    end
end)

SLASH_BTPSTYLES1 = "/btpstyles"
SlashCmdList.BTPSTYLES = function()
    print("BTP native style: "..addon:GetNameplateStyle())
    for _, style in ipairs(addon:GetNameplateStyles()) do
        print(style.name.." = "..style.id.." ("..style.key..")")
    end
end
