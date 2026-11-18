-- Describe: the General tab shows the client's settings for effects on targets and for reputation
-- and honor at the character as boxes below Blizzard's sub-options.
local function Noop() end
local function NewControl()
	local control = setmetatable({}, {
		__index = function() return Noop end,
	})
	function control:Configure(_, label, tooltip) self.label, self.tooltip = label, tooltip end
	function control:SetClickHandler(handler) self.click = handler end
	function control:SetChecked(value) self.checked = value end
	function control:SetValue(value) self.value = value end
	function control:Hide() self.hidden = true end
	function control:Show() self.hidden = false end
	function control:SetSize(width, height) self.size = { width, height } end
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

-- Given a profile, and the client's settings as the switches show them: the own effects are off, the
-- other players' effects on, and the text at the character shows reputation but not honor.
local profile = { blizzardDamageEnabled = true, animationSpeed = 100 }
local textures = {}
local function NewTexture(...)
	local texture = NewControl(...)
	textures[#textures + 1] = texture
	return texture
end
local frame = { CreateFontString = NewControl, CreateTexture = NewTexture }
local client = { effectsOwn = false, effectsOthers = true, reputation = true, honor = false }
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
			return { label = key, tooltip = key .. ".tooltip" }
		end })
	end }),
	MSBTProfiles = {
		currentProfile = profile,
		IsModDisabled = function() return false end,
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

-- Given the client has the own-effects setting off and the other-players setting on.
local own, others = controls.ownSpellMechanicsCheckbox, controls.othersSpellMechanicsCheckbox
assert(own and others, "the spell mechanics checkboxes are missing")
assert(own.label == "spellMechanicsOwn" and others.label == "spellMechanicsOthers",
	"the boxes take each other's texts")

-- Then both stand at the left edge of the Blizzard column, below its sub-options.
local column = controls.blizzardDamageCheckbox
assert(own.point[1] == "TOPLEFT" and own.point[2] == column and own.point[3] == "TOPLEFT",
	"the own box is not below the sub-options")
assert(own.point[4] == 0 and own.point[5] == -102, "the own box is not below the sub-options")
assert(others.point[2] == column and others.point[4] == 0 and others.point[5] == -126,
	"the other-players box is not below the own box")

-- Then the boxes of the text at the character follow, with their own texts.
local reputation, honor = controls.blizzardReputationCheckbox, controls.blizzardHonorCheckbox
assert(reputation and honor, "the reputation and honor checkboxes are missing")
assert(reputation.label == "blizzardReputation" and honor.label == "blizzardHonor",
	"the boxes take each other's texts")
assert(reputation.tooltip == "blizzardReputation.tooltip" and honor.tooltip == "blizzardHonor.tooltip",
	"a box has the wrong tooltip")
assert(reputation.point[2] == column and reputation.point[4] == 0 and reputation.point[5] == -150,
	"the reputation box is not below the effect boxes")
assert(honor.point[2] == column and honor.point[4] == 0 and honor.point[5] == -174,
	"the honor box is not below the reputation box")

-- Then the divider is as long as the column.
assert(textures[1].size[2] == 198, "the divider does not reach the new boxes")
-- Then the slider stands lower, clear of the last box.
assert(controls.animationSpeedSlider.point[5] == 2, "the slider crowds the last box")
local profileBefore = {}
for key, value in pairs(profile) do profileBefore[key] = value end

-- When General is populated.
populate()

-- Then each box shows the client's value, and all four are visible.
assert(own.checked == false and others.checked == true, "the boxes do not show the client's value")
assert(own.hidden == false and others.hidden == false, "a box of a present setting is hidden")
assert(reputation.checked == true and honor.checked == false, "the text boxes do not show the client's value")
assert(reputation.hidden == false and honor.hidden == false, "a box of a present setting is hidden")

-- Given the setting changed elsewhere, such as in Blizzard's menu.
client.effectsOwn, client.effectsOthers = true, false
-- When the tab is populated again.
populate()
-- Then the boxes follow it.
assert(own.checked == true and others.checked == false, "the boxes do not follow the client")

-- When a box is clicked.
own.click(own, false)
others.click(others, true)

-- Then the client's setting is written for that box alone.
assert(table.concat(clientWrites, ",") == "effectsOwn=false,effectsOthers=true",
	"a click does not write the client's setting for its box")
populate()
assert(own.checked == false and others.checked == true, "the boxes do not show what was written")

-- When the boxes of the text at the character are clicked.
clientWrites = {}
reputation.click(reputation, false)
honor.click(honor, true)
-- Then each writes its own setting.
assert(table.concat(clientWrites, ",") == "reputation=false,honor=true",
	"a click does not write the client's setting for its box")
populate()
assert(reputation.checked == false and honor.checked == true, "the text boxes do not show what was written")
-- Given the client changes them elsewhere.
client.reputation, client.honor = true, false
-- When the tab is populated again, then the boxes follow it.
populate()
assert(reputation.checked == true and honor.checked == false, "the text boxes do not follow the client")

-- Then nothing in the profile changed.
for key, value in pairs(profile) do assert(profileBefore[key] == value, key) end
for key in pairs(profileBefore) do assert(profile[key] == profileBefore[key], key) end

-- Given the client lacks the setting for other players' targets.
client.effectsOthers = nil
-- When General is populated.
populate()
-- Then its box is hidden and the other one stays.
assert(others.hidden == true and own.hidden == false, "a box of a missing setting stays visible")
-- When the client lacks the honor setting too.
client.honor = nil
populate()
-- Then its box is hidden and the reputation box stays.
assert(honor.hidden == true and reputation.hidden == false, "a box of a missing setting stays visible")
client.honor = false

-- When the client has it again.
client.effectsOthers = false
populate()
-- Then the box is back, unchecked.
assert(others.hidden == false and others.checked == false, "the box does not come back")

-- Given a profiles module that does not offer the two functions.
local offeredGet = environment.MSBTProfiles.GetBlizzardSwitch
local offeredSet = environment.MSBTProfiles.SetBlizzardSwitch
environment.MSBTProfiles.GetBlizzardSwitch = nil
environment.MSBTProfiles.SetBlizzardSwitch = nil
-- When General is populated.
populate()
-- Then it populates without an error and the boxes are hidden.
assert(own.hidden == true and others.hidden == true, "boxes show without the functions")
assert(reputation.hidden == true and honor.hidden == true, "boxes show without the functions")
environment.MSBTProfiles.GetBlizzardSwitch = offeredGet
environment.MSBTProfiles.SetBlizzardSwitch = offeredSet
populate()
assert(own.hidden == false and others.hidden == false, "boxes stay hidden when the functions return")
assert(reputation.hidden == false and honor.hidden == false, "boxes stay hidden when the functions return")

-- Given a client that has only the settings for the text at the character.
client.effectsOwn, client.effectsOthers = nil, nil
local textOnly = { CreateFontString = NewControl, CreateTexture = NewTexture }
environment.tabFrames.general = textOnly
textures = {}
-- When General is created.
create()
-- Then only that pair is made, right below the sub-options, and the divider fits it.
assert(textOnly.controls.ownSpellMechanicsCheckbox == nil, "effect boxes are made without their settings")
assert(textOnly.controls.blizzardReputationCheckbox and textOnly.controls.blizzardHonorCheckbox,
	"the text boxes are missing without the effect settings")
assert(textOnly.controls.blizzardReputationCheckbox.point[5] == -102
	and textOnly.controls.blizzardHonorCheckbox.point[5] == -126, "the text boxes leave a gap")
assert(textures[1].size[2] == 150, "the divider does not fit one pair")
assert(textOnly.controls.animationSpeedSlider.point[5] == 10, "the slider moved without the full column")

-- Given a client that has only the settings for the effects.
client.effectsOwn, client.effectsOthers, client.reputation, client.honor = true, false, nil, nil
local effectsOnly = { CreateFontString = NewControl, CreateTexture = NewTexture }
environment.tabFrames.general = effectsOnly
textures = {}
-- When General is created.
create()
-- Then the text boxes are not made and the divider fits the effects.
assert(effectsOnly.controls.ownSpellMechanicsCheckbox, "effect boxes are missing")
assert(effectsOnly.controls.blizzardReputationCheckbox == nil
	and effectsOnly.controls.blizzardHonorCheckbox == nil, "text boxes are made without their settings")
assert(textures[1].size[2] == 150, "the divider does not fit one pair")
environment.tabFrames.general = frame
client.effectsOwn, client.effectsOthers, client.reputation, client.honor = true, false, true, false

-- Given a client that has none of the settings.
client.effectsOwn, client.effectsOthers, client.reputation, client.honor = nil, nil, nil, nil
local bare = { CreateFontString = NewControl, CreateTexture = NewTexture }
environment.tabFrames.general = bare
textures = {}
-- When General is created and populated.
create()
populate()
-- Then no boxes exist, nothing errors and the divider keeps its short length.
assert(bare.controls.ownSpellMechanicsCheckbox == nil, "boxes are made without the settings")
assert(bare.controls.othersSpellMechanicsCheckbox == nil, "boxes are made without the settings")
assert(bare.controls.blizzardReputationCheckbox == nil and bare.controls.blizzardHonorCheckbox == nil,
	"boxes are made without the settings")
assert(textures[1].size[2] == 108, "the divider leaves empty space without the settings")
assert(bare.controls.animationSpeedSlider.point[5] == 10, "the slider moved without the boxes")

-- Given no profiles functions at all.
environment.MSBTProfiles.GetBlizzardSwitch = nil
local plain = { CreateFontString = NewControl, CreateTexture = NewTexture }
environment.tabFrames.general = plain
textures = {}
-- When General is created and populated.
create()
populate()
-- Then no boxes exist and the divider keeps its short length.
assert(plain.controls.ownSpellMechanicsCheckbox == nil, "boxes are made without the functions")
assert(plain.controls.blizzardReputationCheckbox == nil, "boxes are made without the functions")
assert(textures[1].size[2] == 108, "the divider leaves empty space without the functions")
environment.MSBTProfiles.GetBlizzardSwitch = offeredGet

-- Given a client that has only one of them.
client.effectsOwn = true
local single = { CreateFontString = NewControl, CreateTexture = NewTexture }
environment.tabFrames.general = single
textures = {}
-- When General is created.
create()
-- Then the boxes exist and the divider is long.
assert(single.controls.ownSpellMechanicsCheckbox and textures[1].size[2] == 150,
	"a client with one setting gets no box or a short divider")

print("Blizzard text box tests passed")
