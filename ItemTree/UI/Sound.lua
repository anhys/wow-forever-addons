-- Interface sounds: a small fixed vocabulary of named cues, played on the SFX channel.
--
-- The rule this file exists to enforce is that no other file ever names a sound id. A call site
-- says what just happened ("tab", "open", "checkOn") and this decides what the client plays, so
-- the whole addon can be retuned, or silenced, in one table.
--
-- WHICH KIT FOR WHICH CUE. Every one is copied from what the client itself plays, read off the
-- `forever` branch of github.com/Gethe/wow-ui-source (the Forever client runs the retail shaped
-- Mainline files with a thin Camelot layer over them). The file and line each choice came from:
--
--   cue        SOUNDKIT name                      id   copied from
--   click      IG_MAINMENU_OPTION_CHECKBOX_ON     856  Blizzard_Settings_Shared/
--                                                      Blizzard_CategoryList.lua:197, the sound a
--                                                      pick in the settings category list makes
--   checkOn    IG_MAINMENU_OPTION_CHECKBOX_ON     856  Blizzard_Settings_Shared/
--   checkOff   IG_MAINMENU_OPTION_CHECKBOX_OFF    857  Blizzard_SettingControls.lua:636 to 638,
--                                                      SettingsCheckboxControlMixin:SetValue
--   tab        IG_CHARACTER_INFO_TAB              841  Blizzard_Settings_Shared/
--                                                      Blizzard_SettingsPanel.lua:114,
--                                                      SettingsPanelMixin:OnTabSelected, and
--                                                      Blizzard_UIPanels_Game/Camelot/
--                                                      CharacterFrame.lua:17
--   open       IG_CHARACTER_INFO_OPEN             839  Blizzard_UIPanels_Game/Camelot/
--   close      IG_CHARACTER_INFO_CLOSE            840  CharacterFrame.lua:724 and :769,
--                                                      CharacterFrameMixin OnShow and OnHide.
--                                                      The same pair is what a side pane opening
--                                                      and closing plays, at CharacterFrame.lua:298
--   menuOpen   IG_MAINMENU_OPTION_CHECKBOX_ON     856  Blizzard_Menu/DropdownButton.lua:315 and
--   menuClose  IG_MAINMENU_OPTION_CHECKBOX_OFF    857  :321, through MenuVariants.lua:64 and :68
--
-- The numbers are Blizzard_SharedXML/Mainline/SoundKitConstants.lua lines 36 to 49 on the same
-- branch. They are a fallback and nothing else: the kit is looked up by name in the live SOUNDKIT
-- table at play time, so a client that has renumbered one still plays the right sound.
--
-- NO DOUBLE SOUNDS. Several client templates play a sound of their own and the controls built
-- from them are left alone. On the `forever` branch, UIPanelCloseButton
-- (SharedUIPanelTemplates.xml:148, through UIPanelCloseButton_OnClick at
-- SharedUIPanelTemplates.lua:150), UIPanelButtonTemplate (SharedUIPanelTemplates.xml:315) and
-- PanelTabButtonTemplate (SharedUIPanelTemplates.xml:932, which PanelTopTabButtonTemplate
-- inherits) carry no OnClick sound at all, so the window's close button, its panel buttons and
-- its tabs are ours to voice. The client's own Settings controls are the other way round: every
-- tick box, dropdown and slider in the settings page plays its own sound already, so UI/Options.lua
-- adds none.
--
-- Sound.Enabled, Sound.KitFor, Sound.Throttled and Sound.Allow are pure and run under busted.
-- Sound.Play is below the divider because it is the one thing here that touches the client.
local _, ItemTree = ...

ItemTree.UI = ItemTree.UI or {}

local Sound = {}
ItemTree.UI.Sound = Sound

-- The whole vocabulary. A call site names one of these and nothing else; adding a ninth is a
-- decision about the addon's sound, not about a pane.
Sound.CUES = {
  -- A small press: a row pick, a dropdown choice, a button that does one thing.
  click = { kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
  -- A tick box or a toggle, which the client voices differently on and off.
  checkOn = { kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
  checkOff = { kit = "IG_MAINMENU_OPTION_CHECKBOX_OFF", id = 857 },
  -- A top tab or a view tab.
  tab = { kit = "IG_CHARACTER_INFO_TAB", id = 841 },
  -- The window, the settings page, a side panel or a popup.
  open = { kit = "IG_CHARACTER_INFO_OPEN", id = 839 },
  close = { kit = "IG_CHARACTER_INFO_CLOSE", id = 840 },
  -- A menu of our own being raised and dropped, which the client does distinguish from a click.
  menuOpen = { kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
  menuClose = { kit = "IG_MAINMENU_OPTION_CHECKBOX_OFF", id = 857 },
}

-- The cue names, in the order this file writes them down, so a spec can walk the whole
-- vocabulary rather than listing it again.
Sound.CUE_NAMES = { "click", "checkOn", "checkOff", "tab", "open", "close", "menuOpen", "menuClose" }

-- The channel every cue is played on, so the player's own Sound Effects slider and the game's
-- mute still govern all of it. Never Master, never Dialog.
Sound.CHANNEL = "SFX"

-- How close together the same cue may be played, in seconds. A refresh that repaints twenty rows
-- must not machine gun, and two call sites that both fire on one click (the window closing while
-- the Recently viewed overlay is still up, say) must be heard once. Blizzard's own controls sit
-- at about a tenth of a second apart before they read as a rattle.
Sound.THROTTLE = 0.1

-- When each cue was last played, keyed by cue name. Public so a spec can look at it.
Sound.last = {}

-- The setting. Governs ItemTree's own cues and nothing else: the game's Sound Effects slider and
-- its mute still apply, because every cue goes out on Sound.CHANNEL. A settings table that has
-- not been written yet reads as on, which is the default in Core/Init.lua.
function Sound.Enabled()
  local settings = ItemTree.db and ItemTree.db.settings
  local value = settings and settings.interfaceSounds
  if value == nil then
    value = true
  end
  return value and true or false
end

-- The SOUNDKIT name and the numeric fallback for a cue, or nil for a cue this file has never
-- heard of. Pure: it reads the table above and nothing else.
function Sound.KitFor(cue)
  local entry = Sound.CUES[cue]
  if type(entry) ~= "table" then
    return nil
  end
  return entry.kit, entry.id
end

-- Whether a cue last played at `last` is still inside the throttle window at `now`. Pure, and
-- both times are handed in, so the specs drive it with a clock of their own.
--
-- A missing time on either side is not a reason to swallow a sound: a client with no clock plays
-- every cue, which is what it did before there was a throttle at all. A clock that has gone
-- backwards (a /reload puts GetTime back to a small number) reads as a long time ago.
function Sound.Throttled(last, now, window)
  local before, after = tonumber(last), tonumber(now)
  if not (before and after) then
    return false
  end
  local gap = tonumber(window) or Sound.THROTTLE
  if after < before then
    return false
  end
  return (after - before) < gap
end

-- The throttle with the record keeping: answers whether this cue may play now, and remembers the
-- time when it may. Handing in no time at all leaves the record untouched and always answers yes,
-- which is the no clock case above.
function Sound.Allow(cue, now)
  local at = tonumber(now)
  if not at then
    return true
  end
  if Sound.Throttled(Sound.last[cue], at, Sound.THROTTLE) then
    return false
  end
  Sound.last[cue] = at
  return true
end

-- Forgets every cue's last time. The specs use it between clicks; nothing in the addon does.
function Sound.ResetThrottle()
  Sound.last = {}
  return true
end

--------------------------------------------------------------------------------
-- Client side. Guarded: this file loads with no WoW API present.
--------------------------------------------------------------------------------

-- The client's frame clock, or nil where there is none. nil turns the throttle off rather than
-- guessing at a time, which is what keeps this file honest under busted.
function Sound.Now()
  local clock = rawget(_G, "GetTime")
  if type(clock) ~= "function" then
    return nil
  end
  local ok, value = pcall(clock)
  if ok and type(value) == "number" then
    return value
  end
  return nil
end

-- The numeric kit this client plays for a cue. SOUNDKIT is asked by name first, so the id
-- follows the client rather than the comment table above; the written down number is what a
-- client with no SOUNDKIT entry for the name falls back to.
local function kitId(entry)
  local kits = rawget(_G, "SOUNDKIT")
  if type(kits) == "table" then
    local named = tonumber(kits[entry.kit])
    if named then
      return named
    end
  end
  return tonumber(entry.id)
end

-- Plays one cue. The only thing call sites use.
--
-- Answers true when a sound went out, and false for every reason it did not: the setting is off,
-- the cue is not one of ours, the same cue played a moment ago, or there is no client. A cue this
-- file does not carry is a silent no op and never an error, so a call site can be written before
-- the cue it names exists.
--
-- now is for the specs. In the client it is left out and Sound.Now answers.
function Sound.Play(cue, now)
  local entry = Sound.CUES[cue]
  if type(entry) ~= "table" then
    return false
  end
  if not Sound.Enabled() then
    return false
  end
  if now == nil then
    now = Sound.Now()
  end
  if not Sound.Allow(cue, now) then
    return false
  end
  local play = rawget(_G, "PlaySound")
  if type(play) ~= "function" then
    return false
  end
  local id = kitId(entry)
  if not id then
    return false
  end
  return (pcall(play, id, Sound.CHANNEL))
end

-- Brief OPT4: how a pane plays a cue, the one copy of what eleven panes each carried (UI/BossLoot,
-- Chain, Discoveries, Frame, Guesses, History, InfoPanel, Map, Options, Sidebar and Tree). It asks
-- for ItemTree.UI.Sound when it plays rather than this file's own table, so a spec's fake of the
-- module, or no module at all, is what answers. True only when the cue played; never raises.
function Sound.PlayCue(cue)
  local current = ItemTree.UI and ItemTree.UI.Sound
  if not (current and type(current.Play) == "function") then
    return false
  end
  local ok, played = pcall(current.Play, cue)
  return ok and played == true
end

-- Nothing to do at load: the cues are played by the panes. Kept because every UI module has one.
function Sound.Init()
  return false
end

return Sound
