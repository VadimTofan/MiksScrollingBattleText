-- Describe: aura-specific styles override only customized fields.
dofile("tests/lua/aura_tracking.lua")
local Tracking = MikSBT.Configuration.AuraTracking
local profile = {
	auraTracking = { ["1459"] = true },
	auraSettings = {},
	events = {
		NOTIFICATION_BUFF = {
			message = "Gain %sl", colorR = 0.2, colorG = 0.4,
			fontName = "Default", scrollArea = "Notification",
		},
		NOTIFICATION_BUFF_FADE = { message = "Lost %sl", colorB = 0.3 },
		NOTIFICATION_DEBUFF = { message = "Debuff %sl", colorR = 0.8 },
	},
}
local shown = {}
local presentation = MikSBT.Components.CombatPresentation:New({
	getProfile = function() return profile end,
	formatMessage = function(settings, record)
		return settings.message:gsub("%%sl", record.name)
	end,
	display = function(...) shown[#shown + 1] = {...} end,
	displayRestricted = function(...) shown[#shown + 1] = {...} end,
})

-- Given a custom aura with no style overrides.
-- When its style is resolved.
local settings = Tracking:GetSettings(profile, "1459", "NOTIFICATION_BUFF")
-- Then it inherits the corresponding notification settings.
assert(settings.message == "Gain %sl" and settings.colorR == 0.2)

-- Given the user changes this aura's color, font, area, sound and sticky state.
profile.auraSettings["1459"] = {
	colorR = 0.9, fontName = "Custom font", fontSize = 24,
	outlineIndex = 3, fontAlpha = 75, scrollArea = "My aura area",
	soundFile = 123456, alwaysSticky = true,
}
-- When it gains, fades, or is reported as a debuff.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(true, true, "Arcane Intellect", 135932, 1459)
-- Then all customized fields apply while each event keeps its own message.
assert(shown[1][2] == "Gain Arcane Intellect")
assert(shown[2][2] == "Lost Arcane Intellect")
assert(shown[3][2] == "Debuff Arcane Intellect")
for _, notice in ipairs(shown) do
	local style = notice[1]
	assert(style.colorR == 0.9 and style.fontName == "Custom font")
	assert(style.fontSize == 24 and style.outlineIndex == 3)
	assert(style.fontAlpha == 75 and style.scrollArea == "My aura area")
	assert(style.soundFile == 123456 and style.alwaysSticky)
end
assert(shown[1][1].colorG == 0.4)
assert(shown[2][1].colorB == 0.3)

-- Given a category style changed after the aura was customized.
profile.events.NOTIFICATION_BUFF.colorG = 0.7
-- When that aura is reported without a spell ID.
presentation:Aura(true, false, "Arcane Intellect", 135932)
-- Then untouched fields still inherit, even through the name-only fallback.
assert(shown[4][1].colorG == 0.7 and shown[4][1].colorR == 0.9)

-- Given a custom message and an explicit non-sticky override.
profile.events.NOTIFICATION_BUFF.alwaysSticky = true
profile.auraSettings["1459"].message = "Aura: %sl"
profile.auraSettings["1459"].alwaysSticky = false
-- When the customized aura and an unlisted aura are reported.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(true, false, "Power Word: Shield", 135940, 17)
-- Then the override affects only the custom aura and leaves defaults intact.
assert(shown[5][2] == "Aura: Arcane Intellect")
assert(shown[5][1].alwaysSticky == false)
assert(shown[6][2] == "Gain Power Word: Shield")
assert(shown[6][1].alwaysSticky == true)
assert(profile.events.NOTIFICATION_BUFF.colorR == 0.2)

-- Given an unchecked custom aura, then a disabled category.
profile.auraTracking["1459"] = false
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
profile.auraTracking["1459"] = true
profile.events.NOTIFICATION_BUFF.disabled = true
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
-- Then custom styling never forces a hidden notification to display.
assert(#shown == 6)

-- Given category defaults supplied by the real profile inheritance pattern.
profile.events.NOTIFICATION_BUFF.disabled = nil
profile.events.NOTIFICATION_BUFF.skillIconsDisabled = true
profile.events.NOTIFICATION_BUFF = setmetatable({}, {
	__index = profile.events.NOTIFICATION_BUFF,
})
-- When a styled aura uses those inherited category settings.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
-- Then fields outside the custom style overrides are preserved as well.
assert(shown[7][1].skillIconsDisabled == true)

-- Given a readable ID but a restricted aura name.
local secret = {}
issecretvalue = function(value) return value == secret end
-- When the restricted rendering path displays this aura.
presentation:Aura(true, false, secret, 135932, 1459)
-- Then it receives the same custom style and the original opaque name.
assert(shown[8][1].fontSize == 24 and shown[8][2] == secret)
print("Custom aura style tests passed")
