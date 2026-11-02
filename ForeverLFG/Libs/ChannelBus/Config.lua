-- Copyright (c) 2026 WerkoDev. All rights reserved.
local Net = _G.ChannelBus
if not Net.loading then return end

-- Native части ограничены отдельно от полного CBOR-сообщения.
Net.Protocol = {version=4,maxItems=32,maxRawBytes=524288,maxPacketBytes=240,
    maxMessageBytes=196608,maxParts=1536,maxPublishItems=1024,maxItemTTL=600}
local defaults = {
    network="global",channel="ChannelBus",prefix="CHBUS",storage={mode="memory"},logged=false,
    batchWindow=0.25,bytesPerSecond=320,burstBytes=560,tickInterval=0.1,
    maxSendsPerTick=2,maxQueuedItems=128,defaultTTL=120,defaultPriority=2,
    priorityWeights={3,2,1},observationDelay={min=1,max=3},
    batch={maxItems=32,maxBytes=524288,packetBytes=240},
    multipart={enabled=true,maxBytes=196608,maxParts=1536,maxInFlight=2,restartAfter=10},
    compression={enabled=true,level="OptimizeForSize",minSavingsBytes=1},
    cache={receivedIds=512,packetIds=512,messageIds=512,semanticEntries=256,recentItems=64,recentBytes=1048576},
    retry={maxRetries=8,minDelay=0.5,maxDelay=10},
    receive={bytesPerSecond=6000,burstBytes=12000,perSenderBytesPerSecond=1500,
        perSenderBurstBytes=3000,senderCacheSize=64,decodesPerSecond=4,burstDecodes=8,
        maxAssemblies=32,maxAssembliesPerSender=8,maxBufferedBytes=1048576,
        maxMessageBytes=196608,maxParts=1536,idleTimeout=15,maxLifetime=600},
}
local function merge(base,overrides,path)
    if type(overrides)~="table" then error("ChannelBus: config table required: "..path) end
    for key in pairs(overrides) do
        if base[key]==nil then error("ChannelBus: unknown config: "..path..tostring(key)) end
    end
    local result={}
    for key,value in pairs(base) do
        local supplied=overrides[key]
        if type(value)=="table" then
            result[key]=merge(value,supplied==nil and {} or supplied,path..key..".")
        elseif supplied==nil then result[key]=value
        else result[key]=supplied end
    end
    return result
end
local function number(v,low,high,integer)
    return type(v)=="number" and v==v and v>=low and v<=high and (not integer or v==math.floor(v))
end
local function check(v,low,high,integer,name)
    if not number(v,low,high,integer) then error("ChannelBus: invalid config: "..name) end
end
local function token(v,max)
    return type(v)=="string" and #v>0 and #v<=max and v:match("^[%w_%-%.]+$")
end
function Net:GetDefaults()
    local copy=Net.Copy(defaults)
    return copy
end
function Net.NormalizeConfig(overrides)
    if Net.IsSecret(overrides) then error("ChannelBus: secret config") end
    if overrides==nil then overrides={} end
    local plain=Net.Copy(overrides)
    local c=merge(defaults,plain,"")
    if not token(c.network,32) or not token(c.channel,32) or not token(c.prefix,16)
        or c.storage.mode~="memory" then error("ChannelBus: invalid network/storage config") end
    check(c.batchWindow,0,30,false,"batchWindow")
    check(c.bytesPerSecond,1,8192,false,"bytesPerSecond")
    check(c.burstBytes,64,16384,true,"burstBytes")
    check(c.tickInterval,0.02,1,false,"tickInterval")
    check(c.maxSendsPerTick,1,8,true,"maxSendsPerTick")
    check(c.maxQueuedItems,1,1024,true,"maxQueuedItems")
    check(c.defaultTTL,1,600,true,"defaultTTL")
    check(c.defaultPriority,1,3,true,"defaultPriority")
    if type(c.logged)~="boolean" then error("ChannelBus: invalid config: logged") end
    for i=1,3 do check(c.priorityWeights[i],1,16,true,"priorityWeights") end
    check(c.observationDelay.min,0,60,false,"observationDelay.min")
    check(c.observationDelay.max,c.observationDelay.min,60,false,"observationDelay.max")
    check(c.batch.maxItems,1,32,true,"batch.maxItems")
    check(c.batch.maxBytes,128,524288,true,"batch.maxBytes")
    check(c.batch.packetBytes,64,240,true,"batch.packetBytes")
    if c.burstBytes<c.batch.packetBytes+#c.prefix+40 then error("ChannelBus: burstBytes below one packet cost") end
    if type(c.multipart.enabled)~="boolean" then error("ChannelBus: invalid multipart.enabled") end
    check(c.multipart.maxBytes,c.batch.packetBytes,196608,true,"multipart.maxBytes")
    check(c.multipart.maxParts,2,1536,true,"multipart.maxParts")
    check(c.multipart.maxInFlight,1,4,true,"multipart.maxInFlight")
    check(c.multipart.restartAfter,1,120,false,"multipart.restartAfter")
    if type(c.compression.enabled)~="boolean" or not ({Default=true,OptimizeForSpeed=true,OptimizeForSize=true})[c.compression.level] then
        error("ChannelBus: invalid compression config")
    end
    check(c.compression.minSavingsBytes,0,12000,true,"compression.minSavingsBytes")
    check(c.cache.receivedIds,1,4096,true,"cache.receivedIds")
    check(c.cache.packetIds,1,4096,true,"cache.packetIds")
    check(c.cache.messageIds,1,4096,true,"cache.messageIds")
    check(c.cache.semanticEntries,1,4096,true,"cache.semanticEntries")
    check(c.cache.recentItems,0,4096,true,"cache.recentItems")
    check(c.cache.recentBytes,0,16777216,true,"cache.recentBytes")
    check(c.retry.maxRetries,0,32,true,"retry.maxRetries")
    check(c.retry.minDelay,0.1,60,false,"retry.minDelay")
    check(c.retry.maxDelay,c.retry.minDelay,60,false,"retry.maxDelay")
    local r=c.receive
    check(r.bytesPerSecond,1,65536,false,"receive.bytesPerSecond")
    check(r.burstBytes,240,262144,true,"receive.burstBytes")
    check(r.perSenderBytesPerSecond,1,65536,false,"receive.perSenderBytesPerSecond")
    check(r.perSenderBurstBytes,240,131072,true,"receive.perSenderBurstBytes")
    check(r.senderCacheSize,1,1024,true,"receive.senderCacheSize")
    check(r.decodesPerSecond,0.1,64,false,"receive.decodesPerSecond")
    check(r.burstDecodes,1,64,true,"receive.burstDecodes")
    check(r.maxAssemblies,1,128,true,"receive.maxAssemblies")
    check(r.maxAssembliesPerSender,1,r.maxAssemblies,true,"receive.maxAssembliesPerSender")
    check(r.maxBufferedBytes,12000,1048576,true,"receive.maxBufferedBytes")
    check(r.maxMessageBytes,240,196608,true,"receive.maxMessageBytes")
    check(r.maxParts,2,1536,true,"receive.maxParts")
    check(r.idleTimeout,2,120,false,"receive.idleTimeout")
    check(r.maxLifetime,r.idleTimeout,600,false,"receive.maxLifetime")
    return Net.Copy(c)
end
function Net.PriorityOrder(config)
    local order={}
    for priority,weight in ipairs(config.priorityWeights) do
        for _=1,weight do order[#order+1]=priority end
    end
    return order
end

-- Совместимая загрузка minor сохраняет runtime текущего протокола.
if Net._runtime then
    local rt=Net._runtime
    -- Upgrade only the exact 0.4.x default configuration; custom policies stay explicit.
    local legacy=Net.Copy(defaults)
    legacy.batch.maxBytes=8192;legacy.multipart.maxBytes=12000;legacy.multipart.maxParts=86
    legacy.cache.recentBytes=nil;legacy.receive.maxBufferedBytes=65536
    legacy.receive.maxMessageBytes=12000;legacy.receive.maxParts=86
    local _,signature=Net.Copy(legacy)
    if rt.signature==signature then rt.config=defaults end
    rt.config,rt.signature=Net.NormalizeConfig(rt.config)
    rt.priorityOrder=Net.PriorityOrder(rt.config)
end
