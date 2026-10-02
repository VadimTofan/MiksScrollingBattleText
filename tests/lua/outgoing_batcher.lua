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
	shouldSplitCritBatch = function()
		return false
	end,
	resolveBatchDisplaySettings = function(settings)
		return settings
	end,
})

-- Given
batcher:Queue(1234, 100, true)
batcher:Queue(1234, 50, false)

-- When
callbacks[1]()

-- Then
assert(displayed, "outgoing batch was not displayed")
assert(displayed[2] == "150 (2 hits, 1 Crit)",
	"outgoing stacked-hit summary changed")
assert(displayed[3] == "texture", "outgoing spell texture changed")

-- Given a pending batch
batcher:Queue(1234, 25, false)
batcher:Reset()

-- When
callbacks[2]()

-- Then
assert(displayed[2] == "150 (2 hits, 1 Crit)",
	"reset batch was displayed")

-- Given an old timer followed by a new batch for the same spell after reset.
batcher:Queue(1234, 10, false)
batcher:Reset()
batcher:Queue(1234, 20, false)
local previousDisplay = displayed

-- When the old timer fires before the new batch's timer.
callbacks[3]()

-- Then the replacement batch remains pending until its own timer fires.
assert(displayed == previousDisplay, "old timer displayed the replacement batch")
assert(batcher.batches["1234"], "old timer removed the replacement batch")
callbacks[4]()
assert(displayed[2] == "20", "replacement timer did not flush its own batch")
