-- Describe: profile snapshots restore, compare and revert the tracked state.
local function LoadFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(source, "@" .. path))()
end

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
InCombatLockdown = function() return false end
GetLocale = function() return "enUS" end
local updates, addonEnabled = 0, nil
local printed = {}
local function Update() updates = updates + 1 end
local translations = setmetatable({ DEFAULT_FONT_NAME = "Default", COMMAND_USAGE = {} }, {
	__index = function(_, key) return key end,
})
local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end
MikSBT = {
	VERSION = "12.052", SVN_REVISION = "0", COMMAND = "/msbt",
	Configuration = {}, translations = translations,
	Compatibility = { Client = {
		isClassicContent = false, hasModernAPI = true, interfaceVersion = 120100,
	} },
	GetSkillName = function(id) return "Spell " .. tostring(id) end,
	Print = function(message) printed[#printed + 1] = message end,
	CopyTable = CopyTable,
	EraseTable = function(value) for key in next, value do value[key] = nil end end,
	SplitString = function(value, pattern, target)
		for part in value:gmatch("[^.]+") do target[#target + 1] = part end
	end,
	Animations = { LoadFont = Noop, UpdateScrollAreas = Update },
	Triggers = { UpdateTriggers = Noop, Enable = Noop, Disable = Noop },
	Main = {
		Enable = function() addonEnabled = true end,
		Disable = function() addonEnabled = false end,
	},
	Parser = { Enable = Noop, Disable = Noop },
	Cooldowns = { Enable = Noop, Disable = Noop },
	Media = { fonts = {}, sounds = {}, OnVariablesInitialized = Noop },
}
LoadFile("Configuration/ProfileStore.lua")
LoadFile("Configuration/RuntimeController.lua")
LoadFile("Configuration/ProfileSnapshots.lua")

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

local function LoadProfiles()
	frame = nil
	local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
	setfenv(chunk, environment)
	chunk()
	frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
	return MikSBT.Profiles
end

local function EnterWorld(isInitialLogin, isReloadingUi)
	frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)
end

local profiles = LoadProfiles()
local saved = profiles.savedVariables
local snapshots = profiles.GetProfileSnapshots()
EnterWorld(true, false)

-- Rule: restoring a snapshot brings back every tracked value.
do
	-- Given a second profile and a snapshot of the tracked state.
	profiles.CopyProfile("Default", "Old")
	saved.profiles.Old.normalFontSize = 30
	local defaultTable = saved.profiles.Default
	local snapshot = snapshots:Take()

	-- When options change, a profile is deleted, another added and selected,
	-- and MSBT is disabled.
	profiles.SetOption(nil, "shortenNumbers", true)
	profiles.SetOption("events.INCOMING_DAMAGE", "disabled", true)
	profiles.DeleteProfile("Old")
	profiles.CopyProfile("Default", "Added")
	profiles.SelectProfile("Added")
	profiles.SetOptionUserDisabled(true)
	assert(addonEnabled == false)
	local updateCount = updates
	snapshots:Restore(snapshot)

	-- Then every value is back and the running addon uses it.
	assert(saved.profiles.Old and saved.profiles.Old.normalFontSize == 30,
		"deleted profile was not restored")
	assert(saved.profiles.Added == nil, "added profile remained")
	assert(MSBTProfiles_SavedVarsPerChar.currentProfileName == "Default",
		"profile selection was not restored")
	assert(profiles.currentProfile == defaultTable,
		"the running profile table was replaced")
	assert(rawget(defaultTable, "shortenNumbers") == nil, "option was not restored")
	assert(#snapshots:Diff(snapshot) == 0, "restored state differs from the snapshot")
	assert(not profiles.IsModDisabled() and addonEnabled == true,
		"enabled state was not restored")
	assert(profiles.currentProfile.events.INCOMING_DAMAGE.message,
		"defaults were not attached to the restored profile")
	assert(updates > updateCount, "scroll areas were not refreshed")
	profiles.DeleteProfile("Old")
end

-- Rule: the diff lists exactly the changed leaves.
local base = snapshots:Take()
profiles.SetOption(nil, "shortenNumbers", true)
profiles.SetOption("events.INCOMING_DAMAGE", "disabled", true)
profiles.SetOptionUserDisabled(true)
do
	-- When the current state is compared with the snapshot.
	local entries = snapshots:Diff(base)

	-- Then only the three changed values are listed with their effective values.
	assert(#entries == 3, "unexpected number of changes: " .. #entries)
	local expected = {
		{ "profiles.Default.events.INCOMING_DAMAGE.disabled", nil, true },
		{ "profiles.Default.shortenNumbers", false, true },
		{ "userDisabled", nil, true },
	}
	for index, entry in ipairs(entries) do
		assert(entry.key == expected[index][1], "unexpected change " .. entry.key)
		assert(entry.old == expected[index][2] and entry.new == expected[index][3],
			"wrong values for " .. entry.key)
	end
	assert(entries[1].path[4] == "INCOMING_DAMAGE" and #entries[1].path == 5)

	-- When a saved override goes back to the inherited default.
	local withOverride = snapshots:Take()
	profiles.SetOption(nil, "shortenNumbers", false)
	local changes = snapshots:Diff(withOverride)

	-- Then the change shows the inherited default as the new value.
	assert(#changes == 1 and changes[1].key == "profiles.Default.shortenNumbers")
	assert(changes[1].old == true and changes[1].new == false,
		"the diff did not resolve the inherited default")
	profiles.SetOption(nil, "shortenNumbers", true)
end

-- Rule: a saved value equal to the default is no change.
do
	-- Given a profile that stores a default value raw, as the migration does.
	rawset(profiles.currentProfile, "blizzardDamageEnabled", true)
	local stored = snapshots:Take()

	-- When the option is switched off and on again, which removes the raw value.
	profiles.SetOption(nil, "blizzardDamageEnabled", false)
	profiles.SetOption(nil, "blizzardDamageEnabled", true)

	-- Then nothing differs.
	assert(snapshots:Count(stored) == 0 and #snapshots:Diff(stored) == 0,
		"a default value counted as a change")
end

-- Rule: a profile added or deleted since a snapshot is one entry and reverts whole.
do
	-- Given a deleted and an added profile.
	profiles.CopyProfile("Default", "Gone")
	local stored = snapshots:Take()
	profiles.DeleteProfile("Gone")
	profiles.CopyProfile("Default", "New")

	-- When the differences are listed, counted and limited.
	local entries = snapshots:Diff(stored)

	-- Then each profile is one entry with the profile as its value.
	assert(#entries == 2 and snapshots:Count(stored) == 2, "a profile was split into entries")
	assert(entries[1].key == "profiles.Gone" and type(entries[1].old) == "table"
		and entries[1].new == nil, "the deleted profile is not one entry")
	assert(entries[2].key == "profiles.New" and entries[2].old == nil, "the added profile is not one entry")
	assert(snapshots:Count(stored, 1) == 1, "the limit did not stop the count")

	-- When both are reverted.
	snapshots:Revert(stored, entries[1].path)
	snapshots:Revert(stored, entries[2].path)

	-- Then the deleted profile is back whole and the added one is gone.
	assert(saved.profiles.Gone and saved.profiles.Gone.creationVersion
		and saved.profiles.Gone ~= stored.profiles.Gone, "the deleted profile did not come back whole")
	assert(saved.profiles.New == nil and snapshots:Count(stored) == 0, "the added profile remained")
	profiles.DeleteProfile("Gone")
end

-- Rule: reverting one path leaves the other changes.
do
	-- When the event change is reverted.
	local entries = snapshots:Diff(base)
	snapshots:Revert(base, entries[1].path)

	-- Then only that change is gone and the emptied tables go with it.
	local remaining = snapshots:Diff(base)
	assert(#remaining == 2 and remaining[1].key == "profiles.Default.shortenNumbers"
		and remaining[2].key == "userDisabled", "other changes were reverted")
	assert(rawget(profiles.currentProfile, "events") == nil, "emptied table remained")
	assert(profiles.currentProfile.events.INCOMING_DAMAGE.disabled ~= true)
	assert(profiles.currentProfile.shortenNumbers == true)

	-- When the enabled state is reverted, the running addon follows.
	snapshots:Revert(base, remaining[2].path)
	assert(not profiles.IsModDisabled() and addonEnabled == true,
		"reverted enabled state was not applied")

	-- When every leaf of an added profile is reverted, the profile goes.
	profiles.CopyProfile("Default", "Extra")
	for _, entry in ipairs(snapshots:Diff(base)) do
		if entry.path[2] == "Extra" then snapshots:Revert(base, entry.path) end
	end
	assert(saved.profiles.Extra == nil, "added profile remained after its revert")
	assert(saved.profiles.Default.shortenNumbers == true)
	profiles.SetOption(nil, "shortenNumbers", false)
end

-- Rule: the login snapshot is replaced on an initial login and kept on a reload.
do
	saved.loginSnapshot = nil
	EnterWorld(false, true)
	local login = snapshots:GetLoginSnapshot()
	assert(login and saved.loginSnapshot == login, "missing login snapshot was not taken")
	profiles.SetOption(nil, "stackSimilarHits", true)

	EnterWorld(false, true)
	EnterWorld(false, false)
	assert(snapshots:GetLoginSnapshot() == login, "reload or zoning replaced the login snapshot")
	assert(#snapshots:Diff(login) == 1)

	EnterWorld(true, false)
	assert(snapshots:GetLoginSnapshot() ~= login, "initial login kept the old snapshot")
	assert(#snapshots:Diff(snapshots:GetLoginSnapshot()) == 0)

	login = snapshots:GetLoginSnapshot()
	EnterWorld()
	assert(snapshots:GetLoginSnapshot() ~= login, "missing event arguments did not count as login")

	-- Given a UI reload, the saved variables are loaded again.
	login = snapshots:GetLoginSnapshot()
	profiles.SetOption(nil, "stackSimilarHits", false)
	profiles = LoadProfiles()
	snapshots = profiles.GetProfileSnapshots()
	EnterWorld(false, true)
	assert(snapshots:GetLoginSnapshot() == login, "UI reload lost the login snapshot")
	assert(#snapshots:Diff(login) == 1, "changes since login were lost")
end

-- Rule: the login snapshot is never part of a snapshot or a diff.
do
	local login = snapshots:GetLoginSnapshot()
	assert(snapshots:Take().loginSnapshot == nil, "a snapshot holds the login snapshot")
	for _, entry in ipairs(snapshots:Diff(login)) do
		assert(entry.path[1] ~= "loginSnapshot", "a diff lists the login snapshot")
	end
	snapshots:Restore(login)
	assert(profiles.savedVariables.loginSnapshot == login, "restoring removed the login snapshot")
	assert(#snapshots:Diff(login) == 0)
end

print("Profile snapshot tests passed")
