# Outgoing damage attribution

MSBT separates whether a report belongs to the player or pet from which
spell caused it. A confirmed hit can remain visible with no spell name and
a generic icon. Reports with unresolved ownership stay hidden; they are
recorded as `unknown`, rather than being described as another player's hit.

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

Consuming a direct impact does not consume the periodic component of a mixed
spell. Unknown spell behavior cannot become periodic evidence merely because
the cast is old. A cooldown is not a display lockout: successful casts and
their supported outcomes govern naming. Additional confirmed hits whose
multiplicity is not known remain visible without reusing a spent name.

The Forever reader requires confirmation once its dedicated filter is ready,
including before the first log line. Unused direct confirmations following
a melee swing or known physical ability can support delayed weapon-proc
candidates. The existing bounded trigger and report windows still apply.
An active imbue does not prove a proc's identity. Candidate metadata reaches
grouping and diagnostics separately from the spell ID used for names/icons.
Neither a candidate nor a guessed source supplies an authoritative proc name.

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

Timing and filtered log colors cannot always identify an individual attacker
or distinguish simultaneous spells. Live validation remains necessary,
especially for group combat, changed server behavior, and spells missing
from the catalog. `/msbttrace wf` remains opt-in development instrumentation;
its candidate counts are not proof of actual Windfury proc counts or visible
pixels. The diagnostic files remain excluded from release manifests.
