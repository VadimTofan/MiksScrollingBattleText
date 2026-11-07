MikSBT = {}
local Tracker = dofile("Combat/WindfuryTrace.lua")
local tracker = Tracker:New()
local opaque = setmetatable({}, {
    __tostring = function() error("tracking inspected a damage amount") end,
})

-- Given an ordinary swing with an active enchant but no proc evidence.
local ordinary = tracker:Swing(10, "target1", 0, true)

-- When that swing is summarized.
local summary = tracker:Summary(ordinary)

-- Then it does not demand two extra hits from every normal attack.
assert(summary.expected == 0 and not tracker:NeedsAttention(ordinary))

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
assert(summary.expected == 2 and summary.damage == 1 and summary.misses == 0)
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
assert(summary.rawMisses == 1 and tracker:NeedsAttention(missedBurst))

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
assert(tracker.bursts[#tracker.bursts].truncated)
assert(not tracker:NeedsAttention(burst), "expired burst remained eligible to freeze capture")
print("Deep Windfury timeline tests passed")
