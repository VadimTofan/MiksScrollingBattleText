-- Describe: opt-in resource diagnostics preserve restricted event values.
MikSBT = { Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
local now, callbacks, messages = 10, {}, {}
GetTime = function() return now end
C_Timer = { After = function(_, callback)
    callbacks[#callbacks + 1] = callback
end }
MikSBT.Print = function(message) messages[#messages + 1] = message end
SlashCmdList = {}
local frame = { events = {} }
function frame:RegisterEvent(event) self.events[event] = true end
function frame:UnregisterAllEvents() self.events = {} end
function frame:SetScript(_, callback) self.callback = callback end
CreateFrame = function() return frame end
local secret = setmetatable({}, {
    __tostring = function() error("diagnostic inspected a secret") end,
    __concat = function() error("diagnostic concatenated a secret") end,
})
issecretvalue = function(value) return value == secret end
local chunk = loadfile("Diagnostics/ResourceCapture.lua")
assert(chunk, "resource source diagnostic is missing")
local capture = chunk()

-- Given the diagnostic is loaded but has not been started.
-- When an unrelated combat event arrives.
capture:OnEvent("COMBAT_TEXT_UPDATE", "ENERGIZE")
-- Then it has no registrations or captured rows.
assert(not next(frame.events) and #capture.rows == 0)

-- Given a resource event with opaque values and an extra spell-ID field.
C_CombatText = { GetCurrentEventInfo = function()
    return secret, secret, nil, 5677
end }
-- When capture is armed and that resource event arrives.
SlashCmdList.MSBTRESOURCES("start")
frame.callback(frame, "COMBAT_TEXT_UPDATE", "ENERGIZE")
-- Then nil holes, extra fields, and secret markers survive in the report.
assert(frame.events.COMBAT_TEXT_UPDATE and frame.events.COMBAT_LOG_MESSAGE)
local report = capture:ReportText()
assert(report:find("ENERGIZE argc=4", 1, true))
assert(report:find("1=<secret> 2=<secret> 3=nil 4=5677", 1, true))

-- Given a readable periodic resource event and a nearby player cast.
C_CombatText.GetCurrentEventInfo = function() return 8, "MANA" end
now = 10.1
-- When the events arrive alongside a protected combat-log string.
frame.callback(frame, "COMBAT_TEXT_UPDATE", "PERIODIC_ENERGIZE")
frame.callback(frame, "UNIT_SPELLCAST_SUCCEEDED", "player", secret, 5675)
frame.callback(frame, "COMBAT_LOG_MESSAGE", secret, 1, 0.5, 0, 1)
frame.callback(frame, "COMBAT_LOG_MESSAGE", "|Kprivate player data|k", 1, 1, 1, 1)
-- Then available fields are visible, but log text is never copied or parsed.
report = capture:ReportText()
assert(report:find("1=8 2=MANA", 1, true))
assert(report:find("player cast spellID=5675 (context only)", 1, true))
assert(report:find("log argc=5 text=<secret>", 1, true))
assert(report:find("log argc=5 text=<formatted-text>", 1, true))
assert(not report:find("private player data", 1, true))

-- Given unrelated combat-text events and a restricted event kind.
local before = #capture.rows
-- When they arrive, they must not invoke the resource getter.
C_CombatText.GetCurrentEventInfo = function() error("unexpected getter") end
frame.callback(frame, "COMBAT_TEXT_UPDATE", "HEAL")
frame.callback(frame, "COMBAT_TEXT_UPDATE", secret)
-- Then only resource events were captured.
assert(#capture.rows == before)

-- Given a broken or unavailable resource getter.
-- When a gain arrives, the diagnostic reports the failure without throwing.
frame.callback(frame, "COMBAT_TEXT_UPDATE", "ENERGIZE")
assert(capture:ReportText():find("payload unavailable", 1, true))
C_CombatText = nil
frame.callback(frame, "COMBAT_TEXT_UPDATE", "ENERGIZE")

-- Given a capture restarted while its old timeout is pending.
local staleTimeout = callbacks[1]
-- When the old timeout runs after a fresh start.
capture:Start()
staleTimeout()
-- Then it does not stop the new capture.
assert(capture.active)

-- Given a resource gain followed by many combat-log messages.
C_CombatText = { GetCurrentEventInfo = function() return 8, "MANA" end }
frame.callback(frame, "COMBAT_TEXT_UPDATE", "ENERGIZE")
-- When log messages arrive, followed by the current timeout.
for index = 1, 200 do
    frame.callback(frame, "COMBAT_LOG_MESSAGE", secret)
end
callbacks[#callbacks]()
-- Then log sampling preserves the gain and event listeners are removed.
assert(#capture.rows == 21)
assert(capture:ReportText():find("1=8 2=MANA", 1, true))
assert(not capture.active and not next(frame.events))
assert(capture:ReportText():find("log events=200", 1, true))

-- Given a new capture with more resource events than its report limit.
capture:Start()
-- When 200 gains arrive.
for index = 1, 200 do
    frame.callback(frame, "COMBAT_TEXT_UPDATE", "ENERGIZE")
end
-- Then resource rows are bounded independently of event volume.
assert(#capture.rows == 120)

-- Given the user requests a report after a new capture.
capture:Start()
capture.ShowReport = function(self)
    self:Stop()
    self.shown = self:ReportText()
end
-- When the report command runs.
SlashCmdList.MSBTRESOURCES("report")
-- Then capture stops before the copyable report opens.
assert(capture.shown and not capture.active)
print("Resource source diagnostic tests passed")
