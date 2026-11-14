MikSBT = { Components = {} }
local profile = {
    stackSimilarHits = true,
    events = { OUTGOING_SPELL_DAMAGE = {} },
}
local now, timers, outputs = 0, {}, {}
local secret = setmetatable({}, {
    __add = function() error("summed hidden damage") end,
    __le = function() error("compared hidden damage") end,
    __tostring = function() error("read hidden damage") end,
})
local Batcher = dofile("Components/OutgoingBatcher.lua")
local batcher = Batcher:New({
    getProfile = function() return profile end,
    getSpellTexture = function() error("invented an unnamed proc icon") end,
    isAutoAttack = function() return false end,
    formatEventMessage = function(_, amount, spell)
        assert(spell == nil, "candidate identity became a spell name")
        return tostring(amount)
    end,
    after = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    delay = 0.3,
    display = function(_, message, icon)
        outputs[#outputs + 1] = { message = message, icon = icon }
    end,
    displayRestricted = function(_, amount, icon)
        outputs[#outputs + 1] = { amounts = { amount }, icon = icon }
    end,
    displayRestrictedGroup = function(_, amounts, icon, _, spell)
        assert(spell == nil, "candidate group invented a spell identity")
        outputs[#outputs + 1] = { amounts = amounts, icon = icon }
    end,
})
local function Advance(seconds)
    now = now + seconds
    for index = #timers, 1, -1 do
        if timers[index].at <= now then
            table.remove(timers, index).callback()
        end
    end
end

-- Given a confirmed owned hit with candidate grouping but no spell identity.
batcher:DisplayRestricted(nil, secret, false, "generic", true,
    false, false, "OUTGOING_SPELL_DAMAGE", 1, 8232)

-- When its partner arrives after the ordinary batching window.
Advance(0.4)
batcher:DisplayRestricted(nil, secret, false, "generic", true,
    false, false, "OUTGOING_SPELL_DAMAGE", 1, 8232)

-- Then the candidate group waits without displaying or inspecting either value.
assert(#outputs == 0, "unnamed candidate grouping was lost")

-- Given unrelated unnamed damage in the same outgoing event.
batcher:Queue(nil, 50, false, "generic", true, false, false,
    "OUTGOING_SPELL_DAMAGE", false, 1)

-- When the ordinary batch and then the candidate batch expire.
Advance(0.31)
Advance(0.3)

-- Then ordinary output remains separate and both candidate amounts survive.
assert(#outputs == 2)
assert(outputs[1].message == "50")
assert(#outputs[2].amounts == 2 and outputs[2].amounts[1] == secret
    and outputs[2].amounts[2] == secret)
assert(outputs[2].icon == "generic")

-- Given candidate grouping is disabled in the profile.
profile.stackSimilarHits = false
outputs = {}

-- When a restricted candidate arrives.
batcher:DisplayRestricted(nil, secret, false, "generic", true,
    false, false, "OUTGOING_SPELL_DAMAGE", 1, 8232)

-- Then it displays immediately without forcing a candidate group.
assert(#outputs == 1 and outputs[1].amounts[1] == secret)
assert(next(batcher.batches) == nil)

-- Given stacking is enabled but the event belongs to a pet or periodic damage.
profile.stackSimilarHits = true
for _, event in ipairs({ { pet = true }, { dot = true } }) do
    outputs = {}

    -- When a candidate hint accompanies an excluded event type.
    batcher:DisplayRestricted(nil, secret, false, "generic", true,
        event.pet, event.dot, "OUTGOING_SPELL_DAMAGE", 1, 8232)

    -- Then the hint cannot merge unrelated damage into a weapon-proc group.
    assert(#outputs == 1 and next(batcher.batches) == nil)
end

-- Given an unnamed public amount followed by a restricted candidate partner.
outputs = {}
batcher:Queue(nil, 25, false, "generic", true, false, false,
    "OUTGOING_SPELL_DAMAGE", false, 1, 8232)
batcher:DisplayRestricted(nil, secret, false, "generic", true,
    false, false, "OUTGOING_SPELL_DAMAGE", 1, 8232)

-- When the group expires.
Advance(1.1)

-- Then the public value and opaque object remain separate native arguments.
assert(#outputs == 1 and #outputs[1].amounts == 2)
assert(outputs[1].amounts[1] == 25 and outputs[1].amounts[2] == secret)

-- Given normal and critical candidate damage in the same time window.
profile.events.OUTGOING_SPELL_DAMAGE_CRIT = {}
outputs = {}
for _, critical in ipairs({ false, true }) do
    batcher:DisplayRestricted(nil, secret, critical, "generic", true,
        false, false, "OUTGOING_SPELL_DAMAGE", 1, 8232)
end

-- When both candidate batches expire.
Advance(1.1)

-- Then critical and normal amounts remain independent.
assert(#outputs == 2 and #outputs[1].amounts == 1 and #outputs[2].amounts == 1)
