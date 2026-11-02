local _, I = ...
I.VERSION = "0.5.5"
I.DATA_BUILD = "1.60.1.70291"
-- Only builds checked against the retained Achievement.db2 evidence belong
-- here. Do not treat an unknown patch as checked just because the API replies.
I.DATA_BUILDS = {["1.60.1.70124"]=true,["1.60.1.70291"]=true}
I.DISCLAIMER = "Figures may be inaccurate, incomplete, or out of date. Game counters, resets, and addon errors can affect the results. Use them as a reference, not proof of a player's wealth or misconduct."
I.DATA_SOURCE = "Blizzard statistics API"
I.DATA_SOURCE_NOTICE = "IRS reads Blizzard's statistics API directly; it does not depend on the Statistics page. Values are captured as returned by the client and are not independently verified."
I.DATA_SOURCE_VERIFY = "This check confirms receipt and safe parsing only. It cannot prove that Blizzard's underlying counters are current, complete or correct."
I.VERIFICATION_NOTICE = "Fetch status describes data availability, not the accuracy of the game's counters."
I.INCOME_SOURCES = "Income breakdown: gold looted, quest rewards, vendor sales and auction earnings."
I.INCOME_TRANSFERS = "The breakdown does not itemize gifts, transfers from alts or friends, or player trades (like normal item sales, selling ports or summons, etc.)."
I.INCOME_DISCLAIMER = "A difference does not necessarily indicate wrongdoing."
I.INCOME_TOTAL_NOTE = "Total gold acquired is Blizzard's separate statistic; IRS does not calculate it by adding the four income rows. These counters are not a complete record of gold received."
-- All 36 Achievement rows match across the checked builds above. Monetary
-- quantities use copper. Only recognized, complete coin markup is decoded.
I.fields = {
    {"acquired",328,"Total gold acquired",true},
    {"peak",334,"Most gold ever owned",true},
    {"looted",333,"Gold looted",true},
    {"quests",326,"Quest rewards",true},
    {"vendors",921,"Vendor sales",true},
    {"auctions",919,"Auction earnings",true},
    {"daily",753,"Average earned per day",true},
    {"travel",1146,"Travel",true},
    {"postage",1148,"Postage",true},
    {"barber",1147,"Barber shops",true},
    {"respec",1150,"Talent respecs",true},
    {"posted",329,"Auctions posted"},
    {"purchases",330,"Auction purchases"},
    {"largestSale",332,"Largest auction sale",true},
    {"largestBid",331,"Largest auction bid",true},
    {"questCount",98,"Quests completed"},
    {"kills",107,"Creatures killed"},
    {"dungeons",932,"Dungeons entered"},
    {"deaths",60,"Total deaths"},
    {"disenchanted",181,"Items disenchanted"},
    {"disenchantMaterials",183,"Disenchant materials"},
    {"fishCaught",1518,"Fish caught"},
    {"flights",349,"Flight paths taken"},
    {"honorableKills",588,"Honorable kills"},
    {"firstAid",281,"First Aid"}, {"cooking",1524,"Cooking"}, {"fishing",1519,"Fishing"},
    {"alchemy",1527,"Alchemy",false,true}, {"blacksmithing",1532,"Blacksmithing",false,true},
    {"enchanting",1535,"Enchanting",false,true}, {"leatherworking",1536,"Leatherworking",false,true},
    {"mining",1537,"Mining",false,true}, {"herbalism",1538,"Herbalism",false,true},
    {"skinning",1541,"Skinning",false,true}, {"tailoring",1542,"Tailoring",false,true},
    {"engineering",1544,"Engineering",false,true},
}
I.byKey = {}
for _, field in ipairs(I.fields) do I.byKey[field[1]] = field end
function I.number(value)
    if type(issecretvalue)=="function" and issecretvalue(value) then return nil end
    local n = tonumber(value)
    if n and n==n and n>=0 and n<=9007199254740991 then return n end
end
function I.text(value)
    local text=tostring(value or ""):gsub("|","||"):gsub("[%c]"," ")
    return text
end
function I.quantity(n)
    if n==nil then return "Unavailable" end
    local grouped=string.format("%.0f",math.floor(n)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
    return grouped
end
function I.money(n,plain)
    if n==nil then return "Unavailable" end
    n=math.floor(n)
    local g,s,c=math.floor(n/10000),math.floor(n/100)%100,n%100
    if plain then return I.quantity(g).."g "..s.."s "..c.."c" end
    return "|cffffd17a"..I.quantity(g).."g|r |cffcbd5e1"..s.."s|r |cffcb9977"..c.."c|r"
end
local function plainIcon(icon)
    -- Keep currency units when copying Blizzard's formatted money text.
    local name=icon:lower()
    if name:find("gold",1,true) then return "g " end
    if name:find("silver",1,true) then return "s " end
    if name:find("copper",1,true) then return "c " end
    return " [icon] "
end
local function integerText(text)
    -- Coin amounts are integers. Accept grouping only in complete groups of
    -- three, never interpret an ambiguous decimal or translated unit name.
    text=text:gsub("\194\160"," "):gsub("\226\128\175"," "):match("^%s*(.-)%s*$")
    if text:match("^%d+$") then return I.number(text) end
    local first,separator,rest=text:match("^(%d%d?%d?)([,. ])(.*)$")
    if not first then return nil end
    local digits=first
    while true do
        local group=rest:sub(1,3)
        if not group:match("^%d%d%d$") then return nil end
        digits=digits..group
        if #rest==3 then return I.number(digits) end
        if rest:sub(4,4)~=separator then return nil end
        rest=rest:sub(5)
    end
end
function I.parseMoney(raw)
    local numeric=I.number(raw)
    if numeric then return numeric%1==0 and numeric or nil end
    if type(raw)~="string" or #raw>400 then return nil end
    local text=raw:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    local units={gold={"g",10000},silver={"s",100},copper={"c",1}}
    local function token(icon,atlas)
        local name=icon:lower():gsub("\\","/")
        local metal
        if atlas then metal=name:match("^:?coin%-(%a+):")
        else metal=name:match("^interface/moneyframe/ui%-(%a+)icon:") end
        return units[metal] and ("\001"..units[metal][1].."\002") or "?"
    end
    text=text:gsub("|T(.-)|t",function(icon)return token(icon,false)end)
        :gsub("|A(.-)|a",function(icon)return token(icon,true)end)
    local values={g=10000,s=100,c=1};local total,last,position,count=0,10001,1,0
    while true do
        local first,finish,unit=text:find("\001([gsc])\002",position)
        if not first then break end
        local amount=integerText(text:sub(position,first-1));local multiplier=values[unit]
        if amount==nil or multiplier>=last or (unit~="g" and amount>99) then return nil end
        total=total+amount*multiplier;last=multiplier;position=finish+1;count=count+1
    end
    if count>0 and text:sub(position):match("^%s*$") then return I.number(total) end
end
function I.entry(raw,money)
    if type(issecretvalue)=="function" and issecretvalue(raw) then return nil end
    local n
    if money then n=I.parseMoney(raw)
    else
        n=I.number(raw)
        if n and n%1~=0 then n=nil end
        if not n and type(raw)=="string" then n=integerText(raw) end
    end
    if n~=nil then return {number=n} end
    if type(raw)~="string" or #raw>400 or not raw:find("%d") then return nil end
    -- Keep unknown localized formats readable, but inert and out of arithmetic.
    return {display=I.text(raw)}
end
I.reasons={notReported="WoW returned no value; this is not a confirmed zero.",
    unsupported="This client does not expose this statistic.",skipped="WoW marked this statistic as hidden or skipped.",
    unreadable="WoW returned a value that could not be read safely.",readError="The game's statistics API could not read this counter.",
    apiUnavailable="This client's statistics API is unavailable."}
function I.reason(snapshot,key)
    local reason=snapshot and snapshot.unavailable and snapshot.unavailable[key]
    return I.reasons[reason] or "No readable value was captured for this statistic; this is not a confirmed zero."
end
function I.value(snapshot,key,plain)
    local entry=snapshot and snapshot.values and snapshot.values[key]
    if not entry then
        return snapshot and snapshot.unavailable and snapshot.unavailable[key]=="notReported" and "Not reported" or "Unavailable"
    end
    if entry.number~=nil then
        return I.byKey[key] and I.byKey[key][4] and I.money(entry.number,plain) or I.quantity(entry.number)
    end
    local display=entry.display or "Unavailable"
    if plain then
        return (display:gsub("|T(.-)|t",plainIcon):gsub("|A(.-)|a",plainIcon):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+$",""))
    end
    return display
end
function I.numeric(snapshot,key)
    return snapshot and snapshot.values and snapshot.values[key] and snapshot.values[key].number
end
function I.gap(snapshot)
    local peak,total=I.numeric(snapshot,"peak"),I.numeric(snapshot,"acquired")
    if peak==nil or total==nil then return nil end
    return math.max(0,peak-total), peak>0 and math.min(1,total/peak) or nil
end
function I.sourceStatus(snapshot)
    local client=snapshot and snapshot.build or I.build()
    local selfAPI=type(GetStatistic)=="function"
    local comparisonAPI=type(GetComparisonStatistic)=="function"
    local supported=type(client)=="string" and client:match("^1%.60%.")~=nil
    local exact=client==I.DATA_BUILD
    local definitionsChecked=I.DATA_BUILDS[client]==true
    -- Current API availability cannot tell us what existed for an old capture.
    local apiMissing=not snapshot and (not selfAPI or not comparisonAPI)
    local warning=not supported or apiMissing or not definitionsChecked
    local reason
    if not supported then reason="This client branch is not verified by IRS."
    elseif apiMissing then reason="One or more Blizzard statistics APIs are unavailable."
    elseif not definitionsChecked then reason="The client build differs from the builds whose statistic definitions IRS has checked; counters may have changed or be incomplete." end
    return {source=I.DATA_SOURCE,client=client,definitions=definitionsChecked and client or I.DATA_BUILD,supported=supported,
        selfAPI=selfAPI,comparisonAPI=comparisonAPI,exact=exact,definitionsChecked=definitionsChecked,warning=warning,reason=reason}
end
function I.checkCapture(snapshot,previous)
    -- Reuse the completed capture. Never query a released comparison slot or
    -- count a wallet value/display-only text as a readable statistics counter.
    local result={numeric=0,displayOnly=0,missing=0,compared=0,changed=0,lost=0}
    if not previous or previous.guid~=snapshot.guid then result.baseline="first"
    elseif previous.build~=snapshot.build then result.baseline="build"
    elseif previous.own~=snapshot.own then result.baseline="source" end
    for _,field in ipairs(I.fields) do
        local key=field[1];local entry=snapshot.values[key]
        local value=I.numeric(snapshot,key)
        if value~=nil then result.numeric=result.numeric+1
        elseif entry then result.displayOnly=result.displayOnly+1
        else result.missing=result.missing+1 end
        if not result.baseline then
            local old=I.numeric(previous,key)
            if old~=nil then
                if value~=nil then
                    result.compared=result.compared+1
                    if old~=value then result.changed=result.changed+1 end
                else result.lost=result.lost+1 end
            end
        end
    end
    return result
end
function I.read(subject, own)
    local getter
    if own then getter=GetStatistic else getter=GetComparisonStatistic end
    local snapshot={guid=subject.guid,name=subject.name,realm=subject.realm,class=subject.class,
        level=subject.level,guild=subject.guild,build=I.build(),at=GetServerTime(),own=own,values={},unavailable={},available=0}
    for _,field in ipairs(I.fields) do
        local valid=true
        if C_AchievementInfo and type(C_AchievementInfo.IsValidAchievement)=="function" then
            local ok,yes=pcall(C_AchievementInfo.IsValidAchievement,field[2]); valid=ok and yes
        end
        if valid and type(getter)=="function" then
            local ok,raw,skip=pcall(getter,field[2])
            if ok and not (type(issecretvalue)=="function" and issecretvalue(raw)) and not skip then
                snapshot.values[field[1]]=I.entry(raw,field[4])
                snapshot.unavailable[field[1]]=(raw==nil or raw=="" or raw=="--" or raw=="-") and "notReported" or "unreadable"
            else snapshot.unavailable[field[1]]=not ok and "readError" or skip and "skipped" or "unreadable" end
        else snapshot.unavailable[field[1]]=not valid and "unsupported" or "apiUnavailable" end
        if snapshot.values[field[1]] then
            snapshot.available=snapshot.available+1;snapshot.unavailable[field[1]]=nil
        end
    end
    if own and type(GetMoney)=="function" then
        local ok,n=pcall(GetMoney);if ok then snapshot.wallet=I.number(n) end
    end
    return snapshot
end
function I.report(s)
    if not s then return "No snapshot loaded." end
    local source=I.sourceStatus(s)
    local lines={"Forever IRS · character statistics","",I.INCOME_DISCLAIMER:upper(),I.INCOME_SOURCES,I.INCOME_TRANSFERS,"",
        "Accuracy disclaimer: "..I.DISCLAIMER,"",s.name..(s.realm~="" and " - "..s.realm or ""),
        "Observed: "..date("%Y-%m-%d %H:%M:%S",s.at).." · client "..s.build,
        "Data source: "..source.source.." (the Statistics page is not used)",
        "Statistic definitions: "..source.definitions,
        source.reason and "WARNING: "..source.reason or "Statistic definitions checked for this capture's build; accuracy is not verified.",
        I.DATA_SOURCE_VERIFY,
        "Current wallet: "..(s.own and I.money(s.wallet,true) or "Not exposed for other players")}
    if I.verificationView then
        local check=I.verificationView(s)
        lines[#lines+1]="Fetch check: "..check.title
        lines[#lines+1]=check.detail
    end
    for _,f in ipairs(I.fields) do
        lines[#lines+1]=f[3]..(f[5] and " (highest recorded)" or "")..": "..I.value(s,f[1],true)
            ..(not s.values[f[1]] and " ("..I.reason(s,f[1])..")" or "")
    end
    local assessment=I.assess(s)
    lines[#lines+1]=""
    lines[#lines+1]="Activity counters: "..assessment.title
    lines[#lines+1]=assessment.summary
    lines[#lines+1]=assessment.coverage
    for _,line in ipairs(assessment.evidence) do lines[#lines+1]="- "..line end
    lines[#lines+1]=I.ASSESSMENT_NOTE
    local gap=I.gap(s)
    lines[#lines+1]="Peak minus recorded acquired gold (minimum zero): "..I.money(gap,true)
    lines[#lines+1]=I.INCOME_SOURCES
    lines[#lines+1]=I.INCOME_TOTAL_NOTE
    lines[#lines+1]=I.INCOME_TRANSFERS
    lines[#lines+1]="Acquired gold is a gross figure, not profit. Missing data and counter resets can also affect the difference."
    lines[#lines+1]="Unavailable is not zero. Counter coverage and resets depend on the game."
    return table.concat(lines,"\n")
end
