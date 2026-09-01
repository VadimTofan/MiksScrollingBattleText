MikSBT = {}

local writes = {}
local inCombat = false
InCombatLockdown = function()
	return inCombat
end
C_CVar = {
	SetCVar = function(name, value)
		writes[#writes + 1] = { name = name, value = value }
		return name ~= "fail"
	end,
}

dofile("API/RestrictedValue.lua")
local BlizzardCombatText = dofile("API/BlizzardCombatText.lua")

-- Given / When
local enabled = BlizzardCombatText:SetEnabled(true)

-- Then
assert(enabled == true, "out-of-combat CVar update failed")
assert(#writes == 7, "not all Blizzard combat-text CVars were updated")
for _, write in ipairs(writes) do
	assert(write.value == 1, "enabled state used the wrong CVar value")
end

-- Given combat lockdown
inCombat = true
local writeCount = #writes

-- When
local disabled = BlizzardCombatText:SetEnabled(false)

-- Then
assert(disabled == false, "combat-lockdown update reported success")
assert(#writes == writeCount, "CVar was written during combat lockdown")

-- Given a native CVar failure
inCombat = false
C_CVar.SetCVar = function(name, value)
	if name == "floatingCombatTextCombatDamage_v2" then
		return nil
	end
	return true
end

-- When / Then
assert(BlizzardCombatText:SetEnabled(true) == false,
	"native CVar failure reported success")
