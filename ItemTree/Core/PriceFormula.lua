-- The price formula (brief K20c, design K20 section 2): the player's own Bar, the price the
-- auction house has to clear before an item reads Sell (AH), written in a small language of our
-- own and read by our own code. Never loadstring, never load, never anything that runs the text.
-- Loaded as: local _, ItemTree = ...
--
-- The language, TSM style:
--   names     vendor (the vendor sell price), auction (the first auction addon that answers),
--             auctionator, auctioneer, dbmarket and dbminbuyout (TSM), disenchant (the expected
--             disenchant value after the cut, brief K20-wire; empty without Enchanting). Upper or lower case alike.
--   numbers   12, 1.5, .25
--   money     1g20s5c, 20s, 5c, 3g: gold, silver and copper in that order, each part optional
--             but one at least, each a whole number; read as copper
--   operators + - * / with the usual precedence, a leading minus, and brackets
--   functions min(), max(), avg() over any number of terms, skipping empty ones; first(), the
--             first term that has a value
-- A name whose source has no price is empty, and so is any sum, difference, product or quotient
-- with an empty side, or a division by nothing; min, max and avg skip empty terms and are empty
-- with none left. The answer is copper; an empty or negative answer means "use the default stop".
--
-- PriceFormula.Parse answers the tree or nil with the position (1 based, in characters) and the
-- words of the first fault; PriceFormula.Evaluate answers a number or nil. Nothing here raises:
-- every entry point is wrapped, a formula longer than MAX_LENGTH or nested deeper than MAX_DEPTH
-- is a fault like any other, and a fault is stored and reported, never thrown.
local _, ItemTree = ...

local PriceFormula = {}
ItemTree.PriceFormula = PriceFormula

PriceFormula.MAX_LENGTH = 400
PriceFormula.MAX_DEPTH = 40

-- The names a formula may read, each to the key Core/Prices.lua answers it by.
PriceFormula.NAMES = {
  vendor = true,
  auction = true,
  auctionator = true,
  auctioneer = true,
  dbmarket = true,
  dbminbuyout = true,
  disenchant = true,
}

PriceFormula.FUNCTIONS = { min = true, max = true, avg = true, first = true }

local COPPER = { g = 10000, s = 100, c = 1 }
local UNIT_ORDER = { g = 1, s = 2, c = 3 }

-- Pure helpers ----------------------------------------------------------------

local function isDigit(ch)
  return ch ~= "" and ch:match("%d") ~= nil
end

local function isLetter(ch)
  return ch ~= "" and ch:match("[%a_]") ~= nil
end

-- A fault: nil, the position and the words.
local function fault(pos, words)
  return nil, pos, words
end

-- The tokens of a formula: { kind, value, pos }, kind "number" (value in copper or a plain
-- number), "name", "op" (+ - * /), "(", ")", ",", then "end". Or nil, the position and the
-- words of the first character it cannot read. Pure.
local function tokenise(text)
  local tokens = {}
  local pos, length = 1, #text
  while pos <= length do
    local ch = text:sub(pos, pos)
    if ch:match("%s") then
      pos = pos + 1
    elseif isDigit(ch) or (ch == "." and isDigit(text:sub(pos + 1, pos + 1))) then
      local start = pos
      local number = text:match("^%d*%.?%d*", pos)
      pos = pos + #number
      local unit = text:sub(pos, pos):lower()
      if COPPER[unit] and not isLetter(text:sub(pos + 1, pos + 1)) then
        -- Money: whole numbers, each with its unit, in the order gold, silver, copper.
        if number:find(".", 1, true) then
          return fault(start, "money takes whole numbers")
        end
        local copper, last = 0, 0
        while true do
          if UNIT_ORDER[unit] <= last then
            return fault(pos, "money reads gold, then silver, then copper")
          end
          last = UNIT_ORDER[unit]
          copper = copper + tonumber(number) * COPPER[unit]
          pos = pos + 1
          local more = text:match("^%d+", pos)
          if not more then
            break
          end
          local nextUnit = text:sub(pos + #more, pos + #more):lower()
          if not COPPER[nextUnit] then
            return fault(pos + #more, "a number in money needs g, s or c after it")
          end
          number, unit = more, nextUnit
          pos = pos + #more
        end
        if isLetter(text:sub(pos, pos)) then
          return fault(pos, "unexpected letter after money")
        end
        tokens[#tokens + 1] = { kind = "number", value = copper, pos = start }
      else
        local value = tonumber(number)
        if value == nil then
          return fault(start, "not a number")
        end
        if isLetter(text:sub(pos, pos)) then
          return fault(pos, "a number needs g, s or c, or nothing, after it")
        end
        tokens[#tokens + 1] = { kind = "number", value = value, pos = start }
      end
    elseif isLetter(ch) then
      local word = text:match("^[%a_][%w_]*", pos)
      tokens[#tokens + 1] = { kind = "name", value = word:lower(), pos = pos }
      pos = pos + #word
    elseif ch == "+" or ch == "-" or ch == "*" or ch == "/" then
      tokens[#tokens + 1] = { kind = "op", value = ch, pos = pos }
      pos = pos + 1
    elseif ch == "(" or ch == ")" or ch == "," then
      tokens[#tokens + 1] = { kind = ch, value = ch, pos = pos }
      pos = pos + 1
    else
      return fault(pos, "unexpected '" .. ch .. "'")
    end
  end
  tokens[#tokens + 1] = { kind = "end", pos = length + 1 }
  return tokens
end

-- The parser: recursive descent over the tokens, answering a tree of
--   { kind = "number", value } | { kind = "name", name } | { kind = "neg", arg }
--   | { kind = "op", op, left, right } | { kind = "call", name, args }
-- Errors travel as a table raised inside and caught by PriceFormula.Parse, the one pcall.
local ParseError = {}

local function newParser(tokens)
  local parser = { tokens = tokens, at = 1, depth = 0 }

  local function peek()
    return parser.tokens[parser.at]
  end

  local function advance()
    local token = parser.tokens[parser.at]
    parser.at = parser.at + 1
    return token
  end

  local function stop(token, words)
    error(setmetatable({ pos = token.pos, words = words }, ParseError), 0)
  end

  local function deeper(token)
    parser.depth = parser.depth + 1
    if parser.depth > PriceFormula.MAX_DEPTH then
      stop(token, "nested too deeply")
    end
  end

  local expression

  local function primary()
    local token = advance()
    if token.kind == "number" then
      return { kind = "number", value = token.value }
    end
    if token.kind == "name" then
      if PriceFormula.FUNCTIONS[token.value] then
        if peek().kind ~= "(" then
          stop(peek(), token.value .. " needs brackets")
        end
        advance()
        deeper(token)
        local args = {}
        if peek().kind ~= ")" then
          args[#args + 1] = expression()
          while peek().kind == "," do
            advance()
            args[#args + 1] = expression()
          end
        end
        if peek().kind ~= ")" then
          stop(peek(), "expected ')'")
        end
        advance()
        parser.depth = parser.depth - 1
        if #args == 0 then
          stop(token, token.value .. " needs at least one term")
        end
        return { kind = "call", name = token.value, args = args }
      end
      if PriceFormula.NAMES[token.value] then
        return { kind = "name", name = token.value }
      end
      stop(token, "unknown name '" .. token.value .. "'")
    end
    if token.kind == "(" then
      deeper(token)
      local inner = expression()
      if peek().kind ~= ")" then
        stop(peek(), "expected ')'")
      end
      advance()
      parser.depth = parser.depth - 1
      return inner
    end
    if token.kind == "end" then
      stop(token, "unexpected end")
    end
    stop(token, "unexpected '" .. tostring(token.value) .. "'")
  end

  local function unary()
    local token = peek()
    if token.kind == "op" and token.value == "-" then
      advance()
      deeper(token)
      local arg = unary()
      parser.depth = parser.depth - 1
      return { kind = "neg", arg = arg }
    end
    if token.kind == "op" and token.value == "+" then
      advance()
      deeper(token)
      local arg = unary()
      parser.depth = parser.depth - 1
      return arg
    end
    return primary()
  end

  local function term()
    local left = unary()
    while peek().kind == "op" and (peek().value == "*" or peek().value == "/") do
      local op = advance().value
      left = { kind = "op", op = op, left = left, right = unary() }
    end
    return left
  end

  expression = function()
    local left = term()
    while peek().kind == "op" and (peek().value == "+" or peek().value == "-") do
      local op = advance().value
      left = { kind = "op", op = op, left = left, right = term() }
    end
    return left
  end

  parser.expression = expression
  parser.peek = peek
  parser.stop = stop
  return parser
end

-- Parses a formula. Answers the tree, or nil, the position of the fault (1 based) and its words.
-- Never raises. Pure.
function PriceFormula.Parse(text)
  if type(text) ~= "string" then
    return fault(1, "no formula")
  end
  if #text > PriceFormula.MAX_LENGTH then
    return fault(PriceFormula.MAX_LENGTH + 1, "longer than " .. PriceFormula.MAX_LENGTH .. " characters")
  end
  if not text:find("%S") then
    return fault(1, "empty formula")
  end
  local okTokens, tokens, pos, words = pcall(tokenise, text)
  if not okTokens then
    return fault(1, "not understood")
  end
  if not tokens then
    return fault(pos, words)
  end
  local ok, tree = pcall(function()
    local parser = newParser(tokens)
    local result = parser.expression()
    if parser.peek().kind ~= "end" then
      parser.stop(parser.peek(), "unexpected '" .. tostring(parser.peek().value) .. "'")
    end
    return result
  end)
  if ok then
    return tree
  end
  if getmetatable(tree) == ParseError then
    return fault(tree.pos, tree.words)
  end
  return fault(1, "not understood")
end

-- A finite number, or nil. Pure.
local function finite(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return value
end

-- Evaluates a tree against values, a table name to copper (nil or missing for empty) or a
-- function(name) answering the same. Answers a number or nil (empty). Never raises. Pure.
function PriceFormula.Evaluate(tree, values)
  local function read(name)
    local value
    if type(values) == "function" then
      local ok, answer = pcall(values, name)
      value = ok and answer or nil
    elseif type(values) == "table" then
      value = values[name]
    end
    return finite(tonumber(value))
  end
  local function walk(node, depth)
    if type(node) ~= "table" or depth > PriceFormula.MAX_DEPTH * 4 then
      return nil
    end
    if node.kind == "number" then
      return finite(node.value)
    end
    if node.kind == "name" then
      return read(node.name)
    end
    if node.kind == "neg" then
      local value = walk(node.arg, depth + 1)
      return value and -value or nil
    end
    if node.kind == "op" then
      local left, right = walk(node.left, depth + 1), walk(node.right, depth + 1)
      if left == nil or right == nil then
        return nil
      end
      if node.op == "+" then
        return finite(left + right)
      elseif node.op == "-" then
        return finite(left - right)
      elseif node.op == "*" then
        return finite(left * right)
      end
      if right == 0 then
        return nil
      end
      return finite(left / right)
    end
    if node.kind == "call" then
      local list = {}
      for _, arg in ipairs(node.args or {}) do
        local value = walk(arg, depth + 1)
        if node.name == "first" and value ~= nil then
          return value
        end
        if value ~= nil then
          list[#list + 1] = value
        end
      end
      if #list == 0 then
        return nil
      end
      local result = list[1]
      if node.name == "avg" then
        local sum = 0
        for _, value in ipairs(list) do
          sum = sum + value
        end
        return finite(sum / #list)
      end
      for index = 2, #list do
        if node.name == "min" and list[index] < result then
          result = list[index]
        elseif node.name == "max" and list[index] > result then
          result = list[index]
        end
      end
      return result
    end
    return nil
  end
  local ok, value = pcall(walk, tree, 0)
  if ok then
    return value
  end
  return nil
end

-- One call: parse and evaluate a formula against values. Answers the number or nil, then (on a
-- fault) the position and the words. Never raises. Pure.
function PriceFormula.Run(text, values)
  local tree, pos, words = PriceFormula.Parse(text)
  if not tree then
    return nil, pos, words
  end
  return PriceFormula.Evaluate(tree, values)
end

-- Parsed trees by text, so a bag pass parses the player's formula once. Small: one formula is in
-- use at a time.
PriceFormula.parsed = {}
local parsedCount = 0

function PriceFormula.Reset()
  PriceFormula.parsed = {}
  parsedCount = 0
end

-- The tree for a text from the cache, or nil, the fault's position and words. Pure apart from
-- the cache.
function PriceFormula.Compiled(text)
  if type(text) ~= "string" then
    return PriceFormula.Parse(text)
  end
  local held = PriceFormula.parsed[text]
  if held == nil then
    local tree, pos, words = PriceFormula.Parse(text)
    held = { tree = tree, pos = pos, words = words }
    if parsedCount >= 8 then
      PriceFormula.Reset()
    end
    PriceFormula.parsed[text] = held
    parsedCount = parsedCount + 1
  end
  return held.tree, held.pos, held.words
end

-- Whether the saved formula is in use and understood: answers true, or false with the position
-- and words of the fault. settings are the saved ones unless given. Pure over ItemTree.db.
function PriceFormula.Check(settings)
  if type(settings) ~= "table" then
    local db = ItemTree.db
    settings = type(db) == "table" and type(db.settings) == "table" and db.settings or {}
  end
  local tree, pos, words = PriceFormula.Compiled(settings.keepSellFormula)
  if tree then
    return true
  end
  return false, pos, words
end

-- Brief K20-wire: the "disenchant" name's copper for a score: the expected disenchant value after
-- the auction house's cut (score.disenchant.copper x 0.95, rounded down), the same net figure
-- Core/Keep.lua weighs against the Bar, since the Bar is compared with net prices. Empty (nil) where
-- the score has no disenchant facts (Keep puts them there only with Enchanting at the item's
-- rank) or no material has a price. Pure.
PriceFormula.AUCTION_CUT = 0.95

function PriceFormula.DisenchantNet(score)
  local facts = type(score) == "table" and score.disenchant or nil
  local copper = type(facts) == "table" and tonumber(facts.copper) or nil
  if copper == nil or copper ~= copper or copper <= 0 then
    return nil
  end
  local keep = ItemTree.Keep
  local cut = type(keep) == "table" and tonumber(keep.AUCTION_CUT) or PriceFormula.AUCTION_CUT
  return math.floor(copper * cut)
end

-- The Bar in copper the saved formula answers for one score (Core/Keep.lua's: vendor, auction,
-- itemId), or nil where the Formula stop is not chosen, the formula is not understood, or it is
-- empty or negative (Core/Keep.lua's default stop then). The per source names are asked of
-- Core/Prices.lua (Prices.FromSource), cached a minute per item like every other price.
function PriceFormula.BarFor(settings, score)
  if type(settings) ~= "table" or settings.keepSellBar ~= "formula" or type(score) ~= "table" then
    return nil
  end
  local tree = PriceFormula.Compiled(settings.keepSellFormula)
  if not tree then
    return nil
  end
  local prices = ItemTree.Prices
  local value = PriceFormula.Evaluate(tree, function(name)
    if name == "vendor" then
      return score.vendor
    end
    if name == "auction" then
      return score.auction
    end
    if name == "disenchant" then
      return PriceFormula.DisenchantNet(score)
    end
    if type(prices) == "table" and type(prices.FromSource) == "function" and score.itemId then
      local ok, copper = pcall(prices.FromSource, name, score.itemId)
      return ok and copper or nil
    end
    return nil
  end)
  if value == nil or value < 0 then
    return nil
  end
  return value
end

return PriceFormula
