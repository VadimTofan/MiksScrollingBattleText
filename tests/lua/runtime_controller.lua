MikSBT = {
	Configuration = {},
}

local grouped = false
local disabled = false
local profile = {
	enableBlizzardV2CombatText = true,
	enableBlizzardV2CombatTextInGroup = true,
}
local addonStates = {}
local blizzardStates = {}
local incomingStates = {}
local RuntimeController = dofile("Configuration/RuntimeController.lua")
local controller = RuntimeController:New({
	isInGroup = function()
		return grouped
	end,
	isAddonDisabled = function()
		return disabled
	end,
	getProfile = function()
		return profile
	end,
	setAddonEnabled = function(enabled)
		addonStates[#addonStates + 1] = enabled
	end,
	setBlizzardEnabled = function(enabled, incomingEnabled)
		blizzardStates[#blizzardStates + 1] = enabled
		incomingStates[#incomingStates + 1] = incomingEnabled
	end,
})

-- Given solo play with MSBT enabled and Blizzard CT disabled while solo
-- When policy applies twice
controller:Apply()
controller:Apply()

-- Then addon lifecycle changes once and Blizzard CT remains disabled
assert(#addonStates == 1 and addonStates[1],
	"enabled addon lifecycle was not idempotent")
assert(blizzardStates[#blizzardStates] == false,
	"solo Blizzard CT policy changed")

-- Given grouped play with Blizzard CT enabled in groups
grouped = true

-- When policy applies
controller:Apply()

-- Then Blizzard CT is enabled
assert(blizzardStates[#blizzardStates] == true,
	"group Blizzard CT policy changed")
assert(incomingStates[#incomingStates] == true,
	"Blizzard incoming text should follow the existing group policy")

-- Given grouped play with only Blizzard incoming text disabled
profile.disableBlizzardIncoming = true

-- When policy applies
controller:Apply()

-- Then outgoing text stays enabled and incoming text is disabled
assert(blizzardStates[#blizzardStates] == true,
	"disabling incoming text also disabled outgoing text")
assert(incomingStates[#incomingStates] == false,
	"Blizzard incoming text was not disabled")
assert(profile.disableIncomingInGroup == nil,
	"Blizzard incoming policy changed the MSBT setting")

-- Given the incoming option is unchecked again
profile.disableBlizzardIncoming = false

-- When policy applies
controller:Apply()

-- Then incoming text is restored
assert(incomingStates[#incomingStates] == true,
	"Blizzard incoming text was not restored")

-- Given solo play with Blizzard CT enabled and incoming text disabled
grouped = false
profile.enableBlizzardV2CombatText = false
profile.disableBlizzardIncoming = true

-- When policy applies
controller:Apply()

-- Then incoming can be disabled independently while solo too
assert(blizzardStates[#blizzardStates] == true,
	"solo outgoing text was disabled")
assert(incomingStates[#incomingStates] == false,
	"solo incoming text was not disabled")

-- Given group combat text is disabled entirely
grouped = true
profile.enableBlizzardV2CombatTextInGroup = false
profile.disableBlizzardIncoming = false

-- When policy applies
controller:Apply()

-- Then neither outgoing nor incoming Blizzard text is enabled
assert(blizzardStates[#blizzardStates] == false,
	"group outgoing text was enabled")
assert(incomingStates[#incomingStates] == false,
	"incoming text bypassed the group combat-text policy")

-- Given the addon is disabled
disabled = true

-- When policy applies twice
controller:Apply()
controller:Apply()

-- Then addon lifecycle changes once to disabled
assert(#addonStates == 2 and addonStates[2] == false,
	"disabled addon lifecycle was not idempotent")
