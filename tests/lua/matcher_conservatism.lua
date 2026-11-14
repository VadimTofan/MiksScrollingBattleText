-- Describe: known ownership does not resolve competing spell identities.
MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local failures = {}
local function Check(name, run)
    local ok, message = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. message end
end
local function New(facts)
    local learned = { school = {}, period = {}, direct = {} }
    local mine = ns.NewMine(
        function(field, spell) return learned[field][spell] end,
        function(field, spell, value) learned[field][spell] = value end,
        function(spell) return facts[spell] end)
    return mine, learned
end
local function Dot(period, duration)
    return { damages = true, direct = false, ticks = true,
        school = 32, period = period, duration = duration }
end
local function Hit(mine, at, kind, restrict, key, amount)
    return mine:Hit(key or "t", kind or "damage", 32, at,
        false, true, amount, false, restrict or "tick", nil, "RESIST")
end
local function Unnamed(result, tick)
    assert(result.who == "you" and result.spell == nil,
        "confirmed ownership received a speculative identity")
    assert(result.tick == tick and result.ambiguous,
        "unresolved identity lost its type or ambiguity marker")
end

Check("pet activity without confirmation cannot establish ownership", function()
    -- Given an attacking pet with no cast, native swing, or own line.
    local mine = New({})
    -- When both an explicitly foreign report and an unconfirmed report arrive.
    for _, line in ipairs({ false, "unconfirmed" }) do
        local confirmation
        if line == false then confirmation = false end
        local result = mine:Hit("t", "damage", 1, 10, true,
            confirmation)
        -- Then pet activity alone never claims either report.
        assert(result.who == "unknown", "pet activity claimed foreign damage")
    end
end)

Check("same-creature opaque rekey retains a supported periodic identity",
    function()
    -- Given an effect whose old and new keys are proven to be one creature.
    local oldKey, newKey = {}, {}
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, oldKey, 0)
    -- When the reader supplies that evidence through Rekey.
    mine:Rekey(oldKey, newKey)
    local result = Hit(mine, 3, nil, nil, newKey)
    -- Then the valid lifetime keeps its effect identity.
    assert(result.spell == 1 and mine.dots[1].key == newKey)
end)

Check("uncertain cast target cannot supply a spell name", function()
    -- Given an observed spell with an unresolved sent recipient.
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, nil, 0, true)
    -- When a compatible owned tick arrives on a visible target.
    local result = Hit(mine, 3)
    -- Then the cast supplies competing evidence without inventing a target.
    Unnamed(result, true)
end)

Check("uncertain direct target competes with a resolved cast", function()
    -- Given two same-school spells, one with an unresolved recipient.
    local facts = { damages = true, direct = true, ticks = false, school = 32 }
    local mine = New({ [1] = facts, [2] = facts })
    mine:Cast("player", 1, nil, 0, true)
    mine:Cast("player", 2, "t", 1.5)
    -- When a later owned report can correspond to either public cast.
    local result = Hit(mine, 1.7, nil, "direct")
    -- Then the resolved cast does not override the missing target evidence.
    Unnamed(result, false)
end)

Check("forgotten DoTs cannot adopt an unrelated lifetime key", function()
    -- Given an effect on a creature whose opaque lifetime key is forgotten.
    local oldKey, newKey = {}, {}
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, oldKey, 0)
    mine:Forget(oldKey)
    -- When an owned report on another creature shares its old rhythm.
    local result = Hit(mine, 3, nil, nil, newKey)
    -- Then ownership remains unnamed and no effect moves to that creature.
    assert(result.who == "you" and result.spell == nil,
        "forgotten effect named another creature's report")
    for _, dot in ipairs(mine.dots) do
        assert(dot.key ~= newKey, "forgotten DoT adopted another key")
    end
end)

Check("cast history cannot name a different target's periodic report", function()
    -- Given a known effect on A and an unrelated creature B.
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, "a", 0)
    -- When a confirmed tick is reported on B at the same time.
    local result = Hit(mine, 3, nil, nil, "b")
    -- Then timing cannot move the identity from A to B.
    assert(result.who == "you" and result.spell == nil)
    assert(mine.dots[1].key == "a")
end)

Check("forgotten periodic timing remains blocking evidence only", function()
    -- Given a known offscreen effect on an old lifetime.
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, "a", 0)
    mine:Forget("a")
    -- When the reader asks whether its line could be from the lost target.
    assert(type(mine.OffscreenTickFit) == "function",
        "matcher does not expose lost-target blocking evidence")
    -- Then only its valid same-school beat blocks foreign report adoption.
    assert(mine:OffscreenTickFit("b", 32, 3))
    assert(not mine:OffscreenTickFit("b", 4, 3))
    assert(not mine:OffscreenTickFit("b", 32, 4))
    assert(not mine:OffscreenTickFit("b", 32, 21))
    assert(#mine.dots == 0 and mine.casts[1] == nil)
end)

Check("another visible target's periodic effect blocks ownership borrowing",
    function()
    -- Given a known effect still ticking on a different visible target.
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, "a", 0)
    -- When a line can describe that effect rather than the report on B.
    assert(mine:OffscreenTickFit("b", 32, 3),
        "another target's due effect did not block borrowing its line")
    -- Then the same target's own report remains eligible.
    assert(not mine:OffscreenTickFit("a", 32, 3))
    assert(not mine:OffscreenTickFit("b", 32, 3, { a = true, b = true }),
        "a represented periodic target was treated as offscreen")
end)

Check("GCD-separated coincident ticks stay unnamed without changing rhythm",
    function()
    -- Given Corruption at 0 and Agony at 3, with their real periods.
    local mine, learned = New({ [172] = Dot(3, 18), [980] = Dot(2, 24) })
    mine:Cast("player", 172, "t", 0)
    assert(Hit(mine, 3).spell == 172)
    mine:Cast("player", 980, "t", 3)
    assert(Hit(mine, 5).spell == 980)
    assert(Hit(mine, 6).spell == 172)
    assert(Hit(mine, 7).spell == 980)
    local firstDot, secondDot = mine.dots[1], mine.dots[2]
    local firstTicks, secondTicks = firstDot.ticks, secondDot.ticks
    -- When indistinguishable opaque ticks coincide at 9.
    local first, second = Hit(mine, 9), Hit(mine, 9)
    -- Then both retain ownership without names or learning mutations.
    Unnamed(first, true)
    Unnamed(second, true)
    assert(firstDot.ticks == firstTicks and secondDot.ticks == secondTicks)
    assert(firstDot.next == 9 and secondDot.next == 9)
    assert(learned.period[172] == nil and learned.period[980] == nil)
end)

Check("readable periodic amounts can separate coincident identities", function()
    -- Given due same-school effects with known different tick amounts.
    local mine = New({ [1] = Dot(3, 18), [2] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 0)
    mine.amounts[1], mine.amounts[2] = { [100] = true }, { [10] = true }
    -- When the readable large tick arrives.
    local result = Hit(mine, 3, nil, nil, nil, 100)
    -- Then a clear amount margin retains the supported identity.
    assert(result.spell == 1 and not result.ambiguous)
end)

Check("coincident periodic misses use the same ambiguity policy", function()
    -- Given two same-school DoTs due at the same time.
    local mine = New({ [1] = Dot(3, 18), [2] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 0)
    -- When an owned periodic resist arrives.
    local result = Hit(mine, 3, "miss")
    -- Then its miss type and ownership survive without choosing a DoT.
    Unnamed(result, true)
    assert(result.missed and mine.dots[1].next == 3)
end)

Check("untyped owned reports cannot choose between due periodic identities",
    function()
    -- Given two known same-school effects due on the same target.
    local mine = New({ [1] = Dot(3, 18), [2] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 0)
    -- When ownership is confirmed without a typed periodic color.
    local result = mine:Hit("t", "damage", 32, 3, false, true)
    -- Then the unnamed result keeps its supported periodic type.
    Unnamed(result, true)
    assert(mine.dots[1].ticks == 0 and mine.dots[2].ticks == 0)
end)

Check("historical periodic recovery preserves identity ambiguity", function()
    -- Given equally plausible periodic casts and confirmed ownership.
    local mine = New({ [1] = Dot(3, 18), [2] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 0)
    mine.lineNow = true
    -- When historical matching evaluates their common beat.
    local result = mine:Likeliest(32, 3, "tick", "t")
    -- Then history cannot restore an arbitrary spell name.
    Unnamed(result, true)
end)

Check("GCD-separated direct misses do not select by cast order", function()
    -- Given a projectile and instant spell still awaiting an outcome.
    local facts = { damages = true, direct = true, ticks = false, school = 4 }
    local mine = New({ [1] = facts, [2] = facts })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 1.5)
    -- When an owned resist could correspond to either cast.
    local result = Hit(mine, 1.5, "miss", "direct")
    -- Then neither cast gets an arbitrary identity or spent outcome.
    Unnamed(result, false)
    assert(result.missed and mine.casts[1][1].outcomes == nil)
    assert(mine.casts[2][1].outcomes == nil)
end)

Check("matching channels with different spells remain ambiguous", function()
    -- Given player and pet channels with the same target and school.
    local facts = { damages = true, direct = true, ticks = true, school = 32 }
    local mine = New({ [1] = facts, [2] = facts })
    mine:StartChannel("player", 1, "t", 0)
    mine:StartChannel("pet", 2, "t", 0)
    -- When a confirmed report cannot identify which source channeled it.
    local result = Hit(mine, 1, nil, "direct")
    -- Then the result exposes ambiguity without naming a source or spell.
    assert(result.spell == nil and result.ambiguous)
    assert(result.who == "unknown")
end)

Check("same-creature rekey preserves a running channel", function()
    -- Given a channel on a creature whose alternate key is now known.
    local oldKey, newKey = {}, {}
    local facts = { damages = true, direct = true, ticks = true, school = 32 }
    local mine = New({ [1] = facts })
    mine:StartChannel("player", 1, oldKey, 0)
    -- When the reader proves that the keys describe the same creature.
    mine:Rekey(oldKey, newKey)
    local result = Hit(mine, 1, nil, "direct", newKey)
    -- Then the active channel retains its supported identity.
    assert(result.spell == 1 and mine.channels.you.key == newKey)
end)

Check("uncertain channel target cannot supply a spell name", function()
    -- Given an observed channel with an unresolved recipient.
    local facts = { damages = true, direct = true, ticks = true, school = 32 }
    local mine = New({ [1] = facts })
    mine:StartChannel("player", 1, nil, 0, true)
    -- When a compatible owned report arrives on a visible target.
    local result = Hit(mine, 1, nil, "direct")
    -- Then channel timing alone cannot invent its recipient.
    Unnamed(result, false)
end)

Check("a channel cannot preempt a competing same-school direct cast", function()
    -- Given an active channel and a pending spell with opaque damage.
    local facts = { damages = true, direct = true, ticks = true, school = 32 }
    local direct = { damages = true, direct = true, ticks = false, school = 32 }
    local mine = New({ [1] = facts, [2] = direct })
    mine:StartChannel("player", 1, "t", 0)
    mine:Cast("pet", 2, "t", 1.5)
    -- When an owned hit can be caused by either source.
    local result = Hit(mine, 1.7, nil, "direct")
    -- Then shared timing does not confer a channel name or individual owner.
    assert(result.who == "unknown" and result.spell == nil and result.ambiguous)
end)

Check("authoritative periods cannot be rewritten by off-beat reports", function()
    -- Given a catalogued three-second effect after its first tick.
    local mine, learned = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    assert(Hit(mine, 3).spell == 1)
    -- When an owned but off-beat report arrives one second later.
    local result = Hit(mine, 4)
    -- Then it stays unnamed and does not retime or teach the effect.
    assert(result.who == "you" and result.spell == nil)
    assert(mine.dots[1].period == 3 and mine.dots[1].next == 6)
    assert(learned.period[1] == nil)
end)

Check("duration applies to normal and historical periodic matching", function()
    for _, historical in ipairs({ false, true }) do
        -- Given a catalogued effect lasting 18 seconds.
        local mine = New({ [1] = Dot(3, 18) })
        mine:Cast("player", 1, "t", 0)
        for at = 3, 18, 3 do assert(Hit(mine, at).spell == 1) end
        -- When an extra report arrives at the next obsolete beat.
        local result = historical and mine:Likeliest(32, 21, "tick", "t")
            or Hit(mine, 21)
        -- Then neither matching path resurrects the expired identity.
        assert(result == nil or result.spell == nil,
            "expired effect named a tick at age 21")
    end
end)

Check("confirmed uncatalogued periodic reports retain ownership and type",
    function()
    -- Given a typed own periodic line with no known cast.
    local mine = New({})
    -- When its matching report arrives.
    local result = Hit(mine, 3)
    -- Then the amount can be presented as an owned unnamed tick.
    assert(result.who == "you" and result.spell == nil and result.tick)
end)

Check("history recovery keeps an unknown periodic interval unknown", function()
    -- Given stale direct-only learning without any authoritative spell facts.
    local mine, learned = New({})
    learned.direct[1] = 1
    mine:Cast("player", 1, "t", 0)
    -- When a confirmed first tick recovers that public cast from history.
    local result = Hit(mine, 3)
    -- Then the tracker has not invented or trusted a tick interval.
    assert(result.spell == 1 and result.tick)
    assert(mine.dots[1].period == nil and not mine.dots[1].known,
        "history recovery stored a false interval as known")
end)

Check("long catalogued offscreen effects retain blocking evidence", function()
    -- Given a catalogued effect lasting longer than ordinary cast history.
    local mine = New({ [1] = Dot(3, 36) })
    mine:Cast("player", 1, "a", 0)
    mine:Forget("a")
    -- When metadata still permits its next tick after history expires.
    mine:Tidy(33)
    -- Then its line remains unsafe to borrow until the effect expires.
    assert(mine:OffscreenTickFit("b", 32, 33),
        "cast history expiry discarded a still-active offscreen effect")
    assert(not mine:OffscreenTickFit("b", 32, 39))
end)

Check("a periodic occurrence cannot name exact or nearby duplicate reports",
    function()
    for _, duplicateAt in ipairs({ 3, 3.02 }) do
        -- Given one catalogued effect with exactly one first tick due.
        local mine, learned = New({ [1] = Dot(3, 18) })
        mine:Cast("player", 1, "t", 0)
        local first = Hit(mine, 3)
        assert(first.spell == 1)
        -- When another separately confirmed report arrives on that beat.
        local second = Hit(mine, duplicateAt)
        -- Then ownership survives without reusing the spent tick identity.
        assert(second.who == "you" and second.spell == nil and second.tick,
            "spent periodic occurrence named another report")
        assert(mine.dots[1].ticks == 1 and mine.dots[1].next == 6)
        assert(learned.period[1] == nil and learned.school[1] == nil)
        assert(mine:Likeliest(32, duplicateAt, "tick", "t") == nil)
        assert(Hit(mine, 6).spell == 1, "next actual tick lost its identity")
    end
end)

Check("historical periodic recovery spends the normal occurrence", function()
    -- Given a catalogued effect whose first tick is recovered from history.
    local mine = New({ [1] = Dot(3, 18) })
    mine:Cast("player", 1, "t", 0)
    mine.lineNow = true
    assert(mine:Likeliest(32, 3, "tick", "t").spell == 1)
    -- When the ordinary matcher sees another report from the same beat.
    local duplicate = Hit(mine, 3.02)
    -- Then both paths honor one shared periodic outcome.
    assert(duplicate.who == "you" and duplicate.spell == nil)
    assert(mine.dots[1].ticks == 0 and mine.dots[1].next == 3)
    assert(Hit(mine, 6).spell == 1)
end)

Check("periodic misses and damage share one occurrence", function()
    for _, firstKind in ipairs({ "damage", "miss" }) do
        -- Given a periodic application with one due outcome.
        local mine = New({ [1] = Dot(3, 18) })
        mine:Cast("player", 1, "t", 0)
        assert(Hit(mine, 3, firstKind).spell == 1)
        -- When another confirmed periodic outcome arrives immediately.
        local duplicate = Hit(mine, 3.02, "miss")
        -- Then a hit or miss cannot reopen the same tick opportunity.
        assert(duplicate.who == "you" and duplicate.spell == nil
            and duplicate.tick and duplicate.missed)
        assert(Hit(mine, 6).spell == 1)
    end
end)

Check("area periodic occurrences have independent target budgets", function()
    -- Given one mixed area application with proven impacts on two targets.
    local facts = Dot(3, 18)
    facts.direct, facts.area = true, true
    local mine = New({ [1] = facts })
    mine:Cast("player", 1, "a", 0)
    assert(Hit(mine, 0.01, nil, "direct", "a").spell == 1)
    assert(Hit(mine, 0.02, nil, "direct", "b").spell == 1)
    -- When each target reports its first tick and one duplicates that report.
    assert(Hit(mine, 3, nil, nil, "a").spell == 1)
    assert(Hit(mine, 3, nil, nil, "b").spell == 1)
    local duplicate = Hit(mine, 3.02, nil, nil, "b")
    -- Then each actual target gets one identity per supported occurrence.
    assert(duplicate.who == "you" and duplicate.spell == nil)
    assert(Hit(mine, 6, nil, nil, "b").spell == 1)
end)

Check("another target's channel provides blocking evidence only", function()
    -- Given a draining periodic channel on visible creature A.
    local facts = { damages = true, direct = false, ticks = true,
        school = 32, leech = true, duration = 5 }
    local mine = New({ [1] = facts })
    mine:StartChannel("player", 1, "a", 0)
    -- When the reader sees its line beside a report on another creature.
    assert(mine:OffscreenTickFit("b", 32, 1),
        "another target's channel did not block borrowing its line")
    assert(not mine:OffscreenTickFit("b", 32, 1, { a = true, b = true }),
        "a represented channel target was treated as offscreen")
    -- Then school, recipient, stop, and natural end remain authoritative.
    assert(not mine:OffscreenTickFit("a", 32, 1))
    assert(not mine:OffscreenTickFit("b", 4, 1))
    assert(not mine:OffscreenTickFit("b", 32, 5.01))
    mine:StopChannel("player", 1, 2)
    assert(mine:OffscreenTickFit("b", 32, 2))
    assert(not mine:OffscreenTickFit("b", 32, 2.01))
end)

Check("forgotten channels keep blocking until their lifecycle ends", function()
    -- Given a channel whose recipient leaves observation.
    local facts = { damages = true, direct = false, ticks = true,
        school = 32, leech = true, duration = 5 }
    local mine = New({ [1] = facts })
    mine:StartChannel("player", 1, "a", 0)
    mine:Forget("a")
    -- When its tick line can still describe the offscreen recipient.
    assert(mine:OffscreenTickFit("b", 32, 1),
        "forgotten channel lost its blocking evidence")
    assert(mine:OffscreenTickFit("b", 32, 1, { a = true, b = true }),
        "report keys revived a retired channel's target")
    assert(mine.channels.you == nil)
    -- Then no target adopts its identity, and a stop still ends its evidence.
    local result = Hit(mine, 1, nil, nil, "b")
    assert(result.spell == nil)
    mine:StopChannel("player", 1, 2)
    assert(not mine:OffscreenTickFit("b", 32, 2.01))
    mine:Tidy(3)
    assert(#mine.retiredChannels == 0)
end)

Check("uncertain channel recipients remain possible offscreen competitors",
    function()
    -- Given a damaging channel whose recipient cannot be resolved.
    local facts = { damages = true, direct = false, ticks = true,
        school = 32, duration = 5 }
    local mine = New({ [1] = facts })
    mine:StartChannel("player", 1, nil, 0, true)
    -- When an unrelated visible target reports same-school damage.
    assert(mine:OffscreenTickFit("b", 32, 1),
        "unknown channel recipient could not block unsafe ownership")
    assert(mine:OffscreenTickFit("b", 32, 1, { b = true }),
        "represented report resolved an uncertain channel recipient")
    -- Then the unknown recipient's possibility expires with the channel.
    assert(not mine:OffscreenTickFit("b", 32, 5.01))
end)

Check("rekey preserves a live DoT ledger after cast history expires", function()
    -- Given a learned rhythm whose live effect outlasts cast history.
    local facts = Dot(nil, 36)
    local mine, learned = New({ [1] = facts })
    learned.period[1] = 3
    mine:Cast("player", 1, "a", 0)
    for at = 3, 30, 3 do assert(Hit(mine, at, nil, nil, "a").spell == 1) end
    assert(Hit(mine, 33, "miss", nil, "a").spell == 1)
    assert(mine.casts[1] == nil, "cast history did not actually expire")
    -- When the same creature receives a new key before a duplicate report.
    mine:Rekey("a", "b")
    local duplicate = Hit(mine, 33.02, "miss", nil, "b")
    -- Then the still-linked cast keeps its already spent occurrence.
    assert(duplicate.who == "you" and duplicate.spell == nil,
        "rekey reopened the expired history's periodic ledger")
    assert(Hit(mine, 36, nil, nil, "b").spell == 1)
end)

Check("a rounding boundary cannot reopen a nearby periodic occurrence",
    function()
    -- Given a learned period without authoritative cast-phase metadata.
    local mine, learned = New({ [1] = Dot(nil, 18) })
    learned.period[1] = 3
    mine:Cast("player", 1, "t", 0)
    assert(Hit(mine, 4.49).spell == 1)
    -- When the next report crosses a nearest-grid rounding boundary.
    local duplicate = Hit(mine, 4.51)
    -- Then a two-hundredth-second gap is not a distinct tick opportunity.
    assert(duplicate.who == "you" and duplicate.spell == nil,
        "grid rounding reopened the same periodic occurrence")
    assert(mine.dots[1].ticks == 1 and mine.dots[1].next == 7.49)
    assert(learned.period[1] == 3)
end)

Check("unidentified confirmed mixtures spend evidence without inventing names",
    function()
    -- Given a due DoT and an overlapping direct spell of the same school.
    local direct = { damages = true, direct = true, ticks = false, school = 32 }
    local mine, learned = New({ [1] = Dot(3, 18), [2] = direct })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("player", 2, "t", 1.5)
    -- When all reports are confirmed but their kinds cannot be assigned.
    assert(type(mine.ConfirmUnidentified) == "function",
        "matcher has no confirmed unidentified outcome contract")
    local result = mine:ConfirmUnidentified("t", 32, 3)
    -- Then numbers remain owned without advancing rhythm or teaching facts.
    Unnamed(result, false)
    assert(mine.dots[1].ticks == 0 and mine.dots[1].next == 3)
    assert(learned.period[1] == nil and learned.school[1] == nil)
    assert(mine.amounts[1] == nil and mine.casts[2][1].ambiguous)
    local tickDuplicate = Hit(mine, 3.02)
    local directDuplicate = Hit(mine, 3.02, nil, "direct")
    assert(tickDuplicate.who == "you" and tickDuplicate.spell == nil)
    assert(directDuplicate.who == "you" and directDuplicate.spell == nil)
    assert(Hit(mine, 6).spell == 1, "next actual periodic opportunity was lost")
end)

Check("unidentified mixtures do not select between player and pet actors",
    function()
    -- Given compatible player and pet actions whose reports are all confirmed.
    local direct = { damages = true, direct = true, ticks = false, school = 32 }
    local mine = New({ [1] = Dot(3, 18), [2] = direct })
    mine:Cast("player", 1, "t", 0)
    mine:Cast("pet", 2, "t", 1.5)
    -- When a mixed group cannot assign amounts to the actors.
    assert(type(mine.ConfirmUnidentified) == "function")
    local result = mine:ConfirmUnidentified("t", 32, 3)
    -- Then the individual feed remains unresolved without a false spell.
    assert(result.who == "unknown" and result.spell == nil and result.ambiguous)
    local second = mine:ConfirmUnidentified("t", 32, 3)
    assert(second.who == "unknown" and second.spell == nil and second.ambiguous,
        "sequential mixed reports lost their competing actor evidence")
end)

Check("confirmed unidentified reports survive without any known spell", function()
    -- Given independently confirmed ownership without a spell candidate.
    local mine = New({})
    -- When a fully confirmed mixed group has no safe identity evidence.
    assert(type(mine.ConfirmUnidentified) == "function")
    local result = mine:ConfirmUnidentified("t", 32, 3)
    -- Then the number stays owned without introducing learned state.
    Unnamed(result, false)
    assert(next(mine.amounts) == nil and #mine.dots == 0)
end)

Check("unidentified actor evidence includes compatible channels", function()
    -- Given an untimed player DoT and a same-school pet channel.
    local channel = { damages = true, direct = true, ticks = true,
        school = 32, duration = 5 }
    local mine = New({ [1] = Dot(nil, 18), [2] = channel })
    mine:Cast("player", 1, "t", 0)
    mine:StartChannel("pet", 2, "t", 0)
    -- When mixed-kind reports cannot establish an individual actor.
    local result = mine:ConfirmUnidentified("t", 32, 3)
    -- Then DoT ranking cannot hide the competing pet channel's ownership.
    assert(result.who == "unknown" and result.spell == nil and result.ambiguous,
        "candidate ranking hid a compatible channel actor")
end)

if #failures > 0 then error(table.concat(failures, "\n")) end
print("Conservative matcher tests passed")
