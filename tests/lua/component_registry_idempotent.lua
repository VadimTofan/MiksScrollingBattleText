MikSBT = {}

local registry = dofile("Core/ComponentRegistry.lua")
local calls = {
	initialize = 0,
	enable = 0,
	disable = 0,
}

local component = {
	name = "Lifecycle",
	Initialize = function()
		calls.initialize = calls.initialize + 1
	end,
	Enable = function()
		calls.enable = calls.enable + 1
	end,
	Disable = function()
		calls.disable = calls.disable + 1
	end,
}

-- Given
registry:Register(component)

-- When
registry:InitializeAll({})
registry:InitializeAll({})
registry:EnableAll()
registry:EnableAll()
registry:DisableAll()
registry:DisableAll()

-- Then
assert(calls.initialize == 1, "component initialized more than once")
assert(calls.enable == 1, "component enabled more than once")
assert(calls.disable == 1, "component disabled more than once")
