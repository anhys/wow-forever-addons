local addon=ForeverNameplates

function addon:CreateQuestIconOptions(view,ui)
    local controls={}
    local caption,preview
    local function Enabled()
        if addon.GetQuestMarkersEnabled then return addon:GetQuestMarkersEnabled() end
        return not ForeverNameplatesDB or ForeverNameplatesDB.questMarker~=false
    end
    local function RefreshPreview()
        preview:Refresh()
        if not Enabled() then caption:SetText("Preview (icons disabled)") end
    end
    local function Refresh()
        for _,control in ipairs(controls) do control:Refresh() end
        RefreshPreview()
    end
    local function Save(key,value)
        ForeverNameplatesDB=ForeverNameplatesDB or {}
        if key=="size" then ForeverNameplatesDB.questIconSize=value
        else
            ForeverNameplatesDB.questIconPosition=ForeverNameplatesDB.questIconPosition or {x=-6,y=0}
            ForeverNameplatesDB.questIconPosition[key]=value
        end
        addon:RefreshQuestMarkers()
    end
    local visibility=CreateFrame("Frame",nil,view,"BackdropTemplate")
    visibility:SetPoint("TOPLEFT",44,-66)
    visibility:SetSize(480,48)
    ui.Backdrop(visibility)
    controls[#controls+1]=ui.Toggle(visibility,"Quest Objective Icons",16,-16,Enabled,function(value)
        if addon.SetQuestMarkersEnabled then addon:SetQuestMarkersEnabled(value); Refresh(); return end
        ForeverNameplatesDB=ForeverNameplatesDB or {}
        ForeverNameplatesDB.questMarker=value
        addon:RefreshQuestMarkers()
        Refresh()
    end,300)
    caption=ui.Font(view,"GameFontDisableSmall","Preview",44,-132,480)
    preview=ui.PreviewCard(view,76,-148)
    local viewport=CreateFrame("Frame",nil,preview)
    viewport:SetPoint("TOPLEFT",8,-6)
    viewport:SetPoint("BOTTOMRIGHT",-8,6)
    local sample=ui.CreateNameplateSample(preview,viewport,caption)
    addon:CreateQuestIconPreview(preview,viewport,sample,caption)
    -- Keep the sample configurable without enabling live quest icons.
    preview.alwaysShowQuestIcon=true
    local card=CreateFrame("Frame",nil,view,"BackdropTemplate")
    card:SetPoint("TOPLEFT",44,-240)
    card:SetSize(480,124)
    ui.Backdrop(card)
    local function Slider(text,key,x,y,width,low,high)
        local control=ui.SliderRow(card,text,x,y,width,low,high,1,function()
            local size,offsetX,offsetY=addon:GetQuestIconSettings()
            return key=="size" and size or (key=="x" and offsetX or offsetY)
        end,function(value) Save(key,value) end," px")
        control.OnUserValueChanged=Refresh
        controls[#controls+1]=control
        return control
    end
    Slider("Icon Size","size",16,-12,448,12,48):AddNotches({12,24,36,48})
    Slider("Horizontal Position","x",16,-68,198,-200,200)
    Slider("Vertical Position","y",266,-68,198,-100,100)
    local reset=ui.Button(visibility,"Reset",92,24)
    reset:SetPoint("RIGHT",-16,0)
    reset:SetScript("OnClick",function()
        local defaults=addon.defaults
        local position=defaults.questIconPosition or {x=-6,y=0}
        ForeverNameplatesDB=ForeverNameplatesDB or {}
        ForeverNameplatesDB.questIconSize=defaults.questIconSize or 24
        ForeverNameplatesDB.questIconPosition={x=position.x,y=position.y}
        addon:RefreshQuestMarkers()
        Refresh()
    end)
    local elapsed=0
    view:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=0.25 then elapsed=0; RefreshPreview() end
    end)
    return {Refresh=Refresh}
end

-- Preserve existing modern entry points, routing to the page instead of a popup.
function addon:OpenModernQuestIconOptions()
    addon.SelectOptionsPage("nameplates")
    self:ShowModernNameplateView("questIcons")
end
