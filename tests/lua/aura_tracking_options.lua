-- Describe: the real aura panel stores explicit checkbox states per profile.
local function Noop() end
local function Frame(parent)
	local frame = {
		items = {}, lines = {}, scripts = {}, created = false, parent = parent, auraID = false,
	}
	setmetatable(frame, { __index = function() return Noop end })
	function frame:SetText(value) self.text = value end
	function frame:SetWidth(value) self.width = value end
	function frame:SetHeight(value) self.height = value end
	function frame:GetHeight() return self.height end
	function frame:SetPoint(...) self.point = {...} end
	function frame:GetParent() return self.parent end
	function frame:SetLabel(value) self.text, self.fontString = value, self end
	function frame:SetColor(r, g, b) self.r, self.g, self.b = r, g, b end
	function frame:SetVertexColor(r, g, b)
		assert(type(r) == "number" and type(g) == "number"
			and type(b) == "number", "SetVertexColor requires numeric RGB")
		self.vertexColor = {r, g, b}
	end
	function frame:SetColorChangedHandler(handler) self.colorChanged = handler end
	function frame:SetFontString(value) self.fontString = value end
	function frame:GetFontString() return self.fontString end
	function frame:GetStringWidth() return #(rawget(self, "text") or "") * 6 end
	function frame:GetNormalTexture() return self end
	function frame:GetPushedTexture() return self end
	function frame:GetDisabledTexture() return self end
	function frame:GetHighlightTexture() return self end
	function frame:GetText() return self.text or "" end
	function frame:Show() self.visible = true end
	function frame:Hide() self.visible = false end
	function frame:Enable() self.enabled = true end
	function frame:Disable() self.enabled = false end
	function frame:CreateFontString() return Frame() end
	function frame:CreateTexture() return Frame() end
	function frame:Configure(width, height, rowHeight)
		self.width, self.height, self.rowHeight = width, height, rowHeight
	end
	function frame:SetClickHandler(handler)
		self.click, self.clickHandler = handler, handler
	end
	function frame:SetScript(event, handler)
		self.scripts = self.scripts or {}
		self.scripts[event] = handler
	end
	function frame:SetChangeHandler(handler) self.change = handler end
	function frame:SetSelectedID(id) self.selected = id end
	function frame:GetSelectedID() return self.selected end
	function frame:GetSelectedText() return "Notification" end
	function frame:SetEnterHandler(handler) self.enter = handler end
	function frame:SetCreateLineHandler(handler) self.createLine = handler end
	function frame:SetDisplayHandler(handler) self.displayLine = handler end
	function frame:SetChecked(value) self.checked = value end
	function frame:Clear() self.items, self.lines = {}, {} end
	function frame:AddItem(key)
		self.items[#self.items + 1] = key
		local line = self:createLine()
		self.lines[#self.lines + 1] = line
		self:displayLine(line, key, false)
	end
	function frame:Refresh()
		for index, key in ipairs(self.items) do
			self:displayLine(self.lines[index], key, false)
		end
	end
	return frame
end
CreateFrame = function(_, _, parent) return Frame(parent) end
MikSBT = { Configuration = {}, API = {}, translations = {} }
dofile("API/RestrictedValue.lua")
C_Spell = { GetSpellInfo = function(id)
	id = tonumber(id)
	if id == 1459 or id == 17 then
		return { name = "Aura " .. id, spellID = id, iconID = id }
	end
end }
dofile("API/Spells.lua")
dofile("Configuration/AuraTracking.lua")
local messages = {}
MikSBT.Print = function(value) messages[#messages + 1] = value end
MikSBT.Profiles = {
	currentProfile = { auraTracking = {} },
	SetOption = function(path, key, value)
		assert(path == nil and (key == "auraTracking" or key == "auraSettings"))
		MikSBT.Profiles.currentProfile[key] = value
	end,
}
MSBTOptions = { Controls = {
	CreateListbox = Frame, CreateCheckbox = Frame,
	CreateEditbox = Frame, CreateOptionButton = Frame,
	CreateIconButton = Frame,
} }
dofile("MSBTOptions/Localization/localization.lua")
-- Use the real button helper: Configure takes height, unlike other controls.
MikSBT.Compatibility = { Client = {} }
dofile("MSBTOptions/MSBTOptionsControls.lua")
local CreateOptionButton = MSBTOptions.Controls.CreateOptionButton
local CreateColorswatch = MSBTOptions.Controls.CreateColorswatch
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }

-- Given a real swatch for a row that has not been displayed yet.
local unusedSwatch = CreateColorswatch(Frame())
-- When closing a popup enables all cached event-row controls.
unusedSwatch:Disable()
unusedSwatch:Enable()
-- Then even unused/hidden swatches have valid colors for the native API.
assert(unusedSwatch.r == 1 and unusedSwatch.g == 1 and unusedSwatch.b == 1)

-- Given a swatch that has already displayed a configured event color.
unusedSwatch:SetColor(0.2, 0.4, 0.6)
-- When another popup disables and enables it.
unusedSwatch:Disable()
unusedSwatch:Enable()
-- Then enabling preserves that configured color.
assert(unusedSwatch.vertexColor[1] == 0.2)
assert(unusedSwatch.vertexColor[2] == 0.4)
assert(unusedSwatch.vertexColor[3] == 0.6)
MSBTOptions.Controls = {
	CreateListbox = Frame, CreateCheckbox = Frame,
	CreateEditbox = Frame, CreateOptionButton = CreateOptionButton,
	CreateIconButton = Frame,
	CreateColorswatch = CreateColorswatch,
}
dofile("MSBTOptions/MSBTOptionsAuras.lua")

-- Given the real Events tab and its built-in notification rows.
local tabs = {}
MikSBT.Media = { fonts = { Default = "default.ttf", Custom = "custom.ttf" } }
MikSBT.Animations = {}
MikSBT.Compatibility = { Client = { isClassicContent = false } }
MikSBT.EraseTable = function(value)
    for key in pairs(value) do value[key] = nil end
end
MikSBT.Profiles.currentProfile.events = setmetatable({}, {
    __index = function() return {
        message = "%sl", scrollArea = "Notification", colorG = 0.6,
    } end,
})
MikSBT.Profiles.currentProfile.scrollAreas = { Notification = {
    normalFontName = "Default", normalFontSize = 20, normalFontAlpha = 100,
    normalOutlineIndex = 1,
} }
MikSBT.Profiles.currentProfile.events.NOTIFICATION_BUFF = {
    message = "%sl", scrollArea = "Notification", colorG = 0.6,
    fontName = "Default",
}
MSBTOptions.Main = { AddTab = function(frame, label) tabs[label] = frame end }
local eventPopup, fontPopup
MSBTOptions.Popups = {
    DisableControls = function(controls)
        for _, control in pairs(controls) do
            if control.Disable then control:Disable() end
        end
    end,
    ShowEvent = function(config) eventPopup = config end,
    ShowFont = function(config) fontPopup = config end,
}
MSBTOptions.Controls.CreateDropdown = Frame
PET = "Pet"
dofile("MSBTOptions/MSBTOptionsTabs.lua")
local events = tabs[MikSBT.translations.TABS.events.label]
events.scripts.OnShow()
local controls = events.controls
controls.eventCategoryDropdown:SetSelectedID("NOTIFICATION_EVENTS")
controls.eventCategoryDropdown:change("NOTIFICATION_EVENTS")
local panel, list = controls.auraPanel, controls.eventsListbox
local builtinCount = #list.items

-- When a user adds a specific aura to hide it.
panel.input:SetText("1459")
panel.add.clickHandler(panel.add)
-- Then it is the first row of the existing list, before built-in events.
assert(list.items[1] == "1459", "custom aura was not prepended")
assert(#list.items == builtinCount + 1)
assert(type(list.items[2]) == "number")
assert(rawget(panel, "list") == nil, "a separate aura list must not be created")
assert(list.lines[1].auraLine.checkbox.checked == false)
assert(panel.input:GetText() == "")
assert(panel.add:GetHeight() == 20, "Add aura button is oversized")

-- Given a second aura entered after the first.
panel.input:SetText("17")
-- When it is added.
panel.add.clickHandler(panel.add)
-- Then the new entry goes to the top and existing custom rows remain.
assert(list.items[1] == "17" and list.items[2] == "1459")
assert(#list.items == builtinCount + 2)

-- Given a custom aura in the same list as built-in events.
local custom = list.lines[1].auraLine
-- When the user changes its color and opens its settings dialog.
assert(custom.colorSwatch and custom.settingsButton and custom.fontButton,
    "custom aura is missing standard style controls")
custom.colorSwatch:SetColor(0.3, 0.6, 0.9)
custom.colorSwatch.colorChangedHandler(custom.colorSwatch)
custom.settingsButton:click()
-- Then the popup starts with inherited values and saves per-aura overrides.
assert(eventPopup.message == "%sl" and eventPopup.scrollArea == "Notification")
eventPopup.saveHandler({ message = "My %sl", scrollArea = "My auras",
    soundFile = 123456, alwaysSticky = true }, eventPopup.saveArg1)
eventPopup.hideHandler()
local overrides = MikSBT.Profiles.currentProfile.auraSettings["17"]
assert(overrides.colorR == 0.3 and overrides.colorB == 0.9)
assert(overrides.colorG == nil, "unchanged inherited color was frozen")
assert(overrides.message == "My %sl" and overrides.scrollArea == "My auras")
assert(overrides.soundFile == 123456 and overrides.alwaysSticky)
assert(MikSBT.Profiles.currentProfile.events.NOTIFICATION_BUFF.message == "%sl")

-- When the font dialog saves a font, size, opacity and outline.
custom.fontButton:click()
assert(fontPopup.normalFontName == nil)
assert(fontPopup.inheritedNormalFontName == "Default")
fontPopup.saveHandler({ normalFontName = "Custom", normalFontSize = 28,
    normalFontAlpha = 80, normalOutlineIndex = 3 }, fontPopup.saveArg1)
fontPopup.hideHandler()
overrides = MikSBT.Profiles.currentProfile.auraSettings["17"]
-- Then all four settings belong only to the custom aura.
assert(overrides.fontName == "Custom" and overrides.fontSize == 28)
assert(overrides.fontAlpha == 80 and overrides.outlineIndex == 3)

-- When font inheritance is restored in the same popup.
custom.fontButton:click()
fontPopup.saveHandler({}, fontPopup.saveArg1)
fontPopup.hideHandler()
assert(MikSBT.Profiles.currentProfile.auraSettings["17"].fontName == nil)

-- Given the first aura row.
-- When its checkbox is ticked, then unticked.
list.lines[1].auraLine.checkbox:click(true)
assert(MikSBT.Profiles.currentProfile.auraTracking["17"] == true)
list.lines[1].auraLine.checkbox:click(false)
-- Then the explicit unchecked state persists.
assert(MikSBT.Profiles.currentProfile.auraTracking["17"] == false)

-- Given invalid input and an already listed aura.
-- When Add is clicked for each.
panel.input:SetText("unknown")
panel.add.clickHandler(panel.add)
panel.input:SetText("17")
panel.add.clickHandler(panel.add)
-- Then invalid input reports an error and no duplicate row appears.
assert(#messages == 1 and #list.items == builtinCount + 2)

-- Given the top row's remove button.
-- When the aura is removed.
list.lines[1].auraLine.remove:click()
-- Then only that rule disappears and the other custom row stays on top.
assert(MikSBT.Profiles.currentProfile.auraTracking["17"] == nil)
assert(MikSBT.Profiles.currentProfile.auraSettings["17"] == nil)
assert(list.items[1] == "1459" and #list.items == builtinCount + 1)

-- Given a profile switch while Events is selected.
MikSBT.Profiles.currentProfile = {
    auraTracking = { ["17"] = true },
    events = MikSBT.Profiles.currentProfile.events,
}
-- When the tab refreshes.
events.scripts.OnShow()
-- Then its custom rows and states replace those from the previous profile.
assert(list.items[1] == "17" and #list.items == builtinCount + 1)
assert(list.lines[1].auraLine.checkbox.checked == true)

-- Given a row frame reused as the user scrolls the mixed list.
local recycled = list.lines[1]
-- When it changes from a custom aura to a built-in notification and back.
list:displayLine(recycled, 1, false)
assert(not recycled.auraLine.visible and recycled.colorSwatch.visible)
list:displayLine(recycled, "17", false)
-- Then only the controls belonging to the current row type are visible.
assert(recycled.auraLine.visible and not recycled.colorSwatch.visible)
assert(not recycled.settingsButton.visible)
assert(recycled.auraLine.checkbox.checked)

-- When another event category is selected.
controls.eventCategoryDropdown:SetSelectedID("INCOMING_PLAYER_EVENTS")
controls.eventCategoryDropdown:change("INCOMING_PLAYER_EVENTS")
-- Then aura rows and the Add controls are absent from that category.
assert(list.height == 300 and not panel.visible)
for _, key in ipairs(list.items) do assert(type(key) == "number") end
assert(not list.lines[1].auraLine.visible)
assert(list.lines[1].colorSwatch.visible)
print("Aura tracking options tests passed")

-- Describe: pet settings are grouped under Outgoing Pet.
-- Given the Events menu with player and pet outgoing event settings.
-- When the user selects Events > Outgoing.
controls.eventCategoryDropdown:SetSelectedID("OUTGOING_PLAYER_EVENTS")
controls.eventCategoryDropdown:change("OUTGOING_PLAYER_EVENTS")
-- Then player events remain and every pet event is absent.
local outgoingRows = {}
for _, line in ipairs(list.lines) do
    assert(not line.eventType:match("^PET_"), "pet event remains in Outgoing")
    outgoingRows[line.eventType] = true
end
assert(outgoingRows.OUTGOING_DAMAGE, "player damage must remain available")
assert(outgoingRows.OUTGOING_HEAL, "player healing must remain available")

-- Given the localized outgoing pet events and their existing settings.
local petEvents = MikSBT.translations.OUTGOING_PET_EVENTS
-- When the user selects Events > Outgoing Pet.
controls.eventCategoryDropdown:SetSelectedID("OUTGOING_PET_EVENTS")
controls.eventCategoryDropdown:change("OUTGOING_PET_EVENTS")
local petRows = {}
for _, line in ipairs(list.lines) do petRows[line.eventType] = line end
-- Then every pet event has its own settings row in that category.
for eventType, locale in pairs(petEvents) do
    local line = petRows[eventType]
    assert(line, eventType .. " is missing from Outgoing Pet")
    assert(line.enableCheckbox.text == locale.label)
    line.settingsButton:click()
    assert(eventPopup.saveArg1 == eventType)
    assert(eventPopup.scrollArea == "Notification")
end
