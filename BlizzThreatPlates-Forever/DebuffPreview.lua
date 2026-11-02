local addon = ForeverNameplates
local icons = {
    "Interface\\Icons\\Ability_WarStomp",
    "Interface\\Icons\\Ability_Warrior_WarCry",
    "Interface\\Icons\\Spell_Nature_ThunderClap",
}

function addon:CreateDebuffPreview(preview, viewport, caption, plate, context, getNumber)
    -- Sample artwork only: no unit auras, native aura templates, or script plates.
    local pool = {}
    local data = {plate=plate, icons=pool}
    preview.btpDebuffPreview = data
    preview.Refresh = function()
        plate.followHealthInfo = true
        plate:Refresh()
        local atd, pvp = addon:IsATDStyle(), context == "pvp"
        local workaround = not atd and addon.GetNativeCCWorkaround and addon:GetNativeCCWorkaround()
        local geometry, bounds = plate.geometry, plate.bounds
        local left, right, top, bottom = bounds.left, bounds.right, bounds.top, bounds.bottom
        local used = 0
        local function Icon(x, y, size, texture)
            used = used + 1
            local item = pool[used]
            if not item then
                item = CreateFrame("Frame", nil, plate.content)
                item.icon = item:CreateTexture(nil, "ARTWORK")
                item.icon:SetAllPoints()
                item.border = item:CreateTexture(nil, "OVERLAY")
                pool[used] = item
            end
            item:ClearAllPoints()
            item:SetPoint("BOTTOMLEFT", plate.bar, "CENTER", x, y)
            item:SetSize(size, size)
            item.icon:SetTexture(texture)
            item.border:ClearAllPoints()
            item.border:SetShown(not atd and not workaround)
            if not atd and not workaround then
                item.border:SetAtlas("UI-HUD-CoolDownManager-IconOverlay", false)
                item.border:SetPoint("TOPLEFT", -6, 5)
                item.border:SetPoint("BOTTOMRIGHT", 6, -5)
            end
            item:Show()
            local pad = (atd or workaround) and 1 or 6
            left, right = math.min(left, x-pad), math.max(right, x+size+pad)
            top, bottom = math.max(top, y+size+pad), math.max(bottom, -y+pad)
        end
        if atd or workaround then
            local settings = atd and addon:GetATDAuraSettings(context) or addon:GetNativeAuraSettings(context)
            if settings.enabled ~= false then
                local spacing, gap = settings.spacing or 2, 6
                local ccSize, iconSize = settings.crowdControlSize or 30, settings.iconSize or 24
                local cc = pvp and (settings.otherCrowdControl ~= false and settings.maxOtherCrowdControl or 0)
                    or (not pvp and settings.crowdControl ~= false and settings.maxCrowdControl or 0)
                if workaround and pvp then cc=0 end
                local debuffs = settings.ownDebuffs ~= false and settings.maxDebuffs or 0
                local lineWidth = addon:GetNameplatePreviewGeometry(not workaround).width
                local y = geometry.height/2+gap
                if workaround and addon:GetNameplateStyleFamily() == (Enum.NamePlateStyle and Enum.NamePlateStyle.Thin) then
                    y=y+addon:GetMobNameFontSize()+4
                end
                local x, rowHeight = 0, 0
                for _, group in ipairs({{count=cc or 0,size=ccSize,cc=true}, {count=debuffs or 0,size=iconSize}}) do
                    for index=1,group.count do
                        if x > 0 and x+group.size > lineWidth then
                            x, y, rowHeight = 0, y+rowHeight+spacing, 0
                        end
                        Icon(-geometry.width/2+x, y, group.size, icons[group.cc and 1 or 2+(index-1)%2])
                        x, rowHeight = x+group.size+spacing, math.max(rowHeight,group.size)
                    end
                end
                local ownSide=pvp and settings.ownCrowdControl~=false or not pvp and settings.ownCrowdControl==true
                local sideCount = ownSide and settings.maxOwnCrowdControl or 0
                if workaround then
                    sideCount = pvp and ((settings.ownCrowdControl ~= false and settings.maxOwnCrowdControl or 0)
                        +(settings.otherCrowdControl ~= false and settings.maxOtherCrowdControl or 0))
                        or (ownSide and settings.maxOwnCrowdControl or 0)
                end
                for index=1,sideCount or 0 do
                    Icon(-geometry.width/2-gap-index*ccSize-(index-1)*spacing, -ccSize/2, ccSize, icons[1])
                end
            end
        else
            local constants, setup = NamePlateConstants or {}, NamePlateSetupOptions or {}
            local enum = Enum and Enum[pvp and "NamePlateEnemyPlayerAuraDisplay" or "NamePlateEnemyNpcAuraDisplay"] or {}
            local cvar = pvp and "nameplateEnemyPlayerAuraDisplay" or "nameplateEnemyNpcAuraDisplay"
            local scales = setup.useClassicHealthBar and constants.NAME_PLATE_SCALES_CLASSIC_STYLE or constants.NAME_PLATE_SCALES
            local sizeScale = scales and scales[addon:GetNameplateSize()]
            local scale = getNumber("nameplateAuraScale",1) * (sizeScale and sizeScale.aura or 1)
            local size = (constants.AURA_ITEM_HEIGHT or 25)*scale
            if addon:IsNameplateBitfieldEnabled(cvar,enum.Debuffs or 2) then
                local thin = addon:GetNameplateStyleFamily() == (Enum.NamePlateStyle and Enum.NamePlateStyle.Thin)
                local y = thin and bounds.top or geometry.height/2
                y = y+getNumber("nameplateDebuffPadding",6)
                for index=1,3 do Icon(-geometry.width/2+(index-1)*size,y,size,icons[2+(index-1)%2]) end
            end
            if addon:IsNameplateBitfieldEnabled(cvar,enum.Buffs or 1) then
                Icon(-geometry.width/2-5-size,-size/2,size,"Interface\\Icons\\Spell_Nature_BloodLust")
            end
            if addon:IsNameplateBitfieldEnabled(cvar,enum[pvp and "LossOfControl" or "CrowdControl"] or 3) then
                local ccSize = pvp and 30*scale or size
                local badgeWidth = geometry.level and geometry.level.width+geometry.level.x or 0
                Icon(geometry.width/2+badgeWidth+5,-ccSize/2,ccSize,icons[1])
            end
        end
        for index=used+1,#pool do pool[index]:Hide() end
        data.count, data.bounds = used, {left=left,right=right,top=top,bottom=bottom}
        local scale, fraction = addon:FitNameplatePreviewScale(addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale()),
            right-left+4,top+bottom+4,viewport:GetWidth(),viewport:GetHeight())
        plate.content:SetScale(scale)
        plate.bar:ClearAllPoints()
        plate.bar:SetPoint("CENTER",plate.content,"CENTER",-(left+right)/2,(bottom-top)/2)
        caption:SetText(fraction < 0.995 and string.format("Preview (%d%% scale)",math.floor(fraction*100+0.5)) or "Preview")
    end
    return preview
end
