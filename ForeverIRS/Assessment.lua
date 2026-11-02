local _, I = ...
I.ASSESSMENT_NOTE = "These counters describe what the game reported. New characters, bank alts and specialists can have different records; missing counters and resets can affect them. IRS does not grade characters."
I.professionKeys = {"firstAid","cooking","fishing","alchemy","blacksmithing","enchanting","leatherworking","mining","herbalism","skinning","tailoring","engineering"}
I.activityKeys = {"questCount","kills","dungeons","disenchanted","disenchantMaterials","fishCaught","honorableKills","flights","deaths"}

function I.professions(snapshot)
    local rows={}
    for _,key in ipairs(I.professionKeys) do
        rows[#rows+1]={key=key,label=I.byKey[key][3],highest=I.byKey[key][5]==true,n=I.numeric(snapshot,key)}
    end
    table.sort(rows,function(a,b)
        if a.n==nil and b.n~=nil then return false end
        if b.n==nil and a.n~=nil then return true end
        if a.n~=b.n then return a.n>b.n end
        return a.label<b.label
    end)
    return rows
end

-- Summarize returned counters without grading a character or inferring play style.
function I.assess(snapshot)
    local known,total,positive=0,0,0
    local evidence={}
    for _,key in ipairs({"questCount","kills","dungeons","honorableKills","disenchanted","disenchantMaterials","fishCaught"}) do
        local n=I.numeric(snapshot,key)
        total=total+1
        if n~=nil then known=known+1;if n>0 then positive=positive+1 end end
        evidence[#evidence+1]=I.byKey[key][3]..": "..I.value(snapshot,key,true)
    end
    local rankKnown,rankPositive=0,0
    for _,key in ipairs(I.professionKeys) do
        local rank=I.numeric(snapshot,key)
        total=total+1
        if rank~=nil then known=known+1;rankKnown=rankKnown+1 end
        if rank and rank>0 then positive=positive+1;rankPositive=rankPositive+1 end
    end
    evidence[#evidence+1]="Professions: "..rankPositive.." with recorded ranks above zero; "..rankKnown.." / "..#I.professionKeys.." readable. Historical ranks can include unlearned professions."
    evidence[#evidence+1]="Auctions: "..I.value(snapshot,"posted",true).." posted; "..I.value(snapshot,"purchases",true).." purchases."
    return {key=known>0 and "recorded" or "unknown",title=known>0 and "Recorded activity" or "Activity counters unavailable",
        summary=known>0 and (positive.." of the "..known.." readable activity counters have values above zero. Missing values are not zero.")
            or "This capture has no readable activity counters. Missing values are not zero.",
        tone=known>0 and "neutral" or "muted",known=known,total=total,positive=positive,evidence=evidence,
        coverage=known.." / "..total.." activity counters readable · missing is not zero"}
end
