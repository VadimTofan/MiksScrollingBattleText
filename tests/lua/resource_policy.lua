-- Describe: notifications only use resources appropriate to the player.
MikSBT = { API = {}, Configuration = {}, Compatibility = { Client = {} } }
dofile("API/RestrictedValue.lua")
local file = io.open("Configuration/ResourcePolicy.lua")
assert(file, "class/form resource policy is missing")
file:close()
local Policy = dofile("Configuration/ResourcePolicy.lua")
local class, primary, form, spec
local primaryIDs = {
	MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, RUNIC_POWER = 6,
	LUNAR_POWER = 8, MAELSTROM = 11, INSANITY = 13, FURY = 17, PAIN = 18,
}
UnitClass = function(unit)
	assert(unit == "player")
	return "Localized class", class
end
UnitPowerType = function(unit)
	assert(unit == "player")
	return primaryIDs[primary], primary
end
GetShapeshiftFormID = function() return form end
C_SpecializationInfo = {
	GetSpecialization = function() return spec and 1 end,
	GetSpecializationInfo = function(index)
		assert(index == 1)
		return spec
	end,
}

-- Given the supported classes, druid forms, and spec-specific secondary powers.
local cases = {
	{ "WARRIOR", "RAGE", nil, nil, { "RAGE" } },
	{ "ROGUE", "ENERGY", nil, nil, { "ENERGY", "COMBO_POINTS" } },
	{ "HUNTER", "FOCUS", nil, nil, { "FOCUS" } },
	{ "HUNTER", "MANA", nil, nil, { "MANA" }, true },
	{ "MAGE", "MANA", nil, 62, { "MANA", "ARCANE_CHARGES" } },
	{ "MAGE", "MANA", nil, 63, { "MANA" } },
	{ "MAGE", "MANA", nil, 64, { "MANA" } },
	{ "MAGE", "MANA", nil, nil, { "MANA" } },
	{ "MAGE", "MANA", nil, nil, { "MANA" }, true },
	{ "WARLOCK", "MANA", nil, 265, { "MANA", "SOUL_SHARDS" } },
	{ "WARLOCK", "MANA", nil, 266, { "MANA", "SOUL_SHARDS" } },
	{ "WARLOCK", "MANA", nil, 267, { "MANA", "SOUL_SHARDS" } },
	{ "WARLOCK", "MANA", nil, nil, { "MANA" }, true },
	{ "PRIEST", "INSANITY", nil, 258, { "INSANITY" } },
	{ "PRIEST", "MANA", nil, 256, { "MANA" } },
	{ "PRIEST", "MANA", nil, 257, { "MANA" } },
	{ "PALADIN", "MANA", nil, nil, { "MANA", "HOLY_POWER" } },
	{ "PALADIN", "MANA", nil, nil, { "MANA" }, true },
	{ "SHAMAN", "MAELSTROM", nil, 262, { "MAELSTROM" } },
	{ "SHAMAN", "MANA", nil, 263, { "MANA" } },
	{ "SHAMAN", "MANA", nil, 264, { "MANA" } },
	{ "MONK", "ENERGY", nil, 268, { "ENERGY" } },
	{ "MONK", "ENERGY", nil, 269, { "ENERGY", "CHI" } },
	{ "MONK", "MANA", nil, 270, { "MANA" } },
	{ "MONK", "ENERGY", nil, nil, { "ENERGY" } },
	{ "DEATHKNIGHT", "RUNIC_POWER", nil, nil, { "RUNES", "RUNIC_POWER" } },
	{ "DEMONHUNTER", "FURY", nil, nil, { "FURY" } },
	{ "DEMONHUNTER", "PAIN", nil, nil, { "PAIN" } },
	{ "EVOKER", "MANA", nil, nil, { "MANA", "ESSENCE" } },
	{ "DRUID", "ENERGY", 1, nil, { "ENERGY", "COMBO_POINTS" } },
	{ "DRUID", "RAGE", 5, nil, { "RAGE" } },
	{ "DRUID", "RAGE", 8, nil, { "RAGE" }, true },
	{ "DRUID", "LUNAR_POWER", 31, nil, { "LUNAR_POWER" } },
	{ "DRUID", "MANA", 31, nil, { "LUNAR_POWER" }, true },
	{ "DRUID", "MANA", 0, nil, { "MANA" } },
	{ "DRUID", "LUNAR_POWER", nil, nil, { "MANA" } },
	{ "DRUID", "MANA", 3, nil, { "MANA" } },
}
for _, case in ipairs(cases) do
	class, primary, form, spec = case[1], case[2], case[3], case[4]
	MikSBT.Compatibility.Client = {
		isMainline = not case[6], isForever = case[6] or false,
	}
	-- When the current allowed resources are resolved.
	local allowed = assert(Policy:Allowed(), "missing policy for " .. class)
	local expected = {}
	for _, token in ipairs(case[5]) do expected[token] = true end
	-- Then every expected resource is allowed and no extra resource is included.
	for token in pairs(expected) do
		assert(allowed[token], class .. " lost " .. token)
	end
	for token in pairs(allowed) do
		assert(expected[token], class .. " incorrectly allowed " .. token)
	end
end

-- Given only the legacy specialization globals are available.
local namespace = C_SpecializationInfo
GetSpecialization = namespace.GetSpecialization
GetSpecializationInfo = namespace.GetSpecializationInfo
C_SpecializationInfo = nil
class, primary, spec = "MONK", "ENERGY", 269
MikSBT.Compatibility.Client = { isMainline = true }
-- When the policy resolves Windwalker, then its secondary resource survives.
assert(Policy:Allowed().CHI)
GetSpecialization, GetSpecializationInfo = nil, nil
C_SpecializationInfo = namespace

-- Given shapeshift information is unavailable but the primary power is public.
class, primary, spec = "DRUID", "ENERGY", nil
GetShapeshiftFormID = nil
-- When the current resource provides the fallback context, then cat rules apply.
assert(Policy:Allowed().COMBO_POINTS and not Policy:Allowed().MANA)
-- Given a secret form and primary power, then neither is inspected or guessed.
local hidden = setmetatable({}, {
	__tostring = function() error("secret context inspected") end,
})
issecretvalue = function(value) return value == hidden end
GetShapeshiftFormID = function() return hidden end
UnitPowerType = function() return hidden, hidden end
local unknownForm = Policy:Allowed()
assert(unknownForm.MANA and unknownForm.ENERGY and unknownForm.RAGE)
assert(not unknownForm.FOCUS)
-- Given the player's class itself cannot be established.
UnitClass = function() return hidden, hidden end
-- When there is no public class identity, then only user settings can apply.
assert(Policy:Allowed() == nil)
print("Class and form resource policy tests passed")
