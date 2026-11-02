local _, TrainerSpells = ...
local rowHeightSyncFrame = CreateFrame("Frame")
rowHeightSyncFrame:RegisterEvent("ADDON_LOADED")
rowHeightSyncFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "TrainerSpells" then return end
    self:UnregisterEvent("ADDON_LOADED")
    TrainerSpells.RowHeight = (TrainerSpells_Character and TrainerSpells_Character.rowHeight) or TrainerSpells.RowHeight
    TrainerSpells.RowHeight = math.max(TrainerSpells.MinRowHeight, math.min(TrainerSpells.MaxRowHeight, TrainerSpells.RowHeight))
    TrainerSpells.RowHeightSlider:SetValue(TrainerSpells.RowHeight)
    TrainerSpells.ProfessionRowHeight = (TrainerSpells_Character and TrainerSpells_Character.professionRowHeight) or TrainerSpells.ProfessionRowHeight
    TrainerSpells.ProfessionRowHeight = math.max(TrainerSpells.MinRowHeight, math.min(TrainerSpells.MaxRowHeight, TrainerSpells.ProfessionRowHeight))
    TrainerSpells.ProfessionRowHeightSlider:SetValue(TrainerSpells.ProfessionRowHeight)
end)
