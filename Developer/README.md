# Local diagnostics

In a development clone, append these lines to the end of the TOC your
client uses. Restart the client after changing the TOC.

    Developer\DebugWindow.lua
    Developer\DebugTests.lua
    Developer\DeveloperTab.lua

Use the Developer tab in MSBT options or run /msbtdebug to open the debug
window. For skill-line build details, add Developer\SkillLineIconsBuild.lua
before DeveloperTab.lua if the build file is present.

Keep these TOC edits local. The release packager excludes Developer.
