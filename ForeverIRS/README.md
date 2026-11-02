# Forever IRS — Ironforge Revenue Service

A character statistics ledger for WoW Forever. View your own gold statistics, inspect the counters the game exposes for a nearby player, and compare locally saved snapshots over time.

## Features

- Total gold acquired, historical peak gold, and your own current carried gold.
- Income sources, selected spending counters, auction activity, gameplay, and profession statistics.
- An **Activity** view with every profession, quests, kills, dungeons, disenchants and their materials, fishing, honorable kills, travel, and deaths.
- A factual **Recorded activity** summary with readable-counter counts; IRS does not grade characters or infer their play style.
- A movable ledger that fits the screen, with an optional panel beside the normal Inspect window.
- A searchable directory of all retained characters, sortable by peak gold, total acquired, level, name, last seen, or snapshot count.
- Up to 20 snapshots per character, with history and a manually copied text report.
- Standalone operation: no other addon, website, account, or companion program required.

## Install and use

Extract the release ZIP into your Forever client's `Interface/AddOns` directory. The result must be `Interface/AddOns/ForeverIRS/ForeverIRS.toc`, without another nested folder. Restart WoW after first installation and enable **Forever IRS** in the addon list. For an update to the same folder, `/reload` loads the new version; saved history is retained.

| Command | Action |
| --- | --- |
| `/irs` | Show the selected player, or yourself when no player is selected. |
| `/irs me` | Show your statistics and current carried gold. |
| `/irs target` | Request a nearby selected player's statistics. |
| `/irs history` or `/irs list` | Open the saved-character directory without requesting live data. |
| `/irs refresh` | Request a fresh observation for the current unit. |
| `/irs auto off` / `/irs auto on` | Disable/enable opening beside Inspect. On by default. |
| `/irs status` | Print addon/client versions, API availability, and request status. |
| `/irs verify` | Request a capture using the same checks as My character, Target and Refresh. Fetch failures appear in red. |
| `/irs scale 1.3` | Set the window scale (0.6 to 1.6; default 1.2). `/irs scale reset` restores the default; `/irs scale` shows the current value. |
| `/irs reset` | Reset the window position; retain saved history. |
| `/irs close` | Close the ledger. |

The window uses the game's own frame, like the Inspect window. Switch views with the tabs along the bottom: **Ledger** (financial figures), **Activity** (every gameplay and profession counter), **History** (saved captures) and **Characters** (the saved-character directory). Hover the activity summary to see the returned counters; hover any figure to see where it came from.

The normal Inspect window also has an **IRS** button. Drag the window by its title or header to move it; Escape closes it. **My character**, **Target** and **Refresh** are at the bottom left; **Open with Inspect** is in the header. If inspection is cooling down, a **Loading in…** countdown appears at the top and your requested inspection starts automatically when it ends; you do not need to press Refresh again. **Copy report** opens selectable text for manual copying; nothing is sent to chat. Changing the inspected character closes the previous report. Readable snapshots are saved automatically. **Save snapshot** does not turn an old capture into a new observation.

The addon checks every requested capture. For another player it waits for the inspection reply matching that character, then counts numeric counters that were safely read. The top section appears only as a **red error** when a request fails or no statistics can be read; a wallet value alone does not count. Otherwise the section and its space disappear, including for partial results and saved captures. Loading and cooldown progress stay in the small header status.

**Copy report** includes fetch details and, when an earlier capture exists for the same character, client build and self/inspection source, how many comparable numeric counters changed. Unchanged values do not prove freshness, and changed values do not prove accuracy. Missing counters and display-only text do not count as changed numeric values. Reports identify saved captures as **Saved snapshot · not checked again**; browsing them does not issue requests. Checking adds no background scanning or extra API probes.

## Saved-character directory

Click the **Characters** tab or use `/irs history`. Each row shows the character's latest saved capture. The default is highest peak gold first. Click a column heading to sort; click it again to reverse. Your chosen sort order is saved. Search matches literal text in a character's name, realm, guild, or class.

Click a row to open that character's saved ledger, then the **History** tab to view earlier captures. Browsing is local and preserves the original observation time. To refresh a saved character, target that same player nearby; IRS will not silently substitute your current target or your own character. Missing numeric values appear as `--` and sort last in either direction; an older known value is not substituted for a missing value in the latest capture.

## Understanding the numbers

**Accuracy disclaimer:** Figures may be inaccurate, incomplete, or out of date. Game counters, resets, and addon errors can affect the results. Use them as a reference, not proof of a player's wealth or misconduct.

**Data-source warning:** IRS reads the Blizzard statistics API directly; it does not read or depend on the in-game Statistics page. The automatic check confirms receipt and safe parsing of the requested capture, but cannot prove that Blizzard's counters are current, complete or correct. Fetch status describes data availability, not the accuracy of the game's counters. If IRS has not checked the statistic definitions for the capture's client build, a separate warning explains that counter coverage or meanings may have changed. An unchecked build alone does not mean the fetch failed.

**A difference does not necessarily indicate wrongdoing.**

The income breakdown shows four sources: gold looted, quest rewards, vendor sales, and auction earnings. It does not itemize gifts, transfers from alts or friends, or player trades (like normal item sales, selling ports or summons, etc.).

**Recorded gold acquired** displays Blizzard's separate **Total gold acquired** statistic. IRS does not calculate that headline by adding the four income rows. The breakdown cannot establish whether Blizzard included a particular gift, trade or mail payment in that separate total. These counters are not a complete record of gold received, and acquired gold is a gross figure, not profit or current wealth. Another player's current wallet is not exposed. Peak gold is a historical high, not their present balance.

**Peak minus acquired** is `max(0, peak gold − total acquired)`. Its blue bar compares recorded acquired gold with peak gold, capped at 100%; **100%+** means acquired exceeds peak. The bar and text use the same neutral styling at every percentage. No percentage is a pass or a failure. A zero peak has no meaningful percentage and is labelled accordingly. Gifts, transfers, direct player sales, missing data, and counter resets may explain a difference; IRS cannot determine where someone's gold came from.

- A grey `--` means no value was captured, never zero. Hover the figure to see why: **not reported** (WoW returned no value) or **unavailable** (no safely readable value was captured, or the statistic/API was not available). Copied reports spell out the reason.
- A reported numeric zero stays zero. Standard coin-icon amounts are converted to exact copper. Unknown localized formats remain display-only; the addon does not guess their value.
- Spending shows only the listed categories, not every expense. Income minus these counters is not a complete profit calculation.
- Profession ranks marked `*` are highest recorded ranks and may belong to a profession no longer learned. The ledger card shows the four highest positive ranks; **Activity** and the report include every queried profession, including zeros and missing values. Disenchants count destroyed items; disenchant materials count their outputs, not extra crafting actions.
- **First seen** means the first locally saved observation, not character creation. History increases compare neighboring observations only when client builds match and total acquired has not decreased.

## Recorded activity

The summary shows how many readable activity counters have values above zero. It reports returned counts without classifying a character as active, abnormal, suspicious, or legitimate. New characters, bank alts and specialists can have different records. Missing counters are not zero, and gold amounts never change the activity summary.

**A difference does not necessarily indicate wrongdoing** appears as a larger, separate line beside the income-source and transfer explanation on Ledger, Activity and History. The same context appears in tooltips and at the start of copied reports. Older snapshots retain their original values and timestamps; no history reset is needed.

## Privacy and storage

`ForeverIRSDB` is account-wide SavedVariables data, written by WoW on UI reload or logout. It contains preferences and character GUID, name, realm, class, level, guild, capture time, client build, and the available statistics. Your current wallet is stored only for self-captures. Each character retains their latest 20 snapshots; older captures are removed. Characters are no longer removed automatically when the directory exceeds 50 entries, so the file grows as you inspect more people. Characters already discarded by an older version cannot be recovered by this update. A failed request without a readable capture does not create a directory entry.

There is no telemetry, automatic upload, addon-message exchange, chat broadcast, or background player scanning. The addon does not read other addons' saved data or require another addon. SavedVariables and copied reports can contain player identities; they are not included in release archives. To erase local history, close WoW and remove `ForeverIRS.lua` and its `.bak` file from your account's SavedVariables folder. `/irs reset` only resets the window position.

## Requests and troubleshooting

Requests occur when you use the panel/commands or inspect with auto-open enabled. One request can be pending, with five seconds of local spacing and a 15-second response timeout. A click during the cooldown queues one inspection; the countdown updates and that request is sent once the cooldown ends. Closing IRS, switching to your character or the directory, or changing targets cancels the queued inspection. Combat and range are checked again before sending. The response timeout starts when the request is sent, and a failed or timed-out request is never retried automatically; the server can impose additional limits. Another addon or the achievement comparison window can take over the shared comparison request; IRS yields rather than clearing their request. It does not clear the native gear-inspection target. On Forever, IRS also keeps the built-in achievement comparison panel subscribed to inspection results only while that panel is visible. This prevents unrelated replies from reaching its hidden Summary page; normal visible comparisons retain their original event handler.

If a request times out, keep the player nearby, leave combat, and click Refresh. The check panel shows the outcome. IRS cannot recover information the game does not expose. To spot-check a counter without the Statistics page, capture yourself, perform one known action such as completing a quest, then refresh and compare that counter. A matching change checks that one observation, not every counter or another player's historical data. `/irs status` reports client and API information. When reporting a bug, include these versions, what you clicked, and any Lua error; remove player names from screenshots or reports if you do not want to share them.

## Compatibility

Version **0.5.5 Beta** targets **Forever 1.60.x**, Interface **16001**. All 36 statistic definitions were checked against client data **1.60.1.70291** on October 9, 2026: their IDs, labels, flags and criteria references are unchanged from the previously checked **1.60.1.70124**. Both builds are recognized, including when viewing saved captures. This checks the definitions, not whether live server values are current or accurate. Other WoW branches are not supported by this release. The interface is English; unknown localized numeric formats remain display-only. Later game patches may change statistic coverage or meaning and retain an unchecked-build warning until reviewed.

## License

MIT License; see `LICENSE`. An independent community addon, not endorsed by Blizzard or the U.S. Internal Revenue Service. The project icon is AI-assisted fantasy artwork included with this MIT-licensed project; in-game fonts and standard UI textures are supplied by the game and belong to their respective owners.

## Development

The test harness simulates WoW APIs; it cannot prove live server behavior. Run from the project root:

```sh
lua tests/test_irs.lua
lua tests/test_release.lua
lua tests/test_directory.lua
lua tests/test_activity.lua
lua tests/test_achievement_ui.lua
lua tests/test_target_buttons.lua
lua tests/test_verification.lua
lua tests/test_neutral_summary.lua
python3 tests/test_package.py
python3 scripts/package.py
```

`python3 scripts/make_portrait.py` rebuilds `Assets/Portrait.tga`, the crest fitted inside the window's round portrait, from `artwork/irs-crest.png`.

The package script uses an explicit file list, checks versions and load order, verifies ZIP contents, and writes a checksum. Research, tests, local records, screenshots, and machine-specific files are excluded. The optional source-only design preview uses synthetic data and is not an in-game screenshot.

Statistic definitions: [Wago Achievement data, build 1.60.1.70291](https://wago.tools/db2/Achievement/csv?build=1.60.1.70291). Reference source files retained for development are excluded from the release.
