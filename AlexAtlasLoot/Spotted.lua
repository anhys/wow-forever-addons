-- =====================================================================================
-- Alex Atlas Loot
-- Author: Alex, known in game as Alex Brandson on Forever. All rights reserved.
-- Contributors: the players named in Finds.lua (NS.CONTRIBUTORS) and on the Report page.
-- Full terms: LICENSE.txt in this folder.
-- =====================================================================================
-- Alex Atlas Loot, the easter egg: "You spotted Alex Brandson".
--
-- When the player who runs this addon meets the author in the world, an achievement
-- style toast pops up where the game's own achievements appear, and the meeting is
-- counted, once a day. Nothing is drawn on the author's character itself: nameplates and raid
-- markers are closed to addons on Forever. Nothing is sent anywhere either.
--
-- How a meeting is noticed, all without secret values:
--   target, mouseover   the unit's guid, plain in the open world and in cities
--   nameplate units     the same check when a nameplate for him appears (about 40 yards;
--                       friendly nameplates have to be on in the player's own settings,
--                       this file never touches that)
--   group               when he is in the party or raid
--   say, yell, emote,   the sender guid that rides on the chat event
--   party, raid
-- Inside dungeons and in PvP the guid comes back secret and the check is skipped. The
-- guard is issecretvalue on every value before it is compared.

local ADDON, NS = ...

local AUTHOR_GUID = "Player-4618-005C3741"
local AUTHOR_NAME = "Alex Brandson"
local LOGO = "Interface\\AddOns\\AlexAtlasLoot\\Textures\\logo.png"

local isAuthor = false

local function Store()
	AlexAtlasLootDB = AlexAtlasLootDB or {}
	AlexAtlasLootDB.spotted = AlexAtlasLootDB.spotted or { count = 0 }
	return AlexAtlasLootDB.spotted
end

---------------------------------------------------------------------------
-- The toast
---------------------------------------------------------------------------
-- Built from the same atlases and at the same measurements as the game's own
-- AchievementAlertFrameTemplate, but as a frame of its own: the alert queue takes
-- achievement ids, and this is not one. The shield says 50 points, as a real one would.
local toast

local function BuildToast()
	local f = CreateFrame("Button", "AlexAtlasLootSpottedToast", UIParent)
	f:SetSize(300, 101)
	f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128)
	f:SetFrameStrata("DIALOG")
	f:Hide()
	f:SetScript("OnClick", function(self) self:Hide() end)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("ui-achievement-alert-background", true)
	bg:SetPoint("CENTER")

	local unlocked = f:CreateFontString(nil, "BACKGROUND", "GameFontBlackTiny")
	unlocked:SetSize(200, 12)
	unlocked:SetPoint("TOP", 7, -23)
	unlocked:SetText(ACHIEVEMENT_UNLOCKED or "Achievement Earned")

	f.name = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
	f.name:SetSize(155, 36)
	f.name:SetPoint("TOP", unlocked, "BOTTOM")
	f.name:SetJustifyH("CENTER")
	f.name:SetJustifyV("MIDDLE")
	f.name:SetMaxLines(2)
	f.name:SetText("You spotted|n" .. AUTHOR_NAME)

	-- The icon, with the game's own round frame over it.
	local icon = CreateFrame("Frame", nil, f)
	icon:SetSize(78, 75)
	icon:SetPoint("TOPLEFT", -4, -15)
	local pic = icon:CreateTexture(nil, "ARTWORK")
	pic:SetSize(52, 52)
	pic:SetPoint("CENTER")
	pic:SetTexture(LOGO)
	local ring = icon:CreateTexture(nil, "OVERLAY")
	ring:SetAtlas("ui-achievement-iconframe", true)
	ring:SetPoint("CENTER", -1, 2)

	-- The shield, with its points.
	local shield = CreateFrame("Frame", nil, f)
	shield:SetSize(64, 64)
	shield:SetPoint("TOPRIGHT", -8, -15)
	local plate = shield:CreateTexture(nil, "BACKGROUND")
	plate:SetAtlas("ui-achievement-shield-2", true)
	plate:SetPoint("TOPRIGHT", 1, -6)
	local points = shield:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	points:SetPoint("CENTER", 3, -2)
	points:SetText("50")

	-- The glow and the shine, the two flashes the game plays when an achievement lands.
	f.glow = f:CreateTexture(nil, "OVERLAY")
	f.glow:SetAtlas("ui-achievement-alert-glow-glow", true)
	f.glow:SetPoint("CENTER")
	f.glow:SetBlendMode("ADD")
	f.glow:SetAlpha(0)
	local glowIn = f.glow:CreateAnimationGroup()
	local g1 = glowIn:CreateAnimation("Alpha") g1:SetFromAlpha(0) g1:SetToAlpha(1) g1:SetDuration(0.2) g1:SetOrder(1)
	local g2 = glowIn:CreateAnimation("Alpha") g2:SetFromAlpha(1) g2:SetToAlpha(0) g2:SetDuration(0.5) g2:SetOrder(2)
	f.glowIn = glowIn

	f.shine = f:CreateTexture(nil, "OVERLAY")
	f.shine:SetAtlas("ui-achievement-alert-glow-shine", true)
	f.shine:SetPoint("BOTTOMLEFT", 0, 8)
	f.shine:SetBlendMode("ADD")
	f.shine:SetAlpha(0)
	local shineIn = f.shine:CreateAnimationGroup()
	local s1 = shineIn:CreateAnimation("Alpha") s1:SetFromAlpha(0) s1:SetToAlpha(1) s1:SetDuration(0.2) s1:SetOrder(1)
	local s2 = shineIn:CreateAnimation("Translation") s2:SetOffset(240, 0) s2:SetDuration(0.85) s2:SetOrder(2)
	local s3 = shineIn:CreateAnimation("Alpha") s3:SetStartDelay(0.35) s3:SetFromAlpha(1) s3:SetToAlpha(0) s3:SetDuration(0.5) s3:SetOrder(2)
	f.shineIn = shineIn

	-- Fade in, hold, fade out, the game's own timing.
	local animIn = f:CreateAnimationGroup()
	local a1 = animIn:CreateAnimation("Alpha") a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.2) a1:SetOrder(1)
	f.animIn = animIn

	local animOut = f:CreateAnimationGroup()
	local o1 = animOut:CreateAnimation("Alpha") o1:SetStartDelay(4.05) o1:SetFromAlpha(1) o1:SetToAlpha(0) o1:SetDuration(1.5)
	animOut:SetScript("OnFinished", function() f:Hide() end)
	f.animOut = animOut

	return f
end

local function Pop()
	toast = toast or BuildToast()
	toast:SetAlpha(1)
	toast:Show()
	toast.animIn:Stop() toast.animOut:Stop() toast.glowIn:Stop() toast.shineIn:Stop()
	toast.animIn:Play()
	toast.animOut:Play()
	toast.glowIn:Play()
	toast.shineIn:Play()
	-- The sound the client plays when an achievement is earned. It has no SOUNDKIT name
	-- because Blizzard code never plays it from Lua; the kit id is 12891, the file 569143.
	if not PlaySound(12891) then PlaySoundFile(569143) end
end

-- Once a day, by the calendar: the day it last fired is kept in the saved variables, so
-- a reload or a relog does not start it over.
local function Show(how)
	local today = date("%Y-%m-%d")
	local s = Store()
	if s.last == today then return end

	s.count = (s.count or 0) + 1
	s.first = s.first or today
	s.last = today
	s.how = how

	Pop()
	print("|cff7fd8ffAlex Atlas Loot|r: You spotted " .. AUTHOR_NAME .. ".")
end

---------------------------------------------------------------------------
-- The checks
---------------------------------------------------------------------------
local function IsAuthorGUID(guid)
	if guid == nil or issecretvalue(guid) then return false end
	return guid == AUTHOR_GUID
end

local function CheckUnit(unit, how)
	if isAuthor or not unit then return end
	if IsAuthorGUID(UnitGUID(unit)) then Show(how) end
end

local function CheckGroup()
	if isAuthor or not IsInGroup() then return end
	local prefix, n = "party", GetNumSubgroupMembers()
	if IsInRaid() then prefix, n = "raid", GetNumGroupMembers() end
	for i = 1, n do
		if IsAuthorGUID(UnitGUID(prefix .. i)) then Show("group") return end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
for _, ev in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }) do
	f:RegisterEvent(ev)
end

f:SetScript("OnEvent", function(_, event, a1, _, _, _, _, _, _, _, _, _, _, senderGUID)
	if AlexAtlasLootDB and AlexAtlasLootDB.noSpotted then return end

	if event == "PLAYER_LOGIN" then
		-- The author gets no toast for meeting himself in a mirror.
		isAuthor = IsAuthorGUID(UnitGUID("player"))
		CheckGroup()
	elseif isAuthor then
		return
	elseif event == "PLAYER_TARGET_CHANGED" then
		CheckUnit("target", "target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		CheckUnit("mouseover", "mouseover")
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		CheckUnit(a1, "nameplate")
	elseif event == "GROUP_ROSTER_UPDATE" then
		CheckGroup()
	else
		-- A chat event. The sender guid is the twelfth argument; in chat lockdown it is
		-- secret and the guard throws it away.
		if IsAuthorGUID(senderGUID) then Show("chat") end
	end
end)

-- /aalspot shows the toast as it would look, counts nothing, so the author can see it
-- without finding himself in the street.
SLASH_ALEXATLASLOOTSPOT1 = "/aalspot"
SlashCmdList.ALEXATLASLOOTSPOT = function()
	Pop()
end

function NS.SpottedCount()
	local s = AlexAtlasLootDB and AlexAtlasLootDB.spotted
	return s and s.count or 0
end
