# Release handoff

Updated: 2026-10-30

- Follow-up: active channels now use the existing delayed line-pairing path.
  Previously only pending bolts and ranged swings were eligible, so channel
  hits lost their spell identity when their confirming line crossed frames.
- Regression failed before the fix. Tests now cover either event order,
  a final hit paired after channel stop, and rejection of unconfirmed damage.
- Validation: 120 tests run, 119 passed, one expected actual-archive skip.
- Next: reload and verify a complete Eye Beam channel in game. Whether missing
  hits occur on one target or mainly across several enemies remains unanswered.
- This checkpoint has not been pushed or released.

## Chaos school checkpoint

- Fixed outgoing Chaos spell attribution when a Chaos tooltip (127) is
  followed by damage reported as 124 or 126, including bolt and channel hits.
- Regression cases failed before the fix and passed afterward. Full validation:
  120 tests run, 119 passed, one expected actual-archive skip; whitespace passed.
- In-game feedback: Eye Beam improved but still missed some hits, prompting
  the channel timing follow-up above. Chaos Bolt remains unverified in game.
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
