local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: profile actions preserve the pre-October 15 combat-text controls.
local supportedSettings = {
	enableFloatingCombatText = true,
	floatingCombatTextCombatHealing = true,
	floatingCombatTextCombatDamage = true,
	floatingCombatTextCombatHealing_v2 = true,
	floatingCombatTextCombatDamage_v2 = true,
	floatingCombatTextCombatLogPeriodicSpells_v2 = true,
	floatingCombatTextPetMeleeDamage_v2 = true,
	floatingCombatTextPetSpellDamage_v2 = true,
}
local functionNames = {
	"DisableBlizzardCombatText",
	"SetBlizzardCombatTextV2Enabled",
	"ResetOfficialBlizzardCombatText",
}

for _, functionName in ipairs(functionNames) do
	local body = assert(source:match(
		"local function " .. functionName .. "%b()%s*.-\nend"))
	local helper = source:match(
		"local function SafeSetCVar%b()%s*.-\nend") or ""
	local action = assert(loadstring(
		helper .. "\n" .. body .. "\nreturn " .. functionName))()

	for _, modern in ipairs({ true, false }) do
		for _, available in ipairs({ true, false }) do
			-- Given combat-text settings and an optional old refresh API.
			local refreshCount = 0
			local writes = {}
			local environment = {
				Client = { hasModernAPI = modern },
				IsClassic = not modern,
				pcall = pcall,
				SetCVar = function(name, value)
					writes[#writes + 1] = { name = name, value = value }
					assert(supportedSettings[name], "unsupported CVar: " .. name)
				end,
				module = { ApplyContextOptions = function() end },
			}
			if available then
				environment.CombatText_UpdateDisplayedMessages = function()
					refreshCount = refreshCount + 1
				end
			end
			setfenv(action, environment)

			-- When a profile action changes Blizzard combat text.
			action(true)

			-- Then legacy clients refresh and all previous controls are set.
			local expectedRefresh = not modern and available and 1 or 0
			assert(refreshCount == expectedRefresh,
				functionName .. ": unexpected refresh count on " ..
				(modern and "modern" or "legacy") .. " client")
			local expectedCount = functionName ==
				"ResetOfficialBlizzardCombatText" and 4 or
				(modern and 8 or 7)
			assert(#writes == expectedCount, functionName .. ": wrong write count")
			for _, write in ipairs(writes) do
				assert(supportedSettings[write.name], write.name)
				local expectedValue = functionName ==
					"DisableBlizzardCombatText" and 0 or 1
				assert(write.value == expectedValue, write.name .. ": wrong value")
			end
			if functionName ~= "ResetOfficialBlizzardCombatText" then
				local incomingValue
				for _, write in ipairs(writes) do
					if write.name == "enableFloatingCombatText" then
						incomingValue = write.value
					end
				end
				local expectedIncoming = functionName ==
					"DisableBlizzardCombatText" and 0 or 1
				assert(incomingValue == expectedIncoming,
					functionName .. ": incoming combat text was not toggled")
				local expectedText = functionName ==
					"DisableBlizzardCombatText" and "0" or "1"
				assert(environment.SHOW_COMBAT_TEXT == expectedText,
					functionName .. ": combat-text toggle was not restored")

				if functionName == "SetBlizzardCombatTextV2Enabled" then
					-- When the checkbox disables Blizzard combat text.
					writes = {}
					action(false)

					-- Then every control, including the global toggle, is off.
					assert(#writes == expectedCount, "missing disable writes")
					for _, write in ipairs(writes) do
						assert(write.value == 0, write.name .. ": still enabled")
					end
					assert(environment.SHOW_COMBAT_TEXT == "0",
						"combat-text toggle is still enabled")
				end
			end

			-- Given a setting whose write fails.
			environment.SetCVar = function() error("write failed") end

			-- When the profile action runs again.
			local success, message = pcall(action, true)

			-- Then the error is visible to the caller.
			assert(not success, functionName .. ": swallowed a write error")
			assert(message:find("write failed", 1, true), message)
		end
	end
end
