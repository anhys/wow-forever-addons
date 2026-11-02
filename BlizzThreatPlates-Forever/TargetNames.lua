local addon = ForeverNameplates
local plates = {}
local updater = CreateFrame("Frame")
local elapsed = 0
local UPDATE_INTERVAL = 0.10
local FONT_SIZE = 16

-- Keep the sample independent of target selection and native plate animations.
function addon:GetTargetNamePreviewScale()
    return UIParent:GetEffectiveScale()
end

function addon:ApplyTargetNameFont(label,size)
    -- Reset the font object so leaving Jundies restores the normal face on
    -- reused labels, including the separate first/last-name labels.
    label:SetFontObject(SystemFont_NamePlate or GameFontNormal)
    if self:IsJundiesStyle() then
        self:SetFontWithFallback(label,self:GetJundiesFontPath(),size,"OUTLINE")
    else
        local font=label:GetFont()
        if font then label:SetFont(font,size,"OUTLINE") end
    end
    label:SetShadowColor(0,0,0,1)
    label:SetShadowOffset(1,-1)
end

local function CanAccessFrame(frame)
    if not frame then return false end
    local forbidden=frame.IsForbidden and frame:IsForbidden()
    if (issecretvalue and issecretvalue(forbidden)) or forbidden then return false end
    if frame.CanBeAccessedInContext then
        local allowed=frame:CanBeAccessedInContext()
        return not (issecretvalue and issecretvalue(allowed)) and allowed==true
    end
    return true
end

local function Children(frame)
    if not CanAccessFrame(frame) or not frame.GetChildren then return {} end
    local ok,children=pcall(function() return {frame:GetChildren()} end)
    return ok and children or {}
end

local function FindHealthBar(frame)
    if not CanAccessFrame(frame) then return nil end
    if CanAccessFrame(frame.healthBar) and frame.healthBar.GetObjectType and frame.healthBar:GetObjectType() == "StatusBar" then
        return frame.healthBar
    end
    if CanAccessFrame(frame.HealthBar) and frame.HealthBar.GetObjectType and frame.HealthBar:GetObjectType() == "StatusBar" then
        return frame.HealthBar
    end
    if frame.unitFrame or frame.UnitFrame then
        local uf = frame.unitFrame or frame.UnitFrame
        if CanAccessFrame(uf) and CanAccessFrame(uf.healthBar) and uf.healthBar.GetObjectType and uf.healthBar:GetObjectType() == "StatusBar" then
            return uf.healthBar
        end
        if CanAccessFrame(uf) and CanAccessFrame(uf.HealthBar) and uf.HealthBar.GetObjectType and uf.HealthBar:GetObjectType() == "StatusBar" then
            return uf.HealthBar
        end
    end

    local best, bestWidth
    local function Scan(parent)
        for _, child in ipairs(Children(parent)) do
            if CanAccessFrame(child) and child.GetObjectType and child:GetObjectType() == "StatusBar" then
                -- This legacy fallback may encounter measurement-restricted
                -- bars. Only compare readable widths; a bar itself remains a
                -- valid anchor even when its dimensions cannot be inspected.
                if not best then best=child end
                local ok,w=pcall(child.GetWidth,child)
                if ok and not (issecretvalue and issecretvalue(w)) and type(w)=="number" then
                    if not bestWidth or w > bestWidth then best,bestWidth=child,w end
                end
            end
            Scan(child)
        end
    end
    Scan(frame)
    return best
end

local function StyleLabel(label)
    label:SetJustifyH("RIGHT")
    addon:ApplyTargetNameFont(label,FONT_SIZE)
end

local function FitTargetName(label, fullNameMode, text)
    addon:ApplyTargetNameFont(label,addon:GetTargetNameFontSize())
end

local function FindNativeCastBar(plate)
    if not CanAccessFrame(plate) then return nil end
    local uf = plate.UnitFrame
    if uf and not CanAccessFrame(uf) then return nil end
    if addon.GetATDCastBar then
        local custom = addon:GetATDCastBar(plate)
        if CanAccessFrame(custom) then return custom end
    end
    local container = uf and (uf.CastBarsContainer or uf.castBarsContainer)
    if container and not CanAccessFrame(container) then container=nil end
    local native = uf and (uf.castBar or uf.CastBar) or nil
    native = native or (container and container.castBar)
    if CanAccessFrame(native) then return native end

    local children = Children(plate)
    local root = children[1]
    if not root then return nil end

    local rootChildren = Children(root)
    local castContainer = rootChildren[2]
    if not castContainer then return nil end

    local castChildren = Children(castContainer)
    local castBar = castChildren[1]

    if CanAccessFrame(castBar) and castBar.GetObjectType and castBar:GetObjectType() == "StatusBar" then
        return castBar
    end
    return nil
end

local function GetTargetNameRightOffset()
    if addon:GetCompatibilityMode() then return 0 end
    local styles = Enum and Enum.NamePlateStyle or {}
    local style = addon:GetNameplateStyleFamily()
    -- Large and Default both need the label's right edge extended beyond the
    -- health StatusBar so it aligns with the complete native nameplate frame.
    if style == (styles.Modern or 0) or style == (styles.Thin or 1) then
        return 28
    end
    return 0
end

local function AnchorLabel(data)
    local healthBar
    if addon:IsATDStyle() and addon.GetATDHealthBar then
        healthBar = addon:GetATDHealthBar(data.plate)
    end
    healthBar = healthBar or FindHealthBar(data.plate) or data.plate
    local offset = addon:IsATDStyle() and 0 or GetTargetNameRightOffset()
    local castBar = FindNativeCastBar(data.plate)
    local casting = castBar and castBar:IsShown() or false
    local positionX, positionY = addon:GetOverlayPosition("target")

    -- Both native and ATD artwork lives on child frames. OVERLAY alone cannot
    -- put a root-owned FontString in front of those frames.
    data.frontLayer = data.plate.btpTargetNameFront
    if not data.frontLayer then
        data.frontLayer = CreateFrame("Frame", nil, data.plate)
        data.frontLayer:EnableMouse(false)
        data.plate.btpTargetNameFront = data.frontLayer
    end
    data.frontLayer:SetParent(data.plate)
    local unitFrame=data.plate.UnitFrame or data.plate.unitFrame
    data.frontLayer:SetFrameLevel(math.max(data.plate:GetFrameLevel(),healthBar:GetFrameLevel(),
        unitFrame and unitFrame:GetFrameLevel() or 0,castBar and castBar:GetFrameLevel() or 0) + 5)
    local labelParent = data.frontLayer
    if data.labelParent ~= labelParent then
        data.label:SetParent(labelParent)
        if data.lastLabel then data.lastLabel:SetParent(labelParent) end
        if data.roleIcon then data.roleIcon:SetParent(labelParent) end
        data.labelParent = labelParent
        data.anchor = nil
    end

    if data.anchor ~= healthBar or data.casting ~= casting or data.offset ~= offset or data.castAnchor ~= castBar or data.anchoredDrop ~= data.targetDrop or data.positionX ~= positionX or data.positionY ~= positionY then
        data.label:ClearAllPoints()
        if data.lastLabel then data.lastLabel:ClearAllPoints() end

        -- Full names use two FontStrings. This lets secret first/last-name
        -- values flow directly into Blizzard FontStrings without addon-side
        -- comparison or concatenation. The last-name label owns the original
        -- right edge; the first-name label sits immediately to its left.
        -- Align tops, not centers: an empty last name has no text height.
        -- Center alignment would lift a pet/NPC first name into the bar.
        if casting then
            local castOffset = addon:IsATDStyle() and (1 - (data.targetDrop or 1.5)) or -3
            if data.lastLabel then
                data.lastLabel:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT", positionX, castOffset + positionY)
                data.label:SetPoint("TOPRIGHT", data.lastLabel, "TOPLEFT", -1, 0)
            else
                data.label:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT", positionX, castOffset + positionY)
            end
        else
            local y = addon:IsATDStyle() and -(data.targetDrop or 1.5) or -5
            if data.lastLabel then
                data.lastLabel:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset + positionX, y + positionY)
                data.label:SetPoint("TOPRIGHT", data.lastLabel, "TOPLEFT", -1, 0)
            else
                data.label:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset + positionX, y + positionY)
            end
        end

        data.anchor = healthBar
        data.casting = casting
        data.offset = offset
        data.castAnchor = castBar
        data.anchoredDrop = data.targetDrop
        data.positionX, data.positionY = positionX, positionY
    end
end

local function EnsureLabel(unit)
    local plate = addon:GetPlate(unit)
    if not CanAccessFrame(plate) then return end
    local data = plates[unit]
    local targetDrop = 1.5
    if addon:IsATDStyle() and UnitIsPlayer then
        local isPlayer = UnitIsPlayer(unit .. "target")
        -- Restricted classification must never be used in a Lua comparison.
        if not (issecretvalue and issecretvalue(isPlayer)) and isPlayer == false then
            targetDrop = 2.5
        end
    end
    if data then data.targetDrop = targetDrop end
    if not data then
        local label = plate:CreateFontString(nil, "OVERLAY")
        local lastLabel = plate:CreateFontString(nil, "OVERLAY")
        StyleLabel(label)
        StyleLabel(lastLabel)
        data = {plate=plate, label=label, lastLabel=lastLabel, targetDrop=targetDrop}
        plates[unit] = data
        AnchorLabel(data)
    elseif data.plate ~= plate then
        data.plate = plate
        data.anchor = nil
        data.labelParent = nil
        data.label:SetParent(plate)
        if data.lastLabel then data.lastLabel:SetParent(plate) end
        if data.roleIcon then data.roleIcon:SetParent(plate) end
        AnchorLabel(data)
    else
        AnchorLabel(data)
    end
    return data
end

-- Forever may mark UnitClass data for compound units such as nameplateNtarget
-- as secret. Never use the class token as a Lua table key. Instead pass it to
-- the native C_ClassColor API, then pass its RGB values directly to the
-- FontString. This keeps the class->color conversion outside addon Lua.
local function SetTargetColor(label, targetUnit)
    local r, g, b, colored = addon:GetUnitClassColor(targetUnit)
    if colored then
        label:SetTextColor(r, g, b)
        return
    end

    label:SetTextColor(1, 1, 1)
end




local function UpdateUnit(unit)
    if not addon:GetTargetNamesEnabled() then return end
    local data = EnsureLabel(unit)
    if not data then return end
    if addon.GetFriendlyTargetNamesEnabled and not addon:GetFriendlyTargetNamesEnabled() then
        local friendly = UnitIsFriend("player", unit)
        -- Unknown affiliation must not leak friendly labels through the filter.
        if (issecretvalue and issecretvalue(friendly)) or friendly then
            data.label:Hide()
            if data.lastLabel then data.lastLabel:Hide() end
            return
        end
    end
    local targetUnit = unit .. "target"

    local exists = UnitExists(targetUnit)
    if not (issecretvalue and issecretvalue(exists)) and exists then
        local fullName = addon:GetFullTargetNames()
        if addon:IsATDStyle() and fullName and UnitIsPlayer then
            local isPlayer = UnitIsPlayer(targetUnit)
            -- Pets/NPCs use the identical single-label layout in either mode.
            -- Do not inspect a potentially secret last name to detect emptiness.
            if not (issecretvalue and issecretvalue(isPlayer)) and isPlayer == false then
                fullName = false
            end
        end
        if fullName and UnitFullName and data.lastLabel then
            local first, last = UnitFullName(targetUnit)

            -- IMPORTANT: first/last may be secret strings in instances/combat.
            -- Do not compare, concatenate, measure, or otherwise inspect them.
            -- Passing each value straight to its own FontString is secret-safe.
            data.label:SetText(first)
            data.lastLabel:SetText(last)
            FitTargetName(data.label, true, first)
            FitTargetName(data.lastLabel, true, last)
            SetTargetColor(data.label, targetUnit)
            SetTargetColor(data.lastLabel, targetUnit)
            data.label:Show()
            data.lastLabel:Show()
            return
        else
            local name = UnitName(targetUnit)
            if (issecretvalue and issecretvalue(name)) or name then
                data.label:SetText(name)
                FitTargetName(data.label, false, name)
                SetTargetColor(data.label, targetUnit)
                data.label:Show()
                if data.lastLabel then
                    data.lastLabel:SetText("")
                    data.lastLabel:Hide()
                end

                -- With last names disabled there is only one visible FontString.
                -- Center that label under the health bar rather than retaining
                -- the full-name layout's right-edge anchor.
                local healthBar
                if addon:IsATDStyle() and addon.GetATDHealthBar then
                    healthBar = addon:GetATDHealthBar(data.plate)
                end
                healthBar = healthBar or FindHealthBar(data.plate) or data.plate
                local castBar = FindNativeCastBar(data.plate)
                local positionX, positionY = addon:GetOverlayPosition("target")
                data.label:ClearAllPoints()
                if castBar and castBar:IsShown() then
                    data.label:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT", positionX, (addon:IsATDStyle() and (1 - (data.targetDrop or 1.5)) or -3) + positionY)
                else
                    -- Keep NPC/pet single-name targets on the same ATD vertical
                    -- baseline as the full-name path. Last-name visibility must
                    -- change text only, never move the target-of-target upward.
                    local offset = addon:IsATDStyle() and 0 or GetTargetNameRightOffset()
                    data.label:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offset + positionX, (addon:IsATDStyle() and -(data.targetDrop or 1.5) or -5) + positionY)
                end
                data.label:SetJustifyH("RIGHT")

                -- This branch temporarily overrides the normal two-part
                -- first/last-name anchor layout. Invalidate the cached anchor
                -- so toggling Last Name back on forces AnchorLabel() to rebuild
                -- both FontString anchors instead of reusing this single-name
                -- position.
                data.anchor = nil
                data.casting = nil
                return
            end
        end
    end
    data.label:SetText("")
    data.label:Hide()
    if data.lastLabel then
        data.lastLabel:SetText("")
        data.lastLabel:Hide()
    end
end

local function HideUnit(unit)
    local data = plates[unit]
    if data then
        data.label:SetText("")
        data.label:Hide()
        data.label:SetParent(UIParent)
        if data.lastLabel then
            data.lastLabel:SetText("")
            data.lastLabel:Hide()
            data.lastLabel:SetParent(UIParent)
        end
        if data.roleIcon then
            data.roleIcon:Hide()
            data.roleIcon:SetParent(UIParent)
        end
        plates[unit] = nil
    end
end

function addon:RefreshTargetNames()
    elapsed = 0
    if not self:GetTargetNamesEnabled() then
        updater:Hide()
        for _, data in pairs(plates) do
            data.label:Hide()
            if data.lastLabel then data.lastLabel:Hide() end
        end
        return
    end
    updater:Show()
    -- Rebuild visible units when enabled, including plates added while off.
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if self:GetPlate(unit) then UpdateUnit(unit) end
    end
end

updater:Hide()
updater:RegisterEvent("NAME_PLATE_UNIT_ADDED")
updater:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
updater:RegisterEvent("PLAYER_ENTERING_WORLD")

updater:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        UpdateUnit(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        HideUnit(unit)
    else
        for u in pairs(plates) do HideUnit(u) end
        addon:RefreshTargetNames()
    end
end)

updater:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    for unit in pairs(plates) do UpdateUnit(unit) end
end)
