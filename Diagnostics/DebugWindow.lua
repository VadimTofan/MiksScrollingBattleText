-- Opt-in development tool. Excluded from release manifests and packages; docs/debug/AGENTS.md
-- says how to switch it on.
local module = {}
local moduleName = "Debug"
MSBTOptions[moduleName] = module



-- The debug window, opened with /msbtdebug. It offers the tests listed in DebugTests.lua page by
-- page and a page of its own for a test pasted in, runs them on request and logs what they record
-- into a field the text can be selected and copied from. Nothing is built, no event is heard and
-- no function is watched until the window is asked for and a test is started.
local MSBTControls = MSBTOptions.Controls
-- Where the options come in designs, the window takes the look of the chosen one. Without them this
-- is nil and there is the classic window alone.
local MSBTDesigns = MSBTOptions.Designs
local RestrictedValue = MikSBT.API.RestrictedValue

-- The log keeps this many rows and drops the oldest beyond that.
local MAX_ROWS = 1000
-- Of the errors one run causes the first ones are logged and the rest are counted, so that a
-- callback that fails at every call of a function in a fight does not flood the log.
local MAX_ERRORS = 5
-- While tests write, the screen follows with this many of the newest rows, at most this often in
-- seconds. Select all shows every row.
local LIVE_ROWS = 100
local REFRESH_DELAY = 0.5
-- A recording keeps at most this many rows of the log, and the row that reaches the number ends it.
local MAX_RECORDED_ROWS = 10000
-- The saved settings keep this many recordings and drop the oldest beyond that.
local MAX_RECORDINGS = 3
-- What the button for the recording says, and the red marker in front of the count while it runs.
local RECORD_LABEL, STOP_RECORD_LABEL = "Record", "Stop recording"
local RECORDING_MARKER = "|cffff4040Recording|r - "
-- The names of the dialogs that ask before a recording starts and offer a reload when it has stopped.
local START_POPUP, SAVE_POPUP = "MSBT_DEBUG_RECORD_START", "MSBT_DEBUG_RECORD_SAVE"
-- The pasted test has a page of its own after the listed ones, and its key marks its rows.
local CUSTOM_KEY = "custom"
local CUSTOM_LABEL = "custom test"
local CUSTOM_PAGE = { key = CUSTOM_KEY, label = "Custom" }
local WINDOW_WIDTH, WINDOW_HEIGHT = 880, 560
-- The left column holds the pages and their tests, the right side the log and what tests draw.
local LEFT_X, LEFT_WIDTH = 30, 280
local RIGHT_X = 330
local RIGHT_WIDTH = WINDOW_WIDTH - RIGHT_X - 30
-- Below the title.
local TOP_Y, BOTTOM_Y = -48, 30
-- The picture in the corner of the classic look reaches further down than the title, so the content
-- hangs this much lower.
local PICTURE_DROP = 30
-- The buttons of the pages stand in slots, this many to a line. A label of one short word fits.
local PAGE_SLOT_WIDTH, PAGES_PER_LINE, PAGE_LINE_HEIGHT = 94, 3, 28
local CHECKBOX_SPACING = 26
-- A label stands this far above the top of the box it names.
local LABEL_GAP = 16
-- What tests draw stands at the bottom of the right side: this many rows of one line each, and
-- the free text of t:Show, which begins where the first row does.
local DRAWN_ROWS, ROW_HEIGHT = 14, 14
local DRAWN_TOP = BOTTOM_Y + DRAWN_ROWS * ROW_HEIGHT
-- The log ends above its row of buttons, which stands on the line of the buttons that end the left
-- column. While something is drawn, it ends above the drawing area instead.
local LOG_BOTTOM_Y = BOTTOM_Y + 28
local LOG_BOTTOM_DRAWN_Y = DRAWN_TOP + 36
local AREA_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local rows = {}
-- When the log began: with its first row, or when it was last cleared.
local logStart
-- The runs of the tests that are started, by test key.
local running = {}
-- The frame that hears a test's events, by test key; kept for the test's next run.
local listeners = {}
-- The runs that watch a function of the addon, by the function's owner and name. Each function
-- gets one dispatcher the first time a test watches it, which stays for the session and passes a
-- call on to the runs that watch the function at that moment.
local watchers = {}
-- The debug window of each look, by the key of the design chosen for the options, and the one that
-- is open.
local windows = {}
local shownWindow
local isRefreshQueued
-- Whether the choice of a design is watched, which begins when the window is first asked for, where
-- there are designs.
local isWatching
-- The page the window shows, the same in every look's window; without a choice the first one.
local chosenPage
-- Whether something is drawn, so that the log leaves room for the drawing area. Like the page, it is
-- the same in every look's window and not saved.
local isDrawn = false
-- The running recording, nil while there is none: the rows written since it began with the moment of
-- each, the keys of the tests that ran, and what the stop needs to save it. Like the log it is the
-- same for every look's window.
local recording
-- The frame that hears the game while a recording runs, built when the first one starts.
local recorder
-- Defined with the recording, below the pages; the log and the window's button reach them from above.
local StopRecording, ToggleRecording


-- Lets the log end where the state of the drawing says. Only a change of that state anchors anew,
-- and only the log's panel: its row of buttons stands under it, and the window keeps its own places.
local function FitLog(window)
	if window.hasRoom == isDrawn then return end
	window.hasRoom = isDrawn
	window.logPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -30, isDrawn and LOG_BOTTOM_DRAWN_Y or LOG_BOTTOM_Y)
end



-- A value as text for the log. Values the client hides and protected texts are named, never copied.
local function Describe(value)
	if RestrictedValue:IsRestricted(value) then return "<secret>" end
	local kind = type(value)
	if kind == "string" then
		if value:find("|K", 1, true) then return "<protected-text>" end
		return (value:gsub("[\r\n]", " "))
	end
	if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(value) end
	return kind
end


-- Shows the log in the open window: its newest rows, or all of them for copying. The text is left
-- alone while it has the keyboard, so that a selection stays; it catches up when the field lets go.
local function Refresh(isFull)
	isRefreshQueued = nil
	local window = shownWindow
	if not window or not window:IsShown() or window.logEditbox:HasFocus() then return end
	local first = isFull and 1 or math.max(1, #rows - LIVE_ROWS + 1)
	local text = table.concat(rows, "\n", first)
	local editbox = window.logEditbox
	editbox.shownText = text
	editbox:SetText(text)
	editbox:SetCursorPosition(#text)
	window.countFontString:SetText((recording and RECORDING_MARKER or "") .. (first == 1 and #rows .. " rows"
		or #rows .. " rows, the newest " .. LIVE_ROWS .. " shown"))
end


local function QueueRefresh()
	if isRefreshQueued or not shownWindow or not shownWindow:IsShown() then return end
	isRefreshQueued = true
	C_Timer.After(REFRESH_DELAY, function() Refresh() end)
end


-- The moment in seconds with fractions, as the client keeps it for the combat log's clock.
local function Precise()
	if GetTimePreciseSec then return GetTimePreciseSec() end
	return GetTime()
end


-- Writes a row to the log and, while a recording runs, to the recording as well. The row that brings
-- the recording to its limit ends it, and the rows its end writes are kept beyond the limit.
local function Log(key, ...)
	logStart = logStart or GetTime()
	local parts = { string.format("%.3f", GetTime() - logStart), key }
	for index = 1, select("#", ...) do
		parts[#parts + 1] = Describe((select(index, ...)))
	end
	local row = table.concat(parts, " ")
	if #rows == MAX_ROWS then table.remove(rows, 1) end
	rows[#rows + 1] = row
	local current = recording
	if current then
		current.rows[#current.rows + 1] = row
		current.times[#current.times + 1] = Precise()
	end
	QueueRefresh()
	if current and #current.rows >= MAX_RECORDED_ROWS and not (current.isLimited or current.isEnding) then
		current.isLimited, current.truncated = true, true
		Log("record", "limit reached", MAX_RECORDED_ROWS)
		StopRecording("limit")
	end
end


local function ClearRows(window)
	for _, fontString in ipairs(window.rowFontStrings) do fontString:SetText("") end
end


local function ClearLog()
	rows = {}
	logStart = GetTime()
	isDrawn = false
	if shownWindow then
		shownWindow.logEditbox:ClearFocus()
		shownWindow.drawnFontString:SetText("")
		ClearRows(shownWindow)
		FitLog(shownWindow)
	end
	Refresh()
end


-- The window tests draw into: the open one, none while it is closed.
local function DrawingWindow()
	local window = shownWindow
	if window and window:IsShown() then return window end
end


-- The format that draws this many values, kept once it is built.
local formats = {}


-- A boolean the client hides cannot go through %s, which takes only strings and numbers. The
-- client's own call turns it into a hidden 1 or 0; a client without that call gets it named.
local function HiddenBoolean(value)
	local evaluate = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
	if not evaluate then return "<hidden boolean>" end
	return evaluate(value, 1, 0)
end


-- Hands values to a font string, a space after each. A value the client hides goes in as it is,
-- for the client to draw, a hidden boolean as a hidden 1 or 0; any other value that is no string
-- goes in as its text.
local function Draw(fontString, ...)
	local count = select("#", ...)
	local values = { ... }
	for index = 1, count do
		local value = values[index]
		if RestrictedValue:IsRestricted(value) then
			if type(value) == "boolean" then values[index] = HiddenBoolean(value) end
		elseif type(value) ~= "string" then
			values[index] = tostring(value)
		end
	end
	local format = formats[count]
	if not format then
		format = string.rep("%s ", count)
		formats[count] = format
	end
	fontString:SetFormattedText(format, unpack(values, 1, count))
end



-- What a test gets as t: the recorder of one run.
local Run = {}
Run.__index = Run


-- Runs a part of the test. An error is logged and the test goes on; beyond the first few of a run
-- the errors are only counted, and the stop of the test says how many there were.
function Run:Call(callback, ...)
	local isOk, message = pcall(callback, ...)
	if isOk then return end
	self.errors = self.errors + 1
	if self.errors <= MAX_ERRORS then self:Log("error", message) end
end


-- Hears a game event until the test stops; with a unit, only for that unit. The handler gets the
-- event's arguments.
function Run:On(event, handler, unit)
	if not self.isActive then return end
	local listener = self.listener
	local register = unit and listener.RegisterUnitEvent or listener.RegisterEvent
	if not pcall(register, listener, event, unit) then
		self:Log("event unavailable", event)
		return
	end
	self.handlers[event] = handler
end


-- Writes a row: the time since the log began, the test's key and the values.
function Run:Log(...)
	Log(self.key, ...)
end


-- A timer that does nothing once the test has stopped.
function Run:After(seconds, callback)
	C_Timer.After(seconds, function()
		if self.isActive then self:Call(callback) end
	end)
end


-- Whether the client hides a value from addons. A table counts as hidden as well when the client
-- keeps its content out of reach.
function Run:IsSecret(value)
	return RestrictedValue:IsRestricted(value)
		or type(value) == "table" and not RestrictedValue:CanAccessTable(value)
end


-- Watches a function of the addon until the test stops: after every call of owner[name] the
-- callback gets the call's arguments. The function, what it returns and what it does stay as
-- they are, and a call that no test watches costs the dispatcher a look at an empty table. Only
-- a function the table holds itself is watched: one reached through a metatable would get the
-- dispatcher on the object itself and shadow the method of its class for good.
function Run:Watch(owner, name, callback)
	if not self.isActive then return end
	if type(owner) ~= "table" or type(rawget(owner, name)) ~= "function" then
		self:Log("function unavailable", name)
		return
	end
	local byName = watchers[owner]
	if not byName then
		byName = {}
		watchers[owner] = byName
	end
	local watching = byName[name]
	if not watching then
		watching = {}
		byName[name] = watching
		hooksecurefunc(owner, name, function(...)
			for run, watch in pairs(watching) do run:Call(watch, ...) end
		end)
	end
	watching[self] = callback
	self.watched[watching] = true
end


-- Runs a callback once when the test stops, whatever stops it, before the row that says so.
-- Several run in the order they were given.
function Run:OnStop(callback)
	self.stopCallbacks[#self.stopCallbacks + 1] = callback
end


-- Draws values into the open window instead of logging them, and says whether it did. There the
-- client shows what it hides from addons, for a look or a screenshot. Each call replaces what
-- was drawn before, the rows included. The first call that has values makes room for the drawing
-- area.
function Run:Show(...)
	local window = DrawingWindow()
	if not window then return false end
	ClearRows(window)
	Draw(window.drawnFontString, ...)
	if select("#", ...) > 0 then
		isDrawn = true
		FitLog(window)
	end
	return true
end


-- Draws values into one row of the open window and says whether it did; the other rows stay as
-- they are, and what t:Show drew goes.
function Run:Row(index, ...)
	local window = DrawingWindow()
	local fontString = window and window.rowFontStrings[index]
	if not fontString then return false end
	window.drawnFontString:SetText("")
	Draw(fontString, ...)
	if select("#", ...) > 0 then
		isDrawn = true
		FitLog(window)
	end
	return true
end


local function Listener(key)
	local listener = listeners[key]
	if not listener then
		listener = CreateFrame("Frame")
		listener:SetScript("OnEvent", function(this, event, ...)
			local run = running[key]
			local handler = run and run.handlers[event]
			if handler then run:Call(handler, ...) end
		end)
		listeners[key] = listener
	end
	return listener
end


-- Ends a run: its events, timers and watches end first, then its callbacks for the stop run.
local function StopTest(key)
	local run = running[key]
	if not run then return end
	run.isActive = false
	run.listener:UnregisterAllEvents()
	running[key] = nil
	for watching in pairs(run.watched) do watching[run] = nil end
	for _, callback in ipairs(run.stopCallbacks) do run:Call(callback) end
	if run.errors > MAX_ERRORS then Log(key, "errors", run.errors, "the first " .. MAX_ERRORS .. " are logged") end
	Log(key, "stopped")
end


-- Ends the test from within, as removing its tick does, and takes the tick away. A recorder kept
-- beyond its run stops nothing; a later run of the same test goes on.
function Run:Stop()
	if running[self.key] ~= self then return end
	StopTest(self.key)
	local checkbox = shownWindow and shownWindow.testCheckboxes[self.key]
	if checkbox then checkbox:SetChecked(false) end
end


-- Starts a test anew: body is the function that gets the run's recorder, which knows how many rows
-- the window has to draw into.
local function StartTest(key, label, body)
	StopTest(key)
	local run = setmetatable({ key = key, handlers = {}, listener = Listener(key), watched = {}, stopCallbacks = {},
		isActive = true, errors = 0, rows = DRAWN_ROWS }, Run)
	running[key] = run
	if recording and not recording.seen[key] then
		recording.seen[key] = true
		recording.tests[#recording.tests + 1] = key
	end
	Log(key, "started", label)
	run:Call(body, run)
end


-- A pasted test is the body of a function that has the recorder as t. The code starts on the
-- first line, so that an error names the line as pasted.
local function StartCustomTest(code)
	local body, message = loadstring("local t = ... " .. code, CUSTOM_LABEL)
	if not body then
		Log(CUSTOM_KEY, "error", message)
		return
	end
	StartTest(CUSTOM_KEY, CUSTOM_LABEL, body)
end



-- A bordered box of the given width with a scrolling field of several lines, as the dialog for
-- copying a profile has. A field that only shows undoes what is typed into it.
local function CreateTextArea(window, boxWidth, isReadOnly)
	local panel = CreateFrame("Frame", nil, window, BackdropTemplateMixin and "BackdropTemplate")
	panel:SetBackdrop(AREA_BACKDROP)
	panel:SetBackdropColor(0.02, 0.02, 0.02, 1)
	panel:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -12)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local editbox = CreateFrame("EditBox", nil, scroll)
	editbox:SetMultiLine(true)
	editbox:SetAutoFocus(false)
	editbox:SetFontObject(ChatFontNormal)
	editbox:SetWidth(boxWidth - 44)
	editbox:SetHeight(40)
	editbox:SetMaxLetters(0)
	editbox:SetScript("OnEscapePressed", editbox.ClearFocus)
	editbox:SetScript("OnTextChanged", function(this, isUserInput)
		if isReadOnly and isUserInput and this:GetText() ~= this.shownText then
			this:SetText(this.shownText or "")
			this:HighlightText()
		end
		scroll:UpdateScrollChildRect()
	end)
	-- The view follows the cursor, so the newest row and what is typed stay in sight.
	editbox:SetScript("OnCursorChanged", function(this, x, y, width, height)
		local cursor = -y
		local offset = scroll:GetVerticalScroll()
		if cursor < offset then
			scroll:SetVerticalScroll(cursor)
		elseif cursor + height > offset + scroll:GetHeight() then
			scroll:SetVerticalScroll(cursor + height - scroll:GetHeight())
		end
	end)
	scroll:SetScrollChild(editbox)
	-- A click anywhere in the box reaches the field, also below its last line.
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() editbox:SetFocus() end)
	return panel, editbox
end


local function CreateLabel(window, text, x, y)
	local fontString = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fontString:SetPoint("TOPLEFT", window.content, "TOPLEFT", x, y)
	fontString:SetText(text)
	return fontString
end


local function CreateButton(window, label, tooltip, handler)
	local button = MSBTControls.CreateOptionButton(window)
	button:Configure(24, label, tooltip)
	button:SetClickHandler(handler)
	return button
end


-- The window in the classic look, built like the popups of the options: the same artwork and
-- controls, so that a design's skin finds what it knows. The pages are added by BuildPages.
local function CreateWindow()
	local window = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
	window:Hide()
	window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	MSBTOptions.Popups.CreateMenuArtwork(window, 256)
	-- What is placed from the top below the title hangs on this frame, which stands lower by the picture
	-- in the corner. A design whose look has no such picture puts the frame back at the corner of the
	-- window. What is placed from the bottom stays on the window.
	window.content = CreateFrame("Frame", nil, window)
	window.content:SetSize(1, 1)
	window.content:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -PICTURE_DROP)
	window:SetScript("OnDragStart", function(this) this:StartMoving() end)
	-- Where the window is dragged to is kept with the saved settings, for every design and for
	-- the time after a reload.
	window:SetScript("OnDragStop", function(this)
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		if x and y then MikSBT.Profiles.savedVariables.debugWindowPosition = { x, y } end
	end)
	-- A design's skin may give the window a placing of its own; this stays the frame's own.
	window.SetOwnPoint = window.SetPoint

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", window, "TOP", 0, -18)
	title:SetText("MSBT Debug")
	-- The window stays open on Escape, which a fight needs for other things; the command and
	-- this button close it.
	local headerClose = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	headerClose:SetPoint("TOPRIGHT", window, "TOPRIGHT", -7, -12)
	headerClose:SetScript("OnClick", function() window:Hide() end)
	window.testCheckboxes = {}

	local logPanel, logEditbox = CreateTextArea(window, RIGHT_WIDTH, true)
	-- BuildPages places the panel and its label, once it knows where the content of the left
	-- column begins.
	window.logPanel = logPanel
	logEditbox:SetScript("OnEditFocusLost", QueueRefresh)
	-- Copying lets go of the keyboard, so that the keys reach the game again and the log goes on.
	if logEditbox:HasScript("OnKeyUp") then
		logEditbox:SetScript("OnKeyUp", function(this, key)
			if key == "C" and IsControlKeyDown() then this:ClearFocus() end
		end)
	end
	window.logEditbox = logEditbox

	window.selectButton = CreateButton(window, "Select all",
		"Shows the whole log and selects it. Copy it with Ctrl+C.", function()
		logEditbox:ClearFocus()
		Refresh(true)
		logEditbox:SetFocus()
		logEditbox:HighlightText()
	end)
	window.selectButton:SetPoint("TOPLEFT", logPanel, "BOTTOMLEFT", 0, -4)
	window.clearButton = CreateButton(window, "Clear", "Empties the log and what tests drew.", ClearLog)
	window.clearButton:SetPoint("LEFT", window.selectButton, "RIGHT", 8, 0)
	window.recordButton = CreateButton(window, RECORD_LABEL,
		"Records the log together with the game's combat log until it is stopped. Asks first, and says where"
		.. " the recording is kept.", ToggleRecording)
	window.recordButton:SetPoint("LEFT", window.clearButton, "RIGHT", 8, 0)
	-- The count takes the room right of the record button up to the right edge of the log, level with the
	-- middle of the buttons, which stand 4 below the log. While a recording runs, the button is wider and
	-- the count longer: a count too long for its room goes on to a second line instead of out of the window.
	window.countFontString = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	window.countFontString:SetPoint("LEFT", window.recordButton, "RIGHT", 12, 0)
	window.countFontString:SetPoint("RIGHT", logPanel, "BOTTOMRIGHT", 0, -4 - window.recordButton:GetHeight() / 2)
	window.countFontString:SetJustifyH("LEFT")

	-- What tests draw stands below the log: the rows from the top down, each cut to one line, and
	-- the free text in the same place, which grows downward.
	window.rowFontStrings = {}
	for index = 1, DRAWN_ROWS do
		local fontString = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fontString:SetPoint("TOPLEFT", window, "BOTTOMLEFT", RIGHT_X, DRAWN_TOP - (index - 1) * ROW_HEIGHT)
		fontString:SetSize(RIGHT_WIDTH, ROW_HEIGHT)
		fontString:SetJustifyH("LEFT")
		fontString:SetWordWrap(false)
		window.rowFontStrings[index] = fontString
	end
	window.drawnFontString = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	window.drawnFontString:SetPoint("TOPLEFT", window, "BOTTOMLEFT", RIGHT_X, DRAWN_TOP)
	window.drawnFontString:SetWidth(RIGHT_WIDTH)
	window.drawnFontString:SetJustifyH("LEFT")
	window.drawnFontString:SetJustifyV("TOP")
	return window
end


-- Shows the controls of the chosen page and hides those of the others. The chosen page's button
-- is disabled, which marks it in the look of every design, and a window that lacks the page
-- chosen shows its first one.
local function ShowPage(window)
	local chosen = window.pageControls[chosenPage] and chosenPage or window.firstPage
	for key, controls in pairs(window.pageControls) do
		local isChosen = key == chosen
		for _, control in ipairs(controls) do control:SetShown(isChosen) end
		if isChosen then window.pageButtons[key]:Disable() else window.pageButtons[key]:Enable() end
	end
end


-- Builds a button for every listed page and for the window's own, and the controls of every page:
-- a checkbox per test, and on the window's own page the field for a pasted test. All of it is
-- built at once, so that a design's skin finds it; a change of page only shows and hides it.
local function BuildPages(window)
	local pages = {}
	for _, page in ipairs(module.pages or {}) do pages[#pages + 1] = page end
	pages[#pages + 1] = CUSTOM_PAGE
	window.firstPage = pages[1].key
	window.pageButtons, window.pageControls = {}, {}
	-- The controls of a page begin below the last line of page buttons.
	local top = TOP_Y - math.ceil(#pages / PAGES_PER_LINE) * PAGE_LINE_HEIGHT - 4
	-- The log's label stands level with them and its panel level with the field for a pasted
	-- test, so that both boxes begin on one line. The panel ends as the state of the drawing says.
	CreateLabel(window, "Log", RIGHT_X, top)
	window.logPanel:SetPoint("TOPLEFT", window.content, "TOPLEFT", RIGHT_X, top - LABEL_GAP)
	FitLog(window)
	for index, page in ipairs(pages) do
		local button = CreateButton(window, page.label, nil, function()
			-- Leaving the page of the pasted test takes the keyboard from its field.
			window.customEditbox:ClearFocus()
			chosenPage = page.key
			ShowPage(window)
		end)
		button:SetPoint("TOPLEFT", window.content, "TOPLEFT", LEFT_X + (index - 1) % PAGES_PER_LINE * PAGE_SLOT_WIDTH,
			TOP_Y - math.floor((index - 1) / PAGES_PER_LINE) * PAGE_LINE_HEIGHT)
		window.pageButtons[page.key] = button
		local controls = {}
		for row, test in ipairs(page.tests or {}) do
			local checkbox = MSBTControls.CreateCheckbox(window)
			checkbox:Configure(24, test.label, test.tooltip)
			checkbox:SetPoint("TOPLEFT", window.content, "TOPLEFT", LEFT_X, top - (row - 1) * CHECKBOX_SPACING)
			checkbox:SetClickHandler(function(this, isChecked)
				if isChecked then StartTest(test.key, test.label, test.run) else StopTest(test.key) end
			end)
			window.testCheckboxes[test.key] = checkbox
			controls[#controls + 1] = checkbox
		end
		window.pageControls[page.key] = controls
	end

	local customLabel = CreateLabel(window, "Paste a test's code. Its recorder is t.", LEFT_X, top)
	local customPanel, customEditbox = CreateTextArea(window, LEFT_WIDTH)
	customPanel:SetPoint("TOPLEFT", window.content, "TOPLEFT", LEFT_X, top - LABEL_GAP)
	customPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", LEFT_X + LEFT_WIDTH, BOTTOM_Y + 28)
	window.customEditbox = customEditbox

	window.runButton = CreateButton(window, "Run", "Runs the pasted test.", function()
		customEditbox:ClearFocus()
		StartCustomTest(customEditbox:GetText())
	end)
	window.runButton:SetPoint("TOPLEFT", customPanel, "BOTTOMLEFT", 0, -4)
	window.stopButton = CreateButton(window, "Stop", "Stops the pasted test.", function()
		StopTest(CUSTOM_KEY)
	end)
	window.stopButton:SetPoint("LEFT", window.runButton, "RIGHT", 8, 0)
	window.pageControls[CUSTOM_KEY] = { customLabel, customPanel, window.runButton, window.stopButton }
end


-- Shows which tests run, also those started or stopped while another design's window was open.
local function UpdateTests(window)
	for key, checkbox in pairs(window.testCheckboxes) do
		checkbox:SetChecked(running[key] ~= nil)
	end
end


-- Shows in a window whether a recording runs, as the button's label; the count of rows carries the
-- marker in Refresh.
local function ShowRecordState(window)
	window.recordButton:SetLabel(recording and STOP_RECORD_LABEL or RECORD_LABEL)
end


-- A change of the state shows in the open window at once.
local function UpdateRecordState()
	if shownWindow then ShowRecordState(shownWindow) end
	Refresh()
end


-- A moment on the game's clock as the combat log writes the time of day: hours, minutes, seconds
-- and thousandths. wall is the moment in seconds since the epoch, with fractions.
local function WallText(wall)
	local whole = math.floor(wall)
	return date("%H:%M:%S", whole) .. string.format(".%03d", math.floor((wall - whole) * 1000))
end


-- time() counts whole seconds, so the frame in which it steps is the one in which a second began.
-- That gives the difference between the wall clock and the game's clock, accurate to one frame, which
-- places every row of the recording on the combat log's clock.
local function AlignClock()
	local current = recording
	local second = time()
	if not current or second == current.second then return end
	current.clockOffset = second - Precise()
	recorder:SetScript("OnUpdate", nil)
end


-- The frame that hears the game while a recording runs, built once.
local function Recorder()
	if not recorder then
		recorder = CreateFrame("Frame")
		recorder:SetScript("OnEvent", function(this, event, ...)
			if event == "PLAYER_LOGOUT" then
				StopRecording("logout")
			else
				Log("record", "logging changed", ...)
			end
		end)
	end
	return recorder
end


-- Begins a recording: the combat log is switched on, the clock is aligned, and every running test starts
-- anew so that its start is in the recording. Rows written before are not kept.
local function StartRecording()
	if recording then return end
	local current = { rows = {}, times = {}, tests = {}, seen = {}, startedAt = Precise(), date = date("%m/%d/%Y"),
		second = time(), combatLog = "unavailable" }
	recording = current
	local isLogging = type(LoggingCombat) == "function"
	if isLogging then current.combatLog = LoggingCombat() and "already on" or "switched on" end
	Log("record", "started", "combat log " .. current.combatLog)
	local hearing = Recorder()
	for _, event in ipairs({ "CHAT_LOGGING_CHANGED", "PLAYER_LOGOUT" }) do
		if not pcall(hearing.RegisterEvent, hearing, event) then Log("record", "event unavailable", event) end
	end
	hearing:SetScript("OnUpdate", AlignClock)
	-- The game logs the fight only while the combat log is on, and the stop switches it off. It writes the file
	-- in blocks: the last one can come minutes after the stop, since neither the stop nor a reload writes it.
	if isLogging then LoggingCombat(true) end
	if C_ChatInfo and C_ChatInfo.IsLoggingCombat then
		Log("record", "combat log state", C_ChatInfo.IsLoggingCombat())
	end
	for _, page in ipairs(module.pages or {}) do
		for _, test in ipairs(page.tests or {}) do
			if running[test.key] then StartTest(test.key, test.label, test.run) end
		end
	end
	if running[CUSTOM_KEY] then
		StartCustomTest(shownWindow and shownWindow.customEditbox:GetText() or "")
	end
	UpdateRecordState()
end


-- Asks before a recording starts, since it starts the tests anew and switches the combat log on.
local function ShowStartPopup()
	if not StaticPopupDialogs[START_POPUP] then
		StaticPopupDialogs[START_POPUP] = {
			-- The client wraps the text only between words, and a word wider than the dialog cuts the rest
			-- off, so the places of the files are named in short words.
			text = "Record the log together with the game's combat log?\n\nThe ticked tests start anew, and tests"
				.. " ticked while it records are recorded from their start. The combat log is switched on now and"
				.. " switched off when the recording stops.\n\nThe game writes the recording to disk only when the"
				.. " interface reloads or on logout: into the saved variables of MikScrollingBattleText, in the folders"
				.. " WTF, your account, SavedVariables. The combat log goes to the folder Logs, into a WoWCombatLog file."
				.. " A reload is offered when the recording stops. At most "
				.. MAX_RECORDINGS .. " recordings are kept, the oldest goes.",
			button1 = "Start",
			button2 = "Cancel",
			OnAccept = StartRecording,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show(START_POPUP)
end


-- Says that the recording is saved and that the game writes it to disk only later, and offers the reload.
local function ShowSavePopup(entry)
	if not StaticPopupDialogs[SAVE_POPUP] then
		StaticPopupDialogs[SAVE_POPUP] = {
			text = "%s",
			button1 = "Reload now",
			button2 = "Later",
			OnAccept = function()
				local reload = ReloadUI or (C_UI and C_UI.Reload)
				if reload then reload() end
			end,
			OnCancel = function() Log("record", "kept until the next reload or logout") end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show(SAVE_POPUP, string.format("Recording kept: %d rows, from %s to %s on %s.\n\nThe game writes it to"
		.. " disk only when the interface reloads or on logout. Reload now?", #entry.rows, entry.started,
		entry.stopped, entry.date))
end


-- Ends the recording that runs, whichever way it ends: the tests stop, the combat log is switched off, and
-- the recording is saved with the settings. Anything but a logout then offers the reload that makes the
-- game write the settings to disk.
function StopRecording(reason)
	local current = recording
	if not current or current.isEnding then return end
	current.isEnding = true
	for _, key in ipairs(current.tests) do StopTest(key) end
	if shownWindow then UpdateTests(shownWindow) end
	if type(LoggingCombat) == "function" then LoggingCombat(false) end
	Log("record", "stopped", reason, #current.rows + 1)
	recorder:UnregisterAllEvents()
	recorder:SetScript("OnUpdate", nil)

	local offset, clock = current.clockOffset, "exact"
	if not offset then offset, clock = time() - Precise(), "approximate" end
	local texts = {}
	for index, row in ipairs(current.rows) do
		texts[index] = WallText(offset + current.times[index]) .. " " .. row
	end
	local version, buildNumber = GetBuildInfo()
	local guid = UnitGUID("player")
	local entry = {
		date = current.date,
		started = WallText(offset + current.startedAt),
		stopped = WallText(offset + Precise()),
		clock = clock,
		build = tostring(version) .. " " .. tostring(buildNumber),
		player = not RestrictedValue:IsRestricted(guid) and guid or nil,
		combatLog = current.combatLog,
		reason = reason,
		truncated = current.truncated,
		tests = current.tests,
		rows = texts,
	}
	recording = nil
	UpdateRecordState()

	local savedVariables = MikSBT.Profiles.savedVariables
	local kept = savedVariables.debugRecordings
	if not kept then
		kept = {}
		savedVariables.debugRecordings = kept
	end
	kept[#kept + 1] = entry
	while #kept > MAX_RECORDINGS do
		local dropped = table.remove(kept, 1)
		Log("record", "dropped the oldest recording", dropped.date, dropped.started)
	end
	if reason ~= "logout" then ShowSavePopup(entry) end
end


-- The button of the window: a click asks before it starts a recording, and ends the one that runs.
function ToggleRecording()
	if recording then StopRecording("stopped") else ShowStartPopup() end
end


-- Puts the window where it was last dragged to. Without that it stays where it was built.
local function Place(window)
	local position = MikSBT.Profiles.savedVariables.debugWindowPosition
	if not position then return end
	window:ClearAllPoints()
	window:SetOwnPoint("CENTER", UIParent, "BOTTOMLEFT", position[1], position[2])
end


-- The design chosen for the options names the window to show.
local function WindowKey()
	return MSBTDesigns and MSBTDesigns.GetSelected() or "classic"
end


-- Opens the window in the look of the design chosen for the options, the classic look without designs.
-- A design with a SkinPopup gets its window handed over once, complete with its pages, as it gets
-- each of its popups.
local function Open()
	local key = WindowKey()
	local window = windows[key]
	if not window then
		window = CreateWindow()
		-- Kept before the pages and the skin are added, so that a failure there builds no further window.
		windows[key] = window
		BuildPages(window)
		local skin = MSBTDesigns and MSBTDesigns.designs[key].SkinPopup
		if skin then skin(window) end
	end
	if shownWindow and shownWindow ~= window then shownWindow:Hide() end
	shownWindow = window
	Place(window)
	UpdateTests(window)
	ShowRecordState(window)
	ShowPage(window)
	FitLog(window)
	window:Show()
	window:Raise()
	Refresh()
end


-- A design chosen while the window is open takes the window over at once. Where there are no designs
-- nothing calls this.
local function Follow()
	if shownWindow and shownWindow:IsShown() and windows[WindowKey()] ~= shownWindow then
		Open()
	end
end


-- Opens the window, or closes it when it is open. Where there are designs, the choice of one is
-- watched from the first time the window is asked for.
local function Toggle()
	local window = windows[WindowKey()]
	if window and window:IsShown() then
		window:Hide()
		return
	end
	if MSBTDesigns and not isWatching then
		isWatching = true
		hooksecurefunc(MSBTDesigns, "Select", Follow)
	end
	Open()
end



SLASH_MSBTDEBUG1 = "/msbtdebug"
SlashCmdList.MSBTDEBUG = Toggle




module.Toggle = Toggle
