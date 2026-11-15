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
-- Given short-number formatting
profile.shortenNumbers = true

-- When / Then
assert(Formatter:FormatDisplayAmount(4500) == "4.5k",
	"short number formatting changed")

-- Given an older profile that disabled all school coloring and this school.
profile.damageColoringDisabled = true
profile.physical.disabled = true

-- When readable and hidden damage numbers use their school palette.
local baseline = Formatter:FormatEvent({ message = "Hit %a", amount = 4500,
	damageType = 1 })
local hiddenTemplate = Formatter:BuildRestrictedTemplate("Hit %a", nil, 1)

-- Then school coloring is baseline, while unknown schools keep event colors.
assert(baseline == "Hit |cFFff00004.5k|r",
	"legacy disabled flags suppressed baseline school coloring")
assert(hiddenTemplate == "Hit |cFFff0000%s|r",
	"legacy disabled flags suppressed hidden school coloring")
assert(Formatter:ColorDamageAmount("42", 999) == "42")

-- Describe: a partial effect's trailer.
-- Given the Block partial effect's text and color.
local block = { trailer = " <%a blocked>", colorR = 0.5, colorG = 0, colorB = 1 }
profile.shortenNumbers = false
profile.partialColoringDisabled = false

-- When a known and an unknown amount are formatted.
-- Then the known amount is shown, and the unknown one drops its number.
assert(Formatter:FormatPartialTrailer(block, 4500)
	== "|cFF7f00ff <4,500 blocked>|r", "a blocked amount lost its trailer")
assert(Formatter:FormatPartialTrailer(block, nil)
	== "|cFF7f00ff <blocked>|r", "an unknown amount kept its placeholder")

-- Given partial coloring off, and then the partial effect itself off.
profile.partialColoringDisabled = true
-- Then the trailer is plain, and then empty.
assert(Formatter:FormatPartialTrailer(block, 12) == " <12 blocked>")
block.disabled = true
assert(Formatter:FormatPartialTrailer(block, 12) == "",
	"a disabled partial effect was still shown")

-- Given the profile's Block partial effect.
block.disabled = nil
profile.block = block
-- When combat engine records are formatted.
-- Then only a partly blocked hit has a trailer, and none while Block is off.
assert(Formatter:FormatBlockedTrailer({ blocked = true, blockedAmount = 3 })
	== " <3 blocked>", "a partly blocked record lost its trailer")
assert(Formatter:FormatBlockedTrailer({ amount = 3 }) == nil,
	"an unblocked record gained a trailer")
block.disabled = true
assert(Formatter:FormatBlockedTrailer({ blocked = true }) == nil,
	"a disabled Block partial effect was still shown")
