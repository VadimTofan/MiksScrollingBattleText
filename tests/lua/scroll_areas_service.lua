MikSBT = {
	Display = {},
}

local inGroup = false
local profile = {
	disableOutgoingInGroup = true,
	scrollAreas = {
		Outgoing = {
			name = "My Outgoing",
			skillIconsDisabled = false,
		},
	},
}
local masterProfile = {
	scrollAreas = {
		Outgoing = { name = "Outgoing" },
		Notification = { name = "Notification" },
	},
}

local ScrollAreas = dofile("Display/ScrollAreas.lua")
ScrollAreas:Configure({
	getProfile = function()
		return profile
	end,
	getMasterProfile = function()
		return masterProfile
	end,
	isInGroup = function()
		return inGroup
	end,
	isInRaid = function()
		return false
	end,
	defaultArea = "Notification",
})

-- Given / When
ScrollAreas:Update()
local outgoing = ScrollAreas:Resolve("Outgoing")
local byName = ScrollAreas:Resolve("My Outgoing")
local fallback = ScrollAreas:Resolve("Missing")

-- Then
assert(outgoing == profile.scrollAreas.Outgoing,
	"profile scroll area did not override master")
assert(byName == outgoing, "localized scroll-area name was not resolved")
assert(fallback == masterProfile.scrollAreas.Notification,
	"default scroll area was not used")
assert(ScrollAreas:IsActive("Outgoing") == true,
	"enabled scroll area was reported inactive")
assert(ScrollAreas:IsIconShown("Outgoing") == true,
	"enabled area icon was reported hidden")
assert(ScrollAreas:IsSuppressedInGroup("Outgoing") == false,
	"solo area was suppressed")

-- Given group context
inGroup = true

-- When / Then
assert(ScrollAreas:IsSuppressedInGroup("Outgoing") == true,
	"group suppression setting was ignored")

-- Describe: pet areas retain the matching outgoing/incoming group controls.
-- Given a group and outgoing suppression enabled.
profile.disableIncomingInGroup = false
-- When checking both pet areas.
-- Then only outgoing pet text is suppressed.
assert(ScrollAreas:IsSuppressedInGroup("OutgoingPet"))
assert(not ScrollAreas:IsSuppressedInGroup("IncomingPet"))

-- Given incoming suppression enabled and outgoing suppression disabled.
profile.disableIncomingInGroup = true
profile.disableOutgoingInGroup = false
-- When checking both pet areas.
-- Then only incoming pet text is suppressed.
assert(ScrollAreas:IsSuppressedInGroup("IncomingPet"))
assert(not ScrollAreas:IsSuppressedInGroup("OutgoingPet"))
