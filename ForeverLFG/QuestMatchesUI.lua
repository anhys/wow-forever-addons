-- Manual browser with the reference's dense, content-sized presentation.
local _,NS=...
local Q,T=NS.Quests,NS.Text
local safe,title=NS.QuestSafeText,NS.QuestTitle
local questHeight,playerHeight=50,46
local inset,headerHeight,toggleHeight=12,74,28
local playerTop,playerBottom=30,8
local function plain(value) return not (issecretvalue and issecretvalue(value)) end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...);if ok and plain(value) then return value end
end
local function label(parent,size,x,y,right,height,light)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);text:SetPoint("TOPRIGHT",parent,"TOPRIGHT",right or -8,y)
    text:SetHeight(height or size+4);text:SetJustifyH("LEFT");text:SetWordWrap(false);text:SetMaxLines(1)
    if light then NS.QuestFont(text,size,.74,.72,.66) else NS.QuestFont(text,size) end
    return text
end
local function panel(parent)
    local f=CreateFrame("Frame",nil,parent)
    NS.QuestSurface(f);NS.ApplyQuestBorder(f);NS.TintQuestBorder(f,.48,.39,.26)
    return f
end
local function questInfo(id,map)
    local questMap=read(GetQuestUiMapID,id,true);local known=type(questMap)=="number" and questMap>0
    local info=read(C_Map and C_Map.GetMapInfo,known and questMap or map)
    local location=type(info)=="table" and plain(info.name) and type(info.name)=="string" and safe(info.name)
    local details={};local count=read(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
    if type(count)=="number" then
        for i=1,math.min(count,200) do
            local quest=read(C_QuestLog.GetInfo,i)
            if type(quest)=="table" and plain(quest.questID) and quest.questID==id then
                if plain(quest.level) and type(quest.level)=="number" and quest.level>0 then details[#details+1]=T("QUEST_LEVEL",quest.level) end
                break
            end
        end
    end
    if location then details[#details+1]=known and location or T("QUEST_PLAYERS_LOCATION",location) end
    return table.concat(details,"  -  ")
end
function NS.OpenMatchedQuest(id)
    if not InCombatLockdown() and type(QuestMapFrame_OpenToQuestDetails)=="function" then pcall(QuestMapFrame_OpenToQuestDetails,id) end
end
local function questTooltip(self,id)
    if not id then return end
    local link=read(GetQuestLink,id);GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    if type(link)=="string" and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(title(id)) end
    GameTooltip:AddLine(T("QUEST_ID",id),1,.82,0,true);GameTooltip:AddLine(T("QUEST_OPEN_HINT"),1,1,1,true);GameTooltip:Show()
end
local function playersText(n)
    local locale=NS.clientLocale
    if locale=="ruRU" then
        local ending=n%100;local key="QUEST_PLAYERS_MANY"
        if ending<11 or ending>14 then
            if n%10==1 then key="QUEST_PLAYERS_ONE" elseif n%10>=2 and n%10<=4 then key="QUEST_PLAYERS_FEW" end
        end
        return T(key,n)
    end
    return T(n==1 and "QUEST_PLAYERS_ONE" or "QUEST_PLAYERS_MANY",n)
end
local function highlight(row,on)
    row.selected=on
    NS.TintQuestBorder(row,on and 1 or .48,on and .82 or .39,on and .28 or .26)
    row.Glow:SetShown(on)
    row.Arrow:SetRotation(on and -math.pi/2 or 0)
    row.Arrow:SetVertexColor(on and 1 or .68,on and .86 or .64,on and .36 or .53,1)
end
local function createQuestRow(parent,owner)
    local row=CreateFrame("Button",nil,parent);row:SetHeight(questHeight-2)
    NS.QuestSurface(row,.055,.040,.026);NS.ApplyQuestBorder(row)
    row.Glow=row:CreateTexture(nil,"BORDER");row.Glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Glow:SetPoint("TOPLEFT",2,-2);row.Glow:SetPoint("BOTTOMRIGHT",-2,2);row.Glow:SetVertexColor(1,.76,.20,.35);row.Glow:Hide()
    row.IconBorder=panel(row);row.IconBorder:SetSize(36,36);row.IconBorder:SetPoint("LEFT",7,0)
    row.Icon=row.IconBorder:CreateTexture(nil,"ARTWORK");row.Icon:SetPoint("TOPLEFT",3,-3);row.Icon:SetPoint("BOTTOMRIGHT",-3,3)
    row.Icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")
    row.Name=label(row,14,52,-6,-116,20)
    row.Details=label(row,11,52,-27,-116,15,true)
    row.Count=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");NS.QuestFont(row.Count,10,.78,.75,.66)
    row.Count:SetJustifyH("RIGHT");row.Count:SetPoint("RIGHT",row,"RIGHT",-26,0);row.Count:SetHeight(16);row.Count:SetWordWrap(false)
    row.GroupIcon=row:CreateTexture(nil,"ARTWORK");row.GroupIcon:SetAtlas("socialqueuing-icon-group",false)
    row.GroupIcon:SetSize(16,16);row.GroupIcon:SetPoint("RIGHT",row.Count,"LEFT",-3,0);row.GroupIcon:SetVertexColor(.84,.78,.63,1)
    row.Arrow=row:CreateTexture(nil,"ARTWORK");row.Arrow:SetSize(8,13);row.Arrow:SetPoint("RIGHT",-11,0);row.Arrow:SetAtlas("common-icon-forwardarrow",false)
    row.Link=CreateFrame("Button",nil,row);row.Link:SetPoint("TOPLEFT",52,-5);row.Link:SetPoint("TOPRIGHT",-116,-5);row.Link:SetHeight(21)
    row.Link:SetScript("OnClick",function() if row.questID then NS.OpenMatchedQuest(row.questID) end end)
    row.Link:SetScript("OnEnter",function(self) questTooltip(self,row.questID) end);row.Link:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick",function() if row.questID then NS.SelectMatchedQuest(owner,row.questID) end end)
    row:SetScript("OnEnter",function(self)
        NS.TintQuestBorder(self,1,.86,.36);GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title(self.questID))
        GameTooltip:AddLine(T("QUEST_EXPAND_HINT"),1,1,1,true);GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function(self) highlight(self,self.selected);GameTooltip:Hide() end)
    row:Hide();return row
end
local function createPlayerRow(parent)
    local row=panel(parent);row:SetHeight(playerHeight-2)
    NS.TintQuestBorder(row,.30,.27,.21)
    row.IconBorder=panel(row);row.IconBorder:SetSize(32,32);row.IconBorder:SetPoint("LEFT",8,0)
    row.ClassIcon=row.IconBorder:CreateTexture(nil,"ARTWORK");row.ClassIcon:SetPoint("TOPLEFT",3,-3);row.ClassIcon:SetPoint("BOTTOMRIGHT",-3,3)
    row.Name=label(row,12,46,-5,-164,18);NS.QuestFont(row.Name,12,.95,.93,.86)
    row.Details=label(row,11,46,-24,-164,15,true);NS.QuestFont(row.Details,11,.84,.82,.75)
    local function action(key,width,x,fn)
        local b=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
        b:SetSize(width,24);b:SetPoint("RIGHT",row,"RIGHT",x,0);b:SetText(T(key));NS.QuestFont(b:GetFontString(),11)
        b.Border=CreateFrame("Frame",nil,b);b.Border:SetAllPoints(b);NS.ApplyQuestBorder(b.Border)
        b:SetMotionScriptsWhileDisabled(true)
        b:SetScript("OnEnter",function(self)
            self.hovered=true;NS.QuestActionStyle(self,self.disabledReason==nil,true)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(T(key))
            GameTooltip:AddLine(T(self.disabledReason or (key=="QUEST_WRITE" and "QUEST_WRITE_HINT" or "QUEST_INVITE_HINT")),1,1,1,true);GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function(self) self.hovered=false;NS.QuestActionStyle(self,self.disabledReason==nil,false);GameTooltip:Hide() end)
        b:SetScript("OnClick",function() fn(row.match) end);return b
    end
    row.Write=action("QUEST_WRITE",68,-86,NS.PrepareQuestWhisper);row.Invite=action("QUEST_INVITE",75,-6,NS.InviteQuestMatch)
    row:EnableMouse(true);row:SetScript("OnEnter",function(self)
        if self.match then
            local p=self.match.player;GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(safe(self.match.sender))
            GameTooltip:AddLine(T("QUEST_PLAYER",p.level,LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.class] or p.class),1,1,1)
            if p.group.size>0 then GameTooltip:AddLine(T("QUEST_GROUP",p.group.size),1,1,1) end
            if self.match.source=="group" or Q:IsPartyMember(self.match.sender) then GameTooltip:AddLine(T("QUEST_INVITE_SAME_GROUP"),1,1,1,true) end
            GameTooltip:Show()
        end
    end);row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row:Hide();return row
end
local function groupMatches(items)
    local groups,byID={},{}
    for _,match in ipairs(items) do
        local group=byID[match.questID]
        if not group then
            group={questID=match.questID,players={},details=questInfo(match.questID,match.player.map)}
            byID[match.questID]=group;groups[#groups+1]=group
        end
        group.players[#group.players+1]=match
    end
    return groups,byID
end
local function classText(class)
    local name=safe(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
    local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local hex=type(color)=="table" and read(function() return color.colorStr end)
    if type(hex)=="string" and hex:match("^%x%x%x%x%x%x%x%x$") then return "|c"..hex..name.."|r" end
    return name
end
local function classIcon(row,class)
    local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if type(coords)=="table" and #coords==4 then
        row.ClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles");row.ClassIcon:SetTexCoord(unpack(coords))
    else
        row.ClassIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");row.ClassIcon:SetTexCoord(0,1,0,1)
    end
end
local function actionReason(match,invite)
    if InCombatLockdown() then return "QUEST_ACTION_COMBAT" end
    if not match then return "QUEST_ACTION_STALE" end
    if not invite then return end
    if match.source=="group" or Q:IsPartyMember(match.sender) then return "QUEST_INVITE_SAME_GROUP" end
    if match.player.group.size>0 then return "QUEST_INVITE_IN_GROUP" end
    if Q:CanRecruit() then return end
    if read(IsInRaid)==true then return "QUEST_INVITE_RAID" end
    local count=read(GetNumGroupMembers)
    if type(count)=="number" then
        if count>=5 then return "QUEST_INVITE_FULL" end
        if count>0 and read(UnitIsGroupLeader,"player")==false then return "QUEST_INVITE_LEADER" end
    end
    return "QUEST_ACTION_UNAVAILABLE"
end
local function actionState(button,reason)
    button.disabledReason=reason;button:SetEnabled(reason==nil);NS.QuestActionStyle(button,reason==nil,button.hovered)
end
local function renderRows(list)
    local items=list.items or {};local viewport=list.Viewport;local offset=viewport:GetVerticalScroll();local height=list.rowHeight
    local first,last=1,0
    for i,slot in ipairs(list.layout or {}) do
        if slot.top+slot.height>offset and slot.top<offset+viewport:GetHeight() then
            if last==0 then first=i end;last=i
        end
    end
    local n=math.max(0,last-first+1)
    for i=1,n do if not list.rows[i] then list.rows[i]=list.createRow(list.Content) end end
    for i,row in ipairs(list.rows) do
        row.match=nil;row.questID=nil;row:Hide();local item=i<=n and items[first+i-1] or nil
        if item then
            local top=list.layout[first+i-1].top
            row:ClearAllPoints();row:SetPoint("TOPLEFT",list.Content,"TOPLEFT",0,-top);row:SetPoint("TOPRIGHT",list.Content,"TOPRIGHT",0,-top)
            if list.kind=="quests" then
                row.questID=item.questID;highlight(row,list.owner.selectedID==item.questID)
                row.Name:SetText(title(item.questID));row.Details:SetText(item.details);row.Count:SetText(playersText(#item.players));row.Link:SetEnabled(not InCombatLockdown())
            else
                row.match=item;local p=item.player;classIcon(row,p.class);row.Name:SetText(safe(item.sender));row.Details:SetText(T("QUEST_PLAYER_SHORT",p.level,classText(p.class)))
                actionState(row.Write,actionReason(item,false));actionState(row.Invite,actionReason(item,true))
            end
            row:Show()
        end
    end
end
local updateList
local function scrollList(list,delta)
    if list.kind=="players" then
        local viewport=list.Viewport;local offset=viewport:GetVerticalScroll();local range=viewport:GetVerticalScrollRange()
        -- A short player list must not trap the wheel above the remaining quests.
        if range<=1 or (delta>0 and offset<=.5) or (delta<0 and offset>=range-.5) then list=list.owner.QuestList end
    end
    list.ScrollBar:ScrollStepInDirection(-delta)
end
local function createList(parent,kind,owner,top,bottom)
    local list={rows={},items={},kind=kind,owner=owner,top=top,bottom=bottom or 4,inset=kind=="players" and 6 or 4,rowHeight=kind=="quests" and questHeight or playerHeight}
    local viewport=CreateFrame("ScrollFrame",nil,parent);list.Viewport=viewport
    viewport:SetPoint("TOPLEFT",list.inset,-top);viewport:SetPoint("BOTTOMRIGHT",-list.inset,list.bottom);viewport:EnableMouseWheel(true)
    local content=CreateFrame("Frame",nil,viewport);list.Content=content;content:SetPoint("TOPLEFT",viewport,"TOPLEFT",0,0);content:SetSize(1,1);viewport:SetScrollChild(content)
    local bar=CreateFrame("EventFrame",nil,parent,"MinimalScrollBar");list.ScrollBar=bar;bar:SetPoint("TOPRIGHT",-3,-top);bar:SetPoint("BOTTOMRIGHT",-3,list.bottom)
    if bar.SetHideIfUnscrollable then bar:SetHideIfUnscrollable(true) end
    ScrollUtil.InitScrollFrameWithScrollBar(viewport,bar);viewport:HookScript("OnVerticalScroll",function() renderRows(list) end)
    viewport:SetScript("OnMouseWheel",function(_,delta) scrollList(list,delta) end)
    -- Child extents can validate after the root's resize callback in the client.
    viewport:HookScript("OnSizeChanged",function()
        if owner.items and not owner.rendering and viewport:IsVisible() then updateList(list,list.items) end
    end)
    parent:EnableMouseWheel(true);parent:SetScript("OnMouseWheel",function(_,delta) scrollList(list,delta) end)
    list.createRow=kind=="quests" and function(p) return createQuestRow(p,owner) end or createPlayerRow;return list
end
updateList=function(list,items)
    if list.updating then return end
    list.updating=true;list.items=items
    -- Reserve an inline block after the expanded quest, before the next quest.
    list.layout={};local total=0
    for i,item in ipairs(items) do
        local extra=list.kind=="quests" and list.owner.expandedID==item.questID and list.owner.expandedHeight+4 or 0
        list.layout[i]={top=total,height=list.rowHeight+extra};total=total+list.rowHeight+extra
        if extra>0 then
            local pane=list.owner.PlayerPane;pane:ClearAllPoints()
            pane:SetPoint("TOPLEFT",list.Content,"TOPLEFT",14,-list.layout[i].top-list.rowHeight-2)
            pane:SetPoint("TOPRIGHT",list.Content,"TOPRIGHT",-4,-list.layout[i].top-list.rowHeight-2)
            pane:SetHeight(list.owner.expandedHeight)
        end
    end
    -- The final row has no trailing 2-unit gap. Ignore subpixel overflow.
    local contentHeight=math.max(0,total-2)
    local visibleHeight=list.Viewport:GetHeight();local overflow=contentHeight>visibleHeight+1
    list.Viewport:ClearAllPoints();list.Viewport:SetPoint("TOPLEFT",list.Viewport:GetParent(),"TOPLEFT",list.inset,-list.top)
    list.Viewport:SetPoint("BOTTOMRIGHT",list.Viewport:GetParent(),"BOTTOMRIGHT",overflow and -16 or -list.inset,list.bottom)
    list.Content:SetSize(math.max(1,list.Viewport:GetWidth()),math.max(1,overflow and contentHeight or visibleHeight));list.Viewport:UpdateScrollChildRect()
    list.Viewport:SetVerticalScroll(overflow and math.min(list.Viewport:GetVerticalScroll(),math.max(0,contentHeight-visibleHeight)) or 0)
    list.ScrollBar:SetShown(overflow);renderRows(list)
    list.updating=false
end
local function number(value,min,max) return plain(value) and type(value)=="number" and value==value and value>=min and value<=max end
local function settings()
    local character=NS.Filters.Settings();if type(character.questBrowser)~="table" then character.questBrowser={} end
    local s=character.questBrowser
    if s.layout~=2 then s.width=400;s.heightLimit=560;s.layout=2 end
    if not number(s.width,360,600) then s.width=400 end
    if not number(s.heightLimit,330,650) then s.heightLimit=560 end
    if not number(s.x,-.5,.5) then s.x=0 end;if not number(s.y,-.5,.5) then s.y=0 end
    -- Preserve the old 200-unit window position when migrating centre-based saves.
    if not number(s.left,-.5,.5) then s.left=s.x-s.width/(2*UIParent:GetWidth()) end
    if not number(s.top,-.5,.5) then s.top=s.y+100/UIParent:GetHeight() end
    return s
end
local function anchorWindow(f)
    local x,y=f:GetCenter();local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if number(width,1,100000) and number(height,1,100000) and number(x,-100000,100000) and number(y,-100000,100000) then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT",UIParent,"CENTER",x-f:GetWidth()/2-width/2,y+f:GetHeight()/2-height/2)
    end
end
local function saveWindow(f)
    local s=settings();s.width=f:GetWidth();s.heightLimit=f.heightLimit
    local x,y=f:GetCenter();local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if number(width,1,100000) and number(height,1,100000) and number(x,-100000,100000) and number(y,-100000,100000) then
        s.x=math.max(-.5,math.min(.5,x/width-.5));s.y=math.max(-.5,math.min(.5,y/height-.5))
        s.left=math.max(-.5,math.min(.5,(x-f:GetWidth()/2)/width-.5))
        s.top=math.max(-.5,math.min(.5,(y+f:GetHeight()/2)/height-.5))
    end
end
local function activeCount() return Q.localState and #Q.localState.quests or 0 end
local function listToggleStyle(button)
    -- Use matching native up/down assets; rotating the full dropdown atlas also
    -- flips its asymmetric frame/padding and moves the visible button centre.
    local direction=button.collapsed and "Down" or "Up"
    button.Arrow:SetAtlas("UI-ScrollBar-Scroll"..direction.."Button-"..(button.pressed and "Down" or "Up"),false)
    NS.TintQuestBorder(button,button.hovered and .95 or .68,button.hovered and .78 or .56,button.hovered and .39 or .33)
end
local function layoutHeader(f)
    local titleHeight=NS.QuestTextHeight(f.Title,23)
    local subtitleTop=6+titleHeight+3
    f.Subtitle:ClearAllPoints();f.Subtitle:SetPoint("TOPLEFT",f.Header,"TOPLEFT",14,-subtitleTop);f.Subtitle:SetPoint("TOPRIGHT",f.Header,"TOPRIGHT",-32,-subtitleTop)
    local statusTop=subtitleTop+NS.QuestTextHeight(f.Subtitle,16)+3
    f.Status:ClearAllPoints();f.Status:SetPoint("TOPLEFT",f.Header,"TOPLEFT",14,-statusTop);f.Status:SetPoint("TOPRIGHT",f.Header,"TOPRIGHT",-12,-statusTop)
    local height=statusTop+NS.QuestTextHeight(f.Status,14)+9
    f.Header:SetHeight(height);f.Body:ClearAllPoints()
    f.Body:SetPoint("TOPLEFT",inset,-inset-height-4);f.Body:SetPoint("BOTTOMRIGHT",-inset,inset)
    return height
end
function NS.RenderQuestMatchesFrame(f,items)
    if f.rendering then return end
    f.rendering=true;f.items=items
    local groups,byID=groupMatches(items);f.groups=groups
    if not byID[f.selectedID] then f.selectedID=nil end
    local collapsed=f.questsCollapsed
    local selected=not collapsed and byID[f.selectedID] or nil
    NS.QuestHeader(f.Header,read(UnitFactionGroup,"player"))
    local shared,players=NS.QuestMatchCounts(items)
    f.Status:SetText(T("QUEST_BROWSER_COUNT",shared,activeCount(),players))
    f.QuestsTitle:SetText(T("QUEST_BROWSER_QUESTS",#groups))
    f.QuestToggle.collapsed=not not collapsed;listToggleStyle(f.QuestToggle)
    f.QuestPane:SetShown(not collapsed)
    f.Empty:SetText(T("QUEST_NO_MATCHES"));f.Empty:SetShown(#groups==0);f.PlayerPane:SetShown(selected~=nil)
    local questWanted=collapsed and 4 or (#groups>0 and 8+math.min(4,#groups)*questHeight or 72)
    local base=2*inset+layoutHeader(f)+4+toggleHeight+4
    -- Keep one quest and one player usable at the smallest expanded size.
    local playerLimit=math.max(playerTop+playerHeight+playerBottom,f.heightLimit-base-questWanted-4)
    local playerWanted=selected and math.min(playerLimit,playerTop+#selected.players*playerHeight+playerBottom) or 0
    local wanted=base+questWanted+(selected and 4+playerWanted or 0)
    local minHeight=collapsed and (base+4) or (selected and 280 or 200)
    f:SetResizeBounds(360,minHeight,600,650)
    if not f.userSizing then f:SetHeight(math.max(minHeight,math.min(f.heightLimit,wanted))) end
    local available=f:GetHeight()-base
    f.QuestPane:SetHeight(math.max(58,available))
    f.expandedID=selected and selected.questID or nil
    f.expandedHeight=selected and math.min(playerWanted,math.max(playerTop+playerHeight+playerBottom,available-58)) or 0
    if selected then f.PlayersTitle:SetText(T("QUEST_BROWSER_PLAYERS",#selected.players)) end
    if collapsed then
        f.QuestList.items=groups
        for _,row in ipairs(f.QuestList.rows) do row.questID=nil;row:Hide() end
    else updateList(f.QuestList,groups) end
    if selected then updateList(f.PlayerList,selected.players) else f.PlayerList.items={};for _,row in ipairs(f.PlayerList.rows) do row.match=nil;row:Hide() end end
    f.rendering=false
end
function NS.SelectMatchedQuest(f,id)
    if not f or not f:IsShown() then return end
    if f.selectedID==id then f.selectedID=nil else f.selectedID=id end
    f.PlayerList.Viewport:SetVerticalScroll(0);NS.RenderQuestMatchesFrame(f,Q:Matches())
    if f.expandedID then
        -- Show the expanded block and its following quest when they fit together.
        local list=f.QuestList;local offset=list.Viewport:GetVerticalScroll();local visible=list.Viewport:GetHeight()
        for i,group in ipairs(list.items) do if group.questID==f.expandedID then
            local top=list.layout[i].top;local bottom=top+questHeight+2+f.expandedHeight
            if bottom-top>visible then bottom=top+questHeight+2+playerTop+playerHeight end
            local following=list.layout[i+1]
            if following and following.top+questHeight-2-top<=visible then bottom=following.top+questHeight-2 end
            if top<offset then list.Viewport:SetVerticalScroll(top)
            elseif bottom>offset+visible then list.Viewport:SetVerticalScroll(math.min(top,bottom-visible)) end
            break
        end end
    end
end
function NS.ToggleQuestList(f)
    if not f or not f:IsVisible() or f.rendering then return end
    GameTooltip:Hide();f.QuestToggle.pressed=false
    f.questsCollapsed=not f.questsCollapsed
    NS.RenderQuestMatchesFrame(f,Q:Matches())
end
function NS.CreateQuestMatchesFrame(name)
    local f=CreateFrame("Frame",name,UIParent);local s=settings();f.heightLimit=s.heightLimit
    f:SetSize(s.width,200);f:SetPoint("TOPLEFT",UIParent,"CENTER",s.left*UIParent:GetWidth(),s.top*UIParent:GetHeight())
    NS.QuestSurface(f,.045,.032,.021);f.Surface:ClearAllPoints();f.Surface:SetPoint("TOPLEFT",12,-12);f.Surface:SetPoint("BOTTOMRIGHT",-12,12)
    NS.ApplyQuestDialogBorder(f,24)
    f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
    local header=panel(f);f.Header=header;NS.TintQuestBorder(header,.52,.43,.28)
    header:SetPoint("TOPLEFT",inset,-inset);header:SetPoint("TOPRIGHT",-inset,-inset);header:SetHeight(headerHeight)
    f.Title=label(header,18,14,-6,-32,23);f.Title:SetText(T("QUEST_BROWSER_TITLE"));NS.QuestFont(f.Title,18,.99,.89,.56)
    f.Subtitle=label(header,11,14,-32,-32,16,true);f.Subtitle:SetText(T("QUEST_BROWSER_SUBTITLE"));NS.QuestFont(f.Subtitle,11,.91,.89,.82)
    f.Status=label(header,10,14,-51,-12,14,true);NS.QuestFont(f.Status,10,.84,.81,.72)
    for _,text in ipairs({f.Title,f.Subtitle,f.Status}) do text:SetWordWrap(true);text:SetMaxLines(2) end
    header:EnableMouse(true);header:RegisterForDrag("LeftButton");header:SetScript("OnDragStart",function() f:StartMoving() end)
    header:SetScript("OnDragStop",function() f:StopMovingOrSizing();anchorWindow(f);saveWindow(f) end)
    f.Close=CreateFrame("Button",nil,header,"UIPanelCloseButton");f.Close:SetSize(26,26);f.Close:SetPoint("TOPRIGHT",-2,-1);f.Close:SetScript("OnClick",function() f:Hide() end)
    local body=CreateFrame("Frame",nil,f);f.Body=body;body:SetPoint("TOPLEFT",inset,-inset-headerHeight-4);body:SetPoint("BOTTOMRIGHT",-inset,inset)
    local toggle=CreateFrame("Button",nil,body);f.QuestToggle=toggle;toggle:SetPoint("TOPLEFT",2,-2);toggle:SetPoint("TOPRIGHT",-2,-2);toggle:SetHeight(24)
    NS.QuestSurface(toggle,.055,.040,.026);NS.ApplyQuestBorder(toggle);NS.TintQuestBorder(toggle,.68,.56,.33)
    toggle.Icon=toggle:CreateTexture(nil,"ARTWORK");toggle.Icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up");toggle.Icon:SetSize(14,14);toggle.Icon:SetPoint("LEFT",9,0);toggle.Icon:SetVertexColor(.92,.77,.34,1)
    f.QuestsTitle=label(toggle,12,30,-4,-26,17)
    toggle.Arrow=toggle:CreateTexture(nil,"ARTWORK");toggle.Arrow:SetSize(18,16);toggle.Arrow:SetPoint("RIGHT",-5,0)
    toggle:RegisterForClicks("LeftButtonUp")
    toggle:SetScript("OnMouseDown",function(self) self.pressed=true;listToggleStyle(self) end)
    toggle:SetScript("OnMouseUp",function(self) self.pressed=false;listToggleStyle(self) end)
    toggle:SetScript("OnEnter",function(self)
        self.hovered=true;listToggleStyle(self);GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(T(self.collapsed and "QUEST_EXPAND_LIST" or "QUEST_COLLAPSE_LIST"));GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave",function(self) self.hovered=false;self.pressed=false;listToggleStyle(self);GameTooltip:Hide() end)
    toggle:SetScript("OnClick",function() NS.ToggleQuestList(f) end)
    f:SetScript("OnHide",function()
        toggle.hovered=false;toggle.pressed=false;listToggleStyle(toggle);GameTooltip:Hide()
    end)
    local questPane=panel(body);f.QuestPane=questPane;questPane:SetPoint("TOPLEFT",0,-toggleHeight-4);questPane:SetPoint("TOPRIGHT",0,-toggleHeight-4);questPane:SetHeight(58)
    f.QuestList=createList(questPane,"quests",f,4);f.QuestList.top=4
    f.Empty=label(questPane,11,12,-10,-12,58,true);f.Empty:SetWordWrap(true);f.Empty:SetMaxLines(5)
    local playerPane=CreateFrame("Frame",nil,f.QuestList.Content);f.PlayerPane=playerPane;NS.QuestParchment(playerPane)
    playerPane:SetHeight(playerTop+playerHeight+playerBottom)
    local branch=playerPane:CreateTexture(nil,"BACKGROUND");f.PlayerBranch=branch;branch:SetColorTexture(.75,.59,.29,1)
    branch:SetPoint("TOPLEFT",playerPane,"TOPLEFT",-9,2);branch:SetPoint("BOTTOMLEFT",playerPane,"BOTTOMLEFT",-9,0);branch:SetWidth(2)
    local strip=CreateFrame("Frame",nil,playerPane);f.PlayerStrip=strip;strip:SetPoint("TOPLEFT",0,0);strip:SetPoint("TOPRIGHT",0,0);strip:SetHeight(28)
    strip.Icon=strip:CreateTexture(nil,"ARTWORK");strip.Icon:SetAtlas("socialqueuing-icon-group",false);strip.Icon:SetSize(20,20);strip.Icon:SetPoint("LEFT",14,0);strip.Icon:SetVertexColor(.24,.16,.08,1)
    f.PlayersTitle=label(strip,11,40,-5,-12,19);NS.QuestFont(f.PlayersTitle,11,.13,.075,.027)
    f.PlayerList=createList(playerPane,"players",f,playerTop,playerBottom)
    f:SetResizable(true);local grip=CreateFrame("Button",nil,f);f.Grip=grip;grip:SetSize(12,12);grip:SetPoint("BOTTOMRIGHT",-4,3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown",function() f.userSizing=true;f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp",function() f:StopMovingOrSizing();anchorWindow(f);f.heightLimit=math.max(330,math.min(650,f:GetHeight()));f.userSizing=false;saveWindow(f);NS.UpdateQuestMatches() end)
    f:SetScript("OnSizeChanged",function() if f.items then NS.RenderQuestMatchesFrame(f,f.items) end end)
    f:Hide();if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end;return f
end
function NS.UpdateQuestMatches()
    local items=Q:Matches();if NS.QuestAttention then NS.QuestAttention:Update(items) end
    local f=NS.QuestMatchesWindow;if f and f:IsShown() then NS.RenderQuestMatchesFrame(f,items) end
    if NS.UpdateQuestLauncher then NS.UpdateQuestLauncher(items) end
end
function NS.OpenQuestMatches()
    if InCombatLockdown() then return end
    local obj=Q:Collect();if obj then Q.localState=obj;Q:MarkDirty() end;Q:Changed()
    if not NS.QuestMatchesWindow then NS.QuestMatchesWindow=NS.CreateQuestMatchesFrame("ForeverLFGQuestMatches") end
    NS.QuestMatchesWindow:Show();if NS.QuestAttention then NS.QuestAttention:Acknowledge() end;NS.UpdateQuestMatches()
end
