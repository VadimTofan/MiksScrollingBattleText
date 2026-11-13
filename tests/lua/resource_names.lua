-- Describe: exact resource labels are selected without inspecting secrets.
MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local values = setmetatable({}, { __mode = "k" })
local function Secret(value)
	local token = setmetatable({}, {
		__tostring = function() error("secret converted to text in Lua") end,
		__concat = function() error("secret concatenated in Lua") end,
	})
	values[token] = { value }
	return token
end
local function Read(value)
	local stored = values[value]
	if stored then return stored[1] end
	return value
end
issecretvalue = function(value) return values[value] ~= nil end
Enum = {
	CollationStrength = { Identical = 4 }, NormalizationForm = { Nfc = 1 },
}
C_Intl = {
	CompareStrings = function(left, right, strength)
		assert(strength == Enum.CollationStrength.Identical)
		left, right = Read(left), Read(right)
		if left == right then return Secret(0) end
		return Secret(left < right and -1 or 1)
	end,
	IsNormalized = function(text)
		return Secret(not Read(text):find("e\204\129", 1, true))
	end,
}
C_CurveUtil = { EvaluateColorValueFromBoolean = function(gate, yes, no)
	if Read(gate) then return Secret(Read(yes)) end
	return Secret(Read(no))
end }
C_StringUtil = {
	TruncateWhenZero = function(number)
		number = Read(number)
		return Secret(number == 0 and "" or tostring(number))
	end,
	WrapString = function(text, prefix, suffix)
		text = Read(text)
		if text == "" then return Secret("") end
		return Secret(Read(prefix) .. text .. Read(suffix))
	end,
	StripHyperlinks = function(text)
		return Secret((Read(text):gsub("|H.-|h(.-)|h", "%1")))
	end,
}
-- Emulate only the native formatting boundary; secret values stay opaque.
local format = string.format
string.format = function(template, ...)
	local arguments, hidden = { ... }, false
	for index, value in ipairs(arguments) do
		if issecretvalue(value) then hidden = true end
		arguments[index] = Read(value)
	end
	local result = format(template, unpack(arguments))
	if hidden then return Secret(result) end
	return result
end
local displayed = {}
local settings = { message = "%a - %p" }
local profile = { events = { NOTIFICATION_RESOURCE_GAIN = settings } }
local presentation = Presentation:New({
	getProfile = function() return profile end,
	displayResource = function(eventSettings, amount, name)
		displayed[#displayed + 1] = {
			amount = amount, name = name, settings = eventSettings,
		}
	end,
	after = function() error("resource label required a timer") end,
})

-- Given a readable combo-point token.
-- When its gain arrives.
presentation:Resource(1, "COMBO_POINTS")
-- Then it uses the requested singular label immediately.
assert(displayed[1].name == "Combo Point", "combo-point label was not replaced")

-- Given hidden combo points beside a separate hidden energy gain.
local amount = Secret(1)
-- When both gains arrive without power updates or timers.
presentation:Resource(amount, Secret("COMBO_POINTS"))
presentation:Resource(Secret(20), Secret("ENERGY"))
-- Then each token selects its own text and the original amount is preserved.
assert(displayed[2].amount == amount)
assert(issecretvalue(displayed[2].name))
assert(Read(displayed[2].name) == "Combo Point")
assert(Read(displayed[3].name) == "ENERGY")

-- Given tokens that are not an exact combo-point match.
for _, name in ipairs({ "MANA", "combo_points", "COMBO_POINTS_EXTRA",
	"Combo Points", "Energy supplied by Blizzard" }) do
	-- When readable and hidden forms arrive.
	presentation:Resource(2, name)
	presentation:Resource(2, Secret(name))
	-- Then neither is renamed, including localized or already formatted text.
	assert(displayed[#displayed - 1].name == name)
	assert(Read(displayed[#displayed].name) == name)
end

-- Given unavailable, failing, or invalid native helpers.
for _, library in ipairs({ C_Intl, C_StringUtil, C_CurveUtil }) do
	for key, helper in pairs(library) do
		for _, replacement in ipairs({ false, function() end,
			function() error("native helper unavailable") end }) do
			library[key] = replacement
			local token = Secret("COMBO_POINTS")
			-- When selection cannot be completed.
			presentation:Resource(amount, token)
			-- Then the exact original token remains available for display.
			assert(displayed[#displayed].name == token,
				"unavailable helper lost the original resource label: " .. key)
		end
		library[key] = helper
	end
end

-- Describe: resource checkboxes filter individual tokens in the active profile.
MikSBT.Configuration = {}
dofile("Configuration/AuraTracking.lua")
-- Given combo points and mana are unchecked, with shared sound settings.
profile.resourceExclusions = { COMBO_POINTS = true, MANA = true, ENERGY = false }
settings.soundFile = "resource.ogg"
local before = #displayed
-- When readable gains for excluded and enabled resources arrive.
presentation:Resource(1, "COMBO_POINTS")
presentation:Resource(10, "MANA")
presentation:Resource(20, "ENERGY")
-- Then only the enabled gain reaches display, with its usual shared settings.
assert(#displayed == before + 1, "unchecked readable resources were displayed")
assert(displayed[#displayed].settings == settings)

-- Given hidden tokens for the same three resources and an unknown token.
for _, name in ipairs({ "COMBO_POINTS", "MANA", "ENERGY", "FUTURE_POWER" }) do
	-- When they arrive with an opaque amount.
	presentation:Resource(amount, Secret(name))
	local event = displayed[#displayed]
	-- Then visibility is selected natively without inspecting the token in Lua.
	assert(event.amount == amount)
	assert(event.settings.auraVisibility, "hidden resource has no visibility gate")
	assert(issecretvalue(event.settings.auraVisibility.visible))
	assert(Read(event.settings.auraVisibility.visible)
		== not (name == "COMBO_POINTS" or name == "MANA"))
	assert(event.settings.soundFile == "", "hidden filtered resources played sound")
end
assert(settings.soundFile == "resource.ogg" and settings.auraVisibility == nil,
	"resource filtering mutated the shared event settings")

-- Given the real display service receiving a resource's native visibility.
local Service = dofile("Display/DisplayService.lua")
local rendered, sounds = {}, 0
Service:Configure({
	getProfile = function() return profile end,
	isModDisabled = function() return false end,
	scrollAreas = { Resolve = function() return {} end }, fonts = {},
	displayWithVisibility = function(visibility, ...)
		rendered[#rendered + 1] = { visibility = visibility, args = { ... } }
	end,
	display = function() error("resource visibility was dropped by display") end,
	playSound = function() sounds = sounds + 1 end,
})
-- When excluded and enabled hidden resources reach the display boundary.
for _, name in ipairs({ "COMBO_POINTS", "ENERGY" }) do
	presentation:Resource(amount, Secret(name))
	local event = displayed[#displayed]
	Service:DisplayEvent(event.settings, "%s - %s", nil, nil,
		event.amount, event.name)
end
-- Then the entire notification is gated and its original amount is untouched.
assert(not Read(rendered[1].visibility.visible))
assert(Read(rendered[2].visibility.visible))
assert(rendered[1].args[12] == amount and rendered[2].args[12] == amount)
assert(sounds == 0)

-- Given a helper is unavailable while a hidden resource is filtered.
local compare = C_Intl.CompareStrings
C_Intl.CompareStrings = nil
local hidden = Secret("COMBO_POINTS")
-- When a native match cannot be computed.
presentation:Resource(amount, hidden)
-- Then the original display remains available and sound stays muted.
assert(displayed[#displayed].name == hidden)
assert(displayed[#displayed].settings.auraVisibility == nil)
assert(displayed[#displayed].settings.soundFile == "")
C_Intl.CompareStrings = compare

-- Given a second profile without resource exclusions.
profile.resourceExclusions = {}
-- When combo points arrive again.
presentation:Resource(1, "COMBO_POINTS")
-- Then they are enabled with the shared sound and requested label.
assert(displayed[#displayed].name == "Combo Point")
assert(displayed[#displayed].settings == settings)

-- Given the master resource checkbox is disabled.
settings.disabled = true
before = #displayed
-- When either readable or hidden gains arrive.
presentation:Resource(1, "ENERGY")
presentation:Resource(amount, Secret("COMBO_POINTS"))
-- Then the master switch suppresses both paths.
assert(#displayed == before)
string.format = format
print("Resource token label tests passed")
