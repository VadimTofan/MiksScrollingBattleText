MikSBT = {}
WOW_PROJECT_ID = 42
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_CATACLYSM_CLASSIC = 5

GetBuildInfo = function()
	return "1.60.1", "69913", "Sep 17 2026", 16001, "enUS", "Beta"
end

-- Given / When
dofile("Compatibility/Client.lua")
local client = MikSBT.Compatibility.Client

-- Then
assert(client.interfaceVersion == 16001, "Forever interface was not detected")
assert(client.isForever == true, "Forever client was not classified")
assert(client.isMainline == false, "Forever was classified as Mainline")
assert(client.hasModernAPI == true, "Forever did not receive modern APIs")
assert(client.isClassicContent == true, "Forever did not receive Classic content")
assert(client.isVanillaContent == true, "Forever did not receive Vanilla content")
assert(client.isCataClassic == false, "Forever was classified as Cataclysm")
