-- Describe: opt-in loot timing uses bounded aggregates and preserves calls.
MikSBT = { Components = {} }
local source = assert(io.open("Components/LootProfiler.lua", "rb"))
local Profiler = assert(loadstring(source:read("*a")))()
source:close()
local milliseconds, clockReads = 0, 0
local messages, timers = {}, {}
local profiler = Profiler:New({
	getMilliseconds = function()
		clockReads = clockReads + 1
		return milliseconds
	end,
	getTime = function() return milliseconds / 1000 end,
	after = function(delay, callback)
		timers[#timers + 1] = { delay = delay, callback = callback }
	end,
	print = function(message) messages[#messages + 1] = message end,
	getContext = function() return "test client" end,
})
local function Pack(...) return { n = select("#", ...), ... } end

-- Given profiling has never been enabled.
-- When a timed function returns nils and multiple values.
local values = Pack(profiler:Measure("metadata", function()
	return nil, "link", 1, nil
end))
-- Then its return values survive without any clock, timer or chat work.
assert(values.n == 4 and values[1] == nil and values[2] == "link")
assert(values[3] == 1 and values[4] == nil)
assert(clockReads == 0 and #timers == 0 and #messages == 0)

-- Given an explicit capture with nested item, count and display work.
assert(profiler:Start())
assert(timers[1].delay == 30, "capture did not get a 30-second limit")
-- When a profiled callback returns nils, then the active wrapper preserves them.
values = Pack(profiler:Measure("metadata", function()
	return nil, "link", 1, nil
end))
assert(values.n == 4 and values[1] == nil and values[2] == "link")
assert(values[3] == 1 and values[4] == nil)
-- When a complete loot handler calls each native boundary.
profiler:Measure("handler", function()
	profiler:Measure("metadata", function() milliseconds = milliseconds + 3 end)
	profiler:Measure("count", function() milliseconds = milliseconds + 7 end)
	profiler:Measure("display", function() milliseconds = milliseconds + 2 end)
end)
profiler:Stop()
-- Then a five-line aggregate reports the measured costs and context.
assert(#messages == 6, "expected one start message and five report lines")
assert(messages[2]:find("test client", 1, true))
assert(messages[3]:find("handler: calls=1 total=12.000ms", 1, true))
assert(messages[4]:find("metadata: calls=2 total=3.000ms", 1, true))
assert(messages[5]:find("count: calls=1 total=7.000ms", 1, true))
assert(messages[6]:find("display: calls=1 total=2.000ms", 1, true))

-- Given profiling is active and a native call fails.
profiler:Start()
-- When that error propagates through a measured callback.
local ok, failure = pcall(function()
	profiler:Measure("metadata", function() error("original item failure", 0) end)
end)
profiler:Stop()
-- Then timing records the error and preserves its original message.
assert(not ok and failure == "original item failure")
assert(messages[#messages - 2]:find("errors=1", 1, true))

-- Given a stopped capture followed by a new one.
profiler:Start()
local staleTimer = timers[#timers].callback
profiler:Stop()
profiler:Start()
local before = #messages
-- When the old timer fires, then only the current timer ends the capture.
staleTimer()
assert(#messages == before, "a stale timer stopped a newer capture")
milliseconds = milliseconds + 30000
timers[#timers].callback()
assert(#messages == before + 5)
local readsAfterStop = clockReads
profiler:Measure("handler", function() end)
assert(clockReads == readsAfterStop, "profiling continued after timeout")

-- Given a fresh capture during a very large burst.
profiler:Start()
before = #messages
-- When 2,001 notices arrive before the timeout.
for index = 1, 2001 do profiler:Measure("handler", function() end) end
-- Then capture stops at 2,000 events with fixed aggregate storage.
assert(#messages == before + 5)
assert(messages[before + 1]:find("2000 loot events", 1, true))
assert(messages[before + 2]:find("handler: calls=2000", 1, true))

-- Given an unavailable high-resolution clock.
local unavailable = Profiler:New({ print = function() end })
-- When capture is requested, then normal callbacks remain usable.
assert(not unavailable:Start())
assert(unavailable:Measure("metadata", function() return "normal" end) == "normal")
print("Loot profiling tests passed")
