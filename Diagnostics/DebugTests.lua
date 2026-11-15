-- Opt-in development tool. Excluded from release manifests and packages.
-- The tests the debug window (/msbtdebug) offers, page by page. A page has a key, a label of one
-- short word and its list of tests. A test is an entry of such a list: a key unique over all
-- pages, a label, a tooltip if it needs one, and a function that gets the recorder of its run as t.
--   t:On(event, handler, unit)    hears a game event until the test stops, with a unit only for
--                                 that unit; the handler gets the event's arguments
--   t:Watch(owner, name, callback) after every call of owner[name] until the test stops, the
--                                 callback gets the call's arguments; the function stays as it is,
--                                 and owner has to hold it itself, not reach it through a metatable
--   t:Log(...)                    writes a row; values the client hides are named, never copied
--   t:After(seconds, callback)    a timer that does nothing once the test has stopped
--   t:OnStop(callback)            runs once when the test stops, whatever stops it
--   t:Stop()                      ends the test, as removing its tick does
--   t:IsSecret(value)             whether the client hides a value from addons, or the content of
--                                 a table
--   t:Show(...)                   draws values into the window instead of logging them and says
--                                 whether it did; there the client shows what it hides, for a look
--                                 or a screenshot
--   t:Row(index, ...)             draws values into one row of the window and says whether it did
--   t.rows                        how many rows the window has for t:Row
-- A new test is a new entry in this file, so that /reload loads it. The same code runs when it is
-- pasted into the window's own page. How to write one and what to watch for: docs/debug/AGENTS.md.

-- Tests that hear the game: its events and what its calls return.
local game = { key = "game", label = "Game" }
-- Tests that watch the addon's own functions with t:Watch.
local addon = { key = "addon", label = "Addon" }
MSBTOptions.Debug.pages = { game, addon }

game.tests = {
	{
		key = "sources",
		label = "Sources: gains and log messages",
		tooltip = "For 30 seconds logs the client's build, each resource gain from the combat text with the fields of"
			.. " its payload, the first 20 combat log messages by their number of arguments and whether their"
			.. " text is hidden, and the player's own casts with their spell id as context.",
		run = function(t)
			-- The test ends itself after this many seconds.
			local DURATION = 30
			-- Of the combat log messages only the first ones are described, the rest are counted.
			local FIRST_MESSAGES = 20
			-- The kinds of combat text that are a resource gain.
			local GAINS = { ENERGIZE = true, PERIODIC_ENERGIZE = true }
			local getGain = C_CombatText and C_CombatText.GetCurrentEventInfo
			local getBuild = GetBuildInfo
			local gains, messages = 0, 0

			local function Pack(...) return { n = select("#", ...), ... } end

			t:Log("rows: GAIN kind, fields, then the number and value of each field; LOG arguments and"
				.. " whether the text is hidden; CAST spell id, as context only")
			if getBuild then t:Log("BUILD", getBuild()) else t:Log("BUILD", "unavailable") end
			t:On("COMBAT_TEXT_UPDATE", function(kind)
				if t:IsSecret(kind) or not GAINS[kind] then return end
				gains = gains + 1
				-- A client that lacks the call fails here as well.
				local payload = Pack(pcall(getGain))
				if not payload[1] then
					t:Log("GAIN", kind, "payload unavailable")
					return
				end
				-- The first value of the payload is the call's own success.
				local row, count = { kind, "fields", payload.n - 1 }, 3
				for index = 2, payload.n do
					row[count + 1], row[count + 2] = index - 1, payload[index]
					count = count + 2
				end
				t:Log("GAIN", unpack(row, 1, count))
			end)
			t:On("COMBAT_LOG_MESSAGE", function(...)
				messages = messages + 1
				if messages > FIRST_MESSAGES then return end
				local text = ...
				t:Log("LOG", "arguments", select("#", ...), "text hidden", t:IsSecret(text))
			end)
			t:On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
				t:Log("CAST", "spell", spellID, "context only")
			end, "player")
			t:After(DURATION, function() t:Stop() end)
			t:OnStop(function() t:Log("END", "gains", gains, "log messages", messages) end)
		end,
	},
}

addon.tests = {
	{
		key = "display",
		label = "Display: every line handed to the display",
		tooltip = "Watches MikSBT.Display.Service:DisplayEvent, through which the events reach the screen, and logs"
			.. " every line handed to it, shown or not: per line the event, scroll area, whether it is sticky, whether"
			.. " the display takes the line or why it drops it, the text or template and the further arguments."
			.. " Ends itself after 300 rows.",
		run = function(t)
			-- A fight shows many lines: this many rows are logged, then the test ends itself.
			local MAX_LINES = 300
			-- The settings of a line may be a copy that reads through to the event's own table, and that
			-- one through another: this many steps are followed.
			local MAX_CLIMB = 3
			-- The map of the events is built again for a line it does not know at most this often, in seconds.
			local REBUILD_DELAY = 1
			local lines = 0
			local service = MikSBT.Display and MikSBT.Display.Service
			-- The events by their settings table, built from the names of the master profile and the
			-- tables the current profile gives for them, and the profile and the moment it was built for.
			local names, builtFor, builtAt

			local function Build(profile, events, master)
				names, builtFor, builtAt = {}, profile, GetTime()
				for name in pairs(master) do
					local own = events[name]
					if type(own) == "table" then names[own] = name end
				end
			end
			-- The name of the table, or of the table it reads through: a copy made for one hit has
			-- the event's settings as its __index. The metatable of a profile has a function there,
			-- which ends the climb.
			local function Find(settings)
				for _ = 0, MAX_CLIMB do
					local name = names[settings]
					if name then return name end
					local metatable = getmetatable(settings)
					local parent = type(metatable) == "table" and rawget(metatable, "__index")
					if type(parent) ~= "table" then return end
					settings = parent
				end
			end
			-- The name of the event whose settings these are, as the profile lists them. A line the
			-- caller shows with settings of its own, a trigger for instance, has none. The map is built
			-- on the first line, for another current profile, and for a line it does not know once a
			-- second has passed.
			local function EventName(settings)
				local profiles = MikSBT.Profiles
				local profile = profiles.currentProfile
				local events = profile and profile.events
				local master = profiles.masterProfile and profiles.masterProfile.events
				if type(events) ~= "table" or type(master) ~= "table" then return "unavailable" end
				if profile ~= builtFor then Build(profile, events, master) end
				local name = Find(settings)
				if not name and GetTime() - builtAt >= REBUILD_DELAY then
					Build(profile, events, master)
					name = Find(settings)
				end
				return name or "unknown"
			end
			-- What the display does with a line: "shown", or the first reason it drops it, in the order
			-- of the checks at the top of DisplayService:DisplayEvent. Reads only; the config calls it makes
			-- change nothing.
			local function Fate(settings)
				local config = service.config
				if settings.disabled then return "dropped: event disabled" end
				if config.isModDisabled() then return "dropped: addon disabled" end
				local category = settings.textCategory or "Notifications"
				if config.getProfile()["msbt" .. category .. "Disabled"] then return "dropped: category disabled" end
				local area = config.scrollAreas:Resolve(settings.scrollArea or config.defaultArea)
				if not area then return "dropped: area missing" end
				if area.disabled then return "dropped: area disabled" end
				return "shown"
			end

			t:Log("rows: LINE event, area, sticky, display (shown, or why the display drops it), text or template,"
				.. " texture, mute, then the further arguments")
			t:Watch(service, "DisplayEvent", function(_, settings, message, texture, mute, formatArg, ...)
				lines = lines + 1
				local name, area, isSticky, fate = "unavailable", "unavailable", "unavailable", "unavailable"
				if type(settings) == "table" and not t:IsSecret(settings) then
					name = EventName(settings)
					area = settings.scrollArea or service.config.defaultArea or "default"
					local profile = MikSBT.Profiles.currentProfile or {}
					isSticky = settings.alwaysSticky or settings.isCrit and not profile.stickyCritsDisabled
					isSticky = isSticky and true or false
					local isOk, result = pcall(Fate, settings)
					if isOk then fate = result end
				end
				t:Log("LINE", name, "area", area, "sticky", isSticky, "display", fate, "text", message, "texture", texture,
					"mute", mute, "args", formatArg, ...)
				if lines == MAX_LINES then
					t:Log("limit of " .. MAX_LINES .. " rows reached")
					t:Stop()
				end
			end)
			t:OnStop(function() t:Log("END", "lines seen", lines) end)
		end,
	},
	{
		key = "trace",
		label = "Trace: a strike through the addon",
		tooltip = "Watches CombatEngine:HandleEvent, CombatPresentation:Out, OutgoingBatcher:Queue and"
			.. " :DisplayRestricted and Display.Service:DisplayEvent, as /msbttrace does. Logs each stage, and"
			.. " draws it into the rows of this window with the amount as the client draws it.",
		run = function(t)
			-- The first rows of a run are logged; after that the stages only go round the rows the
			-- window draws into.
			local MAX_ROWS = 300
			-- A result that is none stands for an empty one.
			local NO_RESULT = {}
			local components = MikSBT.Components or {}
			local sequence, logged = 0, 0
			local lastSwingAt, lastMeleeLine
			local isNoted

			-- A value of the addon's own that the client may hide: nil when it does.
			local function Plain(value)
				if not t:IsSecret(value) then return value end
			end
			-- A stage: a row in the log, and the same row drawn in its place. The client draws what it hides.
			local function Stage(tag, detail, spell, ...)
				sequence = sequence + 1
				if logged < MAX_ROWS then
					logged = logged + 1
					t:Log(tag, sequence, detail, spell, ...)
				elseif logged == MAX_ROWS then
					logged = logged + 1
					t:Log("limit of " .. MAX_ROWS .. " rows reached, the stages are only drawn from here on")
				end
				local isDrawn = t:Row((sequence - 1) % t.rows + 1, string.format("%03d", sequence), tag, detail, spell, ...)
				if not isDrawn and not isNoted then
					isNoted = true
					t:Log("stage not drawn, the window is closed")
				end
			end
			-- The age in seconds of a moment, or -1 where there is none.
			local function Age(at)
				local moment = Plain(at)
				if type(moment) ~= "number" then return "-1.00" end
				return string.format("%.2f", GetTime() - moment)
			end

			t:Log("rows: TARGET, CAST, SWING, LOG what the engine heard; MATCH, MISS what is shown, then amount and the"
				.. " ages in seconds of the native swing, the tracked swing and the log line, -1 for none; BATCH,"
				.. " OPAQUE the amount queued; RENDER the line sent to the screen")
			t:Watch(components.CombatEngine, "HandleEvent", function(_, event, unit, action, flag, amount, school)
				if t:IsSecret(event) then return end
				if event == "UNIT_COMBAT" then
					if t:IsSecret(unit) or unit ~= "target" or t:IsSecret(action) then return end
					Stage("TARGET", action == "WOUND" and "hit" or action, "-", amount, "school", school, "flag", flag)
				elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
					if t:IsSecret(unit) or unit ~= "player" then return end
					Stage("CAST", "succeeded", flag)
				elseif event == "PLAYER_SWING" then
					lastSwingAt = GetTime()
					Stage("SWING", "-", action, "duration", unit)
				elseif event == "COMBAT_LOG_MESSAGE" then
					local engine = MikSBT.CombatEngine
					local lines = engine and engine.reader and engine.reader.logLines
					local line = lines and lines[#lines]
					if not line or t:IsSecret(line) or line.at ~= GetTime() then return end
					local kind, source = Plain(line.kind), Plain(line.source)
					if (kind == "swing" or kind == "swingMiss") and (source == "mine" or source == "unknown") then
						lastMeleeLine = line
					end
					Stage("LOG", "-", kind, source)
				end
			end)
			t:Watch(components.CombatPresentation, "Out", function(_, record)
				if type(record) ~= "table" or t:IsSecret(record) then return end
				local event = Plain(record.event)
				if event ~= "damage" and event ~= "miss" then return end
				local result = record.result
				if type(result) ~= "table" or t:IsSecret(result) then result = NO_RESULT end
				local spell = result.spell
				if not t:IsSecret(spell) and not spell then spell = Plain(result.melee) and "auto" or "-" end
				local engine = MikSBT.CombatEngine
				local swings = engine and engine.reader and engine.reader.swingTimes
				local swing = swings and swings[#swings]
				local line = lastMeleeLine
				local state = "missing"
				if line then state = Plain(line.claimed) and "used" or "free" end
				local detail = (Plain(result.who) or "unknown")
					.. (Plain(result.extra) and " extra" or Plain(result.proc) and " proc" or "")
				local value = record.amount
				if event == "miss" then value = record.missWord end
				Stage(event == "miss" and "MISS" or "MATCH", detail, spell, value, "ages",
					Age(lastSwingAt), Age(swing and swing.at), Age(line and line.at), state)
			end)
			t:Watch(components.OutgoingBatcher, "Queue", function(_, spell, amount)
				Stage("BATCH", "-", spell, amount)
			end)
			t:Watch(components.OutgoingBatcher, "DisplayRestricted", function(_, spell, amount)
				Stage("OPAQUE", "-", spell, amount)
			end)
			t:Watch(MikSBT.Display and MikSBT.Display.Service, "DisplayEvent",
				function(_, _, message, _, _, formatArg, ...)
					Stage("RENDER", "-", "-", message, formatArg, ...)
				end)
			t:OnStop(function() t:Log("END", "stages seen", sequence, "logged", math.min(logged, MAX_ROWS)) end)
		end,
	},
	{
		key = "windfury",
		label = "Windfury: capture and report",
		tooltip = "Starts the addon's own Windfury capture (MikSBT.WindfuryCapture, Combat\\WindfuryCapture.lua)"
			.. " and, when the capture pauses itself, logs its report (its model's ReportText) and ends itself."
			.. " The capture puts its own wrappers on functions of the addon for the session and opens its own"
			.. " report window when it pauses, which takes the keyboard (Escape lets go). Ticking the test"
			.. " discards a capture that already runs. Needs the capture's files in the manifest.",
		run = function(t)
			local capture = MikSBT.WindfuryCapture
			if not (capture and MikSBT.WindfuryTraceModel) then
				t:Log("capture not loaded: add Combat\\WindfuryTrace.lua and Combat\\WindfuryCapture.lua to the"
					.. " manifest, after the Combat and Display files, and restart the game client")
				t:Stop()
				return
			end

			-- The capture shows its report when it pauses itself, and for /msbttrace report; the report
			-- is logged then and the test ends.
			t:Watch(capture, "ShowReport", function()
				local isBuilt, text = pcall(function() return capture.model:ReportText() end)
				if isBuilt then
					t:Log("capture paused, its report follows")
					for line in tostring(text):gmatch("[^\n]+") do t:Log("REPORT", line) end
				else
					t:Log("report not built", text)
				end
				t:Stop()
			end)
			-- The capture has a stop of its own, which ends it whatever ends the test.
			t:OnStop(function() capture:Stop() end)
			capture:Start()
			if not capture.active then
				t:Log("capture did not start, see the chat")
				t:Stop()
				return
			end
			t:Log("capture started, it pauses itself on a strike with fewer than two damage numbers")
		end,
	},
}
