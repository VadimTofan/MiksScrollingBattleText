-- Describe: the General page of the new options window when the client text switches have no texts.
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, ClickEntry = env.Find, env.ClickEntry

-- The profiles module has the functions, but the localization has no texts for them.
function Profiles.GetSpellMechanicsText() return true, true end
function Profiles.SetSpellMechanicsText() end
-- A localization that has the texts is made to lack them, in every table the page can read.
for _, checkboxes in ipairs({ L.CHECKBOXES, MikSBT.translations.CHECKBOXES }) do
	checkboxes.spellMechanicsOwn, checkboxes.spellMechanicsOthers = nil, nil
end
assert(not L.CHECKBOXES.spellMechanicsOwn and not L.CHECKBOXES.spellMechanicsOthers
	and not MikSBT.translations.CHECKBOXES.spellMechanicsOwn
	and not MikSBT.translations.CHECKBOXES.spellMechanicsOthers, "the texts are still there")
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
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")

-- Rule: without the texts the page builds no such switch and keeps its layout.
do
	local built, err = pcall(function()
		Window.Show()
		ClickEntry("general")
	end)
	assert(built, "the page could not be built without the texts: " .. tostring(err))
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	local onTarget = assert(env.Menu(L.WINDOW.blizzardOnTarget), "the dropdown for the text over targets is missing")
	assert(#onTarget == 1 and onTarget[1].text == L.WINDOW.blizzardNumbers, "an entry appeared without its texts")
	assert(Section(0).height == 130 and Section(140).height == 150 and Section(300).height == 156,
		"the layout changed")
	local note = Find(MSBTOptionsWindowFrame, function(frame)
		for _, region in ipairs(frame.regions) do
			if region.GetText and region:GetText() == L.LANGUAGE_INFO then return true end
		end
	end)
	for _, region in ipairs(note.regions) do
		if region.GetText and region:GetText() == L.LANGUAGE_INFO then
			assert(region.points.TOPLEFT.y == -96, "the language note moved")
		end
	end
end
