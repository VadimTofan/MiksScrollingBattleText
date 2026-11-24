-- Describe: the new options window hosts pages and tracks changes.
local env = dofile("tests/lua/options_window_env.lua")
local Noop, Methods, saved, calls, Profiles, snapshots, L, Main, tabs, Window =
	env.Noop, env.Methods, env.saved, env.calls, env.Profiles, env.snapshots, env.L, env.Main,
	env.tabs, env.Window
local Find, FindAll, Labelled, Click, ClickEntry, IsInWindow, Count, Footer =
	env.Find, env.FindAll, env.Labelled, env.Click, env.ClickEntry, env.IsInWindow, env.Count,
	env.Footer
local ROUNDED = "Interface\\Addons\\MikScrollingBattleText\\MSBTOptions\\Designs\\Forever\\Artwork\\RoundedBox"
-- A label of its own, so the footer cannot borrow the Profile tab's shorter one.
L.WINDOW.resetProfile = "Reset the whole profile"

-- The window is built on a client with texture slicing; a later rule turns it off.
Methods.SetTextureSliceMargins = function(self, ...) self.slice = { ... } end
-- The client has every piece of Blizzard's options art but the page divider.
env.art.available, env.art.missing = true, "Options_HorizontalDivider"
local CHEVRON = "Interface\\Addons\\MikScrollingBattleText\\MSBTOptions\\Designs\\Forever\\Artwork\\FlatChevron"
-- A frame's edges in its own scaled units, and the cursor in screen pixels: the interface scale
-- turns pixels into the screen's units.
function Methods:GetScale() return self.scale end
function Methods:GetLeft() return self.left end
function Methods:GetTop() return self.top end
function Methods:GetRight() return self.left + self.width end
function Methods:GetEffectiveScale() return 0.5 end
local cursor = { x = 0, y = 0 }
function GetCursorPosition() return cursor.x, cursor.y end

-- Rule: the window is built at the scale saved for the account.
do
	-- Given a scale saved before the window exists.
	saved.optionsScale = 1.25

	-- When the window opens for the first time.
	Window.Show()

	-- Then it has that scale.
	assert(MSBTOptionsWindowFrame.scale == 1.25, "the saved scale was not applied")
	Window.Hide()
	MSBTOptionsWindowFrame:SetScale(1)
	saved.optionsScale = nil
end

-- Rule: Blizzard's art is worn only when the client has every piece of it.
do
	-- Given a client that lacks one piece of the art.
	-- When the window opens.
	Window.Show()

	-- Then the art was looked up and nothing wears it.
	assert(env.art.queries > 0, "the client's art was not looked up")
	assert(#FindAll(MSBTOptionsWindowFrame, function(region) return region.atlas end) == 0,
		"the window wears Blizzard's art with a piece missing")
	Window.Hide()
end

local Designs = MSBTOptions.Designs

-- Rule: the new window registers as a design after the classic one, and the options open in it
-- when it is chosen.
do
	-- Given the designs as the files registered them.
	local forever = Designs.designs.forever
	assert(table.concat(Designs.keys, ",") == "classic,forever", "the new design is not registered")
	assert(forever.label == L.MSG_FOREVER_DESIGN and forever.Show == Window.Show and forever.Hide == Window.Hide
		and forever.IsShown == Window.IsShown, "the new design is registered without its window")

	-- When the new design is chosen and the options are opened, as /msbt does.
	Designs.Select("forever")
	Designs.Show()

	-- Then the new window opens with the new design's popups.
	assert(MSBTOptionsWindowFrame:IsShown() and env.Popups.design == "forever", "the chosen design did not open")
	Window.Hide()
end

-- Rule: the classic window takes its popups back when it opens while the new one is put away,
-- also the first time it is built.
do
	-- Given the new window is open and puts itself away for the scroll area configuration.
	Designs.Show()
	Designs.Hide()
	MSBTScrollAreasConfigFrame = CreateFrame("Frame")

	-- When /msbt classic runs meanwhile and the configuration then closes.
	Designs.Select("classic")
	Designs.Show()
	MSBTScrollAreasConfigFrame:Hide()
	Designs.Show()

	-- Then the classic window opens with its own popups.
	assert(MSBTMainOptionsFrame:IsShown() and not MSBTOptionsWindowFrame:IsShown(),
		"the classic window did not open")
	assert(env.Popups.design == "classic", "the classic window opened with the new design's popups")
	Main.HideMainFrame()
	MSBTScrollAreasConfigFrame = nil
end

-- Rule: choosing a design while the options are open switches the window, and the popups with it.
do
	-- Given the classic window is open.
	Designs.Show()
	local window = MSBTOptionsWindowFrame

	-- When the new design is chosen.
	Designs.Select("forever")

	-- Then only the new window is open, with the new design's popups.
	assert(window:IsShown() and not MSBTMainOptionsFrame:IsShown(),
		"choosing New left the classic window open")
	assert(env.Popups.design == "forever", "the new window uses the classic popups")

	-- When the classic design is chosen again.
	Designs.Select("classic")

	-- Then only the classic window is open, with the classic popups.
	assert(MSBTMainOptionsFrame:IsShown() and not window:IsShown(),
		"choosing Classic left the new window open")
	assert(env.Popups.design == "classic", "the classic window uses the new design's popups")
	Main.HideMainFrame()
end

-- Rule: the new window uses the new design's popups and the classic window the classic ones;
-- hiding the new window keeps them for the scroll area configuration it opens.
do
	-- When the new window opens, then hides for a moment, then the classic window opens.
	Window.Show()
	local opened = env.Popups.design
	Window.Hide(true)
	local hidden = env.Popups.design
	Main.ShowMainFrame()

	-- Then each window chose its own popups, and hiding chose none.
	assert(opened == "forever" and hidden == "forever", "the new window does not use the new design's popups")
	assert(env.Popups.design == "classic", "the classic window uses the new design's popups")
	Main.HideMainFrame()
end

-- Rule: docking the classic window closes the new one.
do
	-- Given the new window is open and the Settings panel docks the classic window.
	Window.Show()
	local panel = CreateFrame("Frame")
	local soundsIndex
	for _, tab in ipairs(Main.GetTabs()) do
		if tab.text == L.TABS.sounds.label then soundsIndex = tab.index end
	end
	Main.DockMainFrame(panel, Noop, soundsIndex)

	-- Then the docked view shows the tab and the new window is closed.
	assert(MSBTMainOptionsFrame:GetParent() == panel, "the classic window did not dock")
	assert(tabs.sounds:GetParent() == MSBTMainOptionsFrame and tabs.sounds:IsShown(),
		"the docked view lost its tab")
	assert(not MSBTOptionsWindowFrame:IsShown(), "the new window stayed open beside the docked view")
	Main.UndockMainFrame(panel)
end

-- Rule: the new window does not open while the classic view is docked, and keeps its popups out.
do
	-- Given the Settings panel docks the classic window and the classic popups are in use.
	Window.Hide()
	local panel = CreateFrame("Frame")
	Main.DockMainFrame(panel, Noop)
	env.Popups.design = nil

	-- When the options are asked to open while the new design is chosen.
	Designs.Select("forever")
	Designs.Show()

	-- Then it stays closed and chose no popups.
	assert(not MSBTOptionsWindowFrame:IsShown(), "the new window opened beside the docked view")
	assert(env.Popups.design == nil, "the new design's popups were chosen beside the docked view")
	Main.UndockMainFrame(panel)
end

-- Rule: hiding the new window for good gives the classic popups back, hiding it for a moment does not.
do
	-- Given the new window is open.
	Window.Show()

	-- When it hides for a moment, then for good.
	Window.Hide(true)
	local moment = env.Popups.design
	Window.Show()
	Window.Hide()

	-- Then the moment kept the new design's popups and the end gave the classic ones back.
	assert(moment == "forever", "hiding for a moment gave the classic popups back")
	assert(env.Popups.design == "classic", "hiding for good kept the new design's popups")
end

-- Rule: "Configure on screen" puts the new window away with its popups and brings it back.
do
	-- Given the new window is open and a change was made.
	Designs.Show()
	Profiles.SetOption(nil, "shortenNumbers", true)

	-- When the options are put away for the scroll area configuration and opened again as it closes.
	Designs.Hide()
	assert(not MSBTOptionsWindowFrame:IsShown(), "putting away did not hide the new window")
	assert(not MSBTMainOptionsFrame:IsShown(), "putting away showed the classic window")
	assert(env.Popups.design == "forever", "putting away gave the classic popups back")
	Designs.Show()

	-- Then the new window is back, the classic one stays closed, and Cancel still
	-- returns to the state from opening.
	assert(MSBTOptionsWindowFrame:IsShown() and not MSBTMainOptionsFrame:IsShown(),
		"showing did not bring the new window back")
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))
	assert(rawget(Profiles.currentProfile, "shortenNumbers") == nil,
		"the popup round trip moved the Cancel base")
end

-- Rule: a registered page is created once and refreshed.
do
	-- Given two entries register one page with different arguments.
	local created, refreshed = {}, {}
	local function Create(page, width, height)
		created[#created + 1] = { page, width, height }
	end
	local function Refresh(page, arg) refreshed[#refreshed + 1] = { page, arg } end
	Window.RegisterPage("incoming", Create, Refresh, "INCOMING")
	Window.RegisterPage("outgoing", Create, Refresh, "OUTGOING")
	Window.Show()

	-- When both entries are chosen.
	ClickEntry("incoming")
	ClickEntry("outgoing")

	-- Then the page is created once and refreshed with each argument.
	assert(#created == 1 and created[1][2] == 690 and created[1][3] == 456,
		"the page was not created once with the page size")
	local page = created[1][1]
	assert(page:GetParent():GetParent() == MSBTOptionsWindowFrame and page:IsShown(),
		"the page is not shown in the window")
	assert(#refreshed == 2 and refreshed[1][2] == "INCOMING" and refreshed[2][2] == "OUTGOING"
		and refreshed[2][1] == page, "the page was not refreshed with its argument")

	-- When the window opens again and the profile changes in the header.
	Window.Hide()
	Window.Show()
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	dropdown:changeHandler("Alt")

	-- Then the page is refreshed each time.
	assert(#refreshed == 4 and #created == 1, "the page was not refreshed on show and profile change")
	Profiles.SelectProfile("Default")
	Window.Hide()
end

-- Rule: switching designs gives pending Forever edits an explicit resolution.
do
	local previousDialogs, previousShow = StaticPopupDialogs, StaticPopup_Show
	local dialog, data
	StaticPopupDialogs = {}
	StaticPopup_Show = function(which, _, _, value)
		dialog, data = StaticPopupDialogs[which], value
	end
	Designs.Select("forever")
	Designs.Show()
	Profiles.SetOption(nil, "fontSize", 31)

	-- The switch waits for a decision. Dismissing the dialog keeps the edit pending.
	Designs.Select("classic")
	assert(dialog and Designs.GetSelected() == "forever" and Window.IsShown(),
		"switching silently kept pending edits")
	if dialog.OnCancel then dialog.OnCancel(nil, data) end
	assert(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.apply)):IsEnabled())

	-- Discard rolls back the change and completes the switch.
	Designs.Select("classic")
	dialog.OnAlt(nil, data)
	assert(Designs.GetSelected() == "classic" and not Window.IsShown())
	assert(Profiles.currentProfile.fontSize == nil, "discard kept a pending edit")

	-- Apply keeps the edit and completes the switch.
	Designs.Select("forever")
	Profiles.SetOption(nil, "fontSize", 31)
	Designs.Select("classic")
	dialog.OnAccept(nil, data)
	assert(Designs.GetSelected() == "classic" and not Window.IsShown())
	assert(Profiles.currentProfile.fontSize == 31, "apply lost a pending edit")
	Profiles.SetOption(nil, "fontSize", nil)
	Designs.Select("forever")

	-- Applying also ends the original editing session when the window is put away.
	Profiles.SetOption(nil, "fontSize", 28)
	Designs.Hide()
	MSBTScrollAreasConfigFrame = CreateFrame("Frame")
	Designs.Select("classic")
	Designs.Show()
	Designs.Select("classic")
	Designs.Show()
	assert(Designs.GetSelected() == "forever", "a repeated command bypassed the prompt")
	dialog.OnAccept(nil, data)
	assert(Designs.GetSelected() == "classic" and not Window.IsShown())
	MSBTScrollAreasConfigFrame = nil
	Designs.Select("forever")
	Designs.Show()
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))
	assert(Profiles.currentProfile.fontSize == 28, "Cancel undid an already applied edit")
	Profiles.SetOption(nil, "fontSize", nil)
	StaticPopupDialogs, StaticPopup_Show = previousDialogs, previousShow
end

-- Rule: Cancel restores the state from opening and closes.
do
	-- Given the window opened and a setting changed.
	Window.Show()
	Profiles.SetOption("events.INCOMING_DAMAGE", "disabled", true)

	-- When Cancel is clicked.
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))

	-- Then the change is gone and the window closed.
	assert(rawget(Profiles.currentProfile, "events") == nil,
		"Cancel did not restore the setting")
	assert(not MSBTOptionsWindowFrame:IsShown(), "Cancel did not close the window")
end

-- Rule: Apply moves the base for Cancel and keeps the window open.
do
	-- Given a change in the open window.
	Window.Show()
	local apply = Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.apply))
	assert(not apply:IsEnabled(), "Apply is enabled without changes")
	Profiles.SetOption(nil, "fontSize", 20)
	assert(apply:IsEnabled(), "Apply is disabled after a change")

	-- When Apply is clicked and another change is cancelled.
	Click(apply)
	assert(MSBTOptionsWindowFrame:IsShown() and not apply:IsEnabled(),
		"Apply closed the window or stayed enabled")
	Profiles.SetOption(nil, "fontSize", 30)
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))

	-- Then Cancel returns to the applied state.
	assert(Profiles.currentProfile.fontSize == 20, "Cancel did not return to the applied state")
	Profiles.currentProfile.fontSize = nil
end

-- Rule: a staged import can be discarded after its profile has been removed.
do
	-- Given that a staged import is the only remaining session change.
	local pending = false
	local discarded = false
	local previousHasMedia = Profiles.HasImportedMedia
	local previousFinishMedia = Profiles.FinishImportedMedia
	Profiles.HasImportedMedia = function() return pending end
	Profiles.FinishImportedMedia = function(keep)
		if pending and not keep then discarded = true end
		pending = false
	end
	Window.Show()
	pending = true
	Profiles.SetOption(nil, "fontSize", nil)

	-- When the user clicks Cancel.
	local window = MSBTOptionsWindowFrame
	assert(Find(window, Labelled(L.WINDOW.apply)):IsEnabled(),
		"pending media did not enable Apply")
	Click(Find(window, Labelled(L.WINDOW.cancel)))

	-- Then Cancel discards the staged media.
	assert(discarded and not pending)
	Profiles.HasImportedMedia = previousHasMedia
	Profiles.FinishImportedMedia = previousFinishMedia
end

-- Rule: closing keeps the changes.
do
	-- Given a change in the open window.
	Window.Show()
	Profiles.SetOption(nil, "stackSimilarHits", true)

	-- When the window is closed as Esc does and opened again.
	MSBTOptionsWindowFrame:Hide()
	Window.Show()
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))

	-- Then the change stays, because the new opening is the new base.
	assert(Profiles.currentProfile.stackSimilarHits == true, "closing dropped the change")
	Profiles.currentProfile.stackSimilarHits = nil
end

-- Rule: the footer count follows every change through the profile functions.
do
	-- Given the open window.
	Window.Show()
	local footer = Footer()
	local before = Count()
	assert(footer:GetText() == string.format(L.WINDOW.changesCount, before), "wrong count on show")

	-- When settings change and change back.
	Profiles.SetOption(nil, "animationSpeed", 50)
	Profiles.SetOptionUserDisabled(true)

	-- Then the count follows without any refresh call.
	assert(footer:GetText() == string.format(L.WINDOW.changesCount, before + 2),
		"the count did not follow the changes")
	assert(Count() == #snapshots:Diff(snapshots:GetLoginSnapshot()), "Count differs from Diff")
	Profiles.SetOption(nil, "animationSpeed", nil)
	Profiles.SetOptionUserDisabled(false)
	assert(footer:GetText() == string.format(L.WINDOW.changesCount, before),
		"the count did not follow the reverted changes")
	Window.Hide()
end

-- Rule: undoing one entry or all entries restores the login state and refreshes the page.
do
	-- Given two changes since login and the Changes page opened from the footer.
	Profiles.SetOption(nil, "animationSpeed", 50)
	Profiles.SetOption("events.OUTGOING_HEAL", "disabled", true)
	Window.Show()
	Click(Footer())
	local function VisibleUndos()
		return FindAll(MSBTOptionsWindowFrame, function(region)
			return region.kind == "Button" and region:GetText() == L.WINDOW.undo
				and region:GetParent().shown
		end)
	end
	assert(#VisibleUndos() == 2, "the Changes page does not list both changes")

	-- When the first entry is undone.
	local first = VisibleUndos()[1]
	local key = first:GetParent().keyFontString:GetText()
	Click(first)

	-- Then only that entry is restored and the page and count follow.
	local entries = snapshots:Diff(snapshots:GetLoginSnapshot())
	assert(#entries == 1 and entries[1].key ~= key, "Undo did not restore that entry")
	assert(#VisibleUndos() == 1, "the page was not refreshed after Undo")
	assert(Footer():GetText() == string.format(L.WINDOW.changesCount, 1), "the count was not refreshed")

	-- When everything is undone.
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.undoAll)))

	-- Then the login state is back and the page is empty.
	assert(Count() == 0 and #VisibleUndos() == 0, "Undo all did not restore the login state")
	assert(Footer():GetText() == string.format(L.WINDOW.changesCount, 0), "the count was not refreshed")
	Window.Hide()
end

-- Rule: the header holds the profile choice; MSBT and Blizzard text are switched on the General page only.
do
	-- Given the window is open.
	Window.Show()

	-- Then no checkbox stands in the header.
	for _, child in ipairs(MSBTOptionsWindowFrame.children) do
		assert(not child.checkFrame, "a checkbox stands in the header")
	end

	-- When a profile is chosen in the header.
	MikSBT.EraseTable(calls)
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	dropdown:changeHandler("Alt")

	-- Then the function the Profile tab calls runs with the same argument, and the dropdown shows it.
	assert(calls[1][1] == "SelectProfile" and calls[1][2] == "Alt", "profile call differs")
	assert(dropdown:GetSelectedID() == "Alt", "the dropdown does not show the profile")
	Profiles.SelectProfile("Default")
	Window.Hide()
end

-- Rule: hiding the whole interface keeps the base for Cancel.
do
	-- Given a change in the open window.
	Window.Show()
	local window = MSBTOptionsWindowFrame
	Profiles.SetOption(nil, "shortenNumbers", true)

	-- When the interface is hidden and shown, so only a parent changed visibility.
	window.scripts.OnHide(window)
	window.scripts.OnShow(window)
	Click(Find(window, Labelled(L.WINDOW.cancel)))

	-- Then Cancel still returns to the state from opening.
	assert(rawget(Profiles.currentProfile, "shortenNumbers") == nil,
		"hiding the interface dropped the Cancel base")
end

-- Rule: a kept base is dropped when the classic view takes over while the window is put away.
do
	-- Given the window was put away for the configuration and the docked view took over.
	Designs.Show()
	Designs.Hide()
	local panel = CreateFrame("Frame")
	Main.DockMainFrame(panel, Noop)
	Main.UndockMainFrame(panel)

	-- When a change is made there and the new window opens and cancels.
	Profiles.SetOption(nil, "stackSimilarHits", true)
	Designs.Show()
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))

	-- Then the change from the other view stays.
	assert(Profiles.currentProfile.stackSimilarHits == true, "Cancel used the stale base")
	Profiles.currentProfile.stackSimilarHits = nil
end

-- Rule: "Configure on screen" in the docked classic view returns to the game's settings window,
-- also while the new design is chosen.
do
	-- Given the new design is chosen and the settings window docks the classic view.
	Designs.Select("forever")
	local panel = CreateFrame("Frame")
	SettingsPanel = CreateFrame("Frame")
	SettingsPanel:SetScript("OnHide", function() Main.UndockMainFrame(panel) end)
	function HideUIPanel(frame) frame:Hide() end
	local function Reopen()
		SettingsPanel:Show()
		Main.DockMainFrame(panel, Reopen)
	end
	Reopen()

	-- When the options are put away for the configuration and opened again as it closes.
	Designs.Hide()
	assert(not SettingsPanel:IsShown() and not MSBTMainOptionsFrame:IsShown(),
		"putting away left the settings window open")
	Designs.Show()

	-- Then the settings window shows the classic view again, without the new window, with the classic popups.
	assert(SettingsPanel:IsShown() and Main.IsDocked() and MSBTMainOptionsFrame:IsShown()
		and MSBTMainOptionsFrame:GetParent() == panel, "the settings window did not come back")
	assert(not MSBTOptionsWindowFrame:IsShown() and env.Popups.design == "classic",
		"the new design opened instead of the settings window")
	SettingsPanel:Hide()
	SettingsPanel, HideUIPanel = nil, nil
end

-- Rule: the window does not open during the scroll area configuration; the registry sees to that.
do
	-- Given the new design is chosen and the configuration is on screen.
	Designs.Select("forever")
	MSBTScrollAreasConfigFrame = CreateFrame("Frame")

	-- When the options are opened.
	Designs.Show()

	-- Then the window stays away.
	assert(not MSBTOptionsWindowFrame:IsShown(), "the window opened over the configuration")
	MSBTScrollAreasConfigFrame = nil
end

-- Rule: the closed window does not rebuild its profile list.
do
	-- Given the window is closed.
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	local function Listed(name)
		for _, id in ipairs(dropdown.itemIDs) do
			if id == name then return true end
		end
	end

	-- When a profile is added.
	saved.profiles.Extra = { creationVersion = "1" }
	Profiles.CopyProfile("Default", "Extra")

	-- Then the list follows only when the window opens.
	assert(not Listed("Extra"), "the closed window rebuilt its profile list")
	Window.Show()
	assert(Listed("Extra"), "the opened window does not list the profile")
end

-- Rule: a profile added since login is one Changes row and undoes whole.
do
	-- Given the Changes page with the added profile.
	Click(Footer())
	local rows = FindAll(MSBTOptionsWindowFrame, function(region)
		return region.keyFontString and region.shown
	end)

	-- Then it is one row that names the profile, and Undo removes it.
	assert(#rows == 1 and rows[1].keyFontString:GetText() == "profiles.Extra"
		and rows[1].newFontString:GetText() == L.TABS.profile.label, "the profile is not one row")
	Click(Find(rows[1], Labelled(L.WINDOW.undo)))
	assert(saved.profiles.Extra == nil and Count() == 0, "Undo did not remove the profile")
	Window.Hide()
end

-- Rule: boxes are rounded where the client slices textures and square elsewhere.
do
	-- Given a client with texture slicing.
	local ground = Window.Box(CreateFrame("Frame"), Window.COLORS.panel)
	local button = MSBTOptions.Controls.CreateOptionButton(CreateFrame("Frame"))
	button:Configure(24, "Go")
	Window.SkinButton(button)

	-- Then boxes and button states use the whole rounded texture, stretched with margins of 8.
	assert(ground.texturePath == ROUNDED and ground.slice and ground.slice[1] == 8
		and ground.slice[4] == 8, "the box is not rounded where slicing exists")
	assert(ground.vertexColor[1] == Window.COLORS.panel[1], "the rounded box is not tinted")
	local highlight = button:GetHighlightTexture()
	assert(highlight.texturePath == ROUNDED and highlight.texCoord[2] == 1 and highlight.texCoord[4] == 1,
		"the rounded button state is cropped")

	-- And the window frame itself stays square.
	for _, region in ipairs(MSBTOptionsWindowFrame.regions) do
		assert(region.texturePath ~= ROUNDED, "the window frame is rounded")
	end

	-- Given a client without texture slicing, then boxes stay square as before.
	Methods.SetTextureSliceMargins = nil
	ground = Window.Box(CreateFrame("Frame"), Window.COLORS.panel)
	assert(ground.texturePath == nil and ground.color[1] == Window.COLORS.panel[1],
		"the box is not square without slicing")
	button = MSBTOptions.Controls.CreateOptionButton(CreateFrame("Frame"))
	Window.SkinButton(button)
	assert(button:GetHighlightTexture().color[1] == Window.COLORS.gold[1],
		"the button highlight has no colour without slicing")
	local checkbox = MSBTOptions.Controls.CreateCheckbox(CreateFrame("Frame"))
	Window.SkinCheckbox(checkbox)
	assert(checkbox.checkFrame:GetHighlightTexture().color[4] == 0.2,
		"the checkbox highlight differs from before")
end

-- Rule: an entry without a page and without a classic tab is not offered.
do
	-- This script loads no pages, so Fonts & Colors has nothing to show.
	local function Entry(key)
		return Find(MSBTOptionsWindowFrame, function(region) return region.key == key end)
	end
	assert(not Entry("fontsColors"), "an entry without content is offered")
	assert(Entry("general") and Entry("changes"), "entries with content are missing")
end

-- Rule: flat, the dropdown arrow and the list scroll buttons are the gold chevron, the one above
-- the list upside down; the chosen text keeps to one left-aligned line.
do
	local dropdown = MSBTOptions.Controls.CreateDropdown(CreateFrame("Frame"))
	local listbox = MSBTOptions.Controls.CreateListbox(CreateFrame("Frame"))
	Window.SkinDropdown(dropdown)
	Window.SkinListbox(listbox)
	local arrow = dropdown.buttonFrame:GetNormalTexture()
	assert(arrow.texturePath == CHEVRON and arrow.vertexColor[1] == Window.COLORS.gold[1],
		"the arrow is not the chevron")
	local text = dropdown.selectedFontString
	assert(text.wordWrap == false and text.justifyH == "LEFT", "the chosen text is not one left-aligned line")
	assert(listbox.sliderFrame:GetThumbTexture().color[1] == Window.COLORS.border[1],
		"the scroll thumb is not flat")
	local up, down = listbox.upButton:GetNormalTexture(), listbox.downButton:GetNormalTexture()
	assert(up.texturePath == CHEVRON and up.vertexColor[1] == Window.COLORS.gold[1] and down.texturePath == CHEVRON,
		"the scroll buttons are not the chevron")
	assert(up.texCoord and up.texCoord[3] == 1 and up.texCoord[4] == 0 and not down.texCoord,
		"the chevron above the list does not point up")
end

-- Rule: a listbox's own selection bar becomes a flat fill.
do
	local listbox = MSBTOptions.Controls.CreateListbox(CreateFrame("Frame"))
	Window.SkinListbox(listbox)
	local bar = listbox.highlightFrame.regions[1]
	assert(bar.color and bar.color[4] == 0.16 and bar.blendMode == "BLEND", "the selection bar is not a flat fill")
end

-- A dropdown of the new design with items, its own list, and the shared list of the classic dropdowns.
local function NewDropdown(count)
	local dropdown = MSBTOptions.Controls.CreateDropdown(CreateFrame("Frame"))
	dropdown:Configure(120)
	for index = 1, count do dropdown:AddItem("Item " .. index, "id" .. index) end
	dropdown:SetSelectedID("id2")
	Window.SkinDropdown(dropdown)
	return dropdown
end
local function DropdownList(dropdown) return Find(dropdown, function(region) return region.displayFrame end) end
local sharedList = Find(MSBTOptionsWindowFrame, function(region) return region.listbox end)

-- Rule: a dropdown of the new design opens a list of its own, never the shared one; a second
-- click closes it, hiding the dropdown closes it for good, and a disabled dropdown opens nothing.
do
	-- Given a dropdown of the new design.
	local dropdown = NewDropdown(3)

	-- When its field is clicked.
	Click(dropdown.buttonFrame)

	-- Then its own list shows above other windows, and the shared list stays closed.
	local list = DropdownList(dropdown)
	assert(list and list:IsShown() and list.strata == "FULLSCREEN_DIALOG", "the dropdown opened no list of its own")
	assert(sharedList and not sharedList:IsShown(), "the dropdown opened the shared classic list")
	Click(dropdown.buttonFrame)
	assert(not list:IsShown(), "a second click left the list open")
	Click(dropdown.buttonFrame)
	dropdown:Hide()
	dropdown:Show()
	assert(not list:IsShown(), "the list came back with its dropdown")
	dropdown:Disable()
	Click(dropdown.buttonFrame)
	assert(not list:IsShown(), "a disabled dropdown opened its list")
end

-- Rule: the list lies under the field, as wide as the dropdown or its list width, 20 per line up
-- to its list height or 200; a line shows one line of text at 14, the chosen one gold, and
-- leaves the shared hover bar of the classic lists alone.
do
	local dropdown = NewDropdown(12)
	dropdown:SetListboxWidth(150)
	Click(dropdown.buttonFrame)
	local list = DropdownList(dropdown)
	local anchor = list.points.TOPLEFT
	assert(anchor.relative == dropdown and anchor.relativePoint == "BOTTOMLEFT", "the list is not under the field")
	assert(list.width == 150 and list.height == 200, "the list does not take the list width or the cap of 200")
	local line = list.lines[2]
	assert(line.height == 20 and line.fontString.points.LEFT.x == 14 and line.fontString.wordWrap == false,
		"a line is not one line of text at 14")
	local chosen = list.lines[1].fontString
	assert(chosen:GetText() == "Item 2" and chosen.textColor[1] == Window.COLORS.gold[1]
		and line.fontString.textColor[1] == Window.COLORS.text[1], "the list does not start at the chosen line in gold")
	assert(not line.scripts.OnEnter and not line.scripts.OnLeave, "a line moves the shared hover bar")
	assert(not list.highlightFrame:IsShown(), "the list shows a selection bar")
	Click(dropdown.buttonFrame)
	dropdown:SetListboxWidth(nil)
	dropdown:SetListboxHeight(60)
	Click(dropdown.buttonFrame)
	assert(list.width == 120 and list.height == 60, "the list does not take the dropdown width and list height")
	Click(dropdown.buttonFrame)
end

-- Rule: flat, the list has the field's box and its lines the hover fill of the window.
do
	local dropdown = NewDropdown(2)
	Click(dropdown.buttonFrame)
	local list = DropdownList(dropdown)
	local ground, hover
	for _, region in ipairs(list.regions) do
		if region.color and region.color[1] == Window.COLORS.field[1] then ground = region end
	end
	for _, region in ipairs(list.lines[1].regions) do
		if region.layer == "HIGHLIGHT" then hover = region end
	end
	assert(ground, "the list has no box")
	assert(hover and hover.color[4] == 0.08, "a line has no hover fill")
	Click(dropdown.buttonFrame)
end

-- Rule: clearing, removing from and disabling a dropdown close its own list and no other one.
do
	local actions = {
		Clear = function(dropdown) dropdown:Clear() end,
		RemoveItem = function(dropdown) dropdown:RemoveItem("id1") end,
		Disable = function(dropdown) dropdown:Disable() end,
	}
	for name, act in pairs(actions) do
		-- Given a dropdown with its list open.
		local dropdown, other = NewDropdown(3), NewDropdown(3)
		Click(dropdown.buttonFrame)
		local list = DropdownList(dropdown)
		assert(list:IsShown(), "the list did not open")

		-- When another dropdown is changed, and then this one.
		act(other)
		local kept = list:IsShown()
		act(dropdown)

		-- Then only its own change closed the list.
		assert(kept, name .. " of another dropdown closed the list")
		assert(not list:IsShown(), name .. " left the dropdown's list open")
	end
	-- The factory's own work was still done.
	local dropdown = NewDropdown(3)
	dropdown:RemoveItem("id1")
	assert(#dropdown.items == 2, "RemoveItem no longer removes")
	dropdown:Clear()
	assert(#dropdown.items == 0, "Clear no longer clears")
	dropdown:Disable()
	assert(not dropdown.buttonFrame:IsEnabled(), "Disable no longer disables")
end

-- Rule: a dropdown without items opens no list.
do
	-- Given a dropdown that was cleared.
	local dropdown = NewDropdown(3)
	dropdown:Clear()

	-- When its field is clicked.
	Click(dropdown.buttonFrame)

	-- Then no list shows for it.
	local list = DropdownList(dropdown)
	assert(not (list and list:IsShown()), "an empty dropdown opened a list")
end

-- Rule: picking a line does what the classic list does, then the list closes.
do
	local dropdown = NewDropdown(3)
	local picked
	dropdown:SetChangeHandler(function(this, id) picked = id end)
	Click(dropdown.buttonFrame)
	local list = DropdownList(dropdown)
	Click(list.lines[3])
	assert(picked == "id3" and dropdown.selectedItem == 3 and dropdown.selectedFontString:GetText() == "Item 3",
		"picking a line did not choose it")
	assert(not list:IsShown(), "the list stayed open after a pick")
end

-- Rule: "Reset profile" in the footer asks first and resets through the classic function.
do
	-- Given a setting saved at login and the Changes page open.
	local asked
	MSBTOptions.Popups = { ShowAcknowledge = function(config) asked = config end,
		UseDesignPopups = env.Popups.UseDesignPopups }
	Profiles.currentProfile.fontSize = 22
	snapshots:UpdateLoginSnapshot(true)
	Window.Show()
	Click(Footer())
	MikSBT.EraseTable(calls)

	-- When the button is clicked, nothing resets until the question is answered.
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.resetProfile)))
	assert(asked and asked.parentFrame == MSBTOptionsWindowFrame and #calls == 0,
		"Reset profile did not ask first")
	asked.acknowledgeHandler()

	-- Then the classic reset runs for the current profile, the page and count follow it,
	-- and Cancel undoes it.
	assert(calls[1][1] == "ResetProfile" and calls[1][2] == nil, "the classic reset did not run")
	assert(Footer():GetText() == string.format(L.WINDOW.changesCount, 1), "the count missed the reset")
	assert(#FindAll(MSBTOptionsWindowFrame, function(region)
		return region.keyFontString and region.shown
	end) == 1, "the page was not refreshed after the reset")
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))
	assert(Profiles.currentProfile.fontSize == 22, "Cancel did not undo the reset")
	Profiles.currentProfile.fontSize = nil
	snapshots:UpdateLoginSnapshot(true)
	MSBTOptions.Popups = env.Popups
end

-- Rule: search text shows the search page with the text; clearing returns to the entry before.
do
	-- Given the window on Sounds, which has a page, and no search page registered.
	local sounds, loot = {}, {}
	Window.RegisterPage("sounds", function(page) sounds.page = page end)
	Window.RegisterPage("lootAlerts", function(page) loot.page = page end)
	Window.Show()
	ClickEntry("sounds")
	local search = Find(MSBTOptionsWindowFrame, function(region)
		return region.editboxFrame and region.labelFontString:GetText() == L.WINDOW.search
	end).editboxFrame
	local Type = function(text) search:SetText(text) end
	Type("he")
	assert(sounds.page:IsShown(), "the field acted without a search page")
	Type("")

	-- When a search page is registered and text is typed.
	local created, refreshed = 0, {}
	Window.RegisterPage("search", function() created = created + 1 end,
		function(page, text) refreshed[#refreshed + 1] = text end)
	Type("he")
	Type("hea")

	-- Then the search page shows each text, and clearing returns to Sounds.
	assert(created == 1 and refreshed[1] == "he" and refreshed[2] == "hea",
		"the search page did not get the text")
	assert(not sounds.page:IsShown(), "the previous page stayed shown")
	Type("")
	assert(sounds.page:IsShown(), "clearing did not return to Sounds")

	-- When an entry is clicked during a search, the field empties and the entry shows.
	Type("he")
	ClickEntry("lootAlerts")
	assert(search:GetText() == "" and loot.page:IsShown(), "a click did not end the search")

	-- Then a later search returns to that entry.
	Type("x")
	Type("")
	assert(loot.page:IsShown(), "the search returned elsewhere")
	Window.Hide()
end

-- Rule: the skin helper restyles controls without breaking them.
do
	-- Given controls from MSBTOptions.Controls.
	local parent = CreateFrame("Frame")
	local editbox = MSBTOptions.Controls.CreateEditbox(parent)
	local checkbox = MSBTOptions.Controls.CreateCheckbox(parent)
	checkbox:Configure(18, "Label")
	local button = MSBTOptions.Controls.CreateOptionButton(parent)
	button:Configure(24, "Go")
	local slider = MSBTOptions.Controls.CreateSlider(parent)

	-- When they are skinned.
	Window.SkinEditbox(editbox)
	Window.SkinCheckbox(checkbox)
	Window.SkinButton(button, true)
	Window.SkinSlider(slider)

	-- Then the classic art is gone, flat fills replace it and enabling keeps the text colour.
	for _, region in ipairs(editbox.editboxFrame.regions) do
		assert(region.kind ~= "Texture" or not region.shown, "the classic edit box art is visible")
	end
	local red = Window.COLORS.red
	local hasRed
	for _, region in ipairs(button.regions) do
		if region.color and region.color[1] == red[1] then hasRed = true end
	end
	assert(hasRed, "the main button is not red")
	checkbox:Disable()
	checkbox:Enable()
	assert(checkbox.fontString.textColor[1] == Window.COLORS.text[1],
		"enabling the checkbox restored the classic colour")
	assert((slider.sliderFrame.backdropColor or {})[1] == Window.COLORS.field[1],
		"the slider is not skinned")
end

-- Rule: opening the window while the interface is hidden still sets the base for Cancel.
do
	-- Given the window opens while the interface is hidden, so its OnShow does not run.
	Window.Hide()
	MSBTOptionsWindowFrame.shown = true
	Window.Show()

	-- When a setting changes and Cancel is clicked.
	Profiles.SetOption(nil, "fontSize", 44)
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))

	-- Then the state from opening is back.
	assert(Profiles.currentProfile.fontSize == nil, "Cancel had no base after a hidden opening")
end

-- Rule: an icon button's symbol leaves 2 on each side, so it is 20 in a button of 24.
do
	-- When an icon button is built.
	local button = Window.CreateIconButton(CreateFrame("Frame"), "Play", "Play", Noop)

	-- Then every state's symbol is 2 inside the button.
	assert(button.width == 24, "the button is " .. button.width .. " wide")
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
		button:GetHighlightTexture() }) do
		local topLeft, bottomRight = texture.points.TOPLEFT, texture.points.BOTTOMRIGHT
		assert(topLeft.x == 2 and topLeft.y == -2 and bottomRight.x == -2 and bottomRight.y == 2, "the symbol is not 20")
	end
end

local function Grip()
	return Find(MSBTOptionsWindowFrame, function(region)
		local texture = rawget(region, "Normal")
		return texture ~= nil and (texture.texturePath or ""):find("SizeGrabber%-Up$") ~= nil
	end)
end
local function Near(value, expected) return math.abs(value - expected) < 1e-6 end

-- Rule: a grip in the bottom right corner wears the client's size grabber, lies above the Apply
-- button and explains itself in a tooltip.
do
	-- When the window opens.
	Window.Show()
	local grip = Grip()

	-- Then the grip is there, with the grabber's three states and the tooltip.
	assert(grip, "the window has no grip")
	local anchor = grip.points.BOTTOMRIGHT
	assert(anchor and anchor.relative == MSBTOptionsWindowFrame and grip.width == 16 and grip.height == 16,
		"the grip is not a small button in the bottom right corner")
	assert(grip:GetHighlightTexture().texturePath:find("SizeGrabber%-Highlight$")
		and grip:GetPushedTexture().texturePath:find("SizeGrabber%-Down$"), "the grip lacks the grabber's states")
	local apply = Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.apply))
	assert(grip:GetFrameLevel() > apply:GetFrameLevel(), "the grip lies below the Apply button")
	assert(grip.tooltip == L.WINDOW.resizeTooltip, "the grip has no tooltip")
end

-- Rule: while the grip is held the window scales with the cursor, its right edge keeping the
-- distance the grip was taken at; its top left corner stays on the screen, the scale is saved, and
-- a script runs per frame only during the drag.
do
	-- Given the window at scale 1.25 with its top left corner at 80, 560 of its own units, so its
	-- edges are at 100 and 1300 of the screen's units.
	local window, grip = MSBTOptionsWindowFrame, Grip()
	window:SetScale(1.25)
	window.left, window.top = 80, 560
	assert(grip.scripts.OnUpdate == nil, "a script runs per frame before the grip is held")

	-- When the grip is pressed 4 inside the right edge and the cursor has not moved yet.
	cursor.x = (1300 - 4) * 0.5
	grip.scripts.OnMouseDown(grip, "LeftButton")
	grip.scripts.OnUpdate(grip)

	-- Then the window keeps its scale.
	assert(Near(window.scale, 1.25), "taking the grip scaled the window: " .. window.scale)

	-- When the cursor moves 240 to the right while the button is held.
	cursor.x = (1300 - 4 + 240) * 0.5
	grip.scripts.OnUpdate(grip)

	-- Then the window is scaled to 1.5 at once, its corner stays and the scale is saved.
	assert(Near(window.scale, 1.5), "the window does not follow the cursor: " .. window.scale)
	local anchor = window.points.TOPLEFT
	assert(anchor and anchor.relative == UIParent and anchor.relativePoint == "BOTTOMLEFT"
		and Near(anchor.x * window.scale, 100) and Near(anchor.y * window.scale, 700) and window.points.CENTER == nil,
		"the top left corner moved")
	assert(saved.optionsScale == window.scale, "the scale was not saved")

	-- When the button is released, then nothing runs per frame any more.
	grip.scripts.OnMouseUp(grip, "LeftButton")
	assert(grip.scripts.OnUpdate == nil, "the script keeps running after the drag")
end

-- Rule: the scale stays within 0.8 and 2.
do
	-- Given the window at scale 1.5 with its left edge at 100 of the screen's units, the grip taken at its edge.
	local window, grip = MSBTOptionsWindowFrame, Grip()
	window.left, window.top = 100 / 1.5, 700 / 1.5
	cursor.x = (100 + 960 * 1.5) * 0.5
	grip.scripts.OnMouseDown(grip, "LeftButton")

	-- When the cursor is dragged far to the right, then the scale is 2.
	cursor.x = 4000
	grip.scripts.OnUpdate(grip)
	assert(window.scale == 2 and saved.optionsScale == 2, "the scale went beyond 2: " .. window.scale)

	-- When it is dragged to the left of the window, then the scale is 0.8.
	window.left = 100 / 2
	cursor.x = 0
	grip.scripts.OnUpdate(grip)
	assert(window.scale == 0.8 and saved.optionsScale == 0.8, "the scale went below 0.8: " .. window.scale)
	grip.scripts.OnMouseUp(grip, "LeftButton")
end

-- Rule: a drag ends when the grip is hidden, so nothing runs per frame when the window shows again.
do
	-- Given the grip is held.
	local grip = Grip()
	grip.scripts.OnMouseDown(grip, "LeftButton")
	assert(grip.scripts.OnUpdate, "holding the grip runs nothing")

	-- When the window is closed under it, then the script is gone.
	grip.scripts.OnHide(grip)
	assert(grip.scripts.OnUpdate == nil, "hiding the grip left the script running")
end

-- Rule: the scale is no larger than the screen holds.
do
	-- Given a screen 768 high, which holds the 640 high window 1.2 times.
	local window, grip = MSBTOptionsWindowFrame, Grip()
	local width, height = UIParent.width, UIParent.height
	UIParent.width, UIParent.height = 1365, 768
	window.left, window.top = 100 / window.scale, 700 / window.scale

	-- When the grip is dragged far to the right, then the scale is 1.2.
	grip.scripts.OnMouseDown(grip, "LeftButton")
	cursor.x = 4000
	grip.scripts.OnUpdate(grip)
	grip.scripts.OnMouseUp(grip, "LeftButton")
	assert(Near(window.scale, 1.2) and Near(saved.optionsScale, 1.2), "the window outgrew the screen: " .. window.scale)

	-- When the window opens with a scale saved on a larger screen, then it is held to this one.
	Window.Hide()
	saved.optionsScale = 1.5
	Window.Show()
	assert(Near(window.scale, 1.2), "a saved scale outgrew the screen: " .. window.scale)
	UIParent.width, UIParent.height = width, height
end

-- Rule: a right click on the grip sets the scale back to 1 and forgets the saved one.
do
	-- Given the window at another scale.
	local window, grip = MSBTOptionsWindowFrame, Grip()
	window.left, window.top = 100 / window.scale, 700 / window.scale

	-- When the grip is right-clicked.
	grip.scripts.OnMouseDown(grip, "RightButton")
	assert(grip.scripts.OnUpdate == nil, "a right click started a drag")
	grip.scripts.OnMouseUp(grip, "RightButton")

	-- Then the window has the scale 1 and none is saved.
	assert(window.scale == 1 and saved.optionsScale == nil, "the scale was not reset")
	Window.Hide()
end

print("Options window tests passed")
