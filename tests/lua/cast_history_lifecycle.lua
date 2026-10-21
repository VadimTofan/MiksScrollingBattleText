MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local mine = MikSBT.CombatEngine.NewMine()

-- Given old spells and a spell with both an old and a recent cast.
for spell = 1, 1000 do mine:Cast("you", spell, "target", 0) end
mine:Cast("you", 2000, "target", 0)
mine:Cast("pet", 2000, "target", 29)

-- When maintenance runs beyond the old casts' 30-second window.
mine:Tidy(31)

-- Then old spell keys and old records within active histories are released.
assert(mine.casts[1] == nil, "expired spell history was retained")
local count = 0
for _ in pairs(mine.casts) do count = count + 1 end
assert(count == 1, "expired spell keys accumulated")
assert(#mine.casts[2000] == 1 and mine.casts[2000][1].at == 29)
assert(mine.casts[2000][1].caster == "pet")

-- When the final useful cast also expires without being cast again.
mine:Tidy(60)

-- Then the history is empty.
assert(next(mine.casts) == nil)
