-- Class/spec reward picker for Classic and Burning Crusade raid tokens.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
local menu
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local slots = {
    INVTYPE_HEAD="Head", INVTYPE_SHOULDER="Shoulders", INVTYPE_CHEST="Chest",
    INVTYPE_ROBE="Chest", INVTYPE_WRIST="Wrists", INVTYPE_HAND="Hands",
    INVTYPE_WAIST="Waist", INVTYPE_LEGS="Legs", INVTYPE_FEET="Feet",
    INVTYPE_FINGER="Ring", INVTYPE_CLOAK="Cloak", INVTYPE_WEAPON="Weapon",
    INVTYPE_2HWEAPON="Two-hand", INVTYPE_WEAPONMAINHAND="Main hand",
    INVTYPE_WEAPONOFFHAND="Off hand", INVTYPE_SHIELD="Shield",
    INVTYPE_HOLDABLE="Off hand", INVTYPE_RANGED="Ranged", INVTYPE_RANGEDRIGHT="Ranged",
}

local function Info(id)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if get then return get(id) end
end
local function Icon(id)
    local get = C_Item and C_Item.GetItemIconByID or GetItemIcon
    return get and get(id) or QUESTION
end
local function Slot(id)
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if get then
        local _, _, _, equipLoc = get(id)
        return slots[equipLoc] or "Set piece"
    end
    return "Set piece"
end
local function Backdrop(f, r, g, b)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(r, g, b, 0.99)
    f:SetBackdropBorderColor(0.55, 0.42, 0.22, 1)
end
function FDJ.IsTierToken(itemID)
    return FDJ.TIER_TOKEN_REWARDS and FDJ.TIER_TOKEN_REWARDS[tonumber(itemID)] ~= nil or false
end
function FDJ.HideTierTokenChooser()
    if menu then menu:Hide() end
end

local function RefreshItem(button)
    local reward = button.reward
    local name = Info(reward.id)
    button.item = {reward.id, name or reward.set or "Item", "Item", 4}
    button.icon:SetTexture(Icon(reward.id))
    button.label:SetText(reward.spec or Slot(reward.id))
end
local function ItemClick(self, button)
    local _, link = Info(self.reward.id)
    link = link or ("item:" .. self.reward.id)
    if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
        if ChatEdit_InsertLink(link) then return end
    end
    if IsModifiedClick and IsModifiedClick("DRESSUP") and DressUpItemLink then
        DressUpItemLink(link)
        return
    end
    -- Pin the normal item-reference tooltip so the reward can be inspected.
    if SetItemRef then SetItemRef(link, link, button or "LeftButton", self) end
end
local function MakeReward(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(102, 64)
    Backdrop(b, 0.14, 0.10, 0.055)
    b:RegisterForClicks("LeftButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(34, 34)
    b.icon:SetPoint("TOP", 0, -4)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("TOPLEFT", 3, -40)
    b.label:SetPoint("BOTTOMRIGHT", -3, 3)
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(true)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0.3, 1)
        if FDJ.ShowJournalItemTooltip then FDJ.ShowJournalItemTooltip(self) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.55, 0.42, 0.22, 1)
        self.fdjComparing = nil
        if FDJ.HideJournalItemTooltip then FDJ.HideJournalItemTooltip() end
    end)
    b:SetScript("OnUpdate", function(self)
        if FDJ.UpdateJournalItemComparison then FDJ.UpdateJournalItemComparison(self) end
    end)
    b:SetScript("OnClick", ItemClick)
    return b
end
local function MouseOverMenu()
    if not MouseIsOver then return false end
    if MouseIsOver(menu) or (menu.close and MouseIsOver(menu.close)) then return true end
    if menu.owner and MouseIsOver(menu.owner) then return true end
    for _, row in ipairs(menu.rows) do
        for _, b in ipairs(row.buttons) do
            if b:IsShown() and MouseIsOver(b) then return true end
        end
    end
    return false
end
local function EnsureMenu()
    if menu then return menu end
    local journal = FDJ.frame or _G.ForeverDungeonJournalFrame
    menu = CreateFrame("Frame", "ForeverDungeonJournalTierTokens", journal or UIParent, "BackdropTemplate")
    FDJ.tierTokenChooser = menu
    menu:SetWidth(478)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    Backdrop(menu, 0.08, 0.06, 0.035)
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menu.title:SetPoint("TOPLEFT", 14, -14)
    menu.title:SetPoint("TOPRIGHT", -30, -14)
    menu.title:SetHeight(34)
    menu.title:SetJustifyH("LEFT")
    menu.title:SetWordWrap(true)
    menu.subtitle = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    menu.subtitle:SetPoint("TOPLEFT", 14, -51)
    menu.subtitle:SetText("Choose a class and set variant")
    menu.close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    menu.close:SetPoint("TOPRIGHT", -2, -2)
    menu.close:SetScript("OnClick", FDJ.HideTierTokenChooser)
    menu.rows = {}
    menu:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    menu:SetScript("OnEvent", function(self, _, itemID, success)
        if not self:IsShown() or success == false then return end
        if itemID == self.tokenID then
            self.title:SetText(Info(self.tokenID) or self.tokenName)
        end
        for _, row in ipairs(self.rows) do
            if row.frame:IsShown() then
                for _, b in ipairs(row.buttons) do
                    if b:IsShown() and b.reward.id == itemID then RefreshItem(b) end
                end
            end
        end
    end)
    menu:SetScript("OnUpdate", function(self)
        if not self.owner or not self.owner:IsVisible()
            or not self.owner.item or tonumber(self.owner.item[1]) ~= self.tokenID then
            self:Hide(); return
        end
        local down = IsMouseButtonDown and (IsMouseButtonDown("LeftButton")
            or IsMouseButtonDown("RightButton") or IsMouseButtonDown("MiddleButton"))
        if not self.armed then
            if not down then self.armed = true end
        elseif down then
            self.sawDown = true
        elseif self.sawDown then
            self.sawDown = false
            if not MouseOverMenu() then self:Hide() end
        end
    end)
    menu:SetScript("OnHide", function()
        if FDJ.HideJournalItemTooltip then FDJ.HideJournalItemTooltip() end
    end)
    if journal and journal.HookScript then
        journal:HookScript("OnHide", FDJ.HideTierTokenChooser)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, menu:GetName()) end
    menu:Hide()
    return menu
end
local function MakeClassRow(parent)
    local row = {buttons={}}
    row.frame = CreateFrame("Frame", nil, parent)
    row.frame:SetSize(450, 72)
    row.name = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(119)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(true)
    return row
end
function FDJ.ShowTierTokenChooser(owner, item)
    local tokenID = item and tonumber(item[1])
    local data = tokenID and FDJ.TIER_TOKEN_REWARDS and FDJ.TIER_TOKEN_REWARDS[tokenID]
    if not owner or not data then return false end
    local f = EnsureMenu()
    if f:IsShown() and f.owner == owner and f.tokenID == tokenID then f:Hide(); return true end
    if FDJ.HideItemFavouriteMenu then FDJ.HideItemFavouriteMenu() end
    f.owner, f.tokenID, f.tokenName = owner, tokenID, data.name
    f:SetFrameLevel((owner:GetFrameLevel() or 1) + 30)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -3)
    local columns = 1
    for _, group in ipairs(data.groups) do columns = math.max(columns, #group.items) end
    f:SetWidth(math.max(478, 154 + columns * 108))
    f:SetHeight(84 + #data.groups * 72)
    f.title:SetText(Info(tokenID) or data.name)
    for index, group in ipairs(data.groups) do
        local row = f.rows[index]
        if not row then row = MakeClassRow(f); f.rows[index] = row end
        row.frame:SetWidth(f:GetWidth() - 28)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -70 - (index-1)*72)
        local class = group.class
        row.name:SetText(class == "ALL" and "Rewards"
            or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class])
            or (class:sub(1,1) .. class:sub(2):lower()))
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        row.name:SetTextColor(color and color.r or 1, color and color.g or 0.82, color and color.b or 0.3)
        for i, reward in ipairs(group.items) do
            local b = row.buttons[i]
            if not b then b = MakeReward(row.frame); row.buttons[i] = b end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 126 + (i-1)*108, -3)
            b.reward = reward
            b.fdjSourceText = "Reward for " .. data.name
            RefreshItem(b)
            b:Show()
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(reward.id) end
        end
        for i = #group.items+1, #row.buttons do row.buttons[i]:Hide() end
        row.frame:Show()
    end
    for i = #data.groups+1, #f.rows do f.rows[i].frame:Hide() end
    f.armed, f.sawDown = false, false
    f:Show()
    return true
end
