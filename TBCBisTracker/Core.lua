-- TBCBisTracker Core
-- Handles: initialization, saved variables, events, utilities, minimap button, slash commands

TBCBisTracker = TBCBisTracker or {}
local addon = TBCBisTracker
local L     = addon.L

-- Newer clients (WoW Forever) only ship some of these under C_ namespaces.
local GetItemInfo  = GetItemInfo  or (C_Item and C_Item.GetItemInfo)
local GetItemStats = GetItemStats or (C_Item and C_Item.GetItemStats)
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local GetContainerNumSlots = GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots)
local GetContainerItemID   = GetContainerItemID   or (C_Container and C_Container.GetContainerItemID)

-- ─────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────

addon.TITLE = "ZenaBis"
addon.GAME_MODE = "tbc"

addon.PHASES = { "prebis", "phase1", "phase2", "phase3", "phase4", "phase5", "pvp" }

addon.PHASE_LABELS = {
    prebis = "Pre-BIS",
    phase1 = "Phase 1",
    phase2 = "Phase 2",
    phase3 = "Phase 3",
    phase4 = "Phase 4",
    phase5 = "Phase 5",
    pvp    = "PvP",
}

addon.PHASE_DESCRIPTIONS = {
    prebis = "Pre-Raid Best in Slot — Heroic Dungeons, Crafted, Reputation",
    phase1 = "Phase 1 — Karazhan · Gruul's Lair · Magtheridon's Lair",
    phase2 = "Phase 2 — Serpentshrine Cavern · The Eye (Tempest Keep)",
    phase3 = "Phase 3 — Black Temple · Battle for Mount Hyjal",
    phase4 = "Phase 4 — Zul'Aman",
    phase5 = "Phase 5 — Sunwell Plateau",
    pvp    = "PvP — Honor + Arena gear (Battlegrounds, Arena Seasons)",
}

addon.SLOTS = {
    "head","neck","shoulder","back","chest",
    "wrist","hands","waist","legs","feet",
    "ring1","ring2","trinket1","trinket2",
    "mainhand","offhand","ranged",
}

addon.SLOT_LABELS = {
    head     = "Head",
    neck     = "Neck",
    shoulder = "Shoulders",
    back     = "Back",
    chest    = "Chest",
    wrist    = "Wrist",
    hands    = "Hands",
    waist    = "Waist",
    legs     = "Legs",
    feet     = "Feet",
    ring1    = "Ring 1",
    ring2    = "Ring 2",
    trinket1 = "Trinket 1",
    trinket2 = "Trinket 2",
    mainhand = "Main Hand",
    offhand  = "Off Hand",
    ranged   = "Ranged",
}

-- Blizzard inventory slot textures
addon.SLOT_ICONS = {
    head     = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Head",
    neck     = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Neck",
    shoulder = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Shoulder",
    back     = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Chest",
    chest    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Chest",
    wrist    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Wrists",
    hands    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Hands",
    waist    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Waist",
    legs     = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Legs",
    feet     = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Feet",
    ring1    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Finger",
    ring2    = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Finger",
    trinket1 = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Trinket",
    trinket2 = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Trinket",
    mainhand = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-MainHand",
    offhand  = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-SecondaryHand",
    ranged   = "Interface\\PaperDollInfoFrame\\UI-PaperDoll-Slot-Ranged",
}

-- Item quality colors matching Blizzard's
addon.QUALITY_COLORS = {
    [0] = "|cff9d9d9d", -- Poor (grey)
    [1] = "|cffffffff", -- Common (white)
    [2] = "|cff1eff00", -- Uncommon (green)
    [3] = "|cff0070dd", -- Rare (blue)
    [4] = "|cffa335ee", -- Epic (purple)
    [5] = "|cffff8000", -- Legendary (orange)
}

addon.WOWHEAD_BASE = "https://www.wowhead.com/tbc/item="
addon.WOWHEAD_QUEST_BASE = "https://www.wowhead.com/tbc/quest="

-- Acceptable equipLoc strings (from GetItemInfo) per BIS slot key
addon.SLOT_INVTYPES = {
    head     = { INVTYPE_HEAD = true },
    neck     = { INVTYPE_NECK = true },
    shoulder = { INVTYPE_SHOULDER = true },
    back     = { INVTYPE_CLOAK = true },
    chest    = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    wrist    = { INVTYPE_WRIST = true },
    hands    = { INVTYPE_HAND = true },
    waist    = { INVTYPE_WAIST = true },
    legs     = { INVTYPE_LEGS = true },
    feet     = { INVTYPE_FEET = true },
    ring1    = { INVTYPE_FINGER = true },
    ring2    = { INVTYPE_FINGER = true },
    trinket1 = { INVTYPE_TRINKET = true },
    trinket2 = { INVTYPE_TRINKET = true },
    mainhand = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true },
    offhand  = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true, INVTYPE_SHIELD = true },
    ranged   = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true },
}

-- Map BIS-tracker slot keys to WoW inventory slot IDs.
-- ring1/ring2/trinket1/trinket2 each map to TWO inventory slots — we accept a match in either.
addon.SLOT_INVENTORY_IDS = {
    head     = { 1 },
    neck     = { 2 },
    shoulder = { 3 },
    chest    = { 5 },
    waist    = { 6 },
    legs     = { 7 },
    feet     = { 8 },
    wrist    = { 9 },
    hands    = { 10 },
    ring1    = { 11, 12 },
    ring2    = { 11, 12 },
    trinket1 = { 13, 14 },
    trinket2 = { 13, 14 },
    back     = { 15 },
    mainhand = { 16 },
    offhand  = { 17 },
    ranged   = { 18 },
}

-- ─────────────────────────────────────────────
-- Stat caps per class/spec
-- ─────────────────────────────────────────────
-- All caps are in *rating* units (what GetItemStats returns from gear), not
-- skill / percentage. Conversion targets at lvl 70:
--   142 hit rating       = 9% melee hit cap (vs lvl 73 boss).
--   164 spell hit rating = 13% (talented) spell hit cap.
--   202 spell hit rating = 16% (untalented) spell hit cap.
--   350 defense rating   ≈ uncrittable plate tank threshold (covers the
--                          ~140 def skill needed on top of the 350 base
--                          skill from level; 1 def rating ≈ 0.4 def skill).
--   102 expertise rating ≈ 26 expertise = 6.5% dodge cap on bosses.
addon.STAT_CAPS = {
    -- Labels are kept short so they fit on one line in the side panel.
    -- The detailed talent/cap explanation lives in the row hover tooltip.
    WARRIOR = {
        Fury = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Protection = {
            { stat="defense",   cap=350, label="Defense" },
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="armor",     cap=0,   label="Armor", info=true },
        },
    },
    PALADIN = {
        Holy = {
            { stat="healing",   cap=0,   label="+Healing", info=true },
            { stat="mp5",       cap=0,   label="MP5", info=true },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="intellect", cap=0,   label="Intellect", info=true },
        },
        Protection = {
            { stat="defense",   cap=350, label="Defense" },
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="spelldmg",  cap=0,   label="Spell Power", info=true },
        },
        Retribution = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="strength",  cap=0,   label="Strength", info=true },
        },
    },
    HUNTER = {
        ["Marksmanship"] = {
            { stat="hit",   cap=142, label="Hit" },
            { stat="crit",  cap=0,   label="Crit", info=true },
            { stat="agility", cap=0, label="Agility", info=true },
        },
        ["Survival"] = {
            { stat="hit",   cap=142, label="Hit" },
            { stat="crit",  cap=0,   label="Crit", info=true },
            { stat="agility", cap=0, label="Agility", info=true },
        },
        ["Beast Mastery"] = {
            { stat="hit",   cap=142, label="Hit" },
            { stat="crit",  cap=0,   label="Crit", info=true },
            { stat="agility", cap=0, label="Agility", info=true },
        },
    },
    ROGUE = {
        Combat = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="agility",   cap=0,   label="Agility", info=true },
        },
        Assassination = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="agility",   cap=0,   label="Agility", info=true },
        },
    },
    PRIEST = {
        Holy = {
            { stat="healing",   cap=0, label="+Healing", info=true },
            { stat="mp5",       cap=0, label="MP5", info=true },
            { stat="spellcrit", cap=0, label="Spell Crit", info=true },
            { stat="intellect", cap=0, label="Intellect", info=true },
        },
        Discipline = {
            { stat="healing",   cap=0, label="+Healing", info=true },
            { stat="mp5",       cap=0, label="MP5", info=true },
            { stat="spellcrit", cap=0, label="Spell Crit", info=true },
            { stat="intellect", cap=0, label="Intellect", info=true },
        },
        Shadow = {
            { stat="spellhit",  cap=202, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Shadow Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
    },
    MAGE = {
        Fire = {
            { stat="spellhit",  cap=164, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Spell Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Arcane = {
            { stat="spellhit",  cap=202, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Spell Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Frost = {
            { stat="spellhit",  cap=164, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Spell Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
    },
    WARLOCK = {
        Affliction = {
            { stat="spellhit",  cap=164, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Shadow Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Destruction = {
            { stat="spellhit",  cap=202, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Shadow Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Demonology = {
            { stat="spellhit",  cap=202, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Shadow Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
    },
    DRUID = {
        Balance = {
            { stat="spellhit",  cap=164, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Spell Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Restoration = {
            { stat="healing",   cap=0, label="+Healing", info=true },
            { stat="mp5",       cap=0, label="MP5", info=true },
            { stat="spellcrit", cap=0, label="Spell Crit", info=true },
            { stat="intellect", cap=0, label="Intellect", info=true },
        },
        ["Feral - Tank"] = {
            { stat="defense",   cap=165, label="Defense" },
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="armor",     cap=0,   label="Armor", info=true },
        },
        ["Feral - DPS"] = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="agility",   cap=0,   label="Agility", info=true },
        },
    },
    SHAMAN = {
        Restoration = {
            { stat="healing",   cap=0, label="+Healing", info=true },
            { stat="mp5",       cap=0, label="MP5", info=true },
            { stat="spellcrit", cap=0, label="Spell Crit", info=true },
            { stat="intellect", cap=0, label="Intellect", info=true },
        },
        Elemental = {
            { stat="spellhit",  cap=164, label="Spell Hit" },
            { stat="spellcrit", cap=0,   label="Spell Crit", info=true },
            { stat="spelldmg",  cap=0,   label="Spell Damage", info=true },
            { stat="haste",     cap=0,   label="Haste", info=true },
        },
        Enhancement = {
            { stat="hit",       cap=142, label="Hit" },
            { stat="expertise", cap=102, label="Expertise" },
            { stat="crit",      cap=0,   label="Crit", info=true },
            { stat="agility",   cap=0,   label="Agility", info=true },
        },
    },
}

-- Map our stat keys → GetItemStats() keys.
-- Each list is checked in order until a matching, non-zero value is found.
-- Multiple candidates cover differences in WoW versions (Classic / TBC / Wrath / retail)
-- and the way TBC rolls some stats together (e.g. Hit Rating works for both melee
-- and spell on most TBC items, so spellhit falls back to plain hit rating).
addon.STAT_GETITEMSTATS_KEYS = {
    -- Defensive
    defense   = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DEFENSE_RATING_SHORT" },
    armor     = { "RESISTANCE0_NAME", "ITEM_MOD_ARMOR_SHORT" },
    block     = { "ITEM_MOD_BLOCK_RATING_SHORT", "ITEM_MOD_BLOCK_VALUE_SHORT" },
    dodge     = { "ITEM_MOD_DODGE_RATING_SHORT" },
    parry     = { "ITEM_MOD_PARRY_RATING_SHORT" },
    resilience= { "ITEM_MOD_RESILIENCE_RATING_SHORT" },
    -- Hit/expertise/crit/haste — TBC items usually use the un-suffixed Hit/Crit Rating
    -- which applies to both melee and spell. Spell-only items use the SPELL variants.
    hit       = { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_MELEE_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT", "ITEM_MOD_RANGED_HIT_RATING_SHORT" },
    spellhit  = { "ITEM_MOD_SPELL_HIT_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT" },
    expertise = { "ITEM_MOD_EXPERTISE_RATING_SHORT" },
    crit      = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_MELEE_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT", "ITEM_MOD_RANGED_CRIT_RATING_SHORT" },
    spellcrit = { "ITEM_MOD_SPELL_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT" },
    haste     = { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT", "ITEM_MOD_MELEE_HASTE_RATING_SHORT" },
    -- Caster
    spelldmg  = { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DMG_SHORT" },
    healing   = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT" },
    mp5       = { "ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT", "ITEM_MOD_MANA_REGEN_SHORT" },
    -- Attack power
    attack    = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT" },
    rangedap  = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    -- Primary
    strength  = { "ITEM_MOD_STRENGTH_SHORT" },
    agility   = { "ITEM_MOD_AGILITY_SHORT" },
    intellect = { "ITEM_MOD_INTELLECT_SHORT" },
    stamina   = { "ITEM_MOD_STAMINA_SHORT" },
    spirit    = { "ITEM_MOD_SPIRIT_SHORT" },
}

-- ─────────────────────────────────────────────
-- Saved-variable defaults
-- ─────────────────────────────────────────────

-- Account-wide settings (DOES NOT include tracking data)
local DEFAULT_DB = {
    minimap      = { hide = false, pos = 220 },
    lastClass    = nil,
    lastSpec     = nil,
    lastPhase    = "prebis",
    showMissingOnly = false,
    sourceFilter = "all",
    windowPos    = { point = "CENTER", x = 0, y = 0 },
    statTrackerMode = "selected",   -- "obtained" | "selected" | "equipped"
    statTrackerOpen = true,
    previewShowModel = true,
}

-- Per-character tracking data
local DEFAULT_CHAR_DB = {
    obtained   = {},   -- ["CLASS-Spec"]["phase"]["slot"] = true
    selected   = {},   -- ["CLASS-Spec"]["phase"]["slot"] = alternativeIndex (1 = BiS)
    customAlts = {},   -- ["CLASS-Spec"]["phase"]["slot"] = { {id=, source=, sourceType=}, ... }
    notes      = {},   -- ["CLASS-Spec"]["phase"]["slot"] = "user note text"
}

-- ─────────────────────────────────────────────
-- Utility helpers
-- ─────────────────────────────────────────────

function addon:GetSpecKey(class, spec)
    return class .. "-" .. spec
end

function addon:IsObtained(class, spec, phase, slot)
    local key = self:GetSpecKey(class, spec)
    return TBCBisTrackerCharDB.obtained[key]
               and TBCBisTrackerCharDB.obtained[key][phase]
               and TBCBisTrackerCharDB.obtained[key][phase][slot] == true
end

function addon:SetObtained(class, spec, phase, slot, obtained)
    local key = self:GetSpecKey(class, spec)
    TBCBisTrackerCharDB.obtained[key] = TBCBisTrackerCharDB.obtained[key] or {}
    TBCBisTrackerCharDB.obtained[key][phase] = TBCBisTrackerCharDB.obtained[key][phase] or {}
    TBCBisTrackerCharDB.obtained[key][phase][slot] = obtained or nil
end

-- ─────────────────────────────────────────────
-- Gear preview — try the selected BiS gear on the player model
-- (mirrors AtlasLoot's right-click preview / native dressing room).
-- ─────────────────────────────────────────────

function addon:ShowGearPreview(class, spec, phase)
    class = class or TBCBisTrackerDB.lastClass
    spec  = spec  or TBCBisTrackerDB.lastSpec
    phase = phase or TBCBisTrackerDB.lastPhase
    if not (class and spec and phase) then
        self:Print("Set a class/spec/phase first.")
        return
    end
    if self.UI and self.UI.ShowBisPreview then
        self.UI:ShowBisPreview(class, spec, phase)
    else
        self:Print("UI not loaded yet.")
    end
end

-- ─────────────────────────────────────────────
-- Per-slot user notes (free-text annotations)
-- ─────────────────────────────────────────────

function addon:GetNote(class, spec, phase, slot)
    local key = self:GetSpecKey(class, spec)
    local n = TBCBisTrackerCharDB.notes
    return n and n[key] and n[key][phase] and n[key][phase][slot] or nil
end

function addon:SetNote(class, spec, phase, slot, text)
    local key = self:GetSpecKey(class, spec)
    TBCBisTrackerCharDB.notes = TBCBisTrackerCharDB.notes or {}
    TBCBisTrackerCharDB.notes[key] = TBCBisTrackerCharDB.notes[key] or {}
    TBCBisTrackerCharDB.notes[key][phase] = TBCBisTrackerCharDB.notes[key][phase] or {}
    if text and text ~= "" then
        TBCBisTrackerCharDB.notes[key][phase][slot] = text
    else
        TBCBisTrackerCharDB.notes[key][phase][slot] = nil
    end
end

-- Returns obtained count, total count for a given class/spec/phase
function addon:GetPhaseProgress(class, spec, phase)
    local obtained, total = 0, 0
    for _, slot in ipairs(self.SLOTS) do
        local alts = self:GetSlotAlternatives(class, spec, phase, slot)
        if alts and #alts > 0 then
            total = total + 1
            if self:IsObtained(class, spec, phase, slot) then
                obtained = obtained + 1
            end
        end
    end
    return obtained, total
end

function addon:GetProgress(class, spec, phase)
    local data = self:GetPhaseData(class, spec, phase)
    if not data then return 0, 0 end

    local total, obtained = 0, 0
    for _, slot in ipairs(self.SLOTS) do
        if data[slot] then
            total = total + 1
            if self:IsObtained(class, spec, phase, slot) then
                obtained = obtained + 1
            end
        end
    end
    return obtained, total
end

function addon:GetPhaseData(class, spec, phase)
    local classData = addon.DB[class]
    if not classData then return nil end
    local specData = classData[spec]
    if not specData then return nil end
    return specData[phase]
end

-- Slot data may be either a single item ({id=...}) or a list of items {item, item, ...}
-- where index 1 is BiS and 2+ are alternatives. User-imported alternatives are appended.
function addon:GetSlotAlternatives(class, spec, phase, slot)
    local out = {}
    local entries = self:GetPhaseData(class, spec, phase)
    if entries then
        local list = entries[slot]
        if list then
            if list.id then
                table.insert(out, list)
            else
                -- Faction-only items (WoW Forever data) are hidden from the other faction.
                local faction = UnitFactionGroup and UnitFactionGroup("player")
                for _, it in ipairs(list) do
                    if not (it.faction and faction and it.faction ~= faction) then
                        table.insert(out, it)
                    end
                end
            end
        end
    end
    -- Merge user-imported custom alternatives
    local custom = self:GetCustomAlts(class, spec, phase, slot)
    if custom then
        for _, it in ipairs(custom) do table.insert(out, it) end
    end
    if #out == 0 then return nil end
    return out
end

function addon:GetCustomAlts(class, spec, phase, slot)
    local ca = TBCBisTrackerCharDB.customAlts
    if not ca then return nil end
    local key = self:GetSpecKey(class, spec)
    return ca[key] and ca[key][phase] and ca[key][phase][slot]
end

function addon:AddCustomAlt(class, spec, phase, slot, itemId, source)
    if not itemId then return false end
    TBCBisTrackerCharDB.customAlts = TBCBisTrackerCharDB.customAlts or {}
    local key = self:GetSpecKey(class, spec)
    local ca = TBCBisTrackerCharDB.customAlts
    ca[key] = ca[key] or {}
    ca[key][phase] = ca[key][phase] or {}
    ca[key][phase][slot] = ca[key][phase][slot] or {}
    -- Avoid duplicates
    for _, it in ipairs(ca[key][phase][slot]) do
        if it.id == itemId then return false end
    end
    table.insert(ca[key][phase][slot], { id = itemId, source = source or "Custom (imported)", sourceType = "world" })
    self._itemIndex = nil  -- invalidate search index
    self._trackedIndex = nil  -- invalidate tooltip index
    return true
end

function addon:RemoveCustomAlt(class, spec, phase, slot, itemId)
    local list = self:GetCustomAlts(class, spec, phase, slot)
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].id == itemId then table.remove(list, i) end
    end
    self._itemIndex = nil
    self._trackedIndex = nil
end

-- Serialize the currently-selected items for a (class, spec, phase) into a single-line shareable string.
function addon:ExportSetup(class, spec, phase)
    if not class or not spec or not phase then return nil end
    local parts = {
        "TBCBIS:v1",
        "class=" .. class,
        "spec="  .. spec,
        "phase=" .. phase,
    }
    for _, slot in ipairs(self.SLOTS) do
        local entry = self:GetSlotItem(class, spec, phase, slot)
        if entry and entry.id then
            table.insert(parts, slot .. "=" .. entry.id)
        end
    end
    return table.concat(parts, ";")
end

-- Parse an exported string and apply it: adds missing items as custom alts and selects them.
-- Accepts both legacy newline-separated and current semicolon-separated formats.
-- Returns ok, message.
function addon:ImportSetup(text)
    if not text or text == "" then return false, "empty" end
    local class, spec, phase
    local items = {}
    -- Normalize separators: treat both \n and ; as token boundaries
    local normalized = text:gsub("\r", ""):gsub("\n", ";")
    for token in (normalized .. ";"):gmatch("([^;]+)") do
        token = token:match("^%s*(.-)%s*$")
        if token ~= "" and not token:match("^TBCBIS") then
            local k, v = token:match("^([%w_]+)=(.+)$")
            if k == "class" then class = v
            elseif k == "spec"  then spec  = v
            elseif k == "phase" then phase = v
            elseif k and v then
                local id = tonumber(v)
                if id then items[k] = id end
            end
        end
    end
    if not class or not spec or not phase then return false, "missing class/spec/phase header" end
    if not (self.DB[class] and self.DB[class][spec]) then
        return false, "unknown class/spec: " .. class .. "/" .. spec
    end
    local applied = 0
    for slot, itemId in pairs(items) do
        local alts = self:GetSlotAlternatives(class, spec, phase, slot)
        local foundIdx
        if alts then
            for i, alt in ipairs(alts) do
                if alt.id == itemId then foundIdx = i; break end
            end
        end
        if not foundIdx then
            self:AddCustomAlt(class, spec, phase, slot, itemId, "Imported setup")
            local newAlts = self:GetSlotAlternatives(class, spec, phase, slot)
            if newAlts then
                for i, alt in ipairs(newAlts) do
                    if alt.id == itemId then foundIdx = i; break end
                end
            end
        end
        if foundIdx then
            self:SetSelectedAlt(class, spec, phase, slot, foundIdx)
            applied = applied + 1
        end
    end
    return true, ("imported " .. applied .. " slots into " .. class .. "/" .. spec .. "/" .. phase)
end

-- ─────────────────────────────────────────────
-- Badge of Justice tracker
-- ─────────────────────────────────────────────

addon.BADGE_OF_JUSTICE_ID = 29434

-- Fallback prices for items whose source string omits the explicit Badge cost.
addon.BADGE_COSTS = {
    [29370] = 41,  -- Icon of the Silver Crescent
    [29272] = 75,  -- Orb of the Soul-Eater
    [29273] = 75,  -- Khadgar's Knapsack
    [29383] = 41,  -- Bloodlust Brooch
    [29384] = 25,  -- Ring of Unyielding Force
    [29381] = 25,  -- Choker of Vile Intent
    [29386] = 25,  -- Necklace of the Juggernaut
    [29382] = 25,  -- Blood Knight War Cloak
    [32087] = 50,  -- Mask of the Deceiver
    [32088] = 50,  -- Cowl of Beastly Rage
    [33334] = 60,  -- Fetish of the Primal Gods
    [33192] = 30,  -- Carved Witch Doctor's Stick
}

function addon:GetBadgeCount()
    return (GetItemCount and GetItemCount(self.BADGE_OF_JUSTICE_ID, true) or 0)
end

function addon:IsBadgeItem(entry)
    if not entry or not entry.source then return false end
    return entry.source:find("Badges of Justice") ~= nil
end

-- Detects whether an item is a tier-set piece based on its source string.
-- Returns nil or { tier = "T4"|"T5"|"T6"|"T6.5", boss = "..." }
function addon:GetTierInfo(entry)
    if not entry or not entry.source then return nil end
    local src = entry.source
    if not src:find("Token") and not src:find("Tier") then return nil end

    -- Try to extract the boss name. Wowhead-style: "Tier Token from <boss> (<location>)"
    local boss = src:match("Tier Token from ([^%(]+)%(") or src:match("Token from ([^%(]+)%(")
    if not boss then
        -- Pattern like "Karazhan - Prince Malchezaar Token (Item)"
        boss = src:match("%- ([^%-%(]+)Token") or src:match("([^%-%(]+) Token")
    end
    if boss then boss = boss:match("^%s*(.-)%s*$") end

    -- Identify which tier from boss / zone keywords
    local tier
    if src:find("Karazhan") or src:find("Gruul") or src:find("Magtheridon") then
        tier = "T4"
    elseif src:find("Serpentshrine") or src:find("SSC") or src:find("Tempest Keep") or src:find("TK") or src:find("The Eye") then
        tier = "T5"
    elseif src:find("Black Temple") or src:find("BT") or src:find("Hyjal") then
        tier = "T6"
    elseif src:find("Sunwell") or src:find("SWP") then
        tier = "T6.5"
    end

    if not tier then return nil end
    return { tier = tier, boss = boss }
end

function addon:GetBadgeCost(entry)
    if not entry then return nil end
    local n = entry.source and entry.source:match("(%d+)%s*Badges?%s*of%s*Justice")
    if n then return tonumber(n) end
    if entry.id and self.BADGE_COSTS[entry.id] then return self.BADGE_COSTS[entry.id] end
    return nil
end

-- ─────────────────────────────────────────────
-- Profession lookup for crafted items
-- ─────────────────────────────────────────────

local KNOWN_PROFESSIONS = {
    Tailoring = true, Leatherworking = true, Blacksmithing = true,
    Engineering = true, Alchemy = true, Jewelcrafting = true, Enchanting = true,
}

-- Returns "Tailoring" / "Leatherworking" / nil from a source string like
-- "Tailoring (Spellstrike Hood)" or "Tailoring/Shadoweave (...)" or "Leatherworking 365 (...)"
function addon:ParseCraftingProfession(entry)
    if not entry or entry.sourceType ~= "crafted" or not entry.source then return nil end
    -- Take the first capitalized word from the source string
    for word in entry.source:gmatch("([%a]+)") do
        if KNOWN_PROFESSIONS[word] then return word end
    end
    return nil
end

function addon:GetPlayerProfessionLevel(profName)
    if not GetNumSkillLines or not profName then return nil end
    for i = 1, GetNumSkillLines() do
        local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
        if skillName == profName then
            return skillRank, skillMaxRank
        end
    end
    return nil
end

-- ─────────────────────────────────────────────
-- Reputation lookup
-- ─────────────────────────────────────────────

addon.STANDING_NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local STANDING_INDEX = {}
for i, n in ipairs(addon.STANDING_NAMES) do STANDING_INDEX[n] = i end
addon.STANDING_INDEX = STANDING_INDEX

-- Returns faction, standing, standingId, or nil.
function addon:ParseRepLocation(loc)
    if not loc or loc == "" then return nil end
    for _, st in ipairs(self.STANDING_NAMES) do
        local before = loc:match("^(.-)%s+" .. st)
        if before then
            before = before:gsub("[%s%-]+$", "")
            return before, st, STANDING_INDEX[st]
        end
    end
    return nil
end

-- Best-effort lookup by name (case-insensitive, ignoring "The " prefix).
function addon:GetCurrentReputation(factionName)
    if not factionName or not GetNumFactions then return nil end
    local target = factionName:lower():gsub("^the%s+", ""):gsub("^%s*(.-)%s*$", "%1")
    if target == "" then return nil end
    for i = 1, GetNumFactions() do
        local name, _, standingId, barMin, barMax, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(i)
        if name and (not isHeader or hasRep) then
            local norm = name:lower():gsub("^the%s+", "")
            if norm == target or norm:find(target, 1, true) or target:find(norm, 1, true) then
                return name, standingId, barMin, barMax, barValue
            end
        end
    end
    return nil
end

-- "Where to farm" breakdown — groups unobtained items by source type, then by location.
-- Returns ordered list of { type, label, count, locations = { {location, count, items}, ... } }
function addon:GetFarmBreakdown(class, spec, phase)
    if not class or not spec or not phase then return {} end
    local typeOrder = { "raid", "heroic", "dungeon", "crafted", "reputation", "world", "quest", "pvp" }
    local typeLabels = {
        raid       = "Raid",
        heroic     = "Heroic Dungeon",
        dungeon    = "Dungeon",
        crafted    = "Crafted / Profession",
        reputation = "Reputation",
        world      = "World / Open World",
        quest      = "Quest",
        pvp        = "PvP",
    }
    local buckets = {}
    for _, slot in ipairs(self.SLOTS) do
        if not self:IsObtained(class, spec, phase, slot) then
            local entry = self:GetSlotItem(class, spec, phase, slot)
            if entry then
                local t = entry.sourceType or "world"
                buckets[t] = buckets[t] or { count = 0, locations = {} }
                buckets[t].count = buckets[t].count + 1
                local loc = (entry.source or "Unknown"):match("^(.-)%s*%(") or entry.source or "Unknown"
                loc = loc:match("^%s*(.-)%s*$")
                local found
                for _, l in ipairs(buckets[t].locations) do
                    if l.location == loc then
                        l.count = l.count + 1
                        table.insert(l.items, { slot = slot, entry = entry })
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(buckets[t].locations, {
                        location = loc, count = 1,
                        items = { { slot = slot, entry = entry } },
                    })
                end
            end
        end
    end

    local out = {}
    for _, t in ipairs(typeOrder) do
        if buckets[t] then
            -- Sort locations by count desc
            table.sort(buckets[t].locations, function(a, b) return a.count > b.count end)
            table.insert(out, {
                type = t,
                label = typeLabels[t] or t,
                count = buckets[t].count,
                locations = buckets[t].locations,
            })
        end
    end
    return out
end

-- Returns a per-tier summary: { [tier] = { total=N, obtained=M, slots = {slot,...} } }
function addon:GetTierProgress(class, spec, phase)
    local out = {}
    if not class or not spec or not phase then return out end
    for _, slot in ipairs(self.SLOTS) do
        local entry = self:GetSlotItem(class, spec, phase, slot)
        if entry then
            local info = self:GetTierInfo(entry)
            if info then
                local agg = out[info.tier]
                if not agg then
                    agg = { total = 0, obtained = 0, slots = {} }
                    out[info.tier] = agg
                end
                agg.total = agg.total + 1
                table.insert(agg.slots, slot)
                if self:IsObtained(class, spec, phase, slot) then
                    agg.obtained = agg.obtained + 1
                end
            end
        end
    end
    return out
end

-- Returns: owned, totalCost, items[] (each {slot, cost, entry}) for unobtained badge items in (class,spec,phase).
function addon:GetBadgeProgress(class, spec, phase)
    local owned = self:GetBadgeCount()
    if not class or not spec or not phase then return owned, 0, {} end
    local total, items = 0, {}
    for _, slot in ipairs(self.SLOTS) do
        if not self:IsObtained(class, spec, phase, slot) then
            local entry = self:GetSlotItem(class, spec, phase, slot)
            if entry and self:IsBadgeItem(entry) then
                local cost = self:GetBadgeCost(entry)
                if cost then
                    total = total + cost
                    table.insert(items, { slot = slot, cost = cost, entry = entry })
                end
            end
        end
    end
    return owned, total, items
end

-- ─────────────────────────────────────────────
-- Reverse index: item id → list of (spec, phase, slot, altIdx, totalAlts)
-- for the player's class. Used by tooltip integration.
-- ─────────────────────────────────────────────

function addon:BuildTrackedItemIndex()
    local _, playerClass = UnitClass("player")
    if not playerClass then self._trackedIndex = {}; return self._trackedIndex end
    local classData = self.DB[playerClass]
    if not classData then self._trackedIndex = {}; return self._trackedIndex end
    local idx = {}
    for spec, _ in pairs(classData) do
        for _, phase in ipairs(self.PHASES) do
            for _, slot in ipairs(self.SLOTS) do
                local alts = self:GetSlotAlternatives(playerClass, spec, phase, slot)
                if alts then
                    for i, alt in ipairs(alts) do
                        if alt.id then
                            idx[alt.id] = idx[alt.id] or {}
                            table.insert(idx[alt.id], {
                                spec = spec, phase = phase, slot = slot,
                                idx = i, total = #alts,
                            })
                        end
                    end
                end
            end
        end
    end
    self._trackedIndex = idx
    return idx
end

function addon:GetItemTrackingInfo(itemId)
    if not itemId then return nil end
    if not self._trackedIndex then self:BuildTrackedItemIndex() end
    local matches = self._trackedIndex[itemId]
    if not matches or #matches == 0 then return nil end
    local _, playerClass = UnitClass("player")
    local out = {}
    for _, m in ipairs(matches) do
        local selected = self:GetSelectedAlt(playerClass, m.spec, m.phase, m.slot)
        table.insert(out, {
            spec = m.spec, phase = m.phase, slot = m.slot,
            idx = m.idx, total = m.total,
            isSelected = (m.idx == selected),
        })
    end
    return out
end

-- ─────────────────────────────────────────────
-- Item search index (built from internal DB; AtlasLoot can extend it)
-- ─────────────────────────────────────────────

function addon:BuildItemIndex()
    local idx = {}
    local seen = {}

    local function add(it)
        if it and it.id and not seen[it.id] then
            seen[it.id] = true
            table.insert(idx, it)
        end
    end

    -- Walk the static DB
    for _, classData in pairs(self.DB or {}) do
        if type(classData) == "table" then
            for _, specData in pairs(classData) do
                if type(specData) == "table" then
                    for _, phase in ipairs(self.PHASES) do
                        local pdata = specData[phase]
                        if pdata then
                            for _, slot in ipairs(self.SLOTS) do
                                local list = pdata[slot]
                                if list then
                                    if list.id then add(list)
                                    else for _, it in ipairs(list) do add(it) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Include user custom imports
    if TBCBisTrackerCharDB and TBCBisTrackerCharDB.customAlts then
        for _, byPhase in pairs(TBCBisTrackerCharDB.customAlts) do
            for _, bySlot in pairs(byPhase) do
                for _, slotItems in pairs(bySlot) do
                    if type(slotItems) == "table" then
                        for _, it in ipairs(slotItems) do add(it) end
                    end
                end
            end
        end
    end

    -- Best-effort AtlasLoot harvest
    self.atlasLootDetected = false
    if IsAddOnLoaded and IsAddOnLoaded("AtlasLootClassic") then
        self.atlasLootDetected = true
        -- AtlasLoot's data structure varies by version; safe harvest harmless on failure
        local ok = pcall(function()
            local al = _G.AtlasLoot
            if not al or type(al) ~= "table" then return end
            -- Walk any registered data tables looking for items with [1]=number ids
            for _, modName in ipairs({ "AtlasLootClassic_DungeonsAndRaids", "AtlasLootClassic_Crafting", "AtlasLootClassic_Factions", "AtlasLootClassic_PvP", "AtlasLootClassic_Collections" }) do
                local mod = _G[modName]
                if mod and type(mod) == "table" then
                    local function walk(t)
                        if type(t) ~= "table" then return end
                        for k, v in pairs(t) do
                            if type(v) == "table" then
                                if type(v[1]) == "number" and v[2] and type(v[2]) == "number" and v[2] > 100 then
                                    add({ id = v[2], source = "AtlasLoot data", sourceType = "world" })
                                else
                                    walk(v)
                                end
                            end
                        end
                    end
                    walk(mod)
                end
            end
        end)
    end

    self._itemIndex = idx
    return idx
end

-- Search the index for items whose cached name (or source string) contains the query.
function addon:SearchItems(query, limit)
    if not self._itemIndex then self:BuildItemIndex() end
    query = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    if query == "" then return {} end
    limit = limit or 20
    local matches = {}
    for _, it in ipairs(self._itemIndex) do
        local name = GetItemInfo(it.id)
        local hay = (name or it.source or ""):lower()
        if hay:find(query, 1, true) then
            table.insert(matches, { id = it.id, name = name, source = it.source })
            if #matches >= limit then break end
        end
    end
    return matches
end

-- Parse a Wowhead URL, in-game item link, or bare numeric id.
function addon:ParseWowheadInput(input)
    if not input or input == "" then return nil end
    input = tostring(input):match("^%s*(.-)%s*$")
    local patterns = {
        "item=(%d+)",        -- wowhead query-style: ...item=29370
        "item:(%d+)",        -- in-game hyperlink: |Hitem:29370:0:...
        "/item/(%d+)",       -- path style: /item/29370
        "/items/(%d+)",      -- plural variant
        "wowhead%.com/[%w%-/]*/(%d+)",  -- last segment of a wowhead path
        "^(%d+)$",           -- bare number
    }
    for _, p in ipairs(patterns) do
        local id = input:match(p)
        if id then return tonumber(id) end
    end
    return nil
end

function addon:GetSelectedAlt(class, spec, phase, slot)
    local sel = TBCBisTrackerCharDB.selected
    if not sel then return 1 end
    local key = self:GetSpecKey(class, spec)
    return (sel[key] and sel[key][phase] and sel[key][phase][slot]) or 1
end

function addon:SetSelectedAlt(class, spec, phase, slot, idx)
    TBCBisTrackerCharDB.selected = TBCBisTrackerCharDB.selected or {}
    local key = self:GetSpecKey(class, spec)
    TBCBisTrackerCharDB.selected[key] = TBCBisTrackerCharDB.selected[key] or {}
    TBCBisTrackerCharDB.selected[key][phase] = TBCBisTrackerCharDB.selected[key][phase] or {}
    TBCBisTrackerCharDB.selected[key][phase][slot] = idx
end

-- Returns the currently-selected item entry for a slot, the index, and total alternative count.
function addon:GetSlotItem(class, spec, phase, slot)
    local alts = self:GetSlotAlternatives(class, spec, phase, slot)
    if not alts or #alts == 0 then return nil, 1, 0 end
    local idx = self:GetSelectedAlt(class, spec, phase, slot)
    if idx > #alts then idx = 1 end
    return alts[idx], idx, #alts
end

-- ─────────────────────────────────────────────
-- Stat aggregation (cap tracker)
-- ─────────────────────────────────────────────

-- Pull a single stat value from a GetItemStats() result.
-- We try three matching strategies in order:
--   1) literal candidate string as a key  (e.g. "ITEM_MOD_HIT_RATING_SHORT")
--   2) _G[candidate] dereferenced         (e.g. "Hit Rating" via global value)
--   3) substring pattern match on every key in the raw table — catches
--      whatever weird key TBC Classic actually uses (the third arg is a
--      table of patterns; the matched key's value is summed).
local function readStat(statTable, keys, patterns)
    if not statTable then return 0 end
    for _, k in ipairs(keys) do
        local v = statTable[k]
        if v and v ~= 0 then return v end
        local g = _G[k]
        if type(g) == "string" then
            v = statTable[g]
            if v and v ~= 0 then return v end
        end
    end
    if patterns then
        local total = 0
        for key, value in pairs(statTable) do
            if value and value ~= 0 then
                local upper = key:upper()
                for _, p in ipairs(patterns) do
                    if upper:find(p.match) and not (p.exclude and upper:find(p.exclude)) then
                        total = total + value
                        break
                    end
                end
            end
        end
        if total ~= 0 then return total end
    end
    return 0
end

-- Per-stat heuristic patterns. UPPERCASE substring matches against the raw key.
-- `exclude` rules out keys that would also match a more specific stat.
addon.STAT_PATTERNS = {
    defense   = { { match = "DEFENSE" } },
    hit       = { { match = "HIT.*RATING", exclude = "SPELL" } },
    spellhit  = { { match = "SPELL.*HIT" } },
    crit      = { { match = "CRIT.*RATING", exclude = "SPELL" } },
    spellcrit = { { match = "SPELL.*CRIT" }, { match = "CRIT.*SPELL" } },
    haste     = { { match = "HASTE" } },
    expertise = { { match = "EXPERTISE" } },
    spelldmg  = { { match = "SPELL.*DAMAGE" }, { match = "SPELL.*POWER" } },
    healing   = { { match = "HEALING" }, { match = "SPELL.*HEAL" } },
    mp5       = { { match = "MANA.*REGEN" }, { match = "POWER.*REGEN" } },
    block     = { { match = "BLOCK" } },
    dodge     = { { match = "DODGE" } },
    parry     = { { match = "PARRY" } },
    resilience= { { match = "RESILIENCE" } },
    attack    = { { match = "ATTACK.*POWER", exclude = "RANGED" } },
    rangedap  = { { match = "RANGED.*ATTACK.*POWER" } },
    armor     = { { match = "RESISTANCE0", }, { match = "^ARMOR$" } },
    strength  = { { match = "STRENGTH" } },
    agility   = { { match = "AGILITY" } },
    intellect = { { match = "INTELLECT" } },
    stamina   = { { match = "STAMINA" } },
    spirit    = { { match = "SPIRIT" } },
}

-- Returns a stats dict for any item link or item id, e.g. {hit=12, crit=18, ...}.
-- If only an itemId is provided and the item isn't in the local cache yet,
-- returns nil so caller can retry later (after GET_ITEM_INFO_RECEIVED).
function addon:GetItemStatsForLink(link)
    if not link then return {} end
    if type(link) == "number" then
        local id = link
        link = select(2, GetItemInfo(id))
        if not link then
            GetItemInfo(id)  -- prime the cache
            return nil
        end
    end
    local raw = GetItemStats(link)
    -- raw == nil means the client doesn't have the item's stat block ready yet.
    -- Treat as still-loading so the caller increments `pending` and retries on
    -- GET_ITEM_INFO_RECEIVED, instead of silently summing 0 for that slot.
    if not raw then return nil end
    local out = {}
    for ourKey, candidates in pairs(self.STAT_GETITEMSTATS_KEYS) do
        out[ourKey] = readStat(raw, candidates, self.STAT_PATTERNS[ourKey])
    end
    return out
end

-- Backward-compat alias; takes an itemId (int).
function addon:GetItemStatsForId(itemId)
    if not itemId or itemId <= 0 then return {} end
    return self:GetItemStatsForLink(itemId)
end

-- Aggregate stats across all 17 slots, picking the item per `mode`:
--   "obtained" — selected alt for slots the user has checked obtained
--   "selected" — selected alt for every slot, regardless of obtained
--   "equipped" — actually-equipped item via GetInventoryItemLink
-- Returns: stats={...}, missingItems=N (cold-cache count for caller to schedule a retry)
function addon:GetTrackedStats(class, spec, phase, mode)
    mode = mode or "obtained"
    local agg = {}
    local pending = 0
    local contributors = {}  -- stat -> { {slot=..., itemId=..., value=...}, ... }
    for ourKey in pairs(self.STAT_GETITEMSTATS_KEYS) do
        agg[ourKey] = 0
        contributors[ourKey] = {}
    end

    for _, slot in ipairs(self.SLOTS) do
        local itemId, itemLink
        if mode == "equipped" then
            local invIds = self.SLOT_INVENTORY_IDS[slot]
            if invIds then
                -- Convention: ring1/ring2/trinket1/trinket2 each have two inv slots; map slot1=lower, slot2=upper
                local pickIdx = (slot == "ring2" or slot == "trinket2") and 2 or 1
                local invId = invIds[pickIdx] or invIds[1]
                itemLink = GetInventoryItemLink("player", invId)
                if itemLink then itemId = tonumber(itemLink:match("item:(%d+)")) end
            end
        else
            local entry = self:GetSlotItem(class, spec, phase, slot)
            if entry and entry.id and entry.id > 0 then
                if mode == "obtained" then
                    if self:IsObtained(class, spec, phase, slot) then itemId = entry.id end
                else  -- "selected"
                    itemId = entry.id
                end
            end
        end

        if itemId and itemId > 0 then
            -- Equipped uses the live inventory link (carries gems/enchants/random suffixes);
            -- obtained/selected use the bare item id (base stats only).
            local stats = self:GetItemStatsForLink(itemLink or itemId)
            if stats == nil then
                pending = pending + 1
            else
                for k, v in pairs(stats) do
                    if v ~= 0 then
                        agg[k] = (agg[k] or 0) + v
                        table.insert(contributors[k], { slot = slot, itemId = itemId, value = v })
                    end
                end
            end
        end
    end

    return agg, pending, contributors
end

-- Diagnostic: dump raw GetItemStats for the current spec's selected/equipped/obtained gear
-- and list which keys we consumed for each of our stat names. Helps verify the addon's
-- stat-key mapping against what the client actually returns.
function addon:DumpStatDebug(class, spec, phase, mode)
    mode = mode or "obtained"
    self:Print("Stat-debug — mode: " .. mode .. "  (slot → itemId → keys present in raw GetItemStats)")
    for _, slot in ipairs(self.SLOTS) do
        local itemId, itemLink
        if mode == "equipped" then
            local invIds = self.SLOT_INVENTORY_IDS[slot]
            if invIds then
                local pickIdx = (slot == "ring2" or slot == "trinket2") and 2 or 1
                local invId = invIds[pickIdx] or invIds[1]
                itemLink = GetInventoryItemLink("player", invId)
                if itemLink then itemId = tonumber(itemLink:match("item:(%d+)")) end
            end
        else
            local entry = self:GetSlotItem(class, spec, phase, slot)
            if entry and entry.id and entry.id > 0 then
                if mode == "obtained" then
                    if self:IsObtained(class, spec, phase, slot) then itemId = entry.id end
                else
                    itemId = entry.id
                end
            end
        end
        if itemId then
            local link = itemLink or select(2, GetItemInfo(itemId))
            local raw = link and GetItemStats(link) or nil
            local keys = {}
            if raw then for k, v in pairs(raw) do if v ~= 0 then keys[#keys+1] = k .. "=" .. tostring(v) end end end
            self:Print("  " .. (self.SLOT_LABELS[slot] or slot) .. " (id " .. itemId .. "): " .. (raw and (#keys > 0 and table.concat(keys, ", ") or "<empty stats>") or "<not cached>"))
        end
    end
end

-- Returns a render-ready list aligned with STAT_CAPS[class][spec]:
--   { {label="Defense", stat="defense", cap=490, current=410, missing=80, info=false}, ... }
-- Returns nil if the spec has no defined caps.
function addon:GetCapStatus(class, spec, phase, mode)
    if not (class and spec) then return nil end
    local capList = self.STAT_CAPS[class] and self.STAT_CAPS[class][spec]
    if not capList then return nil end

    local stats, pending, contribs = self:GetTrackedStats(class, spec, phase, mode)
    local out = {}
    for _, def in ipairs(capList) do
        local cur = stats[def.stat] or 0
        out[#out + 1] = {
            stat    = def.stat,
            label   = def.label,
            cap     = def.cap or 0,
            current = cur,
            missing = (def.cap and def.cap > 0) and math.max(0, def.cap - cur) or 0,
            info    = def.info or false,
            contributors = contribs[def.stat],
        }
    end
    return out, pending
end

function addon:GetItemLink(itemId)
    if not itemId then return "|cffffffff[Unknown]|r" end
    local name, _, quality = GetItemInfo(itemId)
    if name then
        local color = self.QUALITY_COLORS[quality] or "|cffffffff"
        return color .. "|Hitem:" .. itemId .. ":0:0:0:0:0:0:0|h[" .. name .. "]|h|r"
    end
    return "|cff9d9d9d[Item " .. itemId .. "]|r"
end

function addon:GetItemName(itemId)
    if not itemId then return "Unknown" end
    local name = GetItemInfo(itemId)
    return name or ("Item " .. itemId)
end

function addon:GetItemQualityColor(itemId)
    if not itemId then return self.QUALITY_COLORS[1] end
    local _, _, quality = GetItemInfo(itemId)
    return self.QUALITY_COLORS[quality or 1] or self.QUALITY_COLORS[1]
end

function addon:ResetAllData()
    TBCBisTrackerCharDB.obtained = {}
    self:Print("All tracking data has been reset.")
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

-- Reset all selectedAlt picks for a (class, spec, phase) back to index 1 (the BiS).
-- Custom-imported alts and obtained checkmarks are kept.
function addon:ResetSelectionsToBiS(class, spec, phase)
    if not class or not spec or not phase then return end
    local key = self:GetSpecKey(class, spec)
    if TBCBisTrackerCharDB.selected and TBCBisTrackerCharDB.selected[key] then
        TBCBisTrackerCharDB.selected[key][phase] = nil
    end
    self:Print("Reset all selections back to BiS for " .. (self.PHASE_LABELS[phase] or phase) .. ".")
    if self.UI and self.UI.Refresh then self.UI:Refresh() end
end

-- Reset obtained checkmarks for a single (class, spec, phase). Selections + custom alts kept.
function addon:ResetPhase(class, spec, phase)
    if not class or not spec or not phase then return end
    local key = self:GetSpecKey(class, spec)
    if TBCBisTrackerCharDB.obtained[key] then
        TBCBisTrackerCharDB.obtained[key][phase] = nil
    end
    self:Print("Reset " .. class .. " " .. spec .. " " .. (self.PHASE_LABELS[phase] or phase) .. ".")
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd700[" .. (self:IsForever() and "ZenaBis Forever" or "ZenaBis") .. "]|r " .. tostring(msg))
end

-- ─────────────────────────────────────────────
-- Auto-detect: mark BIS items obtained from currently equipped gear.
-- One-way: never auto-unticks; manual untick stays unticked until item re-equipped.
-- ─────────────────────────────────────────────

function addon:ScanEquipped()
    local _, playerClass = UnitClass("player")
    if not playerClass then return end
    local classData = self.DB[playerClass]
    if not classData then return end

    -- Collect every item id the player currently owns (equipped + bags 0-4)
    local owned = {}
    for invSlot = 1, 19 do
        local id = GetInventoryItemID("player", invSlot)
        if id then owned[id] = true end
    end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slotIdx = 1, slots do
            local id = GetContainerItemID and GetContainerItemID(bag, slotIdx) or nil
            if id then owned[id] = true end
        end
    end

    local marked = 0
    for spec, _ in pairs(classData) do
        for _, phase in ipairs(self.PHASES) do
            for _, slot in ipairs(self.SLOTS) do
                local entry = self:GetSlotItem(playerClass, spec, phase, slot)
                if entry and entry.id and owned[entry.id] then
                    if not self:IsObtained(playerClass, spec, phase, slot) then
                        self:SetObtained(playerClass, spec, phase, slot, true)
                        marked = marked + 1
                    end
                end
            end
        end
    end

    if marked > 0 and self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
    return marked
end

-- ─────────────────────────────────────────────
-- Merge defaults (non-destructive)
-- ─────────────────────────────────────────────

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                applyDefaults(target[k], v)
            else
                target[k] = v
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Minimap button
-- ─────────────────────────────────────────────

local function CreateMinimapButton()
    if _G.TBCBisTrackerMinimapBtn then return _G.TBCBisTrackerMinimapBtn end

    local btn = CreateFrame("Button", "TBCBisTrackerMinimapBtn", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Anchor immediately so the button has a valid position even before UpdatePosition runs
    btn:SetPoint("CENTER", Minimap, "CENTER", 0, 0)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetPoint("TOPLEFT", 7, -6)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Position around minimap: just outside the edge. The radius is measured,
    -- not fixed, because the Forever client uses a bigger minimap.
    local EDGE_OFFSET = 5
    local function UpdatePosition()
        local pos = tonumber(TBCBisTrackerDB.minimap.pos) or 220
        local angle = math.rad(pos)
        local radius = (Minimap:GetWidth() or 140) / 2 + EDGE_OFFSET
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * radius, math.sin(angle) * radius)
    end

    local function CursorAngle()
        local cx, cy = Minimap:GetCenter()
        if not cx then return nil end
        local mx, my = GetCursorPosition()
        local scale  = Minimap:GetEffectiveScale()
        return math.deg(math.atan2(my / scale - cy, mx / scale - cx)) % 360
    end

    -- Follow the cursor while dragging.
    btn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            if angle then
                TBCBisTrackerDB.minimap.pos = angle
                UpdatePosition()
            end
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)
    Minimap:HookScript("OnSizeChanged", UpdatePosition)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            addon.UI:Toggle()
        elseif button == "RightButton" then
            addon:ShowGearPreview()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffffd700" .. addon.TITLE .. "|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click to toggle window", 1, 1, 1)
        GameTooltip:AddLine("Right-click to preview BiS gear", 1, 1, 1)
        GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
    btn:Show()
    addon.MinimapBtn = btn
    return btn
end

-- ─────────────────────────────────────────────
-- Slash commands
-- ─────────────────────────────────────────────

SLASH_TBCBISTRACKER1 = "/tbcbis"
SLASH_TBCBISTRACKER2 = "/tbcbistracker"

SlashCmdList["TBCBISTRACKER"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if cmd == "reset" then
        addon:ResetPhase(TBCBisTrackerDB.lastClass, TBCBisTrackerDB.lastSpec, TBCBisTrackerDB.lastPhase)
    elseif cmd == "reset all" then
        addon:ResetAllData()
    elseif cmd == "hide" then
        if addon.MinimapBtn then addon.MinimapBtn:Hide() end
        TBCBisTrackerDB.minimap.hide = true
    elseif cmd == "show" then
        if addon.MinimapBtn then addon.MinimapBtn:Show() end
        TBCBisTrackerDB.minimap.hide = false
    elseif cmd == "export" then
        if addon.UI and addon.UI.ShowExportPopup then addon.UI:ShowExportPopup() end
    elseif cmd == "import" then
        if addon.UI and addon.UI.ShowImportPopup then addon.UI:ShowImportPopup() end
    elseif cmd == "bis" or cmd == "reset bis" then
        addon:ResetSelectionsToBiS(TBCBisTrackerDB.lastClass, TBCBisTrackerDB.lastSpec, TBCBisTrackerDB.lastPhase)
    elseif cmd == "preview" then
        addon:ShowGearPreview()
    elseif cmd == "statsdebug" or cmd:match("^statsdebug ") then
        local mode = cmd:match("^statsdebug%s+(%S+)$") or TBCBisTrackerDB.statTrackerMode or "equipped"
        addon:DumpStatDebug(TBCBisTrackerDB.lastClass, TBCBisTrackerDB.lastSpec, TBCBisTrackerDB.lastPhase, mode)
    elseif cmd == "stats" or cmd:match("^stats ") then
        local mode = cmd:match("^stats%s+(%S+)$") or TBCBisTrackerDB.statTrackerMode or "selected"
        if mode ~= "obtained" and mode ~= "selected" and mode ~= "equipped" then
            addon:Print("Unknown mode '" .. mode .. "'. Use: obtained / selected / equipped.")
            return
        end
        local class = TBCBisTrackerDB.lastClass
        local spec  = TBCBisTrackerDB.lastSpec
        local phase = TBCBisTrackerDB.lastPhase
        local rows, pending = addon:GetCapStatus(class, spec, phase, mode)
        if not rows then
            addon:Print("No stat caps configured for " .. tostring(class) .. " / " .. tostring(spec) .. ".")
            return
        end
        addon:Print("Stat caps — " .. class .. " " .. spec .. " " .. (addon.PHASE_LABELS[phase] or phase) .. " — mode: " .. mode .. (pending > 0 and (" (" .. pending .. " items still loading)") or ""))
        for _, r in ipairs(rows) do
            local line
            if r.info then
                line = string.format("  %s: %d", r.label, r.current)
            elseif r.missing == 0 then
                line = string.format("  |cff00ff00✓ %s: %d / %d|r", r.label, r.current, r.cap)
            else
                line = string.format("  |cffff8800✗ %s: %d / %d (-%d)|r", r.label, r.current, r.cap, r.missing)
            end
            addon:Print(line)
        end
    elseif cmd == "mode" or cmd:match("^mode ") then
        addon:HandleModeCommand(cmd:match("^mode%s+(%S+)$"))
    elseif cmd == "help" or cmd == "" then
        if cmd == "" then
            addon.UI:Toggle()
        else
            addon:Print("/tbcbis           — toggle window")
            addon:Print("/tbcbis export    — export current spec/phase setup")
            addon:Print("/tbcbis import    — import a setup string")
            addon:Print("/tbcbis bis       — reset selected alts back to BiS for current phase")
            addon:Print("/tbcbis preview   — open WoW dressing room with current BiS gear")
            addon:Print("/tbcbis reset     — reset checkmarks for current phase")
            addon:Print("/tbcbis reset all — reset ALL tracking data")
            addon:Print("/tbcbis stats [mode]  — print stat-cap progress (modes: obtained/selected/equipped)")
            addon:Print("/tbcbis mode [auto|forever|tbc] — show or force game mode")
            addon:Print("/tbcbis hide      — hide minimap button")
            addon:Print("/tbcbis show      — show minimap button")
            addon:Print("/tbcbis help      — show this message")
        end
    else
        addon.UI:Toggle()
    end
end

-- Walks the entire BiS DB + per-character custom alts and calls GetItemInfo
-- on every unique item id, forcing the WoW client to stream the item's data
-- (name, link, stats) into the local cache. Idempotent: items already cached
-- return immediately. Items not yet cached fire GET_ITEM_INFO_RECEIVED later,
-- which the event handler uses to refresh the cap panel.
function addon:PrimeItemCache()
    local seen = {}
    local function visitList(list)
        if not list then return end
        if list.id then
            if list.id > 0 and not seen[list.id] then seen[list.id] = true; GetItemInfo(list.id) end
        else
            for _, it in ipairs(list) do
                if it and it.id and it.id > 0 and not seen[it.id] then
                    seen[it.id] = true
                    GetItemInfo(it.id)
                end
            end
        end
    end
    for _, classData in pairs(self.DB) do
        for _, specData in pairs(classData) do
            for _, phaseData in pairs(specData) do
                if type(phaseData) == "table" then
                    for _, slotData in pairs(phaseData) do
                        visitList(slotData)
                    end
                end
            end
        end
    end
    -- Custom alts the player imported.
    if TBCBisTrackerCharDB and TBCBisTrackerCharDB.customAlts then
        for _, byPhase in pairs(TBCBisTrackerCharDB.customAlts) do
            for _, bySlot in pairs(byPhase) do
                for _, list in pairs(bySlot) do
                    visitList(list)
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Event frame & initialisation
-- ─────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

-- ─────────────────────────────────────────────
-- Loot announcement: alert when a BIS-tracked item appears in loot
-- ─────────────────────────────────────────────

local recentLootAnnouncements = {}  -- itemId -> timestamp; suppress duplicates

local function announceTrackedItem(itemId, contextText)
    if not itemId then return end
    local now = GetTime and GetTime() or 0
    if recentLootAnnouncements[itemId] and (now - recentLootAnnouncements[itemId]) < 30 then return end

    local matches = addon:GetItemTrackingInfo(itemId)
    if not matches or #matches == 0 then return end
    recentLootAnnouncements[itemId] = now

    local _, link = GetItemInfo(itemId)
    link = link or ("item:" .. itemId)

    for _, m in ipairs(matches) do
        local tag
        if m.isSelected then
            tag = "|cffffd700[BIS]|r"
        elseif m.idx == 1 then
            tag = "|cff00ff00[BIS]|r"
        else
            tag = "|cffaaaaaa[Alt " .. m.idx .. "/" .. m.total .. "]|r"
        end
        local ctx = contextText and (" " .. contextText) or ""
        addon:Print(tag .. " " .. link .. " — " .. (addon.PHASE_LABELS[m.phase] or m.phase) .. " " .. (addon.SLOT_LABELS[m.slot] or m.slot) .. ctx)
    end
end

local function scanLootWindow()
    if not GetNumLootItems then return end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        if link then
            local itemId = tonumber(link:match("item:(%d+)"))
            if itemId then announceTrackedItem(itemId, "(loot window)") end
        end
    end
end

local function scanLootRoll(rollId)
    if not GetLootRollItemLink then return end
    local link = GetLootRollItemLink(rollId)
    if link then
        local itemId = tonumber(link:match("item:(%d+)"))
        if itemId then announceTrackedItem(itemId, "(group loot)") end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "TBCBisTracker" then

        -- Initialise saved variables
        TBCBisTrackerDB = TBCBisTrackerDB or {}
        applyDefaults(TBCBisTrackerDB, DEFAULT_DB)

        -- One-time migration: previewShowModel flipped default from false → true.
        -- Promote existing saved-false values once so users get the new default.
        if not TBCBisTrackerDB.__previewModelMigrated then
            TBCBisTrackerDB.previewShowModel = true
            TBCBisTrackerDB.__previewModelMigrated = true
        end
        TBCBisTrackerCharDB = TBCBisTrackerCharDB or {}
        applyDefaults(TBCBisTrackerCharDB, DEFAULT_CHAR_DB)

        -- Swap in WoW Forever data when running on the Forever client.
        addon:ApplyGameMode()
        addon:NormalizeLastPhase()

        -- One-time migration: if account-wide had tracking data and char DB is empty, copy it over
        if TBCBisTrackerDB.obtained and not TBCBisTrackerCharDB.__migrated then
            if next(TBCBisTrackerDB.obtained) and not next(TBCBisTrackerCharDB.obtained) then
                TBCBisTrackerCharDB.obtained = TBCBisTrackerDB.obtained
            end
            if TBCBisTrackerDB.selected and next(TBCBisTrackerDB.selected) and not next(TBCBisTrackerCharDB.selected) then
                TBCBisTrackerCharDB.selected = TBCBisTrackerDB.selected
            end
            if TBCBisTrackerDB.customAlts and next(TBCBisTrackerDB.customAlts) and not next(TBCBisTrackerCharDB.customAlts) then
                TBCBisTrackerCharDB.customAlts = TBCBisTrackerDB.customAlts
            end
            TBCBisTrackerCharDB.__migrated = true
            -- Drop legacy account-wide tracking blobs to avoid drift
            TBCBisTrackerDB.obtained, TBCBisTrackerDB.selected, TBCBisTrackerDB.customAlts = nil, nil, nil
        end

        -- Detect player class if no stored preference
        if not TBCBisTrackerDB.lastClass then
            local _, playerClass = UnitClass("player")
            TBCBisTrackerDB.lastClass = playerClass
            -- Set first spec using the ordered list from CLASS_INFO
            local classInfo = addon.CLASS_INFO and addon.CLASS_INFO[playerClass]
            if classInfo and classInfo.specs and classInfo.specs[1] then
                TBCBisTrackerDB.lastSpec = classInfo.specs[1]
            end
        end

        -- Normalize lastSpec: if the saved spec was renamed/removed (e.g. Druid "Feral" → "Feral - Tank"/"Feral - DPS"),
        -- fall back to the first valid spec for the class.
        local cls = TBCBisTrackerDB.lastClass
        if cls and addon.CLASS_INFO and addon.CLASS_INFO[cls] then
            local valid = {}
            for _, s in ipairs(addon.CLASS_INFO[cls].specs) do valid[s] = true end
            if TBCBisTrackerDB.lastSpec and not valid[TBCBisTrackerDB.lastSpec] then
                TBCBisTrackerDB.lastSpec = addon.CLASS_INFO[cls].specs[1]
            end
        end

        -- Create minimap button
        CreateMinimapButton()
        if TBCBisTrackerDB.minimap.hide then
            addon.MinimapBtn:Hide()
        end

        addon:Print("Loaded" .. (addon:IsForever() and " (WoW Forever mode)" or "") .. "! Type /tbcbis to open.")

    elseif event == "PLAYER_LOGIN" then
        -- Build the UI after all data is ready
        if addon.UI and addon.UI.Build then
            addon.UI:Build()
        end
        addon:ScanEquipped()
        -- Prime the item cache for every item in the BiS database. Without
        -- this, switching to an alternative the player has never seen leaves
        -- GetItemStats returning nil, so the slot silently contributes 0 to
        -- the cap totals until the item happens to load. We fire one
        -- GetItemInfo per id; the client streams the data in and
        -- GET_ITEM_INFO_RECEIVED triggers a stat-cap refresh as each lands.
        addon:PrimeItemCache()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
        addon:ScanEquipped()
        if addon.UI and addon.UI.RefreshBadgeStatus then
            addon.UI:RefreshBadgeStatus()
        end
        if addon.UI and addon.UI.RefreshStatCaps then
            addon.UI:RefreshStatCaps()
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- A previously-uncached item now has stats. Re-render the cap panel.
        if addon.UI and addon.UI.RefreshStatCaps then
            addon.UI:RefreshStatCaps()
        end
        -- Rows show names, icons and quality borders once items load; items
        -- arrive in bursts, so refresh the open list at most every 0.3 s.
        local frame = addon.UI and addon.UI.frame
        if frame and frame:IsShown() and not addon.rowRefreshPending and C_Timer then
            addon.rowRefreshPending = true
            C_Timer.After(0.3, function()
                addon.rowRefreshPending = false
                if addon.UI.frame:IsShown() then addon.UI:Refresh() end
            end)
        end
        -- And re-apply the BiS preview if it's open and items were still loading.
        if addon.UI and addon.UI.previewFrame and addon.UI.previewFrame:IsShown() then
            addon.UI:RefreshBisPreview()
        end

    elseif event == "LOOT_OPENED" then
        scanLootWindow()

    elseif event == "START_LOOT_ROLL" then
        scanLootRoll(arg1)
    end
end)

-- ─────────────────────────────────────────────
-- Tooltip integration: append tracking info to any item tooltip
-- ─────────────────────────────────────────────

local function appendTrackingLines(tooltip, data)
    if not tooltip or not tooltip.AddLine then return end
    local itemId = data and tonumber(data.id)
    if not itemId and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        itemId = link and tonumber(link:match("item:(%d+)"))
    end
    if not itemId then return end

    local matches = addon:GetItemTrackingInfo(itemId)
    if not matches or #matches == 0 then return end

    -- Avoid duplicate stamping on the same render
    if tooltip.tbcbisStamp == itemId then return end
    tooltip.tbcbisStamp = itemId

    tooltip:AddLine(" ")
    for _, m in ipairs(matches) do
        local phaseLabel = addon.PHASE_LABELS[m.phase] or m.phase
        local slotLabel  = addon.SLOT_LABELS[m.slot] or m.slot
        local prefix, line
        if m.isSelected then
            prefix = "|cffffd700[BIS]|r"
            line = string.format("%s Selected for %s %s", prefix, phaseLabel, slotLabel)
        elseif m.idx == 1 then
            prefix = "|cff00ff00[BIS]|r"
            line = string.format("%s Top pick for %s %s (currently tracking Alt %d)", prefix, phaseLabel, slotLabel,
                addon:GetSelectedAlt(select(2, UnitClass("player")), m.spec, m.phase, m.slot))
        else
            prefix = "|cffaaaaaa[Alt " .. m.idx .. "/" .. m.total .. "]|r"
            line = string.format("%s for %s %s", prefix, phaseLabel, slotLabel)
        end
        if m.spec ~= TBCBisTrackerDB.lastSpec then
            line = line .. " |cff888888(" .. m.spec .. ")|r"
        end
        tooltip:AddLine(line)
    end
    tooltip:Show()  -- recompute height
end

local function clearStamp(self) self.tbcbisStamp = nil end

-- Newer clients (WoW Forever) dropped the OnTooltipSetItem script in favour of
-- TooltipDataProcessor; hooking a missing script errors, so pick whichever exists.
local useDataProcessor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
if useDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip == GameTooltip or tooltip == ItemRefTooltip then
            appendTrackingLines(tooltip, data)
        end
    end)
end
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if not useDataProcessor and tooltip:HasScript("OnTooltipSetItem") then
        tooltip:HookScript("OnTooltipSetItem", appendTrackingLines)
    end
    tooltip:HookScript("OnHide", clearStamp)
end
