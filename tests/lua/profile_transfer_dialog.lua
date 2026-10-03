-- Describe: copy/paste dialogs keep errors visible and apply valid profiles.
local frames = {}
local popup
local function Noop() end
local function NewFrame(parent)
	local frame = { parent = parent, scripts = {}, text = "", shown = false }
	setmetatable(frame, {
		__index = function(_, key)
			if key:match("^[A-Z]") then return Noop end
		end,
	})
	function frame:SetScript(event, handler) self.scripts[event] = handler end
	function frame:SetText(text)
		self.text = text or ""
		if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
	end
	function frame:GetText() return self.text end
	function frame:SetFocus() self.focused = true end
	function frame:ClearFocus() self.focused = false end
	function frame:HighlightText()
		self.highlighted = true
		if self.scripts.OnCursorChanged then
			self.scripts.OnCursorChanged(self, 0, -400, 0, 14)
		end
	end
	function frame:Show()
		self.shown = true
		if self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function frame:Hide()
		local wasShown = self.shown
		self.shown = false
		if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
	end
	function frame:CreateFontString() return NewFrame(self) end
	function frame:CreateTexture() return NewFrame(self) end
	function frame:Configure(_, label) self.label = label end
	function frame:SetClickHandler(handler) self.clickHandler = handler end
	function frame:SetEscapeHandler(handler) self.escapeHandler = handler end
	function frame:SetEnterHandler(handler) self.enterHandler = handler end
	function frame:SetLabel(label) self.label = label end
	function frame:SetTooltip() end
	function frame:GetParent() return self.parent end
	function frame:SetParent(parent) self.parent = parent end
	function frame:ClearAllPoints()
		self.point = nil
		self.points = {}
	end
	function frame:SetPoint(...)
		self.point = { ... }
		self.points = self.points or {}
		self.points[#self.points + 1] = self.point
	end
	function frame:SetFrameStrata(strata) self.strata = strata end
	function frame:GetFrameStrata() return self.strata or "DIALOG" end
	function frame:SetFrameLevel(level) self.level = level end
	function frame:GetFrameLevel() return self.level or 0 end
	function frame:SetVerticalScroll(offset) self.scrollOffset = offset end
	function frame:GetVerticalScroll() return self.scrollOffset or 0 end
	function frame:GetHeight() return 220 end
	function frame:SetTextChangedHandler(handler) self.textChangedHandler = handler end
	function frame:AddItem(id, label) self.items[id] = label end
	function frame:GetSelectedID() return self.selected end
	function frame:SetSelectedID(id) self.selected = id end
	function frame:Enable() self.enabled = true end
	function frame:Disable() self.enabled = false end
	frames[#frames + 1] = frame
	return frame
end
function CreateFrame(_, _, parent) return NewFrame(parent) end
PlaySound = Noop
FillLocalizedClassList = Noop
local profile = { normalFontSize = 18 }
local importedProfile = { normalFontSize = 22 }
local importCalls = 0
local messages = {}
MikSBT = {
	translations = {}, Compatibility = { Client = {} },
	EraseTable = function(value) for key in pairs(value) do value[key] = nil end end,
	Print = function(message) messages[#messages + 1] = message end,
	Media = { fonts = {} }, Animations = {}, Triggers = {},
	Profiles = {
		currentProfile = profile,
		savedVariables = { profiles = { Default = profile } },
		ExportProfile = function(name)
			assert(name == "Default")
			return "!MSBT:1!example"
		end,
		ImportProfile = function(text, name)
			importCalls = importCalls + 1
			if name == "" then return nil, "INVALID_NAME" end
			if text ~= "!MSBT:1!valid" then return nil, "INVALID_TEXT" end
			MikSBT.Profiles.savedVariables.profiles[name] = importedProfile
			MikSBT.Profiles.currentProfile = importedProfile
			return name, { clientMismatch = true }
		end,
	},
}
dofile("MSBTOptions/Localization/localization.lua")
local tabs = {}
MSBTOptions.Main = {
	RegisterPopupFrame = function(frame) popup = frame end,
	AddTab = function(frame, label) tabs[label] = frame end,
}
MSBTOptions.Controls = {
	CreateOptionButton = NewFrame,
	CreateEditbox = function(parent)
		local frame = NewFrame(parent)
		frame.editboxFrame = NewFrame(frame)
		function frame:SetText(text)
			self.editboxFrame:SetText(text)
			if self.textChangedHandler then self.textChangedHandler(self) end
		end
		function frame:GetText() return self.editboxFrame:GetText() end
		return frame
	end,
	CreateDropdown = function(parent)
		local frame = NewFrame(parent)
		frame.items = {}
		return frame
	end,
}
dofile("MSBTOptions/MSBTOptionsPopups.lua")
local file = io.open("MSBTOptions/MSBTOptionsProfileTransfer.lua", "r")
assert(file, "profile transfer dialog is missing")
file:close()
dofile("MSBTOptions/MSBTOptionsProfileTransfer.lua")
dofile("MSBTOptions/MSBTOptionsTabs.lua")

-- Given the opened Profile tab.
local tab = assert(tabs.Profile)
tab:SetFrameStrata("DIALOG")
tab:SetFrameLevel(52)
tab:Show()
local controls = tab.controls
assert(controls.exportProfileButton, "Export button is missing")
assert(controls.importProfileButton, "Import button is missing")

-- When Export is clicked.
controls.exportProfileButton.clickHandler(controls.exportProfileButton)

-- Then the complete string is selected and can be copied.
assert(popup.shown)
assert(popup.parent == tab, "popup is not above its parent tab")
assert(popup:GetFrameStrata() == "FULLSCREEN_DIALOG",
	"transfer dialog must use a higher layer than the options window")
assert(popup:GetFrameLevel() == tab:GetFrameLevel() + 3,
	"transfer dialog must sit three levels above its parent")
assert(popup.dataEditbox:GetText() == "!MSBT:1!example")
assert(popup.dataEditbox.highlighted and popup.dataEditbox.focused)
assert(popup.scrollFrame:GetVerticalScroll() == 0,
	"selecting the export must keep its first line visible")
assert(popup.dataLabel and popup.dataLabel:GetText() == "Profile string")
assert(-popup.instructionsText.point[3] >= 72,
	"instructions must start below the 64-pixel menu icon")
assert(-popup.dataLabel.point[3] >= -popup.instructionsText.point[3] + 32,
	"the field label must leave space for two instruction lines")
assert(-popup.dataPanel.points[1][3] >= -popup.dataLabel.point[3] + 20,
	"the text field must sit below its label")
assert(popup.dataPanel, "profile string needs a bordered input panel")
assert(popup.dataHint and not popup.dataHint.shown)
assert(not popup.nameEditbox.shown)
assert(popup.copyButton and popup.copyButton.shown,
	"export dialog must show a copy button")
assert(popup.copyButton.label == "Copy (Ctrl+C)")
assert(popup.actionButton.point[2] == popup.copyButton)
assert(popup.actionButton.point[3] == "BOTTOMLEFT")
assert(popup.closeButton.point[2] == popup.copyButton)
assert(popup.closeButton.point[3] == "BOTTOMRIGHT")

-- Given the export string has lost its keyboard focus and selection.
popup.dataEditbox:ClearFocus()
popup.dataEditbox.highlighted = false

-- When Copy is clicked.
popup.copyButton.clickHandler(popup.copyButton)

-- Then the full string is ready for Ctrl+C and the dialog stays open.
assert(popup.dataEditbox.highlighted and popup.dataEditbox.focused)
assert(popup.dataEditbox:GetText() == "!MSBT:1!example")
assert(popup.shown)
assert(controls.importProfileButton.enabled == false)
popup:Hide()
assert(controls.importProfileButton.enabled == true)
assert(popup.exportText == nil, "hidden popup retains the export string")
assert(popup.dataEditbox:GetText() == "", "hidden popup retains export text")

-- When Import opens and invalid data is submitted.
tab:SetFrameLevel(72)
controls.importProfileButton.clickHandler(controls.importProfileButton)
assert(not popup.copyButton.shown, "import must hide the export copy button")
assert(popup.actionButton.point[2] == popup)
assert(popup.closeButton.point[2] == popup)
assert(popup:GetFrameStrata() == "FULLSCREEN_DIALOG")
assert(popup:GetFrameLevel() == tab:GetFrameLevel() + 3,
	"reopening the dialog must update its level for the current parent")
assert(popup.dataLabel:GetText() == "1. Paste profile string")
assert(popup.nameEditbox.label == "2. Name your new profile")
assert(popup.instructionsText:GetText():find("creates and selects", 1, true))
assert(popup.dataHint.shown)
assert(popup.dataHint:GetText():find("Ctrl+V", 1, true))

-- When the import cursor moves below the visible part of a long paste.
popup.dataEditbox.scripts.OnCursorChanged(popup.dataEditbox, 0, -400, 0, 14)

-- Then editable import text still scrolls to keep the cursor visible.
assert(popup.scrollFrame:GetVerticalScroll() == 194)
assert(popup.nameEditbox.points[1][1] == "TOPLEFT")
assert(popup.nameEditbox.points[1][3] == "BOTTOMLEFT")
assert(popup.nameEditbox.points[1][5] == 178)

-- Given an import with no profile name yet.

-- When Import is submitted without entering a name.
popup.actionButton.clickHandler(popup.actionButton)

-- Then the name error sits below the name and clears when it is edited.
assert(popup.statusText.point[2] == popup.nameEditbox)
assert(popup.statusText:GetText() ~= "")
popup.nameEditbox:SetText("Imported")
assert(popup.statusText:GetText() == "")
popup.dataEditbox:SetText("bad input")
assert(not popup.dataHint.shown, "pasting must remove the empty-box hint")
popup.actionButton.clickHandler(popup.actionButton)

-- Then the dialog remains open, displays the error, and preserves input.
assert(popup.shown)
assert(popup.dataEditbox:GetText() == "bad input")
assert(popup.statusText:GetText() ~= "")
assert(popup.statusText.point[2] == popup.dataPanel,
	"profile string errors must appear below the string field")
assert(MikSBT.Profiles.currentProfile == profile)

-- When valid data is pasted and submitted.
popup.dataEditbox:SetText("!MSBT:1!valid")
popup.dataEditbox.scripts.OnTabPressed(popup.dataEditbox)
assert(popup.nameEditbox.editboxFrame.focused,
	"Tab from the pasted string must focus the profile name")
popup.nameEditbox.enterHandler()

-- Then the popup closes and the Profile dropdown selects the imported profile.
assert(not popup.shown)
assert(importCalls == 3)
assert(controls.profileDropdown:GetSelectedID() == "Imported")
assert(controls.profileDropdown.items.Imported == "Imported")
assert(controls.importProfileButton.enabled == true)
assert(#messages > 0, "cross-client import did not explain compatibility")
assert(popup.dataEditbox:GetText() == "", "hidden popup retains import data")
assert(popup.nameEditbox:GetText() == "", "hidden popup retains the name")

-- Given a reopened Import dialog containing unsaved text.
controls.importProfileButton.clickHandler(controls.importProfileButton)
popup.nameEditbox:SetText("Cancelled")
popup.dataEditbox:SetText(string.rep("A", 131072))

-- When the user closes it without importing.
popup:Hide()

-- Then its buffers and operation callbacks are released.
assert(popup.dataEditbox:GetText() == "")
assert(popup.nameEditbox:GetText() == "")
assert(popup.importHandler == nil and popup.successHandler == nil)
assert(popup.hideHandler == nil)

-- Given the shared dialog was last used for Import.
controls.profileDropdown:SetSelectedID("Default")

-- When Export opens again.
controls.exportProfileButton.clickHandler(controls.exportProfileButton)

-- Then the export layout and copy controls return without import hints.
assert(popup.dataLabel:GetText() == "Profile string")
assert(not popup.nameEditbox.shown and not popup.dataHint.shown)
assert(popup.copyButton.shown)
assert(popup.dataPanel.points[2][3] == 150)
assert(popup.dataEditbox:GetText() == "!MSBT:1!example")
assert(popup.dataEditbox.highlighted and popup.dataEditbox.focused)
assert(popup.scrollFrame:GetVerticalScroll() == 0,
	"reopening export must return to its first line")
popup:Hide()

print("Profile transfer dialog tests passed")
