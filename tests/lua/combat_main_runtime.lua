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
MikSBT.Animations.DisplayEvent = function(settings, message, icon, _, amount)
	displayed[#displayed + 1] = { settings, message, icon, amount }
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
	local finish = now + seconds
	while true do
		local nextIndex
		for index, timer in ipairs(timers) do
			if timer.at <= finish and (not nextIndex
				or timer.at < timers[nextIndex].at) then nextIndex = index end
		end
		if not nextIndex then break end
		local timer = table.remove(timers, nextIndex)
		now = timer.at
		timer.callback()
	end
	now = finish
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
	Advance(0.31)

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

	-- Given similar incoming hits arriving 150 ms apart.
	local beforeDamage = #displayed
	Dispatch("UNIT_COMBAT", "player", "WOUND", "", 25, 1)
	-- When the second hit arrives within the 200 ms grouping window.
	Advance(0.15)
	assert(#displayed == beforeDamage, "incoming damage flushed before 200 ms")
	Dispatch("UNIT_COMBAT", "player", "WOUND", "", 15, 1)
	Advance(0.06)
	-- Then one combined damage line is displayed after the window closes.
	assert(#displayed == beforeDamage + 1)
	Dispatch("PLAYER_REGEN_ENABLED")
	-- Then the incoming window and combat notices retain their settings.
	local taken, entered, left = 0, 0, 0
	for _, record in ipairs(displayed) do
		if record[1] == events.INCOMING_DAMAGE then
			taken = taken + 1
			assert(record[2] == "Taken 40")
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
	Advance(0.31)
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

	-- Given incoming damage uses red text and a negative amount template.
	local incomingMessage = events.INCOMING_DAMAGE.message
	local incomingSpellSettings = events.INCOMING_SPELL_DAMAGE
	events.INCOMING_DAMAGE.message = "(%n) -%a"
	events.INCOMING_DAMAGE.colorR = 1
	events.INCOMING_DAMAGE.colorG = 0
	events.INCOMING_DAMAGE.colorB = 0
	events.INCOMING_SPELL_DAMAGE = {
		message = "(%s) -%a", scrollArea = "Incoming",
		colorR = 1, colorG = 0, colorB = 0,
	}
	profile.physical = { colorR = 1, colorG = 1, colorB = 1 }
	profile.fire = { colorR = 1, colorG = 0.5, colorB = 0 }

	for _, school in ipairs({ 1, 4 }) do
		-- When the player's physical or spell damage reaches the real formatter.
		MikSBT.CombatEngine.liveRouter:In({
			event = "damage", amount = 37, school = school,
		})
		Advance(0.21)

		-- Then the minus remains and school colors cannot override event red.
		local damage = displayed[#displayed]
		assert(damage[2] == "-37",
			"incoming damage lost its minus sign or event color: " .. damage[2])
		assert(damage[1].colorR == 1 and damage[1].colorG == 0
			and damage[1].colorB == 0)
	end

	-- Given an opaque incoming damage amount that Lua cannot inspect.
	local opaque = {}
	local wasSecret, largeNumbers = issecretvalue, BreakUpLargeNumbers
	issecretvalue = function(value) return value == opaque end
	BreakUpLargeNumbers = nil

	-- When it takes the restricted display path through the real main module.
	MikSBT.CombatEngine.liveRouter:In({
		event = "damage", amount = opaque, school = 1,
	})

	-- Then the negative template and separate amount keep the event's red style.
	local restrictedDamage = displayed[#displayed]
	assert(restrictedDamage[2] == "-%s" and restrictedDamage[4] == opaque,
		"restricted incoming damage lost its negative template")
	assert(restrictedDamage[1].colorG == 0 and restrictedDamage[1].colorB == 0)
	issecretvalue, BreakUpLargeNumbers = wasSecret, largeNumbers
	events.INCOMING_DAMAGE.message = incomingMessage
	events.INCOMING_SPELL_DAMAGE = incomingSpellSettings

	profile.holy = { colorR = 1, colorG = 0.5, colorB = 0 }
	events.INCOMING_HEAL = { message = "+%a", scrollArea = "Custom heals" }
	events.INCOMING_HEAL_CRIT = nil
	-- When a heal with a Holy school mask is reported.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 90, 2)
	Advance(0.13)
	Advance(0.08)
	-- Then its amount retains heal styling instead of embedded damage colouring.
	local heal = displayed[#displayed]
	assert(heal[1] == events.INCOMING_HEAL)
	assert(heal[2] == "+90", "incoming heal amount received damage-school colour")

	-- Given a healer notice arriving before the UNIT_COMBAT amount.
	events.INCOMING_HEAL.message = "+%a (%n)"
	C_CombatText = { GetCurrentEventInfo = function()
		return "Early healer", 41
	end }
	Dispatch("COMBAT_TEXT_UPDATE", "HEAL")
	Advance(0.15)
	-- When the matching heal arrives within 200 ms.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 41, 2)
	Advance(0.13)
	Advance(0.08)
	-- Then the name reaches the real formatter without an invented icon.
	heal = displayed[#displayed]
	assert(heal[2] == "+41 (Early healer)" and heal[3] == nil)

	-- Given a heal whose name arrives after its 120 ms grouping window.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 42, 2)
	Advance(0.13)
	Advance(0.02)
	C_CombatText.GetCurrentEventInfo = function() return "Late healer", 42 end
	-- When the notice arrives before the 200 ms pairing deadline.
	Dispatch("COMBAT_TEXT_UPDATE", "HEAL")
	Advance(0.06)
	-- Then the same amount is displayed once with the late healer name.
	heal = displayed[#displayed]
	assert(heal[2] == "+42 (Late healer)" and heal[3] == nil)

	-- Given a helpful spell cast while the player explicitly targets themselves.
	local unitIsUnit = UnitIsUnit
	UnitIsUnit = function(a, b)
		return (a == "target" and b == "player") or unitIsUnit(a, b)
	end
	C_Spell.IsSpellHelpful = function(id) return id == 201 end
	events.SELF_HEAL = { message = "Self %a", scrollArea = "Custom heals" }
	for _, healFirst in ipairs({ true, false }) do
		MikSBT.CombatEngine.ResetHealing()
		local beforeHeal = #displayed
		-- When the heal and cast success arrive in either order in one frame.
		if healFirst then
			Dispatch("UNIT_COMBAT", "player", "HEAL", "", 93, 2)
		end
		Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
		if not healFirst then
			Dispatch("UNIT_COMBAT", "player", "HEAL", "", 93, 2)
		end
		Advance(0.21)
		-- Then exactly one self-heal keeps the actual spell's icon.
		heal = displayed[#displayed]
		assert(#displayed == beforeHeal + 1)
		assert(heal[1] == events.SELF_HEAL)
		assert(heal[2] == "Self 93" and heal[3] == "icon",
			"self-target heal lost its spell icon")
	end
	UnitIsUnit = unitIsUnit
	C_Spell.IsSpellHelpful = function() return false end

	-- Given the active filter was changed to include another player's lines.
	local before = #displayed
	filter.filters[1].sourceFlags[99] = true
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 999, 4)
	Advance(0.02)
	Advance(0.31)
	-- Then unconfirmed outgoing damage stays hidden on a log-capable client.
	assert(#displayed == before, "changed filter allowed guessed outgoing damage")
	main.Disable()
	for _, frame in ipairs(frames) do assert(next(frame.events) == nil) end
end
print("Retail and Forever combat runtime tests passed")
