MikSBT = { Components = {}, CombatEngine = {}, Display = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/WindfuryTrace.lua")
local now, timers, dispatches, reports = 10, {}, 0, 0
GetTime = function() return now end
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { at = now + delay, callback = callback }
end }
local ns = MikSBT.CombatEngine
local targetKey, cooldownAvailable, eventFrames = "target1", true, {}
local COOLDOWN_EVENT = "SPELL_UPDATE_COOLDOWN"
ns.TargetKey = function() return targetKey end
ns.EventAvailable = function(event)
    return C_EventUtils and C_EventUtils.IsEventValid(event)
end
C_EventUtils = { IsEventValid = function(event)
    assert(event == COOLDOWN_EVENT)
    return cooldownAvailable
end }
CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:Fire(event, ...)
        if self.events[event] then self.scripts.OnEvent(self, event, ...) end
    end
    eventFrames[#eventFrames + 1] = frame
    return frame
end
ns.ActiveWindfurySpell = function() return 8232 end
ns.SpellFacts = function(spell)
    return { direct = true, school = spell == 17364 and 1 or 8 }
end
ns.ProcSpell = function() error("capture confused enchant with damage identity") end
ns.reader = { logLines = {} }
ns.mine = {}
local ledgerEvents = {}
MikSBT.SwingAccounting = { New = function()
    local ledger = {}
    for _, method in ipairs({ "Swing", "Cast", "Signal", "Outcome", "Rekey" }) do
        local name = method
        ledger[name] = function(_, info, other)
            ledgerEvents[#ledgerEvents + 1] = { name, info, other }
        end
    end
    ledger.Reset = function() ledgerEvents = {} end
    ledger.Rows = function() return { "accounting test metadata" } end
    return ledger
end }
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
local Engine = {
    HandleEvent = function() return "first", nil, "third" end,
    Stop = function() return "stopped" end,
}
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

-- Describe: public cooldown metadata remains opt-in, bounded context only.
-- Given capture has never been enabled and cooldown support is unavailable.
assert(#eventFrames == 0, "loading diagnostics created an event frame")
cooldownAvailable = false

-- When capture starts on an unsupported client.
capture:Start()
assert(capture.ledger and capture.model.accounting == capture.ledger,
    "capture did not attach the experimental accounting report")
assert(ns.mine.accountingEnabled == true,
    "capture did not opt into Mine outcome receipts")

-- Then it does not create or register a cooldown observer.
assert(#eventFrames == 0, "unsupported cooldown event was registered")
capture:Stop()
assert(not ns.mine.accountingEnabled,
    "stopped capture left outcome accounting enabled")

-- Given no API can positively establish the event's availability.
local eventUtils = C_EventUtils
C_EventUtils = nil
cooldownAvailable = true

-- When capture starts without that capability API.
capture:Start()

-- Then legacy availability defaults cannot register the observer.
assert(#eventFrames == 0, "missing capability API registered cooldown capture")
capture:Stop()
C_EventUtils = eventUtils

-- Given supported cooldown metadata and a swing with no proc evidence.
capture:Start()
local cooldownFrame = eventFrames[1]
assert(cooldownFrame and cooldownFrame.events[COOLDOWN_EVENT],
    "active supported capture did not register cooldown metadata")
cooldownFrame:Fire(COOLDOWN_EVENT, 8232)
assert(#capture.model.bursts == 0,
    "cooldown update created a burst without a swing")
local cooldownBurst = capture.model:Swing(now, "target1", 0, true)

-- When repeated, nullable, and secret payloads arrive through the native frame.
cooldownFrame:Fire(COOLDOWN_EVENT, 8232, nil, 0, 0, nil)
cooldownFrame:Fire(COOLDOWN_EVENT, 8232, nil, 0, 0, nil)
cooldownFrame:Fire(COOLDOWN_EVENT, nil, opaque, opaque, opaque, opaque)
cooldownFrame:Fire(COOLDOWN_EVENT, opaque, 123, opaque, 0, 456)
now = now + 0.25
targetKey = "target2"
cooldownFrame:Fire(COOLDOWN_EVENT, 321, 322, 0, 7, 456)

-- Then only public numbers survive, including zero, without deduplicating them.
assert(#cooldownBurst.cooldowns == 5, "repeated cooldown updates were lost")
assert(cooldownBurst.cooldowns[1].spellID == 8232)
assert(cooldownBurst.cooldowns[2].spellID == 8232)
assert(cooldownBurst.cooldowns[1].category == 0)
for _, field in ipairs({ "spellID", "baseSpellID", "category",
    "startRecoveryCategory", "itemID" }) do
    assert(cooldownBurst.cooldowns[3][field] == nil,
        "nullable or secret cooldown field reached the model: " .. field)
end
assert(cooldownBurst.cooldowns[4].spellID == nil)
assert(cooldownBurst.cooldowns[4].baseSpellID == 123)
assert(cooldownBurst.cooldowns[4].category == nil)
assert(cooldownBurst.cooldowns[4].startRecoveryCategory == 0)
assert(cooldownBurst.cooldowns[4].itemID == 456)
assert(cooldownBurst.cooldowns[5].at == now)
assert(cooldownBurst.cooldowns[5].targetContext == "target2")
assert(cooldownBurst.key == "target1", "cooldown context changed burst ownership")
targetKey = opaque
cooldownFrame:Fire(COOLDOWN_EVENT)
assert(cooldownBurst.cooldowns[6].targetContext == nil,
    "secret target context reached the report")
local cooldownSummary = capture.model:Summary(cooldownBurst)
assert(cooldownSummary.expected == 0 and cooldownSummary.estimated == 0)
assert(cooldownSummary.damage == 0 and cooldownSummary.rawDamage == 0)
assert(cooldownSummary.confirmations == 0 and #cooldownBurst.reports == 0)
assert(not capture.model:NeedsAttention(cooldownBurst))
local cooldownReport = capture.model:ReportText()
assert(cooldownReport:find("Cooldown updates are unconfirmed", 1, true))
assert(cooldownReport:find("cooldown +0.250 spellID=321 baseSpellID=322 " ..
    "category=0 startRecoveryCategory=7 itemID=456 targetContext=target2", 1, true))

-- When capture stops and a stale callback is attempted.
capture:Stop()
assert(not cooldownFrame.events[COOLDOWN_EVENT],
    "stopping capture left its cooldown event registered")
cooldownFrame:Fire(COOLDOWN_EVENT, 999)
local callback = cooldownFrame.scripts.OnEvent
if callback then callback(cooldownFrame, COOLDOWN_EVENT, 999) end

-- Then the stopped model remains unchanged and the frame can be reused.
assert(#cooldownBurst.cooldowns == 6, "stopped capture observed a cooldown")
targetKey = "target1"
capture:Start()
assert(#eventFrames == 1 and cooldownFrame.events[COOLDOWN_EVENT])
capture:Stop()

-- Given capture is explicitly enabled with a normal outgoing configuration.
capture:Start()
local burst = Swing()

-- When the player casts between swings, with a hidden cast GUID.
Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", opaque, 17364)

-- Then capture retains only the public spell ID and timing.
assert(#burst.casts == 1 and burst.casts[1].spell == 17364)
assert(burst.casts[1].weaponTrigger)
assert(capture.model:ReportText():find("cast +0.000 spell=17364", 1, true))

-- When a Nature cast is recorded in the same capture.
Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", opaque, 8042)

-- Then its public ID remains visible but it cannot anchor a weapon proc.
assert(#burst.casts == 2 and burst.casts[2].spell == 8042)
assert(not burst.casts[2].weaponTrigger)
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

-- Given old settle timers survive a stop and restart.
capture:Start()

-- When those old timers run.
Advance(4)

-- Then they cannot freeze the new capture or overwrite its report.
assert(capture.active and reports == 1)
capture:Stop()

-- Describe: real accounting follows the capture without reading amounts.
-- Given a real ledger and the recorded delayed Windfury sequence.
dofile("Combat/SwingAccounting.lua")
targetKey, now = "experiment-target", 1000
capture:Start()
local actualLedger = capture.ledger
local sourceAt = now
Swing()
capture.eventFrame:Fire(COOLDOWN_EVENT, 439440, nil, 0, 0, nil)
local function Accounted(at, result, receipt, evidenceAt, key)
    now = at
    local record = { event = "damage", school = 1, amount = opaque,
        result = result, accounting = {
            at = at, key = key or targetKey, confirmed = true,
            restrict = receipt and receipt.kind == "swing" and "swing" or "direct",
            receipt = receipt,
            evidence = evidenceAt and {
                at = evidenceAt, source = "mine", kind = "spell",
            } or nil,
        } }
    ns.traceCombat("report", { record = record, at = at,
        key = key or targetKey, unit = "target" })
    Presentation:Out(record)
    return record
end

-- When the normal swing arrives between the two delayed extra outcomes.
Accounted(sourceAt + 0.215, { who = "you" }, nil, sourceAt)
Accounted(sourceAt + 0.588, { who = "you", melee = true }, {
    kind = "swing", at = sourceAt, key = targetKey, hand = "main",
    ordinal = 1, who = "you",
})
Accounted(sourceAt + 1.002, { who = "you" }, nil, sourceAt)

-- Then the report separates observed outcomes from the capacity hypothesis.
local accounting = actualLedger:Summaries()[1]
assert(accounting.normalObserved == 1 and accounting.normalMatched == 1)
assert(accounting.ownedPhysicalExtras == 2 and accounting.weaponSignals == 1)
assert(accounting.verdict == "candidate")
assert(capture.model:ReportText():find("Experimental swing accounting", 1, true))
assert(capture.model:ReportText():find("Weapon=1(hint=2)", 1, true))

-- Given a valid source frame but unreadable outcome classification controls.
local observed = #actualLedger.outcomes
local controls = { "tick", "melee", "extra", "ambiguous", "spell" }

-- When each hidden result field or restriction reaches the capture boundary.
for _, field in ipairs(controls) do
    local result = { who = "you" }
    result[field] = opaque
    capture:AccountingOutcome({ event = "damage", school = 1, amount = opaque,
        result = result, accounting = {
            at = now, key = targetKey, confirmed = true, restrict = "direct",
            evidence = { at = sourceAt, source = "mine", kind = "spell" },
        } })
end
capture:AccountingOutcome({ event = "damage", school = 1, amount = opaque,
    result = { who = "you" }, accounting = {
        at = now, key = targetKey, confirmed = true, restrict = opaque,
        evidence = { at = sourceAt, source = "mine", kind = "spell" },
    } })

-- Then unreadability remains uncertain instead of becoming an absent field.
assert(#actualLedger.outcomes == observed,
    "capture erased secret controls and admitted a physical candidate")

-- Given a successful Stormstrike whose captured recipient is no longer selected.
now = sourceAt + 2
local recipientKey = targetKey
targetKey = "different-selected-target"
ns.reader.lastCastTarget = { at = now, key = recipientKey,
    unit = "player", spell = 17364 }

-- When its cast and spent outcome reach capture after the target switch.
Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-original", 17364)
Accounted(now, { who = "you", spell = 17364 }, {
    kind = "cast", at = now, key = recipientKey, sourceKey = recipientKey,
    spell = 17364, ordinal = 1, who = "you",
}, nil, recipientKey)

-- Then accounting uses the original recipient, not the selected target.
accounting = actualLedger:Summaries()[2]
assert(accounting.key == recipientKey and accounting.ssMatched == 1)
ns.traceCombat("rekey", nil, { old = recipientKey, new = "experiment-plate:2" })
assert(actualLedger:Summaries()[2].key == "experiment-plate:2")

-- Given a world transition while capture remains enabled.
-- When the event reaches the capture wrapper.
Engine:HandleEvent("PLAYER_ENTERING_WORLD")

-- Then old source reservations are cleared and receipts stay opt-in.
assert(#actualLedger:Summaries() == 0 and ns.mine.accountingEnabled)

-- Given the user disables the combat engine during the experiment.
-- When the engine stops.
local stopped = Engine:Stop()

-- Then capture stops with it, preserving its report and clearing receipt flags.
assert(stopped == "stopped", "capture changed the engine stop return")
assert(not capture.active and not ns.mine.accountingEnabled,
    "engine stop left experimental accounting active")
assert(ns.traceCombat == nil and capture.model.accounting == actualLedger)
print("Windfury capture pipeline tests passed")
