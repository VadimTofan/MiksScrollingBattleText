MikSBT = { Components = {} }
local events = {}
local restricted = {}
local Notifications = dofile("Components/ActionNotifications.lua")
local notifications = Notifications:New({
	eventType = "dispel",
	isSecret = function(value) return value == restricted end,
	getSpellInfo = function() return "Dispel Magic", nil, "icon" end,
	emit = function(event) events[#events + 1] = event end,
})

-- Given a confirmed pair of player dispels.
-- When the meter delta arrives.
notifications:HandleDelta(527, 2, false, "1")

-- Then each action routes with the action spell and no guessed aura or target.
assert(#events == 2, "confirmed dispel count changed")
assert(events[1].eventType == "dispel" and events[1].sourceUnit == "player")
assert(events[1].extraSkillName == "Dispel Magic")
assert(events[1].recipientName == nil, "aggregate data guessed a target")

-- Given a pet action and invalid or restricted deltas.
-- When the deltas are processed.
notifications:HandleDelta(19505, 1, false, "2")
notifications:HandleDelta(527, restricted, false, "1")
notifications:HandleDelta(527, 0, false, "1")
notifications:HandleDelta(527, -1, false, "1")

-- Then only the confirmed pet action is added.
assert(#events == 3 and events[3].sourceUnit == "pet")
