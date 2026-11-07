# Release handoff

Updated: 2026-11-08

## Windfury rollback

- User reports Windfury stopped working after b4d9549 and requests reverting
  the last change. Reverted that commit; retained the earlier Windfury
  matching, icons and deeper diagnostic capture from 97495ad.
- Removed the Stormstrike anchor and direct-miss attribution changes, along
  with their diagnostic timeline additions and associated regressions.
- Validation: 125 tests run, 124 passed, one expected actual-archive skip.
  Lua 5.1 parsing and whitespace pass. No generated task logs remain.
- Restored Reader.lua, WindfuryCapture.lua and WindfuryTrace.lua in Forever;
  source/destination SHA-256 hashes verified.
- Next: reload and verify the previous Windfury behavior in game. Do not
  reapply b4d9549 without investigating the reported regression. No push
  or release was requested.

## Deeper Windfury capture

- Added `/msbttrace wf` for background capture without the ordinary trace
  overlay. Retains eight native swing timelines with stable raw-report IDs,
  own log classifications, damage/miss decisions, pairing windows, consumed
  confirmations, target keys and display paths. Each timeline is bounded to
  32 reports; truncation is reported.
- A candidate expects two extra attack outcomes plus its ordinary swing.
  Evidence is an identified Windfury proc, or an active enchant with two
  nearby own direct confirmations or an extra-attack notice. This grouping
  is diagnostic evidence, not authoritative spell identification.
- Captures fewer than two damage outcomes, misses, batching into one number,
  and display gates. Automatically freezes an incomplete candidate after
  3.1 seconds and opens a copyable report. `/msbttrace pause` stops capture;
  `/msbttrace report` reopens the retained report. Escape closes the panel.
- Report data contains public metadata only, never damage values or combat
  log text. Animation dispatch is recorded separately from display requests;
  it cannot prove visible pixels. Matching rules remain unchanged. Optional
  reader observers are absent during normal play.
- Regression tests failed before their implementations. Full validation:
  125 tests run, 124 passed, one expected actual-archive skip. Includes real
  reader observations, real presentation/batching/display gates, opaque
  values, failed attacks, retention, rekeys, stop/restart timer isolation,
  return values and error propagation. Lua 5.1 parsing and whitespace pass.
- Installed four Lua files and both local diagnostic TOC loaders into
  Forever; verified source/destination hashes and manifest contents.
  Diagnostic files remain excluded from release manifests and packaging.
- Next: reload, run `/msbttrace wf`, and copy the automatically frozen report
  after a proc shows fewer than two numbers. In-game capture remains pending.
  This checkpoint is local; no new push or release was requested.

## Intermittent single Windfury number

- User now reports that some Windfury procs show only one hit. Do not assume
  another timing failure without distinguishing dropped damage, a failed
  attack, a killing blow with no second report, or public-amount batching.
- Restricted amounts go directly through DisplayRestricted and are never
  merged. Readable amounts are batched for 0.3 s; the stackSimilarHits setting
  controls the count trailer, not whether that batching occurs.
- The trace previously omitted target MISS/DODGE/PARRY/etc. and classified
  miss records. Added those outcomes using native text rendering and the
  existing timing context. Damage matching, counting and presentation are
  unchanged by this diagnostic update.
- The outcome regression failed first. Full validation: 123 tests run,
  122 passed, one expected archive skip; Lua 5.1 parsing and whitespace passed.
  No generated task logs remain.
- Installed the updated trace in Forever and verified its SHA-256.
- Next: capture a proc that shows only one damage number, preferably before
  the target dies. Look for the
  second raw damage or failed-attack report before changing the matcher.

## Windfury icon identification

- User confirms extra damage numbers now appear, but without an icon.
  The confirmed proc records had no spell/procSpell identity for presentation.
- Added active Windfury enchant identification for Forever physical procs.
  Queries C_PaperDollInfo.GetTemporaryEnchantmentInfo on slots 16/17 when
  available, otherwise the guarded GetWeaponEnchantInfo tuple. Vanilla
  Windfury enchant IDs 283/284/525/1669 resolve to spell 8232 for its icon and
  localized name. No cast history or saved icon cache is required after reload.
- Existing confirmed-proc matching is unchanged. Ordinary melee remains an
  Auto Attack; magic, unknown-school, and non-Forever procs retain their
  existing identity logic. Expired/replaced enchants and unreadable/erroring
  API results do not supply a stale Windfury icon.
- Both the icon identity test and actual main/display regression failed
  before implementation. Tests cover modern and legacy API shapes, all four
  enchant ranks, both hands, removal/replacement, unreadable metadata and API
  failures. Both captured damage sequences now supply icons to presentation.
- Validation: 123 tests run, 122 passed, one expected archive skip. Lua 5.1
  parsing and whitespace passed. No generated task logs remain.
- Installed the tested Reader.lua in Forever and verified its SHA-256.
- Next: confirm the icon after reload with Windfury already active.
  No push or release is authorized for
  these new checkpoints yet.

## Windfury confirmation-offset follow-up

- User confirms both the generic outgoing display test and the exact
  OUTGOING_SPELL_DAMAGE event display test are visible. The window and event
  style therefore work; missing proc reports still require matcher fixes.
- A successful post-patch capture accepts proc 168, normal 178, and proc 130.
  The next capture rejects 179 and glancing 111: their two spell lines arrive
  0.099 seconds after the native swing, and the last report follows the normal
  hit by 0.873 seconds. The first patch required exact-frame confirmations
  and allowed only 0.5 seconds after the ordinary hit.
- Added that second capture as an opaque-amount regression; it failed before
  the correction. Physical proc matching now reuses the existing 0.5-second
  swing-to-proc-line window and permits up to 1 second after a confirmed
  normal hit. The same target, unused direct confirmation, and one-use line
  rules remain required. Retail and magic proc timing remain unchanged.
- Both captures pass through the real reader and real main/display adapter
  fixtures. Full validation: 122 tests, 121 passed and one expected archive
  skip; Lua 5.1 parsing and whitespace passed. No generated task logs remain.
- Installed the corrected Reader.lua in Forever and verified its SHA-256.
- Next: reload and test without the trace panel covering combat text. If
  damage is still missing, capture
  the new trace. No additional game confirmation or release has happened yet.

## Windfury delayed-hit patch

- The latest capture shows one swing line and two spell lines at 43707.394.
  A physical proc hit of 179 is accepted at swing age 0.22 s, the ordinary
  196 hit is accepted at 0.59 s, and the later physical 180 hit is rejected
  at 1.02 s. No separate `extra` marker is shown in this capture.
- Reproduced that sequence with opaque amounts through the real reader.
  The second proc was missing before the fix. Extended Forever's physical
  proc pairing to 0.5 seconds after a confirmed normal hit, requiring the
  same target and an unused direct-damage line from that swing's frame.
  Every confirmation still serves once. No damage amount is inspected.
- Tests retain the early proc, ordinary hit and delayed proc. They reject
  another target's hit, reused confirmations, magic hits, reports outside
  the window, DoT confirmations, and the new behavior on Retail. A real
  main-module regression verifies all three amounts reach MSBT's renderer.
- Validation: 122 tests run, 121 passed, one expected archive skip. Lua 5.1
  parsing and whitespace passed. No generated task logs remain.
- Installed the tested Reader.lua in Forever and verified its SHA-256.
- Next: verify both extra-hit amounts in game after reload. Proc-specific
  Windfury names/icons are not
  added by this patch; the recovered hit uses outgoing spell-damage settings.
  Do not push or release without a new user request.

## Windfury Weapon investigation

- User reports missing damage from their shaman's Windfury Weapon after
  confirming the queued-strike patch. No Windfury fix has been made yet.
- Current extra-swing pairing assumes at least 0.38 seconds between an
  orphan melee log line and its hit. A hypothetical immediate three-hit
  melee burst is rejected by the actual reader. The live Windfury sequence
  is still unknown. Accepted extra attacks currently use the Auto Attack
  icon; Windfury Weapon is not recognized as a named weapon-proc source.
- Expanded the opt-in trace to include PLAYER_SWING, combat-log kind/source
  timing, and extra/proc result markers. Combat-log text and opaque amounts
  are never inspected. The regression failed first; validation: 122 tests,
  121 passed and one expected actual-archive skip. Whitespace passed and no
  generated task logs remain.
- Installed the tested trace only in Forever and inserted its load entry
  into that installation's two manifests. Repository/release manifests
  still exclude the trace. Restore those installed manifests from the
  repository and remove the installed Trace.lua after the investigation.
- Next: reload, run `/msbttrace`, trigger Windfury Weapon, stop attacking,
  and capture the panel. Do not assume the timing hypothesis is confirmed.

### Windfury capture follow-up

- The first capture ended in a swing/kill without a target damage report.
  The second shows physical hits 58 (glancing), 13, 97, 91, and 61 classified
  as `other`, while the Fire tick is correctly assigned to spell 8053.
- The rolling panel no longer contains the preceding native swing and melee
  log lines. It cannot yet establish which physical reports were Windfury
  or why their timing failed the matcher.
- Added native/tracked/melee-log ages directly to every match row, plus
  whether that last log line is free or consumed. The native timestamp is
  captured independently of the engine's enum/hand mapping, so missing
  tracked swings can be distinguished from an overly narrow timing window.
- The regression failed first. Full validation: 122 tests, 121 passed and one
  expected archive skip. Next: capture another Windfury proc with the age
  fields visible. There is still no Windfury damage patch.

### Windfury timing evidence and missing proc signal

- The next screenshot shows the accepted 60 hit at native/tracked/log age
  0.58 s, followed by rejected target hits 84 at 0.60 s and critical 299 at
  0.71 s. Both refer to the already-consumed swing line. Later physical
  reports also remain `other`; their ownership must not be inferred solely
  from proximity to the player's swing.
- Found `SPELL_EXTRA_ATTACKS` missing from MSBT's outgoing combat-log filter.
  Blizzard's combat-log source supports that event. Added it with a distinct
  `extra` colour/kind and no damage class, so a grant cannot itself confirm an
  unrelated damage report. This is signal collection, not yet a damage fix.
- The filter regression failed first. Full validation: 122 tests, 121 passed,
  one expected actual-archive skip; Lua 5.1 parsing and whitespace passed.
- Installed the tested filter update in Forever and verified its SHA-256.
- Next: reload and accept MSBT's reload prompt to activate the updated
  filter, then trace Windfury for `log [extra]`.
  Do not attribute a burst until its proc marker is verified in game.

## v12.045 released

- User confirmed the queued-strike patch works in game and requested commit,
  push, and release. The fix is already saved in 54a00aa.
- Prepared v12.045 with matching manifests, README status, and release notes.
  The temporary trace stays in the source/test tree but is no longer loaded
  by either manifest and is excluded from release packages.
- Local validation passed: 122 tests run, 121 passed, one expected archive
  skip; Lua 5.1 parsing and whitespace passed. No generated task logs remain.
- Release commit 9745923 and tag v12.045 are pushed. Main and tag validation
  passed. Package-only and final uploaded ZIPs passed all six archive checks.
- Package-only run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42401188330
- Release run: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42401301431
- Final ZIP: 99 files, 598,860 bytes; all 69 packaged Lua files parse with
  Lua 5.1. Runtime dependencies, media, and notices remain. The temporary
  trace is excluded. Final contents match the package-only build except
  the expected release-tag metadata comment in LibDeflate.
- CurseForge accepted file 9496878. Processing and public availability have
  not been checked. No release actions remain.
- Final artifact: D:/Codex-Temp/msbt-v12.045-release/final/MikScrollingBattleText-v12.045.zip/MikScrollingBattleText-v12.045.zip
- The Forever installation has the release manifests and tested Reader.lua.
  Removed the unchanged temporary trace file from that installation.
- Whitespace passed and no generated task logs remain.

## Queued-strike patch checkpoint

- The second Raptor Strike trace shows both same-frame WOUND reports use
  school 1 and an empty flag. MSBT assigned the initial zero to spell 2973
  and rejected the subsequent real hit (12 in that capture).
- Added a Forever-only tie breaker for exactly two physical damage reports
  on one unit, one direct spell confirmation, and an unused Heroic Strike,
  Maul, or Raptor Strike cast in that exact frame. The later report wins an
  equal-fit tie. Damage amounts remain opaque and are never compared.
- This is a narrow timing inference, not authoritative ownership. Ordinary
  spells, Retail, lone hits, unconfirmed hits, frames with more reports, and
  casts from earlier frames retain their existing matching behavior.
- The real reader regression failed on the zero report before the patch.
  Tests now cover all 24 Vanilla ranks across the three abilities and the
  real MSBT presentation pipeline for their base ranks, including Maul's
  different description wording.
- Validation: 122 tests run, 121 passed, one expected actual-archive skip.
  Lua 5.1 parsing and whitespace passed. No generated task logs remain.
- Installed the tested `Combat/Reader.lua` in the requested Forever addon
  folder and verified its SHA-256 matches the workspace file.
- Next: reload and confirm Raptor Strike displays its actual hit in game.
  Keep `/msbttrace` available
  for confirmation; the patch has not yet been verified in game or released.

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
