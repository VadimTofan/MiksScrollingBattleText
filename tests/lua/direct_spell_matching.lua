-- Describe: direct hits retain a spell only when eligible evidence separates it.
MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local failures = {}
local function Check(name, test)
    local success, failure = pcall(test)
    if not success then failures[#failures + 1] = name .. ": " .. failure end
end
local function NewTracker(facts)
    local learned = { school = {}, direct = {}, period = {} }
    local tracker = MikSBT.CombatEngine.NewMine(
        function(field, spell) return learned[field][spell] end,
        function(field, spell, value) learned[field][spell] = value end,
        function(spell) return facts[spell] end
    )
    return tracker, learned
end

Check("equally plausible spells keep confirmed damage unnamed", function()
    -- Given two Fire spells with identical damage ranges on the same target.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 90, high = 110 },
        [2] = { damages = true, direct = true, school = 4, low = 90, high = 110 },
    })
    tracker:Cast("player", 1, "target", 10)
    tracker:Cast("player", 2, "target", 10.1)
    -- When a confirmed hit could belong to either spell.
    local hit = tracker:Hit("target", "damage", 4, 10.2, false, true,
        100, false, "direct")
    -- Then ownership survives without an arbitrary spell or learning guess.
    assert(hit.who == "you" and hit.spell == nil and hit.ambiguous,
        "equally plausible spells received an arbitrary identity")
    assert(hit.guess == nil)
end)

Check("all candidates participate in the confidence margin", function()
    -- Given three fits: the best is clear of the worst but close to the second.
    for _, order in ipairs({ { 1, 2, 3 }, { 3, 2, 1 } }) do
        local tracker = NewTracker({
            [1] = { damages = true, direct = true, school = 4,
                low = 109, high = 109 },
            [2] = { damages = true, direct = true, school = 4,
                low = 104, high = 104 },
            [3] = { damages = true, direct = true, school = 4,
                low = 100, high = 100 },
        })
        for _, spell in ipairs(order) do tracker:Cast("player", spell, "t", 10) end
        -- When the same hit is processed in either insertion order.
        local hit = tracker:Hit("t", "damage", 4, 10.2, false, true,
            100, false, "direct")
        -- Then the runner-up prevents a falsely confident winner.
        assert(hit.spell == nil and hit.ambiguous,
            "candidate order hid the close runner-up")
    end
end)

Check("strong amount evidence selects a later cast", function()
    -- Given an older projectile and a more recent weak spell of the same school.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 180, high = 200 },
        [2] = { damages = true, direct = true, school = 4, low = 20, high = 25 },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 10.2)
    -- When the weak hit arrives before the projectile.
    local instant = tracker:Hit("t", "damage", 4, 10.3, false, true,
        22, false, "direct")
    local projectile = tracker:Hit("t", "damage", 4, 11, false, true,
        190, false, "direct")
    -- Then each cast is consumed by its matching hit.
    assert(instant.spell == 2 and projectile.spell == 1)
end)

Check("ownership ranking accounts for critical damage", function()
    -- Given one direct spell whose ordinary damage is about half the hit.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 50, high = 55 },
    })
    tracker:Cast("player", 1, "t", 10)
    -- When the reader ranks the hit with and without its critical flag.
    local critical = tracker:Fit("t", "damage", 4, 10.2, 100, "direct", true)
    local ordinary = tracker:Fit("t", "damage", 4, 10.2, 100, "direct", false)
    -- Then the critical report is a better fit for this cast.
    assert(critical < ordinary, "ownership ranking ignored critical damage")
end)

Check("missing amounts do not turn cast age into spell identity", function()
    -- Given overlapping same-school spells with different tooltip damage.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 20, high = 25 },
        [2] = { damages = true, direct = true, school = 4, low = 180, high = 200 },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 11)
    -- When the amount cannot be inspected.
    local hit = tracker:Hit("t", "damage", 4, 11.2, false, true,
        nil, false, "direct")
    -- Then the confirmed damage is unnamed instead of taking the oldest cast.
    assert(hit.who == "you" and hit.spell == nil and hit.ambiguous)
end)

Check("unknown-school ambiguity does not teach either spell", function()
    -- Given two spells whose descriptions and schools are unavailable.
    local tracker, learned = NewTracker({})
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 10.05)
    -- When repeated confirmed hits remain compatible with both casts.
    for _, at in ipairs({ 10.1, 10.2, 11, 12, 12.9 }) do
        local hit = tracker:Hit("t", "damage", 32, at, false, true,
            nil, false, "direct")
        assert(hit.who == "you" and hit.spell == nil and hit.ambiguous,
            "unknown-school hit was given a speculative identity")
    end
    tracker:Tidy(14)
    -- Then ambiguous hits cannot create school, direct, or period knowledge.
    assert(next(learned.school) == nil and next(learned.direct) == nil
        and next(learned.period) == nil)
    assert(next(tracker.votes) == nil)
    assert(tracker:Likeliest(32, 14, "direct", "t") == nil,
        "history fallback resurrected an ambiguous spell")
end)

Check("a fresh clear cast recovers identity after old ambiguity expires", function()
    -- Given ambiguous casts that have no readable spell facts.
    local tracker, learned = NewTracker({
        [3] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 10.1)
    tracker:Hit("t", "damage", 4, 10.2, false, true,
        nil, false, "direct")
    -- When those candidates expire and a fresh identifiable spell lands.
    tracker:Cast("player", 3, "t", 14)
    local hit = tracker:Hit("t", "damage", 4, 14.1, false, true,
        100, false, "direct")
    -- Then ambiguity does not become a permanent label-suppression state.
    assert(hit.spell == 3 and not hit.ambiguous)
    assert(next(learned.school) == nil)
end)

Check("unconfirmed unique guesses do not accumulate learned schools", function()
    -- Given one unknown spell and no confirming ownership line.
    local tracker, learned = NewTracker({})
    -- When three separate casts are each followed by an unconfirmed hit.
    for _, at in ipairs({ 10, 20, 30 }) do
        tracker:Cast("player", 1, "t", at)
        tracker:Hit("t", "damage", 4, at + 0.1, false, nil, 100, false)
    end
    -- Then repetition of a guess is insufficient to teach a persistent school.
    assert(next(learned.school) == nil,
        "unconfirmed guesses permanently taught a school")
end)

Check("a later ownership confirmation can teach a unique guess", function()
    -- Given a unique cast with no school data and a delayed confirmation.
    local tracker, learned = NewTracker({})
    tracker:Cast("player", 1, "t", 10)
    local hit = tracker:Hit("t", "damage", 4, 10.1, false, nil, 100, false)
    -- When the reader later confirms the hit belongs to the player.
    tracker:Trust(hit.guess)
    -- Then the unique identity can safely contribute its school.
    assert(hit.spell == 1 and learned.school[1] == 4)
end)

Check("repeated casts of the same spell do not compete as identities", function()
    -- Given two in-flight casts with the same spell and owner.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 1, "t", 10.2)
    -- When both hits arrive with unavailable amounts.
    local first = tracker:Hit("t", "damage", 4, 10.5, false, true,
        nil, false, "direct")
    local second = tracker:Hit("t", "damage", 4, 10.8, false, true,
        nil, false, "direct")
    tracker:Tidy(11)
    -- Then both hits retain the spell and both direct casts are consumed.
    assert(first.spell == 1 and second.spell == 1)
    assert(not first.ambiguous and not second.ambiguous)
    assert(#tracker.pending == 0)
end)

Check("harmless debuffs cannot steal delayed projectile damage", function()
    -- Given a projectile followed by a non-damaging debuff on the same target.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
        [2] = { damages = false, direct = false, ticks = false },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 10.2)
    -- When the projectile lands after the debuff cast.
    local hit = tracker:Hit("t", "damage", 4, 11, false, true,
        nil, false, "direct")
    -- Then the debuff remains ineligible for damage.
    assert(hit.spell == 1 and not hit.ambiguous)
end)

Check("a target change does not relabel later damage with the old cast", function()
    -- Given one cast directed at a different target.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "old-target", 10)
    -- When another target takes damage outside the simultaneous AoE window.
    local hit = tracker:Hit("new-target", "damage", 4, 11, false, true,
        100, false, "direct")
    -- Then the old cast's identity is not borrowed by the fallback path.
    assert(hit.spell ~= 1, "another target borrowed the pending cast identity")
end)

Check("ambiguity without ownership confirmation does not claim damage", function()
    -- Given two unknown spells and no confirmation of the damage source.
    local tracker, learned = NewTracker({})
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("player", 2, "t", 10.1)
    -- When a plausible but unconfirmed hit arrives.
    local hit = tracker:Hit("t", "damage", 4, 10.2, false, nil,
        100, false, "direct")
    -- Then no player spell or ownership is invented.
    assert(hit.who == "other" and hit.spell == nil)
    assert(next(learned.school) == nil)
end)

Check("mixed player and pet candidates do not invent a caster", function()
    -- Given indistinguishable player and pet casts.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
        [2] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "t", 10)
    tracker:Cast("pet", 2, "t", 10)
    -- When neither the amount nor timing distinguishes their identities.
    local hit = tracker:Hit("t", "damage", 4, 10.2, true, true,
        nil, false, "direct")
    -- Then the generic result does not falsely pick the player or pet.
    assert(hit.who == "other" and hit.spell == nil and hit.ambiguous)
end)

Check("untargeted area casts obey the same ambiguity rule", function()
    -- Given two simultaneous area spells with equal known damage.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 100, high = 100 },
        [2] = { damages = true, direct = true, school = 4, low = 100, high = 100 },
    })
    tracker:Cast("player", 1, nil, 10)
    tracker:Cast("player", 2, nil, 10)
    -- When a nearby enemy takes confirmed damage in the area-impact window.
    local hit = tracker:Hit("nearby", "damage", 4, 10.01, false, true,
        100, false, "direct")
    -- Then history cannot bypass the confidence rule with an arbitrary name.
    assert(hit.who == "you" and hit.spell == nil and hit.ambiguous,
        "area fallback bypassed the direct-match confidence rule")
end)

Check("area fallback considers readable damage evidence", function()
    -- Given two untargeted spells with clearly different direct damage.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4, low = 180, high = 200 },
        [2] = { damages = true, direct = true, school = 4, low = 20, high = 25 },
    })
    tracker:Cast("player", 1, nil, 10)
    tracker:Cast("player", 2, nil, 10)
    -- When the weak spell hits an enemy in the same frame.
    local hit = tracker:Hit("nearby", "damage", 4, 10.01, false, true,
        22, false, "direct")
    -- Then the fallback selects the same winner as targeted direct matching.
    assert(hit.spell == 2 and not hit.ambiguous,
        "area fallback ignored decisive damage evidence")
end)

Check("cast history follows a target key change", function()
    -- Given a cast at a target whose nameplate key changes before impact.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "old-key", 10)
    -- When the reader migrates that target's tracking key.
    tracker:Rekey("old-key", "new-key")
    local hit = tracker:Likeliest(4, 11, "direct", "new-key")
    -- Then history still belongs to the same target under its new key.
    assert(hit and hit.spell == 1, "cast history retained a stale target key")
end)

Check("forgotten target keys cannot lend direct spell identities", function()
    -- Given a target that disappears before its cast is matched.
    local tracker = NewTracker({
        [1] = { damages = true, direct = true, school = 4 },
    })
    tracker:Cast("player", 1, "old-key", 10)
    -- When the reader forgets the target and its token is later reused.
    tracker:Forget("old-key")
    local hit = tracker:Likeliest(4, 11, "direct", "old-key")
    -- Then the history cannot attach the old spell to the reused token.
    assert(hit == nil, "forgotten target history identified a later direct hit")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Direct spell matching tests passed")
