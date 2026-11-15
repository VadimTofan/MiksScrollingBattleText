local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()

-- Describe: combat text settings are written only when they change.
local body = assert(source:match(
	"local function SetBlizzardCombatTextV2Enabled%b()%s*.-\nend"))
local action = assert(loadstring(body ..
	"\nreturn SetBlizzardCombatTextV2Enabled"))()

local cvars, writes
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
	}
	setfenv(action, environment)
	return environment
end
local function Read(name) return cvars[name] end

-- Given the game's settings as a fresh client has them.
cvars = { enableFloatingCombatText = "0", floatingCombatTextCombatDamage_v2 = "1" }
Environment(Read)

-- When MSBT applies its profile: Blizzard's damage off, its text hidden.
action(false, true)

-- Then what differed was written.
assert(cvars.enableFloatingCombatText == "1")
assert(cvars.floatingCombatTextCombatDamage_v2 == "0")
assert(#writes > 0, "nothing written on the first apply")

-- When the same profile is applied again, as each fight starts and ends.
Environment(Read)
action(false, true)
action(false, true)

-- Then nothing is written: no CVAR_UPDATE for settings already right.
assert(#writes == 0, "rewrote unchanged settings: " .. table.concat(writes, ", "))

-- When the player turns Blizzard's damage back on.
Environment(Read)
action(true, true)

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

-- Then the settings are still written, as before.
assert(cvars.floatingCombatTextCombatDamage_v2 == "0")
assert(#writes > 0)

-- Given a client with no way to read settings.
Environment(nil)
action(true, true)

-- Then every setting is written, as before.
assert(cvars.floatingCombatTextCombatDamage_v2 == "1")
assert(#writes >= 5)
