MikSBT = {}

local secretValue = {}
canaccessvalue = function(value)
	return value ~= secretValue
end
canaccesstable = function(value)
	return value ~= secretValue
end

UnitGUID = function(unit)
	return unit == "player" and "Player-1" or secretValue
end
UnitName = function(unit)
	return unit == "player" and "Tester" or secretValue
end
UnitClass = function(unit)
	if unit == "player" then
		return "Druid", "DRUID", 11
	end
	return secretValue, secretValue, secretValue
end
UnitExists = function(unit)
	return unit == "player" and true or secretValue
end
UnitCanAttack = function(_, unit)
	return unit == "target" and true or secretValue
end
UnitAffectingCombat = function(unit)
	return unit == "player"
end
UnitPower = function(unit)
	return unit == "player" and 4 or secretValue
end
UnitPowerMax = function(unit)
	return unit == "player" and 5 or secretValue
end
UnitAttackSpeed = function(unit)
	if unit == "player" then
		return 2.5, 1.8
	end
	return secretValue, secretValue
end
C_UnitAuras = {
	GetAuraDataBySpellID = function(unit, spellID)
		if unit == "player" and spellID == 123 then
			return { spellId = spellID }
		end
		if spellID == 999 then
			return secretValue
		end
	end,
}

dofile("API/RestrictedValue.lua")
local Units = dofile("API/Units.lua")

-- Given / When
local class = Units:GetClass("player")
local mainSpeed, offSpeed = Units:GetAttackSpeed("player")

-- Then
assert(Units:GetGUID("player") == "Player-1", "public GUID was rejected")
assert(Units:GetGUID("target") == nil, "secret GUID was exposed")
assert(Units:GetName("player") == "Tester", "public name was rejected")
assert(Units:GetName("target") == nil, "secret name was exposed")
assert(class.name == "Druid" and class.token == "DRUID" and class.id == 11,
	"class data was not normalized")
assert(Units:GetClass("target") == nil, "secret class was exposed")
assert(Units:Exists("player") == true, "public unit existence was rejected")
assert(Units:Exists("target") == false, "secret unit existence was exposed")
assert(Units:CanAttack("player", "target") == true,
	"public attackability was rejected")
assert(Units:AffectingCombat("player") == true,
	"public combat state was rejected")
assert(Units:GetPower("player", 4) == 4, "public power was rejected")
assert(Units:GetPower("target", 4) == nil, "secret power was exposed")
assert(Units:GetPowerMax("player", 4) == 5,
	"public maximum power was rejected")
assert(mainSpeed == 2.5 and offSpeed == 1.8,
	"attack speed was not normalized")
assert(Units:HasAura("player", 123, "HELPFUL") == true,
	"public aura was not found")
assert(Units:HasAura("player", 999, "HELPFUL") == false,
	"secret aura table was exposed")
