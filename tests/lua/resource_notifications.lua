MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local settings = { message = "%a - %p" }
local profile = { events = { NOTIFICATION_RESOURCE_GAIN = settings } }
local timers, displayed = {}, {}
MANA, ENERGY = "Mana", "Energy"
local presentation = Presentation:New({
	getProfile = function() return profile end,
	after = function(delay, callback)
		timers[#timers + 1] = { delay = delay, callback = callback }
	end,
	displayResource = function(eventSettings, amount, powerName)
		displayed[#displayed + 1] = {
			settings = eventSettings, amount = amount, powerName = powerName,
		}
	end,
})

-- Given three readable gains arriving together.
-- When mana and energy gains are reported.
presentation:Resource(10, "MANA")
presentation:Resource(5, "MANA")
presentation:Resource(3, "ENERGY")
-- Then each gain appears immediately without a timer or grouping.
assert(#displayed == 3, "resource gains were delayed")
assert(#timers == 0, "resource gains still scheduled a collection window")
assert(displayed[1].amount == 10)
assert(displayed[2].amount == 5)
assert(displayed[3].powerName == "ENERGY",
	"Blizzard's resource label was modified")

-- Given an opaque amount and resource name.
local hiddenAmount, hiddenName = {}, {}
issecretvalue = function(value)
	return value == hiddenAmount or value == hiddenName
end
-- When the gain arrives.
presentation:Resource(hiddenAmount, hiddenName)
-- Then both exact values reach rendering immediately.
assert(#displayed == 4 and #timers == 0)
assert(displayed[4].amount == hiddenAmount)
assert(displayed[4].powerName == hiddenName)

-- Given a disabled notification.
settings.disabled = true
-- When another gain arrives, then no text or timer is created.
presentation:Resource(5, "MANA")
assert(#displayed == 4 and #timers == 0)
