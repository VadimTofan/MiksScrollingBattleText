MikSBT = {
	Components = {},
}

local now = 10
local SelfHealTracker = dofile("Components/SelfHealTracker.lua")
local tracker = SelfHealTracker:New({
	getTime = function()
		return now
	end,
	matchWindow = 1,
	tolerance = 1,
})

-- Given
tracker:Record(100)

-- When / Then
assert(tracker:Consume(101), "tolerated self-heal amount did not match")
assert(not tracker:Consume(101), "self-heal amount was consumed twice")

-- Given an expired self-heal
tracker:Record(200)
now = 12

-- When / Then
assert(not tracker:Consume(200), "expired self-heal amount matched")

-- Given a stored self-heal
tracker:Record(300)
tracker:Reset()

-- When / Then
assert(not tracker:Consume(300), "reset retained a self-heal amount")
