-- Logical asset keys to in-client texture paths, atlas names or file data ids.
-- Derived from design/tokens/assets.css and components/core/GameAsset.jsx. Every texture
-- the addon draws goes through Assets.Apply so UI code never knows the path, and the
-- browser harness resolves the same table to local PNGs. No Blizzard art is bundled.
local _, ItemTree = ...

local Assets = {}
ItemTree.Assets = Assets

-- kind: "texture" (Interface path), "atlas" (atlas member name), "addon" (art shipped
-- under Interface\AddOns\ItemTree\Art, see Art/README.md), "fdid" (file data id).
-- slice: nine slice edge size the addon passes to NineSliceUtil, mirrored by the harness
-- as CSS border-image slice.
Assets.table = {
  FRAME_BORDER = { kind = "texture", path = "Interface\\DialogFrame\\UI-DialogBox-Border", slice = 16 },
  FRAME_BACKGROUND = { kind = "texture", path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true },
  TOOLTIP_BORDER = { kind = "texture", path = "Interface\\Tooltips\\UI-Tooltip-Border", slice = 16 },
  TOOLTIP_BACKGROUND = { kind = "texture", path = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true },
  INPUT_BORDER = { kind = "texture", path = "Interface\\Common\\Common-Input-Border", slice = 8 },
  -- The three slices InputBoxTemplate itself draws Common-Input-Border in, read off
  -- SharedUIPanelTemplates.xml on both branches of the wow-ui-source mirror: an 8px left cap,
  -- an 8px right cap and the middle stretched between them, all cropped to the top 0.625 of the
  -- file. The window puts the same bevelled corner border on the square title row buttons so
  -- they read as the same control as the search box beside them.
  INPUT_BORDER_LEFT = {
    kind = "texture",
    path = "Interface\\Common\\Common-Input-Border",
    coords = { 0, 0.0625, 0, 0.625 },
  },
  INPUT_BORDER_MIDDLE = {
    kind = "texture",
    path = "Interface\\Common\\Common-Input-Border",
    coords = { 0.0625, 0.9375, 0, 0.625 },
  },
  INPUT_BORDER_RIGHT = {
    kind = "texture",
    path = "Interface\\Common\\Common-Input-Border",
    coords = { 0.9375, 1.0, 0, 0.625 },
  },
  BUTTON_UP = { kind = "texture", path = "Interface\\Buttons\\UI-Panel-Button-Up", coords = { 0, 0.625, 0, 0.6875 } },
  BUTTON_DOWN = {
    kind = "texture",
    path = "Interface\\Buttons\\UI-Panel-Button-Down",
    coords = { 0, 0.625, 0, 0.6875 },
  },
  BUTTON_HIGHLIGHT = {
    kind = "texture",
    path = "Interface\\Buttons\\UI-Panel-Button-Highlight",
    coords = { 0, 0.625, 0, 0.6875 },
  },
  BUTTON_DISABLED = {
    kind = "texture",
    path = "Interface\\Buttons\\UI-Panel-Button-Disabled",
    coords = { 0, 0.625, 0, 0.6875 },
  },
  BUTTON_CLOSE = { kind = "texture", path = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" },
  CHECKBOX_UP = { kind = "texture", path = "Interface\\Buttons\\UI-CheckBox-Up" },
  CHECKBOX_CHECK = { kind = "texture", path = "Interface\\Buttons\\UI-CheckBox-Check" },
  SCROLLBAR_KNOB = { kind = "texture", path = "Interface\\Buttons\\UI-ScrollBar-Knob" },
  SCROLLBAR_UP = { kind = "texture", path = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up" },
  SCROLLBAR_DOWN = { kind = "texture", path = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up" },
  PLUS = { kind = "texture", path = "Interface\\Buttons\\UI-PlusButton-Up" },
  MINUS = { kind = "texture", path = "Interface\\Buttons\\UI-MinusButton-Up" },
  SLOT_FRAME = { kind = "texture", path = "Interface\\Buttons\\UI-Quickslot2" },
  -- The frame the client's own item button rings an icon with (ItemButtonTemplate's IconBorder,
  -- which SetItemButtonQuality tints). The art is white so a caller tints it to the quality it
  -- wants, and it sits at exactly the icon's rect rather than around it. fileDataID 651080 on
  -- both target builds.
  ICON_FRAME_WHITE = { kind = "texture", path = "Interface\\Common\\WhiteIconFrame" },
  SLOT_EMPTY = { kind = "texture", path = "Interface\\Buttons\\UI-EmptySlot" },
  COIN_GOLD = { kind = "texture", path = "Interface\\MoneyFrame\\UI-GoldIcon" },
  COIN_SILVER = { kind = "texture", path = "Interface\\MoneyFrame\\UI-SilverIcon" },
  COIN_COPPER = { kind = "texture", path = "Interface\\MoneyFrame\\UI-CopperIcon" },
  COIN_GENERIC = { kind = "texture", path = "Interface\\Buttons\\UI-GroupLoot-Coin-Up" },
  FILL_WHITE8X8 = { kind = "texture", path = "Interface\\Buttons\\WHITE8X8" },
  -- The notification bubble over a top tab's corner (UI/Frame.lua). The Communities button's own
  -- red disc, an atlas member 38 by 38 in UiTextureAtlasMember on 1.60.1.69913 and 1.60.1.70009,
  -- and behind it the plain red indicator dot, fileDataID 518450 in the same builds' manifest.
  BUBBLE_NOTIFICATION = { kind = "atlas", name = "communities-icon-notification" },
  BUBBLE_INDICATOR = { kind = "texture", path = "Interface\\COMMON\\Indicator-Red" },
  -- The item info column's frame (brief E78, UI/InfoPanel.lua): the eight pieces of the client's
  -- own "Dialog" nine slice layout, read off NineSliceLayouts.lua (Blizzard_SharedXML/Mainline,
  -- wow-ui-source branch forever, the Dialog entry at line 157). The column asks NineSliceUtil for
  -- the layout by name first and only places these by hand on a client without the util. Each
  -- element is in UiTextureAtlasElement on 1.60.1.70009, drawn from the gold Camelot sheets
  -- (ui-frame-diamondmetal-*-c60-2x, 128 by 128 texels shown at 64 by 64). The edges tile: "_" along
  -- the width, "!" down the height, which is the client's own naming.
  INFO_FRAME_CORNER_TL = { kind = "atlas", name = "UI-Frame-DiamondMetal-CornerTopLeft" },
  INFO_FRAME_CORNER_TR = { kind = "atlas", name = "UI-Frame-DiamondMetal-CornerTopRight" },
  INFO_FRAME_CORNER_BL = { kind = "atlas", name = "UI-Frame-DiamondMetal-CornerBottomLeft" },
  INFO_FRAME_CORNER_BR = { kind = "atlas", name = "UI-Frame-DiamondMetal-CornerBottomRight" },
  INFO_FRAME_EDGE_TOP = { kind = "atlas", name = "_UI-Frame-DiamondMetal-EdgeTop" },
  INFO_FRAME_EDGE_BOTTOM = { kind = "atlas", name = "_UI-Frame-DiamondMetal-EdgeBottom" },
  INFO_FRAME_EDGE_LEFT = { kind = "atlas", name = "!UI-Frame-DiamondMetal-EdgeLeft" },
  INFO_FRAME_EDGE_RIGHT = { kind = "atlas", name = "!UI-Frame-DiamondMetal-EdgeRight" },
  ICON_QUESTIONMARK = { kind = "texture", path = "Interface\\Icons\\INV_Misc_QuestionMark" },
  -- The search box glyph and the column sort arrow, both the clients own art, both shipped by
  -- Classic Era 1.15.9.69722 and the Forever beta 1.60.1.69893 at the same file data id.
  ICON_SEARCH = { kind = "texture", path = "Interface\\Common\\UI-Searchbox-Icon" },
  ICON_SORT_ARROW = { kind = "texture", path = "Interface\\Buttons\\UI-SortArrow" },
  -- Corner glyph for a row that stands for a spell or a recipe rather than an item. A blue
  -- flame, as the owner asked for, and the one spell icon that still reads as a flame at
  -- 12px. Shipped by Classic Era 1.15.9.69722 and the Forever beta 1.60.1.69893.
  ICON_SPELL_MARK = { kind = "texture", path = "Interface\\Icons\\Spell_Fire_BlueFire" },
  -- Corner glyph for a merged craft row that a recipe ITEM teaches, as against a spell the
  -- trainer hands out (UI/Tree.lua, Core/ViewModel.lua opts.mergeCrafts). A rolled scroll,
  -- because that is the picture the build itself puts on a recipe: 852 of the recipe class
  -- items in build 1.60.1.69913 carry this very icon, more than any other, so a player has
  -- already learnt what it means from their own bags. Shipped by Classic Era 1.15.9.69722 and
  -- the Forever beta 1.60.1.69913 at the same file data id, 134939.
  ICON_RECIPE_MARK = { kind = "texture", path = "Interface\\Icons\\INV_Scroll_03" },
  -- Corner glyph for an item this build withholds that somebody on the realm has since found
  -- (Core/Graph.lua Graph.DiscoveryMark). It replaces the question mark the same corner draws
  -- while nobody has found it, so the corner says which of the two states the row is in.
  --
  -- The client's own brown and gold chest, the very icon ART_EMPTY_SOURCES_ICON names, so the
  -- corner mark and the illustration over an undiscovered item's empty views are one idea. Both
  -- other corner marks are Interface\Icons art at the same size (ICON_SPELL_MARK, above, and
  -- ICON_RECIPE_MARK beside it), so a third keeps the family. fileDataID 132594, present in the
  -- Forever beta 1.60.1.69913 and in Classic Era 1.15.9.69722.
  --
  -- The 0.05 to 0.95 crop takes the icon's own dark border off, the usual crop for a client icon,
  -- and is worth two pixels each way at the 12 to 16 px this is drawn at.
  --
  -- Rejected: the minimap's own loot chest atlases (vignetteloot, vignetteloot-locked) and
  -- islands-azeritechest. The atlas names exist, but this client's ObjectIconsAtlas sheet does
  -- not hold the retail artwork at those rects: the two loot rects are empty in the extracted
  -- art and the third is a gold banner, so an atlas mark would draw nothing or the wrong thing.
  -- ChallengeMode-icon-chest and the Garrison and Delves treasure icons live in sheets a 1.60
  -- client does not ship at all.
  ICON_DISCOVERED_MARK = {
    kind = "texture",
    path = "Interface\\Icons\\INV_Box_01",
    coords = { 0.05, 0.95, 0.05, 0.95 },
  },
  -- The glyph beside each word on the window's top tabs, so the two views read at a glance.
  -- Both are light monochrome art, so the window desaturates each one and puts the tab's own
  -- text colour on it, gold when the tab is selected and the muted colour when it is not.
  -- Both coords crop the canvas down to the artwork itself, which is the whole point: the
  -- crop this round replaces took 679,31 to 694,43 out of the UITools sheet and cut the third
  -- bar off the list, which is why the live tab drew two bars and read as an equals sign.
  --
  -- Tree is the client's own indented list, three bars of falling length, at the rect
  -- uitools-icon-bar-fill names (679,31 to 699,51 on a 1024 by 256 canvas) narrowed to the
  -- 16 by 12 the bars actually fill. That rect is byte for byte the same on Classic Era
  -- 1.15.9.69722 and the Forever beta 1.60.1.69913.
  --
  -- Chain is the trade window's own link button, cropped to the two interlocking links (4,4 to
  -- 23,13 of a 32 by 32 canvas). The links are drawn on black rather than on transparency,
  -- which would normally rule the art out, but TabButtonTemplate's own art, HelpFrameTab-Active
  -- and HelpFrameTab-Inactive on both branches, is a pure black tab with a thin brown rim, so
  -- the black behind the links lands on black and nothing reads as a sticker. It is the only
  -- chain the client draws boldly enough to read at 16px: the chat link's own chain
  -- (Interface\\FriendsFrame\\UI-FriendsFrame-Link, the one this key used to name) is 1px
  -- strokes of cyan, and desaturating cyan drops it to 60 per cent luminance, so no tint can
  -- bring it back to the tab's colour at full brightness. That is what the owner saw as faint.
  --
  -- Both files ship with both target builds at the same file data id; check a new build with
  -- `uv run itemtree-data check-assets <build>`.
  ICON_TAB_TREE = {
    kind = "texture",
    path = "Interface\\UITools\\UITools",
    coords = { 681 / 1024, 697 / 1024, 35 / 256, 47 / 256 },
    texW = 1024,
    texH = 256,
  },
  ICON_TAB_CHAIN = {
    kind = "texture",
    path = "Interface\\TradeSkillFrame\\UI-TradeSkill-LinkButton",
    coords = { 4 / 32, 23 / 32, 4 / 32, 13 / 32 },
    texW = 32,
    texH = 32,
  },
  -- Brief TB13: the glyph a Keep line about a chained use leads with ("8 x BS via LW (Medium
  -- Leather)"), under a key of its own so the art can be swapped here without touching the tab.
  -- Brief TB14: a square icon, the same kind as the profession glyphs (CAT_*) on the lines above,
  -- so Assets.Markup draws it at their size.
  -- Brief K22: the owner's own pick (2026-10-05), Concussive Shot's simple icon, the vortex being
  -- too busy at this size: spell 5116, file data id 135860, Interface\ICONS\Spell_Frost_Stun.
  ICON_KEEP_CHAIN = { kind = "texture", path = "Interface\\Icons\\Spell_Frost_Stun" },
  -- The third top tab, Discoveries: what the realm has found that the build withholds. The
  -- client's own magnifier out of the UITools sheet, which is the same sheet and the same line
  -- art as ICON_TAB_TREE two keys up, so the tab strip reads as one family rather than three
  -- borrowed glyphs. White on transparency at 20 by 20, so it desaturates to nothing and takes
  -- the tab's own text colour cleanly, and the strokes still read at the 16px the tab draws it
  -- at. An atlas rather than a crop, because the artwork fills its own square: Assets.Aspect
  -- reads it as square, which is what the tab wants. Present in the Forever beta 1.60.1.69913.
  ICON_TAB_DISCOVERIES = { kind = "atlas", name = "uitools-icon-search" },
  -- The Boss loot tab (brief BL3): the client's own dungeon skull, the mark the world map and the
  -- minimap put on a dungeon entrance, so the tab reads as "dungeons" at a glance. No new art. A
  -- 32 by 32 member of UiTextureAtlasMember on the Forever beta 1.60.1.70009 (id 4707).
  ICON_TAB_BOSSLOOT = { kind = "atlas", name = "dungeonskull" },
  -- The glyph at the left of each level band header on the Boss loot tab (brief BL8), the way a
  -- tree category row wears one: loot that grows with the band. Each is the client's own item
  -- icon of a real item of that band, every file checked present in the Forever 1.60.1.70009
  -- manifest (ManifestInterfaceData):
  --   1  1 to 10    Worn Shortsword, common            INV_Sword_04          (135274)
  --   2  11 to 20   Blackened Defias Armor, leather    INV_Chest_Leather_08  (132723)
  --   3  21 to 30   Scarlet Chestpiece, mail           INV_Chest_Chain_07    (132629)
  --   4  31 to 40   Sang'thraze the Deflector, rare    INV_Sword_45          (135355)
  --   5  41 to 50   Runeblade of Baron Rivendare, epic INV_Sword_17          (135315)
  --   6  51 to 60   Thunderfury, legendary             INV_Sword_39          (135349)
  -- "Level unknown" wears the client's question mark, INV_Misc_QuestionMark (134400).
  ICON_BAND_1 = { kind = "texture", path = "Interface\\Icons\\INV_Sword_04" },
  ICON_BAND_2 = { kind = "texture", path = "Interface\\Icons\\INV_Chest_Leather_08" },
  ICON_BAND_3 = { kind = "texture", path = "Interface\\Icons\\INV_Chest_Chain_07" },
  ICON_BAND_4 = { kind = "texture", path = "Interface\\Icons\\INV_Sword_45" },
  ICON_BAND_5 = { kind = "texture", path = "Interface\\Icons\\INV_Sword_17" },
  ICON_BAND_6 = { kind = "texture", path = "Interface\\Icons\\INV_Sword_39" },
  ICON_BAND_UNKNOWN = { kind = "texture", path = "Interface\\Icons\\INV_Misc_QuestionMark" },
  -- Brief K24e: the small right arrow between the two item levels of the gear line ("13 -> 28",
  -- Core/Keep.lua Keep.LevelPair), drawn inline because the tooltip font may lack the arrow
  -- character. The client's chat menu arrow, file 130940 in the Forever 1.60.1.70170
  -- ManifestInterfaceData (Interface\CHATFRAME\ChatFrameExpandArrow.blp).
  ICON_ARROW_RIGHT = { kind = "texture", path = "Interface\\ChatFrame\\ChatFrameExpandArrow" },
  -- Brief BL10: the sheen on the place column's gold band bar, the Classic quest log's own title
  -- highlight (a horizontal bar, bright in the middle and at its top and bottom rows, black at the
  -- ends), drawn additively over the gold and tinted with it. File 136809, in the client's
  -- ManifestInterfaceData for 1.60.1.69893, 69913 and 70009 alike.
  BAND_SHEEN = { kind = "texture", path = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight" },
  -- Brief T4: the Keep mark round a bag slot, the client's own action button border (the glow an
  -- equipped item's action button wears), drawn additively and tinted ITEMTREE_COLOR_KEEP_GLOW.
  -- File 130739, Interface\BUTTONS\UI-ActionButton-Border.blp, in the client's
  -- ManifestInterfaceData for 1.60.1.69913 and 70009 alike. The fallback, were it ever missing, is
  -- a tinted square ring drawn from four edge textures; nothing needs it on this client.
  KEEP_GLOW = { kind = "texture", path = "Interface\\Buttons\\UI-ActionButton-Border" },
  -- Brief K3: the gold frame on the slot's own edge beside the glow, ItemTree's own art. A square
  -- frame with rounded corners about 2.5 px wide at slot size, bevelled (lit top and left, shaded
  -- bottom and right, a bright inner line) in the window's border gold, baked into the file, so it
  -- is drawn untinted. Art/keep-ring.tga, 64 by 64, built by scripts/build-art.py. It replaced the
  -- client's one pixel WhiteIconFrame tinted gold (brief Q9a), which got lost among busy icons.
  KEEP_RING = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\keep-ring" },
  -- Brief K7: the client art the Keep looks draw (UI/Overlay.lua KEEP_LOOKS), every name
  -- checked in UiTextureAtlasMember on 1.60.1.70009 and 70124. The slot glows are the client's own
  -- quality glow round a bag slot (39px), one per colour word a tier ramp names (UI/Theme.lua
  -- keepRamps); the thin borders are the auction house's item icon borders (136px), one per word.
  -- Drawn in their own colours, except white, which is tinted in the tier's colour.
  KEEP_SLOT_GLOW_WHITE = { kind = "atlas", name = "bags-glow-white" },
  KEEP_SLOT_GLOW_GREEN = { kind = "atlas", name = "bags-glow-green" },
  KEEP_SLOT_GLOW_BLUE = { kind = "atlas", name = "bags-glow-blue" },
  KEEP_SLOT_GLOW_PURPLE = { kind = "atlas", name = "bags-glow-purple" },
  KEEP_SLOT_GLOW_ORANGE = { kind = "atlas", name = "bags-glow-orange" },
  KEEP_SLOT_GLOW_ARTIFACT = { kind = "atlas", name = "bags-glow-artifact" },
  KEEP_SLOT_GLOW_HEIRLOOM = { kind = "atlas", name = "bags-glow-heirloom" },
  KEEP_BORDER_GRAY = { kind = "atlas", name = "auctionhouse-itemicon-border-gray" },
  KEEP_BORDER_WHITE = { kind = "atlas", name = "auctionhouse-itemicon-border-white" },
  KEEP_BORDER_GREEN = { kind = "atlas", name = "auctionhouse-itemicon-border-green" },
  KEEP_BORDER_BLUE = { kind = "atlas", name = "auctionhouse-itemicon-border-blue" },
  KEEP_BORDER_PURPLE = { kind = "atlas", name = "auctionhouse-itemicon-border-purple" },
  KEEP_BORDER_ORANGE = { kind = "atlas", name = "auctionhouse-itemicon-border-orange" },
  KEEP_BORDER_ARTIFACT = { kind = "atlas", name = "auctionhouse-itemicon-border-artifact" },
  -- The rest, each tinted in the tier's colour: the flash a new item's slot pulses with (90px),
  -- the slot's inner glow (36px), the new item corner ribbon (44px) and the cosmetic item's icon
  -- frame (64px).
  KEEP_FLASH = { kind = "atlas", name = "bags-glow-flash" },
  KEEP_INNER_GLOW = { kind = "atlas", name = "bags-innerglow" },
  KEEP_RIBBON = { kind = "atlas", name = "bags-newitem" },
  KEEP_COSMETIC = { kind = "atlas", name = "cosmeticiconframe" },
  -- Brief K12: ItemTree's own marks for three looks, white on transparent with a dark outline so
  -- the tier's colour tints them and they read on any icon, each built by scripts/build-art.py
  -- from Pillow primitives. The Corner gem is a faceted cut gem (32 by 32, look 6; it replaced
  -- the client's round slot highlight), the Dashed border a square frame of dashes on the
  -- canvas edge (64 by 64, look 11, marched by quarter turns of its tex coords), and the Flag a
  -- pole and a swallow tail pennant (32 by 32, look 12).
  KEEP_GEM = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\keep-gem" },
  KEEP_DASH = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\keep-dash" },
  KEEP_FLAG = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\keep-flag" },
  -- Brief K24a: the action tags a tooltip line wears, the owner's flat design: a rounded tag, a
  -- Font Awesome icon on the left, then the word (English only, baked into the art). One 512 by
  -- 512 atlas, Art/keep-tags.tga, built by scripts/build-art.py (keep-tags step), which prints these
  -- coords. The first four are white and greys, so a caller tints them with Assets.Markup's third
  -- argument: fill, a slightly darker outline and near black lettering, all in the one colour. The
  -- legendary Auction tag (over 500 gold) is full colour and drawn untinted.
  -- width and height are the tag's own shape in texture pixels, so Markup keeps its aspect.
  -- Brief K24c: every tag is in the atlas twice. coords is the LARGE art (body 56 high), small the
  -- SMALL art (body 34 high, twice a 17 px tooltip line, so the client's bilinear sample is a clean
  -- 2:1 average), and Markup picks small for a size of TAG_SMALL_MAX or less by itself. The
  -- legendary tag's gradient rim sits OUTSIDE a normal tag's body, so its rect is bigger than its
  -- body by the rim on every side; outset is that rim over the body's height, and Markup draws it
  -- that much taller and wider so its body matches a normal tag's at the same size.
  TAG_KEEP = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 152 / 512, 4 / 512, 60 / 512 },
    texW = 512,
    texH = 512,
    width = 148,
    height = 56,
    small = { coords = { 278 / 512, 374 / 512, 4 / 512, 38 / 512 }, width = 96, height = 34 },
  },
  TAG_AUCTION = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 206 / 512, 68 / 512, 124 / 512 },
    texW = 512,
    texH = 512,
    width = 202,
    height = 56,
    small = { coords = { 278 / 512, 410 / 512, 44 / 512, 78 / 512 }, width = 132, height = 34 },
  },
  TAG_VENDOR = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 198 / 512, 132 / 512, 188 / 512 },
    texW = 512,
    texH = 512,
    width = 194,
    height = 56,
    small = { coords = { 278 / 512, 404 / 512, 84 / 512, 118 / 512 }, width = 126, height = 34 },
  },
  TAG_DISENCHANT = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 265 / 512, 196 / 512, 252 / 512 },
    texW = 512,
    texH = 512,
    width = 261,
    height = 56,
    small = { coords = { 278 / 512, 450 / 512, 124 / 512, 158 / 512 }, width = 172, height = 34 },
  },
  -- Brief K24h: the Equip tag, the Keep tag's look (white and greys, tinted the Keep colour) with
  -- a shirt and the word Equip, for an upgrade the player can wear today.
  TAG_EQUIP = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 174 / 512, 338 / 512, 394 / 512 },
    texW = 512,
    texH = 512,
    width = 170,
    height = 56,
    small = { coords = { 278 / 512, 390 / 512, 214 / 512, 248 / 512 }, width = 112, height = 34 },
  },
  -- Brief K26: the Pet food tag, the Keep tag's look with a paw and the words Pet food, for the
  -- one stack of pet food a hunter's pet eats. Brief FN1: every tag here, and the Worthless and
  -- Equip pills, is drawn in the vendored Inter (OFL, Art/src/fonts/inter) by one build step.
  TAG_PET = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 213 / 512, 398 / 512, 454 / 512 },
    texW = 512,
    texH = 512,
    width = 209,
    height = 56,
    small = { coords = { 278 / 512, 414 / 512, 254 / 512, 288 / 512 }, width = 136, height = 34 },
  },
  -- Brief BQ9: the "do this now" tags, the Keep tag's look (white and greys, tinted the Use blue,
  -- Theme ITEMTREE_COLOR_USE) with a play wedge and the words Use and Open, pasted into the atlas's
  -- right column alone (scripts/build-art.py keep-tags-use).
  TAG_USE = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 278 / 512, 412 / 512, 296 / 512, 352 / 512 },
    texW = 512,
    texH = 512,
    width = 134,
    height = 56,
    small = { coords = { 278 / 512, 364 / 512, 424 / 512, 458 / 512 }, width = 86, height = 34 },
  },
  TAG_OPEN = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 278 / 512, 436 / 512, 360 / 512, 416 / 512 },
    texW = 512,
    texH = 512,
    width = 158,
    height = 56,
    small = { coords = { 278 / 512, 380 / 512, 466 / 512, 500 / 512 }, width = 102, height = 34 },
  },
  -- Brief WL1 (QA item 108, the owner's ruling "A"): the Worthless tag, the bottom rung of the sale
  -- ladder, the Keep tag's look (white and greys, tinted Keep.WORTHLESS_TINT's muted grey) with an
  -- empty set glyph and the word Worthless. The keep-tags atlas has no room for it, so it has its own
  -- 256 by 128 atlas (scripts/build-art.py worthless-tag).
  TAG_WORTHLESS = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\worthless-tag",
    coords = { 4 / 256, 245 / 256, 4 / 128, 60 / 128 },
    texW = 256,
    texH = 128,
    width = 241,
    height = 56,
    small = { coords = { 4 / 256, 162 / 256, 68 / 128, 102 / 128 }, width = 158, height = 34 },
  },
  -- Brief BQ9: the bag's Use mark, the tags' play wedge alone, white with a dark outline, tinted the
  -- Use blue, 32 by 32, drawn in a slot's corner (UI/Overlay.lua) for an [Open] or [Use] item.
  USE_MARK = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\use-mark" },
  TAG_AUCTION_LEGENDARY = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\keep-tags",
    coords = { 4 / 512, 224 / 512, 258 / 512, 334 / 512 },
    texW = 512,
    texH = 512,
    width = 220,
    height = 76,
    outset = 10 / 56,
    small = { coords = { 278 / 512, 422 / 512, 164 / 512, 210 / 512 }, width = 144, height = 46, outset = 6 / 34 },
  },
  -- Brief K9: the flame on a valuable item's slot (an auction value at the Keep value or more),
  -- drawn with KEEP_BORDER_ORANGE and KEEP_SLOT_GLOW_ORANGE above. Two of the client's legendary
  -- toast particle sheets, drawn additively in their own orange along the slot's top edge,
  -- checked in UiTextureAtlasMember on 1.60.1.70009 and 70124. Others there if these read
  -- poorly: LegendaryToast-particles3, LegendaryToast-OrangeStarglow, Relic-Fire-TraitGlow and
  -- titleprestige-ember.
  KEEP_VALUE_FLAME_1 = { kind = "atlas", name = "LegendaryToast-particles1" },
  KEEP_VALUE_FLAME_2 = { kind = "atlas", name = "LegendaryToast-particles2" },
  -- Brief BL21: the silver ring drawn over a rare elite's or rare's round portrait on the Boss
  -- loot tab. A true circle filling its canvas, about a seventh of it wide, bevelled (lit upper
  -- left on its outer slope, shaded lower right, the mid tone on its crest) in neutral greys with
  -- a clear centre and outside, so UI/BossLoot.lua tints it the rare silver with no desaturate.
  -- Art/portrait-ring.tga, 64 by 64, built by scripts/build-art.py.
  PORTRAIT_RING = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\portrait-ring" },
  -- Brief BL16: the round mask a rare's portrait on the Boss loot tab is drawn through
  -- (Texture:SetMask), the client's own portrait alpha mask, file 130924,
  -- Interface\CHARACTERFRAME\TempPortraitAlphaMask.blp, in the client's ManifestInterfaceData for
  -- 1.60.1.70009. A mask, never drawn as a texture itself.
  PORTRAIT_MASK = { kind = "texture", path = "Interface\\CharacterFrame\\TempPortraitAlphaMask" },
  -- Brief BQ14 (QA items 14 and 43): the rarity circle after a profession use line's count
  -- ("10 x Leatherworking" and a circle per quality its recipes make), the same white disc drawn as
  -- an inline texture, which UI/Tooltip.lua tints to each quality's Theme colour through the
  -- escape's vertex colour (Assets.Markup's tint).
  QUALITY_DOT = { kind = "texture", path = "Interface\\CharacterFrame\\TempPortraitAlphaMask" },
  -- Brief BQ14: the gap after a circle: the disc's own top left corner, clear outside the circle,
  -- cropped to a 1 by 3 strip so it draws a third as wide as it is high (2 pixels at the circle's 6).
  QUALITY_DOT_GAP = {
    kind = "texture",
    path = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    coords = { 0, 1 / 64, 0, 3 / 64 },
    texW = 64,
    texH = 64,
    width = 1,
    height = 3,
  },
  -- Brief TV2 (QA item 347, across-5): the clear lead of a wrapped tooltip line's continued lines, so
  -- they start under the first line's words (Assets.Spacer): one clear pixel of the disc's corner,
  -- outside its circle like QUALITY_DOT_GAP's strip, drawn as wide as the line asks for.
  TOOLTIP_INDENT = {
    kind = "texture",
    path = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    coords = { 0, 1 / 64, 0, 1 / 64 },
    texW = 64,
    texH = 64,
  },
  -- Brief BL11: the silver dragon crest beside a Boss loot rare elite's or rare's name, cropped
  -- from the game's own rare elite target frame (file 137020, 256 by 128, in the Forever
  -- 1.60.1.70009 ManifestInterfaceData). The dragon curls over the portrait ring's top left, which
  -- sits right of the file's middle: the crop is its head and crown, pixels 138 to 172 across and
  -- 2 to 36 down, square. The owner's knob: these coords are tuned by eye in QA.
  CREST_RARE_ELITE = {
    kind = "texture",
    path = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite",
    coords = { 138 / 256, 172 / 256, 2 / 128, 36 / 128 },
  },
  -- Empty state illustrations, drawn in the middle of a pane that has nothing to list.
  --
  -- Sources is ItemTree's own artwork: a green dragon curled round a treasure chest that wears
  -- the tree shield off the logo, which is the picture the pane is asking the player to fill in.
  -- It is drawn as an illustration rather than as one more glyph, so it is not cropped to an
  -- icon square and carries no border. The artwork is wider than it is tall and a texture has to
  -- be a power of two, so it sits on the same 512 by 256 canvas the logo does with transparent
  -- padding around it: coords is the rect it occupies inside that canvas, aspect is its width
  -- over its height, and texW and texH state the canvas size. Regenerate it, and these four
  -- numbers, with scripts/build-art.py. ART_EMPTY_SOURCES_ICON is the client icon UI/Tree.lua
  -- falls back to on a build whose Assets table has no own art, the way the badges fall back to
  -- the composed form: INV_Box_01 is the brown and gold chest, and the one to use, because the
  -- other three lids in that family are red, green and purple and a coloured chest reads as an
  -- item quality rather than as a chest. Its 0.05 to 0.95 crop takes the icon's own dark border
  -- off so the artwork sits on the pane rather than in a square tile.
  --
  -- Discoveries is the client's own question mark at the same crop, which is what the game
  -- itself draws for an item whose details it cannot resolve, so it is exactly what an
  -- undiscovered item looks like to a player. It replaces the padlock the pane borrowed, which
  -- said "locked" about something that is only waiting to be found. Both client icons ship with
  -- the Forever beta 1.60.1.69913.
  ART_EMPTY_SOURCES = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\empty-sources",
    coords = { 0.203125, 0.796875, 0.007812, 0.992188 },
    aspect = 1.206349,
    texW = 512,
    texH = 256,
  },
  ART_EMPTY_SOURCES_ICON = {
    kind = "texture",
    path = "Interface\\Icons\\INV_Box_01",
    coords = { 0.05, 0.95, 0.05, 0.95 },
  },
  ART_EMPTY_DISCOVERIES = {
    kind = "texture",
    path = "Interface\\Icons\\INV_Misc_QuestionMark",
    coords = { 0.05, 0.95, 0.05, 0.95 },
  },
  -- Minimap button. MINIMAP_ICON matches ## IconTexture in the TOC, so the button, the addon
  -- list and the compartment entry all show the same glyph. Change the two together.
  --
  -- The owner's own icon, a gold tree glyph on a green disc, which replaced the client's druid
  -- tree icon (Ability_Druid_TreeOfLife) on 2026-09-28: a tester read that one as a restoration
  -- druid addon. Art/minimap.tga is the disc alone, edge to edge on a 64 by 64
  -- transparent square, so it needs no crop: its own transparent corners make it round, and the
  -- tracking border's ring covers its edge. An addon path, so the addon list and the compartment
  -- can draw it too.
  MINIMAP_ICON = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\minimap" },
  MINIMAP_BORDER = { kind = "texture", path = "Interface\\Minimap\\MiniMap-TrackingBorder" },
  MINIMAP_HIGHLIGHT = { kind = "texture", path = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" },
  -- Brief B1: the opt in second minimap button, which opens the Boss loot tab, wears a face. The
  -- client's own Edwin VanCleef boss portrait, Achievement_Boss_EdwinVancleef (file 236409 in the
  -- Forever 1.60.1.70009 ManifestInterfaceData): a head on, masked face that fills its square, so
  -- it still reads as a face at 20 px, and the Deadmines boss every player meets. Also confirmed in
  -- that manifest and not chosen: INV_Misc_Head_Orc_01 (134170), a trophy head drawn small inside
  -- its square, and Spell_Shadow_Skull (237569), a skull rather than a face. The coords trim the
  -- icon's baked border and mask names the client's round portrait mask (TempPortraitAlphaMask,
  -- file 130924 in the same manifest), which UI/Minimap.lua lays over the icon so it sits round
  -- inside the ring. The owner may swap the icon later.
  MINIMAP_ICON_BOSS = {
    kind = "texture",
    path = "Interface\\Icons\\Achievement_Boss_EdwinVancleef",
    coords = { 0.08, 0.92, 0.08, 0.92 },
    mask = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
  },
  -- Atlases. Every name here exists in Classic Era build 1.15.9.69722; check a new build
  -- with `uv run itemtree-data check-assets <build>` in the ItemTree-Data checkout.
  -- The design names the retail quest tracker chevrons, which Classic Era does not ship,
  -- so the UITools chevrons stand in. See docs/design-deviations.md.
  ICON_CHEVRON_EXPAND = { kind = "atlas", name = "uitools-icon-chevron-right" },
  ICON_CHEVRON_COLLAPSE = { kind = "atlas", name = "uitools-icon-chevron-down" },
  -- The mark beside a settings row that belongs to the tick box above it (brief U5). The same
  -- UITools right chevron as ICON_CHEVRON_EXPAND, a key of its own because it means "child of
  -- the row above" rather than "open this". Neither build ships an elbow or branch glyph; this
  -- 20 by 20 chevron is the one small pale arrow that still reads at 10px and desaturates to
  -- grey with the row.
  OPTIONS_CHILD_MARKER = { kind = "atlas", name = "uitools-icon-chevron-right" },
  -- Brief E94: the rule under the settings page's title and Defaults button. The page draws on a
  -- canvas, which hides the client's own list header, so it draws the header's divider itself:
  -- the atlas Blizzard_SettingsList.xml puts there (forever branch), at its own size.
  OPTIONS_DIVIDER = { kind = "atlas", name = "Options_HorizontalDivider" },
  QUEST_NORMAL = { kind = "atlas", name = "QuestNormal" },
  QUEST_LEGENDARY = { kind = "atlas", name = "QuestLegendary" },
  QUEST_DAILY = { kind = "atlas", name = "QuestDaily" },
  ICON_CHECK = { kind = "atlas", name = "common-icon-checkmark" },
  ICON_REDX = { kind = "atlas", name = "common-icon-redx" },
  ICON_ZOOMIN = { kind = "atlas", name = "common-icon-zoomin" },
  -- The recently viewed button on the title row. A clock, not the rewind arrow the button used
  -- to borrow: the owner asked for a stopwatch or a clock face, and the auction house's own
  -- duration glyph is the one clock the client draws at control size. Both target builds ship
  -- it at the same 24 by 24 rect.
  ICON_HISTORY = { kind = "atlas", name = "auctionhouse-icon-clock" },
  -- The cog beside the word Options in the footer, from the same UITools sheet as the chevrons
  -- above. 20 by 20 on both target builds; the window tints it gold.
  ICON_COG = { kind = "atlas", name = "uitools-icon-settings" },
  -- The die on the band's random item button: the client's own group loot roll die, which is
  -- what a player already presses to take a chance on something. GroupLootFrame.xml on the
  -- mirror's `forever` branch draws this very file on its RollButton at 32 by 32 with no
  -- TexCoord at all, so it is taken whole rather than cropped, and the loot alert draws the same
  -- file at 36. The artwork fills its own 32 by 32 canvas left to right and stops three rows
  -- short of the bottom edge, with every corner fully transparent (measured off the extracted
  -- PNG), so it sits on the button's plate with no backing square of its own: UI/Frame.lua's
  -- DICE_PAD is that three row margin turned into a nudge. The file has a Down and a Highlight
  -- beside it, which the client's roll button uses as its own PushedTexture and HighlightTexture,
  -- and this button needs neither: UIPanelButtonTemplate already draws a pressed, a hover and a
  -- disabled plate under the glyph, so this is the one key. Present in the Forever beta
  -- 1.60.1.69913 and in Classic Era 1.15.9.69722, where BADGE_PREDICTED already names it.
  ICON_DICE = { kind = "texture", path = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
  -- Supplied badge medallions, ItemTree's own art (complete marks, no backing composed). The New
  -- medallion, the infinity mark in Forever's blue ring, carries its own colour and is drawn as
  -- it is: no tint here and no desaturate in UI/Badges.lua META.new.
  BADGE_ART_NEW = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-new" },
  BADGE_ART_CHANGED = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-changed" },
  BADGE_ART_PREDICTED = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-predicted" },
  BADGE_ART_NOTE = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-note" },
  -- The Season of Discovery medallion: the New one with its blue swapped for the epic quality
  -- purple, drawn as it is, with no desaturate and no vertex colour (UI/Badges.lua META.sod).
  -- Built by scripts/build-art.py from Art/badge-new.tga, so it follows the New art.
  BADGE_ART_SOD = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-sod" },
  -- The Unverified medallion, the owner's own question mark in the same silver ring as the four
  -- above. It replaced the composed mark this kind used to draw, a "?" on the near black disc,
  -- which is still what UI/Badges.lua falls back to where a client will not draw the file: META
  -- .unverified keeps its backing and its glyph beside this key. Built by scripts/build-art.py
  -- from Art/src/badge-unverified.png, which is committed and left out of the package.
  BADGE_ART_UNVERIFIED = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-unverified" },
  -- Brief A3: the Guess medallion, the owner's three dice inside the family's ring in the guess
  -- rose, drawn as it is (UI/Badges.lua META.guess). Where a client will not draw the file the
  -- badge falls back to the composed ring GS3 drew: BADGE_RING in the guess colour with
  -- BADGE_GUESS inside it. Built by scripts/build-art.py from Art/src/badge-guess.png.
  BADGE_ART_GUESS = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\badge-guess" },
  -- The ItemTree logo, for the settings panel and any header that wants it. The artwork is
  -- wider than it is tall and a texture has to be a power of two, so it sits on a 512 by 256
  -- canvas with transparent padding. coords is the rect the artwork occupies inside that
  -- canvas, aspect is its width over its height, and texW and texH state the canvas size so
  -- Assets.Markup can crop it inline. Regenerate the file with scripts/build-art.py.
  LOGO = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\logo",
    coords = { 0.152344, 0.847656, 0.007812, 0.992188 },
    aspect = 1.412698,
    texW = 512,
    texH = 256,
  },
  -- The square mark, a tight crop of the shield out of the middle of the logo. The lettering
  -- crosses the shield, so the crop keeps some of it, but at 14 to 20 px the gold rim and the
  -- green field are what read, which the whole logo shrunk does not.
  LOGO_MARK = { kind = "addon", path = "Interface\\AddOns\\ItemTree\\Art\\logo-mark" },
  -- Badge composition art (client textures)
  -- BADGE_RING is the shared backing every composed badge sits on (and the tree's loading and
  -- chevron marks), so it carries no tint of its own: UI/Badges.lua colours the ring per kind
  -- from the Theme, and New's ring is ITEMTREE_COLOR_SEMANTIC_NEW, the same silver blue.
  BADGE_RING = { kind = "texture", path = "Interface\\Cooldown\\ping4" },
  -- The New star (the fallback where the medallion will not draw) is New's alone, so it carries
  -- the New silver blue wherever it is drawn, a badge or a tooltip line.
  BADGE_NEW = { kind = "texture", path = "Interface\\Cooldown\\star4", tint = "BADGE_NEW_TINT" },
  -- The Season of Discovery mark: the New star, tinted the epic quality purple through
  -- Assets.BADGE_SOD_TINT. `tint` names that constant, so Assets.Apply puts the colour on the
  -- texture and Assets.Markup writes it into the escape, and the star is purple wherever it is
  -- drawn, a badge frame or a tooltip line.
  BADGE_SOD = { kind = "texture", path = "Interface\\Cooldown\\star4", tint = "BADGE_SOD_TINT" },
  BADGE_CHANGED = { kind = "texture", path = "Interface\\Buttons\\UI-RefreshButton" },
  BADGE_CHANGED_ALT = { kind = "texture", path = "Interface\\Buttons\\UI-RotationRight-Button-Up" },
  BADGE_INFO = { kind = "texture", path = "Interface\\FriendsFrame\\InformationIcon" },
  BADGE_PREDICTED = { kind = "texture", path = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
  -- Brief GS3: the guess badge's inner mark, the same ring art as BADGE_RING drawn smaller inside
  -- it and tinted the guess colour through Assets.BADGE_GUESS_TINT. Since brief A3 it is only the
  -- fallback, drawn where BADGE_ART_GUESS, the dice medallion, will not.
  BADGE_GUESS = { kind = "texture", path = "Interface\\Cooldown\\ping4", tint = "BADGE_GUESS_TINT" },
  SLOT_GLOW = { kind = "texture", path = "Interface\\Buttons\\CheckButtonHilight" },
  SLOT_CORNERS = { kind = "texture", path = "Interface\\Buttons\\UI-AutoCastableOverlay" },
  ACTION_BORDER = { kind = "texture", path = "Interface\\Buttons\\UI-ActionButton-Border" },
  -- Quest glyphs
  QUEST_AVAILABLE = { kind = "texture", path = "Interface\\GossipFrame\\AvailableQuestIcon" },
  QUEST_ACTIVE = { kind = "texture", path = "Interface\\GossipFrame\\ActiveQuestIcon" },
  QUEST_INCOMPLETE = { kind = "texture", path = "Interface\\GossipFrame\\IncompleteQuestIcon" },
  QUEST_REPEATABLE = { kind = "texture", path = "Interface\\GossipFrame\\DailyQuestIcon" },
  WORLD = { kind = "texture", path = "Interface\\WorldMap\\UI-World-Icon" },
  -- The pin on a creature's Map tab (UI/Map.lua, brief E59). The client's own map pin: the
  -- waypoint marker, a teardrop whose point is at the bottom, which is where the position is and
  -- is why UI/Map.lua anchors a pin by its BOTTOM rather than by its centre.
  --
  -- The file is Interface\Waypoint\WaypoinMapPinUI (Blizzard's own spelling, one "t" short),
  -- fileDataID 3500068, read out of
  -- ItemTree-Data/builds/1.60.1.69913/ManifestInterfaceData.csv, the client's own manifest of the
  -- files it ships. Its whole 128 by 64 canvas is the five waypoint pin rects and nothing else,
  -- so unlike the loot chest atlases ICON_DISCOVERED_MARK had to reject, the artwork really is at
  -- the rect named here: UiTextureAtlas row 1567 states the canvas and UiTextureAtlasMember gives
  -- Waypoint-MapPin-Untracked as 30 by 30 at 73,1 to 103,31. A path and a crop rather than the
  -- atlas name, because a path survives a build where the atlas registry has moved on, and this
  -- is the plain untracked pin rather than the tracked one, which carries a ring the tab has no
  -- meaning for.
  --
  -- Drawn at about 14px on a 500px wide map (Map.PIN_AT_BASIS): the shipped pins sit on a grid of
  -- five percent of the zone map, which is 25px apart there, so six pins in one corner still read
  -- as six.
  MAP_PIN = {
    kind = "texture",
    path = "Interface\\Waypoint\\WaypoinMapPinUI",
    coords = { 73 / 128, 103 / 128, 1 / 64, 31 / 64 },
    texW = 128,
    texH = 64,
  },
  -- Brief M8: the instance portal pin on an instance's Map tab (UI/Map.lua Map.PORTAL_KEY), beside
  -- the Entrance pin at the outdoor mouth. The Dalaran portal spell icon, a violet swirl with no
  -- city emblem, fileDataID 237508, which ManifestInterfaceData.csv lists on both 1.60.1.70009
  -- and 1.15.9.69722. A client icon rather than the PortalPurple or MagePortalAlliance atlases:
  -- those live on the ObjectIconsAtlas sheet ICON_DISCOVERED_MARK had to reject. Cropped past the
  -- icon's own border like every client icon; UI/Map.lua falls back to MAP_PIN where it will not
  -- draw.
  MAP_PIN_PORTAL = {
    kind = "texture",
    path = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
    coords = { 0.07, 0.93, 0.07, 0.93 },
  },
  -- Brief MP1: the player's own place on ItemTree's maps (UI/Map.lua Map.PLAYER_ARROW_KEY), the
  -- world map's own player arrow. GroupMembersPinMixin:OnLoad puts this very atlas on the world
  -- map's player pin (SetPinTexture("player", "UI-WorldMapArrow"), Blizzard_SharedMapDataProviders/
  -- GroupMembersDataProvider.lua, wow-ui-source branch forever, unchanged from 1.60.1.70245 to
  -- 70291), and the client turns it to the player's facing. UiTextureAtlasElement 28217 on
  -- 1.60.1.69913 and 70009, whose member ui-worldmaparrow-2x is 64 by 64 at 1,1 on
  -- Interface\HUD\UIworldmaparrow2x (fileDataID 6152823). The art points north, which is facing 0.
  MAP_PLAYER_ARROW = { kind = "atlas", name = "UI-WorldMapArrow" },
  -- Brief MP1: what the player's place wears where the client gives no facing, so an arrow would
  -- point the wrong way: the world map's own unit dot, the default UnitPositionFrame texture
  -- (UnitPositionFrameTemplates.lua, Blizzard_UIPanels_Game/Mainline, same branch), white, which
  -- UI/Map.lua tints. UiTextureAtlasElement 5448 on 1.60.1.70009, 19 by 18 at 1,1 of its sheet.
  MAP_PLAYER_DOT = { kind = "atlas", name = "WhiteCircle-RaidBlips" },
  -- Brief UX1 (QA item 402): the "Waypoint added" toast (UI/Toast.lua), drawn in the client's own
  -- toast art on a frame of our own. The three are members of atlas 570, Interface\Scenarios\
  -- ScenarioParts (fileDataID 1061073, 512 by 512), the sheet the client's own small toasts draw
  -- from: Toast-Frame 311 by 78 at 1,97, Toast-IconBG 47 by 52 at 330,1 and Toast-Flash 327 by 94
  -- at 1,1, the same rects in UiTextureAtlasMember on 1.15.9.69722, 1.60.1.70170 and 1.60.1.70450.
  -- Paths and crops rather than the atlas names, as MAP_PIN is, so a build whose atlas registry has
  -- moved on still draws them.
  TOAST_FRAME = {
    kind = "texture",
    path = "Interface\\Scenarios\\ScenarioParts",
    coords = { 1 / 512, 312 / 512, 97 / 512, 175 / 512 },
    texW = 512,
    texH = 512,
  },
  TOAST_ICON_BG = {
    kind = "texture",
    path = "Interface\\Scenarios\\ScenarioParts",
    coords = { 330 / 512, 377 / 512, 1 / 512, 53 / 512 },
    texW = 512,
    texH = 512,
  },
  TOAST_FLASH = {
    kind = "texture",
    path = "Interface\\Scenarios\\ScenarioParts",
    coords = { 1 / 512, 328 / 512, 1 / 512, 95 / 512 },
    texW = 512,
    texH = 512,
  },
  -- The toast's icon: the waypoint pin as the client draws the one it is tracking, the ringed pin
  -- beside MAP_PIN's plain one on the same sheet (UiTextureAtlasMember Waypoint-MapPin-Tracked, 30
  -- by 30 at 41,33 of row 1567's 128 by 64 canvas, on 1.60.1.70450). UI/Toast.lua falls back to
  -- MAP_PIN where it will not draw.
  TOAST_WAYPOINT = {
    kind = "texture",
    path = "Interface\\Waypoint\\WaypoinMapPinUI",
    coords = { 41 / 128, 71 / 128, 33 / 64, 63 / 64 },
    texW = 128,
    texH = 64,
  },
  -- Category glyphs (profession icons by client path; the design's Lucide masks are web only)
  CAT_ALCHEMY = { kind = "texture", path = "Interface\\Icons\\Trade_Alchemy" },
  CAT_BLACKSMITHING = { kind = "texture", path = "Interface\\Icons\\Trade_BlackSmithing" },
  CAT_ENGINEERING = { kind = "texture", path = "Interface\\Icons\\Trade_Engineering" },
  CAT_ENCHANTING = { kind = "texture", path = "Interface\\Icons\\Trade_Engraving" },
  CAT_TAILORING = { kind = "texture", path = "Interface\\Icons\\Trade_Tailoring" },
  CAT_LEATHERWORKING = { kind = "texture", path = "Interface\\Icons\\Trade_LeatherWorking" },
  CAT_MINING = { kind = "texture", path = "Interface\\Icons\\Trade_Mining" },
  CAT_HERBALISM = { kind = "texture", path = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
  CAT_SKINNING = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
  CAT_FISHING = { kind = "texture", path = "Interface\\Icons\\Trade_Fishing" },
  CAT_COOKING = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Food_15" },
  CAT_FIRSTAID = { kind = "texture", path = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
  CAT_QUEST = { kind = "texture", path = "Interface\\GossipFrame\\AvailableQuestIcon" },
  -- Brief QI2 (the owner, 2026-10-23: "the turn in npc should have the same question mark not the
  -- quest exclamation in quest area"): a quest page's Turned in to category, and a turn in row that
  -- would otherwise wear CAT_QUEST (a name with no page, a quest giving object), wear the client's
  -- own turn in "?", the other half of the gossip pair CAT_QUEST's "!" comes from. The Forever quest
  -- greeting gives its title buttons AvailableQuestIcon (QuestFrameTemplates.xml:136) and asks
  -- QuestUtil for the active quest icon on a quest being handed in (QuestFrame.lua:360), both in
  -- Blizzard_UIPanels_Game/Mainline on wow-ui-source's forever branch at 1.60.1.70245. QuestUtils.lua
  -- is not in the mirror on disk, so this is that pair's gossip file, ActiveQuestIcon: fileDataID
  -- 132048, beside AvailableQuestIcon's 132049 in ManifestInterfaceData.csv on 1.60.1.70009 and on
  -- 1.15.9.69722. The same file as QUEST_ACTIVE, a key of its own as CAT_QUEST is beside
  -- QUEST_AVAILABLE, and drawn on transparency at the same 16 by 16.
  CAT_QUEST_TURNIN = { kind = "texture", path = "Interface\\GossipFrame\\ActiveQuestIcon" },
  -- The Trainer category: a recipe nothing teaches is learnt from a trainer. The client's own
  -- trainer glyph, which is what a player sees over the gossip line that opens a trainer, on
  -- transparency at 16 by 16 the way CAT_QUEST beside it is. Both target builds ship it.
  CAT_TRAINER = { kind = "texture", path = "Interface\\GossipFrame\\TrainerGossipIcon" },
  -- Brief P6b: the side an NPC serves, a small icon before a vendor's, a trainer's, a quest
  -- giver's or a creature's zone column and beside the name in an NPC page's header. The client's
  -- own honour portraits, one family of three so the neutral one reads as the same kind of mark:
  -- atlas members of Interface\PVPFrame\PvPPrestigeIcons (fileDataID 1250929), each 50 by 52,
  -- in UiTextureAtlasMember and ManifestInterfaceData on 1.60.1.70009. Keyed by the table's own
  -- side numbers through Assets.SIDES below.
  SIDE_ALLIANCE = { kind = "atlas", name = "honorsystem-portrait-alliance" },
  SIDE_HORDE = { kind = "atlas", name = "honorsystem-portrait-horde" },
  SIDE_NEUTRAL = { kind = "atlas", name = "honorsystem-portrait-neutral" },
  -- The "Item use" category: a spell an item's own use effect casts, which is how Sulfuras is
  -- made. A pouch with a buckle, because the thing you do is reach into your bag and use an
  -- item. The other candidate, INV_Misc_Gear_01, is a cog, and a cog at 14px beside
  -- CAT_ENGINEERING's gold cog reads as engineering. Both target builds ship this one.
  CAT_ITEM_USE = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Bag_08" },
  -- The Requirements category and the level, skill and class rows under it. The quest "!" is
  -- reserved for quests, so this is the padlock the client itself draws on a group finder
  -- entry you do not meet the requirements for. It sits on transparency like the gossip
  -- glyphs beside it, reads as a padlock down to 14px, and both target builds ship it.
  CAT_REQUIREMENT = { kind = "texture", path = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK" },
  CAT_VENDOR = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Coin_01" },
  CAT_DROPS = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pathfinding" },
  CAT_ZONE = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Map_01" },
  CAT_NOTE = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Note_01" },
  CAT_INSTANCE = { kind = "texture", path = "Interface\\Icons\\Achievement_Zone_Silithus_01" },
  -- The three categories the shipped Classic Era table brought with it that no client glyph
  -- already stood for (Core/EraSources.lua, brief E38). Skinning, herbs, veins and fishing take
  -- the profession icons above, which is what a player already reads them by; these three do
  -- not, so each takes the art the game itself puts on the thing.
  --
  -- CAT_CHEST is a world object you open: a chest, a barrel, a crate. The brown and gold lid of
  -- INV_Box_01, which ART_EMPTY_SOURCES_ICON already falls back to for exactly the same reason:
  -- the other three lids in that family are red, green and purple, and a coloured chest reads as
  -- an item quality rather than as a chest.
  --
  -- CAT_PICKPOCKET is a pocket picked. The build ships no icon named for the ability itself, so
  -- this is the cut purse: a brown bag spilling coins, which is what a rogue actually lifts. It
  -- is a bag of coins rather than CAT_VENDOR's single flat gold coin, and the two sit under
  -- different words, so neither reads as the other.
  --
  -- CAT_CONTAINER is the item a container gives up, which is the Contained in category the
  -- collector already fills: a wooden crate, distinct from CAT_ITEM_USE's buckled pouch.
  --
  -- All three ship with the Forever beta 1.60.1.69913; check a new build with
  -- `uv run itemtree-data check-assets <build>` in the ItemTree-Data checkout.
  CAT_CHEST = { kind = "texture", path = "Interface\\Icons\\INV_Box_01" },
  CAT_PICKPOCKET = { kind = "texture", path = "Interface\\Icons\\INV_Misc_CoinBag01" },
  CAT_CONTAINER = { kind = "texture", path = "Interface\\Icons\\INV_Crate_01" },
  -- Brief BQ15 (QA 2026-10-10 item 1): the "Rewards (n)" group under a quest in Used by. A stack of
  -- gold coins, what a quest hands back, and not CAT_VENDOR's single flat coin or CAT_PICKPOCKET's
  -- bag. Ships with the Forever beta 1.60.1.70009 (file 133785).
  CAT_REWARDS = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Coin_02" },
  -- Brief Q9b: a fishing school whose fish is not known (a school's page reached with no item in
  -- its key and nothing recorded from it). The client's own school of fish, not the rod
  -- CAT_FISHING wears for the category. Ships with the Forever beta 1.60.1.70009 (file 236572).
  CAT_FISH_SCHOOL = { kind = "texture", path = "Interface\\Icons\\Achievement_Profession_Fishing_FindFish" },
  -- Brief Q9b: the "Item set" category and a set row whose set has no head or chest piece to show
  -- (the owner on the note it wore: "not very fun", "like a helm plus gloves or something"). A
  -- plate helm, the piece a player knows a set by. Chosen over INV_Chest_Plate01 (file 132736) and
  -- INV_Misc_ArmorKit_17 (file 133611); all three ship with the Forever beta 1.60.1.70009, and
  -- this one is file 133071.
  CAT_SET = { kind = "texture", path = "Interface\\Icons\\INV_Helmet_03" },
  -- What KIND of creature a source row names (brief E50). Every creature row used to wear
  -- CAT_DROPS, one glyph over a list of twenty, and the shipped Classic Era table now states the
  -- type and the beast family of every name it uses (Core/EraSources.lua KindOf), so a row can
  -- say at a glance whether it is a wolf, a murloc or an elemental. Core/ViewModel.lua maps an
  -- id to one of these keys and the tree resolves it; a row whose source states no kind keeps
  -- CAT_DROPS exactly as it was.
  --
  -- No portrait and no model anywhere in this: a portrait costs a display id, an asynchronous
  -- load and a frame per row, and the owner asked for nothing that could make a list lag. These
  -- are the client's own icon files, drawn the way every other icon in this table is.
  --
  -- The eleven types are the hunter TRACKING glyphs, which is the art the game itself uses to
  -- mean "this kind of creature", plus the client's own critter, engineering, question mark and
  -- stoneclaw totem glyphs for the four with no tracking spell. Every path below was read out of
  -- ItemTree-Data/builds/1.60.1.69913/ManifestInterfaceData.csv, the client's own manifest of
  -- the files it ships, and the file id is in the comment so the claim can be checked: the
  -- addon names paths, because a path survives a build where a file id may be renumbered.
  CREATURE_BEAST = { kind = "texture", path = "Interface\\Icons\\Ability_Tracking" }, -- 132328
  CREATURE_DRAGONKIN = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Head_Dragon_01" }, -- 134153
  CREATURE_DEMON = { kind = "texture", path = "Interface\\Icons\\Spell_Shadow_SummonFelHunter" }, -- 136217
  CREATURE_ELEMENTAL = { kind = "texture", path = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" }, -- 135861
  CREATURE_GIANT = { kind = "texture", path = "Interface\\Icons\\Ability_Racial_Avatar" }, -- 132275
  CREATURE_UNDEAD = { kind = "texture", path = "Interface\\Icons\\Spell_Shadow_DarkSummoning" }, -- 136142
  CREATURE_HUMANOID = { kind = "texture", path = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" }, -- 135942
  CREATURE_CRITTER = { kind = "texture", path = "Interface\\Icons\\Icon_PetFamily_Critter" }, -- 618973
  CREATURE_MECHANICAL = { kind = "texture", path = "Interface\\Icons\\Trade_Engineering" }, -- 136243
  CREATURE_UNKNOWN = { kind = "texture", path = "Interface\\Icons\\INV_Misc_QuestionMark" }, -- 134400
  CREATURE_TOTEM = { kind = "texture", path = "Interface\\Icons\\Spell_Nature_StoneClawTotem" }, -- 136097
  -- The finer tier, for a beast: the hunter PET family glyphs, which are the very icons the
  -- build's own CreatureFamily rows point at (IconFileID), so a wolf wears the wolf the stable
  -- master draws. Seventeen families, which is every beast family the shipped table uses, each
  -- verified in the same manifest and each id matching the CreatureFamily row for it.
  CREATURE_FAMILY_WOLF = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Wolf" }, -- 132203
  CREATURE_FAMILY_CAT = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Cat" }, -- 132185
  CREATURE_FAMILY_SPIDER = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Spider" }, -- 132196
  CREATURE_FAMILY_BEAR = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Bear" }, -- 132183
  CREATURE_FAMILY_BOAR = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Boar" }, -- 132184
  CREATURE_FAMILY_CROCOLISK = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk" }, -- 132187
  CREATURE_FAMILY_CARRION_BIRD = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Vulture" }, -- 132200
  CREATURE_FAMILY_CRAB = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Crab" }, -- 132186
  CREATURE_FAMILY_GORILLA = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Gorilla" }, -- 132189
  CREATURE_FAMILY_RAPTOR = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Raptor" }, -- 132193
  -- 132198
  CREATURE_FAMILY_TALLSTRIDER = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_TallStrider" },
  CREATURE_FAMILY_SCORPID = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Scorpid" }, -- 132195
  CREATURE_FAMILY_TURTLE = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Turtle" }, -- 132199
  CREATURE_FAMILY_BAT = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Bat" }, -- 132182
  CREATURE_FAMILY_HYENA = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Hyena" }, -- 132190
  CREATURE_FAMILY_BIRD_OF_PREY = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_Owl" }, -- 132192
  -- 132202
  CREATURE_FAMILY_WIND_SERPENT = { kind = "texture", path = "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent" },
  -- The one demon family the table carries, and the one family whose own CreatureFamily
  -- IconFileID cannot be used: all four warlock families share 132115, which is the druid's cat
  -- form glyph, so a felhunter row would have drawn a cat. This is the warlock's own summon
  -- glyph instead, which is the same file the Demon type above draws and is verified in the same
  -- manifest. The other warlock families are not in this data and fall back to the type icon.
  CREATURE_FAMILY_FELHUNTER = { kind = "texture", path = "Interface\\Icons\\Spell_Shadow_SummonFelHunter" }, -- 136217
  -- Brief PR13: the Professions tab dressed in the client's own profession art. Every name below
  -- was read off github.com/Gethe/wow-ui-source, branch forever, and checked against
  -- UiTextureAtlasMember.csv of build 1.60.1.70009. The Forever client names its Camelot art
  -- with a "-c60" or "_c60" suffix and answers the plain name for it (the ProfessionsBook asks for
  -- "Profession-overview-Card" and draws profession-overview-card-c60), so each entry names the
  -- plain name the client code uses and lists the suffixed spelling in alts, which the tab asks
  -- for where the plain one answers nothing. A caller checks C_Texture.GetAtlasInfo first and falls
  -- back to its flat Theme colours where neither answers.
  --
  -- The recipe difficulty arrows: the orange triple, the yellow double and the green single the
  -- recipe list draws beside a recipe (Blizzard_ProfessionsTemplates/
  -- Blizzard_ProfessionsRecipeList.lua, skillUpAtlas), each 13 by 15.
  PROFESSION_SKILL_HIGH = { kind = "atlas", name = "Professions-Icon-Skill-High" },
  PROFESSION_SKILL_MEDIUM = { kind = "atlas", name = "Professions-Icon-Skill-Medium" },
  PROFESSION_SKILL_LOW = { kind = "atlas", name = "Professions-Icon-Skill-Low" },
  -- A recipe the player cannot learn yet, and the locked end of the rank bar: the group finder's
  -- padlock, the art CAT_REQUIREMENT already names, under a key of its own so the two can part.
  PROFESSION_LOCK = { kind = "texture", path = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK" },
  -- A gathering zone's row: a folded map with a compass rose (INV_Misc_Map02, fileDataID 237381
  -- in the 1.60.1.70009 manifest). The owner read CAT_ZONE's red crosses as a missing icon.
  PROFESSION_ZONE = { kind = "texture", path = "Interface\\Icons\\INV_Misc_Map02" },
  -- The rank bar: the Camelot ProfessionsBook's own frame and background
  -- (Blizzard_ProfessionsBook/Camelot/Blizzard_ProfessionsBookTemplates.xml, overrideBorderAtlas
  -- and overrideBackgroundAtlas on ProfessionsRankBarTemplate), 374 by 23 each, drawn in three
  -- slices so a wider bar keeps its end caps.
  PROFESSION_BAR_FRAME = {
    kind = "atlas",
    name = "Profession-ProgressBar-frame",
    alts = { "profession-progressbar-frame-c60", "Professions-skillbar-frame" },
    cap = 8,
  },
  PROFESSION_BAR_BG = {
    kind = "atlas",
    name = "Profession-ProgressBar-BG",
    alts = { "profession-progressbar-bg-c60", "Professions-skillbar-bg" },
    cap = 8,
  },
  -- The bar's fill, one per profession: "Skillbar_Fill_Flipbook_%s" with the Enum.Profession name
  -- (Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRankBar.lua, ProfessionsRankBarMixin
  -- Update). Each is a flipbook sheet, 2 columns of frames 34 high, so the tab draws the first
  -- frame alone (flipbook) rather than the whole sheet squeezed into the bar. DefaultBlue is the
  -- client's own fallback for a profession with no art of its own.
  PROFESSION_BAR_FILL_DEFAULT = {
    kind = "atlas",
    name = "Skillbar_Fill_Flipbook_DefaultBlue",
    flipbook = { columns = 2, frameH = 34 },
  },
  -- Brief PR16: the cards, the band headers and the Trainers & vendors panel are flat colour with
  -- a thin chamfered edge (UI\Skin.lua Skin.Card, FILL_WHITE8X8 tinted), no longer the
  -- ProfessionsBook card cut in nine (PROFESSION_CARD) or the tutorial callout glow
  -- (PROFESSION_GLOW_*): the owner found the bevel massive and the glow pixelated, and both blurred
  -- as the canvas zoomed in.
  -- Brief PR19: the Professions tab's thin border (UI\Skin.lua Skin.Border), on its cards, headers,
  -- Recommended tag, panels, queue tray and the rank bar's fallback frame: the eight pieces of the
  -- client's own TooltipDefaultLayout (Blizzard_SharedXML/Mainline/NineSliceLayouts.lua,
  -- wow-ui-source branch forever, line 257). Each is in UiTextureAtlasMember on 1.60.1.70009 at 7
  -- by 7 texels (the edges 16 long, 7 deep), and again as the Camelot art ending -c60 (file
  -- 8070606 and its pair), which alts names. A light bevel, tinted by the caller.
  PROFESSION_BORDER_TL = {
    kind = "atlas",
    name = "Tooltip-NineSlice-CornerTopLeft",
    alts = { "tooltip-nineslice-cornertopleft-c60" },
  },
  PROFESSION_BORDER_TR = {
    kind = "atlas",
    name = "Tooltip-NineSlice-CornerTopRight",
    alts = { "tooltip-nineslice-cornertopright-c60" },
  },
  PROFESSION_BORDER_BL = {
    kind = "atlas",
    name = "Tooltip-NineSlice-CornerBottomLeft",
    alts = { "tooltip-nineslice-cornerbottomleft-c60" },
  },
  PROFESSION_BORDER_BR = {
    kind = "atlas",
    name = "Tooltip-NineSlice-CornerBottomRight",
    alts = { "tooltip-nineslice-cornerbottomright-c60" },
  },
  PROFESSION_BORDER_TOP = {
    kind = "atlas",
    name = "_Tooltip-NineSlice-EdgeTop",
    alts = { "_tooltip-nineslice-edgetop-c60" },
  },
  PROFESSION_BORDER_BOTTOM = {
    kind = "atlas",
    name = "_Tooltip-NineSlice-EdgeBottom",
    alts = { "_tooltip-nineslice-edgebottom-c60" },
  },
  PROFESSION_BORDER_LEFT = {
    kind = "atlas",
    name = "!Tooltip-NineSlice-EdgeLeft",
    alts = { "!tooltip-nineslice-edgeleft-c60" },
  },
  PROFESSION_BORDER_RIGHT = {
    kind = "atlas",
    name = "!Tooltip-NineSlice-EdgeRight",
    alts = { "!tooltip-nineslice-edgeright-c60" },
  },
  -- Brief BL30: the eye on the map button at the right of a Boss loot place row and on each row
  -- of a zone's Map view item list (it replaced brief Z3's painted INV_Misc_Eye_01 there, key
  -- ICON_VIEW_ITEM, now gone). The owner wanted a flat one colour line eye in the Recent button's
  -- clock style, not a painted icon. The UI
  -- editor's eye is the whole of Interface\UIEditorIcons\UIEditorIcons.BLP (file 3151383, a 16
  -- by 16 sheet), a 14 by 14 atlas member on Forever 1.60.1.70009, 70058, 70094 and 70124. It is
  -- yellow in its own file (#FFD200, the clock's title gold), so it is drawn untinted. Classic
  -- Era 1.15.9 does not carry it, and the button falls back to ICON_VIEW_GO there.
  ICON_VIEW_FLAT = { kind = "atlas", name = "UI_Editor_Eye_Icon" },
  -- Brief BL30: the map button's fallback where ICON_VIEW_FLAT will not draw. The client's flat
  -- gold "go to" arrow (the owner's external link idea), 256 by 256 on both target builds.
  ICON_VIEW_GO = { kind = "atlas", name = "common-icon-forwardarrow" },
  -- Brief PR23: the head on the Professions tab's route arrow, the talent tree's own arrow head
  -- (Blizzard_SharedTalentUI/Blizzard_SharedTalentEdgeTemplates.xml, TalentEdgeArrowTemplate's
  -- ArrowHead, wow-ui-source branch forever). In UiTextureAtlasMember on 1.60.1.70009 (member
  -- 16122, 28 by 24 texels, drawn 14 by 12). It points down in its own art, so the pane turns it a
  -- quarter to point right, and it is the grey one so the route gold tint reads true. The pane
  -- keeps its old chevron (ICON_CHEVRON_EXPAND) where the client has no such atlas.
  PROFESSION_ROUTE_ARROW = { kind = "atlas", name = "talents-arrow-head-gray" },
  -- The owner, 2026-10-02: the grey head tinted gold reads dull brown, so the pane prefers the
  -- talent tree's yellow head (member 16124 on 1.60.1.70009, same 28 by 24 texels, drawn 14 by
  -- 12), desaturated and tinted the route gold so it matches the shaft; the grey one stays as the
  -- fallback.
  PROFESSION_ROUTE_ARROW_YELLOW = { kind = "atlas", name = "talents-arrow-head-yellow" },
  -- Brief PR36 (owner QA of PR35, 2026-10-02). Every name below was read off
  -- github.com/Gethe/wow-ui-source, branch forever, and checked against UiTextureAtlasElement,
  -- UiTextureAtlasMember, UiTextureAtlas and ManifestInterfaceData of build 1.60.1.70009.
  -- The craft queue's vendor shopping list card: the neutral player choice card's parchment with
  -- its own torn, burnt edges (Blizzard_PlayerChoice, "UI-Frame-%s-CardParchment"; element 7388,
  -- member 8124, 515 by 438 texels in Interface\FrameGeneral\UIFrameNeutral.BLP, file 2142239),
  -- drawn in nine pieces with slice texel corners (UI\Skin.lua Skin.NineSlice). The tray falls
  -- back to a warm flat card where it will not draw.
  PROFESSION_PARCHMENT = { kind = "atlas", name = "UI-Frame-Neutral-CardParchmentWider", slice = 48 },
  -- The craft queue's profession group strip: the dialog header's dark diamond plate metal
  -- (Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml, CenterBG; element 11478, member 9564,
  -- 128 by 156 texels in Interface\FrameGeneral\UIFrameDiamondMetalHeader2x.BLP, file 3058483;
  -- the Camelot copy, member 38792, has bronze rims), cut to its dark middle by crop (fractions of
  -- the atlas: left, right, top, bottom) so neither rim shows, tinted cool gunmetal.
  PROFESSION_METAL = { kind = "atlas", name = "_UI-Frame-DiamondMetal-Header-Tile", crop = { 0, 1, 0.27, 0.73 } },
  -- The craft queue's card at a band's end: the profession's own glyph in the talent tree's gold
  -- node ring (Blizzard_SharedTalentUI; element 19871, member 16034, 50 by 50 texels in
  -- Interface\TalentFrame\Talents.BLP, file 4556093), cut round by the talent node's circle mask
  -- (element 19936, member 16128, Interface\TalentFrame\TalentsMaskNodeCircle.BLP, file 4633068).
  PROFESSION_RING = { kind = "atlas", name = "talents-node-circle-yellow" },
  PROFESSION_RING_MASK = { kind = "atlas", name = "talents-node-circle-mask" },
  -- Brief LF1 (the owner's QA item 240c, 2026-10-18): the Professions canvas's floating hotkey
  -- panel, our own art in one 256 by 64 atlas, Art/hint-keys.tga, built by scripts/build-art.py
  -- (hint-keys step), which prints these coords. The mouse after the marketing animator's, with its
  -- wheel lit (zoom, and Shift + wheel) and with its left button lit (pan), 40 by 60 texels drawn 20
  -- by 30; a blank keycap the client writes "Shift" on, 64 by 40 drawn about 32 by 20; and three
  -- white action icons the pane tints, 24 by 24 drawn 12 by 12: a magnifier, four way arrows, an up
  -- and down arrow. All full colour apart from the icons, drawn untinted.
  PROFESSION_HINT_MOUSE_WHEEL = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 2 / 256, 42 / 256, 2 / 64, 62 / 64 },
    texW = 256,
    texH = 64,
  },
  PROFESSION_HINT_MOUSE_LEFT = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 46 / 256, 86 / 256, 2 / 64, 62 / 64 },
    texW = 256,
    texH = 64,
  },
  PROFESSION_HINT_KEYCAP = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 90 / 256, 154 / 256, 2 / 64, 42 / 64 },
    texW = 256,
    texH = 64,
  },
  PROFESSION_HINT_ZOOM = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 158 / 256, 182 / 256, 2 / 64, 26 / 64 },
    texW = 256,
    texH = 64,
  },
  PROFESSION_HINT_PAN = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 186 / 256, 210 / 256, 2 / 64, 26 / 64 },
    texW = 256,
    texH = 64,
  },
  PROFESSION_HINT_SCROLL = {
    kind = "addon",
    path = "Interface\\AddOns\\ItemTree\\Art\\hint-keys",
    coords = { 214 / 256, 238 / 256, 2 / 64, 26 / 64 },
    texW = 256,
    texH = 64,
  },
}

-- Brief PR13: each profession's own rank bar fill, by skill line, and the Enum.Profession name
-- (ProfessionConstantsDocumentation.lua, branch forever) the client builds the atlas name from.
-- Built into Assets.table below so every fill is a key like any other.
Assets.professionBarKits = {
  [129] = "FirstAid",
  [164] = "Blacksmithing",
  [165] = "Leatherworking",
  [171] = "Alchemy",
  [182] = "Herbalism",
  [185] = "Cooking",
  [186] = "Mining",
  [197] = "Tailoring",
  [202] = "Engineering",
  [333] = "Enchanting",
  [356] = "Fishing",
  [393] = "Skinning",
}
Assets.professionBars = {}
for line, kit in pairs(Assets.professionBarKits) do
  local key = "PROFESSION_BAR_FILL_" .. kit:upper()
  local lower = kit:lower()
  Assets.table[key] = {
    kind = "atlas",
    name = "Skillbar_Fill_Flipbook_" .. kit,
    alts = { "skillbar_fill_flipbook_" .. lower .. "_c60" },
    flipbook = { columns = 2, frameH = 34 },
  }
  Assets.professionBars[line] = key
end

--- Brief PR13: the rank bar fill key for a skill line, DefaultBlue where it has none. Pure.
function Assets.ForProfessionBar(skillLine)
  return Assets.professionBars[tonumber(skillLine)] or "PROFESSION_BAR_FILL_DEFAULT"
end

-- Skill line id to category glyph, for sidebar and category rows.
-- Vertex colours an entry's `tint` can name, as { r, g, b } from 0 to 1. BADGE_SOD_TINT is the
-- epic quality purple (#A335EE, ITEMTREE_COLOR_QUALITY_EPIC): the Season of Discovery fallback
-- star (BADGE_SOD) is drawn in it where the client will not draw the BADGE_ART_SOD medallion.
Assets.BADGE_SOD_TINT = { r = 0.64, g = 0.21, b = 0.93 }

-- Brief E80: the badges in Forever's colours. These five are the owner's to tune by eye in the
-- client; nothing else needs to change when one moves, except the Theme token that mirrors it
-- (UI/Theme.lua, the semantic block), which tests/spec/ui_theme_spec.lua holds equal to it.
--   BADGE_NEW_TINT        the New star (the fallback where the medallion will not draw) and
--                         its ring, in a silver blue from the World of Warcraft Forever
--                         logo, a touch lighter so it reads as silver on the dark panes. The New
--                         medallion itself carries its own colour and is drawn untinted (brief
--                         A1). Mirrored by ITEMTREE_COLOR_SEMANTIC_NEW (#78B8F5). The quest wash
--                         follows New: ITEMTREE_COLOR_QUEST_WASH is the same colour (brief Q6).
--   BADGE_NOTE_TINT       the Community note "i", desaturated then drawn in this light silver,
--                         apart from the Unverified grey (#8C8C8C) and from New. Mirrored by
--                         ITEMTREE_COLOR_SEMANTIC_NOTE (#CCD4E0).
--   BADGE_PREDICTED_TOP   the crystal ball's vertical gradient, teal at the top (#2EC4B5) ...
--   BADGE_PREDICTED_BOTTOM ... to green at the bottom (#3DBF5C). The top end is the flat colour a
--                         client with no gradient call gets, and ITEMTREE_COLOR_SEMANTIC_PREDICTED
--                         is the same teal at its own alpha.
-- A vertex colour multiplies the art, so a desaturated medallion comes out darker than the tint
-- itself; lighten a tint here rather than reaching for the art.
Assets.BADGE_NEW_TINT = { r = 0.47, g = 0.72, b = 0.96 }
Assets.BADGE_NOTE_TINT = { r = 0.80, g = 0.83, b = 0.88 }
Assets.BADGE_PREDICTED_TOP = { r = 0.18, g = 0.77, b = 0.71 }
Assets.BADGE_PREDICTED_BOTTOM = { r = 0.24, g = 0.75, b = 0.36 }
-- Brief GS3: the sixth knob, the guess colour, the owner's muted rose (#E08FB0, 2026-09-27). The
-- guess badge draws its own medallion, the three dice (BADGE_ART_GUESS, brief A3), and where that
-- will not draw it falls back to the composed form: the shared backing, its ring in this colour,
-- and BADGE_GUESS, a smaller ring in it. Never the question mark, which is the undiscovered
-- corner mark. Mirrored by
-- ITEMTREE_COLOR_SEMANTIC_GUESS, which the rate column of a guessed row is written in.
Assets.BADGE_GUESS_TINT = { r = 224 / 255, g = 143 / 255, b = 176 / 255 }

-- Brief BQ30 addendum (the owner's rulings of 2026-10-10, QA item 92): the [Equip] pills with the
-- specs they are for INSIDE, "Equip (BM, MM)", one label in one font, the pill as wide as its label.
-- scripts/build-art.py equip-tags draws every label the addon can show (Gear.SPEC_SHORT's
-- combinations and "Any spec", brief EQ2's words for "Any") into Art/equip-tags.tga and writes the
-- rects below: label to { key, rect = { left, top, width, height } } in pixels of the 1024 by 512
-- atlas. The small tag set alone (body 34 px high): every tag row is drawn at Keep.TAG_SIZE, inside
-- SMALL_ART_MAX. Each becomes an Assets entry shaped like TAG_EQUIP's small art (Keep.EquipTagKey
-- names it).
Assets.EQUIP_TAG_PATH = "Interface\\AddOns\\ItemTree\\Art\\equip-tags"
Assets.EQUIP_TAG_W = 1024
Assets.EQUIP_TAG_H = 512
-- BEGIN equip-tags (written by scripts/build-art.py equip-tags; do not edit by hand)
Assets.EQUIP_TAG_RECTS = {
  ["Any spec"] = { key = "TAG_EQUIP_ANY_SPEC", rect = { 242, 230, 234, 34 } },
  ["Arms"] = { key = "TAG_EQUIP_ARMS", rect = { 200, 344, 192, 34 } },
  ["Fury"] = { key = "TAG_EQUIP_FURY", rect = { 190, 382, 182, 34 } },
  ["Arms, Fury"] = { key = "TAG_EQUIP_ARMS_FURY", rect = { 262, 116, 252, 34 } },
  ["Prot"] = { key = "TAG_EQUIP_PROT", rect = { 746, 382, 178, 34 } },
  ["Arms, Prot"] = { key = "TAG_EQUIP_ARMS_PROT", rect = { 518, 116, 248, 34 } },
  ["Fury, Prot"] = { key = "TAG_EQUIP_FURY_PROT", rect = { 246, 192, 238, 34 } },
  ["Holy"] = { key = "TAG_EQUIP_HOLY", rect = { 376, 382, 182, 34 } },
  ["Holy, Prot"] = { key = "TAG_EQUIP_HOLY_PROT", rect = { 488, 192, 238, 34 } },
  ["Ret"] = { key = "TAG_EQUIP_RET", rect = { 854, 306, 168, 34 } },
  ["Holy, Ret"] = { key = "TAG_EQUIP_HOLY_RET", rect = { 2, 268, 230, 34 } },
  ["Prot, Ret"] = { key = "TAG_EQUIP_PROT_RET", rect = { 236, 268, 224, 34 } },
  ["BM"] = { key = "TAG_EQUIP_BM", rect = { 716, 420, 168, 34 } },
  ["MM"] = { key = "TAG_EQUIP_MM", rect = { 182, 420, 174, 34 } },
  ["BM, MM"] = { key = "TAG_EQUIP_BM_MM", rect = { 464, 268, 222, 34 } },
  ["Surv"] = { key = "TAG_EQUIP_SURV", rect = { 2, 382, 184, 34 } },
  ["BM, Surv"] = { key = "TAG_EQUIP_BM_SURV", rect = { 480, 230, 232, 34 } },
  ["MM, Surv"] = { key = "TAG_EQUIP_MM_SURV", rect = { 2, 230, 236, 34 } },
  ["Assa"] = { key = "TAG_EQUIP_ASSA", rect = { 396, 344, 188, 34 } },
  ["Combat"] = { key = "TAG_EQUIP_COMBAT", rect = { 2, 306, 218, 34 } },
  ["Assa, Combat"] = { key = "TAG_EQUIP_ASSA_COMBAT", rect = { 310, 2, 284, 34 } },
  ["Sub"] = { key = "TAG_EQUIP_SUB", rect = { 2, 420, 176, 34 } },
  ["Assa, Sub"] = { key = "TAG_EQUIP_ASSA_SUB", rect = { 498, 154, 240, 34 } },
  ["Combat, Sub"] = { key = "TAG_EQUIP_COMBAT_SUB", rect = { 2, 78, 272, 34 } },
  ["Disc"] = { key = "TAG_EQUIP_DISC", rect = { 562, 382, 180, 34 } },
  ["Disc, Holy"] = { key = "TAG_EQUIP_DISC_HOLY", rect = { 252, 154, 242, 34 } },
  ["Shadow"] = { key = "TAG_EQUIP_SHADOW", rect = { 690, 268, 220, 34 } },
  ["Disc, Shadow"] = { key = "TAG_EQUIP_DISC_SHADOW", rect = { 598, 2, 280, 34 } },
  ["Holy, Shadow"] = { key = "TAG_EQUIP_HOLY_SHADOW", rect = { 2, 40, 280, 34 } },
  ["Ele"] = { key = "TAG_EQUIP_ELE", rect = { 2, 458, 166, 34 } },
  ["Enh"] = { key = "TAG_EQUIP_ENH", rect = { 360, 420, 174, 34 } },
  ["Ele, Enh"] = { key = "TAG_EQUIP_ELE_ENH", rect = { 224, 306, 218, 34 } },
  ["Resto"] = { key = "TAG_EQUIP_RESTO", rect = { 2, 344, 194, 34 } },
  ["Ele, Resto"] = { key = "TAG_EQUIP_ELE_RESTO", rect = { 730, 192, 238, 34 } },
  ["Enh, Resto"] = { key = "TAG_EQUIP_ENH_RESTO", rect = { 770, 116, 246, 34 } },
  ["Arcane"] = { key = "TAG_EQUIP_ARCANE", rect = { 808, 78, 212, 34 } },
  ["Fire"] = { key = "TAG_EQUIP_FIRE", rect = { 538, 420, 174, 34 } },
  ["Arcane, Fire"] = { key = "TAG_EQUIP_ARCANE_FIRE", rect = { 278, 78, 264, 34 } },
  ["Frost"] = { key = "TAG_EQUIP_FROST", rect = { 588, 344, 188, 34 } },
  ["Arcane, Frost"] = { key = "TAG_EQUIP_ARCANE_FROST", rect = { 286, 40, 278, 34 } },
  ["Fire, Frost"] = { key = "TAG_EQUIP_FIRE_FROST", rect = { 742, 154, 240, 34 } },
  ["Affl"] = { key = "TAG_EQUIP_AFFL", rect = { 850, 40, 172, 34 } },
  ["Demo"] = { key = "TAG_EQUIP_DEMO", rect = { 654, 306, 196, 34 } },
  ["Affl, Demo"] = { key = "TAG_EQUIP_AFFL_DEMO", rect = { 2, 154, 246, 34 } },
  ["Destro"] = { key = "TAG_EQUIP_DESTRO", rect = { 446, 306, 204, 34 } },
  ["Affl, Destro"] = { key = "TAG_EQUIP_AFFL_DESTRO", rect = { 2, 116, 256, 34 } },
  ["Demo, Destro"] = { key = "TAG_EQUIP_DEMO_DESTRO", rect = { 568, 40, 278, 34 } },
  ["Bal"] = { key = "TAG_EQUIP_BAL", rect = { 172, 458, 166, 34 } },
  ["Feral"] = { key = "TAG_EQUIP_FERAL", rect = { 780, 344, 186, 34 } },
  ["Bal, Feral"] = { key = "TAG_EQUIP_BAL_FERAL", rect = { 716, 230, 232, 34 } },
  ["Bal, Resto"] = { key = "TAG_EQUIP_BAL_RESTO", rect = { 2, 192, 240, 34 } },
  ["Feral, Resto"] = { key = "TAG_EQUIP_FERAL_RESTO", rect = { 546, 78, 258, 34 } },
  ["Bal, Feral, Resto"] = { key = "TAG_EQUIP_BAL_FERAL_RESTO", rect = { 2, 2, 304, 34 } },
}
-- END equip-tags

-- One equip pill's entry from its rect { left, top, width, height }. Pure.
function Assets.EquipTagEntry(rect)
  local w, h = Assets.EQUIP_TAG_W, Assets.EQUIP_TAG_H
  return {
    kind = "addon",
    path = Assets.EQUIP_TAG_PATH,
    coords = { rect[1] / w, (rect[1] + rect[3]) / w, rect[2] / h, (rect[2] + rect[4]) / h },
    texW = w,
    texH = h,
    width = rect[3],
    height = rect[4],
  }
end

for _, rects in pairs(Assets.EQUIP_TAG_RECTS) do
  Assets.table[rects.key] = Assets.EquipTagEntry(rects.rect)
end

-- Brief FN2c (QA item 371, the owner 2026-10-21: "make a second keep tag with the right hand corners
-- cut off (i.e. straight edge) and then build the others on the left and just have one for each number
-- up to 99+"): the counted Keep tag, one pill in two segments, [lock Keep | 51] (Core/Keep.lua
-- Keep.TagRow). TAG_KEEP_SEGMENT is the small Keep tag with a square right edge; TAG_KEEP_COUNT_1 to
-- TAG_KEEP_COUNT_99 and TAG_KEEP_COUNT_99_PLUS are the number segments, a square left edge with a dark
-- divider down it, the number in Inter's tabular figures. White and greys, tinted the Keep colour, the
-- small tag set alone (body 34 px high) as the Equip pills. scripts/build-art.py keep-count draws them
-- into their own 512 by 512 atlas and writes the rects below: key to { left, top, width, height } in
-- pixels of the atlas.
Assets.KEEP_COUNT_PATH = "Interface\\AddOns\\ItemTree\\Art\\keep-count"
Assets.KEEP_COUNT_W = 512
Assets.KEEP_COUNT_H = 512
-- BEGIN keep-count (written by scripts/build-art.py keep-count; do not edit by hand)
Assets.KEEP_COUNT_RECTS = {
  { key = "TAG_KEEP_SEGMENT", rect = { 2, 2, 96, 34 } },
  { key = "TAG_KEEP_COUNT_1", rect = { 102, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_2", rect = { 140, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_3", rect = { 178, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_4", rect = { 216, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_5", rect = { 254, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_6", rect = { 292, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_7", rect = { 330, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_8", rect = { 368, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_9", rect = { 406, 2, 34, 34 } },
  { key = "TAG_KEEP_COUNT_10", rect = { 444, 2, 48, 34 } },
  { key = "TAG_KEEP_COUNT_11", rect = { 2, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_12", rect = { 54, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_13", rect = { 106, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_14", rect = { 158, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_15", rect = { 210, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_16", rect = { 262, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_17", rect = { 314, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_18", rect = { 366, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_19", rect = { 418, 40, 48, 34 } },
  { key = "TAG_KEEP_COUNT_20", rect = { 2, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_21", rect = { 54, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_22", rect = { 106, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_23", rect = { 158, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_24", rect = { 210, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_25", rect = { 262, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_26", rect = { 314, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_27", rect = { 366, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_28", rect = { 418, 78, 48, 34 } },
  { key = "TAG_KEEP_COUNT_29", rect = { 2, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_30", rect = { 54, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_31", rect = { 106, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_32", rect = { 158, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_33", rect = { 210, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_34", rect = { 262, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_35", rect = { 314, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_36", rect = { 366, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_37", rect = { 418, 116, 48, 34 } },
  { key = "TAG_KEEP_COUNT_38", rect = { 2, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_39", rect = { 54, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_40", rect = { 106, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_41", rect = { 158, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_42", rect = { 210, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_43", rect = { 262, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_44", rect = { 314, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_45", rect = { 366, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_46", rect = { 418, 154, 48, 34 } },
  { key = "TAG_KEEP_COUNT_47", rect = { 2, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_48", rect = { 54, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_49", rect = { 106, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_50", rect = { 158, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_51", rect = { 210, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_52", rect = { 262, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_53", rect = { 314, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_54", rect = { 366, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_55", rect = { 418, 192, 48, 34 } },
  { key = "TAG_KEEP_COUNT_56", rect = { 2, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_57", rect = { 54, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_58", rect = { 106, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_59", rect = { 158, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_60", rect = { 210, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_61", rect = { 262, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_62", rect = { 314, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_63", rect = { 366, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_64", rect = { 418, 230, 48, 34 } },
  { key = "TAG_KEEP_COUNT_65", rect = { 2, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_66", rect = { 54, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_67", rect = { 106, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_68", rect = { 158, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_69", rect = { 210, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_70", rect = { 262, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_71", rect = { 314, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_72", rect = { 366, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_73", rect = { 418, 268, 48, 34 } },
  { key = "TAG_KEEP_COUNT_74", rect = { 2, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_75", rect = { 54, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_76", rect = { 106, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_77", rect = { 158, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_78", rect = { 210, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_79", rect = { 262, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_80", rect = { 314, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_81", rect = { 366, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_82", rect = { 418, 306, 48, 34 } },
  { key = "TAG_KEEP_COUNT_83", rect = { 2, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_84", rect = { 54, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_85", rect = { 106, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_86", rect = { 158, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_87", rect = { 210, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_88", rect = { 262, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_89", rect = { 314, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_90", rect = { 366, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_91", rect = { 418, 344, 48, 34 } },
  { key = "TAG_KEEP_COUNT_92", rect = { 2, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_93", rect = { 54, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_94", rect = { 106, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_95", rect = { 158, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_96", rect = { 210, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_97", rect = { 262, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_98", rect = { 314, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_99", rect = { 366, 382, 48, 34 } },
  { key = "TAG_KEEP_COUNT_99_PLUS", rect = { 418, 382, 62, 34 } },
}
-- END keep-count

-- One counted Keep segment's entry from its rect { left, top, width, height }, shaped like an Equip
-- pill's. Pure.
function Assets.KeepCountEntry(rect)
  local w, h = Assets.KEEP_COUNT_W, Assets.KEEP_COUNT_H
  return {
    kind = "addon",
    path = Assets.KEEP_COUNT_PATH,
    coords = { rect[1] / w, (rect[1] + rect[3]) / w, rect[2] / h, (rect[2] + rect[4]) / h },
    texW = w,
    texH = h,
    width = rect[3],
    height = rect[4],
  }
end

for _, piece in ipairs(Assets.KEEP_COUNT_RECTS) do
  Assets.table[piece.key] = Assets.KeepCountEntry(piece.rect)
end

-- The vertex colour an entry is drawn in, or nil for an entry drawn in its own colours. Pure.
function Assets.Tint(key)
  local entry = Assets.table[key]
  local name = entry and entry.tint or key
  local tint = type(name) == "string" and Assets[name] or nil
  if type(tint) ~= "table" or not (tonumber(tint.r) and tonumber(tint.g) and tonumber(tint.b)) then
    return nil
  end
  return tint
end

Assets.skillGlyphs = {
  [171] = "CAT_ALCHEMY",
  [164] = "CAT_BLACKSMITHING",
  [202] = "CAT_ENGINEERING",
  [333] = "CAT_ENCHANTING",
  [197] = "CAT_TAILORING",
  [165] = "CAT_LEATHERWORKING",
  [186] = "CAT_MINING",
  [182] = "CAT_HERBALISM",
  [393] = "CAT_SKINNING",
  [356] = "CAT_FISHING",
  [185] = "CAT_COOKING",
  [129] = "CAT_FIRSTAID",
}

function Assets.Get(key)
  local entry = Assets.table[key]
  if not entry then
    error("unknown asset key " .. tostring(key), 2)
  end
  return entry
end

function Assets.Has(key)
  return Assets.table[key] ~= nil
end

function Assets.ForSkill(skillId)
  return Assets.skillGlyphs[skillId] or "CAT_NOTE"
end

-- How wide a key's artwork is for its height, as a plain number: 2 means twice as wide as it
-- is tall. An entry that crops its canvas says so in coords and states that canvas in texW and
-- texH, and those four numbers are the only place the shape of the artwork is written down; an
-- entry with no crop fills its own canvas and reads as square, which is what every caller drawing
-- into a square box wants. The window's top tabs ask, so a wide glyph like the trade window's
-- chain is drawn at its own shape inside the 16px box rather than stretched to fill it. Pure.
function Assets.Aspect(key)
  local entry = Assets.Get(key)
  local coords, texW, texH = entry.coords, tonumber(entry.texW), tonumber(entry.texH)
  if type(coords) ~= "table" or not texW or not texH then
    return 1
  end
  local width = (tonumber(coords[2]) or 0) - (tonumber(coords[1]) or 0)
  local height = (tonumber(coords[4]) or 0) - (tonumber(coords[3]) or 0)
  width, height = width * texW, height * texH
  if width <= 0 or height <= 0 then
    return 1
  end
  return width / height
end

-- Brief P6b: the key each side number wears, as the shipped Classic Era table numbers them (cf): 1
-- Alliance, 2 Horde, 3 both sides, which the window calls neutral.
Assets.SIDES = { [1] = "SIDE_ALLIANCE", [2] = "SIDE_HORDE", [3] = "SIDE_NEUTRAL" }

-- Sorted keys, for the harness missing-asset report and for tests.
function Assets.Keys()
  local keys = {}
  for key in pairs(Assets.table) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- The inline texture escape for a key, for text the client renders itself: a tooltip line,
-- a FontString, a chat message. Pure, so specs cover it with no client API at all.
--   atlas entries          "|A:name:size:size|a"
--   everything else        "|Tpath:size:size|t"
--   entries with coords and a stated canvas size (texW, texH)
--                          "|Tpath:h:w:0:0:texW:texH:left:right:top:bottom|t"
--   entries with a tint    "|Tpath:h:w:0:0:texW:texH:left:right:top:bottom:r:g:b|t"
-- The coords form crops the canvas down to the artwork, which is what LOGO needs. A tinted
-- entry takes the long form because the colour is only read after the crop, and an entry with
-- no crop states its whole canvas as 64 by 64 (the crop is a ratio, so the number only has to
-- agree with itself); r, g and b are 0 to 255. size is one side in pixels; the escape is square
-- (brief TB13: unless the entry states its own width and height, when size is the height and the
-- width follows the shape), so a wide asset like LOGO wants its own texture rather than markup. A
-- size below 1 is clamped to 1, because the client reads 0 as "use the line height" and that is
-- never what a caller asking for a size meant.
-- Brief K24a: tint, optional, is a colour for this one call, { r = , g = , b = } or { r, g, b }, each
-- 0 to 1 (clamped); it takes the place of the entry's own Assets.Tint. Anything else, nil included,
-- leaves the entry's own tint (or none) as before.
local function callTint(tint)
  if type(tint) ~= "table" then
    return nil
  end
  local r, g, b = tonumber(tint.r or tint[1]), tonumber(tint.g or tint[2]), tonumber(tint.b or tint[3])
  if not (r and g and b) then
    return nil
  end
  local function clamp(value)
    return math.max(0, math.min(1, value))
  end
  return { r = clamp(r), g = clamp(g), b = clamp(b) }
end

-- Brief K24c: an entry carrying a small variant (the action tags) draws it at this size or less, and
-- its large art above that. The tooltip draws the tags at 17, from small art exactly twice that high.
Assets.SMALL_ART_MAX = 24
-- Brief K24c: the vertical offset written into the escape of an entry with an outset (the legendary
-- Auction tag, whose rim makes it taller than the line's other tags), in pixels, positive up. 0 until
-- the owner has seen it on a tooltip line.
Assets.OUTSET_Y_OFFSET = 0

function Assets.Markup(key, size, tintArg)
  local entry = Assets.Get(key)
  local pixels = math.floor(tonumber(size) or 0)
  if pixels < 1 then
    pixels = 1
  end
  -- Brief K24c: the small variant's crop, shape and outset in place of the entry's own, at small sizes.
  local art = entry
  if type(entry.small) == "table" and pixels <= Assets.SMALL_ART_MAX then
    art = entry.small
  end
  -- Brief TB13: an entry stating its own width and height keeps that shape, size high and its
  -- width following; every other entry is square as before. The escape is height, then width.
  -- Brief K24c: size is the height of the BODY; an outset (rim over body height) draws the whole
  -- rect taller and wider by the rim on every side, so the body matches a normal tag's.
  local wide = pixels
  local width, height = tonumber(art.width), tonumber(art.height)
  local outset = tonumber(art.outset) or 0
  local yOffset = 0
  if width and height and width > 0 and height > 0 then
    local tall = pixels
    if outset > 0 then
      tall = pixels * (1 + 2 * outset)
      pixels = math.max(1, math.floor(tall + 0.5))
      yOffset = Assets.OUTSET_Y_OFFSET
    end
    wide = math.max(1, math.floor(tall * width / height + 0.5))
  end
  if entry.kind == "atlas" then
    return string.format("|A:%s:%d:%d|a", entry.name, pixels, wide)
  end
  local path = entry.path
  if entry.kind == "fdid" then
    path = tostring(entry.id)
  end
  local coords = art.coords or entry.coords
  local tint = callTint(tintArg) or Assets.Tint(key)
  if tint then
    local texW, texH = entry.texW or 64, entry.texH or 64
    local rect = coords or { 0, 1, 0, 1 }
    return string.format(
      "|T%s:%d:%d:0:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d|t",
      path,
      pixels,
      wide,
      yOffset,
      texW,
      texH,
      math.floor(rect[1] * texW + 0.5),
      math.floor(rect[2] * texW + 0.5),
      math.floor(rect[3] * texH + 0.5),
      math.floor(rect[4] * texH + 0.5),
      math.floor(tint.r * 255 + 0.5),
      math.floor(tint.g * 255 + 0.5),
      math.floor(tint.b * 255 + 0.5)
    )
  end
  if coords and entry.texW and entry.texH then
    return string.format(
      "|T%s:%d:%d:0:%d:%d:%d:%d:%d:%d:%d|t",
      path,
      pixels,
      wide,
      yOffset,
      entry.texW,
      entry.texH,
      math.floor(coords[1] * entry.texW + 0.5),
      math.floor(coords[2] * entry.texW + 0.5),
      math.floor(coords[3] * entry.texH + 0.5),
      math.floor(coords[4] * entry.texH + 0.5)
    )
  end
  return string.format("|T%s:%d:%d|t", path, pixels, wide)
end

-- Brief TV2 (QA item 347, across-5): a clear inline escape width units wide and one high, the
-- TOOLTIP_INDENT corner stretched, which leads a wrapped tooltip line's continued lines so they start
-- under the first line's words (UI/Tooltip.lua Tooltip.WrapText). Markup's escapes are square or keep
-- an entry's own shape; this one takes any width, rounded to a whole unit. "" for a width under half a
-- unit. Pure.
function Assets.Spacer(width)
  local units = math.floor((tonumber(width) or 0) + 0.5)
  if units < 1 then
    return ""
  end
  local entry = Assets.Get("TOOLTIP_INDENT")
  local coords, texW, texH = entry.coords, entry.texW, entry.texH
  return string.format(
    "|T%s:1:%d:0:0:%d:%d:%d:%d:%d:%d|t",
    entry.path,
    units,
    texW,
    texH,
    math.floor(coords[1] * texW + 0.5),
    math.floor(coords[2] * texW + 0.5),
    math.floor(coords[3] * texH + 0.5),
    math.floor(coords[4] * texH + 0.5)
  )
end

-- Applies an asset to a Texture object. In the client only; returns false when the
-- texture could not be set so callers can fall back (missing addon art, unknown atlas).
-- Addon art and client textures take the same branch, so coords narrow either of them to a
-- rect: that is how LOGO draws its artwork without the transparent padding of its canvas. An
-- entry with a tint puts its vertex colour on the texture as well (BADGE_SOD, BADGE_NEW).
function Assets.Apply(texture, key, useAtlasSize)
  local entry = Assets.Get(key)
  local ok
  if entry.kind == "atlas" then
    ok = texture:SetAtlas(entry.name, useAtlasSize)
  elseif entry.kind == "fdid" then
    ok = texture:SetTexture(entry.id)
  else
    ok = texture:SetTexture(entry.path)
    if entry.coords then
      texture:SetTexCoord(entry.coords[1], entry.coords[2], entry.coords[3], entry.coords[4])
    end
  end
  local tint = entry.tint and Assets.Tint(key) or nil
  if tint and ok ~= false and type(texture.SetVertexColor) == "function" then
    pcall(texture.SetVertexColor, texture, tint.r, tint.g, tint.b)
  end
  return ok ~= false
end

-- One client icon lookup under pcall: the icon, or nil where the call is missing, raises or
-- answers nothing. pick chooses which return is the icon (GetItemInfoInstant's is the fifth).
local function clientIcon(fn, itemId, pick)
  if type(fn) ~= "function" then
    return nil
  end
  local answer = { pcall(fn, itemId) }
  if not answer[1] then
    return nil
  end
  local icon = answer[(pick or 1) + 1]
  if icon == nil or icon == "" or icon == 0 then
    return nil
  end
  return icon
end

-- Item icons come from the generated data (fileDataID) and fall back to the client's own
-- lookups, then to the question mark. The beta is retail shaped, so C_Item.GetItemIconByID is
-- asked first among the client calls, then GetItemInfoInstant's icon, then the legacy global
-- GetItemIcon, each under pcall. All three are local reads of what the client already holds and
-- send nothing to the server. This is what gives a withheld item's page the icon the client has
-- for it, the way the tooltip already does (brief D5).
function Assets.ItemIcon(itemId)
  local data = ItemTree.Data
  -- Brief U3: Data:PeekItem is Data:GetItem once the item rows are loaded and never loads them,
  -- so an icon asked for at login comes from the client below instead.
  local read = type(data) == "table" and (data.PeekItem or data.GetItem) or nil
  if type(read) == "function" then
    local ok, item = pcall(read, data, itemId)
    if ok and type(item) == "table" and item.i then
      return item.i
    end
  end
  local itemApi = rawget(_G, "C_Item")
  local icon = type(itemApi) == "table" and clientIcon(itemApi.GetItemIconByID, itemId) or nil
  icon = icon or clientIcon(rawget(_G, "GetItemInfoInstant"), itemId, 5)
  icon = icon or clientIcon(rawget(_G, "GetItemIcon"), itemId)
  if icon then
    return icon
  end
  return Assets.table.ICON_QUESTIONMARK.path
end

return Assets
