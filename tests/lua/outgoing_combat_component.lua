MikSBT = {
	Components = {},
}

local now = 10
local OutgoingCombat = dofile("Components/OutgoingCombat.lua")
local component = OutgoingCombat:New({
	batcher = {
		Reset = function() end,
	},
	normalizeNumber = tonumber,
	getTime = function()
		return now
	end,
	inCombat = function()
		return true
	end,
	isTargetValid = function()
		return true
	end,
	getSpellTexture = function(spellID)
		return "texture-" .. tostring(spellID)
	end,
	isAutoAttack = function(spellID)
		return spellID == 6603
	end,
	canUseAutoAttackFallback = function()
		return false
	end,
	hasPlayerDebuff = function()
		return false
	end,
	isLikelySpellSchool = function(schoolMask)
		return schoolMask ~= 1
	end,
	damageMeterEnabled = false,
	autoAttackSpellID = 6603,
	fallbackAttributionWindow = 0.9,
	delayedAttributionWindow = 3,
	signalWindow = 1.25,
	dotDuration = 18,
	dotSpells = {},
	timedDotSpells = {},
	critMatchWindow = 0.35,
	critMatchTolerance = 0.10,
})

-- Given a recent successful player spell
component:HandleSpellcastSucceeded("player", 1234)

-- When a matching critical target event arrives
local handled = component:RecordCriticalCandidate(
	"target",
	"WOUND",
	"CRITICAL",
	100,
	4
)

-- Then
assert(handled == true, "critical candidate was not recorded")

-- When the damage meter reports an approximately matching amount
local isCrit = component:ConsumeCriticalCandidate(1234, 109, now)

-- Then
assert(isCrit == true, "matching damage meter amount was not marked critical")
assert(component:ConsumeCriticalCandidate(1234, 109, now) == false,
	"critical candidate was reused")

-- Given a critical event whose amount differs by more than ten percent
now = 11
component:HandleSpellcastSucceeded("player", 1234)
component:RecordCriticalCandidate("target", "WOUND", "CRITICAL", 100, 4)

-- When / Then
assert(component:ConsumeCriticalCandidate(1234, 111, now) == false,
	"damage meter amount outside tolerance was marked critical")

-- Given a matching candidate that has expired
now = 12
component:HandleSpellcastSucceeded("player", 1234)
component:RecordCriticalCandidate("target", "WOUND", "CRITICAL", 100, 4)

-- When / Then
now = 12.36
assert(component:ConsumeCriticalCandidate(1234, 100, now) == false,
	"expired critical candidate was matched")

-- Given invalid and non-critical UNIT_COMBAT events
now = 13
component:HandleSpellcastSucceeded("player", 1234)

-- When / Then
assert(component:RecordCriticalCandidate(
	"player",
	"WOUND",
	"CRITICAL",
	100,
	4
) == false, "non-target critical event was recorded")
assert(component:RecordCriticalCandidate(
	"target",
	"WOUND",
	"NORMAL",
	100,
	4
) == false, "normal hit was recorded as a critical candidate")

-- Given a recorded candidate
component:RecordCriticalCandidate("target", "WOUND", "CRITICAL", 100, 4)

-- When combat state resets
component:ResetCombatState()

-- Then
assert(component:ConsumeCriticalCandidate(1234, 100, now) == false,
	"combat reset retained a critical candidate")
