MikSBT = {
	Configuration = {},
}

local registrations = {}
local callback
local sharedMedia = {
	Register = function(_, mediaType, name, path)
		registrations[mediaType .. ":" .. name] = path
	end,
	List = function(_, mediaType)
		if mediaType == "font" then
			return { "Shared Font" }
		end
		return { "Shared Sound" }
	end,
	Fetch = function(_, mediaType, name)
		return "Shared/" .. mediaType .. "/" .. name
	end,
	RegisterCallback = function(_, _, _, handler)
		callback = handler
	end,
}

local MediaRegistry = dofile("Configuration/MediaRegistry.lua")
local registry = MediaRegistry:New({
	sharedMedia = sharedMedia,
	defaultFonts = { ["Default Font"] = "Fonts/Default.ttf" },
	defaultSounds = { ["Default Sound"] = "Interface/AddOns/MSBT/Default.ogg" },
})

-- Given built-in and shared media
-- When the registry initializes
registry:Initialize()

-- Then both sources are available
assert(registry.fonts["Default Font"] == "Fonts/Default.ttf",
	"default font was not registered")
assert(registry.fonts["Shared Font"] == "Shared/font/Shared Font",
	"shared font was not imported")
assert(registry.sounds["Default Sound"], "default sound was not registered")
assert(registry.sounds["Shared Sound"], "shared sound was not imported")
assert(callback, "shared-media callback was not registered")

-- Given saved custom media
-- When saved media loads
registry:LoadSavedMedia({
	fonts = { Custom = "Fonts/Custom.ttf" },
	sounds = { Alert = "Interface/AddOns/MSBT/Alert.ogg" },
})

-- Then custom media is registered and invalid values are ignored
assert(registry.fonts.Custom == "Fonts/Custom.ttf",
	"saved font was not loaded")
assert(registry.sounds.Alert == "Interface/AddOns/MSBT/Alert.ogg",
	"saved sound was not loaded")
assert(not registry:RegisterFont(nil, nil), "invalid font was accepted")
assert(not registry:RegisterSound("Invalid", nil), "invalid sound was accepted")

-- Given a new shared-media registration
-- When the callback runs
callback(nil, "font", "Late Font")

-- Then it becomes available
assert(registry.fonts["Late Font"] == "Shared/font/Late Font",
	"late shared font was not imported")
