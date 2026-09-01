import unittest

from tests.lua_test_runner import run_lua_test


# Describe: outgoing combat attribution component
class OutgoingCombatComponentTests(unittest.TestCase):
    def test_component_attributes_recent_spells_and_routes_target_actions(self):
        # Given
        script_name = "outgoing_combat_component.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
