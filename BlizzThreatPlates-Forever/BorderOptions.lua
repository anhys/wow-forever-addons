local addon=ForeverNameplates

function addon:CreateBorderOptions(view,ui)
    local warning=ui.Font(view,"GameFontHighlightSmall","Experimental - still needs testing",0,0,260)
    warning.btpDevExclude=true
    warning:ClearAllPoints()
    warning:SetPoint("TOPRIGHT",-20,-36)
    warning:SetJustifyH("RIGHT")
    warning:SetTextColor(1,77/255,77/255,1)
    local controls={}
    local scope,kind,profile="target","secure","default"
    local preview,caption
    local function PreviewProfile()
        if profile~="default" then return profile end
    end
    local function Refresh()
        for _,control in ipairs(controls) do control:Refresh() end
        preview:Refresh()
    end
    local function Selector(parent,label,y,width,x,choices,get,set,up)
        local row=ui.Selector(parent,label,y,choices,get,function(value) set(value); Refresh() end,false,width)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",x,y)
        row.useModernMenu=true
        row.openUpward=up and true or false
        controls[#controls+1]=row
        return row
    end
    local function Choice(parent,text,width,x,y,isSelected,choose)
        local button=ui.Button(parent,text,width,24)
        button:SetPoint("TOPLEFT",x,y)
        local function Paint()
            local active=isSelected()
            button.label:SetTextColor(unpack(active and {0.88,0.66,0.24} or {0.92,0.90,0.84}))
            button:SetBackdropBorderColor(unpack(active and {0.88,0.66,0.24} or {0.20,0.23,0.27}))
        end
        button:SetScript("OnClick",function() choose(); Refresh() end)
        button:HookScript("OnLeave",Paint)
        controls[#controls+1]={Refresh=Paint}
        return button
    end
    for index,entry in ipairs({{"target","Selected Target"},{"nonTarget","Non-Target"}}) do
        local key=entry[1]
        Choice(view,entry[2],144,44+(index-1)*152,-66,function() return scope==key end,function() scope=key end)
    end
    caption=ui.Font(view,"GameFontDisableSmall","Preview",44,-110,480)
    preview=ui.PreviewCard(view,76,-126)
    local viewport=CreateFrame("Frame",nil,preview)
    viewport:SetPoint("TOPLEFT",8,-6)
    viewport:SetPoint("BOTTOMRIGHT",-8,6)
    local sample=ui.CreateNameplateSample(preview,viewport,caption,0.75)
    local outline=addon:CreateNameplateBorderOverlay(sample.bar,sample.selection,"nativeBar")
    local badge=addon:CreateNameplateBorderOverlay(sample.level,sample.levelSelection,"nativeLevel")
    -- ATD's base black rim sits below the fill, separate from its selection
    -- outline. Keep that same structure in this page's preview.
    local atdBlack=CreateFrame("Frame",nil,sample.content)
    atdBlack.btpDevExclude=true
    atdBlack:SetIgnoreParentScale(true)
    atdBlack:SetAllPoints(sample.bar)
    atdBlack:SetFrameLevel(math.max(0,sample.bar:GetFrameLevel()-1))
    atdBlack:EnableMouse(false)
    local shadow=atdBlack:CreateTexture(nil,"BACKGROUND",nil,-7)
    shadow:SetColorTexture(0,0,0,1)
    shadow:SetPoint("TOPLEFT",atdBlack,"TOPLEFT",-1,1)
    shadow:SetPoint("BOTTOMRIGHT",atdBlack,"BOTTOMRIGHT",1,-1)
    if shadow.SetSnapToPixelGrid then shadow:SetSnapToPixelGrid(false) end
    if shadow.SetTexelSnappingBias then shadow:SetTexelSnappingBias(0) end
    atdBlack:Hide()
    preview.btpBorderPreview={plate=sample,outline=outline,badge=badge,atdBlack=atdBlack}
    preview.Refresh=function()
        sample:Refresh()
        local atd=addon:IsATDStyle()
        local r,g,b=addon:GetResolvedNameplateBorderColor(scope,kind,PreviewProfile())
        local selected=scope=="target"
        atdBlack:SetShown(atd)
        sample.selection:SetShown(not atd and selected and not r)
        sample.levelSelection:SetShown(not atd and selected and not r)
        if atd then
            sample.bar:SetBackdropBorderColor(0,0,0,0)
        end
        outline:ClearAllPoints()
        outline:SetStyle(atd and "flat" or "nativeBar")
        outline:SetAllPoints(not atd and sample.selection or sample.bar)
        badge:ClearAllPoints()
        badge:SetStyle("nativeLevel")
        badge:SetAllPoints(sample.levelSelection)
        local painted=r and outline:Paint(r,g,b)
        if atd and selected and not r then painted=outline:Paint(1,1,1) end
        if not painted then
            outline:Hide()
            sample.selection:SetShown(not atd and selected)
        end
        if r and not atd and sample.level:IsShown() then
            local badgePainted=badge:Paint(r,g,b)
            sample.levelSelection:SetShown(selected and not badgePainted)
        else badge:Hide() end
        local mode=addon:GetNameplateBorderMode(scope)
        caption:SetText(mode=="threat" and not r and "Preview (no threat: original border)" or "Preview")
        local bounds=sample.bounds
        local scale=addon:FitNameplatePreviewScale(addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale())*0.75,
            bounds.right-bounds.left+8,bounds.top+bounds.bottom+8,viewport:GetWidth(),viewport:GetHeight())
        sample.content:SetScale(scale)
    end
    local card=CreateFrame("Frame",nil,view,"BackdropTemplate")
    card:SetPoint("TOPLEFT",44,-218)
    card:SetSize(480,146)
    ui.Backdrop(card)
    for index,entry in ipairs({{"default","Original"},{"custom","Custom Color"},{"threat","Threat Color"}}) do
        local key=entry[1]
        local choice=Choice(card,entry[2],144,16+(index-1)*152,-14,
            function() return addon:GetNameplateBorderMode(scope)==key end,
            function() addon:SetNameplateBorderMode(scope,key) end)
        if key=="threat" then
            controls[#controls+1]={Refresh=function()
                choice.label:SetText(scope=="nonTarget" and "Use Threat Colors" or "Threat Color")
            end}
        end
    end
    local originalHelp=ui.Font(card,"GameFontDisableSmall","Keeps this nameplate style's original border.",16,-66,448)
    local custom=CreateFrame("Frame",nil,card)
    custom:SetAllPoints(card)
    local button=ui.Button(custom,"Choose Color",144,24)
    button:SetPoint("TOPLEFT",16,-62)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT",34,0)
    local fill=button:CreateTexture(nil,"ARTWORK")
    fill.btpDevExclude=true
    fill:SetPoint("LEFT",6,0); fill:SetSize(20,16)
    ui.Font(custom,"GameFontDisableSmall","A fixed border color, independent of threat.",180,-66,280)
    button:SetScript("OnClick",function()
        if addon:GetNameplateBorderMode(scope)~="custom" then return end
        -- Keep picker writes/cancel attached to the scope it opened for, even
        -- when the user switches tabs while the picker is still open.
        local key=scope
        local saved=ForeverNameplatesDB and ForeverNameplatesDB.borderOptions
        local original=saved and saved[key] and saved[key].color
        original=original and {unpack(original)} or nil
        ui.OpenColorPicker({addon:GetNameplateBorderColor(key)},function(color)
            addon:SetNameplateBorderColor(key,color); Refresh()
        end,function() addon:SetNameplateBorderColor(key,original); Refresh() end)
    end)
    local threat=CreateFrame("Frame",nil,card)
    threat:SetPoint("TOPLEFT",16,-56)
    threat:SetSize(448,78)
    ui.Font(threat,"GameFontDisableSmall","Preview Threat",0,0,208)
    ui.Font(threat,"GameFontDisableSmall","Preview Palette",224,0,208)
    Selector(threat,"Preview Threat",-18,208,0,function() return {
        {text="No Threat",value="none"},{text="Have Aggro",value="secure"},
        {text="Warning",value="warning"},{text="Lost Aggro",value="lost"},
    } end,function() return kind end,function(value) kind=value end,true)
    Selector(threat,"Preview Palette",-18,224,224,function() return {
        {text="Default Threat Colors",value="default"},
        {text="Dungeon Threat Colors",value="tank"},{text="DPS/Heal Colors",value="nonTank"},
    } end,function() return profile end,function(value) profile=value end,true)
    ui.Font(threat,"GameFontDisableSmall","Uses your Threat Colors palettes. Preview choices do not change settings.",0,-54,448)
    controls[#controls+1]={Refresh=function()
        local current=addon:GetNameplateBorderMode(scope)
        originalHelp:SetShown(current=="default")
        custom:SetShown(current=="custom")
        threat:SetShown(current=="threat")
        local r,g,b=addon:GetNameplateBorderColor(scope)
        fill:SetColorTexture(r,g,b,1)
    end}
    local reset=ui.Button(view,"Reset Both Borders",168,26)
    reset:SetPoint("TOPLEFT",44,-382)
    reset:SetScript("OnClick",function() addon:RestoreOriginalNameplateBorders(); Refresh() end)
    ui.Font(view,"GameFontDisableSmall","Enemy nameplates only. Selected Target and Non-Target save independently.",44,-426,480)
    local elapsed=0
    view:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=0.25 then elapsed=0; preview:Refresh() end
    end)
    return {Refresh=Refresh}
end
