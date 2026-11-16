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

-- The General tab's functions with its controls replaced by recorders.
local tabs = Read("MSBTOptions/MSBTOptionsTabs.lua")
local function BuildGeneralTab(designs)
	local function NewControl()
		local control = setmetatable({ items = {} }, { __index = function() return Noop end })
		function control:AddItem(text, id) self.items[#self.items + 1] = text .. "=" .. id end
		function control:SetChangeHandler(handler) self.change = handler end
		function control:SetSelectedID(id) self.selected = id end
		function control:GetWidth() return 0 end
		return control
	end
	local build = assert(loadstring(
		assert(tabs:match("local function GeneralTab_Create%b()%s*.-\nend")) .. "\n"
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
		MSBTProfiles = { currentProfile = {}, savedVariables = saved, IsModDisabled = Noop },
	})
	local create, populate = build()
	create()
	populate()
	return frame.controls.optionsDesignDropdown
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
