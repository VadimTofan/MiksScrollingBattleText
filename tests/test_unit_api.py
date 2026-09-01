import unittest

from tests.lua_test_runner import run_lua_test


# Describe: Blizzard unit API boundary
class UnitApiTests(unittest.TestCase):
    def test_unit_adapter_returns_only_accessible_typed_values(self):
        # Given
        script_name = "unit_api.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_unit_adapter_supports_legacy_aura_api(self):
        # Given
        script_name = "unit_api_legacy_aura.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
