-- Copyright (c) 2026 WerkoDev. All rights reserved.
local Net = _G.ChannelBus
if not Net.loading then return end
local Codec = Net.Codec
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local reverse = {}
for i = 1, 64 do reverse[alphabet:sub(i, i)] = i - 1 end

function Codec.Base64(source)
    local out = {}
    for i = 1, #source, 3 do
        local a, b, c = string.byte(source, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local x, y, z, w = math.floor(n / 262144), math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = alphabet:sub(x + 1, x + 1) .. alphabet:sub(y + 1, y + 1)
            .. (b and alphabet:sub(z + 1, z + 1) or "=") .. (c and alphabet:sub(w + 1, w + 1) or "=")
    end
    return table.concat(out)
end

function Codec.Unbase64(source)
    if #source > Net.Protocol.maxMessageBytes or #source % 4 ~= 0 then return nil, "base64-size" end
    local out = {}
    for i = 1, #source, 4 do
        local x, y, z, w = source:sub(i,i), source:sub(i+1,i+1), source:sub(i+2,i+2), source:sub(i+3,i+3)
        local a, b, c, d = reverse[x], reverse[y], reverse[z], reverse[w]
        local last = i + 3 == #source
        if not a or not b or (z == "=" and (not last or w ~= "=" or b % 16 ~= 0))
            or (w == "=" and (not last or (c and c % 4 ~= 0)))
            or (z ~= "=" and not c) or (w ~= "=" and not d) then return nil, "invalid-base64" end
        local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        out[#out + 1] = string.char(math.floor(n / 65536))
        if z ~= "=" then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if w ~= "=" then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

Codec.WireLimits={nodes=170000,depth=28,bytes=524288,stringBytes=8192}
local defaults={enabled=true,level="OptimizeForSize",minSavingsBytes=1}
local function pack16(n) return string.char(math.floor(n/256),n%256) end
local function pack32(n)
    return string.char(math.floor(n/16777216),math.floor(n/65536)%256,math.floor(n/256)%256,n%256)
end
local function wire(mode,raw,body)
    -- Header входит в Base64 вместе с бинарным CBOR/DEFLATE, NUL в cstring отсутствует.
    if #raw<=8192 then
        return "3"..Codec.Base64(mode..pack16(#raw)..pack32(tonumber(Net.Adler(raw),16))..body)
    end
    return "5"..Codec.Base64(mode..pack32(#raw)..pack32(tonumber(Net.Adler(raw),16))..body)
end
function Codec.Encode(frame,compression)
    compression=compression or defaults
    local api=C_EncodingUtil
    if not api or not api.SerializeCBOR or (compression.enabled and not api.CompressString) then
        return nil,"codec-unavailable"
    end
    local valid=pcall(Net.Copy,frame,Codec.WireLimits)
    if not valid then return nil,"invalid-frame" end
    local ok,raw=pcall(api.SerializeCBOR,frame)
    if not ok or type(raw)~="string" then return nil,"serialize-failed" end
    if #raw<1 or #raw>Net.Protocol.maxRawBytes then return nil,"raw-size",#raw end
    local encoded,mode=wire("R",raw,raw),"R"
    if compression.enabled then
        local methods=Enum and Enum.CompressionMethod
        local levels=Enum and Enum.CompressionLevel
        if not methods or methods.Deflate==nil or not levels or levels[compression.level]==nil then
            return nil,"compression-enum-unavailable"
        end
        local success,zipped=pcall(api.CompressString,raw,methods.Deflate,levels[compression.level])
        if not success or type(zipped)~="string" then return nil,"compress-failed" end
        if Net.Inflate(zipped,#raw)~=raw then return nil,"deflate-self-check" end
        local compressed=wire("C",raw,zipped)
        if #compressed<#encoded and #encoded-#compressed>=compression.minSavingsBytes then
            encoded,mode=compressed,"C"
        end
    end
    return {text=encoded,mode=mode,rawLength=#raw,checksum=Net.Adler(raw)}
end
function Codec.Decode(text)
    if Net.IsSecret(text) or type(text)~="string" or #text>Net.Protocol.maxMessageBytes or (text:sub(1,1)~="3" and text:sub(1,1)~="5") then
        return nil,"packet-format"
    end
    local binary,err=Codec.Unbase64(text:sub(2))
    if not binary then return nil,err end
    local extended=text:sub(1,1)=="5"
    local header=extended and 9 or 7
    if #binary<=header then return nil,"header-size" end
    local mode=binary:sub(1,1)
    local a,b,c,d,e,f,g,h=string.byte(binary,2,9)
    local size=extended and (a*16777216+b*65536+c*256+d) or (a*256+b)
    local checksum=extended and string.format("%08x",e*16777216+f*65536+g*256+h) or string.format("%08x",c*16777216+d*65536+e*256+f)
    if (mode~="C" and mode~="R") or size<1 or size>(extended and Net.Protocol.maxRawBytes or 8192) then return nil,"header-format" end
    local raw=binary:sub(header+1)
    if mode=="C" then raw,err=Net.Inflate(raw,size) end
    if not raw then return nil,err end
    if #raw~=size or Net.Adler(raw)~=checksum then return nil,"integrity" end
    local api=C_EncodingUtil
    if not api or not api.DeserializeCBOR then return nil,"codec-unavailable" end
    local ok,frame=pcall(api.DeserializeCBOR,raw)
    if not ok or type(frame)~="table" then return nil,"deserialize-failed" end
    local valid,copy=pcall(Net.Copy,frame,Codec.WireLimits)
    if not valid then return nil,"invalid-data" end
    return copy,nil,{mode=mode,rawLength=size,checksum=checksum,packetID=checksum..":"..#text}
end

