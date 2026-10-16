MikSBT = {Components = {}}
dofile("API/RestrictedValue.lua")
local Incoming = dofile("Components/IncomingCombat.lua")
local callbacks, displayed = {}, {}
local profile = {events = {INCOMING_HEAL = {message = "%a"}}}
local incoming = Incoming:New({
	getProfile = function() return profile end,
	groupDelay = 0.12,
	after = function(_, callback) callbacks[#callbacks + 1] = callback end,
	buildActionMessage = function(_, amount) return tostring(amount) end,
	resolveBatchDisplaySettings = function(settings) return settings end,
	shouldSplitCritBatch = function() return false end,
	display = function(_, message) displayed[#displayed + 1] = message end,
	getTime = function() return 10 end,
	getLastPlayerSpell = function() return nil end,
})

-- Given a scheduled heal batch replaced by another batch after reset.
incoming:QueueHeal(10, false)
incoming:Reset()
incoming:QueueHeal(20, false)

-- When the old timer runs.
callbacks[1]()

-- Then the new batch stays pending until its own timer expires.
assert(#displayed == 0, "old heal timer flushed a replacement batch")
callbacks[2]()
assert(#displayed == 1 and displayed[1]:find("20", 1, true),
	"replacement heal timer did not display its own batch")
