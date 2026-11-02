-- Shared Acrylic Pour artwork and safe threat calibration. Textures are lazy:
-- disabled nameplates allocate no liquid regions and run no animation driver.
local addon=ForeverNameplates
local DEFAULT_SPEED=1.5
local ROOT="Interface\\AddOns\\BlizzThreatPlates-Forever\\media\\liquid\\"
local GREEN,YELLOW,RED,ORANGE={0.04,0.82,0.06},{1,0.82,0.015},{0.96,0.025,0.01},{1,0.38,0.01}
local function Clamp(value) return math.max(0,math.min(1,value)) end
local function Smooth(value)
    value=Clamp(value)
    return value*value*(3-2*value)
end
local function Blend(a,b,t)
    return a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t
end
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function Read(api,...)
    if not api then return nil end
    local ok,value=pcall(api,...)
    if ok and Public(value) then return value end
end
local function ReadThreatAmount(source,mob)
    if not UnitDetailedThreatSituation then return nil,true end
    local ok,_,_,_,_,amount=pcall(UnitDetailedThreatSituation,source,mob)
    if not ok or not Public(amount) then return nil,true end
    if amount==nil then return nil,false end
    if type(amount)=="number" and amount==amount and amount>=0 then return amount,false end
    return nil,true
end
local function CompetesForThreat(source,mob)
    local exists=Read(UnitExists,source)
    if exists==false then return false,nil,false end
    if exists~=true then return false,nil,true end
    local same=Read(UnitIsUnit,source,"player")
    if same==true then return false,nil,false end
    if same~=false then return false,nil,true end
    local threat=Read(UnitThreatSituation,source,mob)
    local amount,restricted=ReadThreatAmount(source,mob)
    if amount~=nil then return amount>0,amount,false end
    -- A readable status (including 0) confirms a threat-list entry when its
    -- amount is unavailable. Do not require raw values on restricted plates.
    local present=type(threat)=="number"
    return present,nil,restricted or present
end
local function GetCompetition(mob,readAll)
    local present,highest,complete=false,nil,true
    local function Consider(source)
        local competes,amount,unknown=CompetesForThreat(source,mob)
        present=present or competes
        if unknown then complete=false end
        if amount and amount>0 and (not highest or amount>highest) then highest=amount end
    end
    Consider("pet")
    if present and not readAll then return true end
    local raid=Read(IsInRaid)==true
    if not raid and Read(IsInGroup)~=true then return present,highest,complete end
    local count=Read(raid and GetNumGroupMembers or GetNumSubgroupMembers)
    if type(count)~="number" or count~=count then return present,highest,false end
    local prefix,petPrefix=raid and "raid" or "party",raid and "raidpet" or "partypet"
    for index=1,math.min(raid and 40 or 4,count) do
        Consider(prefix..index); Consider(petPrefix..index)
        if present and not readAll then return true end
    end
    return present,highest,complete
end
local function ReadComparisonLead(mob)
    local mine=ReadThreatAmount("player",mob)
    if mine==nil then return nil end
    local _,highest,complete=GetCompetition(mob,true)
    -- Never derive a ratio from only the readable portion of a group roster.
    if not complete or not highest then return nil end
    return mine/highest*100
end
local function AcrylicProgressFromLead(lead)
    -- Visual anchors: 160% lead = safe; 100% = tied/35%; 94% = 38%;
    -- 50% = the chosen fully-lost mix. These are not aggro thresholds.
    if lead>=100 then return Clamp((160-lead)/60)*0.35 end
    if lead>=94 then return 0.35+(100-lead)/6*0.03 end
    return 0.38+Clamp((94-lead)/44)*0.62
end
function addon:GetLiquidThreatColor(progress)
    progress=Clamp(progress)
    if progress<=0.5 then return Blend(GREEN,YELLOW,progress*2) end
    return Blend(YELLOW,RED,(progress-0.5)*2)
end
local function Effect(decor,progress)
    local effect=decor.btpLiquidThreat
    if not effect then
        effect={phase=math.random()*64,rateA=0.83+math.random()*0.34,
            rateB=0.67+math.random()*0.38,rateC=0.55+math.random()*0.35}
        -- Text stays on OVERLAY. Artwork follows only the health fill's bounds,
        -- without measuring secret health dimensions or covering missing health.
        for index=1,6 do
            local texture=decor.bar:CreateTexture(nil,"ARTWORK",nil,index)
            texture:SetAllPoints(decor.bar:GetStatusBarTexture())
            texture:SetBlendMode("BLEND")
            effect[index]=texture
        end
        decor.btpLiquidThreat=effect
    end
    -- Reuse the six regions when comparing materials, including on live plates.
    local hot=progress>=0.36
    if effect.hot~=hot then
        -- A new asset name also avoids reusing the game's cached 64-frame art.
        local stem="acrylic-currents"
        for index,texture in ipairs(effect) do
            local suffix=(index==3 or index==4) and "-detail.tga" or "-flow.tga"
            if hot and index<=4 then suffix="-hot"..suffix end
            texture:SetTexture(ROOT..stem..suffix,"CLAMP","CLAMP","LINEAR")
        end
        effect.hot=hot
    end
    return effect
end
local function Hide(decor)
    local effect=decor.btpLiquidThreat
    if effect then for _,texture in ipairs(effect) do texture:Hide() end end
end
local function FrameUV(texture,frame,frames)
    local col,row=frame%8,math.floor(frame/8)
    -- Half-texel gutters keep neighboring animation frames out of the sample.
    texture:SetTexCoord((col*256+0.5)/2048,(col*256+255.5)/2048,
        (row*64+0.5)/(frames*8),(row*64+63.5)/(frames*8))
end
local function PaintStream(effect,index,r,g,b,strength,time,offset)
    local frames=128
    local phase=(time*6.4+offset)%frames
    local frame=math.floor(phase)
    local blend=phase-frame
    local a,bTexture=effect[index],effect[index+1]
    FrameUV(a,frame,frames); FrameUV(bTexture,(frame+1)%frames,frames)
    a:SetVertexColor(r,g,b,1); bTexture:SetVertexColor(r,g,b,1)
    a:SetAlpha(strength*(1-blend)); bTexture:SetAlpha(strength*blend)
end
local function PaintAcrylic(decor,effect,progress,time,shade)
    local loss=progress
    -- Keep the earlier anchors; extend the former 75-81% mix over the final
    -- quarter so 100% retains the chosen animated red/yellow endpoint.
    if progress>0.75 then progress=0.75+(progress-0.75)*0.24 end
    local cool,warm,q=GREEN,YELLOW
    if progress<0.36 then
        -- Start at the old 10% look, rejoining the existing curve at 20%.
        -- Keep the 30% balance and clear green before red can enter.
        if progress<=0.30 then q=0.10+0.17*Smooth(progress/0.30)+0.03*Smooth(progress/0.20)
        else q=0.30+0.20*Smooth((progress-0.30)/0.06) end
    else
        -- Orange folds start in the yellow range. Red enters after 65% loss,
        -- reaching the original red at 81%, preserving the chosen endpoint.
        effect.warm=effect.warm or {}
        effect.warm[1],effect.warm[2],effect.warm[3]=Blend(ORANGE,RED,Smooth((loss-0.65)/0.16))
        cool,warm=YELLOW,effect.warm
        if progress<=0.40 then q=0.13*Smooth((progress-0.36)/0.04)
        else q=0.13+0.37*Smooth((progress-0.40)/0.60) end
    end
    local balance=q*2
    -- Keep a true yellow base under the first localized red veins.
    if cool==YELLOW then balance=Smooth((q-0.20)/0.30) end
    local r,g,b=Blend(cool,warm,balance)
    -- Broader yellow shading exposes the original fine marbling between the
    -- sparse red folds. Ease in after the favored green/yellow range and
    -- return to the existing red/yellow recipe by 75%.
    local nuance=Smooth((progress-0.30)/0.06)*(1-Smooth((progress-0.64)/0.11))
    r=r+(1-r)*nuance*0.65
    g=g+(0.94-g)*nuance*0.65
    b=b+(0.18-b)*nuance*0.65
    decor.bar:SetStatusBarColor(r,g,b,1)
    local fade=1-Smooth((q-0.30)/0.20)
    local incoming=math.sin(math.pi*q/0.65)*0.96*fade
    if cool==YELLOW then incoming=Smooth(q/0.13)*0.98*fade end
    local retained=math.sin(math.pi*q)*0.94*fade
    local cr,cg,cb=cool[1]*shade,cool[2]*shade,cool[3]*shade
    cr=cr+(1-cr)*nuance
    cg=cg+(0.46-cg)*nuance
    cb=cb+(0.005-cb)*nuance
    retained=retained+(0.78-retained)*nuance
    local wr,wg,wb=warm[1],warm[2],warm[3]
    if warm==YELLOW then wr,wg,wb=1,0.88,0.025 end
    PaintStream(effect,1,wr,wg,wb,incoming,time*effect.rateA,effect.phase)
    PaintStream(effect,3,wr,wg,wb,incoming*0.22*Smooth((q-0.13)/0.17),time*effect.rateB,effect.phase+19)
    PaintStream(effect,5,cr,cg,cb,retained,time*effect.rateC,effect.phase+41)
end
function addon:GetLiquidThreatProgress(unit,allowCosmetic)
    -- No math, comparison, formatting or logging of restricted threat values.
    if not self:IsThreatNPC(unit) then return nil end
    local fighting=Read(UnitAffectingCombat,unit)
    local tapped=UnitIsTapDenied and Read(UnitIsTapDenied,unit)
    if UnitIsTapDenied and tapped~=false then return nil end
    -- Only ApplyLiquidThreat's selected plate passes the target token. These
    -- fixed idle mixes never enter the live threat cache or affect other mobs.
    if allowCosmetic and unit=="target" and fighting==false and Read(UnitAffectingCombat,"player")==false then
        if self:ShouldColorQuestMob(unit) then return 0.73,"cosmetic" end
        local reaction=Read(UnitReaction,unit,"player")
        if type(reaction)=="number" then
            if reaction<=3 then return 0.97,"cosmetic"
            elseif reaction==4 then return 0.34,"cosmetic" end
        end
    end
    if fighting~=true then return nil end
    if self:ShouldColorQuestMob(unit) then return nil end
    local threat=Read(UnitThreatSituation,"player",unit)
    if type(threat)~="number" then return nil end
    -- A solo lead value is not an actual contest. Keep secure solo attacks
    -- at the chosen safe mix until another player or pet has threat.
    if threat==3 then
        local competing,_,complete=GetCompetition(unit)
        if not competing and complete then return 0,"solo safe",threat end
    end
    local lead=Read(UnitThreatPercentageOfLead,"player",unit)
    local source="lead percentage"
    if not (type(lead)=="number" and lead==lead and lead>=0) then
        lead=ReadComparisonLead(unit)
        source="raw comparison"
    end
    if type(lead)=="number" and lead==lead and lead>=0 then
        return AcrylicProgressFromLead(lead),source,threat
    end
    -- Keep the readable threat states meaningful when continuous lead is secret.
    if threat==0 then return 1,"threat state",threat
    elseif threat==3 then return 0,"threat state",threat elseif threat==2 then return 0.55,"threat state",threat
    elseif threat==1 then return 0.65,"threat state",threat end
end

function addon:PaintLiquidThreatPreview(decor,progress,time)
    progress=Clamp(progress)
    local effect=Effect(decor,progress)
    PaintAcrylic(decor,effect,progress,time or 0,0.90)
    for _,texture in ipairs(effect) do texture:Show() end
end
function addon:HideLiquidThreatPreview(decor) Hide(decor) end

local entries=setmetatable({}, {__mode="k"})
local driver=CreateFrame("Frame")
driver.btpLiquidThreatDriver=true
driver:Hide()
local elapsed,pollElapsed,time=0,0,0
local function Settings()
    local saved=ForeverNameplatesDB and ForeverNameplatesDB.liquidThreat
    return type(saved)=="table" and saved or {}
end
function addon:IsLiquidThreatEnabled() return Settings().enabled==true end
function addon:GetLiquidThreatSpeed()
    local speed=Settings().speed
    return type(speed)=="number" and speed==speed and math.max(0.25,math.min(3,speed)) or DEFAULT_SPEED
end
function addon:IsLiquidThreatStyleSupported()
    if not self:IsATDStyle() then return false end
    local style=self:GetNameplateStyleFamily()
    return style=="ATD" or style=="JUNDIES"
end
local function Save(key,value)
    ForeverNameplatesDB=ForeverNameplatesDB or {}
    if type(ForeverNameplatesDB.liquidThreat)~="table" then ForeverNameplatesDB.liquidThreat={} end
    ForeverNameplatesDB.liquidThreat[key]=value
end
local function UpdateDriver()
    driver:SetShown(next(entries)~=nil)
end
local function Clear()
    for decor in pairs(entries) do Hide(decor) end
    entries=setmetatable({}, {__mode="k"})
    driver:Hide()
    elapsed,pollElapsed=0,0
end
function addon:SetLiquidThreatEnabled(enabled)
    if enabled and not self:IsLiquidThreatStyleSupported() then return false end
    Save("enabled",enabled==true)
    Clear()
    if self.RefreshATDStyle then self:RefreshATDStyle() end
    return true
end
function addon:SetLiquidThreatSpeed(speed)
    if type(speed)~="number" or speed~=speed then return end
    Save("speed",math.max(0.25,math.min(3,speed)))
end
function addon:ResetLiquidThreat()
    Save("speed",DEFAULT_SPEED)
    self:SetLiquidThreatEnabled(false)
end
local function LabActive()
    return addon.IsDevLiquidThreatActive and addon:IsDevLiquidThreatActive()
end
function addon:ApplyLiquidThreat(decor,unit)
    if not self:IsLiquidThreatEnabled() then
        -- No regions are allocated before the feature is first enabled.
        if entries[decor] then entries[decor]=nil; Hide(decor); UpdateDriver() end
        return
    end
    if not self:IsLiquidThreatStyleSupported() or LabActive() then
        entries[decor]=nil; Hide(decor); UpdateDriver(); return
    end
    local token=decor.plate==self:GetPlate("target") and "target" or unit
    local goal,source,threat=self:GetLiquidThreatProgress(token,true)
    if goal==nil then entries[decor]=nil; Hide(decor); UpdateDriver(); return end
    local entry=entries[decor]
    local guid=Read(UnitGUID,unit)
    if type(guid)~="string" then guid=nil end
    local cosmetic=source=="cosmetic"
    if not entry or entry.unit~=unit or (guid and entry.guid~=guid) or entry.cosmetic~=cosmetic then
        entry={unit=unit,guid=guid,current=goal,cosmetic=cosmetic}; entries[decor]=entry
    end
    if cosmetic then entry.current=goal; entry.readableGoal,entry.readableThreat=nil,nil
    else
        if entry.readableThreat~=threat then entry.readableGoal=nil end
        if source=="threat state" and entry.readableGoal~=nil then goal=entry.readableGoal
        elseif source~="threat state" then entry.readableGoal=goal end
        entry.readableThreat=threat
    end
    entry.goal=goal
    self:PaintLiquidThreatPreview(decor,entry.current,time)
    UpdateDriver()
end

driver:SetScript("OnUpdate",function(_,delta)
    if not addon:IsLiquidThreatEnabled() or not addon:IsLiquidThreatStyleSupported() or LabActive() then Clear(); return end
    elapsed=elapsed+delta; pollElapsed=pollElapsed+delta
    if elapsed<0.05 then return end
    local dt=math.min(elapsed,0.15); elapsed=0
    time=time+dt*addon:GetLiquidThreatSpeed()
    local poll=pollElapsed>=0.25
    if poll then pollElapsed=0 end
    local restore=false
    for decor,entry in pairs(entries) do
        if not decor.anchor:IsShown() or addon:GetPlate(entry.unit)~=decor.plate then
            entries[decor]=nil; Hide(decor)
        else
            if poll then
                addon:ApplyLiquidThreat(decor,entry.unit)
                entry=entries[decor]
                if not entries[decor] then restore=true end
            end
            if entries[decor] then
                entry.current=entry.current+(entry.goal-entry.current)*(1-math.exp(-dt*5))
                if math.abs(entry.goal-entry.current)<0.002 then entry.current=entry.goal end
                addon:PaintLiquidThreatPreview(decor,entry.current,time)
            end
        end
    end
    UpdateDriver()
    if restore and addon.RefreshATDStyle then addon:RefreshATDStyle() end
end)

local refreshQueued=false
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
    "UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED"}) do driver:RegisterEvent(event) end
driver:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_TARGET_CHANGED" then
        for decor,entry in pairs(entries) do
            if entry.cosmetic then entries[decor]=nil; Hide(decor) end
        end
        UpdateDriver()
        if addon:IsLiquidThreatEnabled() and addon:IsLiquidThreatStyleSupported() and not LabActive()
            and addon.RefreshATDStyle then addon:RefreshATDStyle() end
        return
    end
    if event=="NAME_PLATE_UNIT_REMOVED" then
        if not Public(unit) then return end
        for decor,entry in pairs(entries) do
            if entry.unit==unit then entries[decor]=nil; Hide(decor) end
        end
        UpdateDriver(); return
    end
    if event=="PLAYER_ENTERING_WORLD" then Clear() end
    if not addon:IsLiquidThreatEnabled() or not addon:IsLiquidThreatStyleSupported() or LabActive() or refreshQueued then return end
    refreshQueued=true
    C_Timer.After(0.1,function()
        refreshQueued=false
        if addon:IsLiquidThreatEnabled() and addon:IsLiquidThreatStyleSupported() and addon.RefreshATDStyle then addon:RefreshATDStyle() end
    end)
end)

