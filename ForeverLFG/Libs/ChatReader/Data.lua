local _,Root=...
local NS=Root.ChatReader or Root
local A,clone,T=NS.Array,NS.Clone,NS.Text
local D={};NS.Data=D
local separators={['!']=true,['~']=true,[',']=true,['.']=true,[';']=true,[':']=true,['[']=true,[']']=true,['(']=true,[')']=true}
local function digit(c) return c~="" and c>="0" and c<="9" end
local function canonicalText(raw)
    local s=T.Fold(T.Plain(raw));local out={}
    for i=1,#s do
        local c=s:sub(i,i)
        if separators[c] and not ((c=='.' or c==',') and digit(s:sub(i-1,i-1)) and digit(s:sub(i+1,i+1))) then out[#out+1]=" "
        elseif c:byte()<=32 then out[#out+1]=" " else out[#out+1]=c end
    end
    local value=table.concat(out):gsub(" +"," "):match("^ *(.-) *$")
    if value:gsub("[- ]","")=="" then return "" end
    return value
end
-- Preserve payload/order, numbers, signs, /, +, ?, apostrophes and non-ASCII bytes.
-- Captions/colors/whitespace/PST! vs PST~ cannot make a new identity.
function D.Canonical(text,links)
    if not links then links=T.Links(text) end
    local parts=A();local cursor=1
    local function addText(value)
        value=canonicalText(value);if value~="" then parts[#parts+1]={text=value} end
    end
    for _,link in ipairs(links) do
        addText(text:sub(cursor,link.startByte-1))
        parts[#parts+1]={kind=link.kind,payload=link.payload}
        cursor=link.endByte+1
    end
    addText(text:sub(cursor));return parts
end
local function actorKey(actor)
    return actor.guid and {guid=actor.guid} or {name=actor.name}
end
function D.SourceKey(source)
    return source.identity or NS.JSON({kind=source.kind,event=source.event})
end
function D.MessageKey(source,fields,origin,parsed)
    local categories=A();for _,f in ipairs(parsed.facts) do categories[#categories+1]=f.category end
    return NS.JSON({actor=actorKey({guid=fields.senderGUID,name=fields.senderName}),source=D.SourceKey(source),origin=origin,
        body=D.Canonical(fields.text,parsed.links),categories=categories})
end
function D.FactKey(record,fact,separateSources)
    local subject
    if fact.professionLink then
        local link=record.recognition.links[fact.professionLink.linkIndex]
        subject={kind=link.kind,payload=link.payload}
    else subject=D.Canonical(fact.subject.text) end
    return NS.JSON({actor=actorKey(fact.actor),category=fact.category,origin=record.origin,subject=subject,
        source=separateSources and D.SourceKey(record.source) or nil})
end
function D.Unique(collector,options)
    options=type(options)=="table" and options or {}
    assert(options.maxAge==nil or (type(options.maxAge)=="number" and options.maxAge>=0 and options.maxAge<math.huge),"maxAge must be a finite nonnegative number")
    local result={schemaVersion=1,dataVersion=1,addonVersion=NS.version,recognizerVersion=NS.Recognizer.version,
        generatedAt=collector.clock(),session=collector.session,scope="retained_records",includesTests=options.includeTests==true,
        separateSources=options.separateSources==true,byCategory={},uniqueFactCount=0,recordCount=0,messageCount=0}
    local index,sourceIndexes,observationIndexes={},{},{}
    for recordIndex,record in ipairs(collector.records) do
        if options.maxRecords and recordIndex>options.maxRecords then break end
        local last=record.lastSeen or record.observedAt
        if (record.origin=="chat" or options.includeTests==true) and (not options.source or record.source.kind==options.source) and
            (not options.maxAge or result.generatedAt-last<=options.maxAge) then
            local counted=false
            for _,fact in ipairs(record.recognition.facts) do if not options.category or fact.category==options.category then
                counted=true
                local key=D.FactKey(record,fact,options.separateSources==true)
                local entry=index[key]
                if not entry then
                    entry={id=fact.id,category=fact.category,actor=clone(fact.actor),firstSeen=record.firstSeen or record.observedAt,
                        lastSeen=last,messageCount=0,observationCount=0,observationIDs=A(),factIDs=A(),sources=A(),fact=clone(fact)}
                    index[key]=entry;sourceIndexes[key]={};observationIndexes[key]={}
                    local bucket=result.byCategory[fact.category] or A();result.byCategory[fact.category]=bucket
                    bucket[#bucket+1]=entry;result.uniqueFactCount=result.uniqueFactCount+1
                end
                if not observationIndexes[key][record.id] then
                    observationIndexes[key][record.id]=true
                    local count=record.occurrences or 1
                    entry.messageCount=entry.messageCount+count;entry.observationCount=entry.observationCount+1
                    entry.observationIDs[#entry.observationIDs+1]=record.id;entry.factIDs[#entry.factIDs+1]=fact.id
                    entry.firstSeen=math.min(entry.firstSeen,record.firstSeen or record.observedAt)
                    if last>=entry.lastSeen then entry.lastSeen=last;entry.fact=clone(fact);entry.actor=clone(fact.actor) end
                    local sourceKey=D.SourceKey(record.source);local seen=sourceIndexes[key][sourceKey]
                    if not seen then
                        seen={source=clone(record.source),firstSeen=record.firstSeen or record.observedAt,lastSeen=last,messageCount=0}
                        sourceIndexes[key][sourceKey]=seen;entry.sources[#entry.sources+1]=seen
                    end
                    seen.firstSeen=math.min(seen.firstSeen,record.firstSeen or record.observedAt)
                    if last>=seen.lastSeen then seen.lastSeen=last;seen.source=clone(record.source) end
                    seen.messageCount=seen.messageCount+count
                end
            end end
            if counted then result.recordCount=result.recordCount+1;result.messageCount=result.messageCount+(record.occurrences or 1) end
        end
    end
    return result
end
