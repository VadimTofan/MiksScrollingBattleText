MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local secret = setmetatable({}, {
    __add = function() error("summed hidden damage") end,
    __le = function() error("compared hidden damage") end,
    __tostring = function() error("read hidden damage") end,
})
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

        -- Then rendering keeps the exact amount without an invented icon.
        assert(queued[1] == nil and queued[2] == amount and queued[3])
        assert(queued[4] == nil,
            "owned unnamed damage must display without an icon")
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
    assert(queued[4] == nil,
        "candidate grouping must not invent a spell icon")
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

-- Describe: ambiguity suppresses even supplied spell IDs and source icons.
for _, amount in ipairs({ 30, secret }) do
    -- Given a possible spell whose identity remains ambiguous.
    local result = { who = "you", ambiguous = true, spell = 101,
        procSpell = 8232, procCandidate = true, candidateSpell = 8232 }

    -- When a source also supplies an icon for that uncertain identity.
    presentation:Out({ event = "damage", amount = amount, school = 1,
        icon = "uncertain-source-icon", result = result })

    -- Then only the original amount reaches presentation.
    assert(queued[1] == nil and queued[2] == amount and queued[4] == nil,
        "ambiguous damage retained a spell identity or icon")
end

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

-- Then a source icon cannot identify an otherwise unknown spell.
assert(queued[1] == nil and queued[4] == nil,
    "unknown spell retained a source icon")

-- Given an unnamed periodic hit or pet hit with a candidate hint.
for _, result in ipairs({
    { who = "you", tick = true, procCandidate = true, candidateSpell = 8232 },
    { who = "pet", procCandidate = true, candidateSpell = 8232 },
}) do
    -- When it reaches presentation.
    presentation:Out({ event = "damage", amount = 28, school = 1,
        result = result })

    -- Then unknown periodic and pet spell damage also has no icon.
    assert(queued[1] == nil and queued[4] == nil)
end

-- Given the client has not supplied the Windfury icon.
presentation.config.getSpellTexture = function() return nil end

-- When a candidate is displayed before the icon is available.
presentation:Out({ event = "damage", amount = 40, school = 1,
    result = { who = "you", procCandidate = true, candidateSpell = 8232 } })

-- Then rendering remains available without inventing an icon or name.
assert(queued[1] == nil and queued[4] == nil)

-- Given an identified spell with an explicit source icon.
-- When that spell reaches presentation.
presentation:Out({ event = "damage", amount = 51, icon = "known-source-icon",
    result = { who = "you", spell = 101 } })

-- Then its authoritative identity and explicit icon stay intact.
assert(queued[1] == 101 and queued[4] == "known-source-icon")
-- Describe: inferred icons decorate output without inventing spell identity.
local trialProfile = { inferredWindfuryIcons = true }
MikSBT.Compatibility = { Client = { isForever = true } }
presentation.config.getProfile = function() return trialProfile end
presentation.config.getSpellTexture = function(id) return "icon-" .. id end
for _, amount in ipairs({ 42, secret }) do
    -- Given an owned physical extra accepted by the opt-in inference stage.
    local result = { who = "you", procCandidate = true, candidateSpell = 8232 }
    local record = { event = "damage", amount = amount, school = 1,
        result = result, inferredWindfuryIcon = 8232,
        windfuryInferenceGroup = "wf:clean-frame" }

    -- When it reaches presentation with the trial enabled.
    presentation:Out(record)

    -- Then only icon/group metadata changes; identity and amount stay intact.
    assert(queued[1] == nil and queued[2] == amount)
    assert(queued[4] == "icon-8232", "accepted inferred WF icon was removed")
    local groupIndex = amount == secret and 11 or 12
    assert(queued[groupIndex] == "wf:clean-frame")
    assert(result.spell == nil and result.procSpell == nil)

    -- When the same stale marker reaches a disabled profile.
    trialProfile.inferredWindfuryIcons = false
    presentation:Out(record)

    -- Then the ordinary number-only output remains the default.
    assert(queued[1] == nil and queued[4] == nil)
    trialProfile.inferredWindfuryIcons = true
end
print("Ownership presentation tests passed")
