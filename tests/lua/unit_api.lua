MikSBT = {}

local secretValue = {}
canaccessvalue = function(value)
	return value ~= secretValue
end
canaccesstable = function(value)
	return value ~= secretValue
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

-- Given a public aura and an inaccessible aura result.
-- When looking up both auras through the real API adapter.
local publicAura = Units:HasAura("player", 123, "HELPFUL")
local restrictedAura = Units:HasAura("player", 999, "HELPFUL")

-- Then public auras are found and restricted data stays inaccessible.
assert(publicAura == true,
	"public aura was not found")
assert(restrictedAura == false,
	"secret aura table was exposed")
