-- Describe: restricted amounts reach the display without Lua formatting.
MikSBT = { Services = {}, Display = {} }
local secretAmount = {}
issecretvalue = function(value) return value == secretAmount end
local restricted = dofile("API/RestrictedValue.lua")
local formatter = dofile("Services/Formatter.lua")
local display = dofile("Display/DisplayService.lua")
local profile = { shortenNumbers = false }
formatter:Configure({ getProfile = function() return profile end })

-- Given an opaque amount which ordinary formatting cannot inspect.
BreakUpLargeNumbers = function() error("restricted number") end
assert(type(formatter.FormatRestrictedAmount) == "function",
    "restricted amount formatting support is missing")
assert(type(formatter.BuildRestrictedTemplate) == "function",
    "restricted amount template support is missing")

-- When a template and its separate amount are prepared.
local amount = formatter:FormatRestrictedAmount(secretAmount)
local template = formatter:BuildRestrictedTemplate("100% heal: +%a")
local received
local area = {}
display:Configure({
    getProfile = function() return profile end,
    isModDisabled = function() return false end,
    scrollAreas = {
        Resolve = function() return area end,
        IsSuppressedInGroup = function() return false end,
    },
    fonts = {},
    display = function(...) received = {...} end,
})
display:DisplayEvent({}, template, nil, nil, amount)

-- Then the opaque amount is forwarded separately and literal percent signs survive.
assert(received[12] == secretAmount,
    "the display lost the opaque amount argument")
assert(received[1] == "100%% heal: +%s",
    "the display template did not escape literal percent signs")
assert(not restricted:Equals(secretAmount, 1),
    "secret values were compared as readable data")
