--[[
    QuestMaster Party Quest Sync Module
    Broadcasts quest progress to party members via addon messages
    Displays party member quest progress in the tracker
]]

local addonName, QM = ...
local L = QM.L

-- Addon message prefix (max 16 chars for TBC)
local MSG_PREFIX = "QuestMasterPS"

-- Message types
local MSG_QUEST_LIST    = "QL"   -- Full quest list broadcast
local MSG_QUEST_UPDATE  = "QU"   -- Single quest progress update
local MSG_QUEST_DONE    = "QD"   -- Quest completed
local MSG_QUEST_NEW     = "QN"   -- New quest accepted

-- Separator for message fields
local SEP = ":"
local FIELD_SEP = "|"
local OBJ_SEP = "~"

-- Party quest data cache
QM.partyQuests = {}

-- Throttle: prevent spamming addon messages
local lastBroadcast = 0
local BROADCAST_COOLDOWN = 2  -- seconds between full broadcasts

-- ============================================================================
-- Initialization
-- ============================================================================

function QM:InitializePartySync()
    -- Register addon message prefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
    end
end

-- ============================================================================
-- Message Encoding/Decoding
-- ============================================================================

-- Encode a single quest into a compact string
-- Format: questId|title|level|isComplete|numObj|obj1Progress~obj1Total~obj1Done|obj2...
local function EncodeQuest(quest)
    if not quest or not quest.id then return nil end

    local parts = {
        quest.id,
        quest.title or "",
        quest.level or 0,
        quest.isComplete and 1 or 0,
        #(quest.objectives or {}),
    }

    for _, obj in ipairs(quest.objectives or {}) do
        local objStr = string.format("%d%s%d%s%d",
            obj.numGot or 0, OBJ_SEP,
            obj.numNeeded or 0, OBJ_SEP,
            obj.finished and 1 or 0)
        table.insert(parts, objStr)
    end

    return table.concat(parts, FIELD_SEP)
end

-- Decode a quest string back into a table
local function DecodeQuest(str)
    if not str or str == "" then return nil end

    local parts = { strsplit(FIELD_SEP, str) }
    if #parts < 5 then return nil end

    local quest = {
        id = tonumber(parts[1]),
        title = parts[2],
        level = tonumber(parts[3]),
        isComplete = parts[4] == "1",
        objectives = {},
    }

    local numObj = tonumber(parts[5]) or 0
    for i = 1, numObj do
        local objStr = parts[5 + i]
        if objStr then
            local got, needed, done = strsplit(OBJ_SEP, objStr)
            table.insert(quest.objectives, {
                numGot = tonumber(got) or 0,
                numNeeded = tonumber(needed) or 0,
                finished = done == "1",
            })
        end
    end

    return quest
end

-- ============================================================================
-- Sending Messages
-- ============================================================================

-- Send a message to the party channel
local function SendPartyMessage(msgType, data)
    if not QM.db or not QM.db.profile.partySync or not QM.db.profile.partySync.enabled then
        return
    end

    if GetNumGroupMembers() == 0 then return end

    local channel = "PARTY"
    if IsInRaid() then
        channel = "RAID"
    end

    local msg = msgType .. SEP .. (data or "")

    -- Truncate if too long (WoW addon messages max ~255 bytes)
    if #msg > 250 then
        local originalLen = #msg
        msg = msg:sub(1, 250)
        if QM.db and QM.db.profile and QM.db.profile.debug then
            print(string.format(L["DEBUG_MESSAGE_TRUNCATED"], originalLen, 250))
        end
    end

    SendAddonMessage(MSG_PREFIX, msg, channel)
end

-- Broadcast full quest list to party
function QM:BroadcastQuestList()
    if not self.db or not self.db.profile.partySync or not self.db.profile.partySync.enabled then
        return
    end

    local now = GetTime()
    if now - lastBroadcast < BROADCAST_COOLDOWN then return end
    lastBroadcast = now

    -- Send each quest as a separate message (to stay within message size limits)
    for questId, quest in pairs(self.activeQuests or {}) do
        local encoded = EncodeQuest(quest)
        if encoded then
            SendPartyMessage(MSG_QUEST_LIST, encoded)
        end
    end
end

-- Send a single quest update
function QM:BroadcastQuestUpdate(questId)
    if not self.db or not self.db.profile.partySync or not self.db.profile.partySync.enabled then
        return
    end

    local quest = self.activeQuests and self.activeQuests[questId]
    if not quest then return end

    local encoded = EncodeQuest(quest)
    if encoded then
        SendPartyMessage(MSG_QUEST_UPDATE, encoded)
    end
end

-- Send quest completion notification
function QM:BroadcastQuestComplete(questId, questTitle)
    if not self.db or not self.db.profile.partySync or not self.db.profile.partySync.enabled then
        return
    end

    SendPartyMessage(MSG_QUEST_DONE, questId .. FIELD_SEP .. (questTitle or ""))
end

-- Send new quest accepted notification
function QM:BroadcastQuestAccepted(questId, questTitle)
    if not self.db or not self.db.profile.partySync or not self.db.profile.partySync.enabled then
        return
    end

    SendPartyMessage(MSG_QUEST_NEW, questId .. FIELD_SEP .. (questTitle or ""))
end

-- ============================================================================
-- Receiving Messages
-- ============================================================================

function QM:OnPartySyncMessage(prefix, message, channel, sender)
    if prefix ~= MSG_PREFIX then return end

    -- Ignore messages from self
    local playerName = UnitName("player")
    -- Strip realm name if present
    local senderName = strsplit("-", sender)
    if senderName == playerName then return end

    if not self.db or not self.db.profile.partySync or not self.db.profile.partySync.enabled then
        return
    end

    -- Parse message type
    local msgType, data = strsplit(SEP, message, 2)
    if not msgType then return end

    -- Initialize party member data if needed
    if not QM.partyQuests[senderName] then
        QM.partyQuests[senderName] = {
            quests = {},
            lastUpdate = GetTime(),
        }
    end

    local memberData = QM.partyQuests[senderName]
    memberData.lastUpdate = GetTime()

    if msgType == MSG_QUEST_LIST or msgType == MSG_QUEST_UPDATE then
        local quest = DecodeQuest(data)
        if quest and quest.id then
            memberData.quests[quest.id] = quest
        end

    elseif msgType == MSG_QUEST_DONE then
        local questId, questTitle = strsplit(FIELD_SEP, data or "", 2)
        questId = tonumber(questId)
        if questId then
            -- Remove from active quests
            memberData.quests[questId] = nil
        end

    elseif msgType == MSG_QUEST_NEW then
        local questId, questTitle = strsplit(FIELD_SEP, data or "", 2)
        questId = tonumber(questId)
        if questId and questTitle then
            memberData.quests[questId] = {
                id = questId,
                title = questTitle,
                level = 0,
                isComplete = false,
                objectives = {},
            }
        end
    end

    -- Trigger tracker update to show new party data
    if QM.ScheduleUpdate then
        QM.ScheduleUpdate({tracker = true})
    end
end

-- ============================================================================
-- Party Event Handlers
-- ============================================================================

function QM:OnGroupJoined()
    -- Broadcast quest list when joining a group
    C_Timer.After(2, function()
        QM:BroadcastQuestList()
    end)
end

function QM:OnGroupLeft()
    -- Clear party quest data
    wipe(QM.partyQuests)
    if QM.ScheduleUpdate then
        QM.ScheduleUpdate({tracker = true})
    end
end

-- Clean up stale party data (members who left)
function QM:CleanupPartyData()
    if GetNumGroupMembers() == 0 then
        wipe(QM.partyQuests)
        return
    end

    local currentMembers = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            local shortName = strsplit("-", name)
            currentMembers[shortName] = true
        end
    end

    for name in pairs(QM.partyQuests) do
        if not currentMembers[name] then
            QM.partyQuests[name] = nil
        end
    end
end

-- ============================================================================
-- Party Quest Utilities
-- ============================================================================

-- Check if a quest is shared with any party member
function QM:IsQuestSharedWithParty(questId)
    for _, memberData in pairs(self.partyQuests) do
        if memberData.quests[questId] then
            return true
        end
    end
    return false
end

-- Get list of party members who share a quest
function QM:GetPartyMembersWithQuest(questId)
    local members = {}
    for name, memberData in pairs(self.partyQuests) do
        if memberData.quests[questId] then
            table.insert(members, {
                name = name,
                quest = memberData.quests[questId],
            })
        end
    end
    return members
end

-- Get party progress summary for a specific quest
function QM:GetPartyQuestProgress(questId)
    local progress = {}
    for name, memberData in pairs(self.partyQuests) do
        local quest = memberData.quests[questId]
        if quest then
            local entry = {
                name = name,
                isComplete = quest.isComplete,
                objectives = {},
            }
            for i, obj in ipairs(quest.objectives or {}) do
                table.insert(entry.objectives, {
                    numGot = obj.numGot,
                    numNeeded = obj.numNeeded,
                    finished = obj.finished,
                })
            end
            table.insert(progress, entry)
        end
    end
    return progress
end

-- Get the total number of tracked party members
function QM:GetPartySyncMemberCount()
    local count = 0
    for _ in pairs(self.partyQuests) do
        count = count + 1
    end
    return count
end
