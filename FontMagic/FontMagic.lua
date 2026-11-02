-- FontMagic.lua
local addonName, FM = ...

if type(FM) ~= "table" then
    error("FontMagic.lua requires the shared addon table", 0)
end

local Compat = FM.Compat
local CVars = FM.CVars
local Fonts = FM.Fonts
local CombatFont = FM.CombatFont
local minimapButton

FM.Database.Initialize()
Fonts.MigrateSavedKeys()

-- Public alias retained for existing FontMagic debug commands and integrations.
_G.FontMagicCombatTextFix = FM.CombatTextFix

function FM.UI.ReportRejectedSetting(label)
    local detail = type(label) == "string" and label ~= "" and (" (" .. label .. ")") or ""
    print("|cFFFF3333[FontMagic]|r WoW rejected that setting" .. detail .. "; the previous value was kept.")
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage("FontMagic: WoW rejected that setting" .. detail .. ".", 1, 0.2, 0.2)
    end
end

-- ---------------------------------------------------------------------------
-- Combat text reconciliation + debug
-- ---------------------------------------------------------------------------
-- Older FontMagic releases repaired malformed scrolling-text FontStrings here.
-- The current implementation is ownership-gated: a passive install never
-- rewrites Blizzard text, flags, spacing, or localized number separators.
-- With a selected face active, Core/CombatFont normalizes only Blizzard's
-- self-combat letter spacing and owns that change for exact Reset.
-- Debug tooling remains available via `/fontmagic debug on|off|toggle|dump`.

_G.FontMagicCombatTextFix = (type(_G) == "table" and type(_G.FontMagicCombatTextFix) == "table") and _G.FontMagicCombatTextFix or {}
_G.FontMagicCombatTextFix.wrap = _G.FontMagicCombatTextFix.wrap or { depth = 0, wrapped = {}, orig = {}, logCount = 0, logLimit = 150, lastSpacingScan = 0 }
if type(_G.FontMagicCombatTextFix.spaceSeps) ~= "table" then
    _G.FontMagicCombatTextFix.spaceSeps = { " ", "\194\160", "\226\128\175", "\226\128\137", "\226\128\135" } -- SP, NBSP, NNBSP, THIN, FIG
end

function _G.FontMagicCombatTextFix:GetSelectedCombatTextFontPath()
    if type(FontMagicDB) ~= "table" then return nil end
    local key = FontMagicDB.selectedFont
    if type(key) ~= "string" or key == "" then return nil end

    local path = Fonts.ResolveKey(key)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return nil
end

function _G.FontMagicCombatTextFix:GetManagedCombatTextFontPath()
    local selected = self:GetSelectedCombatTextFontPath()
    if selected then return selected end
    return nil
end

function _G.FontMagicCombatTextFix:IsSelectedCombatTextFontApplied()
    local want = self:GetManagedCombatTextFontPath()
    if not want then
        if type(FontMagicDB) == "table" and type(FontMagicDB.selectedFont) == "string"
            and FontMagicDB.selectedFont ~= "" then
            local canonical = type(Fonts.CanonicalizeKey) == "function"
                and Fonts.CanonicalizeKey(FontMagicDB.selectedFont) or nil
            if not canonical then
                -- A non-catalogued key still needs a retryable release/cleanup.
                return false
            end
            if type(CombatFont.HasManagedFace) == "function" and CombatFont:HasManagedFace() then
                return false
            end
            -- A known face may be unavailable for this load. Once its prior
            -- live ownership is released, stay dormant until an explicit
            -- addon-load/login reconciliation probes it again.
            if FontMagicDB.combatTextOutlineTouched
                and type(CombatFont.IsOutlineOwnershipApplied) == "function" then
                local applied = CombatFont:IsOutlineOwnershipApplied()
                if applied and type(CombatFont.AreLiveFrameObjectsApplied) == "function" then
                    applied = CombatFont:AreLiveFrameObjectsApplied(nil)
                end
                return applied
            end
            return true
        end
        if type(FontMagicDB) == "table" and FontMagicDB.combatTextOutlineTouched
            and type(CombatFont.IsOutlineOwnershipApplied) == "function" then
            local applied = CombatFont:IsOutlineOwnershipApplied()
            if applied and type(CombatFont.AreLiveFrameObjectsApplied) == "function" then
                applied = CombatFont:AreLiveFrameObjectsApplied(nil)
            end
            return applied
        end
        return true
    end

    local function normalize(path)
        if Compat.IsSecretValue(path) then return nil end
        if type(path) ~= "string" or path == "" then return nil end
        return path:gsub("/", "\\"):lower()
    end

    local wantNorm = normalize(want)
    if not wantNorm then return true end

    local function objectMatches(name, obj)
        local ok, current, _, flags = Compat.GetFontTuple(obj)
        if not ok then return nil end
        local currentNorm = normalize(current)
        if not currentNorm then return nil end
        if type(CombatFont.IsObjectRejectedForPath) == "function"
            and CombatFont:IsObjectRejectedForPath(obj, want) then
            -- ApplyPath already tried this readable optional target for the
            -- current face and left it untouched after the client rejected it.
            -- Relevant addon-load hooks and explicit Apply calls still retry;
            -- the steady monitor must not spin forever on a permanent reject.
            return true
        end
        if currentNorm ~= wantNorm then return false end

        if type(CombatFont.IsSpacingTarget) == "function"
            and CombatFont:IsSpacingTarget(name)
            and type(obj.GetSpacing) == "function" then
            local spacing = CombatFont:GetSpacingValue(obj)
            if spacing ~= nil and spacing ~= 0 then return false end
            if type(CombatFont.NormalizeFlags) == "function"
                and CombatFont:NormalizeFlags(flags)
                    ~= CombatFont:NormalizeFlags(CombatFont:GetOutlineFlags()) then
                return false
            end
        end

        local uflags = type(flags) == "string" and flags:upper() or ""
        if uflags:find("SLUG", 1, true) then return false end

        if FontMagicDB and FontMagicDB.combatTextOutlineTouched and CombatFont:IsOutlineTarget(name) then
            local wantFlags = CombatFont:GetOutlineFlags()
            local hasThick = uflags:find("THICKOUTLINE", 1, true) and true or false
            local hasOutline = (hasThick or uflags:find("OUTLINE", 1, true)) and true or false

            -- A few client FontObjects reject particular outline combinations.
            -- CombatFont records the verified compatibility fallback it actually
            -- applied so the ownership monitor does not retry it forever.
            local effective = type(CombatFont.GetEffectiveManagedOutline) == "function"
                and CombatFont:GetEffectiveManagedOutline(obj) or nil
            if effective ~= nil then
                return CombatFont:GetOutlineToken(uflags) == effective
            end

            if wantFlags == "THICKOUTLINE" then
                if not hasThick then return false end
            elseif wantFlags == "OUTLINE" then
                if hasThick or not hasOutline then return false end
            else
                if hasOutline then return false end
            end
        end

        return true
    end

    local gDamage = normalize(_G and _G.DAMAGE_TEXT_FONT)
    if gDamage then
        if gDamage ~= wantNorm then
            return false
        end
    end

    local gCombat = normalize(_G and _G.COMBAT_TEXT_FONT)
    if gCombat then
        if gCombat ~= wantNorm then
            return false
        end
    end

    local sawManagedObject = false
    local definitions = type(CombatFont.FontObjects) == "table" and CombatFont.FontObjects or {}
    for _, definition in ipairs(definitions) do
        local name = type(definition) == "table" and definition.name or nil
        if type(name) == "string" and name ~= "" then
            local matched = objectMatches(name, _G and _G[name])
            if matched ~= nil then
                if not matched then
                    return false
                end
                sawManagedObject = true
            end
        end
    end

    if type(CombatFont.AreManagedObjectsApplied) == "function"
        and not CombatFont:AreManagedObjectsApplied(want) then
        return false
    end
    if type(CombatFont.AreLiveFrameObjectsApplied) == "function"
        and not CombatFont:AreLiveFrameObjectsApplied(want) then
        return false
    end

    if sawManagedObject or gDamage or gCombat then
        return true
    end

    return false
end

function _G.FontMagicCombatTextFix:MaybeRepairSelectedCombatTextFont(throttleSeconds)
    if type(self.HasManagedCombatTextFont) ~= "function" or not self:HasManagedCombatTextFont() then return end

    local w = self.wrap
    if type(w) ~= "table" then return end

    local now = (type(GetTime) == "function") and GetTime() or 0
    local throttle = tonumber(throttleSeconds) or 0
    local last = tonumber(w.lastFontCheck) or 0
    if throttle > 0 and now > 0 and (now - last) < throttle then
        return
    end

    -- Throttle the validation scan itself, not only actual repairs. Combat-text
    -- messages can arrive many times in one frame even while the managed font is
    -- already correct; without this timestamp every message rechecks every font
    -- object and global.
    w.lastFontCheck = now

    if self:IsSelectedCombatTextFontApplied() then
        return
    end

    -- Capture a controller's latest tuple before reclaiming it. FontMagic must
    -- win while active, but Reset should return to the latest external choice
    -- rather than the value that happened to exist at initial load.
    if type(CombatFont.ObserveExternalGlobals) == "function" then
        pcall(CombatFont.ObserveExternalGlobals, CombatFont)
    end
    if type(CombatFont.ObserveExternalManagedObjects) == "function" then
        pcall(CombatFont.ObserveExternalManagedObjects, CombatFont)
    end

    w.lastFontRepair = now
    CombatFont:ApplySaved()

    if self:IsDebugEnabled() then
        self:DbgLine("combat font repair: reapplied saved font after it was overwritten")
    end
end

function _G.FontMagicCombatTextFix:IsDebugEnabled()
    return (FontMagicDB and FontMagicDB.__fmDebugCombatText) and true or false
end

function _G.FontMagicCombatTextFix:DbgPrint(line)
    line = tostring(line or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
        return
    end
    if type(print) == "function" then
        print(line)
    end
end

function _G.FontMagicCombatTextFix:DbgLine(line)
    self:DbgPrint("|cFF00FF00[FontMagic]|r " .. tostring(line or ""))
end

function _G.FontMagicCombatTextFix:PatternEscape(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

function _G.FontMagicCombatTextFix:IsNumericish(msg)
    if Compat.IsSecretValue(msg) then return false end
    if type(msg) ~= "string" or msg == "" then return false end
    if not msg:match("%d") then return false end

    local s = msg
    s = s:gsub("%d", "")
    s = s:gsub("[+%-]", "")
    s = s:gsub("[%(%)]", "")
    s = s:gsub("[%[%]]", "")
    s = s:gsub("[%{%}]", "")
    s = s:gsub("%s", "")
    if type(self.spaceSeps) == "table" then
        for _, sep in ipairs(self.spaceSeps) do
            if type(sep) == "string" and sep ~= "" then
                s = s:gsub(sep, "")
            end
        end
    end
    s = s:gsub("[,%.']", "")
    return s == ""
end

function _G.FontMagicCombatTextFix:SanitizeMessage(msg)
    if Compat.IsSecretValue(msg) then return msg, false end
    if type(msg) ~= "string" or msg == "" then return msg, false end
    if not msg:match("%d") then return msg, false end
    if not self:IsNumericish(msg) then return msg, false end

    local out = msg
    -- If the combat-text pipeline produces numeric strings with extra whitespace-like
    -- separators (including NBSP/thin spaces), remove them. This is low-collateral
    -- because we only apply it to numeric-only messages (digits/punct/signs).
    if type(self.spaceSeps) == "table" then
        for _, sep in ipairs(self.spaceSeps) do
            if type(sep) == "string" and sep ~= "" then
                out = out:gsub(self:PatternEscape(sep), "")
            end
        end
    end
    return out, out ~= msg
end

function _G.FontMagicCombatTextFix:VisibleWhitespace(msg)
    if Compat.IsSecretValue(msg) then return "<secret>" end
    if type(msg) ~= "string" then return tostring(msg) end
    local out = msg
    out = out:gsub("\194\160", "[NBSP]")
    out = out:gsub("\226\128\175", "[NNBSP]")
    out = out:gsub("\226\128\137", "[THIN]")
    out = out:gsub("\226\128\135", "[FIG]")
    out = out:gsub(" ", "[SP]")
    out = out:gsub(",", "[,]")
    out = out:gsub("%.", "[.]")
    out = out:gsub("'", "[']")
    return out
end

function _G.FontMagicCombatTextFix:DescribeSeparatorBytes(msg)
    if Compat.IsSecretValue(msg) then return "" end
    if type(msg) ~= "string" or msg == "" then return "" end
    local parts = {}
    local function add(label, bytes, needle)
        if msg:find(needle, 1, true) then
            parts[#parts + 1] = label .. "=" .. bytes
        end
    end
    add("SP", "20", " ")
    add("NBSP", "C2 A0", "\194\160")
    add("NNBSP", "E2 80 AF", "\226\128\175")
    add("THIN", "E2 80 89", "\226\128\137")
    add("FIG", "E2 80 87", "\226\128\135")
    add("COMMA", "2C", ",")
    add("DOT", "2E", ".")
    add("APOS", "27", "'")
    return table.concat(parts, ", ")
end

function _G.FontMagicCombatTextFix:MaybeLogMessage(source, rawMsg, sanitizedMsg, changed)
    if Compat.IsSecretValue(rawMsg) or Compat.IsSecretValue(sanitizedMsg) then return end
    if not self:IsDebugEnabled() then return end

    local w = self.wrap
    if type(w) ~= "table" then return end
    w.logCount = (w.logCount or 0) + 1
    local limit = tonumber(w.logLimit) or 150
    if w.logCount > limit then
        if w.logCount == (limit + 1) then
            self:DbgLine("debug: combat-text log limit reached (" .. limit .. "); toggle '/fontmagic debug off' then on to reset.")
        end
        return
    end

    local raw = tostring(rawMsg or "")
    self:DbgLine("CT[" .. tostring(source or "?") .. "] raw=" .. raw)

    local vis = self:VisibleWhitespace(rawMsg)
    local seps = self:DescribeSeparatorBytes(rawMsg)
    if vis ~= raw or seps ~= "" then
        self:DbgLine("CT vis=" .. tostring(vis) .. (seps ~= "" and (" seps=" .. seps) or ""))
    end

    if changed and sanitizedMsg ~= rawMsg then
        self:DbgLine("CT sanitized=" .. tostring(sanitizedMsg))
    end
end

function _G.FontMagicCombatTextFix:DumpFontInstance(name, obj)
    if not Compat.CanInspectObject(obj) then
        self:DbgLine(tostring(name or "?") .. ": unavailable or restricted")
        return
    end

    local otype = nil
    if type(obj.GetObjectType) == "function" then
        local ok, v = pcall(obj.GetObjectType, obj)
        if ok and not Compat.IsSecretValue(v) then otype = v end
    end

    local _, path, size, flags = Compat.GetFontTuple(obj)
    local spacing = CombatFont:GetSpacingValue(obj)

    self:DbgLine(string.format(
        "%s: type=%s font=%s size=%s flags=%s spacing=%s",
        tostring(name or "?"),
        tostring(otype),
        tostring(path),
        tostring(size),
        tostring(flags),
        tostring(spacing)
    ))
end

function _G.FontMagicCombatTextFix:DumpCombatTextRegions(frameName, maxFS)
    local f = _G and _G[frameName]
    if not Compat.CanInspectObject(f) or type(f.GetRegions) ~= "function" then
        self:DbgLine("CT regions: " .. tostring(frameName) .. " (no GetRegions)")
        return
    end

    local okRegions, regions = pcall(function() return { f:GetRegions() } end)
    if not okRegions or type(regions) ~= "table" then
        self:DbgLine("CT regions: " .. tostring(frameName) .. " (GetRegions failed)")
        return
    end
    local found = 0
    local limit = tonumber(maxFS) or 6
    for _, r in ipairs(regions) do
        if Compat.CanInspectObject(r) and type(r.GetObjectType) == "function" then
            local ok, typ = pcall(r.GetObjectType, r)
            if ok and not Compat.IsSecretValue(typ) and typ == "FontString" then
                found = found + 1
                self:DumpFontInstance(frameName .. ":FontString" .. found, r)
                if found >= limit then break end
            end
        end
    end
    if found == 0 then
        self:DbgLine("CT regions: " .. tostring(frameName) .. " (no FontString regions found)")
    end
end

function _G.FontMagicCombatTextFix:ZeroFontStringSpacingOnFrame(frameName)
    if type(self.HasManagedCombatTextFont) ~= "function" or not self:HasManagedCombatTextFont() then
        return false
    end
    -- Legacy method name retained for compatibility with already-installed
    -- hooks. Reconciliation preserves native source sizes and shadows, while
    -- the ownership engine sets only managed self-combat letter spacing to 0.
    return CombatFont:ApplySaved()
end

function _G.FontMagicCombatTextFix:MaybeFixCombatTextFontStringSpacing(throttleSeconds)
    if type(self.HasManagedCombatTextFont) ~= "function" or not self:HasManagedCombatTextFont() then
        return
    end

    local w = self.wrap
    if type(w) ~= "table" then return end

    local now = (type(GetTime) == "function") and GetTime() or 0
    local throttle = tonumber(throttleSeconds) or 0
    local last = tonumber(w.lastSpacingScan) or 0
    if throttle > 0 and now > 0 and (now - last) < throttle then
        return
    end
    w.lastSpacingScan = now

    self:ZeroFontStringSpacingOnFrame()
end

function _G.FontMagicCombatTextFix:MaybeLogDisplayedCombatText(frameName, source)
    if not self:IsDebugEnabled() then return end

    local w = self.wrap
    if type(w) ~= "table" then return end

    local now = (type(GetTime) == "function") and GetTime() or 0
    local last = tonumber(w.lastDisplayedScan) or 0
    if now > 0 and (now - last) < 0.05 then
        return
    end
    w.lastDisplayedScan = now

    local root = _G and _G[frameName]
    if not root then return end

    w.lastFSText = w.lastFSText or {}
    local maxDepth = 4
    local maxFS = 12
    local seen = {}
    local count = 0

    local function visit(f, depth)
        if depth > maxDepth or not Compat.CanInspectObject(f) then return end
        if seen[f] then return end
        seen[f] = true

        if type(f.GetRegions) == "function" then
            local okRegions, regions = pcall(function() return { f:GetRegions() } end)
            if okRegions and type(regions) == "table" then
                for _, r in ipairs(regions) do
                    if Compat.CanInspectObject(r) and type(r.GetObjectType) == "function" then
                        local ok, typ = pcall(r.GetObjectType, r)
                        if ok and not Compat.IsSecretValue(typ) and typ == "FontString" then
                            count = count + 1
                            if count > maxFS then return end

                            local txt = nil
                            if type(r.GetText) == "function" then
                                local okT, v = pcall(r.GetText, r)
                                if okT and not Compat.IsSecretValue(v) then txt = v end
                            end
                            if type(txt) == "string" and txt ~= "" and txt:match("%d") then
                                local lastTxt = w.lastFSText[r]
                                if lastTxt ~= txt then
                                    w.lastFSText[r] = txt

                                    local _, p, s, fl = Compat.GetFontTuple(r)
                                    local sp = CombatFont:GetSpacingValue(r)
                                    local sc = nil
                                    if type(r.GetScale) == "function" then
                                        local okSc, v = pcall(r.GetScale, r)
                                        if okSc and not Compat.IsSecretValue(v) then sc = v end
                                    end

                                    self:DbgLine("CT displayed[" .. tostring(source or "?") .. "] " .. tostring(frameName) .. " FS" .. tostring(count) .. " text=" .. tostring(txt))
                                    self:DbgLine("CT displayed vis=" .. self:VisibleWhitespace(txt) .. " seps=" .. self:DescribeSeparatorBytes(txt))
                                    self:DbgLine("CT displayed font=" .. tostring(p) .. " size=" .. tostring(s) .. " flags=" .. tostring(fl) .. " spacing=" .. tostring(sp) .. " scale=" .. tostring(sc))
                                end
                            end
                        end
                    end
                end
            end
        end

        if type(f.GetChildren) == "function" then
            local okChildren, children = pcall(function() return { f:GetChildren() } end)
            if okChildren and type(children) == "table" then
                for _, child in ipairs(children) do
                    visit(child, depth + 1)
                    if count > maxFS then return end
                end
            end
        end
    end

    visit(root, 0)
end

function _G.FontMagicCombatTextFix:OnCombatTextMessage(source, message, ...)
    self:MaybeRepairSelectedCombatTextFont(0.15)
    if FontMagicDB and FontMagicDB.combatTextAboveNameplates and type(self.ApplyCombatTextAboveNameplatesNow) == "function" then
        pcall(self.ApplyCombatTextAboveNameplatesNow, self)
    end

    if not self:IsDebugEnabled() then return end

    if Compat.IsSecretValue(message) then return end

    local t = type(message)
    if t == "string" and message ~= "" and message:match("%d") then
        local sanitized, changed = self:SanitizeMessage(message)
        if sanitized == nil then sanitized = message end
        self:MaybeLogMessage(source, message, sanitized, changed)
    else
        -- Still log that something happened (helps diagnose missing output).
        self:DbgLine("CT[" .. tostring(source or "?") .. "] argType=" .. tostring(t) .. " arg=" .. tostring(message))
    end

    -- Post-scan the live FontStrings to capture the *actual* displayed text/state.
    self:MaybeLogDisplayedCombatText("CombatText", source)
end

function _G.FontMagicCombatTextFix:SendTestCombatText()
    local msg = "FontMagic TEST +1,234,567"
    local targets = { "CombatText", "CombatTextFrame", "FloatingCombatTextFrame" }

    local function tryCall(label, fn, ...)
        if type(fn) ~= "function" then return false end
        local ok, err = pcall(fn, ...)
        if ok then
            self:DbgLine("debug test: " .. tostring(label) .. " ok")
            return true
        end
        self:DbgLine("debug test: " .. tostring(label) .. " failed: " .. tostring(err))
        return false
    end

    for _, frameName in ipairs(targets) do
        local f = _G and _G[frameName]
        if f and type(f.AddMessage) == "function" then
            local scrollFunction = f.scrollFunction or (_G and _G.COMBAT_TEXT_SCROLL_FUNCTION)
            if type(scrollFunction) ~= "function" and type(_G.CombatTextUtil) == "table" then
                scrollFunction = _G.CombatTextUtil.StandardScroll
            end
            if type(scrollFunction) ~= "function" then
                -- Safe diagnostic fallback for branches that do not expose their
                -- configured scroll function until the first combat-text event.
                scrollFunction = function(_, value)
                    value = value or _
                    return tonumber(value and value.startX) or 0, tonumber(value and value.startY) or 0
                end
            end

            if tryCall(frameName .. ":AddMessage", f.AddMessage, f, msg, scrollFunction, 0, 1, 0, nil, false) then
                return true
            end
        end
    end

    self:DbgLine("debug test: no CombatText* frame accepted AddMessage()")
    return false
end

function _G.FontMagicCombatTextFix:PrintDebugSnapshot()
    self:DbgLine("debug snapshot begin")

    local loc = (type(GetLocale) == "function") and GetLocale() or nil
    self:DbgLine("locale=" .. tostring(loc))

    if type(FontMagicDB) == "table" then
        self:DbgLine("FontMagicDB.selectedFont=" .. tostring(FontMagicDB.selectedFont))
        local masterOff = (FontMagicDB.combatMasterOffByFontMagic
            and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot)) and true or false
        self:DbgLine("FontMagicDB.combatMasterOffByFontMagic=" .. tostring(masterOff))
    end
    self:DbgLine("globals: COMBAT_TEXT_FONT=" .. tostring(_G and _G.COMBAT_TEXT_FONT) .. " DAMAGE_TEXT_FONT=" .. tostring(_G and _G.DAMAGE_TEXT_FONT))

    local breakUp = CVars.Exists("breakUpLargeNumbers") and CVars.GetString("breakUpLargeNumbers") or nil
    local localeFmt = CVars.Exists("useLocaleNumberFormat") and CVars.GetString("useLocaleNumberFormat") or nil
    self:DbgLine("CVar breakUpLargeNumbers=" .. tostring(breakUp))
    self:DbgLine("CVar useLocaleNumberFormat=" .. tostring(localeFmt))

    self:DbgLine("LARGE_NUMBER_SEPERATOR=" .. tostring(_G and _G.LARGE_NUMBER_SEPERATOR))
    self:DbgLine("LARGE_NUMBER_SEPARATOR=" .. tostring(_G and _G.LARGE_NUMBER_SEPARATOR))

    if type(BreakUpLargeNumbers) == "function" then
        local ok, ex = pcall(BreakUpLargeNumbers, 1234567)
        if ok then
            self:DbgLine("BreakUpLargeNumbers(1234567)=" .. tostring(ex) .. " vis=" .. self:VisibleWhitespace(ex) .. " seps=" .. self:DescribeSeparatorBytes(ex))
        else
            self:DbgLine("BreakUpLargeNumbers(1234567)=<error> " .. tostring(ex))
        end
    else
        self:DbgLine("BreakUpLargeNumbers=<missing>")
    end

    self:DumpFontInstance("CombatTextFont", _G and _G.CombatTextFont)
    self:DumpFontInstance("CombatTextFontOutline", _G and _G.CombatTextFontOutline)
    self:DumpFontInstance("DamageFont", _G and _G.DamageFont)
    self:DumpFontInstance("DamageFontOutline", _G and _G.DamageFontOutline)
    self:DumpFontInstance("DamageNumberFont", _G and _G.DamageNumberFont)
    self:DumpFontInstance("CombatDamageFont", _G and _G.CombatDamageFont)
    self:DumpFontInstance("WorldFont", _G and _G.WorldFont)
    self:DumpFontInstance("SystemFont_World", _G and _G.SystemFont_World)
    self:DumpFontInstance("SystemFont_World_ThickOutline", _G and _G.SystemFont_World_ThickOutline)
    self:DumpFontInstance("CombatText", _G and _G.CombatText)
    self:DumpFontInstance("CombatTextFrame", _G and _G.CombatTextFrame)
    self:DumpFontInstance("FloatingCombatTextFrame", _G and _G.FloatingCombatTextFrame)

    local w = self.wrap
    self:DbgLine("hooks: CombatText_AddMessage=" .. tostring(w and w.wrapped and w.wrapped["CombatText_AddMessage"])
        .. " CombatText.AddMessage=" .. tostring(w and w.wrapped and w.wrapped["CombatText.AddMessage"])
        .. " CombatTextFrame.AddMessage=" .. tostring(w and w.wrapped and w.wrapped["CombatTextFrame.AddMessage"])
        .. " FloatingCombatTextFrame.AddMessage=" .. tostring(w and w.wrapped and w.wrapped["FloatingCombatTextFrame.AddMessage"]))

    -- Key combat-text CVars (helps explain when messages don't show).
    local function cvarLine(name)
        if CVars.Exists(name) then
            self:DbgLine("CVar " .. tostring(name) .. "=" .. tostring(CVars.GetString(name)))
        end
    end
    local function cvarGroup(base)
        if type(base) ~= "string" or base == "" then return end
        cvarLine(base)
        cvarLine(base .. "_v2")
        cvarLine(base .. "_V2")
        cvarLine(base .. "_v3")
        cvarLine(base .. "_V3")
    end
    cvarLine("enableFloatingCombatText")
    cvarLine("enableCombatText")
    cvarGroup("WorldTextScale")
    cvarGroup("WorldTextGravity")
    cvarGroup("WorldTextRampDuration")
    cvarGroup("floatingCombatTextCombatHealing")
    cvarGroup("floatingCombatTextCombatDamage")
    cvarGroup("floatingCombatTextCombatLogPeriodicSpells")

    if type(FontMagicDB) == "table" and type(FontMagicDB.incomingOverrides) == "table" then
        self:DbgLine("FontMagicDB.incomingOverrides.incomingDamage=" .. tostring(FontMagicDB.incomingOverrides.incomingDamage))
        self:DbgLine("FontMagicDB.incomingOverrides.incomingHealing=" .. tostring(FontMagicDB.incomingOverrides.incomingHealing))
    end
    if type(FontMagicDB) == "table" then
        self:DbgLine("FontMagicDB.combatTextOutlineMode=" .. tostring(FontMagicDB.combatTextOutlineMode))
    end

    local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
    if type(combatTextTypeInfo) == "table" then
        local function ctInfoLine(k)
            local t = combatTextTypeInfo[k]
            if t == nil then
                self:DbgLine("CT_INFO[" .. tostring(k) .. "]=nil")
                return
            end
            if type(t) == "table" then
                self:DbgLine("CT_INFO[" .. tostring(k) .. "].cvar=" .. tostring(t.cvar))
                return
            end
            self:DbgLine("CT_INFO[" .. tostring(k) .. "] type=" .. type(t))
        end
        ctInfoLine("HEAL")
        ctInfoLine("HEAL_CRIT")
        ctInfoLine("PERIODIC_HEAL")
        ctInfoLine("PERIODIC_HEAL_CRIT")
        self:DbgLine("CT incoming healing present=" .. tostring((combatTextTypeInfo.HEAL ~= nil or combatTextTypeInfo.PERIODIC_HEAL ~= nil) and true or false))
    else
        self:DbgLine("CombatTextTypeInfo=nil")
    end

    self:DumpCombatTextRegions("CombatText", 6)
    self:DumpCombatTextRegions("CombatTextFrame", 6)
    self:DumpCombatTextRegions("FloatingCombatTextFrame", 6)

    self:DbgLine("debug snapshot end")
end

function _G.FontMagicCombatTextFix:WrapGlobalCombatTextFunction(fnName)
    local w = self.wrap
    if not (w and w.wrapped) then return end
    if w.wrapped[fnName] then return end

    local selfRef = self
    if type(hooksecurefunc) ~= "function" then return end
    if not (_G and type(_G[fnName]) == "function") then return end

    local ok = pcall(hooksecurefunc, fnName, function(message, ...)
        pcall(selfRef.OnCombatTextMessage, selfRef, fnName, message, ...)
    end)
    if ok then
        w.wrapped[fnName] = true
    end
end

function _G.FontMagicCombatTextFix:WrapCombatTextFrameMethod(frameName, methodName)
    local w = self.wrap
    if not (w and w.wrapped) then return end

    local key = tostring(frameName) .. "." .. tostring(methodName)
    if w.wrapped[key] then return end

    local f = _G and _G[frameName]
    if not (f and type(f[methodName]) == "function") then return end

    local selfRef = self
    if type(hooksecurefunc) ~= "function" then return end

    local ok = pcall(hooksecurefunc, f, methodName, function(_, message, ...)
        pcall(selfRef.OnCombatTextMessage, selfRef, key, message, ...)
    end)
    if ok then
        w.wrapped[key] = true
    end
end

function _G.FontMagicCombatTextFix:EnsureCombatTextPatches()
    local managed = type(self.HasManagedCombatTextFont) == "function" and self:HasManagedCombatTextFont()
    local debugEnabled = type(self.IsDebugEnabled) == "function" and self:IsDebugEnabled()
    local layeringEnabled = type(FontMagicDB) == "table" and FontMagicDB.combatTextAboveNameplates
    if not managed and not debugEnabled and not layeringEnabled then return end

    self:WrapGlobalCombatTextFunction("CombatText_AddMessage")
    self:WrapCombatTextFrameMethod("CombatText", "AddMessage")
    self:WrapCombatTextFrameMethod("CombatTextFrame", "AddMessage")
    self:WrapCombatTextFrameMethod("FloatingCombatTextFrame", "AddMessage")

    if managed then
        self:MaybeFixCombatTextFontStringSpacing(0)
    end

    self.wrap = self.wrap or {}
    if self.wrap.patchTimersScheduled then return end
    if not managed and not debugEnabled and not layeringEnabled then return end

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        self.wrap.patchTimersScheduled = true
        local selfRef = self
        C_Timer.After(0, function()
            if selfRef:HasManagedCombatTextFont() then
                pcall(selfRef.MaybeFixCombatTextFontStringSpacing, selfRef, 0)
            end
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatText", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatTextFrame", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "FloatingCombatTextFrame", "AddMessage")
            pcall(selfRef.WrapGlobalCombatTextFunction, selfRef, "CombatText_AddMessage")
        end)
        C_Timer.After(0.2, function()
            if selfRef:HasManagedCombatTextFont() then
                pcall(selfRef.MaybeFixCombatTextFontStringSpacing, selfRef, 0)
            end
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatText", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatTextFrame", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "FloatingCombatTextFrame", "AddMessage")
            pcall(selfRef.WrapGlobalCombatTextFunction, selfRef, "CombatText_AddMessage")
        end)
        C_Timer.After(1.0, function()
            if selfRef:HasManagedCombatTextFont() then
                pcall(selfRef.MaybeFixCombatTextFontStringSpacing, selfRef, 0)
            end
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatText", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "CombatTextFrame", "AddMessage")
            pcall(selfRef.WrapCombatTextFrameMethod, selfRef, "FloatingCombatTextFrame", "AddMessage")
            pcall(selfRef.WrapGlobalCombatTextFunction, selfRef, "CombatText_AddMessage")
            if selfRef.wrap then selfRef.wrap.patchTimersScheduled = nil end
        end)
    end
end

local function ApplyFloatingTextMotionSettings(only)
    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local gravityTargets = CVars.ResolveTargets({ "WorldTextGravity_v2", "WorldTextGravity_V2", "WorldTextGravity", "floatingCombatTextGravity_v2", "floatingCombatTextGravity_V2", "floatingCombatTextGravity" })
    local fadeTargets = CVars.ResolveTargets({ "WorldTextRampDuration_v2", "WorldTextRampDuration_V2", "WorldTextRampDuration", "floatingCombatTextRampDuration_v2", "floatingCombatTextRampDuration_V2", "floatingCombatTextRampDuration" })

    local function applyReadable(targets, value)
        local readable = {}
        for _, target in ipairs(targets) do
            if target.commandType == 0 and CVars.GetCurrent(target.name) ~= nil then
                readable[#readable + 1] = target
            end
        end
        if #readable == 0 then return true end
        local applyAtomic = CVars.ApplyAtomicWithRecovery or CVars.ApplyAtomic
        return applyAtomic(readable, value) and true or false
    end

    local succeeded = true
    if (not only or only == "gravity") and #gravityTargets > 0 and FontMagicDB and FontMagicDB.floatingTextGravityTouched
        and type(FontMagicDB.floatingTextGravity) == "number" then
        local g = clamp(FontMagicDB.floatingTextGravity, 0.00, 2.00)
        FontMagicDB.floatingTextGravity = g
        local formatted = string.format("%.2f", g)
        succeeded = applyReadable(gravityTargets, formatted) and succeeded
    end
    if (not only or only == "fade") and #fadeTargets > 0 and FontMagicDB and FontMagicDB.floatingTextFadeDurationTouched
        and type(FontMagicDB.floatingTextFadeDuration) == "number" then
        local f = clamp(FontMagicDB.floatingTextFadeDuration, 0.10, 3.00)
        FontMagicDB.floatingTextFadeDuration = f
        local formatted = string.format("%.2f", f)
        succeeded = applyReadable(fadeTargets, formatted) and succeeded
    end
    return succeeded
end


function _G.FontMagicCombatTextFix:HasManagedCombatTextFont()
    if type(FontMagicDB) ~= "table" then return false end
    if type(FontMagicDB.selectedFont) == "string" and FontMagicDB.selectedFont ~= "" then
        return true
    end
    return FontMagicDB.combatTextOutlineTouched and true or false
end

function _G.FontMagicCombatTextFix:ApplySavedCombatFontNow()
    if not self:HasManagedCombatTextFont() then return true end
    Fonts.MigrateSavedKeys()
    local applied, committed = CombatFont:ApplySaved()
    if committed == nil then committed = applied end
    if not committed then return false end
    if type(self.EnsureCombatTextPatches) == "function" then
        pcall(self.EnsureCombatTextPatches, self)
    end
    if type(self.StartCombatTextOwnershipMonitor) == "function" then
        pcall(self.StartCombatTextOwnershipMonitor, self)
    end
    return true
end

function _G.FontMagicCombatTextFix:QueueSavedCombatFontApply(delay, force)
    if not self:HasManagedCombatTextFont() then return end

    self.externalHooks = self.externalHooks or {}
    self.externalHooks.queuedApply = self.externalHooks.queuedApply or {}

    local d = tonumber(delay) or 0
    if d < 0 then d = 0 end
    local key = string.format("%.3f", d)
    if self.externalHooks.queuedApply[key] then return end
    self.externalHooks.queuedApply[key] = true

    local fix = self
    local function run()
        if fix.externalHooks and fix.externalHooks.queuedApply then
            fix.externalHooks.queuedApply[key] = nil
        end
        if type(fix.InstallExternalCombatFontHooks) == "function" then
            pcall(fix.InstallExternalCombatFontHooks, fix)
        end
        pcall(fix.ApplySavedCombatFontNow, fix)
    end

    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(d, run)
    else
        run()
    end
end

function _G.FontMagicCombatTextFix:CaptureExternalCombatFontState()
    if not self:HasManagedCombatTextFont()
        or (_G and _G.FontMagicCombatTextApplying) then
        return false
    end

    local changed = false
    if type(CombatFont.ObserveExternalGlobals) == "function" then
        local ok, observed = pcall(CombatFont.ObserveExternalGlobals, CombatFont)
        changed = ok and observed and true or changed
    end
    if type(CombatFont.ObserveExternalManagedObjects) == "function" then
        local ok, observed = pcall(CombatFont.ObserveExternalManagedObjects, CombatFont)
        changed = ok and observed and true or changed
    end
    return changed
end

function _G.FontMagicCombatTextFix:GuardExternalCombatFontGlobalsNow()
    if not self:HasManagedCombatTextFont()
        or (_G and _G.FontMagicCombatTextApplying)
        or type(CombatFont.ObserveExternalGlobals) ~= "function" then
        return false
    end

    local ok, changed = pcall(CombatFont.ObserveExternalGlobals, CombatFont)
    if not (ok and changed) then return false end

    if type(CombatFont.GlobalLock) == "table"
        and type(CombatFont.GlobalLock.Reassert) == "function" then
        pcall(CombatFont.GlobalLock.Reassert, CombatFont.GlobalLock)
    end
    return true
end

function _G.FontMagicCombatTextFix:ReconcileExternalCombatFontWrite()
    if not self:HasManagedCombatTextFont()
        or (_G and _G.FontMagicCombatTextApplying) then
        return true
    end

    self:CaptureExternalCombatFontState()
    local applied = self:ApplySavedCombatFontNow()

    -- Keep one end-of-frame pass as a backstop for another secure post-hook
    -- that may run after ours. The synchronous pass is the important one for
    -- DAMAGE_TEXT_FONT: clients cache that global during the login transition.
    self:QueueSavedCombatFontApply(0)
    return applied
end

function _G.FontMagicCombatTextFix:QueueExternalCombatFontGuard(delay)
    if not self:HasManagedCombatTextFont() then return end

    self.externalHooks = self.externalHooks or {}
    if self.externalHooks.globalGuardQueued then return end
    self.externalHooks.globalGuardQueued = true

    local fix = self
    local function run()
        if fix.externalHooks then fix.externalHooks.globalGuardQueued = nil end
        if type(fix.InstallExternalCombatFontHooks) == "function" then
            pcall(fix.InstallExternalCombatFontHooks, fix)
        end

        local observed = fix:CaptureExternalCombatFontState()
        if observed then
            pcall(fix.ApplySavedCombatFontNow, fix)
        elseif type(fix.MaybeRepairSelectedCombatTextFont) == "function" then
            -- This catches a newly-created live FontObject without doing an
            -- unconditional full traversal after every unrelated addon load.
            pcall(fix.MaybeRepairSelectedCombatTextFont, fix, 0)
        end
    end

    local d = tonumber(delay) or 0
    if d < 0 then d = 0 end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(d, run)
    else
        local guard = self.externalHooks.globalGuardFrame
        if not guard then
            guard = CreateFrame("Frame")
            guard:Hide()
            guard:SetScript("OnUpdate", function(frameObj)
                frameObj:Hide()
                run()
            end)
            self.externalHooks.globalGuardFrame = guard
        end
        guard:Show()
    end
end

function _G.FontMagicCombatTextFix:QueueSavedCombatFontApplyBurst()
    self:QueueSavedCombatFontApply(0)
    self:QueueSavedCombatFontApply(0.5)
    self:QueueSavedCombatFontApply(2.0)
end

function _G.FontMagicCombatTextFix:StartStartupCombatFontWatcher(seconds)
    if not self:HasManagedCombatTextFont() then return end
    self:QueueSavedCombatFontApplyBurst()
    local finalDelay = tonumber(seconds) or 5
    if finalDelay < 2 then finalDelay = 2 end
    if finalDelay > 5 then finalDelay = 5 end
    self:QueueSavedCombatFontApply(finalDelay)

    -- DAMAGE_TEXT_FONT is cached during login. Watch only the two cheap global
    -- values every rendered frame during that short window, so a controller
    -- using an unusual delayed initializer cannot land between fixed timers.
    self.externalHooks = self.externalHooks or {}
    local guard = self.externalHooks.startupGlobalGuard
    if not guard then
        local fix = self
        guard = CreateFrame("Frame")
        guard.elapsed = 0
        guard:SetScript("OnUpdate", function(frameObj, elapsed)
            frameObj.elapsed = (frameObj.elapsed or 0) + (tonumber(elapsed) or 0)
            if fix:GuardExternalCombatFontGlobalsNow() then
                fix:QueueSavedCombatFontApply(0)
            end
            if frameObj.elapsed >= (frameObj.duration or 5) then
                frameObj:Hide()
            end
        end)
        self.externalHooks.startupGlobalGuard = guard
    end
    guard.elapsed = 0
    guard.duration = finalDelay
    guard:Show()
end

function _G.FontMagicCombatTextFix:StartCombatTextOwnershipMonitor()
    if not self:HasManagedCombatTextFont() then return end

    self.externalHooks = self.externalHooks or {}
    if self.externalHooks.ownershipMonitor then
        local active = self.externalHooks.ownershipMonitor
        active.elapsed = 0
        if active.Show then active:Show() end
        return
    end

    local monitor = CreateFrame("Frame")
    monitor.elapsed = 0
    monitor.fix = self
    monitor:SetScript("OnUpdate", function(frameObj, elapsed)
        frameObj.elapsed = (frameObj.elapsed or 0) + (tonumber(elapsed) or 0)
        if frameObj.elapsed < 0.75 then return end
        frameObj.elapsed = 0

        local fix = frameObj.fix
        if not (fix and type(fix.HasManagedCombatTextFont) == "function" and fix:HasManagedCombatTextFont()) then
            frameObj:Hide()
            return
        end

        if type(fix.MaybeRepairSelectedCombatTextFont) == "function" then
            pcall(fix.MaybeRepairSelectedCombatTextFont, fix, 0.75)
        end
    end)

    self.externalHooks.ownershipMonitor = monitor
end

function _G.FontMagicCombatTextFix:InstallManagedCombatFontObjectHooks()
    if type(hooksecurefunc) ~= "function" then return end

    self.externalHooks = self.externalHooks or {}
    self.externalHooks.fontObjects = self.externalHooks.fontObjects or {}

    for _, def in ipairs(_G.FontMagicCombatTextFontObjects or {}) do
        local name = def and def.name
        local obj = name and _G and _G[name]
        if name and obj and type(obj.SetFont) == "function" and not self.externalHooks.fontObjects[name] then
            local fix = self
            local ok = pcall(hooksecurefunc, obj, "SetFont", function()
                if _G and _G.FontMagicCombatTextApplying then return end
                if type(CombatFont.ObserveExternalObject) == "function" then
                    pcall(CombatFont.ObserveExternalObject, CombatFont, obj)
                end
                if type(fix.QueueSavedCombatFontApply) == "function" then
                    pcall(fix.QueueSavedCombatFontApply, fix, 0)
                end
            end)
            if ok then
                self.externalHooks.fontObjects[name] = true
            end
        end
    end
end

function _G.FontMagicCombatTextFix:InstallExternalCombatFontHooks()
    self.externalHooks = self.externalHooks or {}
    self:InstallManagedCombatFontObjectHooks()

    if type(hooksecurefunc) ~= "function" then return end

    local fix = self
    local function hookWriter(owner, methodName, key)
        if self.externalHooks[key] or not (owner and type(owner[methodName]) == "function") then return end
        local ok = pcall(hooksecurefunc, owner, methodName, function()
            if _G and _G.FontMagicCombatTextApplying then return end
            fix:ReconcileExternalCombatFontWrite()
        end)
        if ok then self.externalHooks[key] = true end
    end

    if not self.externalHooks.elvuiUpdateBlizzardSpecialFonts
        or not self.externalHooks.elvuiUpdateBlizzardFonts then
        local engine = _G and _G.ElvUI
        local E
        if type(engine) == "table" then
            local unpackFn = _G.unpack or (table and table.unpack)
            if type(unpackFn) == "function" then
                local ok, e = pcall(unpackFn, engine)
                if ok and type(e) == "table" then E = e end
            end
            if not E and type(engine[1]) == "table" then
                E = engine[1]
            end
        end
        if E then
            -- ElvUI 15.x writes DAMAGE_TEXT_FONT and CombatTextFont here.
            -- UpdateBlizzardFonts is retained for older ElvUI branches where
            -- the special-font work lived in the general writer.
            hookWriter(E, "UpdateBlizzardSpecialFonts", "elvuiUpdateBlizzardSpecialFonts")
            hookWriter(E, "UpdateBlizzardFonts", "elvuiUpdateBlizzardFonts")
        end
    end

    if not self.externalHooks.suiGeneralFonts then
        local SUI = _G and _G.SUI
        if type(SUI) == "table" and type(SUI.GetModule) == "function" then
            local okMod, mod = pcall(SUI.GetModule, SUI, "General.Fonts", true)
            if okMod and mod and type(mod.OnInitialize) == "function" then
                hookWriter(mod, "OnInitialize", "suiGeneralFonts")
            end
        end
    end

    if not self.externalHooks.libSharedMediaRegister then
        local libstub = _G and _G.LibStub
        if type(libstub) == "table" or type(libstub) == "function" then
            local okLSM, lsm
            if type(libstub) == "table" and type(libstub.GetLibrary) == "function" then
                okLSM, lsm = pcall(libstub.GetLibrary, libstub, "LibSharedMedia-3.0", true)
            else
                okLSM, lsm = pcall(libstub, "LibSharedMedia-3.0", true)
            end
            if okLSM and lsm and type(lsm.Register) == "function" then
                local fix = self
                local okHook = pcall(hooksecurefunc, lsm, "Register", function(_, mediaType)
                    if tostring(mediaType or ""):lower() == "font" then
                        fix:QueueSavedCombatFontApply(0)
                    end
                end)
                if okHook then
                    self.externalHooks.libSharedMediaRegister = true
                end
            end
        end
    end
end

-- Initial capture + apply as early as possible
CombatFont:CaptureDefaults()
CombatFont:ApplySaved()
if _G and _G.FontMagicCombatTextFix then
    pcall(_G.FontMagicCombatTextFix.InstallExternalCombatFontHooks, _G.FontMagicCombatTextFix)
    pcall(_G.FontMagicCombatTextFix.StartStartupCombatFontWatcher, _G.FontMagicCombatTextFix, 5)
    pcall(_G.FontMagicCombatTextFix.StartCombatTextOwnershipMonitor, _G.FontMagicCombatTextFix)
end


-- 2) MAIN WINDOW
local frame = CreateFrame("Frame", addonName .. "Frame", UIParent, Compat.BackdropTemplate)
--
-- The options window previously lacked a border and used uneven padding
-- around its contents.  Here we keep all the widgets exactly where they
-- were defined and instead only change the outer frame so that it provides
-- an even buffer on every side and a simple border for clarity.
--
-- Constants control the visual spacing and border width so adjustments can
-- be made in a single location.
local PAD       = 20   -- distance from the outer edge to the nearest widget
local BORDER    = 12   -- thickness of the decorative border
local HEADER_H  = 40   -- space reserved for the InterfaceOptions header
local PREVIEW_W = 320  -- width of preview and edit boxes
-- Checkbox column width. Adjusted to ensure the combined width of the two
-- columns plus the spacing between them equals the preview width. The
-- preview box is 320px wide and we want 16px of spacing between the two
-- columns, leaving 304px for the columns themselves. 304/2 = 152.
local CB_COL_W  = 152  -- checkbox column width
local DD_COL_W  = 200  -- width allocated for each dropdown column

-- Dropdown layout (shared by the window and menu builders)
local DD_COLS      = 2    -- number of dropdowns per row
local DD_MARGIN_X  = 12   -- left/right inner margin for dropdown columns
local DD_WIDTH     = 160  -- UIDropDownMenu_SetWidth value
local DD_LIST_X_OFFSET = 13 -- aligns the open border with the selector's visible border
local DD_LIST_Y_OFFSET = 22 -- retains Blizzard's established vertical placement

local function AnchorFontMagicDropDown(dd)
    if not dd then return end

    -- Blizzard's stock anchor starts eight units from the selector texture's
    -- origin.  The selector artwork has five more transparent units before its
    -- visible left border, so x=13 aligns both visible borders exactly.  Keep
    -- the standard y=22 placement and selector-left relative frame.
    if type(UIDropDownMenu_SetAnchor) == "function" then
        UIDropDownMenu_SetAnchor(
            dd,
            DD_LIST_X_OFFSET,
            DD_LIST_Y_OFFSET,
            "TOPLEFT",
            nil,
            "BOTTOMLEFT"
        )
        return
    end

    -- Older clients use these same fields inside ToggleDropDownMenu even when
    -- the SetAnchor convenience global is unavailable.
    dd.xOffset = DD_LIST_X_OFFSET
    dd.yOffset = DD_LIST_Y_OFFSET
    dd.point = "TOPLEFT"
    dd.relativeTo = nil
    dd.relativePoint = "BOTTOMLEFT"
end

-- UI spacing tweaks
-- These values are intentionally centralized so we can keep the layout
-- balanced while ensuring the lowest checkbox row never collides with the
-- bottom action buttons.
local CONTENT_NUDGE_Y = 12  -- shifts the whole lower section up slightly
local CHECK_ROW_H     = 30  -- vertical spacing between checkbox rows
local CHECK_COL_GAP   = 16  -- spacing between left/right checkbox columns

-- The existing widgets already expect roughly 20px from the top-left
-- of the frame, so we simply expand the overall frame to ensure the same
-- distance on the remaining sides as well.
-- Widen the frame slightly so dropdown menus and other widgets have
-- adequate padding on both sides. This prevents the second column of
-- dropdowns from touching or overlapping the right border when the
-- window is scaled.
-- Compute the window width from the dropdown grid so the columns are
-- perfectly padded on both sides when using 3 dropdowns per row.
local INNER_W = DD_WIDTH + (DD_MARGIN_X * 2) + ((DD_COLS - 1) * DD_COL_W)
local COLLAPSED_W = INNER_W + PAD * 2
local LEFT_PANEL_X = math.floor((COLLAPSED_W - PREVIEW_W) / 2 + 0.5)
frame.__fmCollapsedW = COLLAPSED_W
frame:SetSize(COLLAPSED_W, 500 + PAD * 2)
frame:SetPoint("CENTER")
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 32,
    edgeSize = BORDER,
    insets   = { left = PAD - BORDER, right = PAD - BORDER,
                 top  = PAD - BORDER, bottom = PAD - BORDER },
})
-- Darker, more opaque background so text stays readable even over bright scenes.
frame:SetBackdropColor(0, 0, 0, 0.92)
frame:EnableMouse(true)
frame:SetMovable(true)
if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if self.GetParent and self:GetParent() == UIParent and FontMagicDB and self.GetLeft and self.GetTop then
        local l, t = self:GetLeft(), self:GetTop()
        if type(l) == "number" and type(t) == "number" then
            FontMagicDB.windowPos = { left = l, top = t }
        end
    end
end)
frame:Hide()
frame.name = "FontMagic"

-- Anchor frame used to keep the left-side controls (Apply/Reset/Close/Expand) fixed
-- when the window expands to show the optional Combat Options panel.
local leftAnchor = CreateFrame("Frame", nil, frame)
leftAnchor:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
leftAnchor:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
leftAnchor:SetWidth(frame.__fmCollapsedW or frame:GetWidth() or 0)
frame.__fmLeftAnchor = leftAnchor

-- allow ESC key to close the frame
if UISpecialFrames then
    tinsert(UISpecialFrames, frame:GetName())
end

-- 3) COMMON WIDGET HELPERS ---------------------------------------------------
local _cbId = 0

local function GetCheckButtonLabelFS(cb)
    if not cb then return nil end
    -- Modern clients: cb.Text. Older templates: cb.text.
    local fs = cb.Text or cb.text
    if fs and fs.SetText then return fs end

    -- Fallback: scan regions for the first FontString.
    if cb.GetRegions then
        local okRegions, regions = pcall(function() return { cb:GetRegions() } end)
        if okRegions and type(regions) == "table" then
            for _, r in ipairs(regions) do
                if r and r.GetObjectType then
                    local okType, typ = pcall(r.GetObjectType, r)
                    if okType and typ == "FontString" then
                        return r
                    end
                end
            end
        end
    end
    return nil
end

local function SetCheckButtonLabel(cb, label)
    local fs = GetCheckButtonLabelFS(cb)
    if fs then
        fs:SetText(label or "")
        cb.__fmLabelFS = fs
    end
end

local function CreateCheckbox(parent, label, x, y, checked, onClick, anonymous)
    local name = nil
    if not anonymous then
        _cbId = _cbId + 1
        name = addonName .. "CB" .. _cbId
    end
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    SetCheckButtonLabel(cb, label)

    -- Tighten label spacing: keep the text directly to the right of the checkbox on all clients.
    do
        local fs = cb and (cb.__fmLabelFS or GetCheckButtonLabelFS(cb))
        if fs and fs.ClearAllPoints and fs.SetPoint then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
            cb.__fmLabelFS = fs
        end
    end

    cb:SetChecked(checked and true or false)
    if onClick then cb:SetScript("OnClick", onClick) end
    return cb
end


-- 4) FONT DROPDOWNS ---------------------------------------------------------
local dropdowns = {}
local preview
local editBox
local mainShowCombatTextCB
local previewHeaderFS
-- holds a font selection made via the dropdowns but not yet applied
local pendingFont


-- Favorites helpers ---------------------------------------------------------
local function EnsureFavorites()
    if type(FontMagicDB) ~= "table" then FontMagicDB = {} end
    if type(FontMagicDB.favorites) ~= "table" then
        FontMagicDB.favorites = {}
    end
    return FontMagicDB.favorites
end

local function IsFavorite(key)
    local favs = EnsureFavorites()
    return favs[key] == true
end

local function ToggleFavorite(key)
    local favs = EnsureFavorites()
    if favs[key] == true then
        favs[key] = nil
    else
        favs[key] = true
    end
end

-- Select a font key as the current (pending) selection and update the preview.
-- Used when a user clicks the favorite star so the UI still previews what they just favorited.
local SetPreviewFont
local UpdatePreviewHeaderText
-- Incremented on every preview font change. Used to cancel any queued next-frame
-- sizing pass so a stale preview (e.g. from a font you only *previewed*) can't
-- overwrite the currently-applied font after the window is closed/reopened.
local __fmPreviewToken = 0
local function SelectFontKey(key)
    if type(key) ~= "string" or key == "" then return end

    -- Parse "Group/File.ttf" (groups can contain slashes, so match the last slash)
    local grp, fname = key:match("^(.*)/([^/]+)$")
    if not grp or not fname then return end

    local display = Fonts.StripExtension(tostring(fname))

    -- Clear other dropdown labels for clarity.
    if type(UIDropDownMenu_SetText) == "function" then
        for _, d2 in pairs(dropdowns) do
            pcall(UIDropDownMenu_SetText, d2, "Select Font")
        end
    end

    pendingFont = key

    -- Prefer updating the dropdown that is currently open (if it's ours), otherwise the group dropdown.
    local targetDD
    local open = _G and _G.UIDROPDOWNMENU_OPEN_MENU
    if open and open.__fmGroup and dropdowns[open.__fmGroup] == open then
        targetDD = open
    else
        targetDD = dropdowns[grp]
    end

    if targetDD and type(UIDropDownMenu_SetText) == "function" then
        pcall(UIDropDownMenu_SetText, targetDD, display)
    elseif targetDD and targetDD.SetText then
        targetDD:SetText(display)
    end

    -- Update preview font.
    local cache = Fonts.Cached and Fonts.Cached[grp] and Fonts.Cached[grp][fname]
    if cache then
        SetPreviewFont(cache)
        if UpdatePreviewHeaderText then UpdatePreviewHeaderText(display, cache.path, false) end
    else
        local path = Fonts.ResolveKey(key)
        if path then
            SetPreviewFont(GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()), path)
            if UpdatePreviewHeaderText then UpdatePreviewHeaderText(display, path, false) end
        end
    end

    -- Keep the preview text the same; only the font should change.
    if editBox and preview and editBox.GetText and preview.SetText then
        local txt = editBox:GetText() or ""
        preview:SetText("")
        preview:SetText(txt)
    end
end

-- Safely add buttons to UIDropDownMenu across Classic/Retail variants.
local function SafeAddDropDownButton(info, level)
    if type(UIDropDownMenu_AddButton) ~= "function" then return end

    if type(info) == "table" then
        -- The visible selector artwork spans DD_WIDTH + 25; the logical frame
        -- is another 25 units wider because its end textures contain transparent
        -- padding.  Since an open list is maxWidth + 25, its row width must be
        -- exactly DD_WIDTH for the visible borders to match.
        if info.minWidth == nil then
            info.minWidth = DD_WIDTH
        end

        -- FontMagic reserves ten more units than Blizzard's stock text layout
        -- for the favorite-star column.  Account for that during both the
        -- initial AddButton measurement and Blizzard's deferred remeasurement
        -- so the list cannot shrink underneath its already-sized rows.
        if info.padding == nil then
            info.padding = 10
        end
    end

    local ok = pcall(UIDropDownMenu_AddButton, info, level)
    if not ok then
        pcall(UIDropDownMenu_AddButton, info)
    end
end

-- Attach a small clickable star to a dropdown list entry button.
local FM_FAV_TEX_ON  = "Interface\\AddOns\\FontMagic\\Media\\FM_FavStar_Filled.tga"
local FM_FAV_TEX_OFF = "Interface\\AddOns\\FontMagic\\Media\\FM_FavStar_Outline.tga"

local UpdateFavoriteStar

-- UIDropDownMenu list buttons are global/reused across addons.
-- Track only rows FontMagic decorates so we can clean them when our dropdown closes.
frame.__fmMenuCtx = frame.__fmMenuCtx or {}
if type(frame.__fmMenuCtx.touchedButtons) ~= "table" then
    frame.__fmMenuCtx.touchedButtons = setmetatable({}, { __mode = "k" })
end

-- Blizzard sizes an open list from its longest row, which can make it wider
-- than the selector even when every row has the correct minimum width.  Lock
-- FontMagic's shared list and rows to the visible selector artwork width after
-- population.  Do not use ownerDropdown:GetWidth(): it includes 25 units of
-- transparent end padding.  The next-frame Blizzard refresh remains stable
-- because SafeAddDropDownButton accounts for the favorite-star reservation.
function frame.__fmMenuCtx.FinalizeDropDownListWidth(level)
    local listLevel = tonumber(level) or 1
    local list = _G and _G["DropDownList" .. tostring(listLevel)]
    if not list then return end

    local rowWidth = DD_WIDTH
    local outerWidth = rowWidth + 25
    list.maxWidth = rowWidth
    if type(list.SetWidth) == "function" then
        list:SetWidth(outerWidth)
    end

    local count = tonumber(list.numButtons) or 0
    for index = 1, count do
        local button = _G and _G["DropDownList" .. tostring(listLevel) .. "Button" .. tostring(index)]
        if button and type(button.SetWidth) == "function" then
            button:SetWidth(rowWidth)
        end
    end
end

function frame.__fmMenuCtx.GetDropdownForMenuButton(menuButton)
    if not (menuButton and menuButton.GetParent) then return nil end
    local list = menuButton:GetParent()
    return list and list.dropdown or nil
end

function frame.__fmMenuCtx.IsFontMagicDropdown(dropdown)
    return (dropdown and dropdown.__fmOwner == true) and true or false
end

function frame.__fmMenuCtx.IsFontMagicMenuButton(menuButton)
    local dropdown = frame.__fmMenuCtx.GetDropdownForMenuButton(menuButton)
    if dropdown then
        return frame.__fmMenuCtx.IsFontMagicDropdown(dropdown)
    end
    local open = _G and _G.UIDROPDOWNMENU_OPEN_MENU
    return frame.__fmMenuCtx.IsFontMagicDropdown(open)
end

function frame.__fmMenuCtx.GetOpenFontMagicDropdown()
    local open = _G and _G.UIDROPDOWNMENU_OPEN_MENU
    if frame.__fmMenuCtx.IsFontMagicDropdown(open) then
        return open
    end
    return nil
end

function frame.__fmMenuCtx.MarkTouchedMenuButton(menuButton)
    if menuButton then
        frame.__fmMenuCtx.touchedButtons[menuButton] = true
    end
end

function frame.__fmMenuCtx.BringDropDownListToFront(level)
    local list = _G and _G["DropDownList" .. tostring(level or 1)]
    if not list then return end

    if list.GetFrameStrata and list.__fmOrigStrata == nil then
        list.__fmOrigStrata = list:GetFrameStrata()
    end
    if list.GetFrameLevel and list.__fmOrigLevel == nil then
        list.__fmOrigLevel = list:GetFrameLevel()
    end

    if list.SetFrameStrata then
        list:SetFrameStrata("TOOLTIP")
    end
    if list.SetFrameLevel and frame and frame.GetFrameLevel then
        local target = (frame:GetFrameLevel() or 0) + 120
        if (list:GetFrameLevel() or 0) < target then
            list:SetFrameLevel(target)
        end
    end
    if list.Raise then
        list:Raise()
    end
end

function frame.__fmMenuCtx.BringHoverPreviewToFront(previewFrame)
    if not previewFrame then return end

    local topLevel = 0
    for i = 1, 2 do
        local list = _G and _G["DropDownList" .. tostring(i)]
        if list and list.IsShown and list:IsShown() and list.GetFrameLevel then
            local lvl = list:GetFrameLevel() or 0
            if lvl > topLevel then
                topLevel = lvl
            end
        end
    end
    if topLevel <= 0 and frame and frame.GetFrameLevel then
        topLevel = frame:GetFrameLevel() or 0
    end

    if previewFrame.SetFrameStrata then
        previewFrame:SetFrameStrata("TOOLTIP")
    end
    if previewFrame.SetFrameLevel then
        previewFrame:SetFrameLevel(topLevel + 80)
    end
    if previewFrame.SetToplevel then
        previewFrame:SetToplevel(true)
    end
    if previewFrame.Raise then
        previewFrame:Raise()
    end
end

function frame.__fmMenuCtx.RestoreDropDownListZOrder(level)
    local list = _G and _G["DropDownList" .. tostring(level or 1)]
    if not list then return end

    if list.__fmOrigStrata ~= nil and list.SetFrameStrata then
        pcall(list.SetFrameStrata, list, list.__fmOrigStrata)
    end
    if list.__fmOrigLevel ~= nil and list.SetFrameLevel then
        pcall(list.SetFrameLevel, list, list.__fmOrigLevel)
    end

    list.__fmOrigStrata = nil
    list.__fmOrigLevel = nil
end

-- MouseIsOver was a FrameXML global on older clients, but Retail 12.1 moved
-- this behavior to InputUtil/ScriptRegion:IsMouseOver and no longer defines
-- the global.  Prefer the widget method and retain the legacy fallback so the
-- same addon code continues to work on Classic and older Retail clients.
function frame.__fmMenuCtx.IsRegionMouseOver(region)
    if not region then return false end

    if type(region.IsMouseOver) == "function" then
        local ok, isOver = pcall(region.IsMouseOver, region)
        if ok then return isOver and true or false end
    end

    if type(MouseIsOver) == "function" then
        local ok, isOver = pcall(MouseIsOver, region)
        if ok then return isOver and true or false end
    end

    return false
end

function frame.__fmMenuCtx.TouchMenuActivity()
    local now = (type(GetTime) == "function") and GetTime() or 0
    frame.__fmMenuCtx.lastActivityTime = now

    -- Retail opens UIDropDownMenuTemplate from the arrow's OnMouseDown handler,
    -- while Classic variants commonly open it from OnClick.  Remember the
    -- button state that already exists when the menu opens so the watcher does
    -- not mistake that same opening press for a new click outside the menu.
    local mouseDown = false
    if type(IsMouseButtonDown) == "function" then
        mouseDown = (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and true or false
    end
    frame.__fmMenuCtx.lastMouseDown = mouseDown

    if frame.__fmMenuCtx.idleWatcher and frame.__fmMenuCtx.idleWatcher.Show then
        frame.__fmMenuCtx.idleWatcher:Show()
    end
end

function frame.__fmMenuCtx.StopIdleWatcher()
    frame.__fmMenuCtx.lastActivityTime = nil
    frame.__fmMenuCtx.lastMouseDown = nil
    if frame.__fmMenuCtx.idleWatcher and frame.__fmMenuCtx.idleWatcher.Hide then
        frame.__fmMenuCtx.idleWatcher:Hide()
    end
end

function frame.__fmMenuCtx.EnsureIdleWatcher()
    if frame.__fmMenuCtx.idleWatcher then return end

    local watcher = CreateFrame("Frame")
    watcher:Hide()
    watcher:SetScript("OnUpdate", function(self)
        local open = frame.__fmMenuCtx.GetOpenFontMagicDropdown()
        if not open then
            frame.__fmMenuCtx.StopIdleWatcher()
            return
        end

        local now = (type(GetTime) == "function") and GetTime() or 0
        local mouseDown = false
        if type(IsMouseButtonDown) == "function" then
            mouseDown = (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and true or false
        end

        local isOverList = false
        for i = 1, 2 do
            local list = _G and _G["DropDownList" .. tostring(i)]
            if list and list.IsShown and list:IsShown() and frame.__fmMenuCtx.IsRegionMouseOver(list) then
                isOverList = true
                break
            end
        end
        if (not isOverList) and frame.__fmMenuCtx.IsRegionMouseOver(open) then
            isOverList = true
        end

        if isOverList then
            frame.__fmMenuCtx.lastActivityTime = now
            -- Preserve the actual state while inside so a held row click is
            -- not reclassified as a new outside click if the cursor moves.
            frame.__fmMenuCtx.lastMouseDown = mouseDown
            return
        end

        if mouseDown and (not frame.__fmMenuCtx.lastMouseDown) then
            if type(CloseDropDownMenus) == "function" then
                pcall(CloseDropDownMenus)
            end
            frame.__fmMenuCtx.lastActivityTime = now
            frame.__fmMenuCtx.lastMouseDown = true
            return
        end
        frame.__fmMenuCtx.lastMouseDown = mouseDown

        local last = frame.__fmMenuCtx.lastActivityTime or now
        if (now - last) >= 2.5 then
            if type(CloseDropDownMenus) == "function" then
                pcall(CloseDropDownMenus)
            end
            frame.__fmMenuCtx.lastActivityTime = now
        end
    end)

    frame.__fmMenuCtx.idleWatcher = watcher
end

function frame.__fmMenuCtx.CapturePoints(region)
    local points = {}
    if not (region and region.GetNumPoints and region.GetPoint) then
        return points
    end
    local num = region:GetNumPoints() or 0
    for i = 1, num do
        local p, rel, rp, x, y = region:GetPoint(i)
        points[i] = { p, rel, rp, x, y }
    end
    return points
end

function frame.__fmMenuCtx.RestorePoints(region, points)
    if not (region and region.ClearAllPoints and region.SetPoint) then return end
    if type(points) ~= "table" or #points == 0 then return end
    region:ClearAllPoints()
    for i = 1, #points do
        local pt = points[i]
        if pt then
            region:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
        end
    end
end

function frame.__fmMenuCtx.CleanupDecoratedMenuButton(menuButton, preserveLayout)
    if not menuButton then return end

    menuButton.__fmHoverPrevName = nil
    menuButton.__fmHoverPrevPath = nil
    menuButton.__fmHoverPrevFlags = nil

    local star = menuButton.__fmStar
    if star then
        star.__fmKey = nil
        star.__fmHover = false
        if star.Hide then star:Hide() end
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == star then
            GameTooltip:Hide()
        end
    end

    if menuButton.__fmTextConstrained and (not preserveLayout) then
        local labelFS = menuButton.GetFontString and menuButton:GetFontString()
        if labelFS then
            frame.__fmMenuCtx.RestorePoints(labelFS, menuButton.__fmOrigLabelPoints)
            if menuButton.__fmOrigLabelJustifyH and labelFS.SetJustifyH then
                labelFS:SetJustifyH(menuButton.__fmOrigLabelJustifyH)
            end
            if menuButton.__fmOrigLabelWordWrapCaptured and labelFS.SetWordWrap then
                labelFS:SetWordWrap(menuButton.__fmOrigLabelWordWrap)
            end
            if menuButton.__fmOrigLabelMaxLinesCaptured and labelFS.SetMaxLines then
                labelFS:SetMaxLines(menuButton.__fmOrigLabelMaxLines)
            end
        end
        menuButton.__fmTextConstrained = nil
        menuButton.__fmOrigLabelPoints = nil
        menuButton.__fmOrigLabelJustifyH = nil
        menuButton.__fmOrigLabelWordWrap = nil
        menuButton.__fmOrigLabelWordWrapCaptured = nil
        menuButton.__fmOrigLabelMaxLines = nil
        menuButton.__fmOrigLabelMaxLinesCaptured = nil
    end
end

function frame.__fmMenuCtx.CleanupTouchedMenuButtons()
    for btn in pairs(frame.__fmMenuCtx.touchedButtons) do
        -- These buttons are global and UIDropDownMenu_AddButton reanchors their
        -- labels whenever a list is built, so always return the shared row to its
        -- original layout when FontMagic's list closes.
        frame.__fmMenuCtx.CleanupDecoratedMenuButton(btn, false)
        frame.__fmMenuCtx.touchedButtons[btn] = nil
    end
end

function frame.__fmMenuCtx.EnsureDropdownCleanupHooks()
    if frame.__fmMenuCtx.cleanupHooked then return end
    local list = _G and _G["DropDownList1"]
    if list and list.HookScript then
        list:HookScript("OnHide", function()
            if type(frame.__fmMenuCtx.HideHoverPreview) == "function" then
                frame.__fmMenuCtx.HideHoverPreview()
            end
            frame.__fmMenuCtx.CleanupTouchedMenuButtons()
            frame.__fmMenuCtx.RestoreDropDownListZOrder(1)
            frame.__fmMenuCtx.RestoreDropDownListZOrder(2)
            frame.__fmMenuCtx.StopIdleWatcher()
        end)
        frame.__fmMenuCtx.cleanupHooked = true
    end
end

local function AttachFavoriteStar(menuButton, ownerDropdown)
    if not menuButton then return end
    frame.__fmMenuCtx.EnsureDropdownCleanupHooks()

    -- During UIDropDownMenu's initializer, list.dropdown can still point at the
    -- previously opened addon; the explicit owner is authoritative here.
    local activeDropdown = ownerDropdown or frame.__fmMenuCtx.GetDropdownForMenuButton(menuButton)
    if not frame.__fmMenuCtx.IsFontMagicDropdown(activeDropdown) then
        frame.__fmMenuCtx.CleanupDecoratedMenuButton(menuButton)
        return
    end

    local star = menuButton.__fmStar
    if not star then
        star = CreateFrame("Button", nil, menuButton)
        star:SetSize(16, 16)
        star:SetPoint("RIGHT", menuButton, "RIGHT", -6, 0)
        star:RegisterForClicks("LeftButtonUp")

        local icon = star:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        star.icon = icon

        -- Slightly increase visibility on hover without relying on unicode glyphs
        -- (many default UI fonts do not contain ★/☆ on older clients).
        star:SetScript("OnEnter", function(self)
            local parent = self.GetParent and self:GetParent()
            if not frame.__fmMenuCtx.IsFontMagicMenuButton(parent) then
                self.__fmHover = false
                if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then
                    GameTooltip:Hide()
                end
                return
            end
            self.__fmHover = true
            if GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText and GameTooltip.Show then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local key = self.__fmKey
                GameTooltip:SetText((key and IsFavorite(key)) and "Remove from Favorites" or "Add to Favorites")
                GameTooltip:Show()
            end
            if self.icon then
                self.icon:SetAlpha(1)
            end
        end)
        star:SetScript("OnLeave", function(self)
            local parent = self.GetParent and self:GetParent()
            if not frame.__fmMenuCtx.IsFontMagicMenuButton(parent) then
                self.__fmHover = false
                if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then
                    GameTooltip:Hide()
                end
                return
            end
            self.__fmHover = false
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
            -- restore the non-hover alpha for the current state
            local key = self.__fmKey
            if self.icon then
                if key and IsFavorite(key) then
                    self.icon:SetAlpha(1)
                else
                    self.icon:SetAlpha(0.75)
                end
            end
        end)

        star:SetScript("OnClick", function(self)
            local parent = self.GetParent and self:GetParent()
            if not frame.__fmMenuCtx.IsFontMagicMenuButton(parent) then return end

            local key = self.__fmKey
            if not key then return end

            ToggleFavorite(key)
            local nowFav = IsFavorite(key)

            -- If we removed a favorite while browsing the Favorites dropdown, do not
            -- force-select it (that makes it look like it still belongs there).
            local open = _G and _G.UIDROPDOWNMENU_OPEN_MENU
            local inFavMenu = (open and open.__fmGroup == "Favorites") and true or false

            if nowFav or not inFavMenu then
                -- Adding a favorite (or toggling anywhere outside Favorites): keep the
                -- existing "select + preview" behavior so the change is visible.
                SelectFontKey(key)
            else
                -- Removed from Favorites while inside Favorites: clear the Favorites
                -- dropdown label only if it was showing this key.
                local shouldClear = (pendingFont == key) or (FontMagicDB and FontMagicDB.selectedFont == key)

                if shouldClear and dropdowns and dropdowns["Favorites"] then
                    if type(UIDropDownMenu_SetText) == "function" then
                        pcall(UIDropDownMenu_SetText, dropdowns["Favorites"], "Select Font")
                    elseif dropdowns["Favorites"].SetText then
                        dropdowns["Favorites"]:SetText("Select Font")
                    end
                end
            end

            -- refresh this button's star state immediately
            if parent then
                UpdateFavoriteStar(parent, key, frame.__fmMenuCtx.GetDropdownForMenuButton(parent))
            end

            -- Favorites list is built on dropdown open; closing is the safest way to ensure it refreshes everywhere.
            if type(CloseDropDownMenus) == "function" then
                CloseDropDownMenus()
            end
        end)

        menuButton.__fmStar = star
    end

    if menuButton.HookScript and not menuButton.__fmContainmentHooked then
        menuButton:HookScript("OnShow", function(self)
            local dd = frame.__fmMenuCtx.GetDropdownForMenuButton(self)
            if dd and not frame.__fmMenuCtx.IsFontMagicDropdown(dd) then
                frame.__fmMenuCtx.CleanupDecoratedMenuButton(self, false)
            end
        end)
        menuButton.__fmContainmentHooked = true
    end

    -- Constrain the entry label so it does not run underneath the star.
    local labelFS = menuButton.GetFontString and menuButton:GetFontString()
    if labelFS and not menuButton.__fmTextConstrained then
        menuButton.__fmOrigLabelPoints = frame.__fmMenuCtx.CapturePoints(labelFS)
        if labelFS.GetJustifyH then
            menuButton.__fmOrigLabelJustifyH = labelFS:GetJustifyH()
        end
        if labelFS.CanWordWrap then
            local ok, value = pcall(labelFS.CanWordWrap, labelFS)
            if ok then
                menuButton.__fmOrigLabelWordWrap = value and true or false
                menuButton.__fmOrigLabelWordWrapCaptured = true
            end
        end
        if labelFS.GetMaxLines then
            local ok, value = pcall(labelFS.GetMaxLines, labelFS)
            if ok then
                menuButton.__fmOrigLabelMaxLines = value
                menuButton.__fmOrigLabelMaxLinesCaptured = true
            end
        end
        labelFS:ClearAllPoints()
        labelFS:SetPoint("LEFT", menuButton, "LEFT", 24, 0)
        labelFS:SetPoint("RIGHT", star, "LEFT", -4, 0)
        if labelFS.SetJustifyH then
            labelFS:SetJustifyH("LEFT")
        end
        if labelFS.SetWordWrap then labelFS:SetWordWrap(false) end
        if labelFS.SetMaxLines then labelFS:SetMaxLines(1) end
        menuButton.__fmTextConstrained = true
    end

    frame.__fmMenuCtx.MarkTouchedMenuButton(menuButton)
end

UpdateFavoriteStar = function(menuButton, key, ownerDropdown)
    if not menuButton or not menuButton.__fmStar then return end
    local activeDropdown = ownerDropdown or frame.__fmMenuCtx.GetDropdownForMenuButton(menuButton)
    if not frame.__fmMenuCtx.IsFontMagicDropdown(activeDropdown) then
        frame.__fmMenuCtx.CleanupDecoratedMenuButton(menuButton)
        return
    end

    frame.__fmMenuCtx.MarkTouchedMenuButton(menuButton)

    local star = menuButton.__fmStar
    star.__fmKey = key

    -- UIDropDownMenu recycles list buttons. If this row is a disabled placeholder
    -- (e.g. "No favorites yet"), hide any previously-attached star.
    if not key then
        if star.Hide then star:Hide() end
        return
    end
    if star.Show then star:Show() end

    local fav = (IsFavorite(key)) and true or false
    if star.icon then
        if fav then
            star.icon:SetTexture(FM_FAV_TEX_ON)
            star.icon:SetVertexColor(1, 0.82, 0)
            star.icon:SetAlpha(1)
        else
            star.icon:SetTexture(FM_FAV_TEX_OFF)
            star.icon:SetVertexColor(0.75, 0.75, 0.75)
            star.icon:SetAlpha(star.__fmHover and 1 or 0.75)
        end
    end
end

local function GetDropDownListButton(level, index)
    return _G and _G["DropDownList" .. tostring(level) .. "Button" .. tostring(index)] or nil
end

--[[
    Apply a font to the preview field.

    The original implementation assumed fontObj was always valid. During early
    loading however, "GameFontNormalLarge" may not yet exist which triggered
    the reported "attempt to index local 'fontObj'" error. To make the function
    robust we guard against nil values and gracefully fall back when loading via
    the font path fails.

    NOTE: Some font files report incorrect metrics on the same frame they are
    first applied (the client may still be loading the face). To ensure the
    preview size normalizes immediately (no "select twice" behavior), we do the
    fit-to-bounds sizing pass on the next frame.
--]]

-- Next-frame helper (compatible across Classic/Retail; avoids relying on C_Timer).
local __fmNextFrameFrame
local __fmNextFrameQueue
local function __fmRunNextFrame(fn)
    if type(fn) ~= "function" then return end
    if not __fmNextFrameFrame then
        __fmNextFrameQueue = {}
        __fmNextFrameFrame = CreateFrame("Frame")
        __fmNextFrameFrame:Hide()
        __fmNextFrameFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            local q = __fmNextFrameQueue or {}
            __fmNextFrameQueue = {}
            for i = 1, #q do
                pcall(q[i])
            end
        end)
    end
    table.insert(__fmNextFrameQueue, fn)
    __fmNextFrameFrame:Show()
end




-- Hover preview for font dropdown items --------------------------------------
-- Shows a small tooltip-like window near the cursor rendering the hovered font name
-- in its own face, so users can browse without clicking each entry.

local __fmHoverPrevFrame, __fmHoverPrevText
local __fmHoverPrevToken = 0

local function __fmGetCursorScaled()
    if type(GetCursorPosition) ~= "function" then return 0, 0 end
    local x, y = GetCursorPosition()
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    end
    if scale == 0 then scale = 1 end
    return (x or 0) / scale, (y or 0) / scale
end

local function __fmPositionHoverPreview(f)
    if not (f and UIParent and UIParent.GetWidth and UIParent.GetHeight) then return end
    local x, y = __fmGetCursorScaled()
    local uiW = UIParent:GetWidth() or 0
    local uiH = UIParent:GetHeight() or 0
    local w  = f:GetWidth()  or 0
    local h  = f:GetHeight() or 0

    -- Preferred placement: to the right and slightly above the cursor.
    local offsetX, offsetY = 18, 18
    local left = x + offsetX
    local top  = y + offsetY

    -- If near the right edge, flip to the left of the cursor.
    if (left + w) > (uiW - 6) then
        left = x - offsetX - w
    end
    -- Clamp to screen bounds (a little inset keeps border visible).
    if left < 6 then left = 6 end
    if (left + w) > (uiW - 6) then left = (uiW - w - 6) end

    -- Keep within vertical bounds.
    if top > (uiH - 6) then
        top = uiH - 6
    end
    if (top - h) < 6 then
        -- Try placing below the cursor if we're too high.
        top = y - offsetY
        if (top - h) < 6 then
            top = h + 6
        end
    end

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function __fmEnsureHoverPreviewFrame()
    if __fmHoverPrevFrame then return __fmHoverPrevFrame end

    local f = CreateFrame("Frame", addonName .. "HoverPreview", UIParent, Compat.BackdropTemplate)
    f:SetSize(260, 46)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16,
            edgeSize = 12,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.92)
        if f.SetBackdropBorderColor then
            f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        end
    end

    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", f, "CENTER", 0, -1)
    fs:SetWidth((f:GetWidth() or 260) - 14)
    fs:SetJustifyH("CENTER")
    if fs.SetJustifyV then pcall(fs.SetJustifyV, fs, "MIDDLE") end

    f.text = fs
    f:Hide()

    f.__fmFollowCursor = true
    f:SetScript("OnUpdate", function(self)
        if self:IsShown() and self.__fmFollowCursor then
            if frame and frame.__fmMenuCtx and type(frame.__fmMenuCtx.BringHoverPreviewToFront) == "function" then
                frame.__fmMenuCtx.BringHoverPreviewToFront(self)
            end
            __fmPositionHoverPreview(self)
        end
    end)

    __fmHoverPrevFrame = f
    __fmHoverPrevText  = fs
    return f
end

frame.__fmMenuCtx.HideHoverPreview = function()
    __fmHoverPrevToken = (__fmHoverPrevToken or 0) + 1
    if __fmHoverPrevFrame then
        __fmHoverPrevFrame:Hide()
    end
end

local function __fmShowHoverPreview(display, path, flags)
    if type(display) ~= "string" or display == "" then return end
    if type(path) ~= "string" or path == "" then return end

    local f = __fmEnsureHoverPreviewFrame()
    if not (f and f.text) then return end

    local fs = f.text
    fs:SetText(display)

    -- Use a conservative starter size; we'll fit-to-bounds next frame.
    local baseObj = GameFontNormalLarge or GameFontNormal or GameFontHighlight
    local flagsToUse = flags or ""

    local ok = false
    if fs.SetFont then
        local result
        ok, result = pcall(fs.SetFont, fs, path, 18, flagsToUse)
        ok = ok and result ~= false
        if (not ok) and flagsToUse ~= "" then
            ok, result = pcall(fs.SetFont, fs, path, 18, "")
            ok = ok and result ~= false
            if ok then flagsToUse = "" end
        end
    end
    if (not ok) and fs.SetFontObject and baseObj then
        pcall(fs.SetFontObject, fs, baseObj)
    end

    __fmHoverPrevToken = (__fmHoverPrevToken or 0) + 1
    local myToken = __fmHoverPrevToken

    __fmRunNextFrame(function()
        if myToken ~= __fmHoverPrevToken then return end
        if not (__fmHoverPrevFrame and __fmHoverPrevFrame.IsShown and __fmHoverPrevFrame:IsShown()) then return end
        if not (__fmHoverPrevText and __fmHoverPrevText.SetFont and __fmHoverPrevText.GetStringWidth and __fmHoverPrevText.GetStringHeight) then return end

        local maxW = (__fmHoverPrevFrame:GetWidth() or 260) - 16
        local maxH = (__fmHoverPrevFrame:GetHeight() or 46) - 16
        if maxW < 40 then maxW = 200 end
        if maxH < 16 then maxH = 24 end

        local function trySize(sz)
            local ok2, result = pcall(__fmHoverPrevText.SetFont, __fmHoverPrevText, path, sz, flagsToUse)
            ok2 = ok2 and result ~= false
            if not ok2 and flagsToUse ~= "" then
                ok2, result = pcall(__fmHoverPrevText.SetFont, __fmHoverPrevText, path, sz, "")
                ok2 = ok2 and result ~= false
                if ok2 then flagsToUse = "" end
            end
            if not ok2 then return false end
            __fmHoverPrevText:SetText(display)
            local w = __fmHoverPrevText:GetStringWidth() or 0
            local h = __fmHoverPrevText:GetStringHeight() or 0
            return (w <= maxW and h <= maxH)
        end

        local low, high = 10, 28
        local best = 14
        while low <= high do
            local mid = math.floor((low + high) / 2)
            if trySize(mid) then
                best = mid
                low = mid + 1
            else
                high = mid - 1
            end
        end
        trySize(best)
    end)

    if frame and frame.__fmMenuCtx and type(frame.__fmMenuCtx.BringHoverPreviewToFront) == "function" then
        frame.__fmMenuCtx.BringHoverPreviewToFront(f)
    end
    __fmPositionHoverPreview(f)
    f:Show()
end

local function __fmAttachHoverPreviewToMenuButton(btn, display, cache, ownerDropdown)
    if not btn then return end
    if type(display) ~= "string" or display == "" then return end
    frame.__fmMenuCtx.EnsureDropdownCleanupHooks()

    local activeDropdown = ownerDropdown or frame.__fmMenuCtx.GetDropdownForMenuButton(btn)
    if not frame.__fmMenuCtx.IsFontMagicDropdown(activeDropdown) then
        frame.__fmMenuCtx.CleanupDecoratedMenuButton(btn)
        return
    end

    local path, flags
    if type(cache) == "table" then
        path  = cache.path
        flags = cache.flags
    end
    if type(path) ~= "string" or path == "" then return end

    btn.__fmHoverPrevName  = display
    btn.__fmHoverPrevPath  = path
    btn.__fmHoverPrevFlags = flags
    frame.__fmMenuCtx.MarkTouchedMenuButton(btn)

    if btn.HookScript and not btn.__fmHoverPrevHooked then
        btn:HookScript("OnEnter", function(self)
            if not frame.__fmMenuCtx.IsFontMagicMenuButton(self) then
                frame.__fmMenuCtx.HideHoverPreview()
                return
            end
            if self.__fmHoverPrevPath then
                __fmShowHoverPreview(self.__fmHoverPrevName or "", self.__fmHoverPrevPath, self.__fmHoverPrevFlags)
            end
        end)
        btn:HookScript("OnLeave", function()
            frame.__fmMenuCtx.HideHoverPreview()
        end)
        btn.__fmHoverPrevHooked = true
    end
end

-- Ensure we never leave the hover preview orphaned if menus close without an OnLeave (rare but possible).
if type(hooksecurefunc) == "function" then
    if type(CloseDropDownMenus) == "function" then
        pcall(hooksecurefunc, "CloseDropDownMenus", frame.__fmMenuCtx.HideHoverPreview)
    end
    if type(UIDropDownMenu_HideDropDownMenu) == "function" then
        pcall(hooksecurefunc, "UIDropDownMenu_HideDropDownMenu", frame.__fmMenuCtx.HideHoverPreview)
    end
end

-- Force a redraw of the preview text (some clients won't repaint an unchanged string
-- immediately after SetFont/SetFontObject until the text changes).
local function ForcePreviewTextRedraw()
    if not (preview and type(preview.SetText) == "function") then return end

    local txt = ""
    if editBox and type(editBox.GetText) == "function" then
        txt = tostring(editBox:GetText() or "")
    elseif type(preview.GetText) == "function" then
        txt = tostring(preview:GetText() or "")
    end

    local cur = ""
    if type(preview.GetText) == "function" then
        cur = tostring(preview:GetText() or "")
    end

    if txt ~= cur then
        preview:SetText(txt)
    else
        preview:SetText(txt .. " ")
        preview:SetText(txt)
    end
end

SetPreviewFont = function(fontObj, path)
    -- allow passing the cached font table directly
    if type(fontObj) == "table" then
        path    = fontObj.path or path
        fontObj = fontObj.font
    end

    -- Some clients (or earlier calls to SetFont) can leave preview:GetFontObject() nil.
    -- We still want preview updates to work even when no FontObject is available.
    local baseObj = fontObj
    if not (baseObj and type(baseObj.GetFont) == "function") then
        baseObj = GameFontNormalLarge or GameFontNormal or GameFontHighlight or (preview and preview.GetFontObject and preview:GetFontObject())
    end

    local baseFlags = ""
    local _, _, _, inheritedFlags = Compat.GetFontTuple(baseObj)
    if type(inheritedFlags) == "string" then baseFlags = inheritedFlags end

    local function GetCurrentPreviewText()
        if editBox and editBox.GetText then
            return tostring(editBox:GetText() or "")
        end
        if preview and preview.GetText then
            return tostring(preview:GetText() or "")
        end
        return ""
    end

    -- If we have an explicit file path, apply it and normalize size so all fonts
    -- appear visually consistent inside the preview box (fit-to-bounds).
    if path and preview and type(preview.SetFont) == "function" then
        local flagsToUse = baseFlags


        local function tryApply(sz, flags)
            local ok, result = pcall(preview.SetFont, preview, path, sz, flags)
            if not ok or result == false then return false end

            -- Do not trust the return value from SetFont: different clients / objects
            -- return different values (or nothing), and some apply the face asynchronously.
            -- If we can't confirm immediately, we still proceed and normalize next frame.
            if preview and type(preview.GetFont) == "function" then
                local _, curPath = Compat.GetFontTuple(preview)
                if type(curPath) == "string" then
                    local want = tostring(path)
                    if curPath:lower() == want:lower() then
                        return true
                    end
                    local wantFile = want:match("([^\\/:]+)$")
                    if wantFile and curPath:lower():find(wantFile:lower(), 1, true) then
                        return true
                    end
                end
            end

            return true
        end

        -- Force the face to load immediately with a sensible starter size.
        local applied = tryApply(24, flagsToUse)
        if not applied then
            applied = tryApply(24, "")
            if applied then
                flagsToUse = ""
            end
        end

        if not applied then
            -- If the client refuses to load this font path, fall back to a base FontObject.
            if preview and type(preview.SetFontObject) == "function" and baseObj then
                pcall(preview.SetFontObject, preview, baseObj)
            end
            -- Ensure text is still visible.
            if preview and preview.SetText then
                ForcePreviewTextRedraw()
            end
            return
        end

        -- Ensure the current preview text is displayed immediately.
        if preview and preview.SetText then
            ForcePreviewTextRedraw()
        end

        __fmPreviewToken = (__fmPreviewToken or 0) + 1
        local myToken = __fmPreviewToken

        __fmRunNextFrame(function()
            if myToken ~= __fmPreviewToken then return end
            if not preview or type(preview.SetFont) ~= "function" then return end

            -- Use the preview's parent (the preview box) for sizing.
            local parent = (preview.GetParent and preview:GetParent()) or nil
            local maxW, maxH = 0, 0
            local padX, padY = 14, 16
            if parent and parent.GetWidth and parent.GetHeight then
                maxW = (parent:GetWidth() or 0) - padX
                maxH = (parent:GetHeight() or 0) - padY
            end
            if maxW <= 0 then maxW = (preview.GetWidth and preview:GetWidth()) or 300 end
            if maxH <= 0 then maxH = (preview.__fmMaxH or 44) end
            if maxH < 18 then maxH = 18 end

            if preview.SetWordWrap then
                pcall(preview.SetWordWrap, preview, false)
            end

            -- Measure off-screen so we never blank or replace the user's preview text.
            local measure = preview.__fmMeasure
            if not measure and parent and parent.CreateFontString then
                measure = parent:CreateFontString(nil, "OVERLAY")
                measure:Hide()
                preview.__fmMeasure = measure
            end

            local sample = "H8g"

            local function trySize(sz)
                if myToken ~= __fmPreviewToken then return false end

                if measure and type(measure.SetFont) == "function" then
                    local ok, ret = pcall(measure.SetFont, measure, path, sz, flagsToUse)
                    if not ok or ret == false then return false end
                    if measure.SetText then
                        measure:SetText(sample)
                    end
                    local w = (measure.GetStringWidth and measure:GetStringWidth()) or 0
                    local h = (measure.GetStringHeight and measure:GetStringHeight()) or 0
                    return (w <= maxW and h <= (maxH - 2))
                end

                -- Fallback: if we cannot create a measure string, temporarily measure on the preview.
                local old = GetCurrentPreviewText()
                if preview.SetText then preview:SetText(sample) end
                local ok, ret = pcall(preview.SetFont, preview, path, sz, flagsToUse)
                local w = (preview.GetStringWidth and preview:GetStringWidth()) or 0
                local h = (preview.GetStringHeight and preview:GetStringHeight()) or 0
                if preview.SetText then preview:SetText(old) end
                if not ok or ret == false then return false end
                return (w <= maxW and h <= (maxH - 2))
            end

            -- Find the largest size that fits (binary search).
            local low, high = 8, 90
            local best = 8
            if not trySize(best) then best = 8 end
            while low <= high do
                local mid = math.floor((low + high) / 2)
                if trySize(mid) then
                    best = mid
                    low = mid + 1
                else
                    high = mid - 1
                end
            end

            if myToken ~= __fmPreviewToken then return end
            pcall(preview.SetFont, preview, path, best, flagsToUse)

            -- Force a redraw of the preview text even if it hasn't changed.
            if preview and preview.SetText then
                local finalText = GetCurrentPreviewText()
                local curText = ""
                if preview.GetText then curText = tostring(preview:GetText() or "") end
                if finalText ~= curText then
                    preview:SetText(finalText)
                else
                    -- Some clients won't redraw if the string is identical.
                    preview:SetText(finalText .. " ")
                    preview:SetText(finalText)
                end
            end
        end)

        return
    end

    -- Fall back to using the font object if explicit path loading is not available.
    if preview and type(preview.SetFontObject) == "function" and baseObj then
        pcall(preview.SetFontObject, preview, baseObj)
        if preview and preview.SetText then
            ForcePreviewTextRedraw()
        end
    end
end



-- Update the font-name label above the preview box so it always reflects what is being previewed.
local __fmHeaderToken = 0
UpdatePreviewHeaderText = function(displayText, fontPath, isDefault)
    if not previewHeaderFS then return end

    local text = "Default"
    if not isDefault and type(displayText) == "string" and displayText ~= "" then
        text = displayText
    end
    if previewHeaderFS.SetText then
        previewHeaderFS:SetText(text)
    end

    local path = fontPath
    if type(path) ~= "string" or path == "" then
        CombatFont:CaptureDefaults()
        path = CombatFont:GetDefaultPath()
    end
    if type(path) ~= "string" or path == "" then return end

    local baseObj = GameFontNormal or GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject())
    local flagsToUse = ""
    local starterSize = 14
    if starterSize < 12 then starterSize = 12 end
    if starterSize > 18 then starterSize = 18 end

    if type(previewHeaderFS.SetFont) ~= "function" then
        if previewHeaderFS.SetFontObject and baseObj then
            pcall(previewHeaderFS.SetFontObject, previewHeaderFS, baseObj)
        end
        return
    end

    -- Attempt an immediate apply so it doesn't remain at a tiny fallback size.
    do
        local ok, result = pcall(previewHeaderFS.SetFont, previewHeaderFS, path, starterSize, flagsToUse)
        ok = ok and result ~= false
        if not ok and flagsToUse ~= "" then
            ok, result = pcall(previewHeaderFS.SetFont, previewHeaderFS, path, starterSize, "")
            ok = ok and result ~= false
            if ok then
                flagsToUse = ""
            end
        end
        if not ok and previewHeaderFS.SetFontObject and baseObj then
            pcall(previewHeaderFS.SetFontObject, previewHeaderFS, baseObj)
        end
    end

    __fmHeaderToken = (__fmHeaderToken or 0) + 1
    local myToken = __fmHeaderToken

    __fmRunNextFrame(function()
        if myToken ~= __fmHeaderToken then return end
        if not previewHeaderFS or type(previewHeaderFS.SetFont) ~= "function" then return end

        local maxW = ((previewHeaderFS.GetWidth and previewHeaderFS:GetWidth()) or (PREVIEW_W or 320)) - 12
        if maxW < 40 then maxW = (PREVIEW_W or 320) - 12 end
        local maxH = 18

        local function trySize(sz)
            local ok, result = pcall(previewHeaderFS.SetFont, previewHeaderFS, path, sz, flagsToUse)
            ok = ok and result ~= false
            if not ok and flagsToUse ~= "" then
                ok, result = pcall(previewHeaderFS.SetFont, previewHeaderFS, path, sz, "")
                ok = ok and result ~= false
                if ok then
                    flagsToUse = ""
                end
            end
            if not ok then return false end

            local w = (previewHeaderFS.GetStringWidth and previewHeaderFS:GetStringWidth()) or 0
            local h = (previewHeaderFS.GetStringHeight and previewHeaderFS:GetStringHeight()) or 0
            return (w <= maxW and h <= maxH)
        end

        local low, high = 8, 22
        local best = 12
        while low <= high do
            local mid = math.floor((low + high) / 2)
            if trySize(mid) then
                best = mid
                low = mid + 1
            else
                high = mid - 1
            end
        end
        trySize(best)
    end)
end

-- Dropdowns for each font group arranged neatly in two columns
-- Displayed dropdown order; the "Custom" category replaces the old "Default"
-- dropdown to allow users to provide their own fonts.
local order = {"Favorites", "Popular", "Clean & Readable", "Bold & Impact", "Fantasy & RP", "Sci-Fi & Tech", "Custom", "Random"}
-- "Popular" is driven by the /Popular folder (authoritative).
-- Optional display-name overrides for cleaner dropdown labels.
local FONT_LABEL_OVERRIDES = {
    ["bignoodletitling.ttf"]             = "Big Noodle Titling",
    ["PTSansNarrow-Bold.ttf"]            = "PT Sans Narrow (Bold)",
    ["NotoSans_Condensed-Bold.ttf"]      = "Noto Sans Condensed (Bold)",
    ["Roboto Condensed Bold.ttf"]        = "Roboto Condensed (Bold)",
    ["Roboto-Bold.ttf"]                  = "Roboto (Bold)",
    ["CalibriBold.ttf"]                  = "Calibri (Bold)",
    ["AlteHaasGroteskBold.ttf"]          = "Alte Haas Grotesk (Bold)",
    ["Proxima Nova Condensed Bold.ttf"]  = "Proxima Nova Condensed (Bold)",
    ["lemon-milk.ttf"]                   = "Lemon Milk",
}

local FONT_LABEL_OVERRIDES_L = {}
for k, v in pairs(FONT_LABEL_OVERRIDES) do
    if type(k) == "string" then
        FONT_LABEL_OVERRIDES_L[k:lower()] = v
    end
end

local function DisplayNameForFont(fname)
    if type(fname) ~= "string" or fname == "" then return "" end
    local base = Fonts.StripExtension(fname)
    local lower = fname:lower()
    local label = FONT_LABEL_OVERRIDES[fname] or FONT_LABEL_OVERRIDES_L[lower] or base
    return Fonts.ShortenLabel(label)
end



for idx, grp in ipairs(order) do
    local dd = CreateFrame("Frame", addonName .. grp:gsub("[^%w]", "") .. "DD", frame, "UIDropDownMenuTemplate")
    dd.__fmOwner = true
    dd.__fmGroup = grp
    local row = math.floor((idx-1)/DD_COLS)
    local col = (idx-1) % DD_COLS

    -- If the last row is not full, center the remaining dropdown for a cleaner look.
    local remainder = #order % DD_COLS
    local x = DD_MARGIN_X + col * DD_COL_W
    if remainder == 1 and idx == #order and grp ~= "Custom" then
        x = DD_MARGIN_X + (DD_COL_W / 2)
    end

-- place dropdowns below the InterfaceOptions title text
    -- shift dropdowns slightly so left and right margins are even
    -- Position each dropdown in its own column.  We reduce the default
    -- horizontal margin from 16px to 12px so that the combined width of the
    -- two dropdowns, the spacing between them and the left/right margins add
    -- up symmetrically across the options window.  Without this adjustment
    -- the rightmost dropdown sits flush against the frame border.
    dd:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(HEADER_H + row*50) + 8)
    UIDropDownMenu_SetWidth(dd, DD_WIDTH)
    AnchorFontMagicDropDown(dd)
    dropdowns[grp] = dd
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- position label so its left edge aligns with the dropdown
    label:ClearAllPoints()
    label:SetPoint("BOTTOM", dd, "TOP", 0, 3)
    -- Use the frame's GetWidth() method to obtain the dropdown width.
    -- UIDropDownMenu_GetWidth has been removed in Dragonflight and older
    -- globals may not return a valid number. GetWidth() is available on all
    -- frames and ensures a numeric width is returned.
    label:SetWidth(dd:GetWidth())
    label:SetJustifyH("CENTER")
    label:SetText(grp)

    if grp == "Custom" then
        dd:SetScript("OnEnter", function(self)
            if not Fonts.HasCustomFonts then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Install FontMagicCustomFonts to use custom fonts", nil, nil, nil, nil, true)
                GameTooltip:Show()
            end
        end)
        dd:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    UIDropDownMenu_Initialize(dd, function()
        local level = UIDROPDOWNMENU_MENU_LEVEL or 1
        frame.__fmMenuCtx.EnsureDropdownCleanupHooks()
        frame.__fmMenuCtx.EnsureIdleWatcher()
        frame.__fmMenuCtx.BringDropDownListToFront(level)
        frame.__fmMenuCtx.TouchMenuActivity()
        local added = false
        local buttonIndex = 0

        if grp == "Favorites" then
            local favs = EnsureFavorites()
            local favList = {}
            for key, on in pairs(favs) do
        if on == true then
            -- Parse using the last '/' so legacy groups with slashes are handled.
            local g, f = key:match("^(.*)/([^/]+)$")
            if g and f and Fonts.Exists[g] and Fonts.Exists[g][f] and Fonts.Cached[g] and Fonts.Cached[g][f] then
                local display = (g == "Custom") and Fonts.StripExtension(f) or DisplayNameForFont(f)
                table.insert(favList, { key = key, grp = g, fname = f, display = display })
            end
        end
            end
            table.sort(favList, function(a, b)
                return (a.display:lower() .. a.key) < (b.display:lower() .. b.key)
            end)

            for _, item in ipairs(favList) do
                added = true
                buttonIndex = buttonIndex + 1

                local info = UIDropDownMenu_CreateInfo()
                local cache = Fonts.Cached[item.grp][item.fname]
                info.text = item.display
                info.func = function()
                    for g2, d2 in pairs(dropdowns) do UIDropDownMenu_SetText(d2, "Select Font") end
                    -- store the selected font locally until the user clicks Apply
                    pendingFont = item.key
                    UIDropDownMenu_SetText(dd, item.display)
                    SetPreviewFont(cache)
                    if UpdatePreviewHeaderText then UpdatePreviewHeaderText(item.display, cache.path, false) end
                    local txt = editBox:GetText()
                    preview:SetText("")
                    preview:SetText(txt)
                end
                local selected = pendingFont or FontMagicDB.selectedFont
                info.checked = (selected == item.key)
                SafeAddDropDownButton(info, level)

                local mb = GetDropDownListButton(level, buttonIndex)
                if mb then
                    AttachFavoriteStar(mb, dd)
                    UpdateFavoriteStar(mb, item.key, dd)
                    __fmAttachHoverPreviewToMenuButton(mb, item.display, cache, dd)
                end
            end
        else
            local groupData = Fonts.Groups[grp]
            if type(groupData) == "table" and type(groupData.fonts) == "table" then
                for _, fname in ipairs(groupData.fonts) do
                if Fonts.Exists[grp][fname] then
                    added = true
                    buttonIndex = buttonIndex + 1

                    local info = UIDropDownMenu_CreateInfo()
                    local display = (grp == "Custom") and Fonts.StripExtension(fname) or DisplayNameForFont(fname)
                    local cache  = Fonts.Cached[grp][fname]
                    local key    = grp .. "/" .. fname

                    info.text = display
                    info.func = function()
                        for g2, d2 in pairs(dropdowns) do UIDropDownMenu_SetText(d2, "Select Font") end
                        -- store the selected font locally until the user clicks Apply
                        pendingFont = key
                        UIDropDownMenu_SetText(dd, display)
                        SetPreviewFont(cache)
                        if UpdatePreviewHeaderText then UpdatePreviewHeaderText(display, cache.path, false) end
                        local txt = editBox:GetText()
                        preview:SetText("")
                        preview:SetText(txt)
                    end
                    local selected = pendingFont or FontMagicDB.selectedFont
                    info.checked = (selected == key)
                    SafeAddDropDownButton(info, level)

                    local mb = GetDropDownListButton(level, buttonIndex)
                    if mb then
                        AttachFavoriteStar(mb, dd)
                        UpdateFavoriteStar(mb, key, dd)
                        __fmAttachHoverPreviewToMenuButton(mb, display, cache, dd)
                    end
                end
            end
            end
        end
        if not added then
            local info = UIDropDownMenu_CreateInfo()
            info.text = (grp == "Favorites") and "No favorites yet" or "No font detected"
            info.disabled = true
            SafeAddDropDownButton(info, level)

            -- This entry is a disabled placeholder; ensure any recycled menu button
            -- doesn't show a leftover favorite star from a previous dropdown open.
            local mb = GetDropDownListButton(level, buttonIndex + 1)
            if mb and mb.__fmStar then
                UpdateFavoriteStar(mb, nil, dd)
            end
        end
        frame.__fmMenuCtx.FinalizeDropDownListWidth(level)
    end)
end

-- 5) SCALE SLIDER -----------------------------------------------------------
local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
-- Centre the combat text size label beneath the last row of dropdowns.  We
-- calculate how many rows of dropdowns exist (three columns per row) and
-- position the label relative to the top of the frame so it always sits
-- centred horizontally regardless of whether the last dropdown falls in the
-- left or right column.  The vertical offset accounts for the header
-- height, the number of dropdown rows and additional padding.
do
    local rows = math.ceil(#order / DD_COLS)
    -- Nudge the whole lower section up slightly so the checkbox block stays
    -- comfortably above the bottom action buttons.
    local y = -(HEADER_H + rows * 50) - 20 + CONTENT_NUDGE_Y + 6
    scaleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_PANEL_X, y)
end
scaleLabel:SetWidth(PREVIEW_W)
scaleLabel:SetJustifyH("CENTER")
scaleLabel:SetText("Combat Text Size:")

local slider = CreateFrame("Slider", addonName .. "ScaleSlider", frame, "OptionsSliderTemplate")
-- Match the width of the preview/edit boxes so the slider aligns perfectly
-- with the elements below.  A wider slider improves balance within the
-- options window.
slider:SetSize(PREVIEW_W, 16)
-- Anchor the slider below the combat text size label and centre it
-- horizontally.  This eliminates the previous left‑anchored layout which
-- appeared off centre.
slider:SetPoint("TOP", scaleLabel, "BOTTOM", 0, -8) -- temporary; we'll re-anchor after creating the value label

-- The OptionsSliderTemplate adds its own "Text" label which can overlap with
-- our custom scale value and the "Combat Text Size" label. Hide it for a
-- cleaner, more predictable layout across versions.
do
    local sliderText = slider.Text or _G[slider:GetName() .. "Text"]
    if sliderText and sliderText.Hide then
        sliderText:Hide()
    end

    -- Re-anchor the built-in Low/High labels flush with the ends of the bar.
    local low = _G[slider:GetName() .. "Low"]
    local high = _G[slider:GetName() .. "High"]
    if low and high then
        if low.ClearAllPoints then low:ClearAllPoints() end
        if high.ClearAllPoints then high:ClearAllPoints() end
        if low.SetPoint then low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2) end
        if high.SetPoint then high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2) end
    end
end

local function GetCombatTextScaleCVar()
    -- Blizzard renamed a number of Floating Combat Text settings in late 12.0 hotfixes
    -- (often appending a _v2 suffix). In some builds these also appear as console
    -- commands. Resolve the correct name/type at runtime.
    local candidates = {
        "WorldTextScale_v2",
        "WorldTextScale_V2",
        "WorldTextScale",
        "floatingCombatTextScale_v2",
        "floatingCombatTextScale_V2",
        "floatingCombatTextScale",
    }

    local name, commandType = CVars.Resolve(candidates)
    if name and commandType == 0 and CVars.GetCurrent(name) ~= nil then
        local value = CVars.GetString(name)
        return name, commandType, value
    end

    return nil, nil, nil
end


local scaleCVar, scaleCVarCommandType, scaleCVarValue = GetCombatTextScaleCVar()
local scaleSupported = scaleCVar ~= nil
local COMBAT_TEXT_SCALE_MIN = 0.1
local COMBAT_TEXT_SCALE_MAX = 5.0

local scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
scaleValue:ClearAllPoints()
scaleValue:SetWidth(PREVIEW_W)
scaleValue:SetJustifyH("CENTER")

-- Put the numeric value on its own line between the label and the slider so it
-- can never overlap the label text (the overlap shown in your screenshot).
scaleValue:SetPoint("TOP", scaleLabel, "BOTTOM", 0, -6)

-- Now that the value label exists, anchor the slider beneath it.
slider:ClearAllPoints()
slider:SetPoint("TOP", scaleValue, "BOTTOM", 0, -10)

local function UpdateScale(val)
    if not scaleSupported then return end
    if val < COMBAT_TEXT_SCALE_MIN then
        val = COMBAT_TEXT_SCALE_MIN
    elseif val > COMBAT_TEXT_SCALE_MAX then
        val = COMBAT_TEXT_SCALE_MAX
    end
    val = math.floor(val * 10 + 0.5) / 10
    if not CVars.Apply(scaleCVar, scaleCVarCommandType, tostring(val)) then
        FM.UI.ReportRejectedSetting("combat text size")
        local current = tonumber(CVars.GetString(scaleCVar)) or 1.0
        if current < COMBAT_TEXT_SCALE_MIN then current = COMBAT_TEXT_SCALE_MIN end
        if current > COMBAT_TEXT_SCALE_MAX then current = COMBAT_TEXT_SCALE_MAX end
        slider:SetScript("OnValueChanged", nil)
        slider:SetValue(current)
        scaleValue:SetText(string.format("%.1f", current))
        slider:SetScript("OnValueChanged", function(self, newValue) UpdateScale(newValue) end)
        return false
    end
    FontMagicDB = FontMagicDB or {}
    FontMagicDB.combatTextScale = val
    FontMagicDB.combatTextScaleTouched = true
    scaleValue:SetText(string.format("%.1f", val))
    return true
end

function FM.CombatSettings.ApplyScale()
    if type(FontMagicDB) ~= "table" or not FontMagicDB.combatTextScaleTouched
        or type(FontMagicDB.combatTextScale) ~= "number" then
        return true
    end
    local name, commandType = GetCombatTextScaleCVar()
    if not name or commandType ~= 0 then return false end
    local value = math.max(COMBAT_TEXT_SCALE_MIN,
        math.min(COMBAT_TEXT_SCALE_MAX, FontMagicDB.combatTextScale))
    return CVars.Apply(name, commandType, string.format("%.1f", value))
end

local function RefreshScaleControl()
    scaleCVar, scaleCVarCommandType, scaleCVarValue = GetCombatTextScaleCVar()
    scaleSupported = scaleCVar ~= nil
    slider:SetScript("OnValueChanged", nil)

    if scaleSupported then
        slider:SetMinMaxValues(COMBAT_TEXT_SCALE_MIN, COMBAT_TEXT_SCALE_MAX)
        slider:SetValueStep(0.1)
        slider:SetObeyStepOnDrag(true)
        local low = _G[slider:GetName() .. "Low"]
        local high = _G[slider:GetName() .. "High"]
        if low and low.SetText then low:SetText(string.format("%.1f", COMBAT_TEXT_SCALE_MIN)) end
        if high and high.SetText then high:SetText(string.format("%.1f", COMBAT_TEXT_SCALE_MAX)) end
        slider:Enable()
        scaleLabel:SetTextColor(1, 1, 1)
        local currentScale = tonumber(scaleCVarValue)
            or tonumber(CVars.GetString(scaleCVar)) or 1.0
        if currentScale < COMBAT_TEXT_SCALE_MIN then
            currentScale = COMBAT_TEXT_SCALE_MIN
        elseif currentScale > COMBAT_TEXT_SCALE_MAX then
            currentScale = COMBAT_TEXT_SCALE_MAX
        end
        slider:SetValue(currentScale)
        scaleValue:SetText(string.format("%.1f", currentScale))
        slider:SetScript("OnValueChanged", function(self, val) UpdateScale(val) end)
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Drag to adjust combat text size", 1, 1, 1)
            GameTooltip:Show()
        end)
    else
        slider:Disable()
        scaleLabel:SetTextColor(0.5, 0.5, 0.5)
        local low = _G[slider:GetName() .. "Low"]
        local high = _G[slider:GetName() .. "High"]
        if low and low.SetText then low:SetText("") end
        if high and high.SetText then high:SetText("") end
        scaleValue:SetText("|cff888888N/A|r")
        slider:SetScript("OnValueChanged", nil)
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Not available in this version of WoW", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
    end
    slider:SetScript("OnLeave", GameTooltip_Hide)
end

RefreshScaleControl()

-- 6) PREVIEW & EDIT ---------------------------------------------------------
local PREVIEW_BOX_H = 84

-- Fixed-size preview "textbox" so the preview area stays consistent between fonts.
local previewBox = CreateFrame("Frame", addonName .. "PreviewBox", frame, Compat.BackdropTemplate)
previewBox:SetSize(PREVIEW_W, PREVIEW_BOX_H)
previewBox:ClearAllPoints()
previewBox:SetPoint("TOP", slider, "BOTTOM", 0, -30)
previewBox:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16,
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
-- Darker preview background improves contrast against bright scenes.
previewBox:SetBackdropColor(0, 0, 0, 0.55)
previewBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

-- Font name label above the preview box (renders using the selected font)
previewHeaderFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
previewHeaderFS:SetPoint("BOTTOM", previewBox, "TOP", 0, 6)
previewHeaderFS:SetWidth(PREVIEW_W - 10)
previewHeaderFS:SetJustifyH("CENTER")
previewHeaderFS:SetText("Default")

-- Ensure no preview text bleeds outside the box on any client
if previewBox.SetClipsChildren then pcall(previewBox.SetClipsChildren, previewBox, true) end

preview = previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
preview:ClearAllPoints()
-- Nudge down slightly: some decorative fonts draw a few pixels above their
-- reported ascent and can otherwise clip at the very top when the box clips.
preview:SetPoint("CENTER", previewBox, "CENTER", 0, -1)
preview:SetWidth(PREVIEW_W - 10)
preview:SetJustifyH("CENTER")
if preview.SetJustifyV then pcall(preview.SetJustifyV, preview, "MIDDLE") end
preview:SetText("12345")
-- Conservative fallback height budget for clients that return 0 sizes while hidden.
preview.__fmMaxH = PREVIEW_BOX_H - 16

-- Apply a default preview font. GameFontNormalLarge should normally exist,
-- but we fall back to the current FontObject if it does not to avoid errors.
SetPreviewFont(GameFontNormalLarge or (preview.GetFontObject and preview:GetFontObject()), CombatFont:GetDefaultPath())
if UpdatePreviewHeaderText then UpdatePreviewHeaderText("Default", CombatFont:GetDefaultPath(), true) end

editBox = CreateFrame("EditBox", addonName .. "PreviewEdit", frame, "InputBoxTemplate")
editBox:SetSize(PREVIEW_W, 24)
editBox:ClearAllPoints()
editBox:SetPoint("TOP", previewBox, "BOTTOM", 0, -8)
editBox:SetAutoFocus(false)
editBox:SetText("12345")
editBox:SetScript("OnTextChanged", function(self) preview:SetText(self:GetText()) end)

-- Discard un-applied font previews whenever the window closes.
-- This ensures that reopening the addon always reflects the *currently applied*
-- combat text font (saved in FontMagicDB, or Blizzard default when none is saved),
-- and prevents a rare race where a queued next-frame sizing pass from a preview
-- can overwrite the correct font after reopening.
local function SyncPreviewToAppliedFont()
    if not (preview and editBox) then return end

    local key = FontMagicDB and FontMagicDB.selectedFont
    local path, grp, fname
    local label, isDef = "Default", true

    -- Settings can show this canvas without going through FontMagic's slash or
    -- minimap opener. Reset recycled selector labels here as well as the
    -- preview so every entry point reflects the same applied selection.
    if type(UIDropDownMenu_SetText) == "function" then
        for _, dropdown in pairs(dropdowns) do
            pcall(UIDropDownMenu_SetText, dropdown, "Select Font")
        end
    end

    if type(key) == "string" and key ~= "" then
        path, grp, fname = Fonts.ResolveKey(key)
        if fname then
            label = (grp == "Custom") and Fonts.StripExtension(fname) or DisplayNameForFont(fname)
            isDef = false
            if dropdowns[grp] and type(UIDropDownMenu_SetText) == "function" then
                pcall(UIDropDownMenu_SetText, dropdowns[grp], label)
            end
            if dropdowns.Favorites and IsFavorite(key)
                and type(UIDropDownMenu_SetText) == "function" then
                pcall(UIDropDownMenu_SetText, dropdowns.Favorites, label)
            end
        end
    end

    if type(path) ~= "string" or path == "" then
        CombatFont:CaptureDefaults()
        path = CombatFont:GetDefaultPath()
        label, isDef = "Default", true
    end

    if SetPreviewFont then
        SetPreviewFont(GameFontNormalLarge or (preview.GetFontObject and preview:GetFontObject()), path)
    end
    if UpdatePreviewHeaderText then
        UpdatePreviewHeaderText(label, path, isDef)
    end
    if preview.SetText and editBox.GetText then
        preview:SetText(editBox:GetText() or "")
    end
end

frame:SetScript("OnHide", function()
    -- Close any open FontMagic dropdown list immediately when the window hides.
    if type(CloseDropDownMenus) == "function" then
        pcall(CloseDropDownMenus)
    end
    if frame.__fmMenuCtx then
        if type(frame.__fmMenuCtx.HideHoverPreview) == "function" then
            frame.__fmMenuCtx.HideHoverPreview()
        end
        if type(frame.__fmMenuCtx.CleanupTouchedMenuButtons) == "function" then
            frame.__fmMenuCtx.CleanupTouchedMenuButtons()
        end
        if type(frame.__fmMenuCtx.StopIdleWatcher) == "function" then
            frame.__fmMenuCtx.StopIdleWatcher()
        end
    end

    pendingFont = nil
    -- Cancel any queued sizing pass that was scheduled by a previewed font.
    __fmPreviewToken = (__fmPreviewToken or 0) + 1

    if frame.__fmResetDialog and frame.__fmResetDialog.Hide then
        frame.__fmResetDialog:Hide()
    end

    -- Put the preview back to the actually applied font so reopening is consistent.
    pcall(SyncPreviewToAppliedFont)
end)
-- 7) COMBAT TEXT OPTIONS (EXPANDABLE PANEL) --------------------------------

-- Right-side expandable panel
local isExpanded = false
local RIGHT_PANEL_W = PREVIEW_W + 26
local PANEL_GAP = 16
local incomingInit = false
local originalInfo

-- Collapsible combat text options button (integrated label + arrow for a cleaner look)
local expandBtn = CreateFrame("Button", addonName .. "ExpandBtn", frame, "UIPanelButtonTemplate")
expandBtn:SetSize(260, 24)
expandBtn:SetPoint("BOTTOMRIGHT", (frame.__fmLeftAnchor or frame), "BOTTOMRIGHT", -16, 44)

local function UpdateExpandToggleText()
    local txt = isExpanded and "Hide Combat Text Options <" or "Show Combat Text Options >"
    if expandBtn and expandBtn.SetText then
        expandBtn:SetText(txt)
    end
    -- If the tooltip is currently shown for this button, update immediately.
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == expandBtn then
        GameTooltip:SetText(txt, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

UpdateExpandToggleText()

expandBtn:SetFrameStrata("HIGH")
expandBtn:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
expandBtn:SetScript("OnEnter", function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(isExpanded and "Combat Text Options <" or "Combat Text Options >", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end)
expandBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

-- Container + scroll area (hidden when collapsed)
local combatPanel = CreateFrame("Frame", addonName .. "CombatPanel", frame, Compat.BackdropTemplate)
combatPanel:ClearAllPoints()
combatPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", PANEL_GAP, -HEADER_H)
combatPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", PANEL_GAP, 80) -- leave room for the expand toggle above Close
combatPanel:SetWidth(RIGHT_PANEL_W)
combatPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
-- Darker/less translucent so the list remains readable over bright scenes.
combatPanel:SetBackdropColor(0, 0, 0, 0.92)
combatPanel:SetFrameStrata("HIGH")
combatPanel:SetFrameLevel((frame:GetFrameLevel() or 0) + 40)
combatPanel:Hide()


local combatPopShadow = frame:CreateTexture(nil, "BACKGROUND")
combatPopShadow:SetPoint("TOPLEFT", combatPanel, "TOPLEFT", -PANEL_GAP, 0)
combatPopShadow:SetPoint("BOTTOMLEFT", combatPanel, "BOTTOMLEFT", -PANEL_GAP, 0)
combatPopShadow:SetWidth(PANEL_GAP)
combatPopShadow:SetColorTexture(0, 0, 0, 0.25)
combatPopShadow:Hide()

local combatDivider = combatPanel:CreateTexture(nil, "ARTWORK")
combatDivider:SetPoint("TOPLEFT", combatPanel, "TOPLEFT", 0, 0)
combatDivider:SetPoint("BOTTOMLEFT", combatPanel, "BOTTOMLEFT", 0, 0)
combatDivider:SetWidth(1)
combatDivider:SetColorTexture(1, 1, 1, 0.12)


local combatTitle = combatPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
combatTitle:SetPoint("TOPLEFT", combatPanel, "TOPLEFT", 10, -8)
combatTitle:SetText("Combat Text Options")


local combatScroll = CreateFrame("ScrollFrame", addonName .. "CombatScroll", combatPanel, "UIPanelScrollFrameTemplate")
combatScroll:SetPoint("TOPLEFT", combatPanel, "TOPLEFT", 8, -30)
combatScroll:SetPoint("BOTTOMRIGHT", combatPanel, "BOTTOMRIGHT", -26, 10)

local combatContent = CreateFrame("Frame", nil, combatScroll)
combatContent:SetPoint("TOPLEFT", 0, 0)
combatContent:SetSize(PREVIEW_W, 1)
combatScroll:SetScrollChild(combatContent)

combatScroll:EnableMouseWheel(true)
combatScroll:SetScript("OnMouseWheel", function(self, delta)
    local step = 40
    local newOffset = self:GetVerticalScroll() - delta * step
    if newOffset < 0 then newOffset = 0 end
    local max = self:GetVerticalScrollRange()
    if newOffset > max then newOffset = max end
    self:SetVerticalScroll(newOffset)
end)

-- ---------------------------------------------------------------------------
-- Combat text toggle definitions
-- ---------------------------------------------------------------------------

local function MakeCVarCandidates(primary, ...)
    local t = { primary }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v and v ~= "" then table.insert(t, v) end
    end
    if type(primary) == "string" then
        for v = 9, 2, -1 do
            table.insert(t, primary .. "_v" .. v)
            table.insert(t, primary .. "_V" .. v)
        end
    end
    return t
end

local COMBAT_BOOL_DEFS = {
    -- Core
    { key="enableFloatingCombatText",  candidates={ "enableFloatingCombatText", "enableCombatText" },
      label="Show combat text",
      tip="Turns Blizzard\'s floating combat text on or off (numbers and messages shown in the world).\n\nThis does not affect the combat log." },

    -- Outgoing (numbers shown over enemies / targets)
    { key="combatDamage",             candidates=MakeCVarCandidates("floatingCombatTextCombatDamage"),
      label="Outgoing Damage",
      tip="Shows damage numbers over hostile targets when you deal damage." },

    { key="combatHealing",            candidates=MakeCVarCandidates("floatingCombatTextCombatHealing"),
      label="Outgoing Healing",
      tip="Shows healing numbers over the target when you heal them." },

    { key="combatHealingAbsorbSelf",  candidates=MakeCVarCandidates("floatingCombatTextCombatHealingAbsorbSelf"),
      label="Shields (On You)",
      tip="Shows a message when you gain an absorb shield (e.g., Power Word: Shield)." },

    { key="combatHealingAbsorbTarget", candidates=MakeCVarCandidates("floatingCombatTextCombatHealingAbsorbTarget"),
      label="Shields (On Target)",
      tip="Shows the amount of absorb shield you apply to your target." },

    { key="periodicDamage",           candidates={ "floatingCombatTextCombatLogPeriodicSpells", "floatingCombatTextPeriodicDamage" },
      label="Periodic Damage",
      tip="Shows damage from periodic effects (DoTs) like Rend or Shadow Word: Pain." },

    { key="petDamage",                candidates={ "floatingCombatTextPetMeleeDamage", "floatingCombatTextPetDamage" },
      label="Pet Damage (Melee)",
      tip="Shows damage caused by your pet\'s melee attacks." },

    { key="petSpellDamage",           candidates=MakeCVarCandidates("floatingCombatTextPetSpellDamage"),
      label="Pet Damage (Spells)",
      tip="Shows damage caused by your pet\'s spells and special abilities." },

    -- Defensive / informational
    { key="dodgeParryMiss",           candidates=MakeCVarCandidates("floatingCombatTextDodgeParryMiss"),
      label="Avoidance (Dodge/Parry/Miss)",
      tip="Shows when attacks against you are dodged, parried, or miss." },

    { key="damageReduction",          candidates=MakeCVarCandidates("floatingCombatTextDamageReduction"),
      label="Damage Reduction (Resists)",
      tip="Shows when you resist taking damage from attacks or spells." },

    { key="reactives",                candidates=MakeCVarCandidates("floatingCombatTextReactives"),
      label="Spell Alerts",
      tip="Shows alerts when certain important events occur.\n\n(If you already use a modern proc-alert system, this may be redundant.)" },

    { key="combatState",              candidates=MakeCVarCandidates("floatingCombatTextCombatState"),
      label="Enter/Leave Combat",
      tip="Shows a message when you enter or leave combat." },

    { key="lowManaHealth",            candidates=MakeCVarCandidates("floatingCombatTextLowManaHealth"),
      label="Low Mana & Health",
      tip="Shows a warning when you fall below 20% mana or health." },

    { key="energyGains",              candidates=MakeCVarCandidates("floatingCombatTextEnergyGains"),
      label="Resource Gains",
      tip="Shows instant gains of resources like mana, rage, energy, chi, and similar." },

    { key="periodicEnergyGains",      candidates=MakeCVarCandidates("floatingCombatTextPeriodicEnergyGains"),
      label="Periodic Resource Gains",
      tip="Shows periodic (regen/tick) gains of resources like mana, rage, and energy." },

    { key="honorGains",               candidates=MakeCVarCandidates("floatingCombatTextHonorGains"),
      label="Honor Gains",
      tip="Shows the honor you gain from killing other players." },

    { key="repChanges",               candidates=MakeCVarCandidates("floatingCombatTextRepChanges"),
      label="Reputation Changes",
      tip="Shows a message when you gain or lose reputation with a faction." },

    { key="comboPoints",              candidates=MakeCVarCandidates("floatingCombatTextComboPoints"),
      label="Combo Points",
      tip="Shows your current combo point count each time you gain a combo point." },

    { key="auras",                    candidates=MakeCVarCandidates("floatingCombatTextAuras"),
      label="Auras Gained/Lost",
      tip="Shows a message when you gain or lose a buff or debuff." },

    { key="friendlyHealers",          candidates=MakeCVarCandidates("floatingCombatTextFriendlyHealers"),
      label="Friendly Healer Names",
      tip="Shows the name of a friendly caster when they heal you." },

    { key="spellMechanics",           candidates=MakeCVarCandidates("floatingCombatTextSpellMechanics"),
      label="Effects (On Your Target)",
      tip="Displays effect messages (e.g., Silence and Snare) on your current target." },

    { key="spellMechanicsOther",      candidates=MakeCVarCandidates("floatingCombatTextSpellMechanicsOther"),
      label="Effects (Other Players\' Targets)",
      tip="Displays effect messages (e.g., Silence and Snare) on other players\' targets.\n\nThis can add a lot of extra text in groups/raids." },

    { key="allSpellMechanics",        candidates=MakeCVarCandidates("floatingCombatTextAllSpellMechanics"),
      label="Effects (All)",
      tip="Shows all available effect messages related to spell mechanics.\n\nIf you\'re seeing duplicates, disable this and use the more specific Effects options instead." },
}

local DEF_BY_KEY = {}
for _, d in ipairs(COMBAT_BOOL_DEFS) do DEF_BY_KEY[d.key] = d end

-- extra boolean CVars that match floatingCombatText* but aren't in our curated list
local EXTRA_CVAR_PREFIX = "floatingCombatText"
local EXTRA_BLACKLIST = {
    -- curated / already exposed (avoid duplicates)
    enableFloatingCombatText = true,
    enableCombatText = true,

    floatingCombatTextCombatDamage = true,
    floatingCombatTextCombatHealing = true,
    floatingCombatTextCombatHealingAbsorbSelf = true,
    floatingCombatTextCombatHealingAbsorbTarget = true,

    floatingCombatTextCombatLogPeriodicSpells = true,
    floatingCombatTextPeriodicDamage = true,

    floatingCombatTextPetMeleeDamage = true,
    floatingCombatTextPetDamage = true,
    floatingCombatTextPetSpellDamage = true,

    floatingCombatTextDodgeParryMiss = true,
    floatingCombatTextDamageReduction = true,
    floatingCombatTextReactives = true,
    floatingCombatTextCombatState = true,
    floatingCombatTextLowManaHealth = true,
    floatingCombatTextEnergyGains = true,
    floatingCombatTextPeriodicEnergyGains = true,
    floatingCombatTextHonorGains = true,
    floatingCombatTextRepChanges = true,
    floatingCombatTextComboPoints = true,
    floatingCombatTextAuras = true,
    floatingCombatTextFriendlyHealers = true,
    floatingCombatTextSpellMechanics = true,
    floatingCombatTextSpellMechanicsOther = true,
    floatingCombatTextAllSpellMechanics = true,

    -- known non-useful / off-topic for this add-on
    floatingCombatTextCombatDamageStyle = true, -- no longer used in modern clients
    enablePetBattleCombatText = true,
    enablePetBattleFloatingCombatText = true,
}

-- Forward declaration so earlier functions can call this helper before its definition below.
local CollectExtraBoolCombatTextCVars

local function PrettyCVarLabel(cvar)
    local s = tostring(cvar or "")
    -- Hide internal version suffixes like _v2/_v3 from user-facing labels.
    s = s:gsub("_[vV]%d+$", "")
    s = s:gsub("^floatingCombatText", "")
    s = s:gsub("([A-Z])", " %1")
    s = s:gsub("_", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%s+", " ")
    if s == "" then s = tostring(cvar) end
    return s
end

-- Human-readable explanations for extra floatingCombatText* CVars (advanced section).
-- These are not guaranteed to exist on every WoW client; anything unmapped will fall back to a generic explanation.
local EXTRA_CVAR_EXPLANATIONS = {
    floatingCombatTextDodgeParryMiss      = "Shows Dodge / Parry / Miss messages as floating combat text.",
    floatingCombatTextDamageReduction     = "Shows absorbs, blocks, resists, and other damage reduction messages as floating combat text.",
    floatingCombatTextReactives           = "Shows reactive proc messages (for example: 'Overpower!' / 'Revenge!') as floating combat text (when supported).",
    floatingCombatTextCombatState         = "Shows combat state notifications (entering/leaving combat) as floating combat text.",
    floatingCombatTextLowManaHealth       = "Shows low health/mana warnings as floating combat text.",
    floatingCombatTextEnergyGains         = "Shows resource gains (mana/rage/energy/runic power, etc.) as floating combat text.",
    floatingCombatTextPeriodicEnergyGains = "Shows periodic resource gains (from buffs/regen) as floating combat text.",
    floatingCombatTextHonorGains          = "Shows honor gains as floating combat text (when supported).",
    floatingCombatTextRepChanges          = "Shows reputation changes as floating combat text (when supported).",
    floatingCombatTextComboPoints         = "Shows combo point changes as floating combat text (when supported).",
    floatingCombatTextAuras               = "Shows aura notifications (gains/fades) as floating combat text (when supported).",
    floatingCombatTextFriendlyHealers     = "Shows friendly healer messages as floating combat text (when supported).",
    floatingCombatTextSpellMechanics      = "Shows spell mechanic messages (like 'Interrupted', 'Immune', 'Dispelled') as floating combat text (when supported).",
    floatingCombatTextSpellMechanicsOther = "Shows additional spell mechanic messages as floating combat text (when supported).",
    floatingCombatTextAllSpellMechanics   = "Shows a broader set of spell mechanic messages as floating combat text (when supported).",
}

local function GetExtraCombatTextCVarTooltip(cvar)
    local name = tostring(cvar or "")
    local base = name:gsub("_[vV]%d+$", "")
    local expl = EXTRA_CVAR_EXPLANATIONS[name] or EXTRA_CVAR_EXPLANATIONS[base]

    if not expl then
        local pretty = PrettyCVarLabel(base)
        if pretty and pretty ~= "" then
            expl = "Advanced combat text option detected on this client: toggles \"" .. pretty .. "\"."
        else
            expl = "Advanced combat text option detected on this client."
        end
    end

    expl = expl .. "\n\nAvailability and behavior vary by WoW version and UI mods. If you're unsure, leave this at Blizzard's default."
    if name ~= "" then
        expl = expl .. "\n\nTechnical name: " .. name
    end
    return expl
end


local function GetLiveBoolCVar(name)
    local v = CVars.GetString(name)
    if v == nil then return nil end
    local n = tonumber(v)
    if n ~= nil then return n == 1 end
    v = tostring(v):lower()
    return (v == "1" or v == "true" or v == "on")
end

local function AttachTooltip(widget, header, body)
    if not GameTooltip then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(header or "", 1, 1, 1, 1, true)
        if body and body ~= "" then
            GameTooltip:AddLine(body, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Incoming damage/healing toggles (implemented via Blizzard's combat-text type table).
local function EnsureIncomingReady()
    if incomingInit and type(Compat.GetCombatTextTypeInfo()) == "table" then return true end

    -- Try to load Blizzard_CombatText on clients that ship it load-on-demand.
    if type(Compat.LoadAddOn) == "function" then
        pcall(Compat.LoadAddOn, "Blizzard_CombatText")
    end

    local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
    if type(combatTextTypeInfo) ~= "table" then
        return false
    end

    incomingInit = true

    -- capture Blizzard's baseline tables so we can restore after temporary overrides
    originalInfo = originalInfo or {}
    for k, v in pairs(combatTextTypeInfo) do
        originalInfo[k] = v
    end
    originalInfo.PERIODIC_HEAL      = combatTextTypeInfo.PERIODIC_HEAL
    originalInfo.PERIODIC_HEAL_CRIT = combatTextTypeInfo.PERIODIC_HEAL_CRIT

    return true
end

_G.FontMagicCombatTextFix = _G.FontMagicCombatTextFix or {}
_G.FontMagicCombatTextFix.incomingKeys = _G.FontMagicCombatTextFix.incomingKeys or {
    damage = { "DAMAGE", "DAMAGE_CRIT", "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT" },
    healing = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT" },
}

function _G.FontMagicCombatTextFix:SetIncomingGroupEnabled(group, enabled, manageOwnership)
    local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
    local keys = self.incomingKeys and self.incomingKeys[group]
    if type(combatTextTypeInfo) ~= "table" or type(keys) ~= "table" then return false end

    self.incomingRuntimeBackups = self.incomingRuntimeBackups or {}
    local backup = self.incomingRuntimeBackups[group]
    local function capture(origin)
        if backup then return backup end
        backup = { origin = origin, entries = {} }
        for _, key in ipairs(keys) do
            local value = combatTextTypeInfo[key]
            backup.entries[key] = { present = value ~= nil, value = value }
        end
        self.incomingRuntimeBackups[group] = backup
        return backup
    end

    if not enabled then
        if manageOwnership then capture("disable") end
        for _, key in ipairs(keys) do combatTextTypeInfo[key] = nil end
        return true
    end

    if manageOwnership and backup and backup.origin == "disable" then
        for _, key in ipairs(keys) do
            local entry = backup.entries and backup.entries[key]
            combatTextTypeInfo[key] = entry and entry.present and entry.value or nil
        end
        self.incomingRuntimeBackups[group] = nil
        return true
    end

    local needsMutation = false
    for _, key in ipairs(keys) do
        if combatTextTypeInfo[key] == nil and originalInfo and originalInfo[key] ~= nil then
            needsMutation = true
            break
        end
    end
    if manageOwnership and needsMutation then capture("enable") end
    for _, key in ipairs(keys) do
        if combatTextTypeInfo[key] == nil and originalInfo then
            combatTextTypeInfo[key] = originalInfo[key]
        end
    end
    return true
end

function _G.FontMagicCombatTextFix:ReleaseIncomingOverrideOwnership()
    local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
    if type(combatTextTypeInfo) ~= "table" then return false end
    local backups = self.incomingRuntimeBackups
    local releasedGroups = {}
    if type(backups) ~= "table" then return true, releasedGroups end
    for group, backup in pairs(backups) do
        local keys = self.incomingKeys and self.incomingKeys[group]
        if type(keys) == "table" and type(backup) == "table" then
            for _, key in ipairs(keys) do
                local entry = backup.entries and backup.entries[key]
                combatTextTypeInfo[key] = entry and entry.present and entry.value or nil
            end
            releasedGroups[group] = true
        end
        backups[group] = nil
    end
    return true, releasedGroups
end

local function SetIncomingDamageEnabled(enabled, manageOwnership)
    if not EnsureIncomingReady() then return end
    if manageOwnership == nil then manageOwnership = true end
    return _G.FontMagicCombatTextFix:SetIncomingGroupEnabled("damage", enabled, manageOwnership == true)
end

local function SetIncomingHealingEnabled(enabled, manageOwnership)
    if not EnsureIncomingReady() then return end
    if manageOwnership == nil then manageOwnership = true end
    return _G.FontMagicCombatTextFix:SetIncomingGroupEnabled("healing", enabled, manageOwnership == true)
end

local function ApplyIncomingOverrides()
    if type(FontMagicDB) ~= "table" or type(FontMagicDB.incomingOverrides) ~= "table" then return end
    if not EnsureIncomingReady() then return end

    if FontMagicDB.incomingOverrides.incomingDamage ~= nil then
        SetIncomingDamageEnabled(FontMagicDB.incomingOverrides.incomingDamage and true or false, true)
    end
    if FontMagicDB.incomingOverrides.incomingHealing ~= nil then
        SetIncomingHealingEnabled(FontMagicDB.incomingOverrides.incomingHealing and true or false, true)
    end
end

local function ApplyCombatOverrides()
    local applyAtomic = CVars.ApplyAtomicWithRecovery or CVars.ApplyAtomic
    if type(FontMagicDB) == "table" and type(FontMagicDB.combatOverrides) == "table" then
        for key, val in pairs(FontMagicDB.combatOverrides) do
            local def = DEF_BY_KEY[key]
            if def then
                applyAtomic(CVars.ResolveTargets(def.candidates), val and "1" or "0")
            end
        end
    end

    if type(FontMagicDB) == "table" and type(FontMagicDB.extraCombatOverrides) == "table" then
        for cvar, val in pairs(FontMagicDB.extraCombatOverrides) do
            if FM.Database.IsCombatTextCVarName(cvar) then
                applyAtomic(CVars.ResolveTargets(cvar), val and "1" or "0")
            else
                FontMagicDB.extraCombatOverrides[cvar] = nil
            end
        end
    end
end



-- Best-effort: raise Blizzard floating combat text above nameplates.
-- This is not a CVar; it adjusts frame strata/level at runtime and restores it when disabled.
local combatTextLayerBackup = setmetatable({}, { __mode = "k" })

local function VisitCombatTextFrames(root, callback)
    if not (root and callback) then return end

    local seen = {}
    local maxDepth = 5

    local function visit(frameObj, depth)
        if depth > maxDepth or not Compat.CanInspectObject(frameObj) or seen[frameObj] then return end
        seen[frameObj] = true
        callback(frameObj)

        if type(frameObj.GetChildren) == "function" then
            local okChildren, children = pcall(function() return { frameObj:GetChildren() } end)
            if okChildren and type(children) == "table" then
                for _, child in ipairs(children) do
                    visit(child, depth + 1)
                end
            end
        end
    end

    visit(root, 0)
end

local function ApplyCombatTextAboveNameplatesNow(want)
    if not want then
        -- Restore the exact objects FontMagic changed, including frames Blizzard
        -- has since detached or replaced and which are no longer discoverable by
        -- walking today's combat-text roots.
        local owned = {}
        for frameObj, backup in pairs(combatTextLayerBackup) do
            owned[#owned + 1] = { frame = frameObj, backup = backup }
        end
        for _, entry in ipairs(owned) do
            local frameObj, backup = entry.frame, entry.backup
            if Compat.CanInspectObject(frameObj) then
                local restored = true
                if backup.strata and type(frameObj.SetFrameStrata) == "function" then
                    restored = pcall(frameObj.SetFrameStrata, frameObj, backup.strata) and restored
                end
                if backup.level ~= nil and type(frameObj.SetFrameLevel) == "function" then
                    restored = pcall(frameObj.SetFrameLevel, frameObj, backup.level) and restored
                end
                if restored then combatTextLayerBackup[frameObj] = nil end
            end
        end
        return
    end

    local names = { "CombatText", "CombatTextFrame", "FloatingCombatTextFrame" }

    for _, n in ipairs(names) do
        local f = _G and _G[n]
        VisitCombatTextFrames(f, function(frameObj)
            if type(frameObj.SetFrameStrata) ~= "function" then return end

            local okS, strata = pcall(frameObj.GetFrameStrata, frameObj)
            local okL, level = pcall(frameObj.GetFrameLevel, frameObj)
            if not okS or not okL or Compat.IsSecretValue(strata) or Compat.IsSecretValue(level)
                or type(strata) ~= "string" or type(level) ~= "number" then return end
            if not combatTextLayerBackup[frameObj] then
                combatTextLayerBackup[frameObj] = { strata = strata, level = level }
            end

            -- Put combat text above most nameplate add-ons (best-effort) while
            -- preserving relative ordering between nested combat-text frames.
            pcall(frameObj.SetFrameStrata, frameObj, "TOOLTIP")
            if type(frameObj.SetFrameLevel) == "function" and type(frameObj.GetFrameLevel) == "function" then
                if level < 10000 then
                    pcall(frameObj.SetFrameLevel, frameObj, 10000 + level)
                end
            end
        end)
    end
end

local function ApplyCombatTextAboveNameplates(enabled)
    local want = (enabled and true or false)
    if want and _G.FontMagicCombatTextFix
        and type(_G.FontMagicCombatTextFix.EnsureCombatTextPatches) == "function" then
        pcall(_G.FontMagicCombatTextFix.EnsureCombatTextPatches, _G.FontMagicCombatTextFix)
    end
    ApplyCombatTextAboveNameplatesNow(want)

    -- Some nameplate add-ons (and Blizzard nameplates) adjust strata after load.
    -- Re-apply shortly after enabling so combat text reliably stays in front.
    if want and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0.2, function()
            if FontMagicDB and FontMagicDB.combatTextAboveNameplates then
                ApplyCombatTextAboveNameplatesNow(true)
            end
        end)
        C_Timer.After(1.0, function()
            if FontMagicDB and FontMagicDB.combatTextAboveNameplates then
                ApplyCombatTextAboveNameplatesNow(true)
            end
        end)
    end
end

function _G.FontMagicCombatTextFix:ApplyCombatTextAboveNameplatesNow()
    local now = type(GetTime) == "function" and GetTime() or 0
    local last = tonumber(self.lastLayerReconcile) or 0
    if now > 0 and (now - last) < 0.5 then return end
    self.lastLayerReconcile = now
    ApplyCombatTextAboveNameplatesNow(true)
end

-- ---------------------------------------------------------------------------
-- Combat text master toggle (Show/Hide combat text without losing per-type settings)
-- ---------------------------------------------------------------------------

local function GetCombatTextMasterSettingList()
    -- Returns a list of settings we can toggle for the "Show combat text" master checkbox.
    -- Only readable CVars are eligible. Opaque console commands have no generic
    -- value API, so changing them would make exact restoration impossible.
    local list, seen = {}, {}

    local function addSetting(name, commandType)
        if not name or commandType == nil then return end
        if seen[name] then return end
        -- The master switch promises lossless restoration. Never toggle an
        -- opaque console command whose current value cannot be captured.
        if CVars.GetCurrent(name) == nil then return end
        seen[name] = true
        table.insert(list, { name = name, ct = commandType })
    end

    for _, def in ipairs(COMBAT_BOOL_DEFS) do
        for _, target in ipairs(CVars.ResolveTargets(def.candidates)) do
            if target.name and target.commandType == 0 then
                addSetting(target.name, target.commandType)
            end
        end
    end

    local extras = CollectExtraBoolCombatTextCVars()
    for _, cvar in ipairs(extras) do
        for _, target in ipairs(CVars.ResolveTargets(cvar)) do
            if target.name and target.commandType == 0 then
                addSetting(target.name, target.commandType)
            end
        end
    end

    return list
end

local function IsCombatTextMasterSupported()
    if EnsureIncomingReady() then
        return true
    end
    local list = GetCombatTextMasterSettingList()
    return (#list > 0)
end

local function IsCombatTextMasterCurrentlyEnabled()
    -- If FontMagic hid combat text via the master toggle, reflect that immediately.
    if FontMagicDB and FontMagicDB.combatMasterOffByFontMagic
        and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
        return false
    end

    local sawAny = false

    -- Some clients use enableFloatingCombatText while others use enableCombatText.
    -- A readable master gate is authoritative: per-type preferences can remain
    -- enabled while the master gate is off, and must not make the UI look enabled.
    do
        local gateDef = DEF_BY_KEY and DEF_BY_KEY["enableFloatingCombatText"]
        local candidates = (gateDef and gateDef.candidates) or MakeCVarCandidates("enableFloatingCombatText", "enableCombatText")
        for _, target in ipairs(CVars.ResolveTargets(candidates)) do
            if target.name and target.commandType == 0 then
                local value = GetLiveBoolCVar(target.name)
                if value ~= nil then
                    return value and true or false
                end
            end
        end
    end

    -- If any readable combat text toggle is on, we consider combat text enabled.
    for _, entry in ipairs(GetCombatTextMasterSettingList()) do
        if entry and entry.ct == 0 and entry.name then
            local v = GetLiveBoolCVar(entry.name)
            if v ~= nil then
                sawAny = true
            end
            if v == true then
                return true
            end
        end
    end

    -- Incoming combat text can be implemented via Blizzard's type table.
    local combatTextTypeInfo = EnsureIncomingReady() and Compat.GetCombatTextTypeInfo() or nil
    if type(combatTextTypeInfo) == "table" then
        sawAny = true
        local dmgEnabled = (combatTextTypeInfo.DAMAGE ~= nil or combatTextTypeInfo.SPELL_DAMAGE ~= nil)
        local healEnabled = (combatTextTypeInfo.HEAL ~= nil or combatTextTypeInfo.PERIODIC_HEAL ~= nil)
        if dmgEnabled or healEnabled then
            return true
        end
    end

    -- If no values are reportable yet (or we only have non-readable console commands),
    -- default to enabled so the UI doesn't show an unchecked box while combat text is visible.
    if not sawAny then
        return true
    end

    return false
end

local function CaptureCombatTextMasterSnapshot(purpose)
    FontMagicDB = FontMagicDB or {}
    local snap = { cvars = {}, commandTypes = {}, incoming = {} }

    for _, entry in ipairs(GetCombatTextMasterSettingList()) do
        if entry and entry.name then
            local val = CVars.GetCurrent(entry.name)

            snap.cvars[entry.name] = val
            snap.commandTypes[entry.name] = entry.ct
        end
    end

    local combatTextTypeInfo = EnsureIncomingReady() and Compat.GetCombatTextTypeInfo() or nil
    if type(combatTextTypeInfo) == "table" then
        local keys = {
            "DAMAGE", "DAMAGE_CRIT", "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT",
            "HEAL", "HEAL_CRIT", "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT",
        }
        snap.incoming.entries = {}
        local runtime = {}
        for _, key in ipairs(keys) do
            local value = combatTextTypeInfo[key]
            snap.incoming.entries[key] = value ~= nil
            runtime[key] = { present = value ~= nil, value = value }
        end
        if _G.FontMagicCombatTextFix then
            _G.FontMagicCombatTextFix.masterRuntimeIncomingSnapshot = runtime
        end
    end

    FontMagicDB.combatMasterSnapshot = snap
    FontMagicDB.combatMasterSnapshotPurpose = purpose
end

local function ApplyCombatTextMasterDisabled()
    local succeeded = true
    local snap = FontMagicDB and FontMagicDB.combatMasterSnapshot
    local captured = type(snap) == "table" and type(snap.cvars) == "table" and snap.cvars or nil
    for _, entry in ipairs(GetCombatTextMasterSettingList()) do
        -- Only change settings whose exact current value was captured. Console
        -- commands without readable state cannot be restored losslessly.
        if entry and entry.name and captured and captured[entry.name] ~= nil then
            succeeded = CVars.Apply(entry.name, entry.ct, "0") and succeeded
        end
    end

    if EnsureIncomingReady() then
        SetIncomingDamageEnabled(false, false)
        SetIncomingHealingEnabled(false, false)
    end
    return succeeded
end

local function ApplyCombatTextMasterEnabledFromSnapshot(snap)
    if type(snap) ~= "table" or type(snap.cvars) ~= "table" then
        return false
    end

    local appliedAny, allSucceeded = false, true

    for name, val in pairs(snap.cvars) do
        if val ~= nil and FM.Database.IsCombatTextCVarName(name) then
            local n, ct = name, nil
            if type(snap.commandTypes) == "table" then
                ct = snap.commandTypes[name]
                if ct ~= nil then
                    local exactName, exactCt = _G.FontMagicConsoleResolver:TryName(name)
                    if exactName then
                        n, ct = exactName, exactCt
                    else
                        n, ct = nil, nil
                    end
                end
            end
            if ct == nil then
                n, ct = _G.FontMagicConsoleResolver:TryName(name)
            end
            if not n or ct == nil then
                n, ct = CVars.Resolve(name)
            end
            if n and ct ~= nil then
                allSucceeded = CVars.Apply(n, ct, tostring(val)) and allSucceeded
                appliedAny = true
            else
                allSucceeded = false
            end
        end
    end

    if EnsureIncomingReady() and type(snap.incoming) == "table" and type(snap.incoming.entries) == "table" then
        local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
        local runtime = _G.FontMagicCombatTextFix and _G.FontMagicCombatTextFix.masterRuntimeIncomingSnapshot
        if type(combatTextTypeInfo) == "table" then
            for key, present in pairs(snap.incoming.entries) do
                local runtimeEntry = type(runtime) == "table" and runtime[key] or nil
                if type(runtimeEntry) == "table" and runtimeEntry.present == (present and true or false) then
                    combatTextTypeInfo[key] = runtimeEntry.present and runtimeEntry.value or nil
                else
                    combatTextTypeInfo[key] = present and originalInfo[key] or nil
                end
            end
            appliedAny = true
        end
    end

    if allSucceeded and _G.FontMagicCombatTextFix then
        _G.FontMagicCombatTextFix.masterRuntimeIncomingSnapshot = nil
    end
    return appliedAny and allSucceeded
end

local function ApplyCombatTextMasterEnabledBaseline()
    local succeeded = true
    -- Best-effort baseline so "Show combat text" actually shows something on most clients.
    do
        local gateDef = DEF_BY_KEY and DEF_BY_KEY["enableFloatingCombatText"]
        local candidates = (gateDef and gateDef.candidates) or MakeCVarCandidates("enableFloatingCombatText", "enableCombatText")
        for _, target in ipairs(CVars.ResolveTargets(candidates)) do
            if target.name and target.commandType == 0 then
                succeeded = CVars.Apply(target.name, target.commandType, "1") and succeeded
            end
        end
    end

    local dmgDef = DEF_BY_KEY and DEF_BY_KEY["combatDamage"]
    if dmgDef then
        for _, target in ipairs(CVars.ResolveTargets(dmgDef.candidates)) do
            if target.name and target.commandType == 0 then
                succeeded = CVars.Apply(target.name, target.commandType, "1") and succeeded
            end
        end
    end

    local healDef = DEF_BY_KEY and DEF_BY_KEY["combatHealing"]
    if healDef then
        for _, target in ipairs(CVars.ResolveTargets(healDef.candidates)) do
            if target.name and target.commandType == 0 then
                succeeded = CVars.Apply(target.name, target.commandType, "1") and succeeded
            end
        end
    end

    if EnsureIncomingReady() then
        SetIncomingDamageEnabled(true, false)
        SetIncomingHealingEnabled(true, false)
    end
    return succeeded
end

local function SetCombatTextMasterEnabled(wantEnabled)
    if not IsCombatTextMasterSupported() then
        return
    end

    FontMagicDB = FontMagicDB or {}

    if wantEnabled then
        local snap = FontMagicDB.combatMasterSnapshot
        local restored
        local baselineAttempt = false
        local hiddenRestoreAttempt = false
        local purpose = FontMagicDB.combatMasterSnapshotPurpose
        if FM.Database.IsValidMasterSnapshot(snap)
            and (FontMagicDB.combatMasterOffByFontMagic or purpose == "hidden") then
            hiddenRestoreAttempt = true
            restored = ApplyCombatTextMasterEnabledFromSnapshot(snap)
        else
            if not (FM.Database.IsValidMasterSnapshot(snap) and purpose == "baselineRollback") then
                FontMagicDB.combatMasterSnapshot = nil
                FontMagicDB.combatMasterSnapshotPurpose = nil
                CaptureCombatTextMasterSnapshot("baselineRollback")
                snap = FontMagicDB.combatMasterSnapshot
            end
            FontMagicDB.combatMasterOffByFontMagic = nil
            baselineAttempt = true
            restored = ApplyCombatTextMasterEnabledBaseline()
        end
        if restored then
            FontMagicDB.combatMasterSnapshot = nil
            FontMagicDB.combatMasterSnapshotPurpose = nil
            FontMagicDB.combatMasterOffByFontMagic = nil
            return true
        end

        if hiddenRestoreAttempt then
            ApplyCombatTextMasterDisabled()
            return false
        end

        -- Baseline enable spans several independent client settings. If one
        -- write is rejected, restore the exact pre-click state so the checkbox
        -- never leaves combat text half enabled.
        if baselineAttempt and FM.Database.IsValidMasterSnapshot(snap)
            and ApplyCombatTextMasterEnabledFromSnapshot(snap) then
            FontMagicDB.combatMasterSnapshot = nil
            FontMagicDB.combatMasterSnapshotPurpose = nil
            FontMagicDB.combatMasterOffByFontMagic = nil
        end
        return false
    else
        if FontMagicDB.combatMasterSnapshotPurpose == "baselineRollback"
            and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
            if ApplyCombatTextMasterEnabledFromSnapshot(FontMagicDB.combatMasterSnapshot) then
                FontMagicDB.combatMasterSnapshot = nil
                FontMagicDB.combatMasterSnapshotPurpose = nil
                FontMagicDB.combatMasterOffByFontMagic = nil
                return true
            end
            return false
        end
        if not FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
            CaptureCombatTextMasterSnapshot("hidden")
        end
        if ApplyCombatTextMasterDisabled() then
            FontMagicDB.combatMasterOffByFontMagic = true
            return true
        end

        -- A partial hide is worse than a failed request. Roll back every write
        -- we can and retain the snapshot only when that rollback itself needs a
        -- retry.
        local snap = FontMagicDB.combatMasterSnapshot
        if ApplyCombatTextMasterEnabledFromSnapshot(snap) then
            FontMagicDB.combatMasterSnapshot = nil
            FontMagicDB.combatMasterSnapshotPurpose = nil
            FontMagicDB.combatMasterOffByFontMagic = nil
        end
        return false
    end
end

local function UpdateMainCombatCheckboxes()
    if mainShowCombatTextCB and mainShowCombatTextCB.SetChecked then
        if not IsCombatTextMasterSupported() then
            if mainShowCombatTextCB.Disable then pcall(mainShowCombatTextCB.Disable, mainShowCombatTextCB) end
            -- If we can't control it on this client, default to showing it as enabled so the
            -- checkbox doesn't look "wrong" on first load.
            mainShowCombatTextCB:SetChecked(IsCombatTextMasterCurrentlyEnabled() and true or false)
        else
            if mainShowCombatTextCB.Enable then pcall(mainShowCombatTextCB.Enable, mainShowCombatTextCB) end
            mainShowCombatTextCB:SetChecked(IsCombatTextMasterCurrentlyEnabled() and true or false)
        end
    end
end

-- ---------------------------------------------------------------------------
-- UI builder
-- ---------------------------------------------------------------------------

local combatWidgets = {}
local combatSliderPool = {}

combatContent.__fmTextPool = combatContent.__fmTextPool or {}
combatContent.__fmAcquireText = function(content, template)
    content.__fmTextPoolCursor = (content.__fmTextPoolCursor or 0) + 1
    local index = content.__fmTextPoolCursor
    local entry = content.__fmTextPool[index]
    if not entry then
        entry = content:CreateFontString(nil, "OVERLAY", template)
        content.__fmTextPool[index] = entry
    else
        entry:Show()
        entry:ClearAllPoints()
        if entry.SetFontObject and _G[template] then
            pcall(entry.SetFontObject, entry, _G[template])
        end
    end
    entry:SetTextColor(1, 1, 1)
    if entry.SetWidth then entry:SetWidth(0) end
    if entry.SetHeight then entry:SetHeight(0) end
    if entry.SetJustifyH then entry:SetJustifyH("LEFT") end
    if entry.SetJustifyV then entry:SetJustifyV("MIDDLE") end
    if entry.SetWordWrap then entry:SetWordWrap(true) end
    return entry
end

local function ClearCombatWidgets()
    for _, w in ipairs(combatWidgets) do
        if w and w.Hide then w:Hide() end
        if w and w.ClearAllPoints then w:ClearAllPoints() end
    end
    combatWidgets = {}
    if combatContent then
        combatContent.__fmCheckboxPoolCursor = 0
        combatContent.__fmTextPoolCursor = 0
    end
end

local function AddHeader(textLine, y)
    local fs = combatContent:__fmAcquireText("GameFontNormal")
    fs:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
    fs:SetPoint("TOPRIGHT", combatContent, "TOPRIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(textLine)
    table.insert(combatWidgets, fs)
    return y - 18
end


local function AddSectionNote(y, textLine)
    local fs = combatContent:__fmAcquireText("GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
    fs:SetPoint("TOPRIGHT", combatContent, "TOPRIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetTextColor(0.72, 0.72, 0.72)
    fs:SetText(textLine)
    table.insert(combatWidgets, fs)
    local h = 0
    if fs.GetStringHeight then
        h = tonumber(fs:GetStringHeight()) or 0
    end
    if h < 18 then h = 18 end
    return y - h - 6
end

local function CreateOptionSlider(y, key, label, minVal, maxVal, step, value, onChange, tip, enabled, disabledHint, liveApply)
    if enabled == nil then enabled = true end
    if liveApply == nil then liveApply = true end

    local fs = combatContent:__fmAcquireText("GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
    fs:SetText(label)
    if not enabled then
        fs:SetTextColor(0.5, 0.5, 0.5)
    end
    table.insert(combatWidgets, fs)

    local valText = combatContent:__fmAcquireText("GameFontHighlightSmall")
    valText:SetPoint("TOPRIGHT", combatContent, "TOPRIGHT", -10, y)
    table.insert(combatWidgets, valText)

    -- Reuse slider frames by key so UI rebuilds never attempt to recreate the same
    -- globally named frame (which would error once the name is already taken).
    local s = combatSliderPool[key]
    if not s then
        s = CreateFrame("Slider", addonName .. "Combat" .. key .. "Slider", combatContent, "OptionsSliderTemplate")
        combatSliderPool[key] = s
    else
        s:SetParent(combatContent)
        s:Show()
    end
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 8, -6)
    s:SetWidth(CB_COL_W * 2 + CHECK_COL_GAP - 30)
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(false)
    s:SetScript("OnValueChanged", nil)
    s:SetScript("OnMouseUp", nil)
    s:SetScript("OnEnter", nil)
    s:SetScript("OnLeave", nil)

    local low = _G[s:GetName() .. "Low"]
    local high = _G[s:GetName() .. "High"]
    if low then
        low:SetText(string.format("%.2f", minVal))
        low:ClearAllPoints()
        low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
    end
    if high then
        high:SetText(string.format("%.2f", maxVal))
        high:ClearAllPoints()
        high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -8, -2)
    end
    local t = s.Text or _G[s:GetName() .. "Text"]
    if t and t.Hide then t:Hide() end

    local function setVal(v)
        local rounded = math.floor((v / step) + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valText:SetText(string.format("%.2f", rounded))
        return rounded
    end

    s:SetScript("OnValueChanged", function(_, v)
        if not enabled then return end
        local rounded = setVal(v)
        if liveApply then
            onChange(rounded)
        end
    end)

    s:EnableMouse(true)
    s:SetScript("OnMouseUp", function(self)
        if not enabled then return end
        local rounded = setVal(self:GetValue())
        self:SetValue(rounded)
        onChange(rounded)
    end)

    s:SetValue(value)
    setVal(value)

    if enabled then
        s:Enable()
        if tip then AttachTooltip(s, label, tip) end
    else
        s:Disable()
        if tip then AttachTooltip(s, label, tip .. "\n\n" .. (disabledHint or "Not available on this client.")) end
    end

    table.insert(combatWidgets, s)
    return s
end

local function CreateOptionCheckbox(col, y, label, checked, onClick, tip)
    local x = (col == 0) and 0 or (CB_COL_W + CHECK_COL_GAP)
    combatContent.__fmCheckboxPool = combatContent.__fmCheckboxPool or {}
    combatContent.__fmCheckboxPoolCursor = (combatContent.__fmCheckboxPoolCursor or 0) + 1

    local poolIndex = combatContent.__fmCheckboxPoolCursor
    local cb = combatContent.__fmCheckboxPool[poolIndex]
    if not cb then
        cb = CreateCheckbox(combatContent, label, 0, 0, checked, onClick, true)
        combatContent.__fmCheckboxPool[poolIndex] = cb
    else
        cb:SetParent(combatContent)
        cb:Show()
        if cb.Enable then pcall(cb.Enable, cb) end
        if cb.EnableMouse then cb:EnableMouse(true) end
        SetCheckButtonLabel(cb, label)
        cb:SetChecked(checked and true or false)
        cb:SetScript("OnClick", onClick)
    end

    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", combatContent, "TOPLEFT", x, y)
    cb:SetScript("OnEnter", nil)
    cb:SetScript("OnLeave", nil)

    -- Constrain the label so the two checkbox columns never overlap.
    local fs = cb and (cb.__fmLabelFS or GetCheckButtonLabelFS(cb))
    if fs then
        -- Use a slightly smaller font so longer labels still fit nicely.
        if fs.SetFontObject and type(GameFontHighlightSmall) ~= "nil" then
            pcall(fs.SetFontObject, fs, GameFontHighlightSmall)
        end
        if fs.SetWidth then fs:SetWidth(CB_COL_W - 26) end
        if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
        if fs.SetWordWrap then fs:SetWordWrap(true) end
    end

    if tip then AttachTooltip(cb, label, tip) end
    table.insert(combatWidgets, cb)
    return cb
end

CollectExtraBoolCombatTextCVars = function()
    -- Collect additional floatingCombatText* boolean CVars that exist on this client
    -- but are not already represented by our curated definitions. We only include
    -- CVars that are real (commandType == 0) and whose current value is clearly
    -- boolean ("0" or "1") so we don't surface unrelated numeric settings.
    --
    -- Some clients expose both a base CVar and a version-suffixed variant (e.g. _v2).
    -- When multiple variants exist for the same base, prefer the highest version.
    local idx = CVars.BuildIndex()
    local chosen = {} -- [baseName] = bestVariantName

    local function baseName(name)
        return (tostring(name or ""):gsub("_[vV]%d+$", ""))
    end

    local function versionNum(name)
        local v = tostring(name or ""):match("_[vV](%d+)$")
        return tonumber(v) or 0
    end

    if type(idx) == "table" then
        for name, ct in pairs(idx) do
            if type(name) == "string"
                and ct == 0
                and name:sub(1, #EXTRA_CVAR_PREFIX) == EXTRA_CVAR_PREFIX
            then
                local base = baseName(name)

                -- If the base CVar is already covered by our curated list, don't surface
                -- any of its variants here either.
                if not EXTRA_BLACKLIST[name] and not EXTRA_BLACKLIST[base] then
                    local v = CVars.GetString(name)
                    if v == "0" or v == "1" then
                        local prev = chosen[base]
                        if not prev then
                            chosen[base] = name
                        else
                            if versionNum(name) > versionNum(prev) then
                                chosen[base] = name
                            end
                        end
                    end
                end
            end
        end
    end

    local extras = {}
    for _, name in pairs(chosen) do
        table.insert(extras, name)
    end
    table.sort(extras)
    return extras
end

local function BuildCombatOptionsUI()
    ClearCombatWidgets()

    local y = 0
    local row = 0

    local function place()
        local col = (row % 2 == 0) and 0 or 1
        local yy = y - math.floor(row / 2) * CHECK_ROW_H
        row = row + 1
        return col, yy
    end

    local masterOff = (FontMagicDB and FontMagicDB.combatMasterOffByFontMagic
        and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot)) and true or false
    local snap = masterOff and FontMagicDB and FontMagicDB.combatMasterSnapshot or nil

    if masterOff then
        y = AddHeader("Note", y - 2)
        local note = combatContent:__fmAcquireText("GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
        note:SetWidth(CB_COL_W * 2 + CHECK_COL_GAP - 10)
        note:SetJustifyH("LEFT")
        note:SetJustifyV("TOP")
        note:SetText("Combat text is currently hidden by the main \"Show combat text\" toggle. Enable it in the main panel to edit these options.")
        table.insert(combatWidgets, note)
        y = y - 26
    end

    y = AddHeader("Combat text visibility", y - 2)
    row = 0

    for _, def in ipairs(COMBAT_BOOL_DEFS) do
        if def.key ~= "enableFloatingCombatText" then
            local n, ct = CVars.Resolve(def.candidates)
            if n and ct == 0 and CVars.GetCurrent(n) ~= nil then
                local override = FontMagicDB.combatOverrides and FontMagicDB.combatOverrides[def.key]
                local live = (ct == 0) and GetLiveBoolCVar(n) or nil
                local checked
                if override ~= nil then
                    checked = override and true or false
                elseif live ~= nil then
                    checked = live and true or false
                else
                    checked = true
                end

                if masterOff and type(snap) == "table" and type(snap.cvars) == "table" and snap.cvars[n] ~= nil then
                    checked = (tonumber(snap.cvars[n]) == 1) and true or false
                end

                local c, yy = place()
                local cb = CreateOptionCheckbox(c, yy, def.label, checked, function(self)
                    local newVal = self:GetChecked() and true or false
                    local applyAtomic = CVars.ApplyAtomicWithRecovery or CVars.ApplyAtomic
                    if applyAtomic(CVars.ResolveTargets(def.candidates), newVal and "1" or "0") then
                        if type(FontMagicDB.combatOverrides) ~= "table" then FontMagicDB.combatOverrides = {} end
                        FontMagicDB.combatOverrides[def.key] = newVal
                    else
                        self:SetChecked(not newVal)
                        FM.UI.ReportRejectedSetting(def.label)
                    end
                end, def.tip)

                if masterOff and cb and cb.Disable then pcall(cb.Disable, cb) end
            end
        end
    end

    y = y - (math.ceil(row / 2) * CHECK_ROW_H) - 10

    if EnsureIncomingReady() then
        y = AddHeader("Incoming message filters", y)

        local combatTextTypeInfo = Compat.GetCombatTextTypeInfo()
        local dmgEnabled = (type(combatTextTypeInfo) == "table") and
            (combatTextTypeInfo.DAMAGE ~= nil or combatTextTypeInfo.SPELL_DAMAGE ~= nil)
        local healEnabled = (type(combatTextTypeInfo) == "table") and
            (combatTextTypeInfo.HEAL ~= nil or combatTextTypeInfo.PERIODIC_HEAL ~= nil)

        local oDmg = FontMagicDB.incomingOverrides and FontMagicDB.incomingOverrides.incomingDamage
        local oHeal = FontMagicDB.incomingOverrides and FontMagicDB.incomingOverrides.incomingHealing

        local showDmg = (oDmg ~= nil) and oDmg or dmgEnabled
        local showHeal = (oHeal ~= nil) and oHeal or healEnabled

        if masterOff and type(snap) == "table" and type(snap.incoming) == "table"
            and type(snap.incoming.entries) == "table" then
            local entries = snap.incoming.entries
            showDmg = entries.DAMAGE or entries.DAMAGE_CRIT or entries.SPELL_DAMAGE or entries.SPELL_DAMAGE_CRIT or false
            showHeal = entries.HEAL or entries.HEAL_CRIT or entries.PERIODIC_HEAL or entries.PERIODIC_HEAL_CRIT or false
        end

        local cb1 = CreateOptionCheckbox(0, y, "Show Incoming Damage", showDmg, function(self)
            local newVal = self:GetChecked() and true or false
            if type(FontMagicDB.incomingOverrides) ~= "table" then FontMagicDB.incomingOverrides = {} end
            FontMagicDB.incomingOverrides.incomingDamage = newVal
            SetIncomingDamageEnabled(newVal, true)
        end, "Shows or hides scrolling combat text for damage you take.\n\n(Only available on clients that load Blizzard_CombatText.)")

        local cb2 = CreateOptionCheckbox(1, y, "Show Incoming Healing", showHeal, function(self)
            local newVal = self:GetChecked() and true or false
            if type(FontMagicDB.incomingOverrides) ~= "table" then FontMagicDB.incomingOverrides = {} end
            FontMagicDB.incomingOverrides.incomingHealing = newVal
            SetIncomingHealingEnabled(newVal, true)
        end, "Shows or hides scrolling combat text for healing you receive.\n\n(Only available on clients that load Blizzard_CombatText.)")

        if masterOff then
            if cb1 and cb1.Disable then pcall(cb1.Disable, cb1) end
            if cb2 and cb2.Disable then pcall(cb2.Disable, cb2) end
        end

        y = y - CHECK_ROW_H - 10
    end

    y = AddHeader("Scrolling text style", y)
    y = AddSectionNote(y, "Affects self/player scrolling combat text. Outgoing world-space numbers above targets may ignore outline changes depending on the WoW client because Blizzard renders them separately.")
    do
        local function outlineLabel(mode)
            local m = tostring(mode or "NONE"):upper()
            if m == "NONE" or m == "NO" or m == "0" then return "No Outline" end
            if m == "THICK" or m == "THICKOUTLINE" or m == "2" then return "Thick Outline" end
            return "Thin Outline"
        end

        local btn = combatContent.__fmOutlineButton
        if not btn then
            btn = CreateFrame("Button", nil, combatContent, "UIPanelButtonTemplate")
            combatContent.__fmOutlineButton = btn
        else
            btn:SetParent(combatContent)
            btn:Show()
            btn:ClearAllPoints()
        end
        btn:SetSize(220, 22)
        btn:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
        btn:SetText("Self Text Outline: " .. outlineLabel(FontMagicDB and FontMagicDB.combatTextOutlineMode))
        btn:SetScript("OnClick", function(self)
            FontMagicDB = FontMagicDB or {}
            local current = tostring(FontMagicDB.combatTextOutlineMode or "NONE"):upper()
            local wasTouched = FontMagicDB.combatTextOutlineTouched
            local nextMode
            if current == "NONE" or current == "NO" or current == "0" then
                nextMode = "OUTLINE"
            elseif current == "OUTLINE" or current == "1" then
                nextMode = "THICKOUTLINE"
            else
                nextMode = "NONE"
            end
            FontMagicDB.combatTextOutlineMode = nextMode
            FontMagicDB.combatTextOutlineTouched = true
            self:SetText("Self Text Outline: " .. outlineLabel(nextMode))

            local applied, committed = CombatFont:ApplySaved()
            if committed == nil then committed = applied end
            if not committed then
                FontMagicDB.combatTextOutlineMode = current
                FontMagicDB.combatTextOutlineTouched = wasTouched
                pcall(CombatFont.ApplySaved, CombatFont)
                self:SetText("Self Text Outline: " .. outlineLabel(current))
                FM.UI.ReportRejectedSetting("self text outline")
            end
        end)
        AttachTooltip(btn, "Self combat text outline style", "Cycles self/player scrolling combat text between No Outline, Thin Outline, and Thick Outline.\n\nThis does not reliably control outgoing world-space damage/healing numbers above targets; many WoW clients render those separately and ignore outline changes from addons.\n\nDoes not touch global number-format CVars.")
        table.insert(combatWidgets, btn)
        y = y - 30
    end

    y = AddHeader("Floating text motion", y)
    y = AddSectionNote(y, "Tune movement behavior for world-space floating numbers. Changes apply immediately when supported.")
    local gravityName, gravityType = CVars.Resolve({ "WorldTextGravity_v2", "WorldTextGravity_V2", "WorldTextGravity", "floatingCombatTextGravity_v2", "floatingCombatTextGravity_V2", "floatingCombatTextGravity" })
    local fadeName, fadeType = CVars.Resolve({ "WorldTextRampDuration_v2", "WorldTextRampDuration_V2", "WorldTextRampDuration", "floatingCombatTextRampDuration_v2", "floatingCombatTextRampDuration_V2", "floatingCombatTextRampDuration" })
    local gravitySupported = gravityName ~= nil and gravityType == 0 and CVars.GetCurrent(gravityName) ~= nil
    local fadeSupported = fadeName ~= nil and fadeType == 0 and CVars.GetCurrent(fadeName) ~= nil

    if not gravitySupported or not fadeSupported then
        local unavailable = combatContent:__fmAcquireText("GameFontHighlightSmall")
        unavailable:SetPoint("TOPLEFT", combatContent, "TOPLEFT", 0, y)
        if not gravitySupported and not fadeSupported then
            unavailable:SetText("These motion controls are unavailable in this game client.")
        elseif not gravitySupported then
            unavailable:SetText("Gravity is unavailable in this game client.")
        else
            unavailable:SetText("Fade timing is unavailable in this game client.")
        end
        unavailable:SetTextColor(0.7, 0.7, 0.7)
        table.insert(combatWidgets, unavailable)
        y = y - 20
    end

    CreateOptionSlider(y, "Gravity", "Motion gravity", 0.00, 2.00, 0.05,
        tonumber(FontMagicDB and FontMagicDB.floatingTextGravity)
            or CVars.GetNumber({ "WorldTextGravity_v2", "WorldTextGravity_V2", "WorldTextGravity", "floatingCombatTextGravity_v2", "floatingCombatTextGravity_V2", "floatingCombatTextGravity" }, 1.0),
        function(v)
            FontMagicDB = FontMagicDB or {}
            local previous = FontMagicDB.floatingTextGravity
            local previousTouched = FontMagicDB.floatingTextGravityTouched
            FontMagicDB.floatingTextGravity = v
            FontMagicDB.floatingTextGravityTouched = true
            if not ApplyFloatingTextMotionSettings("gravity") then
                FontMagicDB.floatingTextGravity = previous
                FontMagicDB.floatingTextGravityTouched = previousTouched
                ApplyFloatingTextMotionSettings("gravity")
                FM.UI.ReportRejectedSetting("floating text gravity")
                __fmRunNextFrame(function()
                    if frame and frame.IsShown and frame:IsShown() then BuildCombatOptionsUI() end
                end)
            end
        end,
        "Controls arc intensity while world-space numbers move upward and settle.",
        gravitySupported,
        nil,
        false
    )

    CreateOptionSlider(y - 54, "Fade", "Fade duration", 0.10, 3.00, 0.05,
        tonumber(FontMagicDB and FontMagicDB.floatingTextFadeDuration)
            or CVars.GetNumber({ "WorldTextRampDuration_v2", "WorldTextRampDuration_V2", "WorldTextRampDuration", "floatingCombatTextRampDuration_v2", "floatingCombatTextRampDuration_V2", "floatingCombatTextRampDuration" }, 1.0),
        function(v)
            FontMagicDB = FontMagicDB or {}
            local previous = FontMagicDB.floatingTextFadeDuration
            local previousTouched = FontMagicDB.floatingTextFadeDurationTouched
            FontMagicDB.floatingTextFadeDuration = v
            FontMagicDB.floatingTextFadeDurationTouched = true
            if not ApplyFloatingTextMotionSettings("fade") then
                FontMagicDB.floatingTextFadeDuration = previous
                FontMagicDB.floatingTextFadeDurationTouched = previousTouched
                ApplyFloatingTextMotionSettings("fade")
                FM.UI.ReportRejectedSetting("floating text fade")
                __fmRunNextFrame(function()
                    if frame and frame.IsShown and frame:IsShown() then BuildCombatOptionsUI() end
                end)
            end
        end,
        "Controls how long world-space numbers remain visible before fading.",
        fadeSupported,
        nil,
        false
    )

    y = y - 120

    local extras = CollectExtraBoolCombatTextCVars()
    if #extras > 0 then
        local showExtras = (FontMagicDB and FontMagicDB.showExtraCombatToggles) and true or false

        -- Keep the panel tidy by default. Users can opt in to showing extra/experimental toggles.
        local toggle = CreateOptionCheckbox(0, y, "Show extra combat text toggles", showExtras, function(self)
            FontMagicDB = FontMagicDB or {}
            FontMagicDB.showExtraCombatToggles = self:GetChecked() and true or false
            BuildCombatOptionsUI()
        end, "Reveals additional, less common combat text options detected on this client.\n\nThese vary by WoW version and may do nothing in some clients. If you\'re unsure, leave this off.")

        if masterOff and toggle and toggle.Disable then pcall(toggle.Disable, toggle) end

        y = y - CHECK_ROW_H - 6

        if showExtras then
            y = AddHeader("Other (Advanced)", y)
            row = 0
            for _, cvar in ipairs(extras) do
                local n, ct = CVars.Resolve(cvar)
                if n and ct == 0 then
                    local override = FontMagicDB.extraCombatOverrides and FontMagicDB.extraCombatOverrides[cvar]
                    local live = GetLiveBoolCVar(n)
                    local checked = (override ~= nil) and (override and true or false) or (live and true or false)

                    if masterOff and type(snap) == "table" and type(snap.cvars) == "table" and snap.cvars[n] ~= nil then
                        checked = (tonumber(snap.cvars[n]) == 1) and true or false
                    end

                    local c, yy = place()
                    local tip = GetExtraCombatTextCVarTooltip(cvar)
                    local cb = CreateOptionCheckbox(c, yy, PrettyCVarLabel(cvar), checked, function(self)
                        local newVal = self:GetChecked() and true or false
                        local applyAtomic = CVars.ApplyAtomicWithRecovery or CVars.ApplyAtomic
                        if applyAtomic(CVars.ResolveTargets(cvar), newVal and "1" or "0") then
                            if type(FontMagicDB.extraCombatOverrides) ~= "table" then FontMagicDB.extraCombatOverrides = {} end
                            FontMagicDB.extraCombatOverrides[cvar] = newVal
                        else
                            self:SetChecked(not newVal)
                            FM.UI.ReportRejectedSetting(PrettyCVarLabel(cvar))
                        end
                    end, tip)

                    if masterOff and cb and cb.Disable then pcall(cb.Disable, cb) end
                end
            end

            y = y - (math.ceil(row / 2) * CHECK_ROW_H) - 10
        end
    end

-- UI / layering helpers
    y = AddHeader("UI (Advanced)", y)
    local above = (FontMagicDB and FontMagicDB.combatTextAboveNameplates) and true or false
    CreateOptionCheckbox(0, y, "Combat text in front of nameplates", above, function(self)
        FontMagicDB = FontMagicDB or {}
        local v = self:GetChecked() and true or false
        FontMagicDB.combatTextAboveNameplates = v
        ApplyCombatTextAboveNameplates(v)
    end, "Makes Blizzard floating combat text draw in front of nameplates by raising its frame strata/level.\n\nBest-effort: works best with third-party nameplate add-ons. This only changes draw order (layering), not where the text appears. On many clients it also affects Blizzard nameplates, but some versions/UI setups may show little or no change. Some UI/add-ons may still cover it.")

    y = y - CHECK_ROW_H - 6

    local needed = -y + 20
    combatContent:SetHeight(math.max(needed, combatScroll:GetHeight()))
end

local function RefreshCombatTextCVars()
    if not (frame and frame.IsShown and frame:IsShown()) then return end
    RefreshScaleControl()
    UpdateMainCombatCheckboxes()
    if combatPanel and combatPanel:IsShown() then
        BuildCombatOptionsUI()
    end
end

local function SetExpanded(expand)
    local want = (expand and true or false)
    if want == isExpanded then return end

    isExpanded = want
    if UpdateExpandToggleText then UpdateExpandToggleText() end

    if isExpanded then
        if combatPanel and combatPanel.Show then combatPanel:Show() end
        BuildCombatOptionsUI()
    else
        if combatPanel and combatPanel.Hide then combatPanel:Hide() end
    end
end

expandBtn:SetScript("OnClick", function()
    SetExpanded(not isExpanded)
end)

-- 8) APPLY & DEFAULT BUTTONS ----------------------------------------------- -----------------------------------------------
local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
-- Match the width of the Default button for consistency
applyBtn:SetSize(100, 22)
-- Position slightly closer to the bottom border now that the
-- overall frame height has been reduced
-- keep the action buttons in place or slightly lower so they no longer
-- overlap the lowest checkboxes
applyBtn:SetPoint("BOTTOMLEFT", 16, 12)
applyBtn:SetText("Apply")


-- Main quick toggles (kept out of the expanded panel for clarity)
mainShowCombatTextCB = CreateCheckbox(frame, "Show Combat Text", 0, 0, true,
    function(self)
        if not IsCombatTextMasterSupported() then
            UpdateMainCombatCheckboxes()
            return
        end
        local want = self:GetChecked() and true or false
        local changed = SetCombatTextMasterEnabled(want)
        if changed == false then
            print("|cFFFF3333[FontMagic]|r WoW rejected part of that combat-text change; the prior state was kept where possible.")
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage("FontMagic: combat-text change was not fully accepted.", 1, 0.2, 0.2)
            end
        end
        RefreshCombatTextCVars()
    end
)
mainShowCombatTextCB:ClearAllPoints()
-- Keep this quick toggle above the action buttons and away from the expandable panel toggle.
mainShowCombatTextCB:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 44)
do
    local fs = mainShowCombatTextCB and (mainShowCombatTextCB.__fmLabelFS or GetCheckButtonLabelFS(mainShowCombatTextCB))
    if fs and fs.SetWidth then fs:SetWidth(240) end
    if fs and fs.SetJustifyH then fs:SetJustifyH("LEFT") end
    if fs and fs.SetWordWrap then fs:SetWordWrap(false) end
end
AttachTooltip(mainShowCombatTextCB, "Show Combat Text",
    "Shows or hides Blizzard floating combat text without losing your per-type settings.\n\n" ..
    "When you hide it, FontMagic stores your current combat text settings and restores them when you enable it again.")

applyBtn:SetScript("OnClick", function()
    -- use the pending selection if the user picked a font but hasn't applied yet
    local selection = pendingFont or (FontMagicDB and FontMagicDB.selectedFont)
    if selection and type(selection) == "string" and selection ~= "" then
        local previousSelection = FontMagicDB.selectedFont
        FontMagicDB.selectedFont = selection

        local path = Fonts.ResolveKey(selection)
        if path then
            local applied, committed = CombatFont:ApplyPath(path)
            if committed == nil then committed = applied end
            if not committed then
                FontMagicDB.selectedFont = previousSelection
                -- ApplyPath can legitimately succeed on some targets before a
                -- later target rejects the face. Restore the prior ownership
                -- immediately so "previous setting was kept" is literally true.
                pcall(CombatFont.ApplySaved, CombatFont)
                pendingFont = selection
                print("|cFFFF3333[FontMagic]|r WoW rejected that font; your previous setting was kept.")
                if UIErrorsFrame and UIErrorsFrame.AddMessage then
                    UIErrorsFrame:AddMessage("FontMagic: WoW rejected that font.", 1, 0.2, 0.2)
                end
                return
            end

            pendingFont = nil
            if _G and _G.FontMagicCombatTextFix and type(_G.FontMagicCombatTextFix.StartCombatTextOwnershipMonitor) == "function" then
                pcall(_G.FontMagicCombatTextFix.StartCombatTextOwnershipMonitor, _G.FontMagicCombatTextFix)
            end
            print("|cFF00FF00[FontMagic]|r Combat font saved. Log out to the character screen and back in to apply it everywhere.")
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage("FontMagic: font saved - log out and back in to apply.", 0.2, 1, 0.2)
            end
        else
            FontMagicDB.selectedFont = previousSelection
            pendingFont = selection
            print("|cFFFF3333[FontMagic]|r Could not apply that font (file not found).")
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage("FontMagic: that font could not be loaded.", 1, 0.2, 0.2)
            end
        end
        return
    end

    -- No selection: clear and restore defaults
    if FontMagicDB then FontMagicDB.selectedFont = nil end
    local restored, committed = CombatFont:ApplySaved()
    if committed ~= nil then restored = committed end
    CombatFont:CaptureDefaults()
    local defaultPath = CombatFont:GetDefaultPath()
    -- Also update the preview + header so the UI matches what will be applied on relog.
    SetPreviewFont(GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()), defaultPath)
    if UpdatePreviewHeaderText then UpdatePreviewHeaderText("Default", defaultPath, true) end
    if preview and editBox and preview.SetText and editBox.GetText then
        preview:SetText(editBox:GetText() or "")
    end
    if restored then
        print("|cFF00FF00[FontMagic]|r Default combat font restored.")
    else
        print("|cFFFF3333[FontMagic]|r Some combat font objects could not be restored; try /reload and Reset again.")
    end
end)

local defaultBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
defaultBtn:SetSize(100,22)
defaultBtn:SetPoint("LEFT", applyBtn, "RIGHT", 8, 0)
defaultBtn:SetText("Reset")

AttachTooltip(defaultBtn, "Reset", "Restore Blizzard defaults. Choose what to reset.")

-- Reset dialog (font-only / combat-options-only / everything)
local resetDialog = CreateFrame("Frame", addonName .. "ResetDialog", UIParent, Compat.BackdropTemplate)
resetDialog:SetFrameStrata("DIALOG")
resetDialog:SetToplevel(true)
resetDialog:SetSize(420, 220)
resetDialog:SetPoint("CENTER")
resetDialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
-- More opaque so the dialog remains readable when something bright is behind it.
resetDialog:SetBackdropColor(0, 0, 0, 0.95)
if resetDialog.SetBackdropBorderColor then
    resetDialog:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
end
resetDialog:EnableMouse(true)
resetDialog:SetMovable(true)
resetDialog:RegisterForDrag("LeftButton")
resetDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
resetDialog:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
resetDialog:Hide()
frame.__fmResetDialog = resetDialog

-- Allow closing the dialog with Escape and keep it on-screen
if resetDialog and resetDialog.GetName and type(UISpecialFrames) == "table" then
    local n = resetDialog:GetName()
    if n then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do
            if v == n then exists = true break end
        end
        if not exists then
            table.insert(UISpecialFrames, n)
        end
    end
end
if resetDialog and resetDialog.SetClampedToScreen then
    resetDialog:SetClampedToScreen(true)
end


local resetTitle = resetDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
resetTitle:SetPoint("TOP", 0, -18)
resetTitle:SetText("Reset FontMagic")

local resetBody = resetDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
resetBody:SetPoint("TOPLEFT", 18, -52)
resetBody:SetPoint("TOPRIGHT", -18, -52)
resetBody:SetPoint("BOTTOMLEFT", 18, 128)
resetBody:SetPoint("BOTTOMRIGHT", -18, 128)
resetBody:SetJustifyH("LEFT")
resetBody:SetJustifyV("TOP")
resetBody:SetText("Choose what you want to reset.\n\n• Font only: clears your selected font and preview state.\n• Combat options only: removes FontMagic overrides so WoW settings behave normally.\n• Everything: does both.")

local function ResetFontOnly()
    -- Preserve minimap settings
    local keepAngle = FontMagicDB and FontMagicDB.minimapAngle
    local keepHide  = FontMagicDB and FontMagicDB.minimapHide

    FontMagicDB = FontMagicDB or {}
    FontMagicDB.__fmLastResetFailure = nil
    FontMagicDB.selectedFont = nil
    FontMagicDB.selectedGroup = nil
    FontMagicDB.minimapAngle = keepAngle
    FontMagicDB.minimapHide  = keepHide

    -- Release live ownership on a best-effort basis, but clearing the durable
    -- selection does not depend on every transient Blizzard FontString accepting
    -- its old tuple in this frame. Font changes already require a character
    -- relog; the next UI load starts from Blizzard defaults with no saved face.
    local restored, committed = CombatFont:ApplySaved()
    if committed ~= nil then restored = committed end
    if not restored then
        -- A FontObject can be temporarily unavailable while Blizzard rebuilds
        -- combat text. The ownership engine retains its exact snapshot, so one
        -- immediate retry is safe and deterministic.
        restored, committed = CombatFont:ApplySaved()
        if committed ~= nil then restored = committed end
    end
    CombatFont:CaptureDefaults()
    local defaultPath = CombatFont:GetDefaultPath()

    FontMagicPCDB = FontMagicPCDB or {}
    FontMagicPCDB.selectedGroup = nil
    FontMagicPCDB.selectedFont  = nil

    pendingFont = nil

    -- Reset dropdown labels
    for _, group in ipairs(order) do
        local dd = dropdowns[group]
        if dd then
            if type(UIDropDownMenu_SetText) == "function" then
                pcall(UIDropDownMenu_SetText, dd, "Select Font")
            elseif dd.SetText then
                dd:SetText("Select Font")
            end
        end
    end

    -- Reset preview font (keep the preview text as-is).
    SetPreviewFont(GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()), defaultPath)
    if UpdatePreviewHeaderText then UpdatePreviewHeaderText("Default", defaultPath, true) end
    __fmRunNextFrame(function()
        -- Reset Everything may roll the font half back synchronously if the
        -- combat-options half is rejected. Do not let this deferred repaint
        -- overwrite the restored selected preview on the following frame.
        if type(FontMagicDB) == "table" and type(FontMagicDB.selectedFont) == "string"
            and FontMagicDB.selectedFont ~= "" then
            return
        end
        SetPreviewFont(GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()), defaultPath)
        if UpdatePreviewHeaderText then UpdatePreviewHeaderText("Default", defaultPath, true) end
        if preview and editBox and preview.SetText and editBox.GetText then
            preview:SetText(editBox:GetText() or "")
        end
    end)
    if editBox and editBox.ClearFocus then
        editBox:ClearFocus()
    end
    if editBox and preview and editBox.GetText and preview.SetText then
        local txt = editBox:GetText() or ""
        preview:SetText("")
        preview:SetText(txt)
    end

    -- If expanded options are currently visible, refresh labels/buttons (including
    -- Text Style) so they immediately reflect reset defaults.
    RefreshCombatTextCVars()
    FontMagicDB.__fmLastResetFailure = nil
    if not restored then
        print("|cFFFFFF00[FontMagic]|r Font reset saved. Log out to the character screen and back in to finish restoring every live font object.")
    end
    return true
end

local function ResetCombatOptionsOnly()
    FontMagicDB = FontMagicDB or {}
    FontMagicDB.__fmLastResetFailure = nil
    local database = type(FM) == "table" and type(FM.Database) == "table" and FM.Database or nil
    local function IsValidMasterSnapshot(snapshot)
        return database and type(database.IsValidMasterSnapshot) == "function"
            and database.IsValidMasterSnapshot(snapshot) or false
    end
    local function IsScopedCombatCVar(name)
        return not database or type(database.IsCombatTextCVarName) ~= "function"
            or database.IsCombatTextCVarName(name)
    end

    local function RestoreResetRecovery()
        local recovery = FontMagicDB.combatResetRecovery
        if type(recovery) ~= "table" then return true end
        local restored = true
        for name, value in pairs(recovery) do
            if not CVars.Exists(name) or CVars.Apply(name, 0, value) then
                recovery[name] = nil
            else
                restored = false
            end
        end
        if next(recovery) == nil then FontMagicDB.combatResetRecovery = nil end
        return restored
    end

    if not RestoreResetRecovery() then
        FontMagicDB.__fmLastResetFailure = "unfinished prior reset recovery"
        return false
    end

    local previousMasterSnapshot = FontMagicDB.combatMasterSnapshot
    local previousMasterPurpose = FontMagicDB.combatMasterSnapshotPurpose
    local previousMasterOff = FontMagicDB.combatMasterOffByFontMagic
    local masterStateReleased = false
    local resetOriginals, resetOrder, resetFailed = {}, {}, false

    local function RestorePreviousMasterState()
        if not masterStateReleased then return true end
        FontMagicDB.combatMasterSnapshot = previousMasterSnapshot
        FontMagicDB.combatMasterSnapshotPurpose = previousMasterPurpose
        FontMagicDB.combatMasterOffByFontMagic = previousMasterOff
        if previousMasterOff and IsValidMasterSnapshot(previousMasterSnapshot) then
            return ApplyCombatTextMasterDisabled()
        end
        return true
    end

    local function RollBackResetCVars()
        local restored = true
        FontMagicDB.combatResetRecovery = FontMagicDB.combatResetRecovery or {}
        for index = #resetOrder, 1, -1 do
            local name = resetOrder[index]
            if CVars.Apply(name, 0, resetOriginals[name]) then
                FontMagicDB.combatResetRecovery[name] = nil
            else
                FontMagicDB.combatResetRecovery[name] = resetOriginals[name]
                restored = false
            end
        end
        if next(FontMagicDB.combatResetRecovery) == nil then
            FontMagicDB.combatResetRecovery = nil
        elseif not restored then
            -- Retry one transient rejection immediately; any persistent
            -- remainder stays serialized for the next reset/login attempt.
            restored = RestoreResetRecovery()
        end
        return restored
    end

    local function ResetCVarToDefault(name, commandType)
        if resetFailed then return false end
        if not name or commandType ~= 0 then return true end
        if not CVars.Exists(name) then return true end

        local current = type(CVars.GetCurrent) == "function" and CVars.GetCurrent(name) or nil
        if current == nil then
            resetFailed = true
            FontMagicDB.__fmLastResetFailure = "unreadable CVar: " .. tostring(name)
            return false
        end

        -- Prefer the engine reset (most accurate to this client build)
        local resetOK = false
        if type(C_CVar) == "table" and type(C_CVar.ResetCVar) == "function" then
            local ok, result = pcall(C_CVar.ResetCVar, name)
            resetOK = ok and result ~= false
        end

        -- Fallback: set to reported default
        if not resetOK then
            local d
            if type(C_CVar) == "table" and type(C_CVar.GetCVarDefault) == "function" then
                local ok, v = pcall(C_CVar.GetCVarDefault, name)
                if ok then d = v end
            end
            if d == nil and type(GetCVarDefault) == "function" then
                local ok, v = pcall(GetCVarDefault, name)
                if ok then d = v end
            end
            if d ~= nil then
                local currentText, defaultText = tostring(current), tostring(d)
                local currentNumber, defaultNumber = tonumber(current), tonumber(d)
                -- A protected CVar can reject both reset APIs even though it is
                -- already at the client-reported default. In that case there is
                -- no live state left for FontMagic to restore, so the ownership
                -- can be released without turning a no-op into a failed reset.
                if currentText == defaultText
                    or (currentNumber ~= nil and defaultNumber ~= nil
                        and currentNumber == defaultNumber) then
                    return true
                else
                    resetOK = CVars.Apply(name, commandType, d)
                end
            end
        end

        if resetOK then
            if resetOriginals[name] == nil then
                resetOriginals[name] = tostring(current)
                resetOrder[#resetOrder + 1] = name
            end
            return true
        end
        resetFailed = true
        FontMagicDB.__fmLastResetFailure = "CVar default: " .. tostring(name)
        return false
    end

    local function ResetBoolCVarToDefault(name)
        return ResetCVarToDefault(name, 0)
    end

    -- Release the master toggle's exact snapshot first. Only then reset the
    -- individual settings FontMagic owns; restoring the snapshot afterwards
    -- would otherwise reintroduce those old overrides.
    if IsValidMasterSnapshot(previousMasterSnapshot) then
        local released
        if previousMasterOff then
            released = SetCombatTextMasterEnabled(true)
        else
            released = ApplyCombatTextMasterEnabledFromSnapshot(previousMasterSnapshot)
            if released then
                FontMagicDB.combatMasterSnapshot = nil
                FontMagicDB.combatMasterSnapshotPurpose = nil
                FontMagicDB.combatMasterOffByFontMagic = nil
            end
        end
        if not released then
            FontMagicDB.__fmLastResetFailure = "combat-text master restore"
            return false
        end
        masterStateReleased = true
    end

    -- Reset only settings the user actually changed through FontMagic. The
    -- former all-CVar sweep touched unrelated client state and let a single
    -- read-only/secure CVar veto an otherwise normal Reset Everything.
    if type(FontMagicDB.combatOverrides) == "table" then
        for key in pairs(FontMagicDB.combatOverrides) do
            local def = DEF_BY_KEY and DEF_BY_KEY[key]
            if def then
                for _, target in ipairs(CVars.ResolveTargets(def.candidates)) do
                    if target.name and target.commandType == 0 then
                        ResetBoolCVarToDefault(target.name)
                    end
                end
            end
        end
    end

    if type(FontMagicDB.extraCombatOverrides) == "table" then
        for cvar in pairs(FontMagicDB.extraCombatOverrides) do
            if IsScopedCombatCVar(cvar) then
                for _, target in ipairs(CVars.ResolveTargets(cvar)) do
                    if target.name and target.commandType == 0 then
                        ResetBoolCVarToDefault(target.name)
                    end
                end
            end
        end
    end

    -- The main size slider now records ownership just like the expanded
    -- motion sliders. Leave an untouched client scale alone.
    if FontMagicDB.combatTextScaleTouched then
        local scaleCandidates = {
            "WorldTextScale_v2",
            "WorldTextScale_V2",
            "WorldTextScale",
            "floatingCombatTextScale_v2",
            "floatingCombatTextScale_V2",
            "floatingCombatTextScale",
        }

        for _, target in ipairs(CVars.ResolveTargets(scaleCandidates)) do
            local name, ct = target.name, target.commandType
            if name and ct == 0 then
                ResetCVarToDefault(name, ct)
            end
        end
    end

    do
        local function ResetNumericCVarToDefault(candidates)
            local bestName = CVars.ResolveName(candidates)

            for _, target in ipairs(CVars.ResolveTargets(candidates)) do
                local name, ct = target.name, target.commandType
                if name and ct == 0 then
                    ResetCVarToDefault(name, ct)
                end
            end

            if bestName then
                return tonumber(CVars.GetString(bestName))
            end
            return nil
        end

        local gravityCandidates = { "WorldTextGravity_v2", "WorldTextGravity_V2", "WorldTextGravity", "floatingCombatTextGravity_v2", "floatingCombatTextGravity_V2", "floatingCombatTextGravity" }
        local fadeCandidates = { "WorldTextRampDuration_v2", "WorldTextRampDuration_V2", "WorldTextRampDuration", "floatingCombatTextRampDuration_v2", "floatingCombatTextRampDuration_V2", "floatingCombatTextRampDuration" }

        if FontMagicDB.floatingTextGravityTouched then
            ResetNumericCVarToDefault(gravityCandidates)
        end
        if FontMagicDB.floatingTextFadeDurationTouched then
            ResetNumericCVarToDefault(fadeCandidates)
        end
    end

    if resetFailed then
        RollBackResetCVars()
        RestorePreviousMasterState()
        return false
    end

    -- Release only the outline ownership while retaining a selected face. This
    -- is part of the same reset transaction as the CVars above.
    FontMagicDB.combatTextOutlineMode = "NONE"
    FontMagicDB.combatTextOutlineTouched = false
    local function OutlineReleaseSucceeded(complete, committed)
        return complete or (committed
            and type(CombatFont.HasOutstandingOutlineOwnership) == "function"
            and not CombatFont:HasOutstandingOutlineOwnership())
    end
    local complete, committed = CombatFont:ApplySaved()
    local fontStateRestored = OutlineReleaseSucceeded(complete, committed)
    if not fontStateRestored then
        complete, committed = CombatFont:ApplySaved()
        fontStateRestored = OutlineReleaseSucceeded(complete, committed)
    end
    -- A transient live FontObject may reject removing an outline immediately.
    -- The saved ownership is still cleared: the next character login recreates
    -- that object from Blizzard defaults rather than resurrecting the override.
    -- CVar failures above remain transactional because those values persist
    -- independently of FontMagic and therefore cannot be treated this way.

    -- Durable changes succeeded; only now discard FontMagic's saved ownership.
    local priorIncoming = FontMagicDB.incomingOverrides
    local hadDamageOverride = type(priorIncoming) == "table" and priorIncoming.incomingDamage ~= nil
    local hadHealingOverride = type(priorIncoming) == "table" and priorIncoming.incomingHealing ~= nil
    local masterIncomingWasOwned = FontMagicDB.combatMasterOffByFontMagic
        or FontMagicDB.combatMasterSnapshotPurpose == "baselineRollback"
    FontMagicDB.combatOverrides = {}
    FontMagicDB.extraCombatOverrides = {}
    FontMagicDB.incomingOverrides = {}
    FontMagicDB.combatMasterSnapshot = nil
    FontMagicDB.combatMasterSnapshotPurpose = nil
    FontMagicDB.combatMasterOffByFontMagic = nil
    FontMagicDB.floatingTextGravity = nil
    FontMagicDB.floatingTextFadeDuration = nil
    FontMagicDB.floatingTextGravityTouched = false
    FontMagicDB.floatingTextFadeDurationTouched = false
    FontMagicDB.combatTextScale = nil
    FontMagicDB.combatTextScaleTouched = false

    -- Release per-option incoming ownership to the exact row identities that
    -- existed at first mutation. If a master-only operation changed a group
    -- without such a backup, restore only missing Blizzard baseline rows and
    -- leave any later external-addon replacements intact.
    if EnsureIncomingReady() and _G.FontMagicCombatTextFix then
        local releasedGroups = {}
        if type(_G.FontMagicCombatTextFix.ReleaseIncomingOverrideOwnership) == "function" then
            local _, released = _G.FontMagicCombatTextFix:ReleaseIncomingOverrideOwnership()
            if type(released) == "table" then releasedGroups = released end
        end
        if (hadDamageOverride or masterIncomingWasOwned) and not releasedGroups.damage then
            SetIncomingDamageEnabled(true, false)
        end
        if (hadHealingOverride or masterIncomingWasOwned) and not releasedGroups.healing then
            SetIncomingHealingEnabled(true, false)
        end
    end

    -- Reset account-wide layering tweak (combat text above nameplates).
    FontMagicDB.combatTextAboveNameplates = false
    ApplyCombatTextAboveNameplates(false)

    RefreshScaleControl()
    RefreshCombatTextCVars()
    UpdateMainCombatCheckboxes()
    FontMagicDB.__fmLastResetFailure = nil
    if not fontStateRestored then
        print("|cFFFFFF00[FontMagic]|r Combat-option reset saved. Log out to the character screen and back in to finish restoring every live font object.")
    end
    return true
end

local function ResetEverything()
    local previousFont = FontMagicDB and FontMagicDB.selectedFont
    local previousGroup = FontMagicDB and FontMagicDB.selectedGroup
    local previousPCFont = FontMagicPCDB and FontMagicPCDB.selectedFont
    local previousPCGroup = FontMagicPCDB and FontMagicPCDB.selectedGroup
    if not ResetFontOnly() then return false end
    if ResetCombatOptionsOnly() then return true end

    -- Reset Font Only completed first, so restore that face selection if the
    -- combat-options half of the combined transaction was rejected.
    FontMagicDB.selectedFont = previousFont
    FontMagicDB.selectedGroup = previousGroup
    FontMagicPCDB = FontMagicPCDB or {}
    FontMagicPCDB.selectedFont = previousPCFont
    FontMagicPCDB.selectedGroup = previousPCGroup
    pcall(CombatFont.ApplySaved, CombatFont)
    if _G.FontMagicCombatTextFix and _G.FontMagicCombatTextFix.StartCombatTextOwnershipMonitor then
        pcall(_G.FontMagicCombatTextFix.StartCombatTextOwnershipMonitor, _G.FontMagicCombatTextFix)
    end

    for _, group in ipairs(order) do
        local dd = dropdowns[group]
        if dd and type(UIDropDownMenu_SetText) == "function" then
            pcall(UIDropDownMenu_SetText, dd, "Select Font")
        end
    end
    if type(previousFont) == "string" then
        local restoredPath, group, filename = Fonts.ResolveKey(previousFont)
        if not group or not filename then
            group, filename = previousFont:match("^(.*)/([^/]+)$")
        end
        local display = filename and Fonts.StripExtension(filename) or ""
        if group ~= "Custom" and type(DisplayNameForFont) == "function" then
            display = DisplayNameForFont(filename)
        end
        if group and filename and dropdowns[group] and type(UIDropDownMenu_SetText) == "function" then
            pcall(UIDropDownMenu_SetText, dropdowns[group], display)
        end
        if restoredPath then
            SetPreviewFont(
                GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()),
                restoredPath
            )
            if UpdatePreviewHeaderText then
                UpdatePreviewHeaderText(display, restoredPath, false)
            end
            if preview and editBox and preview.SetText and editBox.GetText then
                preview:SetText(editBox:GetText() or "")
            end
        end
    end
    return false
end

local resetFontBtn = CreateFrame("Button", nil, resetDialog, "UIPanelButtonTemplate")
resetFontBtn:SetSize(160, 22)
resetFontBtn:SetPoint("BOTTOMLEFT", 18, 54)
resetFontBtn:SetText("Reset Font Only")
AttachTooltip(resetFontBtn, "Reset font only", "Restore Blizzard\'s default combat text font.")
resetFontBtn:SetScript("OnClick", function()
    if ResetFontOnly() then
        resetDialog:Hide()
    else
        FM.UI.ReportRejectedSetting(FontMagicDB.__fmLastResetFailure or "font reset")
    end
end)

local resetCombatBtn = CreateFrame("Button", nil, resetDialog, "UIPanelButtonTemplate")
resetCombatBtn:SetSize(160, 22)
resetCombatBtn:SetPoint("BOTTOMRIGHT", -18, 54)
resetCombatBtn:SetText("Reset Combat Options")
AttachTooltip(resetCombatBtn, "Reset combat options", "Clear FontMagic combat text overrides and restore Blizzard defaults.")
resetCombatBtn:SetScript("OnClick", function()
    if ResetCombatOptionsOnly() then
        resetDialog:Hide()
    else
        FM.UI.ReportRejectedSetting(FontMagicDB.__fmLastResetFailure or "combat-options reset")
    end
end)

local resetAllBtn = CreateFrame("Button", nil, resetDialog, "UIPanelButtonTemplate")
resetAllBtn:SetSize(160, 22)
resetAllBtn:SetPoint("BOTTOM", 0, 92)
resetAllBtn:SetText("Reset Everything")
AttachTooltip(resetAllBtn, "Reset everything", "Restore Blizzard defaults for both fonts and combat text options.")
resetAllBtn:SetScript("OnClick", function()
    if ResetEverything() then
        resetDialog:Hide()
    else
        FM.UI.ReportRejectedSetting(FontMagicDB.__fmLastResetFailure or "full reset")
    end
end)

local resetCancelBtn = CreateFrame("Button", nil, resetDialog, "UIPanelButtonTemplate")
resetCancelBtn:SetSize(120, 22)
resetCancelBtn:SetPoint("BOTTOM", 0, 18)
resetCancelBtn:SetText(CANCEL or "Cancel")
AttachTooltip(resetCancelBtn, "Cancel", "Close this dialog without making changes.")
resetCancelBtn:SetScript("OnClick", function() resetDialog:Hide() end)

defaultBtn:SetScript("OnClick", function()
    if resetDialog:IsShown() then
        resetDialog:Hide()
    else
        resetDialog:Show()
    end
end)

-- 11) CLOSE BUTTON
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeBtn:SetSize(80, 24)
-- Align with the Apply button and use the reduced
-- bottom spacing
closeBtn:SetPoint("BOTTOMRIGHT", (frame.__fmLeftAnchor or frame), "BOTTOMRIGHT", -16, 12)
-- Keep the expand toggle neatly above Close
if expandBtn and expandBtn.ClearAllPoints and expandBtn.SetPoint then
    expandBtn:ClearAllPoints()
    expandBtn:SetPoint("BOTTOMRIGHT", closeBtn, "TOPRIGHT", 0, 6)
end
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() frame:Hide() end)
closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Close this window", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- 12) SLASH COMMANDS & DROPDOWN
SLASH_FONTMAGIC1 = "/fct"
SLASH_FONTMAGIC2 = "/float"
SLASH_FONTMAGIC3 = "/floating"
SLASH_FONTMAGIC4 = "/floatingtext"
SLASH_FONTMAGIC5 = "/fontmagic"

local function PrepareFontMagicWindowForDisplay()
    if not frame then return end

    -- When opened from the Retail Settings/AddOns panel, this frame can be
    -- parented into that container. Minimap/slash opens are standalone and must
    -- be detached back to UIParent or the frame can remain effectively hidden.
    if frame.GetParent and frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end

    -- Restore saved position (standalone only)
    if frame.GetParent and frame:GetParent() == UIParent and FontMagicDB and type(FontMagicDB.windowPos) == "table" then
        local p = FontMagicDB.windowPos
        if type(p.left) == "number" and type(p.top) == "number" then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left, p.top)
        end
    end

    -- Ensure the config window is on top when opened standalone.
    if frame.GetParent and frame:GetParent() == UIParent then
        if frame.SetToplevel then frame:SetToplevel(true) end
        if frame.SetFrameStrata then frame:SetFrameStrata("FULLSCREEN_DIALOG") end
        if frame.SetFrameLevel then frame:SetFrameLevel(1000) end
        if frame.Raise then frame:Raise() end

        if combatPanel and combatPanel.SetFrameStrata then
            combatPanel:SetFrameStrata("FULLSCREEN_DIALOG")
            if combatPanel.SetFrameLevel and frame.GetFrameLevel then
                combatPanel:SetFrameLevel((frame:GetFrameLevel() or 1000) + 20)
            end
        end
        if expandBtn and expandBtn.SetFrameStrata then
            expandBtn:SetFrameStrata("FULLSCREEN_DIALOG")
            if expandBtn.SetFrameLevel and frame.GetFrameLevel then
                expandBtn:SetFrameLevel((frame:GetFrameLevel() or 1000) + 30)
            end
        end
        if resetDialog and resetDialog.SetFrameStrata then
            resetDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        end
    end

    -- Apply account-wide combat text layer preference immediately.
    if FontMagicDB and FontMagicDB.combatTextAboveNameplates then
        ApplyCombatTextAboveNameplates(true)
    else
        ApplyCombatTextAboveNameplates(false)
    end

    UpdateMainCombatCheckboxes()
end

-- Settings can show the canvas directly, bypassing the slash/minimap opener.
-- Refresh visible state on every show so a hidden CVAR_UPDATE never leaves
-- pooled controls stale when the window is reopened.
if frame.HookScript then
    frame:HookScript("OnShow", function()
        pcall(SyncPreviewToAppliedFont)
        RefreshCombatTextCVars()
    end)
end

SlashCmdList["FONTMAGIC"] = function(msg)
    -- normalise message for case-insensitive matching and remove whitespace
    msg = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()

    if msg:match("^debug") then
        local arg = msg:match("^debug%s*(.-)%s*$") or ""
        local ct = _G and _G.FontMagicCombatTextFix

        if arg == "test" then
            if ct then
                if type(ct.EnsureCombatTextPatches) == "function" then
                    pcall(ct.EnsureCombatTextPatches, ct)
                end
                if type(ct.SendTestCombatText) == "function" then
                    pcall(ct.SendTestCombatText, ct)
                end
                if type(ct.PrintDebugSnapshot) == "function" then
                    pcall(ct.PrintDebugSnapshot, ct)
                end
            end
            return
        end

        if arg == "" or arg == "toggle" then
            FontMagicDB.__fmDebugCombatText = not FontMagicDB.__fmDebugCombatText
        elseif arg == "on" or arg == "1" or arg == "true" then
            FontMagicDB.__fmDebugCombatText = true
        elseif arg == "off" or arg == "0" or arg == "false" then
            FontMagicDB.__fmDebugCombatText = false
        elseif arg == "dump" then
            -- no state change
        else
            if ct and ct.DbgLine then
                ct:DbgLine("usage: /fontmagic debug [on|off|toggle|dump|test]")
            else
                print("FontMagic: usage: /fontmagic debug [on|off|toggle|dump|test]")
            end
        end

        -- Reset per-session counters so the next enable gives fresh logs.
        if FontMagicDB.__fmDebugCombatText then
            if ct and type(ct.wrap) == "table" then
                ct.wrap.logCount = 0
                ct.wrap.lastFSText = {}
                ct.wrap.lastDisplayedScan = 0
            end
            if ct and ct.DbgLine then
                ct:DbgLine("combat-text debug ON (logging numeric-ish messages)")
            end
        else
            if ct and ct.DbgLine then
                ct:DbgLine("combat-text debug OFF")
            end
        end

        if ct then
            if type(ct.EnsureCombatTextPatches) == "function" then
                pcall(ct.EnsureCombatTextPatches, ct)
            end
            if type(ct.PrintDebugSnapshot) == "function" then
                pcall(ct.PrintDebugSnapshot, ct)
            end
        end
        return
    end

    if msg == "hide" then
        if type(FontMagicDB) ~= "table" then FontMagicDB = {} end
        FontMagicDB.minimapHide = true
        if minimapButton then minimapButton:Hide() end
        print("|cFF00FF00[FontMagic]|r Minimap icon hidden. Use /float show to restore.")
        return
    elseif msg == "show" then
        if type(FontMagicDB) ~= "table" then FontMagicDB = {} end
        FontMagicDB.minimapHide = false
        if minimapButton then minimapButton:Show() end
        print("|cFF00FF00[FontMagic]|r Minimap icon shown.")
        return
    end

    if frame:IsVisible() then
        frame:Hide()
        return
    end

    pendingFont = nil -- discard any un-applied selection

    for g,d in pairs(dropdowns) do UIDropDownMenu_SetText(d, "Select Font") end
    if FontMagicDB.selectedFont then
        -- parse using the last '/' to support group names that contain
        -- slashes from older categories.
        local grp,fname = FontMagicDB.selectedFont:match("^(.*)/([^/]+)$")
        if grp and fname and dropdowns[grp] and Fonts.Exists[grp][fname] then
            local display = (grp == "Custom") and Fonts.StripExtension(fname) or DisplayNameForFont(fname)
            UIDropDownMenu_SetText(dropdowns[grp], display)
            -- If this font is favorited, also reflect it in the Favorites dropdown.
            if dropdowns["Favorites"] and IsFavorite(FontMagicDB.selectedFont) then
                UIDropDownMenu_SetText(dropdowns["Favorites"], display)
            end
            local cache = Fonts.Cached[grp][fname]
            if cache then
                SetPreviewFont(cache)
                if UpdatePreviewHeaderText then
                    UpdatePreviewHeaderText(display, cache.path, false)
                end
            end
        end
    else
        -- no saved font means use the UI's default
        SetPreviewFont(GameFontNormalLarge or preview:GetFontObject(), CombatFont:GetDefaultPath())
        if UpdatePreviewHeaderText then UpdatePreviewHeaderText("Default", CombatFont:GetDefaultPath(), true) end
    end
    preview:SetText(editBox:GetText())
    PrepareFontMagicWindowForDisplay()
    frame:Show()

    -- Ensure the preview is correctly sized the first time the window is shown.
    -- Some clients report widget sizes slightly differently before the frame is visible.
    __fmRunNextFrame(function()
        if not (frame and frame.IsShown and frame:IsShown()) then return end

        local key = FontMagicDB and FontMagicDB.selectedFont
        local path
        if key and type(key) == "string" and key ~= "" then
            path = Fonts.ResolveKey(key)
        end
        if not path then
            CombatFont:CaptureDefaults()
            path = CombatFont:GetDefaultPath()
        end

        SetPreviewFont(GameFontNormalLarge or (preview and preview.GetFontObject and preview:GetFontObject()), path)

        if UpdatePreviewHeaderText then
            local label = "Default"
            local isDef = true
            if key and type(key) == "string" and key ~= "" then
                local _, f = key:match("^(.*)/([^/]+)$")
                if f then
                    label = Fonts.StripExtension(f)
                    isDef = false
                end
            end
            UpdatePreviewHeaderText(label, path, isDef)
        end

        if preview and editBox and preview.SetText and editBox.GetText then
            preview:SetText(editBox:GetText() or "")
        end
    end)
end

-- 13) MINIMAP ICON -----------------------------------------------------------
minimapButton = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
minimapButton:SetSize(20, 20)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

-- helper to position the minimap button at a specific angle
local function PositionMinimapButton(btn, angle)
    local a = math.rad(angle or 0)
    local r = (Minimap and Minimap.GetWidth and (Minimap:GetWidth() / 2) or 70) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function UpdateMinimapButtonDrag(self)
    local mx, my = GetCursorPosition()
    local scale = (Minimap and Minimap.GetEffectiveScale and Minimap:GetEffectiveScale()) or 1
    mx, my = mx / scale, my / scale
    local cx, cy = Minimap:GetCenter()
    local dx, dy = mx - cx, my - cy

    local ang = math.deg(Compat.SafeAtan2(dy, dx))
    FontMagicDB.minimapAngle = ang
    PositionMinimapButton(self, ang)
end

-- icon (masked to a circle)
local iconTex = minimapButton:CreateTexture(nil, "BACKGROUND")
iconTex:SetTexture(FM.Paths.Addon .. "FontMagic_MinimapIcon_Best_64.tga")
iconTex:SetAllPoints(minimapButton)
    if iconTex.SetMaskTexture then
        -- Use a double-backslash path to avoid Lua escape sequences removing the backslashes.
        -- Without escaping, a single \M would remove the backslash and break the path.
        iconTex:SetMaskTexture("Interface\\Minimap\\UI-Minimap-Mask")
    end

-- ring overlay
local ring = minimapButton:CreateTexture(nil, "OVERLAY")
ring:SetTexture(FM.Paths.Addon .. "FontMagic_MinimapRing_Best_64.tga")
local w, h = minimapButton:GetSize()
ring:SetSize(w * 1.5, h * 1.5)
ring:SetAlpha(0.85)
iconTex:SetAlpha(0.95)
ring:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

    -- Use a double-backslash path to avoid Lua escape sequences removing the backslashes.
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:EnableMouse(true)
minimapButton:SetHitRectInsets(-6, -6, -6, -6)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnClick", function()
    if SlashCmdList and SlashCmdList["FONTMAGIC"] then
        SlashCmdList["FONTMAGIC"]()
    end
end)

minimapButton:SetScript("OnDragStart", function(self)
    self.isMoving = true
    self:SetScript("OnUpdate", UpdateMinimapButtonDrag)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self.isMoving = false
    self:SetScript("OnUpdate", nil)
    PositionMinimapButton(self, FontMagicDB and FontMagicDB.minimapAngle)
end)

minimapButton:SetScript("OnEnter", function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("FontMagic", 1, 1, 1)
        GameTooltip:Show()
    end
    if ring then ring:SetAlpha(1.0) end
    if iconTex then iconTex:SetAlpha(1.0) end
end)
minimapButton:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    if ring then ring:SetAlpha(0.85) end
    if iconTex then iconTex:SetAlpha(0.95) end
end)

-- place immediately
PositionMinimapButton(minimapButton, FontMagicDB and FontMagicDB.minimapAngle)

-- honour saved visibility preference
if FontMagicDB and FontMagicDB.minimapHide then
    minimapButton:Hide()
end

-- Apply minimap button preferences (angle + visibility). We call this again on
-- ADDON_LOADED/PLAYER_LOGIN because some clients only guarantee SavedVariables
-- are populated by then.
local function ApplyMinimapButtonPreferences()
    if not minimapButton then return end
    if type(FontMagicDB) ~= "table" then return end

    if type(FontMagicDB.minimapAngle) == "number" then
        PositionMinimapButton(minimapButton, FontMagicDB.minimapAngle)
    end

    if FontMagicDB.minimapHide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

-- ---------------------------------------------------------------------------
-- Combat text override bootstrap
-- ---------------------------------------------------------------------------

local function ApplyAllSavedOverrides()
    do
        local recovery = FontMagicDB and FontMagicDB.combatResetRecovery
        if type(recovery) == "table" then
            for name, value in pairs(recovery) do
                if not FM.Database.IsCombatTextCVarName(name)
                    or not CVars.Exists(name)
                    or CVars.Apply(name, 0, value) then
                    recovery[name] = nil
                end
            end
            if next(recovery) == nil then FontMagicDB.combatResetRecovery = nil end
        end
    end

    if FontMagicDB and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
        local purpose = FontMagicDB.combatMasterSnapshotPurpose
        local needsRecovery = purpose == "baselineRollback"
            or (purpose == "hidden" and not FontMagicDB.combatMasterOffByFontMagic)
        if needsRecovery and ApplyCombatTextMasterEnabledFromSnapshot(FontMagicDB.combatMasterSnapshot) then
            FontMagicDB.combatMasterSnapshot = nil
            FontMagicDB.combatMasterSnapshotPurpose = nil
            FontMagicDB.combatMasterOffByFontMagic = nil
        end
    end

    ApplyCombatOverrides()
    ApplyIncomingOverrides()
    ApplyFloatingTextMotionSettings()
    if FM.CombatSettings and type(FM.CombatSettings.ApplyScale) == "function" then
        pcall(FM.CombatSettings.ApplyScale)
    end

    -- If combat text was hidden via the master toggle, keep it hidden across relogs.
    if FontMagicDB and FontMagicDB.combatMasterOffByFontMagic
        and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
        ApplyCombatTextMasterDisabled()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CVAR_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    local fix = _G and _G.FontMagicCombatTextFix
    local relevantAddonLoaded = event == "ADDON_LOADED" and (
        arg1 == addonName
        or arg1 == FM.Constants.CUSTOM_ADDON
        or arg1 == "Blizzard_CombatText"
        or arg1 == "Blizzard_FloatingCombatText"
        or arg1 == "ElvUI"
        or arg1 == "SUI"
    )

    if event == "ADDON_LOADED" and arg1 == FM.Constants.CUSTOM_ADDON
        and type(Fonts.RefreshAvailability) == "function" then
        pcall(Fonts.RefreshAvailability, "Custom")
    end

    if fix and type(fix.InstallExternalCombatFontHooks) == "function"
        and (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or relevantAddonLoaded) then
        pcall(fix.InstallExternalCombatFontHooks, fix)
    end

    -- Catch file-scope writes synchronously; this does not depend on a timer or
    -- a rendered frame existing before WoW caches DAMAGE_TEXT_FONT. The queued
    -- guard below then catches another addon's later handler in this dispatch.
    if fix and type(fix.GuardExternalCombatFontGlobalsNow) == "function"
        and (event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") then
        pcall(fix.GuardExternalCombatFontGlobalsNow, fix)
    end

    -- Run after the current event dispatch finishes. This covers font addons
    -- that write DAMAGE_TEXT_FONT from their own ADDON_LOADED/PLAYER_LOGIN
    -- handler after FontMagic's handler has already run. The guard reconciles
    -- only when it observes real drift, so unrelated addon loads stay cheap.
    if fix and type(fix.QueueExternalCombatFontGuard) == "function"
        and (event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") then
        pcall(fix.QueueExternalCombatFontGuard, fix, 0)
    end

    if relevantAddonLoaded and fix and type(fix.QueueSavedCombatFontApply) == "function" then
        pcall(fix.QueueSavedCombatFontApply, fix, 0)
    end

    if event == "PLAYER_LOGIN" then
        -- Build console index, register options, then apply only the saved overrides.
        CVars.RefreshIndex()
        Fonts.MigrateSavedKeys()
        Compat.RegisterOptionsCategory(frame)
        CombatFont:CaptureDefaults()
        CombatFont:ApplySaved()
        if fix and type(fix.QueueSavedCombatFontApplyBurst) == "function" then
            pcall(fix.QueueSavedCombatFontApplyBurst, fix)
        end
        if fix and type(fix.EnsureCombatTextPatches) == "function" then
            pcall(fix.EnsureCombatTextPatches, fix)
        end
        ApplyAllSavedOverrides()
        RefreshCombatTextCVars()
        -- Apply account-wide layering preference
        if FontMagicDB and FontMagicDB.combatTextAboveNameplates then
            ApplyCombatTextAboveNameplates(true)
        else
            ApplyCombatTextAboveNameplates(false)
        end

        UpdateMainCombatCheckboxes()
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0.2, UpdateMainCombatCheckboxes)
            C_Timer.After(1.0, UpdateMainCombatCheckboxes)
        end

        -- Re-apply minimap icon state now that SavedVariables are definitely loaded.
        pcall(function()
            if type(FontMagicDB) ~= "table" then FontMagicDB = {} end
            if FontMagicDB.minimapAngle == nil then
                FontMagicDB.minimapAngle = tonumber(FM.Constants.DEFAULT_MINIMAP_ANGLE) or 225
            end
            if FontMagicDB.minimapHide == nil then FontMagicDB.minimapHide = false end
            if ApplyMinimapButtonPreferences then ApplyMinimapButtonPreferences() end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        CombatFont:CaptureDefaults()
        CombatFont:ApplySaved()
        if fix and type(fix.QueueSavedCombatFontApplyBurst) == "function" then
            pcall(fix.QueueSavedCombatFontApplyBurst, fix)
        end

    elseif event == "ADDON_LOADED" then
        -- SavedVariables are guaranteed to be available on our own ADDON_LOADED.
        -- Apply the saved font as early as possible so Blizzard combat text picks it up
        -- during its initialization (some clients cache the font before PLAYER_LOGIN).
        if arg1 == addonName then
            Fonts.MigrateSavedKeys()
            CombatFont:CaptureDefaults()
            CombatFont:ApplySaved()
            if fix and type(fix.QueueSavedCombatFontApplyBurst) == "function" then
                pcall(fix.QueueSavedCombatFontApplyBurst, fix)
            end
            if fix and type(fix.EnsureCombatTextPatches) == "function" then
                pcall(fix.EnsureCombatTextPatches, fix)
            end
            ApplyFloatingTextMotionSettings()

            -- Ensure minimap icon respects saved hide/angle (SavedVariables are guaranteed here).
            pcall(function()
                if type(FontMagicDB) ~= "table" then FontMagicDB = {} end
                if FontMagicDB.minimapAngle == nil then
                    FontMagicDB.minimapAngle = tonumber(FM.Constants.DEFAULT_MINIMAP_ANGLE) or 225
                end
                if FontMagicDB.minimapHide == nil then FontMagicDB.minimapHide = false end
                if ApplyMinimapButtonPreferences then ApplyMinimapButtonPreferences() end
            end)
        end

        -- If Blizzard_CombatText loads after us, re-apply incoming overrides (if any).
        if arg1 == "Blizzard_CombatText" or arg1 == "Blizzard_FloatingCombatText" then
            Fonts.MigrateSavedKeys()
            CombatFont:CaptureDefaults()
            CombatFont:ApplySaved()
            if fix and type(fix.QueueSavedCombatFontApplyBurst) == "function" then
                pcall(fix.QueueSavedCombatFontApplyBurst, fix)
            end
            if fix and type(fix.EnsureCombatTextPatches) == "function" then
                pcall(fix.EnsureCombatTextPatches, fix)
            end
            ApplyIncomingOverrides()
            if FontMagicDB and FontMagicDB.combatMasterOffByFontMagic
                and FM.Database.IsValidMasterSnapshot(FontMagicDB.combatMasterSnapshot) then
                ApplyCombatTextMasterDisabled()
            end
            ApplyFloatingTextMotionSettings()
            RefreshCombatTextCVars()
        end

    elseif event == "CVAR_UPDATE" then
        -- Keep visible controls in sync without rebuilding for unrelated CVars
        -- (CVAR_UPDATE can fire hundreds of times during login/options changes).
        local changedName = tostring(arg1 or ""):lower()
        local relevant = changedName:find("^floatingcombattext")
            or changedName:find("^worldtext")
            or changedName == "enablecombattext"
            or changedName == "enablefloatingcombattext"
        if relevant and frame and frame.IsShown and frame:IsShown() then
            local function refreshVisibleControls()
                eventFrame.__fmCVarRefreshQueued = nil
                RefreshCombatTextCVars()
            end
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                if not eventFrame.__fmCVarRefreshQueued then
                    eventFrame.__fmCVarRefreshQueued = true
                    C_Timer.After(0, refreshVisibleControls)
                end
            else
                refreshVisibleControls()
            end
        end
    end
end)
