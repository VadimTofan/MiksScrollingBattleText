-- Describe: options move between standalone and Blizzard Settings layouts.
local function Noop() end
local frames = {}
local created = {}
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
	function frame:RegisterEvent(event) self.events = self.events or {} self.events[event] = true end
	function frame:UnregisterEvent(event) if self.events then self.events[event] = nil end end
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
local printed = {}
MikSBT.Print = function(value) printed[#printed + 1] = value end
MSBTOptions = {Controls = {CreateListbox = function(parent)
	return NewFrame(nil, parent)
end}, Popups = {UseDesignPopups = function() end}}
CreateFrame = function(_, name, parent)
	local frame = NewFrame(name, parent)
	created[#created + 1] = frame
	return frame
end
-- The questions asked and the reloads done, and the entering of the world for the frames that wait for it.
StaticPopupDialogs = {}
YES, NO = "Yes", "No"
local questions, reloads = {}, 0
StaticPopup_Show = function(which) questions[#questions + 1] = which end
ReloadUI = function() reloads = reloads + 1 end
local function EnterWorld()
	for _, frame in ipairs(created) do
		if frame.events and frame.events.PLAYER_ENTERING_WORLD and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
		end
	end
end
MikSBT.Profiles = {savedVariables = {}}
dofile("MSBTOptions/MSBTOptionsDesigns.lua")
dofile("MSBTOptions/MSBTOptionsMain.lua")
local options = MSBTOptions.Main
local openers = {}
local dock = options.DockMainFrame
options.DockMainFrame = function(panel, reopen, ...)
	openers[panel] = reopen
	return dock(panel, reopen, ...)
end
local designs = MSBTOptions.Designs
-- What the setup tells the registry about the design Settings shows.
local settingsCalls = {}
local setSettingsDesign = designs.SetSettingsDesign
designs.SetSettingsDesign = function(key, open)
	settingsCalls[#settingsCalls + 1] = { key = key, open = open }
	return setSettingsDesign(key, open)
end
-- Another design whose window is open.
local other = {shown = true}
function other.Show() other.shown = true end
function other.Hide() other.shown = false end
function other.IsShown() return other.shown end
designs.Register("other", other)
local general, scrollAreas = NewFrame(), NewFrame()
options.AddTab(general, "General")
options.AddTab(scrollAreas, "Scroll Areas")

local panels, currentPanel, rootIndex = {}, nil, nil
local function Register(panel)
	panels[#panels + 1] = panel
	local category = {ID = #panels}
	function category:GetID() return self.ID end
	panel.category = category
	return category
end
Settings = {
	RegisterCanvasLayoutCategory = function(panel)
		local category = Register(panel)
		rootIndex = category.ID
		return category
	end,
	RegisterCanvasLayoutSubcategory = function(_, panel) return Register(panel) end,
	RegisterAddOnCategory = Noop,
	OpenToCategory = function(id)
		if currentPanel then currentPanel:Hide() end
		-- The game's function takes the number the category got, the root category's too.
		assert(type(id) == "number", "Settings was asked to open a category by something but its number")
		currentPanel = panels[id]
		currentPanel:Show()
		SettingsPanel:Show()
	end,
}
local openedIds = {}
local openToCategory = Settings.OpenToCategory
Settings.OpenToCategory = function(id)
	openedIds[#openedIds + 1] = id
	return openToCategory(id)
end
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

-- Then the registry got the opener of the main panel, which opens Settings at the addon's own entry.
local call = settingsCalls[1]
assert(call and call.key == "classic" and type(call.open) == "function", "the classic setup gave no opener")
call.open()
assert(openedIds[#openedIds] == panels[1].category.ID and currentPanel == panels[1],
	"the classic opener did not open the addon's own category by its number")
HideUIPanel(SettingsPanel)

-- When the user opens Settings and switches categories.
Settings.OpenToCategory(1)
local main = frames.MSBTMainOptionsFrame
assert(main:GetParent() == panels[1] and general:IsShown(),
	"General did not dock when its category opened")
assert(not other.shown, "another design's window stayed open beside Settings")
Settings.OpenToCategory(2)

-- Then the selected tab is visible in its matching category.
assert(main:GetParent() == panels[2] and scrollAreas:IsShown(),
	"Scroll Areas did not dock when its category opened")
assert(not general:IsShown(), "previous tab stayed visible")

-- When the opener of the main panel runs from there.
openers[panels[1]]()

-- Then the addon's own category opens, by its number.
assert(currentPanel == panels[1],
	"the opener of the main panel did not open the addon's own category by its number")
Settings.OpenToCategory(2)

-- When the other design is chosen there and the options are requested.
designs.Select("other")
designs.Show()

-- Then the choice is saved, Settings keeps showing the options, and the choice asks to reload
-- instead of printing the hint.
assert(#printed == 0 and #questions == 1 and questions[1] == "MSBT_RELOAD_FOR_DESIGN",
	"a choice differing from Settings did not ask to reload")
assert(MikSBT.Profiles.savedVariables.optionsDesign == "other" and not other.shown
	and SettingsPanel:IsShown() and main:GetParent() == panels[2],
	"a design opened beside Settings")

-- Given the user temporarily closes Settings to configure scroll areas.
designs.Hide()
assert(not SettingsPanel:IsShown(), "Settings stayed open over configuration")

-- When configuration finishes and reopens the options.
designs.Show()

-- Then the same Settings category is restored, whichever design is chosen.
assert(SettingsPanel:IsShown() and main:GetParent() == panels[2] and not other.shown,
	"configuration did not reopen the Scroll Areas category")

-- Given the user closes Settings normally and chooses the classic design.
HideUIPanel(SettingsPanel)
designs.Select("classic")

-- When standalone options are requested.
designs.Show()

-- Then the window belongs to UIParent and is visible again.
assert(main:GetParent() == UIParent and main:IsShown(),
	"standalone options did not reopen after leaving Settings")

-- Then no hint came with the choice that Settings shows already.
assert(#printed == 0 and #questions == 1, "the choice of the design Settings shows said something")

-- Given a design that stands in Settings with a page of its own for each category.
local pageLog = {}
local docking = {shown = false}
function docking.Show() docking.shown = true end
function docking.Hide() docking.shown = false end
function docking.IsShown() return docking.shown end
function docking.DockPages()
	return {{key = "one", label = "One"}, {key = "two", label = "Two"}, {key = "three", label = "Three"}}
end
function docking.Dock(panel, key, openers) pageLog[#pageLog + 1] = {"dock", panel, key, openers} end
function docking.Undock(panel) pageLog[#pageLog + 1] = {"undock", panel} end
designs.Register("docking", docking)
designs.Select("docking")
local firstPanel = #panels + 1
-- Then the choice is a pending switch, with nothing printed or asked.
assert(#printed == 0 and #questions == 1 and designs.IsSwitchPending(),
	"choosing a design that Settings does not show printed or asked, or left no switch pending")

-- When Settings is set up with that design chosen.
setup()

-- Then its pages are the categories, the first one the addon's own, in the order of its list.
assert(#panels == firstPanel + 2, "the pages did not become three categories")
assert(panels[firstPanel].name == "MikScrollingBattleText" and panels[firstPanel + 1].name == "Two"
	and panels[firstPanel + 2].name == "Three", "the categories are not named after the pages")
assert(#printed == 0 and #questions == 1 and not designs.IsSwitchPending(),
	"the design chosen at the setup printed, asked or stayed a pending switch")

-- Then the registry got the opener of the first page, which opens Settings at the addon's own entry.
call = settingsCalls[#settingsCalls]
assert(call.key == "docking" and type(call.open) == "function", "the design's setup gave no opener")
call.open()
assert(openedIds[#openedIds] == panels[firstPanel].category.ID and currentPanel == panels[firstPanel],
	"the opener of the first page did not open the addon's own category by its number")
HideUIPanel(SettingsPanel)
pageLog = {}

-- When a category opens and closes.
panels[firstPanel + 1]:Show()
panels[firstPanel + 1]:Hide()

-- Then the design is told to dock the page with the openers, and to undock the same panel.
local dockCall, undockCall = pageLog[1], pageLog[2]
assert(dockCall and dockCall[1] == "dock" and dockCall[2] == panels[firstPanel + 1] and dockCall[3] == "two",
	"the panel did not dock its page")
assert(type(dockCall[4].one) == "function" and type(dockCall[4].two) == "function"
	and type(dockCall[4].three) == "function", "the design got no opener for a page")
assert(undockCall and undockCall[1] == "undock" and undockCall[2] == panels[firstPanel + 1],
	"the panel did not undock its page")

-- When the opener of the third page runs.
HideUIPanel(SettingsPanel)
pageLog = {}
dockCall[4].three()

-- Then Settings opens at that category.
assert(currentPanel == panels[firstPanel + 2] and pageLog[1][3] == "three", "an opener did not open its page")
HideUIPanel(SettingsPanel)

-- Given the classic design is chosen again, and the design that has no docking after it.
designs.Select("classic")
designs.Select("other")
local count = #panels

-- When Settings is set up with a choice that cannot dock, and with the classic design.
setup()
designs.Select("classic")
setup()

-- Then the classic tabs are the categories each time.
assert(#panels == count + 4, "the classic tabs were not registered")
for _, index in ipairs({count + 1, count + 3}) do
	assert(panels[index].name == "MikScrollingBattleText" and panels[index + 1].name == "Scroll Areas",
		"the classic tabs have other names")
end
assert(#printed == 0, "the choices printed a hint")

-- Given the options were reloaded for a new design, which left the flag.
MikSBT.Profiles.savedVariables.openSettingsAfterReload = true
designs.Select("classic")
count = #panels
openedIds = {}

-- When Settings is set up and the world is entered, twice.
setup()
assert(MikSBT.Profiles.savedVariables.openSettingsAfterReload == nil, "the flag stayed after the setup")
assert(#openedIds == 0, "Settings opened before the world was entered")
EnterWorld()
EnterWorld()

-- Then Settings opens once, at the addon's own category.
assert(#openedIds == 1 and openedIds[1] == panels[count + 1].category.ID and currentPanel == panels[count + 1],
	"Settings did not open once at the addon's own category")
HideUIPanel(SettingsPanel)

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
