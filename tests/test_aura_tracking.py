import unittest

from tests.lua_test_runner import run_lua_test


# Describe: custom aura checkboxes hide only the selected notifications.
class AuraTrackingTests(unittest.TestCase):
    def test_custom_aura_styles_inherit_and_override_notification_settings(self):
        # Given
        script = "aura_styles.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_aura_rules_filter_gains_and_fades_safely(self):
        # Given
        script = "aura_tracking.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_aura_list_add_toggle_remove_and_profile_refresh(self):
        # Given
        script = "aura_tracking_options.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
