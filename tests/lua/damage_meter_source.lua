MikSBT = {
	Components = {},
}

local now = 10
local total = 100
local restrictedSource = false
local queued = {}
local tickerCancelled = false
local DamageMeterSource = dofile("Components/DamageMeterSource.lua")
local source = DamageMeterSource:New({
	extraUnits = { "pet", "vehicle" },
	isSecret = function(value) return value == "restricted" end,
	sessionType = function() return 0 end,
	createFrame = function() return {
		SetScript = function() end, RegisterEvent = function() end,
		UnregisterAllEvents = function() end,
	} end,
	isAvailable = function()
		return true
	end,
	inCombat = function()
		return true
	end,
	getTime = function()
		return now
	end,
	unitGUID = function(unit)
		if unit == "player" or unit == "pet" then
			return "same-guid"
		end
		return nil
	end,
	getPlayerGUID = function()
		return "fallback-guid"
	end,
	getSessionSource = function()
		if restrictedSource then
			return setmetatable({}, {
				__index = function()
					error("restricted combatSpells")
				end,
			})
		end
		return {
			combatSpells = {
				{ spellID = 1234, totalAmount = total },
			},
		}
	end,
	normalizeNumber = tonumber,
	queue = function(spellID, amount, isCrit)
		queued[#queued + 1] = { spellID, amount, isCrit }
	end,
	newTicker = function(_, callback)
		return {
			callback = callback,
			Cancel = function()
				tickerCancelled = true
			end,
		}
	end,
	damageType = function() return 1 end,
	pollInterval = 0.1,
	freshDuration = 0.35,
})

-- Given / When
source:Poll()
total = 150
now = 10.1
source:Poll()

-- Then
assert(#queued == 1, "a pre-existing session total was emitted")
assert(queued[1][1] == 1234 and queued[1][2] == 50,
	"damage meter delta changed")
assert(source:IsDeltaFresh(now), "recent damage meter delta was stale")

-- Given / When
source:Start()
source:Stop()

-- Then
assert(tickerCancelled, "damage meter ticker was not cancelled")
source:Reset()
assert(not source:IsDeltaFresh(now), "reset retained meter freshness")

-- Given a source whose spell table is restricted
restrictedSource = true

-- When / Then
assert(pcall(function()
	source:Poll()
end), "restricted damage meter source escaped protected handling")

-- Given a player in a vehicle without a pet GUID.
local polledGUIDs = {}
source.config.unitGUID = function(unit)
	if unit == "player" then return "player-guid" end
	if unit == "vehicle" then return "vehicle-guid" end
end
source.config.getSessionSource = function(_, _, guid)
	polledGUIDs[#polledGUIDs + 1] = guid
end

-- When the damage meter polls all sources.
source:Poll()

-- Then the nil pet slot does not hide the vehicle source.
assert(#polledGUIDs == 2 and polledGUIDs[2] == "vehicle-guid",
	"vehicle source was skipped when no pet exists")

-- Given a new live session and an initial hit.
source.config.getSessionSourceByID = function(sessionID)
    assert(sessionID == 42, "wrong live session was queried")
    return { combatSpells = {{ spellID = 1234, totalAmount = total }} }
end
source.config.unitGUID = function(unit)
    if unit == "player" then return "player-guid" end
end
total = 25

-- When the session update arrives.
source:OnEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 1, 42)

-- Then the new session starts at zero and its first hit is displayed.
assert(queued[#queued][2] == 25, "first hit of new session was lost")

-- Given restricted session amounts.
total = "restricted"

-- When a poll encounters the restriction.
source:Poll()

-- Then polling stops and the source can recover at the next combat boundary.
assert(source.isBlind and not source.ticker, "restricted meter did not stop")
total = 10
source:Reset(true)
assert(not source.isBlind and source.ticker, "meter did not recover")
source:Stop(true)
assert(not source.wantsRunning, "shutdown retained running intent")

-- Given a combat boundary while the Current session still holds old totals.
source.config.getSessionSource = function()
    return { combatSpells = {{ spellID = 1234, totalAmount = 9999 }} }
end
local countBeforeBoundary = #queued
source:Reset(true)

-- When polling before the new live session ID arrives.
source:Poll()

-- Then the previous fight is baselined rather than shown as a new hit.
assert(#queued == countBeforeBoundary, "combat boundary replayed the old session")
