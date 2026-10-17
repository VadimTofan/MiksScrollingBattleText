MikSBT = { Components = {} }

local now = 10
local displayed = {}
local profile = {
	events = {
		NOTIFICATION_COMBAT_ENTER = { message = "Enter" },
		NOTIFICATION_COMBAT_LEAVE = { message = "Leave" },
		NOTIFICATION_MONSTER_EMOTE = { message = "%s" },
	},
}
local UtilityNotifications = dofile("Components/UtilityNotifications.lua")
local notifications = UtilityNotifications:New({
	getProfile = function() return profile end,
	display = function(settings, message)
		displayed[#displayed + 1] = { settings, message }
	end,
	format = function(message, _, _, _, _, _, _, _, skill)
		return message:gsub("%%s", skill or "")
	end,
	unitName = function() return "Target" end,
	getTime = function() return now end,
	emoteHoldTime = 1,
})

-- Given enabled combat-state notifications.
-- When combat starts and ends.
notifications:HandleCombatEnter()
notifications:HandleCombatLeave()

-- Then both notifications keep their configured messages.
assert(displayed[1][2] == "Enter", "combat-enter message changed")
assert(displayed[2][2] == "Leave", "combat-leave message changed")

-- Given a monster emote from the current target.
-- When the same emote arrives twice during its hold window.
notifications:HandleMonsterEmote("%s roars.", "Target")
notifications:HandleMonsterEmote("%s roars.", "Target")

-- Then only one formatted emote is displayed.
assert(#displayed == 3, "duplicate monster emote was displayed")
assert(displayed[3][2] == "Target roars.", "monster emote changed")
