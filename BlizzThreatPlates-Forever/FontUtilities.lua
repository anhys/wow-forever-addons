local addon=ForeverNameplates
local function FontPath(path)
    return type(path)=="string" and path:gsub("/","\\"):lower() or path
end

function addon:SetFontWithFallback(label,path,size,flags,fallback)
    -- Classic FontStrings can successfully SetFont without returning a value.
    -- Inspect font metadata, never the label's potentially secret text or size.
    local ok=pcall(label.SetFont,label,path,size,flags or "")
    local applied=ok and label:GetFont()
    if applied and FontPath(applied)==FontPath(path) then return true end
    label:SetFont(fallback or "Fonts\\FRIZQT__.TTF",size,flags or "")
    return false
end
