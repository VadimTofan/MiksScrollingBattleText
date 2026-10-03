MikSBT = { Components = {} }
local Notifications = dofile("Components/ParserNotifications.lua")
local notifications = Notifications:New()

-- Describe: supported chat notification routes preserve player filtering.
local cases = {
	{ "HandleHonor", {}, "NOTIFICATION_HONOR_GAIN" },
	{ "HandleReputation", { factionName = "Guild" }, "NOTIFICATION_REP_GAIN", "Guild" },
	{ "HandleReputation", { factionName = "Guild", isLoss = true }, "NOTIFICATION_REP_LOSS", "Guild" },
	{ "HandleProficiency", { skillName = "Cooking" }, "NOTIFICATION_SKILL_GAIN", "Cooking" },
	{ "HandleExperience", {}, "NOTIFICATION_EXPERIENCE_GAIN" },
}
for _, case in ipairs(cases) do
	-- Given a chat notification belonging to the player.
	local event = case[2]
	event.recipientUnit = "player"

	-- When the real notification component resolves it.
	local eventType, effectName = notifications[case[1]](notifications, event)

	-- Then the existing event type and effect name are returned.
	assert(eventType == case[3], case[1] .. " route changed")
	assert(effectName == case[4], case[1] .. " effect name changed")

	-- Given a notification belonging to another unit.
	event.recipientUnit = "target"

	-- When the same route is resolved.
	local otherEvent = notifications[case[1]](notifications, event)

	-- Then the player notification is suppressed.
	assert(otherEvent == nil, case[1] .. " routed another unit")
end
