import unittest

from tests.lua_test_runner import run_lua_test


# Describe: Blizzard cooldown API boundary
class CooldownApiTests(unittest.TestCase):
    def test_cooldown_adapter_normalizes_public_values_and_rejects_secrets(self):
        # Given
        script_name = "cooldown_api.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_cooldown_adapter_supports_legacy_global_api(self):
        # Given
        script_name = "cooldown_api_legacy.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
