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

-- Describe: unchecked pet areas redirect to the matching main area.
for _, direction in ipairs({ "Outgoing", "Incoming" }) do
	-- Given distinct pet and main areas, with pet output unchecked.
	local petKey = direction .. "Pet"
	local mainArea = { name = direction, skillIconsDisabled = true }
	local petArea = { name = "Localized " .. petKey, disabled = true }
	profile.scrollAreas[direction] = mainArea
	profile.scrollAreas[petKey] = petArea
	ScrollAreas:Update()
	local rendered = {}
	DisplayService.config.display = function(...)
		rendered[#rendered + 1] = { ... }
	end
	local event = { scrollArea = petKey, textCategory = direction }
	local amount = {} -- Stand-in for an amount passed untouched to rendering.

	-- When pet damage resolves by key or localized name and reaches display.
	local resolved = ScrollAreas:Resolve(petKey)
	local localized = ScrollAreas:Resolve(petArea.name)
	DisplayService:DisplayEvent(event, "Pet %s", "pet-icon", false, amount)

	-- Then routing and icon policy use the main area without changing settings.
	assert(resolved == mainArea, petKey .. " did not fall back to " .. direction)
	assert(localized == mainArea, "localized pet area did not redirect")
	assert(ScrollAreas:IsActive(petKey), "redirected pet area was inactive")
	assert(not ScrollAreas:IsIconShown(petKey), "main area icon policy ignored")
	assert(#rendered == 1 and rendered[1][2] == mainArea,
		"pet damage did not reach the main scroll area")
	assert(rendered[1][1] == "Pet %s" and rendered[1][11] == "pet-icon"
		and rendered[1][12] == amount, "pet display arguments changed")
	assert(event.scrollArea == petKey and petArea.disabled,
		"fallback rewrote saved pet settings")

	-- When the pet area is re-enabled.
	petArea.disabled = false
	DisplayService:DisplayEvent(event, "Separate pet damage")

	-- Then pet output immediately returns to its own area.
	assert(ScrollAreas:Resolve(petKey) == petArea)
	assert(#rendered == 2 and rendered[2][2] == petArea)

	-- Given both pet and main areas are unchecked.
	petArea.disabled = true
	mainArea.disabled = true

	-- When more pet damage arrives.
	DisplayService:DisplayEvent(event, "Hidden damage")

	-- Then the disabled main area still suppresses output.
	assert(not ScrollAreas:IsActive(petKey))
	assert(#rendered == 2, "disabled main area displayed pet damage")

	-- Given the main area is enabled but the individual event is disabled.
	mainArea.disabled = false
	event.disabled = true

	-- When that event arrives.
	DisplayService:DisplayEvent(event, "Disabled event")

	-- Then fallback does not re-enable an explicitly disabled event.
	assert(#rendered == 2, "disabled pet event was redirected")
end

-- Given an unrelated disabled custom area.
local custom = { name = "Custom", disabled = true }
profile.scrollAreas.Custom = custom
ScrollAreas:Update()

-- When that area is resolved.
local resolvedCustom = ScrollAreas:Resolve("Custom")

-- Then only the built-in pet areas participate in fallback.
assert(resolvedCustom == custom and not ScrollAreas:IsActive("Custom"))
