local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: each profile action respects the client refresh boundary.
local functionNames = {
	"DisableBlizzardCombatText",
	"SetBlizzardCombatTextV2Enabled",
	"ResetOfficialBlizzardCombatText",
}

for _, functionName in ipairs(functionNames) do
	local body = assert(source:match(
		"local function " .. functionName .. "%b()%s*.-\nend"))
	local action = assert(loadstring(body .. "\nreturn " .. functionName))()

	for _, modern in ipairs({ true, false }) do
		for _, available in ipairs({ true, false }) do
			-- Given a client and an optional Blizzard refresh API.
			local refreshCount = 0
			local environment = {
				Client = { hasModernAPI = modern },
				SetCVar = function() end,
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

			-- Then only legacy clients with the API refresh messages.
			local expectedCount = not modern and available and 1 or 0
			assert(refreshCount == expectedCount,
				functionName .. ": unexpected refresh count on " ..
				(modern and "modern" or "legacy") .. " client")
		end
	end
end
