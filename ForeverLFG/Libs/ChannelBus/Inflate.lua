-- Copyright (c) 2026 WerkoDev. All rights reserved.
-- Independent bounded raw DEFLATE decoder, based on the format in RFC 1951.
-- Never calls native DecompressString (its allocation limit is too large).
local Net = _G.ChannelBus
if not Net.loading then return end
local floor, byte, char = math.floor, string.byte, string.char
local powers = {}
for i = 0, 16 do powers[i] = 2 ^ i end
local lengthBase = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local lengthBits = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local distanceBase = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local distanceBits = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local order = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

local function tree(lengths, allowEmpty, codeLengths)
    local counts, maps, max, used = {}, {}, 0, 0
    for _, len in ipairs(lengths) do
        if len < 0 or len > 15 then error("invalid-huffman-length") end
        if len > 0 then
            counts[len] = (counts[len] or 0) + 1
            max, used = math.max(max, len), used + 1
        end
    end
    if used == 0 and allowEmpty then return { max = 0, maps = {} } end
    local left = 1
    for len = 1, 15 do
        left = left * 2 - (counts[len] or 0)
        if left < 0 then error("oversubscribed-huffman") end
    end
    if used == 0 or (left > 0 and (codeLengths or max ~= 1)) then error("incomplete-huffman") end
    local nextCode, code = {}, 0
    for len = 1, max do
        code = (code + (counts[len - 1] or 0)) * 2
        nextCode[len], maps[len] = code, {}
    end
    for index, len in ipairs(lengths) do
        if len > 0 then
            maps[len][nextCode[len]] = index - 1
            nextCode[len] = nextCode[len] + 1
        end
    end
    return { max = max, maps = maps }
end

local fixedLit, fixedDist
do
    local lit, dist = {}, {}
    for sym = 0, 287 do
        lit[sym + 1] = sym <= 143 and 8 or sym <= 255 and 9 or sym <= 279 and 7 or 8
    end
    for sym = 0, 31 do dist[sym + 1] = 5 end
    fixedLit, fixedDist = tree(lit), tree(dist)
end

local function inflate(source, limit)
    if type(source) ~= "string" or #source > Net.Protocol.maxMessageBytes or type(limit) ~= "number"
        or limit < 0 or limit > Net.Protocol.maxRawBytes then error("inflate-limit") end
    local pos, bits, held, operations = 1, 0, 0, 0
    local output, count, blocks = {}, 0, 0
    local function read(n)
        operations = operations + 1
        if operations > math.max(150000,limit*20) then error("inflate-work-limit") end
        while held < n do
            local value = byte(source, pos)
            if not value then error("truncated-deflate") end
            bits, held, pos = bits + value * powers[held], held + 8, pos + 1
        end
        local value = bits % powers[n]
        bits, held = floor(bits / powers[n]), held - n
        return value
    end
    local function symbol(t)
        local code = 0
        for len = 1, t.max do
            code = code * 2 + read(1)
            local value = t.maps[len][code]
            if value ~= nil then return value end
        end
        error("invalid-huffman-code")
    end
    local function emit(value)
        if count >= limit then error("inflate-output-limit") end
        count = count + 1
        output[count] = value
    end
    local final
    repeat
        blocks = blocks + 1
        if blocks > math.max(256,math.ceil(limit/32)) then error("inflate-block-limit") end
        final = read(1)
        local kind = read(2)
        if kind == 0 then
            bits, held = 0, 0
            local len, inverse = read(16), read(16)
            if len + inverse ~= 65535 then error("stored-length") end
            if count + len > limit then error("inflate-output-limit") end
            for _ = 1, len do emit(char(read(8))) end
        elseif kind == 1 or kind == 2 then
            local lit, dist = fixedLit, fixedDist
            if kind == 2 then
                local nl, nd, nc = read(5) + 257, read(5) + 1, read(4) + 4
                if nl > 286 then error("literal-count") end
                local cl = {}
                for i = 1, 19 do cl[i] = 0 end
                for i = 1, nc do cl[order[i] + 1] = read(3) end
                local ct, lengths = tree(cl, false, true), {}
                while #lengths < nl + nd do
                    local value = symbol(ct)
                    if value <= 15 then lengths[#lengths + 1] = value
                    else
                        local previous, repeats = 0, 0
                        if value == 16 then
                            previous = lengths[#lengths]
                            if previous == nil then error("repeat-without-length") end
                            repeats = read(2) + 3
                        elseif value == 17 then repeats = read(3) + 3
                        elseif value == 18 then repeats = read(7) + 11
                        else error("code-length-symbol") end
                        if #lengths + repeats > nl + nd then error("code-length-overrun") end
                        for _ = 1, repeats do lengths[#lengths + 1] = previous end
                    end
                end
                local ll, dl = {}, {}
                for i = 1, nl do ll[i] = lengths[i] end
                for i = 1, nd do dl[i] = lengths[nl + i] end
                if ll[257] == 0 then error("missing-end-symbol") end
                lit, dist = tree(ll), tree(dl, true)
            end
            while true do
                local value = symbol(lit)
                if value == 256 then break end
                if value < 256 then emit(char(value))
                else
                    local index = value - 256
                    if index > 29 then error("reserved-length") end
                    local len = lengthBase[index] + read(lengthBits[index])
                    local d = symbol(dist) + 1
                    if d > 30 then error("reserved-distance") end
                    local distance = distanceBase[d] + read(distanceBits[d])
                    if distance > count or count + len > limit then error("invalid-match") end
                    for _ = 1, len do emit(output[count - distance + 1]) end
                end
            end
        else error("reserved-block") end
    until final == 1
    if pos ~= #source + 1 then error("trailing-deflate-data") end
    return table.concat(output)
end

function Net.Inflate(source, limit)
    local ok, result = pcall(inflate, source, limit)
    if ok then return result end
    return nil, tostring(result)
end
