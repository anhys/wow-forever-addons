-- TBCBisTracker UI
-- Full UI: class/spec picker, phase tabs, gear rows with checkboxes, progress bar

TBCBisTracker = TBCBisTracker or {}
local addon = TBCBisTracker

addon.UI = {}
local UI = addon.UI

-- Newer clients (WoW Forever) only ship this under C_Item.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- Re-fire the current tooltip's owner OnEnter when shift state changes,
-- so pressing/releasing Shift mid-hover toggles the side-by-side comparison.
local modWatcher = CreateFrame("Frame")
modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modWatcher:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    if not owner then return end
    if not (owner.itemId and owner.itemId > 0) and not (owner.GetParent and owner:GetParent() == DropDownList1) then
        return
    end
    local handler = owner:GetScript("OnEnter")
    if handler then handler(owner) end
end)

-- ─────────────────────────────────────────────
-- Layout constants
-- ─────────────────────────────────────────────
-- LIST_W is the width of the gear-list / filters / footer area on the left.
-- STAT_AREA_W is the width of the stat-cap column on the right inside the
-- same window. FRAME_W is the total window width.
local LIST_W       = 760
local STAT_AREA_W  = 230
local FRAME_W      = LIST_W + STAT_AREA_W
local FRAME_H      = 640
local PHASE_TAB_H  = 24
local PROGRESS_H   = 18
local ROW_H        = 34
local ROW_PAD      = 2
local SCROLL_W     = LIST_W - 52   -- leaves room for the slim scrollbar
local COL_ICON_W   = 28
local COL_SLOT_W   = 70
local COL_ITEM_W   = 340
local COL_SRC_W    = 200
local COL_CHK_W    = 40

-- Vertical layout (offsets from the top of the window).
local ROW_A_Y      = -30   -- class dropdown, spec tabs, stage chip
local ROW_B_Y      = -62   -- source filter, missing only, export/import
local TABS_Y       = -92   -- phase tabs (only when there's more than one phase)
local BANNER_H     = 26
-- Space kept under the list: progress footer, plus badge/tier lines on TBC.
local LIST_BOTTOM_FOREVER = 44
local LIST_BOTTOM_TBC     = 80

local CLASS_ORDER = {
    "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
    "SHAMAN","MAGE","WARLOCK","DRUID",
}

local SOURCE_TYPE_COLORS = {
    crafted    = "|cff00ff96",
    heroic     = "|cff40c0ff",
    raid       = "|cffa335ee",
    reputation = "|cffffd700",
    pvp        = "|cffff4040",
    world      = "|cffaaaaaa",
    quest      = "|cffff9900",
    dungeon    = "|cff7fb2ff",
}

-- Short labels shown in the Source column. Full source description is
-- still preserved on `entry.source` and shown via tooltip on hover.
local SOURCE_TYPE_LABELS = {
    crafted    = "Profession",
    heroic     = "Dungeon HC",
    raid       = "Raid",
    reputation = "Reputation",
    pvp        = "PvP",
    world      = "World",
    quest      = "Quest",
    dungeon    = "Dungeon",
}

-- ─────────────────────────────────────────────
-- Central UI palette  — keep all visual constants here so the addon
-- has a predictable, consistent look. If you need a new color or
-- spacing value, add it here rather than inline.
-- ─────────────────────────────────────────────
local UI_PAL = {
    -- Text colors (escaped color codes for inline use)
    accent      = "|cffffd700", -- gold — headers, BiS markers, quest indicator
    accentSoft  = "|cffd6b85a", -- muted gold
    success     = "|cff60ff60", -- capped/obtained
    warning     = "|cffff8800", -- below cap, alt deltas
    danger      = "|cffff5050", -- way below cap, errors
    info        = "|cff00d0ff", -- hover hint, links
    muted       = "|cff888888", -- dim secondary text
    mutedSoft   = "|cffaaaaaa", -- subdued labels
    text        = "|cffffffff",
    -- Bar colors (r,g,b,a tuples for SetVertexColor)
    barFull     = { 0.20, 0.80, 0.20, 0.85 },
    barMid      = { 0.85, 0.70, 0.20, 0.85 },
    barLow      = { 0.85, 0.30, 0.20, 0.85 },
    barTrack    = { 0.10, 0.10, 0.10, 1.0 },
    -- Section divider line
    divider     = { 0.4, 0.4, 0.4, 0.6 },
    dividerSoft = { 0.3, 0.3, 0.3, 0.4 },
    -- Selection / hover backgrounds
    selectBg    = { 0.25, 0.20, 0.05, 0.9 },  -- gold-ish
    hoverBg     = { 0.25, 0.25, 0.30, 1.0 },
    inactiveBg  = { 0.12, 0.12, 0.12, 0.8 },
    -- Spacing tokens
    pad         = 8,
    padSm       = 4,
    padLg       = 14,
    sectionGap  = 12,
}

-- Helper: create a 1px horizontal divider line on a parent frame.
local function CreateDivider(parent, color)
    color = color or UI_PAL.divider
    local d = parent:CreateTexture(nil, "OVERLAY")
    d:SetColorTexture(color[1], color[2], color[3], color[4])
    return d
end

-- Helper: attach a GameTooltip to a frame that shows a simple title + optional description on hover.
local function AddSimpleTooltip(frame, title, desc, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1)
        if desc then GameTooltip:AddLine(desc, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function ColorText(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

local function SetFontNormal(fs)
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
end

local function SetFontSmall(fs)
    fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
end

-- 1px border around a frame (no BackdropTemplate needed, works on every client).
local function AddBorder(frame, r, g, b, a)
    local edges = {}
    for i, pts in ipairs({
        { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
    }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a or 1)
        t:SetPoint(pts[1]); t:SetPoint(pts[2])
        if pts[3] then t:SetWidth(pts[3]) else t:SetHeight(pts[4]) end
        edges[i] = t
    end
    frame.borderEdges = edges
end

local function SetBorderColor(frame, r, g, b, a)
    for _, t in ipairs(frame.borderEdges or {}) do t:SetColorTexture(r, g, b, a or 1) end
end

-- Flat dark background for a frame.
local function AddFill(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- Classic tab: Blizzard's TabButtonTemplate (the Macro window's tabs) when the
-- client has it, else a flat fallback. Tabs get global names because older
-- PanelTemplates_* code finds their textures by name. The selected tab is the
-- template's "disabled" look, so it can't be clicked again.
local function CreateTab(parent, name)
    local ok, tab = pcall(CreateFrame, "Button", name, parent, "TabButtonTemplate")
    if ok and tab and PanelTemplates_TabResize and PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
        tab.classic = true
        return tab
    end
    tab = CreateFrame("Button", name, parent)
    tab:SetHeight(24)
    tab.bg = AddFill(tab, 0.12, 0.12, 0.12, 0.8)
    local accent = tab:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(1, 0.82, 0, 1)
    accent:SetPoint("BOTTOMLEFT", 2, 0)
    accent:SetPoint("BOTTOMRIGHT", -2, 0)
    accent:SetHeight(2)
    accent:Hide()
    tab.accent = accent
    local fs = tab:CreateFontString(nil, "OVERLAY")
    SetFontNormal(fs)
    fs:SetAllPoints()
    tab:SetFontString(fs)
    return tab
end

-- Label a tab and size it to the text (or to a fixed width).
local function SetTabLabel(tab, text, width)
    tab:SetText(text)
    if tab.classic then
        PanelTemplates_TabResize(tab, 0, width)
    else
        tab:SetWidth(width or (tab:GetFontString():GetStringWidth() + 24))
    end
end

local function SetTabSelected(tab, selected)
    if tab.classic then
        if selected then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    else
        tab.bg:SetColorTexture(unpack(selected and UI_PAL.selectBg or UI_PAL.inactiveBg))
        tab:GetFontString():SetTextColor(selected and 1 or 0.8, selected and 0.82 or 0.8, selected and 0 or 0.8, 1)
        tab.accent:SetShown(selected)
    end
end

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Viewing a class other than your own: planning only, no ticks.
local function IsBrowsing()
    local class = PlayerClass()
    return class ~= nil and TBCBisTrackerDB.lastClass ~= class
end

-- Where-it-comes-from text without the trailing "(Item Name)", shortened.
local function ShortSource(entry)
    local src = entry.source or ""
    src = src:gsub("%s*%(([^()]*)%)%s*$", "")
    src = src:gsub("^World drop, sold at the auction house", "World drop · auction house")
    src = src:gsub("^Quest:%s*", "")
    return src
end

-- Random-suffix items are listed by their base ID, so the client names them
-- without the suffix ("Twilight Cape" for "Twilight Cape of Healing"). The
-- list's own name keeps it: return the missing part to show next to the name.
local function SuffixHint(entry, itemName)
    local listed = entry.source and entry.source:match("%(([^()]*)%)%s*$")
    if not (listed and itemName) then return nil end
    if #listed > #itemName and listed:sub(1, #itemName) == itemName then
        return listed:sub(#itemName + 1)
    end
    return nil
end

local function ItemQualityRGB(itemId)
    local quality = itemId and select(3, GetItemInfo(itemId))
    if quality and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 0.35, 0.35, 0.35
end

-- ─────────────────────────────────────────────
-- Main frame
-- ─────────────────────────────────────────────

function UI:Build()
    if self.frame then return end

    -- Outer frame
    local f = CreateFrame("Frame", "TBCBisTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:Hide()
    self.frame = f

    -- Restore saved position
    local wp = TBCBisTrackerDB.windowPos
    if wp and wp.point then
        f:ClearAllPoints()
        f:SetPoint(wp.point, UIParent, wp.point, wp.x, wp.y)
    end

    f:SetScript("OnHide", function()
        local pt, _, _, x, y = f:GetPoint()
        TBCBisTrackerDB.windowPos = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    -- Title: just the add-on name; class and spec live in the toolbar below.
    -- Left-aligned so it can never run under anything else in the title bar.
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -5)
    title:SetText(UI_PAL.accent .. addon.TITLE .. "|r")
    self.titleText = title

    -- ── Row A: class dropdown + spec tabs + stage ──
    self:BuildClassButtons()
    self:BuildSpecSelector()
    self:BuildPhaseTabs()

    -- ── Row B: source filter, missing only, export/import ──
    self:BuildSourceFilter()
    self:BuildMissingFilter()
    self:BuildExportImportButtons()

    -- ── "Browsing another class" banner ──
    self:BuildBrowseBanner()

    -- ── Column headers ──
    self:BuildColumnHeaders()

    -- ── Scrollable gear list ──
    self:BuildScrollFrame()

    -- ── Progress footer ──
    self:BuildProgressBar()

    -- ── TBC extras under the list: badges, tier sets, farm plan hover ──
    -- (Forever shows the farm plan in the side panel instead.)
    if not addon:IsForever() then
        self:BuildBadgeStatus()
        self:BuildFarmPlan()
    end
    self:BuildTierStatus()

    -- ── Stat-cap side panel ──
    self:BuildStatCapPanel()

    -- Initial population
    self:RefreshClassButtons()
    self:RefreshSpecSelector()
    self:RefreshPhaseTabs()
    self:Refresh()
end

-- ─────────────────────────────────────────────
-- Class buttons
-- ─────────────────────────────────────────────

-- The window opens on your own class; the class dropdown lets you browse the
-- others (planning only: ticks and auto-detect stay on your own class).

-- Pick a valid spec for a class: the one last viewed for it, else its first.
local function SpecForClass(class)
    local info = addon.CLASS_INFO[class]
    if not info then return nil end
    local remembered = TBCBisTrackerDB.specByClass and TBCBisTrackerDB.specByClass[class]
    for _, s in ipairs(info.specs) do
        if s == remembered then return s end
    end
    return info.specs[1]
end

function UI:SetViewClass(class)
    if not addon.CLASS_INFO[class] then return end
    TBCBisTrackerDB.specByClass = TBCBisTrackerDB.specByClass or {}
    if TBCBisTrackerDB.lastClass and TBCBisTrackerDB.lastSpec then
        TBCBisTrackerDB.specByClass[TBCBisTrackerDB.lastClass] = TBCBisTrackerDB.lastSpec
    end
    TBCBisTrackerDB.lastClass = class
    TBCBisTrackerDB.lastSpec = SpecForClass(class)
    self:RefreshClassButtons()
    self:RefreshSpecSelector()
    self:Refresh()
end

function UI:BuildClassButtons()
    local f = self.frame
    local playerClass = PlayerClass() or TBCBisTrackerDB.lastClass
    if not playerClass then return end

    -- Every session starts on your own class.
    local info = addon.CLASS_INFO[playerClass]
    if info then
        if TBCBisTrackerDB.lastClass ~= playerClass then
            TBCBisTrackerDB.lastClass = playerClass
            TBCBisTrackerDB.lastSpec = SpecForClass(playerClass)
        end
        local valid = false
        for _, s in ipairs(info.specs) do valid = valid or s == TBCBisTrackerDB.lastSpec end
        if not valid then TBCBisTrackerDB.lastSpec = info.specs[1] end
    end

    -- Standard Blizzard dropdown, same look as the source filter.
    local dd = CreateFrame("Frame", "TBCBisTrackerClassDropdown", f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 2, ROW_A_Y + 2)
    UIDropDownMenu_SetWidth(dd, 110)
    AddSimpleTooltip(dd, "Class", "Browse another class's lists. Ticks and auto-detect stay on your own class.")
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, class in ipairs(CLASS_ORDER) do
            local c = addon.CLASS_INFO[class]
            local info = UIDropDownMenu_CreateInfo()
            info.text = "|cff" .. c.color .. c.name .. "|r"
                .. (class == playerClass and ("  " .. UI_PAL.muted .. "(you)|r") or "")
            info.value = class
            info.checked = class == TBCBisTrackerDB.lastClass
            local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
            if coords then
                info.icon = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
                info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom = coords[1], coords[2], coords[3], coords[4]
            end
            info.func = function()
                CloseDropDownMenus()
                UI:SetViewClass(class)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.classDropdown = dd
end

function UI:RefreshClassButtons()
    local class = TBCBisTrackerDB.lastClass
    local info = class and addon.CLASS_INFO[class]
    if not (self.classDropdown and info) then return end
    UIDropDownMenu_SetSelectedValue(self.classDropdown, class)
    UIDropDownMenu_SetText(self.classDropdown, "|cff" .. info.color .. info.name .. "|r")
end

function UI:BuildSpecSelector()
    local f = self.frame
    self.specBtns = {}
    self.specBtnRow = CreateFrame("Frame", nil, f)
    self.specBtnRow:SetSize(400, 24)
    -- Right of the class dropdown (its frame has ~16 px of empty edge).
    self.specBtnRow:SetPoint("TOPLEFT", f, "TOPLEFT", 166, ROW_A_Y)
end

local SPEC_POOL_SIZE = 4

local function GetOrCreateSpecBtn(self, idx)
    local btn = self.specBtns[idx]
    if btn then return btn end

    btn = CreateTab(self.specBtnRow, "TBCBisTrackerSpecTab" .. idx)
    btn:SetScript("OnEnter", function(s)
        if s.spec then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.spec, 1, 1, 1)
            GameTooltip:AddLine("Click to view BiS for this spec.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(s)
        if not s.spec then return end
        TBCBisTrackerDB.lastSpec = s.spec
        UI:RefreshSpecSelector()
        UI:Refresh()
    end)

    self.specBtns[idx] = btn
    return btn
end

function UI:RefreshSpecSelector()
    local class = TBCBisTrackerDB.lastClass
    if not class then return end
    local info  = addon.CLASS_INFO[class]
    if not info then return end

    local x = 0
    for i = 1, SPEC_POOL_SIZE do
        local spec = info.specs[i]
        local btn  = GetOrCreateSpecBtn(self, i)
        if spec then
            btn.spec = spec
            SetTabLabel(btn, spec)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", self.specBtnRow, "BOTTOMLEFT", x, 0)
            SetTabSelected(btn, spec == TBCBisTrackerDB.lastSpec)
            btn:Show()
            x = x + btn:GetWidth() + 2
        else
            btn.spec = nil
            btn:Hide()
        end
    end
end

-- ─────────────────────────────────────────────
-- Phase tabs
-- ─────────────────────────────────────────────

function UI:BuildPhaseTabs()
    local f = self.frame
    self.phaseTabs = {}

    -- One stage (WoW Forever: Level 30): a single selected tab on the right of row A.
    if #addon.PHASES == 1 then
        local phase = addon.PHASES[1]
        local tab = CreateTab(f, "TBCBisTrackerStageTab")
        SetTabLabel(tab, addon.PHASE_LABELS[phase] or phase)
        tab:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(STAT_AREA_W + 20), ROW_A_Y)
        SetTabSelected(tab, true)
        local lbl = f:CreateFontString(nil, "OVERLAY")
        SetFontSmall(lbl)
        lbl:SetPoint("RIGHT", tab, "LEFT", -6, 0)
        lbl:SetText(UI_PAL.muted .. "STAGE|r")
        AddSimpleTooltip(tab, addon.PHASE_DESCRIPTIONS[phase] or phase)
        self.stageChip = tab
        return
    end

    -- Several phases (TBC): a tab row of their own.
    local tabW = (LIST_W - 40) / #addon.PHASES
    for i, phase in ipairs(addon.PHASES) do
        local btn = CreateTab(f, "TBCBisTrackerPhaseTab" .. i)
        btn.tabW = tabW - 2
        SetTabLabel(btn, addon.PHASE_LABELS[phase], btn.tabW)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + (i-1) * tabW, TABS_Y)

        local capturedPhase = phase
        btn:SetScript("OnClick", function()
            TBCBisTrackerDB.lastPhase = capturedPhase
            UI:RefreshPhaseTabs()
            UI:Refresh()
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(addon.PHASE_DESCRIPTIONS[capturedPhase], 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.phaseTabs[phase] = btn
    end
end

function UI:RefreshPhaseTabs()
    local selected = TBCBisTrackerDB.lastPhase
    local class    = TBCBisTrackerDB.lastClass
    local spec     = TBCBisTrackerDB.lastSpec
    for phase, btn in pairs(self.phaseTabs) do
        local label = addon.PHASE_LABELS[phase] or phase
        if class and spec then
            local got, tot = addon:GetPhaseProgress(class, spec, phase)
            if tot > 0 then
                local pctColor = (got == tot) and "|cffffd700" or "|cffaaaaaa"
                label = label .. " " .. pctColor .. "(" .. got .. "/" .. tot .. ")|r"
            end
        end
        SetTabLabel(btn, label, btn.tabW)
        SetTabSelected(btn, phase == selected)
    end
end

-- ─────────────────────────────────────────────
-- Missing-only filter checkbox
-- ─────────────────────────────────────────────

function UI:ShowExportPopup()
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local text  = addon:ExportSetup(class, spec, phase)
    if not text then addon:Print("Nothing to export."); return end
    StaticPopupDialogs["TBCBIS_EXPORT"] = {
        text = "Export — Ctrl+A then Ctrl+C to copy:",
        button1 = "Close",
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999,
        OnShow = function(s)
            local eb = s.editBox or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            if not eb then return end
            eb:SetMaxLetters(999)
            eb:SetMaxBytes(0)
            eb:SetText(text)
            eb:HighlightText()
            eb:SetFocus()
        end,
        EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCBIS_EXPORT")
end

-- Per-slot note editor popup. Saves on Accept; clearing the field deletes the note.
function UI:ShowNoteEditor(class, spec, phase, slot)
    local slotLabel = addon.SLOT_LABELS[slot] or slot
    local entry = addon:GetSlotItem(class, spec, phase, slot)
    local itemName = entry and entry.id and addon:GetItemName(entry.id) or "(empty)"
    local existing = addon:GetNote(class, spec, phase, slot) or ""

    StaticPopupDialogs["TBCBIS_NOTE"] = {
        text = "Note for |cffffffff" .. slotLabel .. "|r — " .. itemName .. "\n(empty to clear)",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 380,
        maxLetters = 200,
        OnShow = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            if eb then eb:SetText(existing); eb:HighlightText(); eb:SetFocus() end
        end,
        OnAccept = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            local txt = (eb and eb:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            addon:SetNote(class, spec, phase, slot, txt ~= "" and txt or nil)
            UI:Refresh()
        end,
        EditBoxOnEnterPressed = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            local txt = (eb and eb:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            addon:SetNote(class, spec, phase, slot, txt ~= "" and txt or nil)
            s:GetParent():Hide()
            UI:Refresh()
        end,
        EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCBIS_NOTE")
end

function UI:ShowImportPopup()
    StaticPopupDialogs["TBCBIS_IMPORT"] = {
        text = "Paste an exported setup string:",
        button1 = "Import",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            if eb then eb:SetText(""); eb:SetFocus() end
        end,
        OnAccept = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            local input = eb and eb:GetText() or ""
            local ok, msg = addon:ImportSetup(input)
            addon:Print(ok and ("Import: " .. msg) or ("Import failed: " .. tostring(msg)))
            if ok then UI:Refresh() end
        end,
        EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCBIS_IMPORT")
end

local SOURCE_FILTER_OPTIONS = { "all", "raid", "heroic", "dungeon", "crafted", "reputation", "world", "quest", "pvp" }
local SOURCE_FILTER_LABELS = {
    all        = "All sources",
    raid       = "Raid only",
    heroic     = "Heroic only",
    dungeon    = "Dungeon only",
    crafted    = "Crafted only",
    reputation = "Reputation only",
    world      = "World drop only",
    quest      = "Quest only",
    pvp        = "PvP only",
}

function UI:BuildSourceFilter()
    local f = self.frame
    local dd = CreateFrame("Frame", "TBCBisTrackerSourceFilterDropdown", f, "UIDropDownMenuTemplate")
    -- Row B, left. The template draws ~16 px inside its frame, hence the offset.
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 2, ROW_B_Y + 2)
    UIDropDownMenu_SetWidth(dd, 110)
    self.sourceFilterDropdown = dd
    -- Hover tooltip on the dropdown caret
    AddSimpleTooltip(dd, "Source filter", "Show only items from this source type. Useful for planning farms (e.g. show only Heroic dungeon items).")

    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, opt in ipairs(SOURCE_FILTER_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = SOURCE_FILTER_LABELS[opt] or opt
            info.value = opt
            info.checked = (TBCBisTrackerDB.sourceFilter or "all") == opt
            info.func = function()
                TBCBisTrackerDB.sourceFilter = opt
                UIDropDownMenu_SetSelectedValue(dd, opt)
                UIDropDownMenu_SetText(dd, SOURCE_FILTER_LABELS[opt])
                UI:Refresh()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(dd, TBCBisTrackerDB.sourceFilter or "all")
    UIDropDownMenu_SetText(dd, SOURCE_FILTER_LABELS[TBCBisTrackerDB.sourceFilter or "all"])
end

function UI:BuildExportImportButtons()
    local f = self.frame
    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(70, 22)
    importBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(STAT_AREA_W + 20), ROW_B_Y)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function() UI:ShowImportPopup() end)
    -- Preserve the OnClick by adding tooltip via separate scripts (hooking, not overwriting)
    importBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Import setup", 1, 1, 1)
        GameTooltip:AddLine("Paste a setup string to load someone else's BiS picks for this spec/phase.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    importBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(70, 22)
    exportBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function() UI:ShowExportPopup() end)
    exportBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Export setup", 1, 1, 1)
        GameTooltip:AddLine("Copy your current spec/phase BiS picks as a sharable string.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    exportBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI:BuildMissingFilter()
    local f = self.frame
    local chk = CreateFrame("CheckButton", "TBCBisTrackerMissingChk", f, "UICheckButtonTemplate")
    chk:SetSize(22, 22)
    -- Row B, right of the source filter.
    chk:SetPoint("TOPLEFT", f, "TOPLEFT", 172, ROW_B_Y)
    chk:SetChecked(TBCBisTrackerDB.showMissingOnly or false)

    local lbl = f:CreateFontString(nil, "OVERLAY")
    SetFontNormal(lbl)
    lbl:SetText("Missing only")
    lbl:SetPoint("LEFT", chk, "RIGHT", 2, 0)

    chk:SetScript("OnClick", function(self)
        TBCBisTrackerDB.showMissingOnly = self:GetChecked()
        UI:Refresh()
    end)
    chk:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Show missing only", 1, 1, 1)
        GameTooltip:AddLine("Hide rows for items you've already obtained, so the list only shows what you still need to chase.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    chk:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self.missingChk = chk
end

-- ─────────────────────────────────────────────
-- Column headers
-- ─────────────────────────────────────────────

function UI:BuildBrowseBanner()
    local f = self.frame
    local banner = CreateFrame("Frame", nil, f)
    banner:SetSize(LIST_W - 40, BANNER_H)
    AddFill(banner, 0.10, 0.13, 0.19, 0.95)
    AddBorder(banner, 0.18, 0.23, 0.32, 1)

    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(130, 20)
    back:SetPoint("RIGHT", banner, "RIGHT", -4, 0)
    back:SetScript("OnClick", function() UI:SetViewClass(PlayerClass()) end)
    banner.back = back

    local txt = banner:CreateFontString(nil, "OVERLAY")
    SetFontNormal(txt)
    txt:SetPoint("LEFT", banner, "LEFT", 10, 0)
    txt:SetPoint("RIGHT", back, "LEFT", -8, 0)
    txt:SetJustifyH("LEFT")
    txt:SetTextColor(0.79, 0.84, 0.93, 1)
    banner.txt = txt

    banner:Hide()
    self.browseBanner = banner
end

function UI:BuildColumnHeaders()
    local f = self.frame
    local header = CreateFrame("Frame", nil, f)
    header:SetSize(SCROLL_W, 16)
    self.colHeader = header

    local headers = {
        { text = "",       w = COL_ICON_W },
        { text = "Slot",   w = COL_SLOT_W },
        { text = "Item",   w = COL_ITEM_W },
        { text = "Source", w = COL_SRC_W  },
        { text = "Got it", w = COL_CHK_W, center = true },
    }

    local x = 0
    for _, h in ipairs(headers) do
        if h.text ~= "" then
            local fs = header:CreateFontString(nil, "OVERLAY")
            SetFontSmall(fs)
            fs:SetTextColor(0.55, 0.53, 0.48, 1)
            fs:SetWidth(h.w)
            fs:SetJustifyH(h.center and "CENTER" or "LEFT")
            fs:SetPoint("LEFT", header, "LEFT", x, 0)
            fs:SetText(h.text:upper())
        end
        x = x + h.w + 4
    end

    local div = header:CreateTexture(nil, "OVERLAY")
    div:SetColorTexture(0.3, 0.3, 0.3, 0.7)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    div:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 10, -2)
end

-- ─────────────────────────────────────────────
-- Scrollable gear list (plain scroll frame + slim scrollbar; the old
-- UIPanelScrollFrameTemplate art draws as grey boxes on newer clients)
-- ─────────────────────────────────────────────

function UI:BuildScrollFrame()
    local f = self.frame

    local sf = CreateFrame("ScrollFrame", "TBCBisTrackerScroll", f)
    sf:EnableMouseWheel(true)
    self.scrollFrame = sf

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(SCROLL_W, 17 * (ROW_H + ROW_PAD))
    sf:SetScrollChild(content)
    self.scrollContent = content

    -- Slim scrollbar on the right of the list.
    local bar = CreateFrame("Slider", nil, f)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:EnableMouse(true)
    bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 0)
    AddFill(bar, 0.11, 0.12, 0.14, 1)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.42, 0.39, 0.30, 1)
    thumb:SetSize(6, 40)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value) sf:SetVerticalScroll(value) end)
    sf:SetScript("OnMouseWheel", function(_, delta)
        local lo, hi = bar:GetMinMaxValues()
        local v = bar:GetValue() - delta * (ROW_H + ROW_PAD) * 2
        bar:SetValue(math.max(lo, math.min(hi, v)))
    end)
    self.scrollBar = bar
    self.scrollThumb = thumb
    -- The list only knows its height once laid out; redo the range then.
    sf:SetScript("OnSizeChanged", function() UI:UpdateScrollRange(UI.lastRowCount or 0) end)

    self.rowPool = {}
    for i = 1, 18 do
        local row = self:CreateRowFrame(content, i)
        self.rowPool[i] = row
        row:Hide()
    end
end

-- Positions the header, banner and list for the current state: one stage or
-- phase tabs, browsing banner or not, TBC footer lines or not.
function UI:ApplyLayout()
    local f = self.frame
    local top = (#addon.PHASES > 1) and (TABS_Y - PHASE_TAB_H - 6) or (ROW_B_Y - 30)
    local browsing = IsBrowsing()
    if browsing then
        self.browseBanner:ClearAllPoints()
        self.browseBanner:SetPoint("TOPLEFT", f, "TOPLEFT", 20, top)
        self.browseBanner:Show()
        top = top - BANNER_H - 6
    else
        self.browseBanner:Hide()
    end
    self.colHeader:ClearAllPoints()
    self.colHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 20, top)

    local bottom = addon:IsForever() and LIST_BOTTOM_FOREVER or LIST_BOTTOM_TBC
    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, top - 22)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 20 + SCROLL_W, bottom)
end

-- Scroll range and thumb size for the current number of rows.
function UI:UpdateScrollRange(rowCount)
    self.lastRowCount = rowCount
    local contentH = math.max(1, rowCount) * (ROW_H + ROW_PAD)
    self.scrollContent:SetHeight(contentH)
    local viewH = self.scrollFrame:GetHeight() or 0
    local maxScroll = math.max(0, contentH - viewH)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if self.scrollBar:GetValue() > maxScroll then self.scrollBar:SetValue(maxScroll) end
    self.scrollFrame:SetVerticalScroll(self.scrollBar:GetValue())
    if viewH > 0 and maxScroll > 0 then
        self.scrollThumb:SetHeight(math.max(24, viewH * viewH / contentH))
        self.scrollBar:Show()
    else
        self.scrollBar:Hide()
    end
end

function UI:CreateRowFrame(parent, idx)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    -- Background (alternating)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    if idx % 2 == 0 then
        bg:SetVertexColor(0.10, 0.10, 0.14, 0.6)
    else
        bg:SetVertexColor(0.06, 0.06, 0.09, 0.4)
    end
    row.bg = bg

    local x = 0

    -- Item icon with a quality-coloured border
    local iconBorder = row:CreateTexture(nil, "BORDER")
    iconBorder:SetSize(26, 26)
    iconBorder:SetPoint("LEFT", row, "LEFT", x + 1, 0)
    iconBorder:SetColorTexture(0.35, 0.35, 0.35, 1)
    row.iconBorder = iconBorder
    local iconTex = row:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(24, 24)
    iconTex:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)
    iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.iconTex = iconTex
    x = x + COL_ICON_W + 4

    -- Slot label
    local slotLbl = row:CreateFontString(nil, "OVERLAY")
    SetFontSmall(slotLbl)
    slotLbl:SetWidth(COL_SLOT_W)
    slotLbl:SetJustifyH("LEFT")
    slotLbl:SetPoint("LEFT", row, "LEFT", x, 0)
    slotLbl:SetTextColor(0.7, 0.7, 0.7, 1)
    row.slotLbl = slotLbl
    x = x + COL_SLOT_W + 4

    -- Item name
    local itemLbl = row:CreateFontString(nil, "OVERLAY")
    SetFontNormal(itemLbl)
    itemLbl:SetWidth(COL_ITEM_W)
    itemLbl:SetJustifyH("LEFT")
    itemLbl:SetWordWrap(false)
    itemLbl:SetPoint("LEFT", row, "LEFT", x, 0)
    row.itemLbl = itemLbl
    x = x + COL_ITEM_W + 4

    -- Source: type on top (coloured), where-from underneath (dim, one line)
    local srcLbl = row:CreateFontString(nil, "OVERLAY")
    SetFontSmall(srcLbl)
    srcLbl:SetWidth(COL_SRC_W)
    srcLbl:SetJustifyH("LEFT")
    srcLbl:SetPoint("LEFT", row, "LEFT", x, 7)
    srcLbl:SetTextColor(0.65, 0.65, 0.65, 1)
    row.srcLbl = srcLbl
    local srcDetail = row:CreateFontString(nil, "OVERLAY")
    SetFontSmall(srcDetail)
    srcDetail:SetWidth(COL_SRC_W)
    srcDetail:SetJustifyH("LEFT")
    srcDetail:SetWordWrap(false)
    srcDetail:SetPoint("LEFT", row, "LEFT", x, -7)
    srcDetail:SetTextColor(0.64, 0.62, 0.55, 1)
    row.srcDetail = srcDetail
    -- Invisible mouse-capture overlay for the source column — shows a quest
    -- tooltip when this row's item has a questId.
    local srcHover = CreateFrame("Frame", nil, row)
    srcHover:SetSize(COL_SRC_W, ROW_H)
    srcHover:SetPoint("LEFT", row, "LEFT", x, 0)
    srcHover:EnableMouse(true)
    srcHover:SetFrameLevel(row:GetFrameLevel() + 1)
    srcHover:SetScript("OnEnter", function(self)
        if not row.sourceFull then return end  -- empty/placeholder slot
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local typeLabel  = SOURCE_TYPE_LABELS[row.sourceType] or "Source"
        local typeColor  = SOURCE_TYPE_COLORS[row.sourceType] or "|cffcccccc"
        GameTooltip:SetText(typeColor .. typeLabel .. "|r")
        GameTooltip:AddLine(row.sourceFull, 1, 1, 1, true)
        if row.profStatus then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(row.profStatus, 1, 1, 1, true)
        end
        if row.userNote and row.userNote ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|TInterface\\GossipFrame\\TrainerGossipIcon:12:12|t |cffd6b85aYour note|r", 1, 1, 1)
            GameTooltip:AddLine("|cffffffff" .. row.userNote .. "|r", 1, 1, 1, true)
        end
        local qid = row.questId
        if qid and qid > 0 then
            GameTooltip:AddLine(" ")
            local qTitle
            if C_QuestLog and C_QuestLog.GetTitleForQuestID then
                qTitle = C_QuestLog.GetTitleForQuestID(qid)
            end
            if qTitle and qTitle ~= "" then
                GameTooltip:AddLine("|cffffd700Quest:|r |cffffff00[" .. qTitle .. "]|r", 1, 1, 1, true)
            else
                GameTooltip:AddLine("|cffffd700Quest reward|r (id " .. qid .. ")", 1, 1, 1, true)
            end
            GameTooltip:AddLine("|cffaaaaaa" .. addon.WOWHEAD_QUEST_BASE .. qid .. "|r", 1, 1, 1, true)
            GameTooltip:AddLine("|cff888888Ctrl+click for URL  ·  Shift+click for chat-link|r", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    srcHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Click handlers on the source overlay: ctrl=URL popup, shift=chat link
    srcHover:EnableMouse(true)
    srcHover:SetScript("OnMouseDown", function(self, button)
        local qid = row.questId
        if not (qid and qid > 0) then return end
        if button == "LeftButton" and IsShiftKeyDown() then
            local link = GetQuestLink and GetQuestLink(qid)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        elseif button == "LeftButton" and IsControlKeyDown() then
            local url = addon.WOWHEAD_QUEST_BASE .. tostring(qid)
            local function findEditBox(s)
                if s and s.editBox then return s.editBox end
                local name = s and s.GetName and s:GetName()
                if name then return _G[name .. "EditBox"] end
                return _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
                    or _G["StaticPopup3EditBox"] or _G["StaticPopup4EditBox"]
            end
            StaticPopupDialogs["TBCBIS_WOWHEAD_QUEST_URL"] = {
                text = "Wowhead Quest URL (Ctrl+C to copy):",
                button1 = "Close",
                hasEditBox = true, editBoxWidth = 350,
                OnShow = function(s, data)
                    local eb = findEditBox(s)
                    if not eb then return end
                    local value = tostring(data or "")
                    eb:SetText(value)
                    eb:HighlightText()
                    eb:SetFocus()
                    C_Timer.After(0, function()
                        if eb:GetText() ~= value then
                            eb:SetText(value)
                            eb:HighlightText()
                        end
                    end)
                end,
                EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("TBCBIS_WOWHEAD_QUEST_URL", nil, nil, url)
        end
    end)
    row.srcHover = srcHover
    x = x + COL_SRC_W + 4

    -- Checkbox (a dash instead while browsing another class)
    local chk = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    chk:SetSize(22, 22)
    chk:SetPoint("LEFT", row, "LEFT", x + (COL_CHK_W - 22) / 2, 0)
    row.chk = chk
    local dash = row:CreateFontString(nil, "OVERLAY")
    SetFontNormal(dash)
    dash:SetPoint("CENTER", chk, "CENTER", 0, 0)
    dash:SetText("|cff4d4f57-|r")
    dash:Hide()
    row.dash = dash

    -- Hover highlight + tooltip; shift = side-by-side comparison
    row:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(0.20, 0.20, 0.30, 0.8)
        if self.itemId and self.itemId > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemId .. ":0:0:0:0:0:0:0")
            -- Quest source: append quest info if this item is a quest reward
            if self.questId and self.questId > 0 then
                GameTooltip:AddLine(" ")
                local qTitle
                if C_QuestLog and C_QuestLog.GetTitleForQuestID then
                    qTitle = C_QuestLog.GetTitleForQuestID(self.questId)
                end
                if qTitle and qTitle ~= "" then
                    GameTooltip:AddLine("|cffffd700Quest:|r |cffffff00[" .. qTitle .. "]|r", 1, 1, 1)
                else
                    GameTooltip:AddLine("|cffffd700Quest reward|r", 1, 1, 1)
                end
                GameTooltip:AddLine("|cffaaaaaa" .. addon.WOWHEAD_QUEST_BASE .. self.questId .. "|r", 0.8, 0.8, 0.8, true)
            end
            -- User note
            if self.userNote and self.userNote ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|TInterface\\GossipFrame\\TrainerGossipIcon:12:12|t |cffd6b85aYour note|r", 1, 1, 1)
                GameTooltip:AddLine("|cffffffff" .. self.userNote .. "|r", 1, 1, 1, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffaaaaaa" .. (addon.WOWHEAD_BASE .. self.itemId) .. "|r", 1, 1, 1, true)
            GameTooltip:Show()
            if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                GameTooltip_ShowCompareItem(GameTooltip)
            end
        end
    end)
    row:SetScript("OnLeave", function(self)
        if idx % 2 == 0 then
            self.bg:SetVertexColor(0.10, 0.10, 0.14, 0.6)
        else
            self.bg:SetVertexColor(0.06, 0.06, 0.09, 0.4)
        end
        GameTooltip:Hide()
    end)

    -- Click handlers: cursor-drop = import; shift+left = chat-link; ctrl+left = URL; right = alts menu
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and CursorHasItem() then
            UI:ImportFromCursor(self.slotKey)
            return
        end
        if button == "LeftButton" and IsShiftKeyDown() and self.itemId and self.itemId > 0 then
            local _, link = GetItemInfo(self.itemId)
            if link then
                if ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                else
                    DEFAULT_CHAT_FRAME.editBox:Insert(link)
                end
            end
        elseif button == "LeftButton" and IsControlKeyDown() and self.itemId and self.itemId > 0 then
            -- Build the URL upfront and pass it via `data` to StaticPopup_Show
            -- (4th arg). In TBC Classic the popup frame doesn't expose
            -- `self.editBox` — it's only reachable through the global name
            -- `<frameName>EditBox`. The OnShow handler below resolves it via
            -- the popup's actual frame name, then re-applies the text on the
            -- next frame in case Blizzard's StaticPopup clears it after OnShow
            -- on some popup slots.
            local url = addon.WOWHEAD_BASE .. tostring(self.itemId)
            local function findEditBox(s)
                if s and s.editBox then return s.editBox end
                local name = s and s.GetName and s:GetName()
                if name then return _G[name .. "EditBox"] end
                return _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
                    or _G["StaticPopup3EditBox"] or _G["StaticPopup4EditBox"]
            end
            StaticPopupDialogs["TBCBIS_WOWHEAD_URL"] = {
                text = "Wowhead URL (Ctrl+C to copy):",
                button1 = "Close",
                hasEditBox = true,
                editBoxWidth = 350,
                OnShow = function(s, data)
                    local eb = findEditBox(s)
                    if not eb then return end
                    local value = tostring(data or "")
                    eb:SetText(value)
                    eb:HighlightText()
                    eb:SetFocus()
                    C_Timer.After(0, function()
                        if eb:GetText() ~= value then
                            eb:SetText(value)
                            eb:HighlightText()
                        end
                    end)
                end,
                EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("TBCBIS_WOWHEAD_URL", nil, nil, url)
        elseif button == "RightButton" and self.slotKey then
            UI:ShowAlternativesMenu(self, self.slotKey)
        end
    end)

    -- Drag-drop: drop a bag or equipped item onto the row to import it as an alternative
    row:SetScript("OnReceiveDrag", function(self)
        if self.slotKey then UI:ImportFromCursor(self.slotKey) end
    end)

    return row
end

-- Set selected alternative by item id; returns true if found
local function selectAltById(class, spec, phase, slot, itemId)
    local alts = addon:GetSlotAlternatives(class, spec, phase, slot)
    if not alts then return false end
    for i, alt in ipairs(alts) do
        if alt.id == itemId then
            addon:SetSelectedAlt(class, spec, phase, slot, i)
            return true
        end
    end
    return false
end

function UI:ImportOrSelect(slot, itemId, sourceLabel)
    if not itemId then return end
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local nameOrId = GetItemInfo(itemId) or itemId
    if selectAltById(class, spec, phase, slot, itemId) then
        addon:Print(nameOrId .. " — already in list; selected.")
    else
        addon:AddCustomAlt(class, spec, phase, slot, itemId, sourceLabel or "Custom")
        selectAltById(class, spec, phase, slot, itemId)
        addon:Print("Added " .. nameOrId .. " to " .. (addon.SLOT_LABELS[slot] or slot) .. " and selected.")
    end
    addon:ScanEquipped()  -- tick obtained if the item is in bags/equipped
    UI:Refresh()
end

-- Find the BIS slot whose equipLoc whitelist accepts this item.
-- If the dropped slot accepts it, keep it. Otherwise pick the first matching slot in SLOTS order.
local function routeSlotForItem(equipLoc, droppedSlot)
    if not equipLoc or equipLoc == "" then return droppedSlot end
    if addon.SLOT_INVTYPES[droppedSlot] and addon.SLOT_INVTYPES[droppedSlot][equipLoc] then
        return droppedSlot
    end
    for _, slot in ipairs(addon.SLOTS) do
        local map = addon.SLOT_INVTYPES[slot]
        if map and map[equipLoc] then
            return slot
        end
    end
    return nil
end

function UI:ShowSearchDialog(slot)
    StaticPopupDialogs["TBCBIS_SEARCH"] = {
        text = "Search items by name (target slot: " .. (addon.SLOT_LABELS[slot] or slot) .. "):",
        button1 = "Search",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 250,
        OnShow = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            if eb then eb:SetText(""); eb:SetFocus() end
        end,
        OnAccept = function(s)
            local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
            local query = eb and eb:GetText() or ""
            if query == "" then return end
            local results = addon:SearchItems(query, 20)
            if #results == 0 then
                addon:Print("No items found for: " .. query)
                return
            end
            UI:ShowSearchResults(slot, query, results)
        end,
        EditBoxOnEnterPressed = function(s)
            local parent = s:GetParent()
            local dialog = StaticPopupDialogs[parent.which]
            if dialog and dialog.OnAccept then dialog.OnAccept(parent) end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TBCBIS_SEARCH")
end

function UI:ShowSearchResults(slot, query, results)
    if not self.searchDropdown then
        self.searchDropdown = CreateFrame("Frame", "TBCBisTrackerSearchDropdown", UIParent, "UIDropDownMenuTemplate")
    end
    self.searchMenuItemIds = {}
    UIDropDownMenu_Initialize(self.searchDropdown, function(_, level)
        local title = UIDropDownMenu_CreateInfo()
        title.text = "Results for \"" .. query .. "\" — click to import"
        title.isTitle = true
        title.notCheckable = true
        UIDropDownMenu_AddButton(title, level)
        for i, r in ipairs(results) do
            local label = r.name or ("item:" .. r.id)
            local color = addon:GetItemQualityColor(r.id) or "|cffffffff"
            local info = UIDropDownMenu_CreateInfo()
            info.text = color .. label .. "|r"
            info.notCheckable = true
            info.func = function()
                UI:ImportOrSelect(slot, r.id, "Search import")
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
            UI.searchMenuItemIds[i + 1] = r.id  -- offset +1 for the title row
        end
        local cancel = UIDropDownMenu_CreateInfo()
        cancel.text = "Cancel"
        cancel.notCheckable = true
        cancel.func = function() CloseDropDownMenus() end
        UIDropDownMenu_AddButton(cancel, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, self.searchDropdown, "cursor", 0, 0)

    -- Attach item tooltips on hover
    C_Timer.After(0, function()
        for i = 1, 32 do
            local btn = _G["DropDownList1Button" .. i]
            if not btn or not btn:IsShown() then break end
            local id = UI.searchMenuItemIds[i]
            if id and not btn.tbcbisSearchHooked then
                btn.tbcbisSearchHooked = true
                btn:HookScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0")
                    GameTooltip:Show()
                    if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                        GameTooltip_ShowCompareItem(GameTooltip)
                    end
                end)
                btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end)
end

function UI:ImportFromCursor(droppedSlot)
    if not CursorHasItem() then return end
    local cursorType, _, itemLink = GetCursorInfo()
    ClearCursor()
    if cursorType ~= "item" or not itemLink then return end
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
    local targetSlot = routeSlotForItem(equipLoc, droppedSlot)
    if not targetSlot then
        addon:Print((GetItemInfo(itemId) or itemId) .. " can't be routed to a tracked slot (equipLoc=" .. tostring(equipLoc) .. ").")
        return
    end
    if targetSlot ~= droppedSlot then
        addon:Print("Routed to " .. (addon.SLOT_LABELS[targetSlot] or targetSlot) .. ".")
    end
    UI:ImportOrSelect(targetSlot, itemId, "Custom (drag-drop)")
end

function UI:ShowAlternativesMenu(anchorFrame, slot)
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local alts  = addon:GetSlotAlternatives(class, spec, phase, slot)
    if not alts or #alts == 0 then
        -- Empty slot in DB and no custom imports yet; offer the import option from a minimal menu
        alts = {}
    end
    local currentIdx = addon:GetSelectedAlt(class, spec, phase, slot)

    if not self.altDropdown then
        self.altDropdown = CreateFrame("Frame", "TBCBisTrackerAltDropdown", UIParent, "UIDropDownMenuTemplate")
    end

    UIDropDownMenu_Initialize(self.altDropdown, function(_, level)
        local title = UIDropDownMenu_CreateInfo()
        title.text = "Track for " .. (addon.SLOT_LABELS[slot] or slot)
        title.isTitle = true
        title.notCheckable = true
        UIDropDownMenu_AddButton(title, level)

        for i, alt in ipairs(alts) do
            local name  = addon:GetItemName(alt.id)
            local color = addon:GetItemQualityColor(alt.id)
            local prefix = (i == 1) and "|cffffd700[BiS]|r " or "|cffaaaaaa[Alt " .. (i-1) .. "]|r "
            local info = UIDropDownMenu_CreateInfo()
            info.text     = prefix .. color .. name .. "|r"
            info.checked  = (i == currentIdx)
            info.func     = function()
                addon:SetSelectedAlt(class, spec, phase, slot, i)
                UI:Refresh()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end

        local sep = UIDropDownMenu_CreateInfo()
        sep.text = ""
        sep.isTitle = true
        sep.notCheckable = true
        UIDropDownMenu_AddButton(sep, level)

        local search = UIDropDownMenu_CreateInfo()
        local searchLabel = "|cffaaff00Search by name...|r"
        if addon.atlasLootDetected then searchLabel = searchLabel .. " |cff888888(AtlasLoot)|r" end
        search.text = searchLabel
        search.notCheckable = true
        search.func = function()
            CloseDropDownMenus()
            UI:ShowSearchDialog(slot)
        end
        UIDropDownMenu_AddButton(search, level)

        local imp = UIDropDownMenu_CreateInfo()
        imp.text = "|cff00ff00Import from Wowhead...|r"
        imp.notCheckable = true
        imp.func = function()
            StaticPopupDialogs["TBCBIS_IMPORT_WOWHEAD"] = {
                text = "Paste a Wowhead URL or item ID for " .. (addon.SLOT_LABELS[slot] or slot) .. ":",
                button1 = "Add",
                button2 = "Cancel",
                hasEditBox = true,
                editBoxWidth = 350,
                OnShow = function(s)
                    local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
                    if eb then eb:SetFocus() end
                end,
                OnAccept = function(s)
                    local eb = (s and s.editBox) or _G["StaticPopup1EditBox"] or _G["StaticPopup2EditBox"]
                    local input = eb and eb:GetText() or ""
                    local id = addon:ParseWowheadInput(input)
                    if not id then
                        addon:Print("Could not parse a Wowhead item URL/ID from: " .. tostring(input))
                        return
                    end
                    UI:ImportOrSelect(slot, id, "Custom (Wowhead import)")
                end,
                EditBoxOnEnterPressed = function(s)
                    local parent = s:GetParent()
                    if parent.OnAccept then parent.OnAccept(parent) end
                    parent:Hide()
                end,
                EditBoxOnEscapePressed = function(s) s:GetParent():Hide() end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("TBCBIS_IMPORT_WOWHEAD")
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(imp, level)

        -- Allow removing user-added alternatives
        local custom = addon:GetCustomAlts(class, spec, phase, slot)
        if custom and #custom > 0 then
            for _, ci in ipairs(custom) do
                local removeInfo = UIDropDownMenu_CreateInfo()
                local nm = addon:GetItemName(ci.id)
                removeInfo.text = "|cffff6060Remove|r " .. nm
                removeInfo.notCheckable = true
                local capturedId = ci.id
                removeInfo.func = function()
                    addon:RemoveCustomAlt(class, spec, phase, slot, capturedId)
                    -- Reset selection if it pointed past the new list end
                    addon:SetSelectedAlt(class, spec, phase, slot, 1)
                    UI:Refresh()
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(removeInfo, level)
            end
        end

        -- Per-slot note editor
        local noteSep = UIDropDownMenu_CreateInfo()
        noteSep.text = ""; noteSep.disabled = true; noteSep.notCheckable = true
        UIDropDownMenu_AddButton(noteSep, level)

        local noteInfo = UIDropDownMenu_CreateInfo()
        local existingNote = addon:GetNote(class, spec, phase, slot)
        noteInfo.text = (existingNote and "Edit note...") or "Add note..."
        noteInfo.notCheckable = true
        noteInfo.func = function()
            UI:ShowNoteEditor(class, spec, phase, slot)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(noteInfo, level)

        local cancel = UIDropDownMenu_CreateInfo()
        cancel.text = "Cancel"
        cancel.notCheckable = true
        cancel.func = function() CloseDropDownMenus() end
        UIDropDownMenu_AddButton(cancel, level)
    end, "MENU")

    -- Track which item id corresponds to which menu position so we can attach item tooltips
    self.altMenuItemIds = {}
    local pos = 1
    pos = pos + 1  -- skip title row
    for i = 1, #alts do
        self.altMenuItemIds[pos] = alts[i].id
        pos = pos + 1
    end

    ToggleDropDownMenu(1, nil, self.altDropdown, "cursor", 0, 0)

    -- After the dropdown renders, attach item tooltips to each button
    C_Timer.After(0, function()
        local list = _G["DropDownList1"]
        if not list then return end
        for i = 1, 32 do
            local btn = _G["DropDownList1Button" .. i]
            if not btn or not btn:IsShown() then break end
            local itemId = UI.altMenuItemIds[i]
            if itemId and not btn.tbcbisHooked then
                btn.tbcbisHooked = true
                btn:HookScript("OnEnter", function(s)
                    local id = UI.altMenuItemIds[i]
                    if not id then return end
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0")
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cffaaaaaa" .. addon.WOWHEAD_BASE .. id .. "|r", 1, 1, 1, true)
                    GameTooltip:Show()
                    if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                        GameTooltip_ShowCompareItem(GameTooltip)
                    end
                end)
                btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end)
end

-- ─────────────────────────────────────────────
-- Progress bar
-- ─────────────────────────────────────────────

function UI:BuildBadgeStatus()
    local f = self.frame
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 44)
    fs:SetJustifyH("LEFT")
    self.badgeStatus = fs

    -- Hover: show breakdown of unobtained badge items
    local hoverFrame = CreateFrame("Frame", nil, f)
    hoverFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 40)
    hoverFrame:SetSize(380, 16)
    hoverFrame:EnableMouse(true)
    hoverFrame:SetScript("OnEnter", function(self)
        local class = TBCBisTrackerDB.lastClass
        local spec  = TBCBisTrackerDB.lastSpec
        local phase = TBCBisTrackerDB.lastPhase
        local owned, total, items = addon:GetBadgeProgress(class, spec, phase)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Badges of Justice (" .. (addon.PHASE_LABELS[phase] or phase) .. ")", 1, 1, 1)
        if #items == 0 then
            GameTooltip:AddLine("No BoJ-purchasable BiS items in this phase.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine(string.format("You have: %d badges   |cff888888Total cost of unobtained items: %d|r", owned, total), 1, 1, 1)
        GameTooltip:AddLine(" ")
        for _, it in ipairs(items) do
            local name = GetItemInfo(it.entry.id) or ("item:" .. it.entry.id)
            local color = addon:GetItemQualityColor(it.entry.id) or "|cffffffff"
            GameTooltip:AddDoubleLine(
                color .. name .. "|r — " .. (addon.SLOT_LABELS[it.slot] or it.slot),
                it.cost .. " BoJ",
                1, 1, 1, 1, 0.84, 0
            )
        end
        GameTooltip:Show()
    end)
    hoverFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.badgeHover = hoverFrame
end

function UI:BuildFarmPlan()
    local f = self.frame
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22 - STAT_AREA_W, 44)
    fs:SetJustifyH("RIGHT")
    fs:SetText("|cff00d0ff[Hover for farm plan]|r")
    self.farmHint = fs

    local hover = CreateFrame("Frame", nil, f)
    hover:SetSize(160, 16)
    hover:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18 - STAT_AREA_W, 40)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        local class = TBCBisTrackerDB.lastClass
        local spec  = TBCBisTrackerDB.lastSpec
        local phase = TBCBisTrackerDB.lastPhase
        local groups = addon:GetFarmBreakdown(class, spec, phase)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Farm plan — " .. (addon.PHASE_LABELS[phase] or phase))
        if not groups or #groups == 0 then
            GameTooltip:AddLine("Nothing left to farm — all items obtained!", 1, 0.84, 0)
        else
            for _, group in ipairs(groups) do
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("|cffffd700" .. group.label .. "|r", group.count .. " unobtained", 1, 0.84, 0, 0.9, 0.9, 0.9)
                for _, sub in ipairs(group.locations or {}) do
                    if group.type == "reputation" then
                        local fname, requiredStanding, requiredId = addon:ParseRepLocation(sub.location)
                        if fname and requiredStanding then
                            local matched, currentId = addon:GetCurrentReputation(fname)
                            local statusText
                            if currentId then
                                local current = addon.STANDING_NAMES[currentId] or "?"
                                if currentId >= requiredId then
                                    statusText = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:10:10|t |cff00ff00" .. current .. "|r"
                                else
                                    statusText = "|cffff8800" .. current .. " to " .. requiredStanding .. "|r"
                                end
                            else
                                statusText = "|cff888888not yet discovered|r"
                            end
                            GameTooltip:AddDoubleLine("  " .. (matched or fname) .. " (" .. requiredStanding .. ")", statusText, 0.8, 0.85, 0.95, 1, 1, 1)
                        else
                            GameTooltip:AddDoubleLine("  " .. sub.location, sub.count, 0.8, 0.85, 0.95, 1, 1, 1)
                        end
                    else
                        GameTooltip:AddDoubleLine("  " .. sub.location, sub.count, 0.8, 0.85, 0.95, 1, 1, 1)
                    end
                end
            end
        end
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.farmHover = hover
end

-- ─────────────────────────────────────────────
-- Stat-cap side panel
-- ─────────────────────────────────────────────

local STAT_PANEL_W = STAT_AREA_W - 12
local STAT_PANEL_BAR_H = 14
local STAT_PANEL_ROW_H = 38   -- label + bar + spacing
local STAT_PANEL_MAX_ROWS = 8

-- 4-column compact slot ordering used by the integrated BiS preview grid in
-- the right-side panel. Reading order roughly matches the WoW character pane:
-- head/neck/shoulders/back, then armour, jewelry, trinkets, weapons, ranged.
local PREV_GRID_SLOTS = {
    "head", "neck", "shoulder", "back",
    "chest", "wrist", "hands", "waist",
    "legs", "feet", "ring1", "ring2",
    "trinket1", "trinket2", "mainhand", "offhand",
    "ranged",
}

function UI:BuildStatCapPanel()
    local f = self.frame

    -- Vertical divider between gear list area and stat column inside the same frame
    local vdiv = CreateDivider(f, UI_PAL.dividerSoft)
    vdiv:SetPoint("TOPLEFT",    f, "TOPLEFT", LIST_W - 4, -32)
    vdiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LIST_W - 4, 32)
    vdiv:SetWidth(1)
    self.statColDivider = vdiv

    -- Stat column lives INSIDE the main frame on the right side.
    local panel = CreateFrame("Frame", "TBCBisTrackerStatCapPanel", f)
    panel:SetSize(STAT_PANEL_W, FRAME_H - 40)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 6, -30)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 10)
    self.statPanel = panel

    -- ── Section 1: BiS slot preview ──
    local slotsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotsTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad, -UI_PAL.pad)
    slotsTitle:SetText(UI_PAL.accent .. "BiS Preview|r")
    self.statPanelSlotsTitle = slotsTitle

    -- Hint text on the right of the title pointing at minimap right-click for
    -- the standalone preview window with the 3D model.
    local hint = panel:CreateFontString(nil, "OVERLAY")
    SetFontSmall(hint)
    hint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -UI_PAL.pad, -UI_PAL.pad - 2)
    hint:SetText(UI_PAL.muted .. "3D: right-click map icon|r")
    hint:SetJustifyH("RIGHT")
    self.statPanelSlotsHint = hint

    local hdiv = CreateDivider(panel)
    hdiv:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad, -32)
    hdiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -UI_PAL.pad, -32)
    hdiv:SetHeight(1)

    -- Build the 4-column compact slot grid centred in the panel.
    local panelInnerW = STAT_PANEL_W - 2 * UI_PAL.pad
    local SLOT_SZ = 30
    local SLOT_GAP_X = 6
    local SLOT_GAP_Y = 4
    local cols = 4
    local rows = math.ceil(#PREV_GRID_SLOTS / cols)
    local gridW = cols * SLOT_SZ + (cols - 1) * SLOT_GAP_X
    local gridStartX = UI_PAL.pad + (panelInnerW - gridW) / 2
    local gridStartY = -42

    self.integratedSlotBtns = {}
    for i, slot in ipairs(PREV_GRID_SLOTS) do
        local col = (i - 1) % cols
        local rowI = math.floor((i - 1) / cols)
        local x = gridStartX + col * (SLOT_SZ + SLOT_GAP_X)
        local y = gridStartY - rowI * (SLOT_SZ + SLOT_GAP_Y)

        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(SLOT_SZ, SLOT_SZ)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        btn._slot = slot

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        btn.bg = bg

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon = icon

        local mark = btn:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        mark:SetSize(12, 12); mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1); mark:Hide()
        btn.mark = mark

        btn:SetScript("OnEnter", function(self)
            if self._itemId and self._itemId > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetHyperlink("item:" .. self._itemId .. ":0:0:0:0:0:0:0")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(UI_PAL.muted .. (addon.SLOT_LABELS[self._slot] or self._slot) .. "|r", 1, 1, 1)
                GameTooltip:AddLine(self._obtained and "|cff60ff60Obtained|r" or "|cff888888Not obtained|r", 1, 1, 1)
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(addon.SLOT_LABELS[self._slot] or self._slot, 1, 1, 1)
                GameTooltip:AddLine("|cff888888No BiS pick set|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.integratedSlotBtns[slot] = btn
    end

    -- Section divider between slots and stat caps.
    local slotsBottom = gridStartY - rows * (SLOT_SZ + SLOT_GAP_Y) + SLOT_GAP_Y - 6
    local sectDiv = CreateDivider(panel, UI_PAL.divider)
    sectDiv:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad, slotsBottom)
    sectDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -UI_PAL.pad, slotsBottom)
    sectDiv:SetHeight(1)

    -- ── Section 2: Stat Caps ──
    -- Always sums the stats of the SELECTED BiS pick for each slot in the
    -- currently-active phase tab. No mode dropdown — switching alts directly
    -- updates the bars.
    local statTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad, slotsBottom - 8)
    statTitle:SetText(UI_PAL.accent .. "Stat Caps|r  " .. UI_PAL.muted .. "Selected BiS|r")
    self.statPanelTitle = statTitle

    local sdivY = slotsBottom - 22
    local bodyY = slotsBottom - 30
    local sdiv = CreateDivider(panel, UI_PAL.dividerSoft)
    sdiv:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad, sdivY)
    sdiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -UI_PAL.pad, sdivY)
    sdiv:SetHeight(1)
    self.statPanelBodyDiv = sdiv

    -- Body container
    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", UI_PAL.pad + 4, bodyY)
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -UI_PAL.pad - 4, 32)
    self.statPanelBody = body

    -- Pool of stat rows
    self.statRowPool = {}
    local rowW = STAT_PANEL_W - 2 * (UI_PAL.pad + 4)
    for i = 1, STAT_PANEL_MAX_ROWS do
        local row = CreateFrame("Frame", nil, body)
        row:SetSize(rowW, STAT_PANEL_ROW_H)
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(i-1) * STAT_PANEL_ROW_H)
        row:EnableMouse(true)

        local lbl = row:CreateFontString(nil, "OVERLAY")
        SetFontSmall(lbl)
        lbl:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWidth(rowW)
        row.lbl = lbl

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bg:SetVertexColor(unpack(UI_PAL.barTrack))
        bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -15)
        bg:SetSize(rowW, STAT_PANEL_BAR_H)
        row.bg = bg

        local fill = row:CreateTexture(nil, "ARTWORK")
        fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        fill:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -15)
        fill:SetSize(0, STAT_PANEL_BAR_H)
        row.fill = fill

        local val = row:CreateFontString(nil, "OVERLAY")
        SetFontSmall(val)
        val:SetPoint("TOP", row, "TOP", 0, -16)
        val:SetJustifyH("CENTER")
        row.val = val

        row:SetScript("OnEnter", function(self)
            local data = self._data
            if not data then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(data.label, 1, 1, 1)
            if data.cap and data.cap > 0 then
                if data.missing > 0 then
                    GameTooltip:AddLine(string.format("Current: %d / %d  (need %d more)", data.current, data.cap, data.missing), 1, 0.6, 0.2)
                else
                    GameTooltip:AddLine(string.format("Capped: %d / %d  (+%d over)", data.current, data.cap, data.current - data.cap), 0.2, 1, 0.2)
                end
            else
                GameTooltip:AddLine(string.format("Total: %d", data.current), 1, 1, 1)
            end
            if data.contributors and #data.contributors > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(UI_PAL.muted .. "Top contributors:|r", 1, 1, 1)
                table.sort(data.contributors, function(a, b) return a.value > b.value end)
                for i = 1, math.min(6, #data.contributors) do
                    local c = data.contributors[i]
                    local slotLabel = addon.SLOT_LABELS[c.slot] or c.slot
                    local name = addon:GetItemName(c.itemId)
                    GameTooltip:AddDoubleLine(slotLabel .. " — " .. name, "+" .. c.value, 0.8, 0.85, 0.95, 1, 1, 1)
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Hide()
        self.statRowPool[i] = row
    end

    -- Footer divider above note
    local fdiv = CreateDivider(panel, UI_PAL.dividerSoft)
    fdiv:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", UI_PAL.pad, 26)
    fdiv:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -UI_PAL.pad, 26)
    fdiv:SetHeight(1)
    self.statPanelFooterDiv = fdiv

    -- Footer note
    local note = panel:CreateFontString(nil, "OVERLAY")
    SetFontSmall(note)
    note:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", UI_PAL.pad + 4, 8)
    note:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -UI_PAL.pad - 4, 8)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.6, 0.6, 0.6, 1)
    self.statPanelNote = note

    -- WoW Forever has no rating caps: the same space lists where the
    -- still-missing items come from (the farm plan, no longer hidden in a hover).
    if addon:IsForever() then
        statTitle:SetText(UI_PAL.accent .. "Where to get it|r  " .. UI_PAL.muted .. "still needed|r")
        fdiv:Hide()
        self.farmLines = {}
        local lineW = STAT_PANEL_W - 2 * (UI_PAL.pad + 4)
        for i = 1, 16 do
            local line = CreateFrame("Frame", nil, body)
            line:SetSize(lineW, 16)
            line:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(i - 1) * 17)
            local kind = line:CreateFontString(nil, "OVERLAY")
            SetFontSmall(kind)
            kind:SetPoint("LEFT", line, "LEFT", 0, 0)
            kind:SetWidth(62)
            kind:SetJustifyH("LEFT")
            line.kind = kind
            local count = line:CreateFontString(nil, "OVERLAY")
            SetFontSmall(count)
            count:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            count:SetJustifyH("RIGHT")
            line.count = count
            local where = line:CreateFontString(nil, "OVERLAY")
            SetFontSmall(where)
            where:SetPoint("LEFT", kind, "RIGHT", 4, 0)
            where:SetPoint("RIGHT", count, "LEFT", -4, 0)
            where:SetJustifyH("LEFT")
            where:SetWordWrap(false)
            line.where = where
            line:Hide()
            self.farmLines[i] = line
        end
    end

end

local FARM_TYPE_LABELS = {
    raid = "Raid", heroic = "Heroic", dungeon = "Dungeon", crafted = "Profession",
    reputation = "Vendor", world = "World", quest = "Quest", pvp = "PvP",
}

-- Forever side panel: still-needed items grouped by where they come from.
function UI:RefreshFarmPanel(class, spec, phase)
    for _, line in ipairs(self.farmLines) do line:Hide() end
    local groups = addon:GetFarmBreakdown(class, spec, phase)
    if #groups == 0 then
        self.statPanelNote:SetText(UI_PAL.accent .. "Everything obtained!|r")
        return
    end
    local i, hidden = 0, 0
    for _, group in ipairs(groups) do
        local color = SOURCE_TYPE_COLORS[group.type] or "|cffcccccc"
        for n, loc in ipairs(group.locations) do
            if i < #self.farmLines then
                i = i + 1
                local line = self.farmLines[i]
                line.kind:SetText(n == 1 and (color .. (FARM_TYPE_LABELS[group.type] or group.type) .. "|r") or "")
                local where = ShortSource({ source = loc.location .. " (x)" })
                local first = loc.items and loc.items[1] and loc.items[1].entry
                local prof = first and addon:ParseCraftingProfession(first)
                if prof and not addon:GetPlayerProfessionLevel(prof) then
                    where = "|cffff6b5a" .. where .. " (not learned)|r"
                end
                line.where:SetText(where)
                line.count:SetText(UI_PAL.muted .. loc.count .. "|r")
                line:Show()
            else
                hidden = hidden + loc.count
            end
        end
    end
    if hidden > 0 then
        self.statPanelNote:SetText(UI_PAL.muted .. "+" .. hidden .. " more|r")
    end
end

function UI:RefreshStatCaps()
    if not self.statPanel then return end
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local mode  = "selected"

    -- Hide all rows
    for _, row in ipairs(self.statRowPool) do row:Hide() end

    -- Refresh the integrated BiS slot grid above the stat caps. We mirror
    -- the standalone preview window: faded slot icon when no pick is set,
    -- item icon (with green checkmark when obtained) when a BiS pick exists.
    if self.integratedSlotBtns then
        for slot, btn in pairs(self.integratedSlotBtns) do
            local entry = (class and spec and phase) and addon:GetSlotItem(class, spec, phase, slot) or nil
            if entry and entry.id and entry.id > 0 then
                local texture = select(10, GetItemInfo(entry.id))
                btn._itemId   = entry.id
                btn._obtained = addon:IsObtained(class, spec, phase, slot)
                btn.icon:SetTexture(texture or addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
                btn.icon:SetAlpha(1)
                btn.mark:SetShown(btn._obtained == true)
            else
                btn._itemId   = nil
                btn._obtained = false
                btn.icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
                btn.icon:SetAlpha(0.35)
                btn.mark:Hide()
            end
        end
    end

    if not (class and spec) then
        self.statPanelNote:SetText("No spec selected.")
        return
    end

    if self.farmLines then
        self.statPanelNote:SetText("")
        self:RefreshFarmPanel(class, spec, phase)
        return
    end

    local rows, pending = addon:GetCapStatus(class, spec, phase, mode)
    if not rows then
        self.statPanelNote:SetText("|cff888888No stat caps configured for " .. spec .. ".|r")
        return
    end

    local showCount = math.min(#rows, STAT_PANEL_MAX_ROWS)
    for i = 1, showCount do
        local data = rows[i]
        local row = self.statRowPool[i]
        row._data = data
        local pct = (data.cap > 0) and math.min(1, data.current / data.cap) or 0
        local labelText
        if data.info then
            labelText = "|cffaaaaaa" .. data.label .. "|r"
        elseif data.missing == 0 and data.cap > 0 then
            labelText = "|cff60ff60" .. data.label .. "|r |TInterface\\RAIDFRAME\\ReadyCheck-Ready:10:10|t"
        else
            labelText = data.label
        end
        row.lbl:SetText(labelText)

        if data.info then
            -- Info rows: no bar, just show value
            row.bg:Hide()
            row.fill:Hide()
            row.val:SetText("|cffffffff" .. data.current .. "|r")
            row.val:ClearAllPoints()
            row.val:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -16)
        else
            row.bg:Show()
            row.fill:Show()
            row.val:ClearAllPoints()
            row.val:SetPoint("TOP", row, "TOP", 0, -17)
            local barW = (STAT_PANEL_W - 24) * pct
            row.fill:SetWidth(math.max(0.01, barW))
            if data.missing == 0 then
                row.fill:SetVertexColor(0.20, 0.80, 0.20, 0.85)
            elseif pct > 0.6 then
                row.fill:SetVertexColor(0.85, 0.70, 0.20, 0.85)
            else
                row.fill:SetVertexColor(0.85, 0.30, 0.20, 0.85)
            end
            local pctNum = math.floor(pct * 100 + 0.5)
            local txt
            if data.missing == 0 then
                txt = string.format("|cff60ff60%d / %d  (%d%%)|r", data.current, data.cap, pctNum)
            else
                txt = string.format("%d / %d  |cff888888%d%%|r  |cffff8800(-%d)|r", data.current, data.cap, pctNum, data.missing)
            end
            row.val:SetText(txt)
        end
        row:Show()
    end

    if pending and pending > 0 then
        self.statPanelNote:SetText("|cffaaaaaa" .. pending .. " items loading…|r")
    elseif #rows > STAT_PANEL_MAX_ROWS then
        self.statPanelNote:SetText("|cff888888…and " .. (#rows - STAT_PANEL_MAX_ROWS) .. " more|r")
    else
        -- Multi-line note that fits the panel width
        self.statPanelNote:SetText("|cff666666Item base stats only.|r\n|cff666666Gems & enchants not included.|r")
    end
end

function UI:BuildTierStatus()
    local f = self.frame
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 60)
    fs:SetJustifyH("LEFT")
    self.tierStatus = fs

    -- Hover area covering the tier-set text — explains 2pc/4pc bonuses
    local hover = CreateFrame("Frame", nil, f)
    hover:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 58)
    hover:SetSize(380, 16)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        local class = TBCBisTrackerDB.lastClass
        local spec  = TBCBisTrackerDB.lastSpec
        local phase = TBCBisTrackerDB.lastPhase
        local progress = addon:GetTierProgress(class, spec, phase)
        if not progress or not next(progress) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Tier set tracker", 1, 1, 1)
            GameTooltip:AddLine("No tier-set BiS items in this phase for your spec.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Tier set progress (" .. (addon.PHASE_LABELS[phase] or phase) .. ")", 1, 1, 1)
        GameTooltip:AddLine("Counts BiS-listed tier pieces you've obtained. 2/4 piece bonuses noted.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        local order = { "T4", "T5", "T6", "T6.5" }
        for _, t in ipairs(order) do
            local p = progress[t]
            if p and p.total > 0 then
                local bonusText = ""
                if p.obtained >= 4 then bonusText = " — 4-piece bonus active!"
                elseif p.obtained >= 2 then bonusText = " — 2-piece bonus active"
                end
                GameTooltip:AddDoubleLine(t, p.obtained .. " / " .. p.total .. bonusText, 0.9, 0.9, 0.9, 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.tierHover = hover
end

function UI:RefreshTierStatus()
    if not self.tierStatus then return end
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local progress = addon:GetTierProgress(class, spec, phase)

    -- Stable ordering (T4, T5, T6, T6.5)
    local order = { "T4", "T5", "T6", "T6.5" }
    local parts = {}
    for _, t in ipairs(order) do
        local p = progress[t]
        if p and p.total > 0 then
            local bonus
            if p.obtained >= 4 then bonus = " |cffff8000(4pc!)|r"
            elseif p.obtained >= 2 then bonus = " |cff00ff00(2pc)|r"
            else bonus = ""
            end
            local color = (p.obtained >= p.total) and "|cffffd700" or "|cffaaaaaa"
            table.insert(parts, color .. t .. ": " .. p.obtained .. "/" .. p.total .. "|r" .. bonus)
        end
    end
    if #parts == 0 then
        self.tierStatus:SetText("")
    else
        self.tierStatus:SetText("|cff888888Tier set:|r  " .. table.concat(parts, "   "))
    end
end

function UI:RefreshBadgeStatus()
    if not self.badgeStatus then return end
    local class = TBCBisTrackerDB.lastClass
    local spec  = TBCBisTrackerDB.lastSpec
    local phase = TBCBisTrackerDB.lastPhase
    local owned, total, items = addon:GetBadgeProgress(class, spec, phase)
    -- Compact badge readout. The verbose breakdown lives in the hover tooltip.
    -- Format: "[icon] 0 / 66 BoJ  ·  2 items"
    local coin = "|TInterface\\Icons\\Spell_Holy_ChampionsBond:14:14|t"
    if total == 0 then
        self.badgeStatus:SetText(coin .. " " .. UI_PAL.muted .. owned .. " BoJ|r")
    elseif owned >= total then
        self.badgeStatus:SetText(string.format(
            "%s %s%d / %d BoJ|r  %s|cff60ff60enough!|r  %s%d items|r",
            coin, UI_PAL.accent, owned, total, UI_PAL.muted .. "·|r ", UI_PAL.muted, #items
        ))
    else
        local diff = total - owned
        self.badgeStatus:SetText(string.format(
            "%s %s%d / %d BoJ|r  %s|cffff8800need %d more|r  %s%d items|r",
            coin, UI_PAL.mutedSoft, owned, total, UI_PAL.muted .. "·|r ", diff, UI_PAL.muted .. "· ", #items
        ))
    end
end

function UI:BuildProgressBar()
    local f = self.frame

    -- Divider above the footer
    local fdiv = CreateDivider(f, UI_PAL.dividerSoft)
    fdiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 38)
    fdiv:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20 - STAT_AREA_W, 38)
    fdiv:SetHeight(1)

    local container = CreateFrame("Frame", nil, f)
    container:SetSize(LIST_W - 40, PROGRESS_H)
    container:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 12)
    container:EnableMouse(true)
    self.progressContainer = container

    -- Text on the right, slim bar filling the rest
    local txt = container:CreateFontString(nil, "OVERLAY")
    SetFontNormal(txt)
    txt:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    txt:SetJustifyH("RIGHT")
    self.progressTxt = txt

    local trackW = LIST_W - 40 - 190
    local track = container:CreateTexture(nil, "BACKGROUND")
    track:SetSize(trackW, 10)
    track:SetPoint("LEFT", container, "LEFT", 0, 0)
    track:SetColorTexture(0.11, 0.12, 0.14, 1)
    self.progressTrackW = trackW

    local fill = container:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetHeight(10)
    fill:SetColorTexture(0.25, 0.62, 0.18, 1)
    self.progressFill = fill

    container:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("BiS progress", 1, 1, 1)
        GameTooltip:AddLine("How many BiS slots you've ticked off. Items you equip or carry are ticked automatically.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    container:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ─────────────────────────────────────────────
-- Populate gear rows (called on every Refresh)
-- ─────────────────────────────────────────────

function UI:Refresh()
    if not self.frame then return end
    local class  = TBCBisTrackerDB.lastClass
    local spec   = TBCBisTrackerDB.lastSpec
    local phase  = TBCBisTrackerDB.lastPhase
    local missingOnly = TBCBisTrackerDB.showMissingOnly

    -- Hide all rows first
    for _, row in ipairs(self.rowPool) do row:Hide() end

    local data = addon:GetPhaseData(class, spec, phase)

    local browsing = IsBrowsing()
    self:ApplyLayout()
    if browsing then
        local info = addon.CLASS_INFO[class]
        local home = addon.CLASS_INFO[PlayerClass()]
        self.browseBanner.txt:SetText(
            "Browsing |cff" .. info.color .. info.name .. "|r: planning only. Ticks stay on your |cff"
            .. home.color .. home.name .. "|r.")
        self.browseBanner.back:SetText("Back to " .. home.name)
    end

    if not data then
        self:UpdateScrollRange(0)
        self:UpdateProgress(0, 0)
        return
    end

    local rowIdx = 0
    local obtained, total = 0, 0

    local sourceFilter = TBCBisTrackerDB.sourceFilter or "all"
    for _, slot in ipairs(addon.SLOTS) do
        local entry, selectedIdx, altCount = addon:GetSlotItem(class, spec, phase, slot)
        local isObtained = entry and addon:IsObtained(class, spec, phase, slot) or false

        if entry then
            total = total + 1
            if isObtained then obtained = obtained + 1 end
        end

        local matchesSource = (sourceFilter == "all") or (entry and entry.sourceType == sourceFilter)

        if not (missingOnly and isObtained) and matchesSource then
            rowIdx = rowIdx + 1
            local row = self.rowPool[rowIdx]
            if not row then break end

            -- Position row
            row:SetWidth(SCROLL_W)
            row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 0, -(rowIdx - 1) * (ROW_H + ROW_PAD))
            row:Show()
            row.slotKey = slot

            -- Slot icon until the item's own icon is known
            row.iconTex:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.iconBorder:SetColorTexture(0.35, 0.35, 0.35, 1)
            row.slotLbl:SetText(addon.SLOT_LABELS[slot] or slot)

            if entry then
                -- Populated slot — show item details
                local itemId   = entry.id
                row.itemId     = itemId or 0
                row.questId    = entry.questId
                local itemName = addon:GetItemName(itemId)
                local color    = addon:GetItemQualityColor(itemId)
                local texture  = select(10, GetItemInfo(itemId))
                    or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemId))
                if texture then row.iconTex:SetTexture(texture) end
                row.iconBorder:SetColorTexture(ItemQualityRGB(itemId))
                local suffix = SuffixHint(entry, itemName)
                local suffixText = suffix and ("|cffa39d8c" .. suffix .. "|r") or ""
                local altSuffix = (altCount > 1) and (" |cff888888[" .. selectedIdx .. "/" .. altCount .. "]|r") or ""

                local tierInfo = addon:GetTierInfo(entry)
                local tierPrefix = ""
                if tierInfo then
                    tierPrefix = "|cffffd700[" .. tierInfo.tier .. "]|r "
                end

                -- Stash the user note for the hover tooltip; show a small
                -- pencil icon + a short preview when one is set.
                local userNote = addon:GetNote(class, spec, phase, slot)
                row.userNote = userNote
                local noteSuffix = ""
                if userNote and userNote ~= "" then
                    local preview = userNote:sub(1, 36)
                    if #userNote > 36 then preview = preview .. "…" end
                    noteSuffix = "  |TInterface\\GossipFrame\\TrainerGossipIcon:12:12|t |cffd6b85a" .. preview .. "|r"
                end
                row.itemLbl:SetText(tierPrefix .. color .. itemName .. "|r" .. suffixText .. altSuffix .. noteSuffix)

                -- Source column — short category label inline; full text shown
                -- in the source-column hover tooltip.
                local srcColor = SOURCE_TYPE_COLORS[entry.sourceType] or "|cffcccccc"
                local srcShort = SOURCE_TYPE_LABELS[entry.sourceType] or (entry.sourceType or "Unknown")

                -- Stash the full text for the hover handler
                local fullSource = entry.source or "Unknown"
                if entry.note then fullSource = entry.note .. " (" .. fullSource .. ")" end
                row.sourceFull = fullSource
                row.sourceType = entry.sourceType
                row.profStatus = nil

                -- Inline indicators (texture-based — WoW renders Blizzard textures
                -- reliably, unlike unicode glyphs that depend on the font).
                local indicators = ""
                local detail = ShortSource(entry)
                local detailColor = "|cffa39d8c"
                if entry.sourceType == "crafted" then
                    local prof = addon:ParseCraftingProfession(entry)
                    if prof then
                        local level = addon:GetPlayerProfessionLevel(prof)
                        if level then
                            indicators = indicators .. " |TInterface\\RAIDFRAME\\ReadyCheck-Ready:12:12|t"
                            row.profStatus = "|cff00ff00You have " .. prof .. " (" .. level .. ").|r"
                        else
                            -- Spelled out instead of an unexplained red cross.
                            detail = "Needs " .. detail
                            detailColor = "|cffff6b5a"
                            row.profStatus = "|cffff6060You don't have " .. prof .. ".|r"
                        end
                    end
                end
                row.srcDetail:SetText(detailColor .. detail .. "|r")
                if entry.questId and entry.questId > 0 then
                    -- Quest ! icon — the gold "available quest" exclamation mark
                    indicators = indicators .. " |TInterface\\GossipFrame\\AvailableQuestIcon:12:12|t"
                end
                row.srcLbl:SetText(srcColor .. srcShort .. "|r" .. indicators)

                local slotName = addon.SLOT_LABELS[slot] or slot
                if tierInfo then
                    row.slotLbl:SetText("|TInterface\\AchievementFrame\\UI-Achievement-TinyShield:12:12|t " .. slotName)
                else
                    row.slotLbl:SetText(slotName)
                end

                -- Ticks belong to your own class; browsing shows a dash.
                row.chk:SetShown(not browsing)
                row.dash:SetShown(browsing)
                row.chk:Enable()
                row.chk:SetChecked(isObtained)
                row.chk:SetScript("OnClick", function(chkSelf)
                    local val = chkSelf:GetChecked()
                    addon:SetObtained(class, spec, phase, slot, val)
                    UI:Refresh()
                end)

                if isObtained then
                    row.itemLbl:SetTextColor(0.4, 0.4, 0.4, 1)
                    row.slotLbl:SetTextColor(0.4, 0.4, 0.4, 1)
                elseif tierInfo then
                    row.slotLbl:SetTextColor(1, 0.82, 0, 1)
                else
                    row.slotLbl:SetTextColor(0.7, 0.7, 0.7, 1)
                end
            else
                -- Empty slot — invite the user to drop or right-click to import.
                row.itemId = 0
                row.questId = nil
                row.sourceFull = nil
                row.sourceType = nil
                row.profStatus = nil
                row.userNote = nil
                row.itemLbl:SetText("|cff666666No BiS pick set|r  |cff444444· right-click to import|r")
                row.srcLbl:SetText("|cff444444-|r")
                row.srcDetail:SetText("")
                row.chk:SetChecked(false)
                row.chk:Hide()
                row.dash:Hide()
                row.slotLbl:SetTextColor(0.45, 0.45, 0.45, 1)
            end
        end
    end

    self:UpdateScrollRange(rowIdx)

    self:UpdateProgress(obtained, total)
    self:RefreshPhaseTabs()
    self:RefreshBadgeStatus()
    self:RefreshTierStatus()
    self:RefreshStatCaps()
end

function UI:UpdateProgress(obtained, total)
    if total == 0 then
        self.progressFill:SetWidth(1)
        self.progressTxt:SetText("|cffaaaaaaNo data for this selection.|r")
        return
    end

    local pct = obtained / total
    self.progressFill:SetWidth(math.max(1, self.progressTrackW * pct))
    if obtained == total then
        self.progressFill:SetColorTexture(0.9, 0.75, 0.1, 1)  -- gold when complete
        self.progressTxt:SetText("|cffffd700All " .. total .. " obtained!|r")
    else
        self.progressFill:SetColorTexture(0.25, 0.62, 0.18, 1)
        self.progressTxt:SetText("|cff6fdc55" .. obtained .. " / " .. total .. "|r obtained  "
            .. UI_PAL.muted .. math.floor(pct * 100) .. "%|r")
    end
end

-- ─────────────────────────────────────────────
-- BiS Preview window — character-pane-style mockup with 3D model,
-- slot icons, and stats summary. Triggered by right-click on the
-- minimap button or "/tbcbis preview".
-- ─────────────────────────────────────────────

local PREV_SLOT     = 40
local PREV_GAP      = 6
local PREV_PAD      = 10
-- Match the WoW character pane distribution: left column of 7 + right column
-- of 7 + 3 weapons across the bottom. The empty middle is for the optional
-- 3D model.
local PREV_LEFT_SLOTS   = { "head", "neck", "shoulder", "chest", "waist", "legs", "feet" }
local PREV_RIGHT_SLOTS  = { "wrist", "hands", "ring1", "ring2", "trinket1", "trinket2", "back" }
local PREV_BOTTOM_SLOTS = { "mainhand", "offhand", "ranged" }
local PREV_COL_ROWS     = math.max(#PREV_LEFT_SLOTS, #PREV_RIGHT_SLOTS)

-- Width math: column width = pad + slot + pad on each side, with a configurable
-- middle area between them. Compact = 110 px gap, model = 220 px gap.
local PREV_COL_W      = PREV_PAD + PREV_SLOT + PREV_PAD
local PREV_MID_COMPACT = 110
local PREV_MID_WITH_MODEL = 220
local PREV_W_COMPACT      = 2 * PREV_COL_W + PREV_MID_COMPACT
local PREV_W_WITH_MODEL   = 2 * PREV_COL_W + PREV_MID_WITH_MODEL

local PREV_HEADER_H = 48
local PREV_FOOTER_H = 90  -- bottom-row weapons + spacing + stats divider + text
local PREV_H = PREV_HEADER_H + PREV_COL_ROWS * (PREV_SLOT + PREV_GAP) - PREV_GAP + PREV_FOOTER_H

function UI:BuildBisPreview()
    if self.previewFrame then return self.previewFrame end

    local f = CreateFrame("Frame", "TBCBisTrackerPreview", UIParent, "BasicFrameTemplateWithInset")
    local startW = (TBCBisTrackerDB.previewShowModel and PREV_W_WITH_MODEL) or PREV_W_COMPACT
    f:SetSize(startW, PREV_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:Hide()
    self.previewFrame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -6)
    title:SetText(UI_PAL.accent .. "BiS Preview|r")
    self.previewTitle = title

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", f, "TOP", 0, -28)
    self.previewSubtitle = subtitle

    -- "3D model" toggle button — small text button just under the close X.
    local toggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    toggle:SetSize(76, 18)
    toggle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -8)
    toggle:SetText(TBCBisTrackerDB.previewShowModel and "Hide model" or "Show model")
    toggle:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("3D model preview", 1, 1, 1)
        GameTooltip:AddLine("Toggle the player model on the right of the slot grid.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    toggle:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self.previewModelToggle = toggle

    -- 3D model panel — fills the middle area between the two columns,
    -- below the header and above the footer (bottom row + stats).
    local model = CreateFrame("PlayerModel", nil, f)
    model:SetPoint("TOPLEFT", f, "TOPLEFT", PREV_COL_W, -PREV_HEADER_H)
    model:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PREV_COL_W, PREV_FOOTER_H)
    if model.SetUnit then model:SetUnit("player") end
    if model.SetFacing then model:SetFacing(0.4) end
    model:SetShown(TBCBisTrackerDB.previewShowModel == true)
    self.previewModel = model
    -- Drag-to-rotate
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(self) self._rot_start = GetCursorPosition() end)
    model:SetScript("OnMouseUp",   function(self) self._rot_start = nil end)
    model:SetScript("OnUpdate", function(self)
        if self._rot_start then
            local x = GetCursorPosition()
            self:SetFacing((self:GetFacing() or 0) + (x - self._rot_start) * 0.005)
            self._rot_start = x
        end
    end)

    toggle:SetScript("OnClick", function(btn)
        local newVal = not TBCBisTrackerDB.previewShowModel
        TBCBisTrackerDB.previewShowModel = newVal
        btn:SetText(newVal and "Hide model" or "Show model")
        f:SetWidth(newVal and PREV_W_WITH_MODEL or PREV_W_COMPACT)
        if newVal then
            model:Show()
            UI:RefreshBisPreview()
        else
            model:Hide()
        end
    end)

    -- Slot button factory
    local function makeSlotBtn(parent, x, y, slot)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(PREV_SLOT, PREV_SLOT)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        btn._slot = slot

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        btn.bg = bg

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- crop default icon border
        icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon = icon

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetSize(PREV_SLOT + 24, PREV_SLOT + 24)
        border:SetPoint("CENTER")
        btn.border = border

        local mark = btn:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        mark:SetSize(16, 16)
        mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
        mark:Hide()
        btn.mark = mark

        btn:SetScript("OnEnter", function(self)
            if self._itemId and self._itemId > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self._itemId .. ":0:0:0:0:0:0:0")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(UI_PAL.muted .. (addon.SLOT_LABELS[self._slot] or self._slot) .. "|r", 1, 1, 1)
                if self._obtained then
                    GameTooltip:AddLine("|cff60ff60Obtained|r", 1, 1, 1)
                else
                    GameTooltip:AddLine("|cff888888Not obtained|r", 1, 1, 1)
                end
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(addon.SLOT_LABELS[self._slot] or self._slot, 1, 1, 1)
                GameTooltip:AddLine("|cff888888No BiS pick set|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end

    self.previewSlotBtns = {}

    -- Left column — anchored to TOPLEFT.
    local colTopY = -PREV_HEADER_H
    for i, slot in ipairs(PREV_LEFT_SLOTS) do
        local x = PREV_PAD
        local y = colTopY - (i - 1) * (PREV_SLOT + PREV_GAP)
        self.previewSlotBtns[slot] = makeSlotBtn(f, x, y, slot)
    end

    -- Right column — anchored to TOPRIGHT (positions are relative to TOPLEFT
    -- but use the right edge of the *compact* width; right column moves with
    -- the frame's right edge through SetPoint when shown with the model).
    for i, slot in ipairs(PREV_RIGHT_SLOTS) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(PREV_SLOT, PREV_SLOT)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PREV_PAD, colTopY - (i - 1) * (PREV_SLOT + PREV_GAP))
        btn._slot = slot
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        btn.bg = bg
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon = icon
        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetSize(PREV_SLOT + 24, PREV_SLOT + 24)
        border:SetPoint("CENTER")
        btn.border = border
        local mark = btn:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        mark:SetSize(16, 16); mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2); mark:Hide()
        btn.mark = mark
        btn:SetScript("OnEnter", function(self)
            if self._itemId and self._itemId > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetHyperlink("item:" .. self._itemId .. ":0:0:0:0:0:0:0")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(UI_PAL.muted .. (addon.SLOT_LABELS[self._slot] or self._slot) .. "|r", 1, 1, 1)
                GameTooltip:AddLine(self._obtained and "|cff60ff60Obtained|r" or "|cff888888Not obtained|r", 1, 1, 1)
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(addon.SLOT_LABELS[self._slot] or self._slot, 1, 1, 1)
                GameTooltip:AddLine("|cff888888No BiS pick set|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.previewSlotBtns[slot] = btn
    end

    -- Bottom row (3 weapons), centered horizontally.
    local bottomTotal = #PREV_BOTTOM_SLOTS * PREV_SLOT + (#PREV_BOTTOM_SLOTS - 1) * 8
    local bottomY = -(PREV_HEADER_H + PREV_COL_ROWS * (PREV_SLOT + PREV_GAP) - PREV_GAP + 4)
    for i, slot in ipairs(PREV_BOTTOM_SLOTS) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(PREV_SLOT, PREV_SLOT)
        -- Anchor relative to TOP center so it stays centered when the frame width changes
        local xOff = (i - 1) * (PREV_SLOT + 8) - bottomTotal / 2 + PREV_SLOT / 2
        btn:SetPoint("TOP", f, "TOP", xOff, bottomY)
        btn._slot = slot
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        btn.bg = bg
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon = icon
        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetSize(PREV_SLOT + 24, PREV_SLOT + 24); border:SetPoint("CENTER")
        btn.border = border
        local mark = btn:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        mark:SetSize(16, 16); mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2); mark:Hide()
        btn.mark = mark
        btn:SetScript("OnEnter", function(self)
            if self._itemId and self._itemId > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetHyperlink("item:" .. self._itemId .. ":0:0:0:0:0:0:0")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(UI_PAL.muted .. (addon.SLOT_LABELS[self._slot] or self._slot) .. "|r", 1, 1, 1)
                GameTooltip:AddLine(self._obtained and "|cff60ff60Obtained|r" or "|cff888888Not obtained|r", 1, 1, 1)
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(addon.SLOT_LABELS[self._slot] or self._slot, 1, 1, 1)
                GameTooltip:AddLine("|cff888888No BiS pick set|r", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.previewSlotBtns[slot] = btn
    end

    -- Stats summary at the bottom — anchored to bottom edges so it follows
    -- frame width changes when the model toggle resizes the frame.
    local statsLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsLbl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PREV_PAD, 10)
    statsLbl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PREV_PAD, 10)
    statsLbl:SetJustifyH("CENTER")
    self.previewStatsLbl = statsLbl

    local statsDiv = CreateDivider(f, UI_PAL.dividerSoft)
    statsDiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PREV_PAD, 28)
    statsDiv:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PREV_PAD, 28)
    statsDiv:SetHeight(1)

    return f
end

function UI:RefreshBisPreview(class, spec, phase)
    class = class or TBCBisTrackerDB.lastClass
    spec  = spec  or TBCBisTrackerDB.lastSpec
    phase = phase or TBCBisTrackerDB.lastPhase
    if not (self.previewFrame and class and spec and phase) then return end

    -- Title context
    local info = addon.CLASS_INFO[class]
    local subtitle = ""
    if info then
        subtitle = "|cff" .. info.color .. info.name .. " " .. spec .. "|r  " ..
                   UI_PAL.muted .. (addon.PHASE_LABELS[phase] or phase) .. "|r"
    end
    self.previewSubtitle:SetText(subtitle)

    -- Reset the 3D model if visible — undress the player and we'll re-try-on each pick.
    local showModel = self.previewModel and self.previewModel:IsShown()
    if showModel then
        if self.previewModel.SetUnit then self.previewModel:SetUnit("player") end
        if self.previewModel.Undress then self.previewModel:Undress() end
    end

    -- Update each slot button — show item icon if BiS pick exists, faded slot icon otherwise.
    for slot, btn in pairs(self.previewSlotBtns) do
        local entry = addon:GetSlotItem(class, spec, phase, slot)
        if entry and entry.id and entry.id > 0 then
            local _, link = GetItemInfo(entry.id)
            local texture = select(10, GetItemInfo(entry.id))
            btn._itemId = entry.id
            btn._obtained = addon:IsObtained(class, spec, phase, slot)
            btn.icon:SetTexture(texture or addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
            btn.icon:SetAlpha(1)
            btn.mark:SetShown(btn._obtained == true)
            if showModel and link and self.previewModel.TryOn then
                self.previewModel:TryOn(link)
            end
        else
            btn._itemId = nil
            btn._obtained = false
            btn.icon:SetTexture(addon.SLOT_ICONS[slot] or "Interface\\Icons\\INV_Misc_QuestionMark")
            btn.icon:SetAlpha(0.35)
            btn.mark:Hide()
        end
    end

    -- Stats summary line
    local rows = addon:GetCapStatus(class, spec, phase, "selected")
    if rows then
        local parts = {}
        for _, r in ipairs(rows) do
            if r.cap and r.cap > 0 then
                local color = (r.missing == 0) and "|cff60ff60" or "|cffaaaaaa"
                parts[#parts + 1] = color .. r.label .. ": " .. r.current .. " / " .. r.cap .. "|r"
            else
                parts[#parts + 1] = UI_PAL.mutedSoft .. r.label .. ": " .. r.current .. "|r"
            end
        end
        self.previewStatsLbl:SetText(table.concat(parts, "  ·  "))
    else
        self.previewStatsLbl:SetText("")
    end
end

function UI:ShowBisPreview(class, spec, phase)
    self:BuildBisPreview()
    self:RefreshBisPreview(class, spec, phase)
    self.previewFrame:Show()
end

-- ─────────────────────────────────────────────
-- Toggle / Show / Hide
-- ─────────────────────────────────────────────

function UI:Toggle()
    if not self.frame then
        self:Build()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:RefreshClassButtons()
        self:RefreshSpecSelector()
        self:RefreshPhaseTabs()
        self:Refresh()
    end
end

function UI:Show()
    if not self.frame then self:Build() end
    self.frame:Show()
    self:Refresh()
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end
