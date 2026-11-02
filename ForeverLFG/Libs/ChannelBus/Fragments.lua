-- Copyright (c) 2026 WerkoDev. All rights reserved.
local Net=_G.ChannelBus
if not Net.loading then return end
local F=Net.Fragments
function F.Parts(wire,id,packetBytes,maxParts)
    if #wire<=packetBytes then return {wire} end
    local checksum=Net.Adler(wire)
    local header=table.concat({"4",id,maxParts,maxParts,#wire,checksum},"|").."|"
    local width=packetBytes-#header
    if width<1 then return nil,"fragment-header-size" end
    local total=math.ceil(#wire/width)
    if total>maxParts then return nil,"part-limit" end
    local parts={}
    for i=1,total do
        parts[i]=table.concat({"4",id,i,total,#wire,checksum},"|").."|"..wire:sub((i-1)*width+1,i*width)
    end
    return parts
end
function F.Parse(wire)
    if Net.IsSecret(wire) or type(wire)~="string" or #wire>Net.Protocol.maxPacketBytes then return end
    local id,index,total,length,checksum,chunk=wire:match("^4|([%w_%-]+%.[%x]+)|(%d+)|(%d+)|(%d+)|(%x%x%x%x%x%x%x%x)|(.*)$")
    index,total,length=tonumber(index),tonumber(total),tonumber(length)
    if not id or #id>48 or not index or total<2 or total>Net.Protocol.maxParts or index<1 or index>total
        or length<1 or length>Net.Protocol.maxMessageBytes or #chunk<1 or #chunk>length then return end
    return {id=id,index=index,total=total,length=length,checksum=checksum,chunk=chunk}
end
