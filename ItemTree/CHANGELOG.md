# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.19] - 2026-10-31

### Added

- The nine tier 1 raid sets are listed under Sets.

### Changed

- Updated for the live Forever game (1.60.1.70707).

## [0.1.18] - 2026-10-30

### Added

- Items with no known source yet show where they come from on their Sources tab, marked Predicted (the Twisted Water Totem, the Silver Totem of Aquementas).
- Items players saw sold in many zones on both sides count as sold by vendors everywhere (Simple Flour).
- More creatures show on the Map tab, placed roughly (Shinyfinder Narf).

### Changed

- Updated for the live Forever game (1.60.1.70685).
- Paladin and shaman class quests are no longer hidden from the other side, now that both sides can play those classes.
- Share your finds includes what you record in the live game; only the Beta Farewell Tour is left out.
- Quests whose level Forever changed are judged by their Forever level, so their items are kept for the right levels (Fiora Longears).
- A Lesson to Learn and Could I get a Fishing Flier? name the right quest giver and next quest for each side.

### Fixed

- Quests that share a name are numbered in their chain order (The Legend of Stalvan, The Tower of Althalaxx).

## [0.1.17] - 2026-10-24

### Added

- Tooltip display settings turn each kind of ItemTree tooltip line on or off (the Keep and sell tags, quest, profession and gear lines), all on by default.
- Quest pages list the items a quest hands you under Provided items, Classic Era quests included, and the item's page names the quest that gives it (Alexston's Reply from Making Do).
- An item a quest hands you is kept while the quest is in your log (the Soul Gem from Saving Yenniku).
- Quest items you no longer need read Quest complete, Quest abandoned or Quest below your level with the quest's name, tagged Vendor or Worthless.
- Craftsman's Writ quests show their name, level, what they ask for and where to hand them in, and keep the crafted item while you hold the writ (Craftsman's Writ: Red Woolen Boots).
- Pressing the ItemTree key while you read a quest in the quest log or at a quest giver opens that quest's page.
- Setting a waypoint from ItemTree shows a short Waypoint added note at the top of the screen saying what it is for (Marshal Dughan, turn in for Wanted: Hogger).
- A trainer button beside the dice finds your class trainers in one click; press it again to close the search.
- The Map tab zooms with the mouse wheel and moves when you drag it, with Reset, + and - buttons in its corner.
- Quests started or handed in at an object, such as a wanted poster, name it under Given by and Turned in to, and the object's page lists its quests.

### Changed

- Turn ins wear the game's yellow question mark (Turned in to on a quest's page, Ends on a Quests tab); quest givers keep the exclamation mark.
- Trainers and vendors on Zephras Isle serve both factions.
- The trainer search shows where more trainers stand and which side they serve (the paladin trainers in Tirisfal Glades).
- Share your finds leaves out anything recorded during the Beta Farewell Tour, which is not in the game at launch.

### Fixed

- Tooltip lines, the game's own included, no longer shrink to smaller text after an ItemTree tooltip.
- A holiday event quest no longer counts as a use on its item's tooltip, and its Used by row is tagged Event (Ironforge Mint).

## [0.1.16] - 2026-10-21

### Changed

- Arrows and bullets sold by vendors everywhere are kept for your bow or gun from 3 levels before you can use them, not 10.
- The Equip tag reads Equip (Any spec) where it read Equip (Any).
- Long ItemTree lines in tooltips carry on under their own words rather than under the icon, and never leave one word alone on the last line; the Show nearest hover wraps too.
- Hovering a quest, creature or item in the window shows a tidier card with labelled lines and map spots in brackets, and quest givers from Classic Era now show where they stand.
- The Keep tag shows how many you need in a second part of the tag, up to 99+, when a quest, your profession's levelling or a crate keeps the item.
- Hovering the Keep buttons on an item's page says what Auto, Always, Never and Off each do, one line each.
- Tooltips list the uses that matter to you (your professions, quests you can take) one line each and fold the rest under hold Ctrl, instead of one "Used in 15 recipes, 1 quest" line.
- Supply crates read like quest needs, such as Waylaid Supplies (0 / 20 needed), and quests always show how many they need.
- A recipe reads Learn it now, or Learn it (Requires Enchanting 290), without a line naming what it makes.
- Profession tools read Tool for Alchemy with your own uses of it underneath; finished quests read 1 quest (completed).

### Fixed

- Ammo you have outgrown or cannot fire that sells for nothing, such as Sharp Arrow at level 40, reads Worthless instead of no tag.

## [0.1.15] - 2026-10-21

### Added

- The Night Watch Guard's page and both An Unfortunate End quests map every spot players have found him, and the quests say how to get his torch.
- A map spot where a player found the creature wears a green border and shows over any pin it overlaps (its hover says Confirmed; the others say Reported by players or Weak indicator).
- A Use mark setting (under Keep and Use marks) turns off the blue play mark on bag items (they wear the Keep mark instead).
- Hovering Show Changed badges on bags shows an example slot, like the other badge settings.
- A Mark size setting makes the Keep and Use marks on bag items smaller or bigger.
- Each ItemTree hotkey takes a second key beside the first.
- A one time thank you note under Help make ItemTree better after you update (its X or a click on the link closes it for good).

### Changed

- Bag badges go smaller than before (Badge size now shrinks the New in Forever mark too).
- Settings group the bag marks by kind: Forever badges, then Keep and Use marks, each with its own size slider.
- The Forever badges settings list the badge kinds first, then where they show (In your bags, In your bank).
- Creature portraits and Boss portraits moved to the Performance settings.
- Unticking every Suggest gear for box turns gear suggestions off (gear then reads like any other item, with a Gear suggestions off line).
- Closing and reopening the window brings you back to the same place (a creature page stays on its Map tab).
- After a reload or logout the window opens on the last page you viewed (on its tab); a random item shows only when Recently viewed is empty.
- The Item chain follows Classic quests too (Horn of the Red Wolf to the swift wolf horns).
- Hide other faction data also hides the other side's quests from the Item chain and from an NPC's Quests tab.
- Pet trainers mark the abilities your hunter or your pets already know (Learnt, with the rank).
- Boss loot and item pages show what the bosses of Excavation Site: Wetlands, City of Dalaran, The Hall of Thanes and Ruins of Lordaeron drop (Predicted until you loot it yourself).
- Sold by vendors everywhere goes by the price of one item, so cheap things sold in bundles count (Jagged Arrow, 10s for 200).
- The quest badges setting is now called Show New on quests and rewards.

### Fixed

- The Item chain follows Show predicted data (with it off, it leaves out predicted steps).
- ItemTree's hotkeys take Cmd on a Mac as part of a key again, as the game's own Key Bindings do.
- Picking an entry in a page's left list (a trainer's Level 40) keeps the list where you scrolled it.
- A warlock's demon grimoire is kept until your demon has learnt it (the line says what it teaches).
- A book that teaches your class a spell is kept until you have learnt it (Tome of Arcane Brilliance, the AQ tomes, the rogue disguises).
- The Discoveries list keeps its place when a new find arrives or the window is reopened.
- Show craft no longer gets stuck in two rare cases (Find recipe after switching professions, or a click over the profession book doing nothing).
- Arrows and bullets for your equipped bow, crossbow or gun are kept while they suit your level, even when sold everywhere.
- A vendor price for an item sold in bundles says how many it buys (Refreshing Spring Water reads 25c for 5).
- Vendor prices show the full price, never a reputation discount (Refreshing Spring Water 25c for 5, not 23c), and throwing weapons show the game's new price.
- Toys the game gives no toy label, such as Night Watchman's Torch, are kept as toys.
- Map pins point exactly at their spot (the tip stood a little above it).
- /itemtree show now opens creatures by name too, such as Night Watch Guard.

## [0.1.14] - 2026-10-20

### Added

- Track another profession on the Professions tab: pick a range and ItemTree keeps its items as if you had it, handy on a bank alt.
- Class trainers list the spells they teach by level, with rank and cost, and mark the ones you have learnt; pet trainers list their pet abilities.
- Show craft on each recipe opens your profession window searched to that recipe (it reads Find recipe where a step comes first); View profession opens the window, and View in ItemTree on the window opens its route.
- Many more new Forever quests, up to level 60, show who gives them, what they need and what they reward (marked Predicted).
- Toys, such as the new Adventurer's Tent, are kept.

### Changed

- Herbalism, Mining and Skinning goods are kept for their own recipes until the recipe goes grey, then read "Below your current Herbalism level" (or Mining, Skinning).
- A tracked profession keeps only its own reagents, not what another trade turns into them.
- A quest that starts from an item, such as a Craftsman's Writ, keeps what it asks for only while you hold that item or the quest.
- Quest pages show each objective's count (x60 Wool Cloth) and say Choice for a reward you pick.
- Quests that share a name say where they are and the reputation they give: "A Donation of Wool (Ironforge, Gnomeregan Exiles)".
- An item only the other faction uses says "No known uses for Alliance" (or Horde), and Hide other faction data also hides their quest rewards.
- Labels put their detail in brackets ("Learnt (Rank 3)", "Tailoring (tracking 20 to 70)"), and tooltips list a craft's ingredients with icons.
- Typing /it on its own opens the ItemTree window; /it settings opens the settings.
- The Use mark on bag slots is smaller, the size of the Keep flag.
- Professions tab: Shift and the mouse wheel scroll the route, and a small panel shows how to zoom, pan and scroll.

### Fixed

- Creatures, bosses and vendors show their portrait on cards, pages and Sources rows instead of a type icon.
- Most Classic vendors that read Vendor and a number show their name, title and faction.
- Craft all and the craft queue bring your profession window in front of ItemTree.
- Skinners who also do Leatherworking see the Leatherworking count on Light Leather again.
- Craft all says why it cannot queue on an Enchanting level.
- An item's quest count on its page matches its Used by tab.
- Class trainer pages, and the first open on slower PCs, are quicker.
- Item tooltips no longer jump in size when another addon restyles their text, and search result tooltips name the click that opens the item.
- The beta's test vendors no longer show as selling items.

## [0.1.13] - 2026-10-17

### Added

- Hide other faction data, on by default: the other faction's items, quests, trainers and vendors leave pages, counts, search and maps; with it off, each shows its side's mark.
- Many new Forever quests show who gives them, where to hand them in, what they need and what they reward, marked Predicted.
- Items new Forever quests ask for are kept for them, and Predicted quests count on item pages, tooltips and creature pages.
- ItemTree remembers the quests you take and hand in, and the Share window includes them.
- Items in your bank wear the same badges and Keep marks as your bags, on every bank tab.

### Changed

- Ctrl on any tooltip lists the quests that are not yours: other classes', the other faction's, repeatable and Naxxramas quests.
- Repeatable quests count on item pages but never keep an item.
- Naxxramas quests keep nothing until you have been inside Naxxramas.
- Bandages and other items for a profession you have, but not yet at their rank, are kept for later.
- Bag advice is clearer: a reagent bag is judged for your reagent bag slot, normal bags beat profession bags of a similar size, and a bag in your bag bar reads Equipped bag.
- A tool in a bag that cannot hold it is the spare copy, not the one kept.

### Fixed

- The first pages you open after logging in, and opening a vendor with full bags, no longer stutter.
- Vendors and trainers that read "Vendor" or "Creature" and a number show their name, zone and faction, and Show nearest finds them.
- A creature page no longer shows another creature's model while its own loads, and an NPC's portrait fills in once you have viewed it.
- Skinned and pickpocketed items list under Skinned from and Pickpocketed from, not Drops from.
- A quest no longer shows twice (The Captain's Chest), and A Thief's Reward is on the right side.
- Quest pages, reward rows and Used by agree on a quest's faction.
- Pressing Show N more shows all N rows at once.
- Jettison follows your Keep settings and gear spec as soon as you change them.

## [0.1.12] - 2026-10-14

### Added

- ItemTree shows up in ElvUI style data bars and other broker displays when you have one installed.
- Quests whose rewards changed in Forever show their Forever rewards, and the new reward items show the quest they come from.
- Trinkets with a Use effect are rated by what the Use does for your specs, and one we cannot rate says Nothing to compare instead of losing on item level.

### Changed

- A consumable you are too low level for now reads Can't use at your level.
- Stat scrolls, elixirs and food judge your class by the same table as Jettison: Strength and Agility suit warriors, paladins, hunters, rogues, shamans and druids, and Spirit suits every class.
- A bag bigger than one you wear reads Equip, and a spare bag reads Keep beside its price, useful for your bank and alts, up to your bank's bag slots; a quiver is judged against the one you wear.
- A Classic Era trainer's Teaches tab lists the recipes in the order he teaches them, with the skill each needs (Mining 65).

### Changed

- The other faction's quests no longer count as uses of your items: an Alliance character's cloth no longer lists the Horde donations.
- Quests you cannot take yet still show in the tooltip's folded list with their level.

### Fixed
- A long Drops from or Sold by list no longer hides most of its sources behind a "Show 1 more" row, and every "Show N more" now adds exactly N rows.

- Forever creatures show their portraits in an item's sources, as Classic creatures do.
- The comparison tooltip no longer calls a bag item Equipped.
- Profession tools are kept: the best Skinning Knife, Mining Pick or fishing pole for each of your professions reads Keep, a spare reads its sale price, and a tool is never compared with your weapon.
- Smoother while playing: the item data now loads in small steps after you log in, even while you move.
- The first creature or NPC page you open no longer freezes the game for a moment.
- Hovering an item one of your quests asks for no longer makes the game stutter for a moment.
- Weapons, shields and off hand books are judged for the specs that use them, so a book beside a two hander reads as an upgrade for Holy.
- A one hander that beats your worn weapon is suggested even when your spec prefers a two hander, and Holy paladins weigh shields as well as books.
- Every bandage you can use reads Use, and none ever asks you to use it now.
- The Forever copy of a Classic consumable no longer says it is a copy on its tooltip.
- Quest rewards the game has confirmed no longer read Predicted.
- A chest or other openable item with no uses opens on its Contains tab.
- White gear for a much later level is no longer kept; it reads "Common quality" and its sale price.
- Gear kept for a later level still offers the auction house when you have no price addon.
- A class trainer's page shows its map and says what it trains instead of empty item tabs.

## [0.1.11] - 2026-10-11

### Changed

- Gear your class will wear later is kept when it will be an upgrade at its level.
- A Forever appearance piece reads Use until you have collected its appearance.
- Soulbound gear with no sell price that you cannot use reads Worthless.
- A trainer's page lists what they teach under Teaches; city NPCs with nothing to drop no longer show Loot.
- More Forever profession trainers are found by the trainer search, Grungle in Riverglades among them.
- Smelting cards no longer print a points line where the window is empty.
- More trainers are known, with the zone they stand in and the rank they teach up to.
- A chest you have found no longer hides the same named chests in other zones; they are listed beside it.
- An NPC's page is titled by its name.
- Chests and other objects show what they hold under Loot; openable items show Contains.
- Show nearest knows Forever trainers and prefers one who teaches your next rank.

## [0.1.10] - 2026-10-11

### Changed

- The Professions tab is on by default; turn it off under Feature tabs.

## [0.1.9] - 2026-10-11

### Added

- Gear is weighed by its stats for every spec of your class, and an upgrade names the specs it
  helps: "Upgrade for your Chest (Holy)". Random suffix gear ("of the Bear") is weighed by the
  stats it rolled.
- Settings, Keep marks: a "Suggest gear for" box for each spec of your class, saved per character.
- An Equip tag for an upgrade you can wear now ("Upgrade for your Legs (mail over cloth)"); the
  piece you wear reads Vendor and names the better one in your bags.
- Food, drink, potions, bandages, elixirs and scrolls are judged by what they actually do, and the
  Keep line says why: "Best food you can use", "Better potion in your bags", "Too weak for your
  level", "Not for your class", "Needs a skill you lack".
- Potions, elixirs and buff food are kept by the classes that use the buff (Smoked Sagefish for a
  caster, Rage Potion for warriors and druids) until a stronger one you can use is in your bags.
- Food and drink that give more experience from kills are kept while you level.
- Bandages are judged against bandages: kept while one heals a fifth of your health or is the best
  one you carry.
- A blue Open and Use tag for things to do now: clams, loot bags and lockboxes you can open (with
  what is inside), a scroll or elixir whose buff is off, and an item that starts a quest you can
  take. Your bags mark them with a blue play sign.
- Bags get a verdict: one bigger than your smallest bag is Keep, and quivers, ammo pouches, soul
  bags and reagent bags are compared for the characters who use them.
- A Pet food tag for hunters: with a pet out, the biggest stack of food it eats reads "Food for
  your pet".
- Soulbound gear with a Use or special Equip effect you are not yet level for is kept: "Keep for
  level 36".
- Item tooltips name the profession that makes an item and the one that uses it ("Made by
  Alchemy", "Used in 1 First Aid recipe"), and count its quests as soon as you log in.
- Settings, Tooltips: "Hide irrelevant uses", on by default. Uses for professions you do not have
  fold into one "and N other uses" line; hold Ctrl (or your chosen key) to see them all, on
  Jettison's lists too.
- Search trainers with t: or trainer:, nearest first (t:hunter, t:lw), and a "Show nearest" button
  that marks the nearest trainer and sets a waypoint.
- A red gem on the Professions tab when a profession is at its cap and can be trained further.
- The maps show where you are, with an arrow pointing the way you face.
- /itemtree demo pretends a level, professions, specs, quests and items for testing; /itemtree
  demo off puts everything back.

### Changed

- Classic quests that are in WoW Forever now count towards Keep and no longer read Predicted, but
  only quests you can still do: never the other faction's, done, grey, more than ten levels away,
  holiday, Ahn'Qiraj War Effort or reputation turn in quests. Class quests keep items only for
  that class.
- A quest or your profession route keeps only as many as it needs, and the Keep line shows the
  count ("Westfall Stew (II) (9 / 3 needed)"); where both need an item the counts add up.
- A reagent your profession can still turn into gear or a consumable you use is kept up to one
  stack; one no recipe left on your route uses says "Not needed to level First Aid".
- Potions, flasks and bandages you keep read Use; elixirs, scrolls and buff food read Use while
  their buff is off and Keep while it is on.
- Food and drink with a buff can be offered for auction; alcohol goes by its price, never as food.
- Lures and devices for your professions are kept while your skill can use them, and camp items
  such as the Camp Chair are kept as camp items.
- Hunters: Survival counts Strength and melee attack power, and Intellect counts for more once you
  take Careful Aim.
- Search finds whole words first ("meat" shows Charred Wolf Meat), groups results under headings,
  and a "+N more" row shows 20 more; Forever's soulbound copies of Classic potions and food are one
  entry.
- Tooltips: the Keep, Equip, Auction and Vendor tags always come first, quest lines sit above
  "and N other uses", and "Press ... for the full tree" is always last.
- Quest marks: a green tick once you have done a quest, wherever quests are listed, updated as
  soon as you take or hand one in.
- An item's Used by tab lists a quest's rewards in their own Rewards group.
- A creature's Classic Era and Forever pages are now one page, and a player found drop shows the
  Classic Era rate beside it.
- The window reopens on the tab you closed it on, and a trainer's page from a search opens on its
  Map tab.

### Fixed

- Tooltips in the ItemTree window open at the item's icon, and the Equipped comparison opens on
  the left as it does for your bags, with no flickering divider.
- Bandages now count your First Aid; every bandage read "Needs a skill you lack".
- Grey and white gear is compared with what you wear, so a piece for an empty slot or heavier
  armour no longer reads Vendor. Rogues can use one-hand axes and druids polearms, and cosmetic
  clothing is no longer "Not for your class".
- Food for your level is kept for a few levels, a bigger healing potion no longer makes a mana
  potion "Better potion in your bags", and an item vendors sell everywhere (Rough Arrow) is no
  longer offered for auction.
- Disenchanting by clicking an item in your bags records which item it was, and gathering a herb
  or vein with its tooltip up no longer records a second spot. The Sources search finds every row.
- Lord Valthalak and Kormok show in Boss loot, Mutanus the Devourer is known in Wailing Caverns,
  and chests and veins players found show their names under Found in and Mined from.
- Reagent counts on the Professions tab update as your bags change.
- Show nearest finds a vendor at its Classic Era spots too, and never one only the other faction
  can use.
- ItemTree Data and ItemTree Professions show ItemTree's icon in the AddOn List.

## [0.1.8] - 2026-10-06

### Added

- A "Help make ItemTree better" link at the top of the window shows what you have recorded in play
  as text you can copy and paste at https://itemtree.net/, to help name Forever's items, creatures
  and quests, with a Credit my character box, off by default. Nothing is sent by the addon.
- A Total counts tick box in the window footer multiplies a recipe's counts down the tree, so
  12 Arcanite Bars show the 12 Thorium Bar and 12 Arcane Crystal they need.
- New optional Professions tab showing your profession levelling routes.
- On a zone's list, click a vendor's or creature's name to open its page.
- Search finds Forever NPCs, including the vendors you have visited.
- Sources that players have recorded in game, such as new Forever vendors, now show as real rows
  instead of guesses.
- Forever quests, trainers and stable masters that players have met in game now show with their
  names and where to find them.
- Hovering a herb, vein, fishing pool, chest or other named object records where it is, with or without the profession.
- Other addons can now ask ItemTree what it knows about an item.
- A creature's page opens on the tab that fits it, trainers get a Trains tab, and a boss links to its dungeon.
- An ingredient is now kept when another profession turns it into something your profession needs.
- Class only consumables, such as a mage's scrolls, now say which class uses them and are kept for it.
- Professions cards wear the New badge on recipes and items new in Forever.
- Item tooltips now show what to do with an item as tags: Keep, Auction or Vendor.
- An item you keep that is also worth selling shows both tags, such as Keep and Auction.
- Auction is only suggested when a stack is worth the trip for the money you carry.
- An item worth 500 gold or more on the auction house shows its Auction tag in legendary orange.
- Soulbound items are never suggested for the auction house.
- Gear that is an upgrade for you, now or within a few levels, is marked Keep, and tooltips say when gear is not an upgrade or not for your class.
- Gear you are wearing reads Keep in its tooltip.
- Consumables you could use soon are kept, such as a flask a few levels ahead.
- Enchanters see a Disenchant tag when disenchanting an item is worth more.
- Items worth disenchanting wear your bag mark in violet for enchanters.
- A new setting picks how much an auction price must beat the vendor by, or your own price formula, with an example and help.

### Changed

- Bag marks always use your own colour; the Gold, Quality and Heat colour sets are gone.
- The Keep and Auction tags wear your Keep and Valuable colours.
- The tooltip no longer counts a quest that only rewards the item.
- Gathering guides now follow this client's node skill levels, carry earlier herbs and ores while they still give points, and say when each one stops.
- Ctrl + right click opens the tree from loot roll windows and item links in chat too.
- The open key works over an item link in chat without clicking it first.
- The tooltip's Keep line now reads 'Keep' instead of 'Worth keeping'.
- The Mining guide now shows the smelting recipes beside the ore, with the skill range each one levels you through.
- Profession guides now follow this client's skill ranges instead of the Classic ones.
- Recipe cards say where a pattern comes from and when a cheaper route exists on your auction house.
- Herbs, veins and chests you gather are recorded where they really are, not along the path you walked to them.
- The tooltip no longer says when an item was first found.
- An item kept only for its price now reads Auction or Vendor instead of Keep.
- Profession recipe counts read '9 x Tailoring' instead of '9 Tailoring recipes'.
- Nested uses read shorter, with the professions' icons, and no longer list a profession via itself.
- Recipes of professions you do not have no longer mark an item to keep on their own.
- An ingredient a supply crate takes is kept while you carry the crate, and the crate shows in its tooltip.
- Nested uses lead with a simpler icon.
- ItemTree's tooltip lines are labelled 'ItemTree' on their first line.
- The tooltip no longer says 'No known uses'; the item page still does.
- Other addons can now read which quest makes an item stale, quest titles and your professions from ItemTree.
- Profession routes count a reagent across every band that still needs it.
- The item data, the Classic Era sources and the change details use much less memory.
- Searching is lighter while you type.
- Opening the window for the first time no longer stalls the game: the data loads with the login screen.
- Bag badges and the Worth keeping marks use less memory while bags are open.
- Quests in a chain show their number, such as Taming the Beast (II), and same-named quests show
  their zone.
- Quest items are marked with a ! in search results.
- Keep items worth at least is now Valuable at, and works without an auction addon using the item's vendor sell price.
- The tooltip no longer says when the data is for another game build.
- The Worth keeping tooltip lists every use once, and no longer repeats the recipe count above it.
- The item page no longer says an item disenchants into predicted results.
- The tooltip no longer says an item was newly named in this build, and a Discoveries row's
  tooltip is shorter.
- Looting, buying and quest turn-ins no longer cause a short hitch on the next tooltip.
- The window portrait shows the creature you opened.
- A quest item's Keep line counts every quest on one line, such as '2 quests (1 completed)'.
- Nested use lines name the professions short, such as 'BS via LW', after a new chain icon.
- Class only consumables read 'Class: Mage (Comprehension 1)'.
- A gathering card at one skill level reads 'Gather at 300'.

### Fixed

- A page that cannot be drawn now shows an empty page instead of breaking the window.
- The search box's hint no longer covers the first result.
- Opening a container from your bags no longer records a wrong source id.
- An ingredient with one recipe now says Keep if you have its profession, and names it if you do not.
- Quest items are no longer kept once the quest is done or abandoned, and the tooltip says why.
- Quest items are kept while any quest still needs them, including repeatable turn-ins.
- Hovering a corpse or a creature in combat no longer shows an ItemTree error.

## [0.1.7] - 2026-10-04

### Fixed

- Ctrl + right click on a creature, on its body or its nameplate, opens its page again on the
  current client build.
- Opening a creature's page in combat no longer trips a blocked action error.

## [0.1.6] - 2026-10-02

### Fixed

- Items the new beta build changed now show their new quality, stats and sell price, such as
  the dungeon quest rewards that went from blue to green.

### Changed

- More items and creatures are named, from today's play.

## [0.1.5] - 2026-10-02

### Changed

- Updated for the new beta build, 1.60.1.70170.
- Half-Pint Tavern is gone from the Boss loot tab, because the new build removed it.

## [0.1.4] - 2026-10-02

### Added

- An item worth 100 gold or more on the auction house is marked worth keeping, with a flame.
  The price is read from Auctionator, Auctioneer or TSM if you have one, and the amount is yours
  to set.
- A Keep marks section in Settings picks how worth keeping items are marked in your bags:
  thirteen styles, four colour sets, or a colour of your own.
- A zone's page lists the creatures and NPCs found there.
- Forever's own dungeons and zones, Zephras Isle among them, can be searched and opened.
- Items found in a fixed object, such as the library books, show where it stands, with a waypoint.
- A world boss's map draws its patrol path and every place it can appear.
- Each place on the Boss loot tab has a map button.

### Changed

- Worth keeping items in your bags are marked with a small green flag, valuable ones with a
  yellow flag and a flame. The old gold glow is the Classic style in Settings, Keep marks.
- The Worth keeping tooltip lists each reason on its own line with an icon, and uses that are
  not yours are grey.
- Changed badges no longer show on bags unless you turn them on.
- The tooltip no longer says when an item is unchanged or that it disenchants into predicted
  results.
- The Boss loot tab lists level 60 raids and world bosses under Endgame (60+).
- A zone map's item list shows item names first, and its scrollbar can be dragged.
- Map pins near a zone border now sit in the zone they stand in.
- More creatures and items are named, from this week's play.

### Fixed

- Your professions show on the profession headers and in Keep marks on WoW Forever again.

## [0.1.3] - 2026-09-30

### Added

- A Search everything setting, on by default: the search box also finds quests, vendors, zones,
  herbs, veins, chests and item sets, with room for each kind even when many items match, the list
  scrolls instead of growing over the search box, and Recently viewed keeps every kind of page you
  open.
- A Classic Era quest item's Used by lists the quests that ask for it, and Classic Era quest pages
  show what the quest requires and who gives and takes it back.
- Two more new bosses are named on the Boss loot tab: Lyn the Ignored and Atrexis the Grave Knight.
- An instance's map shows its entrance and its instance portal, a world boss's map shows its spawn
  points, and the Boss loot tab's place tooltip gives the entrance's coordinates.
- Left click a map pin to set a waypoint, or the Set waypoint button on a creature's page.

### Changed

- The record ItemTree keeps of what you saw drop and buy takes less room and has a size limit,
  letting go of what you have not seen for longest first.

### Fixed

- When the ItemTree Data folder does not load, chat says why once and the window opens on the
  steps to fix it, with a button that opens the AddOns list.
- ItemTree no longer says its data is out of date on a new client build with the same game tables.

## [0.1.2] - 2026-09-28

### Added

- A Boss loot tab: dungeons, raids and world bosses by level, each boss with its portrait, model
  and loot, the Classic Era drop chance, and what you have seen drop marked Verified.
- Pages for creatures, vendors, zones, herbs, veins and quests, with models, maps, coordinates,
  prices and the quests an NPC starts and ends. Ctrl + right click on a creature opens its page.
- Keep marks: bag items you still need glow gold, and their tooltip says which recipes and quests
  need them. Each item page has a Worth keeping switch: Auto, Always, Never or Off.
- Guessed sources: where nothing real is known, an item's Sources can show a likely source marked
  Guess. Turn off Show guessed sources to hide them.
- Classic items WoW Forever has not released yet show their Classic Era details. Turn off "Show
  Classic Era details for items not yet found" to hide them.
- Quests new in WoW Forever wear the New badge and a blue wash, and new rewards are marked.
- Bag badges in Bagnon, Combuctor, AdiBags, ArkInventory, Baganator, ElvUI and BetterBags, and
  item search by id: type `c:` and the id, such as `c:2589`.

### Changed

- ItemTree uses much less memory: the item data is a second folder, ItemTree Data, in the same
  download, and loads when you first open the window.
- Settings are regrouped into Badges, Tooltips, Bags, Keys and clicks, Minimap, Feature tabs and
  Performance, with plainer tooltips and an example of each setting on hover.
- The Tree tab is now Item tree, Chain is an item's first view tab, the Discoveries tab is off by
  default, and ItemTree has a new icon and badges in WoW Forever's colours.

### Removed

- The Guides tick box in the footer and the Guide lines setting.

### Fixed

- Many smaller fixes, among them: the window closes in combat, right clicking a bag item no longer
  risks a blocked action popup, and Ctrl + right click works anywhere on the target frame.

## [0.1.1] - 2026-09-26

### Changed

- The summary panel is now called the fixed position tooltip, in the settings panel, in chat and
  on the label above it while it is unlocked, and its settings section is Fixed position tooltip
  instead of Edit Mode. It is a tooltip that stays in one place on the screen and shows the item
  under your cursor. Off by default. Its tick box tooltip now says what it is and how to move it:
  tick Unlock to move (or type `/itemtree hud unlock`) and drag it.
- The Season of Discovery badge is brighter and no longer pulses. It now uses its own purple medallion, which matches the purple of the tooltip text.
- The data now names 4,341 items first found on the beta realm, up from 769.
- The count on the Discoveries tab's gem is bold, with a shadow under it, so it is easier to read.
- The New and Changed badges on bag and bank slots are half the size they were. Two new settings
  under Integration change them: `Bag badge size` scales them from 0.3x to 1.5x, and
  `Bag badge corner` puts them in any corner of the slot. A preview slot under the two shows the
  result as you change them.

### Added

- The Discoveries tab has four tick boxes on its tab row, right of the search box, one per kind of item: New, SoD (Season of Discovery), Changed and Unchanged. New and Season of Discovery are on by default and the other two off, so the tab opens on new items. With all four off the list says so and has a button to reset them to the default.
- Discoveries: "On your realm" now means the realm you are playing on. Items noted on another
  realm you play on show as "Other realms" under All.

### Fixed

- Hovering the Changed badge on the fixed position tooltip now lists what changed, old to new,
  as it does in the window.

<!-- Provisional date. On tag day, set the real date and check that this heading matches the tag
with the leading v removed, or the release job fails. -->
## [0.1.0] - 2026-09-26

The first release of ItemTree, for the WoW Forever client.

### What it does

Open any item and see the whole tree behind it: what makes it, what it makes, who drops it, who
sells it and what it disenchants into.

- Four views: Used by, Sources, Requires and Disenchants into.
- New and Changed flags mark what Forever has added or altered against the Classic Era 1.15.9
  baseline.
- Items that came from Season of Discovery count as New and wear the New flag in purple.
- Items first found on the beta realm ship with their names and stats, and say the date they were
  found. Untick "Show items found on the beta" in the settings to hide them until your realm
  finds them.
- The Discoveries tab shows a count of unread finds on its tab and marks each unread row NEW until
  you leave the tab.
- The Discoveries tab hides items unchanged since Classic Era by default; a tick box shows them.
- Creatures can be searched too. A creature page lists what it drops and where it is found, from Classic Era data marked Predicted.

### No spoilers

- An item Forever has not revealed yet is drawn as a neutral placeholder, never with its Classic
  Era name.
- Once your realm finds it, its facts appear and it lands in the Discoveries tab.

### What it cannot know

- Drops, vendors and quest rewards live on the server, so no addon can read them directly.
- Historical Classic Era sources ship as Predicted rows. Forever has retuned loot, so treat them
  as a guide. Untick "Show predicted data" in the settings to hide them.

### Getting started

- Ctrl and right click an item to open its tree, or set a key under Key Bindings, ItemTree.
- Control-click an item in ItemTree to try it on in the Dressing Room. Shift-click links it in
  chat. These follow the game's own modifier settings.
- `/itemtree` opens the settings and `/itemtree help` lists the other commands.
- `/itemtree report` produces a block of text to paste into a bug report. It holds no character,
  realm or account data.

### Known limits

- English only.

### Polite by design

- No bulk item queries, no network access, nothing sent anywhere.

### Licence

ItemTree is all rights reserved with a warranty disclaimer: you may install, run, read and modify
your own copy freely, but please do not reupload it. `Data/generated/EraSources.lua` alone is
GPL-3.0, with the full text in `LICENSES/GPL-3.0.txt` and its source at
https://github.com/Rockjaw-Bonesnapper-Co/itemtree-era-sources.
