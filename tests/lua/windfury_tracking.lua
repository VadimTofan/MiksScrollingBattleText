MikSBT = {}
local Tracker = dofile("Combat/WindfuryTrace.lua")
local tracker = Tracker:New()
local opaque = setmetatable({}, {
    __tostring = function() error("tracking inspected a damage amount") end,
})

-- Describe: cooldown notifications are unconfirmed diagnostic context.
-- Given a native swing with no damage, cast, or extra-attack confirmation.
local cooldownTracker = Tracker:New()
local cooldownBurst = cooldownTracker:Swing(1, "target1", 0, true)

-- When repeated updates arrive while the player's current target changes.
for index = 1, 40 do
    cooldownTracker:Cooldown(1.25, "target2", {
        spellID = 8232, baseSpellID = 8232,
        category = 0, startRecoveryCategory = 0, itemID = 123,
    })
end

-- Then retention is bounded, repeats survive, and no damage is fabricated.
assert(#cooldownBurst.cooldowns == 32)
assert(cooldownBurst.cooldownsTruncated)
assert(cooldownBurst.cooldowns[1].at == 1.25)
assert(cooldownBurst.cooldowns[1].targetContext == "target2")
assert(cooldownBurst.cooldowns[32].spellID == 8232)
local cooldownSummary = cooldownTracker:Summary(cooldownBurst)
assert(cooldownSummary.expected == 0 and cooldownSummary.estimated == 0)
assert(cooldownSummary.rawDamage == 0 and cooldownSummary.damage == 0)
assert(cooldownSummary.confirmations == 0 and #cooldownBurst.reports == 0)
assert(not cooldownTracker:NeedsAttention(cooldownBurst))
local cooldownText = cooldownTracker:ReportText()
assert(cooldownText:find("Cooldown updates are unconfirmed", 1, true))
assert(cooldownText:find("cooldowns=32 cooldownsTruncated=true", 1, true))
assert(cooldownText:find("cooldown +0.250 spellID=8232 baseSpellID=8232 " ..
    "category=0 startRecoveryCategory=0 itemID=123 targetContext=target2", 1, true))

-- Given an update outside the retained swing's three-second context window.
-- When it arrives without a new swing.
cooldownTracker:Cooldown(5, nil, { spellID = 8232 })

-- Then that unrelated update cannot create another burst or report.
assert(#cooldownTracker.bursts == 1 and #cooldownBurst.cooldowns == 32)

-- Describe: Nature and Fire reports cannot freeze a physical-proc capture.
-- Given the latest capture's two lines near a Nature cast between swings.
local magicTracker = Tracker:New()
local magicBurst = magicTracker:Swing(0, "target1", 0, true)
magicTracker:Cast(1.980, "target1", 8042, false)
magicTracker:Log({ at = 1.980, kind = "spell", source = "mine" }, "target1")
magicTracker:Log({ at = 2.121, kind = "spell", source = "mine" }, "target1")
local fire = {}
magicTracker:Report(fire, {
    at = 2.176, key = "target1", event = "damage", school = 4,
})
magicTracker:Decision(fire, { who = "other" })

-- When the candidate evidence is evaluated.
local magicSummary = magicTracker:Summary(magicBurst)

-- Then the nonphysical cast and rejected Fire hit are not Windfury evidence.
assert(magicSummary.estimated == 0, "Nature cast estimated a Windfury proc")
assert(not magicTracker:NeedsAttention(magicBurst),
    "a rejected Fire report froze the Windfury capture")

-- Given two fully accounted physical ability hits near a native swing.
local covered = magicTracker:Swing(4, "target1", 0, true)
for index = 1, 2 do
    magicTracker:Log({ at = 4.225, kind = "spell", source = "mine" }, "target1")
    local hit = {}
    magicTracker:Report(hit, {
        at = 4.225, key = "target1", event = "damage", school = 1,
    })
    magicTracker:Decision(hit, { who = "you" })
end

-- When those confirmations lack an explicit extra-attack grant.
local coveredSummary = magicTracker:Summary(covered)

-- Then the heuristic remains inspectable without claiming a missing hit.
assert(coveredSummary.estimated == 2)
assert(not magicTracker:NeedsAttention(covered),
    "accounted physical ability hits froze the capture")

-- Given an ordinary swing with an active enchant but no proc evidence.
local ordinary = tracker:Swing(10, "target1", 0, true)

-- When that swing is summarized.
local summary = tracker:Summary(ordinary)

-- Then it does not demand two extra hits from every normal attack.
assert(summary.expected == 0 and not tracker:NeedsAttention(ordinary))

-- Given one confirmed hit with only a fallback Windfury identity.
local single = tracker:Swing(12, "target1", 0, true)
tracker:Log({ at = 12, kind = "spell", source = "mine" }, "target1")
local singleRecord = {}
local singleID = tracker:Report(singleRecord, {
    at = 12.216, key = "target1", event = "damage", school = 1,
})
tracker:Decision(singleRecord, { who = "you", procSpell = 8232 })
tracker:Forward({ singleID }, "restricted")
tracker:Dispatch({ singleID }, { area = "Outgoing", alpha = 100 })

-- When the capture evaluates the candidate.
local singleSummary = tracker:Summary(single)

-- Then an estimated second hit is not presented as confirmed missing damage.
assert(singleSummary.expected == 0 and singleSummary.estimated == 2)
assert(not tracker:NeedsAttention(single), "fallback identity froze capture")

-- Given a physical ability cast between the swing and its late reports.
tracker:Cast(12.1, "target1", 17364)

-- When the diagnostic report is exported.
local castReport = tracker:ReportText()

-- Then the trigger is visible without recording hidden amounts or cast text.
assert(castReport:find("cast +0.100 spell=17364", 1, true))

-- Given two spell confirmations following an ability between native swings.
local abilityBurst = tracker:Swing(13, "target1", 0, true)
tracker:Cast(13.9, "target1", 17364, true)
tracker:Log({ at = 13.9, kind = "spell", source = "mine" }, "target1")
tracker:Log({ at = 13.9, kind = "spell", source = "mine" }, "target1")

-- When the ability's reports are absent from the capture.
local abilitySummary = tracker:Summary(abilityBurst)

-- Then late confirmations remain visible as candidate evidence.
assert(abilitySummary.expected == 0 and abilitySummary.estimated == 2)
assert(abilitySummary.confirmations == 2)
assert(not tracker:NeedsAttention(abilityBurst))

-- Given a physical report rejected despite those candidate confirmations.
local rejectedAbilityHit = {}
tracker:Report(rejectedAbilityHit, {
    at = 14.2, key = "target1", event = "damage", school = 1,
})
tracker:Decision(rejectedAbilityHit, { who = "other" })

-- When the capture checks the actual unresolved physical outcome.
local rejectedSummary = tracker:Summary(abilityBurst)

-- Then it still pauses for the original late-report failure pattern.
assert(rejectedSummary.rejectedPhysical == 1)
assert(tracker:NeedsAttention(abilityBurst))

-- Given an extra-attack notification without any surviving damage reports.
local granted = tracker:Swing(15, "target1", 0, true)
tracker:Log({ at = 15.1, kind = "extra", source = "mine" }, "target1")

-- When the granted swing is checked.
summary = tracker:Summary(granted)

-- Then zero delivered outcomes are also captured for investigation.
assert(summary.expected == 2 and tracker:NeedsAttention(granted))

-- Given a swing with two own spell confirmations and three damage reports.
local burst = tracker:Swing(20, "target1", 0, true)
local firstLine = { at = 20.1, kind = "spell", source = "mine" }
local secondLine = { at = 20.1, kind = "spell", source = "mine" }
tracker:Log(firstLine, "target1")
tracker:Log(secondLine, "target1")
local normal, first, second = { amount = opaque }, { amount = opaque },
    { amount = opaque }
local normalID = tracker:Report(normal, {
    at = 20.3, key = "target1", unit = "target", event = "damage", school = 1,
})
local firstID = tracker:Report(first, {
    at = 20.6, key = "target1", unit = "target", event = "damage", school = 1,
})
local secondID = tracker:Report(second, {
    at = 21.1, key = "target1", unit = "target", event = "damage", school = 1,
})

-- When only the first extra hit is identified and sent to animation.
tracker:Decision(normal, { who = "you", melee = true })
tracker:Decision(first, { who = "you", proc = true, procSpell = 8232 })
tracker:Decision(second, { who = "other", confirmed = false })
tracker:Candidate(second, {
    stage = "pair", pairedKey = "target2", pairAge = 0.8,
    nearby = false, delayed = false,
})
tracker:Forward({ firstID }, "restricted")
tracker:Attempt({ firstID })
tracker:Dispatch({ firstID }, { area = "Outgoing", alpha = 100 })

-- Then the missing second outcome is explicit, with a stable report ID.
summary = tracker:Summary(burst)
assert(summary.expected == 0 and summary.estimated == 2)
assert(summary.damage == 1 and summary.misses == 0)
assert(summary.normal == 1 and summary.rawDamage == 3 and summary.rejected == 1)
assert(summary.forwarded == 1 and summary.displays == 1)
assert(tracker:NeedsAttention(burst))
assert(tracker:Lookup(second).id == secondID)
assert(tracker:Lookup(second).candidates[1].pairedKey == "target2")

-- Given the same report is held and later correctly identified.
-- When its decision is updated twice and forwarded once.
tracker:Decision(second, { who = "other", held = true })
tracker:Decision(second, { who = "you", proc = true, procSpell = 8232 })
tracker:Decision(second, { who = "you", proc = true, procSpell = 8232 })
tracker:Forward({ secondID }, "restricted")
tracker:Attempt({ secondID })
tracker:Dispatch({ secondID }, { area = "Outgoing", alpha = 100 })

-- Then updates cannot invent a third attack, and the completed burst passes.
summary = tracker:Summary(burst)
assert(summary.damage == 2 and summary.normal == 1 and summary.displays == 2)
assert(not tracker:NeedsAttention(burst))

-- Given one extra hit is dodged rather than dealing damage.
local missedBurst = tracker:Swing(30, "target1", 0, true)
local hit, missed = { amount = opaque }, {}
local hitID = tracker:Report(hit, {
    at = 30.3, key = "target1", unit = "target", event = "damage", school = 1,
})
tracker:Report(missed, {
    at = 30.5, key = "target1", unit = "target", event = "miss", school = 1,
    outcome = "Dodge",
})

-- When both outcomes are identified, but only the damage is displayed.
tracker:Decision(hit, { who = "you", procSpell = 8232 })
tracker:Decision(missed, { who = "you", procSpell = 8232 })
tracker:Forward({ hitID }, "restricted")
tracker:Attempt({ hitID })
tracker:Dispatch({ hitID }, { area = "Outgoing", alpha = 100 })

-- Then two outcomes are present, with one damage hit and one failed attack.
summary = tracker:Summary(missedBurst)
assert(summary.damage == 1 and summary.misses == 1)
assert(summary.rawMisses == 1 and not tracker:NeedsAttention(missedBurst))

-- Given public amounts are combined into one batch display.
local mergedBurst = tracker:Swing(40, "target1", 0, true)
local a, b = {}, {}
local aID = tracker:Report(a, {
    at = 40.2, key = "target1", unit = "target", event = "damage", school = 1,
})
local bID = tracker:Report(b, {
    at = 40.25, key = "target1", unit = "target", event = "damage", school = 1,
})
tracker:Decision(a, { who = "you", procSpell = 8232 })
tracker:Decision(b, { who = "you", procSpell = 8232 })

-- When both IDs reach one animation dispatch.
tracker:Forward({ aID, bID }, "batch")
tracker:Attempt({ aID, bID })
tracker:Dispatch({ aID, bID }, { area = "Outgoing", alpha = 100 })

-- Then one number is explained as batching, not missing damage.
summary = tracker:Summary(mergedBurst)
assert(summary.damage == 2 and summary.displays == 1 and summary.merged)
assert(tracker:NeedsAttention(mergedBurst))

-- Given a display gate rejects a confirmed report.
local blocked = tracker:Swing(50, "target1", 0, true)
local blockedRecord = {}
local blockedID = tracker:Report(blockedRecord, {
    at = 50.2, key = "target1", unit = "target", event = "damage", school = 1,
})
tracker:Decision(blockedRecord, { who = "you", procSpell = 8232 })
tracker:Attempt({ blockedID }, "category disabled")

-- When the copyable diagnostic report is built.
local report = tracker:ReportText()

-- Then it names the gate and outcomes without exporting opaque amounts.
assert(report:find("category disabled", 1, true))
assert(report:find("Dodge", 1, true))
assert(report:find("target2", 1, true))
assert(report:find("metadata only", 1, true))
assert(tracker:Summary(blocked).displays == 0)

-- Given the target gains a nameplate between a normal hit and its proc.
tracker:Rekey("target1", "nameplate1")

-- When its next raw report is associated with a burst.
local rekeyedID = tracker:Report({}, {
    at = 50.4, key = "nameplate1", unit = "target", event = "miss", school = 1,
})

-- Then diagnostics keep it on the same target timeline.
assert(tracker.records[rekeyedID].burstID == blocked.id)

-- Given a long session with many swings and hostile reports.
-- When the configured retention bounds are exceeded.
for index = 1, 30 do
    local retained = tracker:Swing(60 + index * 4, "target1", 0, true)
    for reportIndex = 1, 40 do
        tracker:Cooldown(retained.at + 0.1, "target2", { spellID = 8232 })
        tracker:Report({}, {
            at = retained.at + 0.2, key = "target1", unit = "target",
            event = "damage", school = 1,
        })
    end
end

-- Then memory is bounded and truncation is visible rather than hidden.
assert(#tracker.bursts == 8)
local recordCount = 0
for _ in pairs(tracker.records) do recordCount = recordCount + 1 end
assert(recordCount <= 8 * 32)
local cooldownCount = 0
for _, retained in ipairs(tracker.bursts) do
    assert(#retained.cooldowns == 32 and retained.cooldownsTruncated)
    cooldownCount = cooldownCount + #retained.cooldowns
end
assert(cooldownCount == 8 * 32)
assert(tracker.bursts[#tracker.bursts].truncated)
assert(not tracker:NeedsAttention(burst), "expired burst remained eligible to freeze capture")
print("Deep Windfury timeline tests passed")
