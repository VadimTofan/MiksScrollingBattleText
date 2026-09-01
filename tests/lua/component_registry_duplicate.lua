MikSBT = {}

local registry = dofile("Core/ComponentRegistry.lua")

-- Given
registry:Register({ name = "Duplicate" })

-- When
local success, message = pcall(function()
	registry:Register({ name = "Duplicate" })
end)

-- Then
assert(not success, "duplicate registration unexpectedly succeeded")
assert(string.find(message, "Duplicate", 1, true), "error omits component name")
