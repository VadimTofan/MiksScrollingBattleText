# Windfury stacking

Updated: 2026-11-11

With Stack Similar Hits enabled, Windfury damage uses a one-second grouping
window. Readable hits are summed; groups containing restricted damage pass
each value to native text formatting on one line, such as
`120 + 150 [2 Hits]`. No restricted damage is inspected or added in Lua.
Normal and critical hits retain separate settings and batches.

Other spells and disabled stacking retain their previous behavior. Resetting
the batcher clears pending output. Toggling stacking cannot mix a pending
ordinary batch with a restricted Windfury group.

Verification: the new batcher and main runtime regressions failed before
implementation and passed afterward. The full suite ran 131 tests: 130 passed
and the release archive check was skipped because no archive was supplied.
Lua 5.1 checks used the existing Lupa runner. `git diff --check` passed.

The Forever installation was synced and all 101 runtime/supporting files
matched the branch byte-for-byte.

Next: run `/reload` in Forever, enable Stack Similar Hits, and check Windfury
bursts. Native rendering still needs in-game verification.
