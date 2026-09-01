import unittest

from tests.lua_test_runner import run_lua_test


# Describe: item cooldown tracker
class ItemCooldownTrackerTests(unittest.TestCase):
    def test_tracker_scans_used_items_and_displays_completion(self):
        # Given
        script_name = "item_cooldown_tracker.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
