-- Describe: the General controls bind the two independent combat-text toggles.
local function Noop() end
local function NewControl()
	local control = setmetatable({}, {
		__index = function() return Noop end,
	})
	function control:Configure(_, label, tooltip) self.label, self.tooltip = label, tooltip end
	function control:SetClickHandler(handler) self.click = handler end
	function control:SetChecked(value) self.checked = value end
	function control:SetValue(value) self.value = value end
	function control:SetPoint(...) self.point = { ... } end
	-- As wide as its label, like a checkbox of the client.
	function control:GetWidth() return #tostring(self.label or "") * 7 end
	return control
end

local file = assert(io.open("MSBTOptions/MSBTOptionsTabs.lua", "r"))
local source = file:read("*a")
file:close()
local createSource = assert(source:match(
	"local function GeneralTab_Create%b()%s*.-\nend"))
local populateSource = assert(source:match(
	"GeneralTab_Populate = function%b()%s*.-\nend"))
local build = assert(loadstring(createSource .. "\n" .. populateSource ..
	"\nreturn GeneralTab_Create, GeneralTab_Populate"))

-- Given the existing appearance settings and the two enabled text systems.
local disabled = false
local profile = {
	blizzardDamageEnabled = true, animationSpeed = 100, hideSkills = true,
}
local frame = { CreateFontString = NewControl, CreateTexture = NewControl }
local applied = 0
-- The client's numbers over targets as their switch shows them: on.
local client = { numbers = true }
local clientWrites = {}
local environment = {
	ipairs = ipairs,
	math = math,
	tabFrames = { general = frame },
	MSBTDesigns = { keys = {} },
	MSBTControls = {
		CreateCheckbox = NewControl,
		CreateSlider = NewControl,
		CreateOptionButton = NewControl,
	},
	L = setmetatable({}, { __index = function()
		return setmetatable({}, { __index = function(_, key)
			return { label = key, tooltip = key .. ".tooltip",
				blizzardTooltip = key .. ".blizzardTooltip" }
		end })
	end }),
	MSBTProfiles = {
		currentProfile = profile,
		IsModDisabled = function() return disabled end,
		SetOptionUserDisabled = function(value)
			disabled = value
			if not value then
				profile.blizzardDamageEnabled = false
				client.numbers = false
			end
		end,
		SetOption = function(_, key, value) profile[key] = value end,
		ApplyContextOptions = function() applied = applied + 1 end,
		GetBlizzardSwitch = function(name) return client[name] end,
		SetBlizzardSwitch = function(name, value)
			clientWrites[#clientWrites + 1] = name .. "=" .. tostring(value)
			client[name] = value
		end,
	},
}
setfenv(build, environment)
local create, populate = build()

-- When General is opened.
create()
populate()
local controls = frame.controls

-- Then both toggles and all the existing appearance controls populate.
assert(controls.enableCheckbox.checked == true)
assert(controls.blizzardDamageCheckbox.checked == true)

-- Given independent category switches beneath both master toggles.
for _, side in ipairs({ "msbt", "blizzard" }) do
	for _, category in ipairs({ "Outgoing", "Notifications", "Incoming" }) do
		local control = controls[side .. category .. "Checkbox"]
		local key = side .. category .. "Disabled"
		assert(control and not control.checked, key .. " did not populate")

		-- When only this category is disabled.
		applied = 0
		control.click(control, true)
		populate()

		-- Then the preference persists without disabling either system.
		if key == "blizzardOutgoingDisabled" then
			-- Then Blizzard's outgoing box hides the client's numbers, not a profile option.
			assert(client.numbers == false and profile[key] == nil,
				"Blizzard's outgoing box does not switch the numbers")
			assert(clientWrites[#clientWrites] == "numbers=false",
				"Blizzard's outgoing box does not switch the numbers")
		else
			assert(profile[key] == true and applied == 1, key .. " is not saved and applied")
		end
		assert(control.checked, key .. " does not show the click")
		assert(not disabled and profile.blizzardDamageEnabled)
		control.click(control, false)
	end
end
assert(client.numbers == true, "unchecking Blizzard's outgoing box does not show the numbers")
applied = 0
clientWrites = {}

-- Then Blizzard's outgoing box says what it switches, and MSBT's keeps its text.
assert(controls.blizzardOutgoingCheckbox.tooltip == "disableOutgoing.blizzardTooltip",
	"Blizzard's outgoing box has the tooltip of MSBT's")
assert(controls.msbtOutgoingCheckbox.tooltip == "disableOutgoing.tooltip",
	"MSBT's outgoing box lost its tooltip")

-- Given the numbers over targets are switched off elsewhere.
client.numbers = false
-- When General is populated.
populate()
-- Then Blizzard's outgoing box shows them as disabled.
assert(controls.blizzardOutgoingCheckbox.checked == true, "the outgoing box does not show the numbers")
client.numbers = true
populate()
assert(controls.blizzardOutgoingCheckbox.checked == false, "the outgoing box does not show the numbers")
-- Given the box shows the numbers as disabled, and then a client without the setting it reads.
client.numbers = false
populate()
client.numbers = nil
-- When General is populated.
populate()
-- Then the box is not checked, as only numbers known to be hidden check it.
assert(controls.blizzardOutgoingCheckbox.checked == false,
	"the outgoing box is checked where the client lacks the setting")
client.numbers = true
populate()

assert(controls.animationSpeedSlider.value == 100)
assert(controls.enableSoundsCheckbox == nil)
assert(controls.enableIconsCheckbox.checked == true)
assert(controls.stickyCritsCheckbox.checked == true)
assert(controls.shortenNumbersCheckbox ~= nil)
assert(controls.stackSimilarHitsCheckbox ~= nil)
assert(controls.masterFontButton ~= nil)
assert(controls.addCustomSoundButton == nil)
assert(controls.shortenNumbersCheckbox.point[2] == frame,
	"General layout still depends on the removed sound toggle")
assert(controls.shortenNumbersCheckbox.point[5] ==
	controls.classColorsButton.point[5],
	"appearance checkboxes do not align with the bottom controls")

-- Given a profiles module that does not offer the switches.
local offeredGet = environment.MSBTProfiles.GetBlizzardSwitch
environment.MSBTProfiles.GetBlizzardSwitch = nil
profile.blizzardOutgoingDisabled = true
-- When General is populated.
populate()
-- Then Blizzard's outgoing box shows the profile's option, as before the switch.
assert(controls.blizzardOutgoingCheckbox.checked == true, "the outgoing box breaks without the functions")
profile.blizzardOutgoingDisabled = nil
environment.MSBTProfiles.GetBlizzardSwitch = offeredGet
populate()

-- Given MSBT is off and the numbers over targets are shown.
disabled, client.numbers, clientWrites = true, true, {}
-- When Blizzard text is unchecked and checked again.
controls.blizzardDamageCheckbox.click(controls.blizzardDamageCheckbox, false)
controls.blizzardDamageCheckbox.click(controls.blizzardDamageCheckbox, true)
populate()
-- Then the numbers are left to their own box.
assert(#clientWrites == 0 and client.numbers == true, "the Blizzard text box switched the numbers")
assert(controls.blizzardOutgoingCheckbox.checked == false, "the Blizzard text box switched the numbers")
-- When MSBT is enabled.
controls.enableCheckbox.click(controls.enableCheckbox, true)
-- Then Blizzard's outgoing box shows the numbers as disabled.
assert(controls.blizzardOutgoingCheckbox.checked == true,
	"enabling MSBT left the numbers over targets shown")
-- Back to MSBT and Blizzard text on, with the numbers shown, for the rules below.
profile.blizzardDamageEnabled, client.numbers, clientWrites, applied = true, true, {}, 0
populate()

-- Given the default profile hides skill names.
local namesCheckbox = controls.enableNamesCheckbox

-- When General is populated.
populate()

-- Then names are unchecked directly above icons, below the slider.
assert(namesCheckbox, "Enable Skill Names checkbox is missing")
assert(namesCheckbox.checked == false)
assert(namesCheckbox.point[1] == "BOTTOMLEFT")
assert(namesCheckbox.point[2] == controls.enableIconsCheckbox)
assert(namesCheckbox.point[3] == "TOPLEFT")
assert(controls.animationSpeedSlider.point[2] == namesCheckbox)

-- When skill names are enabled.
namesCheckbox.click(namesCheckbox, true)
populate()

-- Then only the saved skill-name preference changes.
assert(profile.hideSkills == false and namesCheckbox.checked == true)
assert(controls.enableIconsCheckbox.checked == true)

-- Given another profile still hides skill names.
environment.MSBTProfiles.currentProfile = { hideSkills = true }

-- When the tab refreshes after a profile change.
populate()

-- Then the checkbox reflects the selected profile.
assert(namesCheckbox.checked == false)
environment.MSBTProfiles.currentProfile = profile
populate()
assert(namesCheckbox.checked == true)

-- When skill names are disabled again.
namesCheckbox.click(namesCheckbox, false)
populate()

-- Then hiding is saved without disabling icons.
assert(profile.hideSkills == true and namesCheckbox.checked == false)
assert(controls.enableIconsCheckbox.checked == true)

-- When Blizzard damage is unchecked while MSBT stays enabled.
controls.blizzardDamageCheckbox.click(controls.blizzardDamageCheckbox, false)
populate()

-- Then the new saved preference changes and the MSBT checkbox stays checked.
assert(profile.blizzardDamageEnabled == false and applied == 1)
assert(controls.blizzardDamageCheckbox.checked == false)
assert(controls.enableCheckbox.checked == true)

-- When MSBT is unchecked and Blizzard damage is checked.
controls.enableCheckbox.click(controls.enableCheckbox, false)
controls.blizzardDamageCheckbox.click(controls.blizzardDamageCheckbox, true)
populate()

-- Then each checkbox shows its own preference.
assert(disabled == true and profile.blizzardDamageEnabled == true)
assert(controls.enableCheckbox.checked == false)
assert(controls.blizzardDamageCheckbox.checked == true)

-- Given MSBT is unchecked and Blizzard damage is checked.
-- When the user checks Enable MSBT.
controls.enableCheckbox.click(controls.enableCheckbox, true)

-- Then both checkboxes immediately show the resulting preferences.
assert(not disabled and profile.blizzardDamageEnabled == false)
assert(controls.enableCheckbox.checked == true)
assert(controls.blizzardDamageCheckbox.checked == false,
	"enabling MSBT left the Blizzard damage checkbox checked")

-- Given labels of different lengths in the column that hangs from its bottom checkbox.
local widest = 0
for _, name in ipairs({ "shortenNumbers", "stackSimilarHits", "stickyCrits", "enableIcons", "enableNames" }) do
	widest = math.max(widest, controls[name .. "Checkbox"]:GetWidth())
end
local bottom = controls.shortenNumbersCheckbox
assert(widest > bottom:GetWidth(), "the labels do not differ in length")

-- Then the column stands left by what its widest label needs, so no label runs past the window.
assert(bottom.point[1] == "BOTTOMRIGHT" and bottom.point[4] == bottom:GetWidth() - widest - 30,
	"a label longer than the bottom one runs past the window")
