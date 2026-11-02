--[[
    QuestMaster Quest Tracker - Menu Module
    Context menus and sort dropdown
]]

local addonName, QM = ...
local Tracker = QM.Tracker

-- ============================================================================
-- Quest Context Menu
-- ============================================================================

function QM:ShowQuestContextMenu(qf)
    if not qf or not qf.questData then return end

    local quest = qf.questData
    local menu = {
        {
            text = quest.title,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Set Waypoint",
            notCheckable = true,
            func = function()
                QM:SetWaypointForQuest(quest.id)
            end,
        },
        {
            text = "Show on Map",
            notCheckable = true,
            func = function()
                if WorldMapFrame then
                    WorldMapFrame:Show()
                end
            end,
        },
        {
            text = "Open Quest Log",
            notCheckable = true,
            func = function()
                local logIndex = QM:FindQuestLogIndex(quest.id)
                if logIndex then
                    ShowUIPanel(QuestLogFrame)
                    QuestLog_SetSelection(logIndex)
                    QuestLog_Update()
                end
            end,
        },
        {
            text = " ", isTitle = true, notCheckable = true,
        },
        {
            text = "Link Quest",
            notCheckable = true,
            func = function()
                QM:LinkQuestToChat(quest.id)
            end,
        },
        {
            text = "Share Quest",
            notCheckable = true,
            func = function()
                QM:ShareQuest(quest.id)
            end,
            disabled = GetNumGroupMembers() == 0,
        },
        {
            text = "Abandon Quest",
            notCheckable = true,
            func = function()
                StaticPopup_Show("ABANDON_QUEST", quest.title)
                QM.pendingAbandonQuestId = quest.id
            end,
        },
        {
            text = " ", isTitle = true, notCheckable = true,
        },
        {
            text = "Cancel",
            notCheckable = true,
        },
    }

    -- Create popup menu
    local menuFrame = CreateFrame("Frame", "QMQuestContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

-- ============================================================================
-- Sort Dropdown
-- ============================================================================

function QM:ShowSortDropdown(anchor)
    if not QM.sortDropdown then
        local dropdown = CreateFrame("Frame", "QMSortDropdown", UIParent, "BackdropTemplate")
        dropdown:SetSize(120, 70)
        dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdown:SetFrameLevel(100)
        dropdown:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        })
        dropdown:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
        dropdown:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
        dropdown:Hide()

        -- Close on click outside
        dropdown:SetScript("OnShow", function(self)
            self:SetScript("OnUpdate", function(s)
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    if not s:IsMouseOver() then
                        s:Hide()
                    end
                end
            end)
        end)

        local sortOptions = {
            {key = "distance", label = "Distance"},
            {key = "level", label = "Level"},
        }

        local title = dropdown:CreateFontString(nil, "OVERLAY")
        title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        title:SetPoint("TOP", 0, -8)
        title:SetText("|cFFFFD700Sort By|r")

        dropdown.buttons = {}
        for i, opt in ipairs(sortOptions) do
            local btn = CreateFrame("Button", nil, dropdown)
            btn:SetSize(110, 18)
            btn:SetPoint("TOP", 0, -22 - (i-1) * 20)

            btn.check = btn:CreateTexture(nil, "ARTWORK")
            btn.check:SetSize(12, 12)
            btn.check:SetPoint("LEFT", 5, 0)
            btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            btn.check:Hide()

            btn.text = btn:CreateFontString(nil, "OVERLAY")
            btn.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            btn.text:SetPoint("LEFT", 20, 0)
            btn.text:SetText(opt.label)
            btn.text:SetTextColor(0.9, 0.9, 0.9)

            btn.sortKey = opt.key
            btn:SetScript("OnClick", function(self)
                QM.db.profile.tracker.sortBy = self.sortKey
                QM:UpdateTracker()
                dropdown:Hide()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)
            btn:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 0.8, 0)
            end)
            btn:SetScript("OnLeave", function(self)
                local isSelected = QM.db.profile.tracker.sortBy == self.sortKey
                self.text:SetTextColor(isSelected and 0.3 or 0.9, isSelected and 1 or 0.9, isSelected and 0.3 or 0.9)
            end)

            dropdown.buttons[opt.key] = btn
        end

        QM.sortDropdown = dropdown
    end

    -- Update checkmarks
    local currentSort = QM.db.profile.tracker.sortBy or "distance"
    for key, btn in pairs(QM.sortDropdown.buttons) do
        if key == currentSort then
            btn.check:Show()
            btn.text:SetTextColor(0.3, 1, 0.3)
        else
            btn.check:Hide()
            btn.text:SetTextColor(0.9, 0.9, 0.9)
        end
    end

    -- Position below anchor
    QM.sortDropdown:ClearAllPoints()
    QM.sortDropdown:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    QM.sortDropdown:Show()
end
