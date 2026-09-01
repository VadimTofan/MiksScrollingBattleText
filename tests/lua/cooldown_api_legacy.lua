MikSBT = {}
C_Spell = nil
GetSpellCooldown = function(spellID)
	if spellID == 1 then
		return 10, 20, 1, 0.5
	end
end

dofile("API/RestrictedValue.lua")
local Cooldowns = dofile("API/Cooldowns.lua")

-- Given / When
local cooldown = Cooldowns:GetSpell(1)

-- Then
assert(cooldown.startTime == 10 and cooldown.duration == 20,
	"legacy cooldown timing was rejected")
assert(cooldown.isEnabled == true and cooldown.modRate == 0.5,
	"legacy cooldown metadata was not normalized")
