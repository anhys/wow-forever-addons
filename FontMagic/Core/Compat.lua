-- Cross-client adapters used by the rest of FontMagic.
local _, FM = ...

if type(FM) ~= "table" then
    error("FontMagic Core/Compat.lua requires the shared addon table", 0)
end

local Compat = FM.Compat
local CVars = FM.CVars

-- Forever and modern Retail can supply secret combat text. Never inspect or
-- stringify those values; older clients do not expose this API.
function Compat.IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local objectSafetyChecks = { "IsForbidden", "HasSecretValues" }

function Compat.CanInspectObject(object)
    if Compat.IsSecretValue(object) then return false end
    local kind = type(object)
    if kind ~= "table" and kind ~= "userdata" then return false end
    for _, name in ipairs(objectSafetyChecks) do
        local ok, blocked = pcall(function()
            local check = object[name]
            if Compat.IsSecretValue(check) then return true end
            if type(check) ~= "function" then return false end
            local result = check(object)
            if Compat.IsSecretValue(result) then return true end
            return result and true or false
        end)
        if not ok or blocked then return false end
    end
    return true
end

-- nil means temporarily restricted, false means an unavailable getter. Never
-- return a partially secret tuple: even an empty-string test can be blocked.
function Compat.GetFontTuple(object)
    if not Compat.CanInspectObject(object) then return nil end
    local okMethod, method = pcall(function() return object.GetFont end)
    if not okMethod then return false end
    if Compat.IsSecretValue(method) then return nil end
    if type(method) ~= "function" then return false end
    local ok, path, size, flags = pcall(method, object)
    if not ok then return false end
    if Compat.IsSecretValue(path) or Compat.IsSecretValue(size) or Compat.IsSecretValue(flags) then
        return nil
    end
    return true, path, size, flags
end

Compat.BackdropTemplate = (type(BackdropTemplateMixin) == "table" and "BackdropTemplate") or nil

function Compat.LoadAddOn(name)
    if type(name) ~= "string" or name == "" then return false end
    if type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
        local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, name)
        if not ok then return false, loaded end
        return loaded and true or false, reason
    end
    if type(LoadAddOn) == "function" then
        local ok, loaded, reason = pcall(LoadAddOn, name)
        if not ok then return false, loaded end
        return loaded and true or false, reason
    end
    return false, "UNAVAILABLE"
end

function Compat.GetCombatTextTypeInfo()
    if type(CombatTextTypeInfo) == "table" then return CombatTextTypeInfo end
    if type(COMBAT_TEXT_TYPE_INFO) == "table" then return COMBAT_TEXT_TYPE_INFO end
    return nil
end

function Compat.SafeAtan2(y, x)
    y, x = tonumber(y) or 0, tonumber(x) or 0

    if type(math.atan2) == "function" then
        local ok, value = pcall(math.atan2, y, x)
        if ok and type(value) == "number" then return value end
    end
    if type(atan2) == "function" then
        local ok, value = pcall(atan2, y, x)
        if ok and type(value) == "number" then return value end
    end

    -- Lua 5.1 silently ignores math.atan's second argument, so use explicit
    -- quadrant correction instead of probing math.atan(y, x).
    if x > 0 then return math.atan(y / x) end
    if x < 0 then
        if y >= 0 then return math.atan(y / x) + math.pi end
        return math.atan(y / x) - math.pi
    end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

Compat.registeredOptions = Compat.registeredOptions or setmetatable({}, { __mode = "k" })

function Compat.RegisterOptionsCategory(frame)
    if not frame or Compat.registeredOptions[frame] then return true end

    local name = type(frame.name) == "string" and frame.name or "FontMagic"
    if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function" then
        local ok, category = pcall(function()
            if frame.parent and type(Settings.GetCategory) == "function"
                and type(Settings.RegisterCanvasLayoutSubcategory) == "function" then
                local parent = Settings.GetCategory(frame.parent)
                if parent then
                    return Settings.RegisterCanvasLayoutSubcategory(parent, frame, name, name)
                end
            end
            local created = Settings.RegisterCanvasLayoutCategory(frame, name, name)
            if created and type(Settings.RegisterAddOnCategory) == "function" then
                Settings.RegisterAddOnCategory(created)
            end
            return created
        end)
        if ok and category then
            pcall(function() category.ID = name end)
            Compat.registeredOptions[frame] = category
            return true, category
        end
        return false, category
    end

    if type(InterfaceOptions_AddCategory) == "function" then
        local ok, result = pcall(InterfaceOptions_AddCategory, frame)
        if ok and result ~= false then
            Compat.registeredOptions[frame] = result or true
            return true, result
        end
        return false, result
    end

    return false, "UNAVAILABLE"
end

function CVars.GetInfo(name)
    if type(name) ~= "string" or name == "" then return nil end
    if type(C_CVar) == "table" and type(C_CVar.GetCVarInfo) == "function" then
        local ok, a, b, c, d, e, f, g = pcall(C_CVar.GetCVarInfo, name)
        if ok then
            if type(a) == "table" then
                return a.value, a.defaultValue, a.isStoredServerAccount,
                    a.isStoredServerCharacter, a.isLockedFromUser, a.isSecure, a.isReadOnly
            end
            return a, b, c, d, e, f, g
        end
    end
    if type(GetCVarInfo) == "function" then
        local ok, a, b, c, d, e, f, g = pcall(GetCVarInfo, name)
        if ok then return a, b, c, d, e, f, g end
    end
    return nil
end

function CVars.GetCurrent(name)
    local value = CVars.GetInfo(name)
    if value ~= nil then return value end

    if type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" then
        local ok, result = pcall(C_CVar.GetCVar, name)
        if ok and result ~= nil then return result end
    end
    if type(GetCVar) == "function" then
        local ok, result = pcall(GetCVar, name)
        if ok and result ~= nil then return result end
    end
    return nil
end

function CVars.GetString(name)
    local current = CVars.GetCurrent(name)
    if current ~= nil then return current end

    local _, defaultValue = CVars.GetInfo(name)
    if defaultValue ~= nil then return defaultValue end
    if type(C_CVar) == "table" and type(C_CVar.GetCVarDefault) == "function" then
        local ok, result = pcall(C_CVar.GetCVarDefault, name)
        if ok and result ~= nil then return result end
    end
    if type(GetCVarDefault) == "function" then
        local ok, result = pcall(GetCVarDefault, name)
        if ok and result ~= nil then return result end
    end
    return nil
end

function CVars.Exists(name)
    local value, defaultValue = CVars.GetInfo(name)
    if value ~= nil or defaultValue ~= nil then return true end

    if type(C_CVar) == "table" and type(C_CVar.GetCVarDefault) == "function" then
        local ok, result = pcall(C_CVar.GetCVarDefault, name)
        if ok and result ~= nil then return true end
    end
    if type(GetCVarDefault) == "function" then
        local ok, result = pcall(GetCVarDefault, name)
        if ok and result ~= nil then return true end
    end
    if type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" then
        local ok, result = pcall(C_CVar.GetCVar, name)
        if ok and result ~= nil then return true end
    end
    if type(GetCVar) == "function" then
        local ok, result = pcall(GetCVar, name)
        if ok and result ~= nil then return true end
    end
    return false
end

function CVars.BuildIndex()
    if CVars.commandIndex then return CVars.commandIndex end
    local index = {}
    CVars.commandIndex = index

    local getAll
    if type(C_Console) == "table" and type(C_Console.GetAllCommands) == "function" then
        getAll = C_Console.GetAllCommands
    elseif type(ConsoleGetAllCommands) == "function" then
        getAll = ConsoleGetAllCommands
    end

    if getAll then
        local ok, list = pcall(getAll)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                if type(info) == "table" then
                    local name = info.command or info.name
                    if type(name) == "string" then index[name] = info.commandType end
                elseif type(info) == "string" then
                    index[info] = 0
                end
            end
        end
    end
    return index
end

function CVars.RefreshIndex()
    CVars.commandIndex = nil
    return CVars.BuildIndex()
end

CVars.Resolver = type(_G.FontMagicConsoleResolver) == "table" and _G.FontMagicConsoleResolver or {}
_G.FontMagicConsoleResolver = CVars.Resolver

function CVars.Resolver:BuildNameVariants(name)
    local output, seen = {}, {}
    local function add(candidate)
        if type(candidate) == "string" and candidate ~= "" and not seen[candidate] then
            seen[candidate] = true
            output[#output + 1] = candidate
        end
    end
    if type(name) ~= "string" or name == "" then return output end

    local base = name:gsub("_[vV]%d+$", "")
    for version = 9, 2, -1 do
        add(base .. "_v" .. version)
        add(base .. "_V" .. version)
    end
    add(base)
    add(name)
    return output
end

function CVars.Resolver:TryName(name)
    if type(name) ~= "string" or name == "" then return nil, nil end
    local index = CVars.BuildIndex()
    if index[name] ~= nil then
        if CVars.Exists(name) then return name, 0 end
        return name, index[name]
    end
    if CVars.Exists(name) then return name, 0 end
    return nil, nil
end

function CVars.Resolver:ResolveBestName(name)
    for _, candidate in ipairs(self:BuildNameVariants(name)) do
        local resolved, commandType = self:TryName(candidate)
        if resolved then return resolved, commandType end
    end
    return nil, nil
end

function CVars.Resolve(candidates)
    CVars.BuildIndex()
    if type(candidates) == "string" then
        return CVars.Resolver:ResolveBestName(candidates)
    end
    if type(candidates) == "table" then
        for _, candidate in ipairs(candidates) do
            local name, commandType = CVars.Resolver:ResolveBestName(candidate)
            if name then return name, commandType end
        end
    end
    return nil, nil
end

function CVars.ResolveName(candidates)
    return CVars.Resolve(candidates)
end

function CVars.ResolveTargets(candidates)
    local output, seen = {}, {}
    local function add(name, commandType)
        if type(name) ~= "string" or name == "" then return end
        local key = name .. "#" .. tostring(commandType)
        if seen[key] then return end
        seen[key] = true
        output[#output + 1] = { name = name, commandType = commandType }
    end
    local function resolve(candidate)
        for _, variant in ipairs(CVars.Resolver:BuildNameVariants(candidate)) do
            local name, commandType = CVars.Resolver:TryName(variant)
            if name then add(name, commandType) end
        end
    end
    if type(candidates) == "string" then
        resolve(candidates)
    elseif type(candidates) == "table" then
        for _, candidate in ipairs(candidates) do resolve(candidate) end
    end
    return output
end

function CVars.GetNumber(candidates, fallback)
    local name = CVars.ResolveName(candidates)
    if not name then return fallback end
    local value = tonumber(CVars.GetString(name))
    return value == nil and fallback or value
end

function CVars.Set(name, value)
    if type(name) ~= "string" or name == "" then return false end
    value = tostring(value)
    if type(C_CVar) == "table" and type(C_CVar.SetCVar) == "function" then
        local ok, result = pcall(C_CVar.SetCVar, name, value)
        if ok then return result ~= false end
    end
    if type(SetCVar) == "function" then
        local ok, result = pcall(SetCVar, name, value)
        return ok and result ~= false
    end
    return false
end

function CVars.Apply(name, commandType, value)
    if type(name) ~= "string" or name == "" then return false end
    value = tostring(value)
    if commandType == nil or commandType == 0 then return CVars.Set(name, value) end
    if type(ConsoleExec) == "function" then
        local ok, result = pcall(ConsoleExec, name .. " " .. value, false)
        return ok and result ~= false
    end
    return false
end

function CVars.ApplyAtomic(targets, value)
    if type(targets) ~= "table" then return false end
    local captured = {}
    for _, target in ipairs(targets) do
        if type(target) == "table" and target.commandType == 0
            and type(target.name) == "string" and target.name ~= "" then
            local current = CVars.GetCurrent(target.name)
            if current == nil then return false end
            captured[#captured + 1] = {
                name = target.name,
                commandType = target.commandType,
                value = tostring(current),
            }
        end
    end
    if #captured == 0 then return false end

    for index, entry in ipairs(captured) do
        if not CVars.Apply(entry.name, entry.commandType, value) then
            local restored = true
            local recovery = {}
            for rollback = index - 1, 1, -1 do
                local prior = captured[rollback]
                if not CVars.Apply(prior.name, prior.commandType, prior.value) then
                    recovery[prior.name] = prior.value
                    restored = false
                end
            end
            return false, restored, recovery
        end
    end
    return true
end

function CVars.ApplyAtomicWithRecovery(targets, value)
    local applied, restored, recovery = CVars.ApplyAtomic(targets, value)
    if applied then return true, true end
    if type(recovery) ~= "table" or next(recovery) == nil then
        return false, restored and true or false
    end

    -- Retry a transient rollback rejection once immediately. If a client still
    -- refuses the exact prior value, serialize only FontMagic's combat-text
    -- scope so the next login/reset can finish restoring it safely.
    local pending = {}
    for name, prior in pairs(recovery) do
        if not CVars.Apply(name, 0, prior) then
            pending[name] = tostring(prior)
        end
    end
    if next(pending) ~= nil then
        local db = rawget(_G, "FontMagicDB")
        if type(db) ~= "table" then
            db = {}
            rawset(_G, "FontMagicDB", db)
        end
        if type(db.combatResetRecovery) ~= "table" then db.combatResetRecovery = {} end
        for name, prior in pairs(pending) do
            local allowed = type(FM.Database) == "table"
                and type(FM.Database.IsCombatTextCVarName) == "function"
                and FM.Database.IsCombatTextCVarName(name)
            if not allowed and type(name) == "string" then
                local lowered = name:lower()
                allowed = lowered == "enablecombattext"
                    or lowered == "enablefloatingcombattext"
                    or lowered:find("^floatingcombattext") ~= nil
                    or lowered == "worldtextscale"
                    or lowered:match("^worldtextscale_v%d+$") ~= nil
                    or lowered == "worldtextgravity"
                    or lowered:match("^worldtextgravity_v%d+$") ~= nil
                    or lowered == "worldtextrampduration"
                    or lowered:match("^worldtextrampduration_v%d+$") ~= nil
            end
            if allowed then db.combatResetRecovery[name] = prior end
        end
        if next(db.combatResetRecovery) == nil then db.combatResetRecovery = nil end
        return false, false
    end
    return false, true
end
