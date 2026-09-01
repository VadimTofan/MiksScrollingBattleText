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
	GetSpellInfo = function(identifier)
		if identifier == 1 then
			return {
				name = "Ferocious Bite",
				iconID = 132127,
				castTime = 0,
				minRange = 0,
				maxRange = 5,
				spellID = 22568,
				originalIconID = 132127,
			}
		end
		if identifier == 2 then
			return secretTable
		end
		if identifier == 3 then
			return { name = secretValue, iconID = 132127 }
		end
	end,
	GetSpellTexture = function(identifier)
		if identifier == 1 then
			return 132127
		end
		return secretValue
	end,
}

dofile("API/RestrictedValue.lua")
local Spells = dofile("API/Spells.lua")

-- Given / When
local info = Spells:GetInfo(1)
local name, _, icon, castTime, minRange, maxRange, spellID, originalIcon =
	Spells:GetLegacyInfo(1)

-- Then
assert(info.name == "Ferocious Bite", "spell name was not normalized")
assert(info.spellID == 22568, "spell ID was not normalized")
assert(name == info.name, "legacy spell name differs")
assert(icon == info.iconID, "legacy spell icon differs")
assert(castTime == 0 and minRange == 0 and maxRange == 5,
	"legacy spell fields differ")
assert(spellID == info.spellID, "legacy spell ID differs")
assert(originalIcon == info.originalIconID, "legacy original icon differs")
assert(Spells:GetTexture(1) == 132127, "public texture was rejected")
assert(Spells:GetInfo(2) == nil, "secret spell table was exposed")
assert(Spells:GetInfo(3) == nil, "secret required spell field was exposed")
assert(Spells:GetTexture(2) == nil, "secret texture was exposed")
