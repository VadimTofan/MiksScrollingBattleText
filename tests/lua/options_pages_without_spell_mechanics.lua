-- Describe: the General page of the new options window without the client text switches.
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, FindAll, ClickEntry = env.Find, env.FindAll, env.ClickEntry

-- The texts exist, but the profiles module has no functions for the client setting.
L.CHECKBOXES.spellMechanicsOwn = { label = "Effects on targets", tooltip = "Effects tip" }
L.CHECKBOXES.spellMechanicsOthers = { label = "Effects on other players' targets", tooltip = "Others tip" }
-- A profiles module that has the functions is made to lack them.
Profiles.GetSpellMechanicsText, Profiles.SetSpellMechanicsText = nil, nil
MikSBT.Profiles.GetSpellMechanicsText, MikSBT.Profiles.SetSpellMechanicsText = nil, nil
assert(not Profiles.GetSpellMechanicsText and not Profiles.SetSpellMechanicsText
	and not MikSBT.Profiles.GetSpellMechanicsText and not MikSBT.Profiles.SetSpellMechanicsText,
	"the functions are still there")
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

-- Rule: without the profiles functions the page builds no such switch and keeps its layout.
do
	local built, err = pcall(function()
		Window.Show()
		ClickEntry("general")
	end)
	assert(built, "the page could not be built without the functions: " .. tostring(err))
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	local switches = FindAll(MSBTOptionsWindowFrame, function(region)
		local text = region.checkFrame and region.fontString:GetText()
		return text == L.CHECKBOXES.spellMechanicsOwn.label or text == L.CHECKBOXES.spellMechanicsOthers.label
	end)
	assert(#switches == 0, "a switch appeared without its functions")
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
