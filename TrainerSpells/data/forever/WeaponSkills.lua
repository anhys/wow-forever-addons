TrainerSpellsWeaponSkills = {
    order = {196, 197, 198, 199, 201, 202, 1180, 15590, 227, 200, 264, 266, 5011, 2567},
    trainers = {
        [2704] = {
            zoneID = 1637,
            x = 81.5,
            y = 19.6,
            names = {enUS = "Hanashi", koKR = "하나시", ruRU = "Ханаши", zhCN = "哈纳什", zhTW = "哈納什"},
        },
        [11865] = {
            zoneID = 1537,
            x = 61.2,
            y = 89.5,
            names = {deDE = "Buliwyf Steinhand", enUS = "Buliwyf Stonehand", esES = "Buliwyf Petramano", koKR = "불리위프 스톤헤드", ptBR = "Bulif Manopedra", ruRU = "Бульвайф Крепкорук", zhCN = "布里维夫·石手", zhTW = "布里維夫·石拳"},
        },
        [11866] = {
            zoneID = 1657,
            x = 57.7,
            y = 46.0,
            names = {deDE = "Ilyenia Mondfeuer", enUS = "Ilyenia Moonfire", esES = "Ilyenia Fuegolunar", frFR = "Ilyenia Lunéclat", koKR = "일예니아 문파이어", ptBR = "Ilyenia Flameluna", ruRU = "Илиения Лунное Пламя", zhCN = "伊琳尼雅·月火", zhTW = "伊琳尼雅·月火"},
        },
        [11867] = {
            zoneID = 1519,
            x = 63.9,
            y = 69.1,
            names = {enUS = "Woo Ping", koKR = "우 핑", ruRU = "Ву Пинг", zhCN = "吴平", zhTW = "吳平"},
        },
        [11868] = {
            zoneID = 1637,
            x = 81.7,
            y = 19.6,
            names = {enUS = "Sayoc", koKR = "사요크", ruRU = "Сайок", zhCN = "塞尤克", zhTW = "塞尤克"},
        },
        [11869] = {
            zoneID = 1638,
            x = 40.0,
            y = 63.1,
            names = {enUS = "Ansekhwa", koKR = "안세크화", ruRU = "Ансеква", zhCN = "安塞瓦", zhTW = "安塞瓦"},
        },
        [11870] = {
            zoneID = 1497,
            x = 57.3,
            y = 32.8,
            names = {enUS = "Archibald", koKR = "아키발드", ptBR = "Arquibaldo", ruRU = "Арчибальд", zhCN = "阿基巴德", zhTW = "阿基巴德"},
        },
        [13084] = {
            zoneID = 1537,
            x = 62.2,
            y = 89.6,
            names = {deDE = "Bixi Wobbelbonk", enUS = "Bixi Wobblebonk", esES = "Bixi Tambaleapié", frFR = "Bixi Oscillognon", koKR = "빅시 와블봉크", ptBR = "Bixi Bateagita", ruRU = "Бикси Пошатушка", zhCN = "比克斯", zhTW = "比克斯"},
        },
    },
    zones = {
        [1497] = {
            uiMapID = 1458,
            icon = 135766
        },
        [1519] = {
            uiMapID = 1453,
            icon = 135763
        },
        [1537] = {
            uiMapID = 1455,
            icon = 135757
        },
        [1637] = {
            uiMapID = 1454,
            icon = 135759
        },
        [1638] = {
            uiMapID = 1456,
            icon = 135765
        },
        [1657] = {
            uiMapID = 1457,
            icon = 135755
        },
    },
    skills = {
        [196] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                SHAMAN = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1637}
            },
            trainers = {
                Alliance = {11865},
                Horde = {2704}
            },
        },
        [197] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                SHAMAN = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1637}
            },
            trainers = {
                Alliance = {11865},
                Horde = {2704}
            },
        },
        [198] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                ROGUE = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
            trainers = {
                Alliance = {11865},
                Horde = {11869}
            },
        },
        [199] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
            trainers = {
                Alliance = {11865},
                Horde = {11869}
            },
        },
        [200] = {
            cost = 10000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                DRUID = true
            },
            level = 20,
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
            trainers = {
                Alliance = {11867},
                Horde = {11870}
            },
        },
        [201] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                ROGUE = true,
                MAGE = true,
                WARLOCK = true
            },
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
            trainers = {
                Alliance = {11867},
                Horde = {11870}
            },
        },
        [202] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true
            },
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
            trainers = {
                Alliance = {11867},
                Horde = {11870}
            },
        },
        [227] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true,
                WARLOCK = true,
                MAGE = true
            },
            locations = {
                Alliance = {1519, 1657},
                Horde = {1637, 1638}
            },
            trainers = {
                Alliance = {11867, 11866},
                Horde = {2704, 11869}
            },
        },
        [264] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1657},
                Horde = {1637}
            },
            trainers = {
                Alliance = {11866},
                Horde = {2704}
            },
        },
        [266] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
            trainers = {
                Alliance = {11865},
                Horde = {11869}
            },
        },
        [1180] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true,
                WARLOCK = true,
                MAGE = true
            },
            locations = {
                Alliance = {1537, 1519, 1657},
                Horde = {1637, 1497}
            },
            trainers = {
                Alliance = {13084, 11867, 11866},
                Horde = {11868, 11870}
            },
        },
        [2567] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537, 1657},
                Horde = {1637}
            },
            trainers = {
                Alliance = {13084, 11866},
                Horde = {2704}
            },
        },
        [5011] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537, 1519},
                Horde = {1497}
            },
            trainers = {
                Alliance = {13084, 11867},
                Horde = {11870}
            },
        },
        [15590] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537, 1657},
                Horde = {1637}
            },
            trainers = {
                Alliance = {11865, 11866},
                Horde = {11868}
            },
        },
    },
}

local _, _, _, weaponSkillsInterface = GetBuildInfo()
weaponSkillsInterface = tonumber(weaponSkillsInterface) or 0
if weaponSkillsInterface ~= 16001 then
    if weaponSkillsInterface < 30000 then TrainerSpellsWeaponSkills.skills[196].classes.ROGUE = nil end
    if weaponSkillsInterface < 20000 then
        TrainerSpellsWeaponSkills.skills[197].classes.SHAMAN = nil
        TrainerSpellsWeaponSkills.skills[199].classes.SHAMAN = nil
    end
end
