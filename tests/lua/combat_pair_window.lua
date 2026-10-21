MikSBT = { CombatEngine = { Timer = {} } }
GetTime = function() return 10 end
dofile("Combat/Reader.lua")
local ns = MikSBT.CombatEngine
local originalSort = table.sort
local sorts = 0
table.sort = function(values)
    sorts = sorts + 1
    return originalSort(values)
end

local function Sample(gap)
    local record = { event = "damage", result = { spell = 101 } }
    ns.reader.logLines = {{ source = "mine", at = 10 - gap }}
    ns.OnYourHit(record, 10)
end

-- Given too few timing samples to estimate the matching window.
for index = 1, 7 do Sample(0.01) end

-- When matching is requested before enough evidence exists.
local fallback = ns.PairWindow()

-- Then the original default window is preserved without sorting.
assert(fallback == 0.1 and sorts == 0)

-- Given enough timing samples and many hits using the same samples.
Sample(0.01)

-- When the matching window is queried repeatedly.
for index = 1, 1000 do
    assert(math.abs(ns.PairWindow() - 0.024) < 0.000001)
end

-- Then unchanged samples are sorted only once.
assert(sorts == 1, "unchanged samples were sorted " .. sorts .. " times")

-- When new samples replace the old median.
for index = 1, 30 do Sample(0.04) end
local updated = ns.PairWindow()

-- Then the estimate updates without changing sample arrival order.
assert(math.abs(updated - 0.084) < 0.000001)
assert(#ns.reader.gaps == 30 and sorts == 2)
assert(math.abs(ns.reader.gaps[1] - 0.04) < 0.000001)
table.sort = originalSort

-- When the reader stops and starts a fresh session.
ns.StopReader()

-- Then the old matching estimate is discarded.
assert(ns.PairWindow() == 0.1)
