# v12.048 release

Updated: 2026-11-11

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

The integration suite ran 133 tests: 132 passed and the release archive check
was skipped. Whitespace checks passed. Next: pull the integration into local
main while preserving the separate local font-size commit, then verify it.
