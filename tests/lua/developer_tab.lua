local registered, shown, click
local lines = {}
local toggled = 0
MSBTOptions = {
	Main = { AddTab = function(_, title) registered = title end },
	Controls = { CreateOptionButton = function()
		return {
			Configure = function() end,
			SetPoint = function() end,
			SetClickHandler = function(_, handler) click = handler end,
		}
	end },
}
MikSBT = { Compatibility = { Client = { isForever = true } } }

function CreateFrame()
	return {
		Hide = function() end,
		SetScript = function(_, event, callback)
			assert(event == "OnShow")
			shown = callback
		end,
		CreateFontString = function()
			return {
				SetPoint = function() end,
				SetText = function(_, text) lines[#lines + 1] = text end,
				SetTextColor = function() end,
			}
		end,
	}
end

function GetBuildInfo()
	return "1.60.1", "70959"
end

-- Given no debug window
dofile("Developer/DeveloperTab.lua")
assert(not registered, "The Developer tab requires the debug window")

-- Given the local debug window and build metadata
MSBTOptions.Debug = { Toggle = function() toggled = toggled + 1 end }
MikSBT.TABLE_BUILDS = {
	Current = { product = "wowf", build = "1.60.1.70959", script = "current.py" },
	Older = { product = "wowf", build = "1.60.1.9999", script = "older.py" },
}

-- When the local tab is loaded and opened
dofile("Developer/DeveloperTab.lua")
assert(registered == "Developer")
shown()
click()

-- Then the tab shows the client, reports table builds and opens the debug window
assert(lines[2] == "Client build: 1.60.1.70959")
assert(lines[4] == "Current: 1.60.1.70959, matches client")
assert(lines[5] == "Older: 1.60.1.9999, client is newer")
assert(lines[6] == "Regenerate with older.py")
assert(toggled == 1)
shown()
assert(#lines == 6, "Opening the same tab twice added duplicate text")
