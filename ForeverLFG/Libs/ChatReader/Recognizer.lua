local _,Root=...
local NS=Root.ChatReader or Root
local T,L,A=NS.Text,NS.Lexicon,NS.Array
local R={version="rules-3"};NS.Recognizer=R
local function hits(text)
    local found={}
    for _,r in ipairs(L.rules) do
        local a,b=T.Find(text,r.term,r.substring)
        if a then
            local bucket=found[r.action] or A();found[r.action]=bucket
            bucket[#bucket+1]={rule=r.id,locale=r.locale,term=r.term,startByte=a,endByte=b,kind="text_rule"}
        end
    end
    return found
end
local function professions(text)
    local out,seen=A(),{}
    for _,p in ipairs(L.professions) do
        local a,b=T.Find(text,p.term,p.substring)
        if a and not seen[p.key] then
            seen[p.key]=true;out[#out+1]={key=p.key,evidence={kind="profession_word",locale=p.locale,term=p.term,startByte=a,endByte=b}}
        end
    end
    return out
end
local function lang(evidence)
    local counts={}
    for _,e in ipairs(evidence) do if e.locale and e.locale~="und" then counts[e.locale]=(counts[e.locale] or 0)+1 end end
    local out=A();for code,n in pairs(counts) do out[#out+1]={locale=code,hits=n} end
    table.sort(out,function(a,b) if a.hits==b.hits then return a.locale<b.locale end return a.hits>b.hits end)
    for _,v in ipairs(out) do if v.locale=="esES" then out[#out+1]={locale="esMX",hits=v.hits};break end end
    return out
end
local function copyEvidence(h,...)
    local out=A();for i=1,select("#",...) do for _,e in ipairs(h[select(i,...)] or {}) do out[#out+1]=e end end;return out
end
local units={
 {unit="gold",factor=10000,words={"g","gold","з","зол","золотых","золота","золотой","or","po","oro","금","金"}},
 {unit="silver",factor=100,words={"s","silver","с","сер","серебра","argent","pa","plata","prata","은","银","銀"}},
 {unit="copper",factor=1,words={"c","copper","м","мед","меди","cuivre","pc","cobre","동","铜","銅"}}}
local function qualifiers(text,h,entityCount,prefix)
    local q={money=A(),quantities=A(),basis="unspecified",materials="unspecified"}
    local raw=T.Fold(T.Plain(text)):gsub(prefix.."%d+z", " ")
    -- Only explicit denominations. Bare numbers are not prices or profession ranks.
    for a,amount,space,unit,b in raw:gmatch("()(%d+[.,]?%d*)( *)([A-Za-z\128-\255]+)()") do
        local prev=raw:sub(a-1,a-1)
        if a==1 or not prev:match("[%w\128-\255]") then
            for _,u in ipairs(units) do for _,word in ipairs(u.words) do
                if unit==word then
                    local n=tonumber((amount:gsub(",",".")))
                    local fraction=amount:match("[.,](%d+)$")
                    -- 1,000 / 1.000 may be a thousands separator, not a decimal.
                    if n and n<=100000000 and (not fraction or #fraction<=2) and prev~="-" then
                        q.money[#q.money+1]={amount=n,denomination=u.unit,copper=n*u.factor,raw=amount..space..unit,startByte=a,endByte=b-1}
                    end
                end
            end end
        end
    end
    table.sort(q.money,function(a,b) return a.startByte<b.startByte end)
    -- Component list, not an assumed total: ranges / alternatives / bundles stay unbound.
    for _,pattern in ipairs({"(%d+)%s*x%f[%W]","%f[%w]x%s*(%d+)","(%d+)%s*х%f[%W]","(%d+)%s*шт", "(%d+)%s*个", "(%d+)%s*個", "(%d+)%s*개"}) do
        local n=raw:match(pattern);n=tonumber(n)
        if n and n>0 and n<=100000 then q.quantities[#q.quantities+1]={value=n,scope=entityCount==1 and "single_subject" or "unbound",rule=pattern} end
    end
    local basisCount=0
    for _,kind in ipairs({"per_item","per_stack","per_craft"}) do if h[kind] then basisCount=basisCount+1;q.basis=kind end end
    if basisCount>1 then q.basis="ambiguous" end
    local matsCount=0
    for _,kind in ipairs({"mats_self","mats_other","mats_missing"}) do if h[kind] then matsCount=matsCount+1;q.materials=kind end end
    if matsCount>1 then q.materials="ambiguous" end
    q.negotiable=h.negotiable~=nil;q.tipMentioned=h.tip~=nil
    q.evidence=copyEvidence(h,"per_item","per_stack","per_craft","mats_self","mats_other","mats_missing","negotiable","tip")
    return q
end
local function hasLink(links,kind) for _,l in ipairs(links) do if l.kind==kind then return true end end end
local function roleMentions(normalized)
    local out,seen=A(),{}
    for _,r in ipairs(L.roles) do
        local a,b=T.Find(normalized,r.term,r.substring)
        if a and not seen[r.role] then
            seen[r.role]=true
            out[#out+1]={role=r.role,evidence={kind="role_word",locale=r.locale,term=r.term,startByte=a,endByte=b}}
        end
    end
    return out
end
local function groupDetails(scoped,normalized,part)
    local group={questIDs=A(),roleMentions=roleMentions(normalized),activity="unspecified"}
    local seen={}
    for _,l in ipairs(scoped) do if l.kind=="quest" and l.id and not seen[l.id] then
        seen[l.id]=true;group.questIDs[#group.questIDs+1]=l.id
    end end
    if #group.questIDs>0 then group.activity="quest" end
    local candidates,ratios={},{}
    for a,current,capacity,b in part:gmatch("()(%d+)%s*/%s*(%d+)()") do
        local n,m=tonumber(current),tonumber(capacity)
        local before,after=part:sub(a-1,a-1),part:sub(b,b)
        if n<=m and m>=2 and m<=40 and not before:match("[A-Za-z0-9\128-\255/]") and not after:match("[A-Za-z0-9\128-\255/]") then
            local key=n.."/"..m
            if not ratios[key] then ratios[key]=true;candidates[#candidates+1]={current=n,capacity=m,remaining=m-n,raw=part:sub(a,b-1),interpretation="possible_group_size"} end
        end
    end
    if #candidates==1 then group.rosterCandidate=candidates[1]
    elseif #candidates>1 then group.rosterAmbiguous=true end
    return group
end
local function restore(s,links,prefix) return (s:gsub(prefix.."(%d+)z",function(i) local l=links[tonumber(i)];return l and l.raw or prefix..i.."z" end)) end
local function split(masked)
    local out={}
    masked=masked:gsub("[\n\r;!?]","\1"):gsub("；","\1"):gsub("。","\1"):gsub("！","\1"):gsub("？","\1")
    for clause in masked:gmatch("[^\1]+") do
        -- Split opposite buy/sell adverts, even when separated only by 'and'.
        local normalized=T.Normalize(clause);local h=hits(normalized)
        if h.buy and h.sell then
            -- Keep punctuation in qualifiers; use original folded text for byte offsets.
            local original=" "..T.Fold(clause).." "
            local boundaries={}
            for _,kind in ipairs({"buy","sell"}) do for _,e in ipairs(h[kind]) do
                local a=T.Find(original,e.term,e.locale:match("^zh")~=nil or e.locale=="koKR")
                if a then boundaries[#boundaries+1]={pos=a,kind=kind} end
            end end
            if #boundaries<2 then out[#out+1]=clause
            else
                table.sort(boundaries,function(a,b) return a.pos<b.pos end)
                local cursor,previous=1,nil
                for _,m in ipairs(boundaries) do
                    if previous and m.kind~=previous and m.pos>cursor then out[#out+1]=original:sub(cursor,m.pos-1);cursor=m.pos end
                    previous=m.kind
                end
                out[#out+1]=original:sub(cursor)
            end
        else out[#out+1]=clause end
    end
    return out
end
function R:Recognize(raw,senderGUID)
    local links,masked,prefix=T.Links(raw)
    local result={version=self.version,links=links,segments=A(),facts=A(),rejections=A()}
    local function reject(reason,index) result.rejections[#result.rejections+1]={reason=reason,segmentIndex=index} end
    for _,part in ipairs(split(masked)) do
        local normalized=T.Normalize(part)
        local scoped=A();for n in part:gmatch(prefix.."(%d+)z") do local l=links[tonumber(n)];if l then scoped[#scoped+1]=l end end
        local h=hits(normalized);local profs=professions(normalized)
        if h.offer and h.request then
            local work=false
            for _,e in ipairs(h.offer) do if e.term=="looking for work" or e.term=="lf work" then work=true end end
            local genericOnly=true
            for _,e in ipairs(h.request) do if e.term~="lf" and e.term~="looking for" then genericOnly=false end end
            if work and genericOnly then h.request=nil end
        end
        local segment={index=#result.segments+1,text=restore(part,links,prefix),normalized=normalized,links=A(),professions=profs}
        for _,l in ipairs(scoped) do segment.links[#segment.links+1]=l.index end
        result.segments[#result.segments+1]=segment
        local function fact(category,evidence,confidence,extra)
            local entities=A();for _,l in ipairs(scoped) do entities[#entities+1]={kind=l.kind,id=l.id,linkIndex=l.index,caption=l.caption,raw=l.raw,payload=l.payload} end
            local f={category=category,segmentIndex=segment.index,confidence=confidence or "rule",evidence=evidence or A(),subject={links=segment.links,entities=entities,professions=NS.Clone(profs),text=segment.text},qualifiers=qualifiers(part,h,#scoped,prefix)}
            if category=="craft.offer" then
                f.subject.professionLinks=A();local known={}
                for _,p in ipairs(f.subject.professions) do known[p.key]=true end
                for _,l in ipairs(scoped) do if l.kind=="trade" then
                    local linked=professions(T.Normalize(l.caption))
                    local ownership=l.ownerGUID and (senderGUID and l.ownerGUID==senderGUID and "sender" or "third_party_or_unknown") or "unknown"
                    f.subject.professionLinks[#f.subject.professionLinks+1]={linkIndex=l.index,ownerGUID=l.ownerGUID,ownerRelation=ownership,professions=linked}
                    if ownership=="sender" then for _,p in ipairs(linked) do if not known[p.key] then
                        known[p.key]=true
                        f.subject.professions[#f.subject.professions+1]={key=p.key,evidence={kind="profession_link",linkIndex=l.index,locale=p.evidence.locale,term=p.evidence.term}}
                    end end end
                end end
            end
            if category=="group.recruit" or category=="group.seek" then
                f.group=groupDetails(scoped,normalized,part)
                for _,role in ipairs(f.group.roleMentions) do f.evidence[#f.evidence+1]=role.evidence end
            end
            f.languageCandidates=lang(f.evidence)
            if extra then for k,v in pairs(extra) do f[k]=v end end
            result.facts[#result.facts+1]=f;return f
        end
        -- Trade links are independent observations; they do not prove an offer or recipe ownership by the speaker.
        for _,l in ipairs(scoped) do if l.kind=="trade" then
            local linkedProfs=professions(T.Normalize(l.caption))
            local ownership=l.ownerGUID and (senderGUID and l.ownerGUID==senderGUID and "sender" or "third_party_or_unknown") or "unknown"
            fact("profession.link",A({{kind="hyperlink",linkIndex=l.index}}),"observed",{professionLink={linkIndex=l.index,ownerGUID=l.ownerGUID,ownerRelation=ownership,professions=linkedProfs}})
        end end
        local target=#scoped>0 or #profs>0 or h.service~=nil
        if h.guild then reject("guild_recruitment",segment.index)
        elseif h.cancel and target then
            -- A cancellation is an unassociated statement, never an automatic deletion of a previous advert.
            fact("advert.close",copyEvidence(h,"cancel"),"rule",{association="unresolved"})
        elseif h.cancel or h.negate then reject("negated_or_unavailable",segment.index)
        elseif h.sell and (h.buy or h.request) then reject("conflicting_intents",segment.index)
        elseif h.group_offer then fact("group.recruit",copyEvidence(h,"group_offer"))
        elseif h.group_seek then fact("group.seek",copyEvidence(h,"group_seek"))
        elseif h.group_invite and hasLink(scoped,"quest") then
            local evidence=copyEvidence(h,"group_invite")
            for _,l in ipairs(scoped) do if l.kind=="quest" then evidence[#evidence+1]={kind="hyperlink",linkIndex=l.index} end end
            fact("group.recruit",evidence)
        elseif h.request and hasLink(scoped,"quest") then fact("group.seek",copyEvidence(h,"request"))
        elseif h.request and #roleMentions(normalized)>1 and #profs==0 and not h.craft and not h.service and #scoped==0 then
            fact("group.recruit",copyEvidence(h,"request"))
        elseif h.request or h.buy then
            if target then
                local isCraft=#profs>0 or h.craft or hasLink(scoped,"enchant") or hasLink(scoped,"trade")
                local category=h.service and "service.request" or isCraft and "craft.request" or h.buy and hasLink(scoped,"item") and "item.buy"
                if category then fact(category,copyEvidence(h,"request","buy","craft","service")) else reject("target_or_intent_unclear",segment.index) end
            else reject("missing_subject",segment.index) end
        elseif h.sell or h.offer then
            if target then
                local isCraft=h.craft or h.offer and (#profs>0 or hasLink(scoped,"trade") or hasLink(scoped,"enchant")) or h.sell and (hasLink(scoped,"trade") or hasLink(scoped,"enchant") or #profs>0 and not hasLink(scoped,"item"))
                local category=h.service and "service.offer" or isCraft and "craft.offer" or h.sell and hasLink(scoped,"item") and "item.sell"
                if category then fact(category,copyEvidence(h,"offer","sell","craft","service"),"rule",{capability="advertised_only"}) else reject("target_or_intent_unclear",segment.index) end
            else reject("missing_subject",segment.index) end
        else reject("no_supported_intent",segment.index) end
    end
    -- Profession matches explain the subject, not a second independent intent.
    for _,f in ipairs(result.facts) do for _,p in ipairs(f.subject.professions) do f.evidence[#f.evidence+1]=p.evidence end;f.languageCandidates=lang(f.evidence) end
    if #result.facts==0 then return nil,result.rejections[1] and result.rejections[1].reason or "unrecognized" end
    return result
end
