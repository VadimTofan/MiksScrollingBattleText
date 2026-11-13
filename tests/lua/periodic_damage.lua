-- Run from the addon root: lua5.1 tests/lua/periodic_damage.lua
local count = 0
local filter = os.getenv("MSBT_TEST_FILTER")
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, run)
    if filter and not name:find(filter, 1, true) then return end
    run()
    count = count + 1
    print("ok " .. count .. " - " .. name)
end

local locale, descriptions = "enUS", {}
MikSBT = { CombatEngine = {}, Components = {}, API = {} }
local ns = MikSBT.CombatEngine
GetLocale = function() return locale end
ns.Text = function(value) return type(value) == "string" and value ~= "" end
ns.Bool = function(value) return type(value) == "boolean" end
ns.Number = function(value, low, high)
    return type(value) == "number" and (not low or value >= low) and (not high or value <= high)
end
ns.Public = function() return true end
C_Spell = { GetSpellDescription = function(id) return descriptions[id] end }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")

local clock, callbacks, shown = 0, {}, {}
GetTime = function() return clock end
local function after(delay, callback) callbacks[#callbacks + 1] = { at = clock + delay, run = callback } end
local function flush()
    while #callbacks > 0 do
        table.sort(callbacks, function(a, b) return a.at < b.at end)
        local next = table.remove(callbacks, 1)
        clock = math.max(clock, next.at)
        next.run()
    end
end
ns.Timer = { After = after }
UnitExists = function(unit) return unit == "target" end
local target = "nameplate1"
UnitIsUnit = function(a, b) return (a == target and b == "target") or a == b end
ns.RekeyHealing = function() end
ns.ForgetHealing = function() end
ns.EventAvailable = function() return true end
MikSBT.API.RestrictedValue = {
    IsRestricted = function() return false end,
    Number = function(_, value) return type(value) == "number" and value or nil end,
    Table = function(_, value) return type(value) == "table" and value or nil end,
}
dofile("Combat/Reader.lua")
local CombatLog = dofile("Components/CombatLogFilter.lua")
local savedFilter = { filters = {} }
local log = CombatLog:New({ getSaved = function() return savedFilter end, mineFlag = 1, petFlag = 2 })
assert(log:WriteSettings())
assert(log:IsReady())
log:ConfigureNamespace(ns)
Blizzard_CombatLog_Filters, COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = savedFilter, 1, 2
local Batcher = dofile("Components/OutgoingBatcher.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local Engine = dofile("Components/CombatEngine.lua")
local profile = { events = {
    OUTGOING_SPELL_DOT = { key = "OUTGOING_SPELL_DOT" },
    OUTGOING_SPELL_DAMAGE = { key = "OUTGOING_SPELL_DAMAGE" },
} }
local ready = true
local batcher = Batcher:New({ getProfile = function() return profile end, after = after, delay = 0.12,
    getSpellTexture = function(id) return id end,
    formatEventMessage = function(_, amount) return tostring(amount) end,
    display = function(settings, message, icon)
        shown[#shown + 1] = { key = settings.key, message = message, icon = icon }
    end })
local presentation = Presentation:New({ batcher = batcher, getSpellTexture = function(id) return id end })
local engine = Engine:New({ presentation = presentation, log = { IsReady = function() return ready and log:IsReady() end } })
ns.liveRouter = engine:CreateRouter()
local function reset(learned)
    clock, callbacks, shown, target, ready = 0, {}, {}, "nameplate1", true
    descriptions = {}
    for _, spell in ipairs({ 1, 2, 3 }) do ns.ForgetSpellFacts(spell) end
    learned = learned or { school = {}, direct = {}, period = {} }
    ns.mine = ns.NewMine(function(field, id) return learned[field][id] end,
        function(field, id, value) learned[field][id] = value end, ns.SpellFacts)
    ns.reader.epoch, ns.reader.plates, ns.reader.targetPlate = 0, {}, nil
    ns.reader.frameHits, ns.reader.held, ns.reader.logLines = {}, {}, {}
    ns.reader.yourHits, ns.reader.swingHits, ns.reader.swingTimes = {}, {}, {}
    ns.reader.playerHeals = {}
    ns.reader.sawGrey = true
    ns.ReaderEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    return learned
end
Enum = { CombatLogMessageOrder = { Oldest = 0 } }
local function combatLine(kind)
    local colours = { tick = { 0.8, 0.6, 1 }, direct = { 1, 0.8, 0.3 },
        shot = { 0.85, 0.7, 0.5 }, untyped = { 0.5, 0.5, 0.5 }, other = { 0.2, 0.2, 0.2 } }
    local rgb = colours[kind]
    ns.ReaderEvent(nil, "COMBAT_LOG_MESSAGE", "not inspected", rgb[1], rgb[2], rgb[3], 1)
end
local function cast(spell)
    ns.ReaderEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", spell or 1)
end
local function beginDot(learned)
    local cache = reset(learned)
    cast()
    return cache
end
local function hit(amount, school, unit)
    ns.ReaderEvent(nil, "UNIT_COMBAT", unit or "target", "WOUND", "", amount or 20, school)
end
local function assertDot(message, spell)
    for _, item in ipairs(shown) do
        if item.key == "OUTGOING_SPELL_DOT" then
            equal(item.message, message or "20", "tick amount")
            equal(item.icon, spell or 1, "DoT icon")
            return
        end
    end
    error("DoT did not reach display")
end

test("isolated DoT with confirmation in a later frame", function()
    beginDot()
    clock = 3
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
end)
test("isolated DoT with confirmation in an earlier frame", function()
    beginDot()
    clock = 2.8
    combatLine("tick")
    clock = 3
    hit(20, 32)
    flush()
    assertDot()
end)
for _, language in ipairs({ "enUS", "enGB", "ruRU", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "koKR", "zhCN", "zhTW" }) do
    for _, loaded in ipairs({ false, true }) do
        test(language .. (loaded and " with description" or " without description"), function()
            locale = language
            local learned = reset()
            if loaded then
                descriptions[1] = (language == "enUS" or language == "enGB")
                    and "Stings the target, causing 70 Nature damage over 15 sec."
                    or "Localized tooltip is not parsed"
            end
            cast()
            for index = 1, 5 do
                clock = 0.8 + index * 3
                ns.mine:Tidy(clock)
                hit(28, 8)
                after(0.05, function() combatLine("tick") end)
                flush()
                equal(#shown, index, "every projectile tick displayed")
                equal(shown[index].key, "OUTGOING_SPELL_DOT", "periodic event")
                equal(shown[index].icon, 1, "stable icon")
                equal(shown[index].message, "28", "actual damage, not tooltip estimate")
                if index == 1 then equal(learned.period[1], nil, "flight time is not an interval") end
            end
            assert(math.abs(learned.period[1] - 3) < 0.0001, "interval measured between actual ticks")
        end)
    end
end
locale = "enUS"

test("stale learned school kind and period recover without a tooltip or cache reset", function()
    local learned = beginDot({ school = { [1] = 1, [99] = 16 }, direct = { [1] = 1 }, period = { [1] = 2 } })
    for index = 1, 3 do
        clock = 0.8 + index * 3
        ns.mine:Tidy(clock)
        hit(28, 8)
        after(0.05, function() combatLine("tick") end)
        flush()
        equal(#shown, index, "stale guesses cannot hide confirmed ticks")
    end
    equal(learned.school[1], 8, "observed school replaces stale guess")
    equal(learned.direct[1], 2, "periodic kind replaces stale directOnly")
    assert(math.abs(learned.period[1] - 3) < 0.0001, "observed interval replaces stale guess")
    equal(learned.school[99], 16, "unrelated cache preserved")
end)
test("stale directOnly without any tracked DoT recovers from history", function()
    local learned = beginDot({ school = { [1] = 1 }, direct = { [1] = 1 }, period = {} })
    equal(#ns.mine:Dots(), 0, "no initial DoT")
    for index = 1, 2 do
        clock = 0.8 + index * 3
        hit(20, 8)
        combatLine("tick")
        flush()
        equal(#shown, index, "history recovers every tick")
    end
    equal(learned.school[1], 8, "school corrected after repeated evidence")
    equal(learned.direct[1], 2, "kind corrected")
end)
test("periodic fitting is read-only even with stale cached guesses", function()
    beginDot({ school = { [1] = 1 }, direct = { [1] = 1 }, period = {} })
    local pending = #ns.mine.pending
    assert(ns.mine:TickFit("nameplate1", 8, 3.8, 20))
    assert(ns.mine:TickFit("nameplate1", nil, 3.8, nil))
    equal(#ns.mine:Dots(), 0, "fit cannot create DoTs")
    equal(#ns.mine.pending, pending, "fit cannot consume casts")
    equal(ns.mine.pending[1].used, nil, "cast remains unused")
end)
test("wrong schools from actual spell facts are not overridden", function()
    reset()
    descriptions[1] = "Causes 120 Shadow damage over 18 sec."
    cast()
    clock = 3.8
    hit(20, 4)
    combatLine("tick")
    flush()
    equal(#shown, 0, "authoritative school mismatch rejected")
end)
test("a direct-only spell description is not a periodic candidate", function()
    reset()
    descriptions[1] = "Deals 60 Fire damage."
    cast()
    clock = 3.8
    hit(20, 4)
    combatLine("tick")
    flush()
    equal(#shown, 0, "direct-only spell cannot claim an unrelated tick")
end)
test("mixed spell retains its direct hit after delayed DoT recovery", function()
    local learned = beginDot()
    clock = 0.1
    hit(60, 4)
    combatLine("direct")
    flush()
    equal(shown[1].key, "OUTGOING_SPELL_DAMAGE", "direct hit")
    for index = 1, 2 do
        clock = 0.8 + index * 3
        ns.mine:Tidy(clock)
        hit(20, 4)
        after(0.05, function() combatLine("tick") end)
        flush()
        equal(#shown, index + 1, "direct hit and every delayed tick displayed")
    end
    equal(learned.direct[1], 3, "recovery preserves observed direct damage")
end)
test("four-second ticks do not depend on the old first-tick offsets", function()
    local learned = beginDot()
    for index = 1, 3 do
        clock = 0.8 + index * 4
        ns.mine:Tidy(clock)
        hit(20, 8)
        after(0.05, function() combatLine("tick") end)
        flush()
        equal(#shown, index, "long-interval tick displayed")
    end
    assert(math.abs(learned.period[1] - 4) < 0.0001, "four-second interval learned")
end)
test("an established DoT survives expiration of its cast history", function()
    local learned = beginDot()
    for index = 1, 12 do
        clock = 0.8 + index * 3
        ns.mine:Tidy(clock)
        hit(20, 8)
        after(0.05, function() combatLine("tick") end)
        flush()
        equal(#shown, index, "ongoing tick displayed")
    end
    equal(ns.mine.casts[1], nil, "history actually expired")
    assert(math.abs(learned.period[1] - 3) < 0.0001, "established interval retained")
end)
test("a missing report does not double an established interval", function()
    local learned = beginDot()
    for _, at in ipairs({ 3.8, 6.8, 12.8 }) do
        clock = at
        ns.mine:Tidy(clock)
        hit(20, 8)
        after(0.05, function() combatLine("tick") end)
        flush()
    end
    equal(#shown, 3, "only actual reports displayed")
    assert(math.abs(learned.period[1] - 3) < 0.0001, "missing report did not teach six seconds")
end)
test("expired casts cannot recover unrelated ticks", function()
    beginDot()
    clock = 35
    ns.mine:Tidy(clock)
    hit(20, 8)
    combatLine("tick")
    flush()
    equal(#shown, 0, "expired history rejected")
end)
test("ambiguous periodic matches do not overwrite learned guesses", function()
    local learned = beginDot()
    cast(2)
    for _, at in ipairs({ 3.8, 6.8 }) do
        clock = at
        hit(20, 8)
        combatLine("tick")
        flush()
    end
    equal(learned.school[1], nil, "ambiguous school not saved")
    equal(learned.period[1], nil, "ambiguous interval not saved")
    equal(learned.school[2], nil, "other ambiguous school not saved")
    equal(learned.period[2], nil, "other ambiguous interval not saved")
end)
test("confirmed tick on another target retains the history fallback", function()
    reset()
    ns.mine:Cast("you", 1, "nameplate2", 0)
    clock = 3
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
end)
test("plate lost before first tick can recover", function()
    beginDot()
    ns.mine:Forget("nameplate1")
    clock = 3.8
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
end)
test("cross-frame DoT survives target switch", function()
    beginDot()
    target = "nameplate2"
    ns.ReaderEvent(nil, "PLAYER_TARGET_CHANGED")
    ns.ReaderEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
    clock = 3
    hit(20, 32, "nameplate1")
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
end)
test("contested first tick prefers its own target", function()
    beginDot()
    clock = 3
    ns.reader.frameHits = {
        { at = 3, key = "other", record = { event = "damage", amount = 99, school = 32 } },
        { at = 3, key = "nameplate1", record = { event = "damage", amount = 20, school = 32 } },
    }
    combatLine("tick")
    ns.DecideFrame()
    flush()
    equal(#shown, 1, "only one confirmed report")
    assertDot()
end)
for _, kind in ipairs({ "other", "untyped" }) do
    test(kind .. " line cannot confirm delayed periodic damage", function()
        local learned = beginDot()
        clock = 3.8
        hit(20, 32)
        after(0.05, function() combatLine(kind) end)
        flush()
        equal(#shown, 0, "unconfirmed damage hidden")
        equal(learned.period[1], nil, "no learning without confirmation")
    end)
end
test("damage without a log line stays hidden", function()
    beginDot()
    clock = 3
    hit(20, 32)
    flush()
    equal(#shown, 0, "foreign damage hidden")
end)
test("one delayed confirmation is consumed only once", function()
    beginDot()
    clock = 3
    hit(20, 32)
    after(0.02, function() combatLine("tick") end)
    after(0.05, function() hit(20, 32) end)
    flush()
    assertDot()
    equal(#shown, 1, "one own tick only")
end)
test("near-duplicate reports do not teach a cast interval", function()
    local learned = beginDot()
    clock = 3
    hit(20, 32)
    combatLine("tick")
    flush()
    clock = 3.2
    hit(20, 32)
    combatLine("tick")
    flush()
    equal(#shown, 1, "near-duplicate hidden")
    equal(learned.period[1], nil, "no invented interval")
end)
test("confirmation outside the late window is not borrowed", function()
    beginDot()
    clock = 3
    hit(20, 32)
    after(0.2, function() combatLine("tick") end)
    flush()
    equal(#shown, 0, "too-late confirmation ignored")
end)
for _, delayed in ipairs({ false, true }) do
    test("simultaneous direct damage keeps its own amount " .. tostring(delayed), function()
        beginDot()
        clock = 2.9
        cast(2)
        clock = 3
        combatLine("direct")
        if delayed then after(0.05, function() combatLine("tick") end) else combatLine("tick") end
        hit(20, nil)
        hit(60, 4)
        flush()
        assertDot()
        equal(#shown, 2, "both hits displayed separately")
        for _, item in ipairs(shown) do
            if item.key ~= "OUTGOING_SPELL_DOT" then equal(item.icon, 2, "direct hit icon") end
        end
    end)
end
for _, opaqueSchool in ipairs({ false, true }) do
    test("missing tick never borrows an auto-shot amount " .. tostring(opaqueSchool), function()
        beginDot()
        ns.mine.wandSchool = 1
        ns.mine:Swing("ranged", "nameplate1", 2.6)
        clock = 3
        combatLine("tick")
        combatLine("shot")
        local school
        if not opaqueSchool then school = 1 end
        hit(80, school)
        flush()
        equal(#shown, 1, "only reported shot displayed")
        equal(shown[1].message, "80", "no fabricated tick amount")
        equal(shown[1].icon, 5019, "shot icon")
    end)
end
test("auto shot and delayed DoT retain separate icons", function()
    beginDot()
    ns.mine.wandSchool = 1
    ns.mine:Swing("ranged", "nameplate1", 2.6)
    clock = 3
    combatLine("shot")
    hit(20, nil)
    hit(80, 1)
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
    equal(#shown, 2, "shot and DoT displayed")
end)
test("maintenance cannot skip a buffered tick", function()
    beginDot()
    local dot = ns.mine:Dots()[1]
    dot.period, dot.next, dot.known = 3, 3, true
    clock = 3.1
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    after(0.1, function() ns.mine:Tidy(clock) end)
    flush()
    assertDot()
    equal(dot.ticks, 1, "buffered tick counted")
end)
test("unkeyed known DoT recovers only after confirmation", function()
    beginDot()
    local dot = ns.mine:Dots()[1]
    dot.period, dot.next, dot.known = 3, 3, true
    ns.mine:Forget("nameplate1")
    clock = 3
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    flush()
    assertDot()
    equal(dot.key, "nameplate1", "re-adopted")
end)
test("opaque amounts and school are not inspected", function()
    local learned = beginDot()
    local opaque = {}
    local restricted = MikSBT.API.RestrictedValue.IsRestricted
    MikSBT.API.RestrictedValue.IsRestricted = function(_, value) return value == opaque end
    batcher.config.displayRestricted = function(settings, _, icon)
        shown[#shown + 1] = { key = settings.key, message = "restricted", icon = icon }
    end
    for index = 1, 2 do
        clock = 0.8 + index * 3
        hit(opaque, nil)
        after(0.05, function() combatLine("tick") end)
        flush()
        equal(#shown, index, "opaque tick displayed")
        equal(shown[index].key, "OUTGOING_SPELL_DOT", "opaque periodic event")
        equal(shown[index].icon, 1, "opaque tick icon")
    end
    MikSBT.API.RestrictedValue.IsRestricted = restricted
    assert(math.abs(learned.period[1] - 3) < 0.0001, "interval uses timestamps only")
end)
test("unreadable line colours cannot confirm damage", function()
    local source, kind = ns.LineSource(nil, nil, nil)
    equal(source, "unknown", "unreadable source")
    equal(kind, "other", "no damage confirmation")
end)
test("unready combat-log filter blocks output", function()
    beginDot()
    ready = false
    clock = 3
    hit(20, 32)
    combatLine("tick")
    flush()
    equal(#shown, 0, "filter gate")
end)
test("foreign sources invalidate the confirmation filter", function()
    local part = savedFilter.filters[1].filters[1]
    part.sourceFlags[3] = true
    equal(log:IsReady(), false, "foreign source rejected")
    part.sourceFlags[3] = nil
    equal(log:IsReady(), true, "own-only restored")
end)

-- Describe: healing evidence distinguishes simultaneous periodic spells.
test("a matching heal keeps the draining tick's spell identity", function()
    -- Given two Shadow DoTs due together, only spell 2 drains health.
    reset({ school = { [1] = 32, [2] = 32 },
        direct = { [1] = 2, [2] = 2 }, period = { [1] = 3, [2] = 3 } })
    descriptions[1] = "Causes 120 Shadow damage over 18 sec."
    descriptions[2] = "Causes 120 Shadow damage over 18 sec. "
        .. "Transfers health to the caster."
    cast(1)
    cast(2)
    clock = 3
    ns.reader.playerHeals = { { at = clock, amount = 20 } }

    -- When a confirmed tick has a same-frame heal of the same amount.
    hit(20, 32)
    after(0.05, function() combatLine("tick") end)
    flush()

    -- Then the real reader/display pipeline retains the draining identity.
    equal(#shown, 1, "one confirmed tick displayed")
    assertDot("20", 2)
    equal(ns.mine:Dots()[1].ticks, 0, "non-draining DoT not advanced")
    equal(ns.mine:Dots()[2].ticks, 1, "draining DoT advanced")
end)

test("periodic fits use only the current hit's healing evidence", function()
    -- Given a non-draining DoT due now, with no learned damage amounts.
    beginDot({ school = { [1] = 32 }, direct = { [1] = 2 },
        period = { [1] = 3 } })
    local dot = ns.mine:Dots()[1]

    -- When the same hit is fitted with and without a matching heal.
    local ordinary = ns.mine:TickFit("nameplate1", 32, 3, 20)
    local draining = ns.mine:TickFit("nameplate1", 32, 3, 20, true)
    ns.mine:Hit("nameplate1", "damage", 32, 3, false, true,
        20, false, "tick", true)
    local nextOrdinary = ns.mine:TickFit("nameplate1", 32, 6, 20)
    local nextDraining = ns.mine:TickFit("nameplate1", 32, 6, 20, true)

    -- Then mismatches score worse and old healing evidence cannot leak.
    assert(draining > ordinary, "matching heal ignored during fitting")
    assert(nextDraining > nextOrdinary, "previous heal leaked into fitting")
    equal(dot.ticks, 1, "read-only fits did not consume another tick")
    equal(dot.next, 6, "read-only fits did not advance the rhythm")
end)

-- Describe: periodic channels share confirmations with established DoTs.
test("Drain Life cannot take a due Siphon Life tick", function()
    -- Given a known draining DoT and an active draining channel.
    reset({ school = { [1] = 32 }, direct = { [1] = 2 },
        period = { [1] = 3 } })
    descriptions[1] = "Causes 80 Shadow damage over 12 sec. "
        .. "Transfers health to the caster."
    descriptions[2] = "Transfers 10 health every 1 sec "
        .. "from the target to the caster. Lasts 5 sec."
    cast(1)
    ns.mine.amounts[1] = { n = 1, [20] = true }
    clock = 1
    ns.mine:StartChannel("you", 2, "nameplate1", clock)
    clock = 3
    ns.reader.playerHeals = { { at = clock, amount = 20 } }

    -- When the DoT's confirmed tick also heals the player.
    hit(20, 32)
    combatLine("tick")
    flush()

    -- Then its identity and next tick remain attached to the DoT.
    equal(#shown, 1, "one confirmed tick")
    assertDot("20", 1)
    equal(ns.mine:Dots()[1].next, 6, "draining DoT rhythm advanced")
end)

test("a channel cannot flatten competing DoT amount evidence", function()
    -- Given a known DoT amount and a same-school periodic channel.
    reset({ school = { [1] = 32 }, direct = { [1] = 2 },
        period = { [1] = 3 } })
    descriptions[1] = "Causes 80 Shadow damage over 12 sec."
    descriptions[2] = "Drains the soul of the target, "
        .. "causing 55 Shadow damage over 15 sec."
    cast(1)
    ns.mine.amounts[1] = { n = 1, [20] = true }
    clock = 1
    ns.mine:StartChannel("you", 2, "nameplate1", clock)
    clock = 3

    -- When a foreign hit precedes a partial-resist tick, with one own line.
    local foreignFit = ns.mine:Fit("nameplate1", "damage", 32, 3,
        99, "tick")
    local ownFit = ns.mine:Fit("nameplate1", "damage", 32, 3,
        10, "tick")
    hit(99, 32)
    hit(10, 32)
    combatLine("tick")
    flush()

    -- Then fitting and the real display both retain the DoT's evidence.
    assert(ownFit < foreignFit, "channel erased the amount distinction")
    equal(#shown, 1, "one confirmed tick displayed")
    assertDot("10", 1)
end)

for _, healed in ipairs({ false, true }) do
    local name = "delayed channel confirmation reaches display "
        .. tostring(healed)
    test(name, function()
        -- Given an isolated Drain Life channel with no ordinary cast record.
        reset()
        descriptions[2] = "Transfers 10 health every 1 sec "
            .. "from the target to the caster. Lasts 5 sec."
        ns.mine:StartChannel("you", 2, "nameplate1", 0)
        clock = 1
        if healed then
            ns.reader.playerHeals = { { at = clock, amount = 10 } }
        end

        -- When its periodic confirmation arrives in the following frame.
        hit(10, 32)
        after(0.05, function() combatLine("tick") end)
        flush()

        -- Then the tick reaches the display with its channel identity.
        equal(#shown, 1, "channel tick displayed once")
        assertDot("10", 2)
        assert(ns.mine.amounts[2] and ns.mine.amounts[2][10],
            "confirmed channel amount not retained")
    end)
end

for _, scenario in ipairs({
    { channelFirst = false, gap = 0 },
    { channelFirst = true, gap = 0 },
    { channelFirst = false, gap = 0.05 },
    { channelFirst = true, gap = 0.05 },
}) do
    local channelFirst, gap = scenario.channelFirst, scenario.gap
    test("simultaneous draining amounts stay separate "
        .. tostring(channelFirst) .. " gap " .. gap, function()
        -- Given a 20-damage draining DoT and Drain Life due together.
        reset({ school = { [1] = 32 }, direct = { [1] = 2 },
            period = { [1] = 3 } })
        descriptions[1] = "Causes 80 Shadow damage over 12 sec. "
            .. "Transfers health to the caster."
        descriptions[2] = "Transfers 10 health every 1 sec "
            .. "from the target to the caster. Lasts 5 sec."
        cast(1)
        ns.mine.amounts[1] = { n = 1, [20] = true }
        ns.mine.amounts[2] = { n = 1, [10] = true }
        ns.mine:StartChannel("you", 2, "nameplate1", 1)
        clock = 3
        ns.reader.playerHeals = {
            { at = clock, amount = channelFirst and 10 or 20 },
        }

        -- When both confirmed, healing ticks arrive in either order.
        hit(channelFirst and 10 or 20, 32)
        combatLine("tick")
        local function secondTick()
            ns.reader.playerHeals[#ns.reader.playerHeals + 1] = {
                at = clock, amount = channelFirst and 20 or 10,
            }
            hit(channelFirst and 20 or 10, 32)
            combatLine("tick")
        end
        if gap == 0 then secondTick() else after(gap, secondTick) end
        flush()

        -- Then each actual amount keeps its spell and the DoT advances once.
        equal(#shown, 2, "both draining ticks displayed")
        local dot, channel
        for _, item in ipairs(shown) do
            if item.icon == 1 then dot = item end
            if item.icon == 2 then channel = item end
        end
        assert(dot, "draining DoT identity missing")
        assert(channel, "channel tick identity missing")
        equal(dot.message, "20", "DoT retained its amount")
        equal(channel.message, "10", "channel retained its amount")
        equal(ns.mine:Dots()[1].next, 6 + (channelFirst and gap or 0),
            "DoT rhythm follows its actual impact")
        equal(ns.mine:Dots()[1].ticks, 1, "DoT advanced once")
    end)
end

-- Describe: a frame waiting for a periodic confirmation keeps its own lines.
local function runUntil(time)
    while true do
        table.sort(callbacks, function(a, b) return a.at < b.at end)
        local next = callbacks[1]
        if not next or next.at > time then break end
        table.remove(callbacks, 1)
        clock = math.max(clock, next.at)
        next.run()
    end
    clock = time
end
for _, gap in ipairs({ 0.017, 0.05, 0.1 }) do
    test("an earlier hit cannot take the line of a waiting attack, " .. gap .. " s", function()
        -- Given a taunt and a strike learned as physical blows, and no
        -- description read, so the taunt might still be a DoT.
        locale = "deDE"
        reset({ school = { [1] = 1, [2] = 1 }, direct = { [1] = 1, [2] = 1 }, period = {} })
        profile.events.OUTGOING_DAMAGE = { key = "OUTGOING_DAMAGE" }
        cast(1)

        -- When someone else's blow lands just before the strike, its hit and
        -- its line.
        runUntil(1 - gap)
        hit(30, 1)
        runUntil(1)
        cast(2)
        hit(40, 1)
        combatLine("direct")
        flush()

        -- Then the strike keeps its line and the earlier blow stays hidden.
        local own, other
        for _, item in ipairs(shown) do
            if item.message == "40" then own = item end
            if item.message == "30" then other = item end
        end
        assert(own, "the strike lost its line to an earlier hit")
        assert(not other, "an earlier hit took the strike's line")
        profile.events.OUTGOING_DAMAGE = nil
        locale = "enUS"
    end)
end
test("a waiting frame keeps only its own lines", function()
    -- Given a taunt, then a bolt whose line came before its hit.
    locale = "deDE"
    reset({ school = { [1] = 1, [2] = 1, [3] = 4 }, direct = { [1] = 1, [2] = 1, [3] = 1 }, period = {} })
    cast(1)
    runUntil(0.7)
    cast(3)
    combatLine("direct")

    -- When the bolt lands in a frame of its own, and a strike in the frame
    -- after waits for a periodic confirmation.
    runUntil(0.85)
    hit(50, 4)
    runUntil(0.9)
    cast(2)
    hit(40, 1)
    combatLine("direct")
    runUntil(0.95)

    -- Then, while the strike waits, only the line of its frame is kept.
    for _, line in ipairs(ns.reader.logLines) do
        equal(not not line.claimed, line.at == 0.9, "line at " .. line.at .. " kept")
    end
    flush()

    -- Then the bolt still finds its line, and the strike keeps its own.
    local bolt, strike
    for _, item in ipairs(shown) do
        if item.message == "50" then bolt = item end
        if item.message == "40" then strike = item end
    end
    assert(bolt and bolt.icon == 3, "a waiting frame kept a bolt's line from another frame")
    assert(strike, "the strike lost its line")
    locale = "enUS"
end)
for _, gap in ipairs({ 0.03, 0.08 }) do
    test("a waiting frame keeps no more lines than its hits, " .. gap .. " s", function()
        -- Given a taunt, then a bolt reported with no line of its own.
        locale = "deDE"
        reset({ school = { [1] = 1, [2] = 1, [3] = 4 }, direct = { [1] = 1, [2] = 1, [3] = 1 }, period = {} })
        cast(1)
        runUntil(0.7)
        cast(3)
        runUntil(1 - gap)
        hit(50, 4)

        -- When a strike in a later frame waits with two lines in its frame.
        runUntil(1)
        cast(2)
        hit(40, 1)
        combatLine("direct")
        combatLine("direct")
        flush()

        -- Then the spare line still serves the bolt.
        local bolt, strike
        for _, item in ipairs(shown) do
            if item.message == "50" then bolt = item end
            if item.message == "40" then strike = item end
        end
        assert(bolt and bolt.icon == 3, "a waiting frame kept a line its hits cannot use")
        assert(strike, "the strike lost its line")
        locale = "enUS"
    end)
    test("a waiting frame leaves a miss line to an earlier miss, " .. gap .. " s", function()
        -- Given a taunt, then a resist reported with no line of its own.
        locale = "deDE"
        reset({ school = { [1] = 1, [2] = 1, [3] = 4 }, direct = { [1] = 1, [2] = 1, [3] = 1 }, period = {} })
        local missed
        ns.MissWord = ns.MissWord or function(token) return token end
        presentation.config.getProfile = function() return profile end
        ns.traceCombat = function(stage, hit)
            if stage == "decision" and hit and hit.record.event == "miss" then missed = hit.record.result end
        end
        cast(1)
        runUntil(0.7)
        cast(3)
        runUntil(1 - gap)
        ns.ReaderEvent(nil, "UNIT_COMBAT", "target", "RESIST", "", 0, 4)

        -- When a strike in a later frame waits, with a spell's miss line and
        -- its own line in its frame.
        runUntil(1)
        cast(2)
        hit(40, 1)
        ns.ReaderEvent(nil, "COMBAT_LOG_MESSAGE", "not inspected", 0.6, 0.65, 0.8, 1)
        combatLine("direct")
        flush()
        ns.traceCombat, presentation.config.getProfile = nil, nil

        -- Then the resist still finds its line.
        assert(missed and missed.who == "you", "a waiting frame kept a miss line from an earlier miss")
        locale = "enUS"
    end)
    test("a waiting frame leaves a tick's line to a tick reported before it, " .. gap .. " s", function()
        -- Given a DoT whose tick is reported a moment before its line.
        beginDot()
        clock = 3
        hit(20, 32)

        -- When another report of its school lands in the line's frame.
        runUntil(3 + gap)
        hit(33, 32)
        combatLine("tick")
        flush()

        -- Then the tick keeps its line and the other report stays hidden.
        assertDot()
        for _, item in ipairs(shown) do
            assert(item.message ~= "33", "a later report took a tick's line")
        end
    end)
end

print("PASS: " .. count .. " tests")
