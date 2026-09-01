MikSBT = {
	Services = {},
}

local EventRouter = dofile("Services/EventRouter.lua")

-- Given
local router = EventRouter:New()
local receivedEvent
local receivedProfile
router:Register("damage", function(parserEvent, profile)
	receivedEvent = parserEvent
	receivedProfile = profile
	return "OUTGOING_DAMAGE", "Ability", "Target", "DRUID", true
end)
local parserEvent = { eventType = "damage" }
local profile = { name = "Test" }

-- When
local eventType, effectName, unitName, unitClass, mergeEligible =
	router:Resolve(parserEvent, profile)

-- Then
assert(receivedEvent == parserEvent, "router replaced the parser event")
assert(receivedProfile == profile, "router replaced the profile")
assert(eventType == "OUTGOING_DAMAGE", "router changed the event type")
assert(effectName == "Ability", "router changed the effect name")
assert(unitName == "Target", "router changed the unit name")
assert(unitClass == "DRUID", "router changed the unit class")
assert(mergeEligible == true, "router changed merge eligibility")
assert(router:Resolve({ eventType = "unknown" }, profile) == nil,
	"unknown events should not resolve")

local duplicateSucceeded = pcall(function()
	router:Register("damage", function() end)
end)
assert(not duplicateSucceeded, "duplicate routes were accepted")
