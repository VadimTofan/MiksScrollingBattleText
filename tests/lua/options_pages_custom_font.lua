-- Describe: the Fonts & Colors page of the new options window registers a custom font through the
-- classic General tab's dialog, also when that tab was never built.
local env = dofile("tests/lua/options_window_env.lua")
local Profiles, L, Window, Main = env.Profiles, env.L, env.Window, env.Main
local Find, FindAll, Labelled, Click, ClickEntry, Footer = env.Find, env.FindAll, env.Labelled, env.Click,
	env.ClickEntry, env.Footer

-- Like the client: a font file that is not installed does not load, and a broken one throws.
local tried = {}
function env.Methods:SetFont(path)
	tried[#tried + 1] = { fontString = self, path = path }
	if path:find("broken", 1, true) then error("font unavailable") end
	return not path:find("missing", 1, true)
end

-- The popups record the dialog they are asked for and disable controls as the real ones do.
local function Noop() end
local opened = {}
MSBTOptions.Popups = {
	ShowInput = function(config) opened[#opened + 1] = config end,
	DisableControls = function(controls)
		for _, control in pairs(controls) do
			if control.Disable then control:Disable() end
		end
	end,
	ShowAcknowledge = Noop, ShowPartialEffects = Noop, ShowDamageColors = Noop, ShowClassColors = Noop,
	ShowFont = Noop, UseDesignPopups = env.Popups.UseDesignPopups,
}
-- The media library keeps what is registered.
local fonts = { Default = "Fonts\\FRIZQT__.TTF" }
MikSBT.Media = { fonts = fonts, sounds = {}, PlaySound = function() return true end }
function MikSBT.Media.RegisterFont(name, path)
	fonts[name] = path
	return true
end
MikSBT.Print = Noop
MikSBT.API = { Sounds = { NormalizeFile = function(_, file) return file end } }
-- The game resolves missing values from the master profile; this store has none.
for _, profile in pairs(Profiles.savedVariables.profiles) do profile.animationSpeed = 100 end

-- The real classic tabs, whose General tab frame is known by the label it is added under.
local addTab, generalTab = Main.AddTab, nil
Main.AddTab = function(frame, label, ...)
	if label == L.TABS.general.label then generalTab = frame end
	return addTab(frame, label, ...)
end
dofile("MSBTOptions/MSBTOptionsTabs.lua")
Main.AddTab = addTab
dofile("MSBTOptions/MSBTOptionsSounds.lua")
dofile("MSBTOptions/Designs/Forever/Pages.lua")

local DEFAULT_FONT_PATH = "Interface\\AddOns\\MikScrollingBattleText\\Fonts\\"
local function Last() return opened[#opened] end
local function EditButtons()
	return FindAll(MSBTOptionsWindowFrame, function(region)
		return region.kind == "Button" and region:GetText() == L.WINDOW.edit
	end)
end

-- Rule: with the classic General tab never built, the entry's dialog validates and registers a font.
local add
do
	-- Given the new window on Fonts & Colors, and the classic window never shown.
	Window.Show()
	ClickEntry("fontsColors")
	add = Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.add))
	local edits = EditButtons()
	local count = env.Count()

	-- When the custom font entry is clicked.
	Click(add)

	-- Then the classic dialog opens over the page at the button, and the other entries wait.
	local dialog = Last()
	assert(dialog and dialog.title == L.CUSTOM_FONTS.add and dialog.showSecondEditbox
		and dialog.editboxLabel == L.CUSTOM_FONTS.name and dialog.secondEditboxLabel == L.CUSTOM_FONTS.path,
		"the classic custom font dialog did not open")
	assert(dialog.parentFrame == add:GetParent() and dialog.anchorFrame == add
		and dialog.anchorPoint == "TOPRIGHT" and dialog.relativePoint == "BOTTOMRIGHT",
		"the dialog does not open over the page at its button")
	assert(not add:IsEnabled() and not edits[1]:IsEnabled(), "the entries stayed enabled behind the dialog")
	assert(generalTab and not generalTab.created and generalTab.controls == nil,
		"opening the dialog built the classic General tab")

	-- When names and paths are checked.
	assert(dialog.validateHandler("", "custom.ttf") == L.CUSTOM_FONTS.invalidName, "an empty name was accepted")
	assert(dialog.validateHandler("Default", "custom.ttf") == L.CUSTOM_FONTS.duplicateName,
		"a registered name was accepted")
	assert(dialog.validateHandler("Mine", "missing.ttf") == L.CUSTOM_FONTS.invalidPath,
		"a font that does not load was accepted")
	assert(dialog.validateHandler("Mine", "broken.ttf") == L.CUSTOM_FONTS.invalidPath,
		"a font that throws was accepted")
	MikSBT.EraseTable(tried)
	assert(dialog.validateHandler("Mine", "custom.ttf") == nil, "an installed font was refused")
	assert(dialog.validateHandler("Mine", "Interface/AddOns/MyFonts/mine.ttf") == nil, "a full path was refused")

	-- Then each path was tried on one hidden string outside the classic General tab, kept for the next check.
	assert(#tried == 2 and tried[1].path == DEFAULT_FONT_PATH .. "custom.ttf"
		and tried[2].path == "Interface\\AddOns\\MyFonts\\mine.ttf",
		"the paths were not tried as the classic tab tries them")
	assert(tried[1].fontString == tried[2].fontString, "each check made a string of its own")
	assert(tried[1].fontString:GetParent() == UIParent and not generalTab.created,
		"the check needed the classic General tab")

	-- When the dialog is saved, which hides it first.
	dialog.hideHandler()
	dialog.saveHandler({ inputText = " Mine ", secondInputText = " Interface/AddOns/MyFonts/mine.ttf " })

	-- Then the font is registered and kept in the saved media, and the entries are enabled again.
	local path = "Interface\\AddOns\\MyFonts\\mine.ttf"
	assert(fonts.Mine == path and Profiles.savedMedia.fonts.Mine == path, "the font was not registered and saved")
	assert(add:IsEnabled() and edits[1]:IsEnabled(), "closing the dialog did not enable the entries")

	-- And it is no profile change: the footer keeps its count, Apply stays off, and Cancel keeps the font.
	assert(env.Count() == count and Footer():GetText() == string.format(L.WINDOW.changesCount, count),
		"the registered font counts as a change since login")
	assert(not Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.apply)):IsEnabled(), "the registered font enabled Apply")
	Click(Find(MSBTOptionsWindowFrame, Labelled(L.WINDOW.cancel)))
	assert(not MSBTOptionsWindowFrame:IsShown() and fonts.Mine == path and Profiles.savedMedia.fonts.Mine == path,
		"Cancel dropped the registered font")
end

-- Rule: the classic General tab still opens the dialog at its own button and checks on its own string.
do
	-- Given the classic General tab built after the new window checked a font.
	generalTab:Show()
	local controls = generalTab.controls
	local validator = generalTab.fontPathValidationFontString
	assert(generalTab.created and validator and validator:GetParent() == generalTab and validator.alpha == 0
		and validator.points.BOTTOMRIGHT.relative == generalTab and validator:GetText() == "Test",
		"the classic tab did not make its own hidden string")

	-- When its custom font button is clicked.
	Click(controls.addFontButton)

	-- Then the dialog opens above that button in the tab, with the tab's controls disabled until it hides.
	local dialog = Last()
	assert(dialog.title == L.CUSTOM_FONTS.add and dialog.parentFrame == generalTab
		and dialog.anchorFrame == controls.addFontButton and dialog.anchorPoint == "BOTTOMLEFT"
		and dialog.relativePoint == "TOPLEFT", "the classic dialog does not open at its button")
	assert(not controls.masterFontButton:IsEnabled() and not controls.addFontButton:IsEnabled(),
		"the classic controls stayed enabled behind the dialog")
	MikSBT.EraseTable(tried)
	assert(dialog.validateHandler("Mine", "custom.ttf") == L.CUSTOM_FONTS.duplicateName,
		"the font registered in the new window can be added again")
	assert(dialog.validateHandler("Other", "custom.ttf") == nil and tried[1].fontString == validator,
		"the classic tab does not check on its own string")
	dialog.hideHandler()
	assert(controls.masterFontButton:IsEnabled() and controls.addFontButton:IsEnabled(),
		"closing the dialog did not enable the classic controls")

	-- And the new window's dialog checks on the same string from then on.
	Window.Show()
	ClickEntry("fontsColors")
	Click(add)
	MikSBT.EraseTable(tried)
	assert(Last().validateHandler("Other", "custom.ttf") == nil and tried[1].fontString == validator,
		"the new window checks on a string of its own after the classic tab was built")
	Last().hideHandler()
	Window.Hide()
end

print("Options custom font tests passed")
