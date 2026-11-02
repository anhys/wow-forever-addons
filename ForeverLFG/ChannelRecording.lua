-- Explicit ten-minute captures, independent from the 200-entry live journal.
local _,NS=...
local R={duration=600,active=false,entries={}}
NS.ChannelRecording=R
local english={
    RECORD_START="Record 10 minutes",RECORD_STOP="Stop",RECORD_COPY="Copy recording",
    RECORD_IDLE="Recording has not started. The entire capture is kept until reload or a new recording.",
    RECORD_ACTIVE="Recording %s remaining - events: %d",
    RECORD_DONE="Recording saved: %s - events: %d",
    RECORD_TITLE="10-minute exchange recording",RECORD_EMPTY="No recording yet.",
    RECORD_FINISHED="Recording finished. Open /flfg dchanel and copy the recording.",
    RECORD_COPY_HINT="The entire recording is selected, including all message types. Press Ctrl+C (Mac: Cmd+C). New events do not change this snapshot.",
}
local russian={
    RECORD_START="Записать 10 минут",RECORD_STOP="Остановить",RECORD_COPY="Копировать запись",
    RECORD_IDLE="Запись не начата. Весь сбор хранится до перезагрузки или новой записи.",
    RECORD_ACTIVE="Запись: осталось %s - событий: %d",
    RECORD_DONE="Запись сохранена: %s - событий: %d",
    RECORD_TITLE="Запись обмена за 10 минут",RECORD_EMPTY="Запись ещё не начата.",
    RECORD_FINISHED="Запись завершена. Откройте /flfg dchanel и скопируйте запись.",
    RECORD_COPY_HINT="Выделена вся запись обмена, включая все типы сообщений. Нажмите Ctrl+C (Mac: Cmd+C). Новые события не меняют этот снимок.",
}
local translations={ruRU=russian,
    deDE={RECORD_START="10 Minuten aufzeichnen",RECORD_STOP="Stoppen",RECORD_COPY="Aufzeichnung kopieren",
        RECORD_IDLE="Noch keine Aufzeichnung. Gespeichert bis zum Neuladen oder zur nächsten Aufzeichnung.",
        RECORD_ACTIVE="Aufzeichnung: noch %s - Ereignisse: %d",RECORD_DONE="Gespeichert: %s - Ereignisse: %d",
        RECORD_TITLE="10-Minuten-Aufzeichnung",RECORD_EMPTY="Noch keine Aufzeichnung.",
        RECORD_FINISHED="Aufzeichnung beendet. Mit /flfg dchanel öffnen und kopieren.",
        RECORD_COPY_HINT="Die gesamte Aufzeichnung ist ausgewählt. Strg+C (Mac: Cmd+C) kopiert. Neue Ereignisse ändern diese Momentaufnahme nicht."},
    frFR={RECORD_START="Enregistrer 10 minutes",RECORD_STOP="Arrêter",RECORD_COPY="Copier la session",
        RECORD_IDLE="Aucune session. Conservation jusqu'au rechargement ou à la prochaine session.",
        RECORD_ACTIVE="Enregistrement : reste %s - événements : %d",RECORD_DONE="Session conservée : %s - événements : %d",
        RECORD_TITLE="Échanges sur 10 minutes",RECORD_EMPTY="Aucune session.",
        RECORD_FINISHED="Session terminée. Ouvrez /flfg dchanel pour la copier.",
        RECORD_COPY_HINT="Toute la session est sélectionnée. Ctrl+C (Mac : Cmd+C) copie cet instantané, qui reste inchangé à l'arrivée de nouveaux événements."},
    esES={RECORD_START="Grabar 10 minutos",RECORD_STOP="Detener",RECORD_COPY="Copiar grabación",
        RECORD_IDLE="Sin grabación. Se conserva hasta recargar o iniciar otra grabación.",
        RECORD_ACTIVE="Grabando: quedan %s - eventos: %d",RECORD_DONE="Grabación guardada: %s - eventos: %d",
        RECORD_TITLE="Intercambio de 10 minutos",RECORD_EMPTY="Aún no hay grabación.",
        RECORD_FINISHED="Grabación finalizada. Abre /flfg dchanel para copiarla.",
        RECORD_COPY_HINT="Toda la grabación está seleccionada. Pulsa Ctrl+C (Mac: Cmd+C). Los nuevos eventos no cambian esta captura."},
    zhCN={RECORD_START="记录10分钟",RECORD_STOP="停止",RECORD_COPY="复制记录",
        RECORD_IDLE="尚未开始记录。保留到重载或开始新记录。",
        RECORD_ACTIVE="记录中：剩余%s - 事件：%d",RECORD_DONE="记录已保留：%s - 事件：%d",
        RECORD_TITLE="10分钟交换记录",RECORD_EMPTY="尚无记录。",
        RECORD_FINISHED="记录完成。打开 /flfg dchanel 复制记录。",
        RECORD_COPY_HINT="已选中全部记录。按 Ctrl+C（Mac：Cmd+C）复制。新事件不会更改此快照。"},
    zhTW={RECORD_START="記錄10分鐘",RECORD_STOP="停止",RECORD_COPY="複製記錄",
        RECORD_IDLE="尚未開始記錄。保留至重載或開始新記錄。",
        RECORD_ACTIVE="記錄中：剩餘%s - 事件：%d",RECORD_DONE="記錄已保留：%s - 事件：%d",
        RECORD_TITLE="10分鐘交換記錄",RECORD_EMPTY="尚無記錄。",
        RECORD_FINISHED="記錄完成。開啟 /flfg dchanel 複製記錄。",
        RECORD_COPY_HINT="已選取全部記錄。按 Ctrl+C（Mac：Cmd+C）複製。新事件不會變更此快照。"},
}
for key,value in pairs(english) do NS.english[key]=value end
local selected=translations[NS.clientLocale=="esMX" and "esES" or NS.clientLocale]
if selected and NS.translation then for key,value in pairs(selected) do NS.translation[key]=value end end
NS.english.RECORD_LOCAL="Local"
local localLabels={ruRU="Локально",deDE="Lokal",frFR="Local",esES="Local",esMX="Local",zhCN="本地",zhTW="本機"}
if NS.translation and localLabels[NS.clientLocale] then NS.translation.RECORD_LOCAL=localLabels[NS.clientLocale] end
local function snapshot(value)
    if value==nil then return end
    local ok,result=pcall(ChannelBus.Copy,value,{nodes=4096,depth=12,bytes=65536,stringBytes=32768})
    return ok and result or {error="diagnostic-data-unavailable"}
end
function R:Refresh()
    local f=NS.QuestWindow
    if not f or not f.RecordStatus then return end
    local seconds,key=0,"RECORD_IDLE"
    if self.active then seconds=math.max(0,math.ceil(self.deadline-GetTime()));key="RECORD_ACTIVE"
    elseif self.startedAt then seconds=math.max(0,math.floor(self.elapsed));key="RECORD_DONE" end
    f.RecordStatus:SetText(NS.Text(key,string.format("%02d:%02d",math.floor(seconds/60),seconds%60),#self.entries))
    f.RecordStart:SetEnabled(not self.active)
    f.RecordStop:SetEnabled(self.active)
    f.RecordCopy:SetEnabled(self.startedAt~=nil)
end
function R:Stop(reason)
    if not self.active then return end
    local at=math.min(GetTime(),self.deadline)
    self.active=false;self.elapsed=math.max(0,at-self.started)
    self.endedAt=self.startedAt+self.elapsed
    self.reason=reason or "manual"
    self:Refresh()
    if self.reason=="completed" then print("ForeverLFG: "..NS.Text("RECORD_FINISHED")) end
end
function R:Tick()
    if self.active and GetTime()>=self.deadline then self:Stop("completed") end
    self:Refresh()
end
function R:Start()
    self:Tick()
    if self.active then return false end
    self.entries={};self.started=GetTime();self.deadline=self.started+self.duration
    self.startedAt=time();self.endedAt=nil;self.elapsed=0;self.reason=nil
    self.context=NS.Context()
    self.context.player=NS.Quests:GetUnitName()
    self.context.questDebugAll=NS.Quests:DebugAll()
    local q=NS.Quests
    self.context.questExchange=snapshot({revision=q.revision,localState=q.localState,lastPublished=q.lastPublished,
        dirty=q.dirtyAt~=nil,retry=q.retryPublish==true,pending=q.outgoing and not q.outgoing.finished or false,
        heartbeat=q.nextHeartbeat~=math.huge,error=q.error})
    if q.bus then
        local ok,status=pcall(q.bus.GetStatus,q.bus)
        if ok then self.context.channelBus=snapshot(status) end
    end
    self.active=true;self:Refresh()
    return true
end
function R:Add(direction,obj,meta,kind)
    self:Tick()
    if not self.active then return end
    -- Observe supplies private copies. Retain them before the live UI reduces
    -- trade.chat to a summary; no item/byte cap may silently drop the beginning.
    self.entries[#self.entries+1]={at=time(),elapsed=GetTime()-self.started,
        direction=direction,kind=kind,meta=meta,obj=obj}
    self:Refresh()
end
function NS.RecordDiagnostic(event,details)
    if not R.active then return end
    R:Add("local",snapshot(details),{type="flfg.local",event=event},"diagnostic")
end
local frame=CreateFrame("Frame")
R.frame=frame
local elapsed=0
frame:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=.25 then elapsed=0;R:Tick() end
end)
