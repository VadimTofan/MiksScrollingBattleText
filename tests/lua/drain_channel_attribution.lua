-- Describe: channels whose hits the log reports as periodic ticks (Drain
-- Life, Drain Soul) keep their spell instead of being hidden as others'.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local DRAIN_LIFE, DRAIN_SOUL, CORRUPTION, ARCANE_MISSILES = 689, 1120, 172, 5143
local SHADOW, ARCANE = 32, 64
local descriptions = {
    [DRAIN_LIFE] = "Transfers 10 health every 1 sec from the target to the caster. Lasts 5 sec.",
    [DRAIN_SOUL] = "Drains the soul of the target, causing 55 Shadow damage over 15 sec. If the target dies while being drained, the caster receives a Soul Shard.",
    [CORRUPTION] = "Corrupts the target, causing 40 Shadow damage over 12 sec.",
    [ARCANE_MISSILES] = "Launches Arcane Missiles at the enemy, causing 26 Arcane damage each second for 3 sec.",
}
local function NewMine()
    return ns.NewMine(nil, nil, function(spell)
        return ns.ParseSpellDescription(descriptions[spell])
    end)
end

-- Given Drain Life channeled at the target.
local mine = NewMine()
mine:Cast("player", DRAIN_LIFE, "target", 10)
mine:StartChannel("player", DRAIN_LIFE, "target", 10)

-- When its ticks arrive with periodic lines, with and without a matching heal.
local healed = mine:Hit("target", "damage", SHADOW, 11, false, true, 10, false, "tick", true)
local unhealed = mine:Hit("target", "damage", SHADOW, 12, false, true, 10, false, "tick", nil)
local fit = mine:Fit("target", "damage", SHADOW, 12, 10, "tick")

-- Then both are yours, shown as Drain Life ticks.
assert(healed.who == "you" and healed.spell == DRAIN_LIFE and healed.tick, "healed Drain Life tick hidden")
assert(unhealed.who == "you" and unhealed.spell == DRAIN_LIFE and unhealed.tick, "Drain Life tick hidden")
assert(fit ~= nil, "Drain Life tick did not fit")

-- Given Drain Soul channeled at the target.
mine = NewMine()
mine:Cast("player", DRAIN_SOUL, "target", 20)
mine:StartChannel("player", DRAIN_SOUL, "target", 20)

-- When a periodic Shadow tick arrives during the channel and one after it stops.
local soulTick = mine:Hit("target", "damage", SHADOW, 23, false, true, 12, false, "tick")
mine:StopChannel("player", DRAIN_SOUL, 24)
local afterStop = mine:Hit("target", "damage", SHADOW, 25, false, true, 12, false, "tick")

-- Then the channel's tick is Drain Soul's and later damage is not.
assert(soulTick.who == "you" and soulTick.spell == DRAIN_SOUL and soulTick.tick, "Drain Soul tick hidden")
assert(afterStop.spell ~= DRAIN_SOUL, "stopped channel kept claiming ticks")

-- Given Drain Soul and a Corruption whose rhythm is known.
mine = NewMine()
mine:Cast("player", CORRUPTION, "target", 30)
mine:Hit("target", "damage", SHADOW, 33, false, true, 7, false, "tick")
mine:Hit("target", "damage", SHADOW, 36, false, true, 7, false, "tick")
mine:StartChannel("player", DRAIN_SOUL, "target", 36.5)

-- When Corruption ticks on its beat and Drain Soul ticks between beats.
local corruptionTick = mine:Hit("target", "damage", SHADOW, 39, false, true, 7, false, "tick")
local drainTick = mine:Hit("target", "damage", SHADOW, 39.5, false, true, 12, false, "tick")

-- Then each tick keeps its own spell.
assert(corruptionTick.spell == CORRUPTION, "Drain Soul took Corruption's tick")
assert(drainTick.who == "you" and drainTick.spell == DRAIN_SOUL, "Drain Soul tick lost beside Corruption")

-- Given Drain Life and a Corruption due on the same beat.
mine = NewMine()
mine:Cast("player", CORRUPTION, "target", 40)
mine:Hit("target", "damage", SHADOW, 43, false, true, 7, false, "tick")
mine:Hit("target", "damage", SHADOW, 46, false, true, 7, false, "tick")
mine:StartChannel("player", DRAIN_LIFE, "target", 48)

-- When the healed tick and the unhealed tick land together.
local leechTick = mine:Hit("target", "damage", SHADOW, 49, false, true, 10, false, "tick", true)
local dotTick = mine:Hit("target", "damage", SHADOW, 49, false, true, 7, false, "tick", nil)

-- Then the heal decides which is Drain Life's.
assert(leechTick.spell == DRAIN_LIFE, "healed tick went to Corruption")
assert(dotTick.spell == CORRUPTION, "Corruption tick went to Drain Life")

-- Given Arcane Missiles, a channel whose hits are not periodic.
mine = NewMine()
mine:Cast("player", ARCANE_MISSILES, "target", 60)
mine:StartChannel("player", ARCANE_MISSILES, "target", 60)

-- When a direct hit arrives.
local missile = mine:Hit("target", "damage", ARCANE, 61, false, true, 26, false, "direct")

-- Then the existing channel attribution still applies.
assert(missile.who == "you" and missile.spell == ARCANE_MISSILES and not missile.tick)

-- Given a due Siphon Life tick beside an active Drain Life channel.
local SIPHON_LIFE = 18265
mine = ns.NewMine(function(field, spell)
    if spell == SIPHON_LIFE then
        if field == "school" then return SHADOW end
        if field == "direct" then return 2 end
        if field == "period" then return 3 end
    end
end, nil, function()
    return { damages = true, school = SHADOW, ticks = true,
        direct = false, leech = true }
end)
mine:Cast("player", SIPHON_LIFE, "target", 70)
mine.amounts[SIPHON_LIFE] = { n = 1, [20] = true }
mine:StartChannel("player", DRAIN_LIFE, "target", 71)

-- When the established draining DoT produces its matching heal.
local siphonTick = mine:Hit("target", "damage", SHADOW, 73,
    false, true, 20, false, "tick", true)

-- Then Drain Life cannot replace that DoT or leave its rhythm unadvanced.
assert(siphonTick.spell == SIPHON_LIFE, "channel stole a draining DoT tick")
assert(mine:Dots()[1].next == 76, "draining DoT rhythm did not advance")

print("Drain channel attribution tests passed")
