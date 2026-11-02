local addon = ForeverNameplates

function addon:CreateQuestIconPreview(preview, viewport, sample, caption)
    local iconFrame = CreateFrame("Frame",nil,sample.content)
    iconFrame:SetFrameLevel(sample.bar:GetFrameLevel()+5)
    local icon = iconFrame:CreateTexture(nil,"OVERLAY")
    icon:SetAllPoints()
    local data = {plate=sample,iconFrame=iconFrame,icon=icon}
    preview.btpQuestIconPreview = data
    preview.Refresh = function()
        sample.followHealthInfo = true
        sample:Refresh()
        local r,g,b = 0.72,0.74,0.04
        if addon:GetQuestColorEnabled() then r,g,b=addon:GetQuestColor() end
        sample.bar:GetStatusBarTexture():SetVertexColor(1,1,1,1)
        sample.bar:SetStatusBarColor(r,g,b,1)
        local size,x,y = addon:GetQuestIconSettings()
        iconFrame:SetSize(size,size)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("RIGHT",sample.bar,"LEFT",x,y)
        addon:SetQuestObjectiveIcon(icon,"incomplete")
        local shown = preview.alwaysShowQuestIcon or not ForeverNameplatesDB or ForeverNameplatesDB.questMarker ~= false
        iconFrame:SetShown(shown)
        local bounds,geometry = sample.bounds,sample.geometry
        local left,right,top,bottom = bounds.left,bounds.right,bounds.top,bounds.bottom
        if shown then
            local iconRight = -geometry.width/2+x
            left,right = math.min(left,iconRight-size),math.max(right,iconRight)
            top,bottom = math.max(top,y+size/2),math.max(bottom,-y+size/2)
        end
        data.bounds = {left=left,right=right,top=top,bottom=bottom}
        local scale,fraction = addon:FitNameplatePreviewScale(addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale()),
            right-left+4,top+bottom+4,viewport:GetWidth(),viewport:GetHeight())
        sample.content:SetScale(scale)
        sample.bar:ClearAllPoints()
        sample.bar:SetPoint("CENTER",sample.content,"CENTER",-(left+right)/2,(bottom-top)/2)
        if caption then
            caption:SetText(fraction<0.995 and string.format("Preview (%d%% scale)",math.floor(fraction*100+0.5)) or "Preview")
        end
    end
    return preview
end
