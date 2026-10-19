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
local optionsFile = assert(io.open("MSBTOptions/MSBTOptionsTabs.lua", "rb"))
local optionsSource = optionsFile:read("*a")
optionsFile:close()
local exports = {}
for _, classic in ipairs({ false, true }) do
	MikSBT.Compatibility.Client.isClassicContent = classic
	frame = nil
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
	local profiles = MikSBT.Profiles

	-- Given defaults on either client branch and an existing saved profile.
	local defaults = profiles.masterProfile
	for _, direction in ipairs({ "Incoming", "Outgoing" }) do
		local areaKey = direction .. "Pet"
		local area = defaults.scrollAreas[areaKey]
		-- Then pets have independent areas beside their player counterparts.
		assert(area and area.name == defaults.scrollAreas[direction].name .. " PET",
			"missing localized pet area: " .. areaKey)
		assert(area.offsetX == defaults.scrollAreas[direction].offsetX - 100)
		assert(area.offsetY == defaults.scrollAreas[direction].offsetY)
		assert(area.animationStyle == defaults.scrollAreas[direction].animationStyle)
		assert(area ~= defaults.scrollAreas[direction])
	end
	for eventType, settings in pairs(defaults.events) do
		if eventType:match("^PET_INCOMING_") then
			assert(settings.scrollArea == "IncomingPet", eventType)
		elseif eventType:match("^PET_OUTGOING_") then
			assert(settings.scrollArea == "OutgoingPet", eventType)
		end
	end
	-- When a profile with explicit pet event assignments is selected again.
	for _, eventType in ipairs({ "PET_INCOMING_DAMAGE", "PET_OUTGOING_DAMAGE" }) do
		profiles.SetOption("events." .. eventType, "scrollArea", "Static")
	end
	profiles.SelectProfile("Default")
	-- Then custom assignments survive; inherited player routes stay unchanged.
	assert(profiles.currentProfile.events.PET_INCOMING_DAMAGE.scrollArea == "Static")
	assert(profiles.currentProfile.events.PET_OUTGOING_DAMAGE.scrollArea == "Static")
	assert(profiles.currentProfile.events.INCOMING_DAMAGE.scrollArea == "Incoming")
	assert(profiles.currentProfile.events.OUTGOING_DAMAGE.scrollArea == "Outgoing")
	profiles.SetOption("events.PET_INCOMING_DAMAGE", "scrollArea", "IncomingPet")
	profiles.SetOption("events.PET_OUTGOING_DAMAGE", "scrollArea", "OutgoingPet")

	-- Given retired spam settings in an existing saved profile.
	local retiredSettings = {
		dotThrottleDuration = 3, hotThrottleDuration = 3,
		powerThrottleDuration = 3, throttleList = { Legacy = 3 },
		mergeExclusions = { Legacy = true }, damageThreshold = 10,
		healThreshold = 10, powerThreshold = 10, hideFullHoTOverheals = true,
	}
	for key, value in pairs(retiredSettings) do
		assert(profiles.masterProfile[key] == nil, "retired default remains: " .. key)
		profiles.currentProfile[key] = value
	end
	-- When that profile is exported using the current schema.
	local legacyTransfer = MikSBT.Configuration.ProfileTransfer:New({
		masterProfile = profiles.masterProfile,
		version = "12.035", client = 120100, locale = "enUS",
	})
	local legacyExport = assert(profiles.ExportProfile("Default"))
	local legacyPayload = assert(legacyTransfer:Decode(legacyExport))
	-- Then retired settings stay saved but are absent from the portable profile.
	for key, value in pairs(retiredSettings) do
		assert(profiles.currentProfile[key] == value)
		assert(legacyPayload.sections.SpamControl[key] == nil)
		assert(legacyPayload.sections.General[key] == nil)
	end

	-- Given the real default profile and its outgoing spell message.
	local formatter = LoadFile("Services/Formatter.lua")
	formatter:Configure({
		getProfile = function() return profiles.currentProfile end,
		formatLargeNumber = tostring,
	})
	-- When a known outgoing spell is formatted with the default settings.
	local message = formatter:FormatEvent({
		message = profiles.currentProfile.events.OUTGOING_SPELL_DAMAGE.message,
		amount = 42, effectName = "Fireball",
		hideSkills = profiles.currentProfile.hideSkills,
	})
	-- Then only the amount is shown, without a skill name or empty brackets.
	assert(message:match("^42%s*$"), "skill names were visible by default")

	-- Given custom aura rows with both checkbox states on either client.
	assert(type(profiles.currentProfile.auraTracking) == "table",
		"missing custom aura defaults")
	assert(type(profiles.currentProfile.auraSettings) == "table",
		"missing custom aura style defaults")
	profiles.SetOption(nil, "auraTracking", {
		["1459"] = false, ["17"] = true,
	})
	profiles.SetOption(nil, "auraSettings", {
		["17"] = { colorR = 0.4, fontSize = 28, message = "Aura %sl",
			scrollArea = "Notification", soundFile = 123456, alwaysSticky = false },
	})
	-- When the profile is exported and decoded for importing.
	local auraExport = assert(profiles.ExportProfile("Default"))
	local auraTransfer = MikSBT.Configuration.ProfileTransfer:New({
		masterProfile = profiles.masterProfile,
		version = "12.031", client = 120100, locale = "enUS",
	})
	local auraPayload = assert(auraTransfer:Decode(auraExport))
	-- Then unchecked rows survive, rather than becoming missing defaults.
	assert(auraPayload.sections.SpamControl.auraTracking["1459"] == false)
	assert(auraPayload.sections.SpamControl.auraTracking["17"] == true)
	assert(auraPayload.sections.SpamControl.auraSettings["17"].fontSize == 28)
	assert(auraPayload.sections.SpamControl.auraSettings["17"].alwaysSticky == false)
	-- Given a malformed custom style in an imported profile.
	auraPayload.sections.SpamControl.auraSettings["17"].fontSize = "large"
	-- When validation checks its display settings.
	-- Then the invalid style is rejected before it reaches the runtime.
	assert(not auraTransfer:Validate(auraPayload))
	auraPayload.sections.SpamControl.auraSettings["17"].fontSize = 28
	-- When an import contains an invalid aura key or checkbox state.
	auraPayload.sections.SpamControl.auraTracking[1] = true
	-- Then validation rejects data that cannot be displayed as a rule row.
	assert(not auraTransfer:Validate(auraPayload))
	auraPayload.sections.SpamControl.auraTracking[1] = nil

	-- Given every event offered by the actual options list on this client.
	for eventType in optionsSource:gmatch(
		'EventsTab_AddEvent%([^,]+,%s*"([A-Z_]+)"') do
		-- When the list resolves settings from the active profile.
		local eventSettings = profiles.currentProfile.events[eventType]

		-- Then its rendering/editing controls have a complete settings object.
		assert(type(eventSettings) == "table",
			"missing options event defaults: " .. eventType
				.. " (classic=" .. tostring(classic) .. ")")
		assert(type(eventSettings.message) == "string",
			"missing options event message: " .. eventType)
	end

	-- Given the loaded defaults for a buff ending on either client branch.
	local fade = profiles.currentProfile.events.NOTIFICATION_BUFF_FADE
	-- When the buff name is rendered into its notification message.
	local fadedMessage = fade.message:gsub("%%sl", "Arcane Intellect")
	-- Then the notification explicitly says that the buff faded.
	assert(fadedMessage == "-[Arcane Intellect] faded",
		"buff removal notification did not say faded")
	assert(type(profiles.ExportProfile) == "function",
		"profile facade has no ExportProfile action")

	-- When supported General and area settings are configured and exported.
	profiles.SetOption(nil, "partialColoringDisabled", true)
	profiles.SetOption(nil, "damageColoringDisabled", true)
	profiles.SetOption("scrollAreas.Incoming", "skillIconsDisabled", true)
	profiles.SetOption("scrollAreas.Incoming", "offsetX", -320)
	profiles.SetOption("scrollAreas.IncomingPet", "offsetX", -400)
	profiles.SetOption("scrollAreas.OutgoingPet", "skillIconsDisabled", true)
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
assert(profiles.currentProfile.scrollAreas.IncomingPet.offsetX == -400)
assert(profiles.currentProfile.scrollAreas.OutgoingPet.skillIconsDisabled)
assert(profiles.currentProfile.events.PET_INCOMING_DAMAGE.scrollArea == "IncomingPet")
assert(profiles.currentProfile.events.PET_OUTGOING_DAMAGE.scrollArea == "OutgoingPet")
assert(profiles.currentProfile.events.INCOMING_DAMAGE.soundFile == 5678901)
assert(profiles.currentProfile.partialColoringDisabled)
assert(profiles.currentProfile.auraTracking["1459"] == false)
assert(profiles.currentProfile.auraTracking["17"] == true)
assert(profiles.currentProfile.auraSettings["17"].message == "Aura %sl")
assert(profiles.currentProfile.damageColoringDisabled)
assert(profiles.currentProfile.scrollAreas.Incoming.skillIconsDisabled)
assert(MSBTProfiles_SavedVarsPerChar.currentProfileName == "Portable")
assert(updates == updateCount + 2)

-- Describe: the new damage preference survives profile transfer and migration.
-- Given a user disables Blizzard damage on the selected profile.
profiles.SetOption(nil, "blizzardDamageEnabled", false)
local combatExport = assert(profiles.ExportProfile("Portable"))

-- When that profile is imported under a new name.
local combatName = assert(profiles.ImportProfile(combatExport, "Combat toggles"))

-- Then the unchecked checkbox is preserved, independently of retired options.
assert(combatName == "Combat toggles")
assert(profiles.currentProfile.blizzardDamageEnabled == false,
	"profile transfer lost the Blizzard damage preference")

-- Given a saved profile with old solo/group restrictions.
profiles.savedVariables.profiles.LegacyCombatText = {
	enableBlizzardV2CombatText = true,
	enableBlizzardV2CombatTextInGroup = true,
	disableOutgoingInGroup = true,
	normalFontSize = 24,
}

-- When the real profile facade selects it.
profiles.SelectProfile("LegacyCombatText")

-- Then it migrates before defaults are attached and keeps appearance settings.
assert(profiles.currentProfile.blizzardDamageEnabled == false)
assert(rawget(profiles.currentProfile, "enableBlizzardV2CombatText") == nil)
assert(rawget(profiles.currentProfile, "disableOutgoingInGroup") == nil)
assert(profiles.currentProfile.normalFontSize == 24)

-- Given the migrated profile has Blizzard damage disabled.
-- When the existing Blizzard reset action runs.
profiles.ResetOfficialBlizzardCombatText()

-- Then its result agrees with the two General checkboxes.
assert(profiles.currentProfile.blizzardDamageEnabled == true)
assert(profiles.IsModDisabled() == true)

-- Describe: enabling MSBT clears Blizzard damage without resetting it on reload.
-- Given MSBT is off and Blizzard damage is on after the reset action.
local combatTextWrites = {}
SetCVar = function(key, value) combatTextWrites[key] = value end

-- When MSBT is enabled through its real profile action.
profiles.SetOptionUserDisabled(false)

-- Then MSBT is on and the Blizzard damage checkbox is unchecked.
assert(not profiles.IsModDisabled())
assert(profiles.currentProfile.blizzardDamageEnabled == false,
	"enabling MSBT did not clear the Blizzard damage preference")
for _, key in ipairs({
	"enableFloatingCombatText", "floatingCombatTextCombatHealing_v2",
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2",
	"floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2",
}) do
	assert(combatTextWrites[key] == 0, key .. " remained enabled")
end

-- Given the user explicitly enables Blizzard damage afterward.
profiles.SetOption(nil, "blizzardDamageEnabled", true)

-- When the normal variables-loaded event reapplies settings.
environment.CUSTOM_CLASS_COLORS = {}
frame.scripts.OnEvent(frame, "VARIABLES_LOADED")

-- Then loading settings preserves the explicit selection.
assert(profiles.currentProfile.blizzardDamageEnabled == true,
	"loading settings reset an explicit Blizzard damage selection")

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
