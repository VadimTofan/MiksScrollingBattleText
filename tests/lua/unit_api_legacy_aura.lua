MikSBT = {}
C_UnitAuras = nil
AuraUtil = nil
UnitBuff = function(unit, aura)
	if unit == "player" and aura == "Legacy Aura" then
		return aura
	end
end

dofile("API/RestrictedValue.lua")
local Units = dofile("API/Units.lua")

-- Given / When / Then
assert(Units:HasAura("player", "Legacy Aura", "HELPFUL") == true,
	"legacy UnitBuff aura was not found")
assert(Units:HasAura("player", "Missing", "HELPFUL") == false,
	"missing legacy aura was reported present")
