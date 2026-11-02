-- Maps and home-card artwork imported from the installed Forever beta.
-- Only instances already present in Anniversary are eligible. Existing maps win.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ or not FDJ.IS_TBC_ANNIVERSARY then return end
local MAPS = {
    ["Blackrock Depths"] = {
        ["bosses"] = {
            {
                ["floor"] = 1,
                ["name"] = "High Interrogator Gerstahn",
                ["x"] = 0.474,
                ["y"] = 0.922,
            },
            {
                ["floor"] = 1,
                ["name"] = "Lord Roccor",
                ["x"] = 0.556,
                ["y"] = 0.67,
            },
            {
                ["floor"] = 1,
                ["name"] = "Houndmaster Grebmar",
                ["x"] = 0.535,
                ["y"] = 0.573,
            },
            {
                ["floor"] = 1,
                ["name"] = "Bael'Gar",
                ["x"] = 0.251,
                ["y"] = 0.534,
            },
            {
                ["floor"] = 1,
                ["name"] = "Lord Incendius",
                ["x"] = 0.564,
                ["y"] = 0.311,
            },
            {
                ["floor"] = 1,
                ["name"] = "Fineous Darkvire",
                ["x"] = 0.635,
                ["y"] = 0.211,
            },
            {
                ["floor"] = 2,
                ["name"] = "Gorosh the Dervish",
                ["x"] = 0.53,
                ["y"] = 0.868,
            },
            {
                ["floor"] = 2,
                ["name"] = "Grizzle",
                ["x"] = 0.547,
                ["y"] = 0.883,
            },
            {
                ["floor"] = 2,
                ["name"] = "Eviscerator",
                ["x"] = 0.547,
                ["y"] = 0.913,
            },
            {
                ["floor"] = 2,
                ["name"] = "Ok'thor the Breaker",
                ["x"] = 0.53,
                ["y"] = 0.928,
            },
            {
                ["floor"] = 2,
                ["name"] = "Anub'shiah",
                ["x"] = 0.513,
                ["y"] = 0.913,
            },
            {
                ["floor"] = 2,
                ["name"] = "Hedrum the Creeper",
                ["x"] = 0.513,
                ["y"] = 0.883,
            },
            {
                ["floor"] = 2,
                ["name"] = "Pyromancer Loregrain",
                ["x"] = 0.549,
                ["y"] = 0.948,
            },
            {
                ["floor"] = 2,
                ["name"] = "Warder Stilgiss",
                ["x"] = 0.602,
                ["y"] = 0.659,
            },
            {
                ["floor"] = 2,
                ["name"] = "General Angerforge",
                ["x"] = 0.363,
                ["y"] = 0.823,
            },
            {
                ["floor"] = 2,
                ["name"] = "Golem Lord Argelmach",
                ["x"] = 0.364,
                ["y"] = 0.651,
            },
            {
                ["floor"] = 2,
                ["name"] = "Hurley Blackbreath",
                ["x"] = 0.505,
                ["y"] = 0.704,
            },
            {
                ["floor"] = 2,
                ["name"] = "Plugger Spazzring",
                ["x"] = 0.477,
                ["y"] = 0.657,
            },
            {
                ["floor"] = 2,
                ["name"] = "Phalanx",
                ["x"] = 0.458,
                ["y"] = 0.564,
            },
            {
                ["floor"] = 2,
                ["name"] = "Ambassador Flamelash",
                ["x"] = 0.538,
                ["y"] = 0.485,
            },
            {
                ["floor"] = 2,
                ["name"] = "The Seven",
                ["npcID"] = 9039,
                ["x"] = 0.538,
                ["y"] = 0.247,
            },
            {
                ["floor"] = 2,
                ["name"] = "Magmus",
                ["x"] = 0.796,
                ["y"] = 0.118,
            },
            {
                ["floor"] = 2,
                ["name"] = "Princess Moira Bronzebeard",
                ["x"] = 0.92,
                ["y"] = 0.11,
            },
            {
                ["floor"] = 2,
                ["name"] = "Emperor Dagran Thaurissan",
                ["x"] = 0.909,
                ["y"] = 0.118,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.329,
            ["y"] = 0.794,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\BlackrockDepths\\BlackrockDepths1_",
                ["uiMapID"] = 242,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\BlackrockDepths\\BlackrockDepths2_",
                ["uiMapID"] = 243,
            },
        },
    },
    ["Dire Maul: East"] = {
        ["bosses"] = {
            {
                ["floor"] = 2,
                ["name"] = "Lethtendris",
                ["x"] = 0.438,
                ["y"] = 0.481,
            },
            {
                ["floor"] = 1,
                ["name"] = "Zevrim Thornhoof",
                ["x"] = 0.575,
                ["y"] = 0.743,
            },
            {
                ["floor"] = 1,
                ["name"] = "Hydrospawn",
                ["x"] = 0.536,
                ["y"] = 0.715,
            },
            {
                ["floor"] = 1,
                ["name"] = "Alzzin the Wildshaper",
                ["x"] = 0.566,
                ["y"] = 0.288,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.281,
            ["y"] = 0.554,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul6_",
                ["uiMapID"] = 240,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul5_",
                ["uiMapID"] = 239,
            },
        },
    },
    ["Dire Maul: North"] = {
        ["bosses"] = {
            {
                ["name"] = "Guard Mol'dar",
                ["x"] = 0.695,
                ["y"] = 0.76,
            },
            {
                ["name"] = "Stomper Kreeg",
                ["x"] = 0.612,
                ["y"] = 0.692,
            },
            {
                ["name"] = "Guard Fengus",
                ["x"] = 0.494,
                ["y"] = 0.78,
            },
            {
                ["name"] = "Guard Slip'kik",
                ["x"] = 0.266,
                ["y"] = 0.571,
            },
            {
                ["name"] = "Captain Kromcrush",
                ["x"] = 0.318,
                ["y"] = 0.506,
            },
            {
                ["name"] = "Cho'Rush the Observer",
                ["x"] = 0.3,
                ["y"] = 0.29,
            },
            {
                ["name"] = "King Gordok",
                ["x"] = 0.319,
                ["y"] = 0.229,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.717,
            ["y"] = 0.924,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul1_",
                ["uiMapID"] = 235,
            },
        },
    },
    ["Dire Maul: West"] = {
        ["bosses"] = {
            {
                ["floor"] = 1,
                ["name"] = "Tendris Warpwood",
                ["x"] = 0.336,
                ["y"] = 0.536,
            },
            {
                ["floor"] = 1,
                ["name"] = "Illyanna Ravenoak",
                ["x"] = 0.203,
                ["y"] = 0.776,
            },
            {
                ["floor"] = 2,
                ["name"] = "Magister Kalendris",
                ["x"] = 0.338,
                ["y"] = 0.45,
            },
            {
                ["floor"] = 2,
                ["name"] = "Tsu'zee",
                ["x"] = 0.322,
                ["y"] = 0.143,
            },
            {
                ["floor"] = 3,
                ["name"] = "Immol'thar",
                ["x"] = 0.349,
                ["y"] = 0.575,
            },
            {
                ["floor"] = 3,
                ["name"] = "Prince Tortheldrin",
                ["x"] = 0.622,
                ["y"] = 0.231,
            },
        },
        ["entrance"] = {
            ["angle"] = 180,
            ["floor"] = 1,
            ["x"] = 0.935,
            ["y"] = 0.507,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul2_",
                ["uiMapID"] = 236,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul3_",
                ["uiMapID"] = 237,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\DireMaul\\DireMaul4_",
                ["uiMapID"] = 238,
            },
        },
    },
    ["Maraudon"] = {
        ["bosses"] = {
            {
                ["floor"] = 1,
                ["name"] = "Noxxion",
                ["x"] = 0.362,
                ["y"] = 0.098,
            },
            {
                ["floor"] = 1,
                ["name"] = "Razorlash",
                ["x"] = 0.166,
                ["y"] = 0.344,
            },
            {
                ["floor"] = 1,
                ["name"] = "Lord Vyletongue",
                ["x"] = 0.378,
                ["y"] = 0.704,
            },
            {
                ["floor"] = 1,
                ["name"] = "Meshlok the Harvester",
                ["x"] = 0.246,
                ["y"] = 0.874,
            },
            {
                ["floor"] = 2,
                ["name"] = "Celebras the Cursed",
                ["x"] = 0.245,
                ["y"] = 0.143,
            },
            {
                ["floor"] = 2,
                ["name"] = "Landslide",
                ["x"] = 0.408,
                ["y"] = 0.487,
            },
            {
                ["floor"] = 2,
                ["name"] = "Tinkerer Gizlock",
                ["x"] = 0.484,
                ["y"] = 0.686,
            },
            {
                ["floor"] = 2,
                ["name"] = "Rotgrip",
                ["x"] = 0.413,
                ["y"] = 0.817,
            },
            {
                ["floor"] = 2,
                ["name"] = "Princess Theradras",
                ["x"] = 0.258,
                ["y"] = 0.788,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.618,
            ["y"] = 0.281,
        },
        ["entrances"] = {
            {
                ["angle"] = 0,
                ["color"] = {
                    1,
                    0.55,
                    0.1,
                },
                ["floor"] = 1,
                ["labelKey"] = "MAP_ENTRANCE_ORANGE",
                ["x"] = 0.618,
                ["y"] = 0.281,
            },
            {
                ["angle"] = 0,
                ["color"] = {
                    0.78,
                    0.45,
                    1,
                },
                ["floor"] = 1,
                ["labelKey"] = "MAP_ENTRANCE_PURPLE",
                ["x"] = 0.764,
                ["y"] = 0.659,
            },
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\Maraudon\\Maraudon1_",
                ["uiMapID"] = 280,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\Maraudon\\Maraudon2_",
                ["uiMapID"] = 281,
            },
        },
    },
    ["Razorfen Downs"] = {
        ["bosses"] = {
            {
                ["name"] = "Tuten'kash",
                ["x"] = 0.589,
                ["y"] = 0.342,
            },
            {
                ["name"] = "Mordresh Fire Eye",
                ["x"] = 0.86,
                ["y"] = 0.467,
            },
            {
                ["name"] = "Glutton",
                ["x"] = 0.345,
                ["y"] = 0.664,
            },
            {
                ["name"] = "Amnennar the Coldbringer",
                ["x"] = 0.455,
                ["y"] = 0.582,
            },
        },
        ["entrance"] = {
            ["angle"] = 90,
            ["floor"] = 1,
            ["x"] = 0.234,
            ["y"] = 0.185,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\RazorfenDowns\\RazorfenDowns1_",
                ["uiMapID"] = 300,
            },
        },
    },
    ["Scarlet Monastery: Armory"] = {
        ["bosses"] = {
            {
                ["name"] = "Herod",
                ["x"] = 0.785,
                ["y"] = 0.118,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.61,
            ["y"] = 0.945,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery3_",
                ["uiMapID"] = 304,
            },
        },
    },
    ["Scarlet Monastery: Cathedral"] = {
        ["bosses"] = {
            {
                ["name"] = "High Inquisitor Fairbanks",
                ["x"] = 0.555,
                ["y"] = 0.25,
            },
            {
                ["name"] = "Scarlet Commander Mograine",
                ["x"] = 0.49,
                ["y"] = 0.285,
            },
            {
                ["name"] = "High Inquisitor Whitemane",
                ["x"] = 0.49,
                ["y"] = 0.165,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.618,
            ["y"] = 0.915,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\ScarletMonastery\\ScarletMonastery4_",
                ["uiMapID"] = 305,
            },
        },
    },
    ["Stratholme: Living"] = {
        ["bosses"] = {
            {
                ["name"] = "Skul",
                ["x"] = 0.574,
                ["y"] = 0.652,
            },
            {
                ["name"] = "Hearthsinger Forresten",
                ["x"] = 0.605,
                ["y"] = 0.327,
            },
            {
                ["name"] = "The Unforgiven",
                ["x"] = 0.734,
                ["y"] = 0.204,
            },
            {
                ["name"] = "Timmy the Cruel",
                ["x"] = 0.495,
                ["y"] = 0.18,
            },
            {
                ["name"] = "Postmaster Malown",
                ["x"] = 0.558,
                ["y"] = 0.684,
            },
            {
                ["name"] = "Cannon Master Willey",
                ["x"] = 0.042,
                ["y"] = 0.51,
            },
            {
                ["name"] = "Archivist Galford",
                ["x"] = 0.272,
                ["y"] = 0.75,
            },
            {
                ["name"] = "Balnazzar",
                ["x"] = 0.204,
                ["y"] = 0.818,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.675,
            ["y"] = 0.877,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\Stratholme\\Stratholme1_",
                ["uiMapID"] = 317,
            },
        },
    },
    ["Stratholme: Undead"] = {
        ["bosses"] = {
            {
                ["name"] = "Magistrate Barthilas",
                ["x"] = 0.566,
                ["y"] = 0.161,
            },
            {
                ["name"] = "Stonespine",
                ["x"] = 0.649,
                ["y"] = 0.489,
            },
            {
                ["name"] = "Nerub'enkan",
                ["x"] = 0.572,
                ["y"] = 0.461,
            },
            {
                ["name"] = "Baroness Anastari",
                ["x"] = 0.745,
                ["y"] = 0.469,
            },
            {
                ["name"] = "Maleki the Pallid",
                ["x"] = 0.674,
                ["y"] = 0.227,
            },
            {
                ["name"] = "Ramstein the Gorger",
                ["x"] = 0.456,
                ["y"] = 0.198,
            },
            {
                ["name"] = "Baron Rivendare",
                ["x"] = 0.372,
                ["y"] = 0.199,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.658,
            ["y"] = 0.902,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\Stratholme\\Stratholme2_",
                ["uiMapID"] = 318,
            },
        },
    },
    ["The Temple of Atal'Hakkar"] = {
        ["bosses"] = {
            {
                ["name"] = "Avatar of Hakkar",
                ["x"] = 0.243,
                ["y"] = 0.459,
            },
            {
                ["name"] = "Jammal'an the Prophet",
                ["x"] = 0.76,
                ["y"] = 0.37,
            },
            {
                ["name"] = "Ogom the Wretched",
                ["x"] = 0.78,
                ["y"] = 0.385,
            },
            {
                ["name"] = "Dreamscythe",
                ["x"] = 0.43,
                ["y"] = 0.865,
            },
            {
                ["name"] = "Weaver",
                ["x"] = 0.478,
                ["y"] = 0.83,
            },
            {
                ["name"] = "Morphaz",
                ["x"] = 0.461,
                ["y"] = 0.845,
            },
            {
                ["name"] = "Hazzas",
                ["x"] = 0.448,
                ["y"] = 0.851,
            },
            {
                ["name"] = "Shade of Eranikus",
                ["x"] = 0.686,
                ["y"] = 0.874,
            },
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\TheTempleOfAtalHakkar\\TheTempleOfAtalHakkar1_",
                ["uiMapID"] = 220,
            },
        },
    },
    ["Uldaman"] = {
        ["bosses"] = {
            {
                ["floor"] = 1,
                ["mapNote"] = "The Lost Dwarves: Baelog, Eric \"The Swift\" and Olaf share this room.",
                ["name"] = "Baelog",
                ["x"] = 0.584,
                ["y"] = 0.92,
            },
            {
                ["floor"] = 1,
                ["name"] = "Revelosh",
                ["x"] = 0.534,
                ["y"] = 0.725,
            },
            {
                ["floor"] = 1,
                ["name"] = "Ironaya",
                ["x"] = 0.372,
                ["y"] = 0.739,
            },
            {
                ["floor"] = 1,
                ["name"] = "Ancient Stone Keeper",
                ["x"] = 0.475,
                ["y"] = 0.44,
            },
            {
                ["floor"] = 1,
                ["name"] = "Galgann Firehammer",
                ["x"] = 0.267,
                ["y"] = 0.327,
            },
            {
                ["floor"] = 1,
                ["name"] = "Grimlok",
                ["x"] = 0.219,
                ["y"] = 0.256,
            },
            {
                ["floor"] = 2,
                ["name"] = "Archaedas",
                ["x"] = 0.553,
                ["y"] = 0.504,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.679,
            ["y"] = 0.725,
        },
        ["floors"] = {
            {
                ["tiles"] = "Interface\\WorldMap\\Uldaman\\Uldaman1_",
                ["uiMapID"] = 230,
            },
            {
                ["tiles"] = "Interface\\WorldMap\\Uldaman\\Uldaman2_",
                ["uiMapID"] = 231,
            },
        },
    },
    ["Zul'Farrak"] = {
        ["bosses"] = {
            {
                ["name"] = "Antu'sul",
                ["x"] = 0.646,
                ["y"] = 0.276,
            },
            {
                ["name"] = "Witch Doctor Zum'rah",
                ["x"] = 0.442,
                ["y"] = 0.176,
            },
            {
                ["name"] = "Shadowpriest Sezz'ziz",
                ["x"] = 0.296,
                ["y"] = 0.174,
            },
            {
                ["name"] = "Gahz'rilla",
                ["x"] = 0.312,
                ["y"] = 0.414,
            },
            {
                ["name"] = "Zerillis",
                ["x"] = 0.548,
                ["y"] = 0.401,
            },
            {
                ["name"] = "Sandarr Dunereaver",
                ["npcID"] = 10080,
                ["x"] = 0.524,
                ["y"] = 0.428,
            },
            {
                ["name"] = "Dustwraith",
                ["x"] = 0.31,
                ["y"] = 0.16,
            },
            {
                ["name"] = "Ruuzlu",
                ["npcID"] = 7797,
                ["x"] = 0.432,
                ["y"] = 0.342,
            },
            {
                ["name"] = "Chief Ukorz Sandscalp",
                ["x"] = 0.422,
                ["y"] = 0.329,
            },
        },
        ["entrance"] = {
            ["angle"] = 0,
            ["floor"] = 1,
            ["x"] = 0.552,
            ["y"] = 0.88,
        },
        ["floors"] = {
            {
                ["texBottom"] = 0.6669921875,
                ["texture"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ZulFarrakMap",
            },
        },
    },
}
local CARDS = {
    ["Blackrock Depths"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackrockDepthsHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Dire Maul: East"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DireMaulHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Dire Maul: North"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DireMaulNorthHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Dire Maul: West"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\DireMaulWestHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Lower Blackrock Spire"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\BlackrockSpireHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Maraudon"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\MaraudonHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Razorfen Downs"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\RazorfenDownsHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Scarlet Monastery: Armory"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ScarletMonasteryArmoryHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Scarlet Monastery: Cathedral"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ScarletMonasteryCathedralHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Scholomance"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ScholomanceHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Stratholme: Living"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\StratholmeHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Stratholme: Undead"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\StratholmeUndeadHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["The Temple of Atal'Hakkar"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\SunkenTempleHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Uldaman"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\UldamanHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Upper Blackrock Spire"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\UpperBlackrockSpireHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
    ["Zul'Farrak"] = {
        ["art"] = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\ZulFarrakHome",
        ["texCoord"] = {
            0,
            1,
            0.06,
            0.94,
        },
    },
}
FDJ.DUNGEON_MAPS = FDJ.DUNGEON_MAPS or {}
for name, map in pairs(MAPS) do
    if FDJ.DB and FDJ.DB[name] and not FDJ.DUNGEON_MAPS[name] then
        FDJ.DUNGEON_MAPS[name] = map
    end
end
-- Mutate the existing tables: the journal holds references to them.
FDJ.DUNGEON_HOME_ART = FDJ.DUNGEON_HOME_ART or {}
FDJ.DUNGEON_HOME_TEXCOORD = FDJ.DUNGEON_HOME_TEXCOORD or {}
for name, card in pairs(CARDS) do
    if FDJ.DB and FDJ.DB[name] then
        FDJ.DUNGEON_HOME_ART[name] = card.art
        FDJ.DUNGEON_HOME_TEXCOORD[name] = card.texCoord
    end
end
