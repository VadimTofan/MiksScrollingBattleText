-- Describe: resource sounds have independent cooldowns; text stays immediate.
local now, health, mana = 0, 1, 1
local frame
local displayed, played = {}, {}
local profile = {}
GetTime = function() return now end
Enum = { PowerType = { Mana = 0 } }
UnitClass = function() return "Mage", "MAGE" end
UnitPowerType = function() return 0 end
UnitHealthPercent = function() return health end
UnitPowerPercent = function() return mana end
CreateFrame = function()
    frame = {}
    function frame:RegisterUnitEvent() end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    function frame:SetScript(_, handler) self.onEvent = handler end
    return frame
end
MikSBT = {
    Profiles = { currentProfile = profile }, Parser = {}, Animations = {},
}
dofile("API/RestrictedValue.lua")
local service = dofile("Display/DisplayService.lua")
service:Configure({
    getProfile = function() return profile end,
    getTime = GetTime,
    isModDisabled = function() return false end,
    scrollAreas = { Resolve = function() return {} end },
    fonts = {},
    display = function(message) displayed[#displayed + 1] = message end,
    playSound = function(sound) played[#played + 1] = sound end,
})
MikSBT.Animations.DisplayEvent = function(...)
    service:DisplayEvent(...)
end
dofile("MSBTTriggers.lua")
local triggers = MikSBT.Triggers
triggers.Enable()

local function HealthChanged(value)
    health = value
    frame.onEvent(frame, "UNIT_HEALTH", "player")
end
local function ManaChanged(value)
    mana = value
    frame.onEvent(frame, "UNIT_POWER_UPDATE", "player")
end

-- Given the first low-health warning at time zero.
HealthChanged(0.2)
assert(#played == 1 and played[1]:match("LowHealth%.ogg$"))

-- When health recovers and drops again one second later.
now = 1
HealthChanged(1)
HealthChanged(0.2)

-- Then text appears immediately, but the health sound cannot repeat.
assert(#displayed == 2 and #played == 1,
    "rapid health recovery bypassed the sound cooldown")

-- Given health's sound is cooling down.
-- When mana drops for the first time.
ManaChanged(0.2)

-- Then mana plays immediately using its own cooldown.
assert(#played == 2 and played[2]:match("LowMana%.ogg$"))

-- Given another health threshold crossing just before eight seconds.
now = 7.999
HealthChanged(1)
HealthChanged(0.2)
assert(#played == 2, "health sound replayed before eight seconds")

-- When health crosses again at the exact cooldown boundary.
now = 8
HealthChanged(1)
HealthChanged(0.2)

-- Then the sound is eligible again.
assert(#played == 3 and played[3]:match("LowHealth%.ogg$"))

-- Given mana's cooldown started one second after health's.
now = 8.999
ManaChanged(1)
ManaChanged(0.2)
assert(#played == 3, "mana reused health's cooldown")

-- When mana crosses at its own eight-second boundary.
now = 9
ManaChanged(1)
ManaChanged(0.2)

-- Then its sound can play again.
assert(#played == 4 and played[4]:match("LowMana%.ogg$"))

-- Given both sounds just played.
-- When the runtime is disabled and immediately enabled again.
triggers.Disable()
triggers.Enable()
HealthChanged(0.2)
ManaChanged(0.2)

-- Then resetting alert latches cannot bypass either sound cooldown.
assert(#displayed == 9 and #played == 4,
    "runtime toggle bypassed a resource sound cooldown")

-- Given both cooldowns have elapsed while the profile is muted.
now = 20
profile.soundsDisabled = true
HealthChanged(1)
ManaChanged(1)
HealthChanged(0.2)
ManaChanged(0.2)
assert(#played == 4)

-- When sounds are unmuted and both thresholds are crossed immediately.
profile.soundsDisabled = false
HealthChanged(1)
ManaChanged(1)
HealthChanged(0.2)
ManaChanged(0.2)

-- Then muted warnings did not consume a sound cooldown.
assert(#played == 6, "muted alerts consumed a sound cooldown")

-- Given notifications are disabled after both cooldowns expire.
now = 30
profile.msbtNotificationsDisabled = true
HealthChanged(1)
ManaChanged(1)
HealthChanged(0.2)
ManaChanged(0.2)
assert(#played == 6)

-- When notifications are enabled and the resources cross again.
profile.msbtNotificationsDisabled = false
HealthChanged(1)
ManaChanged(1)
HealthChanged(0.2)
ManaChanged(0.2)

-- Then disabled warnings did not consume a sound cooldown.
assert(#played == 8, "disabled alerts consumed a sound cooldown")

-- Given a different event with no sound cooldown.
local otherEvent = { soundFile = "Bell" }

-- When it fires twice without advancing time.
service:DisplayEvent(otherEvent, "Other")
service:DisplayEvent(otherEvent, "Other")

-- Then its sound behavior remains unchanged.
assert(#played == 10 and played[9] == "Bell" and played[10] == "Bell")

-- Given only the low-health sound is disabled and both cooldowns expired.
now = 40
profile.lowHealthSoundDisabled = true
local beforeText = #displayed
HealthChanged(1)
ManaChanged(1)

-- When both resources fall below the threshold.
HealthChanged(0.2)
ManaChanged(0.2)

-- Then both text warnings remain visible, but only mana plays its sound.
assert(#displayed == beforeText + 2)
assert(#played == 11 and played[11]:match("LowMana%.ogg$"),
    "disabling low-health sound also muted mana or left health audible")

-- Given health is enabled and only the low-mana sound is disabled.
now = 40.1
profile.lowHealthSoundDisabled = false
profile.lowManaSoundDisabled = true
beforeText = #displayed
HealthChanged(1)
ManaChanged(1)

-- When both resources cross the threshold again.
HealthChanged(0.2)
ManaChanged(0.2)

-- Then both text warnings remain visible, but only health plays its sound.
assert(#displayed == beforeText + 2)
assert(#played == 12 and played[12]:match("LowHealth%.ogg$"),
    "disabling low-mana sound also muted health or left mana audible")

-- Given both resource sounds are enabled but the master sound switch is off.
now = 56
profile.lowManaSoundDisabled = false
profile.soundsDisabled = true
HealthChanged(1)
ManaChanged(1)

-- When both warnings fire, then the master switch still mutes both sounds.
HealthChanged(0.2)
ManaChanged(0.2)
assert(#played == 12, "resource sound switches bypassed the master mute")

-- When the master is enabled and both warnings rearm immediately.
profile.soundsDisabled = false
HealthChanged(1)
ManaChanged(1)
HealthChanged(0.2)
ManaChanged(0.2)

-- Then neither mute option consumed a sound cooldown.
assert(#played == 14)
triggers.Disable()
print("Low resource sound cooldown tests passed")
