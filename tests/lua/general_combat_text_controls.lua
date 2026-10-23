-- Describe: the General controls bind the two independent combat-text toggles.
local function Noop() end
local function NewControl()
	local control = setmetatable({}, {
		__index = function() return Noop end,
	})
	function control:Configure(_, label) self.label = label end
	function control:SetClickHandler(handler) self.click = handler end
	function control:SetChecked(value) self.checked = value end
	function control:SetValue(value) self.value = value end
	function control:SetPoint(...) self.point = { ... } end
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
local environment = {
	ipairs = ipairs,
	tabFrames = { general = frame },
	MSBTControls = {
		CreateCheckbox = NewControl,
		CreateSlider = NewControl,
		CreateOptionButton = NewControl,
	},
	L = setmetatable({}, { __index = function()
		return setmetatable({}, { __index = function(_, key)
			return { label = key }
		end })
	end }),
	MSBTProfiles = {
		currentProfile = profile,
		IsModDisabled = function() return disabled end,
		SetOptionUserDisabled = function(value)
			disabled = value
			if not value then profile.blizzardDamageEnabled = false end
		end,
		SetOption = function(_, key, value) profile[key] = value end,
		ApplyContextOptions = function() applied = applied + 1 end,
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
		control.click(control, true)
		populate()

		-- Then the preference persists without disabling either system.
		assert(profile[key] == true and control.checked)
		assert(not disabled and profile.blizzardDamageEnabled)
		control.click(control, false)
	end
end
applied = 0

assert(controls.animationSpeedSlider.value == 100)
assert(controls.enableSoundsCheckbox.checked == true)
assert(controls.enableIconsCheckbox.checked == true)
assert(controls.stickyCritsCheckbox.checked == true)
assert(controls.shortenNumbersCheckbox ~= nil)
assert(controls.stackSimilarHitsCheckbox ~= nil)
assert(controls.masterFontButton ~= nil)
assert(controls.addCustomSoundButton ~= nil)

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
