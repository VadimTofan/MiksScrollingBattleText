# Release handoff

Updated: 2026-10-30

- Fixed outgoing Chaos spell attribution when a Chaos tooltip (127) is
  followed by damage reported as 124 or 126, including bolt and channel hits.
- Regression cases failed before the fix and passed afterward. Full validation:
  120 tests run, 119 passed, one expected actual-archive skip; whitespace passed.
- Next: reload in game and verify outgoing Eye Beam and Chaos Bolt damage.
  Incoming damage was not reproduced; the user's direction clarification is open.
- This checkpoint has not been pushed or released.

## Previous release

- Prepared v12.042 for the combat setup reload prompt in commit 6cb6bd2.
- Deleted the local feat/forever-outgoing-attribution branch as requested.
- Pushed release commit b22fdc0 and tag v12.042 to origin.
- CI validation: 120 tests, one expected actual-archive skip.
- Release archive validation: all 6 tests passed against the BigWigs ZIP.
- CurseForge accepted the upload as file 9314426.
- Release workflow: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/40134428538
- Whitespace check passed. No generated task logs remain.
- No release actions remain. In-game behavior and CurseForge public availability
  have not been checked.
