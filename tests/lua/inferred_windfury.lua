MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
local file = io.open("Combat/WindfuryInference.lua", "r")
assert(file, "production inferred Windfury runtime is missing")
file:close()
local Inference = dofile("Combat/WindfuryInference.lua")
assert(Inference == MikSBT.Components.WindfuryInference)

local opaque = setmetatable({}, { __mode = "k" })
issecretvalue = function(value) return opaque[value] == true end
local function Secret()
    local value = setmetatable({}, {
        __add = function() error("added hidden damage") end,
        __le = function() error("compared hidden damage") end,
        __lt = function() error("ordered hidden damage") end,
        __eq = function() error("compared hidden objects") end,
        __tostring = function() error("read hidden damage") end,
    })
    opaque[value] = true
    return value
end

local function Harness()
    local test = { at = 10, timers = {}, output = {}, enabled = true }
    test.runtime = Inference:New({
        after = function(delay, callback)
            test.timers[#test.timers + 1] = {
                at = test.at + delay, callback = callback,
            }
        end,
        emit = function(record)
            test.output[#test.output + 1] = record
        end,
        enabled = function() return test.enabled end,
    })
    function test:At(at)
        while true do
            local first
            for index, timer in ipairs(self.timers) do
                if timer.at <= at and (not first
                    or timer.at < self.timers[first].at) then
                    first = index
                end
            end
            if not first then break end
            local timer = table.remove(self.timers, first)
            self.at = timer.at
            timer.callback()
        end
        self.at = at
    end
    return test
end

local function Source(test, spell, key, at)
    at, key = at or test.at, key or "target1"
    test.runtime:Swing(at, key, "main")
    test.runtime:Line(at, key, "mine", "swing")
    test.runtime:Signal(at, spell or 439440)
    local count = spell == 10610 and 1 or 2
    for _ = 1, count do
        test.runtime:Line(at, key, "mine", "spell")
    end
end

local function Extra(test, sourceAt, key, shared, event)
    local record = { event = event or "damage", amount = Secret(), school = 1,
        crit = false, result = { who = "you", procCandidate = false } }
    local info = { at = test.at, key = key or "target1", confirmed = true,
        restrict = "direct", evidence = { at = sourceAt, source = "mine",
            kind = "spell", shared = shared == true,
            capacity = shared and 2 or 1 } }
    return record, info
end

local function Normal(test, sourceAt, key, hand)
    local record = { event = "damage", amount = Secret(), school = 1,
        result = { who = "you", melee = true, hand = hand or "main" } }
    local info = { at = test.at, key = key or "target1", confirmed = true,
        restrict = "swing", receipt = { kind = "swing", at = sourceAt,
            key = key or "target1", hand = hand or "main", who = "you" } }
    test.runtime:Out(record, info)
    return record
end

local function Count(test, record)
    local count = 0
    for _, emitted in ipairs(test.output) do
        if rawequal(emitted, record) then count = count + 1 end
    end
    return count
end

local failures = {}
local function Check(name, run)
    local ok, failure = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. failure end
end

-- Describe: complete frames infer icons without changing combat identity.
Check("extras arriving before normal wait for its receipt", function()
    -- Given two owned extras whose normal impact has not arrived.
    local test = Harness()
    Source(test)
    local first, firstInfo = Extra(test, 10)
    test.runtime:Out(first, firstInfo)
    test:At(10.216)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)
    assert(#test.output == 0)

    -- When the later normal impact spends its own reservation.
    test:At(10.585)
    local normal = Normal(test, 10)

    -- Then extras keep their amounts and acquire only inferred icon metadata.
    for _, record in ipairs({ first, second }) do
        assert(Count(test, record) == 1 and record.inferredWindfuryIcon == 8232)
        assert(type(record.windfuryInferenceGroup) == "string")
        assert(record.result.who == "you" and record.result.spell == nil)
        assert(record.result.procSpell == nil and record.amount ~= nil)
    end
    assert(first.windfuryInferenceGroup == second.windfuryInferenceGroup)
    assert(Count(test, normal) == 1 and normal.inferredWindfuryIcon == nil)
    test:At(20)
    assert(#test.output == 3, "stale callbacks duplicated completed output")
end)

Check("normal between extras does not release an incomplete Weapon pair", function()
    -- Given the captured +.244 first extra and +.590 normal impact.
    local test = Harness()
    Source(test)
    test:At(10.244)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)
    test:At(10.590)
    Normal(test, 10)
    assert(Count(test, first) == 0)

    -- When the remaining extra arrives near one second.
    test:At(10.992)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)

    -- Then both extras release together before the deadline.
    assert(Count(test, first) == 1 and Count(test, second) == 1)
    assert(first.inferredWindfuryIcon == 8232)
end)

Check("homogeneous shared direct confirmations retain their own capacity", function()
    -- Given two extras from one public homogeneous direct pool.
    local test = Harness()
    Source(test)
    local first, firstInfo = Extra(test, 10, nil, true)
    local second, secondInfo = Extra(test, 10, nil, true)
    test.runtime:Out(first, firstInfo)
    test.runtime:Out(second, secondInfo)

    -- When frame collection closes and the normal outcome resolves.
    test:At(10.5)
    Normal(test, 10)

    -- Then pooled ownership can decorate without inventing individual lines.
    assert(first.inferredWindfuryIcon == 8232)
    assert(second.inferredWindfuryIcon == 8232)
end)

Check("Stormstrike spends a separate direct reservation", function()
    -- Given one actual Stormstrike cast plus a normal and two extras.
    local test = Harness()
    Source(test)
    test.runtime:Cast({ at = 10, key = "target1", spell = 17364,
        guid = "Cast-1", uncertain = false })
    test.runtime:Line(10, "target1", "mine", "spell")
    test:At(10.3)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)
    Normal(test, 10)
    assert(Count(test, first) == 0)

    -- When the identified Stormstrike outcome spends its receipt.
    local strike = { event = "damage", amount = Secret(), school = 1,
        result = { who = "you", spell = 17364 } }
    test.runtime:Out(strike, { at = test.at, key = "target1", confirmed = true,
        receipt = { kind = "cast", at = 10, key = "target1",
            sourceKey = "target1", spell = 17364, ordinal = 1, who = "you" } })

    -- Then the known strike remains untouched and only residuals decorate.
    assert(first.inferredWindfuryIcon == 8232)
    assert(second.inferredWindfuryIcon == 8232)
    assert(Count(test, strike) == 1 and strike.inferredWindfuryIcon == nil)
end)

Check("a Totem source has one residual outcome", function()
    -- Given a public Totem signal and one already-owned physical extra.
    local test = Harness()
    Source(test, 10610)
    test:At(10.2)
    local extra, info = Extra(test, 10)
    test.runtime:Out(extra, info)

    -- When the normal reservation resolves.
    Normal(test, 10)

    -- Then the single Totem candidate receives the same inferred icon.
    assert(extra.inferredWindfuryIcon == 8232 and Count(test, extra) == 1)
end)

-- Describe: ambiguous source accounting keeps ordinary output intact.
Check("incomplete and surplus Weapon outcomes remain undecorated", function()
    for _, count in ipairs({ 1, 3 }) do
        -- Given a Weapon signal with fewer or more than two residuals.
        local test, extras = Harness(), {}
        Source(test)
        test:At(10.2)
        for _ = 1, count do
            local record, info = Extra(test, 10)
            extras[#extras + 1] = record
            test.runtime:Out(record, info)
        end
        if count == 1 then assert(#test.output == 0) end

        -- When normal resolves and the hard source deadline expires.
        Normal(test, 10)
        test:At(11.601)

        -- Then every extra is preserved once without a candidate icon.
        for _, record in ipairs(extras) do
            assert(Count(test, record) == 1)
            assert(record.inferredWindfuryIcon == nil)
        end
    end
end)

for _, conflict in ipairs({ "combined", "bleed", "uncertain", "foreign",
    "extra-line", "mixed-evidence", "shared-capacity", "known", "tick",
    "unknown", "pet", "ambiguous" }) do
    Check(conflict .. " cannot decorate a source", function()
        -- Given an otherwise valid source with one conflicting observation.
        local test = Harness()
        Source(test)
        if conflict == "combined" then test.runtime:Signal(10, 10610) end
        if conflict == "bleed" then
            test.runtime:Cast({ at = 10, key = "target1", spell = 21949,
                conflict = true })
        end
        if conflict == "uncertain" then
            test.runtime:Cast({ at = 10, spell = 17364, uncertain = true })
        end
        if conflict == "foreign" then
            test.runtime:Line(10, "target1", "pet", "spell")
        end
        if conflict == "extra-line" then
            test.runtime:Line(10, "target1", "mine", "spell")
        end
        test:At(10.2)
        local first, firstInfo = Extra(test, 10)
        local second, secondInfo = Extra(test, 10)
        if conflict == "mixed-evidence" then
            secondInfo.evidence.ambiguous = true
        elseif conflict == "shared-capacity" then
            firstInfo.evidence.shared, firstInfo.evidence.capacity = true, 1
            secondInfo.evidence.shared, secondInfo.evidence.capacity = true, 1
        elseif conflict == "known" then second.result.spell = 8026
        elseif conflict == "tick" then second.result.tick = true
        elseif conflict == "unknown" then second.result.who = "unknown"
        elseif conflict == "pet" then second.result.who = "pet"
        elseif conflict == "ambiguous" then second.result.ambiguous = true end

        -- When all impacts and the source deadline are observed.
        test.runtime:Out(first, firstInfo)
        test.runtime:Out(second, secondInfo)
        Normal(test, 10)
        test:At(12)

        -- Then inference never changes any record's display or ownership.
        assert(Count(test, first) == 1 and Count(test, second) == 1)
        assert(first.inferredWindfuryIcon == nil)
        assert(second.inferredWindfuryIcon == nil)
    end)
end

Check("unresolved normal cannot be substituted with extra damage", function()
    -- Given two extras but no native outcome receipt.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)

    -- When the deadline passes.
    test:At(11.601)

    -- Then both existing reports survive without creating a normal receipt.
    assert(#test.output == 2 and first.inferredWindfuryIcon == nil)
    assert(second.inferredWindfuryIcon == nil)
end)

Check("a confirmation-only parent cannot borrow a nearby native swing", function()
    -- Given a native trigger followed by a distinct Weapon confirmation frame.
    local test = Harness()
    test.runtime:Swing(10, "target1", "main")
    test.runtime:Line(10, "target1", "mine", "swing")
    test:At(10.102)
    test.runtime:Signal(test.at, 439440)
    test.runtime:Line(test.at, "target1", "mine", "spell")
    test.runtime:Line(test.at, "target1", "mine", "spell")
    local first, info = Extra(test, test.at)
    test.runtime:Out(first, info)
    local second, secondInfo = Extra(test, test.at)
    test.runtime:Out(second, secondInfo)

    -- When the nearby native outcome resolves and all timers expire.
    test:At(10.590)
    Normal(test, 10)
    test:At(12)

    -- Then source frames stay distinct and neither extra gains an icon.
    assert(Count(test, first) == 1 and Count(test, second) == 1)
    assert(first.inferredWindfuryIcon == nil)
    assert(second.inferredWindfuryIcon == nil)
end)

Check("one global signal cannot decorate two target lifetimes", function()
    -- Given same-frame native sources for two distinct lifetime keys.
    local test = Harness()
    Source(test, 439440, "target1")
    Source(test, 439440, "target2")
    test:At(10.2)
    local records = {}
    for _, key in ipairs({ "target1", "target2" }) do
        for _ = 1, 2 do
            local record, info = Extra(test, 10, key)
            records[#records + 1] = record
            test.runtime:Out(record, info)
        end
        Normal(test, 10, key)
    end

    -- When the complete but competing sources expire.
    test:At(12)

    -- Then every report survives once and the global signal remains ambiguous.
    for _, record in ipairs(records) do
        assert(Count(test, record) == 1 and record.inferredWindfuryIcon == nil)
    end
end)

Check("misses consume capacity without receiving a damage icon", function()
    -- Given one extra damage and one independently confirmed extra miss.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local damage, info = Extra(test, 10)
    local miss, missInfo = Extra(test, 10, nil, false, "miss")
    missInfo.evidence.kind = "spellMiss"
    test.runtime:Out(damage, info)
    test.runtime:Out(miss, missInfo)

    -- When the normal outcome completes the source.
    Normal(test, 10)

    -- Then only damage is decorated and both records are forwarded once.
    assert(damage.inferredWindfuryIcon == 8232)
    assert(miss.inferredWindfuryIcon == nil)
    assert(Count(test, damage) == 1 and Count(test, miss) == 1)
end)

-- Describe: lifecycle and restricted controls fail closed without losing output.
Check("secret controls never inspect hidden values", function()
    for _, field in ipairs({ "school", "who", "confirmed", "key", "at",
        "evidence", "crit", "capacity" }) do
        -- Given an opaque control alongside ordinary opaque damage.
        local test = Harness()
        Source(test)
        test:At(10.2)
        local first, info = Extra(test, 10)
        local second, secondInfo = Extra(test, 10)
        if field == "school" or field == "crit" then
            second[field] = Secret()
        elseif field == "who" then second.result.who = Secret()
        elseif field == "capacity" then secondInfo.evidence.capacity = Secret()
        else secondInfo[field] = Secret() end

        -- When the source resolves or expires.
        test.runtime:Out(first, info)
        test.runtime:Out(second, secondInfo)
        Normal(test, 10)
        test:At(12)

        -- Then its original records survive once without inferred decoration.
        assert(Count(test, first) == 1 and Count(test, second) == 1)
        assert(first.inferredWindfuryIcon == nil)
        assert(second.inferredWindfuryIcon == nil)
    end
end)

Check("disable and FlushPlain preserve buffered records once", function()
    for _, action in ipairs({ "disable", "flush" }) do
        -- Given a pending already-owned extra.
        local test = Harness()
        Source(test)
        test:At(10.2)
        local record, info = Extra(test, 10)
        test.runtime:Out(record, info)
        assert(#test.output == 0)

        -- When inference is disabled or explicitly flushed.
        if action == "disable" then test.enabled = false
        else test.runtime:FlushPlain() end
        test:At(12)

        -- Then ordinary output appears exactly once without a stale icon.
        assert(Count(test, record) == 1 and record.inferredWindfuryIcon == nil)
    end
end)

Check("Reset cancels output from the previous session", function()
    -- Given a pending report and callbacks from its source.
    local test = Harness()
    Source(test)
    local record, info = Extra(test, 10)
    test.runtime:Out(record, info)

    -- When the owner resets its lifecycle before callbacks run.
    test.runtime:Reset()
    test:At(12)

    -- Then the previous session cannot dispatch output.
    assert(#test.output == 0)
end)

Check("Rekey follows the same visible lifetime", function()
    -- Given pending source evidence captured before its nameplate appeared.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)

    -- When the lifetime is rekeyed and its remaining receipts resolve.
    test.runtime:Rekey("target1", "nameplate1:8")
    local second, secondInfo = Extra(test, 10, "nameplate1:8")
    test.runtime:Out(second, secondInfo)
    Normal(test, 10, "nameplate1:8")

    -- Then the same target's pending and later extras still share one group.
    assert(first.inferredWindfuryIcon == 8232)
    assert(second.inferredWindfuryIcon == 8232)
    assert(first.windfuryInferenceGroup == second.windfuryInferenceGroup)
end)

Check("frame overflow flushes old records without reopening retired sources", function()
    -- Given enough pending distinct sources to exceed the runtime bound.
    local test, records = Harness(), {}
    for index = 1, 24 do
        local at = 10 + index * 0.01
        test:At(at)
        Source(test, 439440, "target" .. index, at)
        local record, info = Extra(test, at, "target" .. index)
        records[#records + 1] = record
        test.runtime:Out(record, info)
    end

    -- When all remaining deadlines run.
    test:At(20)

    -- Then bounded eviction neither loses records nor decorates partial data.
    for _, record in ipairs(records) do
        assert(Count(test, record) == 1 and record.inferredWindfuryIcon == nil)
    end
end)

Check("receipt evidence from another frame cannot complete a source", function()
    -- Given complete extras and a native receipt with conflicting evidence.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)
    local normal = { event = "damage", amount = Secret(), school = 1,
        result = { who = "you", melee = true } }

    -- When its receipt names this source but its confirming line names another.
    test.runtime:Out(normal, { at = test.at, key = "target1", confirmed = true,
        restrict = "swing", receipt = { kind = "swing", at = 10,
            key = "target1", hand = "main", who = "you" },
        evidence = { at = 10.1, source = "mine", kind = "swing" } })
    test:At(12)

    -- Then incompatible provenance cannot release previously queued icons.
    assert(Count(test, first) == 1 and first.inferredWindfuryIcon == nil)
    assert(Count(test, second) == 1 and second.inferredWindfuryIcon == nil)
end)

Check("post-deadline evidence cannot reopen an expired source", function()
    -- Given one pending extra that expires before its source finishes.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local first, info = Extra(test, 10)
    test.runtime:Out(first, info)
    test:At(11.601)

    -- When late normal and extra reports still reference that source frame.
    Normal(test, 10)
    local second, secondInfo = Extra(test, 10)
    test.runtime:Out(second, secondInfo)
    test:At(20)

    -- Then both remain ordinary output exactly once.
    assert(Count(test, first) == 1 and Count(test, second) == 1)
    assert(first.inferredWindfuryIcon == nil and second.inferredWindfuryIcon == nil)
end)

Check("an orphan melee extra keeps its existing icon path", function()
    -- Given a native source and an explicitly owned orphan melee extra.
    local test = Harness()
    Source(test)
    test:At(10.2)
    local first, info = Extra(test, 10)
    local second, secondInfo = Extra(test, 10)
    second.result.melee, second.result.extra = true, true
    secondInfo.restrict, secondInfo.evidence.kind = "swing", "swing"

    -- When all reports and source timers are delivered.
    test.runtime:Out(first, info)
    test.runtime:Out(second, secondInfo)
    Normal(test, 10)
    test:At(12)

    -- Then inference preserves the existing melee classification untouched.
    assert(Count(test, first) == 1 and Count(test, second) == 1)
    assert(first.inferredWindfuryIcon == nil and second.inferredWindfuryIcon == nil)
    assert(second.result.melee and second.result.extra)
end)

Check("global queue overflow retains every report once", function()
    -- Given one unresolved source without a signal and many owned reports.
    local test, records = Harness(), {}
    test.runtime:Swing(10, "target1", "main")
    for _ = 1, 32 do test.runtime:Line(10, "target1", "mine", "spell") end
    test:At(10.2)

    -- When reports exceed the queue's fixed bound before its deadline.
    for _ = 1, 80 do
        local record, info = Extra(test, 10)
        records[#records + 1] = record
        test.runtime:Out(record, info)
    end
    test:At(12)

    -- Then overflow preserves all original output without partial inference.
    for _, record in ipairs(records) do
        assert(Count(test, record) == 1 and record.inferredWindfuryIcon == nil)
    end
end)

Check("Reset releases pending amount references before timers expire", function()
    -- Given a report retained only by the runtime's undecorated queue.
    local test = Harness()
    Source(test)
    local record, info = Extra(test, 10)
    local remaining = setmetatable({ record }, { __mode = "v" })
    test.runtime:Out(record, info)
    record, info = nil, nil

    -- When reset cancels the session without advancing its pending timers.
    test.runtime:Reset()
    collectgarbage("collect")

    -- Then timer closures no longer retain its amount-bearing report.
    assert(remaining[1] == nil, "reset retained a canceled amount in a timer")
end)

Check("separate runtime instances never reuse a presentation group", function()
    -- Given an old profile's undecorated release with a still-pending batch.
    local old = Harness()
    Source(old)
    old:At(10.2)
    local plain, plainInfo = Extra(old, 10)
    old.runtime:Out(plain, plainInfo)
    old.runtime:FlushPlain()
    assert(plain.windfuryInferenceGroup and not plain.inferredWindfuryIcon)

    -- When a replacement runtime validates its own first source.
    local replacement = Harness()
    Source(replacement)
    replacement:At(10.2)
    local first, firstInfo = Extra(replacement, 10)
    local second, secondInfo = Extra(replacement, 10)
    replacement.runtime:Out(first, firstInfo)
    replacement.runtime:Out(second, secondInfo)
    Normal(replacement, 10)
    assert(first.inferredWindfuryIcon == 8232)

    -- Then no callback ordering can merge inferred and old plain groups.
    assert(plain.windfuryInferenceGroup ~= first.windfuryInferenceGroup,
        "separate runtimes reused a batch key and could spread an icon")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Inferred Windfury runtime tests passed")
