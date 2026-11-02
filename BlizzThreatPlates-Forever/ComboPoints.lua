-- Native combo-point visuals on the target plate. Never modify Blizzard's
-- unit frame or AuraButton scripts, or measure restricted nameplate regions.
local addon=ForeverNameplates
local defaults={enabled=true,spacing=4,x=0,y=6,size=16,opacity=100,placement="above",swirlEnabled=true}
local SWIRL_TEXTURE="Interface\\AddOns\\BlizzThreatPlates-Forever\\media\\combo\\liquid-currents-v2.tga"
local NATIVE_POINT_SIZE=20 -- RogueComboPointTemplate's declared XML size; never measure a live child.
local limits={spacing={0,24},x={-150,150},y={-40,80},size={6,32},opacity={0,100}}
local window,row,preview,previewRow,status
local previewOnTarget=false
local previewCast=false
local liveGeneration=0
local lastLive
local lifted=setmetatable({}, {__mode="k"})
local queued=false
local events=CreateFrame("Frame")
local controls,placementButtons={},{}
local function StyleKey()
    return tostring(addon:GetNameplateStyleFamily())
end
local function DefaultX()
    local thin=Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
    return thin~=nil and addon:GetNameplateStyleFamily()==thin and 2 or 0
end
local function DefaultY()
    local style=addon:GetNameplateStyleFamily()
    if style=="JUNDIES" then return 5 end
    local native=Enum and Enum.NamePlateStyle or {}
    if native.Thin~=nil and style==native.Thin then return 2 end
    if native.Modern~=nil and style==native.Modern then return 8 end
    return 6
end
local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Accessible(frame)
    if not frame then return false end
    local ok,allowed=pcall(function()
        local forbidden=frame.IsForbidden and frame:IsForbidden()
        if Secret(forbidden) or forbidden then return false end
        if frame.CanBeAccessedInContext then return frame:CanBeAccessedInContext() end
        return true
    end)
    return ok and not Secret(allowed) and allowed==true
end
local function Settings()
    -- Adopt the experiment's settings before applying public migrations.
    if ForeverNameplatesDB and type(ForeverNameplatesDB.comboPoints)~="table"
        and type(ForeverNameplatesDB.devComboPoints)=="table" then
        ForeverNameplatesDB.comboPoints=ForeverNameplatesDB.devComboPoints
        ForeverNameplatesDB.devComboPoints=nil
    end
    if ForeverNameplatesDB and type(ForeverNameplatesDB.comboPoints)~="table" then
        ForeverNameplatesDB.comboPoints={}
    end
    local saved=ForeverNameplatesDB and ForeverNameplatesDB.comboPoints
    if type(saved)=="table" and saved.opacity100Applied~=true then
        -- One-time reset for this update, including existing opacity choices.
        -- Keep the marker through Reset so subsequent edits survive reloads.
        saved.opacity=100
        saved.opacity100Applied=true
    end
    if type(saved)=="table" and type(saved.positionProfiles)~="table" then
        saved.positionProfiles={}
        -- Old height/placement were global. Retain those edits on the active
        -- style while other styles receive their own new starting position.
        if saved.height~=nil or saved.placement~=nil then
            saved.positionProfiles[StyleKey()]={y=saved.height,placement=saved.placement}
        end
    end
    local thin=Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
    if type(saved)=="table" and thin~=nil and saved.blizzardDefaultX2Applied~=true then
        -- Update Blizzard Default once, even if another style is active.
        -- Retain Y/placement and all other styles; future X edits take priority.
        local id=tostring(thin)
        local profile=saved.positionProfiles[id]
        if type(profile)~="table" then profile={}; saved.positionProfiles[id]=profile end
        profile.x=2
        saved.blizzardDefaultX2Applied=true
    end
    return type(saved)=="table" and saved or {}
end
local function Value(key)
    if key=="swirlSpeed" then return 1.60 end
    local saved=Settings()
    local profile=saved.positionProfiles and saved.positionProfiles[StyleKey()] or {}
    if type(profile)~="table" then profile={} end
    local value=saved[key]
    if key=="x" or key=="y" or key=="placement" then value=profile[key] end
    if key=="enabled" then
        if addon.GetCompatibilityMode and addon:GetCompatibilityMode() and addon.GetCompatibilityFeatureEnabled then
            return addon:GetCompatibilityFeatureEnabled("comboPoints")
        end
        return value~=false
    end
    if key=="swirlEnabled" then return value==nil and defaults.swirlEnabled or value==true end
    if key=="placement" then return value=="below" and "below" or "above" end
    if type(value)~="number" or value~=value then
        value=key=="y" and DefaultY() or key=="x" and DefaultX() or defaults[key]
    end
    return math.max(limits[key][1],math.min(limits[key][2],value))
end
local function Save(key,value)
    if key=="enabled" and addon.SetCompatibilityFeatureEnabled
        and addon:SetCompatibilityFeatureEnabled("comboPoints",value) then return end
    ForeverNameplatesDB=ForeverNameplatesDB or {}
    Settings()
    if type(ForeverNameplatesDB.comboPoints)~="table" then ForeverNameplatesDB.comboPoints={} end
    local saved=ForeverNameplatesDB.comboPoints
    if key=="x" or key=="y" or key=="placement" then
        saved.positionProfiles=saved.positionProfiles or {}
        local id=StyleKey()
        saved.positionProfiles[id]=saved.positionProfiles[id] or {}
        saved.positionProfiles[id][key]=value
    else saved[key]=value end
end
local function GemColor() return nil end -- Always use Blizzard's original red.
local function TintRim(visual)
    if visual.btpGreyRim then return end
    -- Desaturate only the sockets/rim glow. Preserve native transition alpha.
    for _,key in ipairs({"BGActive","BGInactive","BGGlow","FrameGlow"}) do
        local texture=visual[key]
        if texture then
            texture:SetDesaturated(true)
            texture:SetVertexColor(0.35,0.35,0.35)
        end
    end
    visual.btpGreyRim=true
end
local function TintGem(visual,color)
    local previous=visual.btpGemColor
    if not color and previous==false then return end
    if color and previous and previous[1]==color[1] and previous[2]==color[2] and previous[3]==color[3] then return end
    -- Only the red gem and its red effect layers are tinted here. Rim colors
    -- are handled separately; native transition alpha remains intact.
    for _,key in ipairs({"IconUncharged","FXUncharged","SlashFBUncharged"}) do
        local texture=visual[key]
        if texture then
            texture:SetDesaturated(color~=nil)
            -- Alpha belongs to the native transition. An explicit 1 here
            -- exposes hidden flipbook sheets (and filled icons on empty gems).
            if color then texture:SetVertexColor(color[1],color[2],color[3])
            else texture:SetVertexColor(1,1,1) end
        end
    end
    visual.btpGemColor=color or false
end
local function StopSwirl(point)
    if not point.swirl then return end
    for _,layer in ipairs(point.swirl) do
        if layer.playing then layer.group:Stop(); layer.playing=false end
        layer.texture:Hide()
    end
end
local function StopSwirls(frame)
    if frame then for _,point in ipairs(frame.comboPoints) do StopSwirl(point) end end
end
local function Swirl(point,active,index,color)
    if not active or not Value("swirlEnabled") or Value("opacity")==0 then StopSwirl(point); return end
    local visual=point.visual
    if not visual.IconUncharged then return end
    if not point.swirl then
        point.swirl={}
        -- The native gem uses ARTWORK sublevel 1. Give currents explicit
        -- higher sublevels so texture batching cannot cover them with the gem.
        -- Keep the native red gain glow above both current layers.
        if visual.FXUncharged then visual.FXUncharged:SetDrawLayer("ARTWORK",4) end
        for layerIndex=1,2 do
            -- Evolving currents are baked into a circular RGBA flipbook,
            -- rather than rotating a static image. Native playback keeps
            -- animation work out of Lua; native rim geometry and gain FX stay intact.
            local texture=visual:CreateTexture(nil,"ARTWORK",nil,1+layerIndex)
            texture:SetTexture(SWIRL_TEXTURE,"CLAMP","CLAMP","LINEAR")
            texture:SetAllPoints(visual.IconUncharged); texture:SetBlendMode("BLEND")
            texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0)
            texture:SetTexCoord(0,1/8,0,1/16)
            local group=texture:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            local flow=group:CreateAnimation("FlipBook")
            flow:SetFlipBookRows(16); flow:SetFlipBookColumns(8); flow:SetFlipBookFrames(128)
            flow:SetFlipBookFrameWidth(0); flow:SetFlipBookFrameHeight(0)
            flow:SetDuration(layerIndex==1 and 6.4+index*0.19 or 8.1+index*0.23)
            point.swirl[layerIndex]={texture=texture,group=group,offset=index*0.41+layerIndex*1.13}
        end
    end
    local speed=Value("swirlSpeed")
    for layerIndex,layer in ipairs(point.swirl) do
        layer.texture:SetDesaturated(color~=nil)
        if color then
            layer.texture:SetVertexColor(0.2+color[1]*0.8,0.2+color[2]*0.8,0.2+color[3]*0.8)
        else layer.texture:SetVertexColor(1,1,1) end
        -- Alpha here belongs solely to our current layer. Never change the
        -- native icon/flipbook alpha that drives the combo-point gain effect.
        layer.texture:SetAlpha(layerIndex==1 and 0.92 or 0.24)
        if layer.speed~=speed then layer.group:SetAnimationSpeedMultiplier(speed); layer.speed=speed end
        layer.texture:Show()
        -- Reverse adjacent gems' currents while retaining their independent phases.
        if not layer.group:IsPlaying() then layer.group:Play(index%2==0,layer.offset) end
        layer.playing=true
    end
end
local function RefreshSwirls(frame)
    if not frame:IsVisible() then StopSwirls(frame); return end
    for index,point in ipairs(frame.comboPoints) do
        Swirl(point,index<=(frame.btpCount or 0) and index<=(frame.btpMax or 0),index,GemColor())
    end
end
local function ReadNumber(api,...)
    if not api then return nil end
    local ok,value=pcall(api,...)
    if ok and not Secret(value) and type(value)=="number" and value==value then return value end
end
local function Points()
    local power=Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
    local count
    if GetComboPoints then count=ReadNumber(GetComboPoints,"player","target")
    else count=ReadNumber(UnitPower,"player",power) end
    if count==nil then return nil,nil,"Combo points are restricted or unavailable; live row hidden." end
    local max
    if UnitPowerMax then max=ReadNumber(UnitPowerMax,"player",power) else max=5 end
    if not max then return nil,nil,"Combo-point maximum is restricted; live row hidden." end
    if max<1 then return 0,5,"No active combo-point resource." end
    max=math.min(10,math.floor(max))
    return math.max(0,math.min(max,math.floor(count))),max
end
local function MakeRow(parent)
    local frame=CreateFrame("Frame",nil,parent)
    frame:EnableMouse(false); frame.comboPoints={}
    frame:SetScript("OnShow",function() RefreshSwirls(frame) end)
    frame:SetScript("OnHide",function() StopSwirls(frame) end); frame:Hide()
    return frame
end
local function NativePointsAvailable()
    return RogueComboPointMixin and type(RogueComboPointMixin.Setup)=="function"
        and type(RogueComboPointMixin.SetActiveNoAnimation)=="function"
        and type(RogueComboPointMixin.SetActive)=="function"
end
local function Draw(frame,count,max,animate,reset)
    if not NativePointsAvailable() then frame:Hide(); return false end
    local size,spacing=Value("size"),Value("spacing")
    local color=GemColor()
    frame:SetSize(max*size+(max-1)*spacing,size)
    frame:SetAlpha(Value("opacity")/100)
    for index=1,max do
        local point=frame.comboPoints[index]
        if not point then
            point=CreateFrame("Frame",nil,frame)
            point:EnableMouse(false)
            -- This is the same template used by Camelot's unit-frame ComboFrame.
            -- Keep its native geometry and scale the whole visual, including its
            -- layered atlases, rather than cropping/stretching a legacy sheet.
            point.visual=CreateFrame("Frame",nil,point,"RogueComboPointTemplate")
            point.visual:EnableMouse(false)
            point.visual:Setup()
            point.visual:SetActiveNoAnimation(false)
            point.visual:SetPoint("CENTER",point,"CENTER",0,0)
            frame.comboPoints[index]=point
        elseif reset then
            StopSwirl(point)
            point.visual:Setup()
        end
        local pointX=(index-1)*(size+spacing)
        if point.btpX~=pointX then
            point:ClearAllPoints(); point:SetPoint("LEFT",frame,"LEFT",pointX,0)
            point.btpX=pointX
        end
        -- Keep the complete native visual below the bar, including gain effects.
        point:SetFrameLevel(frame:GetFrameLevel()+1)
        point.visual:SetFrameLevel(frame:GetFrameLevel()+2)
        point:SetSize(size,size)
        point.visual:SetScale(size/NATIVE_POINT_SIZE)
        TintRim(point.visual)
        TintGem(point.visual,color)
        if animate then point.visual:SetActive(index<=count)
        else point.visual:SetActiveNoAnimation(index<=count) end
        if index>count then StopSwirl(point) end
        point:Show()
    end
    for index=max+1,#frame.comboPoints do StopSwirl(frame.comboPoints[index]); frame.comboPoints[index]:Hide() end
    frame.btpCount,frame.btpMax=count,max
    return true
end
local function PositionRow(frame,anchor,above,x,y)
    if frame.btpAnchor==anchor and frame.btpAbove==above and frame.btpX==x and frame.btpY==y then return end
    frame:ClearAllPoints()
    if above then frame:SetPoint("BOTTOM",anchor,"TOP",x,y)
    else frame:SetPoint("TOP",anchor,"BOTTOM",x,-y) end
    frame.btpAnchor,frame.btpAbove,frame.btpX,frame.btpY=anchor,above,x,y
end
local function HideLive(clearHistory)
    if row then row:Hide() end
    if clearHistory then lastLive=nil end
end
local function Lift(container,anchor,gap,amount,x,previewEntry)
    if not Accessible(container) or not Accessible(anchor) then return end
    x=x or 0
    lifted[container]={anchor=anchor,gap=gap,x=x,previewEntry=previewEntry,layout=previewEntry and previewEntry.btpLayout}
    pcall(function()
        container:ClearAllPoints(); container:SetPoint("BOTTOMLEFT",anchor,"TOPLEFT",x,gap+amount)
    end)
end
local function RestoreLifts()
    for container,saved in pairs(lifted) do
        if Accessible(container) and Accessible(saved.anchor) then
            local ok=pcall(function()
                -- A new layout snapshot means the preview already positioned
                -- this icon again. Never measure restricted nameplate regions
                -- or undo a newer layout (including moves to the left CC row).
                if saved.previewEntry and saved.previewEntry.btpLayout~=saved.layout then return end
                container:ClearAllPoints(); container:SetPoint("BOTTOMLEFT",saved.anchor,"TOPLEFT",saved.x,saved.gap)
            end)
            if ok then lifted[container]=nil end
        end
    end
end
local function NativeNameGap()
    local thin=Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin
    return not addon:IsATDStyle() and thin~=nil and addon:GetNameplateStyleFamily()==thin
        and addon:GetMobNameFontSize()+4 or 0
end
local function CastState(api)
    if not api then return nil end
    local ok,value=pcall(api,"target")
    if not ok or Secret(value) then return nil end
    return value~=nil
end
local function AboveTarget()
    if Value("placement")=="above" or previewOnTarget and previewCast then return true end
    if UnitCanAttack then
        local ok,enemy=pcall(UnitCanAttack,"player","target")
        if ok and not Secret(enemy) and enemy==false then return false end
    end
    local cast=CastState(UnitCastingDuration or UnitCastingInfo)
    local channel=CastState(UnitChannelDuration or UnitChannelInfo)
    -- Unknown cast presence reserves the safer upper row, without inspecting
    -- secret spell names, duration fields, native visibility or frame bounds.
    return cast~=false or channel~=false
end
local function RefreshSample()
    if not window or not window:IsShown() then return end
    preview:Refresh()
    previewRow:SetFrameLevel(math.max(0,preview.bar:GetFrameLevel()-3))
    local drawn=Draw(previewRow,3,5)
    local above=Value("placement")=="above" or previewCast
    PositionRow(previewRow,preview.bar,above,Value("x"),Value("y")+(above and NativeNameGap() or 0))
    if drawn then
        previewRow:Show()
        -- Layout changes can stop native animation groups. Start only after
        -- the complete row is positioned and visible, including first open.
        RefreshSwirls(previewRow)
    end
end
local function Refresh()
    RestoreLifts()
    if window and window:IsShown() then
        for _,control in ipairs(controls) do control:Refresh() end
        for key,button in pairs(placementButtons) do
            local selected=Value("placement")==key
            button:SetBackdropBorderColor(unpack(selected and {0.88,0.66,0.24,1} or {0.20,0.23,0.27,1}))
            button.label:SetTextColor(unpack(selected and {0.88,0.66,0.24} or {0.92,0.90,0.84}))
        end
    end
    RefreshSample()
    if not Value("enabled") then HideLive(true); if status then status:SetText("Live nameplate combo points disabled.") end; return end
    if addon:GetCompatibilityMode() and (not addon.GetCompatibilityFeatureEnabled
        or not addon:GetCompatibilityFeatureEnabled("comboPoints")) then
        HideLive(true); if status then status:SetText("Enable on Nameplates to use combo points in Compatibility Mode.") end; return
    end
    if not NativePointsAvailable() then
        HideLive(true)
        if status then status:SetText("Blizzard's new combo-point template is unavailable on this client; row hidden.") end
        return
    end
    local count,max,notice=Points()
    if previewOnTarget then count,max,notice=3,5,"Previewing 3 combo points on your target." end
    if status then status:SetText(notice or (count and count>0 and "Following your target's combo points." or "Build a combo point, or enable Preview on Target.")) end
    if not count or Value("opacity")==0 then HideLive(true); return end
    local plate=addon:GetPlate("target")
    if not Accessible(plate) then HideLive(true); return end
    local unit=plate.unitToken
    if Secret(unit) or type(unit)~="string" then unit=nil end
    local same=lastLive and lastLive.plate==plate and lastLive.max==max
        and lastLive.preview==previewOnTarget and lastLive.generation==liveGeneration
    local animate=not previewOnTarget and same and lastLive.count~=count
    if count<1 then
        if row and (not same or lastLive.count~=0) then
            -- Prepare a true empty state so the next first point uses the
            -- native empty-to-full transition, even after spending all points.
            for _,point in ipairs(row.comboPoints) do
                point.visual:Setup(); point.visual:SetActiveNoAnimation(false)
            end
        end
        HideLive(false)
        lastLive={plate=plate,unit=unit,max=max,count=0,preview=previewOnTarget,generation=liveGeneration}
        return
    end
    local anchor=addon:GetThreatOverlayAnchor(plate)
    if not Accessible(anchor) then HideLive(true); return end
    if not row then row=MakeRow(UIParent) end
    if row:GetParent()~=plate then row:SetParent(plate) end
    row:SetFrameLevel(math.max(0,anchor:GetFrameLevel()-3))
    if not Draw(row,count,max,animate,not same) then HideLive(true); return end
    lastLive={plate=plate,unit=unit,max=max,count=count,preview=previewOnTarget,generation=liveGeneration}
    local above=AboveTarget()
    PositionRow(row,anchor,above,Value("x"),Value("y")+(above and NativeNameGap() or 0))
    row:Show()
    RefreshSwirls(row)
    -- RestoreLifts already returned real and sample auras to their normal
    -- positions. Below the bar reserves no top-aura space.
    if not above then return end
    local frame=plate.UnitFrame
    if not Accessible(frame) then return end
    local amount=math.max(0,Value("y")+Value("size")+4-6)
    local decor=frame.btpATDOverlay
    if addon:IsATDStyle() and decor then Lift(decor.auraContainer,decor.anchor,6,amount)
    elseif frame.btpNativeAuraDisplay then
        Lift(frame.btpNativeAuraDisplay.top,frame.healthBar or frame,6+NativeNameGap(),amount)
    elseif status then status:SetText("Live points shown. Native debuff lifting needs CC Display Workaround.")
    end
    local sample=addon:IsATDStyle() and decor or frame.btpNativeAuraPreview
    local auraPreview=sample and sample.auraPreview
    if auraPreview and auraPreview.btpIcons then
        for _,entry in ipairs(auraPreview.btpIcons) do
            -- These are BTP's synthetic sample Frames, never real AuraButtons.
            local layout=entry.btpLayout
            if layout then Lift(entry.frame,layout.anchor,layout.y,amount,layout.x,entry) end
        end
    end
end
local function Queue()
    if queued then return end
    queued=true
    C_Timer.After(0,function() queued=false; Refresh() end)
end

local function OpenControls(parent)
    if not window then
        local ui=addon.ModernOptionsUI
        window=parent
        local card=CreateFrame("Frame",nil,window,"BackdropTemplate")
        card:SetPoint("TOPLEFT",44,-66); card:SetSize(480,48); ui.Backdrop(card)
        local function Changed(key,value) Save(key,value); Refresh() end
        controls[#controls+1]=ui.Toggle(card,"Enable on Nameplates",16,-14,function() return Value("enabled") end,
            function(value) Changed("enabled",value) end,224)
        controls[#controls+1]=ui.Toggle(card,"Preview on Target",256,-14,function() return previewOnTarget end,
            function(value) previewOnTarget=value; Refresh() end,208)
        local caption=ui.Font(window,"GameFontDisableSmall","Preview",44,-126,480)
        local viewport=ui.PreviewCard(window,104,-142)
        local inset=CreateFrame("Frame",nil,viewport)
        inset:SetPoint("TOPLEFT",8,-6); inset:SetPoint("BOTTOMRIGHT",-8,6)
        preview=ui.CreateNameplateSample(viewport,inset,caption,1)
        previewRow=MakeRow(preview.content)
        preview.ExtendBounds=function(left,right,top,bottom)
            if Value("opacity")==0 then return left,right,top,bottom end
            local gap=Value("y")+NativeNameGap()
            local above=Value("placement")=="above" or previewCast
            local halfWidth=(5*Value("size")+4*Value("spacing"))/2
            left=math.min(left,Value("x")-halfWidth-4)
            right=math.max(right,Value("x")+halfWidth+4)
            -- Only measure our detached sample bar, never a live nameplate.
            -- Fit the actual gem bounds rather than adding name/debuff space
            -- twice, which made native-style previews unnecessarily small.
            local halfHeight=preview.bar:GetHeight()/2
            local rowTop,rowBottom
            if above then
                rowBottom=halfHeight+gap; rowTop=rowBottom+Value("size")
            else
                rowTop=-halfHeight-Value("y"); rowBottom=rowTop-Value("size")
            end
            top=math.max(top,rowTop+4); bottom=math.max(bottom,-rowBottom+4)
            return left,right,top,bottom
        end
        ui.Font(window,"GameFontHighlight","Placement",44,-264,224)
        local function PaintPlacement(button,key)
            local selected=Value("placement")==key
            button:SetBackdropBorderColor(unpack(selected and {0.88,0.66,0.24,1} or {0.20,0.23,0.27,1}))
        end
        for index,item in ipairs({{"above","Above"},{"below","Below"}}) do
            local key=item[1]
            local button=ui.Button(window,item[2],108,26)
            button:SetPoint("TOPLEFT",44+(index-1)*116,-282)
            placementButtons[key]=button
            button:SetScript("OnClick",function() Changed("placement",key) end)
            button:SetScript("OnLeave",function() PaintPlacement(button,key) end)
        end
        for _,item in ipairs({
            {"size","Size",300,-264,6,32," px"},
            {"x","X Placement",44,-326,-150,150," px"},
            {"y","Y Placement",300,-326,-40,80," px"},
            {"spacing","Spacing",44,-388,0,24," px"},
            {"opacity","Opacity",300,-388,0,100,"%"},
        }) do
            local key=item[1]
            controls[#controls+1]=ui.SliderRow(window,item[2],item[3],item[4],224,item[5],item[6],1,
                function() return Value(key) end,function(value) Changed(key,value) end,item[7])
        end
        controls[#controls+1]=ui.Toggle(window,"Liquid Swirl",44,-450,function() return Value("swirlEnabled") end,
            function(value) Changed("swirlEnabled",value) end,224)
        local reset=ui.Button(window,"Reset",120,26); reset:SetPoint("TOPLEFT",404,-446)
        status=ui.Font(window,"GameFontDisableSmall","",44,-490,480); status:SetWordWrap(true)
        reset:SetScript("OnClick",function()
            local saved=Settings()
            if saved.positionProfiles then saved.positionProfiles[StyleKey()]=nil end
            for _,key in ipairs({"enabled","spacing","size","opacity","swirlEnabled","height","placement","gemColor","swirlSpeed"}) do saved[key]=nil end
            previewOnTarget,previewCast=false,false
            Refresh()
        end)
        window:HookScript("OnHide",function()
            StopSwirls(previewRow); previewOnTarget,previewCast=false,false; Refresh()
        end)
    end
    Refresh()
end
function addon:RefreshComboPoints() Refresh() end
function addon:GetComboPointsEnabled() return Value("enabled") end
function addon:OpenComboPoints()
    if self.OptionsPanel then self.OptionsPanel:Show() end
    self.SelectOptionsPage("nameplates"); self:ShowModernNameplateView("comboPoints")
end
addon.OpenDevComboPoints=addon.OpenComboPoints
-- Only DevOptions creates a control for this simulation; normal spell/cast
-- events continue to drive the live automatic above/below placement.
function addon:SetComboPointsDevCastPreview(enabled)
    previewCast=enabled==true
    Refresh()
end
function addon:GetComboPointsDevCastPreview() return previewCast end
local ui=addon.ModernOptionsUI
if ui and ui.CreateView then
    local view=ui.CreateView("comboPoints","Combo Points","")
    view:SetScript("OnShow",function() OpenControls(view) end)
end
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","COMBO_TARGET_CHANGED","UNIT_POWER_FREQUENT",
    "UNIT_POWER_UPDATE","UNIT_MAXPOWER","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_AURA",
    "PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UPDATE_SHAPESHIFT_FORM","CVAR_UPDATE",
    "UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_CHANNEL_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit,power)
    if Secret(unit) then return end
    if event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_ENTERING_WORLD"
        or event=="NAME_PLATE_UNIT_REMOVED" and lastLive and lastLive.unit==unit then
        liveGeneration=liveGeneration+1
    end
    if event:match("^UNIT_SPELLCAST") and unit~="target" and not (type(unit)=="string" and unit:match("^nameplate%d+$")) then return end
    if event=="UNIT_POWER_FREQUENT" or event=="UNIT_POWER_UPDATE" or event=="UNIT_MAXPOWER" then
        if Secret(power) then return end
        if unit~="player" or (power and power~="COMBO_POINTS") then return end
    end
    Queue()
end)
for _,method in ipairs({"RefreshATDStyle","RefreshNativeCCFallbacks"}) do
    if addon[method] then hooksecurefunc(addon,method,Queue) end
end
SLASH_BTP_COMBO1="/btpcombo"
SlashCmdList.BTP_COMBO=function() addon:OpenComboPoints() end
