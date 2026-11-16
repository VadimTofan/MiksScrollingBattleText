-- Describe: the classic scroll area configuration lists the style entries and saves every field as before.
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
		kind = kind, parent = parent, shown = true, scripts = {}, children = {},
		enabled = true, value = 0, minValue = 0, maxValue = 0, step = 1,
	}, Meta)
	if parent then parent.children[#parent.children + 1] = region end
	if name then _G[name] = region end
	return region
end

function Methods:GetParent() return self.parent end
function Methods:SetParent(parent) self.parent = parent end
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
function Methods:SetScript(event, handler) self.scripts[event] = handler end
function Methods:GetWidth() return 100 end
function Methods:GetFrameLevel() return 0 end
function Methods:CreateTexture() return NewRegion("Texture", self) end
function Methods:CreateFontString() return NewRegion("FontString", self) end
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
	Methods["Set" .. state .. "Texture"] = function(self)
		rawset(self, state, rawget(self, state) or self:CreateTexture())
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

function CreateFrame(kind, name, parent) return NewRegion(kind, parent, name) end
UIParent = NewRegion("Frame", nil, "UIParent")
function PlaySound() end
function GetLocale() return "enUS" end
FillLocalizedClassList = Noop
SAVE, CANCEL, OKAY, YES, NO = "Save", "Cancel", "Okay", "Yes", "No"
GameTooltip = setmetatable({}, { __index = function() return Noop end })
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }

local calls, updates = {}, 0
MikSBT = {
	VERSION_STRING = "v12.052",
	Compatibility = { Client = { hasModernAPI = true } },
	translations = {},
	Main = {},
	Media = { fonts = {} },
	EraseTable = function(value) for key in next, value do value[key] = nil end end,
	Profiles = {
		currentProfile = { animationSpeed = 100 },
		SetOption = function(section, key, value, default)
			calls[#calls + 1] = { section, key, value, default }
		end,
	},
	Animations = {
		scrollAreas = {
			Incoming = { name = "Incoming", offsetX = -140, offsetY = -160, animationStyle = "Parabola",
				direction = "Down" },
			Outgoing = { name = "Outgoing", offsetX = 100, offsetY = -160, animationSpeed = 100 },
		},
		animationStyles = {
			Straight = { availableDirections = "Up;Down", localizationTable = { Up = "Rising" } },
			Parabola = { availableDirections = "Up;Down", availableBehaviors = "CurvedLeft;CurvedRight" },
		},
		stickyAnimationStyles = {
			Pow = { availableDirections = "Up;Down", availableBehaviors = "MSBT_NORMAL;Jiggle" },
			Static = {},
		},
		UpdateScrollAreas = function() updates = updates + 1 end,
	},
}
dofile("MSBTOptions/Localization/localization.lua")
local L = MikSBT.translations
MSBTOptions.Main = { RegisterPopupFrame = Noop, ShowMainFrame = Noop }
MSBTOptions.Designs = { Show = Noop }
dofile("MSBTOptions/MSBTOptionsControls.lua")
dofile("MSBTOptions/MSBTOptionsPopups.lua")

local function Find(root, predicate)
	if predicate(root) then return root end
	for _, child in ipairs(root.children) do
		local found = Find(child, predicate)
		if found then return found end
	end
end
local function Choose(dropdown, id)
	dropdown:SetSelectedID(id)
	dropdown:changeHandler(id)
end
local function ClickCheckbox(checkbox, isChecked)
	checkbox.checkFrame:SetChecked(isChecked)
	checkbox.checkFrame.scripts.OnClick(checkbox.checkFrame)
end
local function Entries(dropdown, ids, names)
	if #dropdown.itemIDs ~= #ids then return false end
	for index, id in ipairs(ids) do
		if dropdown.itemIDs[index] ~= id or dropdown.items[index] ~= names[index] then return false end
	end
	return true
end
local DATA = L.ANIMATION_STYLE_DATA

MikSBT.Popups = MSBTOptions.Popups
MSBTOptions.Popups.ShowScrollAreaConfig()
local frame = MSBTScrollAreasConfigFrame

-- Rule: the style dropdowns list the styles and the entries the chosen style offers, first one selected.
do
	-- Given Incoming with its own style and direction, shown first.
	local styles = frame.animationStyleDropdown
	assert(#styles.itemIDs == 2, "the style list holds " .. #styles.itemIDs .. " styles")
	assert(styles:GetSelectedID() == "Parabola", "the area's style is not selected")
	assert(Entries(frame.directionDropdown, { "Up", "Down" }, { DATA.Up, DATA.Down })
		and frame.directionDropdown:GetSelectedID() == "Down", "the area's directions are wrong")
	assert(Entries(frame.behaviorDropdown, { "CurvedLeft", "CurvedRight" }, { DATA.CurvedLeft, DATA.CurvedRight })
		and frame.behaviorDropdown:GetSelectedID() == "CurvedLeft", "the area's behaviors are wrong")

	-- When another style is chosen.
	Choose(styles, "Straight")

	-- Then its entries are listed with the style's own names, and a style without behaviors offers Normal.
	assert(Entries(frame.directionDropdown, { "Up", "Down" }, { "Rising", DATA.Down })
		and frame.directionDropdown:GetSelectedID() == "Up", "the new style's directions are wrong")
	assert(Entries(frame.behaviorDropdown, { "MSBT_NORMAL" }, { DATA.Normal })
		and frame.behaviorDropdown:GetSelectedID() == "MSBT_NORMAL", "the new style's behaviors are wrong")

	-- When the sticky style changes to one without entries and back.
	Choose(frame.stickyAnimationStyleDropdown, "Static")
	assert(Entries(frame.stickyDirectionDropdown, { "MSBT_NORMAL" }, { DATA.Normal }),
		"a sticky style without directions does not offer Normal")
	Choose(frame.stickyAnimationStyleDropdown, "Pow")

	-- Then the sticky dropdowns, and only they, follow it.
	assert(Entries(frame.stickyBehaviorDropdown, { "MSBT_NORMAL", "Jiggle" }, { DATA.MSBT_NORMAL or "MSBT_NORMAL", DATA.Jiggle })
		and frame.stickyDirectionDropdown:GetSelectedID() == "Up", "the sticky entries are wrong")
	assert(frame.directionDropdown.items[1] == "Rising", "the sticky style changed the normal directions")
end

-- Rule: the sliders keep their ranges.
do
	for _, range in ipairs({ { frame.scrollHeightSlider, 50, 600, 5 }, { frame.scrollWidthSlider, 10, 800, 10 },
		{ frame.animationSpeedSlider, 20, 250, 10 } }) do
		local slider = range[1].sliderFrame
		assert(slider.minValue == range[2] and slider.maxValue == range[3] and slider.step == range[4],
			range[1].labelText .. " has another range")
	end
end

-- Rule: saving writes every field of every area with its value and default, in the order it always had.
do
	-- Given every control of Incoming set.
	Choose(frame.directionDropdown, "Down")
	Choose(frame.stickyBehaviorDropdown, "Jiggle")
	Choose(frame.textAlignDropdown, 3)
	Choose(frame.stickyTextAlignDropdown, 1)
	frame.scrollHeightSlider:SetValue(300)
	frame.scrollWidthSlider:SetValue(120)
	ClickCheckbox(frame.animationSpeedCheckbox, false)
	frame.animationSpeedSlider:SetValue(150)
	frame.xOffsetEditbox:SetText("55")
	frame.yOffsetEditbox:SetText("-70")
	Choose(frame.iconAlignDropdown, "Right")
	ClickCheckbox(frame.iconsDisabledCheckbox, true)

	-- When Save is clicked.
	calls = {}
	local save = Find(frame, function(region)
		return region.kind == "Button" and region:GetText() == L.BUTTONS.genericSave.label
	end)
	save.scripts.OnClick(save)

	-- Then each area gets every field once, in order; untouched values go with their defaults,
	-- and the speed's default is the profile's speed.
	local expected = {
		Incoming = {
			{ "animationStyle", "Straight", "Straight" }, { "direction", "Down", "MSBT_NORMAL" },
			{ "behavior", "MSBT_NORMAL", "MSBT_NORMAL" }, { "textAlignIndex", 3, 2 },
			{ "stickyAnimationStyle", "Pow", "Pow" }, { "stickyDirection", "Up", "MSBT_NORMAL" },
			{ "stickyBehavior", "Jiggle", "MSBT_NORMAL" }, { "stickyTextAlignIndex", 1, 2 },
			{ "scrollHeight", 300, 260 }, { "scrollWidth", 120, 40 }, { "offsetX", 55 }, { "offsetY", -70 },
			{ "animationSpeed", 150, 100 }, { "iconAlign", "Right", "Left" }, { "skillIconsDisabled", true },
		},
		Outgoing = {
			{ "animationStyle", "Straight", "Straight" }, { "direction", nil, "MSBT_NORMAL" },
			{ "behavior", nil, "MSBT_NORMAL" }, { "textAlignIndex", 2, 2 },
			{ "stickyAnimationStyle", "Pow", "Pow" }, { "stickyDirection", nil, "MSBT_NORMAL" },
			{ "stickyBehavior", nil, "MSBT_NORMAL" }, { "stickyTextAlignIndex", 2, 2 },
			{ "scrollHeight", 260, 260 }, { "scrollWidth", 40, 40 }, { "offsetX", 100 }, { "offsetY", -160 },
			{ "animationSpeed", 100, 100 }, { "iconAlign", "Left", "Left" }, { "skillIconsDisabled", nil },
		},
	}
	local seen = {}
	for _, call in ipairs(calls) do
		local key = call[1]:match("^scrollAreas%.(.+)$")
		seen[key] = (seen[key] or 0) + 1
		local want = expected[key][seen[key]]
		assert(want and call[2] == want[1] and call[3] == want[2] and call[4] == want[3],
			key .. " call " .. seen[key] .. " is " .. tostring(call[2]) .. " = " .. tostring(call[3])
			.. " (default " .. tostring(call[4]) .. ")")
	end
	assert(seen.Incoming == 15 and seen.Outgoing == 15, "not every field was saved")
	assert(updates == 1, "the running addon was updated " .. updates .. " times")
	assert(not frame:IsShown(), "Save did not close the configuration")
end

print("Scroll area configuration tests passed")
