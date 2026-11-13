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
assert(Read(displayed[3].name) == "Energy")

-- Given the resource tokens reported by Blizzard, including multiword names.
for token, label in pairs({ MANA = "Mana", ENERGY = "Energy",
	LUNAR_POWER = "Lunar Power", RUNIC_POWER = "Runic Power",
	SOUL_SHARDS = "Soul Shards", ARCANE_CHARGES = "Arcane Charges" }) do
	-- When readable and hidden tokens reach the resource display.
	presentation:Resource(2, token)
	presentation:Resource(amount, Secret(token))
	-- Then both paths show the same human-readable name.
	assert(displayed[#displayed - 1].name == label)
	assert(Read(displayed[#displayed].name) == label)
end

-- Given tokens that are not an exact combo-point match.
for _, name in ipairs({ "combo_points", "COMBO_POINTS_EXTRA",
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
dofile("Configuration/ResourcePolicy.lua")
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

-- Describe: druid cat form hides resources belonging to other forms.
settings.disabled = nil
profile.resourceExclusions = {}
local oldUnitClass, oldPowerType = UnitClass, UnitPowerType
local playerClass, activePower = "DRUID", "ENERGY"
UnitClass = function(unit)
	assert(unit == "player")
	return "Localized class", playerClass
end
UnitPowerType = function(unit)
	assert(unit == "player")
	local types = { ENERGY = 3, RAGE = 1, MANA = 0, LUNAR_POWER = 8 }
	return types[activePower], activePower
end
-- Given every resource checkbox is enabled and cat form is active.
for _, token in ipairs({ "RAGE", "LUNAR_POWER", "ENERGY", "COMBO_POINTS", "MANA" }) do
	local excluded = token ~= "ENERGY" and token ~= "COMBO_POINTS"
	before = #displayed
	-- When readable resource gains arrive.
	presentation:Resource(5, token)
	-- Then cat form only shows energy and combo points, including hidden tokens.
	assert(#displayed == before + (excluded and 0 or 1),
		"cat form resource filter failed for " .. token)
	-- When the token and amount are hidden, the same rule stays native.
	presentation:Resource(amount, Secret(token))
	local event = displayed[#displayed]
	assert(event.amount == amount)
	assert(Read(event.settings.auraVisibility.visible) == not excluded)
end
assert(next(profile.resourceExclusions) == nil,
	"cat form changed the user's resource checkboxes")

-- Given the user has also disabled energy explicitly.
profile.resourceExclusions = { ENERGY = true }
before = #displayed
-- When an energy gain arrives in cat form, then the checkbox still applies.
presentation:Resource(5, "ENERGY")
assert(#displayed == before)
presentation:Resource(amount, Secret("ENERGY"))
assert(not Read(displayed[#displayed].settings.auraVisibility.visible))
assert(profile.resourceExclusions.RAGE == nil)
-- Given every cat resource is unchecked, no hidden notice is eligible.
profile.resourceExclusions.COMBO_POINTS = true
before = #displayed
presentation:Resource(amount, Secret("ENERGY"))
presentation:Resource(amount, Secret("FUTURE_POWER"))
presentation:ComboPoints(Secret(5), Secret(5))
assert(#displayed == before)
profile.resourceExclusions = {}

-- Given a shapeshift changes which power is active.
local allowedCompare = C_Intl.CompareStrings
C_Intl.CompareStrings = nil
before = #displayed
-- A hidden token cannot be displayed if its class eligibility cannot be proven.
presentation:Resource(amount, Secret("ENERGY"))
assert(#displayed == before)
C_Intl.CompareStrings = allowedCompare

for _, power in ipairs({ "RAGE", "LUNAR_POWER", "MANA" }) do
	activePower = power
	before = #displayed
	-- When the current form gains its own resource, it remains visible.
	presentation:Resource(5, power)
	assert(#displayed == before + 1)
	-- Other forms' resources and unknown tokens are excluded in both paths.
	for _, token in ipairs({ "ENERGY", "COMBO_POINTS", "MANA", "RAGE",
		"LUNAR_POWER", "FOCUS", "FUTURE_POWER" }) do
		local allowed = token == power
		before = #displayed
		presentation:Resource(5, token)
		assert(#displayed == before + (allowed and 1 or 0))
		presentation:Resource(amount, Secret(token))
		assert(Read(displayed[#displayed].settings.auraVisibility.visible) == allowed,
			"form allowlist failed for hidden " .. token)
	end
	-- Combo totals and their max alert must also respect the current form.
	presentation.config.display = function(eventSettings, message)
		displayed[#displayed + 1] = { settings = eventSettings, message = message }
	end
	before = #displayed
	presentation:ComboPoints(4, 5)
	presentation:ComboPoints(5, 5)
	presentation:ComboPoints(Secret(5), Secret(5))
	assert(#displayed == before, "combo totals escaped the active form policy")
end
-- Given a different class, then the druid-only filter does not apply.
playerClass, activePower = "WARRIOR", "ENERGY"
before = #displayed
presentation:Resource(5, "RAGE")
assert(#displayed == before + 1)
-- Given unreadable form information, then it is not inspected or guessed.
playerClass = "DRUID"
UnitPowerType = function() return Secret(3), Secret("ENERGY") end
before = #displayed
presentation:Resource(5, "RAGE")
assert(#displayed == before + 1)
-- Given only the readable numeric power type identifies cat energy.
UnitPowerType = function() return 3, nil end
before = #displayed
presentation:Resource(5, "RAGE")
assert(#displayed == before)
-- Given the power getter fails, then existing checkbox behavior is retained.
UnitPowerType = function() error("power type unavailable") end
presentation:Resource(5, "RAGE")
assert(#displayed == before + 1)
UnitClass, UnitPowerType = oldUnitClass, oldPowerType

-- Describe: current combo-point totals replace gain amounts and mark the cap.
settings.disabled = nil
profile.resourceExclusions = {}
presentation.config.display = function(eventSettings, message)
	displayed[#displayed + 1] = { settings = eventSettings, message = message }
end
-- Given current totals that can jump by more than one point.
for _, count in ipairs({ 1, 2, 4 }) do
	-- When a total below the current cap is reported.
	presentation:ComboPoints(count, 5)
	-- Then it displays that total, rather than the size of the gain.
	local event = displayed[#displayed]
	assert(event.amount == count)
	assert(event.name == (count == 1 and "Combo Point" or "Combo Points"))
end
-- Given a finisher spends all points.
before = #displayed
-- When the total becomes zero, then no notification appears.
presentation:ComboPoints(0, 5)
assert(#displayed == before, "zero combo points were displayed")
-- Given a character with a higher cap.
presentation:ComboPoints(5, 7)
assert(displayed[#displayed].amount == 5, "five points assumed the wrong cap")
-- When the actual maximum is reached, then the existing sticky path is used.
presentation:ComboPoints(7, 7)
assert(displayed[#displayed].message == "Finish Him!")
assert(displayed[#displayed].settings.alwaysSticky)
assert(not settings.alwaysSticky, "maximum alert mutated shared settings")

-- Given combo text inherits its font from the scroll area or profile.
local finishSettings = displayed[#displayed].settings
local area = { normalFontSize = 24 }
profile.normalFontSize = 18
settings.colorR, settings.colorG, settings.colorB = 0.2, 0.8, 0.1
Service.config.scrollAreas.Resolve = function() return area end
Service.config.display = function(...)
	rendered[#rendered + 1] = { args = { ... } }
end
-- When the normal notification and maximum alert reach real font resolution.
Service:DisplayEvent(settings, "4 Combo Points")
local normalFont = rendered[#rendered].args[7]
Service:DisplayEvent(finishSettings, "Finish Him!")
local finishArgs = rendered[#rendered].args
-- Then Finish Him is exactly twice the inherited size and red.
assert(normalFont == 24 and finishArgs[7] == 48,
	"maximum combo alert is not twice the combo-point font size")
assert(finishArgs[4] == 1 and finishArgs[5] == 0 and finishArgs[6] == 0,
	"maximum combo alert is not red")
assert(settings.colorR == 0.2 and settings.colorG == 0.8)
-- Given an explicit event font, then doubling uses that override.
settings.fontSize = 30
Service:DisplayEvent(finishSettings, "Finish Him!")
assert(rendered[#rendered].args[7] == 60)
-- Given no event or area font, then doubling uses the profile default.
settings.fontSize, area.normalFontSize = nil, nil
Service:DisplayEvent(finishSettings, "Finish Him!")
assert(rendered[#rendered].args[7] == 36)

-- Given current and maximum counts that are both opaque.
for _, count in ipairs({ 0, 1, 4, 5 }) do
	local current = Secret(count)
	before = #displayed
	-- When native display selection handles zero, ordinary totals, and the cap.
	presentation:ComboPoints(current, Secret(5))
	local normal, full = displayed[before + 1], displayed[before + 2]
	-- Then exactly the appropriate animation is visible; zero hides both.
	assert(#displayed == before + 2)
	assert(Read(normal.settings.auraVisibility.visible) == (count > 0 and count < 5))
	assert(Read(full.settings.auraVisibility.visible) == (count == 5))
	assert(normal.amount == current)
	assert(Read(normal.name) == (count == 1 and "Combo Point" or "Combo Points"))
	assert(full.message == "Finish Him!" and full.settings.alwaysSticky)
	assert(normal.settings.soundFile == "" and full.settings.soundFile == "")
	-- The same size and color must apply to the native-gated maximum animation.
	Service:DisplayEvent(full.settings, full.message)
	local fullArgs = rendered[#rendered].args
	assert(fullArgs[7] == 36)
	assert(fullArgs[4] == 1 and fullArgs[5] == 0 and fullArgs[6] == 0)
end

-- Given the combo-point checkbox is unchecked.
profile.resourceExclusions = { COMBO_POINTS = true }
before = #displayed
-- When ordinary or full totals arrive, neither path may emit a notification.
presentation:ComboPoints(4, 5)
presentation:ComboPoints(5, 5)
presentation:ComboPoints(Secret(5), Secret(5))
assert(#displayed == before)
profile.resourceExclusions = {}

-- Given totals are active and Blizzard also sends a gain for the same points.
before = #displayed
-- When readable combo gains arrive, then they are suppressed completely.
presentation:Resource(1, "COMBO_POINTS", true)
assert(#displayed == before)
-- When gain tokens are opaque, then only combo-point gains are hidden natively.
presentation:Resource(amount, Secret("COMBO_POINTS"), true)
assert(not Read(displayed[#displayed].settings.auraVisibility.visible))
presentation:Resource(amount, Secret("ENERGY"), true)
assert(Read(displayed[#displayed].settings.auraVisibility.visible))

-- Given the real reader and a minimal frame/event boundary.
dofile("Combat/Context.lua")
local ns = MikSBT.CombatEngine
ns.NewMine = function() return {} end
ns.ResetHealing, ns.KeepCombatLog = function() end, function() end
Enum.PowerType = { ComboPoints = 4 }
GetTime = function() return 10 end
C_EventUtils = { IsEventValid = function() return true end }
CreateFrame = function()
	local frame = { events = {} }
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:RegisterUnitEvent(event, unit)
		assert(unit == "player")
		self.events[event] = true
	end
	function frame:SetScript() end
	function frame:UnregisterAllEvents() self.events = {} end
	return frame
end
local current, maximum, reads = 1, 5, 0
UnitPower = function(unit, power)
	assert(unit == "player" and power == 4)
	reads = reads + 1
	return current
end
UnitPowerMax = function(unit, power)
	assert(unit == "player" and power == 4)
	return maximum
end
ns.liveRouter = {
	ComboPoints = function(_, count, cap) presentation:ComboPoints(count, cap) end,
	Resource = function(_, count, token, ignored)
		presentation:Resource(count, token, ignored)
	end,
}
dofile("Combat/Reader.lua")
-- When the reader starts, it subscribes to player power changes.
ns.StartReader()
assert(ns.reader.frame.events.UNIT_POWER_UPDATE,
	"combo-point totals were not registered")
-- Then only the player's combo-point updates query their current total.
before = #displayed
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "pet", "COMBO_POINTS")
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "ENERGY")
assert(reads == 0 and #displayed == before)
for _, count in ipairs({ 1, 2, 4 }) do
	current = count
	ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
	assert(displayed[#displayed].amount == count)
end
-- Given repeated unchanged updates, then they do not repeat public totals.
before = #displayed
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
assert(#displayed == before)
-- Given a cap increase, then the reader uses the new maximum.
current, maximum = 7, 7
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
assert(displayed[#displayed].message == "Finish Him!")
current = 0
before = #displayed
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
assert(#displayed == before)
-- Given the live count and cap become hidden during combat.
current, maximum = Secret(4), Secret(5)
before = #displayed
-- When the real reader forwards the untouched values.
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
-- Then normal totals remain visible and the maximum alert remains hidden.
assert(displayed[before + 1].amount == current)
assert(Read(displayed[before + 1].settings.auraVisibility.visible))
assert(not Read(displayed[before + 2].settings.auraVisibility.visible))
current = Secret(0)
before = #displayed
ns.ReaderEvent(nil, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
assert(not Read(displayed[before + 1].settings.auraVisibility.visible))
assert(not Read(displayed[before + 2].settings.auraVisibility.visible))
-- When a duplicate combat-text gain arrives, then it is not shown again.
before = #displayed
C_CombatText = { GetCurrentEventInfo = function() return 1, "COMBO_POINTS" end }
ns.ReaderEvent(nil, "COMBAT_TEXT_UPDATE", "ENERGIZE")
assert(#displayed == before)
-- When disabled, then the power subscription is removed.
ns.StopReader()
assert(next(ns.reader.frame.events) == nil)
-- Given a missing native helper, then totals cannot safely hide zero or duplicates.
local nativeCompare = C_Intl.CompareStrings
C_Intl.CompareStrings = nil
ns.StartReader()
assert(not ns.reader.frame.events.UNIT_POWER_UPDATE)
ns.ReaderEvent(nil, "COMBAT_TEXT_UPDATE", "ENERGIZE")
assert(displayed[#displayed].amount == 1, "missing helpers lost the fallback gain")
ns.StopReader()
C_Intl.CompareStrings = nativeCompare
-- Given a missing power API, the existing gain feed also remains available.
UnitPower = nil
ns.StartReader()
assert(not ns.reader.frame.events.UNIT_POWER_UPDATE)
ns.StopReader()
string.format = format
print("Resource token label tests passed")
