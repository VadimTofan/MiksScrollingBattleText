# Outgoing self and pet healing

Updated: 2026-11-12

Matched player heals on self or pet now reach outgoing healing presentation
while retaining incoming display. The outgoing copy preserves amounts and
crits and treats the pet as recipient, rather than caster. Duplicate target
reports for a selected pet are ignored. Periodic heal confirmation identifies
the first HoT ticks without waiting for a rhythm to form.

Readable UNIT_SPELLCAST_SENT recipient data is paired to cast success by GUID
and spell, supporting self/pet bindings while another target remains selected.
Hidden or ambiguous recipient names are not inspected or guessed. Helpful
casts alone cannot confirm outgoing healing when combat-log confirmation is
available: an unused own heal line is required within the existing timing
window. Existing cast matching remains the fallback on clients without that
event. Passive or unidentifiable heals without a matched cast remain outside
this change.

Regressions failed first for missing outgoing heals, actual cast recipients,
and unconfirmed received healing. The full suite ran 144 tests: 143 passed,
with the release-archive check skipped. Installed Forever engine and complete
runtime regressions passed; all 102 runtime files match source by SHA-256.
The two runtime files were backed up under
D:/Codex-Temp/msbt-self-pet-heals-20261112 before installation.

API payload reference:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua

Saved locally; no push or release. Next: reload in game and test a self-heal,
a pet heal, and a HoT while an enemy is selected.

## Damage palette top spacing

Updated: 2026-11-12

The first damage-school row was anchored to the scroll content's bottom edge.
Increasing that content's height to fit the school list therefore moved the
first row down by the full list height, leaving a large empty area above it.
The first row now anchors to the content's top with 10 pixels of padding;
subsequent rows retain their existing spacing and scrolling.

The layout regression failed first, then passed with the fix. Six focused
popup, settings, menu and Lua 5.1 parse tests passed. The installed Forever
popup regression passed, and all 102 runtime files match source by SHA-256.
The fix is saved locally; no push or release was requested.

Next: run `/reload` in Forever and reopen General > Damage Colors to check the
first row starts near the top of the palette content.

## Baseline damage school colors

Updated: 2026-11-12

The user requested school coloring as baseline behavior rather than an
enable/disable option. Known damage schools now always use their configured
palette color. Legacy global and per-school disabled flags are ignored;
existing custom colors and profile-transfer compatibility are preserved.
Unknown or restricted schools keep the event color, and incoming damage and
heals retain their existing event styling.

The Damage Colors window is now a palette editor with labeled swatches only.
The global and per-school checkboxes and their obsolete localized strings
were removed. Tooltips now describe color customization in all eight locales.

Formatter, runtime and popup regressions failed first, then passed after the
change. The full suite ran 144 tests: 143 passed and the actual release-archive
check was skipped. The tests verify old disabled flags cannot suppress either
readable or hidden amount colors, and palette labels/swatches remain usable
without enable/disable controls.

Ten runtime files were backed up and synced to Forever. All 102 runtime files
match the source by SHA-256, and all 70 installed Lua files compile as Lua 5.1.
Installed main-runtime, formatter and popup scripts passed. Both school-color
checkpoints are local only; no push or release was requested.

Next: run `/reload` in Forever and verify school colors are present without
enabling an option. General > Damage Colors is only for changing the palette.

## Outgoing damage school colors

Updated: 2026-11-12

The approved change colors outgoing damage numbers by their readable school,
using the existing Damage Colors palette, global toggle and per-school
toggles. Spell names and hit counts retain the event color. Normal, critical,
periodic and pet damage use the same school path. Unknown or restricted
schools keep the event color; no school is guessed from a spell identity.

Presentation forwards the school through batching and formatting. Different
schools cannot share a damage batch. Hidden amounts remain separate native
display arguments; only their placeholders receive color codes, including
restricted Windfury groups. Incoming damage and healing retain their existing
event styling.

The full runtime regression failed first on missing outgoing school color.
After the fix, 18 focused tests passed. The full suite ran 144 tests: 143
passed and the actual release-archive check was skipped. Both Retail and
Forever fixtures cover school colors, names, criticals, DoTs, pets, disabled
settings, unknown/hidden schools, hidden amounts and separate school batches.

Four runtime files were backed up and synced to Forever. All 102 runtime files
match the source by SHA-256, and all 70 installed Lua files compile as Lua 5.1.
Installed main-runtime, combat-engine, 68-scenario periodic, Windfury stacking
and formatter scripts passed. The change is saved locally; no push or release
was requested.

The optional-toggle design above was superseded by the baseline follow-up.
Verify Frost and Shadow damage numbers in-game before release.

## Drain channel PR integration

Updated: 2026-11-12

At the user's request, ky0jr's PR #28 was merged as `ad8ccd7` and pulled into
main with `--ff-only` after fixing its overlap regressions. The contributor
received the agreed thank-you and explanation; no changes were requested
from them:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/28#issuecomment-6819278037

Periodic channels now participate in the shared periodic matcher used by the
reader and engine. Due DoTs retain rhythm and amount evidence rather than
being overridden by a flat channel fit. Matching heals favor drain channels,
while due Siphon Life ticks retain their identity unless learned channel
amounts fit clearly better. Confirmed, unambiguous channel amounts are retained
for later comparisons. Already-settled reports avoid a second line wait, so
rapid direct channels continue to work.

The original regression probes now retain Siphon Life's identity and next tick,
and display the actual 10-damage DoT report instead of a competing 99-damage
foreign hit. Regressions were observed failing before their fixes. The
17 focused tests passed. The full suite ran 144 tests: 143 passed and the actual
release-archive check was skipped. All 68 periodic pipeline scenarios passed.
The contributor's drain-channel cases and the added engine-only Siphon Life
case passed. Lua 5.1 parse checks and whitespace checks passed.

GitHub validation passed for the merge:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43189256037
The pulled workspace's drain-channel and 68-scenario periodic scripts passed.

Next: run `/reload` and check Drain Life and Drain Soul,
including overlap with Siphon Life and Corruption. In-game validation is
pending. No release was requested.

# Periodic damage merge and local healing follow-up

Updated: 2026-11-12

At the user's request, ameNiku's PR #29 was merged as `07e44e6` and pulled
into main with `--ff-only`. The conflict resolution preserves main's direct
attribution safeguards. GitHub validation passed:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43184533453
The requested thank-you and follow-up explanation were posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/29#issuecomment-6818842622

The local follow-up passes matching-heal evidence explicitly into periodic
candidate scoring, both when the reader fits a report and when the engine
chooses its spell. A draining tick no longer takes a simultaneous non-draining
DoT's identity when the other evidence ties. Without healing evidence, the
existing score is unchanged; read-only fits cannot inherit a previous heal.

Both regressions failed first: wrong displayed icon and ignored healing
evidence during fitting. After the fix, 16 focused tests passed. The full suite
ran 143 tests: 142 passed and the actual release-archive check was skipped.
All 60 periodic Lua scenarios passed, including the contributor's original 58.
Whitespace checks passed. The follow-up is saved locally only; no push or
release was requested for it.

Next: run `/reload` and check overlapping same-school DoTs with a matching
self-heal, along with Serpent Sting's delayed ticks. In-game validation is
pending.

## Periodic damage PR integration

Updated: 2026-11-12

At the user's request, ameNiku's PR #29 is integrated with current main.
The conflict resolution preserves direct-hit confidence, cast consumption,
and target restrictions alongside cross-frame periodic confirmations and
recovery from stale learned values. Duplicate target-history loops from the
automatic merge were removed.

The merged suite ran 143 tests: 142 passed and the actual release-archive
check was skipped. The contributor's 58 periodic scenarios pass. In-game
validation is pending.

Next: pull this merge into the addon workspace, add a failing regression for
same-school draining ticks, and restore healing-aware periodic scoring there.
The user requested this follow-up locally; no release was requested.

# Hunter shot descriptions merged

Updated: 2026-11-12

At the user's request, the adaptive melee-window checkpoint `9c677a1` was
pushed to main. Gamooly's hunter-shot description PR #32 was merged as
`3078189` and pulled with `--ff-only`. A familiar thank-you was posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/32#issuecomment-6809878211

The parser now recognizes Aimed Shot's ranged-damage wording and Multi-Shot's
missile wording as physical direct damage. It retains Hunter's Mark's
non-damaging classification and explicit damage schools. Multi-Shot hits on
other targets remain outside this change. Strict YAGNI review found all four
added parsing checks necessary: removing each breaks its regression test.

The merged main suite ran 142 tests: 141 passed and the actual release-archive
check was skipped. GitHub validation also passed:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43121478549
Installed hunter-description, adaptive melee-window and
miss-attribution regression scripts passed. All 102 runtime files match
Forever by SHA-256, with no destination extras. No release was requested;
public v12.050 predates these hunter-description and melee-window changes.

Next: run `/reload` in Forever and check Aimed Shot and Multi-Shot attribution
on the targeted enemy, plus slow-weapon behavior in solo and group combat.

## Adaptive melee swing window

Updated: 2026-11-12

At the user's request, Gamooly's PR #34 was merged as `f60031f` and pulled
into main with `--ff-only`. The requested thank-you and refinement comment:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/34#issuecomment-6809621903
GitHub validation passed for the merge. The local follow-up is not authorized
for push or release yet.

The follow-up keeps each hand's narrow median-based window when all recent
confirmed delays fit inside it. When a sample falls outside those margins,
that hand retains at least the initial 0.25–0.9 second range from Gamooly's
fix. The aggregate window combines learned hands using the same calculation.
Weapon-speed changes still invalidate that hand's samples. Variable hands
still use a broad window, so group-combat ambiguity is not eliminated.

The new stable-window and real-reader competing-hit regressions failed first.
After the fix, 16 focused tests passed. The full suite ran 141 tests: 140
passed and the actual release-archive check was skipped. Tests preserve the
slow-weapon cases, check final attribution as samples change, ordinary timing
jitter, hand independence, sample reset and a teammate hitting at 0.30 seconds
before the player's learned 0.45-second hit.

All 102 runtime files match Forever by SHA-256, with no extra installed files.
All 70 installed Lua files compile as Lua 5.1. Four installed regression
scripts passed: melee windows, the combat engine including competing hits,
miss attribution, and killing-blow classification/deduplication.

Next: run `/reload` in Forever and check a slow two-hander in solo and group
combat. The adaptive refinement is saved locally only; live validation is
pending. Public v12.050 predates this melee-window change.

## Release v12.050

Updated: 2026-11-12

Release commit `4e49e69` and tag `v12.050` were pushed from main, including
the attribution follow-up `921e3b8`. Both manifests identify v12.050. The
changelog covers killing-blow routing and duplicates, Gamooly's miss attribution
contribution and the follow-up, and the opt-in loot profiler. Restricted
Windfury damage still displays separate amounts; no summation change was made.

Both GitHub validation runs and the CurseForge workflow succeeded:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43117600919
The upload response accepted CurseForge file `9566384`. Public processing or
moderation status was not independently verified.

The exact workflow artifact is retained at
`D:/Codex-Temp/msbt-v12.050-release/MikScrollingBattleText-v12.050.zip`.
It contains 102 files, 628,059 compressed bytes and 1,932,696 uncompressed bytes.
All six actual-archive tests passed with no skips. All 70 packaged Lua files
compile as Lua 5.1. Runtime files and binary media match the release source,
apart from expected line endings and LibDeflate comment metadata substitutions.
The profiler, both client manifests, locales, libraries, fonts, sounds and
artwork are present; development files are excluded by the existing .pkgmeta.

The full local suite passed 139 tests with one actual-archive check skipped
before packaging. Whitespace checks passed. Forever's 102 runtime files match
the source, including both v12.050 manifests.

Next: obtain a loot timing capture from a user who experiences the stutter.
Run `/msbt lootprofile`, reproduce for 10–20 seconds, and collect the five
lines from `/msbt lootprofile stop`. The stutter cause is still unconfirmed.

## Miss attribution follow-up

Updated: 2026-11-11

At the user's request, the five local checkpoints through `6d400bc` were pushed
to main. Gamooly's PR #35 was merged as `b4e6c06` and pulled with `--ff-only`.
The requested thank-you and follow-up comment was posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/35#issuecomment-6809046602
GitHub validation passed for the merge. No release was requested.

The local follow-up preserves a miss confirmed by a direct-spell line when a
pet or recent ranged shot is present. The ambiguous-miss preference from the
PR remains intact. Candidate ranking now also rejects ranged parries, matching
the final attribution rule so an impossible candidate cannot take a scarce
confirmation. The recent-cast fallback uses the same confirmation rule.

Both regressions failed first and passed after their fixes. Fourteen focused
combat tests passed. The full suite ran 140 tests: 139 passed and the actual
release-archive check was skipped. All 70 installed Lua files compile as Lua
5.1; miss attribution, kill classification/deduplication, and kill presentation
regressions passed against the installed files. All 102 runtime files match
Forever by SHA-256, with no destination extras.

This follow-up is a local checkpoint only; the push authorization covered the
pre-existing changes. Live combat confirmation is still pending.

Next: run `/reload` in Forever and check Hunter's Mark with pet parries, ranged
misses, and confirmed spell misses. The affected-user loot timing report is
still pending.

## Forever runtime sync

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
