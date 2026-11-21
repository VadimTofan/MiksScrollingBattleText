-- Describe: the numbers over targets follow their switch with every client setting of the group,
-- Blizzard's master leaves them alone, and the texts of the General boxes say so in both languages.
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match(
	"(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))
local build = assert(loadstring(body ..
	"\nreturn GetBlizzardSwitch, SetBlizzardSwitch, SetBlizzardCombatTextV2Enabled,"
	.. " TakeBlizzardSwitches, RestoreBlizzardSwitches"))

local NUMBERS = {
	"floatingCombatTextCombatDamage_v2", "floatingCombatTextCombatLogPeriodicSpells_v2",
	"floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2",
	"floatingCombatTextCombatHealing_v2", "floatingCombatTextCombatDamage",
	"floatingCombatTextCombatHealing",
}
local cvars, writes = {}, {}
local inCombat = false
local function ClientHasNumbers(value)
	for _, name in ipairs(NUMBERS) do cvars[name] = value end
	cvars.enableFloatingCombatText = "1"
end
local function Written(name)
	for _, write in ipairs(writes) do
		if write:match("^[^=]+") == name then return true end
	end
	return false
end
local shown = true
local env = {
	GetCVar = function(name) return cvars[name] end,
	GetCVarBool = function(name) return cvars[name] == "1" end,
	SetCVar = function(name, value)
		writes[#writes + 1] = name .. "=" .. tostring(value)
		cvars[name] = tostring(value)
	end,
	InCombatLockdown = function() return inCombat end,
	Client = { hasModernAPI = true }, IsClassic = false,
	CombatText = { Hide = function() shown = false end, Show = function() shown = true end },
	pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, pcall = pcall,
}
setfenv(build, env)
local get, set, apply, take, restore = build()

-- Given a new profile and a client with the numbers on.
local profile = { blizzardSwitches = { version = 1 } }
env.currentProfile = profile
ClientHasNumbers("1")
-- When the switch is read.
local isShown, isSet = get("numbers")
-- Then it shows the client's value and is not set.
assert(isShown == true and isSet == false, "an unset switch does not mirror the client")

-- Given the client changes the damage number elsewhere, such as in Blizzard's menu.
cvars.floatingCombatTextCombatDamage_v2 = "0"
-- When the switch is read again.
-- Then it follows the client, as the damage number is the one read.
assert(get("numbers") == false, "an unset switch does not follow the client")

-- When MSBT applies its settings, with the master on and off.
apply(true, true, profile)
apply(false, false, profile)
-- Then no setting of the unset switch is written.
for _, name in ipairs(NUMBERS) do assert(not Written(name), "an unset switch was written: " .. name) end

-- When the player hides the numbers.
writes = {}
set("numbers", false)
-- Then the profile keeps it as set and every number setting the client has is written.
isShown, isSet = get("numbers")
assert(isShown == false and isSet == true, "a click does not set the switch")
assert(profile.blizzardSwitches.numbers == 0, "a click is not kept in the profile")
for _, name in ipairs(NUMBERS) do
	if name ~= "floatingCombatTextCombatDamage_v2" then
		assert(Written(name) and cvars[name] == "0", "a click does not write " .. name)
	end
end
-- Then a setting that already has the value is not written again.
assert(not Written("floatingCombatTextCombatDamage_v2"), "a setting already right was written")

-- Given the master of Blizzard's text is switched.
-- When MSBT applies its settings with the master off, then on.
writes = {}
apply(false, true, profile)
apply(true, true, profile)
-- Then the numbers keep the switch's value and are not written.
for _, name in ipairs(NUMBERS) do
	assert(not Written(name) and cvars[name] == "0", "the master touched the numbers: " .. name)
end
assert(shown, "the master no longer shows Blizzard's frame")
apply(false, true, profile)
assert(not shown, "the master no longer hides Blizzard's frame")

-- Given the client turns two of the numbers back on elsewhere.
cvars.floatingCombatTextCombatDamage_v2 = "1"
cvars.floatingCombatTextPetMeleeDamage_v2 = "1"
-- When the switch is read.
-- Then it shows the profile's value.
assert(get("numbers") == false, "a set switch does not show the profile's value")
-- When MSBT applies its settings.
writes = {}
apply(true, true, profile)
-- Then the profile's value is forced again, only where it differs.
assert(cvars.floatingCombatTextCombatDamage_v2 == "0" and cvars.floatingCombatTextPetMeleeDamage_v2 == "0",
	"a set switch is not forced after an outside change")
local numberWrites = 0
for _, name in ipairs(NUMBERS) do if Written(name) then numberWrites = numberWrites + 1 end end
assert(numberWrites == 2, "settings that already had the value were written")

-- Given the player is in combat.
inCombat = true
writes = {}
-- When the numbers are shown.
set("numbers", true)
-- Then the profile keeps it and every setting is written at once, as none is secure.
assert(get("numbers") == true, "a click in combat does not set the switch")
for _, name in ipairs(NUMBERS) do assert(cvars[name] == "1", "the numbers were not written in combat") end
inCombat = false

-- Describe: an options window takes the numbers and puts them back.
-- Given the numbers set hidden and the client's numbers mixed, damage on and healing off, as
-- Blizzard's menu allows.
local restored = { blizzardSwitches = { version = 1, numbers = 0 } }
env.currentProfile = restored
ClientHasNumbers("1")
cvars.floatingCombatTextCombatHealing_v2, cvars.floatingCombatTextCombatHealing = "0", "0"
-- When they are taken and then changed.
local record = take()
set("numbers", true)
cvars.floatingCombatTextCombatDamage_v2 = "0"
-- When they are put back, in combat.
inCombat = true
restore(record)
inCombat = false
-- Then the switch is set as it was and every client setting has its own value back.
assert(restored.blizzardSwitches.numbers == 0, "a restore does not put the marks back")
assert(cvars.floatingCombatTextCombatDamage_v2 == "1" and cvars.floatingCombatTextCombatHealing_v2 == "0"
	and cvars.floatingCombatTextCombatHealing == "0", "mixed client values do not survive a restore")

-- Given a profile with another value than 1 or 0, as from an edited import, and the numbers on.
local crafted = { blizzardSwitches = { version = 1, numbers = 5 } }
env.currentProfile = crafted
ClientHasNumbers("1")
writes = {}
-- When MSBT applies its settings.
apply(true, true, crafted)
-- Then nothing is written and the switch counts as not set.
for _, name in ipairs(NUMBERS) do assert(not Written(name), "a stored value other than 1 or 0 was written") end
isShown, isSet = get("numbers")
assert(isShown == true and isSet == false, "a stored value other than 1 or 0 counts as set")

-- Given a classic client.
env.IsClassic = true
local classic = assert(loadstring(body .. "\nreturn GetBlizzardSwitch, SetBlizzardSwitch"))
setfenv(classic, env)
local _, classicSet = classic()
ClientHasNumbers("1")
env.currentProfile = { blizzardSwitches = { version = 1 } }
-- When the numbers are hidden.
classicSet("numbers", false)
-- Then the old healing setting is left alone and the rest follows.
assert(cvars.floatingCombatTextCombatHealing == "1", "the old healing setting was written on classic")
assert(cvars.floatingCombatTextCombatHealing_v2 == "0", "the numbers do not follow on classic")
env.IsClassic = false

-- Describe: the reset action shows the numbers again where no profile keeps them.
-- Given the reset action, before a profile is selected, and a client with the numbers hidden.
local resetSource = assert(source:match(
	"local function ResetOfficialBlizzardCombatText%b()%s*.-\nend"))
local buildReset = assert(loadstring(body .. resetSource .. "\nreturn ResetOfficialBlizzardCombatText"))
env.module = { ApplyContextOptions = function() end }
env.SetOption = function() end
setfenv(buildReset, env)
local reset = buildReset()
env.currentProfile = nil
ClientHasNumbers("0")
-- When it runs.
reset()
-- Then every number is shown again.
for _, name in ipairs(NUMBERS) do assert(cvars[name] == "1", name .. " stayed hidden without a profile") end
-- Given a profile without the table of switches.
env.currentProfile = {}
ClientHasNumbers("0")
-- When it runs.
reset()
-- Then the numbers are shown again and no table is made.
for _, name in ipairs(NUMBERS) do assert(cvars[name] == "1", name .. " stayed hidden without the table") end
assert(env.currentProfile.blizzardSwitches == nil, "the reset made a table of switches")

-- Given the English and German texts of the General boxes.
local function Read(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local english = Read("MSBTOptions/Localization/localization.lua")
local german = Read("MSBTOptions/Localization/localization.de.lua")
-- Then Blizzard's outgoing box has its own tooltip in each.
assert(english:find("\tblizzardTooltip = ", 1, true), "Blizzard's outgoing box has no English tooltip")
assert(german:find("L.CHECKBOXES.disableOutgoing.blizzardTooltip = ", 1, true),
	"Blizzard's outgoing box has no German tooltip")
-- Then that tooltip says the box shows the game's setting until it is set here, by a click or
-- by enabling MSBT.
assert(english:find("until it is set here, by a click or by enabling MSBT", 1, true),
	"the English outgoing tooltip does not say when the box is set")
assert(german:find("bis sie hier gesetzt wird, per Klick oder durch Aktivieren von MSBT", 1, true),
	"the German outgoing tooltip does not say when the box is set")
-- Then enabling MSBT says it leaves the effect texts on targets alone.
assert(english:find("turn off Blizzard's combat text, except the effect texts on targets", 1, true),
	"the English MSBT tooltip does not leave out the effect texts")
assert(german:find("L.CHECKBOXES.enableMSBT.tooltip = \"MSBT aktivieren und Blizzards Kampftext "
	.. "deaktivieren, außer den Effekten auf Zielen.\"", 1, true),
	"the German MSBT tooltip does not leave out the effect texts")
print("Blizzard numbers switch tests passed")
