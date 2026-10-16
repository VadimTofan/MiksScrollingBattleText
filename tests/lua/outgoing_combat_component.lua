MikSBT = {
	Components = {},
}

local now = 10
local queued
local displayed
local displayCount = 0
local emitted = {}
local OutgoingCombat = dofile("Components/OutgoingCombat.lua")
local component = OutgoingCombat:New({
	emit = function(event) emitted[#emitted + 1] = event end,
	classifyUnit = function(unit)
		if unit == "target" then return "hostile" end
	end,
	isHostileUnit = function() return true end,
	unitName = function() return "Target One" end,
	getSpellName = function(id) return "Spell " .. id end,
	ownedSpellWindow = 5,
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
assert(emitted[1] and emitted[1].missType == "DODGE",
	"outgoing miss was not routed")
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

-- Given one pending direct damage cast in a group.
component.config.isMeterOwning = function() return false end
component.config.isInGroup = function() return true end
component:HandleSpellcastSent("player", "Target One", "cast-guid")
component:HandleSpellcastSucceeded("player", 1234, "cast-guid")
queued = nil

-- When the first matching hit and then an unrelated second hit arrive.
component:HandleUnitCombat("target", "WOUND", nil, 30, 4)
assert(queued and queued[2] == 30, "own direct cast was not attributed")
queued = nil
component:HandleUnitCombat("target", "WOUND", nil, 40, 4)

-- Then the one-use direct cast cannot claim both hits.
assert(queued == nil, "one direct cast claimed multiple group hits")

-- Given a periodic cast at one of two similarly named enemies.
component.config.namedDots = function()
    return { ["Spell 5555"] = { duration = 18, interval = 3, school = 4 } }
end
component:HandleSpellcastSent("player", "Target One", "dot-cast")
component:HandleSpellcastSucceeded("player", 5555, "dot-cast")
component.config.unitName = function() return "Target Two" end
now = now + 3
queued = nil

-- When another enemy takes damage on the expected tick boundary.
component:HandleUnitCombat("target", "WOUND", nil, 20, 4)

-- Then a shared first word cannot match a different enemy.
assert(queued == nil, "periodic damage matched the wrong full target name")
assert(component.castTargets["dot-cast"] == nil,
    "successful damage cast retained its target record")

-- Given a successful helpful cast at a known friendly target.
component.config.isHelpfulSpell = function(id) return id == 7777 end
component.config.defaultHealTarget = function() return "Friendly One" end
component.config.namedHots = function() return {} end
component.config.classifyUnit = function() return "friendly" end
component.config.unitName = function() return "Friendly One" end
component:HandleSpellcastSent("player", "Friendly One", "heal-cast")
component:HandleSpellcastSucceeded("player", 7777, "heal-cast")

-- When that target receives a heal.
component:HandleUnitCombat("target", "HEAL", nil, 60, nil, true)

-- Then it routes the heal with its spell and recipient.
local heal = emitted[#emitted]
assert(heal.eventType == "heal" and heal.skillID == 7777,
    "helpful cast was not attributed to outgoing healing")
assert(heal.recipientName == "Friendly One", "heal recipient changed")
assert(component.castTargets["heal-cast"] == nil,
    "helpful cast retained its target record")

-- Given a helpful cast without a recent damaging cast.
component:ResetCombatState()
component.lastSpellID = nil
component.lastSpellTime = 0
component.config.classifyUnit = function() return "hostile" end
component.config.isInGroup = function() return false end
component:HandleSpellcastSent("player", "Friendly One", "another-heal")
component:HandleSpellcastSucceeded("player", 7777, "another-heal")
queued = nil

-- When the enemy takes unrelated damage immediately afterwards.
component:HandleUnitCombat("target", "WOUND", nil, 90, 4)

-- Then a healing cast cannot supply damage attribution.
assert(queued == nil, "helpful spell was used to attribute damage")
