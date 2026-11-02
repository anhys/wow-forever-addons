-- A persistent, movable entry point; new matches never open the browser.
local _,NS=...
local Q,T=NS.Quests,NS.Text
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
local function number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="number"
        and value==value and value>-math.huge and value<math.huge
end
function NS.QuestMatchCounts(items)
    local quests,players,n,p={},{},0,0
    for _,match in ipairs(items) do
        if not quests[match.questID] then quests[match.questID]=true;n=n+1 end
        if not players[match.sender] then players[match.sender]=true;p=p+1 end
    end
    return n,p
end
local function center(frame)
    if not frame or type(frame.GetCenter)~="function" then return end
    local ok,x,y=pcall(frame.GetCenter,frame)
    local w,h=read(frame.GetWidth,frame),read(frame.GetHeight,frame)
    if ok and number(x) and number(y) and number(w) and number(h) and w>0 and h>0 then
        local scale,parentScale=read(frame.GetEffectiveScale,frame),read(UIParent.GetEffectiveScale,UIParent)
        local ratio=number(scale) and scale>0 and number(parentScale) and parentScale>0 and scale/parentScale or 1
        return x*ratio,y*ratio,w*ratio,h*ratio
    end
end
local function position(b,x,y)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    -- Clamp the frame itself; a safety margin made edge placements bounce back.
    x=math.max(0,math.min(x,math.max(0,w-b:GetWidth())))
    y=math.max(b:GetHeight(),math.min(y,h))
    b:ClearAllPoints();b:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
    return x/w,y/h
end
local function initialPosition(b)
    local s=NS.Filters.Settings().questLauncher
    if type(s)=="table" and number(s.x) and number(s.y) and s.x>=0 and s.x<=1 and s.y>=0 and s.y<=1 then
        position(b,s.x*UIParent:GetWidth(),s.y*UIParent:GetHeight());return
    end
    -- Read the stock header's position once; never join or change its layout.
    local tracker=ObjectiveTrackerFrame
    local header=tracker and tracker.Header
    local x,y,w,h=center(header)
    if x and read(header.IsVisible,header) then
        local left,top=x-w/2,y+h/2+b:GetHeight()+6
        local mapX,mapY,mapW,mapH=center(Minimap)
        -- If the minimap leaves too little room above the stock header, sit
        -- beside it rather than cover the map or its coordinate text.
        if mapX and left+b:GetWidth()>mapX-mapW/2-8 and left<mapX+mapW/2+8
            and top>mapY-mapH/2-24 then
            left,top=x-w/2-b:GetWidth()-12,y+h/2
        end
        position(b,left,top);return
    end
    local _,mapY,_,mapH=center(Minimap)
    position(b,UIParent:GetWidth()-b:GetWidth()-24,mapY and mapY-mapH/2-12 or UIParent:GetHeight()-230)
end
local function style(b)
    local active=b.questCount>0
    b.Label:SetTextColor(active and .99 or .76,active and .89 or .74,active and .56 or .68,1)
    b.Count:SetTextColor(active and 1 or .65,active and .88 or .63,active and .44 or .58,1)
    b.Icon:SetVertexColor(active and .94 or .61,active and .84 or .59,active and .61 or .54,1)
    NS.TintQuestBorder(b,b.hovered and .94 or .62,b.hovered and .77 or .49,b.hovered and .40 or .28)
    b.Glow:SetShown(b.hovered==true)
end
local function tooltip(b)
    GameTooltip:SetOwner(b,"ANCHOR_LEFT");GameTooltip:SetText(T("QUEST_BROWSER_TITLE"))
    GameTooltip:AddLine(T("QUEST_LAUNCHER_COUNTS",b.questCount,b.playerCount),1,.89,.64,true)
    local unread=NS.QuestAttention and NS.QuestAttention:Count() or 0
    if unread>0 then GameTooltip:AddLine(T("QUEST_NEW_MATCHES",unread),1,.85,.40,true) end
    if Q.error or not Q.localState then GameTooltip:AddLine(T("CHANNEL_UNAVAILABLE"),.76,.74,.68,true)
    elseif b.questCount==0 then GameTooltip:AddLine(T("QUEST_NO_MATCHES"),.76,.74,.68,true) end
    GameTooltip:AddLine(T(b.hintKey or "QUEST_LAUNCHER_HINT"),1,1,1,true)
    if InCombatLockdown() and not (NS.QuestMatchesWindow and NS.QuestMatchesWindow:IsShown()) then
        GameTooltip:AddLine(T("QUEST_ACTION_COMBAT"),1,.65,.35,true)
    end
    GameTooltip:Show()
end
function NS.RefreshQuestAttention()
    local b=NS.QuestLauncher;if not b or not b.Unread then return end
    b.Unread:SetShown(NS.QuestAttention and NS.QuestAttention:Count()>0 or false)
    if b.hovered and not b.dragging then tooltip(b) end
end
function NS.StopQuestAttention()
    local b=NS.QuestLauncher;if not b then return end
    if b.StopAttention then b:StopAttention();return end
    if not b.Sweep then return end
    b.Sweep:Stop();b.Beam:SetAlpha(0)
end
function NS.PlayQuestAttention()
    local b=NS.QuestLauncher;if not b or read(b.IsVisible,b)~=true then return false end
    if b.PlayAttention then b:PlayAttention();return true end
    NS.StopQuestAttention()
    local width=b.SweepClip:GetWidth();local band=math.min(104,width*.38)
    b.Beam:SetSize(band,b.SweepClip:GetHeight());b.Beam:ClearAllPoints()
    b.Beam:SetPoint("LEFT",b.SweepClip,"LEFT",-band,0)
    b.Sweep.Translation:SetOffset(width+band,0);b.Sweep:Play()
    b.AttentionPulse:Play()
    return true
end
function NS.UpdateQuestLauncher(items)
    local b=NS.QuestLauncher;if not b then return end
    b.questCount,b.playerCount=NS.QuestMatchCounts(items or Q:Matches())
    if b.mode=="minimap" then b:UpdateAppearance();NS.RefreshQuestAttention();return end
    b.Count:SetText(NS.QuestCountText(b.questCount))
    NS.QuestHeader(b,read(UnitFactionGroup,"player"))
    -- Crop a horizontal strip instead of flattening the faction engraving.
    local half=2172*(b:GetHeight()-6)/(b:GetWidth()-6)/2
    b.FactionTexture:SetTexCoord(0,2172/4096,(362-half)/1024,(362+half)/1024)
    style(b)
    NS.RefreshQuestAttention()
end
function NS.BindQuestLauncher(b,refreshStyle)
    b:RegisterForClicks("LeftButtonUp");b:RegisterForDrag("LeftButton")
    b:SetScript("OnMouseDown",function(self,button)
        if button and button~="LeftButton" then return end
        if not self.dragging then self.suppressClick=false;self.pressed=true;refreshStyle(self) end
    end)
    b:SetScript("OnMouseUp",function(self) self.pressed=false;refreshStyle(self) end)
    b:SetScript("OnClick",function(self,button)
        if (button and button~="LeftButton") or self.dragging or self.suppressClick then return end
        local f=NS.QuestMatchesWindow
        if f and f:IsShown() then f:Hide() else NS.OpenQuestMatches() end
        if self.hovered then tooltip(self) end
    end)
    b:SetScript("OnEnter",function(self) self.hovered=true;refreshStyle(self);if not self.dragging then tooltip(self) end end)
    b:SetScript("OnLeave",function(self) self.hovered=false;self.pressed=false;refreshStyle(self);GameTooltip:Hide() end)
    b:SetScript("OnHide",function(self)
        if self.hovered then GameTooltip:Hide() end
        self.hovered=false;self.pressed=false;self.suppressClick=true
        if self.FinishDrag then self:FinishDrag() end
        if self.StopAttention then self:StopAttention() elseif self.Sweep then self.Sweep:Stop();self.Beam:SetAlpha(0) end
    end)
end
local function createBar()
    local b=CreateFrame("Button","ForeverLFGQuestLauncher",UIParent);NS.QuestBar=b
    b.mode="bar";b.questCount=0
    b:SetHeight(32);b:SetFrameStrata("MEDIUM");b:SetClampedToScreen(true);b:SetMovable(true)
    NS.QuestSurface(b,.045,.032,.021);NS.ApplyQuestBorder(b)
    local clip=CreateFrame("Frame",nil,b);b.SweepClip=clip
    clip:SetPoint("TOPLEFT",3,-3);clip:SetPoint("BOTTOMRIGHT",-3,3);clip:SetClipsChildren(true)
    -- Keep the labels and symbol above the brighter moving light.
    local text=CreateFrame("Frame",nil,clip);b.TextSurface=text
    text:SetAllPoints(b);text:SetFrameLevel(clip:GetFrameLevel()+1)
    b.Label=text:CreateFontString(nil,"OVERLAY","GameFontNormal");NS.QuestFont(b.Label,12)
    b.Label:SetText(T("QUEST_LAUNCHER_TITLE"));b.Label:SetJustifyH("LEFT");b.Label:SetWordWrap(true);b.Label:SetMaxLines(2)
    b.Icon=text:CreateTexture(nil,"ARTWORK");b.Icon:SetAtlas("socialqueuing-icon-group",false);b.Icon:SetSize(18,18);b.Icon:SetPoint("LEFT",10,0)
    b.Count=text:CreateFontString(nil,"OVERLAY","GameFontNormal");NS.QuestFont(b.Count,13)
    b.Count:SetPoint("RIGHT",-11,0);b.Count:SetHeight(18);b.Count:SetJustifyH("RIGHT")
    local countWidth=28
    for _,n in ipairs({0,1,2,5,11,21,64}) do b.Count:SetText(NS.QuestCountText(n));countWidth=math.max(countWidth,NS.QuestTextWidth(b.Count)+2) end
    b.Count:SetWidth(countWidth);b.Label:SetPoint("LEFT",34,0);b.Label:SetPoint("RIGHT",-countWidth-19,0)
    b:SetWidth(math.min(UIParent:GetWidth()-16,math.max(282,math.min(402,NS.QuestTextWidth(b.Label)+countWidth+53))))
    b:SetHeight(math.max(32,NS.QuestTextHeight(b.Label,18)+14))
    b.Glow=b:CreateTexture(nil,"BORDER");b.Glow:SetPoint("TOPLEFT",3,-3);b.Glow:SetPoint("BOTTOMRIGHT",-3,3)
    b.Glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");b.Glow:SetVertexColor(1,.78,.34,.12);b.Glow:Hide()
    b.Unread=text:CreateFontString(nil,"OVERLAY","GameFontNormal");NS.QuestFont(b.Unread,13,1,.86,.40)
    b.Unread:SetText("•");b.Unread:SetSize(10,10);b.Unread:SetPoint("TOPRIGHT",b.Icon,"TOPRIGHT",3,4);b.Unread:Hide()
    b.AttentionGlow=b:CreateTexture(nil,"BORDER",nil,1)
    b.AttentionGlow:SetPoint("TOPLEFT",3,-3);b.AttentionGlow:SetPoint("BOTTOMRIGHT",-3,3)
    b.AttentionGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b.AttentionGlow:SetVertexColor(1,.78,.34,1);b.AttentionGlow:SetBlendMode("ADD");b.AttentionGlow:SetAlpha(0)
    local pulse=b.AttentionGlow:CreateAnimationGroup();b.AttentionPulse=pulse
    local rise=pulse:CreateAnimation("Alpha");rise:SetFromAlpha(0);rise:SetToAlpha(.18);rise:SetDuration(.22);rise:SetOrder(1)
    local fade=pulse:CreateAnimation("Alpha");fade:SetFromAlpha(.18);fade:SetToAlpha(0);fade:SetStartDelay(1.1);fade:SetDuration(.7);fade:SetOrder(1)
    pulse:SetScript("OnFinished",function() b.AttentionGlow:SetAlpha(0) end)
    pulse:SetScript("OnStop",function() b.AttentionGlow:SetAlpha(0) end)
    b.Beam=clip:CreateTexture(nil,"ARTWORK");b.Beam:SetAtlas("ui-questtracker-objfx-barglow",false)
    b.Beam:SetVertexColor(1,.85,.46,1);b.Beam:SetBlendMode("ADD");b.Beam:SetAlpha(0)
    local group=b.Beam:CreateAnimationGroup();b.Sweep=group
    local move=group:CreateAnimation("Translation");group.Translation=move;move:SetDuration(1.8);move:SetOrder(1)
    local enter=group:CreateAnimation("Alpha");enter:SetFromAlpha(0);enter:SetToAlpha(.46);enter:SetDuration(.2);enter:SetOrder(1)
    local leave=group:CreateAnimation("Alpha");leave:SetFromAlpha(.46);leave:SetToAlpha(0);leave:SetStartDelay(1.25);leave:SetDuration(.55);leave:SetOrder(1)
    group:SetScript("OnFinished",function() b.Beam:SetAlpha(0) end)
    group:SetScript("OnStop",function() b.Beam:SetAlpha(0) end)
    function b:StopAttention()
        self.Sweep:Stop();self.Beam:SetAlpha(0)
        self.AttentionPulse:Stop();self.AttentionGlow:SetAlpha(0)
    end
    initialPosition(b);NS.BindQuestLauncher(b,style)
    b:SetScript("OnDragStart",function(self)
        if InCombatLockdown() then return end
        self.dragging=true;self.suppressClick=true;GameTooltip:Hide();self:StartMoving()
    end)
    b.FinishDrag=function(self)
        if not self.dragging then return end
        self:StopMovingOrSizing();self.dragging=false
        local x,y,w,h=center(self)
        if x then
            local sx,sy=position(self,x-w/2,y+h/2)
            NS.Filters.Settings().questLauncher={x=sx,y=sy}
        end
    end
    b:SetScript("OnDragStop",b.FinishDrag)
    return b
end
function NS.QuestLauncherMode()
    local mode=NS.Filters.Settings().questLauncherMode
    if mode=="bar" or mode=="minimap" then return mode end
    return NS.QuestTutorialDefaultMode and NS.QuestTutorialDefaultMode() or "minimap"
end
function NS.SetQuestLauncherMode(mode)
    if mode~="bar" and mode~="minimap" then return end
    NS.Filters.Settings().questLauncherMode=mode
    NS.EnsureQuestLauncher()
end
function NS.EnsureQuestLauncher()
    if not UIParent then return end
    local mode=NS.QuestLauncherMode()
    local width,height=Minimap and read(Minimap.GetWidth,Minimap),Minimap and read(Minimap.GetHeight,Minimap)
    if mode=="minimap" and (not number(width) or width<=0 or not number(height) or height<=0) then mode="bar" end
    local current=NS.QuestLauncher
    if current and current.mode==mode then return current end
    if InCombatLockdown() then return current end
    if current then
        NS.StopQuestAttention()
        if current.FinishDrag then current:FinishDrag() end
        if current.hovered then GameTooltip:Hide() end
        current.hovered=false;current.pressed=false;current:Hide()
    end
    local b
    if mode=="minimap" then b=NS.QuestMinimapButton or NS.CreateQuestMinimap()
    else b=NS.QuestBar or createBar() end
    NS.QuestLauncher=b;b:Show();NS.UpdateQuestLauncher()
    return b
end
