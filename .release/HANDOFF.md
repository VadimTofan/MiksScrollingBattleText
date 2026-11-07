# Release handoff

Updated: 2026-11-07

## Queued-strike damage investigation

- Heroic Strike, Maul, and Raptor Strike reportedly show a literal zero. The
  user confirmed Raptor Strike's zero appears when the melee hit lands.
- Short Numbers was already off. A temporary raw-event probe showed raw 13
  and formatted 13, but auto-attacks could overwrite that sample. The cause
  remains unconfirmed; no damage fix has been implemented.
- Added an opt-in `/msbttrace` panel with 18 retained rows for target hits,
  spell casts, attribution, outgoing batching, and final display text. Native
  font strings render opaque amounts directly. Tracing changes no damage
  arguments, saves no hit values, and is off by default after each reload.
- Regression tests failed before implementation. Validation: 122 tests run,
  121 passed, one expected actual-archive skip. Lua 5.1 parsing and whitespace
  checks passed. No generated task logs remain.
- Installed `Combat/Trace.lua` and both addon manifests in the requested
  `_forever_/Interface/AddOns/MikScrollingBattleText` folder; all three copied
  files match the tested workspace files by SHA-256.
- Next: load the diagnostic in Forever, run `/msbttrace`, land one Raptor
  Strike, and capture the panel immediately after stopping auto-attacks.
- The panel is temporary investigation tooling, not a fix or a release.

### Trace evidence from Raptor Strike

- The screenshot shows spell 2973 casting at 10622.631, then two target WOUND
  reports at the same time: 0 followed by 13. At 10622.640 MSBT renders 0,
  assigns that report to spell 2973, and attributes the 13 report to `other`.
- The shortage-of-lines matcher ranks both reports and uses their original
  event order to break equal-fit ties. The first report consumes the spell's
  confirmation. The prior raw-13 probe did not distinguish these reports.
- The next diagnostic adds native school and flag fields to each raw-hit row.
  This is needed before selecting a safe discriminator; reversing hit order
  alone could wrongly claim another player's damage.
- The metadata regression failed before the trace update. Full validation:
  122 tests run, 121 passed, one expected archive skip. Next: capture one more
  Raptor Strike with the school/flag fields visible. No damage fix exists yet.

## Reload reminder checkpoint

- Removed the redundant reload chat message; the setup popup and its Reload UI
  and Cancel buttons remain covered by the runtime regression.
- Regression failed before the fix and passed afterward. Validation: 120 tests
  run, 119 passed, one expected archive skip, using Lupa's Lua 5.1 runtime.
- Whitespace passed. No generated task logs remain.
- Released v12.044 from 29887c3; main and tag are pushed. Main and tag CI passed.
- Package-only run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42306011042
- Release run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42306189378
- Both actual ZIPs passed all six archive checks. Final ZIP: 99 files,
  598,285 bytes; all 69 packaged Lua files parse with Lua 5.1. Runtime files,
  media, libraries, and notices remain; development files are excluded.
- Final contents match the dry run except for the expected release-tag
  substitution in LibDeflate's metadata comment.
- CurseForge accepted file 9482708. Processing and public availability have not
  been checked. No release actions remain.
- Final artifact: D:/Codex-Temp/msbt-v12.044-release/final/MikScrollingBattleText-v12.044.zip/MikScrollingBattleText-v12.044.zip

## Released version

- Released v12.043 from ef18446 with the Chaos-school and delayed channel-hit
  fixes from 2b3aa22 and 257752a. The user confirmed both spells work in game.
- Cancelled and deleted feat/friendly-healing at the user's request. Its five
  commits are not part of main or this release.
- Pushed main and tag v12.043 to origin. Main and tag CI validation passed:
  120 tests run, 119 passed, one expected archive skip.
- Package-only run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/41134404534
- Release run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/41134600765
- Both actual ZIPs passed all six archive checks. Final ZIP: 99 files,
  598,350 bytes; all 69 packaged Lua files parse with Lua 5.1. Dependencies,
  runtime media, and notices are retained; development files are excluded.
- Final contents match the dry run except for the expected release-tag
  substitution in LibDeflate's metadata comment. Healing experiments are absent.
- CurseForge accepted the upload as file 9377689. Public availability and
  processing status have not been checked.
- Final artifact: D:/Downloads/MSBT-v12.043-release/MikScrollingBattleText-v12.043.zip
- Whitespace passed. No generated task logs remain. No release actions remain.

## Channel timing checkpoint

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
