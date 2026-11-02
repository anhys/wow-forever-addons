-- Dark metal outside; quiet native bevels on cards and controls.
local _,NS=...
local media="Interface\\AddOns\\ForeverLFG\\Media\\"
local font=({ruRU="Fonts\\FRIZQT___CYR.TTF",koKR="Fonts\\2002.TTF",zhCN="Fonts\\ARKai_T.ttf",zhTW="Fonts\\blei00d.TTF"})[NS.clientLocale] or "Fonts\\FRIZQT__.TTF"
function NS.QuestFont(text,size,r,g,b)
    text:SetFont(font,size,"");text:SetShadowOffset(1,-1);text:SetShadowColor(0,0,0,1)
    text:SetTextColor(r or .96,g or .83,b or .42,1)
end
local function extent(text,method)
    local fn=text[method];if type(fn)~="function" then return end
    local ok,value=pcall(fn,text)
    if ok and not (issecretvalue and issecretvalue(value)) and type(value)=="number" and value>=0 and value<10000 then return value end
end
function NS.QuestTextWidth(text)
    return math.ceil(extent(text,"GetUnboundedStringWidth") or extent(text,"GetStringWidth") or 1)
end
function NS.QuestTextHeight(text,minimum)
    -- Give wrapped text room to measure before replacing the previous height.
    text:SetHeight(128)
    local height=math.max(minimum,math.ceil(extent(text,"GetStringHeight") or 0)+2)
    text:SetHeight(height);return height
end
function NS.TintQuestBorder(frame,r,g,b,a)
    frame.borderTint={r,g,b,a or 1}
    if frame.CardBorder then frame.CardBorder:SetBackdropBorderColor(r,g,b,a or 1) end
    for _,texture in ipairs(frame.BorderParts or {}) do texture:SetVertexColor(r,g,b,a or 1) end
end
function NS.ApplyQuestBorder(frame)
    local border=CreateFrame("Frame",nil,frame,"BackdropTemplate");frame.CardBorder=border
    border:SetAllPoints(frame);border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
    NS.TintQuestBorder(frame,.48,.39,.26)
end
function NS.ApplyQuestDialogBorder(frame,corner)
    local c,e=216/2048,1254/2048
    local parts={
        {"TOPLEFT",0,c,0,c}, {"TOPRIGHT",e-c,e,0,c},
        {"BOTTOMLEFT",0,c,e-c,e}, {"BOTTOMRIGHT",e-c,e,e-c,e},
    }
    frame.BorderParts={}
    local function texture(l,r,t,b)
        local tex=frame:CreateTexture(nil,"OVERLAY",nil,1);tex:SetTexture(media.."QuestFrameV2.tga")
        tex:SetTexCoord(l,r,t,b);frame.BorderParts[#frame.BorderParts+1]=tex;return tex
    end
    local corners={}
    for _,p in ipairs(parts) do
        local tex=texture(p[2],p[3],p[4],p[5]);tex:SetSize(corner,corner);tex:SetPoint(p[1],frame,p[1],0,0);corners[p[1]]=tex
    end
    local top=texture(c,e-c,0,c);top:SetHeight(corner);top:SetPoint("TOPLEFT",corners.TOPLEFT,"TOPRIGHT");top:SetPoint("TOPRIGHT",corners.TOPRIGHT,"TOPLEFT")
    local bottom=texture(c,e-c,e-c,e);bottom:SetHeight(corner);bottom:SetPoint("BOTTOMLEFT",corners.BOTTOMLEFT,"BOTTOMRIGHT");bottom:SetPoint("BOTTOMRIGHT",corners.BOTTOMRIGHT,"BOTTOMLEFT")
    local left=texture(0,c,c,e-c);left:SetWidth(corner);left:SetPoint("TOPLEFT",corners.TOPLEFT,"BOTTOMLEFT");left:SetPoint("BOTTOMLEFT",corners.BOTTOMLEFT,"TOPLEFT")
    local right=texture(e-c,e,c,e-c);right:SetWidth(corner);right:SetPoint("TOPRIGHT",corners.TOPRIGHT,"BOTTOMRIGHT");right:SetPoint("BOTTOMRIGHT",corners.BOTTOMRIGHT,"TOPRIGHT")
    NS.TintQuestBorder(frame,1,1,1,1)
end
function NS.QuestSurface(frame,r,g,b)
    frame.Surface=frame:CreateTexture(nil,"BACKGROUND")
    frame.Surface:SetPoint("TOPLEFT",3,-3);frame.Surface:SetPoint("BOTTOMRIGHT",-3,3)
    -- Solid color stays opaque regardless of any stock texture's alpha.
    frame.Surface:SetColorTexture(r or .065,g or .047,b or .028,1)
end
function NS.QuestHeader(frame,faction)
    if not frame.FactionTexture then
        frame.FactionTexture=frame:CreateTexture(nil,"BACKGROUND",nil,1)
        frame.FactionTexture:SetPoint("TOPLEFT",3,-3);frame.FactionTexture:SetPoint("BOTTOMRIGHT",-3,3)
    end
    -- Local player's faction controls artwork only, never the matching protocol.
    if faction=="Horde" or faction=="Alliance" then
        if frame.factionStyle~=faction then
            frame.FactionTexture:SetTexture(media.."QuestHeader"..faction..".tga")
            frame.FactionTexture:SetTexCoord(0,2172/4096,0,724/1024)
        end
        frame.FactionTexture:Show()
        frame.factionStyle=faction
    else frame.FactionTexture:Hide();frame.factionStyle=nil end
end
function NS.QuestParchment(frame)
    -- Nine slices keep the natural paper edges while the section grows downward.
    local c,e=150/2048,1254/2048
    local function piece(l,r,t,b)
        local tex=frame:CreateTexture(nil,"BACKGROUND");tex:SetTexture(media.."QuestSectionPaper.tga")
        tex:SetTexCoord(l,r,t,b);return tex
    end
    local corners={};local parts={}
    for _,p in ipairs({{"TOPLEFT",0,c,0,c},{"TOPRIGHT",e-c,e,0,c},{"BOTTOMLEFT",0,c,e-c,e},{"BOTTOMRIGHT",e-c,e,e-c,e}}) do
        local tex=piece(p[2],p[3],p[4],p[5]);tex:SetSize(12,12);tex:SetPoint(p[1],frame,p[1]);corners[p[1]]=tex;parts[#parts+1]=tex
    end
    local top=piece(c,e-c,0,c);top:SetHeight(12);top:SetPoint("TOPLEFT",corners.TOPLEFT,"TOPRIGHT");top:SetPoint("TOPRIGHT",corners.TOPRIGHT,"TOPLEFT")
    local bottom=piece(c,e-c,e-c,e);bottom:SetHeight(12);bottom:SetPoint("BOTTOMLEFT",corners.BOTTOMLEFT,"BOTTOMRIGHT");bottom:SetPoint("BOTTOMRIGHT",corners.BOTTOMRIGHT,"BOTTOMLEFT")
    local left=piece(0,c,c,e-c);left:SetWidth(12);left:SetPoint("TOPLEFT",corners.TOPLEFT,"BOTTOMLEFT");left:SetPoint("BOTTOMLEFT",corners.BOTTOMLEFT,"TOPLEFT")
    local right=piece(e-c,e,c,e-c);right:SetWidth(12);right:SetPoint("TOPRIGHT",corners.TOPRIGHT,"BOTTOMRIGHT");right:SetPoint("BOTTOMRIGHT",corners.BOTTOMRIGHT,"TOPRIGHT")
    local middle=piece(c,e-c,c,e-c);middle:SetPoint("TOPLEFT",12,-12);middle:SetPoint("BOTTOMRIGHT",-12,12)
    for _,tex in ipairs({top,bottom,left,middle,right}) do parts[#parts+1]=tex end
    frame.Parchment,frame.ParchmentParts=middle,parts
end
function NS.QuestActionStyle(button,enabled,hover)
    local border=button.Border
    if enabled then
        NS.TintQuestBorder(border,hover and .95 or .65,hover and .78 or .47,hover and .39 or .24)
        button:GetFontString():SetTextColor(.96,.83,.42,1)
    else
        NS.TintQuestBorder(border,.32,.31,.28)
        button:GetFontString():SetTextColor(.46,.45,.42,1)
    end
end
