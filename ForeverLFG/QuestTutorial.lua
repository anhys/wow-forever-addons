-- Account-wide introduction: search basics, quest partners and launcher choice.
local addonName,NS=...
local T=NS.Text
local media="Interface\\AddOns\\ForeverLFG\\Media\\"
local width,contentWidth=704,656
local tutor={};NS.QuestTutorial=tutor
local function mode(value) return value=="bar" or value=="minimap" end
local function state()
    local db=NS.Database()
    if type(db.tutorials)~="table" then db.tutorials={} end
    if type(db.tutorials.questPartners)~="table" then db.tutorials.questPartners={} end
    return db.tutorials.questPartners
end
local function basics()
    local db=NS.Database();state()
    if type(db.tutorials.searchBasics)~="table" then db.tutorials.searchBasics={} end
    if db.tutorials.searchBasics.version ~= 5 then
        db.tutorials.searchBasics.completed=nil; db.tutorials.searchBasics.version=5
    end
    return db.tutorials.searchBasics
end
local function pending() return basics().completed~=true or state().completed~=true end
function NS.QuestTutorialDefaultMode()
    local value=state().mode;return mode(value) and value or "minimap"
end
local function label(parent,size,width,text,r,g,b)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    NS.QuestFont(f,size,r,g,b);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
    f:SetWordWrap(true);f:SetText(text);return f
end
local function action(parent,text,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetText(text);NS.QuestFont(b:GetFontString(),13)
    b:SetSize(math.max(100,NS.QuestTextWidth(b:GetFontString())+30),26)
    b:SetScript("OnClick",fn);return b
end
local function fit(tex,width,height)
    local w=math.min(width,height*tex.sourceWidth/tex.sourceHeight)
    tex:SetSize(w,w*tex.sourceHeight/tex.sourceWidth)
end
local function screenshot(parent,file,width,height,l,r,t,b)
    local tex=parent:CreateTexture(nil,"ARTWORK");tex:SetTexture(media..file)
    tex:SetTexCoord(l,r,t,b);tex:SetPoint("CENTER")
    tex.sourceWidth,tex.sourceHeight=width,height
    return tex
end
local function refreshCards(f)
    for key,c in pairs(f.Cards) do
        local selected=f.choice==key;c.Check:SetChecked(selected)
        NS.TintQuestBorder(c,selected and .98 or (c.hovered and .78 or .43),selected and .78 or .52,selected and .28 or .29)
        c.Surface:SetColorTexture(selected and .115 or .045,selected and .077 or .032,.021,1)
    end
end
local function saveDraft(f)
    if f.step~=2 and f.step~=3 then return end
    local s=state();if s.completed==true then return end
    -- Keep the existing quest-only saved step contract (1/2) across upgrades.
    s.step=f.step-1;s.draftMode=f.choice
end
local function layout(f)
    local titleHeight=NS.QuestTextHeight(f.Title,27)
    f.Progress:ClearAllPoints();f.Progress:SetPoint("TOPLEFT",f.Header,"TOPLEFT",14,-titleHeight-15)
    f.Progress:SetText("ForeverLFG  -  "..T("QUEST_TUTORIAL_STEP",f.step,f.totalSteps))
    local headerHeight=titleHeight+42;f.Header:SetHeight(headerHeight)
    f.Body:ClearAllPoints();f.Body:SetPoint("TOPLEFT",f,"TOPLEFT",24,-headerHeight-26)
    f.Body:SetPoint("TOPRIGHT",f,"TOPRIGHT",-24,-headerHeight-26)
    local search,intro=f.step==1,f.step==2
    f.Search:SetShown(search);f.Intro:SetShown(intro);f.Choose:SetShown(f.step==3)
    f.StepTitle:SetText(T(search and "QUEST_TUTORIAL_SEARCH_TITLE" or intro and "QUEST_TUTORIAL_INTRO_TITLE" or "QUEST_TUTORIAL_CHOOSE_TITLE"))
    local contentTop=NS.QuestTextHeight(f.StepTitle,24)+12
    local bodyHeight
    if search then
        f.Search:ClearAllPoints();f.Search:SetPoint("TOPLEFT",f.Body,"TOPLEFT",0,-contentTop)
        bodyHeight=contentTop+f.Search:Layout()
    elseif intro then
        f.Intro:ClearAllPoints();f.Intro:SetPoint("TOPLEFT",f.Body,"TOPLEFT",(contentWidth-592)/2,-contentTop)
        f.Intro:SetWidth(592)
        local textHeight=NS.QuestTextHeight(f.IntroText,24)
        f.Community:ClearAllPoints();f.Community:SetPoint("TOPLEFT",f.Intro,"TOPLEFT",0,-textHeight-16)
        local communityHeight=NS.QuestTextHeight(f.CommunityText,32)+26
        f.Community:SetHeight(communityHeight)
        fit(f.Example,300,250)
        f.ExampleFrame:SetHeight(f.Example:GetHeight())
        f.ExampleCaption:ClearAllPoints();f.ExampleCaption:SetPoint("TOPLEFT",f.ExampleFrame,"BOTTOMLEFT",0,-8)
        bodyHeight=contentTop+math.max(textHeight+16+communityHeight,f.Example:GetHeight()+8+NS.QuestTextHeight(f.ExampleCaption,16))
        f.Intro:SetHeight(bodyHeight-contentTop)
    else
        f.Choose:ClearAllPoints();f.Choose:SetPoint("TOPLEFT",f.Body,"TOPLEFT",(contentWidth-592)/2,-contentTop)
        f.Choose:SetWidth(592)
        local cardsTop=NS.QuestTextHeight(f.ChooseText,24)+12
        local titleHeight,hintHeight=0,0
        for _,c in pairs(f.Cards) do
            titleHeight=math.max(titleHeight,NS.QuestTextHeight(c.Title,20))
            hintHeight=math.max(hintHeight,NS.QuestTextHeight(c.Hint,32))
        end
        local imageTop=14+titleHeight+10
        local cardHeight=imageTop+190+12+hintHeight+14
        for key,c in pairs(f.Cards) do
            c:ClearAllPoints();c:SetPoint("TOPLEFT",f.Choose,"TOPLEFT",key=="minimap" and 0 or 304,-cardsTop)
            c:SetHeight(cardHeight)
            c.ImageFrame:ClearAllPoints();c.ImageFrame:SetPoint("TOPLEFT",c,"TOPLEFT",12,-imageTop)
            fit(c.Image,264,190)
            c.Hint:ClearAllPoints();c.Hint:SetPoint("TOPLEFT",c,"TOPLEFT",14,-imageTop-202)
        end
        local hintTop=cardsTop+cardHeight+14
        f.Use:ClearAllPoints();f.Use:SetPoint("TOPLEFT",f.Choose,"TOPLEFT",0,-hintTop)
        local height=hintTop+NS.QuestTextHeight(f.Use,24)
        f.Choose:SetHeight(height);bodyHeight=contentTop+height
    end
    f.Body:SetHeight(bodyHeight)
    f.Back:SetShown(not search and not f.searchOnly)
    f.Next:SetText(T((f.searchOnly or f.step==3) and "QUEST_TUTORIAL_DONE" or "QUEST_TUTORIAL_NEXT"))
    f:SetHeight(f.fixedHeight or (headerHeight+26+bodyHeight+64))
    -- Scale only this dialog to fit smaller UI canvases; do not alter game UI.
    f:SetScale(math.min(1,math.max(.25,(UIParent:GetWidth()-24)/width),math.max(.25,(UIParent:GetHeight()-24)/f:GetHeight())))
    NS.QuestHeader(f.Header,UnitFactionGroup("player"));refreshCards(f)
end
local function chooseCard(f,key,file,width,height,l,r,t,b)
    local c=CreateFrame("Button",nil,f.Choose);c:SetWidth(288);c:RegisterForClicks("LeftButtonUp")
    NS.QuestSurface(c);NS.ApplyQuestBorder(c)
    c.Check=CreateFrame("CheckButton",nil,c,"UICheckButtonTemplate");c.Check:SetSize(24,24);c.Check:SetPoint("TOPLEFT",10,-10)
    c.Title=label(c,15,236,T(key=="minimap" and "QUEST_TUTORIAL_MINIMAP" or "QUEST_TUTORIAL_BAR"))
    c.Title:SetPoint("TOPLEFT",42,-14)
    c.ImageFrame=CreateFrame("Frame",nil,c);c.ImageFrame:SetSize(264,190)
    c.Image=screenshot(c.ImageFrame,file,width,height,l,r,t,b)
    c.Hint=label(c,12,260,T(key=="minimap" and "QUEST_TUTORIAL_MINIMAP_HINT" or "QUEST_TUTORIAL_BAR_HINT"),.91,.89,.82)
    local function select()
        if InCombatLockdown() then return end
        f.choice=key;saveDraft(f);refreshCards(f)
    end
    c:SetScript("OnClick",select);c.Check:SetScript("OnClick",select)
    c:SetScript("OnEnter",function() c.hovered=true;refreshCards(f) end)
    c:SetScript("OnLeave",function() c.hovered=false;refreshCards(f) end)
    f.Cards[key]=c
end
local function create()
    local f=CreateFrame("Frame","ForeverLFGQuestTutorial",UIParent);tutor.window=f
    f:SetWidth(width);f:SetHeight(560);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetFrameLevel(100)
    f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
    NS.QuestSurface(f,.045,.032,.021);f.Surface:ClearAllPoints();f.Surface:SetPoint("TOPLEFT",12,-12);f.Surface:SetPoint("BOTTOMRIGHT",-12,12)
    NS.ApplyQuestDialogBorder(f,24)
    f.Header=CreateFrame("Frame",nil,f);f.Header:SetPoint("TOPLEFT",12,-12);f.Header:SetPoint("TOPRIGHT",-12,-12)
    NS.QuestSurface(f.Header);NS.ApplyQuestBorder(f.Header)
    f.Title=label(f.Header,22,width-82,T("QUEST_TUTORIAL_TITLE"),.99,.89,.56);f.Title:SetPoint("TOPLEFT",14,-9)
    f.Progress=label(f.Header,12,width-82,"",.84,.81,.72)
    f.Header:EnableMouse(true);f.Header:RegisterForDrag("LeftButton")
    f.Header:SetScript("OnDragStart",function() if not InCombatLockdown() then f:StartMoving() end end)
    f.Header:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    f.Close=CreateFrame("Button",nil,f.Header,"UIPanelCloseButton");f.Close:SetPoint("TOPRIGHT",-2,-1);f.Close:SetSize(26,26)
    f.Close:SetScript("OnClick",function() f:Hide() end)
    f.Body=CreateFrame("Frame",nil,f);f.Body:SetWidth(contentWidth)
    f.StepTitle=label(f.Body,18,contentWidth,"");f.StepTitle:SetPoint("TOPLEFT")
    f.Search=NS.CreateSearchTutorialPage(f.Body,contentWidth,function() if f.step==1 then layout(f) end end)
    f.Intro=CreateFrame("Frame",nil,f.Body)
    f.IntroText=label(f.Intro,14,264,T("QUEST_TUTORIAL_INTRO"),.94,.92,.85);f.IntroText:SetPoint("TOPLEFT")
    f.Community=CreateFrame("Frame",nil,f.Intro);f.Community:SetWidth(264);NS.QuestParchment(f.Community)
    f.CommunityText=label(f.Community,13,236,T("QUEST_TUTORIAL_COMMUNITY"),.14,.085,.035);f.CommunityText:SetPoint("TOPLEFT",14,-13)
    f.ExampleFrame=CreateFrame("Frame",nil,f.Intro);f.ExampleFrame:SetWidth(300);f.ExampleFrame:SetPoint("TOPRIGHT")
    f.Example=screenshot(f.ExampleFrame,"QuestTutorialBrowser.tga",796,640,0,796/1024,428/2048,1068/2048)
    f.ExampleCaption=label(f.Intro,11,300,T("QUEST_TUTORIAL_EXAMPLE").."\n"..T("QUEST_TUTORIAL_IMAGE_NOTE"),.79,.76,.68)
    f.Choose=CreateFrame("Frame",nil,f.Body)
    f.ChooseText=label(f.Choose,13,592,T("QUEST_TUTORIAL_CHOOSE_BODY"),.94,.92,.85);f.ChooseText:SetPoint("TOPLEFT")
    f.Cards={}
    chooseCard(f,"minimap","QuestTutorialMinimap.tga",468,468,0,468/512,0,468/512)
    chooseCard(f,"bar","QuestTutorialBar.tga",594,488,0,594/1024,0,488/512)
    f.Use=label(f.Choose,12,592,T("QUEST_TUTORIAL_USE").."\n"..T("QUEST_TUTORIAL_IMAGE_NOTE"),.84,.81,.72)
    f.Later=action(f,T("QUEST_TUTORIAL_LATER"),function() f:Hide() end);f.Later:SetPoint("BOTTOMLEFT",24,19)
    f.Next=action(f,T("QUEST_TUTORIAL_NEXT"),function()
        if InCombatLockdown() then return end
        if f.step==1 then
            basics().completed=true
            if f.searchOnly then f:Hide();return end
            f.step=f.resumeQuestStep or 2;f.resumeQuestStep=nil;saveDraft(f);layout(f);return
        end
        if f.step==2 then f.step=3;saveDraft(f);layout(f);return end
        NS.SetQuestLauncherMode(f.choice)
        local s=state();s.completed=true;s.mode=f.choice;s.step=nil;s.draftMode=nil
        if NS.QuestMinimapModeCheck then NS.QuestMinimapModeCheck:SetChecked(f.choice=="minimap") end
        f:Hide()
    end);f.Next:SetPoint("BOTTOMRIGHT",-24,19)
    f.Back=action(f,T("QUEST_TUTORIAL_BACK"),function() if not InCombatLockdown() and f.step>1 then f.step=f.step-1;saveDraft(f);layout(f) end end)
    f.Back:SetPoint("RIGHT",f.Next,"LEFT",-10,0)
    f:SetScript("OnHide",function() f:StopMovingOrSizing();saveDraft(f) end)
    f:Hide()
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ForeverLFGQuestTutorial" end
    return f
end
function NS.OpenQuestTutorial(automatic)
    if InCombatLockdown() then print("ForeverLFG: "..T("QUEST_ACTION_COMBAT"));return false end
    if not tutor.loaded or not UIParent or not UIParent:IsVisible() then return false end
    local f=tutor.window or create();local s=state()
    local questStep=s.completed~=true and s.step==2 and 3 or 2
    f.searchOnly=automatic==true and s.completed==true
    f.totalSteps=f.searchOnly and 1 or 3
    local step=automatic==true and basics().completed==true and questStep or 1
    f.resumeQuestStep=automatic==true and step==1 and questStep or 2
    f.choice=s.completed~=true and mode(s.draftMode) and s.draftMode or NS.QuestLauncherMode()
    tutor.handled=true;tutor.resume=false
    -- Measure all applicable pages before showing, keeping the header/footer still.
    f.fixedHeight=nil;local height=0
    for page=1,f.totalSteps do f.step=page;layout(f);height=math.max(height,f:GetHeight()) end
    f.fixedHeight=height;f.step=step
    layout(f);f:Show();return true
end
local schedule
schedule=function()
    if not tutor.loaded or tutor.queued then return end
    if not tutor.resume and (tutor.handled or not pending()) then return end
    tutor.queued=true
    C_Timer.After(math.max(.5,(tutor.readyAt or 0)-GetTime()),function()
        tutor.queued=false
        if not tutor.loaded or not tutor.inWorld then return end
        if not tutor.resume and (tutor.handled or not pending()) then return end
        if InCombatLockdown() then return end -- PLAYER_REGEN_ENABLED resumes.
        if GetTime()<(tutor.readyAt or 0) or not UIParent or not UIParent:IsVisible() then schedule();return end
        if tutor.resume and tutor.window then
            tutor.resume=false;layout(tutor.window);tutor.window:Show()
        else NS.OpenQuestTutorial(true) end
    end)
end
local events=CreateFrame("Frame");tutor.events=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then if name==addonName then tutor.loaded=true end;return end
    if event=="PLAYER_ENTERING_WORLD" then tutor.inWorld=true;tutor.readyAt=GetTime()+3;schedule();return end
    if event=="PLAYER_REGEN_ENABLED" then schedule();return end
    if event=="PLAYER_LEAVING_WORLD" then tutor.inWorld=false end
    if tutor.window and tutor.window:IsShown() then tutor.resume=true;tutor.window:Hide() end
end)
