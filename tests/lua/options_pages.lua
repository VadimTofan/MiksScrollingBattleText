-- Describe: the General, Fonts & Colors, Sounds and Profile pages of the new options window.
local env = dofile("tests/lua/options_window_env.lua")
local calls, Profiles, L, tabs, Window = env.calls, env.Profiles, env.L, env.tabs, env.Window
local Find, FindAll, Labelled, Click, ClickEntry, IsInWindow =
	env.Find, env.FindAll, env.Labelled, env.Click, env.ClickEntry, env.IsInWindow

-- Which icon each icon button was built with.
local skinned = {}
local createIconButton = Window.CreateIconButton
Window.CreateIconButton = function(parent, icon, tooltip, handler)
	local button = createIconButton(parent, icon, tooltip, handler)
	skinned[button] = icon
	return button
end

-- Popups, classic exports and the sound media record what the pages hand them.
local shown = {}
local function Recorder(name)
	return function(...) shown[#shown + 1] = { name, ... } end
end
GetLocale = function() return "deDE" end
MikSBT.Print = Recorder("Print")
MSBTOptions.Popups = {
	ShowAcknowledge = Recorder("ShowAcknowledge"), ShowInput = Recorder("ShowInput"),
	ShowPartialEffects = Recorder("ShowPartialEffects"), ShowDamageColors = Recorder("ShowDamageColors"),
	ShowClassColors = Recorder("ShowClassColors"), DisableControls = Recorder("DisableControls"),
	UseDesignPopups = env.Popups.UseDesignPopups,
}
MSBTOptions.Tabs = { general = {
	ShowMasterFont = Recorder("ShowMasterFont"),
	ResetBlizzardSCT = Recorder("ResetBlizzardSCT"), ReportImport = Recorder("ReportImport"),
} }
MSBTOptions.ProfileTransfer = { ShowExport = Recorder("ShowExport"), ShowImport = Recorder("ShowImport") }
local media = { sounds = { Alarm = "b.ogg", Beep = "a.ogg" } }
MikSBT.Media = { sounds = media.sounds, PlaySound = function(name) Recorder("PlaySound")(name) return true end }
-- Like the shared media library, a name registered once cannot be registered again.
function MikSBT.Media.RegisterSound(name, file)
	if media.sounds[name] then return false end
	media.sounds[name] = file
	return true
end
MikSBT.API = { Sounds = { NormalizeFile = function(_, file) return file end } }
Profiles.savedMedia.sounds = { Alarm = "b.ogg", Beep = "a.ogg" }
-- The game resolves missing values from the master profile; this store has none.
for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")
local general = MSBTOptions.Tabs.general

local function Last() return shown[#shown] end
local function Checkboxes(label)
	return FindAll(MSBTOptionsWindowFrame, function(region)
		return region.checkFrame and region.fontString:GetText() == label and region.shown
	end)
end
local function Toggle(checkbox, isChecked)
	checkbox.checkFrame:SetChecked(isChecked)
	Click(checkbox.checkFrame)
end

-- Rule: the sidebar shows the rebuilt entries as pages, not as classic tabs.
do
	Window.Show()
	local function Entry(key)
		return Find(MSBTOptionsWindowFrame, function(region) return region.key == key end)
	end
	assert(Entry("fontsColors") and not Entry("resetBlizzardSCT") and not Entry("language"),
		"the sidebar entries are not the new ones")
	for _, key in ipairs({ "general", "sounds", "profile" }) do
		ClickEntry(key)
		assert(not IsInWindow(tabs[key]) and not tabs[key]:IsShown(), key .. " hosts the classic tab")
	end
end

-- Rule: each General control saves the field, value and default of the classic General tab.
do
	ClickEntry("general")
	-- Label, which of equal labels, field, value saved when checked, reapplies context.
	local expected = {
		{ "enableBlizzardDamage", 1, "blizzardDamageEnabled", true, true },
		{ "disableOutgoing", 1, "msbtOutgoingDisabled", true, true },
		{ "disableNotifications", 1, "msbtNotificationsDisabled", true, true },
		{ "disableIncoming", 1, "msbtIncomingDisabled", true, true },
		{ "disableOutgoing", 2, "blizzardOutgoingDisabled", true, true },
		{ "disableNotifications", 2, "blizzardNotificationsDisabled", true, true },
		{ "disableIncoming", 2, "blizzardIncomingDisabled", true, true },
		{ "enableNames", 1, "hideSkills", false },
		{ "enableIcons", 1, "skillIconsDisabled", false },
		{ "stickyCrits", 1, "stickyCritsDisabled", false },
		{ "stackSimilarHits", 1, "stackSimilarHits", true },
		{ "shortenNumbers", 1, "shortenNumbers", true },
	}
	for _, case in ipairs(expected) do
		MikSBT.EraseTable(calls)
		Toggle(Checkboxes(L.CHECKBOXES[case[1]].label)[case[2]], true)
		assert(calls[1][1] == "SetOption" and calls[1][2] == nil and calls[1][3] == case[3]
			and calls[1][4] == case[4] and calls[1][5] == nil, "wrong save for " .. case[3])
		assert((calls[2] ~= nil and calls[2][1] == "ApplyContextOptions") == (case[5] == true),
			"wrong context reapply for " .. case[3])
	end

	MikSBT.EraseTable(calls)
	Toggle(Checkboxes(L.CHECKBOXES.enableMSBT.label)[1], false)
	assert(calls[1][1] == "SetOptionUserDisabled" and calls[1][2] == true, "MSBT switch differs")

	MikSBT.EraseTable(calls)
	local slider = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.sliderFrame and region.shown
	end)
	slider.sliderFrame:SetValue(120)
	assert(calls[1][3] == "animationSpeed" and calls[1][4] == 120 and calls[1][5] == nil,
		"the speed slider differs")

	-- When the profile changes elsewhere, the page shows it on the next show.
	Profiles.currentProfile.hideSkills = true
	ClickEntry("sounds")
	ClickEntry("general")
	assert(not Checkboxes(L.CHECKBOXES.enableNames.label)[1]:GetChecked(), "the page did not refresh")
	Profiles.currentProfile.hideSkills = nil
end

-- Rule: the Options Design dropdown lists the registered designs, shows the chosen one and switches.
do
	local Designs = MSBTOptions.Designs
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.optionsDesign.label
	end)
	-- Given the new design is chosen and the page shows again.
	Designs.Select("forever")
	ClickEntry("sounds")
	ClickEntry("general")

	-- Then every design is listed with its label in order, and the chosen one is shown.
	assert(table.concat(dropdown.items, ",") == L.MSG_CLASSIC_DESIGN .. "," .. L.MSG_FOREVER_DESIGN
		and table.concat(dropdown.itemIDs, ",") == "classic,forever", "the page does not list the registered designs")
	assert(dropdown:GetSelectedID() == "forever", "the page does not show the chosen design")

	-- When Classic is picked, then it is saved and the classic window replaces this one with its popups.
	dropdown:changeHandler("classic")
	assert(Profiles.savedVariables.optionsDesign == nil, "the pick was not saved")
	assert(MSBTMainOptionsFrame:IsShown() and not MSBTOptionsWindowFrame:IsShown(),
		"choosing Classic did not switch to the classic window")
	assert(env.Popups.design == "classic", "the classic window opened with the new design's popups")

	-- When New is chosen again, then this window replaces the classic one with its popups.
	Designs.Select("forever")
	assert(MSBTOptionsWindowFrame:IsShown() and not MSBTMainOptionsFrame:IsShown(),
		"choosing New did not switch to the new window")
	assert(env.Popups.design == "forever", "the new window opened with the classic popups")
end

-- Rule: Reset Blizzard SCT asks first and runs the classic reset.
do
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.BUTTONS.resetBlizzardSCT.label)))
	assert(Last()[1] == "ShowAcknowledge", "the reset did not ask")
	Last()[2].acknowledgeHandler()
	assert(Last()[1] == "ResetBlizzardSCT", "the classic reset did not run")
end

-- Rule: the page explains the reset and the language with the texts every language has.
do
	local function Tells(text)
		return Find(MSBTOptionsWindowFrame, function(frame)
			for _, region in ipairs(frame.regions) do
				if region.GetText and region:GetText() == text then return true end
			end
		end)
	end
	assert(Tells(L.TABS.resetBlizzardSCT.tooltip), "the reset is not explained in the classic words")
	assert(Tells(L.LANGUAGE_INFO), "the language is not explained in the classic words")
end

-- Rule: Fonts & Colors opens each existing popup at its button.
do
	ClickEntry("fontsColors")
	local buttons = FindAll(MSBTOptionsWindowFrame, function(region)
		return region.kind == "Button" and region:GetText() == L.WINDOW.edit and region.shown
	end)
	assert(#buttons == 4, "Fonts & Colors does not list four entries")
	Click(buttons[1])
	assert(Last()[1] == "ShowMasterFont" and Last()[3] == buttons[1], "master fonts did not open")
	assert(not buttons[2]:IsEnabled(), "the other entries stayed enabled while a popup is open")
	Click(buttons[2])
	assert(Last()[1] == "ShowMasterFont", "a second popup opened over the first")
	Last()[6]()
	assert(buttons[2]:IsEnabled(), "closing the popup did not enable the entries")
	for index, name in ipairs({ "ShowPartialEffects", "ShowDamageColors", "ShowClassColors" }) do
		Click(buttons[index + 1])
		local popup = Last()[2]
		assert(Last()[1] == name and popup.anchorFrame == buttons[index + 1]
			and popup.anchorPoint == "TOPRIGHT" and popup.relativePoint == "BOTTOMRIGHT", name .. " did not open")
		popup.hideHandler()
	end
end

-- Rule: Sounds lists, plays and removes custom sounds through the classic functions.
do
	ClickEntry("sounds")
	local function Rows()
		return FindAll(MSBTOptionsWindowFrame, function(region)
			return region.nameFontString and region.shown
		end)
	end
	local rows = Rows()
	assert(#rows == 2 and rows[1].nameFontString:GetText() == "Alarm"
		and rows[1].fileFontString:GetText() == "b.ogg", "the custom sounds are not listed in order")

	local function IconButton(label)
		return Find(rows[1], function(region) return region.kind == "Button" and region.tooltip == label end)
	end
	local play = IconButton(L.BUTTONS.playSound.label .. "\n" .. L.BUTTONS.playSound.tooltip)
	local remove = IconButton(L.WINDOW.remove .. "\n" .. L.WINDOW.removeTooltip)
	assert(play and remove and skinned[play] == "Play" and skinned[remove] == "Delete"
		and (play:GetText() or "") == "" and (remove:GetText() or "") == "",
		"Play and Remove are not icon buttons with their label and explanation as tooltips")
	Click(play)
	assert(Last()[1] == "PlaySound" and Last()[2] == "Alarm", "Play did not use the classic path")

	Click(remove)
	local ask = Last()
	assert(ask[1] == "ShowAcknowledge" and ask[2].saveArg1 == "Alarm"
		and ask[2].anchorPoint == "TOPRIGHT", "Remove did not ask inside the window")
	ask[2].acknowledgeHandler(ask[2].saveArg1)
	assert(Profiles.savedMedia.sounds.Alarm == nil, "Remove kept the saved sound")
	assert(media.sounds.Alarm == "b.ogg", "Remove dropped the registered sound before a reload")
	assert(#Rows() == 1, "the list did not refresh")

	MikSBT.EraseTable(calls)
	Toggle(Checkboxes(L.CHECKBOXES.enableSounds.label)[1], true)
	assert(calls[1][3] == "soundsDisabled" and calls[1][4] == false, "the sound switch differs")

	-- When sounds are added through the popup, which hides before it saves.
	local function Add(name, file)
		Click(Find(MSBTOptionsWindowFrame, Labelled(L.BUTTONS.addCustomSound.label)))
		local input = Last()[2]
		assert(Last()[1] == "ShowInput", "Add sound did not open the classic popup")
		local problem = input.validateHandler(name, file)
		if problem then return problem end
		input.hideHandler()
		input.saveHandler({ inputText = name, secondInputText = file })
	end

	-- Then a new sound and the removed name added again both show at once,
	-- and a name another addon registered stays taken.
	assert(not Add("Chime", "c.ogg") and #Rows() == 2, "the added sound is not listed")
	assert(not Add("Alarm", "d.ogg") and #Rows() == 3, "the removed name cannot be added again")
	assert(Profiles.savedMedia.sounds.Alarm == "d.ogg" and media.sounds.Alarm == "d.ogg",
		"adding the name again did not replace the sound")
	media.sounds.Foreign = "f.ogg"
	assert(Add("Foreign", "g.ogg") == L.MSG_SOUND_NAME_ALREADY_EXISTS, "a foreign sound was replaced")

	-- When a saved sound lost its name to another addon's sound and is removed,
	-- then that sound stays and the name stays taken.
	Profiles.savedMedia.sounds.Foreign = "mine.ogg"
	MSBTOptions.Sounds.RemoveSound("Foreign")
	assert(media.sounds.Foreign == "f.ogg" and Add("Foreign", "g.ogg") == L.MSG_SOUND_NAME_ALREADY_EXISTS,
		"removing took over another addon's sound")

	-- The empty-list text lies on the list, above its ground.
	local listbox = Rows()[1]:GetParent():GetParent()
	assert(Find(listbox, function(region) return region:GetText() == L.WINDOW.noSounds end),
		"the empty-list text is not on the list")
end

-- Rule: Profile copy, reset, delete, export and import take the classic paths.
do
	ClickEntry("profile")
	MikSBT.EraseTable(calls)
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.BUTTONS.copyProfile.label)))
	local input = Last()[2]
	assert(input.validateHandler("Default") == L.MSG_PROFILE_ALREADY_EXISTS
		and input.validateHandler("") == L.MSG_INVALID_PROFILE_NAME and not input.validateHandler("New"),
		"the copy name is not validated")
	local delete = Find(MSBTOptionsWindowFrame, function(region)
		return region.kind == "Button" and region:GetText() == L.BUTTONS.deleteProfile.label and region.shown
	end)
	assert(not delete:IsEnabled(), "Default can be deleted")
	-- The popup hides before it saves.
	input.hideHandler()
	input.saveHandler({ inputText = "New" })
	assert(calls[1][1] == "CopyProfile" and calls[1][2] == "Default" and calls[1][3] == "New"
		and calls[2][1] == "SelectProfile" and calls[2][2] == "New", "copy differs")
	assert(Find(MSBTOptionsWindowFrame, function(region)
		return region.kind == "FontString" and region:GetText() == string.format(L.WINDOW.currentProfile, "New")
	end) and delete:IsEnabled(), "the page still shows the old profile after the copy")

	Profiles.SelectProfile("Default")
	MikSBT.EraseTable(calls)
	local page = delete:GetParent()
	Click(Find(page, Labelled(L.BUTTONS.resetProfile.label)))
	Last()[2].acknowledgeHandler()
	assert(calls[1][1] == "ResetProfile" and calls[1][2] == "Default", "reset differs")
	Profiles.currentProfile.animationSpeed = 100

	Last()[2].hideHandler()
	assert(not delete:IsEnabled(), "Default can be deleted")
	Profiles.SelectProfile("Alt")
	ClickEntry("general")
	ClickEntry("profile")
	assert(delete:IsEnabled(), "Delete stayed disabled")
	MikSBT.EraseTable(calls)
	Click(delete)
	Last()[2].acknowledgeHandler()
	assert(calls[1][1] == "DeleteProfile" and calls[1][2] == "Alt", "delete differs")
	Profiles.SelectProfile("Default")

	Profiles.ExportProfile = function(name) return "TEXT:" .. name end
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.PROFILE_TRANSFER.export)))
	assert(Last()[1] == "ShowExport" and Last()[3] == "TEXT:Default", "export differs")
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.PROFILE_TRANSFER.import)))
	assert(Last()[1] == "ShowImport" and Last()[2].importHandler == Profiles.ImportProfile
		and Last()[2].successHandler == general.ReportImport, "import differs")
	Window.Hide()
end

-- Rule: the German texts give the Sounds and Profile pages their own hints and Inherit a word of its own.
do
	local classic = L.CHECKBOXES.inheritField.label
	-- English keeps its classic word, as every language does that defines no other.
	assert(L.CHECKBOXES.inheritValue == nil, "English has a second Inherit text")
	-- The game skips the byte order mark of the file; the loader here does not.
	local file = io.open("MSBTOptions/Localization/localization.de.lua", "rb")
	local source = file:read("*a"):gsub("^" .. string.char(239, 187, 191), "")
	file:close()
	assert(loadstring(source, "@localization.de.lua"))()
	assert(L.WINDOW.soundsHint == "Ereignis-Sounds einschalten und eigene Sounddateien hinzuf\195\188gen.",
		"the Sounds hint is not German")
	assert(L.WINDOW.profileHint == "Profile kopieren, zur\195\188cksetzen, l\195\182schen, exportieren und importieren.",
		"the Profile hint is not German")
	assert(L.CHECKBOXES.inheritValue.label == "Erben" and L.CHECKBOXES.inheritValue.tooltip
		== "Erbt den Wert der \195\188bergeordneten Einstellung.\n\nHaken entfernen, um ihn zu \195\188berschreiben.",
		"Inherit has no German word of its own")
	assert(L.CHECKBOXES.inheritValue.label ~= L.WINDOW.apply, "Inherit reads like Apply")
	assert(L.CHECKBOXES.inheritField.label == "\195\156bernehmen" and classic == "Inherit",
		"the classic Inherit label changed")
end

print("Options pages tests passed")
