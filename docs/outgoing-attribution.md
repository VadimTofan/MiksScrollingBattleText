# Outgoing damage attribution

MSBT separates whether a report belongs to the player or pet from which
spell caused it. A confirmed hit with an unknown or ambiguous spell shows its
number without a spell name, icon, or question mark. Identified spells and
melee attacks retain their icons. Reports with unresolved ownership stay
hidden and are recorded as `unknown`.

| Responsibility | Implementation |
| --- | --- |
| Known spell behavior | `Combat/SpellCatalog.lua`, `Combat/Spells.lua` |
| Confirmation pairing and target lifecycle | `Combat/Reader.lua` |
| Cast outcomes, swings, and periodic state | `Combat/Mine.lua` |
| Events, pet routing, names, and icons | `Components/CombatPresentation.lua` |
| Grouping and native amount rendering | `Components/OutgoingBatcher.lua` |

The catalog adapts the complete direct and periodic spell tables from
[NameplateSCT Reforged](https://github.com/dbspringer/nameplatesct-reforged),
revision `e678a89bb7fe15232e0425c81735779da13d5111`. That source records
Forever data build `1.60.1.70888`. Its MIT license is shipped as
`Combat/LICENSE-NameplateSCTReforged`; its source comments retain unverified
behavior caveats. These are sourced client facts, not a promise that every
spell has been verified in live combat on every subsequent build.

Catalog facts apply only to Forever. They provide schools, direct/periodic
behavior, known intervals and durations, shot and next-swing classifications,
and matching windows. Optional tooltip amounts remain available. Unknown
IDs and other clients retain description-based facts. The axe bleed `21949`
uses its live description; total damage and duration do not establish its
tick interval. Shared rank entries are never mutated by callers.

Matching windows are inference policy, not cooldowns or universal game-data
facts. MSBT retains its observed three-second direct projectile allowance;
explicit source constraints such as Judgement's short window still apply.
The regression suite includes an impact at 2.37 seconds whose confirmation
arrives in an earlier frame. Cast accounting prevents that same cast from
being reused after the late impact.

Normal matching, historical recovery, misses, fitting, and flight checks
share the cast's direct outcome budget and matching window. A target normally
has one direct outcome; an explicit `directHits` fact can describe additional
components. Distinct area targets have independent outcomes. Known area
metadata uses its matching window; legacy secondary-target inference remains
limited to the existing simultaneous-impact window. A target token change
does not reopen spent outcomes. A failed application cannot provide later
periodic identity, while another target or a remaining component stays valid.
Periodic outcomes also share a per-cast, per-target occurrence budget across
normal, historical, and miss matching. A duplicate confirmed report retains
its amount without reusing a tick's name. These budgets follow live DoT cast
links even after ordinary cast history expires.

Consuming a direct impact does not consume the periodic component of a mixed
spell. Unknown spell behavior cannot become periodic evidence merely because
the cast is old. A cooldown is not a display lockout: successful casts and
their supported outcomes govern naming. Additional confirmed hits whose
multiplicity is not known remain visible without reusing a spent name.

A named, unambiguous tick confirms that its periodic-only cast applied to
that target. The same application cannot then compete as a new direct miss.
Initial application misses, other targets, mixed direct/periodic spells, and
ambiguous periodic reservations retain their existing outcome rules.
Ambiguous direct outcomes cannot supply a Windfury candidate tag.

Each confirmed report keeps its original confirmation for timing association.
Exact lines are reused; shared pools do not invent an individual line binding.
Those reports cannot reserve another spare or later line. An omitted context
retains legacy timing association; an explicit missing context suppresses it.
Timing samples use the original evidence within the existing sampling window;
a mixed-time pool cannot supply an exact gap or teach a spell's timing.

Forever automatically shows inferred Windfury icons without a General
checkbox. It decorates only already-owned, unnamed direct physical extras
after complete source accounting. The icon is an estimate; it does not set a
damage spell ID or name. Existing skill-icon visibility settings still apply.

Inference requires one same-frame Weapon or Totem signal, a single target
lifetime, spent native/Stormstrike reservations, and fully accounted own
confirmation slots. Exactly two residual Weapon outcomes or one Totem outcome
are required. Misses count toward that capacity and retain their ordinary
presentation. Combined signals, bleed applications, uncertain recipients,
ambiguous sources, incomplete counts, and exceeded bounds remain undecorated.

Possible proc numbers wait for completion for at most 1.6 seconds. Complete
sources release early; an incomplete source releases the same owned records
without inferred icons. Inferred and plain batches stay separate and avoid a
second proc-collection delay. Profile changes flush pending records plain;
world/engine resets cancel old work under the existing lifecycle rules.
The production stage preserves opaque amounts, ownership, spell IDs, crits,
and event settings. It runs independently of diagnostic capture.

The Forever reader requires confirmation once its dedicated filter is ready,
including before the first log line. Unused direct confirmations following
a melee swing or known physical ability can support delayed weapon-proc
candidates. The existing bounded trigger and report windows still apply.
An active imbue does not prove a proc's identity. Candidate metadata reaches
grouping and diagnostics separately from the named spell ID. It does not
supply a spell icon or name. Confirmed periodic damage can remain visible
without a spell candidate, provided no competing target's periodic evidence
could have supplied its confirmation.

Nameplate keys include their visible generation. Casts, outcomes, swings,
held reports, and callbacks waiting for confirmations follow that lifetime.
Public aliases of the same selected creature can move those references
together when a plate appears. A new creature reusing a token receives a
different key. Forgotten periodic effects retain bounded timing only as
competing evidence; they cannot adopt another target or supply its name.
Pet activity without confirmation cannot establish ownership.
Active and retired channels also remain competing evidence on other targets
until their stop or duration expires. Simultaneous represented targets only
waive that competition when confirmations cover the complete report group.
When confirmations are fewer than reports, equal ownership fits remain
unresolved. Their confirmations cannot be lent to later reports. If all
amounts are confirmed but their direct/periodic roles cannot be assigned,
they remain numeric and unnamed without teaching a rhythm or reopening
possible spell outcomes.

A mixed fire/physical frame with one direct line cannot assume the physical
report used an earlier native swing. The direct line might instead describe
that physical proc, with the normal swing still delayed. A compatible later
normal report must retain its unused swing evidence. Native timing eligibility
and total candidate capacity alone do not establish both reports' ownership.

Readable cast GUIDs join SENT recipient evidence to successful casts and
channel starts. Public target, focus, mouseover, and nameplate aliases are
checked together. Duplicate or unreadable recipients stay uncertain. Older
events with an empty recipient retain the start snapshot; casts without
SENT evidence retain the legacy current-context fallback. Those fallbacks
remain inference rather than proof of the spell's actual victim.

Periodic, channel, historical, and miss matching share conservative identity
rules. Equally plausible identities remain unnamed and do not teach amounts,
schools, or tick timing. Known catalog periods and durations constrain later
reports instead of being replaced by the gap between competing ticks.

MSBT keeps its existing event settings, scrolling areas, sounds, critical
styling, and pet routing. Candidate grouping preserves the one-second window
when Stack Similar Hits is enabled. It separates normal and critical damage,
pets, periodic damage, and ordinary unnamed output. Restricted values reach
native rendering unchanged; Lua does not read, compare, or sum them.

`tests/lua/outgoing_capture_replays.lua` exercises the real catalog, filter,
reader, engine, presentation, and batcher with timings from the live reports.
It covers delayed physical reports, bleed applications/ticks, same-frame
Stormstrike accounting, unconfirmed reports, wrong targets, used lines, and
target departure. Initial and refreshed periodic applications with empty
reports are also covered. The catalogued next-swing test is a conservative
ordering fixture; it does not establish unobserved live Cleave behavior.
Separate tests cover cast budgets, misses, ambiguity, metadata/client
boundaries, public/restricted amounts, and candidate grouping exclusions.

`tests/lua/reader_attribution_lifecycle.lua` covers recipient ambiguity,
target switches, reused plates, late confirmations, same-creature rekeying,
and missing spell identity. `tests/lua/matcher_conservatism.lua` covers
shared ambiguity rules, unconfirmed pets, retired periodic evidence, and
authoritative timing. `tests/lua/recorded_spell_identity.lua` replays a
sanitized subset of the reference project's build 70938 Warlock recording.
Its four pet-target/tooltip variants preserve all 12 confirmed periodic
reports once, retain isolated known identities, and reject names contradicted
by independently checked combat-log labels. This is a fixed-target
regression, not a general accuracy percentage.

Timing and filtered log colors cannot always identify an individual attacker
or distinguish simultaneous spells. Live validation remains necessary,
especially for group combat, changed server behavior, and spells missing
from the catalog. `/msbttrace wf` remains opt-in development instrumentation;
its candidate counts are not proof of actual Windfury proc counts or visible
pixels. The diagnostic files remain excluded from release manifests.

During `/msbttrace wf`, a separate frame records `SPELL_UPDATE_COOLDOWN`
only when event support is positively confirmed. Each burst keeps at most
32 updates with the public spell ID, base spell ID, category, start-recovery
category, item ID, and arrival time. Unreadable fields are omitted; zero and
repeated updates are retained. `targetContext` records the selected target
at arrival, not the spell's victim. These updates never change ownership,
names, damage, or expected proc counts. The event unregisters when capture
stops. Live recordings are needed before using this signal for attribution.

On the swing-tracking experiment branch, `/msbttrace wf` also enables a
parallel accounting ledger. It reserves each observed native swing and the
supported Stormstrike outcome. Optional receipts identify reservations the
existing matcher already spent; accounting never spends them again. Delayed
reports retain the original confirmation frame, and collective confirmations
retain their shared pool instead of inventing individual line assignments.

The report lists matched and unresolved ordinary outcomes, excluded periodic
and known spells, unexplained owned physical outcomes, and unowned or unlinked
reports. Windfury Weapon `439440` and the observed Totem signal `10610` are
recorded separately. Two and one possible extra outcomes are explicit policy
hints, not confirmed grants or proc counts. Combined signals do not identify
which amount belongs to which effect. Missing reports never create outcomes.

Observed Stormstrike casts with unresolved recipients remain untargeted
reservations. They do not borrow the selected target. An owned direct physical
report can preserve its exact confirmation frame when no native swing or cast
matches that frame. These confirmation-only rows show unassigned outcomes and
an unresolved parent; they never attach themselves to the nearest swing.
Same-frame Weapon and Totem signals remain separate family candidates.

Reports also retain public swing durations, cast-recipient observation flags,
and up to eight existing swing-window checks per outcome. Checks capture the
windows before the matcher spends a reservation and explain whether it was
already used, eligible, early, or late. Reading these checks does not change
the windows, learned timing, ownership, or reservation budgets.

The accounting ledger changes no damage ownership, names, icons, values, or
display timing. It stores public metadata only and runs only during
capture. World entry clears its state; stopping capture or the combat engine
disables diagnostic receipts. `Combat/SwingAccounting.lua` remains outside release
manifests and packaging, alongside the other optional diagnostics.
The icon trial has its own receipt flag, so stopping capture does not disable
it. `Combat/WindfuryInference.lua` is a production manifest dependency.
Windfury reports expose `inferredIcon=8232` separately from the unchanged
`identity` field when an inferred icon is handed to presentation.
