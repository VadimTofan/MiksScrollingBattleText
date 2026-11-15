-- Describe: scrolling text moves on every frame, whatever the frame rate.
local frames = {}
local object = {}
object.__index = function(_, key)
	if key == "SetPoint" then
		return function(self, _, _, y)
			rawset(self, "moves", (rawget(self, "moves") or 0) + 1)
			rawset(self, "lastY", y)
		end
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
local current
MikSBT.Animations.RegisterAnimationStyle("Straight", function(displayEvent)
	current = displayEvent
	displayEvent.animationHandler = function(event, percentDone)
		event.positionY = percentDone * event.scrollHeight
	end
end)

for _, fps in ipairs({ 60, 144, 240 }) do
	-- Given a scrolling message on a display drawing this many frames a second.
	displayConfig.display("text", {}, false, 1, 1, 1, 18, "font", 1, 100)
	local fontString = current.fontString
	local frameTime = 1 / fps

	-- When a second of frames is drawn.
	local still, steps, lastY = 0, {}, rawget(fontString, "lastY")
	for _ = 1, fps do
		local moves = rawget(fontString, "moves") or 0
		animationFrame:OnUpdate(frameTime)
		if (rawget(fontString, "moves") or 0) == moves then
			still = still + 1
		else
			steps[#steps + 1] = rawget(fontString, "lastY") - lastY
			lastY = rawget(fontString, "lastY")
		end
	end

	-- Then the text moved on every frame, by the same distance each time.
	assert(still == 0, fps .. " fps: the text stood still on " .. still .. " of " .. fps .. " frames")
	local least, most = math.huge, -math.huge
	for _, step in ipairs(steps) do
		least, most = math.min(least, step), math.max(most, step)
	end
	assert(most - least < 1e-6, fps .. " fps: uneven steps from " .. least .. " to " .. most)

	-- (the message finishes before the next frame rate)
	animationFrame:OnUpdate(4)
end
