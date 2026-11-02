--[[
    QuestMaster Objective Frame Module
    Displays a floating frame showing current objective with progress
    Updates in real-time when objectives change
]]

local addonName, QM = ...
local L = QM.L

-- Objective frame reference
local ObjectiveFrame = nil

-- Animation variables
local fadeIn = true
local pulseTimer = 0
local PULSE_SPEED = 2

-- ============================================================================
-- Objective Frame Creation
-- ============================================================================

function QM:InitializeObjectiveFrame()
    -- Create floating objective display frame
    ObjectiveFrame = CreateFrame("Frame", "QuestMasterObjectiveFrame", UIParent, "BackdropTemplate")
    ObjectiveFrame:SetSize(300, 60)
    ObjectiveFrame:SetPoint("TOP", QM.ArrowFrame or UIParent, "BOTTOM", 0, -10)
    ObjectiveFrame:SetFrameStrata("HIGH")
    ObjectiveFrame:SetClampedToScreen(true)
    ObjectiveFrame:EnableMouse(true)
    ObjectiveFrame:SetMovable(true)
    ObjectiveFrame:RegisterForDrag("LeftButton")

    -- Background
    ObjectiveFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    ObjectiveFrame:SetBackdropColor(0, 0, 0, 0.85)
    ObjectiveFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Icon
    ObjectiveFrame.icon = ObjectiveFrame:CreateTexture(nil, "ARTWORK")
    ObjectiveFrame.icon:SetSize(32, 32)
    ObjectiveFrame.icon:SetPoint("LEFT", ObjectiveFrame, "LEFT", 10, 0)
    ObjectiveFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- Quest title
    ObjectiveFrame.title = ObjectiveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ObjectiveFrame.title:SetPoint("TOPLEFT", ObjectiveFrame.icon, "TOPRIGHT", 8, 0)
    ObjectiveFrame.title:SetPoint("TOPRIGHT", ObjectiveFrame, "TOPRIGHT", -10, -8)
    ObjectiveFrame.title:SetJustifyH("LEFT")
    ObjectiveFrame.title:SetTextColor(1, 0.82, 0, 1)
    ObjectiveFrame.title:SetWordWrap(false)

    -- Objective text
    ObjectiveFrame.objective = ObjectiveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ObjectiveFrame.objective:SetPoint("TOPLEFT", ObjectiveFrame.title, "BOTTOMLEFT", 0, -4)
    ObjectiveFrame.objective:SetPoint("RIGHT", ObjectiveFrame, "RIGHT", -10, 0)
    ObjectiveFrame.objective:SetJustifyH("LEFT")
    ObjectiveFrame.objective:SetTextColor(1, 1, 1, 1)
    ObjectiveFrame.objective:SetWordWrap(true)

    -- Progress text (larger, centered)
    ObjectiveFrame.progress = ObjectiveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ObjectiveFrame.progress:SetPoint("RIGHT", ObjectiveFrame, "RIGHT", -15, 0)
    ObjectiveFrame.progress:SetTextColor(0.5, 1, 0.5, 1)

    -- Progress bar
    ObjectiveFrame.progressBar = CreateFrame("StatusBar", nil, ObjectiveFrame)
    ObjectiveFrame.progressBar:SetSize(ObjectiveFrame:GetWidth() - 60, 6)
    ObjectiveFrame.progressBar:SetPoint("BOTTOMLEFT", ObjectiveFrame, "BOTTOMLEFT", 50, 8)
    ObjectiveFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    ObjectiveFrame.progressBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    ObjectiveFrame.progressBar:SetMinMaxValues(0, 1)

    ObjectiveFrame.progressBar.bg = ObjectiveFrame.progressBar:CreateTexture(nil, "BACKGROUND")
    ObjectiveFrame.progressBar.bg:SetAllPoints()
    ObjectiveFrame.progressBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    ObjectiveFrame.progressBar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

    -- Drag handlers
    ObjectiveFrame:SetScript("OnDragStart", function(self)
        if not QM.db.profile.lockFrames then
            self:StartMoving()
        end
    end)

    ObjectiveFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Update script for animations
    ObjectiveFrame:SetScript("OnUpdate", function(self, elapsed)
        QM:UpdateObjectiveAnimation(elapsed)
    end)

    -- Store reference
    QM.ObjectiveFrame = ObjectiveFrame
    ObjectiveFrame:Hide()
end

-- ============================================================================
-- Objective Frame Updates
-- ============================================================================

function QM:UpdateObjectiveDisplay()
    if not ObjectiveFrame then return end

    local waypoint = self.currentWaypoint
    if not waypoint then
        ObjectiveFrame:Hide()
        return
    end

    -- Get quest data
    local quest = self.activeQuests[waypoint.questId]
    if not quest then
        ObjectiveFrame:Hide()
        return
    end

    -- Update title
    ObjectiveFrame.title:SetText(quest.title)

    -- Update objective
    local objective = quest.objectives[waypoint.objectiveIndex]
    if objective then
        ObjectiveFrame.objective:SetText(objective.text or waypoint.description)

        -- Update progress
        if objective.current and objective.required then
            local progressText = string.format("%d/%d", objective.current, objective.required)
            ObjectiveFrame.progress:SetText(progressText)

            -- Update progress bar
            ObjectiveFrame.progressBar:SetMinMaxValues(0, objective.required)
            ObjectiveFrame.progressBar:SetValue(objective.current)
            ObjectiveFrame.progressBar:Show()

            -- Color based on completion
            local percent = objective.current / objective.required
            if percent >= 1 then
                ObjectiveFrame.progress:SetTextColor(0, 1, 0, 1)
                ObjectiveFrame.progressBar:SetStatusBarColor(0, 1, 0, 1)
            elseif percent >= 0.5 then
                ObjectiveFrame.progress:SetTextColor(1, 1, 0, 1)
                ObjectiveFrame.progressBar:SetStatusBarColor(1, 1, 0, 1)
            else
                ObjectiveFrame.progress:SetTextColor(1, 0.5, 0, 1)
                ObjectiveFrame.progressBar:SetStatusBarColor(1, 0.5, 0, 1)
            end
        else
            ObjectiveFrame.progress:SetText("")
            ObjectiveFrame.progressBar:Hide()
        end

        -- Update icon
        local iconTexture = self:GetObjectiveIcon(objective.type)
        ObjectiveFrame.icon:SetTexture(iconTexture)
    else
        ObjectiveFrame.objective:SetText(waypoint.description or "")
        ObjectiveFrame.progress:SetText("")
        ObjectiveFrame.progressBar:Hide()
    end

    ObjectiveFrame:Show()
end

function QM:UpdateObjectiveAnimation(elapsed)
    if not ObjectiveFrame or not ObjectiveFrame:IsShown() then return end

    -- Pulse animation for progress text
    pulseTimer = pulseTimer + elapsed * PULSE_SPEED

    if pulseTimer >= math.pi * 2 then
        pulseTimer = pulseTimer - math.pi * 2
    end

    -- Apply subtle pulse to progress text
    local alpha = 0.7 + 0.3 * math.sin(pulseTimer)
    -- ObjectiveFrame.progress:SetAlpha(alpha)
end

function QM:HideObjectiveDisplay()
    if ObjectiveFrame then
        ObjectiveFrame:Hide()
    end
end

-- ============================================================================
-- Progress Flash Effect
-- ============================================================================

local flashFrame = nil

function QM:FlashObjectiveProgress(questId, objectiveIndex, newValue)
    -- Show a flash effect when objective progress changes
    if not ObjectiveFrame or not ObjectiveFrame:IsShown() then return end

    local waypoint = self.currentWaypoint
    if not waypoint or waypoint.questId ~= questId then return end

    -- Create flash frame if needed
    if not flashFrame then
        flashFrame = CreateFrame("Frame", nil, ObjectiveFrame)
        flashFrame:SetAllPoints()
        flashFrame.texture = flashFrame:CreateTexture(nil, "OVERLAY")
        flashFrame.texture:SetAllPoints()
        flashFrame.texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        flashFrame.texture:SetVertexColor(0, 1, 0, 0.3)
        flashFrame:Hide()
    end

    -- Play flash animation
    flashFrame.alpha = 0.5
    flashFrame:Show()

    -- Fade out animation
    flashFrame:SetScript("OnUpdate", function(self, elapsed)
        self.alpha = self.alpha - elapsed * 2
        if self.alpha <= 0 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
        else
            self.texture:SetVertexColor(0, 1, 0, self.alpha)
        end
    end)
end
