MikSBT = { Components = {} }
local IncomingCombat = dofile("Components/IncomingCombat.lua")
local file = assert(io.open("MSBTMain.lua", "r"))
local mainSource = file:read("*a")
file:close()

local profile = { events = {
	INCOMING_HEAL = { message = "%a" },
	SELF_HEAL = { message = "%a" },
} }
local callbacks = {}
local displayed = {}
local selfHealing = false
local incoming = IncomingCombat:New({
	getProfile = function() return profile end,
	normalizeNumber = tonumber,
	groupDelay = 0.12,
	after = function(_, callback)
		callbacks[#callbacks + 1] = callback
	end,
	buildActionMessage = function(_, amount) return tostring(amount) end,
	resolveBatchDisplaySettings = function(settings) return settings end,
	shouldSplitCritBatch = function() return false end,
	display = function(settings, message)
		displayed[#displayed + 1] = { settings = settings, message = message }
	end,
	getTime = function() return 10 end,
	unitCastingInfo = function() return selfHealing and "Heal" or nil end,
	unitChannelInfo = function() return nil end,
	safeUnitBoolean = function() return true end,
	unitName = function(unit)
		return unit == "player" and "Player" or "Healer"
	end,
	getLastPlayerSpell = function() return nil, 0 end,
	selfHealIconWindow = 12,
	unknown = "Unknown",
})

local eventFrame = {}
local environment = {
	eventFrame = eventFrame,
	incomingCombat = incoming,
	outgoingCombat = { ResetCombatState = function() end },
	utilityNotifications = {
		HandleCombatLeave = function() end,
		HandleCombatEnter = function() end,
	},
	InCombatLockdown = function() return false end,
}
for _, event in ipairs({
	"UNIT_COMBAT", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
}) do
	local body = assert(mainSource:match(
		"function eventFrame:" .. event .. "%b()%s*.-\nend"))
	local loadHandler = assert(loadstring(body))
	setfenv(loadHandler, environment)
	loadHandler()
end

-- Describe: healing displays outside combat and across combat boundaries.
for _, eventKey in ipairs({ "INCOMING_HEAL", "SELF_HEAL" }) do
	selfHealing = eventKey == "SELF_HEAL"
	for _, transition in ipairs({
		"none", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	}) do
		-- Given an enabled heal event while the player is out of combat.
		incoming:Reset()
		local previousCount = #displayed
		eventFrame:UNIT_COMBAT("player", "HEAL", nil, 75, nil)
		local timer = callbacks[#callbacks]
		assert(timer, "heal did not schedule a display")

		-- When its timer fires, optionally after entering or leaving combat.
		if transition ~= "none" then
			eventFrame[transition](eventFrame)
		end
		timer()

		-- Then its full amount displays in the configured healing event.
		assert(#displayed == previousCount + 1,
			eventKey .. " was lost during " .. transition)
		assert(displayed[#displayed].settings == profile.events[eventKey],
			"heal used the wrong event settings")
		assert(displayed[#displayed].message == "75", "heal amount changed")
	end
end

-- Given a pending healing batch when the addon is reset or disabled.
incoming:QueueHeal(100, false)
local timer = callbacks[#callbacks]
local previousCount = #displayed

-- When the full lifecycle reset runs before the timer.
incoming:Reset()
timer()

-- Then disabled or stale healing is still discarded.
assert(#displayed == previousCount, "full reset retained stale healing")
