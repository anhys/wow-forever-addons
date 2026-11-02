local _, FM = ...

if type(FM) ~= "table" then
    error("FontMagic Core/Database.lua requires the shared addon table", 0)
end

FM.Database = FM.Database or {}
local Database = FM.Database

local SCHEMA_VERSION = 3
local MOTION_OWNERSHIP_VERSION = 1

local function IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function NormalizeOutline(db)
    local rawValue = db.combatTextOutlineMode
    local rawMode = type(rawValue) == "string"
        and rawValue:upper()
        or "NONE"
    local recognized = rawMode == "" or rawMode == "NONE" or rawMode == "NO" or rawMode == "0"
        or rawMode == "OUTLINE" or rawMode == "1"
        or rawMode == "THICK" or rawMode == "THICKOUTLINE" or rawMode == "2"

    -- Unknown strings are corrupt/future data, not evidence that the user
    -- deliberately granted FontMagic outline ownership. Fail passive.
    if type(rawValue) == "string" and not recognized then
        db.combatTextOutlineMode = "NONE"
        db.combatTextOutlineTouched = false
        return
    end

    if type(db.combatTextOutlineTouched) ~= "boolean" then
        db.combatTextOutlineTouched = rawMode ~= ""
            and rawMode ~= "NONE"
            and rawMode ~= "NO"
            and rawMode ~= "0"
    end

    local mode = rawMode

    if mode == "" or mode == "NONE" or mode == "NO" or mode == "0" then
        db.combatTextOutlineMode = "NONE"
    elseif mode == "THICK" or mode == "THICKOUTLINE" or mode == "2" then
        db.combatTextOutlineMode = "THICKOUTLINE"
    else
        db.combatTextOutlineMode = "OUTLINE"
    end
end

local function NormalizeMotionOwnership(db)
    -- Older FontMagic versions persisted a snapshot of the live client values
    -- even if the user never moved these controls. Clear that historical state
    -- once, then only retain values FontMagic explicitly owns.
    if db.__fmMotionOwnershipVersion ~= MOTION_OWNERSHIP_VERSION then
        db.floatingTextGravity = nil
        db.floatingTextFadeDuration = nil
        db.floatingTextGravityTouched = false
        db.floatingTextFadeDurationTouched = false
        db.combatTextScale = nil
        db.combatTextScaleTouched = false
        db.__fmMotionOwnershipVersion = MOTION_OWNERSHIP_VERSION
        return
    end

    if type(db.floatingTextGravityTouched) ~= "boolean" then
        db.floatingTextGravityTouched = false
    end
    if type(db.floatingTextFadeDurationTouched) ~= "boolean" then
        db.floatingTextFadeDurationTouched = false
    end

    if not db.floatingTextGravityTouched or not IsFiniteNumber(db.floatingTextGravity) then
        db.floatingTextGravity = nil
        db.floatingTextGravityTouched = false
    end
    if not db.floatingTextFadeDurationTouched or not IsFiniteNumber(db.floatingTextFadeDuration) then
        db.floatingTextFadeDuration = nil
        db.floatingTextFadeDurationTouched = false
    end

    if type(db.combatTextScaleTouched) ~= "boolean" then
        db.combatTextScaleTouched = false
    end
    if not db.combatTextScaleTouched or not IsFiniteNumber(db.combatTextScale) then
        db.combatTextScale = nil
        db.combatTextScaleTouched = false
    end
end

local function NormalizeBooleanMap(value, trueOnly, keyPredicate)
    local normalized = {}
    if type(value) ~= "table" then return normalized end

    for key, enabled in pairs(value) do
        if type(key) == "string" and key ~= ""
            and type(enabled) == "boolean"
            and (not keyPredicate or keyPredicate(key))
            and (not trueOnly or enabled) then
            normalized[key] = enabled
        end
    end

    return normalized
end

local function NormalizeStringMap(value, keyPredicate)
    local normalized = {}
    if type(value) ~= "table" then return normalized end
    for key, current in pairs(value) do
        local currentType = type(current)
        if type(key) == "string" and key ~= ""
            and (not keyPredicate or keyPredicate(key))
            and (currentType == "string" or currentType == "number" or currentType == "boolean") then
            normalized[key] = tostring(current)
        end
    end
    return normalized
end

local MASTER_INCOMING_KEYS = {
    DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true, SPELL_DAMAGE_CRIT = true,
    HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true, PERIODIC_HEAL_CRIT = true,
}

function Database.IsCombatTextCVarName(name)
    if type(name) ~= "string" or name == "" then return false end
    local lowered = name:lower()
    if lowered == "enablecombattext" or lowered == "enablefloatingcombattext" then
        return true
    end
    if lowered:find("^floatingcombattext") then return true end
    for _, base in ipairs({ "worldtextscale", "worldtextgravity", "worldtextrampduration" }) do
        if lowered == base or lowered:match("^" .. base .. "_v%d+$") then
            return true
        end
    end
    return false
end

local function NormalizeMasterSnapshot(value)
    if type(value) ~= "table" then return nil end
    local normalized = { cvars = {}, commandTypes = {}, incoming = { entries = {} } }
    local restorable = false

    if type(value.cvars) == "table" then
        for name, current in pairs(value.cvars) do
            local commandType = type(value.commandTypes) == "table" and value.commandTypes[name] or nil
            local currentType = type(current)
            if Database.IsCombatTextCVarName(name) and commandType == 0
                and (currentType == "string" or currentType == "number" or currentType == "boolean") then
                normalized.cvars[name] = current
                normalized.commandTypes[name] = 0
                restorable = true
            end
        end
    end

    local entries = type(value.incoming) == "table" and value.incoming.entries or nil
    if type(entries) == "table" then
        for key, present in pairs(entries) do
            if MASTER_INCOMING_KEYS[key] and type(present) == "boolean" then
                normalized.incoming.entries[key] = present
                restorable = true
            end
        end
    end

    return restorable and normalized or nil
end

function Database.IsValidMasterSnapshot(value)
    return NormalizeMasterSnapshot(value) ~= nil
end

local function MigratePerCharacterOverrides(db, pcdb)
    local migrated = false
    local fields = { "combatOverrides", "extraCombatOverrides", "incomingOverrides" }

    for _, field in ipairs(fields) do
        local source = pcdb[field]
        if type(source) == "table" then
            source = NormalizeBooleanMap(
                source,
                false,
                field == "extraCombatOverrides" and Database.IsCombatTextCVarName or nil
            )
            local destination = db[field]
            if type(destination) ~= "table" then
                destination = {}
                db[field] = destination
            end

            for key, value in pairs(source) do
                if destination[key] == nil then
                    destination[key] = value
                end
            end

            pcdb[field] = nil
            migrated = true
        elseif source ~= nil then
            -- Invalid legacy data has no safe interpretation and must not remain
            -- available for later code to index as a table.
            pcdb[field] = nil
        end
    end

    if migrated then
        -- Older per-character versions used this entry as their main hide
        -- switch. Do not unexpectedly preserve that state account-wide.
        db.combatOverrides.enableFloatingCombatText = nil
    end
end

function Database.Initialize()
    local db = rawget(_G, "FontMagicDB")
    local pcdb = rawget(_G, "FontMagicPCDB")

    if type(db) ~= "table" then db = {} end
    if type(pcdb) ~= "table" then pcdb = {} end

    rawset(_G, "FontMagicDB", db)
    rawset(_G, "FontMagicPCDB", pcdb)

    if not IsFiniteNumber(db.minimapAngle) then
        db.minimapAngle = tonumber(type(FM.Constants) == "table" and FM.Constants.DEFAULT_MINIMAP_ANGLE) or 225
    end
    db.minimapAngle = db.minimapAngle % 360
    if type(db.minimapHide) ~= "boolean" then db.minimapHide = false end
    if type(db.selectedFont) ~= "string" then db.selectedFont = nil end
    if type(db.selectedGroup) ~= "string" then db.selectedGroup = nil end

    if type(db.windowPos) ~= "table"
        or not IsFiniteNumber(db.windowPos.left)
        or not IsFiniteNumber(db.windowPos.top) then
        db.windowPos = nil
    end

    if type(pcdb.selectedFont) ~= "string" then pcdb.selectedFont = nil end
    if type(pcdb.selectedGroup) ~= "string" then pcdb.selectedGroup = nil end

    db.favorites = NormalizeBooleanMap(db.favorites, true)
    if type(db.__fmPopularFolderMigrationDone) ~= "boolean" then
        db.__fmPopularFolderMigrationDone = false
    end
    if type(db.__fmDebugCombatText) ~= "boolean" then db.__fmDebugCombatText = false end
    db.combatOverrides = NormalizeBooleanMap(db.combatOverrides, false)
    db.extraCombatOverrides = NormalizeBooleanMap(
        db.extraCombatOverrides,
        false,
        Database.IsCombatTextCVarName
    )
    db.incomingOverrides = NormalizeBooleanMap(db.incomingOverrides, false)
    db.combatResetRecovery = NormalizeStringMap(
        db.combatResetRecovery,
        Database.IsCombatTextCVarName
    )
    if next(db.combatResetRecovery) == nil then db.combatResetRecovery = nil end
    db.combatMasterSnapshot = NormalizeMasterSnapshot(db.combatMasterSnapshot)
    if type(db.combatMasterOffByFontMagic) ~= "boolean" then
        db.combatMasterOffByFontMagic = nil
    end
    if db.combatMasterOffByFontMagic and not db.combatMasterSnapshot then
        db.combatMasterOffByFontMagic = nil
    end
    if db.combatMasterSnapshot then
        if db.combatMasterOffByFontMagic then
            db.combatMasterSnapshotPurpose = "hidden"
        elseif db.combatMasterSnapshotPurpose ~= "hidden"
            and db.combatMasterSnapshotPurpose ~= "baselineRollback" then
            db.combatMasterSnapshot = nil
            db.combatMasterSnapshotPurpose = nil
        end
    else
        db.combatMasterSnapshotPurpose = nil
    end
    if type(db.showExtraCombatToggles) ~= "boolean" then db.showExtraCombatToggles = false end
    if type(db.combatTextAboveNameplates) ~= "boolean" then db.combatTextAboveNameplates = false end

    NormalizeOutline(db)
    NormalizeMotionOwnership(db)
    MigratePerCharacterOverrides(db, pcdb)

    db.__fmSchemaVersion = SCHEMA_VERSION
    return db, pcdb
end

function Database.Get()
    return rawget(_G, "FontMagicDB"), rawget(_G, "FontMagicPCDB")
end
