local addon = ForeverNameplates
local pages={}
function addon:RefreshEnemyDebuffPreviewControls()
    for _,page in pairs(pages) do if page.view:IsShown() then page:Refresh() end end
end

function addon:CreateEnemyDebuffOptions(ui, context)
    local pvp = context == "pvp"
    local view = ui.CreateView(context, "Enemy Debuffs", "")
    local page = {view=view}
    local caption = ui.Font(view,"GameFontDisableSmall","Preview",44,-119,240)
    local preview = ui.PreviewCard(view,116,-134)
    local viewport = CreateFrame("Frame",nil,preview)
    viewport:SetPoint("TOPLEFT",8,-6)
    viewport:SetPoint("BOTTOMRIGHT",-8,6)
    local plate = ui.CreateNameplateSample(preview,viewport,caption)
    addon:CreateDebuffPreview(preview,viewport,caption,plate,context,ui.GetNumber)
    page.preview = preview

    local native = CreateFrame("Frame",nil,view)
    native:SetAllPoints(view)
    local info = CreateFrame("Frame",nil,native,"BackdropTemplate")
    info:SetSize(480,32)
    info:SetPoint("TOPLEFT",44,-270)
    ui.Backdrop(info)
    ui.Font(info,"GameFontHighlightSmall",pvp and "Enemy Player Buffs/Debuffs" or "Enemy NPC Buffs/Debuffs",12,-10,224)
    local button = ui.Button(info,"",226,24)
    ui.HighlightSelectorButton(button)
    button:SetPoint("RIGHT",-8,0)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT",10,0)
    button.label:SetPoint("RIGHT",-25,0)
    button.label:SetJustifyH("LEFT")
    button.label:SetWordWrap(false)
    ui.Font(button,"GameFontNormal","v",210,-6)
    local cvar = pvp and "nameplateEnemyPlayerAuraDisplay" or "nameplateEnemyNpcAuraDisplay"
    local enumName = pvp and "NamePlateEnemyPlayerAuraDisplay" or "NamePlateEnemyNpcAuraDisplay"
    local choices = {
        {key="Buffs",index=1,text=pvp and (UNIT_NAMEPLATES_ENEMY_PLAYER_AURA_DISPLAY_BUFFS or "Enemy Buffs")
            or (UNIT_NAMEPLATES_ENEMY_NPC_AURA_DISPLAY_BUFFS or "Mob Buffs")},
        {key="Debuffs",index=2,text=pvp and (UNIT_NAMEPLATES_ENEMY_PLAYER_AURA_DISPLAY_DEBUFFS or "Personal Debuffs")
            or (UNIT_NAMEPLATES_ENEMY_NPC_AURA_DISPLAY_DEBUFFS or "Personal Debuffs")},
        {key=pvp and "LossOfControl" or "CrowdControl",index=3,text=pvp
            and (UNIT_NAMEPLATES_ENEMY_PLAYER_AURA_DISPLAY_BIG_DEBUFF or "Big Debuff")
            or (UNIT_NAMEPLATES_ENEMY_NPC_AURA_DISPLAY_CROWD_CONTROL or "Shared CC")},
    }
    button:SetScript("OnClick",function(self)
        UIDropDownMenu_Initialize(ui.menuFrame,function(_,level)
            if level ~= 1 then return end
            for _,choice in ipairs(choices) do
                local item = choice
                local index = ui.EnumIndex(enumName,item.key,item.index)
                local entry = UIDropDownMenu_CreateInfo()
                entry.text,entry.isNotRadio,entry.keepShownOnClick=item.text,true,true
                entry.checked=function() return addon:IsNameplateBitfieldEnabled(cvar,index) end
                entry.func=function()
                    addon:SetNameplateBitfieldIndex(cvar,index,not addon:IsNameplateBitfieldEnabled(cvar,index))
                    ui.Refresh()
                end
                UIDropDownMenu_AddButton(entry,level)
            end
        end,"MENU")
        ToggleDropDownMenu(1,nil,ui.menuFrame,self,0,0)
    end)
    local nativePanel = CreateFrame("Frame",nil,native,"BackdropTemplate")
    nativePanel:SetSize(480,82)
    nativePanel:SetPoint("TOPLEFT",44,-316)
    ui.Backdrop(nativePanel)
    local nativeSliders = {
        ui.SliderRow(nativePanel,"Buff/Debuff Scale",16,-14,198,70,140,10,
            function() return math.floor(ui.GetNumber("nameplateAuraScale",1)*100+0.5) end,
            function(v) ui.SetNumber("nameplateAuraScale",v/100) end,"%"),
        ui.SliderRow(nativePanel,"Debuff Padding",266,-14,198,0,50,1,
            function() return ui.GetNumber("nameplateDebuffPadding",6) end,
            function(v) ui.SetNumber("nameplateDebuffPadding",v) end,""),
    }
    local workaroundPanel = CreateFrame("Frame",nil,view)
    workaroundPanel:SetSize(480,24)
    workaroundPanel:SetPoint("TOPLEFT",44,-70)
    local workaround = ui.Toggle(workaroundPanel,"CC Display Workaround (Experimental)",0,0,
        function() return addon:GetNativeCCWorkaround() end,
        function(value) addon:SetNativeCCWorkaround(value); ui.Refresh() end,430)
    workaround.label:SetWidth(0)
    workaround.label:SetWordWrap(false)
    addon:CreateOptionsNewFeatureTag(workaroundPanel,workaround.label,"LEFT","RIGHT",6,0)
    local note = ui.Font(native,"GameFontDisableSmall","",44,-410,480)

    local atd = CreateFrame("Frame",nil,view)
    atd:SetAllPoints(view)
    local visibility = CreateFrame("Frame",nil,atd,"BackdropTemplate")
    visibility:SetSize(480,76)
    visibility:SetPoint("TOPLEFT",44,-270)
    ui.Backdrop(visibility)
    local toggles = {}
    local function Settings()
        return addon:IsATDStyle() and addon:GetATDAuraSettings(context) or addon:GetNativeAuraSettings(context)
    end
    local function SetSetting(key,value)
        if addon:IsATDStyle() then addon:SetATDAuraSetting(context,key,value)
        else addon:SetNativeAuraSetting(context,key,value) end
    end
    local function Toggle(text,x,y,key,width)
        local control = ui.Toggle(visibility,text,x,y,
            function()
                if not pvp and key=="ownCrowdControl" then return Settings()[key]==true end
                return Settings()[key] ~= false
            end,
            function(v) SetSetting(key,v) end,width)
        toggles[#toggles+1] = control
    end
    Toggle("Enable Debuffs",16,-15,"enabled",130)
    Toggle("My Debuffs",174,-15,"ownDebuffs",120)
    if pvp then
        Toggle("Crowd Control",332,-15,"otherCrowdControl",130)
        Toggle("My CC on Left",16,-45,"ownCrowdControl",220)
    else
        Toggle("Crowd Control",332,-15,"crowdControl",130)
        Toggle("My CC on Left",16,-45,"ownCrowdControl",220)
        local myCC=toggles[#toggles]
        myCC.label:SetWidth(0)
        myCC.label:SetWordWrap(false)
        addon:CreateOptionsNewFeatureTag(myCC,myCC.label,"LEFT","RIGHT",6,0)
    end
    local layout = CreateFrame("Frame",nil,atd,"BackdropTemplate")
    layout:SetSize(480,136)
    layout:SetPoint("TOPLEFT",44,-360)
    ui.Backdrop(layout)
    local sliders = {}
    local function Slider(text,x,y,key,low,high,suffix)
        sliders[#sliders+1] = ui.SliderRow(layout,text,x,y,132,low,high,1,
            function() return Settings()[key] end,
            function(v) SetSetting(key,v) end,suffix)
    end
    Slider("Debuff Size",16,-14,"iconSize",16,36," px")
    Slider("CC Size",174,-14,"crowdControlSize",20,44," px")
    Slider("Spacing",332,-14,"spacing",0,10," px")
    Slider("Max Debuffs",16,-76,"maxDebuffs",0,12,"")
    Slider(pvp and "Max My CC" or "Max CC",174,-76,pvp and "maxOwnCrowdControl" or "maxCrowdControl",0,6,"")
    if pvp then Slider("Max Other CC",332,-76,"maxOtherCrowdControl",0,6,"")
    else Slider("Max My CC",332,-76,"maxOwnCrowdControl",0,6,"") end
    local reset = ui.Button(view,"Reset",66,26)
    reset:SetPoint("TOPRIGHT",-18,-17)
    reset:SetScript("OnClick",function()
        if addon:IsATDStyle() then addon:ResetATDAuraSettings(context)
        else addon:ResetNativeAuraSettings(context) end
        ui.Refresh()
    end)
    local target
    do
        target = ui.Button(visibility,"Preview on Target",136,22)
        target:SetPoint("TOPRIGHT",-12,-42)
        target:SetScript("OnClick",function()
            addon:SetATDAuraPreview(not addon:IsATDAuraPreviewActive()); ui.Refresh()
        end)
    end
    for _,list in ipairs({nativeSliders,sliders}) do
        for _,control in ipairs(list) do control.OnUserValueChanged=function() preview:Refresh() end end
    end
    page.Refresh=function()
        local useATD = addon:IsATDStyle()
        local custom = useATD or addon:GetNativeCCWorkaround()
        local editable = custom and not InCombatLockdown()
        workaround:Refresh()
        workaroundPanel:SetShown(not useATD)
        ui.SetControlEnabled(workaround,not InCombatLockdown())
        native:SetShown(not custom)
        atd:SetShown(custom)
        reset:SetShown(custom)
        ui.SetControlEnabled(reset,editable)
        local selected = {}
        for _,choice in ipairs(choices) do
            if addon:IsNameplateBitfieldEnabled(cvar,ui.EnumIndex(enumName,choice.key,choice.index)) then
                selected[#selected+1] = choice.text
            end
        end
        button.label:SetText(#selected == 0 and (NONE or "None")
            or (#selected == 1 and selected[1] or string.format("%d Selected",#selected)))
        note:SetText((addon:HasPendingNameplateBitfield(cvar)
            or ui.HasPendingNumber("nameplateAuraScale") or ui.HasPendingNumber("nameplateDebuffPadding"))
            and "Changes apply when combat ends." or "")
        for _,control in ipairs(toggles) do control:Refresh(); ui.SetControlEnabled(control,editable) end
        for _,control in ipairs(sliders) do control:Refresh(); control:SetEnabled(editable) end
        for _,control in ipairs(nativeSliders) do control:Refresh() end
        if target then
            target:SetShown(custom)
            target:SetEnabled(editable)
            target.label:SetText(addon:IsATDAuraPreviewActive() and "Stop Preview" or "Preview on Target")
        end
        preview:Refresh()
    end
    pages[context]=page
    return page
end
