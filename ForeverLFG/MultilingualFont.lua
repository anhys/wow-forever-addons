-- Preserve each chat alphabet instead of flattening a FontFamily to one TTF.
local _,NS=...
local families,memberFiles,count={},{},0
local alphabets={"roman","russian","korean","simplifiedchinese","traditionalchinese"}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function fontInfo(object)
    if not object or type(object.GetFont)~="function" then return end
    local ok,file,height,flags=pcall(object.GetFont,object)
    if ok and public(file) and public(height) and public(flags) and type(file)=="string"
        and type(height)=="number" and height>0 and height<256 and type(flags)=="string" then
        return file,height,flags
    end
end
NS.ChatFontInfo=fontInfo
function NS.ApplyMultilingualFont(box,text)
    if not box or type(text)~="string" or not text:find("[\128-\255]") then return "unchanged" end
    if type(box.SetFontObject)~="function" then return "unavailable" end
    local base=ChatFontNormal
    local file,height,flags=fontInfo(box)
    local family
    if base and type(base.GetFontObjectForAlphabet)=="function" and type(CreateFontFamily)=="function" and file then
        local key=file..":"..height..":"..flags
        family=families[key]
        if not family then
            local members={}
            for _,alphabet in ipairs(alphabets) do
                local ok,font=pcall(base.GetFontObjectForAlphabet,base,alphabet)
                local nativeFile=ok and fontInfo(font)
                if nativeFile then
                    members[#members+1]={alphabet=alphabet,file=alphabet=="roman" and file or nativeFile,
                        height=height,flags=flags}
                end
            end
            if #members==#alphabets then
                count=count+1
                local ok,value=pcall(CreateFontFamily,"ForeverLFGChatFont"..count,members)
                if ok and value and public(value) then
                    family=value;families[key]=family
                    local files={}
                    for _,member in ipairs(members) do files[member.alphabet]=member.file end
                    memberFiles[family]=files
                end
            end
        end
    end
    -- Older/restricted clients can still restore Blizzard's complete family.
    local colors
    if type(box.GetTextColor)=="function" and type(box.SetTextColor)=="function" then
        local ok,r,g,b,a=pcall(box.GetTextColor,box)
        if ok and public(r) and public(g) and public(b) and public(a)
            and type(r)=="number" and type(g)=="number" and type(b)=="number" and type(a)=="number" then colors={r,g,b,a} end
    end
    local ok=pcall(box.SetFontObject,box,family or base or "ChatFontNormal")
    if ok and colors then pcall(box.SetTextColor,box,unpack(colors)) end
    box.foreverLFGFontAlphabets=ok and family and memberFiles[family] or nil
    return ok and (family and "multilingual-family" or "native-family") or "unavailable"
end
