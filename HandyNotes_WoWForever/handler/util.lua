local myname, ns = ...

ns.merge = function(t1, t2)
    if not t2 then return t1 end
    for k, v in pairs(t2) do
        t1[k] = v
    end
    return t1
end

local _, playerClass = UnitClass("player")
ns.playerName = UnitName("player")
ns.playerFaction = UnitFactionGroup("player")
ns.playerClassMask = ({
    -- this is 2^(classID - 1)
    WARRIOR = 0x1,
    PALADIN = 0x2,
    HUNTER = 0x4,
    ROGUE = 0x8,
    PRIEST = 0x10,
    DEATHKNIGHT = 0x20,
    SHAMAN = 0x40,
    MAGE = 0x80,
    WARLOCK = 0x100,
    MONK = 0x200,
    DRUID = 0x400,
    DEMONHUNTER = 0x800,
    EVOKER = 0x1000,
})[playerClass] or 0

ns.Getterize = function(tbl)
    return setmetatable(tbl, {
        __index=function(self, key)
            if self.__get[key] then return self.__get[key](self) end
        end,
    })
end

function ns.IsCosmeticItem(itemInfo)
    if _G.C_Item and C_Item.IsCosmeticItem then
        return C_Item.IsCosmeticItem(itemInfo)
    elseif _G.IsCosmeticItem then
        return IsCosmeticItem(itemInfo)
    end
    return false
end

function ns.GetCriteria(achievement, criteriaid)
    local retOK, criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaID, eligible = pcall(criteriaid < 100 and GetAchievementCriteriaInfo or GetAchievementCriteriaInfoByID, achievement, criteriaid, true)
    if not retOK then return end
    return criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaID, eligible
end
