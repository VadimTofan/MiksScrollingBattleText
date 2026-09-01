MikSBT = {
	Services = {},
}

local profile = {
	shortenNumbers = false,
	shortenNumberPrecision = 0,
	groupNumbers = false,
	partialColoringDisabled = true,
	damageColoringDisabled = false,
	classColoringDisabled = false,
	abbreviateAbilities = true,
	abilitySubstitutions = {},
	physical = {
		colorR = 1,
		colorG = 0,
		colorB = 0,
	},
	DRUID = {
		colorR = 1,
		colorG = 0.5,
		colorB = 0,
	},
	absorb = {
		disabled = false,
		trailer = " (%a absorbed)",
		colorR = 1,
		colorG = 1,
		colorB = 1,
	},
}

local Formatter = dofile("Services/Formatter.lua")
Formatter:Configure({
	getProfile = function()
		return profile
	end,
	shortenNumber = function(amount)
		return amount == 4500 and "4.5k" or tostring(amount)
	end,
	formatLargeNumber = function(amount)
		return amount == 4500 and "4,500" or tostring(amount)
	end,
	damageColorEntries = {
		[1] = "physical",
	},
	damageTypes = {
		[1] = "Physical",
	},
	powerTokens = {},
	isEnglish = true,
	unknown = "Unknown",
	unknownSchool = "Unknown",
})

-- Given / When
local amount = Formatter:FormatDisplayAmount(4500)
local message = Formatter:FormatEvent({
	message = "%n - %s: %a (%t)",
	amount = 4500,
	damageType = 1,
	name = "Tester-Realm",
	class = "DRUID",
	effectName = "Ferocious Bite",
})
local hiddenName = Formatter:FormatEvent({
	message = "%n - %a",
	amount = 4500,
	name = "Restricted",
	hideNames = true,
})

-- Then
assert(amount == "4,500", "large number formatting changed")
assert(string.find(message, "4,500", 1, true), "amount token was not replaced")
assert(string.find(message, "Tester", 1, true), "realm was not removed")
assert(not string.find(message, "Realm", 1, true), "realm remained in output")
assert(string.find(message, "FB", 1, true), "ability abbreviation changed")
assert(string.find(message, "Physical", 1, true), "damage type was not replaced")
assert(string.find(message, "|cFFff0000", 1, true),
	"damage coloring was not applied")
assert(hiddenName == " - 4,500", "hidden-name formatting changed")
assert(Formatter:FormatPartialEffects(4500) == " (4500 absorbed)",
	"partial amounts were grouped while groupNumbers was disabled")

-- Given grouped partial-effect numbers
profile.groupNumbers = true

-- When / Then
assert(Formatter:FormatPartialEffects(4500) == " (4,500 absorbed)",
	"partial amounts were not grouped")

-- Given short-number formatting
profile.shortenNumbers = true

-- When / Then
assert(Formatter:FormatDisplayAmount(4500) == "4.5k",
	"short number formatting changed")
