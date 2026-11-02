-- TBC Anniversary: show limited-time dungeon quests only while their matching
-- HOLIDAY exists on *today's in-game calendar*. Never use the PC date as an
-- alternate event schedule. In particular, Ahune's quests belong to Midsummer.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end

do
    local eventByQuestID = {
        -- Slave Pens / Midsummer Fire Festival
        [11955] = "midsummer", [11696] = "midsummer", [11972] = "midsummer",
        -- Classic Era Lunar Festival elders at dungeon locations
        [8676] = "lunar", [8635] = "lunar", [8713] = "lunar",
        [8619] = "lunar", [8644] = "lunar", [8714] = "lunar", [8727] = "lunar",
        -- Blackrock Depths / Brewfest
        [12062] = "brewfest",
    }

    -- Blizzard localizes calendar holiday titles. Search for distinctive words
    -- in the holiday name/description, NOT player-made calendar entries.
    -- Some CJK names are included verbatim because Lua 5.1 string.lower does
    -- not implement Unicode case folding.
    local aliases = {
        midsummer = {
            "midsummer", "fire festival", "solstice", "sommerfeuer", "sonnenwende",
            "mezza estate", "fuochi di mezza", "fuoco di mezza", "feu du solstice",
            "festival del fuego", "festival do fogo", "fogo do solstício",
            "солнцеворот", "огненный солнцеворот", "仲夏火焰", "한여름", "불꽃축제",
        },
        lunar = {
            "lunar festival", "mondfest", "festa della luna", "fête lunaire",
            "festival lunar", "festival da lua", "лунный фестиваль", "春节", "春節", "달의 축제",
        },
        brewfest = {
            "brewfest", "braufest", "brasseur", "festa della birra", "festival de la cerveza",
            "festival da cerveja", "хмельной", "美酒节", "美酒節", "가을 축제",
        },
        hallow = { "hallow's end", "schlotternächte", "sanssaint", "scherzetto", "hallows end" },
        winterveil = { "winter veil", "winterhauch", "voile d'hiver", "velo d'inverno", "invierno" },
        darkmoon = { "darkmoon faire", "dunkelmond", "sombraluna", "sombrelune", "luna nera" },
        love = { "love is in the air", "liebe liegt in der luft", "amor", "amour dans l'air" },
        childrens = { "children's week", "kinderwoche", "semaine des enfants" },
        noblegarden = { "noblegarden", "nobelgarten", "jardin des nobles" },
    }

    local function ContainsAny(text, words)
        if type(text) ~= "string" then return false end
        text = string.lower(text)
        for _, word in ipairs(words) do
            if string.find(text, word, 1, true) then return true end
        end
        return false
    end

    local function SeasonalQuestEvent(quest)
        if not quest then return nil end
        local event = eventByQuestID[quest.id]
        if event then return event end
        local name = string.lower(tostring(quest.name or ""))
        local note = string.lower(tostring(quest.note or ""))
        local objective = string.lower(tostring(quest.objective or ""))
        if name:find("ahune", 1, true) then return "midsummer" end
        if name:find("the elder", 1, true) and quest.hideFromMainList then return "lunar" end
        if name:find("coren direbrew", 1, true) then return "brewfest" end
        if note:find("midsummer", 1, true) or objective:find("midsummer", 1, true) then return "midsummer" end
        if note:find("lunar festival", 1, true) then return "lunar" end
        if note:find("brewfest", 1, true) then return "brewfest" end
        if note:find("hallow's end", 1, true) then return "hallow" end
        if note:find("winter veil", 1, true) then return "winterveil" end
        if note:find("darkmoon faire", 1, true) then return "darkmoon" end
        if note:find("noblegarden", 1, true) then return "noblegarden" end
        if note:find("children's week", 1, true) then return "childrens" end
        if quest.seasonal or quest.holiday or note:find("seasonal", 1, true)
            or objective:find("seasonal", 1, true) or note:find("event%-only")
            or objective:find("event%-only") then
            -- Unknown holiday: fail closed until it has an explicit mapping.
            return "unknown"
        end
        return nil
    end
    FDJ.SeasonalQuestEvent = SeasonalQuestEvent

    local cachedDate, cachedAt, cachedEvents = nil, nil, {}

    local function CalendarNow()
        if C_DateAndTime and type(C_DateAndTime.GetCurrentCalendarTime) == "function" then
            local ok, today = pcall(C_DateAndTime.GetCurrentCalendarTime)
            if ok and type(today) == "table" and today.year and today.month and today.monthDay then
                return today
            end
        end
        -- Only used to pick which day to ask the *game calendar* about;
        -- the fallback is never used as a standalone holiday schedule.
        if type(GetServerTime) == "function" and type(date) == "function" then
            local ok, today = pcall(function() return date("*t", GetServerTime()) end)
            if ok and today then
                return { year = today.year, month = today.month, monthDay = today.day,
                    hour = today.hour, minute = today.min }
            end
        end
    end

    local function DayKey(t)
        return t.year * 10000 + t.month * 100 + t.monthDay
    end

    local function ActiveWithinWindow(now, startTime, endTime)
        local current = DayKey(now) * 10000 + (now.hour or 0) * 100 + (now.minute or 0)
        if type(startTime) == "table" and startTime.year and startTime.month and startTime.monthDay then
            local begins = DayKey(startTime) * 10000 + (startTime.hour or 0) * 100 + (startTime.minute or 0)
            if current < begins then return false end
        end
        if type(endTime) == "table" and endTime.year and endTime.month and endTime.monthDay then
            local ends = DayKey(endTime) * 10000 + (endTime.hour or 23) * 100 + (endTime.minute or 59)
            if current > ends then return false end
        end
        return true
    end

    local function ReadActiveCalendarHolidays(today)
        local found = {}
        local calendar = C_Calendar
        if not calendar or type(calendar.SetAbsMonth) ~= "function"
            or type(calendar.GetMonthInfo) ~= "function"
            or type(calendar.GetNumDayEvents) ~= "function"
            or type(calendar.GetDayEvent) ~= "function" then
            return found -- Not a guess: hide seasonal quests on unsupported clients.
        end
        -- The calendar may be pointing to a month the player browsed (or the
        -- 2004 initial calendar month). Switch temporarily and restore it.
        local okOriginal, original = pcall(calendar.GetMonthInfo, 0)
        local restore = okOriginal and type(original) == "table" and original.month and original.year
        local changed = not restore or original.month ~= today.month or original.year ~= today.year
        local ok = pcall(function()
            if changed then calendar.SetAbsMonth(today.month, today.year) end
            local n = calendar.GetNumDayEvents(0, today.monthDay) or 0
            -- Cap the scan to avoid pathological calendar data freezing the UI.
            for index = 1, math.min(100, n) do
                local event = calendar.GetDayEvent(0, today.monthDay, index)
                if type(event) == "table" and event.calendarType == "HOLIDAY" then
                    local name = event.title or ""
                    local beginTime, endTime = event.startTime, event.endTime
                    if type(calendar.GetHolidayInfo) == "function" then
                        local holidayOK, info = pcall(calendar.GetHolidayInfo, 0, today.monthDay, index)
                        if holidayOK and type(info) == "table" then
                            name = name .. " " .. (info.name or "") .. " " .. (info.description or "")
                            beginTime = info.startTime or beginTime
                            endTime = info.endTime or endTime
                        end
                    end
                    if ActiveWithinWindow(today, beginTime, endTime) then
                        for holiday, keywords in pairs(aliases) do
                            if ContainsAny(name, keywords) then found[holiday] = true end
                        end
                    end
                end
            end
        end)
        if changed and restore then pcall(calendar.SetAbsMonth, original.month, original.year) end
        if not ok then return {} end
        return found
    end

    local function RefreshCalendar(force)
        local today = CalendarNow()
        if not today then return {} end
        local key = DayKey(today)
        local nowTime = type(GetTime) == "function" and GetTime() or 0
        if not force and key == cachedDate and cachedAt and nowTime - cachedAt < 90 then
            return cachedEvents
        end
        cachedEvents = ReadActiveCalendarHolidays(today)
        cachedDate, cachedAt = key, nowTime
        return cachedEvents
    end
    FDJ.GetActiveDungeonHolidays = RefreshCalendar
    FDJ.IsDungeonHolidayActive = function(holiday)
        return holiday ~= "unknown" and RefreshCalendar()[holiday] == true or false
    end
    FDJ.ShouldDisplayMainQuest = function(quest)
        local holiday = SeasonalQuestEvent(quest)
        if holiday then
            -- Hidden prerequisite-only nodes stay hidden regardless of holiday.
            if quest.fdjVisibleInQuestChain then return false end
            return FDJ.IsDungeonHolidayActive(holiday)
        end
        return not quest.hideFromMainList
    end

    -- Holiday dates can roll over with no reload. Refresh periodically and
    -- repaint an open quest list when the matching calendar holidays change.
    local function RefreshAndUpdate()
        local before = cachedEvents
        local updated = RefreshCalendar(true)
        local changed = false
        for key in pairs(aliases) do
            if (before[key] or false) ~= (updated[key] or false) then changed = true break end
        end
        if changed and FDJ.RefreshSeasonalQuestDisplay then FDJ.RefreshSeasonalQuestDisplay() end
    end
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:SetScript("OnEvent", function()
        cachedDate, cachedAt = nil, nil
        if C_Timer and C_Timer.After then
            C_Timer.After(3, RefreshAndUpdate)
            C_Timer.After(15, RefreshAndUpdate)
        end
    end)
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(120, RefreshAndUpdate) end
end
