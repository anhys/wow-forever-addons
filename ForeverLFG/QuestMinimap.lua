-- A minimap-owned launcher: orbit dragging never changes the map's anchors.
local _,NS=...
local media="Interface\\AddOns\\ForeverLFG\\Media\\"
local circle="Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="number"
        and value==value and value>-math.huge and value<math.huge
end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
local function point(fn,...)
    if type(fn)~="function" then return end
    local ok,x,y=pcall(fn,...)
    if ok and number(x) and number(y) then return x,y end
end
local function rounded(shape,x,y)
    local corner=(y>=0 and "TOP" or "BOTTOM")..(x<0 and "LEFT" or "RIGHT")
    if shape=="SQUARE" then return false end
    if shape and shape:match("^CORNER%-") then return shape=="CORNER-"..corner end
    if shape and shape:match("^TRICORNER%-") then return shape~="TRICORNER-"..corner end
    if shape=="SIDE-LEFT" then return x<0 end
    if shape=="SIDE-RIGHT" then return x>=0 end
    if shape=="SIDE-TOP" then return y>=0 end
    if shape=="SIDE-BOTTOM" then return y<0 end
    return true
end
local function position(b)
    local map=b:GetParent();local w,h=read(map.GetWidth,map),read(map.GetHeight,map)
    if not number(w) or not number(h) or w<=0 or h<=0 then return end
    local shape=read(GetMinimapShape);if type(shape)~="string" then shape="ROUND" end
    local angle=math.rad(b.angle);local x,y=math.cos(angle),math.sin(angle)
    if not rounded(shape,x,y) then local length=math.max(math.abs(x),math.abs(y));x,y=x/length,y/length end
    b:ClearAllPoints();b:SetPoint("CENTER",map,"CENTER",x*(w/2+5),y*(h/2+5))
    b.mapWidth,b.mapHeight,b.mapShape=w,h,shape
end
local function drag(b)
    local map=b:GetParent();local x,y=point(GetCursorPosition)
    local mx,my=point(map.GetCenter,map);local scale=read(map.GetEffectiveScale,map)
    if not x or not mx or not number(scale) or scale<=0 then return end
    x,y=x/scale-mx,y/scale-my
    if x==0 and y==0 then return end
    b.angle=math.deg(math.atan2(y,x))%360;position(b)
end
local function style(b)
    local active=b.questCount>0
    -- An empty result must not make the entry point disappear against the map.
    b.Icon:SetVertexColor(1,1,1,1)
    b.Ring:SetVertexColor(1,b.hovered and .87 or .73,b.hovered and .48 or .3,1)
    b.Count:SetTextColor(active and 1 or .87,active and .94 or .86,active and .74 or .8,1)
    b.Hover:SetShown(b.hovered==true)
    b.Icon:ClearAllPoints();b.Icon:SetPoint("CENTER",b,"CENTER",b.pressed and 1 or 0,b.pressed and 2 or 3)
end
local function disk(parent,size,layer,r,g,b,subLevel)
    local t=parent:CreateTexture(nil,layer,nil,subLevel);t:SetTexture(circle);t:SetSize(size,size);t:SetPoint("CENTER")
    t:SetVertexColor(r,g,b,1);return t
end
function NS.CreateQuestMinimap()
    local b=CreateFrame("Button","ForeverLFGQuestMinimapButton",Minimap);NS.QuestMinimapButton=b
    b.mode="minimap";b.questCount=0;b.hintKey="QUEST_MINIMAP_HINT"
    local level=read(Minimap.GetFrameLevel,Minimap)
    b:SetSize(36,36);b:SetClampedToScreen(true);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(number(level) and level+8 or 8);b:SetHitRectInsets(-4,-4,-4,-12)
    local saved=NS.Filters.Settings().questMinimap
    b.angle=type(saved)=="table" and number(saved.angle) and saved.angle%360 or 225
    -- Explicit concentric rims stay visible without depending on an atlas's padding.
    b.Shadow=disk(b,40,"BACKGROUND",.035,.025,.015,-3)
    b.Ring=disk(b,38,"BACKGROUND",1,.73,.3,-2)
    b.Bevel=disk(b,34,"BACKGROUND",.22,.13,.045,-1)
    b.Base=disk(b,32,"BORDER",.07,.055,.035,-1)
    b.FactionTexture=b:CreateTexture(nil,"BORDER");b.FactionTexture:SetSize(30,30);b.FactionTexture:SetPoint("CENTER")
    b.FactionTexture:SetAlpha(.45)
    local mask=b:CreateMaskTexture();mask:SetTexture(circle,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.FactionTexture);b.FactionTexture:AddMaskTexture(mask);b.CircleMask=mask
    b.Icon=b:CreateTexture(nil,"ARTWORK");b.Icon:SetTexture(media.."QuestPartners.tga");b.Icon:SetSize(26,26);b.Icon:SetPoint("CENTER",0,3)
    b.Hover=disk(b,38,"OVERLAY",1,.88,.55,1)
    b.Hover:SetAlpha(.12);b.Hover:SetBlendMode("ADD");b.Hover:Hide()
    local light=CreateFrame("Frame",nil,b);b.PulseSurface=light
    light:SetAllPoints(b);light:SetFrameLevel(b:GetFrameLevel()+1);light:SetAlpha(0)
    local wash=disk(light,32,"BACKGROUND",1,.73,.3);wash:SetBlendMode("ADD");wash:SetAlpha(.42)
    local emblem=light:CreateTexture(nil,"ARTWORK");emblem:SetTexture(media.."QuestPartners.tga");emblem:SetAllPoints(b.Icon)
    emblem:SetVertexColor(1,.9,.6,.85);emblem:SetBlendMode("ADD")
    local halo=disk(light,48,"BACKGROUND",1,.82,.42,-1);halo:SetAlpha(.26);halo:SetBlendMode("ADD")
    local aura=disk(light,54,"BACKGROUND",1,.76,.32,-2);aura:SetAlpha(.08);aura:SetBlendMode("ADD")
    local pulse=light:CreateAnimationGroup();b.Pulse=pulse
    for _,step in ipairs({{0,1,.2,0},{1,.45,.45,.2},{.45,1,.25,.65},{1,0,.9,.9}}) do
        local a=pulse:CreateAnimation("Alpha");a:SetFromAlpha(step[1]);a:SetToAlpha(step[2]);a:SetDuration(step[3]);a:SetStartDelay(step[4]);a:SetOrder(1)
    end
    pulse:SetScript("OnFinished",function() light:SetAlpha(0) end);pulse:SetScript("OnStop",function() light:SetAlpha(0) end)
    function b:StopAttention() self.Pulse:Stop();self.PulseSurface:SetAlpha(0) end
    function b:PlayAttention() self:StopAttention();self.Pulse:Play() end
    local badge=CreateFrame("Frame",nil,b,"BackdropTemplate");b.Badge=badge
    badge:SetSize(23,16);badge:SetPoint("BOTTOM",0,-10);badge:SetFrameLevel(b:GetFrameLevel()+3)
    badge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
    badge:SetBackdropColor(.035,.025,.015,1);badge:SetBackdropBorderColor(.85,.65,.28,1)
    b.Count=badge:CreateFontString(nil,"OVERLAY","GameFontNormal");NS.QuestFont(b.Count,12)
    b.Count:SetAllPoints(badge);b.Count:SetJustifyH("CENTER");b.Count:SetJustifyV("MIDDLE")
    b.Unread=b:CreateTexture(nil,"OVERLAY",nil,3);b.Unread:SetTexture(circle);b.Unread:SetSize(7,7)
    b.Unread:SetPoint("TOPLEFT",2,-1);b.Unread:SetVertexColor(1,.86,.3,1);b.Unread:Hide()
    function b:UpdateAppearance()
        self.Count:SetText(tostring(self.questCount))
        local faction=read(UnitFactionGroup,"player")
        if faction=="Horde" then self.Base:SetVertexColor(.28,.025,.018,1)
        elseif faction=="Alliance" then self.Base:SetVertexColor(.018,.075,.26,1)
        else self.Base:SetVertexColor(.07,.055,.035,1) end
        if faction=="Horde" or faction=="Alliance" then
            self.FactionTexture:SetTexture(media.."QuestHeader"..faction..".tga")
            self.FactionTexture:SetTexCoord(.08,.24,.03,.67);self.FactionTexture:Show()
        else self.FactionTexture:Hide() end
        self.factionStyle=faction;style(self)
    end
    function b:FinishDrag()
        if not self.dragging then return end
        self.dragging=false;self.pressed=false;self.suppressClick=true
        NS.Filters.Settings().questMinimap={angle=self.angle};style(self)
    end
    NS.BindQuestLauncher(b,style)
    b:SetScript("OnDragStart",function(self)
        if InCombatLockdown() then return end
        self.dragging=true;self.suppressClick=true;self.pressed=false;GameTooltip:Hide();drag(self)
    end)
    b:SetScript("OnDragStop",b.FinishDrag)
    local elapsed=0
    b:SetScript("OnUpdate",function(self,delta)
        if self.dragging then
            if InCombatLockdown() then self:FinishDrag() else drag(self) end
            return
        end
        elapsed=elapsed+delta;if elapsed<.25 then return end;elapsed=0
        local shape=read(GetMinimapShape);if type(shape)~="string" then shape="ROUND" end
        local map=self:GetParent();if not map then return end
        if self.mapWidth~=read(map.GetWidth,map) or self.mapHeight~=read(map.GetHeight,map) or self.mapShape~=shape then position(self) end
    end)
    position(b);return b
end
