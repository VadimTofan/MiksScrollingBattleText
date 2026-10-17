MikSBT = {
	Components = {},
}

local profile = {
	stackSimilarHits = true,
	events = {
		OUTGOING_SPELL_DAMAGE = { scrollArea = "Outgoing" },
		OUTGOING_SPELL_DAMAGE_CRIT = { scrollArea = "Outgoing" },
		OUTGOING_DAMAGE = { scrollArea = "Outgoing" },
		OUTGOING_DAMAGE_CRIT = { scrollArea = "Outgoing" },
	},
}
local callbacks = {}
local displayed
local outputs = {}
local OutgoingBatcher = dofile("Components/OutgoingBatcher.lua")
local batcher = OutgoingBatcher:New({
	getProfile = function()
		return profile
	end,
	formatAmount = function(amount)
		return tostring(amount)
	end,
	display = function(settings, message, texture)
		displayed = { settings, message, texture }
		outputs[#outputs + 1] = displayed
	end,
	after = function(_, callback)
		callbacks[#callbacks + 1] = callback
	end,
	getSpellTexture = function()
		return "texture"
	end,
	isAutoAttack = function(spellID)
		return spellID == 6603
	end,
	autoAttackSpellID = 6603,
	delay = 0.2,
})

-- Given
batcher:Queue(1234, 100, true)
batcher:Queue(1234, 50, false)

-- When
for _, callback in ipairs(callbacks) do callback() end

-- Then
assert(displayed, "outgoing batch was not displayed")
assert(#outputs == 2, "normal and critical hits were merged")
assert(outputs[1][2] == "100" and outputs[2][2] == "50",
	"normal and critical amounts changed")
assert(outputs[1][1] == profile.events.OUTGOING_SPELL_DAMAGE_CRIT
	and outputs[2][1] == profile.events.OUTGOING_SPELL_DAMAGE,
	"separate damage batches did not use their own event settings")
assert(displayed[3] == "texture", "outgoing spell texture changed")

-- Given a pending batch
batcher:Queue(1234, 25, false)
batcher:Reset()

-- When
callbacks[3]()

-- Then
assert(displayed[2] == "50",
	"reset batch was displayed")

-- Given an old timer followed by a new batch for the same spell after reset.
batcher:Queue(1234, 10, false)
batcher:Reset()
batcher:Queue(1234, 20, false)
local previousDisplay = displayed

-- When the old timer fires before the new batch's timer.
callbacks[4]()

-- Then the replacement batch remains pending until its own timer fires.
assert(displayed == previousDisplay, "old timer displayed the replacement batch")
assert(batcher.batches["1234"], "old timer removed the replacement batch")
callbacks[5]()
assert(displayed[2] == "20", "replacement timer did not flush its own batch")

-- Given two critical hits for the same spell.
batcher:Queue(1234, 30, true)
batcher:Queue(1234, 40, true)

-- When their batch timer fires.
callbacks[#callbacks]()

-- Then the count describes that critical batch only.
assert(displayed[2] == "70 [2 Hits]", "critical hit count changed")

-- Given critical damage is assigned to another scroll area.
profile.events.OUTGOING_SPELL_DAMAGE_CRIT.scrollArea = "Critical"
batcher:Queue(1234, 80, true)

-- When that independent critical batch expires.
callbacks[#callbacks]()

-- Then the full amount uses the critical event settings.
assert(displayed[1] == profile.events.OUTGOING_SPELL_DAMAGE_CRIT
	and displayed[2] == "80", "critical scroll-area routing changed")

-- Given critical event settings are disabled.
profile.events.OUTGOING_SPELL_DAMAGE_CRIT.disabled = true
batcher:Queue(1234, 90, true)

-- When the critical batch expires.
callbacks[#callbacks]()

-- Then damage falls back to enabled normal event settings.
assert(displayed[1] == profile.events.OUTGOING_SPELL_DAMAGE
	and displayed[2] == "90", "disabled critical event fallback changed")
