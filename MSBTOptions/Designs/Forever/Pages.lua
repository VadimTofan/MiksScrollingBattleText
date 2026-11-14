
local MSBTWindow = MSBTOptions.Window
local MSBTDesigns = MSBTOptions.Designs
local MSBTControls = MSBTOptions.Controls
local MSBTPopups = MSBTOptions.Popups
local MSBTSounds = MSBTOptions.Sounds
local MSBTGeneral = MSBTOptions.Tabs.general
local MSBTProfiles = MikSBT.Profiles
local L = MikSBT.translations

local COLORS = MSBTWindow.COLORS
local EraseTable = MikSBT.EraseTable
local Print = MikSBT.Print



local COLUMN = 345
local ROW_HEIGHT = 26
local SOUND_LINE_HEIGHT = 30
local DEFAULT_PROFILE_NAME = "Default"

-- Field part and text of the sub-options under each enable switch, as on the classic General tab.
local SUB_OPTIONS = {
	{ "Outgoing", "disableOutgoing" },
	{ "Notifications", "disableNotifications" },
	{ "Incoming", "disableIncoming" },
}
local FONTS_COLORS = {
	{ "masterFont" },
	{ "partialEffects", MSBTPopups.ShowPartialEffects },
	{ "damageColors", MSBTPopups.ShowDamageColors },
	{ "classColors", MSBTPopups.ShowClassColors },
}



-- Popups copy what they need, so one table serves every click, as on the classic tabs.
local config = {}
local generalSwitches = {}
local soundSwitches = {}
local fontsColorsButtons = {}
local soundNames = {}

local msbtCheckbox
local speedSlider
local designDropdown
local soundsPage
local soundListbox
local noSoundsFontString
local profilePage
local profileFontString
local deleteButton



local function CreateText(parent, template, color, text)
	local fontString = parent:CreateFontString(nil, "OVERLAY", template)
	fontString:SetTextColor(color[1], color[2], color[3])
	fontString:SetJustifyH("LEFT")
	fontString:SetText(text)
	return fontString
end


local function CreateSection(page, top, height)
	local section = CreateFrame("Frame", nil, page)
	section:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
	section:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -top)
	section:SetHeight(height)
	MSBTWindow.Box(section, COLORS.panel)
	return section
end


local function CreateButton(parent, label, tooltip, handler)
	local button = MSBTControls.CreateOptionButton(parent)
	button:Configure(ROW_HEIGHT, label, tooltip)
	button:SetClickHandler(handler)
	MSBTWindow.SkinButton(button)
	return button
end


local function PopupConfig(parent, anchor, hideHandler)
	EraseTable(config)
	config.parentFrame = parent
	config.anchorFrame = anchor
	config.hideHandler = hideHandler
	return config
end


-- inverted saves the opposite for the "...Disabled" fields; context reapplies the Blizzard text.
local function OnClickSwitch(this, isChecked)
	if this.inverted then isChecked = not isChecked end
	MSBTProfiles.SetOption(nil, this.option, isChecked)
	if this.context then MSBTProfiles.ApplyContextOptions() end
end


local function CreateSwitch(parent, switches, localeKey, option, inverted, context)
	local locale = L.CHECKBOXES[localeKey]
	local checkbox = MSBTControls.CreateCheckbox(parent)
	checkbox:Configure(20, locale.label, locale.tooltip)
	checkbox:SetClickHandler(OnClickSwitch)
	checkbox.option, checkbox.inverted, checkbox.context = option, inverted, context
	MSBTWindow.SkinCheckbox(checkbox)
	switches[#switches + 1] = checkbox
	return checkbox
end


local function PopulateSwitches(switches)
	local profile = MSBTProfiles.currentProfile
	for _, checkbox in ipairs(switches) do
		local value = profile[checkbox.option]
		if checkbox.inverted then value = not value end
		checkbox:SetChecked(value)
	end
end


local function CurrentProfileName()
	for name, profile in pairs(MSBTProfiles.savedVariables.profiles) do
		if profile == MSBTProfiles.currentProfile then return name end
	end
end



local function RefreshGeneral()
	msbtCheckbox:SetChecked(not MSBTProfiles.IsModDisabled())
	PopulateSwitches(generalSwitches)
	speedSlider:SetValue(MSBTProfiles.currentProfile.animationSpeed)
	designDropdown:SetSelectedID(MSBTDesigns.GetSelected())
end


local function ResetBlizzardSCT()
	MSBTGeneral.ResetBlizzardSCT()
	RefreshGeneral()
end


local function OnClickResetBlizzardSCT(this)
	PopupConfig(this:GetParent(), this).acknowledgeHandler = ResetBlizzardSCT
	MSBTPopups.ShowAcknowledge(config)
end


local function CreateSubOptions(section, side, enable)
	for index, option in ipairs(SUB_OPTIONS) do
		CreateSwitch(section, generalSwitches, option[2], side .. option[1] .. "Disabled", false, true)
			:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 20, -6 - (index - 1) * ROW_HEIGHT)
	end
end


local function CreateGeneral(page)
	local section = CreateSection(page, 0, 130)
	local locale = L.CHECKBOXES["enableMSBT"]
	msbtCheckbox = MSBTControls.CreateCheckbox(section)
	msbtCheckbox:Configure(20, locale.label, locale.tooltip)
	msbtCheckbox:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12)
	msbtCheckbox:SetClickHandler(function(this, isChecked)
		MSBTProfiles.SetOptionUserDisabled(not isChecked)
		RefreshGeneral()
	end)
	MSBTWindow.SkinCheckbox(msbtCheckbox)
	CreateSubOptions(section, "msbt", msbtCheckbox)
	local blizzard = CreateSwitch(section, generalSwitches, "enableBlizzardDamage", "blizzardDamageEnabled", false, true)
	blizzard:SetPoint("TOPLEFT", section, "TOPLEFT", COLUMN, -12)
	CreateSubOptions(section, "blizzard", blizzard)

	section = CreateSection(page, 140, 150)
	local anchor
	for index, switch in ipairs({
		{ "enableNames", "hideSkills", true },
		{ "enableIcons", "skillIconsDisabled", true },
		{ "stickyCrits", "stickyCritsDisabled", true },
		{ "stackSimilarHits", "stackSimilarHits" },
		{ "shortenNumbers", "shortenNumbers" },
	}) do
		anchor = CreateSwitch(section, generalSwitches, switch[1], switch[2], switch[3])
		anchor:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12 - (index - 1) * ROW_HEIGHT)
	end
	locale = L.SLIDERS["animationSpeed"]
	speedSlider = MSBTControls.CreateSlider(section)
	speedSlider:Configure(300, locale.label, locale.tooltip)
	speedSlider:SetPoint("TOPLEFT", section, "TOPLEFT", COLUMN, -30)
	speedSlider:SetMinMaxValues(20, 250)
	speedSlider:SetValueStep(10)
	speedSlider:SetValueChangedHandler(function(this, value)
		MSBTProfiles.SetOption(nil, "animationSpeed", value)
	end)
	MSBTWindow.SkinSlider(speedSlider)

	section = CreateSection(page, 300, 156)
	locale = L.DROPDOWNS["optionsDesign"]
	designDropdown = MSBTControls.CreateDropdown(section)
	designDropdown:Configure(180, locale.label, locale.tooltip)
	designDropdown:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -8)
	for _, key in ipairs(MSBTDesigns.keys) do
		designDropdown:AddItem(MSBTDesigns.designs[key].label, key)
	end
	designDropdown:SetChangeHandler(function(this, id) MSBTDesigns.Select(id) end)
	MSBTWindow.SkinDropdown(designDropdown)

	locale = L.BUTTONS["resetBlizzardSCT"]
	local button = CreateButton(section, locale.label, locale.tooltip, OnClickResetBlizzardSCT)
	button:SetPoint("TOPLEFT", section, "TOPLEFT", COLUMN, -18)
	local fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, L.TABS.resetBlizzardSCT.tooltip)
	fontString:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -6)
	fontString:SetWidth(320)

	fontString = CreateText(section, "GameFontHighlightSmall", COLORS.text, L.LANGUAGE_INFO)
	fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -96)
	fontString:SetPoint("RIGHT", section, "RIGHT", -12, 0)
end



local function EnableFontsColors()
	for _, button in ipairs(fontsColorsButtons) do button:Enable() end
end


local function OnClickFontsColors(this)
	for _, button in ipairs(fontsColorsButtons) do button:Disable() end
	local parent = this:GetParent()
	if this.show then
		PopupConfig(parent, this, EnableFontsColors)
		config.anchorPoint, config.relativePoint = "TOPRIGHT", "BOTTOMRIGHT"
		this.show(config)
	else
		MSBTGeneral.ShowMasterFont(parent, this, "TOPRIGHT", "BOTTOMRIGHT", EnableFontsColors)
	end
end


local function CreateFontsColors(page)
	local section = CreateSection(page, 0, #FONTS_COLORS * 70 + 10)
	for index, entry in ipairs(FONTS_COLORS) do
		local locale = L.BUTTONS[entry[1]]
		local top = 10 + (index - 1) * 70
		local fontString = CreateText(section, "GameFontNormal", COLORS.gold, locale.label)
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top)
		fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, locale.tooltip)
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top - 20)
		fontString:SetWidth(520)
		local button = CreateButton(section, L.WINDOW.edit, locale.tooltip, OnClickFontsColors)
		button:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -top - 8)
		button.show = entry[2]
		fontsColorsButtons[index] = button
	end
end



local function RefreshSounds()
	PopulateSwitches(soundSwitches)
	local sounds = MSBTProfiles.savedMedia.sounds
	EraseTable(soundNames)
	for name in pairs(sounds) do soundNames[#soundNames + 1] = name end
	table.sort(soundNames)
	soundListbox:Clear()
	for index = 1, #soundNames do soundListbox:AddItem(index) end
	noSoundsFontString:SetShown(#soundNames == 0)
end


local function RemoveSound(name)
	MSBTSounds.RemoveSound(name)
	RefreshSounds()
end


local function OnClickPlay(this)
	MSBTSounds.PlaySound(soundNames[this:GetParent().item])
end


local function OnClickRemove(this)
	PopupConfig(soundsPage, this)
	config.anchorPoint, config.relativePoint = "TOPRIGHT", "BOTTOMRIGHT"
	config.acknowledgeHandler = RemoveSound
	config.saveArg1 = soundNames[this:GetParent().item]
	MSBTPopups.ShowAcknowledge(config)
end


local function CreateSoundLine(listbox)
	local line = CreateFrame("Button", nil, listbox)
	line:EnableMouse(false)
	line.nameFontString = CreateText(line, "GameFontHighlight", COLORS.text)
	line.nameFontString:SetPoint("LEFT", line, "LEFT", 8, 0)
	line.nameFontString:SetWidth(200)
	local remove = MSBTWindow.CreateIconButton(line, "Delete", L.WINDOW.remove .. "\n" .. L.WINDOW.removeTooltip,
		OnClickRemove)
	remove:SetPoint("RIGHT", line, "RIGHT", -4, 0)
	local play = MSBTWindow.CreateIconButton(line, "Play",
		L.BUTTONS.playSound.label .. "\n" .. L.BUTTONS.playSound.tooltip, OnClickPlay)
	play:SetPoint("RIGHT", remove, "LEFT", -8, 0)

	-- The path ends at the play button.
	line.fileFontString = CreateText(line, "GameFontHighlightSmall", COLORS.hint)
	line.fileFontString:SetPoint("LEFT", line, "LEFT", 216, 0)
	line.fileFontString:SetPoint("RIGHT", play, "LEFT", -8, 0)
	return line
end


local function DisplaySoundLine(listbox, line, item)
	local name = soundNames[item]
	line.item = item
	line.nameFontString:SetText(name)
	line.fileFontString:SetText(MSBTProfiles.savedMedia.sounds[name])
end


local function CreateSounds(page, width, height)
	soundsPage = page
	local section = CreateSection(page, 0, 110)
	local anchor = CreateSwitch(section, soundSwitches, "enableSounds", "soundsDisabled", true)
	anchor:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12)
	for index, switch in ipairs({
		{ "lowHealthSound", "lowHealthSoundDisabled" },
		{ "lowManaSound", "lowManaSoundDisabled" },
	}) do
		CreateSwitch(section, soundSwitches, switch[1], switch[2], true)
			:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 20, -6 - (index - 1) * ROW_HEIGHT)
	end

	local locale = L.BUTTONS["addCustomSound"]
	CreateButton(section, locale.label, locale.tooltip, function(this)
		MSBTSounds.ShowAddSound(page, this, RefreshSounds)
	end):SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -12)

	soundListbox = MSBTControls.CreateListbox(page)
	soundListbox:Configure(width, height - 120, SOUND_LINE_HEIGHT)
	soundListbox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -120)
	soundListbox:SetCreateLineHandler(CreateSoundLine)
	soundListbox:SetDisplayHandler(DisplaySoundLine)
	MSBTWindow.Fill(soundListbox, COLORS.panel)
	MSBTWindow.SkinListbox(soundListbox)

	noSoundsFontString = CreateText(soundListbox, "GameFontHighlight", COLORS.hint, L.WINDOW.noSounds)
	noSoundsFontString:SetPoint("TOPLEFT", soundListbox, "TOPLEFT", 8, -10)
end



local function RefreshProfile()
	local name = CurrentProfileName()
	profileFontString:SetText(string.format(L.WINDOW.currentProfile, name or DEFAULT_PROFILE_NAME))
	if name == DEFAULT_PROFILE_NAME then deleteButton:Disable() else deleteButton:Enable() end
end


local function ValidateProfileName(name)
	if not name or name == "" then return L.MSG_INVALID_PROFILE_NAME end
	if MSBTProfiles.savedVariables.profiles[name] then return L.MSG_PROFILE_ALREADY_EXISTS end
end


local function CopyProfile(settings)
	MSBTProfiles.CopyProfile(CurrentProfileName(), settings.inputText)
	MSBTProfiles.SelectProfile(settings.inputText)
	-- The popup ran its hide handler before saving, so the page refreshes once more.
	RefreshProfile()
end


local function ResetProfile()
	MSBTProfiles.ResetProfile(CurrentProfileName())
end


local function DeleteProfile()
	MSBTProfiles.DeleteProfile(CurrentProfileName())
end


local function OnClickCopy(this)
	local locale = L.EDITBOXES["copyProfile"]
	PopupConfig(profilePage, this, RefreshProfile)
	config.defaultText = L.MSG_NEW_PROFILE
	config.editboxLabel = locale.label
	config.editboxTooltip = locale.tooltip
	config.validateHandler = ValidateProfileName
	config.saveHandler = CopyProfile
	MSBTPopups.ShowInput(config)
end


local function OnClickReset(this)
	PopupConfig(profilePage, this, RefreshProfile).acknowledgeHandler = ResetProfile
	MSBTPopups.ShowAcknowledge(config)
end


local function OnClickDelete(this)
	PopupConfig(profilePage, this, RefreshProfile).acknowledgeHandler = DeleteProfile
	MSBTPopups.ShowAcknowledge(config)
end


local function OnClickExport()
	local text, errorCode = MSBTProfiles.ExportProfile(CurrentProfileName())
	if not text then
		Print(L.PROFILE_TRANSFER.errors[errorCode], 1, 0.3, 0.3)
		return
	end
	MSBTOptions.ProfileTransfer.ShowExport({ parentFrame = profilePage, hideHandler = RefreshProfile }, text)
end


local function OnClickImport()
	MSBTOptions.ProfileTransfer.ShowImport({
		parentFrame = profilePage,
		hideHandler = RefreshProfile,
		importHandler = MSBTProfiles.ImportProfile,
		successHandler = MSBTGeneral.ReportImport,
	})
end


local function CreateProfile(page)
	profilePage = page
	local section = CreateSection(page, 0, 130)
	profileFontString = CreateText(section, "GameFontNormal", COLORS.gold)
	profileFontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12)

	local locale = L.BUTTONS["copyProfile"]
	local button = CreateButton(section, locale.label, locale.tooltip, OnClickCopy)
	button:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -44)
	locale = L.BUTTONS["resetProfile"]
	local anchor = CreateButton(section, locale.label, locale.tooltip, OnClickReset)
	anchor:SetPoint("LEFT", button, "RIGHT", 10, 0)
	locale = L.BUTTONS["deleteProfile"]
	deleteButton = CreateButton(section, locale.label, locale.tooltip, OnClickDelete)
	deleteButton:SetPoint("LEFT", anchor, "RIGHT", 10, 0)

	locale = L.PROFILE_TRANSFER
	anchor = CreateButton(section, locale.export, locale.exportHelp, OnClickExport)
	anchor:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -12)
	CreateButton(section, locale.import, locale.importHelp, OnClickImport)
		:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
end



MSBTWindow.RegisterPage("general", CreateGeneral, RefreshGeneral)
MSBTWindow.RegisterPage("fontsColors", CreateFontsColors)
MSBTWindow.RegisterPage("sounds", CreateSounds, RefreshSounds)
MSBTWindow.RegisterPage("profile", CreateProfile, RefreshProfile)
