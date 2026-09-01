MikSBT = {
	Configuration = {},
}

local globals = {}
local migrations = 0
local ProfileStore = dofile("Configuration/ProfileStore.lua")
local store = ProfileStore:New({
	globals = globals,
	version = "12.024.0",
	defaultProfileName = "Default",
	migrateProfiles = function(profiles)
		migrations = migrations + 1
		profiles.Existing.migrated = true
	end,
})

-- Given no saved variables
-- When storage initializes
local state = store:Initialize()

-- Then legacy globals and defaults are created
assert(globals.MSBTProfiles_SavedVars == state.savedVariables,
	"account saved-variable name changed")
assert(globals.MSBTProfiles_SavedVarsPerChar == state.savedVariablesPerChar,
	"character saved-variable name changed")
assert(globals.MSBT_SavedMedia == state.savedMedia,
	"media saved-variable name changed")
assert(state.savedVariables.profiles.Default.creationVersion == "12.024.0",
	"default profile version changed")
assert(state.savedVariablesPerChar.currentProfileName == "Default",
	"default profile selection changed")
assert(state.savedMedia.fonts and state.savedMedia.sounds,
	"media collections were not initialized")
assert(state.isFirstLoad, "new storage was not marked as first load")

-- Given existing storage with a missing selected profile and partial media
globals.MSBTProfiles_SavedVars = {
	profiles = {
		Default = {},
		Existing = {},
	},
}
globals.MSBTProfiles_SavedVarsPerChar = {
	currentProfileName = "Missing",
}
globals.MSBT_SavedMedia = {
	fonts = {},
}

-- When storage initializes again
state = store:Initialize()

-- Then existing profiles migrate and selection safely falls back
assert(migrations == 1, "existing profiles were not migrated once")
assert(state.savedVariables.profiles.Existing.migrated,
	"migration changes were not retained")
assert(state.currentProfileName == "Default",
	"missing profile did not fall back to Default")
assert(state.savedVariablesPerChar.currentProfileName == "Default",
	"fallback profile was not persisted")
assert(state.savedMedia.sounds, "partial media storage was not normalized")
assert(not state.isFirstLoad, "existing storage was marked as first load")
