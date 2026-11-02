-- TBC Anniversary: show only the final quest of each *complete* linear chain.
-- All other chain steps remain in FDJ.DB and FDJ.QUEST_PREREQ_DETAILS, so their
-- progress, rewards, objectives, map locations and interactive chain pages work.
-- This is a display-only consolidation: no quest IDs, chains or steps are deleted.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end

local chains = FDJ.QUEST_PREREQ_CHAINS or {}
local db = FDJ.DB or {}

local function SupportsSameCharacters(stepQuest, finalQuest)
    -- Never merge Alliance and Horde versions, different classes, or a
    -- normal quest into a heroic-only final quest (or vice versa).
    local a, b = stepQuest.faction, finalQuest.faction
    if a ~= b and a ~= "Both" and a ~= "Neutral"
        and b ~= "Both" and b ~= "Neutral" then
        return false
    end
    if (stepQuest.heroicOnly == true) ~= (finalQuest.heroicOnly == true) then
        return false
    end
    if stepQuest.classOnly ~= finalQuest.classOnly then
        return false
    end
    if stepQuest.requiredSkill ~= finalQuest.requiredSkill then
        return false
    end
    return true
end

local collapsed = 0
local perDungeon = {}
for dungeonName, dungeon in pairs(db) do
    local quests = dungeon.quests or {}
    local concealed = {}

    for finalIndex, finalQuest in ipairs(quests) do
        if finalQuest.id and not finalQuest.hideFromMainList then
            local chain = chains[finalQuest.id]
            -- A few older chains are *prerequisite-only* or mixed item-step
            -- guides, not complete storyline sequences. Require the final
            -- quest to be the last recorded step before collapsing anything.
            if type(chain) == "table" and #chain >= 2
                and chain[#chain].id == finalQuest.id then
                for stepIndex = 1, #chain - 1 do
                    local step = chain[stepIndex]
                    if step.id and not step.itemStep then
                        for index, candidate in ipairs(quests) do
                            if index ~= finalIndex and candidate.id == step.id
                                and not candidate.hideFromMainList
                                and not candidate.alwaysShowInMainList
                                and SupportsSameCharacters(candidate, finalQuest) then
                                concealed[index] = true
                            end
                        end
                    end
                end
            end
        end
    end

    for index in pairs(concealed) do
        local quest = quests[index]
        quest.hideFromMainList = true
        quest.fdjVisibleInQuestChain = true
        collapsed = collapsed + 1
        perDungeon[dungeonName] = (perDungeon[dungeonName] or 0) + 1
    end
end

FDJ.QUEST_LIST_CONSOLIDATION = {
    hiddenSteps = collapsed,
    byDungeon = perDungeon,
}
