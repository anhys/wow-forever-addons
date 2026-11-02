local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local listBg = TrainerSpells.ClassListBackground
local searchBox = TrainerSpells.SearchBox
local SPELLBOOK_TAB_NAMES = {"TrainerSpellsSpellbookTab", "TrainerSpellsPetSpellbookTab", "TrainerSpellsClassTrainerMapTab", "TrainerSpellsWeaponSpellbookTab"}
for i = 1, 8 do
    table.insert(SPELLBOOK_TAB_NAMES, "SpellBookSkillLineTab" .. i)
end

local function GetSearchLeftOffset(defaultOffset, topOffset)
    local frameScale = classFrame:GetEffectiveScale()
    local frameLeft = classFrame:GetLeft()
    local frameRight = classFrame:GetRight()
    local frameTop = classFrame:GetTop()
    if not frameLeft or not frameRight or not frameTop then return defaultOffset end
    local rowTop = frameTop + topOffset
    local rowBottom = rowTop - 40
    local offset = defaultOffset
    for _, name in ipairs(SPELLBOOK_TAB_NAMES) do
        local tab = _G[name]
        if tab and tab:IsShown() and tab:GetLeft() then
            local scale = tab:GetEffectiveScale() / frameScale
            local left, right = tab:GetLeft() * scale, tab:GetRight() * scale
            local top, bottom = tab:GetTop() * scale, tab:GetBottom() * scale
            if left < frameRight - 4 and bottom < rowTop and top > rowBottom then offset = math.max(offset, right - frameLeft + 8) end
        end
    end
    return offset
end

local function PositionFrame()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    classFrame:ClearAllPoints()
    if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUISpellBookBG and DragonflightUISpellBookBG:IsShown() then
        listBg:SetPoint("CENTER", classFrame, "CENTER", 0, 0)
        if DragonflightUISpellBookInsetBg then
            local shortHeight = 30
            listBg:ClearAllPoints()
            listBg:SetPoint("TOPLEFT", DragonflightUISpellBookInsetBg, "TOPLEFT", 0, -shortHeight)
            listBg:SetPoint("BOTTOMRIGHT", DragonflightUISpellBookInsetBg, "BOTTOMRIGHT", 0, 0)
            listBg:SetTexture(DragonflightUISpellBookInsetBg:GetTexture())
            local fullHeight = DragonflightUISpellBookInsetBg:GetHeight()
            local cropTop = shortHeight / fullHeight
            listBg:SetTexCoord(0, 1, cropTop, 1)
            listBg:SetVertexColor(0, 0, 0)
        end
    else
        listBg:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -2)
        listBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
    end

    if SpellBookFrame and SpellBookFrame:IsShown() then
        classFrame:SetScale(SpellBookFrame:GetScale())
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUISpellBookBG and DragonflightUISpellBookBG:IsShown() then
            classFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 4, -50)
            classFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -4, 4)
        else
            classFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 14, -70)
            classFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -36, 70)
        end
    else
        classFrame:SetScale(1)
        classFrame:SetPoint("CENTER")
    end

    searchBox:ClearAllPoints()
    local titleText = SpellBookFrame and _G["SpellBookTitleText"]
    if titleText and classFrame:GetTop() and titleText:GetBottom() then
        local topOffset = titleText:GetBottom() - classFrame:GetTop() - 4
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", GetSearchLeftOffset(66, topOffset), topOffset)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, topOffset)
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 10, -6)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -30, -6)
    end

    local showWeaponControls = TrainerSpells.ClassView == "weapons" and TrainerSpells.WeaponControls
    local showClassTrainerControls = TrainerSpells.ClassView == "trainers" and TrainerSpells.ClassTrainerControls
    if TrainerSpells.WeaponControls then
        TrainerSpells.WeaponControls:ClearAllPoints()
        TrainerSpells.WeaponControls:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -4)
        TrainerSpells.WeaponControls:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, -4)
        TrainerSpells.WeaponControls:SetShown(showWeaponControls and true or false)
    end

    if TrainerSpells.ClassTrainerControls then
        TrainerSpells.ClassTrainerControls:ClearAllPoints()
        TrainerSpells.ClassTrainerControls:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -4)
        TrainerSpells.ClassTrainerControls:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, -4)
        TrainerSpells.ClassTrainerControls:SetShown(showClassTrainerControls and true or false)
    end

    if TrainerSpells.ClassScrollBox then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        local controlsOffset = showClassTrainerControls and -44 or showWeaponControls and -36 or -4
        TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 6, controlsOffset)
        TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -24, 13)
    end
end

if SpellBookFrame then hooksecurefunc(SpellBookFrame, "SetScale", function() if classFrame:IsShown() then PositionFrame() end end) end
local repositionQueued = false
local function QueuePositionFrame()
    if repositionQueued or not classFrame:IsShown() then return end
    repositionQueued = true
    C_Timer.After(0, function()
        repositionQueued = false
        if classFrame:IsShown() then PositionFrame() end
    end)
end

if SpellBookFrame then
    for _, funcName in ipairs({"SpellBookFrame_Update", "SpellBookFrame_UpdateSkillLineTabs"}) do
        if _G[funcName] then hooksecurefunc(funcName, QueuePositionFrame) end
    end

    for i = 1, 8 do
        local tab = _G["SpellBookSkillLineTab" .. i]
        if tab then
            tab:HookScript("OnShow", QueuePositionFrame)
            tab:HookScript("OnHide", QueuePositionFrame)
        end
    end

    local tabWatcher = CreateFrame("Frame")
    for _, event in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "UNIT_PET"}) do
        TrainerSpells:RegisterEvent(tabWatcher, event)
    end

    tabWatcher:SetScript("OnEvent", QueuePositionFrame)
end

local NATIVE_EXTRA_WIDGETS = {"SpellBookPageNavigationFrame", "SpellBookFrameShowAllSpellRanksCheckbox", "ShowAllSpellRanksCheckbox",}
local spellButtonsHidden = false
local hiddenPageRegions = {}
local function HideNativeSpellButtons()
    if classFrame.compendiumHost or spellButtonsHidden then return end
    spellButtonsHidden = true
    for _, name in ipairs(NATIVE_EXTRA_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Hide() end
    end

    wipe(hiddenPageRegions)
    if SpellBookFrame then
        for _, region in ipairs({SpellBookFrame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                if text and text:find("^Page ") then
                    region:Hide()
                    table.insert(hiddenPageRegions, region)
                end
            end
        end
    end
end

local function ShowNativeSpellButtons()
    if not spellButtonsHidden then return end
    spellButtonsHidden = false
    for _, name in ipairs(NATIVE_EXTRA_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Show() end
    end

    for _, region in ipairs(hiddenPageRegions) do
        region:Show()
    end

    wipe(hiddenPageRegions)
    if SpellBookFrame_Update then SpellBookFrame_Update() end
end

local classicModeTabs = {}
local classicModeTabGlows = {}
local function GetTabGlow(tabFrame)
    if not tabFrame then return nil end
    for _, region in ipairs({tabFrame:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetDrawLayer and region:GetDrawLayer() == "OVERLAY" then return region end
    end
end

local function HideNativeSkillTabGlows()
    for i = 1, 8 do
        local glow = GetTabGlow(_G["SpellBookSkillLineTab" .. i])
        if glow then glow:Hide() end
    end
end

local function HideClassicModeTabGlows()
    for _, glow in pairs(classicModeTabGlows) do
        glow:Hide()
    end
end

local function OpenFrame(view)
    if classFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(classFrame) end
    TrainerSpells:SetClassView(view)
    PositionFrame()
    classFrame:Show()
    HideNativeSpellButtons()
    HideNativeSkillTabGlows()
    HideClassicModeTabGlows()
    if classicModeTabGlows[view] then classicModeTabGlows[view]:Show() end
end

if SpellBookFrame and TrainerSpells:HasClassTrainers() then
    local lastTab = _G["SpellBookSkillLineTab5"] or _G["SpellBookSkillLineTab4"] or _G["SpellBookSkillLineTab1"] or SpellBookFrame
    local classicModeTabOrder = {}
    local function CreateClassicModeTab(name, view, icon, tooltip)
        local tab = CreateFrame("Button", name, SpellBookFrame)
        tab:SetSize(32, 32)
        tab:SetNormalTexture(icon)
        tab:SetHighlightTexture(130718, "ADD")
        local border = tab:CreateTexture(name .. "Border", "BACKGROUND")
        border:SetSize(64, 64)
        border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
        border:SetTexture(136831)
        tab.tsBorder = border
        local glow = tab:CreateTexture(nil, "OVERLAY")
        glow:SetSize(32, 32)
        glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
        glow:SetTexture(130724)
        glow:SetBlendMode("ADD")
        glow:Hide()
        tab:Hide()
        tab:SetScript("OnClick", function() OpenFrame(view) end)
        tab:SetScript("OnEnter", function(sel)
            GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)

        tab:SetScript("OnLeave", GameTooltip_Hide)
        classicModeTabs[view] = tab
        classicModeTabGlows[view] = glow
        table.insert(classicModeTabOrder, view)
        return tab
    end

    local className, classToken = UnitClass("player")
    CreateClassicModeTab("TrainerSpellsSpellbookTab", "class", "Interface\\Icons\\INV_Misc_Book_09", className or TrainerSpells:Trans("LID_CLASSTRAINER"))
    if TrainerSpells:HasPetClassData(classToken) then CreateClassicModeTab("TrainerSpellsPetSpellbookTab", "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", TrainerSpells:Trans("LID_PETTRAINING")) end
    if TrainerSpells.BuildClassTrainerItems then CreateClassicModeTab("TrainerSpellsClassTrainerMapTab", "trainers", 134269, TrainerSpells:Trans("LID_CLASSTRAINERS")) end
    if TrainerSpells.BuildWeaponSkillItems then CreateClassicModeTab("TrainerSpellsWeaponSpellbookTab", "weapons", "Interface\\Icons\\INV_Sword_04", TrainerSpells:Trans("LID_WEAPONSKILLS")) end
    local function IsClassicModeTabEnabled(view)
        return TrainerSpells:IsTabEnabled("spellbook") and TrainerSpells:IsTabEnabled(view)
    end

    local ownTabs = {}
    local function IsAnchoredToOwnTabs(frame, depth)
        if not frame or depth > 10 then return false end
        if ownTabs[frame] then return true end
        if not frame.GetNumPoints then return false end
        for index = 1, frame:GetNumPoints() do
            local _, relativeTo = frame:GetPoint(index)
            if relativeTo and relativeTo ~= SpellBookFrame and IsAnchoredToOwnTabs(relativeTo, depth + 1) then return true end
        end
        return false
    end

    local function FindForeignSideTab()
        local reference = _G["SpellBookSkillLineTab1"]
        local refLeft = reference and reference:GetLeft()
        local floor = lastTab ~= SpellBookFrame and lastTab:GetBottom() or reference and reference:GetBottom()
        if not refLeft or not floor then return nil end
        local found, foundBottom = nil, floor
        for _, child in ipairs({SpellBookFrame:GetChildren()}) do
            if not ownTabs[child] and child:IsShown() and child:IsObjectType("Button") then
                local left, bottom, width, height = child:GetLeft(), child:GetBottom(), child:GetWidth(), child:GetHeight()
                if left and bottom and math.abs(left - refLeft) <= 8 and width <= 48 and height <= 48 and bottom < foundBottom and not IsAnchoredToOwnTabs(child, 0) then found, foundBottom = child, bottom end
            end
        end
        return found
    end

    local function SetTabSide(tab, leftSide)
        local border = tab.tsBorder
        border:ClearAllPoints()
        if leftSide then
            border:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 3, 11)
            border:SetTexCoord(1, 0, 0, 1)
        else
            border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
            border:SetTexCoord(0, 1, 0, 1)
        end
    end

    local function NeedsLeftSide(foreignTab, count)
        local frameBottom = SpellBookFrame:GetBottom()
        local startTop = foreignTab and foreignTab:GetBottom() and foreignTab:GetBottom() - 16 or lastTab ~= SpellBookFrame and lastTab:GetBottom()
        if count == 0 or not frameBottom or not startTop then return false end
        return startTop - count * 32 - (count - 1) * 16 < frameBottom + 16
    end

    local function ApplyClassicModeTabs()
        local previousTab = nil
        for _, tab in pairs(classicModeTabs) do ownTabs[tab] = true end
        local foreignTab = FindForeignSideTab()
        local count = 0
        for _, view in ipairs(classicModeTabOrder) do
            if IsClassicModeTabEnabled(view) then count = count + 1 end
        end
        local leftSide = NeedsLeftSide(foreignTab, count)
        local reference = _G["SpellBookSkillLineTab1"]
        local leftTop = reference and reference:GetTop() and SpellBookFrame:GetTop() and reference:GetTop() - SpellBookFrame:GetTop() or -65
        for _, view in ipairs(classicModeTabOrder) do
            local tab = classicModeTabs[view]
            local enabled = IsClassicModeTabEnabled(view)
            tab:ClearAllPoints()
            SetTabSide(tab, leftSide)
            if enabled then
                if previousTab then
                    tab:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -16)
                elseif leftSide then
                    tab:SetPoint("TOPRIGHT", SpellBookFrame, "TOPLEFT", 0, leftTop)
                elseif foreignTab then
                    tab:SetPoint("TOPLEFT", foreignTab, "BOTTOMLEFT", 0, -16)
                else
                    tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, 0)
                end

                previousTab = tab
            end

            tab:SetShown(enabled and SpellBookFrame:IsShown())
        end

        if classFrame:IsShown() and not classFrame.compendiumHost and not IsClassicModeTabEnabled(TrainerSpells.ClassView) then
            classFrame:Hide()
            ShowNativeSpellButtons()
            HideClassicModeTabGlows()
        end
    end

    ApplyClassicModeTabs()
    TrainerSpells:OnTabSettingsChanged(ApplyClassicModeTabs)
    SpellBookFrame:HookScript("OnShow", function()
        for view, tab in pairs(classicModeTabs) do
            tab:SetShown(IsClassicModeTabEnabled(view))
        end
        C_Timer.After(0, ApplyClassicModeTabs)
    end)

    if SpellBookFrame_UpdateSkillLineTabs then hooksecurefunc("SpellBookFrame_UpdateSkillLineTabs", function() C_Timer.After(0, ApplyClassicModeTabs) end) end

    SpellBookFrame:HookScript("OnHide", function()
        if classFrame.compendiumHost then return end
        for _, tab in pairs(classicModeTabs) do
            tab:Hide()
        end

        classFrame:Hide()
        ShowNativeSpellButtons()
        HideClassicModeTabGlows()
    end)

    local function OnNativeTabClicked()
        if classFrame.compendiumHost then return end
        if classFrame:IsShown() then
            classFrame:Hide()
            ShowNativeSpellButtons()
            HideClassicModeTabGlows()
        end
    end

    for i = 1, 8 do
        local t = _G["SpellBookSkillLineTab" .. i]
        if t then t:HookScript("OnClick", OnNativeTabClicked) end
    end

    for i = 1, 3 do
        local t = _G["SpellBookFrameTabButton" .. i]
        if t then t:HookScript("OnClick", OnNativeTabClicked) end
    end

    C_Timer.After(4, function()
        for i = 1, 4 do
            local t = _G["DragonflightUISpellBookFrameTabButton" .. i]
            if t then t:HookScript("OnClick", OnNativeTabClicked) end
        end
    end)
end

local playerSpellsModeTabs = {}
local playerSpellsModeTabContainer
local playerSpellsModeDivider
local playerSpellsModeLastTab
local playerSpellsContentHidden = false
local playerSpellsSubTabs = {}
function playerSpellsSubTabs.GetSavedView()
    local saved = TrainerSpells_Character and TrainerSpells_Character.classView
    for _, entry in ipairs(playerSpellsSubTabs.views or {}) do
        if entry.view == saved then return saved end
    end
    return playerSpellsSubTabs.views and playerSpellsSubTabs.views[1] and playerSpellsSubTabs.views[1].view or "class"
end

function playerSpellsSubTabs.Update()
    if not playerSpellsSubTabs.bar then return end
    for index, entry in ipairs(playerSpellsSubTabs.allViews) do
        if entry.view == TrainerSpells.ClassView then
            playerSpellsSubTabs.bar:SetTabVisuallySelected(index)
            playerSpellsSubTabs.title:SetText(entry.title)
            playerSpellsSubTabs.desc:SetText(TrainerSpells:Trans(entry.desc))
        end
    end
end

local function GetPlayerSpellsBook()
    return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
end

local function GetMaxDescendantFrameLevel(frame)
    local level = frame:GetFrameLevel()
    for _, child in ipairs({frame:GetChildren()}) do
        level = math.max(level, GetMaxDescendantFrameLevel(child))
    end
    return level
end

local function PositionPlayerSpellsFrame()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    local book = GetPlayerSpellsBook()
    if not book then return end
    local content = book.PagedSpellsFrame or book
    local frameLevel = GetMaxDescendantFrameLevel(content)
    if playerSpellsModeTabContainer then frameLevel = math.max(frameLevel, playerSpellsModeTabContainer:GetFrameLevel()) end
    classFrame:SetParent(book)
    classFrame:SetFrameStrata(book:GetFrameStrata())
    classFrame:SetFrameLevel(frameLevel + 1)
    classFrame:ClearAllPoints()
    classFrame:SetScale(1)
    classFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -50)
    classFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, -8)
    listBg:ClearAllPoints()
    listBg:Hide()
    local showWeaponControls = TrainerSpells.ClassView == "weapons" and TrainerSpells.WeaponControls
    local showClassTrainerControls = TrainerSpells.ClassView == "trainers" and TrainerSpells.ClassTrainerControls
    local panel = playerSpellsSubTabs.panel
    local showSpoilerFree = panel and TrainerSpells.ClassView == "class"
    local anchor, left, right, top = classFrame, 48, -100, -2
    if panel then
        local tabsLayout = playerSpellsSubTabs.IsTabsLayout()
        panel:Show()
        playerSpellsSubTabs.bar:SetShown(not tabsLayout)
        playerSpellsSubTabs.title:Show()
        playerSpellsSubTabs.desc:Show()
        anchor, left, right, top = panel, 8, -90, -8
        panel:ClearAllPoints()
        if content.View1 then
            panel:SetPoint("TOPLEFT", content.View1, "TOPLEFT", -37, -46)
            panel:SetPoint("BOTTOMRIGHT", content.View1, "BOTTOMRIGHT", 0, 4)
        else
            panel:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 44, -61)
            panel:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -10, 24)
        end

        local bar, slider = playerSpellsSubTabs.bar, TrainerSpells.RowHeightSlider
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 33, 3)
        local sliderScale = slider:GetScale()
        slider:ClearAllPoints()
        slider:SetPoint("RIGHT", panel, "TOPRIGHT", -86 / sliderScale, 16 / sliderScale)
        slider:SetWidth(168 / sliderScale)
        local spoilerFree = playerSpellsSubTabs.spoilerFree
        spoilerFree:ClearAllPoints()
        spoilerFree:SetPoint("TOPLEFT", panel, "TOPLEFT", left, top)
        spoilerFree:SetChecked(TrainerSpells_Character.spoilerFree and true or false)
        spoilerFree:SetShown(showSpoilerFree)
        playerSpellsSubTabs.title:ClearAllPoints()
        playerSpellsSubTabs.title:SetPoint("TOPLEFT", bar, tabsLayout and "TOPLEFT" or "TOPRIGHT", tabsLayout and 0 or 12, 0)
        playerSpellsSubTabs.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -266, 35)
        playerSpellsSubTabs.desc:ClearAllPoints()
        playerSpellsSubTabs.desc:SetPoint("TOPLEFT", playerSpellsSubTabs.title, "BOTTOMLEFT", 0, -3)
        playerSpellsSubTabs.desc:SetPoint("TOPRIGHT", playerSpellsSubTabs.title, "BOTTOMRIGHT", 0, -3)
    end

    for _, controls in ipairs({TrainerSpells.WeaponControls or false, TrainerSpells.ClassTrainerControls or false}) do
        if controls then
            controls:ClearAllPoints()
            controls:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
            controls:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", right, top)
        end
    end

    if TrainerSpells.WeaponControls then TrainerSpells.WeaponControls:SetShown(showWeaponControls and true or false) end
    if TrainerSpells.ClassTrainerControls then TrainerSpells.ClassTrainerControls:SetShown(showClassTrainerControls and true or false) end
    local dividerOffset = top + 1 + (showClassTrainerControls and -42 or showWeaponControls and -34 or showSpoilerFree and -26 or 0)
    if playerSpellsModeDivider then
        playerSpellsModeDivider:ClearAllPoints()
        if panel then
            playerSpellsModeDivider:GetParent():SetFrameLevel(playerSpellsSubTabs.bar:GetFrameLevel() + 10)
            playerSpellsModeDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, 6)
            playerSpellsModeDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -60, 6)
        else
            playerSpellsModeDivider:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, dividerOffset)
            playerSpellsModeDivider:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", right, dividerOffset)
        end

        playerSpellsModeDivider:Show()
    end

    if TrainerSpells.ClassScrollBox and playerSpellsModeDivider then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        if panel then
            local scrollBar = _G.TrainerSpellsScrollBar
            TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, dividerOffset - 13)
            TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 0)
            if scrollBar then
                scrollBar:ClearAllPoints()
                scrollBar:SetPoint("TOPLEFT", TrainerSpells.ClassScrollBox, "TOPRIGHT", 4, -2)
                scrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -18, 8)
            end
        else
            TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", playerSpellsModeDivider, "BOTTOMLEFT", 0, -2)
            TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -84, 30)
        end
    end

    searchBox:ClearAllPoints()
    if book.SearchBox then
        searchBox:SetPoint("LEFT", book.SearchBox, "LEFT")
        searchBox:SetPoint("RIGHT", book.SearchBox, "RIGHT")
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 60, 34)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, 34)
    end
end

local PLAYER_SPELLS_CONTENT_KEYS = {"PagedSpellsFrame", "SearchBox"}
local playerSpellsContentAlpha = {}
local playerSpellsContentBlocker
local function GetPlayerSpellsContentBlocker()
    if not playerSpellsContentBlocker then
        playerSpellsContentBlocker = TrainerSpells.CreateDetachedFrame("Frame", classFrame)
        playerSpellsContentBlocker:SetFrameLevel(classFrame:GetFrameLevel())
        playerSpellsContentBlocker:EnableMouse(true)
        playerSpellsContentBlocker:EnableMouseWheel(true)
        playerSpellsContentBlocker:SetScript("OnMouseWheel", function() end)
    end
    return playerSpellsContentBlocker
end

local function SetNativeCategoryTabsVisual(book, showSelection)
    local tabSystem = book and book.CategoryTabSystem
    if not tabSystem or not tabSystem.tabs then return end
    for _, tab in ipairs(tabSystem.tabs) do
        local isSelected = showSelection and tab.isSelected and true or false
        local active = tab.squareMode and {"SquareBackgroundActive", "SquareBackgroundActiveGlow"} or {"LeftActive", "MiddleActive", "RightActive"}
        local inactive = tab.squareMode and {"SquareBackground"} or {"Left", "Middle", "Right"}
        for _, key in ipairs(active) do
            if tab[key] then tab[key]:SetShown(isSelected) end
        end

        for _, key in ipairs(inactive) do
            if tab[key] then tab[key]:SetShown(not isSelected) end
        end

        tab:SetNormalFontObject(isSelected and (tab.selectedFontObject or GameFontHighlightSmall) or (tab.unselectedFontObject or GameFontNormalSmall))
        if not (SmartNavigation and SmartNavigation:GetCurrentButton() == tab) then tab:SetEnabled(not isSelected and not (tab.IsForceDisabled and tab:IsForceDisabled())) end
        if tab.Text and tab.GetTextYOffset then tab.Text:SetPoint("CENTER", tab, "CENTER", 0, tab:GetTextYOffset(isSelected)) end
        if tab.Icon and tab.GetIconYOffset then tab.Icon:SetPoint("CENTER", tab, "CENTER", 0, tab:GetIconYOffset(isSelected)) end
    end
end

playerSpellsSubTabs.detachedNativeButtons = {}
function playerSpellsSubTabs.DetachNativeButton(button)
    if not button or not button:IsRectValid() then return end
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == button then GameTooltip:Hide() end
    local detached = playerSpellsSubTabs.detachedNativeButtons
    if not detached[button] then
        local points = {}
        for index = 1, button:GetNumPoints() do
            points[index] = {button:GetPoint(index)}
        end

        detached[button] = points
    end

    button:ClearAllPoints()
end

function playerSpellsSubTabs.DetachNativeButtons(book)
    local paged = book and book.PagedSpellsFrame
    if not paged then return end
    for _, view in ipairs(paged.ViewFrames or {}) do
        for _, item in ipairs({view:GetChildren()}) do
            playerSpellsSubTabs.DetachNativeButton(item.Button)
        end
    end

    local controls = paged.PagingControls
    if controls then
        playerSpellsSubTabs.DetachNativeButton(controls.PrevPageButton)
        playerSpellsSubTabs.DetachNativeButton(controls.NextPageButton)
    end
end

function playerSpellsSubTabs.RestoreNativeButtons()
    local detached = playerSpellsSubTabs.detachedNativeButtons
    if not next(detached) then return end
    for button, points in pairs(detached) do
        button:ClearAllPoints()
        for _, point in ipairs(points) do
            button:SetPoint(unpack(point))
        end
    end

    wipe(detached)
end

local function HidePlayerSpellsContent()
    if classFrame.compendiumHost then return end
    local book = GetPlayerSpellsBook()
    if playerSpellsContentHidden or not book then return end
    playerSpellsContentHidden = true
    for _, key in ipairs(PLAYER_SPELLS_CONTENT_KEYS) do
        local content = book[key]
        if content then
            playerSpellsContentAlpha[content] = content:GetAlpha()
            content:SetAlpha(0)
        end
    end

    if book.PagedSpellsFrame then
        local blocker = GetPlayerSpellsContentBlocker()
        blocker:SetFrameLevel(classFrame:GetFrameLevel())
        blocker:ClearAllPoints()
        blocker:SetAllPoints(book.PagedSpellsFrame)
        blocker:Show()
    end
end

local function ShowPlayerSpellsContent()
    playerSpellsSubTabs.RestoreNativeButtons()
    if not playerSpellsContentHidden then return end
    playerSpellsContentHidden = false
    if playerSpellsContentBlocker then playerSpellsContentBlocker:Hide() end
    for content, alpha in pairs(playerSpellsContentAlpha) do
        content:SetAlpha(alpha)
    end

    wipe(playerSpellsContentAlpha)
end

local function ClosePlayerSpellsPanel()
    if classFrame.compendiumHost then ShowPlayerSpellsContent(); SetNativeCategoryTabsVisual(GetPlayerSpellsBook(), true); return end
    local wasOpen = playerSpellsContentHidden
    classFrame:Hide()
    ShowPlayerSpellsContent()
    for _, tab in pairs(playerSpellsModeTabs) do
        tab:SetTabSelected(false)
    end

    for _, tab in ipairs(playerSpellsSubTabs.viewTabs or {}) do
        tab:SetTabSelected(false)
    end

    if wasOpen then SetNativeCategoryTabsVisual(GetPlayerSpellsBook(), true) end
end

local function OpenPlayerSpellsPanel()
    if classFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(classFrame) end
    local book = GetPlayerSpellsBook()
    if not book then return end
    PositionPlayerSpellsFrame()
    HidePlayerSpellsContent()
    TrainerSpells.RunDetached(classFrame, function() classFrame:Show() end)
    TrainerSpells:PrepareGamepadNavigation(classFrame)
    SetNativeCategoryTabsVisual(book, false)
    TrainerSpells:UpdateClassViewTabs()
end

function TrainerSpells:UpdateClassViewTabs()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    for view, glow in pairs(classicModeTabGlows) do
        glow:SetShown(classFrame:IsShown() and TrainerSpells.ClassView == view)
    end

    if playerSpellsModeTabs.addon then playerSpellsModeTabs.addon:SetTabSelected(classFrame:IsShown()) end
    for _, tab in ipairs(playerSpellsSubTabs.viewTabs or {}) do
        tab:SetTabSelected(classFrame:IsShown() and TrainerSpells.ClassView == tab.view)
    end

    playerSpellsSubTabs.Update()
end

function playerSpellsSubTabs.KeepTabEnabled()
end

function playerSpellsSubTabs.SetClassIcon(icon, classToken)
    local classAtlas = GetClassAtlas and GetClassAtlas(classToken)
    if icon and classAtlas then
        icon:SetAtlas(classAtlas)
    elseif icon and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken] then
        local coords = CLASS_ICON_TCOORDS[classToken]
        icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

function playerSpellsSubTabs.BuildViews()
    if playerSpellsSubTabs.allViews then return playerSpellsSubTabs.allViews end
    local className, classToken = UnitClass("player")
    local views = {
        {
            view = "class",
            icon = TrainerSpells:GetAddonIcon(),
            title = className,
            desc = "LID_CLASSVIEW_DESC",
            classToken = classToken
        }
    }

    if TrainerSpells:HasPetClassData(classToken) then
        table.insert(views, {
            view = "pet",
            icon = "Interface\\Icons\\Ability_Hunter_BeastCall",
            title = TrainerSpells:Trans("LID_PETTRAINING"),
            desc = "LID_PETVIEW_DESC"
        })
    end

    table.insert(views, {
        view = "trainers",
        icon = 134269,
        title = TrainerSpells:Trans("LID_CLASSTRAINERS"),
        desc = "LID_TRAINERSVIEW_DESC"
    })

    table.insert(views, {
        view = "weapons",
        icon = "Interface\\Icons\\INV_Sword_04",
        title = TrainerSpells:Trans("LID_WEAPONSKILLS"),
        desc = "LID_WEAPONVIEW_DESC"
    })

    playerSpellsSubTabs.allViews = views
    playerSpellsSubTabs.views = TrainerSpells:FilterTabViews(views)
    return views
end

function playerSpellsSubTabs.Create()
    if playerSpellsSubTabs.bar then return end
    local views = playerSpellsSubTabs.BuildViews()
    local bar = CreateFrame("Frame", "TrainerSpellsPlayerSpellsSubTabs", classFrame, "TabSystemTemplate")
    bar:SetTabSelectedCallback(function(tabID)
        local entry = views[tabID]
        if entry then
            TrainerSpells:SetClassView(entry.view)
            OpenPlayerSpellsPanel()
        end
        return true
    end)

    for index, entry in ipairs(views) do
        bar:AddTab(nil, entry.icon)
        local button = bar:GetTabButton(index)
        button.SetEnabled = playerSpellsSubTabs.KeepTabEnabled
        button:Enable()
        button:SetTooltipText(entry.title .. "\n|cffffffff" .. TrainerSpells:Trans(entry.desc) .. "|r")
        if entry.classToken then playerSpellsSubTabs.SetClassIcon(button.Icon, entry.classToken) end
    end

    bar:Layout()
    local panel = CreateFrame("Frame", nil, classFrame)
    playerSpellsSubTabs.panel = panel
    local title = classFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local desc = classFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(false)
    desc:SetTextColor(0.75, 0.75, 0.75)
    local titleButton = TrainerSpells.CreateDetachedFrame("Button", classFrame)
    titleButton:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
    titleButton:SetPoint("BOTTOMRIGHT", desc, "BOTTOMRIGHT", 0, 0)
    titleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, self:GetHeight())
        GameTooltip:SetText(title:GetText() or "")
        GameTooltip:AddLine(desc:GetText() or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    titleButton:SetScript("OnLeave", GameTooltip_Hide)
    playerSpellsSubTabs.spoilerFree = TrainerSpells:CreateSpoilerFreeCheckbox(classFrame, "spoilerFree", "LID_SPOILERFREE_DESC", TrainerSpells_Refresh)
    playerSpellsSubTabs.title = title
    playerSpellsSubTabs.desc = desc
    playerSpellsSubTabs.bar = bar
    playerSpellsSubTabs.ApplySettings()
end

function playerSpellsSubTabs.ApplySettings()
    if playerSpellsModeTabContainer then
        local enabled = TrainerSpells:IsTabEnabled("spellbook") and TrainerSpells:HasSpellbookTabs()
        playerSpellsModeTabContainer:SetShown(enabled)
        local nextIcon = playerSpellsSubTabs.nextIcon
        if enabled then
            playerSpellsSubTabs.LayoutModeTabs()
        elseif nextIcon and playerSpellsSubTabs.nextIconPoints then
            nextIcon:ClearAllPoints()
            for _, point in ipairs(playerSpellsSubTabs.nextIconPoints) do nextIcon:SetPoint(unpack(point)) end
        end
        if playerSpellsSubTabs.QueueFit then playerSpellsSubTabs.QueueFit() end
        if not enabled and classFrame:IsShown() and not classFrame.compendiumHost then ClosePlayerSpellsPanel() end
    end

    if not playerSpellsSubTabs.allViews then return end
    playerSpellsSubTabs.views = TrainerSpells:FilterTabViews(playerSpellsSubTabs.allViews)
    if playerSpellsSubTabs.bar then
        for index, entry in ipairs(playerSpellsSubTabs.allViews) do
            playerSpellsSubTabs.bar:SetTabShown(index, TrainerSpells:IsTabEnabled(entry.view))
        end
    end

    local first = playerSpellsSubTabs.views[1]
    local panelOpen = playerSpellsModeTabContainer and classFrame:IsShown() and not classFrame.compendiumHost
    if first and not TrainerSpells:IsTabEnabled(TrainerSpells.ClassView or "") then
        TrainerSpells:SetClassView(first.view)
        if panelOpen then OpenPlayerSpellsPanel() end
    elseif not first and panelOpen then
        ClosePlayerSpellsPanel()
    end
    if playerSpellsModeTabContainer and classFrame:IsShown() and not classFrame.compendiumHost then PositionPlayerSpellsFrame() end
    TrainerSpells:UpdateClassViewTabs()
end

TrainerSpells:OnTabSettingsChanged(playerSpellsSubTabs.ApplySettings)

local function CreatePlayerSpellsModeTabs(book, tabSystem)
    local container = CreateFrame("Frame", "TrainerSpellsPlayerSpellsModeTabs", UIParent)
    playerSpellsModeTabContainer = container
    container:SetSize(48, 32)
    container:SetPoint("LEFT", tabSystem, "RIGHT", 8, 0)
    local dividerFrame = CreateFrame("Frame", nil, classFrame)
    dividerFrame:SetAllPoints(classFrame)
    local divider = dividerFrame:CreateTexture(nil, "OVERLAY")
    playerSpellsModeDivider = divider
    divider:SetAtlas("spellbook-divider")
    divider:SetHeight(11)
    local tab = CreateFrame("Button", nil, container, "TabSystemButtonTemplate")
    tab.GetTabSystem = function() return tabSystem end
    tab:Init(1, nil, TrainerSpells:GetAddonIcon())
    tab.SetEnabled = playerSpellsSubTabs.KeepTabEnabled
    tab:Enable()
    tab:SetTooltipText("TrainerSpells")
    tab:SetPoint("LEFT", container, "LEFT", 0, 0)
    tab:SetScript("OnClick", function()
        TrainerSpells:SetClassView(playerSpellsSubTabs.GetSavedView())
        OpenPlayerSpellsPanel()
    end)

    playerSpellsModeTabs.addon = tab
    playerSpellsModeLastTab = tab
    playerSpellsSubTabs.Create()
    playerSpellsSubTabs.viewTabs = {}
    for index, entry in ipairs(playerSpellsSubTabs.allViews) do
        local viewTab = CreateFrame("Button", nil, container, "TabSystemButtonTemplate")
        viewTab.GetTabSystem = function() return tabSystem end
        viewTab:Init(100 + index, nil, entry.icon)
        viewTab.SetEnabled = playerSpellsSubTabs.KeepTabEnabled
        viewTab:Enable()
        viewTab:SetTooltipText(entry.title)
        if entry.classToken then playerSpellsSubTabs.SetClassIcon(viewTab.Icon, entry.classToken) end
        viewTab.view = entry.view
        viewTab:SetScript("OnClick", function()
            TrainerSpells:SetClassView(entry.view)
            OpenPlayerSpellsPanel()
        end)
        viewTab:Hide()
        table.insert(playerSpellsSubTabs.viewTabs, viewTab)
    end
    container:SetParent(book)
end

function playerSpellsSubTabs.IsTabsLayout()
    return TrainerSpells:GetTabLayout("spellbookLayout") == "tabs"
end

function playerSpellsSubTabs.LayoutModeTabs()
    local container = playerSpellsModeTabContainer
    if not container or not playerSpellsModeTabs.addon then return end
    local tabsLayout = playerSpellsSubTabs.IsTabsLayout()
    local last, width = nil, 0
    playerSpellsModeTabs.addon:SetShown(not tabsLayout)
    if not tabsLayout then
        last, width = playerSpellsModeTabs.addon, playerSpellsModeTabs.addon:GetWidth()
    end
    for _, viewTab in ipairs(playerSpellsSubTabs.viewTabs or {}) do
        local shown = tabsLayout and TrainerSpells:IsTabEnabled(viewTab.view)
        viewTab:SetShown(shown)
        viewTab:ClearAllPoints()
        if shown then
            if last then
                viewTab:SetPoint("LEFT", last, "RIGHT", 1, 0)
                width = width + 1
            else
                viewTab:SetPoint("LEFT", container, "LEFT", 0, 0)
            end
            width = width + viewTab:GetWidth()
            last = viewTab
        end
    end
    container:SetWidth(math.max(1, width))
    playerSpellsModeLastTab = last or playerSpellsModeTabs.addon
    local nextIcon = playerSpellsSubTabs.nextIcon
    if nextIcon and playerSpellsSubTabs.nextIconPoints and container:IsShown() then
        nextIcon:ClearAllPoints()
        nextIcon:SetPoint("TOPLEFT", playerSpellsModeLastTab, "TOPRIGHT", 0, 0)
    end
    if playerSpellsSubTabs.QueueFit then playerSpellsSubTabs.QueueFit() end
end

local function FitNativeSearchBox()
    local book = GetPlayerSpellsBook()
    local nativeSearchBox = book and book.SearchBox
    if not nativeSearchBox or not playerSpellsModeLastTab then return end
    if not playerSpellsSubTabs.searchPoints then
        local points = {}
        for index = 1, nativeSearchBox:GetNumPoints() do points[index] = {nativeSearchBox:GetPoint(index)} end
        playerSpellsSubTabs.searchPoints = points
    else
        nativeSearchBox:ClearAllPoints()
        for _, point in ipairs(playerSpellsSubTabs.searchPoints) do nativeSearchBox:SetPoint(unpack(point)) end
    end
    if not playerSpellsModeTabContainer or not playerSpellsModeTabContainer:IsShown() then
        if classFrame:IsShown() then PositionPlayerSpellsFrame() end
        return
    end
    local edge = book.NextCategoryIcon and book.NextCategoryIcon:IsShown() and book.NextCategoryIcon or playerSpellsModeLastTab
    local tabRight = edge:GetRight()
    local left, right, top = nativeSearchBox:GetLeft(), nativeSearchBox:GetRight(), nativeSearchBox:GetTop()
    local bookLeft, bookRight, bookTop = book:GetLeft(), book:GetRight(), book:GetTop()
    if not tabRight or not left or not right or not top or not bookLeft or not bookRight or not bookTop then return end
    tabRight = tabRight * edge:GetEffectiveScale() / book:GetEffectiveScale()
    if left >= tabRight + 8 or right <= tabRight + 60 then return end
    nativeSearchBox:ClearAllPoints()
    nativeSearchBox:SetPoint("TOPLEFT", book, "TOPLEFT", tabRight - bookLeft + 12, top - bookTop)
    nativeSearchBox:SetPoint("TOPRIGHT", book, "TOPRIGHT", right - bookRight, top - bookTop)
    if classFrame:IsShown() then PositionPlayerSpellsFrame() end
end

local function QueueFitNativeSearchBox()
    C_Timer.After(0, FitNativeSearchBox)
end
playerSpellsSubTabs.QueueFit = QueueFitNativeSearchBox

function playerSpellsSubTabs.SelectNextView(forward)
    for index, entry in ipairs(playerSpellsSubTabs.views or {}) do
        if entry.view == TrainerSpells.ClassView then
            local nextEntry = playerSpellsSubTabs.views[index + (forward and 1 or -1)]
            if nextEntry then
                TrainerSpells:SetClassView(nextEntry.view)
                OpenPlayerSpellsPanel()
            elseif not forward then
                ClosePlayerSpellsPanel()
            end

            return
        end
    end
end

function playerSpellsSubTabs.InstallGamepadCycling(book)
    if not book.GetTab or not IsKeyDown or not playerSpellsModeTabContainer then return end
    local leftButton = CreateFrame("Button", "TrainerSpellsSpellbookShoulderLeft", UIParent)
    leftButton:SetSize(1, 1)
    leftButton:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10, 10)
    leftButton:EnableMouse(false)
    leftButton:RegisterForClicks("AnyDown")
    local leftBinding = "CLICK TrainerSpellsSpellbookShoulderLeft:LeftButton"
    local leftBound = false
    local function UpdateLeftBinding()
        if InCombatLockdown() then return end
        local active = book:IsVisible() and playerSpellsModeTabContainer:IsShown() and classFrame:IsShown() and not classFrame.compendiumHost and playerSpellsSubTabs.IsTabsLayout()
        if active then
            if GetBindingAction("PADLSHOULDER", true) ~= leftBinding then SetOverrideBindingClick(leftButton, true, "PADLSHOULDER", leftButton:GetName(), "LeftButton") end
            leftBound = true
        elseif leftBound then
            ClearOverrideBindings(leftButton)
            leftBound = false
        end
    end

    leftButton:SetScript("OnClick", function()
        if book:IsVisible() and classFrame:IsShown() and not classFrame.compendiumHost and playerSpellsSubTabs.IsTabsLayout() then
            playerSpellsSubTabs.SelectNextView(false)
        end
        UpdateLeftBinding()
    end)
    classFrame:HookScript("OnShow", UpdateLeftBinding)
    classFrame:HookScript("OnHide", UpdateLeftBinding)
    playerSpellsModeTabContainer:RegisterEvent("PLAYER_REGEN_ENABLED")
    playerSpellsModeTabContainer:HookScript("OnEvent", UpdateLeftBinding)
    local focused, gamepadState, scrolledTo
    local function UpdateGamepadFocus()
        local gamepad = TrainerSpells.IsGamepadNavActive()
        if gamepad ~= gamepadState then
            gamepadState = gamepad
            TrainerSpells:PrepareGamepadNavigation(playerSpellsModeTabContainer, gamepad)
            TrainerSpells:PrepareGamepadNavigation(classFrame, gamepad)
            if TrainerSpells_Refresh then TrainerSpells_Refresh() end
        end

        if gamepad and classFrame:IsShown() and not classFrame.compendiumHost then
            playerSpellsSubTabs.DetachNativeButtons(book)
        else
            playerSpellsSubTabs.RestoreNativeButtons()
        end

        local current = gamepad and SmartNavigation:GetCurrentButton() or nil
        if current ~= scrolledTo then
            scrolledTo = current
            local row = current and current.tsRow
            if row and row.GetElementData and row:GetParent() == TrainerSpells.ClassScrollTarget then
                TrainerSpells.ClassScrollBox:ScrollToElementData(row:GetElementData(), ScrollBoxConstants.AlignNearest)
            end
        end

        if current and not current.tsFocusStripped then current = nil end
        if current == focused then return end
        if focused and focused.tsOnLeave then
            focused.tsOnLeave(focused)
        end

        focused = current
        if focused and focused.tsOnEnter then
            focused.tsOnEnter(focused)
        end
    end

    local function HandleShoulder(forward, tabBefore)
        if classFrame.compendiumHost or tabBefore == nil or not book:IsVisible() then return end
        local tabChanged = tabBefore ~= book:GetTab()
        if classFrame:IsShown() then
            if tabChanged then
                ClosePlayerSpellsPanel()
            else
                playerSpellsSubTabs.SelectNextView(forward)
            end
        elseif forward and not tabChanged then
            local first = playerSpellsSubTabs.IsTabsLayout() and playerSpellsSubTabs.views and playerSpellsSubTabs.views[1]
            TrainerSpells:SetClassView(first and first.view or playerSpellsSubTabs.GetSavedView())
            OpenPlayerSpellsPanel()
        end

    end

    local aHeld = false
    local function CheckAButton()
        local down = IsKeyDown("PAD1") and true or false
        if down and not aHeld and TrainerSpells.IsGamepadNavActive() then
            local current = SmartNavigation:GetCurrentButton()
            if current and current.tsGamepadClick and current:IsVisible() and (not current.IsEnabled or current:IsEnabled()) then
                TrainerSpells.SmartNavClick(current)
            end
        end
        aHeld = down
    end

    local held = {}
    local lastTab
    local function CheckShoulder(key, forward, tabBefore)
        local down = IsKeyDown(key) and true or false
        if down and not held[key] and (forward or not leftBound) then C_Timer.After(0.05, function() HandleShoulder(forward, tabBefore) end) end
        held[key] = down
    end

    playerSpellsModeTabContainer:HookScript("OnHide", function()
        UpdateLeftBinding()
        lastTab = nil
        wipe(held)
        if focused and focused.tsOnLeave then focused.tsOnLeave(focused) end
        focused = nil
    end)

    playerSpellsModeTabContainer:SetScript("OnUpdate", function()
        local tabBefore = lastTab
        lastTab = book:GetTab()
        if tabBefore and lastTab ~= tabBefore and classFrame:IsShown() and not classFrame.compendiumHost then
            ClosePlayerSpellsPanel()
        end
        UpdateLeftBinding()
        CheckShoulder("PADRSHOULDER", true, tabBefore)
        CheckShoulder("PADLSHOULDER", false, tabBefore)
        CheckAButton()
        UpdateGamepadFocus()
    end)

    local nextIcon = book.NextCategoryIcon
    if nextIcon and playerSpellsModeTabs.addon then
        local points = {}
        for index = 1, nextIcon:GetNumPoints() do points[index] = {nextIcon:GetPoint(index)} end
        playerSpellsSubTabs.nextIcon = nextIcon
        playerSpellsSubTabs.nextIconPoints = points
        nextIcon:ClearAllPoints()
        nextIcon:SetPoint("TOPLEFT", playerSpellsModeLastTab or playerSpellsModeTabs.addon, "TOPRIGHT", 0, 0)
        nextIcon:HookScript("OnShow", QueueFitNativeSearchBox)
        nextIcon:HookScript("OnHide", QueueFitNativeSearchBox)
    end
end

function playerSpellsSubTabs.PrewarmRows()
    if classFrame:IsShown() or classFrame.compendiumHost then return end
    PositionPlayerSpellsFrame()
    local rowHeight = TrainerSpells.RowHeight
    TrainerSpells.RowHeight = TrainerSpells.MinRowHeight
    TrainerSpells.ClassScrollBox:ClearAllPoints()
    TrainerSpells.ClassScrollBox:SetAllPoints(classFrame)
    local savedView = TrainerSpells.ClassView
    TrainerSpells.RunDetached(classFrame, function()
        classFrame:Show()
        for _, entry in ipairs(playerSpellsSubTabs.views or {}) do
            TrainerSpells.ClassView = entry.view
            TrainerSpells_Refresh()
        end
        classFrame:Hide()
    end)
    TrainerSpells.ClassView = savedView
    TrainerSpells.RowHeight = rowHeight
end

local function InstallPlayerSpellsIntegration()
    local book = GetPlayerSpellsBook()
    if playerSpellsModeTabContainer or not book then return end
    local tabSystem = book.CategoryTabSystem
    if not tabSystem then return end
    TrainerSpells.RunDetached(classFrame, function()
        CreatePlayerSpellsModeTabs(book, tabSystem)
    end)
    playerSpellsSubTabs.PrewarmRows()
    TrainerSpells:PrepareGamepadNavigation(playerSpellsModeTabContainer)
    TrainerSpells:PrepareGamepadNavigation(classFrame)
    book:HookScript("OnHide", ClosePlayerSpellsPanel)
    hooksecurefunc(tabSystem, "SetTab", ClosePlayerSpellsPanel)
    PlayerSpellsFrame:HookScript("OnHide", ClosePlayerSpellsPanel)
    book:HookScript("OnShow", QueueFitNativeSearchBox)
    book:HookScript("OnSizeChanged", QueueFitNativeSearchBox)
    playerSpellsSubTabs.InstallGamepadCycling(book)
    playerSpellsSubTabs.ApplySettings()
    if book:IsShown() then QueueFitNativeSearchBox() end
end

if not SpellBookFrame and TrainerSpells:HasClassTrainers() then
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        InstallPlayerSpellsIntegration()
    else
        local playerSpellsLoader = CreateFrame("Frame")
        playerSpellsLoader:RegisterEvent("ADDON_LOADED")
        playerSpellsLoader:SetScript("OnEvent", function(self, _, addonName)
            if addonName ~= "Blizzard_PlayerSpells" then return end
            self:UnregisterEvent("ADDON_LOADED")
            InstallPlayerSpellsIntegration()
        end)
    end
end

function TrainerSpells:DockCompendiumFrame(frame, host, widgets)
    local saved = {}
    for _, widget in ipairs(widgets) do
        local state = {widget = widget, parent = widget:GetParent(), shown = widget:IsShown(), points = {}}
        if widget.GetScale then state.scale = widget:GetScale() end
        if widget.GetFrameStrata then state.strata = widget:GetFrameStrata(); state.level = widget:GetFrameLevel() end
        for index = 1, widget:GetNumPoints() do state.points[index] = {widget:GetPoint(index)} end
        table.insert(saved, state)
    end
    frame.compendiumState = saved
    frame.compendiumHost = host
    frame:SetParent(host)
    frame:SetScale(1)
    frame:SetFrameStrata(host:GetFrameStrata())
    frame:SetFrameLevel(host:GetFrameLevel() + 2)
    frame:ClearAllPoints()
    frame:SetAllPoints(host)
end

function TrainerSpells:UndockCompendiumFrame(frame)
    if not frame.compendiumHost then return end
    frame:Hide()
    frame.compendiumHost = nil
    for _, state in ipairs(frame.compendiumState) do state.widget:ClearAllPoints() end
    for _, state in ipairs(frame.compendiumState) do
        local widget = state.widget
        widget:SetParent(state.parent)
        if state.scale then widget:SetScale(state.scale) end
        if state.strata then widget:SetFrameStrata(state.strata); widget:SetFrameLevel(state.level) end
        widget:ClearAllPoints()
        for _, point in ipairs(state.points) do widget:SetPoint(unpack(point)) end
        widget:SetShown(state.shown)
    end
    frame.compendiumState = nil
    frame:Hide()
end

function TrainerSpells:PositionCompendiumClass()
    local host = classFrame.compendiumHost
    if not host then return end
    local panel = playerSpellsSubTabs.panel
    panel:ClearAllPoints()
    panel:SetAllPoints(classFrame)
    for index, tab in ipairs(host.classTabs) do
        tab:SetTabSelected(tab.view == TrainerSpells.ClassView)
        AzerothCompendiumAPI.PositionContentTab(tab, host, host.classTabs[index - 1])
    end
    searchBox:Hide()
    AzerothCompendiumAPI.PositionHeaderSlider(TrainerSpells.RowHeightSlider)
    local offset = -4
    for _, entry in ipairs({{TrainerSpells.ClassTrainerControls, "trainers", -48}, {TrainerSpells.WeaponControls, "weapons", -40}}) do
        local controls = entry[1]
        if controls then
            controls:ClearAllPoints()
            controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
            controls:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
            controls:SetShown(TrainerSpells.ClassView == entry[2])
            if TrainerSpells.ClassView == entry[2] then offset = entry[3] end
        end
    end
    TrainerSpells.ClassScrollBox:ClearAllPoints()
    TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, offset)
    TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 0)
    local scrollBar = _G.TrainerSpellsScrollBar
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", TrainerSpells.ClassScrollBox, "TOPRIGHT", 4, -2)
    scrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -18, 8)
    listBg:Hide()
    if playerSpellsModeDivider then playerSpellsModeDivider:Hide() end
    panel:Show()
    playerSpellsSubTabs.bar:Hide()
    playerSpellsSubTabs.spoilerFree:Hide()
    playerSpellsSubTabs.title:ClearAllPoints()
    playerSpellsSubTabs.title:SetPoint("BOTTOMLEFT", host.classTabs[#host.classTabs], "BOTTOMRIGHT", 12, 17)
    playerSpellsSubTabs.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 17)
    playerSpellsSubTabs.desc:ClearAllPoints()
    playerSpellsSubTabs.desc:SetPoint("TOPLEFT", playerSpellsSubTabs.title, "BOTTOMLEFT", 0, -3)
    playerSpellsSubTabs.desc:SetPoint("TOPRIGHT", playerSpellsSubTabs.title, "BOTTOMRIGHT", 0, -3)
    playerSpellsSubTabs.title:Show()
    playerSpellsSubTabs.desc:Show()
    playerSpellsSubTabs.Update()
end

function TrainerSpells:CreateCompendiumListView(host, entries, mode, rowHeight, isEntryVisible)
    local view = {host = host, mode = mode, rowHeight = rowHeight, tabs = {}, entries = entries, isEntryVisible = isEntryVisible}
    function view:IsEntryVisible(index)
        return not self.isEntryVisible or self.isEntryVisible(self.entries[index])
    end
    function view:LayoutTabs()
        local previous = nil
        for index, tab in ipairs(self.tabs) do
            local shown = self:IsEntryVisible(index)
            tab:SetShown(shown)
            if shown then
                AzerothCompendiumAPI.PositionContentTab(tab, host, previous)
                previous = tab
            end
        end
        if previous then self.title:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 12, 17) end
    end
    function view:EnsureVisibleMode()
        local first = nil
        for index, tab in ipairs(self.tabs) do
            if self:IsEntryVisible(index) then
                if tab.mode == self.mode then return end
                first = first or tab.mode
            end
        end
        if first then self.mode = first end
    end
    function view:ApplyVisibility()
        self:LayoutTabs()
        self:EnsureVisibleMode()
        if host:IsShown() then self:Refresh() end
    end
    function view:TranslateTitle(text)
        if type(text) == "string" and text:find("LID_", 1, true) == 1 then return TrainerSpells:Trans(text) end
        return text
    end
    view.title = host:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    view.title:SetJustifyH("LEFT")
    view.title:SetWordWrap(false)
    view.desc = host:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    view.desc:SetJustifyH("LEFT")
    view.desc:SetWordWrap(false)
    view.desc:SetTextColor(0.75, 0.75, 0.75)
    view.desc:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -3)
    view.desc:SetPoint("TOPRIGHT", view.title, "BOTTOMRIGHT", 0, -3)
    for _, entry in ipairs(entries) do
        local tab = AzerothCompendiumAPI.CreateContentTab(host, view:TranslateTitle(entry.title), entry.icon, function() view.mode = entry.mode or entry.view; view:Refresh() end)
        tab.mode = entry.mode or entry.view
        if entry.classToken then playerSpellsSubTabs.SetClassIcon(tab.Icon, entry.classToken) end
        tab:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(view:TranslateTitle(entry.title))
            GameTooltip:AddLine(TrainerSpells:Trans(entry.desc), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        table.insert(view.tabs, tab)
    end
    view:LayoutTabs()
    view:EnsureVisibleMode()
    view.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 17)
    view.scrollBox = CreateFrame("Frame", nil, host, "WowScrollBoxList")
    view.scrollBox:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    view.scrollBox:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -24, 0)
    view.scrollBar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    view.scrollBar:SetPoint("TOPLEFT", view.scrollBox, "TOPRIGHT", 4, -2)
    view.scrollBar:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", -20, 8)
    local list = CreateScrollBoxListLinearView()
    list:SetElementExtentCalculator(function(_, item) return item.isHeader and TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap or view.rowHeight end)
    list:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
    list:SetElementInitializer("Frame", function(row, item)
        TrainerSpells:InitScrollRow(row, item, view.rowHeight)
        TrainerSpells:ApplyRowStripe(row, item)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(view.scrollBox, view.scrollBar, list)
    TrainerSpells:AddContentBorder(host)
    host.borderFrame:SetFrameLevel(view.scrollBox:GetFrameLevel() + 20)
    host.borderFrame:EnableMouse(false)
    view.scrollBar:SetFrameLevel(host.borderFrame:GetFrameLevel() + 1)
    view.slider = CreateFrame("Slider", nil, host, "MinimalSliderWithSteppersTemplate")
    view.slider:SetScale(0.75)
    view.slider:SetHeight(10)
    view.slider:Init(rowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
    })
    if view.slider.MinText then view.slider.MinText:Hide() end
    if view.slider.MaxText then view.slider.MaxText:Hide() end
    view.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value) view.rowHeight = math.floor(value + 0.5); if view.BuildItems then view:Refresh() end end)
    function view:AddSpoilerFreeCheckbox(settingKey, descKey, onlyMode)
        self.spoilerFree = TrainerSpells:CreateSpoilerFreeCheckbox(host, settingKey, descKey, function() self:Refresh() end)
        self.spoilerFree:SetPoint("LEFT", self.slider, "RIGHT", 30, 0)
        self.spoilerFreeMode = onlyMode
    end
    function view:Refresh()
        self:EnsureVisibleMode()
        for index, tab in ipairs(self.tabs) do
            tab:SetTabSelected(tab.mode == self.mode)
            if tab.mode == self.mode then
                self.title:SetText(self:TranslateTitle(self.entries[index].title))
                self.desc:SetText(TrainerSpells:Trans(self.entries[index].desc))
            end
        end
        if self.spoilerFree and self.spoilerFreeMode then self.spoilerFree:SetShown(self.mode == self.spoilerFreeMode) end
        local offset = -4
        for _, control in ipairs(self.controls or {}) do
            local active = control.mode == self.mode
            control.frame:SetShown(active)
            if active then offset = -control.height end
        end
        self.scrollBox:ClearAllPoints()
        self.scrollBox:SetPoint("TOPLEFT", host, "TOPLEFT", 0, offset)
        self.scrollBox:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -24, 0)
        if self.BuildItems then self.scrollBox:SetDataProvider(CreateDataProvider(self:BuildItems()), ScrollBoxConstants.RetainScrollPosition) end
    end
    host.OnSearchChanged = function() view:Refresh() end
    host:SetScript("OnSizeChanged", function()
        AzerothCompendiumAPI.PositionHeaderSlider(view.slider)
        view:LayoutTabs()
    end)
    AzerothCompendiumAPI.PositionHeaderSlider(view.slider)
    host:RegisterEvent("PLAYER_LEVEL_UP")
    host:RegisterEvent("SPELLS_CHANGED")
    host:RegisterEvent("PLAYER_MONEY")
    if TrainerSpells.TrainerLocations then TrainerSpells.TrainerLocations.AddResolveListener(function() if host:IsShown() then view:Refresh() end end) end
    host:SetScript("OnEvent", function() if host:IsShown() then view:Refresh() end end)
    return view
end

function TrainerSpells:CreateCompendiumClass(host)
    playerSpellsSubTabs.BuildViews()
    local view = self:CreateCompendiumListView(host, playerSpellsSubTabs.allViews, playerSpellsSubTabs.GetSavedView(), self.RowHeight, function(entry) return TrainerSpells:IsTabEnabled(entry.view) end)
    self.CompendiumClassView = view
    view.BuildItems = function(current) return TrainerSpells:BuildClassViewItems(current.mode, host.searchText) end
    view:AddSpoilerFreeCheckbox("spoilerFree", "LID_SPOILERFREE_DESC", "class")
    view.controls = {}
    for _, entry in ipairs({{self.CreateClassTrainerControls, "trainers", 48}, {self.CreateWeaponControls, "weapons", 40}}) do
        if entry[1] then
            local controls = entry[1](self, host)
            local top = -(entry[3] - controls:GetHeight()) / 2 - 4
            controls:SetPoint("TOPLEFT", host, "TOPLEFT", 4, top)
            controls:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, top)
            table.insert(view.controls, {frame = controls, mode = entry[2], height = entry[3]})
        end
    end
    host:SetScript("OnShow", function() view:Refresh() end)
end
function TrainerSpells:RegisterCompendiumTabs()
    local api = _G["AzerothCompendiumAPI"]
    if not self.SettingsReady or type(api) ~= "table" or type(api.RegisterTab) ~= "function" then return end
    if self:IsTabEnabled("compendium_professions") and self:HasProfessionTabs() then
        api.RegisterTab("TrainerSpells:professions", {
            label = function() return TrainerSpells:Trans("LID_PROFESSIONS") end,
            icon = 134708,
            insertBefore = "wishlist",
            createPanel = function(host) TrainerSpells:CreateCompendiumProfessions(host) end
        })
    elseif type(api.UnregisterTab) == "function" then
        api.UnregisterTab("TrainerSpells:professions")
    end
    if self:HasClassTrainers() and self:IsTabEnabled("compendium_class") and self:HasSpellbookTabs() then
        api.RegisterTab("TrainerSpells:class", {
            label = function() return _G.CLASSES or (GetLocale() == "deDE" and "Klassen") or "Classes" end,
            icon = 133743,
            insertBefore = "wishlist",
            createPanel = function(host) TrainerSpells:CreateCompendiumClass(host) end
        })
    elseif type(api.UnregisterTab) == "function" then
        api.UnregisterTab("TrainerSpells:class")
    end
    if self.CompendiumClassView and self.CompendiumClassView.ApplyVisibility then self.CompendiumClassView:ApplyVisibility() end
    if self.CompendiumProfessionView and self.CompendiumProfessionView.ApplyVisibility then self.CompendiumProfessionView:ApplyVisibility() end
end

TrainerSpells.CompendiumLoader = CreateFrame("Frame")
TrainerSpells.CompendiumLoader:RegisterEvent("ADDON_LOADED")
TrainerSpells.CompendiumLoader:RegisterEvent("PLAYER_LOGIN")
TrainerSpells.CompendiumLoader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0, function() TrainerSpells:RegisterCompendiumTabs() end)
    elseif name == "AzerothCompendium" then
        TrainerSpells:RegisterCompendiumTabs()
    end
end)
TrainerSpells:RegisterCompendiumTabs()
