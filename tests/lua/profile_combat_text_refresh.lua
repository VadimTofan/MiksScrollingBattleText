local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: the numbers over targets follow their own switch, not Blizzard's master.
local numberSettings = {
	floatingCombatTextCombatDamage = true,
	floatingCombatTextCombatDamage_v2 = true,
	floatingCombatTextCombatLogPeriodicSpells_v2 = true,
	floatingCombatTextPetMeleeDamage_v2 = true,
	floatingCombatTextPetSpellDamage_v2 = true,
	floatingCombatTextCombatHealing_v2 = true,
	floatingCombatTextCombatHealing = true,
}
local body = assert(source:match(
	"(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))

for _, modern in ipairs({ true, false }) do
	for _, enabled in ipairs({ true, false }) do
		-- Given the numbers set the other way from Blizzard's master, and the client as the master.
		local cvars, writes, refreshes = {}, {}, 0
		for name in pairs(numberSettings) do cvars[name] = enabled and "1" or "0" end
		local wanted = enabled and "0" or "1"
		local profile = { blizzardSwitches = { version = 1, numbers = tonumber(wanted) } }
		local shown = true
		local blizzardFrame = {
			Hide = function() shown = false end,
			Show = function() shown = true end,
		}
		local environment = {
			Client = { hasModernAPI = modern },
			IsClassic = not modern,
			SHOW_COMBAT_TEXT = "unchanged",
			CombatText = blizzardFrame,
			GetCVar = function(name) return cvars[name] end,
			SetCVar = function(name, value)
				writes[name] = value
				cvars[name] = tostring(value)
			end,
			CombatText_UpdateDisplayedMessages = function()
				refreshes = refreshes + 1
			end,
			pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, pcall = pcall,
		}
		local action = assert(loadstring(body .. "\nreturn SetBlizzardCombatTextV2Enabled"))
		setfenv(action, environment)
		action = action()

		-- When the master is applied without a profile.
		action(enabled)

		-- Then nothing is written and only the old client refreshes its text.
		assert(next(writes) == nil, "the master wrote a setting without a profile")
		assert(environment.SHOW_COMBAT_TEXT == "unchanged")
		assert(refreshes == (modern and 0 or 1))

		-- When the master is applied with the profile.
		action(enabled, false, profile)

		-- Then the numbers follow their switch and nothing else changes but MSBT's feed.
		for name in pairs(numberSettings) do
			if name == "floatingCombatTextCombatHealing" and not modern then
				assert(writes[name] == nil, "the old healing setting was written on a classic client")
			else
				assert(writes[name] == wanted, name .. " did not follow its switch")
			end
		end
		for name in pairs(writes) do
			assert(numberSettings[name] or name == "enableFloatingCombatText",
				"changed unrelated text: " .. name)
		end

		-- Given a checkbox change during combat.
		environment.InCombatLockdown = function() return true end
		profile.blizzardSwitches.numbers = tonumber(enabled and "1" or "0")
		writes = {}

		-- When the preference is applied.
		action(enabled, false, profile)

		-- Then settings wait until combat ends.
		assert(next(writes) == nil, "damage settings changed during combat")
		environment.InCombatLockdown = function() return false end
		action(enabled, false, profile)
		assert(writes.floatingCombatTextCombatDamage_v2 == (enabled and "1" or "0"))

		-- Given MSBT needs aura notices while Blizzard text stays hidden, and the feed is off.
		writes = {}
		cvars.enableFloatingCombatText = "0"

		-- When MSBT's suppression policy applies.
		action(false, true)

		-- Then the event feed stays enabled while Blizzard's frame is hidden.
		assert(writes.enableFloatingCombatText == 1,
			"suppression disabled MSBT's aura event feed")
		assert(not shown, "Blizzard self combat text remained visible")
		assert(environment.SHOW_COMBAT_TEXT == "1")
		-- Then the numbers are left to their switch.
		for name in pairs(numberSettings) do
			assert(writes[name] == nil, name .. " was written by the suppression")
		end

		-- Given Blizzard's combat-text addon has not loaded yet.
		environment.CombatText = nil
		local loaded
		environment.C_AddOns = { LoadAddOn = function(name)
			loaded = name
			environment.CombatText = blizzardFrame
			shown = true
		end }
		-- When suppression is applied before the frame exists.
		action(false, true)
		-- Then its frame is loaded and hidden before normal gameplay.
		assert(loaded == "Blizzard_CombatText" and not shown)

		-- Given MSBT is enabled during combat, with the feed off.
		environment.InCombatLockdown = function() return true end
		writes = {}
		cvars.enableFloatingCombatText = "0"

		-- When suppression is requested.
		action(false, true)

		-- Then suppression waits until the post-combat settings application.
		assert(next(writes) == nil)
		environment.InCombatLockdown = function() return false end
		action(false, true)
		assert(writes.enableFloatingCombatText == 1)

		-- Given a client without the optional legacy refresh function.
		environment.CombatText_UpdateDisplayedMessages = nil
		cvars.floatingCombatTextCombatDamage_v2 = "2"

		-- When the preference is applied.
		action(enabled)
		action(enabled, false, profile)

		-- Then settings still apply without needing that API.
		assert(writes.floatingCombatTextCombatDamage_v2 == (enabled and "1" or "0"))
		assert(shown == enabled, "the master did not show or hide Blizzard's frame")

		-- Given a CVar write fails, and the feed is off, so it has to be written.
		environment.SetCVar = function() error("write failed") end
		cvars.enableFloatingCombatText = "0"

		-- When the preference is applied.
		local success, message = pcall(action, enabled, false, profile)

		-- Then the error remains visible to the caller.
		assert(not success and message:find("write failed", 1, true))
	end
end

-- Describe: obsolete overrides migrate when selecting a profile.
local migrationBody = assert(source:match(
	"local function MigrateCombatTextOptions%b()%s*.-\nend"))
local storedBody = assert(source:match("local function StoredBlizzardSwitch%b()%s*.-\nend"))
local migrate = assert(loadstring(storedBody .. "\n" .. migrationBody ..
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
		assert(key == "blizzardDamageEnabled" or key == "normalFontSize"
			or key == "blizzardSwitches", key)
	end
	-- Then the numbers over targets are set as MSBT wrote them, and no other switch is set.
	local switches = profile.blizzardSwitches
	assert(switches and switches.version == 2, "an old profile got no switches")
	assert(switches.numbers == (oldSoloDisabled and 0 or 1),
		"an old profile does not keep the numbers MSBT wrote")
	for name in pairs(switches) do
		assert(name == "version" or name == "numbers", "an old profile set another switch: " .. name)
	end

	-- Given the user changes the new checkbox and the numbers.
	profile.blizzardDamageEnabled = oldSoloDisabled
	switches.numbers = oldSoloDisabled and 1 or 0

	-- When selecting the profile again.
	migrate(profile)

	-- Then the new preference remains.
	assert(profile.blizzardDamageEnabled == oldSoloDisabled)
	assert(profile.blizzardSwitches == switches and switches.numbers == (oldSoloDisabled and 1 or 0),
		"a second migration changed the switches")
end

for _, outgoingDisabled in ipairs({ true, false }) do
	-- Given an old profile with Blizzard text on and its outgoing text disabled or not.
	local profile = { blizzardDamageEnabled = true, blizzardOutgoingDisabled = outgoingDisabled }
	-- When the profile migrates.
	migrate(profile)
	-- Then the numbers are set to what the two checkboxes made of them.
	assert(profile.blizzardSwitches.numbers == (outgoingDisabled and 0 or 1),
		"the old outgoing option is not kept in the numbers")
end

-- Given a profile of this version with no switch set, and its outgoing text disabled.
local fresh = { blizzardOutgoingDisabled = true, blizzardSwitches = { version = 2 } }
-- When it migrates.
migrate(fresh)
-- Then it stays without a set switch.
assert(fresh.blizzardSwitches.numbers == nil, "a new profile was migrated")

-- Given a table that another switch made, in a profile with its outgoing text disabled.
local shared = { blizzardOutgoingDisabled = true, blizzardSwitches = { version = 1, effectsOwn = 0 } }
-- When it migrates.
migrate(shared)
-- Then the numbers are taken over, the other switch stays, and the table is of version 2.
assert(shared.blizzardSwitches.numbers == 0 and shared.blizzardSwitches.effectsOwn == 0
	and shared.blizzardSwitches.version == 2, "a table of another switch kept the numbers from being taken over")

-- Given a table of version 1 with the numbers set, in a profile with its outgoing text disabled.
local chosen = { blizzardOutgoingDisabled = true, blizzardSwitches = { version = 1, numbers = 1 } }
-- When it migrates.
migrate(chosen)
-- Then the numbers stay as set, and the table is of version 2.
assert(chosen.blizzardSwitches.numbers == 1 and chosen.blizzardSwitches.version == 2,
	"a set switch was overwritten by the old options")

-- Given a table of version 1 whose numbers value is not a valid setting.
local invalid = { blizzardOutgoingDisabled = true, blizzardSwitches = { version = 1, numbers = 5 } }
-- When it migrates.
migrate(invalid)
-- Then the numbers count as not set and are taken over.
assert(invalid.blizzardSwitches.numbers == 0 and invalid.blizzardSwitches.version == 2,
	"an invalid numbers value kept the numbers from being taken over")

-- Given a profile whose switches value is not a table.
local broken = { blizzardOutgoingDisabled = true, blizzardSwitches = true }
-- When it migrates.
migrate(broken)
-- Then the value is left as it is.
assert(broken.blizzardSwitches == true, "a switches value that is no table was replaced")
