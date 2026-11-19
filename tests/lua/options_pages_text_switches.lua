-- Describe: the General page of the new options window lists the reputation and honor entries only when it can.
-- A script sets TEXT_SWITCH_SCENARIO first: "get", "set", "take" or "restore" takes one function of the
-- profiles module away, "texts" the locale texts and "client" the client's settings; "only" gives the
-- page the two entries without the effect entries.
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

-- Rule: the two entries are listed only with all four functions, both texts and a client setting, and then
-- close the dropdown for the text at the character; either way the page keeps its layout.
do
	local built, err = pcall(function()
		Window.Show()
		ClickEntry("general")
	end)
	assert(built, "the page could not be built: " .. tostring(err))
	local function Labels(text)
		local labels = {}
		for _, entry in ipairs(assert(env.Menu(text), "a dropdown is missing")) do labels[#labels + 1] = entry.text end
		return table.concat(labels, "|")
	end
	local onMe, onTarget = Labels(L.WINDOW.blizzardOnMe), Labels(L.WINDOW.blizzardOnTarget)
	local profile = L.WINDOW.incoming .. "|" .. L.WINDOW.notifications
	if scenario == "only" then
		assert(onMe == profile .. "|Reputation Changes|Honorable Kills", "an entry is missing: " .. onMe)
		assert(onTarget == L.WINDOW.blizzardNumbers, "an effect entry was listed without its functions: " .. onTarget)
	else
		assert(onMe == profile, "an entry appeared without what it needs: " .. onMe)
		assert(onTarget == L.WINDOW.blizzardNumbers .. "|Effects on targets|Effects on other players' targets",
			"the effect entries differ: " .. onTarget)
	end
	-- No checkbox of the page stands for any of them.
	local checkboxes = FindAll(MSBTOptionsWindowFrame, function(region)
		local text = region.checkFrame and region.fontString:GetText()
		return text == "Reputation Changes" or text == "Honorable Kills" or text == "Effects on targets"
	end)
	assert(#checkboxes == 0, "a checkbox was built for an entry of the dropdowns")
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	assert(Section(0).height == 130 and Section(140).height == 150 and Section(300).height == 156,
		"the layout changed with the entries")
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
