MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
local CombatLog = dofile("Components/CombatLogFilter.lua")
local saved = { currentFilter = 1, filters = {
	{ name = "Original", settings = {}, filters = {} },
} }
local log = CombatLog:New({
	getSaved = function() return saved end,
	getTemplate = function() return {
		settings = { unitBraces = true },
		colors = { unitColoring = { [1] = { r = 0.7 } } },
		quickButtonDisplay = { solo = true, party = true, raid = true },
	} end,
	mineFlag = 1,
	petFlag = 2,
})

-- Given the player's existing combat-log settings.
-- When checking readiness before the first reload.
assert(not log:IsReady())

-- Then checking does not mutate their active filter.
assert(saved.currentFilter == 1 and #saved.filters == 1)

-- Given logout, when a new dedicated filter can safely be saved.
-- When writing the settings for the next session.
assert(log:WriteSettings())

-- Then the original filter remains intact and the new one decodes events.
assert(saved.filters[1].name == "Original")
assert(saved.currentFilter == 2 and log:IsReady())
local filter = saved.filters[2]
assert(filter.settings.unitBraces and filter.colors.unitColoring[1].r == 0.7,
	"Blizzard's required default formatting/colour tables were lost")
assert(filter.filters[1].destFlags == nil, "outgoing filter constrained destinations")
assert(filter.filters[1].eventList.SPELL_MISSED_RESIST == nil,
	"colour-only event variants were passed to the event filter")
local direct = filter.colors.eventColoring.SPELL_DAMAGE
assert(log:Kind(direct.r, direct.g, direct.b) == "direct")
local tick = filter.colors.eventColoring.SPELL_PERIODIC_DAMAGE
assert(log:Kind(tick.r, tick.g, tick.b) == "tick")
assert(log:Kind(0.5, 0.5, 0.5) == nil, "unrelated log line confirmed damage")

-- Given repeated reloads.
-- When writing the same dedicated filter again.
assert(log:WriteSettings())

-- Then filters do not accumulate.
assert(#saved.filters == 2)

-- Given another player's messages were enabled in our filter.
filter = saved.filters[2]
filter.filters[1].sourceFlags[4] = true
-- When validating ownership, then the filter is rejected.
assert(not log:IsReady(), "other players' lines counted as ours")
filter.filters[1].sourceFlags[4] = nil

-- Given an additional Done To filter accepting incoming damage.
filter.filters[2] = { destFlags = { [1] = true } }
-- When validating ownership, then the filter is rejected.
assert(not log:IsReady(), "incoming lines counted as ours")
filter.filters[2] = nil
filter.filters[3] = { destFlags = { [1] = true } }
assert(not log:IsReady(), "a sparse incoming filter was accepted")
filter.filters[3] = nil

-- Given changed colours or filter selection.
direct = filter.colors.eventColoring.SPELL_DAMAGE
direct.r = 0
-- When validating the live filter, then changed colours are rejected.
assert(not log:IsReady())
assert(log:WriteSettings())
saved.currentFilter = 1
assert(not log:IsReady())

-- Given inaccessible RGB channels.
issecretvalue = function(value) return type(value) == "table" end
-- When decoding, then no secret is compared or interpreted.
assert(log:Kind({}, 1, 1) == nil)

-- Given malformed saved settings.
saved = 42
-- When checking the filter, then setup stays unavailable without an error.
assert(not log:IsReady())
print("Forever combat-log tests passed")
