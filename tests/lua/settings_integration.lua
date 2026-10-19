-- Describe: options move between standalone and Blizzard Settings layouts.
local function Noop() end
local frames = {}
local function NewFrame(name, parent)
	local frame = {
		name = name, parent = parent, scripts = {}, regions = {},
		shown = false, width = 800, height = 600, level = 0,
	}
	setmetatable(frame, {__index = function(_, key)
		if key:match("^[A-Z]") then return Noop end
	end})
	function frame:GetName() return self.name end
	function frame:GetParent() return self.parent end
	function frame:SetParent(value) self.parent = value end
	function frame:GetWidth() return self.width end
	function frame:GetHeight() return self.height end
	function frame:SetWidth(value) self.width = value end
	function frame:SetHeight(value) self.height = value end
	function frame:GetFrameLevel() return self.level end
	function frame:SetFrameLevel(value) self.level = value end
	function frame:GetFrameStrata() return self.strata or "DIALOG" end
	function frame:SetFrameStrata(value) self.strata = value end
	function frame:SetScript(event, callback) self.scripts[event] = callback end
	function frame:HookScript(event, callback) self.scripts[event] = callback end
	function frame:IsShown() return self.shown end
	function frame:Show()
		if self.shown then return end
		self.shown = true
		if self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function frame:Hide()
		if not self.shown then return end
		self.shown = false
		if self.scripts.OnHide then self.scripts.OnHide(self) end
	end
	function frame:SetShown(value)
		if value then self:Show() else self:Hide() end
	end
	function frame:CreateTexture()
		local region = NewFrame()
		self.regions[#self.regions + 1] = region
		return region
	end
	frame.CreateFontString = frame.CreateTexture
	function frame:GetRegions() return unpack(self.regions) end
	if name then frames[name] = frame end
	return frame
end

UIParent = NewFrame("UIParent")
UISpecialFrames = {}
PlaySound = Noop
SOUNDKIT = {IG_MAINMENU_OPTION = 1}
MikSBT = {
	VERSION_STRING = "test",
	Compatibility = {Client = {hasModernAPI = true}},
	translations = {TABS = {general = {label = "General"}}},
}
MSBTOptions = {Controls = {CreateListbox = function(parent)
	return NewFrame(nil, parent)
end}}
CreateFrame = function(_, name, parent) return NewFrame(name, parent) end
dofile("MSBTOptions/MSBTOptionsMain.lua")
local options = MSBTOptions.Main
local general, scrollAreas = NewFrame(), NewFrame()
options.AddTab(general, "General")
options.AddTab(scrollAreas, "Scroll Areas")

local panels, currentPanel = {}, nil
local function Register(panel)
	panels[#panels + 1] = panel
	local category = {ID = #panels}
	function category:GetID() return self.ID end
	return category
end
Settings = {
	RegisterCanvasLayoutCategory = Register,
	RegisterCanvasLayoutSubcategory = function(_, panel) return Register(panel) end,
	RegisterAddOnCategory = Noop,
	OpenToCategory = function(id)
		if currentPanel then currentPanel:Hide() end
		-- The root category uses its name as its ID.
		currentPanel = panels[type(id) == "string" and 1 or id]
		currentPanel:Show()
		SettingsPanel:Show()
	end,
}
SettingsPanel = NewFrame("SettingsPanel")
HideUIPanel = function(frame)
	frame:Hide()
	if currentPanel then currentPanel:Hide() end
end
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local setupSource = assert(source:match(
	"(local function SetupBlizzardOptions%(%)%s*.-)local function SetBlizzardCombatTextV2Enabled"
))
local setup = assert(loadstring(setupSource .. "\nreturn SetupBlizzardOptions"))()

-- Given embedded options with General and Scroll Areas tabs.
setup()
assert(#panels == 2, "Settings did not register both tabs")

-- When the user opens Settings and switches categories.
Settings.OpenToCategory(1)
local main = frames.MSBTMainOptionsFrame
assert(main:GetParent() == panels[1] and general:IsShown(),
	"General did not dock when its category opened")
Settings.OpenToCategory(2)

-- Then the selected tab is visible in its matching category.
assert(main:GetParent() == panels[2] and scrollAreas:IsShown(),
	"Scroll Areas did not dock when its category opened")
assert(not general:IsShown(), "previous tab stayed visible")

-- Given the user temporarily closes Settings to configure scroll areas.
options.HideMainFrame()
assert(not SettingsPanel:IsShown(), "Settings stayed open over configuration")

-- When configuration finishes and reopens the options.
options.ShowMainFrame()

-- Then the same Settings category is restored.
assert(SettingsPanel:IsShown() and main:GetParent() == panels[2],
	"configuration did not reopen the Scroll Areas category")

-- Given the user closes Settings normally.
HideUIPanel(SettingsPanel)

-- When standalone options are requested.
options.ShowMainFrame()

-- Then the window belongs to UIParent and is visible again.
assert(main:GetParent() == UIParent and main:IsShown(),
	"standalone options did not reopen after leaving Settings")

-- Given an options module which failed to load.
MSBTOptions = nil
local message
Print = function(value) message = value end
local panelCount = #panels

-- When Settings integration is initialized.
setup()

-- Then a clear diagnostic replaces an unusable Settings entry.
assert(message and message:find("options are unavailable", 1, true),
	"missing options did not produce a clear diagnostic")
assert(#panels == panelCount, "missing options registered an unusable panel")
