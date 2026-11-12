-- Describe: a queued strike's zero report and swing are not shown as hits.
MikSBT = { Components = {}, Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
dofile("Combat/Healing.lua")
dofile("Combat/Reader.lua")
local Engine = dofile("Components/CombatEngine.lua")
local now, timers, outgoing = 10, {}, {}
local STRIKE, CLAW = 2973, 16827
local opaqueZero, opaqueDamage, opaqueClaw, opaqueSwing = {}, {}, {}, {}
issecretvalue = function(value)
    return value == opaqueZero or value == opaqueDamage or value == opaqueClaw
        or value == opaqueSwing
end
GetTime = function() return now end
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    NewTicker = function() return { Cancel = function() end } end,
}
C_EventUtils = { IsEventValid = function() return true end }
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetScript() end
    function frame:UnregisterAllEvents() end
    return frame
end
UnitExists = function(unit) return unit == "target" or unit == "pet" or unit == "pettarget" end
UnitIsUnit = function(a, b) return a == b or (a == "pettarget" and b == "target") end
UnitGUID = function(unit) return unit == "player" and "Player-1" or nil end
UnitName = function() return "Tester" end
UnitHealthMax = function() return 1000 end
GetLocale = function() return "enUS" end
Enum = {
    CombatLogMessageOrder = { Oldest = 0, Newest = 1 },
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
}
C_Spell = {
    GetSpellDescription = function(id)
        if id == STRIKE then return "A strong attack that increases melee damage by 5." end
        if id == CLAW then return "Claw the enemy, causing 16 to 22 damage." end
        return ""
    end,
    IsSpellHelpful = function() return false end,
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
        In = function() end, Alert = function() end, Aura = function() end,
        Healer = function() end,
    },
})
local function Event(event, ...)
    if event == "COMBAT_LOG_MESSAGE" then
        local kind = ...
        local eventName = kind == "swing" and "SWING_DAMAGE" or "SPELL_DAMAGE"
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
local function Settle()
    Advance(0.02)
    Advance(0.5)
    Advance(2)
end
local function Shown(from)
    local you, pet = {}, {}
    for index = from + 1, #outgoing do
        local record = outgoing[index]
        if record.result.who == "you" then you[#you + 1] = record end
        if record.result.who == "pet" then pet[#pet + 1] = record end
    end
    return you, pet
end
engine:Start()
Event("PLAYER_ENTERING_WORLD")

-- Given combat log lines already arriving for the player and the pet.
Event("UNIT_SPELLCAST_SUCCEEDED", "pet", nil, CLAW)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueClaw, 1)
Event("COMBAT_LOG_MESSAGE", "spell")
Settle()

-- Given a queued strike with the player's pet attacking the same target.
Advance(4)
local before = #outgoing
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, STRIKE)
Event("PLAYER_SWING", 3.3, 0)

-- When its zero report and its hit share one spell confirmation.
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
Event("COMBAT_LOG_MESSAGE", "spell")
Settle()

-- Then the hit is the strike's and the zero report is not the pet's swing.
local you, pet = Shown(before)
assert(#you == 1 and you[1].result.spell == STRIKE and you[1].amount == opaqueDamage)
assert(#pet == 0, "the strike's zero report was shown as a pet swing")

-- Given a queued strike and the pet's Claw in one frame.
Advance(4)
before = #outgoing
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, STRIKE)
Event("PLAYER_SWING", 3.3, 0)
Event("UNIT_SPELLCAST_SUCCEEDED", "pet", nil, CLAW)

-- When three reports come with two spell confirmations.
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueClaw, 1)
Event("COMBAT_LOG_MESSAGE", "spell")
Event("COMBAT_LOG_MESSAGE", "spell")
Settle()

-- Then the zero report is neither shown nor turned into a pet swing. (Which
-- of the two real hits is the strike's is decided by the casts' own frames.)
for index = before + 1, #outgoing do
    local record = outgoing[index]
    assert(record.amount ~= opaqueZero, "the zero report was shown")
    assert(not (record.result.who == "pet" and record.result.melee),
        "the strike's zero report was shown as a pet swing beside its Claw")
end

-- Given the pet's swing line, then a queued strike whose swing event comes
-- in its cast's frame.
Advance(4)
before = #outgoing
Event("COMBAT_LOG_MESSAGE", "swing")
Advance(0.2)
Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, STRIKE)
Event("PLAYER_SWING", 3.3, 0)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
Event("COMBAT_LOG_MESSAGE", "spell")
Advance(0.02)

-- When the pet's blow is reported inside what would be that swing's window.
Advance(0.43)
Event("UNIT_COMBAT", "target", "WOUND", "", opaqueSwing, 1)
Settle()

-- Then the strike's swing does not take it as the player's Auto Attack.
you, pet = Shown(before)
assert(#you == 1 and you[1].result.spell == STRIKE,
    "the strike's swing took the pet's blow as the player's Auto Attack")
assert(#pet == 1 and pet[1].result.melee and pet[1].amount == opaqueSwing)
