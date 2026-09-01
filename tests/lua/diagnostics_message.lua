MikSBT = {}

local messages = {}
local Diagnostics = dofile("Core/Diagnostics.lua")
local diagnostics = Diagnostics:New(function(message)
	messages[#messages + 1] = message
end)

-- Given
local componentName = "IncomingDamage"
local operation = "Enable"

-- When
diagnostics:ReportError(componentName, operation, "restricted value")

-- Then
assert(#messages == 1, "diagnostic was not emitted once")
assert(string.find(messages[1], componentName, 1, true),
	"diagnostic omitted component name")
assert(string.find(messages[1], operation, 1, true),
	"diagnostic omitted operation")
assert(string.find(messages[1], "restricted value", 1, true),
	"diagnostic omitted failure message")
