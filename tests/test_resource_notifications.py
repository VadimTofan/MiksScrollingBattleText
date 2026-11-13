import unittest

from tests.lua_test_runner import run_lua_test


# Describe: resource gains display immediately.
class ResourceNotificationTests(unittest.TestCase):
    def test_classes_forms_and_specializations_only_allow_their_resources(self):
        # Given
        script = "resource_policy.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_resource_names_and_combo_point_totals_preserve_hidden_values(self):
        # Given
        script = "resource_names.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_gains_display_without_a_polling_or_grouping_delay(self):
        # Given
        script = "resource_notifications.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
