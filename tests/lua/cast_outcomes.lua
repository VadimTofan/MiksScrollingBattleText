-- Describe: direct outcomes are shared by normal and historical matching.
MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local failures = {}
local function Check(name, run)
    local ok, message = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. message end
end
local function New(facts)
    return ns.NewMine(nil, nil, function(id) return facts[id] end)
end
local function Direct(window)
    return { damages = true, direct = true, ticks = false,
        school = 1, window = window }
end
local function Hit(mine, key, at, kind, line)
    return mine:Hit(key, kind or "damage", 1, at, false,
        line ~= false, nil, false, "direct", nil, "MISS")
end

Check("a direct cast cannot name additional confirmed reports", function()
    -- Given one single-target strike.
    local mine = New({ [17364] = Direct(1.5) })
    mine:Cast("player", 17364, "t", 10)
    -- When several confirmed reports follow its impact.
    assert(Hit(mine, "t", 10.01).spell == 17364)
    for _, at in ipairs({ 10.02, 10.1, 10.5, 11, 14 }) do
        local result = Hit(mine, "t", at)
        -- Then ownership survives but the spent spell does not.
        assert(result.who == "you" and result.spell == nil,
            "spent strike named or lost confirmed report at " .. at)
    end
end)

Check("historical impact spends the ordinary pending outcome", function()
    -- Given a spell whose impact is recovered from cast history.
    local mine = New({ [1] = Direct() })
    mine:Cast("player", 1, "t", 10)
    -- When history resolves its impact before the ordinary matcher.
    assert(mine:Likeliest(1, 10.5, "direct", "t").spell == 1)
    local result = Hit(mine, "t", 10.6)
    -- Then both paths share one spent outcome.
    assert(result.spell == nil and result.who == "you")
end)

Check("damage and avoidance spend the same direct outcome", function()
    for _, firstKind in ipairs({ "damage", "miss" }) do
        -- Given one cast that can hit or miss.
        local mine = New({ [1] = Direct() })
        mine:Cast("player", 1, "t", 10)
        -- When a hit or miss is followed by another confirmed miss.
        assert(Hit(mine, "t", 10.1, firstKind).spell == 1)
        local result = Hit(mine, "t", 10.2, "miss")
        -- Then the second outcome does not reuse the spell.
        assert(result.spell == nil and result.who == "you")
    end
end)

Check("metadata window applies to fits flight and history", function()
    -- Given a short-window spell and a legacy projectile.
    local mine = New({ [1] = Direct(0.2), [2] = Direct() })
    mine:Cast("player", 1, "t", 10)
    -- When the spell's window has ended.
    assert(mine:Fit("t", "damage", 1, 10.5, nil, "direct") == nil)
    assert(not mine:InFlight("t", 1, 10.5))
    assert(mine:Likeliest(1, 10.5, "direct", "t") == nil)
    assert(Hit(mine, "t", 10.5, "miss").spell == nil)
    mine:Cast("player", 2, "t", 20)
    -- Then legacy unknown-tooltip timing is retained.
    assert(Hit(mine, "t", 22.5).spell == 2)
end)

Check("area impacts keep separate target outcomes", function()
    -- Given one legacy area impact with no multiplicity metadata.
    local mine = New({ [1] = Direct() })
    mine:Cast("player", 1, "a", 10)
    -- When its simultaneous impacts arrive on distinct targets.
    assert(Hit(mine, "a", 10.01).spell == 1)
    assert(Hit(mine, "b", 10.02).spell == 1)
    -- Then a repeated impact on either target does not reopen the cast.
    assert(Hit(mine, "a", 10.03).spell == nil)
    assert(Hit(mine, "b", 10.04).spell == nil)
end)

Check("explicit multi-hit metadata permits only its supported components", function()
    -- Given a two-component strike.
    local facts = Direct()
    facts.directHits = 2
    local mine = New({ [1] = facts })
    mine:Cast("player", 1, "t", 10)
    -- When both components and an unrelated third report arrive.
    assert(Hit(mine, "t", 10.1).spell == 1)
    assert(Hit(mine, "t", 10.3).spell == 1)
    -- Then the third report remains unnamed.
    assert(Hit(mine, "t", 10.4).spell == nil)
end)

Check("spent direct impact preserves a mixed spell's ticks", function()
    -- Given a spell with a direct impact and periodic damage.
    local mine = New({ [1] = { damages = true, direct = true,
        ticks = true, school = 1, period = 2 } })
    mine:Cast("player", 1, "t", 10)
    -- When its direct impact is followed by a confirmed tick.
    assert(Hit(mine, "t", 10.1).spell == 1)
    local tick = mine:Hit("t", "damage", 1, 12, false, true,
        nil, false, "tick")
    -- Then the tick retains its own identity.
    assert(tick.spell == 1 and tick.tick)
end)

Check("unknown spell history cannot invent periodic damage", function()
    -- Given a spell with unavailable metadata that already hit.
    local mine = New({})
    mine:Cast("player", 1, "t", 10)
    assert(Hit(mine, "t", 10.1).spell == 1)
    -- When later confirmed direct reports arrive.
    for _, at in ipairs({ 11, 14, 20 }) do
        local result = Hit(mine, "t", at)
        -- Then elapsed time cannot invent ticks or reuse the direct identity.
        assert(result.spell == nil and result.who == "you")
    end
end)

Check("missing ownership evidence remains unknown", function()
    -- Given no known casts, swings, or confirmation.
    local mine = New({})
    -- When an unmatched report is observed.
    local result = mine:Hit("t", "damage", 1, 10, false, false)
    -- Then the engine does not claim another actor is known.
    assert(result.who == "unknown" and result.spell == nil)
end)

Check("failed application cannot recover periodic damage from history", function()
    -- Given a spell whose application was resisted.
    local mine = New({ [1] = { damages = true, direct = true,
        ticks = true, school = 1, period = 2 } })
    mine:Cast("player", 1, "t", 10)
    assert(Hit(mine, "t", 10.1, "miss").spell == 1)
    -- When an unrelated confirmed periodic report arrives.
    local tick = mine:Hit("t", "damage", 1, 12, false, true,
        nil, false, "tick")
    -- Then the failed application does not restart its DoT.
    assert(tick.who == "you" and tick.spell == nil)
end)

Check("outcomes follow target identity changes", function()
    -- Given a consumed impact on a target whose plate disappears.
    local mine = New({ [1] = Direct() })
    mine:Cast("player", 1, "plate", 10)
    assert(Hit(mine, "plate", 10.01).spell == 1)
    -- When the target migrates to its target key in the area-impact frame.
    mine:Rekey("plate", "target")
    local result = Hit(mine, "target", 10.02)
    -- Then a new token does not reopen the same target's impact.
    assert(result.who == "you" and result.spell == nil)
end)

Check("same spell casts retain independent outcomes", function()
    -- Given two identical spells in flight.
    local mine = New({ [1] = Direct() })
    mine:Cast("player", 1, "t", 10)
    mine:Cast("player", 1, "t", 10.2)
    -- When two impacts and an additional confirmed report arrive.
    assert(Hit(mine, "t", 10.5).spell == 1)
    assert(Hit(mine, "t", 10.7).spell == 1)
    -- Then each cast spends its own outcome exactly once.
    assert(Hit(mine, "t", 10.8).spell == nil)
end)

Check("one missed area target cannot invalidate another target", function()
    -- Given a mixed area spell whose application failed on one enemy.
    local mine = New({ [1] = { damages = true, direct = true,
        ticks = true, school = 1, period = 2, area = true } })
    mine:Cast("player", 1, "a", 10)
    assert(Hit(mine, "b", 10.01, "miss").spell == 1)
    -- When another target takes the impact and subsequent periodic damage.
    assert(Hit(mine, "c", 10.02).spell == 1)
    local tick = mine:Likeliest(1, 12, "tick", "c")
    -- Then only the failed target is barred from periodic recovery.
    assert(tick and tick.spell == 1 and tick.tick)
    assert(mine:Likeliest(1, 12, "tick", "b") == nil)
end)

Check("one missed component preserves historical matching of the next", function()
    -- Given a two-component attack whose first component missed.
    local facts = Direct()
    facts.directHits = 2
    local mine = New({ [1] = facts })
    mine:Cast("player", 1, "t", 10)
    assert(Hit(mine, "t", 10.1, "miss").spell == 1)
    -- When the next component is identified from history.
    local result = mine:Likeliest(1, 10.3, "direct", "t")
    -- Then the unspent outcome remains available through every direct path.
    assert(result and result.spell == 1)
    assert(mine:Likeliest(1, 10.4, "direct", "t") == nil)
end)

Check("verified area impacts use the same fit and history window", function()
    -- Given an area spell with a metadata impact window.
    local facts = Direct(1.5)
    facts.area = true
    local mine = New({ [1] = facts })
    mine:Cast("player", 1, "a", 10)
    -- When another target is struck after the legacy simultaneous window.
    local fit = mine:Fit("b", "damage", 1, 10.5, nil, "direct")
    local result = mine:Likeliest(1, 10.5, "direct", "b")
    -- Then ownership ranking and identity use the same eligible impact.
    assert(fit ~= nil and result and result.spell == 1)
end)

Check("an impossible shot parry cannot become owned by fallback", function()
    for _, restrict in ipairs({ "shot", "untyped" }) do
        -- Given an unused ranged shot and a line that cannot explain a parry.
        local mine = New({})
        mine:Swing("ranged", "t", 10)
        local source = restrict == "shot" and "shot" or nil
        -- When a confirmed-looking parry report is attributed.
        local result = mine:Hit("t", "miss", 1, 10.4, false, true,
            nil, false, source, nil, "PARRY")
        -- Then contradictory evidence leaves ownership and the shot unresolved.
        assert(result.who == "unknown" and not mine.swings[1].used)
    end
end)

Check("an untyped invalid miss differs from an owned spell miss", function()
    -- Given a cast whose known reach cannot explain a dodge.
    local previous = ns.SpellCanAvoid
    ns.SpellCanAvoid = function() return false end
    local mine = New({ [1] = Direct() })
    mine:Cast("player", 1, "t", 10)
    -- When untyped and explicitly owned direct-miss confirmations arrive.
    local unsure = mine:Hit("t", "miss", 1, 10.3, false, true,
        nil, false, nil, nil, "DODGE")
    local owned = New({}):Hit("t", "miss", 1, 10.4, false, true,
        nil, false, "direct", nil, "DODGE")
    ns.SpellCanAvoid = previous
    -- Then only the typed confirmation establishes ownership without identity.
    assert(unsure.who == "unknown" and unsure.spell == nil)
    assert(owned.who == "you" and owned.spell == nil and owned.missed)
end)

Check("a resisted periodic-only application cannot identify later ticks", function()
    -- Given a periodic-only spell whose application was resisted.
    local mine = New({ [1] = { damages = true, direct = false,
        ticks = true, school = 32, period = 2 } })
    mine:Cast("player", 1, "t", 10)
    local missed = mine:Hit("t", "miss", 1, 10.1, false, true,
        nil, false, "direct", nil, "RESIST")
    assert(missed.spell == 1 and missed.missed)
    -- When confirmed and unconfirmed periodic reports follow the failed cast.
    local confirmed = mine:Hit("t", "damage", 32, 12, false, true,
        nil, false, "tick")
    local unknown = mine:Hit("t", "damage", 32, 14, false, false,
        nil, false, "tick")
    -- Then ownership survives only its confirmation, without the failed ID.
    assert(confirmed.who == "you" and confirmed.spell == nil)
    assert(unknown.who == "unknown" and unknown.spell == nil)
end)

-- Describe: confirmed periodic applications do not compete as fresh misses.
Check("a confirmed bleed tick leaves the later miss to Stormstrike", function()
    -- Given a periodic-only bleed with an unambiguous tick on this target.
    local mine = New({
        [21949] = { damages = true, direct = false, ticks = true,
            school = 1, duration = 7 },
        [17364] = Direct(),
    })
    mine:Cast("player", 21949, "t", 10)
    local tick = mine:Hit("t", "damage", 1, 10.761, false, true,
        nil, false, "tick")
    assert(tick.spell == 21949 and tick.tick and not tick.ambiguous)
    mine:Cast("player", 17364, "t", 11.746)

    -- When an owned direct miss accompanies that Stormstrike cast.
    local missed = Hit(mine, "t", 11.746, "miss")

    -- Then the successful bleed application cannot obscure the strike.
    assert(missed.who == "you" and missed.spell == 17364
        and missed.missed and not missed.ambiguous,
        "confirmed bleed application competed with Stormstrike's miss")
end)

Check("an ambiguous periodic reservation cannot prove application success", function()
    -- Given periodic capacity reserved without a positive named tick.
    local mine = New({
        [21949] = { damages = true, direct = false, ticks = true,
            school = 1, duration = 7 },
        [17364] = Direct(),
    })
    mine:Cast("player", 21949, "t", 10)
    local unidentified = mine:ConfirmUnidentified("t", 1, 10.761)
    local bleed = mine.casts[21949][1]
    assert(unidentified.ambiguous and unidentified.spell == nil)
    assert(bleed.periodicOutcomes.t == 10.761)
    assert(mine.dots[1].confirmedAt == nil)
    mine:Cast("player", 17364, "t", 11.746)

    -- When an owned direct miss could answer either application.
    local missed = Hit(mine, "t", 11.746, "miss")

    -- Then reserved periodic capacity cannot remove a competing identity.
    assert(missed.who == "you" and missed.spell == nil
        and missed.ambiguous and missed.missed,
        "ambiguous periodic reservation resolved a direct miss")
end)

Check("an area tick cannot confirm application success on another target", function()
    -- Given an area DoT confirmed only on its original target.
    local mine = New({
        [1] = { damages = true, direct = false, ticks = true,
            school = 1, duration = 7, area = true },
        [17364] = Direct(),
    })
    mine:Cast("player", 1, "a", 10)
    local tick = mine:Hit("a", "damage", 1, 10.761, false, true,
        nil, false, "tick")
    assert(tick.spell == 1 and tick.tick and not tick.ambiguous)
    mine:Cast("player", 17364, "b", 11.746)

    -- When a direct miss on the other target could answer either cast.
    local missed = Hit(mine, "b", 11.746, "miss")

    -- Then another target's tick cannot resolve this application outcome.
    assert(missed.who == "you" and missed.spell == nil
        and missed.ambiguous and missed.missed,
        "another target's confirmed tick eliminated an application miss")
end)

Check("a mixed spell keeps its unspent direct miss after a confirmed tick", function()
    -- Given a mixed spell whose periodic component has already landed.
    local mine = New({
        [1] = { damages = true, direct = true, ticks = true,
            school = 1, duration = 7 },
        [17364] = Direct(),
    })
    mine:Cast("player", 1, "t", 10)
    local tick = mine:Hit("t", "damage", 1, 10.761, false, true,
        nil, false, "tick")
    assert(tick.spell == 1 and tick.tick and not tick.ambiguous)
    assert(mine.casts[1][1].outcomes == nil)
    mine:Cast("player", 17364, "t", 11.746)

    -- When a direct miss could still be either unspent direct component.
    local missed = Hit(mine, "t", 11.746, "miss")

    -- Then the periodic tick does not eliminate the mixed spell's direct part.
    assert(missed.who == "you" and missed.spell == nil
        and missed.ambiguous and missed.missed,
        "a mixed spell lost its unspent direct miss after ticking")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Cast outcome tests passed")
