import unittest

from tests.lua_test_runner import run_lua_test


# Describe: frame-driven utility notifications
class UtilityNotificationsTests(unittest.TestCase):
    def test_resource_combat_state_and_emote_notifications(self):
        # Given
        script_name = "utility_notifications.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
