--[[
    QuestMaster Quest Tracker - Actions Module
    Quest actions: abandon, share, quest log helpers

    Note: Waypoint functions (SetWaypointForQuest, SetWaypointForObjective)
    are defined in QuestTracker.lua to avoid duplication
]]

local addonName, QM = ...
local Tracker = QM.Tracker

-- ============================================================================
-- Quest Log Functions
-- ============================================================================

-- Find quest log index by quest ID
-- Expands collapsed headers temporarily to find quests hidden under them
function QM:FindQuestLogIndex(questId)
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, isHeader, _, _, _, qId = GetQuestLogTitle(i)
        if not isHeader and qId == questId then
            return i
        end
    end

    -- Quest not found - it may be under a collapsed header
    if ExpandQuestHeader then
        local collapsedHeaders = {}
        for i = 1, numEntries do
            local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
            if isHeader and isCollapsed then
                collapsedHeaders[title] = true
            end
        end
        if next(collapsedHeaders) then
            ExpandQuestHeader(0)
            numEntries = GetNumQuestLogEntries()
            local foundIndex = nil
            for i = 1, numEntries do
                local _, _, _, isHeader, _, _, _, qId = GetQuestLogTitle(i)
                if not isHeader and qId == questId then
                    foundIndex = i
                    break
                end
            end
            -- Restore collapsed headers
            if CollapseQuestHeader then
                numEntries = GetNumQuestLogEntries()
                for i = numEntries, 1, -1 do
                    local title, _, _, isHeader = GetQuestLogTitle(i)
                    if isHeader and collapsedHeaders[title] then
                        CollapseQuestHeader(i)
                    end
                end
            end
            return foundIndex
        end
    end

    return nil
end

-- ============================================================================
-- Abandon Quest
-- ============================================================================

function QM:AbandonQuest(questId)
    local logIndex = self:FindQuestLogIndex(questId)
    if not logIndex then
        print("|cFFFF0000QuestMaster:|r Quest not found in quest log")
        return
    end

    SelectQuestLogEntry(logIndex)
    SetAbandonQuest()
    AbandonQuest()
end

-- ============================================================================
-- Share Quest
-- ============================================================================

function QM:ShareQuest(questId)
    local logIndex = self:FindQuestLogIndex(questId)
    if not logIndex then
        print("|cFFFF0000QuestMaster:|r Quest not found in quest log")
        return
    end

    if GetNumGroupMembers() == 0 then
        print("|cFFFFFF00QuestMaster:|r You must be in a party to share quests")
        return
    end

    SelectQuestLogEntry(logIndex)
    QuestLogPushQuest()
end

-- ============================================================================
-- Link Quest to Chat
-- ============================================================================

function QM:LinkQuestToChat(questId)
    local logIndex = self:FindQuestLogIndex(questId)
    if not logIndex then
        print("|cFFFF0000QuestMaster:|r Quest not found in quest log")
        return
    end

    -- Get quest info
    local questTitle, questLevel = GetQuestLogTitle(logIndex)
    if not questTitle then
        print("|cFFFF0000QuestMaster:|r Could not get quest info")
        return
    end

    -- Create quest link (TBC Classic format)
    -- Format: |cff808080|Hquest:questId:questLevel|h[Quest Name]|h|r
    local questLink = string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", questId, questLevel or 1, questTitle)

    -- Insert into chat edit box
    if ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
        ChatFrame1EditBox:Insert(questLink)
    elseif ChatEdit_GetActiveWindow() then
        ChatEdit_InsertLink(questLink)
    else
        -- Open chat with the link
        ChatFrame_OpenChat(questLink)
    end
end
