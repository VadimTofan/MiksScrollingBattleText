local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: profile actions use supported combat-text settings.
local supportedSettings = {
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
			-- Given supported V2 settings and an optional old refresh API.
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

			-- Then no old refresh API or unsupported setting is used.
			assert(refreshCount == 0,
				functionName .. ": unexpected refresh count on " ..
				(modern and "modern" or "legacy") .. " client")
			local expectedCount = functionName ==
				"ResetOfficialBlizzardCombatText" and 4 or 5
			assert(#writes == expectedCount, functionName .. ": wrong write count")
			for _, write in ipairs(writes) do
				assert(supportedSettings[write.name], write.name)
				local expectedValue = functionName ==
					"DisableBlizzardCombatText" and 0 or 1
				assert(write.value == expectedValue, write.name .. ": wrong value")
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
