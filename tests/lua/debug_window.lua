-- Describe: the debug window runs tests on request and logs what they record into a field to copy from.
local function Noop() end
local frames = {}
-- Two values the client hides from addons. The second cannot be a table key, as no hidden value can
-- in the client.
local SECRET, HIDDEN = {}, 0 / 0
function canaccessvalue(value) return value ~= SECRET and value == value end
local now = 100
function GetTime() return now end
local isControlDown = false
function IsControlKeyDown() return isControlDown end
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
-- Runs the timers that are due within the given time; later ones stay.
local function RunTimers(within)
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		if timer[1] <= within then timer[2]() else timers[#timers + 1] = timer end
	end
end
-- How many refreshes of the log on screen are on their way.
local function Queued()
	local count = 0
	for _, timer in ipairs(timers) do
		if timer[1] == 0.5 then count = count + 1 end
	end
	return count
end

local function NewFrame(kind, parent)
	local frame = { kind = kind, parent = parent, scripts = {}, events = {}, shown = true, text = "" }
	setmetatable(frame, { __index = function(_, key)
		if key:match("^[A-Z]") then return Noop end
	end })
	function frame:SetScript(event, handler) self.scripts[event] = handler end
	function frame:HasScript() return true end
	function frame:Show()
		if self.shown then return end
		self.shown = true
		if self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function frame:Hide()
		if not self.shown then return end
		self.shown = false
		if self.scripts.OnHide then self.scripts.OnHide(self) end
	end
	function frame:SetShown(isShown)
		if isShown then self:Show() else self:Hide() end
	end
	function frame:IsShown() return self.shown end
	-- Like the client, a frame is on screen only while its parents show as well.
	function frame:IsVisible() return self.shown and (self.parent == nil or self.parent:IsVisible()) end
	function frame:Enable() self.disabled = false end
	function frame:Disable() self.disabled = true end
	function frame:IsEnabled() return not self.disabled end
	-- Like the client, which refuses an event it does not know.
	function frame:RegisterEvent(event)
		if event == "NO_SUCH_EVENT" then error("unknown event") end
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event, unit) self.events[event] = unit end
	function frame:UnregisterAllEvents() self.events = {} end
	function frame:CreateFontString() return NewFrame("FontString", self) end
	function frame:SetText(text)
		self.text = text or ""
		if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
	end
	-- What the user types replaces the text and is reported as the user's input.
	function frame:Type(text)
		self.text = text
		if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
	end
	function frame:GetText() return self.text end
	function frame:HasFocus() return self.focused == true end
	function frame:SetFocus() self.focused = true end
	function frame:ClearFocus()
		local hadFocus = self.focused
		self.focused = false
		if hadFocus and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
	end
	function frame:HighlightText() self.highlighted = true end
	function frame:GetVerticalScroll() return 0 end
	function frame:GetHeight() return 200 end
	-- Like the client, a frame keeps every anchor it is given until they are cleared, one for each point:
	-- an anchor to a point that has one replaces it. point is the last one given, points all of them by
	-- the name of the point, and pointCalls counts every call, cleared or not.
	function frame:SetPoint(name, ...)
		local point = { name, ... }
		self.points = self.points or {}
		if not self.points[name] then self.anchors = (self.anchors or 0) + 1 end
		self.point, self.points[name] = point, point
		self.pointCalls = (self.pointCalls or 0) + 1
	end
	function frame:ClearAllPoints() self.point, self.points, self.anchors = nil, nil, 0 end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:GetCenter() return self.centerX, self.centerY end
	-- Like the client, which draws a value it hides when one is handed over; here as a mark.
	function frame:SetFormattedText(format, ...)
		local count = select("#", ...)
		local values = { ... }
		for index = 1, count do
			local value = values[index]
			-- Like the client's formatter, which takes only strings and numbers for %s.
			if type(value) == "boolean" then error("bad argument to SetFormattedText: a boolean") end
			if value == SECRET then
				values[index] = "<drawn>"
			elseif value ~= value then
				values[index] = "<drawn too>"
			elseif not canaccessvalue(value) then
				values[index] = "<drawn hidden>"
			end
		end
		self.text = string.format(format, unpack(values, 1, count))
	end
	function frame:Configure(_, label, tooltip) self.label, self.tooltip = label, tooltip end
	function frame:SetClickHandler(handler) self.clickHandler = handler end
	function frame:SetChecked(isChecked) self.checked = isChecked and true or false end
	function frame:GetChecked() return self.checked == true end
	frames[#frames + 1] = frame
	return frame
end
function CreateFrame(kind, _, parent) return NewFrame(kind, parent) end
UIParent = NewFrame("Frame")
SlashCmdList = {}
-- The frames Escape closes; the debug window is none of them.
UISpecialFrames = {}
-- A table whose content the client keeps out of reach.
local SEALED = {}
function canaccesstable(value) return value ~= SEALED end
-- A client that hides one more value: the one given, for which the stub has no hiding of its own. Where
-- a test asks t:IsSecret before it compares or tests such a value, only the rows tell that it did.
local hiddenOne = {}
local canAccessPlain = canaccessvalue
function canaccessvalue(value) return value ~= hiddenOne and canAccessPlain(value) end
local function Hide(value) hiddenOne = value end
-- The names of the functions hooked so far, once for every hook.
local hooks = {}
local function Hooked(name)
	local count = 0
	for _, hooked in ipairs(hooks) do
		if hooked == name then count = count + 1 end
	end
	return count
end
local function Pack(...) return { n = select("#", ...), ... } end
-- Like the client: the hook runs after the function with the same arguments, and the call returns
-- all that the function returned. A name that holds no function is refused.
function hooksecurefunc(owner, name, hook)
	local hooked = owner[name]
	assert(type(hooked) == "function", "hooksecurefunc: " .. tostring(name) .. " is no function")
	hooks[#hooks + 1] = name
	owner[name] = function(...)
		local results = Pack(hooked(...))
		hook(...)
		return unpack(results, 1, results.n)
	end
end
-- Functions of the stub addon for tests to watch. Sum counts the calls it ran, so that a callback
-- can tell that the function ran before it.
local Addon = { calls = 0, value = 1, Other = Noop, Late = Noop }
function Addon.Sum(left, right)
	Addon.calls = Addon.calls + 1
	return left + right, "and more"
end

-- Delivers a game event to every frame that registered it, a unit event only for its unit.
local function Fire(event, ...)
	for _, frame in ipairs(frames) do
		local unit = frame.events[event]
		if unit and (unit == true or unit == (...)) and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end
local function Listening()
	for _, frame in ipairs(frames) do
		if next(frame.events) then return true end
	end
	return false
end

local saved = {}
local registered = {}
local skinned = {}
MikSBT = { API = {}, Profiles = { savedVariables = saved } }
dofile("API/RestrictedValue.lua")
MSBTOptions = {
	Main = { RegisterPopupFrame = function(frame) registered[#registered + 1] = frame end },
	Controls = {
		CreateOptionButton = function(parent) return NewFrame("Button", parent) end,
		CreateCheckbox = function(parent) return NewFrame("Checkbox", parent) end,
	},
	Popups = { CreateMenuArtwork = function(frame) frame.hasArtwork = true end },
	-- The designs of the options as the window finds them where the options come in designs: the designs
	-- by key, the saved choice with the classic design as no choice, and a Select for the window to watch.
	Designs = { designs = {} },
}
function MSBTOptions.Designs.Register(key, design) MSBTOptions.Designs.designs[key] = design end
function MSBTOptions.Designs.GetSelected()
	return MSBTOptions.Designs.designs[saved.optionsDesign] and saved.optionsDesign or "classic"
end
function MSBTOptions.Designs.Select(key)
	if not MSBTOptions.Designs.designs[key] then return false end
	saved.optionsDesign = key ~= "classic" and key or nil
	return true
end
MSBTOptions.Designs.Register("classic", {})
MSBTOptions.Designs.Register("other", {
	SkinPopup = function(frame)
		skinned[frame] = (skinned[frame] or 0) + 1
		-- Like a design whose look has no picture in the corner, which puts the content back there. Until now
		-- only the debug code anchored it.
		frame.contentCallsWhenSkinned = frame.content.pointCalls
		frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		-- Like a design's skin, which restyles only the controls there are when it gets the window.
		frame.hadTestsWhenSkinned = next(frame.testCheckboxes) ~= nil and frame.testCheckboxes.rows ~= nil
			and frame.pageButtons ~= nil and frame.pageButtons.custom ~= nil and frame.customEditbox ~= nil
		-- And the log's panel is placed on both sides by then.
		frame.hadLogWhenSkinned = frame.logPanel ~= nil and frame.logPanel.points ~= nil
			and frame.logPanel.points.TOPLEFT ~= nil and frame.logPanel.points.BOTTOMRIGHT ~= nil
		-- Like a design that places its popups itself, wherever they are asked to go.
		frame.SetPoint = function(this)
			this.point = { "CENTER" }
			this.skinPoints = (this.skinPoints or 0) + 1
		end
	end,
})
MSBTOptions.Designs.Register("failing", { SkinPopup = function() error("the skin failed") end })
-- Two designs whose windows are built while there are no pages, and with the listed ones.
MSBTOptions.Designs.Register("bare", {})
MSBTOptions.Designs.Register("listed", {})
-- A design whose window is built with a list of four pages, to see how the page buttons wrap.
MSBTOptions.Designs.Register("wide", {})
local framesBefore = #frames
local SelectBefore = MSBTOptions.Designs.Select
dofile("Diagnostics/DebugWindow.lua")
local Debug = MSBTOptions.Debug

local function Slash() SlashCmdList.MSBTDEBUG("") end
-- The debug window that is open, by the log field every debug window has.
local function Window()
	for _, frame in ipairs(frames) do
		if frame.logEditbox and frame.shown then return frame end
	end
end
-- Like the client: a checkbox or a button is clicked only where it is on screen, and a disabled
-- button does nothing.
local function Tick(window, key, isChecked)
	local checkbox = assert(window.testCheckboxes[key], "no checkbox for the test " .. key)
	assert(checkbox:IsVisible(), "the checkbox of the test " .. key .. " is not on the page shown")
	checkbox:SetChecked(isChecked)
	checkbox.clickHandler(checkbox, isChecked)
end
local function Click(button)
	assert(button:IsVisible(), "a button was clicked that is not on screen")
	if button:IsEnabled() then button.clickHandler(button) end
end
local function Split(text)
	local lines = {}
	for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
	return lines
end
-- The log as the window shows it while tests write, once its refresh has run.
local function Lines(window)
	RunTimers(0.5)
	return Split(window.logEditbox:GetText())
end
-- The whole log as Select all shows it at once; the field lets go of the keyboard again.
local function AllLines(window)
	Click(window.selectButton)
	local lines = Split(window.logEditbox:GetText())
	window.logEditbox:ClearFocus()
	return lines
end

-- Rule: loading builds nothing, hears nothing, starts no timer and watches nothing.
do
	assert(#frames == framesBefore, "a frame was built before the window was asked for")
	assert(not Listening() and #timers == 0, "the debug window is at work without being asked")
	assert(MSBTOptions.Designs.Select == SelectBefore, "the choice of a design is watched before the window is asked for")
	assert(#hooks == 0, "a function was hooked before the window was asked for")
end

-- Rule: without pages the window opens with its own page only, which shows the field for a pasted
-- test, and Escape does not close it.
do
	-- When the command runs in a design whose window is built while no pages are listed.
	saved.optionsDesign = "bare"
	Slash()

	-- Then the window offers no test and one page, its own, which it shows.
	local bare = assert(Window(), "without pages no window opened")
	assert(next(bare.testCheckboxes) == nil, "a test is offered although none is listed")
	local pages = 0
	for _ in pairs(bare.pageButtons) do pages = pages + 1 end
	assert(pages == 1 and bare.pageButtons.custom and bare.pageButtons.custom.label == "Custom",
		"without pages the window offers " .. pages .. " pages")
	assert(not bare.pageButtons.custom:IsEnabled() and bare.customEditbox:IsVisible() and bare.runButton:IsVisible(),
		"without pages the window does not show its own page")
	assert(#UISpecialFrames == 0, "the debug window closes on Escape")
	Slash()
	assert(Window() == nil, "/msbtdebug did not close the open window")
	saved.optionsDesign = nil
end
-- The choice of a design as it is watched from the first opening on.
local SelectWatched = MSBTOptions.Designs.Select

-- A class of the addon with an instance that reaches its method through a metatable, as the
-- addon's components are used: the method is called on the instance.
local Class = { calls = 0 }
function Class:Method(value) Class.calls = Class.calls + 1 end
local instance = setmetatable({}, { __index = Class })
-- The recorders of the last runs of the tests "odd", "watch" and "ender", kept beyond their stop.
local kept, keptWatch, keptEnder
Debug.pages = {
	{ key = "first", label = "First", tests = {
		{ key = "echo", label = "Echo", tooltip = "Repeats an event.", run = function(t)
			t:On("SOME_EVENT", function(first, second) t:Log("heard", first, second) end)
			t:On("UNIT_EVENT", function(unit) t:Log("unit", unit) end, "player")
			t:After(1, function() t:Log("timer ran") end)
		end },
		{ key = "faulty", label = "Faulty", run = function(t)
			t:On("SOME_EVENT", function() error("boom") end)
			t:On("OTHER_EVENT", function() t:Log("still here", t:IsSecret(SECRET), t:IsSecret(1)) end)
		end },
		{ key = "odd", label = "Odd", run = function(t)
			kept = t
			t:On("NO_SUCH_EVENT", Noop)
			t:Log("went on")
		end },
		{ key = "flood", label = "Flood", run = function(t)
			for index = 1, 1005 do t:Log("row", index) end
		end },
		{ key = "draw", label = "Draw", run = function(t)
			t:On("SOME_EVENT", function(first) t:Log("drawn", t:Show("gain", first, SECRET, HIDDEN, nil, "\nnext")) end)
		end },
		{ key = "failing", label = "Failing", run = function(t)
			t:On("SOME_EVENT", function() t:Log("heard after the failure") end)
			t:After(0, function() error("late") end)
			error("early")
		end },
		{ key = "shapes", label = "Shapes", run = function(t)
			t:Log({}, Noop, "a\r\nb", t:IsSecret(SEALED), t:IsSecret({}))
		end },
	} },
	{ key = "second", label = "Second", tests = {
		{ key = "watch", label = "Watch", tooltip = "Watches Addon.Sum.", run = function(t)
			keptWatch = t
			t:Watch(Addon, "Sum", function(left, right) t:Log("sum", left, right, "after call", Addon.calls) end)
		end },
		{ key = "watchToo", label = "Watch too", run = function(t)
			t:Watch(Addon, "Sum", function(left)
				if left == 0 then error("bad call") end
				t:Log("also", left)
			end)
		end },
		{ key = "missing", label = "Missing", run = function(t)
			t:Watch(Addon, "Missing", Noop)
			t:Watch(Addon, "value", Noop)
			t:Watch(nil, "Sum", Noop)
			t:Log("went on")
		end },
		{ key = "ender", label = "Ender", run = function(t)
			keptEnder = t
			t:OnStop(function() t:Log("first on stop") end)
			t:OnStop(function() error("stop failed") end)
			t:OnStop(function()
				t:Stop()
				t:Log("last on stop")
			end)
			t:On("SOME_EVENT", function() t:Stop() end)
			t:On("OTHER_EVENT", function() t:After(0, function() t:Stop() end) end)
			t:Watch(Addon, "Sum", function(left) if left == 99 then t:Stop() end end)
		end },
		{ key = "rows", label = "Rows", run = function(t)
			t:On("SOME_EVENT", function(index, ...) t:Log("row", t:Row(index, ...)) end)
			t:On("OTHER_EVENT", function(...) t:Log("shown", t:Show(...)) end)
		end },
		{ key = "twice", label = "Twice", run = function(t)
			t:Watch(Addon, "Sum", function() t:Log("first watch") end)
			t:Watch(Addon, "Sum", function() t:Log("second watch") end)
		end },
		{ key = "inherit", label = "Inherit", run = function(t)
			t:Watch(instance, "Method", function() t:Log("instance heard") end)
			t:Watch(Class, "Method", function(self, value) t:Log("class heard", self == instance, value) end)
		end },
		{ key = "stopper", label = "Stopper", run = function(t)
			t:On("SOME_EVENT", function() t:Log("event heard") end)
			t:Watch(Addon, "Sum", function() t:Log("watch heard") end)
			t:OnStop(function()
				t:Log("stop callback")
				t:On("THIRD_EVENT", function() t:Log("late event heard") end)
				t:Watch(Addon, "Late", function() t:Log("late watch heard") end)
				t:After(0, function() t:Log("late timer ran") end)
				Fire("SOME_EVENT")
				Fire("THIRD_EVENT")
				Addon.Sum(1, 1)
				Addon.Late()
			end)
		end },
	} },
}

-- Rule: /msbtdebug opens the window with a checkbox for every listed test, apart from the options' popups.
local window
do
	-- When the command runs.
	Slash()
	window = assert(Window(), "/msbtdebug opened no window")

	-- Then every test of every page is offered unticked with its label and tooltip, and the window
	-- is no popup of the options, which close with the options window.
	for _, key in ipairs({ "echo", "faulty", "odd", "flood", "watch", "ender", "rows" }) do
		assert(window.testCheckboxes[key] and not window.testCheckboxes[key]:GetChecked(), "the test " .. key .. " is not offered")
	end
	assert(window.testCheckboxes.echo.label == "Echo" and window.testCheckboxes.echo.tooltip == "Repeats an event.",
		"a test is offered without its label and tooltip")
	assert(#registered == 0, "the debug window closes with the options' popups")
	assert(window.hasArtwork, "the window is not built in the classic look")
	assert(not Listening(), "a test listens before it is started")
	assert(#window.point == 1 and window.point[1] == "CENTER", "the window was moved although it was never dragged")

	-- When the command runs again, then the window closes.
	Slash()
	assert(Window() == nil, "/msbtdebug did not close the open window")
	Slash()
	assert(Window() == window, "the window was built a second time")
	assert(MSBTOptions.Designs.Select == SelectWatched, "the choice of a design was hooked a second time")

	-- When the X in its corner is clicked, then it closes as well.
	local close
	for _, frame in ipairs(frames) do
		if frame.kind == "Button" and frame.parent == window and frame.scripts.OnClick then close = frame end
	end
	assert(close, "the window has no button of its own to close it")
	close.scripts.OnClick(close)
	assert(Window() == nil, "the X did not close the window")
	Slash()
end

-- Rule: the window shows one page at a time and marks its button, at first the first listed page.
-- Its own page comes after the listed ones and shows the field for a pasted test.
do
	-- Given the window has just opened.
	-- Then the tests of the first page show, those of another page and the field for a pasted test do not.
	assert(window.testCheckboxes.echo:IsVisible() and window.testCheckboxes.shapes:IsVisible(),
		"the tests of the first page do not show at first")
	assert(not window.testCheckboxes.watch:IsVisible(), "a test of another page shows")
	assert(not window.customEditbox:IsVisible() and not window.runButton:IsVisible() and not window.stopButton:IsVisible(),
		"the field for a pasted test shows on another page")
	assert(not window.pageButtons.first:IsEnabled() and window.pageButtons.second:IsEnabled()
		and window.pageButtons.custom:IsEnabled(), "the page shown is not marked")
	assert(window.pageButtons.second.label == "Second" and window.pageButtons.custom.label == "Custom",
		"a page is offered without its label")
	assert(window.pageButtons.custom.point[4] > window.pageButtons.second.point[4],
		"the window's own page does not come after the listed ones")

	-- When the second page is chosen.
	Click(window.pageButtons.second)

	-- Then its tests show and those of the first page do not, and its button is the marked one.
	assert(window.testCheckboxes.watch:IsVisible() and window.testCheckboxes.rows:IsVisible()
		and not window.testCheckboxes.echo:IsVisible(), "the tests of the chosen page do not show")
	assert(not window.pageButtons.second:IsEnabled() and window.pageButtons.first:IsEnabled(),
		"a page that is not shown cannot be chosen")

	-- When the window's own page is chosen, then it shows the field for a pasted test and no tests.
	Click(window.pageButtons.custom)
	assert(window.customEditbox:IsVisible() and window.runButton:IsVisible() and window.stopButton:IsVisible(),
		"the window's own page does not show the field for a pasted test")
	assert(not window.testCheckboxes.watch:IsVisible() and not window.testCheckboxes.echo:IsVisible(),
		"a test shows on the window's own page")

	-- When the window is closed and opened again, then it shows the same page.
	Slash()
	Slash()
	assert(window.customEditbox:IsVisible() and not window.testCheckboxes.echo:IsVisible(), "the window opened again on another page")
	Click(window.pageButtons.first)
end

-- Rule: a started test hears its events and writes a row for each, with the time since the log began.
do
	-- When the test is ticked and its events arrive, a unit event also for another unit.
	Tick(window, "echo", true)
	now = 101.5
	Fire("SOME_EVENT", 7, "x")
	Fire("UNIT_EVENT", "target")
	Fire("UNIT_EVENT", "player")

	-- Then one refresh of the screen is on its way for all of them, and the log shows the start
	-- and the events the test asked for.
	assert(Queued() == 1, Queued() .. " refreshes are on their way for three rows")
	local lines = Lines(window)
	assert(#lines == 3, "the log has " .. #lines .. " rows: " .. table.concat(lines, " | "))
	assert(lines[1] == "0.000 echo started Echo", "the start row is " .. lines[1])
	assert(lines[2] == "1.500 echo heard 7 x", "the event row is " .. lines[2])
	assert(lines[3] == "1.500 echo unit player", "the unit event row is " .. lines[3])
	assert(window.countFontString:GetText() == "3 rows", "the count reads " .. tostring(window.countFontString:GetText()))
end

-- Rule: values the client hides and protected texts are named in the log, never copied, and a text
-- of several lines stays one row.
do
	Fire("SOME_EVENT", SECRET, "a|Kq1|k")
	local lines = Lines(window)
	assert(lines[#lines] == "1.500 echo heard <secret> <protected-text>", "a hidden value was logged as " .. lines[#lines])
	Fire("SOME_EVENT", HIDDEN, "two\nlines")
	lines = Lines(window)
	assert(lines[#lines] == "1.500 echo heard <secret> two lines", "a text of two lines was logged as " .. lines[#lines])
	Fire("SOME_EVENT", nil, true)
	lines = Lines(window)
	assert(lines[#lines] == "1.500 echo heard nil true", "plain values were logged as " .. lines[#lines])
end

-- Rule: a stopped test hears nothing more, and its timers do nothing.
do
	-- When the test is unticked, its event arrives and its timer comes due.
	Tick(window, "echo", false)
	local count = #Lines(window)
	Fire("SOME_EVENT", 1, 2)
	RunTimers(1)

	-- Then only the stop was logged, and no frame listens any more.
	local lines = Lines(window)
	assert(lines[count] == "1.500 echo stopped" and #lines == count, "a stopped test wrote " .. tostring(lines[#lines]))
	assert(not Listening(), "a stopped test left an event registered")

	-- When it runs again and the timer of this run comes due, then that timer writes.
	Tick(window, "echo", true)
	RunTimers(1)
	lines = Lines(window)
	assert(lines[#lines] == "1.500 echo timer ran", "the timer of a running test wrote " .. tostring(lines[#lines]))
	Tick(window, "echo", false)
end

-- Rule: an error in a test is logged, and the test goes on.
do
	Tick(window, "faulty", true)
	Fire("SOME_EVENT")
	Fire("OTHER_EVENT")
	local lines = Lines(window)
	assert(lines[#lines - 1]:find("^1%.500 faulty error ") and lines[#lines - 1]:find("boom", 1, true),
		"the error row is " .. lines[#lines - 1])
	assert(lines[#lines] == "1.500 faulty still here true false", "after an error the test wrote " .. lines[#lines])
	Tick(window, "faulty", false)
end

-- Rule: an error while a test starts or in one of its timers is logged as well, and what the test
-- set up before keeps running.
do
	-- When a test fails while it starts, its timer fails in the next frame and its event arrives.
	Tick(window, "failing", true)
	RunTimers(0)
	Fire("SOME_EVENT")

	-- Then both failures are rows, and the event was heard.
	local lines = Lines(window)
	assert(lines[#lines - 2]:find("failing error ", 1, true) and lines[#lines - 2]:find("early", 1, true),
		"a failure while a test starts logged " .. lines[#lines - 2])
	assert(lines[#lines - 1]:find("failing error ", 1, true) and lines[#lines - 1]:find("late", 1, true),
		"a failure in a timer logged " .. lines[#lines - 1])
	assert(lines[#lines]:find("failing heard after the failure$"), "after its failure the test wrote " .. lines[#lines])
	Tick(window, "failing", false)
end

-- Rule: a table or a function is logged as what it is and a line break of either kind as a space;
-- a table whose content the client keeps out of reach counts as hidden.
do
	Tick(window, "shapes", true)
	local lines = Lines(window)
	assert(lines[#lines]:find("shapes table function a  b true false$"), "the row of shapes reads " .. lines[#lines])
	Tick(window, "shapes", false)
end

-- Rule: an event the client does not know is logged as unavailable and the test goes on; a recorder
-- kept beyond the stop registers nothing.
do
	Tick(window, "odd", true)
	local lines = Lines(window)
	assert(lines[#lines - 1] == "1.500 odd event unavailable NO_SUCH_EVENT", "an unknown event logged " .. lines[#lines - 1])
	assert(lines[#lines] == "1.500 odd went on", "after an unknown event the test wrote " .. lines[#lines])
	Tick(window, "odd", false)
	kept:On("SOME_EVENT", Noop)
	assert(not Listening(), "the recorder of a stopped test registered an event")
end

-- Rule: Select all shows the whole log, also rows the screen has not caught up with, and selects it.
-- While the log has the keyboard its text stays as it is, and what is typed there is undone.
do
	-- Given a row written this instant.
	Tick(window, "echo", true)

	-- When Select all is clicked.
	Click(window.selectButton)

	-- Then the field holds that row as well and has the keyboard, its text selected.
	local text = window.logEditbox:GetText()
	assert(text:find("echo started Echo$"), "Select all left out the newest row")
	assert(window.logEditbox:HasFocus() and window.logEditbox.highlighted, "Select all did not select the log")

	-- When a test writes meanwhile and a key is typed into the log.
	Fire("SOME_EVENT", 8, 9)
	RunTimers(0.5)
	assert(window.logEditbox:GetText() == text, "the log changed under a selection")
	window.logEditbox:Type("x")
	assert(window.logEditbox:GetText() == text, "typing changed the log")

	-- When another key is let go, then the log keeps the keyboard; when the copy is made with
	-- Ctrl+C, then it lets go and catches up.
	window.logEditbox.scripts.OnKeyUp(window.logEditbox, "C")
	isControlDown = true
	window.logEditbox.scripts.OnKeyUp(window.logEditbox, "X")
	assert(window.logEditbox:HasFocus(), "a key that copies nothing took the keyboard from the log")
	window.logEditbox.scripts.OnKeyUp(window.logEditbox, "C")
	isControlDown = false
	assert(not window.logEditbox:HasFocus(), "copying left the keyboard with the log")
	local lines = Lines(window)
	assert(lines[#lines] == "1.500 echo heard 8 9", "the log did not catch up after the selection")
	Tick(window, "echo", false)
end

-- Rule: the log keeps the newest thousand rows; the screen follows with the newest hundred, and
-- Select all shows them all.
do
	Tick(window, "flood", true)
	local lines = Lines(window)
	assert(#lines == 100 and lines[100] == "1.500 flood row 1005", "the screen shows " .. #lines .. " rows up to " .. lines[#lines])
	assert(window.countFontString:GetText() == "1000 rows, the newest 100 shown", "the count reads " .. window.countFontString:GetText())
	lines = AllLines(window)
	assert(#lines == 1000, "the log holds " .. #lines .. " rows")
	assert(lines[1] == "1.500 flood row 6" and lines[1000] == "1.500 flood row 1005", "the log dropped other rows than the oldest")
	Tick(window, "flood", false)
end

-- Rule: Clear empties the log, also while it is selected, and starts its clock anew.
do
	now = 110
	Click(window.selectButton)
	Click(window.clearButton)
	assert(window.logEditbox:GetText() == "", "Clear left rows in the log")
	now = 112
	Tick(window, "echo", true)
	local lines = Lines(window)
	assert(#lines == 1 and lines[1] == "2.000 echo started Echo", "after Clear the log shows " .. tostring(lines[1]))
	Tick(window, "echo", false)
	Click(window.clearButton)
end

-- Rule: a test pasted into the window's own page runs like a listed one, and Stop ends it.
do
	-- When code is pasted and run.
	Click(window.pageButtons.custom)
	window.customEditbox:SetFocus()
	window.customEditbox:Type('t:On("SOME_EVENT", function(value) t:Log("pasted", value) end)')
	Click(window.runButton)
	Fire("SOME_EVENT", 3)

	-- Then the field lets go of the keyboard and the test hears its event.
	assert(not window.customEditbox:HasFocus(), "Run left the keyboard with the pasted code")
	local lines = Lines(window)
	assert(lines[1] == "0.000 custom started custom test" and lines[2] == "0.000 custom pasted 3",
		"the pasted test logged " .. table.concat(lines, " | "))

	-- When it is stopped, then it hears nothing more.
	Click(window.stopButton)
	Fire("SOME_EVENT", 4)
	lines = Lines(window)
	assert(lines[#lines] == "0.000 custom stopped" and not Listening(), "Stop left the pasted test running")

	-- When the pasted code does not compile, then the log says why, with the line as pasted, and
	-- nothing runs.
	window.customEditbox:SetText("t:On(")
	Click(window.runButton)
	lines = Lines(window)
	assert(lines[#lines]:find("^0%.000 custom error ") and not Listening(), "broken code logged " .. lines[#lines])
	assert(lines[#lines]:find("]:1:", 1, true), "the error names another line than the pasted one: " .. lines[#lines])

	-- When code is run and run again while it runs, then the first run is stopped and its timer
	-- does nothing more.
	Click(window.clearButton)
	window.customEditbox:SetText('t:After(1, function() t:Log("timer of this run") end)')
	Click(window.runButton)
	Click(window.runButton)
	RunTimers(1)
	local stopped, fired = 0, 0
	for _, line in ipairs(Lines(window)) do
		if line:find("custom stopped$") then stopped = stopped + 1 end
		if line:find("timer of this run$") then fired = fired + 1 end
	end
	assert(stopped == 1 and fired == 1, "running a pasted test again stopped " .. stopped .. " runs and let " .. fired .. " timers write")
	Click(window.stopButton)
	Click(window.clearButton)
end

-- Rule: the callbacks of a pasted test for its stop run when Stop is clicked and when it is run
-- anew, and a pasted test that ends itself goes on to the end of its code.
do
	-- When a pasted test with a callback for its stop is run, run again and stopped.
	window.customEditbox:SetText('t:OnStop(function() t:Log("on stop") end)')
	Click(window.runButton)
	Click(window.runButton)
	Click(window.stopButton)

	-- Then each run ran its callback before its stop row.
	local lines = Lines(window)
	assert(#lines == 6 and lines[2] == "0.000 custom on stop" and lines[3] == "0.000 custom stopped"
		and lines[5] == "0.000 custom on stop" and lines[6] == "0.000 custom stopped",
		"the pasted test's callbacks for its stop logged " .. table.concat(lines, " | "))

	-- When a pasted test ends itself, then it is stopped and its code goes on, though it has no tick.
	Click(window.clearButton)
	window.customEditbox:SetText('t:Stop() t:Log("after the stop")')
	Click(window.runButton)
	lines = Lines(window)
	assert(#lines == 3 and lines[2] == "0.000 custom stopped" and lines[3] == "0.000 custom after the stop",
		"a pasted test that ended itself logged " .. table.concat(lines, " | "))
	Click(window.clearButton)
	Click(window.pageButtons.first)
end

-- Rule: while the window is closed, rows are recorded without work for the screen, and it shows
-- them when it opens.
do
	Tick(window, "echo", true)
	Lines(window)
	Slash()
	assert(Window() == nil)
	Fire("SOME_EVENT", 5, 6)
	assert(Queued() == 0, "the closed window queued a refresh")
	window.testCheckboxes.echo:SetChecked(false)
	Slash()
	assert(window.logEditbox:GetText():find("echo heard 5 6", 1, true), "the window opened without the rows recorded meanwhile")
	assert(window.testCheckboxes.echo:GetChecked(), "the window opened without showing the running test")
	Tick(window, "echo", false)
	Click(window.clearButton)
end

-- Rule: what a test draws shows in the open window, the values the client hides handed over as
-- they are, and the test learns that it was drawn. Nothing is drawn into the closed window, and
-- Clear empties what was drawn.
do
	-- When a test draws values, some of them hidden.
	Tick(window, "draw", true)
	Fire("SOME_EVENT", 5)

	-- Then the window shows them, the hidden ones as the client draws them. The log has none of
	-- them, only the test's own row that it drew.
	assert(window.drawnFontString:GetText() == "gain 5 <drawn> <drawn too> nil \nnext ",
		"the window shows " .. window.drawnFontString:GetText())
	local lines = Lines(window)
	assert(#lines == 2 and lines[2]:find("draw drawn true$"), "after drawing the log reads " .. table.concat(lines, " | "))

	-- When Clear is clicked, then nothing drawn is left.
	Click(window.clearButton)
	assert(window.drawnFontString:GetText() == "", "Clear left what a test drew")

	-- When the window is closed, then a test draws nothing and learns that.
	Slash()
	Fire("SOME_EVENT", 6)
	Slash()
	assert(window.drawnFontString:GetText() == "", "a test drew into the closed window")
	lines = Lines(window)
	assert(#lines == 1 and lines[1]:find("draw drawn false$"), "with the window closed the log reads " .. table.concat(lines, " | "))
	Tick(window, "draw", false)
	Click(window.clearButton)
end

-- Rule: a test that watches a function of the addon hears every call after the function ran, with
-- its arguments, and the call returns all that the function returned.
do
	-- Given nothing is hooked while no test watches.
	Click(window.pageButtons.second)
	assert(Hooked("Sum") == 0, "a function was hooked before a test watched it")
	Addon.calls = 0

	-- When the test is ticked and the function is called.
	Tick(window, "watch", true)
	local total, more = Addon.Sum(2, 3)

	-- Then the call returns what the function returns, and the test heard it after the function ran.
	assert(total == 5 and more == "and more", "the watched function returned " .. tostring(total) .. " and " .. tostring(more))
	local lines = Lines(window)
	assert(lines[#lines]:find(" watch sum 2 3 after call ", 1, true), "the watching test logged " .. lines[#lines])
	assert(lines[#lines]:find(" after call 1$"), "the callback ran before the function: " .. lines[#lines])

	-- When a second test watches the same function and a call comes.
	Tick(window, "watchToo", true)
	Addon.Sum(4, 1)

	-- Then both hear it, and the function was hooked once.
	lines = Lines(window)
	local heard = lines[#lines - 1] .. " | " .. lines[#lines]
	assert(heard:find("watch sum 4 1 after call 2", 1, true) and heard:find("watchToo also 4", 1, true),
		"two tests that watch one function logged " .. heard)
	assert(Hooked("Sum") == 1, "the function was hooked " .. Hooked("Sum") .. " times")

	-- When a callback fails, then the error is logged, the other test still hears the call, and
	-- the call returns what the function returned.
	local isOk, sum = pcall(Addon.Sum, 0, 1)
	assert(isOk and sum == 1, "an error in a watching callback reached the addon's call")
	lines = Lines(window)
	heard = lines[#lines - 1] .. " | " .. lines[#lines]
	assert(heard:find("watchToo error ", 1, true) and heard:find("bad call", 1, true) and heard:find("watch sum 0 1", 1, true),
		"a failing watching callback logged " .. heard)

	-- When the tests stop and a test watches the function anew, then it is not hooked again.
	Tick(window, "watch", false)
	Tick(window, "watch", true)
	assert(Hooked("Sum") == 1, "starting a watching test again hooked the function anew")

	-- When both stop and the function is called, then neither hears it.
	Tick(window, "watch", false)
	Tick(window, "watchToo", false)
	local count = #Lines(window)
	Addon.Sum(5, 5)
	assert(#Lines(window) == count, "a stopped test still watched the function")

	-- When a recorder kept beyond its stop asks to watch, then it hears nothing and nothing is hooked.
	keptWatch:Watch(Addon, "Sum", function() error("the kept recorder heard a call") end)
	keptWatch:Watch(Addon, "Other", Noop)
	Addon.Sum(6, 6)
	assert(#Lines(window) == count and Hooked("Other") == 0, "the recorder of a stopped test watched a function")
end

-- Rule: a function that is not there is logged as unavailable, and the test goes on.
do
	Click(window.clearButton)
	Tick(window, "missing", true)
	local lines = Lines(window)
	assert(lines[2]:find("missing function unavailable Missing$"), "a missing function logged " .. lines[2])
	assert(lines[3]:find("missing function unavailable value$"), "a value that is no function logged " .. lines[3])
	assert(lines[4]:find("missing function unavailable Sum$"), "a function of no table logged " .. lines[4])
	assert(lines[5]:find("missing went on$"), "after an unavailable function the test wrote " .. tostring(lines[5]))
	Tick(window, "missing", false)
	Click(window.clearButton)
end

-- Rule: a test can end itself from a handler, a timer and a watching callback, as if its tick were
-- removed, and the tick goes. Its callbacks for the stop run once, in order, before the row
-- "stopped", whatever stops it, and an error in one is logged.
do
	-- When the test is ticked and its handler ends it.
	Click(window.clearButton)
	Tick(window, "ender", true)
	Fire("SOME_EVENT")

	-- Then its callbacks ran once and in order, the failing one logged, then the stop.
	local lines = Lines(window)
	assert(#lines == 5 and lines[2]:find("ender first on stop$") and lines[3]:find("ender error ")
		and lines[3]:find("stop failed", 1, true) and lines[4]:find("ender last on stop$") and lines[5]:find("ender stopped$"),
		"a test that ended itself from a handler logged " .. table.concat(lines, " | "))
	assert(not window.testCheckboxes.ender:GetChecked(), "the tick stayed after the test ended itself")
	assert(not Listening(), "a test that ended itself left an event registered")

	-- When it is ticked again and a timer of it ends it.
	Click(window.clearButton)
	Tick(window, "ender", true)
	Fire("OTHER_EVENT")
	assert(window.testCheckboxes.ender:GetChecked(), "the test ended before its timer came due")
	RunTimers(0)
	lines = Lines(window)
	assert(lines[#lines]:find("ender stopped$") and not window.testCheckboxes.ender:GetChecked(),
		"a test that ended itself from a timer logged " .. lines[#lines])

	-- When it is ticked again and a watching callback of it ends it.
	Click(window.clearButton)
	Tick(window, "ender", true)
	Addon.Sum(1, 1)
	assert(window.testCheckboxes.ender:GetChecked(), "the test ended at a call it was not to end at")
	local total = Addon.Sum(99, 1)
	lines = Lines(window)
	assert(total == 100 and lines[#lines]:find("ender stopped$") and not window.testCheckboxes.ender:GetChecked(),
		"a test that ended itself from a watching callback logged " .. lines[#lines])

	-- When it is ticked again and the tick is removed, then its callbacks run as well.
	Click(window.clearButton)
	Tick(window, "ender", true)
	Tick(window, "ender", false)
	lines = Lines(window)
	assert(#lines == 5 and lines[2]:find("ender first on stop$") and lines[5]:find("ender stopped$"),
		"removing the tick logged " .. table.concat(lines, " | "))

	-- When a recorder kept from an earlier run asks to end the test, then the later run goes on.
	local earlier = keptEnder
	Tick(window, "ender", true)
	earlier:Stop()
	assert(window.testCheckboxes.ender:GetChecked() and Listening(), "a recorder kept beyond its run ended a later run")
	Tick(window, "ender", false)
	Click(window.clearButton)
end

-- Rule: a test draws values into one row of the drawing area, the hidden ones handed over as they
-- are, and the other rows stay. A row outside the area and the closed window draw nothing. t:Show
-- empties the rows, t:Row empties what t:Show drew, and Clear empties both.
do
	-- Given the test that draws rows is ticked.
	Tick(window, "rows", true)
	local last = #window.rowFontStrings
	assert(last >= 14, "the drawing area has " .. last .. " rows")
	assert(keptWatch.rows == last, "the recorder says the window has " .. tostring(keptWatch.rows) .. " rows, not " .. last)

	-- When it draws into the second and the last row.
	Fire("SOME_EVENT", 2, "a", SECRET, HIDDEN, 7, nil)
	Fire("SOME_EVENT", last, "b")

	-- Then those rows show the values, the hidden ones as the client draws them, and the other rows nothing.
	assert(window.rowFontStrings[2]:GetText() == "a <drawn> <drawn too> 7 nil ", "the second row shows " .. window.rowFontStrings[2]:GetText())
	assert(window.rowFontStrings[last]:GetText() == "b ", "the last row shows " .. window.rowFontStrings[last]:GetText())
	assert(window.rowFontStrings[1]:GetText() == "", "a row was drawn that was not asked for")
	local lines = Lines(window)
	assert(lines[#lines]:find("rows row true$"), "the test did not learn that it drew a row: " .. lines[#lines])

	-- When it draws into rows that are not there, then nothing is drawn and the test learns that.
	Fire("SOME_EVENT", 0, "x")
	Fire("SOME_EVENT", last + 1, "x")
	Fire("SOME_EVENT", nil, "x")
	lines = Lines(window)
	assert(lines[#lines - 2]:find("rows row false$") and lines[#lines - 1]:find("rows row false$") and lines[#lines]:find("rows row false$"),
		"an index outside the rows logged " .. table.concat(lines, " | ", #lines - 2))
	assert(window.rowFontStrings[2]:GetText() == "a <drawn> <drawn too> 7 nil ", "an index outside the rows changed a row")

	-- When it shows a text, then the rows are empty; when it draws a row, then the text is gone.
	Fire("OTHER_EVENT", "free")
	assert(window.drawnFontString:GetText() == "free " and window.rowFontStrings[2]:GetText() == ""
		and window.rowFontStrings[last]:GetText() == "", "t:Show left the rows as they were")
	Fire("SOME_EVENT", 1, "c")
	assert(window.drawnFontString:GetText() == "" and window.rowFontStrings[1]:GetText() == "c ", "t:Row left what t:Show drew")

	-- When Clear is clicked, then no row is left.
	Click(window.clearButton)
	assert(window.rowFontStrings[1]:GetText() == "", "Clear left a drawn row")

	-- When the window is closed, then no row is drawn and the test learns that.
	Slash()
	Fire("SOME_EVENT", 1, "d")
	Slash()
	assert(window.rowFontStrings[1]:GetText() == "", "a test drew a row into the closed window")
	lines = Lines(window)
	assert(lines[#lines]:find("rows row false$"), "with the window closed drawing a row logged " .. lines[#lines])
	Tick(window, "rows", false)
	Click(window.clearButton)
	Click(window.pageButtons.first)
end

-- Rule: the content of both columns begins 78 below the top of the window. While nothing is drawn the log
-- reaches from there down to its row of buttons, which stands on the line of Run and Stop at the bottom.
do
	-- Given the window has just opened and nothing is drawn.
	local logLabel, hint
	for _, frame in ipairs(frames) do
		if frame.kind == "FontString" and frame.parent == window then
			if frame.text == "Log" then logLabel = frame elseif frame.text:find("^Paste") then hint = frame end
		end
	end
	assert(logLabel and hint, "the window lacks the label of the log or that of the field for a pasted test")
	local panel, customPanel = window.logPanel, window.runButton.point[2]
	-- What hangs on the content frame is that far below the top of the window more than its offset says.
	local drop = window.content.point[5]

	-- Then the page buttons begin 78 below the top, and the content below them a line of buttons and
	-- a gap lower. The label of the log stands level with that content: with the first checkbox and
	-- with the label of the field for a pasted test.
	for key, button in pairs(window.pageButtons) do
		assert(drop + button.point[5] == -78, "the page button " .. key .. " begins " .. -(drop + button.point[5]) .. " below the top, not 78")
	end
	assert(drop + window.testCheckboxes.echo.point[5] == -110, "the content below the page buttons begins at "
		.. drop + window.testCheckboxes.echo.point[5] .. ", not 110 below the top")
	assert(logLabel.point[4] == 330 and logLabel.point[5] == window.testCheckboxes.echo.point[5]
		and logLabel.point[5] == hint.point[5],
		"the label of the log stands at " .. logLabel.point[4] .. ", " .. logLabel.point[5])

	-- And the log begins level with the field for a pasted test, so that both boxes begin on one line.
	local top = panel.points.TOPLEFT
	assert(top[4] == 330 and top[5] == customPanel.points.TOPLEFT[5] and drop + top[5] == -126,
		"the log begins at " .. top[5] .. ", the field for a pasted test at " .. customPanel.points.TOPLEFT[5])

	-- And it ends level with the field for a pasted test, with its row of buttons under it as Run and Stop
	-- have theirs, so that the row stands on their line.
	local bottom = panel.points.BOTTOMRIGHT
	assert(bottom[2] == window and bottom[3] == "BOTTOMRIGHT" and bottom[4] == -30, "the log is not anchored to the corner of the window")
	assert(bottom[5] == customPanel.points.BOTTOMRIGHT[5] and bottom[5] == 58,
		"the log ends " .. bottom[5] .. " above the bottom, the field for a pasted test " .. customPanel.points.BOTTOMRIGHT[5])
	local selectAt, runAt = window.selectButton.point, window.runButton.point
	assert(selectAt[1] == "TOPLEFT" and selectAt[2] == panel and selectAt[3] == "BOTTOMLEFT" and selectAt[5] == runAt[5],
		"the row of buttons of the log does not stand under its panel as Run and Stop do")
	assert(window.clearButton.point[2] == window.selectButton and window.countFontString.point[2] == window.clearButton,
		"Clear and the count do not follow Select all")

	-- And the log is as tall as the content of the left column: the window's 560 less its top and its bottom.
	assert(560 + drop + top[5] - bottom[5] == 376, "the log is " .. 560 + drop + top[5] - bottom[5] .. " tall, not 376")
end

-- Rule: the first drawing, by t:Show or t:Row, makes room for the drawing area at the bottom of the right
-- side and anchors only the log's panel anew, once. A second drawing anchors nothing, and Clear gives the
-- room back. A call that draws nothing, or into the closed window, makes no room.
do
	-- Given nothing is drawn, and the test that draws is ticked on its page.
	local panel = window.logPanel
	local rest = { window, window.selectButton, window.clearButton, window.countFontString, window.drawnFontString,
		window.rowFontStrings[1], window.rowFontStrings[#window.rowFontStrings] }
	local function Calls()
		local calls = {}
		for index, frame in ipairs(rest) do calls[index] = frame.pointCalls end
		return calls
	end
	-- Whether none of the other frames was anchored since.
	local function Same(before)
		for index, frame in ipairs(rest) do
			if frame.pointCalls ~= before[index] then return false end
		end
		return true
	end
	local bottom = panel.points.BOTTOMRIGHT[5]
	local row = window.rowFontStrings[1].point[5]
	local calls, before = panel.pointCalls, Calls()
	Click(window.pageButtons.second)
	Tick(window, "rows", true)

	-- When a drawing goes into the closed window, then no room is made.
	Slash()
	Fire("SOME_EVENT", 1, "x")
	Fire("OTHER_EVENT", "free")
	Slash()
	assert(panel.points.BOTTOMRIGHT[5] == bottom, "a drawing into the closed window made room")
	assert(panel.pointCalls == calls, "the log was anchored anew without a change of the state of the drawing")

	-- When calls without values draw nothing, then no room is made.
	Fire("OTHER_EVENT")
	Fire("SOME_EVENT", 3)
	assert(panel.points.BOTTOMRIGHT[5] == bottom and panel.pointCalls == calls, "a call that drew nothing made room")

	-- When the first drawing comes, by t:Show.
	Fire("OTHER_EVENT", "free")

	-- Then the log ends higher and the row of buttons under it stays 8 above the first row of the drawing area.
	local raised = panel.points.BOTTOMRIGHT[5]
	assert(raised > bottom, "the log made no room for the drawing area")
	local gap = raised + window.selectButton.point[5] - 24 - row
	assert(gap == 8, "the row of buttons of the log ends " .. gap .. " above the drawing area, not 8")
	local height = 560 + window.content.point[5] + panel.points.TOPLEFT[5] - raised
	assert(height == 172, "the log is " .. height .. " tall with something drawn, not 172")

	-- And only the log's panel was anchored anew, by one anchor; the window, its row of buttons and the
	-- drawing area were not.
	assert(panel.pointCalls == calls + 1, "the first drawing anchored the panel " .. panel.pointCalls - calls .. " times")
	assert(Same(before), "the first drawing anchored a frame other than the log's panel")

	-- When a second drawing comes, by t:Show and by t:Row, then nothing is anchored anew.
	Fire("OTHER_EVENT", "more")
	Fire("SOME_EVENT", 4, "row")
	assert(panel.pointCalls == calls + 1 and Same(before), "a further drawing anchored a frame anew")

	-- When Clear is clicked, then the log has the room back, by one anchor anew.
	Click(window.clearButton)
	assert(panel.points.BOTTOMRIGHT[5] == bottom, "Clear did not give the room back to the log")
	assert(panel.pointCalls == calls + 2 and Same(before), "Clear anchored more than the log's panel, or it more than once")

	-- When Clear is clicked again, then nothing is anchored anew.
	Click(window.clearButton)
	assert(panel.pointCalls == calls + 2, "Clear anchored the panel with nothing drawn")

	-- When the first drawing after that is by t:Row, then room is made again.
	Fire("SOME_EVENT", 4, "row")
	assert(panel.points.BOTTOMRIGHT[5] == raised and panel.pointCalls == calls + 3 and Same(before),
		"a drawing by t:Row made no room, or anchored more than the panel")
	Tick(window, "rows", false)
	Click(window.clearButton)
	Click(window.pageButtons.first)
end

-- Rule: the window comes in the design chosen for the options, skinned once like that design's popups.
do
	-- Given the classic window was used so far.
	assert(next(skinned) == nil, "the classic debug window was handed to another design's skin")

	-- When another design is chosen and the command runs.
	saved.optionsDesign = "other"
	Slash()
	local other = assert(Window(), "no window opened in the other design")

	-- Then that design gets a window of its own, skinned once with all its pages in it, and the
	-- classic one is closed.
	assert(other ~= window and skinned[other] == 1 and skinned[window] == nil, "the other design's window was not skinned on its own")
	assert(other.hadTestsWhenSkinned, "the window was handed to the skin before its tests were built")
	assert(other.hadLogWhenSkinned, "the log was not placed when the skin got the window")
	assert(not window.shown, "the classic debug window stayed open beside the other design's")

	-- When it is closed and opened again, then it is the same window and it is not skinned again.
	Slash()
	Slash()
	assert(Window() == other and skinned[other] == 1, "the other design's window was built or skinned again")

	-- When the classic design is chosen again, then the classic window comes back.
	saved.optionsDesign = nil
	Slash()
	assert(Window() == window and not other.shown, "the classic debug window did not come back")
	assert(#registered == 0, "a debug window was registered with the options' popups")
end

-- Rule: the window of another design shows the page chosen last, and the choice is not saved.
do
	-- Given the window's own page is chosen in the classic window.
	Click(window.pageButtons.custom)

	-- When another design takes the window over.
	MSBTOptions.Designs.Select("other")

	-- Then its window shows that page.
	local other = Window()
	assert(other.customEditbox:IsVisible() and not other.testCheckboxes.echo:IsVisible() and not other.pageButtons.custom:IsEnabled(),
		"the other design's window opened on another page than the one chosen")

	-- When a page is chosen there and the classic design comes back, then the classic window shows it.
	Click(other.pageButtons.second)
	MSBTOptions.Designs.Select("classic")
	assert(window.testCheckboxes.watch:IsVisible() and not window.customEditbox:IsVisible(),
		"the classic window did not show the page chosen in another design's window")
	for key, value in pairs(saved) do
		assert(value ~= "second", "the chosen page was saved with the settings under " .. key)
	end
	Click(window.pageButtons.first)
end

-- Rule: a design chosen while the window is open takes the window over at once; a closed window
-- stays closed.
do
	-- Given the classic debug window is open; when another design is chosen.
	assert(Window() == window)
	MSBTOptions.Designs.Select("other")

	-- Then that design's window is open in its place.
	local other = Window()
	assert(other and other ~= window and not window.shown, "the open window did not follow the chosen design")

	-- When the classic design is chosen again, then the classic window is back.
	MSBTOptions.Designs.Select("classic")
	assert(Window() == window and not other.shown, "the open window did not follow back to the classic design")

	-- When the window is closed and a design is chosen, then no window opens.
	Slash()
	MSBTOptions.Designs.Select("other")
	assert(Window() == nil, "choosing a design opened the closed debug window")
	MSBTOptions.Designs.Select("classic")
	Slash()
	assert(Window() == window)
end

-- Rule: the window opens where it was last dragged to, in every design, and where the saved
-- settings say so after a reload.
do
	-- When the classic window is dragged somewhere.
	window.centerX, window.centerY = 300, 400
	window.scripts.OnDragStop(window)

	-- Then the place is kept with the saved settings.
	local position = saved.debugWindowPosition
	assert(position and position[1] == 300 and position[2] == 400, "the place the window was dragged to was not saved")

	-- When a drag ends without the frame knowing where it stands, then the place kept stays.
	window.centerX, window.centerY = nil, nil
	window.scripts.OnDragStop(window)
	position = saved.debugWindowPosition
	assert(position[1] == 300 and position[2] == 400, "a drag without a place overwrote the place kept")

	-- When another design takes the window over, then its window stands there as well, although
	-- that design's skin places popups itself.
	MSBTOptions.Designs.Select("other")
	local point = Window().point
	assert(#point == 5 and point[1] == "CENTER" and point[2] == UIParent and point[3] == "BOTTOMLEFT"
		and point[4] == 300 and point[5] == 400, "the other design's window opened elsewhere than the window was dragged to")

	-- When the saved settings name another place, as they do after a reload, and the window holds an anchor
	-- of another point as well, then the window opens there, on that anchor alone.
	MSBTOptions.Designs.Select("classic")
	window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 5, 5)
	saved.debugWindowPosition = { 10, 20 }
	Slash()
	Slash()
	assert(window.point[4] == 10 and window.point[5] == 20, "the window did not open where the saved settings say")
	assert(window.anchors == 1, "the window was given a place without letting go of the one before")
	saved.debugWindowPosition = nil
end

-- Rule: the window of another design opens in the state of the drawing, and so does a window opened later;
-- the window itself is anchored by no one but the design.
do
	-- Given something is drawn in the classic window, which is open.
	assert(Window() == window)
	local panel = window.logPanel
	local bottom = panel.points.BOTTOMRIGHT[5]
	Tick(window, "draw", true)
	Fire("SOME_EVENT", 1)
	local raised = panel.points.BOTTOMRIGHT[5]
	assert(raised > bottom, "the classic window made no room for the drawing")
	Tick(window, "draw", false)

	-- When another design takes the window over, then its log ends where the classic one does, and the
	-- design's own placing of the window was not asked for it. The count of anchors starts once it is open.
	MSBTOptions.Designs.Select("other")
	local other = Window()
	assert(other ~= window, "the other design's window did not open")
	local calls, placed = other.logPanel.pointCalls, other.skinPoints
	assert(other.logPanel.points.BOTTOMRIGHT[5] == raised, "the other design's window opened without the room for the drawing")
	assert(other.skinPoints == placed, "the window of the design was anchored anew for the room")

	-- When Clear is clicked there and the classic design comes back, then its window has the room back too.
	Click(other.clearButton)
	assert(other.logPanel.points.BOTTOMRIGHT[5] == bottom, "Clear in the other design's window did not give the room back")
	MSBTOptions.Designs.Select("classic")
	assert(Window() == window and panel.points.BOTTOMRIGHT[5] == bottom,
		"the classic window opened again with the room of a drawing that was cleared")
	assert(other.logPanel.pointCalls == calls + 1 and other.skinPoints == placed,
		"the other design's panel was anchored " .. other.logPanel.pointCalls - calls .. " times since it opened, not 1")
end

-- Rule: everything placed from the top below the title hangs on the window's content frame, which stands 30 below
-- the corner of the window in the classic look and where a design's skin puts it otherwise. The title, the X and
-- what is placed from the bottom stay on the window.
do
	-- Given the classic window.
	assert(Window() == window)
	-- Whether a frame has an anchor of the named point on the given frame.
	local function Hangs(frame, name, anchor)
		local point = frame.points and frame.points[name]
		return point ~= nil and point[2] == anchor
	end
	-- Whether the frames that are placed from the top hang on the content and the others on the window.
	local function Check(target, label)
		local content = target.content
		assert(content and content.kind == "Frame" and content.parent == target and content.width == 1 and content.height == 1,
			label .. " has no content frame of 1 by 1 of its own")
		local labelOfLog, hint, title
		for _, frame in ipairs(frames) do
			if frame.kind == "FontString" and frame.parent == target then
				if frame.text == "Log" then labelOfLog = frame
				elseif frame.text:find("^Paste") then hint = frame
				elseif frame.text == "MSBT Debug" then title = frame end
			end
		end
		for key, button in pairs(target.pageButtons) do
			assert(Hangs(button, "TOPLEFT", content), "the page button " .. key .. " of " .. label .. " does not hang on the content")
		end
		for key, checkbox in pairs(target.testCheckboxes) do
			assert(Hangs(checkbox, "TOPLEFT", content), "the checkbox " .. key .. " of " .. label .. " does not hang on the content")
		end
		assert(Hangs(labelOfLog, "TOPLEFT", content), "the label of the log of " .. label .. " does not hang on the content")
		assert(Hangs(hint, "TOPLEFT", content), "the label of the field for a pasted test of " .. label .. " does not hang on the content")
		local customPanel = target.runButton.point[2]
		assert(Hangs(target.logPanel, "TOPLEFT", content), "the top of the log of " .. label .. " does not hang on the content")
		assert(Hangs(customPanel, "TOPLEFT", content), "the top of the field for a pasted test of " .. label .. " does not hang on the content")
		assert(Hangs(title, "TOP", target), "the title of " .. label .. " does not stand on the window")
		-- The X is the one button of the window that stands in its top right corner.
		local cornerButtons = 0
		for _, frame in ipairs(frames) do
			if frame.kind == "Button" and frame.parent == target and Hangs(frame, "TOPRIGHT", target) then
				cornerButtons = cornerButtons + 1
			end
		end
		assert(cornerButtons == 1, "the X of " .. label .. " does not stand on the window")
		assert(Hangs(target.logPanel, "BOTTOMRIGHT", target), "the bottom of the log of " .. label .. " does not stand on the window")
		assert(Hangs(customPanel, "BOTTOMRIGHT", target), "the bottom of the field for a pasted test of " .. label .. " does not stand on the window")
		local rowsStand = Hangs(target.drawnFontString, "TOPLEFT", target)
		for _, row in ipairs(target.rowFontStrings) do rowsStand = rowsStand and Hangs(row, "TOPLEFT", target) end
		assert(rowsStand, "the rows of what tests draw of " .. label .. " do not stand on the window")
		return content, customPanel
	end

	local function Tall(target, panel)
		local top = target.content.point[5] + panel.points.TOPLEFT[5]
		return 560 + top - panel.points.BOTTOMRIGHT[5]
	end

	-- Then the content frame hangs 30 below the window's corner, anchored once, and the page buttons begin 48
	-- below it, which is 78 below the top of the window, where they were.
	local content = Check(window, "the classic window")
	assert(content.point[1] == "TOPLEFT" and content.point[2] == window and content.point[3] == "TOPLEFT"
		and content.point[4] == 0 and content.point[5] == -30, "the content frame of the classic window is not 30 below the window's corner")
	assert(content.pointCalls == 1, "the content frame of the classic window was anchored " .. content.pointCalls .. " times, not once")
	assert(window.pageButtons.first.point[5] == -48, "the page buttons of the classic window begin " .. -window.pageButtons.first.point[5]
		.. " below the content frame, not 48")
	assert(Tall(window, window.logPanel) == 376, "the log of the classic window is " .. Tall(window, window.logPanel) .. " tall, not 376")

	-- When a design whose skin puts the content frame back at the corner gets its window, then the debug code
	-- anchored the frame once and the skin once, the content begins 48 below the top, and the log and the field
	-- for a pasted test are 30 taller.
	MSBTOptions.Designs.Select("other")
	local other = Window()
	local otherContent, otherPanel = Check(other, "the window of a skin that moves the content")
	assert(other.contentCallsWhenSkinned == 1, "the content frame was anchored " .. tostring(other.contentCallsWhenSkinned)
		.. " times by the debug code before the skin, not once")
	assert(otherContent.point[1] == "TOPLEFT" and otherContent.point[2] == other and otherContent.point[3] == "TOPLEFT"
		and otherContent.point[4] == 0 and otherContent.point[5] == 0, "the skin did not put the content frame at the corner")
	assert(Tall(other, other.logPanel) == 406, "the log is " .. Tall(other, other.logPanel) .. " tall where the content moved up, not 406")
	assert(Tall(other, otherPanel) == 406, "the field for a pasted test is " .. Tall(other, otherPanel) .. " tall where the content moved up, not 406")

	-- When the window is closed and opened again, and when the design comes back, then the frame is not anchored
	-- again.
	Slash()
	Slash()
	MSBTOptions.Designs.Select("classic")
	MSBTOptions.Designs.Select("other")
	assert(Window() == other and otherContent.pointCalls == 2 and otherContent.point[5] == 0,
		"the content frame was anchored " .. otherContent.pointCalls .. " times, not twice (once by the debug code, once by the skin)")
	assert(content.pointCalls == 1, "the content frame of the classic window was anchored again")

	-- When the classic design comes back, then its window is the one that was open.
	MSBTOptions.Designs.Select("classic")
	assert(Window() == window)
end

-- Rule: when a design's skin fails, the window it failed on is kept, so that asking again builds
-- no further one.
do
	-- Given the window is closed and a design whose skin fails is chosen.
	Slash()
	saved.optionsDesign = "failing"

	-- When the command runs twice.
	local opened = pcall(Slash)
	local built = #frames
	local reopened = pcall(Slash)

	-- Then the first time fails, and the second opens the window that was built then.
	assert(not opened and reopened and #frames == built and Window() ~= nil,
		"after a failing skin the command built " .. (#frames - built) .. " further frames")
	saved.optionsDesign = nil
	Slash()
	assert(Window() == window, "the classic debug window did not come back after the failing design")
end

-- Rule: what a test draws takes a hidden boolean as the client's formatter does, which accepts only
-- strings and numbers: as a hidden 1 or 0 where the client has the call for it, else as a name. A
-- boolean that is not hidden is drawn as text.
do
	-- Given the test that draws, and a client with the call that turns a hidden boolean into a hidden 1 or 0.
	Click(window.pageButtons.first)
	Click(window.clearButton)
	C_CurveUtil = { EvaluateColorValueFromBoolean = function(isTrue, yes, no) if isTrue then return yes end return no end }
	Tick(window, "draw", true)

	-- When a hidden false and a hidden true are drawn, and a false that is not hidden.
	Hide(false)
	Fire("SOME_EVENT", false)
	local drawn = window.drawnFontString:GetText()
	assert(drawn == "gain 0 <drawn> <drawn too> nil \nnext ", "a hidden false was drawn as " .. drawn)
	Hide(true)
	Fire("SOME_EVENT", true)
	drawn = window.drawnFontString:GetText()
	assert(drawn == "gain 1 <drawn> <drawn too> nil \nnext ", "a hidden true was drawn as " .. drawn)
	Hide({})
	Fire("SOME_EVENT", false)
	drawn = window.drawnFontString:GetText()
	assert(drawn == "gain false <drawn> <drawn too> nil \nnext ", "a boolean that is not hidden was drawn as " .. drawn)

	-- When the client lacks the call, then a hidden boolean is named.
	C_CurveUtil = {}
	Hide(true)
	Fire("SOME_EVENT", true)
	drawn = window.drawnFontString:GetText()
	assert(drawn == "gain <hidden boolean> <drawn> <drawn too> nil \nnext ", "a hidden true without the call was drawn as " .. drawn)
	C_CurveUtil = nil
	Click(window.clearButton)
	Hide(false)
	Fire("SOME_EVENT", false)
	drawn = window.drawnFontString:GetText()
	assert(drawn == "gain <hidden boolean> <drawn> <drawn too> nil \nnext ", "a hidden false without the client's table was drawn as " .. drawn)
	Hide({})
	Tick(window, "draw", false)
	Click(window.clearButton)
end

-- Rule: the format for a number of values is built once and kept.
do
	-- Given a count of values that was never drawn before.
	Click(window.pageButtons.second)
	Tick(window, "rows", true)
	local many = {}
	for index = 1, 23 do many[index] = index end
	local built, rep = 0, string.rep
	string.rep = function(...)
		built = built + 1
		return rep(...)
	end

	-- When values of that count are drawn three times.
	for _ = 1, 3 do Fire("OTHER_EVENT", unpack(many)) end
	string.rep = rep

	-- Then the format was built once, and the text is right.
	assert(built == 1, "the format for 23 values was built " .. built .. " times")
	assert(window.drawnFontString:GetText() == table.concat(many, " ") .. " ", "23 values were drawn as " .. window.drawnFontString:GetText())
	Tick(window, "rows", false)
	Click(window.clearButton)
end

-- Rule: of the errors of one run the first five are logged and the rest are counted; the stop says
-- how many there were, and only when more than five came.
do
	-- When a test whose handler fails is run and the handler fails five times.
	Click(window.pageButtons.first)
	Click(window.clearButton)
	Tick(window, "faulty", true)
	for _ = 1, 5 do Fire("SOME_EVENT") end
	Tick(window, "faulty", false)

	-- Then all five are logged and the stop says nothing of them.
	local lines = Lines(window)
	assert(#lines == 7 and lines[2]:find("faulty error ") and lines[6]:find("faulty error ") and lines[7]:find("faulty stopped$"),
		"five errors were logged as " .. table.concat(lines, " | "))

	-- When it is run again and the handler fails eight times.
	Click(window.clearButton)
	Tick(window, "faulty", true)
	for _ = 1, 8 do Fire("SOME_EVENT") end
	Tick(window, "faulty", false)

	-- Then the first five are logged, and before the stop a row says how many there were.
	lines = Lines(window)
	assert(#lines == 8 and lines[6]:find("faulty error ") and lines[7]:find("faulty errors 8 the first 5 are logged$")
		and lines[8]:find("faulty stopped$"), "eight errors were logged as " .. table.concat(lines, " | "))
	Click(window.clearButton)
end

-- Rule: a second watch of the same function in one test replaces the first.
do
	Click(window.pageButtons.second)
	Click(window.clearButton)
	Tick(window, "twice", true)
	Addon.Sum(1, 1)
	local lines = Lines(window)
	assert(#lines == 2 and lines[2]:find("twice second watch$"), "two watches of one function logged " .. table.concat(lines, " | "))
	Tick(window, "twice", false)
	Click(window.clearButton)
end

-- Rule: only a function the table holds itself is watched. One an object reaches through its metatable
-- is not, so that the object gets no wrapper that would shadow the method of its class; the class table
-- is watched and sees the calls of the instance, with the instance as the first argument.
do
	-- When a test watches the method through the instance and through the class.
	Click(window.clearButton)
	Tick(window, "inherit", true)

	-- Then the instance has no wrapper and the test says the function is unavailable there.
	local lines = Lines(window)
	assert(#lines == 2 and lines[2]:find("inherit function unavailable Method$"),
		"watching a method through an instance logged " .. table.concat(lines, " | "))
	assert(rawget(instance, "Method") == nil, "a wrapper was put on the instance")

	-- When the method is called on the instance, then the watch of the class hears it.
	instance:Method(7)
	lines = Lines(window)
	assert(#lines == 3 and lines[3]:find("inherit class heard true 7$"),
		"a call on the instance was heard as " .. table.concat(lines, " | "))
	assert(Hooked("Method") == 1 and Class.calls == 1, "the method was hooked " .. Hooked("Method") .. " times or not run")
	Tick(window, "inherit", false)
	Click(window.clearButton)
end

-- Rule: when a test stops, its events and watches have ended before its callbacks for the stop run, and
-- in those callbacks it can neither hear nor watch nor time anything more.
do
	-- Given a test that hears an event and watches a function.
	Tick(window, "stopper", true)

	-- When it is stopped, and its callback fires the event, calls the watched function, and asks to hear
	-- another event, to watch another function and for a timer.
	Tick(window, "stopper", false)
	RunTimers(1)

	-- Then the callback ran before the stop and none of that reached the test.
	local lines = Lines(window)
	assert(#lines == 3 and lines[2]:find("stopper stop callback$") and lines[3]:find("stopper stopped$"),
		"the callback for the stop logged " .. table.concat(lines, " | "))
	assert(not Listening(), "a callback for the stop registered an event")
	assert(Hooked("Late") == 0, "a callback for the stop watched a function")
	Click(window.clearButton)
end

-- Rule: leaving the page of the pasted test takes the keyboard from its field.
do
	-- Given the pasted test's field has the keyboard.
	Click(window.pageButtons.custom)
	window.customEditbox:SetFocus()

	-- When another page is chosen, then the field lets go.
	Click(window.pageButtons.first)
	assert(not window.customEditbox:HasFocus(), "the field of the pasted test kept the keyboard on another page")
end

-- Rule: a test stopped while another design's window was open has lost its tick when its own window
-- opens again.
do
	-- Given a test runs and the classic window shows it ticked.
	Tick(window, "echo", true)

	-- When another design's window opens and the test is stopped there.
	saved.optionsDesign = "other"
	Slash()
	local other = Window()
	assert(other ~= window and other.testCheckboxes.echo:GetChecked(), "the other design's window did not show the running test")
	Tick(other, "echo", false)

	-- Then the classic window, when it comes back, shows no tick for it.
	saved.optionsDesign = nil
	Slash()
	assert(Window() == window and not window.testCheckboxes.echo:GetChecked(), "the window opened again with the tick of a test that stopped")
end

-- Rule: the buttons of the pages wrap after three to a line, and the checkboxes of a page begin below the
-- last line of buttons and stand 26 apart.
do
	-- Given four pages, with the window's own five, and a design of its own for a window built with them.
	local function Page(key, label)
		return { key = key, label = label, tests = {
			{ key = key .. "1", label = label .. " 1", run = Noop }, { key = key .. "2", label = label .. " 2", run = Noop },
		} }
	end
	local pagesBefore = Debug.pages
	Debug.pages = { Page("p1", "One"), Page("p2", "Two"), Page("p3", "Three"), Page("p4", "Four") }
	saved.optionsDesign = "wide"
	Slash()
	local wide = Window()

	-- Then the first three buttons stand on a line, a slot apart, the fourth and the window's own begin
	-- the next line, one line lower.
	local one, two, three = wide.pageButtons.p1.point, wide.pageButtons.p2.point, wide.pageButtons.p3.point
	local four, own = wide.pageButtons.p4.point, wide.pageButtons.custom.point
	assert(one[5] == two[5] and two[5] == three[5], "the first three page buttons are not on one line")
	assert(two[4] - one[4] == 94 and three[4] - two[4] == 94, "the page buttons are not a slot apart")
	assert(four[4] == one[4] and own[4] == two[4] and four[5] == own[5], "the buttons after the third did not begin a new line")
	assert(one[5] - four[5] == 28, "the lines of page buttons are " .. (one[5] - four[5]) .. " apart")

	-- And the checkboxes of a page begin below the last line of buttons and are 26 apart.
	local first, second = wide.testCheckboxes.p11.point, wide.testCheckboxes.p12.point
	assert(first[4] == one[4] and first[5] == four[5] - 32, "the first checkbox stands at " .. first[4] .. ", " .. first[5])
	assert(first[5] - second[5] == 26, "the checkboxes are " .. (first[5] - second[5]) .. " apart")

	-- And the content begins 78 below the top, the log a label's gap below the first checkbox, and
	-- below two lines of buttons 15 tests fit above the buttons at the bottom, which end 30 above the
	-- window's bottom edge; below one line 16 do.
	local function Fits(point)
		return math.floor((window.content.point[5] + point[5] - 24 + window.height - 30) / 26) + 1
	end
	local logTop = wide.logPanel.points.TOPLEFT[5]
	assert(wide.content.point[5] + one[5] == -78 and logTop == first[5] - 16, "the content of the window with two lines of buttons begins lower")
	assert(Fits(first) == 15, Fits(first) .. " tests fit below two lines of page buttons, not 15")
	assert(Fits(window.testCheckboxes.echo.point) == 16, Fits(window.testCheckboxes.echo.point) .. " tests fit below one line of page buttons, not 16")
	assert(560 + wide.content.point[5] + logTop - wide.logPanel.points.BOTTOMRIGHT[5] == 348, "the log is "
		.. 560 + wide.content.point[5] + logTop - wide.logPanel.points.BOTTOMRIGHT[5] .. " tall below two lines of page buttons, not 348")

	-- When the classic window comes back, then the listed pages are the ones before.
	Debug.pages = pagesBefore
	saved.optionsDesign = nil
	Slash()
	assert(Window() == window, "the classic window did not come back after the design with four pages")
end

-- Rule: the listed tests come from one file, on the pages game and addon.
do
	-- Given the tests file.
	dofile("Diagnostics/DebugTests.lua")
	local byKey, pageKeys = {}, {}
	for _, page in ipairs(Debug.pages) do
		assert(type(page.key) == "string" and type(page.label) == "string" and type(page.tests) == "table",
			"a listed page lacks its key, label or tests")
		assert(page.key ~= "custom" and not pageKeys[page.key], "the page key " .. page.key .. " is taken")
		pageKeys[page.key] = true
		-- A page has room for 16 tests below one line of page buttons and for 15 below two lines, which a
		-- fourth page needs, the window's own counted. A button is as wide as its label plus a margin, three to a line.
		local fit = #Debug.pages + 1 <= 3 and 16 or 15
		assert(#page.tests <= fit, "the page " .. page.key .. " lists " .. #page.tests .. " tests, " .. fit .. " fit")
		assert(#page.label <= 6, "the label of the page " .. page.key .. " has " .. #page.label .. " letters, 6 fit")
		for _, test in ipairs(page.tests) do
			assert(type(test.key) == "string" and type(test.label) == "string" and type(test.run) == "function",
				"a listed test lacks its key, label or function")
			assert(test.key ~= "custom" and not byKey[test.key], "two tests share the key " .. test.key)
			byKey[test.key] = test
		end
	end
	assert(#Debug.pages == 2 and Debug.pages[1].key == "game" and Debug.pages[2].key == "addon",
		"the listed pages are not game and addon")
	assert(byKey.sources and Debug.pages[1].tests[1] == byKey.sources, "the test of the sources is not listed first on the page game")

	-- When a design is chosen whose window is built with the listed tests.
	Slash()
	saved.optionsDesign = "listed"
	Slash()
	window = assert(Window(), "no window opened with the listed tests")

	-- Then the window opens on the first page, with a checkbox for the first test.
	assert(window.testCheckboxes.sources:IsVisible(), "a window without the page chosen before opened on none of its pages")
end

-- The display service of the addon, shaped like the real one: a method called through its table, as
-- the animation engine's DisplayEvent calls it, which the tests of the page addon watch.
local Display = { calls = 0, areas = { Notification = {}, Outgoing = {} }, isModDisabled = false, service = {} }
-- The checks of the service's config as the real one answers them: the addon's switch, the current profile
-- and the scroll areas by their key.
Display.service.config = {
	defaultArea = "Notification",
	isModDisabled = function() return Display.isModDisabled end,
	getProfile = function() return MikSBT.Profiles.currentProfile end,
	scrollAreas = { Resolve = function(_, key) return Display.areas[key] end },
}
function Display.service:DisplayEvent(settings, message, texture, mute, formatArg, ...)
	Display.calls = Display.calls + 1
end
Display.Show = function(...) return Display.service:DisplayEvent(...) end
MikSBT.Display = { Service = Display.service }

-- Rule: the test of the sources records the client's build, each resource gain with the fields of its
-- payload, the first twenty combat log messages and the player's casts, and ends itself after 30 seconds.
do
	-- Given a client that hides a gain's first field and has none for its second and fourth.
	assert(Debug.pages[1].tests[1] and Debug.pages[1].tests[1].key == "sources", "the test of the sources is not listed")
	function GetBuildInfo() return "1.60.1", "70888", "Nov 1 2026", 160001 end
	C_CombatText = { GetCurrentEventInfo = function() return SECRET, nil, "x", nil end }
	Click(window.pageButtons.game)
	now = 300
	Click(window.clearButton)

	-- When the test starts, then it says what its rows mean and names the client's build.
	Tick(window, "sources", true)
	local lines = Lines(window)
	assert(#lines == 3, "the test of the sources began with " .. #lines .. " rows")
	assert(lines[2]:find("0.000 sources rows: GAIN kind, fields", 1, true), "the legend is " .. lines[2])
	assert(lines[3] == "0.000 sources BUILD 1.60.1 70888 Nov 1 2026 160001", "the build is logged as " .. lines[3])

	-- When gains come, with other combat text and combat text of a hidden kind between them.
	now = 301
	Fire("COMBAT_TEXT_UPDATE", "ENERGIZE")
	Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
	Fire("COMBAT_TEXT_UPDATE", SECRET)
	Hide("ENERGIZE")
	Fire("COMBAT_TEXT_UPDATE", "ENERGIZE")
	Hide({})
	Fire("COMBAT_TEXT_UPDATE", "PERIODIC_ENERGIZE")

	-- Then each gain is logged with the number of fields and each field, hidden ones named.
	lines = Lines(window)
	assert(#lines == 5, "gains and other combat text wrote " .. (#lines - 3) .. " rows: " .. table.concat(lines, " | ", 4))
	assert(lines[4] == "1.000 sources GAIN ENERGIZE fields 4 1 <secret> 2 nil 3 x 4 nil", "the gain is logged as " .. lines[4])
	assert(lines[5] == "1.000 sources GAIN PERIODIC_ENERGIZE fields 4 1 <secret> 2 nil 3 x 4 nil", "the periodic gain is logged as " .. lines[5])

	-- When combat log messages come, the first of them with a hidden text and one without arguments.
	Fire("COMBAT_LOG_MESSAGE", SECRET, 1, 2)
	Fire("COMBAT_LOG_MESSAGE")
	for _ = 3, 25 do Fire("COMBAT_LOG_MESSAGE", "text", 1) end

	-- Then the first twenty are logged with their number of arguments and whether the text is hidden.
	lines = Lines(window)
	assert(#lines == 25, "25 combat log messages wrote " .. (#lines - 5) .. " rows")
	assert(lines[6] == "1.000 sources LOG arguments 3 text hidden true", "a hidden text is logged as " .. lines[6])
	assert(lines[7] == "1.000 sources LOG arguments 0 text hidden false", "a message without arguments is logged as " .. lines[7])
	assert(lines[8] == "1.000 sources LOG arguments 2 text hidden false", "a message is logged as " .. lines[8])

	-- When the player casts, and another unit does, then only the player's cast is logged, with its spell id.
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8232)
	Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 1)
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", SECRET)
	lines = Lines(window)
	assert(#lines == 27, "the casts wrote " .. (#lines - 25) .. " rows")
	assert(lines[26] == "1.000 sources CAST spell 8232 context only", "a cast is logged as " .. lines[26])
	assert(lines[27] == "1.000 sources CAST spell <secret> context only", "a cast of a hidden spell is logged as " .. lines[27])

	-- When 29 seconds have passed, the test still runs; at 30 it ends itself with a summary of what it saw.
	RunTimers(29)
	assert(window.testCheckboxes.sources:GetChecked() and Listening(), "the test of the sources ended before 30 seconds")
	RunTimers(30)
	lines = Lines(window)
	assert(not Listening() and not window.testCheckboxes.sources:GetChecked(), "the test of the sources did not end after 30 seconds")
	assert(lines[#lines - 1] == "1.000 sources END gains 2 log messages 25" and lines[#lines] == "1.000 sources stopped",
		"the test of the sources ended with " .. lines[#lines - 1] .. " | " .. lines[#lines])

	-- When the client has no call for the build and the call for the payload of a gain fails, and in
	-- another run lacks that call.
	GetBuildInfo = nil
	C_CombatText = { GetCurrentEventInfo = function() error("no payload") end }
	Click(window.clearButton)
	Tick(window, "sources", true)
	Fire("COMBAT_TEXT_UPDATE", "ENERGIZE")
	Tick(window, "sources", false)
	C_CombatText = nil
	Tick(window, "sources", true)
	Fire("COMBAT_TEXT_UPDATE", "ENERGIZE")

	-- Then the test says so in the place of each, and goes on.
	lines = Lines(window)
	assert(#lines == 10, "without the calls the test of the sources wrote " .. #lines .. " rows")
	assert(lines[3] == "0.000 sources BUILD unavailable", "a missing build call is logged as " .. lines[3])
	assert(lines[4] == "0.000 sources GAIN ENERGIZE payload unavailable", "a failing payload call is logged as " .. lines[4])
	assert(lines[5] == "0.000 sources END gains 1 log messages 0" and lines[10] == "0.000 sources GAIN ENERGIZE payload unavailable",
		"a missing payload call is logged as " .. lines[10])
	Tick(window, "sources", false)
	assert(not Listening(), "the test of the sources left an event registered")
	Click(window.clearButton)
end

-- Rule: the test of the display logs every line handed to the display with its event, scroll area and
-- sticky, what the display does with it, its text and its further arguments, and ends itself after 300
-- rows. The event is found for the settings as the profile has them and for copies that read through to
-- them, from a map that is built once.
do
	-- Given the profile as the addon keeps it: the events as they are in the master profile, and in the
	-- current profile only those that were changed, which read through to the master ones. What the
	-- current profile is asked for an event it did not change is counted: that is what a map costs.
	local reads = 0
	local changed = { scrollArea = "Outgoing" }
	local master = { events = {
		OUTGOING_DAMAGE = { scrollArea = "Outgoing" }, INCOMING_HEAL = { isCrit = true }, NOTIFICATION_BUFF = { alwaysSticky = true },
	} }
	local function Events(own)
		return setmetatable(own, { __index = function(_, name)
			reads = reads + 1
			return master.events[name]
		end })
	end
	local current = { events = Events({ OUTGOING_DAMAGE = changed }) }
	local heal, buff = master.events.INCOMING_HEAL, master.events.NOTIFICATION_BUFF
	MikSBT.Profiles.masterProfile, MikSBT.Profiles.currentProfile = master, current
	assert(Debug.pages[2].tests[1] and Debug.pages[2].tests[1].key == "display", "the test of the display is not listed")
	assert(#Debug.pages[2].tests == 3, "the page addon does not list three tests")
	Click(window.pageButtons.addon)
	now = 400
	Click(window.clearButton)

	-- When the test starts, then it says what its rows mean.
	Tick(window, "display", true)
	local lines = Lines(window)
	assert(#lines == 2 and lines[2]:find("0.000 display rows: LINE event, area, sticky, display", 1, true), "the legend is " .. tostring(lines[2]))

	-- When lines are shown for events the profile changed and for those it did not, and for settings of
	-- a trigger, which the profile does not list.
	now = 401
	Display.Show(changed, "%s hit", 132, nil, SECRET)
	Display.Show(heal, "%s healed", nil, true, "a", "b", HIDDEN)
	Display.Show(buff, "Buff", 135)
	Display.Show({ scrollArea = "Notification" }, SECRET)

	-- Then each is a row with the name of its event, its area, whether it is sticky, that the display shows
	-- it, and what it was given.
	lines = Lines(window)
	assert(#lines == 6, "four lines wrote " .. (#lines - 2) .. " rows")
	assert(lines[3] == "1.000 display LINE OUTGOING_DAMAGE area Outgoing sticky false display shown text %s hit texture 132 mute nil args <secret>",
		"a line is logged as " .. lines[3])
	assert(lines[4] == "1.000 display LINE INCOMING_HEAL area Notification sticky true display shown text %s healed texture nil mute true args a b <secret>",
		"a line of a critical hit is logged as " .. lines[4])
	assert(lines[5] == "1.000 display LINE NOTIFICATION_BUFF area Notification sticky true display shown text Buff texture 135 mute nil args nil",
		"a line of an event that is always sticky is logged as " .. lines[5])
	assert(lines[6] == "1.000 display LINE unknown area Notification sticky false display shown text <secret> texture nil mute nil args nil",
		"a line of settings the profile does not list is logged as " .. lines[6])
	assert(Display.calls == 4, "the display of a line was changed by the test")

	-- Then the map of the events was built once, for the four lines.
	assert(reads == 2, "the current profile was asked " .. reads .. " times for events it did not change")

	-- When critical hits are not sticky in this profile, then such a line is not sticky.
	current.stickyCritsDisabled = true
	Display.Show(heal, "%s healed")
	assert(Lines(window)[7]:find(" sticky false ", 1, true), "a critical hit is sticky although the profile has no sticky crits")
	current.stickyCritsDisabled = nil

	-- When the settings are hidden or are no table, and when the profile is not there to look them up.
	local before = #Lines(window)
	local hidden = { scrollArea = "Outgoing" }
	Hide(hidden)
	Display.Show(hidden, "x")
	Hide({})
	Display.Show(5, "x")
	MikSBT.Profiles.currentProfile = nil
	Display.Show(heal, "x")
	MikSBT.Profiles.currentProfile = current
	lines = Lines(window)
	assert(#lines == before + 3, "settings that cannot be read wrote " .. (#lines - before) .. " rows")
	assert(lines[before + 1] == "1.000 display LINE unavailable area unavailable sticky unavailable display unavailable text x texture nil mute nil args nil",
		"hidden settings are logged as " .. lines[before + 1])
	assert(lines[before + 2] == lines[before + 1], "settings that are no table are logged as " .. lines[before + 2])
	assert(lines[before + 3] == "1.000 display LINE unavailable area Notification sticky true display unavailable text x texture nil mute nil args nil",
		"a line without the profile is logged as " .. lines[before + 3])
	assert(reads == 2, "a line without the profile built the map anew")

	-- When the settings are copies made for one hit, which read through to the event's own table, one,
	-- two and three steps away, and one that is four steps away.
	before = #Lines(window)
	local copy = setmetatable({ amount = 5 }, { __index = changed })
	local copyTwo = setmetatable({}, { __index = copy })
	local copyThree = setmetatable({}, { __index = copyTwo })
	local copyFour = setmetatable({}, { __index = copyThree })
	Display.Show(copy, "one step")
	Display.Show(copyTwo, "two steps")
	Display.Show(copyThree, "three steps")
	Display.Show(copyFour, "four steps")

	-- Then the first three name the event, and the fourth is as unknown as settings of a trigger. All
	-- of them read their area through to the event, and the map was not built again for any of them.
	lines = Lines(window)
	assert(#lines == before + 4, "four copies wrote " .. (#lines - before) .. " rows")
	assert(lines[before + 1] == "1.000 display LINE OUTGOING_DAMAGE area Outgoing sticky false display shown text one step texture nil mute nil args nil",
		"a copy one step away is logged as " .. lines[before + 1])
	assert(lines[before + 2]:find("display LINE OUTGOING_DAMAGE area Outgoing ", 1, true), "a copy two steps away is logged as " .. lines[before + 2])
	assert(lines[before + 3]:find("display LINE OUTGOING_DAMAGE area Outgoing ", 1, true), "a copy three steps away is logged as " .. lines[before + 3])
	assert(lines[before + 4]:find("display LINE unknown area Outgoing ", 1, true), "a copy four steps away is logged as " .. lines[before + 4])
	assert(reads == 2, "copies or lines the map does not know built it anew")

	-- When the settings read through to something that is no table of an event: a function, a metatable that
	-- gets its __index from another one, a metatable without one.
	before = #Lines(window)
	Display.Show(setmetatable({}, { __index = function() end }), "function")
	local lender = setmetatable({}, { __index = { __index = changed } })
	Display.Show(setmetatable({}, lender), "lent")
	Display.Show(setmetatable({}, { __mode = "k" }), "without")
	lines = Lines(window)
	assert(#lines == before + 3 and lines[before + 1]:find("display LINE unknown ", 1, true) and lines[before + 2]:find("display LINE unknown ", 1, true)
		and lines[before + 3]:find("display LINE unknown ", 1, true), "settings that read through to no event table were logged as "
		.. table.concat(lines, " | ", before + 1))

	-- When the profile gets a new table for an event and a line with it comes within the second and a
	-- moment before the second is over, then it is unknown; when the second has passed, then the map is
	-- built anew and it is known.
	local fresh = { isCrit = true }
	rawset(current.events, "INCOMING_HEAL", fresh)
	Display.Show(fresh, "within")
	now = 401.9
	Display.Show(fresh, "almost")
	lines = Lines(window)
	assert(lines[#lines - 1]:find("display LINE unknown area Notification sticky true display shown text within ", 1, true)
		and lines[#lines]:find("display LINE unknown area Notification sticky true display shown text almost ", 1, true),
		"lines with a new table within the second were logged as " .. lines[#lines - 1] .. " | " .. lines[#lines])
	assert(reads == 2, "the map was built anew within the second")
	now = 402
	Display.Show(fresh, "after")
	Display.Show(fresh, "again")
	lines = Lines(window)
	assert(lines[#lines - 1]:find("display LINE INCOMING_HEAL area Notification sticky true display shown text after ", 1, true)
		and lines[#lines]:find("display LINE INCOMING_HEAL ", 1, true), "lines with a new table after the second were logged as "
		.. lines[#lines - 1] .. " | " .. lines[#lines])
	assert(reads == 3, "the map was built " .. (reads - 2) .. " times after the second")

	-- When another profile is current, then the map is built for it at once, and for the one before again
	-- when that comes back.
	local other = { events = Events({ OUTGOING_DAMAGE = { scrollArea = "Other" } }) }
	MikSBT.Profiles.currentProfile = other
	Display.Show(other.events.OUTGOING_DAMAGE, "other profile")
	Display.Show(other.events.OUTGOING_DAMAGE, "other profile again")
	assert(Lines(window)[#Lines(window)]:find("display LINE OUTGOING_DAMAGE area Other ", 1, true),
		"a line of another profile was logged as " .. Lines(window)[#Lines(window)])
	assert(reads == 5, "the map for another profile was built with " .. (reads - 3) .. " reads")
	MikSBT.Profiles.currentProfile = current
	Display.Show(changed, "back")
	assert(Lines(window)[#Lines(window)]:find("display LINE OUTGOING_DAMAGE area Outgoing ", 1, true),
		"a line of the profile that came back was logged as " .. Lines(window)[#Lines(window)])
	assert(reads == 6, "the map for the profile that came back was built with " .. (reads - 5) .. " reads")

	-- When the settings name no area and the display has no default one, then the area reads "default".
	Display.service.config.defaultArea = nil
	Display.Show({}, "no area")
	Display.service.config.defaultArea = "Notification"
	lines = Lines(window)
	assert(lines[#lines]:find("display LINE unknown area default sticky false display dropped: area missing text no area ", 1, true),
		"a line without an area was logged as " .. lines[#lines])

	-- When the display drops lines for several reasons at once, then the first of its checks is told, and
	-- as each reason is lifted the next one.
	local doomed = { disabled = true, scrollArea = "Nowhere", textCategory = "Outgoing" }
	Display.isModDisabled = true
	current.msbtOutgoingDisabled = true
	local function Fate(settings)
		Display.Show(settings, "fate")
		lines = Lines(window)
		return lines[#lines]:match(" sticky %a+ display (.-) text fate ")
	end
	assert(Fate(doomed) == "dropped: event disabled", "a disabled event was logged as " .. tostring(Fate(doomed)))
	doomed.disabled = nil
	assert(Fate(doomed) == "dropped: addon disabled", "a disabled addon was logged as " .. tostring(Fate(doomed)))
	Display.isModDisabled = false
	assert(Fate(doomed) == "dropped: category disabled", "a disabled category was logged as " .. tostring(Fate(doomed)))
	current.msbtOutgoingDisabled = nil
	assert(Fate(doomed) == "dropped: area missing", "a missing area was logged as " .. tostring(Fate(doomed)))
	doomed.scrollArea = "Outgoing"
	Display.areas.Outgoing.disabled = true
	assert(Fate(doomed) == "dropped: area disabled", "a disabled area was logged as " .. tostring(Fate(doomed)))
	Display.areas.Outgoing.disabled = nil
	assert(Fate(doomed) == "shown", "a line that passes every check was logged as " .. tostring(Fate(doomed)))

	-- When a category is not named, then it is the notifications.
	current.msbtNotificationsDisabled = true
	assert(Fate({ scrollArea = "Notification" }) == "dropped: category disabled", "a line of no category was not dropped with the notifications")
	current.msbtNotificationsDisabled = nil

	-- When the test is removed, then it writes how many lines it saw, and later lines write nothing.
	Tick(window, "display", false)
	lines = AllLines(window)
	assert(lines[#lines - 1]:find("display END lines seen " .. Display.calls .. "$") and lines[#lines]:find("display stopped$"),
		"the test of the display ended with " .. lines[#lines - 1])
	Display.Show(changed, "late")
	assert(#AllLines(window) == #lines, "a stopped test of the display wrote a row")

	-- When 305 lines come, then the first 300 are logged, the test says so and ends itself.
	Click(window.clearButton)
	Tick(window, "display", true)
	for index = 1, 305 do Display.Show(changed, "line " .. index) end
	lines = AllLines(window)
	assert(#lines == 305, "305 lines wrote " .. (#lines - 2) .. " rows")
	assert(lines[3]:find(" text line 1 ", 1, true) and lines[302]:find(" text line 300 ", 1, true),
		"the rows are not the first 300 lines")
	assert(lines[303] == "0.000 display limit of 300 rows reached", "the limit is said as " .. lines[303])
	assert(lines[304] == "0.000 display END lines seen 300" and lines[305] == "0.000 display stopped",
		"the test of the display ended with " .. lines[304])
	assert(not window.testCheckboxes.display:GetChecked(), "the test of the display kept its tick after its limit")

	-- When the addon has no display service, then the test says so.
	MikSBT.Display = nil
	Click(window.clearButton)
	Tick(window, "display", true)
	lines = Lines(window)
	assert(lines[3] == "0.000 display function unavailable DisplayEvent", "without the service the test logged " .. tostring(lines[3]))
	Tick(window, "display", false)
	MikSBT.Display = { Service = Display.service }
	Click(window.clearButton)
end

-- Rule: the test of the trace logs and draws each stage of a strike through the addon: what the engine
-- heard, what is shown with the ages of the swing and the log line, what is queued and what is rendered.
do
	-- Given the engine, the presentation, the batcher and the display service as the addon has them, each
	-- a method called through its table, and the engine's reader with the swings and the log lines.
	local Engine, Presentation, Batcher = {}, {}, {}
	function Engine:HandleEvent(event, ...) end
	function Presentation:Out(record) end
	function Batcher:Queue(spellID, amount, isCrit) end
	function Batcher:DisplayRestricted(spellID, amount, isCrit) end
	local Components = { CombatEngine = Engine, CombatPresentation = Presentation, OutgoingBatcher = Batcher }
	local reader = { swingTimes = { { at = 499.8 } }, logLines = {} }
	local engine = { reader = reader }
	MikSBT.Components, MikSBT.CombatEngine = Components, engine
	assert(Debug.pages[2].tests[2].key == "trace", "the test of the trace is not listed")
	local function Row(index) return window.rowFontStrings[index]:GetText() end
	local function Match() Presentation:Out({ event = "damage", amount = SECRET, result = { who = "you" } }) end
	Click(window.pageButtons.addon)
	now = 500
	Click(window.clearButton)

	-- When the test starts, then it says what its rows mean.
	Tick(window, "trace", true)
	local lines = Lines(window)
	assert(#lines == 2 and lines[2]:find("0.000 trace rows: TARGET, CAST, SWING, LOG", 1, true), "the legend is " .. tostring(lines[2]))

	-- When the engine hears a swing, a combat log line and a hit on the target, and a cast, and also
	-- events it is not asked about: another unit's, a hidden action, a hidden unit, a hidden event.
	Engine:HandleEvent("PLAYER_SWING", 2.6, "MAINHAND")
	now = 500.2
	local melee = { at = now, kind = "swing", source = "mine" }
	reader.logLines = { melee }
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	Engine:HandleEvent("UNIT_COMBAT", "player", "WOUND", 0, SECRET, 1)
	Hide("WOUND")
	Engine:HandleEvent("UNIT_COMBAT", "target", "WOUND", 0, SECRET, 1)
	Hide("target")
	Engine:HandleEvent("UNIT_COMBAT", "target", "WOUND", 0, SECRET, 1)
	Hide("UNIT_COMBAT")
	Engine:HandleEvent("UNIT_COMBAT", "target", "WOUND", 0, SECRET, 1)
	Hide({})
	Engine:HandleEvent("UNIT_COMBAT", "target", "WOUND", 0, SECRET, 1)
	Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 1)
	Hide("player")
	Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1)
	Hide({})
	Engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8232)
	Engine:HandleEvent("PLAYER_TARGET_CHANGED")

	-- Then each stage is a row with its number, hidden amounts named, and the same row is drawn with the
	-- amount as the client draws it.
	lines = Lines(window)
	assert(#lines == 6, "the engine's events wrote " .. (#lines - 2) .. " rows: " .. table.concat(lines, " | ", 3))
	assert(lines[3] == "0.000 trace SWING 1 - MAINHAND duration 2.6", "a swing is logged as " .. lines[3])
	assert(lines[4] == "0.200 trace LOG 2 - swing mine", "a log line is logged as " .. lines[4])
	assert(lines[5] == "0.200 trace TARGET 3 hit - <secret> school 1 flag 0", "a hit on the target is logged as " .. lines[5])
	assert(lines[6] == "0.200 trace CAST 4 succeeded 8232", "a cast is logged as " .. lines[6])
	assert(Row(1) == "001 SWING - MAINHAND duration 2.6 " and Row(2) == "002 LOG - swing mine "
		and Row(3) == "003 TARGET hit - <drawn> school 1 flag 0 " and Row(4) == "004 CAST succeeded 8232 ",
		"the stages were drawn as " .. Row(1) .. "|" .. Row(2) .. "|" .. Row(3) .. "|" .. Row(4))

	-- When a log line is hidden, or is not of this frame, then it is no stage.
	local before = #lines
	Hide(melee)
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	Hide({})
	now = 500.25
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	assert(#Lines(window) == before, "a hidden log line or one of another frame wrote a row")

	-- When a strike is shown, then its row names who and how, the amount, and the ages in seconds of
	-- the native swing, the tracked swing and the log line of a melee swing, with its state.
	now = 500.7
	Match()
	lines = Lines(window)
	assert(lines[#lines] == "0.700 trace MATCH 5 you - <secret> ages 0.70 0.90 0.50 free", "a match is logged as " .. lines[#lines])
	assert(Row(5) == "005 MATCH you - <drawn> ages 0.70 0.90 0.50 free ", "a match was drawn as " .. Row(5))

	-- When further log lines come, then only a melee swing of the player or an unknown source is the
	-- one the ages follow: the line of a spell and the swing of another source are not.
	now = 500.8
	reader.logLines = { { at = now, kind = "spell", source = "mine" } }
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	now = 501.3
	Match()
	lines = Lines(window)
	assert(lines[#lines]:find(" ages 1.30 1.50 1.10 free", 1, true),
		"the line of a spell was taken for a melee swing: " .. lines[#lines])
	now = 501.4
	reader.logLines = { { at = now, kind = "swing", source = "other" } }
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	now = 501.9
	Match()
	lines = Lines(window)
	assert(lines[#lines]:find(" ages 1.90 2.10 1.70 free", 1, true), "the swing of another source was taken: " .. lines[#lines])
	now = 502
	local missed = { at = now, kind = "swingMiss", source = "unknown" }
	reader.logLines = { missed }
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	now = 502.5
	Match()
	lines = Lines(window)
	assert(lines[#lines]:find(" ages 2.50 2.70 0.50 free", 1, true), "a missed swing of an unknown source was not taken: " .. lines[#lines])
	missed.claimed = true
	Match()
	lines = Lines(window)
	assert(lines[#lines]:find(" ages 2.50 2.70 0.50 used", 1, true), "a used line is named " .. lines[#lines])
	assert(#lines == 14, "the strikes and log lines wrote " .. (#lines - 6) .. " rows")

	-- When strikes come of other shapes, then they are named as the addon names them: a proc with its
	-- spell, an extra strike, a miss by the pet's melee with the miss's word, one without a result or
	-- with none that is a table.
	Presentation:Out({ event = "damage", amount = SECRET, result = { who = "you", spell = 8232, proc = true } })
	Presentation:Out({ event = "damage", amount = 7, result = { who = "you", spell = 1, extra = true } })
	Presentation:Out({ event = "miss", missWord = SECRET, result = { who = "pet", melee = true } })
	Presentation:Out({ event = "damage", amount = 5, result = 5 })
	Presentation:Out({ event = "damage", amount = 5 })
	lines = Lines(window)
	assert(#lines == 19, "the shapes of strikes wrote " .. (#lines - 14) .. " rows")
	assert(lines[15]:find("trace MATCH 13 you proc 8232 <secret> ages ", 1, true), "a proc is logged as " .. lines[15])
	assert(lines[16]:find("trace MATCH 14 you extra 1 7 ages ", 1, true), "an extra strike is logged as " .. lines[16])
	assert(lines[17]:find("trace MISS 15 pet auto <secret> ages ", 1, true), "a miss is logged as " .. lines[17])
	assert(lines[18]:find("trace MATCH 16 unknown - 5 ages ", 1, true), "a strike with a result that is no table is logged as " .. lines[18])
	assert(lines[19]:find("trace MATCH 17 unknown - 5 ages ", 1, true), "a strike without a result is logged as " .. lines[19])

	-- When other things reach the presentation, or the client hides them or what they hold.
	Presentation:Out({ event = "heal", amount = 5 })
	Presentation:Out(5)
	local hiddenRecord = { event = "damage", amount = 5, result = { who = "you" } }
	Hide(hiddenRecord)
	Presentation:Out(hiddenRecord)
	Hide("damage")
	Presentation:Out({ event = "damage", amount = 5, result = { who = "you" } })
	assert(#Lines(window) == 19, "other things than strikes wrote a row, or a failure")
	Hide("you")
	Presentation:Out({ event = "damage", amount = 5, result = { who = "you" } })
	Hide(false)
	Presentation:Out({ event = "damage", amount = 5, result = { who = "you", spell = false } })
	local hiddenResult = { who = "you", spell = 1 }
	Hide(hiddenResult)
	Presentation:Out({ event = "damage", amount = 5, result = hiddenResult })
	Hide({})
	lines = Lines(window)
	assert(#lines == 22, "hidden things wrote " .. (#lines - 19) .. " rows")
	assert(lines[20]:find("trace MATCH 18 unknown - 5 ages ", 1, true), "a hidden who is logged as " .. lines[20])
	assert(lines[21]:find("trace MATCH 19 you <secret> 5 ages ", 1, true), "a hidden spell is logged as " .. lines[21])
	assert(lines[22]:find("trace MATCH 20 unknown - 5 ages ", 1, true), "a hidden result is logged as " .. lines[22])

	-- When an amount is queued, one is kept for the client to draw, and a line is sent to the screen.
	Batcher:Queue(8232, SECRET, false)
	Batcher:DisplayRestricted(8232, SECRET, false)
	Display.Show({}, "%s hit", 132, nil, SECRET)
	Display.Show({}, "plain")
	lines = Lines(window)
	assert(#lines == 26, "the batcher and the display wrote " .. (#lines - 22) .. " rows")
	assert(lines[23] == "2.500 trace BATCH 21 - 8232 <secret>", "a queued amount is logged as " .. lines[23])
	assert(lines[24]:find("trace OPAQUE 22 - 8232 <secret>", 1, true), "an opaque amount is logged as " .. lines[24])
	assert(lines[25]:find("trace RENDER 23 - - %s hit <secret>", 1, true), "a rendered line is logged as " .. lines[25])
	assert(lines[26]:find("trace RENDER 24 - - plain nil", 1, true), "a rendered plain line is logged as " .. lines[26])
	assert(Row(7) == "021 BATCH - 8232 <drawn> " and Row(8) == "022 OPAQUE - 8232 <drawn> ", "the amounts were drawn as " .. Row(7) .. "|" .. Row(8))

	-- Then the stages go round the rows of the window: the 15th is drawn in the first row again.
	assert(Row(1):find("^015 MISS pet auto <drawn> ages ") and Row(10) == "024 RENDER - - plain nil " and Row(11):find("^011 MATCH ")
		and Row(14):find("^014 MATCH "), "the stages did not go round the rows: " .. Row(1) .. "|" .. Row(10) .. "|" .. Row(11) .. "|" .. Row(14))
	assert(Row(9) == "023 RENDER - - %s hit <drawn> ", "a rendered line was drawn as " .. Row(9))

	-- When stages come while the window is closed, then the log says once that they are not drawn.
	Slash()
	Batcher:Queue(1, 1)
	Batcher:Queue(2, 2)
	Slash()
	lines = Lines(window)
	assert(#lines == 29 and lines[27]:find("trace BATCH 25 ", 1, true) and lines[28] == "2.500 trace stage not drawn, the window is closed"
		and lines[29]:find("trace BATCH 26 ", 1, true), "stages with the window closed wrote " .. table.concat(lines, " | ", 27))
	local drawn = Row(11)

	-- When the test is removed, then it says how many stages it saw, and later calls write and draw nothing.
	Tick(window, "trace", false)
	lines = Lines(window)
	assert(lines[#lines - 1] == "2.500 trace END stages seen 26 logged 26", "the test of the trace ended with " .. lines[#lines - 1])
	Batcher:Queue(3, 3)
	Presentation:Out({ event = "damage", amount = 5 })
	Display.Show({}, "late")
	assert(#Lines(window) == #lines and Row(11) == drawn, "a stopped test of the trace wrote or drew")

	-- When the engine is not there to look up, then a strike has no ages and its line is missing.
	MikSBT.CombatEngine = nil
	Click(window.clearButton)
	Tick(window, "trace", true)
	Engine:HandleEvent("COMBAT_LOG_MESSAGE", "text")
	Match()
	lines = Lines(window)
	assert(#lines == 3 and lines[3]:find(" ages -1.00 -1.00 -1.00 missing", 1, true),
		"without the engine a strike is logged as " .. table.concat(lines, " | ", 3))
	Tick(window, "trace", false)
	MikSBT.CombatEngine = engine

	-- When 305 stages come, then the first 300 are logged and the log says so, while the drawing goes on.
	Click(window.clearButton)
	Tick(window, "trace", true)
	for index = 1, 305 do Batcher:Queue(index, index) end
	Tick(window, "trace", false)
	lines = AllLines(window)
	assert(#lines == 305, "305 stages wrote " .. (#lines - 2) .. " rows")
	assert(lines[3]:find("trace BATCH 1 - 1 1", 1, true) and lines[302]:find("trace BATCH 300 - 300 300", 1, true),
		"the rows are not the first 300 stages")
	assert(lines[303] == "0.000 trace limit of 300 rows reached, the stages are only drawn from here on",
		"the limit is said as " .. lines[303])
	assert(lines[304] == "0.000 trace END stages seen 305 logged 300", "the test of the trace ended with " .. lines[304])
	assert(Row(11) == "305 BATCH - 305 305 " and Row(12):find("^292 BATCH "), "the drawing did not go on after the limit: " .. Row(11) .. "|" .. Row(12))

	-- When the time of the tracked swing is hidden, then it counts as none.
	reader.swingTimes = { { at = 499.8 } }
	Click(window.clearButton)
	Tick(window, "trace", true)
	Hide(499.8)
	Match()
	Hide({})
	lines = Lines(window)
	assert(#lines == 3 and lines[3]:find(" ages -1.00 -1.00 -1.00 missing", 1, true),
		"with a hidden time of the swing a strike is logged as " .. table.concat(lines, " | ", 3))
	Tick(window, "trace", false)

	-- When strikes without a result come, then none of them makes a table of its own: with the collector
	-- stopped, the memory they take is that of strikes that have a result.
	Click(window.clearButton)
	Tick(window, "trace", true)
	local withResult = { event = "damage", amount = 5, result = { who = "unknown" } }
	local withoutResult = { event = "damage", amount = 5, result = 5 }
	for _ = 1, 400 do Presentation:Out(withResult) end
	collectgarbage("collect")
	collectgarbage("stop")
	-- The numbered rows intern new strings, and the table of strings doubles now and then, which would fall
	-- into one run of strikes only. It is grown beyond that first, with the collector stopped.
	for index = 1, 400000 do local _ = "grow" .. index end
	local start = collectgarbage("count")
	for _ = 1, 4000 do Presentation:Out(withResult) end
	local middle = collectgarbage("count")
	for _ = 1, 4000 do Presentation:Out(withoutResult) end
	local finish = collectgarbage("count")
	collectgarbage("restart")
	assert(finish - middle - (middle - start) < 40, "4000 strikes without a result took "
		.. math.floor(finish - middle - (middle - start)) .. " KB more than strikes with one")
	Tick(window, "trace", false)

	-- When the addon lacks what the test watches, then it says so for each and goes on.
	MikSBT.Components, MikSBT.Display = nil, nil
	Click(window.clearButton)
	Tick(window, "trace", true)
	lines = Lines(window)
	assert(#lines == 7, "without the addon's tables the test of the trace wrote " .. #lines .. " rows")
	assert(lines[3] == "0.000 trace function unavailable HandleEvent" and lines[4] == "0.000 trace function unavailable Out"
		and lines[5] == "0.000 trace function unavailable Queue" and lines[6] == "0.000 trace function unavailable DisplayRestricted"
		and lines[7] == "0.000 trace function unavailable DisplayEvent", "the missing functions are logged as " .. table.concat(lines, " | ", 3))
	Tick(window, "trace", false)
	MikSBT.Components, MikSBT.Display = Components, { Service = Display.service }
	Click(window.clearButton)
end

-- Rule: the test of the Windfury capture starts the capture the addon has, logs its report line by line
-- when the capture shows it, which it does when it pauses itself, and ends itself; the capture is stopped
-- however the test ends, and the test waits on no timer.
do
	-- Given the capture as the addon has it, with its model that tells the report; it starts as a client
	-- of the Forever combat reader would let it, and it shows its report as it does when it pauses
	-- itself, after it has stopped.
	local Capture = { active = false, starts = 0, stops = 0, reports = 0, refuses = false }
	function Capture:Start()
		self.starts = self.starts + 1
		self.model = { ReportText = function() return "report line one\nreport line two\n\nreport line three" end }
		self.active = not self.refuses
	end
	function Capture:Stop()
		self.active = false
		self.stops = self.stops + 1
	end
	function Capture:ShowReport() self.reports = self.reports + 1 end
	function Capture:Pause()
		self:Stop()
		self:ShowReport()
	end
	assert(Debug.pages[2].tests[3].key == "windfury", "the test of the Windfury capture is not listed")
	Click(window.pageButtons.addon)
	now = 600
	Click(window.clearButton)

	-- When the capture is not loaded, or its model is not, then the test names the files to add to the
	-- manifest, starts nothing and ends itself.
	MikSBT.WindfuryCapture, MikSBT.WindfuryTraceModel = nil, {}
	Tick(window, "windfury", true)
	local lines = Lines(window)
	assert(#lines == 3 and lines[2]:find("windfury capture not loaded: add Combat\\WindfuryTrace.lua and Combat\\WindfuryCapture.lua", 1, true)
		and lines[2]:find("restart the game client", 1, true) and lines[3] == "0.000 windfury stopped",
		"without the capture the test logged " .. table.concat(lines, " | ", 2))
	MikSBT.WindfuryCapture, MikSBT.WindfuryTraceModel = Capture, nil
	Click(window.clearButton)
	Tick(window, "windfury", true)
	lines = Lines(window)
	assert(Capture.starts == 0 and lines[2]:find("capture not loaded", 1, true) and lines[3] == "0.000 windfury stopped",
		"without the model the test started the capture or logged " .. table.concat(lines, " | ", 2))
	assert(not window.testCheckboxes.windfury:GetChecked(), "the test kept its tick although it ended itself")
	MikSBT.WindfuryTraceModel = {}

	-- When the capture is loaded, then the test starts it once and says so, and waits on no timer.
	Click(window.clearButton)
	Lines(window)
	local waiting = #timers
	Tick(window, "windfury", true)
	lines = Lines(window)
	assert(Capture.starts == 1 and Capture.active and #lines == 2 and lines[2]:find("0.000 windfury capture started", 1, true),
		"the test started the capture " .. Capture.starts .. " times and logged " .. table.concat(lines, " | ", 2))
	assert(#timers == waiting, "the test of the Windfury capture waits on a timer")

	-- When time passes while the capture runs, then nothing is written and it is not stopped.
	for _ = 1, 3 do RunTimers(1) end
	assert(#Lines(window) == 2 and Capture.active and Capture.stops == 0 and window.testCheckboxes.windfury:GetChecked(),
		"the test of the Windfury capture did something while the capture ran")

	-- When the capture pauses itself and shows its report, then the test logs it line by line, without
	-- the empty one, and ends itself.
	Capture:Pause()
	lines = Lines(window)
	assert(#lines == 7, "the report wrote " .. (#lines - 2) .. " rows: " .. table.concat(lines, " | ", 3))
	assert(lines[3] == "0.000 windfury capture paused, its report follows" and lines[4] == "0.000 windfury REPORT report line one"
		and lines[5] == "0.000 windfury REPORT report line two" and lines[6] == "0.000 windfury REPORT report line three"
		and lines[7] == "0.000 windfury stopped", "the report is logged as " .. table.concat(lines, " | ", 3))
	assert(not window.testCheckboxes.windfury:GetChecked() and Capture.stops >= 1 and not Capture.active,
		"the test did not end itself after the report")
	assert(Hooked("ShowReport") == 1, "the report was hooked " .. Hooked("ShowReport") .. " times")
	Capture:ShowReport()
	assert(#Lines(window) == 7, "the test went on after it ended")

	-- When the report is asked for while the capture runs, then the test logs it as well, ends itself and
	-- stops the capture.
	Click(window.clearButton)
	Tick(window, "windfury", true)
	local stops = Capture.stops
	Capture:ShowReport()
	lines = Lines(window)
	assert(#lines == 7 and lines[3] == "0.000 windfury capture paused, its report follows" and lines[7] == "0.000 windfury stopped",
		"a report asked for was logged as " .. table.concat(lines, " | ", 3))
	assert(not Capture.active and Capture.stops == stops + 1, "the capture was not stopped after a report asked for")

	-- When the test is removed while the capture runs, then the capture is stopped and no report is written.
	Click(window.clearButton)
	Tick(window, "windfury", true)
	assert(Capture.active, "the capture was not started again")
	stops = Capture.stops
	Tick(window, "windfury", false)
	lines = Lines(window)
	assert(not Capture.active and Capture.stops == stops + 1, "removing the tick did not stop the capture")
	assert(#lines == 3 and lines[3] == "0.000 windfury stopped", "removing the tick wrote " .. table.concat(lines, " | ", 3))
	Capture:ShowReport()
	assert(#Lines(window) == 3, "a test that was removed went on watching the capture")

	-- When the capture refuses to start, then the test says so and ends itself, stopping what it asked for.
	Capture.refuses = true
	Click(window.clearButton)
	stops = Capture.stops
	Tick(window, "windfury", true)
	lines = Lines(window)
	assert(#lines == 3 and lines[2] == "0.000 windfury capture did not start, see the chat" and lines[3] == "0.000 windfury stopped"
		and Capture.stops == stops + 1 and not window.testCheckboxes.windfury:GetChecked(),
		"a capture that does not start was logged as " .. table.concat(lines, " | ", 2))
	Capture.refuses = false

	-- When the report cannot be put together, then the test says so and ends itself.
	Click(window.clearButton)
	Tick(window, "windfury", true)
	Capture.model = nil
	Capture:Pause()
	lines = Lines(window)
	assert(#lines == 4 and lines[3]:find("windfury report not built ", 1, true) and lines[4] == "0.000 windfury stopped"
		and not window.testCheckboxes.windfury:GetChecked(), "a report that cannot be built was logged as " .. table.concat(lines, " | ", 2))
	MikSBT.WindfuryCapture, MikSBT.WindfuryTraceModel = nil, nil
	Click(window.clearButton)
end

-- Rule: a design that is saved as the choice but is not there gets no window of its own: the window asks the
-- designs which one is chosen, and they answer with the classic one then.
do
	-- Given the classic window, closed again, and a saved choice that names a design that is not registered.
	local chosen = saved.optionsDesign
	if Window() then Slash() end
	saved.optionsDesign = nil
	Slash()
	local classic = assert(Window(), "the classic window did not open")
	Slash()
	saved.optionsDesign = "gone"
	local frameCount = #frames

	-- When the command runs, then the classic window opens and nothing is built.
	local isOpened = pcall(Slash)
	assert(isOpened and Window() == classic and #frames == frameCount, "a design that is saved but not there got a window of its own")
	Slash()
	saved.optionsDesign = chosen
end

-- Rule: without the registry of designs there is the classic window alone, which opens, closes and runs a test.
do
	-- Given the window's file is loaded where the options have no designs, with a page of one test; and the
	-- window of the other loading is closed.
	if Window() then Slash() end
	local Designs, Command, Module = MSBTOptions.Designs, SlashCmdList.MSBTDEBUG, MSBTOptions.Debug
	local function Windows()
		local count = 0
		for _, frame in ipairs(frames) do
			if frame.logEditbox then count = count + 1 end
		end
		return count
	end
	local function Skins()
		local count = 0
		for _, times in pairs(skinned) do count = count + times end
		return count
	end
	local windowsBefore, skinsBefore, watchedBefore = Windows(), Skins(), Hooked("Select")
	MSBTOptions.Designs = nil
	dofile("Diagnostics/DebugWindow.lua")
	MSBTOptions.Debug.pages = { { key = "alone", label = "Alone", tests = {
		{ key = "echo", label = "Echo", run = function(t) t:Log("heard") end },
	} } }

	-- When the command runs, then one window opens in the classic look, anchored like the classic window of
	-- the designs, and no skin ran.
	Slash()
	local lone = assert(Window(), "no window opened without designs")
	assert(Windows() == windowsBefore + 1 and lone.hasArtwork, "the window without designs was not built once in the classic look")
	assert(lone.content.point[5] == -30 and lone.content.pointCalls == 1, "the content frame without designs is not 30 below the corner, once")
	assert(Skins() == skinsBefore and Hooked("Select") == watchedBefore, "a design was watched or a skin ran without designs")

	-- When the command runs again, then the window closes, and a third time it shows the same window.
	Slash()
	assert(Window() == nil, "the command did not close the window without designs")
	Slash()
	assert(Window() == lone and Windows() == windowsBefore + 1, "the command built another window without designs")

	-- When a test is started from its checkbox, then it logs as it always does.
	Tick(lone, "echo", true)
	local lines = Lines(lone)
	assert(lines[#lines]:find("echo heard$"), "a test started without designs logged " .. tostring(lines[#lines]))

	-- Then the world is put back for what comes after.
	Tick(lone, "echo", false)
	Slash()
	MSBTOptions.Designs, SlashCmdList.MSBTDEBUG, MSBTOptions.Debug = Designs, Command, Module
end

print("Debug window tests passed")
