MikSBT = {
	Components = {},
}

local now = 10
local powerAmount = 5
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
		return 5
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
