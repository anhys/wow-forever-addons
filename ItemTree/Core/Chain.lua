-- Linear crafting chains through the item graph. Pure Lua, no WoW API.
-- Loaded as: local _, ItemTree = ...
--
-- The tree answers "what is this used for" as a branching list. The Chain tab answers the
-- narrower question "what is the single run of steps that gets me from one end to the
-- other", so this module walks the same graph and returns flat stage lists instead of rows
-- (see design: tree/ChainView.jsx).
--
-- A path is one route from the root to a node with nothing further to follow: a leaf, a
-- node whose only edges close a cycle, or the depth cap. Cycles are guarded by the
-- ancestor path, exactly the way Graph.Walk guards them, so a reagent that is also made
-- from its own product is visited once and never descended into.
--
-- Not every edge out of a node is a fork in the road:
--   * the reagents of one spell are an AND group, and so are the items one quest asks for
--     (QUEST_REQUIRES). A recipe that asks for a crystal, a shard, an essence and some dust
--     needs all four, so a chain follows one of them and states the rest on that stage as
--     coReagents. They are never alternatives of one another.
--   * a tool (REQUIRES_TOOL, TOOL_FOR) is held, not consumed. It is never a stage and
--     never an alternative. A spell stage states its tools instead.
--   * the item that starts a quest (QUEST_STARTED_BY) is not one of the things the quest
--     needs, so it is never a step on the way up while the quest has a required item to
--     follow instead. It stands only where it is the sole way up.
--   * everything else is a genuine choice: another recipe that makes the item, another
--     source it comes from, another thing it can be made into. Those are the alternatives.
--
-- Direction is fixed at the root, as everywhere else. A path walked with Edges.UP is
-- reversed before it is returned, so every chain reads left to right from the earliest
-- stage to the finished item and the label reads "Thorium Ore to Arcanite Bar". The arrow
-- and the numbers behind it always belong to the edge drawn under it, so the first stage of
-- a chain carries none of them whichever way it was walked. Everything the edge states (the
-- arrow, the numbers behind it, the confidence badge it raises and the meta line it carries)
-- travels together when a path is reversed; everything the node states (its Diff badges and
-- its own meta line) stays where it is.
--
-- Slots are counted from the root: 0 is the root, negative is upstream, positive is
-- downstream. A slot is what opts.pins names, and what an alternative and a co-reagent each
-- carry, so a caller can pin one in place of the stage drawn there and ask for the chain
-- again.
--
-- opts.pins and opts.choice are two ways of saying which chain to draw and a caller can hand
-- over both. A pin is the narrower of the two: pinning a stage of the chain in hand swaps that
-- one step and recomputes the rest, so a pin stands whatever chain was picked, and the chosen
-- chain is drawn whole only where it stands on every pin. Where it cannot, the chain that
-- agrees with the pick for longest is drawn rather than the shortest one in the list. A caller
-- whose player has just picked a whole chain drops its pins with the chain they belonged to.
--
-- A choice id is the keys of one whole chain joined by ">", so the chain an id names is read
-- back out of the id and walked down rather than looked for among the paths this call happened
-- to enumerate: a path cap, a walk budget, a prefer that sent the walk down another reagent and
-- an edge that arrived after the list was drawn each take one path out of a walk, and none of
-- them may lose the chain the player picked.
local _, ItemTree = ...

local Data = ItemTree.Data
local Edges = ItemTree.Edges
local Graph = ItemTree.Graph
local Diff = ItemTree.Diff
local Confidence = ItemTree.Confidence
local L = ItemTree.L or setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

local Chain = {}
ItemTree.Chain = Chain

local EMPTY = {}

Chain.DEFAULTS = {
  maxDepth = 6, -- stages beyond the root, matching ViewModel.DEFAULTS.maxDepth
  maxPaths = 12, -- kept after sorting, the rest are dropped
  maxChoices = 12, -- entries offered in the chain selector
  budget = 2000, -- walk steps before enumeration gives up, so a dense root cannot hang the client
}

-- Node kind to the Diff module kind that holds its New and Changed sets. Same table as
-- ViewModel; Core never shares state between modules, only shapes.
local DIFF_KINDS = { item = "items", spell = "recipes", skill = "skills", enchant = "enchants" }

-- Held, not consumed: a tool is never a step between two items.
local TOOL_EDGES = { REQUIRES_TOOL = true, TOOL_FOR = true }

-- The AND groups in the graph, by edge type name: every reagent of one spell, and every item
-- one quest asks for. A chain follows one of a group and states the rest on that stage. Read by
-- name rather than by identity, so this holds for an edge type a later build adds.
local GROUP_EDGES = { REAGENT = true, QUEST_REQUIRES = true }

-- The item that starts a quest is not one of the things the quest needs, so it is never one of
-- the steps on the way up. It is kept only where it is the sole way up out of a quest, the way
-- a chain that has nowhere else to go still has to read as something.
local START_EDGES = { QUEST_STARTED_BY = true }

local function edgeName(edge)
  local def = edge and edge.type
  return def and def.name or nil
end

local function isTool(edge)
  local name = edgeName(edge)
  return name ~= nil and TOOL_EDGES[name] == true
end

-- True on one member of an AND group: a spell's reagent, or an item a quest asks for.
local function isGroup(edge)
  local name = edgeName(edge)
  return name ~= nil and GROUP_EDGES[name] == true
end

local function isStart(edge)
  local name = edgeName(edge)
  return name ~= nil and START_EDGES[name] == true
end

-- The predicted disenchant edges, which a chain never follows in either direction.
--
-- Walking down, a piece of equipment turning into dust is not a step on the way to anything the
-- player is making: the chain ran on through whatever that dust and those shards enchant, so
-- every chain Arcane Crystal offered ended on the Arcane Forge one of those enchants is cast at,
-- and the list of them differed only in which shard went on to make which enchant. Walking up, a
-- shard's own sources are 1,502 pieces of equipment, and the walk started the chain from an
-- arbitrary one of them. A chain therefore ends at the item that would be disenchanted, and what
-- happens at the enchanting table is a signpost after it rather than more steps.
--
-- Both sides are read from Edges rather than named here, so a type filed under either set later
-- leaves chains along with it: Edges.DISENCHANT_TYPES is the set the Disenchants view is built
-- from, and Edges.DISENCHANT_SOURCE_TYPES is its up side, the edges a dust or a shard answers
-- with. The two names this file used to state are kept as a fall back, so a build whose Edges
-- predates either set still loads and still filters.
local DISENCHANT_EDGES = { DISENCHANTS_INTO = true, DISENCHANTED_FROM = true }
for _, set in ipairs({ "DISENCHANT_TYPES", "DISENCHANT_SOURCE_TYPES" }) do
  for name in pairs((Edges and Edges[set]) or EMPTY) do
    DISENCHANT_EDGES[name] = true
  end
end

local function isDisenchant(edge)
  local name = edgeName(edge)
  return name ~= nil and DISENCHANT_EDGES[name] == true
end

-- The shared World drop node (Core/EraSources.lua WORLD_ID). It stands for every creature a
-- source table would not list by name, so it is a row in a tree and never one creature a chain
-- can start from.
local WORLD_DROP_KEY = Graph.Key("npc", 0)

-- A row that stands for a GROUP of sources rather than one of them: a Classic Era "Show N more"
-- row (edge.summary, Core/Graph.lua) or the World drop entry. Neither is a thing the player can
-- go to, so neither is ever a stage: a chain stops at the last real node in front of it, and
-- neither is offered as an alternative. Both only ever arrive on historical edges, and a chain
-- walk asks for the Classic Era quest rows alone (brief CH1, Graph.ChainQuestEdge, which takes no
-- summary row either), so this holds the rule in the one place a chain chooses its edges should a
-- caller ever hand them over.
local function isSummary(edge)
  return edge.summary ~= nil or edge.target == WORLD_DROP_KEY
end

-- The text drawn on the arrow between two stages, in the client's number style.
function Chain.Arrow(edge)
  if not edge then
    return nil
  end
  if edge.quantity then
    if edge.quantityMax and edge.quantityMax > edge.quantity then
      return string.format("x%d to %d", edge.quantity, edge.quantityMax)
    end
    return "x" .. tostring(edge.quantity)
  end
  if edge.percent then
    return Confidence.Percent(edge.percent / 100)
  end
  local name = edge.type and edge.type.name or nil
  if name == "QUEST_REWARD" or name == "QUEST_REWARDS" then
    return "reward"
  end
  return nil
end

-- What a spell stage asks the player to be holding. A recipe states a tool either as a totem
-- category (any Blacksmith Hammer will do) or as the one exact item it wants (Flint and Tinder,
-- for the campfire recipes), and sometimes both ways at once. Both lists are read, so a recipe
-- whose only tool is an item still says what it needs, and an item a category has already named
-- is stated once. A category the build names but ships no item for is still stated by name.
local function toolsFor(node)
  if node.kind ~= "spell" then
    return nil
  end
  local recipe = Data:GetRecipe(node.id)
  if not recipe then
    return nil
  end
  local out, named = {}, {}
  for _, category in ipairs(recipe.tools or EMPTY) do
    local categoryName = Data:GetTotemCategoryName(category)
    local items = Data:ItemsWithTotemCategory(category)
    local itemId = items and items[1] or nil
    if itemId then
      named[itemId] = true
    end
    local key = itemId and Graph.Key("item", itemId) or nil
    local tool = key and Graph.Node(key) or nil
    out[#out + 1] = {
      categoryId = category,
      categoryName = categoryName,
      key = key,
      name = (tool and tool.name) or categoryName,
      icon = tool and tool.icon or nil,
      quality = tool and tool.quality or nil,
    }
  end
  for _, itemId in ipairs(recipe.toolItems or EMPTY) do
    if not named[itemId] then
      named[itemId] = true
      local key = Graph.Key("item", itemId)
      local tool = Graph.Node(key)
      out[#out + 1] = {
        key = key,
        name = (tool and tool.name) or key,
        icon = tool and tool.icon or nil,
        quality = tool and tool.quality or nil,
      }
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Brief CH1 (owner QA 2026-10-18 item 249): the side words a quest stage says for a player of
-- playerSide ("Alliance" or "Horde"; left out, Graph.PlayerSide answers): "Horde only" for a quest
-- of the other side alone, the read an item's Used by and Sources rows word it by
-- (Graph.FactionOnly), else "Possibly Horde only" for one our data leans to the other side
-- (Graph.LeanWords), else nil: the player's own side, both sides, no side known, anything that is
-- no quest. While "Hide other faction data" is on the other side's quests never reach a chain, so
-- the words stand only with the setting off. Pure over the shipped listing.
function Chain.SideWords(questKey, playerSide)
  if Graph.Kind(questKey) ~= "quest" then
    return nil
  end
  if playerSide == nil then
    playerSide = Graph.PlayerSide()
  end
  if playerSide ~= "Alliance" and playerSide ~= "Horde" then
    return nil
  end
  local side = Graph.FactionOnly({ target = questKey }, playerSide)
  if side == "Alliance" then
    return L["Alliance only"]
  end
  if side == "Horde" then
    return L["Horde only"]
  end
  return Graph.LeanWords(questKey, playerSide)
end

-- One stage: the node, plus everything the edge that reached it carries. What the node
-- states and what the edge states are kept apart until the path is the right way round.
local function buildStage(nodeKey, edge)
  local node = Graph.Node(nodeKey)
  if not node then
    return nil
  end
  local nodeBadges = {}
  local diffKind = DIFF_KINDS[node.kind]
  if diffKind then
    for _, badge in ipairs(Diff.Badges(diffKind, node.id)) do
      nodeBadges[#nodeBadges + 1] = badge
    end
  end
  local stage = {
    key = node.key,
    kind = node.kind,
    id = node.id,
    type = node.type,
    name = node.name,
    quality = node.quality,
    icon = node.icon,
    nodeMeta = node.meta,
    nodeBadges = nodeBadges,
  }
  -- Carried through so the selector can tell a chain that ends on something the build will not
  -- name from one that ends on a thing the player can go and make. The name is already the
  -- neutral placeholder Graph.UndiscoveredName words; this is the fact behind it.
  --
  -- E39: both halves of it travel, not just the first. node.discovered says something outside
  -- the data named the item anyway, and a stage that carried only the withheld half left the
  -- pane asking Graph.ItemDiscoveryMark again for that one id to find the other half out.
  -- Written as a plain false rather than left absent, because absent is what tells the pane that
  -- a stage some other hand built has no word on it at all and still has to be asked about.
  if node.undiscovered then
    stage.undiscovered = true
    stage.discovered = node.discovered and true or false
  end
  if node.skillLine then
    stage.skill = Data:GetSkillName(node.skillLine)
  end
  -- Brief CH1: a fact about the quest, so it stays with the node when a path is reversed and
  -- finaliseStage puts it on the meta line.
  if node.kind == "quest" then
    stage.sideWords = Chain.SideWords(node.key)
  end
  local tools = toolsFor(node)
  if tools then
    stage.tools = tools
  end
  if edge then
    stage.quantity = edge.quantity
    stage.quantityMax = edge.quantityMax
    stage.percent = edge.percent
    stage.confidence = edge.confidence
    stage.arrow = Chain.Arrow(edge)
    stage.edgeType = edgeName(edge)
    -- The edge that reached this node, kept with the node rather than the step: edgeType moves
    -- onto the stage in front when an upward path is reversed, so the creature at the head of a
    -- "Dropped by" chain would otherwise carry nothing that says it drops, sells or is skinned.
    -- The pane reads it for the stage's glyph (UI/Chain.lua).
    stage.reachedBy = edgeName(edge)
    stage.edgeMeta = edge.meta
    stage.edgeBadge = Confidence.Badge(edge.confidence)
  end
  return stage
end

-- Folds what the node states and what the edge states into the two fields the UI reads.
-- Runs once, after any reversal, so a badge never sits a slot away from its number.
local function finaliseStage(stage)
  if stage.badges then
    return stage
  end
  local badges = {}
  for _, badge in ipairs(stage.nodeBadges or EMPTY) do
    badges[#badges + 1] = badge
  end
  if stage.edgeBadge then
    badges[#badges + 1] = stage.edgeBadge
  end
  stage.badges = badges
  stage.meta = stage.edgeMeta or stage.nodeMeta
  -- Brief CH1: "Horde only" after whatever the line already says ("Event, Horde only"), the way a
  -- Used by row says it (Core/ViewModel.lua ViewModel.WithSideWords).
  if stage.sideWords then
    if type(stage.meta) == "string" and stage.meta ~= "" then
      stage.meta = stage.meta .. ", " .. stage.sideWords
    else
      stage.meta = stage.sideWords
    end
  end
  stage.nodeBadges, stage.nodeMeta, stage.edgeBadge, stage.edgeMeta = nil, nil, nil, nil
  return stage
end

local function copyStage(stage)
  local out = {}
  for key, value in pairs(stage) do
    out[key] = value
  end
  return out
end

-- The numbers an alternative cannot honestly state: they only hold once the chain has been
-- rebuilt through it, and on the upward side they would belong to the stage in front of it.
local STEP_FIELDS = { "arrow", "quantity", "quantityMax", "percent" }

local function stripStep(stage)
  for _, field in ipairs(STEP_FIELDS) do
    stage[field] = nil
  end
  return stage
end

-- Everything the edge into a stage states. The arrow is the text drawn on it, the numbers
-- are what is behind that text, and the badge and the meta line are what the edge itself
-- raises. They all describe the step between a pair and not either end of it, so they all
-- move together when a path is reversed.
local EDGE_FIELDS = { "arrow", "quantity", "quantityMax", "percent", "confidence", "edgeType", "edgeMeta", "edgeBadge" }

-- Walk order to reading order. Reversing moves what the edge stated onto the stage in front of
-- it, so a stage still carries the step that reaches it. The first stage is reached by no edge
-- and carries none of it.
local function reverseStages(stages)
  local out = {}
  local total = #stages
  for index = 1, total do
    out[index] = stages[total + 1 - index]
  end
  for index = total, 2, -1 do
    for _, field in ipairs(EDGE_FIELDS) do
      out[index][field] = out[index - 1][field]
    end
  end
  for _, field in ipairs(EDGE_FIELDS) do
    out[1][field] = nil
  end
  return out
end

-- Takes a copy of the stages currently on the walk stack and turns them into a path.
local function finishPath(stages, direction)
  local copied = {}
  for index, stage in ipairs(stages) do
    copied[index] = copyStage(stage)
  end
  if direction == Edges.UP then
    copied = reverseStages(copied)
  end

  local keys, mined, weakest = {}, 0, nil
  for index, stage in ipairs(copied) do
    finaliseStage(stage)
    keys[index] = stage.key
    if stage.confidence == Confidence.MINED then
      mined = mined + 1
    end
    if stage.confidence and (not weakest or Confidence.Rank(stage.confidence) < Confidence.Rank(weakest)) then
      weakest = stage.confidence
    end
  end

  return {
    id = table.concat(keys, ">"),
    label = copied[1].name .. " to " .. copied[#copied].name,
    stages = copied,
    -- Whether the build will name what this path ends on. Always a boolean: a path that ends on
    -- an item the build withholds reads "to Undiscovered permanent", which names nothing the
    -- player can go and make, so it stands behind one that does.
    named = not copied[#copied].undiscovered,
    -- Whether this path ends on a thing the player can hold rather than on an enchant, a spell or
    -- anything else that is not an item. Always a boolean, because the sorts compare the two.
    endsOnItem = copied[#copied].kind == "item",
    depth = #copied,
    mined = mined,
    confidence = weakest,
  }
end

-- Slot, counted from the root: upward is negative, downward is positive.
local function slotOf(direction, depth)
  if direction == Edges.UP then
    return -depth
  end
  return depth
end

-- The index a slot names inside a one direction path. An upward path ends on the root, a
-- downward one starts on it.
local function slotIndex(path, direction, slot)
  if direction == Edges.UP then
    return #path.stages + slot
  end
  return slot + 1
end

-- The pins one side of the chain has to answer for. A slot that is not a number, a key that is
-- not one, and a slot that belongs to the other half are all none of this walk's business.
local function sidePins(pins, direction)
  local out = {}
  if type(pins) ~= "table" then
    return out
  end
  for slot, key in pairs(pins) do
    slot = tonumber(slot)
    if slot and type(key) == "string" then
      if (direction == Edges.UP and slot < 0) or (direction == Edges.DOWN and slot > 0) then
        out[slot] = key
      end
    end
  end
  return out
end

local function pathMeets(path, direction, pins)
  for slot, key in pairs(pins) do
    local stage = path.stages[slotIndex(path, direction, slot)]
    if not stage or stage.key ~= key then
      return false
    end
  end
  return true
end

-- Brief CH1 (owner QA 2026-10-18 item 249, and item 270's note that a chain ignored "Hide other
-- faction data"): the side a chain hides the other side's quests, vendors and trainers from, by the
-- rule the views use (Core/Graph.lua Graph.HidesEdge). A caller that states opts.hideOtherFaction is
-- taken at its word (a spec); one that does not (the pane) is answered from the saved setting,
-- Graph.HiddenSide: the character's own side while the setting is on, else nil and nothing is
-- hidden. Guarded.
function Chain.HiddenSide(opts)
  if type(opts) == "table" and opts.hideOtherFaction ~= nil then
    if opts.hideOtherFaction == false then
      return nil
    end
    return Graph.PlayerSide()
  end
  return Graph.HiddenSide()
end

-- What a chain asks of every graph walk it makes, the walk itself, its alternatives and its
-- co-reagents alike: the caller's predicted switch, the Classic Era quest rows (brief CH1,
-- Graph.ChainQuestEdge: an Era quest is a step, an Era drop or vendor never is) and the side
-- "Hide other faction data" hides from.
local function walkOptions(opts)
  return { showPredicted = opts.showPredicted, includeEraQuests = true, hideSide = Chain.HiddenSide(opts) }
end

-- Brief CH1 (the brief's cost line): one chain asks the graph about the same node again and again
-- (every path through it, the alternatives in its slot, a quest's other items), and the Classic Era
-- quest rows made those walks wider. The answers are kept for one call only, keyed by the walk
-- options table that call made (Chain.Full makes one and hands it to every walk it starts, opts.walk),
-- so nothing outlives the call and the next one reads the data and the setting afresh. The lists are
-- read, never written into, by everything below.
local memos = setmetatable({}, { __mode = "k" })
local function childrenOf(key, direction, childOpts)
  local memo = memos[childOpts]
  if not memo then
    memo = {}
    memos[childOpts] = memo
  end
  local byKey = memo[direction]
  if not byKey then
    byKey = {}
    memo[direction] = byKey
  end
  local edges = byKey[key]
  if not edges then
    edges = Graph.Children(key, direction, childOpts)
    byKey[key] = edges
  end
  return edges
end

-- The one member of an AND group a chain follows: the one the caller came from if it is in the
-- group, else the rarest, else the one the recipe or the quest lists first.
local function pickGroupMember(group, prefer)
  if prefer then
    for _, edge in ipairs(group) do
      if edge.target == prefer then
        return edge
      end
    end
  end
  local best, bestQuality = nil, nil
  for _, edge in ipairs(group) do
    local node = Graph.Node(edge.target)
    local quality = (node and node.quality) or -1
    if not best or quality > bestQuality then
      best, bestQuality = edge, quality
    end
  end
  return best or group[1]
end

-- The edges a walk may follow out of one node: tools never, a predicted disenchant never, a
-- summary row or the World drop never, the
-- item that starts a quest only where the quest has no other way up, a pinned slot only through
-- the node it names, and one member of each AND group (a spell's reagents, a quest's required
-- items) at a time.
local function candidateEdges(key, direction, depth, opts, childOpts)
  local pin = opts.pins and opts.pins[slotOf(direction, depth)] or nil
  local kept, groups, starts = {}, {}, 0
  for _, edge in ipairs(childrenOf(key, direction, childOpts)) do
    if not isTool(edge) and not isDisenchant(edge) and not isSummary(edge) and (not pin or edge.target == pin) then
      kept[#kept + 1] = edge
      if isStart(edge) then
        starts = starts + 1
      elseif isGroup(edge) then
        local name = edgeName(edge)
        local group = groups[name]
        if not group then
          group = {}
          groups[name] = group
        end
        group[#group + 1] = edge
      end
    end
  end
  if starts > 0 and starts < #kept then
    local rest = {}
    for _, edge in ipairs(kept) do
      if not isStart(edge) then
        rest[#rest + 1] = edge
      end
    end
    kept = rest
  end
  local chosen, forking = {}, false
  for _, group in pairs(groups) do
    if #group > 1 then
      chosen[pickGroupMember(group, opts.prefer)] = true
      forking = true
    end
  end
  if not forking then
    return kept
  end
  local out = {}
  for _, edge in ipairs(kept) do
    local group = isGroup(edge) and groups[edgeName(edge)] or nil
    if chosen[edge] or not group or #group < 2 then
      out[#out + 1] = edge
    end
  end
  return out
end

-- Every linear path from rootKey, best first and capped at opts.maxPaths: a path whose end the
-- build will name, then one that ends on a thing the player can hold, then the shortest, then by
-- label. opts also takes maxDepth, budget, showPredicted, pins, prefer and hideOtherFaction (brief
-- CH1), and walk, the walk options Chain.Full shares between the walks it starts (childrenOf).
--
-- A pin is honoured before the cap, never after it. Restricting the walk at the pinned depth is
-- not enough on its own: a branch that runs out before it reaches that depth still finishes a
-- path, that path is shorter than any path through the pin, and the cap keeps the shortest. On a
-- dense root there are more than maxPaths of those, so every path through the pin was thrown
-- away and the pin read as one nothing could meet. A path that does not stand on every pin for
-- this side is not a candidate at all, so it is dropped as it is finished.
function Chain.Paths(rootKey, direction, opts)
  opts = opts or EMPTY
  direction = direction == Edges.UP and Edges.UP or Edges.DOWN
  local maxDepth = opts.maxDepth or Chain.DEFAULTS.maxDepth
  local maxPaths = opts.maxPaths or Chain.DEFAULTS.maxPaths
  local budget = opts.budget or Chain.DEFAULTS.budget
  local childOpts = opts.walk or walkOptions(opts)
  local pinned = sidePins(opts.pins, direction)
  local hasPins = next(pinned) ~= nil

  local root = buildStage(rootKey, nil)
  if not root then
    return {}
  end

  local paths, stages, onPath, steps = {}, { root }, { [rootKey] = true }, 0

  local function walk(key, depth)
    steps = steps + 1
    local children = EMPTY
    if depth < maxDepth then
      children = candidateEdges(key, direction, depth + 1, opts, childOpts)
    end
    local grown = false
    for _, edge in ipairs(children) do
      if steps > budget then
        break
      end
      if not onPath[edge.target] then
        local stage = buildStage(edge.target, edge)
        if stage then
          grown = true
          stages[#stages + 1] = stage
          onPath[edge.target] = true
          walk(edge.target, depth + 1)
          onPath[edge.target] = nil
          stages[#stages] = nil
        end
      end
    end
    if not grown and #stages > 1 then
      local path = finishPath(stages, direction)
      if not hasPins or pathMeets(path, direction, pinned) then
        paths[#paths + 1] = path
      end
    end
  end

  walk(rootKey, 0)

  -- The cap below keeps the head of this list and throws the rest away, so every rule that
  -- decides what the player is offered has to be stated here rather than in the choice list: a
  -- chain the cap has already dropped is one no later sort can bring back.
  --
  -- Named first, the same rule bestOf and buildChoices hold: a chain that ends on an item this
  -- build withholds reads "to Undiscovered permanent" and names nothing the player can go and
  -- make, so it never takes a place from one that does. Nexus Crystal has twenty of those and
  -- seven real ones, and without this key the twenty would fill the list.
  --
  -- Then a chain that ends on a thing the player can hold, before one that ends on an enchant.
  -- An enchanting material's chains nearly all end at the enchanting table and there are far
  -- more of them than the cap keeps, so by depth and label alone the cap threw every item ending
  -- away: Illusion Dust offered twelve enchants and none of its sixteen items, Runed Arcanite
  -- Rod among them, and Strange Dust offered the first twelve end products alphabetically. The
  -- choice list sorts the same way, so the list and the chain the pane opens on keep agreeing.
  table.sort(paths, function(a, b)
    if a.named ~= b.named then
      return a.named
    end
    if a.endsOnItem ~= b.endsOnItem then
      return a.endsOnItem
    end
    if a.depth ~= b.depth then
      return a.depth < b.depth
    end
    if a.label ~= b.label then
      return a.label < b.label
    end
    return a.id < b.id
  end)

  for index = #paths, maxPaths + 1, -1 do
    paths[index] = nil
  end
  return paths
end

-- The best of a path list: a path whose end the build will name before one it will not, then the
-- shortest, then the one with the most mined stages. Split out so Chain.Full can pick from paths
-- it has already walked.
--
-- A path that ends on a withheld item reads "to Undiscovered permanent". It is a real route and
-- is still offered, but the chain the pane opens on, and the words on the selector, are the one
-- thing the player is shown without asking, so they name something they can go and make. The
-- selector's own list sorts the same way, so the list and the chain it draws agree.
local function bestOf(paths)
  local best = nil
  for _, path in ipairs(paths) do
    local better
    if not best then
      better = true
    elseif path.named ~= best.named then
      better = path.named == true
    elseif path.depth ~= best.depth then
      better = path.depth < best.depth
    else
      better = path.mined > best.mined
    end
    if better then
      best = path
    end
  end
  return best
end

-- The best path: one the build can name the end of first, then the shortest, and among equally
-- short paths the one with the most mined stages.
function Chain.Best(rootKey, direction, opts)
  return bestOf(Chain.Paths(rootKey, direction, opts))
end

local function passesThrough(path, key)
  for _, stage in ipairs(path.stages) do
    if stage.key == key then
      return true
    end
  end
  return false
end

-- The best path that still passes through the node the caller came from, so walking to a
-- recipe from one of its reagents keeps that reagent on the chain rather than swapping it for
-- the scroll that teaches it. Falls back to the best of the lot when nothing passes through.
local function bestOfPreferring(paths, prefer)
  if type(prefer) == "string" then
    local kept = {}
    for _, path in ipairs(paths) do
      if passesThrough(path, prefer) then
        kept[#kept + 1] = path
      end
    end
    if #kept > 0 then
      return bestOf(kept)
    end
  end
  return bestOf(paths)
end

--------------------------------------------------------------------------------
-- Pins
--------------------------------------------------------------------------------

local function keepMeeting(paths, direction, pins)
  if next(pins) == nil then
    return paths
  end
  local out = {}
  for _, path in ipairs(paths) do
    if pathMeets(path, direction, pins) then
      out[#out + 1] = path
    end
  end
  return out
end

local function withPins(opts, pins)
  local out = {}
  for key, value in pairs(opts) do
    out[key] = value
  end
  out.pins = pins
  return out
end

-- One side of the chain, with as many of its pins met as the graph allows. The common case
-- is one walk. A pin nothing can meet is dropped, named in dropped, and the side is walked
-- again with the pins that are left, nearest the root first.
local function sidePaths(rootKey, direction, opts, pins, dropped)
  local side = sidePins(pins, direction)
  if next(side) == nil then
    return Chain.Paths(rootKey, direction, opts)
  end
  local paths = keepMeeting(Chain.Paths(rootKey, direction, withPins(opts, side)), direction, side)
  if #paths > 0 then
    return paths
  end

  local order = {}
  for slot in pairs(side) do
    order[#order + 1] = slot
  end
  table.sort(order, function(a, b)
    return math.abs(a) < math.abs(b)
  end)

  local active = {}
  paths = Chain.Paths(rootKey, direction, withPins(opts, active))
  for _, slot in ipairs(order) do
    active[slot] = side[slot]
    local tried = keepMeeting(Chain.Paths(rootKey, direction, withPins(opts, active)), direction, active)
    if #tried > 0 then
      paths = tried
    else
      active[slot] = nil
      dropped[#dropped + 1] = slot
    end
  end
  return paths
end

-- Slot 0 is the root itself, so a pin there is either what the caller already asked for or
-- impossible. Anything that is not a number to a key is not a pin at all.
local function normalisePins(raw, rootKey, dropped)
  local pins = {}
  if type(raw) ~= "table" then
    return pins
  end
  for slot, key in pairs(raw) do
    slot = tonumber(slot)
    if slot and type(key) == "string" then
      if slot == 0 then
        if key ~= rootKey then
          dropped[#dropped + 1] = 0
        end
      else
        pins[slot] = key
      end
    end
  end
  return pins
end

--------------------------------------------------------------------------------
-- The chain the player picked
--------------------------------------------------------------------------------

-- A choice id is the keys of one whole chain joined by ">", so the chain an id names can always
-- be read back out of the id itself. Nothing else is needed: not the list it was offered in,
-- not the walk that produced that list, and not the caps that walk ran under.
local function choiceKeys(id)
  if type(id) ~= "string" or id == "" then
    return nil
  end
  local keys = {}
  for key in string.gmatch(id, "[^>]+") do
    keys[#keys + 1] = key
  end
  if #keys < 2 then
    return nil
  end
  return keys
end

-- Where the root stands in a chosen chain, so the rest of its keys can be read as slots. An id
-- that does not pass through this root was offered for another one and is no choice here.
local function rootStep(keys, rootKey)
  for index, key in ipairs(keys) do
    if key == rootKey then
      return index
    end
  end
  return nil
end

-- A chosen chain read as pins: one key per slot, the root's own slot left out.
local function pinsForChoice(keys, at)
  local pins = {}
  for index, key in ipairs(keys) do
    local slot = index - at
    if slot ~= 0 then
      pins[slot] = key
    end
  end
  return pins
end

local function runsAs(stages, keys, from, to)
  local at = 0
  for index = from, to do
    at = at + 1
    local stage = stages[at]
    if not stage or stage.key ~= keys[index] then
      return false
    end
  end
  return at == #stages
end

-- One half of a chosen chain, walked down the keys the id names rather than looked for among
-- whatever this call happened to enumerate. This is what makes a pick stick: the path cap, the
-- walk budget, the reagent a prefer would otherwise have followed and an edge that has arrived
-- since the list was drawn all change what a plain walk finds, and none of them may change what
-- the player asked for. nil where the graph no longer joins those keys up.
-- The variant that agrees with a chosen chain for as long as it can. Where a pin stops the
-- chosen chain being drawn whole, the rest of what the player picked is still worth keeping:
-- the chain nearest to it is a better answer than the shortest one in the list.
local function bestOfLike(paths, keys, from)
  local kept, longest = {}, -1
  for _, path in ipairs(paths) do
    local run = 0
    while path.stages[run + 1] and keys[from + run] and path.stages[run + 1].key == keys[from + run] do
      run = run + 1
    end
    if run > longest then
      kept, longest = { path }, run
    elseif run == longest then
      kept[#kept + 1] = path
    end
  end
  return bestOf(kept)
end

local function chosenSide(rootKey, direction, opts, pins, keys, from, to)
  local side = sidePins(pins, direction)
  if next(side) == nil then
    return nil
  end
  for _, path in ipairs(Chain.Paths(rootKey, direction, withPins(opts, side))) do
    if runsAs(path.stages, keys, from, to) then
      return path
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Choices
--------------------------------------------------------------------------------

local function weaker(a, b)
  if not a then
    return b
  end
  if not b then
    return a
  end
  if Confidence.Rank(a) <= Confidence.Rank(b) then
    return a
  end
  return b
end

-- The keys and names of one whole chain: an upward half, then a downward half with the root
-- it repeats dropped.
local function chainKeys(up, down)
  local keys, names = {}, {}
  if up then
    for _, stage in ipairs(up.stages) do
      keys[#keys + 1] = stage.key
      names[#names + 1] = stage.name
    end
  end
  if down then
    for index = (up and 2 or 1), #down.stages do
      keys[#keys + 1] = down.stages[index].key
      names[#names + 1] = down.stages[index].name
    end
  end
  return keys, names
end

-- The steps where the chains of one group part company, middle steps first: a fork named after
-- either end of a chain says nothing the label does not already say.
local function forkSteps(group)
  local longest = 0
  for _, entry in ipairs(group) do
    if #entry.keys > longest then
      longest = #entry.keys
    end
  end
  local middles, ends = {}, {}
  for step = 1, longest do
    local first, set, differs = nil, false, false
    local atEnd = false
    for _, entry in ipairs(group) do
      local key = entry.keys[step]
      if not set then
        first, set = key, true
      elseif key ~= first then
        differs = true
      end
      if step == 1 or step == #entry.keys then
        atEnd = true
      end
    end
    if differs then
      if atEnd then
        ends[#ends + 1] = step
      else
        middles[#middles + 1] = step
      end
    end
  end
  for _, step in ipairs(ends) do
    middles[#middles + 1] = step
  end
  return middles
end

-- The bracket one chain carries for a run of steps: the stages it stands on there, in order and
-- without saying the same name twice running, because a recipe and the item it makes read alike.
local function bracketFor(entry, steps, count)
  local parts, last = {}, nil
  for index = 1, count do
    local name = entry.names[steps[index]]
    if name and name ~= "" and name ~= last then
      parts[#parts + 1] = name
      last = name
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ", ")
end

-- Two chains that read "A to B" are told apart by the stages where they part company, which are
-- the steps the player is choosing between. As many of those are named as it takes to tell every
-- chain in the group apart, so a list never falls back on "(Runic Plate Boots) 2", which says
-- nothing at all about what the second one does differently.
local function disambiguate(list)
  local groups, order = {}, {}
  for _, entry in ipairs(list) do
    local group = groups[entry.label]
    if not group then
      group = {}
      groups[entry.label] = group
      order[#order + 1] = entry.label
    end
    group[#group + 1] = entry
  end
  for _, label in ipairs(order) do
    local group = groups[label]
    if #group > 1 then
      local steps = forkSteps(group)
      local enough = nil
      for count = 1, #steps do
        local taken, clash = {}, false
        for _, entry in ipairs(group) do
          local bracket = bracketFor(entry, steps, count) or ""
          if taken[bracket] then
            clash = true
            break
          end
          taken[bracket] = true
        end
        if not clash then
          enough = count
          break
        end
      end
      if enough then
        for _, entry in ipairs(group) do
          local bracket = bracketFor(entry, steps, enough)
          if bracket then
            entry.label = label .. " (" .. bracket .. ")"
          end
        end
      end
    end
  end
  -- Last resort, for two chains the graph itself states nothing different about.
  local taken = {}
  for _, entry in ipairs(list) do
    if taken[entry.label] then
      taken[entry.label] = taken[entry.label] + 1
      entry.label = entry.label .. " " .. tostring(taken[entry.label])
    else
      taken[entry.label] = 1
    end
  end
end

-- The last stage of a whole chain, which is the end product the entry is named after.
local function endStage(first, second)
  local half = second or first
  if not half then
    return nil
  end
  return half.stages[#half.stages]
end

-- One entry per whole chain worth offering, best first. The upward half is held still and the
-- downward half varies, because that is the end product the player is choosing; a root with
-- nothing downstream offers its upward halves instead.
local function buildChoices(up, variants, varyDown, limit)
  local list, byId = {}, {}
  for _, variant in ipairs(variants) do
    local first, second = variant, nil
    if varyDown then
      first, second = up, variant
    end
    local keys, names = chainKeys(first, second)
    local id = table.concat(keys, ">")
    if #keys > 0 and not byId[id] then
      byId[id] = variant
      local ending = endStage(first, second)
      list[#list + 1] = {
        id = id,
        label = names[1] .. " to " .. names[#names],
        depth = #keys,
        confidence = weaker(first and first.confidence, second and second.confidence),
        mined = (first and first.mined or 0) + (second and second.mined or 0),
        -- Whether the build will name what this chain ends on. Always a boolean, because the
        -- sort below compares the two.
        named = not (ending and ending.undiscovered),
        -- Whether this chain ends on a thing the player can hold. Always a boolean, for the same
        -- reason, and the same key Chain.Paths sorts by before its own cap.
        endsOnItem = ending ~= nil and ending.kind == "item",
        keys = keys,
        names = names,
      }
    end
  end
  table.sort(list, function(a, b)
    -- A chain that ends on something the build withholds is a real route and is still offered,
    -- but it reads "Arcane Crystal to Undiscovered permanent": it names nothing the player can
    -- go and make, so it never stands above one that does, however short it is. The neutral
    -- placeholder is the wording either way; this only decides where it sits.
    if a.named ~= b.named then
      return a.named
    end
    -- Then a chain that ends on something the player can hold, before one that ends on an
    -- enchant. Chain.Paths already sorted this way before its own cap, so the twelve offered here
    -- are drawn from the same head of the list and the two can never disagree about which chains
    -- the player is choosing between.
    if a.endsOnItem ~= b.endsOnItem then
      return a.endsOnItem
    end
    if a.depth ~= b.depth then
      return a.depth < b.depth
    end
    if a.mined ~= b.mined then
      return a.mined > b.mined
    end
    if a.label ~= b.label then
      return a.label < b.label
    end
    return a.id < b.id
  end)
  for index = #list, limit + 1, -1 do
    list[index] = nil
  end
  disambiguate(list)
  return list, byId
end

--------------------------------------------------------------------------------
-- Co-reagents, alternatives and the whole chain
--------------------------------------------------------------------------------

-- What one stage asks for alongside another: the reagents of a spell, or the items a quest
-- needs. Both are AND groups, so both read the same way. The recipe is read from Data, because
-- a spell's reagents are shipped data; a quest's required items are not, so they are read back
-- off the graph, where whoever supplied them put them. Brief CH1: with the walk's own options
-- (walkOptions), so a Classic Era quest the chain stepped through states its other items too.
local function groupNeeds(stage, childOpts)
  if stage.kind == "spell" then
    local recipe = Data:GetRecipe(stage.id)
    if not recipe then
      return nil
    end
    local out, asked = {}, {}
    for _, reagent in ipairs(recipe.re or EMPTY) do
      asked[reagent[1]] = true
      out[#out + 1] = { key = Graph.Key("item", reagent[1]), quantity = reagent[2] }
    end
    -- An item combine is cast by USING an item, which the build states in via and only
    -- sometimes repeats under SpellReagents. It is as much a thing the player has to be
    -- holding as a reagent is, so the chain asks for it the same way and a combine with no
    -- reagents at all still reads as a step with an input.
    for _, itemId in ipairs(recipe.via or EMPTY) do
      if not asked[itemId] then
        asked[itemId] = true
        out[#out + 1] = { key = Graph.Key("item", itemId) }
      end
    end
    if #out == 0 then
      return nil
    end
    return out
  end
  if stage.kind ~= "quest" then
    return nil
  end
  local out = {}
  local edges = childOpts and childrenOf(stage.key, Edges.UP, childOpts) or Graph.Children(stage.key, Edges.UP, EMPTY)
  for _, edge in ipairs(edges) do
    if edgeName(edge) == "QUEST_REQUIRES" then
      out[#out + 1] = { key = edge.target, quantity = edge.quantity }
    end
  end
  if #out == 0 then
    return nil
  end
  return out
end

-- Everything the stage after this one needs other than this item, or nil when this item is not
-- one of the things it needs at all (the recipe scroll that teaches it, for one).
local function coNeedsOf(groupStage, exceptKey, slot, childOpts)
  local needs = groupNeeds(groupStage, childOpts)
  if not needs then
    return nil
  end
  local out, feeds = {}, false
  for _, need in ipairs(needs) do
    local key = need.key
    if key == exceptKey then
      feeds = true
    else
      local node = Graph.Node(key)
      out[#out + 1] = {
        key = key,
        name = (node and node.name) or key,
        icon = node and node.icon or nil,
        quality = node and node.quality or nil,
        quantity = need.quantity,
        slot = slot,
      }
    end
  end
  if not feeds then
    return nil
  end
  return out
end

-- An item stage that feeds the spell or the quest stage after it states what else that stage
-- needs, so the slot reads "Arcane Crystal" over "+ 3 other reagents" rather than offering them
-- as routes. A quest says "+ 3 other items", because a quest has no reagents.
local function addCoReagents(stages, childOpts)
  for index, stage in ipairs(stages) do
    local after = stages[index + 1]
    if after and stage.kind == "item" and (after.kind == "spell" or after.kind == "quest") then
      local others = coNeedsOf(after, stage.key, stage.slot, childOpts)
      if others then
        stage.coReagents = others
        stage.coReagentKind = after.kind
      end
    end
  end
end

-- The stages the walk to one slot has already been through, the root included. The walk refuses
-- to stand on a node twice, so any of these offered in this slot would be a step no chain can
-- take, which is a row that answers a click with the chain it already had.
local function ancestorsOf(stages, rootIndex, index)
  local out = {}
  local first, last = rootIndex, index + 1
  if index > rootIndex then
    first, last = rootIndex, index - 1
  end
  local step = first <= last and 1 or -1
  for at = first, last, step do
    local stage = stages[at]
    if stage then
      out[stage.key] = true
    end
  end
  return out
end

-- The other steps that could stand in one slot. Counted at the branch the chain took, not by
-- what happens to sit the same distance from the root, so a co-reagent is never offered as a
-- route and a tool is never offered at all. A whole AND group is worth one entry: the reagent
-- the chain would follow, carrying the rest as its own co-reagents.
local function addAlternatives(stages, rootIndex, opts, childOpts)
  for index, stage in ipairs(stages) do
    if index ~= rootIndex then
      local upward = index < rootIndex
      local direction = upward and Edges.UP or Edges.DOWN
      local parent = stages[upward and index + 1 or index - 1]
      local edges = childrenOf(parent.key, direction, childOpts)
      local ancestors = ancestorsOf(stages, rootIndex, index)
      -- The edge the chain took at this branch. Reading order puts what an upward edge states
      -- on the stage in front of it, so upward it is the parent that names the edge type.
      local followed = stage.edgeType
      if upward then
        followed = parent.edgeType
      end
      local grouped = followed ~= nil and GROUP_EDGES[followed] == true
      local startFollowed = followed ~= nil and START_EDGES[followed] == true
      local member = nil
      if not grouped then
        local group = {}
        for _, edge in ipairs(edges) do
          if isGroup(edge) and edge.target ~= stage.key then
            group[#group + 1] = edge
          end
        end
        if #group > 0 then
          member = pickGroupMember(group, opts.prefer)
        end
      end
      local seen = { [stage.key] = true }
      for _, edge in ipairs(edges) do
        -- A disenchant result is never a route the chain could have taken here, so it is never
        -- one of the steps offered in this slot either.
        local keep = not isTool(edge)
          and not isDisenchant(edge)
          and not isSummary(edge)
          and not seen[edge.target]
          and not ancestors[edge.target]
        if keep and isStart(edge) then
          keep = startFollowed
        end
        if keep and isGroup(edge) then
          keep = edge == member
        end
        if keep then
          seen[edge.target] = true
          local alternative = buildStage(edge.target, edge)
          if alternative then
            finaliseStage(stripStep(alternative))
            alternative.slot = stage.slot
            alternative.alternatives = {}
            alternative.coReagents = (edge == member and coNeedsOf(parent, edge.target, stage.slot, childOpts)) or {}
            if #alternative.coReagents > 0 then
              alternative.coReagentKind = parent.kind
            end
            local list = stage.alternatives
            list[#list + 1] = alternative
          end
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- The disenchant signposts
--------------------------------------------------------------------------------

-- The kind both signposts carry. It is not a node kind: there is no such node, nothing walks to
-- one, nothing can be pinned in one, no alternative is ever counted on one, and it never stands
-- in the middle of a chain. It is a sign at the end saying what happens next, and clicking it
-- takes the player to the stage it belongs to with the right view up.
Chain.DISENCHANT_KIND = "disenchant"

-- The Assets key the Disenchants into category wears, which is what a signpost draws. A key and
-- never a path, so UI/Assets.lua is still the only place a texture is named.
Chain.DISENCHANT_ICON = "CAT_ENCHANTING"

-- How many results a piece of equipment is predicted to disenchant into, or nil where it cannot
-- be disenchanted at all. One read of the band the rule already holds, which is the same read
-- behind Graph.Summary's disenchant flag, and it answers the count as well so the signpost can
-- say how many results there are without a second pass.
local function disenchantResults(stage)
  if type(stage) ~= "table" or stage.kind ~= "item" then
    return nil
  end
  local item = Data:GetItem(stage.id)
  if not item then
    return nil
  end
  local band = Data:DisenchantBand(item)
  if not band then
    return nil
  end
  local count = #(band.out or EMPTY)
  if count < 1 then
    return nil
  end
  return count
end

-- How many things disenchant into one material, or nil where nothing does. Data answers an empty
-- list outright for an item the rule does not name as a material, so an ordinary item costs one
-- lookup and never builds the index behind it.
local function disenchantSources(stage)
  if type(stage) ~= "table" or stage.kind ~= "item" then
    return nil
  end
  local sources = Data:DisenchantSources(stage.id)
  local count = #(sources or EMPTY)
  if count < 1 then
    return nil
  end
  return count
end

-- One signpost. It carries no key at all, which is what keeps it out of everything a key stands
-- for: the chain's own id is its keys joined by ">", a pin is a key in a slot, and an alternative
-- is a key the walk could have taken instead. `of` is the stage it belongs to, which is the node
-- a click on it opens, and `view` is the view that node should be opened on.
local function signpost(of, slot, leading)
  local stage = {
    kind = Chain.DISENCHANT_KIND,
    of = of.key,
    ofKind = of.kind,
    icon = Chain.DISENCHANT_ICON,
    slot = slot,
    alternatives = {},
    coReagents = {},
    badges = {},
  }
  if leading then
    stage.leading = true
    stage.name = L["Disenchanted from"]
    stage.view = Edges.SOURCES or "sources"
  else
    stage.terminal = true
    stage.name = L["Disenchants"]
    stage.view = Edges.DISENCHANTS or "disenchants"
  end
  return stage
end

-- "4 results", the line under the signpost at the end of a chain: how many things the rule
-- predicts the last item disenchants into.
function Chain.DisenchantResultsText(count)
  count = tonumber(count) or 0
  if count < 1 then
    return nil
  end
  if count == 1 then
    return L["1 result"]
  end
  return string.format(L["%d results"], count)
end

-- The whole chain through a node, both directions at once, with the node in the middle:
-- { stages, rootIndex, choices, choice, label, dropped }, where stages[rootIndex] is the
-- root. For Arcanite Bar that is Thorium Ore and Arcane Crystal on the left, the bar itself,
-- and then what the bar goes on to make on the right, through to the end product.
--
-- The two halves are Chain.Paths walked once in each direction: the best upward path already
-- reads earliest stage first and ends on the root, and the chosen downward path starts on the
-- root, so the chain is the first followed by the second with its root dropped. Every arrow
-- still belongs to the edge drawn under it, because neither half is re-ordered here.
--
-- Neither half follows a predicted disenchant, so the chain ends at the item that would be
-- disenchanted. Where that item has results, one signpost is appended after it, and where the
-- chain begins on something that is disenchanted from other items, one is put in front. Both
-- carry kind = "disenchant" and no key at all: they are not steps, they are not in the chain's
-- id or its label, they hold no alternatives and no co-reagents, and nothing can be pinned in
-- one. Each states `of`, the stage it belongs to, and `view`, the view that stage should be
-- opened on, which is what a click on it asks the window for.
--
-- opts takes everything Chain.Paths takes, and:
--   choice  an id from Chain.Choices, which picks the chain to show.
--   pins    { [slot] = nodeKey }, slots counted from the root. The chain passes through each
--           pinned node, and the rest is the best chain that can. A pin nothing can meet is
--           dropped and its slot is named in result.dropped. Every alternative a stage offers
--           can be pinned in its own slot. A co-reagent can only be pinned upstream of the root
--           (slot < 0), where following it instead is a different way up to the same recipe; at
--           the root and downstream the slot is decided by the walk out of the root, so nothing
--           that is not on that walk can stand there and the pin is dropped.
--   prefer  a node key. Where a recipe has several reagents the chain follows this one.
--
-- Brief CH1 (owner QA 2026-10-18 item 249): every walk steps through the Classic Era quest rows
-- (Graph.ChainQuestEdge: Horn of the Red Wolf to Wolf Swapping to the swift wolves) and never an Era
-- drop or vendor, leaves out the other side's quests, vendors and trainers while "Hide other faction
-- data" is on (Chain.HiddenSide, opts.hideOtherFaction for a caller that states it), and a quest
-- stage of the other side says so on its meta line with the setting off (Chain.SideWords).
function Chain.Full(rootKey, opts)
  opts = opts or EMPTY
  local root = buildStage(rootKey, nil)
  if not root then
    return { stages = {}, rootIndex = 0, choices = {}, dropped = {} }
  end
  finaliseStage(root)

  local childOpts = walkOptions(opts)
  local dropped = {}
  local pins = normalisePins(opts.pins, rootKey, dropped)

  -- A choice id is a whole chain, so the chain behind one can be read straight back out of it.
  -- A pin is the narrower thing to say and stands whatever chain was picked: pinning a stage of
  -- the chain in hand swaps that one step and recomputes the rest, which is a different chain
  -- from the one the id names. So the chosen chain is rebuilt only where it stands on every pin,
  -- and where it cannot, the nearest chain that does is drawn rather than the shortest one.
  --
  -- This is the whole of a pick that does nothing. The sides are walked under the pins and the
  -- chosen id used to be looked for among what survived and nothing else: a path cap, a walk
  -- budget, a reagent a prefer sent the walk down or an edge that arrived after the list was
  -- drawn each take that one path out of the walk, the id is not found, and the chain the player
  -- already had is handed back with nothing to say it was not the one they asked for.
  local wanted = choiceKeys(opts.choice)
  local wantedAt = wanted and rootStep(wanted, rootKey) or nil
  local wantedPins = wantedAt and pinsForChoice(wanted, wantedAt) or nil
  local standsOnPins = wantedPins ~= nil
  if standsOnPins then
    for slot, key in pairs(pins) do
      if wantedPins[slot] ~= key then
        standsOnPins = false
        break
      end
    end
  end
  if not wantedAt then
    wanted = nil
  end

  local walkOpts = withPins(opts, pins)
  -- Brief CH1: every walk this call starts shares its options, and so its memo (childrenOf).
  walkOpts.walk = childOpts
  local upPaths = sidePaths(rootKey, Edges.UP, walkOpts, pins, dropped)
  local downPaths = sidePaths(rootKey, Edges.DOWN, walkOpts, pins, dropped)

  local varyDown = #downPaths > 0
  local variants = upPaths
  if varyDown then
    variants = downPaths
  end
  local up, down = bestOfPreferring(upPaths, opts.prefer), nil
  local choices, byId = buildChoices(up, variants, varyDown, opts.maxChoices or Chain.DEFAULTS.maxChoices)

  local picked = (type(opts.choice) == "string" and byId[opts.choice]) or nil
  if picked then
    if varyDown then
      down = picked
    else
      up = picked
    end
  else
    local chosenUp, chosenDown, rebuilt = nil, nil, false
    if wanted and standsOnPins then
      if wantedAt > 1 then
        chosenUp = chosenSide(rootKey, Edges.UP, walkOpts, wantedPins, wanted, 1, wantedAt)
      end
      if wantedAt < #wanted then
        chosenDown = chosenSide(rootKey, Edges.DOWN, walkOpts, wantedPins, wanted, wantedAt, #wanted)
      end
      rebuilt = (wantedAt == 1 or chosenUp ~= nil) and (wantedAt == #wanted or chosenDown ~= nil)
    end
    if rebuilt then
      up, down = chosenUp, chosenDown
    else
      if wanted then
        -- The variants are the downward halves where there is one, so a downward variant is
        -- compared from the root's own step in the chosen chain and an upward one from its start.
        local from = 1
        if varyDown then
          from = wantedAt
        end
        picked = bestOfLike(variants, wanted, from)
      end
      if not picked then
        picked = bestOfPreferring(variants, opts.prefer)
      end
      if varyDown then
        down = picked
      else
        up = picked
      end
    end
  end

  local stages, rootIndex = {}, 1
  if up then
    for _, stage in ipairs(up.stages) do
      stages[#stages + 1] = copyStage(stage)
    end
    rootIndex = #stages
  else
    stages[1] = copyStage(root)
  end
  if down then
    for index = 2, #down.stages do
      stages[#stages + 1] = copyStage(down.stages[index])
    end
  end

  local keys = {}
  for index, stage in ipairs(stages) do
    stage.slot = index - rootIndex
    stage.alternatives = {}
    stage.coReagents = {}
    keys[index] = stage.key
  end
  addAlternatives(stages, rootIndex, opts, childOpts)
  addCoReagents(stages, childOpts)

  local id = table.concat(keys, ">")
  local label = stages[1].name .. " to " .. stages[#stages].name
  for _, entry in ipairs(choices) do
    if entry.id == id then
      label = entry.label
    end
  end
  table.sort(dropped)

  -- The signposts, added once the chain is whole and its id and its label are both settled: they
  -- are steps in neither, so a chain still reads "Arcane Crystal to Dawnbringer Shoulders" and is
  -- still named by the keys of its real stages. Appending cannot move a stage that is already
  -- there, and prepending moves the root index with it, so every real slot is the number it
  -- already was and a pin still lands where the player put it.
  --
  -- Both stand for a prediction, so both follow the same switch the predicted edges follow: a
  -- player who has turned predictions off is told nothing about the enchanting table at all.
  if opts.showPredicted ~= false then
    local last = stages[#stages]
    local results = disenchantResults(last)
    if results then
      local sign = signpost(last, last.slot + 1, false)
      sign.meta = Chain.DisenchantResultsText(results)
      sign.results = results
      stages[#stages + 1] = sign
    end
    local first = stages[1]
    local sources = disenchantSources(first)
    if sources then
      local sign = signpost(first, first.slot - 1, true)
      sign.sources = sources
      table.insert(stages, 1, sign)
      rootIndex = rootIndex + 1
    end
  end

  return {
    stages = stages,
    rootIndex = rootIndex,
    choices = choices,
    choice = id,
    label = label,
    dropped = dropped,
  }
end

-- The chains worth offering in the selector, best first: { id, label, depth, confidence,
-- mined, keys, names }. An id is what opts.choice takes. Chain.Full states the same list, so
-- a caller that wants both asks for the chain and reads result.choices rather than walking
-- the graph twice.
function Chain.Choices(rootKey, opts)
  return Chain.Full(rootKey, opts).choices
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

-- "+ 3 other reagents", the label on the control under a stage a recipe needs alongside others.
-- The "+" reads as the recipe's own arithmetic and leaves the button room for the count, which
-- the older "plus" wording did not at the width of one stage slot.
--
-- kind is the stage the group belongs to: a quest has no reagents, so "+ 3 other items" is what
-- one of those reads. Left out, the wording is the recipe's, which is what every caller written
-- before quests reached the graph asks for.
function Chain.CoReagentsText(count, kind)
  count = tonumber(count) or 0
  if count < 1 then
    return nil
  end
  if kind == "quest" then
    if count == 1 then
      return L["+ 1 other item"]
    end
    return string.format(L["+ %d other items"], count)
  end
  if count == 1 then
    return L["+ 1 other reagent"]
  end
  return string.format(L["+ %d other reagents"], count)
end

-- "Requires Blacksmith Hammer", the tools a recipe stage asks the player to be holding.
function Chain.ToolsText(tools)
  if type(tools) ~= "table" or #tools == 0 then
    return nil
  end
  local names = {}
  for index, tool in ipairs(tools) do
    names[index] = tool.name or ""
  end
  return string.format(L["Requires %s"], table.concat(names, ", "))
end

return Chain
