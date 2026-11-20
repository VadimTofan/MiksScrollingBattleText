-- Describe: the Events page of the new options window lists, previews and saves events.
local function Noop() end
local Methods = {}
local Meta = {
	__index = function(_, key)
		local method = Methods[key]
		if method then return method end
		if key:match("^[A-Z]") then return Noop end
	end,
}

local function NewRegion(kind, parent, name)
	local region = setmetatable({
		kind = kind, parent = parent, name = name, shown = true, scale = 1,
		width = 0, height = 0, level = 0, scripts = {}, regions = {}, children = {},
		enabled = true, value = 0, minValue = 0, maxValue = 0, step = 1,
	}, Meta)
	if parent then parent.children[#parent.children + 1] = region end
	if name then _G[name] = region end
	return region
end

function Methods:GetObjectType() return self.kind end
function Methods:GetName() return self.name end
function Methods:GetParent() return self.parent end
function Methods:SetParent(parent)
	local siblings = self.parent and self.parent.children or {}
	for index = #siblings, 1, -1 do
		if siblings[index] == self then table.remove(siblings, index) end
	end
	self.parent = parent
	if parent then parent.children[#parent.children + 1] = self end
end
function Methods:IsShown() return self.shown end
function Methods:Show()
	if self.shown then return end
	self.shown = true
	if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:Hide()
	if not self.shown then return end
	self.shown = false
	if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:SetShown(isShown) if isShown then self:Show() else self:Hide() end end
function Methods:SetScript(event, handler) self.scripts[event] = handler end
function Methods:SetWidth(value) self.width = value end
function Methods:SetHeight(value) self.height = value end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetScale(value) self.scale = value end
function Methods:GetFrameLevel() return self.level end
function Methods:GetFrameStrata() return "DIALOG" end
function Methods:CreateTexture()
	local region = NewRegion("Texture", self)
	self.regions[#self.regions + 1] = region
	return region
end
function Methods:CreateFontString()
	local region = NewRegion("FontString", self)
	self.regions[#self.regions + 1] = region
	return region
end
function Methods:GetRegions() return unpack(self.regions) end
function Methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Methods:SetAlpha(value) self.alpha = value end
-- Like the game, an edit box reports every text change, also one made by code.
function Methods:SetText(text)
	if self.fontString then return self.fontString:SetText(text) end
	self.text = text
	if self.kind == "Editbox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
-- Like the game, a focused field highlights all its text and Insert replaces a highlight.
function Methods:HighlightText(start, finish) self.highlighted = start == nil or start ~= finish end
function Methods:Insert(text)
	local highlighted = self.highlighted
	self.highlighted = false
	self:SetText((highlighted and "" or self.text or "") .. text)
end
-- Like a client that reports nothing: a missing file leaves the font string without a font.
function Methods:SetFont(path, size, flags)
	self.fontObject = nil
	self.font = path ~= "missing.ttf" and { path, size, flags } or nil
end
function Methods:GetFont() if self.font then return unpack(self.font) end end
function Methods:SetFontObject(fontObject) self.fontObject, self.font = fontObject, { "game font" } end
function Methods:GetText()
	if self.fontString then return self.fontString:GetText() end
	return self.text
end
function Methods:GetStringWidth() return #(self.text or "") * 6 end
function Methods:SetFontString(fontString) self.fontString = fontString end
function Methods:GetFontString() return self.fontString end
function Methods:SetTexture(path) self.texturePath = path end
function Methods:SetVertexColor(r, g, b) self.vertexColor = { r, g, b } end
function Methods:SetPoint(point, relativeTo, relativePoint, x, y)
	self.point = { point, relativeTo, relativePoint, x or 0, y or 0 }
end
for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked", "Thumb" }) do
	Methods["Set" .. state .. "Texture"] = function(self, path)
		local texture = rawget(self, state) or self:CreateTexture()
		rawset(self, state, texture)
		if path then texture.texturePath = path end
	end
	Methods["Get" .. state .. "Texture"] = function(self) return rawget(self, state) end
end
function Methods:Enable() self.enabled = true end
function Methods:Disable() self.enabled = false end
function Methods:EnableMouse(value) self.mouseEnabled = value end
function Methods:IsEnabled() return self.enabled end
function Methods:SetChecked(value) self.checked = value end
function Methods:GetChecked() return self.checked end
function Methods:SetMinMaxValues(minValue, maxValue)
	self.minValue, self.maxValue = minValue, maxValue
	self:SetValue(self.value)
end
function Methods:SetValue(value)
	value = math.max(self.minValue, math.min(self.maxValue, value))
	if value == self.value then return end
	self.value = value
	if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Methods:GetValue() return self.value end
function Methods:GetValueStep() return self.step end

-- The client's scroll frame template brings a bar that names its two buttons.
function CreateFrame(kind, name, parent, template)
	local frame = NewRegion(kind, parent, name)
	if template == "UIPanelScrollFrameTemplate" then
		local bar = NewRegion("Slider", frame)
		bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
		bar.ScrollUpButton, bar.ScrollDownButton = NewRegion("Button", bar), NewRegion("Button", bar)
		frame.ScrollBar = bar
	end
	return frame
end
UIParent = NewRegion("Frame", nil, "UIParent")
UISpecialFrames = {}
function PlaySound() end
FillLocalizedClassList = Noop
ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame")
ColorPickerFrame:Hide()
function ColorPickerFrame:SetupColorPickerAndShow(info)
	self.info = info
	self:Show()
end
SOUNDKIT = { IG_MAINMENU_OPTION = 850 }
GameTooltip = setmetatable({}, { __index = function() return Noop end })
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NONE, OKAY, CANCEL, SAVE, MANA = "None", "Okay", "Cancel", "Save", "Mana"
LE_ITEM_QUALITY_POOR, LE_ITEM_QUALITY_EPIC, ITEM_QUALITY_COLORS = 0, 4, {}
for quality = 0, 4 do _G["ITEM_QUALITY" .. quality .. "_DESC"] = "Quality " .. quality end
C_Spell = { GetSpellInfo = function(id)
	if tonumber(id) == 1459 then return { name = "Spell 1459", spellID = 1459, iconID = 1 } end
end }
for _, name in ipairs({ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
	"GameFontHighlight", "GameFontDisable", "ChatFontNormal", "GameFontNormal" }) do
	_G[name] = {}
end
function hooksecurefunc(owner, name, hook)
	local original = owner[name]
	owner[name] = function(...)
		local result = original(...)
		hook(...)
		return result
	end
end

local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end

-- A wrapper names the client; a Forever client has the ranged events.
local isForever = EVENTS_CLIENT == "forever"

MikSBT = {
	VERSION_STRING = "v12.052",
	Compatibility = { Client = { hasModernAPI = true, isForever = isForever } },
	translations = { DEFAULT_FONT_NAME = "Default" },
	Configuration = {},
	API = { Sounds = { NormalizeFile = function(_, file) return file ~= "" and file or nil end } },
	Services = {},
	Main = {},
	CopyTable = CopyTable,
	EraseTable = function(value) for key in next, value do value[key] = nil end end,
	Print = Noop,
	Media = {
		fonts = { Default = "default.ttf", Custom = "custom.ttf" },
		sounds = { Ding = "ding.ogg" },
		IterateSounds = function() return pairs(MikSBT.Media.sounds) end,
		PlaySound = function(name) MikSBT.played = name return true end,
	},
	Animations = { scrollAreas = {
		Incoming = { name = "Incoming" }, Outgoing = { name = "Outgoing" },
		Notification = { name = "Notification" }, Static = { name = "Static" },
	} },
}
dofile("MSBTOptions/Localization/localization.lua")
local L = MikSBT.translations
-- A long translation of the aura button, which is as wide as its text.
L.AURA_TRACKING_ADD = "Add this aura to the tracked list"
-- A label of its own tells the key the page reads from the one the classic window reads.
L.CHECKBOXES.inheritValue = { label = "Inherit value", tooltip = "Inherit tooltip" }
local CATEGORIES = { "INCOMING_PLAYER_EVENTS", "INCOMING_PET_EVENTS", "OUTGOING_PLAYER_EVENTS",
	"OUTGOING_PET_EVENTS", "NOTIFICATION_EVENTS" }

-- Profiles with one settings table per event, as the options read them.
local function NewProfile(message)
	local events = {}
	for _, category in ipairs(CATEGORIES) do
		for eventType in pairs(L[category]) do
			events[eventType] = {
				message = message, colorR = 1, colorG = 0, colorB = 0,
				scrollArea = category:match("^OUTGOING") and "Outgoing" or "Incoming",
				isCrit = eventType:match("_CRIT$") and true or nil,
			}
		end
	end
	for _, eventType in ipairs({ "NOTIFICATION_LOOT", "NOTIFICATION_MONEY", "NOTIFICATION_CURRENCY" }) do
		events[eventType] = { message = eventType == "NOTIFICATION_MONEY" and "+%e" or "+%a %e (%t)",
			colorR = 1, colorG = 1, colorB = 1 }
	end
	return {
		events = events, abilitySubstitutions = {}, animationSpeed = 100,
		auraTracking = {}, auraSettings = {}, resourceExclusions = { MANA = true },
		qualityExclusions = { [0] = true }, alwaysShowQuestItems = true, itemsAllowed = {}, itemExclusions = {},
		normalFontName = "Default", normalOutlineIndex = 1, normalFontSize = 18, normalFontAlpha = 100,
		critFontName = "Default", critOutlineIndex = 2, critFontSize = 26, critFontAlpha = 100,
		scrollAreas = { Outgoing = { normalFontName = "Custom", normalFontSize = 22 }, Incoming = {},
			Notification = {}, Static = {} },
	}
end
local saved = { profiles = { Default = NewProfile("(%n) -%a"), Alt = NewProfile("Alt %a") } }
local perChar = { currentProfileName = "Default" }
local calls = {}
local Profiles = { savedVariables = saved, currentProfile = saved.profiles.Default }
MikSBT.Profiles = Profiles
local function Select(name)
	perChar.currentProfileName = name
	Profiles.currentProfile = saved.profiles[name]
end
function Profiles.SetOption(section, key, value, default)
	calls[#calls + 1] = { section, key, value, default }
	local target = Profiles.currentProfile
	if section then
		for part in section:gmatch("[^.]+") do
			target[part] = target[part] or {}
			target = target[part]
		end
	end
	target[key] = value
end
Profiles.masterProfile = { itemsAllowed = {}, itemExclusions = {} }
function Profiles.SetOptionUserDisabled(isDisabled) saved.userDisabled = isDisabled or nil end
function Profiles.IsModDisabled() return saved.userDisabled end
function Profiles.SelectProfile(name) Select(name) end
for _, name in ipairs({ "ApplyContextOptions", "CopyProfile", "DeleteProfile", "ResetProfile",
	"ImportProfile", "ResetOfficialBlizzardCombatText" }) do
	Profiles[name] = Noop
end
dofile("Configuration/ProfileSnapshots.lua")
local snapshots = MikSBT.Configuration.ProfileSnapshots:New({
	savedVariables = saved, savedVariablesPerChar = perChar, selectProfile = Select,
})
function Profiles.GetProfileSnapshots() return snapshots end
snapshots:UpdateLoginSnapshot(true)

local Formatter = dofile("Services/Formatter.lua")
Formatter:Configure({
	getProfile = function() return Profiles.currentProfile end,
	formatLargeNumber = tostring,
	damageColorEntries = {}, damageTypes = { [4] = "Fire" }, powerTokens = { [0] = "MANA" },
	unknown = "Unknown", unknownSchool = "Unknown",
})

dofile("API/RestrictedValue.lua")
dofile("API/Spells.lua")
dofile("Configuration/AuraTracking.lua")
dofile("MSBTOptions/MSBTOptionsControls.lua")
dofile("MSBTOptions/MSBTOptionsDesigns.lua")
dofile("MSBTOptions/MSBTOptionsPopups.lua")
dofile("MSBTOptions/MSBTOptionsMain.lua")
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/MSBTOptionsAuras.lua")
dofile("MSBTOptions/MSBTOptionsTabs.lua")
dofile("MSBTOptions/Designs/Forever/Window.lua")
dofile("MSBTOptions/Designs/Forever/Events.lua")
local Window = MSBTOptions.Window
local Popups = MSBTOptions.Popups

-- Every event and font popup opened from here on is counted.
local opened = 0
for _, name in ipairs({ "ShowEvent", "ShowFont" }) do
	local show = Popups[name]
	Popups[name] = function(...)
		opened = opened + 1
		return show(...)
	end
end

local function Find(root, predicate)
	if predicate(root) then return root end
	for _, child in ipairs(root.children) do
		local found = Find(child, predicate)
		if found then return found end
	end
end
local function FindAll(root, predicate, found)
	found = found or {}
	if predicate(root) then found[#found + 1] = root end
	for _, child in ipairs(root.children) do FindAll(child, predicate, found) end
	return found
end
local function Click(button) button.scripts.OnClick(button) end
local function ClickCheckbox(checkbox, isChecked)
	checkbox.checkFrame:SetChecked(isChecked)
	Click(checkbox.checkFrame)
end
local function ClickEntry(key)
	Click(Find(MSBTOptionsWindowFrame, function(region) return region.key == key end))
end
local function Labelled(text)
	return Find(MSBTOptionsWindowFrame, function(region)
		return region.kind == "Button" and region:GetText() == text
	end)
end

Window.Show()
ClickEntry("incoming")
local listbox = Find(MSBTOptionsWindowFrame, function(region) return region.lineHeight == 29 end)
local panel = Find(MSBTOptionsWindowFrame, function(region)
	return region.controls and region.controls.messageEditbox
end)
local controls = panel.controls
local function InPanel(predicate) return Find(panel, predicate) end
local areaDropdown = InPanel(function(region)
	return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.outputScrollArea.label
end)
local swatch = InPanel(function(region) return region.colorChangedHandler ~= nil end)
local sticky = InPanel(function(region)
	return region.checkFrame and region.fontString:GetText() == L.CHECKBOXES.stickyEvent.label
end)
local fontControls = {}
for _, control in ipairs(FindAll(panel, function(region) return region.spec ~= nil end)) do
	fontControls[control.spec.field] = control
end
local preview = InPanel(function(region) return region.kind == "FontString" and region.height == 40 end)
local function Chips()
	return FindAll(panel, function(region)
		return region.kind == "Button" and region.shown and (region:GetText() or ""):match("^%%")
	end)
end
local function Rows()
	local rows = {}
	for index = 1, listbox:GetNumLines() do rows[index] = listbox:GetLine(index) end
	return rows
end
local function Items()
	local types = {}
	for index = 1, listbox:GetNumItems() do
		local item = listbox:GetItem(index)
		if type(item) == "table" and item.eventType then types[#types + 1] = item.eventType end
	end
	return types
end
local function ClickRow(eventType)
	for index = 1, listbox:GetNumItems() do
		if listbox:GetItem(index).eventType == eventType then listbox:SetOffset(index - 1) end
	end
	for _, row in ipairs(Rows()) do
		if row.eventType == eventType then return Click(row) end
	end
	error("no visible row for " .. eventType)
end
local function Settings(eventType) return Profiles.currentProfile.events[eventType] end
local function LastCall() return calls[#calls] end
local function Called(call, section, key, value, default)
	return call ~= nil and call[1] == section and call[2] == key and call[3] == value and call[4] == default
end

local function VisibleRow(eventType)
	for index = 1, listbox:GetNumItems() do
		if listbox:GetItem(index).eventType == eventType then listbox:SetOffset(index - 1) end
	end
	for _, row in ipairs(Rows()) do
		if row.eventType == eventType then return row end
	end
	error("no visible row for " .. eventType)
end
local expected = {}

-- Rule: each sidebar entry lists its events in the classic tab's order, with the ranged results,
-- which the classic tab lists between the melee results, behind the melee results.
do
	-- Given the order in which the classic tab adds its events; the ranged ones only on Forever.
	local category, foreverOnly
	local ranged = {}
	for line in io.lines("MSBTOptions/MSBTOptionsTabs.lua") do
		category = line:match('category = "([%u_]+)"') or category
		if line:match("^%s*if IsForever then%s*$") then
			foreverOnly = true
		elseif line:match("^%s*end%s*$") then
			foreverOnly = false
		end
		local eventType = line:match('EventsTab_AddEvent%(category, "([%u_]+)"')
		if eventType and L[category][eventType] and (isForever or not foreverOnly) then
			expected[category] = expected[category] or {}
			if eventType:find("_RANGED_") then
				ranged[#ranged + 1] = eventType
			else
				table.insert(expected[category], eventType)
			end
		end
	end
	assert(#ranged == (isForever and 3 or 0), "the classic tab adds " .. #ranged .. " ranged events")
	local outgoing = expected.OUTGOING_PLAYER_EVENTS
	local firstSpell = 1
	while not outgoing[firstSpell]:find("SPELL") do firstSpell = firstSpell + 1 end
	for offset, eventType in ipairs(ranged) do table.insert(outgoing, firstSpell + offset - 1, eventType) end
	local pet = {}
	for _, name in ipairs({ "INCOMING_PET_EVENTS", "OUTGOING_PET_EVENTS" }) do
		for _, eventType in ipairs(expected[name]) do pet[#pet + 1] = eventType end
	end

	-- When each entry is chosen, then its list matches.
	for key, types in pairs({ incoming = expected.INCOMING_PLAYER_EVENTS,
		outgoing = expected.OUTGOING_PLAYER_EVENTS, pet = pet, notifications = expected.NOTIFICATION_EVENTS }) do
		ClickEntry(key)
		local items = Items()
		assert(#items == #types, key .. " lists " .. #items .. " events instead of " .. #types)
		for index, eventType in ipairs(types) do
			assert(items[index] == eventType, key .. " row " .. index .. " is " .. tostring(items[index]))
		end
	end
end

-- Rule: selecting a row fills the panel from that event's settings and opens no popup.
do
	-- Given an event with its own settings for every field.
	local settings = Settings("OUTGOING_SPELL_DAMAGE")
	settings.message, settings.colorR, settings.colorG, settings.colorB = "%a %s", 0.2, 0.4, 0.6
	settings.soundFile, settings.alwaysSticky, settings.fontName = "Ding", true, "Custom"
	settings.outlineIndex, settings.fontSize, settings.fontAlpha = 3, 30, 70
	ClickEntry("outgoing")

	-- When its row is clicked.
	ClickRow("OUTGOING_SPELL_DAMAGE")

	-- Then every control shows its value and no popup opened.
	assert(controls.messageEditbox:GetText() == "%a %s", "the format was not filled")
	assert(areaDropdown:GetSelectedID() == "Outgoing", "the scroll area was not filled")
	assert(swatch.r == 0.2 and swatch.g == 0.4 and swatch.b == 0.6, "the colour was not filled")
	assert(controls.soundDropdown:GetSelectedID() == "Ding", "the sound was not filled")
	assert(sticky:GetChecked() and sticky.shown, "sticky was not filled")
	assert(fontControls.fontName:GetSelectedID() == "Custom" and not fontControls.fontName.inheritCheckbox:GetChecked(),
		"the font was not filled")
	assert(fontControls.outlineIndex:GetSelectedID() == 3, "the outline was not filled")
	assert(fontControls.fontSize:GetValue() == 30 and fontControls.fontAlpha:GetValue() == 70,
		"size or opacity was not filled")
	assert(opened == 0, "selecting a row opened a popup")
end

-- Rule: an inherited font field shows the value the classic font popup would inherit.
do
	-- Given an event without font settings in the Outgoing area, which sets its own font and size.
	ClickRow("OUTGOING_DAMAGE")

	-- Then the controls show the area's font and size and the profile's outline and opacity.
	for field, value in pairs({ fontName = "Custom", fontSize = 22, outlineIndex = 1, fontAlpha = 100 }) do
		local control = fontControls[field]
		assert(control.inheritCheckbox:GetChecked(), field .. " is not inherited")
		assert(control:Get() == value, field .. " shows " .. tostring(control:Get()) .. " instead of " .. value)
	end
	assert(not fontControls.fontName.buttonFrame.enabled, "an inherited font can be changed")
	assert(preview.font[1] == "custom.ttf" and preview.font[2] == 22 and preview.font[3] == "",
		"the preview does not use the inherited font")
	assert(preview.fontObject == nil, "a font that loaded was replaced by the game font")

	-- When the event's font file is missing, then the preview falls back to the game font.
	MikSBT.Media.fonts.Broken = "missing.ttf"
	Settings("OUTGOING_DAMAGE").fontName = "Broken"
	ClickRow("OUTGOING_DAMAGE")
	assert(preview.fontObject == GameFontNormal, "a font that did not load left the preview without a font")
	Settings("OUTGOING_DAMAGE").fontName, MikSBT.Media.fonts.Broken = nil, nil
end

-- Rule: each control saves the same field with the same default as the classic popups.
do
	-- Given a selected event.
	local eventType = "OUTGOING_SPELL_DAMAGE"
	local section = "events." .. eventType
	ClickRow(eventType)

	-- When each control is used, then the classic save call is made.
	controls.messageEditbox:SetText("%a!")
	assert(Called(LastCall(), section, "message", "%a!"), "the format saves differently")
	areaDropdown:changeHandler("Static")
	assert(Called(LastCall(), section, "scrollArea", "Static", "Notification"), "the scroll area saves differently")
	controls.soundDropdown:changeHandler("")
	assert(Called(LastCall(), section, "soundFile", ""), "the sound saves differently")
	ClickCheckbox(sticky, false)
	assert(Called(LastCall(), section, "alwaysSticky", false), "sticky saves differently")
	swatch:SetColor(0.5, 0.25, 1)
	calls = {}
	swatch:colorChangedHandler()
	assert(Called(calls[1], section, "colorR", 0.5, 1) and Called(calls[2], section, "colorG", 0.25, 1)
		and Called(calls[3], section, "colorB", 1, 1), "the colour saves differently")
	fontControls.fontName:changeHandler("Default")
	assert(Called(LastCall(), section, "fontName", "Default"), "the font saves differently")
	fontControls.outlineIndex:changeHandler(2)
	assert(Called(LastCall(), section, "outlineIndex", 2), "the outline saves differently")
	fontControls.fontSize:SetValue(40)
	assert(Called(LastCall(), section, "fontSize", 40), "the size saves differently")
	fontControls.fontAlpha:SetValue(50)
	assert(Called(LastCall(), section, "fontAlpha", 50), "the opacity saves differently")

	-- When a field is set to inherit, then nil is saved and the inherited value is shown.
	ClickCheckbox(fontControls.fontSize.inheritCheckbox, true)
	assert(Called(LastCall(), section, "fontSize", nil), "inherit does not save nil")
	assert(fontControls.fontSize:GetValue() == 18, "inherit does not show the inherited size")

	-- When the inherit box is cleared again, then the shown value becomes the event's own.
	ClickCheckbox(fontControls.fontSize.inheritCheckbox, false)
	assert(Called(LastCall(), section, "fontSize", 18), "clearing inherit does not keep the shown size")

	-- When a custom sound file is entered, then it is saved as the sound.
	Click(controls.customSoundButton)
	local input = Find(UIParent, function(region) return region.inputEditbox ~= nil end)
	input.inputEditbox:SetText("my.ogg")
	Click(input.okayButton)
	assert(Called(LastCall(), section, "soundFile", "my.ogg"), "the custom sound was not saved")
	assert(controls.soundDropdown.buttonFrame.enabled and controls.playSoundButton.enabled,
		"the sound controls stayed disabled after the input")

	-- When the row's checkbox is cleared, then the event is disabled as the classic row does.
	for _, row in ipairs(Rows()) do
		if row.eventType == eventType then ClickCheckbox(row.enableCheckbox, false) end
	end
	assert(Called(LastCall(), section, "disabled", true), "enabling saves differently")
	assert(opened == 0, "a control opened an event or font popup")
	Settings(eventType).disabled = nil
end

-- Rule: "Always sticky" is offered for normal events only.
do
	ClickRow("OUTGOING_DAMAGE_CRIT")
	assert(not sticky.shown, "sticky is shown for a crit event")
	assert(fontControls.fontSize.labelText == L.SLIDERS.critFontSize.label, "a crit event shows normal labels")
	assert(fontControls.fontSize:GetValue() == 26, "a crit event does not inherit the crit size")
	ClickRow("OUTGOING_DAMAGE")
	assert(sticky.shown, "sticky is hidden for a normal event")
end

-- Rule: a code chip inserts its code into the format.
do
	-- Given an event whose codes include the long skill name.
	ClickRow("OUTGOING_SPELL_DAMAGE")
	controls.messageEditbox:SetText("%a")
	local chips = Chips()
	assert(#chips == 5 and chips[4]:GetText() == "%sl", "the event's codes are not offered as chips")

	-- When the chip is clicked.
	Click(chips[4])

	-- Then the code is in the format and saved.
	assert(controls.messageEditbox:GetText() == "%a%sl", "the chip did not insert its code")
	assert(Settings("OUTGOING_SPELL_DAMAGE").message == "%a%sl", "the inserted code was not saved")

	-- When the field was clicked, which highlights its text, and a chip is clicked.
	local editboxFrame = controls.messageEditbox.editboxFrame
	editboxFrame.scripts.OnEditFocusGained(editboxFrame)
	Click(chips[1])

	-- Then the code is added, not put in place of the format.
	assert(controls.messageEditbox:GetText() == "%a%sl%a", "the chip replaced the highlighted format")
end

-- Rule: the colour picker and the custom sound input do not follow a new selection.
do
	-- Given the colour picker opened for one event.
	ClickRow("OUTGOING_DAMAGE")
	local before = Settings("OUTGOING_MISS").colorG
	Click(swatch)
	assert(ColorPickerFrame.associatedColorSwatch == swatch, "the picker did not open for the swatch")

	-- When another row is clicked and the picker is cancelled afterwards.
	ClickRow("OUTGOING_MISS")
	calls = {}
	ColorPickerFrame.info.cancelFunc(ColorPickerFrame.info.previousValues)

	-- Then the picker was closed and nothing was written to the new event.
	assert(not ColorPickerFrame.shown and ColorPickerFrame.associatedColorSwatch == nil,
		"the picker stayed bound to the panel")
	assert(#calls == 0 and Settings("OUTGOING_MISS").colorG == before, "the old colour went to the new event")

	-- Given the custom sound input opened.
	Click(controls.customSoundButton)
	local input = Find(UIParent, function(region) return region.inputEditbox ~= nil end)
	assert(input.shown, "the custom sound input did not open")

	-- When another row is clicked, then the input is closed and the sound controls work again.
	ClickRow("OUTGOING_DAMAGE")
	assert(not input.shown, "the custom sound input stayed open for the next event")
	assert(controls.soundDropdown.buttonFrame.enabled, "the sound controls stayed disabled")
end

-- Rule: an event whose scroll area was deleted shows that key, not another area.
do
	-- Given an event that names a scroll area that no longer exists.
	ClickRow("OUTGOING_DAMAGE")
	Settings("OUTGOING_MISS").scrollArea = "Deleted"

	-- When it is selected.
	ClickRow("OUTGOING_MISS")

	-- Then the scroll area list shows the missing key.
	assert(areaDropdown:GetSelectedID() == "Deleted", "the panel shows another scroll area")
	Settings("OUTGOING_MISS").scrollArea = "Outgoing"
end

-- Rule: the previews show the rendered format in the event's colour, not the codes.
do
	ClickRow("OUTGOING_DAMAGE")
	local row = VisibleRow("OUTGOING_DAMAGE")
	assert(row.previewFontString:GetText() == "(Someone) -1234", "the row preview is " .. tostring(row.previewFontString:GetText()))
	assert(preview:GetText() == "(Someone) -1234", "the panel preview is " .. tostring(preview:GetText()))
	assert(row.previewFontString.textColor[2] == 0 and preview.textColor[1] == 1,
		"a preview is not in the event's colour")
end

-- Rule: the previews fill in %t as the damage type where the event's codes name it so, and as a
-- count where the codes give %t another meaning.
do
	-- Given a spell hit taken and one dealt, whose codes name the damage type, and one more
	-- notification at the end of the list whose %t is a total, as another change may add it.
	local events = MSBTOptions.Tabs.events
	local getEvents = events.GetEvents
	local profileEvents = Profiles.currentProfile.events
	profileEvents.NOTIFICATION_GAIN_WITH_TOTAL = { message = "+%a (%t)" }
	events.GetEvents = function(category)
		local list = getEvents(category)
		if category ~= "NOTIFICATION_EVENTS" then return list end
		local extended = {}
		for index, event in ipairs(list) do extended[index] = event end
		extended[#extended + 1] = { eventType = "NOTIFICATION_GAIN_WITH_TOTAL", label = "Gain with total",
			codes = L.EVENT_CODES.RESOURCE_AMOUNT .. L.EVENT_CODES.TOTAL_ITEMS }
		return extended
	end
	local dealtMessage = Settings("OUTGOING_SPELL_DAMAGE").message
	local takenMessage = Settings("INCOMING_SPELL_DAMAGE").message
	Settings("OUTGOING_SPELL_DAMAGE").message = "%a %t"
	Settings("INCOMING_SPELL_DAMAGE").message = "%a %t"

	-- When all three are shown, the notification in the panel as well.
	ClickEntry("incoming")
	local taken = VisibleRow("INCOMING_SPELL_DAMAGE").previewFontString:GetText()
	ClickEntry("outgoing")
	local dealt = VisibleRow("OUTGOING_SPELL_DAMAGE").previewFontString:GetText()
	ClickEntry("notifications")
	ClickRow("NOTIFICATION_GAIN_WITH_TOTAL")
	local gain = VisibleRow("NOTIFICATION_GAIN_WITH_TOTAL").previewFontString:GetText()

	-- Then the hits name their damage type and the notification shows a count, its format left as saved.
	assert(profileEvents.NOTIFICATION_GAIN_WITH_TOTAL.message == "+%a (%t)", "a preview changed the saved format")
	assert(taken == "1234 Fire" and dealt == "1234 Fire",
		"the damage type shows as " .. tostring(taken) .. " and " .. tostring(dealt))
	assert(gain == "+1234 (5678)", "the row preview of a total is " .. tostring(gain))
	assert(preview:GetText() == "+1234 (5678)", "the panel preview of a total is " .. tostring(preview:GetText()))

	events.GetEvents = getEvents
	profileEvents.NOTIFICATION_GAIN_WITH_TOTAL = nil
	Settings("OUTGOING_SPELL_DAMAGE").message = dealtMessage
	Settings("INCOMING_SPELL_DAMAGE").message = takenMessage
	ClickEntry("outgoing")
	ClickRow("OUTGOING_DAMAGE")
end

-- Rule: "All on" and "All off" set every event of the page and nothing else.
do
	ClickEntry("pet")
	Click(Labelled(L.WINDOW.allOff))
	for eventType, settings in pairs(Profiles.currentProfile.events) do
		assert((settings.disabled == true) == (eventType:match("^PET_") ~= nil),
			"All off changed " .. eventType .. " wrongly")
	end
	assert(not VisibleRow("PET_INCOMING_DAMAGE").enableCheckbox:GetChecked(), "the rows were not refreshed")
	Click(Labelled(L.WINDOW.allOn))
	assert(Settings("PET_INCOMING_DAMAGE").disabled == false and Settings("PET_OUTGOING_HEAL").disabled == false,
		"All on did not enable the pet events")
	assert(Settings("INCOMING_DAMAGE").disabled == nil, "All on changed another page")
end

-- Rule: a refresh shows the current values and keeps the selection on the same page.
do
	-- Given a selected event whose format changed.
	ClickEntry("outgoing")
	local original = Settings("OUTGOING_HEAL").message
	ClickRow("OUTGOING_HEAL")
	controls.messageEditbox:SetText("changed")

	-- When everything is undone on the Changes page and the page is shown again.
	ClickEntry("changes")
	Click(Labelled(L.WINDOW.undoAll))
	ClickEntry("outgoing")

	-- Then the same event shows its restored format.
	assert(listbox:GetSelectedItem().eventType == "OUTGOING_HEAL", "the selection was lost")
	assert(controls.messageEditbox:GetText() == original, "the panel shows the undone format")

	-- When the profile changes in the header.
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	dropdown:changeHandler("Alt")

	-- Then the panel and rows show the new profile's values.
	assert(controls.messageEditbox:GetText() == "Alt %a", "the panel shows the old profile")
	assert(VisibleRow("OUTGOING_HEAL").previewFontString:GetText() == "Alt 1234", "the rows show the old profile")

	-- When another page is chosen, then its first event is selected.
	ClickEntry("notifications")
	assert(listbox:GetSelectedItem().eventType == Items()[1], "a new page did not select its first event")
	Profiles.SelectProfile("Default")
end

-- Rule: search lists every matching event of all categories, and nothing for an unknown text.
do
	-- Given the classic order and the loot events, and a text in another case than the names.
	local matches = {}
	for _, category in ipairs({ "INCOMING_PLAYER_EVENTS", "INCOMING_PET_EVENTS", "OUTGOING_PLAYER_EVENTS",
		"OUTGOING_PET_EVENTS", "NOTIFICATION_EVENTS" }) do
		for _, eventType in ipairs(expected[category]) do
			if L[category][eventType].label:lower():find("gain", 1, true) then matches[#matches + 1] = eventType end
		end
	end
	matches[#matches + 1] = "NOTIFICATION_MONEY"
	matches[#matches + 1] = "NOTIFICATION_CURRENCY"
	local search = Find(MSBTOptionsWindowFrame, function(region)
		return region.editboxFrame and region.labelFontString:GetText() == L.WINDOW.search
	end)

	local function Headers()
		local texts = {}
		for index = 1, listbox:GetNumItems() do
			local item = listbox:GetItem(index)
			if type(item) == "table" and item.header then texts[#texts + 1] = item.header end
		end
		return table.concat(texts, ",")
	end
	local auraPanel = Find(MSBTOptionsWindowFrame, function(region) return region.input and region.add end)
	local lootPanel = Find(MSBTOptionsWindowFrame, function(region) return region.quality == 0 end):GetParent()

	-- When the text is searched from Loot Alerts.
	ClickEntry("lootAlerts")
	search:SetText("GAIN")

	-- Then exactly the matching events are listed under their categories, the first is selected,
	-- and the panels of the entries are hidden.
	local items = Items()
	assert(#items == #matches, "search lists " .. #items .. " events instead of " .. #matches)
	for index, eventType in ipairs(matches) do
		assert(items[index] == eventType, "search row " .. index .. " is " .. tostring(items[index]))
	end
	assert(Headers() == L.EVENT_CATEGORIES[5] .. "," .. L.TABS.lootAlerts.label, "search headers are " .. Headers())
	assert(panel.shown and listbox:GetSelectedItem().eventType == matches[1], "the first match is not selected")
	assert(not lootPanel.shown and not auraPanel.shown, "the search shows the panel of an entry")

	-- When a name shared by four categories is searched, then each hit follows its category.
	search:SetText("melee hits")
	assert(Headers() == table.concat(L.EVENT_CATEGORIES, ",", 1, 4), "shared names are not told apart: " .. Headers())
	assert(#Items() == 4, "melee hits are not listed four times")

	-- When a text matches nothing while the colour picker and the sound input are open.
	Click(swatch)
	Click(controls.customSoundButton)
	local input = Find(UIParent, function(region) return region.inputEditbox ~= nil end)
	search:SetText("zzz")

	-- Then the table is empty, no event is shown and both editors are closed.
	assert(listbox:GetNumItems() == 0 and not panel.shown, "a text without matches lists rows")
	assert(not ColorPickerFrame.shown and ColorPickerFrame.associatedColorSwatch == nil and not input.shown,
		"an editor of the last event stayed open")

	-- When the text is cleared, then Loot Alerts returns with its panel.
	search:SetText("")
	assert(lootPanel.shown and Items()[1] == "NOTIFICATION_LOOT", "clearing the search did not return to Loot Alerts")
end

-- Rule: each group has one header, which is neither selectable nor toggled.
do
	-- Given the Outgoing and Pet pages.
	local function Headers()
		local texts = {}
		for index = 1, listbox:GetNumItems() do
			local item = listbox:GetItem(index)
			if type(item) == "table" and item.header then
				texts[#texts + 1] = item.header
				local nextItem = listbox:GetItem(index + 1)
				assert(nextItem and nextItem.eventType, "a header is not followed by an event")
			end
		end
		return table.concat(texts, ",")
	end
	ClickEntry("outgoing")

	-- Then the headers follow the groups of the classic order, the ranged group after the melee one.
	assert(Headers() == (isForever and "Melee,Ranged,Spells,Healing,Other" or "Melee,Spells,Healing,Other"),
		"Outgoing headers are " .. Headers())
	assert(listbox:GetItem(1).header and listbox:GetSelectedItem().eventType == "OUTGOING_DAMAGE",
		"the page does not start with a header and select the first event")
	listbox:SetOffset(0)
	local headerRow = Rows()[1]
	assert(headerRow.mouseEnabled == false and not headerRow.enableCheckbox.shown, "a header row can be clicked")
	ClickEntry("pet")
	assert(Headers() == "Incoming \194\183 Melee,Incoming \194\183 Spells,Incoming \194\183 Healing,"
		.. "Outgoing \194\183 Melee,Outgoing \194\183 Spells,Outgoing \194\183 Healing,Outgoing \194\183 Other",
		"Pet headers are " .. Headers())

	-- When all are turned off, then one write per event is made and none for a header.
	calls = {}
	Click(Labelled(L.WINDOW.allOff))
	assert(#calls == #Items(), #calls .. " writes for " .. #Items() .. " events")
	Click(Labelled(L.WINDOW.allOn))
end

-- Rule: an event type the group rules do not know stands with the rest, not under melee.
do
	-- Given one more outgoing event at the end of the list, as another change may add it.
	local events = MSBTOptions.Tabs.events
	local getEvents = events.GetEvents
	local profileEvents = Profiles.currentProfile.events
	local previous = profileEvents.OUTGOING_EFFECT
	profileEvents.OUTGOING_EFFECT = { message = "<%sl>" }
	events.GetEvents = function(category)
		local list = getEvents(category)
		if category ~= "OUTGOING_PLAYER_EVENTS" then return list end
		local extended = {}
		for index, event in ipairs(list) do extended[index] = event end
		extended[#extended + 1] = { eventType = "OUTGOING_EFFECT", label = "Effects on Target", codes = "" }
		return extended
	end

	-- When the Outgoing page is built again.
	ClickEntry("incoming")
	ClickEntry("outgoing")

	-- Then it joins the last group instead of opening a melee group.
	local last
	for index = 1, listbox:GetNumItems() do
		local item = listbox:GetItem(index)
		if type(item) == "table" and item.header then last = item.header end
	end
	assert(last == "Other", "an unknown event type stands under " .. tostring(last))

	events.GetEvents = getEvents
	-- Where another change has added this event for real, its settings stay.
	profileEvents.OUTGOING_EFFECT = previous
	ClickEntry("incoming")
	ClickEntry("outgoing")
end

-- Rule: the sound column shows a gold symbol for an event with a sound and nothing otherwise.
do
	Settings("OUTGOING_DAMAGE").soundFile = "Ding"
	Settings("OUTGOING_DODGE").soundFile = "Interface\\AddOns\\Sounds\\bell.ogg"
	ClickEntry("outgoing")
	local row = VisibleRow("OUTGOING_DAMAGE")
	local icon = row.soundIcon
	assert(icon.shown and VisibleRow("OUTGOING_DODGE").soundIcon.shown, "the sound column misses the symbol")
	assert(not VisibleRow("OUTGOING_MISS").soundIcon.shown, "an event without sound shows the symbol")
	assert(icon.texturePath:match("Designs.Forever.Artwork.FlatSound$") and icon.width == 16 and icon.height == 16,
		"the symbol is not the sound symbol at its size")
	local gold = MSBTOptions.Window.COLORS.gold
	assert(icon.vertexColor[1] == gold[1] and icon.vertexColor[2] == gold[2] and icon.vertexColor[3] == gold[3],
		"the symbol is not gold")

	-- A header row has none, and a row keeps the one symbol it was created with.
	listbox:SetOffset(0)
	assert(not Rows()[1].soundIcon.shown, "a header row shows the symbol")
	local parts = #row.regions
	for _ = 1, 3 do ClickEntry("incoming"); ClickEntry("outgoing") end
	assert(row.soundIcon == icon and #row.regions == parts, "a refresh made new parts for a row")
	Settings("OUTGOING_DAMAGE").soundFile, Settings("OUTGOING_DODGE").soundFile = nil, nil
end

-- Rule: the area column has the width the sound symbol leaves, the headers stand over the columns, and
-- the sound header ends with the symbol column, left of the list's scroll bar.
do
	local row = VisibleRow("OUTGOING_DAMAGE")
	local function Header(text)
		return Find(MSBTOptionsWindowFrame, function(region)
			return region.kind == "FontString" and region.text == text and region.point
		end)
	end
	assert(row.areaFontString.width == 104, "the area column is " .. row.areaFontString.width .. " wide")
	assert(Header(L.WINDOW.columnArea).point[4] == row.areaFontString.point[4], "the area header is out of line")
	local soundHeader = Header(L.WINDOW.columnSound)
	assert(soundHeader.point[1] == "TOPRIGHT" and soundHeader.point[4] == row.soundIcon.point[4] + row.soundIcon.width,
		"the sound header does not end with the symbol column")
	local scrollBarWidth = 17
	local tableWidth = Find(MSBTOptionsWindowFrame, function(region) return region.input and region.add end):GetWidth()
	assert(soundHeader.point[4] == 380 and soundHeader.point[4] <= tableWidth - scrollBarWidth,
		"the sound header runs under the scroll bar")
	assert(row.areaFontString.point[4] + row.areaFontString.width < row.soundIcon.point[4],
		"the area column runs into the sound column")
end

-- Rule: an event row's tooltip names the event in full and the sound when one is set; a header has none.
do
	Settings("OUTGOING_DAMAGE").soundFile = "Ding"
	Settings("OUTGOING_DODGE").soundFile = "Interface\\AddOns\\Sounds\\bell.ogg"
	ClickEntry("outgoing")
	local function Begins(text, start) return text:sub(1, #start) == start end
	local damage = VisibleRow("OUTGOING_DAMAGE").tooltip
	assert(Begins(damage, L.OUTGOING_PLAYER_EVENTS.OUTGOING_DAMAGE.label) and damage:find("Ding", 1, true),
		"the tooltip misses the name or the sound")
	local dodge = VisibleRow("OUTGOING_DODGE").tooltip
	assert(dodge:find("bell.ogg", 1, true) and not dodge:find("Sounds", 1, true), "a sound path is not shortened")
	local miss = VisibleRow("OUTGOING_MISS").tooltip
	assert(Begins(miss, L.OUTGOING_PLAYER_EVENTS.OUTGOING_MISS.label) and not miss:find("ogg", 1, true)
		and not miss:find("Ding", 1, true), "an event without sound names one")
	listbox:SetOffset(0)
	assert(Rows()[1].tooltip == nil, "a header row has a tooltip")
	Settings("OUTGOING_DAMAGE").soundFile, Settings("OUTGOING_DODGE").soundFile = nil, nil
end

-- Rule: inside a group whose event names share a prefix up to the first ": ", the rows leave it out.
do
	-- Given outgoing names with a prefix in every group but healing, and one odd name among the spells.
	local events = MSBTOptions.Tabs.events
	local getEvents = events.GetEvents
	local melee = { DAMAGE = true, DAMAGE_CRIT = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true,
		DEFLECT = true, ABSORB = true, IMMUNE = true, EVADE = true }
	local function Tag(eventType)
		if eventType:find("HEAL") or eventType:find("HOT") then return end
		if eventType:find("SPELL") then return eventType == "OUTGOING_SPELL_DAMAGE" and "Odd" or "Spell" end
		return melee[eventType:gsub("^OUTGOING_", "")] and "Melee" or "Misc"
	end
	events.GetEvents = function(category)
		local list = getEvents(category)
		if category ~= "OUTGOING_PLAYER_EVENTS" then return list end
		local renamed = {}
		for index, event in ipairs(list) do
			local tag = Tag(event.eventType)
			renamed[index] = { eventType = event.eventType, codes = event.codes, tooltip = event.tooltip,
				label = tag and tag .. ": " .. event.label or event.label }
		end
		return renamed
	end
	local function Shown(eventType) return VisibleRow(eventType).nameFontString:GetText() end
	local function Label(eventType) return L.OUTGOING_PLAYER_EVENTS[eventType].label end

	-- When the Outgoing page is built.
	ClickEntry("incoming")
	ClickEntry("outgoing")

	-- Then a group with one prefix shows the names without it, and the row's tooltip keeps the full name.
	assert(Shown("OUTGOING_DAMAGE") == Label("OUTGOING_DAMAGE"), "the melee prefix stayed: " .. Shown("OUTGOING_DAMAGE"))
	assert(VisibleRow("OUTGOING_DAMAGE").tooltip:find("Melee: " .. Label("OUTGOING_DAMAGE"), 1, true),
		"the tooltip lost the prefix")
	-- And a group with mixed prefixes or none stays as it is.
	assert(Shown("OUTGOING_SPELL_MISS") == "Spell: " .. Label("OUTGOING_SPELL_MISS"), "a mixed group was shortened")
	assert(Shown("OUTGOING_HEAL") == Label("OUTGOING_HEAL"), "a name without a prefix changed")
	-- And the ranged group, whose rows stand between the melee ones in the list, has its own prefix.
	if isForever then
		assert(Shown("OUTGOING_RANGED_DAMAGE") == Label("OUTGOING_RANGED_DAMAGE"),
			"the ranged prefix stayed: " .. Shown("OUTGOING_RANGED_DAMAGE"))
		assert(Shown("OUTGOING_DODGE") == Label("OUTGOING_DODGE"), "the melee rows after the ranged ones kept the prefix")
	end

	-- And the detail panel keeps the full name.
	ClickRow("OUTGOING_DAMAGE")
	local title = InPanel(function(region) return region.kind == "FontString" and region.width == 246
		and region.height == 0 end)
	assert(title:GetText() == "Melee: " .. Label("OUTGOING_DAMAGE"), "the panel title lost the prefix")

	-- And a page without group headers shows the full name.
	local search = Find(MSBTOptionsWindowFrame, function(region)
		return region.editboxFrame and region.labelFontString:GetText() == L.WINDOW.search
	end)
	search:SetText("melee: ")
	assert(Shown("OUTGOING_DAMAGE") == "Melee: " .. Label("OUTGOING_DAMAGE"), "the search results are shortened")
	search:SetText("")

	events.GetEvents = getEvents
	ClickEntry("incoming")
	ClickEntry("outgoing")
end

-- Rule: the icon buttons carry the flat symbols, and Play plays the chosen sound.
do
	ClickEntry("outgoing")
	assert(controls.customSoundButton:GetNormalTexture().texturePath:match("FlatSettings$"), "the custom sound button has no symbol")
	assert(Rows()[1].removeButton:GetNormalTexture().texturePath:match("FlatDelete$"), "the remove button has no symbol")
	local play = controls.playSoundButton
	assert(play:GetNormalTexture().texturePath:match("FlatPlay$") and play.tooltip == L.BUTTONS.playSound.label .. "\n" .. L.BUTTONS.playSound.tooltip
		and (play:GetText() or "") == "", "Play is not an icon button with its label and explanation as tooltip")
	assert(controls.soundDropdown.width == 160, "the sound dropdown did not take the freed width")
	MikSBT.played = nil
	controls.soundDropdown:SetSelectedID("Ding")
	Click(play)
	assert(MikSBT.played == "Ding", "Play did not play the chosen sound")
	MikSBT.played = nil
	controls.soundDropdown:SetSelectedID("")
	Click(play)
	assert(MikSBT.played == nil, "Play played with no sound chosen")
end

-- Rule: the inherit boxes of the event panel use the label of their own key.
do
	for field, control in pairs(fontControls) do
		assert(control.inheritCheckbox.fontString:GetText() == L.CHECKBOXES.inheritValue.label,
			field .. " has another inherit label")
	end
end

-- Rule: Loot Alerts lists the loot events and saves its options as the classic tab does.
do
	-- Given the Loot Alerts page.
	local lists = {}
	Popups.ShowItemList = function(config) lists[#lists + 1] = config end
	ClickEntry("lootAlerts")
	local items = Items()
	assert(table.concat(items, ",") == "NOTIFICATION_LOOT,NOTIFICATION_MONEY,NOTIFICATION_CURRENCY",
		"Loot Alerts lists " .. table.concat(items, ","))
	local function LootControl(predicate) return Find(MSBTOptionsWindowFrame, predicate) end
	local poor = LootControl(function(region) return region.quality == 0 and region.checkFrame end)
	local quest = LootControl(function(region)
		return region.checkFrame and region.fontString:GetText() == L.CHECKBOXES.alwaysShowQuestItems.label
	end)
	assert(not poor:GetChecked() and quest:GetChecked(), "the loot options do not show the profile")
	assert(VisibleRow("NOTIFICATION_LOOT").previewFontString:GetText() == "+2 Potion (5)"
		and VisibleRow("NOTIFICATION_MONEY").previewFontString:GetText() == "+1 Gold 23 Silver",
		"the loot previews are not filled in as the loot notifications do")
	Settings("NOTIFICATION_MONEY").message = "+%e %a"
	listbox:Refresh()
	assert(VisibleRow("NOTIFICATION_MONEY").previewFontString:GetText() == "+1 Gold 23 Silver %a",
		"the money preview fills in codes the money notification leaves")
	Settings("NOTIFICATION_MONEY").message = "+%e"

	-- When each loot control is used, then the classic call is made.
	ClickCheckbox(poor, true)
	assert(Called(LastCall(), "qualityExclusions", 0, false), "a quality saves differently")
	ClickCheckbox(quest, false)
	assert(Called(LastCall(), nil, "alwaysShowQuestItems", false), "quest items save differently")
	ClickRow("NOTIFICATION_MONEY")
	assert(Chips()[1]:GetText() == "%e", "the money event does not offer the classic codes")
	areaDropdown:changeHandler("Static")
	assert(Called(LastCall(), "events.NOTIFICATION_MONEY", "scrollArea", "Static", "Notification"),
		"a loot scroll area saves differently")
	swatch:SetColor(0.5, 0.5, 0.5)
	swatch:colorChangedHandler()
	assert(Called(LastCall(), "events.NOTIFICATION_MONEY", "colorB", 0.5, 1), "a loot colour saves differently")
	ClickCheckbox(VisibleRow("NOTIFICATION_LOOT").enableCheckbox, false)
	assert(Called(LastCall(), "events.NOTIFICATION_LOOT", "disabled", true), "a loot event enables differently")
	Click(Labelled(L.BUTTONS.itemExclusions.label))
	local list = lists[#lists]
	assert(list and list.saveArg1 == "itemExclusions", "the item list did not open")
	list.items.Potion = true
	list.saveHandler(list.saveArg1)
	assert(Called(LastCall(), "itemExclusions", "Potion", true), "the item list saves differently")
	assert(opened == 0, "Loot Alerts opened an event or font popup")
end

-- Rule: tracked auras are added, edited and removed on the Notifications page through the classic paths.
do
	-- Given the Notifications page.
	ClickEntry("notifications")
	local auras = Find(MSBTOptionsWindowFrame, function(region) return region.input and region.add end)
	assert(auras.shown, "Notifications has no aura panel")

	-- Then the input and the long button, the input's 5 inset and the 10 between them included,
	-- end at the table's right edge and do not cover the detail panel.
	assert(auras.add:GetWidth() > 200, "the button is not wide")
	assert(5 + auras.input:GetWidth() + 10 + auras.add:GetWidth() == auras:GetWidth(),
		"the aura row is not as wide as the table")

	-- When an aura is added by ID.
	auras.input:SetText("1459")
	Click(auras.add)

	-- Then it is listed first, selected, and stored as the classic panel stores it.
	assert(Profiles.currentProfile.auraTracking["1459"] == false, "the aura rule was not saved")
	assert(listbox:GetItem(1) == "1459" and listbox:GetSelectedItem() == "1459", "the new aura is not selected")
	assert(VisibleRow("1459").nameFontString:GetText() == "Spell 1459 (1459)", "the aura row has no name")
	assert(VisibleRow("1459").tooltip == nil, "an aura row keeps the tooltip of an event")

	-- When its format, colour and size change and its row is ticked.
	controls.messageEditbox:SetText("Got %sl")
	swatch:SetColor(0.25, 1, 1)
	swatch:colorChangedHandler()
	fontControls.fontSize:SetValue(30)
	ClickCheckbox(VisibleRow("1459").enableCheckbox, true)

	-- Then the overrides belong to the aura and the buff event is unchanged.
	local overrides = Profiles.currentProfile.auraSettings["1459"]
	assert(overrides.message == "Got %sl" and overrides.colorR == 0.25 and overrides.fontSize == 30,
		"the aura settings were not saved per aura")
	assert(Settings("NOTIFICATION_BUFF").message ~= "Got %sl", "the buff event was changed")
	assert(Profiles.currentProfile.auraTracking["1459"] == true, "ticking the aura did not save")

	-- When an aura added by name is edited.
	auras.input:SetText("Mystery Aura")
	Click(auras.add)
	controls.messageEditbox:SetText("Name %sl")

	-- Then its settings go to the aura too.
	assert(Profiles.currentProfile.auraSettings["name:Mystery Aura"].message == "Name %sl",
		"a named aura saves into the events")
	assert(Profiles.currentProfile.events["name:Mystery Aura"] == nil, "a named aura created an event")

	-- When Buff Gains has a size of its own and the named aura stops inheriting it.
	Settings("NOTIFICATION_BUFF").fontSize = 20
	Click(VisibleRow("name:Mystery Aura"))
	local size = fontControls.fontSize
	ClickCheckbox(size.inheritCheckbox, false)

	-- Then the size stays editable and a different size is saved for the aura.
	assert(not size.inheritCheckbox:GetChecked() and size.sliderFrame.mouseEnabled,
		"the aura size could not be released from Buff Gains")
	size:SetValue(24)
	assert(Profiles.currentProfile.auraSettings["name:Mystery Aura"].fontSize == 24, "the aura size was not saved")
	Settings("NOTIFICATION_BUFF").fontSize = nil

	-- When a third aura was added, an aura further down is selected in the scrolled list,
	-- and the page is refreshed.
	auras.input:SetText("Beta")
	Click(auras.add)
	ClickEntry("notifications")
	listbox:SetOffset(1)
	for _, row in ipairs(Rows()) do
		if row.eventType == "name:Mystery Aura" then Click(row) end
	end
	ClickEntry("notifications")

	-- Then the aura keeps its place, the selection and the offset, and stays in view.
	local inView
	for _, row in ipairs(Rows()) do inView = inView or row.eventType == "name:Mystery Aura" end
	assert(listbox:GetItem(3) == "name:Mystery Aura" and listbox:GetSelectedItem() == "name:Mystery Aura"
		and listbox:GetOffset() == 1 and inView, "the selected aura moved out of view")
	listbox:SetOffset(0)
	Click(VisibleRow("name:Beta").removeButton)

	-- When both are removed, then rule and style are gone and the list starts with events.
	Click(VisibleRow("name:Mystery Aura").removeButton)
	Click(VisibleRow("1459").removeButton)
	assert(Profiles.currentProfile.auraTracking["1459"] == nil and Profiles.currentProfile.auraSettings["1459"] == nil,
		"removing kept the aura")
	assert(type(listbox:GetItem(1)) == "table", "a removed aura is still listed")
end

-- Rule: the resource list of Resource Gains shows and saves the exclusions as the classic popup does.
do
	-- Given Resource Gains selected with mana excluded.
	ClickRow("NOTIFICATION_RESOURCE_GAIN")
	local button = Labelled(L.WINDOW.resources)
	assert(button and button.shown, "Resource Gains offers no resource list")

	-- When the list is opened.
	Click(button)
	local boxes = {}
	for _, checkbox in ipairs(FindAll(panel, function(region) return region.token ~= nil end)) do
		boxes[checkbox.token] = checkbox
	end

	-- Then it shows the exclusions, and a change saves the whole map.
	assert(not boxes.MANA:GetChecked() and boxes.COMBO_POINTS:GetChecked(), "the list does not show the exclusions")
	assert(not fontControls.fontName:GetParent().shown, "the font controls stay over the list")
	ClickCheckbox(boxes.COMBO_POINTS, false)
	local call = LastCall()
	assert(call[1] == nil and call[2] == "resourceExclusions" and call[3].MANA == true
		and call[3].COMBO_POINTS == true, "the exclusions save differently")

	-- When another event is selected, then the button is gone.
	ClickRow("NOTIFICATION_PROC")
	assert(not button.shown and fontControls.fontName:GetParent().shown, "the resource list stays for other events")
end

-- Rule: the resource list scrolls with the window's bar instead of the template's round buttons.
do
	-- Given Resource Gains selected and its list opened.
	ClickRow("NOTIFICATION_RESOURCE_GAIN")
	Click(Labelled(L.WINDOW.resources))
	local scroll = Find(panel, function(region) return region.kind == "ScrollFrame" end)

	-- Then its bar has the flat thumb and the chevrons.
	local bar = scroll.ScrollBar
	local chevron = "Designs\\Forever\\Artwork\\FlatChevron"
	assert(bar:GetThumbTexture().width == 8, "the thumb is the template's")
	assert(bar.ScrollUpButton:GetNormalTexture().texturePath:find(chevron, 1, true)
		and bar.ScrollDownButton:GetNormalTexture().texturePath:find(chevron, 1, true), "the buttons are the template's")
	ClickRow("NOTIFICATION_PROC")
end

-- Rule: no classic tab is embedded in the Events pages.
do
	for _, key in ipairs({ "incoming", "outgoing", "pet", "notifications", "lootAlerts" }) do
		ClickEntry(key)
		assert(not Find(MSBTOptionsWindowFrame, function(region)
			return region.controls and (region.controls.eventCategoryDropdown or region.controls.lootAlertsColorSwatch)
		end), key .. " embeds a classic tab")
	end
end

print("Options events tests passed")
