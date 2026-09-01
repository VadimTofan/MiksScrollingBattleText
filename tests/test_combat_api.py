import unittest

from tests.lua_test_runner import run_lua_test


# Describe: combat event normalization
class CombatApiTests(unittest.TestCase):
    def test_unit_combat_payload_is_normalized_only_from_public_values(self):
        # Given
        script_name = "combat_api.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
