-- Describe: Windfury bursts stack without inspecting restricted amounts.
MikSBT = { Components = {} }
local profile = {
    stackSimilarHits = true,
    events = {
        OUTGOING_SPELL_DAMAGE = {},
        OUTGOING_SPELL_DAMAGE_CRIT = {},
    },
}
local now, timers, outputs = 0, {}, {}
local secret = setmetatable({}, {
    __add = function() error("added restricted damage") end,
    __lt = function() error("compared restricted damage") end,
    __le = function() error("compared restricted damage") end,
    __tostring = function() error("formatted restricted damage in Lua") end,
})
local Batcher = dofile("Components/OutgoingBatcher.lua")
local batcher = Batcher:New({
    getProfile = function() return profile end,
    getSpellTexture = function() return "windfury" end,
    isAutoAttack = function() return false end,
    formatAmount = tostring,
    formatEventMessage = function(_, amount) return tostring(amount) end,
    after = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    delay = 0.3,
    display = function(settings, message, icon)
        outputs[#outputs + 1] = { settings = settings, message = message,
            icon = icon }
    end,
    displayRestricted = function(settings, amount, icon)
        outputs[#outputs + 1] = { settings = settings, amounts = { amount },
            icon = icon }
    end,
    displayRestrictedGroup = function(settings, amounts, icon)
        outputs[#outputs + 1] = { settings = settings, amounts = amounts,
            icon = icon }
    end,
})
local function Advance(seconds)
    now = now + seconds
    for index = #timers, 1, -1 do
        if timers[index].at <= now then
            local timer = table.remove(timers, index)
            timer.callback()
        end
    end
end

-- Given one restricted Windfury hit with stacking enabled.
batcher:DisplayRestricted(8232, secret, false, "windfury", true)

-- When its partner arrives more than the normal 0.3 seconds later.
Advance(0.5)
batcher:DisplayRestricted(8232, secret, false, "windfury", true)

-- Then both wait for one burst instead of displaying separately.
assert(#outputs == 0, "restricted Windfury bypassed stacking")
Advance(0.5)
assert(#outputs == 1 and #outputs[1].amounts == 2)
assert(outputs[1].amounts[1] == secret and outputs[1].amounts[2] == secret)
assert(outputs[1].icon == "windfury")

-- Given readable Windfury damage in a new burst.
batcher:Queue(8232, 120, false, "windfury", true)

-- When the other hit arrives after the ordinary batch window.
Advance(0.5)
batcher:Queue(8232, 150, false, "windfury", true)
Advance(0.5)

-- Then readable hits retain their summed amount and hit count.
assert(#outputs == 2 and outputs[2].message == "270 [2 Hits]",
    "delayed readable Windfury hits were split")

-- Given readable and restricted damage in the same Windfury burst.
batcher:Queue(8232, 40, false, "windfury", true)

-- When a restricted partner arrives and the burst expires.
Advance(0.5)
batcher:DisplayRestricted(8232, secret, false, "windfury", true)
Advance(0.5)

-- Then neither value is lost or added to restricted damage.
assert(#outputs == 3 and #outputs[3].amounts == 2)
assert(outputs[3].amounts[1] == 40 and outputs[3].amounts[2] == secret)

-- Given a critical Windfury hit beside a normal one.
batcher:DisplayRestricted(8232, secret, true, "windfury", true)
batcher:DisplayRestricted(8232, secret, false, "windfury", true)

-- When both batches expire.
Advance(1)

-- Then normal and critical hits retain their own event settings.
assert(#outputs == 5)
assert(outputs[4].settings ~= outputs[5].settings,
    "normal and critical Windfury damage was merged")

-- Given a pending restricted burst.
batcher:DisplayRestricted(8232, secret, false, "windfury", true)

-- When the runtime resets before its timer runs.
batcher:Reset()
Advance(1)

-- Then reset output remains discarded.
assert(#outputs == 5, "reset Windfury burst was displayed")

-- Given stacking is off.
profile.stackSimilarHits = false

-- When two restricted Windfury hits arrive.
batcher:DisplayRestricted(8232, secret, false, "windfury", true)
batcher:DisplayRestricted(8232, secret, false, "windfury", true)

-- Then both still display immediately and separately.
assert(#outputs == 7)
assert(#outputs[6].amounts == 1 and #outputs[7].amounts == 1)

-- Given stacking is enabled for a different spell.
profile.stackSimilarHits = true

-- When restricted damage from that spell arrives.
batcher:DisplayRestricted(1234, secret, false, "other", true)

-- Then the Windfury fix does not delay it.
assert(#outputs == 8 and outputs[8].icon == "other")

-- Given a readable hit queued before stacking is enabled.
profile.stackSimilarHits = false
batcher:Queue(8232, 10, false, "windfury", true)

-- When stacking is turned on before a restricted Windfury hit arrives.
profile.stackSimilarHits = true
batcher:DisplayRestricted(8232, secret, false, "windfury", true)
Advance(1)

-- Then the old batch and new restricted burst keep their own amounts.
assert(#outputs == 10)
local publicFound, restrictedFound = false, false
for index = 9, 10 do
    local output = outputs[index]
    if output.amounts then
        restrictedFound = output.amounts[1] == secret
    else
        publicFound = output.message == "10"
    end
end
assert(publicFound and restrictedFound, "toggling stacking lost damage")
print("Windfury stacking tests passed")
