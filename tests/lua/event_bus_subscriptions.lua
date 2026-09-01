MikSBT = {}

local EventBus = dofile("Core/EventBus.lua")
local eventBus = EventBus:New()
local calls = {}

-- Given
eventBus:Subscribe("First", "DAMAGE", function(amount)
	calls[#calls + 1] = "first:" .. amount
end)
eventBus:Subscribe("Second", "DAMAGE", function(amount)
	calls[#calls + 1] = "second:" .. amount
end)

-- When
eventBus:Emit("DAMAGE", 25)
eventBus:UnsubscribeOwner("First")
eventBus:Emit("DAMAGE", 50)

-- Then
assert(#calls == 3, "unexpected number of event calls")
assert(calls[1] == "first:25", "first subscriber order changed")
assert(calls[2] == "second:25", "second subscriber order changed")
assert(calls[3] == "second:50", "owner unsubscription removed wrong handler")
