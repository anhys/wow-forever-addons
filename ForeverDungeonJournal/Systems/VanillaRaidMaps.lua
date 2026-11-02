-- Dungeon Journal (TBC Anniversary): Map tab for the Vanilla raids.
-- The art is the game's own raid map. Which file names this client ships is
-- probed at login (both the flat and the per-floor naming schemes).
-- Boss pins are added once their positions on these maps are known.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY or not FDJ.DUNGEON_MAPS then return end

local RAIDS = {
    ["Molten Core"]          = { "MoltenCore" },
    ["Onyxia's Lair"]        = { "OnyxiasLair" },
    ["Blackwing Lair"]       = { "BlackwingLair" },
    ["Zul'Gurub"]            = { "ZulGurub" },
    ["Ruins of Ahn'Qiraj"]   = { "RuinsofAhnQiraj", "RuinsOfAhnQiraj", "AhnQirajRuins" },
    ["Temple of Ahn'Qiraj"]  = { "AhnQiraj", "TempleofAhnQiraj", "TempleOfAhnQiraj", "AhnQirajTemple" },
    ["Naxxramas"]            = { "Naxxramas" },
}

-- Boss pins and entrances from "Vanilla + TBC Raid Boss Location Maps" (Atlas
-- layouts, 22 Oct 2026), transferred onto the game's map. Ctrl-drag to fine-tune.
FDJ.VANILLA_RAID_PINS = {
    -- Temple of Ahn'Qiraj: per-level spots from "AQ40 Boss Positions - Your Three Map Tabs".
    ["Temple of Ahn'Qiraj"] = { multi = true, bosses = { { name = "The Prophet Skeram", floor = 2, x = 0.459, y = 0.516 }, { name = "The Bug Trio", floor = 1, x = 0.283, y = 0.496 }, { name = "Battleguard Sartura", floor = 1, x = 0.446, y = 0.339 }, { name = "Fankriss the Unyielding", floor = 1, x = 0.621, y = 0.227 }, { name = "Viscidus", floor = 1, x = 0.721, y = 0.181 }, { name = "Princess Huhuran", floor = 1, x = 0.433, y = 0.501 }, { name = "The Twin Emperors", floor = 1, x = 0.605, y = 0.699 }, { name = "Ouro", floor = 1, x = 0.303, y = 0.816 }, { name = "C'Thun", floor = 3, x = 0.570, y = 0.628 } } },
    -- Blackwing Lair: per-level spots from "Blackwing Lair Boss Positions - Your Four Map Tabs".
    ["Blackwing Lair"] = { multi = true, bosses = { { name = "Razorgore the Untamed", floor = 1, x = 0.417, y = 0.604 }, { name = "Vaelastrasz the Corrupt", floor = 1, x = 0.331, y = 0.282 }, { name = "Broodlord Lashlayer", floor = 3, x = 0.502, y = 0.621 }, { name = "Firemaw", floor = 3, x = 0.462, y = 0.432 }, { name = "Ebonroc", floor = 3, x = 0.347, y = 0.215 }, { name = "Flamegor", floor = 4, x = 0.352, y = 0.375 }, { name = "Chromaggus", floor = 4, x = 0.393, y = 0.723 }, { name = "Nefarian", floor = 4, x = 0.702, y = 0.728 } } },
    -- Naxxramas: per-level spots from "Naxxramas Boss Positions - Your Six Map Tabs".
    ["Naxxramas"] = { multi = true, bosses = { { name = "Patchwerk", floor = 1, x = 0.616, y = 0.525 }, { name = "Grobbulus", floor = 1, x = 0.457, y = 0.442 }, { name = "Gluth", floor = 1, x = 0.540, y = 0.422 }, { name = "Thaddius", floor = 1, x = 0.266, y = 0.148 }, { name = "Anub'Rekhan", floor = 2, x = 0.304, y = 0.473 }, { name = "Grand Widow Faerlina", floor = 2, x = 0.439, y = 0.360 }, { name = "Maexxna", floor = 2, x = 0.685, y = 0.158 }, { name = "Instructor Razuvious", floor = 3, x = 0.425, y = 0.456 }, { name = "Gothik the Harvester", floor = 3, x = 0.675, y = 0.597 }, { name = "The Four Horsemen", floor = 3, x = 0.301, y = 0.771 }, { name = "Noth the Plaguebringer", floor = 4, x = 0.497, y = 0.456 }, { name = "Heigan the Unclean", floor = 4, x = 0.347, y = 0.568 }, { name = "Loatheb", floor = 4, x = 0.758, y = 0.286 }, { name = "Sapphiron", floor = 6, x = 0.567, y = 0.673 }, { name = "Kel'Thuzad", floor = 6, x = 0.368, y = 0.229 } } },
    ["Molten Core"] = { entrance = { floor = 1, x = 0.265, y = 0.225, angle = 0 }, bosses = { { name = "Lucifron", floor = 1, x = 0.659, y = 0.382 }, { name = "Magmadar", floor = 1, x = 0.69, y = 0.245 }, { name = "Gehennas", floor = 1, x = 0.333, y = 0.493 }, { name = "Garr", floor = 1, x = 0.309, y = 0.704 }, { name = "Shazzrah", floor = 1, x = 0.552, y = 0.851 }, { name = "Baron Geddon", floor = 1, x = 0.524, y = 0.782 }, { name = "Golemagg the Incinerator", floor = 1, x = 0.686, y = 0.59 }, { name = "Sulfuron Harbinger", floor = 1, x = 0.828, y = 0.834 }, { name = "Majordomo Executus", floor = 1, x = 0.84, y = 0.662 }, { name = "Ragnaros", floor = 1, x = 0.559, y = 0.543 } } },
    ["Onyxia's Lair"] = { entrance = { floor = 1, x = 0.339, y = 0.208, angle = 0 }, bosses = { { name = "Onyxia", floor = 1, x = 0.673, y = 0.311 } } },
    ["Zul'Gurub"] = { entrance = { floor = 1, x = 0.293, y = 0.487, angle = 0 }, bosses = { { name = "High Priestess Jeklik", floor = 1, x = 0.389, y = 0.768 }, { name = "High Priest Venoxis", floor = 1, x = 0.508, y = 0.545 }, { name = "High Priestess Mar'li", floor = 1, x = 0.479, y = 0.835 }, { name = "Bloodlord Mandokir", floor = 1, x = 0.602, y = 0.805 }, { name = "Edge of Madness", floor = 1, x = 0.597, y = 0.465 }, { name = "Gahz'ranka", floor = 1, x = 0.565, y = 0.354 }, { name = "High Priest Thekal", floor = 1, x = 0.61, y = 0.362 }, { name = "High Priestess Arlokk", floor = 1, x = 0.475, y = 0.205 }, { name = "Jin'do the Hexxer", floor = 1, x = 0.315, y = 0.251 }, { name = "Hakkar the Soulflayer", floor = 1, x = 0.495, y = 0.403 } } },
    ["Ruins of Ahn'Qiraj"] = { entrance = { floor = 1, x = 0.582, y = 0.088, angle = 0 }, bosses = { { name = "Kurinnaxx", floor = 1, x = 0.559, y = 0.362 }, { name = "General Rajaxx", floor = 1, x = 0.585, y = 0.499 }, { name = "Moam", floor = 1, x = 0.33, y = 0.369 }, { name = "Buru the Gorger", floor = 1, x = 0.699, y = 0.626 }, { name = "Ayamiss the Hunter", floor = 1, x = 0.616, y = 0.904 }, { name = "Ossirian the Unscarred", floor = 1, x = 0.432, y = 0.694 } } },
}

local probe
local function FileExists(path)
    if not probe then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        probe = holder:CreateTexture(nil, "ARTWORK")
    end
    probe:SetTexture(nil)
    probe:SetTexture(path)
    local id = probe.GetTextureFileID and probe:GetTextureFileID()
    return id ~= nil and id ~= 0
end

local function Resolve()
    for name, folders in pairs(RAIDS) do
        if FDJ.DB and FDJ.DB[name] and not FDJ.DUNGEON_MAPS[name] then
            local floors = {}
            for _, folder in ipairs(folders) do
                local base = "Interface\\WorldMap\\" .. folder .. "\\" .. folder
                for f = 1, 8 do
                    if FileExists(base .. f .. "_1") then floors[#floors + 1] = { tiles = base .. f .. "_" } end
                end
                if #floors == 0 and FileExists(base .. "1") then floors[1] = { tiles = base } end
                if #floors > 0 then break end
            end
            if #floors > 1 then
                for i, f in ipairs(floors) do f.name = "Level " .. i end
            end
            if #floors > 0 then
                local pin = FDJ.VANILLA_RAID_PINS[name]
                -- Pins are placed for single-map raids; multi-level raids get them once
                -- each boss's level is known.
                FDJ.DUNGEON_MAPS[name] = { floors = floors,
                    bosses = (pin and (#floors == 1 or pin.multi)) and pin.bosses or {},
                    entrance = (pin and #floors == 1) and pin.entrance or nil }
            end
            if FDJ.TBCMapDebug then FDJ.TBCMapDebug["raid " .. name] = #floors .. " floors" end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() pcall(Resolve) end)
