# Local diagnostics

In a development clone, append these lines to the end of the TOC your
client uses. Restart the client after changing the TOC.

    Diagnostics\DebugWindow.lua
    Diagnostics\DebugTests.lua
    Diagnostics\DeveloperTab.lua

Use the Developer tab in MSBT options or run /msbtdebug to open the debug
window. For skill-line build details, add Diagnostics\SkillLineIconsBuild.lua
before DeveloperTab.lua if the build file is present.

Keep these TOC edits local. The release packager excludes Diagnostics.
