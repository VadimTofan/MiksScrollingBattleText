
local MSBTWindow = MSBTOptions.Window
local MSBTDesigns = MSBTOptions.Designs
local MSBTControls = MSBTOptions.Controls
local MSBTPopups = MSBTOptions.Popups
local MSBTSounds = MSBTOptions.Sounds
local MSBTGeneral = MSBTOptions.Tabs.general
-- The developer share of the classic tabs, where they have one.
local MSBTDeveloper = MSBTOptions.Tabs.developer
local MSBTProfiles = MikSBT.Profiles
local L = MikSBT.translations

local COLORS = MSBTWindow.COLORS
local EraseTable = MikSBT.EraseTable
local Print = MikSBT.Print



local COLUMN = 345
local ROW_HEIGHT = 26
local SOUND_LINE_HEIGHT = 30
local DEFAULT_PROFILE_NAME = "Default"
-- Switches for the game's own text over a target (they show the client until set, then the profile's
-- value, which MSBT forces): the part of the field names in the profiles module and the locale key of each.
local MECHANICS = {
	{ "own", "spellMechanicsOwn" },
	{ "others", "spellMechanicsOthers" },
}
local MECHANICS_TOP = 114
local MECHANICS_STEP = 24
-- The first section grows by the rows below its sub-options (130 high without them); the page has
-- no spare height, so the third section gives the same back and moves the language note up.
local function RowsGrowth(rows) return MECHANICS_TOP + (rows - 1) * MECHANICS_STEP + 20 + 12 - 130 end
local LANGUAGE_NOTE_TOP = 96
local LANGUAGE_NOTE_SHIFT = 30
-- With the reputation and honor switches below the effect switches, the second section closes its
-- rows up and the third gives the room back, so the language note moves up a little further.
local CHARACTER_ROWS_HEIGHT = 140
local CHARACTER_ROW_HEIGHT = 24
local CHARACTER_NOTE_SHIFT = 44
-- The reset button stands in the second section, under the slider that ends 60 below its top.
local RESET_TOP = 74
-- Switches for the game's reputation and honor text at the character, through the Blizzard switches
-- of the profiles module: the name there and the locale key of each. They follow the effect switches
-- in the Blizzard column.
local CHARACTER_TEXTS = {
	{ "reputation", "blizzardReputation" },
	{ "honor", "blizzardHonor" },
}
-- The alert thresholds are sliders under the sound switches; the list below starts under them.
local THRESHOLDS = { "lowHealthThreshold", "lowManaThreshold" }
local THRESHOLD_DEFAULT = 35
local THRESHOLD_LEFT = 32
local THRESHOLD_TOP = 112
local THRESHOLD_STEP = 50
local SLIDER_HEIGHT = 30
local SOUNDS_SECTION_HEIGHT = THRESHOLD_TOP + (#THRESHOLDS - 1) * THRESHOLD_STEP + SLIDER_HEIGHT + 12
-- The developer page lists the generated tables below the section's title, a line for each text.
local DEVELOPER_LIST_TOP = 40
local DEVELOPER_LINE_HEIGHT = 18

-- Field part and text of the sub-options under each enable switch, as on the classic General tab.
local SUB_OPTIONS = {
	{ "Outgoing", "disableOutgoing" },
	{ "Notifications", "disableNotifications" },
	{ "Incoming", "disableIncoming" },
}
-- Each entry opens what its classic General button opens: a popup that takes the shared config, or
-- the classic export of that name, which takes the anchor.
local FONTS_COLORS = {
	{ "masterFont", "ShowMasterFont" },
	{ "addFont", "ShowAddFont" },
	{ "partialEffects", MSBTPopups.ShowPartialEffects },
	{ "damageColors", MSBTPopups.ShowDamageColors },
	{ "classColors", MSBTPopups.ShowClassColors },
}



-- Popups copy what they need, so one table serves every click, as on the classic tabs.
local config = {}
local generalSwitches = {}
local mechanicsSwitches = {}
local characterSwitches = {}
local soundSwitches = {}
local thresholdSliders = {}
local fontsColorsButtons = {}
local soundNames = {}
local refreshingThresholds

local msbtCheckbox
local speedSlider
local designDropdown
local reloadDesignButton
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
	-- The numbers over targets stand for the client's setting; the profiles module marks and writes it.
	if this.numbers then
		MSBTProfiles.SetBlizzardSwitch("numbers", not isChecked)
		MSBTWindow.RefreshSwitches()
		return
	end
	if this.inverted then isChecked = not isChecked end
	MSBTProfiles.SetOption(nil, this.option, isChecked)
	if this.context then MSBTProfiles.ApplyContextOptions() end
end


local function CreateSwitch(parent, switches, localeKey, option, inverted, context, tooltip)
	local locale = L.CHECKBOXES[localeKey]
	local checkbox = MSBTControls.CreateCheckbox(parent)
	checkbox:Configure(20, locale.label, tooltip or locale.tooltip)
	checkbox:SetClickHandler(OnClickSwitch)
	checkbox.option, checkbox.inverted, checkbox.context = option, inverted, context
	MSBTWindow.SkinCheckbox(checkbox)
	switches[#switches + 1] = checkbox
	return checkbox
end


local function PopulateSwitches(switches)
	local profile = MSBTProfiles.currentProfile
	for _, checkbox in ipairs(switches) do
		if checkbox.numbers then
			checkbox:SetChecked(MSBTProfiles.GetBlizzardSwitch("numbers") == false)
		else
			local value = profile[checkbox.option]
			if checkbox.inverted then value = not value end
			checkbox:SetChecked(value)
		end
	end
end


-- Only built when the profiles module and the locale have them and the client has at least one of
-- the two settings, so a client without them keeps the page as it was.
local function HasMechanics()
	if not (MSBTProfiles.GetSpellMechanicsText and MSBTProfiles.SetSpellMechanicsText) then return false end
	for _, entry in ipairs(MECHANICS) do
		if not L.CHECKBOXES[entry[2]] then return false end
	end
	local own, others = MSBTProfiles.GetSpellMechanicsText()
	return own ~= nil or others ~= nil
end


local function OnClickMechanics(this, isChecked)
	MSBTProfiles.SetSpellMechanicsText(this.which, isChecked)
	MSBTWindow.RefreshSwitches()
end


local function CreateMechanicsSwitch(section, entry)
	local locale = L.CHECKBOXES[entry[2]]
	local checkbox = MSBTControls.CreateCheckbox(section)
	checkbox:Configure(20, locale.label, locale.tooltip)
	checkbox:SetClickHandler(OnClickMechanics)
	checkbox.which = entry[1]
	MSBTWindow.SkinCheckbox(checkbox)
	mechanicsSwitches[#mechanicsSwitches + 1] = checkbox
end


-- The client's own values, read at every show; a switch whose value is nil is hidden and the
-- others move up. Returns the number of rows shown.
local function PopulateMechanics()
	local own, others = MSBTProfiles.GetSpellMechanicsText()
	local values = { own = own, others = others }
	local row = 0
	for _, checkbox in ipairs(mechanicsSwitches) do
		local value = values[checkbox.which]
		if value == nil then
			checkbox:Hide()
		else
			checkbox:ClearAllPoints()
			checkbox:SetPoint("TOPLEFT", checkbox:GetParent(), "TOPLEFT", COLUMN, -MECHANICS_TOP - row * MECHANICS_STEP)
			checkbox:SetChecked(value)
			checkbox:Show()
			row = row + 1
		end
	end
	return row
end


-- Only built when the profiles module has the Blizzard switches and the record that puts them back,
-- the locale has both texts and the client has at least one of the two settings.
local function HasCharacterSwitches()
	local profiles = MSBTProfiles
	if not (profiles.GetBlizzardSwitch and profiles.SetBlizzardSwitch
		and profiles.TakeBlizzardSwitches and profiles.RestoreBlizzardSwitches) then return false end
	for _, entry in ipairs(CHARACTER_TEXTS) do
		if not L.CHECKBOXES[entry[2]] then return false end
	end
	return profiles.GetBlizzardSwitch(CHARACTER_TEXTS[1][1]) ~= nil
		or profiles.GetBlizzardSwitch(CHARACTER_TEXTS[2][1]) ~= nil
end


local function OnClickCharacterSwitch(this, isChecked)
	MSBTProfiles.SetBlizzardSwitch(this.switch, isChecked)
	MSBTWindow.RefreshSwitches()
end


local function CreateCharacterSwitch(section, entry)
	local locale = L.CHECKBOXES[entry[2]]
	local checkbox = MSBTControls.CreateCheckbox(section)
	checkbox:Configure(20, locale.label, locale.tooltip)
	checkbox:SetClickHandler(OnClickCharacterSwitch)
	checkbox.switch = entry[1]
	MSBTWindow.SkinCheckbox(checkbox)
	characterSwitches[#characterSwitches + 1] = checkbox
end


-- The client's own values, read at every show; a switch whose value is nil is hidden and the
-- other one moves up. The rows start below the ones the effect switches show.
local function PopulateCharacterSwitches(firstRow)
	local row = firstRow
	for _, checkbox in ipairs(characterSwitches) do
		local isShown = MSBTProfiles.GetBlizzardSwitch(checkbox.switch)
		if isShown == nil then
			checkbox:Hide()
		else
			checkbox:ClearAllPoints()
			checkbox:SetPoint("TOPLEFT", checkbox:GetParent(), "TOPLEFT", COLUMN, -MECHANICS_TOP - row * MECHANICS_STEP)
			checkbox:SetChecked(isShown)
			checkbox:Show()
			row = row + 1
		end
	end
end


local function CurrentProfileName()
	for name, profile in pairs(MSBTProfiles.savedVariables.profiles) do
		if profile == MSBTProfiles.currentProfile then return name end
	end
end



-- The reload button stays while the chosen design differs from the one the game's settings window shows.
local function RefreshReloadButton()
	if MSBTDesigns.IsSwitchPending() then reloadDesignButton:Show() else reloadDesignButton:Hide() end
end


local function RefreshGeneral()
	msbtCheckbox:SetChecked(not MSBTProfiles.IsModDisabled())
	PopulateSwitches(generalSwitches)
	local rows = #mechanicsSwitches > 0 and PopulateMechanics() or 0
	if #characterSwitches > 0 then PopulateCharacterSwitches(rows) end
	speedSlider:SetValue(MSBTProfiles.currentProfile.animationSpeed)
	designDropdown:SetSelectedID(MSBTDesigns.GetSelected())
	RefreshReloadButton()
end


local function ResetBlizzardSCT()
	MSBTGeneral.ResetBlizzardSCT()
	RefreshGeneral()
end


local function OnClickResetBlizzardSCT(this)
	PopupConfig(this:GetParent(), this).acknowledgeHandler = ResetBlizzardSCT
	MSBTPopups.ShowAcknowledge(config)
end


local function OnClickReloadDesign()
	MSBTDesigns.ReloadForDesign(MSBTWindow.IsDocked() and "settings" or "window")
end


local function CreateSubOptions(section, side, enable)
	for index, option in ipairs(SUB_OPTIONS) do
		-- Blizzard's outgoing switch stands for the client's numbers over targets where the profiles
		-- module has the functions for it, and then says so in its tooltip.
		local numbers = side == "blizzard" and option[2] == "disableOutgoing"
			and MSBTProfiles.GetBlizzardSwitch and MSBTProfiles.SetBlizzardSwitch and true or nil
		local checkbox = CreateSwitch(section, generalSwitches, option[2], side .. option[1] .. "Disabled", false, true,
			numbers and L.CHECKBOXES[option[2]].blizzardTooltip)
		checkbox.numbers = numbers
		checkbox:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 20, -6 - (index - 1) * ROW_HEIGHT)
	end
end


local function CreateGeneral(page)
	local hasMechanics, hasCharacter = HasMechanics(), HasCharacterSwitches()
	local rows = (hasMechanics and #MECHANICS or 0) + (hasCharacter and #CHARACTER_TEXTS or 0)
	local extra = rows > 0 and RowsGrowth(rows) or 0
	local isTight = rows > #MECHANICS
	local rowHeight = isTight and CHARACTER_ROW_HEIGHT or ROW_HEIGHT
	local middleHeight = isTight and CHARACTER_ROWS_HEIGHT or 150
	local section = CreateSection(page, 0, 130 + extra)
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
	if hasMechanics then
		for _, entry in ipairs(MECHANICS) do CreateMechanicsSwitch(section, entry) end
	end
	if hasCharacter then
		for _, entry in ipairs(CHARACTER_TEXTS) do CreateCharacterSwitch(section, entry) end
	end

	section = CreateSection(page, 140 + extra, middleHeight)
	local anchor
	for index, switch in ipairs({
		{ "enableNames", "hideSkills", true },
		{ "enableIcons", "skillIconsDisabled", true },
		{ "stickyCrits", "stickyCritsDisabled", true },
		{ "stackSimilarHits", "stackSimilarHits" },
		{ "shortenNumbers", "shortenNumbers" },
	}) do
		anchor = CreateSwitch(section, generalSwitches, switch[1], switch[2], switch[3])
		anchor:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12 - (index - 1) * rowHeight)
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
	-- Below the slider, where the column is free with every number of rows above. The third section
	-- is too low with all of them to hold the button's hint above the language note.
	locale = L.BUTTONS["resetBlizzardSCT"]
	local button = CreateButton(section, locale.label, locale.tooltip, OnClickResetBlizzardSCT)
	button:SetPoint("TOPLEFT", section, "TOPLEFT", COLUMN, -RESET_TOP)
	local fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, L.TABS.resetBlizzardSCT.tooltip)
	fontString:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -6)
	fontString:SetWidth(320)

	section = CreateSection(page, 150 + extra + middleHeight, 156 - extra + 150 - middleHeight)
	locale = L.DROPDOWNS["optionsDesign"]
	designDropdown = MSBTControls.CreateDropdown(section)
	designDropdown:Configure(180, locale.label, locale.tooltip)
	designDropdown:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -8)
	for _, key in ipairs(MSBTDesigns.keys) do
		designDropdown:AddItem(MSBTDesigns.designs[key].label, key)
	end
	designDropdown:SetChangeHandler(function(this, id)
		MSBTDesigns.Select(id)
		RefreshReloadButton()
	end)
	MSBTWindow.SkinDropdown(designDropdown)
	-- Beside the field, which stands at the bottom of the dropdown's frame, clear of the field's ground.
	locale = L.BUTTONS["reloadDesign"]
	reloadDesignButton = CreateButton(section, locale.label, locale.tooltip, OnClickReloadDesign)
	reloadDesignButton:SetPoint("BOTTOMLEFT", designDropdown, "BOTTOMRIGHT", 14, 0)
	reloadDesignButton:Hide()

	fontString = CreateText(section, "GameFontHighlightSmall", COLORS.text, L.LANGUAGE_INFO)
	local noteShift = isTight and CHARACTER_NOTE_SHIFT or (extra > 0 and LANGUAGE_NOTE_SHIFT or 0)
	fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -(LANGUAGE_NOTE_TOP - noteShift))
	fontString:SetPoint("RIGHT", section, "RIGHT", -12, 0)
end



-- The developer page: the client's build with the button for the debug window, and the generated
-- tables. A table whose source differs from the client stands out and names its script below.
-- The tables do not change while the game runs, so the page is written once.
local function CreateDeveloper(page)
	local locale = L.DEVELOPER
	local section = CreateSection(page, 0, 50)
	local fontString = CreateText(section, "GameFontHighlight", COLORS.text,
		locale.client:format(MSBTDeveloper.GetBuild()))
	fontString:SetPoint("LEFT", section, "LEFT", 12, 0)
	local button = CreateButton(section, locale.debugWindow, locale.debugWindowTooltip, MSBTDeveloper.ToggleDebugWindow)
	button:SetPoint("RIGHT", section, "RIGHT", -12, 0)

	local tables = MSBTDeveloper.GetTables()
	local height = DEVELOPER_LIST_TOP + 12
	for _, entry in ipairs(tables) do
		height = height + (entry.state == "fits" and 1 or 2) * DEVELOPER_LINE_HEIGHT + 6
	end
	if #tables == 0 then height = height + DEVELOPER_LINE_HEIGHT end
	section = CreateSection(page, 60, height)
	fontString = CreateText(section, "GameFontNormal", COLORS.gold, locale.tables)
	fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12)
	local top = DEVELOPER_LIST_TOP
	for _, entry in ipairs(tables) do
		local fits = entry.state == "fits"
		fontString = CreateText(section, "GameFontHighlight", fits and COLORS.text or COLORS.gold,
			entry.name .. ": " .. entry.build .. ", " .. locale[entry.state])
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top)
		top = top + DEVELOPER_LINE_HEIGHT
		if not fits then
			fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, locale.regenerate:format(entry.script))
			fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 26, -top)
			top = top + DEVELOPER_LINE_HEIGHT
		end
		top = top + 6
	end
	if #tables == 0 then
		fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, locale.noTables)
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top)
	end
end



local function EnableFontsColors()
	for _, button in ipairs(fontsColorsButtons) do button:Enable() end
end


local function OnClickFontsColors(this)
	for _, button in ipairs(fontsColorsButtons) do button:Disable() end
	local parent = this:GetParent()
	if type(this.show) == "string" then
		MSBTGeneral[this.show](parent, this, "TOPRIGHT", "BOTTOMRIGHT", EnableFontsColors)
	else
		PopupConfig(parent, this, EnableFontsColors)
		config.anchorPoint, config.relativePoint = "TOPRIGHT", "BOTTOMRIGHT"
		this.show(config)
	end
end


-- The name, hint and button word of an entry: the label and tooltip of its classic button, which
-- for adding a font are the custom font texts.
local function FontsColorsTexts(key)
	if key == "addFont" then return L.CUSTOM_FONTS.add, L.CUSTOM_FONTS.help, L.WINDOW.add end
	local locale = L.BUTTONS[key]
	return locale.label, locale.tooltip, L.WINDOW.edit
end


local function CreateFontsColors(page)
	local section = CreateSection(page, 0, #FONTS_COLORS * 70 + 10)
	for index, entry in ipairs(FONTS_COLORS) do
		local label, tooltip, word = FontsColorsTexts(entry[1])
		local top = 10 + (index - 1) * 70
		local fontString = CreateText(section, "GameFontNormal", COLORS.gold, label)
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top)
		fontString = CreateText(section, "GameFontHighlightSmall", COLORS.hint, tooltip)
		fontString:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -top - 20)
		fontString:SetWidth(520)
		local button = CreateButton(section, word, tooltip, OnClickFontsColors)
		button:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -top - 8)
		button.show = entry[2]
		fontsColorsButtons[index] = button
	end
end



-- The sliders are filled under a guard, so showing the page and putting a profile back write nothing.
local function PopulateThresholds()
	local profile = MSBTProfiles.currentProfile
	refreshingThresholds = true
	for _, slider in ipairs(thresholdSliders) do
		local value = profile[slider.option]
		if type(value) ~= "number" or not (value >= 1 and value <= 99) then value = THRESHOLD_DEFAULT end
		slider:SetValue(value)
	end
	refreshingThresholds = false
end


local function RefreshSounds()
	PopulateSwitches(soundSwitches)
	PopulateThresholds()
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


local function OnThresholdChanged(this, value)
	if refreshingThresholds then return end
	MSBTProfiles.SetOption(nil, this.option, math.floor(value + 0.5))
end


local function CreateThresholdSlider(section, option, index)
	local locale = L.SLIDERS[option]
	local slider = MSBTControls.CreateSlider(section)
	slider:Configure(300, locale.label, locale.tooltip)
	slider:SetPoint("TOPLEFT", section, "TOPLEFT", THRESHOLD_LEFT, -THRESHOLD_TOP - (index - 1) * THRESHOLD_STEP)
	slider:SetMinMaxValues(1, 99)
	slider:SetValueStep(1)
	slider.option = option
	slider:SetValueChangedHandler(OnThresholdChanged)
	MSBTWindow.SkinSlider(slider)
	thresholdSliders[index] = slider
end


local function CreateSounds(page, width, height)
	soundsPage = page
	local section = CreateSection(page, 0, SOUNDS_SECTION_HEIGHT)
	local anchor = CreateSwitch(section, soundSwitches, "enableSounds", "soundsDisabled", true)
	anchor:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -12)
	for index, switch in ipairs({
		{ "lowHealthSound", "lowHealthSoundDisabled" },
		{ "lowManaSound", "lowManaSoundDisabled" },
	}) do
		CreateSwitch(section, soundSwitches, switch[1], switch[2], true)
			:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 20, -6 - (index - 1) * ROW_HEIGHT)
	end
	for index, option in ipairs(THRESHOLDS) do CreateThresholdSlider(section, option, index) end

	local locale = L.BUTTONS["addCustomSound"]
	CreateButton(section, locale.label, locale.tooltip, function(this)
		MSBTSounds.ShowAddSound(page, this, RefreshSounds)
	end):SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -12)

	soundListbox = MSBTControls.CreateListbox(page)
	soundListbox:Configure(width, height - SOUNDS_SECTION_HEIGHT - 10, SOUND_LINE_HEIGHT)
	soundListbox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -SOUNDS_SECTION_HEIGHT - 10)
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
-- The developer page needs that share, and is offered when the share says so.
if MSBTDeveloper then
	MSBTWindow.RegisterPage("developer", CreateDeveloper, nil, nil, MSBTDeveloper.IsOffered)
end
