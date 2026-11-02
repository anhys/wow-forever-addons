local _,Root=...
local NS=Root.ChatReader or Root
local A=NS.Array
local C={};C.__index=C;NS.Collector=C
local clone=NS.Clone
function C.New(options)
    options=options or {}
    local channels=NS.Channels.New();channels:Refresh()
    return setmetatable({channels=channels,records=A(),nextID=0,maxRecords=options.maxRecords or 500,ttl=1800,
        clock=options.clock or time,intervalClock=options.intervalClock or GetTime or options.clock or time,dedupSeconds=10,
        session=options.session or (tostring(time()).."-"..tostring(math.floor(GetTime()*1000))),
        observer=options.observer or {},enabled={trade=true,trade_services=true,general=true,lfg=true,say=true,yell=true},
        stats={seen=0,accepted=0,facts=0,duplicates=0,coalesced=0,evicted=0,rejected={}},recent={},recentOrder={},messageIndex={},recordKeys={},paused=false},C)
end
function C:PruneRecent(interval)
    interval=interval or self.intervalClock()
    while self.recentOrder[1] and interval-self.recentOrder[1].at>=self.dedupSeconds do
        local old=table.remove(self.recentOrder,1);if self.recent[old.key]==old.at then self.recent[old.key]=nil end
    end
end
function C:Reject(reason)
    self.stats.rejected[reason]=(self.stats.rejected[reason] or 0)+1
    return nil,reason
end
function C.ChannelKind(name)
    return NS.Channels.NameHint(name)
end
function C:Source(event,fields)
    if event=="CHAT_MSG_SAY" then return {kind="say",event=event} elseif event=="CHAT_MSG_YELL" then return {kind="yell",event=event}
    elseif event=="CHAT_MSG_CHANNEL" then
        return self.channels:Resolve(fields)
    end
    return nil,"source_not_allowed"
end
local fieldNames={"text","senderName","languageName","channelName","senderName2","specialFlags","zoneChannelID","channelIndex","channelBaseName","languageID","lineID","senderGUID","bnSenderID","isMobile","isSubtitle","hideSenderInLetterbox","suppressRaidIcons"}
function C:Event(event,...)
    self.stats.seen=self.stats.seen+1
    if self.paused then return self:Reject("paused") end
    local fields={};local missing=A()
    for i,key in ipairs(fieldNames) do
        local v=select(i,...)
        if not NS.Readable(v) then
            if i==1 or i==2 then return self:Reject("restricted_payload") end
            missing[#missing+1]=key
        elseif type(v)=="string" or type(v)=="number" or type(v)=="boolean" then fields[key]=v end
    end
    local source,sourceError=self:Source(event,fields)
    if not source then return self:Reject(sourceError) end
    local kind=source.kind
    if not self.enabled[kind] then return self:Reject("source_disabled") end
    if type(fields.text)~="string" or fields.text=="" or type(fields.senderName)~="string" then return self:Reject("invalid_payload") end
    if #fields.text>8192 then return self:Reject("oversized_payload") end
    local now=self.clock();local interval=self.intervalClock()
    self:PruneRecent(interval)
    -- Ignore duplicate delivery first; genuine reposts are counted/coalesced by Accept.
    local key
    if type(fields.lineID)=="number" and fields.lineID>0 then
        key=event..":"..tostring(fields.lineID)..":"..(fields.channelName or kind)..":"..tostring(fields.channelIndex or 0)..":"..(fields.senderGUID or fields.senderName)..":"..fields.text
        if self.recent[key] and interval-self.recent[key]>=0 and interval-self.recent[key]<self.dedupSeconds then self.stats.duplicates=self.stats.duplicates+1;return nil,"duplicate" end
    end
    local record,why=self:Accept(source,fields,missing,"chat",now,interval)
    if record and key then
        self.recent[key]=interval;self.recentOrder[#self.recentOrder+1]={key=key,at=interval}
        while #self.recentOrder>1000 do
            local old=table.remove(self.recentOrder,1);if self.recent[old.key]==old.at then self.recent[old.key]=nil end
        end
    end
    return record,why
end
function C:Accept(source,fields,missing,origin,now,interval)
    local parsed,why=NS.Recognizer:Recognize(fields.text,fields.senderGUID)
    if not parsed then return self:Reject(why) end
    now=now or self.clock();origin=origin or "chat";interval=interval or self.intervalClock()
    local messageKey=NS.Data.MessageKey(source,fields,origin,parsed)
    local previous=self.messageIndex[messageKey]
    local repeated=previous and interval-previous.at>=0 and interval-previous.at<self.dedupSeconds
    local record=repeated and previous.record or nil
    if record then
        record.firstRaw=record.firstRaw or clone(record.raw)
        record.occurrences=record.occurrences+1;self.stats.coalesced=self.stats.coalesced+1
        self.stats.facts=self.stats.facts+#parsed.facts-#record.recognition.facts
    else
        self.nextID=self.nextID+1
        record={schemaVersion=1,id=self.session..":"..self.nextID,origin=origin,observer=clone(self.observer),firstSeen=now,occurrences=1}
        self.records[#self.records+1]=record;self.recordKeys[record.id]=messageKey
        self.stats.accepted=self.stats.accepted+1;self.stats.facts=self.stats.facts+#parsed.facts
    end
    record.observedAt=now;record.lastSeen=now;record.source=clone(source);record.raw=clone(fields)
    record.unavailableFields=missing or A();record.recognition=parsed
    self.messageIndex[messageKey]={record=record,at=interval}
    for i,f in ipairs(parsed.facts) do
        f.id=record.id..":"..i;f.observationID=record.id;f.actor={name=fields.senderName,guid=fields.senderGUID};f.observedAt=record.observedAt
        f.origin=record.origin;f.source=clone(source)
    end
    while #self.records>self.maxRecords do
        local old=table.remove(self.records,1);local oldKey=self.recordKeys[old.id]
        if self.messageIndex[oldKey] and self.messageIndex[oldKey].record==old then self.messageIndex[oldKey]=nil end
        self.recordKeys[old.id]=nil;self.stats.evicted=self.stats.evicted+1
    end
    local change=repeated and "repeat" or "new"
    if self.OnRecord then pcall(self.OnRecord,clone(record),change) end
    return clone(record),change
end
function C:Test(text)
    if type(text)~="string" or #text>8192 or text=="" then return nil,"invalid_test" end
    return self:Accept({event="TEST",kind="test"},{text=text,senderName="Diagnostic Example"},A(),"test",self.clock())
end
function C:GetRecords(category,source)
    local out=A()
    for _,r in ipairs(self.records) do
        local keep=not category
        for _,f in ipairs(r.recognition.facts) do if f.category==category then keep=true end end
        if keep and (not source or r.source.kind==source) then out[#out+1]=clone(r) end
    end
    return out
end
function C:GetData(options)
    options=options or {}
    self:PruneRecent()
    assert(not options.drain or (not options.category and not options.source and not options.maxAge and not options.includeTests),"drain does not support filters")
    assert(options.maxRecords==nil or (type(options.maxRecords)=="number" and options.maxRecords>=1 and options.maxRecords%1==0),"invalid maxRecords")
    -- Build the independent snapshot first. Errors cannot erase the source queue.
    assert(options.maxBytes==nil or (type(options.maxBytes)=="number" and options.maxBytes>=1024),"invalid maxBytes")
    local count=math.min(#self.records,options.maxRecords or #self.records)
    local data=NS.Data.Unique(self,options)
    -- A logical batch is bounded before drain; leave the tail for a later caller.
    -- JSON's escaped representation is a conservative budget, not the wire format.
    while options.maxBytes and count>1 and #NS.JSON(data)>options.maxBytes do
        count=math.max(1,math.floor(count/2))
        local limited={};for k,v in pairs(options) do limited[k]=v end;limited.maxRecords=count
        data=NS.Data.Unique(self,limited)
    end
    if options.drain then
        for _=1,count do
            local old=table.remove(self.records,1);local key=self.recordKeys[old.id]
            if self.messageIndex[key] and self.messageIndex[key].record==old then self.messageIndex[key]=nil end
            self.recordKeys[old.id]=nil
        end
        -- Delivery dedupe holds no records, only bounded strings/times for 10 seconds.
        data.scope="drained_records"
    end
    return data
end
function C:Snapshot()
    local now=self.clock();local byCategory,profiles,adverts={},A(),A();local profileIndex={}
    for _,r in ipairs(self.records) do for _,f in ipairs(r.recognition.facts) do
        local bucket=byCategory[f.category] or A();byCategory[f.category]=bucket;bucket[#bucket+1]=clone(f)
        -- Separate views of recent claims. Never used as a verified recipe book or active order.
        if r.origin=="chat" and now-(r.lastSeen or r.observedAt)<=self.ttl then
            local owner,profKeys,proof
            if f.professionLink then owner=f.professionLink.ownerGUID;profKeys=f.professionLink.professions;proof="linked_owner"
            elseif f.category=="craft.offer" then owner=f.actor.guid or f.actor.name;profKeys=f.subject.professions;proof="advertised_only" end
            if owner then for _,p in ipairs(profKeys or {}) do
                local key=owner..":"..p.key;local profile=profileIndex[key]
                if not profile then
                    profile={owner=owner,profession=p.key,proofs=A(),firstSeen=r.firstSeen or r.observedAt,lastSeen=r.lastSeen or r.observedAt};profileIndex[key]=profile;profiles[#profiles+1]=profile
                end
                profile.firstSeen=math.min(profile.firstSeen,r.firstSeen or r.observedAt)
                profile.lastSeen=math.max(profile.lastSeen,r.lastSeen or r.observedAt)
                profile.proofs[#profile.proofs+1]={factID=f.id,kind=proof,sender=f.actor.name}
            end end
        end
    end end
    for category,entries in pairs(self:GetData({maxAge=self.ttl,separateSources=true}).byCategory) do
        if category~="profession.link" then for _,entry in ipairs(entries) do
            adverts[#adverts+1]={category=category,firstSeen=entry.firstSeen,lastSeen=entry.lastSeen,repeats=entry.messageCount,
                factIDs=entry.factIDs,latest=entry.fact,status="observed_unconfirmed"}
        end end
    end
    table.sort(adverts,function(a,b) if a.firstSeen==b.firstSeen then return a.latest.id<b.latest.id end return a.firstSeen<b.firstSeen end)
    return {schemaVersion=1,addonVersion=NS.version,recognizerVersion=NS.Recognizer.version,exportedAt=now,session=self.session,
        stats=clone(self.stats),records=self:GetRecords(),byCategory=byCategory,professionObservations=profiles,recentAdverts=adverts,channels=self:Inventory(),
        enabledSources=clone(self.enabled),paused=self.paused,
        limits={maxRecords=self.maxRecords,recentSeconds=self.ttl,dedupSeconds=self.dedupSeconds,unknownMessagesStored=false,networkEnabled=false}}
end
function C:Clear()
    self.records=A();self.recent={};self.recentOrder={};self.messageIndex={};self.recordKeys={}
    self.stats={seen=0,accepted=0,facts=0,duplicates=0,coalesced=0,evicted=0,rejected={}}
end
function C.Inventory(self)
    local channels=self and self.channels or NS.Channels.New()
    return clone(channels:Refresh())
end
function C:JoinAvailable()
    local requested=self.channels:JoinAvailable(self.enabled)
    self.lastJoinRequest=requested;return clone(requested)
end
