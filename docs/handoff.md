# Aura exclusions by name or ID

Updated: 2026-11-11

Adding an aura by name now creates an all-ranks rule. Adding a numeric ID
creates an exact-ID rule. Existing saved rules remain exact-ID rules because
their original input is unknown. Name rows display "all ranks"; ID rows keep
their number. Both rule types retain checkbox states and custom styles through
profile export and import.

Either matching exclusion hides the notification. When both matching rules
are enabled, the exact-ID style takes priority. Name-only combat-text notices
can match name rules, but cannot establish an exact rank for ID rules. If WoW
hides both identity fields, the notification still displays.

Regression tests failed before implementation for name resolution, the options
row, and profile transfer. The full suite ran 133 tests: 132 passed and the
release archive check was skipped. Whitespace checks passed.

The four changed runtime files were synced to Forever and verified by SHA-256.
In-game behavior has not yet been checked.

Next: run `/reload` in Forever and replace an old ID rule with a name entry to
check gains and fades across ranks in game.

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
