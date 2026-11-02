-- ForeverLFG
-- Copyright (c) 2026 Forever. All rights reserved.
-- Custom license: see LICENSE for permissions and earlier MIT releases.
-- Permission requests: wow@werko.dev or https://werko.dev/addons/feedback/

local _, NS = ...
local events = CreateFrame("Frame")
local installed

local function Install()
    if installed then return end
    local original = LFGBrowseSearchEntryTooltip_UpdateAndShow
    if type(original) ~= "function" then return end
    local lastMissingID, lastMissingAt

    -- В 70009 подсказка обращается к numMembers без проверки отсутствующего результата.
    -- Post-hook слишком поздний: исключение возникает внутри оригинала.
    LFGBrowseSearchEntryTooltip_UpdateAndShow = function(tooltip, resultID, ...)
        local getter = C_LFGList and C_LFGList.GetSearchResultInfo
        if type(getter) == "function" and type(resultID) == "number"
            and not (issecretvalue and issecretvalue(resultID)) then
            local ok, info = pcall(getter, resultID)
            -- Другие ошибки и secret values оставляем штатному обработчику.
            if ok and not (issecretvalue and issecretvalue(info)) and info == nil then
                tooltip:Hide()
                local now = GetTime()
                if resultID ~= lastMissingID or now - lastMissingAt >= 5 then
                    NS.Log("Warning", "Skipped stale listing tooltip; resultID=" .. resultID
                        .. "; GetSearchResultInfo returned nil; searchPending=" .. tostring(not not NS.IsPending()), true)
                    lastMissingID, lastMissingAt = resultID, now
                end
                return
            end
        end
        return original(tooltip, resultID, ...)
    end
    installed = true
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Install)
