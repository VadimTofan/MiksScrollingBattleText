MikSBT = {
	Components = {},
}

local now = 10
local cooldownStart = 10
local cooldownDuration = 2
local displayed
local triggered
local cooldownCalls = 0
local profile = {
	cooldownThreshold = 1,
	cooldownExclusions = {},
	ignoreCooldownThreshold = {},
	events = {
		NOTIFICATION_ITEM_COOLDOWN = {
			message = "%e ready",
			skillColorR = 1,
			skillColorG = 1,
			skillColorB = 1,
		},
	},
}
local ItemCooldownTracker = dofile("Components/ItemCooldownTracker.lua")
local tracker = ItemCooldownTracker:New({
	getProfile = function()
		return profile
	end,
	getTime = function()
		return now
	end,
	getItemInfo = function()
		return "Healthstone", nil, nil, nil, nil, nil, nil, nil, nil,
			"texture"
	end,
	getItemCooldown = function()
		cooldownCalls = cooldownCalls + 1
		return cooldownStart, cooldownDuration
	end,
	normalizeNumber = tonumber,
	display = function(settings, message, texture)
		displayed = { settings, message, texture }
	end,
	handleCooldown = function(...)
		triggered = { ... }
	end,
	unknown = "Unknown",
	watchDelay = 1,
	updateInterval = 0.1,
})

-- Given
tracker:SetEnabled(true)
tracker:RecordUse(5512)
now = 11

-- When less than the update interval elapses
tracker:Tick(0.05)

-- Then
assert(cooldownCalls == 0, "item cooldown API was polled every frame")

-- When the item cooldown becomes observable
local activeAfterScan = tracker:Tick(0.05)

-- Then
assert(activeAfterScan, "item cooldown was not tracked")
assert(displayed == nil, "item cooldown completed too early")

-- When the cooldown completes
now = 12.1
local activeAfterCompletion = tracker:Tick(0.1)

-- Then
assert(not activeAfterCompletion, "completed item cooldown remained active")
assert(triggered[1] == "item" and triggered[2] == 5512,
	"item cooldown trigger changed")
assert(displayed[2]:find("Healthstone", 1, true),
	"item cooldown message omitted the item name")
assert(displayed[3] == "texture", "item cooldown texture changed")
