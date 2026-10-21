import unittest

from tests.lua_test_runner import run_lua_test


# Describe: resource gains display immediately.
class ResourceNotificationTests(unittest.TestCase):
    def test_gains_display_without_a_polling_or_grouping_delay(self):
        # Given
        script = "resource_notifications.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
