local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: combat text settings are written only when they change.
-- The function is taken with the switches of the client's text settings, which it applies.
local body = assert(source:match(
	"(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))
local build = assert(loadstring(body ..
	"\nreturn SetBlizzardCombatTextV2Enabled"))

local cvars, writes, action
local function Environment(getCVar)
	writes = {}
	local frame = { Hide = function() end, Show = function() end }
	local environment = {
		Client = { hasModernAPI = true }, IsClassic = false,
		CombatText = frame,
		SetCVar = function(name, value)
			writes[#writes + 1] = name
			cvars[name] = tostring(value)
		end,
		GetCVar = getCVar,
		pcall = pcall, tostring = tostring,
		pairs = pairs, ipairs = ipairs, type = type,
	}
	setfenv(build, environment)
	action = build()
	return environment
end
local function Read(name) return cvars[name] end

-- Given the game's settings as a fresh client has them.
cvars = { enableFloatingCombatText = "0", floatingCombatTextCombatDamage_v2 = "1" }
Environment(Read)

-- When MSBT applies its profile: Blizzard's damage off by its switch, its text hidden. Blizzard's
-- master, the first argument, no longer writes the numbers over targets. They follow the switch
-- the profile keeps in blizzardSwitches, which is written only where the client's value differs.
local profile = { blizzardSwitches = { version = 1, numbers = 0 } }
action(false, true, profile)

-- Then what differed was written.
assert(cvars.enableFloatingCombatText == "1")
assert(cvars.floatingCombatTextCombatDamage_v2 == "0")
assert(#writes > 0, "nothing written on the first apply")

-- When the same profile is applied again, as each fight starts and ends.
Environment(Read)
action(false, true, profile)
action(false, true, profile)

-- Then nothing is written: no CVAR_UPDATE for settings already right.
assert(#writes == 0, "rewrote unchanged settings: " .. table.concat(writes, ", "))

-- When the player turns Blizzard's damage back on, with its switch.
Environment(Read)
profile.blizzardSwitches.numbers = 1
action(false, true, profile)

-- Then only the damage settings change.
for _, name in ipairs(writes) do
	assert(name:find("Damage", 1, true) or name:find("PeriodicSpells", 1, true),
		"changed an unrelated setting: " .. name)
end
assert(cvars.floatingCombatTextCombatDamage_v2 == "1")

-- Given a client where reading a setting fails.
Environment(function() error("no such cvar") end)

-- When the profile is applied.
action(false, true)

-- Then the settings are still written, as before: without a profile that is the feed alone,
-- although it is already on.
assert(writes[1] == "enableFloatingCombatText")
assert(#writes > 0)

-- Given a client with no way to read settings.
Environment(nil)
action(true, true)

-- Then every setting is written, as before: the feed, and no number, as the master no longer
-- writes them.
assert(writes[1] == "enableFloatingCombatText")
assert(#writes == 1)
