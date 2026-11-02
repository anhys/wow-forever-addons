-- Copyright (c) 2026 WerkoDev. All rights reserved.
-- One registry for standalone and embedded copies; no SavedVariables queues.
local MAJOR, MINOR = 1, 4
local old = _G.ChannelBus
if old and old.major ~= MAJOR then error("ChannelBus: incompatible major") end
if old and old.minor >= MINOR then old.loading = false; return end
if old and old._runtime and old._runtime.protocol ~= 4 then
    old.loading = false
    error("ChannelBus: protocol upgrade requires replacing old copies and /reload")
end
local Net = old or { major = MAJOR, Bus = {}, Codec = {} }
_G.ChannelBus = Net
Net.minor, Net.loading = MINOR, true
Net.version = "0.5.0"
Net.ObjectLimits={nodes=160000,depth=24,bytes=524288,stringBytes=8192}
Net.Fragments=Net.Fragments or {}

function Net.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

-- Copy plain data and produce an unambiguous semantic representation.
-- No metatables, cycles, sparse arrays, mixed array/object keys or secret values.
function Net.Copy(value, limits)
    limits = limits or {nodes=512,depth=8,bytes=8192}
    local active, nodes, bytes = {}, 0, 0
    local function walk(v, depth)
        if Net.IsSecret(v) then error("secret-value") end
        nodes = nodes + 1
        if nodes > limits.nodes or depth > limits.depth then error("data-limit") end
        local typ = type(v)
        if typ == "string" then
            bytes = bytes + #v
            if #v > (limits.stringBytes or 4096) or bytes > limits.bytes then error("string-limit") end
            return v, "s" .. #v .. ":" .. v
        elseif typ == "boolean" then
            return v, v and "b1" or "b0"
        elseif typ == "number" then
            if v ~= v or v == math.huge or v == -math.huge then error("invalid-number") end
            return v, "n" .. string.format("%.17g", v) .. ";"
        elseif typ ~= "table" or getmetatable(v)~=nil or active[v] then
            error("unsupported-value")
        end
        active[v] = true
        local keys, numeric, strings = {}, false, false
        for k in pairs(v) do
            if Net.IsSecret(k) then error("secret-key") end
            if type(k) == "string" then strings = true
            elseif type(k) == "number" and k >= 1 and k <= limits.nodes and k == math.floor(k) then numeric = true
            else error("invalid-key") end
            keys[#keys + 1] = k
            if #keys > limits.nodes then error("data-limit") end
        end
        if numeric and strings then error("mixed-table") end
        table.sort(keys)
        local copy, canonical = {}, { numeric and "a[" or "o{" }
        for i, k in ipairs(keys) do
            if numeric and k ~= i then error("sparse-array") end
            local _, key = walk(k, depth + 1)
            local item, text = walk(v[k], depth + 1)
            copy[k] = item
            canonical[#canonical + 1] = key .. text
        end
        canonical[#canonical + 1] = numeric and "]" or "}"
        active[v] = nil
        return copy, table.concat(canonical)
    end
    return walk(value, 0)
end

function Net.Adler(text)
    local a, b = 1, 0
    for i = 1, #text do
        a = (a + string.byte(text, i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%08x", b * 65536 + a)
end
