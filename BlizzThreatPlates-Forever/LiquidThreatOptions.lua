local addon=ForeverNameplates

function addon:CreateLiquidThreatOptions(view,ui)
    local function Text(text,x,y,width,size)
        local label=ui.Font(view,"GameFontHighlightSmall",text,x,y,width)
        addon:StyleOptionsFont(label,size or 11)
        label.btpOptionsFontSizeOffset=(size or 11)-12
        label:SetWordWrap(true)
        return label
    end
    local back=ui.Button(view,"Back to Style",110,24)
    back:SetPoint("TOPRIGHT",-24,-14)
    back:SetScript("OnClick",function() addon:ShowModernNameplateView("style") end)

    local function Sample(x,y,width,height)
        local bar=CreateFrame("StatusBar",nil,view,"BackdropTemplate")
        bar:SetPoint("TOPLEFT",x,y); bar:SetSize(width,height)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0,100); bar:SetValue(100)
        ui.Backdrop(bar,{0.015,0.02,0.025,1},{0.92,0.92,0.92,1})
        return {bar=bar}
    end
    Text("Preview",44,-78,480)
    local sample=Sample(44,-100,480,36)
    local name=sample.bar:CreateFontString(nil,"OVERLAY")
    name.btpDevExclude=true
    addon:SetFontWithFallback(name,addon:GetJundiesFontPath(),16,"OUTLINE")
    name:SetPoint("LEFT",10,0); name:SetText("Young Wolf"); name:SetTextColor(1,1,1)
    local health=sample.bar:CreateFontString(nil,"OVERLAY")
    health.btpDevExclude=true
    addon:SetFontWithFallback(health,addon:GetJundiesFontPath(),16,"OUTLINE")
    health:SetPoint("RIGHT",-10,0); health:SetText("100%"); health:SetTextColor(1,1,1)

    local warning=Text("",44,-190,480,12)
    warning.btpDevExclude=true
    warning:SetTextColor(1,0.15,0.15)
    warning:Hide()
    local warningTime=0
    local enabled=ui.Toggle(view,"Enable Liquid Threat",44,-159,
        function() return addon:IsLiquidThreatEnabled() end,
        function(value)
            if not addon:SetLiquidThreatEnabled(value) then
                warningTime=6
                warning:SetText("Currently only works with Style: ATD -- or Jundies")
                warning:SetAlpha(1); warning:Show()
            end
        end,180)
    local style=ui.Selector(view,"Nameplate Style",-153,function()
        local choices={}
        for _,entry in ipairs(addon:GetNameplateStyles()) do
            if entry.key=="Modern" or entry.key=="Thin" or entry.key=="ATD" or entry.key=="JUNDIES" then
                choices[#choices+1]={value=entry.id,text=entry.name,
                    disabled=entry.key=="Modern" or entry.key=="Thin"}
            end
        end
        return choices
    end,function() return addon:GetNameplateStyleFamily() end,function(value)
        addon:SetNameplateStyle(value)
        warningTime=0; warning:Hide(); warning:SetAlpha(1)
    end,true,276)
    style.useModernMenu=true
    style:ClearAllPoints(); style:SetPoint("TOPLEFT",248,-153)
    local playing,time,phase,progress,cycling=false,0,0,0,true
    local loss
    local play=ui.Button(view,"Play Animation",144,26)
    play:SetPoint("TOPLEFT",44,-234)
    play:SetScript("OnClick",function()
        playing=not playing
        play.label:SetText(playing and "Pause Animation" or "Play Animation")
    end)
    local speed=ui.SliderRow(view,"Liquid Speed",326,-224,198,0.25,3,0.25,
        function() return addon:GetLiquidThreatSpeed() end,
        function(value) addon:SetLiquidThreatSpeed(value) end,"x")
    local reset=ui.Button(view,"Reset",96,26)
    reset:SetPoint("TOPLEFT",204,-234)
    reset:SetScript("OnClick",function()
        addon:ResetLiquidThreat()
        playing,time,phase,progress,cycling=false,0,0,0,true
        warningTime=0; warning:Hide(); warning:SetAlpha(1)
        play.label:SetText("Play Animation")
        enabled:Refresh(); speed:Refresh(); loss:Refresh()
        addon:PaintLiquidThreatPreview(sample,0,0)
    end)
    loss=ui.SliderRow(view,"Threat Loss",44,-280,480,0,100,1,
        function() return progress*100 end,function(value)
            progress=math.max(0,math.min(1,value/100))
            phase=math.acos(1-2*progress)
            cycling=false
            addon:PaintLiquidThreatPreview(sample,progress,time)
        end,"%")

    Text("Threat progression",44,-346,480,12)
    local examples={
        {progress=0.30,title="Green to yellow",note="More yellow: losing threat"},
        {progress=0.36,title="Yellow",note="WARNING"},
        {progress=0.91,title="Yellow to red",note="91% threat loss"},
    }
    for index,example in ipairs(examples) do
        local x=44+(index-1)*168
        example.decor=Sample(x,-374,144,22)
        Text(example.title,x,-407,152,11)
        Text(example.note,x,-426,152,10):SetTextColor(0.65,0.68,0.72)
    end
    Text("Play Animation previews the full progression. Enabling Liquid Threat applies it to live nameplates.",44,-467,480,10)
    local elapsed=0
    view:SetScript("OnUpdate",function(_,delta)
        if warningTime>0 then
            warningTime=math.max(0,warningTime-delta)
            warning:SetAlpha(math.floor(warningTime*4)%2==0 and 1 or 0.25)
            if warningTime==0 then warning:Hide(); warning:SetAlpha(1) end
        end
        if not playing then return end
        elapsed=elapsed+delta
        if elapsed<0.05 then return end
        local dt=math.min(elapsed,0.15); elapsed=0
        time=time+dt*addon:GetLiquidThreatSpeed()
        if cycling then
            phase=(phase+dt*0.30*addon:GetLiquidThreatSpeed())%(math.pi*2)
            progress=(1-math.cos(phase))*0.5
            loss:Refresh()
        end
        addon:PaintLiquidThreatPreview(sample,progress,time)
    end)
    view:HookScript("OnHide",function()
        playing=false; play.label:SetText("Play Animation")
        warningTime=0; warning:Hide(); warning:SetAlpha(1)
        elapsed=0
    end)
    local controls={}
    function controls:Refresh()
        enabled:Refresh(); speed:Refresh(); loss:Refresh(); style:Refresh()
        style:SetEnabled(not InCombatLockdown() and not addon:GetCompatibilityMode())
        if addon:IsLiquidThreatStyleSupported() then
            if warningTime==0 then warning:Hide() end
        elseif warningTime==0 then
            warning:SetText("Choose ATD Inspired or Jundies Inspired above to enable Liquid Threat.")
            warning:SetAlpha(1); warning:Show()
        end
    end
    view:HookScript("OnShow",function()
        controls:Refresh()
        addon:PaintLiquidThreatPreview(sample,progress,time)
        for _,example in ipairs(examples) do addon:PaintLiquidThreatPreview(example.decor,example.progress,2.3) end
    end)
    return controls
end
