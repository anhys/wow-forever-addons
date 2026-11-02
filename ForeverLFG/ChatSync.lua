-- Public chat observations are a separate ChannelBus consumer, never quest peers.
local addonName,NS=...
local Reader=NS.ChatReader
local S={INTERVAL=45,TYPE="trade.chat",VERSION=1,loaded=false,sequence=0,
    stats={batches=0,submitted=0,unconfirmed=0,failures=0,received=0}}
NS.ChatSync=S
local function plain(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=plain(v) end
    return result -- JSON array metatables are reader-local, never sent to ChannelBus.
end
local function call(fn)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn)
    if ok and Reader.Readable(v) and (type(v)=="string" or type(v)=="number") then return v end
end
function S:Start()
    if self.collector then return end
    local version,build,buildDate,interface
    if GetBuildInfo then version,build,buildDate,interface=GetBuildInfo() end
    self.collector=Reader.Collector.New({clock=GetServerTime or time,observer={
        realm=call(GetRealmName),clientLocale=call(GetLocale),clientVersion=version,
        build=build,buildDate=buildDate,interface=interface}})
    self.nextPoll=GetTime()+self.INTERVAL
end
function S:EnsureBus()
    if self.bus then return true end
    local ok,bus=pcall(ChannelBus.Init,ChannelBus)
    if not ok then self.error="bus-unavailable";return false end
    self.bus=bus
    -- Intentionally no feature/cache for received chat data. Diagnostics still observe it.
    bus:On(self.TYPE,"ForeverLFG.chat",function() self.stats.received=self.stats.received+1 end,self.VERSION)
    return true
end
function S:CheckPending()
    local pending=self.pending
    if not pending or not pending.ticket then return end
    local status=pending.ticket:GetStatus()
    if status.state=="submitted" or status.state=="submitted-unconfirmed" or status.state=="duplicate-known" then
        self.stats.submitted=self.stats.submitted+1
        if status.state=="submitted-unconfirmed" then self.stats.unconfirmed=self.stats.unconfirmed+1 end
        self.pending=nil;self.error=nil -- Drop ticket, payload and its closure together.
    elseif status.state=="failed" or status.state=="expired" or status.state=="cancelled" or status.state=="superseded" then
        pending.ticket=nil;pending.retryAt=GetTime()+10
        self.stats.failures=self.stats.failures+1;self.error=status.reason or status.state
    end
end
function S:SendPending()
    local pending=self.pending
    if not pending or pending.ticket or GetTime()<(pending.retryAt or 0) or not self:EnsureBus() then return end
    -- No semantic key/revision: a later batch must never supersede an earlier one.
    -- One object; only the bus serializes, compresses, fragments and assembles it.
    local ticket,err=self.bus:Publish(self.TYPE,pending.data,{ver=self.VERSION,ttl=600,priority=3})
    if ticket then pending.ticket=ticket;self.error=nil
    else
        self.error=err and err.code or "publish-failed";pending.retryAt=GetTime()+10
        self.stats.failures=self.stats.failures+1
    end
end
function S:Poll()
    -- Backpressure: one in-flight batch; do not drain again while it is unfinished.
    if self.pending then return end
    local data=self.collector:GetData({drain=true,maxRecords=64,maxBytes=32768})
    if data.uniqueFactCount==0 then return end
    self.sequence=self.sequence+1
    data.batchID=data.session.."/"..self.sequence
    self.pending={data=plain(data)}
    self.stats.batches=self.stats.batches+1
end
function S:Tick()
    if not self.loaded or (IsLoggedIn and not IsLoggedIn()) then return end
    self:Start();self.collector:PruneRecent();self:EnsureBus();self:CheckPending()
    local at=GetTime()
    if at>=self.nextPoll then
        self.nextPoll=at+self.INTERVAL
        self:Poll()
    end
    self:SendPending()
end
local frame=CreateFrame("Frame");S.frame=frame
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if (...)~=addonName then return end
        S.loaded=true;S:Start()
        for _,name in ipairs({"CHAT_MSG_CHANNEL","CHAT_MSG_SAY","CHAT_MSG_YELL",
            "CHANNEL_UI_UPDATE","CHANNEL_COUNT_UPDATE","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA"}) do frame:RegisterEvent(name) end
    elseif S.collector then
        if event=="CHAT_MSG_CHANNEL" or event=="CHAT_MSG_SAY" or event=="CHAT_MSG_YELL" then S.collector:Event(event,...)
        else S.collector.channels:Refresh() end
    end
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta;if elapsed<.25 then return end;elapsed=0;S:Tick()
end)
