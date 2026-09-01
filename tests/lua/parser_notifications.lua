MikSBT = {
	Components = {},
}

local ParserNotifications = dofile("Components/ParserNotifications.lua")
local notifications = ParserNotifications:New({
	uniquePowerTypes = { [3] = true },
	alternatePowerType = 10,
	testFlagsAll = function(flags, mask)
		return flags == mask
	end,
	guardianHumanMask = 5,
	serverControlMask = 7,
	classMap = {
		["target-guid"] = "DRUID",
	},
})

-- Given
local profile = {
	showAllPowerGains = false,
	powerThreshold = 10,
}

-- When
local eventType, skillName, unitName, unitClass, mergeEligible =
	notifications:HandlePower({
		recipientUnit = "player",
		amount = 25,
		powerType = 10,
		skillName = "Power Spell",
	}, profile)

-- Then
assert(eventType == "NOTIFICATION_ALT_POWER_GAIN",
	"alternate power route changed")
assert(skillName == "Power Spell", "power skill changed")
assert(mergeEligible == true, "power notification stopped merging")
assert(notifications:HandlePower({ powerType = 3 }, profile) == nil,
	"unique power type was routed")

-- Given / When
eventType, _, unitName, unitClass = notifications:HandleKill({
	sourceUnit = "player",
	recipientUnit = "target",
	recipientFlags = 7,
	recipientName = "Target",
	recipientGUID = "target-guid",
})

-- Then
assert(eventType == "NOTIFICATION_NPC_KILLING_BLOW",
	"killing-blow route changed")
assert(unitName == "Target" and unitClass == "DRUID",
	"killing-blow target data changed")
