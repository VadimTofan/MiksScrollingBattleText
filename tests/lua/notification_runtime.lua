-- Describe: real parser and main modules preserve chat notifications.
local frames, displayed, received, errors = {}, {}, {}, {}
local playerGUID
UnitPower = function() error("removed resource notifications read power") end
UnitPowerMax = function() error("removed resource notifications read max power") end
local function EraseTable(value)
	for key in pairs(value) do value[key] = nil end
end
local function BitAnd(left, right)
	local result, place = 0, 1
	while left > 0 and right > 0 do
		if left % 2 == 1 and right % 2 == 1 then result = result + place end
		left, right, place = math.floor(left / 2), math.floor(right / 2), place * 2
	end
	return result
end
bit = {
	band = BitAnd,
	bor = function(...)
		local result = 0
		for _, value in ipairs({...}) do result = result + value - BitAnd(result, value) end
		return result
	end,
}
CreateFrame = function()
	local frame = { scripts = {}, events = {}, visible = false }
	function frame:SetScript(name, handler) self.scripts[name] = handler end
	function frame:RegisterEvent(name) self.events[name] = true end
	function frame:RegisterUnitEvent(name) self.events[name] = true end
	function frame:UnregisterAllEvents() self.events = {} end
	function frame:Show() self.visible = true end
	function frame:Hide() self.visible = false end
	function frame:IsVisible() return self.visible end
	frames[#frames + 1] = frame
	return frame
end
UnitName = function() return "Tester" end
UnitGUID = function() return playerGUID end
UnitClass = function() return "Warrior", "WARRIOR" end
GetTime = function() return 10 end
GetLocale = function() return "enUS" end
InCombatLockdown = function() return false end
IsInRaid = function() return false end
GetNumGroupMembers = function() return 0 end
UnitExists = function() return false end
geterrorhandler = function()
	return function(message) errors[#errors + 1] = message end
end
FormatLargeNumber = tostring
UNKNOWN = "Unknown"
local scheduledTimers = {}
C_Timer = {
	After = function(delay, callback)
		scheduledTimers[#scheduledTimers + 1] = {
			delay = delay, callback = callback,
		}
	end,
	NewTicker = function() end,
}
Enum = { PowerType = {
	Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4,
	Runes = 5, RunicPower = 6, SoulShards = 7, LunarPower = 8,
	HolyPower = 9, Alternate = 10, Maelstrom = 11, Chi = 12,
	Insanity = 13, ArcaneCharges = 16, Fury = 17, Pain = 18, Essence = 19,
} }

local strings = {
	COMBATLOG_HONORAWARD = "You receive %d honor.",
	COMBATLOG_HONORGAIN = "You defeated %s of rank %s for %d honor.",
	FACTION_STANDING_INCREASED = "Reputation with %s increased by %d.",
	FACTION_STANDING_DECREASED = "Reputation with %s decreased by %d.",
	SKILL_RANK_UP = "Your skill in %s increased to %d.",
	COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience.",
	COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience.",
	LOOT_ITEM_SELF = "You receive loot: %s.",
	LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
	LOOT_ITEM_CREATED_SELF = "You create: %s.",
	LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d.",
	LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
	LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.",
	YOU_LOOT_MONEY = "You loot %s.",
	LOOT_MONEY_SPLIT = "Your share is %s.",
	CURRENCY_GAINED = "You receive currency: %s.",
	CURRENCY_GAINED_MULTIPLE = "You receive currency: %sx%d.",
	CURRENCY_GAINED_MULTIPLE_BONUS = "Bonus currency: %sx%d.",
}
for key, value in pairs(strings) do _G[key] = value end

local profile = {
	abilitySuppressions = {}, abilitySubstitutions = {}, skillIconsDisabled = true,
	events = {
		NOTIFICATION_HONOR_GAIN = { message = "+%a Honor", scrollArea = "Static" },
		NOTIFICATION_REP_GAIN = { message = "+%a %e", scrollArea = "Static" },
		NOTIFICATION_REP_LOSS = { message = "-%a %e", scrollArea = "Static" },
		NOTIFICATION_SKILL_GAIN = { message = "%e: %a", scrollArea = "Static" },
		NOTIFICATION_EXPERIENCE_GAIN = { message = "+%a XP", scrollArea = "Static" },
	},
}
MikSBT = {
	Services = {}, Components = {}, Media = {}, Profiles = { currentProfile = profile },
	Compatibility = { Client = { isMainline = false, isClassicContent = true } },
	EraseTable = EraseTable, Print = function() end, ShortenNumber = tostring,
	GetSpellInfo = function(id) return "Spell " .. tostring(id), nil, "icon" end,
	GetSkillName = function(id) return "Spell " .. tostring(id) end,
	Triggers = {
		powerTypes = { MANA = 0, ALTERNATE_POWER = 10 },
		triggerSuppressions = {},
	},
	translations = { MSG_HITS = "hits", MSG_CRIT = "crit", MSG_CRITS = "crits" },
	Animations = {
		IsScrollAreaActive = function(area) return area ~= "Hidden" end,
		IsScrollAreaIconShown = function() return false end,
		DisplayEvent = function(settings, message, icon)
			displayed[#displayed + 1] = { settings, message, icon }
		end,
	},
}
local services = { "Formatter", "Batcher", "Throttler", "EventRouter", "EventPipeline" }
for _, name in ipairs(services) do
	local file = io.open("Services/" .. name .. ".lua")
	if file then file:close(); dofile("Services/" .. name .. ".lua") end
end
-- The baseline still owns a tracker fed only by its dormant combat-log path.
local trackerFile = io.open("Components/SelfHealTracker.lua")
if trackerFile then
	trackerFile:close()
	dofile("Components/SelfHealTracker.lua")
end
for _, name in ipairs({
	"IncomingCombat", "OutgoingBatcher", "DamageMeterSource",
	"OutgoingCombat", "ParserNotifications", "UtilityNotifications",
}) do dofile("Components/" .. name .. ".lua") end
local function LoadAddonFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(source, "@" .. path))()
end
LoadAddonFile("MSBTParser.lua")
LoadAddonFile("MSBTMain.lua")
local parserFrame = frames[1]
local parser = MikSBT.Parser
local main = MikSBT.Main
parser.RegisterHandler(function(event)
	local snapshot = {}
	for key, value in pairs(event) do snapshot[key] = value end
	received[#received + 1] = snapshot
end)

-- Given enabled modules whose player GUID becomes available after loading.
parser.Enable()
main.Enable()
playerGUID = "Player-1"
parserFrame.scripts.OnUpdate(parserFrame, 1)

-- When each supported notification is received through the real event handler.
local cases = {
	{ "CHAT_MSG_COMBAT_HONOR_GAIN", "You receive 25 honor.", "+25 Honor" },
	{ "CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Guild increased by 10.", "+10 Guild" },
	{ "CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Guild decreased by 3.", "-3 Guild" },
	{ "CHAT_MSG_SKILL", "Your skill in Cooking increased to 75.", "Cooking: 75" },
	{ "CHAT_MSG_COMBAT_XP_GAIN", "You gain 100 experience.", "+100 XP" },
}
for index, case in ipairs(cases) do
	assert(parserFrame.events[case[1]], "chat event was not registered")
	parserFrame.scripts.OnEvent(parserFrame, case[1], case[2])

	-- Then rendering and player metadata match the existing behavior.
	assert(displayed[index] and displayed[index][2] == case[3], case[1])
	assert(received[index].recipientGUID == "Player-1", "late GUID was lost")
	assert(received[index].recipientName == "Tester", "player name changed")
end
assert(not parserFrame.events.COMBAT_LOG_EVENT_UNFILTERED, "CLEU was registered")

-- Given loot consumers sharing the parser with the main module.
local lootCases = {
	{ "CHAT_MSG_LOOT", "You receive loot: item-linkx2.", "itemLink", "item-link" },
	{ "CHAT_MSG_MONEY", "You loot 1 Gold.", "moneyString", "1 Gold" },
	{ "CHAT_MSG_CURRENCY", "You receive currency: currency-linkx5.", "itemLink", "currency-link" },
}

-- When item, money and currency messages arrive.
for _, case in ipairs(lootCases) do
	parserFrame.scripts.OnEvent(parserFrame, case[1], case[2])
	local event = received[#received]

	-- Then their payloads still reach registered loot handlers.
	assert(event.eventType == "loot" and event[case[3]] == case[4], case[1])
end

-- Given a disabled notification and an inactive scroll area.
profile.events.NOTIFICATION_HONOR_GAIN.disabled = true
profile.events.NOTIFICATION_EXPERIENCE_GAIN.scrollArea = "Hidden"

-- When matching messages arrive, followed by a malformed message.
parserFrame.scripts.OnEvent(parserFrame, cases[1][1], cases[1][2])
parserFrame.scripts.OnEvent(parserFrame, cases[5][1], cases[5][2])
parserFrame.scripts.OnEvent(parserFrame, cases[1][1], {})

-- Then no extra display or Lua error is produced.
assert(#displayed == 5, "disabled or hidden notifications were displayed")
assert(#errors == 0, errors[1])

-- Describe: retired resource settings cannot reactivate notifications.
-- Given an old profile still contains resource-notification settings.
profile.showAllPowerGains = true
profile.events.NOTIFICATION_POWER_GAIN = {
	message = "+%a Power", scrollArea = "Static",
}
local mainFrame = frames[2]
local displaysBeforePower = #displayed

-- When obsolete power events are delivered to the real event dispatcher.
mainFrame.scripts.OnEvent(mainFrame, "UNIT_POWER_UPDATE", "player", "MANA")
mainFrame.scripts.OnEvent(mainFrame, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")

-- Then no resource event is registered, queried, or displayed.
assert(not mainFrame.events.UNIT_POWER_UPDATE,
	"main still subscribes to removed resource notifications")
assert(#displayed == displaysBeforePower,
	"obsolete saved settings enabled resource notifications")
assert(#errors == 0, errors[1])

-- Describe: incoming damage batches use a 60 ms grouping window.
-- Given enabled normal and critical damage notifications.
profile.events.INCOMING_DAMAGE = {
	message = "Damage %a", scrollArea = "Incoming",
}
profile.events.INCOMING_DAMAGE_CRIT = {
	message = "Damage %a", scrollArea = "Incoming", isCrit = true,
}
local timersBeforeDamage = #scheduledTimers
local displaysBeforeDamage = #displayed

-- When normal and critical hits arrive through the real event route.
mainFrame.scripts.OnEvent(mainFrame, "UNIT_COMBAT", "player", "WOUND", nil, 50)
mainFrame.scripts.OnEvent(mainFrame, "UNIT_COMBAT", "player", "WOUND", "CRITICAL", 100)

-- Then separate batches wait 60 ms before displaying their amounts.
assert(#displayed == displaysBeforeDamage, "incoming damage bypassed grouping")
assert(#scheduledTimers == timersBeforeDamage + 2,
	"normal and critical damage did not get separate timers")
for index = timersBeforeDamage + 1, #scheduledTimers do
	local timer = scheduledTimers[index]
	assert(timer.delay == 0.06, "incoming damage did not use a 60 ms timer")
	timer.callback()
end
assert(displayed[displaysBeforeDamage + 1][2] == "Damage 50",
	"normal damage amount changed")
assert(displayed[displaysBeforeDamage + 2][2] == "Damage 100",
	"critical damage amount changed")

-- Given disabled modules.
main.Disable()
parser.Disable()
local count = #received

-- When a previously registered event is delivered.
parserFrame.scripts.OnEvent(parserFrame, cases[1][1], cases[1][2])

-- Then parser callbacks stop and the main frame unregisters its events.
assert(#received == count, "disabled parser delivered a message")
assert(next(frames[2].events) == nil, "disabled main kept events registered")

-- Describe: health and power triggers keep their existing registration and output.
local health, power = 60, 60
UnitHealth = function() return health end
UnitHealthMax = function() return 100 end
UnitPower = function() return power end
UnitPowerMax = function() return 100 end
UnitIsDeadOrGhost = function() return false end
MikSBT.GetComboPoints = function() return 0 end
MikSBT.HasAura = function() return false end
MikSBT.IsRestrictedContext = function() return false end
MikSBT.GetSpellCooldown = function() return 0, 0 end
local notices = {}
MikSBT.Print = function(message) notices[#notices + 1] = message end
profile.triggers = {
	Health = {
		message = "%r at %a", scrollArea = "Static",
		mainEvents = "UNIT_HEALTH{unitID;;eq;;player;;threshold;;lt;;35}",
	},
	Mana = {
		message = "Mana at %a", scrollArea = "Static",
		mainEvents = "UNIT_POWER_UPDATE{unitID;;eq;;player;;powerType;;eq;;0;;threshold;;lt;;35}",
	},
	Retired = { message = "Stale", mainEvents = "SPELL_DAMAGE{}" },
}
MikSBT.Profiles.masterProfile = { triggers = {} }
LoadAddonFile("MSBTTriggers.lua")
local triggers = MikSBT.Triggers
local triggerFrame = frames[#frames]

-- Given saved health, mana and retired combat-log triggers.
triggers.UpdateTriggers()
triggers.Enable()
triggerFrame.scripts.OnEvent(triggerFrame, "UNIT_HEALTH", "player")
triggerFrame.scripts.OnEvent(triggerFrame, "UNIT_POWER_UPDATE", "player", "MANA")
local displaysBeforeTriggers = #displayed

-- When health and mana cross their configured thresholds.
health, power = 30, 20
triggerFrame.scripts.OnEvent(triggerFrame, "UNIT_HEALTH", "player")
triggerFrame.scripts.OnEvent(triggerFrame, "UNIT_POWER_UPDATE", "player", "MANA")

-- Then active triggers display unchanged messages and the retired trigger stays disabled.
assert(displayed[displaysBeforeTriggers + 1][2] == "Tester at 30")
assert(displayed[displaysBeforeTriggers + 2][2] == "Mana at 20")
assert(not triggerFrame.events.COMBAT_LOG_EVENT_UNFILTERED)
assert(#notices == 1 and notices[1] == "CLEU-based triggers are disabled.")
assert(triggers.categorizedTriggers.SPELL_DAMAGE == nil)
assert(profile.triggers.Retired.mainEvents == "SPELL_DAMAGE{}", "saved trigger was changed")

-- Given disabled trigger processing.
triggers.Disable()
local displaysBeforeDisable = #displayed

-- When another health event arrives.
health = 10
triggerFrame.scripts.OnEvent(triggerFrame, "UNIT_HEALTH", "player")

-- Then disabled triggers produce no display.
assert(#displayed == displaysBeforeDisable)
print("Chat notification runtime tests passed")
