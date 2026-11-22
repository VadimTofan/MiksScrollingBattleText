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
local now, timers, records, alerts = 0, {}, {}, {}
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
-- A unit's name is a text, or a table of the two names the client gives for it.
UnitName = function(unit)
    local name = names[Unit(unit)]
    if type(name) == "table" then return name[1], name[2] end
    return name
end
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
        In = function() end, Alert = function(_, record) alerts[#alerts + 1] = record end,
        Aura = function() end,
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
        tick = "SPELL_PERIODIC_DAMAGE", interrupt = "SPELL_INTERRUPT" })[kind]
    local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[event]
    Event("COMBAT_LOG_MESSAGE", "opaque native text", rgb.r, rgb.g, rgb.b,
        Enum.CombatLogMessageOrder.Newest)
end
local function Start()
    if engine.active then engine:Stop() end
    now, timers, records, alerts = now + 10, {}, {}, {}
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

-- A swing's hit is reported a while after the swing and its line. Once a delay is learned, a hit that
-- comes at neither of its times found no swing; while nobody fights beside you it still does.
local function Company(state, callback)
    local group, raid = IsInGroup, IsInRaid
    IsInGroup = state ~= "unknown" and function() return state == "party" end or nil
    IsInRaid = function() return state == "raid" end
    local ok, failure = pcall(callback)
    IsInGroup, IsInRaid = group, raid
    assert(ok, failure)
end
local function Swing()
    Event("PLAYER_SWING", 1, Enum.PlayerSwingType.MainHand)
    Line("swing")
end
local function Report(school)
    local amount = Amount()
    Event("UNIT_COMBAT", "target", "WOUND", "", amount, school or 1)
    return amount
end
-- Three swings whose hits come 0.76 s after them: that delay is learned. Returns the time after them.
local function LearnedDelay()
    local start = Start()
    for index = 0, 2 do
        At(start + index)
        Swing()
        At(start + index + 0.76)
        Report()
    end
    At(start + 3)
    assert(math.abs(ns.mine:SwingDelay("main") - 0.76) < 0.001, "the swing delay was not learned")
    return start + 3
end
-- A swing and its hit that long after it; who the hit is taken for.
local function SwingHit(at, late)
    At(at)
    Swing()
    At(at + late)
    local amount = Report()
    At(math.max(at + 1.9, at + late + 0.5))
    return Result(amount)
end

Replay("a swing's hit outside its learned times is its swing's while you fight alone", function()
    for _, late in ipairs({ 0.1, 0.43, 1, 1.8 }) do
        for _, state in ipairs({ "alone", "party", "raid", "unknown" }) do
            Company(state, function()
                -- Given a learned delay of 0.76 s: the hit's times are 0.66 to 0.91 s and 1.01 to 1.66 s.
                local start = LearnedDelay()

                -- When a swing's hit comes before the first time, between the two, or outside both.
                local result = SwingHit(start, late)

                -- Then from 0.25 s to the end of the second time it is that swing's while you are alone;
                -- sooner, later or beside others it is someone else's.
                local own = state == "alone" and (late == 0.43 or late == 1)
                assert(result.who == (own and "you" or "unknown") and (result.melee == true) == own,
                    ("a swing's hit %.2f s after it, %s, came out as %s"):format(late, state, result.who))
            end)
        end
    end
end)

Replay("normal swing reports outrank an earlier tentative report", function()
    for _, delay in ipairs({ 0.76, 1.1 }) do
        Company("alone", function()
            -- Given a learned swing delay and an actual native swing.
            local start = LearnedDelay()
            Swing()

            -- When an unrelated report precedes the actual swing report.
            At(start + 0.43)
            local unrelated = Report()
            At(start + delay)
            local own = Report()
            At(start + 2)

            -- Then the real report keeps the native swing's confirmation.
            assert(Result(unrelated).who == "unknown", "early report stole the swing")
            assert(Result(own).who == "you" and Result(own).melee, "normal swing went unshown")
        end)
    end
end)

Replay("a tentative periodic tie cannot reserve a later confirmed swing", function()
    Company("alone", function()
        -- Given a due Rend tick and an outstanding swing.
        local start = LearnedDelay()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
        At(start + 2)
        Swing()

        -- When the tie arrives first and the real swing follows in its delayed window.
        At(start + 3)
        Line("tick")
        local first, second = Report(), Report()
        At(start + 3.3)
        local own = Report()
        At(start + 4)

        -- Then the actual swing keeps its confirmation and the tie stays unresolved.
        assert(Result(own).who == "you" and Result(own).melee, "periodic tie took the real swing")
        assert(Result(first).who == "unknown" and Result(second).who == "unknown")
    end)
end)

Replay("a periodic tie counts all available tick lines", function()
    Company("alone", function()
        -- Given a due Rend tick and an outstanding swing.
        local start = LearnedDelay()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
        At(start + 2)
        Swing()

        -- When three same-frame reports tie for two periodic confirmations.
        At(start + 3)
        Line("tick")
        Line("tick")
        local first, second, third = Report(), Report(), Report()
        At(start + 4)

        -- Then the two lines and the swing cover three plain amounts.
        for _, amount in ipairs({ first, second, third }) do
            local result = Result(amount)
            assert(result.who == "you" and not result.spell and not result.melee,
                "a periodic line was left unused")
        end
    end)
end)

Replay("a miss of a swing outside its learned times is shown while you fight alone", function()
    Company("alone", function()
        -- Given a learned delay and a swing that is parried.
        local start = LearnedDelay()
        local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring.SWING_MISSED
        Event("PLAYER_SWING", 1, Enum.PlayerSwingType.MainHand)
        Event("COMBAT_LOG_MESSAGE", "opaque native text", rgb.r, rgb.g, rgb.b, Enum.CombatLogMessageOrder.Newest)

        -- When its report comes between the swing's two times.
        At(start + 1)
        Event("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
        At(start + 2)

        -- Then the parry is that swing's.
        local last = records[#records]
        assert(last.event == "miss" and last.result.who == "you" and last.result.melee and last.result.missed,
            "a late swing's parry came out as " .. tostring(last.result and last.result.who))
    end)
end)

Replay("someone else's strike on the unit ends the search for a late swing's hit for a while", function()
    for _, strike in ipairs({ "WOUND", "PARRY" }) do
        Company("alone", function()
            -- Given a strike on the unit that no line and no swing of yours answers.
            local start = LearnedDelay()
            Event("UNIT_COMBAT", "target", strike, "", strike == "WOUND" and Amount() or 0, 1)

            -- When swings' hits come before their time, 4 s after it and 5.5 s after that one.
            local soon = SwingHit(start + 3.57, 0.43).who
            local later = SwingHit(start + 9.07, 0.43).who

            -- Then the first is not taken for the swing's, and counts as someone else's itself; the next is.
            assert(soon == "unknown", "a late swing's hit was looked for 4 s after someone else's " .. strike)
            assert(later == "you", "a late swing's hit was not looked for 5.5 s after the last unplaced hit")
        end)
    end
end)

Replay("a heal on the unit does not end the search for a late swing's hit", function()
    Company("alone", function()
        -- Given a heal on the unit, which is nobody's strike.
        local start = LearnedDelay()
        Event("UNIT_COMBAT", "target", "HEAL", "", Amount(), 2)

        -- When a swing's hit comes before its time.
        local result = SwingHit(start + 0.1, 0.43)

        -- Then it is still that swing's.
        assert(result.who == "you", "a heal on the unit ended the search for a late swing's hit")
    end)
end)

Replay("strikes of others are forgotten once they no longer count", function()
    -- Given someone else's strike on another unit.
    local start = Start()
    Event("UNIT_COMBAT", "nameplate2", "WOUND", "", Amount(), 1)

    -- When another one comes on the target after the quiet time.
    At(start + 6)
    Event("UNIT_COMBAT", "target", "WOUND", "", Amount(), 1)
    At(start + 7)

    -- Then only that one is kept.
    local kept = 0
    for _ in pairs(ns.reader.strangers) do kept = kept + 1 end
    assert(kept == 1, "strikes of others kept: " .. kept)
end)

Replay("someone else's strike stays with the unit when its name plate comes", function()
    Company("alone", function()
        -- Given a target without a name plate that someone else strikes.
        local start = LearnedDelay()
        target = "nameplate3"
        visible.nameplate3, names.nameplate3 = true, "Creature C"
        Event("PLAYER_TARGET_CHANGED")
        Report()
        At(start + 0.2)

        -- When its plate comes, and a swing's hit comes before its time.
        Event("NAME_PLATE_UNIT_ADDED", "nameplate3")
        local result = SwingHit(start + 0.4, 0.43)

        -- Then the strike still counts for the unit.
        assert(result.who == "unknown", "someone else's strike was lost with the unit's old key")
    end)
end)

Replay("a late swing's hit teaches no delay", function()
    -- Given a learned delay, and a swing's hit that came before its time while you were alone.
    local start
    Company("alone", function()
        start = LearnedDelay()
        assert(SwingHit(start, 0.43).who == "you", "the late swing's hit was not taken")
    end)

    -- When you then fight in a party and a swing's hit comes that early again.
    Company("party", function()
        local result = SwingHit(start + 3, 0.43)

        -- Then the swing's time is as it was learned: the hit is someone else's.
        assert(result.who == "unknown", "a late swing's hit widened the swing's time")
    end)
end)

Replay("a pet at something ends the search for a late swing's hit", function()
    Company("alone", function()
        -- Given a learned delay and your pet attacking.
        local start = LearnedDelay()
        pet = true

        -- When a swing's hit comes before its time.
        local result = SwingHit(start, 0.43)

        -- Then it may be the pet's or anyone's: it stays unplaced.
        assert(result.who == "unknown", "a late swing's hit was looked for beside a pet")
    end)
end)

Replay("an extra attack's line takes its hit before a late swing is looked for", function()
    Company("alone", function()
        -- Given a swing whose hit is still out, and a swing line with no swing of yours in its frame.
        local start = LearnedDelay()
        Swing()
        At(start + 0.3)
        Line("swing")

        -- When a hit comes 0.7 s after that line, a second after the swing.
        At(start + 1)
        local amount = Report()
        At(start + 2)

        -- Then it is the extra attack's, as before.
        local result = Result(amount)
        assert(result.who == "you" and result.extra == true, "an extra attack's hit went to a late swing")
    end)
end)

-- What a hit came out as.
local function Outcome(result)
    return result.who .. (result.spell and " with a spell" or "") .. (result.melee and " as a swing" or "")
end

Replay("a strike's own line takes its hit before a late swing is looked for", function()
    Company("alone", function()
        -- Given a swing whose hit is still out, and a strike cast after it whose line has come.
        local start = LearnedDelay()
        Swing()
        At(start + 0.2)
        Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-strike", 999002)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-strike", 999002)
        Line("spell")

        -- When the strike's hit is reported 0.3 s after its line, and the swing's hit in its own time.
        At(start + 0.5)
        local strike = Report()
        At(start + 0.77)
        local swing = Report()
        At(start + 2)

        -- Then each is what it is.
        assert(Outcome(Result(strike)) == "you with a spell",
            "a strike's late hit came out as " .. Outcome(Result(strike)))
        assert(Outcome(Result(swing)) == "you as a swing",
            "the swing's own hit came out as " .. Outcome(Result(swing)))
    end)
end)

Replay("a late swing's hit is found while a bolt of yours is in flight", function()
    Company("alone", function()
        -- Given a swing whose hit is held back, and a bolt cast after it.
        local start = LearnedDelay()
        Swing()
        At(start + 0.6)
        Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-bolt", 999003)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-bolt", 999003)

        -- When the swing's hit comes between the swing's two times, and the bolt lands after it.
        At(start + 1)
        local swing = Report()
        At(start + 1.5)
        Line("spell")
        local bolt = Report()
        At(start + 3)

        -- Then the first is the swing's and the second the bolt's.
        assert(Outcome(Result(swing)) == "you as a swing",
            "a late swing's hit before a bolt came out as " .. Outcome(Result(swing)))
        assert(Outcome(Result(bolt)) == "you with a spell", "the bolt came out as " .. Outcome(Result(bolt)))
    end)
end)

Replay("a separately confirmed proc can coexist with a tentative swing", function()
    Company("alone", function()
        -- Given a swing whose hit came before the swing's time.
        local start = LearnedDelay()
        Swing()
        At(start + 0.43)
        local swing = Report()

        -- When a proc's line follows, and the proc's hit comes after the swing's hit.
        At(start + 0.46)
        Line("spell")
        At(start + 0.65)
        local proc = Report()
        At(start + 2)

        -- Then the proc is yours, as after a swing's hit in its time.
        assert(Outcome(Result(swing)) == "you as a swing" and Result(proc).who == "you",
            "a late swing's hit and the proc after it came out as " .. Outcome(Result(swing)) .. " and "
                .. Outcome(Result(proc)))
    end)
end)

Replay("a spell's hit and a late swing's hit in one frame are both yours, unnamed", function()
    for _, state in ipairs({ "alone", "party" }) do
        Company(state, function()
            -- Given a swing whose hit is held back a second.
            local start = LearnedDelay()
            Swing()

            -- When it comes with the next swing and with the hit of a spell cast on that swing.
            At(start + 1)
            Swing()
            Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-tie", 133)
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-tie", 133)
            Line("spell")
            local first, second = Report(), Report()
            At(start + 2)

            -- Then both are yours and neither is named; beside others both stay someone else's.
            for _, amount in ipairs({ first, second }) do
                assert(Outcome(Result(amount)) == (state == "alone" and "you" or "unknown"),
                    ("a hit that tied for the spell's line, %s, came out as %s"):format(state,
                        Outcome(Result(amount))))
            end
        end)
    end
end)

Replay("a tick and a late swing's hit in one frame are both yours, unnamed", function()
    for _, state in ipairs({ "alone", "party" }) do
        Company(state, function()
            -- Given Rend on the target and a swing whose hit is held back a second.
            local start = LearnedDelay()
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
            At(start + 2)
            Swing()

            -- When that hit comes in the frame of Rend's first tick.
            At(start + 3)
            Line("tick")
            local first, second = Report(), Report()
            At(start + 4)

            -- Then both are yours and neither is named; beside others both stay someone else's.
            for _, amount in ipairs({ first, second }) do
                assert(Outcome(Result(amount)) == (state == "alone" and "you" or "unknown"),
                    ("a hit that tied for the tick's line, %s, came out as %s"):format(state,
                        Outcome(Result(amount))))
            end
        end)
    end
end)

Replay("hits that tie for a tick's line are not taken for a swing's when no swing covers the rest", function()
    Company("alone", function()
        -- Given Rend on the target and one swing whose hit is held back.
        local start = LearnedDelay()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 772)
        At(start + 2)
        Swing()

        -- When three hits come in the frame of Rend's first tick.
        At(start + 3)
        Line("tick")
        local tied = { Report(), Report(), Report() }
        At(start + 4)

        -- Then the tick's line and one swing do not cover three hits, and none is taken for the swing's.
        for _, amount in ipairs(tied) do
            assert(not Result(amount).melee, "a hit that tied for the tick's line was taken for the swing's")
        end
    end)
end)

Replay("a hit the lines of its frame leave out is the late swing's", function()
    for _, state in ipairs({ "alone", "party" }) do
        Company(state, function()
            -- Given a swing whose hit is held back a second, and Fireball, a Fire spell.
            local start = LearnedDelay()
            Swing()

            -- When that hit comes in the frame of the spell's hit.
            At(start + 1)
            Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-fire", 133)
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fire", 133)
            Line("spell")
            local fire, physical = Report(4), Report()
            At(start + 2)

            -- Then the spell's hit keeps its name, and the other is the swing's while you are alone.
            assert(Result(fire).spell == 133, "the spell's hit lost its name")
            assert(Outcome(Result(physical)) == (state == "alone" and "you as a swing" or "unknown"),
                ("a hit beside a spell's, %s, came out as %s"):format(state, Outcome(Result(physical))))
        end)
    end
end)

Replay("hits that tie for a line stay someone else's when no swing covers the rest", function()
    Company("alone", function()
        -- Given one swing whose hit is held back.
        local start = LearnedDelay()
        Swing()

        -- When three hits come in the frame of one spell's line, and a fourth alone a moment later.
        At(start + 1)
        Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-three", 133)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-three", 133)
        Line("spell")
        local tied = { Report(), Report(), Report() }
        At(start + 1.3)
        local alone = Report()
        At(start + 2.5)

        -- Then one line and one swing do not cover three hits: none of them is shown, and the swing
        -- keeps its line for the hit that comes in its own time.
        for _, amount in ipairs(tied) do
            assert(Result(amount).who == "unknown", "one of three tied hits was shown")
        end
        assert(Outcome(Result(alone)) == "you as a swing", "the swing lost its line to the tie")
    end)
end)

Replay("a tie takes no more swings than it needs", function()
    Company("alone", function()
        -- Given two swings whose hits are still out.
        local start = LearnedDelay()
        Swing()
        At(start + 0.5)
        Swing()

        -- When the first one's hit ties with a spell's hit, and the second one's comes alone later.
        At(start + 1.2)
        Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-two", 133)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-two", 133)
        Line("spell")
        Report()
        Report()
        At(start + 1.6)
        local second = Report()
        At(start + 2.5)

        -- Then the tie took one swing's line, and the other swing still has its own.
        assert(Outcome(Result(second)) == "you as a swing", "a tie took a swing's line it did not need")
    end)
end)

Replay("a hit its frame's line names keeps its name beside a late swing", function()
    Company("alone", function()
        -- Given a swing whose hit is still out, and a spell on its way to the target.
        local start = LearnedDelay()
        Swing()
        At(start + 0.8)
        Event("UNIT_SPELLCAST_SENT", "player", names.nameplate1, "cast-flight", 999001)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-flight", 999001)

        -- When its hit comes with its line, in a frame with a hit on another unit.
        At(start + 1)
        Line("spell")
        local named = Report()
        Event("UNIT_COMBAT", "nameplate2", "WOUND", "", Amount(), 1)
        At(start + 2)

        -- Then the line's hit is the spell's, not the swing's.
        assert(Outcome(Result(named)) == "you with a spell",
            "a hit its line named came out as " .. Outcome(Result(named)))
    end)
end)

Replay("a queued strike's zero report is not taken for a late swing's hit", function()
    Company("alone", function()
        -- Given a swing whose hit is held back a second.
        local start = LearnedDelay()
        Swing()

        -- When a queued strike lands on the next swing: a zero report and its hit, with one line.
        At(start + 1)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-strike", 78)
        Event("PLAYER_SWING", 1, Enum.PlayerSwingType.MainHand)
        Line("spell")
        local zero, strike = Report(), Report()
        At(start + 2)

        -- Then the hit is the strike's and the zero report is still not shown.
        assert(Result(strike).spell == 78, "the strike's hit lost its name")
        assert(Result(zero).who == "unknown", "the strike's zero report was shown")
    end)
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

-- Forever gives a player a surname: UnitName's second value there, joined to the name by the
-- client's separator in what the game sends. Elsewhere the second value is a realm.
local function WithSurnames(callback)
    local client = MikSBT.Compatibility.Client
    local constants, forever = Constants, client.isForever
    Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
    local ok, failure = pcall(callback)
    Constants, client.isForever = constants, forever
    assert(ok, failure)
end

Replay("a cast sent at a player's name and surname finds the player", function()
    WithSurnames(function()
        -- Given a selected player the client names with a surname.
        local start = Start()
        names.nameplate1 = { "Anna", "Berg" }
        local key = ns.TargetKey()

        -- When a cast is sent at the two names as the game joins them.
        Event("UNIT_SPELLCAST_SENT", "player", "Anna Berg", "cast-surname", 172)
        At(start + 0.1)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-surname", 172)

        -- Then the cast belongs to that player.
        local cast = ns.mine.casts[172][1]
        assert(cast.key == key and not cast.targetUncertain,
            "a name with its surname did not find the player")
    end)
end)

Replay("an interrupt whose interrupter is readable names the enemy with its surname", function()
    WithSurnames(function()
        -- Given a selected player with a surname and a cast of yours.
        local start = Start()
        names.nameplate1 = { "Anna", "Berg" }
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-kick", 172)

        -- When that player's cast is interrupted by you.
        At(start + 0.1)
        Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, "Player-Test")

        -- Then the alert names the player as the game writes the name.
        assert(#alerts == 1 and alerts[1].kind == "interrupt" and alerts[1].sub == "Anna Berg",
            "the interrupt named " .. tostring(alerts[1] and alerts[1].sub))
    end)
end)

Replay("an interrupt settled by its combat log line names the enemy with its surname", function()
    WithSurnames(function()
        -- Given a selected player with a surname, and an interrupter the client hides.
        local start = Start()
        names.nameplate1 = { "Anna", "Berg" }
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-kick", 172)
        At(start + 0.1)
        Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, nil)
        assert(#alerts == 0, "the interrupt did not wait for its line")

        -- When your combat log line of the interrupt comes.
        Line("interrupt")
        At(start + 1)

        -- Then the alert carries the name held for that line, with the surname.
        assert(#alerts == 1 and alerts[1].kind == "interrupt" and alerts[1].sub == "Anna Berg",
            "the held interrupt named " .. tostring(alerts[1] and alerts[1].sub))
    end)
end)

Replay("elsewhere the second name is a realm and is not written after the name", function()
    WithSurnames(function()
        -- Given another client, where UnitName gives the realm, and a selected player from one.
        MikSBT.Compatibility.Client.isForever = false
        local start = Start()
        names.nameplate1 = { "Anna", "Realm" }
        local key = ns.TargetKey()

        -- When a cast is sent at name and realm, and you interrupt that player.
        Event("UNIT_SPELLCAST_SENT", "player", "Anna-Realm", "cast-realm", 172)
        At(start + 0.1)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-realm", 172)
        Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, "Player-Test")

        -- Then the cast finds the player as before, and the alert shows the name alone.
        local cast = ns.mine.casts[172][1]
        assert(cast.key == key and not cast.targetUncertain, "a name with its realm did not find the player")
        assert(#alerts == 1 and alerts[1].sub == "Anna",
            "the interrupt named " .. tostring(alerts[1] and alerts[1].sub))
    end)
end)

Replay("without the client's separator a name stands alone", function()
    -- Given Forever without the constant for the separator, and a selected player with a surname.
    local start = Start()
    names.nameplate1 = { "Anna", "Berg" }
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-kick", 172)

    -- When you interrupt that player.
    At(start + 0.1)
    Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, "Player-Test")

    -- Then the alert shows the name alone.
    assert(#alerts == 1 and alerts[1].sub == "Anna",
        "without a separator the interrupt named " .. tostring(alerts[1] and alerts[1].sub))
end)

Replay("a surname the client hides is left off the name", function()
    WithSurnames(function()
        -- Given a selected player whose surname the client hides.
        local start = Start()
        names.nameplate1 = { "Anna", Amount() }
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-kick", 172)

        -- When you interrupt that player.
        At(start + 0.1)
        Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, "Player-Test")

        -- Then the alert shows the name alone.
        assert(#alerts == 1 and alerts[1].sub == "Anna",
            "with a hidden surname the interrupt carried a " .. type(alerts[1] and alerts[1].sub))
    end)
end)

Replay("a name the client hides is not shown", function()
    WithSurnames(function()
        -- Given a selected player whose name the client hides.
        local start = Start()
        names.nameplate1 = { Amount(), "Berg" }
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-kick", 172)

        -- When you interrupt that player.
        At(start + 0.1)
        Event("UNIT_SPELLCAST_INTERRUPTED", "target", "cast-enemy", 999, "Player-Test")

        -- Then the alert comes without a name.
        assert(#alerts == 1 and alerts[1].sub == nil,
            "with a hidden name the interrupt carried a " .. type(alerts[1] and alerts[1].sub))
    end)
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

assert(#failures == 0, table.concat(failures, "\n"))
print("Reader attribution lifecycle tests passed")
