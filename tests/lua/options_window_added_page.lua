-- Describe: a file outside the design adds a page to the new options window.
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, FindAll, Labelled, Click, ClickEntry = env.Find, env.FindAll, env.Labelled, env.Click, env.ClickEntry

-- The classic exports and media the design's pages are built on, as in the pages test.
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
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")

-- The sidebar's entries in their order.
local function Entries()
	return FindAll(MSBTOptionsWindowFrame, function(region) return region.key and region.label and region.hint end)
end

-- Rule: a page added while the files load comes after every page of the design.
do
	-- Given localized texts under the page's key, which the entry's own must win over.
	L.WINDOW.extra = "Localized label"
	L.WINDOW.extraHint = "Localized hint"
	-- Given a page added after the Forever files loaded, before the window is built.
	local created, refreshed, clicked = {}, {}, 0
	local function create(page, width, height)
		created[#created + 1] = page
		local section = Window.CreateSection(page, 12, 40)
		assert(section:GetParent() == page, "the section is not on the page")
		assert(section.height == 40 and section.points.TOPLEFT.y == -12, "the section has the wrong place")
		local text = Window.CreateText(section, "GameFontNormal", Window.COLORS.gold, "Added text")
		assert(text:GetText() == "Added text", "the text was not set")
		local button = Window.CreateButton(section, "Added button", "Added tooltip", function() clicked = clicked + 1 end)
		assert(button:GetParent() == section, "the button is not in the section")
	end
	local function refresh(page, arg) refreshed[#refreshed + 1] = { page, arg } end
	Window.AddPage("extra", "Extra page", "What the extra page is for.", create, refresh)

	-- Then a call without a label or hint, or with a key already in use, is refused and adds nothing.
	local count = #MSBTOptions.Designs.designs.forever.DockPages()
	assert(not pcall(Window.AddPage, "other", nil, "A hint", create), "a page without a label was added")
	assert(not pcall(Window.AddPage, "other", "A label", nil, create), "a page without a hint was added")
	assert(not pcall(Window.AddPage, "extra", "Again", "A hint", create), "a page was added twice")
	assert(not pcall(Window.AddPage, "general", "Again", "A hint", create), "a page of the design was replaced")
	assert(#MSBTOptions.Designs.designs.forever.DockPages() == count, "a refused page left an entry")

	-- When the list for the game's settings window is asked for.
	local list = MSBTOptions.Designs.designs.forever.DockPages()

	-- Then it ends with the page, under its own label, after the pages of the design.
	assert(list[#list].key == "extra" and list[#list].label == "Extra page", "the list does not end with the page")
	assert(list[#list - 1].key == "changes", "the page does not come after the last page of the design")
	assert(list[1].label == L.TABS.general.label, "a page of the design lost its localized label")

	-- When the window is opened.
	Window.Show()
	local entries = Entries()

	-- Then the sidebar ends with an entry of that label and hint, and the entries of the design keep
	-- their localized ones.
	local last = entries[#entries]
	assert(last.key == "extra" and last.label == "Extra page", "the sidebar does not end with the page")
	assert(last.hint == "What the extra page is for.", "the entry has the wrong hint")
	assert(last.fontString:GetText() == "Extra page", "the entry shows the wrong label")
	assert(entries[1].key == "general" and entries[1].label == L.TABS.general.label, "the first entry lost its label")
	assert(entries[#entries - 1].key == "changes" and entries[#entries - 1].label == L.WINDOW.changes,
		"an entry of the design lost its label")
	assert(entries[#entries - 1].hint == L.WINDOW.changesHint, "an entry of the design lost its hint")

	-- When the page is selected.
	assert(#created == 0, "the page was made before it was selected")
	ClickEntry("extra")

	-- Then it is made once and refreshed, and its title and hint are the entry's.
	assert(#created == 1 and #refreshed == 1, "the page was not made and refreshed on its first selection")
	assert(refreshed[1][1] == created[1], "refresh did not get the page's frame")
	assert(Find(MSBTOptionsWindowFrame, function(region)
		return region.kind == "FontString" and region:GetText() == "What the extra page is for."
	end), "the page's hint is not shown")

	-- When another page and then this one are selected.
	ClickEntry("general")
	ClickEntry("extra")

	-- Then it is refreshed again, not made again.
	assert(#created == 1, "the page was made twice")
	assert(#refreshed == 2, "refresh did not run on each selection")

	-- And the helpers build a working button.
	Click(Find(MSBTOptionsWindowFrame, Labelled("Added button")))
	assert(clicked == 1, "the button's click did not reach its handler")
	Window.Hide()
end
