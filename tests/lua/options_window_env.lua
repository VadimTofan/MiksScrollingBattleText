-- Shared by the options window scripts: a stubbed frame API, a small profile store,
-- the real Controls, Main, ProfileSnapshots and Window, and classic tab frames.
local function Noop() end
local Methods = {}
local Meta = {
	__index = function(_, key)
		local method = Methods[key]
		if method then return method end
		-- Texture slicing is a client feature; a script turns it on through Methods. SetLabel is no
		-- widget method; option buttons get theirs from the factory.
		if key:match("^[A-Z]") and key ~= "SetTextureSliceMargins" and key ~= "SetLabel" then return Noop end
	end,
}

-- Like the game, a new frame is shown, so its first Show() runs no OnShow.
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
function Methods:GetScript(event) return self.scripts[event] end
function Methods:HookScript(event, handler)
	local original = self.scripts[event]
	self.scripts[event] = function(...)
		if original then original(...) end
		handler(...)
	end
end
function Methods:GetChildren() return unpack(self.children) end
-- Anchors by their point, as the game keeps one anchor per point.
function Methods:SetPoint(point, relative, relativePoint, x, y)
	if type(relative) ~= "table" then relative, relativePoint, x, y = self.parent, relative, relativePoint, x end
	self.points = rawget(self, "points") or {}
	self.points[point] = { relative = relative, relativePoint = relativePoint or point, x = x or 0, y = y or 0 }
end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetAtlas(atlas, useAtlasSize) self.atlas, self.atlasSize = atlas, useAtlasSize end
function Methods:SetAlpha(value) self.alpha = value end
function Methods:SetBlendMode(mode) self.blendMode = mode end
function Methods:SetWordWrap(value) self.wordWrap = value end
function Methods:SetJustifyH(value) self.justifyH = value end
function Methods:SetFrameStrata(value) self.strata = value end
function Methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function Methods:GetBackdrop() return rawget(self, "backdrop") end
function Methods:GetTextureFilePath() return self.texturePath end
function Methods:SetWidth(value) self.width = value end
function Methods:SetHeight(value) self.height = value end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:SetScale(value) self.scale = value end
function Methods:GetFrameLevel() return self.level end
function Methods:SetFrameLevel(value) self.level = value end
function Methods:GetFrameStrata() return "DIALOG" end
function Methods:CreateTexture(_, layer)
	local region = NewRegion("Texture", self)
	region.layer = layer
	self.regions[#self.regions + 1] = region
	return region
end
function Methods:CreateFontString(_, layer, template)
	local region = NewRegion("FontString", self)
	region.layer, region.template = layer, template
	self.regions[#self.regions + 1] = region
	return region
end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:GetRegions() return unpack(self.regions) end
function Methods:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Methods:SetTexture(path) self.texturePath = path end
function Methods:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Methods:SetDesaturated(value) self.desaturated = value end
function Methods:SetTexCoord(...) self.texCoord = { ... } end
function Methods:SetTextColor(r, g, b) self.textColor = { r, g, b } end
-- Like the game, an edit box runs OnTextChanged when its text changes, also by SetText.
function Methods:SetText(text)
	if self.fontString then return self.fontString:SetText(text) end
	local changed = self.text ~= text
	self.text = text
	if changed and self.kind == "Editbox" and self.scripts.OnTextChanged then
		self.scripts.OnTextChanged(self)
	end
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
		rawset(self, state, rawget(self, state) or self:CreateTexture())
		if type(path) == "string" then rawget(self, state).texturePath = path end
	end
	Methods["Set" .. state .. "Atlas"] = function(self, atlas)
		Methods["Set" .. state .. "Texture"](self)
		rawget(self, state).atlas = atlas
	end
	Methods["Get" .. state .. "Texture"] = function(self) return rawget(self, state) end
end
function Methods:Enable() self.enabled = true end
function Methods:Disable() self.enabled = false end
function Methods:IsEnabled() return self.enabled end
function Methods:SetChecked(value) self.checked = value end
function Methods:GetChecked() return self.checked end
function Methods:GetMinMaxValues() return self.minValue, self.maxValue end
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
function Methods:SetValueStep(value) self.step, self.stepSet = value, value end
function Methods:GetValueStep() return self.step end
function Methods:SetBackdropColor(...) self.backdropColor = { ... } end

function CreateFrame(kind, name, parent, template)
	local frame = NewRegion(kind, parent, name)
	if template and template:find("Scroll%a+ButtonTemplate") then
		frame:SetNormalTexture()
		frame:SetPushedTexture()
		frame:SetDisabledTexture()
	end
	return frame
end
UIParent = NewRegion("Frame", nil, "UIParent")
-- A screen large enough for the window at its largest scale; a script sets a smaller one.
UIParent.width, UIParent.height = 3840, 2160
UISpecialFrames = {}
function PlaySound() end
SOUNDKIT = { IG_MAINMENU_OPTION = 850 }
GameTooltip = setmetatable({}, { __index = function() return Noop end })
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
for _, name in ipairs({ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
	"GameFontHighlight", "GameFontDisable", "ChatFontNormal" }) do
	_G[name] = {}
end
-- The client's atlas lookup. Blizzard's art is missing unless a script makes it available
-- before the window is built, so the scripts cover the flat look by default.
local art = { queries = 0 }
C_Texture = { GetAtlasInfo = function(atlas)
	art.queries = art.queries + 1
	if art.available and atlas ~= art.missing then return { width = 1, height = 1 } end
end }
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

-- A small profile store with the same entry points the options call.
local saved = { profiles = { Default = {}, Alt = {} } }
local perChar = { currentProfileName = "Default" }
local calls = {}
local Profiles = {
	savedVariables = saved, currentProfile = saved.profiles.Default, savedMedia = { sounds = {} },
}
local function Record(name, ...) calls[#calls + 1] = { name, ... } end
local function Select(name)
	perChar.currentProfileName = name
	Profiles.currentProfile = saved.profiles[name]
end
function Profiles.SetOption(section, key, value, default)
	Record("SetOption", section, key, value, default)
	local target = Profiles.currentProfile
	if section then
		for part in section:gmatch("[^.]+") do
			target[part] = target[part] or {}
			target = target[part]
		end
	end
	target[key] = value
end
function Profiles.SetOptionUserDisabled(isDisabled)
	Record("SetOptionUserDisabled", isDisabled)
	saved.userDisabled = isDisabled or nil
end
function Profiles.IsModDisabled() return saved.userDisabled end
function Profiles.SelectProfile(name) Record("SelectProfile", name) Select(name) end
function Profiles.ApplyContextOptions() Record("ApplyContextOptions") end
function Profiles.CopyProfile(source, target)
	Record("CopyProfile", source, target)
	saved.profiles[target] = CopyTable(saved.profiles[source])
end
function Profiles.ResetProfile(name)
	Record("ResetProfile", name)
	local profile = saved.profiles[name or perChar.currentProfileName]
	for key in pairs(profile) do profile[key] = nil end
end
for _, name in ipairs({ "DeleteProfile", "ImportProfile",
	"ExportProfile", "ResetOfficialBlizzardCombatText" }) do
	Profiles[name] = function(...) Record(name, ...) end
end

MikSBT = {
	VERSION_STRING = "v12.052",
	Compatibility = { Client = { hasModernAPI = true } },
	translations = {},
	Configuration = {},
	CopyTable = CopyTable,
	EraseTable = function(value) for key in next, value do value[key] = nil end end,
	Profiles = Profiles,
}
dofile("MSBTOptions/Localization/localization.lua")
dofile("Configuration/ProfileSnapshots.lua")
local snapshots = MikSBT.Configuration.ProfileSnapshots:New({
	savedVariables = saved, savedVariablesPerChar = perChar, selectProfile = Select,
})
function Profiles.GetProfileSnapshots() return snapshots end
snapshots:UpdateLoginSnapshot(true)

dofile("MSBTOptions/MSBTOptionsControls.lua")
dofile("MSBTOptions/MSBTOptionsDesigns.lua")
dofile("MSBTOptions/MSBTOptionsMain.lua")
local L = MikSBT.translations
local Main = MSBTOptions.Main
-- Popups record the design that uses them; scripts that open popups add what they need.
local popups = {}
function popups.UseDesignPopups(key) popups.design = key end
MSBTOptions.Popups = popups
local tabs, populated = {}, {}
for _, tab in ipairs({ { "general" }, { "profile", 8999.5 }, { "scrollAreas" }, { "events" },
	{ "sounds" }, { "lootAlerts" }, { "language", 9500 }, { "resetBlizzardSCT", 9000 } }) do
	local key = tab[1]
	local frame = CreateFrame("Frame")
	frame:Hide()
	frame:SetScript("OnShow", function() populated[key] = (populated[key] or 0) + 1 end)
	tabs[key] = frame
	Main.AddTab(frame, L.TABS[key].label, L.TABS[key].tooltip, tab[2])
end
dofile("MSBTOptions/Designs/Forever/Window.lua")

local env = {
	Noop = Noop, Methods = Methods, saved = saved, perChar = perChar, calls = calls,
	Profiles = Profiles, snapshots = snapshots, L = L, Main = Main, tabs = tabs,
	populated = populated, Window = MSBTOptions.Window, art = art, Popups = popups,
}
function env.Find(root, predicate)
	if predicate(root) then return root end
	for _, child in ipairs(root.children) do
		local found = env.Find(child, predicate)
		if found then return found end
	end
end
function env.FindAll(root, predicate, found)
	found = found or {}
	if predicate(root) then found[#found + 1] = root end
	for _, child in ipairs(root.children) do env.FindAll(child, predicate, found) end
	return found
end
function env.Labelled(text)
	return function(region)
		return region.kind == "Button" and region:GetText() == text
	end
end
-- A disabled button ignores the click, as in the game.
function env.Click(button)
	if button.enabled then button.scripts.OnClick(button) end
end
function env.ClickEntry(key)
	env.Click(env.Find(MSBTOptionsWindowFrame, function(region) return region.key == key end))
end
function env.IsInWindow(frame)
	return frame:GetParent() and frame:GetParent():GetParent() == MSBTOptionsWindowFrame
end
function env.Count() return snapshots:Count(snapshots:GetLoginSnapshot()) end
function env.Footer()
	return env.Find(MSBTOptionsWindowFrame, function(region)
		return region.kind == "Button" and (region:GetText() or ""):find("Changes since login", 1, true)
	end)
end
return env
