MikSBT = { Components = {}, Display = {} }
dofile("API/RestrictedValue.lua")
local created, calls, hooks = {}, 0, 0
local now = 10
GetTime = function() return now end
UIParent = {}
SlashCmdList = {}

local function NewWidget()
    local widget = { strings = {} }
    function widget:SetSize() end
    function widget:SetPoint() end
    function widget:SetWidth() end
    function widget:SetJustifyH() end
    function widget:SetFrameStrata() end
    function widget:SetBackdrop() end
    function widget:SetBackdropColor() end
    function widget:SetText(text) self.text = text end
    function widget:SetFormattedText(template, ...)
        self.template, self.args = template, { ... }
    end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    function widget:CreateFontString()
        local text = NewWidget()
        self.strings[#self.strings + 1] = text
        return text
    end
    return widget
end

CreateFrame = function()
    local frame = NewWidget()
    created[#created + 1] = frame
    return frame
end
hooksecurefunc = function(object, method, callback)
    local original = object[method]
    hooks = hooks + 1
    object[method] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end
local function Original()
    calls = calls + 1
    return "original result"
end
MikSBT.Components.CombatEngine = { HandleEvent = Original }
MikSBT.Components.CombatPresentation = { Out = Original }
MikSBT.Components.OutgoingBatcher = {
    Queue = Original, DisplayRestricted = Original,
}
MikSBT.Display.Service = { DisplayEvent = Original }

-- Given the module loads during normal gameplay.
dofile("Combat/Trace.lua")
local trace = MikSBT.CombatTrace

-- When damage arrives before the player opts in.
MikSBT.Components.OutgoingBatcher:Queue(2973, 13)

-- Then no hooks or UI are created and normal behavior remains intact.
assert(#created == 0 and hooks == 0 and calls == 1)
assert(SLASH_MSBTDAMAGETRACE1 == "/msbttrace")

-- Given an opaque hit value that cannot be converted to text by Lua.
local opaque = setmetatable({}, {
    __tostring = function() error("trace inspected an opaque amount") end,
})
issecretvalue = function(value) return value == opaque end

-- When the player enables tracing and an actual spell hit is handled.
SlashCmdList.MSBTDAMAGETRACE()
assert(trace.active and #created == 1 and hooks == 5)
local result = MikSBT.Components.CombatEngine:HandleEvent(
    "UNIT_COMBAT", "target", "WOUND", "", opaque, 1)
MikSBT.Components.CombatPresentation:Out({
    event = "damage", amount = opaque,
    result = { who = "you", spell = 2973 },
})
MikSBT.Components.OutgoingBatcher:DisplayRestricted(2973, opaque)
MikSBT.Display.Service:DisplayEvent({}, "%s", "icon", nil, opaque)

-- Then all four stages retain the exact value without changing return values.
assert(result == "original result" and calls == 5)
assert(trace.sequence == 4 and #trace.rows == 4)
for index = 1, 4 do
    assert(trace.rows[index].value.args[1] == opaque)
end
assert(trace.rows[1].value.args[2] == 1,
    "raw hit tracing omitted the school needed to distinguish duplicate reports")
assert(trace.rows[1].value.args[3] == "",
    "raw hit tracing omitted the report flag")
assert(trace.rows[2].label.text:find("2973", 1, true))
assert(trace.rows[4].value.template == "%s")

-- Given repeated damage reports, including auto-attacks and zero amounts.
-- When more than a panel of damage is traced.
for index = 1, 50 do
    now = now + 0.01
    MikSBT.Components.OutgoingBatcher:Queue(6603, index % 2 == 0 and 0 or 13)
end

-- Then the panel is bounded and all normal calls still execute.
assert(#trace.rows == 18 and trace.sequence == 54 and calls == 55)
local last = trace.rows[(trace.sequence - 1) % 18 + 1]
assert(last.value.args[1] == 0, "zero-valued reports were hidden by the trace")

-- Given tracing is switched off.
SlashCmdList.MSBTDAMAGETRACE()
local previous = trace.sequence

-- When another hit arrives.
MikSBT.Components.OutgoingBatcher:Queue(2973, 13)

-- Then no trace is added, the panel is hidden, and combat keeps working.
assert(not trace.active and not created[1].shown)
assert(trace.sequence == previous and calls == 56)

-- Given tracing is switched on again.
-- When the command is used a second time.
SlashCmdList.MSBTDAMAGETRACE()

-- Then hooks and rows are reused, with no duplicate callbacks.
assert(hooks == 5 and #created == 1 and trace.sequence == 0)
MikSBT.Components.OutgoingBatcher:Queue(2973, 13)
assert(trace.sequence == 1 and calls == 57)

-- Given a fresh capture with opaque swing timing and a classified log line.
SlashCmdList.MSBTDAMAGETRACE()
SlashCmdList.MSBTDAMAGETRACE()
MikSBT.CombatEngine = { reader = {
    logLines = { { at = now, kind = "swing", source = "mine" } },
    swingTimes = { { at = now - 0.2, ranged = false } },
} }

-- When a melee swing, its log line and an extra attack reach the pipeline.
MikSBT.Components.CombatEngine:HandleEvent("PLAYER_SWING", opaque, 1)
MikSBT.Components.CombatEngine:HandleEvent(
    "COMBAT_LOG_MESSAGE", opaque, 0.9, 0.9, 0.9, 1)
now = now + 0.25
MikSBT.Components.CombatPresentation:Out({
    event = "damage", amount = opaque,
    result = { who = "you", melee = true, hand = "main", extra = true },
})

-- Then timing and extra-attack classification remain visible without reading
-- either the opaque duration or Blizzard's combat-log message.
assert(trace.sequence == 3, "trace omitted swing or combat-log timing")
assert(trace.rows[1].label.text:find("swing", 1, true))
assert(trace.rows[1].value.args[1] == opaque)
assert(trace.rows[2].label.text:find("swing", 1, true))
assert(trace.rows[2].value.args[1] == "mine")
assert(trace.rows[3].label.text:find("extra", 1, true))
assert(trace.rows[3].value.args[1] == opaque)
assert(math.abs((trace.rows[3].value.args[2] or -1) - 0.25) < 0.001,
    "match row omitted the age of the native swing event")
assert(math.abs((trace.rows[3].value.args[3] or -1) - 0.45) < 0.001,
    "match row omitted the age of the swing accepted by the reader")
assert(math.abs((trace.rows[3].value.args[4] or -1) - 0.25) < 0.001,
    "match row omitted the age of the latest own melee line")
assert(trace.rows[3].value.args[5] == "free")

-- Given a Windfury burst with one damage report and one failed attack.
SlashCmdList.MSBTDAMAGETRACE()
SlashCmdList.MSBTDAMAGETRACE()

-- When the target reports a dodge and the engine classifies its outcome.
MikSBT.Components.CombatEngine:HandleEvent(
    "UNIT_COMBAT", "target", "DODGE", "", 0, 1)
MikSBT.Components.CombatPresentation:Out({
    event = "miss", missWord = "Dodge", school = 1,
    result = { who = "other" },
})

-- Then the trace retains the failed attack instead of suggesting lost damage.
assert(trace.sequence == 2, "trace omitted the failed attack outcome")
assert(trace.rows[1].label.text:find("DODGE", 1, true))
assert(trace.rows[2].label.text:find("miss other", 1, true))
assert(trace.rows[2].value.args[1] == "Dodge")
print("Optional damage trace tests passed")
