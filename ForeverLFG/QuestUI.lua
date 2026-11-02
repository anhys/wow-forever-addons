-- Classic-looking diagnostics and a separate shared-quest candidate list.
local _, NS = ...
local T,Q=NS.Text,NS.Quests
local history={}
NS.ChannelHistory=history
function NS.ChannelTabEntries(filter)
    if filter=="matches" then return Q:Matches() end
    local entries={}
    for i=#history,1,-1 do
        if filter=="all" or history[i].kind==filter then entries[#entries+1]=history[i] end
    end
    return entries
end
local function safe(value)
    return (tostring(value or ""):gsub("|","||"):gsub("[%z\1-\31]"," "))
end
local function title(id)
    local value=C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if type(value)=="string" and not (issecretvalue and issecretvalue(value)) then return safe(value) end
    return "#"..id
end
NS.QuestTitle,NS.QuestSafeText=title,safe
local function preview(value,depth,budget)
    depth=depth or 0
    budget=budget or {left=1000,nodes=0}
    budget.nodes=budget.nodes+1
    if budget.left<=0 or budget.nodes>80 then return "…" end
    if type(value)~="table" then
        local text=safe(value);local chars={}
        for char in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
            if #chars>=180 or budget.left<=0 then chars[#chars+1]="…";break end
            chars[#chars+1]=char
            budget.left=budget.left-1
        end
        return table.concat(chars)
    end
    if depth>=3 then return "{…}" end
    local keys,parts={},{}
    for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) if type(a)=="number" and type(b)=="number" then return a<b end;return tostring(a)<tostring(b) end)
    for i,key in ipairs(keys) do
        if i>20 then parts[#parts+1]="…";break end
        if budget.left<=0 or budget.nodes>80 then parts[#parts+1]="…";break end
        parts[#parts+1]=safe(key).."="..preview(value[key],depth+1,budget)
    end
    return "{"..table.concat(parts,", ").."}"
end
function NS.PrepareQuestWhisper(match)
    if InCombatLockdown() or not match or Q:IsSelf(match.sender) then return end
    match=Q:FindMatch(match.sender,match.questID)
    if not match then NS.UpdateQuestWindow();if NS.UpdateQuestMatches then NS.UpdateQuestMatches() end;return end
    local draft,details=NS.QuestWhisper(match.player.locale,match.questID)
    if NS.RecordDiagnostic then
        details.sender=match.sender;details.questID=match.questID;details.draft=draft
        NS.RecordDiagnostic("whisper.prepare",details)
    end
    if not draft then print("ForeverLFG: "..T("QUEST_WHISPER_TOO_LONG"));return end
    NS.OpenPrivateDraft(match.sender,draft)
end
function NS.InviteQuestMatch(match)
    if not match or InCombatLockdown() or not Q:CanRecruit() or Q:IsPartyMember(match.sender) then return end
    match=Q:FindMatch(match.sender,match.questID)
    if not match or match.player.group.size>0 then NS.UpdateQuestWindow();if NS.UpdateQuestMatches then NS.UpdateQuestMatches() end;return end
    local api=C_PartyInfo and C_PartyInfo.InviteUnit
    if api then pcall(api,match.sender) end
end
local function kind(typ)
    if typ==Q.TYPE or typ=="q" or typ:match("^quest%.") then return "quests" end
    if typ=="t" or typ=="p" or typ:match("^trade%.") then return "trade" end
    return "other"
end
function NS.RecordChannelMessage(direction,obj,meta)
    NS.ChannelRecording:Add(direction,obj,meta,kind(meta.type))
    if meta.type=="trade.chat" then
        -- The generic bus handles the full payload. Keep only a small diagnostic summary.
        local function scalar(value)
            if type(value)=="number" or (type(value)=="string" and #value<=128) then return value end
        end
        obj={batchID=scalar(obj.batchID),uniqueFactCount=scalar(obj.uniqueFactCount),messageCount=scalar(obj.messageCount),
            recordCount=scalar(obj.recordCount),recognizerVersion=scalar(obj.recognizerVersion)}
    end
    history[#history+1]={at=time(),direction=direction,kind=kind(meta.type),meta=meta,obj=obj}
    if #history>200 then table.remove(history,1) end
    NS.UpdateQuestWindow()
end
local function button(parent,label,width,point,relative,relativePoint,x,y,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24);b:SetPoint(point,relative,relativePoint,x,y);b:SetText(label);b:SetScript("OnClick",fn)
    return b
end
local function classic(name,width,height)
    local f=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    f:SetSize(width,height);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
    f:EnableMouse(true);f:SetMovable(true)
    local bar=CreateFrame("Frame",nil,f);bar:SetPoint("TOPLEFT",12,-8);bar:SetPoint("TOPRIGHT",-34,-8);bar:SetHeight(26)
    bar:EnableMouse(true);bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function() f:StartMoving() end);bar:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    f.Title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");f.Title:SetPoint("CENTER",bar,"CENTER",0,0)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5)
    close:SetScript("OnClick",function() f:Hide() end)
    f:Hide()
    return f
end
local function helpTip(widget,key,titleKey)
    widget:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(T(titleKey or "QUEST_SETTINGS_SECTION"));GameTooltip:AddLine(T(key),1,1,1,true);GameTooltip:Show() end)
    widget:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function NS.EnsureAddonSettings()
    if NS.AddonSettings or InCombatLockdown() or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel=CreateFrame("Frame","ForeverLFGAddonSettings")
    local header=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");header:SetPoint("TOPLEFT",20,-20);header:SetText("ForeverLFG")
    local section=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");section:SetPoint("TOPLEFT",20,-66)
    section:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-66);section:SetJustifyH("LEFT");section:SetText(T("QUEST_SETTINGS_SECTION"))
    NS.QuestFont(section,16);section:SetWordWrap(true);section:SetMaxLines(2)
    local divider=panel:CreateTexture(nil,"ARTWORK");divider:SetColorTexture(1,.82,0,.3)
    divider:SetPoint("TOPLEFT",20,-94);divider:SetPoint("TOPRIGHT",-24,-94);divider:SetHeight(1)
    local summary=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight");summary:SetPoint("TOPLEFT",20,-106)
    summary:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-106);summary:SetJustifyH("LEFT");summary:SetWordWrap(true);summary:SetMaxLines(3);summary:SetText(T("QUEST_SETTINGS_DESCRIPTION"));NS.QuestFont(summary,12,.91,.89,.82)
    local mode=CreateFrame("CheckButton","ForeverLFGQuestMinimapMode",panel,"UICheckButtonTemplate")
    mode:SetPoint("TOPLEFT",20,-164);mode.Text:SetText(T("QUEST_MINIMAP_MODE"));mode.Text:SetPoint("RIGHT",panel,"RIGHT",-24,0)
    mode.Text:SetJustifyH("LEFT");mode.Text:SetWordWrap(true)
    mode:SetScript("OnClick",function(self) NS.SetQuestLauncherMode(self:GetChecked()==true and "minimap" or "bar") end)
    helpTip(mode,"QUEST_MINIMAP_MODE_HINT","QUEST_MINIMAP_MODE")
    local animation=CreateFrame("CheckButton","ForeverLFGQuestMatchAnimation",panel,"UICheckButtonTemplate")
    animation:SetPoint("TOPLEFT",20,-164);animation.Text:SetText(T("QUEST_MATCH_ANIMATION"));animation.Text:SetPoint("RIGHT",panel,"RIGHT",-24,0)
    animation.Text:SetJustifyH("LEFT");animation.Text:SetWordWrap(true)
    animation:SetScript("OnClick",function(self) NS.SetQuestMatchAnimation(self:GetChecked()==true) end)
    helpTip(animation,"QUEST_MATCH_ANIMATION_HINT","QUEST_MATCH_ANIMATION")
    local sound=CreateFrame("CheckButton","ForeverLFGQuestMatchSound",panel,"UICheckButtonTemplate")
    sound:SetPoint("TOPLEFT",20,-208);sound.Text:SetText(T("QUEST_MATCH_SOUND"));sound.Text:SetPoint("RIGHT",panel,"RIGHT",-24,0)
    sound.Text:SetJustifyH("LEFT");sound.Text:SetWordWrap(true)
    sound:SetScript("OnClick",function(self) NS.SetQuestMatchSound(self:GetChecked()==true) end)
    helpTip(sound,"QUEST_MATCH_SOUND_HINT","QUEST_MATCH_SOUND")
    local sample=button(panel,T("QUEST_SOUND_PREVIEW"),200,"TOPLEFT",panel,"TOPLEFT",44,-250,function()
        if not NS.PlayQuestMatchSound() then print("ForeverLFG: "..T("QUEST_SOUND_UNAVAILABLE")) end
    end)
    helpTip(sample,"QUEST_SOUND_PREVIEW_HINT","QUEST_SOUND_PREVIEW")
    local animationSample=button(panel,T("QUEST_ANIMATION_PREVIEW"),200,"TOPLEFT",panel,"TOPLEFT",44,-284,function()
        NS.EnsureQuestLauncher()
        if not NS.PlayQuestAttention() then print("ForeverLFG: "..T("QUEST_ANIMATION_UNAVAILABLE")) end
    end)
    helpTip(animationSample,"QUEST_ANIMATION_PREVIEW_HINT","QUEST_ANIMATION_PREVIEW")
    local tutorial=button(panel,T("QUEST_TUTORIAL_REPLAY"),240,"TOPLEFT",panel,"TOPLEFT",44,-318,function() NS.OpenQuestTutorial() end)
    NS.QuestFont(tutorial:GetFontString(),13)
    local function layout()
        if panel:GetWidth()<=44 then return end
        local dividerTop=66+NS.QuestTextHeight(section,23)+8
        divider:ClearAllPoints();divider:SetPoint("TOPLEFT",20,-dividerTop);divider:SetPoint("TOPRIGHT",-24,-dividerTop)
        local summaryTop=dividerTop+12
        summary:ClearAllPoints();summary:SetPoint("TOPLEFT",20,-summaryTop);summary:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-24,-summaryTop)
        local controlsTop=summaryTop+NS.QuestTextHeight(summary,16)+16
        mode:ClearAllPoints();mode:SetPoint("TOPLEFT",20,-controlsTop)
        animation:ClearAllPoints();animation:SetPoint("TOPLEFT",20,-controlsTop-44)
        sound:ClearAllPoints();sound:SetPoint("TOPLEFT",20,-controlsTop-88)
        for _,check in ipairs({mode,animation,sound}) do
            check.Text:ClearAllPoints();check.Text:SetPoint("TOPLEFT",check,"TOPRIGHT",4,-4)
            check.Text:SetWidth(panel:GetWidth()-64);check.Text:SetMaxLines(2);NS.QuestTextHeight(check.Text,16)
        end
        sample:ClearAllPoints();sample:SetPoint("TOPLEFT",44,-controlsTop-130)
        animationSample:ClearAllPoints();animationSample:SetPoint("TOPLEFT",44,-controlsTop-164)
        tutorial:ClearAllPoints();tutorial:SetPoint("TOPLEFT",44,-controlsTop-208)
        tutorial:SetWidth(math.min(panel:GetWidth()-64,math.max(200,NS.QuestTextWidth(tutorial:GetFontString())+24)))
    end
    panel.OnRefresh=function()
        local s=NS.QuestAttentionSettings()
        mode:SetChecked(NS.QuestLauncherMode()=="minimap")
        animation:SetChecked(s.questMatchAnimation);sound:SetChecked(s.questMatchSound)
        layout()
    end
    panel.OnDefault=function() NS.SetQuestMatchAnimation(true);NS.SetQuestMatchSound(true);NS.SetQuestLauncherMode("minimap");panel.OnRefresh() end
    panel:SetScript("OnShow",function() panel.OnRefresh() end)
    panel:SetScript("OnSizeChanged",layout)
    local category=Settings.RegisterCanvasLayoutCategory(panel,"ForeverLFG")
    Settings.RegisterAddOnCategory(category)
    NS.AddonSettings,NS.AddonSettingsCategory,NS.AddonSettingsQuestSection=panel,category,section
    NS.AddonSettingsQuestDescription=summary
    NS.QuestMatchAnimationCheck,NS.QuestMatchSoundCheck,NS.QuestSoundPreview=animation,sound,sample
    NS.QuestAnimationPreview=animationSample
    NS.QuestMinimapModeCheck=mode
    NS.QuestTutorialReplay=tutorial
    panel.OnRefresh()
end
function NS.EnsureQuestWindow()
    if NS.QuestWindow then return NS.QuestWindow end
    local f=classic("ForeverLFGChannelWindow",800,470)
    NS.QuestWindow=f;f.filter="all";f.offset=0;f:SetResizable(true);f:SetResizeBounds(640,330,1200,900)
    f.Title:SetText(T("CHANNEL_TITLE"))
    local grip=CreateFrame("Button",nil,f);grip:SetSize(20,20);grip:SetPoint("BOTTOMRIGHT",-7,7)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown",function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp",function() f:StopMovingOrSizing();NS.UpdateQuestWindow() end)
    f.tabs={}
    for i,filter in ipairs({"all","quests","trade","matches"}) do
        local tab=button(f,T("CHANNEL_FILTER_"..filter:upper()),130,"TOPLEFT",f,"TOPLEFT",18+(i-1)*138,-42,
            function() f.filter=filter;f.offset=0;NS.UpdateQuestWindow() end)
        f.tabs[filter]=tab
    end
    f.Status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.Status:SetPoint("TOPLEFT",18,-77);f.Status:SetPoint("TOPRIGHT",-18,-77)
    f.Status:SetJustifyH("LEFT");f.Status:SetWordWrap(true)
    f.rows={}
    for i=1,30 do
        local row=CreateFrame("Frame",nil,f);row:SetHeight(44);row:SetPoint("TOPLEFT",18,-112-(i-1)*44);row:SetPoint("TOPRIGHT",-24,-112-(i-1)*44)
        row.Text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");row.Text:SetPoint("TOPLEFT");row.Text:SetPoint("BOTTOMRIGHT");row.Text:SetJustifyH("LEFT");row.Text:SetJustifyV("TOP");row.Text:SetWordWrap(true)
        row.Write=button(row,T("QUEST_WRITE"),98,"RIGHT",row,"RIGHT",-102,0,function()
            local match=row.match
            if not match or InCombatLockdown() then return end
            NS.PrepareQuestWhisper(match)
        end)
        row.Invite=button(row,T("QUEST_INVITE"),98,"RIGHT",row,"RIGHT",0,0,function()
            NS.InviteQuestMatch(row.match)
        end)
        row:Hide();row.Write:Hide();row.Invite:Hide()
        f.rows[i]=row
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta) f.offset=math.max(0,f.offset-delta*3);NS.UpdateQuestWindow() end)
    f:SetScript("OnSizeChanged",function() NS.UpdateQuestWindow() end)
    f:SetScript("OnShow",function() NS.UpdateQuestWindow() end)
    button(f,T("CHANNEL_CLEAR"),120,"BOTTOMLEFT",f,"BOTTOMLEFT",18,14,function() for i=#history,1,-1 do history[i]=nil end;f.offset=0;NS.UpdateQuestWindow() end)
    button(f,T("CHANNEL_NEWEST"),130,"BOTTOMLEFT",f,"BOTTOMLEFT",146,14,function() f.offset=0;NS.UpdateQuestWindow() end)
    f.Copy=button(f,T("CHANNEL_COPY"),190,"BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,14,function() NS.OpenChannelCopy(f.filter) end)
    f.RecordStart=button(f,T("RECORD_START"),180,"BOTTOMLEFT",f,"BOTTOMLEFT",18,48,function() NS.ChannelRecording:Start() end)
    f.RecordStop=button(f,T("RECORD_STOP"),110,"BOTTOMLEFT",f,"BOTTOMLEFT",206,48,function() NS.ChannelRecording:Stop() end)
    f.RecordCopy=button(f,T("RECORD_COPY"),220,"BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,48,function() NS.OpenChannelCopy("recording") end)
    f.RecordStatus=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.RecordStatus:SetPoint("BOTTOMLEFT",18,80);f.RecordStatus:SetPoint("BOTTOMRIGHT",-30,80)
    f.RecordStatus:SetJustifyH("LEFT");f.RecordStatus:SetWordWrap(true)
    NS.ChannelRecording:Refresh()
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ForeverLFGChannelWindow" end
    return f
end
function NS.UpdateQuestWindow()
    local f=NS.QuestWindow
    if not f or not f:IsShown() then return end
    local entries=NS.ChannelTabEntries(f.filter)
    local visible=math.max(1,math.min(#f.rows,math.floor((f:GetHeight()-242)/44)))
    f.offset=math.min(f.offset,math.max(0,#entries-visible))
    for filter,tab in pairs(f.tabs) do tab:SetEnabled(filter~=f.filter) end
    local status=Q.bus and Q.bus:GetStatus()
    local state=status and (status.ready and T("CHANNEL_READY") or T("CHANNEL_JOINING")) or T("CHANNEL_UNAVAILABLE")
    if Q.error then state=state.." - "..safe(Q.error) end
    if status and status.error then state=state.." - "..safe(status.error) end
    f.Status:SetText(state.." - "..T("CHANNEL_RECORDS",#entries).." - "..T("CHANNEL_SCROLL_HINT"))
    for i,row in ipairs(f.rows) do
        local entry
        if i<=visible then entry=entries[f.offset+i] end
        row:SetShown(entry~=nil);row.match=nil
        row.Write:Hide();row.Invite:Hide()
        if entry then
            row.Text:ClearAllPoints();row.Text:SetPoint("TOPLEFT")
            if f.filter=="matches" then
                row.match=entry;row.Write:Show();row.Invite:Show();row.Text:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-208,0)
                local p=entry.player
                local class=LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.class] or p.class
                local group=p.group.size>0 and T("QUEST_GROUP",p.group.size) or T("QUEST_SOLO")
                row.Text:SetText(safe(entry.sender).." - "..title(entry.questID).."\n"..T("QUEST_PLAYER",p.level,safe(class)).." - "..group)
                row.Write:SetEnabled(not InCombatLockdown());row.Invite:SetEnabled(not InCombatLockdown() and Q:CanRecruit() and p.group.size==0)
            else
                row.Write:Hide();row.Invite:Hide();row.Text:SetPoint("BOTTOMRIGHT")
                local m=entry.meta
                local direction=T(entry.direction=="sent" and "CHANNEL_SENT" or entry.direction=="received" and "CHANNEL_RECEIVED" or "CHANNEL_ERROR")
                local detail=m.state and (" - "..safe(m.state)) or ""
                if m.error and m.error.code then detail=detail.." - "..safe(m.error.code) end
                row.Text:SetText(date("%H:%M:%S",entry.at).." "..direction.." - "..safe(m.type).." - "..safe(m.sender or T("CHANNEL_SELF"))..detail.."\n"..preview(entry.obj))
            end
        end
    end
    if #entries==0 then
        local row=f.rows[1];row:Show();row.Write:Hide();row.Invite:Hide();row.Text:ClearAllPoints();row.Text:SetPoint("TOPLEFT");row.Text:SetPoint("BOTTOMRIGHT");row.Text:SetText(T(f.filter=="matches" and "QUEST_NO_MATCHES" or "CHANNEL_EMPTY"))
    end
end
function NS.OpenQuestWindow(filter)
    local f=NS.EnsureQuestWindow();f.filter=filter or "all";f.offset=0;f:Show();NS.UpdateQuestWindow()
end
