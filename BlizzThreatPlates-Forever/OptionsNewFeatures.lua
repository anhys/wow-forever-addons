local addon = ForeverNameplates
local function Key(category, destination)
    return destination and category.."/"..destination or category
end
-- Absent on both fresh installs and upgrades: each menu starts unread once.
-- Stable keys preserve dismissals across reloads and subsequent builds.
function addon:IsOptionsMenuNew(category, destination)
    local seen = ForeverNameplatesDB and ForeverNameplatesDB.optionsSeenMenuNew
    return type(seen) ~= "table" or seen[Key(category,destination)] ~= true
end
function addon:MarkOptionsMenuSeen(category, destination)
    ForeverNameplatesDB = ForeverNameplatesDB or {}
    if type(ForeverNameplatesDB.optionsSeenMenuNew) ~= "table" then ForeverNameplatesDB.optionsSeenMenuNew={} end
    ForeverNameplatesDB.optionsSeenMenuNew[Key(category,destination)] = true
end
