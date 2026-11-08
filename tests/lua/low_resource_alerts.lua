-- Describe: built-in resource alerts follow settings and runtime state.
local frames, displayed, played = {}, {}, {}
local profile, area = {}, {}
local disabled = false
local mana, powerType = 1, 0
local health = 1
local now = 0
GetTime = function() return now end
local secret = newproxy(true)
getmetatable(secret).__lt = function() error("compared secret mana") end
getmetatable(secret).__tostring = function() error("formatted secret mana") end
canaccessvalue = function(value) return not rawequal(value, secret) end

Enum = { PowerType = { Mana = 0 } }
UnitClass = function() return "Mage", "MAGE" end
UnitPowerType = function() return powerType end
UnitPowerPercent = function(unit, power)
	assert(unit == "player" and power == 0)
	return mana
end
UnitHealthPercent = function(unit, predicted)
	assert(unit == "player" and predicted == false)
	return health
end
CreateFrame = function()
	local frame = { events = {}, scripts = {} }
	function frame:RegisterUnitEvent(event, unit)
		assert(unit == "player")
		self.events[event] = true
	end
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:UnregisterAllEvents() self.events = {} end
	function frame:SetScript(event, handler) self.scripts[event] = handler end
	frames[#frames + 1] = frame
	return frame
end
LowHealthFrame = nil
local function ShowLowHealth()
	local frame = frames[#frames]
	health = 1
	frame.scripts.OnEvent(frame, "UNIT_HEALTH", "player")
	health = 0.2
	frame.scripts.OnEvent(frame, "UNIT_HEALTH", "player")
	frame.scripts.OnEvent(frame, "UNIT_HEALTH", "player")
end
MikSBT = {
	Profiles = { currentProfile = profile },
	Parser = {}, Animations = {},
}
dofile("API/RestrictedValue.lua")
local service = dofile("Display/DisplayService.lua")
service:Configure({
	getProfile = function() return profile end,
	getTime = GetTime,
	isModDisabled = function() return disabled end,
	scrollAreas = { Resolve = function() return area end },
	fonts = {},
	display = function(message) displayed[#displayed + 1] = message end,
	playSound = function(sound) played[#played + 1] = sound end,
})
MikSBT.Animations.DisplayEvent = function(...)
	service:DisplayEvent(...)
end
PlaySoundFile = function() error("bypassed settings-aware sound service") end

-- Given an addon whose runtime has not been enabled.
dofile("MSBTTriggers.lua")
local triggers = MikSBT.Triggers
-- When the health warning is shown before enable.
ShowLowHealth()
-- Then neither text nor sound is emitted.
assert(#displayed == 0 and #played == 0, "inactive alert was emitted")
for _, frame in ipairs(frames) do
	assert(next(frame.events) == nil, "inactive tracker subscribed to events")
end

-- Given enabled alerts and full mana.
triggers.Enable()
local manaFrame = assert(frames[#frames], "mana event frame was not created")
local function PowerChanged(unit)
	manaFrame.scripts.OnEvent(manaFrame, "UNIT_POWER_UPDATE", unit or "player")
end
-- When full mana and another unit's power changes are observed.
PowerChanged()
mana = 0.2
PowerChanged("target")
-- Then neither event produces a low mana alert.
assert(#displayed == 0 and #played == 0, "unrelated power caused an alert")

-- Given low player mana.
-- When multiple power updates occur below the threshold.
PowerChanged()
PowerChanged()
-- Then exactly one alert uses the normal sound service.
assert(#displayed == 1 and displayed[1] == "Low Mana!")
assert(#played == 1 and played[1]:match("LowMana%.ogg$"))

-- Given mana recovered to the threshold.
mana = 0.35
PowerChanged()
-- When it crosses below the threshold again.
now = 8
mana = 0.349
PowerChanged()
-- Then the warning is rearmed.
assert(#displayed == 2 and #played == 2, "mana alert did not rearm")

-- Given restricted mana after a warning.
mana = secret
-- When power updates arrive under restrictions.
PowerChanged()
-- Then restricted data is neither compared nor formatted.
assert(#displayed == 2 and #played == 2)
-- When an accessible low value returns without a known recovery.
mana = 0.2
PowerChanged()
-- Then restrictions did not reset the warning latch.
assert(#displayed == 2, "restrictions rearmed an already fired alert")

-- Given an invalid or absent resource value.
for _, value in ipairs({ false, "unknown", 0 / 0, -1, 2 }) do
	mana = value
	-- When it is delivered by the API.
	PowerChanged()
	-- Then it cannot generate an alert.
	assert(#displayed == 2)
end
mana = nil
PowerChanged()
assert(#displayed == 2)

-- Given a profile with sounds muted.
profile.soundsDisabled = true
-- When the built-in health warning appears.
ShowLowHealth()
-- Then text is shown without sound.
assert(#displayed == 3 and displayed[3] == "Low Health!")
assert(#played == 2, "muted health alert played a sound")
mana = 1
PowerChanged()
mana = 0.1
PowerChanged()
assert(#displayed == 4 and #played == 2, "muted mana alert played a sound")

-- Given notifications or their scroll area are disabled.
profile.soundsDisabled = false
profile.msbtNotificationsDisabled = true
-- When the health warning appears.
ShowLowHealth()
profile.msbtNotificationsDisabled = false
area.disabled = true
ShowLowHealth()
area.disabled = false
-- Then both text and sound stay suppressed.
assert(#displayed == 4 and #played == 2)

-- Given disabled runtime and queued callbacks.
triggers.Disable()
-- When the old callbacks are delivered.
ShowLowHealth()
mana = 1
PowerChanged()
mana = 0.1
PowerChanged()
-- Then subscriptions are removed and callbacks stay silent.
assert(next(manaFrame.events) == nil, "disabled tracker retained events")
assert(#displayed == 4 and #played == 2, "disabled runtime emitted an alert")

-- Given a re-enabled runtime at low mana.
now = 16
triggers.Enable()
triggers.Enable()
-- When the health warning is shown and a power event arrives.
ShowLowHealth()
PowerChanged()
-- Then both independent alerts resume without duplicate subscriptions.
assert(manaFrame.events.UNIT_HEALTH, "health event was not registered")
assert(#displayed == 6 and #played == 4)

-- Given a non-mana form followed by a mana form.
now = 24
powerType = 3
PowerChanged()
powerType = 0
-- When the display power changes back to mana.
manaFrame.scripts.OnEvent(manaFrame, "UNIT_DISPLAYPOWER", "player")
-- Then low mana can warn again.
assert(#displayed == 7 and #played == 5)

-- Given recovered mana followed by an empty mana bar on world entry.
now = 32
mana = 1
PowerChanged()
mana = 0
-- When the world entry event has no unit argument.
manaFrame.scripts.OnEvent(manaFrame, "PLAYER_ENTERING_WORLD")
-- Then zero mana produces a warning.
assert(#displayed == 8 and #played == 6)

-- Given a client without the percentage API or Blizzard health frame.
triggers.Disable()
UnitPowerPercent = nil
UnitHealthPercent = nil
LowHealthFrame = nil
-- When the runtime is loaded and enabled.
dofile("MSBTTriggers.lua")
MikSBT.Triggers.Enable()
-- Then loading remains safe without unsupported API calls.
assert(#displayed == 8 and #played == 6)
MikSBT.Triggers.Disable()

print("Low resource alert tests passed")
