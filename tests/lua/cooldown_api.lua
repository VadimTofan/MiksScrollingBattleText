MikSBT = {}

local secretValue = {}
local secretTable = {}
canaccessvalue = function(value)
	return value ~= secretValue
end
canaccesstable = function(value)
	return value ~= secretTable
end

C_Spell = {
	GetSpellCooldown = function(spellID)
		if spellID == 1 then
			return {
				startTime = 10,
				duration = 30,
				isEnabled = true,
				modRate = 1,
			}
		end
		if spellID == 2 then
			return secretTable
		end
		if spellID == 3 then
			return { startTime = 10, duration = secretValue }
		end
	end,
}
C_Container = {
	GetItemCooldown = function(itemID)
		if itemID == 10 then
			return 5, 60, 1
		end
		return secretValue, secretValue, secretValue
	end,
}

dofile("API/RestrictedValue.lua")
local Cooldowns = dofile("API/Cooldowns.lua")

-- Given / When
local spell = Cooldowns:GetSpell(1)
local startTime, duration, isEnabled, modRate = Cooldowns:GetLegacySpell(1)
local item = Cooldowns:GetItem(10)

-- Then
assert(spell.startTime == 10 and spell.duration == 30,
	"spell cooldown timing was not normalized")
assert(spell.isEnabled == true and spell.modRate == 1,
	"spell cooldown metadata was not normalized")
assert(startTime == 10 and duration == 30 and isEnabled == true and modRate == 1,
	"legacy cooldown tuple differs")
assert(item.startTime == 5 and item.duration == 60 and item.isEnabled == true,
	"item cooldown was not normalized")
assert(Cooldowns:GetSpell(2) == nil, "secret cooldown table was exposed")
assert(Cooldowns:GetSpell(3) == nil, "secret cooldown duration was exposed")
assert(Cooldowns:GetItem(11) == nil, "secret item cooldown was exposed")
