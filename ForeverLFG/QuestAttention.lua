-- Local attention state; no extra exchange, popup, whisper or invite.
local _,NS=...
local Q=NS.Quests
local A={seen={},pending={},queued={},nextSound=0}
NS.QuestAttention=A
local function key(match) return match.questID.."\31"..match.sender end
function NS.QuestAttentionSettings()
    local s=NS.Database().settings
    if type(s.questMatchAnimation)~="boolean" then s.questMatchAnimation=true end
    if type(s.questMatchSound)~="boolean" then s.questMatchSound=true end
    return s
end
function NS.PlayQuestMatchSound()
    local kit=SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST
    if type(kit)~="number" or (issecretvalue and issecretvalue(kit)) or not C_Sound then return false end
    local ok,success
    if type(C_Sound.PlaySoundWithOptions)=="function" then
        ok,success=pcall(C_Sound.PlaySoundWithOptions,{soundKitID=kit,forceNoDuplicates=true,volumeOverride=.55})
    elseif type(C_Sound.PlaySound)=="function" then
        ok,success=pcall(C_Sound.PlaySound,kit,nil,true,false,nil,.55)
    end
    return ok==true and not (issecretvalue and issecretvalue(success)) and success==true
end
function A:Count()
    local n=0;for _ in pairs(self.pending) do n=n+1 end;return n
end
function A:Acknowledge()
    self.pending={};self.queued={};self.batchAt=nil
    if NS.StopQuestAttention then NS.StopQuestAttention() end
    if NS.RefreshQuestAttention then NS.RefreshQuestAttention() end
end
function A:Update(items)
    local active={};local now=GetTime()
    if Q.localState then
        for _,id in ipairs(Q.localState.quests) do active[id]=true end
        for id,senders in pairs(self.seen) do
            if not active[id] then self.seen[id]=nil
            else
                for sender,at in pairs(senders) do if at<now-1800 then senders[sender]=nil end end
            end
        end
    end
    local current={}
    local open=NS.QuestMatchesWindow and NS.QuestMatchesWindow:IsShown()
    for _,match in ipairs(items) do
        local k=key(match);current[k]=true
        local senders=self.seen[match.questID] or {};self.seen[match.questID]=senders
        if not senders[match.sender] and not open then
            self.pending[k]=match;self.queued[k]=true
            if not self.batchAt then self.batchAt=now+2 end
        end
        senders[match.sender]=now
    end
    for k in pairs(self.pending) do if not current[k] then self.pending[k]=nil;self.queued[k]=nil end end
    if open then self:Acknowledge();return end
    if not next(self.queued) then self.batchAt=nil end
    if not next(self.pending) and NS.StopQuestAttention then NS.StopQuestAttention() end
    if NS.RefreshQuestAttention then NS.RefreshQuestAttention() end
end
function A:Tick()
    if not self.batchAt or GetTime()<self.batchAt or not NS.QuestLauncher then return end
    -- Recheck local quests/zone before alerting; publication still uses Q's throttle.
    local obj=Q:Collect()
    if not obj then self.batchAt=GetTime()+5;return end
    Q.localState=obj;Q:MarkDirty();Q:Changed()
    if not self.batchAt or GetTime()<self.batchAt then return end
    self.batchAt=nil;self.queued={}
    local s=NS.QuestAttentionSettings()
    if s.questMatchAnimation and NS.PlayQuestAttention then NS.PlayQuestAttention() end
    if s.questMatchSound and GetTime()>=self.nextSound then
        self.nextSound=GetTime()+30;NS.PlayQuestMatchSound()
    end
end
function NS.SetQuestMatchAnimation(enabled)
    NS.QuestAttentionSettings().questMatchAnimation=enabled==true
    if not enabled and NS.StopQuestAttention then NS.StopQuestAttention() end
end
function NS.SetQuestMatchSound(enabled)
    NS.QuestAttentionSettings().questMatchSound=enabled==true
end
