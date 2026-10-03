import unittest

from tests.lua_test_runner import run_lua_test


# Describe: parser notification routes
class ParserNotificationsTests(unittest.TestCase):
    def test_chat_notifications_survive_without_legacy_combat_processing(self):
        # Given real parser, routing, formatting and notification modules.
        script_name = "notification_runtime.lua"

        # When chat events arrive with enabled and disabled settings.
        result = run_lua_test(script_name)

        # Then display output and loot payloads keep their existing behavior.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_routes_supported_chat_notifications_for_the_player(self):
        # Given
        script_name = "parser_notifications.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
