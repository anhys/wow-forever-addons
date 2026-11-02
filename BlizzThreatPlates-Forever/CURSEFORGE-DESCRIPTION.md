# BlizzThreatPlates-Forever

See who has aggro, how far ahead you are, and who each enemy is targeting. Customize your nameplates or use BTP's threat displays alongside your preferred nameplate addon.

Designed for **WoW Forever**. Open settings with **/btp** or the minimap button.

## Choose how to read threat

### Threat Percentages

Live Blizzard-supplied percentages let you watch several enemies at once, including enemies you are not targeting. Values can exceed 100%, so you can see the size of your lead. Large values use compact formatting such as **6.3K%**.

### Threat Differential + Snapshots

See how many threat points you are **ahead (+)** or **behind (-)** compared with the highest-threat group member or pet.

**Only your selected enemy updates live.** When you switch away, its last known value remains temporarily with a `*`, then blinks and fades. These off-target numbers are snapshots, not live updates. Select the enemy again to refresh its value.

### Mixed

Show the live threat-point difference on your selected target and live percentages on other enemies. If the target's difference is unavailable, Mixed falls back to percentage when available. No snapshots.

All three modes need comparison data from you and another player or pet. Blizzard's API restrictions can prevent values from appearing. Differential compares raw threat totals, not the melee/ranged threshold for pulling aggro.

Customize **Have Aggro**, **Warning**, and **Lost Aggro** text colors under **Colors & Threat > Threat Display**, with separate palettes for numbers and percentages, live previews, and per-color defaults. Health-bar and border colors remain independent.

## Choose your nameplate style

- **Blizzard Large** and **Blizzard Default** retain the familiar native appearance.
- **ATD Inspired** offers compact bars with the enemy name and health percentage inside, a white selected-target border and soft glow, player debuff icons, and a matching castbar with its timer inside.
- **Jundies Inspired** offers flat bars with Expressway Bold name and health text, independent size/text settings, and a matching castbar.
- **Liquid Threat Animation** adds optional Acrylic Pour colors to ATD Inspired and Jundies Inspired. Open its detail page from Style for a bar preview, Play Animation, Reset, Liquid Speed and three progression examples. The saved enable toggle starts off.
- **Combo Points** adds native animated combo points to your selected nameplate, with a current-style preview, above/below placement, per-style X/Y positions, cast-aware debuff spacing and optional red/orange liquid currents.
- Adjust nameplate size and enemy-name, health-percentage, and health-value text sizes where supported.
- Toggle Health Percentage and Health Value beside their sliders under Text Size. Blizzard styles mirror Blizzard's Nameplate Information settings; ATD has its own saved toggles and numeric health display.
- Check **Disable Mob Level** below the Style controls to hide the level bubble on Blizzard styles. It starts unchecked once for fresh installs and updates, then remembers later choices across reloads and future builds.
- Toggle enemy names and align names, health percentage and health value independently to the left, center or right, with a live preview. Each style remembers its own size, text and alignment settings.

ATD is included with BTP; it does not require Plater or import Plater profiles.

## Already using another nameplate addon?

Enable **Compatibility Mode** under **Advanced** to start with BTP's threat text only. Use **Optional Features** to add target-of-target, quest colors/icons, combo points, recoloring, brightness, aggro flashing or enemy debuffs. Your normal settings return when the mode is switched off. Full style, size and text replacement stay with your other addon. Anchor alignment can vary between nameplate addons.

## Customize your display

- **Modern options:** General, Colors & Threat, Nameplates, and Advanced organize the controls into focused pages with selected-style previews. General highlights the latest changes with a Liquid Threat sample and Try Me shortcut.
- **Size & Shape:** adjust nameplate size, independent width/height proportions, and supported text sizes, saved per style.
- **Castbars & Enemy Debuffs:** Blizzard styles expose native display settings; ATD has its own castbar and contextual PvE/PvP debuff controls.
- **Player Colors:** separate enemy PvP settings and experimental friendly-player colors for Open World, Battlegrounds, Dungeons, and Raids, with independent class-color choices and Default buttons.
- **Quest colors & icons:** keep quest objective icons while disabling quest recoloring, and customize the icon's size and placement in its preview window. Left-side CC makes room only when the quest icon overlaps its row; quest icons remain visible.
- **Threat Position & Size:** adjust font size and horizontal/vertical placement with a nameplate preview.
- **Target of Target:** show who each enemy is targeting, with optional last names, a friendly-nameplate toggle, and independent size and X/Y controls reflected in the preview.
- **Threat colors:** customize default aggro, warning, and lost-aggro colors, plus separate dungeon and raid palettes for tanks and DPS/healers.
- **Border Colors (Experimental):** independently choose Original, Custom Color, or threat-based borders for selected targets and non-target enemies. Supports Blizzard and ATD styles, with matching previews and Reset Both Borders. Both start on Original once when installing or updating; later choices remain saved. This feature still needs testing and feedback.
- **Non-target visibility:** optionally keep other enemies' nameplates bright.
- **Aggro warning:** optionally flash the border when losing secure aggro on an off-target enemy, including ATD bars.
- **Snapshots:** choose how long last-known differential values remain visible.
- **Role filter:** optionally show threat only when assigned Tank. This is off by default for new installs.
- **Welcome screen:** compare all three threat modes in the modern setup screen. Reopen with **/btpwelcome**.
- **Minimap button:** drag it to reposition it or hide it in settings.

Compatibility Mode leaves full nameplate styling to your other addon. Optional BTP features start off and can be enabled individually; turning the mode off restores your normal preferences.

## Getting started

1. Install and enable **BlizzThreatPlates-Forever**.
2. Open **/btp** and choose your display under **Colors & Threat**.
3. Choose a style under **Nameplates**, or enable Compatibility Mode under **Advanced** for another nameplate addon.
4. Fine-tune threat placement in **Colors & Threat > Threat Display** and target names in **Nameplates > Target of Target**.

Fresh installs use green **#19FF00** for Default Aggro. Keep SavedVariables when updating.

Version 1.1.0 includes a one-time sizing reset: adopt the style selected in Blizzard's options and set that native style to size 1, width 100%, and height 100%. A saved ATD appearance switches to that native style once; ATD can be selected again afterward. Later changes remain saved, and users who already received this reset in a recent test build are not reset again. Existing text/color preferences and other stored style dimensions are retained.

This update has many new features and needs testing. Please leave issues and feature requests in the CurseForge comments. Friendly-player colors apply only to nameplates the client allows the addon to edit.
