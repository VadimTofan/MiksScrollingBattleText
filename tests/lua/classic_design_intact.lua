-- Describe: the classic options window looks the same alone and after the new window was used.
local HARNESS = debug.getinfo(1, "S").short_src
local function Noop() end

local function Serialize(value)
	if type(value) ~= "table" then return tostring(value) end
	if value.kind and value.id then return "<" .. value.id .. ">" end
	if value.fontName then return "font:" .. value.fontName end
	local parts = {}
	for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. Serialize(item) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end
local function SerializeArgs(packed)
	local parts = {}
	for index = 1, packed.n do parts[index] = Serialize(packed[index]) end
	return table.concat(parts, ",")
end

-- A frame API stub that keeps every visual setting an object receives. An object is named by
-- its parent, its kind and the function that created it, so creation order elsewhere is moot.
local DEFAULTS = { GetWidth = 0, GetHeight = 0, GetScale = 1, GetAlpha = 1, GetFrameLevel = 0,
	GetFrameStrata = "MEDIUM", GetText = "" }
local STATES = { "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked", "Thumb" }

local function NewWorld()
	local G = setmetatable({}, { __index = _G })
	G._G = G
	local world = { G = G, all = {}, counts = {}, steps = {}, dirty = {}, skinned = {}, shownClassic = 0 }
	local Methods, Meta, cache = {}, {}, {}
	local Touch, Fire

	local function CreatorFunction()
		for level = 3, 40 do
			local info = debug.getinfo(level, "nS")
			if not info then return "?" end
			if info.short_src ~= HARNESS and info.what ~= "C" then
				return info.what == "main" and "main" or info.name or "?"
			end
		end
	end
	local function NewObject(kind, parent, name)
		local obj = setmetatable({ kind = kind, parent = parent, creator = parent, name = name,
			shown = true, enabled = true, props = {}, scripts = {}, hooks = {}, points = {},
			regions = {}, children = {}, value = 0, minValue = 0, maxValue = 0 }, Meta)
		obj.site = CreatorFunction()
		local owner
		if obj.site == "Dropdown_CreateListboxFrame" then
			obj.id, obj.singleton, world.sharedList = "SharedDropdownList", true, obj
		elseif name then
			obj.id = name
		else
			-- A frame made without a parent is named after the object made just before it by the same function.
			owner = parent or (obj.site ~= "main" and world.last and world.last.site == obj.site and world.last)
			local prefix = (owner and owner.id or "-") .. "/" .. kind .. ":" .. obj.site
			-- The new design's popups are instances of their own beside the classic ones.
			if world.designPopups and parent == G.UIParent then prefix = "design:" .. prefix end
			world.counts[prefix] = (world.counts[prefix] or 0) + 1
			obj.id = prefix .. "#" .. world.counts[prefix]
		end
		obj.creator = parent or owner
		world.last = obj
		obj.fire = Fire
		Touch(obj)
		if parent then parent.children[#parent.children + 1] = obj end
		if name then G[name] = obj end
		world.all[#world.all + 1] = obj
		return obj
	end
	function Fire(obj, event, ...)
		if obj.scripts[event] then obj.scripts[event](obj, ...) end
		for _, hook in ipairs(obj.hooks[event] or {}) do hook(obj, ...) end
	end
	-- An object is described again only after it changed; a new scale or parent changes its subtree.
	function Touch(obj, withChildren)
		if not obj.dirty then obj.dirty = true world.dirty[#world.dirty + 1] = obj end
		if withChildren then for _, child in ipairs(obj.children) do Touch(child, true) end end
	end
	world.Touch = Touch
	local function Store(self, key, ...)
		self.props[key] = { n = select("#", ...), ... }
		Touch(self, key == "SetScale")
	end

	Meta.__index = function(_, key)
		if Methods[key] then return Methods[key] end
		-- The game has no such widget method; option buttons get theirs from the factory.
		if key == "SetLabel" then return nil end
		if not cache[key] then
			if key:match("^Get") then
				cache[key] = function(self)
					local packed = self.props["Set" .. key:sub(4)]
					if packed then return unpack(packed, 1, packed.n) end
					return DEFAULTS[key]
				end
			elseif key:match("^[A-Z]") and not key:match("^Is") and not key:match("^Create") then
				cache[key] = function(self, ...) Store(self, key, ...) end
			end
		end
		return cache[key]
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
		Touch(self, true)
	end
	function Methods:GetChildren() return unpack(self.children) end
	function Methods:GetRegions() return unpack(self.regions) end
	function Methods:IsShown() return self.shown end
	-- Like the client: a change of visibility runs OnShow or OnHide on the frame and on every
	-- shown frame under it.
	local function IsVisible(obj)
		while obj do
			if not obj.shown then return false end
			obj = obj.parent
		end
		return true
	end
	local function FireTree(obj, event)
		Fire(obj, event)
		for _, child in ipairs({ unpack(obj.children) }) do
			if child.shown then FireTree(child, event) end
		end
	end
	function Methods:Show()
		if self.shown then return end
		self.shown = true
		Touch(self)
		if not self.parent or IsVisible(self.parent) then FireTree(self, "OnShow") end
	end
	function Methods:Hide()
		if not self.shown then return end
		local wasVisible = IsVisible(self)
		self.shown = false
		Touch(self)
		if wasVisible then FireTree(self, "OnHide") end
	end
	function Methods:SetShown(isShown) if isShown then self:Show() else self:Hide() end end
	function Methods:SetScript(event, handler) self.scripts[event] = handler Touch(self) end
	function Methods:GetScript(event) return self.scripts[event] end
	function Methods:HookScript(event, handler)
		self.hooks[event] = self.hooks[event] or {}
		table.insert(self.hooks[event], handler)
		Touch(self)
	end
	function Methods:SetSize(width, height) Store(self, "SetWidth", width) Store(self, "SetHeight", height) end
	function Methods:GetEffectiveScale()
		return (self:GetScale() or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
	end
	function Methods:SetPoint(point, relative, relativePoint, x, y)
		if type(relative) ~= "table" then relative, relativePoint, x, y = self.parent, relative, relativePoint, x end
		local anchor = point .. ">" .. Serialize(relative) .. ":" .. Serialize(relativePoint or point)
			.. ":" .. (x or 0) .. ":" .. (y or 0)
		-- Like the game, an anchor replaces the one that already has the same point.
		for index, existing in ipairs(self.points) do
			if existing:match("^[^>]+") == point then self.points[index] = anchor Touch(self) return end
		end
		self.points[#self.points + 1] = anchor
		Touch(self)
	end
	function Methods:SetAllPoints(relative) self.points = { "ALL>" .. Serialize(relative or self.parent) } Touch(self) end
	function Methods:ClearAllPoints() self.points = {} Touch(self) end
	function Methods:GetNumPoints() return #self.points end
	function Methods:CreateTexture(_, layer)
		local region = NewObject("Texture", self)
		Store(region, "layer", layer)
		self.regions[#self.regions + 1] = region
		return region
	end
	function Methods:CreateFontString(_, layer, template)
		local region = NewObject("FontString", self)
		Store(region, "layer", layer)
		Store(region, "template", template)
		self.regions[#self.regions + 1] = region
		return region
	end
	for _, state in ipairs(STATES) do
		Methods["Set" .. state .. "Texture"] = function(self, path)
			local texture = rawget(self, state)
			if not texture then
				texture = NewObject("Texture", self)
				rawset(self, state, texture)
				self.regions[#self.regions + 1] = texture
			end
			if type(path) == "string" then Store(texture, "SetTexture", path) end
		end
		Methods["Get" .. state .. "Texture"] = function(self) return rawget(self, state) end
	end
	function Methods:SetText(text)
		if self.fontString then return self.fontString:SetText(text) end
		local changed = self.props.SetText == nil or self.props.SetText[1] ~= text
		Store(self, "SetText", text or "")
		if changed and self.kind:lower() == "editbox" then Fire(self, "OnTextChanged") end
	end
	function Methods:GetText()
		if self.fontString then return self.fontString:GetText() end
		return self.props.SetText and self.props.SetText[1] or ""
	end
	function Methods:GetStringWidth() return #self:GetText() * 6 end
	function Methods:SetFontString(fontString) self.fontString = fontString end
	function Methods:GetFontString() return self.fontString end
	function Methods:Enable() self.enabled = true Touch(self) end
	function Methods:Disable() self.enabled = false Touch(self) end
	function Methods:IsEnabled() return self.enabled end
	function Methods:SetMinMaxValues(minValue, maxValue)
		self.minValue, self.maxValue = minValue, maxValue
		Touch(self)
		self:SetValue(self.value)
	end
	function Methods:SetValue(value)
		value = math.max(self.minValue, math.min(self.maxValue, value))
		if value == self.value then return end
		self.value = value
		Touch(self)
		Fire(self, "OnValueChanged", value)
	end
	function Methods:GetValue() return self.value end
	function Methods:GetValueStep() return self.props.SetValueStep and self.props.SetValueStep[1] or 1 end

	G.CreateFrame = function(kind, name, parent, template)
		local frame = NewObject(kind, parent, name)
		Store(frame, "template", template)
		if template and template:find("Scroll%a+ButtonTemplate") then
			frame:SetNormalTexture() frame:SetPushedTexture() frame:SetDisabledTexture()
		end
		return frame
	end
	G.UIParent = NewObject("Frame", nil, "UIParent")
	G.ColorPickerFrame = NewObject("Frame", nil, "ColorPickerFrame")
	G.UISpecialFrames = {}
	G.PlaySound = Noop
	G.SOUNDKIT = { IG_MAINMENU_OPTION = 850 }
	G.FillLocalizedClassList = Noop
	G.GetLocale = function() return "enUS" end
	G.Enum = { ItemQuality = { Poor = 0, Epic = 4 } }
	G.ITEM_QUALITY_COLORS = {}
	for quality = 0, 4 do G["ITEM_QUALITY" .. quality .. "_DESC"] = "Quality" .. quality end
	G.GameTooltip = setmetatable({}, { __index = function() return Noop end })
	G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
	G.HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
	-- Like the client: Blizzard's options art is there, so the new design wears it.
	G.C_Texture = { GetAtlasInfo = function() return { width = 1, height = 1 } end }
	-- The preview reopens the new window after a delay; here at once.
	G.C_Timer = { After = function(_, callback) callback() end }
	setmetatable(G, { __index = function(_, key)
		if type(key) == "string" and key:match("Font") and key:match("^%u") then
			G[key] = { fontName = key }
			return G[key]
		end
		return _G[key]
	end })
	G.hooksecurefunc = function(owner, name, hook)
		local original = owner[name]
		owner[name] = function(...) local result = original(...) hook(...) return result end
	end
	return world
end

-- The profile store the options call, with the same entry points as the real one.
local function NewProfiles(world)
	local G = world.G
	local saved = { profiles = { Default = {}, Alt = {} } }
	local perChar = { currentProfileName = "Default" }
	local function Copy(source)
		local copy = {}
		for key, value in pairs(source) do copy[key] = type(value) == "table" and Copy(value) or value end
		return copy
	end
	-- A profile reads what it does not hold from the master profile.
	local events = setmetatable({}, { __index = function() return { scrollArea = "Incoming",
		colorR = 1, colorG = 1, colorB = 1, message = "%a" } end })
	local master = { animationSpeed = 100, normalFontSize = 18, normalFontAlpha = 100,
		normalOutlineIndex = 1, normalFontName = "Default", critFontSize = 24, critFontAlpha = 100,
		critOutlineIndex = 1, critFontName = "Default", qualityExclusions = {}, events = events, scrollAreas = {} }
	-- Colour entries of the partial effects and classes, which their popups read.
	for name in ("crushing glancing absorb block resist overheal overkill DEATHKNIGHT DRUID HUNTER MAGE MONK"
		.. " PALADIN PRIEST ROGUE SHAMAN WARLOCK WARRIOR DEMONHUNTER EVOKER"):gmatch("%a+") do
		master[name] = { colorR = 1, colorG = 1, colorB = 1, trailer = "" }
	end
	for _, profile in pairs(saved.profiles) do setmetatable(profile, { __index = master }) end
	local Profiles = { savedVariables = saved, currentProfile = saved.profiles.Default,
		masterProfile = { scrollAreas = {} }, savedMedia = { sounds = {} } }
	local function Select(name) perChar.currentProfileName = name Profiles.currentProfile = saved.profiles[name] end
	function Profiles.SetOption(section, key, value)
		local target = Profiles.currentProfile
		for part in (section or ""):gmatch("[^.]+") do
			target[part] = target[part] or {}
			target = target[part]
		end
		target[key] = value
	end
	function Profiles.SelectProfile(name) Select(name) end
	function Profiles.CopyProfile(source, target) saved.profiles[target] = Copy(saved.profiles[source]) end
	function Profiles.IsModDisabled() return saved.userDisabled end
	function Profiles.SetOptionUserDisabled(isDisabled) saved.userDisabled = isDisabled or nil end
	for _, name in ipairs({ "ApplyContextOptions", "ResetProfile", "DeleteProfile", "ImportProfile",
		"ExportProfile", "ResetOfficialBlizzardCombatText" }) do Profiles[name] = Noop end
	local areas = {}
	local styles = {}
	for _, name in ipairs({ "Straight", "Pow" }) do
		styles[name] = { availableDirections = "Up;Down", availableBehaviors = "MSBT_NORMAL" }
	end
	for _, name in ipairs({ "Incoming", "Outgoing", "Notification", "Static" }) do
		areas[name] = { name = name, offsetX = 0, offsetY = 0, animationStyle = "Straight", textAlignIndex = 2,
			stickyAnimationStyle = "Pow", direction = "Up", behavior = "MSBT_NORMAL", normalFontName = "Default",
			normalOutlineIndex = 1, normalFontSize = 18, normalFontAlpha = 100, critFontName = "Default",
			critOutlineIndex = 1, critFontSize = 24, critFontAlpha = 100, animationSpeed = 100 }
	end
	master.scrollAreas = areas
	G.MikSBT = {
		VERSION_STRING = "test", translations = {}, Profiles = Profiles, Print = Noop,
		Compatibility = { Client = { hasModernAPI = true, isClassicContent = false } },
		Configuration = { AuraTracking = {} }, Services = { Formatter = setmetatable({}, { __index = function()
			return function() return "" end end }) }, API = { Spells = {}, Sounds = {} },
		EraseTable = function(value) for key in next, value do value[key] = nil end end,
		Animations = { scrollAreas = areas, animationStyles = styles, stickyAnimationStyles = styles,
			UpdateScrollAreas = Noop },
		Media = { fonts = {}, sounds = {}, PlaySound = Noop, IterateSounds = function() return next, {} end },
		Main = { damageColorProfileEntries = {}, damageTypeMap = {} },
		DisplayMessage = Noop, CopyTable = Copy,
	}
	setfenv(assert(loadfile("Configuration/ProfileSnapshots.lua")), G)()
	local snapshots = G.MikSBT.Configuration.ProfileSnapshots:New({
		savedVariables = saved, savedVariablesPerChar = perChar, selectProfile = Select })
	function Profiles.GetProfileSnapshots() return snapshots end
	snapshots:UpdateLoginSnapshot(true)
end

-- Loads the options files in the order of the TOC.
local function LoadOptions(world)
	NewProfiles(world)
	local files = { "MSBTOptions/Localization/localization.lua" }
	for line in io.lines("MSBTOptions/MSBTOptions.toc") do
		if line:match("%.lua%s*$") then files[#files + 1] = "MSBTOptions/" .. line:gsub("%s+$", ""):gsub("\\", "/") end
	end
	for _, path in ipairs(files) do
		setfenv(assert(loadfile(path)), world.G)()
		local Options = world.G.MSBTOptions
		-- Popups register with the main window, which hides them; the harness keeps its own list.
		if path:find("OptionsMain.lua", 1, true) then
			local Main, register = Options.Main, Options.Main.RegisterPopupFrame
			world.popups = {}
			Main.RegisterPopupFrame = function(frame) world.popups[frame] = true register(frame) end
		-- Which design's popups are in use names the popups made from here on.
		elseif path:find("OptionsPopups.lua", 1, true) then
			local use = Options.Popups.UseDesignPopups
			Options.Popups.UseDesignPopups = function(key) world.designPopups = key ~= "classic" use(key) end
		-- Only a popup made for the new design may receive its skin.
		elseif path:find("/Window.lua", 1, true) then
			local design = Options.Designs.designs.forever
			local skin = design.SkinPopup
			design.SkinPopup = function(frame)
				-- Recorded apart from the flag that names the popups, which the code under test also sets.
				world.skinned[frame] = true
				if not frame.id:find("^design:") then
					world.errors[#world.errors + 1] = "the new design skinned the classic popup " .. frame.id
				end
				skin(frame)
			end
		end
	end
end

local function InNewWindow(world, obj)
	local window = world.G.MSBTOptionsWindowFrame
	local node = obj
	while node do
		if node.singleton then return false end
		if node == window then return true end
		node = node.creator
	end
	return false
end

-- Every visual property of a classic or shared object, as property -> value.
local function Describe(world, obj)
	local map = {}
	-- The color picker is the game's own, and the measuring string is never drawn.
	if obj.id == "ColorPickerFrame" or (obj.kind == "FontString" and obj.parent == world.G.UIParent)
		or InNewWindow(world, obj) then return map end
	local function Put(property, value) map[property] = tostring(value) end
	Put("kind", obj.kind)
	Put("parent", obj.parent and obj.parent.id or "nil")
	Put("shown", obj.shown)
	Put("enabled", obj.enabled)
	Put("effectiveScale", obj:GetEffectiveScale())
	Put("points", table.concat(obj.points, " ; "))
	Put("value", obj.value .. "/" .. obj.minValue .. "/" .. obj.maxValue)
	local scripts = {}
	for event in pairs(obj.scripts) do scripts[#scripts + 1] = event end
	for event in pairs(obj.hooks) do scripts[#scripts + 1] = "hook:" .. event end
	table.sort(scripts)
	Put("scripts", table.concat(scripts, ","))
	for key, packed in pairs(obj.props) do Put("set." .. key, SerializeArgs(packed)) end
	return map
end
local function Try(world, label, func, ...)
	local ok, message = pcall(func, ...)
	if not ok then world.errors[#world.errors + 1] = label .. ": " .. tostring(message) end
	return ok
end
local function Snap(world, label)
	local delta = {}
	for _, obj in ipairs(world.dirty) do
		obj.dirty = false
		local old, new = obj.dumped or {}, Describe(world, obj)
		for property, value in pairs(new) do
			if old[property] ~= value then delta[obj.id .. " | " .. property] = value end
		end
		for property in pairs(old) do
			if new[property] == nil then delta[obj.id .. " | " .. property] = "<removed>" end
		end
		obj.dumped = new
	end
	world.dirty = {}
	world.steps[#world.steps + 1] = { label = label, delta = delta }
end

local function Visible(obj)
	while obj do
		if not obj.shown then return false end
		obj = obj.parent
	end
	return true
end
local function Click(button)
	if button.enabled and (button.scripts.OnClick or button.hooks.OnClick) then button:fire("OnClick") end
end
local function Collect(world, predicate)
	local found = {}
	for _, obj in ipairs(world.all) do
		if predicate(obj) then found[#found + 1] = obj end
	end
	return found
end

-- Opens the list of every visible dropdown, dumps it and closes the shared list again.
local function OpenDropdowns(world, label)
	for _, dropdown in ipairs(Collect(world, function(obj) return obj.buttonFrame and Visible(obj) end)) do
		if Try(world, label .. "/" .. dropdown.id, Click, dropdown.buttonFrame) then
			-- The new design opens a list of its own and leaves the shared one alone.
			if label:find("^new") and world.sharedList.shown then
				world.errors[#world.errors + 1] = label .. ": the shared list opened for " .. dropdown.id
			end
			Snap(world, label .. " list of " .. dropdown.id)
			if world.sharedList.shown then Click(dropdown.buttonFrame) end
			Snap(world, label .. " list closed")
		end
	end
end

-- A popup a classic window shows must be none of those the new design's skin reached.
local function CheckClassicPopups(world, label)
	if not (label:find("^classic") or label:find("^docked")) then return end
	for popup in pairs(world.popups) do
		if popup.shown then
			world.shownClassic = world.shownClassic + 1
			if world.skinned[popup] then
				world.errors[#world.errors + 1] = label .. ": the classic window shows the skinned popup " .. popup.id
			end
		end
	end
end

-- Presses every visible option button that opens a popup, with the dropdowns in it.
local function OpenPopups(world, label)
	local popups = {}
	for _, button in ipairs(Collect(world, function(obj)
		return obj.site == "CreateOptionButton" and Visible(obj) and obj.enabled
	end)) do
		popups[#popups + 1] = button
	end
	for _, button in ipairs(popups) do
		if Visible(button) and Try(world, label .. "/" .. button.id, Click, button) then
			CheckClassicPopups(world, label)
			Snap(world, label .. " popup of " .. button.id)
			OpenDropdowns(world, label .. " popup")
			for popup in pairs(world.popups) do popup:Hide() end
			Snap(world, label .. " popups closed")
		end
	end
end

-- Opens every popup the options can show above a window, with the dropdowns in it, so each
-- design shows each of its popups at least once.
local POPUPS = { "ShowAcknowledge", "ShowInput", "ShowFont", "ShowPartialEffects", "ShowDamageColors",
	"ShowClassColors", "ShowItemList", "ShowScrollAreaSelection", "ShowEvent" }
local function OpenEveryPopup(world, label, parent)
	local Options = world.G.MSBTOptions
	local opened = { ShowImport = Options.ProfileTransfer.ShowImport }
	for _, name in ipairs(POPUPS) do opened[name] = Options.Popups[name] end
	for _, name in ipairs({ "ShowImport", unpack(POPUPS) }) do
		local config = { parentFrame = parent, anchorFrame = parent, title = name, items = { Hearthstone = true } }
		for _, kind in ipairs({ "normal", "crit", "inheritedNormal", "inheritedCrit" }) do
			config[kind .. "FontName"], config[kind .. "OutlineIndex"] = "Default", 1
			config[kind .. "FontSize"], config[kind .. "FontAlpha"] = 18, 100
		end
		if Try(world, label .. "/" .. name, opened[name], config) then
			CheckClassicPopups(world, label)
			Snap(world, label .. " popup " .. name)
			OpenDropdowns(world, label .. " popup " .. name)
			for popup in pairs(world.popups) do popup:Hide() end
			Snap(world, label .. " popups closed")
		end
	end
end

local function Under(obj, root)
	while obj do
		if obj == root then return true end
		obj = obj.parent
	end
	return false
end

-- Chooses an option of the visible options design dropdown, as a click on its list does; the
-- classic window's list is the shared one, the new window's a list under the dropdown.
-- Like /msbt followed by a design, or alone without one: the choice is saved and the options open.
local function Command(world, design)
	local Designs = world.G.MSBTOptions.Designs
	if design then assert(Designs.Select(design), "no design " .. design) end
	Designs.Show()
end

local function ChooseDesign(world, id)
	local dropdown = assert(Collect(world, function(obj)
		return obj.buttonFrame and obj.itemIDs and obj.itemIDs[1] == "classic" and Visible(obj)
	end)[1], "no visible design dropdown")
	Click(dropdown.buttonFrame)
	for index, itemID in ipairs(dropdown.itemIDs) do
		if itemID == id then
			for _, line in ipairs(Collect(world, function(obj)
				return obj.itemNumber == index and Visible(obj) and (Under(obj, world.sharedList) or Under(obj, dropdown))
			end)) do
				Click(line)
			end
		end
	end
end

-- Like a click on "Configure on screen": the configuration replaces the window with a mover per
-- area, follows another area chosen in its dropdown and gives the window back when it closes.
local function ConfigureOnScreen(world, round)
	local handler = world.G.MSBTOptions.Tabs.scrollAreas.ConfigureOnScreen
	Click(assert(Collect(world, function(obj) return obj.clickHandler == handler and Visible(obj) end)[1],
		"no visible Configure on screen button"))
	local config = world.G.MSBTScrollAreasConfigFrame
	assert(config and config.shown, "the scroll area configuration did not open")
	Snap(world, round .. " on screen")
	config.scrollAreaDropdown:SetSelectedID("Outgoing")
	config.scrollAreaDropdown:changeHandler("Outgoing")
	Snap(world, round .. " on screen, another area")
	config:Hide()
	Snap(world, round .. " on screen closed")
end

local function SelectTab(world, tab)
	local lines = Collect(world, function(obj)
		return obj.itemNumber and obj.parent and obj.parent.parent and obj.parent.parent.items
			and obj.parent.parent.items[obj.itemNumber] == tab.index and Visible(obj)
			and obj.parent.parent.parent == world.G.MSBTMainOptionsFrame
	end)
	Click(assert(lines[#lines], "no tab line"))
end

-- Like the game: the classic window opens through the options command, every tab is chosen
-- with a click on its line, and each tab gets its lists and popups opened.
local function ClassicWalk(world, round)
	local Main = world.G.MSBTOptions.Main
	Command(world, "classic")
	assert(world.G.MSBTMainOptionsFrame.shown, "the classic window did not open")
		Snap(world, round .. " opened")
	for _, tab in ipairs(Main.GetTabs()) do
		Try(world, round .. " tab " .. tab.text, SelectTab, world, tab)
		Snap(world, round .. " tab " .. tab.text)
		OpenDropdowns(world, round .. " " .. tab.text)
		OpenPopups(world, round .. " " .. tab.text)
	end
	OpenEveryPopup(world, round, world.G.MSBTMainOptionsFrame)
	for _, tab in ipairs(Main.GetTabs()) do
		if tab.text == world.G.MikSBT.translations.TABS.scrollAreas.label then
			Try(world, round .. " scroll areas", SelectTab, world, tab)
		end
	end
	Try(world, round .. " on screen", ConfigureOnScreen, world, round)
	Try(world, round .. " general", SelectTab, world, Main.GetTabs()[1])
	Snap(world, round .. " end")
end

-- Like the Settings panel: each tab has a panel that docks the classic view on its tab, and the
-- options command then has nothing to open. The new design is chosen, which must change nothing.
local function DockedWalk(world, round)
	local G = world.G
	local Main, Window = G.MSBTOptions.Main, G.MSBTOptions.Window
	assert(G.MSBTOptions.Designs.Select("forever"))
	for _, tab in ipairs(Main.GetTabs()) do
		local panel = G.CreateFrame("Frame", nil, G.UIParent)
		Main.DockMainFrame(panel, Noop, tab.index)
		Command(world)
		assert(Main.IsDocked() and not Window.IsShown(), round .. ": the new window opened beside the docked view")
		Snap(world, round .. " tab " .. tab.text)
		OpenDropdowns(world, round .. " " .. tab.text)
		OpenPopups(world, round .. " " .. tab.text)
		if tab.isGeneral then OpenEveryPopup(world, round, G.MSBTMainOptionsFrame) end
		Main.UndockMainFrame(panel)
	end
end

local function ClickEntry(world, key)
	Click(assert(Collect(world, function(obj) return obj.key == key end)[1], "no entry " .. key))
end

-- The new window: every sidebar page, its dropdowns and popups, the search field.
local function NewWindowWalk(world, round)
	local G = world.G
	Command(world, "forever")
	assert(G.MSBTOptions.Window.IsShown(), "the new window did not open")
	for _, entry in ipairs(Collect(world, function(obj) return obj.key and obj.scripts.OnClick end)) do
		Try(world, round .. " page " .. entry.key, Click, entry)
		Snap(world, round .. " page " .. entry.key)
		OpenDropdowns(world, round .. " " .. entry.key)
		OpenPopups(world, round .. " " .. entry.key)
	end
	OpenEveryPopup(world, round, G.MSBTOptionsWindowFrame)
	local search = Collect(world, function(obj) return obj.kind:lower() == "editbox" and Visible(obj) end)[1]
	search:SetText("font")
	Snap(world, round .. " search")
	search:SetText("")
	Snap(world, round .. " search cleared")
	ClickEntry(world, "scrollAreas")
	Try(world, round .. " on screen", ConfigureOnScreen, world, round)
	ClickEntry(world, "general")
end

local function Run(scenario)
	local world = NewWorld()
	world.errors = {}
	LoadOptions(world)
	scenario(world)
	return world
end

local function Indexes(world, round)
	local indexes = {}
	for index, step in ipairs(world.steps) do
		if step.label:sub(1, #round + 1) == round .. " " then indexes[#indexes + 1] = index end
	end
	return indexes
end

-- An object is hidden when it or an object it was created under is.
local function IsHidden(state, id)
	while id do
		if state[id .. " | shown"] == "false" then return true end
		id = id:match("^(.*)/[^/]*$")
	end
	return false
end

-- Steps keep only what changed; the two states are rebuilt in step and compared in full at the
-- first and the last step of the round, in between on the keys that changed.
local function Differences(first, second, round)
	local worlds, states, cursors = { first, second }, { {}, {} }, { 1, 1 }
	local indexes = { Indexes(first, round), Indexes(second, round) }
	assert(#indexes[1] > 0 and #indexes[1] == #indexes[2], round .. " has a different number of steps")
	local found, seen, compared, objects = {}, {}, 0, {}
	for n = 1, #indexes[1] do
		local touched = {}
		for side = 1, 2 do
			for index = cursors[side], indexes[side][n] do
				for key, value in pairs(worlds[side].steps[index].delta) do
					states[side][key] = value ~= "<removed>" and value or nil
					if index == indexes[side][n] then touched[key] = true end
				end
			end
			cursors[side] = indexes[side][n] + 1
		end
		local label = first.steps[indexes[1][n]].label
		assert(label == second.steps[indexes[2][n]].label, "steps differ: " .. label)
		if n == 1 or n == #indexes[1] then
			for side = 1, 2 do for key in pairs(states[side]) do touched[key] = true end end
		end
		for key in pairs(touched) do
			-- A closed shared list is configured again on every open, so only later steps compare it.
			local isClosedList = n == 1 and key:sub(1, 18) == "SharedDropdownList"
			-- A hidden object only one side has built, such as a spare list line, is not a difference.
			local id = key:match("^(.-) | ")
			local isAbsent = states[1][id .. " | kind"] == nil or states[2][id .. " | kind"] == nil
			local isSpare = isAbsent and (IsHidden(states[1], id) or IsHidden(states[2], id))
			-- Controls the classic window builds when a tab first shows may not exist yet in the other run.
			isSpare = isSpare or (isAbsent and n == 1)
			if not isClosedList and not isSpare then
				compared = compared + 1
				objects[id] = true
			end
			if states[1][key] ~= states[2][key] and not isClosedList and not isSpare then
				local line = "[" .. label .. "] " .. key .. " : " .. tostring(states[1][key])
					.. " <-> " .. tostring(states[2][key])
				if not seen[line] then seen[line] = true found[#found + 1] = line end
			end
		end
	end
	table.sort(found)
	return found, #indexes[1], compared, objects
end

-- Presses the visible button with the given tooltip under root.
local function Press(world, root, tooltip)
	Click(assert(Collect(world, function(obj)
		return obj.tooltip == tooltip and obj.clickHandler and Visible(obj) and Under(obj, root)
	end)[1], "no visible button " .. tooltip))
end

-- Like a click on "Configure on screen" in the new window, after Incoming was moved and previewed:
-- the preview saves the moved area, so only a cancel puts it back.
local function OnScreenFromNewWindow(world, classicBuilt)
	local G = world.G
	world.classicPopups = G.MSBTOptions.Popups.GetPopupFrames()
	if classicBuilt then Command(world, "classic") end
	Command(world, "forever")
	world.newShown = 0
	G.MSBTOptionsWindowFrame:HookScript("OnShow", function() world.newShown = world.newShown + 1 end)
	ClickEntry(world, "scrollAreas")
	local handler = G.MSBTOptions.Tabs.scrollAreas.ConfigureOnScreen
	Click(assert(Collect(world, function(obj) return obj.clickHandler == handler and Visible(obj) end)[1],
		"no visible Configure on screen button"))
	local config = assert(G.MSBTScrollAreasConfigFrame, "the scroll area configuration did not open")
	config.previewSettings.Incoming.offsetX = 77
	Press(world, config, G.MikSBT.translations.BUTTONS.scrollAreasPreview.tooltip)
	assert(G.MikSBT.Animations.scrollAreas.Incoming.offsetX == 77, "the preview saved nothing, so it proves nothing")
	return config
end

-- The new window's Cancel after a change made elsewhere: true when the change stays, so the base
-- Cancel returns to was taken after it. False when the new window does not open.
local function FreshCancelBase(world)
	local G = world.G
	G.MikSBT.Profiles.SetOption(nil, "stackSimilarHits", true)
	Command(world)
	if not G.MSBTOptionsWindowFrame.shown then return false end
	Press(world, G.MSBTOptionsWindowFrame, G.MikSBT.translations.WINDOW.cancelTooltip)
	return rawget(G.MikSBT.Profiles.currentProfile, "stackSimilarHits") == true
end

-- Given the configuration on screen from the new window, when the game's settings window docks the
-- classic view, once before the classic window was ever built and once after.
for _, classicBuilt in ipairs({ false, true }) do
	local label = classicBuilt and "docked, classic built" or "docked, classic not built"
	local docked = {}
	local world = Run(function(world)
		local G = world.G
		local config = OnScreenFromNewWindow(world, classicBuilt)
		local panel = G.CreateFrame("Frame", nil, G.UIParent)
		G.MSBTOptions.Main.DockMainFrame(panel, Noop)
		docked.shown = G.MSBTOptions.Main.IsDocked() and Visible(G.MSBTMainOptionsFrame)
		docked.popups = G.MSBTOptions.Popups.GetPopupFrames()
		docked.configShown = config.shown
		docked.offsetX = G.MikSBT.Animations.scrollAreas.Incoming.offsetX
		docked.newShown = world.newShown
		G.MSBTOptions.Main.UndockMainFrame(panel)
		docked.freshBase = FreshCancelBase(world)
	end)
	-- Then the classic view takes over with its popups, the configuration ends as cancelled, the new
	-- window never shows in between, and its Cancel base from before is gone.
	assert(docked.shown, label .. ": the classic view is not docked and shown")
	assert(docked.popups == world.classicPopups, label .. ": the classic popups are not in use")
	assert(not docked.configShown, label .. ": the configuration stayed open")
	assert(docked.offsetX == 0, label .. ": the configuration did not end as cancelled")
	assert(docked.newShown == 0, label .. ": the new window showed in between")
	assert(docked.freshBase, label .. ": the new window kept its Cancel base")
	assert(#world.errors == 0, label .. ": a step failed")
end

-- Given the configuration on screen from the new window, when /msbt classic chooses the classic
-- design, once before the classic window was ever built and once after, and the configuration is
-- saved afterwards.
for _, classicBuilt in ipairs({ false, true }) do
	local label = classicBuilt and "/msbt classic, classic built" or "/msbt classic, classic not built"
	local during, config = {}
	local world = Run(function(world)
		local G = world.G
		config = OnScreenFromNewWindow(world, classicBuilt)
		Command(world, "classic")
		during.configShown = config.shown
		during.classicShown = G.MSBTMainOptionsFrame ~= nil and Visible(G.MSBTMainOptionsFrame)
		during.newShown = G.MSBTOptionsWindowFrame.shown
		Press(world, config, G.MikSBT.translations.BUTTONS.genericSave.tooltip)
	end)
	local G = world.G
	-- Then nothing opens while the configuration is open, and the classic window opens when it ends.
	assert(during.configShown and not during.classicShown and not during.newShown,
		label .. ": a window opened over the configuration")
	assert(G.MSBTMainOptionsFrame and Visible(G.MSBTMainOptionsFrame) and not G.MSBTOptionsWindowFrame.shown
		and not config.shown, label .. ": not exactly the classic window is open at the end")
	assert(G.MikSBT.Animations.scrollAreas.Incoming.offsetX == 77, label .. ": the saved configuration was lost")
	assert(#world.errors == 0, label .. ": a step failed")
end

-- Given the configuration on screen from the new window, when /msbt asks for the options meanwhile
-- and the configuration is saved afterwards.
do
	local during, back = {}
	local world = Run(function(world)
		local G = world.G
		local config = OnScreenFromNewWindow(world, false)
		Command(world)
		during.configShown = config.shown
		during.newShown = G.MSBTOptionsWindowFrame.shown
		-- A window that opens closes the configuration, and then there is nothing left to save.
		if config.shown then Press(world, config, G.MikSBT.translations.BUTTONS.genericSave.tooltip) end
		back = G.MSBTOptionsWindowFrame.shown and not config.shown
	end)
	-- Then the new window, which has no check of its own, stays away while the configuration is
	-- open and comes back when it ends.
	assert(during.configShown and not during.newShown, "the new window opened over the configuration")
	assert(back, "the new window did not come back after the configuration")
	assert(#world.errors == 0, "a step failed")
end

-- Given the configuration on screen from the new window after a change, when it is saved or cancelled.
for _, button in ipairs({ "genericSave", "genericCancel" }) do
	local back, keptBase
	local world = Run(function(world)
		local G = world.G
		local Profiles = G.MikSBT.Profiles
		Command(world, "forever")
		Profiles.SetOption(nil, "shortenNumbers", true)
		-- The classic window is never built here, so nothing but the new window can come back.
		local config = OnScreenFromNewWindow(world, false)
		Press(world, config, G.MikSBT.translations.BUTTONS[button].tooltip)
		back = G.MSBTOptionsWindowFrame.shown and not G.MSBTMainOptionsFrame
			and G.MSBTOptions.Popups.GetPopupFrames().scrollAreaConfigFrame == config
		if back then
			Press(world, G.MSBTOptionsWindowFrame, G.MikSBT.translations.WINDOW.cancelTooltip)
			keptBase = rawget(Profiles.currentProfile, "shortenNumbers") == nil
		end
	end)
	-- Then the new window comes back alone with its popups, and Cancel still returns to its base.
	assert(back, button .. ": the new window did not come back alone with its popups")
	assert(keptBase, button .. ": the configuration moved the new window's Cancel base")
	assert(#world.errors == 0, button .. ": a step failed")
end

-- Given a popup of the new design open above its window, when the window closes.
do
	local open = {}
	local world = Run(function(world)
		local G = world.G
		Command(world, "forever")
		local window = G.MSBTOptionsWindowFrame
		G.MSBTOptions.Popups.ShowAcknowledge({ parentFrame = window, anchorFrame = window })
		local popup = G.MSBTOptions.Popups.GetPopupFrames().acknowledgeFrame
		open.before = popup.shown
		G.MSBTOptions.Designs.designs.forever.Hide()
		open.after = popup.shown
	end)
	-- Then the shared HidePopups closed the popup with the window.
	assert(open.before and not open.after, "the new design's popup stayed open after its window closed")
	assert(#world.errors == 0, "the popup walk failed")
end

-- Given a third design with a skin of its own, when each design opens every popup.
do
	local sets = {}
	local world = Run(function(world)
		local G = world.G
		local Popups = G.MSBTOptions.Popups
		world.thirdSkinned = {}
		G.MSBTOptions.Designs.Register("third", { label = "Third", Show = Noop, Hide = Noop,
			IsShown = function() return false end, SkinPopup = function(frame) world.thirdSkinned[frame] = true end })
		local parent = G.CreateFrame("Frame", nil, G.UIParent)
		for _, key in ipairs({ "forever", "third", "classic" }) do
			Popups.UseDesignPopups(key)
			OpenEveryPopup(world, key, parent)
			sets[key] = Popups.GetPopupFrames()
		end
	end)
	-- Then the third design's popups are its own and wore its skin alone, the new design's never
	-- wore it, and no classic popup went through a skin.
	for name, frame in pairs(sets.forever) do
		assert(world.skinned[frame] and not world.thirdSkinned[frame], "the new design's " .. name .. " wore the wrong skin")
	end
	local third = 0
	for name, frame in pairs(sets.third) do
		third = third + 1
		assert(frame ~= sets.forever[name] and frame ~= sets.classic[name], "the third design shares the popup " .. name)
		assert(world.thirdSkinned[frame] and not world.skinned[frame], "the third design's " .. name .. " wore the wrong skin")
	end
	assert(third > 0, "the third design opened no popup, so it proves nothing")
	for name, frame in pairs(sets.classic) do
		assert(not world.skinned[frame] and not world.thirdSkinned[frame], "the classic " .. name .. " went through a skin")
	end
	assert(#world.errors == 0, "the third design's walk failed")
end

-- Given the classic window alone, walked twice.
local classic = Run(function(world)
	ClassicWalk(world, "classic1")
	world.G.MSBTOptions.Main.HideMainFrame()
	ClassicWalk(world, "classic2")
end)

-- Given the new window used first, then switched to classic and back by the design dropdown.
local mixed = Run(function(world)
	NewWindowWalk(world, "new1")
	ClickEntry(world, "general")
	ChooseDesign(world, "classic")
	assert(world.G.MSBTMainOptionsFrame.shown, "choosing classic did not open the classic window")
	ClassicWalk(world, "classic1")
	-- When the classic General tab chooses the new design, and the new window chooses classic again.
	local Main = world.G.MSBTOptions.Main
	SelectTab(world, Main.GetTabs()[1])
	ChooseDesign(world, "forever")
	NewWindowWalk(world, "new2")
	ClickEntry(world, "general")
	ChooseDesign(world, "classic")
	ClassicWalk(world, "classic2")
end)

-- Then the classic window is the same in both orders, in both rounds.
local failures, steps, compared, objects = {}, 0, 0, {}
for _, round in ipairs({ "classic1", "classic2" }) do
	local found, roundSteps, roundCompared, roundObjects = Differences(classic, mixed, round)
	for _, difference in ipairs(found) do failures[#failures + 1] = difference end
	steps, compared = steps + roundSteps, compared + roundCompared
	for id in pairs(roundObjects) do objects[id] = true end
end
for _, message in ipairs(classic.errors) do print("alone: " .. message) end
for _, message in ipairs(mixed.errors) do print("mixed: " .. message) end
for index = 1, math.min(#failures, 40) do print(failures[index]) end
assert(#classic.errors == 0 and #mixed.errors == 0, "a walk step failed")
assert(#failures == 0, #failures .. " classic properties differ after the new window was used")
-- And the walks reached the movers: the classic ones were compared, the new design's wear its skin.
local classicMovers, skinnedMovers = 0, 0
for id in pairs(objects) do
	if id:find("CreateScrollAreaMoverFrame", 1, true) and not id:find("^design:") then classicMovers = classicMovers + 1 end
end
for _, obj in ipairs(mixed.all) do
	if obj.site == "CreateScrollAreaMoverFrame" and obj.id:find("^design:") and obj.scripts.OnEnter then
		skinnedMovers = skinnedMovers + 1
	end
end
assert(classicMovers > 0 and skinnedMovers > 0, "the walks compared no classic mover or skinned none of the new design")
local objectCount = 0
for _ in pairs(objects) do objectCount = objectCount + 1 end
print(string.format("classic design intact: 2 rounds, %d steps, %d objects, %d properties compared",
	steps, objectCount, compared))

-- Given the new design used first and the classic view then docked once per tab.
local docked = Run(function(world)
	NewWindowWalk(world, "new1")
	DockedWalk(world, "docked1")
end)

-- Then no popup the docked tabs opened is one the new design's skin reached.
for _, message in ipairs(docked.errors) do print("docked: " .. message) end
assert(#docked.errors == 0, "the docked walk failed")
assert(next(docked.skinned) and docked.shownClassic > 0, "the docked walk skinned or opened no popup, so it proves nothing")

-- Given the classic Profile tab was shown, and the profiles then change outside it, as an undo
-- in the new window does.
local profileDropdown
local relisted = Run(function(world)
	local G = world.G
	Command(world)
	local tabs = G.MSBTOptions.Main.GetTabs()
	local profileTab
	for _, tab in ipairs(tabs) do
		SelectTab(world, tab)
		local dropdown = Collect(world, function(obj)
			return obj.buttonFrame and obj.itemIDs and obj.itemIDs[1] == "Alt" and Visible(obj)
		end)[1]
		if dropdown then profileTab, profileDropdown = tab, dropdown end
	end
	assert(profileTab and #profileDropdown.itemIDs == 2, "the classic Profile tab does not list both profiles")
	local profiles = G.MikSBT.Profiles.savedVariables.profiles
	profiles.Restored, profiles.Alt = profiles.Alt, nil

	-- When another tab and then the Profile tab is shown again.
	SelectTab(world, tabs[1])
	SelectTab(world, profileTab)
end)

-- Then its list holds exactly the current profiles, with the current one selected.
assert(#relisted.errors == 0, "a step of the profile walk failed")
assert(#profileDropdown.itemIDs == 2 and profileDropdown.itemIDs[1] == "Default"
	and profileDropdown.itemIDs[2] == "Restored", "the classic Profile tab lists stale profiles")
assert(profileDropdown:GetSelectedID() == "Default", "the current profile is not selected")
