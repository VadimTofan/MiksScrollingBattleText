# Chinese hunter report investigation

Updated: 2026-11-13

User requested investigation of missing skill names, Summon Hawk attacks
shown as permanent-pet melee, and Serpent Sting ticks using another icon.
Gallery: https://postimg.cc/gallery/3d7MmLn. All four screenshots were inspected;
they show v12.051 and the Simplified Chinese (zhCN) client. The relevant code
paths remain present on current main after PR #52.

Findings and evidence:
1. Confirmed: MSBTMain.lua DisplayRestrictedAmount calls CleanupActionMessage,
   which removes skill placeholders before they can be replaced. A disposable
   assertion in the real combat_main_runtime fixture fails because a known
   spell's name disappears despite hideSkills=false. Misses take a separate
   presentation path, explaining why their names can appear.
2. Summon Hawk is a temporary summon, not the hunter's Auto Shot. The tracker
   has no separate guardian identity; unmatched physical swings with a pet
   present can return who=pet with melee=true. Presentation then uses the
   permanent pet's family icon. A synthetic summon dive followed by a swing
   reproduces that fallback. This confirms the model gap; the screenshots
   alone cannot establish which live swing belonged to which creature.
3. Confirmed localization gap: Combat/Spells.lua SpellFacts returns before
   querying any facts on non-English clients, including the locale-independent
   helpfulness API. English can reject a physical Hawk spell as the source of
   Nature damage; zhCN lacks that constraint. A synthetic Nature tick following
   a Hawk cast is rejected on enUS but receives the Hawk spell ID on zhCN.
   This reproduces a cause consistent with the wrong-icon report; the exact
   screenshot event sequence has not been captured in game.

Disposable reproductions and downloaded screenshots:
`D:/Codex-Temp/msbt-chinese-hunter-report-20261113`.
The reproduction uses synthetic spell IDs and is not a live combat recording.
No production code or installed client files were changed during investigation.

Next: fix public spell-name substitution around restricted damage first, with
hideSkills and localized-name regressions. Then address non-English spell
facts and investigate reliable summon attribution without inventing a source
when the available event evidence cannot distinguish it.

Primary reference for Summon Hawk's initial hit, temporary summon duration,
and support for two active hawks:
https://news.blizzard.com/en-us/article/24301515/world-of-warcraft-forever-class-deep-dives-hunter-and-druid

# Release v12.052 published

Updated: 2026-11-13

The user authorized committing, pushing, and releasing the current changes.
Both root TOCs now declare 12.052. CHANGELOG.md describes all user-visible
changes since v12.051. Temporary diagnostics remain outside release manifests
and packages. No workflow credentials or upload targets were changed.

Release commit `7cd02c4a95c51b8b0192327dd45edf08c9494de3` and annotated tag
`v12.052` were pushed to origin. Main and tag validation both passed.
Package-only run `43418603030` passed before tagging; its real ZIP passed
all six archive checks and all 71 packaged Lua files compiled with Lua 5.1.

Publication workflow:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43418732431

The workflow validated its rebuilt ZIP before upload. CurseForge accepted
file ID `9589815`. Public listing and processing status were not independently
checked. The exact uploaded workflow artifact was downloaded and verified:
103 files, 638200 bytes compressed, 1971367 bytes uncompressed. Both packaged
TOCs declare 12.052; all 71 Lua files compile. Runtime dependencies, media,
libraries, locales, and licensing are retained; development files and temporary
diagnostics are excluded.

Published artifact:
`D:/Codex-Temp/msbt-v12.052-release/MikScrollingBattleText-v12.052.zip`.

The final full suite ran with this real archive: all 150 tests passed, with
no skips. Whitespace checks passed. No generated workspace log files remain.
No release implementation work remains. Live resource-source capture and
in-game verification described below remain separate follow-ups.

# Outgoing melee attack colors

Updated: 2026-11-13

Outgoing melee swings now display in white; direct physical abilities display
in yellow. This applies to player/pet hits, crits, readable and restricted
amounts, and grouped hits. Magic-school damage, periodic damage, and incoming
damage retain their existing styling.

`Components/OutgoingBatcher.lua` derives temporary event settings for these
attacks and suppresses the physical-school amount markup that would otherwise
override their color. Saved profile settings remain unchanged.

Verification: the new runtime regression failed on the old attack colors
before implementation. The full suite ran 150 tests: 149 passed, one archive
check skipped. Seven installed Forever regression scripts passed, including
the real Retail/Forever runtime with normal/critical, player/pet, grouped,
and restricted attack-color assertions. The installed batcher matches source.
Backup: `D:/Codex-Temp/msbt-melee-colors-20261113`.

Next: `/reload` in Forever and compare an auto-attack with a physical ability.
The separate resource-source investigation below still needs a live capture.

# Resource source investigation (live capture pending)

Updated: 2026-11-13

The user requested checking whether resource gains can show their source spell
icon, such as Mana Spring Totem or Judgement. The current reader consumes only
amount and resource token from `C_CombatText.GetCurrentEventInfo`. No source
attribution or icons have been added without live evidence.

Added the opt-in `Diagnostics/ResourceCapture.lua`. It captures all returned
fields, including nil holes and extra fields, for ENERGIZE/PERIODIC_ENERGIZE;
marks secret values without inspecting them; records nearby player spell IDs
as context only; and counts combat-log messages without copying their text.
It keeps at most 120 rows, samples only the first 20 log messages, and stops
after 30 seconds or when its report opens. It does not change resource output,
enable combat-log filters, or persist captures across reloads.

Installed in Forever and appended to both installed manifests, preserving
their existing content and temporary Windfury diagnostic entries. Repository
release manifests do not load the diagnostic, and `.pkgmeta` already excludes
the Diagnostics folder. Installation backups:
`D:/Codex-Temp/msbt-resource-source-capture-20261113`.

Live procedure:
1. `/reload` in Forever, then `/msbtresources start`.
2. Trigger a single known mana source while missing mana.
3. `/msbtresources report`, then copy the report with Ctrl+A / Ctrl+C.
4. Repeat separately for another source. Opening Blizzard's combat-log tab
   can provide log samples; absent log samples do not establish API absence.

Next unfinished action: collect a report for Mana Spring Totem or Judgement
and inspect any extra resource fields. Nearby casts alone are insufficient
for assigning an icon to an individual gain.

Verification: the new diagnostic regression first failed because the module
was missing. A separate failing case caught log traffic displacing the mana
gain; log sampling now preserves it. The full suite ran 150 tests: 149 passed,
one archive check skipped. The installed diagnostic matches source, compiles
with Lua 5.1, and passes the same regression script.

API references inspected:
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatTextDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua

# Resource notification spacing

Updated: 2026-11-13

Resource defaults now use `%a %p`: `1 Combo Point`, `8 Mana`.
The Retail/Forever formatter also renders the previous exact default
`%a - %p` with a single space so existing profiles receive the change.
Other custom message templates remain unchanged; hidden amounts and names
still reach native rendering without Lua inspection.

Verification: the regression failed on the old separator before the fix.
The full suite ran 148 tests: 147 passed, one archive check skipped.
Seven installed Forever regression scripts passed; both changed production
files match their source hashes. Backups are in
`D:/Codex-Temp/msbt-resource-spacing-20261113`.

Next: `/reload` in Forever and confirm resource gains display with one space.

# Class, specialization, and form resource filtering

Updated: 2026-11-13

Resource notifications now use Configuration/ResourcePolicy.lua to allow only
resources appropriate to the player's class and current form/spec. Both client
manifests load the policy before combat presentation. The user's resource
checkboxes remain an additional restriction and are not rewritten.

Implemented notification rules:

| Class | Allowed resources |
| --- | --- |
| Druid | Cat: Energy + Combo Points; Bear/Dire Bear: Rage; Moonkin: Lunar Power; no form/travel/tree/flight: Mana |
| Rogue | Energy + Combo Points |
| Warrior | Rage |
| Hunter | Current Focus or Mana, supporting Forever's mana-based hunters |
| Mage | Mana; confirmed modern Arcane specialization also allows Arcane Charges |
| Warlock | Mana + Soul Shards on modern clients; Mana on Forever/Vanilla |
| Priest | Current Mana or Insanity |
| Paladin | Mana + Holy Power on modern clients; Mana on Forever/Vanilla |
| Shaman | Current Mana or Maelstrom |
| Monk | Brewmaster: Energy; Windwalker: Energy + Chi; Mistweaver: Mana |
| Death Knight | Runes + Runic Power |
| Demon Hunter | Current Fury or legacy Pain |
| Evoker | Mana + Essence |

Druid form ID takes precedence over primary power, including Moonkin whose
client reports Mana and unshifted Balance whose client reports Lunar Power.
If form data is absent, readable primary power supplies the fallback. Arcane
Charges and Chi require a confirmed Arcane or Windwalker specialization;
characters without a selected spec do not gain those secondary notifications.

Readable tokens are checked directly. Hidden tokens use native matching
against the allowed resource names, with unchecked resources removed first.
Unknown resource tokens are hidden when class context is known. If native
eligibility cannot be computed, the hidden notice is suppressed. If class
identity itself is unavailable, existing user filtering remains available;
unreadable druid form/power context falls back to the druid resource family.
Combo-point totals and Finish Him use the same eligibility check, so other
druid forms and other classes cannot display those alerts. No new sources
for resource gains were added.

Native-gated notices still occupy animation slots until they expire, and their
sounds are muted because the match cannot gate Lua playback. The resource
configuration help now explains both automatic eligibility and sound behavior.

Research references: [Blizzard class descriptions](https://worldofwarcraft.blizzard.com/en-us/game/classes),
[unit API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua),
and [specialization API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua).
The explicit druid notification rules above follow the user's requested policy.

Regressions first failed for the missing policy, then for Mana leaking into
cat form and secondary resources appearing without a spec. Verification:
148 tests ran, 147 passed and the actual release-archive check was skipped.
Coverage includes 37 class/form/spec cases, namespace/legacy spec APIs,
secret context, hidden-token allowlists, unknown resources, manual exclusions,
form switching, and combo alert eligibility. Both manifest load orders pass.

Forever has the three Lua changes matched to source by SHA-256. Both installed
manifests received only the policy entry; their diagnostic entries were
preserved. Eleven related installed Lua files parsed and seven installed
regression scripts passed. Backups and the verifier are under
D:/Codex-Temp/msbt-forever-class-resource-policy-20261113.
The source change has not been pushed; live testing across classes is pending.

Next: /reload in Forever and switch druid forms; verify each form only shows
the resource notifications listed above.

# Resource display names and maximum combo alert styling

Updated: 2026-11-13

"Finish Him!" now renders in red at twice the effective combo-point font size.
The scale is applied after the display service resolves event, scroll-area,
and profile font inheritance. Both public-count and native-gated maximum
alerts use the same styling and retain the existing sticky/Pow animation.
Shared resource settings are not mutated.

Known resource tokens now display readable names, including LUNAR_POWER as
"Lunar Power", RUNIC_POWER as "Runic Power", and SOUL_SHARDS as "Soul Shards".
The bounded resource-name table covers the same 30 token types as the resource
configuration. Hidden tokens select labels through native string matching;
they remain opaque to Lua. Unknown/custom labels and unavailable-helper
fallbacks retain their original text.

Regressions first failed for raw resource names and the unchanged alert font.
All 146 tests ran: 145 passed and the actual release-archive check was skipped.
Seventeen focused checks also passed after the final formatting changes.
Coverage includes event/area/profile font resolution, red styling, hidden
maximum alerts, multiword labels, custom labels, and the real combat runtime.

Forever's presentation and display service match source by SHA-256. Ten
related installed files parsed with Lua 5.1 and six installed regression
scripts passed. Backups and the verifier are under
D:/Codex-Temp/msbt-forever-resource-display-20261113.
The source change has not been pushed; in-game visuals have not been checked.

Next: /reload in Forever and reach maximum combo points; verify the red
Finish Him alert is twice the ordinary combo-point text size.

# Druid cat-form resource filtering

Updated: 2026-11-13

Resource gains for Rage and Lunar Power are now hidden while the player is a
druid using energy (cat form). Public UnitClass/UnitPowerType results establish
the form; secret or unavailable form information is not guessed. The check is
performed for each gain, so leaving cat form restores the existing behavior
immediately. Energy, combo points, and mana retain their existing behavior.

The form exclusions are temporary and combine with the user's resource
checkboxes without changing saved choices. Hidden resource tokens use the
existing native string-matching visibility path and its sound limitations.
Other classes are unaffected.

The regression failed first because cat-form Rage was displayed. All 146 tests
ran: 145 passed and the actual release-archive check was skipped. Coverage
includes readable/hidden tokens, user exclusions, form changes, other classes,
numeric power identification, and unavailable or secret form information.

Forever's Components/CombatPresentation.lua matches the tested source by
SHA-256. Nine related installed files parsed with Lua 5.1 and five installed
regression scripts passed, including the full Retail/Forever runtime and new
cat-form cases. The previous presentation file is backed up under
D:/Codex-Temp/msbt-forever-cat-resources-20261113.
The source change has not been pushed; in-game behavior has not been checked.

Next: /reload in Forever and check that cat form shows no Rage or Lunar Power
gains, then shift to bear and verify its Rage gains remain visible.

# Current combo-point totals and maximum alert

Updated: 2026-11-13

Combo-point notifications now use player UNIT_POWER_UPDATE events and read
UnitPower/UnitPowerMax. Nonzero totals appear immediately through the existing
Resource Gains settings, including decreases. At the actual maximum, "Finish
Him!" uses the existing sticky animation path (Pow by default). Zero produces
no visible notification. The resource master switch and combo-point exclusion
still apply; normal resource gains keep their existing behavior.

When totals are active, readable Blizzard combo-point gain messages are
discarded and hidden-token combo gains are suppressed through native string
matching, preventing a second visible gain line. Hidden current and maximum
counts use native comparisons to select normal/full visibility and singular
or plural labels. Neither count is inspected in Lua. Hidden totals create two
gated animation entries; zero hides both. Their sounds are muted because the
native decision cannot gate Lua sound playback. Unchanged readable totals
are deduplicated; hidden values are never compared in Lua for deduplication.

If the required native display helpers or power APIs are absent at startup,
the original resource-gain feed remains active. A failed native decision while
tracking totals emits no total rather than risking zero or a false max alert.

The regression failed first for the missing ComboPoints method. Verification:
146 tests ran, 145 passed and the actual release-archive check was skipped.
Coverage includes 1/2/4 totals, a seven-point cap, zero, hidden counts and caps,
resource exclusions, duplicate gain suppression, event lifecycle, and fallback.

Forever was updated with nine related runtime/configuration files, all matching
source by SHA-256 and parsing with Lua 5.1. Five installed regression scripts
passed: resources/combo totals, full combat runtime, popup controls, profile
transfer, and healer pairing. This also installs the prior individual resource
checkbox feature there. Backups and the verifier are under
D:/Codex-Temp/msbt-forever-combo-totals-20261113.
The source changes have not been pushed; in-game combat has not been checked.

Next: /reload in Forever, build combo points to maximum, then use a finisher;
confirm the current totals, sticky Finish Him alert, and no zero notification.

# Incoming healing with hidden healer names

Updated: 2026-11-13

Incoming healing now preserves a supplied hidden healer name for native
rendering when the event message includes %n. Public spell metadata and
readable amounts still pass through the existing formatter. Hidden names and
amounts remain separate native format arguments; Lua never inspects the name.
Repeated/reordered name placeholders and literal percent text are preserved.
Templates without %n remain amount-only, and Hide Skills still applies.

The full-runtime regression failed first because the hidden name did not
reach rendering. Verification: 146 tests ran, 145 passed and the actual release
archive check was skipped. Tests cover readable and hidden amounts, both
event orders on Retail and Forever, spell metadata, icons, and omitted names.

The existing 200 ms healer/amount association is unchanged; this change does
not establish reliable attribution for simultaneous heals or recover missing
source/ability information. Incoming damage is unchanged. In-game behavior
has not been checked. The source change is local and has not been pushed.

The user requested installation in Forever. The healing-only sections were
applied to Components/CombatPresentation.lua and MSBTMain.lua there. Both
files parsed with Lua 5.1, and five regressions passed against installed
production files: full-runtime healing, attribution, timer reset, combat
transitions, and healer pairing. The runtime test used Forever's older
resource baseline with the exact new healing regression added. MSBTMain.lua
matches the source by SHA-256. Presentation retained its previous resource
implementation at that checkpoint; the combo-point sync above updates it too.
The installed healing patch passed a reverse applicability check.
Backups and the verifier are under
D:/Codex-Temp/msbt-forever-healer-names-20261113.

Next: reload Forever and receive a heal in combat with %n in
the Incoming Heals message; verify the healer name appears beside the amount.

# Individual resource notification checkboxes

Updated: 2026-11-13

Events > Notifications > Resource Gains > Configure now includes a scrollable
resource list with individual checkboxes. All start enabled. The existing
Resource Gains checkbox remains the master switch; message, color, font,
sound, and scroll-area settings stay shared. Save applies the resource choices
with the other event settings; Cancel and the header close discard edits.
The popup restores its usual size and hides the resource list for other events.

Profiles store unchecked tokens in resourceExclusions. Both profile defaults
include the empty map, and portable exports/imports retain validated boolean
choices. Readable gains are filtered by their exact token. Hidden tokens reuse
the existing native string-matching visibility path, without power-update
correlation or Lua inspection. Unknown tokens remain visible. Missing native
helpers leave the original display visible. Hidden filtered notices still
occupy animation slots until expiration, as with the existing aura filter.

When exclusions are active, all hidden-token resource sounds are muted because
the native match cannot control Lua sound playback. Readable enabled resources
retain their sound. The configuration popup explains the combat sound limit.

Regression tests first failed for filtering, profile transfer, and the missing
checkbox UI. Verification: all 146 tests ran, 145 passed and the actual release
archive check was skipped. Coverage includes Save/Cancel, configuration wiring,
profile transfer, readable filtering on Retail and Forever, and opaque native
visibility reaching the real display service. In-game layout and combat
behavior have not been verified. These changes have not been pushed. The
combo-point sync above also installs these resource controls in Forever.

Next: reload the source installation and open Resource Gains > Configure to
check the list, then disable one resource and compare its gains with an enabled
resource in combat.

# Combo Point resource label

Updated: 2026-11-13

Resource presentation now replaces the exact COMBO_POINTS token with
"Combo Point". Readable tokens use direct string equality. Hidden tokens use
native comparison, normalization, and conditional text selection; the result
stays opaque and reaches native rendering. Each gain is processed immediately
without power-update correlation. Unavailable or failing native helpers retain
the original token. Other resource tokens keep their existing labels.

The regression failed first for the missing readable label. All 146 tests ran:
145 passed and the release-archive check was skipped. Coverage includes hidden
combo points alongside energy, exact matching, native helper failures, and the
readable label through the full Retail and Forever runtime. Actual combat use
of the native label selector has not been verified in game.

PR #49 was closed with the two review findings and a thank-you. This replacement
is saved locally and installed in Forever by the combo-point sync above; it
has not been pushed.
Next: load this change in Forever and verify a combo-point gain reads
"1 - Combo Point" while an energy gain keeps its own label.

# Windfury one-attack investigation

Updated: 2026-11-13

The user reports Windfury sometimes showing only one attack and wants both
outcomes accounted for. No damage count or combat attribution was changed.
The batcher currently separates normal and critical hits, and uses a
one-second grouping window. An independent probe reproduced two separate
single-hit lines for a mixed normal/critical pair. Existing delayed-reader
cases pass; a live report is needed to distinguish splitting, misses,
rejected reports, and display gates in the user's case.

The existing opt-in Windfury diagnostics are temporarily enabled in the
installed _forever_ addon. Combat/WindfuryTrace.lua, WindfuryCapture.lua, and
Trace.lua were copied and appended to both installed client manifests.
The source manifests and release packaging remain unchanged. Previous
installed files are backed up under
D:/Codex-Temp/msbt-windfury-check-20261113-000346.

Nineteen focused tests passed. Five regression scripts also passed against
the installed runtime; the three diagnostic files parsed with Lua 5.1.
No live combat report has been captured yet.

Next: /reload, run /msbttrace wf, reproduce a one-attack proc, then run
/msbttrace report and copy the report for investigation. /msbttrace pause
stops collection. Restore backed-up files and remove only newly added
diagnostic files when this investigation is finished.

# Targetless Mend Pet follow-up

Updated: 2026-11-12

PR #50 was merged as 7e61e68 and main was pulled with --ff-only.
The contributor thank-you comment is posted at:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/50#issuecomment-6837902569

Targetless Mend Pet now uses its known pet recipient. Its base spell ID and
matching localized names identify ranked versions without parsing English
descriptions. The general open-cast fallback was removed: unrelated incoming
self-heals cannot take Mend Pet's cast, and helpful buffs mentioning healing
cannot become healing casts. Unknown targetless spells receive no inferred
recipient. Named recipients and the existing outgoing confirmation gate stay
in place; hidden recipients are still ignored.

The new regression failed first on the merged implementation. Full suite:
145 tests, 144 passed and one release-archive check skipped. The full-runtime
regression covers a localized ranked Mend Pet after an unrelated self-heal
on Retail and Forever. GitHub's PR and post-merge validation passed.

The installed _forever_ runtime matches all 102 source files by SHA-256.
Three installed healing/runtime regressions passed and all 70 runtime Lua
files parsed with Lua 5.1. Its previous healing file is backed up under
D:/Codex-Temp/msbt-targetless-healing-fix-20261112-234631.

The follow-up fix is saved locally on main; it has not been pushed or
released. Next: /reload and test Mend Pet with an enemy selected while the
player receives an unrelated heal.

# v12.051 published

Updated: 2026-11-12

The user authorized pushing main and publishing a release. Release commit
is ddac17896cc511508b53c69cb69622237801f994; tag v12.051 points to it.
Both root TOCs and CHANGELOG.md agree on version 12.051.

Local suite: 144 tests, 143 passed and the archive check initially skipped.
GitHub main and tag validation passed. Package-only run 43267606425 passed;
its actual ZIP passed all six packaging tests and all 70 Lua files parsed.

Publication run:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43267797548

The rebuilt upload ZIP passed all six packaging checks before upload.
CurseForge accepted the upload with file ID 9577779. Public listing and
processing status were not independently checked. The published workflow
artifact was downloaded and passed all six archive tests locally again:
102 files, 631898 bytes, with runtime manifests, media, libraries, locales,
and licensing retained; development files excluded by .pkgmeta.

Published artifact:
D:/Codex-Temp/msbt-v12.051-release/published/MikScrollingBattleText-v12.051.zip

All 102 Forever runtime files match source by SHA-256, including version
metadata. The user confirmed school colors and healing skill names in game.
No implementation work remains for this release.

## Healing skill names with restricted amounts

Updated: 2026-11-12

Restricted healing amounts bypassed normal message formatting, so public
spell names were removed by the native amount display path. Healing now
formats public metadata with the amount omitted, then passes the original
opaque amount to native rendering. Skill visibility settings still apply.
This shared healing presentation path also preserves available incoming
metadata; damage rendering is unchanged.

The new full-runtime regression failed with "Healed %s" instead of the
spell label before the fix. Direct heals and HoTs now retain their names,
icons, and opaque amount identity on Retail and Forever; Hide Skills is
also covered. Full suite: 144 tests, 143 passed and one release-archive
check skipped. Installed Forever runtime tests passed, and the changed
runtime file matches source by SHA-256. Its previous copy is saved under
D:/Codex-Temp/msbt-heal-skill-names-20261112.

Saved locally; no push or release. Next: run /reload and test an outgoing
self-heal with skill names enabled.

## Outgoing self and pet healing

Updated: 2026-11-12

Matched player heals on self or pet now reach outgoing healing presentation
while retaining incoming display. The outgoing copy preserves amounts and
crits and treats the pet as recipient, rather than caster. Duplicate target
reports for a selected pet are ignored. Periodic heal confirmation identifies
the first HoT ticks without waiting for a rhythm to form.

Readable UNIT_SPELLCAST_SENT recipient data is paired to cast success by GUID
and spell, supporting self/pet bindings while another target remains selected.
Hidden or ambiguous recipient names are not inspected or guessed. Helpful
casts alone cannot confirm outgoing healing when combat-log confirmation is
available: an unused own heal line is required within the existing timing
window. Existing cast matching remains the fallback on clients without that
event. Passive or unidentifiable heals without a matched cast remain outside
this change.

Regressions failed first for missing outgoing heals, actual cast recipients,
and unconfirmed received healing. The full suite ran 144 tests: 143 passed,
with the release-archive check skipped. Installed Forever engine and complete
runtime regressions passed; all 102 runtime files match source by SHA-256.
The two runtime files were backed up under
D:/Codex-Temp/msbt-self-pet-heals-20261112 before installation.

API payload reference:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua

Saved locally; no push or release. Next: reload in game and test a self-heal,
a pet heal, and a HoT while an enemy is selected.

## Damage palette top spacing

Updated: 2026-11-12

The first damage-school row was anchored to the scroll content's bottom edge.
Increasing that content's height to fit the school list therefore moved the
first row down by the full list height, leaving a large empty area above it.
The first row now anchors to the content's top with 10 pixels of padding;
subsequent rows retain their existing spacing and scrolling.

The layout regression failed first, then passed with the fix. Six focused
popup, settings, menu and Lua 5.1 parse tests passed. The installed Forever
popup regression passed, and all 102 runtime files match source by SHA-256.
The fix is saved locally; no push or release was requested.

Next: run `/reload` in Forever and reopen General > Damage Colors to check the
first row starts near the top of the palette content.

## Baseline damage school colors

Updated: 2026-11-12

The user requested school coloring as baseline behavior rather than an
enable/disable option. Known damage schools now always use their configured
palette color. Legacy global and per-school disabled flags are ignored;
existing custom colors and profile-transfer compatibility are preserved.
Unknown or restricted schools keep the event color, and incoming damage and
heals retain their existing event styling.

The Damage Colors window is now a palette editor with labeled swatches only.
The global and per-school checkboxes and their obsolete localized strings
were removed. Tooltips now describe color customization in all eight locales.

Formatter, runtime and popup regressions failed first, then passed after the
change. The full suite ran 144 tests: 143 passed and the actual release-archive
check was skipped. The tests verify old disabled flags cannot suppress either
readable or hidden amount colors, and palette labels/swatches remain usable
without enable/disable controls.

Ten runtime files were backed up and synced to Forever. All 102 runtime files
match the source by SHA-256, and all 70 installed Lua files compile as Lua 5.1.
Installed main-runtime, formatter and popup scripts passed. Both school-color
checkpoints are local only; no push or release was requested.

Next: run `/reload` in Forever and verify school colors are present without
enabling an option. General > Damage Colors is only for changing the palette.

## Outgoing damage school colors

Updated: 2026-11-12

The approved change colors outgoing damage numbers by their readable school,
using the existing Damage Colors palette, global toggle and per-school
toggles. Spell names and hit counts retain the event color. Normal, critical,
periodic and pet damage use the same school path. Unknown or restricted
schools keep the event color; no school is guessed from a spell identity.

Presentation forwards the school through batching and formatting. Different
schools cannot share a damage batch. Hidden amounts remain separate native
display arguments; only their placeholders receive color codes, including
restricted Windfury groups. Incoming damage and healing retain their existing
event styling.

The full runtime regression failed first on missing outgoing school color.
After the fix, 18 focused tests passed. The full suite ran 144 tests: 143
passed and the actual release-archive check was skipped. Both Retail and
Forever fixtures cover school colors, names, criticals, DoTs, pets, disabled
settings, unknown/hidden schools, hidden amounts and separate school batches.

Four runtime files were backed up and synced to Forever. All 102 runtime files
match the source by SHA-256, and all 70 installed Lua files compile as Lua 5.1.
Installed main-runtime, combat-engine, 68-scenario periodic, Windfury stacking
and formatter scripts passed. The change is saved locally; no push or release
was requested.

The optional-toggle design above was superseded by the baseline follow-up.
Verify Frost and Shadow damage numbers in-game before release.

## Drain channel PR integration

Updated: 2026-11-12

At the user's request, ky0jr's PR #28 was merged as `ad8ccd7` and pulled into
main with `--ff-only` after fixing its overlap regressions. The contributor
received the agreed thank-you and explanation; no changes were requested
from them:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/28#issuecomment-6819278037

Periodic channels now participate in the shared periodic matcher used by the
reader and engine. Due DoTs retain rhythm and amount evidence rather than
being overridden by a flat channel fit. Matching heals favor drain channels,
while due Siphon Life ticks retain their identity unless learned channel
amounts fit clearly better. Confirmed, unambiguous channel amounts are retained
for later comparisons. Already-settled reports avoid a second line wait, so
rapid direct channels continue to work.

The original regression probes now retain Siphon Life's identity and next tick,
and display the actual 10-damage DoT report instead of a competing 99-damage
foreign hit. Regressions were observed failing before their fixes. The
17 focused tests passed. The full suite ran 144 tests: 143 passed and the actual
release-archive check was skipped. All 68 periodic pipeline scenarios passed.
The contributor's drain-channel cases and the added engine-only Siphon Life
case passed. Lua 5.1 parse checks and whitespace checks passed.

GitHub validation passed for the merge:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43189256037
The pulled workspace's drain-channel and 68-scenario periodic scripts passed.

Next: run `/reload` and check Drain Life and Drain Soul,
including overlap with Siphon Life and Corruption. In-game validation is
pending. No release was requested.

# Periodic damage merge and local healing follow-up

Updated: 2026-11-12

At the user's request, ameNiku's PR #29 was merged as `07e44e6` and pulled
into main with `--ff-only`. The conflict resolution preserves main's direct
attribution safeguards. GitHub validation passed:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43184533453
The requested thank-you and follow-up explanation were posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/29#issuecomment-6818842622

The local follow-up passes matching-heal evidence explicitly into periodic
candidate scoring, both when the reader fits a report and when the engine
chooses its spell. A draining tick no longer takes a simultaneous non-draining
DoT's identity when the other evidence ties. Without healing evidence, the
existing score is unchanged; read-only fits cannot inherit a previous heal.

Both regressions failed first: wrong displayed icon and ignored healing
evidence during fitting. After the fix, 16 focused tests passed. The full suite
ran 143 tests: 142 passed and the actual release-archive check was skipped.
All 60 periodic Lua scenarios passed, including the contributor's original 58.
Whitespace checks passed. The follow-up is saved locally only; no push or
release was requested for it.

Next: run `/reload` and check overlapping same-school DoTs with a matching
self-heal, along with Serpent Sting's delayed ticks. In-game validation is
pending.

## Periodic damage PR integration

Updated: 2026-11-12

At the user's request, ameNiku's PR #29 is integrated with current main.
The conflict resolution preserves direct-hit confidence, cast consumption,
and target restrictions alongside cross-frame periodic confirmations and
recovery from stale learned values. Duplicate target-history loops from the
automatic merge were removed.

The merged suite ran 143 tests: 142 passed and the actual release-archive
check was skipped. The contributor's 58 periodic scenarios pass. In-game
validation is pending.

Next: pull this merge into the addon workspace, add a failing regression for
same-school draining ticks, and restore healing-aware periodic scoring there.
The user requested this follow-up locally; no release was requested.

# Hunter shot descriptions merged

Updated: 2026-11-12

At the user's request, the adaptive melee-window checkpoint `9c677a1` was
pushed to main. Gamooly's hunter-shot description PR #32 was merged as
`3078189` and pulled with `--ff-only`. A familiar thank-you was posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/32#issuecomment-6809878211

The parser now recognizes Aimed Shot's ranged-damage wording and Multi-Shot's
missile wording as physical direct damage. It retains Hunter's Mark's
non-damaging classification and explicit damage schools. Multi-Shot hits on
other targets remain outside this change. Strict YAGNI review found all four
added parsing checks necessary: removing each breaks its regression test.

The merged main suite ran 142 tests: 141 passed and the actual release-archive
check was skipped. GitHub validation also passed:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43121478549
Installed hunter-description, adaptive melee-window and
miss-attribution regression scripts passed. All 102 runtime files match
Forever by SHA-256, with no destination extras. No release was requested;
public v12.050 predates these hunter-description and melee-window changes.

Next: run `/reload` in Forever and check Aimed Shot and Multi-Shot attribution
on the targeted enemy, plus slow-weapon behavior in solo and group combat.

## Adaptive melee swing window

Updated: 2026-11-12

At the user's request, Gamooly's PR #34 was merged as `f60031f` and pulled
into main with `--ff-only`. The requested thank-you and refinement comment:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/34#issuecomment-6809621903
GitHub validation passed for the merge. The local follow-up is not authorized
for push or release yet.

The follow-up keeps each hand's narrow median-based window when all recent
confirmed delays fit inside it. When a sample falls outside those margins,
that hand retains at least the initial 0.25–0.9 second range from Gamooly's
fix. The aggregate window combines learned hands using the same calculation.
Weapon-speed changes still invalidate that hand's samples. Variable hands
still use a broad window, so group-combat ambiguity is not eliminated.

The new stable-window and real-reader competing-hit regressions failed first.
After the fix, 16 focused tests passed. The full suite ran 141 tests: 140
passed and the actual release-archive check was skipped. Tests preserve the
slow-weapon cases, check final attribution as samples change, ordinary timing
jitter, hand independence, sample reset and a teammate hitting at 0.30 seconds
before the player's learned 0.45-second hit.

All 102 runtime files match Forever by SHA-256, with no extra installed files.
All 70 installed Lua files compile as Lua 5.1. Four installed regression
scripts passed: melee windows, the combat engine including competing hits,
miss attribution, and killing-blow classification/deduplication.

Next: run `/reload` in Forever and check a slow two-hander in solo and group
combat. The adaptive refinement is saved locally only; live validation is
pending. Public v12.050 predates this melee-window change.

## Release v12.050

Updated: 2026-11-12

Release commit `4e49e69` and tag `v12.050` were pushed from main, including
the attribution follow-up `921e3b8`. Both manifests identify v12.050. The
changelog covers killing-blow routing and duplicates, Gamooly's miss attribution
contribution and the follow-up, and the opt-in loot profiler. Restricted
Windfury damage still displays separate amounts; no summation change was made.

Both GitHub validation runs and the CurseForge workflow succeeded:
https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43117600919
The upload response accepted CurseForge file `9566384`. Public processing or
moderation status was not independently verified.

The exact workflow artifact is retained at
`D:/Codex-Temp/msbt-v12.050-release/MikScrollingBattleText-v12.050.zip`.
It contains 102 files, 628,059 compressed bytes and 1,932,696 uncompressed bytes.
All six actual-archive tests passed with no skips. All 70 packaged Lua files
compile as Lua 5.1. Runtime files and binary media match the release source,
apart from expected line endings and LibDeflate comment metadata substitutions.
The profiler, both client manifests, locales, libraries, fonts, sounds and
artwork are present; development files are excluded by the existing .pkgmeta.

The full local suite passed 139 tests with one actual-archive check skipped
before packaging. Whitespace checks passed. Forever's 102 runtime files match
the source, including both v12.050 manifests.

Next: obtain a loot timing capture from a user who experiences the stutter.
Run `/msbt lootprofile`, reproduce for 10–20 seconds, and collect the five
lines from `/msbt lootprofile stop`. The stutter cause is still unconfirmed.

## Miss attribution follow-up

Updated: 2026-11-11

At the user's request, the five local checkpoints through `6d400bc` were pushed
to main. Gamooly's PR #35 was merged as `b4e6c06` and pulled with `--ff-only`.
The requested thank-you and follow-up comment was posted:
https://github.com/VadimTofan/MiksScrollingBattleText/pull/35#issuecomment-6809046602
GitHub validation passed for the merge. No release was requested.

The local follow-up preserves a miss confirmed by a direct-spell line when a
pet or recent ranged shot is present. The ambiguous-miss preference from the
PR remains intact. Candidate ranking now also rejects ranged parries, matching
the final attribution rule so an impossible candidate cannot take a scarce
confirmation. The recent-cast fallback uses the same confirmation rule.

Both regressions failed first and passed after their fixes. Fourteen focused
combat tests passed. The full suite ran 140 tests: 139 passed and the actual
release-archive check was skipped. All 70 installed Lua files compile as Lua
5.1; miss attribution, kill classification/deduplication, and kill presentation
regressions passed against the installed files. All 102 runtime files match
Forever by SHA-256, with no destination extras.

This follow-up is a local checkpoint only; the push authorization covered the
pre-existing changes. Live combat confirmation is still pending.

Next: run `/reload` in Forever and check Hunter's Mark with pet parries, ranged
misses, and confirmed spell misses. The affected-user loot timing report is
still pending.

## Forever runtime sync

Updated: 2026-11-11

The user requested that Forever match this workspace after `/msbt lootprofile`
printed usage. Its profiler file, command handler and manifest entries were
missing. The complete runtime file set selected by the existing `.pkgmeta`
exclusions was synced, replacing earlier partial installs. All 102 runtime
files match by SHA-256, with no extra files in the destination addon folder.
Development files and Git metadata stay in this workspace.

Verification: all 70 installed Lua files compile as Lua 5.1. Five regression
scripts ran against the installed files: profiler, loot integration, profile
command integration, kill classification/deduplication, and kill presentation.
The workspace suite ran 139 tests: 138 passed, one release-archive check skipped.
No push or release was requested.

Next: run `/reload`, start `/msbt lootprofile`, loot for 10–20 seconds, run
`/msbt lootprofile stop`, and collect the five report lines.

## Duplicate killing-blow notifications

Updated: 2026-11-11

A melee kill with no damage report could emit both the normal PARTY_KILL alert
and the delayed killing-swing fallback. Both paths now share a notification
flag on the kill line. Whichever runs first sends the notification; the other
still completes its bookkeeping without displaying another alert. Distinct
kill lines retain independent notifications and the existing NPC/player routing.

The regression test failed first for duplicate notifications. It now covers
NPC and player victims, both timer orders, and a second distinct kill. The full
suite ran 139 tests: 138 passed and the release-archive check was skipped.

The Forever sync check found its reader still matched the version before
player/NPC classification, despite the earlier installation note below. That
file now matches the tested source, including classification and duplicate
prevention. The installed reader passed the same Lua regression test. No push
or release was requested.

Next: run `/reload` in Forever and kill an NPC with a melee finishing blow;
confirm only one notification appears. Live confirmation is still pending.

## Player and NPC killing blows

Updated: 2026-11-11

The approved routing change is implemented on `main` and installed in Forever.
Matched player kills use Player Killing Blows. NPC and unclassified kills share
NPC Killing Blows, including its message, font, color, sound and toggle. The
separate unclassified control and defaults are removed; profile transfer ignores
its obsolete setting. Existing player/NPC settings are retained. The delayed
melee killing-blow fallback follows the same routing. Unclassified PvP kills
also follow the NPC setting.

Victim classification uses public `UnitIsPlayer` and `UnitIsDead` observations
attached to damage reports or player swings. A kill must have one matching
victim in its frame and an observed death. Target epochs and nameplate
generations prevent a later target or recycled token from supplying that
death. Multiple victims, multiple same-frame kill lines, missing APIs, secret
flags, and unavailable death evidence remain unclassified. This is conservative
correlation: the formatted combat-log event still has no direct victim flag,
so not every PvP or NPC kill can be classified.

Verification: regression tests failed first for unknown kills using the generic
setting and separate generic defaults remaining. The full suite ran 139 tests: 138 passed
and the actual release-archive check was skipped. Tests cover target changes,
mixed victims, token reuse, restricted/missing/erroring predicates, delayed
melee alerts, shared NPC/unclassified settings and defaults on both client branches.
Whitespace checks passed. Five runtime files were installed in Forever; only
the killing-blow sections of its presentation file were patched, preserving
its earlier pet-icon difference. Live PvP/NPC testing is still required.

The loot diagnostic checkpoint remains separate and unchanged. Neither it nor
this killing-blow change has been pushed or included in a new release.

Reference: [Blizzard unit predicate declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).

Next: run `/reload` in Forever, enable Player Killing Blows and disable NPC
Killing Blows. Check that NPC and unknown kills stay hidden, then test PvP kills.
The five-line loot timing report is also still pending.

## Loot stutter investigation

Updated: 2026-11-11

Users report stutter when repeatedly clicking corpses with loot, but not empty
corpses. The cause is not confirmed. MSBT has no direct loot-window or mouse
handler. Item notifications do item-info and inventory-count lookups even when
their alert is disabled; counts also run for templates without `%t`. Those
paths remain unchanged so timing can identify the actual cost before a fix.

The approved temporary diagnostic is implemented on `main` and installed in
Forever. After `/reload`, `/msbt lootprofile` starts a capture; spam-loot for
10–20 seconds, then `/msbt lootprofile stop` prints five report lines. Capture
also stops automatically after 30 seconds or 2,000 self-loot parser events.

The header identifies the addon/client build and loot event count. Four rows
report call count, total, average, maximum milliseconds, and errors:
`handler` (full loot callback), `metadata` (item/currency lookup), `count`
(inventory total), and `display` (synchronous notification setup, including
sound). Handler time includes its child phases; do not add the totals together.
The timings exclude chat parsing, later animation frames, GPU work, and other
addons' loot-window or target-change handlers.

Capture is off by default and makes no profiling-clock reads while inactive.
It uses `GetTimePreciseSec`, or `debugprofilestop` without resetting the shared
timer. It does not enable global CPU profiling, change notification decisions,
or retain item data/history in SavedVariables. Captures keep fixed aggregates;
stale timers cannot stop a later capture. Callback results, nil returns, and
errors are preserved.

Verification: new tests failed first for missing capture, command routing,
and manifest integration. The full suite ran 137 tests: 136 passed and the
actual release-archive check was skipped. Whitespace checks passed. The three
installed Lua changes match the tested source; both Forever manifest edits
only add the profiler before LootNotifications and retain version 12.048.
This diagnostic has not been pushed or released, and no live timing capture
has been collected yet.

Next: reproduce the stutter with capture enabled and paste the five report
lines. Use the maximum phase times to select the next investigation.

## Release v12.049

Updated: 2026-11-11

Release commit `3fd11c4` and tag `v12.049` were pushed to origin from `main`.
GitHub validation and the CurseForge release workflow succeeded. The archive
gate passed before upload; CurseForge accepted file ID `9556335`. Public
availability or moderation status has not been independently checked.

Both runtime manifests report 12.049. The changelog covers name/ID aura
rules, native protected-name visibility, the sound limitation, larger font
sizes, and the pet melee icon change since v12.048.

The full suite ran 134 tests: 133 passed, with the actual-archive check skipped
until packaging. The exact workflow ZIP then passed all six archive tests;
all 69 packaged Lua files parsed as Lua 5.1. Both manifest versions and the
native aura runtime match the released source. The ZIP contains 101 files and
is 624,210 bytes. Tests, diagnostics, and development files are excluded;
runtime dependencies, media, localizations, and notices remain included.
Whitespace checks passed and task logs are clean.

Artifact: `D:/Codex-Temp/msbt-v12.049-release/MikScrollingBattleText-v12.049.zip`.

Workflow: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/43011216698

Forever has the five native aura changes from before release preparation,
with its earlier pet-icon and font-size differences preserved. It has not been
replaced with the complete v12.049 archive.

Next: check CurseForge public availability and test the native aura filter in
combat after `/reload` in Forever.

## Aura exclusions by name or ID

Updated: 2026-11-11

Native secret-name filtering is now implemented on `main`. Excluded name
rules use `C_Intl.CompareStrings`, conditional string helpers, normalization,
and native boolean selection to produce an opaque visibility boolean. The
animation renderer uses it to select alpha for both text and icon, including
fades. Lua never branches on the match result or extracts the secret name.
Completed animations release their visibility reference. Missing helpers,
invalid native returns, and selector errors preserve visible notifications.

Secret aura notifications checked against active name exclusions are muted:
sound playback cannot be selected with the secret match result. This also
mutes unrelated secret aura sounds checked by the filter. Numeric exclusions
still require a readable ID; secret names cannot establish a specific rank.
Invisible events still occupy an animation slot until they expire.

Verification: regression tests failed before implementation for native
matching and animation visibility. The full suite ran 134 tests: 133 passed,
with the release archive check skipped. Whitespace checks passed. All five
installed runtime files parse as Lua 5.1; three aura tests also passed against
the installed implementations. Actual combat behavior remains unverified.

The five runtime changes were synced to Forever. Its presentation and display
service files had pre-existing pet-icon and font-size differences, so only
the aura sections were patched there. The other three files match the source
byte-for-byte. A separate installed display test still rejects font sizes
above 38; the same failure was reproduced without the aura changes.

References: [native selector investigation](https://github.com/Questie/Questie/blob/master/docs/forever-object-tooltip-api-audit.md#native-string-based-selection-promising-primitives-unverified-composition),
[secret-capable alpha API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua).

Next: run `/reload` in Forever, exclude an aura by its exact displayed name,
and check that it stays hidden in combat while an unrelated aura stays visible.

## Name and ID rule storage

Adding an aura by name now creates an all-ranks rule. Adding a numeric ID
creates an exact-ID rule. Existing saved rules remain exact-ID rules because
their original input is unknown. Name rows display "all ranks"; ID rows keep
their number. Both rule types retain checkbox states and custom styles through
profile export and import.

Follow-up: name entry no longer requires a successful spell API lookup. If
lookup returns no result, the trimmed name is saved directly for exact display
name matching. This permits unlearned or otherwise unresolved aura names;
users must check their spelling. Numeric IDs still require a valid lookup,
and empty or control-character input is rejected. Regression tests reproduced
the rejection in both resolution and the real options panel before the fix.
The full suite still passes (132 passed, one archive check skipped), and both
follow-up runtime files were synced to Forever with SHA-256 verification.

Either matching exclusion hides the notification. When both matching rules
are enabled, the exact-ID style takes priority. Name-only combat-text notices
can match name rules, but cannot establish an exact rank for ID rules. Hidden
names now use native rendering selection when its helpers are available.

Regression tests failed before implementation for name resolution, the options
row, and profile transfer. The full suite ran 133 tests: 132 passed and the
release archive check was skipped. Whitespace checks passed.

The four changed runtime files were synced to Forever and verified by SHA-256.
In-game behavior has not yet been checked.

## Font size range

Updated: 2026-11-11

Normal and critical font sliders now support sizes 4–100 with one-point steps.
The shared editor applies this range to Master Fonts, scroll areas, and event
overrides. The public display helper accepts the same range. Existing font
inheritance and out-of-range fallback behavior are preserved.

The popup and display regression tests failed before implementation and passed
afterward. The full suite ran 132 tests: 131 passed and the release archive
check was skipped. Whitespace checks passed. The two changed runtime files
were synced to Forever and verified by SHA-256.

Next: run `/reload` in Forever and check larger normal and critical sizes in
Master Fonts. This change has not been included in a new release.

## Previous release: v12.048

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

Release commit `9b61910` and tag `v12.048` were pushed to origin. Both Validate
runs and the CurseForge release workflow completed successfully. The workflow
verified the archive before upload; CurseForge accepted file ID `9550672`.
Public availability or moderation status was not independently checked.

The exact workflow ZIP was downloaded to
`D:/Codex-Temp/msbt-v12.048-release/MikScrollingBattleText-v12.048.zip`.
Its six archive tests passed, all 69 packaged Lua files parsed as Lua 5.1,
and both client manifests report 12.048. The ZIP contains 101 files and is
622,870 bytes. Runtime dependencies, media, and licenses are retained;
tests, diagnostics, and development files are excluded.

Workflow: https://github.com/VadimTofan/MiksScrollingBattleText/actions/runs/42930592192

The Forever installation still has the feature branch version from before
the merge. Next: install v12.048 in Forever and check Windfury bursts and
killing blows in game.

## Pet swing icon: PR #33

Merged Gamooly's pet icon change with the existing unknown-proc handling.
When GetPetIcon supplies a readable icon, pet melee damage and misses use it.
The user accepted the assumption that the API supplies a usable pet icon;
the previously identified downstream no-icon fallback remains unchanged.

PR #33 was approved with the user's thank-you message and merged remotely as
`5cfb8e1`. GitHub validation passed. The merge was pulled into local main while
preserving the separate, unpushed font-size commit. Both the integration and
combined local suites ran 133 tests: 132 passed and the release archive check
was skipped. Whitespace checks passed.

Next: sync the pet icon change to Forever before checking pet hits and misses
in game.
