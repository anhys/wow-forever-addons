local addonName, FM = ...

if type(FM) ~= "table" then
    error("FontMagic Core/Fonts.lua requires the shared addon table", 0)
end

FM.Fonts = FM.Fonts or {}
local Fonts = FM.Fonts
local Constants = type(FM.Constants) == "table" and FM.Constants or {}
local Paths = type(FM.Paths) == "table" and FM.Paths or {}
local Compat = type(FM.Compat) == "table" and FM.Compat or {}

local resolvedAddonName = type(addonName) == "string" and addonName ~= "" and addonName or "FontMagic"
local addonPath = type(Paths.Addon) == "string" and Paths.Addon ~= ""
    and Paths.Addon
    or ("Interface\\AddOns\\" .. resolvedAddonName .. "\\")
local customAddon = type(Constants.CUSTOM_ADDON) == "string" and Constants.CUSTOM_ADDON ~= ""
    and Constants.CUSTOM_ADDON
    or "FontMagicCustomFonts"
local customPath = type(Paths.Custom) == "string" and Paths.Custom ~= ""
    and Paths.Custom
    or ("Interface\\AddOns\\" .. customAddon .. "\\Custom\\")

local function EnsureTrailingSeparator(path)
    if type(path) ~= "string" or path == "" then return nil end
    path = path:gsub("/", "\\")
    if path:sub(-1) ~= "\\" then path = path .. "\\" end
    return path
end

addonPath = EnsureTrailingSeparator(addonPath) or ("Interface\\AddOns\\" .. resolvedAddonName .. "\\")
customPath = EnsureTrailingSeparator(customPath) or ("Interface\\AddOns\\" .. customAddon .. "\\Custom\\")

if type(Compat.LoadAddOn) == "function" then
    pcall(Compat.LoadAddOn, customAddon)
end

local companion = rawget(_G, customAddon)
if type(companion) == "table" then
    local reportedPath = EnsureTrailingSeparator(companion.PATH)
    if reportedPath then customPath = reportedPath end
end

-- Keep the shared path table authoritative for modules loaded after this one.
if type(FM.Paths) == "table" then
    FM.Paths.Addon = addonPath
    FM.Paths.Custom = customPath
end

local STYLE_TOKENS = {
    regular = true, normal = true, book = true, roman = true,
    medium = true, semibold = true, demibold = true, demi = true, semi = true,
    bold = true, extrabold = true, ultrabold = true, extra = true, ultra = true,
    black = true, heavy = true,
    light = true, thin = true, hairline = true,
    italic = true, oblique = true,
    condensed = true, narrow = true, compressed = true,
    expanded = true, extended = true,
    outline = true,
}

function Fonts.StripExtension(fileName)
    if type(fileName) ~= "string" then return "" end
    local base = fileName
    base = base:gsub("%.[Tt][Tt][Ff]$", "")
        :gsub("%.[Oo][Tt][Ff]$", "")
        :gsub("%.[Tt][Tt][Cc]$", "")
    return (base:gsub("%s+$", ""))
end

function Fonts.ShortenLabel(label)
    if type(label) ~= "string" or label == "" then return "" end

    local normalized = label
        :gsub("%.[Tt][Tt][Ff]$", "")
        :gsub("%.[Oo][Tt][Ff]$", "")
        :gsub("%.[Tt][Tt][Cc]$", "")
        :gsub("[_%-]+", " ")
        :gsub("([%l])([%u])", "%1 %2")
        :gsub("([%a])(%d)", "%1 %2")
        :gsub("(%d)([%a])", "%1 %2")
        :gsub("[%(%)]", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    local tokens = {}
    for token in normalized:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    local function IsStyleToken(token)
        if not token then return false end
        local key = token:lower():gsub("[^%w]+", "")
        return key == "" or STYLE_TOKENS[key] == true or key:match("^%d+$") ~= nil
    end

    while #tokens > 0 and IsStyleToken(tokens[#tokens]) do
        table.remove(tokens)
    end

    local shortened = table.concat(tokens, " ")
    return shortened ~= "" and shortened or normalized
end

local Groups = {
    ["Popular"] = {
        path = addonPath .. "Popular\\",
        fonts = {
            "Pepsi.ttf", "bignoodletitling.ttf", "Expressway.ttf", "Bangers.ttf", "PTSansNarrow-Bold.ttf", "Roboto Condensed Bold.ttf",
            "NotoSans_Condensed-Bold.ttf", "Roboto-Bold.ttf", "AlteHaasGroteskBold.ttf", "CalibriBold.ttf", "Orbitron.ttf", "Prototype.ttf",
            "914Solid.ttf", "Halo.ttf", "Proxima Nova Condensed Bold.ttf", "Comfortaa-Bold.ttf", "Andika-Bold.ttf", "lemon-milk.ttf",
            "Good Brush.ttf", "KG HAPPY.ttf",
        },
    },
    ["Clean & Readable"] = {
        path = addonPath .. "Easy-to-Read\\",
        fonts = {
            "BauhausRegular.ttf", "Butterpop.ttf", "Diogenes.ttf", "Junegull.ttf", "Pantalone.ttf", "Resoft.ttf",
            "Retro Amour.ttf", "SF-Pro.ttf", "Solange.ttf", "Takeaway.ttf",
        },
    },
    ["Bold & Impact"] = {
        path = addonPath .. "BoldImpact\\",
        fonts = {
            "airstrikebold.ttf", "Blazed.ttf", "DieDieDie.ttf", "graff.ttf", "Green Fuz.otf", "Love Craft.ttf",
            "modernwarfare.ttf", "Showpop.ttf", "Skratchpunk.ttf", "Skullphabet.ttf", "Trashco.ttf", "Whiplash.ttf",
        },
    },
    ["Fantasy & RP"] = {
        path = addonPath .. "Fun\\",
        fonts = {
            "Acadian.ttf", "akash.ttf", "Caesar.ttf", "ComicRunes.ttf", "crygords.ttf", "Deltarune.ttf",
            "Elven.ttf", "Gunung.ttf", "Guroes.ttf", "HarryP.ttf", "Hobbit.ttf", "Kting.ttf",
            "leviathans.ttf", "MystikOrbs.ttf", "Odinson.ttf", "ParryHotter.ttf", "Pau.ttf", "Pokemon.ttf",
            "Runic.ttf", "Runy.ttf", "Ruritania.ttf", "Spongebob.ttf", "Starborn.ttf", "Starshines.ttf",
            "The Centurion .ttf", "Vampire Wars.ttf", "VTKS.ttf", "WaltographUI.ttf", "Wasser.ttf", "Wickedmouse.ttf",
            "WKnight.ttf", "Zombie.ttf",
        },
    },
    ["Sci-Fi & Tech"] = {
        path = addonPath .. "Future\\",
        fonts = {
            "04b.ttf", "albra.TTF", "Audiowide.ttf", "continuum.ttf", "dalek.ttf", "digital-7.ttf",
            "Digital.ttf", "Exocet.ttf", "Galaxyone.ttf", "Minecrafter.Reg.ttf", "pf_tempesta_seven.ttf", "Price.ttf",
            "RaceSpace.ttf", "RushDriver.ttf", "space age.ttf", "Terminator.ttf",
        },
    },
    ["Random"] = {
        path = addonPath .. "Random\\",
        fonts = {
            "accidentalpres.ttf", "animeace.ttf", "Barriecito.ttf", "baskethammer.ttf", "ChopSic.ttf", "college.ttf",
            "Disko.ttf", "Dmagic.ttf", "edgyh.ttf", "edkies.ttf", "FastHand.ttf", "figtoen.ttf",
            "font2.ttf", "Fraks.ttf", "Ginko.ttf", "Homespun.ttf", "IKARRG.TTF", "JJSTS.TTF",
            "KOMIKAX_.ttf", "Ktingw.ttf", "Melted.ttf", "Midorima.ttf", "Munsteria.ttf", "Rebuffed.TTF",
            "Shiruken.ttf", "shog.ttf", "Starcine.ttf", "Stentiga.ttf", "tsuchigumo.ttf", "WhoAsksSatan.ttf",
        },
    },
    ["Custom"] = {
        path = customPath,
        fonts = {},
    },
}

local customFontCount = tonumber(Constants.CUSTOM_FONT_COUNT) or 20
customFontCount = math.max(0, math.floor(customFontCount))
for index = 1, customFontCount do
    Groups.Custom.fonts[index] = tostring(index) .. ".ttf"
end

local GROUP_ORDER = {
    "Popular", "Clean & Readable", "Bold & Impact", "Fantasy & RP",
    "Sci-Fi & Tech", "Random", "Custom",
}

local Cached = {}
local Exists = {}
local hasCustomFonts = false

local function NormalizePath(path)
    if Compat.IsSecretValue(path) then return nil end
    if type(path) ~= "string" or path == "" then return nil end
    return path:gsub("/", "\\"):lower()
end

local probe = nil
if type(CreateFont) == "function" then
    local ok, created = pcall(CreateFont, resolvedAddonName .. "FontProbe")
    if ok and created and type(created.SetFont) == "function" and type(created.GetFont) == "function" then
        probe = created
    end
end

local function ProbePath(path)
    if not probe then return false end
    local setOK, setResult = pcall(probe.SetFont, probe, path, 32, "")
    if not setOK or Compat.IsSecretValue(setResult) or setResult == false then return false end
    local getOK, loadedPath = pcall(probe.GetFont, probe)
    return getOK and NormalizePath(loadedPath) == NormalizePath(path)
end

for _, groupName in ipairs(GROUP_ORDER) do
    local group = Groups[groupName]
    Cached[groupName] = {}
    Exists[groupName] = {}

    for _, fileName in ipairs(group.fonts) do
        local path = group.path .. fileName
        local detected = ProbePath(path)

        Exists[groupName][fileName] = detected
        if detected then
            Cached[groupName][fileName] = { font = probe, path = path }
            if groupName == "Custom" then hasCustomFonts = true end
        end
    end
end

local function GroupContainsFile(groupName, fileName)
    local group = Groups[groupName]
    if type(group) ~= "table" or type(group.fonts) ~= "table" then return false end
    for _, candidate in ipairs(group.fonts) do
        if candidate == fileName then return true end
    end
    return false
end

function Fonts.RefreshAvailability(groupName)
    local names = {}
    if type(groupName) == "string" and groupName ~= "" then
        if not Groups[groupName] then return false end
        names[1] = groupName
    else
        for _, name in ipairs(GROUP_ORDER) do names[#names + 1] = name end
    end

    if not probe and type(CreateFont) == "function" then
        local ok, created = pcall(CreateFont, resolvedAddonName .. "FontProbe")
        if ok and created and type(created.SetFont) == "function" and type(created.GetFont) == "function" then
            probe = created
        end
    end

    for _, name in ipairs(names) do
        local group = Groups[name]
        if name == "Custom" then
            local loadedCompanion = rawget(_G, customAddon)
            local reportedPath = type(loadedCompanion) == "table"
                and EnsureTrailingSeparator(loadedCompanion.PATH) or nil
            if reportedPath then
                customPath = reportedPath
                group.path = reportedPath
                if type(FM.Paths) == "table" then FM.Paths.Custom = reportedPath end
            end
        end

        Cached[name] = Cached[name] or {}
        Exists[name] = Exists[name] or {}
        for _, fileName in ipairs(group.fonts) do
            local path = group.path .. fileName
            local detected = ProbePath(path)
            Exists[name][fileName] = detected
            Cached[name][fileName] = detected and { font = probe, path = path } or nil
        end
    end

    hasCustomFonts = false
    for _, fileName in ipairs(Groups.Custom.fonts) do
        if Exists.Custom and Exists.Custom[fileName] == true then
            hasCustomFonts = true
            break
        end
    end
    Fonts.HasCustomFonts = hasCustomFonts
    return true
end

function Fonts.ResolveKey(key)
    if type(key) ~= "string" or key == "" then return nil end

    local groupName, fileName = key:match("^(.*)/([^/]+)$")
    if groupName and fileName
        and GroupContainsFile(groupName, fileName)
        and Exists[groupName]
        and Exists[groupName][fileName] == true then
        return Groups[groupName].path .. fileName, groupName, fileName
    end

    local legacyFile = key:match("([^/]+)$")
    local lowerFile = type(legacyFile) == "string" and legacyFile:lower() or ""
    if lowerFile:match("%.ttf$") or lowerFile:match("%.otf$") then
        for _, candidateGroup in ipairs(GROUP_ORDER) do
            if GroupContainsFile(candidateGroup, legacyFile)
                and Exists[candidateGroup]
                and Exists[candidateGroup][legacyFile] == true then
                return Groups[candidateGroup].path .. legacyFile, candidateGroup, legacyFile
            end
        end
    end

    return nil
end

function Fonts.CanonicalizeKey(key)
    if type(key) ~= "string" or key == "" then return nil end

    -- Canonicalization is a catalog operation, not a runtime availability
    -- check.  A known custom font may be temporarily unavailable because its
    -- optional companion is disabled, and a built-in probe can fail during an
    -- early client-loading phase.  Migration must preserve those durable user
    -- choices; ResolveKey remains the availability-gated apply path.
    local groupName, fileName = key:match("^(.*)/([^/]+)$")
    if groupName and fileName and GroupContainsFile(groupName, fileName) then
        return groupName .. "/" .. fileName
    end

    local legacyFile = key:match("([^/]+)$")
    local lowerFile = type(legacyFile) == "string" and legacyFile:lower() or ""
    if lowerFile:match("%.ttf$") or lowerFile:match("%.otf$") then
        for _, candidateGroup in ipairs(GROUP_ORDER) do
            if GroupContainsFile(candidateGroup, legacyFile) then
                return candidateGroup .. "/" .. legacyFile
            end
        end
    end
    return nil
end

function Fonts.MigrateSavedKeys(db)
    if type(db) ~= "table" then db = rawget(_G, "FontMagicDB") end
    if type(db) ~= "table" or db.__fmPopularFolderMigrationDone then return false end

    if type(db.selectedFont) == "string" and db.selectedFont ~= "" then
        db.selectedFont = Fonts.CanonicalizeKey(db.selectedFont) or ""
    end

    local migratedFavorites = {}
    if type(db.favorites) == "table" then
        for key, enabled in pairs(db.favorites) do
            if enabled == true then
                local canonical = Fonts.CanonicalizeKey(key)
                if canonical then migratedFavorites[canonical] = true end
            end
        end
    end
    db.favorites = migratedFavorites
    db.__fmPopularFolderMigrationDone = true
    return true
end

Fonts.Groups = Groups
Fonts.Cached = Cached
Fonts.Exists = Exists
Fonts.HasCustomFonts = hasCustomFonts
