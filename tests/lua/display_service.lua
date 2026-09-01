MikSBT = {
	Display = {},
}

local calls = {}
local profile = {
	critFontSize = 30,
	critFontName = "Crit Font",
	critOutlineIndex = 3,
	critFontAlpha = 90,
	normalFontSize = 18,
	normalFontName = "Normal Font",
	normalOutlineIndex = 1,
	normalFontAlpha = 80,
	stickyCritsDisabled = false,
	soundsDisabled = false,
	skillIconsDisabled = false,
}
local area = {
	name = "Outgoing",
	critFontSize = 32,
	critFontName = "Area Crit",
	critOutlineIndex = 2,
	critFontAlpha = 85,
	normalFontSize = 20,
	normalFontName = "Area Normal",
	normalOutlineIndex = 1,
	normalFontAlpha = 75,
}
local scrollAreas = {
	areas = { Outgoing = area },
	Resolve = function()
		return area
	end,
	ResolveKey = function()
		return "Outgoing"
	end,
	IsSuppressedInGroup = function()
		return false
	end,
}

local DisplayService = dofile("Display/DisplayService.lua")
DisplayService:Configure({
	getProfile = function()
		return profile
	end,
	scrollAreas = scrollAreas,
	fonts = {
		["Area Crit"] = "crit.ttf",
		["Area Normal"] = "normal.ttf",
	},
	iterateSounds = function()
		return pairs({})
	end,
	playSound = function() end,
	isModDisabled = function()
		return false
	end,
	display = function(...)
		calls[#calls + 1] = { ... }
	end,
	outlineMap = { "", "OUTLINE", "THICKOUTLINE" },
	defaultArea = "Notification",
	defaultSoundPath = "Sounds/",
})

-- Given / When
DisplayService:DisplayEvent({
	scrollArea = "Outgoing",
	isCrit = true,
	colorR = 1,
	colorG = 0,
	colorB = 0,
}, "Critical", 100)
DisplayService:DisplayMessage(
	"Public",
	"Outgoing",
	false,
	255,
	128,
	0,
	20,
	"Area Normal",
	1,
	nil
)

-- Then
assert(#calls == 2, "display calls were not forwarded")
assert(calls[1][1] == "Critical", "event message changed")
assert(calls[1][3] == true, "critical event was not sticky")
assert(calls[1][7] == 32, "area critical font size was ignored")
assert(calls[1][8] == "crit.ttf", "critical font was not resolved")
assert(calls[2][4] == 1 and calls[2][5] == 128 / 255,
	"public message colors were not normalized")
assert(calls[2][7] == 20, "public message font size changed")
