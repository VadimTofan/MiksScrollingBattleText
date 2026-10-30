-- Describe: channel attribution follows the channel's lifetime and school.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local descriptions = {
    [1] = "Deals 100 Chaos damage over 2 sec.",
    [2] = "Deals 100 Cosmic damage over 2 sec.",
    [3] = "Heals 100 damage over 2 sec.",
    [4] = "Deals 100 Cosmic damage over 2 sec.",
}
local mine = ns.NewMine(nil, nil, function(spell)
    return ns.ParseSpellDescription(descriptions[spell])
end)

-- Given a damaging channel preceded by its successful-cast event.
mine:Cast("player", 1, "target", 10)
mine:StartChannel("player", 1, "target", 10)

-- When its cast-success event repeats while the channel is active.
mine:Cast("player", 1, "target", 10)

-- Then ordinary cast/DoT guesses cannot outlive the channel.
assert(mine.casts[1] == nil and #mine.pending == 0 and #mine.dots == 0)

-- Given rapid hits reported without Chaos's Holy and Physical bits.
-- When they match the channel's school and target.
local hit = mine:Hit("target", "damage", 124, 10.2, false, true,
    10, false, "direct")
local fit = mine:Fit("target", "damage", 124, 10.2, 10, "direct")

-- Then ownership and identity are available before any DoT rhythm is learned.
assert(hit.who == "you" and hit.spell == 1 and not hit.tick)
assert(fit ~= nil)

-- Given a hit from another school or a confirmed melee hit.
-- When either is considered during the channel.
local otherSchool = mine:Hit("target", "damage", 4, 10.3, false, true,
    10, false, "direct")
local melee = mine:Hit("target", "damage", 127, 10.3, false, true,
    10, false, "swing")

-- Then neither is relabeled as the channel.
assert(otherSchool.spell ~= 1 and melee.spell ~= 1)

-- Given a stop notification preceding the processing of its buffered last hit.
mine:StopChannel("player", 1, 11)

-- When a hit from before the stop and one from after it are processed.
local finalHit = mine:Hit("target", "damage", 127, 10.99, false, true,
    10, false, "direct")
local laterHit = mine:Hit("target", "damage", 127, 11.1, false, true,
    10, false, "direct")

-- Then the final hit is retained and later damage cannot use the old icon.
assert(finalHit.spell == 1 and laterHit.spell ~= 1)
mine:Tidy(12)
assert(next(mine.channels) == nil)

-- Given a healing channel and a damaging pet channel.
mine:StartChannel("player", 3, "target", 12)
mine:StartChannel("pet", 2, "target", 12)

-- When a matching Cosmic hit is received.
local petHit = mine:Hit("target", "damage", 106, 12.2, true, true,
    10, false, "direct")

-- Then healing is excluded and pet ownership is preserved.
assert(mine.channels.you == nil)
assert(petHit.who == "pet" and petHit.spell == 2)

-- Given a missing stop event.
-- When idle maintenance expires old cast state.
mine:Tidy(43)

-- Then the channel cannot retain stale attribution indefinitely.
assert(next(mine.channels) == nil)

-- Given an existing DoT and an active channel with the same school.
mine:Cast("player", 2, "target", 50)
mine:StartChannel("player", 4, "target", 50)

-- When the combat log identifies a hit as periodic damage.
local dotHit = mine:Hit("target", "damage", 106, 51, false, true,
    50, false, "tick")

-- Then the channel must not take the DoT's identity.
assert(dotHit.spell == 2 and dotHit.tick,
    "active channel stole a same-school DoT tick")
print("Channel attribution tests passed")
