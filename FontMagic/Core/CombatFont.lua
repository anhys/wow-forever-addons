-- FontMagic combat-font ownership engine.
local addonName, FM = ...
local CombatFont = FM.CombatFont
local Fonts = FM.Fonts
local Compat = FM.Compat

CombatFont.FallbackPath = type(FM.Constants) == "table" and FM.Constants.FALLBACK_FONT_PATH
    or "Fonts\\FRIZQT__.TTF"
CombatFont.defaultDamagePath = not Compat.IsSecretValue(_G.DAMAGE_TEXT_FONT)
    and type(_G.DAMAGE_TEXT_FONT) == "string" and _G.DAMAGE_TEXT_FONT or nil
CombatFont.defaultCombatPath = not Compat.IsSecretValue(_G.COMBAT_TEXT_FONT)
    and type(_G.COMBAT_TEXT_FONT) == "string" and _G.COMBAT_TEXT_FONT or nil

CombatFont.FontObjects = CombatFont.FontObjects or {
    -- The original working addon deliberately used stable source sizes for
    -- these Blizzard combat-text FontObjects. In Anniversary 2.5.6 the
    -- inherited SystemFont_World tuple can report an effective size above 100;
    -- carrying that tuple into CombatTextFont produces very wide self text.
    { name = "CombatTextFont", defaultSize = 25, managedSize = 25 },
    { name = "CombatTextFontOutline", defaultSize = 25, managedSize = 25 },
    { name = "DamageFont", defaultSize = 25, managedSize = 25 },
    { name = "DamageFontOutline", defaultSize = 25, managedSize = 25 },
    { name = "CombatTextFontNormal", defaultSize = 25, managedSize = 25 },
    { name = "CombatTextFontSmall", defaultSize = 20, managedSize = 20 },
    { name = "DamageTextFont", defaultSize = 25, managedSize = 25 },
    { name = "DamageTextFontOutline", defaultSize = 25, managedSize = 25 },
    { name = "DamageNumberFont", defaultSize = 25 },
    { name = "CombatDamageFont", defaultSize = 25 },
    { name = "CombatHealingAbsorbGlowFont", defaultSize = 25 },
    { name = "WorldFont", defaultSize = 25 },
    { name = "SystemFont_World", defaultSize = 25 },
    { name = "SystemFont_World_ThickOutline", defaultSize = 25 },
}

CombatFont.GlobalLock = CombatFont.GlobalLock or {}
CombatFont.objectBackups = CombatFont.objectBackups or setmetatable({}, { __mode = "k" })
CombatFont.objectRejections = CombatFont.objectRejections or setmetatable({}, { __mode = "k" })

_G.FontMagicCombatTextGlobalLock = CombatFont.GlobalLock
_G.FontMagicCombatTextFontObjects = CombatFont.FontObjects
_G.FontMagicCombatTextApplying = false

function CombatFont:IsManaged()
    if type(FontMagicDB) ~= "table" then return false end
    return (type(FontMagicDB.selectedFont) == "string" and FontMagicDB.selectedFont ~= "")
        or (FontMagicDB.combatTextOutlineTouched and true or false)
end

function CombatFont:IsOutlineTarget(name)
    local lowered = tostring(name or ""):lower()
    if lowered == "combattext:fontstring"
        or lowered == "combattextframe:fontstring"
        or lowered == "floatingcombattextframe:fontstring" then
        return true
    end
    if lowered:find("^combattextfont") or lowered:find("^damagefont") or lowered:find("^damagetextfont") then
        return true
    end
    return lowered == "damagenumberfont"
        or lowered == "combatdamagefont"
        or lowered == "combathealingabsorbglowfont"
        or lowered == "worldfont"
        or lowered == "systemfont_world"
        or lowered == "systemfont_world_thickoutline"
end

function CombatFont:IsSpacingTarget(name)
    local lowered = tostring(name or ""):lower()
    return lowered == "combattextfont"
        or lowered == "combattextfontoutline"
        or lowered == "combattext:fontstring"
        or lowered == "combattextframe:fontstring"
        or lowered == "floatingcombattextframe:fontstring"
end

function CombatFont:GetOutlineFlags()
    local mode = tostring(type(FontMagicDB) == "table" and FontMagicDB.combatTextOutlineMode or "NONE"):upper()
    if mode == "THICK" or mode == "THICKOUTLINE" or mode == "2" then return "THICKOUTLINE" end
    if mode == "OUTLINE" or mode == "1" then return "OUTLINE" end
    return ""
end

function CombatFont:GetCompatFlags()
    local flags = self:GetOutlineFlags()
    return flags, flags
end

function CombatFont.GlobalLock:ShouldLockCombatTextFont()
    return CombatFont:IsManaged()
end

function CombatFont.GlobalLock:IsManagedGlobal(name)
    return name == "DAMAGE_TEXT_FONT" or name == "COMBAT_TEXT_FONT"
end

function CombatFont.GlobalLock:GetLockedPath(name)
    if not self:IsManagedGlobal(name) or not self:ShouldLockCombatTextFont() then return nil end
    local values = rawget(self, "values")
    local path = type(values) == "table" and values[name] or rawget(self, "path")
    return type(path) == "string" and path ~= "" and path or nil
end

function CombatFont.GlobalLock:GetGlobalForDefaultCapture(name)
    if type(name) ~= "string" or name == "" then return nil end
    local locked = self:GetLockedPath(name)
    local value = rawget(_G, name)
    if Compat.IsSecretValue(value) then return nil end
    if type(value) ~= "string" or value == "" or value == locked then return nil end
    return value
end

function CombatFont.GlobalLock:Own(path)
    if Compat.IsSecretValue(path) then return false end
    if type(path) ~= "string" or path == "" then return false end
    if not self.path then
        self.originals = {}
        for _, name in ipairs({ "DAMAGE_TEXT_FONT", "COMBAT_TEXT_FONT" }) do
            local value = rawget(_G, name)
            if Compat.IsSecretValue(value) then return false end
            self.originals[name] = { present = value ~= nil, value = value }
        end
    end
    self.path = path
    self.values = self.values or {}
    self.values.DAMAGE_TEXT_FONT = path
    self.values.COMBAT_TEXT_FONT = path
    rawset(_G, "DAMAGE_TEXT_FONT", path)
    rawset(_G, "COMBAT_TEXT_FONT", path)
    return true
end

function CombatFont.GlobalLock:ObserveExternalWrites()
    if not self:ShouldLockCombatTextFont() then return false end

    local values = type(self.values) == "table" and self.values or nil
    if not values then return false end

    self.originals = type(self.originals) == "table" and self.originals or {}
    local changed = false
    for _, name in ipairs({ "DAMAGE_TEXT_FONT", "COMBAT_TEXT_FONT" }) do
        local wanted = values[name]
        if type(wanted) == "string" and wanted ~= "" then
            local current = rawget(_G, name)
            if not Compat.IsSecretValue(current)
                and CombatFont:NormalizePath(current) ~= CombatFont:NormalizePath(wanted) then
                -- Another addon changed this global while FontMagic owned it.
                -- Preserve that addon's latest value as the release baseline,
                -- then let FontMagic reassert its active selection. This makes
                -- ownership cooperative: FontMagic wins while enabled, but a
                -- Reset hands control back to the other addon's current choice.
                self.originals[name] = { present = current ~= nil, value = current }
                changed = true
            end
        end
    end
    return changed
end

function CombatFont.GlobalLock:Reassert()
    if not self:ShouldLockCombatTextFont() then return false end
    local values = type(self.values) == "table" and self.values or nil
    if not values then return false end

    local wrote = false
    for _, name in ipairs({ "DAMAGE_TEXT_FONT", "COMBAT_TEXT_FONT" }) do
        local wanted = values[name]
        if type(wanted) == "string" and wanted ~= "" then
            rawset(_G, name, wanted)
            wrote = true
        end
    end
    return wrote
end

function CombatFont.GlobalLock:Release(damagePath, combatPath, retainForRetry)
    local values = type(self.values) == "table" and self.values or nil
    local wasOwned = self.path ~= nil or (values and (
        values.DAMAGE_TEXT_FONT ~= nil or values.COMBAT_TEXT_FONT ~= nil
    ))
    if wasOwned then
        local originals = type(self.originals) == "table" and self.originals or nil
        local function restore(name, fallback)
            local original = originals and originals[name] or nil
            if original then
                if original.present then
                    rawset(_G, name, original.value)
                else
                    rawset(_G, name, nil)
                end
            elseif type(fallback) == "string" and fallback ~= "" then
                rawset(_G, name, fallback)
            end
        end
        restore("DAMAGE_TEXT_FONT", damagePath)
        restore("COMBAT_TEXT_FONT", combatPath)
    end
    if not retainForRetry then
        self.path = nil
        self.originals = nil
        if values then
            self.values.DAMAGE_TEXT_FONT = nil
            self.values.COMBAT_TEXT_FONT = nil
        end
    end
    return true
end

-- Compatibility aliases retained for integrations and prior FontMagic hooks.
CombatFont.GlobalLock.OwnCombatTextFontGlobals = CombatFont.GlobalLock.Own
CombatFont.GlobalLock.ReleaseCombatTextFontGlobals = CombatFont.GlobalLock.Release
function CombatFont.GlobalLock:SetCombatTextFontGlobals(path, damageDefault, combatDefault)
    if self:ShouldLockCombatTextFont() then return self:Own(path) end
    return self:Release(damageDefault, combatDefault)
end

function CombatFont:CaptureDefaults()
    -- Capture again whenever a new ownership cycle begins. Other addons (or
    -- Blizzard itself) may legitimately change these globals while FontMagic
    -- is released, and the next reset must restore that new state rather than
    -- a value observed at initial addon load.
    if self.GlobalLock.path then return end
    local damage = self.GlobalLock:GetGlobalForDefaultCapture("DAMAGE_TEXT_FONT")
    local combat = self.GlobalLock:GetGlobalForDefaultCapture("COMBAT_TEXT_FONT")
    if damage then self.defaultDamagePath = damage end
    if combat then self.defaultCombatPath = combat end
end

function CombatFont:GetDefaultPath()
    self:CaptureDefaults()
    return self.defaultDamagePath or self.defaultCombatPath or self.FallbackPath
end

function CombatFont:NormalizePath(path)
    if Compat.IsSecretValue(path) then return nil end
    if type(path) ~= "string" then return nil end
    return path:gsub("/", "\\"):lower()
end

function CombatFont:NormalizeFlags(flags)
    if Compat.IsSecretValue(flags) then return nil end
    local tokens, seen = {}, {}
    for token in tostring(flags or ""):gmatch("[^,]+") do
        local normalized = (token:match("^%s*(.-)%s*$") or token):upper()
        if normalized ~= "" and not seen[normalized] then
            seen[normalized] = true
            tokens[#tokens + 1] = normalized
        end
    end
    table.sort(tokens)
    return table.concat(tokens, ",")
end

function CombatFont:FontTupleMatches(object, path, size, flags)
    if Compat.IsSecretValue(path) or Compat.IsSecretValue(size) or Compat.IsSecretValue(flags) then
        return false
    end
    local ok, currentPath, currentSize, currentFlags = Compat.GetFontTuple(object)
    if not ok then return false end
    return self:NormalizePath(currentPath) == self:NormalizePath(path)
        and tonumber(currentSize) == tonumber(size)
        and self:NormalizeFlags(currentFlags) == self:NormalizeFlags(flags)
end

function CombatFont:GetSpacingValue(object)
    if not Compat.CanInspectObject(object) or type(object.GetSpacing) ~= "function" then return nil end
    local ok, spacing = pcall(object.GetSpacing, object)
    if not ok or Compat.IsSecretValue(spacing) then return nil end
    return tonumber(spacing)
end

function CombatFont:TrySetSpacing(object, spacing)
    if Compat.IsSecretValue(spacing) or not Compat.CanInspectObject(object) then return false end
    spacing = tonumber(spacing)
    if spacing == nil or not (object and type(object.SetSpacing) == "function") then
        return false
    end
    if self:GetSpacingValue(object) == nil then return false end
    local ok = pcall(object.SetSpacing, object, spacing)
    if not ok then return false end
    return self:GetSpacingValue(object) == spacing
end

function CombatFont:MarkObjectRejected(object, path)
    if object then self.objectRejections[object] = self:NormalizePath(path) end
end

function CombatFont:ClearObjectRejection(object)
    if object then self.objectRejections[object] = nil end
end

function CombatFont:IsObjectRejectedForPath(object, path)
    if not object then return false end
    local rejected = self.objectRejections[object]
    local wanted = self:NormalizePath(path)
    return rejected ~= nil and wanted ~= nil and rejected == wanted
end

function CombatFont:ObserveExternalObject(object)
    if not Compat.CanInspectObject(object) then return false end
    local state = object and self.objectBackups[object] or nil
    if not (state and state.managed and type(object.GetFont) == "function") then
        return false
    end

    local ok, currentPath, currentSize, currentFlags = Compat.GetFontTuple(object)
    if not ok or type(currentPath) ~= "string" or currentPath == ""
        or type(currentSize) ~= "number" then
        return false
    end

    local drifted = false
    if state.faceManaged then
        local wantedPath = self.GlobalLock:GetLockedPath("DAMAGE_TEXT_FONT")
            or self.GlobalLock:GetLockedPath("COMBAT_TEXT_FONT")
        if wantedPath and self:NormalizePath(currentPath) ~= self:NormalizePath(wantedPath) then
            drifted = true
        elseif state.managedSize and tonumber(currentSize) ~= tonumber(state.managedSize) then
            drifted = true
        elseif state.rendererFlagsManaged
            and self:NormalizeFlags(currentFlags) ~= state.effectiveRendererFlags then
            drifted = true
        elseif state.outlineManaged
            and self:GetOutlineToken(currentFlags) ~= state.effectiveOutline then
            drifted = true
        end
    elseif state.outlineManaged
        and self:GetOutlineToken(currentFlags) ~= state.effectiveOutline then
        drifted = true
    end

    if not drifted then return false end

    if state.faceManaged then
        state.path, state.size, state.flags = currentPath, currentSize, currentFlags or ""
    elseif state.outlineManaged then
        -- Outline-only ownership never owns the face. Keep the live face and
        -- remember only the external outline baseline that Reset must restore.
        state.flags = currentFlags or ""
    end
    return true
end

function CombatFont:ObserveExternalManagedObjects()
    local changed = false
    for object in pairs(self.objectBackups) do
        if self:ObserveExternalObject(object) then changed = true end
    end
    return changed
end

function CombatFont:ObserveExternalGlobals()
    return self.GlobalLock:ObserveExternalWrites()
end

function CombatFont:TrySetFont(object, path, size, flags, fallbackFlags)
    if not Compat.CanInspectObject(object) or type(object.SetFont) ~= "function" then return false end
    if Compat.IsSecretValue(path) or Compat.IsSecretValue(size)
        or Compat.IsSecretValue(flags) or Compat.IsSecretValue(fallbackFlags) then return false end
    if Compat.GetFontTuple(object) ~= true then return false end

    local function attempt(useFlags)
        local ok, result = pcall(object.SetFont, object, path, size, useFlags)
        if not ok then return false end
        if not Compat.IsSecretValue(result) and result == false then return false end
        if type(object.GetFont) == "function" then
            local okGet, currentPath = Compat.GetFontTuple(object)
            -- A setter/post-hook can make the tuple restricted immediately.
            -- Keep the original snapshot until verification becomes possible.
            if okGet == nil then return true, useFlags end
            if okGet and type(currentPath) == "string"
                and self:NormalizePath(currentPath) ~= self:NormalizePath(path) then
                return false
            end
        end
        return true, useFlags
    end

    local applied, effectiveFlags = attempt(flags)
    if applied then return true, effectiveFlags end
    if type(fallbackFlags) == "string" and fallbackFlags ~= flags then
        return attempt(fallbackFlags)
    end
    return false
end

function CombatFont:GetOutlineToken(flags)
    if Compat.IsSecretValue(flags) then return nil end
    local upper = tostring(flags or ""):upper()
    if upper:find("THICKOUTLINE", 1, true) then return "THICKOUTLINE" end
    if upper:find("OUTLINE", 1, true) then return "OUTLINE" end
    return "NONE"
end

function CombatFont:GetEffectiveManagedOutline(object)
    local state = self.objectBackups[object]
    if not (state and state.managed and state.outlineManaged) then return nil end
    return state.effectiveOutline
end

function CombatFont:HasOutstandingOutlineOwnership()
    for _, state in pairs(self.objectBackups) do
        if state and state.managed and state.outlineManaged then return true end
    end
    return false
end

function CombatFont:CaptureObject(object)
    if not Compat.CanInspectObject(object) then return nil end
    local existing = self.objectBackups[object]
    if existing then return existing end

    local state = { managed = false }
    if type(object.GetFont) == "function" then
        local ok, path, size, flags = Compat.GetFontTuple(object)
        if ok == nil then return nil end
        if ok then state.path, state.size, state.flags = path, size, flags end
    end
    -- Spacing is captured lazily, immediately before FontMagic first changes
    -- it, and only for Blizzard's self-combat text objects. Shadow properties
    -- are never changed or owned.
    self.objectBackups[object] = state
    return state
end

function CombatFont:RestoreObject(object, state)
    if not Compat.CanInspectObject(object) then return false end
    if Compat.GetFontTuple(object) == nil then return false end
    if not (state and state.managed) then
        self.objectBackups[object] = nil
        return true
    end

    local restored = true
    if state.faceManaged and type(state.path) == "string" and type(state.size) == "number" then
        local applied = self:TrySetFont(object, state.path, state.size, state.flags or "", nil)
        restored = applied
            and self:FontTupleMatches(object, state.path, state.size, state.flags or "")
            and restored
    elseif state.outlineManaged and type(object.GetFont) == "function" then
        local ok, currentPath, currentSize, currentFlags = Compat.GetFontTuple(object)
        if ok and type(currentPath) == "string" and type(currentSize) == "number" then
            local originalOutline = self:GetOutlineToken(state.flags)
            local restoredFlags = self:WithOutlineFlag(currentFlags,
                originalOutline ~= "NONE" and originalOutline or nil)
            local applied = self:TrySetFont(object, currentPath, currentSize, restoredFlags, nil)
            restored = applied
                and self:FontTupleMatches(object, currentPath, currentSize, restoredFlags)
                and restored
        else
            restored = false
        end
    end
    if state.spacingManaged then
        local spacingRestored = state.spacingCaptured
            and type(state.spacing) == "number"
            and self:TrySetSpacing(object, state.spacing)
        restored = spacingRestored and restored
    end
    if restored then self.objectBackups[object] = nil end
    return restored
end

function CombatFont:Release()
    _G.FontMagicCombatTextApplying = true
    local ok, result = pcall(function()
        local objects = {}
        for object in pairs(self.objectBackups) do objects[#objects + 1] = object end
        local restored = true
        for _, object in ipairs(objects) do
            restored = self:RestoreObject(object, self.objectBackups[object]) and restored
        end
        self.GlobalLock:Release(
            self.defaultDamagePath or self.FallbackPath,
            self.defaultCombatPath or self.FallbackPath,
            not restored
        )
        return restored
    end)
    _G.FontMagicCombatTextApplying = false
    return ok and result ~= false
end

function CombatFont:WithOutlineFlag(currentFlags, wantedOutline)
    if Compat.IsSecretValue(currentFlags) or Compat.IsSecretValue(wantedOutline) then return nil end
    local kept, seen = {}, {}
    for token in tostring(currentFlags or ""):gmatch("[^,]+") do
        local trimmed = token:match("^%s*(.-)%s*$") or token
        local upper = trimmed:upper()
        if trimmed ~= "" and upper ~= "OUTLINE" and upper ~= "THICKOUTLINE" and not seen[upper] then
            seen[upper] = true
            kept[#kept + 1] = trimmed
        end
    end
    if wantedOutline == "OUTLINE" or wantedOutline == "THICKOUTLINE" then
        kept[#kept + 1] = wantedOutline
    end
    return table.concat(kept, ",")
end

function CombatFont:ApplyObject(name, object, path, defaultSize, manageFace, managedSize)
    if not Compat.CanInspectObject(object) or type(object.SetFont) ~= "function" then return nil end
    if Compat.IsSecretValue(path) then return nil end
    if manageFace == nil then manageFace = true end
    if type(self.activeApplySeen) == "table" then
        self.activeApplySeen[object] = true
    end

    local currentPath, size, flags
    if type(object.GetFont) == "function" then
        local ok, reportedPath, reportedSize, reportedFlags = Compat.GetFontTuple(object)
        if ok == nil then return nil end
        if ok then currentPath, size, flags = reportedPath, reportedSize, reportedFlags end
    end
    local reportedSize = tonumber(size)
    managedSize = manageFace and tonumber(managedSize) or nil
    size = managedSize or reportedSize or tonumber(defaultSize) or 25
    if type(flags) ~= "string" then flags = "" end

    local reportedFlags = flags
    local state = self.objectBackups[object]
    if state then
        state.targetName = state.targetName or name
        state.defaultSize = state.defaultSize or defaultSize
        state.managedSize = managedSize or state.managedSize
    end
    local outlineTouched = type(FontMagicDB) == "table" and FontMagicDB.combatTextOutlineTouched
    local outlineTarget = self:IsOutlineTarget(name)
    local restoringOutline = not outlineTouched and outlineTarget and state and state.outlineManaged
    local fallbackFlags = nil
    if manageFace and self:IsSpacingTarget(name) then
        -- Match the original working renderer contract. FILTER/FIXEDHEIGHT are
        -- inherited FontFamily flags, not user outline choices; retaining them
        -- with a directly selected face makes Anniversary self text disappear
        -- at 25 or render at the inherited 106-point effective width.
        flags = self:GetOutlineFlags()
        fallbackFlags = flags
    elseif restoringOutline then
        flags = type(state.flags) == "string" and state.flags or ""
    elseif outlineTouched and outlineTarget then
        flags = self:WithOutlineFlag(flags, self:GetOutlineFlags())
        -- Some client FontObjects reject outline combinations. Retry without
        -- only the outline token while preserving unrelated flags such as
        -- MONOCHROME.
        fallbackFlags = self:WithOutlineFlag(reportedFlags, nil)
    end

    local flagsMatch = true
    if manageFace and self:IsSpacingTarget(name) then
        flagsMatch = self:NormalizeFlags(reportedFlags) == self:NormalizeFlags(flags)
    elseif restoringOutline then
        flagsMatch = self:NormalizeFlags(reportedFlags) == self:NormalizeFlags(flags)
    elseif outlineTouched and outlineTarget then
        flagsMatch = self:NormalizeFlags(reportedFlags)
            == self:NormalizeFlags(self:WithOutlineFlag(reportedFlags, self:GetOutlineFlags()))
    end
    local fontNeedsWrite = self:NormalizePath(currentPath) ~= self:NormalizePath(path)
        or not flagsMatch
        or (managedSize and reportedSize ~= managedSize)
    local spacingTarget = manageFace and self:IsSpacingTarget(name)
    local spacingBefore = spacingTarget and self:GetSpacingValue(object) or nil
    -- The old implementation called SetSpacing(0) even when GetSpacing already
    -- reported zero. Retain that observable behavior because Anniversary can
    -- carry inherited renderer state that is cleared only by the explicit set.
    local spacingNeedsWrite = spacingBefore ~= nil

    if not fontNeedsWrite and not spacingNeedsWrite then
            self:ClearObjectRejection(object)
            if restoringOutline then
                state.outlineManaged = false
                state.effectiveOutline = nil
            end
            return true
    end

    state = state or self:CaptureObject(object)
    if not state then return nil end
    state.targetName = state.targetName or name
    state.defaultSize = state.defaultSize or defaultSize
    state.managedSize = managedSize or state.managedSize
    -- Without a readable original font tuple FontMagic could apply a face but
    -- could never honor Reset exactly. Leave that target untouched instead.
    if not state.managed and (type(state.path) ~= "string" or state.path == "" or not reportedSize) then
        self.objectBackups[object] = nil
        -- Blizzard preallocates inactive combat-text FontStrings without a
        -- font tuple and assigns CombatTextFont only when a row is acquired.
        -- Such rows are not failed targets and must not veto a valid selection.
        return nil
    end
    local applied, effectiveFlags = true, reportedFlags
    if fontNeedsWrite then
        applied, effectiveFlags = self:TrySetFont(object, path, size, flags, fallbackFlags)
        if applied then
            local okTuple, actualPath, actualSize = Compat.GetFontTuple(object)
            if okTuple ~= nil and (not okTuple
                or self:NormalizePath(actualPath) ~= self:NormalizePath(path)
                or (managedSize and tonumber(actualSize) ~= managedSize)) then
                applied = false
            end
        end
        if applied then
            state.managed = true
            state.faceManaged = state.faceManaged or manageFace
            state.outlineManaged = outlineTouched and outlineTarget and true or false
            state.effectiveOutline = state.outlineManaged
                and self:GetOutlineToken(effectiveFlags or flags) or nil
            state.rendererFlagsManaged = manageFace and self:IsSpacingTarget(name) and true or false
            state.effectiveRendererFlags = state.rendererFlagsManaged
                and self:NormalizeFlags(effectiveFlags or flags) or nil
        end
    end

    if applied and spacingTarget and spacingBefore ~= nil and Compat.GetFontTuple(object) == true then
        local spacingAfterFont = self:GetSpacingValue(object)
        if spacingAfterFont ~= nil then
            if not state.spacingCaptured then
                state.spacingCaptured = true
                state.spacing = spacingBefore
            end
            self:TrySetSpacing(object, 0)
            local finalSpacing = self:GetSpacingValue(object)
            if finalSpacing ~= spacingBefore then
                state.managed = true
                state.spacingManaged = true
            end
            if finalSpacing ~= 0 then applied = false end
        end
    end

    if applied then
        self:ClearObjectRejection(object)
        if not state.managed then self.objectBackups[object] = nil end
    else
        if not state.managed then self.objectBackups[object] = nil end
        self:MarkObjectRejected(object, path)
    end
    return applied
end

function CombatFont:ApplyToDetachedOwned(path, preserveFace)
    local seen = type(self.activeApplySeen) == "table" and self.activeApplySeen or {}
    local appliedAny, allSucceeded, sawTarget = false, true, false
    for object, state in pairs(self.objectBackups) do
        if state and state.managed and not seen[object] then
            local usePath = path
            if preserveFace then
                local okFont, currentPath = Compat.GetFontTuple(object)
                if okFont then usePath = currentPath end
            end
            local applied = self:ApplyObject(
                state.targetName or "CombatText:FontString",
                object,
                usePath,
                state.defaultSize or state.size or 25,
                not preserveFace,
                not preserveFace and state.managedSize or nil
            )
            if applied ~= nil then
                sawTarget = true
                appliedAny = appliedAny or applied
                allSucceeded = applied and allSucceeded
            end
        end
    end
    if not sawTarget then return nil, true end
    return appliedAny, allSucceeded
end

function CombatFont:ApplyToFrame(rootName, path, preserveFace)
    local root = _G[rootName]
    if not root then return nil, false end

    local seen, appliedAny, allSucceeded, sawTarget = {}, false, true, false
    local function visit(region, depth)
        if depth > 5 or not Compat.CanInspectObject(region) or seen[region] then return end
        seen[region] = true
        if type(region.GetRegions) == "function" then
            local okRegions, regions = pcall(function() return { region:GetRegions() } end)
            if okRegions and type(regions) == "table" then
                for _, childRegion in ipairs(regions) do
                    if Compat.CanInspectObject(childRegion) and type(childRegion.GetObjectType) == "function" then
                        local okType, objectType = pcall(childRegion.GetObjectType, childRegion)
                        if okType and not Compat.IsSecretValue(objectType) and objectType == "FontString" then
                            local usePath = path
                            if preserveFace then
                                local okFont, currentPath = Compat.GetFontTuple(childRegion)
                                if okFont then usePath = currentPath end
                            end
                            local applied = self:ApplyObject(
                                rootName .. ":FontString", childRegion, usePath, 25, not preserveFace
                            )
                            if applied ~= nil then
                                sawTarget = true
                                appliedAny = appliedAny or applied
                                allSucceeded = applied and allSucceeded
                            end
                        end
                    end
                end
            end
        end
        if type(region.GetChildren) == "function" then
            local okChildren, children = pcall(function() return { region:GetChildren() } end)
            if okChildren and type(children) == "table" then
                for _, child in ipairs(children) do visit(child, depth + 1) end
            end
        end
    end
    visit(root, 0)
    if not sawTarget then return nil, true end
    return appliedAny, allSucceeded
end

function CombatFont:HasManagedFace()
    if self.GlobalLock.path then return true end
    for _, state in pairs(self.objectBackups) do
        if state and state.managed and state.faceManaged then return true end
    end
    return false
end

function CombatFont:AreManagedObjectsApplied(path)
    local wantedPath = self:NormalizePath(path)
    for object, state in pairs(self.objectBackups) do
        if state and state.managed then
            local ok, currentPath, currentSize, currentFlags = Compat.GetFontTuple(object)
            -- A restricted tuple is unknown, not evidence of an overwritten
            -- font. Keep its ownership snapshot and retry when readable.
            if ok ~= nil then
                if not ok or type(currentPath) ~= "string" or currentPath == "" then return false end
                local rejectionPath = state.faceManaged and path or currentPath
                if not self:IsObjectRejectedForPath(object, rejectionPath) then
                    if state.faceManaged then
                        if not wantedPath or self:NormalizePath(currentPath) ~= wantedPath then
                            return false
                        end
                        if state.managedSize and tonumber(currentSize) ~= state.managedSize then
                            return false
                        end
                    end
                    if state.outlineManaged
                        and self:GetOutlineToken(currentFlags) ~= state.effectiveOutline then
                        return false
                    end
                    if state.rendererFlagsManaged
                        and self:NormalizeFlags(currentFlags) ~= state.effectiveRendererFlags then
                        return false
                    end
                    if state.spacingManaged then
                        local spacing = self:GetSpacingValue(object)
                        if spacing ~= nil and spacing ~= 0 then return false end
                    end
                end
            end
        end
    end
    return true
end

function CombatFont:AreLiveFrameObjectsApplied(path)
    local wantedPath = self:NormalizePath(path)
    local outlineTouched = type(FontMagicDB) == "table" and FontMagicDB.combatTextOutlineTouched
    local wantedOutline = self:GetOutlineToken(self:GetOutlineFlags())
    local seen = {}

    for _, rootName in ipairs({ "CombatText", "CombatTextFrame", "FloatingCombatTextFrame" }) do
        local root = _G[rootName]
        local valid = true
        local function visit(region, depth)
            if not valid or depth > 5 or not Compat.CanInspectObject(region) or seen[region] then return end
            seen[region] = true
            if type(region.GetRegions) == "function" then
                local okRegions, regions = pcall(function() return { region:GetRegions() } end)
                if okRegions and type(regions) == "table" then
                    for _, childRegion in ipairs(regions) do
                        if Compat.CanInspectObject(childRegion) and type(childRegion.GetObjectType) == "function" then
                            local okType, objectType = pcall(childRegion.GetObjectType, childRegion)
                            if okType and not Compat.IsSecretValue(objectType)
                                and objectType == "FontString" then
                                local okFont, currentPath, _, currentFlags = Compat.GetFontTuple(childRegion)
                                if okFont and type(currentPath) == "string" and currentPath ~= "" then
                                    local rejectionPath = wantedPath and path or currentPath
                                    if not self:IsObjectRejectedForPath(childRegion, rejectionPath) then
                                        if wantedPath and self:NormalizePath(currentPath) ~= wantedPath then
                                            valid = false
                                            return
                                        end
                                        if wantedPath and self:IsSpacingTarget(rootName .. ":FontString") then
                                            if self:NormalizeFlags(currentFlags)
                                                ~= self:NormalizeFlags(self:GetOutlineFlags()) then
                                                valid = false
                                                return
                                            end
                                        elseif outlineTouched then
                                            local state = self.objectBackups[childRegion]
                                            local effective = state and state.managed and state.outlineManaged
                                                and state.effectiveOutline or wantedOutline
                                            if self:GetOutlineToken(currentFlags) ~= effective then
                                                valid = false
                                                return
                                            end
                                        end
                                        if wantedPath and self:IsSpacingTarget(rootName .. ":FontString") then
                                            local spacing = self:GetSpacingValue(childRegion)
                                            if spacing ~= nil and spacing ~= 0 then
                                                valid = false
                                                return
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if type(region.GetChildren) == "function" then
                local okChildren, children = pcall(function() return { region:GetChildren() } end)
                if okChildren and type(children) == "table" then
                    for _, child in ipairs(children) do visit(child, depth + 1) end
                end
            end
        end
        visit(root, 0)
        if not valid then return false end
    end
    return true
end

function CombatFont:IsOutlineOwnershipApplied()
    local checked = {}
    local wanted = self:GetOutlineToken(self:GetOutlineFlags())
    for _, definition in ipairs(self.FontObjects) do
        local object = _G[definition.name]
        if Compat.CanInspectObject(object) and self:IsOutlineTarget(definition.name) then
            checked[object] = true
            local ok, path, _, flags = Compat.GetFontTuple(object)
            -- A readable optional target may permanently reject this outline
            -- combination. ApplyObject records that exact face rejection so the
            -- steady monitor can remain quiet; explicit Apply/addon-load/login
            -- reconciliation still retries it.
            if ok ~= nil then
                if not ok or type(path) ~= "string" or path == "" then return false end
                if not self:IsObjectRejectedForPath(object, path) then
                    local state = self.objectBackups[object]
                    local effective = state and state.managed and state.outlineManaged and state.effectiveOutline or wanted
                    if self:GetOutlineToken(flags) ~= effective then return false end
                end
            end
        end
    end
    for object, state in pairs(self.objectBackups) do
        if not checked[object] and state and state.managed and state.outlineManaged then
            local ok, path, _, flags = Compat.GetFontTuple(object)
            if ok ~= nil then
                if not ok or type(path) ~= "string" or path == "" then return false end
                if self:GetOutlineToken(flags) ~= state.effectiveOutline then return false end
            end
        end
    end
    return true
end

function CombatFont:ApplyOutlineOnly()
    if type(FontMagicDB) ~= "table" or not FontMagicDB.combatTextOutlineTouched then
        local released = self:Release()
        return released, released
    end

    -- Moving from a selected FontMagic face to outline-only first restores every
    -- original face, then acquires only the outline token on each live object.
    if self:HasManagedFace() and not self:Release() then return false, false end

    _G.FontMagicCombatTextApplying = true
    self.activeApplySeen = {}
    local ok, result = pcall(function()
        local appliedAny, sawTarget, allSucceeded = false, false, true
        for _, definition in ipairs(self.FontObjects) do
            local object = _G[definition.name]
            local currentPath
            if Compat.CanInspectObject(object) then
                local okFont, reportedPath = Compat.GetFontTuple(object)
                if okFont then currentPath = reportedPath end
            end
            local applied = self:ApplyObject(
                definition.name, object, currentPath, definition.defaultSize, false
            )
            if applied ~= nil then
                sawTarget = true
                appliedAny = appliedAny or applied
                allSucceeded = applied and allSucceeded
            end
        end

        for _, rootName in ipairs({ "CombatText", "CombatTextFrame", "FloatingCombatTextFrame" }) do
            local frameApplied, frameSucceeded = self:ApplyToFrame(rootName, nil, true)
            if frameApplied ~= nil then
                sawTarget = true
                appliedAny = appliedAny or frameApplied
                allSucceeded = frameSucceeded and allSucceeded
            end
        end
        local detachedApplied, detachedSucceeded = self:ApplyToDetachedOwned(nil, true)
        if detachedApplied ~= nil then
            sawTarget = true
            appliedAny = appliedAny or detachedApplied
            allSucceeded = detachedSucceeded and allSucceeded
        end
        return allSucceeded and (appliedAny or not sawTarget)
    end)
    self.activeApplySeen = nil
    _G.FontMagicCombatTextApplying = false
    if not ok then return false, false end
    -- Live FontObjects are best-effort outline targets. Reaching this point
    -- means any prior face ownership was released successfully and the durable
    -- outline preference can be retried as later objects become available.
    return result ~= false, true
end

function CombatFont:ApplyPath(path)
    if Compat.IsSecretValue(path) then return false end
    if type(path) ~= "string" or path == "" then return false end
    if not self:IsManaged() then return self:Release() end

    self:CaptureDefaults()

    _G.FontMagicCombatTextApplying = true
    self.activeApplySeen = {}
    local ok, complete, committed = pcall(function()
        local appliedAny, sawTarget, allSucceeded = false, false, true
        for _, definition in ipairs(self.FontObjects) do
            local object = _G[definition.name]
            local applied = self:ApplyObject(
                definition.name, object, path, definition.defaultSize, true, definition.managedSize
            )
            if applied ~= nil then
                sawTarget = true
                appliedAny = appliedAny or applied
                allSucceeded = applied and allSucceeded
            end
        end

        for _, rootName in ipairs({ "CombatText", "CombatTextFrame", "FloatingCombatTextFrame" }) do
            local frameApplied, frameSucceeded = self:ApplyToFrame(rootName, path)
            if frameApplied ~= nil then
                sawTarget = true
                appliedAny = appliedAny or frameApplied
                allSucceeded = frameSucceeded and allSucceeded
            end
        end

        -- Blizzard can detach pooled rows from the live frame tree while their
        -- exact ownership snapshots remain valid. Keep those rows in the same
        -- face/outline transition as reachable objects without visiting live
        -- targets twice.
        local detachedApplied, detachedSucceeded = self:ApplyToDetachedOwned(path, false)
        if detachedApplied ~= nil then
            sawTarget = true
            appliedAny = appliedAny or detachedApplied
            allSucceeded = detachedSucceeded and allSucceeded
        end

        -- A path reaching this method has already passed Fonts.ResolveKey's
        -- exact client probe.  Live FontObjects and pooled FontStrings are
        -- best-effort reconciliation targets; the global paths are the durable
        -- engine contract used on the next UI load/login.
        local globalOwned = self.GlobalLock:Own(path)
        return allSucceeded and (appliedAny or not sawTarget), globalOwned
    end)
    self.activeApplySeen = nil
    _G.FontMagicCombatTextApplying = false

    if not ok then
        local fix = _G.FontMagicCombatTextFix
        if fix and type(fix.IsDebugEnabled) == "function" and fix:IsDebugEnabled() and type(fix.DbgLine) == "function" then
            fix:DbgLine("combat font apply error: " .. tostring(complete))
        end
        return false, false
    end
    return complete ~= false, committed == true
end

function CombatFont:ApplySaved()
    if type(FontMagicDB) ~= "table" then return false end
    local key = FontMagicDB.selectedFont
    if type(key) ~= "string" or key == "" then
        if not FontMagicDB.combatTextOutlineTouched then return self:Release() end
        return self:ApplyOutlineOnly()
    end

    local path, group, filename = Fonts.ResolveKey(key)
    if not path then
        local canonical = type(Fonts.CanonicalizeKey) == "function" and Fonts.CanonicalizeKey(key) or nil
        local released, committed
        if FontMagicDB.combatTextOutlineTouched then
            released, committed = self:ApplyOutlineOnly()
        else
            released = self:Release()
            committed = released
        end
        if committed == nil then committed = released end
        -- A catalogued face can be temporarily unavailable while the optional
        -- custom-font companion or the client font backend is not ready. Keep
        -- that durable choice so explicit addon-load/login reconciliation can
        -- recover it, while still releasing any stale live face immediately.
        -- Truly unknown keys are cleared only after exact release succeeds.
        if committed then FontMagicDB.selectedFont = canonical or "" end
        return released, committed
    end
    if group and filename then FontMagicDB.selectedFont = group .. "/" .. filename end
    return self:ApplyPath(path)
end
