-- Brief G1: the error boundary. Guard.Run calls one of ItemTree's own functions under xpcall, so
-- a page that cannot be drawn shows an empty page instead of breaking the window, and a tooltip
-- or bag slot whose data is missing simply goes without our lines or marks.
--
-- Catching must never make an error quieter than it is today. Every error caught here is handed
-- to the client's own error handler (geterrorhandler) from inside the xpcall handler, while the
-- stack is still live, so the error popup or BugSack shows exactly what an uncaught error would
-- have shown, stack and all. It goes there the first time each distinct message is met in a
-- session, in dev and packaged builds alike; a repeat is counted and not shown again, so an
-- OnUpdate loop cannot flood. The last few are kept in memory for /itemtree debug and never
-- written to saved variables. Nothing personal is ever recorded: the place, the message, the
-- stack, the time and a count.
--
-- Guard.strict (false by default) turns the catch off altogether: Run just calls the function.
-- tests/helpers.lua sets it for the whole busted suite, so no spec can pass because the boundary
-- swallowed its error; only Guard's own specs turn it off.
--
-- Only ever wrap ItemTree's own functions and the bodies of its own callbacks. Never a Blizzard
-- function, never a script on a Blizzard frame (the taint rule).
local _, ItemTree = ...
ItemTree = ItemTree or {}

local Guard = {}
ItemTree.Guard = Guard

Guard.strict = false
-- How many caught errors the ring keeps, newest last.
Guard.RING_SIZE = 10
-- How many distinct messages a session hands to the error handler. Past this, a new message is
-- recorded and counted but not shown, so a loop whose message changes every pass (an id in it)
-- still cannot flood the client.
Guard.REPORT_LIMIT = 50
-- How many of the ring /itemtree debug prints.
Guard.DEBUG_LINES = 5

-- Session state, in memory only.
local function resetState()
  Guard.ring = {}
  Guard.byMessage = {}
  Guard.reported = {}
  Guard.reportedCount = 0
  Guard.total = 0
end
resetState()

--- Forgets everything caught this session. For the specs.
function Guard.Reset()
  resetState()
end

--- The first line of an error message, with the chunk position kept. Pure.
function Guard.FirstLine(message)
  local text = tostring(message)
  local line = text:match("^([^\n]*)") or text
  return line
end

--- Files one caught error: a repeat of a message already in the ring bumps its count and its
--- time, a new one goes on the end and the oldest falls off past Guard.RING_SIZE. Answers the
--- entry and whether this is the first time the message was met this session. Pure but for the
--- module's own state.
function Guard.Record(where, message, stack, now)
  message = tostring(message)
  Guard.total = Guard.total + 1
  local entry = Guard.byMessage[message]
  if entry then
    entry.count = entry.count + 1
    entry.time = now
    entry.where = tostring(where)
  else
    entry = { where = tostring(where), message = message, stack = stack, time = now, count = 1 }
    Guard.byMessage[message] = entry
    local ring = Guard.ring
    ring[#ring + 1] = entry
    while #ring > Guard.RING_SIZE do
      local dropped = table.remove(ring, 1)
      if Guard.byMessage[dropped.message] == dropped then
        Guard.byMessage[dropped.message] = nil
      end
    end
  end
  local first = not Guard.reported[message]
  if first then
    if Guard.reportedCount >= Guard.REPORT_LIMIT then
      first = false
    else
      Guard.reported[message] = true
      Guard.reportedCount = Guard.reportedCount + 1
    end
  end
  return entry, first
end

--- The lines /itemtree debug prints: the count, and when there is one the last few as
--- "where: first line of the message (xK)", newest first. Pure.
function Guard.DebugLines(max)
  max = tonumber(max) or Guard.DEBUG_LINES
  local lines = { string.format("Errors caught: %d", Guard.total) }
  local ring = Guard.ring
  local shown = 0
  for index = #ring, 1, -1 do
    if shown >= max then
      break
    end
    local entry = ring[index]
    lines[#lines + 1] = string.format("  %s: %s (x%d)", entry.where, Guard.FirstLine(entry.message), entry.count)
    shown = shown + 1
  end
  return lines
end

--------------------------------------------------------------------------------
-- Client side. Guarded
--------------------------------------------------------------------------------

local function now()
  local clock = rawget(_G, "GetTime")
  if type(clock) == "function" then
    local ok, value = pcall(clock)
    if ok and type(value) == "number" then
      return value
    end
  end
  local lib = rawget(_G, "os")
  if type(lib) == "table" and type(lib.clock) == "function" then
    return lib.clock()
  end
  return 0
end

local function stackOf(message)
  local dbg = rawget(_G, "debug")
  if type(dbg) == "table" and type(dbg.traceback) == "function" then
    local ok, stack = pcall(dbg.traceback, tostring(message), 3)
    if ok and type(stack) == "string" then
      return stack
    end
  end
  local debugstack = rawget(_G, "debugstack")
  if type(debugstack) == "function" then
    local ok, stack = pcall(debugstack, 3)
    if ok and type(stack) == "string" then
      return tostring(message) .. "\n" .. stack
    end
  end
  return tostring(message)
end

--- Hands one error to the client's own error handler, as an uncaught error would reach it.
--- Answers whether the handler took it.
function Guard.Report(message)
  local get = rawget(_G, "geterrorhandler")
  if type(get) ~= "function" then
    return false
  end
  local ok, handler = pcall(get)
  if not ok or type(handler) ~= "function" then
    return false
  end
  return (pcall(handler, message))
end

-- The place the innermost Run is guarding, for the handler, which takes only the error.
local currentWhere = "unknown"

-- Records one error and, the first time its message is met, hands it to the client's handler.
local function note(err)
  local _, first = Guard.Record(currentWhere, err, stackOf(err), now())
  if first then
    Guard.Report(err)
  end
end

-- The xpcall handler. It runs before the stack unwinds, which is what lets the client's handler
-- (and BugSack's debugstack) see the stack where the error was raised. Nothing in it may raise.
local function onError(err)
  pcall(note, err)
  return err
end

-- What Run answers after the call: the function's own answers behind true, or false alone.
local function finish(where, ok, ...)
  currentWhere = where
  if ok then
    return true, ...
  end
  return false
end

-- Lua 5.1's own xpcall hands no arguments on; the client's does. Asked once, so the client never
-- allocates a closure per call, and plain 5.1 (busted) packs the arguments into a table instead.
local xpcallPassesArgs
do
  local ok, value = xpcall(function(arg)
    return arg
  end, onError, true)
  xpcallPassesArgs = ok and value == true
end

-- Lua 5.1's unpack, or 5.3's table.unpack under the browser harness.
local unpackArgs = rawget(_G, "unpack") or rawget(table, "unpack")

local packedFn, packedArgs, packedCount
local function unpacked()
  local fn, args, count = packedFn, packedArgs, packedCount
  packedFn, packedArgs, packedCount = nil, nil, nil
  return fn(unpackArgs(args, 1, count))
end

--- Calls fn(...) under the boundary. Answers true and fn's own answers, or false where fn
--- raised, after the error is recorded and (the first time this session) handed to the client's
--- error handler. With Guard.strict on, fn is simply called and an error raises as it would.
function Guard.Run(where, fn, ...)
  if Guard.strict then
    return true, fn(...)
  end
  local outer = currentWhere
  currentWhere = tostring(where)
  if xpcallPassesArgs then
    return finish(outer, xpcall(fn, onError, ...))
  end
  packedFn, packedArgs, packedCount = fn, { ... }, select("#", ...)
  return finish(outer, xpcall(unpacked, onError))
end

return Guard
