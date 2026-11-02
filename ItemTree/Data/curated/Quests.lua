-- Hand maintained quest turn ins, loaded after the generated modules. Everything here carries
-- the "curated" confidence tier and shows the Community note badge.
--
-- A build's client tables carry recipes but say nothing about what a quest asks for or hands
-- back: that lives on the server. The one quest fact a build does state is the quest an item
-- starts (item.sq), which is where the STARTS_QUEST edge comes from. This table is the rest,
-- for the well known Classic Era chains players come looking for. Core/Quests.lua reads it.
--
-- Format:
--   ItemTree.CuratedQuests = {
--     [questId] = {
--       name = "Quest name",              -- as the client names it
--       requires = { { itemId, count } }, -- every item the turn in consumes, all of them needed
--       rewards = { itemId, ... },        -- what it always hands back
--       choice = { itemId, ... },         -- a choice of rewards, one of which is taken
--       startedBy = itemId,               -- the item that starts it, mirror of item.sq
--       zone = "Silithus",                -- where the turn in is, shown beside a quest row
--       note = "One line",                -- anything a player needs to know
--     },
--   }
--
-- Every field but name is optional. A count is a positive whole number and is written out even
-- when it is 1. An item a quest hands you to carry ("provided") is not a requirement: it is the
-- quest's own item, so it is left out, and startedBy carries it where it starts the quest.
--
-- Rules for anything added here:
--   * Classic Era facts, hand checked as Data/curated/README.md says. Facts only, never wording, and
--     never anything lifted from Questie, All The Things or another addon's database.
--   * Every item id must exist in the shipped data; tests/spec/quests_spec.lua fails otherwise.
--   * A quest nobody can verify is left out. A small correct table beats a large doubtful one.
local _, ItemTree = ...

ItemTree.CuratedQuests = {
  -- Thunderfury, Blessed Blade of the Windseeker. Either half of the bindings lets Highlord
  -- Demitrian hand over the Vessel of Rebirth, and the chain ends in Silithus.
  [7785] = {
    name = "Examine the Vessel",
    startedBy = 19016, -- Vessel of Rebirth
    zone = "Silithus",
    note = "Demitrian hands over the vessel to anyone carrying either half of the bindings.",
  },
  [7786] = {
    name = "Thunderaan the Windseeker",
    requires = {
      { 17771, 10 }, -- Elementium Bar (the wiki calls it Enchanted Elementium Bar)
      { 19017, 1 }, -- Essence of the Firelord
      { 18563, 1 }, -- Bindings of the Windseeker, left half
      { 18564, 1 }, -- Bindings of the Windseeker, right half
    },
    zone = "Silithus",
    note = "Handing this in summons Prince Thunderaan, a 40 player outdoor fight.",
  },
  [7787] = {
    name = "Rise, Thunderfury!",
    startedBy = 19018, -- Dormant Wind Kissed Blade
    rewards = { 19019 }, -- Thunderfury, Blessed Blade of the Windseeker
    zone = "Silithus",
  },

  -- Benediction and Anathema. The quest hands over the splinter; the staff itself is an item
  -- combine rather than a turn in, so it is not a quest edge.
  [7622] = {
    name = "The Balance of Light and Shadow",
    rewards = { 18659 }, -- Splinter of Nordrassil
    zone = "Eastern Plaguelands",
    note = "Needs both eyes carried to take. The splinter and the two eyes combine into Benediction.",
  },

  -- Rhok'delar and Lok'delar. The bow is the stave and the enchanted string combined, and the
  -- quiver is the lamina quest's reward.
  [7632] = {
    name = "The Ancient Leaf",
    startedBy = 18703, -- Ancient Petrified Leaf
    zone = "Felwood",
  },
  [7636] = {
    name = "Stave of the Ancients",
    requires = {
      { 18952, 1 }, -- Simone's Head
      { 18953, 1 }, -- Klinfran's Head
      { 18954, 1 }, -- Solenor's Head
      { 18955, 1 }, -- Artorius's Head
    },
    rewards = { 18707 }, -- Ancient Rune Etched Stave
    zone = "Felwood",
    note = "The four demons must be fought alone, with no pet and no raid.",
  },
  [7635] = {
    name = "A Proper String",
    requires = { { 18705, 1 } }, -- Mature Black Dragon Sinew
    rewards = { 18724 }, -- Enchanted Black Dragon Sinew
    zone = "Felwood",
    note = "The stave and the string combine into Rhok'delar, Longbow of the Ancient Keepers.",
  },
  [7634] = {
    name = "Ancient Sinew Wrapped Lamina",
    requires = { { 18704, 1 } }, -- Mature Blue Dragon Sinew
    rewards = { 18714 }, -- Ancient Sinew Wrapped Lamina
    zone = "Feralas",
  },

  -- Atiesh, Greatstaff of the Guardian. Forty splinters combine into the frame, and the last
  -- quest is four quests, one per class, each handing back that class's staff.
  [9250] = {
    name = "Frame of Atiesh",
    startedBy = 22727, -- Frame of Atiesh
    zone = "Tanaris",
    note = "The frame is 40 Splinters of Atiesh combined.",
  },
  [9251] = {
    name = "Atiesh, the Befouled Greatstaff",
    requires = {
      { 22733, 1 }, -- Staff Head of Atiesh
      { 22734, 1 }, -- Base of Atiesh
    },
    zone = "Tanaris",
  },
  [9269] = {
    name = "Atiesh, Greatstaff of the Guardian",
    rewards = { 22632 }, -- Atiesh, Greatstaff of the Guardian (druid)
    zone = "Tanaris",
    note = "The druid version of the last quest, handed back at the Caverns of Time.",
  },
  [9270] = {
    name = "Atiesh, Greatstaff of the Guardian",
    rewards = { 22589 }, -- Atiesh, Greatstaff of the Guardian (mage)
    zone = "Tanaris",
    note = "The mage version of the last quest, handed back at the Caverns of Time.",
  },
  [9257] = {
    name = "Atiesh, Greatstaff of the Guardian",
    rewards = { 22631 }, -- Atiesh, Greatstaff of the Guardian (priest)
    zone = "Tanaris",
    note = "The priest version of the last quest, handed back at the Caverns of Time.",
  },
  [9271] = {
    name = "Atiesh, Greatstaff of the Guardian",
    rewards = { 22630 }, -- Atiesh, Greatstaff of the Guardian (warlock)
    zone = "Tanaris",
    note = "The warlock version of the last quest, handed back at the Caverns of Time.",
  },

  -- The Dire Maul librams. Lorekeeper Lydros turns a libram and its materials into an arcanum.
  [7484] = {
    name = "Libram of Focus",
    requires = {
      { 18333, 1 }, -- Libram of Focus
      { 18335, 1 }, -- Pristine Black Diamond
      { 14344, 4 }, -- Large Brilliant Shard
      { 12753, 2 }, -- Skin of Shadow
    },
    rewards = { 18330 }, -- Arcanum of Focus
    zone = "Dire Maul",
  },
  [7485] = {
    name = "Libram of Protection",
    requires = {
      { 18334, 1 }, -- Libram of Protection
      { 18335, 1 }, -- Pristine Black Diamond
      { 14344, 2 }, -- Large Brilliant Shard
      { 12735, 1 }, -- Frayed Abomination Stitching
    },
    rewards = { 18331 }, -- Arcanum of Protection
    zone = "Dire Maul",
  },
  [7483] = {
    name = "Libram of Rapidity",
    requires = {
      { 18332, 1 }, -- Libram of Rapidity
      { 18335, 1 }, -- Pristine Black Diamond
      { 14344, 2 }, -- Large Brilliant Shard
      { 12938, 2 }, -- Blood of Heroes
    },
    rewards = { 18329 }, -- Arcanum of Rapidity
    zone = "Dire Maul",
  },

  -- Lower Blackrock Spire. The three gemstones and the unadorned seal go to Vaelan.
  [4742] = {
    name = "Seal of Ascension",
    requires = {
      { 12219, 1 }, -- Unadorned Seal of Ascension
      { 12335, 1 }, -- Gemstone of Smolderthorn
      { 12336, 1 }, -- Gemstone of Spirestone
      { 12337, 1 }, -- Gemstone of Bloodaxe
    },
    zone = "Lower Blackrock Spire",
    note = "The follow up, which forges the seal at Emberstrife, hands back an item this build's data does not carry.",
  },

  -- The Drakefire Amulet, which opens Onyxia's Lair. One quest per faction, same turn in.
  [6502] = {
    name = "Drakefire Amulet",
    requires = { { 16663, 1 } }, -- Blood of the Black Dragon Champion
    rewards = { 16309 }, -- Drakefire Amulet
    zone = "Winterspring",
    note = "The Alliance side of the Onyxia's Lair attunement.",
  },
  [6602] = {
    name = "Blood of the Black Dragon Champion",
    requires = { { 16663, 1 } }, -- Blood of the Black Dragon Champion
    rewards = { 16309 }, -- Drakefire Amulet
    zone = "Desolace",
    note = "The Horde side of the Onyxia's Lair attunement.",
  },

  -- The Mithril Order. Six blacksmithing turn ins, three of bars and three of crafted armour.
  [2761] = {
    name = "Smelt On, Smelt Off",
    requires = {
      { 3860, 40 }, -- Mithril Bar
      { 3575, 40 }, -- Iron Bar
    },
    rewards = { 7983 }, -- Plans: Ornate Mithril Pants
    zone = "Stranglethorn Vale",
  },
  [2762] = {
    name = "The Great Silver Deceiver",
    requires = {
      { 3860, 40 }, -- Mithril Bar
      { 6037, 5 }, -- Truesilver Bar
    },
    rewards = { 7984 }, -- Plans: Ornate Mithril Gloves
    zone = "Stranglethorn Vale",
  },
  [2763] = {
    name = "The Art of the Imbue",
    requires = {
      { 3860, 40 }, -- Mithril Bar
      { 3864, 4 }, -- Citrine
    },
    rewards = { 7985 }, -- Plans: Ornate Mithril Shoulders
    zone = "Stranglethorn Vale",
  },
  [2771] = {
    name = "A Good Head On Your Shoulders",
    requires = {
      { 7928, 1 }, -- Ornate Mithril Shoulders
      { 7931, 2 }, -- Mithril Coif
    },
    zone = "Tanaris",
    note = "Teaches the Ornate Mithril Helm plans rather than handing back an item.",
  },
  [2772] = {
    name = "The World At Your Feet",
    requires = {
      { 7926, 1 }, -- Ornate Mithril Pants
      { 7933, 2 }, -- Heavy Mithril Boots
    },
    zone = "Tanaris",
    note = "Teaches the Ornate Mithril Boots plans rather than handing back an item.",
  },
  [2773] = {
    name = "The Mithril Kid",
    requires = {
      { 7927, 1 }, -- Ornate Mithril Gloves
      { 7930, 2 }, -- Heavy Mithril Breastplate
    },
    zone = "Tanaris",
    note = "Teaches the Ornate Mithril Breastplate plans rather than handing back an item.",
  },

  -- Artisan fishing and artisan cooking, both of which eat what a player has gathered or cooked.
  [6607] = {
    name = "Nat Pagle, Angler Extreme",
    requires = {
      { 16967, 1 }, -- Feralas Ahi
      { 16968, 1 }, -- Sar'theris Striker
      { 16969, 1 }, -- Savage Coast Blue Sailfin
      { 16970, 1 }, -- Misty Reed Mahi Mahi
    },
    zone = "Dustwallow Marsh",
    note = "Teaches Artisan Fishing on Classic Era. The fishing pole reward came later.",
  },
  [6610] = {
    name = "Clamlette Surprise",
    requires = {
      { 12207, 10 }, -- Giant Egg
      { 7974, 10 }, -- Zesty Clam Meat
      { 3927, 20 }, -- Fine Aged Cheddar
    },
    zone = "Tanaris",
    note = "Teaches the Clamlette Magnifique recipe rather than handing back an item.",
  },
}
