local module = {}
MikSBT.Compatibility = MikSBT.Compatibility or {}
MikSBT.Compatibility.Client = module

local FOREVER_INTERFACE = 16001

local interfaceVersion = tonumber((select(4, GetBuildInfo())))

module.interfaceVersion = interfaceVersion
module.isForever = interfaceVersion == FOREVER_INTERFACE
module.isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
module.isCataClassic = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
module.isVanillaContent = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
		or module.isForever
module.isClassicContent = WOW_PROJECT_ID >= WOW_PROJECT_CLASSIC
		or module.isForever
module.hasModernAPI = module.isMainline or module.isForever

-- Tables generated from the client's own data name it in MikSBT.TABLE_BUILDS, each as
-- { product =, build =, script = }: the client's name in that data, its version and build number
-- in one text, and the script that makes the table. Only Forever's name there is known.
module.product = module.isForever and "wowf" or nil


-- The running client's version and build number in the form the tables write.
local function GetBuild()
	local version, build = GetBuildInfo()
	return version .. "." .. build
end


-- How the running client stands to the data a table was made from: "fits", "clientNewer",
-- "clientOlder", "otherVersion" or "otherClient".
local function CompareTableBuild(record)
	if record.product ~= module.product then return "otherClient" end
	local version, build = GetBuildInfo()
	local tableVersion, tableBuild = record.build:match("^(.+)%.(%d+)$")
	if tableVersion ~= version then return "otherVersion" end
	build, tableBuild = tonumber(build), tonumber(tableBuild)
	if build == tableBuild then return "fits" end
	return build > tableBuild and "clientNewer" or "clientOlder"
end

module.GetBuild = GetBuild
module.CompareTableBuild = CompareTableBuild
