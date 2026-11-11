-- Describe: real loot timings are opt-in and preserve item/money alerts.
local milliseconds, clockReads = 0, 0
local messages, displayed, timers = {}, {}, {}
local callback
GetTimePreciseSec = function()
	clockReads = clockReads + 1
	return milliseconds / 1000
end
GetTime = function() return milliseconds / 1000 end
GetBuildInfo = function() return "1.60.1", "test-build" end
C_Timer = { After = function(delay, handler)
	timers[#timers + 1] = handler
end }
debugprofilestart = function() error("global profiling timer was reset") end
SetCVar = function() error("global profiling setting was changed") end
local profile = {
	qualityExclusions = {}, itemExclusions = {}, itemsAllowed = {},
	events = {
		NOTIFICATION_LOOT = { message = "%e x%a (%t)" },
		NOTIFICATION_MONEY = { message = "%e" },
	},
}
MikSBT = {
	Components = {}, VERSION_STRING = "v12.049",
	Print = function(message) messages[#messages + 1] = message end,
	Profiles = { currentProfile = profile },
	Parser = { RegisterHandler = function(handler) callback = handler end },
	Animations = { DisplayEvent = function(_, message, texture)
		milliseconds = milliseconds + 2
		displayed[#displayed + 1] = { message, texture }
	end },
}
C_Item = {
	GetItemInfo = function()
		milliseconds = milliseconds + 3
		return "Potion", nil, 1, nil, nil, "Consumable",
			nil, nil, nil, "potion-icon"
	end,
	GetItemCount = function()
		milliseconds = milliseconds + 7
		return 0
	end,
	GetItemClassInfo = function() return "Quest" end,
}
LE_ITEM_CLASS_QUESTITEM = 12
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 } }
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
UNKNOWN = "Unknown"
local function Load(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(text, "@" .. path))()
end
Load("Components/LootProfiler.lua")
Load("Components/LootNotifications.lua")
local event = { recipientUnit = "player", eventType = "loot", amount = 2,
	itemLink = "|cffFFFFFF|Hitem:123|h[Potion]|h|r" }

-- Given a normal item receipt with capture off.
-- When the real callback handles it.
callback(event)
-- Then the original alert appears without reading any profiling clocks.
assert(clockReads == 0 and #messages == 0)
assert(displayed[1][1] == "|cFFffffff[Potion]|r x2 (2)")
assert(displayed[1][2] == "potion-icon")

-- Given the opt-in command and an unrelated parser event.
assert(type(MikSBT.Loot.ProfileCommand) == "function")
MikSBT.Loot.ProfileCommand("")
local before = clockReads
-- When unrelated events and item/money loot arrive.
callback({ recipientUnit = "player", eventType = "honor" })
callback({ recipientUnit = "party1", eventType = "loot" })
assert(clockReads == before)
callback(event)
callback({ recipientUnit = "player", eventType = "loot", isMoney = true,
	moneyString = "5 Gold" })
MikSBT.Loot.ProfileCommand("STOP")
-- Then the full handler includes money; item boundaries count only items.
assert(messages[2]:find("2 loot events", 1, true))
assert(messages[2]:find("test-build", 1, true))
assert(messages[3]:find("handler: calls=2 total=14.000ms", 1, true))
assert(messages[4]:find("metadata: calls=1 total=3.000ms", 1, true))
assert(messages[5]:find("count: calls=1 total=7.000ms", 1, true))
assert(messages[6]:find("display: calls=2 total=4.000ms", 1, true))
assert(displayed[2][1] == displayed[1][1])
assert(#displayed == 3)

-- Given capture is stopped.
-- When more loot arrives and the old timer fires.
before = clockReads
callback(event)
timers[1]()
-- Then no new capture work or reports occur.
assert(clockReads == before and #messages == 6)

-- Given a client exposing only the older high-resolution timer.
GetTimePreciseSec = nil
debugprofilestop = function()
	clockReads = clockReads + 1
	return milliseconds
end
Load("Components/LootNotifications.lua")
-- When a fresh capture processes an item using that timer.
MikSBT.Loot.ProfileCommand("start")
callback(event)
MikSBT.Loot.ProfileCommand("stop")
-- Then the fallback clock measures milliseconds without resetting global timers.
assert(messages[#messages - 3]:find(
	"handler: calls=1 total=12.000ms", 1, true))
print("Loot profiling integration tests passed")
