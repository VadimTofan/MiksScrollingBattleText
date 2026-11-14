MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local mine = MikSBT.CombatEngine.NewMine()

-- Given abandoned targets and recently active target and pet timings.
for index = 1, 1000 do
    mine.rhythm["target" .. index] = { [4] = { last = 0, interval = 1 } }
    mine.petLast["pet" .. index] = 0
end
mine.rhythm.active = { [4] = { last = 99, interval = 1 } }
mine.petLast.activePet = 99.5
mine:Rekey("active", "nameplate1")

-- When normal maintenance runs after the abandoned timings expire.
mine:Tidy(100)

-- Then abandoned keys are released while useful timings survive.
assert(mine.rhythm.target1 == nil, "expired target rhythm was retained")
assert(mine.petLast.pet1 == nil, "expired pet timing was retained")
local rhythmCount, petCount = 0, 0
for _ in pairs(mine.rhythm) do rhythmCount = rhythmCount + 1 end
for _ in pairs(mine.petLast) do petCount = petCount + 1 end
assert(rhythmCount == 1 and mine.rhythm.nameplate1)
assert(petCount == 1 and mine.petLast.activePet == 99.5)

-- When recent hits continue on the rekeyed target.
mine:Hit("nameplate1", "damage", 4, 100, false, false)
local result = mine:Hit("nameplate1", "damage", 4, 101, false, false)

-- Then a cached rhythm still cannot establish ownership without confirmation.
assert(result.who == "unknown", "cached rhythm established false ownership")
