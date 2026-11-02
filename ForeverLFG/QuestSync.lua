-- ForeverLFG: automatic shared quest snapshots over the embedded ChannelBus.
local addonName, NS = ...
local Q = {peers={},revision=0,dirtyAt=nil,nextHeartbeat=0,nextSend=0,loaded=false}
NS.Quests = Q
Q.TYPE, Q.VERSION, Q.TTL = "flfg.q", 1, 180
local function now() return GetTime() end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function integer(v,lo,hi)
    return not secret(v) and type(v)=="number" and v==math.floor(v) and v>=lo and v<=hi
end
local function text(v,max)
    return not secret(v) and type(v)=="string" and #v<=max and not v:find("[%z\1-\31|]")
end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if not ok or secret(a) or secret(b) or secret(c) then return nil end
    return a,b,c
end
local function ownName(unit)
    -- Camelot's unit-name results are first name and surname, not realm.
    local unmodified=type(UnitNameUnmodified)=="function"
    local read=unmodified and UnitNameUnmodified or UnitName
    local name,surname=call(read,unit or "player")
    if not text(name,128) or name=="" then return end
    if surname~=nil and not text(surname,128) then return end
    local constants=Constants and Constants.CharacterNameSeparatorConsts
    local separator=constants and constants.CHARACTERNAME_SURNAME_SEPARATOR
    if surname and surname~="" then
        if not text(separator,16) or separator=="" then return end
        local suffix=separator..surname
        -- UnitName may already supply a full name; prefer unmodified parts.
        if name:sub(-#suffix)~=suffix then name=name..suffix end
    elseif call(RegionalUniqueNamesEnabled)==true then
        if unmodified or not text(separator,16) or separator=="" or not name:find(separator,1,true) then return end
    end
    return text(name,160) and name or nil
end
local function sameName(sender,name)
    if not name then return false end
    if sender:lower()==name:lower() then return true end
    -- Recognize only our actual realm suffix, preserving surname hyphens.
    local realm=call(GetRealmName)
    return text(realm,128) and realm~="" and (sender:lower()==(name.."-"..realm):lower()
        or sender:lower()==(name.."-"..realm:gsub(" ","")):lower())
end
function Q:GetUnitName(unit) return ownName(unit) end
function Q:DebugAll()
    return NS.Filters.Settings().questDebugAll==true
end
function Q:SetDebugAll(enabled)
    local settings=NS.Filters.Settings()
    if settings.questDebugAll==(enabled==true) then return end
    settings.questDebugAll=enabled==true
    -- Rebuild local matches immediately; the outgoing snapshot keeps its throttle.
    local obj,err=self:Collect()
    self.localState=obj;self.error=err
    self:MarkDirty();self:Changed()
    if NS.GroupQuests then NS.GroupQuests:Schedule() end
end
function Q:IsSelf(sender)
    local own=ownName()
    -- Until local identity is ready, we cannot safely rule out self.
    return not own or not text(sender,160) or sender=="" or sameName(sender,own)
end
function Q:IsPartyMember(sender)
    if self:IsSelf(sender) then return true end
    local count=call(GetNumGroupMembers)
    if not integer(count,0,40) then return true end
    local raid=call(IsInRaid)==true
    for i=1,count do
        local name=ownName((raid and "raid" or "party")..i)
        if sameName(sender,name) then return true end
    end
    return false
end
function Q:CanRecruit()
    local count=call(GetNumGroupMembers)
    if not integer(count,0,40) then return false end
    return count==0 or (count<5 and call(IsInRaid)~=true and call(UnitIsGroupLeader,"player")==true)
end
function Q:Collect()
    if not ownName() then return nil,"player-name-unavailable" end
    local api=C_QuestLog
    if not api or not api.GetNumQuestLogEntries or not api.GetInfo or not api.IsComplete then return nil,"quest-api-unavailable" end
    local count=call(api.GetNumQuestLogEntries)
    if not integer(count,0,1000) then return nil,"quest-log-unavailable" end
    local quests,seen={},{}
    local debugAll=self:DebugAll()
    for i=1,count do
        local info=call(api.GetInfo,i)
        if type(info)~="table" or secret(info) then return nil,"quest-log-loading" end
        if not secret(info.isHeader) and not secret(info.isHidden) and not info.isHeader and not info.isHidden then
            local id,suggested=info.questID,info.suggestedGroup
            if integer(id,1,2147483647) then
                local eligible=debugAll
                if not eligible then
                    local tag=call(api.GetQuestTagInfo,id)
                    local tagID=type(tag)=="table" and not secret(tag) and tag.tagID or nil
                    if secret(tagID) then tagID=nil end
                    local tags=Enum and Enum.QuestTag or {}
                    local raid=(type(tags.Raid)=="number" and tagID==tags.Raid) or (type(tags.Raid10)=="number" and tagID==tags.Raid10) or (type(tags.Raid25)=="number" and tagID==tags.Raid25)
                    local elite=call(api.IsEliteQuest,id)==true or (type(tag)=="table" and not secret(tag) and not secret(tag.isElite) and tag.isElite==true)
                    eligible=not raid and ((type(tags.Group)=="number" and tagID==tags.Group) or integer(suggested,2,40) or elite)
                end
                if eligible then
                    local complete=call(api.IsComplete,id)
                    if type(complete)~="boolean" then return nil,"quest-completion-unavailable" end
                    if not complete and not seen[id] then
                        if #quests>=64 then return nil,"quest-count-limit" end
                        quests[#quests+1]=id;seen[id]=true
                    end
                end
            end
        end
    end
    table.sort(quests)
    local map=call(C_Map and C_Map.GetBestMapForUnit,"player")
    local level=call(UnitLevel,"player")
    local _,class=call(UnitClass,"player")
    local faction=call(UnitFactionGroup,"player")
    local region=call(GetCurrentRegionName)
    local realm=call(GetRealmName)
    local groupSize=call(GetNumGroupMembers)
    if not integer(map,1,2147483647) or not integer(level,1,255) or not text(class,32) or class=="" or not integer(groupSize,0,40) then return nil,"player-data-unavailable" end
    return {quests=quests,map=map,level=level,class=class,locale=GetLocale(),
        faction=text(faction,16) and faction or "",region=text(region,32) and region or "",
        realm=text(realm,128) and realm or "",project=integer(WOW_PROJECT_ID,0,1000) and WOW_PROJECT_ID or 0,
        group={size=integer(groupSize,0,40) and groupSize or 0,leader=groupSize==0 or call(UnitIsGroupLeader,"player")==true,raid=call(IsInRaid)==true},enabled=true}
end
function Q:Valid(obj)
    if type(obj)~="table" or type(obj.quests)~="table" or type(obj.group)~="table" then return false end
    local n=0;for k in pairs(obj.quests) do if not integer(k,1,64) then return false end;n=n+1 end
    local previous=0
    for i=1,n do local id=obj.quests[i];if not integer(id,1,2147483647) or id<=previous then return false end;previous=id end
    if not integer(obj.map,1,2147483647) or not integer(obj.level,1,255) or not integer(obj.project,0,1000)
        or not integer(obj.at,0,2147483647) or type(obj.enabled)~="boolean"
        or not text(obj.class,32) or obj.class=="" or not text(obj.locale,8)
        or not text(obj.faction,16) or not text(obj.region,32) or not text(obj.realm,128)
        or not integer(obj.group.size,0,40) or type(obj.group.leader)~="boolean" or type(obj.group.raid)~="boolean" then return false end
    return true
end
function Q:Compatible(obj)
    local localState=self.localState
    if not localState then return false end
    -- Region, realm and project are metadata; they do not restrict quest matches.
    return obj.faction~="" and localState.faction~="" and obj.faction==localState.faction
end
local function mapInfo(id,cache)
    if cache.maps[id]==nil then
        local info=call(C_Map and C_Map.GetMapInfo,id)
        cache.maps[id]=type(info)=="table" and not secret(info) and info or false
    end
    return cache.maps[id]
end
local function insideMap(id,destination,cache)
    local answers=cache.inside[destination]
    if not answers then answers={};cache.inside[destination]=answers end
    if answers[id]~=nil then return answers[id] end
    local current,seen=id,{}
    for _=1,64 do
        if current==destination then answers[id]=true;return true end
        if seen[current] then break end
        seen[current]=true
        local info=mapInfo(current,cache)
        local parent=info and info.parentMapID
        if not integer(parent,1,2147483647) then break end
        current=parent
    end
    answers[id]=false;return false
end
function Q:InQuestLocation(id,first,second,cache)
    if not integer(id,1,2147483647) or not integer(first,1,2147483647) or not integer(second,1,2147483647) then return false end
    -- Cache only within one refresh: unavailable data must recover on the next call.
    cache=cache or {quests={},maps={},inside={}}
    if cache.quests[id]==nil then
        local destination=call(GetQuestUiMapID,id,true) -- Destination, never a travel waypoint.
        local info=integer(destination,1,2147483647) and mapInfo(destination,cache)
        local kind=info and info.mapType
        local types=Enum and Enum.UIMapType or {}
        -- A continent/world cannot establish a quest location.
        local specific=not secret(kind) and type(kind)=="number" and
            (kind==types.Zone or kind==types.Dungeon or kind==types.Micro or kind==types.Orphan)
        cache.quests[id]=specific and destination or false
    end
    local destination=cache.quests[id]
    return destination~=false and insideMap(first,destination,cache) and insideMap(second,destination,cache)
end
function Q:Matches()
    local result,ids={},{}
    if not self.localState then return result end
    local map=call(C_Map and C_Map.GetBestMapForUnit,"player")
    local groupKnown=integer(call(GetNumGroupMembers),0,40)
    local cache={quests={},maps={},inside={}}
    for _,id in ipairs(self.localState.quests) do ids[id]=true end
    for sender,peer in pairs(self.peers) do
        local obj=peer.obj
        local inGroup=groupKnown and self:IsPartyMember(sender)
        if peer.expires>now() and self:Compatible(obj) and groupKnown and not self:IsSelf(sender)
            and (inGroup or (not obj.group.raid and obj.group.size<5 and (obj.group.size==0 or obj.group.leader))) then
            for _,id in ipairs(obj.quests) do
                if ids[id] and self:InQuestLocation(id,map,obj.map,cache) then
                    result[#result+1]={sender=sender,questID=id,player=obj,sync=peer.sync or 0}
                end
            end
        end
    end
    if NS.GroupQuests then NS.GroupQuests:AppendMatches(result,ids) end
    table.sort(result,function(a,b) if a.questID==b.questID then return a.sender<b.sender end;return a.questID<b.questID end)
    return result
end
function Q:Changed()
    if NS.EnsureQuestLauncher then NS.EnsureQuestLauncher() end
    if NS.UpdateQuestMatches then NS.UpdateQuestMatches() end
    if NS.UpdateQuestWindow then NS.UpdateQuestWindow() end
end
function Q:FindMatch(sender,id)
    local obj=self:Collect()
    if not obj then return end
    self.localState=obj;self:MarkDirty()
    for _,match in ipairs(self:Matches()) do
        if match.sender==sender and match.questID==id then
            if match.source~="group" or NS.GroupQuests:Validate(match) then return match end
        end
    end
end
function Q:Receive(obj,meta)
    if not self:Valid(obj) or not text(meta.sender,160) or meta.sender=="" or self:IsSelf(meta.sender) then return end
    local server=call(GetServerTime)
    if not integer(server,0,2147483647) or obj.at>server+30 or obj.at+self.TTL<=server then return end
    local old=self.peers[meta.sender]
    if old and old.obj.at>obj.at then return end
    if not obj.enabled then self.peers[meta.sender]=nil;self:Changed();return end
    local count,oldest,oldestAt=0,nil,math.huge
    for name,p in pairs(self.peers) do count=count+1;if p.received<oldestAt then oldest,oldestAt=name,p.received end end
    if not old and count>=200 then self.peers[oldest]=nil end
    self.receiveCycle=(self.receiveCycle or 0)+1
    self.peers[meta.sender]={obj=obj,sync=self.receiveCycle,received=now(),expires=math.min(meta.expiresAt,now()+self.TTL,now()+obj.at+self.TTL-server)}
    self:Changed()
end
function Q:MarkDirty()
    if not self.dirtyAt then self.dirtyAt=now()+2 end
end
function Q:RetryPublication(attempt,reason)
    -- A superseded packet may finish after a newer snapshot was queued.
    if self.outgoing~=attempt or attempt.finished then return end
    attempt.finished=true
    self.error=reason or "publish-failed"
    self.retryPublish=true
    self.dirtyAt=now()+10;self.nextSend=now()+10
    if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.retry",{reason=self.error,revision=self.revision,retrySeconds=10}) end
end
function Q:CheckPublication()
    local attempt=self.outgoing
    if not attempt or attempt.finished or not attempt.ticket then return end
    local status=attempt.ticket:GetStatus()
    if attempt.lastStatus~=status.state then
        attempt.lastStatus=status.state
        if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.ticket",{state=status.state,reason=status.reason,revision=self.revision}) end
    end
    if status.state=="submitted" or status.state=="submitted-unconfirmed" or status.state=="duplicate-known" then
        attempt.finished=true
    elseif status.state=="failed" or status.state=="expired" or status.state=="cancelled" or status.state=="superseded" then
        self:RetryPublication(attempt,status.reason or status.state)
    end
end
function Q:Publish(obj,reason)
    if not self.bus then return end
    obj.at=call(GetServerTime)
    if not integer(obj.at,0,2147483647) then
        self.error="server-time-unavailable";self.dirtyAt=now()+5;self.nextSend=now()+5
        if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.collect-error",{reason=self.error,retrySeconds=5}) end
        return
    end
    local attempt={finished=false,lastStatus="queued"}
    self.outgoing=attempt
    self.revision=self.revision+1
    local ticket,err=self.bus:Publish(self.TYPE,obj,{ver=self.VERSION,ttl=self.TTL,priority=2,key="quests",revision=self.revision,
        delayMin=0,delayMax=1,onError=function(problem)
            Q:RetryPublication(attempt,problem.code)
        end})
    if not ticket then self:RetryPublication(attempt,err and err.code);return end
    attempt.ticket=ticket
    self.ticket=ticket;self.error=nil;self.retryPublish=false;self.nextSend=now()+10
    -- Empty snapshots only announce startup or clear a previously nonempty state.
    -- Failed/cancelled tickets still rearm retry independently from this timer.
    self.nextHeartbeat=#obj.quests>0 and now()+math.random(55,65) or math.huge
    self.lastPublished=obj
    if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.publish",{reason=reason or "direct",revision=self.revision,
        quests=obj.quests,heartbeat=#obj.quests>0,minIntervalSeconds=10}) end
    return true
end
function Q:Start()
    if self.bus then return true end
    local ok,bus=pcall(function() return ChannelBus:Init() end)
    if not ok then self.error="channelbus-init-failed";return end
    self.bus=bus
    self.nextHeartbeat=now()+60
    bus:On(self.TYPE,"ForeverLFG.quests",function(obj,meta) Q:Receive(obj,meta) end,self.VERSION)
    bus:Observe("ForeverLFG.monitor",function(direction,obj,meta)
        if NS.RecordChannelMessage then NS.RecordChannelMessage(direction,obj,meta) end
    end)
    self:MarkDirty()
    return true
end
function Q:Tick()
    if not self.loaded or (IsLoggedIn and not IsLoggedIn()) then return end
    if not NS.AddonSettings and NS.EnsureAddonSettings then NS.EnsureAddonSettings() end
    if NS.EnsureQuestLauncher then NS.EnsureQuestLauncher() end
    if not self.bus and not self:Start() then return end
    self:CheckPublication()
    local changed=false
    for sender,p in pairs(self.peers) do if p.expires<=now() then self.peers[sender]=nil;changed=true end end
    if changed then self:Changed() end
    if NS.QuestAttention then NS.QuestAttention:Tick() end
    local pending=self.outgoing and not self.outgoing.finished
    local heartbeat=not pending and self.nextHeartbeat<=now()
    local due=(self.dirtyAt and self.dirtyAt<=now()) or heartbeat
    if not due or now()<self.nextSend then return end
    local obj,err=self:Collect()
    if not obj then
        self.error=err;self.dirtyAt=now()+5;self.nextSend=now()+5
        if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.collect-error",{reason=err,retrySeconds=5}) end
        return
    end
    self.localState=obj;self.error=nil
    local _,signature=ChannelBus.Copy(obj)
    local empty=#obj.quests==0
    local wasEmpty=self.lastPublished and #self.lastPublished.quests==0
    local publish=self.retryPublish or not self.lastPublished
        or (empty and not wasEmpty)
        or (not empty and (signature~=self.lastSignature or heartbeat))
    if publish then
        local reason=self.retryPublish and "retry" or not self.lastPublished and "initial"
            or empty and "clear" or signature~=self.lastSignature and "changed" or "heartbeat"
        if self:Publish(obj,reason) then self.lastSignature=signature;self.dirtyAt=nil end
    else
        self.dirtyAt=nil
        if empty then self.nextHeartbeat=math.huge end
        if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.suppressed",{reason=empty and "empty" or "unchanged",quests=obj.quests}) end
    end
    self:Changed()
end
local frame=CreateFrame("Frame")
Q.frame=frame
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","ZONE_CHANGED_INDOORS","GROUP_ROSTER_UPDATE","PLAYER_LEVEL_UP","UNIT_NAME_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do
    pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        if name==addonName then
            Q.loaded=true
            local settings=NS.Database().settings
            settings.questExchange=nil -- Retired preference must not stop exchange.
            if NS.EnsureAddonSettings then NS.EnsureAddonSettings() end
        elseif name=="Blizzard_Settings" and NS.EnsureAddonSettings then NS.EnsureAddonSettings() end
        return
    end
    if event=="UNIT_NAME_UPDATE" and name~="player" then return end
    if event=="PLAYER_REGEN_DISABLED" then if NS.UpdateQuestWindow then NS.UpdateQuestWindow() end;if NS.UpdateQuestMatches then NS.UpdateQuestMatches() end;return end
    if event=="PLAYER_REGEN_ENABLED" then Q:Changed();return end
    if event=="PLAYER_LOGIN" then Q:Start();if NS.EnsureAddonSettings then NS.EnsureAddonSettings() end end
    if NS.RecordDiagnostic then NS.RecordDiagnostic("quest.event",{event=event,arg=name}) end
    Q:MarkDirty()
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,delta) elapsed=elapsed+delta;if elapsed>=.25 then elapsed=0;Q:Tick() end end)
