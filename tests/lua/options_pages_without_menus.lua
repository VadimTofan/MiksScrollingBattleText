-- Describe: the General page of the new options window on a client without the game's menu system.
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window = env.Profiles, env.L, env.Window
local Find, FindAll, ClickEntry = env.Find, env.FindAll, env.ClickEntry

-- The client has no dropdown with a menu; a frame of that kind cannot be made there.
WowStyle2DropdownMixin = nil
local createFrame = CreateFrame
function CreateFrame(kind, ...)
	assert(kind ~= "DropdownButton", "the page asked for a dropdown the client does not have")
	return createFrame(kind, ...)
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

-- Rule: without the menu system the page builds without the two dropdowns and keeps everything else.
do
	local built, err = pcall(function()
		Window.Show()
		ClickEntry("general")
	end)
	assert(built, "the page could not be built without the menu system: " .. tostring(err))
	assert(not env.Menu(L.WINDOW.blizzardOnMe) and not env.Menu(L.WINDOW.blizzardOnTarget), "a dropdown was built")
	local function Checkboxes(label)
		return FindAll(MSBTOptionsWindowFrame, function(region)
			return region.checkFrame and region.fontString:GetText() == label and region.shown
		end)
	end
	assert(#Checkboxes(L.CHECKBOXES.enableBlizzardDamage.label) == 1, "the Blizzard switch is missing")
	assert(#Checkboxes(L.CHECKBOXES.disableOutgoing.label) == 1, "MSBT's own sub-options differ")
	local function Section(top)
		return Find(MSBTOptionsWindowFrame, function(region)
			local point = region.points and region.points.TOPLEFT
			return region.height and point and point.y == -top and point.x == 0 and region.points.TOPRIGHT
		end)
	end
	assert(Section(0).height == 130 and Section(140).height == 150 and Section(300).height == 156,
		"the layout changed")
end
