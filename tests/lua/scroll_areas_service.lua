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

-- Describe: removed group settings cannot suppress events or public messages.
-- Given a grouped player with every old scroll-area restriction saved.
inGroup = true
profile.disableIncomingInGroup = true
profile.disableNotificationInGroup = true
profile.disableStaticInGroup = true
local displayed = 0
local DisplayService = dofile("Display/DisplayService.lua")
DisplayService:Configure({
	scrollAreas = ScrollAreas,
	getProfile = function() return profile end,
	isModDisabled = function() return false end,
	display = function() displayed = displayed + 1 end,
	fonts = {},
	outlineMap = {},
	defaultArea = "Notification",
})

-- When combat events and public messages arrive in every area.
local areaKeys = {
	"Outgoing", "OutgoingPet", "Incoming", "IncomingPet",
	"Notification", "Static",
}
for _, key in ipairs(areaKeys) do
	DisplayService:DisplayEvent({ scrollArea = key }, "Event")
	DisplayService:DisplayMessage("Public message", key)
end

-- Then every enabled message displays regardless of the old restrictions.
assert(displayed == 12, "legacy group restrictions still hide MSBT messages")
