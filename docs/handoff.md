# Spell tracking merged into main

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

The Forever installation still has the feature branch version from before
this merge. Its earlier sync does not include main's additional changes.

Next: sync main to Forever before checking Windfury bursts and killing blows
in game.
