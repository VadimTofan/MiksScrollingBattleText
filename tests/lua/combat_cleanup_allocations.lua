MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local mine = MikSBT.CombatEngine.NewMine()

-- Given an active tracker with cast, target and pet timing records.
mine:Cast("you", 101, "target", 0)
mine:Hit("target", "damage", 4, 0, false, false)
mine:Hit("petTarget", "damage", 1, 0, true, false)
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")

-- When frequent combat events repeatedly maintain those records.
for index = 1, 10000 do mine:Tidy(index / 60) end
local allocated = collectgarbage("count") - before
collectgarbage("restart")

-- Then maintenance releases expired records without steady allocation churn.
assert(next(mine.casts) == nil and next(mine.rhythm) == nil)
assert(next(mine.petLast) == nil and #mine.pending == 0 and #mine.dots == 0)
assert(allocated < 32, "cleanup allocated " .. allocated .. " KiB")
