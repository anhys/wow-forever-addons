-- Hand maintained data loaded after the generated modules. Everything here carries the
-- "curated" confidence tier and shows the Community note badge.
--
-- notes[itemId] = { "one line of text", ... }
-- raid[itemId]  = "Molten Core"  (raid relevance label)
-- corrections[kind][id] = { field = value } applied over generated data at runtime
-- favour        Merchant's Favor vendors, offers and crates (brief M3). The block at the foot is
--               written by ItemTree-Data (itemtree_data/curated.py) from its hand kept
--               curated/favour_vendors.json; edit that file, never the block.
local _, ItemTree = ...

ItemTree.Curated = {
  notes = {},
  raid = {},
  corrections = { items = {}, recipes = {} },
}

-- BEGIN favour. Written by itemtree-data (itemtree_data/curated.py) from
-- ItemTree-Data curated/favour_vendors.json, checked against build 1.60.1.70009.
-- Edit the JSON and write it again; never edit this block by hand. Every row is a
-- community fact with its provenance and sources, read by Core/Sources.lua Favour.
ItemTree.Curated = ItemTree.Curated or {}
ItemTree.Curated.favour = {
  build = "1.60.1.70009",
  crates = {
    items = {
      248549,
      248682,
      248683,
      248684,
      248685,
      248686,
      248687,
      248688,
      248689,
      248690,
      248691,
      248692,
      248693,
      248694,
      248695,
      248696,
      248697,
      248698,
      248699,
      248702,
      248703,
      248704,
      248705,
      248706,
      248707,
      248708,
      248709,
      248710,
      248711,
      248712,
      248713,
    },
    level = 10,
    note = "from ordinary creatures from level 10, turned in to a Supply Officer for Merchant's Favor",
    provenance = "community",
    sources = {
      {
        date = "2026-09-23",
      },
      {
        date = "2026-09-20",
      },
    },
    vendors = {
      "aca-supply",
      "dsl-supply",
    },
  },
  currency = {
    id = 3402,
    name = "Merchant's Favor",
    note = "Waylaid Crates from world mobs, level 10 and up, turned in to your Supply Officer",
    provenance = "community",
    sources = {
      {
        date = "2026-09-23",
      },
      {
        date = "2026-09-20",
      },
    },
  },
  offers = {
    {
      amount = 30,
      currency = 3402,
      iecId = 11844,
      item = 251364,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-blacksmith",
      },
    },
    {
      amount = 30,
      currency = 3402,
      iecId = 11844,
      item = 251369,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-blacksmith",
      },
    },
    {
      amount = 200,
      copper = 50000,
      currency = 3402,
      iecId = 11041,
      item = 262764,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "dsl-supply",
      },
    },
    {
      amount = 200,
      copper = 50000,
      currency = 3402,
      iecId = 11041,
      item = 262765,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-supply",
      },
    },
    {
      amount = 6000,
      currency = 3402,
      iecId = 11042,
      item = 262766,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1200,
      currency = 3402,
      iecId = 11517,
      item = 270887,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1200,
      currency = 3402,
      iecId = 11517,
      item = 270888,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271621,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271622,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271624,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271625,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271626,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1000,
      currency = 3402,
      iecId = 11522,
      item = 271627,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
    {
      amount = 1500,
      currency = 3402,
      iecId = 11879,
      item = 284664,
      provenance = "community",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      vendors = {
        "aca-camp",
        "dsl-camp",
      },
    },
  },
  vendors = {
    {
      area = "Three Corners",
      faction = "Alliance",
      id = 1,
      key = "aca-supply",
      name = "Tamelyn Aldridge",
      provenance = "community",
      role = "Supply Officer",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-14",
        },
      },
      uiMap = 1433,
      x = 10.4,
      y = 71.4,
      zone = "Redridge Mountains",
    },
    {
      area = "Three Corners",
      faction = "Alliance",
      id = 2,
      key = "aca-blacksmith",
      name = "Stondry Darkhammer",
      npc = 256730,
      provenance = "community",
      role = "Blacksmithing",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-27",
        },
      },
      uiMap = 1433,
      x = 10.2,
      y = 74.2,
      zone = "Redridge Mountains",
    },
    {
      area = "west of the Crossroads",
      faction = "Horde",
      id = 3,
      key = "dsl-supply",
      label = "Supply Officer (west of the Crossroads)",
      provenance = "community",
      role = "Supply Officer",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      uiMap = 1413,
      x = 49.6,
      y = 29.5,
      zone = "The Barrens",
    },
    {
      area = "Three Corners",
      faction = "Alliance",
      id = 4,
      key = "aca-camp",
      label = "Merchant's Favor vendors (Three Corners)",
      provenance = "community",
      role = "Merchant's Favor vendors",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      uiMap = 1433,
      x = 10.4,
      y = 72.4,
      zone = "Redridge Mountains",
    },
    {
      area = "west of the Crossroads",
      faction = "Horde",
      id = 5,
      key = "dsl-camp",
      label = "Merchant's Favor vendors (west of the Crossroads)",
      provenance = "community",
      role = "Merchant's Favor vendors",
      sources = {
        {
          date = "2026-09-26",
        },
        {
          date = "2026-09-23",
        },
      },
      uiMap = 1413,
      x = 49.6,
      y = 29.5,
      zone = "The Barrens",
    },
  },
}
-- END favour
