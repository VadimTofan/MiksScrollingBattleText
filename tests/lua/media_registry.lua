MikSBT = {
	Configuration = {},
}

local registrations = {}
local callback
local sharedMedia = {
	Register = function(_, mediaType, name, path)
		registrations[mediaType .. ":" .. name] = path
		return true
	end,
	List = function(_, mediaType)
		if mediaType == "sound" then return {} end
		return { "Shared Font" }
	end,
	Fetch = function(_, mediaType, name)
		return "Shared/" .. mediaType .. "/" .. name
	end,
}
sharedMedia.RegisterCallback = function(receiver, eventName, handler)
	if receiver == sharedMedia then
		error("callbacks must use their own receiver")
	end
	assert(eventName == "LibSharedMedia_Registered",
		"shared-media event name changed")
	callback = handler
end

local MediaRegistry = dofile("Configuration/MediaRegistry.lua")
local registry = MediaRegistry:New({
	sharedMedia = sharedMedia,
	defaultFonts = { ["Default Font"] = "Fonts/Default.ttf" },
})

-- Given built-in and shared media
-- When the registry initializes
registry:Initialize()

-- Then both sources are available
assert(registry.fonts["Default Font"] == "Fonts/Default.ttf",
	"default font was not registered")
assert(registry.fonts["Shared Font"] == "Shared/font/Shared Font",
	"shared font was not imported")
assert(callback, "shared-media callback was not registered")

-- Given saved custom media
-- When saved media loads
registry:LoadSavedMedia({
	fonts = { Custom = "Fonts/Custom.ttf" },
})

-- Then custom media is registered and invalid values are ignored
assert(registry.fonts.Custom == "Fonts/Custom.ttf",
	"saved font was not loaded")
assert(not registry:RegisterFont(nil, nil), "invalid font was accepted")

-- Given a new shared-media registration
-- When the callback runs
callback(nil, "font", "Late Font")

-- Then it becomes available
assert(registry.fonts["Late Font"] == "Shared/font/Late Font",
	"late shared font was not imported")

-- Given newly imported media and a pre-existing shared font.
dofile("API/RestrictedValue.lua")
dofile("API/Sounds.lua")
local imported = { fonts = {
	["Preview Font"] = "Fonts/Preview.ttf",
	["Shared Font"] = "Fonts/Other.ttf",
}, sounds = { ["Preview Sound"] = 1234 } }
local saved = { fonts = {
	["Preview Font"] = "Fonts/Preview.ttf",
	["Shared Font"] = "Fonts/Other.ttf",
}, sounds = { ["Preview Sound"] = 1234 } }

-- When the import is staged, then MSBT can preview without publishing.
registry:StageImportedMedia(imported)
assert(registry.fonts["Preview Font"] == imported.fonts["Preview Font"])
assert(registrations["font:Preview Font"] == nil)
assert(registry.sounds["Preview Sound"] == 1234)
assert(registrations["sound:Preview Sound"] == nil)
assert(registry.fonts["Shared Font"] == "Shared/font/Shared Font")

-- When the import is discarded, then the new entries disappear.
registry:FinishImportedMedia(false, saved)
assert(registry.fonts["Preview Font"] == nil and next(saved.fonts) == nil)
assert(registry.sounds["Preview Sound"] == nil and next(saved.sounds) == nil)
assert(registry.fonts["Shared Font"] == "Shared/font/Shared Font")

-- When a later import is kept, then the registration becomes shared.
saved.fonts["Preview Font"] = imported.fonts["Preview Font"]
saved.sounds["Preview Sound"] = 1234
registry:StageImportedMedia(saved)
registry:FinishImportedMedia(true, saved)
assert(registrations["font:Preview Font"] == imported.fonts["Preview Font"])
assert(registrations["sound:Preview Sound"] == 1234)

-- Given an imported font and sound staged before another addon registers them.
local late = { fonts = { ["Late Shared"] = "Shared/font/Late Shared" },
	sounds = { ["Late Sound"] = 5678 } }
registry:StageImportedMedia(late)
sharedMedia:Register("font", "Late Shared", late.fonts["Late Shared"])
sharedMedia:Register("sound", "Late Sound", late.sounds["Late Sound"])
local previousFetch = sharedMedia.Fetch
sharedMedia.Fetch = function(self, kind, name)
	return registrations[kind .. ":" .. name] or previousFetch(self, kind, name)
end
callback(nil, "font", "Late Shared")
callback(nil, "sound", "Late Sound")

-- When the import is cancelled.
registry:FinishImportedMedia(false, late)

-- Then the imported entries are removed and MSBT still sees the shared media.
assert(next(late.fonts) == nil and next(late.sounds) == nil)
assert(registry.fonts["Late Shared"] == "Shared/font/Late Shared")
assert(registry.sounds["Late Sound"] == 5678)
