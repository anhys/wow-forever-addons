-- A stable, selectable snapshot of the active diagnostics tab; no chat submission.
local _,NS=...
local T=NS.Text
local function quote(value)
    -- Keep UTF-8 readable, while making controls and WoW markup inert and reversible.
    return '"'..value:gsub('[%z\1-\31|\\"]',function(char)
        if char=='"' or char=='\\' then return '\\'..char end
        return string.format('\\%03d',string.byte(char))
    end)..'"'
end
local function serialize(value,seen)
    local typ=type(value)
    if typ=="string" then return quote(value) end
    if typ=="number" or typ=="boolean" or typ=="nil" then return tostring(value) end
    if typ~="table" then return quote("<"..typ..">") end
    seen=seen or {}
    if seen[value] then return quote("<cycle>") end
    seen[value]=true
    local keys,parts={},{}
    for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)
        local ta,tb=type(a),type(b)
        if ta~=tb then return ta<tb end
        if ta=="number" or ta=="string" then return a<b end
        return tostring(a)<tostring(b)
    end)
    for _,key in ipairs(keys) do
        parts[#parts+1]="["..serialize(key,seen).."]="..serialize(value[key],seen)
    end
    seen[value]=nil
    return "{"..table.concat(parts,", ").."}"
end
local function recordingText()
    local r=NS.ChannelRecording;r:Tick()
    local lines={T("CHANNEL_TITLE").." - "..T("RECORD_TITLE"),T("CHANNEL_RECORDS",#r.entries),""}
    if not r.startedAt then lines[#lines+1]=T("RECORD_EMPTY");return table.concat(lines,"\n") end
    local duration=r.active and math.min(r.duration,GetTime()-r.started) or r.elapsed
    lines[#lines+1]="capture="..serialize({startedAt=r.startedAt,endedAt=r.endedAt,elapsed=duration,
        plannedSeconds=r.duration,state=r.active and "recording" or r.reason,context=r.context})
    lines[#lines+1]=""
    -- Captures are chronological and always contain all types and directions.
    for i,entry in ipairs(r.entries) do
        local direction=T(entry.direction=="local" and "RECORD_LOCAL" or entry.direction=="sent" and "CHANNEL_SENT" or entry.direction=="received" and "CHANNEL_RECEIVED" or "CHANNEL_ERROR")
        lines[#lines+1]=string.format("#%d +%.3fs ",i,entry.elapsed)..date("%Y-%m-%d %H:%M:%S",entry.at).." "..direction
        lines[#lines+1]="meta="..serialize(entry.meta)
        lines[#lines+1]="data="..serialize(entry.obj)
        lines[#lines+1]=""
    end
    return table.concat(lines,"\n")
end
function NS.ChannelTabText(filter)
    if filter=="recording" then return recordingText() end
    local entries=NS.ChannelTabEntries(filter)
    local lines={T("CHANNEL_TITLE").." - "..T("CHANNEL_FILTER_"..filter:upper()),T("CHANNEL_RECORDS",#entries),""}
    for _,entry in ipairs(entries) do
        if filter=="matches" then
            lines[#lines+1]=serialize(entry)
        else
            local direction=T(entry.direction=="sent" and "CHANNEL_SENT" or entry.direction=="received" and "CHANNEL_RECEIVED" or "CHANNEL_ERROR")
            lines[#lines+1]=date("%Y-%m-%d %H:%M:%S",entry.at).." "..direction
            lines[#lines+1]="meta="..serialize(entry.meta)
            lines[#lines+1]="data="..serialize(entry.obj)
        end
        lines[#lines+1]=""
    end
    if #entries==0 then lines[#lines+1]=T(filter=="matches" and "QUEST_NO_MATCHES" or "CHANNEL_EMPTY") end
    return table.concat(lines,"\n")
end
function NS.OpenChannelCopy(filter)
    local f=NS.ChannelCopyWindow
    if not f then
        local parent=NS.EnsureQuestWindow()
        f=CreateFrame("Frame","ForeverLFGChannelCopyWindow",parent,"BackdropTemplate")
        NS.ChannelCopyWindow=f
        f:Hide();f:SetSize(math.min(740,parent:GetWidth()-32),430);f:SetPoint("CENTER",parent,"CENTER")
        f:SetFrameStrata("DIALOG");f:SetFrameLevel(parent:GetFrameLevel()+10);f:SetClampedToScreen(true);f:EnableMouse(true)
        f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
        f.Title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.Title:SetPoint("TOPLEFT",18,-16);f.Title:SetPoint("TOPRIGHT",-38,-16);f.Title:SetJustifyH("LEFT")
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5)
        close:SetScript("OnClick",function() f:Hide() end)
        local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.Hint=hint
        hint:SetPoint("TOPLEFT",18,-44);hint:SetPoint("TOPRIGHT",-18,-44);hint:SetJustifyH("LEFT");hint:SetWordWrap(true)
        hint:SetText(T("CHANNEL_COPY_HINT"))
        local scroll=CreateFrame("ScrollFrame",nil,f,"ScrollFrameTemplate");f.Scroll=scroll
        scroll:SetPoint("TOPLEFT",20,-90);scroll:SetPoint("BOTTOMRIGHT",-40,52)
        local bar=CreateFrame("EventFrame",nil,f,"MinimalScrollBar");f.ScrollBar=bar
        bar:SetPoint("TOPRIGHT",-18,-90);bar:SetPoint("BOTTOMRIGHT",-18,52)
        ScrollUtil.InitScrollFrameWithScrollBar(scroll,bar)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel",function(_,delta)
            scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*40)))
        end)
        local edit=CreateFrame("EditBox",nil,scroll);f.Edit=edit
        edit:SetPoint("TOPLEFT");edit:SetWidth(f:GetWidth()-64);edit:SetHeight(1)
        edit:SetFontObject("ChatFontNormal");edit:SetAutoFocus(false);edit:SetMultiLine(true);edit:SetMaxLetters(0);edit:SetMaxBytes(0)
        scroll:SetScrollChild(edit)
        edit:SetScript("OnEscapePressed",function() f:Hide() end)
        edit:SetScript("OnTextChanged",function(self,userInput)
            if userInput then self:SetText(f.snapshot or "") end
            scroll:UpdateScrollChildRect()
        end)
        edit:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local top=-y;local offset=scroll:GetVerticalScroll()
            if top<offset then scroll:SetVerticalScroll(top)
            elseif top+height>offset+scroll:GetHeight() then scroll:SetVerticalScroll(top+height-scroll:GetHeight()) end
        end)
        local selectAll=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.SelectAll=selectAll
        selectAll:SetSize(220,24);selectAll:SetPoint("BOTTOM",0,16);selectAll:SetText(T("CHANNEL_SELECT_ALL"))
        selectAll:SetScript("OnClick",function() edit:SetFocus();edit:HighlightText() end)
        f:SetScript("OnHide",function() edit:ClearFocus();f.snapshot=nil;edit:SetText("") end)
        parent:HookScript("OnHide",function() f:Hide() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ForeverLFGChannelCopyWindow" end
    end
    f.Hint:SetText(T(filter=="recording" and "RECORD_COPY_HINT" or "CHANNEL_COPY_HINT"))
    f.snapshot=NS.ChannelTabText(filter)
    f.Title:SetText(T("CHANNEL_COPY_TITLE",filter=="recording" and T("RECORD_TITLE") or T("CHANNEL_FILTER_"..filter:upper())))
    f.Edit:SetText(f.snapshot)
    if NS.ApplyMultilingualFont then NS.ApplyMultilingualFont(f.Edit,f.snapshot) end
    f:Show();f.Edit:SetFocus();f.Edit:HighlightText();f.Scroll:SetVerticalScroll(0)
end
