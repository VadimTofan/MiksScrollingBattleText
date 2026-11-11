# Forever runtime sync

Updated: 2026-11-11

The user requested that Forever match this workspace after `/msbt lootprofile`
printed usage. Its profiler file, command handler and manifest entries were
missing. The complete runtime file set selected by the existing `.pkgmeta`
exclusions was synced, replacing earlier partial installs. All 102 runtime
files match by SHA-256, with no extra files in the destination addon folder.
Development files and Git metadata stay in this workspace.

Verification: all 70 installed Lua files compile as Lua 5.1. Five regression
scripts ran against the installed files: profiler, loot integration, profile
command integration, kill classification/deduplication, and kill presentation.
The workspace suite ran 139 tests: 138 passed, one release-archive check skipped.
No push or release was requested.

Next: run `/reload`, start `/msbt lootprofile`, loot for 10–20 seconds, run
`/msbt lootprofile stop`, and collect the five report lines.

## Duplicate killing-blow notifications

Updated: 2026-11-11

A melee kill with no damage report could emit both the normal PARTY_KILL alert
and the delayed killing-swing fallback. Both paths now share a notification
flag on the kill line. Whichever runs first sends the notification; the other
still completes its bookkeeping without displaying another alert. Distinct
kill lines retain independent notifications and the existing NPC/player routing.

The regression test failed first for duplicate notifications. It now covers
NPC and player victims, both timer orders, and a second distinct kill. The full
suite ran 139 tests: 138 passed and the release-archive check was skipped.

The Forever sync check found its reader still matched the version before
player/NPC classification, despite the earlier installation note below. That
file now matches the tested source, including classification and duplicate
prevention. The installed reader passed the same Lua regression test. No push
or release was requested.

Next: run `/reload` in Forever and kill an NPC with a melee finishing blow;
confirm only one notification appears. Live confirmation is still pending.

## Player and NPC killing blows

Updated: 2026-11-11

The approved routing change is implemented on `main` and installed in Forever.
Matched player kills use Player Killing Blows. NPC and unclassified kills share
NPC Killing Blows, including its message, font, color, sound and toggle. The
separate unclassified control and defaults are removed; profile transfer ignores
its obsolete setting. Existing player/NPC settings are retained. The delayed
melee killing-blow fallback follows the same routing. Unclassified PvP kills
also follow the NPC setting.

Victim classification uses public `UnitIsPlayer` and `UnitIsDead` observations
attached to damage reports or player swings. A kill must have one matching
victim in its frame and an observed death. Target epochs and nameplate
generations prevent a later target or recycled token from supplying that
death. Multiple victims, multiple same-frame kill lines, missing APIs, secret
flags, and unavailable death evidence remain unclassified. This is conservative
correlation: the formatted combat-log event still has no direct victim flag,
so not every PvP or NPC kill can be classified.

Verification: regression tests failed first for unknown kills using the generic
setting and separate generic defaults remaining. The full suite ran 139 tests: 138 passed
and the actual release-archive check was skipped. Tests cover target changes,
mixed victims, token reuse, restricted/missing/erroring predicates, delayed
melee alerts, shared NPC/unclassified settings and defaults on both client branches.
Whitespace checks passed. Five runtime files were installed in Forever; only
the killing-blow sections of its presentation file were patched, preserving
its earlier pet-icon difference. Live PvP/NPC testing is still required.

The loot diagnostic checkpoint remains separate and unchanged. Neither it nor
this killing-blow change has been pushed or included in a new release.

Reference: [Blizzard unit predicate declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).

Next: run `/reload` in Forever, enable Player Killing Blows and disable NPC
Killing Blows. Check that NPC and unknown kills stay hidden, then test PvP kills.
The five-line loot timing report is also still pending.

## Loot stutter investigation

Updated: 2026-11-11

Users report stutter when repeatedly clicking corpses with loot, but not empty
corpses. The cause is not confirmed. MSBT has no direct loot-window or mouse
handler. Item notifications do item-info and inventory-count lookups even when
their alert is disabled; counts also run for templates without `%t`. Those
paths remain unchanged so timing can identify the actual cost before a fix.

The approved temporary diagnostic is implemented on `main` and installed in
Forever. After `/reload`, `/msbt lootprofile` starts a capture; spam-loot for
10–20 seconds, then `/msbt lootprofile stop` prints five report lines. Capture
also stops automatically after 30 seconds or 2,000 self-loot parser events.

The header identifies the addon/client build and loot event count. Four rows
report call count, total, average, maximum milliseconds, and errors:
`handler` (full loot callback), `metadata` (item/currency lookup), `count`
(inventory total), and `display` (synchronous notification setup, including
sound). Handler time includes its child phases; do not add the totals together.
The timings exclude chat parsing, later animation frames, GPU work, and other
addons' loot-window or target-change handlers.

Capture is off by default and makes no profiling-clock reads while inactive.
It uses `GetTimePreciseSec`, or `debugprofilestop` without resetting the shared
timer. It does not enable global CPU profiling, change notification decisions,
or retain item data/history in SavedVariables. Captures keep fixed aggregates;
stale timers cannot stop a later capture. Callback results, nil returns, and
errors are preserved.

Verification: new tests failed first for missing capture, command routing,
and manifest integration. The full suite ran 137 tests: 136 passed and the
actual release-archive check was skipped. Whitespace checks passed. The three
installed Lua changes match the tested source; both Forever manifest edits
only add the profiler before LootNotifications and retain version 12.048.
This diagnostic has not been pushed or released, and no live timing capture
has been collected yet.

Next: reproduce the stutter with capture enabled and paste the five report
lines. Use the maximum phase times to select the next investigation.

## Release v12.049

Updated: 2026-11-11

Release commit `3fd11c4` and tag `v12.049` were pushed to origin from `main`.
GitHub validation and the CurseForge release workflow succeeded. The archive
gate passed before upload; CurseForge accepted file ID `9556335`. Public
availability or moderation status has not been independently checked.

Both runtime manifests report 12.049. The changelog covers name/ID aura
rules, native protected-name visibility, the sound limitation, larger font
sizes, and the pet melee icon change since v12.048.

The full suite ran 134 tests: 133 passed, with the actual-archive check skipped
until packaging. The exact workflow ZIP then passed all six archive tests;
all 69 packaged Lua files parsed as Lua 5.1. Both manifest versions and the
native aura runtime match the released source. The ZIP contains 101 files and
is 624,210 bytes. Tests, diagnostics, and development files are excluded;
runtime dependencies, media, localizations, and notices remain included.
Whitespace checks passed and task logs are clean.

Artifact: `D:/Codex-Temp/msbt-v12.049-release/MikScrollingBattleText-v12.049.zip`.

Workflow: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43011216698

Forever has the five native aura changes from before release preparation,
with its earlier pet-icon and font-size differences preserved. It has not been
replaced with the complete v12.049 archive.

Next: check CurseForge public availability and test the native aura filter in
combat after `/reload` in Forever.

## Aura exclusions by name or ID

Updated: 2026-11-11

Native secret-name filtering is now implemented on `main`. Excluded name
rules use `C_Intl.CompareStrings`, conditional string helpers, normalization,
and native boolean selection to produce an opaque visibility boolean. The
animation renderer uses it to select alpha for both text and icon, including
fades. Lua never branches on the match result or extracts the secret name.
Completed animations release their visibility reference. Missing helpers,
invalid native returns, and selector errors preserve visible notifications.

Secret aura notifications checked against active name exclusions are muted:
sound playback cannot be selected with the secret match result. This also
mutes unrelated secret aura sounds checked by the filter. Numeric exclusions
still require a readable ID; secret names cannot establish a specific rank.
Invisible events still occupy an animation slot until they expire.

Verification: regression tests failed before implementation for native
matching and animation visibility. The full suite ran 134 tests: 133 passed,
with the release archive check skipped. Whitespace checks passed. All five
installed runtime files parse as Lua 5.1; three aura tests also passed against
the installed implementations. Actual combat behavior remains unverified.

The five runtime changes were synced to Forever. Its presentation and display
service files had pre-existing pet-icon and font-size differences, so only
the aura sections were patched there. The other three files match the source
byte-for-byte. A separate installed display test still rejects font sizes
above 38; the same failure was reproduced without the aura changes.

References: [native selector investigation](https://github.com/Questie/Questie/blob/master/docs/forever-object-tooltip-api-audit.md#native-string-based-selection-promising-primitives-unverified-composition),
[secret-capable alpha API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua).

Next: run `/reload` in Forever, exclude an aura by its exact displayed name,
and check that it stays hidden in combat while an unrelated aura stays visible.

## Name and ID rule storage

Adding an aura by name now creates an all-ranks rule. Adding a numeric ID
creates an exact-ID rule. Existing saved rules remain exact-ID rules because
their original input is unknown. Name rows display "all ranks"; ID rows keep
their number. Both rule types retain checkbox states and custom styles through
profile export and import.

Follow-up: name entry no longer requires a successful spell API lookup. If
lookup returns no result, the trimmed name is saved directly for exact display
name matching. This permits unlearned or otherwise unresolved aura names;
users must check their spelling. Numeric IDs still require a valid lookup,
and empty or control-character input is rejected. Regression tests reproduced
the rejection in both resolution and the real options panel before the fix.
The full suite still passes (132 passed, one archive check skipped), and both
follow-up runtime files were synced to Forever with SHA-256 verification.

Either matching exclusion hides the notification. When both matching rules
are enabled, the exact-ID style takes priority. Name-only combat-text notices
can match name rules, but cannot establish an exact rank for ID rules. Hidden
names now use native rendering selection when its helpers are available.

Regression tests failed before implementation for name resolution, the options
row, and profile transfer. The full suite ran 133 tests: 132 passed and the
release archive check was skipped. Whitespace checks passed.

The four changed runtime files were synced to Forever and verified by SHA-256.
In-game behavior has not yet been checked.

## Font size range

Updated: 2026-11-11

Normal and critical font sliders now support sizes 4–100 with one-point steps.
The shared editor applies this range to Master Fonts, scroll areas, and event
overrides. The public display helper accepts the same range. Existing font
inheritance and out-of-range fallback behavior are preserved.

The popup and display regression tests failed before implementation and passed
afterward. The full suite ran 132 tests: 131 passed and the release archive
check was skipped. Whitespace checks passed. The two changed runtime files
were synced to Forever and verified by SHA-256.

Next: run `/reload` in Forever and check larger normal and critical sizes in
Master Fonts. This change has not been included in a new release.

## Previous release: v12.048

The merge combines conservative direct spell matching, the shaman Windfury
icon fallback, and Windfury stacking with main's Sounds settings and late-hit
handling after target loss. Windfury stacking uses a one-second window;
restricted amounts share a line without being added in Lua. Critical and
normal hits remain separate.

Low-health and low-mana sounds each use the requested 10-second cooldown.
The separate sound toggles and immediate text alerts from main are retained.

Verification: the merged suite ran 132 tests: 131 passed and the release
archive check was skipped because no archive was supplied. Lua 5.1 checks
used the existing Lupa runner. Conflict markers and whitespace were checked.

Release commit `9b61910` and tag `v12.048` were pushed to origin. Both Validate
runs and the CurseForge release workflow completed successfully. The workflow
verified the archive before upload; CurseForge accepted file ID `9550672`.
Public availability or moderation status was not independently checked.

The exact workflow ZIP was downloaded to
`D:/Codex-Temp/msbt-v12.048-release/MikScrollingBattleText-v12.048.zip`.
Its six archive tests passed, all 69 packaged Lua files parsed as Lua 5.1,
and both client manifests report 12.048. The ZIP contains 101 files and is
622,870 bytes. Runtime dependencies, media, and licenses are retained;
tests, diagnostics, and development files are excluded.

Workflow: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42930592192

The Forever installation still has the feature branch version from before
the merge. Next: install v12.048 in Forever and check Windfury bursts and
killing blows in game.

## Pet swing icon: PR #33

Merged Gamooly's pet icon change with the existing unknown-proc handling.
When GetPetIcon supplies a readable icon, pet melee damage and misses use it.
The user accepted the assumption that the API supplies a usable pet icon;
the previously identified downstream no-icon fallback remains unchanged.

PR #33 was approved with the user's thank-you message and merged remotely as
`5cfb8e1`. GitHub validation passed. The merge was pulled into local main while
preserving the separate, unpushed font-size commit. Both the integration and
combined local suites ran 133 tests: 132 passed and the release archive check
was skipped. Whitespace checks passed.

Next: sync the pet icon change to Forever before checking pet hits and misses
in game.
