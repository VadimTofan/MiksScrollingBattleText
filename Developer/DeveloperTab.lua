local debug = MSBTOptions.Debug
if not debug or type(debug.Toggle) ~= "function" then return end

local tab = CreateFrame("Frame")
local client = MikSBT.Compatibility.Client

local function BuildStatus(record, version, build)
	if record.product ~= (client.isForever and "wowf" or nil) then
		return "different client"
	end
	local sourceVersion, sourceBuild = record.build:match("^(.+)%.(%d+)$")
	if sourceVersion ~= version then return "different version" end
	sourceBuild = tonumber(sourceBuild)
	if sourceBuild == build then return "matches client" end
	return build > sourceBuild and "client is newer" or "client is older"
end

local function AddLine(text, font, x, y)
	local line = tab:CreateFontString(nil, "OVERLAY", font)
	line:SetPoint("TOPLEFT", tab, "TOPLEFT", x, y)
	line:SetText(text)
	return line
end

local function Show()
	if tab.created then return end
	tab.created = true

	local version, build = GetBuildInfo()
	AddLine("Developer", "GameFontNormalLarge", 10, -18)
	AddLine("Client build: " .. version .. "." .. build, "GameFontNormal", 10, -48)

	local button = MSBTOptions.Controls.CreateOptionButton(tab)
	button:Configure(20, "Debug window", "Open or close the debug window.")
	button:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, -75)
	button:SetClickHandler(debug.Toggle)

	AddLine("Generated tables", "GameFontNormal", 10, -112)
	local records = MikSBT.TABLE_BUILDS or {}
	local names = {}
	for name in pairs(records) do
		names[#names + 1] = name
	end
	table.sort(names)

	local y = -136
	if #names == 0 then
		AddLine("No build metadata loaded.", "GameFontHighlightSmall", 10, y)
	end
	for _, name in ipairs(names) do
		local record = records[name]
		local status = BuildStatus(record, version, tonumber(build))
		local text = name .. ": " .. record.build .. ", " .. status
		local line = AddLine(text, "GameFontHighlightSmall", 10, y)
		y = y - 18
		if status ~= "matches client" then
			line:SetTextColor(1, 0.5, 0.25)
			AddLine("Regenerate with " .. record.script,
				"GameFontHighlightSmall", 24, y)
			y = y - 18
		end
	end
end

tab:Hide()
tab:SetScript("OnShow", Show)
MSBTOptions.Main.AddTab(tab, "Developer", "Build details and debug tools.", 8999.75)
