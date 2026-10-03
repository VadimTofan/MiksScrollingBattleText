-- Describe: popup presentation leaves editing and save behavior intact.
local frames, popups = {}, {}
local function Noop() end
local function NewFrame(parent, template)
	local frame = {
		parent = parent, template = template, scripts = {}, points = {},
		text = "", width = 100, height = 24, enabled = true,
		items = {}, textures = {}, children = {},
	}
	setmetatable(frame, { __index = function(_, key)
		if key:match("^[A-Z]") then return Noop end
	end })
	function frame:SetScript(event, handler) self.scripts[event] = handler end
	function frame:SetPoint(...) self.points[#self.points + 1] = {...} end
	function frame:ClearAllPoints() self.points = {} end
	function frame:SetParent(value) self.parent = value end
	function frame:GetParent() return self.parent end
	function frame:SetFrameStrata(value) self.strata = value end
	function frame:GetFrameStrata() return self.strata or "DIALOG" end
	function frame:SetFrameLevel(value) self.level = value end
	function frame:GetFrameLevel() return self.level or 0 end
	function frame:SetWidth(value) self.width = value end
	function frame:SetHeight(value) self.height = value end
	function frame:SetSize(w, h) self.width, self.height = w, h end
	function frame:GetWidth() return self.width end
	function frame:GetHeight() return self.height end
	function frame:SetText(value)
		self.text = value or ""
		if self.textChangedHandler then self.textChangedHandler(self) end
	end
	function frame:GetText() return self.text end
	function frame:SetTexture(value) self.texture = value end
	function frame:CreateTexture()
		local texture = NewFrame(self)
		self.textures[#self.textures + 1] = texture
		return texture
	end
	function frame:CreateFontString(_, _, font)
		local text = NewFrame(self)
		text.font = font
		return text
	end
	function frame:Configure(size, label)
		self.width, self.label = size, label
	end
	function frame:SetLabel(value) self.label = value end
	function frame:SetTextChangedHandler(value) self.textChangedHandler = value end
	function frame:SetClickHandler(value) self.clickHandler = value end
	function frame:SetEnterHandler(value) self.enterHandler = value end
	function frame:SetEscapeHandler(value) self.escapeHandler = value end
	function frame:Enable() self.enabled = true end
	function frame:Disable() self.enabled = false end
	function frame:IsEnabled() return self.enabled and 1 or 0 end
	function frame:SetChecked(value) self.checked = value end
	function frame:GetChecked() return self.checked end
	function frame:SetSelectedID(value) self.selected = value end
	function frame:GetSelectedID() return self.selected end
	function frame:AddItem(value) self.items[#self.items + 1] = value end
	function frame:Clear() self.items = {} end
	function frame:SetValue(value) self.value = value end
	function frame:GetValue() return self.value end
	function frame:SetColor(r, g, b) self.r, self.g, self.b = r, g, b end
	function frame:GetNormalTexture() return self end
	function frame:GetStringWidth() return #self.text * 6 end
	function frame:GetCenter() return 0, 0 end
	function frame:SetScrollChild(value) self.scrollChild = value end
	function frame:Show()
		self.shown = true
		if self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function frame:Hide()
		local shown = self.shown
		self.shown = false
		if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
	end
	if parent then parent.children[#parent.children + 1] = frame end
	frames[#frames + 1] = frame
	return frame
end
function CreateFrame(_, _, parent, template)
	return NewFrame(parent, template)
end
UIParent = NewFrame()
UIParent:SetFrameLevel(50)
PlaySound, FillLocalizedClassList = Noop, Noop
YES, NO = "Yes", "No"
SAVE, CANCEL, OKAY = "Save", "Cancel", "Okay"
MikSBT = {
	translations = {}, Compatibility = { Client = {} },
	Media = { fonts = { Default = "Fonts\\FRIZQT__.TTF" } },
	Main = { damageColorProfileEntries = {}, damageTypeMap = {} },
	Animations = { scrollAreas = { Incoming = { name = "Incoming" } } },
	Profiles = { currentProfile = {} },
	EraseTable = function(t) for k in pairs(t) do t[k] = nil end end,
}
dofile("MSBTOptions/Localization/localization.lua")
MSBTOptions.Main = { RegisterPopupFrame = function(frame)
	popups[#popups + 1] = frame
end }
MSBTOptions.Controls = {}
for _, name in ipairs({ "Editbox", "OptionButton", "Checkbox", "Slider",
	"Dropdown", "Colorswatch", "Listbox", "IconButton" }) do
	MSBTOptions.Controls["Create" .. name] = NewFrame
end
dofile("MSBTOptions/MSBTOptionsPopups.lua")
local P = MSBTOptions.Popups
local function CheckWindow(frame, parent)
	assert(frame:GetFrameStrata() == "FULLSCREEN_DIALOG",
		"popup must use the same layer as import/export")
	assert(frame:GetFrameLevel() == parent:GetFrameLevel() + 3,
		"popup must remain above its current parent")
	assert(frame.titleFontString and frame.titleFontString.font == "GameFontNormal",
		"popup needs a menu-style gold header")
	assert(frame.headerCloseButton, "popup needs a header close button")
	assert(#frame.textures >= 7, "popup must use character-panel artwork")
end
local function Config(parent)
	return { parentFrame = parent or UIParent, anchorFrame = UIParent }
end
local function Click(frame, label)
	for _, child in ipairs(frame.children) do
		if child.label == label and child.clickHandler then
			child.clickHandler(child)
			return
		end
	end
	error("Missing button: " .. label)
end

-- Given a validated input dialog with two fields.
local saves, hides = 0, 0
local config = Config()
config.title = "Add Sound"
config.editboxLabel, config.secondEditboxLabel = "Name", "Path"
config.showSecondEditbox = true
config.validateHandler = function(name)
	if name == "" then return "Enter a name" end
end
config.saveHandler = function(result)
	assert(result.inputText == "Test")
	assert(result.secondInputText == "test.ogg")
	saves = saves + 1
end
config.hideHandler = function() hides = hides + 1 end

-- When input is opened, validated, and saved.
P.ShowInput(config)
local input = popups[#popups]
CheckWindow(input, UIParent)
assert(input.titleFontString:GetText() == "Add Sound")
assert(input.inputEditbox.points[1][5] <= -78,
	"input must start below the menu icon")
input.inputEditbox:SetText("")
assert(not input.okayButton.enabled)
input.inputEditbox.enterHandler()
assert(saves == 0 and input.shown)
input.inputEditbox:SetText("Test")
input.secondInputEditbox:SetText("test.ogg")
input.okayButton.clickHandler()

-- Then only valid input is saved and closing still releases controls.
assert(saves == 1 and hides == 1 and not input.shown)

-- Given the same cached input is opened above another popup.
local parent = NewFrame(UIParent)
parent:SetFrameLevel(90)
config.parentFrame, config.showSecondEditbox = parent, false
P.ShowInput(config)

-- When the header close button is clicked.
CheckWindow(input, parent)
input.headerCloseButton.scripts.OnClick(input.headerCloseButton)

-- Then cancelling does not save and the parent is released.
assert(saves == 1 and hides == 2 and not input.shown)
assert(not input.secondInputEditbox.shown)

-- Given a font editor with inherited normal settings and explicit crit values.
config = Config()
config.title = "Master Fonts"
config.inheritedNormalFontName = "Default"
config.inheritedNormalOutlineIndex = 1
config.inheritedNormalFontSize = 18
config.inheritedNormalFontAlpha = 100
config.critFontName, config.critOutlineIndex = "Default", 2
config.critFontSize, config.critFontAlpha = 24, 75
config.saveHandler = function(result)
	assert(result.normalFontName == nil and result.normalFontSize == nil)
	assert(result.critFontName == "Default" and result.critFontSize == 24)
	assert(result.critFontAlpha == 75)
	saves = saves + 1
end

-- When the font editor is saved.
P.ShowFont(config)
local font = popups[#popups]
CheckWindow(font, UIParent)
assert(font.normalFrame.points[1][5] <= -85)
Click(font, MikSBT.translations.BUTTONS.genericSave.label)

-- Then font inheritance and explicit values are preserved.
assert(saves == 2 and not font.shown)

-- Given an item list with a nested Add Item dialog.
config = Config()
config.title, config.items = "Items", { Existing = true }
P.ShowItemList(config)
local list = popups[#popups]
CheckWindow(list, UIParent)

-- When Add Item opens and is cancelled via its header.
list.addItemButton.clickHandler(list.addItemButton)
CheckWindow(input, list)
assert(not list.addItemButton.enabled)
input.headerCloseButton.scripts.OnClick(input.headerCloseButton)

-- Then list controls become usable again and items remain unchanged.
assert(list.addItemButton.enabled and config.items.Existing)

-- Given the remaining simple popup types.
config = Config()
config.title = "Scroll Area"
for school = 1, 32 do
	local key = "school" .. school
	MikSBT.Main.damageColorProfileEntries[school] = key
	MikSBT.Main.damageTypeMap[school] = "School " .. school
	MikSBT.Profiles.currentProfile[key] = {
		colorR = 1, colorG = 0.5, colorB = 0,
	}
end

-- When each popup opens.
for _, show in ipairs({ P.ShowAcknowledge, P.ShowScrollAreaSelection,
	P.ShowDamageColors }) do
	show(config)
	local frame = popups[#popups]

	-- Then it uses the same menu header and stacking as the editors.
	CheckWindow(frame, UIParent)
	if show == P.ShowDamageColors then
		for _, child in ipairs(frame.children) do
			if child.scrollChild then
				assert(child.scrollChild:GetHeight() > frame:GetHeight(),
					"all damage schools must remain reachable by scrolling")
			end
		end
	end
	frame.headerCloseButton.scripts.OnClick(frame.headerCloseButton)
	assert(not frame.shown)
end
print("Popup windows preserve menu styling and editing behavior")

-- Given the live color and partial-effect profile entries.
for name in string.gmatch("crushing glancing absorb block resist overheal " ..
	"overkill DEATHKNIGHT DRUID HUNTER MAGE MONK PALADIN PRIEST ROGUE " ..
	"SHAMAN WARLOCK WARRIOR DEMONHUNTER EVOKER", "[^%s]+") do
	MikSBT.Profiles.currentProfile[name] = {
		colorR = 1, colorG = 0.5, colorB = 0, trailer = "Test",
	}
end
function MikSBT.Profiles.SetOption(path, key, value)
	if path then
		MikSBT.Profiles.currentProfile[path] =
			MikSBT.Profiles.currentProfile[path] or {}
	end
	local target = path and MikSBT.Profiles.currentProfile[path]
		or MikSBT.Profiles.currentProfile
	target[key] = value
end

-- When their editors are opened and closed using the footer.
for _, show in ipairs({ P.ShowPartialEffects, P.ShowClassColors }) do
	show(Config())
	local frame = popups[#popups]
	CheckWindow(frame, UIParent)
	frame.colorCheckbox.clickHandler(frame.colorCheckbox, false)
	Click(frame, MikSBT.translations.PROFILE_TRANSFER.close)

	-- Then the existing live color changes are still applied.
	assert(not frame.shown)
end
assert(MikSBT.Profiles.currentProfile.partialColoringDisabled)
assert(MikSBT.Profiles.currentProfile.classColoringDisabled)

-- Given scroll-area positioning with a saved starting position.
MikSBT.Animations.animationStyles = { Straight = {} }
MikSBT.Animations.stickyAnimationStyles = { Pow = {} }
MikSBT.Animations.UpdateScrollAreas = Noop
MSBTAnimations = MikSBT.Animations
GetLocale = function() return "enUS" end
MSBTOptions.Main.ShowMainFrame = Noop
MikSBT.Profiles.currentProfile.animationSpeed = 100

-- When the preview is changed, then cancelled using the new header button.
P.ShowScrollAreaConfig()
local positioning = popups[#popups]
CheckWindow(positioning, UIParent)
positioning.previewSettings.Incoming.offsetX = 123
positioning.headerCloseButton.scripts.OnClick(positioning.headerCloseButton)

-- Then cancelling restores the original position and closes the movers.
assert(MikSBT.Profiles.currentProfile["scrollAreas.Incoming"].offsetX == 0)
assert(not positioning.shown)
assert(not positioning.moverFrames.Incoming.shown)

-- Given the event editor and its actual sound controls.
NONE = "None"
MikSBT.API = { Sounds = { NormalizeFile = function(_, file) return file end } }
MikSBT.Media.sounds = {}
MikSBT.Media.IterateSounds = function() return pairs(MikSBT.Media.sounds) end
dofile("MSBTOptions/MSBTOptionsSounds.lua")
config = Config()
config.title, config.scrollArea = "Event", "Incoming"
config.message, config.soundFile = "Message", "test.ogg"
config.showIconSkillEditbox, config.iconSkill = true, "123"
local eventSaves = 0
config.saveHandler = function(settings)
	assert(settings.message == "Message")
	assert(settings.soundFile == "test.ogg")
	assert(settings.scrollArea == "Incoming")
	assert(settings.iconSkill == "123")
	eventSaves = eventSaves + 1
end

-- When an event is edited and saved, then reopened without its icon field.
P.ShowEvent(config)
local event = popups[#popups]
CheckWindow(event, UIParent)
local iconHeight = event:GetHeight()
Click(event, MikSBT.translations.BUTTONS.genericSave.label)
config.showIconSkillEditbox = false
P.ShowEvent(config)
event.headerCloseButton.scripts.OnClick(event.headerCloseButton)

-- Then save still returns event settings and closing does not save again.
assert(eventSaves == 1)
assert(not event.controls.iconSkillEditbox.shown)
assert(event:GetHeight() < iconHeight)

-- Describe: Blizzard's color picker remains usable above raised editors.
-- Given the real colorswatch control and an open menu popup.
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
ColorPickerFrame = NewFrame(UIParent)
function ColorPickerFrame:SetupColorPickerAndShow() self:Show() end
local modern = MikSBT.Compatibility.Client
modern.hasModernAPI = true
dofile("MSBTOptions/MSBTOptionsControls.lua")
local swatch = MSBTOptions.Controls.CreateColorswatch(parent)

-- When the color picker opens from that popup.
swatch.scripts.OnClick(swatch)

-- Then it sits above the popup rather than hiding behind its artwork.
assert(ColorPickerFrame:GetFrameStrata() == "FULLSCREEN_DIALOG")
assert(ColorPickerFrame:GetFrameLevel() > swatch:GetFrameLevel(),
	"color picker must sit above the control that opened it")
assert(ColorPickerFrame.shown)

-- Given the legacy color-picker API used on Classic clients.
modern.hasModernAPI = false
dofile("MSBTOptions/MSBTOptionsControls.lua")
ColorPickerFrame:SetFrameStrata("DIALOG")
local classicSwatch = MSBTOptions.Controls.CreateColorswatch(parent)

-- When that picker opens from a popup.
classicSwatch.scripts.OnClick(classicSwatch)

-- Then the legacy picker is also visible above its owner.
assert(ColorPickerFrame:GetFrameStrata() == "FULLSCREEN_DIALOG")
assert(ColorPickerFrame:GetFrameLevel() > classicSwatch:GetFrameLevel())
