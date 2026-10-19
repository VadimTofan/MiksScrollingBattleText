-- Reuse the full legacy runtime regression fixture before exercising both
-- modern clients through the real main module and real adapted reader.
dofile("tests/lua/notification_runtime.lua")

local createFrame = CreateFrame
local frames, timers, displayed = {}, {}, {}
CreateFrame = function(...)
	local frame = createFrame(...)
	frames[#frames + 1] = frame
	return frame
end
local now = 10
GetTime = function() return now end
C_Timer.After = function(delay, callback)
	timers[#timers + 1] = { at = now + delay, callback = callback }
end
C_Timer.NewTicker = function() return { Cancel = function() end } end
UnitExists = function(unit) return unit == "target" end
UnitIsUnit = function(a, b) return a == b end
UnitCanAttack = function() return true end
UnitXP = function() return 0 end
UnitXPMax = function() return 100 end
GetMoney = function() return 0 end
UnitHealthMax = function() return 1000 end
InCombatLockdown = function() return true end
C_Spell = {
	IsSpellHelpful = function() return false end,
	GetSpellDescription = function() return "Deals 42 Fire damage." end,
	GetSpellTexture = function() return "icon" end,
	GetSpellName = function() return "Test spell" end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
DEFAULT_COMBATLOG_FILTER_TEMPLATE = { settings = {}, colors = {} }
Enum.PlayerSwingType = { MainHand = 1, OffHand = 2, Ranged = 3 }
Enum.CombatLogMessageOrder = { Oldest = 0, Newest = 1 }
local meterReads = 0
C_DamageMeter = {
	GetCombatSessionSourceFromType = function() meterReads = meterReads + 1 end,
}
Enum.DamageMeterType = { DamageDone = 0 }
C_EventUtils = { IsEventValid = function(event) return event ~= "PLAYER_SWING" end }
MikSBT.Animations.DisplayEvent = function(settings, message, icon)
	displayed[#displayed + 1] = { settings, message, icon }
end
local events = MikSBT.Profiles.currentProfile.events
events.OUTGOING_SPELL_DAMAGE = { message = "Hit %a", scrollArea = "Custom outgoing" }
events.INCOMING_DAMAGE = { message = "Taken %a", scrollArea = "Custom incoming" }
events.INCOMING_DAMAGE_CRIT = nil
events.NOTIFICATION_COMBAT_ENTER = { message = "+Combat" }
events.NOTIFICATION_COMBAT_LEAVE = { message = "-Combat" }
local function Load(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	assert(loadstring(source, "@" .. path))()
end
for _, path in ipairs({
	"Combat/Context.lua", "Combat/Helpers.lua", "Combat/Mine.lua",
	"Combat/Spells.lua", "Combat/Healing.lua", "Combat/Reader.lua",
	"Components/CombatLogFilter.lua",
	"Components/CombatPresentation.lua", "Components/CombatEngine.lua",
}) do Load(path) end
local function Dispatch(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
	end
end
local function Advance(seconds)
	now = now + seconds
	local pending = timers
	timers = {}
	for _, timer in ipairs(pending) do
		if timer.at <= now then timer.callback()
		else timers[#timers + 1] = timer end
	end
end

for _, forever in ipairs({ false, true }) do
	-- Given a modern client and the player's existing event configuration.
	timers, displayed = {}, {}
	Blizzard_CombatLog_Filters = { filters = {}, currentFilter = 1 }
	MikSBT.Compatibility.Client.isForever = forever
	MikSBT.Compatibility.Client.isMainline = not forever
	MikSBT.Compatibility.Client.hasModernAPI = true
	Load("MSBTMain.lua")
	local main = MikSBT.Main
	local mainFrame = frames[#frames]
	main.Enable()
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 999, 4)
	Advance(0.4)
	Advance(0.3)
	assert(#displayed == 0, "outgoing damage was guessed before filter setup")

	-- When the first session saves the combat filter at logout.
	Dispatch("PLAYER_LOGOUT")
	main.Disable()
	main.Enable()
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("PLAYER_REGEN_DISABLED")
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 42, 4)
	local filter = Blizzard_CombatLog_Filters.filters[1]
	local rgb = filter.colors.eventColoring.SPELL_DAMAGE
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
	Advance(0.02)
	Advance(0.21)

	-- Then one outgoing hit keeps the configured message, area and icon.
	local hits = 0
	for _, record in ipairs(displayed) do
		if record[1] == events.OUTGOING_SPELL_DAMAGE then
			hits = hits + 1
			assert(record[2] == "Hit 42" and record[3] == "icon")
			assert(record[1].scrollArea == "Custom outgoing")
		end
	end
	assert(hits == 1, "modern combat did not produce exactly one hit")
	assert(not mainFrame.events.UNIT_COMBAT, "legacy incoming reader remained active")
	assert(meterReads == 0, "duplicate damage-meter source was queried")

	-- Given incoming damage and combat exit through the same dispatcher.
	Dispatch("UNIT_COMBAT", "player", "WOUND", "", 25, 1)
	Advance(0.13)
	Dispatch("PLAYER_REGEN_ENABLED")
	-- Then the incoming window and combat notices retain their settings.
	local taken, entered, left = 0, 0, 0
	for _, record in ipairs(displayed) do
		if record[1] == events.INCOMING_DAMAGE then
			taken = taken + 1
			assert(record[2] == "Taken 25")
		end
		if record[1] == events.NOTIFICATION_COMBAT_ENTER then entered = entered + 1 end
		if record[1] == events.NOTIFICATION_COMBAT_LEAVE then left = left + 1 end
	end
	assert(taken == 1 and entered == 1 and left == 1)

	-- Given the existing Hide Skills setting is enabled.
	local profile = MikSBT.Profiles.currentProfile
	profile.hideSkills = true
	events.OUTGOING_SPELL_DAMAGE.message = "Hit %a (%s)"
	events.INCOMING_DAMAGE.message = "Taken %a (%s)"
	-- When outgoing and incoming records include their spell names.
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 43, 4)
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
	MikSBT.CombatEngine.liveRouter:In({
		event = "damage", amount = 26, name = "Fireball", school = 1,
	})
	Advance(0.02)
	Advance(0.21)
	-- Then amounts and icons remain, with spell names and empty brackets removed.
	local hiddenOutgoing, hiddenIncoming = false, false
	for _, record in ipairs(displayed) do
		if record[1] == events.OUTGOING_SPELL_DAMAGE and record[2] == "Hit 43" then
			hiddenOutgoing = record[3] == "icon"
		end
		if record[1] == events.INCOMING_DAMAGE and record[2] == "Taken 26" then
			hiddenIncoming = true
		end
	end
	assert(hiddenOutgoing and hiddenIncoming, "Hide Skills did not hide combat spell names")
	-- Buff names remain useful notification text while combat names are hidden.
	events.NOTIFICATION_BUFF = { message = "[%sl]" }
	MikSBT.CombatEngine.liveRouter:Aura(true, false, "Arcane Intellect", "buff-icon")
	assert(displayed[#displayed][2] == "[Arcane Intellect]")
	profile.hideSkills = false
	events.OUTGOING_SPELL_DAMAGE.message = "Hit %a"
	events.INCOMING_DAMAGE.message = "Taken %a"

	-- Given incoming heals have their own styling and damage-school colours are on.
	profile.damageColoringDisabled = false
	profile.holy = { colorR = 1, colorG = 0.5, colorB = 0 }
	events.INCOMING_HEAL = { message = "+%a", scrollArea = "Custom heals" }
	events.INCOMING_HEAL_CRIT = nil
	-- When a heal with a Holy school mask is reported.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 90, 2)
	Advance(0.13)
	-- Then its amount retains heal styling instead of embedded damage colouring.
	local heal = displayed[#displayed]
	assert(heal[1] == events.INCOMING_HEAL)
	assert(heal[2] == "+90", "incoming heal amount received damage-school colour")

	-- Given the active filter was changed to include another player's lines.
	local before = #displayed
	filter.filters[1].sourceFlags[99] = true
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 999, 4)
	Advance(0.02)
	Advance(0.21)
	-- Then unconfirmed outgoing damage stays hidden on a log-capable client.
	assert(#displayed == before, "changed filter allowed guessed outgoing damage")
	main.Disable()
	for _, frame in ipairs(frames) do assert(next(frame.events) == nil) end
end
print("Retail and Forever combat runtime tests passed")
