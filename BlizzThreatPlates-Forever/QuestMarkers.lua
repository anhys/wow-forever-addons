local addon = ForeverNameplates
local labels = {}
local labelsByPlate = setmetatable({}, {__mode="k"})
local activeUnits = {}
local driver = CreateFrame("Frame")
driver:Hide()
local elapsed = 0
function addon:SetQuestObjectiveIcon(texture, state)
    if state == "complete" then
        texture:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        return
    end
    local atlas = "QuestNormal"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
    else
        texture:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
end
function addon:GetQuestIconSettings()
    local db = ForeverNameplatesDB or self.defaults
    local position = db.questIconPosition or self.defaults.questIconPosition
    return db.questIconSize or 24, position.x or -6, position.y or 0
end
function addon:GetQuestIconPreviewGeometry()
    local _, x, y = self:GetQuestIconSettings()
    local result = self:GetNameplatePreviewGeometry()
    result.x, result.y = x, y
    return result
end
local threatMeasure
local measuredFontSize
local measuredText, measuredWidth, measuredHeight
local function PublishQuest(label,visible)
    if label and addon.SetNameplateQuestAttachment then
        addon:SetNameplateQuestAttachment(label:GetParent(),label,visible)
    end
end
local function ThreatTextSize(region)
    local size = addon:GetThreatDifferentialSize()
    local text = region and region:GetText()
    -- Secret percentage strings cannot be measured safely. Reserve a
    -- conservative text width instead of inspecting or converting them.
    if issecretvalue and issecretvalue(text) then return size * 8, size * 1.4 end
    if type(text) ~= "string" or text == "" then return 0, size * 1.4 end
    if measuredFontSize == size and measuredText == text then return measuredWidth, measuredHeight end
    -- Measure a detached, addon-owned copy, never a region on a live plate.
    threatMeasure = threatMeasure or UIParent:CreateFontString(nil, "OVERLAY")
    threatMeasure:Hide()
    if measuredFontSize ~= size then
        threatMeasure:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        measuredFontSize = size
    end
    threatMeasure:SetText(text)
    measuredText = text
    measuredWidth, measuredHeight = threatMeasure:GetStringWidth(), math.max(size, threatMeasure:GetStringHeight())
    return measuredWidth, measuredHeight
end
function addon:GetThreatDisplayX(unit, savedX, plate, region, savedY)
    local ccWidth=self.GetNameplateLeftCCWidth and self:GetNameplateLeftCCWidth(plate) or 0
    if ccWidth>0 then
        local ccX=self.GetNameplateLeftCCOffset and self:GetNameplateLeftCCOffset(plate) or -6
        savedX=math.min(savedX,ccX-ccWidth-6)
    end
    local label = labels[unit] or (plate and labelsByPlate[plate])
    if not ForeverNameplatesDB or not ForeverNameplatesDB.questMarker or not label or not label:IsShown() then return savedX end
    local iconSize, iconX, iconY = self:GetQuestIconSettings()
    local width, height = ThreatTextSize(region)
    local y = savedY
    if y == nil then local unusedX; unusedX, y = self:GetOverlayPosition("threat") end
    local gap = 4
    -- Both overlays anchor their right edge to the health bar's left edge;
    -- compare those saved coordinates without querying Blizzard's geometry.
    local overlapsX = savedX > iconX - iconSize - gap and savedX - width < iconX + gap
    local overlapsY = math.abs(y - iconY) < (height + iconSize) / 2 + gap
    if width > 0 and overlapsX and overlapsY then return math.min(savedX, iconX - iconSize - gap) end
    return savedX
end
local function Refresh()
    local enabled = addon.GetQuestMarkersEnabled and addon:GetQuestMarkersEnabled()
        or (not addon.GetQuestMarkersEnabled and ForeverNameplatesDB and ForeverNameplatesDB.questMarker)
    if not enabled or not next(activeUnits) then
        for _, label in pairs(labels) do label:Hide(); PublishQuest(label,false) end
        driver:Hide()
        return
    end
    driver:Show()
    local size, x, y = addon:GetQuestIconSettings()
    for unit in pairs(activeUnits) do
        local plate = addon:GetPlate(unit)
        local label = labels[unit]
        local state = plate and addon:GetQuestObjectiveState(unit)
        if state then
            if not label then
                label = CreateFrame("Frame", nil, plate)
                label.icon = label:CreateTexture(nil, "OVERLAY")
                label.icon:SetAllPoints()
                labels[unit] = label
            end
            if label:GetParent() ~= plate then
                PublishQuest(label,false)
                labelsByPlate[label:GetParent()] = nil
                label:SetParent(plate)
            end
            labelsByPlate[plate] = label
            if label.btpSize ~= size then label:SetSize(size, size); label.btpSize = size end
            if label.btpState ~= state then addon:SetQuestObjectiveIcon(label.icon, state); label.btpState = state end
            local anchor = addon:GetThreatOverlayAnchor(plate)
            if label.btpAnchor ~= anchor or label.btpX ~= x or label.btpY ~= y then
                label:ClearAllPoints()
                label:SetPoint("RIGHT", anchor, "LEFT", x, y)
                label.btpAnchor, label.btpX, label.btpY = anchor, x, y
            end
            label:Show()
            PublishQuest(label,true)
        elseif label then label:Hide(); PublishQuest(label,false) end
    end
end
addon.RefreshQuestMarkers = Refresh
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    Refresh()
end)
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        activeUnits[unit] = nil
        if labels[unit] then labels[unit]:Hide(); PublishQuest(labels[unit],false) end
        addon:ClearQuestMobCache(unit)
        if not next(activeUnits) then driver:Hide() end
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        activeUnits[unit] = true
        addon:ClearQuestMobCache(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        for key in pairs(activeUnits) do activeUnits[key] = nil end
        for _, label in pairs(labels) do label:Hide(); PublishQuest(label,false) end
        -- Seed existing plates once on login/zoning; normal updates are driven
        -- by add/remove events instead of probing every possible slot.
        for i=1,40 do
            local token = "nameplate"..i
            if addon:GetPlate(token) then activeUnits[token] = true end
        end
        addon:ClearQuestMobCache()
    else
        addon:ClearQuestMobCache()
    end
    Refresh()
end)
