-- Given the real main, parser, router and source modules.
local counts = { dispel = 0, interrupt = 0 }
local total = 5
local tickers = {}
local stopped = 0
C_Timer = { After = function() end }
C_Timer.NewTicker = function(_, callback)
	tickers[#tickers + 1] = callback
	return { Cancel = function() stopped = stopped + 1 end }
end
dofile("tests/lua/notification_runtime.lua")
Enum.DamageMeterType = { DamageDone = 1, Dispels = 2, Interrupts = 3 }
Enum.DamageMeterSessionType = { Current = 0 }
C_DamageMeter = {
	IsDamageMeterAvailable = function() return true end,
	GetCombatSessionSourceFromType = function(_, meterType)
		return { combatSpells = {
			{ spellID = 100 + meterType, totalAmount = total },
		} }
	end,
}
UnitGUID = function() return "player-guid" end
local router = MikSBT.Services.EventRouter
local originalResolve = router.Resolve
router.Resolve = function(self, event, profile)
	if counts[event.eventType] ~= nil then
		counts[event.eventType] = counts[event.eventType] + 1
		return nil
	end
	return originalResolve(self, event, profile)
end
MikSBT.Main.Enable()

-- When the sources first see running session totals.
for _, callback in ipairs(tickers) do callback() end

-- Then old totals do not produce new action notifications.
assert(counts.dispel == 0 and counts.interrupt == 0)

-- When both confirmed action totals increase by two.
total = 7
for _, callback in ipairs(tickers) do callback() end

-- Then the real source configuration routes both action types.
assert(counts.dispel == 2, "confirmed dispel deltas were not routed")
assert(counts.interrupt == 2, "confirmed interrupt deltas were not routed")

-- When the module is disabled.
MikSBT.Main.Disable()

-- Then all active source tickers are cancelled.
assert(stopped == #tickers, "disabled action source retained a ticker")
