MikSBT = {
	Services = {},
}

local recycled = {}
local Batcher = dofile("Services/Batcher.lua")
Batcher:Configure({
	multipleTargets = "Multiple Targets",
	hits = "Hits",
	crit = "Crit",
	crits = "Crits",
	erase = function(event)
		for key in pairs(event) do
			event[key] = nil
		end
	end,
})

local unmerged = {
	{
		eventType = "OUTGOING_DAMAGE",
		effectName = "Moonfire",
		name = "First",
		class = "MAGE",
		amount = 100,
		isCrit = true,
	},
	{
		eventType = "OUTGOING_DAMAGE",
		effectName = "Moonfire",
		name = "Second",
		class = "WARRIOR",
		amount = 50,
		isCrit = false,
	},
}
local merged = {}

-- Given / When
Batcher:Merge(unmerged, merged, {
	hideTrailer = false,
	recycle = function(event)
		recycled[#recycled + 1] = event
	end,
})

-- Then
assert(#merged == 1, "matching events were not merged")
assert(merged[1].amount == 150, "merged amount differs")
assert(merged[1].name == "Multiple Targets", "multiple targets were not marked")
assert(merged[1].class == nil, "different target classes were retained")
assert(merged[1].isCrit == false, "mixed batch remained fully critical")
assert(merged[1].numMerged == 1 and merged[1].numCrits == 1,
	"merge counters differ")
assert(merged[1].mergeTrailer == " [2 Hits, 1 Crit]",
	"merge trailer differs")
assert(#unmerged == 0, "processed queue was not emptied")
assert(#recycled == 1, "merged-away event was not recycled")
