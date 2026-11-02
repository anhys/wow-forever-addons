--[[
    QuestMaster Minimap Button Module
    Provides a minimap button for quick access to settings
]]

local addonName, QM = ...
local L = QM.L

local LDB = QM.LDB
local LDBIcon = QM.LDBIcon

-- Data broker object
local QuestMasterLDB = nil

-- ============================================================================
-- Minimap Button Initialization
-- ============================================================================

function QM:InitializeMinimapButton()
    -- Create LDB data object
    QuestMasterLDB = LDB:NewDataObject("QuestMaster", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        OnClick = function(self, button)
            if button == "LeftButton" then
                -- Toggle options
                if IsShiftKeyDown() then
                    -- Toggle tracker
                    QM.db.profile.tracker.enabled = not QM.db.profile.tracker.enabled
                    QM:UpdateTrackerVisibility()
                else
                    -- Open custom settings panel
                    QM:ToggleSettings()
                end
            elseif button == "RightButton" then
                -- Toggle arrow
                QM.db.profile.arrow.enabled = not QM.db.profile.arrow.enabled
                QM:UpdateArrowVisibility()
            elseif button == "MiddleButton" then
                -- Clear current waypoint
                QM:ClearWaypoint()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFFFFD700QuestMaster|r v" .. QM.version)
            tooltip:AddLine(" ")

            -- Quest Statistics
            local questCount = 0
            local completedCount = 0
            local zoneQuestCount = 0
            local currentZone = GetZoneText() or ""

            for _, quest in pairs(QM.activeQuests or {}) do
                questCount = questCount + 1
                if quest.isComplete then
                    completedCount = completedCount + 1
                end
                -- Check if quest is in current zone
                if quest.zone and quest.zone == currentZone then
                    zoneQuestCount = zoneQuestCount + 1
                end
            end

            -- Quest info section
            tooltip:AddDoubleLine(L["MINIMAP_ACTIVE_QUESTS"] or "Active Quests:", "|cFFFFFFFF" .. questCount .. "|r", 0.95, 0.78, 0.25, 1, 1, 1)
            if completedCount > 0 then
                tooltip:AddDoubleLine(L["MINIMAP_COMPLETED"] or "Completed:", "|cFF00FF00" .. completedCount .. "|r", 0.65, 0.65, 0.65, 1, 1, 1)
            end
            if currentZone ~= "" then
                tooltip:AddDoubleLine(L["MINIMAP_IN_ZONE"] or "In Zone:", "|cFFAAAAAA" .. zoneQuestCount .. "|r", 0.65, 0.65, 0.65, 1, 1, 1)
            end

            tooltip:AddLine(" ")

            -- Current waypoint info
            if QM.currentWaypoint then
                tooltip:AddLine("|cFFFFD700" .. (L["MINIMAP_CURRENT_WAYPOINT"] or "Current Waypoint:") .. "|r")
                local desc = QM.currentWaypoint.description or L["UNKNOWN"] or "Unknown"
                if #desc > 35 then
                    desc = desc:sub(1, 32) .. "..."
                end
                tooltip:AddLine("  " .. desc, 0.8, 0.8, 0.8)
                if QM.currentWaypoint.distance then
                    local dist = QM.currentWaypoint.distance
                    local distText = dist < 1000 and string.format("%.0f yd", dist) or string.format("%.1f km", dist/1000)
                    tooltip:AddLine("  " .. distText, 0.5, 0.8, 0.5)
                end
            else
                tooltip:AddLine("|cFF666666" .. (L["MINIMAP_NO_WAYPOINT"] or "No active waypoint") .. "|r")
            end

            tooltip:AddLine(" ")

            -- Controls
            tooltip:AddLine("|cFFAAAAAA" .. (L["MINIMAP_LEFT_CLICK"] or "Left-Click: Open Settings") .. "|r")
            tooltip:AddLine("|cFFAAAAAA" .. (L["MINIMAP_SHIFT_CLICK"] or "Shift+Left-Click: Toggle Tracker") .. "|r")
            tooltip:AddLine("|cFFAAAAAA" .. (L["MINIMAP_RIGHT_CLICK"] or "Right-Click: Toggle Arrow") .. "|r")
            tooltip:AddLine("|cFFAAAAAA" .. (L["MINIMAP_MIDDLE_CLICK"] or "Middle-Click: Clear Waypoint") .. "|r")
        end,
    })

    -- Register with LibDBIcon
    LDBIcon:Register("QuestMaster", QuestMasterLDB, QM.db.profile.minimapButton)
end

-- ============================================================================
-- Minimap Button Updates
-- ============================================================================

function QM:UpdateMinimapButton()
    if QM.db.profile.minimapButton.hide then
        LDBIcon:Hide("QuestMaster")
    else
        LDBIcon:Show("QuestMaster")
    end
end

function QM:ShowMinimapButton()
    QM.db.profile.minimapButton.hide = false
    LDBIcon:Show("QuestMaster")
end

function QM:HideMinimapButton()
    QM.db.profile.minimapButton.hide = true
    LDBIcon:Hide("QuestMaster")
end

function QM:ToggleMinimapButton()
    QM.db.profile.minimapButton.hide = not QM.db.profile.minimapButton.hide
    self:UpdateMinimapButton()
end
