-- Describe: observed swing accounting never supplies ownership or identity.
MikSBT = {}
dofile("API/RestrictedValue.lua")
local file = io.open("Combat/SwingAccounting.lua", "r")
assert(file, "swing accounting diagnostic module is missing")
file:close()
dofile("Combat/SwingAccounting.lua")
local Accounting = MikSBT.SwingAccounting
assert(Accounting and Accounting.New, "swing accounting API is missing")

local failures = {}
local function Check(name, test)
    local ok, message = pcall(test)
    if not ok then failures[#failures + 1] = name .. ": " .. message end
end
local function Evidence(at)
    return { at = at, source = "mine", kind = "spell" }
end
local function Physical(id, at, sourceAt, key)
    return { id = id, at = at, key = key or "target1", who = "you",
        event = "damage", school = 1, confirmed = true,
        restrict = "direct", evidence = Evidence(sourceAt) }
end
local function Normal(ledger, id, sourceAt, at, hand, key)
    key = key or "target1"
    local outcome = Physical(id, at, sourceAt, key)
    outcome.melee = true
    outcome.receipt = { kind = "swing", at = sourceAt, key = key,
        hand = hand or "main" }
    ledger:Outcome(outcome)
end
local function First(ledger)
    local summary = ledger:Summaries()[1]
    assert(summary, "source frame was lost")
    return summary
end

Check("late normal receipt leaves two Weapon candidate outcomes", function()
    -- Given one actual main-hand swing and a Weapon signal.
    local ledger = Accounting:New()
    ledger:Swing({ at = 10, key = "target1", hand = "main" })
    ledger:Signal({ at = 10, spell = 439440 })

    -- When both extra reports precede the already-matched normal report.
    ledger:Outcome(Physical(1, 10.245, 10))
    ledger:Outcome(Physical(2, 10.587, 10))
    Normal(ledger, 3, 10, 11.002)

    -- Then arrival order does not spend normal capacity on an extra.
    local row = First(ledger)
    assert(row.normalObserved == 1 and row.normalMatched == 1)
    assert(row.ownedPhysicalExtras == 2 and row.weaponSignals == 1)
    assert(row.weaponCapacity == 2 and row.totemCapacity == 0)
    assert(row.verdict == "candidate" and row.reason == "weapon-policy")
    assert(table.concat(ledger:Rows(), "\n"):find("candidate", 1, true))
end)

Check("Stormstrike and normal each retain their spent reservation", function()
    -- Given one native swing and one observed Stormstrike cast.
    local ledger = Accounting:New()
    ledger:Swing({ at = 20, key = "target1", hand = "main" })
    ledger:Cast({ at = 20, key = "target1", spell = 17364,
        guid = "Cast-1", count = 1, uncertain = false })

    -- When their receipts identify both actual outcomes.
    Normal(ledger, 1, 20, 20.6)
    local strike = Physical(2, 20.35, 20)
    strike.spell = 17364
    strike.receipt = { kind = "cast", at = 20, key = "target1",
        spell = 17364, ordinal = 1, who = "you" }
    ledger:Outcome(strike)

    -- Then no additional physical outcome is invented.
    local row = First(ledger)
    assert(row.normalMatched == 1 and row.ssReserved == 1)
    assert(row.ssMatched == 1 and row.ownedPhysicalExtras == 0)
    assert(row.verdict == "none")
end)

Check("Totem supports one candidate while combined sources stay ambiguous", function()
    for _, combined in ipairs({ false, true }) do
        -- Given a Totem signal, optionally with a Weapon signal.
        local ledger = Accounting:New()
        ledger:Swing({ at = 30, key = "target1", hand = "main" })
        ledger:Signal({ at = 30, spell = 10610 })
        if combined then ledger:Signal({ at = 30, spell = 439440 }) end

        -- When one normal and one confirmed residual arrive.
        Normal(ledger, 1, 30, 30.5)
        ledger:Outcome(Physical(2, 30.8, 30))

        -- Then capacities are hypotheses and source identity is not chosen.
        local row = First(ledger)
        assert(row.totemCapacity == 1 and row.ownedPhysicalExtras == 1)
        assert(row.verdict == "candidate")
        assert(row.reason == (combined and "weapon-totem-ambiguous"
            or "totem-policy"))
    end
end)

Check("unknown physical cannot become a third combined-source extra", function()
    -- Given Weapon and Totem observations in one actual source frame.
    local ledger = Accounting:New()
    ledger:Swing({ at = 40, key = "target1", hand = "main" })
    ledger:Signal({ at = 40, spell = 439440 })
    ledger:Signal({ at = 40, spell = 10610 })

    -- When two own residuals and a third unknown report arrive.
    Normal(ledger, 1, 40, 40.56)
    ledger:Outcome(Physical(2, 40.35, 40))
    ledger:Outcome(Physical(3, 40.935, 40))
    local unknown = Physical(4, 41.352, 40)
    unknown.who = "unknown"
    ledger:Outcome(unknown)

    -- Then the unknown report remains outside the owned residual count.
    local row = First(ledger)
    assert(row.ownedPhysicalExtras == 2 and row.unownedPhysical == 1)
    assert(row.weaponCapacity == 2 and row.totemCapacity == 1)
    assert(unknown.who == "unknown" and unknown.spell == nil)
end)

Check("bleed application tick and immune are excluded", function()
    -- Given a swing with one normal report and a Weapon signal.
    local ledger = Accounting:New()
    ledger:Swing({ at = 50, key = "target1", hand = "main" })
    ledger:Signal({ at = 50, spell = 439440 })
    Normal(ledger, 1, 50, 50.5)

    -- When bleed-only application, tick, immune, and fire reports follow.
    for id = 2, 4 do
        local outcome = Physical(id, 50 + id * 0.2, 50)
        outcome.spell, outcome.periodicOnly = 21949, true
        outcome.tick = id == 3
        if id == 4 then outcome.event = "miss" end
        ledger:Outcome(outcome)
    end
    local fire = Physical(5, 50.149, 50)
    fire.school, fire.spell = 4, 8026
    ledger:Outcome(fire)

    -- Then excluded reports do not become physical extras.
    local row = First(ledger)
    assert(row.excludedPeriodic == 3 and row.excludedKnown == 1)
    assert(row.ownedPhysicalExtras == 0 and row.verdict == "none")
end)

Check("missing normal and surplus reports remain unresolved", function()
    -- Given one observed normal reservation and a Weapon capacity hint.
    local ledger = Accounting:New()
    ledger:Swing({ at = 60, key = "target1", hand = "main" })
    ledger:Signal({ at = 60, spell = 439440 })

    -- When a confirmed physical residual arrives without a normal receipt.
    ledger:Outcome(Physical(1, 60.2, 60))

    -- Then the missing ordinary outcome prevents a resolved candidate.
    local row = First(ledger)
    assert(row.normalUnresolved == 1 and row.verdict == "unresolved")
    assert(row.reason == "missing-reservation-outcome")

    -- When normal arrives and three residuals exceed the Weapon hint.
    Normal(ledger, 2, 60, 61)
    ledger:Outcome(Physical(3, 61.1, 60))
    ledger:Outcome(Physical(4, 61.2, 60))

    -- Then surplus observations stay explicit without a guessed assignment.
    row = First(ledger)
    assert(row.ownedPhysicalExtras == 3 and row.verdict == "unresolved")
    assert(row.reason == "capacity-exceeded")
end)

Check("signals alone and fire-only swings never imply physical damage", function()
    -- Given cooldown observations without an actual source event.
    local ledger = Accounting:New()
    ledger:Signal({ at = 70, spell = 439440 })

    -- When no report is observed.
    local orphan = First(ledger)

    -- Then the signal stays unlinked rather than creating a swing.
    assert(orphan.normalObserved == 0 and orphan.physicalObserved == 0)
    assert(orphan.reason == "no-source-frame")

    -- When a real swing has only a confirmed nonphysical spell report.
    ledger:Reset()
    ledger:Swing({ at = 71, key = "target1", hand = "main" })
    ledger:Signal({ at = 71, spell = 439440 })
    local fire = Physical(1, 71.149, 71)
    fire.school, fire.spell = 4, 8026
    ledger:Outcome(fire)

    -- Then missing physical reports stay zero, including the normal report.
    local row = First(ledger)
    assert(row.physicalObserved == 0 and row.ownedPhysicalExtras == 0)
    assert(row.normalMatched == 0 and row.normalUnresolved == 1)
end)

Check("deduplication cannot add outcomes signals or cast capacity", function()
    -- Given repeated signals and one GUID-backed Stormstrike cast.
    local ledger = Accounting:New()
    ledger:Swing({ at = 80, key = "target1", hand = "main" })
    for _ = 1, 4 do
        ledger:Signal({ at = 80, spell = 439440 })
        ledger:Cast({ at = 80, key = "target1", spell = 17364,
            guid = "Cast-repeat", count = 1 })
    end

    -- When the same report is observed repeatedly.
    local report = Physical(1, 80.4, 80)
    for _ = 1, 4 do ledger:Outcome(report) end

    -- Then every observed identity is counted once.
    local row = First(ledger)
    assert(row.weaponSignals == 1 and row.ssReserved == 1)
    assert(row.ownedPhysicalExtras == 1 and row.physicalObserved == 1)

    -- When missing GUID casts repeat in one source frame.
    ledger:Cast({ at = 80, key = "target1", spell = 17364 })
    ledger:Cast({ at = 80, key = "target1", spell = 17364 })

    -- Then duplicate ambiguity cannot manufacture another reservation.
    row = First(ledger)
    assert(row.ssReserved == 1 and row.ambiguous > 0,
        "a GUID-less repeat invented additional Stormstrike capacity")
    assert(row.verdict == "unresolved")
end)

Check("original evidence links delayed reports instead of arrival time", function()
    -- Given two distinct native source frames on the same target.
    local ledger = Accounting:New()
    ledger:Swing({ at = 90, key = "target1", hand = "main" })
    ledger:Swing({ at = 91, key = "target1", hand = "main" })
    ledger:Signal({ at = 90, spell = 439440 })

    -- When the first frame's delayed report arrives beside the second swing.
    Normal(ledger, 1, 90, 91.1)
    ledger:Outcome(Physical(2, 91.2, 90))
    ledger:Outcome(Physical(3, 91.3, nil))

    -- Then only its exact evidence frame gets the extra.
    local rows = ledger:Summaries()
    assert(rows[1].ownedPhysicalExtras == 1)
    assert(rows[2].ownedPhysicalExtras == 0)
    assert(rows[#rows].unlinked == 1)
end)

Check("shared frame evidence does not invent individual confirmation", function()
    -- Given one source frame with a normal receipt and two pooled lines.
    local ledger = Accounting:New()
    ledger:Swing({ at = 100, key = "target1", hand = "main" })
    ledger:Signal({ at = 100, spell = 439440 })
    Normal(ledger, 1, 100, 100.5)

    -- When two residuals share the confirmed frame pool.
    for id = 2, 3 do
        local outcome = Physical(id, 100 + id * 0.2, 100)
        outcome.evidence.shared, outcome.evidence.capacity = true, 2
        ledger:Outcome(outcome)
    end

    -- Then pooled evidence is explicit while individual sources stay unknown.
    local row = First(ledger)
    assert(row.ownedPhysicalExtras == 2 and row.sharedEvidence == 2)
    assert(row.verdict == "candidate")
end)

Check("overlapping targets block signals and hand receipts stay separate", function()
    -- Given simultaneous swings at different target lifetimes.
    local ledger = Accounting:New()
    ledger:Swing({ at = 110, key = "target1", hand = "main" })
    ledger:Swing({ at = 110, key = "target2", hand = "off" })
    ledger:Signal({ at = 110, spell = 439440 })

    -- When one target has its own normal and an extra report.
    Normal(ledger, 1, 110, 110.5)
    ledger:Outcome(Physical(2, 110.8, 110))

    -- Then the global signal cannot pick the selected target.
    local row = First(ledger)
    assert(row.weaponSignals == 0 and row.sourceAmbiguous > 0)
    assert(row.verdict == "unresolved")

    -- When both hands swing in one target's actual source frame.
    ledger:Reset()
    ledger:Swing({ at = 111, key = "target1", hand = "main" })
    ledger:Swing({ at = 111, key = "target1", hand = "off" })
    Normal(ledger, 1, 111, 111.4, "main")

    -- Then matching one hand leaves the other reservation open.
    row = First(ledger)
    assert(row.normalObserved == 2 and row.normalMatched == 1)
    assert(row.normalUnresolved == 1)
end)

Check("ambiguous unknown school and false confirmations never become extras", function()
    -- Given a resolved normal report and Weapon signal.
    local ledger = Accounting:New()
    ledger:Swing({ at = 120, key = "target1", hand = "main" })
    ledger:Signal({ at = 120, spell = 439440 })
    Normal(ledger, 1, 120, 120.5)

    -- When ownership or report interpretation lacks required evidence.
    local ambiguous = Physical(2, 120.7, 120)
    ambiguous.ambiguous = true
    ledger:Outcome(ambiguous)
    local unknownSchool = Physical(3, 120.8, 120)
    unknownSchool.school = nil
    ledger:Outcome(unknownSchool)
    local unconfirmed = Physical(4, 120.9, 120)
    unconfirmed.confirmed = false
    ledger:Outcome(unconfirmed)

    -- Then positive physical source evidence is never inferred.
    local row = First(ledger)
    assert(row.ownedPhysicalExtras == 0 and row.ambiguous == 1)
    assert(row.verdict == "unresolved")
end)

Check("receipts cannot be spent twice or identify the wrong hand", function()
    -- Given two same-hand actual events with indistinguishable receipts.
    local ledger = Accounting:New()
    ledger:Swing({ at = 130, key = "target1", hand = "main" })
    ledger:Swing({ at = 130, key = "target1", hand = "main" })

    -- When one receipt has no ordinal to distinguish those reservations.
    Normal(ledger, 1, 130, 130.5)

    -- Then no arbitrary event is selected.
    local row = First(ledger)
    assert(row.normalObserved == 2 and row.normalMatched == 0)
    assert(row.ambiguous > 0)

    -- When one valid normal receipt is repeated with a distinct report ID.
    ledger:Reset()
    ledger:Swing({ at = 131, key = "target1", hand = "main" })
    Normal(ledger, 1, 131, 131.5)
    Normal(ledger, 2, 131, 131.6)

    -- Then the duplicate cannot become an extra or another normal.
    row = First(ledger)
    assert(row.normalMatched == 1 and row.ownedPhysicalExtras == 0)
    assert(row.ambiguous > 0)
end)

Check("rekey reset expiry and held-before-swing preserve bounded lifetimes", function()
    -- Given a report held before its subsequently observed swing.
    local ledger = Accounting:New()
    Normal(ledger, 1, 140, 139.8)
    ledger:Swing({ at = 140, key = "target1", hand = "main" })

    -- When public alias migration retains the same target lifetime.
    ledger:Rekey("target1", "plate1:2")

    -- Then the existing receipt follows that lifetime exactly once.
    local row = First(ledger)
    assert(row.key == "plate1:2" and row.normalMatched == 1)
    local stale = Physical(2, 143.01, 140, "plate1:2")
    ledger:Outcome(stale)
    assert(First(ledger).ownedPhysicalExtras == 0)

    -- When the capture is reset.
    ledger:Reset()

    -- Then all source history and deduplication IDs are released.
    assert(#ledger:Summaries() == 0 and #ledger:Rows() == 0)
    ledger:Swing({ at = 150, key = "target1", hand = "main" })
    Normal(ledger, 1, 150, 150.5)
    assert(First(ledger).normalMatched == 1)
end)

Check("caps bound all retained observations", function()
    -- Given more distinct observations than this diagnostic retains.
    local ledger = Accounting:New()
    for index = 1, 400 do
        ledger:Swing({ at = index * 5, key = "target" .. index,
            hand = "main" })
        ledger:Signal({ at = index * 5, spell = 439440 })
        ledger:Outcome(Physical(index, index * 5 + 0.5,
            index * 5, "target" .. index))
    end

    -- When the bounded capture is summarized.
    local summaries = ledger:Summaries()

    -- Then retained state and report length cannot grow with combat duration.
    assert(#ledger.frames <= 32 and #ledger.outcomes <= 256)
    assert(#ledger.signals <= 128 and #summaries <= 33)
end)

Check("secret controls and opaque amounts are ignored without inspection", function()
    -- Given a secret-like value that throws when used as data.
    local opaque = setmetatable({}, {
        __add = function() error("opaque arithmetic") end,
        __lt = function() error("opaque comparison") end,
        __le = function() error("opaque ordering") end,
        __tostring = function() error("opaque formatting") end,
    })
    issecretvalue = function(value) return rawequal(value, opaque) end
    local ledger = Accounting:New()

    -- When secret event metadata and unused amount/text fields are observed.
    ledger:Swing(opaque)
    ledger:Swing({ at = opaque, key = "target1", hand = "main" })
    ledger:Signal({ at = 160, spell = opaque })
    ledger:Cast({ at = 160, key = opaque, spell = 17364 })
    ledger:Outcome({ id = 1, at = 160, key = opaque })
    ledger:Swing({ at = 160, key = "target1", hand = "main" })
    local report = Physical(2, 160.5, 160)
    report.amount, report.text = opaque, opaque
    ledger:Outcome(setmetatable(report, {
        __index = function() error("read a missing metadata field") end,
    }))

    -- Then only whitelisted readable metadata contributes to the ledger.
    assert(#ledger.frames == 1 and #ledger.signals == 0)
    assert(First(ledger).ownedPhysicalExtras == 1)
    assert(not table.concat(ledger:Rows(), "\n"):find("opaque", 1, true))
    issecretvalue = nil
end)

Check("nested secret flags and secret spell IDs cannot grant evidence", function()
    -- Given a secret control value beside otherwise valid public metadata.
    local opaque = {}
    issecretvalue = function(value) return rawequal(value, opaque) end
    local ledger = Accounting:New()
    ledger:Swing({ at = 170, key = "target1", hand = "main" })
    ledger:Signal({ at = 170, spell = 439440 })
    Normal(ledger, 1, 170, 170.5)

    -- When restricted controls appear inside the receipt and source evidence.
    local secretSpell = Physical(2, 170.6, 170)
    secretSpell.spell = opaque
    ledger:Outcome(secretSpell)
    local secretReceipt = Physical(3, 170.7, 170)
    secretReceipt.receipt = { kind = "swing", at = 170, key = "target1",
        hand = "main", uncertain = opaque }
    ledger:Outcome(secretReceipt)
    local secretEvidence = Physical(4, 170.8, 170)
    secretEvidence.evidence.ambiguous = opaque
    ledger:Outcome(secretEvidence)
    local malformedFlag = Physical(5, 170.9, 170)
    malformedFlag.tick = "unreadable"
    ledger:Outcome(malformedFlag)
    ledger:Cast({ at = 170, key = "target1", spell = 17364, count = opaque })

    -- Then unreadable controls cannot add residuals or reservations.
    local row = First(ledger)
    assert(row.ownedPhysicalExtras == 0,
        "restricted metadata was converted into a physical candidate")
    assert(row.normalMatched == 1 and row.ssReserved == 0)
    assert(row.verdict == "none")
    issecretvalue = nil
end)

Check("typed periodic restriction cannot become a direct residual", function()
    -- Given a normal outcome and a Weapon signal on a real source frame.
    local ledger = Accounting:New()
    ledger:Swing({ at = 180, key = "target1", hand = "main" })
    ledger:Signal({ at = 180, spell = 439440 })
    Normal(ledger, 1, 180, 180.5)

    -- When inconsistent metadata lacks a resolved periodic/direct role.
    local outcome = Physical(2, 180.6, 180)
    outcome.restrict = "tick"
    ledger:Outcome(outcome)

    -- Then direct confirmation color cannot override the periodic restriction.
    assert(First(ledger).ownedPhysicalExtras == 0,
        "periodic restriction was counted as a direct extra")
end)

Check("a held normal receipt remains authoritative without a new line", function()
    -- Given an owned report held before the native swing was observed.
    local ledger = Accounting:New()
    ledger:Swing({ at = 190, key = "target1", hand = "main" })
    local held = Physical(1, 189.8, nil)
    held.confirmed, held.melee, held.evidence = false, true, nil
    held.receipt = { kind = "swing", at = 190, key = "target1", hand = "main" }

    -- When Mine supplies its already-spent normal receipt after the swing.
    ledger:Outcome(held)

    -- Then diagnostic matching respects the existing decision's authority.
    assert(First(ledger).normalMatched == 1)
    assert(First(ledger).ownedPhysicalExtras == 0)
end)

Check("malformed receipts remain unresolved without arithmetic on nil", function()
    -- Given an actual source frame and an otherwise confirmed own report.
    local ledger = Accounting:New()
    ledger:Swing({ at = 200, key = "target1", hand = "main" })
    local outcome = Physical(1, 200.5, 200)
    outcome.receipt = { kind = "swing", key = "target1", hand = "main" }

    -- When the receipt has no usable source time.
    ledger:Outcome(outcome)
    local row = First(ledger)

    -- Then missing metadata cannot match a reservation or become an extra.
    assert(row.normalMatched == 0 and row.ownedPhysicalExtras == 0)
    assert(row.verdict == "unresolved")
end)

Check("secret restriction cannot be erased into absent restriction", function()
    -- Given a readable source frame with its normal outcome already matched.
    local opaque = {}
    issecretvalue = function(value) return rawequal(value, opaque) end
    local ledger = Accounting:New()
    ledger:Swing({ at = 210, key = "target1", hand = "main" })
    ledger:Signal({ at = 210, spell = 439440 })
    Normal(ledger, 1, 210, 210.5)

    -- When an otherwise plausible extra has a secret restriction control.
    local outcome = Physical(2, 210.6, 210)
    outcome.restrict = opaque
    ledger:Outcome(outcome)

    -- Then the unreadable observation is rejected rather than made direct.
    local row = First(ledger)
    assert(row.ownedPhysicalExtras == 0,
        "secret restriction was erased and a candidate was granted")
    assert(#ledger.outcomes == 1 and row.verdict == "none")
    issecretvalue = nil
end)

Check("classification text controls reject unreadable or malformed values", function()
    -- Given a resolved normal report and public source evidence.
    local opaque = {}
    issecretvalue = function(value) return rawequal(value, opaque) end
    local ledger = Accounting:New()
    ledger:Swing({ at = 220, key = "target1", hand = "main" })
    Normal(ledger, 1, 220, 220.5)
    local id = 1

    -- When text controls are secret, nontext, or invalid restriction labels.
    for _, field in ipairs({ "who", "event", "restrict" }) do
        for _, value in ipairs({ opaque, 42, true, "", string.rep("x", 161) }) do
            id = id + 1
            local outcome = Physical(id, 220.6, 220)
            outcome[field] = value
            ledger:Outcome(outcome)
        end
    end
    local unknownRestriction = Physical(id + 1, 220.7, 220)
    unknownRestriction.restrict = "unrecognized"
    ledger:Outcome(unknownRestriction)

    -- Then invalid controls never survive as sanitized classification data.
    assert(#ledger.outcomes == 1,
        "malformed classification text was retained as absent metadata")
    assert(First(ledger).ownedPhysicalExtras == 0)
    issecretvalue = nil
end)

Check("cast uncertainty rejects malformed controls as certainty", function()
    -- Given each kind of unsupported uncertainty value.
    local opaque = {}
    issecretvalue = function(value) return rawequal(value, opaque) end
    for _, uncertainty in ipairs({ "malformed", 42, {}, opaque }) do
        local ledger = Accounting:New()

        -- When a known cast and its apparent receipt carry that uncertainty.
        ledger:Cast({ at = 230, key = "target1", spell = 17364,
            guid = "Cast-control", uncertain = uncertainty })
        local outcome = Physical(1, 230.1, 230)
        outcome.spell = 17364
        outcome.receipt = { kind = "cast", at = 230, key = "target1",
            spell = 17364, ordinal = 1, who = "you" }
        ledger:Outcome(outcome)

        -- Then the reservation remains ambiguous instead of becoming certain.
        local row = First(ledger)
        assert(row.ssMatched == 0 and row.ambiguous > 0,
            "malformed cast uncertainty was treated as certain")
        assert(row.verdict == "unresolved")
    end
    issecretvalue = nil
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Swing accounting tests passed")
