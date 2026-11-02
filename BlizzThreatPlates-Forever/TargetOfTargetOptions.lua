local addon = ForeverNameplates

function addon:CreateTargetOfTargetOptions(view, ui)
    local controls = {}
    local caption = ui.Font(view,"GameFontDisableSmall","Preview",44,-77,240)
    local preview = ui.PreviewCard(view,92,-92)
    local viewport = CreateFrame("Frame",nil,preview)
    viewport:SetPoint("TOPLEFT",8,-6)
    viewport:SetPoint("BOTTOMRIGHT",-8,6)
    local plate = ui.CreateNameplateSample(preview,viewport,caption)
    local front = CreateFrame("Frame",nil,plate.content)
    front:EnableMouse(false)
    local name = front:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    name:SetJustifyH("RIGHT")
    name:SetWordWrap(false)
    name:SetTextColor(0.78,0.61,0.43)
    name:SetShadowColor(0,0,0,1)
    name:SetShadowOffset(1,-1)
    preview.btpTargetPreview = {plate=plate,name=name}
    preview.Refresh = function()
        -- The sample contains only fixed text and public settings. No live
        -- target, nameplate, or protected frame is queried or measured.
        plate:Refresh()
        front:SetFrameLevel(plate.bar:GetFrameLevel()+5)
        addon:ApplyTargetNameFont(name,addon:GetTargetNameFontSize())
        name:SetTextColor(0.78,0.61,0.43)
        name:SetShadowColor(0,0,0,1)
        name:SetShadowOffset(1,-1)
        name:SetText(addon:GetFullTargetNames() and "Preview Name" or "Preview")
        local enabled = addon:GetTargetNamesEnabled()
        name:SetShown(enabled)
        local atd = addon:IsATDStyle()
        local styles = Enum and Enum.NamePlateStyle or {}
        local family = addon:GetNameplateStyleFamily()
        local offset = not atd and not addon:GetCompatibilityMode()
            and (family==(styles.Modern or 0) or family==(styles.Thin or 1)) and 28 or 0
        local x,y = addon:GetOverlayPosition("target")
        local right = plate.geometry.width/2+offset+x
        local top = -plate.geometry.height/2+(atd and -1.5 or -5)+y
        name:ClearAllPoints()
        name:SetPoint("TOPRIGHT",plate.bar,"BOTTOMRIGHT",offset+x,(atd and -1.5 or -5)+y)
        local b = plate.bounds
        local leftBound,rightBound,topBound,bottomBound = b.left,b.right,b.top,b.bottom
        if enabled then
            leftBound = math.min(leftBound,right-name:GetStringWidth())
            rightBound = math.max(rightBound,right)
            topBound = math.max(topBound,top)
            bottomBound = math.max(bottomBound,-top+name:GetStringHeight())
        end
        local scale,fraction = addon:FitNameplatePreviewScale(addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale()),
            rightBound-leftBound+4,topBound+bottomBound+4,viewport:GetWidth(),viewport:GetHeight())
        plate.content:SetScale(scale)
        plate.bar:ClearAllPoints()
        plate.bar:SetPoint("CENTER",plate.content,"CENTER",-(leftBound+rightBound)/2,(bottomBound-topBound)/2)
        preview.btpTargetPreview.bounds = {left=leftBound,right=rightBound,top=topBound,bottom=bottomBound}
        caption:SetText(fraction<0.995 and string.format("Preview (%d%% scale)",math.floor(fraction*100+0.5)) or "Preview")
    end
    ui.Font(view,"GameFontHighlightSmall","Name & Position",44,-208,300)
    local card = CreateFrame("Frame",nil,view,"BackdropTemplate")
    card:SetPoint("TOPLEFT",44,-240)
    card:SetSize(480,140)
    ui.Backdrop(card)
    local Refresh
    local function Slider(text,x,y,width,low,high,get,set)
        local slider = ui.SliderRow(card,text,x,y,width,low,high,1,get,set," px")
        slider.OnUserValueChanged = function() Refresh() end
        controls[#controls+1] = slider
        return slider
    end
    Slider("Name Size",16,-14,448,8,24,
        function() return addon:GetTargetNameFontSize() end,
        function(v) addon:SetTargetNameFontSize(v); addon:RefreshTargetNames() end):AddNotches({8,12,16,20,24})
    for index,axis in ipairs({"x","y"}) do
        Slider(axis=="x" and "Horizontal Position" or "Vertical Position",index==1 and 16 or 266,-82,198,-100,100,
            function() local x,y=addon:GetOverlayPosition("target"); return axis=="x" and x or y end,
            function(v)
                local x,y=addon:GetOverlayPosition("target")
                addon:SetOverlayPosition("target",axis=="x" and v or x,axis=="y" and v or y)
            end)
    end
    local visibility = CreateFrame("Frame",nil,view,"BackdropTemplate")
    visibility:SetPoint("TOPLEFT",card,"BOTTOMLEFT",0,-24)
    visibility:SetSize(480,72)
    ui.Backdrop(visibility)
    local enable = ui.Toggle(visibility,"Enable Target of Target",16,-16,
        function() return addon:GetTargetNamesEnabled() end,
        function(v) addon:SetTargetNamesEnabled(v); Refresh() end,218)
    local full = ui.Toggle(visibility,"Show Last Name",266,-16,
        function() return addon:GetFullTargetNames() end,
        function(v) addon:SetFullTargetNames(v); addon:RefreshTargetNames(); Refresh() end,180)
    local friendly = ui.Toggle(visibility,"Show on Friendly Nameplates",16,-44,
        function() return addon:GetFriendlyTargetNamesEnabled() end,
        function(v) addon:SetFriendlyTargetNamesEnabled(v); Refresh() end,420)
    local reset = ui.Button(view,"Reset",66,24)
    reset:SetPoint("TOPLEFT",458,-204)
    reset:SetScript("OnClick",function()
        local _,x,y=addon:GetTargetNameDefaults()
        addon:SetTargetNameFontSize(nil)
        addon:SetOverlayPosition("target",x,y)
        Refresh()
    end)
    Refresh = function()
        local enabled=addon:GetTargetNamesEnabled()
        for _,control in ipairs(controls) do control:Refresh(); control:SetEnabled(enabled) end
        enable:Refresh(); full:Refresh(); friendly:Refresh()
        ui.SetControlEnabled(friendly,enabled)
        ui.SetControlEnabled(full,enabled)
        ui.SetControlEnabled(reset,enabled)
        preview:Refresh()
    end
    local elapsed=0
    preview:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=0.2 then elapsed=0; preview:Refresh() end
    end)
    return {Refresh=Refresh,preview=preview}
end
