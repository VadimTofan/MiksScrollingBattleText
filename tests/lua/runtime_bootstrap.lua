-- Describe: actual namespace and configuration load without the removed registry.
C_AddOns = { GetAddOnMetadata = function() return "12.029" end }
GetBuildInfo = function() return "12.0", "1", "date", 120100 end
WOW_PROJECT_ID = 1
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_CATACLYSM_CLASSIC = 5

local function LoadFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	return assert(loadstring(source, "@" .. path))()
end

-- Given namespace initialization with no pre-created test namespaces.
LoadFile("MikSBT.lua")
LoadFile("Compatibility/Client.lua")

-- When configuration and the supported API facade load in manifest order.
for _, path in ipairs({
	"Configuration/ProfileStore.lua", "Configuration/MediaRegistry.lua",
	"Configuration/RuntimeController.lua", "Configuration/ProfileTransfer.lua",
	"API/RestrictedValue.lua", "API/Sounds.lua", "API/Spells.lua",
	"API/Units.lua", "API/Cooldowns.lua", "Compatibility/LegacyAPI.lua",
	"Services/Formatter.lua", "Services/EventRouter.lua",
	"Components/IncomingCombat.lua", "Display/ScrollAreas.lua",
}) do LoadFile(path) end

-- Then all active namespaces exist and compatibility exports are callable.
assert(MikSBT.Configuration.ProfileStore)
assert(MikSBT.Configuration.ProfileTransfer)
assert(MikSBT.Services.Formatter)
assert(MikSBT.Components.IncomingCombat)
assert(MikSBT.Display.ScrollAreas)
assert(type(MikSBT.GetSpellInfo) == "function")
assert(type(MikSBT.HasAura) == "function")
assert(MikSBT.RegisterComponent == nil)
print("Runtime bootstrap tests passed")
