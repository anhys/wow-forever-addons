-- Independent visual interpretation of the Jundies profile's public screenshots:
-- https://wago.io/ak3iS95aa . Uses BTP's own rendering and threat/aura policies.
local addon=ForeverNameplates
local WHITE="Interface\\Buttons\\WHITE8X8"
local FONT="Interface\\AddOns\\BlizzThreatPlates-Forever\\media\\fonts\\Expressway-Bold.ttf"
local touched=setmetatable({}, {__mode="k"})
-- Approved editor preset: 116.424 wide at the default 84% plate width.
local CAST_DEFAULTS={enabled=true,width=138.6,height=12,offsetY=-3,nameSize=10,timeSize=10,
    showName=true,showTime=true,interruptibleColor={1,0.70,0},protectedColor={0.5,0.5,0.5}}

function addon:GetJundiesFontPath()
    return FONT
end

function addon:GetJundiesStyleLayout(ignoreDimensions)
    local scale=1+(self:GetNameplateSize()-2)*0.10
    return {width=180*scale*(ignoreDimensions and 1 or self:GetNameplateWidthPercent()/100),
        height=20*scale*(ignoreDimensions and 1 or self:GetNameplateHeightPercent()/100)}
end
function addon:GetJundiesCastbarDefaults()
    return CAST_DEFAULTS
end
local function SetFont(label,size)
    addon:SetFontWithFallback(label,FONT,size,"OUTLINE")
    label:SetTextColor(1,1,1,1); label:SetShadowColor(0,0,0,0); label:SetShadowOffset(0,0)
    label:SetWordWrap(false)
end
function addon:ApplyJundiesCastbarFonts(name,time)
    local settings=self:GetATDCastbarSettings()
    SetFont(name,settings.nameSize); SetFont(time,settings.timeSize)
end
local function SmoothEdge(frame)
    local edge=frame:CreateTexture(nil,"OVERLAY")
    if edge.SetSnapToPixelGrid then edge:SetSnapToPixelGrid(false) end
    if edge.SetTexelSnappingBias then edge:SetTexelSnappingBias(0) end
    return edge
end
local function PixelWidth(frame,width)
    -- Match CreateATDTargetBorder's screen-pixel calculation. Only measure our
    -- own border's scale, and retain geometry if the client restricts that read.
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        local ok,scale=pcall(frame.GetEffectiveScale,frame)
        if ok and not (issecretvalue and issecretvalue(scale)) and type(scale)=="number" and scale>0 and scale<math.huge then
            local readable,stroke=pcall(PixelUtil.GetNearestPixelSize,width,scale,1)
            if readable and not (issecretvalue and issecretvalue(stroke)) and type(stroke)=="number" and stroke>0 and stroke<math.huge then
                frame.btpPixelWidth,frame.btpRequestedWidth=stroke,width
                return stroke
            end
        end
    end
    return frame.btpRequestedWidth==width and frame.btpPixelWidth or width
end
function addon:ApplyJundiesOuterBorder(bar,width,color,opacity,field)
    field=field or "btpJundiesBorder"
    local border=bar[field]
    if width<=0 then if border then border:Hide() end; return end
    if not border then
        border=CreateFrame("Frame",nil,bar,"BackdropTemplate"); border:EnableMouse(false)
        bar[field]=border
    end
    -- Creator frames are reused between built-ins and drafts. Remove any
    -- previous Backdrop before displaying the matching Jundies strips.
    if not border.btpUsingJundiesStrips then
        border:SetIgnoreParentScale(true)
        border:SetBackdrop(nil); border:ClearAllPoints(); border:SetAllPoints(bar)
        border.btpUsingJundiesStrips=true; border.stroke=nil
    end
    if not border.edges then
        border.edges={}
        for index=1,4 do border.edges[index]=SmoothEdge(border) end
    end
    border:SetFrameLevel(bar:GetFrameLevel()+3)
    local stroke=PixelWidth(border,width)
    if border.stroke~=stroke then
        for index,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local edge=border.edges[index]
            edge:ClearAllPoints()
            if index<=2 then
                local y=side=="TOP" and stroke or -stroke
                edge:SetPoint(side.."LEFT",border,side.."LEFT",-stroke,y)
                edge:SetPoint(side.."RIGHT",border,side.."RIGHT",stroke,y)
                edge:SetHeight(stroke)
            else
                local x=side=="LEFT" and -stroke or stroke
                edge:SetPoint("TOP"..side,border,"TOP"..side,x,0)
                edge:SetPoint("BOTTOM"..side,border,"BOTTOM"..side,x,0)
                edge:SetWidth(stroke)
            end
        end
        border.stroke=stroke
    end
    border.edgeWidth=width
    for _,edge in ipairs(border.edges) do edge:SetColorTexture(color[1],color[2],color[3],opacity/100); edge:Show() end
    border:Show()
end
function addon:ApplyJundiesTargetInset(bar,selected,width,opacity)
    width,opacity=width or 1,opacity or 65
    local inset=bar.btpJundiesTargetInset
    if not selected or width<=0 or opacity<=0 then if inset then inset:Hide() end; return end
    if not inset then
        inset=CreateFrame("Frame",nil,bar); inset:EnableMouse(false)
        inset:SetIgnoreParentScale(true)
        inset:SetAllPoints(bar)
        inset.edges={}
        for index=1,4 do
            local edge=SmoothEdge(inset)
            inset.edges[index]=edge
        end
        bar.btpJundiesTargetInset=inset
    end
    local stroke=PixelWidth(inset,width)
    if inset.stroke~=stroke then
        for index,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local edge=inset.edges[index]
            edge:ClearAllPoints()
            if side=="TOP" or side=="BOTTOM" then
                edge:SetPoint(side.."LEFT",inset,side.."LEFT",0,0)
                edge:SetPoint(side.."RIGHT",inset,side.."RIGHT",0,0)
                edge:SetHeight(stroke)
            else
                -- Exclude the top/bottom strips so corner opacity is uniform.
                edge:SetPoint("TOP"..side,inset,"TOP"..side,0,-stroke)
                edge:SetPoint("BOTTOM"..side,inset,"BOTTOM"..side,0,stroke)
                edge:SetWidth(stroke)
            end
        end
        inset.stroke=stroke
    end
    for _,edge in ipairs(inset.edges) do edge:SetColorTexture(0,0,0,opacity/100) end
    inset:SetFrameLevel(bar:GetFrameLevel()+2)
    inset:Show()
end
local function Border(bar,selected)
    local shade=selected and 0.88 or 0
    -- Both rims share the bar's unsnapped coordinate system. A snapped
    -- Backdrop outside a fractional inset can otherwise cover that inset.
    addon:ApplyJundiesOuterBorder(bar,selected and 1 or 0,{shade,shade,shade},100)
    addon:ApplyJundiesTargetInset(bar,selected)
end
function addon:PrepareJundiesStyle(decor)
    if not self:IsJundiesStyle() then self:ApplyJundiesTargetInset(decor.bar,false) end
    if not touched[decor] then return end
    touched[decor]=nil
    local keepBorder=self:IsJundiesStyle() and not (self.GetDevNameplateStyle and self:GetDevNameplateStyle(decor))
    if not keepBorder and decor.bar.btpJundiesBorder then decor.bar.btpJundiesBorder:Hide() end
    decor.background:SetVertexColor(0.0431372,0.0431372,0.0431372,1)
    decor.name:SetWidth(0)
    if not keepBorder and decor.blackBorder then decor.blackBorder:Show() end
    for _,role in ipairs({"name","percent","value"}) do decor[role]:SetShadowOffset(0,0) end
    if decor.cast then
        decor.cast.layoutSignature=nil
        decor.cast.text:SetShadowOffset(0,0); decor.cast.time:SetShadowOffset(0,0)
    end
end
function addon:ApplyJundiesStyle(decor,selected,preview)
    if not self:IsJundiesStyle() then return end
    -- Temporary creator previews retain full control of the target's design.
    if not preview and self.GetDevNameplateStyle and self:GetDevNameplateStyle(decor) then return end
    decor.bar:SetStatusBarTexture(WHITE)
    decor.background:SetTexture(WHITE); decor.background:SetVertexColor(0.08,0.08,0.08,1)
    if decor.blackBorder then decor.blackBorder:Hide() end
    if decor.targetBorder then decor.targetBorder:Hide() end
    Border(decor.bar,selected)
    SetFont(decor.name,self:GetMobNameFontSize())
    SetFont(decor.percent,self:GetHealthPercentFontSize()); SetFont(decor.value,self:GetHealthValueFontSize())
    local percentOn,valueOn=self:GetNameplateHealthInfoFlags()
    decor.showHealthPercent,decor.showHealthValue=percentOn,valueOn
    decor.percent:SetShown(percentOn); decor.value:SetShown(valueOn)
    -- Let the native FontStrings fit their contents, so short numbers do not
    -- reserve empty columns. Anchors follow that size without Lua measuring
    -- or reading potentially secret health text.
    decor.percent:SetWidth(0)
    decor.value:SetWidth(0)
    decor.name:ClearAllPoints(); decor.name:SetWidth(0); decor.name:SetJustifyH("LEFT")
    if self.GetNameplateNameEnabled then decor.name:SetShown(self:GetNameplateNameEnabled()) end
    decor.percent:ClearAllPoints(); decor.percent:SetJustifyH("RIGHT"); decor.percent:SetPoint("RIGHT",decor.bar,"RIGHT",-3,0)
    decor.value:ClearAllPoints(); decor.value:SetJustifyH("RIGHT")
    if percentOn then decor.value:SetPoint("RIGHT",decor.percent,"LEFT",-4,0)
    else decor.value:SetPoint("RIGHT",decor.bar,"RIGHT",-3,0) end
    decor.name:SetPoint("LEFT",decor.bar,"LEFT",3,0)
    decor.name:SetPoint("RIGHT",valueOn and decor.value or percentOn and decor.percent or decor.bar,
        (valueOn or percentOn) and "LEFT" or "RIGHT",-4,0)
    if self.ApplyNameplateTextAlignment then
        self:ApplyNameplateTextAlignment(decor.bar,decor.percent,decor.value,percentOn,valueOn,decor.name)
    end
    if decor.cast then
        self:ApplyJundiesCastbarFonts(decor.cast.text,decor.cast.time)
    end
    touched[decor]=true
end
function addon:ApplyJundiesStylePreview(bar,background,name,percent,value)
    self:ApplyJundiesStyle({bar=bar,background=background,name=name,percent=percent,value=value},true,true)
    background:ClearAllPoints(); background:SetAllPoints(bar)
    bar:SetBackdropColor(0,0,0,0); bar:SetBackdropBorderColor(0,0,0,0)
end
function addon:ResetJundiesStylePreview(bar)
    if bar.btpJundiesBorder then bar.btpJundiesBorder:Hide() end
    self:ApplyJundiesTargetInset(bar,false)
end
