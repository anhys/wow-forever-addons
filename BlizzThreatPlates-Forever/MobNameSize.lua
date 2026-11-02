local addon = ForeverNameplates
local IsNamePlateUnitFrame
local originalFonts = setmetatable({}, {__mode="k"})
local alignedNativeBars = setmetatable({}, {__mode="k"})
local nativeNames = setmetatable({}, {__mode="k"})

local function RestoreNameAlignment(name, frame, thin)
    name:SetJustifyH(thin and "CENTER" or "LEFT")
    if thin then
        name:ClearAllPoints(); name:SetWidth(0)
        name:SetPoint("BOTTOM",frame.HealthBarsContainer or frame.healthBar,"TOP",0,
            NamePlateSetupOptions and NamePlateSetupOptions.healthBarToNameAboveSpacing or 2)
    end
end

local function RestoreHealthLayout(frame)
    local hb = frame.healthBar
    local setup = NamePlateSetupOptions or {}
    local styles = NamePlateConstants and NamePlateConstants.NAME_ANCHOR_STYLES or {}
    local thin = setup.unitNameAnchorStyle == styles.CenteredAboveHealthBar and styles.CenteredAboveHealthBar ~= nil
    -- Match the native layout's existing text roles, including its intentionally
    -- swapped LeftText/RightText fields. No real region's anchors are read.
    local percent, value, single = hb.LeftText, hb.RightText, hb.TextString or hb.Text
    for _, label in ipairs({percent,value,single}) do
        label:ClearAllPoints(); label:SetWidth(0); label:SetJustifyH("RIGHT")
    end
    if percent then percent:SetPoint("RIGHT",hb,"RIGHT",-4,thin and setup.useClassicHealthBar and -0.5 or 0) end
    if value then value:SetPoint("RIGHT",percent or hb,percent and "LEFT" or "RIGHT",percent and -2 or -4,0) end
    if single then single:SetPoint("RIGHT",value or hb,value and "LEFT" or "RIGHT",value and 2 or -5,0) end
    if frame.name and setup.unitNameAnchorStyle == styles.InsideHealthBar and styles.InsideHealthBar ~= nil then
        frame.name:ClearAllPoints(); frame.name:SetWidth(0); frame.name:SetJustifyH("LEFT")
        frame.name:SetPoint("LEFT",frame.HealthBarsContainer or hb,"LEFT",4,0)
        frame.name:SetPoint("RIGHT",single or hb,single and "LEFT" or "RIGHT",-2,0)
    end
    hb.btpHealthAlignment = nil
    alignedNativeBars[hb] = nil
end

local function Resize(fs, size, outlineIfMissing)
    if not fs or not fs.GetFont or not fs.SetFont then return end
    local font, originalSize, flags = fs:GetFont()
    if font then
        local saved = originalFonts[fs]
        if not saved or font~=saved.lastFont or originalSize~=saved.lastSize or flags~=saved.lastFlags then
            saved = {font=font,size=originalSize,flags=flags}
            originalFonts[fs] = saved
        end
        -- Default/Thin supplies "SLUG" while Large supplies
        -- "OUTLINE, SLUG". Preserve SLUG and add only the missing outline.
        if outlineIfMissing and (not flags or not flags:find("OUTLINE", 1, true)) then
            flags = flags and flags ~= "" and ("OUTLINE, "..flags) or "OUTLINE"
        end
        size = tonumber(size) or 11
        fs:SetFont(font, size, flags)
        saved.lastFont,saved.lastSize,saved.lastFlags = font,size,flags
        -- Blizzard also sets a rendered text height when applying a style.
        -- SetFont alone must not leave that separate height override behind.
        if fs.SetTextHeight then fs:SetTextHeight(size) end
    end
end

function addon:RestoreNativeTextSizes()
    for _, frame in pairs(alignedNativeBars) do
        if not frame:IsForbidden() then RestoreHealthLayout(frame) end
    end
    for name, state in pairs(nativeNames) do
        if not state.frame:IsForbidden() then
            if state.alpha ~= nil then name:SetAlpha(state.alpha) end
            if state.aligned then RestoreNameAlignment(name,state.frame,state.thin) end
        end
        nativeNames[name] = nil
    end
    for fs, saved in pairs(originalFonts) do
        local ok,font,size,flags = pcall(fs.GetFont,fs)
        local secret = issecretvalue and (issecretvalue(font) or issecretvalue(size) or issecretvalue(flags))
        -- A different font means another owner has already taken over. Only
        -- undo our own last write; never measure or recover native anchors.
        if ok and not secret and font==saved.lastFont and size==saved.lastSize and flags==saved.lastFlags then
            fs:SetFont(saved.font,saved.size,saved.flags)
            if fs.SetTextHeight then fs:SetTextHeight(saved.size) end
        end
        originalFonts[fs] = nil
    end
end

local function ApplyHealthText(frame, changedKind)
    if addon:GetCompatibilityMode() then return end
    if not IsNamePlateUnitFrame(frame) then return end
    local hb = frame.healthBar
    if not hb then return end

    local thinStyle = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
    local isThinStyle = thinStyle ~= nil and addon:GetNameplateStyleFamily() == thinStyle
    local percentSize, valueSize = addon:GetHealthPercentFontSize(), addon:GetHealthValueFontSize()
    local percentOn, valueOn = addon:GetNameplateHealthInfoFlags(true)
    -- TextStatusBar uses LeftText for percentage and RightText for numeric
    -- health in BOTH mode. Nameplates swap their visual order, not these roles.
    -- Single-field modes reuse TextString for whichever option is enabled.
    local singleText = hb.TextString or hb.Text
    if not changedKind or changedKind == "percent" then
        Resize(hb.LeftText, percentSize, isThinStyle)
    end
    if not changedKind or changedKind == "value" then
        Resize(hb.RightText, valueSize, isThinStyle)
    end
    -- In BOTH mode the shared field is hidden. Only size it when it actually
    -- represents one health option, and only for that option's slider.
    local singleKind = percentOn and not valueOn and "percent"
        or valueOn and not percentOn and "value"
    if singleKind and (not changedKind or changedKind == singleKind) then
        Resize(singleText, singleKind == "value" and valueSize or percentSize, isThinStyle)
    end

    -- Keep Default/Thin's single health field inside the bar, as in our preview.
    if singleText and isThinStyle then
        singleText:ClearAllPoints()
        singleText:SetPoint("RIGHT", hb, "RIGHT", -5, 0)
        singleText:SetJustifyH("RIGHT")
    end
    if addon.ApplyNameplateTextAlignment and not addon:IsATDStyle() then
        local custom = addon:GetNameplateTextAlignment("percent") ~= "DEFAULT"
            or addon:GetNameplateTextAlignment("value") ~= "DEFAULT"
        if not custom and hb.btpHealthAlignment then
            RestoreHealthLayout(frame)
        elseif custom then
            local aligned = addon:ApplyNameplateTextAlignment(hb,
                percentOn and (valueOn and hb.LeftText or singleText),
                valueOn and (percentOn and hb.RightText or singleText),percentOn,valueOn,
                not isThinStyle and frame.name or nil)
            hb.btpHealthAlignment = aligned or nil
            if aligned then alignedNativeBars[hb] = frame end
        end
    end
    if addon.ApplyATDStyle then addon:ApplyATDStyle(frame) end
end

IsNamePlateUnitFrame = function(frame)
    if not frame or frame:IsForbidden() then return false end

    -- CompactUnitFrame_UpdateName is shared by nameplates AND compact
    -- party/raid frames. Only touch frames that are actually owned by a
    -- Blizzard nameplate.
    local unit = frame.unit or frame.displayedUnit
    if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string"
        or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return false
    end

    -- GetNamePlateForUnit explicitly rejects partyN/raidN tokens. The shared
    -- CompactUnitFrame name updater is used by those frames too, so reject
    -- them before calling the nameplate API.
    if unit:match("^party%d+$") or unit:match("^raid%d+$") then
        return false
    end

    -- Native nameplates use nameplateN unit tokens. Restrict this hook to
    -- those tokens so compact party/raid/player frames can never inherit the
    -- enemy-name font size.
    if not unit:match("^nameplate%d+$") then
        return false
    end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    return plate and not plate:IsForbidden() and plate.UnitFrame == frame
end

local function ApplyNameAfterBlizzard(frame)
    if addon:GetCompatibilityMode() then return end
    if not IsNamePlateUnitFrame(frame) then return end
    if not frame.name then return end
    local name = frame.name
    local state = nativeNames[name] or {frame=frame}
    local enabled = not addon.GetNameplateNameEnabled or addon:GetNameplateNameEnabled()
    if not enabled then
        if state.alpha == nil then
            local ok,alpha = false,nil
            if name.GetAlpha then ok,alpha = pcall(name.GetAlpha,name) end
            state.alpha = ok and not (issecretvalue and issecretvalue(alpha)) and type(alpha)=="number" and alpha or 1
        end
        -- Native health text consults name:IsShown(). Alpha hides the name
        -- without changing the engine's name/health visibility relationship.
        name:SetAlpha(0)
    elseif state.alpha ~= nil then
        name:SetAlpha(state.alpha); state.alpha = nil
    end
    if addon.ApplyNameplateNameAlignment then
        local align = addon:GetNameplateTextAlignment("name")
        local thin = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
        local above = thin ~= nil and addon:GetNameplateStyleFamily() == thin
        if align == "DEFAULT" and state.aligned then
            RestoreNameAlignment(name,frame,above); state.aligned = nil
        elseif align ~= "DEFAULT" then
            state.thin = above
            addon:ApplyNameplateNameAlignment(name,frame.healthBar,state.thin)
            state.aligned = true
        end
    end
    nativeNames[name] = (state.alpha ~= nil or state.aligned) and state or nil

    -- CompactUnitFrame_UpdateName also runs for raid-style party frames.
    -- Scope the custom font size strictly to native Blizzard nameplates.
    if addon:GetMobNameEnabled() then Resize(frame.name, addon:GetMobNameFontSize()) end
    if addon.ApplyATDStyle then addon:ApplyATDStyle(frame) end
end

-- Keep percentage sizing on the already-proven path.
hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
    ApplyHealthText(frame)
end)

-- Key experiment: style the native name only after Blizzard has finished its
-- own name update.
hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
    ApplyNameAfterBlizzard(frame)
end)

-- Apply immediately to existing nameplates when settings sliders change.
function addon:ApplyNativeTextSizes(changedKind)
    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end
    for _, plate in ipairs(plates) do
        local frame = plate and not plate:IsForbidden() and plate.UnitFrame
        if frame and not frame:IsForbidden() then
            ApplyHealthText(frame, changedKind)
            if not changedKind then ApplyNameAfterBlizzard(frame) end
        end
    end
end

addon.ApplyMobNameFontSize = addon.ApplyNativeTextSizes

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "CVAR_UPDATE" then
        if type(unit) ~= "string" then return end
        local cvar = unit:lower()
        if cvar ~= "nameplateinfodisplay" and cvar ~= "nameplatestyle" and cvar ~= "nameplatesize" then return end
    end
    if event == "NAME_PLATE_UNIT_ADDED" and unit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        local frame = plate and not plate:IsForbidden() and plate.UnitFrame
        if frame and not frame:IsForbidden() then
            -- Blizzard has just initialized the plate; apply our presentation
            -- after the current event stack completes.
            C_Timer.After(0, function()
                if frame and not frame:IsForbidden() then
                    ApplyHealthText(frame)
                    ApplyNameAfterBlizzard(frame)
                end
            end)
        end
    else
        -- Native display/style changes can swap text fields without a health
        -- event. Refresh after that event stack without hooking or replacing
        -- the health bar's UpdateTextString method used during ClearUnit.
        C_Timer.After(0, function()
            addon:ApplyNativeTextSizes()
        end)
    end
end)
