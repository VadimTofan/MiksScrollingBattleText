-- Describe: profile transfers use the real profile facade and client defaults.
local function LoadFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(source, "@" .. path))()
end

LoadFile("Libs/LibStub.lua")
LoadFile("Libs/LibSerialize.lua")
LoadFile("Libs/LibDeflate.lua")

local function Noop() end
local frame
function CreateFrame()
	local created = setmetatable({ scripts = {} }, {
		__index = function() return Noop end,
	})
	function created:SetScript(event, handler) self.scripts[event] = handler end
	if not frame then frame = created end
	return created
end
RAID_CLASS_COLORS = {}
Enum = { ItemQuality = { Poor = 0 } }
SlashCmdList = {}
SetCVar = Noop
InterfaceOptions_AddCategory = Noop
IsInGroup = function() return false end
IsInRaid = function() return false end
local inCombat = false
InCombatLockdown = function() return inCombat end
GetLocale = function() return "enUS" end
local updates = 0
local function Update() updates = updates + 1 end
local translations = setmetatable({ DEFAULT_FONT_NAME = "Default" }, {
	__index = function(_, key) return key end,
})
MikSBT = {
	VERSION = "12.029", SVN_REVISION = "0", COMMAND = "/msbt",
	Configuration = {}, translations = translations,
	Compatibility = { Client = {
		isClassicContent = false, hasModernAPI = true, interfaceVersion = 120100,
	} },
	GetSkillName = function(id) return "Spell " .. tostring(id) end,
	Print = Noop,
	EraseTable = function(value) for key in pairs(value) do value[key] = nil end end,
	SplitString = function(value, pattern, target)
		for part in value:gmatch("[^.]+") do target[#target + 1] = part end
	end,
	Animations = { LoadFont = Noop, UpdateScrollAreas = Update },
	Triggers = { UpdateTriggers = Update, Enable = Noop, Disable = Noop },
	Main = { Enable = Noop, Disable = Noop },
	Parser = { Enable = Noop, Disable = Noop },
	Cooldowns = { Enable = Noop, Disable = Noop },
	Media = { fonts = {}, sounds = {}, OnVariablesInitialized = Noop },
}
LoadFile("Configuration/ProfileStore.lua")
LoadFile("Configuration/RuntimeController.lua")
LoadFile("Configuration/ProfileTransfer.lua")

-- Given the actual default profile on each supported content branch.
local environment = setmetatable({}, {
	__index = function(_, key)
		local value = _G[key]
		if value ~= nil then return value end
		if key:match("^[A-Z_]+$") then return key end
	end,
})
local sourceFile = assert(io.open("MSBTProfiles.lua", "rb"))
local source = sourceFile:read("*a"):gsub("^\239\187\191", "")
sourceFile:close()
local exports = {}
for _, classic in ipairs({ false, true }) do
	MikSBT.Compatibility.Client.isClassicContent = classic
	frame = nil
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
	local profiles = MikSBT.Profiles
	assert(type(profiles.ExportProfile) == "function",
		"profile facade has no ExportProfile action")

	-- When supported General and area settings are configured and exported.
	profiles.SetOption(nil, "partialColoringDisabled", true)
	profiles.SetOption(nil, "damageColoringDisabled", true)
	profiles.SetOption("scrollAreas.Incoming", "skillIconsDisabled", true)
	profiles.SetOption("scrollAreas.Incoming", "offsetX", -320)
	profiles.SetOption("events.INCOMING_DAMAGE", "soundFile", 5678901)
	local exported, errorCode = profiles.ExportProfile("Default")

	-- Then both complete client schemas can be exported.
	assert(exported, errorCode)
	exports[#exports + 1] = exported
end

-- Describe: profiles from older versions retain retired settings in storage.
do
	-- Given the retired options and event overrides found in a saved profile.
	local profiles = MikSBT.Profiles
	local profile = profiles.savedVariables.profiles.Default
	profile.enableBlizzardDamage = true
	profile.enableBlizzardHealing = true
	profile.enableBlizzardV2GroupDamage = false
	profile.enableBlizzardV2GroupHealing = false
	profile.showAllPowerGains = true
	profile.events.NOTIFICATION_POWER_GAIN = { message = "+%a %p" }
	profile.events.NOTIFICATION_CP_FULL = { message = "Full combo points" }
	profile.events.NOTIFICATION_COOLDOWN = { disabled = true }
	profile.events.NOTIFICATION_PET_COOLDOWN = { disabled = true }
	local retiredEvent = profile.events.NOTIFICATION_COOLDOWN
	local transfer = MikSBT.Configuration.ProfileTransfer:New({
		masterProfile = profiles.masterProfile,
		version = "12.029.0", client = 120100, locale = "enUS",
	})

	-- When the legacy profile is exported and decoded.
	local exported, errorCode = profiles.ExportProfile("Default")
	assert(exported, "legacy profile export failed: " .. tostring(errorCode))
	local payload = assert(transfer:Decode(exported))

	-- Then only supported settings transfer, without changing saved data.
	assert(payload.sections.General.enableBlizzardDamage == nil)
	assert(payload.sections.General.enableBlizzardHealing == nil)
	assert(payload.sections.General.enableBlizzardV2GroupDamage == nil)
	assert(payload.sections.General.enableBlizzardV2GroupHealing == nil)
	assert(payload.sections.General.showAllPowerGains == nil)
	assert(payload.sections.Events.NOTIFICATION_POWER_GAIN == nil)
	assert(payload.sections.Events.NOTIFICATION_CP_FULL == nil)
	assert(payload.sections.Events.NOTIFICATION_COOLDOWN == nil)
	assert(payload.sections.Events.NOTIFICATION_PET_COOLDOWN == nil)
	assert(payload.sections.ScrollAreas.Incoming.offsetX == -320)
	assert(payload.sections.Events.INCOMING_DAMAGE.soundFile == 5678901)
	assert(profile.enableBlizzardDamage == true)
	assert(profile.enableBlizzardV2GroupHealing == false)
	assert(profile.events.NOTIFICATION_COOLDOWN == retiredEvent)
	assert(retiredEvent.disabled == true)

	-- When a supported setting in that profile has an invalid value.
	profile.events.INCOMING_DAMAGE.fontSize = "large"
	local invalid, invalidError = profiles.ExportProfile("Default")

	-- Then validation still rejects malformed supported settings.
	assert(not invalid and invalidError == "INVALID_DATA")
	profile.events.INCOMING_DAMAGE.fontSize = nil
end

-- Given a valid export and the active default profile.
local profiles = MikSBT.Profiles
local original = profiles.currentProfile
local updateCount = updates

-- When the profile is imported with a new name.
local name, errorCode = profiles.ImportProfile(exports[1], "Portable")

-- Then it becomes active and refreshes display and trigger settings.
assert(name == "Portable", errorCode)
assert(profiles.currentProfile ~= original)
assert(profiles.currentProfile.scrollAreas.Incoming.offsetX == -320)
assert(profiles.currentProfile.events.INCOMING_DAMAGE.soundFile == 5678901)
assert(profiles.currentProfile.partialColoringDisabled)
assert(profiles.currentProfile.damageColoringDisabled)
assert(profiles.currentProfile.scrollAreas.Incoming.skillIconsDisabled)
assert(MSBTProfiles_SavedVarsPerChar.currentProfileName == "Portable")
assert(updates == updateCount + 2)

-- Given a character in combat.
inCombat = true
local active = profiles.currentProfile

-- When an import is attempted.
name, errorCode = profiles.ImportProfile(exports[2], "During Combat")

-- Then the import is deferred without changing profiles or runtime state.
assert(not name and errorCode == "IN_COMBAT")
assert(profiles.currentProfile == active)
assert(profiles.savedVariables.profiles["During Combat"] == nil)

print("Profile transfer integration tests passed")
