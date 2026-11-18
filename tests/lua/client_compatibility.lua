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

-- Rule: a generated table's source is compared with the running client.
do
	local function State(build, product)
		return client.CompareTableBuild({ product = product or "wowf", build = build })
	end
	assert(client.product == "wowf", "Forever's product name is missing")
	assert(client.GetBuild() == "1.60.1.69913", "version and build are not joined as the tables write them")
	assert(State("1.60.1.69913") == "fits", "the same build does not fit")
	assert(State("1.60.1.69000") == "clientNewer", "an older table is not told")
	-- A build with more digits is larger, though its text sorts first.
	assert(State("1.60.1.100000") == "clientOlder", "the builds are not compared as numbers")
	assert(State("1.61.0.69913") == "otherVersion", "another version is not told")
	assert(State("test") == "otherVersion", "a text that is no build is not told as another version")
	assert(State("1.60.1.69913", "wow") == "otherClient", "another client's table is not told")
	-- Given a client that is not Forever.
	GetBuildInfo = function() return "12.0.5", "65000", "Oct 1 2026", 120105 end
	dofile("Compatibility/Client.lua")
	client = MikSBT.Compatibility.Client
	assert(client.product == nil and State("12.0.5.65000") == "otherClient", "a Forever table fits another client")
end
