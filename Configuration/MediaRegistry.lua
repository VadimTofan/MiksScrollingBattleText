local MediaRegistry = {}
MediaRegistry.__index = MediaRegistry

local ALL_LANGUAGES = 255

function MediaRegistry:New(options)
	local registry = setmetatable({}, self)

	registry.sharedMedia = options.sharedMedia
	registry.defaultFonts = options.defaultFonts or {}
	registry.defaultSounds = options.defaultSounds or {}
	registry.fonts = {}
	registry.sounds = {}

	return registry
end

function MediaRegistry:RegisterFont(name, path)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if type(path) ~= "string" or path == "" then
		return false
	end

	self.fonts[name] = path
	self.sharedMedia:Register("font", name, path, ALL_LANGUAGES)

	return true
end


function MediaRegistry:RegisterSound(name, path)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if type(path) ~= "string" or path == "" then
		return false
	end

	local lowerPath = string.lower(path)
	local startsInInterface = string.find(lowerPath, "interface", 1, true) == 1
	local supportedFile = string.find(lowerPath, ".mp3", 1, true)
		or string.find(lowerPath, ".ogg", 1, true)
	if not startsInInterface or not supportedFile then
		return false
	end

	self.sounds[name] = path
	self.sharedMedia:Register("sound", name, path)

	return true
end

function MediaRegistry:ImportSharedMedia(mediaType, name)
	if mediaType == "font" then
		self.fonts[name] = self.sharedMedia:Fetch(mediaType, name)
	elseif mediaType == "sound" then
		self.sounds[name] = self.sharedMedia:Fetch(mediaType, name)
	end
end

function MediaRegistry:LoadSavedMedia(savedMedia)
	savedMedia = savedMedia or {}

	for name, path in pairs(savedMedia.fonts or {}) do
		self:RegisterFont(name, path)
	end
	for name, path in pairs(savedMedia.sounds or {}) do
		self:RegisterSound(name, path)
	end
end

function MediaRegistry:Initialize()
	for name, path in pairs(self.defaultFonts) do
		self:RegisterFont(name, path)
	end
	for name, path in pairs(self.defaultSounds) do
		self:RegisterSound(name, path)
	end

	for _, name in pairs(self.sharedMedia:List("font")) do
		self:ImportSharedMedia("font", name)
	end
	for _, name in pairs(self.sharedMedia:List("sound")) do
		self:ImportSharedMedia("sound", name)
	end

	local registry = self
	self.sharedMedia:RegisterCallback(
		"MSBTSharedMedia",
		"LibSharedMedia_Registered",
		function(event, mediaType, name)
			registry:ImportSharedMedia(mediaType, name)
		end
	)
end

function MediaRegistry:IterateFonts()
	return pairs(self.fonts)
end

function MediaRegistry:IterateSounds()
	return pairs(self.sounds)
end

MikSBT.Configuration.MediaRegistry = MediaRegistry

return MediaRegistry
