-- Describe: inferred Windfury is an explicit, experimental Forever option.
MikSBT = { translations = {} }
dofile("MSBTOptions/Localization/localization.lua")
local translations = MikSBT.translations

-- Given the English option text displayed in General.
local locale = translations.CHECKBOXES.inferredWindfuryIcons

-- When its label and tooltip are shown.
-- Then the wording distinguishes estimates and leaves ambiguity visible.
assert(locale, "inferred Windfury option text is missing")
assert(locale.label == "Show inferred Windfury icons")
assert(locale.tooltip:find("[Ee]xperimental"))
assert(locale.tooltip:find("estimated Windfury", 1, true))
assert(locale.tooltip:find("[Aa]mbiguous hits stay without an icon"))

local function Noop() end
local function NewControl()
    local control = setmetatable({}, {
        __index = function() return Noop end,
    })
    function control:Configure(_, label, tooltip)
        self.label, self.tooltip = label, tooltip
    end
    function control:SetClickHandler(handler) self.click = handler end
    function control:SetChecked(value) self.checked = value end
    return control
end

local file = assert(io.open("MSBTOptions/MSBTOptionsTabs.lua", "r"))
local source = file:read("*a")
file:close()
local createSource = assert(source:match(
    "local function GeneralTab_Create%b()%s*.-\nend"))
local populateSource = assert(source:match(
    "GeneralTab_Populate = function%b()%s*.-\nend"))

for _, forever in ipairs({ true, false }) do
    -- Given the same profile on Forever and on an unsupported client.
    local profile = { inferredWindfuryIcons = false, animationSpeed = 100 }
    local frame = { CreateFontString = NewControl, CreateTexture = NewControl }
    local savedKeys = {}
    local profiles
    profiles = {
        currentProfile = profile,
        IsModDisabled = function() return false end,
        SetOption = function(path, key, value)
            assert(path == nil, "inferred icons saved to a nested section")
            savedKeys[#savedKeys + 1] = key
            profiles.currentProfile[key] = value
        end,
    }
    local environment = {
        ipairs = ipairs, IsForever = forever, L = translations,
        tabFrames = { general = frame }, MSBTProfiles = profiles,
        MSBTControls = {
            CreateCheckbox = NewControl, CreateSlider = NewControl,
            CreateOptionButton = NewControl,
        },
    }
    local build = assert(loadstring(createSource .. "\n" .. populateSource ..
        "\nreturn GeneralTab_Create, GeneralTab_Populate"))
    setfenv(build, environment)
    local create, populate = build()

    -- When General opens with the default preference.
    create()
    populate()
    local checkbox = frame.controls.inferredWindfuryIconsCheckbox

    -- Then the trial is offered only on Forever and starts unchecked.
    if forever then
        assert(checkbox, "Forever has no inferred Windfury checkbox")
        assert(checkbox.checked == false)
        assert(checkbox.label == locale.label)
        assert(checkbox.tooltip == locale.tooltip)

        -- When the user enables the trial.
        checkbox.click(checkbox, true)
        populate()

        -- Then only the explicit icon preference is enabled.
        assert(profile.inferredWindfuryIcons == true)
        assert(checkbox.checked == true)
        assert(#savedKeys == 1 and savedKeys[1] == "inferredWindfuryIcons")
        assert(profile.skillIconsDisabled == nil)

        -- Given another profile has never opted into the trial.
        profiles.currentProfile = { animationSpeed = 100 }

        -- When General refreshes after the profile switch.
        populate()

        -- Then the previous profile's opt-in does not carry over.
        assert(checkbox.checked == false)
        assert(profile.inferredWindfuryIcons == true)

        -- Given a malformed saved value is not an explicit opt-in.
        profiles.currentProfile.inferredWindfuryIcons = "true"
        -- When its settings populate.
        populate()
        -- Then it remains unchecked.
        assert(checkbox.checked == false)

        -- Given the original profile is selected again.
        profiles.currentProfile = profile
        -- When the user turns the trial off.
        checkbox.click(checkbox, false)
        populate()
        -- Then the preference is false and the checkbox is unchecked.
        assert(profile.inferredWindfuryIcons == false)
        assert(checkbox.checked == false)
    else
        assert(checkbox == nil,
            "unsupported client offered the Forever icon trial")
        assert(#savedKeys == 0)
    end
end
