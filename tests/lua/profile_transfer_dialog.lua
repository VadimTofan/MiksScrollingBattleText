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
	function frame:HighlightText() self.highlighted = true end
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
	function frame:GetVerticalScroll() return 0 end
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
tab:Show()
local controls = tab.controls
assert(controls.exportProfileButton, "Export button is missing")
assert(controls.importProfileButton, "Import button is missing")

-- When Export is clicked.
controls.exportProfileButton.clickHandler(controls.exportProfileButton)

-- Then the complete string is selected and can be copied.
assert(popup.shown)
assert(popup.parent == tab, "popup is not above its parent tab")
assert(popup.dataEditbox:GetText() == "!MSBT:1!example")
assert(popup.dataEditbox.highlighted and popup.dataEditbox.focused)
assert(controls.importProfileButton.enabled == false)
popup:Hide()
assert(controls.importProfileButton.enabled == true)
assert(popup.exportText == nil, "hidden popup retains the export string")
assert(popup.dataEditbox:GetText() == "", "hidden popup retains export text")

-- When Import opens and invalid data is submitted.
controls.importProfileButton.clickHandler(controls.importProfileButton)
popup.nameEditbox:SetText("Imported")
popup.dataEditbox:SetText("bad input")
popup.actionButton.clickHandler(popup.actionButton)

-- Then the dialog remains open, displays the error, and preserves input.
assert(popup.shown)
assert(popup.dataEditbox:GetText() == "bad input")
assert(popup.statusText:GetText() ~= "")
assert(MikSBT.Profiles.currentProfile == profile)

-- When valid data is pasted and submitted.
popup.dataEditbox:SetText("!MSBT:1!valid")
popup.actionButton.clickHandler(popup.actionButton)

-- Then the popup closes and the Profile dropdown selects the imported profile.
assert(not popup.shown)
assert(importCalls == 2)
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

print("Profile transfer dialog tests passed")
