import unittest

from tests.lua_test_runner import run_lua_test


# Describe: readable combat text aura notifications.
class CombatRoutesTests(unittest.TestCase):
    def test_aura_source_routes_readable_events_and_stops_cleanly(self):
        # Given
        script = "combat_routes.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
