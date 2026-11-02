-- Read-only introduction: two short explanations beside real interface excerpts.
local _,NS=...
local T=NS.Text
local media="Interface\\AddOns\\ForeverLFG\\Media\\"
local screenshots={enUS=true,ruRU=true,koKR=true,deDE=true}
-- Show the actual mode selector and contact action, without a full filter panel.
local modeRegions={seek={1188,8,1518,64},recruit={1188,520,1518,576}}
-- Result lists differ in scroll position and may start with the player's listing.
local actionRegions={
    enUS={seek={778,218,949,271},recruit={778,638,949,690}},
    ruRU={seek={809,218,981,271},recruit={778,801,949,853}},
    koKR={seek={778,218,949,271},recruit={778,904,949,956}},
    deDE={seek={778,218,949,271},recruit={778,801,949,853}},
}
local function label(parent,size,width,text)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    NS.QuestFont(t,size);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetJustifyV("TOP")
    t:SetWordWrap(true);t:SetText(text);t:SetTextColor(.94,.92,.85);return t
end
function NS.CreateSearchTutorialPage(parent,width)
    local s=CreateFrame("Frame",nil,parent);s:SetWidth(width);s.Rows={};s.Images={}
    local innerWidth,imageWidth,gap=592,225,28
    local textWidth=innerWidth-imageWidth-gap
    local left=(width-innerWidth)/2
    s.imageLocale=screenshots[NS.clientLocale] and NS.clientLocale or "enUS"
    s.file="TutorialSearch_"..s.imageLocale..".tga"
    s.Lead=label(s,14,innerWidth,T("QUEST_TUTORIAL_SEARCH_LEAD",T("BROWSE_REFRESH")))
    s.Lead:SetPoint("TOPLEFT",left,0)
    local function excerpt(row,mode,part,c,width)
        local image=row:CreateTexture(nil,"ARTWORK");image:SetTexture(media..s.file);image.file=s.file
        image.crop=c;image.region=mode;image.part=part
        image.sourceWidth,image.sourceHeight=c[3]-c[1],c[4]-c[2]
        image:SetTexCoord(c[1]/2048,c[3]/2048,c[2]/1024,c[4]/1024)
        image:SetSize(width,width*image.sourceHeight/image.sourceWidth)
        s.Images[#s.Images+1]=image;return image
    end
    for _,mode in ipairs({"seek","recruit"}) do
        local row=CreateFrame("Frame",nil,s);row:SetWidth(innerWidth)
        NS.QuestSurface(row,.12,.085,.045);NS.ApplyQuestBorder(row)
        -- Give each explanation and its examples one quiet, padded backdrop.
        -- Extend decoration only: preserve the existing content and page layout.
        for _,layer in ipairs({row.Surface,row.CardBorder}) do
            layer:ClearAllPoints();layer:SetPoint("TOPLEFT",row,"TOPLEFT",-12,4)
            layer:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",12,-4)
        end
        row.Title=label(row,15,textWidth,T(mode=="seek" and "FILTER_SEEK" or "FILTER_RECRUIT"))
        row.Title:SetTextColor(.99,.86,.46);row.Title:SetPoint("TOPLEFT")
        row.Text=label(row,14,textWidth,T(mode=="seek" and "QUEST_TUTORIAL_SEARCH_SEEK_BODY" or "QUEST_TUTORIAL_SEARCH_RECRUIT_BODY",
            T("BROWSE_MODE"),T(mode=="seek" and "FILTER_SEEK" or "FILTER_RECRUIT"),T(mode=="seek" and "BROWSE_WRITE" or "BROWSE_INVITE")))
        row.ModeImage=excerpt(row,mode,"mode",modeRegions[mode],imageWidth);row.ModeImage:SetPoint("TOPRIGHT")
        row.ActionImage=excerpt(row,mode,"action",actionRegions[s.imageLocale][mode],120)
        row.ActionImage:SetPoint("TOPRIGHT",row.ModeImage,"BOTTOMRIGHT",0,-10)
        s.Rows[#s.Rows+1]=row
    end
    s.ListingHint=label(s.Rows[2],11,textWidth,T("QUEST_TUTORIAL_SEARCH_LISTING_HINT"));s.ListingHint:SetTextColor(.79,.76,.68)
    s.Caption=label(s,10,innerWidth,T("QUEST_TUTORIAL_IMAGE_NOTE"));s.Caption:SetTextColor(.7,.68,.61)
    function s:Layout()
        local leadHeight=NS.QuestTextHeight(self.Lead,24)
        local heights,headings={},{}
        for index,row in ipairs(self.Rows) do
            local heading=NS.QuestTextHeight(row.Title,20)
            local textHeight=heading+8+NS.QuestTextHeight(row.Text,24)
            if index==2 then
                textHeight=textHeight+10+NS.QuestTextHeight(self.ListingHint,16)
            end
            local imageHeight=heading+8+row.ModeImage:GetHeight()+10+row.ActionImage:GetHeight()
            headings[index]=heading;heights[index]=math.max(textHeight,imageHeight)
        end
        local fallback=not screenshots[NS.clientLocale] and NS.clientLocale~="enGB"
        local captionHeight=fallback and 6+NS.QuestTextHeight(self.Caption,14) or 0
        local naturalHeight=leadHeight+18+heights[1]+22+heights[2]+captionHeight
        -- The shared dialog fits all three pages. Balance this page inside that
        -- existing space, leaving the following pages and navigation untouched.
        local dialog=parent:GetParent()
        local available=dialog.fixedHeight and dialog.fixedHeight-dialog.Header:GetHeight()-26-dialog.StepTitle:GetHeight()-12-64
        local extra=available and math.max(0,available-naturalHeight) or 0
        local top=leadHeight+18
        for index,row in ipairs(self.Rows) do
            local padding=extra/4
            row:ClearAllPoints();row:SetPoint("TOPLEFT",self,"TOPLEFT",left,-top)
            row.Title:ClearAllPoints();row.Title:SetPoint("TOPLEFT",0,-padding)
            row.Text:ClearAllPoints();row.Text:SetPoint("TOPLEFT",0,-padding-headings[index]-8)
            row.ModeImage:ClearAllPoints();row.ModeImage:SetPoint("TOPRIGHT",0,-padding-headings[index]-8)
            row:SetHeight(heights[index]+extra/2)
            top=top+row:GetHeight()+(index==1 and 22 or 0)
        end
        self.ListingHint:ClearAllPoints();self.ListingHint:SetPoint("TOPLEFT",self.Rows[2].Text,"BOTTOMLEFT",0,-10)
        self.Caption:ClearAllPoints();self.Caption:SetPoint("TOPLEFT",self,"TOPLEFT",left,-top-6);self.Caption:SetShown(fallback)
        top=top+captionHeight
        self:SetHeight(top);return top
    end
    s:Layout();return s
end
