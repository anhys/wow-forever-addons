local addon=ForeverNameplates
local attachments=setmetatable({}, {__mode="k"})
local leftContainers=setmetatable({}, {__mode="k"})
local leftCCLayouts=setmetatable({}, {__mode="k"})
local movedMarks=setmetatable({}, {__mode="k"})
local hooked=setmetatable({}, {__mode="k"})
local units={}
local pendingCCRefresh=setmetatable({}, {__mode="k"})
local GAP=6
local RAID_ICON_SIZE=22 -- Blizzard's RaidTargetFrame template size; never measure live frames.

local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Accessible(object)
    if not object then return false end
    local forbidden=object.IsForbidden and object:IsForbidden()
    if Secret(forbidden) or forbidden then return false end
    if object.CanBeAccessedInContext then
        local allowed=object:CanBeAccessedInContext()
        return not Secret(allowed) and allowed==true
    end
    return true
end
local function State(plate)
    local state=attachments[plate]
    if not state then state={}; attachments[plate]=state end
    return state
end
local function Shown(region)
    local shown=region:IsShown()
    return not Secret(shown) and shown==true
end
local function QuestLaneOffset(state,height,width)
    if not state or not state.quest or not Shown(state.quest) then return -GAP end
    local size,x,y=24,-6,0
    if addon.GetQuestIconSettings then size,x,y=addon:GetQuestIconSettings() end
    height=height or state.ccHeight or 30
    width=width or ((state.ccWidth or 0)>0 and state.ccWidth or nil)
    -- Both rows use the bar's left edge and center. Compare only saved quest
    -- coordinates and public CC layout sizes, never live frame measurements.
    -- If CC visibility is restricted, its unknown left edge stays unbounded
    -- so the fallback remains outside any quest icon in the same vertical lane.
    local overlapsY=math.abs(y)<(height+size)/2+GAP
    local overlapsX=x-size-GAP < -GAP and (not width or x+GAP > -GAP-width)
    if overlapsX and overlapsY then return math.min(-GAP,x-size-GAP) end
    return -GAP
end
local function LeftAnchor(plate,layout)
    local state=attachments[plate]
    local compatible = addon.GetCompatibilityMode and addon:GetCompatibilityMode()
    local optedIn = addon.GetCompatibilityFeatureEnabled and addon:GetCompatibilityFeatureEnabled("enemyDebuffs")
    if (not compatible or optedIn) and state then
        local mode=addon.GetThreatDisplayMode and addon:GetThreatDisplayMode() or "differential"
        local threat=state[mode]
        if mode=="mixed" then
            threat=state.differential
            if not threat or not Shown(threat) then threat=state.percentage end
        end
        if threat and Shown(threat) then return threat end
        if state.quest and Shown(state.quest) then
            -- Keep the restricted-visibility attachment order, reserving the
            -- quest lane only when its saved position can overlap this row.
            return addon.GetThreatOverlayAnchor and addon:GetThreatOverlayAnchor(plate),QuestLaneOffset(state,layout and layout.size)
        end
    end
    return addon.GetThreatOverlayAnchor and addon:GetThreatOverlayAnchor(plate)
end
local function PlaceLeft(container,plate)
    if not Accessible(plate) or not Accessible(container) then return end
    local layout=leftCCLayouts[container]
    local state=attachments[plate]
    local canPlaceBesideBar=layout and (layout.readable or (state and (state.ccWidth or 0)>0))
    local anchor,x
    if canPlaceBesideBar and addon.GetThreatOverlayAnchor then
        anchor,x=addon:GetThreatOverlayAnchor(plate),QuestLaneOffset(state,state and state.ccHeight or layout.size)
    else anchor,x=LeftAnchor(plate,layout) end
    x=x or -GAP
    if not Accessible(anchor) or (container.btpSideAttachment==anchor and container.btpSideAttachmentX==x) then return end
    container:ClearAllPoints()
    container:SetPoint("RIGHT",anchor,"LEFT",x,0)
    container.btpSideAttachment,container.btpSideAttachmentX=anchor,x
    return true
end
function addon:AnchorLeftAuraContainer(container,plate)
    if not container or not plate then return end
    leftContainers[container]=plate
    PlaceLeft(container,plate)
end
local function RefreshLeft(plate)
    local changed=false
    for container,owner in pairs(leftContainers) do
        if owner==plate and PlaceLeft(container,plate) then changed=true end
    end
    return changed
end
local function RestoreQuestVisibility(state)
    local quest=state.quest
    if not Accessible(quest) then return end
    -- Quest icons own their position and visibility. Left CC must never hide
    -- one, including a marker moved clear of the row. Clear legacy suppression.
    if quest.btpCCSuppressed~=false then
        quest:SetAlpha(1)
        quest.btpCCSuppressed=false
    end
end
local numbersPending=false
local function RefreshNumbers()
    if numbersPending then return end
    numbersPending=true
    local function Run()
        numbersPending=false
        if addon.RefreshThreatDisplays then addon:RefreshThreatDisplays() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end
local function RefreshCC(plate)
    if not Accessible(plate) then return end
    local width,height=0,0
    for _,layout in pairs(leftCCLayouts) do
        if layout.plate==plate and layout.enabled and layout.readable then
            local count=0
            for _,shown in pairs(layout.buttons) do if shown then count=count+1 end end
            if count>0 then
                width=math.max(width,count*layout.size+(count-1)*layout.spacing)
                height=math.max(height,layout.size)
            end
        end
    end
    local state=State(plate)
    height=height>0 and height or nil
    if state.ccWidth==width and state.ccHeight==height then return end
    state.ccWidth,state.ccHeight=width,height
    RestoreQuestVisibility(state)
    RefreshLeft(plate)
    -- Repaint existing live/snapshot numbers immediately; no aura polling.
    RefreshNumbers()
end
local function CCLayout(container)
    local layout=leftCCLayouts[container]
    if not layout then
        layout={buttons=setmetatable({}, {__mode="k"}),size=30,spacing=2,readable=true}
        leftCCLayouts[container]=layout
    end
    return layout
end
function addon:TrackLeftCCButton(button,container,previewOnly)
    local layout=CCLayout(container)
    if layout.buttons[button]~=nil then return end
    layout.buttons[button]=false
    -- Secure AuraButtons must remain script-free: even hooks installed during
    -- initialization make Blizzard's later SetShown(secret) fail. Only our
    -- ordinary sample Frames may publish visibility through script handlers.
    if previewOnly then
        button:HookScript("OnShow",function() layout.buttons[button]=true; RefreshCC(layout.plate) end)
        button:HookScript("OnHide",function() layout.buttons[button]=false; RefreshCC(layout.plate) end)
    end
end
local function ReadCCShown(button)
    -- Prefer the context-access query: temporary aura restrictions do not
    -- necessarily set the ordinary forbidden flag.
    if button.CanBeAccessedInContext then
        local allowed=button:CanBeAccessedInContext()
        if Secret(allowed) or allowed~=true then return end
    elseif button.IsForbidden then
        local forbidden=button:IsForbidden()
        if Secret(forbidden) or forbidden then return end
    end
    local shown=button:IsShown()
    if not Secret(shown) and type(shown)=="boolean" then return shown end
end
function addon:SetLeftCCLayout(container,plate,size,spacing,enabled)
    if not container or not plate then return end
    local layout=CCLayout(container)
    local previous=layout.plate
    layout.plate,layout.size,layout.spacing,layout.enabled=plate,size,spacing,enabled==true
    -- Read only public visibility at existing aura/layout refresh events.
    -- Never infer presence from allocated frames or retain a value after it
    -- becomes restricted. Unknown rows use the older collision-free spacing.
    layout.readable=true
    for button in pairs(layout.buttons) do
        local ok,shown=pcall(ReadCCShown,button)
        if ok and type(shown)=="boolean" then layout.buttons[button]=shown
        else layout.buttons[button]=false; layout.readable=false end
    end
    if previous and previous~=plate then RefreshCC(previous) end
    RefreshCC(plate)
    PlaceLeft(container,plate)
end
function addon:GetNameplateLeftCCWidth(plate)
    if addon.GetCompatibilityMode and addon:GetCompatibilityMode()
        and (not addon.GetCompatibilityFeatureEnabled or not addon:GetCompatibilityFeatureEnabled("enemyDebuffs")) then return 0 end
    local state=plate and attachments[plate]
    return state and state.ccWidth or 0
end
function addon:GetNameplateLeftCCOffset(plate)
    return QuestLaneOffset(plate and attachments[plate])
end
function addon:ClearLeftCCLayout(container)
    local layout=container and leftCCLayouts[container]
    if not layout then return end
    layout.enabled=false
    for button in pairs(layout.buttons) do layout.buttons[button]=false end
    RefreshCC(layout.plate)
end
function addon:SetNameplateThreatAttachment(plate,region,mode,visible)
    if not plate then return end
    local state=State(plate)
    if visible then
        if state[mode]==region then return end
        state[mode]=region
    elseif state[mode]==region then state[mode]=nil
    else return end
    RefreshLeft(plate)
end
function addon:SetNameplateQuestAttachment(plate,region,visible)
    if not plate then return end
    local state=State(plate)
    if visible then
        if state.quest~=region and state.quest and state.quest.btpCCSuppressed then state.quest:SetAlpha(1); state.quest.btpCCSuppressed=false end
        state.quest=region
    elseif state.quest==region then
        if region.btpCCSuppressed then region:SetAlpha(1); region.btpCCSuppressed=false end
        state.quest=nil
    else return end
    RestoreQuestVisibility(state)
    local changed=RefreshLeft(plate)
    if changed and (state.ccWidth or 0)>0 then RefreshNumbers() end
end

local function RestoreMark(mark)
    local icon=mark and movedMarks[mark]
    if not icon or not Accessible(mark) or not Accessible(icon) then return end
    if InCombatLockdown and InCombatLockdown() and mark.IsProtected and mark:IsProtected() then return end
    icon:ClearAllPoints()
    icon:SetAllPoints(mark)
    movedMarks[mark]=nil
end
local function PlaceMark(plate,unit)
    if not Accessible(plate) then return "Nameplate access restricted" end
    local frame=plate.UnitFrame
    if not Accessible(frame) then return "Unit frame missing or restricted" end
    local mark=frame.RaidTargetFrame
    if not Accessible(mark) then return "Raid marker missing or restricted" end
    local icon=mark.RaidTargetIcon
    if not Accessible(icon) then return "Raid marker texture missing or restricted" end
    if InCombatLockdown and InCombatLockdown() and mark.IsProtected and mark:IsProtected() then
        return "Raid marker protected in combat"
    end
    if not hooked[frame] then
        hooked[frame]=true
        local function UpdateMarker()
            local token=frame.unit or frame.displayedUnit
            if not Secret(token) and type(token)=="string" then
                local owner=addon:GetPlate(token)
                if owner and owner.UnitFrame==frame then PlaceMark(owner,token) end
            end
        end
        -- The texture's anchor is independent of the native marker frame, so
        -- Blizzard can relayout that frame without a Lua method hook here.
        if mark.HookScript then
            mark:HookScript("OnShow",UpdateMarker)
            mark:HookScript("OnHide",function() RestoreMark(mark) end)
        end
    end
    -- Move only the texture. The native marker frame stays in Blizzard's
    -- layout because classification icons depend on its original anchors.
    if not Shown(mark) then RestoreMark(mark); return "Native raid marker hidden" end
    local hostile=unit and UnitCanAttack and UnitCanAttack("player",unit)
    if Secret(hostile) then RestoreMark(mark); return "Hostility restricted" end
    if not hostile then RestoreMark(mark); return "Unit not attackable" end
    if addon.GetCompatibilityMode and addon:GetCompatibilityMode() then
        RestoreMark(mark); return "Compatibility mode enabled"
    end
    if frame.IsShowOnlyName then
        local nameOnly=frame:IsShowOnlyName()
        if Secret(nameOnly) then RestoreMark(mark); return "Name-only state restricted" end
        if nameOnly then RestoreMark(mark); return "Name-only display active" end
    end
    local anchor=addon.GetThreatOverlayAnchor and addon:GetThreatOverlayAnchor(plate)
    if not Accessible(anchor) then return "Health bar anchor missing or restricted" end
    -- Native styles have a level badge beyond the health bar's right edge.
    -- ATD has no visible level badge; its own health bar is the right boundary.
    if not addon:IsATDStyle() and (not addon.GetMobLevelEnabled or addon:GetMobLevelEnabled()) then
        local level=frame.PlayerLevelDiffFrame or frame.LevelFrame
        if Accessible(level) and Shown(level) then anchor=level end
    end
    icon:ClearAllPoints()
    icon:SetSize(RAID_ICON_SIZE,RAID_ICON_SIZE)
    icon:SetPoint("LEFT",anchor,"RIGHT",GAP,0)
    movedMarks[mark]=icon
    return "Raid marker moved right"
end
function addon:RefreshNameplateAttachments(plate,unit)
    if plate then
        local state=attachments[plate]
        if state then RestoreQuestVisibility(state) end
        RefreshLeft(plate)
        return PlaceMark(plate,unit or (plate.UnitFrame and (plate.UnitFrame.unit or plate.UnitFrame.displayedUnit)))
    else
        for token,owner in pairs(units) do
            local state=attachments[owner]; if state then RestoreQuestVisibility(state) end
            RefreshLeft(owner); PlaceMark(owner,token)
        end
    end
end

-- Print before touching live frames so a layout error cannot silently swallow
-- the diagnostic. Keep this separate from the automatic event/hook paths.
SLASH_BTPMARKER1="/btpmarker"
SlashCmdList.BTPMARKER=function()
    print("BTP marker: diagnostic running")
    local ok,result=pcall(function()
        local plate=addon:GetPlate("target")
        if not plate then return "Target nameplate not visible" end
        return addon:RefreshNameplateAttachments(plate,"target")
    end)
    if Secret(result) then result="Restricted diagnostic result" end
    print("BTP marker: "..(ok and "" or "Lua error: ")..tostring(result or "No layout result"))
end

-- Reuse nameplate/raid-marker events; threat and quest changes publish their
-- own anchor updates. No polling and no aura or secret text measurements.
local events=CreateFrame("Frame")
for _,event in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","RAID_TARGET_UPDATE",
    "PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","UNIT_FACTION","UNIT_AURA","CVAR_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="UNIT_AURA" then
        if Secret(unit) or type(unit)~="string" or not unit:match("^nameplate%d+$") then return end
        local plate=units[unit]
        if not plate or pendingCCRefresh[plate] then return end
        pendingCCRefresh[plate]=true
        local function Run()
            pendingCCRefresh[plate]=nil
            if units[unit]~=plate then return end
            for container,layout in pairs(leftCCLayouts) do
                if layout.plate==plate and layout.enabled then
                    addon:SetLeftCCLayout(container,plate,layout.size,layout.spacing,true)
                end
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
        return
    end
    if event=="NAME_PLATE_UNIT_REMOVED" then
        if Secret(unit) then return end
        local plate=units[unit]
        units[unit]=nil
        if plate then
            local assigned
            if Accessible(plate) and Accessible(plate.UnitFrame) then
                assigned=plate.UnitFrame.unit
                if not Secret(assigned) and assigned==nil then assigned=plate.UnitFrame.displayedUnit end
            end
            if not Secret(assigned) and assigned and assigned~=unit then return end
            local state=attachments[plate]
            if state and state.quest and state.quest.btpCCSuppressed then state.quest:SetAlpha(1); state.quest.btpCCSuppressed=false end
            for _,layout in pairs(leftCCLayouts) do
                if layout.plate==plate then layout.enabled=false; for button in pairs(layout.buttons) do layout.buttons[button]=false end end
            end
            attachments[plate]=nil
            RefreshLeft(plate)
            local frame=Accessible(plate) and plate.UnitFrame
            if Accessible(frame) then RestoreMark(frame.RaidTargetFrame) end
        end
        return
    end
    if event=="NAME_PLATE_UNIT_ADDED" then
        if Secret(unit) or type(unit)~="string" then return end
        local plate=addon:GetPlate(unit)
        if Accessible(plate) then
            units[unit]=plate
            addon:RefreshNameplateAttachments(plate,unit)
        end
        return
    end
    if event=="CVAR_UPDATE" and (type(unit)~="string" or not unit:lower():match("^nameplate")) then return end
    if event=="PLAYER_ENTERING_WORLD" then
        for key in pairs(units) do units[key]=nil end
        for index=1,40 do
            local token="nameplate"..index
            local plate=addon:GetPlate(token)
            if Accessible(plate) then units[token]=plate end
        end
    end
    addon:RefreshNameplateAttachments()
end)
