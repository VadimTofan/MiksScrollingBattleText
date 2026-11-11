import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: opt-in loot timing preserves notifications and bounds capture work.
class LootProfilingTests(unittest.TestCase):
    def test_capture_times_phases_preserves_results_and_stops_automatically(self):
        # Given
        script = "loot_profiling.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_real_loot_handler_exposes_timing_commands_without_changing_alerts(self):
        # Given
        script = "loot_profiling_integration.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_profiler_loads_before_loot_notifications_on_both_clients(self):
        # Given
        for path in ROOT.glob("MikScrollingBattleText*.toc"):
            files = path.read_text(encoding="utf-8-sig").splitlines()

            # When / Then
            self.assertIn("Components\\LootProfiler.lua", files)
            self.assertLess(
                files.index("Components\\LootProfiler.lua"),
                files.index("Components\\LootNotifications.lua"),
            )
