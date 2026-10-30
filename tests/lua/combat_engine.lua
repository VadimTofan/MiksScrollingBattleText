MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
dofile("Combat/Healing.lua")
dofile("Combat/Reader.lua")
local Engine = dofile("Components/CombatEngine.lua")
local now, timers, frames = 10, {}, {}
local outgoing, incoming, alerts, auras = {}, {}, {}, {}
GetTime = function() return now end
C_Timer = {
	After = function(delay, callback)
		timers[#timers + 1] = { at = now + delay, callback = callback }
	end,
	NewTicker = function() return { Cancel = function() end } end,
}
local unsupported = { PLAYER_SWING = true }
C_EventUtils = { IsEventValid = function(event) return not unsupported[event] end }
CreateFrame = function()
	local frame = { events = {} }
	function frame:RegisterEvent(event)
		assert(not unsupported[event], "registered unsupported event " .. event)
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event) self:RegisterEvent(event) end
	function frame:SetScript(_, callback) self.callback = callback end
	function frame:UnregisterAllEvents() self.events = {} end
	frames[#frames + 1] = frame
	return frame
end
local petExists = false
UnitExists = function(unit) return unit == "target" or (petExists and unit == "pet") end
local targetIsPlayer = false
UnitIsUnit = function(a, b)
	return a == b or (targetIsPlayer and ((a == "target" and b == "player")
		or (a == "player" and b == "target")))
		or (petExists and a == "pettarget" and b == "target")
end
UnitGUID = function(unit) return unit == "player" and "Player-1" or nil end
UnitName = function() return "Tester" end
UnitXP = function() error("combat reader queried the dedicated XP source") end
UnitXPMax = function() error("combat reader queried the dedicated XP source") end
GetMoney = function() error("combat reader queried the dedicated money source") end
UnitHealthMax = function() return 1000 end
GetLocale = function() return "enUS" end
Enum = { CombatLogMessageOrder = { Oldest = 0, Newest = 1 } }
C_Spell = {
	GetSpellDescription = function(id)
		if id == 101 then return "Deals 100 Fire damage." end
		if id == 102 then return "Causes 90 Shadow damage over 9 sec." end
		if id == 201 then return "Heals 90 damage." end
		if id == 301 then return "Deals 20 Nature damage." end
		if id == 401 then return "Deals (315% of Spell Power) Cosmic damage." end
		if id == 402 then return "Deals 100 Chaos damage." end
		if id == 403 then return "Deals 100 Chaos damage over 2 sec." end
		return "Forces the target to speak in Demonic."
	end,
	IsSpellHelpful = function(id) return id == 201 end,
	GetSpellTexture = function(id) return "icon-" .. id end,
	GetSpellName = function(id) return "Spell " .. id end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
Blizzard_CombatLog_Filters = { filters = {} }
local CombatLog = dofile("Components/CombatLogFilter.lua")
local log = CombatLog:New({
    getSaved = function() return Blizzard_CombatLog_Filters end,
    mineFlag = 1, petFlag = 2,
})
assert(log:WriteSettings())
local engine = Engine:New({
	log = log,
	getSaved = function() return nil end,
	setSaved = function() end,
	notify = function() end,
	presentation = {
		Out = function(_, record) outgoing[#outgoing + 1] = record end,
		In = function(_, record) incoming[#incoming + 1] = record end,
		Alert = function(_, record) alerts[#alerts + 1] = record end,
		Aura = function(_, ...) auras[#auras + 1] = {...} end,
		Healer = function() end,
	},
})
local function Event(event, ...)
    if event == "COMBAT_LOG_MESSAGE" then
        local _, kind = ...
        local eventName = kind == "heal" and "SPELL_HEAL"
            or (kind == "spell" and "SPELL_DAMAGE" or "SPELL_PERIODIC_DAMAGE")
        local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[eventName]
        engine:HandleEvent(event, "opaque message", rgb.r, rgb.g, rgb.b, 1)
    else
        engine:HandleEvent(event, ...)
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

-- Given a Retail client that lacks PLAYER_SWING.
-- When starting the actual adapted reader.
engine:Start()
local frame = frames[#frames]
-- Then it registers supported combat events without duplicate gain readers.
assert(frame.events.UNIT_COMBAT and not frame.events.PLAYER_SWING)
assert(not frame.events.CHAT_MSG_LOOT and not frame.events.PLAYER_MONEY)
assert(not frame.events.COMBAT_LOG_EVENT_UNFILTERED)
Event("PLAYER_ENTERING_WORLD")

-- Given a successful damaging cast and its confirming line.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
-- When its critical hit is reported.
Event("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 100, 4)
Advance(0.02)
-- Then the full upstream attribution engine identifies spell and owner.
local record = outgoing[#outgoing]
assert(record and record.result.who == "you" and record.result.spell == 101)
assert(record.amount == 100 and record.crit)

-- Chaos Bolt's tooltip says Chaos; its damage uses 124, not always 127.
for _, example in ipairs({ { spell = 401, school = 106 },
    { spell = 402, school = 127 },
    { spell = 402, school = 124 },
    { spell = 402, school = 126 } }) do
    -- Given a composite-school cast following an unrelated spell.
    Advance(4)
    local previous = #outgoing
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, example.spell)
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)

    -- When its confirmed hit arrives on the target.
    Event("UNIT_COMBAT", "target", "WOUND", "", 100, example.school)
    Advance(0.02)

    -- Then the hit scrolls under its own spell and retains its school.
    assert(#outgoing == previous + 1, "composite-school damage disappeared")
    record = outgoing[#outgoing]
    assert(record.result.who == "you")
    assert(record.result.spell == example.spell, "wrong spell claimed the hit")
    assert(record.school == example.school and not record.result.melee)
end

-- Given an Eye Beam-like channel: a Chaos tooltip with school-124 hits.
Advance(4)
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 403)
Event("UNIT_SPELLCAST_CHANNEL_START", "player", "channel-1", 403)
for index = 1, 5 do
    Advance(0.2)
    local previous = #outgoing

    -- When each confirmed channel hit arrives before a normal DoT tick.
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
    Event("UNIT_COMBAT", "target", "WOUND", "", 10, 124)
    Advance(0.02)

    -- Then every hit retains the channel's spell instead of disappearing.
    assert(#outgoing == previous + 1, "rapid channel hit disappeared")
    record = outgoing[#outgoing]
    assert(record.result.spell == 403, "channel hit used another spell")
end
Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "channel-1", 403)

-- Given incoming damage and healing.
-- When the game reports them on the player and pet.
Event("UNIT_COMBAT", "player", "WOUND", "", 50, 1)
Event("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 60, 2)
Advance(0)
Event("UNIT_COMBAT", "pet", "WOUND", "", 20, 1)
-- Then the new reader owns all three with their original amounts.
assert(#incoming == 3 and incoming[1].amount == 50)
assert(incoming[2].event == "heal" and incoming[2].crit)
assert(incoming[3].pet)

-- Given a proc, combat entry and a spell that cannot deal damage.
Event("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 101)
Event("PLAYER_REGEN_DISABLED")
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 999)
-- Then alerts arrive and spell descriptions exclude harmless spells.
assert(alerts[#alerts].kind == "combat" and alerts[#alerts].entering == true)
assert(MikSBT.CombatEngine.SpellFacts(999).damages == false)

-- Given a damaging spell whose description identifies it as a DoT.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 102)
Advance(3)
Event("COMBAT_LOG_MESSAGE", nil, "tick", 0, 0, 1)
-- When its first periodic hit arrives.
Event("UNIT_COMBAT", "target", "WOUND", "", 30, 32)
Advance(0.02)
-- Then the imported engine distinguishes ticks from direct spells.
record = outgoing[#outgoing]
assert(record.result.spell == 102 and record.result.tick)

-- Given the pet casts a damaging spell at the same target.
petExists = true
Event("UNIT_SPELLCAST_SUCCEEDED", "pet", nil, 301)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", 20, 8)
Advance(0.02)
-- Then the result retains pet ownership and its spell identity.
record = outgoing[#outgoing]
assert(record.result.who == "pet" and record.result.spell == 301)
petExists = false

-- Given a beneficial spell cast on the current friendly target.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
Event("COMBAT_LOG_MESSAGE", nil, "heal", 0, 0, 1)
-- When its matching heal arrives.
Event("UNIT_COMBAT", "target", "HEAL", "", 90, 2)
Advance(0.02)
-- Then it is attributed as an outgoing heal, never as damage.
record = outgoing[#outgoing]
assert(record.event == "heal" and record.result.who == "you")
assert(record.result.spell == 201 and record.amount == 90)

-- Given the player explicitly targets themselves for a helpful spell.
targetIsPlayer = true
Event("PLAYER_TARGET_CHANGED")
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
-- When its heal is reported on the player.
Event("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 91, 2)
Advance(0)
-- Then the self heal keeps the player's spell and its real icon.
record = incoming[#incoming]
assert(record.event == "heal" and record.amount == 91 and record.crit)
assert(record.selfHeal and record.spell == 201 and record.icon == "icon-201",
    "self heal lost its cast's spell icon")
targetIsPlayer = false
Event("PLAYER_TARGET_CHANGED")

-- Given a readable aura added to the player.
local aura = { auraInstanceID = 77, spellId = 1459,
	name = "Arcane Intellect", icon = 135932, isHarmful = false,
	expirationTime = now + 60 }
-- When it is gained, refreshed and removed by the actual reader.
Event("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { aura } })
C_UnitAuras = { GetAuraDataByAuraInstanceID = function() return aura end }
aura.expirationTime = now + 120
Event("UNIT_AURA", "player", {
	isFullUpdate = false, updatedAuraInstanceIDs = {77},
})
Event("UNIT_AURA", "player", {
	isFullUpdate = false, removedAuraInstanceIDs = {77},
})
-- Then all three notifications retain the spell ID for checkbox filtering.
assert(#auras == 3)
assert(auras[1][1] and auras[2][1] and not auras[3][1])
for _, notice in ipairs(auras) do
	assert(notice[3] == "Arcane Intellect" and notice[5] == 1459,
		"aura spell ID was lost between reader and presentation")
end

-- Given pending callbacks from the current session.
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
local before = #outgoing
local ns = MikSBT.CombatEngine
ns.Learn("school", 101, 4)
ns.NoteHealCast("player", 201, "target", now)
local learned = ns.learned
-- When stopped and restarted before they run.
engine:Stop()
assert(next(frame.events) == nil)
-- Then temporary combat records are released and learned data survives.
assert(ns.mine == nil, "disabled engine retained its combat tracker")
for key, value in pairs(ns.reader) do
	if type(value) == "table" and key ~= "frame" then
		assert(next(value) == nil, "disabled reader retained " .. key)
	end
end
assert(ns.MatchHealing("target", now, false) == nil,
	"disabled engine retained healing casts")
assert(ns.learned == learned and ns.Learned("school", 101) == 4)
engine:Start()
Advance(1)
-- Then stale callbacks cannot emit records into the new session.
assert(#outgoing == before)
assert(#frames <= 2, "enable cycles leaked reader frames")
engine:Stop()
-- Given a client missing several modern combat events.
unsupported.COMBAT_LOG_MESSAGE = true
unsupported.SPELL_TEXT_UPDATE = true
-- When the reader is enabled again.
engine:Start()
-- Then supported incoming combat remains registered without startup errors.
assert(frame.events.UNIT_COMBAT and not frame.events.COMBAT_LOG_MESSAGE)
Event("UNIT_COMBAT", "player", "WOUND", "", 33, 1)
assert(incoming[#incoming].amount == 33)

-- Given target timings and cast histories on a client without combat logs.
ns.mine:Hit("expiredTarget", "damage", 4, now, false, false)
ns.mine:Cast("you", 101, "expiredTarget", now)

-- When idle maintenance runs after their useful windows.
Advance(31)
engine:MaintainLog()

-- Then cleanup runs even without further hits or combat-log support.
assert(next(ns.mine.rhythm) == nil, "idle target timings were retained")
assert(next(ns.mine.casts) == nil, "idle cast histories were retained")
engine:Stop()
print("Adapted combat engine tests passed")
