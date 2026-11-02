-- Open an editable private draft, verifying the recipient after chat-addon hooks.
local _,NS=...
local T,safe=NS.Text,NS.QuestSafeText
local function plain(value) return not (issecretvalue and issecretvalue(value)) end
local function sameTarget(value,expected)
    if not plain(value) or not plain(expected) or type(value)~="string" or type(expected)~="string" then return false end
    local function normalized(name)
        local character,realm=name:match("^(.-)%-(.*)$")
        return realm and (character.."-"..realm:gsub(" ","")) or name
    end
    return normalized(value)==normalized(expected)
end
local function read(box,method,...)
    if not box or type(box[method])~="function" then return end
    local ok,value=pcall(box[method],box,...)
    if ok and plain(value) then return value end
end
local function wimTarget(box,sender)
    -- WIM exposes its focused edit box, with the recipient on the parent window.
    -- This adapter only inspects the window opened by the common whisper route.
    if type(WIM)~="table" or WIM.EditBoxInFocus~=box or box.widgetName~="msg_box" then return false end
    local win=read(box,"GetParent")
    return win and win.type=="whisper" and not win.isBN and sameTarget(win.theUser,sender)
end
local function verified(box,sender)
    if not box or not plain(box) then return false end
    local kind=read(box,"GetChatType") or read(box,"GetAttribute","chatType")
    local target=read(box,"GetTellTarget") or read(box,"GetAttribute","tellTarget")
    return (kind=="WHISPER" and sameTarget(target,sender)) or wimTarget(box,sender)
end
local function keyboardFocus()
    if type(GetCurrentKeyBoardFocus)~="function" then return nil,false end
    local ok,box=pcall(GetCurrentKeyBoardFocus)
    return ok and plain(box) and box or nil,true
end
local function fill(box,sender,draft)
    if type(box.SetText)~="function" or not verified(box,sender) then return false end
    local ok,prepared=pcall(function()
        if wimTarget(box,sender) then box.setText=0;box.textToSet="" end
        box:SetText(draft)
        if box.SetFocus then box:SetFocus() end
        local focus,known=keyboardFocus()
        if not verified(box,sender) or (known and focus~=box) then return false end
        if NS.ApplyMultilingualFont then box.foreverLFGFontResult=NS.ApplyMultilingualFont(box,draft) end
        focus,known=keyboardFocus()
        return verified(box,sender) and (not known or focus==box)
    end)
    if ok and prepared then return true end
    -- OnTextChanged/OnEditFocusGained hooks may have changed the destination.
    pcall(box.SetText,box,"")
    return false
end
local function commonRoute(sender,draft)
    local api=ChatFrameUtil
    if not api or type(api.ChooseBoxForSend)~="function" or type(api.OpenChat)~="function" then return false end
    -- Activating an empty edit box first lets addons install their normal hooks.
    local edit=api.OpenChat("",DEFAULT_CHAT_FRAME) or api.ChooseBoxForSend(DEFAULT_CHAT_FRAME)
    if not edit or not edit.SetChatType or not edit.SetTellTarget or not edit.UpdateHeader then return false end
    if edit.setText==1 and plain(edit.text) and edit.text=="" then edit.setText=0;edit.text=nil end
    edit:SetChatType("WHISPER");edit:SetTellTarget(sender);edit:UpdateHeader()
    local candidates,seen={},{}
    local function add(box) if box and plain(box) and not seen[box] then seen[box]=true;candidates[#candidates+1]=box end end
    add(keyboardFocus())
    if type(api.GetActiveWindow)=="function" then add(api.GetActiveWindow()) end
    add(CHAT_FOCUS_OVERRIDE)
    add(edit)
    for _,box in ipairs(candidates) do
        if verified(box,sender) and fill(box,sender,draft) then return true,wimTarget(box,sender) and "wim" or "native",box end
    end
    return false
end
local function failed() print("ForeverLFG: "..T("QUEST_WHISPER_FAILED")) end
local function fallback(sender,draft)
    local f=NS.WhisperComposer
    if not f then
        f=CreateFrame("Frame","ForeverLFGWhisperComposer",UIParent,"BackdropTemplate");NS.WhisperComposer=f
        f:SetSize(480,184);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true)
        f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
        f:SetBackdropBorderColor(.7,.56,.22,1);f:SetBackdropColor(.03,.03,.02,.95)
        local header=CreateFrame("Frame",nil,f);header:SetPoint("TOPLEFT",8,-8);header:SetPoint("TOPRIGHT",-36,-8);header:SetHeight(26)
        header:EnableMouse(true);header:RegisterForDrag("LeftButton");header:SetScript("OnDragStart",function() f:StartMoving() end)
        header:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        local title=header:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("LEFT",8,0);title:SetText(T("QUEST_WHISPER_TITLE"))
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-2,-2);close:SetScript("OnClick",function() f:Hide() end)
        f.Recipient=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.Recipient:SetPoint("TOPLEFT",16,-40);f.Recipient:SetPoint("TOPRIGHT",-16,-40)
        f.Recipient:SetHeight(18);f.Recipient:SetJustifyH("LEFT");f.Recipient:SetMaxLines(1)
        local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");hint:SetPoint("TOPLEFT",16,-62);hint:SetPoint("TOPRIGHT",-16,-62)
        hint:SetHeight(28);hint:SetJustifyH("LEFT");hint:SetWordWrap(true);hint:SetText(T("QUEST_WHISPER_COMPOSE_HINT"))
        local border=CreateFrame("Frame",nil,f,"BackdropTemplate");border:SetPoint("TOPLEFT",14,-96);border:SetPoint("TOPRIGHT",-14,-96);border:SetHeight(32)
        border:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        border:SetBackdropColor(0,0,0,.75)
        local edit=CreateFrame("EditBox",nil,border);f.Edit=edit
        edit:SetPoint("TOPLEFT",8,-4);edit:SetPoint("BOTTOMRIGHT",-8,4);edit:SetFontObject("ChatFontNormal")
        edit:SetAutoFocus(false);edit:SetMultiLine(false);edit:SetMaxBytes(255)
        local function send()
            if InCombatLockdown() or not f.target then return end
            local text=edit:GetText()
            if not plain(text) or type(text)~="string" or not text:find("%S") or #text>255 or text:find("[%z\1-\31]") then return end
            local api=C_ChatInfo and C_ChatInfo.SendChatMessage
            if type(api)~="function" then failed();return end
            -- Only this explicit click/Enter submits. Never inherit a chat type.
            local ok=pcall(api,text,"WHISPER",nil,f.target)
            if ok then f:Hide() else failed() end
        end
        f.Send=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.Send:SetSize(208,24);f.Send:SetPoint("BOTTOMRIGHT",-16,14)
        f.Send:SetText(T("QUEST_WHISPER_SEND"));f.Send:SetScript("OnClick",send)
        edit:SetScript("OnEnterPressed",send);edit:SetScript("OnEscapePressed",function() f:Hide() end)
        f:SetScript("OnHide",function() f.target=nil;edit:SetText("");edit:ClearFocus() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ForeverLFGWhisperComposer" end
    end
    f.target=sender;f.Recipient:SetText(T("QUEST_WHISPER_TO",safe(sender)));f.Edit:SetText(draft)
    f:Show();f.Edit:SetFocus()
    if NS.ApplyMultilingualFont then f.Edit.foreverLFGFontResult=NS.ApplyMultilingualFont(f.Edit,draft) end
    return f.Edit
end
function NS.OpenPrivateDraft(sender,draft)
    if InCombatLockdown() then return end
    local ok,prepared,route,box=pcall(commonRoute,sender,draft)
    if not (ok and prepared) then
        -- A custom editor without verifiable whisper state gets a controlled draft.
        ok,box=pcall(fallback,sender,draft);route="fallback"
        if not ok then failed();box=nil;route="failed" end
    end
    if NS.RecordDiagnostic then
        local file,height,flags=NS.ChatFontInfo(box)
        NS.RecordDiagnostic("whisper.route",{sender=sender,route=route,bytes=#draft,
            fontResult=box and box.foreverLFGFontResult,font=file,fontHeight=height,fontFlags=flags,
            fontAlphabets=box and box.foreverLFGFontAlphabets,text=read(box,"GetText")})
    end
end
