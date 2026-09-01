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
	setBlizzardEnabled = function(enabled)
		blizzardStates[#blizzardStates + 1] = enabled
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

-- Given the addon is disabled
disabled = true

-- When policy applies twice
controller:Apply()
controller:Apply()

-- Then addon lifecycle changes once to disabled
assert(#addonStates == 2 and addonStates[2] == false,
	"disabled addon lifecycle was not idempotent")
