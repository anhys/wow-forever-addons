-- Profession-only dungeon quests. Profession requirements are independent
-- of class, faction, skill-level, or quest-chain prerequisites.
-- Loaded after the quest databases and before the journal UI.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ then return end

local PROFESSIONS = {
    ALCHEMY = { skill = 171, spell = 2259, icon = "Interface\\Icons\\Trade_Alchemy" },
    BLACKSMITHING = { skill = 164, spell = 2018, icon = "Interface\\Icons\\Trade_BlackSmithing" },
    ENCHANTING = { skill = 333, spell = 7411, icon = "Interface\\Icons\\Trade_Engraving" },
    ENGINEERING = { skill = 202, spell = 4036, icon = "Interface\\Icons\\Trade_Engineering" },
    HERBALISM = { skill = 182, spell = 2366, icon = "Interface\\Icons\\Trade_Herbalism" },
    INSCRIPTION = { skill = 773, spell = 45357, icon = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
    JEWELCRAFTING = { skill = 755, spell = 25229, icon = "Interface\\Icons\\INV_Misc_Gem_01" },
    LEATHERWORKING = { skill = 165, spell = 2108, icon = "Interface\\Icons\\Trade_LeatherWorking" },
    MINING = { skill = 186, spell = 2575, icon = "Interface\\Icons\\Trade_Mining" },
    SKINNING = { skill = 393, spell = 8613, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    TAILORING = { skill = 197, spell = 3908, icon = "Interface\\Icons\\Trade_Tailoring" },
    COOKING = { skill = 185, spell = 2550, icon = "Interface\\Icons\\INV_Misc_Food_15" },
    FISHING = { skill = 356, spell = 7620, icon = "Interface\\Icons\\Trade_Fishing" },
    FIRSTAID = { skill = 129, spell = 3273, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
}

-- Explicit quest-ID classifications also cover older entries that don't have
-- requiredSkill metadata. IDs, not displayed/translated titles, are used.
local PROFESSIONAL_QUEST_IDS = {
    [10902] = "ALCHEMY", -- Master of Elixirs / Black Morass
    [10897] = "ALCHEMY", -- Master of Potions / Botanica
    [4083] = "MINING",   -- The Spectral Chalice / BRD
}

local function NormalizeProfession(value)
    if type(value) ~= "string" then return nil end
    local upper = value:upper():gsub("[%s%-_]", "")
    if PROFESSIONS[upper] then return upper end
    return nil
end

function FDJ.GetQuestProfession(quest)
    if type(quest) ~= "table" then return nil end
    -- An explicit per-quest designation takes precedence over legacy text.
    local tag = NormalizeProfession(quest.professionOnly or quest.professionQuest)
    if tag then return tag end
    local byID = PROFESSIONAL_QUEST_IDS[tonumber(quest.id)]
    if byID then return byID end
    -- These are actual skill requirements, not incidental text mentioning
    -- crafted materials; do not infer a profession from an objective/note.
    if type(quest.requiredSkill) == "string" then
        local name = quest.requiredSkill:match("^%s*([%a%s]+)%s+%d+%s*$")
        return NormalizeProfession(name)
    end
    return nil
end

function FDJ.QuestProfessionIcon(quest)
    local key = type(quest) == "table" and FDJ.GetQuestProfession(quest)
        or NormalizeProfession(quest)
    return key and PROFESSIONS[key] and PROFESSIONS[key].icon or nil
end

local localNames
local known, knownAt
local function LocalNames()
    if localNames then return localNames end
    localNames = {}
    for key, info in pairs(PROFESSIONS) do
        local translated
        if type(GetSpellInfo) == "function" then
            local ok, result = pcall(GetSpellInfo, info.spell)
            if ok and type(result) == "string" then translated = result end
        elseif C_Spell and type(C_Spell.GetSpellName) == "function" then
            local ok, result = pcall(C_Spell.GetSpellName, info.spell)
            if ok and type(result) == "string" then translated = result end
        end
        if translated then localNames[translated:lower()] = key end
        localNames[key:lower()] = key
        localNames[key:lower():gsub("firstaid", "first aid")] = key
    end
    return localNames
end

local function MarkKnown(found, professionName, skillLine)
    local number = tonumber(skillLine)
    if number then
        for key, info in pairs(PROFESSIONS) do
            if info.skill == number then found[key] = true; return end
        end
    end
    if type(professionName) == "string" then
        local key = LocalNames()[professionName:lower()]
        if key then found[key] = true end
    end
end

local function ReadKnownProfessions()
    local found = {}
    -- Classic/TBC clients normally expose the learned primary/secondary
    -- professions through GetProfessions + GetProfessionInfo.
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local ok, p1, p2, p3, p4, p5 = pcall(GetProfessions)
        if ok then
            -- Iterate all five slots explicitly: nil gaps are normal when a
            -- character has only one of its primary/secondary professions.
            local slots = { p1, p2, p3, p4, p5 }
            for i = 1, 5 do
                if type(slots[i]) == "number" then
                    local infoOK, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, slots[i])
                    if infoOK then MarkKnown(found, name, skillLine) end
                end
            end
        end
    end
    -- Legacy fallback for clients where GetProfessions is not present.
    if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        local ok, count = pcall(GetNumSkillLines)
        if ok and type(count) == "number" then
            for i = 1, math.min(count, 300) do
                local got, name, isHeader, _, rank, _, _, _, _, _, _, _, skillLine = pcall(GetSkillLineInfo, i)
                if got and not isHeader and (not rank or rank > 0) then
                    MarkKnown(found, name, skillLine)
                end
            end
        end
    end
    return found
end

function FDJ.ResetProfessionQuestCache()
    known, knownAt = nil, nil
end

function FDJ.PlayerHasQuestProfession(profession)
    local key = NormalizeProfession(profession)
    if not key then return false end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if not known or not knownAt or (now > 0 and now - knownAt > 5) then
        known = ReadKnownProfessions()
        knownAt = now
    end
    return known[key] == true
end

function FDJ.IsQuestProfessionVisible(quest)
    local key = FDJ.GetQuestProfession(quest)
    if not key then return true end
    if ForeverDungeonJournalDB and ForeverDungeonJournalDB.showAllProfessionQuests then return true end
    return FDJ.PlayerHasQuestProfession(key)
end

-- Learning, dropping, or swapping a profession updates the quest list and the
-- home-page quest counts without needing /reload. Coalesce event bursts.
local eventFrame = CreateFrame("Frame")
local pending = false
local function Refresh()
    pending = false
    FDJ.ResetProfessionQuestCache()
    if FDJ.ScheduleQuestRefresh then FDJ.ScheduleQuestRefresh() end
    if FDJ.RefreshHomeCards then FDJ.RefreshHomeCards() end
end
eventFrame:SetScript("OnEvent", function()
    FDJ.ResetProfessionQuestCache()
    if pending then return end
    pending = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.2, Refresh)
    else
        Refresh()
    end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_UPDATE", "LEARNED_SPELL_IN_TAB" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
