import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing self-heal matching component
class SelfHealTrackerTests(unittest.TestCase):
    def test_tracker_matches_tolerated_recent_amounts_once(self):
        # Given
        script_name = "self_heal_tracker.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
