# Shaman Windfury icon fallback

Updated: 2026-11-11

On Forever, shamans with an active Windfury imbue use Windfury's icon for
unidentified physical procs as a best guess. Other classes, damage schools,
expired imbues, and unreadable enchant data retain the existing behavior.
Damage amounts and hit matching are unchanged. The independent 10-second
low-health and low-mana sound cooldowns remain in place.

Verification: the proc fallback and main runtime tests failed before
implementation and passed afterward. The full suite ran 130 tests: 129 passed
and the release archive check was skipped because no archive was supplied.
Lua 5.1 checks used the existing Lupa runner. `git diff --check` passed.

The Forever installation was synced and all 101 runtime/supporting files
matched the branch byte-for-byte.

Next: run `/reload` in Forever and check the Windfury icon on shaman procs.
