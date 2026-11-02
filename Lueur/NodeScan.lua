-- Lueur : filons et plantes sur la minimap
-- Avec le pistage des plantes ou des minerais, le jeu pose sur la minimap un point par nœud,
-- tous pareils. Lueur met à la place de chacun l'icône de ce qu'il donne, dans un anneau dont la
-- couleur dit ce qu'il vaut pour la compétence du joueur, et grisée s'il est dans une grotte
-- (Nodes.lua sait ce qu'est un nœud).
--
-- Le jeu ne dit pas à un addon où sont ces points. Il répond en revanche à une souris fictive
-- promenée sur la minimap (Minimap:SetUsingSoftCursor, Minimap:UpdateMouseoverAtPoint, en pixels
-- d'écran) par ce que son infobulle dirait là (C_TooltipInfo.GetMinimapMouseover) : le nom des
-- points qui s'y trouvent, en gris pour un nœud dans une grotte. Un point répond dans un disque
-- autour de lui, d'une dizaine à une vingtaine d'unités de rayon selon le point. D'où le balayage,
-- quelques dizaines de points de grille par image :
--   1. la grille : les points voisins qui ont répondu le même nom forment un groupe ;
--   2. un groupe rond est un nœud, quel que soit son rayon, dont le centre se trouve en cherchant
--      ses bords par dichotomie ;
--   3. un groupe allongé, ou que le bord de la minimap tronque, est regardé de plus près : ses
--      nœuds sont les centres des cercles que son contour dessine, chacun de son rayon.
-- Chaque nœud trouvé est rangé par sa place sur la carte de la zone : entre deux balayages son
-- icône suit ainsi le joueur image par image. Un nœud déjà placé garde sa place tant que les
-- balayages le retrouvent là : seule la grille est refaite à chaque fois.
--
-- Un nœud connu reste le même d'un balayage à l'autre (Finish) : il garde son icône, ne change de
-- place que pour une mesure meilleure que la sienne, y glisse au lieu d'y sauter, et ne s'en va
-- qu'au second balayage qui ne le retrouve pas. Son icône suit le joueur entre deux pixels, comme
-- les points du jeu, paraît et s'efface en fondu, et s'estompe au bord de la minimap.
--
-- Ce fichier a son propre cadre et ses propres événements. Il lit les réglages par ns.GetOption
-- et n'est connu de Lueur.lua que par des crochets gardés : ns.UpdateNodes, ns.NodesFailure,
-- ns.ScanReport. Vu en jeu le 2026-10-13, deux fois : les icônes se posent sur les points.

local ADDON_NAME, ns = ...
local L = ns.L
local SafeCall, IsSecret = ns.SafeCall, ns.IsSecret
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local STEP = 10           -- unités de minimap entre deux points de la grille
local FINE = 3            -- et entre deux points du regard de près
local PER_FRAME = 60      -- points essayés par image
local WAIT = 0.75         -- secondes entre deux balayages
local MAX_SLOW = 8        -- à l'arrêt, sans rien de neuf, l'attente s'allonge jusqu'à ce multiple
local IDLE_WAIT = 5       -- sans pistage actif : on regarde de loin en loin s'il y en a un
local SWITCH_WAIT = 1     -- après un changement de pistage, le temps que les points du jeu suivent
local SWITCH_RETRY = 1.5  -- secondes au bout desquelles une bascule que le jeu n'a pas faite est redemandée
local SWITCH_TRIES = 3    -- demandes d'une même bascule, la première comprise
local SWITCH_SETTLE = 0.6 -- secondes après un changement de pistage avant lesquelles rien n'est balayé : les points du jeu changent un instant après lui
local SWITCH_POLL = 0.5   -- entre deux pistages, le temps d'un sort : on regarde de nouveau sous peu
local MAX_ICONS = 40
local MAX_FINE = 1000     -- points du regard de près par balayage, sauf pour le premier groupe s'il en demande plus ; au-delà, un groupe garde son centre
local MAX_DISCS = 6       -- nœuds cherchés dans un groupe
local MIN_VOTES = 6       -- points de contour qu'un cercle doit expliquer pour compter
local MIN_LOOSE = 5       -- points d'un groupe qu'aucun nœud trouvé n'explique : ce qu'un nœud de plus doit en expliquer, et à partir de quoi il en manque un
local TOLERANCE = 2       -- écart admis entre un point de contour et son cercle (unités)
local AHEAD, WIDE = 1.75, 3.75  -- le point du regard de près le plus proche d'un centre en est à deux unités au plus : de lui, le contour se tient à ce rayon de plus que la distance au premier point qui ne répond pas, à cela près
local SNUG = 1.5          -- un disque ne contient aucun point qui n'a pas répondu, à cela près (unités)
local TIGHT, HUG = 1.25, 0.6  -- et le contour qui passe à WIDE de son bord s'en tient pour cette part à TIGHT
local SPARE = 3           -- un nœud qui explique moins de points que cela, que les autres n'expliquent pas, est de trop
local SHARE = 0.2         -- groupe relu comme si ses nœuds avaient tous le même rayon : la part de ce qu'explique le premier, que chaque autre doit expliquer
local WELL, CLEARLY = 3, 3  -- ce que cette lecture laisse au plus d'inexpliqué, et ce dont elle doit faire mieux que l'autre, pour être retenue (points)
local RINGS = 24           -- anneaux du quadrillage du regard de près où se cherche le bord d'un groupe : plus de deux fois MAX_REACH
local HALVINGS = 5        -- dichotomies par bord : au quart d'unité près
local ROUND = 2           -- écart admis entre la plus grande et la plus petite largeur d'un disque seul
local MIN_APART = 4.5     -- deux nœuds plus proches que cela ne se séparent pas (unités)
local SQUARE_RATIO, SQUARE_FILL = 1.25, 0.95  -- un groupe dont le rectangle n'est pas plus allongé que cela, et que ses points remplissent pour cette part, est un seul point carré (Fit)
local MIN_SHARED, SHARED_IN = 5, 1  -- points essayés à cela au moins à l'intérieur de deux disques, où le nom écrit une seule fois dit que c'est un seul nœud (Fit)
local MIN_REACH, MAX_REACH = 6, 30  -- bornes du rayon de réponse d'un point du jeu (unités)
local PIN_REACH = 0.6     -- en pas de grille : jusqu'où un groupe est encore le nœud déjà placé là
local REFIT = 10          -- balayages au bout desquels un groupe déjà séparé est regardé de nouveau
local MERGE = 15          -- mètres : en deçà, une place trouvée est celle d'un nœud déjà connu du même nom (ou d'un rayon de disque, s'il fait plus)
local TWIN = 0.6          -- en rayons de disque : un nœud non retrouvé aussi près d'un nœud du même nom que le balayage vient de placer est ce nœud
local AVERAGE = 8         -- balayages sur lesquels une place approchée se moyenne
local STILL = 1.5         -- unités : un nœud placé avec précision ne bouge pas pour une mesure exacte si proche,
local SLACK = 3           -- ni pour une mesure approchée à moins de cela
local MISSES = 2          -- balayages de suite qui ne lisent aucun nom de son métier, au bout desquels un nœud perd son icône
local GLIDE = 0.12        -- secondes : une icône dont la place est corrigée y glisse, de cette constante de temps
local GLIDE_END = 0.3     -- mètres : en deçà, elle y est
local PICK_REACH = 10     -- mètres : l'icône d'un nœud que le joueur vient de récolter s'en va sans attendre
local PICK_TIME = 3       -- secondes entre le dernier regard du jeu sur un nœud et la fin du butin, et de là au balayage
local CAVE_SHADE = 0.55   -- luminosité de l'icône d'un nœud dans une grotte, qui est aussi grisée
local RING = "node"       -- Media\node.tga : l'anneau en relief qui entoure chaque icône, teinté de la difficulté du nœud
local RING_HOLE = 17.5 / 32  -- part du côté de cette image que prend l'icône entourée (Lueur-outils\gen_node.py)
local FLAT_RIM = 3        -- sans cette image, un disque de couleur dépasse l'icône d'autant, de chaque côté
local PLAIN = { 0.32, 0.29, 0.25 }  -- couleur de l'anneau d'un nœud dont la difficulté ne se sait pas
local FADE_IN, FADE_OUT = 0.25, 0.2 -- secondes que met une icône à paraître, puis à s'effacer
local EDGE_IN, EDGE_OUT = 7, 1      -- unités : une icône s'efface de EDGE_IN avant le bord de la minimap à EDGE_OUT après

-- Sorts de pistage, d'après Blizzard_Minimap\Mainline\Minimap.lua (build 1.60.1.70245)
local FINDERS = { [2383] = "herb", [8387] = "herb", [2580] = "ore", [8388] = "ore" }
local OPTION = { herb = "nodeHerbs", ore = "nodeOre" }
-- Image d'un nœud dont l'objet n'est pas connu : celle du bouton de pistage, sinon l'icône du métier
local KIND_ATLAS = { herb = "professions_tracking_herb", ore = "professions_tracking_ore" }
local KIND_ICON = { herb = "Interface\\Icons\\Trade_Herbalism", ore = "Interface\\Icons\\Trade_Mining" }
local CIRCLE = "CircleMask"
local CIRCLE_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- La flèche du joueur au centre de la minimap : l'atlas que le client nomme parmi les flèches de la
-- minimap (WowB.exe, build 70338), sinon l'image des clients d'avant, à une taille estimée
local PLAYER_ARROW = "ui-hud-minimap-arrow-player"
local PLAYER_ARROW_FILE, PLAYER_ARROW_SIZE = "Interface\\Minimap\\MinimapArrow", 24

local driver = CreateFrame("Frame")  -- fait tourner le balayage (OnUpdate) et reçoit les événements
local holder              -- cadre posé sur la minimap, qui porte les icônes
local pointer             -- la flèche du joueur, redessinée par-dessus une icône qui la recouvre
local covering = false    -- une icône recouvre-t-elle la flèche du joueur ?
local spare = {}          -- icônes qu'aucun nœud ne porte plus : le prochain qui en demande une la reprend
local markers = {}        -- nœuds connus : ceux du dernier balayage, ceux qu'il vient de manquer, ceux gardés d'un autre pistage
local ghosts = {}         -- nœuds qui ne le sont plus, le temps que leur icône s'efface
local busy = false        -- une icône au moins glisse vers sa place, paraît ou s'efface : le suivi ne s'arrête pas
local pickedAt            -- quand le butin s'est refermé pour la dernière fois
local probes = 0          -- points essayés depuis le chargement
local last = {}           -- ce qu'a coûté le dernier balayage : points, secondes, groupes regardés de près
local scan                -- balayage en cours
local wait, slow = 0, 1   -- secondes avant le prochain, et de combien l'attente est allongée
-- Rayon courant dans lequel un point du jeu répond (unités), par métier : `value`, ajusté sur les
-- nœuds isolés ; `measured`, s'il l'a été ou n'est encore qu'une estimation. Chaque nœud a le
-- sien (`marker.reach`), lu de son disque : celui-ci ne sert qu'à défaut, et à relire un groupe de
-- nœuds serrés comme s'ils l'avaient tous (Fit). Ni un rayon pour tous les points, ni un rayon par
-- métier n'ont tenu en jeu (2026-10-13 : des nœuds montrés par paires d'icônes, à dix-huit unités
-- l'une de l'autre puis côte à côte, ce que donne un disque cherché avec un rayon trop petit).
local reaches = { herb = { value = 15, measured = false }, ore = { value = 15, measured = false } }
local grid, gridWidth     -- points de la grille, pour cette largeur de minimap
local left, bottom, scale, width  -- place et échelle de la minimap pendant le balayage
local broken              -- erreur levée par le jeu pendant un balayage : il ne reprend pas
local masks               -- nil : pas encore essayé ; false : ce client ne sait pas découper une icône
local lastNames = {}      -- nom lu par le dernier balayage -> { points, gray }
local seen = {}           -- ce d'où le dernier suivi est parti : carte, place, orientation, rayon
local spot = {}           -- où était le joueur à la fin du dernier balayage
-- alternance des pistages : métier actif (kind), lieu de la dernière bascule (map, x, y), balayage fait depuis (scanned),
-- la bascule demandée au jeu tant qu'il ne l'a pas faite : le métier voulu (want), quand (at), combien de fois (tries) ;
-- et quand le jeu a annoncé pour la dernière fois un changement de pistage (changed)
local turn = {}
local looting = false
local refit = false       -- le joueur vient de récolter : les groupes déjà séparés sont à revoir
local hooked = false      -- l'infobulle de la minimap est-elle complétée ?

local function Wanted(kind)
	return ns.GetOption(OPTION[kind])
end

-- Nom du texte qui dit pourquoi ce client ne permet pas le balayage, ou nil
local function Failure()
	if broken then return "FAIL_SCAN_ERROR" end
	if not (Minimap and Minimap.UpdateMouseoverAtPoint and Minimap.SetUsingSoftCursor
		and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover
		and C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then
		return "FAIL_NO_SCAN"
	end
end

function ns.NodesFailure()
	local failure = Failure()
	return failure and L[failure]
end

local function HasAtlas(atlas)
	if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
	local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
	return ok and info ~= nil
end

local function Round(value)
	return math.floor(value + 0.5)
end

---------------------------------------------------------------------------
-- Où est le joueur, et ce que montre la minimap
---------------------------------------------------------------------------

-- Carte de la zone, place du joueur sur elle (0 à 1, y vers le sud) et taille de la carte en
-- mètres ; nil quand le jeu ne le dit pas (en instance)
local function MapPosition()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then return nil end
	local map = SafeCall(C_Map.GetBestMapForUnit, "player")
	if type(map) ~= "number" then return nil end
	local position = SafeCall(C_Map.GetPlayerMapPosition, map, "player")
	if type(position) ~= "table" or not position.GetXY then return nil end
	local ok, x, y = pcall(position.GetXY, position)
	if not ok or IsSecret(x) or IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
	local sized, wide, tall = pcall(C_Map.GetMapWorldSize, map)
	if not sized or IsSecret(wide) or IsSecret(tall) or type(wide) ~= "number" or type(tall) ~= "number" then return nil end
	if wide <= 0 or tall <= 0 then return nil end
	return map, x, y, wide, tall
end

-- Rayon de la minimap en mètres, si elle tourne avec le joueur, et l'orientation du joueur
-- (radians, sens inverse des aiguilles depuis le nord)
local function View()
	local radius = SafeCall(C_Minimap.GetViewRadius)
	if type(radius) ~= "number" or radius <= 0 then return nil end
	local turning = C_CVar and C_CVar.GetCVar and SafeCall(C_CVar.GetCVar, "rotateMinimap") == "1"
	if turning and C_Minimap.IsRotateMinimapIgnored and SafeCall(C_Minimap.IsRotateMinimapIgnored) == true then turning = false end
	local facing = GetPlayerFacing and SafeCall(GetPlayerFacing)
	if type(facing) ~= "number" then facing = nil end
	return radius, turning or false, facing
end

---------------------------------------------------------------------------
-- Icônes
---------------------------------------------------------------------------

-- Le jeu accroche chaque texture à la grille des pixels. Une icône qui suit le joueur avancerait
-- alors par à-coups d'un pixel, là où les points du jeu glissent : ses textures ne s'y accrochent
-- donc pas, et se posent entre deux pixels comme eux. (Vu en jeu le 2026-10-13, accrochées puis
-- posées par Lueur sur un pixel entier : « se refresh à chaque pas du personnage ».)
local function Loose(region)
	if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(false) end
	if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
end

-- Découpe en rond une texture d'une icône ; sans effet sur le client qui ne sait pas
local function Clip(icon, region)
	if masks == false then return end
	local ok, mask = pcall(icon.frame.CreateMaskTexture, icon.frame)
	if ok and mask then
		local set
		if HasAtlas(CIRCLE) then
			set = pcall(mask.SetAtlas, mask, CIRCLE)
		else
			local done, loaded = pcall(mask.SetTexture, mask, CIRCLE_FILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			set = done and loaded ~= false
		end
		if set and pcall(region.AddMaskTexture, region, mask) then
			mask:SetAllPoints(region)
			Loose(mask)
			masks = true
			return
		end
	end
	masks = false
end

-- Une icône : un cadre (`frame`, par lequel elle se place) qui porte l'image du nœud découpée en
-- rond (`face`) et, par-dessus, l'anneau qui l'entoure (`ring`). Un cadre par icône : deux icônes
-- qui se recouvrent restent chacune d'un seul tenant.
-- Sans l'image de l'anneau (Lueur mis à jour sans relancer le jeu, qui ne charge un nouveau fichier
-- qu'à son démarrage), l'anneau est un disque de couleur sous l'image (`flat`).
local function NewIcon(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local icon = { frame = frame }
	icon.face = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	icon.face:SetAllPoints(frame)
	icon.ring = frame:CreateTexture(nil, "ARTWORK", nil, 2)
	icon.ring:SetPoint("CENTER")
	if icon.ring:SetTexture(MEDIA .. RING .. ".tga") == false then
		icon.flat = true
		icon.ring:SetDrawLayer("ARTWORK", 0)
	end
	Clip(icon, icon.face)
	if icon.flat then Clip(icon, icon.ring) end
	Loose(icon.face)
	Loose(icon.ring)
	frame:Hide()
	return icon
end

-- Le jeu dessine la flèche du joueur avec la minimap elle-même, sous tout ce qu'un addon y pose : une
-- icône sur laquelle le joueur se tient la cache. Elle est donc redessinée par-dessus les icônes, à
-- la même place et dans le même sens, le temps qu'une icône la recouvre. (Demandé le 2026-10-15 :
-- « l'icone de navigation (le pointeur) sur la minimap qui représente le joueur doit passer
-- au-dessus des icones des ressources ».)
local function Turn()
	local _, turning, facing = View()
	-- (la minimap qui tourne garde la flèche pointée vers le haut)
	if turning then facing = 0 end
	if facing then pointer.texture:SetRotation(facing) end
	pointer.texture:SetShown(facing ~= nil)
end

local function Pointer(shown)
	if not pointer then
		if not shown then return end
		local frame = CreateFrame("Frame", nil, holder)
		frame:SetAllPoints(holder)
		frame:SetFrameLevel(holder:GetFrameLevel() + 10)
		local texture = frame:CreateTexture(nil, "OVERLAY")
		texture:SetPoint("CENTER", holder, "CENTER")
		if HasAtlas(PLAYER_ARROW) then
			texture:SetAtlas(PLAYER_ARROW, true)
		else
			texture:SetTexture(PLAYER_ARROW_FILE)
		end
		if (texture:GetWidth() or 0) <= 0 then texture:SetSize(PLAYER_ARROW_SIZE, PLAYER_ARROW_SIZE) end
		Loose(texture)
		pointer = { frame = frame, texture = texture }
		frame:SetScript("OnUpdate", Turn)
		frame:Hide()
	end
	if shown and not pointer.frame:IsShown() then Turn() end
	pointer.frame:SetShown(shown)
end

-- La moitié de la diagonale de la flèche : une icône plus proche que cela du centre de la minimap,
-- augmenté de son propre rayon, la recouvre
local function PointerReach()
	if not pointer then return PLAYER_ARROW_SIZE / 2 end
	local w, h = pointer.texture:GetWidth() or 0, pointer.texture:GetHeight() or 0
	return math.sqrt(w * w + h * h) / 2
end

-- Image d'un nœud, et si c'est un atlas
local function Picture(node)
	local file = ns.NodeIcon(node)
	if file then return file, false end
	if HasAtlas(KIND_ATLAS[node.kind]) then return KIND_ATLAS[node.kind], true end
	return KIND_ICON[node.kind], false
end

-- Donne à une icône l'image d'un nœud, à son anneau la couleur de sa difficulté (`level`, ou nil :
-- inconnue), et la grise s'il est dans une grotte. `size` est le diamètre de l'image ; l'anneau
-- l'entoure. Rien n'est refait de ce qui n'a pas changé.
local function DrawIcon(icon, node, level, cave, size)
	local picture, atlas = Picture(node)
	if icon.picture ~= picture then
		icon.picture = picture
		if atlas then
			icon.face:SetAtlas(picture)
		else
			icon.face:SetTexture(picture)
			icon.face:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- sans le bord dessiné dans les icônes du jeu
		end
	end
	if icon.size ~= size then
		icon.size = size
		icon.frame:SetSize(size, size)
		local around = icon.flat and size + 2 * FLAT_RIM or size / RING_HOLE
		icon.ring:SetSize(around, around)
	end
	level = level or false
	if icon.level ~= level then
		icon.level = level
		local r, g, b = PLAIN[1], PLAIN[2], PLAIN[3]
		if level then r, g, b = ns.DifficultyColor(level) end
		-- l'anneau est une image en gris, que la couleur teinte : son cerne et son ombre, noirs, le restent
		if icon.flat then icon.ring:SetColorTexture(r, g, b, 1) else icon.ring:SetVertexColor(r, g, b) end
	end
	cave = cave and true or false
	if icon.cave ~= cave then
		icon.cave = cave
		local shade = cave and CAVE_SHADE or 1
		icon.face:SetDesaturated(cave)
		icon.face:SetVertexColor(shade, shade, shade)
	end
end

local function ShowIcon(icon, shown)
	if icon.shown == shown then return end
	icon.shown = shown
	icon.frame:SetShown(shown)
end

-- Rend l'icône d'un nœud, qui servira à un autre
local function Free(marker)
	local icon = marker.icon
	if not icon then return end
	marker.icon = nil
	ShowIcon(icon, false)
	spare[#spare + 1] = icon
end

-- Un nœud n'est plus : son icône s'efface là où elle est, au lieu de disparaître d'un coup
local function Fade(marker)
	if not (marker.icon and marker.icon.shown) then
		Free(marker)
		return
	end
	marker.gone = GetTime()
	ghosts[#ghosts + 1] = marker
	busy = true
end

-- Ce qu'une icône garde d'opacité à cet endroit : elle s'efface en passant le bord de la minimap,
-- au lieu d'en déborder puis de disparaître d'un coup
local function Edge(marker, half)
	if marker.lost or not Wanted(marker.node.kind) then return 0 end
	local x, y = (marker.sx or marker.x) - half, (marker.sy or marker.y) - half
	return math.max(0, math.min(1, (half + EDGE_OUT - math.sqrt(x * x + y * y)) / (EDGE_IN + EDGE_OUT)))
end

-- Pose l'icône d'un nœud à sa place, avec cette opacité. Un nœud garde la sienne tant qu'il se
-- montre : aucune ne change d'image parce que la liste des nœuds a changé d'ordre.
local function Paint(marker, alpha, size)
	local icon = marker.icon
	if not icon then
		icon = table.remove(spare) or NewIcon(holder)
		marker.icon = icon
	end
	DrawIcon(icon, marker.node, ns.NodeDifficulty(marker.node), marker.gray, size)
	local x, y = marker.sx or marker.x, marker.sy or marker.y
	icon.frame:SetPoint("CENTER", holder, "BOTTOMLEFT", x, y)
	-- l'anneau déborde l'image : RING_HOLE en dit la part
	local half, reach = Minimap:GetWidth() / 2, size / RING_HOLE / 2 + PointerReach()
	if alpha > 0 and (x - half) ^ 2 + (y - half) ^ 2 < reach * reach then covering = true end
	if icon.alpha ~= alpha then
		icon.alpha = alpha
		icon.frame:SetAlpha(alpha)
	end
	ShowIcon(icon, true)
end

-- Met les icônes en accord avec les nœuds connus, et avec ceux qui s'en vont
local function Draw()
	if not holder then return end
	local size, shown, now, half = ns.GetOption("nodeSize"), 0, GetTime(), Minimap:GetWidth() / 2
	covering = false
	for _, marker in ipairs(markers) do
		local edge = Edge(marker, half)
		if shown < MAX_ICONS and edge > 0 then
			shown = shown + 1
			local life = math.min(1, (now - marker.born) / FADE_IN)
			if life < 1 then busy = true end
			Paint(marker, edge * life, size)
		else
			Free(marker)
		end
	end
	for index = #ghosts, 1, -1 do
		local marker = ghosts[index]
		local life = math.min(1, (now - marker.born) / FADE_IN, 1 - (now - marker.gone) / FADE_OUT)
		local edge = Edge(marker, half)
		if marker.icon and life > 0 and edge > 0 then
			busy = true
			Paint(marker, edge * life, size)
		else
			Free(marker)
			table.remove(ghosts, index)
		end
	end
	Pointer(covering)
end

-- Oublie tous les nœuds, sur-le-champ
local function Clear()
	for _, marker in ipairs(markers) do Free(marker) end
	for _, marker in ipairs(ghosts) do Free(marker) end
	markers, ghosts = {}, {}
	Pointer(false)
end

-- Où le point (mx, my) de la carte de la zone tombe sur la minimap, pour ce que `seen` dit du
-- joueur et d'elle : x, y, sa distance au centre (unités), et en mètres
local function Spot(mx, my)
	local east, north = (mx - seen.x) * seen.wide, (seen.y - my) * seen.tall
	local yards = math.sqrt(east * east + north * north)
	local way = math.atan2(east, north) -- sens des aiguilles depuis le nord
	if seen.turning then way = way + seen.facing end
	local distance = yards / seen.radius * seen.half
	return seen.half + distance * math.sin(way), seen.half + distance * math.cos(way), distance, yards
end

-- Entre deux balayages un nœud ne bouge pas, le joueur si : chaque icône est replacée d'après
-- la place du nœud sur la carte. Sans carte (en instance), elles restent où le balayage les a vues.
-- Un nœud dont un balayage vient de corriger la place (`dmx`, `dmy` : ce qui l'en sépare encore)
-- montre son icône en chemin (`sx`, `sy`).
local function Track(marker, rest)
	if marker.map == seen.map then
		local distance
		marker.x, marker.y, distance, marker.yards = Spot(marker.mx, marker.my)
		marker.far, marker.lost = distance > seen.half, nil
		if marker.dmx then
			marker.dmx, marker.dmy = marker.dmx * rest, marker.dmy * rest
			if (marker.dmx * seen.wide) ^ 2 + (marker.dmy * seen.tall) ^ 2 < GLIDE_END * GLIDE_END then
				marker.dmx, marker.dmy, marker.sx, marker.sy = nil, nil, nil, nil
			else
				marker.sx, marker.sy = Spot(marker.mx + marker.dmx, marker.my + marker.dmy)
				busy = true
			end
		end
	elseif marker.map then
		-- rangé sur une autre carte que celle où le joueur vient de passer : sa place ne se sait
		-- plus, et le prochain balayage le retrouvera s'il est encore là
		marker.far, marker.lost = true, true
	end
end

local function Follow(elapsed)
	if not (markers[1] or ghosts[1]) then return end
	local map, x, y, wide, tall = MapPosition()
	local radius, turning, facing
	if map then radius, turning, facing = View() end
	if radius and not (turning and not facing) then
		if not busy and map == seen.map and x == seen.x and y == seen.y and radius == seen.radius and turning == seen.turning
			and (not turning or facing == seen.facing) then
			return
		end
		seen.map, seen.x, seen.y, seen.radius, seen.turning, seen.facing = map, x, y, radius, turning, facing
		seen.wide, seen.tall, seen.half = wide, tall, Minimap:GetWidth() / 2
		local rest = math.exp(-(elapsed or 0) / GLIDE)
		busy = false
		for _, marker in ipairs(markers) do Track(marker, rest) end
		for _, marker in ipairs(ghosts) do Track(marker, rest) end
	elseif busy then
		busy = false -- sans carte, rien ne suit le joueur ; les icônes qui paraissent ou s'effacent continuent
	else
		return
	end
	Draw()
end

---------------------------------------------------------------------------
-- Ce que dit l'infobulle de la minimap
---------------------------------------------------------------------------

-- Le jeu écrit en gris le nom d'un nœud qui est dans une grotte
local function Gray(r, g, b)
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return false end
	return math.abs(r - g) < 0.1 and math.abs(g - b) < 0.1 and r < 0.9
end

-- Les noms d'une ligne d'infobulle : elle en porte un par rangée, chacun avec ses images
-- (|T…|t, |A…|a) et parfois sa couleur (|cAARRGGBB, |cnNOM:). `gray` vaut nil pour un nom sans
-- couleur à lui : c'est alors celle de la ligne qui compte. `arrow` : le nom vient après la flèche
-- d'un nœud plus haut ou plus bas que le joueur (Minimap-PositionArrows), que le jeu montre au lieu
-- d'un point. Les mêmes lignes reviennent sans cesse : ce qui en a été tiré est gardé.
local parsed, parsedCount = {}, 0

local function Names(text)
	local list = parsed[text]
	if list then return list end
	list = {}
	for row in text:gmatch("[^\n]+") do
		local gray
		local r, g, b = row:match("|c%x%x(%x%x)(%x%x)(%x%x)")
		local named = row:match("|cn([%w_]+):")
		if r then
			gray = Gray(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
		elseif named then
			gray = named:find("GRAY", 1, true) ~= nil or named:find("DISABLED", 1, true) ~= nil
		end
		local name = row:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", "")
		name = name:match("^%s*(.-)%s*$")
		if name ~= "" then list[#list + 1] = { name = name, gray = gray, arrow = row:find("PositionArrows", 1, true) ~= nil } end
	end
	if parsedCount >= 300 then parsed, parsedCount = {}, 0 end
	parsed[text], parsedCount = list, parsedCount + 1
	return list
end

-- Le jeu a-t-il déjà écrit un même nom deux fois en un point, comme il le ferait de deux points du
-- jeu de ce nom qui y répondent ensemble ? Retenu d'une session à l'autre (db.nodeTwice) : rien ne
-- dit d'avance qu'il le fait, et Fit ne se fie qu'alors à un nom écrit une seule fois, sauf
-- après une flèche.
local function Doubled()
	return ns.db ~= nil and ns.db.nodeTwice == true
end

-- Essaie un point de la minimap (x, y en unités depuis son coin bas gauche) et note sous
-- `point`, pour chaque nom que le jeu y donne, 1, ou 2 s'il l'écrit en gris. Un regard de près
-- (`job`) note en plus les noms que le jeu y écrit plus d'une fois (job.many), et ceux qu'il écrit
-- après une flèche (job.arrows).
local written, writtenCount = {}, 0

local function Probe(x, y, hits, point, job)
	probes = probes + 1
	Minimap:UpdateMouseoverAtPoint((left + x) * scale, (bottom + y) * scale)
	local data = SafeCall(C_TooltipInfo.GetMinimapMouseover)
	local lines = type(data) == "table" and data.lines
	if IsSecret(lines) or type(lines) ~= "table" then return end
	writtenCount = 0
	for _, line in ipairs(lines) do
		local text = line.leftText
		if not IsSecret(text) and type(text) == "string" then
			local color = line.leftColor
			local lineGray = not IsSecret(color) and type(color) == "table" and Gray(color.r, color.g, color.b)
			for _, entry in ipairs(Names(text)) do
				local set = hits[entry.name]
				if not set then
					set = {}
					hits[entry.name] = set
				end
				local gray = entry.gray
				if gray == nil then gray = lineGray end
				set[point] = gray and 2 or 1
				local twice = false
				for index = 1, writtenCount do
					if written[index] == entry.name then twice = true end
				end
				writtenCount = writtenCount + 1
				written[writtenCount] = entry.name
				if twice and ns.db and not ns.db.nodeTwice then ns.db.nodeTwice = true end
				if job then
					if twice then
						job.many[entry.name] = job.many[entry.name] or {}
						job.many[entry.name][point] = true
					end
					if entry.arrow then job.arrows[entry.name] = true end
				end
			end
		end
	end
end

local scratch = {}

-- Le jeu nomme-t-il ce point du jeu en (x, y) ?
local function Under(name, x, y)
	for key in pairs(scratch) do scratch[key] = nil end
	Probe(x, y, scratch, 1)
	return scratch[name] ~= nil
end

---------------------------------------------------------------------------
-- Des points de grille aux nœuds
---------------------------------------------------------------------------

-- Un point de grille a pour numéro colonne + 1024 × rangée ; voici ses huit voisins, et les quatre
-- qui le touchent
local ROW = 1024
local AROUND = { -ROW - 1, -ROW, -ROW + 1, -1, 1, ROW - 1, ROW, ROW + 1 }
local BESIDE = { { -1, -1, 0 }, { 1, 1, 0 }, { -ROW, 0, -1 }, { ROW, 0, 1 } }

-- Les groupes de points voisins d'un ensemble : une liste de listes de numéros
local function Groups(set)
	local groups, taken = {}, {}
	for first in pairs(set) do
		if not taken[first] then
			taken[first] = true
			local keys, stack = {}, { first }
			while #stack > 0 do
				local key = table.remove(stack)
				keys[#keys + 1] = key
				for _, step in ipairs(AROUND) do
					local other = key + step
					if set[other] and not taken[other] then
						taken[other] = true
						stack[#stack + 1] = other
					end
				end
			end
			groups[#groups + 1] = keys
		end
	end
	return groups
end

-- Le rectangle qui tient un groupe et son milieu, en unités : gauche, bas, droite, haut, x, y
local function Box(keys)
	local x0, y0, x1, y1, sx, sy = math.huge, math.huge, -math.huge, -math.huge, 0, 0
	for _, key in ipairs(keys) do
		local x, y = key % ROW * STEP, math.floor(key / ROW) * STEP
		x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
		sx, sy = sx + x, sy + y
	end
	return x0, y0, x1, y1, sx / #keys, sy / #keys
end

-- Le jeu écrit-il ce nom en gris au point de l'ensemble le plus proche de (x, y) ? nil si ce
-- point n'en fait pas partie
local function GrayAt(set, x, y, step)
	local value = set[Round(x / step) + ROW * Round(y / step)]
	if value then return value == 2 end
end

-- Ce que vaut la place qu'un balayage donne à un nœud. Du pire au meilleur : le milieu d'un groupe
-- que rien n'a séparé ; un disque que le bord de la minimap tronque, dont la place est tirée vers
-- le centre ; un nœud d'un groupe, lu de son contour ; un nœud seul dont les bords ont été trouvés.
local ROUGH, RIM_PLACE, FITTED, SURE = 0, 1, 2, 3

local function Worth(place)
	if place.rim then return RIM_PLACE end
	if place.fitted then return FITTED end
	return place.exact and SURE or ROUGH
end

-- Rayon du disque où répond ce nœud : le sien, s'il a été lu, sinon le rayon courant de son métier
local function Radius(marker)
	return marker.reach or reaches[marker.node.kind].value
end

-- Un nœud seul vient d'être mesuré : le rayon courant de son métier s'en approche, et le premier
-- remplace l'estimation de départ
local function Learn(kind, radius)
	local known = reaches[kind]
	radius = math.max(MIN_REACH, math.min(MAX_REACH, radius))
	if known.measured then
		known.value = known.value + (radius - known.value) / 4
	else
		known.value, known.measured = radius, true
	end
end

-- Les nœuds déjà bien placés (un par un, ou lus du contour de leur groupe) dont le disque touche ce
-- groupe, et s'ils l'expliquent en entier. `map` : la carte où est le joueur.
local function Placed(name, keys, map)
	local mine, used, whole = {}, {}, true
	for _, key in ipairs(keys) do
		local x, y = key % ROW * STEP, math.floor(key / ROW) * STEP
		local covered = false
		for _, marker in ipairs(markers) do
			if marker.name == name and marker.map == map and marker.worth >= FITTED
				and (marker.x - x) ^ 2 + (marker.y - y) ^ 2 <= (Radius(marker) + STEP / 2 + 1) ^ 2 then
				covered = true
				if not used[marker] then
					used[marker] = true
					mine[#mine + 1] = marker
				end
			end
		end
		whole = whole and covered
	end
	return mine, whole
end

-- Un groupe touche-t-il le bord de la minimap, où le disque d'un nœud est tronqué ?
local function AtRim(keys)
	local half = width / 2
	local edge = (half - 1.5 * STEP) ^ 2
	for _, key in ipairs(keys) do
		if (key % ROW * STEP - half) ^ 2 + (math.floor(key / ROW) * STEP - half) ^ 2 >= edge then return true end
	end
	return false
end

-- Le nœud isolé déjà placé avec précision à cet endroit, s'il y en a un : il garde sa place.
-- `wide` : la largeur du groupe, qui ne dépasse pas le disque de ce nœud s'il y est seul.
local function Pinned(name, x, y, wide)
	local near = (PIN_REACH * STEP) ^ 2
	for _, marker in ipairs(markers) do
		if marker.exact and marker.name == name and not marker.far and (marker.x - x) ^ 2 + (marker.y - y) ^ 2 <= near
			and wide <= 2 * Radius(marker) + 2 then
			return marker
		end
	end
end

-- Les nœuds qu'un balayage précédent a déjà séparés dans ce groupe, s'ils l'expliquent encore en
-- entier : les séparer coûte cher, et ils ne bougent pas. Sauf si un seul disque, au milieu d'eux,
-- l'explique aussi bien : c'est peut-être un nœud seul qu'un regard de près a lu comme plusieurs, et
-- les garder le montrerait en double pendant REFIT balayages. Le groupe est alors relu.
-- (Vu en jeu le 2026-10-14 : deux Feuillargent « dans un groupe », à dix unités l'une de l'autre,
-- pour une seule sur la minimap, gardées par le dernier balayage sans regard de près.)
local function Known(name, keys)
	if refit then return nil end
	local inside, mine = {}, {}
	local cx, cy, reach = 0, 0, 0
	for _, key in ipairs(keys) do inside[key] = true end
	for _, marker in ipairs(markers) do
		if marker.fitted and marker.name == name and not marker.far and marker.age < REFIT
			and inside[Round(marker.x / STEP) + ROW * Round(marker.y / STEP)] then
			mine[#mine + 1] = marker
			cx, cy, reach = cx + marker.x, cy + marker.y, math.max(reach, Radius(marker))
		end
	end
	if #mine < 2 then return nil end
	cx, cy = cx / #mine, cy / #mine
	local single = true
	for _, key in ipairs(keys) do
		local x, y = key % ROW * STEP, math.floor(key / ROW) * STEP
		local covered = false
		for _, marker in ipairs(mine) do
			if (marker.x - x) ^ 2 + (marker.y - y) ^ 2 <= (Radius(marker) + STEP / 2 + 1) ^ 2 then
				covered = true
				break
			end
		end
		if not covered then return nil end
		if (cx - x) ^ 2 + (cy - y) ^ 2 > (reach + STEP / 2 + 1) ^ 2 then single = false end
	end
	if single then return nil end
	return mine
end

-- Jusqu'où ce nom répond depuis (x, y) dans la direction (dx, dy), cherché jusqu'à `limit` unités.
-- nil s'il répond encore au bout ; le second résultat dit alors si c'est le bord de la minimap
-- qui a arrêté la recherche.
local function Edge(name, x, y, dx, dy, limit)
	local half = width / 2
	local px, py, rim = x - half, y - half, half - 1
	local along = px * dx + py * dy
	local room = along * along - (px * px + py * py - rim * rim)
	if room <= 0 then return nil, true end
	local far, atRim = math.sqrt(room) - along, true
	if far > limit then far, atRim = limit, false end
	if far <= 0 then return nil, true end
	if Under(name, x + dx * far, y + dy * far) then return nil, atRim end
	local near = 0
	for _ = 1, HALVINGS do
		local middle = (near + far) / 2
		if Under(name, x + dx * middle, y + dy * middle) then near = middle else far = middle end
	end
	return (near + far) / 2
end

-- Cherche le centre exact d'un groupe qui peut être un disque seul. À la sortie : place.exact s'il
-- est trouvé (et place.reach, le rayon de ce disque), place.rim si le bord de la minimap cache un
-- de ses bords, place.merged s'il n'a pas la forme d'un disque seul. Un groupe rond est un nœud
-- quel que soit son rayon : rien n'assure que tous les points du jeu répondent d'aussi loin.
local function Refine(place)
	local name, x, y = place.name, place.x, place.y
	-- un bord se cherche jusqu'un peu au-delà de ce que la grille a vu du groupe
	local box = place.box
	local limit = math.min(2 * MAX_REACH, math.max(box[3] - box[1], box[4] - box[2]) / 2 + 2 * STEP)
	if not Under(name, x, y) then
		place.merged = true
		return
	end
	-- la demi-largeur du groupe le long d'une droite qui passe par (x, y), et de combien son
	-- milieu s'écarte de ce point ; nil si un bord manque
	local function Chord(dx, dy)
		local back, backRim = Edge(name, x, y, -dx, -dy, limit)
		local ahead, aheadRim = Edge(name, x, y, dx, dy, limit)
		if back and ahead then return (ahead + back) / 2, (ahead - back) / 2 end
		if backRim or aheadRim then place.rim = true else place.merged = true end
	end
	local half, shift = Chord(1, 0)
	if not half then return end
	x = x + shift
	half, shift = Chord(0, 1)
	if not half then return end
	y = y + shift
	-- Un disque seul a la même largeur dans toutes les directions. Deux nœuds voisins dont les
	-- disques se recouvrent font un groupe allongé, qui ne dépasse pas toujours la taille d'un
	-- disque sur la grille.
	local slant = math.sqrt(0.5)
	local least, most, sum = math.huge, 0, 0
	for _, way in ipairs({ { 1, 0 }, { 0, 1 }, { slant, slant }, { slant, -slant } }) do
		half = Chord(way[1], way[2])
		if not half then return end
		least, most, sum = math.min(least, half), math.max(most, half), sum + half
	end
	local radius = sum / 4
	if most - least > ROUND or radius < MIN_REACH or radius > MAX_REACH then
		place.merged = true
		return
	end
	place.x, place.y, place.exact, place.reach = x, y, true, radius
	Learn(place.node.kind, radius)
end

-- Le regard de près sur un groupe : les points, FINE unités d'écart, de son rectangle élargi
-- d'un pas de grille, qui touchent une case de la grille où le groupe a répondu ou sa voisine
local function NewJob(place, x0, y0, x1, y1)
	local half = width / 2
	local nearby, points = {}, {}
	for _, key in ipairs(place.keys) do
		nearby[key] = true
		for _, step in ipairs(AROUND) do nearby[key + step] = true end
	end
	for column = math.max(0, math.ceil((x0 - STEP) / FINE)), math.floor((x1 + STEP) / FINE) do
		for line = math.max(0, math.ceil((y0 - STEP) / FINE)), math.floor((y1 + STEP) / FINE) do
			local x, y = column * FINE, line * FINE
			if nearby[Round(x / STEP) + ROW * Round(y / STEP)] and (x - half) ^ 2 + (y - half) ^ 2 <= half * half then
				points[#points + 1] = column + ROW * line
			end
		end
	end
	return { place = place, points = points, next = 1, hits = {}, many = {}, arrows = {} }
end

-- Le cercle qui passe au plus près de ces points (moindres carrés) : son centre et son rayon, ou
-- nil s'ils sont trop peu ou alignés
local function Circle(points)
	local count = #points
	if count < 3 then return nil end
	local mx, my = 0, 0
	for _, point in ipairs(points) do mx, my = mx + point[1], my + point[2] end
	mx, my = mx / count, my / count
	local uu, uv, vv, uuu, vvv, uvv, vuu = 0, 0, 0, 0, 0, 0, 0
	for _, point in ipairs(points) do
		local u, v = point[1] - mx, point[2] - my
		uu, uv, vv = uu + u * u, uv + u * v, vv + v * v
		uuu, vvv, uvv, vuu = uuu + u * u * u, vvv + v * v * v, uvv + u * v * v, vuu + v * u * u
	end
	local det = uu * vv - uv * uv
	if det < 1e-6 * (uu + vv) ^ 2 then return nil end
	local a, b = (uuu + uvv) / 2, (vvv + vuu) / 2
	local x, y = (a * vv - b * uv) / det, (b * uu - a * uv) / det
	return mx + x, my + y, math.sqrt(x * x + y * y + (uu + vv) / count)
end

-- Le regard de près sur un groupe déborde sur ses voisins : de ses points qui ont répondu, ceux
-- qui tiennent au groupe, de proche en proche depuis un point de la grille où il a répondu. Le reste
-- est le disque d'un nœud d'un autre groupe, qui a son propre regard.
local function Own(job, inside)
	local at, mine, stack = {}, {}, {}
	for _, point in ipairs(inside) do at[point[4]] = point end
	for _, key in ipairs(job.place.keys) do
		local x, y = key % ROW * STEP, math.floor(key / ROW) * STEP
		local column, line = Round(x / FINE), Round(y / FINE)
		for dx = -1, 1 do
			for dy = -1, 1 do
				local point = at[column + dx + ROW * (line + dy)]
				if point and not mine[point] and (point[1] - x) ^ 2 + (point[2] - y) ^ 2 <= FINE * FINE then
					mine[point] = true
					stack[#stack + 1] = point
				end
			end
		end
	end
	local list = {}
	while #stack > 0 do
		local point = table.remove(stack)
		list[#list + 1] = point
		for _, step in ipairs(AROUND) do
			local other = at[point[4] + step]
			if other and not mine[other] then
				mine[other] = true
				stack[#stack + 1] = other
			end
		end
	end
	return list
end

-- Les nœuds d'un groupe regardé de près : une liste de { x, y, rayon }.
--
-- Chaque point du jeu a son rayon, que rien ne dit d'avance : il se lit du groupe. Le centre d'un
-- nœud est un point du groupe ; son disque s'arrête au premier point qui n'a pas répondu, et le
-- contour du groupe se tient à cette distance autour de lui. Le point qui voit ainsi le plus de
-- contour donne un nœud, ce contour-là est retiré, et l'on recommence tant qu'il en reste assez. Un
-- nœud de plus n'est admis que s'il explique des points du groupe qu'aucun nœud trouvé n'explique,
-- et celui qui, à la fin, n'explique rien que les autres n'expliquent est retiré : un disque seul,
-- quel que soit son rayon, est un nœud et un seul.
-- (Vu en jeu le 2026-10-13 : les disques y étaient cherchés au rayon mesuré sur d'autres nœuds du
-- même métier, 11,2 unités ce jour-là. Un point qui répondait d'un peu plus loin donnait alors deux
-- icônes côte à côte, « un doublon qui n'existe pas en vrai ».)
--
-- Des nœuds serrés, tous du même rayon, se lisent mal ainsi : quatre en carré passent pour deux ou
-- trois disques plus gros. Le groupe est donc lu une seconde fois au rayon courant du métier, comme
-- si tous ses nœuds l'avaient, et cette lecture n'est retenue que si elle explique nettement mieux
-- le groupe que la première (Misfit).
--
-- Essayé hors jeu sur des grappes tirées au hasard (Lueur-outils\harness\scan.py), de même rayon
-- ou de rayons mêlés, et sur un champ de nœuds traversé en courant (walk.py, MIX=2) : un nœud seul
-- ne donne jamais deux icônes ; il en manque une quand un disque est presque couvert par ses voisins.
local function Fit(job)
	local set = job.hits[job.place.name]
	if not set then return nil end
	local inside, outline, outside = {}, {}, {}
	local asked = {}
	for _, key in ipairs(job.points) do asked[key] = true end
	for _, key in ipairs(job.points) do
		local x, y = key % ROW * FINE, math.floor(key / ROW) * FINE
		if set[key] then
			inside[#inside + 1] = { x, y, 0, key }
		else
			outside[#outside + 1] = { x, y }
		end
	end
	if #inside == 0 or #outside == 0 then return nil end
	inside = Own(job, inside)
	-- Le contour passe à mi-chemin d'un point qui a répondu et d'un voisin qui ne l'a pas fait.
	-- Ce qui sépare chaque point du groupe du plus proche qui n'a pas répondu se cherche d'anneau en
	-- anneau autour de lui, sur le quadrillage du regard de près, et l'on s'arrête dès qu'un anneau
	-- est plus loin que ce qui est trouvé. (Les comparer tous deux à deux prenait des dizaines de
	-- millisecondes sur un gros groupe : une image qui saute.) Un point est un centre possible si un
	-- disque y tient.
	local centers = {}
	for _, point in ipairs(inside) do
		local key, ox, oy = point[4], 0, 0
		for _, side in ipairs(BESIDE) do
			local other = key + side[1]
			if asked[other] and not set[other] then ox, oy = ox + side[2], oy + side[3] end
		end
		if ox ~= 0 or oy ~= 0 then outline[#outline + 1] = { point[1] + ox * FINE / 2, point[2] + oy * FINE / 2 } end
		local nearest, ring = math.huge, 1
		while ring <= RINGS and ((ring - 1) * FINE) ^ 2 < nearest do
			for along = -ring, ring do
				for _, other in ipairs({ key + along + ROW * ring, key + along - ROW * ring, key + ring + ROW * along, key - ring + ROW * along }) do
					if asked[other] and not set[other] then
						local gap = (point[1] - other % ROW * FINE) ^ 2 + (point[2] - math.floor(other / ROW) * FINE) ^ 2
						if gap < nearest then nearest = gap end
					end
				end
			end
			ring = ring + 1
		end
		point[3] = math.sqrt(math.min(nearest, (RINGS * FINE) ^ 2))
		if point[3] >= MIN_REACH and point[3] <= MAX_REACH + FINE then centers[#centers + 1] = point end
	end

	local contour, discs -- le contour que les nœuds trouvés n'expliquent pas encore, et ces nœuds
	-- les points du contour restant qui se tiennent à ce rayon de (x, y), à `slack` près ; et leur nombre
	local function Near(x, y, radius, slack)
		local low, high, list = math.max(0, radius - slack) ^ 2, (radius + slack) ^ 2, {}
		for _, point in ipairs(contour) do
			local gap = (point[1] - x) ^ 2 + (point[2] - y) ^ 2
			if gap >= low and gap <= high then list[#list + 1] = point end
		end
		return list
	end
	local function Votes(x, y, radius, slack)
		local low, high, count = math.max(0, radius - slack) ^ 2, (radius + slack) ^ 2, 0
		for _, point in ipairs(contour) do
			local gap = (point[1] - x) ^ 2 + (point[2] - y) ^ 2
			if gap >= low and gap <= high then count = count + 1 end
		end
		return count
	end
	-- combien de points du groupe, qu'aucun nœud trouvé n'explique (point[6]), sont à ce rayon de (x, y)
	local function Gain(x, y, radius)
		local near, count = radius * radius, 0
		for _, point in ipairs(inside) do
			if not point[6] and (point[1] - x) ^ 2 + (point[2] - y) ^ 2 <= near then count = count + 1 end
		end
		return count
	end
	-- ce qui sépare (x, y) du plus proche point qui n'a pas répondu
	local function Room(x, y)
		local room = math.huge
		for _, point in ipairs(outside) do
			local gap = (point[1] - x) ^ 2 + (point[2] - y) ^ 2
			if gap < room then room = gap end
		end
		return math.sqrt(room)
	end
	local function Apart(x, y)
		for _, disc in ipairs(discs) do
			-- trop près d'un nœud déjà trouvé : ce serait le même
			if (disc[1] - x) ^ 2 + (disc[2] - y) ^ 2 < MIN_APART * MIN_APART then return false end
		end
		return true
	end
	-- Un nœud de plus : les points du groupe que son disque explique, et le contour qu'il explique,
	-- ne compteront plus pour un autre (ni ce qui reste de contour dans son disque)
	local function Add(x, y, radius)
		discs[#discs + 1] = { x, y, radius }
		local cover, high, rest = (radius + 1) ^ 2, (radius + TOLERANCE) ^ 2, {}
		for _, point in ipairs(inside) do
			if (point[1] - x) ^ 2 + (point[2] - y) ^ 2 <= cover then point[6] = true end
		end
		for _, point in ipairs(contour) do
			if (point[1] - x) ^ 2 + (point[2] - y) ^ 2 > high then rest[#rest + 1] = point end
		end
		contour = rest
	end
	-- Le vrai centre est entre les points du regard de près : autour de (x, y), à l'unité près, c'est
	-- le milieu des places qui expliquent le plus de contour à ce rayon
	local function Center(x, y, radius)
		local tries, top = {}, 0
		for dx = -2, 2 do
			for dy = -2, 2 do
				local count = Votes(x + dx, y + dy, radius, TOLERANCE)
				tries[#tries + 1] = { x + dx, y + dy, count }
				if count > top then top = count end
			end
		end
		local sx, sy, count = 0, 0, 0
		for _, try in ipairs(tries) do
			if try[3] >= top - 1 then sx, sy, count = sx + try[1], sy + try[2], count + 1 end
		end
		return sx / count, sy / count
	end
	-- Le centre et le rayon du disque qui passe près de là : le rayon est la distance moyenne à
	-- laquelle le contour se tient du centre. Le contour d'un voisin, là où il rejoint celui-ci, tire
	-- cette moyenne vers le haut : le disque s'arrête pourtant avant le premier point qui n'a pas répondu.
	local function Polish(x, y, radius)
		for _ = 1, 2 do
			x, y = Center(x, y, radius)
			for _ = 1, 2 do
				local list, sum = Near(x, y, radius, TOLERANCE), 0
				for _, point in ipairs(list) do sum = sum + math.sqrt((point[1] - x) ^ 2 + (point[2] - y) ^ 2) end
				if list[1] then radius = sum / #list end
			end
		end
		return x, y, math.min(radius, Room(x, y) + SNUG / 3)
	end
	-- Un disque est-il possible là ? Il ne contient aucun point qui n'a pas répondu, et le contour
	-- qui passe près de son bord le suit : un cercle qui engloberait plusieurs nœuds coupe leur
	-- contour au lieu de le suivre.
	local function Sound(x, y, radius)
		return radius >= MIN_REACH and radius <= MAX_REACH and Room(x, y) >= radius - SNUG
			and Votes(x, y, radius, TIGHT) >= HUG * Votes(x, y, radius, WIDE)
	end
	-- Le disque dont ce point voit le contour : son centre, son rayon, et ce qu'il explique de
	-- contour (0 si aucun disque n'est possible là). Le cercle qui passe au plus près du contour vu
	-- de ce point le donne, d'où que ce point le voie ; vu de trop large, ce contour est parfois
	-- celui de plusieurs nœuds : il est alors repris de plus près, puis de ce point seul.
	local function Disc(center)
		local x, y, radius
		for _, slack in ipairs({ WIDE, TOLERANCE }) do
			x, y, radius = Circle(Near(center[1], center[2], center[3] + (slack == WIDE and AHEAD or 0.5), slack))
			if x then
				x, y, radius = Polish(x, y, radius)
				if Sound(x, y, radius) then return x, y, radius, Votes(x, y, radius, TOLERANCE) end
			end
		end
		x, y, radius = Polish(center[1], center[2], center[3] + 0.5)
		return x, y, radius, Sound(x, y, radius) and Votes(x, y, radius, TOLERANCE) or 0
	end

	-- Lit le groupe : chaque nœud à son rayon, ou tous au rayon `same`
	local function Read(same)
		contour, discs = outline, {}
		for _, point in ipairs(inside) do point[5], point[6] = math.huge, nil end
		local first
		while #discs < MAX_DISCS do
			-- Le meilleur centre : celui autour duquel le plus de contour se tient à distance égale.
			-- Le contour restant ne fait que diminuer : un centre qui n'en expliquait pas assez
			-- (point[5]) n'est pas recompté.
			local best, bestVotes = nil, MIN_VOTES - 1
			for _, center in ipairs(centers) do
				if center[5] > bestVotes then
					local count = 0
					if not Apart(center[1], center[2]) then
						count = 0
					elseif not same then
						count = Votes(center[1], center[2], center[3] + AHEAD, WIDE)
					elseif center[3] >= same - TOLERANCE - 0.5 then
						count = Votes(center[1], center[2], same, TOLERANCE)
					end
					center[5] = count
					if count > bestVotes then best, bestVotes = center, count end
				end
			end
			if not best then break end
			if same then
				-- il faut un arc de contour, et pas des miettes laissées par les nœuds déjà trouvés
				local x, y = Center(best[1], best[2], same)
				local votes = Votes(x, y, same, TOLERANCE)
				first = first or votes
				if votes < MIN_VOTES or votes < first * SHARE or not Apart(x, y) then break end
				Add(x, y, same)
			else
				-- Il faut un arc de contour autour de lui, et, pour un nœud de plus, des points du groupe
				-- qu'aucun nœud trouvé n'explique : sans quoi ce centre est écarté, et l'on passe au suivant.
				local x, y, radius, votes = Disc(best)
				if votes >= MIN_VOTES and Apart(x, y) and (not discs[1] or Gain(x, y, radius) >= MIN_LOOSE) then
					Add(x, y, radius)
				else
					best[5] = 0
				end
			end
		end
		if not discs[1] then return nil end
		-- Un nœud pris entre deux autres ne montre presque rien de son contour. Il reste alors des
		-- points du groupe qu'aucun nœud trouvé n'explique : le point qui en explique le plus en donne
		-- un, du rayon du premier nœud du groupe faute de pouvoir lire le sien.
		local radius = discs[1][3]
		while #discs < MAX_DISCS do
			local best, bestCount, counts = nil, 0, {}
			for index, center in ipairs(centers) do
				local count = (not same or center[3] >= same - TOLERANCE - 0.5) and Apart(center[1], center[2]) and Gain(center[1], center[2], radius) or 0
				counts[index] = count
				if count > bestCount then best, bestCount = center, count end
			end
			if bestCount < MIN_LOOSE then break end
			local sx, sy, count = 0, 0, 0
			for index, center in ipairs(centers) do
				if counts[index] == bestCount and (center[1] - best[1]) ^ 2 + (center[2] - best[2]) ^ 2 <= (2 * FINE) ^ 2 then
					sx, sy, count = sx + center[1], sy + center[2], count + 1
				end
			end
			Add(sx / count, sy / count, radius)
		end
		return discs
	end
	-- Ce qu'une lecture explique mal du groupe : les points de son contour qui ne sont sur le bord
	-- d'aucun de ses disques, ou qui sont dans l'un d'eux ; les points qui n'ont pas répondu et
	-- qu'un disque contient ; et, pour moitié, les points du groupe qu'aucun disque ne contient.
	local function Misfit(list)
		local count = 0
		for _, point in ipairs(outline) do
			local on, within = false, false
			for _, disc in ipairs(list) do
				local gap = math.sqrt((point[1] - disc[1]) ^ 2 + (point[2] - disc[2]) ^ 2) - disc[3]
				if gap < -TOLERANCE then within = true elseif gap <= TOLERANCE then on = true end
			end
			if within or not on then count = count + 1 end
		end
		for _, point in ipairs(outside) do
			for _, disc in ipairs(list) do
				if (point[1] - disc[1]) ^ 2 + (point[2] - disc[2]) ^ 2 < math.max(0, disc[3] - SNUG) ^ 2 then
					count = count + 1
					break
				end
			end
		end
		for _, point in ipairs(inside) do
			local covered = false
			for _, disc in ipairs(list) do
				if (point[1] - disc[1]) ^ 2 + (point[2] - disc[2]) ^ 2 <= (disc[3] + 1) ^ 2 then
					covered = true
					break
				end
			end
			if not covered then count = count + 0.5 end
		end
		return count
	end

	-- Le moins de nœuds possible : celui qui n'explique rien que les autres n'expliquent est de trop,
	-- ni points du groupe ni contour. (Deux nœuds serrés se lisent parfois comme un disque plus gros,
	-- puis chacun pour lui-même : c'est le gros qui s'en va.)
	local function Idle(list, index)
		local disc, own = list[index], 0
		local function Elsewhere(point, slack)
			for other, with in ipairs(list) do
				if other ~= index and (point[1] - with[1]) ^ 2 + (point[2] - with[2]) ^ 2 <= (with[3] + slack) ^ 2 then return true end
			end
			return false
		end
		for _, point in ipairs(inside) do
			if (point[1] - disc[1]) ^ 2 + (point[2] - disc[2]) ^ 2 <= (disc[3] + 1) ^ 2 and not Elsewhere(point, 1) then own = own + 1 end
		end
		for _, point in ipairs(outline) do
			local gap = math.sqrt((point[1] - disc[1]) ^ 2 + (point[2] - disc[2]) ^ 2) - disc[3]
			if gap >= -TOLERANCE and gap <= TOLERANCE and not Elsewhere(point, TOLERANCE) then own = own + 1 end
		end
		return own < SPARE
	end
	local function Prune(list)
		local index = 1
		while list[2] and index <= #list do
			if Idle(list, index) then
				table.remove(list, index)
				index = 1
			else
				index = index + 1
			end
		end
		return list, Misfit(list)
	end

	-- Là où deux points du jeu répondent ensemble, l'infobulle écrit leur nom deux fois, une rangée
	-- chacun. Deux disques dont le recouvrement a été essayé sans que le nom y soit jamais écrit deux
	-- fois sont donc un seul point du jeu, qui ne répond pas en rond : ils n'en font qu'un, entre eux,
	-- assez grand pour couvrir les deux (le quatrième champ le dit : son rayon n'est pas une mesure).
	-- (Vu en jeu le 2026-10-15, deux fois : un Pacifique, puis une Terrestrine, montrés par deux icônes
	-- « dans un groupe », à dix unités l'une de l'autre, du rayon des autres plantes ; chaque fois, le
	-- point sous la souris portait la flèche d'un nœud plus bas que le joueur. Dans le faux client, un
	-- point qui répond 1,2 fois plus loin en largeur qu'en hauteur donne ainsi deux icônes à chaque
	-- balayage : la forme seule du groupe ne les distingue pas de deux points ronds, à la finesse du
	-- regard de près.) Que le jeu écrive deux fois le nom de deux points qui se recouvrent n'a pas été
	-- vu, et s'il ne le faisait pas, deux nœuds proches n'auraient plus qu'une icône (dans le faux
	-- client, plus de la moitié des paires serrées). Lueur ne s'y fie donc qu'une fois qu'il l'a vu faire,
	-- ou pour une flèche : les trois doublons vus en jeu en étaient, et deux flèches du même nom qui se
	-- recouvrent sont rares.
	local twice = job.many[job.place.name] or {}
	local trusted = Doubled() or job.arrows[job.place.name] == true
	local function Alone(a, b)
		local shared = 0
		for _, point in ipairs(inside) do
			if (point[1] - a[1]) ^ 2 + (point[2] - a[2]) ^ 2 <= (a[3] - SHARED_IN) ^ 2
				and (point[1] - b[1]) ^ 2 + (point[2] - b[2]) ^ 2 <= (b[3] - SHARED_IN) ^ 2 then
				if twice[point[4]] then return false end
				shared = shared + 1
			end
		end
		return shared >= MIN_SHARED
	end
	local function Join(list)
		if not list or not trusted then return list end
		local index = 1
		while list[2] and index < #list do
			local a, joined = list[index], false
			for other = index + 1, #list do
				local b = list[other]
				if Alone(a, b) then
					-- son centre est le milieu des points du groupe que ces deux disques couvraient, son
					-- rayon va jusqu'au plus éloigné
					local sx, sy, count, mine = 0, 0, 0, {}
					for _, point in ipairs(inside) do
						if (point[1] - a[1]) ^ 2 + (point[2] - a[2]) ^ 2 <= (a[3] + 1) ^ 2
							or (point[1] - b[1]) ^ 2 + (point[2] - b[2]) ^ 2 <= (b[3] + 1) ^ 2 then
							sx, sy, count = sx + point[1], sy + point[2], count + 1
							mine[#mine + 1] = point
						end
					end
					local x, y, radius = sx / count, sy / count, 0
					for _, point in ipairs(mine) do radius = math.max(radius, math.sqrt((point[1] - x) ^ 2 + (point[2] - y) ^ 2)) end
					list[index] = { x, y, radius + 1, true }
					table.remove(list, other)
					joined = true
					break
				end
			end
			if joined then index = 1 else index = index + 1 end
		end
		return list
	end

	-- Un point du jeu peut répondre dans un carré, et non dans un disque : vu en jeu le 2026-10-15
	-- (/lueur scan, la zone d'une Terrestrine : 22 unités de côté, à bords droits ; les rayons lus de
	-- 11 à 14 unités pour les autres plantes le disent aussi). Un carré seul se lit parfois comme deux
	-- disques côte à côte, à dix unités l'un de l'autre : les doublons de ce jour-là, alignés comme
	-- ceux du faux client (un carré seul sur dix, en largeur ou en hauteur). Les points d'un groupe
	-- qui remplissent leur rectangle, presque carré, sont donc ce seul point : un disque en son milieu,
	-- qui couvre le carré. Deux points ronds qui se recouvrent laissent vides les coins du rectangle,
	-- et deux carrés côte à côte en font un rectangle allongé.
	local function Square(list)
		if not list or not list[2] then return list end
		local x0, y0, x1, y1, mine = math.huge, math.huge, -math.huge, -math.huge, {}
		for _, point in ipairs(inside) do
			x0, y0, x1, y1 = math.min(x0, point[1]), math.min(y0, point[2]), math.max(x1, point[1]), math.max(y1, point[2])
			mine[point[4]] = true
		end
		local wide, tall = x1 - x0 + FINE, y1 - y0 + FINE
		if math.max(wide, tall) > SQUARE_RATIO * math.min(wide, tall) then return list end
		-- ni plus grand qu'un point du jeu : deux carrés serrés en font un rectangle plus large
		if math.max(wide, tall) > 2 * reaches[job.place.node.kind].value + FINE then return list end
		local asked, answered = 0, 0
		for _, key in ipairs(job.points) do
			local x, y = key % ROW * FINE, math.floor(key / ROW) * FINE
			if x >= x0 and x <= x1 and y >= y0 and y <= y1 then
				asked = asked + 1
				if mine[key] then answered = answered + 1 end
			end
		end
		if answered < SQUARE_FILL * asked then return list end
		return { { (x0 + x1) / 2, (y0 + y1) / 2, math.sqrt(wide * wide + tall * tall) / 2, true } }
	end

	-- La seconde lecture ne se fait que si elle peut l'emporter : elle est retenue si elle explique
	-- bien le groupe, et nettement mieux que la première.
	local own, left = Read(), math.huge
	if own then own, left = Prune(own) end
	local known = reaches[job.place.node.kind]
	if known.measured and left >= CLEARLY then
		local same = Read(known.value)
		if same then
			local rest
			same, rest = Prune(same)
			if rest <= WELL and rest + CLEARLY <= left then return Join(Square(same)) end
		end
	end
	return Join(Square(own))
end

-- Un groupe que ce balayage ne regardera pas de près, pour ne pas y passer trop de temps : les nœuds
-- déjà bien placés qui le touchent y restent ; à défaut il a une place, son milieu.
local function Rough(places, place, map)
	local mine = map and Placed(place.name, place.keys, map) or {}
	if not mine[1] then
		places[#places + 1] = place
		return
	end
	for _, marker in ipairs(mine) do
		places[#places + 1] = { name = place.name, node = place.node, set = place.set, pin = marker }
	end
end

-- La grille est faite : chaque groupe de points d'un nœud voulu devient une place, exacte tout
-- de suite si un balayage précédent la connaît, sinon à affiner ou à regarder de près
local function Sort()
	local places, refines, jobs, fine = {}, {}, {}, 0
	local map = MapPosition() -- sans carte, une place ne se garde pas d'un balayage à l'autre

	local heard = {} -- les métiers dont ce balayage a lu au moins un nom
	lastNames = {}
	for name, set in pairs(scan.hits) do
		local points, gray = 0, false
		for _, value in pairs(set) do
			points = points + 1
			if value == 2 then gray = true end
		end
		lastNames[name] = { points = points, gray = gray }
		local node = ns.NodeOf(name)
		if node then heard[node.kind] = true end
		if node and Wanted(node.kind) then
			for _, keys in ipairs(Groups(set)) do
				local x0, y0, x1, y1, x, y = Box(keys)
				local place = { name = name, node = node, set = set, keys = keys, x = x, y = y, box = { x0, y0, x1, y1 } }
				-- ce qu'un disque seul couvre au plus de grille : tout groupe qui pourrait en être un est
				-- essayé comme tel, quel que soit le rayon des nœuds déjà mesurés
				local span = 2 * MAX_REACH + 1
				local single = x1 - x0 <= span and y1 - y0 <= span
				local pin = map and Pinned(name, x, y, math.max(x1 - x0, y1 - y0)) or nil
				-- placé quand le bord de la minimap le tronquait, et tout entier dedans désormais :
				-- son centre peut se chercher par ses bords
				if pin and pin.rim and math.sqrt((x - width / 2) ^ 2 + (y - width / 2) ^ 2) + Radius(pin) + STEP < width / 2 then
					pin = nil
				end
				local split = map and not pin and Known(name, keys) or nil
				if map and not pin and not split and AtRim(keys) then
					-- Au bord de la minimap la place d'un nœud se lit mal, et son disque tronqué passe pour
					-- plusieurs : les nœuds déjà bien placés qui expliquent ce groupe à eux seuls y restent.
					local mine, whole = Placed(name, keys, map)
					if whole then split = mine end
				end
				if pin then
					place.pin, place.single = pin, true
					places[#places + 1] = place
				elseif split then
					for _, marker in ipairs(split) do
						places[#places + 1] = { name = name, node = node, set = set, pin = marker }
					end
				elseif single then
					refines[#refines + 1] = place
					places[#places + 1] = place
				else
					local job = NewJob(place, x0, y0, x1, y1)
					if fine + #job.points <= MAX_FINE or (fine == 0 and #job.points <= 3 * MAX_FINE) then
						fine = fine + #job.points
						jobs[#jobs + 1] = job
					else
						Rough(places, place, map)
					end
				end
			end
		end
	end
	scan.places, scan.refines, scan.jobs, scan.fine, scan.map, scan.heard = places, refines, jobs, fine, map, heard
	scan.phase = "refine"
end

-- Un nœud d'un groupe est-il dans une grotte ? Là où plusieurs nœuds du groupe répondent, le jeu
-- écrit leur nom une fois par nœud, en gris ou non, sans dire lequel est lequel : on s'en tient
-- donc aux points où celui-ci répond seul, et à défaut à son centre.
local function GrayOf(job, set, discs, disc)
	local gray, plain = 0, 0
	for _, key in ipairs(job.points) do
		local value = set[key]
		if value then
			local x, y = key % ROW * FINE, math.floor(key / ROW) * FINE
			local alone = (x - disc[1]) ^ 2 + (y - disc[2]) ^ 2 <= disc[3] * disc[3]
			for _, other in ipairs(discs) do
				if other ~= disc and (x - other[1]) ^ 2 + (y - other[2]) ^ 2 <= other[3] * other[3] then alone = false end
			end
			if alone then
				if value == 2 then gray = gray + 1 else plain = plain + 1 end
			end
		end
	end
	if gray + plain == 0 then return GrayAt(set, disc[1], disc[2], FINE) end
	return gray > plain
end

-- Un groupe regardé de près donne ses nœuds, ou à défaut son milieu
local function EndJob(job)
	local place = job.place
	local discs = Fit(job)
	local set = job.hits[place.name]
	scan.looked = scan.looked + 1
	if discs then
		-- un seul nœud, tout entier dans la minimap : son disque dit de combien un point de ce métier répond
		local alone = #discs == 1
		if alone and not discs[1][4] and not place.rim and not AtRim(place.keys) then Learn(place.node.kind, discs[1][3]) end
		for _, disc in ipairs(discs) do
			scan.places[#scan.places + 1] = { name = place.name, node = place.node, set = place.set, keys = place.keys, x = disc[1], y = disc[2],
				fitted = not alone, exact = alone, reach = disc[3], rim = place.rim, gray = GrayOf(job, set, discs, disc) }
		end
	else
		scan.places[#scan.places + 1] = place
	end
end

-- Un point de la grille de cet ensemble est-il à moins de `range` unités de (x, y) ? L'ensemble est
-- ce qu'un nom a répondu (numéro du point -> valeur), ou la liste des points d'un groupe (`list`).
local function Heard(set, x, y, range, list)
	if not set then return false end
	for first, second in pairs(set) do
		local key = list and second or first
		if (key % ROW * STEP - x) ^ 2 + (math.floor(key / ROW) * STEP - y) ^ 2 <= range * range then return true end
	end
	return false
end

-- Le balayage est fait : ses places deviennent les nœuds connus. Chaque place est, dans l'ordre,
-- le nœud déjà placé là (`pin`), sinon le nœud connu du même nom le plus proche d'elle, sinon un
-- nœud nouveau. Un nœud connu reste le même objet d'un balayage à l'autre : il garde son icône,
-- et sa place ne change que pour une mesure meilleure que celle qu'il a.
local function Finish()
	local half = width / 2
	local radius, turning, facing = View()
	local map, px, py, wide, tall = MapPosition()
	local anchored = map ~= nil and radius ~= nil and not (turning and not facing)
	local found, claimed, loose, fresh, again = {}, {}, {}, false, false

	local function Keep(marker, place)
		claimed[marker] = true
		-- ce que Lueur sait de ce nom a pu changer depuis : l'objet d'une plante que le client vient de charger
		marker.node, marker.held, marker.missed = place.node, nil, 0
		found[#found + 1] = marker
	end
	for _, place in ipairs(scan.places) do
		local marker = place.pin
		if not marker then
			loose[#loose + 1] = place
		elseif not claimed[marker] then
			Keep(marker, place)
			marker.age = marker.age + 1
			if place.single then marker.fitted = nil end
			-- (un nœud d'un groupe garde ce que le regard de près en a dit : la grille ne sépare pas
			-- le gris de l'un de celui de son voisin)
			if not marker.fitted then
				local gray = GrayAt(place.set, marker.x, marker.y, STEP)
				if gray ~= nil then marker.gray = gray end
			end
		end
	end

	-- Les autres places, chacune avec sa place sur la carte de la zone, et ce qui la sépare de chaque
	-- nœud connu du même nom : en mètres sur la carte, en unités de minimap sans elle
	local perYard = anchored and half / radius or 1 -- unités de minimap par unité d'écart
	local matches = {}
	for _, place in ipairs(loose) do
		-- Deux nœuds du même nom à moins d'un rayon de disque l'un de l'autre répondent ensemble, et un
		-- balayage les place tous les deux : une place seule, aussi près d'un nœud connu, est ce nœud.
		-- Au bord de la minimap le disque d'un nœud est tronqué, sa place mal lue, et son contour passe
		-- parfois pour deux nœuds : c'est de plus loin qu'une place vue là est le nœud que l'on connaît.
		local reach = place.reach or reaches[place.node.kind].value
		local limit = math.max(anchored and MERGE or 0, reach / perYard)
		local rimLimit = limit + 2 * reach / perYard
		place.depth = half - math.sqrt((place.x - half) ^ 2 + (place.y - half) ^ 2)
		if anchored then
			local dx, dy = place.x - half, place.y - half
			local yards = math.sqrt(dx * dx + dy * dy) / half * radius
			local way = math.atan2(dx, dy) -- sens des aiguilles depuis le haut de la minimap
			if turning then way = way - facing end
			place.yards = yards
			place.mx, place.my = px + yards * math.sin(way) / wide, py - yards * math.cos(way) / tall
		end
		for _, old in ipairs(markers) do
			if not claimed[old] and old.name == place.name and old.map == (anchored and map or nil) then
				local gap
				if anchored then
					gap = math.sqrt(((old.mx - place.mx) * wide) ^ 2 + ((old.my - place.my) * tall) ^ 2)
				else
					gap = math.sqrt((old.x - place.x) ^ 2 + (old.y - place.y) ^ 2)
				end
				-- (de plus loin, seulement si ce nœud peut être ce qui a répondu là : son disque touche le groupe)
				if gap <= limit or ((place.rim or old.rim) and gap <= rimLimit and Heard(place.keys, old.x, old.y, Radius(old) + STEP / 2 + 1, true)) then
					matches[#matches + 1] = { gap = gap, place = place, marker = old }
				end
			end
		end
	end
	table.sort(matches, function(a, b) return a.gap < b.gap end)

	-- Donne à un nœud la place d'une mesure, `weight` fois moins lourde que celle qu'il avait (0 : elle
	-- la remplace). Son icône part d'où elle était.
	local function Put(marker, place, weight)
		if anchored then
			local mx, my = (marker.mx * weight + place.mx) / (weight + 1), (marker.my * weight + place.my) / (weight + 1)
			marker.dmx, marker.dmy = (marker.dmx or 0) + marker.mx - mx, (marker.dmy or 0) + marker.my - my
			marker.mx, marker.my = mx, my
		else
			marker.x, marker.y = (marker.x * weight + place.x) / (weight + 1), (marker.y * weight + place.y) / (weight + 1)
		end
		marker.count = weight + 1
	end
	for _, match in ipairs(matches) do
		local place, marker = match.place, match.marker
		if not place.marker and not claimed[marker] then
			place.marker = marker
			Keep(marker, place)
			local gray = place.gray
			if gray == nil then gray = GrayAt(place.set, place.x, place.y, STEP) end
			if gray ~= nil then marker.gray = gray end
			local units = match.gap * perYard
			local worth, had = Worth(place), marker.worth
			local weight -- ce que pèse la place connue devant la nouvelle ; nil : elle reste
			if worth > had then
				weight = 0
			elseif worth < had then
				-- une mesure qui vaut moins ne déplace pas un nœud, sauf le regard de près qui trouve loin
				-- de lui un nœud que ses bords disaient seul : c'étaient deux nœuds pris pour un
				if worth == FITTED and units >= SLACK then weight = 0 end
			elseif worth == SURE then
				-- retrouvé là à l'erreur de mesure près : il n'en bouge pas
				if units >= STILL then weight = 0 end
			elseif worth == RIM_PLACE then
				-- au bord, la meilleure des deux est celle qui a vu le plus du disque : la plus à l'intérieur
				if place.depth > marker.depth + 1 then weight = 0 end
			else
				-- deux places approchées changent un peu à chaque balayage : elles se moyennent
				weight = math.min(marker.count, AVERAGE)
			end
			if weight then
				Put(marker, place, weight)
				marker.exact, marker.fitted, marker.rim, marker.worth, marker.depth = place.exact, place.fitted, place.rim, worth, place.depth
				marker.reach = place.reach or marker.reach
			elseif place.fitted then
				marker.fitted = true -- il fait partie d'un groupe séparé : Known s'en servira
			end
			if place.fitted or place.exact then marker.age = 0 end
		end
	end
	for _, place in ipairs(loose) do
		if not place.marker then
			local gray = place.gray
			if gray == nil then gray = GrayAt(place.set, place.x, place.y, STEP) end
			found[#found + 1] = { name = place.name, node = place.node, x = place.x, y = place.y, gray = gray or false,
				exact = place.exact, fitted = place.fitted, rim = place.rim, worth = Worth(place), depth = place.depth, reach = place.reach,
				age = 0, count = 1, missed = 0, far = false, born = GetTime(),
				map = anchored and map or nil, mx = place.mx, my = place.my, yards = place.yards }
			fresh = true
		end
	end

	-- Les nœuds connus que ce balayage n'a pas retrouvés. Aucun ne reste à côté de ce que le balayage a
	-- vu : un nœud ne se montre jamais deux fois. (Vu en jeu le 2026-10-13, avec l'alternance : « la
	-- minimap affiche souvent la même ressource plusieurs fois ». Un nœud non retrouvé restait alors
	-- deux balayages, et sans limite tant que les pistages s'alternaient à moins de trois secondes.)
	local other = turn.kind and anchored and (turn.kind == "herb" and "ore" or "herb") or nil
	local now = GetTime()
	local picked = pickedAt ~= nil and now - pickedAt <= PICK_TIME
	local sighted = #found -- jusque-là, `found` ne tient que ce que ce balayage a vu
	for _, old in ipairs(markers) do
		if not claimed[old] then
			local kind, keep = old.node.kind, false
			local twin = false -- le balayage a-t-il placé un nœud du même nom tout près ? C'est alors lui
			for index = 1, sighted do
				local near = found[index]
				if near.name == old.name and (near.x - old.x) ^ 2 + (near.y - old.y) ^ 2 < (TWIN * Radius(old)) ^ 2 then twin = true end
			end
			if twin or old.map ~= map or not Wanted(kind) then
				-- en double, resté sur une autre carte, ou plus voulu
			elseif kind == other then
				-- Alternance des pistages : le métier éteint n'a pas de points par où le trouver. Ses nœuds
				-- restent donc comme ils étaient jusqu'à son tour. Sauf celui dont le nom a répondu près de
				-- lui : ses points se voyaient encore, et le balayage en a fait un autre nœud que lui.
				keep = not Heard(scan.hits[old.name], old.x, old.y, Radius(old) + STEP)
				old.held = keep or nil
			elseif not old.far and not scan.heard[kind] then
				-- Le balayage n'a lu aucun nom de ce métier : les points du jeu tardent après un changement
				-- de pistage, ou l'infobulle n'a rien répondu. Ses nœuds ne s'en vont qu'au second balayage
				-- de suite dans ce cas. Sauf celui que le joueur vient de récolter, et celui posé faute de
				-- mieux au milieu d'un groupe.
				old.missed = (old.missed or 0) + 1
				keep = old.missed < MISSES and old.worth > ROUGH and not (picked and old.yards ~= nil and old.yards <= PICK_REACH)
				again = again or keep
			end
			-- (dans tout autre cas le balayage a lu des nœuds de ce métier, et pas celui-ci : il n'est plus là)
			if keep then found[#found + 1] = old else Fade(old) end
		end
	end

	turn.scanned = true
	-- À l'arrêt, rien n'entre par le bord de la minimap : sans rien de neuf, le balayage s'espace
	local moved = map ~= spot.map or px ~= spot.x or py ~= spot.y
	spot.map, spot.x, spot.y = map, px, py
	if fresh or moved or again then slow = 1 else slow = math.min(slow * 2, MAX_SLOW) end
	wait = WAIT * slow
	last.points, last.seconds, last.jobs = probes - scan.probes, now - scan.started, scan.looked
	markers, scan, refit = found, nil, false
	seen.map = nil -- le suivi replace tout à la prochaine image
	ns.ForgetSkills()
	Draw()
end

-- Fait avancer le balayage d'une image. La souris fictive n'est allumée que pendant cet appel.
local function Advance()
	if scan.phase == "grid" then
		for index = scan.next, math.min(scan.next + PER_FRAME - 1, #grid) do
			local key = grid[index]
			Probe(key % ROW * STEP, math.floor(key / ROW) * STEP, scan.hits, key)
		end
		scan.next = scan.next + PER_FRAME
		if scan.next > #grid then Sort() end
	elseif scan.refines[1] then
		do -- une place par image : elle demande autant d'essais qu'une image de grille
			local place = table.remove(scan.refines)
			Refine(place)
			if place.merged or place.rim then
				-- pas un disque seul, malgré sa taille, ou un disque que le bord de la minimap tronque :
				-- ses nœuds seront cherchés par son contour, avec les gros groupes
				for index, other in ipairs(scan.places) do
					if other == place then
						table.remove(scan.places, index)
						break
					end
				end
				local job = NewJob(place, place.box[1], place.box[2], place.box[3], place.box[4])
				if scan.fine + #job.points <= MAX_FINE or (scan.fine == 0 and #job.points <= 3 * MAX_FINE) then
					scan.fine = scan.fine + #job.points
					scan.jobs[#scan.jobs + 1] = job
				else
					Rough(scan.places, place, scan.map)
				end
			end
		end
	elseif scan.jobs[1] then
		local job = scan.jobs[1]
		for index = job.next, math.min(job.next + PER_FRAME - 1, #job.points) do
			local key = job.points[index]
			Probe(key % ROW * FINE, math.floor(key / ROW) * FINE, job.hits, key, job)
		end
		job.next = job.next + PER_FRAME
		if job.next > #job.points then
			table.remove(scan.jobs, 1)
			EndJob(job)
		end
	else
		Finish()
	end
end

---------------------------------------------------------------------------
-- Pistages, et leur alternance
---------------------------------------------------------------------------

-- Les métiers dont le pistage est actif, et la place de chaque pistage de récolte dans la liste
-- du jeu ; nil si le jeu ne le dit pas
local function Finders()
	local count = SafeCall(C_Minimap.GetNumTrackingTypes)
	if type(count) ~= "number" then return nil end
	local on, listed = {}, {}
	for index = 1, count do
		local info = SafeCall(C_Minimap.GetTrackingInfo, index)
		if type(info) == "table" then
			local spell, active = info.spellID, info.active
			if IsSecret(spell) or IsSecret(active) then return nil end
			local kind = spell and FINDERS[spell]
			if kind then
				listed[kind] = index
				if active then on[kind] = true end
			end
		end
	end
	return on, listed
end

local function Casting(read)
	if not read then return false end
	local ok, name = pcall(read, "player")
	return ok and (IsSecret(name) or name ~= nil)
end

-- Changer de pistage lance un sort : pas pendant que le joueur récolte, incante ou fouille
local function Busy()
	return looting or Casting(UnitCastingInfo) or Casting(UnitChannelInfo)
end

-- Demande au jeu d'allumer le pistage de ce métier (`index`, dans la liste du jeu). Le jeu lance
-- un sort : le pistage ne change qu'un instant plus tard (Blizzard_Minimap le dit de son propre
-- menu), et pas du tout si le sort n'était pas prêt. Renvoie true si la demande est partie.
local function Ask(kind, index)
	turn.want, turn.at, turn.tries = kind, GetTime(), (turn.tries or 0) + 1
	return (pcall(C_Minimap.SetTracking, index, true))
end

-- Deux métiers de récolte : le jeu ne montre les points que d'un pistage à la fois. Lueur allume
-- donc l'autre quand le joueur s'est éloigné d'assez du lieu de la dernière bascule, un balayage
-- au moins ayant eu lieu entre-temps. Renvoie true s'il l'a demandé.
local function Switch(kind, index)
	if not C_Minimap.SetTracking or Busy() then return false end
	local map, x, y, wide, tall = MapPosition()
	if not map then return false end
	if map ~= turn.map then -- autre carte : la distance se compte d'ici
		turn.map, turn.x, turn.y = map, x, y
		return false
	end
	local east, north = (x - turn.x) * wide, (y - turn.y) * tall
	local yards = ns.GetOption("nodeSwitchYards")
	if not turn.scanned or east * east + north * north < yards * yards then return false end
	turn.x, turn.y, turn.scanned, turn.tries = x, y, false, 0
	return Ask(kind, index)
end

local function StartScan()
	wait = WAIT * slow
	-- ni en combat, ni la minimap cachée, ni la vraie souris dessus : la souris fictive changerait
	-- ce que son infobulle montre
	if InCombatLockdown() or not Minimap:IsVisible() or Minimap:IsMouseOver() then return end
	-- le pistage vient de changer : les points du jeu ne sont pas encore ceux qu'il montre
	local since = turn.changed and GetTime() - turn.changed
	if since and since < SWITCH_SETTLE then
		wait = SWITCH_SETTLE - since
		return
	end
	local on, listed = Finders()
	turn.kind = nil
	if on then
		local alternating = ns.GetOption("nodeSwitch") and Wanted("herb") and Wanted("ore") and listed.herb and listed.ore
		if turn.want then
			if on[turn.want] or not alternating then
				turn.want = nil -- la bascule a eu lieu, ou n'a plus lieu d'être
			elseif GetTime() - turn.at >= SWITCH_RETRY then
				-- Le jeu n'a pas fait la bascule demandée : le sort n'était pas prêt. Elle est redemandée,
				-- quelques fois ; après quoi ce sera pour la prochaine.
				if turn.tries >= SWITCH_TRIES then
					turn.want = nil
				elseif C_Minimap.SetTracking and not Busy() then
					Ask(turn.want, listed[turn.want])
					wait, slow = SWITCH_WAIT, 1
					return
				end
			end
		end
		if alternating and (on.herb == true) ~= (on.ore == true) then
			turn.kind = on.herb and "herb" or "ore"
			local other = on.herb and "ore" or "herb"
			if not turn.want and Switch(other, listed[other]) then
				wait, slow = SWITCH_WAIT, 1
				return
			end
		end
		if not ((on.herb and Wanted("herb")) or (on.ore and Wanted("ore"))) then
			if turn.want then
				-- entre deux pistages, le temps que le sort de la bascule parte : rien ne s'efface
				wait = SWITCH_POLL
				return
			end
			-- rien à trouver sur la minimap
			wait = IDLE_WAIT
			Clear()
			return
		end
	end
	left, bottom, scale, width = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale(), Minimap:GetWidth()
	if not (left and bottom and scale and width) or width <= 0 then return end
	if gridWidth ~= width then
		gridWidth, grid = width, {}
		local half = width / 2
		for column = 0, math.floor(width / STEP) do
			for line = 0, math.floor(width / STEP) do
				local dx, dy = column * STEP - half, line * STEP - half
				if dx * dx + dy * dy <= half * half then grid[#grid + 1] = column + ROW * line end
			end
		end
	end
	scan = { phase = "grid", next = 1, hits = {}, probes = probes, started = GetTime(), looked = 0 }
end

local function Lit()
	Minimap:SetUsingSoftCursor(true)
	Advance()
end

local function OnUpdate(_, elapsed)
	if scan then
		left, bottom, scale = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale()
		if InCombatLockdown() or not Minimap:IsVisible() or Minimap:IsMouseOver() or not (left and bottom and scale) then
			scan, wait = nil, WAIT
		else
			local ok, problem = pcall(Lit)
			pcall(Minimap.SetUsingSoftCursor, Minimap, false)
			if not ok then
				-- le jeu refuse : on n'insiste pas, et /lueur scan dit pourquoi
				broken, scan = tostring(problem), nil
				ns.UpdateNodes()
				if ns.Refresh then ns.Refresh() end -- Menu.lua : la page de la minimap se grise
				return
			end
		end
	else
		wait = wait - elapsed
		if wait <= 0 then StartScan() end
	end
	Follow(elapsed)
end

---------------------------------------------------------------------------
-- Infobulle de la minimap
---------------------------------------------------------------------------

-- La souris sur un nœud que la compétence du joueur ne permet pas de récolter : sous son nom,
-- ce qu'il demande, écrit comme le jeu l'écrit pour un objet inutilisable
local function OnTooltip(tooltip, data)
	if not (ns.db and ns.db.enabled) or IsSecret(data) or type(data) ~= "table" then return end
	local lines = data.lines
	if IsSecret(lines) or type(lines) ~= "table" then return end
	local said
	for _, line in ipairs(lines) do
		local text = line.leftText
		if not IsSecret(text) and type(text) == "string" then
			for _, entry in ipairs(Names(text)) do
				local node = ns.NodeOf(entry.name)
				local needs = node and Wanted(node.kind) and ns.NodeRequirement(node)
				if needs and not (said and said[needs]) then
					said = said or {}
					said[needs] = true
					pcall(tooltip.AddLine, tooltip, needs, ns.DifficultyColor("impossible"))
				end
			end
		end
	end
end

local function HookTooltip()
	if hooked then return end
	local kind = Enum and Enum.TooltipDataType and Enum.TooltipDataType.MinimapMouseover
	if kind and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
		hooked = pcall(TooltipDataProcessor.AddTooltipPostCall, kind, OnTooltip)
	end
end

---------------------------------------------------------------------------
-- Liens avec Lueur.lua et avec le jeu
---------------------------------------------------------------------------

-- Appelée par Lueur.lua quand un réglage des icônes change, et quand Lueur s'allume ou s'éteint :
-- lance ou arrête le balayage, qui repart de zéro
function ns.UpdateNodes()
	if not ns.db then return end
	local on = ns.db.enabled and (Wanted("herb") or Wanted("ore")) and not Failure()
	scan, wait, slow = nil, 0, 1
	turn.map, turn.kind, turn.want = nil, nil, nil
	if on then
		if not holder then
			holder = CreateFrame("Frame", nil, Minimap)
			holder:SetAllPoints(Minimap)
		end
		HookTooltip()
		-- sans alternance, plus rien ne justifie de garder les nœuds d'un pistage éteint
		if not ns.GetOption("nodeSwitch") then
			for index = #markers, 1, -1 do
				if markers[index].held then Free(table.remove(markers, index)) end
			end
		end
	else
		Clear()
	end
	driver:SetScript("OnUpdate", on and OnUpdate or nil)
	Draw()
end

local handlers = {}

function handlers.PLAYER_LOGIN()
	ns.UpdateNodes()
end

-- Un écran de chargement : le joueur est peut-être ailleurs
function handlers.PLAYER_ENTERING_WORLD()
	scan, wait, slow = nil, 0, 1
	Clear()
end

-- Le joueur se met en route, zoome la minimap ou change de pistage : le prochain balayage ne tarde pas
local function Hurry(delay)
	slow = 1
	if wait > delay then wait = delay end
end

function handlers.PLAYER_STARTED_MOVING() Hurry(WAIT) end
function handlers.MINIMAP_UPDATE_ZOOM() Hurry(WAIT) end
function handlers.MINIMAP_UPDATE_TRACKING()
	turn.changed = GetTime()
	Hurry(SWITCH_WAIT)
end

function handlers.LOOT_OPENED()
	looting = true
end

-- Le butin se referme. Si c'était celui d'un nœud, son point du jeu va disparaître : on balaie
-- sans attendre. Et l'icône gardée d'un pistage éteint, que nul balayage ne verra partir avant
-- son tour, s'en va tout de suite.
function handlers.LOOT_CLOSED()
	looting, refit, pickedAt = false, true, GetTime()
	Hurry(0)
	local kind = ns.LastNodeKind(PICK_TIME)
	if not kind then return end
	for index = #markers, 1, -1 do
		local marker = markers[index]
		if marker.held and marker.node.kind == kind and marker.yards and marker.yards <= PICK_REACH then
			Fade(table.remove(markers, index))
		end
	end
end

-- La compétence a changé : les couleurs aussi, peut-être
function handlers.SKILL_LINES_CHANGED()
	ns.ForgetSkills()
	Draw()
end

driver:SetScript("OnEvent", function(_, event)
	if ns.db then handlers[event]() end
end)
for event in pairs(handlers) do
	pcall(driver.RegisterEvent, driver, event)
end

---------------------------------------------------------------------------
-- Diagnostic (/lueur scan)
---------------------------------------------------------------------------

local function SkillText(kind)
	local skill = ns.GatherSkill(kind)
	if not skill then return "?" end
	return skill.total == skill.rank and tostring(skill.rank) or ("%d (%d)"):format(skill.total, skill.rank)
end

-- Les champs d'une table du jeu, sauf ceux de `skip` : « nom = valeur », triés. Pour voir ce que le
-- jeu dit d'un point de la minimap en plus de son nom.
local function Fields(value, skip)
	local parts = {}
	for key, item in pairs(value) do
		if not skip[key] then
			local text = "?"
			if not IsSecret(item) then text = type(item) == "table" and "{…}" or tostring(item) end
			parts[#parts + 1] = tostring(key) .. " = " .. text
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local TEXT_FIELDS = { lines = true, leftText = true, leftColor = true, rightColor = true, args = true }
local SCAN_LINES = 12     -- icônes que /lueur scan détaille

-- Ce que l'infobulle de la minimap dit sous la vraie souris, tel que le jeu l'écrit ; et tout ce que
-- ses données portent d'autre que ce texte. Le jeu ne documente pas ces données : s'il y glissait
-- un identifiant du point, c'est là qu'il se verrait.
-- Le troisième résultat est le premier nom lu, et le quatrième, où est la souris : en pixels d'écran.
local function UnderPointer()
	if InCombatLockdown() or not GetCursorPosition then return nil end
	local texts, others, first, cursor = {}, {}, nil, nil
	pcall(function()
		local x, y = GetCursorPosition()
		cursor = { x, y }
		Minimap:SetUsingSoftCursor(true)
		Minimap:UpdateMouseoverAtPoint(x, y)
		local data = SafeCall(C_TooltipInfo.GetMinimapMouseover)
		local lines = type(data) == "table" and data.lines
		if IsSecret(lines) or type(lines) ~= "table" then return end
		others[1] = Fields(data, TEXT_FIELDS)
		for index, line in ipairs(lines) do
			local text = line.leftText
			if not IsSecret(text) and type(text) == "string" then
				texts[#texts + 1] = (text:gsub("|", "||"):gsub("\n", " / "))
				first = first or (Names(text)[1] or {}).name
			end
			local more = Fields(line, TEXT_FIELDS)
			if type(line.args) == "table" then
				for _, arg in ipairs(line.args) do
					if type(arg) == "table" then more = more .. (more ~= "" and ", " or "") .. "args { " .. Fields(arg, {}) .. " }" end
				end
			end
			if more ~= "" then others[#others + 1] = ("%d { %s }"):format(index, more) end
		end
	end)
	pcall(Minimap.SetUsingSoftCursor, Minimap, false)
	if not texts[1] then return nil end
	return table.concat(texts, " // "), table.concat(others, " ; "), first, cursor
end

-- La zone où le jeu nomme le point sous la souris, essayée toutes les ZONE_STEP unités autour
-- d'elle : une fois colonne par colonne, comme le balayage, puis rangée par rangée. Ce que le jeu
-- répond ne devrait pas dépendre de l'ordre des essais, et un point du jeu devrait répondre dans un
-- disque : sa largeur, sa hauteur, son milieu, ses rangées et les points où le nom est écrit deux
-- fois le disent. (Ajouté le 2026-10-15 : des nœuds montrés en deux icônes, toujours à dix unités
-- l'une de l'autre sur une même rangée, que le faux client ne fait qu'avec une zone allongée.)
local ZONE_STEP, ZONE_REACH = 2, 34

local function Zone(name, cursor)
	left, bottom, scale, width = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale(), Minimap:GetWidth()
	if not (left and bottom and scale and width) then return end
	local px, py = cursor[1] / scale - left, cursor[2] / scale - bottom
	local size = math.floor(ZONE_REACH / ZONE_STEP)
	local rows -- de la première passe : rangée -> plus petit et plus grand écart en largeur qui a répondu
	for pass = 1, 2 do
		local hits, job = {}, { many = {}, arrows = {} }
		pcall(function()
			Minimap:SetUsingSoftCursor(true)
			for outer = -size, size do
				for inner = -size, size do
					local column, line = outer, inner
					if pass == 2 then column, line = inner, outer end
					if column * column + line * line <= size * size then
						Probe(px + column * ZONE_STEP, py + line * ZONE_STEP, hits, (column + size) + ROW * (line + size), job)
					end
				end
			end
		end)
		pcall(Minimap.SetUsingSoftCursor, Minimap, false)
		local set, count, sx, sy = hits[name] or {}, 0, 0, 0
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		local spans = {}
		for key in pairs(set) do
			local x, y = (key % ROW - size) * ZONE_STEP, (math.floor(key / ROW) - size) * ZONE_STEP
			count, sx, sy = count + 1, sx + x, sy + y
			x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
			local span = spans[y] or { x, x }
			spans[y] = { math.min(span[1], x), math.max(span[2], x) }
		end
		local twice = 0
		for _ in pairs(job.many[name] or {}) do twice = twice + 1 end
		if count == 0 then return end
		print("  " .. L.SCAN_ZONE:format(name, pass == 1 and L.SCAN_ZONE_COLUMNS or L.SCAN_ZONE_ROWS, count,
			x1 - x0 + ZONE_STEP, y1 - y0 + ZONE_STEP, sx / count, sy / count, twice))
		rows = rows or spans
	end
	-- les rangées, du haut vers le bas, une sur deux
	local list, ys = {}, {}
	for y in pairs(rows) do ys[#ys + 1] = y end
	table.sort(ys, function(a, b) return a > b end)
	for index = 1, #ys, 2 do
		local y = ys[index]
		list[#list + 1] = ("%+d: %+d..%+d"):format(y, rows[y][1], rows[y][2])
	end
	print("  " .. L.SCAN_ZONE_LINES:format(table.concat(list, " | ")))
end

-- Les « vignettes » du jeu : des objets de la minimap qui ont, eux, un identifiant et une place sur
-- la carte. Rien ne dit que les plantes et les filons en soient ; leur nombre et leurs noms le diront.
local function Vignettes()
	if not (C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo) then return "?" end
	local guids = SafeCall(C_VignetteInfo.GetVignettes)
	if type(guids) ~= "table" then return "?" end
	local names = {}
	for index = 1, math.min(#guids, 8) do
		local info = SafeCall(C_VignetteInfo.GetVignetteInfo, guids[index])
		local name = type(info) == "table" and info.name
		names[#names + 1] = (not IsSecret(name) and type(name) == "string") and name or "?"
	end
	return #guids .. (names[1] and " : " .. table.concat(names, ", ") or "")
end

function ns.ScanReport()
	local failure = ns.NodesFailure()
	ns.Print(L.SCAN_HEADER:format(failure or L.SCAN_READY))
	if broken then print("  " .. broken) end
	if failure then return end
	local finders = {}
	for index = 1, SafeCall(C_Minimap.GetNumTrackingTypes) or 0 do
		local info = SafeCall(C_Minimap.GetTrackingInfo, index)
		if type(info) == "table" and not IsSecret(info.spellID) and FINDERS[info.spellID or 0] then
			finders[#finders + 1] = L.SETTING:format(("%s (%s)"):format(tostring(info.name), tostring(info.spellID)),
				ns.Flag(not IsSecret(info.active) and info.active == true))
		end
	end
	print("  " .. L.SCAN_TRACKING:format(#finders > 0 and table.concat(finders, ", ") or L.NAME_NONE))
	ns.ForgetSkills()
	print("  " .. L.SCAN_SKILL:format(SkillText("herb"), SkillText("ore")))
	local radius, turning = View()
	print("  " .. L.SCAN_VIEW:format(radius and ("%.0f"):format(radius) or "?", ns.Flag(turning), ns.Flag(MapPosition() ~= nil),
		("%s %.1f%s, %s %.1f%s"):format(L.NAME_HERB, reaches.herb.value, reaches.herb.measured and "" or " ?",
			L.NAME_ORE, reaches.ore.value, reaches.ore.measured and "" or " ?")))
	print("  " .. L.SCAN_TWICE:format(Doubled() and L.YES or L.STATUS_NOT_YET))
	-- comment chaque nœud connu a été placé, et ce qu'a coûté le dernier balayage
	local exact, fitted, rough, held, missed = 0, 0, 0, 0, 0
	for _, marker in ipairs(markers) do
		if marker.held then held = held + 1
		elseif (marker.missed or 0) > 0 then missed = missed + 1
		elseif marker.worth == SURE then exact = exact + 1
		elseif marker.worth == FITTED then fitted = fitted + 1
		else rough = rough + 1 end
	end
	print("  " .. L.SCAN_PLACED:format(exact, fitted, rough, held, missed, last.points or 0, last.seconds or 0, last.jobs or 0))
	-- puis les icônes une à une, les plus proches du joueur d'abord : deux icônes pour un seul nœud
	-- se voient à leurs places, et le rayon lu pour chacune dit si les points du jeu ont tous le même
	local half, near = Minimap:GetWidth() / 2, {}
	for _, marker in ipairs(markers) do near[#near + 1] = marker end
	table.sort(near, function(a, b) return (a.x - half) ^ 2 + (a.y - half) ^ 2 < (b.x - half) ^ 2 + (b.y - half) ^ 2 end)
	for index = 1, math.min(#near, SCAN_LINES) do
		local marker = near[index]
		local how = marker.held and L.SCAN_HOW_HELD or (marker.missed or 0) > 0 and L.SCAN_HOW_MISSED
			or marker.worth == SURE and L.SCAN_HOW_EXACT or marker.worth == FITTED and L.SCAN_HOW_CLUSTER or L.SCAN_HOW_ROUGH
		print("    " .. L.SCAN_NODE:format(marker.name, how, marker.reach and ("%.1f"):format(marker.reach) or "?", marker.x - half, marker.y - half))
	end
	local names = {}
	for name in pairs(lastNames) do names[#names + 1] = name end
	table.sort(names)
	print("  " .. L.SCAN_FOUND:format(#names, #markers))
	for _, name in ipairs(names) do
		local node = ns.NodeOf(name)
		local text = L.SCAN_NOT_NODE
		if node then
			text = L["NAME_" .. node.kind:upper()]
			if node.skill then text = text .. L.SCAN_NEEDS:format(node.skill) end
			if lastNames[name].gray then text = text .. L.SCAN_CAVE end
		end
		print(("    %s → %s"):format(name, text))
	end
	print("  " .. L.SCAN_VIGNETTES:format(Vignettes()))
	local text, others, name, cursor = UnderPointer()
	if text then print("  " .. L.SCAN_DATA:format(others)) end
	print("  " .. L.SCAN_POINTER:format(text or L.SCAN_NOTHING))
	if name and cursor and not InCombatLockdown() then Zone(name, cursor) end
end
