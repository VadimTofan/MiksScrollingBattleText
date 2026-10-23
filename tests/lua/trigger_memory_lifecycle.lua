-- Describe: real trigger refresh releases tables from removed profiles.
local file = assert(io.open("MSBTTriggers.lua", "r"))
local source = file:read("*a")
file:close()
local categorize = assert(source:match(
	"local function CategorizeTrigger%b()%s*.-\nend"))
local update = assert(source:match(
	"local function UpdateTriggers%b()%s*.-\nend"))
local environment = setmetatable({
	MSBTProfiles = {
		currentProfile = { triggers = {} }, masterProfile = { triggers = {} },
	},
	firedTimes = {}, triggerExceptions = {}, categorizedTriggers = {},
	listenEvents = {}, triggerSuppressions = {},
	captureFuncs = {}, playerClass = "WARRIOR",
	string_find = string.find, string_gmatch = string.gmatch,
	IsCLEUTriggerMainEvent = function() return false end,
	ConvertType = function(value) return tonumber(value) or value end,
	EraseTable = function(value) for key in pairs(value) do value[key] = nil end end,
}, { __index = _G })
local chunk = assert(loadstring(categorize .. "\n" .. update ..
	"\nreturn UpdateTriggers"))
setfenv(chunk, environment)
local UpdateTriggers = chunk()

-- Given a trigger with a recently-fired exception on an active profile.
local removed = {
	message = "Custom trigger", exceptions = "recentlyFired;;lt;;5",
	mainEvents = "TEST_EVENT{}",
}
local weak = setmetatable({ [removed] = true }, { __mode = "k" })
environment.MSBTProfiles.currentProfile.triggers.Custom = removed
UpdateTriggers()
assert(environment.firedTimes[removed] == 0, "active timer was not initialized")

-- When its profile is removed and triggers refresh.
environment.MSBTProfiles.currentProfile.triggers.Custom = nil
UpdateTriggers()
removed = nil
collectgarbage("collect")

-- Then no runtime state keeps the removed trigger alive.
assert(next(weak) == nil, "removed trigger table remains referenced")
assert(next(environment.firedTimes) == nil, "stale trigger timer remains")

-- Given an active trigger whose timer was previously updated.
local active = {
	message = "Active", exceptions = "recentlyFired;;lt;;5",
	mainEvents = "TEST_EVENT{}",
}
environment.MSBTProfiles.currentProfile.triggers.Active = active
UpdateTriggers()
environment.firedTimes[active] = 123

-- When the active configuration refreshes again.
UpdateTriggers()

-- Then active timers still initialize according to existing refresh behavior.
assert(environment.firedTimes[active] == 0)
assert(environment.triggerExceptions[active])

print("Trigger lifecycle tests passed")
