MikSBT = {
	Components = {},
}
dofile("API/RestrictedValue.lua")

local now = 10
local total = 100
local restrictedSource = false
local queued = {}
local tickerCancelled = false
local DamageMeterSource = dofile("Components/DamageMeterSource.lua")
local source = DamageMeterSource:New({
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
	damageType = 1,
	pollInterval = 0.1,
	freshDuration = 0.35,
})

-- Given / When
source:Poll()
total = 150
now = 10.1
source:Poll()

-- Then
assert(#queued == 2, "damage meter source duplicated a source GUID")
assert(queued[1][1] == 1234 and queued[1][2] == 100,
	"initial damage meter total changed")
assert(queued[2][2] == 50, "damage meter delta changed")
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
source.config.getSessionSource = function(guid)
	polledGUIDs[#polledGUIDs + 1] = guid
end

-- When the damage meter polls all sources.
source:Poll()

-- Then the nil pet slot does not hide the vehicle source.
assert(#polledGUIDs == 2 and polledGUIDs[2] == "vehicle-guid",
	"vehicle source was skipped when no pet exists")
