# v12.048 release preparation

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

Both client manifests and the README now report version 12.048. The changelog
describes the merged spell matching, Windfury, sound, and killing-blow changes.
The release tag will trigger the existing CurseForge workflow, which verifies
the actual package before upload.

The Forever installation still has the feature branch version from before
the merge. Next: verify the release workflow, then install v12.048 in Forever
and check Windfury bursts and killing blows in game.
