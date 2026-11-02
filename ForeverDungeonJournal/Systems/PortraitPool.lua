-- Render portraits off-screen before attaching them to visible journal slots.
-- New renders are demand-driven and limited to one per worker update; opening
-- the journal must never submit every boss model to the graphics engine.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

FDJ.PORTRAIT_LOAD_SECONDS = 3
local RENDER_INTERVAL = 0.08
local pool, queue = {}, {}
local first, last = 1, 0
local staging, worker

local function Now() return GetTime and GetTime() or 0 end

local function Staging()
    if not staging then
        staging = CreateFrame("Frame", nil, UIParent)
        staging:SetSize(64, 64)
        staging:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 400, 0)
        staging:Show()
    end
    return staging
end

local function Park(tex)
    tex:SetParent(Staging())
    tex:ClearAllPoints()
    tex:SetAllPoints(staging)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:Show()
end

local function Place(host)
    local tex = host.fdjPooled
    if not tex or Now() < (tex.fdjReadyAt or 0) then return end
    local parent = host:GetParent()
    if not parent then return end
    tex:SetParent(parent)
    tex:ClearAllPoints()
    tex:SetAllPoints(host)
    local layer, sub = host:GetDrawLayer()
    if layer then tex:SetDrawLayer(layer, sub or 0) end
    tex:SetTexCoord(host:GetTexCoord())
    tex:SetAlpha(1)
    tex:SetShown(host:IsShown())
end

local function Attach(host, tex)
    tex.fdjHost = host
    host.fdjPooled = tex
    host:SetTexture(nil)
    local wait = (tex.fdjReadyAt or 0) - Now()
    if wait > 0 and C_Timer and C_Timer.After then
        C_Timer.After(wait + 0.05, function()
            if host.fdjPooled == tex then pcall(Place, host) end
        end)
    else
        tex.fdjReadyAt = 0
        Place(host)
    end
end

local function Spare(displayID)
    for _, tex in ipairs(pool[displayID] or {}) do
        if not tex.fdjHost then return tex end
    end
end

local function CreatePooled(displayID)
    local tex = Staging():CreateTexture(nil, "ARTWORK")
    Park(tex)
    local ok = pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
    local shown = ok and tex:GetTexture() or nil
    if shown == nil or shown == 0 or shown == "" then
        tex:Hide()
        return nil
    end
    tex.fdjDisplayID = displayID
    tex.fdjReadyAt = Now() + (FDJ.PORTRAIT_LOAD_SECONDS or 0)
    local list = pool[displayID]
    if not list then list = {}; pool[displayID] = list end
    list[#list + 1] = tex
    return tex
end

local function Visible(host)
    local parent = host:GetParent()
    return host:IsShown() and parent
        and (not parent.IsVisible or parent:IsVisible())
end

local function Drain(self, elapsed)
    if InCombatLockdown and InCombatLockdown() then return end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < RENDER_INTERVAL then return end
    -- Never catch up in a loop after a slow frame.
    self.elapsed = 0
    -- Discard stale requests in bounded batches, without rendering them.
    for _ = 1, 16 do
        if first > last then
            queue = {}; first, last = 1, 0
            self:Hide()
            return
        end
        local request = queue[first]
        queue[first] = nil; first = first + 1
        local host = request.host
        if host.fdjPortraitRequest == request then
            host.fdjPortraitRequest = nil
            if Visible(host) then
                local tex = Spare(request.displayID) or CreatePooled(request.displayID)
                if tex then
                    Attach(host, tex)
                else
                    host:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                return
            end
        end
    end
end

function FDJ.ReleasePortrait(host)
    if not host then return end
    host.fdjPortraitRequest = nil
    local tex = host.fdjPooled
    if not tex then return end
    host.fdjPooled = nil
    tex.fdjHost = nil
    Park(tex)
end

function FDJ.AcquirePortrait(host, displayID)
    if not host or type(displayID) ~= "number" or displayID <= 0 then return false end
    if type(SetPortraitTextureFromCreatureDisplayID) ~= "function" then return false end
    local current = host.fdjPooled
    if current and current.fdjDisplayID == displayID then
        Place(host)
        return true
    end
    local pending = host.fdjPortraitRequest
    if pending and pending.displayID == displayID then return true end
    FDJ.ReleasePortrait(host)
    local tex = Spare(displayID)
    if tex then
        Attach(host, tex)
        return true
    end
    local request = {host = host, displayID = displayID}
    host.fdjPortraitRequest = request
    host:SetTexture(nil)
    last = last + 1; queue[last] = request
    if not worker then
        worker = CreateFrame("Frame")
        worker:SetScript("OnUpdate", Drain)
    end
    worker:Show()
    return true
end
