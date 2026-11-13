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

-- Describe: a skill gain takes its skill line's own icon.
-- Given the player's skill lines and the icons of known lines.
MikSBT.SKILL_LINE_ICONS = { [165] = 136247, [185] = 133971 }
local lines = {
	{ skillID = 0, name = "Berufe", isHeader = true },
	{ skillID = 165, name = "Lederverarbeitung" },
	{ skillID = 185, name = "Kochkunst" },
	{ skillID = 173, name = "Dolche" },
}
C_SkillInfo = {
	GetNumSkillLines = function() return #lines end,
	GetSkillLineInfo = function(index) return lines[index] end,
}

-- When skill gains are named, for lines with and without an icon.
-- Then each finds its own line's icon, and nothing else is guessed.
assert(notifications:SkillIcon("Lederverarbeitung") == 136247, "profession icon missing")
assert(notifications:SkillIcon("Kochkunst") == 133971, "second line's icon missing")
assert(notifications:SkillIcon("Dolche") == nil, "a line with no icon got one")
assert(notifications:SkillIcon("Bergbau") == nil, "a line the player lacks got an icon")

-- When the client refuses the skill lines or has none of the functions.
C_SkillInfo.GetSkillLineInfo = function() error("refused") end
assert(notifications:SkillIcon("Kochkunst") == nil, "a refused read was not caught")
C_SkillInfo = nil
assert(notifications:SkillIcon("Kochkunst") == nil, "a missing API was not caught")
