MikSBT = {}

local registry = dofile("Core/ComponentRegistry.lua")
local calls = {}

local first = {
	name = "First",
	Initialize = function(self, context)
		calls[#calls + 1] = "initialize:" .. self.name
		assert(context.marker == "context")
	end,
	Enable = function(self)
		calls[#calls + 1] = "enable:" .. self.name
	end,
}

local second = {
	name = "Second",
	Initialize = function(self)
		calls[#calls + 1] = "initialize:" .. self.name
	end,
	Enable = function(self)
		calls[#calls + 1] = "enable:" .. self.name
	end,
}

-- Given
registry:Register(first)
registry:Register(second)

-- When
registry:InitializeAll({ marker = "context" })
registry:EnableAll()

-- Then
local expected = {
	"initialize:First",
	"initialize:Second",
	"enable:First",
	"enable:Second",
}

assert(#calls == #expected, "unexpected number of lifecycle calls")
for index, expectedCall in ipairs(expected) do
	assert(calls[index] == expectedCall, "lifecycle order differs at " .. index)
end
