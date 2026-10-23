-- Describe: setup is checked after login, including reloads with saved filters.
local loggedIn, ready, notifications = false, false, 0
local frame = { events = {} }
function frame:RegisterEvent(event) self.events[event] = true end
IsLoggedIn = function() return loggedIn end
InCombatLockdown = function() return false end
C_Timer = { NewTicker = function()
	return { Cancel = function() end }
end }
MikSBT = { Components = {}, CombatEngine = {
	generation = 0,
	reader = { frame = frame },
	EventAvailable = function() return true end,
	LoadLearned = function() return {} end,
	StartReader = function() end,
	StopReader = function() frame.events = {} end,
	KeepCombatLog = function() end,
} }
local Engine = dofile("Components/CombatEngine.lua")
local engine = Engine:New({
	log = {
		IsReady = function() return ready end,
		ConfigureNamespace = function() end,
	},
	getSaved = function() end,
	setSaved = function() end,
	notify = function() notifications = notifications + 1 end,
	presentation = {},
})

-- Given a reload before Blizzard has restored its saved combat-log filter.
-- When MSBT starts and other addons load before login completes.
engine:Start()
engine:HandleEvent("ADDON_LOADED", "AnotherAddon")
engine:MaintainLog()

-- Then no reload request is made from the incomplete startup state.
assert(notifications == 0, "setup prompted before saved filters finished loading")
assert(frame.events.PLAYER_LOGIN, "engine did not register the login check")

-- Given the saved filter is restored before login finishes.
ready, loggedIn = true, true

-- When login completes and the user disables and re-enables MSBT.
engine:HandleEvent("PLAYER_LOGIN")
engine:Stop()
engine:Start()

-- Then completed setup does not prompt again.
assert(notifications == 0, "valid saved filter requested another reload")
engine:Stop()

-- Given a fresh installation with no filter, starting before login.
ready, loggedIn = false, false
engine = Engine:New(engine.config)
engine:Start()
loggedIn = true

-- When login completes and periodic maintenance checks again.
engine:HandleEvent("PLAYER_LOGIN")
engine:MaintainLog()

-- Then setup requests one reload, without repeating the notification.
assert(notifications == 1, "missing filter did not request exactly one reload")

-- Given setup subsequently succeeds, then the active filter is changed.
ready = true
engine:MaintainLog()
ready = false

-- When maintenance detects the invalid filter.
engine:MaintainLog()

-- Then setup repair can still request a reload.
assert(notifications == 2, "changed filter did not request setup repair")
engine:Stop()
print("Combat setup lifecycle tests passed")
