-- Confidence tiers for every fact ItemTree shows. Pure Lua, no WoW API.
--
-- Tiers, from most to least trusted:
--   verified   the collector saw it on this client and build
--   mined      read from this build's client tables (DB2), always true for the build
--   curated    a hand maintained note shipped under Data/curated
--   baseline   imported from an external baseline, not yet seen on this client
--   predicted  a rule based prediction (disenchant bands), always shown with a percentage
--   guess      a source ItemTree's model guessed (Core/GuessSources.lua), never seen in the game.
--              Below every other tier, and never a step in a chain (Core/Graph.lua drops a guess
--              edge unless a walk asks for them with opts.includeGuessSources).
local _, ItemTree = ...

local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Confidence = {}
ItemTree.Confidence = Confidence

Confidence.VERIFIED = "verified"
Confidence.MINED = "mined"
Confidence.CURATED = "curated"
Confidence.BASELINE = "baseline"
Confidence.PREDICTED = "predicted"
Confidence.GUESS = "guess"

-- What a prediction is based on, which is not the same question as how far it is trusted. Every
-- predicted fact the addon shipped until now came out of the disenchant bands, so "predicted"
-- and "worked out from item level and quality" were one and the same; the Classic Era source
-- table is a prediction of another kind altogether. An edge carries the basis, Core/Sources.lua
-- passes it on, and UI/Badges.lua picks the badge's meaning line by it, so a disenchant row
-- still says what it always said and an Era row says it is history.
Confidence.BASIS_DISENCHANT = "disenchant"
Confidence.BASIS_ERA = "era"
-- Brief GS2: a guessed source rests on the model's own strategies, which is neither of the two
-- above, so a guess edge says so and its badge can explain itself in its own words.
Confidence.BASIS_GUESS = "guess"

-- Higher rank wins when two facts disagree.
local RANK = {
  verified = 5,
  mined = 4,
  curated = 3,
  baseline = 2,
  predicted = 1,
  -- Brief GS2: below everything, and a half so that no rank above it moved to make room. Two
  -- facts about one source keep the more trusted, so any real edge beats a guess of the same one.
  guess = 0.5,
}

Confidence.Order = { "verified", "mined", "curated", "baseline", "predicted", "guess" }

-- Badge kind shown for a tier, or nil when no badge is drawn (mined facts are the norm).
local BADGE = {
  verified = "verified",
  mined = nil,
  curated = "note",
  baseline = "unverified",
  predicted = "predicted",
  guess = "guess",
}

-- Copy that the design system's voice uses: terse, factual, no subject. Each line is the
-- English wording and its own locale key, read through L by Confidence.Label, so nothing here
-- reaches a player untranslated.
local LABEL = {
  verified = "Verified by collector",
  mined = "From client data",
  curated = "Community note",
  baseline = "Imported baseline, unverified",
  predicted = "Predicted",
  guess = "Guess",
}

function Confidence.Rank(tier)
  return RANK[tier] or 0
end

function Confidence.IsValid(tier)
  return RANK[tier] ~= nil
end

-- Returns the more trusted of two tiers.
function Confidence.Best(a, b)
  if not a then
    return b
  end
  if not b then
    return a
  end
  return RANK[a] >= RANK[b] and a or b
end

function Confidence.Badge(tier)
  return BADGE[tier]
end

-- The build stamp on a verified label. A format rather than a join, so a locale can put the
-- build where its own grammar wants it.
local BUILD_STAMP = "%s, build %s"

-- Label with an optional build stamp, e.g. "Verified by collector, build 1.15.9".
function Confidence.Label(tier, build)
  local label = LABEL[tier] and L[LABEL[tier]] or tier
  if tier == "verified" and build then
    return string.format(L[BUILD_STAMP], label, tostring(build))
  end
  return label
end

-- A figure this client cannot confirm, hedged: "3%" -> "about 3%". Imported drop rates were
-- measured on another client line, so the number is worth showing and the precision is not.
-- A format rather than a join, so a locale can put the word where its own grammar wants it.
local APPROXIMATE = "about %s"

function Confidence.Approximate(text)
  if type(text) ~= "string" or text == "" then
    return text
  end
  return string.format(L[APPROXIMATE], text)
end

-- A figure that was measured somewhere else entirely, marked so it cannot be read as one this
-- client measured: "12.5%" -> "~12.5%". "about 3%" above hedges the precision of a figure that
-- still describes this client; this says the figure describes a different game. A format rather
-- than a join, so a locale can put the mark where its own grammar wants it.
local HISTORICAL = "~%s"

function Confidence.Historical(text)
  if type(text) ~= "string" or text == "" then
    return text
  end
  return string.format(L[HISTORICAL], text)
end

-- A measured chance, to the one decimal place it was stated to and no further: 12.5 -> "12.5%",
-- 4 -> "4%". Confidence.Percent rounds anything over 10 to a whole number, which is right for a
-- band's prediction and wrong for a measurement, where the decimal is the measurement.
function Confidence.Chance(percent)
  if type(percent) ~= "number" then
    return nil
  end
  local text = string.format("%.1f", percent)
  return (text:gsub("%.0$", "")) .. "%"
end

-- Percent text for predictions: 0.75 -> "75%".
function Confidence.Percent(chance)
  if type(chance) ~= "number" then
    return ""
  end
  local pct = chance * 100
  if pct >= 10 or pct == math.floor(pct) then
    return string.format("%d%%", math.floor(pct + 0.5))
  end
  return string.format("%.1f%%", pct)
end

return Confidence
