local addon = ForeverNameplates
local valid = {LEFT=true, CENTER=true, RIGHT=true, DEFAULT=true}

local function Profile(create)
    local db = ForeverNameplatesDB
    if create then
        db = db or {}; ForeverNameplatesDB = db
        db.appearance = db.appearance or {}
        db.appearance.textAlignments = db.appearance.textAlignments or {}
    end
    local profiles = db and db.appearance and db.appearance.textAlignments
    local key = tostring(addon:GetNameplateStyleFamily())
    if create then profiles[key] = profiles[key] or {} end
    return profiles and profiles[key]
end

function addon:GetNameplateTextAlignment(kind)
    local profile = Profile()
    local choice = profile and profile[kind]
    return valid[choice] and choice or "DEFAULT"
end

function addon:SetNameplateTextAlignment(kind, choice)
    if (kind ~= "name" and kind ~= "percent" and kind ~= "value") or not valid[choice] or self:GetCompatibilityMode() then return end
    Profile(true)[kind] = choice
    if self.ApplyNativeTextSizes then self:ApplyNativeTextSizes() end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    if self.RefreshStyleOptions then self:RefreshStyleOptions() end
end

function addon:GetNameplateNameEnabled()
    local profile = Profile()
    return not profile or profile.nameEnabled ~= false
end

function addon:SetNameplateNameEnabled(enabled)
    if self:GetCompatibilityMode() then return end
    Profile(true).nameEnabled = enabled == true
    if self.ApplyNativeTextSizes then self:ApplyNativeTextSizes() end
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    if self.RefreshStyleOptions then self:RefreshStyleOptions() end
end

function addon:ApplyNameplateNameAlignment(name, bar, above)
    if not name or self:GetCompatibilityMode() then return end
    local align = self:GetNameplateTextAlignment("name")
    if align == "DEFAULT" then return end
    if above then
        local y = NamePlateSetupOptions and NamePlateSetupOptions.healthBarToNameAboveSpacing or 2
        name:ClearAllPoints(); name:SetWidth(0)
        name:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",3,y)
        name:SetPoint("BOTTOMRIGHT",bar,"TOPRIGHT",-3,y)
    end
    name:SetJustifyH(align)
end

-- All dimensions come from public font settings. Never measure live text,
-- frame geometry, or saved anchors: health text and its regions may be secret.
function addon:ApplyNameplateTextAlignment(bar, percent, value, percentOn, valueOn, name, force)
    if self:GetCompatibilityMode() then return false end
    local percentAlign, valueAlign = self:GetNameplateTextAlignment("percent"), self:GetNameplateTextAlignment("value")
    if percentAlign == "DEFAULT" and valueAlign == "DEFAULT" and not force then
        if name then self:ApplyNameplateNameAlignment(name,bar,false) end
        return false
    end
    if percentAlign == "DEFAULT" then percentAlign = "RIGHT" end
    if valueAlign == "DEFAULT" then valueAlign = "RIGHT" end
    local groups = {LEFT={}, CENTER={}, RIGHT={}}
    if valueOn and value then groups[valueAlign][#groups[valueAlign]+1] = {label=value, width=self:GetHealthValueFontSize()*5.5+2} end
    if percentOn and percent then groups[percentAlign][#groups[percentAlign]+1] = {label=percent, width=self:GetHealthPercentFontSize()*3.5+2} end
    local firstCenter, lastLeft, firstRight
    for _, align in ipairs({"LEFT", "CENTER", "RIGHT"}) do
        local group, total = groups[align], 0
        for _, item in ipairs(group) do total = total + item.width + 4 end
        total = math.max(0,total-4)
        local offset = align == "LEFT" and 3 or align == "CENTER" and -total/2 or -total-3
        for _, item in ipairs(group) do
            local label = item.label
            label:ClearAllPoints(); label:SetWidth(item.width); label:SetJustifyH(align)
            label:SetPoint("LEFT",bar,align,offset,0)
            offset = offset + item.width + 4
        end
        if align == "LEFT" and #group>0 then lastLeft = group[#group].label end
        if align == "CENTER" and #group>0 then firstCenter = group[1].label end
        if align == "RIGHT" and #group>0 then firstRight = group[1].label end
    end
    if name then
        name:ClearAllPoints(); name:SetWidth(0); name:SetJustifyH("LEFT")
        name:SetPoint("LEFT",lastLeft or bar,lastLeft and "RIGHT" or "LEFT",lastLeft and 4 or 3,0)
        local boundary = firstCenter or firstRight
        name:SetPoint("RIGHT",boundary or bar,boundary and "LEFT" or "RIGHT",boundary and -4 or -3,0)
        self:ApplyNameplateNameAlignment(name,bar,false)
    end
    return true
end
