local module = {}
local moduleName = "Media"
MikSBT[moduleName] = module

local DEFAULT_SOUND_FILES = {
	["MSBT Low Health"] =
		"Interface\\Addons\\MikScrollingBattleText\\Sounds\\LowHealth.ogg",
	["MSBT Low Mana"] =
		"Interface\\Addons\\MikScrollingBattleText\\Sounds\\LowMana.ogg",
	["MSBT Cooldown"] =
		"Interface\\Addons\\MikScrollingBattleText\\Sounds\\Cooldown.ogg",
}

local registry = MikSBT.Configuration.MediaRegistry:New({
	sharedMedia = LibStub("LibSharedMedia-3.0"),
	defaultFonts = MikSBT.translations.FONT_FILES,
	defaultSounds = DEFAULT_SOUND_FILES,
})
registry:Initialize()

local function OnVariablesInitialized()
	registry:LoadSavedMedia(MikSBT.Profiles.savedMedia)
end

module.fonts = registry.fonts
module.sounds = registry.sounds

module.RegisterFont = function(name, path)
	return registry:RegisterFont(name, path)
end
module.RegisterSound = function(name, path)
	return registry:RegisterSound(name, path)
end
module.IterateFonts = function()
	return registry:IterateFonts()
end
module.IterateSounds = function()
	return registry:IterateSounds()
end
module.OnVariablesInitialized = OnVariablesInitialized
