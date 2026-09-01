MikSBT = {
	Components = {},
}

local profile = {
	events = {
		INCOMING_DAMAGE = { message = "%a", scrollArea = "Incoming" },
		INCOMING_DAMAGE_CRIT = {
			message = "%a",
			scrollArea = "Incoming",
		},
		SELF_HEAL = { message = "%a", scrollArea = "Incoming" },
		SELF_HEAL_CRIT = { message = "%a", scrollArea = "Incoming" },
	},
}
local callbacks = {}
local displayed = {}
local now = 10

local SelfHealTracker = dofile("Components/SelfHealTracker.lua")
local selfHealTracker = SelfHealTracker:New({
	getTime = function()
		return now
	end,
	matchWindow = 1,
	tolerance = 1,
})
local IncomingCombat = dofile("Components/IncomingCombat.lua")
local component = IncomingCombat:New({
	selfHealTracker = selfHealTracker,
	getProfile = function()
		return profile
	end,
	normalizeNumber = function(value)
		return tonumber(value)
	end,
	buildActionMessage = function(_, amount)
		return tostring(amount)
	end,
	shouldSplitCritBatch = function()
		return false
	end,
	resolveBatchDisplaySettings = function(settings)
		return settings
	end,
	display = function(settings, message, texture)
		displayed[#displayed + 1] = {
			settings = settings,
			message = message,
			texture = texture,
		}
	end,
	after = function(_, callback)
		callbacks[#callbacks + 1] = callback
	end,
	getTime = function()
		return now
	end,
	unitName = function()
		return "Player-Realm"
	end,
	unitCastingInfo = function()
		return "Healing Spell"
	end,
	unitChannelInfo = function()
		return nil
	end,
	safeUnitBoolean = function()
		return false
	end,
	getSpellInfo = function()
		return nil, nil, "heal-texture"
	end,
	isAutoAttackSpellID = function()
		return false
	end,
	unknown = "Unknown",
	groupDelay = 0.12,
	selfHealIconWindow = 12,
	getLastPlayerSpell = function()
		return 1234, now
	end,
})

-- Given two incoming damage hits
local firstHandled = component:HandleUnitCombat(
	"player",
	"WOUND",
	"CRITICAL",
	"100",
	"FIRE"
)
component:HandleUnitCombat("player", "WOUND", nil, 50, "FIRE")

-- When the batch timer expires
callbacks[1]()

-- Then
assert(firstHandled == true, "incoming damage was not handled")
assert(#displayed == 1, "incoming damage batch displayed incorrectly")
assert(displayed[1].message == "150 (2 hits, 1 Crit) - fire",
	"incoming damage summary changed")

-- Given an outgoing self-heal amount
component:RecordOutgoingSelfHeal(75)
local callbacksBeforeHeal = #callbacks

-- When the matching UNIT_COMBAT heal arrives
local healHandled = component:HandleUnitCombat(
	"player",
	"HEAL",
	nil,
	75,
	nil
)

-- Then
assert(healHandled == true, "incoming heal was not handled")
assert(#callbacks == callbacksBeforeHeal,
	"matching outgoing self-heal was queued as incoming")
assert(component:HandleUnitCombat("target", "WOUND", nil, 50, nil) == false,
	"non-player combat was consumed")
