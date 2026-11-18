-- Describe: a switch for a client setting mirrors the client until the player sets it in a profile,
-- then the profile's value is written each time MSBT applies its settings.
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match(
	"(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))
-- The rules are shown on three switches of this test's own, so they hold for any switch the addon
-- enters: one with two client settings behind it, and two with one setting each.
local PAIR = { "testPairFirst", "testPairSecond" }
local SINGLE = "testSingle"
local OTHER = "testOther"
local build = assert(loadstring(body
	.. '\nBLIZZARD_SWITCH_SETTINGS.pair = { "testPairFirst", "testPairSecond" }'
	.. '\nBLIZZARD_SWITCH_SETTINGS.single = { "testSingle" }'
	.. '\nBLIZZARD_SWITCH_SETTINGS.other = { "testOther" }'
	.. "\nreturn GetBlizzardSwitch, SetBlizzardSwitch, SetBlizzardCombatTextV2Enabled,"
	.. " TakeBlizzardSwitches, RestoreBlizzardSwitches"))
assert(source:find("module.GetBlizzardSwitch", 1, true), "Get is not exported")
assert(source:find("module.SetBlizzardSwitch", 1, true), "Set is not exported")
assert(source:find("module.TakeBlizzardSwitches", 1, true), "Take is not exported")
assert(source:find("module.RestoreBlizzardSwitches", 1, true), "Restore is not exported")

local cvars, writes = {}, {}
local inCombat = false
-- Whether one of this test's settings was written, and how many of them were.
local function Written(name)
	for _, write in ipairs(writes) do
		if write:match("^[^=]+") == name then return true end
	end
	return false
end
local function TestWrites()
	local count = 0
	for _, write in ipairs(writes) do
		if write:find("^test") then count = count + 1 end
	end
	return count
end
local env = {
	GetCVar = function(name) return cvars[name] end,
	GetCVarBool = function(name) return cvars[name] == "1" end,
	SetCVar = function(name, value)
		writes[#writes + 1] = name .. "=" .. tostring(value)
		cvars[name] = tostring(value)
	end,
	InCombatLockdown = function() return inCombat end,
	Client = { hasModernAPI = true }, IsClassic = false,
	CombatText = { Hide = function() end, Show = function() end },
	pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, pcall = pcall,
}
setfenv(build, env)
local get, set, apply, take, restore = build()

-- Given a new profile and a client with the pair on and the two single settings off.
local profile = { blizzardSwitches = { version = 1 } }
env.currentProfile = profile
cvars[PAIR[1]], cvars[PAIR[2]] = "1", "1"
cvars[SINGLE], cvars[OTHER] = "0", "0"
-- When the switches are read.
local isShown, isSet = get("pair")
-- Then each shows the client's value and is not set.
assert(isShown == true and isSet == false, "an unset switch does not mirror the client")
assert(get("single") == false and get("other") == false,
	"an unset switch does not mirror the client")

-- Given the client changes the first setting of the pair elsewhere, such as in Blizzard's menu.
cvars[PAIR[1]] = "0"
-- When the switch is read again.
-- Then it follows the client, by its first setting.
assert(get("pair") == false, "an unset switch does not follow the client")

-- When MSBT applies its settings, with the master on and off.
apply(true, true, profile)
apply(false, false, profile)
-- Then no setting of an unset switch is written.
assert(TestWrites() == 0, "an unset switch was written")

-- When the player hides the pair.
writes = {}
set("pair", false)
-- Then the profile keeps it as set and every setting of the switch is written.
isShown, isSet = get("pair")
assert(isShown == false and isSet == true, "a click does not set the switch")
assert(profile.blizzardSwitches.pair == 0, "a click is not kept in the profile")
assert(Written(PAIR[2]) and cvars[PAIR[2]] == "0", "a click does not write " .. PAIR[2])
-- Then a setting that already has the value is not written again.
assert(not Written(PAIR[1]), "a setting already right was written")

-- Given the client turns both settings back on elsewhere.
cvars[PAIR[1]], cvars[PAIR[2]] = "1", "1"
-- When the switch is read.
-- Then it shows the profile's value.
assert(get("pair") == false, "a set switch does not show the profile's value")
-- When MSBT applies its settings, after one of the two was put right elsewhere.
cvars[PAIR[2]] = "0"
writes = {}
apply(true, true, profile)
-- Then the profile's value is forced again, only where it differs.
assert(cvars[PAIR[1]] == "0" and cvars[PAIR[2]] == "0", "a set switch is not forced after an outside change")
assert(TestWrites() == 1, "settings that already had the value were written")
-- Given the client turns the first setting on again elsewhere.
cvars[PAIR[1]] = "1"
-- When MSBT applies its settings while it is turned off.
apply(false, false, profile)
-- Then the set switch is forced all the same.
assert(cvars[PAIR[1]] == "0", "a set switch is not forced while MSBT is turned off")

-- Given the player is in combat.
inCombat = true
writes = {}
-- When the pair is shown.
set("pair", true)
-- Then the profile keeps it and every setting is written at once, as none is secure.
assert(get("pair") == true, "a click in combat does not set the switch")
assert(cvars[PAIR[1]] == "1" and cvars[PAIR[2]] == "1", "a switch was not written in combat")
-- When a single setting is shown in combat.
set("single", true)
-- Then it is written at once too, and it alone.
assert(cvars[SINGLE] == "1" and cvars[OTHER] == "0", "a switch was not written in combat")

-- Given the client changed that single setting elsewhere, still in combat.
cvars[SINGLE] = "0"
-- When MSBT applies its settings.
apply(true, true, profile)
-- Then nothing is written, as the profile is applied again when the fight ends.
assert(cvars[SINGLE] == "0", "a switch was forced while MSBT applied its settings in combat")
inCombat = false
-- When MSBT applies its settings after the fight.
apply(true, true, profile)
-- Then the set switch is forced and the unset one stays as the client has it.
assert(cvars[SINGLE] == "1" and cvars[OTHER] == "0", "a set switch is not forced")
assert(select(2, get("other")) == false, "an unset switch reads as set")

-- Given another profile with the pair hidden and the single switch unset.
local other = { blizzardSwitches = { version = 1, pair = 0 } }
env.currentProfile = other
-- When it is the current one and MSBT applies its settings.
apply(true, true, other)
-- Then its values are forced and the first profile's single switch is not.
assert(cvars[PAIR[1]] == "0", "a switch of the current profile is not forced")
cvars[SINGLE] = "0"
apply(true, true, other)
assert(cvars[SINGLE] == "0", "a switch of another profile was forced")
assert(get("single") == false, "a switch of another profile shows")

-- Given a client without the two single settings.
cvars[SINGLE], cvars[OTHER] = nil, nil
other.blizzardSwitches.single = 1
writes = {}
-- When they are read and applied.
apply(true, true, other)
-- Then they are not written and read as missing.
assert(not Written(SINGLE) and cvars[SINGLE] == nil, "a missing setting was written")
isShown, isSet = get("single")
assert(isShown == nil and isSet == true, "a missing setting is not nil")
isShown, isSet = get("other")
assert(isShown == nil and isSet == false, "a missing setting of an unset switch reads as set")
-- Given a client that has only the second setting of the pair.
cvars[PAIR[1]] = nil
-- When the pair is read, then it is missing too, as its first setting stands for the switch.
assert(get("pair") == nil, "a switch without its first setting is not missing")
cvars[PAIR[1]] = "0"

-- When an unknown switch is set or read.
writes = {}
set("elsewhere", true)
-- Then nothing is written or kept.
assert(#writes == 0 and other.blizzardSwitches.elsewhere == nil, "an unknown switch was written")
assert(get("elsewhere") == nil, "an unknown switch reads as present")

-- Given a profile without the table of switches.
local bare = {}
env.currentProfile = bare
cvars[SINGLE] = "0"
-- When a switch is set.
set("single", true)
-- Then the table is made, with its version, and the value is written.
assert(bare.blizzardSwitches and bare.blizzardSwitches.version == 1
	and bare.blizzardSwitches.single == 1, "a switch is not kept in a profile without the table")
assert(cvars[SINGLE] == "1", "a switch of a profile without the table is not written")

-- Given a profile whose entry for the switches is not a table, as from an edited saved file.
local edited = { blizzardSwitches = true }
env.currentProfile = edited
cvars[SINGLE] = "0"
-- When a switch is read and then set.
isShown, isSet = get("single")
set("single", true)
-- Then it read as not set, and the click made the table anew and is kept.
assert(isShown == false and isSet == false, "a switch reads as set from an entry that is no table")
assert(type(edited.blizzardSwitches) == "table" and edited.blizzardSwitches.single == 1,
	"a switch is not kept where the entry was no table")

-- Describe: an options window takes the switches and the client's values, and puts both back.
-- Given the pair set hidden, one single switch set shown, the other unset, and the client's pair
-- mixed, the first on and the second off, as Blizzard's menu allows.
local restored = { blizzardSwitches = { version = 1, pair = 0, other = 1 } }
env.currentProfile = restored
cvars[PAIR[1]], cvars[PAIR[2]], cvars[OTHER] = "1", "0", "1"
-- Given a client without the setting of the unset switch.
cvars[SINGLE] = nil
-- When they are taken and then changed in every way.
local record = take()
set("pair", true)
set("other", false)
restored.blizzardSwitches.single = 1
cvars[PAIR[1]] = "0"
-- Given the client turns the single setting back on by itself.
cvars[OTHER] = "1"
-- When they are put back, in combat.
inCombat = true
writes = {}
restore(record)
inCombat = false
-- Then each switch is set as it was, or not set.
assert(restored.blizzardSwitches.pair == 0 and restored.blizzardSwitches.other == 1
	and restored.blizzardSwitches.single == nil, "a restore does not put the marks back")
-- Then every client setting has its own value back, mixed values included.
assert(cvars[PAIR[1]] == "1" and cvars[PAIR[2]] == "0" and cvars[OTHER] == "1",
	"mixed client values do not survive a restore")
-- Then a setting the client lacks is skipped, and one that already has its value is not written.
assert(not Written(SINGLE) and cvars[SINGLE] == nil, "a restore wrote a missing setting")
assert(#writes == 2, "a restore wrote a setting that already had the value")
-- Given a profile without the table of switches, and a client that loses a setting after the take.
local plain = {}
env.currentProfile = plain
record = take()
-- Then the take alone makes no table in the profile.
assert(plain.blizzardSwitches == nil, "taking the switches changed the profile")
set("other", false)
cvars[OTHER] = nil
-- When it is put back.
restore(record)
-- Then no switch is set and the lost setting is not written.
assert(plain.blizzardSwitches.other == nil, "a restore does not put the marks back")
assert(cvars[OTHER] == nil, "a restore wrote a missing setting")
-- When something else than a record is put back.
writes = {}
restore(nil)
restore("record")
-- Then nothing is written.
assert(#writes == 0, "a restore without a record wrote a setting")

-- Given no profile is selected yet, and a client with the pair on.
env.currentProfile = nil
cvars[PAIR[1]], cvars[PAIR[2]] = "1", "1"
writes = {}
-- When a switch is read, set, taken and put back.
isShown, isSet = get("pair")
set("pair", false)
restore(take())
-- Then it shows the client's value as not set, and nothing is written.
assert(isShown == true and isSet == false, "a switch without a profile does not mirror the client")
assert(#writes == 0, "a switch without a profile was written")

-- Describe: only 1 and 0 count as stored values.
-- Given a profile with other values, as from an edited import, and a client with every setting on.
local crafted = { blizzardSwitches = { version = 1, pair = 5, single = true, bogus = 2 } }
env.currentProfile = crafted
cvars[PAIR[1]], cvars[PAIR[2]], cvars[SINGLE], cvars[OTHER] = "1", "1", "1", "1"
writes = {}
-- When MSBT applies its settings.
apply(true, true, crafted)
-- Then nothing is written and the switches count as not set.
assert(TestWrites() == 0, "a stored value other than 1 or 0 was written")
isShown, isSet = get("pair")
assert(isShown == true and isSet == false, "a stored value other than 1 or 0 counts as set")
assert(select(2, get("single")) == false, "a stored value other than 1 or 0 counts as set")
print("Blizzard switch tests passed")
