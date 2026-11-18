-- Describe: the developer tab is offered while the debug window is loaded and shows the generated tables.
local function Noop() end
local function NewFrame(name, parent)
	local frame = { name = name, parent = parent, scripts = {}, regions = {}, shown = false, items = {} }
	setmetatable(frame, { __index = function(_, key)
		if key:match("^[A-Z]") then return Noop end
	end })
	function frame:GetName() return self.name end
	function frame:SetScript(event, callback) self.scripts[event] = callback end
	function frame:IsShown() return self.shown end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:AddItem(index) self.items[#self.items + 1] = index end
	function frame:SetPoint(...) self.point = { ... } end
	function frame:SetText(text) self.text = text end
	function frame:SetTextColor(r, g, b) self.color = { r, g, b } end
	function frame:Configure(_, label, tooltip) self.label, self.tooltip = label, tooltip end
	function frame:SetClickHandler(handler) self.click = handler end
	function frame:CreateFontString(_, _, template)
		local region = NewFrame(nil, self)
		region.template = template
		self.regions[#self.regions + 1] = region
		return region
	end
	frame.CreateTexture = frame.CreateFontString
	function frame:GetRegions() return unpack(self.regions) end
	return frame
end

UIParent = NewFrame("UIParent")
UISpecialFrames = {}
PlaySound = Noop
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_CATACLYSM_CLASSIC = 42, 1, 2, 5
GetBuildInfo = function() return "1.60.1", "70959", "Nov 13 2026", 16001 end
CreateFrame = function(_, name, parent) return NewFrame(name, parent) end

-- The tab's own functions out of the tabs file, with the registration of the tab.
local file = assert(io.open("MSBTOptions/MSBTOptionsTabs.lua", "r"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local tabSource = assert(source:match("(local DEVELOPER_TABLES_TOP.-\nmodule%.developer = %b{})"))
local registerSource = assert(source:match("(objLocale = L%.TABS%.developer.-DeveloperTab_IsOffered%))"))

-- The files as they load up to the tabs file, each time anew: the tab list with the other tabs,
-- then the developer tab. The debug window is not loaded yet.
local main, developer, tabFrame, lists, L
local function Load()
	MikSBT = { VERSION_STRING = "test", translations = {} }
	dofile("Compatibility/Client.lua")
	-- The localization makes the options table, so it loads before the stubs go in.
	dofile("MSBTOptions/Localization/localization.lua")
	L = MikSBT.translations
	lists = {}
	MSBTOptions.Controls = {
		CreateListbox = function(parent)
			lists[#lists + 1] = NewFrame(nil, parent)
			return lists[#lists]
		end,
		CreateOptionButton = function(parent) return NewFrame(nil, parent) end,
	}
	MSBTOptions.Popups = { UseDesignPopups = Noop }
	MikSBT.Profiles = { savedVariables = {} }
	dofile("MSBTOptions/MSBTOptionsDesigns.lua")
	dofile("MSBTOptions/MSBTOptionsMain.lua")
	main = MSBTOptions.Main
	for _, tab in ipairs({ { "General" }, { "Profile", 8999.5 }, { "Events" }, { "Language", 9500 }, { "Reset", 9000 } }) do
		main.AddTab(NewFrame(), tab[1], nil, tab[2])
	end
	local module, tabFrames = {}, {}
	local build = assert(loadstring("local objLocale, tabFrame\n" .. tabSource .. "\n" .. registerSource))
	setfenv(build, setmetatable({ module = module, tabFrames = tabFrames, L = L,
		MSBTControls = MSBTOptions.Controls, MSBTOptMain = main }, { __index = _G }))
	build()
	developer, tabFrame = module.developer, tabFrames.developer
end
local function Names()
	local names = {}
	for _, tab in ipairs(main.GetTabs()) do names[#names + 1] = tab.text end
	return table.concat(names, ",")
end
local function Written()
	tabFrame.scripts.OnShow(tabFrame)
	local texts = {}
	for _, region in ipairs(tabFrame.regions) do texts[#texts + 1] = region.text end
	return table.concat(texts, "|")
end

-- Rule: without the debug window there is no developer tab.
do
	Load()
	assert(not developer.IsOffered(), "the tab is offered without the debug window")
	assert(Names() == "General,Events,Profile,Reset,Language", "a developer tab without the debug window: " .. Names())
end

-- Rule: a debug file that broke off while loading left its table without the function; no tab then.
do
	Load()
	MSBTOptions.Debug = {}
	assert(Names() == "General,Events,Profile,Reset,Language", "a developer tab for a broken debug window: " .. Names())
end

-- Rule: the tab waits for the files that load after the tabs, and joins below Profile.
do
	-- Given the tabs file has loaded and the debug window loads after it.
	Load()
	MSBTOptions.Debug = { Toggle = Noop }
	assert(developer.IsOffered(), "the tab is not offered with the debug window")
	-- When the tabs are listed, then the developer tab stands at the end of the upper list.
	assert(Names() == "General,Events,Profile,Developer,Reset,Language", "the developer tab is not below Profile: " .. Names())
	-- When they are asked again, then the tab does not come twice.
	assert(Names() == "General,Events,Profile,Developer,Reset,Language", "asked again, the developer tab comes twice: " .. Names())
end

-- Rule: the window is built without the tabs having been listed, as when another design stands in
-- the game's settings; its upper list has the tab all the same.
do
	Load()
	MSBTOptions.Debug = { Toggle = Noop }
	main.ShowMainFrame()
	assert(#lists == 3 and #lists[1].items == 4, "the upper list lacks the developer tab")
end

-- Rule: a design's developer page gets the same through four functions.
do
	Load()
	local names = {}
	for name, value in pairs(developer) do
		assert(type(value) == "function", name .. " is no function")
		names[#names + 1] = name
	end
	table.sort(names)
	assert(table.concat(names, ",") == "GetBuild,GetTables,IsOffered,ToggleDebugWindow",
		"the share differs: " .. table.concat(names, ","))
	assert(developer.GetBuild() == "1.60.1.70959", "the share names another build")
end

-- Rule: while no generated table has named its source, the list is empty and the tab says so.
do
	Load()
	MSBTOptions.Debug = { Toggle = Noop }
	assert(MikSBT.TABLE_BUILDS == nil and #developer.GetTables() == 0, "tables without a registration")
	local written = Written()
	assert(written:find(L.DEVELOPER.noTables, 1, true), "the empty list is not told: " .. written)
end

-- Rule: the tab names the client's build and each table with its state; a table that differs
-- names its script, and the button toggles the debug window.
do
	Load()
	local toggled = 0
	MSBTOptions.Debug = { Toggle = function() toggled = toggled + 1 end }
	-- Given three tables named their source: the client's build, an older one, another client's.
	MikSBT.TABLE_BUILDS = {
		SpellMechanics = { product = "wowf", build = "1.60.1.70959", script = "scripts/generate_spell_mechanics.py" },
		HealSpells = { product = "wowf", build = "1.60.1.70888", script = "scripts/generate_heal_spells.py" },
		SkillLineIcons = { product = "wow", build = "1.60.1.70959", script = "scripts/generate_skill_line_icons.py" },
	}
	-- When the tables are asked for, then they come by name, each with its state.
	local tables = developer.GetTables()
	assert(#tables == 3 and tables[1].name == "HealSpells" and tables[2].name == "SkillLineIcons"
		and tables[3].name == "SpellMechanics", "the tables are not sorted by name")
	assert(tables[1].state == "clientNewer" and tables[2].state == "otherClient" and tables[3].state == "fits",
		"a table has the wrong state")

	-- When the tab is shown.
	local written = Written()
	-- Then it names the client's build, each table and, for a table that differs, its script.
	assert(written:find("Client build: 1.60.1.70959", 1, true), "the client's build is missing: " .. written)
	assert(written:find("HealSpells: 1.60.1.70888, client is newer|Regenerate with scripts/generate_heal_spells.py", 1, true),
		"a table that differs does not name its script: " .. written)
	assert(written:find("SpellMechanics: 1.60.1.70959, fits", 1, true) and not written:find("generate_spell_mechanics", 1, true),
		"a table that fits names its script: " .. written)
	assert(not written:find(L.DEVELOPER.noTables, 1, true), "the list is called empty: " .. written)
	-- And a table that differs is written in the game's orange, apart from the list's title and from
	-- a table that fits, which keep the color of their font.
	local function Region(text)
		for _, region in ipairs(tabFrame.regions) do
			if region.text == text then return region end
		end
	end
	local color = Region("HealSpells: 1.60.1.70888, client is newer").color
	assert(color and color[1] == 1 and color[2] == 0.5 and color[3] == 0.25, "a table that differs is not written in orange")
	assert(Region("SkillLineIcons: 1.60.1.70959, " .. L.DEVELOPER.otherClient).color, "another client's table is not written in orange")
	assert(not Region(L.DEVELOPER.tables).color, "the list's title has a color of its own")
	assert(not Region("SpellMechanics: 1.60.1.70959, fits").color, "a table that fits has a color of its own")
	-- And its button toggles the debug window.
	tabFrame.controls.debugWindowButton.click()
	assert(toggled == 1, "the button did not toggle the debug window")
end
print("developer tab OK")
