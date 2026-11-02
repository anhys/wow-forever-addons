-- Strips player and character identity before anything is stored. Pure Lua, no WoW API.
--
-- The collector records what the client shows the player: loot, vendor stock, quest
-- rewards, gathering, disenchant results. None of that needs the player's name, their
-- realm, their guild or anyone else's name, so those are removed at capture time and
-- the sanitiser is the only path into saved variables.
--
-- One realm fact is let through: the client's numeric realm id, under the key realm, as a
-- positive whole number and nothing else. It is what tells a discovery made on one realm from
-- one made on another the player also plays on. The number identifies nothing on its own; the
-- realm's name would, and a name under that key (or anything else that is not such a number)
-- is dropped like every other forbidden value.
local _, ItemTree = ...

local Privacy = {}
ItemTree.Privacy = Privacy

-- Keys that are never stored, whatever value they carry.
local FORBIDDEN_KEYS = {
  player = true,
  playerName = true,
  character = true,
  characterName = true,
  realmName = true,
  server = true,
  guild = true,
  guildName = true,
  account = true,
  battleTag = true,
  guid = true,
  playerGuid = true,
  unitGuid = true,
  owner = true,
  looter = true,
  sender = true,
  target = true,
  email = true,
}

-- Player GUIDs identify an account's characters; creature and object GUIDs identify
-- game entities and are useful (NPC id, object id). Only the entity type and id are kept.
local KEEP_GUID_TYPES = { Creature = true, GameObject = true, Vehicle = true, Pet = true, Item = true }

-- "Creature-0-1234-1-5-12345-000ABCDEF" -> "Creature", 12345
function Privacy.ParseGuid(guid)
  if type(guid) ~= "string" then
    return nil
  end
  local kind, rest = guid:match("^(%a+)%-(.+)$")
  if not kind then
    return nil
  end
  if kind == "Player" then
    return "Player", nil
  end
  if not KEEP_GUID_TYPES[kind] then
    return kind, nil
  end
  -- Creature-[unknown]-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
  local fields = {}
  for field in rest:gmatch("[^%-]+") do
    fields[#fields + 1] = field
  end
  if kind == "Item" then
    return "Item", tonumber(fields[3])
  end
  return kind, tonumber(fields[5])
end

-- Returns an entity reference safe to store, or nil for players and unknown kinds.
function Privacy.SanitiseGuid(guid)
  local kind, id = Privacy.ParseGuid(guid)
  if not kind or kind == "Player" or not id then
    return nil
  end
  return { kind = kind, id = id }
end

-- The one shape the realm key may hold: a positive whole number. Pure.
function Privacy.IsRealmId(value)
  return type(value) == "number" and value > 0 and value == math.floor(value) and value < math.huge
end

local function looksLikeName(value)
  -- "Name-Realm" or "Name" that is not a number and has no spaces beyond a realm hyphen.
  return type(value) == "string" and value:match("^%a[%a']+%-?[%a' ]*$") ~= nil and not value:match("^%d+$")
end

-- Removes forbidden keys, player GUIDs, and free text that looks like "Name-Realm".
-- Works on nested tables. Returns a new table; the input is never mutated.
function Privacy.Sanitise(record, depth)
  depth = depth or 0
  if type(record) ~= "table" then
    return record
  end
  if depth > 8 then
    return nil
  end
  local out = {}
  for key, value in pairs(record) do
    local drop = FORBIDDEN_KEYS[key]
      or (key == "realm" and not Privacy.IsRealmId(value))
      or (type(value) == "string" and value:match("^Player%-") ~= nil)
      or (key == "name" and record.kind == "player" and looksLikeName(value))
    if not drop then
      if type(value) == "table" then
        out[key] = Privacy.Sanitise(value, depth + 1)
      elseif type(value) == "string" and value:match("^%a+%-%d+%-") then
        local ref = Privacy.SanitiseGuid(value)
        if ref then
          out[key] = ref
        end
      else
        out[key] = value
      end
    end
  end
  return out
end

-- Brief OPT4: whether a string looks like "Thrall-Frostmourne", a character name with a realm. Defence
-- in depth for Core/Collector.lua and Core/Share.lua, which each had a copy: the sanitiser has
-- already dropped the keys and GUIDs that normally carry identity. Pure.
function Privacy.LooksLikeCharacter(value)
  return type(value) == "string" and value:match("^%u%l+%-%u%l+$") ~= nil
end

-- Scans any stored blob for text that still looks like a character name with realm,
-- e.g. "Thrall-Frostmourne". Used by tests and the debug command.
function Privacy.FindNameLikeStrings(record, found, depth)
  found = found or {}
  depth = depth or 0
  if type(record) ~= "table" or depth > 8 then
    return found
  end
  for _, value in pairs(record) do
    if type(value) == "table" then
      Privacy.FindNameLikeStrings(value, found, depth + 1)
    elseif type(value) == "string" and value:match("^%u%l+%-%u%l+$") then
      found[#found + 1] = value
    end
  end
  return found
end

return Privacy
