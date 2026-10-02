MikSBT = { Services = {} }
local Throttler = dofile("Services/Throttler.lua")
local released = {}
Throttler:Configure({release = function(event)
	released[#released + 1] = event
end})

-- Given many distinct spells with no more events queued.
for index = 1, 1000 do
	Throttler:Queue("Spell" .. index, {}, 1, 10)
end

-- When their windows expire.
local active = Throttler:Tick(1, 11)

-- Then no inactive spell keys remain or require another tick.
assert(next(Throttler.windows) == nil, "expired throttle keys remain")
assert(not active, "empty throttler kept its update frame active")

-- Given a repeated event just before the original window ends.
local event = {amount = 20}
Throttler:Queue("Moonfire", {}, 1, 20)
Throttler:Tick(0.8, 20.8)
Throttler:Queue("Moonfire", event, 1, 20.8)

-- When the original window releases the repeated event.
local stillActive, didRelease = Throttler:Tick(0.2, 21)

-- Then the recent-event timing survives until its own expiry.
assert(didRelease and released[1] == event, "queued event was not released")
assert(stillActive, "recent throttle timing was discarded too early")
local throttled = Throttler:Queue("Moonfire", {amount = 30}, 1, 21.1)
assert(throttled, "event shortly after a flush bypassed throttling")
Throttler:Tick(1, 22.1)
assert(next(Throttler.windows) == nil, "completed throttle history remains")
