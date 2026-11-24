-- Describe: the Scroll Areas page of the new options window lists, sketches and saves scroll areas.
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
function Methods:SetTexture(path) self.texturePath = path end
function Methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Methods:SetColorTexture(r, g, b) self.color = { r, g, b } end
-- Like the game, an edit box reports every text change, also one made by code.
function Methods:SetText(text)
	if self.fontString then return self.fontString:SetText(text) end
	self.text = text ~= nil and tostring(text) or nil
	if self.kind == "Editbox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function Methods:GetText()
	if self.fontString then return self.fontString:GetText() end
	return self.text
end
function Methods:GetStringWidth() return #(self.text or "") * 6 end
function Methods:SetFontString(fontString) self.fontString = fontString end
function Methods:GetFontString() return self.fontString end
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
function Methods:SetValueStep(value) self.step = value end
function Methods:GetValueStep() return self.step end
function Methods:SetPoint(point, relativeTo, relativePoint, x, y)
	self.point = { point, relativeTo, relativePoint, x or 0, y or 0 }
end
function Methods:ClearAllPoints() self.point, self.dropLeft, self.dropBottom = nil, nil, nil end
function Methods:GetCenter() return self.centerX, self.centerY end
-- Only sketch boxes ask for their edges: they hang at the sketch center or where the test dropped them.
function Methods:GetLeft()
	if self.dropLeft then return self.dropLeft end
	return self.point[2]:GetCenter() + self.point[4]
end
function Methods:GetBottom()
	if self.dropBottom then return self.dropBottom end
	local _, centerY = self.point[2]:GetCenter()
	return centerY + self.point[5]
end
function Methods:StartMoving() self.moving = true end
function Methods:StopMovingOrSizing() self.moving = nil end
function Methods:SetClipsChildren(value) self.clips = value end
function Methods:SetFrameLevel(value) self.level = value end
function Methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function Methods:SetBackdropColor(...) self.backdropColor = { ... } end
function Methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function Methods:HookScript(event, handler)
	local original = self.scripts[event]
	self.scripts[event] = function(...)
		if original then original(...) end
		handler(...)
	end
end
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }

function CreateFrame(kind, name, parent) return NewRegion(kind, parent, name) end
UIParent = NewRegion("Frame", nil, "UIParent")
UIParent.width, UIParent.height = 1600, 900
UISpecialFrames = {}
function PlaySound() end
function GetLocale() return "enUS" end
FillLocalizedClassList = Noop
SOUNDKIT = { IG_MAINMENU_OPTION = 850 }
local tooltip = {}
GameTooltip = setmetatable({
	SetOwner = function(_, owner) tooltip.owner = owner end,
	SetText = function(_, text) tooltip.text = text end,
	Hide = function() tooltip.owner, tooltip.text = nil, nil end,
}, { __index = function() return Noop end })
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NONE, OKAY, CANCEL, SAVE, MANA, YES, NO = "None", "Okay", "Cancel", "Save", "Mana", "Yes", "No"
for _, name in ipairs({ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
	"GameFontHighlight", "GameFontDisable", "ChatFontNormal" }) do
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

local displayed = {}
MikSBT = {
	VERSION_STRING = "v12.052",
	Compatibility = { Client = { hasModernAPI = true } },
	translations = { DEFAULT_FONT_NAME = "Default" },
	Configuration = {},
	API = { Sounds = { NormalizeFile = function(_, file) return file ~= "" and file or nil end } },
	Services = {},
	Main = {},
	CopyTable = CopyTable,
	EraseTable = function(value) for key in next, value do value[key] = nil end end,
	Print = Noop,
	DisplayMessage = function(message, area, isSticky)
		displayed[#displayed + 1] = { message, area, isSticky }
	end,
	Media = {
		fonts = { Default = "default.ttf", Custom = "custom.ttf" },
		sounds = { Ding = "ding.ogg" },
		IterateSounds = function() return pairs(MikSBT.Media.sounds) end,
	},
}
dofile("MSBTOptions/Localization/localization.lua")
local L = MikSBT.translations

-- Areas as the master profile defines them, and profiles holding their own copies.
local master = { scrollAreas = {
	Incoming = { name = "Incoming", offsetX = -140, offsetY = -160 },
	Outgoing = { name = "Outgoing", offsetX = 100, offsetY = -160 },
	Notification = { name = "Notification", offsetX = -175, offsetY = 120, scrollWidth = 350, scrollHeight = 200 },
	Static = { name = "Static", offsetX = -20, offsetY = -300, scrollHeight = 125 },
} }
local function NewProfile(custom)
	local areas = CopyTable(master.scrollAreas)
	areas[custom.key] = { name = custom.name, offsetX = 10, offsetY = 20, scrollWidth = 100, scrollHeight = 80 }
	return { scrollAreas = areas, animationSpeed = 100, events = {}, normalFontName = "Default", critFontName = "Default" }
end
local saved = { profiles = {
	Default = NewProfile({ key = "Custom1", name = "Custom Zone" }),
	Alt = NewProfile({ key = "Custom7", name = "Alt Zone" }),
} }
local perChar = { currentProfileName = "Default" }
local calls = {}
local Profiles = { savedVariables = saved, currentProfile = saved.profiles.Default, masterProfile = master }
MikSBT.Profiles = Profiles

local ScrollAreas = dofile("Display/ScrollAreas.lua")
ScrollAreas:Configure({
	getProfile = function() return Profiles.currentProfile end,
	getMasterProfile = function() return master end,
	defaultArea = "Notification",
})
local updates = 0
MikSBT.Animations = {
	scrollAreas = ScrollAreas.areas,
	animationStyles = {
		Straight = { availableDirections = "MSBT_UP;MSBT_DOWN" },
		Parabola = { availableDirections = "MSBT_UP;MSBT_DOWN", availableBehaviors = "CurvedLeft;CurvedRight" },
		Static = {},
	},
	stickyAnimationStyles = {
		Pow = { availableDirections = "MSBT_UP;MSBT_DOWN", availableBehaviors = "MSBT_NORMAL;Jiggle" },
		Static = {},
	},
	UpdateScrollAreas = function()
		updates = updates + 1
		ScrollAreas:Update()
	end,
}
local Animations = MikSBT.Animations
Animations.UpdateScrollAreas()

local function Select(name)
	perChar.currentProfileName = name
	Profiles.currentProfile = saved.profiles[name]
	Animations.UpdateScrollAreas()
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
Profiles.HasImportedMedia = Noop
Profiles.FinishImportedMedia = Noop
snapshots:UpdateLoginSnapshot(true)

dofile("MSBTOptions/MSBTOptionsControls.lua")
dofile("MSBTOptions/MSBTOptionsDesigns.lua")
dofile("MSBTOptions/MSBTOptionsPopups.lua")
dofile("MSBTOptions/MSBTOptionsMain.lua")
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/MSBTOptionsAuras.lua")
dofile("MSBTOptions/MSBTOptionsTabs.lua")
dofile("MSBTOptions/Designs/Forever/Window.lua")
dofile("MSBTOptions/Designs/Forever/Areas.lua")
local Window = MSBTOptions.Window
local Popups = MSBTOptions.Popups
-- The new design is the chosen one, so a closing configuration brings the new window back.
saved.optionsDesign = "forever"

-- The font popup is recorded instead of built.
local fontConfig
Popups.ShowFont = function(config) fontConfig = { saveArg1 = config.saveArg1, title = config.title } end

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
	Click(Find(MSBTOptionsWindowFrame, function(region) return region.key == key and region.kind == "Button" end))
end
local function Labelled(text)
	return Find(UIParent, function(region)
		return region.kind == "Button" and region.shown and region:GetText() == text
	end)
end

Window.Show()
ClickEntry("scrollAreas")
local listbox = Find(MSBTOptionsWindowFrame, function(region) return region.lineHeight == 24 end)
local page = listbox:GetParent()
local SCALE = math.min(408 / 1600, 240 / 900)
local function Box(key)
	return Find(page, function(region) return region.key == key and region.scripts.OnDragStop ~= nil end)
end
local sketch = Box("Incoming"):GetParent()
sketch.centerX, sketch.centerY = 1000, 500
local function Control(label, x)
	return Find(page, function(region)
		local text = region.labelText or region.labelFontString and region.labelFontString:GetText()
			or region.checkFrame and region.fontString:GetText()
		return text == label and region.point and region.point[4] == x
	end)
end
local function Tooltipped(tooltip)
	return Find(page, function(region) return region.tooltip == tooltip end)
end
local normalStyle = Control(L.DROPDOWNS.animationStyle.label, 12)
local stickyStyle = Control(L.DROPDOWNS.stickyAnimationStyle.label, 144)
local direction = Control(L.DROPDOWNS.direction.label, 12)
local stickyDirection = Control(L.DROPDOWNS.direction.label, 144)
local behavior = Control(L.DROPDOWNS.behavior.label, 12)
local stickyBehavior = Control(L.DROPDOWNS.behavior.label, 144)
local textAlign = Control(L.DROPDOWNS.textAlign.label, 12)
local stickyTextAlign = Control(L.DROPDOWNS.textAlign.label, 144)
local xEditbox = Control(L.EDITBOXES.xOffset.label, 12)
local yEditbox = Control(L.EDITBOXES.yOffset.label, 144)
local heightSlider = Control(L.SLIDERS.scrollHeight.label, 12)
local widthSlider = Control(L.SLIDERS.scrollWidth.label, 144)
local speedSlider = Control(L.SLIDERS.scrollAnimationSpeed.label, 12)
-- This language has no word of its own for it, so the box keeps the classic one.
local inherit = Control(L.CHECKBOXES.inheritField.label, 144)
local iconAlign = Control(L.DROPDOWNS.iconAlign.label, 12)
local hideIcons = Control(L.CHECKBOXES.hideSkillIcons.label, 12)
local deleteButton = Tooltipped(L.BUTTONS.deleteScrollArea.tooltip)
local renameButton = Tooltipped(L.BUTTONS.editScrollAreaName.tooltip)
local fontButton = Tooltipped(L.BUTTONS.scrollAreaFontSettings.tooltip)
local title = Find(page, function(region) return region.kind == "FontString" and region.width == 160 end)

local function Items()
	local items = {}
	for index = 1, listbox:GetNumItems() do items[index] = listbox:GetItem(index) end
	return items
end
local function Row(key)
	for index = 1, listbox:GetNumLines() do
		local row = listbox:GetLine(index)
		if row.shown and row.scrollAreaKey == key then return row end
	end
end
local function ClickRow(key) Click(Row(key)) end
local function Area(key) return Animations.scrollAreas[key] end
local function LastCall() return calls[#calls] end
local function Called(call, section, key, value, default)
	return call ~= nil and call[1] == section and call[2] == key and call[3] == value and call[4] == default
end
local function Near(a, b) return math.abs(a - b) < 0.001 end
local function SortedKeys()
	local keys = {}
	for key in pairs(Profiles.currentProfile.scrollAreas) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return Area(a).name < Area(b).name end)
	return keys
end
local function Drag(box, left, bottom)
	box.scripts.OnMouseDown(box, "LeftButton")
	box.scripts.OnDragStart(box)
	box.dropLeft, box.dropBottom = left, bottom
	box.scripts.OnDragStop(box)
end
local function Input()
	return Find(UIParent, function(region) return region.inputEditbox ~= nil and region.shown end)
end

-- Rule: the list shows every area of the profile by name, with its enabled state.
do
	-- Given a profile with a custom area and a disabled one.
	Profiles.currentProfile.scrollAreas.Static.disabled = true
	ClickEntry("general")
	ClickEntry("scrollAreas")

	-- Then the list holds every area sorted by name and the rows show the state.
	local items, expected = Items(), SortedKeys()
	assert(#items == 5 and #expected == 5, "the list holds " .. #items .. " areas")
	for index, key in ipairs(expected) do
		assert(items[index] == key, "row " .. index .. " is " .. tostring(items[index]) .. " instead of " .. key)
	end
	assert(Row("Custom1").nameFontString:GetText() == "Custom Zone", "a row does not show the area name")
	assert(not Row("Static").enableCheckbox:GetChecked() and Row("Incoming").enableCheckbox:GetChecked(),
		"the rows do not show the enabled state")
	Profiles.currentProfile.scrollAreas.Static.disabled = nil
end

-- Rule: the row checkbox enables and disables the area as the classic tab does.
do
	ClickCheckbox(Row("Outgoing").enableCheckbox, false)
	assert(Called(LastCall(), "scrollAreas.Outgoing", "disabled", true), "disabling saves differently")
	ClickCheckbox(Row("Outgoing").enableCheckbox, true)
	assert(Called(LastCall(), "scrollAreas.Outgoing", "disabled", false), "enabling saves differently")
	Area("Outgoing").disabled = nil
end

-- Rule: selecting an area fills the settings from it and writes nothing.
do
	-- Given an area with its own value for every setting.
	local outgoing = Profiles.currentProfile.scrollAreas.Outgoing
	outgoing.animationStyle, outgoing.direction, outgoing.behavior = "Parabola", "MSBT_DOWN", "CurvedRight"
	outgoing.textAlignIndex, outgoing.stickyAnimationStyle, outgoing.stickyDirection = 1, "Pow", "MSBT_DOWN"
	outgoing.stickyBehavior, outgoing.stickyTextAlignIndex, outgoing.scrollHeight = "Jiggle", 3, 200
	outgoing.scrollWidth, outgoing.animationSpeed, outgoing.iconAlign = 60, 150, "Right"
	outgoing.skillIconsDisabled = true
	calls = {}

	-- When its row is clicked.
	ClickRow("Outgoing")

	-- Then every control shows its value.
	assert(title:GetText() == "Outgoing", "the title is " .. tostring(title:GetText()))
	assert(normalStyle:GetSelectedID() == "Parabola" and direction:GetSelectedID() == "MSBT_DOWN"
		and behavior:GetSelectedID() == "CurvedRight", "the normal style was not filled")
	assert(#behavior.itemIDs == 2 and behavior.itemIDs[1] == "CurvedLeft", "the behaviors are not the style's")
	assert(textAlign:GetSelectedID() == 1 and stickyTextAlign:GetSelectedID() == 3, "the text align was not filled")
	assert(stickyStyle:GetSelectedID() == "Pow" and stickyDirection:GetSelectedID() == "MSBT_DOWN"
		and stickyBehavior:GetSelectedID() == "Jiggle", "the sticky style was not filled")
	assert(xEditbox:GetText() == "100" and yEditbox:GetText() == "-160", "the offsets were not filled")
	assert(heightSlider:GetValue() == 200 and widthSlider:GetValue() == 60, "the size was not filled")
	assert(speedSlider:GetValue() == 150 and not inherit:GetChecked(), "the speed was not filled")
	assert(iconAlign:GetSelectedID() == "Right" and hideIcons:GetChecked(), "the icons were not filled")
	assert(#calls == 0, "selecting an area wrote " .. #calls .. " settings")

	-- When an area without own values is selected, then the classic defaults are shown.
	ClickRow("Incoming")
	assert(normalStyle:GetSelectedID() == "Straight" and direction:GetSelectedID() == "MSBT_UP"
		and behavior:GetSelectedID() == "MSBT_NORMAL", "the default style is not shown")
	assert(stickyStyle:GetSelectedID() == "Pow" and textAlign:GetSelectedID() == 2, "the sticky defaults are not shown")
	assert(heightSlider:GetValue() == 260 and widthSlider:GetValue() == 40, "the default size is not shown")
	assert(speedSlider:GetValue() == 100 and inherit:GetChecked(), "the speed is not inherited")
	assert(iconAlign:GetSelectedID() == "Left" and not hideIcons:GetChecked(), "the default icons are not shown")
	assert(xEditbox:GetText() == "-140", "the offset of the second area was not filled")
	assert(#calls == 0, "selecting an area wrote " .. #calls .. " settings")

	-- When a style is registered after the page was built, then selecting an area lists it, as the classic one does.
	Animations.animationStyles.Late = {}
	ClickRow("Outgoing")
	local listed = false
	for _, id in ipairs(normalStyle.itemIDs) do listed = listed or id == "Late" end
	assert(listed and #normalStyle.itemIDs == 4, "the style list was not refilled")
	Animations.animationStyles.Late = nil
end

-- Rule: each control saves the same field with the same default as the classic configuration, at once.
do
	ClickRow("Outgoing")
	local section = "scrollAreas.Outgoing"
	local function Saved(key, value, default, message)
		local before = updates
		return function(action)
			calls = {}
			action()
			assert(Called(calls[1], section, key, value, default), message .. " saves differently")
			assert(updates > before, message .. " is not applied to the running addon")
		end
	end

	Saved("animationStyle", "Straight", "Straight", "the style")(function() normalStyle:changeHandler("Straight") end)
	assert(Called(calls[1], section, "animationStyle", "Straight", "Straight")
		and Called(calls[2], section, "direction", "MSBT_UP", "MSBT_NORMAL")
		and Called(calls[3], section, "behavior", "MSBT_NORMAL", "MSBT_NORMAL"),
		"a new style does not save its first direction and behavior")
	assert(#direction.itemIDs == 2 and #behavior.itemIDs == 1, "the directions do not follow the new style")
	Saved("stickyAnimationStyle", "Static", "Pow", "the sticky style")(function() stickyStyle:changeHandler("Static") end)
	assert(Called(calls[2], section, "stickyDirection", "MSBT_NORMAL", "MSBT_NORMAL")
		and Called(calls[3], section, "stickyBehavior", "MSBT_NORMAL", "MSBT_NORMAL"),
		"a new sticky style does not save its first direction and behavior")
	Saved("direction", "MSBT_DOWN", "MSBT_NORMAL", "the direction")(function() direction:changeHandler("MSBT_DOWN") end)
	Saved("behavior", "X", "MSBT_NORMAL", "the behavior")(function() behavior:changeHandler("X") end)
	Saved("stickyDirection", "MSBT_UP", "MSBT_NORMAL", "the sticky direction")(function()
		stickyDirection:changeHandler("MSBT_UP") end)
	Saved("stickyBehavior", "Y", "MSBT_NORMAL", "the sticky behavior")(function() stickyBehavior:changeHandler("Y") end)
	Saved("textAlignIndex", 3, 2, "the text align")(function() textAlign:changeHandler(3) end)
	Saved("stickyTextAlignIndex", 1, 2, "the sticky text align")(function() stickyTextAlign:changeHandler(1) end)
	Saved("offsetX", 55, nil, "X")(function() xEditbox:SetText("55") end)
	Saved("offsetY", -70, nil, "Y")(function() yEditbox:SetText("-70") end)
	Saved("scrollHeight", 300, 260, "the height")(function() heightSlider:SetValue(300) end)
	Saved("scrollWidth", 120, 40, "the width")(function() widthSlider:SetValue(120) end)
	Saved("animationSpeed", 200, 100, "the speed")(function() speedSlider:SetValue(200) end)
	Saved("animationSpeed", 100, 100, "inheriting the speed")(function() ClickCheckbox(inherit, true) end)
	Saved("iconAlign", "Left", "Left", "the icon align")(function() iconAlign:changeHandler("Left") end)
	Saved("skillIconsDisabled", false, nil, "hiding icons")(function() ClickCheckbox(hideIcons, false) end)

	-- Then the box follows the new size and position.
	local box = Box("Outgoing")
	assert(Near(box.width, 120 * SCALE) and Near(box.height, 300 * SCALE), "the box did not follow the size")
	assert(Near(box.point[4], 55 * SCALE) and Near(box.point[5], -70 * SCALE), "the box did not follow the offsets")

	-- When a number is still being typed, then the field keeps the text.
	xEditbox:SetText("55.")
	assert(xEditbox:GetText() == "55.", "the field rewrote the text being typed")
	xEditbox:SetText("-")
	assert(Area("Outgoing").offsetX == 55, "an unfinished number was saved")
end

-- Rule: the boxes show every area at its offset and size at the sketch scale, the selected one highlighted.
do
	ClickRow("Notification")
	assert(Near(sketch.width, 1600 * SCALE) and Near(sketch.height, 900 * SCALE), "the sketch is not the screen's shape")
	assert(sketch.clips, "a box off the screen can cover the controls beside the sketch")
	for key in pairs(Profiles.currentProfile.scrollAreas) do
		local area, box = Area(key), Box(key)
		assert(box and box.shown, "the sketch has no box for " .. key)
		assert(box.point[1] == "BOTTOMLEFT" and box.point[2] == sketch and box.point[3] == "CENTER",
			key .. " is not placed from the center")
		assert(Near(box.point[4], (area.offsetX or 0) * SCALE) and Near(box.point[5], (area.offsetY or 0) * SCALE),
			key .. " is not at its offset")
		assert(Near(box.width, (area.scrollWidth or 40) * SCALE) and Near(box.height, (area.scrollHeight or 260) * SCALE),
			key .. " does not have its size")
		local gold = key == "Notification"
		assert((box.border.color[1] == MSBTOptions.Window.COLORS.gold[1]) == gold, key .. " is highlighted wrongly")
	end
end

-- Rule: dropping a box writes the position it was dropped at, clamped to the sketch, and redraws it from that.
do
	-- Given the Static area, 40 wide and 125 high.
	local box = Box("Static")
	calls = {}

	-- When it is only clicked, then it is selected and nothing is written.
	box.scripts.OnMouseDown(box, "LeftButton")
	assert(title:GetText() == "Static", "clicking a box did not select its area")
	assert(#calls == 0, "clicking a box wrote a position")

	-- When it is dropped inside the sketch.
	Drag(box, 1000 + 51, 500 - 25.5)

	-- Then the drop point is saved in UI units and the box hangs there.
	assert(Called(calls[1], "scrollAreas.Static", "offsetX", 200) and Called(calls[2], "scrollAreas.Static", "offsetY", -100),
		"the drop was saved as " .. tostring(Area("Static").offsetX) .. ", " .. tostring(Area("Static").offsetY))
	assert(xEditbox:GetText() == "200" and yEditbox:GetText() == "-100", "the offsets do not show the drop")
	assert(box:GetLeft() == 1000 + 200 * SCALE and box.point[2] == sketch, "the box was not redrawn from the saved value")

	-- When it is dropped beyond the right and bottom edge.
	Drag(box, 1000 + 300, 500 - 200)

	-- Then it is kept fully on the screen.
	assert(Area("Static").offsetX == 760 and Area("Static").offsetY == -450,
		"the drop was clamped to " .. Area("Static").offsetX .. ", " .. Area("Static").offsetY)
	assert(Near(box:GetLeft(), 1000 + 760 * SCALE), "the clamped box was not redrawn")

	-- When it is dropped beyond the left and top edge, then the top edge holds the area's height.
	Drag(box, 1000 - 300, 500 + 200)
	assert(Area("Static").offsetX == -800 and Area("Static").offsetY == 450 - 125,
		"the drop was clamped to " .. Area("Static").offsetX .. ", " .. Area("Static").offsetY)
end

-- Rule: built-in areas cannot be deleted; a custom one can, and its row and box go away.
do
	ClickRow("Incoming")
	assert(not deleteButton.enabled, "a built-in area can be deleted")
	ClickRow("Custom1")
	assert(deleteButton.enabled, "a custom area cannot be deleted")

	Click(deleteButton)
	local acknowledge = Find(UIParent, function(region) return region.acknowledgeHandler ~= nil and region.shown end)
	Click(Find(acknowledge, function(region) return region.kind == "Button" and region:GetText() == YES end))

	assert(Profiles.currentProfile.scrollAreas.Custom1 == nil and Area("Custom1") == nil, "the area was not deleted")
	assert(listbox:GetNumItems() == 4 and not Row("Custom1"), "the row stayed")
	assert(not Box("Custom1").shown, "the box stayed")
	assert(title:GetText() == Area(Items()[1]).name, "no area is selected after the delete")
end

-- Rule: adding and renaming an area work as in the classic tab.
do
	-- When an area is added under a name that exists, then it cannot be saved.
	Click(Labelled(L.BUTTONS.addScrollArea.label))
	local input = Input()
	input.inputEditbox:SetText("Incoming")
	assert(not input.okayButton.enabled, "a duplicate name was accepted")

	-- When it gets a new name.
	input.inputEditbox:SetText("Kappa Zone")
	Click(input.okayButton)

	-- Then it exists, is listed, sketched and selected.
	local area = Profiles.currentProfile.scrollAreas.Custom1
	assert(area and area.name == "Kappa Zone", "the area was not added")
	assert(Row("Custom1") and Box("Custom1").shown, "the new area has no row or box")
	assert(title:GetText() == "Kappa Zone", "the new area is not selected")

	-- When it is renamed.
	Click(renameButton)
	input = Input()
	assert(input.inputEditbox:GetText() == "Kappa Zone", "rename does not start from the name")
	input.inputEditbox:SetText("Zulu Zone")
	Click(input.okayButton)

	-- Then the name is saved and the list is sorted again.
	assert(Called(LastCall(), "scrollAreas.Custom1", "name", "Zulu Zone"), "the rename saved differently")
	assert(Items()[5] == "Custom1" and Box("Custom1").label:GetText() == "Zulu Zone", "the rename is not shown")
end

-- Rule: the area's font opens in the classic font popup.
do
	ClickRow("Custom1")
	Click(fontButton)
	assert(fontConfig and fontConfig.saveArg1 == "Custom1" and fontConfig.title == "Zulu Zone",
		"the font popup did not open for the selected area")
end

-- Rule: the selected area's row is scrolled into view.
do
	-- Given more areas than rows, the last one added at the end of the list.
	for _, name in ipairs({ "Zz One", "Zz Two" }) do
		Click(Labelled(L.BUTTONS.addScrollArea.label))
		Input().inputEditbox:SetText(name)
		Click(Input().okayButton)
	end
	assert(listbox:GetNumItems() > listbox:GetNumLines(), "the list does not need to scroll")

	-- Then the new area's row is shown, and selecting the first area by its box shows that row.
	assert(Row(Items()[listbox:GetNumItems()]), "the selected new area is not shown in the list")
	local first = Items()[1]
	Box(first).scripts.OnMouseDown(Box(first), "LeftButton")
	assert(Row(first), "the area selected in the sketch is not shown in the list")
end

-- Rule: Preview shows the classic test lines in every area while the window steps aside.
do
	-- When Preview is clicked.
	displayed, timers = {}, {}
	Click(Labelled(L.BUTTONS.scrollAreasPreview.label))

	-- Then each area shows the classic lines and the window is hidden.
	local count = listbox:GetNumItems()
	assert(#displayed == 3 * count, "the preview showed " .. #displayed .. " lines")
	local sticky = 0
	for _, line in ipairs(displayed) do
		if line[3] then sticky = sticky + 1 end
		assert(line[1] == Area(line[2]).name, "a preview line is not in its area")
	end
	assert(sticky == count, "the preview did not show a sticky line per area")
	assert(not MSBTOptionsWindowFrame.shown, "the window covers the preview")

	-- When the one timer of the click runs, then the window is back with its Cancel base.
	assert(#timers == 1 and timers[1][1] == 3, "the preview did not start one timer for its lines")
	timers[1][2]()
	assert(MSBTOptionsWindowFrame.shown, "the window did not come back after the preview")
	assert(Labelled(L.WINDOW.apply).enabled, "the preview dropped the changes Cancel would undo")
end

-- Rule: the window does not come back from a preview while the scroll areas are positioned.
do
	-- Given Preview was clicked, and before its timer ran the options were opened again and put
	-- away for the configuration on screen.
	displayed, timers = {}, {}
	Click(Labelled(L.BUTTONS.scrollAreasPreview.label))
	MSBTOptions.Designs.Show()
	Click(Labelled(L.WINDOW.onScreen))
	local config = MSBTScrollAreasConfigFrame
	assert(config.shown and not MSBTOptionsWindowFrame.shown, "the configuration did not open")

	-- When the timer of the preview runs.
	timers[1][2]()

	-- Then the configuration stays open, and the window comes back when it is closed.
	assert(config.shown and not MSBTOptionsWindowFrame.shown,
		"the preview brought the window back over the configuration")
	Click(Find(config, function(region)
		return region.kind == "Button" and region:GetText() == L.BUTTONS.genericCancel.label
	end))
	assert(MSBTOptionsWindowFrame.shown and not config.shown, "the window did not come back after the configuration")
end

-- Rule: "Configure on screen" opens the classic configuration with the same ranges and comes back.
do
	-- When the button is clicked.
	Click(Labelled(L.WINDOW.onScreen))

	-- Then the classic configuration replaces the window.
	local config = MSBTScrollAreasConfigFrame
	assert(config and config.shown and not MSBTOptionsWindowFrame.shown, "the classic configuration did not open")

	-- And the page's sliders have the ranges the classic sliders always had.
	for _, range in ipairs({ { heightSlider, 50, 600, 5 }, { widthSlider, 10, 800, 10 }, { speedSlider, 20, 250, 10 } }) do
		local slider = range[1].sliderFrame
		assert(slider.minValue == range[2] and slider.maxValue == range[3] and slider.step == range[4],
			range[1].labelText .. " has another range than the classic slider")
	end

	-- When an area is moved there and saved.
	config.previewSettings.Outgoing.offsetX = 333
	Click(Find(config, function(region) return region.kind == "Button" and region:GetText() == L.BUTTONS.genericSave.label end))

	-- Then the window is back and the box shows the new position.
	assert(MSBTOptionsWindowFrame.shown and not config.shown, "the window did not come back")
	assert(Near(Box("Outgoing").point[4], 333 * SCALE), "the page was not refreshed after the configuration")
end

-- Rule: the configuration the new window opens is an instance of the new design, skinned when it
-- is made; the classic popups are other instances that keep their art, and the configuration's
-- global name follows the instance shown last.
do
	-- Given the configuration the new window opened above.
	local design = MSBTScrollAreasConfigFrame

	-- When the classic popups are in use and the configuration opens.
	Popups.UseDesignPopups("classic")
	Popups.ShowScrollAreaConfig()
	local classic = MSBTScrollAreasConfigFrame
	classic:Hide()
	Popups.UseDesignPopups("forever")

	-- Then the classic instance is another frame, and only the design's lost the paper-doll art.
	local function ArtShown(frame)
		for _, region in ipairs(frame.regions) do
			if (region.texturePath or ""):find("PaperDollInfoFrame", 1, true) then return region.shown end
		end
	end
	assert(classic ~= design, "both designs share the configuration")
	assert(ArtShown(classic) == true and ArtShown(design) == false, "the skin reached the wrong instance")
	Popups.ShowScrollAreaConfig()
	assert(MSBTScrollAreasConfigFrame == design, "the global name stayed with the classic instance")
	design:Hide()
	Window.Show()
end

local classicConfig
local COLORS = Window.COLORS
local function OpenOnScreen()
	Click(Labelled(L.WINDOW.onScreen))
	return MSBTScrollAreasConfigFrame
end

-- Rule: the new design's movers are translucent and dark with a thin border, the selected one gold
-- and stronger; the classic movers stay grey with the selected one red.
do
	-- Given the classic configuration opened once.
	Popups.UseDesignPopups("classic")
	Popups.ShowScrollAreaConfig()
	classicConfig = MSBTScrollAreasConfigFrame
	classicConfig:Hide()
	Popups.UseDesignPopups("forever")
	Window.Show()

	-- When the new window opens its configuration, with Incoming selected.
	local design = OpenOnScreen()

	-- Then its movers are flat, and only Incoming has the gold border and the stronger fill.
	for key, mover in pairs(design.moverFrames) do
		local isSelected = key == "Incoming"
		local fill, border = mover.backdropColor, mover.borderColor
		assert(mover.backdrop.edgeSize == 1 and fill[1] == COLORS.window[1], key .. " is not flat")
		assert(border[1] == (isSelected and COLORS.gold or COLORS.border)[1], key .. " has the wrong border")
		assert(fill[4] < 1 and (fill[4] > 0.6) == isSelected, key .. " has the wrong fill")
	end

	-- And the classic movers keep the classic ground, grey with the selected one red.
	for key, mover in pairs(classicConfig.moverFrames) do
		local expected = key == "Incoming" and { 0.5, 0.05, 0.05, 1 } or { 0.8, 0.8, 0.8, 1 }
		assert(mover.backdrop.edgeFile == nil and mover.borderColor == nil, key .. " lost the classic ground")
		for index = 1, 4 do assert(mover.backdropColor[index] == expected[index], key .. " has another classic colour") end
		assert(mover.fontString.shown and mover.scripts.OnEnter == nil, key .. " lost the classic label")
	end
end

-- Rule: only the selected mover shows its label; the others show it as a tooltip.
do
	-- Given the new design's configuration with Incoming selected.
	local design = MSBTScrollAreasConfigFrame
	local incoming, outgoing = design.moverFrames.Incoming, design.moverFrames.Outgoing

	-- Then only Incoming shows its label.
	for key, mover in pairs(design.moverFrames) do
		assert(mover.fontString.shown == (key == "Incoming"), key .. " shows its label wrongly")
	end

	-- When the mouse enters another mover, then the tooltip shows its label, and leaving removes it.
	outgoing.scripts.OnEnter(outgoing)
	assert(tooltip.owner == outgoing and tooltip.text == outgoing.fontString:GetText()
		and tooltip.text:find("^Outgoing %("), "the tooltip does not show the label")
	outgoing.scripts.OnLeave(outgoing)
	assert(tooltip.text == nil, "the tooltip stayed")

	-- When the mouse enters the selected mover, then no tooltip repeats its label.
	incoming.scripts.OnEnter(incoming)
	assert(tooltip.text == nil, "the selected mover repeats its label")

	-- When a drag starts on another mover, then its tooltip goes and the mover moves.
	outgoing.scripts.OnEnter(outgoing)
	outgoing.scripts.OnMouseDown(outgoing, "LeftButton")
	assert(tooltip.text == nil and outgoing.moving, "the drag kept the tooltip or did not move")
	outgoing:StopMovingOrSizing()
end

-- Rule: the gold border and the label follow the selection, from the dropdown and from a dropped mover.
do
	local design = MSBTScrollAreasConfigFrame
	local function AssertSelected(selected)
		for key, mover in pairs(design.moverFrames) do
			local isSelected = key == selected
			assert((mover.borderColor[1] == COLORS.gold[1]) == isSelected and mover.fontString.shown == isSelected,
				key .. " does not follow the selection of " .. selected)
		end
	end

	-- When Static is chosen in the dropdown, then Static is selected.
	design.scrollAreaDropdown:SetSelectedID("Static")
	design.scrollAreaDropdown:changeHandler("Static")
	AssertSelected("Static")

	-- When Outgoing is dragged and dropped, then it is selected and its label shows the new position.
	UIParent.centerX, UIParent.centerY = 800, 450
	local outgoing = design.moverFrames.Outgoing
	outgoing.scripts.OnMouseDown(outgoing, "LeftButton")
	outgoing.dropLeft, outgoing.dropBottom = 900, 300
	outgoing.scripts.OnMouseUp(outgoing, "LeftButton")
	AssertSelected("Outgoing")
	assert(outgoing.fontString:GetText() == "Outgoing (100, -150)", "the label shows " .. outgoing.fontString:GetText())
end

-- Rule: an area created after the configuration was first built gets a flat mover too.
do
	-- Given the configuration closed and an area created since.
	MSBTScrollAreasConfigFrame:Hide()
	local areas = Profiles.currentProfile.scrollAreas
	areas.Later = { name = "Later", offsetX = 0, offsetY = 0 }
	Animations.UpdateScrollAreas()

	-- When the configuration opens again.
	local design = OpenOnScreen()

	-- Then the new area's mover is flat, without its label, and names the area in a tooltip.
	local later = design.moverFrames.Later
	assert(later and later.backdrop.edgeSize == 1 and later.borderColor[1] == COLORS.border[1], "the new mover is not flat")
	assert(not later.fontString.shown, "the new mover shows its label")
	later.scripts.OnEnter(later)
	assert(tooltip.text == later.fontString:GetText(), "the new mover has no tooltip")
	later.scripts.OnLeave(later)

	areas.Later = nil
	Animations.UpdateScrollAreas()
	design:Hide()
end

-- Rule: the new design's configuration opens with its left edge 320 right of the screen center,
-- clear of the movers; the classic one keeps the screen's right edge.
do
	local point = MSBTScrollAreasConfigFrame.point
	assert(point[1] == "LEFT" and point[2] == UIParent and point[3] == "CENTER" and point[4] == 320 and point[5] == 0,
		"the configuration is not beside the screen center")
	assert(classicConfig.point[1] == "RIGHT" and classicConfig.point[2] == nil, "the classic configuration moved")
end

-- Rule: a popup of the new design opens centred on the window whatever its caller anchors it to,
-- also when it is shown again while open; a popup it opens is centred above it.
do
	local window = MSBTOptionsWindowFrame
	local function Centred(popup)
		local point = popup.point
		return point[1] == "CENTER" and point[2] == window and point[3] == "CENTER"
	end
	local function ShowList(anchorPoint)
		Popups.ShowItemList({ parentFrame = window, anchorFrame = Labelled(L.WINDOW.onScreen),
			anchorPoint = anchorPoint, relativePoint = "BOTTOMLEFT", items = { Hearthstone = true } })
		return Find(UIParent, function(region) return region.addItemButton ~= nil and region.shown end)
	end

	-- When the item list opens at a button, and again at another point while it is open.
	local list = ShowList("TOPLEFT")
	local first = Centred(list)
	ShowList("BOTTOMRIGHT")

	-- Then it is centred on the window both times.
	assert(first and Centred(list), "the item list hangs on its button")

	-- When it opens the input popup for a new item.
	Click(list.addItemButton)
	local input = Find(UIParent, function(region) return region.inputEditbox ~= nil and region.shown end)

	-- Then the input is centred too, above the list.
	assert(Centred(input) and input:GetFrameLevel() > list:GetFrameLevel(), "the input is not centred above the list")
	input:Hide()
	list:Hide()
end

-- Rule: a refresh after an undo or a profile change redraws the list, the boxes and the settings.
do
	-- Given a selected area that was moved.
	ClickRow("Outgoing")
	Drag(Box("Outgoing"), 1000, 500)
	assert(Area("Outgoing").offsetX == 0, "the drag did not move the area")

	-- When everything is undone on the Changes page and the page is shown again.
	ClickEntry("changes")
	Click(Labelled(L.WINDOW.undoAll))
	ClickEntry("scrollAreas")

	-- Then the same area shows its position from login, and the list has the login areas.
	assert(title:GetText() == "Outgoing", "the selection was lost")
	assert(xEditbox:GetText() == "100" and Near(Box("Outgoing").point[4], 100 * SCALE),
		"the undone position is not shown")
	assert(Row("Custom1").nameFontString:GetText() == "Custom Zone" and Box("Custom1").shown,
		"the restored area is not listed")
	assert(heightSlider:GetValue() == 260, "the settings were not re-read")

	-- When the profile changes in the header.
	local dropdown = Find(MSBTOptionsWindowFrame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	ClickRow("Custom1")
	Click(deleteButton)
	local acknowledge = Find(UIParent, function(region) return region.acknowledgeHandler ~= nil and region.shown end)
	dropdown:changeHandler("Alt")

	-- Then a popup for the old profile's area is closed.
	assert(not acknowledge.shown, "a popup kept the old profile's area across the switch")

	-- And the other profile's areas are listed and sketched, and its first area is selected.
	assert(Row("Custom7") and not Row("Custom1"), "the list shows the old profile")
	assert(Box("Custom7").shown and not Box("Custom1").shown, "the sketch shows the old profile")
	assert(title:GetText() == Area(Items()[1]).name, "a vanished area stayed selected")
	assert(heightSlider:GetValue() == (Area(Items()[1]).scrollHeight or 260), "the settings show the old profile")
end

-- Rule: a refresh takes the screen's size again, for the sketch and the clamp of a drop.
do
	-- Given a 4:3 screen after a change of resolution.
	UIParent.width, UIParent.height = 1200, 900
	ClickEntry("general")
	ClickEntry("scrollAreas")

	-- Then the sketch has the new shape and a drop is clamped to the new edges.
	local scale = 240 / 900
	assert(Near(sketch.width, 1200 * scale) and Near(sketch.height, 240), "the sketch kept the old shape")
	ClickRow("Static")
	Drag(Box("Static"), 1000 + 300, 500)
	assert(Area("Static").offsetX == 600 - 40, "the drop was clamped to " .. Area("Static").offsetX)
	assert(Near(Box("Static").point[4], 560 * scale), "the box does not use the new scale")
end

-- Rule: the sketch shows a centered band of the screen as wide as 16:9, widened just enough for every area.
do
	local profileAreas = Profiles.currentProfile.scrollAreas
	local outgoing = profileAreas.Outgoing
	local original = { outgoing.offsetX, outgoing.scrollWidth }
	local function Reopen()
		ClickEntry("general")
		ClickEntry("scrollAreas")
	end
	local function Place(offsetX, width)
		outgoing.offsetX, outgoing.scrollWidth = offsetX, width
		Animations.UpdateScrollAreas()
		Reopen()
	end

	-- Given every area inside the band of a 32:9 screen.
	UIParent.width, UIParent.height = 3200, 900
	Place(100, 40)
	for key in pairs(Profiles.currentProfile.scrollAreas) do
		local area = Area(key)
		assert(math.abs(area.offsetX or 0) <= 800 and math.abs((area.offsetX or 0) + (area.scrollWidth or 40)) <= 800,
			key .. " lies outside the band")
	end

	-- Then the sketch shows the 16:9 band at its scale and is as high as it would be on a 16:9 screen.
	local scale = math.min(408 / 1600, 240 / 900)
	assert(Near(sketch.width, 1600 * scale) and Near(sketch.height, 900 * scale),
		"the sketch is " .. sketch.width .. " x " .. sketch.height)
	assert(Near(Box("Outgoing").point[4], 100 * scale) and Near(Box("Outgoing").width, 40 * scale),
		"the boxes do not use the band's scale")

	-- When an area reaches beyond the band to the right, then the view widens to hold it.
	Place(1000, 60)
	scale = 408 / (2 * 1060)
	assert(Near(sketch.width, 408) and Near(sketch.height, 900 * scale), "the view did not widen to the right")
	assert(Near(Box("Outgoing").point[4], 1000 * scale), "the box does not use the widened scale")

	-- When it is dropped, then the drop is converted with that scale.
	Drag(Box("Outgoing"), 1000 + 1200 * scale, 500 + 100 * scale)
	assert(Area("Outgoing").offsetX == 1200 and Area("Outgoing").offsetY == 100,
		"the drop was saved as " .. Area("Outgoing").offsetX .. ", " .. Area("Outgoing").offsetY)

	-- When an area reaches beyond the band to the left, then the farthest edge counts.
	Place(-1500, 40)
	assert(Near(sketch.width, 408) and Near(sketch.height, 900 * 408 / 3000), "the view did not widen to the left")

	-- When an area lies beyond the screen, then the view stops at the screen.
	Place(5000, 60)
	assert(Near(sketch.width, 408) and Near(sketch.height, 900 * 408 / 3200), "the view grew beyond the screen")

	-- When the screen is 16:10, then it is shown whole as before.
	UIParent.width, UIParent.height = 1440, 900
	Place(100, 40)
	scale = math.min(408 / 1440, 240 / 900)
	assert(Near(sketch.width, 1440 * scale) and Near(sketch.height, 900 * scale), "a 16:10 screen is not shown whole")

	outgoing.offsetX, outgoing.scrollWidth = original[1], original[2]
	Animations.UpdateScrollAreas()
end

-- Rule: an area moved beyond the band widens the view at once and every box is drawn with the new scale.
do
	local outgoing = Profiles.currentProfile.scrollAreas.Outgoing
	local original = { outgoing.offsetX, outgoing.scrollWidth }
	local function AllBoxesAt(scale, message)
		for key in pairs(Profiles.currentProfile.scrollAreas) do
			local area, box = Area(key), Box(key)
			assert(Near(box.point[4], (area.offsetX or 0) * scale) and Near(box.width, (area.scrollWidth or 40) * scale),
				key .. " " .. message)
		end
	end

	-- Given a 32:9 screen with every area inside the band and Outgoing selected.
	UIParent.width, UIParent.height = 3200, 900
	outgoing.offsetX, outgoing.scrollWidth = 100, 40
	Animations.UpdateScrollAreas()
	ClickEntry("general")
	ClickEntry("scrollAreas")
	ClickRow("Outgoing")
	local band = math.min(408 / 1600, 240 / 900)
	AllBoxesAt(band, "is not at the band's scale")

	-- When it is dropped beyond the band, then the view widens and every box follows.
	Drag(Box("Outgoing"), 1000 + 1200 * band, 500)
	local scale = 408 / (2 * 1240)
	assert(Near(sketch.width, 408) and Near(sketch.height, 900 * scale), "the view did not widen after the drop")
	AllBoxesAt(scale, "was not redrawn after the drop")

	-- When the offset field moves it further out, then the view follows again.
	xEditbox:SetText("1400")
	scale = 408 / (2 * 1440)
	assert(Near(sketch.height, 900 * scale), "the view did not widen after the offset field")
	AllBoxesAt(scale, "was not redrawn after the offset field")

	-- When the width slider makes it wider, then the view follows again.
	widthSlider:SetValue(160)
	scale = 408 / (2 * 1560)
	assert(Near(sketch.height, 900 * scale), "the view did not widen after the width slider")
	AllBoxesAt(scale, "was not redrawn after the width slider")

	UIParent.width, UIParent.height = 1440, 900
	outgoing.offsetX, outgoing.scrollWidth = original[1], original[2]
	Animations.UpdateScrollAreas()
end

-- Rule: only the selected box shows its name; every box names its area in a tooltip while the mouse is over it.
do
	-- Given the Incoming area selected.
	ClickRow("Incoming")

	-- Then only its box shows the name.
	for key in pairs(Profiles.currentProfile.scrollAreas) do
		assert(Box(key).label.shown == (key == "Incoming"), key .. " shows its name wrongly")
	end

	-- When the mouse enters another box, then the tooltip names its area and leaving removes it.
	local box = Box("Outgoing")
	box.scripts.OnEnter(box)
	assert(tooltip.owner == box and tooltip.text == Area("Outgoing").name, "the tooltip does not name the area")
	box.scripts.OnLeave(box)
	assert(tooltip.text == nil, "the tooltip stayed")

	-- When that box is clicked, then the name moves to it.
	box.scripts.OnMouseDown(box, "LeftButton")
	assert(box.label.shown and not Box("Incoming").label.shown, "the name did not move with the selection")
end

-- Rule: Hide Icons has its own row in the left column below the icon alignment, inside the panel.
do
	assert(hideIcons and hideIcons.point[4] == 12, "Hide Icons is not in the left column")
	assert(hideIcons.point[5] < iconAlign.point[5] - 38, "Hide Icons is not below the icon alignment")
end

-- Rule: the icon buttons of the panel carry the flat symbols.
do
	for symbol, button in pairs({ Delete = deleteButton, Settings = renameButton, Font = fontButton }) do
		assert(button:GetNormalTexture().texturePath:match("Flat" .. symbol .. "$"), symbol .. " has another symbol")
	end
end

-- Rule: the two built-in pet areas offer independent merge checkboxes.
do
	-- Given both pet areas in the current profile.
	local previous = Profiles.currentProfile.scrollAreas
	previous.OutgoingPet = { name = "Outgoing Pet" }
	previous.IncomingPet = { name = "Incoming Pet" }
	Animations.UpdateScrollAreas()
	ClickEntry("scrollAreas")

	-- When the outgoing option is enabled and then the incoming area is selected.
	local outgoingBox = Box("OutgoingPet")
	outgoingBox.scripts.OnMouseDown(outgoingBox, "LeftButton")
	local merge = Control("Merge into Outgoing", 12)
	assert(merge and merge.shown and not merge:GetChecked())
	ClickCheckbox(merge, true)
	local incomingBox = Box("IncomingPet")
	incomingBox.scripts.OnMouseDown(incomingBox, "LeftButton")

	-- Then the incoming option is independent, and player areas hide the control.
	assert(merge.fontString:GetText() == "Merge into Incoming" and not merge:GetChecked())
	assert(previous.OutgoingPet.mergeWhenDisabled and not previous.IncomingPet.mergeWhenDisabled)
	ClickRow("Incoming")
	assert(not merge.shown)

	-- When Classic opens the same profile and the outgoing merge is unchecked.
	Window.Hide()
	local main = MSBTOptions.Main
	local panel = CreateFrame("Frame")
	for _, tab in ipairs(main.GetTabs()) do
		if tab.text == L.TABS.scrollAreas.label then
			main.DockMainFrame(panel, Noop, tab.index)
			break
		end
	end
	local classicRow = Find(MSBTMainOptionsFrame, function(region)
		return region.mergeCheckbox and region.scrollAreaKey == "OutgoingPet"
	end)
	assert(classicRow.mergeCheckbox.shown and classicRow.mergeCheckbox:GetChecked())
	ClickCheckbox(classicRow.mergeCheckbox, false)

	-- Then Classic saves to the same per-area setting.
	assert(not previous.OutgoingPet.mergeWhenDisabled)
	main.UndockMainFrame(panel)
end

print("Options areas tests passed")
