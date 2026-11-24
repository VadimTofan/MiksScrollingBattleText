-- Describe: verified metadata supplies identity facts only on Forever.
local locale = "enUS"
local descriptions = {
    [133] = "Inflicts 90 to 110 Fire damage.",
    [116] = "Causes 50 Fire damage over 20 sec.",
    [21949] = "Wounds the target causing them to bleed for 210 damage over 7 sec.",
}
local function Load(forever, catalog, classes)
    MikSBT = {
        CombatEngine = { classRules = {} },
        Compatibility = { Client = { isForever = forever } },
    }
    local ns = MikSBT.CombatEngine
    ns.Text = function(value)
        return type(value) == "string" and value ~= ""
    end
    ns.Bool = function(value) return type(value) == "boolean" end
    GetLocale = function() return locale end
    C_Spell = {
        GetSpellDescription = function(spell) return descriptions[spell] end,
        IsSpellHelpful = function(spell) return spell == 20473 end,
    }
    for _, class in ipairs(classes or {}) do
        dofile("Combat/Classes/" .. class .. ".lua")
    end
    if catalog then
        local available = io.open("Combat/SpellCatalog.lua", "r")
        assert(available, "verified spell catalog module is missing")
        available:close()
        dofile("Combat/SpellCatalog.lua")
    end
    dofile("Combat/Spells.lua")
    return ns
end

-- Given a Fireball tooltip that omits its periodic component.
local ns = Load(true, true)

-- Describe: catalogued bolts retain MSBT's observed long projectile flights.
dofile("Combat/Mine.lua")
for _, example in ipairs({ { spell = 116, school = 16 },
    { spell = 686, school = 32 } }) do
    -- Given a real catalogued cast with no consumed direct impact.
    local tracker = ns.NewMine(function() return nil end,
        function() end, ns.SpellFacts)
    tracker:Cast("player", example.spell, "target", 10)

    -- When its own confirmed impact arrives at the observed +2.37 seconds.
    local impact = tracker:Hit("target", "damage", example.school,
        12.37, false, true, nil, false, "direct")

    -- Then the catalog must preserve the identity throughout that flight.
    assert(impact.who == "you" and impact.spell == example.spell,
        "catalog window rejected a confirmed +2.37 second projectile")

    -- Given the original cast's impact is now accounted for.
    -- When a second confirmed same-school report follows inside the window.
    local later = tracker:Hit("target", "damage", example.school,
        12.5, false, true, nil, false, "direct")

    -- Then ownership can survive without reusing the consumed cast identity.
    assert(later.who == "you" and later.spell == nil,
        "late impact identity was reused for another confirmed report")
end

-- When metadata and tooltip facts are combined.
local fireball = ns.SpellFacts(133)

-- Then verified identity facts win and optional damage amounts remain.
assert(fireball.direct and fireball.ticks and fireball.school == 4)
assert(fireball.period == 2 and fireball.duration == 8)
assert(fireball.travels and not fireball.area and fireball.window == 3)
assert(fireball.low == 90 and fireball.high == 110)
assert(fireball.source == "nameplatesct-reforged")
assert(fireball.sourceBuild == "1.60.1.70888")

-- Given spells with distinct verified cast and shot semantics.
-- When their normalized catalog facts are requested.
local judgement = ns.SpellFacts(20271)
local strike = ns.SpellFacts(78)
local shoot = ns.SpellFacts(5019)
local corruption = ns.SpellFacts(172)
local volley = ns.SpellFacts(1510)

-- Then all routing fields retain the source meanings.
assert(judgement.window == 0.2 and judgement.direct and not judgement.ticks)
assert(strike.nextSwing and strike.school == 1)
assert(shoot.shot and shoot.learnsSchool and shoot.school == nil)
assert(shoot.window == 2.5)
assert(corruption.ticks and not corruption.direct and corruption.period == 3)
assert(volley.area and volley.travels and not volley.direct)
assert(ns.SpellFacts(1328618).school == 1, "Forever-only rank missing")
assert(ns.SpellFacts(3110).school == 4, "pet damage spell missing")

-- Given a stale description and a spell that can also heal friends.
-- When verified direct-only metadata is combined with optional facts.
local stale = ns.SpellFacts(116)
local holyShock = ns.SpellFacts(20473)

-- Then absent periodic fields and harmful capability remain authoritative.
assert(stale.school == 16 and stale.direct and not stale.ticks)
assert(stale.duration == nil and stale.period == nil)
assert(holyShock.damages and holyShock.helpful ~= true)

-- Given a consumer that changes a returned metadata record.
local first = ns.CatalogSpellFacts(133)
first.school = 1

-- When the catalog is read again.
local second = ns.CatalogSpellFacts(133)

-- Then rank-shared source records were not mutated.
assert(second.school == 4 and ns.CatalogSpellFacts(143).school == 4)

-- Given an unknown periodic-only axe bleed.
-- When tooltip fallback supplies its facts.
local bleed = ns.SpellFacts(21949)

-- Then it remains periodic-only without an invented tick interval.
assert(bleed.ticks and bleed.direct == false and bleed.school == 1)
assert(bleed.duration == 7 and bleed.total == 210 and bleed.period == nil)
assert(bleed.source == nil)

-- Given a non-English locale with no available spell description.
locale = "deDE"
ns = Load(true, true)

-- When a verified spell is requested.
local frostbolt = ns.SpellFacts(116)

-- Then metadata needs no tooltip or localization to establish its facts.
assert(frostbolt.school == 16 and frostbolt.direct and not frostbolt.ticks)

-- Given the shared catalog alone, when asking for an ability adjustment,
-- then the catalog must have no class-specific override of its own.
assert(ns.CatalogSpellFacts(20375) == nil, "the catalog still owns seal rules")
assert(ns.CatalogSpellFacts(5143) == nil, "the catalog still owns Arcane Missiles rules")

-- Given each class can load independently, when its spells are queried,
-- then only its adjustments are available and their facts stay locale-neutral.
local paladin = Load(true, true, { "Paladin" })
local seal = paladin.SpellFacts(20375)
assert(seal.helpful and not seal.damages and seal.weaponProc == "seal")
assert(paladin.CatalogSpellFacts(5143) == nil)

local mage = Load(true, true, { "Mage" })
local missiles = mage.SpellFacts(5143)
assert(missiles.direct and missiles.school == 64 and not missiles.ticks)
assert(mage.CatalogSpellFacts(20375) == nil)

-- When a caller changes the returned record, the class rule remains intact.
local copy = mage.CatalogSpellFacts(5143)
copy.school = 1
assert(mage.CatalogSpellFacts(5143).school == 64)
assert(mage.CatalogSpellFacts(25345).school == 64)

-- Given each class's module, when queued strikes are looked up,
-- then only the owning class supplies the special rank list.
local queued = Load(true, true, { "Warrior", "Druid", "Hunter" }).classRules
for _, example in ipairs({ { "WARRIOR", 78, 25286 },
    { "DRUID", 6807, 9881 }, { "HUNTER", 2973, 14266 } }) do
    local rules = queued[example[1]].queuedStrikes
    assert(rules and rules[example[2]] and rules[example[3]],
        "missing class-owned queued strike ranks for " .. example[1])
end
assert(not queued.WARRIOR.queuedStrikes[6807])
assert(not queued.DRUID.queuedStrikes[2973])
assert(not queued.HUNTER.queuedStrikes[78])
assert(queued.HUNTER.rangedAttackSpell == 75)
assert(queued.HUNTER.targetlessHealRecipients[136] == "pet")

-- Given the class rules on Forever with no English tooltip.
local classes = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue",
    "Shaman", "Warlock", "Warrior" }
ns = Load(true, true, classes)
dofile("Combat/Mine.lua")
local function CastAt(spell, key, uncertain)
    local tracker = ns.NewMine(function() return nil end, function() end,
        ns.SpellFacts)
    tracker:Cast("player", spell, key, 10, uncertain)
    return tracker
end

local function DirectHit(tracker, key, school, at, kind)
    return tracker:Hit(key, kind or "damage", school, at, false, true, nil,
        false, "direct")
end

-- When a capped attack produces distinct confirmed outcomes in its window.
for _, example in ipairs({ { 9908, 1, 3, 10.1 }, { 2643, 1, 3, 10.1 },
    { 10605, 8, 3, 10.1 }, { 11581, 1, 4, 10.1 }, { 1680, 1, 4, 10.1 } }) do
    local spell, school, cap, impactAt = unpack(example)
    local tracker = CastAt(spell, "target1")
    assert(DirectHit(tracker, "target1", school, 10.05).spell == spell)
    for index = 2, cap do
        local hit = DirectHit(tracker, "target" .. index, school, impactAt)
        assert(hit.who == "you" and hit.spell == spell,
            "valid secondary target lost spell " .. spell)
    end

    -- Then a further confirmed report keeps its damage without that identity.
    local extra = DirectHit(tracker, "extra", school, impactAt)
    assert(extra.who == "you" and extra.spell == nil,
        "cast exceeded its target cap for " .. spell)

    -- A multi-target spell cannot satisfy a single-outcome fallback.
    local known = CastAt(spell, "target")
    assert(known:MixedFrameDirectSchool("target", school, 4, 10) == nil)
    local hidden = CastAt(spell, nil, true)
    assert(hidden:UntargetedDirectCandidate("target", school, 10.1) == nil)
end

-- Given either Mutilate weapon can miss.
local mutilate = CastAt(399956, "target")

-- When the off-hand damage follows a main-hand miss.
assert(DirectHit(mutilate, "target", 1, 10.1, "miss").spell == 399956)
assert(DirectHit(mutilate, "target", 1, 10.11).spell == 399956,
    "Mutilate lost the off-hand result")

-- Then a third confirmed report cannot reuse Mutilate.
local extra = DirectHit(mutilate, "target", 1, 10.12)
assert(extra.who == "you" and extra.spell == nil)

-- Given area casts with no readable target.
for _, example in ipairs({ { 10202, 64 }, { 10318, 2 }, { 27801, 2 } }) do
    local spell, school = unpack(example)
    local facts = ns.SpellFacts(spell)
    assert(facts.area and facts.school == school and facts.direct)
    local hidden = CastAt(spell, nil, true)

    -- When only a targetless single-target fallback is available.
    assert(hidden:UntargetedDirectCandidate("target", school, 10.1) == nil)

    -- Then nearby confirmed hits still get the spell, within the area window.
    local known = CastAt(spell, "target")
    assert(DirectHit(known, "other", school, 10.1).spell == spell)
    local late = DirectHit(known, "late", school, 10.5)
    assert(late.who == "you" and late.spell == nil,
        "nearby area attack took a later report for " .. spell)
end

-- Given a localized Drain Life channel and a tracked Siphon Life on the target.
local drain = ns.SpellFacts(11700)
assert(drain.leech and drain.ticks and drain.school == 32 and drain.period == 1)
local siphon = 18881
local warlock = CastAt(siphon, "target")
warlock.amounts[siphon] = { n = 1, [20] = true }
warlock:StartChannel("player", 11700, "target", 11)

-- When both can produce a heal but a due tick matches Siphon Life's amount.
local healedTick = warlock:Hit("target", "damage", 32, 13, false, true, 20,
    false, "tick", true)

-- Then the established draining DoT retains its identity in this locale.
assert(healedTick.who == "you" and healedTick.spell == siphon,
    "Drain Life took a localized Siphon Life tick")
assert(Load(false, true, classes).SpellFacts(11700) == nil)

-- Given a different client and an old harness without the optional catalog.
locale = "enUS"
for _, context in ipairs({ { false, true }, { true, false } }) do
    ns = Load(context[1], context[2])

    -- When the same Fireball description is read.
    local fallback = ns.SpellFacts(133)

    -- Then existing tooltip behavior remains available without Forever rows.
    assert(fallback.direct and not fallback.ticks and fallback.period == nil)
    assert(fallback.source == nil)
end
