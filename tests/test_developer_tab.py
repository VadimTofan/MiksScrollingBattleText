import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


# Describe: the developer tab of the classic options window.
class DeveloperTabTests(unittest.TestCase):
    def test_developer_tab_stays_out_of_release(self):
        # Given
        root = Path(__file__).resolve().parents[1]
        runtime = root / "MSBTOptions" / "MSBTOptionsTabs.lua"
        manifests = [*root.glob("*.toc"), root / "MSBTOptions/MSBTOptions.toc"]

        # When
        options = runtime.read_text(encoding="utf-8")
        exclusions = (root / ".pkgmeta").read_text(encoding="utf-8")

        # Then
        self.assertNotIn("DeveloperTab", options)
        self.assertIn("  - Diagnostics", exclusions.splitlines())
        for manifest in manifests:
            self.assertNotIn("Diagnostics", manifest.read_text(encoding="utf-8-sig"))

    def test_tab_waits_for_the_debug_window_and_lists_the_generated_tables(self):
        # Given
        script_name = "developer_tab.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
