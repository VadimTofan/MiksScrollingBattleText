-- Describe: a kill uses a uniquely matched dead victim, never a later target.
MikSBT = { API = {}, Components = {} }
dofile("API/RestrictedValue.lua")
for _, file in ipairs({ "Context", "Helpers", "Mine", "Spells", "Healing", "Reader" }) do
	dofile("Combat/" .. file .. ".lua")
end
local CombatLog = dofile("Components/CombatLogFilter.lua")
local ns = MikSBT.CombatEngine
local now, timers, alerts, outgoing = 10, {}, {}, {}
local victimPlayer, victimDead, exists = false, true, true
local secret = setmetatable({}, {
	__tostring = function() error("restricted victim inspected") end,
})
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
GetLocale = function() return "enUS" end
UnitExists = function(unit) return unit == "target" and exists end
UnitIsUnit = function(left, right) return left == right end
UnitIsPlayer = function() return victimPlayer end
UnitIsDead = function() return victimDead end
Enum = {
	CombatLogMessageOrder = { Oldest = 0, Newest = 1 },
	PlayerSwingType = { MainHand = 1 },
}
C_EventUtils = { IsEventValid = function() return true end }
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { at = now + delay, callback = callback }
end }
CreateFrame = function() return {
	RegisterEvent = function() end, RegisterUnitEvent = function() end,
	SetScript = function() end, UnregisterAllEvents = function() end,
} end
C_Spell = {
	GetSpellDescription = function() return "Deals 100 Fire damage." end,
	GetSpellTexture = function(id) return id end,
	IsSpellHelpful = function() return false end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
local saved = { filters = {} }
Blizzard_CombatLog_Filters = saved
local log = CombatLog:New({
	getSaved = function() return saved end, mineFlag = 1, petFlag = 2,
})
assert(log:WriteSettings())
log:ConfigureNamespace(ns)
local function Event(event, ...) ns.ReaderEvent(nil, event, ...) end
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
local function Start()
	ns.active, ns.generation = true, ns.generation + 1
	ns.learned = ns.LoadLearned(nil)
	ns.StartReader()
	timers, alerts, outgoing = {}, {}, {}
	exists, victimDead, victimPlayer = true, true, false
	ns.liveRouter = {
		Alert = function(_, record) alerts[#alerts + 1] = record end,
		Out = function(_, record) outgoing[#outgoing + 1] = record end,
	}
end
local function Line(event)
	local rgb = saved.filters[1].colors.eventColoring[event]
	Event("COMBAT_LOG_MESSAGE", secret, rgb.r, rgb.g, rgb.b, 1)
end
local function SpellHit()
	Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
	Line("SPELL_DAMAGE")
	Event("UNIT_COMBAT", "target", "WOUND", "", 100, 4)
end

-- Given a single dying player or NPC hit by the player's own spell.
for _, player in ipairs({ true, false }) do
	Start()
	victimPlayer = player
	-- When its killing line arrives and the target changes before display.
	SpellHit()
	Line("PARTY_KILL")
	Event("PLAYER_TARGET_CHANGED")
	victimPlayer = not player
	Advance(0.2)
	-- Then the original dying victim's type survives the target switch.
	assert(#alerts == 1 and alerts[1].victimIsPlayer == player,
		"killing blow did not retain its matched victim type")
end

-- Given two different dying targets struck in the same frame.
Start()
victimPlayer = true
SpellHit()
Event("PLAYER_TARGET_CHANGED")
victimPlayer = false
SpellHit()
-- When a killing line cannot identify which victim it belongs to.
Line("PARTY_KILL")
Advance(0.2)
-- Then it stays generic instead of taking the most recent target's type.
assert(#alerts == 1 and alerts[1].victimIsPlayer == nil)

-- Given the victim was alive when hit but dies before its killing line is drawn.
Start()
victimPlayer, victimDead = true, false
SpellHit()
-- When that same target becomes dead without a target change.
victimDead = true
Line("PARTY_KILL")
Advance(0.2)
-- Then the still-matching unit can establish the original victim's death.
assert(alerts[1].victimIsPlayer == true)

-- Given an alive target, missing identity, or multiple killing lines.
for _, scenario in ipairs({ "alive", "secret", "missing", "multiple", "no-hit",
    "secret-death", "failed-death" }) do
	Start()
	if scenario == "alive" then victimDead = false end
	if scenario == "secret" then victimPlayer = secret end
	if scenario == "missing" then UnitIsPlayer = nil end
	if scenario == "secret-death" then victimDead = secret end
	if scenario == "failed-death" then
		UnitIsDead = function() error("unit unavailable") end
	end
	if scenario ~= "no-hit" then SpellHit() else ns.reader.sawGrey = true end
	-- When one or more kill signals arrive without a unique typed death.
	Line("PARTY_KILL")
	if scenario == "multiple" then Line("PARTY_KILL") end
	Advance(0.2)
	-- Then all resulting notifications remain unclassified.
	assert(#alerts >= 1)
	for _, alert in ipairs(alerts) do assert(alert.victimIsPlayer == nil) end
	UnitIsPlayer = function() return victimPlayer end
	UnitIsDead = function() return victimDead end
end

-- Given an off-target victim whose nameplate token can be recycled.
Start()
victimPlayer, victimDead = true, false
local targetPlate = true
local targetExists = UnitExists
UnitExists = function(unit) return unit == "nameplate1" or targetExists(unit) end
UnitIsUnit = function(left, right)
	return left == right or (targetPlate and left == "nameplate1"
		and right == "target")
end
Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
targetPlate = false
Event("PLAYER_TARGET_CHANGED")
Line("SPELL_DAMAGE")
Event("UNIT_COMBAT", "nameplate1", "WOUND", "", 100, 4)
Advance(0)
assert(#ns.reader.yourHits == 1, "off-target control hit was not attributed")
-- When its token is removed and reused for a different dead unit.
Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
victimPlayer, victimDead = false, true
Line("PARTY_KILL")
Advance(0.2)
-- Then the later corpse cannot supply the old hit's victim type or death.
assert(alerts[1].victimIsPlayer == nil)
UnitExists = targetExists
UnitIsUnit = function(left, right) return left == right end

-- Given a melee killing blow whose damage report never arrives.
Start()
victimPlayer = true
Event("PLAYER_SWING", 2, 1)
Line("SWING_DAMAGE")
Line("PARTY_KILL")
-- When both the normal alert and the delayed killing-swing fallback fire.
Advance(3)
-- Then both preserve the dying victim's player classification.
assert(alerts[1].victimIsPlayer == true)
assert(#outgoing == 1 and outgoing[1].event == "killed")
assert(outgoing[1].victimIsPlayer == true)
print("Killing-blow victim type tests passed")
