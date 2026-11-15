# Debug tests

How to add a test to the debug window, what a test can do, and what to watch for.

- A debug test is a small measurement that runs inside the game on request. It hears game events or watches the addon's own functions, writes rows into a log and can draw values into the window.
- A test is often written by one person and run by another. The tester starts it, plays, and sends back the copied log or a screenshot. A test has to bring back everything its question needs in one round.
- The debug window (`/msbtdebug`) is an opt-in development tool. It is not part of a release, its texts are English and fixed in the code, and it adds no options.

## Where things are

| What | Where |
|---|---|
| The pages and their tests | `Diagnostics/DebugTests.lua`, table `MSBTOptions.Debug.pages` |
| Window, log and recorder | `Diagnostics/DebugWindow.lua`, table `MSBTOptions.Debug` |
| Tests of both | `tests/lua/debug_window.lua`, wrapper `tests/test_debug_window.py` |
| Manifests and packages | No manifest lists the two files, and `.pkgmeta` leaves `Diagnostics` out of the packages. `tests/test_debug_window.py` keeps it so |

Two pages are listed:

| Page | Label | For tests that | Tests |
|---|---|---|---|
| `game` | Game | hear the game: its events and what its calls return | `sources` |
| `addon` | Addon | watch the addon's own functions with `t:Watch`, or start the addon's own capture | `display`, `trace`, `windfury` |

These serve as examples:

- `sources` ends itself after a time, describes only the first rows of a kind and counts the rest, and writes a summary row in `t:OnStop`.
- `display` watches one function, finds the event of a line from its settings table (also from a copy that reads through to it), says in a column whether the display takes the line, and ends itself at a limit of rows.
- `trace` watches several functions, logs each call as a numbered row and draws the same row in a ring over the rows of the window (`t.rows` of them), so that the client draws the hidden amounts.
- `windfury` starts the addon's own capture, which has a stop of its own, writes the report the capture shows when it pauses itself, and stops the capture in `t:OnStop`. It is no watch of the addon in the sense of the next section: see What a test must not do.

## Switching it on

Add these two lines at the end of the file list in the manifest your client loads, and restart the game client once:

```
Diagnostics\DebugWindow.lua
Diagnostics\DebugTests.lua
```

- They have to come after the files of the options, which the window builds on. That includes the options' designs, where there are any: loaded before them, the window stays in the classic look.
- From then on an edit to the tests file needs only `/reload`.
- Do not commit the manifest with these lines.
- The test `windfury` needs the addon's Windfury capture as well: add `Combat\WindfuryTrace.lua` and `Combat\WindfuryCapture.lua` after the files of `Combat` and `Display`. Without them it says so and ends itself.
- The chat lines of that capture name `/msbttrace` commands. They exist only with `Combat\Trace.lua` loaded as well; add it before the capture's files if the tester is to use them.

## Pages and tests

In `Diagnostics/DebugTests.lua` each page is a local table near the top, listed in `MSBTOptions.Debug.pages`; its tests follow below as `game.tests = { ... }`, `addon.tests = { ... }`.

| Field of a page | Meaning |
|---|---|
| `key` | Short lower-case word, unique among the pages. `custom` is taken by the window's own page |
| `label` | Text of the page's button: one short word of at most six letters. A button is as wide as its text plus a margin, and three stand on a line |
| `tests` | The page's tests, in the order the checkboxes show. An empty list is fine |

A test is an entry of a page's `tests`:

```lua
{
	key = "target",
	label = "Target: what is readable",
	tooltip = "Logs at each change of target whether there is one, and its health and level.",
	run = function(t)
		t:On("PLAYER_TARGET_CHANGED", function()
			t:Log("target", UnitExists("target"), "health", UnitHealth("target"), "level", UnitLevel("target"))
		end)
	end,
},
```

| Field | Required | Meaning |
|---|---|---|
| `key` | yes | Short lower-case word, unique over all pages. Every row of the test carries it. `custom` is taken by the pasted test |
| `label` | yes | Text of the checkbox: the topic, a colon, what the test does |
| `tooltip` | no | One or two sentences on what is logged or drawn. For a test that watches the addon, it names the functions watched |
| `run(t)` | yes | Called once when the test is ticked. It registers what the test hears or watches and returns. `t` is the recorder of this run |

- A test that hears the game goes on the page `game`, a test that watches the addon on the page `addon`. A test that does both goes where its question is.
- A new page is a new local table and an entry in `MSBTOptions.Debug.pages`. The window adds its own page, "Custom", after the listed ones.

What the window does, so a test must not do it again:

- Writes the row `started <label>` when the test is ticked and `stopped` when it stops.
- Ends the test when the tick is removed or the test calls `t:Stop()`: its events are unregistered, its watches end, its timers do nothing more, and its `t:OnStop` callbacks run.
- Catches an error in `run`, in a handler, in a timer callback, in a watching callback and in a callback for the stop, and logs it as `error <message>`. What the test set up before the error keeps running.
- Logs the first five errors of a run and counts the rest, so that a callback that fails at every call in a fight does not flood the log. When the test stops after more than five, the row `errors <count> the first 5 are logged` comes before `stopped`.
- Keeps recording while the window is closed, and shows the rows when it opens.
- Keeps the newest 1000 rows. While tests write, the screen follows with the newest 100, at most twice a second. "Select all" shows every row.
- Starts nothing by itself. After `/reload` no test runs and the log is empty.
- Keeps the place it was dragged to, for the whole account and outside the profiles (`MSBTProfiles_SavedVars.debugWindowPosition`), and takes the look of the chosen options design where the options come in designs; otherwise it is the classic window.
- Has room for 16 tests on a page below one line of page buttons, and for 15 below two lines, which a fourth page needs, the window's own counted; page buttons stand three to a line. `tests/lua/debug_window.lua` asserts that no listed page has more tests than fit and no page label is longer than six letters. A changed list needs `/reload`.

## The recorder

| Call | What it does |
|---|---|
| `t:On(event, handler)` | Hears a game event until the test stops. The handler gets the event's arguments, without the event's name |
| `t:On(event, handler, unit)` | The same, for that unit only |
| `t:Watch(owner, name, callback)` | Watches the addon's function `owner[name]` until the test stops. After every call the callback gets the call's arguments. See Tests that watch the addon |
| `t:Log(...)` | Writes one row: the seconds since the log began, the test's key, the values |
| `t:After(seconds, callback)` | Runs the callback later, unless the test has stopped by then. `t:After(0, callback)` is the next frame |
| `t:OnStop(callback)` | Runs the callback once when the test stops, whatever stops it, before the row `stopped` |
| `t:Stop()` | Ends the test, exactly as removing its tick does, and takes the tick away |
| `t:IsSecret(value)` | Whether the client hides the value from addons. A table counts as hidden as well when its content is out of reach |
| `t:Show(...)` | Draws the values into the window as free text instead of logging them, and returns whether it did. Each call replaces what was drawn before, the rows included |
| `t:Row(index, ...)` | Draws the values into row `index` of the window and returns whether it did. The other rows stay, the free text of `t:Show` goes |
| `t.rows` | A plain field, no call: how many rows the window has for `t:Row`. Use it where a test goes round the rows, instead of repeating the number (`trace` does) |

- One handler per event: a second `t:On` for the same event replaces the first. The same holds for a second `t:Watch` of the same function in one test.
- An event the client does not know is logged as `event unavailable <event>`, and the test goes on.
- `t:Log` writes numbers, booleans and `nil` as text, and a string with its line breaks turned into spaces. A table, a function or userdata is written as the name of its type, so log fields, not tables. A value the client hides is written as `<secret>`, a protected text as `<protected-text>`.
- `t:Show` and `t:Row` put a space after each value. A string goes in as it is, a value the client hides is handed to the client as it is, for the client to draw, a hidden boolean as a hidden 1 or 0, and any other value as its text (`nil`, `true`, `12`). See What a test may draw where.
- `t:OnStop`: several callbacks run in the order they were given. The test is already stopped when they run: its events and watches have ended, so that an event or a call of a watched function from inside a callback is not heard; `t:Log`, `t:Show` and `t:Row` work, `t:On`, `t:Watch` and `t:After` do nothing more, `t:Stop()` does nothing. Use it for a summary row, for instance how many calls were heard. A test that started something with a stop of its own stops it here. A callback given after `t:Stop()` has been called never runs.
- `t:Stop()` is safe from inside `run`, a handler, a timer callback, a watching callback and a callback for the stop. The code after it runs to its end. The pasted test has no tick to take away.
- A recorder kept beyond its run hears and watches nothing: `t:On` and `t:Watch` register nothing, its timers do not run, and `t:Stop()` stops no later run of the same test.
- A call as the last argument hands over all its values: `t:Log("BUILD", getBuild())`, as `sources` logs the client's build.
- Rows with the same time were written in the same frame.
- A test is ordinary addon code. It may call the game's API and read the addon's own tables (`MikSBT`, `MSBTOptions`).

## Tests that watch the addon

`t:Watch(owner, name, callback)` lets a test see what the addon's own functions are called with, for instance which setting the options changed and to what.

```lua
{
	key = "options",
	label = "Options: settings changed",
	tooltip = "Watches MikSBT.Profiles.SetOption and logs the path, the name and the value of every call.",
	run = function(t)
		local calls = 0
		t:Watch(MikSBT.Profiles, "SetOption", function(path, name, value)
			calls = calls + 1
			t:Log("SO", path, name, value)
		end)
		t:OnStop(function() t:Log("calls heard", calls) end)
	end,
},
```

What it does:

- The callback runs after the function has run, with the same arguments. For a method called with a colon, the first argument is the object the method was called on. The addon's components are class tables whose methods are called on instances, so watching the class table sees the calls of every instance, and the first argument is the instance.
- It runs after the function has returned, so with watched functions that call each other the rows of the inner call come first. It does not run at all when the watched function raises an error.
- The function itself stays in place. It is called as before, it returns what it returned before, and it does what it did before. The callback gets the arguments, not the results.
- The first time any test watches a function, one dispatcher is put on it with `hooksecurefunc`. It stays for the session, until `/reload`, and passes every call on to the tests that watch the function at that moment. With no test watching, it looks at an empty table and does nothing else. Nothing is hooked before a running test asks for it.
- When the test stops, it is taken out of every function it watched.
- An error in the callback is logged as `error <message>` under the test's key. The addon's call and other tests watching the same function are not disturbed.
- `owner` has to be the table that holds the function itself: the class table, not an instance that reaches the method through a metatable. A wrapper put on the instance would shadow the class's method for good, so for an instance the row `function unavailable <name>` is written and the test goes on. The same row is written when `owner` is no table or `owner[name]` is no function.

What a callback must keep to:

- Read its arguments, never change them. A table handed over is the addon's own: no field set, no entry added or removed.
- Never call back into the watched function, nor into anything that calls it.
- Stay small. Watched functions run during fights, some many times a second. Limit the rows as for an event that comes often.

Watch with care:

- The addon's functions are internal. Their names, their arguments and where they live can change with any version. Read the function before writing the test, and name what is watched in the tooltip, so that the tester and the next reader know what the rows depend on.
- Only calls that go through `owner[name]` are seen. A reference to the function taken before it was watched (a local copy, a script handler or a slash command set to the function itself) calls the original, unseen. `MikSBT.Animations.DisplayEvent` is such a case: most files take it into a local when they load. So is `MikSBT.Profiles.SetOption` in the example above: the two calls inside `MSBTProfiles.lua` itself go through a local and are not seen.
- When the addon puts another function under that name after it was first watched, the dispatcher stays on the old one, and calls of the new one are not seen, in every later run until `/reload`.
- `function unavailable` usually means the name or the table moved. Look the function up again in the code.

## What a test may draw where

The lower part of the right side of the window is the drawing area, below the log. It takes room only while something is drawn: with nothing drawn the log reaches down to the line of "Run" and "Stop", and the first call of `t:Show` or `t:Row` that draws values makes room by ending the log higher, with its row of buttons moving up with it. "Clear" gives the room back.

| Call | Where | Fits |
|---|---|---|
| `t:Row(index, ...)` | Row `index`, from 1 at the top to 14 | One line, about 520 wide. A longer text is cut |
| `t:Show(...)` | Free text, starting where row 1 starts | Lines broken by `"\n"` and by the width; it grows downward |

- `t:Show` empties all rows and writes its text. `t:Row` empties the free text and writes its row. "Clear" empties both, and gives the room back to the log.
- A call without values draws nothing and makes no room; neither does a call that returns `false`.
- Whether room is made is kept for the session, the same in the window of every look, and is not saved: a window opened later shows it as well.
- `t:Row(index)` without values empties that row.
- An index outside 1 to 14, or one that is no whole number, draws nothing and returns `false`.
- Nothing is drawn while the window is closed; both calls return `false` then. Log that, as `trace` does, so that the tester learns why the window stayed empty.
- All tests share the area. Run one drawing test at a time.
- Rows suit values that are read again and again, one row per value, each updated in its place. Free text suits one reading drawn at once.
- Of the listed tests `trace` draws, into rows. None draws free text; `t:Show` is there for a test that needs it.

## Adding a test

1. Write down the question the test answers, and what the tester has to do so that it comes up.
2. Try a short test pasted first: on the page "Custom", the body of `run` goes into the field, then "Run". That needs no file and no reload. Its rows carry the key `custom`, "Stop" ends it, and code that does not compile is logged as `custom error <message>`.
3. Add the entry to the page's list in `Diagnostics/DebugTests.lua`. Do not add a file: an edit to a loaded file needs only `/reload`, a new file needs a restart of the game client.
4. Give the test a rule in `tests/lua/debug_window.lua` (see Tests).
5. Write the test case for the tester (see The test case).

If a measurement needs more than the recorder gives, extend the recorder (`Run` in `Diagnostics/DebugWindow.lua`) and give the new call a rule, instead of working around it inside a test.

## What a test should log

- The state first: what holds before anything happens. `sources` writes the client's build when it starts, after a legend row.
- A legend row where the order of a row's values is not obvious.
- Short tags in capitals for rows that repeat (`GAIN`, `LOG`, `CAST`). Say what each tag means in the test case.
- Every value that could decide the question, read at the event and, when timing matters, again one frame later (`t:After(0, ...)`). Many values change only after the event that announces them.
- The client's own word on what it hides, where it offers a call for that (`C_Secrets.ShouldUnitPowerBeSecret`), next to the value.
- `unavailable` in place of a call the client may lack. Take the call once at the top: `local getGain = C_CombatText and C_CombatText.GetCurrentEventInfo`.
- A limit on what repeats. An event or a watched call that comes many times a second gets one: the first ten of a kind, or only the third of a second after the event the test is about. Otherwise 1000 rows are gone quickly, and the tester has to copy them all.
- How many rows were left out, on the next row that is written or in a `t:OnStop` row, where the rate matters for the question.
- Numbers that tune the test (limits, time windows) as named locals at the top of `run`, each with a comment.

## Values the client hides

The client keeps some values from addons, called secret values. Seen hidden so far: the mana, rage and energy of the player, and the amount and the resource of a gain in the combat text. What is hidden depends on the value, and for some values on whether a fight is on. Finding that out is what many tests are for, so a test guards every value it does more with than pass it on. The addon passes such values through its own functions, so the arguments a watching callback gets can be hidden as well.

| With a hidden value a test may | It must not, the client raises an error |
|---|---|
| store it and pass it on | compare it (`==`, `~=`, `<`) |
| hand it to `t:Log`, `t:Show` and `t:Row` | do arithmetic with it |
| join it into a text (`..`, `string.format`) | use it as a table key, index it, take its length |
| ask `type(value)` and `t:IsSecret(value)` | test it for truth (`if value`, `value and ...`, `not value`) |

- Ask `t:IsSecret(value)` before any comparison, key or truth test. That holds for the arguments of an event and of a watched call as well.
- A call can return a table that is hidden as a whole or out of reach, or a readable table with hidden fields. Ask `t:IsSecret` of the table before reading a field, and log which case it was, for instance `none`, `hidden` or `table`, before the fields.
- Give the value itself to `t:Log`, `t:Show` and `t:Row`, as an argument of its own. A text joined with a hidden value is hidden as a whole, label included.
- In the log a hidden value reads `<secret>`. That it is hidden is often the answer.
- To read what it holds, draw it with `t:Show` or `t:Row`. A drawn value cannot be copied; the tester sends a screenshot of the window.
- The index of `t:Row` is a plain number of the test's own, never a value the client hides.
- `t:Show` and `t:Row` draw a hidden boolean as a hidden 1 or 0, made by `C_CurveUtil.EvaluateColorValueFromBoolean(value, 1, 0)`, or as the text `<hidden boolean>` on a client without that call. The client's formatter takes only strings and numbers for `%s` and raises an error on a boolean. A test that builds a text of its own turns a hidden boolean with the same call first, and decides by `type(value) == "boolean"` once it knows the value is hidden: a truth test of it raises an error.
- The client's own text tools take hidden values and return hidden results (`C_StringUtil`, `C_Intl`, `C_CurveUtil`). With them the client can pick a text by a value the addon cannot read. `ResourceLabel` in `Components/CombatPresentation.lua` is the model.

## What a test must not do

A test is meant to read only. Nothing enforces that, so the list is a rule for whoever writes one:

- Change anything. No CVars, no settings, no profile values, no targeting, no casting, and no argument of a watched call.
- Leave anything behind. Nothing a test installs itself can be taken back: no `hooksecurefunc` of its own (watch with `t:Watch`), no `HookScript`, no `SetScript` on a frame it does not own. `t:OnStop` is for the test's own rows, and for the stop of something the test started that has a stop of its own (`windfury`). The one exception is `windfury` itself: the capture it starts puts wrappers on functions of the addon for the session, and they stay until `/reload`. That is the capture's doing, not the test's, and it is why the tooltip of the test says so.
- Hear or wait by itself. No `OnUpdate`, no frame of its own that registers events, no `C_Timer` call. Events come through `t:On`, calls of the addon through `t:Watch` and time through `t:After`, so that the stop ends them.
- Call a watched function, or anything that calls it, from its callback.
- Build a frame, a table or a function per event or per watched call where one per run will do. Tests run during fights.
- Add a file or a manifest line.
- Add texts to the localization. Labels, tooltips and rows are English.

## The test case

A test is half of a measurement. The other half is what the tester does in the game. Write one test case per test:

- Preparation: which files to copy into the game. If only files changed that were loaded before, `/reload` is enough. A new file or a changed manifest needs a restart of the game client.
- Steps: which page to choose, when to tick the test, what to do in the game and for how long, when to remove the tick. Use the words the game shows the tester, and say where it matters that a fight is on or not.
- Expected: the rows that should appear and what each tag means, so that the tester sees at once whether the test ran.
- What to send back: the whole log ("Select all", Ctrl+C, paste), or a screenshot of the window for drawn values.
- What else to report: rows that say `error` or `unavailable`, and anything that looked different from Expected.

How the window is used, so that the steps are right:

- `/msbtdebug` opens and closes it, and so does the X in its corner. Escape does not close it.
- The content begins 78 below the top of the window, clear of the picture in the corner of the classic look. What is placed from the top below the title hangs on `window.content`, which a design without that picture puts back at the corner of the window, so that the content begins 48 below the top there; the log and the field for the code grow by as much. What is placed from the bottom stays on the window: the bottoms of both boxes with the buttons under them, and what tests draw. On the left, a row of buttons, one per page: "Game", "Addon", and "Custom" for the pasted test. The button of the page shown is greyed out. Below them the page's tests, or on "Custom" the field for the code with "Run" and "Stop" at the bottom.
- The page chosen stays when the window is closed and opened again, and, where there are designs, when another options design takes it over. After `/reload` the window opens on the first page.
- A tick starts a test, removing the tick stops it. Tests keep running while the window is closed and while another page is shown.
- On the right, the label "Log" level with the first test of the page, and under it the log, one log for all pages. Its box begins level with the box for the pasted code on "Custom". Its row with "Select all", "Clear" and the count of rows stands at the bottom on the line of "Run" and "Stop", and the log reaches down to that row. A test that draws makes room at the bottom for what it draws: the log ends higher, and its row of buttons with it.
- "Select all" shows the whole log and selects it. Ctrl+C copies it and lets go of the keyboard; Escape lets go as well. While the log holds the keyboard, its text does not change.
- "Clear" empties the log and what was drawn, and starts the clock anew.
- `/reload` empties the log. Copy first.
- A test that draws needs the window open, and only one drawing test at a time.

## Reading a log

A log as `sources` writes it; the values are made up:

```
0.000 sources started Sources: gains and log messages
0.000 sources rows: GAIN kind, fields, then the number and value of each field; LOG arguments and whether the text is hidden; CAST spell id, as context only
0.000 sources BUILD 1.60.1 70888 Nov 1 2026 16001
4.212 sources CAST spell 5221 context only
4.212 sources GAIN ENERGIZE fields 2 1 <secret> 2 <secret>
4.212 sources LOG arguments 1 text hidden true
30.000 sources END gains 1 log messages 1
30.000 sources stopped
```

- First the seconds since the log began or was last cleared. Equal times mean the same frame.
- Then the key of the test, `custom` for the pasted one.
- `<secret>`: the client hid the value. `<protected-text>`: a text the client protects.
- `error ...`: the test failed at that point. The message names the line, in the tests file for a listed test and in the pasted text for a pasted one.
- `event unavailable ...`: the client does not know the event.
- `function unavailable ...`: the addon has no function of that name in that table.
- `stopped` right after rows of the test's own, without the tick removed: the test ended itself.
- `errors <count> the first 5 are logged`: before `stopped`, more than five errors came in the run and only the first five are rows.
- Fewer rows than expected: a limit of the test, or the 1000 rows of the log, which drops the oldest first.

## Pitfalls

Timing

- A value often changes after the event that announces it. At the combat text of a resource gain the total still held the old value; the power update in the same frame and the next frame held the new one. Read at the event and one frame later.
- Combat lockdown begins after `PLAYER_REGEN_DISABLED` has fired and ends before `PLAYER_REGEN_ENABLED` fires. Take stock for the beginning of a fight one frame later, with `t:After(0, ...)`; at the end it can be taken at once.
- A watching callback runs after the function, in the same frame. What the function changed is in place; what it set off for later is not.

Hidden values

- One event can carry readable and hidden arguments. The kind of a combat text was readable while its amount and its resource were hidden. Check each argument.
- A hidden value as a table key raises an error. Count under a name: `local name = t:IsSecret(kind) and "<secret>" or kind`.

Watching

- A function that is not called through its table is not seen. No rows from a watch where rows were expected: check how the addon calls the function.
- Two tests watching the same function each get every call, in no fixed order between them.
- The settings of the current profile read through to the master profile (`MikSBT.Profiles.masterProfile`): `pairs` over a table of the current profile lists only what the user changed. To find which entry a table handed to a watched call belongs to, go over the keys of the master profile and compare `current[key]` with the table.
- Settings handed to a watched call can also be a copy made for one hit, built as `setmetatable({ ... }, { __index = settings })`, which reads through to the event's own table; it matches no table of the profile itself. `display` shows how to find the event from it: it builds a map from table to event name once per run, from the master profile's names and the tables the current profile gives for them, and climbs from the copy by `rawget(getmetatable(copy), "__index")` a few steps, while that is a table (the profile's own metatable has a function there, which ends the climb). It builds the map anew for another current profile and, for a table it does not know, at most once a second.
- A watched call is not always a call of the thing the test is about: `DisplayEvent` is also called for lines the display then drops, because the event, the addon, the category or the area is off. `display` logs them all, and says in its column `display` whether the display takes the line (`shown`) or the first reason it drops it (`dropped: event disabled`, `addon disabled`, `category disabled`, `area missing`, `area disabled`), read from the same checks the function makes. Say in the test case what the rows include.

The log

- Events that come often flood the log and the copy. Power updates arrive every few seconds outside a fight as well. Limit them.
- The screen shows the newest 100 rows; the count beside "Clear" says how many there are. The copy from "Select all" holds them all.
- `t:Show` and `t:Row` draw only into the open window, and one test's drawing replaces another's.

Loading

- A new file or a changed manifest needs a restart of the game client. `/reload` only picks up edits to files that were already loaded. That is why a test is an entry in a loaded file.
- A syntax error in the tests file leaves the window without pages. The repository test loads that file; run it before handing a test over.

## Tests

- `tests/lua/debug_window.lua` holds the rules of the window and of every listed test, among them where the content begins, how far the log reaches with and without a drawing, and how many tests fit below one and two lines of page buttons. Run it alone with `python -m unittest tests.test_debug_window`, and the full suite before a commit with `python -m unittest discover -s tests -p "test_*.py"`, both with `LUA51` and `LUAC51` pointing at a Lua 5.1 interpreter and compiler.
- `tests/test_debug_window.py` also holds the rule that no manifest lists the two files and that the packages leave them out.
- The stub world of the Lua file:

  | Helper | What it does |
  |---|---|
  | `Fire(event, ...)` | Delivers a game event to whoever registered it. A test that hears an event for one unit gets it only when the first argument is that unit, so `Fire(event, "target")` shows that another unit is not heard |
  | `RunTimers(within)` | Runs the timers due within that many seconds; `RunTimers(0)` is the next frame. A timer started meanwhile waits for the next call |
  | `now` | The clock, in seconds. The log's zero is the `now` at the moment "Clear" is clicked, so set `now` first and click then |
  | `Tick(window, key, isChecked)` | Starts or stops a test. Like the tester, it can only tick a checkbox on the page shown |
  | `Click(button)` | Clicks a button that is on screen; a disabled one, such as the button of the page shown, does nothing |
  | `window.pageButtons.<key>` | The button of a page; `Click(window.pageButtons.addon)` shows the page `addon` |
  | `frame:IsVisible()` | Whether a control is on screen, its page and the window shown |
  | `Lines(window)` | The rows on screen. It first runs the timers due within half a second, a test's own among them. After "Clear" and a tick the first row is `started <label>`; the test's own rows begin with the second |
  | `AllLines(window)` | All rows, as "Select all" shows them |
  | `frame.points`, `frame.pointCalls` | The anchors a frame holds by the name of the point, one per point as in the client, and how often `SetPoint` was called on it. A rule that says nothing was anchored anew compares the count before and after |
  | `window.drawnFontString:GetText()` | What a test drew with `t:Show` |
  | `window.rowFontStrings[index]:GetText()` | What a test drew into a row with `t:Row` |
  | `SECRET`, `HIDDEN` | Two values the stub client hides: a table, and a number that is not one (NaN). Logged they read `<secret>`, drawn they read `<drawn>` and `<drawn too>` |
  | `SetFormattedText` | Like the client's, it raises an error on a boolean argument, so that only a value turned into a number or a text gets through. `Hide(false)` and `Hide(true)` prove the conversion of a hidden boolean |
  | `SEALED` | A table whose content the stub client keeps out of reach |
  | `Listening()` | Whether any event is still registered |
  | `Addon` | A stub table of the addon's functions to watch: `Addon.Sum(left, right)` returns `left + right, "and more"` and counts its calls in `Addon.calls` |
  | `Hooked(name)` | How often a function of that name was hooked |
  | `Hide(value)` | The stub client hides that one value as well, until `Hide({})`. Drawn it reads `<drawn hidden>`. It proves a `t:IsSecret` check that `SECRET` cannot: a hidden text that would equal what the test compares it with, a hidden `false`, a hidden table with readable fields |
  | `Display` | Rules of the page `addon`: `Display.service` is a stub of `MikSBT.Display.Service` with `DisplayEvent` as a method, and `Display.Show(...)` calls it through the table, as the animation engine's `DisplayEvent` does. Its `config` answers the checks of the real one: `Display.isModDisabled`, the current profile and `Display.areas` by key |

- `hooksecurefunc` of the stub behaves like the client's: the hook runs after the function with its arguments, the call returns all the function returned, and a name that holds no function is refused. To watch a real function of the addon, load its file in the rule or put a stub of it into the table the test watches.
- A window builds its pages once, when it is built. The real list is loaded in the rule "the listed tests come from one file", which then chooses the stub design `listed`, so that a window is built with every listed page. The rule of a new test comes after the rules of the tests listed before it, and before the two rules that end the file: the last one loads the window's file a second time without designs. `window`, `Debug` and the helpers above are in scope there; take the test by its page and place and assert its key (`Debug.pages[1].tests[1].key`, `Debug.pages[2].tests[3].key`), and show its page before ticking it (`Click(window.pageButtons.addon)`; the page shown already is disabled, and a click on it does nothing).
- Rules of a watching test put stubs of the addon's tables into `MikSBT` (`MikSBT.Components`, `MikSBT.CombatEngine`, the profile), with the functions as methods called through their table, as the real ones are. Where the test starts something of the addon's own, as `windfury` starts the capture, the stub has its `Start`, `Stop`, `ShowReport` and `active`, the rule calls `ShowReport` as the capture does when it pauses itself, and it asserts the count of `Start` and `Stop`.
- In that rule: stub the game calls the test uses as globals, tick the test, fire its events or call the watched functions, assert the rows or the drawing, remove the tick and assert that nothing stays registered and that a call after the stop writes no row.
- A global stubbed in one rule stays for the rules after it. Set every global the test reads, and set one back to `nil` where a later rule must not see it.
- Cover the plain case, a hidden value in every place where one can come, the limit on rows that repeat, and a call or function the client or the addon lacks.
- Every assertion has to fail when the code it guards is changed back. Check that by changing the code, not by reading it: one change at a time, run the test, undo.
- The stub is not the client. `SECRET` is a table there, so joining it into a text, arithmetic, `<` and calling it raise an error, but `==`, `~=`, a truth test and reading a field of it do not. `HIDDEN` raises one only when something is stored under it as a table key. A `t:IsSecret` check can therefore often not be proven by an error: assert the text of the row, and read the code.
- The stub's buttons and checkboxes are not the options' controls, and no design's skin restyles them. Whether the look of a page button marks the page shown is seen only in the game.
- Comment style of the tests: `-- Given`, `-- When`, `-- Then`.
