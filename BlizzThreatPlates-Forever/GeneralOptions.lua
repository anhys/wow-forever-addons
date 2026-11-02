local addon=ForeverNameplates
local ui,panel=addon.ModernOptionsUI,addon.OptionsPanel
if not ui or not panel or not addon.OptionsPages then return end

local page=CreateFrame("Frame",nil,addon.OptionsContentInset)
page:SetAllPoints(addon.OptionsContentRoot)
page:Hide()
addon.OptionsPages.general=page

local shell=CreateFrame("Frame",nil,page,"BackdropTemplate")
shell:SetPoint("TOPLEFT",addon.OptionsContentRoot,"TOPLEFT",24,-104)
shell:SetPoint("BOTTOMRIGHT",addon.OptionsContentRoot,"BOTTOMRIGHT",-24,60)
shell:SetFrameLevel(panel:GetFrameLevel()+30)
shell:EnableMouse(true)
ui.Backdrop(shell,{0.065,0.075,0.090,1},{0.20,0.23,0.27,1})
shell:SetBackdropBorderColor(0,0,0,0)

local textLabels={}
local function LayoutText(entry)
    local label=entry.label
    -- These are our own static labels, never unit text or restricted regions.
    -- Font changes can leave a single line clipped to its previous height.
    label:SetHeight(0)
    label:SetText(entry.text)
    label:SetHeight(math.ceil(math.max(entry.size,label:GetStringHeight()))+4)
end
local function Text(parent,text,x,y,width,size,color)
    local label=ui.Font(parent,"GameFontHighlight","",x,y,width)
    addon:StyleOptionsFont(label,size)
    label.btpOptionsFontSizeOffset=size-12
    local tint=color or {0.75,0.78,0.82}
    label:SetTextColor(tint[1],tint[2],tint[3],1)
    label:SetWordWrap(true)
    local entry={label=label,text=text,size=size}
    textLabels[#textLabels+1]=entry
    LayoutText(entry)
    return label
end
local function Card(y,height)
    local card=CreateFrame("Frame",nil,shell,"BackdropTemplate")
    card:SetPoint("TOPLEFT",24,y); card:SetSize(520,height)
    ui.Backdrop(card)
    return card
end
local news=Card(-16,378)
Text(news,"What's New",18,-14,350,16,{0.92,0.93,0.95})
Text(news,"VERSION 1.4.4",400,-18,106,10,{0.88,0.66,0.24})
-- Public release highlights: keep Liquid Threat last, beside its live sample.
local highlights={
    {"Compatibility Mode","Start with threat text; optional features and normal settings stay separate."},
    {"Text Alignment & Visibility","Align or hide names, health percentages and values independently."},
    {"Target of Target","Choose whether target names appear on friendly nameplates."},
    {"Quest & CC Spacing","Quest icons stay visible; left CC closes the gap when the icon is clear."},
    {"Combo Points","Liquid Swirl preview starts correctly, including on fresh installs."},
    {"Liquid Threat Animation","Acrylic Pour threat colors, adjustable speed and live previews.","(yes its silly, just something fun)"},
}
for index,item in ipairs(highlights) do
    local y=-49-(index-1)*44
    local bullet=news:CreateTexture(nil,"ARTWORK")
    bullet:SetColorTexture(0.88,0.66,0.24,1)
    bullet:SetPoint("TOPLEFT",19,y-4); bullet:SetSize(4,4)
    local title=item[1]..(item[3] and (" |cff9ba4b0"..item[3].."|r") or "")
    Text(news,title,32,y,470,12,{0.92,0.93,0.95})
    Text(news,item[2],32,y-18,470,11)
end
local bar=CreateFrame("StatusBar",nil,news,"BackdropTemplate")
bar:SetPoint("TOPLEFT",32,-322); bar:SetSize(336,26)
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetMinMaxValues(0,100); bar:SetValue(100)
ui.Backdrop(bar,{0.015,0.02,0.025,1},{0.88,0.66,0.24,1})
local name=bar:CreateFontString(nil,"OVERLAY")
name.btpDevExclude=true
addon:SetFontWithFallback(name,addon:GetJundiesFontPath(),12,"OUTLINE")
name:SetPoint("LEFT",8,0); name:SetText("Young Wolf"); name:SetTextColor(1,1,1)
local percent=bar:CreateFontString(nil,"OVERLAY")
percent.btpDevExclude=true
addon:SetFontWithFallback(percent,addon:GetJundiesFontPath(),12,"OUTLINE")
percent:SetPoint("RIGHT",-8,0); percent:SetText("100%"); percent:SetTextColor(1,1,1)
local sample={bar=bar}
local try=ui.Button(news,"Try Me",112,26)
try:SetPoint("TOPLEFT",384,-322)
try:SetBackdropBorderColor(0.88,0.66,0.24,1)
try:HookScript("OnLeave",function(self) self:SetBackdropBorderColor(0.88,0.66,0.24,1) end)
try:SetScript("OnClick",function()
    addon.SelectOptionsPage("nameplates")
    addon:ShowModernNameplateView("liquidThreat")
end)
local elapsed,time,phase=0,0,math.acos(0.4)
page:HookScript("OnShow",function()
    for _,entry in ipairs(textLabels) do LayoutText(entry) end
    addon:PaintLiquidThreatPreview(sample,(1-math.cos(phase))*0.5,time)
end)
page:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed<0.05 then return end
    local dt=math.min(elapsed,0.15); elapsed=0
    time=time+dt*addon:GetLiquidThreatSpeed()
    phase=(phase+dt*0.25)%(math.pi*2)
    addon:PaintLiquidThreatPreview(sample,(1-math.cos(phase))*0.5,time)
end)
page:HookScript("OnHide",function() elapsed=0 end)

local feedback=Card(-410,78)
Text(feedback,"Feedback & Feature Requests",18,-14,484,13,{0.92,0.93,0.95})
Text(feedback,"Share your ideas on CurseForge. For errors, include the full message and the nameplate style you were using.",18,-38,484,11)
