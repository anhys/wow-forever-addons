-- The profession tools list: items a profession needs to have in the bags, by the skill line
-- each one serves. Plain data, nothing else. Hand maintained, loaded after the generated modules.
--
-- What this file is: a list of item ids, each one a tool a profession cannot work without (a
-- Skinning Knife to skin, a Mining Pick to mine, a Blacksmith Hammer at the anvil, a Runed rod to
-- enchant, a fishing pole to fish). The client files most of them as weapons of the Miscellaneous
-- subclass or as trade goods, so compared with the worn weapon they look outclassed and a vendor
-- pays almost nothing for them: without this list they would read as weapons that are no upgrade.
--
-- How it is read: ItemTree.CuratedTools[itemId] is the profession skill line id the tool serves
-- (the client's own numbers: 164 Blacksmithing, 171 Alchemy, 165 Leatherworking, 185 Cooking, 186
-- Mining, 202 Engineering, 333 Enchanting, 356 Fishing, 393 Skinning), or a list of them for a
-- tool more than one profession uses. Core/Keep.lua reads it (Keep.ToolSkills): the best tool the
-- player carries for each of their professions is kept ("Skinning tool"), every other copy reads
-- its ordinary sale verdict ("Spare Skinning tool"), and a tool for a profession the player lacks
-- is worth what a vendor pays, with the line "Tool for Mining". A tool is never compared with the
-- worn weapon. A fishing pole not on the list still counts as a Fishing tool by its weapon
-- subclass.
--
-- One shared list (brief K31): Jettison ships the same ids and skill lines in its Data/Tools.lua,
-- and tests/spec/keep_tools_spec.lua fails when the two differ (where the Jettison checkout sits
-- beside this one). Change both together.
--
-- One id per line with the item's name in a comment. Nothing here is code, a packed string or a
-- call. Every id was checked by name against the compiled item tables (build 1.60.1.70170) and,
-- where the build states one, its tool category (ToolItems) and the recipes that ask for it.

local _, ItemTree = ...

local BLACKSMITHING = 164
local LEATHERWORKING = 165
local ALCHEMY = 171
local COOKING = 185
local MINING = 186
local ENGINEERING = 202
local ENCHANTING = 333
local FISHING = 356
local SKINNING = 393

ItemTree.CuratedTools = {
  -- Skinning.
  [7005] = SKINNING, -- Skinning Knife
  [269716] = SKINNING, -- Keen Skinning Knife

  -- Mining.
  [2901] = MINING, -- Mining Pick
  [6206] = MINING, -- Rock Chipper
  [259229] = MINING, -- Vindael's Spectral Pickaxe

  -- Blacksmithing (the hammer is also asked for by engineering recipes).
  [5956] = { BLACKSMITHING, ENGINEERING }, -- Blacksmith Hammer
  [281665] = { BLACKSMITHING, ENGINEERING }, -- Twilight Forgehammer
  [285280] = { BLACKSMITHING, ENGINEERING }, -- Mithril Blacksmith Hammer
  [285281] = { BLACKSMITHING, ENGINEERING }, -- Arcanite Blacksmith Hammer

  -- Engineering.
  [6219] = ENGINEERING, -- Arclight Spanner
  [10498] = ENGINEERING, -- Gyromatic Micro-Adjustor
  [260811] = { ENGINEERING, BLACKSMITHING, MINING, SKINNING }, -- Gnomish Army Knife

  -- Enchanting.
  [6218] = ENCHANTING, -- Runed Copper Rod
  [6339] = ENCHANTING, -- Runed Silver Rod
  [11130] = ENCHANTING, -- Runed Golden Rod
  [11145] = ENCHANTING, -- Runed Truesilver Rod
  [16207] = ENCHANTING, -- Runed Arcanite Rod

  -- Alchemy.
  [9149] = ALCHEMY, -- Philosopher's Stone
  [13503] = ALCHEMY, -- Alchemist's Stone

  -- Leatherworking.
  [15846] = LEATHERWORKING, -- Salt Shaker

  -- Cooking.
  [4471] = COOKING, -- Flint and Tinder

  -- Fishing.
  [6256] = FISHING, -- Fishing Pole
  [6365] = FISHING, -- Strong Fishing Pole
  [6366] = FISHING, -- Darkwood Fishing Pole
  [6367] = FISHING, -- Big Iron Fishing Pole
  [12225] = FISHING, -- Blump Family Fishing Pole
  [19022] = FISHING, -- Nat Pagle's Extreme Angler FC-5000
  [19970] = FISHING, -- Arcanite Fishing Pole
}
