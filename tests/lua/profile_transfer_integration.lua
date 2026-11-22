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
for _, forever in ipairs({ false, true }) do
	MikSBT.Compatibility.Client.isClassicContent = forever
	MikSBT.Compatibility.Client.isForever = forever
	frame = nil
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
	local profiles = MikSBT.Profiles

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
	do
		-- Then on Forever the area for your lines on other units lies beside Outgoing, switched off;
		-- a client that is neither Forever nor Mainline shows its lines without the combat
		-- presentation and has no such area.
		local outgoing = defaults.scrollAreas.Outgoing
		local other = defaults.scrollAreas.OutgoingOther
		if not forever then
			assert(other == nil, "a client without plates has the area for other units")
		else
			assert(other and other.disabled == true, "the area for other units is missing or on")
			assert(other.name == outgoing.name .. " (" .. translations.MSG_OTHERS .. ")",
				"the area for other units is named " .. tostring(other.name))
			assert(other.offsetX == outgoing.offsetX + 100 and other.offsetY == outgoing.offsetY
				and other.animationStyle == outgoing.animationStyle and other.behavior == outgoing.behavior
				and other.iconAlign == outgoing.iconAlign and other ~= outgoing,
				"the area for other units did not copy Outgoing")
		end

		-- And every outgoing event of yours that shows in Outgoing names it as its second area,
		-- on the clients that have the area, and no other event has the field.
		for eventType, settings in pairs(defaults.events) do
			local expected = forever and profiles.EventTakesOtherArea(eventType)
				and settings.scrollArea == "Outgoing" and "OutgoingOther" or nil
			assert(settings.scrollAreaOther == expected, eventType .. " has the second area "
				.. tostring(settings.scrollAreaOther) .. ", not " .. tostring(expected))
		end
		for _, eventType in ipairs({ "OUTGOING_DAMAGE", "OUTGOING_DAMAGE_CRIT", "OUTGOING_SPELL_DAMAGE",
			"OUTGOING_SPELL_DOT", "OUTGOING_SPELL_DAMAGE_SHIELD", "OUTGOING_HEAL", "OUTGOING_HEAL_CRIT",
			"OUTGOING_HOT", "OUTGOING_MISS", "OUTGOING_SPELL_MISS" }) do
			assert(defaults.events[eventType].scrollArea == "Outgoing", eventType)
			assert(defaults.events[eventType].scrollAreaOther == (forever and "OutgoingOther" or nil), eventType)
		end
		for _, eventType in ipairs({ "OUTGOING_SPELL_INTERRUPT", "OUTGOING_DISPEL", "PET_OUTGOING_DAMAGE",
			"INCOMING_DAMAGE", "SELF_HEAL", "NOTIFICATION_BUFF" }) do
			assert(defaults.events[eventType].scrollAreaOther == nil, eventType .. " has a second area")
		end
		-- And the predicate accepts your outgoing events and refuses every other kind.
		for eventType, expected in pairs({ OUTGOING_DAMAGE = true, OUTGOING_SPELL_DAMAGE_CRIT = true,
			OUTGOING_RANGED_MISS = true, OUTGOING_SPELL_INTERRUPT = false, OUTGOING_DISPEL = false,
			PET_OUTGOING_DAMAGE = false, INCOMING_DAMAGE = false, NOTIFICATION_BUFF = false,
			SELF_HEAL = false, ["12345"] = false, ["name:Thorns"] = false, [""] = false }) do
			assert(profiles.EventTakesOtherArea(eventType) == expected, eventType)
		end
		assert(profiles.EventTakesOtherArea(nil) == false and profiles.EventTakesOtherArea(5) == false)

		-- Given the running display, and a hit of yours on another unit.
		MikSBT.Display, MikSBT.Components = {}, {}
		LoadFile("API/RestrictedValue.lua")
		local areas = LoadFile("Display/ScrollAreas.lua")
		local service = LoadFile("Display/DisplayService.lua")
		areas:Configure({
			getProfile = function() return profiles.currentProfile end,
			getMasterProfile = function() return profiles.masterProfile end,
			defaultArea = "Notification",
		})
		areas:Update()
		local shownIn = {}
		service:Configure({
			scrollAreas = areas, getProfile = function() return profiles.currentProfile end,
			isModDisabled = function() return false end, fonts = {}, defaultArea = "Notification",
			display = function(_, area) shownIn[#shownIn + 1] = area end,
		})
		local function Display(...) service:DisplayEvent(...) end
		local batcher = LoadFile("Components/OutgoingBatcher.lua"):New({
			getProfile = function() return profiles.currentProfile end,
			formatEventMessage = function(_, amount) return tostring(amount) end,
			display = Display, after = function(_, callback) callback() end,
			getSpellTexture = function() return "icon" end,
			isAutoAttack = function() return false end, delay = 0, scrollAreas = areas,
		})
		local presentation = LoadFile("Components/CombatPresentation.lua"):New({
			getProfile = function() return profiles.currentProfile end,
			batcher = batcher, getSpellTexture = function() return "icon" end, display = Display,
			scrollAreas = areas,
		})
		local function HitOnAnotherUnit()
			presentation:Out({ event = "damage", amount = 10, plate = "nameplate2",
				result = { who = "you", spell = 101 } })
			return shownIn[#shownIn]
		end
		assert(HitOnAnotherUnit() == areas:Resolve("Outgoing"), "a switched-off or absent area took a line")

		if forever then
			-- When the area is switched on the way the options do it.
			profiles.SetOption("scrollAreas.OutgoingOther", "disabled", false)
			areas:Update()

			-- Then it resolves with the default settings and receives the line.
			local enabled = areas:Resolve("OutgoingOther")
			assert(enabled.disabled == false and enabled.name == other.name
				and enabled.offsetX == other.offsetX, "the switched-on area lost its default settings")
			assert(HitOnAnotherUnit() == enabled, "the switched-on area did not receive the line")

			-- When it is switched off again, then the event's own display returns.
			profiles.SetOption("scrollAreas.OutgoingOther", "disabled", true)
			areas:Update()
			assert(HitOnAnotherUnit() == areas:Resolve("Outgoing"), "switching the area off kept moving lines")

			-- When the options save a second area the way the Events tab does.
			local events = profiles.currentProfile.events
			local function Saved(eventType)
				local table = rawget(profiles.currentProfile, "events")
				table = table and rawget(table, eventType)
				return table and rawget(table, "scrollAreaOther")
			end
			-- Then the area the master profile already has leaves no entry behind,
			profiles.SetOption("events.OUTGOING_DAMAGE", "scrollAreaOther", "OutgoingOther")
			assert(Saved("OUTGOING_DAMAGE") == nil and events.OUTGOING_DAMAGE.scrollAreaOther == "OutgoingOther")
			-- and "Same as above" is stored as false, which survives selecting the profile again,
			profiles.SetOption("events.OUTGOING_DAMAGE", "scrollAreaOther", false)
			assert(Saved("OUTGOING_DAMAGE") == false)
			profiles.SelectProfile("Default")
			assert(profiles.currentProfile.events.OUTGOING_DAMAGE.scrollAreaOther == false,
				"the choice of no second area was lost")
			-- and choosing the master's area again removes the entry.
			profiles.SetOption("events.OUTGOING_DAMAGE", "scrollAreaOther", "OutgoingOther")
			assert(Saved("OUTGOING_DAMAGE") == nil and
				profiles.currentProfile.events.OUTGOING_DAMAGE.scrollAreaOther == "OutgoingOther")
			-- An event without a master value stores a chosen area and no entry for none.
			profiles.SetOption("events.OUTGOING_SPELL_INTERRUPT", "scrollAreaOther", false)
			assert(Saved("OUTGOING_SPELL_INTERRUPT") == nil)
			profiles.SetOption("events.OUTGOING_SPELL_INTERRUPT", "scrollAreaOther", "Static")
			assert(Saved("OUTGOING_SPELL_INTERRUPT") == "Static")
			profiles.SetOption("events.OUTGOING_SPELL_INTERRUPT", "scrollAreaOther", false)
			assert(Saved("OUTGOING_SPELL_INTERRUPT") == nil)
		end
		MikSBT.Display, MikSBT.Components = nil, nil
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

-- Describe: Mainline shows your lines through the same combat presentation as Forever.
do
	-- Given the defaults of a Mainline client.
	local client = MikSBT.Compatibility.Client
	local loaded, loadedFrame = MikSBT.Profiles, frame
	client.isClassicContent, client.isForever, client.isMainline = false, false, true
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	local mainline = MikSBT.Profiles.masterProfile
	MikSBT.Profiles, frame = loaded, loadedFrame
	client.isClassicContent, client.isForever, client.isMainline = true, true, nil

	-- And a client whose heal event shows in another area leaves that event without a second area.
	local patched, replaced = source:gsub('(	OUTGOING_HEAL = {[^}]-scrollArea%s*= )"Outgoing"', '%1"Static"')
	assert(replaced == 2, "the heal event was not found in both default tables")
	client.isClassicContent, client.isForever, client.isMainline = false, false, true
	chunk = assert(loadstring(patched, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	local moved = MikSBT.Profiles.masterProfile
	MikSBT.Profiles, frame = loaded, loadedFrame
	client.isClassicContent, client.isForever, client.isMainline = true, true, nil
	assert(moved.events.OUTGOING_HEAL.scrollAreaOther == nil
		and moved.events.OUTGOING_DAMAGE.scrollAreaOther == "OutgoingOther",
		"an event that does not show in Outgoing got a second area")

	-- Then they have the area for your lines on other units too.
	assert(mainline.scrollAreas.OutgoingOther and mainline.scrollAreas.OutgoingOther.disabled == true,
		"a Mainline client lacks the area for other units")
	assert(mainline.events.OUTGOING_SPELL_DAMAGE.scrollAreaOther == "OutgoingOther"
		and mainline.events.PET_OUTGOING_SPELL_DAMAGE.scrollAreaOther == nil,
		"a Mainline client lacks the second area of its events")
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
	"floatingCombatTextCombatHealing_v2",
	"floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2",
	"floatingCombatTextCombatLogPeriodicSpells_v2",
	"floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2",
}) do
	assert(combatTextWrites[key] == 0, key .. " remained enabled")
end
assert(combatTextWrites.enableFloatingCombatText == 1,
	"enabling MSBT disabled the aura notice feed")

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
