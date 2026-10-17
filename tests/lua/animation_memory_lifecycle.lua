local frames = {}
local object = {}
object.__index = function(_, key)
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
