MikSBT = {}

local failures = {}
local diagnostics = {
	ReportError = function(_, owner, operation, message)
		failures[#failures + 1] = {
			owner = owner,
			operation = operation,
			message = message,
		}
	end,
}
local registry = dofile("Core/ComponentRegistry.lua")
local healthyEnabled = false

-- Given
registry:SetDiagnostics(diagnostics)
registry:Register({
	name = "Broken",
	Enable = function()
		error("enable failed")
	end,
})
registry:Register({
	name = "Healthy",
	Enable = function()
		healthyEnabled = true
	end,
})

-- When
registry:EnableAll()

-- Then
assert(healthyEnabled, "failure prevented a later component from enabling")
assert(#failures == 1, "lifecycle failure was not reported once")
assert(failures[1].owner == "Broken", "diagnostic omitted component name")
assert(failures[1].operation == "Enable", "diagnostic omitted lifecycle operation")
assert(string.find(failures[1].message, "enable failed", 1, true),
	"diagnostic omitted failure message")
