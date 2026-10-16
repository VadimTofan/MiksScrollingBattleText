MikSBT = {
	Components = {},
}
dofile("API/RestrictedValue.lua")

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

local IncomingCombat = dofile("Components/IncomingCombat.lua")
local component = IncomingCombat:New({
	getProfile = function()
		return profile
	end,
	normalizeNumber = function(value)
		return tonumber(value)
	end,
	buildActionMessage = function(settings, amount)
		return settings.message:gsub("%%a", tostring(amount))
	end,
	shouldSplitCritBatch = function(settings, critSettings, critCount)
		return critCount > 0 and critSettings and not critSettings.disabled
			and settings.scrollArea ~= critSettings.scrollArea
	end,
	resolveBatchDisplaySettings = function(settings, critSettings, hits, crits)
		if hits == crits and critSettings and not critSettings.disabled then
			return critSettings
		end
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
	isHelpfulSpell = function()
		return true
	end,
	playerHasAura = function()
		return false
	end,
	unitHealth = function()
		return 100
	end,
	unitHealthMax = function()
		return 200
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

-- When each independent batch timer expires.
assert(#callbacks == 2, "normal and critical hits need separate timers")
callbacks[1]()
callbacks[2]()

-- Then
assert(firstHandled == true, "incoming damage was not handled")
assert(#displayed == 2, "incoming normal and critical hits were merged")
assert(displayed[1].message == "100 - fire"
	and displayed[2].message == "50 - fire",
	"incoming damage summary changed")

-- Given a UNIT_COMBAT self-heal with no combat-log producer.
local callbacksBeforeHeal = #callbacks

-- When its UNIT_COMBAT heal arrives.
local healHandled = component:HandleUnitCombat(
	"player",
	"HEAL",
	nil,
	75,
	nil
)

-- Then
assert(healHandled == true, "incoming heal was not handled")
assert(#callbacks == callbacksBeforeHeal + 1,
	"incoming self-heal was not queued")
callbacks[#callbacks]()
assert(displayed[#displayed].message:find("75", 1, true),
	"incoming self-heal amount was lost")
assert(component:HandleUnitCombat("target", "WOUND", nil, 50, nil) == false,
	"non-player combat was consumed")

-- Given an old incoming damage timer and a new batch after reset.
component:QueueDamage(10, false)
local oldTimer = callbacks[#callbacks]
component:Reset()
component:QueueDamage(20, false)
local newTimer = callbacks[#callbacks]
local previousCount = #displayed

-- When the old timer fires.
oldTimer()

-- Then it cannot display or remove the replacement damage batch.
assert(#displayed == previousCount, "old damage timer flushed a new batch")
newTimer()
assert(#displayed == previousCount + 1, "new damage batch never displayed")

-- Given an old heal timer and a replacement heal batch after reset.
component:QueueHeal(10, false, nil, "Healer", nil, "SELF_HEAL")
oldTimer = callbacks[#callbacks]
component:Reset()
component:QueueHeal(20, false, nil, "Healer", nil, "SELF_HEAL")
newTimer = callbacks[#callbacks]
previousCount = #displayed

-- When the old heal timer fires.
oldTimer()

-- Then only the replacement timer can flush the new heal batch.
assert(#displayed == previousCount, "old heal timer flushed a new batch")
newTimer()
assert(#displayed == previousCount + 1, "new heal batch never displayed")

-- Describe: mixed incoming and self-heal batches retain critical counts.
for _, eventKey in ipairs({ "INCOMING_HEAL", "SELF_HEAL" }) do
	-- Given normal and critical heals sharing the same scroll area.
	profile.events[eventKey] = { message = "%a", scrollArea = "Incoming" }
	profile.events[eventKey .. "_CRIT"] = {
		message = "%a",
		scrollArea = "Incoming",
	}
	component:QueueHeal(100, false, nil, nil, nil, eventKey)
	component:QueueHeal(50, true, nil, nil, nil, eventKey)
	previousCount = #displayed

	-- When the mixed heal batch expires.
	callbacks[#callbacks]()

	-- Then its summary preserves the total and critical count.
	assert(#displayed == previousCount + 1, "mixed heal batch was split")
	assert(displayed[#displayed].message == "150 (2 hits, 1 Crit)",
		eventKey .. " lost its critical heal count")
end

-- Given a single critical heal.
component:QueueHeal(50, true)

-- When its batch expires.
callbacks[#callbacks]()

-- Then the critical indicator is preserved.
assert(displayed[#displayed].message == "50 (Crit)",
	"single critical heal lost its indicator")

-- Given multiple critical heals in one batch.
component:QueueHeal(50, true)
component:QueueHeal(75, true)

-- When their batch expires.
callbacks[#callbacks]()

-- Then the summary uses the plural critical count.
assert(displayed[#displayed].message == "125 (2 hits, 2 Crits)",
	"multiple critical heals lost their count")

-- Given multiple incoming critical damage hits.
component:QueueDamage(50, true)
component:QueueDamage(75, true)

-- When their batch expires.
callbacks[#callbacks]()

-- Then damage keeps the new hit-count format without a crit trailer.
assert(displayed[#displayed].message == "125 [2 Hits]",
	"critical damage summary changed")

-- Given incoming critical damage uses a separate scroll area and message.
profile.events.INCOMING_DAMAGE_CRIT.scrollArea = "Critical"
profile.events.INCOMING_DAMAGE_CRIT.message = "Critical %a"
component:QueueDamage(80, true)

-- When that critical batch expires.
callbacks[#callbacks]()

-- Then its full amount uses the critical area's event and message.
assert(displayed[#displayed].settings == profile.events.INCOMING_DAMAGE_CRIT
	and displayed[#displayed].message == "Critical 80",
	"incoming critical scroll-area routing changed")

-- Given critical damage settings are disabled.
profile.events.INCOMING_DAMAGE_CRIT.disabled = true
component:QueueDamage(90, true)

-- When the critical batch expires.
callbacks[#callbacks]()

-- Then its damage falls back to the enabled normal event.
assert(displayed[#displayed].settings == profile.events.INCOMING_DAMAGE
	and displayed[#displayed].message == "90",
	"incoming disabled critical event fallback changed")
