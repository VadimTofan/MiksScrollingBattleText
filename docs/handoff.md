# Killing-blow damage

Updated: 2026-11-09

The reader keeps a lost target's key for 500 ms for late damage reports.
Existing ownership checks and batching still apply. Selecting a new target,
changing worlds, or restarting the reader clears the fallback.

Regression coverage includes player and pet spells, target/nameplate removal
order, a nameplate added after casting, duplicate reports, expiry, and restart.

Verification: the full unittest suite ran 130 tests successfully, with the
release-ZIP check skipped because no release archive was supplied. Lua 5.1
checks used the existing local Lupa runner. `git diff --check` passed.

Next: run `/reload` in game and check killing blows with nameplates enabled
and disabled. Client event delivery still needs in-game verification.
