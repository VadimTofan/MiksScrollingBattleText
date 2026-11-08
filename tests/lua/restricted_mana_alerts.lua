-- Describe: restricted mana is evaluated by native curve and text APIs.
local isHealth = TEST_HEALTH_ALERTS == true
local resourceName = isHealth and "Health" or "Mana"
local resourceEvent = isHealth and "UNIT_HEALTH" or "UNIT_POWER_UPDATE"
local nativeValues = {}
local function Secret(value)
	local token = newproxy(true)
	getmetatable(token).__lt = function() error("ordered a secret number") end
	getmetatable(token).__tostring = function() error("formatted a secret") end
	nativeValues[token] = value
	return token
end
local mana = Secret(1)
local frame, warnings, probeReads = nil, 0, 0
local shown = true
MikSBT = {
	Profiles = { currentProfile = {} }, Parser = {},
	Animations = { DisplayEvent = function(settings, message, _, mute)
		assert(message == "Low " .. resourceName .. "!")
		assert(settings.soundFile:match("Low" .. resourceName .. "%.ogg$"))
		assert(not mute, "alert bypassed normal sound settings")
		warnings = warnings + 1
	end },
}
canaccessvalue = function(value) return nativeValues[value] == nil end
dofile("API/RestrictedValue.lua")
Enum = { PowerType = { Mana = 0 }, LuaCurveType = { Linear = 0 } }
UnitClass = function() return "Mage", "MAGE" end
UnitPowerType = function() return 0 end
C_CurveUtil = { CreateCurve = function()
	local curve = { points = {} }
	function curve:SetType(kind) assert(kind == Enum.LuaCurveType.Linear) end
	function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
	return curve
end }
local function EvaluatePercent(curve)
	if not curve then return mana end
	-- Emulate native curve evaluation, which can consume secret numbers.
	local value = nativeValues[mana]
	for index = 2, #curve.points do
		local left, right = curve.points[index - 1], curve.points[index]
		if value <= right[1] then
			local fraction = (value - left[1]) / (right[1] - left[1])
			return Secret(left[2] + fraction * (right[2] - left[2]))
		end
	end
	error("curve did not cover the mana percentage")
end
if isHealth then
	UnitHealthPercent = function(unit, predicted, curve)
		assert(unit == "player" and predicted == false)
		return EvaluatePercent(curve)
	end
else
	UnitPowerPercent = function(_, _, _, curve)
		return EvaluatePercent(curve)
	end
end
C_StringUtil = { TruncateWhenZero = function(value)
	return Secret(math.floor(nativeValues[value]) == 0 and "" or "100")
end }
CreateFrame = function()
	frame = { events = {} }
	function frame:Hide() shown = false end
	function frame:RegisterUnitEvent(event) self.events[event] = true end
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:UnregisterAllEvents() self.events = {} end
	function frame:SetScript(_, handler) self.onEvent = handler end
	function frame:CreateFontString()
		return {
			SetText = function(self, text) self.text = text end,
			GetText = function(self)
				probeReads = probeReads + 1
				-- WoW collapses empty FontString text to nil; nonempty stays secret.
				if nativeValues[self.text] == "" then return nil end
				return self.text
			end,
		}
	end
	return frame
end

-- Given enabled alerts and full, secret mana.
dofile("MSBTTriggers.lua")
MikSBT.Triggers.Enable()
-- When the player enters the world.
frame.onEvent(frame, "PLAYER_ENTERING_WORLD")
-- Then full mana does not warn.
assert(warnings == 0)
assert(frame.events[resourceEvent], "player resource event was not registered")

-- Given secret mana below 35%.
mana = Secret(0.2)
-- When repeated player power events arrive.
frame.onEvent(frame, resourceEvent, "target")
assert(warnings == 0, "another unit triggered a player warning")
frame.onEvent(frame, resourceEvent, "player")
frame.onEvent(frame, resourceEvent, "player")
-- Then exactly one warning fires through the normal display path.
assert(warnings == 1, "restricted low mana did not produce one warning")
assert(probeReads > 0, "native text evaluation was not used")
assert(not shown, "scratch mana probe must remain hidden")

-- Given recovered secret mana.
mana = Secret(0.8)
frame.onEvent(frame, resourceEvent, "player")
-- When mana crosses below the threshold again.
mana = Secret(0.1)
frame.onEvent(frame, resourceEvent, "player")
-- Then the warning rearms even while raw mana remains restricted.
assert(warnings == 2, "restricted mana warning did not rearm")

-- Given a temporary native formatter failure after recovery.
mana = Secret(1)
frame.onEvent(frame, resourceEvent, "player")
local format = C_StringUtil.TruncateWhenZero
C_StringUtil.TruncateWhenZero = function() error("formatter unavailable") end
mana = Secret(0.1)
-- When the native probe fails.
frame.onEvent(frame, resourceEvent, "player")
-- Then the failed probe does not emit or latch an alert.
assert(warnings == 2)
C_StringUtil.TruncateWhenZero = format
frame.onEvent(frame, resourceEvent, "player")
assert(warnings == 3, "failed probe prevented later recovery")

-- Given a disabled runtime.
MikSBT.Triggers.Disable()
-- When a queued callback arrives.
frame.onEvent(frame, resourceEvent, "player")
-- Then no additional warning is emitted.
assert(warnings == 3 and next(frame.events) == nil)
print("Restricted mana alert tests passed")
