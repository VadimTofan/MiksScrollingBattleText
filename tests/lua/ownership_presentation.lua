MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local secret = {}
issecretvalue = function(value) return value == secret end
local queued, calls = nil, 0
local function Capture(_, ...)
    queued, calls = { ... }, calls + 1
end
local presentation = Presentation:New({
    batcher = { Queue = Capture, DisplayRestricted = Capture },
    getSpellTexture = function(id) return "icon-" .. id end,
})

-- Describe: every owned nonmelee report can render without a spell identity.
for _, owner in ipairs({ "you", "pet" }) do
    for _, amount in ipairs({ 42, secret }) do
        -- Given an owned hit with no identified spell.
        local result = { who = owner }

        -- When the existing MSBT presentation receives it.
        presentation:Out({ event = "damage", amount = amount,
            crit = true, school = 1, result = result })

        -- Then rendering keeps the exact amount and uses an unnamed icon.
        assert(queued[1] == nil and queued[2] == amount and queued[3])
        assert(queued[4] == "Interface\\Icons\\INV_Misc_QuestionMark",
            "owned unnamed damage needs a generic icon")
        assert(queued[5] == true and queued[6] == (owner == "pet"))
    end
end

-- Describe: candidate grouping metadata never becomes spell identity.
for _, amount in ipairs({ 37, secret }) do
    -- Given a bounded physical proc candidate whose identity remains unknown.
    local result = { who = "you", proc = true,
        procCandidate = true, candidateSpell = 8232 }

    -- When it reaches public or restricted batching.
    presentation:Out({ event = "damage", amount = amount,
        school = 1, result = result })

    -- Then grouping metadata is separate from the absent spell ID.
    assert(queued[1] == nil and queued[2] == amount)
    assert(queued[4] == "icon-8232",
        "Windfury candidate lost its visual icon hint")
    local candidateIndex = amount == secret and 10 or 11
    assert(queued[candidateIndex] == 8232,
        "candidate grouping metadata did not reach the batcher")
end

-- Given a confirmed bleed tick with an incidental candidate hint.
-- When periodic damage reaches presentation.
presentation:Out({ event = "damage", amount = 28, school = 1,
    result = { who = "you", tick = true, spell = 21949,
        procCandidate = true, candidateSpell = 8232 } })

-- Then its identified bleed icon and spell remain intact.
assert(queued[1] == 21949 and queued[4] == "icon-21949")

-- Given an ambiguous result with a possible Windfury candidate.
-- When it reaches presentation.
presentation:Out({ event = "damage", amount = 30, school = 1,
    result = { who = "you", ambiguous = true,
        procCandidate = true, candidateSpell = 8232 } })

-- Then ambiguity retains its generic icon and absent spell identity.
assert(queued[1] == nil
    and queued[4] == "Interface\\Icons\\INV_Misc_QuestionMark")

-- Given unresolved ownership or an explicitly foreign report.
local before = calls
for _, owner in ipairs({ "unknown", "other" }) do
    -- When presentation receives it.
    presentation:Out({ event = "damage", amount = 99,
        result = { who = owner } })
end

-- Then only confirmed owned reports have reached batching.
assert(calls == before)

-- Given an owned unnamed hit with a public icon supplied by its source.
-- When the presentation adapter forwards it.
presentation:Out({ event = "damage", amount = 21, icon = "source-icon",
    result = { who = "you", procCandidate = true, candidateSpell = 8232 } })

-- Then an explicit source icon survives the unnamed fallback.
assert(queued[1] == nil and queued[4] == "source-icon",
    "unnamed fallback replaced an explicit source icon")

-- Given an unnamed periodic hit or pet hit with a candidate hint.
for _, result in ipairs({
    { who = "you", tick = true, procCandidate = true, candidateSpell = 8232 },
    { who = "pet", procCandidate = true, candidateSpell = 8232 },
}) do
    -- When it reaches presentation.
    presentation:Out({ event = "damage", amount = 28, school = 1,
        result = result })

    -- Then the hint does not overwrite periodic or pet attribution visually.
    assert(queued[1] == nil
        and queued[4] == "Interface\\Icons\\INV_Misc_QuestionMark")
end

-- Given the client has not supplied the Windfury icon.
presentation.config.getSpellTexture = function() return nil end

-- When a candidate is displayed before the icon is available.
presentation:Out({ event = "damage", amount = 40, school = 1,
    result = { who = "you", procCandidate = true, candidateSpell = 8232 } })

-- Then generic rendering remains available without inventing a name.
assert(queued[1] == nil
    and queued[4] == "Interface\\Icons\\INV_Misc_QuestionMark")
print("Ownership presentation tests passed")
