-- Describe: every displayed damage school retains its attribution facts.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine

for _, example in ipairs({
    { name = "Physical", mask = 1 },
    { name = "Holy", mask = 2 },
    { name = "Fire", mask = 4 },
    { name = "Nature", mask = 8 },
    { name = "Frost", mask = 16 },
    { name = "Shadow", mask = 32 },
    { name = "Arcane", mask = 64 },
    { name = "Holystrike", mask = 3 },
    { name = "Flamestrike", mask = 5 },
    { name = "Stormstrike", mask = 9 },
    { name = "Froststrike", mask = 17 },
    { name = "Shadowstrike", mask = 33 },
    { name = "Spellstrike", mask = 65 },
    { name = "Holyfire", mask = 6 },
    { name = "Holystorm", mask = 10 },
    { name = "Holyfrost", mask = 18 },
    { name = "Shadowholy", mask = 34 },
    { name = "Divine", mask = 66 },
    { name = "Firestorm", mask = 12 },
    { name = "Frostfire", mask = 20 },
    { name = "Shadowflame", mask = 36 },
    { name = "Spellfire", mask = 68 },
    { name = "Froststorm", mask = 24 },
    { name = "Shadowstorm", mask = 40 },
    { name = "Spellstorm", mask = 72 },
    { name = "Shadowfrost", mask = 48 },
    { name = "Spellfrost", mask = 80 },
    { name = "Spellshadow", mask = 96 },
    { name = "Elemental", mask = 28 },
    { name = "Cosmic", mask = 106 },
    { name = "Chromatic", mask = 124 },
    { name = "Magic", mask = 126 },
    { name = "Chaos", mask = 127 },
    { name = "Radiant", mask = 6 },
    { name = "Twilight", mask = 34 },
    { name = "Plague", mask = 40 },
    { name = "Astral", mask = 72 },
    { name = "Volcanic", mask = 5 },
}) do
    -- Given a direct attack described with a damage school.
    local text = "Deals (315% of Spell Power) " .. example.name .. " damage."

    -- When the spell description is parsed.
    local facts = ns.ParseSpellDescription(text)

    -- Then its identity can participate in direct damage attribution.
    assert(facts.damages, example.name .. " attack was treated as harmless")
    assert(facts.school == example.mask, example.name .. " school was lost")
    assert(facts.direct and not facts.ticks)

    -- Given those facts in a new tracker.
    local mine = ns.NewMine(nil, nil, function() return facts end)
    mine:Cast("player", 1, "target", 10)

    -- When the direct hit arrives with its confirming spell line.
    local hit = mine:Hit("target", "damage", example.mask, 10.1,
        false, true, 100, false, "direct")

    -- Then the spell owns its damage, including physical-school abilities.
    assert(hit.who == "you" and hit.spell == 1 and not hit.melee,
        example.name .. " direct damage lost its attribution")

    -- Given a spell dealing the same school's damage over time.
    text = "Deals 100 " .. example.name .. " damage over 2 sec."

    -- When its description is parsed.
    facts = ns.ParseSpellDescription(text)

    -- Then periodic damage and its school are both retained.
    assert(facts.damages and facts.school == example.mask)
    assert(facts.ticks and not facts.direct)
    assert(facts.total == 100 and facts.duration == 2)

    -- Given the periodic spell in a separate tracker.
    mine = ns.NewMine(nil, nil, function() return facts end)
    mine:Cast("player", 2, "target", 20)

    -- When a confirmed periodic hit arrives.
    hit = mine:Hit("target", "damage", example.mask, 21,
        false, true, 50, false, "tick")

    -- Then the same school also supports periodic spell attribution.
    assert(hit.who == "you" and hit.spell == 2 and hit.tick,
        example.name .. " periodic damage lost its attribution")
end

-- Given a harmless ability.
local text = "Forces the target to speak in Demonic."

-- When the description is parsed.
local facts = ns.ParseSpellDescription(text)

-- Then the harmless spell must not claim outgoing damage.
assert(not facts.damages)
print("Spell damage school tests passed")
