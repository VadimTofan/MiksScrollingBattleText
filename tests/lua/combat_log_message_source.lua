MikSBT = { Components = {} }
CreateFrame = function() return {
	SetScript = function() end, RegisterEvent = function() end,
	UnregisterAllEvents = function() end,
} end
local profile = {}
local Source = dofile("Components/CombatLogMessageSource.lua")
local source = Source:New({
	getProfile = function() return profile end,
	getTime = function() return 10 end,
	ownershipWindow = 8, liveWindow = 600, expectWindow = 2.5,
	missLimit = 2,
})

-- Given a line whose owner could not be identified.
source:CountLive(10, nil)

-- When matching a player action against it.
local matched = source:TakeMessage(10, nil, "mine")

-- Then unknown ownership cannot be promoted to player ownership.
assert(not matched, "unclassified line claimed a player action")

-- Given confirmed ownership evidence and pending casts.
source:CountLive(10, "mine")
source:ExpectOwnLine(10)
assert(source:TakeMessage(10, nil, "mine"), "own line was not matched")

-- When the source stops and restarts.
source:Stop()
source:Start()

-- Then evidence from the previous lifecycle cannot own new actions.
assert(#source.recentMessages == 0 and #source.expectedCasts == 0,
	"stopped source retained ownership evidence")
assert(not source:IsLive(), "stopped source retained live state")

-- Describe: delayed ownership checks end with their runtime lifecycle.
local file = assert(io.open("MSBTMain.lua", "r"))
local mainSource = file:read("*a")
file:close()
local body = assert(mainSource:match(
    "(local QueueOwnershipCheck.-)\nfunction eventFrame:UNIT_COMBAT"
))
local now, pending, delivered = 10, nil, 0
local environment = setmetatable({
    GetTime = function() return now end,
    C_Timer = { After = function(_, callback) pending = callback end },
    incomingCombat = { HandleUnitCombat = function() delivered = delivered + 1 end },
    combatLogMessageSource = {
        CheckExpectedCasts = function() end,
        TakeMessage = function() return false end,
    },
}, { __index = _G })
local factory = assert(loadstring(body ..
    "\nreturn QueuePlayerHeal, ClearPendingOwnership"))
setfenv(factory, environment)
local queueHeal, clearPending = factory()

-- Given a heal waiting for delayed ownership resolution.
queueHeal(nil, 50, nil)

-- When the runtime stops before its callback fires.
if clearPending then clearPending() end
now = 11
pending()

-- Then the delayed event cannot restart disabled combat processing.
assert(delivered == 0, "stopped ownership processing delivered a delayed heal")
