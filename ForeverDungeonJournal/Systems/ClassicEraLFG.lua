-- Classic Era "Looking For Group" eye on dungeon pages.
-- Same code as the TBC Anniversary edition: it drives the client's own Group
-- Finder (Blizzard_GroupFinder_VanillaStyle) - open the window on the Group
-- Browser tab, set the category, tick this dungeon in the Activity drop-down
-- and run the browser's own search. Not every Classic Era realm type has the
-- Group Finder enabled, so the eye only appears once the client reports at
-- least one LFG activity; on realms without the tool it stays hidden.
-- The Forever client has a different window (Systems/LFGButton.lua).
local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS
local function DB() return ForeverDungeonJournalDB end

-- Is the Group Finder usable on this realm? Checked lazily (the activity list
-- is empty until the client has logged in) and re-checked while it says no.
local lfgAvailable = nil
function FDJ.LFGToolAvailable()
    if lfgAvailable then return true end
    if not (C_LFGList and type(C_LFGList.GetAvailableActivities) == "function") then return false end
    local ok, ids = pcall(C_LFGList.GetAvailableActivities)
    if ok and type(ids) == "table" and #ids > 0 then
        lfgAvailable = true
        return true
    end
    return false
end

-- Activity IDs on the TBC Anniversary client (recorded from /dj lfgdebug).
local NORMAL = {
    ["Wailing Caverns"] = 796, ["Scholomance"] = 797, ["The Deadmines"] = 799,
    ["Shadowfang Keep"] = 800, ["Blackfathom Deeps"] = 801, ["The Stockade"] = 802,
    ["Gnomeregan"] = 803, ["Razorfen Kraul"] = 804, ["Scarlet Monastery: Graveyard"] = 805,
    ["Razorfen Downs"] = 806, ["Uldaman"] = 807, ["Zul'Farrak"] = 808, ["Maraudon"] = 809,
    ["The Temple of Atal'Hakkar"] = 810, ["Blackrock Depths"] = 811,
    ["Lower Blackrock Spire"] = 812, ["Dire Maul: East"] = 813, ["Dire Maul: West"] = 814,
    ["Dire Maul: North"] = 815, ["Stratholme: Living"] = 816, ["Stratholme: Undead"] = 1603,
    ["Hellfire Ramparts"] = 817, ["The Blood Furnace"] = 818, ["The Shattered Halls"] = 819,
    ["The Slave Pens"] = 820, ["The Underbog"] = 821, ["The Steamvault"] = 822,
    ["Mana-Tombs"] = 823, ["Auchenai Crypts"] = 824, ["Sethekk Halls"] = 825,
    ["Shadow Labyrinth"] = 826, ["Scarlet Monastery: Armory"] = 827,
    ["Scarlet Monastery: Cathedral"] = 828, ["Scarlet Monastery: Library"] = 829,
    ["Old Hillsbrad Foothills"] = 830, ["The Black Morass"] = 831, ["The Mechanar"] = 832,
    ["The Botanica"] = 833, ["The Arcatraz"] = 834, ["Upper Blackrock Spire"] = 837,
    -- Raids (category 114)
    ["Karazhan"] = 844, ["Magtheridon's Lair"] = 845, ["Gruul's Lair"] = 846,
    ["Tempest Keep: The Eye"] = 847, ["Serpentshrine Cavern"] = 848,
    ["Battle for Mount Hyjal"] = 849, ["Black Temple"] = 850,
}
local HEROIC = {
    ["Auchenai Crypts"] = 903, ["Mana-Tombs"] = 904, ["Sethekk Halls"] = 905,
    ["Shadow Labyrinth"] = 906, ["The Black Morass"] = 907, ["Old Hillsbrad Foothills"] = 908,
    ["The Slave Pens"] = 909, ["The Steamvault"] = 910, ["The Underbog"] = 911,
    ["The Blood Furnace"] = 912, ["Hellfire Ramparts"] = 913, ["The Shattered Halls"] = 914,
    ["The Arcatraz"] = 915, ["The Mechanar"] = 916, ["The Botanica"] = 918,
}

local function Say(msg) print("|cffffd200Dungeon Journal:|r " .. msg) end

local function Norm(s)
    if type(s) ~= "string" then return "" end
    return (s:lower():gsub("%(heroic%)", ""):gsub("^the ", ""):gsub("[^%w]", ""))
end

local function WantHeroic(name)
    local d = FDJ.DB and FDJ.DB[name]
    return d and d.hasHeroic and FDJ.IsHeroicMode and FDJ.IsHeroicMode() or false
end

local function Info(id)
    if not (id and C_LFGList and C_LFGList.GetActivityInfoTable) then return nil end
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
    return ok and type(info) == "table" and info or nil
end

-- Known ID first; otherwise look the dungeon up by name (e.g. dungeons the
-- client adds in a later phase, like Magisters' Terrace).
local function ActivityFor(name)
    local heroic = WantHeroic(name)
    local id = heroic and HEROIC[name] or NORMAL[name]
    if id and Info(id) then return id, heroic end
    local wanted = Norm(name)
    local ok, ids = pcall(C_LFGList.GetAvailableActivities)
    if not ok or type(ids) ~= "table" then return nil end
    for _, aid in ipairs(ids) do
        local info = Info(aid)
        if info then
            local full = info.fullName or ""
            local isHeroic = full:lower():find("heroic", 1, true) ~= nil
            local n = Norm(full)
            if isHeroic == heroic and #wanted >= 5 and (n == wanted or n:sub(-#wanted) == wanted) then
                return aid, heroic
            end
        end
    end
    return nil
end

local function OpenFor(name)
    local log = { dungeon = name, time = date and date() or "" }
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.lfgClick = log
    if InCombatLockdown and InCombatLockdown() then
        Say("Open Looking For Group outside combat.")
        return
    end
    if not (LFGParentFrame and ShowLFGParentFrame) then
        log.err = "no LFGParentFrame"
        if ToggleLFGParentFrame then pcall(ToggleLFGParentFrame, 2) end
        return
    end
    local id, heroic = ActivityFor(name)
    log.activity, log.heroic = id, heroic
    -- Open straight on the Group Browser tab (tab 2).
    local ok, err = pcall(ShowLFGParentFrame, 2)
    log.opened, log.err = ok, (not ok) and tostring(err) or nil
    if not ok then return end
    if not id then
        Say("couldn't find " .. (FDJ.LocalizeDungeonName and FDJ.LocalizeDungeonName(name) or name)
            .. (heroic and " (Heroic)" or "") .. " in the Group Finder list.")
        return
    end
    local browse = LFGBrowseFrame
    if not (browse and browse.CategoryDropdown and browse.ActivityDropdown and LFGBrowse_DoSearch) then
        log.err = "browse frame missing"
        return
    end
    local info = Info(id)
    local categoryID = (info and info.categoryID) or 2
    ok, err = pcall(function()
        browse.CategoryDropdown:SetValue(categoryID)
        browse.ActivityDropdown:ValueReset()
        browse.ActivityDropdown:ValueSetSelected(id, true)
        browse.ActivityDropdown:SetupDropdown()
        browse.searching = false -- a search still in flight would block the new one
        LFGBrowse_DoSearch()
    end)
    log.searched, log.err = ok, (not ok) and tostring(err) or nil
    if not ok then Say("couldn't start the search (" .. tostring(err) .. ").") end
end

function FDJ.IsLFGButtonHidden()
    return DB() and DB().hideLFGButton == true or false
end

function FDJ.SetLFGButtonHidden(hidden)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.hideLFGButton = hidden and true or nil
    local frame = _G.ForeverDungeonJournalFrame
    if frame and frame.lfgButton then
        frame.lfgButton:SetShown(not hidden and frame.lfgButton.fdjDungeon ~= nil)
        if frame.dungeonRouteButton then
            frame.dungeonRouteButton:ClearAllPoints()
            frame.dungeonRouteButton:SetPoint("LEFT",
                hidden and frame.dungeonLocationButton or frame.lfgButton, "RIGHT", 3, 0)
        end
    end
    if FDJ.FitDungeonTitle then FDJ.FitDungeonTitle() end
    local settings = _G.ForeverDungeonJournalSettings
    if settings and settings:IsShown() then
        local onShow = settings:GetScript("OnShow")
        if onShow then pcall(onShow, settings) end
    end
end

function FDJ.LFGToggleLabel()
    return FDJ.IsLFGButtonHidden() and "Show LFG Panel" or "Hide LFG Panel"
end

function FDJ.LFGToggleTip()
    return "Show or hide the Group Finder icon on dungeon pages."
end

-- Icon styling copied from the Forever build (Systems/LFGButton.lua):
-- soft gold glow, the game's own LFG eye art, and once the game's Looking
-- For Group window has been opened, its round eye portrait with a gold ring.
local EYE = "Interface\\LFGFrame\\LFG-Eye" -- 512x256 sheet, 64x64 frames
local RING = "Interface\\Common\\GoldRing"

local function FileExists(path)
    if not GetFileIDFromPath then return true end
    local ok, id = pcall(GetFileIDFromPath, path)
    return ok and id ~= nil
end

local function PortraitSource()
    local candidates = {
        LFGBrowseFrame and LFGBrowseFrame.PortraitContainer and LFGBrowseFrame.PortraitContainer.portrait,
        LFGParentFrame and LFGParentFrame.PortraitContainer and LFGParentFrame.PortraitContainer.portrait,
        LFGListingFrame and LFGListingFrame.PortraitContainer and LFGListingFrame.PortraitContainer.portrait,
        _G.LFGParentFramePortraitTexture,
    }
    for _, tex in pairs(candidates) do
        if tex and tex.GetTexture then
            local atlas = tex.GetAtlas and tex:GetAtlas()
            local file = tex:GetTexture()
            if (atlas and atlas ~= "") or file then return tex, atlas, file end
        end
    end
    return nil
end

local function ApplyLFGPortrait(b)
    if not b or b.fdjPortraitDone then return end
    pcall(function()
        local src, atlas, file = PortraitSource()
        if not src then return end
        b.icon:ClearAllPoints()
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(30, 30)
        if atlas and atlas ~= "" then
            b.icon:SetTexCoord(0, 1, 0, 1)
            b.icon:SetAtlas(atlas)
        else
            b.icon:SetTexture(file)
            b.icon:SetTexCoord(src:GetTexCoord())
        end
        if not b.fdjMask and b.CreateMaskTexture then
            local mask = b:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(b.icon)
            b.icon:AddMaskTexture(mask)
            b.fdjMask = mask
        end
        if FileExists(RING) and not b.fdjRing then
            local ring = b:CreateTexture(nil, "OVERLAY")
            ring:SetTexture(RING)
            ring:SetPoint("CENTER")
            ring:SetSize(37, 37)
            b.fdjRing = ring
        end
        b.fdjPortraitDone = true
    end)
end
FDJ.ApplyLFGPortrait = ApplyLFGPortrait

function FDJ.CreateLFGButton(frame, header, anchor)
    local button = CreateFrame("Button", nil, header)
    button:SetSize(38, 38)
    button:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
    button:SetFrameLevel(header:GetFrameLevel() + 4)

    -- Same eye and gold glow as the Forever client, shipped with the addon
    -- (TBC Anniversary's own LFG art is older and lower resolution).
    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\FDJEyeGlow")
    button.glow:SetBlendMode("ADD")
    button.glow:SetSize(44, 44)
    button.glow:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\ForeverDungeonJournal\\Media\\FDJEyeIcon")
    icon:SetSize(44, 44)
    icon:SetPoint("CENTER")
    button.icon = icon

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = button:GetHighlightTexture()
    if hl then hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", 5, -5); hl:SetPoint("BOTTOMRIGHT", -5, 5) end
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Looking For Group")
        GameTooltip:AddLine("Opens Group Browser and searches for groups for this dungeon" .. ((self.fdjHeroic and " (Heroic)") or "") .. ".", 1, 1, 1, true)
        GameTooltip:AddLine("Right click to hide this icon", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then FDJ.SetLFGButtonHidden(true) return end
        if self.fdjDungeon then OpenFor(self.fdjDungeon) end
    end)
    frame.lfgButton = button
end

function FDJ.UpdateLFGButton(frame, name, dungeon)
    local button = frame and frame.lfgButton
    if not button then return end
    button.fdjDungeon = dungeon and not dungeon.lootFilterPage and not dungeon.recipeSearch
        and not dungeon.previewOnly and name or nil
    button.fdjHeroic = button.fdjDungeon and WantHeroic(name) or nil
    if button.fdjDungeon and not FDJ.LFGToolAvailable() then button.fdjDungeon = nil end
    button:SetShown(not FDJ.IsLFGButtonHidden() and button.fdjDungeon ~= nil)
    if frame.dungeonRouteButton then
        frame.dungeonRouteButton:ClearAllPoints()
        frame.dungeonRouteButton:SetPoint("LEFT",
            FDJ.IsLFGButtonHidden() and frame.dungeonLocationButton or button,
            "RIGHT", 3, 0)
    end
end

function FDJ.LFGDebug()
    local acts = {}
    local ok, ids = pcall(C_LFGList.GetAvailableActivities)
    for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
        local info = Info(id)
        if info then acts[#acts + 1] = id .. ":" .. tostring(info.fullName) .. ":cat" .. tostring(info.categoryID) end
    end
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    ForeverDungeonJournalDB.lfgDebug = { time = date and date() or "", activities = acts }
    Say("Group Finder list saved (" .. #acts .. " activities). /reload to write it to disk.")
end
