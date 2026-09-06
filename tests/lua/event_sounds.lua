MikSBT = { Display = {} }
local service = dofile("Display/DisplayService.lua")
local played, displayed = {}, {}
local profile = { soundsDisabled = false }
local grouped, disabled = false, false
local area = {}
service:Configure({
	getProfile = function() return profile end,
	scrollAreas = {
		Resolve = function() return area end,
		IsSuppressedInGroup = function() return grouped end,
	},
	fonts = {},
	isModDisabled = function() return disabled end,
	display = function(message) displayed[#displayed + 1] = message end,
	playSound = function(sound) played[#played + 1] = sound end,
})

-- Given an enabled event with a saved custom sound.
local settings = { soundFile = "Bell", scrollArea = "Outgoing" }
-- When the event is displayed.
service:DisplayEvent(settings, "9500 (3 hits, 1 Crit)")
-- Then its batch produces one sound and preserves the displayed text.
assert(#played == 1 and played[1] == "Bell", "event sound was not played")
assert(displayed[1] == "9500 (3 hits, 1 Crit)")

-- Given a muted profile, a cleared sound selection, or a legacy trigger.
-- When those events are displayed.
profile.soundsDisabled = true
service:DisplayEvent(settings, "Muted")
profile = { soundsDisabled = false }
service:DisplayEvent({ soundFile = "" }, "None")
service:DisplayEvent({}, "No assignment")
service:DisplayEvent(settings, "Legacy trigger", nil, true)
-- Then the text still displays, without more event sounds.
assert(#played == 1 and #displayed == 5)

-- Given hidden/disabled events or a disabled addon.
-- When they would otherwise display.
grouped = true
service:DisplayEvent(settings, "Grouped")
grouped = false
area.disabled = true
service:DisplayEvent(settings, "Area disabled")
area.disabled = false
settings.disabled = true
service:DisplayEvent(settings, "Event disabled")
settings.disabled = false
disabled = true
service:DisplayEvent(settings, "Addon disabled")
-- Then both sound and text stay suppressed.
assert(#played == 1 and #displayed == 5)

-- Given a newly selected profile with sounds enabled.
-- When an event arrives after re-enabling the addon.
disabled = false
service:DisplayEvent(settings, "Enabled")
-- Then the current profile takes effect immediately.
assert(#played == 2 and #displayed == 6)
