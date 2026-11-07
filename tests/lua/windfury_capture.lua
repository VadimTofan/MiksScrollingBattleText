MikSBT = { Components = {}, CombatEngine = {}, Display = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/WindfuryTrace.lua")
local now, timers, dispatches, reports = 10, {}, 0, 0
GetTime = function() return now end
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { at = now + delay, callback = callback }
end }
local ns = MikSBT.CombatEngine
ns.TargetKey = function() return "target1" end
ns.ProcSpell = function() return 8232 end
ns.reader = { logLines = {} }
MikSBT.Print = function() end
MikSBT.Compatibility = { Client = { isForever = true } }
local function Pack(...) return { n = select("#", ...), ... } end
hooksecurefunc = function(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        local result = Pack(original(...))
        callback(...)
        return unpack(result, 1, result.n)
    end
end
local Engine = { HandleEvent = function() return "first", nil, "third" end }
MikSBT.Components.CombatEngine = Engine
local profile = { events = {
    OUTGOING_SPELL_DAMAGE = { textCategory = "Outgoing", scrollArea = "Outgoing" },
    OUTGOING_SPELL_DODGE = { textCategory = "Outgoing", scrollArea = "Outgoing" },
}, normalFontAlpha = 100 }
local Service = dofile("Display/DisplayService.lua")
Service:Configure({ isModDisabled = function() return false end,
    getProfile = function() return profile end,
    scrollAreas = { Resolve = function() return {} end }, fonts = {},
    display = function() dispatches = dispatches + 1 end,
})
local Batcher = dofile("Components/OutgoingBatcher.lua")
local batcher = Batcher:New({ getProfile = function() return profile end,
    getSpellTexture = function() return "icon" end,
    isAutoAttack = function() return false end,
    after = C_Timer.After, delay = 0.3,
    formatAmount = tostring,
    formatEventMessage = function(_, amount) return tostring(amount) end,
    display = function(...) Service:DisplayEvent(...) end,
    displayRestricted = function(settings, amount, icon)
        Service:DisplayEvent(settings, "%s", icon, nil, amount)
    end,
})
local opaque = setmetatable({}, {
    __tostring = function() error("capture inspected damage") end,
})
issecretvalue = function(value) return value == opaque end
local PresentationClass = dofile("Components/CombatPresentation.lua")
local Presentation = PresentationClass:New({
    getProfile = function() return profile end,
    batcher = batcher, after = C_Timer.After,
    getSpellTexture = function() return "icon" end,
    formatMessage = function(_, record) return record.missWord end,
    display = function(...) Service:DisplayEvent(...) end,
})
dofile("Combat/WindfuryCapture.lua")
local capture = MikSBT.WindfuryCapture
capture.ShowReport = function(self)
    reports = reports + 1
    self.reportText = self.model:ReportText()
end
local function Swing()
    Engine:HandleEvent("PLAYER_SWING", 3.8, 0)
    for index = 1, 2 do
        ns.reader.logLines[index] = { at = now, source = "mine", kind = "spell" }
        Engine:HandleEvent("COMBAT_LOG_MESSAGE")
    end
    return capture.model.bursts[#capture.model.bursts]
end
local function Hit(amount)
    local record = { event = "damage", school = 1, amount = amount }
    local hit = { record = record, at = now, key = "target1", unit = "target" }
    ns.traceCombat("report", hit)
    record.result = { who = "you", procSpell = 8232 }
    ns.traceCombat("decision", hit)
    Presentation:Out(record)
    return record
end
local function Advance(seconds)
    now = now + seconds
    for index = #timers, 1, -1 do
        if timers[index].at <= now then
            local timer = table.remove(timers, index)
            timer.callback()
        end
    end
end

-- Given capture is explicitly enabled with a normal outgoing configuration.
capture:Start()
local burst = Swing()
now = now + 0.5

-- When two opaque proc hits pass through presentation and the real service.
Hit(opaque)
Hit(opaque)

-- Then both hits retain their IDs through separate animation dispatches.
local summary = capture.model:Summary(burst)
assert(summary.damage == 2 and summary.forwarded == 2 and summary.displays == 2)
assert(dispatches == 2 and not capture.model:NeedsAttention(burst))

-- Given another swing whose public amounts are combined by the real batcher.
Advance(4)
local merged = Swing()
now = now + 0.5
Hit(13)
Hit(15)

-- When its batch flushes and the settled capture is evaluated.
Advance(0.4)
summary = capture.model:Summary(merged)
assert(summary.damage == 2 and summary.forwarded == 2)
assert(summary.displays == 1 and summary.merged)
Advance(3)

-- Then capture freezes automatically with the copyable reason available.
assert(not capture.active and reports == 1)
assert(capture.reportText:find("merged=true", 1, true))
assert(ns.traceCombat == nil)

-- Given a fresh capture with outgoing text disabled.
capture:Start()
local blocked = Swing()
profile.msbtOutgoingDisabled = true
now = now + 0.5

-- When both hits reach the service but fail its category gate.
Hit(opaque)
Hit(opaque)
summary = capture.model:Summary(blocked)

-- Then requests are distinguished from dispatches and the gate is named.
assert(summary.damage == 2 and summary.displays == 0)
assert(capture.model:ReportText():find("category disabled", 1, true))
capture:Stop()
assert(ns.traceCombat == nil)

-- Given a confirmed dodge takes the real presentation's non-damage path.
profile.msbtOutgoingDisabled = false
capture:Start()
local missBurst = Swing()
now = now + 0.5
local missed = { event = "miss", missWord = "Dodge", school = 1 }
local missHit = { record = missed, at = now, key = "target1", unit = "target" }
ns.traceCombat("report", missHit)
missed.result = { who = "you", procSpell = 8232 }

-- When its presentation emits the failed attack instead of damage.
Presentation:Out(missed)

-- Then it remains one miss on the correct timeline with its display request.
summary = capture.model:Summary(missBurst)
assert(summary.misses == 1 and summary.damage == 0 and summary.displays == 1)
capture:Stop()

-- Given a wrapped method has multiple returns or fails inside a correlation.
capture:Start()
local object = { Call = function(fail)
    if fail then error("observed failure", 0) end
    return "first", nil, "third"
end }
capture:Wrap(object, "Call", function(original, ...)
    capture.ids = { 999 }
    return original(...)
end)

-- When it succeeds and then fails.
local values = Pack(object.Call(false))
local ok, err = pcall(object.Call, true)

-- Then return arity, the error and surrounding correlation are preserved.
assert(values.n == 3 and values[1] == "first" and values[3] == "third")
assert(not ok and err == "observed failure" and capture.ids == nil)
capture:Stop()

-- Given a successful auto-attack proc followed by a separate Stormstrike proc.
capture:Start()
local ordinaryBurst = Swing()
now = now + 0.5
Hit(opaque)
Hit(opaque)
now = now + 1.757

-- When Stormstrike succeeds and its own confirmations arrive between swings.
Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
for index = 1, 3 do
    ns.reader.logLines[index] = { at = now, source = "mine", kind = "spell" }
    Engine:HandleEvent("COMBAT_LOG_MESSAGE")
end
local strikeBurst = capture.model.bursts[#capture.model.bursts]

-- Then its missing proc cannot be hidden by the earlier successful pair.
assert(strikeBurst ~= ordinaryBurst and strikeBurst.spell == 17364)
assert(capture.model:Summary(ordinaryBurst).damage == 2)
assert(capture.model:Summary(strikeBurst).expected == 2)
assert(capture.model:NeedsAttention(strikeBurst))
assert(capture.model:ReportText():find("Stormstrike", 1, true))
capture:Stop()

-- Given old settle timers survive a stop and restart.
capture:Start()

-- When those old timers run.
Advance(4)

-- Then they cannot freeze the new capture or overwrite its report.
assert(capture.active and reports == 1)
capture:Stop()
print("Windfury capture pipeline tests passed")
