-- Real quest text from the game. WoW only hands addons a quest's text while
-- it is in the quest log or while its quest-giver window is open, so the
-- journal remembers it then (per client language, shared by all characters)
-- and shows it on the quest page from then on:
--   * the game's own objective text instead of the journal's short summary
--   * the quest description ("Description" section)
--   * live progress lines (5/7 Deviate Dreadfang slain) while it is in the log
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local NAME_TOKEN = "\001N" -- the player's name is stored as a token

local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Str(v) return type(v) == "string" and not Secret(v) and v ~= "" and v or nil end

local function Locale() return (GetLocale and GetLocale()) or "enUS" end

local function Store()
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local all = ForeverDungeonJournalDB.questText
    if type(all) ~= "table" then all = {}; ForeverDungeonJournalDB.questText = all end
    local loc = Locale()
    all[loc] = all[loc] or {}
    return all[loc]
end

local function PlayerName()
    local ok, name = pcall(UnitName, "player")
    return ok and Str(name) or nil
end

local function Tokenize(text)
    local name = PlayerName()
    if not text or not name then return text end
    return (text:gsub(name:gsub("(%W)", "%%%1"), NAME_TOKEN))
end

local function Detokenize(text)
    if not text then return nil end
    local name = PlayerName() or ""
    return (text:gsub(NAME_TOKEN, (name:gsub("%%", "%%%%"))))
end

local function Save(questID, objective, description)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return end
    objective, description = Str(objective), Str(description)
    if not objective and not description then return end
    local entry = Store()[questID] or {}
    if objective then entry.o = Tokenize(objective) end
    if description then entry.d = Tokenize(description) end
    Store()[questID] = entry
end

-- ------------------------------------------------------------- learning
local function ScanLog()
    if type(GetQuestLogQuestText) ~= "function" then return end
    -- Forever uses C_QuestLog; TBC Anniversary uses the traditional quest log
    -- globals, with questID as the eighth return from GetQuestLogTitle.
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local okN, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        if not okN or type(n) ~= "number" then return end
        for i = 1, n do
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
                local ok2, desc, obj = pcall(GetQuestLogQuestText, i)
                if ok2 then Save(info.questID, obj, desc) end
            end
        end
    elseif type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
        local okN, n = pcall(GetNumQuestLogEntries)
        if not okN or type(n) ~= "number" then return end
        for i = 1, n do
            local ok, _, _, _, isHeader, _, _, _, questID = pcall(GetQuestLogTitle, i)
            if ok and not isHeader and type(questID) == "number" and questID > 0 then
                local okText, desc, obj = pcall(GetQuestLogQuestText, i)
                if okText then Save(questID, obj, desc) end
            end
        end
    end
end

local pending = false
local function ScanSoon()
    if pending then return end
    pending = true
    local function run() pending = false; pcall(ScanLog) end
    if C_Timer and C_Timer.After then C_Timer.After(1, run) else run() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "QUEST_DETAIL" then
        pcall(function()
            local id = GetQuestID and GetQuestID()
            Save(id, GetObjectiveText and GetObjectiveText(), GetQuestText and GetQuestText())
        end)
    else
        ScanSoon()
    end
end)

-- -------------------------------------------------------------- display
local function Learned(questID)
    if not questID then return nil end
    -- Text is stored in the client language: only use it when the journal
    -- shows that language too.
    if FDJ.CanUseClientLocalizedText and not FDJ.CanUseClientLocalizedText() then return nil end
    local entry = Store()[tonumber(questID)]
    if not entry then return nil end
    return Detokenize(entry.o), Detokenize(entry.d)
end
FDJ.LearnedQuestText = Learned

local function ProgressLines(questID)
    if not questID then return nil end
    local lines = {}
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetQuestObjectives then
        local okI, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if not okI or type(index) ~= "number" or index <= 0 then return nil end
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
        if not ok or type(objectives) ~= "table" then return nil end
        for _, o in ipairs(objectives) do
            local text = type(o) == "table" and Str(o.text)
            if text then
                lines[#lines + 1] = o.finished and ("|cff6e5c40" .. text .. "|r") or text
            end
        end
    elseif type(GetQuestLogIndexByID) == "function" and type(GetNumQuestLeaderBoards) == "function"
        and type(GetQuestLogLeaderBoard) == "function" then
        local okI, index = pcall(GetQuestLogIndexByID, questID)
        if not okI or type(index) ~= "number" or index <= 0 then return nil end
        local okN, n = pcall(GetNumQuestLeaderBoards, index)
        if not okN or type(n) ~= "number" then return nil end
        for i = 1, n do
            local ok, text, _, finished = pcall(GetQuestLogLeaderBoard, i, index)
            text = ok and Str(text) or nil
            if text then
                lines[#lines + 1] = finished and ("|cff6e5c40" .. text .. "|r") or text
            end
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

-- Objective block for the quest page: the game's objective (or the
-- journal's fallback) plus live progress; second value is the description.
function FDJ.QuestPageText(questID, fallbackObjective)
    local obj, desc = Learned(questID)
    local text = obj or fallbackObjective or ""
    local progress = ProgressLines(questID)
    if progress then text = (text ~= "" and (text .. "\n\n") or "") .. progress end
    return text, desc
end

-- Places the Description section; returns the new y offset.
function FDJ.PlaceQuestDescription(frame, desc, y, placeHeader)
    local header, body = frame.questDescHeader, frame.questDescText
    if not header or not body then return y end
    -- The description is not shown (too long for the quest page); only the
    -- game's objective text and live progress are used.
    if true or not desc or desc == "" then
        header:Hide(); body:Hide()
        return y
    end
    y = placeHeader(header, y)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", 0, -y)
    body:SetWidth(frame.questDetailText:GetWidth() or 360)
    body:SetText(desc)
    body:SetTextColor(0.10, 0.065, 0.025)
    body:Show()
    return y + (body:GetStringHeight() or 30) + 13
end

function FDJ.HideQuestDescription(frame)
    if frame and frame.questDescHeader then frame.questDescHeader:Hide() end
    if frame and frame.questDescText then frame.questDescText:Hide() end
end
