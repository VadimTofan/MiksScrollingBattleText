-- Describe: the developer page of the new options window stands in the sidebar only while it is offered.
-- A script sets DEVELOPER_SCENARIO first: "offered" has the developer share of the classic tabs with
-- the debug window loaded, "empty" the same without a generated table, "not_offered" the share
-- without the debug window, "absent" no share.
local scenario = assert(DEVELOPER_SCENARIO, "no scenario")
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, Labelled, Click, ClickEntry = env.Find, env.Labelled, env.Click, env.ClickEntry

-- The classic exports and media the pages are built on, as in the pages test.
local function Noop() end
MSBTOptions.Popups = { ShowAcknowledge = Noop, ShowInput = Noop, ShowPartialEffects = Noop,
	ShowDamageColors = Noop, ShowClassColors = Noop, DisableControls = Noop,
	UseDesignPopups = env.Popups.UseDesignPopups }
MSBTOptions.Tabs = { general = { ShowMasterFont = Noop, ResetBlizzardSCT = Noop, ReportImport = Noop } }
MSBTOptions.ProfileTransfer = { ShowExport = Noop, ShowImport = Noop }
MikSBT.Media = { sounds = {}, PlaySound = function() return true end,
	RegisterSound = function() return true end }
MikSBT.API = { Sounds = { NormalizeFile = function(_, file) return file end } }
for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end

-- The developer share of the classic tabs. Its texts come with the classic developer tab; where
-- they are not there, these stand in.
local toggled, asked = 0, 0
if scenario ~= "absent" then
	MSBTOptions.Tabs.developer = {
		IsOffered = function()
			asked = asked + 1
			return scenario ~= "not_offered"
		end,
		GetBuild = function() return "1.60.1.70959" end,
		GetTables = function()
			if scenario == "empty" then return {} end
			return {
				{ name = "HealSpells", build = "1.60.1.70888", state = "clientNewer", script = "scripts/generate_heal_spells.py" },
				{ name = "SkillLineIcons", build = "1.60.1.70959", state = "fits", script = "scripts/generate_skill_line_icons.py" },
			}
		end,
		ToggleDebugWindow = function() toggled = toggled + 1 end,
	}
	L.DEVELOPER = L.DEVELOPER or { client = "Client build: %s", tables = "Generated tables", noTables = "None",
		fits = "fits", clientNewer = "client is newer", regenerate = "Regenerate with %s",
		debugWindow = "Debug Window", debugWindowTooltip = "Debug tip" }
end
local texts = L.DEVELOPER
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")
-- The page asks only when the sidebar or the settings list is built: the debug window loads later.
assert(asked == 0, "the page asked for the debug window while the files loaded")

local function Listed()
	for _, page in ipairs(Window.DockPages()) do
		if page.key == "developer" then return page end
	end
end
local function Entry() return Find(MSBTOptionsWindowFrame, function(region) return region.key == "developer" end) end
local function Tells(text)
	return Find(MSBTOptionsWindowFrame, function(frame)
		for _, region in ipairs(frame.regions) do
			if region.shown and region.GetText and region:GetText() == text then return true end
		end
	end)
end
-- The color a shown text is written in, and a color of the design, as one string each.
local function Shade(color) return ("%.3f %.3f %.3f"):format(color[1], color[2], color[3]) end
local function ColorOf(text)
	for _, region in ipairs(Tells(text).regions) do
		if region.shown and region.GetText and region:GetText() == text then return Shade(region.textColor) end
	end
end

-- Rule: where the classic tabs have the developer share, it has every function the page calls.
do
	local function Read(path)
		local file = assert(io.open(path, "r"))
		local text = file:read("*a")
		file:close()
		return text
	end
	local share = Read("MSBTOptions/MSBTOptionsTabs.lua"):match("module%.developer = (%b{})")
	if share then
		for name in Read("MSBTOptions/Designs/Forever/Pages.lua"):gmatch("MSBTDeveloper%.(%w+)") do
			assert(share:find("%f[%w]" .. name .. " = "), "the classic tabs' developer share lacks " .. name)
		end
	end
end

if scenario == "absent" or scenario == "not_offered" then
	-- Rule: without the share or without the debug window, there is no entry and no settings page.
	assert(not Listed(), "the game's settings list has a developer page")
	Window.Show()
	assert(not Entry(), "the sidebar has a developer entry")
	print("developer page OK", scenario)
	return
end

-- Rule: with the debug window loaded, the entry closes the last group and the settings list has the page.
do
	local page = Listed()
	assert(page and page.label == L.WINDOW.developer, "the game's settings list lacks the developer page")
	local pages = Window.DockPages()
	assert(pages[#pages].key == "developer" and pages[#pages - 1].key == "changes", "the page is not the last one")
	Window.Show()
	local entry, changes = Entry(), Find(MSBTOptionsWindowFrame, function(region) return region.key == "changes" end)
	assert(entry, "the sidebar lacks the developer entry")
	assert(entry.points.TOPLEFT.y == changes.points.TOPLEFT.y - 28, "the entry does not follow Changes")
end

ClickEntry("developer")
assert(Tells(texts.client:format("1.60.1.70959")), "the client's build is missing")
assert(Tells(texts.tables), "the list has no title")
-- The section that holds the list is the one with its title.
local list = Find(MSBTOptionsWindowFrame, function(frame)
	for _, region in ipairs(frame.regions) do
		if region:GetText() == texts.tables then return true end
	end
end)
assert(list, "the list has no section")

if scenario == "empty" then
	-- Rule: while no generated table has named its source, the page says so in a section of one line.
	assert(Tells(texts.noTables), "the empty list is not told")
	assert(list.height == 40 + 12 + 18, "the empty list's section has another height: " .. list.height)
	print("developer page OK", scenario)
	return
end

-- Rule: the page names each table with its state, a differing table with its script, and toggles the debug window.
do
	assert(Tells("HealSpells: 1.60.1.70888, " .. texts.clientNewer), "a table is missing")
	assert(Tells(texts.regenerate:format("scripts/generate_heal_spells.py")), "a differing table does not name its script")
	assert(Tells("SkillLineIcons: 1.60.1.70959, " .. texts.fits), "a table is missing")
	assert(not Tells(texts.regenerate:format("scripts/generate_skill_line_icons.py")), "a fitting table names its script")
	assert(not Tells(texts.noTables), "the list is called empty")
	assert(list.height == 40 + 12 + (2 * 18 + 6) + (18 + 6), "the section does not fit its lines: " .. list.height)
	Click(Find(MSBTOptionsWindowFrame, Labelled(texts.debugWindow)))
	assert(toggled == 1, "the button did not toggle the debug window")
end

-- Rule: a differing table is written in orange, apart from the list's title and from a table that fits.
do
	local orange = Shade(Window.COLORS.orange)
	assert(ColorOf("HealSpells: 1.60.1.70888, " .. texts.clientNewer) == orange, "a differing table is not written in orange")
	assert(ColorOf(texts.tables) ~= orange, "the list's title has the color of a differing table")
	assert(ColorOf("SkillLineIcons: 1.60.1.70959, " .. texts.fits) == Shade(Window.COLORS.text),
		"a fitting table is not written in the text color")
end
print("developer page OK", scenario)
