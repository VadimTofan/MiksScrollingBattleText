import unittest

from tests.lua_test_runner import run_lua_test


# Describe: incoming combat component
class IncomingCombatComponentTests(unittest.TestCase):
    def test_component_batches_damage_and_suppresses_duplicate_self_heals(self):
        # Given
        script_name = "incoming_combat_component.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
