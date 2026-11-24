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
