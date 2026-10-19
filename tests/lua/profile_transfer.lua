MikSBT = { Configuration = {} }
local stubFile = assert(io.open("Libs/LibStub.lua", "rb"))
local stubSource = stubFile:read("*a"):gsub("^\239\187\191", "")
stubFile:close()
assert(loadstring(stubSource))()
dofile("Libs/LibSerialize.lua")
dofile("Libs/LibDeflate.lua")

local file = io.open("Configuration/ProfileTransfer.lua", "r")
assert(file, "profile transfer service is missing")
file:close()
local ProfileTransfer = dofile("Configuration/ProfileTransfer.lua")
local serializer = LibStub("LibSerialize")
local deflate = LibStub("MSBTLibDeflate")

local defaults = {
	normalFontName = "Default Font",
	normalFontSize = 18,
	shortenNumbers = false,
	abilitySubstitutions = { Spell = "Default name" },
	abilitySuppressions = {},
	qualityExclusions = { [0] = true },
	itemsAllowed = {},
	scrollAreas = {
		Incoming = { name = "Incoming", offsetX = -140, offsetY = -160 },
	},
	events = {
		INCOMING_DAMAGE = { message = "-%a", scrollArea = "Incoming" },
	},
	triggers = {
		LOW_HEALTH = { message = "Low health", mainEvents = "UNIT_HEALTH{}" },
	},
}
local transfer = ProfileTransfer:New({
	masterProfile = defaults,
	version = "12.029.0",
	client = 120100,
	locale = "enUS",
})

local function encode(payload)
	local serialized = serializer:Serialize(payload)
	return "!MSBT:1!" .. deflate:EncodeForPrint(
		deflate:CompressZlib(serialized))
end

-- Describe: exports freeze inherited defaults and retain false overrides.
do
	-- Given a differential profile with custom media and a removed trigger.
	local profile = {
		creationVersion = "12.029.0",
		normalFontName = "Custom Font",
		shortenNumbers = true,
		abilitySubstitutions = { Spell = false, Other = "Custom name" },
		qualityExclusions = { [0] = false, [2] = true },
		events = { INCOMING_DAMAGE = { soundFile = "Custom Sound" } },
		triggers = { LOW_HEALTH = false },
	}
	local media = {
		fonts = { ["Custom Font"] = "Interface\\Fonts\\custom.ttf" },
		sounds = { ["Custom Sound"] = "Interface\\Sounds\\custom.ogg" },
	}

	-- When the profile is exported and decoded from wrapped clipboard text.
	local exported, message = transfer:Export("My Profile", profile, media)
	assert(exported, message)
	local wrapped = "  " .. exported:sub(1, 30) .. "\n" .. exported:sub(31)
	local payload, errorCode = transfer:Decode(wrapped)

	-- Then settings are grouped, defaults resolved, and no source data changes.
	assert(payload, errorCode)
	assert(exported:match("^!MSBT:1!"), "missing versioned prefix")
	assert(not exported:match("%s"), "export is not a single copyable string")
	assert(payload.sections.General.normalFontSize == 18)
	assert(payload.sections.ScrollAreas.Incoming.offsetX == -140)
	assert(payload.sections.Events.INCOMING_DAMAGE.message == "-%a")
	assert(payload.sections.Triggers.LOW_HEALTH == false)
	assert(payload.sections.SpamControl.abilitySubstitutions.Spell == false)
	assert(payload.sections.LootAlerts.qualityExclusions[0] == false)
	assert(payload.media.fonts["Custom Font"] == media.fonts["Custom Font"])
	assert(payload.media.sounds["Custom Sound"] == media.sounds["Custom Sound"])
	assert(profile.normalFontSize == nil, "export modified the source profile")
	assert(defaults.abilitySubstitutions.Spell == "Default name", "export modified defaults")

	-- Given different destination defaults and an existing media registration.
	local destination = ProfileTransfer:New({
		masterProfile = defaults,
		version = "12.030.0",
		client = 16001,
		locale = "deDE",
	})
	defaults.normalFontSize = 22
	local existing = { normalFontSize = 30 }
	local profiles = { Existing = existing }
	local savedMedia = {
		fonts = { ["Custom Font"] = "Existing.ttf" }, sounds = {},
	}

	-- When the profile is imported under a new name.
	local name, details = destination:Import(
		exported, "  Imported  ", profiles, savedMedia)

	-- Then effective source settings survive and existing data is preserved.
	assert(name == "Imported", details)
	assert(profiles.Imported.normalFontSize == 18)
	assert(profiles.Imported.creationVersion == "12.030.0")
	assert(profiles.Imported.events.INCOMING_DAMAGE.soundFile == "Custom Sound")
	assert(profiles.Imported.triggers.LOW_HEALTH == false)
	assert(profiles.Existing == existing)
	assert(savedMedia.fonts["Custom Font"] == "Existing.ttf")
	assert(savedMedia.sounds["Custom Sound"] == media.sounds["Custom Sound"])
	assert(details.clientMismatch and details.localeMismatch)

	-- When importing over an existing name or with an empty name.
	local duplicate, duplicateError = destination:Import(
		exported, "Existing", profiles, savedMedia)
	local empty, emptyError = destination:Import(
		exported, " \n ", profiles, savedMedia)

	-- Then neither attempt overwrites the original profile.
	assert(not duplicate and duplicateError == "PROFILE_EXISTS")
	assert(not empty and emptyError == "INVALID_NAME")
	assert(profiles.Existing == existing)
end

-- Describe: corrupt strings and invalid settings never enter saved variables.
do
	-- Given a valid export and fresh target storage.
	local exported = assert(transfer:Export("Test", {}, {}))
	local payload = assert(transfer:Decode(exported))
	local profiles = { Default = {} }
	local savedMedia = { fonts = {}, sounds = {} }
	local original = profiles.Default
	local invalidStrings = {
		"", "return os.execute('bad')", "!MSBT:2!abc",
		exported:sub(1, -5), exported .. "abc", "!MSBT:1!%%invalid",
		"!MSBT:1!" .. string.rep("a", 70000),
	}

	-- When malformed strings are imported.
	for _, text in ipairs(invalidStrings) do
		local imported, errorCode = transfer:Import(
			text, "Rejected", profiles, savedMedia)

		-- Then the attempt reports an error and preserves storage.
		assert(not imported and errorCode, "invalid string was accepted")
		assert(profiles.Rejected == nil and profiles.Default == original)
	end

	-- Given structurally valid encoded data with invalid setting types.
	payload.sections.General.normalFontSize = "large"
	local imported, errorCode = transfer:Import(
		encode(payload), "Rejected", profiles, savedMedia)

	-- Then malformed settings are rejected before saving.
	assert(not imported and errorCode == "INVALID_DATA")
	assert(profiles.Rejected == nil)

	-- Given a cyclic profile section.
	payload.sections.General.normalFontSize = 18
	payload.sections.ScrollAreas.Incoming.self = payload.sections.ScrollAreas

	-- When cyclic data is imported.
	imported, errorCode = transfer:Import(
		encode(payload), "Rejected", profiles, savedMedia)

	-- Then cycles are rejected instead of reaching recursive profile logic.
	assert(not imported and errorCode == "INVALID_DATA")
	assert(profiles.Rejected == nil)

	-- Given invalid record types and unsupported format metadata.
	payload.sections.ScrollAreas.Incoming.self = nil
	payload.sections.Events.INCOMING_DAMAGE = "bad"
	assert(not transfer:Decode(encode(payload)), "invalid event was accepted")
	payload.sections.Events.INCOMING_DAMAGE = { message = true }
	assert(not transfer:Decode(encode(payload)), "invalid message was accepted")
	payload.sections.Events.INCOMING_DAMAGE = { message = "-%a" }
	-- Given false or incomplete records that would break profile activation.
	payload.sections.Events.INCOMING_DAMAGE = false
	assert(not transfer:Decode(encode(payload)), "false event was accepted")
	payload.sections.Events.INCOMING_DAMAGE = { message = false }
	assert(not transfer:Decode(encode(payload)), "false message was accepted")
	payload.sections.Events.INCOMING_DAMAGE = { message = "-%a" }
	payload.sections.ScrollAreas.Incoming = false
	assert(not transfer:Decode(encode(payload)), "false scroll area was accepted")
	payload.sections.ScrollAreas.Incoming = { name = "Incoming", colorR = 999 }
	assert(not transfer:Decode(encode(payload)), "invalid color was accepted")
	payload.sections.ScrollAreas.Incoming = { name = "Incoming" }
	payload.sections.Triggers.Custom = { mainEvents = "UNIT_HEALTH{}" }
	assert(not transfer:Decode(encode(payload)), "incomplete trigger was accepted")
	payload.sections.Triggers.Custom = nil
	-- Given two event entries sharing a table with different default mappings.
	payload.sections.Events.OTHER_DAMAGE = payload.sections.Events.INCOMING_DAMAGE
	assert(not transfer:Decode(encode(payload)), "shared event table was accepted")
	payload.sections.Events.OTHER_DAMAGE = nil
	payload.format = 2
	assert(not transfer:Decode(encode(payload)), "future format was accepted")
end

print("Profile transfer tests passed")

-- Describe: profiles exported before retiring unused spam settings still import.
do
	-- Given an older portable profile containing the retired settings.
	local payload = assert(transfer:Decode(assert(transfer:Export("Old", {}, {}))))
	payload.sections.SpamControl.damageThreshold = 25
	payload.sections.SpamControl.throttleList = { Legacy = 3 }
	local profiles = {}
	-- When it is imported by the current version.
	local name = assert(transfer:Import(encode(payload), "Old", profiles, {}))
	-- Then active settings survive while retired options do not become active.
	assert(name == "Old" and profiles.Old.normalFontSize == defaults.normalFontSize)
	assert(profiles.Old.damageThreshold == nil and profiles.Old.throttleList == nil)
end
