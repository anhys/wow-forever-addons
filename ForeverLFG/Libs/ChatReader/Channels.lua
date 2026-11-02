local _,Root=...
local NS=Root.ChatReader or Root
local A,T=NS.Array,NS.Text
local Channels={};Channels.__index=Channels;NS.Channels=Channels
local function safe(v) if NS.Readable(v) then return v end end
local function booleanInfo(method,arg)
    if not C_ChatInfo or type(C_ChatInfo[method])~="function" then return nil,"unavailable" end
    local ok,value
    if arg~=nil then ok,value=pcall(C_ChatInfo[method],arg) else ok,value=pcall(C_ChatInfo[method]) end
    if not ok then return nil,"error" end
    if not NS.Readable(value) then return nil,"restricted" end
    if type(value)~="boolean" then return nil,"invalid" end
    return value,"ok"
end
local function hint(name)
    if type(name)~="string" then return end
    local base=name:gsub("^%d+%.%s*",""):gsub("%s+%-%s+.*$",""):gsub(":.*$","")
    return NS.Lexicon.channels[T.Normalize(base)]
end
Channels.NameHint=hint
local function info(identifier)
    if not C_ChatInfo or not C_ChatInfo.GetChannelInfoFromIdentifier then return nil,"unavailable" end
    local ok,value=pcall(C_ChatInfo.GetChannelInfoFromIdentifier,tostring(identifier))
    if not ok then return nil,"error" end
    if not NS.Readable(value) then return nil,"restricted" end
    if type(value)~="table" then return nil,"empty" end
    local result={}
    for _,key in ipairs({"name","shortcut","localID","instanceID","zoneChannelID","channelType"}) do
        local v=value[key]
        if NS.Readable(v) and (type(v)=="string" or type(v)=="number") then result[key]=v end
    end
    return result,"ok"
end
local function system(entry)
    -- PermanentChatChannelType.Zone=1 in the pinned Forever 70374 API.
    return entry.channelType==1 and type(entry.zoneChannelID)=="number" and entry.zoneChannelID>0 and entry.isCommunitiesChannel~=true
end
local function describe(listName,index,disabled,fromServer)
    local entry={listName=listName,index=index,disabled=disabled,fromServerList=fromServer or false}
    local native,status=info(index or listName)
    if not native and index then native,status=info(listName) end
    entry.lookupStatus=status
    if native then
        for key,value in pairs(native) do if key=="name" then entry.nativeName=value else entry[key]=value end end
    end
    if index and GetChannelName then
        local ok,localID,fullName,instanceID,isCommunity=pcall(GetChannelName,index)
        if ok then
            entry.fullName=safe(fullName);entry.displayLocalID=safe(localID)
            entry.displayInstanceID=safe(instanceID);entry.isCommunitiesChannel=safe(isCommunity)
        end
    end
    entry.isSystem=system(entry)
    if index then entry.isRegional,entry.regionalLookupStatus=booleanInfo("IsChannelRegional",index)
    elseif entry.isSystem then entry.isRegional,entry.regionalLookupStatus=booleanInfo("IsChannelRegionalForChannelID",entry.zoneChannelID) end
    entry.regionalServiceAvailable,entry.regionalServiceStatus=booleanInfo("IsRegionalServiceAvailable")
    entry.name=entry.fullName or entry.nativeName or listName
    -- Name is only a category hint after discovery, never the subscription identity.
    entry.nameHint=hint(entry.nativeName) or hint(entry.fullName) or hint(listName)
    return entry
end
function Channels.New()
    return setmetatable({joined=A(),available=A(),catalogRaw=A(),byLocal={},byZone={},errors=A()},Channels)
end
function Channels:Classify(entry)
    if not entry.isSystem then
        -- Catalog names are hints, not proof that this session can join a channel.
        if entry.fromServerList and entry.lookupStatus=="empty" then
            entry.kind=entry.nameHint;entry.classification="catalog_name_hint"
        end
        return
    end
    local learned=self.byZone[entry.zoneChannelID]
    entry.kind=entry.nameHint or (type(learned)=="string" and learned or nil)
    entry.classification=entry.nameHint and "discovered_name_hint" or entry.kind and "discovered_zone_id" or "unclassified_system"
end
function Channels:Refresh()
    self.joined=A();self.available=A();self.catalogRaw=A();self.byLocal={};self.byZone={};self.errors=A()
    if GetChannelList then
        local ok,list=pcall(function() return {GetChannelList()} end)
        if ok then for i=1,#list,3 do
            local index,name,disabled=list[i],list[i+1],list[i+2]
            if NS.Readable(index) and NS.Readable(name) and NS.Readable(disabled) and type(index)=="number" and type(name)=="string" then
                local entry=describe(name,index,disabled,false)
                self.joined[#self.joined+1]=entry;self.byLocal[index]=entry
            end
        end else self.errors[#self.errors+1]="GetChannelList" end
    end
    if EnumerateServerChannels then
        local ok,list=pcall(function() return {EnumerateServerChannels()} end)
        local byName={}
        if ok then for _,name in ipairs(list) do if NS.Readable(name) and type(name)=="string" then
            self.catalogRaw[#self.catalogRaw+1]=name
            local entry=byName[name]
            if entry then entry.catalogOccurrences=entry.catalogOccurrences+1
            else
                entry=describe(name,nil,nil,true);entry.catalogOccurrences=1;byName[name]=entry
                self.available[#self.available+1]=entry
            end
        end end else self.errors[#self.errors+1]="EnumerateServerChannels" end
    end
    -- Learn semantics from discovered, verified system records, not from hard-coded /2 or guessed DB2 IDs.
    for _,list in ipairs({self.joined,self.available}) do for _,entry in ipairs(list) do
        if entry.isSystem and entry.nameHint then
            local previous=self.byZone[entry.zoneChannelID]
            if previous==nil or previous==entry.nameHint then self.byZone[entry.zoneChannelID]=entry.nameHint
            else self.byZone[entry.zoneChannelID]=false end
        end
    end end
    for _,list in ipairs({self.joined,self.available}) do for _,entry in ipairs(list) do
        self:Classify(entry)
        local joined=entry.localID and self.byLocal[entry.localID]
        entry.subscribed=joined~=nil and joined.disabled~=true
        entry.joinEligible=false
        if not entry.isSystem then entry.joinBlockReason=entry.lookupStatus=="ok" and "not_system_channel" or "metadata_unresolved"
        elseif not entry.kind then entry.joinBlockReason="category_unknown"
        elseif entry.subscribed then entry.joinBlockReason="already_subscribed"
        else entry.joinEligible=true end
    end end
    return {joined=self.joined,available=self.available,catalogRaw=self.catalogRaw,errors=self.errors}
end
function Channels:Resolve(fields)
    if type(fields.channelIndex)~="number" or fields.channelIndex<=0 or type(fields.zoneChannelID)~="number" or fields.zoneChannelID<=0 then return nil,"source_not_allowed" end
    -- Resolve live metadata by the local ID; do not trust a cached name after the number is reused.
    local entry=describe(fields.channelBaseName or fields.channelName or "",fields.channelIndex,nil,false)
    if not entry.isSystem then return nil,entry.lookupStatus~="ok" and "channel_metadata_unavailable" or "source_not_allowed" end
    if entry.localID~=fields.channelIndex or entry.zoneChannelID~=fields.zoneChannelID then return nil,"channel_identity_mismatch" end
    -- Use live native names for the hint, not the message label / old list entry.
    entry.nameHint=hint(entry.nativeName) or hint(entry.fullName)
    if not entry.nameHint and self.byZone[entry.zoneChannelID]==nil then self:Refresh() end
    self:Classify(entry)
    if not entry.kind then return nil,"channel_category_unknown" end
    entry.event="CHAT_MSG_CHANNEL"
    entry.identity=NS.JSON({localID=entry.localID,zoneChannelID=entry.zoneChannelID,instanceID=entry.instanceID,nativeName=entry.nativeName,fullName=entry.fullName,isRegional=entry.isRegional})
    return entry
end
function Channels:JoinAvailable(enabled)
    local requested=A();if not JoinPermanentChannel then return requested,"api_unavailable" end
    self:Refresh()
    local requestedNames={}
    for _,entry in ipairs(self.available) do
        if entry.joinEligible and enabled[entry.kind] and not requestedNames[entry.listName] then
            local ok=pcall(JoinPermanentChannel,entry.listName,nil,nil,1)
            requested[#requested+1]={name=entry.listName,zoneChannelID=entry.zoneChannelID,instanceID=entry.instanceID,callSucceeded=ok}
            requestedNames[entry.listName]=true -- distinct available regional names are not collapsed by kind.
        end
    end
    return requested
end
