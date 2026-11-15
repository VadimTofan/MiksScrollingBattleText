-- Describe: the General page of the new options window with the profiles module's Blizzard switches.
local env = dofile("tests/lua/options_window_env.lua")
local calls, Profiles, L, Window, snapshots = env.calls, env.Profiles, env.L, env.Window, env.snapshots
local Find, FindAll, Labelled, Click, ClickEntry = env.Find, env.FindAll, env.Labelled, env.Click, env.ClickEntry
local Footer = env.Footer

-- The client's values, and the functions of the profiles module as they behave: a switch shows
-- the client until it is set in the current profile (blizzardSwitches, 1 shown, 0 hidden). The
-- record is opaque to the window: the marks and the client values, as copies.
local client = { numbers = true, effectsOwn = false, effectsOthers = true }
local seen = {}
local function Record(...) seen[#seen + 1] = { ... } end
local function Marks() return Profiles.currentProfile.blizzardSwitches end
local function Copy(source)
	if source == nil then return nil end
	local copy = {}
	for key, value in pairs(source) do copy[key] = value end
	return copy
end
function Profiles.GetBlizzardSwitch(name)
	local stored = Marks() and Marks()[name]
	if client[name] == nil then return nil, stored ~= nil end
	if stored ~= nil then return stored == 1, true end
	return client[name], false
end
function Profiles.SetBlizzardSwitch(name, isShown)
	Record("SetBlizzardSwitch", name, isShown)
	Profiles.currentProfile.blizzardSwitches = Marks() or { version = 1 }
	Marks()[name] = isShown and 1 or 0
	client[name] = isShown
end
function Profiles.TakeBlizzardSwitches()
	Record("TakeBlizzardSwitches")
	return { marks = Copy(Marks()), client = Copy(client) }
end
function Profiles.RestoreBlizzardSwitches(record)
	Record("RestoreBlizzardSwitches", record, Profiles.currentProfile.animationSpeed)
	Profiles.currentProfile.blizzardSwitches = Copy(record.marks)
	for name, value in pairs(record.client) do client[name] = value end
end
function Profiles.GetSpellMechanicsText()
	return (Profiles.GetBlizzardSwitch("effectsOwn")), (Profiles.GetBlizzardSwitch("effectsOthers"))
end
function Profiles.SetSpellMechanicsText(which, isShown)
	Profiles.SetBlizzardSwitch(which == "own" and "effectsOwn" or "effectsOthers", isShown)
end
L.CHECKBOXES.spellMechanicsOwn = { label = "Effects on targets", tooltip = "Effects tip" }
L.CHECKBOXES.spellMechanicsOthers = { label = "Effects on other players' targets", tooltip = "Others tip" }
L.CHECKBOXES.disableOutgoing.blizzardTooltip = "The numbers over targets"

-- The classic exports and media the pages are built on, as in the pages test.
local function Noop() end
MSBTOptions.Popups = { ShowAcknowledge = Noop, ShowInput = Noop, ShowPartialEffects = Noop,
	ShowDamageColors = Noop, ShowClassColors = Noop, DisableControls = Noop,
	UseDesignPopups = env.Popups.UseDesignPopups }
MSBTOptions.Tabs = { general = { ShowMasterFont = Noop, ResetBlizzardSCT = Noop, ReportImport = Noop } }
MSBTOptions.ProfileTransfer = { ShowExport = Noop, ShowImport = Noop }
MikSBT.Media = { sounds = {}, PlaySound = function() return true end,
	RegisterSound = function() return true end }
MikSBT.API = { Sounds = { NormalizeFile = function(_, file) return file end } }
for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")

local function Checkboxes(label)
	return FindAll(MSBTOptionsWindowFrame, function(region)
		return region.checkFrame and region.fontString:GetText() == label and region.shown
	end)
end
local function Numbers() return Checkboxes(L.CHECKBOXES.disableOutgoing.label)[2] end
local function Own() return Checkboxes(L.CHECKBOXES.spellMechanicsOwn.label)[1] end
local function Others() return Checkboxes(L.CHECKBOXES.spellMechanicsOthers.label)[1] end
local function Toggle(checkbox, isChecked)
	checkbox.checkFrame:SetChecked(isChecked)
	Click(checkbox.checkFrame)
end
local function Cancel() Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel))) end
local function Apply() return Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.apply)) end
local function Open()
	Window.Hide()
	Window.Show()
	ClickEntry("general")
	MikSBT.EraseTable(seen)
	MikSBT.EraseTable(calls)
end
local function Sets()
	local found = {}
	for _, entry in ipairs(seen) do
		if entry[1] == "SetBlizzardSwitch" then found[#found + 1] = entry end
	end
	return found
end
local function Restored()
	local count = 0
	for _, entry in ipairs(seen) do
		if entry[1] == "RestoreBlizzardSwitches" then count = count + 1 end
	end
	return count
end
-- Undo all restores the login state, which has no speed; the page needs one.
local function Reset()
	Window.Hide()
	Profiles.currentProfile.blizzardSwitches = nil
	client.numbers, client.effectsOwn, client.effectsOthers = true, false, true
	for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end
end

-- Rule: Blizzard's outgoing switch shows the client's numbers and saves through the profiles module.
do
	Window.Show()
	ClickEntry("general")
	local numbers = Numbers()
	assert(numbers, "the switch is missing")
	-- Then it shows the client (numbers shown means the box is not checked) with the tooltip of the numbers.
	assert(numbers:GetChecked() == false, "the switch does not show the client")
	assert(numbers.checkFrame.tooltip == L.CHECKBOXES.disableOutgoing.blizzardTooltip, "the tooltip is not the numbers' one")
	assert(Checkboxes(L.CHECKBOXES.disableOutgoing.label)[1].checkFrame.tooltip == L.CHECKBOXES.disableOutgoing.tooltip,
		"MSBT's own switch lost its tooltip")

	-- When the client changed meanwhile, then the next show has it.
	client.numbers = false
	ClickEntry("sounds")
	ClickEntry("general")
	assert(numbers:GetChecked() == true, "the switch did not take the client's value")

	-- When it is clicked, then the profiles module is asked and the page writes nothing itself.
	MikSBT.EraseTable(seen)
	MikSBT.EraseTable(calls)
	Toggle(numbers, false)
	assert(Sets()[1] and Sets()[1][2] == "numbers" and Sets()[1][3] == true,
		"the click did not ask the profiles module to show the numbers")
	assert(#calls == 0, "the page wrote a profile field itself")
	assert(Profiles.currentProfile.blizzardOutgoingDisabled == nil, "the old profile field was written")
	Toggle(numbers, true)
	assert(Sets()[2] and Sets()[2][3] == false, "the click did not hide the numbers")
	Reset()
end

-- Rule: the marks stay out of the profile snapshots, the changes list and Undo all.
do
	Window.Show()
	local before = env.Count()
	Toggle(Own(), true)
	assert(Marks().effectsOwn == 1, "the click set no mark")
	assert(env.Count() == before and #snapshots:Diff(snapshots:GetLoginSnapshot()) == before,
		"a mark reached the changes list")
	assert(snapshots:Take().profiles.Default.blizzardSwitches == nil, "the snapshot carries the marks")
	-- Undo all leaves the marks and the client alone and calls nothing of the switch functions.
	Profiles.SetOption(nil, "animationSpeed", 50)
	Click(Footer())
	MikSBT.EraseTable(seen)
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.undoAll)))
	assert(Marks() and Marks().effectsOwn == 1 and client.effectsOwn == true, "Undo all touched the switches")
	assert(#seen == 0, "Undo all called the profiles module's switch functions")
	Reset()
end

-- Rule: Cancel gives the profiles module the record taken when the window opened, and Apply moves it.
do
	Profiles.currentProfile.blizzardSwitches = { version = 1, effectsOwn = 0 }
	Open()
	Window.Hide()
	Window.Show()
	assert(seen[1] and seen[1][1] == "TakeBlizzardSwitches", "no record was taken at the opening")
	ClickEntry("general")
	Toggle(Others(), false)
	Toggle(Numbers(), false)
	Profiles.SetOption(nil, "animationSpeed", 60)
	MikSBT.EraseTable(seen)
	Cancel()
	for _, entry in ipairs(seen) do
		if entry[1] == "RestoreBlizzardSwitches" then
			assert(entry[3] == 100, "Cancel gave the record back before the profile was restored")
		end
	end
	assert(Restored() == 1, "Cancel did not restore the record once")
	local given
	for _, entry in ipairs(seen) do
		if entry[1] == "RestoreBlizzardSwitches" then given = entry[2] end
	end
	assert(given.marks.effectsOwn == 0 and given.marks.numbers == nil, "Cancel gave another record")
	assert(Marks().effectsOwn == 0 and Marks().numbers == nil and Marks().effectsOthers == nil
		and client.numbers == true and client.effectsOthers == true, "Cancel did not put the switches back")
	for _, entry in ipairs(seen) do assert(entry[1] ~= "SetBlizzardSwitch", "Cancel used the setter") end

	-- When Apply moved the base, then Cancel goes back to that state.
	Open()
	Toggle(Others(), false)
	assert(Apply().enabled, "Apply stays disabled after a switch click")
	Click(Apply())
	assert(not Apply().enabled, "Apply stays enabled after it was applied")
	Toggle(Numbers(), false)
	Cancel()
	assert(Marks().effectsOthers == 0 and Marks().numbers == nil and client.numbers == true,
		"Cancel went back past Apply")
	Reset()
end

-- Rule: a click on a switch refreshes the footer, and clicking it back disables Apply again.
do
	Open()
	assert(not Apply().enabled, "Apply is enabled at the opening")
	Toggle(Numbers(), false)
	assert(Apply().enabled, "a click on the numbers did not enable Apply")
	-- Clicking it back leaves a mark, which is a difference from the opening.
	Toggle(Numbers(), true)
	assert(Apply().enabled, "the mark of a clicked switch was not counted as a difference")
	Click(Apply())
	assert(not Apply().enabled, "Apply stays enabled after it was applied")
	Toggle(Own(), true)
	assert(Apply().enabled, "a click on an effect did not enable Apply")
	-- A switch set to the state it already had in the record is no difference.
	Click(Apply())
	Toggle(Own(), true)
	assert(not Apply().enabled, "Apply is enabled with the record as it was")
	-- A profile change still does it.
	Reset()
	Open()
	Profiles.SetOption(nil, "animationSpeed", 60)
	assert(Apply().enabled, "a profile change no longer enables Apply")
	Profiles.SetOption(nil, "animationSpeed", 100)
	Reset()
end

-- Rule: the record is taken again whenever the window is opened anew, however it was put away.
do
	-- Hidden by Escape, which hides the frame itself.
	Open()
	Toggle(Own(), true)
	-- Without the hook of the popups, which would clear the record as well.
	local hooked = MSBTOptions.Popups.UseDesignPopups
	MSBTOptions.Popups.UseDesignPopups = Noop
	MSBTOptionsWindowFrame:Hide()
	MSBTOptions.Popups.UseDesignPopups = hooked
	Window.Show()
	ClickEntry("general")
	Toggle(Own(), false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after Escape the old record was used")
	Reset()

	-- Hidden by the window's own Hide.
	Open()
	Toggle(Own(), true)
	Window.Hide()
	Window.Show()
	ClickEntry("general")
	Toggle(Own(), false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after Hide the old record was used")
	Reset()

	-- Put away for a moment, then another design takes its popups.
	Open()
	Toggle(Own(), true)
	Window.Hide(true)
	MSBTOptions.Popups.UseDesignPopups("classic")
	Window.Show()
	ClickEntry("general")
	Toggle(Own(), false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after another design opened the old record was used")
	Reset()

	-- Put away for a moment, then a Hide while it was hidden.
	Open()
	Toggle(Own(), true)
	Window.Hide(true)
	Window.Hide()
	Window.Show()
	ClickEntry("general")
	Toggle(Own(), false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after a Hide while hidden the old record was used")
	Reset()

	-- Put away for a moment only: the record stays.
	Open()
	Toggle(Own(), true)
	Window.Hide(true)
	Window.Show()
	ClickEntry("general")
	Cancel()
	assert(Marks() == nil or Marks().effectsOwn == nil, "a short hide lost the record")
	Reset()

	-- Shown with the interface hidden, where Show runs no OnShow: the record is still taken.
	Window.Hide()
	local onShow = MSBTOptionsWindowFrame.scripts.OnShow
	MSBTOptionsWindowFrame.scripts.OnShow = nil
	MikSBT.EraseTable(seen)
	Window.Show()
	MSBTOptionsWindowFrame.scripts.OnShow = onShow
	assert(seen[1] and seen[1][1] == "TakeBlizzardSwitches", "Show took no record")
	ClickEntry("general")
	Toggle(Own(), true)
	Cancel()
	assert(Marks() == nil or Marks().effectsOwn == nil, "Cancel did not restore after a Show without OnShow")
	Reset()
end

print("Blizzard switch page tests passed")
