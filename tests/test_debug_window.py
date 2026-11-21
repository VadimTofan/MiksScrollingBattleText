import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: the debug window is an optional development tool that runs tests on request.
class DebugWindowTests(unittest.TestCase):
    def test_tests_run_on_request_and_log_into_the_window_of_the_chosen_design(self):
        # Given
        script_name = "debug_window.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_window_stays_out_of_release_manifests_and_packages(self):
        # Given
        manifests = list(ROOT.glob("MikScrollingBattleText*.toc"))
        manifests.append(ROOT / "MSBTOptions" / "MSBTOptions.toc")
        for manifest in manifests:
            # When
            files = manifest.read_text(encoding="utf-8-sig").replace("\\", "/")

            # Then
            self.assertNotIn("DebugWindow.lua", files)
            self.assertNotIn("DebugTests.lua", files)

        # Given / When
        exclusions = (ROOT / ".pkgmeta").read_text(encoding="utf-8")

        # Then
        self.assertIn("  - Developer\n", exclusions)


if __name__ == "__main__":
    unittest.main()
