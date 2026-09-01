MikSBT = {}

local secretValue = {}
canaccessvalue = function(value)
	return value ~= secretValue
end

dofile("API/RestrictedValue.lua")
local Combat = dofile("API/Combat.lua")

-- Given / When
local event = Combat:NormalizeUnitCombat(
	"player",
	"WOUND",
	"CRITICAL",
	408,
	4
)

-- Then
assert(event.unit == "player", "unit token was not normalized")
assert(event.action == "WOUND", "combat action was not normalized")
assert(event.flags == "CRITICAL", "combat flags were not normalized")
assert(event.amount == 408, "combat amount was not normalized")
assert(event.schoolMask == 4, "school mask was not normalized")
assert(event.isCritical == true, "critical state was not normalized")

-- Given inaccessible required values
-- When / Then
assert(Combat:NormalizeUnitCombat(secretValue, "WOUND", nil, 408, 4) == nil,
	"secret unit token was accepted")
assert(Combat:NormalizeUnitCombat("player", secretValue, nil, 408, 4) == nil,
	"secret action was accepted")
assert(Combat:NormalizeUnitCombat("player", "WOUND", nil, secretValue, 4) == nil,
	"secret amount was accepted")

-- Given inaccessible optional values
-- When
local partial = Combat:NormalizeUnitCombat(
	"player",
	"HEAL",
	secretValue,
	100,
	secretValue
)

-- Then
assert(partial ~= nil, "safe required values were rejected")
assert(partial.flags == nil, "secret optional flags were exposed")
assert(partial.schoolMask == nil, "secret optional school was exposed")
assert(partial.isCritical == false, "missing flags became critical")
