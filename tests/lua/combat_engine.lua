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
	function frame:RegisterUnitEvent(event, ...)
		self.units = self.units or {}
		self.units[event] = { ... }
		self:RegisterEvent(event)
	end
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
	IsSpellHelpful = function(id) return id == 201 or id == 3661 end,
	GetSpellTexture = function(id) return "icon-" .. id end,
	GetSpellName = function(id)
		if id == 136 or id == 3661 then return "Mend Pet" end
		return "Spell " .. id
	end,
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
            or (kind == "hot" and "SPELL_PERIODIC_HEAL")
            or (kind == "swing" and "SWING_DAMAGE")
            or (kind == "swingMiss" and "SWING_MISSED")
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

do
    local landed = {}
    engine.config.presentation.Landed = function(_, spell) landed[#landed + 1] = spell end
    -- Given a harmful spell that leaves an aura on the target and reports
    -- nothing else. The aura's event comes in the cast's frame with its
    -- payload hidden, as in a fight.
    assert(frame.units.UNIT_AURA[1] == "player" and frame.units.UNIT_AURA[2] == "target",
        "the target's auras are not heard")
    local missLine = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring.SPELL_MISSED
    local hiddenAuras, hiddenHarm, hiddenRecipient = {}, {}, {}
    local plainSecretCheck = issecretvalue
    issecretvalue = function(value)
        return value == hiddenAuras or value == hiddenHarm or value == hiddenRecipient
    end
    C_Spell.IsSpellHarmful = function(id)
        if id == 506 then return hiddenHarm end
        return true
    end
    local function Settle() Advance(0.016) Advance(0.05) Advance(0.2) end
    local function Lands(unit, spell, info)
        Advance(4)
        Event("UNIT_SPELLCAST_SUCCEEDED", unit, nil, spell)
        if info then Event("UNIT_AURA", "target", info) end
        Settle()
        return #landed
    end
    local describe = C_Spell.GetSpellDescription
    C_Spell.GetSpellDescription = function(id) return id ~= 505 and describe(id) or "" end
    -- When the wait for a hit or a miss of its own is over.
    -- Then the spell is shown as landed: one with no description read, one
    -- whose aura was only refreshed, one whose aura came just before its cast.
    assert(Lands("player", 505, { isFullUpdate = false, addedAuras = hiddenAuras }) == 1,
        "landed debuff was not shown")
    assert(landed[1] == 505, "another spell was shown as landed")
    assert(Lands("player", 503, { isFullUpdate = false, updatedAuraInstanceIDs = { 7 } }) == 2,
        "refreshed debuff was not shown")
    Advance(4)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Settle()
    assert(#landed == 3, "an aura just before its cast was not counted")

    -- Given casts that left nothing of their own on the target: no aura event,
    -- one that only took an aura away, a full update, a spell that does not
    -- harm, a spell whose harm the client hides, and a cast of the pet's.
    -- When the wait is over.
    -- Then none of them is shown as landed.
    assert(Lands("player", 503) == 3, "a cast without an aura was shown as landed")
    assert(Lands("player", 503, { isFullUpdate = false, addedAuras = {}, removedAuraInstanceIDs = { 7 } }) == 3,
        "a faded aura counted as landed")
    assert(Lands("player", 503, { isFullUpdate = true }) == 3, "a full update counted as landed")
    C_Spell.IsSpellHarmful = function(id)
        if id == 506 then return hiddenHarm end
        return id ~= 504
    end
    assert(Lands("player", 504, { isFullUpdate = false, addedAuras = hiddenAuras }) == 3,
        "a harmless spell was shown as landed")
    assert(Lands("player", 506, { isFullUpdate = false, addedAuras = hiddenAuras }) == 3,
        "a spell with hidden harm was shown as landed")
    petExists = true
    assert(Lands("pet", 503, { isFullUpdate = false, addedAuras = hiddenAuras }) == 3,
        "a pet's cast was shown as landed")
    petExists = false

    -- Given a spell that is resisted and a spell that hits, each with an aura
    -- event in its frame.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    engine:HandleEvent("COMBAT_LOG_MESSAGE", "opaque message", missLine.r, missLine.g, missLine.b, 1)
    Event("UNIT_COMBAT", "target", "RESIST", "", 0, 8)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
    Event("UNIT_COMBAT", "target", "WOUND", "", 100, 4)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    -- When the wait is over.
    Settle()
    -- Then the miss and the hit speak for themselves.
    assert(#landed == 3, "a spell with a result of its own was shown as landed")
    -- Given a spell of yours and the same spell of your pet's in one frame,
    -- with an aura event in it: their hit is shown without a name.
    petExists = true
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "pet", nil, 101)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
    Event("UNIT_COMBAT", "target", "WOUND", "", 100, 4)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    -- When the wait is over.
    Settle()
    petExists = false
    assert(not outgoing[#outgoing].result.spell, "the hit of two casts was named")
    -- Then the hit, though unnamed, speaks for your cast.
    assert(#landed == 3, "a spell with an unnamed hit of its own was shown as landed")
    -- Given two spells of yours in one frame, one of them resisted, with an
    -- aura event in it: the miss is shown without a name.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    engine:HandleEvent("COMBAT_LOG_MESSAGE", "opaque message", missLine.r, missLine.g, missLine.b, 1)
    Event("UNIT_COMBAT", "target", "RESIST", "", 0, 8)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    -- When the wait is over.
    Settle()
    assert(outgoing[#outgoing].result.missed and not outgoing[#outgoing].result.spell,
        "the miss of one of two casts was named")
    -- Then the miss, though unnamed, speaks for the debuff.
    assert(#landed == 3, "a spell with an unnamed miss of its own was shown as landed")

    -- Given an aura event on the target, then another target and a cast on it
    -- in the same frame.
    Advance(4)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Settle()
    -- Then the earlier target's aura does not count for the cast.
    assert(#landed == 3, "an aura of the earlier target counted as landed")
    -- Given a cast, then another target and an aura event on that one.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    -- Then the new target's aura does not count for the earlier cast.
    assert(#landed == 3, "an aura of the new target counted for a cast on the earlier one")
    -- Given another target, then a cast on it and its aura in the same frame.
    Advance(4)
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    -- Then the spell is shown as landed on the new target.
    assert(#landed == 4, "a debuff landing on a new target was not shown")
    -- Given a cast and its aura, then another target before the wait is over.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Event("PLAYER_TARGET_CHANGED")
    Settle()
    -- Then the landing already seen is still shown.
    assert(#landed == 5, "a landing seen before the switch was not shown")
    -- Given a cast sent to the target, then another target before it
    -- succeeds and an aura event on that one in its frame.
    local unitName, selected = UnitName, "Creature A"
    UnitName = function(unit) if unit == "target" then return selected end end
    Advance(4)
    Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "sent-before-switch", 503)
    selected = "Creature B"
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "sent-before-switch", 503)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    -- Then the new target's aura does not count for a cast sent to the earlier one.
    assert(#landed == 5, "an aura of the new target counted for a cast sent to the earlier one")
    -- Given a cast sent to the target selected now and its aura in its frame.
    Advance(4)
    Event("UNIT_SPELLCAST_SENT", "player", "Creature B", "sent-to-target", 503)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "sent-to-target", 503)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    UnitName = unitName
    -- Then the spell is shown as landed.
    assert(#landed == 6, "a debuff sent to the selected target was not shown")
    -- Given a cast whose recipient the client hides and an aura in its frame.
    Advance(4)
    Event("UNIT_SPELLCAST_SENT", "player", hiddenRecipient, "sent-hidden", 503)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "sent-hidden", 503)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    Settle()
    -- Then the spell is not shown as landed: the target is not shown to be
    -- its recipient.
    assert(#landed == 6, "the target's aura counted for a cast with a hidden recipient")

    -- Given a spell of yours resisted a moment before a debuff, then a swing
    -- of yours parried and an aura event in the debuff's frame.
    local before = #landed
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    engine:HandleEvent("COMBAT_LOG_MESSAGE", "opaque message", missLine.r, missLine.g, missLine.b, 1)
    Event("UNIT_COMBAT", "target", "RESIST", "", 0, 4)
    Settle()
    Advance(0.5)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Event("COMBAT_LOG_MESSAGE", nil, "swingMiss", 0, 0, 1)
    Event("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = hiddenAuras })
    -- When the wait is over.
    Settle()
    -- Then neither miss is taken for the debuff's own.
    assert(#landed == before + 1, "an earlier miss or a swing's miss hid a landing")
    -- Given the combat log filter not set up, and a debuff landing.
    before = #landed
    local currentFilter = Blizzard_CombatLog_Filters.currentFilter
    Blizzard_CombatLog_Filters.currentFilter = nil
    -- When the wait is over.
    local shown = Lands("player", 503, { isFullUpdate = false, addedAuras = hiddenAuras })
    Blizzard_CombatLog_Filters.currentFilter = currentFilter
    -- Then the landing waits for the filter, as outgoing hits do.
    assert(shown == before, "a landing was shown before the combat log filter was ready")
    issecretvalue = plainSecretCheck
    C_Spell.GetSpellDescription = describe
    C_Spell.IsSpellHarmful = nil
end

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
    -- Keep all five hits and the final buffered hit inside its two seconds.
    Advance(0.15)
    local previous = #outgoing

    -- When channel lines and hits arrive in different frames, either first.
    if index % 2 == 0 then
        Event("UNIT_COMBAT", "target", "WOUND", "", 10, 124)
        Advance(0.03)
    end
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
    if index % 2 ~= 0 then
        Advance(0.03)
        Event("UNIT_COMBAT", "target", "WOUND", "", 10, 124)
    end
    Advance(0.02)
    Advance(0.13)

    -- Then every hit retains the channel's spell instead of disappearing.
    assert(#outgoing == previous + 1, "rapid channel hit disappeared")
    record = outgoing[#outgoing]
    assert(record.result.spell == 403, "channel hit used another spell")
end

-- Given another player's same-school hit during the channel.
local previous = #outgoing
Advance(0.2)

-- When no confirming line arrives for that hit.
Event("UNIT_COMBAT", "target", "WOUND", "", 10, 124)
Advance(0.02)
Advance(0.13)

-- Then the active channel must not claim it.
assert(#outgoing == previous + 1)
assert(outgoing[#outgoing].result.who == "unknown",
    "channel claimed an unconfirmed hit")

-- Given a final hit whose confirming line follows the channel stop.
previous = #outgoing
Event("UNIT_COMBAT", "target", "WOUND", "", 10, 124)
Advance(0.02)

-- When the channel stops before the delayed pairing runs.
Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "channel-1", 403)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
Advance(0.13)

-- Then the buffered final hit still retains Eye Beam's identity.
assert(#outgoing == previous + 1, "final channel hit disappeared")
assert(outgoing[#outgoing].result.spell == 403)

-- Describe: an aura event on the target counts for a debuff's landing only
-- when the target is shown to be the cast's recipient and what the event
-- lets you read does not speak against the cast.
do
    local landed = {}
    engine.config.presentation.Landed = function(_, spell) landed[#landed + 1] = spell end
    local hiddenAuras, hiddenRecipient = {}, {}
    local plainSecretCheck, harmful = issecretvalue, C_Spell.IsSpellHarmful
    issecretvalue = function(value) return value == hiddenAuras or value == hiddenRecipient end
    C_Spell.IsSpellHarmful = function() return true end
    local hidden = { isFullUpdate = false, addedAuras = hiddenAuras }
    local function Lands(info, recipient, guid)
        Advance(4)
        if guid then Event("UNIT_SPELLCAST_SENT", "player", recipient, guid, 503) end
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, 503)
        Event("UNIT_AURA", "target", info)
        Advance(0.016) Advance(0.05) Advance(0.2)
        return #landed
    end

    -- Given a cast sent to the focus, a unit other than the target and
    -- without a nameplate, and an aura event on the target in its frame.
    local unitName, unitExists = UnitName, UnitExists
    UnitName = function(unit)
        if unit == "target" then return "Target B" end
        if unit == "focus" then return "Focus A" end
    end
    UnitExists = function(unit) return unit == "focus" or unitExists(unit) end
    -- When the wait is over.
    local shown = Lands(hidden, "Focus A", "sent-to-focus")
    UnitName, UnitExists = unitName, unitExists
    -- Then the target's aura does not count for the focus's cast.
    assert(shown == 0, "the target's aura counted for a cast on the focus")
    -- Given yourself as the target, a cast whose recipient the client hides
    -- and an aura event on the target, you, in its frame.
    targetIsPlayer = true
    Event("PLAYER_TARGET_CHANGED")
    -- When the wait is over.
    shown = Lands(hidden, hiddenRecipient, "sent-hidden-self")
    targetIsPlayer = false
    Event("PLAYER_TARGET_CHANGED")
    -- Then your own aura does not count for the cast either.
    assert(shown == 0, "an aura of yours counted for a cast with a hidden recipient")

    -- Given auras the payload shows as not the cast's: a buff a party member
    -- put on the target, a debuff of another's, a buff of yours, and a
    -- refreshed aura the client lets you look up, a party member's buff.
    local function Aura(isHarmful, sourceUnit)
        return { auraInstanceID = 999, spellId = 1126, isHarmful = isHarmful, sourceUnit = sourceUnit }
    end
    local unitAuras, refreshed = C_UnitAuras, Aura(false, "party1")
    C_UnitAuras = { GetAuraDataByAuraInstanceID = function(unit, id)
        if unit == "target" and id == 999 then return refreshed end
    end }
    -- When the wait is over.
    -- Then none of them is shown as landed.
    assert(Lands({ isFullUpdate = false, addedAuras = { { auraInstanceID = 999,
        spellId = 1126, isHarmful = false, sourceUnit = "party1" } } }) == 0,
        "a party member's buff counted as landed")
    assert(Lands({ isFullUpdate = false, addedAuras = { Aura(true, "party1") } }) == 0,
        "another's debuff counted as landed")
    assert(Lands({ isFullUpdate = false, addedAuras = { Aura(false, "player") } }) == 0,
        "a buff of yours counted as landed")
    assert(Lands({ isFullUpdate = false, updatedAuraInstanceIDs = { 999 } }) == 0,
        "a party member's refreshed buff counted as landed")
    -- Given a debuff of yours beside a party member's buff, a debuff of your
    -- pet's, and an aura the payload hides beside a party member's buff.
    -- When the wait is over.
    -- Then each is shown as landed.
    assert(Lands({ isFullUpdate = false, addedAuras = { Aura(false, "party1"), Aura(true, "player") } }) == 1,
        "a debuff of yours beside another's buff was not shown")
    assert(Lands({ isFullUpdate = false, addedAuras = { Aura(true, "pet") } }) == 2,
        "a debuff of your pet's was not shown")
    assert(Lands({ isFullUpdate = false, addedAuras = { Aura(false, "party1"), hiddenAuras } }) == 3,
        "a hidden aura beside another's buff was not shown")
    -- Given the client saying the target's auras are secret, and a refreshed
    -- aura in the cast's frame.
    local secrets, looked = C_Secrets, false
    C_Secrets = { ShouldAurasBeSecret = function() return true end }
    C_UnitAuras.GetAuraDataByAuraInstanceID = function() looked = true return refreshed end
    -- When the wait is over.
    shown = Lands({ isFullUpdate = false, updatedAuraInstanceIDs = { 999 } })
    C_UnitAuras, C_Secrets = unitAuras, secrets
    -- Then the aura is not looked up, and the refresh counts as hidden ones do.
    assert(not looked, "a secret aura of the target was looked up")
    assert(shown == 4, "a refresh hidden by the client was not shown")
    -- Given a strike whose line of yours comes in its frame while no hit on
    -- the target is spent on it (in a party, others strike the same enemy in
    -- that moment), and an aura event on the target in that frame.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
    Event("UNIT_AURA", "target", hidden)
    -- When the wait is over.
    Advance(0.016) Advance(0.05) Advance(0.2)
    -- Then the line speaks for the cast: it struck, so the aura is not its mark.
    assert(#landed == 4, "a strike with a line of its own and no hit spent on it was shown as landed")
    -- Given a debuff with a swing's hit line and a tick's line of yours in its
    -- frame, and an aura event in it.
    Advance(4)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 503)
    Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
    Event("COMBAT_LOG_MESSAGE", nil, "tick", 0, 0, 1)
    Event("UNIT_AURA", "target", hidden)
    -- When the wait is over.
    Advance(0.016) Advance(0.05) Advance(0.2)
    -- Then neither line is taken for a hit of the debuff's own.
    assert(#landed == 5, "a swing's hit line or a tick's line hid a landing")
    issecretvalue, C_Spell.IsSpellHarmful = plainSecretCheck, harmful
end

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

-- Describe: a partly blocked hit on you carries the amount blocked.
do
    local blockSecretCheck, hiddenBlock = issecretvalue, {}
    local originalCompatibility = MikSBT.Compatibility
    MikSBT.Compatibility = { Client = { isForever = true } }
    local shieldBlock = 25
    local shieldBlockReads = 0
    GetShieldBlock = function()
        shieldBlockReads = shieldBlockReads + 1
        return shieldBlock
    end
    local function Hit(unit, flag)
        Event("UNIT_COMBAT", unit, "WOUND", flag, 30, 1)
        return incoming[#incoming]
    end

    -- Given your shield block value read out of combat.
    -- When a hit on you is partly blocked.
    local blocked = Hit("player", "BLOCK_REDUCED")
    -- Then it is marked blocked with that value.
    assert(blocked.blocked and blocked.blockedAmount == 25,
        "a partial block lost its blocked amount")

    -- Given the value hidden in combat after it was read.
    issecretvalue = function(value) return value == hiddenBlock end
    shieldBlock = hiddenBlock
    -- When the next hit is partly blocked.
    blocked = Hit("player", "BLOCK_REDUCED")
    -- Then the last value read is kept.
    assert(blocked.blocked and blocked.blockedAmount == 25,
        "a hidden shield block value dropped the last one read")

    -- Given an unblocked hit on you and a partly blocked hit on your pet.
    -- Then neither takes your shield block value.
    assert(not Hit("player", "").blocked, "an unblocked hit was marked blocked")
    assert(not Hit("pet", "BLOCK_REDUCED").blocked,
        "your shield block went to your pet's block")

    -- Given no value ever read (a reader started in combat).
    MikSBT.CombatEngine.reader.shieldBlock = nil
    -- When a hit on you is partly blocked.
    blocked = Hit("player", "BLOCK_REDUCED")
    -- Then it is still marked blocked, without an amount.
    assert(blocked.blocked and blocked.blockedAmount == nil,
        "a partial block with an unknown amount was not marked")

    -- Given Retail exposes block armor rather than flat damage blocked.
    MikSBT.Compatibility.Client = { isMainline = true, isForever = false }
    shieldBlock = 26702
    MikSBT.CombatEngine.reader.shieldBlock = 25
    local readsBeforeRetail = shieldBlockReads

    -- When a Retail hit is partly blocked.
    blocked = Hit("player", "BLOCK_REDUCED")

    -- Then it keeps the block marker without using the armor as an amount.
    assert(blocked.blocked and blocked.blockedAmount == nil,
        "Retail block armor was presented as damage blocked")
    assert(shieldBlockReads == readsBeforeRetail,
        "a non-Forever client queried the flat block amount")

    -- Given client compatibility information is unavailable.
    MikSBT.Compatibility = nil

    -- When another partly blocked hit arrives.
    blocked = Hit("player", "BLOCK_REDUCED")

    -- Then the amount remains unknown rather than assuming Forever rules.
    assert(blocked.blocked and blocked.blockedAmount == nil,
        "an unknown client assumed a flat block amount")

    issecretvalue = blockSecretCheck
    MikSBT.Compatibility = originalCompatibility
    GetShieldBlock = nil
end

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
-- Allow the periodic confirmation window to settle.
Advance(0)
Advance(0.13)
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
local beforeSelfOutgoing = #outgoing
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
-- When its heal is reported on the player.
Event("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 91, 2)
Event("COMBAT_LOG_MESSAGE", nil, "heal")
Advance(0)
Advance(0.13)
-- Then the self heal keeps the player's spell and its real icon.
record = incoming[#incoming]
assert(record.event == "heal" and record.amount == 91 and record.crit)
assert(record.selfHeal and record.spell == 201 and record.icon == "icon-201",
    "self heal lost its cast's spell icon")
-- Then the same matched heal is also outgoing, with its original crit/amount.
assert(#outgoing == beforeSelfOutgoing + 1,
    "self heal was not sent to outgoing")
assert(outgoing[#outgoing].result.who == "you"
    and outgoing[#outgoing].result.spell == 201
    and outgoing[#outgoing].amount == 91 and outgoing[#outgoing].crit)
targetIsPlayer = false
Event("PLAYER_TARGET_CHANGED")

do
    -- Given a helpful player cast while their pet is selected.
    local ns = MikSBT.CombatEngine
    local isUnit = UnitIsUnit
    petExists = true
    UnitIsUnit = function(a, b)
        return (a == "target" and b == "pet") or isUnit(a, b)
    end
    ns.ResetHealing()
    local beforeOut, beforeIn = #outgoing, #incoming
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)

    -- When the pet receives that heal.
    Event("UNIT_COMBAT", "pet", "HEAL", "", 92, 2)
    Event("UNIT_COMBAT", "target", "HEAL", "", 92, 2)
    Event("COMBAT_LOG_MESSAGE", nil, "heal")
    Advance(0)
    Advance(0.13)

    -- Then it is your outgoing heal and retains the pet's incoming record.
    assert(#outgoing == beforeOut + 1, "pet heal was not sent to outgoing")
    assert(outgoing[#outgoing].result.who == "you"
        and outgoing[#outgoing].result.spell == 201
        and not outgoing[#outgoing].pet, "pet recipient became pet caster")
    assert(#incoming == beforeIn + 1 and incoming[#incoming].pet)
    UnitIsUnit, petExists = isUnit, false
    ns.ResetHealing()
end

do
    -- Given self/pet heal bindings while an unrelated enemy remains selected.
    local ns = MikSBT.CombatEngine
    local unitName = UnitName
    UnitName = function(unit)
        if unit == "player" then return "Healer", "Realm" end
        if unit == "pet" then return "Wolf" end
        return "Enemy"
    end
    for _, case in ipairs({
        { unit = "player", name = "Healer-Realm", guid = "self-cast" },
        { unit = "pet", name = "Wolf", guid = "pet-cast" },
    }) do
        ns.ResetHealing()
        Advance(4)
        local before = #outgoing
        -- When a successful heal's actual recipient receives the heal.
        Event("UNIT_SPELLCAST_SENT", "player", case.name, case.guid, 201)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", case.guid, 201)
        Event("UNIT_COMBAT", case.unit, "HEAL", "", 94, 2)
        Event("COMBAT_LOG_MESSAGE", nil, "heal")
        Advance(0)
        Advance(0.13)
        -- Then targeting the enemy does not hide your outgoing heal.
        assert(#outgoing == before + 1,
            "actual self/pet cast recipient was not used for outgoing heal")
        assert(outgoing[#outgoing].result.who == "you"
            and outgoing[#outgoing].result.spell == 201)
    end

    -- Given one pet HoT cast while an enemy remains selected.
    ns.ResetHealing()
    Event("UNIT_SPELLCAST_SENT", "player", "Wolf", "pet-hot", 201)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pet-hot", 201)
    for tick = 1, 2 do
        Advance(1)
        local before = #outgoing
        -- When each periodic heal has its own confirmation.
        Event("UNIT_COMBAT", "pet", "HEAL", "", 20, 2)
        Event("COMBAT_LOG_MESSAGE", nil, "hot")
        Advance(0)
        Advance(0.13)
        -- Then even the first two ticks use outgoing HoT presentation.
        assert(#outgoing == before + 1, "early pet HoT tick was lost")
        assert(outgoing[#outgoing].result.tick
            and outgoing[#outgoing].result.spell == 201)
    end

    -- Given a pet heal sent with no target (Mend Pet) while an enemy remains
    -- selected.
    ns.ResetHealing()
    local describe = C_Spell.GetSpellDescription
    C_Spell.GetSpellDescription = function()
        return "Heals your pet 68 health every second while you focus."
    end
    Event("UNIT_SPELLCAST_SENT", "player", "", "mend-pet", 3661)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "mend-pet", 3661)
    local beforeUnrelated = #outgoing
    -- When another healer heals the player before Mend Pet's first tick.
    Event("UNIT_COMBAT", "player", "HEAL", "", 14, 2)
    Advance(0)
    Advance(0.13)
    -- Then this incoming heal cannot consume or be labeled as Mend Pet.
    assert(#outgoing == beforeUnrelated)
    assert(incoming[#incoming].spell == nil,
        "unrelated incoming self-heal was labeled as Mend Pet")
    for tick = 1, 2 do
        Advance(1)
        local before = #outgoing
        -- When each of its ticks heals the pet with its own confirmation.
        Event("UNIT_COMBAT", "pet", "HEAL", "", 68, 1)
        Event("COMBAT_LOG_MESSAGE", nil, "hot")
        Advance(0)
        Advance(0.13)
        -- Then the cast is bound to the pet and shown as your outgoing heal.
        assert(#outgoing == before + 1,
            "a heal sent with no target was not shown as outgoing")
        assert(outgoing[#outgoing].result.who == "you"
            and outgoing[#outgoing].result.spell == 3661)
    end

    -- Given a helpful spell that does not heal, sent with no target.
    ns.ResetHealing()
    C_Spell.GetSpellDescription = function()
        return "Increases ranged attack power by 20."
    end
    Event("UNIT_SPELLCAST_SENT", "player", "", "aspect", 201)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "aspect", 201)
    Advance(1)
    local beforeBuff = #outgoing
    -- When another healer's tick lands on the pet.
    Event("UNIT_COMBAT", "pet", "HEAL", "", 40, 2)
    Event("COMBAT_LOG_MESSAGE", nil, "hot")
    Advance(0)
    Advance(0.13)
    -- Then the buff is not taken for the heal's cast.
    assert(#outgoing == beforeBuff, "a buff sent with no target was shown as a heal")
    C_Spell.GetSpellDescription = describe
    -- Its unclaimed line must not confirm a later heal.
    Advance(1)

    -- Given no matching local cast, or a hidden recipient that cannot be read.
    ns.ResetHealing()
    local before = #outgoing
    Event("UNIT_COMBAT", "player", "HEAL", "", 95, 2)
    Advance(0)
    local secretCheck, hiddenName = issecretvalue, {}
    issecretvalue = function(value) return value == hiddenName end
    Event("UNIT_SPELLCAST_SENT", "player", hiddenName, "hidden-cast", 201)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "hidden-cast", 201)
    Event("UNIT_COMBAT", "pet", "HEAL", "", 96, 2)
    Advance(0)
    -- Then received heals are not guessed to be your outgoing heals.
    assert(#outgoing == before, "another healer's spell was claimed as yours")
    issecretvalue = secretCheck

    -- Given recipient data that is cleared before a later cast succeeds.
    ns.NoteHealTarget("player", "Wolf", "stale-cast", 201, now)
    ns.ResetHealing()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "stale-cast", 201)
    Event("UNIT_COMBAT", "pet", "HEAL", "", 97, 2)
    Advance(0)
    -- Then reset cannot lend stale recipient information to the next session.
    assert(#outgoing == before, "reset retained a stale healing recipient")
    UnitName = unitName
    ns.ResetHealing()
end

do
    -- Given a recent helpful self cast but no confirming heal line of ours.
    local ns = MikSBT.CombatEngine
    ns.ResetHealing()
    targetIsPlayer = true
    local before = #outgoing
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
    -- When an incoming heal has no evidence that the player caused it.
    Event("UNIT_COMBAT", "player", "HEAL", "", 98, 2)
    Advance(0)
    Advance(0.13)
    -- Then it must not become an outgoing heal merely due to cast timing.
    assert(#outgoing == before,
        "unconfirmed received healing was claimed as outgoing")
    targetIsPlayer = false
    ns.ResetHealing()
end

-- Describe: Windfury reports a proc before the swing hit and another after it.
local windfuryCompatibility = MikSBT.Compatibility
MikSBT.Compatibility = { Client = { isForever = true } }
unsupported.PLAYER_SWING = nil
Enum.PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }
local windfurySecretCheck = issecretvalue
local firstProc, normalHit, delayedProc = {}, {}, {}
issecretvalue = function(value)
	return value == firstProc or value == normalHit or value == delayedProc
end

-- Given one native swing and its melee line plus two direct proc lines.
local observations = {}
MikSBT.CombatEngine.traceCombat = function(stage, hit, info)
	observations[#observations + 1] = { stage = stage, hit = hit, info = info }
end
Advance(4)
local burstStart = now
local beforeBurst = #outgoing
Event("PLAYER_SWING", 3.8, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)

-- When the first proc precedes the normal hit, matching the captured timing.
Advance(0.213)
Event("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
Advance(0.01)
Advance(0.362)
Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
Advance(0.01)

-- Given an unrelated hit on another nameplate before the delayed proc.
MikSBT.CombatEngine.reader.plates.nameplate1 = true
Advance(0.2)
Event("UNIT_COMBAT", "nameplate1", "WOUND", "", 321, 1)
Advance(0.01)

-- When the second physical proc lands 0.424 seconds after the normal hit.
Advance(burstStart + 1.009 - now)
Event("UNIT_COMBAT", "target", "WOUND", "", delayedProc, 1)
Advance(0.01)

-- Then both opaque proc amounts and the ordinary swing retain ownership.
local burst = {}
for index = beforeBurst + 1, #outgoing do
	local hit = outgoing[index]
	if hit.amount == 321 then
		assert(hit.result.who == "unknown",
			"a delayed proc line was stolen by another target")
	elseif hit.result.who == "you" then
		burst[#burst + 1] = hit
	end
end
assert(#burst == 3, "Windfury's delayed second proc disappeared")
assert(burst[1].amount == firstProc and burst[1].result.proc)
assert(burst[2].amount == normalHit and burst[2].result.melee)
assert(burst[3].amount == delayedProc and burst[3].result.proc,
	"the delayed Windfury proc lost its original amount or classification")
-- Then diagnostics see raw records before decisions and pairing rejections.
local raw, decisions, pairsSeen = {}, {}, 0
for _, observation in ipairs(observations) do
	if observation.stage == "report" then raw[observation.hit.record] = true end
	if observation.stage == "decision" then
		assert(raw[observation.hit.record], "decision preceded raw report tracking")
		assert(observation.info and observation.info.stage == "decision",
			"decision omitted its confirmation and restriction metadata")
		decisions[observation.hit.record] = true
	end
	if observation.stage == "candidate" then pairsSeen = pairsSeen + 1 end
end
assert(raw[burst[3]] and decisions[burst[3]] and pairsSeen > 0,
	"reader omitted diagnostic report, decision or pairing evidence")
MikSBT.CombatEngine.traceCombat = nil

-- Given both confirming proc lines have already been consumed.
-- When another physical hit arrives in the same timing window.
Event("UNIT_COMBAT", "target", "WOUND", "", 322, 1)
Advance(0.01)

-- Then that hit cannot reuse either proc confirmation.
assert(outgoing[#outgoing].amount == 322)
assert(outgoing[#outgoing].result.who == "unknown",
	"a proc confirmation was reused for unrelated damage")

for _, example in ipairs({
	{ forever = true, school = 4, delay = 0.424, kind = "spell" },
	{ forever = true, school = 1, delay = 1.1, kind = "spell" },
	{ forever = true, school = 1, delay = 0.424, kind = "tick" },
	{ forever = false, school = 1, delay = 0.424, kind = "spell" },
}) do
	-- Given a spare confirmation outside the supported physical-proc case.
	Advance(4)
	MikSBT.Compatibility.Client.isForever = example.forever
	Event("PLAYER_SWING", 3.8, 0)
	Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
	Event("COMBAT_LOG_MESSAGE", nil, example.kind, 0, 0, 1)
	Advance(0.585)
	Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
	Advance(0.01)

	-- When a magic, late, DoT-confirmed or Retail hit follows the swing.
	Advance(example.delay - 0.01)
	Event("UNIT_COMBAT", "target", "WOUND", "", 323, example.school)
	Advance(0.01)

	-- Then the widened path does not claim that unrelated damage.
	assert(outgoing[#outgoing].amount == 323)
	assert(outgoing[#outgoing].result.who == "unknown",
		"delayed-proc matching claimed an unsupported report")
end

-- Given a native swing and its melee line, with no other line of yours.
Advance(4)
MikSBT.Compatibility.Client.isForever = true
local beforeMagicHit = #outgoing
Event("PLAYER_SWING", 3.8, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)

-- When someone else's magic hit lands just before the swing's own hit.
Advance(0.5)
Event("UNIT_COMBAT", "target", "WOUND", "", 324, 4)
Advance(0.085)
Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
Advance(0.5)

-- Then the swing keeps its line and the magic hit stays someone else's.
local magicHit, swingHit
for index = beforeMagicHit + 1, #outgoing do
	local hit = outgoing[index]
	if hit.amount == 324 then magicHit = hit end
	if hit.amount == normalHit then swingHit = hit end
end
assert(magicHit and magicHit.result.who == "unknown",
	"a magic hit took a melee swing's line")
assert(swingHit and swingHit.result.who == "you" and swingHit.result.melee,
	"a melee swing lost its line to a magic hit")

for _, example in ipairs({
	{ line = "swing", report = "WOUND", amount = 325 },
	{ line = "swingMiss", report = "DODGE", amount = 0, school = 4 },
}) do
	-- Given a native swing and its melee line.
	Advance(4)
	local beforeReport = #outgoing
	Event("PLAYER_SWING", 3.8, 0)
	Event("COMBAT_LOG_MESSAGE", nil, example.line, 0, 0, 1)

	-- When its own report has no readable school, or is a miss of any school.
	Advance(0.585)
	Event("UNIT_COMBAT", "target", example.report, "", example.amount, example.school)
	Advance(0.5)

	-- Then that report still takes the swing's line.
	local result = #outgoing == beforeReport + 1 and outgoing[#outgoing].result
	assert(result and result.who == "you" and result.melee,
		"a swing's own report lost its line over its school")
end

-- Describe: a partly blocked hit of yours is marked, without an amount.
for _, example in ipairs({
	{ flag = "BLOCK_REDUCED", amount = 326, blocked = true },
	{ flag = "", amount = 327 },
	{ flag = "CRITICAL", amount = 328 },
	{ flag = "BLOCK_REDUCED", amount = 0, line = "swingMiss", event = "miss" },
}) do
	-- Given a native swing and its melee line.
	Advance(4)
	Event("PLAYER_SWING", 3.8, 0)
	Event("COMBAT_LOG_MESSAGE", nil, example.line or "swing", 0, 0, 1)

	-- When its report carries the flag of a partly blocked hit, none, another, or the flag
	-- with no damage at all.
	Advance(0.585)
	Event("UNIT_COMBAT", "target", "WOUND", example.flag, example.amount, 1)
	Advance(0.5)

	-- Then only the partly blocked hit is marked, and no amount blocked is named.
	local hit = outgoing[#outgoing]
	assert(hit.event == (example.event or "damage") and hit.result.who == "you"
		and hit.blocked == example.blocked and hit.blockedAmount == nil,
		("a %s of yours with the flag '%s' came out with blocked = %s"):format(
			hit.event, example.flag, tostring(hit.blocked)))
end

-- Given the later capture: proc confirmations trail the swing by 0.099 s.
Advance(4)
Event("PLAYER_ENTERING_WORLD")
MikSBT.Compatibility.Client.isForever = true
local beforeOffsetBurst = #outgoing
Event("PLAYER_SWING", 3.8, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
Advance(0.099)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)

-- When the ordinary hit lands first and both proc reports follow it.
Advance(0.213)
Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
Advance(0.01)
Advance(0.369)
Event("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
Advance(0.01)
Advance(0.484)
Event("UNIT_COMBAT", "target", "WOUND", "GLANCING", delayedProc, 1)
Advance(0.01)

-- Then the offset confirmations still explain both later physical hits.
local offsetBurst = {}
for index = beforeOffsetBurst + 1, #outgoing do
	if outgoing[index].result.who == "you" then
		offsetBurst[#offsetBurst + 1] = outgoing[index]
	end
end
assert(#offsetBurst == 3,
	"Windfury reports were lost when their lines followed the native swing")
assert(offsetBurst[1].amount == normalHit and offsetBurst[1].result.melee)
assert(offsetBurst[2].amount == firstProc and offsetBurst[2].result.proc)
assert(offsetBurst[3].amount == delayedProc and offsetBurst[3].result.proc)

-- Describe: a physical ability can trigger delayed Windfury between swings.
local originalDescription = C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id)
	if id == 17364 then return "Instantly deals weapon damage." end
	if id == 21949 then
		return "Wounds the target causing them to bleed for 210 damage over 7 sec."
	end
	return originalDescription(id)
end
local originalClass, originalEnchant = UnitClass, GetWeaponEnchantInfo
UnitClass = function() return "Shaman", "SHAMAN" end
GetWeaponEnchantInfo = function() return true, 10000, 0, 283 end

-- Given the captured swing, normal hit, and later physical cast confirmations.
Advance(4)
Event("PLAYER_ENTERING_WORLD")
local abilityStart, beforeAbility = now, #outgoing
Event("PLAYER_SWING", 3.8, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
Advance(0.429)
Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
Advance(0.01)
Advance(abilityStart + 1.047 - now)
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
for index = 1, 3 do
	Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
end
Event("UNIT_COMBAT", "target", "WOUND", "", 326, 1)
Advance(0.01)

-- When the two opaque physical reports arrive at the captured delays.
Advance(abilityStart + 1.293 - now)
Event("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
Advance(0.01)
Advance(abilityStart + 1.632 - now)
Event("UNIT_COMBAT", "target", "WOUND", "", delayedProc, 1)
Advance(0.01)

-- Then both proc reports retain ownership and their original amounts.
local abilityProcs = 0
for index = beforeAbility + 1, #outgoing do
	local report = outgoing[index]
	if report.amount == firstProc or report.amount == delayedProc then
		assert(report.result.who == "you" and report.result.proc,
			"ability-triggered Windfury was rejected by native-swing timing")
		abilityProcs = abilityProcs + 1
	end
end
assert(abilityProcs == 2, "ability-triggered proc report disappeared")

-- When an additional hit arrives after both spare confirmations were used.
Event("UNIT_COMBAT", "target", "WOUND", "", 327, 1)
Advance(0.01)

-- Then a proc cannot consume the same confirmation twice.
assert(outgoing[#outgoing].amount == 327
	and outgoing[#outgoing].result.who == "unknown")

for _, example in ipairs({
	{ name = "Retail", forever = false },
	{ name = "missing Windfury enchant", enchanted = false },
	{ name = "magic damage", school = 4 },
	{ name = "periodic confirmation", kind = "tick" },
	{ name = "nonphysical ability", spell = 101 },
	{ name = "another target", unit = "nameplate1" },
	{ name = "expired confirmation", delay = 1.46 },
}) do
	-- Given a spare line with one required proc condition absent.
	Advance(4)
	Event("PLAYER_ENTERING_WORLD")
	MikSBT.Compatibility.Client.isForever = example.forever ~= false
	GetWeaponEnchantInfo = function()
		return example.enchanted ~= false, 10000, 0, 283
	end
	Event("PLAYER_SWING", 3.8, 0)
	Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
	Advance(0.429)
	Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
	Advance(0.01)
	Advance(0.608)
	Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, example.spell or 17364)
	Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
	Event("COMBAT_LOG_MESSAGE", nil, example.kind or "spell", 0, 0, 1)
	Event("UNIT_COMBAT", "target", "WOUND", "", 328, 1)
	Advance(0.01)
	MikSBT.CombatEngine.reader.plates.nameplate1 = true

	-- When the unrelated or unsupported delayed report arrives.
	Advance((example.delay or 0.585) - 0.01)
	Event("UNIT_COMBAT", example.unit or "target", "WOUND", "",
		329, example.school or 1)
	Advance(0.2)

	-- Then the new path cannot assign ownership to that report.
	local rejected
	for index = #outgoing, 1, -1 do
		if outgoing[index].amount == 329 then
			rejected = outgoing[index]
			break
		end
	end
	assert(rejected and rejected.result.who == "unknown",
		"weapon-proc matching accepted " .. example.name)
end
-- Describe: an axe bleed can coincide with an active Windfury enchant.
-- Given the bleed application alongside a native swing and a direct line.
Advance(4)
Event("PLAYER_ENTERING_WORLD")
local bleedStart, beforeBleed = now, #outgoing
Event("PLAYER_SWING", 3.8, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing", 0, 0, 1)
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 21949)
Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
Advance(0.02)
Advance(0.5)
Event("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
Advance(0.02)

-- When its first opaque periodic hit arrives with a periodic confirmation.
Advance(bleedStart + 1 - now)
Event("COMBAT_LOG_MESSAGE", nil, "tick", 0, 0, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", delayedProc, 1)
Advance(0.2)
Advance(1)

-- Then the ambiguous application stays visible without a false Windfury name,
-- and the confirmed tick retains the bleed's identity.
local application, bleedTick
for index = beforeBleed + 1, #outgoing do
	local report = outgoing[index]
	if report.amount == firstProc then application = report end
	if report.amount == delayedProc then bleedTick = report end
end
assert(application and application.result.who == "you")
assert(application.result.procSpell ~= 8232,
	"axe bleed application received the Windfury fallback name")
assert(bleedTick and bleedTick.result.who == "you"
	and bleedTick.result.spell == 21949 and bleedTick.result.tick,
	"confirmed axe bleed tick lost its periodic spell identity")
Event("PLAYER_ENTERING_WORLD")
C_Spell.GetSpellDescription = originalDescription
UnitClass, GetWeaponEnchantInfo = originalClass, originalEnchant

MikSBT.CombatEngine.reader.plates.nameplate1 = nil
MikSBT.Compatibility = windfuryCompatibility
issecretvalue = windfurySecretCheck
unsupported.PLAYER_SWING = true

-- Describe: Forever's queued melee strikes emit a zero report before the hit.
local queuedSpells = {
	78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286,
	6807, 6808, 6809, 8972, 9745, 9880, 9881,
	2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266,
}
local descriptions = C_Spell.GetSpellDescription
local opaqueZero, opaqueDamage = {}, {}
local previousSecretCheck = issecretvalue
issecretvalue = function(value)
	return value == opaqueZero or value == opaqueDamage
end
local previousCompatibility = MikSBT.Compatibility
MikSBT.Compatibility = { Client = { isForever = true } }
local strikeDescriptions = { [105] = true }
for _, spell in ipairs(queuedSpells) do strikeDescriptions[spell] = true end
C_Spell.GetSpellDescription = function(spell)
	if strikeDescriptions[spell] then
		return "A strong attack that increases melee damage by 5."
	end
	return descriptions(spell)
end

for _, spell in ipairs(queuedSpells) do
	-- Given a queued strike succeeding as its melee swing lands.
	Advance(4)
	local before = #outgoing
	Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, spell)

	-- When its two opaque physical reports share one spell confirmation.
	Event("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
	Event("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
	Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
	Advance(0.02)

	-- Then the real hit receives the spell instead of displaying its zero.
	local own = {}
	for index = before + 1, #outgoing do
		if outgoing[index].result.who == "you" then
			own[#own + 1] = outgoing[index]
		end
	end
	assert(#own == 1, "queued strike did not retain exactly one confirmed hit")
	assert(own[1].result.spell == spell, "queued strike lost its spell")
	assert(own[1].amount == opaqueDamage,
		"queued strike displayed the zero report instead of its real hit")
end

for _, example in ipairs({
	{ spell = 105, forever = true, hits = 2, lines = 1 },
	{ spell = 2973, forever = false, hits = 2, lines = 1 },
	{ spell = 2973, forever = true, hits = 1, lines = 1, expected = opaqueDamage },
	{ spell = 2973, forever = true, hits = 2, lines = 0 },
	{ spell = 2973, forever = true, hits = 3, lines = 1 },
	{ spell = 2973, forever = true, hits = 2, lines = 1,
		delay = 0.01 },
}) do
	-- Given a normal spell, another client, a lone hit, or no confirmation.
	Advance(4)
	local before = #outgoing
	MikSBT.Compatibility.Client.isForever = example.forever
	Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, example.spell)
	if example.delay then Advance(example.delay) end

	-- When ordinary matching handles those reports.
	for index = 1, example.hits - 1 do
		Event("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
	end
	Event("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
	for index = 1, example.lines do
		Event("COMBAT_LOG_MESSAGE", nil, "spell", 0, 0, 1)
	end
	Advance(0.02)
	Advance(0.5)

	-- Then a lone confirmed report survives; equal contested fits stay unknown.
	local own = {}
	for index = before + 1, #outgoing do
		if outgoing[index].result.who == "you" then
			own[#own + 1] = outgoing[index]
		end
	end
	assert(#own == (example.expected and 1 or 0),
		"queued strike rule changed ordinary confirmation behavior")
	if example.expected then
		assert(own[1].amount == example.expected,
			"queued strike rule changed an unrelated hit's event order")
	end
end
C_Spell.GetSpellDescription = descriptions
MikSBT.Compatibility = previousCompatibility
issecretvalue = previousSecretCheck

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

-- Given stable melee timing learned from three confirmed swings.
unsupported.PLAYER_SWING = nil
unsupported.COMBAT_LOG_MESSAGE = nil
unsupported.SPELL_TEXT_UPDATE = nil
petExists, targetIsPlayer = false, false
engine:Start()
Advance(1)
for index = 1, 3 do
	Event("PLAYER_SWING", 2, 0)
	Event("COMBAT_LOG_MESSAGE", nil, "swing")
	Advance(0.45)
	Event("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
	Advance(0.01)
	Advance(2)
end
assert(math.abs(ns.mine:SwingDelay("main") - 0.45) < 0.001)
outgoing = {}

-- When a teammate hits before the player's next confirmed swing lands.
Event("PLAYER_SWING", 2, 0)
Event("COMBAT_LOG_MESSAGE", nil, "swing")
Advance(0.30)
Event("UNIT_COMBAT", "target", "WOUND", "", 999, 1)
Advance(0.01)
Advance(0.14)
Event("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
Advance(0.01)
Advance(0.7)

-- Then the teammate's hit cannot take the player's swing confirmation.
assert(#outgoing == 2)
assert(outgoing[1].amount == 999 and outgoing[1].result.who == "unknown",
	"an early teammate hit stole a stable swing's confirmation")
assert(outgoing[2].amount == 40 and outgoing[2].result.who == "you"
	and outgoing[2].result.melee,
	"the player's later melee hit lost its confirmation")
engine:Stop()
print("Adapted combat engine tests passed")
