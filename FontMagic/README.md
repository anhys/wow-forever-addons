# FontMagic

FontMagic is a cross-client World of Warcraft addon for choosing, previewing,
and applying floating-combat-text fonts. It includes 120 built-in font files,
favorites, an optional custom-font companion, live preview, combat-text size
and visibility controls, motion settings where the client exposes them, and
lossless reset controls.

## Supported clients

The runtime compatibility layer and TOC cover current Retail/Midnight and PTR,
modern Classic, Anniversary, Classic Era, Titan, and Forever clients. Unsupported APIs
are detected at runtime; FontMagic does not write a setting that the client
cannot read back and restore safely.

The manifest includes these client interface versions:

- Retail/PTR: `120100`, `120105`
- Modern Classic: `50504`
- Anniversary: `20506`
- Classic Era: `11509`
- Titan: `38002`
- Wrath Classic: `30405`
- Cataclysm Classic: `40402`
- Forever: `16001`

Forever support targets its current beta API. Future beta builds may require
updates. Use the AddOns folder belonging to the client you actually launch.

Historical interface IDs remain in the TOC so one package can continue to load
on older supported installations.

## Installation

1. Copy the `FontMagic` folder into the relevant
   `World of Warcraft/<game version>/Interface/AddOns/` directory.
2. Restart WoW or type `/reload` after replacing addon files.
3. Open FontMagic with `/fontmagic`, `/float`, `/floating`, `/floatingtext`,
   `/fct`, or the minimap button.

## Custom fonts

Install `FontMagicCustomFonts` beside FontMagic, then place up to 20 files in
its `Custom` directory using the companion's expected names (`1.ttf` through
`20.ttf`). Keep your existing companion and personal font files unchanged when
updating FontMagic. If the companion is listed as outdated, enable **Load out of
date AddOns** rather than replacing its files.

## Behavior and safety

- A fresh installation is passive until the user chooses an override.
- Restricted combat-text objects are left untouched while their values are
  hidden. FontMagic resumes its normal checks when they become readable; a
  pending Reset retains the original font snapshot for a later retry or login.
- A font that passes FontMagic's load probe is saved when **Apply** is clicked.
  If a live client font object is not ready yet, the saved face is completed on
  the next relevant addon load or login instead of discarding the selection.
- FontMagic changes each managed object's font face tuple and restores that
  tuple on reset. While a selected face is active, Blizzard's self-combat font
  uses the original addon's stable size/renderer contract and zero letter
  spacing; the exact prior tuple and spacing are restored on reset. It never
  changes shadows or unrelated font spacing.
- Outline-only use preserves every object's existing font face and does not
  take ownership of Blizzard's global font paths.
- CVar changes are restricted to readable CVars, checked for failure, and
  rolled back when a multi-setting action cannot complete.
- Corrupt or obsolete SavedVariables are normalized during load.
- Known font choices survive temporary custom-companion or font-probe
  unavailability and recover when the face becomes available again.
- When ElvUI or SUI is enabled, FontMagic loads after their font controller and
  reasserts its selected combat face inside their actual font-update callbacks.
  Other login-time global writers are caught by the end-of-event guard. Reset
  restores the latest external face FontMagic observed, so interoperability
  does not erase the other addon's saved preference.
- Dropdown behavior uses both modern `Region:IsMouseOver()` and the legacy
  `MouseIsOver` fallback.

Some outgoing world-space number styling is controlled by the WoW client and
may ignore addon-selected outlines. FontMagic labels those controls as
best-effort rather than claiming support the client does not provide.

## Reset choices

- **Font only** durably clears the selected FontMagic face while retaining
  combat options such as an independently selected outline. If a transient
  live FontString cannot refresh immediately, the next character login
  completes the restoration from Blizzard defaults.
- **Combat options only** restores client defaults while retaining the selected
  face.
- **Everything** performs both operations as one guarded action and reports a
  rejected client write instead of silently claiming success.

## Diagnostics

`/fontmagic debug on`, `/fontmagic debug off`, `/fontmagic debug toggle`, and
`/fontmagic debug dump` provide opt-in combat-text diagnostics. Debug mode logs
state; it does not rewrite localized displayed numbers.

See [CHANGELOG.md](CHANGELOG.md) for release details and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before redistributing the
bundled fonts.
