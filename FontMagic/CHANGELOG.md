# Changelog

## 4.1.4 — Restricted combat-font values

- Fixed repeated secret-value comparison errors while checking live combat-text fonts.
- Skip restricted or forbidden objects and unreadable font paths, sizes, flags and spacing before inspecting them or attempting a write.
- Keep original font snapshots for Reset, and resume normal font checks when the client makes an object readable again. A hidden tuple no longer causes repeated font repairs.
- Keep diagnostic output from inspecting restricted font values or frame references.
- Retain all bundled fonts, saved choices, custom-font paths and existing interface versions. FontMagicCustomFonts must remain unchanged.

## 4.1.2 — Forever compatibility

- Added Forever 1.60.1 (`16001`) to the shared manifest, preserving all previous interface values.
- Completed the client-version audit and added the missing Wrath Classic 3.4.5 (`30405`) interface entry. No additional runtime changes.
- Skip secret combat values in debug message parsing and displayed-text scans on Forever and modern Retail. Font styling remains independent of message content.
- Reviewed against Blizzard UI source for Forever 1.60.1 build 69913; local regression checks passed. In-game validation is still required.

## 3.3.6

### Combat-font interoperability

- Gave FontMagic the final login-time combat-font write when ElvUI or SUI is
  enabled by loading those optional controllers first and applying the saved
  FontMagic face afterward.
- Hooked ElvUI's actual `UpdateBlizzardSpecialFonts` combat writer rather than
  only its unrelated general Blizzard-font method; retained the older method
  hook for compatibility with previous ElvUI branches.
- Reconciled controller writes synchronously inside their post-hooks so
  `DAMAGE_TEXT_FONT` is correct during the brief login window in which WoW
  caches the outgoing world-text face.
- Added an end-of-event guard for other addons that write the combat global
  from `ADDON_LOADED`, `PLAYER_LOGIN`, or `PLAYER_ENTERING_WORLD`, plus the
  existing throttled live-object monitor for later runtime drift.
- Preserved the latest external global and FontObject tuples as FontMagic's
  release baseline, so FontMagic wins while active but Reset returns control to
  the other addon's current preference instead of destroying it.

## 3.3.5

### Anniversary incoming combat text

- Restored the original addon's verified zero-letter-spacing correction for
  incoming damage, healing, aura, buff, and other player combat messages on
  WoW 2.5.6.
- Restored the old working renderer tuple for self combat: a stable 25-point
  `CombatTextFont` source size with only FontMagic's configured outline token,
  rather than Anniversary's inherited `106.042...` size and
  `FILTER,FIXEDHEIGHT` flags.
- Limited the explicit zero-spacing correction to the selected font's shared
  `CombatTextFont` objects and live self-combat rows; unrelated fonts, shadows,
  localized text, and passive installations remain untouched.
- Captured each affected object's prior spacing immediately before the first
  FontMagic write and restore it exactly when the selected font is reset.
- Added a regression using the exact size and renderer flags captured from the
  Anniversary client, including drift detection and repair.

## 3.3.4

### Reset reliability

- Made font and outline resets durable saved-state operations: a transient live
  Blizzard FontString can no longer veto clearing the override, and the next
  character login completes any live-object restoration.
- Limited combat-font ownership to the face tuple FontMagic actually changes.
  Reset no longer writes spacing or shadow properties owned by Blizzard or
  another addon.
- Retained transactional failure handling for owned persistent CVars, while
  recording the exact failed reset stage instead of collapsing every cause into
  a vague `full reset` label.
- Added regression coverage for persistent live-object rejection, non-owned
  font properties, and successful durable Reset Everything behavior.

## 3.3.3

### Tested workflow fixes

- Changed successful font-Apply feedback to state clearly that the selection is
  saved and the player must log out to the character screen and back in for it
  to reach every Blizzard font target.
- Corrected Reset Combat Options and Reset Everything so they reset only the
  settings FontMagic actually owns; an unrelated protected or read-only client
  CVar can no longer veto the whole reset.
- Added explicit ownership for the main combat-text size slider so it resets to
  the client default only after the user changes it through FontMagic.
- Kept Favorites rows to one line, removed redundant group suffixes, and
  restored Blizzard's recycled row wrapping state when the list closes.
- Added user-workflow regressions for relog guidance, Favorites row containment,
  owned-only reset behavior, and full reset rollback.

## 3.3.2

### Font ownership and recovery

- Reconciled Blizzard's preallocated, newly initialized, detached, and
  reattached combat-text rows without allowing dormant or optional rows to
  reject a valid saved selection.
- Made selected-face and outline transitions follow every object FontMagic
  actually owns, while keeping remembered client rejections monitor-stable.
- Verified exact face, size, and normalized flag restoration before releasing
  ownership, and retained retry state when a client silently ignored a reset.
- Restored the exact prior presence and value of each combat-font global,
  including clients on which the optional `COMBAT_TEXT_FONT` global is absent.

### Settings and UI correctness

- Captured incoming combat-text rows at first mutation and restored their exact
  identities without overwriting later changes from Blizzard or another addon.
- Added retryable atomic recovery for motion/CVar writes, master-hide rollback,
  and interrupted reset transactions across login.
- Kept Reset Everything's preview, header, and selector state synchronized when
  its combat-options half was rejected, including the deferred repaint path.
- Synchronized the saved font when Retail Settings opens FontMagic directly and
  kept a staged font selected when its Favorites star is removed.
- Re-probed custom-font availability when a late-loaded companion reports its
  path, allowing the saved selection to recover without another UI reload.

### Hardening and release quality

- Normalized invalid legacy outline values to a passive state instead of
  acquiring outline ownership from corrupt SavedVariables.
- Avoided installing combat-message hooks on a passive fresh installation and
  throttled repeated steady-state validation work.
- Added regressions for current Blizzard's 20-row combat-text pool, direct
  Settings entry, exact reset postconditions, Favorites selection state,
  late custom-font loading, and failed rollback recovery.
- Expanded the bundled-font rights notice to record restrictive embedded terms
  found during the release audit.

## 3.3.1

### Font application

- Fixed valid font selections being reported as rejected after Blizzard's
  combat-text addon preallocated inactive FontStrings without an assigned face.
- Made a successfully probed selection durable even when an optional live font
  target is not ready; supported targets update immediately and the remaining
  client state is reconciled on addon load or the next login.
- Prevented permanent optional-target rejections from causing a continuous
  ownership-monitor retry loop while retaining explicit and login-time retries.
- Preserved known built-in and custom font selections during temporary probe or
  companion-addon unavailability so they recover automatically when available.

### Reliability and release quality

- Reasserted the saved master combat-text OFF state when Blizzard's incoming
  combat-text backend loads after FontMagic.
- Restricted recovered SavedVariable CVar writes to FontMagic's combat-text
  scope and covered current WorldText base and versioned names on Lua 5.1.
- Removed a redundant full font traversal from every already-correct combat
  message and added the real 20-row Blizzard pool lifecycle to regression tests.
- Added deterministic ZIP construction and actual-archive verification with
  normalized permissions, timestamps, paths, payload bytes, and metadata.

## 3.3.0

### Compatibility

- Added the current Retail/PTR, Classic, Anniversary, Era, and Titan interface
  IDs, including `120100`, `50504`, `20506`, `11509`, and `38002`.
- Replaced the removed Retail 12.1 `MouseIsOver` dependency with a method-first
  compatibility check and a legacy fallback.
- Added adapters for modern and legacy addon loading, Settings registration,
  combat-text type tables, CVars, callable-table LibStub, and Lua 5.1 atan2.

### Dropdowns

- Fixed the opening mouse press being mistaken for an outside click.
- Fixed font-row clicks being closed before their `OnClick` callback.
- Matched the open list's visible width and horizontal alignment to its closed
  selector while preserving long-label and favorite-star containment.
- Hardened recycled Blizzard dropdown row cleanup and owner tracking.

### Reliability and interoperability

- Split database, compatibility, font catalog, and combat-font ownership into
  load-ordered Core modules.
- Made fresh installations passive: no unsolicited combat-text, spacing,
  outline, motion, or number-format changes.
- Added exact per-object and per-global font ownership with verified SetFont
  results, client-compatible flag fallback, and retryable release.
- Made outline-only mode face-neutral and kept successful client fallbacks
  stable under the ownership monitor.
- Restricted persistent setting ownership to readable CVars and made grouped
  changes/reset actions transactional.
- Added exact master-toggle snapshots, incoming-row restoration, rollback
  purpose tracking, and corrupt snapshot recovery.
- Coalesced startup repair work, filtered addon events, reused monitors, pooled
  expanded-panel controls, and debounced visible CVar refreshes.
- Restored detached combat-text frames from the ownership registry when the
  above-nameplates option is disabled.
- Normalized corrupt SavedVariables and migrated legacy font/favorite keys.

### Release engineering

- Added Lua 5.1/5.4 regression suites, three-client full-load simulations,
  architecture/local-limit guards, and a disk-backed package/font inventory
  audit.
- Added `.pkgmeta` exclusions for development and local build artifacts.
- Added README, changelog, and code/font-rights notices.

## 3.2.49

- Archived as the rollback baseline before the 3.3.0 compatibility and
  ownership refactor.
