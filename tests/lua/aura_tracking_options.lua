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
	function frame:GetSelectedID() return rawget(self, "selected") end
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
	if id == "Aura 17" then id = 17 end
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
	-- Only the player's damage event takes a second scroll area here, whatever the real rule is.
	EventTakesOtherArea = function(eventType) return eventType == "OUTGOING_DAMAGE" end,
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
local eventPopup, fontPopup, movePopup
MSBTOptions.Popups = {
    DisableControls = function(controls)
        for _, control in pairs(controls) do
            if control.Disable then control:Disable() end
        end
    end,
    ShowEvent = function(config) eventPopup = config end,
    ShowFont = function(config) fontPopup = config end,
    ShowScrollAreaSelection = function(config) movePopup = config end,
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
panel.input:SetText("99999999")
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

-- Describe: only the events that take a second scroll area offer one in their settings.
-- Given a client with the area for lines on other units, and a spy on what the tab saves.
MikSBT.Profiles.masterProfile = { scrollAreas = { OutgoingOther = {} } }
local savedOptions = {}
local savingOption = MikSBT.Profiles.SetOption
MikSBT.Profiles.SetOption = function(path, field, value, default)
    savedOptions[#savedOptions + 1] = { path, field, value, default }
end
local function Settings(eventType, category)
    controls.eventCategoryDropdown:SetSelectedID(category)
    controls.eventCategoryDropdown:change(category)
    for _, line in ipairs(list.lines) do
        if line.eventType == eventType then
            line.settingsButton:click()
            return
        end
    end
    error(eventType .. " has no row")
end
local function SavedSecondAreas()
    local saved = {}
    for _, call in ipairs(savedOptions) do
        if call[2] == "scrollAreaOther" then saved[#saved + 1] = call end
    end
    return saved
end
-- When the settings of an event that takes one are opened.
MikSBT.Profiles.currentProfile.events.OUTGOING_DAMAGE = { message = "%a", scrollArea = "Outgoing",
    scrollAreaOther = "OutgoingOther" }
Settings("OUTGOING_DAMAGE", "OUTGOING_PLAYER_EVENTS")
-- Then the popup is told to offer it, with the event's choice.
assert(eventPopup.showScrollAreaOther == true and eventPopup.scrollAreaOther == "OutgoingOther")
-- When the user keeps it, picks another area, or picks "Same as above".
for _, choice in ipairs({ "OutgoingOther", "Custom", false }) do
    savedOptions = {}
    eventPopup.saveHandler({ message = "%a", scrollArea = "Outgoing", scrollAreaOther = choice },
        eventPopup.saveArg1)
    -- Then the choice is saved for that field alone, without a default that could hide it.
    local saved = SavedSecondAreas()
    assert(#saved == 1 and saved[1][1] == "events.OUTGOING_DAMAGE" and saved[1][3] == choice
        and saved[1][4] == nil, "the second area was not saved as chosen")
end
-- And a save from a popup that offered no second area saves none.
savedOptions = {}
eventPopup.saveHandler({ message = "%a", scrollArea = "Outgoing" }, eventPopup.saveArg1)
assert(#SavedSecondAreas() == 0 and #savedOptions > 0, "a save without a second area wrote one")
-- When the settings of events that take none are opened.
Settings("OUTGOING_HEAL", "OUTGOING_PLAYER_EVENTS")
assert(not eventPopup.showScrollAreaOther, "an outgoing event the profile refuses was offered a second area")
Settings("PET_OUTGOING_DAMAGE", "OUTGOING_PET_EVENTS")
assert(not eventPopup.showScrollAreaOther, "a pet event was offered a second area")
Settings("NOTIFICATION_BUFF", "NOTIFICATION_EVENTS")
assert(not eventPopup.showScrollAreaOther, "a notification was offered a second area")
list.lines[1].auraLine.settingsButton:click()
assert(not eventPopup.showScrollAreaOther, "an aura was offered a second area")
-- When a client has no such area.
MikSBT.Profiles.masterProfile.scrollAreas.OutgoingOther = nil
Settings("OUTGOING_DAMAGE", "OUTGOING_PLAYER_EVENTS")
assert(not eventPopup.showScrollAreaOther, "a client without the area was offered it")
MikSBT.Profiles.masterProfile, MikSBT.Profiles.SetOption = nil, savingOption
MikSBT.Profiles.currentProfile.events.OUTGOING_DAMAGE = nil

-- Describe: entering a name and an ID creates independently scoped rows.
-- Given the notification category with an existing ID rule.
controls.eventCategoryDropdown:SetSelectedID("NOTIFICATION_EVENTS")
controls.eventCategoryDropdown:change("NOTIFICATION_EVENTS")
-- When the same spell is added by name.
panel.input:SetText("Aura 17")
panel.add.clickHandler(panel.add)
-- Then a distinct all-ranks row is saved and clearly labeled.
local nameKey = "name:Aura 17"
assert(MikSBT.Profiles.currentProfile.auraTracking[nameKey] == false,
    "name entry was saved as an exact ID")
assert(list.items[1] == nameKey)
assert(list.lines[1].auraLine.label.text == "Aura 17 (all ranks)")
assert(list.lines[2].auraLine.label.text == "Aura 17 (17)")

-- Describe: the Events tab treats an aura tracked by name as an aura.
-- Given the all-ranks row and a spy on the events written through the profile.
local profileWrites = {}
MikSBT.Profiles.currentProfile.events.NOTIFICATION_BUFF.fontSize = 24
MikSBT.Profiles.currentProfile.scrollAreas = { Notification = {} }
local plainSetOption = MikSBT.Profiles.SetOption
MikSBT.Profiles.SetOption = function(path, ...)
	if path then profileWrites[#profileWrites + 1] = path return end
	return plainSetOption(path, ...)
end
MSBTOptions.Auras.SaveSetting(nameKey, "message", "Named %sl")
MSBTOptions.Auras.SaveSetting(nameKey, "fontSize", 32)
local named = list.lines[1].auraLine
-- When its settings and font dialogs open, and then save.
named.settingsButton:click()
assert(eventPopup.message == "Named %sl", "settings did not read the aura's settings")
eventPopup.saveHandler({ message = "Saved %sl", scrollArea = "Notification" },
	eventPopup.saveArg1)
named.fontButton:click()
assert(fontPopup.normalFontSize == 32, "font dialog did not read the aura's settings")
assert(fontPopup.inheritedNormalFontSize == 24, "font dialog did not inherit from the aura base")
fontPopup.saveHandler({ normalFontSize = 40 }, fontPopup.saveArg1)
-- And the color is changed.
named.colorSwatch:SetColor(0.3, 0.6, 0.9)
named.colorSwatch.colorChangedHandler(named.colorSwatch)
-- Then everything is saved with the aura and nothing under the events table.
local nameSettings = MikSBT.Profiles.currentProfile.auraSettings[nameKey]
assert(nameSettings.message == "Saved %sl" and nameSettings.fontSize == 40)
assert(nameSettings.colorR == 0.3 and nameSettings.colorB == 0.9)
assert(#profileWrites == 0, "a name rule was written to events: " .. tostring(profileWrites[1]))
MikSBT.Profiles.currentProfile.events.NOTIFICATION_BUFF.fontSize = nil
MikSBT.Profiles.SetOption = plainSetOption

-- Given the all-ranks row with a custom font.
MSBTOptions.Auras.SaveSetting(nameKey, "fontSize", 32)
-- When it is enabled and removed.
list.lines[1].auraLine.checkbox:click(true)
assert(MikSBT.Profiles.currentProfile.auraTracking[nameKey] == true)
list.lines[1].auraLine.remove:click()
-- Then its rule and style disappear while the exact-ID rule survives.
assert(MikSBT.Profiles.currentProfile.auraTracking[nameKey] == nil)
assert(MikSBT.Profiles.currentProfile.auraSettings[nameKey] == nil)
assert(MikSBT.Profiles.currentProfile.auraTracking["17"] == true)

-- Given a name that the spell API cannot resolve.
-- When it is added through the real options panel.
local errorsBefore = #messages
panel.input:SetText("Unlearned Aura")
panel.add.clickHandler(panel.add)
-- Then a name rule appears without a false 'Aura not found' error.
assert(MikSBT.Profiles.currentProfile.auraTracking[
    "name:Unlearned Aura"] == false, "unresolved name was rejected")
assert(#messages == errorsBefore)
assert(list.items[1] == "name:Unlearned Aura")

-- Describe: only the resource notification config exposes resource choices.
-- Given the existing notification rows and profile-specific exclusions.
MikSBT.Profiles.currentProfile.resourceExclusions = { MANA = true }
local resourceRow, combatRow
for _, line in ipairs(list.lines) do
	if line.eventType == "NOTIFICATION_RESOURCE_GAIN" then resourceRow = line end
	if line.eventType == "NOTIFICATION_COMBAT_ENTER" then combatRow = line end
end
-- When the user presses Configure on Resource Gains.
resourceRow.settingsButton:click()
-- Then the popup receives the profile's individual choices.
assert(eventPopup.showResources, "Resource Gains config omitted resource controls")
assert(eventPopup.resourceExclusions.MANA == true)
-- When its shared settings and a changed checkbox map are saved together.
local setOption = MikSBT.Profiles.SetOption
MikSBT.Profiles.SetOption = function(path, key, value)
	if path == "events.NOTIFICATION_RESOURCE_GAIN" then return end
	if key == "resourceExclusions" then
		MikSBT.Profiles.currentProfile.resourceExclusions = value
		return
	end
	return setOption(path, key, value)
end
eventPopup.saveHandler({ message = "%a - %p", scrollArea = "Notification",
	resourceExclusions = { COMBO_POINTS = true } }, eventPopup.saveArg1)
-- Then the saved profile contains the new map rather than the old checkbox state.
assert(MikSBT.Profiles.currentProfile.resourceExclusions.COMBO_POINTS == true)
assert(MikSBT.Profiles.currentProfile.resourceExclusions.MANA == nil)
MikSBT.Profiles.SetOption = setOption
-- When another notification is configured, then the resource panel is omitted.
combatRow.settingsButton:click()
assert(not eventPopup.showResources)

-- Given translated help text and the Chinese game locale.
local language = tabs[MikSBT.translations.TABS.language.label]
local reset = tabs[MikSBT.translations.TABS.resetBlizzardSCT.label]
local L = MikSBT.translations
L.TABS.language.label = "语言"
L.TABS.resetBlizzardSCT.label = "重置暴雪战斗文字"
L.LANGUAGE_CURRENT = "当前语言：%s（%s）"
L.LANGUAGE_INFO = "MSBT 使用游戏语言。"
L.RESET_BLIZZARD_INFO = "恢复暴雪战斗文字。"
GetLocale = function() return "zhCN" end
-- When both help tabs are opened for the first time.
language.scripts.OnShow()
reset.scripts.OnShow()
-- Then actual controls render localized headers, language names, and help.
assert(language.headerFontString.text == "语言")
assert(language.currentLocaleFontString.text == "当前语言：简体中文（zhCN）")
assert(language.languageInfoFontString.text == L.LANGUAGE_INFO)
assert(reset.headerFontString.text == "重置暴雪战斗文字")
assert(reset.bodyFontString.text == L.RESET_BLIZZARD_INFO)

-- Describe: Events can be viewed by the scroll area assigned to each row.
-- Given a custom area added after the Events tab was first opened.
local profile = MikSBT.Profiles.currentProfile
MikSBT.Profiles.masterProfile = {
	scrollAreas = { Notification = {}, Outgoing = {}, Incoming = {}, Static = {} },
}
MikSBT.Animations.scrollAreas = {
	Incoming = { name = "Incoming" },
	Notification = { name = "Notification" },
	Outgoing = { name = "Outgoing" },
	Static = { name = "Static" },
	Custom1 = { name = "Hunter" },
}
profile.events.OUTGOING_DAMAGE = {
	message = "Weapon %a", scrollArea = "Custom1",
}
profile.events.OUTGOING_SPELL_DAMAGE = {
	message = "Skill %a", scrollArea = "Outgoing",
}
profile.events.NOTIFICATION_LOOT = { message = "%e", scrollArea = "Static" }
profile.events.NOTIFICATION_MONEY = { message = "%e", scrollArea = "Static" }
profile.events.NOTIFICATION_CURRENCY = { message = "%e", scrollArea = "Notification" }
profile.events.NOTIFICATION_ABILITY_READY = { message = "%s", scrollArea = "Static" }
profile.auraTracking["1459"] = true
profile.auraSettings = { ["1459"] = { scrollArea = "Custom1" } }
MikSBT.Profiles.SetOption = function(path, field, value)
	if path then
		local eventType = assert(path:match("^events%.(.+)$"))
		profile.events[eventType][field] = value
	else
		profile[field] = value
	end
end

-- When the tab is reopened and the custom area is selected.
events.scripts.OnShow()
local dropdown = controls.eventCategoryDropdown
local names = {}
for _, label in ipairs(dropdown.items) do names[label] = true end
assert(#dropdown.items == #MikSBT.translations.EVENT_CATEGORIES + 2,
	"Static and one custom area should add exactly two dropdown entries")
assert(names.Hunter and names["Outgoing Player"])
assert(names.Static, "Static was missing from the Events picker")
local function SelectCategory(id)
	dropdown:SetSelectedID(id)
	dropdown:change(id)
end

-- When Static is selected, then it shows only the rows routed there.
SelectCategory("scrollArea:Static")
local staticRows = {}
for _, line in ipairs(list.lines) do staticRows[line.eventType] = line end
assert(#list.lines == 3 and staticRows.NOTIFICATION_LOOT
	and staticRows.NOTIFICATION_MONEY and staticRows.NOTIFICATION_ABILITY_READY)
assert(not staticRows.NOTIFICATION_CURRENCY and not staticRows.OUTGOING_DAMAGE)

-- When the loot event is disabled there, then its shared setting is updated.
staticRows.NOTIFICATION_LOOT.enableCheckbox:click(false)
assert(profile.events.NOTIFICATION_LOOT.disabled == true)
assert(not profile.events.NOTIFICATION_MONEY.disabled)

SelectCategory("scrollArea:Custom1")

-- Then the view shows exactly the event and aura assigned to Hunter.
assert(#list.lines == 2)
assert(list.lines[1].auraLine.auraID == "1459")
assert(list.lines[2].eventType == "OUTGOING_DAMAGE")

-- When the event is moved back from its Configure popup.
list.lines[2].settingsButton:click()
eventPopup.saveHandler({
	message = "Weapon %a", scrollArea = "Outgoing",
}, eventPopup.saveArg1)

-- Then it leaves Hunter immediately and stays in its original event category.
assert(#list.lines == 1 and list.lines[1].auraLine.auraID == "1459")
SelectCategory("OUTGOING_PLAYER_EVENTS")
assert(#list.lines > 2)
assert(list.lines[1].eventType == "OUTGOING_DAMAGE")
assert(profile.events.OUTGOING_DAMAGE.scrollArea == "Outgoing")

-- When all rows in Hunter are moved to Outgoing.
SelectCategory("scrollArea:Custom1")
profile.events.OUTGOING_DAMAGE.scrollArea = "Hunter"
events.scripts.OnShow()
assert(#list.lines == 2, "legacy scroll-area names should resolve to their key")
controls.moveButton:clickHandler()
movePopup.saveHandler("Outgoing")

-- Then the event and aura leave Hunter and other event assignments stay put.
assert(#list.lines == 0)
assert(profile.events.OUTGOING_DAMAGE.scrollArea == "Outgoing")
assert(profile.auraSettings["1459"].scrollArea == "Outgoing")
assert(profile.events.OUTGOING_SPELL_DAMAGE.scrollArea == "Outgoing")
assert(profile.events.NOTIFICATION_BUFF.scrollArea == "Notification")

-- When the selected area is renamed and then deleted.
SelectCategory("scrollArea:Custom1")
MikSBT.Animations.scrollAreas.Custom1.name = "Hunter renamed"
events.scripts.OnShow()
assert(dropdown:GetSelectedID() == "scrollArea:Custom1")
local renamed
for _, label in ipairs(dropdown.items) do
	assert(label ~= "Hunter")
	if label == "Hunter renamed" then renamed = true end
end
assert(renamed)
MikSBT.Animations.scrollAreas.Custom1 = nil
events.scripts.OnShow()

-- Then the picker returns to its first event category.
assert(dropdown:GetSelectedID() == "INCOMING_PLAYER_EVENTS")
