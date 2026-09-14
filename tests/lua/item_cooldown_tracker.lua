MikSBT = { Components = {} }

local now = 10
local displayed
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
local Tracker = dofile("Components/ItemCooldownTracker.lua")
local tracker = Tracker:New({
	getProfile = function() return profile end,
	getTime = function() return now end,
	getItemInfo = function() return "Potion", nil, nil, nil, nil, nil, nil, nil, nil, "icon" end,
	getItemCooldown = function() return 10, 2 end,
	normalizeNumber = tonumber,
	display = function(_, message, icon) displayed = { message, icon } end,
	handleCooldown = function() end,
	unknown = "Unknown",
	watchDelay = 1,
	updateInterval = 0.1,
})

-- Given a used item whose cooldown lasts two seconds
tracker:SetEnabled(true)
assert(tracker:RecordUse(123), "item use was not recorded")

-- When the cooldown starts and then finishes
now = 11
tracker:Tick(0.1)
now = 12.1
tracker:Tick(0.1)

-- Then its ready notification includes the item and icon
assert(displayed and displayed[1]:find("Potion", 1, true),
	"ready notification omitted the item name")
assert(displayed[2] == "icon", "ready notification omitted the icon")
