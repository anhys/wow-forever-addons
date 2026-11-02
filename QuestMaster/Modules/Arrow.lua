--[[
    QuestMaster Arrow Module
    Premium HD Navigation Arrow with custom styling
    Features smooth animations, glow effects, and multiple arrow styles
]]

local addonName, QM = ...
local L = QM.L
local HBD = QM.HBD

-- Arrow frame
local ArrowFrame = nil

-- Constants
local ARROW_SIZE = 52
local UPDATE_INTERVAL = 0.15  -- ~7fps (smooth enough for arrow, saves CPU)
local AUTO_WAYPOINT_INTERVAL = 5.0  -- Check for better waypoint every 5 seconds
-- ARRIVAL_DISTANCE now uses QM.db.profile.arrow.arrivalDist (default: 10)

-- State
local lastUpdate = 0
local lastAutoUpdate = 0
local lastOrientation = 0
local lowerbound = math.pi / 64
local upperbound = 2 * math.pi - lowerbound
local lastZone = nil  -- Track zone changes for ETA reset

-- Pre-computed format strings (avoid repeated concatenation in DrawArrow)
local fmtDistKm, fmtDistYd
local fmtEtaSec, fmtEtaMin, fmtEtaHr
local lastDistText = ""
local lastDistValue = -1

-- ============================================================================
-- HereBeDragons Coordinate Validation
-- ============================================================================

-- Validates and returns player world position, or nil if invalid
local function GetValidPlayerPosition()
    if not HBD then return nil, nil, nil end
    local x, y, instance = HBD:GetPlayerWorldPosition()
    if not x or not y or x == 0 or y == 0 then
        return nil, nil, nil
    end
    return x, y, instance
end

-- Validates and returns world coordinates from zone, or nil if invalid
local function GetValidWorldCoordinates(zoneX, zoneY, mapId)
    if not HBD or not zoneX or not zoneY or not mapId then
        return nil, nil, nil
    end
    local wx, wy, instance = HBD:GetWorldCoordinatesFromZone(zoneX, zoneY, mapId)
    if not wx or not wy then
        return nil, nil, nil
    end
    return wx, wy, instance
end

-- Validates waypoint is reachable from current zone (same instance or connected)
local function IsWaypointReachable(waypointMapId, playerInstance)
    if not waypointMapId or not playerInstance then return false end
    -- Same instance is always reachable
    if waypointMapId == playerInstance then return true end
    -- For now, assume waypoints in different instances may still be reachable
    -- (continent transitions, portals, etc.)
    return true
end

-- Color presets for arrow
local ARROW_COLORS = {
    gold = {1, 0.82, 0},
    green = {0.2, 1, 0.3},
    blue = {0.3, 0.7, 1},
    red = {1, 0.3, 0.3},
    white = {1, 1, 1},
    purple = {0.7, 0.3, 1},
    cyan = {0, 1, 1},
}

-- ============================================================================
-- Arrow Creation - Clean Minimal Design
-- ============================================================================

function QM:InitializeArrow()
    -- Pre-compute format strings to avoid concatenation in DrawArrow hot path
    fmtDistKm = "%%.1f %s"
    fmtDistYd = "%%d %s"
    fmtDistKm = fmtDistKm:format(L["KILOMETERS"])
    fmtDistYd = fmtDistYd:format(L["YARDS"])

    ArrowFrame = CreateFrame("Frame", "QuestMasterArrow", UIParent)
    ArrowFrame:SetSize(180, 80)
    ArrowFrame:SetPoint(
        QM.db.profile.arrow.point or "TOP",
        UIParent,
        QM.db.profile.arrow.point or "TOP",
        QM.db.profile.arrow.x or 0,
        QM.db.profile.arrow.y or -100
    )
    ArrowFrame:SetFrameStrata("HIGH")
    ArrowFrame:SetClampedToScreen(true)
    ArrowFrame:EnableMouse(true)
    ArrowFrame:SetMovable(true)
    ArrowFrame:RegisterForDrag("LeftButton")

    -- Arrow container (no background, just holds the arrow)
    local arrowContainer = CreateFrame("Frame", nil, ArrowFrame)
    arrowContainer:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrowContainer:SetPoint("TOP", ArrowFrame, "TOP", 0, 0)
    ArrowFrame.arrowContainer = arrowContainer

    -- Subtle shadow for depth
    local shadow = arrowContainer:CreateTexture(nil, "BACKGROUND")
    shadow:SetSize(ARROW_SIZE + 4, ARROW_SIZE + 4)
    shadow:SetPoint("CENTER", 1, -1)
    shadow:SetTexture("Interface\\MINIMAP\\ROTATING-MINIMAPGUIDEARROW")
    shadow:SetVertexColor(0, 0, 0, 0.4)
    ArrowFrame.shadow = shadow

    -- Main arrow texture - clean and simple
    local arrow = arrowContainer:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\MINIMAP\\ROTATING-MINIMAPGUIDEARROW")
    arrow:SetVertexColor(0.2, 0.9, 0.3)  -- Green by default
    ArrowFrame.arrow = arrow

    -- Arrived checkmark
    local check = arrowContainer:CreateTexture(nil, "OVERLAY")
    check:SetSize(ARROW_SIZE * 0.7, ARROW_SIZE * 0.7)
    check:SetPoint("CENTER")
    check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    check:Hide()
    ArrowFrame.checkmark = check

    -- Distance display - clean text with outline
    local dist = ArrowFrame:CreateFontString(nil, "OVERLAY")
    dist:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    dist:SetPoint("TOP", arrowContainer, "BOTTOM", 0, 0)
    dist:SetTextColor(1, 1, 1)
    dist:SetText("--")
    dist:SetShadowOffset(1, -1)
    dist:SetShadowColor(0, 0, 0, 1)
    ArrowFrame.distance = dist

    -- ETA text (smaller, below distance)
    local eta = ArrowFrame:CreateFontString(nil, "OVERLAY")
    eta:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    eta:SetPoint("TOP", dist, "BOTTOM", 0, -1)
    eta:SetTextColor(0.7, 0.7, 0.7)
    eta:SetText("")
    eta:SetShadowOffset(1, -1)
    eta:SetShadowColor(0, 0, 0, 0.8)
    ArrowFrame.eta = eta

    -- Objective text (optional, shows what you're going to)
    local obj = ArrowFrame:CreateFontString(nil, "OVERLAY")
    obj:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    obj:SetPoint("TOP", eta, "BOTTOM", 0, -1)
    obj:SetWidth(180)
    obj:SetWordWrap(true)
    obj:SetTextColor(0.8, 0.8, 0.8)
    obj:SetText("")
    obj:SetShadowOffset(1, -1)
    obj:SetShadowColor(0, 0, 0, 0.8)
    ArrowFrame.objective = obj

    -- Compatibility - create dummy elements that other code might reference
    ArrowFrame.outerGlow = arrowContainer:CreateTexture(nil, "BACKGROUND")
    ArrowFrame.outerGlow:SetAlpha(0)
    ArrowFrame.outerGlow:Hide()
    ArrowFrame.innerGlow = arrowContainer:CreateTexture(nil, "BACKGROUND")
    ArrowFrame.innerGlow:SetAlpha(0)
    ArrowFrame.innerGlow:Hide()
    ArrowFrame.trail = arrowContainer:CreateTexture(nil, "BACKGROUND")
    ArrowFrame.trail:SetAlpha(0)
    ArrowFrame.trail:Hide()
    ArrowFrame.checkBg = arrowContainer:CreateTexture(nil, "BACKGROUND")
    ArrowFrame.checkBg:SetAlpha(0)
    ArrowFrame.checkBg:Hide()
    ArrowFrame.highlight = arrowContainer:CreateTexture(nil, "BACKGROUND")
    ArrowFrame.highlight:SetAlpha(0)
    ArrowFrame.highlight:Hide()

    -- Movement speed tracking for ETA
    ArrowFrame.lastX = nil
    ArrowFrame.lastY = nil
    ArrowFrame.speeds = {}
    ArrowFrame.speedIndex = 1

    -- Dragging
    ArrowFrame:SetScript("OnDragStart", function(self)
        if not QM.db.profile.lockFrames then
            self:StartMoving()
        end
    end)

    ArrowFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        QM.db.profile.arrow.point = point
        QM.db.profile.arrow.x = x
        QM.db.profile.arrow.y = y
    end)

    -- Store waypoint world coordinates
    ArrowFrame.targetWX = nil
    ArrowFrame.targetWY = nil
    ArrowFrame.targetInstance = nil

    -- Main update loop - simple, no fancy effects
    ArrowFrame:SetScript("OnUpdate", function(self, elapsed)
        lastUpdate = lastUpdate + elapsed
        lastAutoUpdate = lastAutoUpdate + elapsed

        if lastUpdate >= UPDATE_INTERVAL then
            QM:DrawArrow(elapsed)
            lastUpdate = 0
        end

        if lastAutoUpdate >= AUTO_WAYPOINT_INTERVAL then
            QM:AutoSelectBestWaypoint()
            lastAutoUpdate = 0
        end
    end)

    -- Tooltip
    ArrowFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("|cFFFFD700QuestMaster|r |cFFAAAAAA" .. L["ARROW_NAVIGATION"] .. "|r")
        if QM.currentWaypoint then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(QM.currentWaypoint.description or L["OBJECTIVE"], 1, 1, 1)
            if QM.currentWaypoint.questId then
                local quest = QM.activeQuests[QM.currentWaypoint.questId]
                if quest then
                    GameTooltip:AddLine(quest.title, 0.7, 0.7, 0.7)
                end
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888" .. L["LEFT_CLICK_DRAG"] .. "|r")
        GameTooltip:AddLine("|cFF888888" .. L["RIGHT_CLICK_OPTIONS"] .. "|r")
        GameTooltip:Show()
    end)

    ArrowFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Right-click menu
    ArrowFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            QM:ShowArrowContextMenu()
        end
    end)

    QM.ArrowFrame = ArrowFrame
    ArrowFrame:Show()

    -- Apply saved settings
    QM:UpdateArrowSettings()

    -- Initial waypoint selection
    C_Timer.After(2, function()
        QM:AutoSelectBestWaypoint(true)
    end)
end

-- ============================================================================
-- Arrow Drawing - Premium HD
-- ============================================================================

function QM:DrawArrow(elapsed)
    if not ArrowFrame or not ArrowFrame:IsShown() then return end

    local waypoint = self.currentWaypoint
    if not waypoint then
        -- No waypoint - show idle state
        ArrowFrame.arrow:SetRotation(0)
        ArrowFrame.shadow:SetRotation(0)
        ArrowFrame.trail:SetRotation(0)
        ArrowFrame.arrow:SetVertexColor(0.4, 0.4, 0.4)
        ArrowFrame.innerGlow:SetVertexColor(0.3, 0.3, 0.3)
        ArrowFrame.outerGlow:SetVertexColor(0.3, 0.3, 0.3)
        ArrowFrame.innerGlow:SetAlpha(0.1)
        ArrowFrame.trail:SetAlpha(0)
        ArrowFrame.distance:SetText("--")
        ArrowFrame.objective:SetText("|cFF888888" .. L["NO_ACTIVE_OBJECTIVE"] .. "|r")
        ArrowFrame.eta:SetText("")
        ArrowFrame.arrow:Show()
        ArrowFrame.shadow:Show()
        ArrowFrame.outerGlow:Show()
        ArrowFrame.innerGlow:Show()
        ArrowFrame.checkmark:Hide()
        ArrowFrame.checkBg:Hide()
        return
    end

    -- Get player position in world coordinates (validated)
    local x, y, instance = GetValidPlayerPosition()
    if not x or not y then
        ArrowFrame.distance:SetText("|cFFFF0000?|r")
        return
    end

    -- Reset ETA tracking on zone/instance change
    if lastZone and lastZone ~= instance then
        QM:ResetETATracking()
    end
    lastZone = instance

    -- Get/cache target world coordinates (validated)
    if not ArrowFrame.targetWX or ArrowFrame.waypointChanged then
        ArrowFrame.targetWX, ArrowFrame.targetWY, ArrowFrame.targetInstance =
            GetValidWorldCoordinates(waypoint.x, waypoint.y, waypoint.mapId)
        ArrowFrame.waypointChanged = false
    end

    local targetWX = ArrowFrame.targetWX
    local targetWY = ArrowFrame.targetWY
    local targetInstance = ArrowFrame.targetInstance

    if not targetWX or not targetWY then
        ArrowFrame.distance:SetText("|cFFFF0000?|r")
        return
    end

    -- Check if waypoint is reachable from current zone
    if not IsWaypointReachable(targetInstance, instance) then
        if not self._unknownText then self._unknownText = "|cFFFFFF00" .. L["UNKNOWN"] .. "|r" end
        ArrowFrame.distance:SetText(self._unknownText)
        return
    end

    -- Calculate direction and distance
    local angle, dist = HBD:GetWorldVector(instance, x, y, targetWX, targetWY)
    local facing = GetPlayerFacing()

    if not (angle and dist and facing) then
        ArrowFrame.distance:SetText("|cFFFF0000?|r")
        return
    end

    -- Calculate ETA based on movement
    if QM.db.profile.arrow.showETA then
        self:UpdateETA(x, y, dist, elapsed)
    else
        ArrowFrame.eta:SetText("")
    end

    -- Check if arrived (uses setting with fallback)
    local arrivalDist = QM.db and QM.db.profile.arrow.arrivalDist or 10
    if dist < arrivalDist then
        ArrowFrame.arrow:Hide()
        ArrowFrame.shadow:Hide()
        ArrowFrame.trail:Hide()
        ArrowFrame.innerGlow:Hide()
        ArrowFrame.outerGlow:SetVertexColor(0, 1, 0.3)
        ArrowFrame.outerGlow:SetAlpha(0.4)
        ArrowFrame.checkmark:Show()
        ArrowFrame.checkBg:Show()
        if QM.db.profile.arrow.showDistance ~= false then
            if not self._arrivedText then self._arrivedText = "|cFF00FF00" .. L["ARRIVED"] .. "|r" end
            ArrowFrame.distance:SetText(self._arrivedText)
            ArrowFrame.distance:Show()
        else
            ArrowFrame.distance:Hide()
        end
        ArrowFrame.eta:SetText("")

        -- Trigger next waypoint search
        lastAutoUpdate = AUTO_WAYPOINT_INTERVAL
        return
    end

    -- Show arrow elements
    ArrowFrame.arrow:Show()
    ArrowFrame.shadow:Show()
    ArrowFrame.trail:Show()
    ArrowFrame.innerGlow:Show()
    ArrowFrame.outerGlow:Show()
    ArrowFrame.checkmark:Hide()
    ArrowFrame.checkBg:Hide()

    -- Calculate orientation
    local orientation = angle - facing

    -- Smooth rotation (reduce jitter)
    local diff = math.abs(orientation - lastOrientation)
    if diff > lowerbound and diff < upperbound then
        lastOrientation = orientation
        ArrowFrame.arrow:SetRotation(orientation)
        ArrowFrame.shadow:SetRotation(orientation)
        ArrowFrame.trail:SetRotation(orientation + math.pi)  -- Trail points backwards
    end

    -- Distance display (check if enabled)
    if QM.db.profile.arrow.showDistance ~= false then
        dist = math.floor(dist)
        -- Only update text if distance actually changed (avoids string alloc)
        if dist ~= lastDistValue then
            lastDistValue = dist
            if dist >= 1000 then
                lastDistText = string.format(fmtDistKm, dist / 1000)
            else
                lastDistText = string.format(fmtDistYd, dist)
            end
            ArrowFrame.distance:SetText(lastDistText)
        end
        ArrowFrame.distance:Show()
    else
        ArrowFrame.distance:Hide()
    end

    -- Color based on alignment (smooth HD gradient)
    local absAngle = math.abs(orientation)
    while absAngle > math.pi do absAngle = absAngle - 2 * math.pi end
    absAngle = math.abs(absAngle)

    local r, g, b
    local glowIntensity
    if absAngle < 0.15 then
        -- Perfect alignment - bright green
        r, g, b = 0, 1, 0.4
        glowIntensity = 0.6
    elseif absAngle < 0.4 then
        -- Good - green-yellow
        r, g, b = 0.3, 1, 0.2
        glowIntensity = 0.5
    elseif absAngle < 0.8 then
        -- OK - yellow
        r, g, b = 1, 0.95, 0
        glowIntensity = 0.4
    elseif absAngle < 1.3 then
        -- Off course - orange
        r, g, b = 1, 0.6, 0
        glowIntensity = 0.3
    elseif absAngle < 2.0 then
        -- Wrong way - red-orange
        r, g, b = 1, 0.3, 0
        glowIntensity = 0.25
    else
        -- Backwards - red
        r, g, b = 1, 0.1, 0
        glowIntensity = 0.2
    end

    ArrowFrame.arrow:SetVertexColor(r, g, b)
    ArrowFrame.shadow:SetVertexColor(0, 0, 0, 0.5)
    ArrowFrame.innerGlow:SetVertexColor(r, g, b)
    ArrowFrame.innerGlow:SetAlpha(glowIntensity)
    ArrowFrame.outerGlow:SetVertexColor(r * 0.8, g * 0.8, b * 0.8)
    ArrowFrame.trail:SetVertexColor(r, g, b)
    ArrowFrame.trail:SetAlpha(0.15 + glowIntensity * 0.15)

    -- Update objective text - use LIVE objective text instead of cached waypoint.description
    if QM.db.profile.arrow.showObjective ~= false then
        local text = waypoint.description or L["QUEST_OBJECTIVE"]

        -- Fetch live objective text from activeQuests to ensure progress is current
        local quest = self.activeQuests and self.activeQuests[waypoint.questId]
        if quest and quest.objectives and waypoint.objectiveIndex and quest.objectives[waypoint.objectiveIndex] then
            local obj = quest.objectives[waypoint.objectiveIndex]
            if obj.text then
                text = obj.text
            end
        end

        if #text > 50 then text = text:sub(1, 47) .. "..." end
        ArrowFrame.objective:SetText(text)
        ArrowFrame.objective:Show()
    else
        ArrowFrame.objective:Hide()
    end
end

-- ============================================================================
-- ETA Calculation
-- ============================================================================

-- Track time for accurate speed calculation
local etaUpdateTimer = 0
local ETA_UPDATE_INTERVAL = 0.5  -- Update ETA every 0.5 seconds

function QM:UpdateETA(x, y, dist, elapsed)
    -- Initialize tracking data
    if not ArrowFrame.etaData then
        ArrowFrame.etaData = {
            lastX = x,
            lastY = y,
            lastTime = GetTime(),
            speeds = {},
            speedIndex = 1,
            lastETA = nil,
        }
        ArrowFrame.eta:SetText("")
        return
    end

    local data = ArrowFrame.etaData
    local currentTime = GetTime()
    local timeDelta = currentTime - data.lastTime

    -- Only update speed calculation every 0.5 seconds for accuracy
    if timeDelta < ETA_UPDATE_INTERVAL then
        -- Show cached ETA if available
        if data.lastETA then
            ArrowFrame.eta:SetText(data.lastETA)
        end
        return
    end

    -- Calculate distance moved
    local dx = x - data.lastX
    local dy = y - data.lastY
    local moved = math.sqrt(dx * dx + dy * dy)

    -- Calculate speed (yards per second)
    local speed = 0
    if timeDelta > 0 then
        speed = moved / timeDelta
    end

    -- Update tracking data
    data.lastX = x
    data.lastY = y
    data.lastTime = currentTime

    -- Only store valid speeds (player is moving)
    if speed > 1 and speed < 500 then  -- Reasonable speed range (1-500 yd/s)
        data.speeds[data.speedIndex] = speed
        data.speedIndex = (data.speedIndex % 8) + 1  -- Keep last 8 samples
    end

    -- Calculate average speed from samples (use ipairs-style loop, max 8 entries)
    local totalSpeed = 0
    local count = 0
    for idx = 1, 8 do
        local s = data.speeds[idx]
        if s and s > 1 then
            totalSpeed = totalSpeed + s
            count = count + 1
        end
    end

    -- Display ETA (pre-computed format strings avoid concatenation)
    local etaText = ""
    if count > 0 and dist > 0 then
        local avgSpeed = totalSpeed / count
        local eta = dist / avgSpeed

        -- Sanity check
        if eta > 0 and eta < 36000 then  -- Max 10 hours
            if not fmtEtaSec then
                fmtEtaSec = "|cFF888888" .. L["ETA_SECONDS"] .. "|r"
                fmtEtaMin = "|cFF888888" .. L["ETA_MINUTES"] .. "|r"
                fmtEtaHr = "|cFF888888" .. L["ETA_HOURS"] .. "|r"
            end
            if eta < 60 then
                etaText = string.format(fmtEtaSec, math.floor(eta))
            elseif eta < 3600 then
                local mins = math.floor(eta / 60)
                local secs = math.floor(eta % 60)
                etaText = string.format(fmtEtaMin, mins, secs)
            else
                local hours = math.floor(eta / 3600)
                local mins = math.floor((eta % 3600) / 60)
                etaText = string.format(fmtEtaHr, hours, mins)
            end
        else
            etaText = ""
        end
    elseif count == 0 then
        -- No speed data yet - player might be standing still
        if not self._moveToCalcText then
            self._moveToCalcText = "|cFF666666" .. L["MOVE_TO_CALCULATE"] .. "|r"
        end
        etaText = self._moveToCalcText
    end

    data.lastETA = etaText
    ArrowFrame.eta:SetText(etaText)
end

-- Reset ETA tracking when waypoint changes
function QM:ResetETATracking()
    if ArrowFrame then
        ArrowFrame.etaData = nil
    end
end

-- ============================================================================
-- Context Menu
-- ============================================================================

function QM:ShowArrowContextMenu()
    -- Create a simple context menu (compatible with Classic)
    if not ArrowFrame.contextMenu then
        local menu = CreateFrame("Frame", "QuestMasterArrowContextMenu", ArrowFrame, "BackdropTemplate")
        menu:SetSize(160, 145)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.35, 0.3, 1)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)

        -- Title
        local title = menu:CreateFontString(nil, "OVERLAY")
        title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        title:SetPoint("TOP", 0, -8)
        title:SetText("|cFFFFD700QuestMaster|r")

        -- Buttons
        local buttonData = {
            {text = L["HIDE_ARROW"], func = function()
                QM.db.profile.arrow.enabled = false
                QM:UpdateArrowVisibility()
            end},
            {text = L["CLEAR_WAYPOINT"], func = function()
                QM:ClearWaypoint()
            end},
            {text = L["FIND_NEAREST_AUTO"], func = function()
                -- Clear manual flag so auto-select can work again
                QM.manualWaypoint = false
                QM:AutoSelectBestWaypoint(true)
            end},
            {text = L["OPEN_SETTINGS"], func = function()
                QM:ToggleSettings()
            end},
            {text = L["CLOSE"], func = function() end},
        }

        local yOffset = -28
        for i, data in ipairs(buttonData) do
            local btn = CreateFrame("Button", nil, menu)
            btn:SetSize(150, 20)
            btn:SetPoint("TOP", 0, yOffset)

            btn.text = btn:CreateFontString(nil, "OVERLAY")
            btn.text:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            btn.text:SetPoint("LEFT", 8, 0)
            btn.text:SetText(data.text)
            btn.text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 0.85, 0)
            end)
            btn:SetScript("OnLeave", function(self)
                self.text:SetTextColor(0.9, 0.9, 0.9)
            end)
            btn:SetScript("OnClick", function()
                data.func()
                menu:Hide()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)

            yOffset = yOffset - 22
        end

        menu:SetScript("OnShow", function(self)
            -- Close when clicking elsewhere
            self:SetScript("OnUpdate", function(self)
                if not MouseIsOver(self) and IsMouseButtonDown("LeftButton") then
                    self:Hide()
                end
            end)
        end)

        menu:Hide()
        ArrowFrame.contextMenu = menu
    end

    -- Position and show
    local menu = ArrowFrame.contextMenu
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
    menu:Show()
end

-- ============================================================================
-- Auto Waypoint Selection
-- ============================================================================

function QM:AutoSelectBestWaypoint(force)
    if not self.activeQuests then return end

    -- IMPORTANT: If auto-waypoint is disabled in settings and not forced, do nothing
    if not QM.db.profile.auto.waypoint and not force then return end

    -- CRITICAL: ALWAYS respect manually set waypoints
    -- Only clear manual waypoint if the quest no longer exists (abandoned/completed)
    -- Capture currentWaypoint in local to avoid race condition
    local currentWP = self.currentWaypoint
    if self.manualWaypoint and currentWP then
        local questId = currentWP.questId
        -- If questId is 0, nil, or has isManual flag, it's a pure coordinate waypoint - ALWAYS keep it
        if not questId or questId == 0 or currentWP.isManual then
            return
        end
        local quest = self.activeQuests[questId]
        if quest then
            -- Quest still exists - KEEP the manual waypoint, don't override!
            return
        else
            -- Quest was abandoned or no longer active, clear manual flag
            self.manualWaypoint = false
            self.currentWaypoint = nil
        end
    end

    -- If we already have a waypoint and it's not manual, check if still valid
    -- Re-capture currentWaypoint for this block (may have changed)
    currentWP = self.currentWaypoint
    if not force and currentWP and not self.manualWaypoint then
        local quest = self.activeQuests[currentWP.questId]
        if quest then
            -- If quest is now complete, switch to turn-in (don't keep objective waypoint)
            if quest.isComplete then
                if currentWP.objectiveIndex == 0 then
                    return -- Already pointing to turn-in, keep it
                end
                -- Quest complete but pointing to objective - need to switch to turn-in
                -- Fall through to find turn-in waypoint
            else
                -- Quest not complete - check if objective waypoint still valid
                if currentWP.objectiveIndex > 0 then
                    local obj = quest.objectives and quest.objectives[currentWP.objectiveIndex]
                    if obj and not obj.finished then
                        return -- Objective not finished yet
                    end
                end
            end
        end
    end

    -- Reusable waypoint tables to avoid GC pressure
    local bestWP = self._bestWP or {}
    local bestTurnInWP = self._bestTurnInWP or {}
    self._bestWP = bestWP
    self._bestTurnInWP = bestTurnInWP

    local bestDistance = math.huge
    local foundBest = false
    local foundTurnIn = false
    local bestTurnInDist = math.huge

    -- Single loop: check both turn-ins and incomplete objectives
    local prioritizeTurnIn = QM.db.profile.auto.prioritizeTurnIn

    for questId, quest in pairs(self.activeQuests) do
        -- Inline: check if all objectives are finished
        local isFinished = quest.isComplete
        if not isFinished and quest.objectives and #quest.objectives > 0 then
            isFinished = true
            for _, obj in ipairs(quest.objectives) do
                if not obj.finished then isFinished = false break end
            end
        end

        if isFinished then
            -- Quest complete - check for turn-in location
            if QM.DB then
                local locs = QM.DB:GetQuestTurnInLocations(questId)
                if locs and locs[1] then
                    local dist = self:GetDistanceToPoint(locs[1].x, locs[1].y, locs[1].mapId)
                    if dist then
                        -- Track best turn-in separately for prioritization
                        if dist < bestTurnInDist then
                            bestTurnInDist = dist
                            foundTurnIn = true
                            bestTurnInWP.questId = questId
                            bestTurnInWP.objectiveIndex = 0
                            bestTurnInWP.x = locs[1].x
                            bestTurnInWP.y = locs[1].y
                            bestTurnInWP.mapId = locs[1].mapId
                            bestTurnInWP.description = "|cFF00FF00" .. L["TURN_IN"] .. ":|r " .. quest.title
                        end
                        -- Also track overall best
                        if dist < bestDistance then
                            bestDistance = dist
                            foundBest = true
                            bestWP.questId = questId
                            bestWP.objectiveIndex = 0
                            bestWP.x = locs[1].x
                            bestWP.y = locs[1].y
                            bestWP.mapId = locs[1].mapId
                            bestWP.description = "|cFF00FF00" .. L["TURN_IN"] .. ":|r " .. quest.title
                        end
                    end
                end
            end
        else
            -- Quest incomplete - check objectives
            local locs = self:GetQuestObjectiveLocationsFixed(questId)
            if locs then
                for i, obj in ipairs(quest.objectives) do
                    if not obj.finished and locs[i] and #locs[i] > 0 then
                        for _, loc in ipairs(locs[i]) do
                            local dist = self:GetDistanceToPoint(loc.x, loc.y, loc.mapId)
                            if dist and dist < bestDistance then
                                bestDistance = dist
                                foundBest = true
                                bestWP.questId = questId
                                bestWP.objectiveIndex = i
                                bestWP.x = loc.x
                                bestWP.y = loc.y
                                bestWP.mapId = loc.mapId
                                bestWP.description = obj.text or quest.title
                            end
                        end
                    end
                end
            end
        end
    end

    -- If prioritizing turn-ins and we found one, use it
    if prioritizeTurnIn and foundTurnIn then
        self:SetNewWaypoint(bestTurnInWP)
        return
    end

    if foundBest then
        self:SetNewWaypoint(bestWP)
    else
        self.currentWaypoint = nil
        if ArrowFrame then
            ArrowFrame.waypointChanged = true
        end
    end
end

function QM:SetNewWaypoint(waypoint)
    -- Check if waypoint actually changed
    if not self.currentWaypoint or
       self.currentWaypoint.x ~= waypoint.x or
       self.currentWaypoint.y ~= waypoint.y or
       self.currentWaypoint.mapId ~= waypoint.mapId then
        ArrowFrame.waypointChanged = true
        lastDistValue = -1  -- Reset distance text cache for new waypoint
        -- Reset ETA tracking for new waypoint
        self:ResetETATracking()
    end
    self.currentWaypoint = waypoint
end

-- ============================================================================
-- Visibility Controls
-- ============================================================================

function QM:UpdateArrowVisibility()
    if not ArrowFrame then return end
    if QM.db.profile.arrow.enabled and QM.db.profile.enabled then
        ArrowFrame:Show()
    else
        ArrowFrame:Hide()
    end
end

function QM:UpdateArrowSettings()
    if not ArrowFrame then return end

    local scale = QM.db.profile.arrow.scale or 1.0
    ArrowFrame:SetScale(scale)

    local alpha = QM.db.profile.arrow.alpha or 1.0
    ArrowFrame:SetAlpha(alpha)

    -- Apply color
    self:SetArrowColor(QM.db.profile.arrow.color or "gold")

    -- Apply position
    ArrowFrame:ClearAllPoints()
    ArrowFrame:SetPoint(
        QM.db.profile.arrow.point or "TOP",
        UIParent,
        QM.db.profile.arrow.point or "TOP",
        QM.db.profile.arrow.x or 0,
        QM.db.profile.arrow.y or -100
    )
end

function QM:SetArrowColor(colorName)
    if not ArrowFrame or not ArrowFrame.arrow then return end

    local color
    if colorName == "class" then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            color = {classColor.r, classColor.g, classColor.b}
        else
            color = ARROW_COLORS.gold
        end
    else
        color = ARROW_COLORS[colorName] or ARROW_COLORS.gold
    end

    -- Apply to arrow textures
    ArrowFrame.arrow:SetVertexColor(color[1], color[2], color[3])

    -- Apply to glows with reduced intensity
    if ArrowFrame.outerGlow then
        ArrowFrame.outerGlow:SetVertexColor(color[1], color[2], color[3])
    end
    if ArrowFrame.innerGlow then
        ArrowFrame.innerGlow:SetVertexColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7)
    end
    if ArrowFrame.trail then
        ArrowFrame.trail:SetVertexColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
    end
    if ArrowFrame.shadow then
        ArrowFrame.shadow:SetVertexColor(0, 0, 0, 0.5)
    end
end

function QM:UpdateArrow()
    self:UpdateArrowVisibility()
    self:DrawArrow(0)
    if ArrowFrame then
        ArrowFrame.waypointChanged = true
    end
end

function QM:UpdateArrowTarget()
    self:AutoSelectBestWaypoint(true)
end

function QM:SelectBestWaypoint()
    self:AutoSelectBestWaypoint(true)
end

-- Keep compatibility
function QM:UpdateArrowRotation()
    self:DrawArrow(0)
end
