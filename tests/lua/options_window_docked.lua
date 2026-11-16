-- Describe: the new options window stands in the game's settings window, one panel for each page.
local env = dofile("tests/lua/options_window_env.lua")
local Methods, saved, Profiles, L, Window, Popups = env.Methods, env.saved, env.Profiles, env.L, env.Window, env.Popups
local Find, FindAll, Labelled, Click, Footer = env.Find, env.FindAll, env.Labelled, env.Click, env.Footer
local Designs = MSBTOptions.Designs

-- What the frame API of the shared environment leaves unread.
function Methods:GetFrameStrata() return self.strata or "DIALOG" end
function Methods:GetScale() return self.scale end
function Methods:EnableMouse(isEnabled) self.mouse = isEnabled end
function Methods:SetClampedToScreen(isClamped) self.clamped = isClamped end
local sounds = {}
function PlaySound(sound) sounds[#sounds + 1] = sound end

-- The game's settings window: a frame that shows one panel at a time and hides it when it closes.
local panels, openers = {}, {}
local currentPanel
SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent)
SettingsPanel:Hide()
SettingsPanel:SetScript("OnHide", function()
	local panel = currentPanel
	currentPanel = nil
	if panel then panel:Hide() end
end)
function HideUIPanel(frame) frame:Hide() end
local function Open(key)
	local panel = panels[key]
	if currentPanel and currentPanel ~= panel then currentPanel:Hide() end
	currentPanel = panel
	panel:Show()
	SettingsPanel:Show()
end

-- The panels as the registration makes them, with the design's own functions.
local design = Designs.designs.forever
local pageList = design.DockPages()
for _, page in ipairs(pageList) do
	local panel = CreateFrame("Frame")
	panel:Hide()
	panel.width, panel.height = 700, 600
	panel:SetFrameStrata("HIGH")
	panel:SetScript("OnShow", function(this) design.Dock(this, page.key, openers) end)
	panel:SetScript("OnHide", function(this) design.Undock(this) end)
	panels[page.key] = panel
	openers[page.key] = function() Open(page.key) end
end

local function IsSpecial()
	for _, name in ipairs(UISpecialFrames) do
		if name == "MSBTOptionsWindowFrame" then return true end
	end
	return false
end
local function Point(region, point)
	local anchor = region.points and region.points[point]
	return anchor and anchor.x, anchor and anchor.y
end
local function Frame() return MSBTOptionsWindowFrame end
local function Button(label) return Find(Frame(), Labelled(label)) end
local function CloseSettings() HideUIPanel(SettingsPanel) end
local function TextRegion(text)
	return Find(Frame(), function(region) return region.kind == "FontString" and region.text == text end)
end

-- Rule: the pages are listed without the window, and are the entries the sidebar would show.
do
	-- Given no window built yet.
	assert(Frame() == nil, "the window was built before it was needed")

	-- When the pages are asked for, then the window is built by docking, and its sidebar read.
	local keys = {}
	for index, page in ipairs(pageList) do keys[index] = page.key .. "=" .. page.label end
	Open("general")
	local entries = FindAll(Frame(), function(region) return region.kind == "Button" and region.label end)
	local shown = {}
	for index, entry in ipairs(entries) do shown[index] = entry.key .. "=" .. entry.label end
	CloseSettings()

	-- Then the pages are exactly the sidebar's entries in its order, the Fonts page left out for
	-- it has no page here, and the first one is General.
	assert(#pageList > 1 and pageList[1].key == "general" and pageList[1].label == L.TABS.general.label,
		"the first page is not General")
	assert(table.concat(keys, ",") == table.concat(shown, ","), "the pages differ from the sidebar's entries: "
		.. table.concat(keys, ",") .. " / " .. table.concat(shown, ","))
end

-- Rule: docked, the frame stands in the panel with the header, the page and the footer.
do
	-- Given the game's settings window opens at the Scroll Areas panel.
	sounds = {}
	Open("scrollAreas")

	-- Then the frame belongs to the panel, in its strata, without mouse and clamping, and Escape
	-- is left to the game's window.
	local frame = Frame()
	assert(frame:GetParent() == panels.scrollAreas and frame.strata == "HIGH", "the frame is not in the panel")
	assert(frame.mouse == false and frame.clamped == false, "the docked frame takes the mouse or is clamped")
	assert(not IsSpecial(), "Escape would close the docked frame")
	assert(frame:IsShown() and Window.IsShown(), "the docked frame is not shown")
	assert(Popups.design == "forever", "the docked window did not take its popups")

	-- Then the border, the close button, the sidebar and the size grip are away.
	assert(frame.regions[1].shown == false and frame.regions[2].shown == false, "the ground and border stayed")
	local close = Find(frame, function(region)
		local x, y = Point(region, "TOPRIGHT")
		return region.kind == "Button" and region.parent == frame and x == -12 and y == -16
	end)
	assert(close.shown == false, "the close button stayed")
	local entry = Find(frame, function(region) return region.key == "general" end)
	assert(entry:GetParent().shown == false, "the sidebar stayed")
	local grip = Find(frame, function(region)
		return region.parent == frame and region.scripts.OnMouseDown and region.scripts.OnHide
	end)
	assert(grip.shown == false, "the size grip stayed")

	-- Then the header stays: the title, the subtitle, the rule under it and the profile dropdown,
	-- which stands in the corner the close button leaves.
	assert(TextRegion("Mik's Scrolling Battle Text").shown, "the header title went")
	assert(TextRegion(string.format(L.WINDOW.subtitle, MikSBT.VERSION_STRING)).shown, "the subtitle went")
	local topRule = Find(frame, function(region)
		local _, y = Point(region, "TOPLEFT")
		return region.parent == frame and region.kind == "Texture" and y == -64
	end)
	assert(topRule.shown, "the rule under the header went")
	local profile = Find(frame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	assert(profile.shown, "the profile dropdown went")
	local profileX, profileY = Point(profile, "TOPRIGHT")
	assert(profileX == -16 and profileY == -12, "the profile dropdown is not in the corner of the docked frame")

	-- Then the footer, its rule, the page title and the hint stay.
	local bottomRule = Find(frame, function(region)
		local _, y = Point(region, "BOTTOMLEFT")
		return region.parent == frame and region.kind == "Texture" and y == 48
	end)
	assert(bottomRule.shown, "the rule above the footer went")
	assert(Button(L.WINDOW.resetProfile).shown, "the Reset Profile button went")
	assert(Footer().shown, "the Changes button went")

	-- Then Cancel and Apply are away, and Reset Profile stands where Apply stands standalone.
	assert(not Button(L.WINDOW.cancel).shown and not Button(L.WINDOW.apply).shown,
		"Cancel or Apply stayed in the docked footer")
	local resetX, resetY = Point(Button(L.WINDOW.resetProfile), "BOTTOMRIGHT")
	assert(resetX == -16 and resetY == 9 and Button(L.WINDOW.resetProfile).points.BOTTOMRIGHT.relative == frame
		and not Button(L.WINDOW.resetProfile).points.RIGHT, "Reset Profile is not in the corner of the docked footer")

	-- Then the page is the one of the panel.
	assert(TextRegion(L.TABS.scrollAreas.label).shown, "the page title is not the panel's page")
	assert(Find(frame, function(region) return region.key == "scrollAreas" end).selected.shown,
		"the entry of the panel's page is not selected")

	-- Then the content starts at the left edge with a margin and keeps its vertical places.
	local pageArea = Find(frame, function(region) return region.parent == frame and region.kind == "Frame" and region.width == 690 end)
	assert(frame.width == 730 and frame.height == 640, "the docked frame has the wrong size")
	local x, y = Point(pageArea, "TOPLEFT")
	assert(x == 20 and y == -124, "the page area is not at the docked place: " .. tostring(x) .. "," .. tostring(y))
	x, y = Point(TextRegion(L.TABS.scrollAreas.label), "TOPLEFT")
	assert(x == 20 and y == -80, "the page title is not at the docked place")

	-- Then the window is scaled to fit the panel, anchored at its top left, and refits.
	local scale = math.min(1.6, (700 - 32) / 730, (600 - 32) / 640)
	assert(math.abs(frame.scale - scale) < 1e-9, "the docked frame is not scaled to the panel")
	x, y = Point(frame, "TOPLEFT")
	assert(math.abs(x - 16 / scale) < 1e-9 and math.abs(y + 16 / scale) < 1e-9 and frame.points.TOPLEFT.relative == panels.scrollAreas,
		"the docked frame is not anchored in the panel")
	panels.scrollAreas.width, panels.scrollAreas.height = 2000, 1500
	panels.scrollAreas.scripts.OnSizeChanged(panels.scrollAreas)
	assert(frame.scale == 1.6, "the docked frame did not refit when the panel grew")
	panels.scrollAreas.width, panels.scrollAreas.height = 700, 600

	-- Then the game's window plays the sounds, not this one.
	assert(#sounds == 0, "the docked window played a sound")

	-- Then a list opened from the docked page shows above the game's settings window.
	profile.buttonFrame.scripts.OnClick(profile.buttonFrame)
	local list = Find(profile, function(region) return region.strata == "FULLSCREEN_DIALOG" end)
	assert(list and list:IsShown(), "the dropdown list is not above the settings window")
	CloseSettings()
end

-- Rule: the profile is chosen in the header of the docked frame.
do
	-- Given the docked frame at the Profile page.
	Open("profile")
	local profile = Find(Frame(), function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)

	-- When another profile is chosen in the header.
	profile:changeHandler("Alt")

	-- Then the profile is switched.
	assert(Profiles.currentProfile == saved.profiles.Alt, "the docked header did not switch the profile")
	Profiles.SelectProfile("Default")
	CloseSettings()
end

-- Rule: closing the game's settings window ends the session and gives the frame its own state back.
do
	-- Given a change made in the docked window.
	sounds = {}
	Open("general")
	Profiles.SetOption(nil, "stackSimilarHits", true)

	-- When the game's settings window closes.
	CloseSettings()

	-- Then the frame is the standalone window again.
	local frame = Frame()
	assert(not frame:IsShown() and not Window.IsShown(), "the frame stayed shown")
	assert(frame:GetParent() == UIParent and frame.strata == "DIALOG" and frame.mouse == true and frame.clamped == true,
		"the frame did not get its standalone state back")
	assert(IsSpecial(), "Escape does not close the standalone frame")
	assert(frame.width == 960 and frame.height == 640, "the standalone size was not restored")
	assert(TextRegion("Mik's Scrolling Battle Text").shown and frame.regions[1].shown and frame.regions[2].shown,
		"the chrome did not come back")
	local profile = Find(frame, function(region)
		return region.labelFontString and region.labelFontString:GetText() == L.DROPDOWNS.profile.label
	end)
	local profileX, profileY = Point(profile, "TOPRIGHT")
	assert(profile.shown and profileX == -56 and profileY == -12, "the profile dropdown did not get its place back")
	local entry = Find(frame, function(region) return region.key == "general" end)
	assert(entry:GetParent().shown, "the sidebar did not come back")
	local x, y = Point(Find(frame, function(region) return region.parent == frame and region.kind == "Frame" and region.width == 690 end), "TOPLEFT")
	assert(x == 250 and y == -124, "the page area is not at the standalone place")
	assert(frame.points.CENTER and frame.points.CENTER.relative == UIParent and not frame.points.TOPLEFT,
		"the frame is not centered")
	assert(Popups.design == "classic", "the session did not give the popups back")
	assert(#sounds == 0, "closing the docked window played a sound")

	-- Then Cancel and Apply are shown again, and Reset Profile stands to the left of Cancel.
	assert(Button(L.WINDOW.cancel).shown and Button(L.WINDOW.apply).shown, "Cancel or Apply did not come back")
	local cancel, reset = Button(L.WINDOW.cancel), Button(L.WINDOW.resetProfile)
	assert(reset.points.RIGHT and reset.points.RIGHT.relative == cancel and reset.points.RIGHT.relativePoint == "LEFT"
		and reset.points.RIGHT.x == -10 and not reset.points.BOTTOMRIGHT, "Reset Profile did not get its place back")
	local applyX, applyY = Point(Button(L.WINDOW.apply), "BOTTOMRIGHT")
	assert(applyX == -16 and applyY == 9, "Apply did not keep its place")

	-- Then the base is gone: the standalone window takes a new one, so Cancel keeps the change.
	Window.Show()
	assert(#sounds == 1 and sounds[1] == SOUNDKIT.IG_MAINMENU_OPTION, "the standalone window plays no sound")
	Click(Button(L.WINDOW.cancel))
	assert(Profiles.currentProfile.stackSimilarHits == true, "the base outlived the settings window")
	Profiles.currentProfile.stackSimilarHits = nil
end

-- Rule: in the game the frame turns invisible with the settings window before the panel's OnHide
-- runs. Its own OnHide then still finds it shown, and hiding it afterwards runs no OnHide, so the
-- end of the session cannot wait for that script.
do
	-- Given a change made in the docked window and a popup open over it.
	Open("general")
	Profiles.SetOption(nil, "stackSimilarHits", true)
	local popup = CreateFrame("Frame")
	MSBTOptions.Main.RegisterPopupFrame(popup)
	assert(popup:IsShown(), "the popup is not open")

	-- When the game's settings window closes the way the game does it.
	local frame = Frame()
	local onHide = frame.scripts.OnHide
	onHide(frame)
	frame.scripts.OnHide = nil
	CloseSettings()
	frame.scripts.OnHide = onHide

	-- Then the popup is closed and the session ended all the same.
	assert(not Window.IsDocked() and frame:GetParent() == UIParent, "the frame stayed in the panel")
	assert(not popup:IsShown(), "the popup outlived the settings window")
	assert(Popups.design == "classic", "the session did not give the popups back")
	Window.Show()
	Click(Button(L.WINDOW.cancel))
	assert(Profiles.currentProfile.stackSimilarHits == true, "the base outlived the settings window")
	Profiles.currentProfile.stackSimilarHits = nil
end

-- Rule: a category switch moves the frame to the new panel and keeps the base of the changes.
do
	-- Given a change made in the docked window.
	Open("general")
	Profiles.SetOption(nil, "fontSize", 30)
	assert(Button(L.WINDOW.apply):IsEnabled(), "Apply is disabled after a change")

	-- When the settings window switches to another category.
	Open("profile")

	-- Then the frame stands in the new panel with its page selected and the window did not end.
	assert(Frame():GetParent() == panels.profile and Frame():IsShown() and Popups.design == "forever",
		"the frame did not follow the category")
	assert(Find(Frame(), function(region) return region.key == "profile" end).selected.shown
		and not Find(Frame(), function(region) return region.key == "general" end).selected.shown,
		"the new category's page is not selected alone")

	-- Then the footer is still the docked one, and the base stayed.
	assert(not Button(L.WINDOW.cancel).shown and not Button(L.WINDOW.apply).shown, "the switch brought Cancel or Apply back")
	local resetX, resetY = Point(Button(L.WINDOW.resetProfile), "BOTTOMRIGHT")
	assert(resetX == -16 and resetY == 9, "the switch moved Reset Profile")
	assert(Button(L.WINDOW.apply):IsEnabled(), "the switch dropped the base")

	-- When the settings window closes, then the session ends and the changes stay.
	CloseSettings()
	assert(not Window.IsDocked() and Popups.design == "classic", "closing did not end the session")
	assert(Profiles.currentProfile.fontSize == 30, "closing the settings window undid a change")
	Profiles.currentProfile.fontSize = nil
end

-- Rule: the registry opens nothing while the frame stands in the game's settings window.
do
	-- Given the new design chosen and the frame docked, and a spy on its Show.
	Designs.Select("forever")
	Open("general")
	local asked = 0
	local show = design.Show
	design.Show = function() asked = asked + 1 end

	-- When the options are requested.
	Designs.Show()

	-- Then nothing happens.
	design.Show = show
	assert(asked == 0 and Frame():GetParent() == panels.general and (MSBTMainOptionsFrame == nil or not MSBTMainOptionsFrame:IsShown()),
		"the registry opened a window beside the settings window")
	CloseSettings()
end

-- Rule: put away from the settings window, the options come back there at the page.
do
	-- Given a change made at the Scroll Areas page.
	Open("scrollAreas")
	Profiles.SetOption(nil, "fontSize", 40)

	-- When the options are put away, as the positioning and the preview do.
	Designs.Hide()

	-- Then the game's settings window is closed, nothing is shown, and the base stays.
	assert(not SettingsPanel:IsShown() and not Frame():IsShown() and not Window.IsDocked(),
		"putting away left the settings window open")
	assert(Popups.design == "forever", "putting away ended the session")

	-- When the options are requested again.
	Designs.Show()

	-- Then the settings window opens at the same page, not the standalone window.
	assert(SettingsPanel:IsShown() and Frame():GetParent() == panels.scrollAreas and Window.IsDocked()
		and not IsSpecial(), "the options did not come back at their page")

	-- Then the base is the one from before, so the change still counts against it.
	assert(Button(L.WINDOW.apply):IsEnabled(), "putting away dropped the base")
	CloseSettings()
	Profiles.currentProfile.fontSize = nil

	-- Given the options put away once and no more.
	Open("sounds")
	Designs.Hide()
	Designs.Show()
	CloseSettings()

	-- When they are requested again.
	Designs.Show()

	-- Then the standalone window opens, for the page was remembered once only.
	assert(Frame():GetParent() == UIParent and Frame():IsShown() and not SettingsPanel:IsShown(),
		"a page stayed remembered")
	Window.Hide()
end

-- Rule: a page put away is forgotten when the frame docks again or another design takes its popups.
do
	-- Given the options put away at the Sounds page, and another category opened by hand.
	Open("sounds")
	Window.Hide(true)
	Open("profile")

	-- When the window is asked to show while it stands there.
	Window.Show()

	-- Then it stays at the category opened by hand.
	assert(currentPanel == panels.profile and Frame():GetParent() == panels.profile,
		"docking kept the page that was put away")
	CloseSettings()

	-- When the new window opens.
	Window.Show()

	-- Then it is the standalone window.
	assert(Frame():GetParent() == UIParent and not SettingsPanel:IsShown(), "docking did not forget the page")
	Window.Hide()

	-- Given the options put away at the Sounds page, and the classic design taking its popups.
	Open("sounds")
	Window.Hide(true)
	Popups.UseDesignPopups("classic")

	-- When the new window opens.
	Window.Show()

	-- Then it is the standalone window again.
	assert(Frame():GetParent() == UIParent and not SettingsPanel:IsShown(), "another design did not drop the page")
	Window.Hide()
end

-- Rule: closing for good drops the base and closes the settings window.
do
	-- Given a change in the docked window.
	Open("general")
	Profiles.SetOption(nil, "stackSimilarHits", true)

	-- When the window is hidden without keeping the base.
	Window.Hide()

	-- Then the settings window is closed, and the next opening is the standalone window with a new base.
	assert(not SettingsPanel:IsShown() and not Window.IsDocked(), "hiding left the settings window open")
	Window.Show()
	assert(Frame():GetParent() == UIParent, "a page was remembered after closing for good")
	Click(Button(L.WINDOW.cancel))
	assert(Profiles.currentProfile.stackSimilarHits == true, "hiding kept the base")
	Profiles.currentProfile.stackSimilarHits = nil
end

-- Rule: the Changes button opens the Changes category of the settings window.
do
	-- Given the docked window at the General page.
	Open("general")

	-- When the Changes button is clicked.
	Click(Footer())

	-- Then the settings window switches to the Changes category and shows its page.
	assert(currentPanel == panels.changes and Frame():GetParent() == panels.changes, "Changes did not open its category")
	local page = Find(Frame(), function(region) return region.parent and region.parent.parent == Frame() and region.shown
		and region.parent.width == 690 end)
	assert(page, "the Changes page is not shown")
	CloseSettings()
end
