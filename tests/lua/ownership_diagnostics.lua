MikSBT = {}
local Tracker = dofile("Combat/WindfuryTrace.lua")
local tracker = Tracker:New()
local burst = tracker:Swing(10, "target1", "main", true)
local function Report(at, result)
    local record = {}
    tracker:Report(record, { at = at, key = "target1", unit = "target",
        event = "damage", school = 1 })
    tracker:Decision(record, result)
    return record
end

-- Given a confirmed owned candidate with no known spell identity.
local candidate = Report(10.5, { who = "you", proc = true,
    procCandidate = true, candidateSpell = 8232 })
local candidateID = tracker:Lookup(candidate).id

-- When its normal dispatch path completes.
tracker:Forward({ candidateID }, "restricted")
tracker:Dispatch({ candidateID }, { area = "Outgoing", alpha = 1 })
local summary = tracker:Summary(burst)

-- Then candidate accounting remains available without inventing identity.
assert(summary.damage == 1 and summary.forwarded == 1,
    "unnamed candidate disappeared from diagnostic outcomes")
assert(summary.displays == 1 and summary.estimated == 2)
assert(tracker:Lookup(candidate).procSpell == nil)

-- Given unresolved ownership, foreign ownership and a known legacy identity.
Report(10.6, { who = "unknown" })
Report(10.7, { who = "other" })
Report(10.8, { who = "you", procSpell = 8232 })

-- When diagnostic summaries and report text are generated.
summary = tracker:Summary(burst)
local text = tracker:ReportText()

-- Then unknown differs from rejected foreign damage and identity is explicit.
assert(summary.unknown == 1 and summary.rejected == 1)
assert(summary.rejectedPhysical == 1 and summary.damage == 2)
assert(text:find("unknown=1", 1, true))
assert(text:find("candidateSpell=8232", 1, true))
assert(text:find("identity=-", 1, true))
assert(text:find("identity=8232", 1, true))

-- Given two physical-trigger confirmations and an unresolved physical hit.
local unresolved = Tracker:New()
local unresolvedBurst = unresolved:Swing(20, "target1", "main", true)
for _, at in ipairs({ 20.01, 20.02 }) do
    unresolved:Log({ at = at, source = "mine", kind = "spell" }, "target1")
end
local unknown = {}
unresolved:Report(unknown, { at = 20.5, key = "target1", unit = "target",
    event = "damage", school = 1 })
unresolved:Decision(unknown, { who = "unknown" })

-- When the capture checks whether candidate outcomes need review.
local attention = unresolved:NeedsAttention(unresolvedBurst)

-- Then the physical-only diagnostic gate retains unresolved evidence.
assert(attention, "unresolved physical damage must remain reviewable")
assert(unresolved:Summary(unresolvedBurst).unknownPhysical == 1)
print("Ownership diagnostic tests passed")
