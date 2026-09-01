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
