-- Describe: custom aura rules preserve normal tracking by default.
MikSBT = { Configuration = {}, Components = {}, API = {} }
dofile("API/RestrictedValue.lua")
local spells = {
	[1459] = { name = "Arcane Intellect", spellID = 1459, iconID = 135932 },
	[17] = { name = "Power Word: Shield", spellID = 17, iconID = 135940 },
}
C_Spell = { GetSpellInfo = function(value)
	if type(value) == "number" then return spells[value] end
	for _, info in pairs(spells) do
		if info.name == value then return info end
	end
end }
dofile("API/Spells.lua")
local Tracking = dofile("Configuration/AuraTracking.lua")

-- Given a valid ID or an exact aura name entered in options.
-- When each input is resolved.
local id = Tracking:Resolve(" 1459 ")
local named = Tracking:Resolve("Power Word: Shield")
-- Then a canonical spell ID is used, and invalid input is rejected.
assert(id == "1459" and named == "17")
assert(Tracking:Resolve("not an aura") == nil)
assert(Tracking:Resolve("-3") == nil)

-- Given only one hidden aura in the active profile.
local profile = { auraTracking = { ["1459"] = false }, events = {} }
for _, key in ipairs({ "BUFF", "BUFF_FADE", "DEBUFF", "DEBUFF_FADE" }) do
	profile.events["NOTIFICATION_" .. key] = { message = "%sl" }
end
local shown = {}
local Presentation = dofile("Components/CombatPresentation.lua")
local presentation = Presentation:New({
	getProfile = function() return profile end,
	formatMessage = function(_, record) return record.name end,
	display = function(...) shown[#shown + 1] = {...} end,
	displayRestricted = function(...) shown[#shown + 1] = {...} end,
})

-- When that aura gains or fades, including a name-only combat-text notice.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(true, true, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, true, "Arcane Intellect", 135932, 1459)
presentation:Aura(true, false, "Arcane Intellect", 135932)
-- Then all of its aura notifications are hidden.
assert(#shown == 0, "unchecked aura still displayed")

-- Given an unlisted aura and a different ID with the same display name.
-- When they are reported.
presentation:Aura(true, false, "Power Word: Shield", 135940, 17)
presentation:Aura(true, false, "Arcane Intellect", 135932, 999)
-- Then neither is hidden by another ID's rule.
assert(#shown == 2)

-- Given the custom aura's checkbox is ticked again.
profile.auraTracking["1459"] = true
-- When the aura is reported.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
-- Then it is visible again, without forcing a disabled category on.
assert(#shown == 3)
profile.events.NOTIFICATION_BUFF.disabled = true
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
assert(#shown == 3)
profile.events.NOTIFICATION_BUFF.disabled = nil

-- Given WoW hides the aura name and spell ID.
local secret = setmetatable({}, {
	__tostring = function() error("restricted identity inspected") end,
})
issecretvalue = function(value) return value == secret end
profile.auraTracking["1459"] = false
-- When an unidentified aura is received, or its public ID is available.
presentation:Aura(true, false, secret, 135932, secret)
presentation:Aura(true, false, secret, 135932, 1459)
-- Then unidentified notices remain visible and readable IDs still filter.
assert(#shown == 4 and shown[4][2] == secret)

-- Given a different active profile without exclusions.
profile = { events = profile.events }
-- When the previously hidden aura is reported.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
-- Then the old profile's rules do not leak into it.
assert(#shown == 5)
print("Aura tracking tests passed")
