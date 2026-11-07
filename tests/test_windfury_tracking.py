import unittest

from tests.lua_test_runner import run_lua_test


# Describe: deeper Windfury tracking counts outcomes without inspecting damage.
class WindfuryTrackingTests(unittest.TestCase):
    def test_capture_correlates_real_batching_display_gates_and_lifecycle(self):
        # Given / When
        result = run_lua_test("windfury_capture.lua")

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_burst_reports_distinguish_missing_failed_and_merged_attacks(self):
        # Given
        script = "windfury_tracking.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
