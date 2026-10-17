MikSBT = {
	Components = {},
}

local now = 10
local powerAmount = 5
local maximumPower = 5
local secretPower = 99999
local secretMaximum = 88888
canaccessvalue = function(value)
	return value ~= secretPower and value ~= secretMaximum
end
local RestrictedValue = dofile("API/RestrictedValue.lua")
local displayed = {}
local profile = {
	showAllPowerGains = true,
	events = {
		NOTIFICATION_CP_GAIN = { message = "CP %a" },
		NOTIFICATION_CP_FULL = { message = "Full %a" },
		NOTIFICATION_POWER_GAIN = { message = "Power %a" },
		NOTIFICATION_COMBAT_ENTER = { message = "Enter" },
		NOTIFICATION_COMBAT_LEAVE = { message = "Leave" },
		NOTIFICATION_MONSTER_EMOTE = { message = "%s" },
	},
}
local UtilityNotifications = dofile("Components/UtilityNotifications.lua")
local notifications = UtilityNotifications:New({
	getProfile = function()
		return profile
	end,
	display = function(settings, message)
		displayed[#displayed + 1] = { settings, message }
	end,
	format = function(message, amount, _, _, _, powerType, _, _, skill)
		return message:gsub("%%a", tostring(amount or ""))
			:gsub("%%s", tostring(skill or ""))
	end,
	powerTypes = { COMBO_POINTS = 4, MANA = 0 },
	unitPower = function()
		return powerAmount
	end,
	unitPowerMax = function()
		return maximumPower
	end,
	normalizeNumber = function(value)
		return RestrictedValue:Number(value)
	end,
	getPlayerClass = function()
		return "ROGUE"
	end,
	unitName = function()
		return "Target"
	end,
	getTime = function()
		return now
	end,
	unknown = "Unknown",
	emoteHoldTime = 1,
})

-- Given / When
notifications:HandlePowerUpdate("player", "COMBO_POINTS")

-- Then
assert(displayed[1][2] == "Full 5", "full combo-point message changed")

-- Given / When
notifications:HandleCombatEnter()
notifications:HandleCombatLeave()

-- Then
assert(displayed[2][2] == "Enter", "combat-enter message changed")
assert(displayed[3][2] == "Leave", "combat-leave message changed")

-- Given duplicate monster emotes
notifications:HandleMonsterEmote("%s roars.", "Target")
notifications:HandleMonsterEmote("%s roars.", "Target")

-- Then
assert(#displayed == 4, "duplicate monster emote was displayed")
assert(displayed[4][2] == "Target roars.", "monster emote changed")

-- Describe: power gains require readable, consecutive samples.
-- Given a readable mana baseline.
powerAmount = 100
notifications:HandlePowerUpdate("player", "MANA")
local previousDisplayCount = #displayed

-- When the next power reading is secret.
powerAmount = secretPower
notifications:HandlePowerUpdate("player", "MANA")

-- Then no gain is displayed and the old baseline is discarded.
assert(#displayed == previousDisplayCount, "secret mana produced a gain")
assert(notifications.lastPowerAmounts[0] == nil,
	"secret mana kept a stale baseline")

-- Given power becomes readable again above its old baseline.
powerAmount = 150

-- When the first readable sample arrives.
notifications:HandlePowerUpdate("player", "MANA")

-- Then it establishes a new baseline without inventing a gain.
assert(#displayed == previousDisplayCount,
	"first readable mana sample produced a false gain")
assert(notifications.lastPowerAmounts[0] == 150,
	"readable mana did not restore the baseline")

-- Given consecutive readable mana samples.
powerAmount = 175

-- When mana increases.
notifications:HandlePowerUpdate("player", "MANA")

-- Then normal power-gain notifications resume with the correct delta.
assert(displayed[#displayed][2] == "Power 25",
	"readable mana gain was lost")

-- Describe: resource changes require readable current and maximum power.
-- Given a secret combo-point reading.
previousDisplayCount = #displayed
powerAmount = secretPower

-- When combo points update.
notifications:HandlePowerUpdate("player", "COMBO_POINTS")

-- Then no resource notification or inaccessible baseline is retained.
assert(#displayed == previousDisplayCount,
	"secret combo points produced a notification")
assert(notifications.lastPowerAmounts[4] == nil,
	"secret combo points kept a stale baseline")

-- Given readable combo points with a secret maximum.
powerAmount = 4
maximumPower = secretMaximum

-- When combo points update.
notifications:HandlePowerUpdate("player", "COMBO_POINTS")

-- Then full-resource detection skips the inaccessible maximum.
assert(#displayed == previousDisplayCount,
	"secret maximum power produced a resource notification")

-- Given a legacy client without secret-value predicates.
canaccessvalue = nil
powerAmount = 5
maximumPower = 5

-- When readable combo points reach their maximum.
notifications:HandlePowerUpdate("player", "COMBO_POINTS")

-- Then the full-resource notification still works.
assert(displayed[#displayed][2] == "Full 5",
	"legacy full-resource notification changed")
