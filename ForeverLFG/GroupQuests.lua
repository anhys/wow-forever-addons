-- Local group/raid quest matches. Never publish or insert synthetic bus peers.
local _,NS=...
local Q=NS.Quests
local G={entries={},nextScan=0,retryUntil=0,TTL=30}
NS.GroupQuests=G
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if not ok or (issecretvalue and (issecretvalue(a) or issecretvalue(b))) then return end
    return a,b
end
local function text(value,max)
    return type(value)=="string" and not (issecretvalue and issecretvalue(value))
        and value~="" and #value<=max and not value:find("[%z\1-\31|]")
end
local function number(value,lo,hi)
    return type(value)=="number" and not (issecretvalue and issecretvalue(value))
        and value==math.floor(value) and value>=lo and value<=hi
end
local function roster()
    local count=read(GetNumGroupMembers)
    if not number(count,0,40) then return end
    if count==0 then return {},"solo" end
    local raid=read(IsInRaid)
    local own=read(UnitGUID,"player")
    if type(raid)~="boolean" or not text(own,128) then return end
    local members,parts={},{own,tostring(count),tostring(raid)}
    for i=1,(raid and count or math.min(4,count-1)) do
        local unit=(raid and "raid" or "party")..i
        local guid=read(UnitGUID,unit)
        parts[#parts+1]=unit..":"..(text(guid,128) and guid or "?")
        if text(guid,128) and guid~=own and read(UnitExists,unit)==true and read(UnitIsConnected,unit)==true then
            local name=Q:GetUnitName(unit)
            local level=read(UnitLevel,unit)
            local _,class=read(UnitClass,unit)
            if name and number(level,1,255) and text(class,32) then
                local map=read(C_Map and C_Map.GetBestMapForUnit,unit)
                members[guid]={unit=unit,guid=guid,sender=name,player={level=level,class=class,locale="",
                    map=number(map,1,2147483647) and map or 0,
                    group={size=count,raid=raid,leader=read(UnitIsGroupLeader,unit)==true}}}
            end
        end
    end
    return members,table.concat(parts,"\31")
end
function G:Schedule()
    local now=GetTime()
    self.nextScan=math.min(self.nextScan or now+.5,now+.5)
    self.retryUntil=now+8
end
function G:Commit(entries,obj)
    local parts={obj and table.concat(obj.quests,",") or "unavailable"}
    for _,match in ipairs(entries) do
        local p=match.player
        parts[#parts+1]=table.concat({match.questID,match.guid,match.sender,p.level,p.class,p.map,p.group.size,tostring(p.group.raid)},"\31")
    end
    local signature=table.concat(parts,"\30")
    self.entries=entries
    if obj then Q.localState=obj end
    -- A live scan also refreshes attention's seen timestamps while the bus is unavailable.
    if signature~=self.signature or obj then self.signature=signature;Q:Changed() end
end
function G:Scan()
    local api=C_QuestLog and C_QuestLog.IsUnitOnQuest
    local members,stamp=roster()
    if not members or not next(members) or type(api)~="function" then self:Commit({});return end
    local obj=Q:Collect()
    if not obj then self:Commit({});return end
    local entries={}
    for guid,member in pairs(members) do
        for _,id in ipairs(obj.quests) do
            -- Only a literal, public true is evidence. A reused unit must not inherit it.
            if read(api,member.unit,id)==true and read(UnitGUID,member.unit)==guid then
                entries[#entries+1]={source="group",guid=guid,sender=member.sender,questID=id,
                    player=member.player,expires=GetTime()+self.TTL}
            end
        end
    end
    local _,current=roster()
    if stamp~=current then self:Commit({});self:Schedule();return end
    table.sort(entries,function(a,b) if a.questID==b.questID then return a.sender<b.sender end;return a.questID<b.questID end)
    self:Commit(entries,obj)
end
function G:AppendMatches(result,active)
    if #self.entries==0 then return end
    local members=roster()
    if not members then return end
    local seen={}
    for _,match in ipairs(result) do seen[match.questID.."\31"..match.sender:lower()]=true end
    for _,match in ipairs(self.entries) do
        local member=members[match.guid]
        local key=match.questID.."\31"..match.sender:lower()
        if active[match.questID] and match.expires>GetTime() and member and member.sender==match.sender and not seen[key] then
            result[#result+1]=match;seen[key]=true
        end
    end
end
function G:Validate(match)
    local members,stamp=roster()
    local member=members and members[match.guid]
    if not member or member.sender~=match.sender then return false end
    local onQuest=read(C_QuestLog and C_QuestLog.IsUnitOnQuest,member.unit,match.questID)
    local _,current=roster()
    local valid=onQuest==true and read(UnitGUID,member.unit)==match.guid and stamp==current
    if not valid then
        for i=#self.entries,1,-1 do
            local entry=self.entries[i]
            if entry.guid==match.guid and entry.questID==match.questID then table.remove(self.entries,i) end
        end
        self:Schedule()
    end
    return valid
end
local frame=CreateFrame("Frame");G.frame=frame
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","GROUP_JOINED","GROUP_LEFT",
    "QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","UNIT_QUEST_LOG_CHANGED",
    "UNIT_NAME_UPDATE","UNIT_CONNECTION","UNIT_LEVEL","ZONE_CHANGED_NEW_AREA"}) do
    pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript("OnEvent",function(_,event,unit)
    if event:sub(1,5)=="UNIT_" and (not text(unit,32)
        or (unit~="player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$"))) then return end
    G:Schedule()
    -- Remove departed/disconnected/replaced units immediately, before the delayed scan.
    if event=="GROUP_ROSTER_UPDATE" or event=="GROUP_LEFT" or event=="UNIT_CONNECTION" then Q:Changed() end
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta;if elapsed<.25 then return end;elapsed=0
    if not Q.loaded or (IsLoggedIn and not IsLoggedIn()) then return end
    if GetTime()>=G.nextScan then
        G.nextScan=GetTime()+(GetTime()<G.retryUntil and 2 or 15)
        G:Scan()
    end
    -- The existing bus loop normally ticks attention; keep local matches independent of bus startup.
    if not Q.bus and NS.QuestAttention then NS.QuestAttention:Tick() end
end)
