-- Copyright (c) 2026 WerkoDev. All rights reserved.
local Net = _G.ChannelBus
if not Net.loading then return end

local function identify(rt, name)
    if Net.IsSecret(name) or type(name) ~= "string" then return end
    name = name:gsub("^%d+%.%s*", "")
    return name:lower() == rt.channel.name:lower()
end

local function installFilters(rt)
    if rt.filterInstalled then return end
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if not add then return end
    rt.filter = rt.filter or function(_, _, _, _, _, channelString, _, _, _, _, baseName)
        return identify(rt,baseName) == true or identify(rt,channelString) == true
    end
    add("CHAT_MSG_CHANNEL_NOTICE",rt.filter)
    add("CHAT_MSG_CHANNEL_NOTICE_USER",rt.filter)
    add("CHAT_MSG_CHANNEL",rt.filter)
    rt.filterInstalled=true
end

local function hide(rt)
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local frame=_G["ChatFrame"..i]
        if frame then
            local remove=frame.RemoveChannel or (ChatFrameUtil and ChatFrameUtil.RemoveChannel) or ChatFrame_RemoveChannel
            if remove then pcall(remove,frame,rt.channel.name)
            elseif RemoveChatWindowChannel then pcall(RemoveChatWindowChannel,i,rt.channel.name) end
        end
    end
end

function Net.SendNative(rt,job,part)
    local fn
    if job.logged then fn=C_ChatInfo.SendAddonMessageLogged else fn=C_ChatInfo.SendAddonMessage end
    if not fn then error("send-api-unavailable") end
    -- CHANNEL targets are cstring in 70338, not the legacy numeric assumption.
    return fn(rt.config.prefix,part,"CHANNEL",tostring(rt.channel.id))
end

function Net.UpdateNative(rt,at)
    local active=not IsLoggedIn or IsLoggedIn()
    if not active then rt.ready,rt.transportReady=false,false;return end
    if (rt.nextNative or 0)>at then return end
    rt.nextNative=at+2
    rt.ready,rt.transportReady=false,false
    local api=C_ChatInfo
    local enums=Enum and Enum.RegisterAddonMessagePrefixResult
    if not api or not api.RegisterAddonMessagePrefix or not api.SendAddonMessage
        or not enums or not GetChannelName
        or not Enum.SendAddonMessageResult then rt.error="native-api-unavailable";return end
    if not rt.codecReady then
        local sample={"test",{{1,"test",1,GetServerTime(),30,0,false,0,{label="Русский"}}}}
        local packet,err=Net.Codec.Encode(sample,rt.config.compression)
        local decoded=packet and Net.Codec.Decode(packet.text)
        if not decoded or decoded[2][1][9].label~=sample[2][1][9].label then
            rt.error=err or "codec-self-test";return
        end
        rt.codecReady=true
    end
    if not rt.prefixReady then
        local ok,result=pcall(api.RegisterAddonMessagePrefix,rt.config.prefix)
        if not ok or (result~=enums.Success and result~=enums.DuplicatePrefix) then
            rt.error="prefix-registration:"..tostring(result);return
        end
        rt.prefixReady=true
    end
    installFilters(rt)
    rt.transportReady=true
    local all=true
    local defaultID=GetChannelName(1)
    local canJoin=(type(defaultID)=="number" and defaultID>0) or at-rt.startedAt>=20
    local channel=rt.channel
    do
        local ok,id=pcall(GetChannelName,channel.name)
        channel.id=ok and type(id)=="number" and id>0 and id or 0
        if channel.id==0 then
            all=false
            if canJoin and channel.nextJoin<=at then
                local join=JoinTemporaryChannel or JoinChannelByName
                local joined,result=false,nil
                if join then joined,result=pcall(join,channel.name) end
                channel.error=joined and "joining" or "join-unavailable"
                channel.nextJoin=at+math.min(30,5*(1+(channel.attempts or 0)))
                channel.attempts=(channel.attempts or 0)+1
                -- Confirm on a subsequent scan, never by this return value.
            end
        else channel.error=nil;channel.attempts=0 end
    end
    hide(rt)
    rt.ready,rt.error=all,nil
end

function Net.StartNative(rt)
    rt.startedAt=GetTime()
    if not CreateFrame then rt.error="frame-api-unavailable";return end
    local frame=CreateFrame("Frame")
    rt.frame=frame
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
    frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    frame:SetScript("OnEvent",function(_,event,prefix,packet,chatType,sender,target,zoneID,localID,name)
        if event=="PLAYER_LOGIN" or event=="CHAT_MSG_CHANNEL_NOTICE" then rt.nextNative=0;return end
        if Net.IsSecret(prefix) or Net.IsSecret(chatType) or Net.IsSecret(localID) then return end
        if prefix~=rt.config.prefix or chatType~="CHANNEL" then return end
        local ownChannel=identify(rt,name)
        if not ownChannel and type(localID)=="number" then
            local _,resolved=GetChannelName(localID)
            ownChannel=identify(rt,resolved)
        end
        if not ownChannel then return end
        -- Use current module methods after an embedded minor upgrade.
        local ok,err=pcall(rt.bus.Receive,rt.bus,packet,sender,event=="CHAT_MSG_ADDON_LOGGED")
        if not ok then rt.error="receive-exception:"..tostring(err) end
    end)
    local elapsed=0
    frame:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed<rt.config.tickInterval then return end
        elapsed=0
        local ok,err=pcall(rt.bus.Tick,rt.bus)
        if not ok then rt.error="tick-exception:"..tostring(err) end
    end)
end

-- Loading a provider does not enqueue announcements; consumers call Init/Publish.
-- Diagnostic uses an existing custom configuration, or starts defaults.
SLASH_CHANNELBUS1="/channelbus"
SlashCmdList=SlashCmdList or {}
SlashCmdList.CHANNELBUS=function()
    local bus=Net._runtime and Net._runtime.bus or Net:Init()
    local status=bus:GetStatus()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("ChannelBus "..Net.version..": "..status.state..", queue="..status.queued
            ..", sent="..status.stats.sentBytes..", received="..status.stats.receivedMessages
            ..(status.error and ", "..status.error or ""))
    end
end
Net.loading=false
