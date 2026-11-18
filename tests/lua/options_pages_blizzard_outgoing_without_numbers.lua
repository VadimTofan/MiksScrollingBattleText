-- Describe: Blizzard's Disable outgoing on the General page where the profiles module has the Blizzard
-- switch functions but the locale has no text for the numbers switch.
local env = dofile("tests/lua/options_window_env.lua")
local calls, Profiles, L, Window = env.calls, env.Profiles, env.L, env.Window
local FindAll, Click, ClickEntry = env.FindAll, env.Click, env.ClickEntry

-- The functions of the profiles module that offer the Blizzard switches, as the effect and text switches use them.
local function Fail() error("the page used a Blizzard switch for the outgoing option") end
function Profiles.GetBlizzardSwitch() return nil, false end
function Profiles.SetBlizzardSwitch() Fail() end
function Profiles.TakeBlizzardSwitches() return {} end
function Profiles.RestoreBlizzardSwitches() end
-- The locale has no text for the numbers switch, whether or not the tree brings one.
L.CHECKBOXES.disableOutgoing.blizzardTooltip = nil
assert(not MikSBT.translations.CHECKBOXES.disableOutgoing.blizzardTooltip, "the text is still there")
Profiles.currentProfile.blizzardOutgoingDisabled = true

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

-- Rule: without the numbers tooltip the outgoing switch stays on the profile option.
do
	Window.Show()
	ClickEntry("general")
	local outgoing = FindAll(MSBTOptionsWindowFrame, function(region)
		return region.checkFrame and region.fontString:GetText() == L.CHECKBOXES.disableOutgoing.label and region.shown
	end)[2]
	assert(outgoing, "the switch is missing")
	-- Then it shows the profile option with MSBT's own tooltip.
	assert(outgoing:GetChecked() == true, "the switch does not show the profile option")
	assert(outgoing.checkFrame.tooltip == L.CHECKBOXES.disableOutgoing.tooltip, "the tooltip is not the option's one")

	-- When it is clicked, then the profile option is saved and the Blizzard switch is left alone.
	MikSBT.EraseTable(calls)
	outgoing.checkFrame:SetChecked(false)
	Click(outgoing.checkFrame)
	assert(Profiles.currentProfile.blizzardOutgoingDisabled == false, "the click did not save the profile option")
	assert(calls[1] and calls[1][1] == "SetOption" and calls[1][3] == "blizzardOutgoingDisabled" and calls[1][4] == false,
		"the click did not go through the profile option")
end
