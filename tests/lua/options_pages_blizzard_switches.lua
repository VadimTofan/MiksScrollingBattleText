-- Describe: the General page of the new options window with the profiles module's Blizzard switches.
local env = dofile("tests/lua/options_window_env.lua")
local calls, Profiles, L, Window, snapshots = env.calls, env.Profiles, env.L, env.Window, env.snapshots
local Find, FindAll, Labelled, Click, ClickEntry = env.Find, env.FindAll, env.Labelled, env.Click, env.ClickEntry
local Footer = env.Footer

-- The client's values, and the functions of the profiles module as they behave: a switch shows
-- the client until it is set in the current profile (blizzardSwitches, 1 shown, 0 hidden). The
-- record is opaque to the window: the marks and the client values, as copies.
local client = { numbers = true, effectsOwn = false, effectsOthers = true, reputation = true, honor = false }
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
L.CHECKBOXES.blizzardReputation = { label = "Reputation Changes", tooltip = "Reputation tip" }
L.CHECKBOXES.blizzardHonor = { label = "Honorable Kills", tooltip = "Honor tip" }
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
-- The entries of the two dropdowns by a short name: an entry as the menu lists it when opened, the
-- labels of a dropdown in their order, and a click on an entry where its text does not stand as wanted.
local ON_ME, ON_TARGET = L.WINDOW.blizzardOnMe, L.WINDOW.blizzardOnTarget
local LABELS = {
	numbers = L.WINDOW.blizzardNumbers, own = L.CHECKBOXES.spellMechanicsOwn.label,
	others = L.CHECKBOXES.spellMechanicsOthers.label, reputation = L.CHECKBOXES.blizzardReputation.label,
	honor = L.CHECKBOXES.blizzardHonor.label,
}
local function Entry(name)
	return env.MenuEntry(ON_ME, LABELS[name]) or env.MenuEntry(ON_TARGET, LABELS[name])
end
local function Labels(text)
	local labels = {}
	for _, entry in ipairs(env.Menu(text)) do labels[#labels + 1] = entry.text end
	return table.concat(labels, "|")
end
local function Set(name, isShown)
	local entry = Entry(name)
	if entry:IsSelected() ~= isShown then entry:Pick() end
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
	client.reputation, client.honor = true, false
	for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end
end

-- Rule: the entry for the numbers over targets shows the client and saves through the profiles module.
do
	Window.Show()
	ClickEntry("general")
	assert(Entry("numbers"), "the entry is missing")
	-- Then it shows the client, ticked while the numbers show, and tells what it stands for.
	assert(Entry("numbers"):IsSelected() == true, "the entry does not show the client")
	local title, text = env.MenuTooltip(Entry("numbers"))
	assert(title == L.WINDOW.blizzardNumbers and text == L.WINDOW.blizzardNumbersTooltip, "the entry has another tooltip")
	-- And Blizzard's column has no checkbox for them; MSBT's own switch keeps its tooltip.
	local outgoing = Checkboxes(L.CHECKBOXES.disableOutgoing.label)
	assert(#outgoing == 1 and outgoing[1].checkFrame.tooltip == L.CHECKBOXES.disableOutgoing.tooltip,
		"MSBT's own switch differs")

	-- When the client changed meanwhile, then the menu has it the next time it opens.
	client.numbers = false
	assert(Entry("numbers"):IsSelected() == false, "the entry did not take the client's value")

	-- When it is clicked, then the profiles module is asked and the page writes nothing itself.
	MikSBT.EraseTable(seen)
	MikSBT.EraseTable(calls)
	Entry("numbers"):Pick()
	assert(Sets()[1] and Sets()[1][2] == "numbers" and Sets()[1][3] == true,
		"the click did not ask the profiles module to show the numbers")
	assert(#calls == 0, "the page wrote a profile field itself")
	assert(Profiles.currentProfile.blizzardOutgoingDisabled == nil, "the old profile field was written")
	Entry("numbers"):Pick()
	assert(Sets()[2] and Sets()[2][3] == false, "the click did not hide the numbers")
	Reset()
end

-- Rule: the marks stay out of the profile snapshots, the changes list and Undo all.
do
	Window.Show()
	local before = env.Count()
	Set("own", true)
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
	Set("others", false)
	Set("numbers", false)
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
	Set("others", false)
	assert(Apply().enabled, "Apply stays disabled after a switch click")
	Click(Apply())
	assert(not Apply().enabled, "Apply stays enabled after it was applied")
	Set("numbers", false)
	Cancel()
	assert(Marks().effectsOthers == 0 and Marks().numbers == nil and client.numbers == true,
		"Cancel went back past Apply")
	Reset()
end

-- Rule: a click on a switch refreshes the footer, and clicking it back disables Apply again.
do
	Open()
	assert(not Apply().enabled, "Apply is enabled at the opening")
	Entry("numbers"):Pick()
	assert(Apply().enabled, "a click on the numbers did not enable Apply")
	-- Clicking it back leaves a mark, which is a difference from the opening.
	Entry("numbers"):Pick()
	assert(Entry("numbers"):IsSelected() == true and Apply().enabled,
		"the mark of a clicked switch was not counted as a difference")
	Click(Apply())
	assert(not Apply().enabled, "Apply stays enabled after it was applied")
	Set("own", true)
	assert(Apply().enabled, "a click on an effect did not enable Apply")
	-- A switch clicked back to the state it had in the record is no difference.
	Click(Apply())
	Entry("own"):Pick()
	Entry("own"):Pick()
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
	Set("own", true)
	-- Without the hook of the popups, which would clear the record as well.
	local hooked = MSBTOptions.Popups.UseDesignPopups
	MSBTOptions.Popups.UseDesignPopups = Noop
	MSBTOptionsWindowFrame:Hide()
	MSBTOptions.Popups.UseDesignPopups = hooked
	Window.Show()
	ClickEntry("general")
	Set("own", false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after Escape the old record was used")
	Reset()

	-- Hidden by the window's own Hide.
	Open()
	Set("own", true)
	Window.Hide()
	Window.Show()
	ClickEntry("general")
	Set("own", false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after Hide the old record was used")
	Reset()

	-- Put away for a moment, then another design takes its popups.
	Open()
	Set("own", true)
	Window.Hide(true)
	MSBTOptions.Popups.UseDesignPopups("classic")
	Window.Show()
	ClickEntry("general")
	Set("own", false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after another design opened the old record was used")
	Reset()

	-- Put away for a moment, then a Hide while it was hidden.
	Open()
	Set("own", true)
	Window.Hide(true)
	Window.Hide()
	Window.Show()
	ClickEntry("general")
	Set("own", false)
	Cancel()
	assert(Marks() and Marks().effectsOwn == 1, "after a Hide while hidden the old record was used")
	Reset()

	-- Put away for a moment only: the record stays.
	Open()
	Set("own", true)
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
	Set("own", true)
	Cancel()
	assert(Marks() == nil or Marks().effectsOwn == nil, "Cancel did not restore after a Show without OnShow")
	Reset()
end

-- Rule: the reputation and honor entries show the client, save through the profiles module and are put back by Cancel.
do
	Open()
	assert(Entry("reputation") and Entry("honor"), "an entry is missing")
	assert(Entry("reputation"):IsSelected() == true and Entry("honor"):IsSelected() == false,
		"the entries do not show the client")
	local title, text = env.MenuTooltip(Entry("reputation"))
	assert(title == L.CHECKBOXES.blizzardReputation.label and text == L.CHECKBOXES.blizzardReputation.tooltip,
		"the entry does not have the text of its classic checkbox")

	-- Then they close the text at the character, after the profile's two; the effects follow the numbers.
	assert(Labels(ON_ME) == L.WINDOW.incoming .. "|" .. L.WINDOW.notifications .. "|" .. LABELS.reputation .. "|"
		.. LABELS.honor, "the text at the character differs: " .. Labels(ON_ME))
	assert(Labels(ON_TARGET) == LABELS.numbers .. "|" .. LABELS.own .. "|" .. LABELS.others,
		"the text over targets differs: " .. Labels(ON_TARGET))
	-- And with all seven entries the sections keep their heights, the rows of the second their distance.
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	assert(Section(0) and Section(140) and Section(300), "the sections moved with the entries")
	assert(Section(0).height == 130 and Section(140).height == 150 and Section(300).height == 156,
		"the sections changed with the entries")
	local lastRow = Checkboxes(L.CHECKBOXES.shortenNumbers.label)[1]
	assert(lastRow.points.TOPLEFT.y == -12 - 4 * 26, "the second section closed its rows up")
	local note = Find(MSBTOptionsWindowFrame, function(frame)
		for _, region in ipairs(frame.regions) do
			if region.GetText and region:GetText() == L.LANGUAGE_INFO then return true end
		end
	end)
	for _, region in ipairs(note.regions) do
		if region.GetText and region:GetText() == L.LANGUAGE_INFO then
			assert(region.points.TOPLEFT.y == -96, "the language note moved")
		end
	end
	-- And the reset button stands with its hint under the slider of the second section, so the
	-- third holds no text but the note.
	local reset = Find(MSBTOptionsWindowFrame, Labelled(L.BUTTONS.resetBlizzardSCT.label))
	local top = -reset.points.TOPLEFT.y
	assert(reset.parent == Section(140) and reset.points.TOPLEFT.x == 345, "the reset button left the second section")
	assert(top >= 30 + 30, "the reset button is not below the slider")
	assert(top + reset.height + 6 + 2 * 12 <= Section(140).height, "the hint of the reset button leaves the section")
	for _, region in ipairs(Section(300).regions) do
		assert(region.kind ~= "FontString" or region:GetText() == L.LANGUAGE_INFO, "a text shares the third section with the note")
	end

	-- When one is clicked, then the profiles module is asked with its name and the new state.
	Set("honor", true)
	assert(Sets()[1] and Sets()[1][2] == "honor" and Sets()[1][3] == true, "the click did not set the honor switch")
	Set("reputation", false)
	assert(Sets()[2] and Sets()[2][2] == "reputation" and Sets()[2][3] == false, "the click did not set the reputation switch")
	assert(#calls == 0, "a click wrote to the profile")
	assert(Apply().enabled, "a click on a switch did not enable Apply")

	-- When the client has the opposite of what the clicks left and the profile has no mark, then the menu
	-- has the client's values the next time it opens.
	Profiles.currentProfile.blizzardSwitches = nil
	client.reputation, client.honor = true, false
	assert(Entry("reputation"):IsSelected() == true and Entry("honor"):IsSelected() == false,
		"the entries kept the values of an earlier opening")

	-- When the client changed again, then the menu has that too; a missing setting leaves its entry out.
	client.reputation, client.honor = false, true
	assert(Entry("reputation"):IsSelected() == false and Entry("honor"):IsSelected() == true,
		"the entries did not take the client's values")
	client.reputation = nil
	assert(not Entry("reputation") and Entry("honor") and #env.Menu(ON_ME) == 3, "a missing setting kept its entry")
	client.reputation = true
	client.effectsOwn = nil
	assert(not Entry("own") and Entry("others") and #env.Menu(ON_TARGET) == 2, "a missing effect setting kept its entry")
	Reset()

	-- When the window opened, then Cancel gives the record back and the client has its values from then.
	Open()
	Set("honor", true)
	Set("reputation", false)
	Cancel()
	assert(client.reputation == true and client.honor == false, "Cancel did not put the switches back")
	assert(Marks() == nil or (Marks().reputation == nil and Marks().honor == nil), "Cancel left a mark")
	Reset()
end

print("Blizzard switch page tests passed")
