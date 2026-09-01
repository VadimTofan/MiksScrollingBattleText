MikSBT = {
	Services = {},
}

local profile = {
	hideMergeTrailer = false,
	exclusiveSkillsDisabled = false,
	hideSkills = false,
	hideNames = false,
	events = {
		OUTGOING_DAMAGE = {
			message = "%a",
		},
	},
}
local displayedMessage
local displayedTexture
local mergeCalls = 0
local formattedEvent

local EventPipeline = dofile("Services/EventPipeline.lua")
local pipeline = EventPipeline:New({
	delay = 0.3,
	getProfile = function()
		return profile
	end,
	batcher = {
		Merge = function(_, pending, merged)
			mergeCalls = mergeCalls + 1
			for index, event in ipairs(pending) do
				merged[index] = event
				pending[index] = nil
			end
		end,
	},
	formatter = {
		FormatLegacyEvent = function(_, ...)
			formattedEvent = { ... }
			return "formatted"
		end,
	},
	display = function(_, message, texture)
		displayedMessage = message
		displayedTexture = texture
	end,
	erase = function(event)
		for key in pairs(event) do
			event[key] = nil
		end
	end,
})

-- Given
local event = pipeline:Acquire()
event.eventType = "OUTGOING_DAMAGE"
event.amount = 4500
event.effectTexture = "texture"
pipeline:Queue(event)

-- When the merge delay has not elapsed
local pendingBeforeDelay = pipeline:Tick(0.2)

-- Then
assert(pendingBeforeDelay == true, "queued event was reported inactive")
assert(displayedMessage == nil, "event displayed before the merge delay")

-- When the merge delay elapses
local pendingAfterDelivery = pipeline:Tick(0.1)

-- Then
assert(mergeCalls == 1, "batcher was not called once")
assert(displayedMessage == "formatted", "formatted event was not displayed")
assert(displayedTexture == "texture", "event texture was not preserved")
assert(formattedEvent[1] == "%a", "event message was not formatted")
assert(formattedEvent[2] == 4500, "event amount was not formatted")
assert(pendingAfterDelivery == false, "empty pipeline remained active")
assert(pipeline:Acquire() == event, "delivered event was not recycled")
