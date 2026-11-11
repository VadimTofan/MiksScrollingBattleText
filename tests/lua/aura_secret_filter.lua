-- Describe: native aura filtering keeps comparisons and visibility opaque.
MikSBT = { API = {}, Configuration = {}, Components = {}, Display = {} }
local contents = setmetatable({}, { __mode = "k" })
local function Secret(value)
	local token = setmetatable({}, {
		__tostring = function() error("secret inspected as text") end,
		__concat = function() error("secret concatenated in Lua") end,
	})
	contents[token] = { value }
	return token
end
local function Read(value)
	local stored = contents[value]
	if stored then return stored[1] end
	return value
end
issecretvalue = function(value) return contents[value] ~= nil end
dofile("API/RestrictedValue.lua")
C_Spell = { GetSpellInfo = function(id)
	if id == 1459 then return { name = "Arcane Intellect", spellID = id } end
end }
dofile("API/Spells.lua")
local Tracking = dofile("Configuration/AuraTracking.lua")
Enum = {
	CollationStrength = { Identical = 4 }, NormalizationForm = { Nfc = 1 },
}
local comparisons = 0
C_Intl = {
	CompareStrings = function(left, right)
		comparisons = comparisons + 1
		left, right = Read(left), Read(right)
		if left == right then return Secret(0) end
		return Secret(left < right and -1 or 1)
	end,
	IsNormalized = function(text)
		return Secret(not Read(text):find("e\204\129", 1, true))
	end,
}
C_StringUtil = {
	TruncateWhenZero = function(value)
		value = Read(value)
		return Secret(value == 0 and "" or tostring(value))
	end,
	WrapString = function(value, prefix, suffix)
		value = Read(value)
		return Secret(value == "" and "" or prefix .. value .. suffix)
	end,
}
C_CurveUtil = { EvaluateColorValueFromBoolean = function(gate, yes, no)
	if Read(gate) then return Secret(Read(yes)) end
	return Secret(Read(no))
end }

-- Given several excluded names, an enabled name and an exact-ID exclusion.
local rules = {
	["name:Arcane Intellect"] = false, ["name:Frost Armor"] = false,
	["name:Power Word: Shield"] = true, ["1459"] = false,
}
local hiddenName = Secret("Arcane Intellect")
-- When the secret matching and unrelated names are filtered natively.
assert(type(Tracking.SecretVisibility) == "function",
	"native secret-name filtering is missing")
local matching = Tracking:SecretVisibility(rules, hiddenName)
local other = Tracking:SecretVisibility(rules, Secret("Power Word: Shield"))
-- Then the results stay secret and only excluded names become invisible.
assert(issecretvalue(matching.visible) and not Read(matching.visible))
assert(issecretvalue(other.visible) and Read(other.visible))
assert(comparisons == 4, "ID or enabled-name rules entered native matching")

-- Given an exact-ID rule with no excluded names.
-- When its secret name cannot establish a rank.
local exactOnly = Tracking:SecretVisibility({ ["1459"] = false }, hiddenName)
-- Then it cannot be filtered by name as though every rank were excluded.
assert(exactOnly == nil)

-- Given the real presentation and display services.
local profile = { auraTracking = rules, events = {
	NOTIFICATION_BUFF = { message = "+[%sl]", soundFile = "alert.ogg" },
	NOTIFICATION_BUFF_FADE = { message = "-[%sl] faded" },
} }
local calls, sounds = {}, 0
local Service = dofile("Display/DisplayService.lua")
Service:Configure({
	getProfile = function() return profile end,
	isModDisabled = function() return false end,
	scrollAreas = { Resolve = function() return {} end }, fonts = {},
	display = function(...) calls[#calls + 1] = { args = {...} } end,
	displayWithVisibility = function(visibility, ...)
		calls[#calls + 1] = { visibility = visibility, args = {...} }
	end,
	playSound = function() sounds = sounds + 1 end,
})
local Presentation = dofile("Components/CombatPresentation.lua")
local presentation = Presentation:New({
	getProfile = function() return profile end,
	displayRestricted = function(settings, value, icon, message)
		Service:DisplayEvent(settings, message, icon, nil, value)
	end,
})
-- When a secret gain and fade reach the real display boundary.
presentation:Aura(true, false, hiddenName, "aura-icon")
presentation:Aura(false, false, hiddenName, "aura-icon")
-- Then their full rendering is gated, including any icon, without mutation.
assert(calls[1].visibility and not Read(calls[1].visibility.visible))
assert(calls[2].visibility and not Read(calls[2].visibility.visible))
assert(calls[1].args[1] == "+[%a]" and calls[1].args[11] == "aura-icon")
assert(calls[1].args[12] == hiddenName)
assert(profile.events.NOTIFICATION_BUFF.auraVisibility == nil)
assert(sounds == 0, "a gated secret aura played an unfilterable sound")
assert(profile.events.NOTIFICATION_BUFF.soundFile == "alert.ogg")

-- Given a missing helper or a helper that returns no comparison.
local compare = C_Intl.CompareStrings
C_Intl.CompareStrings = nil
-- When native filtering is unavailable.
local missing = Tracking:SecretVisibility(rules, hiddenName)
C_Intl.CompareStrings = function() end
local unavailable = Tracking:SecretVisibility(rules, hiddenName)
C_Intl.CompareStrings = function() error("unsupported native argument") end
local failed = Tracking:SecretVisibility(rules, hiddenName)
-- Then the original display remains available instead of hiding every aura.
assert(missing == nil and unavailable == nil and failed == nil)
presentation:Aura(true, false, hiddenName, "aura-icon")
assert(calls[#calls].visibility == nil)
C_Intl.CompareStrings = compare
print("Native secret aura filtering tests passed")
