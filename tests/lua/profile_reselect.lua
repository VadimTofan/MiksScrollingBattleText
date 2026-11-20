-- Describe: a profile that was selected before can be selected again.
local function LoadFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(source, "@" .. path))()
end

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
InCombatLockdown = function() return false end
GetLocale = function() return "enUS" end
local translations = setmetatable({ DEFAULT_FONT_NAME = "Default" }, {
	__index = function(_, key) return key end,
})
MikSBT = {
	VERSION = "12.055", SVN_REVISION = "0", COMMAND = "/msbt",
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
	Animations = { LoadFont = Noop, UpdateScrollAreas = Noop },
	Triggers = { UpdateTriggers = Noop, Enable = Noop, Disable = Noop },
	Main = { Enable = Noop, Disable = Noop },
	Parser = { Enable = Noop, Disable = Noop },
	Cooldowns = { Enable = Noop, Disable = Noop },
	Media = { fonts = {}, sounds = {}, OnVariablesInitialized = Noop },
}
LoadFile("Configuration/ProfileStore.lua")
LoadFile("Configuration/RuntimeController.lua")

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
local chunk = assert(loadstring(source, "@MSBTProfiles.lua"))
setfenv(chunk, environment)
chunk()
frame.scripts.OnEvent(frame, "ADDON_LOADED", "MikScrollingBattleText")
local profiles = MikSBT.Profiles
local saved = profiles.savedVariables

local function IsRunning(name)
	return MSBTProfiles_SavedVarsPerChar.currentProfileName == name
		and profiles.currentProfile == saved.profiles[name]
		and profiles.currentProfile.events.INCOMING_DAMAGE.message ~= nil
end

-- Rule: a profile whose Blizzard text setting is back at its default can be selected again.
do
	-- Given a second profile in which Blizzard's text was switched off and on again, so that the
	-- profile holds no value of its own for it.
	profiles.CopyProfile("Default", "Second")
	profiles.SelectProfile("Second")
	profiles.SetOption(nil, "blizzardDamageEnabled", false)
	profiles.SetOption(nil, "blizzardDamageEnabled", true)
	assert(rawget(saved.profiles.Second, "blizzardDamageEnabled") == nil,
		"the profile kept a value equal to the default")

	-- When another profile is selected and then this one again.
	profiles.SelectProfile("Default")
	local selected, message = pcall(profiles.SelectProfile, "Second")

	-- Then it is the running profile, with its defaults and Blizzard's text on.
	assert(selected, "selecting the profile again failed: " .. tostring(message))
	assert(IsRunning("Second"), "the profile selected again is not the running one")
	assert(profiles.currentProfile.blizzardDamageEnabled == true, "Blizzard's text did not stay on")
end

print("Profile reselect tests passed")
