MikSBT = {
	API = {},
	Print = function() end,
}
UNKNOWN = "Unknown"

MikSBT.API.RestrictedValue = {
	Number = function(_, value)
		return type(value) == "number" and value or nil
	end,
	String = function(_, value)
		return type(value) == "string" and value or nil
	end,
}
MikSBT.API.Spells = {
	GetLegacyInfo = function(_, spellID)
		return spellID == 1 and "Safe Spell" or nil
	end,
	GetTexture = function(_, spellID)
		return spellID == 1 and 100 or nil
	end,
}
MikSBT.API.Cooldowns = {
	GetLegacySpell = function(_, spellID)
		if spellID == 1 then
			return 10, 20, true, 1
		end
	end,
}
MikSBT.API.Units = {
	HasAura = function(_, unit, aura)
		return unit == "player" and aura == "Safe Aura"
	end,
}

-- Given / When
dofile("Compatibility/LegacyAPI.lua")
local spellName = MikSBT.GetSpellInfo(1)
local startTime, duration = MikSBT.GetSpellCooldown(1)

-- Then
assert(spellName == "Safe Spell", "legacy spell info bypassed adapter")
assert(MikSBT.GetSpellTexture(1) == 100,
	"legacy spell texture bypassed adapter")
assert(startTime == 10 and duration == 20,
	"legacy cooldown bypassed adapter")
assert(MikSBT.HasAura("player", "Safe Aura", "HELPFUL") == true,
	"legacy aura lookup bypassed adapter")
assert(MikSBT.GetSkillName(1) == "Safe Spell",
	"legacy skill name bypassed adapter")
