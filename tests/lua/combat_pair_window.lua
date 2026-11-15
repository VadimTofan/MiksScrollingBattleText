MikSBT = { CombatEngine = { Timer = {} } }
GetTime = function() return 10 end
dofile("Combat/Reader.lua")
local ns = MikSBT.CombatEngine
local originalSort = table.sort
local sorts = 0
table.sort = function(values)
    sorts = sorts + 1
    return originalSort(values)
end

local function Sample(gap)
    local record = { event = "damage", result = { spell = 101 } }
    ns.reader.logLines = {{ source = "mine", at = 10 - gap }}
    ns.OnYourHit(record, 10)
end

-- Given too few timing samples to estimate the matching window.
for index = 1, 7 do Sample(0.01) end

-- When matching is requested before enough evidence exists.
local fallback = ns.PairWindow()

-- Then the original default window is preserved without sorting.
assert(fallback == 0.1 and sorts == 0)

-- Given enough timing samples and many hits using the same samples.
Sample(0.01)

-- When the matching window is queried repeatedly.
for index = 1, 1000 do
    assert(math.abs(ns.PairWindow() - 0.024) < 0.000001)
end

-- Then unchanged samples are sorted only once.
assert(sorts == 1, "unchanged samples were sorted " .. sorts .. " times")

-- When new samples replace the old median.
for index = 1, 30 do Sample(0.04) end
local updated = ns.PairWindow()

-- Then the estimate updates without changing sample arrival order.
assert(math.abs(updated - 0.084) < 0.000001)
assert(#ns.reader.gaps == 30 and sorts == 2)
assert(math.abs(ns.reader.gaps[1] - 0.04) < 0.000001)
table.sort = originalSort

-- When the reader stops and starts a fresh session.
ns.StopReader()

-- Then the old matching estimate is discarded.
assert(ns.PairWindow() == 0.1)

-- Describe: resolved confirmation context never consumes a second spare line.
local failures, callbacks = {}, {}
local function Reset()
    ns.StopReader()
    callbacks = {}
    ns.Timer.After = function(_, callback)
        callbacks[#callbacks + 1] = callback
    end
end

local function Check(name, run)
    Reset()
    local ok, message = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. message end
end

Check("an actual claimed line keeps its hit and original timing", function()
    -- Given an actual claimed confirmation after an earlier free spare.
    local record = { event = "damage", result = { spell = 101 } }
    local spare = { source = "mine", at = 9.99 }
    local actual = { source = "mine", at = 9.98, claimed = true,
        hit = { at = 10, record = record } }
    ns.reader.logLines = { spare, actual }

    -- When the existing decision hands its exact line to hit observation.
    ns.OnYourHit(record, 10, actual)

    -- Then the same line remains bound and the spare is still available.
    local hit = ns.reader.yourHits[1]
    assert(hit.line == actual and actual.hit == hit)
    assert(spare.hit == nil, "actual confirmation consumed a spare line")
    assert(math.abs(hit.gap - 0.02) < 0.000001)
    assert(#ns.reader.gaps == 1)
    assert(math.abs(ns.reader.gaps[1] - 0.02) < 0.000001)
end)

Check("a same-frame confirmation pool keeps individual lines unbound", function()
    -- Given two claimed pool lines plus an unrelated free spare.
    local record = { event = "damage", result = { spell = 101 } }
    local spare = { source = "mine", at = 9.99 }
    local first = { source = "mine", at = 9.98, claimed = true }
    local second = { source = "mine", at = 9.98, claimed = true }
    local unused = { source = "mine", at = 9.97 }
    ns.reader.logLines = { spare, first, second, unused }

    -- When ownership came from the claimed same-frame pool as a group.
    ns.OnYourHit(record, 10, { first, second, unused }, true)

    -- Then its common original time is retained without inventing a pairing.
    local hit = ns.reader.yourHits[1]
    assert(hit.confirmed and hit.line == nil)
    assert(math.abs(hit.gap - 0.02) < 0.000001)
    assert(first.hit == nil and second.hit == nil and unused.hit == nil)
    assert(spare.hit == nil, "shared confirmation consumed a spare line")
    assert(#ns.reader.gaps == 1)
    assert(math.abs(ns.reader.gaps[1] - 0.02) < 0.000001)
end)

Check("a same-frame pool can confirm a guess without borrowing a spare", function()
    -- Given a guessed spell and a claimed pool close to its actual hit.
    local guess = { caster = "you", spell = 101 }
    local record = { event = "damage", result = { spell = 101, guess = guess } }
    local first = { source = "mine", at = 9.98, claimed = true }
    local second = { source = "mine", at = 9.98, claimed = true }
    local spare = { source = "mine", at = 9.99 }
    ns.reader.logLines = { spare, first, second }
    local trusted = 0
    ns.mine = { Trust = function(_, actual)
        assert(actual == guess)
        trusted = trusted + 1
    end }

    -- When its shared confirmation reaches the delayed trust check.
    ns.OnYourHit(record, 10, { first, second }, true)
    for _, callback in ipairs(callbacks) do callback() end

    -- Then common timing confirms the guess without selecting another line.
    assert(trusted == 1 and spare.hit == nil)
    assert(first.hit == nil and second.hit == nil)
    assert(#ns.reader.gaps == 0, "a guessed spell taught the pair window")
end)

Check("mixed-time confirmation pools cannot invent a gap or trust", function()
    -- Given claimed lines at different times and a tempting close spare.
    local guess = { caster = "you", spell = 101 }
    local record = { event = "damage", result = { spell = 101, guess = guess } }
    local first = { source = "mine", at = 9.98, claimed = true }
    local second = { source = "mine", at = 9.97, claimed = true }
    local spare = { source = "mine", at = 9.999 }
    ns.reader.logLines = { spare, first, second }
    local trusted = 0
    ns.mine = { Trust = function() trusted = trusted + 1 end }

    -- When an ownership-confirmed group has no individual timing assignment.
    ns.OnYourHit(record, 10, { first, second }, true)
    for _, callback in ipairs(callbacks) do callback() end

    -- Then ownership remains confirmed without exact timing or new trust.
    local hit = ns.reader.yourHits[1]
    assert(hit.confirmed and hit.line == nil and hit.gap == nil)
    assert(trusted == 0 and #ns.reader.gaps == 0)
    assert(spare.hit == nil and first.hit == nil and second.hit == nil)
end)

Check("an explicit false context rejects existing and later free lines", function()
    -- Given an owned hit explicitly lacking an individual confirmation.
    local record = { event = "damage", result = { spell = 101 } }
    local spare = { source = "mine", at = 9.99 }
    ns.reader.logLines = { spare }
    ns.Number = function(value, minimum, maximum)
        return type(value) == "number" and (not minimum or value >= minimum)
            and (not maximum or value <= maximum)
    end
    ns.Public = function() return true end
    ns.TargetKey = function() return "target1" end
    Enum = { CombatLogMessageOrder = { Newest = 1 } }

    -- When observation runs before a second nearby own line arrives.
    ns.OnYourHit(record, 10, false)
    ns.ReaderEvent(nil, "COMBAT_LOG_MESSAGE", "own line", 0.7, 0.7, 0.7, 1)

    -- Then neither path can consume fresh capacity for the resolved hit.
    local hit = ns.reader.yourHits[1]
    local later = ns.reader.logLines[#ns.reader.logLines]
    assert(later ~= spare and later.source == "mine")
    assert(spare.hit == nil and later.hit == nil)
    assert(hit.line == nil and hit.gap == nil and not hit.confirmed)
    assert(#ns.reader.gaps == 0)
end)

for _, shared in ipairs({ false, true }) do
    for _, gap in ipairs({ 0.1, 0.1001, 0.25 }) do
        Check("pair sample boundary gap=" .. gap .. " shared=" .. tostring(shared),
            function()
            -- Given an original confirmation and a closer unused spare.
            local record = { event = "damage", result = { spell = 101 } }
            local actual = { source = "mine", at = 10 - gap, claimed = true }
            local spare = { source = "mine", at = 9.99 }
            ns.reader.logLines = { spare, actual }
            local confirmation = shared and { actual } or actual

            -- When the exact or shared original confirmation is observed.
            ns.OnYourHit(record, 10, confirmation, shared)

            -- Then only a gap within LOG_PAIR can enter timing samples.
            local hit = ns.reader.yourHits[1]
            local expectedSamples = gap <= 0.1 and 1 or 0
            assert(math.abs(hit.gap - gap) < 0.000001)
            assert(#ns.reader.gaps == expectedSamples and spare.hit == nil)
        end)
    end
end

assert(#failures == 0, table.concat(failures, "\n"))
print("Combat pair confirmation context tests passed")
