import unittest

from tests.lua_test_runner import run_lua_test


# Describe: Blizzard spell API boundary
class SpellApiTests(unittest.TestCase):
    def test_spell_adapter_normalizes_public_info_and_rejects_secrets(self):
        # Given
        script_name = "spell_api.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_spell_adapter_supports_legacy_global_apis(self):
        # Given
        script_name = "spell_api_legacy.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
