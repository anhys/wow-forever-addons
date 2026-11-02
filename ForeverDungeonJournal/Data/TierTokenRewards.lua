-- Classic/TBC token redemption item IDs and class groupings checked against
-- installed AtlasLootClassic Data/Token.lua and Data/ItemSet.lua.
-- Factual item relationships only; no AtlasLoot runtime or code dependency.
-- Reference: https://github.com/Hoizame/AtlasLootClassic
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
FDJ.TIER_TOKEN_REWARDS = {
    [19716] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 19827,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 19833,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 19846,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Bindings",
    },
    [19717] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 19824,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 19836,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 19830,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Armsplint",
    },
    [19718] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 19843,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 19848,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 19840,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Stanchion",
    },
    [19719] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 19823,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 19835,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 19829,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Girdle",
    },
    [19720] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 19842,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 19849,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 19839,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Sash",
    },
    [19721] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 19826,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 19832,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 19845,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Shawl",
    },
    [19722] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 19825,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 19828,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 19838,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Tabard",
    },
    [19723] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 19822,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 20034,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 20033,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Kossack",
    },
    [19724] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 19831,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 19834,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 19841,
                    },
                },
            },
        },
        ["name"] = "Primal Hakkari Aegis",
    },
    [20884] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21393,
                    },
                },
            },
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21396,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21399,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21414,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21408,
                    },
                },
            },
        },
        ["name"] = "Qiraji Magisterial Ring",
    },
    [20885] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21394,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21406,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21412,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21415,
                    },
                },
            },
        },
        ["name"] = "Qiraji Martial Drape",
    },
    [20886] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21392,
                    },
                },
            },
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21395,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21401,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21404,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21398,
                    },
                },
            },
        },
        ["name"] = "Qiraji Spiked Hilt",
    },
    [20888] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21402,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21405,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21411,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21417,
                    },
                },
            },
        },
        ["name"] = "Qiraji Ceremonial Ring",
    },
    [20889] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21397,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21403,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21400,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21418,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21409,
                    },
                },
            },
        },
        ["name"] = "Qiraji Regal Drape",
    },
    [20890] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21410,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21413,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21416,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21407,
                    },
                },
            },
        },
        ["name"] = "Qiraji Ornate Hilt",
    },
    [20926] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21329,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21348,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21347,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21337,
                    },
                },
            },
        },
        ["name"] = "Vek'nilash's Circlet",
    },
    [20927] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21332,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21362,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21352,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21346,
                    },
                },
            },
        },
        ["name"] = "Ouro's Intact Hide",
    },
    [20928] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21330,
                    },
                    {
                        ["id"] = 21333,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21365,
                    },
                    {
                        ["id"] = 21367,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21359,
                    },
                    {
                        ["id"] = 21361,
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21349,
                    },
                    {
                        ["id"] = 21350,
                    },
                },
            },
        },
        ["name"] = "Qiraji Bindings of Command",
    },
    [20929] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 21331,
                    },
                },
            },
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21389,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21370,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21364,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21374,
                    },
                },
            },
        },
        ["name"] = "Carapace of the Old God",
    },
    [20930] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21387,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21366,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 21360,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21372,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21353,
                    },
                },
            },
        },
        ["name"] = "Vek'lor's Diadem",
    },
    [20931] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21390,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 21368,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21375,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21336,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21356,
                    },
                },
            },
        },
        ["name"] = "Skin of the Great Sandworm",
    },
    [20932] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 21388,
                    },
                    {
                        ["id"] = 21391,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 21373,
                    },
                    {
                        ["id"] = 21376,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21344,
                    },
                    {
                        ["id"] = 21345,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21335,
                    },
                    {
                        ["id"] = 21338,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21354,
                    },
                    {
                        ["id"] = 21355,
                    },
                },
            },
        },
        ["name"] = "Qiraji Bindings of Dominance",
    },
    [20933] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 21351,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 21343,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 21334,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 21357,
                    },
                },
            },
        },
        ["name"] = "Husk of the Old God",
    },
    [21232] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "ALL",
                ["items"] = {
                    {
                        ["id"] = 21242,
                    },
                    {
                        ["id"] = 21244,
                    },
                    {
                        ["id"] = 21269,
                    },
                    {
                        ["id"] = 21272,
                    },
                },
            },
        },
        ["name"] = "Imperial Qiraji Armaments",
    },
    [21237] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "ALL",
                ["items"] = {
                    {
                        ["id"] = 21268,
                    },
                    {
                        ["id"] = 21273,
                    },
                    {
                        ["id"] = 21275,
                    },
                },
            },
        },
        ["name"] = "Imperial Qiraji Regalia",
    },
    [22349] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22416,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22476,
                    },
                },
            },
        },
        ["name"] = "Desecrated Breastplate",
    },
    [22350] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22425,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22436,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22464,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22488,
                    },
                },
            },
        },
        ["name"] = "Desecrated Tunic",
    },
    [22351] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22512,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22496,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22504,
                    },
                },
            },
        },
        ["name"] = "Desecrated Robe",
    },
    [22352] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22417,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22477,
                    },
                },
            },
        },
        ["name"] = "Desecrated Legplates",
    },
    [22353] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22418,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22478,
                    },
                },
            },
        },
        ["name"] = "Desecrated Helmet",
    },
    [22354] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22419,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22479,
                    },
                },
            },
        },
        ["name"] = "Desecrated Pauldrons",
    },
    [22355] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22423,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22483,
                    },
                },
            },
        },
        ["name"] = "Desecrated Bracers",
    },
    [22356] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22422,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22482,
                    },
                },
            },
        },
        ["name"] = "Desecrated Waistguard",
    },
    [22357] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22421,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22481,
                    },
                },
            },
        },
        ["name"] = "Desecrated Gauntlets",
    },
    [22358] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 22420,
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 22480,
                    },
                },
            },
        },
        ["name"] = "Desecrated Sabatons",
    },
    [22359] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22427,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22437,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22465,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22489,
                    },
                },
            },
        },
        ["name"] = "Desecrated Legguards",
    },
    [22360] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22428,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22438,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22466,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22490,
                    },
                },
            },
        },
        ["name"] = "Desecrated Headpiece",
    },
    [22361] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22429,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22439,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22467,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22491,
                    },
                },
            },
        },
        ["name"] = "Desecrated Spaulders",
    },
    [22362] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22424,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22443,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22471,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22495,
                    },
                },
            },
        },
        ["name"] = "Desecrated Wristguards",
    },
    [22363] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22431,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22442,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22470,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22494,
                    },
                },
            },
        },
        ["name"] = "Desecrated Girdle",
    },
    [22364] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22426,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22441,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22469,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22493,
                    },
                },
            },
        },
        ["name"] = "Desecrated Handguards",
    },
    [22365] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 22430,
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 22440,
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 22468,
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 22492,
                    },
                },
            },
        },
        ["name"] = "Desecrated Boots",
    },
    [22366] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22513,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22497,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22505,
                    },
                },
            },
        },
        ["name"] = "Desecrated Leggings",
    },
    [22367] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22514,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22498,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22506,
                    },
                },
            },
        },
        ["name"] = "Desecrated Circlet",
    },
    [22368] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22515,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22499,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22507,
                    },
                },
            },
        },
        ["name"] = "Desecrated Shoulderpads",
    },
    [22369] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22519,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22503,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22511,
                    },
                },
            },
        },
        ["name"] = "Desecrated Bindings",
    },
    [22370] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22518,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22502,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22510,
                    },
                },
            },
        },
        ["name"] = "Desecrated Belt",
    },
    [22371] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22517,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22501,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22509,
                    },
                },
            },
        },
        ["name"] = "Desecrated Gloves",
    },
    [22372] = {
        ["era"] = "classic",
        ["groups"] = {
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 22516,
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 22500,
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 22508,
                    },
                },
            },
        },
        ["name"] = "Desecrated Sandals",
    },
    [29753] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 29019,
                        ["set"] = "Warbringer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 29012,
                        ["set"] = "Warbringer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 29050,
                        ["set"] = "Incarnate Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 29056,
                        ["set"] = "Incarnate Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 29091,
                        ["set"] = "Malorne Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 29096,
                        ["set"] = "Malorne Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 29087,
                        ["set"] = "Malorne Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Fallen Defender",
    },
    [29754] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 29062,
                        ["set"] = "Justicar Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 29066,
                        ["set"] = "Justicar Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 29071,
                        ["set"] = "Justicar Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 29045,
                        ["set"] = "Netherblade",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 29033,
                        ["set"] = "Cyclone Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 29038,
                        ["set"] = "Cyclone Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 29029,
                        ["set"] = "Cyclone Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Fallen Champion",
    },
    [29755] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 29082,
                        ["set"] = "Demon Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 29077,
                        ["set"] = "Aldor Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 28964,
                        ["set"] = "Voidheart Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Fallen Hero",
    },
    [29756] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 29085,
                        ["set"] = "Demon Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 29080,
                        ["set"] = "Aldor Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 28968,
                        ["set"] = "Voidheart Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Fallen Hero",
    },
    [29757] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 29065,
                        ["set"] = "Justicar Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 29067,
                        ["set"] = "Justicar Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 29072,
                        ["set"] = "Justicar Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 29048,
                        ["set"] = "Netherblade",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 29034,
                        ["set"] = "Cyclone Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 29039,
                        ["set"] = "Cyclone Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 29032,
                        ["set"] = "Cyclone Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Fallen Champion",
    },
    [29758] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 29020,
                        ["set"] = "Warbringer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 29017,
                        ["set"] = "Warbringer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 29055,
                        ["set"] = "Incarnate Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 29057,
                        ["set"] = "Incarnate Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 29092,
                        ["set"] = "Malorne Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 29097,
                        ["set"] = "Malorne Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 29090,
                        ["set"] = "Malorne Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Fallen Defender",
    },
    [29759] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 29081,
                        ["set"] = "Demon Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 29076,
                        ["set"] = "Aldor Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 28963,
                        ["set"] = "Voidheart Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Helm of the Fallen Hero",
    },
    [29760] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 29061,
                        ["set"] = "Justicar Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 29068,
                        ["set"] = "Justicar Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 29073,
                        ["set"] = "Justicar Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 29044,
                        ["set"] = "Netherblade",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 29035,
                        ["set"] = "Cyclone Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 29040,
                        ["set"] = "Cyclone Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 29028,
                        ["set"] = "Cyclone Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Fallen Champion",
    },
    [29761] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 29021,
                        ["set"] = "Warbringer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 29011,
                        ["set"] = "Warbringer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 29049,
                        ["set"] = "Incarnate Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 29058,
                        ["set"] = "Incarnate Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 29093,
                        ["set"] = "Malorne Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 29098,
                        ["set"] = "Malorne Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 29086,
                        ["set"] = "Malorne Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Fallen Defender",
    },
    [29762] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 29084,
                        ["set"] = "Demon Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 29079,
                        ["set"] = "Aldor Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 28967,
                        ["set"] = "Voidheart Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Fallen Hero",
    },
    [29763] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 29064,
                        ["set"] = "Justicar Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 29070,
                        ["set"] = "Justicar Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 29075,
                        ["set"] = "Justicar Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 29047,
                        ["set"] = "Netherblade",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 29037,
                        ["set"] = "Cyclone Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 29043,
                        ["set"] = "Cyclone Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 29031,
                        ["set"] = "Cyclone Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Fallen Champion",
    },
    [29764] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 29023,
                        ["set"] = "Warbringer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 29016,
                        ["set"] = "Warbringer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 29054,
                        ["set"] = "Incarnate Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 29060,
                        ["set"] = "Incarnate Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 29095,
                        ["set"] = "Malorne Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 29100,
                        ["set"] = "Malorne Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 29089,
                        ["set"] = "Malorne Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Fallen Defender",
    },
    [29765] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 29083,
                        ["set"] = "Demon Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 29078,
                        ["set"] = "Aldor Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 28966,
                        ["set"] = "Voidheart Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Fallen Hero",
    },
    [29766] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 29063,
                        ["set"] = "Justicar Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 29069,
                        ["set"] = "Justicar Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 29074,
                        ["set"] = "Justicar Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 29046,
                        ["set"] = "Netherblade",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 29036,
                        ["set"] = "Cyclone Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 29042,
                        ["set"] = "Cyclone Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 29030,
                        ["set"] = "Cyclone Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Fallen Champion",
    },
    [29767] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 29022,
                        ["set"] = "Warbringer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 29015,
                        ["set"] = "Warbringer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 29053,
                        ["set"] = "Incarnate Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 29059,
                        ["set"] = "Incarnate Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 29094,
                        ["set"] = "Malorne Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 29099,
                        ["set"] = "Malorne Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 29088,
                        ["set"] = "Malorne Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Fallen Defender",
    },
    [30236] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30134,
                        ["set"] = "Crystalforge Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30123,
                        ["set"] = "Crystalforge Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30129,
                        ["set"] = "Crystalforge Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 30144,
                        ["set"] = "Deathmantle",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 30169,
                        ["set"] = "Cataclysm Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 30185,
                        ["set"] = "Cataclysm Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 30164,
                        ["set"] = "Cataclysm Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Vanquished Champion",
    },
    [30237] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30118,
                        ["set"] = "Destroyer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30113,
                        ["set"] = "Destroyer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 30150,
                        ["set"] = "Avatar Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 30159,
                        ["set"] = "Avatar Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 30231,
                        ["set"] = "Nordrassil Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 30222,
                        ["set"] = "Nordrassil Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 30216,
                        ["set"] = "Nordrassil Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Vanquished Defender",
    },
    [30238] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 30139,
                        ["set"] = "Rift Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 30196,
                        ["set"] = "Tirisfal Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 30214,
                        ["set"] = "Corruptor Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Vanquished Hero",
    },
    [30239] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30135,
                        ["set"] = "Crystalforge Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30124,
                        ["set"] = "Crystalforge Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30130,
                        ["set"] = "Crystalforge Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 30145,
                        ["set"] = "Deathmantle",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 30170,
                        ["set"] = "Cataclysm Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 30189,
                        ["set"] = "Cataclysm Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 30165,
                        ["set"] = "Cataclysm Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Vanquished Champion",
    },
    [30240] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30119,
                        ["set"] = "Destroyer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30114,
                        ["set"] = "Destroyer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 30151,
                        ["set"] = "Avatar Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 30160,
                        ["set"] = "Avatar Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 30232,
                        ["set"] = "Nordrassil Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 30223,
                        ["set"] = "Nordrassil Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 30217,
                        ["set"] = "Nordrassil Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Vanquished Defender",
    },
    [30241] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 30140,
                        ["set"] = "Rift Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 30205,
                        ["set"] = "Tirisfal Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 30211,
                        ["set"] = "Corruptor Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Vanquished Hero",
    },
    [30242] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30136,
                        ["set"] = "Crystalforge Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30125,
                        ["set"] = "Crystalforge Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30131,
                        ["set"] = "Crystalforge Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 30146,
                        ["set"] = "Deathmantle",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 30171,
                        ["set"] = "Cataclysm Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 30190,
                        ["set"] = "Cataclysm Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 30166,
                        ["set"] = "Cataclysm Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Vanquished Champion",
    },
    [30243] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30120,
                        ["set"] = "Destroyer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30115,
                        ["set"] = "Destroyer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 30152,
                        ["set"] = "Avatar Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 30161,
                        ["set"] = "Avatar Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 30233,
                        ["set"] = "Nordrassil Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 30228,
                        ["set"] = "Nordrassil Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 30219,
                        ["set"] = "Nordrassil Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Vanquished Defender",
    },
    [30244] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 30141,
                        ["set"] = "Rift Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 30206,
                        ["set"] = "Tirisfal Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 30212,
                        ["set"] = "Corruptor Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Helm of the Vanquished Hero",
    },
    [30245] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30137,
                        ["set"] = "Crystalforge Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30126,
                        ["set"] = "Crystalforge Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30132,
                        ["set"] = "Crystalforge Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 30148,
                        ["set"] = "Deathmantle",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 30172,
                        ["set"] = "Cataclysm Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 30192,
                        ["set"] = "Cataclysm Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 30167,
                        ["set"] = "Cataclysm Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Vanquished Champion",
    },
    [30246] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30121,
                        ["set"] = "Destroyer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30116,
                        ["set"] = "Destroyer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 30153,
                        ["set"] = "Avatar Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 30162,
                        ["set"] = "Avatar Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 30234,
                        ["set"] = "Nordrassil Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 30229,
                        ["set"] = "Nordrassil Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 30220,
                        ["set"] = "Nordrassil Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Vanquished Defender",
    },
    [30247] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 30142,
                        ["set"] = "Rift Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 30207,
                        ["set"] = "Tirisfal Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 30213,
                        ["set"] = "Corruptor Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Vanquished Hero",
    },
    [30248] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30138,
                        ["set"] = "Crystalforge Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30127,
                        ["set"] = "Crystalforge Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30133,
                        ["set"] = "Crystalforge Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 30149,
                        ["set"] = "Deathmantle",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 30173,
                        ["set"] = "Cataclysm Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 30194,
                        ["set"] = "Cataclysm Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 30168,
                        ["set"] = "Cataclysm Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Vanquished Champion",
    },
    [30249] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30122,
                        ["set"] = "Destroyer Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30117,
                        ["set"] = "Destroyer Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 30154,
                        ["set"] = "Avatar Raiment",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 30163,
                        ["set"] = "Avatar Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 30235,
                        ["set"] = "Nordrassil Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 30230,
                        ["set"] = "Nordrassil Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 30221,
                        ["set"] = "Nordrassil Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Vanquished Defender",
    },
    [30250] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 30143,
                        ["set"] = "Rift Stalker Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 30210,
                        ["set"] = "Tirisfal Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 30215,
                        ["set"] = "Corruptor Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Vanquished Hero",
    },
    [31089] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30992,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30991,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30990,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 31066,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 31065,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 31052,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Forgotten Conqueror",
    },
    [31090] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 31028,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 31057,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 31043,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 31042,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 31041,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Forgotten Vanquisher",
    },
    [31091] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30975,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30976,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 31004,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 31017,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 31018,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 31016,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Chestguard of the Forgotten Protector",
    },
    [31092] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30983,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30985,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30982,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 31060,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 31061,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 31050,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Forgotten Conqueror",
    },
    [31093] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 31026,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 31055,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 31035,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 31034,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 31032,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Forgotten Vanquisher",
    },
    [31094] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30969,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30970,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 31001,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 31008,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 31011,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 31007,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Gloves of the Forgotten Protector",
    },
    [31095] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30972,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30974,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 31003,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 31014,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 31015,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 31012,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Forgotten Protector",
    },
    [31096] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 31027,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 31056,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 31040,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 31039,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 31037,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Helm of the Forgotten Vanquisher",
    },
    [31097] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30988,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30987,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30989,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 31063,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 31064,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 31051,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Helm of the Forgotten Conqueror",
    },
    [31098] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30994,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30995,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30993,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 31068,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 31067,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 31053,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Forgotten Conqueror",
    },
    [31099] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 31029,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 31058,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 31046,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 31044,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 31045,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Forgotten Vanquisher",
    },
    [31100] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30977,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30978,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 31005,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 31020,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 31021,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 31019,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Leggings of the Forgotten Protector",
    },
    [31101] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 30996,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 30998,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 30997,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 31069,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 31070,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 31054,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Forgotten Conqueror",
    },
    [31102] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 31030,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 31059,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 31049,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 31048,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 31047,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Forgotten Vanquisher",
    },
    [31103] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 30979,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 30980,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 31006,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 31023,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 31024,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 31022,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Pauldrons of the Forgotten Protector",
    },
    [34848] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 34432,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 34433,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 34431,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 34435,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 34434,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 34436,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Bracers of the Forgotten Conqueror",
    },
    [34851] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 34441,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 34442,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 34443,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 34437,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 34439,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 34438,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Bracers of the Forgotten Protector",
    },
    [34852] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 34448,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 34447,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 34446,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 34444,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 34445,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Bracers of the Forgotten Vanquisher",
    },
    [34853] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 34487,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 34488,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 34485,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 34527,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 34528,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 34541,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Belt of the Forgotten Conqueror",
    },
    [34854] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 34546,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 34547,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 34549,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 34542,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 34545,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 34543,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Belt of the Forgotten Protector",
    },
    [34855] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 34558,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 34557,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 34555,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 34556,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 34554,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Belt of the Forgotten Vanquisher",
    },
    [34856] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "PALADIN",
                ["items"] = {
                    {
                        ["id"] = 34559,
                        ["set"] = "Lightbringer Raiment",
                        ["spec"] = "Holy",
                    },
                    {
                        ["id"] = 34560,
                        ["set"] = "Lightbringer Armor",
                        ["spec"] = "Protection",
                    },
                    {
                        ["id"] = 34561,
                        ["set"] = "Lightbringer Battlegear",
                        ["spec"] = "Retribution",
                    },
                },
            },
            {
                ["class"] = "PRIEST",
                ["items"] = {
                    {
                        ["id"] = 34562,
                        ["set"] = "Vestments of Absolution",
                        ["spec"] = "Holy / Discipline",
                    },
                    {
                        ["id"] = 34563,
                        ["set"] = "Absolution Regalia",
                        ["spec"] = "Shadow",
                    },
                },
            },
            {
                ["class"] = "WARLOCK",
                ["items"] = {
                    {
                        ["id"] = 34564,
                        ["set"] = "Malefic Raiment",
                        ["spec"] = "All specs",
                    },
                },
            },
        },
        ["name"] = "Boots of the Forgotten Conqueror",
    },
    [34857] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "WARRIOR",
                ["items"] = {
                    {
                        ["id"] = 34569,
                        ["set"] = "Onslaught Battlegear",
                        ["spec"] = "Arms / Fury",
                    },
                    {
                        ["id"] = 34568,
                        ["set"] = "Onslaught Armor",
                        ["spec"] = "Protection",
                    },
                },
            },
            {
                ["class"] = "HUNTER",
                ["items"] = {
                    {
                        ["id"] = 34570,
                        ["set"] = "Gronnstalker's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "SHAMAN",
                ["items"] = {
                    {
                        ["id"] = 34566,
                        ["set"] = "Skyshatter Regalia",
                        ["spec"] = "Elemental",
                    },
                    {
                        ["id"] = 34567,
                        ["set"] = "Skyshatter Harness",
                        ["spec"] = "Enhancement",
                    },
                    {
                        ["id"] = 34565,
                        ["set"] = "Skyshatter Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Boots of the Forgotten Protector",
    },
    [34858] = {
        ["era"] = "tbc",
        ["groups"] = {
            {
                ["class"] = "ROGUE",
                ["items"] = {
                    {
                        ["id"] = 34575,
                        ["set"] = "Slayer's Armor",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "MAGE",
                ["items"] = {
                    {
                        ["id"] = 34574,
                        ["set"] = "Tempest Regalia",
                        ["spec"] = "All specs",
                    },
                },
            },
            {
                ["class"] = "DRUID",
                ["items"] = {
                    {
                        ["id"] = 34572,
                        ["set"] = "Thunderheart Regalia",
                        ["spec"] = "Balance",
                    },
                    {
                        ["id"] = 34573,
                        ["set"] = "Thunderheart Harness",
                        ["spec"] = "Feral (Cat / Bear)",
                    },
                    {
                        ["id"] = 34571,
                        ["set"] = "Thunderheart Raiment",
                        ["spec"] = "Restoration",
                    },
                },
            },
        },
        ["name"] = "Boots of the Forgotten Vanquisher",
    },
}
