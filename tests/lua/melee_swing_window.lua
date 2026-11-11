-- Describe: the learned swing window stays open for a slow weapon's hits.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local mine = ns.NewMine(nil, nil, function() end)

-- A swing and its hit, paired by the swing's own line as the reader does.
local function PairedSwing(at, delay)
    mine:Swing("main", "target", at, 3.3)
    local swing = mine:SwingsBefore("target", at + delay)[1]
    assert(swing, "no swing to pair " .. delay .. " s after it")
    mine.pairedSwing = swing
    return mine:Hit("target", "damage", 1, at + delay, false, true, 40, false, "swing")
end

-- Given a two-hander whose hits came 0.47, 0.57 and 0.73 s after its swings.
for index, delay in ipairs({ 0.467, 0.570, 0.729 }) do
    local hit = PairedSwing(10 + index * 3.3, delay)
    assert(hit.who == "you" and hit.melee)
end
assert(math.abs(mine:SwingDelay("main") - 0.570) < 0.001)

-- When the next hits come at the other delays seen with that weapon.
for index, delay in ipairs({ 0.466, 0.364, 0.730 }) do
    local at = 30 + index * 3.3
    local hit = PairedSwing(at, delay)

    -- Then each keeps its melee attribution as the samples change.
    assert(hit.who == "you" and hit.melee,
        "a hit " .. delay .. " s after its swing lost its attribution")
end

-- When the window is asked for, with a hand and without.
local early, late = mine:MeleeWindow("main")
local anyEarly, anyLate = mine:MeleeWindow()

-- Then it is no narrower than before anything was learned.
assert(early <= 0.25 and late >= 0.9)
assert(anyEarly <= 0.25 and anyLate >= 0.9)

-- Given a hit long after a swing.
mine:Swing("main", "target", 60, 3.3)

-- When it comes past both the usual and the delayed window, then it is not that swing's.
assert(#mine:SwingsBefore("target", 62.5) == 0)

-- Given a weapon whose three confirmed delays are stable.
mine = ns.NewMine(nil, nil, function() end)
for index = 1, 3 do
    local hit = PairedSwing(70 + index * 3.3, 0.45)
    assert(hit.who == "you" and hit.melee)
end

-- When the learned window is requested for its hand and for any hand.
early, late = mine:MeleeWindow("main")
anyEarly, anyLate = mine:MeleeWindow()

-- Then stable timing keeps the original tight window.
assert(math.abs(early - 0.35) < 0.001 and math.abs(late - 0.60) < 0.001,
    "stable timing was widened without evidence of variable delays")
assert(math.abs(anyEarly - early) < 0.001
    and math.abs(anyLate - late) < 0.001)

-- Given small timing variation that fits within the learned margins.
mine.swingLags.main = { 0.44, 0.45, 0.46 }

-- When that hand's window is requested again.
early, late = mine:MeleeWindow("main")

-- Then ordinary jitter does not force the broad initial range.
assert(math.abs(early - 0.35) < 0.001 and math.abs(late - 0.60) < 0.001)

-- Given an off-hand whose confirmed delays vary outside its tight window.
mine.swingLags.off = { 0.467, 0.570, 0.729 }

-- When each hand and the aggregate window are requested.
local mainEarly, mainLate = mine:MeleeWindow("main")
local offEarly, offLate = mine:MeleeWindow("off")
anyEarly, anyLate = mine:MeleeWindow()

-- Then only the variable hand widens; the aggregate includes both hands.
assert(math.abs(mainEarly - 0.35) < 0.001
    and math.abs(mainLate - 0.60) < 0.001)
assert(offEarly <= 0.25 and offLate >= 0.9)
assert(anyEarly <= offEarly and anyLate >= offLate)

-- Given a different main-hand weapon speed.
mine:Swing("main", "target", 90, 1.5)

-- When its samples have been invalidated by the weapon change.
early, late = mine:MeleeWindow("main")

-- Then the unlearned hand uses the initial window again.
assert(early == 0.25 and late == 0.9)
