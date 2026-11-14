local frames = {}
local object = {}
local formattedText
object.__index = function(_, key)
	if key == "SetTexture" then
		return function(self, value) self.texturePath = value end
	end
	if key == "SetPoint" then
		return function(self, ...) self.lastPoint = { ... } end
	end
	if key == "SetWidth" then
		return function(self, value) self.width = value end
	end
	if key == "SetHeight" then
		return function(self, value) self.height = value end
	end
	if key == "SetAlpha" then
		return function(self, value) self.lastAlpha = value end
	end
	if key == "SetFormattedText" then
		return function(_, ...) formattedText = { ... } end
	end
	if key == "CreateFontString" or key == "CreateTexture" then
		return function() return setmetatable({}, object) end
	end
	if key == "SetScript" then
		return function(self, event, handler) self[event] = handler end
	end
	if key == "Show" then return function(self) self.visible = true end end
	if key == "Hide" then return function(self) self.visible = false end end
	if key == "IsVisible" then return function(self) return self.visible end end
	return function() end
end
CreateFrame = function()
	local frame = setmetatable({}, object)
	frames[#frames + 1] = frame
	return frame
end
local displayConfig
MikSBT = {
	Media = {fonts = {}},
	Profiles = {
		currentProfile = {animationSpeed = 100},
		IsModDisabled = function() return false end,
	},
	translations = {FONT_FILES = {Default = "font"}, DEFAULT_FONT_NAME = "Default"},
	Display = {
		ScrollAreas = {areas = {}, Configure = function() end},
		Service = {Configure = function(_, config) displayConfig = config end},
	},
}
dofile("API/RestrictedValue.lua")
local file = assert(io.open("Display/AnimationEngine.lua", "rb"))
local source = file:read("*a"):gsub("^\239\187\191", "")
file:close()
assert(loadstring(source))()
local animationFrame = frames[1]
local weakAreas = setmetatable({}, {__mode = "k"})
local function initialize(event)
	event.animationHandler = function() end
end
MikSBT.Animations.RegisterAnimationStyle("Straight", initialize)
MikSBT.Animations.RegisterStickyAnimationStyle("Pow", initialize)

-- Given two opaque values for a resource-gain notification.
local hiddenAmount, hiddenName = {}, {}
issecretvalue = function(value) return value == hiddenAmount or value == hiddenName end
-- When the animation renderer creates its font string.
displayConfig.display("+%s %s", {}, false, 1, 1, 1, 18, "font", 1, 100,
	nil, hiddenAmount, hiddenName)
-- Then WoW's text widget receives both values without inspection.
assert(formattedText[1] == "+%s %s")
assert(formattedText[2] == hiddenAmount)
assert(formattedText[3] == hiddenName, "font string lost the hidden resource name")
animationFrame:OnUpdate(4)

-- Given fresh normal and sticky scroll-area settings from repeated profiles.
for index = 1, 100 do
	local area = {}
	weakAreas[area] = true
	displayConfig.display("text", area, false, 1, 1, 1, 18, "font", 1, 100)
	displayConfig.display("crit", area, true, 1, 1, 1, 18, "font", 1, 100)

	-- When all animations finish and external references are dropped.
	animationFrame:OnUpdate(4)
end
animationFrame:OnUpdate(0.02)
collectgarbage("collect")

-- Then completed animation buckets do not keep the area tables alive.
assert(next(weakAreas) == nil, "finished scroll-area tables remain referenced")
assert(not animationFrame:IsVisible(), "idle animation frame remains visible")

-- Given an animation which is still running.
local activeArea = {}
weakAreas[activeArea] = true
displayConfig.display("active", activeArea, false, 1, 1, 1, 18, "font", 1, 100)
activeArea = nil

-- When less than its duration elapses.
animationFrame:OnUpdate(0.1)
collectgarbage("collect")

-- Then the active animation remains owned until completion.
assert(next(weakAreas) ~= nil, "active animation lost its scroll area")
animationFrame:OnUpdate(4)
collectgarbage("collect")
assert(next(weakAreas) == nil, "last completed animation retained its area")

-- Describe: iconless damage stays iconless when the active-area limit is full.
local initializedEvents = {}
local function CaptureIconEvent(event)
	initializedEvents[#initializedEvents + 1] = event
	event.animationHandler = function() end
end
MikSBT.Animations.RegisterAnimationStyle("Iconless", CaptureIconEvent)
MikSBT.Animations.RegisterStickyAnimationStyle("Iconless", CaptureIconEvent)
for _, sticky in ipairs({ false, true }) do
	-- Given fifteen active lines with identified spell icons in one area.
	local area = {
		animationStyle = "Iconless", stickyAnimationStyle = "Iconless",
		iconAlign = sticky and "Right" or "Left",
	}
	initializedEvents = {}
	for index = 1, 15 do
		displayConfig.display("Known spell", area, sticky,
			1, 1, 1, 18, "font", 1, 100, "known-spell-icon")
	end
	local oldestEvent = initializedEvents[1]
	local oldestTexture = oldestEvent.texture
	assert(oldestTexture ~= nil)

	-- When unknown spell damage replaces the oldest line with no supplied icon.
	displayConfig.display("42", area, sticky,
		1, 1, 1, 18, "font", 1, 100, nil)

	-- Then the reused line has no texture for animation or icon spacing.
	assert(initializedEvents[16] == oldestEvent)
	assert(oldestEvent.texture == nil,
		"iconless damage inherited an icon at the active-area limit")
	assert(oldestTexture.lastAlpha == 0 and rawget(oldestTexture, "texturePath") == nil)

	-- When more known spells make that same line display an icon again.
	for index = 1, 15 do
		displayConfig.display("Known again", area, sticky,
			1, 1, 1, 18, "font", 1, 100, "restored-spell-icon")
	end

	-- Then its restored icon uses the configured side and normal dimensions.
	assert(initializedEvents[31] == oldestEvent)
	local restoredTexture = oldestEvent.texture
	assert(restoredTexture and restoredTexture.texturePath == "restored-spell-icon")
	assert(restoredTexture.width == 18 and restoredTexture.height == 18)
	assert(restoredTexture.lastPoint[1] == (sticky and "LEFT" or "RIGHT"))
	assert(restoredTexture.lastPoint[2] == oldestEvent.fontString)
	assert(restoredTexture.lastPoint[3] == (sticky and "RIGHT" or "LEFT"))
	assert(restoredTexture.lastPoint[4] == (sticky and 4 or -4))
	animationFrame:OnUpdate(4)
end

-- Describe: native visibility controls text and icons without Lua arithmetic.
-- Given a secret visibility boolean and native-only alpha selector.
local opaqueVisibility, opaqueAlpha = {}, {}
issecretvalue = function(value)
	return value == opaqueVisibility or value == opaqueAlpha
end
local selectedAlpha
C_CurveUtil = { EvaluateColorValueFromBoolean = function(gate, yes, no)
	assert(gate == opaqueVisibility)
	selectedAlpha = { yes, no }
	return opaqueAlpha
end }
local gatedEvent
MikSBT.Animations.RegisterAnimationStyle("Gated", function(event)
	gatedEvent = event
	event.animationHandler = function() end
end)
local gate = { visible = opaqueVisibility }
local gatedArea = { animationStyle = "Gated" }
-- When a gated notification animates, including its fade.
assert(type(displayConfig.displayWithVisibility) == "function",
	"animation renderer is missing native visibility support")
displayConfig.displayWithVisibility(gate, "Aura", gatedArea, false,
	1, 1, 1, 18, "font", 1, 80, "aura-icon")
animationFrame:OnUpdate(0.1)
-- Then native selection controls both regions with the same opaque alpha.
assert(gatedEvent.fontString.lastAlpha == opaqueAlpha)
assert(gatedEvent.texture.lastAlpha == opaqueAlpha)
assert(selectedAlpha[1] == 0.8 and selectedAlpha[2] == 0)
animationFrame:OnUpdate(2.5)
assert(selectedAlpha[1] < 0.8 and selectedAlpha[1] > 0)
assert(gatedEvent.fontString.lastAlpha == opaqueAlpha)
animationFrame:OnUpdate(1)
-- Then completed cached events release the secret visibility reference.
assert(gatedEvent.visibility == nil)

-- Given a normal event reusing a previously gated cache entry.
-- When it animates without a filter.
displayConfig.display("Normal", gatedArea, false,
	1, 1, 1, 18, "font", 1, 80, "normal-icon")
animationFrame:OnUpdate(0.1)
-- Then no hidden gate leaks into the normal message or icon.
assert(gatedEvent.fontString.lastAlpha == 0.8)
assert(gatedEvent.texture.lastAlpha == 0.8)
animationFrame:OnUpdate(4)

-- Given a native selector that becomes unavailable after enqueueing.
C_CurveUtil.EvaluateColorValueFromBoolean = function()
	error("native selector unavailable")
end
-- When the queued secret aura animates.
displayConfig.displayWithVisibility(gate, "Fallback", gatedArea, false,
	1, 1, 1, 18, "font", 1, 80, "aura-icon")
animationFrame:OnUpdate(0.1)
-- Then its original visibility survives without repeated animation errors.
assert(gatedEvent.fontString.lastAlpha == 0.8)
assert(gatedEvent.texture.lastAlpha == 0.8)
assert(gatedEvent.visibility == nil)
animationFrame:OnUpdate(4)
