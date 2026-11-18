-- Describe: the General page of the new options window builds the reputation and honor switches only when it can.
-- A script sets TEXT_SWITCH_SCENARIO first: "get", "set", "take" or "restore" takes one function of the
-- profiles module away, "texts" the locale texts and "client" the client's settings; "only" gives the
-- page the switches without the effect switches.
local scenario = assert(TEXT_SWITCH_SCENARIO, "no scenario")
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, FindAll, ClickEntry = env.Find, env.FindAll, env.ClickEntry

-- The profiles module, the texts and the client have everything; one scenario then takes a part away.
local client = { reputation = true, honor = false }
function Profiles.GetBlizzardSwitch(name) return client[name] end
function Profiles.SetBlizzardSwitch() error("the page wrote a switch it should not have built") end
function Profiles.TakeBlizzardSwitches() return {} end
function Profiles.RestoreBlizzardSwitches() end
L.CHECKBOXES.blizzardReputation = { label = "Reputation Changes", tooltip = "Reputation tip" }
L.CHECKBOXES.blizzardHonor = { label = "Honorable Kills", tooltip = "Honor tip" }
if scenario ~= "only" then
	function Profiles.GetSpellMechanicsText() return false, true end
	function Profiles.SetSpellMechanicsText() end
	L.CHECKBOXES.spellMechanicsOwn = { label = "Effects on targets", tooltip = "Effects tip" }
	L.CHECKBOXES.spellMechanicsOthers = { label = "Effects on other players' targets", tooltip = "Others tip" }
end
local functionNames = { get = "GetBlizzardSwitch", set = "SetBlizzardSwitch", take = "TakeBlizzardSwitches",
	restore = "RestoreBlizzardSwitches" }
if functionNames[scenario] then
	Profiles[functionNames[scenario]] = nil
	assert(not MikSBT.Profiles[functionNames[scenario]], "the function is still there")
elseif scenario == "texts" then
	L.CHECKBOXES.blizzardReputation, L.CHECKBOXES.blizzardHonor = nil, nil
	assert(not MikSBT.translations.CHECKBOXES.blizzardReputation and not MikSBT.translations.CHECKBOXES.blizzardHonor,
		"the texts are still there")
elseif scenario == "client" then
	client.reputation, client.honor = nil, nil
end
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

-- Rule: the switches are built only with all four functions, both texts and a client setting, and then
-- stand in the Blizzard column below the effect switches' rows; without them the page is as it was.
do
	local built, err = pcall(function()
		Window.Show()
		ClickEntry("general")
	end)
	assert(built, "the page could not be built: " .. tostring(err))
	local function Switch(label)
		return Find(MSBTOptionsWindowFrame, function(region)
			return region.checkFrame and region.fontString:GetText() == label and region.shown
		end)
	end
	local reputation, honor = Switch("Reputation Changes"), Switch("Honorable Kills")
	-- Hidden or not, no switch is built where it cannot work.
	local switches = FindAll(MSBTOptionsWindowFrame, function(region) return region.switch end)
	assert(#switches == (scenario == "only" and 2 or 0), "the number of built switches differs")
	local own = Switch("Effects on targets")
	if scenario == "only" then
		-- The two rows are the first of the Blizzard column, below the sub-options.
		assert(reputation and honor, "a switch is missing")
		assert(reputation.points.TOPLEFT.x == 345 and reputation.points.TOPLEFT.y == -114
			and honor.points.TOPLEFT.y == -138, "the switches are not below the sub-options")
		assert(not own, "an effect switch was built without its functions")
	else
		assert(not reputation and not honor, "a switch appeared without what it needs")
		assert(own and own.points.TOPLEFT.x == 345 and own.points.TOPLEFT.y == -114, "the effect switch moved")
	end
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	assert(Section(0).height == 170 and Section(180).height == 150 and Section(340).height == 116,
		"the layout differs from that with two rows")
	local note = Find(MSBTOptionsWindowFrame, function(frame)
		for _, region in ipairs(frame.regions) do
			if region.GetText and region:GetText() == L.LANGUAGE_INFO then return true end
		end
	end)
	for _, region in ipairs(note.regions) do
		if region.GetText and region:GetText() == L.LANGUAGE_INFO then
			assert(region.points.TOPLEFT.y == -66, "the language note is not where the grown section puts it")
		end
	end
end
