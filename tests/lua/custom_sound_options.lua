-- Given the real sound modules and a minimal UI host.
dofile("tests/lua/custom_sounds.lua")
PlaySoundFile = function() return true end
MikSBT.EraseTable = function(t) for k in pairs(t) do t[k] = nil end end
MikSBT.Animations = { scrollAreas = { Outgoing = { name = "Outgoing" } } }
MikSBT.Triggers = {}
MikSBT.Profiles.currentProfile = { events = {}, soundsDisabled = false }
MikSBT.Profiles.IsModDisabled = function() return false end
MikSBT.Profiles.SetOption = function(path, key, value)
	local target = MikSBT.Profiles.currentProfile
	if path then
		for part in path:gmatch("[^.]+") do
			target[part] = target[part] or {}
			target = target[part]
		end
	end
	target[key] = value
end
local messages = {}
MikSBT.Print = function(message) messages[#messages + 1] = message end
MikSBT.Profiles.savedMedia.sounds = {}
WOW_PROJECT_ID, WOW_PROJECT_CLASSIC, WOW_PROJECT_CATACLYSM_CLASSIC = 1, 2, 5
NONE = "None"
LocalizedClassList = function() return {} end
GetLocale = function() return "enUS" end
PlaySound = function() end
dofile("MSBTOptions/Localization/localization.lua")

local widgets = {}
local Widget = {}
Widget.__index = Widget
local function NewWidget(parent)
	local widget = setmetatable({ parent = parent, scripts = {}, items = {} }, Widget)
	widgets[#widgets + 1] = widget
	return widget
end
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "EnableMouse", "SetMovable",
	"RegisterForDrag", "SetFrameStrata", "SetClampedToScreen", "SetBackdrop",
	"Raise", "SetAlpha", "SetTooltip", "SetFocus", "Sort", "SetMinMaxValues",
	"SetValueStep", "SetLabel", "SetEscapeHandler", "SetEnterHandler",
	"SetTextChangedHandler", "SetValueChangedHandler" }) do
	Widget[name] = function() end
end
function Widget:SetScript(name, handler) self.scripts[name] = handler end
function Widget:Show()
	self.shown = true
	if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Widget:Hide()
	local wasShown = self.shown
	self.shown = false
	if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Widget:SetParent(parent) self.parent = parent end
function Widget:GetParent() return self.parent end
function Widget:SetWidth(value) self.width = value end
function Widget:SetHeight(value) self.height = value end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:SetChecked(value) self.checked = value end
function Widget:GetChecked() return self.checked end
function Widget:SetValue(value) self.value = value end
function Widget:Configure(_, label) self.label = label end
function Widget:SetClickHandler(handler) self.clickHandler = handler end
function Widget:Clear() self.items = {} end
function Widget:AddItem(label, id) self.items[id] = label end
function Widget:SetSelectedID(id) self.selected = id end
function Widget:GetSelectedID() return self.selected end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:IsEnabled() return self.enabled ~= false end
Widget.CreateFontString = NewWidget
CreateFrame = function(_, _, parent) return NewWidget(parent) end
local tabs = {}
MSBTOptions = { Controls = {}, Main = {
	RegisterPopupFrame = function() end,
	AddTab = function(frame, label) tabs[label] = frame end,
} }
for _, name in ipairs({ "CreateDropdown", "CreateOptionButton", "CreateIconButton",
	"CreateCheckbox", "CreateEditbox", "CreateSlider" }) do
	MSBTOptions.Controls[name] = NewWidget
end
dofile("MSBTOptions/MSBTOptionsPopups.lua")
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/MSBTOptionsTabs.lua")

-- When General is opened and Enable Sounds is toggled.
local general = tabs[MikSBT.translations.TABS.general.label]
general:Show()
local controls = general.controls
assert(controls.enableSoundsCheckbox, "General sound toggle is missing")
controls.enableSoundsCheckbox.clickHandler(controls.enableSoundsCheckbox, false)
-- Then the profile is muted and reopening shows the persisted choice.
assert(MikSBT.Profiles.currentProfile.soundsDisabled)
general:Show()
assert(controls.enableSoundsCheckbox.checked == false)

-- When Add Sound is opened, validated and saved.
controls.addCustomSoundButton.clickHandler(controls.addCustomSoundButton)
local input
for _, widget in ipairs(widgets) do
	if widget.inputEditbox then input = widget end
end
assert(input and input.shown, "custom sound input was not opened")
assert(input.validateHandler("", "valid.ogg"))
assert(input.validateHandler("Bell", "valid.ogg"))
assert(input.validateHandler("New Bell", "bad.txt"))
assert(not input.validateHandler("New Bell", "Interface/AddOns/MySounds/new.ogg"))
input.inputEditbox:SetText("New Bell")
input.secondInputEditbox:SetText("Interface/AddOns/MySounds/new.ogg")
input.okayButton.clickHandler(input.okayButton)
-- Then registration is persistent and controls become usable again.
assert(MikSBT.Profiles.savedMedia.sounds["New Bell"] ==
	"Interface\\AddOns\\MySounds\\new.ogg")
assert(controls.addCustomSoundButton.enabled)

-- Given an event popup using the original saved sound name.
local saved
local config = { parentFrame = general, anchorFrame = general,
	message = "%a", scrollArea = "Outgoing", soundFile = "Bell",
	saveHandler = function(settings) saved = settings.soundFile end,
}
MSBTOptions.Popups.ShowEvent(config)
local eventFrame
for _, widget in ipairs(widgets) do
	if widget.controls and widget.controls.messageEditbox then eventFrame = widget end
end
assert(eventFrame and eventFrame.controls.soundDropdown, "event selector is missing")
local eventControls = eventFrame.controls
assert(eventControls.soundDropdown:GetSelectedID() == "Bell")
assert(eventControls.soundDropdown.items["New Bell"])

-- When previewing while the automatic sound toggle is off.
local plays = 0
PlaySoundFile = function() plays = plays + 1; return false end
eventControls.playSoundButton.clickHandler(eventControls.playSoundButton)
-- Then preview still calls the API and reports a failed file.
assert(plays == 1 and #messages > 0)

-- When saving a different sound and reopening.
eventControls.soundDropdown:SetSelectedID("New Bell")
for _, widget in pairs(eventControls) do
	if widget.label == MikSBT.translations.BUTTONS.genericSave.label then
		widget.clickHandler(widget)
	end
end
assert(saved == "New Bell", "event save lost the selected sound")
config.soundFile = saved
MSBTOptions.Popups.ShowEvent(config)
assert(eventControls.soundDropdown:GetSelectedID() == "New Bell")

-- When selecting None and saving.
eventControls.soundDropdown:SetSelectedID("")
for _, widget in pairs(eventControls) do
	if widget.label == MikSBT.translations.BUTTONS.genericSave.label then
		widget.clickHandler(widget)
	end
end
-- Then the empty string explicitly clears the old profile selection.
assert(saved == "")

-- Given a legacy direct path that is not in shared media.
config.soundFile = "legacy.ogg"
-- When reopening its event configuration.
MSBTOptions.Popups.ShowEvent(config)
-- Then the existing assignment remains selectable.
assert(eventControls.soundDropdown:GetSelectedID() == "legacy.ogg")
assert(eventControls.soundDropdown.items["legacy.ogg"])

-- Given an existing assignment and a nested custom-file dialog.
eventControls.customSoundButton.clickHandler(eventControls.customSoundButton)
assert(input.shown and not eventControls.soundDropdown.enabled)

-- When cancelling that dialog without choosing a file.
input:Hide()

-- Then the selection is untouched and the event controls are usable again.
assert(eventControls.soundDropdown:GetSelectedID() == "legacy.ogg")
assert(eventControls.soundDropdown.enabled)

-- Given a valid custom file that has no registered media name.
eventControls.customSoundButton.clickHandler(eventControls.customSoundButton)
local directPath = "Interface/AddOns/MySounds/direct.mp3"
assert(not input.validateHandler(directPath))
assert(input.validateHandler("not a sound"))

-- When saving the file input and previewing the resulting selection.
input.inputEditbox:SetText(directPath)
input.okayButton.clickHandler(input.okayButton)
local previewed
PlaySoundFile = function(file) previewed = file; return true end
eventControls.playSoundButton.clickHandler(eventControls.playSoundButton)

-- Then the selected path plays without changing the saved event yet.
local normalizedPath = "Interface\\AddOns\\MySounds\\direct.mp3"
assert(eventControls.soundDropdown:GetSelectedID() == normalizedPath)
assert(previewed == normalizedPath)
assert(saved == "")

-- When the event itself is cancelled and reopened with its saved setting.
for _, widget in pairs(eventControls) do
	if widget.label == MikSBT.translations.BUTTONS.genericCancel.label then
		widget.clickHandler(widget)
	end
end
MSBTOptions.Popups.ShowEvent(config)

-- Then the unsaved custom file has not replaced the original assignment.
assert(eventControls.soundDropdown:GetSelectedID() == "legacy.ogg")

-- Given the registration dialog with an unsaved name and path.
controls.addCustomSoundButton.clickHandler(controls.addCustomSoundButton)
input.inputEditbox:SetText("Cancelled Bell")
input.secondInputEditbox:SetText("cancelled.ogg")

-- When cancelling Add Sound.
input:Hide()

-- Then neither shared media nor saved registrations contain the draft.
assert(not MikSBT.Media.sounds["Cancelled Bell"])
assert(not MikSBT.Profiles.savedMedia.sounds["Cancelled Bell"])
assert(controls.addCustomSoundButton.enabled)
