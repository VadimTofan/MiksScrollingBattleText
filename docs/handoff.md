# Low resource sound cooldowns

Updated: 2026-11-11

On `feat/spell-tracking`, low-health and low-mana sounds each have an
independent 10-second cooldown. The first sound and all text alerts remain
immediate. Muted or disabled alerts do not consume the cooldown. Runtime
disable/enable cycles preserve the cooldown; unrelated sounds are unchanged.

Verification: the new regression test failed before implementation and passed
afterward. The full unittest suite ran 130 tests: 129 passed and the release
archive check was skipped because no archive was supplied. Lua 5.1 checks used
the existing Lupa runner. `git diff --check` passed.

Next: sync the three changed runtime files to the Forever installation before
checking repeated resource threshold crossings in game. That installation
still has the earlier branch version without these cooldowns.
