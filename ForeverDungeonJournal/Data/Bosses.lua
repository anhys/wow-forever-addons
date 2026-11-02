local ADDON_NAME, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

FDJ.BOSS_LEVELS = {
    ["Excavation Site: Wetlands"] = {
        ["Saltspine"] = "28",
        ["Shadetooth"] = "29",
        ["Relic Guardian"] = "31",
    },
    ["City of Dalaran"] = {
        ["Atrexis the Grave Knight"] = "29",
        ["Arcane Anomaly"] = "30",
        ["Unstable Sentinel"] = "31",
        ["Fel Ancient"] = "32",
        ["Mana Devourer"] = "31",
        ["Arcanic Enigma"] = "30",
        ["Shade of the Archmage"] = "33",
    },
    ["Gnomeregan"] = {
        ["Grubbis"] = "32",
        ["Viscous Fallout"] = "30",
        ["Electrocutioner 6000"] = "32",
        ["Crowd Pummeler 9-60"] = "32",
        ["Mekgineer Thermaplugg"] = "34",
        ["Dark Iron Ambassador"] = "33",
    },
    ["Razorfen Kraul"] = {
        ["Roogug"] = "28",
        ["Aggem Thorncurse"] = "30",
        ["Death Speaker Jargba"] = "30",
        ["Overlord Ramtusk"] = "32",
        ["Agathelos the Raging"] = "33",
        ["Charlga Razorflank"] = "33",
        ["Blind Hunter"] = "32",
        ["Earthcaller Halmgar"] = "32",
    },
    ["Scarlet Monastery: Graveyard"] = {
        ["Interrogator Vishas"] = "32",
        ["Azshir the Sleepless"] = "33",
        ["Fallen Champion"] = "33",
        ["Ironspine"] = "33",
        ["Bloodmage Thalnos"] = "34",
    },
    ["Scarlet Monastery: Library"] = {
        ["Houndmaster Loksey"] = "34",
        ["Arcanist Doan"] = "37",
    },
    ["Hall of Thanes"] = {
        ["Faldrim Anvilmar"] = "16",
        ["Magmatus"] = "16",
        ["Plunder"] = "16",
        ["Durgen Dirgehammer"] = "16",
    },
    ["Ruins of Lordaeron"] = {
        ["The Baron"] = "17",
        ["Witherfang"] = "17",
        ["The Abandoned"] = "18",
        ["Bjork"] = "19",
        ["Rath'mael"] = "20",
        ["Viktor the Vile"] = "19",
        ["Lordaeron Captain"] = "19",
    },
    ["Ragefire Chasm"] = {
        ["Oggleflint"] = "16",
        ["Taragaman the Hungerer"] = "16",
        ["Jergosh the Invoker"] = "16",
        ["Bazzalan"] = "16",
    },
    ["The Deadmines"] = {
        ["Rhahk'Zor"] = "19",
        ["Miner Johnson"] = "19",
        ["Sneed's Shredder"] = "20",
        ["Sneed"] = "20",
        ["Gilnid"] = "20",
        ["Mr. Smite"] = "20",
        ["Captain Greenskin"] = "20",
        ["Edwin VanCleef"] = "21",
        ["Cookie"] = "20",
    },
    ["Wailing Caverns"] = {
        ["Lord Cobrahn"] = "20",
        ["Lady Anacondra"] = "20",
        ["Kresh"] = "20",
        ["Lord Pythas"] = "21",
        ["Skum"] = "21",
        ["Lord Serpentis"] = "21",
        ["Verdan the Everliving"] = "21",
        ["Mutanus the Devourer"] = "22",
        ["Deviate Faerie Dragon"] = "20",
    },
    ["Shadowfang Keep"] = {
        ["Rethilgore"] = "20",
        ["Fel Steed / Shadow Charger"] = "19-21",
        ["Razorclaw the Butcher"] = "22",
        ["Baron Silverlaine"] = "24",
        ["Commander Springvale"] = "24",
        ["Odo the Blindwatcher"] = "24",
        ["Deathsworn Captain"] = "25",
        ["Arugal's Voidwalker"] = "24-25",
        ["Fenrus the Devourer"] = "25",
        ["Wolf Master Nandos"] = "25",
        ["Archmage Arugal"] = "24",
    },
    ["The Stockade"] = {
        ["Targorr the Dread"] = "24",
        ["Kam Deepfury"] = "27",
        ["Hamhock"] = "28",
        ["Dextren Ward"] = "26",
        ["Bazil Thredd"] = "29",
        ["Bruegal Ironknuckle"] = "26",
    },
    ["Blackfathom Deeps"] = {
        ["Ghamoo-ra"] = "25",
        ["Lady Sarevess"] = "25",
        ["Gelihast"] = "26",
        ["Lorgus Jett"] = "26",
        ["Baron Aquanis"] = "28",
        ["Old Serra'kis"] = "26",
        ["Twilight Lord Kelris"] = "27",
        ["Aku'mai"] = "28",
    },
}

FDJ.STATIC_DISPLAY_IDS = {
    -- Wailing Caverns
    [3669] = 4213,  -- Lord Cobrahn
    [3671] = 4313,  -- Lady Anacondra
    [3653] = 5126,  -- Kresh
    [3670] = 4214,  -- Lord Pythas
    [3674] = 4203,  -- Skum
    [3673] = 4215,  -- Lord Serpentis
    [5775] = 4256,  -- Verdan the Everliving
    [3654] = 4088,  -- Mutanus the Devourer
    [5912] = 1267,  -- Deviate Faerie Dragon

    -- The Deadmines
    [644]  = 14403, -- Rhahk'Zor
    [3586] = 556,   -- Miner Johnson
    [642]  = 1269,  -- Sneed's Shredder
    [643]  = 7125,  -- Sneed
    [1763] = 7124,  -- Gilnid
    [646]  = 2026,  -- Mr. Smite
    [647]  = 7113,  -- Captain Greenskin
    [639]  = 2029,  -- Edwin VanCleef
    [645]  = 1305,  -- Cookie

    -- Blackfathom Deeps
    [4887]  = 5027,  -- Ghamoo-ra
    [4831]  = 4979,  -- Lady Sarevess
    [6243]  = 1773,  -- Gelihast
    [12902] = 12822, -- Lorgus Jett
    [12876] = 110,   -- Baron Aquanis
    [4830]  = 1816,  -- Old Serra'kis
    [4832]  = 4939,  -- Twilight Lord Kelris
    [4829]  = 2837,  -- Aku'mai

    -- Ragefire Chasm
    [11517] = 11611, -- Oggleflint
    [11520] = 7970,  -- Taragaman the Hungerer
    [11518] = 11429, -- Jergosh the Invoker
    [11519] = 2007,  -- Bazzalan

    -- Shadowfang Keep
    [3914] = 524,   -- Rethilgore
    [3864] = 1951,  -- Fel Steed / Shadow Charger
    [3886] = 524,   -- Razorclaw the Butcher
    [3887] = 3222,  -- Baron Silverlaine
    [4278] = 3223,  -- Commander Springvale
    [4279] = 522,   -- Odo the Blindwatcher
    [3872] = 3224,  -- Deathsworn Captain
    [4627] = 1131,  -- Arugal's Voidwalker
    [4274] = 2352,  -- Fenrus the Devourer
    [3927] = 11179, -- Wolf Master Nandos
    [4275] = 2353,  -- Archmage Arugal

    -- Resolved by the Forever client (build 70170) and bundled so these
    -- portraits render immediately instead of waiting on the model resolver.

    -- Hall of Thanes
    [261306] = 142826,  -- Faldrim Anvilmar
    [261311] = 142840,  -- Plunder
    [261319] = 142837,  -- Durgen Dirgehammer

    -- Ruins of Lordaeron
    [250660] = 144188,  -- The Baron
    [250483] = 144189,  -- Witherfang
    [250631] = 138667,  -- The Abandoned
    [256097] = 144170,  -- Bjork
    [250657] = 144175,  -- Rath'mael
    [256035] = 139455,  -- Viktor the Vile

    -- The Stockade
    [1696] = 517,       -- Targorr the Dread
    [1666] = 825,       -- Kam Deepfury
    [1717] = 3250,      -- Hamhock
    [1663] = 2149,      -- Dextren Ward
    [1716] = 1621,      -- Bazil Thredd
    [1720] = 2142,      -- Bruegal Ironknuckle

    -- Excavation Site: Wetlands
    [260322] = 144209,  -- Saltspine
    [260325] = 144210,  -- Shadetooth
    [260326] = 144224,  -- Relic Guardian

    -- City of Dalaran
    [247126] = 145787,  -- Atrexis the Grave Knight
    [245999] = 129891,  -- Arcane Anomaly
    [246003] = 129894,  -- Fel Ancient
    [246017] = 129954,  -- Unstable Sentinel
    [246931] = 130220,  -- Mana Wraith
    [246008] = 129895,  -- Mana Devourer
    [246016] = 129900,  -- Arcanic Enigma (Mana Elemental)
    [247032] = 130235,  -- Lyn the Ignored
    [246020] = 130061,  -- Shade of the Archmage

    -- Gnomeregan
    [7361] = 144378,    -- Grubbis
    [7079] = 5497,      -- Viscous Fallout
    [6235] = 6915,      -- Electrocutioner 6000
    [6229] = 6774,      -- Crowd Pummeler 9-60
    [7800] = 6980,      -- Mekgineer Thermaplugg
    [6228] = 6669,      -- Dark Iron Ambassador

    -- Razorfen Kraul
    [6168] = 6110,      -- Roogug
    [4424] = 6097,      -- Aggem Thorncurse
    [4428] = 4644,      -- Death Speaker Jargba
    [4420] = 4652,      -- Overlord Ramtusk
    [4422] = 2450,      -- Agathelos the Raging
    [4421] = 4642,      -- Charlga Razorflank
    [4425] = 4735,      -- Blind Hunter
    [4842] = 6102,      -- Earthcaller Halmgar

    -- Scarlet Monastery: Graveyard
    [3983] = 2044,      -- Interrogator Vishas
    [6490] = 5534,      -- Azshir the Sleepless
    [6488] = 5230,      -- Fallen Champion
    [6489] = 5231,      -- Ironspine
    [4543] = 11396,     -- Bloodmage Thalnos

    -- Scarlet Monastery: Library
    [3974] = 2040,      -- Houndmaster Loksey
    [6487] = 5266,      -- Arcanist Doan
}

-- Trash mobs named as the source of a trash drop: name -> creature display ID
-- (Wowhead Forever NPC pages). Used to draw their portraits on the loot row.
FDJ.TRASH_MOB_DISPLAY_IDS = {
    ["Druid of the Fang"] = 4211, -- npc 3840
    ["Skeleton"] = 9786, -- npc 250618
    ["Shrieking Banshee"] = 10728, -- npc 250620
    ["Ragged Ghoul"] = 414, -- npc 250622
    ["Skeletal Mage"] = 7550, -- npc 250624
    ["Skeletal Soldier"] = 7848, -- npc 250626
    ["Ghoul"] = 1065, -- npc 250627
    ["Plague Ghoul"] = 559, -- npc 250630
    ["Flesh Golem"] = 1693, -- npc 255109
    ["Stone Watcher"] = 7534, -- npc 250629
    ["Fallen Necromancer"] = 9785, -- npc 255964
    ["Goblin Engineer"] = 7109, -- npc 622
    ["Defias Overseer"] = 2316, -- npc 634
    ["Defias Blackguard"] = 2314, -- npc 636
    ["Defias Pirate"] = 2347, -- npc 657
    ["Defias Evoker"] = 2318, -- npc 1729
    ["Defias Squallshaper"] = 2349, -- npc 1732
    ["Defias Strip Miner"] = 2438, -- npc 4416
    ["Defias Taskmaster"] = 2440, -- npc 4417
    ["Defias Wizard"] = 2447, -- npc 4418
    -- City of Dalaran
    ["Dark Caster"] = 7555, -- npc 255072
    ["Fallen Mage"] = 9783, -- npc 255066
    ["Kirin Tor Necromancer"] = 145809, -- npc 269134
}

-- Source-verified Classic display IDs for the added dungeon bosses.
FDJ.STATIC_DISPLAY_IDS = FDJ.STATIC_DISPLAY_IDS or {}
-- Scarlet Monastery: Armory
FDJ.STATIC_DISPLAY_IDS[3975] = 2041 -- authentic Herod model, 3975
-- Scarlet Monastery: Cathedral
-- Razorfen Downs
FDJ.STATIC_DISPLAY_IDS[7355] = 7845
FDJ.STATIC_DISPLAY_IDS[7357] = 8055
FDJ.STATIC_DISPLAY_IDS[8567] = 7864
FDJ.STATIC_DISPLAY_IDS[7354] = 11382
-- Uldaman
FDJ.STATIC_DISPLAY_IDS[6907] = 5708
FDJ.STATIC_DISPLAY_IDS[6906] = 5710
FDJ.STATIC_DISPLAY_IDS[6908] = 5709
FDJ.STATIC_DISPLAY_IDS[6910] = 5945
FDJ.STATIC_DISPLAY_IDS[7228] = 6089
FDJ.STATIC_DISPLAY_IDS[7023] = 5285
FDJ.STATIC_DISPLAY_IDS[7206] = 10798
FDJ.STATIC_DISPLAY_IDS[7291] = 6059
FDJ.STATIC_DISPLAY_IDS[4854] = 11165
FDJ.STATIC_DISPLAY_IDS[2748] = 5988
-- Zul'Farrak
FDJ.STATIC_DISPLAY_IDS[8127] = 7353
FDJ.STATIC_DISPLAY_IDS[7272] = 6696
FDJ.STATIC_DISPLAY_IDS[7271] = 6434
FDJ.STATIC_DISPLAY_IDS[7796] = 6690
FDJ.STATIC_DISPLAY_IDS[7275] = 6441
FDJ.STATIC_DISPLAY_IDS[10081] = 9292
FDJ.STATIC_DISPLAY_IDS[7274] = 6440
FDJ.STATIC_DISPLAY_IDS[7604] = 6433
FDJ.STATIC_DISPLAY_IDS[7795] = 6685
FDJ.STATIC_DISPLAY_IDS[7273] = 7271
FDJ.STATIC_DISPLAY_IDS[7267] = 6439
FDJ.STATIC_DISPLAY_IDS[10082] = 9293
-- Maraudon
FDJ.STATIC_DISPLAY_IDS[13282] = 11172
FDJ.STATIC_DISPLAY_IDS[12258] = 12389
FDJ.STATIC_DISPLAY_IDS[12236] = 12334
FDJ.STATIC_DISPLAY_IDS[12237] = 9014
FDJ.STATIC_DISPLAY_IDS[12225] = 12350
FDJ.STATIC_DISPLAY_IDS[12203] = 12293
FDJ.STATIC_DISPLAY_IDS[13601] = 7125
FDJ.STATIC_DISPLAY_IDS[13596] = 13589
FDJ.STATIC_DISPLAY_IDS[12201] = 12292
-- The Temple of Atal'Hakkar
FDJ.STATIC_DISPLAY_IDS[8580] = 7873
FDJ.STATIC_DISPLAY_IDS[5708] = 4065
FDJ.STATIC_DISPLAY_IDS[8443] = 8053
FDJ.STATIC_DISPLAY_IDS[5710] = 6708
FDJ.STATIC_DISPLAY_IDS[5711] = 6709
FDJ.STATIC_DISPLAY_IDS[5721] = 7553
FDJ.STATIC_DISPLAY_IDS[5720] = 6375
FDJ.STATIC_DISPLAY_IDS[5722] = 9584
FDJ.STATIC_DISPLAY_IDS[5719] = 7975
FDJ.STATIC_DISPLAY_IDS[5709] = 7806
-- Blackrock Depths
FDJ.STATIC_DISPLAY_IDS[9025] = 5781
FDJ.STATIC_DISPLAY_IDS[9018] = 8761
FDJ.STATIC_DISPLAY_IDS[9319] = 9212
FDJ.STATIC_DISPLAY_IDS[9027] = 8760
FDJ.STATIC_DISPLAY_IDS[9028] = 7873
FDJ.STATIC_DISPLAY_IDS[9029] = 523
FDJ.STATIC_DISPLAY_IDS[9030] = 11538
FDJ.STATIC_DISPLAY_IDS[9031] = 3004
FDJ.STATIC_DISPLAY_IDS[9032] = 8271
FDJ.STATIC_DISPLAY_IDS[9024] = 8762
FDJ.STATIC_DISPLAY_IDS[9016] = 12162
FDJ.STATIC_DISPLAY_IDS[9017] = 1204
FDJ.STATIC_DISPLAY_IDS[9056] = 8704
FDJ.STATIC_DISPLAY_IDS[9041] = 9089
FDJ.STATIC_DISPLAY_IDS[9033] = 8756
FDJ.STATIC_DISPLAY_IDS[8983] = 8759
FDJ.STATIC_DISPLAY_IDS[9499] = 8652
FDJ.STATIC_DISPLAY_IDS[9502] = 8177
FDJ.STATIC_DISPLAY_IDS[9543] = 8667
FDJ.STATIC_DISPLAY_IDS[9537] = 8658
FDJ.STATIC_DISPLAY_IDS[9156] = 8329
FDJ.STATIC_DISPLAY_IDS[8923] = 8270
FDJ.STATIC_DISPLAY_IDS[9938] = 12162
FDJ.STATIC_DISPLAY_IDS[8929] = 8705
FDJ.STATIC_DISPLAY_IDS[9019] = 8807
-- Lower Blackrock Spire
FDJ.STATIC_DISPLAY_IDS[10263] = 5047
FDJ.STATIC_DISPLAY_IDS[9219] = 11574
FDJ.STATIC_DISPLAY_IDS[9196] = 11565
FDJ.STATIC_DISPLAY_IDS[9236] = 9732
FDJ.STATIC_DISPLAY_IDS[9237] = 9733
FDJ.STATIC_DISPLAY_IDS[9596] = 9668
FDJ.STATIC_DISPLAY_IDS[10596] = 9929
FDJ.STATIC_DISPLAY_IDS[10584] = 11583
FDJ.STATIC_DISPLAY_IDS[9736] = 9738
FDJ.STATIC_DISPLAY_IDS[10220] = 9567
FDJ.STATIC_DISPLAY_IDS[10268] = 9564
FDJ.STATIC_DISPLAY_IDS[9568] = 8711
FDJ.STATIC_DISPLAY_IDS[9218] = 11576
FDJ.STATIC_DISPLAY_IDS[9217] = 11578
FDJ.STATIC_DISPLAY_IDS[10376] = 9755
FDJ.STATIC_DISPLAY_IDS[9718] = 11809
-- Upper Blackrock Spire
FDJ.STATIC_DISPLAY_IDS[9816] = 2172
FDJ.STATIC_DISPLAY_IDS[10264] = 9581
FDJ.STATIC_DISPLAY_IDS[10509] = 9686
FDJ.STATIC_DISPLAY_IDS[10899] = 10222
FDJ.STATIC_DISPLAY_IDS[10339] = 9806
FDJ.STATIC_DISPLAY_IDS[10429] = 9778
FDJ.STATIC_DISPLAY_IDS[10430] = 10193
FDJ.STATIC_DISPLAY_IDS[10363] = 10115
-- Dire Maul: East
FDJ.STATIC_DISPLAY_IDS[14354] = 7552
FDJ.STATIC_DISPLAY_IDS[11490] = 11335
FDJ.STATIC_DISPLAY_IDS[13280] = 5489
FDJ.STATIC_DISPLAY_IDS[14327] = 14378
FDJ.STATIC_DISPLAY_IDS[11492] = 14416
-- Dire Maul: West
FDJ.STATIC_DISPLAY_IDS[11489] = 14383
FDJ.STATIC_DISPLAY_IDS[11488] = 11270
FDJ.STATIC_DISPLAY_IDS[11487] = 14384
FDJ.STATIC_DISPLAY_IDS[11467] = 11250
FDJ.STATIC_DISPLAY_IDS[11496] = 14173
FDJ.STATIC_DISPLAY_IDS[11486] = 11256
FDJ.STATIC_DISPLAY_IDS[14506] = 14556
-- Dire Maul: North
FDJ.STATIC_DISPLAY_IDS[14326] = 11561
FDJ.STATIC_DISPLAY_IDS[14322] = 11545
FDJ.STATIC_DISPLAY_IDS[14321] = 11561
FDJ.STATIC_DISPLAY_IDS[14323] = 11561
FDJ.STATIC_DISPLAY_IDS[14325] = 11564
FDJ.STATIC_DISPLAY_IDS[14324] = 11537
FDJ.STATIC_DISPLAY_IDS[11501] = 11583
-- Scholomance
FDJ.STATIC_DISPLAY_IDS[10506] = 7534
FDJ.STATIC_DISPLAY_IDS[10503] = 11073
FDJ.STATIC_DISPLAY_IDS[11622] = 12073
FDJ.STATIC_DISPLAY_IDS[10433] = 10248
FDJ.STATIC_DISPLAY_IDS[10432] = 2606
FDJ.STATIC_DISPLAY_IDS[10508] = 7919
FDJ.STATIC_DISPLAY_IDS[10505] = 11069
FDJ.STATIC_DISPLAY_IDS[11261] = 10901
FDJ.STATIC_DISPLAY_IDS[10901] = 11492
FDJ.STATIC_DISPLAY_IDS[10507] = 10433
FDJ.STATIC_DISPLAY_IDS[10504] = 11072
FDJ.STATIC_DISPLAY_IDS[10502] = 11835
FDJ.STATIC_DISPLAY_IDS[1853] = 11070
FDJ.STATIC_DISPLAY_IDS[14516] = 14591
-- Stratholme: Living
FDJ.STATIC_DISPLAY_IDS[10393] = 2606
FDJ.STATIC_DISPLAY_IDS[10516] = 10771
FDJ.STATIC_DISPLAY_IDS[10558] = 10482
FDJ.STATIC_DISPLAY_IDS[10808] = 571
FDJ.STATIC_DISPLAY_IDS[11032] = 10458
FDJ.STATIC_DISPLAY_IDS[10997] = 10674
FDJ.STATIC_DISPLAY_IDS[10811] = 10544
FDJ.STATIC_DISPLAY_IDS[10813] = 10691
FDJ.STATIC_DISPLAY_IDS[11143] = 10669
-- Stratholme: Undead
FDJ.STATIC_DISPLAY_IDS[10809] = 7856
FDJ.STATIC_DISPLAY_IDS[10436] = 10698
FDJ.STATIC_DISPLAY_IDS[10437] = 9793
FDJ.STATIC_DISPLAY_IDS[10438] = 10546
FDJ.STATIC_DISPLAY_IDS[10435] = 10433
FDJ.STATIC_DISPLAY_IDS[10439] = 12818
FDJ.STATIC_DISPLAY_IDS[10440] = 10729
