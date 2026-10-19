MikSBT = { Configuration = {} }

local grouped, disabled = false, false
local profile = {
	blizzardDamageEnabled = true,
	enableBlizzardV2CombatText = true,
	enableBlizzardV2CombatTextInGroup = false,
	disableBlizzardIncoming = true,
}
local addonStates, blizzardStates, suppressOtherStates = {}, {}, {}
local RuntimeController = dofile("Configuration/RuntimeController.lua")
local controller = RuntimeController:New({
	isInGroup = function() return grouped end,
	isAddonDisabled = function() return disabled end,
	getProfile = function() return profile end,
	setAddonEnabled = function(enabled)
		addonStates[#addonStates + 1] = enabled
	end,
	setBlizzardEnabled = function(enabled, suppressOtherText)
		blizzardStates[#blizzardStates + 1] = enabled
		suppressOtherStates[#suppressOtherStates + 1] = suppressOtherText
	end,
})

-- Describe: independent combat-text toggles in solo and group play.
for _, inGroup in ipairs({ false, true }) do
	for _, addonDisabled in ipairs({ false, true }) do
		for _, damageEnabled in ipairs({ false, true }) do
			-- Given independent checkbox selections in either context.
			grouped, disabled = inGroup, addonDisabled
			profile.blizzardDamageEnabled = damageEnabled

			-- When the settings apply twice.
			controller:Apply()
			local lifecycleCalls = #addonStates
			controller:Apply()

			-- Then old overrides cannot change either checkbox selection.
			assert(addonStates[#addonStates] == not addonDisabled,
				"MSBT did not follow its own toggle")
			assert(blizzardStates[#blizzardStates] == damageEnabled,
				"Blizzard damage did not follow its own toggle")
			assert(suppressOtherStates[#suppressOtherStates] == not addonDisabled,
				"MSBT did not suppress the other Blizzard combat text")
			assert(#addonStates == lifecycleCalls,
				"reapplying settings repeated the addon lifecycle")
		end
	end
end
