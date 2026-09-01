MikSBT = {}

local failures = {}
local diagnostics = {
	ReportError = function(_, owner, eventName, message)
		failures[#failures + 1] = {
			owner = owner,
			eventName = eventName,
			message = message,
		}
	end,
}
local EventBus = dofile("Core/EventBus.lua")
local eventBus = EventBus:New(diagnostics)
local laterHandlerRan = false

-- Given
eventBus:Subscribe("Broken", "HEAL", function()
	error("handler failed")
end)
eventBus:Subscribe("Healthy", "HEAL", function()
	laterHandlerRan = true
end)

-- When
eventBus:Emit("HEAL", 100)

-- Then
assert(laterHandlerRan, "failure prevented a later handler")
assert(#failures == 1, "handler failure was not reported once")
assert(failures[1].owner == "Broken", "diagnostic omitted component owner")
assert(failures[1].eventName == "HEAL", "diagnostic omitted event name")
assert(string.find(failures[1].message, "handler failed", 1, true),
	"diagnostic omitted failure message")
