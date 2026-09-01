MikSBT = {
	Services = {},
}

local released = {}
local Throttler = dofile("Services/Throttler.lua")
Throttler:Configure({
	release = function(event)
		released[#released + 1] = event
	end,
})

local first = { amount = 100 }
local second = { amount = 50 }

-- Given / When
local firstThrottled, windowStarted =
	Throttler:Queue("Moonfire", first, 1, 10)
local secondThrottled = Throttler:Queue("Moonfire", second, 1, 10.2)
local activeBefore, releasedBefore = Throttler:Tick(0.5)
local activeAfter, releasedAfter = Throttler:Tick(0.5)

-- Then
assert(firstThrottled == false, "first event was unexpectedly throttled")
assert(windowStarted == true, "first event did not start a throttle window")
assert(secondThrottled == true, "repeated event was not throttled")
assert(activeBefore == true and releasedBefore == false,
	"active window ended too early")
assert(activeAfter == false and releasedAfter == true,
	"expired window state differs")
assert(#released == 1 and released[1] == second,
	"queued event was not released")
