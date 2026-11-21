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
local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end
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
-- The client has every text setting on.
local cvars = {}
for _, name in ipairs({
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2", "floatingCombatTextPetMeleeDamage_v2",
	"floatingCombatTextPetSpellDamage_v2", "floatingCombatTextCombatHealing_v2",
	"floatingCombatTextSpellMechanics_v2", "floatingCombatTextSpellMechanicsOther_v2",
	"floatingCombatTextRepChanges_v2", "floatingCombatTextHonorGains_v2",
}) do cvars[name] = "1" end
GetCVar = function(name) return cvars[name] end
GetCVarBool = function(name) return cvars[name] == "1" end
SetCVar = function(name, value) cvars[name] = tostring(value) end
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
	CopyTable = CopyTable,
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
local installedSwitches
-- Given the player has the damage number over targets turned off in the game's menu.
cvars.floatingCombatTextCombatDamage_v2 = "0"
for _, forever in ipairs({ false, true }) do
	MikSBT.Compatibility.Client.isClassicContent = forever
	MikSBT.Compatibility.Client.isForever = forever
	frame = nil
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
	local profiles = MikSBT.Profiles

	local switches = rawget(profiles.savedVariables.profiles.Default, "blizzardSwitches")
	if not installedSwitches then
		-- Given a new installation.
		-- When its default profile is made.
		-- Then it has the table of switches, with none set, so it is not migrated.
		assert(switches and switches.version == 2 and switches.numbers == nil,
			"a new installation's profile was migrated")
		assert(select(2, profiles.GetBlizzardSwitch("numbers")) == false,
			"a new installation's profile was migrated")
		-- Then the client's number stays as the player has it.
		assert(cvars.floatingCombatTextCombatDamage_v2 == "0", "a new installation wrote the numbers")
		cvars.floatingCombatTextCombatDamage_v2 = "1"
		installedSwitches = switches
	else
		-- Given the saved variables of that installation.
		-- When the addon loads again.
		-- Then the default profile keeps its table of switches.
		assert(switches == installedSwitches, "a later load started the default profile's switches anew")
	end

	-- Given the loaded loot diagnostic and its command entry point.
	local lootCommands = {}
	MikSBT.Loot = { ProfileCommand = function(command)
		lootCommands[#lootCommands + 1] = command or ""
	end }
	translations.COMMAND_USAGE = {}
	-- When the actual slash handler receives capture start and stop commands.
	SlashCmdList.MSBT("lootprofile")
	SlashCmdList.MSBT("lootprofile stop")
	-- Then it delegates both commands without opening options or changing profiles.
	assert(#lootCommands == 2 and lootCommands[1] == ""
		and lootCommands[2] == "stop", "loot profile command is not routed")

	-- Given defaults on either client branch and an existing saved profile.
	local defaults = profiles.masterProfile
	assert(defaults.inferredWindfuryIcons == nil,
		"retired inferred Windfury preference remains in defaults")
	profiles.savedVariables.profiles.InferredLegacy = {
		creationVersion = "12.035.0",
	}
	profiles.SelectProfile("InferredLegacy")
	assert(profiles.currentProfile.inferredWindfuryIcons == nil,
		"existing profile inherited a retired preference")
	profiles.SelectProfile("Default")

	if forever then
		-- Given only Blizzard is showing resource gains.
		profiles.SetOption("events.NOTIFICATION_RESOURCE_GAIN", "disabled", true)
		CombatTextTypeInfo = {
			ENERGIZE = { show = 1, cvar = "floatingCombatTextEnergyGains_v2" },
		}

		-- When the player enables MSBT Resource Gains from the Events settings.
		profiles.SetOption("events.NOTIFICATION_RESOURCE_GAIN", "disabled", false)

		-- Then the native renderer is suppressed immediately.
		assert(CombatTextTypeInfo.ENERGIZE.show == nil,
			"the resource switch left the native renderer active")
		profiles.SetOption("events.NOTIFICATION_RESOURCE_GAIN", "disabled", true)
		assert(CombatTextTypeInfo.ENERGIZE.show == 1)
		profiles.SetOption("events.NOTIFICATION_RESOURCE_GAIN", "disabled", false)
		CombatTextTypeInfo = nil
	end

	assert(defaults.lowHealthSoundDisabled == false,
		"low-health sounds are not enabled by default")
	assert(defaults.lowManaSoundDisabled == false,
		"low-mana sounds are not enabled by default")
	assert(defaults.events.NOTIFICATION_KILLING_BLOW == nil,
		"separate unclassified killing-blow default remains")
	-- Category identity includes critical self-heals and pet events.
	assert(defaults.events.SELF_HEAL_CRIT.textCategory == "Incoming")
	assert(defaults.events.SELF_HOT_CRIT.textCategory == "Incoming")
	assert(defaults.events.PET_OUTGOING_DAMAGE.textCategory == "Outgoing")
	assert(defaults.events.NOTIFICATION_BUFF.textCategory == "Notifications")
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
	profiles.currentProfile.events.NOTIFICATION_KILLING_BLOW = {
		message = "Old generic", disabled = false,
	}
	local legacyTransfer = MikSBT.Configuration.ProfileTransfer:New({
		masterProfile = profiles.masterProfile,
		version = "12.035", client = 120100, locale = "enUS",
	})
	local legacyExport = assert(profiles.ExportProfile("Default"))
	local legacyPayload = assert(legacyTransfer:Decode(legacyExport))
	-- Then retired generic settings cannot reintroduce a third kill toggle.
	assert(legacyPayload.sections.Events.NOTIFICATION_KILLING_BLOW == nil)
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
		["name:Arcane Intellect"] = false,
	})
	profiles.SetOption(nil, "auraSettings", {
		["17"] = { colorR = 0.4, fontSize = 28, message = "Aura %sl",
			scrollArea = "Notification", soundFile = 123456, alwaysSticky = false },
		["name:Arcane Intellect"] = { fontSize = 32 },
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
	assert(auraPayload.sections.SpamControl.auraTracking[
		"name:Arcane Intellect"] == false)
	assert(auraPayload.sections.SpamControl.auraSettings[
		"name:Arcane Intellect"].fontSize == 32)
	assert(auraTransfer:Validate(auraPayload), "name rules failed validation")
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
	-- Given an empty name rule in an imported profile.
	auraPayload.sections.SpamControl.auraTracking["name:"] = false
	-- When its key is validated, then the malformed entry is rejected.
	assert(not auraTransfer:Validate(auraPayload))
	auraPayload.sections.SpamControl.auraTracking["name:"] = nil

	-- Given the real options module on this client.
	local previousOptions = MSBTOptions
	MikSBT.translations = {}
	LoadFile("MSBTOptions/Localization/localization.lua")
	MSBTOptions.Main = { AddTab = Noop }
	MSBTOptions.Popups = {}
	LoadFile("MSBTOptions/MSBTOptionsTabs.lua")
	MikSBT.translations = translations

	-- When each Events category resolves its rows.
	local eventOptions = MSBTOptions.Tabs.events
	MSBTOptions = previousOptions
	local outgoing = {}
	local abilityReady
	for _, category in ipairs({
		"INCOMING_PLAYER_EVENTS", "INCOMING_PET_EVENTS", "OUTGOING_PLAYER_EVENTS",
		"OUTGOING_PET_EVENTS", "NOTIFICATION_EVENTS",
	}) do
		for _, row in ipairs(eventOptions.GetEvents(category)) do
			-- Then each row has a complete settings object.
			local settings = eventOptions.GetSettings(row.eventType)
			assert(type(settings) == "table",
				"missing options event defaults: " .. row.eventType)
			assert(type(settings.message) == "string",
				"missing options event message: " .. row.eventType)
			if category == "OUTGOING_PLAYER_EVENTS" then
				outgoing[row.eventType] = row
			end
			if category == "NOTIFICATION_EVENTS"
				and row.eventType == "NOTIFICATION_ABILITY_READY" then
				abilityReady = settings
			end
		end
	end
	assert(abilityReady and abilityReady.disabled
		and abilityReady.soundFile == "MSBT Cooldown",
		"Ability Ready should be opt-in with the original cooldown sound")
	-- Then only Forever offers ranged swing settings, enabled by default.
	for _, suffix in ipairs({ "DAMAGE", "DAMAGE_CRIT", "MISS" }) do
		local eventType = "OUTGOING_RANGED_" .. suffix
		assert((outgoing[eventType] ~= nil) == forever,
			"wrong client for ranged swing option: " .. eventType)
		assert((defaults.events[eventType] ~= nil) == forever, eventType)
		assert(not outgoing["OUTGOING_AUTO_SHOT_" .. suffix])
		if forever then
			local settings = eventOptions.GetSettings(eventType)
			assert(not settings.disabled and settings.textCategory == "Outgoing", eventType)
			assert(settings.scrollArea == "Outgoing", eventType)
			assert(not not settings.isCrit == (suffix == "DAMAGE_CRIT"), eventType)
		end
	end

	if forever then
		-- Given saved Skill settings and an explicitly enabled Auto Shot preview.
		profiles.savedVariables.profiles.LegacyRanged = {
			creationVersion = "12.054.0",
			events = {
				OUTGOING_SPELL_DAMAGE = { soundFile = 5678901 },
				OUTGOING_SPELL_MISS = { disabled = true },
				OUTGOING_AUTO_SHOT_DAMAGE_CRIT = { disabled = false, soundFile = 5678902 },
			},
		}

		-- When the saved profile is selected and upgraded.
		profiles.SelectProfile("LegacyRanged")

		-- Then ranged outcomes retain their previously effective settings.
		local hit = "OUTGOING_RANGED_DAMAGE"
		assert(eventOptions.GetSettings(hit).soundFile == 5678901)
		assert(eventOptions.GetSettings("OUTGOING_RANGED_DAMAGE_CRIT").soundFile == 5678902)
		assert(eventOptions.GetSettings("OUTGOING_RANGED_MISS").disabled)
		eventOptions.SaveOption(hit, "disabled", true)
		eventOptions.SaveOption(hit, "soundFile", 5678903)
		profiles.SelectProfile("LegacyRanged")
		assert(eventOptions.GetSettings(hit).disabled)
		assert(eventOptions.GetSettings(hit).soundFile == 5678903)
		assert(eventOptions.GetSettings("OUTGOING_SPELL_DAMAGE").soundFile == 5678901)
		local exported = assert(profiles.ExportProfile("LegacyRanged"))
		local payload = assert(legacyTransfer:Decode(exported))
		assert(payload.sections.Events[hit].soundFile == 5678903)
		assert(payload.sections.Events.OUTGOING_AUTO_SHOT_DAMAGE_CRIT == nil)
		assert(payload.sections.General.rangedEventsMigrated == nil)
		profiles.SelectProfile("Default")
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
	profiles.SetOption(nil, "lowHealthSoundDisabled", true)
	profiles.SetOption(nil, "lowManaSoundDisabled", false)
	profiles.SetOption(nil, "lowHealthThreshold", 60)
	profiles.SetOption(nil, "lowManaThreshold", 20)
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
assert(profiles.currentProfile.lowHealthSoundDisabled == true)
assert(profiles.currentProfile.lowManaSoundDisabled == false)
assert(profiles.currentProfile.lowHealthThreshold == 60)
assert(profiles.currentProfile.lowManaThreshold == 20)
assert(profiles.currentProfile.inferredWindfuryIcons == nil,
	"profile transfer restored a retired preference")
assert(profiles.currentProfile.partialColoringDisabled)
assert(profiles.currentProfile.auraTracking["1459"] == false)
assert(profiles.currentProfile.auraTracking["17"] == true)
assert(profiles.currentProfile.auraTracking["name:Arcane Intellect"] == false)
assert(profiles.currentProfile.auraSettings["name:Arcane Intellect"].fontSize == 32)
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
-- Then the numbers over targets stay hidden as MSBT kept them, now as a set switch.
local isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isShown == false and isSet == true, "an old profile does not keep the numbers MSBT wrote")

-- Given the migrated profile has Blizzard damage disabled.
-- When the existing Blizzard reset action runs.
profiles.ResetOfficialBlizzardCombatText()

-- Then its result agrees with the two General checkboxes.
assert(profiles.currentProfile.blizzardDamageEnabled == true)
assert(profiles.IsModDisabled() == true)
-- Then the numbers go back to the client's setting.
isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isSet == false, "the reset left the numbers set")
assert(isShown == true, "the numbers remained off after the reset")

-- Describe: enabling MSBT clears Blizzard damage without resetting it on reload.
-- Given MSBT is off and Blizzard damage is on after the reset action.
local combatTextWrites = {}
SetCVar = function(key, value)
	combatTextWrites[key] = value
	cvars[key] = tostring(value)
end
-- Given the client's text feed was turned off since, as in the game's menu.
cvars.enableFloatingCombatText = "0"

-- When MSBT is enabled through its real profile action.
profiles.SetOptionUserDisabled(false)

-- Then MSBT is on and the Blizzard damage checkbox is unchecked.
assert(not profiles.IsModDisabled())
assert(profiles.currentProfile.blizzardDamageEnabled == false,
	"enabling MSBT did not clear the Blizzard damage preference")
for _, key in ipairs({
	"floatingCombatTextCombatHealing_v2",
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2",
	"floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2",
}) do
	assert(cvars[key] == "0", key .. " remained enabled")
end
assert(combatTextWrites.enableFloatingCombatText == 1,
	"enabling MSBT disabled the aura notice feed")
-- Then the numbers are set off in the profile.
isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isShown == false and isSet == true, "enabling MSBT did not set the numbers off")

-- Given the user explicitly enables Blizzard damage afterward.
profiles.SetOption(nil, "blizzardDamageEnabled", true)

-- When the normal variables-loaded event reapplies settings.
environment.CUSTOM_CLASS_COLORS = {}
frame.scripts.OnEvent(frame, "VARIABLES_LOADED")

-- Then loading settings preserves the explicit selection.
assert(profiles.currentProfile.blizzardDamageEnabled == true,
	"loading settings reset an explicit Blizzard damage selection")

-- Describe: the switch for the numbers over targets belongs to each profile.
-- Given the selected profile with the numbers hidden.
local selectedName = MSBTProfiles_SavedVarsPerChar.currentProfileName
-- When it is copied and the copy is selected.
profiles.CopyProfile(selectedName, "Copied")
profiles.SelectProfile("Copied")
-- Then the copy keeps the mark in a table of its own.
local copied = rawget(profiles.savedVariables.profiles.Copied, "blizzardSwitches")
assert(copied ~= rawget(profiles.savedVariables.profiles[selectedName], "blizzardSwitches"),
	"the copy shares the switches of its source")
assert(copied.numbers == 0, "the copy lost the switches")
isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isShown == false and isSet == true, "the copy lost the numbers switch")

-- Given the client shows the numbers again, changed elsewhere.
for key in pairs(cvars) do cvars[key] = "1" end
-- When a profile without set switches is selected.
profiles.SelectProfile("Portable")
-- Then the client's settings stay as they are and show.
assert(cvars.floatingCombatTextCombatDamage_v2 == "1", "a profile without set switches wrote them")
isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isShown == true and isSet == false, "a profile without set switches does not mirror the client")
-- When the copy is selected again.
profiles.SelectProfile("Copied")
-- Then its switch is forced again.
assert(cvars.floatingCombatTextCombatDamage_v2 == "0", "selecting a profile does not force its switches")

-- Given the copy is exported.
local transfer = MikSBT.Configuration.ProfileTransfer:New({
	masterProfile = profiles.masterProfile,
	version = "12.029.0", client = 120100, locale = "enUS",
})
local switchExport = assert(profiles.ExportProfile("Copied"))
assert(transfer:Decode(switchExport).sections.General.blizzardSwitches.numbers == 0,
	"the export lost the switches")
-- When it is imported.
assert(profiles.ImportProfile(switchExport, "Copied import"))
-- Then the switch comes back as it was, without a migration.
local imported = rawget(profiles.currentProfile, "blizzardSwitches")
assert(imported.version == 2 and imported.numbers == 0, "an import of a new export changed the switches")

-- Given exports of an older version, made from profiles without the switches.
for _, outgoingDisabled in ipairs({ true, false }) do
	local oldExport = assert(transfer:Export("Old", {
		blizzardDamageEnabled = true, blizzardOutgoingDisabled = outgoingDisabled,
	}))
	assert(transfer:Decode(oldExport).sections.General.blizzardSwitches == nil)
	-- When one is imported.
	local oldName = "Old " .. tostring(outgoingDisabled)
	assert(profiles.ImportProfile(oldExport, oldName))
	-- Then it is migrated: the numbers as MSBT wrote them, and no other switch set.
	isShown, isSet = profiles.GetBlizzardSwitch("numbers")
	assert(isSet == true and isShown == not outgoingDisabled, "an import of an old export was not migrated")
	for switch in pairs(rawget(profiles.currentProfile, "blizzardSwitches")) do
		assert(switch == "version" or switch == "numbers", "an import of an old export set a switch: " .. switch)
	end
	-- When the player shows the numbers and the profile is selected again.
	profiles.SetBlizzardSwitch("numbers", true)
	profiles.SelectProfile(oldName)
	-- Then the migration does not run twice.
	assert(profiles.GetBlizzardSwitch("numbers") == true, "a profile was migrated twice")
end

-- Given the selected profile with set switches.
profiles.SelectProfile("Copied import")
assert(select(2, profiles.GetBlizzardSwitch("numbers")) == true)
-- When it is reset to the defaults.
profiles.ResetProfile("Copied import")
-- Then it starts with no switch set, as a new profile.
for switch in pairs(rawget(profiles.currentProfile, "blizzardSwitches")) do
	assert(switch == "version", "a reset profile was migrated: " .. switch)
end
assert(select(2, profiles.GetBlizzardSwitch("numbers")) == false, "a reset profile was migrated: numbers")

-- Given MSBT was enabled, which hid every number over targets.
profiles.SetOptionUserDisabled(false)
for _, key in ipairs({
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2", "floatingCombatTextPetMeleeDamage_v2",
	"floatingCombatTextPetSpellDamage_v2", "floatingCombatTextCombatHealing_v2",
}) do
	assert(cvars[key] == "0", key .. " remained enabled")
end
-- When the Blizzard reset action runs.
profiles.ResetOfficialBlizzardCombatText()
-- Then every number setting is shown again, healing included, and left to the client.
for _, key in ipairs({
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2", "floatingCombatTextPetMeleeDamage_v2",
	"floatingCombatTextPetSpellDamage_v2", "floatingCombatTextCombatHealing_v2",
}) do
	assert(cvars[key] == "1", key .. " remained off after the reset")
end
assert(select(2, profiles.GetBlizzardSwitch("numbers")) == false, "the reset left the numbers set")
-- When MSBT's own checkbox action turns MSBT off.
profiles.SetOptionUserDisabled(true)
-- Then the numbers stay shown and not set, as only enabling MSBT hides them.
isShown, isSet = profiles.GetBlizzardSwitch("numbers")
assert(isShown == true and isSet == false, "disabling MSBT switched the numbers")
-- Given the player sets the numbers shown.
profiles.SetBlizzardSwitch("numbers", true)
-- When the Blizzard reset action runs again.
profiles.ResetOfficialBlizzardCombatText()
-- Then the mark is taken away all the same.
assert(select(2, profiles.GetBlizzardSwitch("numbers")) == false, "the reset left the shown numbers set")

-- Given an edited export whose switches hold other values than 1 or 0.
local craftedExport = assert(transfer:Export("Crafted", {
	blizzardSwitches = { version = 2, numbers = 5, bogus = 2 },
}))
for key in pairs(cvars) do cvars[key] = "1" end
-- When it is imported.
assert(profiles.ImportProfile(craftedExport, "Crafted"))
-- Then MSBT writes no such value and the numbers count as not set.
for key, value in pairs(cvars) do
	assert(value == "1", "an edited import wrote " .. key .. "=" .. value)
end
assert(select(2, profiles.GetBlizzardSwitch("numbers")) == false, "an edited import set the numbers")

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
