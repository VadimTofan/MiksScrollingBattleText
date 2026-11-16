-- Describe: inferred Windfury is baseline behavior without a General toggle.
MikSBT = { translations = {} }
dofile("MSBTOptions/Localization/localization.lua")
local translations = MikSBT.translations

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
        ipairs = ipairs, math = math, IsForever = forever, L = translations,
        tabFrames = { general = frame }, MSBTProfiles = profiles,
        MSBTControls = {
            CreateCheckbox = NewControl, CreateSlider = NewControl,
            CreateOptionButton = NewControl,
        },
        MSBTDesigns = { keys = {} },
    }
    local build = assert(loadstring(createSource .. "\n" .. populateSource ..
        "\nreturn GeneralTab_Create, GeneralTab_Populate"))
    setfenv(build, environment)
    local create, populate = build()

    -- When General opens with an old disabled preference.
    create()
    populate()
    local checkbox = frame.controls.inferredWindfuryIconsCheckbox

    -- Then General exposes no retired inference toggle on either client.
    assert(checkbox == nil, "General still offers inferred Windfury icons")
    assert(translations.CHECKBOXES.inferredWindfuryIcons == nil)
    assert(#savedKeys == 0)
end
