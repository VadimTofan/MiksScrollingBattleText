import unittest

from tests.lua_test_runner import run_lua_test


# Describe: built-in low resource alerts use the normal runtime lifecycle.
class LowResourceAlertTests(unittest.TestCase):
    def test_restricted_health_warns_without_blizzard_screen_flash(self):
        # Given secret health values and no Blizzard low-health flash frame.
        script_name = "restricted_health_alerts.lua"

        # When player health drops and recovers during restricted combat.
        result = run_lua_test(script_name)

        # Then independent health alerts fire, rearm, and stop when disabled.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_restricted_mana_uses_engine_evaluation_to_alert_and_rearm(self):
        # Given secret power values and native curve/text APIs.
        script_name = "restricted_mana_alerts.lua"

        # When mana crosses the threshold during restricted combat.
        result = run_lua_test(script_name)

        # Then the alert fires and rearms without inspecting secret numbers.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_alerts_respect_restrictions_settings_and_runtime_lifecycle(self):
        # Given a player, resource APIs, and the real display service.
        script_name = "low_resource_alerts.lua"

        # When the trigger module receives health and mana changes.
        result = run_lua_test(script_name)

        # Then alerts remain safe and follow the active settings.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
