-- Describe: the options window comes in designs; one is chosen and only one is open at a time.
local function Noop() end
local saved = {}
local docked = false
MikSBT = { Profiles = { savedVariables = saved } }
MSBTOptions = { Main = { IsDocked = function() return docked end, ShowMainFrame = Noop } }

local log = {}
local function Events()
	local text = table.concat(log, ", ")
	log = {}
	return text
end
-- A design whose window records when it opens and closes.
local function NewDesign(key)
	local design = { label = key:upper() }
	function design.Show() design.shown = true log[#log + 1] = "show " .. key end
	function design.Hide(comesBack)
		design.shown = false
		log[#log + 1] = (comesBack and "put away " or "hide ") .. key
	end
	function design.IsShown() return design.shown == true end
	return design
end
-- A fresh registry with the given designs, in that order.
local function LoadDesigns(...)
	dofile("MSBTOptions/MSBTOptionsDesigns.lua")
	local windows = {}
	for _, key in ipairs({ ... }) do
		windows[key] = NewDesign(key)
		MSBTOptions.Designs.Register(key, windows[key])
	end
	return MSBTOptions.Designs, windows
end
local function Read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

-- Given the classic design and another one, and no choice saved.
local Designs, windows = LoadDesigns("classic", "other")
-- Then the classic design is the selected one.
assert(Designs.GetSelected() == "classic", "without a choice the design is not the classic one")

-- Given the saved choice of a design that is not there.
saved.optionsDesign = "gone"
-- When the options are opened.
Designs.Show()
-- Then the classic design opens and the choice stays saved.
assert(Designs.GetSelected() == "classic", "a design that is not there was selected")
assert(Events() == "show classic", "a missing design did not open the classic one")
assert(saved.optionsDesign == "gone", "the choice of a missing design was dropped")

-- Given the other design is chosen while the classic window is open.
saved.optionsDesign = "other"
-- When the options are opened.
Designs.Show()
-- Then the classic window closes first: only one design is open at a time.
assert(Designs.GetSelected() == "other", "the saved design is not selected")
assert(Events() == "hide classic, show other", "another design's window stayed open")
-- When every window but one is to close.
Designs.HideOthers("other")
assert(Events() == "", "the named design's own window was closed")
Designs.HideOthers("classic")
-- Then a window of another design closes and the named one would stay.
assert(Events() == "hide other", "another design's window was not closed")
-- Given two windows open at once, as when a design's frame shows the moment it is created.
windows.classic.shown = true
windows.other.shown = true
-- When every window but the first one registered is to close.
Designs.HideOthers("classic")
-- Then the other one closes although the first one is open too.
assert(Events() == "hide other", "a window stayed open behind the first one shown")
windows.classic.shown = false

-- Given no window is open.
saved.optionsDesign = nil
-- When a design is chosen.
-- Then the choice is only saved.
assert(Designs.Select("other") and saved.optionsDesign == "other", "the choice was not saved")
assert(Events() == "", "a choice opened the options although no window was open")
-- Given its window is open.
Designs.Show()
Events()
-- When the classic design is chosen.
-- Then it is saved as no choice and the open window switches at once.
assert(Designs.Select("classic") and saved.optionsDesign == nil,
	"the classic design was not saved as no choice")
assert(Events() == "hide other, show classic", "the open window did not switch to the choice")
-- When a design that is not there is chosen.
-- Then it is refused.
assert(not Designs.Select("gone") and saved.optionsDesign == nil and Events() == "",
	"a design that is not there was chosen")

-- Given the classic window is open while the other design is chosen.
saved.optionsDesign = "other"
-- When the options are put away and opened again.
Designs.Hide()
-- Then the design learns that its window comes back, and the design put away comes back, once.
assert(Events() == "put away classic", "the open window was not put away to come back")
Designs.Show()
assert(Events() == "show classic", "the design put away did not come back")
windows.classic.shown = false
Designs.Show()
assert(Events() == "show other", "the design put away came back a second time")
-- When nothing is open and the options are put away.
windows.other.shown = false
Designs.Hide()
Designs.Show()
-- Then the chosen design opens as usual.
assert(Events() == "show other", "putting nothing away changed what opens")
-- Given the open window is put away.
Designs.Hide()
Events()
-- When another design is chosen meanwhile and the options are opened.
assert(Designs.Select("classic") and Events() == "", "a choice opened a window while the options were put away")
Designs.Show()
-- Then the choice opens, not the design put away.
assert(Events() == "show classic", "the design put away won over a choice made meanwhile")

-- Given the game's settings window shows the options.
windows.other.shown = false
windows.classic.shown = true
docked = true
-- When the options are opened or a design is chosen.
Designs.Show()
-- Then no window opens beside it and the choice is only saved.
assert(Events() == "", "a window opened beside the game's settings window")
assert(Designs.Select("classic") and saved.optionsDesign == nil and Events() == "",
	"a choice inside the game's settings window moved a window")
docked = false
windows.classic.shown = false

-- Given another design stands in the game's settings window, and the classic window does not.
windows.other.shown = true
local otherDocked = true
function windows.other.IsDocked() return otherDocked end
-- When the options are opened.
Designs.Show()
-- Then no window opens beside it, whichever design stands there.
assert(Events() == "", "a window opened beside another design standing in the game's settings window")
-- When that design leaves the game's settings window.
otherDocked = false
Designs.Show()
-- Then the options open as usual.
assert(Events() == "hide other, show classic", "a design that left the game's settings window kept the options from opening")
windows.classic.shown = false
windows.other.IsDocked = nil
windows.other.shown = false

-- Rule: a choice that differs from the design the game's settings window shows leaves a switch pending.
do
	local printed, questions = {}, {}
	MikSBT.Print = function(message) printed[#printed + 1] = message end
	StaticPopup_Show = function(which) questions[#questions + 1] = which end

	-- Given the window shows no design yet, as before the options are registered.
	-- When a design is chosen.
	Designs.Select("other")
	-- Then no switch is pending.
	assert(not Designs.IsSwitchPending(), "a switch was pending before the game's settings window was set up")

	-- Given the game's settings window shows the classic design.
	Designs.SetSettingsDesign("classic")
	-- When the other design is chosen outside the game's settings window.
	Designs.Select("other")
	-- Then the switch is pending, and nothing is printed or asked.
	assert(Designs.IsSwitchPending(), "a choice differing from the settings window left no switch pending")
	assert(#printed == 0 and #questions == 0, "a choice outside the settings window printed or asked")
	-- When the same design as the settings window is chosen, and one that is not there.
	Designs.Select("classic")
	assert(not Designs.IsSwitchPending(), "the settings window's own design left a switch pending")
	Designs.Select("other")
	Designs.Select("gone")
	-- Then the earlier choice still stands.
	assert(Designs.IsSwitchPending(), "a design that is not there ended the pending switch")

	-- Given the game's settings window shows the other design.
	Designs.SetSettingsDesign("other")
	-- Then the other design as the choice is no switch.
	assert(not Designs.IsSwitchPending(), "the settings window's own further design left a switch pending")
	-- When the classic design is chosen.
	Designs.Select("classic")
	-- Then the switch is pending.
	assert(Designs.IsSwitchPending(), "a choice differing from a further design in the settings window left no switch pending")
	saved.optionsDesign = nil
	Designs.SetSettingsDesign(nil)
end

-- Rule: a differing choice made inside the game's settings window asks to reload.
do
	local printed, questions, reloads, flagAtReload = {}, {}, 0, nil
	MikSBT.Print = function(message) printed[#printed + 1] = message end
	MikSBT.translations = { MSG_DESIGN_ASK_RELOAD = "reload now?" }
	StaticPopupDialogs = {}
	YES, NO = "Yes", "No"
	StaticPopup_Show = function(which) questions[#questions + 1] = which end
	ReloadUI = function()
		reloads = reloads + 1
		flagAtReload = saved.openSettingsAfterReload
	end
	Designs.SetSettingsDesign("classic")

	-- Given the options stand in the game's settings window.
	docked = true
	-- When the other design is chosen.
	Designs.Select("other")
	-- Then the question is shown, nothing is printed, and nothing is reloaded yet.
	assert(#questions == 1 and #printed == 0, "a choice inside the settings window did not ask to reload")
	local dialog = StaticPopupDialogs[questions[1]]
	assert(dialog and dialog.text == "reload now?" and dialog.button1 == "Yes" and dialog.button2 == "No"
		and dialog.timeout == 0 and dialog.whileDead and dialog.hideOnEscape, "the question is not as expected")
	assert(reloads == 0 and saved.openSettingsAfterReload == nil, "the interface reloaded before the answer")

	-- When the question is accepted.
	dialog.OnAccept()
	-- Then the flag is saved before the interface reloads.
	assert(reloads == 1 and flagAtReload == "settings", "accepting did not save the flag before the reload")

	-- When the same design as the settings window shows is chosen.
	Designs.Select("classic")
	-- Then nothing is asked and nothing is printed.
	assert(#questions == 1 and #printed == 0, "the choice of the settings window's own design said something")

	-- Given the options stand outside the game's settings window.
	docked = false
	-- When the other design is chosen.
	Designs.Select("other")
	-- Then nothing is printed and no further question is shown.
	assert(#printed == 0 and #questions == 1, "a choice outside the settings window printed or asked")
	saved.optionsDesign = nil
	saved.openSettingsAfterReload = nil
	Designs.SetSettingsDesign(nil)
end

-- Rule: the reload for a design saves where the interface opens afterwards.
do
	local reloads, flagAtReload = 0, nil
	ReloadUI = function()
		reloads = reloads + 1
		flagAtReload = saved.openSettingsAfterReload
	end
	-- When the interface is reloaded for the options window.
	Designs.ReloadForDesign("window")
	-- Then the flag holds that place when the interface reloads.
	assert(reloads == 1 and flagAtReload == "window", "the reload did not save where to open afterwards")
	saved.openSettingsAfterReload = nil
end

-- Rule: after a reload for a new design, the game's settings window opens once at the first PLAYER_ENTERING_WORLD.
do
	local waiting, opened = {}, 0
	CreateFrame = function()
		local frame = { scripts = {}, events = {} }
		function frame:RegisterEvent(event) self.events[event] = true end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:SetScript(event, handler) self.scripts[event] = handler end
		waiting[#waiting + 1] = frame
		return frame
	end
	local function Open() opened = opened + 1 end
	local function EnterWorld()
		for _, frame in ipairs(waiting) do
			if frame.events.PLAYER_ENTERING_WORLD then frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD") end
		end
	end

	-- Given no flag is saved.
	-- When the settings design is set and the world is entered.
	Designs.SetSettingsDesign("classic", Open)
	EnterWorld()
	-- Then nothing waits and nothing opens.
	assert(#waiting == 0 and opened == 0, "the settings window opened without the flag")

	-- Given the flag is saved.
	saved.openSettingsAfterReload = true
	-- When the settings design is set.
	Designs.SetSettingsDesign("classic", Open)
	-- Then the flag is cleared and the window waits for the world.
	assert(saved.openSettingsAfterReload == nil, "the flag was not cleared")
	assert(opened == 0, "the settings window opened before the world was entered")
	-- When the world is entered, twice.
	EnterWorld()
	EnterWorld()
	-- Then the window opens once.
	assert(opened == 1, "the settings window did not open exactly once")

	-- Given the flag of an earlier build, which is true.
	saved.openSettingsAfterReload = true
	-- When the settings design is set and the world is entered.
	Designs.SetSettingsDesign("classic", Open)
	EnterWorld()
	-- Then the game's settings window opens once more, and the flag is cleared.
	assert(opened == 2 and saved.openSettingsAfterReload == nil, "the flag of an earlier build did not open the settings window")

	-- Given the flag is saved but there is no opener.
	saved.openSettingsAfterReload = true
	-- When the settings design is set.
	Designs.SetSettingsDesign("classic")
	-- Then the flag is cleared and nothing waits.
	assert(saved.openSettingsAfterReload == nil and #waiting == 2, "a missing opener left the flag or a waiting frame")
	Designs.SetSettingsDesign(nil)
end

-- Rule: after a reload for the options window, that window opens once in the chosen design.
do
	local waiting, opened = {}, 0
	CreateFrame = function()
		local frame = { scripts = {}, events = {} }
		function frame:RegisterEvent(event) self.events[event] = true end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:SetScript(event, handler) self.scripts[event] = handler end
		waiting[#waiting + 1] = frame
		return frame
	end
	local function Open() opened = opened + 1 end
	local function EnterWorld()
		for _, frame in ipairs(waiting) do
			if frame.events.PLAYER_ENTERING_WORLD then frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD") end
		end
	end
	Designs, windows = LoadDesigns("classic", "other")
	saved.optionsDesign = "other"
	Events()

	-- Given the flag says the options window.
	saved.openSettingsAfterReload = "window"
	-- When the settings design is set with an opener.
	Designs.SetSettingsDesign("classic", Open)
	-- Then the flag is cleared and nothing opens before the world is entered.
	assert(saved.openSettingsAfterReload == nil and Events() == "", "the options opened before the world was entered")
	-- When the world is entered, twice.
	EnterWorld()
	EnterWorld()
	-- Then the chosen design opens once, and the settings window does not.
	assert(Events() == "show other" and opened == 0, "the options window did not open once in the chosen design")

	-- Given the flag says the settings window, as in the game's own question.
	windows.other.shown = false
	saved.openSettingsAfterReload = "settings"
	Designs.SetSettingsDesign("classic", Open)
	EnterWorld()
	-- Then only the settings window opens.
	assert(opened == 1 and Events() == "", "the settings flag opened the options window")
	saved.optionsDesign = nil
	Designs.SetSettingsDesign(nil)
end

-- The General tab's functions with its controls replaced by recorders.
local tabs = Read("MSBTOptions/MSBTOptionsTabs.lua")
local function BuildGeneralTab(designs)
	local function NewControl()
		local control = setmetatable({ items = {} }, { __index = function() return Noop end })
		function control:AddItem(text, id) self.items[#self.items + 1] = text .. "=" .. id end
		function control:SetChangeHandler(handler) self.change = handler end
		function control:SetSelectedID(id) self.selected = id end
		function control:GetWidth() return 0 end
		function control:Show() self.shown = true end
		function control:Hide() self.shown = false end
		function control:SetClickHandler(handler) self.click = handler end
		function control:SetPoint(...) self.point = { ... } end
		return control
	end
	local build = assert(loadstring(
		assert(tabs:match("local function GeneralTab_ShowReloadButton%b()%s*.-\nend")) .. "\n"
		.. assert(tabs:match("local function GeneralTab_Create%b()%s*.-\nend")) .. "\n"
		.. assert(tabs:match("GeneralTab_Populate = function%b()%s*.-\nend"))
		.. "\nreturn GeneralTab_Create, GeneralTab_Populate"))
	local frame = { CreateFontString = NewControl, CreateTexture = NewControl }
	setfenv(build, {
		ipairs = ipairs,
		math = math,
		tabFrames = { general = frame },
		MSBTControls = {
			CreateCheckbox = NewControl, CreateSlider = NewControl,
			CreateOptionButton = NewControl, CreateDropdown = NewControl,
		},
		L = setmetatable({}, { __index = function()
			return setmetatable({}, { __index = function(_, key) return { label = key } end })
		end }),
		MSBTDesigns = designs,
		MSBTOptMain = MSBTOptions.Main,
		MSBTProfiles = { currentProfile = {}, savedVariables = saved, IsModDisabled = Noop },
	})
	local create, populate = build()
	create()
	populate()
	return frame.controls.optionsDesignDropdown, frame.controls, populate
end

-- Given two designs, the second one chosen.
saved.optionsDesign = "other"
-- When the General tab is opened.
local dropdown = BuildGeneralTab(Designs)
-- Then it offers every design with its label in the order they registered, the chosen one shown.
assert(dropdown, "the General tab does not offer the choice between two designs")
assert(table.concat(dropdown.items, " ") == "CLASSIC=classic OTHER=other",
	"the designs are not listed with their labels in order")
assert(dropdown.selected == "other", "the selected design is not shown")
-- When another design is picked there.
dropdown.change(dropdown, "classic")
-- Then the pick is saved.
assert(saved.optionsDesign == nil, "a pick in the General tab was not saved")

-- Rule: the General tab shows a reload button beside the design choice while a switch is pending.
do
	local reloads, flagAtReload = 0, nil
	ReloadUI = function()
		reloads = reloads + 1
		flagAtReload = saved.openSettingsAfterReload
	end
	-- Given the game's settings window shows the classic design, which is chosen.
	Designs.SetSettingsDesign("classic")
	saved.optionsDesign = nil
	-- When the General tab is opened.
	local dropdown, controls, populate = BuildGeneralTab(Designs)
	-- Then the button is hidden.
	assert(controls.reloadDesignButton and controls.reloadDesignButton.shown == false,
		"the reload button shows without a pending switch")
	-- And it stands under the choice at its left edge, clear of the Blizzard column beside it.
	local point = controls.reloadDesignButton.point
	assert(point[1] == "TOPLEFT" and point[2] == dropdown and point[3] == "BOTTOMLEFT" and point[4] == 0,
		"the reload button does not stand under the design choice")
	-- When the other design is picked.
	dropdown.change(dropdown, "other")
	-- Then the button shows.
	assert(controls.reloadDesignButton.shown == true, "the reload button did not show for a pending switch")
	-- When the classic design is picked again.
	dropdown.change(dropdown, "classic")
	-- Then it is hidden again.
	assert(controls.reloadDesignButton.shown == false, "the reload button stayed after the switch was undone")
	-- When the choice changes elsewhere and the tab is filled again.
	saved.optionsDesign = "other"
	populate()
	-- Then the button shows.
	assert(controls.reloadDesignButton.shown == true, "filling the tab did not show the reload button")

	-- When the button is clicked outside the game's settings window.
	docked = false
	controls.reloadDesignButton.click()
	-- Then the interface reloads to open the options window.
	assert(reloads == 1 and flagAtReload == "window", "the button outside the settings window did not reload for the window")
	-- When it is clicked inside the game's settings window.
	docked = true
	controls.reloadDesignButton.click()
	-- Then the interface reloads to open the settings window.
	assert(reloads == 2 and flagAtReload == "settings", "the button inside the settings window did not reload for it")
	docked = false
	saved.optionsDesign = nil
	saved.openSettingsAfterReload = nil
	Designs.SetSettingsDesign(nil)
end

-- Given the classic design alone.
local alone = LoadDesigns("classic")
-- When the General tab is opened.
-- Then there is nothing to choose and the tab has no such control.
assert(BuildGeneralTab(alone) == nil, "the General tab offers a choice of one design")

-- Given two designs again, the second one chosen.
Designs, windows = LoadDesigns("classic", "other")
saved.optionsDesign = "other"
local show = assert(loadstring(assert(Read("MSBTProfiles.lua"):match(
	"local function ShowOptions%b()%s*.-\nend")) .. "\nreturn ShowOptions"))
setfenv(show, { MSBTOptions = MSBTOptions, Print = Noop })
-- When /msbt asks for the options.
show()()
-- Then the chosen design opens.
assert(Events() == "show other", "/msbt did not open the chosen design")
-- Then the button for positioning the scroll areas puts the options away in whichever design
-- they are open, so that closing the positioning brings that design back.
assert(tabs:find("MSBTDesigns%.Hide%(%)%s+MSBTPopups%.ShowScrollAreaConfig%(%)")
	and not tabs:find("MSBTOptMain.HideMainFrame()", 1, true),
	"the positioning button does not put the options away through the registry")

-- The slash command's handler and the texts it prints, with Print recorded.
local translations = {}
local localization = Read("Localization/localization.lua"):gsub("^\239\187\191", "")
setfenv(assert(loadstring(localization)), setmetatable({
	MikSBT = { translations = translations, COMMAND = "/msbt" },
}, { __index = _G }))()
local profiles = Read("MSBTProfiles.lua")
local printed = {}
local handler = assert(loadstring(table.concat({
	assert(profiles:match("local function ShowOptions%b()%s*.-\nend")),
	assert(profiles:match("local function GetNextParameter%b()%s*.-\nend")),
	assert(profiles:match("local function CommandHandler%b()%s*.-\nend")),
	"return CommandHandler",
}, "\n")))
setfenv(handler, setmetatable({
	L = translations, MSBTOptions = MSBTOptions, string_find = string.find,
	Print = function(message) printed[#printed + 1] = message end,
}, { __index = _G }))
local Slash = handler()
local usage = translations.COMMAND_USAGE

-- Rule: /msbt followed by a registered design saves it and opens it; another word shows the usage.
do
	-- Given two designs, no choice saved and no window open.
	Designs, windows = LoadDesigns("classic", "other")
	saved.optionsDesign = nil

	-- When /msbt runs alone.
	Slash("")
	-- Then the classic design opens.
	assert(Events() == "show classic" and saved.optionsDesign == nil, "/msbt did not open the classic design")
	windows.classic.shown = false

	-- When /msbt other runs with the options closed.
	Slash("other")
	-- Then it saves the design and opens it.
	assert(saved.optionsDesign == "other", "/msbt other did not save the design")
	assert(Events() == "show other", "/msbt other did not open the other design")
	windows.other.shown = false
	Slash("")
	assert(Events() == "show other", "/msbt did not open the chosen design")

	-- When /msbt classic runs while the other window is open.
	Slash("classic")
	-- Then it saves the classic design and switches to the classic window.
	assert(saved.optionsDesign == nil, "/msbt classic did not save the design")
	assert(windows.classic.IsShown() and not windows.other.IsShown() and Events():find("^hide other, show classic"),
		"/msbt classic did not switch to the classic design")
	windows.classic.shown = false

	-- When an unknown word follows /msbt.
	printed = {}
	Slash("neww")
	-- Then nothing opens, the choice stays, and the usage is printed.
	assert(Events() == "" and saved.optionsDesign == nil, "an unknown word changed the design")
	assert(#printed > 0 and printed[1] == usage[1], "an unknown word did not show the usage")
end

-- Rule: the usage names the design keys, joined by " | ", only when more than one design is registered.
do
	-- Given each number of designs.
	for _, keys in ipairs({ { "classic" }, { "classic", "other" }, { "classic", "other", "third" } }) do
		LoadDesigns(unpack(keys))

		-- When the usage is printed.
		printed = {}
		Slash("help")

		-- Then the usage is followed by the line of design keys from two designs on.
		local count = #usage + (#keys > 1 and 1 or 0)
		assert(#printed == count and printed[#usage] == usage[#usage],
			#keys .. " designs printed " .. #printed .. " usage lines")
		if #keys > 1 then
			assert(printed[count] == translations.COMMAND_USAGE_DESIGN:format(table.concat(keys, " | ")),
				"the usage names the designs as " .. tostring(printed[count]))
		end
	end
	Events()
end

-- Rule: while the scroll areas are positioned, a further design does not open; the classic one is
-- asked as ever, for it checks that itself.
do
	-- Given two designs and the positioning on screen.
	Designs, windows = LoadDesigns("classic", "other")
	local positioned = true
	MSBTScrollAreasConfigFrame = { IsShown = function() return positioned end }

	-- When the options are opened in the further design.
	saved.optionsDesign = "other"
	Designs.Show()
	-- Then its window is not asked to open.
	assert(Events() == "", "a further design opened while the scroll areas are positioned")

	-- When the options are opened in the classic design.
	saved.optionsDesign = nil
	Designs.Show()
	-- Then its window is asked, as before there were designs.
	assert(Events() == "show classic", "the classic design was not asked while the scroll areas are positioned")
	windows.classic.shown = false

	-- When the positioning has closed.
	positioned = false
	saved.optionsDesign = "other"
	Designs.Show()
	-- Then the further design opens.
	assert(Events() == "show other", "a further design did not open after the positioning")
	MSBTScrollAreasConfigFrame = nil
end
