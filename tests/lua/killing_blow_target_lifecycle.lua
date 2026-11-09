MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
dofile("Combat/Healing.lua")
dofile("Combat/Reader.lua")
local Batcher = dofile("Components/OutgoingBatcher.lua")
local Presentation = dofile("Components/CombatPresentation.lua")

local ns = MikSBT.CombatEngine
local now, timers, outgoing, displayed = 10, {}, {}, {}
local profile = { events = {
    OUTGOING_SPELL_DAMAGE = {}, PET_OUTGOING_SPELL_DAMAGE = {},
} }
local targetExists, petExists = true, false
GetTime = function() return now end
UnitExists = function(unit)
    return (unit == "target" and targetExists) or (unit == "pet" and petExists)
end
UnitIsUnit = function(a, b)
    return a == b or (targetExists and a == "nameplate1" and b == "target")
        or (petExists and targetExists and a == "pettarget" and b == "target")
end
C_Spell = {
    GetSpellDescription = function() return "Deals 100 Fire damage." end,
    GetSpellTexture = function() return 123 end,
    IsSpellHelpful = function() return false end,
}
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { at = now + delay, callback = callback }
end }
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        RegisterUnitEvent = function() end,
        SetScript = function() end,
        UnregisterAllEvents = function() end,
    }
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
local function Event(event, ...) ns.ReaderEvent(nil, event, ...) end
local function Start()
    ns.active, ns.generation = true, ns.generation + 1
    ns.learned = ns.LoadLearned(nil)
    ns.StartReader()
    targetExists, outgoing, timers, displayed = true, {}, {}, {}
    local batcher = Batcher:New({
        getProfile = function() return profile end,
        getSpellTexture = function() return 123 end,
        isAutoAttack = function() return false end,
        after = C_Timer.After,
        delay = 0.2,
        formatEventMessage = function(_, amount) return tostring(amount) end,
        display = function(_, message)
            displayed[#displayed + 1] = message
        end,
    })
    local presentation = Presentation:New({
        batcher = batcher,
        getSpellTexture = function() return 123 end,
    })
    ns.liveRouter = {
        Out = function(_, record)
            outgoing[#outgoing + 1] = record
            presentation:Out(record)
        end,
        Alert = function() end,
    }
end
local function OwnHits(owner)
    local count = 0
    for _, record in ipairs(outgoing) do
        if record.result.who == (owner or "you") then
            count = count + 1
            assert(record.result.spell == 101 and record.amount == 100)
        end
    end
    return count
end

-- Describe: late damage survives loss of its target in either event order.
for _, caster in ipairs({ "player", "pet" }) do
    for _, order in ipairs({ "no-change-event", "plate-first", "target-first",
        "without-plate", "late-plate", "loss-before-plate" }) do
        -- Given a cast made at the dying target.
        Start()
        petExists = caster == "pet"
        if order ~= "without-plate" and order ~= "late-plate" then
            Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
        end
        Event("UNIT_SPELLCAST_SUCCEEDED", caster, nil, 101)
        if order == "late-plate" then
            Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
        end

        -- When the target goes before its final damage report.
        targetExists = false
        if order == "loss-before-plate" then
            assert(ns.TargetKey() == nil)
        end
        if order == "plate-first" or order == "loss-before-plate" then
            Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        end
        if order ~= "no-change-event" then Event("PLAYER_TARGET_CHANGED") end
        if order == "target-first" or order == "late-plate" then
            Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        end
        Event("PLAYER_REGEN_ENABLED")
        Advance(0.1)
        Event("UNIT_COMBAT", "target", "WOUND", "", 100, 4)
        Event("UNIT_COMBAT", "nameplate1", "WOUND", "", 100, 4)
        assert(#displayed == 0, "damage bypassed the batching delay")
        Advance(0.6)

        -- Then its damage retains its owner and spell exactly once.
        local owner = caster == "pet" and "pet" or "you"
        assert(OwnHits(owner) == 1,
            "killing hit disappeared: " .. caster .. "/" .. order)
        assert(#displayed == 1 and displayed[1] == "100",
            "killing damage was dropped or duplicated during batching")
        assert(ns.TargetKey() == nil, "new casts inherited a departed target")
    end
end
petExists = false

-- Describe: a departed key cannot become a permanent or new target.
for _, scenario in ipairs({ "expired", "retargeted", "restarted" }) do
    -- Given a pending cast whose target disappeared.
    Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 101)
    targetExists = false
    Event("PLAYER_TARGET_CHANGED")

    -- When the grace expires, another target is selected, or we restart.
    if scenario == "expired" then
        Advance(0.6)
    elseif scenario == "retargeted" then
        targetExists = true
        Event("PLAYER_TARGET_CHANGED")
        targetExists = false
        Event("PLAYER_TARGET_CHANGED")
    else
        ns.StopReader()
        ns.StartReader()
    end
    Event("UNIT_COMBAT", "target", "WOUND", "", 100, 4)
    Advance(1)

    -- Then a late report never inherits the old cast's ownership.
    assert(OwnHits() == 0, "stale target reused: " .. scenario)
    assert(#displayed == 0, "stale target produced damage text")
end
print("Killing-blow target lifecycle tests passed")
