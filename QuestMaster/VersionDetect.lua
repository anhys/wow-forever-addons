--[[
    QuestMaster Version Detection
    Detects the current WoW game version and sets QM.gameVersion accordingly.
    This file MUST be loaded before all other QuestMaster files.
]]

local addonName, QM = ...

-- Detect game version from interface number
local _, _, _, interfaceVersion = GetBuildInfo()

if interfaceVersion >= 50000 then
    QM.gameVersion = "MoP"
elseif interfaceVersion >= 40000 then
    QM.gameVersion = "Cata"
elseif interfaceVersion >= 30000 then
    QM.gameVersion = "Wrath"
elseif interfaceVersion >= 20000 then
    QM.gameVersion = "TBC"
else
    QM.gameVersion = "Classic"
end

QM.interfaceVersion = interfaceVersion

-- Convenience booleans
QM.isClassic = (QM.gameVersion == "Classic")
QM.isTBC = (QM.gameVersion == "TBC")
QM.isWrath = (QM.gameVersion == "Wrath")
QM.isCata = (QM.gameVersion == "Cata")
QM.isMoP = (QM.gameVersion == "MoP")

-- Feature flags based on version
QM.hasOutland = QM.isTBC or QM.isWrath or QM.isCata or QM.isMoP
QM.hasNorthrend = QM.isWrath or QM.isCata or QM.isMoP
QM.hasCataZones = QM.isCata or QM.isMoP
QM.hasPandaria = QM.isMoP
