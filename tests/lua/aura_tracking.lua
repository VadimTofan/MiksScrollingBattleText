-- Describe: custom aura rules preserve normal tracking by default.
MikSBT = { Configuration = {}, Components = {}, API = {} }
dofile("API/RestrictedValue.lua")
local spells = {
	[1459] = { name = "Arcane Intellect", spellID = 1459, iconID = 135932 },
	[1460] = { name = "Arcane Intellect", spellID = 1460, iconID = 135932 },
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
-- Then the input's matching scope is preserved, and invalid input is rejected.
assert(id == "1459" and named == "name:Power Word: Shield",
	"name input lost its all-ranks scope")
assert(Tracking:Resolve("") == nil)
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

-- When that exact aura gains or fades.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(true, true, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, true, "Arcane Intellect", 135932, 1459)
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

-- Describe: name exclusions match ranks, while ID exclusions stay exact.
-- Given a rule added by name and a separately listed, enabled rank.
profile = { events = profile.events, auraTracking = {
	["name:Arcane Intellect"] = false, ["1460"] = true,
} }
local before = #shown
-- When either rank gains or fades, or only its name or ID is readable.
for _, spellID in ipairs({ 1459, 1460 }) do
	for _, harmful in ipairs({ false, true }) do
		presentation:Aura(true, harmful, "Arcane Intellect", 135932, spellID)
		presentation:Aura(false, harmful, "Arcane Intellect", 135932, spellID)
	end
end
presentation:Aura(true, false, "Arcane Intellect", 135932)
presentation:Aura(true, false, secret, 135932, 1460)
-- Then the name exclusion hides all identified ranks, even an enabled ID.
assert(#shown == before, "a name exclusion did not hide every rank")

-- Given only an ID exclusion.
profile.auraTracking = { ["1459"] = false }
-- When another rank or a name-only notice arrives.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1460)
presentation:Aura(true, false, "Arcane Intellect", 135932)
-- Then neither can be suppressed by that exact-ID rule.
assert(#shown == before + 2, "ID exclusion matched an unproven rank")

-- Given both a name rule and a more specific ID rule with custom styles.
profile.auraTracking = { ["name:Arcane Intellect"] = true, ["1459"] = true }
-- When a different rank, the exact rank, or a name-only notice is matched.
local rank = Tracking:FindID(profile.auraTracking, 1460, "Arcane Intellect")
local exact = Tracking:FindID(profile.auraTracking, 1459, "Arcane Intellect")
local fallback = Tracking:FindID(profile.auraTracking, nil, "Arcane Intellect")
-- Then name styles cover ranks and exact ID styles take priority.
assert(rank == "name:Arcane Intellect" and exact == "1459")
assert(fallback == "name:Arcane Intellect")

-- Given only an exact-ID style rule and a name-only notice.
-- When its style is matched without an ID.
local unknownRank = Tracking:FindID({ ["1459"] = true }, nil,
	"Arcane Intellect")
-- Then an unproven rank does not inherit the exact-ID style.
assert(unknownRank == nil)

-- Given an unidentified notice with an active name exclusion.
profile.auraTracking["name:Arcane Intellect"] = false
before = #shown
-- When neither the ID nor name can be inspected.
presentation:Aura(true, false, secret, 135932, secret)
-- Then it remains displayable without inspecting restricted data.
assert(#shown == before + 1 and shown[#shown][2] == secret)
print("Aura rank matching tests passed")

-- Describe: name rules do not require spellbook name lookup support.
-- Given a client that resolves numeric IDs but not names.
local getSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(value)
	if type(value) == "number" then return getSpellInfo(value) end
end
-- When the user enters an exact name with surrounding whitespace.
local unlistedName = Tracking:Resolve("  Arcane Intellect  ")
-- Then it is saved as a name rule, and numeric validation still applies.
assert(unlistedName == "name:Arcane Intellect",
	"name rule incorrectly required a successful spell lookup")
assert(Tracking:Resolve("1459") == "1459")
assert(Tracking:Resolve("99999999") == nil)
assert(Tracking:Resolve("   ") == nil)
assert(Tracking:Resolve("Arcane\nIntellect") == nil)

-- Given the rule entered while name lookup was unavailable.
profile.auraTracking = { [unlistedName] = false }
before = #shown
-- When two ranks and a name-only notification arrive.
presentation:Aura(true, false, "Arcane Intellect", 135932, 1459)
presentation:Aura(false, false, "Arcane Intellect", 135932, 1460)
presentation:Aura(true, false, "Arcane Intellect", 135932)
-- Then every matching notification is hidden.
assert(#shown == before)
C_Spell.GetSpellInfo = getSpellInfo
