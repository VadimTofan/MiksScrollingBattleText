local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: the checkbox only changes player and pet damage CVars.
local damageSettings = {
	floatingCombatTextCombatDamage = true,
	floatingCombatTextCombatDamage_v2 = true,
	floatingCombatTextCombatLogPeriodicSpells_v2 = true,
	floatingCombatTextPetMeleeDamage_v2 = true,
	floatingCombatTextPetSpellDamage_v2 = true,
}
local body = assert(source:match(
	"local function SetBlizzardCombatTextV2Enabled%b()%s*.-\nend"))
local action = assert(loadstring(body ..
	"\nreturn SetBlizzardCombatTextV2Enabled"))()

for _, modern in ipairs({ true, false }) do
	for _, enabled in ipairs({ true, false }) do
		-- Given unrelated incoming and healing text settings.
		local writes, refreshes = {}, 0
		local environment = {
			Client = { hasModernAPI = modern },
			IsClassic = not modern,
			SHOW_COMBAT_TEXT = "unchanged",
			SetCVar = function(name, value) writes[name] = value end,
			CombatText_UpdateDisplayedMessages = function()
				refreshes = refreshes + 1
			end,
		}
		setfenv(action, environment)

		-- When damage is toggled.
		action(enabled)

		-- Then only damage settings follow the checkbox.
		for name in pairs(damageSettings) do
			assert(writes[name] == (enabled and 1 or 0), name)
		end
		for name in pairs(writes) do
			assert(damageSettings[name], "changed unrelated text: " .. name)
		end
		assert(environment.SHOW_COMBAT_TEXT == "unchanged")
		assert(refreshes == (modern and 0 or 1))

		-- Given a checkbox change during combat.
		environment.InCombatLockdown = function() return true end
		writes = {}

		-- When the preference is applied.
		action(enabled)

		-- Then settings wait until combat ends.
		assert(next(writes) == nil, "damage settings changed during combat")
		environment.InCombatLockdown = function() return false end
		action(enabled)
		assert(writes.floatingCombatTextCombatDamage_v2 == (enabled and 1 or 0))

		-- Given MSBT is enabled and all Blizzard combat text must be hidden.
		writes = {}

		-- When MSBT's suppression policy applies.
		action(false, true)

		-- Then damage, incoming, healing, and the legacy global are all off.
		for name in pairs(damageSettings) do
			assert(writes[name] == 0, name .. " was not disabled")
		end
		assert(writes.enableFloatingCombatText == 0,
			"Blizzard incoming combat text was not disabled")
		assert(writes.floatingCombatTextCombatHealing_v2 == 0,
			"Blizzard healing text was not disabled")
		assert(writes.floatingCombatTextCombatHealing == (modern and 0 or nil))
		assert(environment.SHOW_COMBAT_TEXT == "0")

		-- Given MSBT is enabled during combat.
		environment.InCombatLockdown = function() return true end
		writes = {}

		-- When suppression is requested.
		action(false, true)

		-- Then suppression waits until the post-combat settings application.
		assert(next(writes) == nil)
		environment.InCombatLockdown = function() return false end
		action(false, true)
		assert(writes.enableFloatingCombatText == 0)
		assert(writes.floatingCombatTextCombatDamage_v2 == 0)

		-- Given a client without the optional legacy refresh function.
		environment.CombatText_UpdateDisplayedMessages = nil

		-- When the damage preference is applied.
		action(enabled)

		-- Then settings still apply without needing that API.
		assert(writes.floatingCombatTextCombatDamage_v2 == (enabled and 1 or 0))

		-- Given a CVar write fails.
		environment.SetCVar = function() error("write failed") end

		-- When the preference is applied.
		local success, message = pcall(action, enabled)

		-- Then the error remains visible to the caller.
		assert(not success and message:find("write failed", 1, true))
	end
end

-- Describe: obsolete overrides migrate when selecting a profile.
local migrationBody = assert(source:match(
	"local function MigrateCombatTextOptions%b()%s*.-\nend"))
local migrate = assert(loadstring(migrationBody ..
	"\nreturn MigrateCombatTextOptions"))()

for _, oldSoloDisabled in ipairs({ true, false }) do
	-- Given an old profile with every removed override.
	local profile = {
		enableBlizzardV2CombatText = oldSoloDisabled,
		enableBlizzardV2CombatTextInGroup = true,
		disableBlizzardIncoming = true,
		disableOutgoingInGroup = true,
		disableIncomingInGroup = true,
		disableNotificationInGroup = true,
		disableStaticInGroup = true,
		normalFontSize = 24,
	}

	-- When the profile migrates.
	migrate(profile)

	-- Then solo preference remains and hidden overrides disappear.
	assert(profile.blizzardDamageEnabled == not oldSoloDisabled)
	assert(profile.normalFontSize == 24, "appearance setting changed")
	for key in pairs(profile) do
		assert(key == "blizzardDamageEnabled" or key == "normalFontSize", key)
	end

	-- Given the user changes the new checkbox.
	profile.blizzardDamageEnabled = oldSoloDisabled

	-- When selecting the profile again.
	migrate(profile)

	-- Then the new preference remains.
	assert(profile.blizzardDamageEnabled == oldSoloDisabled)
end
