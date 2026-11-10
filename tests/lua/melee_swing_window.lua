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
    mine:Swing("main", "target", at, 3.3)

    -- Then each still finds its swing.
    assert(#mine:SwingsBefore("target", at + delay) == 1,
        "a hit " .. delay .. " s after its swing lost it")
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
