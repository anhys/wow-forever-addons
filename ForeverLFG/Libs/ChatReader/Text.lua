local _,Root=...
local NS=Root.ChatReader or Root
NS.version = "0.1.5"
NS.Array = function(t) return setmetatable(t or {}, {__jsonarray=true}) end
function NS.Clone(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=NS.Clone(x) end
    return setmetatable(out,getmetatable(v))
end
local T = {}; NS.Text = T
local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝŒŠŽẞ"
local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяàáâãäåæçèéêëìíîïñòóôõöøùúûüýœšžß"
local map, chars = {}, {}
for c in lower:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=c end
local i=0
for c in upper:gmatch("[%z\1-\127\194-\244][\128-\191]*") do i=i+1;map[c]=chars[i] end
function T.Fold(s)
    -- string.lower and %p/%s may follow the host C locale and corrupt UTF-8 bytes.
    return (s:gsub("[A-Z]",function(c) return string.char(c:byte()+32) end):gsub("[\194-\244][\128-\191]*", map))
end
function T.Plain(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " "):gsub("|A.-|a", " "))
end
function T.Normalize(s)
    s=T.Fold(T.Plain(s))
    for _,p in ipairs({"’","‘","“","”","，","。","！","？","：","；","、","—","–"}) do s=s:gsub(p," ") end
    return " "..s:gsub("[%z\1-\47\58-\64\91-\96\123-\127]"," "):gsub(" +"," "):match("^ *(.-) *$").." "
end
-- Indices refer to this normalized representation, never to the raw message.
function T.Find(s,term,substring)
    local stem=term:sub(-1)=="*"
    if stem then term=term:sub(1,-2) end
    term=T.Normalize(term):match("^ (.-) $")
    if term=="" then return end
    local from=1
    while true do
        local a,b=s:find(term,from,true);if not a then return end
        if substring or (s:sub(a-1,a-1)==" " and (stem or s:sub(b+1,b+1)==" ")) then return a,b end
        from=b+1
    end
end
function T.Links(raw)
    local prefix="fcpref"
    while raw:find(prefix,1,true) do prefix=prefix.."z" end
    local links=NS.Array();local masked, cursor={},1
    while true do
        local a,b,kind,payload,caption=raw:find("|H([%a]+):([^|]*)|h(.-)|h",cursor)
        if not a then masked[#masked+1]=raw:sub(cursor);break end
        local index=#links+1
        local link={index=index,kind=kind,payload=payload,caption=caption,raw=raw:sub(a,b),startByte=a,endByte=b,fields=NS.Array()}
        for field in (payload..":"):gmatch("([^:]*):") do
            link.fields[#link.fields+1]=field
            if field:match("^Player%-%S+$") then link.ownerGUID=field end
        end
        if kind=="item" or kind=="spell" or kind=="enchant" or kind=="quest" then
            local id=tonumber(link.fields[1]);if id and id>0 and id%1==0 then link.id=id end
        end
        links[index]=link;masked[#masked+1]=raw:sub(cursor,a-1);masked[#masked+1]=" "..prefix..index.."z "
        cursor=b+1
    end
    return links,T.Plain(table.concat(masked)),prefix
end
local function escape(s)
    -- No literal pipe reaches the game's EditBox: copying must not interpret links/colors.
    return '"'..s:gsub('[%z\1-\31\\"|]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',c:byte())
    end)..'"'
end
function NS.JSON(v,seen)
    local kind=type(v)
    if kind=="string" then return escape(v) elseif kind=="boolean" then return tostring(v)
    elseif kind=="number" then return v==v and v~=math.huge and v~=-math.huge and tostring(v) or "null"
    elseif kind~="table" then return "null" end
    seen=seen or {};assert(not seen[v],"cyclic export");seen[v]=true
    local out={};local array=getmetatable(v) and getmetatable(v).__jsonarray
    if array then for n=1,#v do out[#out+1]=NS.JSON(v[n],seen) end
    else
        local keys={};for k in pairs(v) do if type(k)=="string" then keys[#keys+1]=k end end;table.sort(keys)
        for _,k in ipairs(keys) do out[#out+1]=escape(k)..":"..NS.JSON(v[k],seen) end
    end
    seen[v]=nil;return (array and "[" or "{")..table.concat(out,",")..(array and "]" or "}")
end
function NS.Readable(v)
    if canaccessvalue then local ok,value=pcall(canaccessvalue,v);if not ok or not value then return false end end
    if issecretvalue then local ok,value=pcall(issecretvalue,v);if not ok or value then return false end end
    return true
end
