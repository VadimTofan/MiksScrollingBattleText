MikSBT = {}
C_Spell = nil
GetSpellInfo = function(identifier)
	if identifier == 1 then
		return "Legacy Spell", nil, 100, 1500, 0, 30, 1, 101
	end
end
GetSpellTexture = function(identifier)
	return identifier == 1 and 100 or nil
end

dofile("API/RestrictedValue.lua")
local Spells = dofile("API/Spells.lua")

-- Given / When
local info = Spells:GetInfo(1)

-- Then
assert(info.name == "Legacy Spell", "legacy spell name was rejected")
assert(info.iconID == 100 and info.castTime == 1500,
	"legacy spell fields were not normalized")
assert(Spells:GetTexture(1) == 100, "legacy spell texture was rejected")
