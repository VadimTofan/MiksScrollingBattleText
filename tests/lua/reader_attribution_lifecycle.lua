MikSBT = { Components = {},
    Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
for _, file in ipairs({ "Context", "Helpers", "SpellCatalog", "Mine",
    "Spells", "Healing", "Reader" }) do
    dofile("Combat/" .. file .. ".lua")
end
local Log = dofile("Components/CombatLogFilter.lua")
local Engine = dofile("Components/CombatEngine.lua")
local ns = MikSBT.CombatEngine
local now, timers, records = 0, {}, {}
local target, focus, mouseover, names, visible, pet = nil, nil, nil, {}, {}, false
local opaque = setmetatable({}, { __mode = "k" })
local function Amount()
    local value = setmetatable({}, {
        __add = function() error("added an opaque amount") end,
        __lt = function() error("ordered an opaque amount") end,
        __le = function() error("compared an opaque amount") end,
        __tostring = function() error("read an opaque amount") end,
    })
    opaque[value] = true
    return value
end
issecretvalue = function(value) return opaque[value] == true end
GetTime = function() return now end
GetLocale = function() return "enUS" end
local function Unit(unit)
    if unit == "target" then return target end
    if unit == "focus" then return focus end
    if unit == "mouseover" then return mouseover end
    if unit == "pettarget" then return pet and target or nil end
    return unit
end
UnitExists = function(unit)
    unit = Unit(unit)
    return unit == "player" or (unit == "pet" and pet)
        or (unit ~= nil and visible[unit] == true)
end
UnitIsUnit = function(a, b)
    a, b = Unit(a), Unit(b)
    return a ~= nil and b ~= nil and a == b
end
UnitName = function(unit) return names[Unit(unit)] end
UnitGUID = function(unit) return unit == "player" and "Player-Test" end
UnitIsPlayer = function(unit) return unit == "player" end
UnitIsDead = function() return false end
UnitClass = function() return "Shaman", "SHAMAN" end
UnitHealthMax = function() return 1000 end
GetWeaponEnchantInfo = function() return true, 10000, 0, 283 end
Enum = { CombatLogMessageOrder = { Newest = 0, Oldest = 1 },
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
C_EventUtils = { IsEventValid = function() return true end }
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    NewTicker = function() return { Cancel = function() end } end,
}
CreateFrame = function() return {
    RegisterEvent = function() end, RegisterUnitEvent = function() end,
    UnregisterAllEvents = function() end, SetScript = function() end,
} end
C_Spell = {
    GetSpellDescription = function() return nil end,
    IsSpellHelpful = function() return false end,
    GetSpellTexture = function(id) return id end,
    GetSpellName = function(id) return "Spell " .. id end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
Blizzard_CombatLog_Filters = { filters = {} }
local log = Log:New({ getSaved = function() return Blizzard_CombatLog_Filters end,
    mineFlag = 1, petFlag = 2 })
assert(log:WriteSettings())
local engine = Engine:New({ log = log,
    getSaved = function() return nil end, setSaved = function() end,
    notify = function() end, presentation = {
        Out = function(_, record) records[#records + 1] = record end,
        In = function() end, Alert = function() end, Aura = function() end,
        Healer = function() end, Resource = function() end,
        ComboPoints = function() end,
    } })
local function Event(event, ...) engine:HandleEvent(event, ...) end
local function At(time)
    while true do
        local first
        for index, timer in ipairs(timers) do
            if timer.at <= time and
                (not first or timer.at < timers[first].at) then first = index end
        end
        if not first then break end
        local timer = table.remove(timers, first)
        now = timer.at
        timer.callback()
    end
    now = time
end
local function Line(kind)
    local event = ({ swing = "SWING_DAMAGE", spell = "SPELL_DAMAGE",
        tick = "SPELL_PERIODIC_DAMAGE" })[kind]
    local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[event]
    Event("COMBAT_LOG_MESSAGE", "opaque native text", rgb.r, rgb.g, rgb.b,
        Enum.CombatLogMessageOrder.Newest)
end
local function Start()
    if engine.active then engine:Stop() end
    now, timers, records = now + 10, {}, {}
    target, focus, mouseover, pet = "nameplate1", nil, nil, false
    visible = { nameplate1 = true, nameplate2 = true }
    names = { nameplate1 = "Creature A", nameplate2 = "Creature B" }
    engine:Start()
    Event("PLAYER_ENTERING_WORLD")
    Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Event("NAME_PLATE_UNIT_ADDED", "nameplate2")
    return now
end
local function Result(amount)
    local found
    for _, record in ipairs(records) do
        if record.amount == amount then
            assert(not found, "report was decided twice")
            found = record.result
        end
    end
    assert(found, "report was never decided")
    return found
end
local failures = {}
local function Replay(name, callback)
    local ok, failure = pcall(callback)
    if not ok then failures[#failures + 1] = name .. ": " .. failure end
end

Replay("reused plate cannot borrow a previous creature's proc evidence", function()
    -- Given a real native swing and spare direct confirmation on creature A.
    local start = Start()
    Event("PLAYER_SWING", 3.8, Enum.PlayerSwingType.MainHand)
    Line("swing")
    Line("spell")
    assert(#ns.reader.swingTimes == 1, "native swing fixture is inactive")

    -- When a new creature takes A's nameplate token before a later report.
    At(start + 0.05)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    visible.nameplate1 = nil
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    At(start + 0.1)
    visible.nameplate1 = true
    Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local amount = Amount()
    At(start + 0.7)
    Event("UNIT_COMBAT", "nameplate1", "WOUND", "", amount, 1)
    At(start + 2)

    -- Then the new creature's hit stays unresolved.
    local result = Result(amount)
    assert(result.who ~= "you" and result.who ~= "pet",
        "new creature inherited an old confirmation")
end)

Replay("confirmed periodic report survives missing spell identity", function()
    -- Given a single own periodic line without a recorded cast.
    local start = Start()
    local amount = Amount()
    At(start + 0.5)
    Line("tick")

    -- When its sole same-frame report arrives.
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, 32)
    At(start + 1)

    -- Then ownership and periodic type survive without inventing a spell.
    local result = Result(amount)
    assert(result.who == "you" and result.tick and result.spell == nil,
        "missing spell identity erased a confirmed periodic report")
end)

Replay("orphan swing confirmation stays with its observed target lifetime", function()
    -- Given an extra-attack or pet line while creature A is selected.
    local start = Start()
    Line("swing")

    -- When another creature becomes the target before its unrelated report.
    At(start + 0.1)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    local amount = Amount()
    At(start + 0.6)
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, 1)
    At(start + 1)

    -- Then the delayed line cannot establish ownership on the new target.
    assert(Result(amount).who == "unknown",
        "orphan swing line moved to an unrelated target")
end)

Replay("offscreen tick cannot supply another creature's amount", function()
    -- Given Rend on A, followed by selecting B and losing A's plate.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
    At(start + 0.1)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    visible.nameplate1 = nil
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")

    -- When A's tick line arrives beside an unrelated report on B.
    local amount = Amount()
    At(start + 3)
    Line("tick")
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, 1)
    At(start + 3.2)

    -- Then the line cannot establish ownership of B's amount.
    assert(Result(amount).who == "unknown",
        "offscreen tick borrowed another creature's amount")
end)

Replay("one periodic line does not choose between two unknown reports", function()
    -- Given one own line and two indistinguishable reports.
    local start = Start()
    local first, second = Amount(), Amount()
    At(start + 0.5)
    Line("tick")

    -- When the reports compete for that single confirmation.
    Event("UNIT_COMBAT", "target", "WOUND", "", first, 32)
    Event("UNIT_COMBAT", "target", "WOUND", "", second, 32)
    At(start + 1)

    -- Then neither amount is arbitrarily selected as outgoing.
    assert(Result(first).who == "unknown" and Result(second).who == "unknown")
end)

Replay("cast keeps the recipient observed at SENT across a target switch", function()
    -- Given a cast sent to A with a readable cast identity and recipient.
    local start = Start()
    local firstKey = ns.TargetKey()
    Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "cast-one", 172)

    -- When the target changes before the cast succeeds.
    At(start + 1)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-one", 172)

    -- Then the cast still belongs to A's lifetime.
    assert(ns.mine.casts[172][1].key == firstKey,
        "cast inherited the target selected at success")
end)

Replay("focus recipient overrides the unrelated current target", function()
    -- Given a focus cast to B while A remains selected.
    local start = Start()
    focus = "nameplate2"
    local currentKey = ns.TargetKey()

    -- When the readable SENT recipient is confirmed by the same cast GUID.
    Event("UNIT_SPELLCAST_SENT", "player", "Creature B", "cast-focus", 172)
    At(start + 0.1)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-focus", 172)

    -- Then the spell is never bound to the unrelated current target.
    assert(ns.mine.casts[172][1].key ~= currentKey,
        "focus cast was bound to the current target")
end)

Replay("duplicate recipient names do not establish a unique target", function()
    -- Given two distinct visible creatures with the same public name.
    local start = Start()
    names.nameplate1, names.nameplate2 = "Creature", "Creature"

    -- When a named cast cannot identify which creature received it.
    Event("UNIT_SPELLCAST_SENT", "player", "Creature", "cast-ambiguous", 172)
    At(start + 0.1)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-ambiguous", 172)

    -- Then the cast explicitly retains the recipient uncertainty.
    local cast = ns.mine.casts[172][1]
    assert(cast.targetUncertain and cast.key == nil,
        "duplicate names established a false cast target")
end)

Replay("same-name unplated focus keeps the recipient ambiguous", function()
    -- Given a selected creature and a distinct unplated focus of the same name.
    local start = Start()
    focus = "focus-creature"
    visible[focus], names[focus] = true, names.nameplate1

    -- When a named cast could have targeted either unit.
    Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-focus", 172)
    At(start + 0.1)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-focus", 172)

    -- Then the unplated alternative still prevents a false recipient claim.
    local cast = ns.mine.casts[172][1]
    assert(cast.targetUncertain and cast.key == nil,
        "same-name unplated focus trusted the selected creature")
end)

Replay("a same-creature plate return rekeys hits already waiting for a line", function()
    -- Given Rend on a selected creature whose plate temporarily disappears.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    local amount = Amount()
    At(start + 3)
    Line("tick")
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, 1)

    -- When the same creature's plate returns during the periodic settle timer.
    At(start + 3.01)
    Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    At(start + 3.3)

    -- Then both the pending report and its spell retain the same lifetime.
    local result = Result(amount)
    assert(result.who == "you" and result.spell == 772,
        "waiting hit did not follow its creature's returning plate")
end)

Replay("a new channel GUID does not borrow a previous cast recipient", function()
    -- Given an observed cast to A followed by selecting B.
    local start = Start()
    Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "cast-old", 689)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-old", 689)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    local secondKey = ns.TargetKey()

    -- When a distinct public channel identity begins without SENT metadata.
    Event("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-new", 689)

    -- Then legacy fallback uses the new context, never the different GUID.
    assert(ns.mine.channels.you.key == secondKey,
        "new channel inherited a different cast's recipient")
end)

for _, losesPlate in ipairs({ false, true }) do
    Replay("another target's channel cannot supply a report's amount " ..
        tostring(losesPlate), function()
        -- Given Drain Life on A, followed by selecting another creature B.
        local start = Start()
        Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "channel-one", 689)
        Event("UNIT_SPELLCAST_CHANNEL_START", "player", "channel-one", 689)
        At(start + 0.1)
        target = "nameplate2"
        Event("PLAYER_TARGET_CHANGED")
        if losesPlate then
            visible.nameplate1 = nil
            Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
        end

        -- When A's channel line coincides with an unrelated report on B.
        local amount = Amount()
        At(start + 1)
        Line("tick")
        Event("UNIT_COMBAT", "target", "WOUND", "", amount, 32)
        At(start + 1.3)

        -- Then the typed line cannot establish ownership of B's amount.
        assert(Result(amount).who == "unknown",
            "another target's channel supplied a report's ownership")
    end)
end

Replay("another target's channel competes even with a known local tick", function()
    -- Given a channel on A and a known same-school periodic spell on B.
    local start = Start()
    Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "channel-one", 689)
    Event("UNIT_SPELLCAST_CHANNEL_START", "player", "channel-one", 689)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)

    -- When a single periodic line cannot establish which target produced it.
    local amount = Amount()
    At(start + 3)
    Line("tick")
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, 32)
    At(start + 3.3)

    -- Then local spell timing does not remove the other target's ownership risk.
    assert(Result(amount).who == "unknown",
        "a known local tick borrowed another target's channel line")
end)

Replay("two represented target lifetimes keep their simultaneous ticks", function()
    -- Given the same periodic spell on two distinct visible creatures.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    At(start + 3)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    local firstTick = Amount()
    Line("tick")
    Event("UNIT_COMBAT", "nameplate1", "WOUND", "", firstTick, 32)
    At(start + 3.3)

    -- When both target reports and both confirmations arrive on the shared beat.
    local first, second = Amount(), Amount()
    At(start + 6)
    Line("tick")
    Line("tick")
    Event("UNIT_COMBAT", "nameplate1", "WOUND", "", first, 32)
    Event("UNIT_COMBAT", "target", "WOUND", "", second, 32)
    At(start + 6.3)

    -- Then represented targets do not incorrectly block one another.
    assert(Result(first).who == "you" and Result(second).who == "you",
        "represented simultaneous ticks blocked each other")
    assert(Result(first).spell == 172 and Result(second).spell == 172)
end)

Replay("one line cannot choose between a channel and another target's tick", function()
    -- Given a channel on A and a same-school DoT on B.
    local start = Start()
    Event("UNIT_SPELLCAST_SENT", "player", "Creature A", "channel-one", 689)
    Event("UNIT_SPELLCAST_CHANNEL_START", "player", "channel-one", 689)
    target = "nameplate2"
    Event("PLAYER_TARGET_CHANGED")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)

    -- When both reports arrive but only one own confirmation exists.
    local first, second = Amount(), Amount()
    At(start + 3)
    Line("tick")
    Event("UNIT_COMBAT", "target", "WOUND", "", first, 32)
    Event("UNIT_COMBAT", "nameplate1", "WOUND", "", second, 32)
    At(start + 3.3)

    -- Then neither amount wins ownership merely by fitting an own effect.
    assert(Result(first).who == "unknown" and Result(second).who == "unknown",
        "one confirmation was arbitrarily allocated across target reports")
end)

for _, periodic in ipairs({ false, true }) do
    Replay("one confirmation cannot choose between equal fitting reports " ..
        tostring(periodic), function()
        -- Given one known spell that fits two opaque reports equally well.
        local start = Start()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, periodic and 172 or 133)
        local first, second = Amount(), Amount()
        At(start + (periodic and 3 or 0.3))
        Line(periodic and "tick" or "spell")

        -- When only one confirmation exists for those same-frame reports.
        Event("UNIT_COMBAT", "target", "WOUND", "", first, periodic and 32 or 4)
        Event("UNIT_COMBAT", "target", "WOUND", "", second, periodic and 32 or 4)
        At(start + 4)

        -- Then neither opaque amount is chosen solely by arrival order.
        assert(Result(first).who == "unknown" and Result(second).who == "unknown",
            "equal report fits established arbitrary ownership")
    end)
end

Replay("a rejected periodic ownership tie cannot lend its line later", function()
    -- Given one periodic line that cannot choose between two equal reports.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    At(start + 3)
    Line("tick")
    Event("UNIT_COMBAT", "target", "WOUND", "", Amount(), 32)
    Event("UNIT_COMBAT", "target", "WOUND", "", Amount(), 32)
    At(start + 3.13)

    -- When another report follows without a new own confirmation.
    local later = Amount()
    Event("UNIT_COMBAT", "target", "WOUND", "", later, 32)
    At(start + 3.5)

    -- Then the rejected line cannot be reused to claim that later amount.
    assert(Result(later).who == "unknown", "rejected tie lent its line later")
end)

Replay("fully confirmed mixed damage keeps both numbers without guessed roles", function()
    -- Given a periodic and a direct Shadow spell whose opaque reports tie.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    At(start + 2.9)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 686)

    -- When both reports have own lines, but the lines' kinds cannot be assigned.
    local first, second = Amount(), Amount()
    At(start + 3)
    Line("tick")
    Line("spell")
    Event("UNIT_COMBAT", "target", "WOUND", "", first, 32)
    Event("UNIT_COMBAT", "target", "WOUND", "", second, 32)
    At(start + 3.5)

    -- Then both confirmed amounts remain owned with no invented spell identity.
    assert(Result(first).who == "you" and Result(second).who == "you",
        "mixed identity ambiguity discarded confirmed amounts")
    assert(Result(first).spell == nil and Result(second).spell == nil,
        "opaque mixed reports received guessed identities")
end)

-- A cast sent to a name two creatures in view carry, nameplate1 the target.
local function SharedNameCast(spell, guid)
    names.nameplate1, names.nameplate2 = "Creature", "Creature"
    Event("UNIT_SPELLCAST_SENT", "player", "Creature", guid, spell)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spell)
end
-- A report on unit with a line of yours of its kind in the same frame.
local function OwnReport(unit, kind, school)
    local amount = Amount()
    Line(kind or "spell")
    Event("UNIT_COMBAT", unit, "WOUND", "", amount, school or 1)
    return amount
end
-- A line of yours for an event Line does not cover.
local function EventLine(event)
    local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[event]
    Event("COMBAT_LOG_MESSAGE", "opaque native text", rgb.r, rgb.g, rgb.b,
        Enum.CombatLogMessageOrder.Newest)
end
local function Unplaced(spell)
    local cast = ns.mine.casts[spell][1]
    return cast.targetUncertain and cast.key == nil
end

Replay("a strike's own report settles a name two creatures share", function()
    -- Given Rake sent to a name the target and another creature carry.
    local start = Start()
    SharedNameCast(1822, "cast-shared")

    -- When its hit lands on the target in the cast's own frame.
    local hit = OwnReport("target")
    At(start + 3)
    local tick = OwnReport("target", "tick")
    At(start + 3.3)

    -- Then the hit and the bleed's later tick are both named after Rake.
    assert(Result(hit).who == "you" and Result(hit).spell == 1822,
        "the strike's own report did not settle its recipient")
    assert(Result(tick).spell == 1822 and Result(tick).tick,
        "the settled bleed's tick was not named")
end)

Replay("a mouseover strike is settled on the creature its report lands on", function()
    -- Given Rake sent by mouseover to the second creature of a shared name.
    local start = Start()
    mouseover = "nameplate2"
    SharedNameCast(1822, "cast-mouseover")

    -- When its hit and later tick land on that creature.
    local hit = OwnReport("nameplate2")
    At(start + 3)
    local tick = OwnReport("nameplate2", "tick")
    At(start + 3.3)

    -- Then Rake follows that creature, not the selected one.
    local key = ns.mine.casts[1822][1].key
    assert(key and key ~= ns.TargetKey(),
        "the strike was not settled on the creature its report landed on")
    assert(Result(hit).spell == 1822 and Result(tick).spell == 1822,
        "the mouseover strike's hit or tick was not named")
end)

Replay("a strike's own miss settles a name two creatures share", function()
    -- Given Claw sent to a name two creatures in view carry.
    local start = Start()
    SharedNameCast(3029, "cast-dodged")

    -- When the target dodges it in the cast's own frame.
    EventLine("SPELL_MISSED")
    Event("UNIT_COMBAT", "target", "DODGE", "", nil, 1)
    At(start + 1)

    -- Then the miss is named after the strike.
    local result
    for _, record in ipairs(records) do
        if record.event == "miss" then result = record.result end
    end
    assert(result and result.missed and result.spell == 3029,
        "the strike's own miss did not settle its recipient")
end)

Replay("reports on both creatures of a shared name keep the strike unplaced", function()
    -- Given Claw sent to a name two creatures in view carry.
    local start = Start()
    SharedNameCast(3029, "cast-both")

    -- When reports of yours land on both creatures in the cast's frame.
    local first, second = OwnReport("target"), OwnReport("nameplate2")
    At(start + 1)

    -- Then neither report chooses the strike's recipient.
    assert(Unplaced(3029), "one of two reported creatures was chosen")
    assert(Result(first).spell == nil and Result(second).spell == nil,
        "a report was named after a strike without a recipient")
end)

Replay("an unplated same-name focus keeps a reported strike unplaced", function()
    -- Given the target and an unplated focus that carry one name.
    local start = Start()
    focus = "focus-creature"
    visible[focus], names[focus] = true, names.nameplate1

    -- When Claw's report lands on the target in its own frame.
    Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-focus", 3029)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-focus", 3029)
    local hit = OwnReport("target")
    At(start + 1)

    -- Then the focus, which no report can show, may still have taken it.
    assert(Unplaced(3029) and Result(hit).spell == nil,
        "a report ruled out an unplated creature of the same name")
end)

Replay("a hidden recipient name is not settled by a report", function()
    -- Given Claw whose recipient name cannot be read.
    local start = Start()
    names.nameplate1, names.nameplate2 = "Creature", "Creature"
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "cast-hidden", 3029)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-hidden", 3029)

    -- When its report lands on the target in its own frame.
    local hit = OwnReport("target")
    At(start + 1)

    -- Then nothing names the unit it was sent to.
    assert(Unplaced(3029) and Result(hit).spell == nil,
        "a hidden recipient name was settled")
end)

Replay("a cast paired without its GUID is not settled by a report", function()
    -- Given Claw sent to a shared name with no readable cast GUID.
    local start = Start()
    SharedNameCast(3029, nil)

    -- When its report lands on the target in its own frame.
    local hit = OwnReport("target")
    At(start + 1)

    -- Then the cast is not known to be the one sent to that name.
    assert(Unplaced(3029) and Result(hit).spell == nil,
        "a cast paired without its GUID was settled")
end)

Replay("a report after the cast's frame does not settle a shared name", function()
    -- Given Claw sent to a name two creatures in view carry.
    local start = Start()
    SharedNameCast(3029, "cast-late")

    -- When a report of yours lands on the target only after its frame.
    At(start + 0.05)
    local hit = OwnReport("target")
    At(start + 1)

    -- Then that report does not choose the strike's recipient.
    assert(Unplaced(3029) and Result(hit).spell == nil,
        "a report outside the cast's frame settled its recipient")
end)

Replay("a report without your line does not settle a shared name", function()
    -- Given Claw sent to a name two creatures in view carry.
    local start = Start()
    SharedNameCast(3029, "cast-unlined")

    -- When a report lands on the target with no line of yours.
    local hit = Amount()
    Event("UNIT_COMBAT", "target", "WOUND", "", hit, 1)
    At(start + 1)

    -- Then a report that is not yours chooses nothing.
    assert(Unplaced(3029) and Result(hit).who == "unknown",
        "another's report settled the strike's recipient")
end)

Replay("a tick in the cast's frame does not settle a shared name", function()
    -- Given Rend on the target, then a second creature of its name.
    local start = Start()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)

    -- When Claw's frame at the shared name holds only Rend's tick.
    At(start + 3)
    SharedNameCast(3029, "cast-tick")
    local tick = OwnReport("target", "tick")
    At(start + 3.3)

    -- Then the tick keeps its own spell and the strike stays unplaced.
    assert(Result(tick).spell == 772, "Rend's tick lost its spell")
    assert(Unplaced(3029), "a tick settled a strike's recipient")
end)

Replay("a heal in the cast's frame does not settle a shared name", function()
    -- Given Claw sent to a name two creatures in view carry.
    local start = Start()
    SharedNameCast(3029, "cast-heal")

    -- When the only report of its frame is a heal on the target.
    EventLine("SPELL_HEAL")
    Event("UNIT_COMBAT", "target", "HEAL", "", Amount(), 8)
    At(start + 1)

    -- Then a heal does not show where a strike landed.
    assert(Unplaced(3029), "a heal settled a strike's recipient")
end)

Replay("a report its spell cannot make does not settle a shared name", function()
    -- Given Claw, a physical strike, sent to a shared name.
    local start = Start()
    SharedNameCast(3029, "cast-school")

    -- When the only report of its frame is a Fire hit on the target.
    OwnReport("target", "spell", 4)
    At(start + 1)

    -- Then that report is not taken for the strike's.
    assert(Unplaced(3029), "a report of another school settled a strike")
end)

Replay("a flying spell is not settled by a report in its cast's frame", function()
    -- Given Fireball, whose missile flies, sent to a shared name.
    local start = Start()
    SharedNameCast(133, "cast-fireball")

    -- When a Fire report of yours lands on the target in its cast's frame.
    local hit = OwnReport("target", "spell", 4)
    At(start + 1)

    -- Then that report is not taken for the missile's.
    assert(Unplaced(133) and Result(hit).spell == nil,
        "a flying spell was settled by a report in its cast's frame")
end)

Replay("a report on a creature of another name does not settle a shared name", function()
    -- Given a third creature in view whose name differs.
    local start = Start()
    visible.nameplate3, names.nameplate3 = true, "Other"
    Event("NAME_PLATE_UNIT_ADDED", "nameplate3")
    SharedNameCast(3029, "cast-other")

    -- When the only report of the cast's frame lands on that creature.
    local hit = OwnReport("nameplate3")
    At(start + 1)

    -- Then a creature the name did not match is never chosen.
    assert(Unplaced(3029) and Result(hit).spell == nil,
        "a creature of another name was taken for the recipient")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Reader attribution lifecycle tests passed")
