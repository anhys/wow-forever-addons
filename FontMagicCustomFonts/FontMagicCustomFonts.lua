-- FontMagicCustomFonts.lua
-- Supplementary addon for FontMagic allowing users to provide custom fonts.
-- Drop files named 1.ttf .. 20.ttf into this addon's Custom folder and
-- FontMagic will be able to use them.

local ADDON_NAME = ...

local ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Custom\\"

-- Public table used by the main FontMagic addon
FontMagicCustomFonts = {
    PATH = ADDON_PATH,
}

-- internal helper to safely check font existence
local function fontExists(path)
    local f = CreateFont(ADDON_NAME .. "Check")
    local ok = pcall(function() f:SetFont(path, 12, "") end)
    local loaded = ok and f:GetFont()
    return loaded and loaded:lower():find(path:match("[^\\/]+$"), 1, true)
end

-- Return the font path for the given numeric index if the file exists.
function FontMagicCustomFonts:GetFontPath(index)
    if type(index) ~= "number" then return nil end
    local fname = index .. ".ttf"
    local path = ADDON_PATH .. fname
    if fontExists(path) then
        return path
    end
    return nil
end

-- Return a table listing all existing custom font paths
function FontMagicCustomFonts:AvailableFonts()
    local fonts = {}
    for i = 1, 20 do
        local path = self:GetFontPath(i)
        if path then
            fonts[#fonts + 1] = path
        end
    end
    return fonts
end

print("FontMagicCustomFonts loaded. Drop numbered .ttf files into" ..
      " 'Interface/AddOns/" .. ADDON_NAME .. "/Custom' to use them in FontMagic.")
