local addon=ForeverNameplates
local defaults={target={1,1,1},nonTarget={0.12,0.12,0.12}}
local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Allowed(widget) return widget and not (widget.IsForbidden and widget:IsForbidden()) end
local function Settings(scope)
    local saved=ForeverNameplatesDB and ForeverNameplatesDB.borderOptions
    return type(saved)=="table" and type(saved[scope])=="table" and saved[scope] or {}
end
local function Save(scope)
    ForeverNameplatesDB=ForeverNameplatesDB or {}
    ForeverNameplatesDB.borderOptions=ForeverNameplatesDB.borderOptions or {}
    local settings=ForeverNameplatesDB.borderOptions
    settings[scope]=settings[scope] or {}
    return settings[scope]
end
function addon:InitializeNameplateBorderDefaults()
    ForeverNameplatesDB=ForeverNameplatesDB or {}
    if ForeverNameplatesDB.borderColorsDefaults==1 then return end
    -- One-time rollout for fresh installs and upgrades, including earlier
    -- experiment settings. Keep saved colors, but start both modes Original.
    local settings=ForeverNameplatesDB.borderOptions
    if type(settings)=="table" then
        for _,scope in ipairs({"target","nonTarget"}) do
            if type(settings[scope])=="table" then settings[scope].mode="default" end
        end
    else ForeverNameplatesDB.borderOptions=nil end
    -- Deliberately outside addon.defaults: later edits survive all default
    -- copying, reloads, and future builds rather than being reset repeatedly.
    ForeverNameplatesDB.borderColorsDefaults=1
end
function addon:GetNameplateBorderMode(scope)
    local mode=Settings(scope).mode
    return (mode=="custom" or mode=="threat") and mode or "default"
end
function addon:GetNameplateBorderColor(scope)
    local color=Settings(scope).color or defaults[scope]
    local function Channel(index)
        return math.max(0,math.min(1,tonumber(color[index]) or defaults[scope][index]))
    end
    return Channel(1),Channel(2),Channel(3)
end
function addon:SetNameplateBorderMode(scope,mode)
    if not defaults[scope] then return end
    Save(scope).mode=(mode=="custom" or mode=="threat") and mode or "default"
    self:RefreshNameplateBorders()
end
function addon:SetNameplateBorderColor(scope,color)
    if not defaults[scope] then return end
    Save(scope).color=color and {color[1],color[2],color[3]} or nil
    if color then Save(scope).color={self:GetNameplateBorderColor(scope)} end
    self:RefreshNameplateBorders()
end
function addon:RestoreOriginalNameplateBorders()
    if ForeverNameplatesDB then ForeverNameplatesDB.borderOptions=nil end
    self:RefreshNameplateBorders()
end
function addon:GetResolvedNameplateBorderColor(scope,kind,profile)
    local mode=self:GetNameplateBorderMode(scope)
    if mode=="custom" then return self:GetNameplateBorderColor(scope) end
    if mode=="threat" and (kind=="secure" or kind=="warning" or kind=="lost") then
        if profile=="tank" or profile=="nonTank" then return self:GetDungeonRaidThreatColor(profile,kind) end
        return self:GetThreatColor(kind)
    end
    -- No usable threat state means the original border, not a stale color.
end
function addon:GetNameplateBorderThreatKind(unit)
    if not self:IsThreatNPC(unit) then return end
    local tapped=UnitIsTapDenied and UnitIsTapDenied(unit)
    if Secret(tapped) or tapped then return end
    local status=UnitThreatSituation("player",unit)
    if Secret(status) then return end
    if status==3 then return "secure" end
    if self:IsATDStyle() and UnitExists and UnitIsUnit then
        local token=unit.."target"
        local exists=UnitExists(token)
        if not Secret(exists) and exists then
            local pet=UnitIsUnit(token,"pet")
            if not Secret(pet) and pet then return "lost" end
        end
    end
    if status==1 or status==2 then return "warning" end
    if status==0 then
        local fighting=UnitAffectingCombat(unit)
        if not Secret(fighting) and fighting then return "lost" end
    end
end

-- Cosmetic frames only. Never read health values or change native geometry.
function addon:CreateNameplateBorderOverlay(parent,anchor,style)
    local border=CreateFrame("Frame",nil,parent)
    border.btpDevExclude=true
    border:SetAllPoints(anchor or parent)
    border:SetFrameLevel(parent:GetFrameLevel()+6)
    border:EnableMouse(false)
    border.edges={}
    -- Native artwork must be a sibling of the original border/text. Putting
    -- it on the raised edge frame makes its glow cover nameplate lettering.
    border.artwork=parent:CreateTexture(nil,"OVERLAY")
    border.artwork.btpDevExclude=true
    border.nativeAnchor=anchor
    border.artwork:SetAllPoints(border)
    border:SetScript("OnHide",function(self)
        self.artwork:Hide()
        if self.flatBorder then self.flatBorder:Hide() end
    end)
    border:SetScript("OnShow",function(self)
        if self.nativePainted then self.artwork:Show() end
        if self.flatPainted and self.flatBorder then self.flatBorder:Show() end
    end)
    if border.artwork.SetSnapToPixelGrid then border.artwork:SetSnapToPixelGrid(false) end
    if border.artwork.SetTexelSnappingBias then border.artwork:SetTexelSnappingBias(0) end
    border.SetStyle=function(self,value)
        self.style=value or "flat"
        -- Native artwork must follow the plate/preview's complete transform.
        -- Scale-independent edge thickness is only for the flat ATD outline.
        if self.SetIgnoreParentScale then self:SetIgnoreParentScale(self.style=="flat") end
        if self.style=="flat" and not self.flatBorder then
            self.flatBorder=addon:CreateATDTargetBorder(parent)
            self.flatBorder.btpDevExclude=true
            self.flatBorder:ClearAllPoints()
            self.flatBorder:SetAllPoints(self)
            self.edges=self.flatBorder.edges
        end
    end
    border.Paint=function(self,r,g,b)
        local native=self.style~="flat"
        self.nativePainted=false
        self.flatPainted=false
        if native then
            if self.flatBorder then self.flatBorder:Hide() end
            local layer,sublevel="OVERLAY",self.style=="nativeLevel" and 1 or 2
            local original=self.nativeAnchor
            if Allowed(original) and original.GetDrawLayer then
                local nativeLayer,nativeSublevel=original:GetDrawLayer()
                if not Secret(nativeLayer) and type(nativeLayer)=="string"
                    and not Secret(nativeSublevel) and type(nativeSublevel)=="number" then
                    layer,sublevel=nativeLayer,nativeSublevel
                end
            end
            self.artwork:SetDrawLayer(layer,sublevel)
            local atlas=self.style=="nativeLevel" and "ui-hud-nameplates-levelindicator-rectangle-selected"
                or (NamePlateConstants and NamePlateConstants.SELECTED_BORDER_ATLAS) or "UI-HUD-CoolDownManager-Selected-yellow"
            -- Anchor to the native selection region and use its shaped atlas,
            -- never a rectangle around the atlas's transparent bounding box.
            if not self.artwork.SetAtlas or (C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas)) then
                self.artwork:Hide(); self:Hide(); return false
            end
            local ok=pcall(self.artwork.SetAtlas,self.artwork,atlas,false)
            if not ok then self.artwork:Hide(); self:Hide(); return false end
            if self.artwork.SetDesaturated then self.artwork:SetDesaturated(true) end
            self.artwork:SetVertexColor(r,g,b,1)
            self.nativePainted=true
            self.artwork:Show()
        else
            self.artwork:Hide()
            self.flatBorder:PaintColor(r,g,b)
            self.flatPainted=true
        end
        self:Show()
        return true
    end
    border:SetStyle(style)
    border:Hide()
    return border
end

local tracked={}
local overlays=setmetatable({},{__mode="k"})
local suppressed=setmetatable({},{__mode="k"})
local hooked=setmetatable({},{__mode="k"})
local painting=false
local function SetAlpha(widget,alpha)
    painting=true; widget:SetAlpha(alpha); painting=false
end
local function Suppress(widget,record)
    if not Allowed(widget) or not widget.SetAlpha or not widget.GetAlpha then return end
    if not suppressed[widget] then
        local alpha=widget:GetAlpha()
        if Secret(alpha) or type(alpha)~="number" then return end
        suppressed[widget]={alpha=alpha}
    end
    record.originals[widget]=true
    if not hooked[widget] and hooksecurefunc then
        hooked[widget]=true
        hooksecurefunc(widget,"SetAlpha",function(self,alpha)
            local saved=suppressed[self]
            if painting or not saved then return end
            if not Secret(alpha) and type(alpha)=="number" then saved.alpha=alpha end
            SetAlpha(self,0)
        end)
        for _,method in ipairs({"Show","SetShown"}) do
            if widget[method] then hooksecurefunc(widget,method,function(self)
                if suppressed[self] then SetAlpha(self,0) end
            end) end
        end
    end
    SetAlpha(widget,0)
end
local function Restore(record)
    if not record then return end
    if Allowed(record.overlay) then record.overlay:Hide() end
    if Allowed(record.badge) then record.badge:Hide() end
    for widget in pairs(record.originals) do
        local saved=suppressed[widget]
        suppressed[widget]=nil
        if saved and Allowed(widget) then SetAlpha(widget,saved.alpha) end
    end
end
local function Overlay(parent,anchor,style)
    anchor=anchor or parent
    if not overlays[anchor] then overlays[anchor]=addon:CreateNameplateBorderOverlay(parent,anchor,style) end
    overlays[anchor]:SetStyle(style)
    return overlays[anchor]
end
local function Active()
    return addon:GetNameplateBorderMode("target")~="default" or addon:GetNameplateBorderMode("nonTarget")~="default"
end
function addon:UpdateNameplateBorder(unit)
    if Secret(unit) or type(unit)~="string" or not unit:match("^nameplate%d+$") then return end
    local previous=tracked[unit]
    local function Clear() Restore(previous); tracked[unit]=nil end
    if not Active() or self:GetCompatibilityMode() then Clear(); return end
    local plate=self:GetPlate(unit)
    if not Allowed(plate) then Clear(); return end
    local frame=plate.UnitFrame
    if not Allowed(frame) then Clear(); return end
    local enemy=UnitCanAttack("player",unit)
    local selected=UnitIsUnit(unit,"target")
    if Secret(enemy) or Secret(selected) or not enemy then Clear(); return end
    local scope=selected and "target" or "nonTarget"
    local r,g,b=self:GetResolvedNameplateBorderColor(scope,self:GetNameplateBorderThreatKind(unit),self:GetDungeonRaidThreatProfile())
    if not r then Clear(); return end
    local atd=self:IsATDStyle()
    local bar=frame.healthBar
    if atd then bar=self:GetATDHealthBar(plate) end
    if not Allowed(bar) then Clear(); return end
    local anchor=atd and bar or bar.selectedBorder
    if not Allowed(anchor) then Clear(); return end
    if previous and (previous.bar~=bar or previous.anchor~=anchor or previous.frame~=frame) then Clear(); previous=nil end
    local record=previous or {bar=bar,anchor=anchor,frame=frame,originals={}}
    tracked[unit]=record
    record.overlay=Overlay(bar,anchor,not atd and "nativeBar" or "flat")
    record.overlay:SetFrameLevel(bar:GetFrameLevel()+6)
    if not record.overlay:Paint(r,g,b) then
        Restore(record); tracked[unit]=nil; return
    end
    if atd then
        local decor=frame.btpATDOverlay
        if decor then Suppress(decor.targetBorder,record) end
    else
        Suppress(bar.selectedBorder,record)
        local level=frame.PlayerLevelDiffFrame
        if Allowed(level) and Allowed(level.selectedBorder) then
            record.badge=Overlay(level,level.selectedBorder,"nativeLevel")
            if record.badge:Paint(r,g,b) then
                Suppress(level.selectedBorder,record)
            else
                local original=level.selectedBorder
                local saved=suppressed[original]
                suppressed[original]=nil
                record.originals[original]=nil
                if saved then SetAlpha(original,saved.alpha) end
            end
        end
    end
end
function addon:RefreshNameplateBorders()
    if not Active() or self:GetCompatibilityMode() then
        for unit,record in pairs(tracked) do Restore(record); tracked[unit]=nil end
        return
    end
    local seen={}
    for _,plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if Allowed(plate) and Allowed(plate.UnitFrame) then
            local unit=plate.UnitFrame.unit
            if not Secret(unit) and type(unit)=="string" and unit:match("^nameplate%d+$") then
                seen[unit]=plate
            end
        end
    end
    -- Release old owners before painting a recycled frame for its new unit.
    for unit,record in pairs(tracked) do
        if not seen[unit] or seen[unit].UnitFrame~=record.frame then Restore(record); tracked[unit]=nil end
    end
    for unit in pairs(seen) do self:UpdateNameplateBorder(unit) end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED",
    "UNIT_THREAT_SITUATION_UPDATE","UNIT_THREAT_LIST_UPDATE","PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE","PLAYER_ROLES_ASSIGNED","ZONE_CHANGED_NEW_AREA","CVAR_UPDATE","PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="NAME_PLATE_UNIT_REMOVED" then
        if Secret(unit) or type(unit)~="string" then return end
        Restore(tracked[unit]); tracked[unit]=nil
    else addon:RefreshNameplateBorders() end
end)
local elapsed=0
events:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=0.10 then elapsed=0; if Active() then addon:RefreshNameplateBorders() end end
end)
if hooksecurefunc then
    for _,method in ipairs({"RefreshATDStyle","SetCompatibilityMode","SetNameplateStyle","RefreshThreatColors"}) do
        if addon[method] then hooksecurefunc(addon,method,function() addon:RefreshNameplateBorders() end) end
    end
end
