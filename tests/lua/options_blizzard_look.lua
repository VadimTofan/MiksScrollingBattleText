-- Describe: the new options window wears Blizzard's options art where the client has all of it.
local env = dofile("tests/lua/options_window_env.lua")
env.art.available = true
-- The client slices textures; the window's rounded boxes and the list's ground use it.
env.Methods.SetTextureSliceMargins = function(self, ...) self.slice = { ... } end
local Window, L, Find, FindAll, Click, ClickEntry =
	env.Window, env.L, env.Find, env.FindAll, env.Click, env.ClickEntry
local Controls = MSBTOptions.Controls
local COLORS = Window.COLORS
local ICON = "Interface\\Addons\\MikScrollingBattleText\\MSBTOptions\\Designs\\Forever\\Artwork\\Flat"
-- Fonts & Colors has a page here, so the sidebar holds every entry.
Window.RegisterPage("fontsColors", function() end)

local function Point(region, point) return region.points and region.points[point] end
local function Outside(texture, region, left, top, right, bottom)
	local topLeft, bottomRight = Point(texture, "TOPLEFT"), Point(texture, "BOTTOMRIGHT")
	return topLeft and bottomRight and topLeft.relative == region and bottomRight.relative == region
		and topLeft.x == -left and topLeft.y == top and bottomRight.x == right and bottomRight.y == -bottom
end
local function RegionWith(frame, predicate)
	for _, region in ipairs(frame.regions) do
		if predicate(region) then return region end
	end
end
local function Atlas(name) return function(region) return region.atlas == name end end

-- Rule: the client's art is looked up once.
do
	-- Given the window was opened, which looked the art up.
	Window.Show()
	local queries = env.art.queries

	-- When more controls are skinned.
	Window.SkinCheckbox(Controls.CreateCheckbox(CreateFrame("Frame")))
	Window.SkinSlider(Controls.CreateSlider(CreateFrame("Frame")))

	-- Then the client was not asked again.
	assert(queries > 0 and env.art.queries == queries, "the art is looked up again")
end

-- Rule: a checkbox shows Blizzard's minimal box and checks, with no box of its own behind them.
do
	local checkbox = Controls.CreateCheckbox(CreateFrame("Frame"))
	Window.SkinCheckbox(checkbox)
	local check = checkbox.checkFrame
	assert(check:GetNormalTexture().atlas == "checkbox-minimal" and check:GetPushedTexture().atlas == "checkbox-minimal"
		and check:GetCheckedTexture().atlas == "checkmark-minimal"
		and check:GetDisabledCheckedTexture().atlas == "checkmark-minimal-disabled", "the checkbox is not Blizzard's")
	assert(not RegionWith(check, function(region) return region.color end), "the checkbox has a box behind it")
end

-- Rule: a slider shows Blizzard's track in three pieces and its untinted thumb, without the backdrop.
do
	local slider = Controls.CreateSlider(CreateFrame("Frame"))
	Window.SkinSlider(slider)
	local track = slider.sliderFrame
	local thumb = track:GetThumbTexture()
	assert(track.backdrop == nil, "the classic backdrop shows")
	assert(thumb.atlas == "Minimal_SliderBar_Button" and thumb.atlasSize and not thumb.vertexColor,
		"the thumb is not Blizzard's")
	local left = RegionWith(track, Atlas("Minimal_SliderBar_Left"))
	local right = RegionWith(track, Atlas("Minimal_SliderBar_Right"))
	local middle = RegionWith(track, Atlas("_Minimal_SliderBar_Middle"))
	assert(left and right and middle and Point(middle, "TOPLEFT").relative == left
		and Point(middle, "BOTTOMRIGHT").relative == right, "the track is not Blizzard's three pieces")
end

-- Rule: a disabled dropdown shows the disabled ground, and enabling brings the normal one back.
do
	local dropdown = Controls.CreateDropdown(CreateFrame("Frame"))
	dropdown:Configure(160)
	dropdown:AddItem("One", 1)
	Window.SkinDropdown(dropdown)

	-- When it is disabled and then enabled.
	dropdown:Disable()
	local disabled = dropdown.ground.atlas
	dropdown:Enable()

	-- Then the ground followed.
	assert(disabled == "common-dropdown-c-button-disabled", "a disabled dropdown has the ground " .. tostring(disabled))
	assert(dropdown.ground.atlas == "common-dropdown-c-button", "enabling kept the disabled ground")
end

-- Rule: a dropdown is Blizzard's field: the whole band is its button, the ground lies 7 outside it
-- and shows hover and open, and the chosen text is centred on one line 13 from both ends.
do
	local dropdown = Controls.CreateDropdown(CreateFrame("Frame"))
	dropdown:Configure(160)
	dropdown:AddItem("One", 1)
	Window.SkinDropdown(dropdown)
	local button, ground, text = dropdown.buttonFrame, dropdown.ground, dropdown.selectedFontString
	assert(button.alpha == 0 and Point(button, "BOTTOMLEFT") and Point(button, "BOTTOMRIGHT") and button.height == 25,
		"the field is not one invisible button")
	assert(ground and ground.atlas == "common-dropdown-c-button" and Outside(ground, button, 7, 7, 7, 7),
		"the ground is not Blizzard's")
	assert(text.justifyH == "CENTER" and text.wordWrap == false and Point(text, "LEFT").x == 13
		and Point(text, "RIGHT").x == -13, "the chosen text is not centred on one line")

	-- When the mouse enters, the list opens and closes, and the mouse leaves.
	button.scripts.OnEnter(button)
	local hovered = ground.atlas
	Click(button)
	local opened = ground.atlas
	Click(button)
	local closed = ground.atlas
	button.scripts.OnLeave(button)

	-- Then the ground follows.
	assert(hovered == "common-dropdown-c-button-hover-1" and opened == "common-dropdown-c-button-open"
		and closed == "common-dropdown-c-button-hover-1" and ground.atlas == "common-dropdown-c-button",
		"the ground does not follow hover and open")
end

-- Rule: a hovered dropdown shows Blizzard's small arrow under its field, at the art's size, 5 below
-- the button's bottom; a client without that art keeps the ground and shows no arrow.
do
	local arrowAtlas = "common-dropdown-c-button-hover-arrow"
	local function Arrow(dropdown) return RegionWith(dropdown, Atlas(arrowAtlas)) end
	local function NewDropdown()
		local dropdown = Controls.CreateDropdown(CreateFrame("Frame"))
		dropdown:Configure(160)
		dropdown:AddItem("One", 1)
		Window.SkinDropdown(dropdown)
		return dropdown
	end
	local dropdown = NewDropdown()
	local button, arrow = dropdown.buttonFrame, Arrow(dropdown)
	local anchor = arrow and Point(arrow, "BOTTOM")
	assert(arrow and arrow.atlasSize, "the arrow does not take the art's size")
	assert(anchor and anchor.relative == button and anchor.relativePoint == "BOTTOM" and anchor.x == 0 and anchor.y == -5,
		"the arrow is not 5 below the button's bottom")
	assert(not arrow.shown, "the arrow shows at rest")

	-- When the mouse enters, leaves, enters a disabled field and the state is refreshed without the mouse.
	button.scripts.OnEnter(button)
	local entered = arrow.shown
	button.scripts.OnLeave(button)
	local left = arrow.shown
	dropdown:Disable()
	button.scripts.OnEnter(button)
	local disabled = arrow.shown
	dropdown:Enable()
	button.scripts.OnEnter(button)
	dropdown:Enable()
	local refreshed = arrow.shown

	-- Then it shows only while the mouse is over an enabled field.
	assert(entered and not left and not disabled and not refreshed, "the arrow does not follow the mouse")

	-- Given a client without the arrow's art.
	env.art.missing = arrowAtlas
	local plain = NewDropdown()
	env.art.missing = nil
	assert(not Arrow(plain) and plain.ground.atlas == "common-dropdown-c-button", "a client without the arrow lost the ground")
end

-- Rule: the list lies on Blizzard's menu ground with the art's own slices. The entries lie 3 inside
-- the field's edges and 6 below it; the art reaches 18 above and 29 below them. Beside them it
-- reaches 3 and the art's margin of 16.3, which the client shrinks with the art while the ground is
-- lower than the art's 90: so the ground of a short list is narrower, and the panel it draws is as
-- wide as the field for a list of any length. A line under the mouse shows Blizzard's highlight at
-- 0.15.
do
	local function Side(entries) return 3 + 16.3 * math.min(1, (entries * 20 + 18 + 29) / 90) end
	local function OpenList(entries)
		local dropdown = Controls.CreateDropdown(CreateFrame("Frame"))
		dropdown:Configure(160)
		for index = 1, entries do dropdown:AddItem("Entry " .. index, index) end
		Window.SkinDropdown(dropdown)
		Click(dropdown.buttonFrame)
		local list = Find(dropdown, function(region) return region.displayFrame end)
		return dropdown, list, RegionWith(list, Atlas("common-dropdown-c-bg"))
	end
	assert(Side(1) < Side(2) and Side(2) < Side(3) and Side(3) == Side(9), "the widths to compare do not differ")
	for _, entries in ipairs({ 5, 2 }) do
		local other, otherList, otherGround = OpenList(entries)
		assert(otherGround and Outside(otherGround, otherList, Side(entries), 18, Side(entries), 29),
			"the ground of a list of " .. entries .. " entries is not as wide as its panel needs")
		Click(other.buttonFrame)
	end
	local dropdown, list, ground = OpenList(1)
	assert(ground and Outside(ground, list, Side(1), 18, Side(1), 29),
		"the ground of a list of one entry is not as wide as its panel needs")
	assert(ground.slice == nil, "the ground's own slices are overridden")
	local anchor = list.points.TOPLEFT
	assert(anchor.relative == dropdown and anchor.relativePoint == "BOTTOMLEFT" and anchor.x == 3 and anchor.y == -6
		and list.width == 154, "the entries do not keep Blizzard's distance to the panel")
	local hover = RegionWith(list.lines[1], Atlas("common-dropdown-customize-mouseover"))
	assert(hover and hover.layer == "HIGHLIGHT" and hover.alpha == 0.15, "a line has not Blizzard's highlight")
	Click(dropdown.buttonFrame)
end

-- Rule: an option button lies on Blizzard's button ground, a texture of its own 7 outside it that
-- follows the button's state, while its state textures show nothing (there the client stretches
-- the art instead of slicing it); the main button keeps the factory's red art.
do
	local button = Controls.CreateOptionButton(CreateFrame("Frame"))
	button:Configure(24, "Go")
	local main = Controls.CreateOptionButton(CreateFrame("Frame"))
	main:Configure(24, "Apply")
	local mainRegions = #main.regions
	Window.SkinButton(button)
	Window.SkinButton(main, true)
	local ground = button.ground
	assert(ground and ground.kind == "Texture" and ground.atlas == "common-dropdown-c-button"
		and Outside(ground, button, 7, 7, 7, 7), "the button has not Blizzard's ground")
	for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
		local texture = button["Get" .. state .. "Texture"](button)
		assert(texture.alpha == 0 and not texture.atlas, state .. " still draws on the button")
	end

	-- When the mouse enters, presses, lets go over the button and beside it, and leaves.
	local seen = {}
	local function Fire(event) button.scripts[event](button) seen[#seen + 1] = ground.atlas end
	Fire("OnEnter")
	Fire("OnMouseDown")
	button.IsMouseOver = function() return true end
	Fire("OnMouseUp")
	button.IsMouseOver = function() return false end
	Fire("OnMouseUp")
	Fire("OnEnter")
	Fire("OnLeave")

	-- Then the ground shows each state.
	assert(table.concat(seen, " ") == "common-dropdown-c-button-hover-1 common-dropdown-c-button-pressed-1 "
		.. "common-dropdown-c-button-hover-1 common-dropdown-c-button common-dropdown-c-button-hover-1 "
		.. "common-dropdown-c-button", "the ground does not follow the mouse: " .. table.concat(seen, " "))

	-- When the button is disabled and enabled again.
	button:Disable()
	button.scripts.OnDisable(button)
	local disabled = ground.atlas
	button.scripts.OnEnter(button)
	local hoveredWhileDisabled = ground.atlas
	button:Enable()
	button.scripts.OnEnable(button)

	-- Then a disabled button shows the disabled ground, also under the mouse.
	assert(disabled == "common-dropdown-c-button-disabled" and hoveredWhileDisabled == disabled
		and ground.atlas == "common-dropdown-c-button", "the ground does not follow the enabled state")
	assert(#main.regions == mainRegions and not main:GetNormalTexture().atlas
		and main:GetNormalTexture().texturePath == "Interface\\Buttons\\UI-Panel-Button-Up", "the main button lost its art")
end

-- Rule: an edit box keeps the factory's border, which is Blizzard's input art.
do
	local editbox = Controls.CreateEditbox(CreateFrame("Frame"))
	local regions = #editbox.regions
	Window.SkinEditbox(editbox)
	assert(#editbox.regions == regions and not RegionWith(editbox.editboxFrame, function(region)
		return not region.shown
	end), "the edit box lost its border")
end

-- Blizzard's minimal bar: a track with rounded ends; an 8 by 24 thumb drawn by rounded pieces that
-- follow the slider's own, invisible thumb; arrows of 17 by 11 with their own press and hover art,
-- 5 clear of the track.
local function AssertScrollBar(slider, up, down)
	local thumb = slider:GetThumbTexture()
	assert(thumb.width == 8 and thumb.height == 24 and thumb.alpha == 0, "the slider's thumb draws itself")
	local function Piece(atlas) return assert(RegionWith(slider, Atlas(atlas)), "the bar has no " .. atlas) end
	local trackTop, trackBottom = Piece("minimal-scrollbar-track-top"), Piece("minimal-scrollbar-track-bottom")
	local track = Piece("!minimal-scrollbar-track-middle")
	assert(Point(trackTop, "TOP").relative == slider and Point(trackBottom, "BOTTOM").relative == slider
		and Point(track, "TOPLEFT").relative == trackTop and Point(track, "BOTTOMRIGHT").relative == trackBottom,
		"the track has no rounded ends")
	local thumbTop, thumbBottom = Piece("minimal-scrollbar-small-thumb-top"), Piece("minimal-scrollbar-small-thumb-bottom")
	local middle = Piece("minimal-scrollbar-small-thumb-middle")
	assert(Point(thumbTop, "TOP").relative == thumb and Point(thumbBottom, "BOTTOM").relative == thumb
		and Point(middle, "TOPLEFT").relative == thumbTop and Point(middle, "BOTTOMRIGHT").relative == thumbBottom,
		"the thumb has no rounded ends that follow it")
	for button, arrow in pairs({ [up] = { "minimal-scrollbar-arrow-top", "BOTTOM", "TOP", 5 },
		[down] = { "minimal-scrollbar-arrow-bottom", "TOP", "BOTTOM", -5 } }) do
		local atlas, anchor = arrow[1], Point(button, arrow[2])
		local art, normal = button.ground, button:GetNormalTexture()
		assert(button.width == 17 and button.height == 11 and art and art.kind == "Texture" and art.atlas == atlas
			and art.atlasSize and Point(art, "CENTER") and (not normal or normal.alpha == 0),
			atlas .. " is not Blizzard's arrow at its own size on a texture of its own")
		button.scripts.OnEnter(button)
		local over = art.atlas
		button.scripts.OnMouseDown(button)
		local down = art.atlas
		button.scripts.OnLeave(button)
		assert(over == atlas .. "-over" and down == atlas .. "-down" and art.atlas == atlas,
			atlas .. " does not follow the mouse")
		assert(anchor and anchor.relative == slider and anchor.relativePoint == arrow[3] and anchor.y == arrow[4],
			atlas .. " is not 5 clear of the track")
	end
end

-- Rule: a checkbox's label takes the width it needs on one line, so it cannot wrap when the window
-- is scaled and the text comes out a little wider than the factory measured.
do
	local checkbox = Controls.CreateCheckbox(CreateFrame("Frame"))
	checkbox:Configure(20, "Label")
	Window.SkinCheckbox(checkbox)
	local label = checkbox.fontString
	assert(Point(label, "LEFT") and Point(label, "LEFT").relative == checkbox.checkFrame and Point(label, "RIGHT") == nil
		and label.wordWrap == false, "the label is held to the width of its box")
end

-- Rule: the thumb is as long as the share of the list that shows, and never shorter than 24.
do
	-- Given a list whose bar is 200 long and shows ten of forty items.
	local listbox = Controls.CreateListbox(CreateFrame("Frame"))
	Window.SkinListbox(listbox)
	local slider = listbox.sliderFrame
	slider.height = 200
	for index = 1, 10 do listbox.lines[index] = {} end

	-- When the list tells its bar how far it scrolls.
	slider:SetMinMaxValues(0, 30)
	slider.scripts.OnMinMaxChanged(slider)

	-- Then the thumb covers a quarter of the bar.
	assert(slider:GetThumbTexture().height == 50, "the thumb does not show a quarter of the list")

	-- When nearly all of a long list is out of sight, then the thumb keeps its least height.
	slider:SetMinMaxValues(0, 990)
	slider.scripts.OnMinMaxChanged(slider)
	assert(slider:GetThumbTexture().height == 24, "the thumb shrank below 24")
end

-- Rule: a listbox scrolls with Blizzard's minimal bar; its selection bar is the flat fill.
do
	local listbox = Controls.CreateListbox(CreateFrame("Frame"))
	Window.SkinListbox(listbox)
	AssertScrollBar(listbox.sliderFrame, listbox.upButton, listbox.downButton)
	local bar = listbox.highlightFrame.regions[1]
	assert(bar.color and bar.color[4] == 0.16 and bar.blendMode == "BLEND", "the selection bar is not a flat fill")
end

local general = Find(MSBTOptionsWindowFrame, function(region) return region.key == "general" end)
local sidebar = general:GetParent()

-- Rule: each sidebar group sits on Blizzard's header bar in a slot of 30, after a gap of 18 but for
-- the first, its label in GameFontHighlightMedium 20 from the left; every entry still fits.
do
	local tops, labels = {}, 0
	for _, region in ipairs(sidebar.regions) do
		if region.atlas == "Options_CategoryHeader_1" then tops[#tops + 1] = Point(region, "TOPLEFT").y end
		if region.template == "GameFontHighlightMedium" and Point(region, "LEFT").x == 20 then labels = labels + 1 end
	end
	assert(#tops == 3 and tops[1] == -46 and tops[2] == -(46 + 30 + 3 * 28 + 18) and tops[3] == -(178 + 30 + 5 * 28 + 18),
		"the group headers are not Blizzard's slots")
	assert(labels == 3, "the group labels are not Blizzard's")
	local lowest = 0
	for _, entry in ipairs(FindAll(sidebar, function(region) return region.key end)) do
		lowest = math.max(lowest, -Point(entry, "TOPLEFT").y + entry.height)
	end
	assert(lowest <= 640 - 64 - 48 - 2, "the entries do not fit the sidebar")
end

-- Rule: entries are gold and the selected one light on Blizzard's active bar; the mouse shows
-- Blizzard's hover bar.
do
	ClickEntry("general")
	local sounds = Find(sidebar, function(region) return region.key == "sounds" end)
	assert(general.fontString.textColor[1] == COLORS.text[1] and sounds.fontString.textColor[1] == COLORS.gold[1],
		"the entries do not take Blizzard's colours")
	assert(general.selected.atlas == "Options_List_Active" and general.selected.atlasSize
		and Point(general.selected, "CENTER") and general.selected.shown, "the selected entry is not on Blizzard's bar")
	local hover = RegionWith(general, Atlas("Options_List_Hover"))
	assert(hover and hover.layer == "HIGHLIGHT", "the entry has no Blizzard hover bar")
end

-- Rule: the page title is white in GameFontHighlightHuge; Blizzard's divider lies between the hint
-- line and the page, 3 above the page.
do
	local title = RegionWith(MSBTOptionsWindowFrame, function(region) return region.template == "GameFontHighlightHuge" end)
	assert(title and title:GetText() == general.label and not title.textColor, "the title is not Blizzard's")
	local divider = RegionWith(MSBTOptionsWindowFrame, Atlas("Options_HorizontalDivider"))
	assert(divider and Point(divider, "TOPLEFT").x == 250 and Point(divider, "TOPLEFT").y == -121,
		"the page has no divider")
end

-- Rule: a popup of the new design trades the paper-doll art and its tooltip panels for the window's
-- ground, and every factory control in it gets its skin, also on lines a listbox builds later.
do
	-- Given a popup with classic art, a panel and the factories' controls.
	local popup = CreateFrame("Frame")
	local art = popup:CreateTexture()
	art:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
	local panel = CreateFrame("Frame", nil, popup)
	panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	local checkbox = Controls.CreateCheckbox(panel)
	local dropdown = Controls.CreateDropdown(popup)
	local slider = Controls.CreateSlider(popup)
	local button = Controls.CreateOptionButton(popup)
	button:Configure(24, "Save")
	local icons = {}
	for _, kind in ipairs({ "Delete", "Configure", "FontSettings" }) do icons[kind] = Controls.CreateIconButton(popup, kind) end
	local listbox = Controls.CreateListbox(popup)
	listbox:Configure(200, 60, 20)
	listbox:SetCreateLineHandler(function(this)
		local line = CreateFrame("Button", nil, this)
		line.deleteButton = Controls.CreateIconButton(line, "Delete")
		return line
	end)
	listbox:SetDisplayHandler(function() end)

	-- When it is skinned and the listbox then builds a line.
	Window.SkinPopup(popup)
	listbox:AddItem("Hearthstone")

	-- Then the classic art gives way to the window's ground, and each control wears its skin.
	assert(not art.shown and panel.backdrop == nil, "the classic art shows")
	assert(RegionWith(popup, function(region) return region.color and region.color[1] == COLORS.window[1] end)
		and RegionWith(panel, function(region) return region.color and region.color[1] == COLORS.panel[1] end),
		"the popup has not the window's ground")
	assert(checkbox.checkFrame:GetNormalTexture().atlas == "checkbox-minimal", "the checkbox in the panel is classic")
	assert(dropdown.ground and slider.sliderFrame.backdrop == nil, "the dropdown or slider is classic")
	assert(button.ground and button.ground.atlas == "common-dropdown-c-button", "the option button is classic")
	assert(icons.Delete:GetNormalTexture().texturePath == ICON .. "Delete"
		and icons.Configure:GetNormalTexture().texturePath == ICON .. "Settings"
		and icons.FontSettings:GetNormalTexture().texturePath == ICON .. "Font", "an icon button is classic")
	assert(RegionWith(listbox.sliderFrame, Atlas("minimal-scrollbar-small-thumb-middle")), "the listbox is classic")
	assert(listbox.lines[1].deleteButton:GetNormalTexture().texturePath == ICON .. "Delete", "a later line is classic")
end

-- Rule: a scroll frame of the client's template in a popup of the new design scrolls with Blizzard's
-- minimal bar too, and the controls it scrolls get their skin; one without the template's keys stays.
do
	-- Given a popup with a scroll frame as the template builds it, holding a checkbox, and a bare scroll frame.
	local popup = CreateFrame("Frame")
	local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
	local bar = CreateFrame("Slider", nil, scroll)
	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	bar.ScrollUpButton = CreateFrame("Button", nil, bar, "UIPanelScrollUpButtonTemplate")
	bar.ScrollDownButton = CreateFrame("Button", nil, bar, "UIPanelScrollDownButtonTemplate")
	scroll.ScrollBar = bar
	local checkbox = Controls.CreateCheckbox(CreateFrame("Frame", nil, scroll))
	local bare = CreateFrame("ScrollFrame", nil, popup)

	-- When the popup is skinned.
	Window.SkinPopup(popup)

	-- Then the bar is Blizzard's, the checkbox is skinned and the bare scroll frame is untouched.
	AssertScrollBar(bar, bar.ScrollUpButton, bar.ScrollDownButton)
	assert(checkbox.checkFrame:GetNormalTexture().atlas == "checkbox-minimal", "the scrolled checkbox is classic")
	assert(#bare.regions == 0, "the bare scroll frame was changed")
end

print("Options Blizzard look tests passed")
