MikSBT = {
	Components = {},
}

local now = 10
local queued
local displayed
local displayCount = 0
local OutgoingCombat = dofile("Components/OutgoingCombat.lua")
local component = OutgoingCombat:New({
	batcher = {
		Queue = function(_, ...)
			queued = { ... }
		end,
		Reset = function() end,
	},
	getProfile = function()
		return {
			events = {
				OUTGOING_DODGE = { message = "Dodged" },
			},
		}
	end,
	normalizeNumber = tonumber,
	buildActionMessage = function(settings)
		return settings.message
	end,
	display = function(settings, message, texture)
		displayCount = displayCount + 1
		displayed = { settings, message, texture }
	end,
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
	getDamageMeterDeltaFresh = function()
		return false
	end,
})

-- Given a recent successful player spell
component:HandleSpellcastSucceeded("player", 1234)

-- When matching outgoing damage arrives
local handled = component:HandleUnitCombat(
	"target",
	"WOUND",
	"CRITICAL",
	100,
	4
)

-- Then
assert(handled == true, "outgoing target damage was not handled")
assert(queued[1] == 1234, "recent spell was not attributed")
assert(queued[2] == 100, "outgoing amount changed")
assert(queued[3] == true, "outgoing crit flag changed")
assert(queued[4] == "texture-1234", "outgoing texture changed")

-- Given a non-damage target action
component:HandleUnitCombat("target", "DODGE", nil, nil, nil)

-- Then
assert(displayed[2] == "Dodged", "outgoing action was not displayed")
assert(component:HandleUnitCombat("player", "WOUND", nil, 10, 1) == false,
	"non-target combat was consumed")

-- Given no recent spell attribution
now = 20
local displaysBeforeUnattributedAction = displayCount

-- When
component:HandleUnitCombat("target", "DODGE", nil, nil, nil)

-- Then
assert(displayCount == displaysBeforeUnattributedAction,
	"unattributed outgoing action received an auto-attack fallback")

-- Given a live meter which already owns outgoing damage.
local critAmount
component.config.isMeterOwning = function() return true end
component.config.recordCrit = function(amount) critAmount = amount end
component:HandleSpellcastSucceeded("player", 1234)
queued = nil

-- When UNIT_COMBAT reports a matching critical hit.
component:HandleUnitCombat("target", "WOUND", "CRITICAL", 80, 4)

-- Then it supplies a crit hint without displaying the hit twice.
assert(critAmount == 80, "meter crit hint was not recorded")
assert(queued == nil, "meter-owned damage was queued twice")
