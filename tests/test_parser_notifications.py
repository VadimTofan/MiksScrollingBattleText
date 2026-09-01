import unittest

from tests.lua_test_runner import run_lua_test


# Describe: parser notification routes
class ParserNotificationsTests(unittest.TestCase):
    def test_routes_power_and_killing_blow_notifications(self):
        # Given
        script_name = "parser_notifications.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
