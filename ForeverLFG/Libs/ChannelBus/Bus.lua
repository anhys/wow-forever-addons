-- Copyright (c) 2026 WerkoDev. All rights reserved.
local Net=_G.ChannelBus
if not Net.loading then return end
local Bus,Codec,F=Net.Bus,Net.Codec,Net.Fragments
Bus.__index=Bus
local function now() return GetTime() end
local function stamp() return math.floor(GetServerTime()) end
local function number(v,lo,hi,whole)
    return not Net.IsSecret(v) and type(v)=="number" and v==v and v>=lo and v<=hi and (not whole or v==math.floor(v))
end
local function token(v,max)
    return not Net.IsSecret(v) and type(v)=="string" and #v>0 and #v<=max and v:match("^[%w_%-%.]+$")
end
local function text(v,max)
    return not Net.IsSecret(v) and type(v)=="string" and #v>0 and #v<=max and not v:find("%z")
end
local function dense(v,min,max)
    if Net.IsSecret(v) or type(v)~="table" or getmetatable(v)~=nil then return end
    local count=0
    for k in pairs(v) do if not number(k,1,max,true) then return end;count=count+1 end
    if count<min or count>max then return end
    for i=1,count do if v[i]==nil then return end end
    return count
end
local function errorInfo(code,details)
    local err=details or {};err.code=code;return err
end
local function runtime(bus)
    local rt=Net._runtime
    if not rt or rt.bus~=bus then error("ChannelBus: invalid bus") end
    return rt
end
local function expired(cache,at)
    for k,entry in pairs(cache) do if entry.expires<=at then cache[k]=nil end end
end
local function put(cache,key,entry,max)
    local count,oldest,oldestAt=0,nil,math.huge
    for k,v in pairs(cache) do count=count+1;if v.at<oldestAt then oldest,oldestAt=k,v.at end end
    if not cache[key] and count>=max then cache[oldest]=nil end
    cache[key]=entry
end
local function known(cache,key,at)
    local v=key and cache[key]
    if v and v.expires>at then return v end
end
function Net:Init(config)
    local c,signature=Net.NormalizeConfig(config)
    if self._runtime then
        if self._runtime.signature~=signature then error("ChannelBus: configuration conflict") end
        return self._runtime.bus
    end
    local bus=setmetatable({},Bus)
    local rt={bus=bus,protocol=4,config=c,signature=signature,
        channel={name=c.channel,id=0,nextJoin=0},subscriptions={},queues={{},{},{}},queued=0,
        pending={},localKnown={},observations={},received={},receivedPackets={},completedMessages={},revisions={},recent={},
        assemblies={},assemblyBytes=0,reservedBytes=0,recentBytes=0,paused={},messageCounter=0,
        sendTokens=0,sendAt=now(),receiveTokens=c.receive.burstBytes,receiveAt=now(),
        decodeTokens=c.receive.burstDecodes,decodeAt=now(),senders={},counter=0,wheel=0,
        priorityOrder=Net.PriorityOrder(c),session=string.format("%x-%06x",stamp(),math.random(0,16777215)),
        stats={sentPackets=0,sentParts=0,sentBytes=0,sentItems=0,receivedPackets=0,receivedParts=0,receivedMessages=0,
            assemblyTimeouts=0,assemblyConflicts=0,
            duplicates=0,suppressed=0,rejected=0,retries=0,compressed=0,raw=0,callbackErrors=0}}
    self._runtime=rt;self.StartNative(rt)
    return bus
end
local function statusOf(record)
    return {id=record.id,state=record.state,reason=record.reason,error=record.error and Net.Copy(record.error),
        packetID=record.packetID,packetBytes=record.packetBytes,messageID=record.messageID,
        parts=record.partsCount or 0,submittedParts=record.submittedParts or 0,expiresAt=record.expires}
end
local finish,pruneRecent
local function observe(rt,direction,obj,meta)
    local snapshot={}
    for _,fn in pairs(rt.observers or {}) do snapshot[#snapshot+1]=fn end
    for _,fn in ipairs(snapshot) do
        if not pcall(fn,direction,Net.Copy(obj,Net.ObjectLimits),Net.Copy(meta)) then rt.stats.callbackErrors=rt.stats.callbackErrors+1 end
    end
end
local function ticketFor(rt,record)
    return {GetStatus=function() return statusOf(record) end,
        Cancel=function()
            if record.finished then return false end
            finish(rt,record,"cancelled")
            return true
        end}
end
finish=function(rt,record,state,reason,err)
    if record.finished then return end
    if not err and (state=="failed" or state=="expired") then err=errorInfo(reason or state) end
    record.state,record.reason,record.error,record.finished=state,reason,err,true
    rt.queued=rt.queued-1
    if record.semantic and rt.pending[record.semantic]==record then rt.pending[record.semantic]=nil end
    if record.batch then record.batch.dirty=true end
    record.batch=nil
    local meta=statusOf(record)
    meta.type,meta.ver,meta.logged=record.item[2],record.item[3],record.logged
    if state=="submitted" or state=="submitted-unconfirmed" then observe(rt,"sent",record.item[9],meta)
    elseif state=="failed" or state=="expired" then observe(rt,"error",record.item[9],meta) end
    if record.onError and (state=="failed" or state=="expired") then
        local ok=pcall(record.onError,Net.Copy(err),statusOf(record))
        if not ok then rt.stats.callbackErrors=rt.stats.callbackErrors+1 end
    end
end
local function compact(rt)
    for _,q in ipairs(rt.queues) do for i=#q,1,-1 do if q[i].finished then table.remove(q,i) end end end
end
local function semantic(typ,version,mode,key)
    if mode~=0 then return typ.."\t"..version.."\t"..mode.."\t"..key end
end
local function fits(rt,packet)
    local limit=rt.config.multipart.enabled and rt.config.multipart.maxBytes or rt.config.batch.packetBytes
    return packet.rawLength<=rt.config.batch.maxBytes and #packet.text<=limit
end
local function sizeError(rt,packet,rawSize)
    return errorInfo(rt.config.multipart.enabled and "message-too-large" or "item-too-large",{sizeBytes=packet and #packet.text,
        limitBytes=rt.config.multipart.enabled and rt.config.multipart.maxBytes or rt.config.batch.packetBytes,
        packetLimitBytes=rt.config.batch.packetBytes,maxParts=rt.config.multipart.maxParts,rawBytes=packet and packet.rawLength or rawSize,
        rawLimitBytes=rt.config.batch.maxBytes})
end
local optionNames={ttl=true,priority=true,delayMin=true,delayMax=true,batchWindow=true,
    logged=true,key=true,revision=true,observationID=true,ver=true,onError=true}
local function prepare(rt,entry,at,sequence)
    if type(entry)~="table" or Net.IsSecret(entry) or getmetatable(entry)~=nil then return nil,errorInfo("invalid-entry") end
    for key,value in pairs(entry) do
        if Net.IsSecret(key) or Net.IsSecret(value) then return nil,errorInfo("secret-entry") end
        if key~="type" and key~="ver" and key~="obj" and key~="options" then return nil,errorInfo("unknown-entry-field") end
    end
    local typ,version=entry.type,entry.ver==nil and 1 or entry.ver
    if not token(typ,32) or not number(version,1,65535,true) or type(entry.obj)~="table" then return nil,errorInfo("invalid-type-object") end
    local ok,obj,canonical=pcall(Net.Copy,entry.obj,Net.ObjectLimits)
    if not ok then return nil,errorInfo("invalid-object",{detail=tostring(obj)}) end
    local options=entry.options
    if options==nil then options={} end
    if Net.IsSecret(options) or type(options)~="table" or getmetatable(options)~=nil then return nil,errorInfo("invalid-options") end
    local plain,onError={}
    for k,v in pairs(options) do
        if Net.IsSecret(k) or not optionNames[k] or Net.IsSecret(v) then return nil,errorInfo("invalid-options") end
        if k=="onError" then
            if type(v)~="function" then return nil,errorInfo("invalid-error-callback") end
            onError=v
        else plain[k]=v end
    end
    ok,options=pcall(Net.Copy,plain)
    if not ok then return nil,errorInfo("invalid-options") end
    if options.ver~=nil and (not number(options.ver,1,65535,true) or options.ver~=version) then
        return nil,errorInfo("invalid-type-version")
    end
    local function policy(key,default) local v=options[key];if v==nil then return default end;return v end
    local ttl,priority,window=policy("ttl",rt.config.defaultTTL),policy("priority",rt.config.defaultPriority),policy("batchWindow",rt.config.batchWindow)
    local logged=policy("logged",rt.config.logged)
    local key,revision,obs=options.key,options.revision,options.observationID
    if (key~=nil and not text(key,128)) or (revision~=nil and not number(revision,0,9007199254740991,true))
        or ((key~=nil)~=(revision~=nil)) or (obs~=nil and not text(obs,128)) or (key and obs) then return nil,errorInfo("invalid-identity") end
    local low,high=policy("delayMin",obs and rt.config.observationDelay.min or 0),policy("delayMax",obs and rt.config.observationDelay.max or 0)
    if not number(ttl,1,600,true) or not number(priority,1,3,true) or not number(window,0,30)
        or not number(low,0,60) or not number(high,low,60) or type(logged)~="boolean" then return nil,errorInfo("invalid-options") end
    if logged and (not C_ChatInfo or not C_ChatInfo.SendAddonMessageLogged) then return nil,errorInfo("logged-api-unavailable") end
    if not number(sequence,1,4294967295,true) then return nil,errorInfo("session-exhausted") end
    local mode=obs and 2 or (key and 1 or 0)
    -- Позиционная схема: seq,type,ver,stamp,ttl,identityMode,identity,revision,obj.
    local item={sequence,typ,version,stamp(),ttl,mode,obs or key or false,revision or 0,obj}
    local packet,why,rawSize=Codec.Encode({rt.session,{item}},rt.config.compression)
    if not packet then
        if why=="raw-size" then return nil,sizeError(rt,nil,rawSize) end
        return nil,errorInfo(why)
    end
    if not fits(rt,packet) then return nil,sizeError(rt,packet) end
    local parts,partError=F.Parts(packet.text,rt.session..".ffffffff",rt.config.batch.packetBytes,rt.config.multipart.maxParts)
    if not parts then local err=sizeError(rt,packet);err.detail=partError;return nil,err end
    local ready=at+low+math.random()*(high-low)
    return {id=rt.session.."."..string.format("%x",sequence),item=item,soloPacket=packet,
        semantic=semantic(typ,version,mode,item[7]),canonical=canonical,priority=priority,logged=logged,
        window=window,readyAt=ready,due=ready+window,expires=at+ttl,state="queued",onError=onError}
end
function Bus:On(typ,consumerID,callback,version)
    local rt=runtime(self)
    if Net.IsSecret(version) or Net.IsSecret(callback) then error("ChannelBus: secret subscription") end
    if version==nil then version=1 end
    if not token(typ,32) or not text(consumerID,64) or type(callback)~="function" or not number(version,1,65535,true) then error("ChannelBus: invalid subscription") end
    local callbacks=rt.subscriptions[typ] or {};local count=0
    for _ in pairs(rt.subscriptions) do count=count+1 end
    if not rt.subscriptions[typ] and count>=64 then error("ChannelBus: subscription limit") end
    count=0;for _ in pairs(callbacks) do count=count+1 end
    if not callbacks[consumerID] and count>=16 then error("ChannelBus: consumer limit") end
    callbacks[consumerID]={fn=callback,ver=version};rt.subscriptions[typ]=callbacks
    return self
end
function Bus:Off(typ,consumerID)
    local subscriptions=runtime(self).subscriptions[typ]
    if subscriptions then subscriptions[consumerID]=nil end
end
-- Logical objects only, after validation/deduplication or completed native submission.
-- Copies and protected callbacks keep diagnostics independent of consumers.
function Bus:Observe(consumerID,callback)
    local rt=runtime(self)
    if not text(consumerID,64) or Net.IsSecret(callback) or type(callback)~="function" then error("ChannelBus: invalid observer") end
    rt.observers=rt.observers or {}
    local count=0;for _ in pairs(rt.observers) do count=count+1 end
    if not rt.observers[consumerID] and count>=16 then error("ChannelBus: observer limit") end
    rt.observers[consumerID]=callback
    return self
end
function Bus:Unobserve(consumerID) if runtime(self).observers then runtime(self).observers[consumerID]=nil end end
function Bus:Publish(typ,obj,options)
    if Net.IsSecret(options) then return nil,errorInfo("invalid-options") end
    if options~=nil and (type(options)~="table" or getmetatable(options)~=nil) then
        return nil,errorInfo("invalid-options")
    end
    local version=1
    if options then
        if Net.IsSecret(options.ver) then return nil,errorInfo("invalid-options") end
        if options.ver~=nil then version=options.ver end
    end
    local tickets,err=self:PublishBatch({{type=typ,ver=version,obj=obj,options=options}})
    if not tickets then return nil,err end
    return tickets[1]
end
function Bus:PublishBatch(entries)
    local rt,at=runtime(self),now()
    local count=dense(entries,1,Net.Protocol.maxPublishItems)
    if not count then return nil,errorInfo("invalid-batch") end
    local staged,shadow,newCount,live={}, {},0,rt.queued
    for i=1,count do
        local record,err=prepare(rt,entries[i],at,rt.counter+newCount+1)
        if not record then err.itemIndex=i;return nil,err,i end
        local sk=record.semantic
        local previous=sk and (shadow[sk] or rt.pending[sk])
        if previous and previous.finished then previous=nil end
        local old=previous or known(record.item[6]==2 and rt.observations or rt.localKnown,sk,at)
        local duplicate
        if old then
            local rev=old.item and old.item[8] or old.revision
            if record.item[6]==2 then
                if old.canonical~=record.canonical then return nil,errorInfo("observation-conflict",{itemIndex=i}),i end
                duplicate="observation"
            elseif record.item[8]<rev then duplicate="older-revision"
            elseif record.item[8]==rev then
                if old.canonical~=record.canonical then return nil,errorInfo("revision-conflict",{itemIndex=i}),i end
                duplicate="revision"
            end
        end
        if duplicate then staged[i]={duplicate=duplicate}
        else
            staged[i]={record=record,previous=previous}
            if previous then live=live-1 end
            live=live+1;newCount=newCount+1
            if sk then shadow[sk]=record end
        end
    end
    if live>rt.config.maxQueuedItems then return nil,errorInfo("queue-full",{limitItems=rt.config.maxQueuedItems}) end
    rt.counter=rt.counter+newCount
    local tickets={}
    for i,stage in ipairs(staged) do
        if stage.duplicate then
            rt.stats.duplicates=rt.stats.duplicates+1
            local reason=stage.duplicate
            tickets[i]={GetStatus=function() return {state="duplicate-known",reason=reason} end,Cancel=function() return false end}
        else
            local record=stage.record
            if stage.previous then finish(rt,stage.previous,"superseded") end
            rt.queues[record.priority][#rt.queues[record.priority]+1]=record
            rt.queued=rt.queued+1
            if record.semantic then rt.pending[record.semantic]=record end
            tickets[i]=ticketFor(rt,record)
        end
    end
    compact(rt);return tickets
end
local function requeue(rt,batch,at)
    if rt.active==batch then rt.active=nil end
    for i=#rt.paused,1,-1 do if rt.paused[i]==batch then table.remove(rt.paused,i) end end
    for _,r in ipairs(batch.records) do
        r.batch=nil
        if not r.finished then
            r.state,r.readyAt,r.due="queued",at,at+r.window
            rt.queues[r.priority][#rt.queues[r.priority]+1]=r
        end
    end
end
local function dropAssembly(rt,key)
    local a=rt.assemblies[key]
    if a then
        rt.assemblyBytes=rt.assemblyBytes-a.bytes;rt.reservedBytes=rt.reservedBytes-a.length
        rt.assemblies[key]=nil
    end
end
local function pick(rt,at)
    local order=rt.priorityOrder
    for _=1,#order do
        rt.wheel=rt.wheel%#order+1
        for i,batch in ipairs(rt.paused) do
            if batch.priority==order[rt.wheel] and batch.due<=at then
                table.remove(rt.paused,i);rt.active=batch;return
            end
        end
        for _,r in ipairs(rt.queues[order[rt.wheel]]) do if not r.finished and r.due<=at then return r end end
    end
end
local function build(rt,seed,at)
    if rt.messageCounter>=4294967295 then finish(rt,seed,"failed","session-exhausted");return end
    local selected={seed}
    for _,q in ipairs(rt.queues) do
        for _,r in ipairs(q) do
            local ready=r.due<=at or (r.window==seed.window and r.readyAt<=at)
            if r~=seed and r.priority==seed.priority and not r.finished and ready and r.logged==seed.logged and #selected<rt.config.batch.maxItems then
                selected[#selected+1]=r
            end
        end
    end
    rt.messageCounter=rt.messageCounter+1
    local id=rt.session.."."..string.format("%08x",rt.messageCounter)
    local packet,parts
    while #selected>1 do
        local items={};for _,r in ipairs(selected) do items[#items+1]=r.item end
        packet=Codec.Encode({rt.session,items},rt.config.compression)
        if packet and fits(rt,packet) then parts=F.Parts(packet.text,id,rt.config.batch.packetBytes,rt.config.multipart.maxParts) end
        if parts then break end
        table.remove(selected);packet=nil
    end
    packet=packet or seed.soloPacket
    parts=parts or F.Parts(packet.text,id,rt.config.batch.packetBytes,rt.config.multipart.maxParts)
    if not parts then finish(rt,seed,"failed","part-limit");return end
    local packetID=rt.session..":"..packet.checksum..":"..#packet.text
    local batch={id=id,records=selected,packet=packet,parts=parts,index=1,logged=seed.logged,attempts=0,due=at,priority=seed.priority}
    for _,r in ipairs(selected) do
        r.batch,r.packetID,r.packetBytes,r.messageID=batch,packetID,#packet.text,id
        r.partsCount,r.submittedParts=#parts,0
        batch.priority=math.min(batch.priority,r.priority)
        for _,q in ipairs(rt.queues) do for i=#q,1,-1 do if q[i]==r then table.remove(q,i) end end end
    end
    rt.active=batch
end
function Bus:Tick()
    local rt,at=runtime(self),now()
    local function isExpired(record) return record.expires<=at or record.item[4]+record.item[5]<=stamp() end
    Net.UpdateNative(rt,at)
    pruneRecent(rt,at)
    for _,c in ipairs({rt.received,rt.receivedPackets,rt.completedMessages,rt.observations,rt.localKnown,rt.revisions,rt.senders}) do expired(c,at) end
    for key,a in pairs(rt.assemblies) do
        if a.expires<=at then dropAssembly(rt,key);rt.stats.assemblyTimeouts=rt.stats.assemblyTimeouts+1 end
    end
    for _,q in ipairs(rt.queues) do for _,r in ipairs(q) do if not r.finished and isExpired(r) then finish(rt,r,"expired") end end end
    local batches={};if rt.active then batches[#batches+1]=rt.active end
    for _,batch in ipairs(rt.paused) do batches[#batches+1]=batch end
    for _,batch in ipairs(batches) do
        for _,r in ipairs(batch.records) do
            if not r.finished and isExpired(r) then finish(rt,r,"expired") end
            local old=r.item[6]==2 and known(rt.observations,r.semantic,at)
            if not r.finished and old and old.canonical==r.canonical then finish(rt,r,"suppressed");rt.stats.suppressed=rt.stats.suppressed+1 end
        end
        if batch.dirty or (batch.index>1 and batch.lastSentAt and at-batch.lastSentAt>=rt.config.multipart.restartAfter) then
            requeue(rt,batch,at)
        end
    end
    compact(rt)
    rt.sendTokens=math.min(rt.config.burstBytes,rt.sendTokens+math.max(0,at-rt.sendAt)*rt.config.bytesPerSecond);rt.sendAt=at
    if not rt.transportReady or rt.channel.id==0 or (rt.blockedUntil or 0)>at then return end
    for _=1,rt.config.maxSendsPerTick do
        if rt.active and #rt.paused<rt.config.multipart.maxInFlight-1 then
            local urgent
            for priority=1,rt.active.priority-1 do
                for _,r in ipairs(rt.queues[priority]) do if not r.finished and r.due<=at then urgent=r;break end end
                if urgent then break end
            end
            if urgent then rt.paused[#rt.paused+1]=rt.active;rt.active=nil;build(rt,urgent,at) end
        end
        if not rt.active then
            local seed=pick(rt,at)
            if not seed and not rt.active then break end
            local old=seed and seed.item[6]==2 and known(rt.observations,seed.semantic,at)
            if old and old.canonical==seed.canonical then finish(rt,seed,"suppressed");rt.stats.suppressed=rt.stats.suppressed+1;compact(rt)
            elseif seed then build(rt,seed,at) end
        end
        local batch=rt.active
        if not batch or batch.due>at then break end
        local part=batch.parts[batch.index]
        local cost=#part+#rt.config.prefix+40
        if rt.sendTokens<cost then break end
        rt.sendTokens=rt.sendTokens-cost
        local ok,result=pcall(Net.SendNative,rt,batch,part)
        local e=Enum and Enum.SendAddonMessageResult
        if ok and e and (result==e.Success or result==nil) then
            if result==nil then batch.uncertain=true end
            rt.stats.sentParts=rt.stats.sentParts+1;rt.stats.sentBytes=rt.stats.sentBytes+#part
            batch.index=batch.index+1;batch.lastSentAt=at;batch.attempts=0
            for _,r in ipairs(batch.records) do r.submittedParts=batch.index-1;r.state="sending" end
            if batch.index>#batch.parts then
                rt.active=nil;rt.stats.sentPackets=rt.stats.sentPackets+1
                if batch.packet.mode=="C" then rt.stats.compressed=rt.stats.compressed+1 else rt.stats.raw=rt.stats.raw+1 end
                for _,r in ipairs(batch.records) do
                    if not r.finished then
                        if r.semantic then
                            local info={canonical=r.canonical,revision=r.item[8],at=at,expires=r.expires}
                            put(rt.localKnown,r.semantic,info,rt.config.cache.semanticEntries)
                            if r.item[6]==2 then put(rt.observations,r.semantic,info,rt.config.cache.semanticEntries) end
                        end
                        finish(rt,r,batch.uncertain and "submitted-unconfirmed" or "submitted");rt.stats.sentItems=rt.stats.sentItems+1
                    end
                end
            end
        elseif ok and e and (result==e.AddonMessageThrottle or result==e.ChannelThrottle or result==e.AddOnMessageLockdown or result==e.InvalidChannel or result==e.GeneralError) then
            batch.attempts=batch.attempts+1;rt.stats.retries=rt.stats.retries+1
            if batch.attempts>rt.config.retry.maxRetries then
                rt.active=nil
                for _,r in ipairs(batch.records) do finish(rt,r,"failed","retry-limit",errorInfo("retry-limit",{nativeResult=result})) end
            else
                batch.due=at+math.min(rt.config.retry.maxDelay,rt.config.retry.minDelay*2^(batch.attempts-1));rt.blockedUntil=batch.due
                for _,r in ipairs(batch.records) do if not r.finished then r.state="retrying" end end
                if result==e.InvalidChannel then
                    rt.channel.id=0;rt.nextNative=0
                    if batch.index>1 then requeue(rt,batch,at) end
                end
            end
            break
        else
            rt.active=nil
            local err=errorInfo(ok and "native-result" or "send-exception",ok and {nativeResult=result} or nil)
            for _,r in ipairs(batch.records) do finish(rt,r,"failed",err.code,err) end
        end
    end
end
local function budget(rt,sender,cost,at)
    local c=rt.config.receive
    rt.receiveTokens=math.min(c.burstBytes,rt.receiveTokens+math.max(0,at-rt.receiveAt)*c.bytesPerSecond);rt.receiveAt=at
    local peer=rt.senders[sender]
    if not peer then peer={tokens=c.perSenderBurstBytes,at=at,expires=at+60};put(rt.senders,sender,peer,c.senderCacheSize) end
    peer.tokens=math.min(c.perSenderBurstBytes,peer.tokens+math.max(0,at-peer.at)*c.perSenderBytesPerSecond);peer.at,peer.expires=at,at+60
    if rt.receiveTokens<cost or peer.tokens<cost then return false end
    rt.receiveTokens,peer.tokens=rt.receiveTokens-cost,peer.tokens-cost
    return true
end
local function decodeBudget(rt,at)
    local c=rt.config.receive
    rt.decodeTokens=math.min(c.burstDecodes,rt.decodeTokens+math.max(0,at-rt.decodeAt)*c.decodesPerSecond);rt.decodeAt=at
    if rt.decodeTokens<1 then return false end
    rt.decodeTokens=rt.decodeTokens-1;return true
end
local function validate(item)
    if not dense(item,9,9) or not number(item[1],1,4294967295,true) or not token(item[2],32)
        or not number(item[3],1,65535,true) or not number(item[4],0,9007199254740991,true)
        or not number(item[5],1,600,true) or not number(item[6],0,2,true) then return end
    if item[6]==0 then if item[7]~=false or item[8]~=0 then return end
    elseif item[6]==1 then if not text(item[7],128) or not number(item[8],0,9007199254740991,true) then return end
    elseif not text(item[7],128) or item[8]~=0 then return end
    if type(item[9])~="table" then return end
    local ok,copy,canonical=pcall(Net.Copy,item[9],Net.ObjectLimits);if not ok then return end
    return copy,canonical
end
pruneRecent=function(rt,at)
    rt.recentBytes=rt.recentBytes or 0
    for i=#rt.recent,1,-1 do if rt.recent[i].expiresAt<=at then
        rt.recentBytes=rt.recentBytes-(rt.recent[i].objectBytes or 0);table.remove(rt.recent,i)
    end end
end
local function apply(rt,session,item,obj,canonical,sender,logged,packetID,at,messageID)
    local sequence,typ,version,when,ttl,mode,key,revision=item[1],item[2],item[3],item[4],item[5],item[6],item[7],item[8]
    if when>stamp()+30 or when+ttl<=stamp() then rt.stats.rejected=rt.stats.rejected+1;return false end
    local id=session.."."..string.format("%x",sequence)
    local idKey=sender.."\t"..id
    if known(rt.received,idKey,at) then rt.stats.duplicates=rt.stats.duplicates+1;return false end
    local lifetime=math.min(ttl,when+ttl-stamp())
    put(rt.received,idKey,{at=at,expires=at+lifetime},rt.config.cache.receivedIds)
    local sk=semantic(typ,version,mode,key)
    if mode==2 then
        local old=known(rt.observations,sk,at)
        if old then
            if old.canonical==canonical then rt.stats.duplicates=rt.stats.duplicates+1 else rt.stats.rejected=rt.stats.rejected+1 end
            return false
        end
        put(rt.observations,sk,{canonical=canonical,at=at,expires=at+lifetime},rt.config.cache.semanticEntries)
        local pending=rt.pending[sk]
        if pending and pending.canonical==canonical then finish(rt,pending,"suppressed");rt.stats.suppressed=rt.stats.suppressed+1 end
    elseif mode==1 then
        local stateKey=sender.."\t"..session.."\t"..sk
        local old=known(rt.revisions,stateKey,at)
        if old and revision<=old.revision then rt.stats.duplicates=rt.stats.duplicates+1;return false end
        put(rt.revisions,stateKey,{revision=revision,at=at,expires=at+lifetime},rt.config.cache.semanticEntries)
    end
    rt.stats.receivedMessages=rt.stats.receivedMessages+1
    local meta={id=id,packetID=packetID,messageID=messageID,sender=sender,type=typ,ver=version,logged=logged,expiresAt=at+lifetime}
    if mode==1 then meta.key,meta.revision=key,revision elseif mode==2 then meta.observationID=key end
    if rt.config.cache.recentItems>0 then
        pruneRecent(rt,at)
        local bytes=#canonical
        if bytes<=rt.config.cache.recentBytes then
            local message=Net.Copy(meta);message.obj=obj;message.objectBytes=bytes
            rt.recent[#rt.recent+1]=message;rt.recentBytes=rt.recentBytes+bytes
        end
        while #rt.recent>rt.config.cache.recentItems or rt.recentBytes>rt.config.cache.recentBytes do
            local old=table.remove(rt.recent,1);rt.recentBytes=rt.recentBytes-(old.objectBytes or 0)
        end
    end
    local callbacks=rt.subscriptions[typ]
    observe(rt,"received",obj,meta)
    if callbacks then
        local snapshot={};for _,sub in pairs(callbacks) do if sub.ver==version then snapshot[#snapshot+1]=sub.fn end end
        for _,fn in ipairs(snapshot) do
            local payload,details=Net.Copy(obj,Net.ObjectLimits),Net.Copy(meta)
            if not pcall(fn,payload,details) then rt.stats.callbackErrors=rt.stats.callbackErrors+1 end
        end
    end
    return true
end
local function decodeLogical(rt,packet,sender,logged,at,messageID)
    local packetKey=sender.."\t"..packet
    local old=known(rt.receivedPackets,packetKey,at)
    if old then rt.stats.duplicates=rt.stats.duplicates+1;return false,old.expires-at end
    if not decodeBudget(rt,at) then rt.stats.rejected=rt.stats.rejected+1;return false end
    local frame,_,info=Codec.Decode(packet)
    if not frame or not dense(frame,2,2) or not token(frame[1],32) or frame[1]:find("%.") then rt.stats.rejected=rt.stats.rejected+1;return false end
    local count=dense(frame[2],1,Net.Protocol.maxItems)
    if not count then rt.stats.rejected=rt.stats.rejected+1;return false end
    local checked,maxTTL={},1
    for i=1,count do
        local obj,canonical=validate(frame[2][i])
        if not obj then rt.stats.rejected=rt.stats.rejected+1;return false end
        checked[i]={item=frame[2][i],obj=obj,canonical=canonical};maxTTL=math.max(maxTTL,frame[2][i][5])
    end
    -- Большие wire не держим ещё раз в exact cache: ID сборки и itemID достаточны.
    if #packet<=Net.Protocol.maxPacketBytes then
        put(rt.receivedPackets,packetKey,{at=at,expires=at+maxTTL},rt.config.cache.packetIds)
    end
    rt.stats.receivedPackets=rt.stats.receivedPackets+1
    local delivered=false
    for _,v in ipairs(checked) do
        if apply(rt,frame[1],v.item,v.obj,v.canonical,sender,logged,frame[1]..":"..info.packetID,at,messageID) then delivered=true end
    end
    return delivered,maxTTL
end
local function assemblyKey(rt,sender,id)
    return sender.."\t"..rt.config.prefix.."\t"..rt.config.channel.."\t"..id
end
local function rejectAssembly(rt,key,at)
    dropAssembly(rt,key)
    put(rt.completedMessages,key,{at=at,expires=at+rt.config.receive.maxLifetime,rejected=true},rt.config.cache.messageIds)
    rt.stats.rejected=rt.stats.rejected+1;rt.stats.assemblyConflicts=rt.stats.assemblyConflicts+1
    return false
end
function Bus:Receive(packet,sender,logged)
    local rt,at=runtime(self),now()
    if not text(sender,128) or Net.IsSecret(packet) or type(packet)~="string" or #packet>Net.Protocol.maxPacketBytes or type(logged)~="boolean" then
        rt.stats.rejected=rt.stats.rejected+1;return false
    end
    if packet:sub(1,2)~="4|" then
        local key=sender.."\t"..packet
        if known(rt.receivedPackets,key,at) then rt.stats.duplicates=rt.stats.duplicates+1;return false end
        if not budget(rt,sender,#packet,at) then rt.stats.rejected=rt.stats.rejected+1;return false end
        return (decodeLogical(rt,packet,sender,logged,at))
    end
    local part=F.Parse(packet)
    local c=rt.config.receive
    if not part or part.length>c.maxMessageBytes or part.total>c.maxParts then rt.stats.rejected=rt.stats.rejected+1;return false end
    local key=assemblyKey(rt,sender,part.id)
    if known(rt.completedMessages,key,at) then rt.stats.duplicates=rt.stats.duplicates+1;return false end
    if not budget(rt,sender,#packet,at) then rt.stats.rejected=rt.stats.rejected+1;return false end
    for k,a in pairs(rt.assemblies) do
        if a.expires<=at then dropAssembly(rt,k);rt.stats.assemblyTimeouts=rt.stats.assemblyTimeouts+1 end
    end
    local a=rt.assemblies[key]
    if not a then
        local count,peers=0,0
        for _,v in pairs(rt.assemblies) do count=count+1;if v.sender==sender then peers=peers+1 end end
        if count>=c.maxAssemblies or peers>=c.maxAssembliesPerSender or rt.reservedBytes+part.length>c.maxBufferedBytes then
            rt.stats.rejected=rt.stats.rejected+1;return false
        end
        a={sender=sender,logged=logged,total=part.total,length=part.length,checksum=part.checksum,
            parts={},count=0,bytes=0,started=at,expires=at+c.idleTimeout}
        rt.assemblies[key]=a;rt.reservedBytes=rt.reservedBytes+part.length
    end
    if a.total~=part.total or a.length~=part.length or a.checksum~=part.checksum or a.logged~=logged then return rejectAssembly(rt,key,at) end
    if a.parts[part.index] then
        if a.parts[part.index]~=part.chunk then return rejectAssembly(rt,key,at) end
        rt.stats.duplicates=rt.stats.duplicates+1;return false
    end
    if a.bytes+#part.chunk>a.length then return rejectAssembly(rt,key,at) end
    a.parts[part.index]=part.chunk;a.count=a.count+1;a.bytes=a.bytes+#part.chunk
    a.expires=math.min(a.started+c.maxLifetime,at+c.idleTimeout)
    rt.assemblyBytes=rt.assemblyBytes+#part.chunk;rt.stats.receivedParts=rt.stats.receivedParts+1
    if a.count~=a.total then return false end
    local wire=table.concat(a.parts)
    dropAssembly(rt,key)
    -- Защита от replay/reentrant callback устанавливается до выдачи объекта.
    local done={at=at,expires=at+c.maxLifetime}
    put(rt.completedMessages,key,done,rt.config.cache.messageIds)
    if #wire~=a.length or Net.Adler(wire)~=a.checksum then rt.stats.rejected=rt.stats.rejected+1;return false end
    local delivered,lifetime=decodeLogical(rt,wire,sender,logged,at,part.id)
    if lifetime then done.expires=at+lifetime end
    return delivered
end
function Bus:GetStatus()
    local rt=runtime(self)
    return {ready=rt.ready or false,state=rt.ready and "ready" or "joining",error=rt.error,queued=rt.queued,
        channel={name=rt.channel.name,id=rt.channel.id,error=rt.channel.error},stats=Net.Copy(rt.stats),version=Net.version,protocol=4,
        bufferedBytes=rt.assemblyBytes,reservedBytes=rt.reservedBytes}
end
function Bus:GetConfig() local copy=Net.Copy(runtime(self).config);return copy end
function Bus:GetRecent(typ)
    local rt=runtime(self);pruneRecent(rt,now())
    local result={}
    for _,message in ipairs(runtime(self).recent) do
        if message.expiresAt>now() and (typ==nil or message.type==typ) then
            local copy={};for k,v in pairs(message) do if k~="obj" then copy[k]=v end end
            copy.obj=Net.Copy(message.obj,Net.ObjectLimits);result[#result+1]=copy
        end
    end
    return result
end
function Bus:GetSnapshot(typ)
    local states={}
    for _,message in ipairs(self:GetRecent(typ)) do
        if message.key then states[table.concat({message.sender,message.type,message.ver,message.key},"\t")]=message end
    end
    return states
end
