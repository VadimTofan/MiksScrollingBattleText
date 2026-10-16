import unittest

from tests.lua_test_runner import run_lua_test


# Describe: action notifications use confirmed readable meter deltas.
class ActionNotificationTests(unittest.TestCase):
    def test_confirmed_dispels_emit_without_guessing_removed_auras(self):
        # Given
        script = "action_notifications.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_interrupt_source_routes_confirmed_count_increases(self):
        # Given
        script = "interrupt_notifications.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
