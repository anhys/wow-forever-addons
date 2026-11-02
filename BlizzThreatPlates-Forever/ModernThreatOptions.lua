local addon = ForeverNameplates
local ui, panel = addon.ModernOptionsUI, addon.OptionsPanel
if not ui or not panel then return end
local actions = addon.ThreatOptionsActions
local views, controls, active = {}, {}, "colors"
local GOLD, TEXT = {0.88,0.66,0.24}, {0.92,0.90,0.84}
local SelectEnemyColorState
local shell = CreateFrame("Frame",nil,addon.OptionsContentInset,"BackdropTemplate")
shell:SetPoint("TOPLEFT",addon.OptionsContentRoot,"TOPLEFT",24,-104)
shell:SetPoint("BOTTOMRIGHT",addon.OptionsContentRoot,"BOTTOMRIGHT",-24,60)
shell:SetFrameLevel(panel:GetFrameLevel()+30)
shell:EnableMouse(true)
ui.Backdrop(shell,{0.065,0.075,0.090,1},{0.20,0.23,0.27,1})

local function Refresh()
    for _,control in ipairs(controls) do if control.Refresh then control:Refresh() end end
end
local function Register(control) controls[#controls+1]=control; return control end
local function DB() ForeverNameplatesDB=ForeverNameplatesDB or {}; return ForeverNameplatesDB end
local function ChangedColors()
    if addon.RefreshThreatColors then addon:RefreshThreatColors() end
    if addon.RefreshATDStyle then addon:RefreshATDStyle() end
    Refresh()
end
local function View(key,title)
    local view=CreateFrame("Frame",nil,shell)
    view:SetAllPoints(shell)
    ui.Font(view,"GameFontNormalLarge",title,20,-14,420):SetTextColor(unpack(TEXT))
    local line=view:CreateTexture(nil,"ARTWORK")
    line:SetColorTexture(0.20,0.23,0.27,1)
    line.btpOptionsTextureRole="border"
    line.btpOptionsTextureMethod="SetColorTexture"
    line.btpOptionsTextureColor={0.20,0.23,0.27,1}
    line:SetPoint("TOPLEFT",18,-54)
    line:SetPoint("TOPRIGHT",-18,-54)
    line:SetHeight(1)
    views[key]=view
    view:Hide()
    return view
end
local function Card(parent,y,height,width,x)
    local card=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    card:SetPoint("TOPLEFT",x or 44,y)
    card:SetSize(width or 480,height)
    ui.Backdrop(card)
    return card
end
local function Toggle(parent,text,x,y,get,set,width)
    return Register(ui.Toggle(parent,text,x,y,get,function(value) set(value); Refresh() end,width))
end
local function Slider(parent,text,x,y,width,low,high,get,set,suffix)
    local control=Register(ui.SliderRow(parent,text,x,y,width,low,high,1,get,set,suffix))
    control.OnUserValueChanged=Refresh
    return control
end
local function ColorRow(parent,text,y,width,get,set,default,enabled,previewState)
    local label=ui.Font(parent,"GameFontHighlightSmall",text,12,y-7,width-122)
    local swatch=ui.Button(parent,"",36,24)
    swatch:SetPoint("TOPLEFT",width-116,y)
    local fill=swatch:CreateTexture(nil,"ARTWORK")
    fill:SetPoint("TOPLEFT",3,-3)
    fill:SetPoint("BOTTOMRIGHT",-3,3)
    local function Apply(color)
        if enabled and not enabled() then return end
        if previewState then SelectEnemyColorState(previewState) end
        set(color[1],color[2],color[3]); ChangedColors()
    end
    swatch:SetScript("OnClick",function()
        if not enabled or enabled() then
            if previewState then SelectEnemyColorState(previewState) end
            ui.OpenColorPicker({get()},Apply,function(color)
                -- Cancel restores the saved swatch even if class colors were
                -- enabled externally while the picker was open.
                set(color[1],color[2],color[3]); ChangedColors()
            end)
        end
    end)
    local reset=ui.Button(parent,"Default",66,24)
    reset:SetPoint("TOPLEFT",width-72,y)
    reset:SetScript("OnClick",function() Apply(default) end)
    swatch.Refresh=function()
        local r,g,b=get(); fill:SetColorTexture(r,g,b,1)
        if enabled then
            ui.SetControlEnabled(swatch,enabled())
            ui.SetControlEnabled(reset,enabled())
        end
    end
    Register(swatch)
    return label
end

local colors=View("colors","Threat Colors")
local colorPanels,colorTabs,selectedColorPanel={},{},"general"
local paletteNames={general="Default Colors",tank="Tank Colors",nonTank="DPS / Healer Colors"}
local colorPreviewState="secure"
local function RefreshColorTabs()
    for name,button in pairs(colorTabs) do
        button.label:SetTextColor(unpack(name==selectedColorPanel and GOLD or TEXT))
        button:SetBackdropBorderColor(unpack(name==selectedColorPanel and GOLD or {0.20,0.23,0.27}))
    end
end
local function ShowColorPanel(key)
    if not colorPanels[key] then key="general" end
    if key~="general" and DB().disableRoleColors then key="general" end
    if selectedColorPanel~=key then colorPreviewState=key=="general" and "secure" or key..":secure" end
    selectedColorPanel=key
    for name,view in pairs(colorPanels) do view:SetShown(name==key) end
    RefreshColorTabs()
    actions.CloseEditors()
end
local automaticRoles=Card(colors,-362,44)
local roleToggle=Toggle(automaticRoles,"Auto-Switch Role Colors",252,-14,
    function() return not DB().disableRoleColors end,
    function(value) DB().disableRoleColors=not value; ChangedColors() end,192)
roleToggle.label.btpDevExclude=true
roleToggle.label:SetWidth(0)
roleToggle.label:SetWordWrap(false)
addon:CreateOptionsNewFeatureTag(automaticRoles,roleToggle.label,"LEFT","RIGHT",6,0)
-- A short, non-interactive pulse points to the required toggle without moving
-- controls or changing the user's saved preference. Restart it on each click.
local roleAttention=CreateFrame("Frame",nil,automaticRoles,"BackdropTemplate")
roleAttention.btpDevExclude=true
roleAttention:EnableMouse(false)
roleAttention:SetFrameLevel(automaticRoles:GetFrameLevel()+2)
roleAttention:SetPoint("TOPLEFT",roleToggle,"TOPLEFT",-7,7)
roleAttention:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
roleAttention:SetBackdropColor(GOLD[1],GOLD[2],GOLD[3],0.08)
local roleAttentionEdges={}
for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
    local edge=roleAttention:CreateTexture(nil,"OVERLAY")
    edge:SetColorTexture(GOLD[1],GOLD[2],GOLD[3],1)
    if edge.SetSnapToPixelGrid then edge:SetSnapToPixelGrid(false) end
    if edge.SetTexelSnappingBias then edge:SetTexelSnappingBias(0) end
    roleAttentionEdges[side]=edge
end
local function LayoutRoleAttention()
    -- Size from the checkbox, not the font's shorter bottom edge. This leaves
    -- the same seven units of space above and below the entire checkbox.
    roleAttention:SetSize(roleToggle:GetWidth()+7+roleToggle.label:GetStringWidth()+14,
        roleToggle:GetHeight()+14)
    local scale=roleAttention:GetEffectiveScale()
    local stroke=math.max(1,math.floor(2*scale+0.5))/scale
    for side,edge in pairs(roleAttentionEdges) do
        edge:ClearAllPoints()
        if side=="TOP" or side=="BOTTOM" then
            edge:SetPoint(side.."LEFT",roleAttention,side.."LEFT",0,0)
            edge:SetPoint(side.."RIGHT",roleAttention,side.."RIGHT",0,0)
            edge:SetHeight(stroke)
        else
            edge:SetPoint("TOP"..side,roleAttention,"TOP"..side,0,-stroke)
            edge:SetPoint("BOTTOM"..side,roleAttention,"BOTTOM"..side,0,stroke)
            edge:SetWidth(stroke)
        end
    end
end
local function StopRoleAttention()
    roleAttention:SetScript("OnUpdate",nil)
    roleAttention:Hide()
end
local function PulseRoleToggle()
    local elapsed=0
    LayoutRoleAttention()
    roleAttention:SetAlpha(0.25)
    roleAttention:Show()
    roleAttention:SetScript("OnUpdate",function(self,delta)
        elapsed=elapsed+delta
        if elapsed>=2.4 or not DB().disableRoleColors then StopRoleAttention(); return end
        self:SetAlpha(0.25+0.75*(1-math.cos(elapsed/0.8*2*math.pi))/2)
    end)
end
StopRoleAttention()
roleAttention:HookScript("OnHide",function(self) self:SetScript("OnUpdate",nil) end)
colors:HookScript("OnHide",StopRoleAttention)
shell:HookScript("OnHide",StopRoleAttention)
local roleStatus=ui.Font(colors,"GameFontDisableSmall","",0,0,300)
roleStatus:ClearAllPoints()
roleStatus:SetPoint("TOPRIGHT",automaticRoles,"BOTTOMRIGHT",0,-6)
roleStatus:SetJustifyH("RIGHT")
roleStatus:SetWordWrap(false)
local function RoleColorSummary()
    local profile=addon:GetDungeonRaidThreatProfile()
    local palette=profile=="tank" and "Tank" or profile=="nonTank" and "DPS / Healer" or "Default"
    local inInstance,instanceType=IsInInstance()
    local locations={party="Dungeon",raid="Raid",pvp="Battleground",arena="Arena",scenario="Scenario"}
    local location=inInstance and (locations[instanceType] or "Instance") or "Open World"
    return "Current: "..palette.." ("..location..")"
end
local function RoleColorStatus()
    local profile=addon:GetDungeonRaidThreatProfile()
    if profile then
        return "Currently using: "..(profile=="tank" and "Tank colors" or "DPS / Healer colors")
    end
    local reason
    if DB().disableRoleColors then reason="role switching is off"
    else
        local inInstance,instanceType=IsInInstance()
        if not inInstance or (instanceType~="party" and instanceType~="raid") then
            reason="outside a dungeon or raid"
        else reason="no group role assigned" end
    end
    return "Using Default colors - "..reason
end
local roleTooltipShown=false
local function ShowRoleTooltip()
    if not GameTooltip then return end
    GameTooltip:SetOwner(roleToggle,"ANCHOR_RIGHT")
    GameTooltip:SetText("Auto-Switch Role Colors",1,1,1)
    GameTooltip:AddLine("Automatically uses your assigned Tank or DPS / Healer colors in dungeons and raids.",0.8,0.8,0.8,true)
    GameTooltip:AddLine(RoleColorStatus(),0.9,0.8,0.5,true)
    GameTooltip:Show()
end
local function HideRoleTooltip()
    roleTooltipShown=false
    if GameTooltip and GameTooltip:IsOwned(roleToggle) then GameTooltip:Hide() end
end
roleToggle:HookScript("OnEnter",function() roleTooltipShown=true; ShowRoleTooltip() end)
roleToggle:HookScript("OnLeave",HideRoleTooltip)
roleToggle:HookScript("OnHide",function() HideRoleTooltip(); StopRoleAttention() end)
panel:HookScript("OnHide",function() HideRoleTooltip(); StopRoleAttention() end)
Register({Refresh=function()
    if DB().disableRoleColors then
        roleToggle.label:SetTextColor(1,1,1)
        if selectedColorPanel~="general" then ShowColorPanel("general") end
    else
        roleToggle.label:SetTextColor(unpack(GOLD))
        StopRoleAttention()
    end
    roleStatus:SetText(RoleColorSummary())
    if roleTooltipShown and GameTooltip and GameTooltip:IsOwned(roleToggle) then ShowRoleTooltip() end
end})

local enemyPreview=ui.PreviewCard(colors,76,-66)
-- Only the sample viewport clips; the selector's upward popup must be able
-- to extend beyond this card while remaining owned by the options UI.
if enemyPreview.SetClipsChildren then enemyPreview:SetClipsChildren(false) end
local enemyCaption=ui.Font(enemyPreview,"GameFontDisableSmall","Preview: Default Colors",294,-14,174)
local enemyViewport=CreateFrame("Frame",nil,enemyPreview)
-- Reserve a separate right-hand column for the state control. The sample
-- gets the full card height rather than a narrow strip under the dropdown.
enemyViewport:SetPoint("TOPLEFT",12,-8)
enemyViewport:SetPoint("BOTTOMRIGHT",-198,8)
if enemyViewport.SetClipsChildren then enemyViewport:SetClipsChildren(true) end
local enemySample=ui.CreateNameplateSample(enemyPreview,enemyViewport,enemyCaption,0.75)
enemyPreview.btpEnemyColorPreview={plate=enemySample,caption=enemyCaption}
local enemyStateSelector=Register(ui.Selector(enemyPreview,"Preview State",-6,function()
    if selectedColorPanel=="general" then return {
        {text="Default Aggro",value="secure"},{text="Default Warning",value="warning"},
        {text="Default Lost Aggro",value="lost"},{text="Default Quest Color",value="quest"},
    } end
    local profile=selectedColorPanel
    return {{text="Have Aggro",value=profile..":secure"},{text="Warning",value=profile..":warning"},
        {text=profile=="tank" and "Lost Aggro" or "No Aggro",value=profile..":lost"},
        {text="Quest Color",value="quest"}}
end,function() return colorPreviewState end,function(value) SelectEnemyColorState(value) end,false,140))
enemyStateSelector.useModernMenu=true
enemyStateSelector.openUpward=true
enemyStateSelector:ClearAllPoints()
enemyStateSelector:SetPoint("TOPLEFT",enemyPreview,"TOPLEFT",294,-34)
SelectEnemyColorState=function(value)
    -- The color wheel remains attached to the palette where it opened, even
    -- if the user browses another palette before applying or resetting it.
    local profile=value:match("^(%a+):")
    if profile and DB().disableRoleColors then ShowColorPanel("general"); Refresh(); return end
    if value~="quest" then ShowColorPanel(profile or "general") end
    colorPreviewState=value
    Refresh()
end
enemyPreview.Refresh=function()
    enemySample.followHealthInfo=true
    enemySample:Refresh()
    local r,g,b,notice
    local previewPalette=paletteNames[selectedColorPanel]
    if colorPreviewState=="quest" then
        previewPalette="Quest Color"
        if addon:GetQuestColorEnabled() then r,g,b=addon:GetQuestColor()
        else r,g,b=0.72,0.74,0.04; notice="Quest color disabled" end
    else
        local profile,kind=colorPreviewState:match("^(%a+):(%a+)$")
        -- Editing/previewing a palette never enables it in gameplay.
        if profile then r,g,b=addon:GetDungeonRaidThreatColor(profile,kind)
        else r,g,b=addon:GetThreatColor(colorPreviewState) end
    end
    -- The atlas fill has its own tint; clear it before applying the bar color.
    enemySample.bar:GetStatusBarTexture():SetVertexColor(1,1,1,1)
    enemySample.bar:SetStatusBarColor(r,g,b,1)
    enemyCaption:SetText(notice or "Preview: "..previewPalette)
end
Register(enemyPreview)
for index,entry in ipairs({{"general","Default Colors"},{"tank","Tank Colors"},{"nonTank","DPS / Healer Colors"}}) do
    local key=entry[1]
    local view=CreateFrame("Frame",nil,colors)
    view:SetAllPoints(colors)
    colorPanels[key]=view
    local button=ui.Button(colors,entry[2],154,24)
    button:SetPoint("TOPLEFT",44+(index-1)*163,-160)
    button:SetScript("OnClick",function()
        ShowColorPanel(key); Refresh()
        if key~="general" and DB().disableRoleColors then PulseRoleToggle() end
    end)
    button:HookScript("OnLeave",RefreshColorTabs)
    colorTabs[key]=button
end
local defaultColors
for _,profile in ipairs({"general","tank","nonTank"}) do
    local palette=profile
    local card=Card(colorPanels[palette],-198,palette=="general" and 148 or 132)
    if palette=="general" then defaultColors=card end
    for index,key in ipairs({"secure","warning","lost"}) do
        local kind=key
        local text=palette=="general" and ({secure="Default Aggro",warning="Default Warning",lost="Default Lost Aggro"})[kind]
            or ({secure="Have Aggro",warning="Warning",lost=palette=="tank" and "Lost Aggro" or "No Aggro"})[kind]
        ColorRow(card,text,-8-(index-1)*34,480,
            function()
                if palette=="general" then return addon:GetThreatColor(kind) end
                return addon:GetDungeonRaidThreatColor(palette,kind)
            end,
            function(r,g,b)
                if palette=="general" then addon:SetThreatColor(kind,r,g,b)
                else addon:SetDungeonRaidThreatColor(palette,kind,r,g,b) end
            end,
            palette=="general" and addon.defaults.threat[kind] or addon.defaults.dungeonRaidThreat[palette][kind],
            palette~="general" and function() return not DB().disableRoleColors end or nil,
            palette=="general" and kind or palette..":"..kind)
    end
    if palette~="general" then
        ui.Font(card,"GameFontDisableSmall","Off-Tank Aggro (Still Testing)",12,-111,396)
        local offTankColor=card:CreateTexture(nil,"ARTWORK")
        offTankColor:SetPoint("TOPRIGHT",-12,-109)
        offTankColor:SetSize(24,14)
        offTankColor:SetColorTexture(0.54,0.81,0.94,0.45)
    end
end
local questLabel=ColorRow(defaultColors,"Default Quest Color",-110,480,
    function() return addon:GetQuestColor() end,
    function(r,g,b) DB().questColor={r,g,b} end,addon.defaults.questColor,nil,"quest")
questLabel:SetWidth(0)
questLabel:SetWordWrap(false)
local disableQuestColor=Toggle(automaticRoles,"Disable Quest Color",12,-14,
    function() return not addon:GetQuestColorEnabled() end,
    function(v) addon:SetQuestColorEnabled(not v) end,132)
disableQuestColor.label:SetWidth(0)
disableQuestColor.label:SetWordWrap(false)
addon:CreateOptionsNewFeatureTag(automaticRoles,disableQuestColor.label,"LEFT","RIGHT",6,0)

local players=View("players","Player Colors")
local pvpColors=Card(players,-66,108)
ui.Font(pvpColors,"GameFontHighlightSmall","Enemy Players",12,-12,300):SetTextColor(unpack(GOLD))
ColorRow(pvpColors,"PvP Combat",-36,480,
    function() local c=DB().pvpColor or addon.defaults.pvpColor; return unpack(c) end,
    function(r,g,b) DB().pvpColor={r,g,b} end,addon.defaults.pvpColor,
    function() return not addon:GetEnemyPlayerClassColors() end)
Toggle(pvpColors,"Use Class Colors for Enemy Players",16,-77,
    function() return addon:GetEnemyPlayerClassColors() end,
    function(v) addon:SetEnemyPlayerClassColors(v) end,440)

local friendlyColors=Card(players,-188,236)
local friendlyHeading=ui.Font(friendlyColors,"GameFontHighlightSmall","Friendly Players",12,-12,102)
friendlyHeading:SetTextColor(unpack(GOLD))
addon:CreateOptionsNewFeatureTag(friendlyColors,friendlyHeading)
local experimentalLabel=ui.Font(friendlyColors,"GameFontHighlightSmall","Experimental - Needs Testing",218,-14,250)
experimentalLabel:SetTextColor(unpack(GOLD))
experimentalLabel:SetJustifyH("CENTER")
for index,entry in ipairs({{"world","Open World"},{"pvp","Battlegrounds"},{"party","Dungeons"},{"raid","Raids"}}) do
    local context,text=entry[1],entry[2]
    local y=-40-(index-1)*36
    ui.Font(friendlyColors,"GameFontHighlightSmall",text,16,y-7,128)
    Toggle(friendlyColors,"Use Class Color",154,y-4,
        function() return addon:GetFriendlyPlayerClassColors(context) end,
        function(value) addon:SetFriendlyPlayerClassColors(value,context) end,166)
    local swatch=ui.Button(friendlyColors,"",36,24)
    swatch:SetPoint("TOPLEFT",354,y)
    local fill=swatch:CreateTexture(nil,"ARTWORK")
    fill:SetPoint("TOPLEFT",3,-3)
    fill:SetPoint("BOTTOMRIGHT",-3,3)
    local reset=ui.Button(friendlyColors,"Default",66,24)
    reset:SetPoint("TOPLEFT",398,y)
    swatch:HookScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        local _,_,_,useDefault=addon:GetFriendlyPlayerColorSettings(context)
        if addon:GetFriendlyPlayerClassColors(context) then
            GameTooltip:SetText("Blizzard chooses each player's class color.",nil,nil,nil,nil,true)
        elseif useDefault then
            GameTooltip:SetText("Blizzard's friendly color for this location. PvP flags and group membership can change individual players' colors. Click to customize.",nil,nil,nil,nil,true)
        else
            GameTooltip:SetText("Click to change this location's custom friendly-player color.",nil,nil,nil,nil,true)
        end
        GameTooltip:Show()
    end)
    swatch:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    swatch:SetScript("OnClick",function()
        if addon:GetFriendlyPlayerClassColors(context) then return end
        local r,g,b,wasDefault=addon:GetFriendlyPlayerColorSettings(context)
        local displayR,displayG,displayB=addon:GetFriendlyPlayerColorSwatch(context)
        ui.OpenColorPicker({displayR,displayG,displayB},function(color)
            if addon:GetFriendlyPlayerClassColors(context) then return end
            addon:SetFriendlyPlayerColor(context,color[1],color[2],color[3])
            Refresh()
        end,function()
            addon:SetFriendlyPlayerColor(context,r,g,b,wasDefault)
            Refresh()
        end)
    end)
    reset:SetScript("OnClick",function()
        if addon:GetFriendlyPlayerClassColors(context) then return end
        addon:ResetFriendlyPlayerColor(context)
        Refresh()
    end)
    Register({Refresh=function()
        local r,g,b=addon:GetFriendlyPlayerColorSwatch(context)
        local enabled=not addon:GetFriendlyPlayerClassColors(context)
        fill:Show()
        fill:SetColorTexture(r,g,b,1)
        swatch.label:SetText("")
        ui.SetControlEnabled(swatch,enabled)
        ui.SetControlEnabled(reset,enabled)
    end})
end
local location=ui.Font(friendlyColors,"GameFontDisableSmall","",16,-190,448)
Register({Refresh=function()
    location:SetText("Current location: "..addon:GetFriendlyPlayerColorContextLabel())
end})
ui.Font(friendlyColors,"GameFontDisableSmall","Custom colors apply only to nameplates Blizzard allows us to edit.",16,-211,448)

function addon:RefreshPlayerColorSwatches()
    if active=="players" and shell:IsShown() then Refresh() end
end

local display=View("display","Threat Display")
local threatPreviewState="secure"
local mixedColorMode="differential"
local function ThreatColorMode()
    local mode=addon:GetThreatDisplayMode()
    return mode=="mixed" and mixedColorMode or mode
end
local function ThreatModeSelector(parent,y,compactWidth)
    return Register(ui.Selector(parent,"Display Mode",y,function()
        return {{text=compactWidth and "Differential" or "Threat Differential",value="differential"},
            {text=compactWidth and "Percentage" or "Threat Percentage",value="percentage"},
            {text="Mixed",value="mixed"}}
    end,function() return addon:GetThreatDisplayMode() end,
    function(v) addon:SetThreatDisplayMode(v); Refresh() end,true,compactWidth))
end
ThreatModeSelector(display,-130)
local function CreateThreatPreview(parent,y,compact)
    local preview=ui.PreviewCard(parent,compact and 54 or 76,-y)
    local caption=ui.Font(compact and preview or parent,"GameFontDisableSmall","Preview",44,-y+16,240)
    if compact then caption:Hide() end
    local viewport=CreateFrame("Frame",nil,preview)
    viewport:SetPoint("TOPLEFT",8,-6)
    viewport:SetPoint("BOTTOMRIGHT",-8,6)
    local sample=ui.CreateNameplateSample(preview,viewport,caption)
    local number=sample.content:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    number.btpDevExclude=true
    preview.btpThreatPreview={plate=sample,number=number}
    number:SetJustifyH("RIGHT")
    number:SetShadowColor(0,0,0,1)
    number:SetShadowOffset(1,-1)
    preview.Refresh=function()
        sample.followHealthInfo=true
        sample:Refresh()
        local size=addon:GetThreatDifferentialSize()
        number:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"OUTLINE")
        local mode=ThreatColorMode()
        number:SetText(mode=="percentage" and "125%" or "+420")
        local r,g,b=addon:GetThreatTextColor(threatPreviewState,mode)
        number:SetTextColor(r,g,b,1)
        local x,y=addon:GetOverlayPosition("threat")
        number:ClearAllPoints()
        number:SetPoint("RIGHT",sample.bar,"LEFT",x,y)
        local b,g=sample.bounds,sample.geometry
        -- These measurements are our own fixed sample string, never unit data.
        local left=math.min(b.left,-g.width/2+x-number:GetStringWidth())
        local right=math.max(b.right,-g.width/2+x)
        local top,bottom=math.max(b.top,y+number:GetStringHeight()/2),math.max(b.bottom,-y+number:GetStringHeight()/2)
        preview.btpThreatPreview.bounds={left=left,right=right,top=top,bottom=bottom}
        local desiredScale=addon:GetNameplatePreviewRenderScale(preview:GetEffectiveScale()) * (compact and 0.7 or 1)
        local scale,fraction=addon:FitNameplatePreviewScale(desiredScale,
            right-left+4,top+bottom+4,viewport:GetWidth(),viewport:GetHeight())
        sample.content:SetScale(scale)
        sample.bar:ClearAllPoints()
        sample.bar:SetPoint("CENTER",sample.content,"CENTER",-(left+right)/2,(bottom-top)/2)
        caption:SetText(fraction<0.995 and string.format("Preview (%d%% scale)",math.floor(fraction*100+0.5)) or "Preview")
    end
    Register(preview)
    return preview
end
CreateThreatPreview(display,66,true)
local editor,snapshots
local customize=ui.Button(display,"Customize",104,24)
customize:SetPoint("TOPLEFT",420,-20)
customize:SetScript("OnClick",function() addon:OpenModernThreatDisplayOptions() end)
local visibility=Card(display,-178,48)
Toggle(visibility,"Enable Threat Display",16,-15,
    function() return addon:GetThreatDifferentialEnabled() end,
    function(v) addon:SetThreatDifferentialEnabled(v) end,190)
local tankOnly=Toggle(visibility,"Only When Assigned Tank",252,-15,
    function() return addon:GetThreatDifferentialTankOnly() end,
    function(v) addon:SetThreatDifferentialTankOnly(v) end,204)
local snapshotNote=ui.Font(display,"GameFontDisableSmall","",44,-238,480)
Register({Refresh=function()
    local enabled=addon:GetThreatDifferentialEnabled()
    ui.SetControlEnabled(tankOnly,enabled)
    local mode=addon:GetThreatDisplayMode()
    local differential=mode=="differential"
    if snapshots then snapshots:SetEnabled(enabled and differential) end
    snapshotNote:SetText(differential and "Snapshots retain the last known difference on enemies you switch away from."
        or mode=="mixed" and "Mixed: target difference; live percentages elsewhere. Falls back to percentage when needed."
        or "Threat Percentage updates live. Snapshot Duration applies to Threat Differential.")
end})
local textColors=Card(display,-282,152)
local textColorsTitle=ui.Font(textColors,"GameFontDisableSmall","",12,-10,440)
-- Fit the badge to the caption rather than the full heading width.
textColorsTitle:SetWidth(0)
local textColorsNew=addon:CreateOptionsNewFeatureTag(textColors,textColorsTitle,"LEFT","RIGHT",8,0)
local colorHint=ui.Font(display,"GameFontDisableSmall","",44,-446,480)
local mixedPaletteButtons={}
local function StyleMixedPaletteButton(button,mode,hover)
    local selected=mode==mixedColorMode
    button:SetBackdropBorderColor(unpack((selected or hover) and {0.88,0.66,0.24,1} or {0.20,0.23,0.27,1}))
    button.label:SetTextColor(unpack(selected and {0.88,0.66,0.24,1} or {0.92,0.90,0.84,1}))
end
for index,entry in ipairs({{"differential","Target Numbers"},{"percentage","Percentages"}}) do
    local mode=entry[1]
    local button=ui.Button(textColors,entry[2],112,22)
    button:SetPoint("TOPLEFT",240+(index-1)*120,-5)
    button:SetScript("OnClick",function() mixedColorMode=mode; Refresh() end)
    button:SetScript("OnEnter",function() StyleMixedPaletteButton(button,mode,true) end)
    button:SetScript("OnLeave",function() StyleMixedPaletteButton(button,mode,false) end)
    mixedPaletteButtons[mode]=button
end
Register({Refresh=function()
    local mixed=addon:GetThreatDisplayMode()=="mixed"
    local percentage=ThreatColorMode()=="percentage"
    textColorsTitle:SetText(mixed and "Mixed Colors" or percentage and "Percentage Colors" or "Threat Number Colors")
    textColorsNew:SetShown(not mixed and not percentage)
    for mode,button in pairs(mixedPaletteButtons) do
        button:SetShown(mixed)
        StyleMixedPaletteButton(button,mode,false)
    end
    colorHint:SetText(mixed and "Choose a palette above to customize target numbers or live percentages."
        or percentage and "Percentage colors are saved separately from threat number colors."
        or "Number colors apply to Threat Differential.")
end})
for index,entry in ipairs({{"secure","Have Aggro"},{"warning","Warning"},{"lost","Lost Aggro"}}) do
    local kind=entry[1]
    local function ApplyTextColor(r,g,b)
        threatPreviewState=kind
        addon:SetThreatTextColor(kind,r,g,b,ThreatColorMode())
    end
    -- Capture the palette at picker-open time, so switching modes while the
    -- picker is open cannot write/cancel into the other mode's colors.
    local label=ui.Font(textColors,"GameFontHighlightSmall",entry[2],12,-36-(index-1)*36,300)
    local swatch=ui.Button(textColors,"",36,24)
    swatch:SetPoint("TOPLEFT",364,-30-(index-1)*36)
    local fill=swatch:CreateTexture(nil,"ARTWORK")
    fill.btpDevExclude=true
    fill:SetPoint("TOPLEFT",3,-3); fill:SetPoint("BOTTOMRIGHT",-3,3)
    swatch:SetScript("OnClick",function()
        threatPreviewState=kind
        local mode=ThreatColorMode()
        local function Apply(color)
            threatPreviewState=kind
            addon:SetThreatTextColor(kind,color[1],color[2],color[3],mode)
            Refresh()
        end
        ui.OpenColorPicker({addon:GetThreatTextColor(kind,mode)},Apply,Apply)
        Refresh()
    end)
    local reset=ui.Button(textColors,"Default",66,24)
    reset:SetPoint("TOPLEFT",408,-30-(index-1)*36)
    reset:SetScript("OnClick",function()
        ApplyTextColor(addon:GetThreatTextColorDefaults(kind)); Refresh()
    end)
    swatch.Refresh=function()
        local r,g,b=addon:GetThreatTextColor(kind,ThreatColorMode())
        fill:SetColorTexture(r,g,b,1)
    end
    Register(swatch)
end
local function ResetThreatLayout()
    local p=addon.defaults.threatPosition
    addon:SetOverlayPosition("threat",p.x,p.y)
    addon:SetThreatDifferentialSize(addon.defaults.threatDifferentialSize)
    Refresh()
end
local function CreateThreatEditor()
    editor=CreateFrame("Frame","BTPModernThreatDisplayOptions",panel,"DefaultPanelTemplate")
    editor:Hide()
    editor:SetSize(568,344)
    editor:SetPoint("CENTER",panel,"CENTER")
    editor:SetFrameStrata("DIALOG")
    editor:SetFrameLevel(panel:GetFrameLevel()+80)
    editor:SetClampedToScreen(true)
    editor:EnableMouse(true)
    editor.TitleContainer.TitleText:SetText("Threat Display")
    local inset=CreateFrame("Frame",nil,editor,"BackdropTemplate")
    inset:SetPoint("TOPLEFT",14,-35)
    inset:SetPoint("BOTTOMRIGHT",-14,14)
    inset:SetFrameLevel(editor:GetFrameLevel())
    ui.Backdrop(inset,{0.065,0.075,0.090,1},{0.20,0.23,0.27,1})
    local close=CreateFrame("Button",nil,editor,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,0)
    close:SetFrameStrata("TOOLTIP")
    close:SetFrameLevel(editor:GetFrameLevel()+100)
    close:SetScript("OnClick",function() editor:Hide() end)
    local mode=ThreatModeSelector(editor,-48,124)
    mode:ClearAllPoints()
    mode:SetPoint("TOPRIGHT",-44,-48)
    local resetEditor=ui.Button(editor,"Reset",66,24)
    resetEditor:SetPoint("RIGHT",mode,"LEFT",-8,0)
    resetEditor:SetScript("OnClick",ResetThreatLayout)
    local editorPreview=CreateThreatPreview(editor,80)
    local dimensions=Card(editor,-172,142)
    Slider(dimensions,"Text Size",16,-14,198,10,32,
        function() return addon:GetThreatDifferentialSize() end,
        function(v) addon:SetThreatDifferentialSize(v) end," px")
    snapshots=Slider(dimensions,"Snapshot Duration",266,-14,198,3,10,
        function() return addon:GetThreatSnapshotSeconds() end,
        function(v) addon:SetThreatSnapshotSeconds(v) end," sec")
    for index,axis in ipairs({"x","y"}) do
        Slider(dimensions,axis=="x" and "Horizontal Position" or "Vertical Position",index==1 and 16 or 266,-78,198,-200,200,
            function() local x,y=addon:GetOverlayPosition("threat"); return axis=="x" and x or y end,
            function(value)
                local x,y=addon:GetOverlayPosition("threat")
                addon:SetOverlayPosition("threat",axis=="x" and value or x,axis=="y" and value or y)
            end," px")
    end
    local elapsed=0
    editor:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=0.25 then elapsed=0; editorPreview:Refresh() end
    end)
    panel:HookScript("OnHide",function() editor:Hide() end)
end

function addon:OpenModernThreatDisplayOptions()
    if editor and editor:IsShown() then editor:Hide(); return end
    actions.CloseEditors()
    if not editor then CreateThreatEditor() end
    Refresh()
    editor:Show()
end
function addon:CloseModernThreatDisplayOptions() if editor then editor:Hide() end end

-- Register the experimental page when its runtime and factory are available.
if addon.CreateBorderOptions and addon.GetNameplateBorderMode then
    local borders=View("borders","Border Colors (Still Testing)")
    Register(addon:CreateBorderOptions(borders,ui))
end

local tanking=View("tanking","Tanking Tools")
local tools=Card(tanking,-66,92)
Toggle(tools,"Keep Non-Target Nameplates Bright",16,-15,actions.GetNonTargetsBright,actions.SetNonTargetsBright,420)
Toggle(tools,"Flash Border When Losing Aggro",16,-55,
    function() return addon:GetThreatFlashEnabled() end,
    function(v) addon:SetThreatFlashEnabled(v) end,420)

function addon:ShowModernThreatView(key)
    local roleColors=key=="dungeon"
    active=views[key] and key or "colors"
    if active=="colors" then ShowColorPanel(roleColors and (addon:GetDungeonRaidThreatProfile() or "tank") or "general") end
    for viewKey,view in pairs(views) do view:SetShown(viewKey==active) end
    if panel:IsShown() and not DB().useLegacyNameplateOptions then DB().optionsLastThreatView=active end
    actions.CloseEditors()
    Refresh()
    if self.OnModernThreatViewChanged then self:OnModernThreatViewChanged(active) end
end
function addon:GetModernThreatView() return active end
function addon:RefreshModernThreatControls() Refresh() end
function addon:RefreshModernThreatLayout()
    local modern=not DB().useLegacyNameplateOptions
    local page=self:GetOptionsPage()
    shell:SetShown(modern and (page=="colors" or page=="roles"))
    if not shell:IsShown() then self:CloseModernThreatDisplayOptions() end
    if shell:IsShown() then
        self:ShowModernThreatView(page=="roles" and "dungeon" or DB().optionsLastThreatView or active)
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent",function() if shell:IsShown() then Refresh() end end)
addon:RefreshModernThreatLayout()
